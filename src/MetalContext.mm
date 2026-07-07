#import "MetalContext.h"
#include <pthread.h>

// Global context singleton
static VBoxMetalContext* g_metalContext = nil;
static pthread_once_t g_onceToken = PTHREAD_ONCE_INIT;

static void InitGlobalContext(void) {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device) {
        g_metalContext = [[VBoxMetalContext alloc] initWithDevice:device];
    }
}

VBoxMetalContext* VBoxMetalGetGlobalContext(void) {
    pthread_once(&g_onceToken, InitGlobalContext);
    return g_metalContext;
}

@implementation VBoxMetalContext

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _device = device;
        _commandQueue = [device newCommandQueue];
        _pixelFormat = MTLPixelFormatBGRA8Unorm;
        _viewWidth = 1;
        _viewHeight = 1;

        // Compile Metal shaders at runtime (no Xcode needed)
        NSError* err = nil;
        NSString* shaderSource = [NSString stringWithContentsOfFile:
            [[NSBundle mainBundle] pathForResource:@"VBoxMetalShaders" ofType:@"metal"]
            encoding:NSUTF8StringEncoding error:nil];
        if (!shaderSource) {
            NSString* homePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/VBoxMetal3D/VBoxMetalShaders.metal"];
            shaderSource = [NSString stringWithContentsOfFile:homePath encoding:NSUTF8StringEncoding error:nil];
        }
        if (!shaderSource) {
            shaderSource = [NSString stringWithContentsOfFile:
                @"/Users/nicholasrussell/projects/VBoxMetal3D/shaders/VBoxMetalShaders.metal"
                encoding:NSUTF8StringEncoding error:nil];
        }
        if (shaderSource) {
            MTLCompileOptions* opts = [MTLCompileOptions new];
            opts.languageVersion = MTLLanguageVersion2_4;
            _shaderLibrary = [device newLibraryWithSource:shaderSource options:opts error:&err];
            if (!_shaderLibrary) {
                NSLog(@"VBoxMetal3D: Shader compile error: %@", err);
            }
        }
        if (!_shaderLibrary) {
            _shaderLibrary = [device newDefaultLibrary];
        }
        NSLog(@"VBoxMetal3D: Initialized with device: %@", device.name);
    }
    return self;
}

- (void)createLayerInView:(NSView*)view {
    _hostView = view;
    _metalLayer = [CAMetalLayer layer];
    _metalLayer.device = self.device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = YES;
    _metalLayer.frame = view.bounds;
    _metalLayer.drawsAsynchronously = YES;

    // Use maximum drawable count for better throughput
    _metalLayer.maximumDrawableCount = 3;

    // Set the layer as the view's backing layer
    // If view already has a layer, replace it
    view.wantsLayer = YES;
    view.layer = _metalLayer;

    _viewWidth = view.bounds.size.width * view.window.backingScaleFactor;
    _viewHeight = view.bounds.size.height * view.window.backingScaleFactor;
    _metalLayer.drawableSize = CGSizeMake(_viewWidth, _viewHeight);

    NSLog(@"VBoxMetal3D: Created Metal layer in view (%.0fx%.0f @%.1fx)",
          _viewWidth, _viewHeight, view.window.backingScaleFactor);
}

- (void)resizeLayer {
    if (!_metalLayer || !_hostView) return;

    CGFloat scale = _hostView.window ? _hostView.window.backingScaleFactor : 1.0;
    _viewWidth = _hostView.bounds.size.width * scale;
    _viewHeight = _hostView.bounds.size.height * scale;
    _metalLayer.drawableSize = CGSizeMake(_viewWidth, _viewHeight);
    _metalLayer.frame = _hostView.bounds;
}

- (id<MTLCommandBuffer>)acquireCommandBuffer {
    if (!_currentCommandBuffer) {
        _currentCommandBuffer = [self.commandQueue commandBuffer];
        _currentCommandBuffer.label = @"VBoxMetal3D Frame";
    }
    return _currentCommandBuffer;
}

- (void)commitCommandBuffer {
    if (_currentEncoder) {
        [_currentEncoder endEncoding];
        _currentEncoder = nil;
    }
    if (_currentComputeEncoder) {
        [_currentComputeEncoder endEncoding];
        _currentComputeEncoder = nil;
    }
    if (_currentBlitEncoder) {
        [_currentBlitEncoder endEncoding];
        _currentBlitEncoder = nil;
    }
    if (_currentCommandBuffer) {
        [_currentCommandBuffer commit];
        _currentCommandBuffer = nil;
    }
}

- (void)presentDrawable {
    id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
    if (!drawable) return;

    id<MTLCommandBuffer> cmdBuf = [self acquireCommandBuffer];
    [cmdBuf presentDrawable:drawable];
    [self commitCommandBuffer];
}

- (void)commitAndPresent {
    [self presentDrawable];
}

- (void)waitForGPU {
    [self commitCommandBuffer];
    id<MTLCommandBuffer> waitBuf = [self.commandQueue commandBuffer];
    [waitBuf commit];
    [waitBuf waitUntilCompleted];
}

- (void)dealloc {
}

@end
