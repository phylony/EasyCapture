//
//  CameraEncoder.h
//  EasyCapture
//
//  Created by phylony on 9/11/16.
//  Copyright © 2016 phylony. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "H264HWEncoder.h"

#import <UIKit/UIKit.h>
#import "AACEncoder.h"
#import "EasyPusherAPI.h"


@interface CameraEncoder : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, H264HWEncoderDelegate, AACEncoderDelegate>

@property (weak, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

- (void) initCameraWithOutputSize:(CGSize)size;
- (void) startCamera;
- (void) stopCamera;

@end

