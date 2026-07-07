#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>

// MetalDisplay manages the Metal view/layer lifecycle for VirtualBox
// It replaces the NSOpenGLView/NSOpenGLContext with CAMetalLayer

@interface MetalDisplay : NSObject

@property (readonly) CAMetalLayer* metalLayer;
@property (readonly) NSView* hostView;

- (instancetype)initWithMetalDevice:(id<MTLDevice>)device;
- (bool)createViewInParent:(NSView*)parent width:(uint32_t)width height:(uint32_t)height;
- (void)setPosition:(int)x y:(int)y;
- (void)setSize:(int)w h:(int)h;
- (void)swapBuffers;
- (void)destroy;

@end
