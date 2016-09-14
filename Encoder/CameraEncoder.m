//
//  CameraEncoder.m
//  EasyCapture
//
//  Created by phylony on 9/11/16.
//  Copyright © 2016 phylony. All rights reserved.
//
#import "CameraEncoder.h"

#define KEY "6A34714D6C354F576B5971414A553558714C485A4576466C59584E356348567A6147567958334E6B61395A58444661672F704C67523246326157346D516D466962334E68514449774D545A4659584E355247467964326C75564756686257566863336B3D"

char* ConfigIP		= "121.40.50.44";	//Default EasyDarwin Address
char* ConfigPort	= "554";			//Default EasyDarwin Port
char* ConfigName	= "easypusher_sdk.sdp";//Default Push StreamName
char* ConfigUName	= "admin";			//SDK UserName
char* ConfigPWD		= "admin";			//SDK Password
char* ConfigDHost	= "192.168.66.189";	//SDK Host
char* ConfigDPort	= "80";				//SDK Port
char *ProgName;		//Program Name

@interface CameraEncoder ()
{
    H264HWEncoder *h264Encoder;

    AACEncoder *aacEncoder;
    Easy_I32 isActivated;
    Easy_Pusher_Handle handle;

    AVCaptureSession *captureSession;
    
//    NSString *h264File;
//    NSString *aacFile;
//    NSFileHandle *fileH264Handle;
//    NSFileHandle *fileAACHandle;
    
    AVCaptureConnection* connectionVideo;
    AVCaptureConnection* connectionAudio;
    BOOL isReadyVideo, isReadyAudio;
}

@end

@implementation CameraEncoder

- (void)initCameraWithOutputSize:(CGSize)size
{
    h264Encoder = [[H264HWEncoder alloc] init];
    [h264Encoder setOutputSize:size];
    h264Encoder.delegate = self;
    
#if TARGET_OS_IPHONE
    aacEncoder = [[AACEncoder alloc] init];
    aacEncoder.delegate = self;
#endif
    
    isReadyAudio = NO;
    isReadyVideo = NO;
    
    handle= EasyPusher_Create();
    EASY_MEDIA_INFO_T mediainfo;
    memset(&mediainfo, 0x00, sizeof(EASY_MEDIA_INFO_T));
    mediainfo.u32VideoCodec = EASY_SDK_VIDEO_CODEC_H264;
    mediainfo.u32VideoFps = 25;
    mediainfo.u32AudioCodec = EASY_SDK_AUDIO_CODEC_AAC;//SDK output Audio PCMA
    mediainfo.u32AudioSamplerate = 8000;
    mediainfo.u32AudioChannel = 1;
    EasyPusher_StartStream(handle, ConfigIP, atoi(ConfigPort), ConfigName, "admin", "admin", &mediainfo, 0, false);//1M缓冲区

    [self initCamera];
    
}

-(void)Send{
    isReadyAudio=isReadyVideo=true;
}

- (void)dealloc {
#if TARGET_OS_IPHONE
    [h264Encoder invalidate];
#endif
    isReadyAudio = NO;
    isReadyVideo = NO;
}

#pragma mark - Camera Control

- (void) initCamera
{
    // make input device
    
    NSError *deviceError;
    
    AVCaptureDevice *cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *microphoneDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    AVCaptureDeviceInput *inputCameraDevice = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&deviceError];
    AVCaptureDeviceInput *inputMicrophoneDevice = [AVCaptureDeviceInput deviceInputWithDevice:microphoneDevice error:&deviceError];
    
    // make output device
    
    AVCaptureVideoDataOutput *outputVideoDevice = [[AVCaptureVideoDataOutput alloc] init];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    
    outputVideoDevice.videoSettings = videoSettings;
    
    [outputVideoDevice setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    
    AVCaptureAudioDataOutput *outputAudioDevice = [[AVCaptureAudioDataOutput alloc] init];
    
    [outputAudioDevice setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];
    
    // initialize capture session
    
    captureSession = [[AVCaptureSession alloc] init];
    
    [captureSession addInput:inputCameraDevice];
    [captureSession addInput:inputMicrophoneDevice];
    [captureSession addOutput:outputVideoDevice];
    [captureSession addOutput:outputAudioDevice];
    
    // begin configuration for the AVCaptureSession
    [captureSession beginConfiguration];
    
    // picture resolution
    [captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset640x480]];
    
    connectionVideo = [outputVideoDevice connectionWithMediaType:AVMediaTypeVideo];
    connectionAudio = [outputAudioDevice connectionWithMediaType:AVMediaTypeAudio];
    
    [self setRelativeVideoOrientation];
    
    NSNotificationCenter* notify = [NSNotificationCenter defaultCenter];
    
    [notify addObserver:self
               selector:@selector(statusBarOrientationDidChange:)
                   name:@"StatusBarOrientationDidChange"
                 object:nil];
    
    [captureSession commitConfiguration];
    
    // make preview layer and add so that camera's view is displayed on screen
    
    self.previewLayer = [AVCaptureVideoPreviewLayer    layerWithSession:captureSession];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
}

