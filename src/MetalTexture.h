#import <Metal/Metal.h>
#import <Cocoa/Cocoa.h>

@interface VBoxMetalTexture : NSObject

@property (readonly) id<MTLTexture> metalTexture;
@property (readonly) uint32_t glTarget;
@property (readonly) uint32_t glName;
@property (readonly) MTLPixelFormat pixelFormat;
@property (readonly) uint32_t width;
@property (readonly) uint32_t height;
@property (readonly) uint32_t depth;
@property (readonly) uint32_t mipLevels;

// Parameter state
@property CGFloat minFilter;
@property CGFloat magFilter;
@property CGFloat wrapS;
@property CGFloat wrapT;
@property CGFloat wrapR;
@property CGFloat maxAnisotropy;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                        glName:(uint32_t)name
                        glTarget:(uint32_t)target
                        width:(uint32_t)width
                        height:(uint32_t)height
                        depth:(uint32_t)depth
                        mipLevels:(uint32_t)mipLevels
                        format:(uint32_t)glFormat
                        type:(uint32_t)glType;

- (void)uploadData:(const void*)data
           mipLevel:(uint32_t)mipLevel
           offsetX:(uint32_t)offsetX
           offsetY:(uint32_t)offsetY
           offsetZ:(uint32_t)offsetZ
           width:(uint32_t)width
           height:(uint32_t)height
           depth:(uint32_t)depth
           format:(uint32_t)glFormat
           type:(uint32_t)glType;

- (void)generateMipmaps;
- (void)setTexParameter:(uint32_t)pname value:(CGFloat)value;

+ (MTLPixelFormat)metalFormatFromGL:(uint32_t)glFormat glType:(uint32_t)glType;

@end
