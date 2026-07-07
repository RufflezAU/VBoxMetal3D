#import "MetalTexture.h"
#import "MetalContext.h"
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>

// GL constants not in system headers
#ifndef GL_TEXTURE_RECTANGLE
#define GL_TEXTURE_RECTANGLE 0x84F5
#endif
#ifndef GL_TEXTURE_2D_ARRAY
#define GL_TEXTURE_2D_ARRAY 0x8C1A
#endif

static uint32_t s_nextTextureName = 1;

static MTLPixelFormat MTLFormatFromGL(uint32_t glFormat, uint32_t glType) {
    switch (glFormat) {
        case GL_RGBA:
            switch (glType) {
                case GL_UNSIGNED_BYTE:          return MTLPixelFormatRGBA8Unorm;
                case GL_FLOAT:                  return MTLPixelFormatRGBA32Float;
                case GL_HALF_FLOAT:             return MTLPixelFormatRGBA16Float;
                case GL_UNSIGNED_INT_2_10_10_10_REV: return MTLPixelFormatRGB10A2Unorm;
            }
            break;
        case GL_BGRA:
            if (glType == GL_UNSIGNED_BYTE)
                return MTLPixelFormatBGRA8Unorm;
            break;
        case GL_RGB:
            if (glType == GL_UNSIGNED_BYTE)
                return MTLPixelFormatRGBA8Unorm; // Swizzled, can't do RGB natively
            if (glType == GL_UNSIGNED_SHORT_5_6_5)
                return MTLPixelFormatB5G6R5Unorm;
            break;
        case GL_DEPTH_COMPONENT:
            if (glType == GL_FLOAT)
                return MTLPixelFormatDepth32Float;
            if (glType == GL_UNSIGNED_INT)
                return MTLPixelFormatDepth32Float;
            if (glType == GL_UNSIGNED_SHORT)
                return MTLPixelFormatDepth16Unorm;
            break;
        case GL_DEPTH_STENCIL:
            if (glType == GL_UNSIGNED_INT_24_8)
                return MTLPixelFormatDepth24Unorm_Stencil8;
            return MTLPixelFormatDepth32Float_Stencil8;
        case GL_RED:
            if (glType == GL_UNSIGNED_BYTE)     return MTLPixelFormatR8Unorm;
            if (glType == GL_FLOAT)             return MTLPixelFormatR32Float;
            if (glType == GL_HALF_FLOAT)        return MTLPixelFormatR16Float;
            break;
        case GL_RG:
            if (glType == GL_UNSIGNED_BYTE)     return MTLPixelFormatRG8Unorm;
            if (glType == GL_FLOAT)             return MTLPixelFormatRG32Float;
            break;
        case GL_LUMINANCE:
            return MTLPixelFormatR8Unorm; // Luminance maps to RED
        case GL_ALPHA:
            // Alpha-only not directly supported; use RGBA with alpha swizzle
            return MTLPixelFormatA8Unorm;
        case GL_LUMINANCE_ALPHA:
            return MTLPixelFormatRG8Unorm; // Maps luminance to R, alpha to G
    }
    return MTLPixelFormatInvalid;
}

@implementation VBoxMetalTexture

