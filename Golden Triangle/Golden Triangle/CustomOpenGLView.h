//
//  CustomOpenGLView.h
//  Golden Triangle
//
//  Created by Blukee on 23/02/2014.
//  Copyright (c) 2014 Blukee. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class NSOpenGLContext, NSOpenGLPixelFormat;
@interface CustomOpenGLView : NSView
{
@private
    NSOpenGLContext*     _openGLContext;
    NSOpenGLPixelFormat* _pixelFormat;
}
+ (NSOpenGLPixelFormat*)defaultPixelFormat;
- (id)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat*)format;
- (void)setOpenGLContext:(NSOpenGLContext*)context;
- (NSOpenGLContext*)openGLContext;
- (void)clearGLContext;
- (void)prepareOpenGL;
- (void)update;
- (void)setPixelFormat:(NSOpenGLPixelFormat*)pixelFormat;
- (NSOpenGLPixelFormat*)pixelFormat;
@end
