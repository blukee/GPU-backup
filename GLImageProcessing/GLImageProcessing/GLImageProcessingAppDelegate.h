//
//  GLImageProcessingAppDelegate.h
//  GLImageProcessing
//
//  Created by Chris Parrish on 8/22/11.
//  Copyright 2011 Aged & Distilled. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ImageProcessingViewController;

@interface GLImageProcessingAppDelegate : NSObject <UIApplicationDelegate>

@property (nonatomic, retain) IBOutlet UIWindow* window;
@property (nonatomic, retain) IBOutlet ImageProcessingViewController* viewController;

@end
