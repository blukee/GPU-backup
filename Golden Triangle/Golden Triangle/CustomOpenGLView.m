//
//  CustomOpenGLView.m
//  Golden Triangle
//
//  Created by Blukee on 23/02/2014.
//  Copyright (c) 2014 Blukee. All rights reserved.
//

#import "CustomOpenGLView.h"

@implementation CustomOpenGLView
- (id)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format
{
    self = [super initWithFrame:frameRect];
    if (self != nil) {
        _pixelFormat   = format;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_surfaceNeedsUpdate:)
                                                     name:NSViewGlobalFrameDidChangeNotification
                                                   object:self];
    }
    return self;
}

- (void) _surfaceNeedsUpdate:(NSNotification*)notification
{
    [self update];
}

- (void)lockFocus
{
    NSOpenGLContext* context = [self openGLContext];
    
    [super lockFocus];
    if ([context view] != self) {
        [context setView:self];
    }
    [context makeCurrentContext];
}

//-(void) drawRect
//{
//    [context makeCurrentContext];
//    //Perform drawing here
//    [context flushBuffer];
//}
//
//-(void) viewDidMoveToWindow
//{
//    [super viewDidMoveToWindow];
//    if ([self window] == nil)
//    [context clearDrawable];
//}

@end