- (instancetype)initWithDevice:(id<MTLDevice>)device
                        glName:(uint32_t)name
                        glTarget:(uint32_t)target
                        width:(uint32_t)width
                        height:(uint32_t)height
                        depth:(uint32_t)depth
                        mipLevels:(uint32_t)mipLevels
                        format:(uint32_t)glFormat
                        type:(uint32_t)glType {
    self = [super init];
    if (self) {
        _glName = name ? name : s_nextTextureName++;
        _glTarget = target;
        _width = width;
        _height = height;
        _depth = depth;
        _mipLevels = mipLevels > 0 ? mipLevels : 1;
        _pixelFormat = MTLFormatFromGL(glFormat, glType);

        // Default sampler state
        _minFilter = GL_LINEAR;
        _magFilter = GL_LINEAR;
        _wrapS = GL_REPEAT;
        _wrapT = GL_REPEAT;
        _wrapR = GL_REPEAT;
        _maxAnisotropy = 1.0;

        MTLTextureDescriptor* desc = nil;
        switch (target) {
            case GL_TEXTURE_2D:
            case GL_TEXTURE_RECTANGLE:
                desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:_pixelFormat
                                                                          width:width
                                                                         height:height
                                                                      mipmapped:(_mipLevels > 1)];
                break;
            case GL_TEXTURE_CUBE_MAP:
            case GL_TEXTURE_CUBE_MAP_POSITIVE_X ... GL_TEXTURE_CUBE_MAP_NEGATIVE_Z:
                desc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:_pixelFormat
                                                                            size:width
                                                                       mipmapped:(_mipLevels > 1)];
                break;
            case GL_TEXTURE_3D:
                desc = [[MTLTextureDescriptor alloc] init];
                desc.textureType = MTLTextureType3D;
                desc.pixelFormat = _pixelFormat;
                desc.width = width;
                desc.height = height;
                desc.depth = depth;
                desc.mipmapLevelCount = _mipLevels;
                break;
            case GL_TEXTURE_2D_ARRAY:
                desc = [[MTLTextureDescriptor alloc] init];
                desc.textureType = MTLTextureType2DArray;
                desc.pixelFormat = _pixelFormat;
                desc.width = width;
                desc.height = height;
                desc.arrayLength = depth;
                desc.mipmapLevelCount = _mipLevels;
                break;
        }

        if (desc) {
            desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
            if (_pixelFormat == MTLPixelFormatInvalid) {
                NSLog(@"VBoxMetal3D: Invalid pixel format for texture %dx%d format=%x type=%x",
                      width, height, glFormat, glType);
                // Use a default format
                desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
                _pixelFormat = MTLPixelFormatBGRA8Unorm;
            }
            _metalTexture = [device newTextureWithDescriptor:desc];
        }
    }
    return self;
}

- (void)uploadData:(const void*)data
           mipLevel:(uint32_t)mipLevel
           offsetX:(uint32_t)offsetX
           offsetY:(uint32_t)offsetY
           offsetZ:(uint32_t)offsetZ
           width:(uint32_t)width
           height:(uint32_t)height
           depth:(uint32_t)depth
           format:(uint32_t)glFormat
           type:(uint32_t)glType {
    if (!data || !_metalTexture) return;

    NSUInteger bpp = 4; // default BGRA/RGBA
    if (glFormat == GL_RGB && glType == GL_UNSIGNED_SHORT_5_6_5) bpp = 2;
    else if (glFormat == GL_RED) bpp = 1;
    else if (glFormat == GL_RG) bpp = 2;
    else if (glFormat == GL_LUMINANCE) bpp = 1;
    else if (glFormat == GL_ALPHA) bpp = 1;
    else if (glFormat == GL_LUMINANCE_ALPHA) bpp = 2;
    else if (glType == GL_FLOAT) bpp = 16;
    else if (glType == GL_HALF_FLOAT) bpp = 8;

    NSUInteger bytesPerRow = width * bpp;

    MTLRegion region = MTLRegionMake3D(offsetX, offsetY, offsetZ, width, height, 1);
    for (uint32_t slice = 0; slice < (depth > 0 ? depth : 1); slice++) {
        region.origin.z = slice;
        const void* sliceData = (const uint8_t*)data + slice * bytesPerRow * height;
        // Note: For compressed or format-converted data, we'd use a compute shader
        [_metalTexture replaceRegion:region
                         mipmapLevel:mipLevel
                               slice:slice
                           withBytes:sliceData
                         bytesPerRow:bytesPerRow
                       bytesPerImage:bytesPerRow * height];
    }
}

- (void)generateMipmaps {
    if (_metalTexture && _mipLevels > 1) {
        id<MTLBlitCommandEncoder> blit = [[VBoxMetalGetGlobalContext() acquireCommandBuffer] blitCommandEncoder];
        [blit generateMipmapsForTexture:_metalTexture];
        [blit endEncoding];
    }
}

- (void)setTexParameter:(uint32_t)pname value:(CGFloat)value {
    switch (pname) {
        case GL_TEXTURE_MIN_FILTER: _minFilter = value; break;
        case GL_TEXTURE_MAG_FILTER: _magFilter = value; break;
        case GL_TEXTURE_WRAP_S:     _wrapS = value; break;
        case GL_TEXTURE_WRAP_T:     _wrapT = value; break;
        case GL_TEXTURE_WRAP_R:     _wrapR = value; break;
        case GL_TEXTURE_MAX_ANISOTROPY_EXT: _maxAnisotropy = value; break;
        default: break;
    }
}

+ (MTLPixelFormat)metalFormatFromGL:(uint32_t)glFormat glType:(uint32_t)glType {
    return MTLFormatFromGL(glFormat, glType);
}

- (void)dealloc {
    // MTLTexture will be released by ARC
}

@end
