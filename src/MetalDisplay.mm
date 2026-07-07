#import "MetalDisplay.h"

@interface MetalDisplay ()
@property (strong) id<MTLDevice> device;
@property (strong) id<MTLCommandQueue> commandQueue;
@end

@implementation MetalDisplay

- (instancetype)initWithMetalDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [device newCommandQueue];
        _commandQueue.label = @"VBoxMetal3D Display Queue";
    }
    return self;
}

- (bool)createViewInParent:(NSView*)parent width:(uint32_t)width height:(uint32_t)height {
    // Create a Metal-backed view
    NSRect frame = NSMakeRect(0, 0, width, height);
    NSView* view = [[NSView alloc] initWithFrame:frame];
    view.wantsLayer = YES;

    CAMetalLayer* layer = [CAMetalLayer layer];
    layer.device = self.device;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.frame = view.bounds;

    CGFloat scale = parent.window ? parent.window.backingScaleFactor : 1.0;
    layer.drawableSize = CGSizeMake(width * scale, height * scale);
    layer.maximumDrawableCount = 3;
    layer.drawsAsynchronously = YES;

    view.layer = layer;

    if (parent) {
        view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [parent addSubview:view];
    }

    _hostView = view;
    _metalLayer = layer;

    NSLog(@"VBoxMetal3D: Metal display created (%dx%d @%.1fx)", width, height, scale);
    return YES;
}

- (void)setPosition:(int)x y:(int)y {
    NSRect frame = self.hostView.frame;
    frame.origin.x = x;
    frame.origin.y = y;
    self.hostView.frame = frame;
}

- (void)setSize:(int)w h:(int)h {
    NSRect frame = self.hostView.frame;
    frame.size.width = w;
    frame.size.height = h;
    self.hostView.frame = frame;

    CGFloat scale = self.hostView.window ? self.hostView.window.backingScaleFactor : 1.0;
    self.metalLayer.drawableSize = CGSizeMake(w * scale, h * scale);
}

- (void)swapBuffers {
    @autoreleasepool {
        id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
        if (!drawable) return;

        id<MTLCommandBuffer> cmdBuf = [self.commandQueue commandBuffer];
        cmdBuf.label = @"VBoxMetal3D Swap";

        id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
        [blit endEncoding];

        [cmdBuf presentDrawable:drawable];
        [cmdBuf commit];
    }
}

- (void)destroy {
    if (_hostView) {
        [_hostView removeFromSuperview];
        _hostView = nil;
    }
    _metalLayer = nil;
}

@end
