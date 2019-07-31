# Issue description:

AVSampleBufferDisplayLayer seems to hang on iOS 12.3.1 (>= iOS 12.2 is also affected) after 
reboot. It looks that after 5 minutes everything works fine again.

The issue is not reproducible on iOS 11.
In our production code we don't use AVAssetReader, so please ignore any issues
with it, if minor.

I can make application hang on AVSampleBufferDisplayLayer init, enqueue and
requestMediaDataWhenReadyOnQueue.

Please advise how we should implement AVSampleBufferDisplayLayer correctly
(examples are welcome). Especially when we have to maintain and exchange
many display layers at once.

--------------------------------
How to reproduce the issue:

1) Download:
[Tears of Steel segment](http://demo.cf.castlabs.com/media/TOS/abr/tearsofsteel_4k.mov_1918x852_2000.mp4)
2) Put tearsofsteel_4k.mov_1918x852_2000.mp4 in Resources/ directory
3) Open AVSampleBufferDisplayLayer_BlackScreen.xcodeproj
4) Take iOS 12.3.1 device and reboot it
5) Start debugging AVSampleBufferDisplayLayer_BlackScreen
6) The video should start playing, then move a slider (seek) one or a few more times

## Observed result:
Video hangs usually on AVSampleBufferDisplayLayer methods

## Expected result:
Video seeks and continues to play

## Sample code is available also here:

https://github.com/mackode/AVSampleBufferDisplayLayer_Hanging
