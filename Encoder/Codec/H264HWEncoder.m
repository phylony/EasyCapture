//
//  H264HWEncoder.m
//  EasyCapture
//
//  Created by phylony on 9/11/16.
//  Copyright © 2016 phylony. All rights reserved.
//

#import "H264HWEncoder.h"

@import VideoToolbox;
@import AVFoundation;

@implementation H264HWEncoder
{
    VTCompressionSessionRef session;
    CGSize outputSize;
}

- (void) dealloc {
    [self invalidate];
}

- (id) init {
    if (self = [super init]) {
        session = NULL;
        outputSize = CGSizeMake(640, 360);
    }
    return self;
}

void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags,
                     CMSampleBufferRef sampleBuffer )
{
    H264HWEncoder* encoder = (__bridge H264HWEncoder*)outputCallbackRefCon;
    
    if (status == noErr) {
        return [encoder didReceiveSampleBuffer:sampleBuffer];
    }
    
    NSLog(@"Error %d : %@", infoFlags, [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
}

- (void)didReceiveSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!sampleBuffer) {
        return;
    }
    
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    H264Packet *packet = [[H264Packet alloc] initWithCMSampleBuffer:sampleBuffer];
    
    if (self.delegate != nil) {
        [self.delegate gotH264EncodedData:packet.packet timestamp:timestamp];
    }
}

- (void) setOutputSize:(CGSize)size
{
    outputSize = size;
}

- (void) initSession
{
    CFMutableDictionaryRef encoderSpecifications = NULL;
    
#if !TARGET_OS_IPHONE
    /** iOS is always hardware-accelerated **/
    CFStringRef key = kVTVideoEncoderSpecification_EncoderID;
    CFStringRef value = CFSTR("com.apple.videotoolbox.videoencoder.h264.gva");
    
    CFStringRef bkey = kVTVideoEncoderSpecification_RequireHardwareAcceleratedVideoEncoder;
    CFBooleanRef bvalue = kCFBooleanTrue;
    
    CFStringRef ckey = kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder;
    CFBooleanRef cvalue = kCFBooleanTrue;
    
    encoderSpecifications = CFDictionaryCreateMutable(
                                                      kCFAllocatorDefault,
                                                      3,
                                                      &kCFTypeDictionaryKeyCallBacks,
                                                      &kCFTypeDictionaryValueCallBacks);
    
    CFDictionaryAddValue(encoderSpecifications, bkey, bvalue);
    CFDictionaryAddValue(encoderSpecifications, ckey, cvalue);
    CFDictionaryAddValue(encoderSpecifications, key, value);
#endif
    
    OSStatus ret = VTCompressionSessionCreate(kCFAllocatorDefault, outputSize.width, outputSize.height, kCMVideoCodecType_H264, encoderSpecifications, NULL, NULL, didCompressH264, (__bridge void *)(self), &session);
    if (ret == noErr) {
        VTSessionSetProperty(session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_3_0);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_AspectRatio16x9, kCFBooleanTrue);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanTrue);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(90));
        VTSessionSetProperty(session, kVTCompressionPropertyKey_MaxH264SliceBytes, (__bridge CFTypeRef)@(184)); // this is not working yet.
        
#if !TARGET_OS_IPHONE
        VTSessionSetProperty(session, kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder, kCFBooleanTrue);
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(15));
#else
        VTSessionSetProperty(session, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(30));
#endif
        
        // Bitrate is only working iOS. not Mac OSX
#if TARGET_OS_IPHONE
        int bitrate = 600;
        int v = bitrate;
        CFNumberRef ref = CFNumberCreate(NULL, kCFNumberSInt32Type, &v);
        
        OSStatus ret = VTSessionSetProperty(session, kVTCompressionPropertyKey_AverageBitRate, ref);
        
        CFRelease(ref);
        ret = VTSessionCopyProperty(session, kVTCompressionPropertyKey_AverageBitRate, kCFAllocatorDefault, &ref);
        
        if(ret == noErr && ref) {
            SInt32 br = 0;
            
            CFNumberGetValue(ref, kCFNumberSInt32Type, &br);
            
            bitrate = br;
            CFRelease(ref);
        } else {
            bitrate = v;
        }
        v = 800 / 8;
        CFNumberRef bytes = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &v);
        v = 1;
        CFNumberRef duration = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &v);
        
        CFMutableArrayRef limit = CFArrayCreateMutable(kCFAllocatorDefault, 2, &kCFTypeArrayCallBacks);
        
        CFArrayAppendValue(limit, bytes);
        CFArrayAppendValue(limit, duration);
        
        VTSessionSetProperty(session, kVTCompressionPropertyKey_DataRateLimits, limit);
        CFRelease(bytes);
        CFRelease(duration);
        CFRelease(limit);
#endif
        
        VTCompressionSessionPrepareToEncodeFrames(session);
    }
}

- (void) invalidate
{
    if(session)
    {
        VTCompressionSessionCompleteFrames(session, kCMTimeInvalid);
        VTCompressionSessionInvalidate(session);
        CFRelease(session);
        session = NULL;
    }
}

- (void) encode:(CMSampleBufferRef )sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    if(session == NULL)
    {
        [self initSession];
    }
    
    if( session != NULL && sampleBuffer != NULL )
    {
        // Create properties
        CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
        VTCompressionSessionEncodeFrame(session, imageBuffer, timestamp, kCMTimeInvalid, NULL, NULL, NULL);
    }
}

@end
