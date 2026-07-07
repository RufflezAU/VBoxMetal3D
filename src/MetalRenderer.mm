// MetalRenderer - GPU-accelerated rendering pipeline for VirtualBox
// Handles the actual Metal command encoding for 3D rendering

#import "MetalContext.h"
#import "MetalTexture.h"
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

@interface VBoxMetalRenderer : NSObject

@property (readonly) VBoxMetalContext* context;

// Render pipeline cache
@property (strong) NSMutableDictionary* pipelineCache;
@property (strong) NSMutableDictionary* depthStateCache;
@property (strong) NSMutableDictionary* samplerStateCache;

- (instancetype)initWithContext:(VBoxMetalContext*)ctx;

// Core rendering operations
- (void)blitTexture:(id<MTLTexture>)src toTexture:(id<MTLTexture>)dst filter:(MTLSamplerMinMagFilter)filter;
- (void)blitFramebuffer:(id<MTLTexture>)src toDrawable:(id<CAMetalDrawable>)dst;
- (void)clearTexture:(id<MTLTexture>)tex color:(MTLClearColor)color;
- (void)compositeTexture:(id<MTLTexture>)src onto:(id<MTLTexture>)dst;

// GPU compute operations
- (void)convertTexture:(id<MTLTexture>)src to:(id<MTLTexture>)dst format:(uint32_t)glFormat;

@end

@implementation VBoxMetalRenderer

- (instancetype)initWithContext:(VBoxMetalContext*)ctx {
    self = [super init];
    if (self) {
        _context = ctx;
        _pipelineCache = [NSMutableDictionary dictionary];
        _depthStateCache = [NSMutableDictionary dictionary];
        _samplerStateCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)blitTexture:(id<MTLTexture>)src toTexture:(id<MTLTexture>)dst filter:(MTLSamplerMinMagFilter)filter {
    if (!src || !dst) return;

    id<MTLCommandBuffer> cmdBuf = [self.context acquireCommandBuffer];
    id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
    blit.label = @"VBoxMetal3D Texture Blit";

    MTLOrigin srcOrigin = MTLOriginMake(0, 0, 0);
    MTLSize srcSize = MTLSizeMake(src.width, src.height, 1);
    MTLOrigin dstOrigin = MTLOriginMake(0, 0, 0);

    [blit copyFromTexture:src
              sourceSlice:0
              sourceLevel:0
             sourceOrigin:srcOrigin
               sourceSize:srcSize
                toTexture:dst
         destinationSlice:0
         destinationLevel:0
        destinationOrigin:dstOrigin];
    [blit endEncoding];
}

- (void)blitFramebuffer:(id<MTLTexture>)src toDrawable:(id<CAMetalDrawable>)dst {
    if (!src || !dst.texture) return;

    id<MTLCommandBuffer> cmdBuf = [self.context acquireCommandBuffer];
    id<MTLBlitCommandEncoder> blit = [cmdBuf blitCommandEncoder];
    blit.label = @"VBoxMetal3D Framebuffer Blit";

    MTLSize srcSize = MTLSizeMake(src.width, src.height, 1);
    [blit copyFromTexture:src
              sourceSlice:0 sourceLevel:0
             sourceOrigin:MTLOriginMake(0, 0, 0)
               sourceSize:srcSize
                toTexture:dst.texture
         destinationSlice:0 destinationLevel:0
        destinationOrigin:MTLOriginMake(0, 0, 0)];
    [blit endEncoding];
    [cmdBuf presentDrawable:dst];
}

- (void)clearTexture:(id<MTLTexture>)tex color:(MTLClearColor)color {
    if (!tex) return;

    id<MTLCommandBuffer> cmdBuf = [self.context acquireCommandBuffer];
    MTLRenderPassDescriptor* rpDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    rpDesc.colorAttachments[0].texture = tex;
    rpDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    rpDesc.colorAttachments[0].clearColor = color;
    rpDesc.colorAttachments[0].storeAction = MTLStoreActionStore;

    id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpDesc];
    enc.label = @"VBoxMetal3D Clear";
    [enc endEncoding];
}

- (void)compositeTexture:(id<MTLTexture>)src onto:(id<MTLTexture>)dst {
    if (!src || !dst) return;

    // Use Metal Performance Shaders for compositing if available
    if (@available(macOS 10.13, *)) {
        // For simple alpha blending, we use a compute shader
        id<MTLCommandBuffer> cmdBuf = [self.context acquireCommandBuffer];
        id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
        comp.label = @"VBoxMetal3D Composite";

        // Find or create the composite pipeline state
        id<MTLComputePipelineState> pipeline = [self.pipelineCache objectForKey:@"composite"];
        if (!pipeline) {
            id<MTLFunction> fn = [self.context.shaderLibrary newFunctionWithName:@"compositeAlpha"];
            if (fn) {
                NSError* err = nil;
                pipeline = [self.context.device newComputePipelineStateWithFunction:fn error:&err];
                if (pipeline) {
                    [self.pipelineCache setObject:pipeline forKey:@"composite"];
                }
            }
        }

        if (pipeline) {
            [comp setComputePipelineState:pipeline];
            [comp setTexture:dst atIndex:0];
            [comp setTexture:src atIndex:1];
            [comp setTexture:dst atIndex:2]; // write to dst
            MTLSize gridSize = MTLSizeMake(dst.width, dst.height, 1);
            MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
            [comp dispatchThreads:gridSize threadsPerThreadgroup:threadGroupSize];
        }
        [comp endEncoding];
    }
}

- (void)convertTexture:(id<MTLTexture>)src to:(id<MTLTexture>)dst format:(uint32_t)glFormat {
    // Use compute shader for pixel format conversion
    id<MTLCommandBuffer> cmdBuf = [self.context acquireCommandBuffer];
    id<MTLComputeCommandEncoder> comp = [cmdBuf computeCommandEncoder];
    comp.label = @"VBoxMetal3D Format Convert";

    NSString* fnName = (glFormat == 0x80E1) ? @"convertBGRAtoRGBA" : @"convertRGBAToBGRA"; // GL_BGRA
    id<MTLComputePipelineState> pipeline = [self.pipelineCache objectForKey:fnName];
    if (!pipeline) {
        id<MTLFunction> fn = [self.context.shaderLibrary newFunctionWithName:fnName];
        if (fn) {
            NSError* err = nil;
            pipeline = [self.context.device newComputePipelineStateWithFunction:fn error:&err];
            if (pipeline) {
                [self.pipelineCache setObject:pipeline forKey:fnName];
            }
        }
    }

    if (pipeline) {
        [comp setComputePipelineState:pipeline];
        [comp setTexture:src atIndex:0];
        [comp setTexture:dst atIndex:1];
        MTLSize gridSize = MTLSizeMake(MIN(src.width, dst.width), MIN(src.height, dst.height), 1);
        MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
        [comp dispatchThreads:gridSize threadsPerThreadgroup:threadGroupSize];
    }
    [comp endEncoding];
}

@end
