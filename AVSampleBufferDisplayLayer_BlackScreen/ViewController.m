//
//  ViewController.m
//  AVSampleBufferDisplayLayer_BlackScreen
//
//  Created by Mackode - Bartlomiej Makowski on 16/07/2019.
//  Copyright © 2019 com.castlabs.player.blackscreen. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>


//
@interface DisplayLayer : AVSampleBufferDisplayLayer

@property BOOL firstSampleBufferEnqueued;

@end

@implementation DisplayLayer

- (void)dealloc {
    [self stopRequestingMediaData];
    [self flushAndRemoveImage];
    self.controlTimebase = nil;
    [NSThread sleepForTimeInterval:0.1];
}

@end


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIView *videoView;
@property (weak, nonatomic) IBOutlet UISlider *seek;

@property (nonatomic) AVAsset *asset;
@property (nonatomic) AVAssetReader *assetReader;
@property (nonatomic) AVAssetReaderTrackOutput *assetReaderOutput;
@property (nonatomic) BOOL assetReaderReady;

@property DisplayLayer *videoLayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(decodingDidFail:) name:AVSampleBufferDisplayLayerFailedToDecodeNotification object:nil];
    self.seek.value = 0.0f;

    NSURL *url = [[NSBundle mainBundle] URLForResource:@"tearsofsteel_4k.mov_1918x852_2000" withExtension:@"mp4"];
    self.asset = [AVAsset assetWithURL:url];

    [self setupVideoLayer];
    [self setupAssetReader];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startPlayback];
}

- (void)decodingDidFail:(NSNotification *)notification {
    NSLog(@">>!! Decoding Did Fail %@", [[notification userInfo] valueForKey:AVSampleBufferDisplayLayerFailedToDecodeNotificationErrorKey]);
}

- (void)setupVideoLayer {
    if (self.videoLayer) {
        NSLog(@">>!! Remove Layer ...");
        [self.videoLayer stopRequestingMediaData];
        [self.videoLayer flushAndRemoveImage];
        [self.videoLayer removeFromSuperlayer];
        NSLog(@">>!! < Remove");
    }

    NSLog(@">>!! 0) Init Display Layer ...");
    self.videoLayer = [[DisplayLayer alloc] init];
    self.videoLayer.bounds = self.videoView.bounds;
    self.videoLayer.position = CGPointMake(CGRectGetMidX(self.videoView.bounds), CGRectGetMidY(self.videoView.bounds));
    self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.videoLayer.backgroundColor = [[UIColor blackColor] CGColor];
    NSLog(@">>!! OK");

    CMTimebaseRef controlTimebase;
    CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(), &controlTimebase);

    self.videoLayer.controlTimebase = controlTimebase;
    CMTimebaseSetTime(self.videoLayer.controlTimebase, CMTimeMake(0, 1));
    CMTimebaseSetRate(self.videoLayer.controlTimebase, 1.0);

    [[self.videoView layer] addSublayer:_videoLayer];
}

- (void)setupAssetReader {
    NSLog(@">>!! Setup Reader ...");
    NSArray *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    CMTime duration = self.asset.duration;
    AVAssetTrack *videoTrack = [videoTracks objectAtIndex:0];
    CMTime startTime = CMTimeMake([self.seek value] * duration.value, duration.timescale);
    CMTimeRange timeRange = CMTimeRangeMake(startTime, kCMTimePositiveInfinity);

    @synchronized (self) {
        if (self.assetReader) {
            [self.assetReader cancelReading];
        }

        NSError *error;
        self.assetReader = [[AVAssetReader alloc] initWithAsset:self.asset error:&error];
        if (error) {
            NSLog(@">>!! AVAssetReader Error %@", error);
            return;
        }

        self.assetReader.timeRange = timeRange;
        self.assetReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack outputSettings:nil];
        if ([self.assetReader canAddOutput:self.assetReaderOutput]) {
            [self.assetReader addOutput:self.assetReaderOutput];
            self.assetReaderReady = [self.assetReader startReading];
        } else {
            NSLog(@">>!! Unable to add output to AVAssetReader instance");
            return;
        }
    }
    NSLog(@">>!! < Setup Reader");
}

- (void)startPlayback {
    NSLog(@">>!! Start Playback ...");
    dispatch_queue_t renderQueue = dispatch_queue_create([[NSString stringWithFormat:@"renderqueue.%p", self.videoLayer] cStringUsingEncoding:NSASCIIStringEncoding], 0);
    NSLog(@">>!! Try to Request New Sample Buffer ...");
    [self.videoLayer requestMediaDataWhenReadyOnQueue:renderQueue usingBlock: ^{
        NSLog(@">>!! 1. Request New Sample Buffer");
        while([self.videoLayer isReadyForMoreMediaData]) {
            CMSampleBufferRef sampleBuffer = NULL;

            @synchronized (self) {
                if (!self.assetReaderReady ||
                    [self.assetReader status] != AVAssetReaderStatusReading ||
                    ![[self.assetReader outputs] containsObject:self.assetReaderOutput]) {

                    NSLog(@">>!! AVAsset Reader Status Not Equals Reading");
                    [self.videoLayer stopRequestingMediaData];
                    return;
                }

                sampleBuffer = [self.assetReaderOutput copyNextSampleBuffer];
            }

            if (sampleBuffer) {
                BOOL keyFrame = NO;
                if (CMSampleBufferGetNumSamples(sampleBuffer) > 0) {
                    NSArray *attachmentArray = ((NSArray*)CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false));
                    if (attachmentArray) {
                        NSDictionary *attachment = attachmentArray[0];
                        NSNumber *depends = attachment[(__bridge NSNumber *)kCMSampleAttachmentKey_DependsOnOthers];
                        if (depends && !depends.boolValue) {
                            keyFrame = YES;
                        }
                    }
                }

                if (([self.videoLayer firstSampleBufferEnqueued] == NO && keyFrame == YES) || [self.videoLayer firstSampleBufferEnqueued] == YES) {
                    NSLog(@">>!! Enqueue Sample Buffer ...");
                    [self.videoLayer enqueueSampleBuffer:sampleBuffer];
                    self.videoLayer.firstSampleBufferEnqueued = YES;
                    NSLog(@">>!! < Enqueue");
                }
                CFRelease(sampleBuffer);
            }
            NSLog(@">>!! << Enqueue");
        }
        NSLog(@">>!! < Request New Sample Buffer");
    }];
    NSLog(@">>!! < Playback");
}

- (void)syncVideoLayer {
    NSLog(@">>!! Sync ...");
    CMTime duration = self.asset.duration;
    CMTime startTime = CMTimeMake([self.seek value] * duration.value, duration.timescale);
    CMTimebaseSetTime(self.videoLayer.controlTimebase, startTime);
    CMTimebaseSetRate(self.videoLayer.controlTimebase, 1.0);
    NSLog(@">>!! < Sync");
}

- (IBAction)seek:(id)sender {
    NSLog(@">>!! Seek ...");
    [self setupVideoLayer];
    [self setupAssetReader];
    [self startPlayback];
    [self syncVideoLayer];
    NSLog(@">>!! < Seek");
}

@end
