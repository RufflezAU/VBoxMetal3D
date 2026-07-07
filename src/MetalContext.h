#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <Cocoa/Cocoa.h>


// Forward declarations
@class VBoxMetalContext;

// Global singleton access
VBoxMetalContext* VBoxMetalGetGlobalContext(void);

// Per-thread context tracking
typedef struct {
    VBoxMetalContext* current;
} VBoxMetalThreadState;

// Virtual context ID tracking for OpenGL compatibility
typedef struct {
    uint32_t nextId;
    void*    contextMap;
} VBoxMetalContextRegistry;

@interface VBoxMetalContext : NSObject

@property (readonly) id<MTLDevice> device;
@property (readonly) id<MTLCommandQueue> commandQueue;
@property (readonly) id<MTLLibrary> shaderLibrary;
@property (readonly) CAMetalLayer* metalLayer;
@property (readonly) NSView* hostView;

// Current state for the active render pass
@property (strong) id<MTLCommandBuffer> currentCommandBuffer;
@property (strong) id<MTLRenderCommandEncoder> currentEncoder;
@property (strong) id<MTLComputeCommandEncoder> currentComputeEncoder;
@property (strong) id<MTLBlitCommandEncoder> currentBlitEncoder;

// Render pass state
@property MTLRenderPassDescriptor* currentRenderPassDesc;
@property MTLPixelFormat pixelFormat;

// View dimensions
@property CGFloat viewWidth;
@property CGFloat viewHeight;

- (instancetype)initWithDevice:(id<MTLDevice>)device;
- (void)createLayerInView:(NSView*)view;
- (void)resizeLayer;
- (void)presentDrawable;
- (void)waitForGPU;

// Command buffer management
- (id<MTLCommandBuffer>)acquireCommandBuffer;
- (void)commitCommandBuffer;
- (void)commitAndPresent;

@end