- (void) startCamera
{
    [captureSession startRunning];
    [self performSelector:@selector(Send) withObject:nil afterDelay:2.0];

//    NSFileManager *fileManager = [NSFileManager defaultManager];
//    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//    NSString *documentsDirectory = [paths objectAtIndex:0];
//    
//    // Drop file to raw 264 track
//    h264File = [documentsDirectory stringByAppendingPathComponent:@"test.h264"];
//    [fileManager removeItemAtPath:h264File error:nil];
//    [fileManager createFileAtPath:h264File contents:nil attributes:nil];
//    
//    // Open the file using POSIX as this is anyway a test application
//    fileH264Handle = [NSFileHandle fileHandleForWritingAtPath:h264File];
//    
//    // Drop file to raw aac track
//    aacFile = [documentsDirectory stringByAppendingPathComponent:@"test.aac"];
//    [fileManager removeItemAtPath:aacFile error:nil];
//    [fileManager createFileAtPath:aacFile contents:nil attributes:nil];
//    
//    // Open the file using POSIX as this is anyway a test application
//    fileAACHandle = [NSFileHandle fileHandleForWritingAtPath:aacFile];
}

- (void) stopCamera
{
    [h264Encoder invalidate];
    [captureSession stopRunning];
    
//    [fileH264Handle closeFile];
//    fileH264Handle = NULL;
//    [fileAACHandle closeFile];
//    fileAACHandle = NULL;
    

}


- (void)statusBarOrientationDidChange:(NSNotification*)notification {
    [self setRelativeVideoOrientation];
}

- (void)setRelativeVideoOrientation {
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            connectionVideo.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            connectionVideo.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            connectionVideo.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            connectionVideo.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}

-(void) captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection
{
    if(connection == connectionVideo)
    {
        [h264Encoder encode:sampleBuffer];
    }
    else if(connection == connectionAudio)
    {
        [aacEncoder encode:sampleBuffer];
    }
}

#pragma mark -  H264HWEncoderDelegate declare

- (void)gotH264EncodedData:(NSData *)packet timestamp:(CMTime)timestamp
{
//    NSLog(@"gotH264EncodedData %d", (int)[packet length]);
//    
//    [fileH264Handle writeData:packet];
    
//    if(isReadyVideo && isReadyAudio) [rtp_h264 publish:packet timestamp:timestamp payloadType:98];
    
    EASY_AV_Frame frame;
    frame.pBuffer=(void*)packet.bytes;
    frame.u32AVFrameFlag=EASY_SDK_VIDEO_FRAME_FLAG;
    frame.u32AVFrameLen=(Easy_U32)packet.length;
    frame.u32TimestampSec=0;//(Easy_U32)timestamp.value/timestamp.timescale;
    frame.u32TimestampUsec=0;//timestamp.value%timestamp.timescale/1000;
    unsigned char* bt4= (unsigned char*)packet.bytes;
    
    unsigned char nal=bt4[4] &0x1f;
    
    frame.u32VFrameType=(nal==0x05)? EASY_SDK_VIDEO_FRAME_I : EASY_SDK_VIDEO_FRAME_P;

//    NSLog(@"H264 Encoder:%d",timestamp.timescale);
    
    if(isReadyVideo && isReadyAudio) EasyPusher_PushFrame(handle, &frame) ;//[publish:packet timestamp:timestamp payloadType:98];

}

#if TARGET_OS_IPHONE
#pragma mark - AACEncoderDelegate declare

- (void)gotAACEncodedData:(NSData*)data timestamp:(CMTime)timestamp error:(NSError*)error
{
//    NSLog(@"gotAACEncodedData %d", (int)[data length]);
//
//    if (fileAACHandle != NULL)
//    {
//        [fileAACHandle writeData:data];
//    }

//    if(isReadyVideo && isReadyAudio) [rtp_aac publish:data timestamp:timestamp payloadType:97];
    EASY_AV_Frame frame;
    frame.pBuffer=(void*)data.bytes;
    frame.u32AVFrameFlag=EASY_SDK_AUDIO_FRAME_FLAG;
    frame.u32AVFrameLen=(Easy_U32)data.length;
    frame.u32TimestampSec=0;//(Easy_U32)timestamp.value/timestamp.timescale;
    frame.u32TimestampUsec=0;//timestamp.value%timestamp.timescale;
    if(isReadyVideo && isReadyAudio) EasyPusher_PushFrame(handle,&frame);//[rtp_aac publish:data timestamp:timestamp payloadType:97];

}
#endif


@end
