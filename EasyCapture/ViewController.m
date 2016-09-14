//
//  ViewController.m
//  EasyCapture
//
//  Created by phylony on 9/11/16.
//  Copyright © 2016 phylony. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    cp=[[CameraEncoder alloc] init];
    
    [cp initCameraWithOutputSize:CGSizeMake(480, 640)];
    
    
    cp.previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:cp.previewLayer];
    AVCaptureVideoPreviewLayer *prev=cp.previewLayer;
    [[prev connection] setVideoOrientation:AVCaptureVideoOrientationPortrait];
    prev.frame=self.view.bounds;
    cp.previewLayer.hidden = NO;
    [cp startCamera];

    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
