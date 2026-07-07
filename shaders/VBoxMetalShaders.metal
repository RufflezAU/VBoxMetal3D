#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// ─── Fullscreen blit vertex shader ───────────────────────────────────────────

struct BlitVertex {
    float4 position [[position]];
    float2 texcoord;
};

vertex BlitVertex blitVertex(uint vertexID [[vertex_id]]) {
    BlitVertex out;
    // Generate full-screen triangle (3 vertices covering clip space)
    float2 uv = float2((vertexID << 1) & 2, vertexID & 2);
    out.position = float4(uv * 2.0 - 1.0, 0.0, 1.0);
    out.texcoord = uv;
    return out;
}

fragment float4 blitFragment(BlitVertex in [[stage_in]],
                             texture2d<float> source [[texture(0)]],
                             sampler linearSampler [[sampler(0)]]) {
    return source.sample(linearSampler, in.texcoord);
}

// ─── YCbCr->RGB conversion shader (for video playback) ──────────────────────

struct YCbCrVertex {
    float4 position [[position]];
    float2 texcoord;
};

fragment float4 ycbcrFragment(YCbCrVertex in [[stage_in]],
                               texture2d<float> lumaTexture [[texture(0)]],
                               texture2d<float> chromaTexture [[texture(1)]],
                               sampler linearSampler [[sampler(0)]]) {
    float3 ycbcr = float3(
        lumaTexture.sample(linearSampler, in.texcoord).r,
        chromaTexture.sample(linearSampler, in.texcoord).rg
    );
    // BT.601 conversion
    float3 rgb = float3(
        dot(ycbcr, float3(1.0, 0.0, 1.402)),
        dot(ycbcr, float3(1.0, -0.344, -0.714)),
        dot(ycbcr, float3(1.0, 1.772, 0.0))
    );
    return float4(rgb, 1.0);
}

// ─── Color conversion / format conversion compute shader ─────────────────────

kernel void convertBGRAtoRGBA(texture2d<float, access::read> source [[texture(0)]],
                               texture2d<float, access::write> dest [[texture(1)]],
                               uint2 gid [[thread_position_in_grid]]) {
    float4 color = source.read(gid);
    dest.write(color, gid);
}

kernel void convertRGBAToBGRA(texture2d<float, access::read> source [[texture(0)]],
                               texture2d<float, access::write> dest [[texture(1)]],
                               uint2 gid [[thread_position_in_grid]]) {
    float4 color = source.read(gid);
    dest.write(float4(color.b, color.g, color.r, color.a), gid);
}

// ─── Simple solid-color clear compute shader ─────────────────────────────────

kernel void clearTexture(texture2d<float, access::write> tex [[texture(0)]],
                          constant float4* clearColor [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    tex.write(*clearColor, gid);
}

// ─── Alpha blending composite ───────────────────────────────────────────────

kernel void compositeAlpha(texture2d<float, access::read> dest [[texture(0)]],
                            texture2d<float, access::read> src [[texture(1)]],
                            texture2d<float, access::write> out [[texture(2)]],
                            uint2 gid [[thread_position_in_grid]]) {
    float4 srcColor = src.read(gid);
    float4 dstColor = dest.read(gid);
    float4 result = srcColor + dstColor * (1.0 - srcColor.a);
    out.write(result, gid);
}
