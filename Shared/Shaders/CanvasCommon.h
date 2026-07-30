#ifndef CanvasCommon_h
#define CanvasCommon_h

#include <metal_stdlib>
using namespace metal;

// Shared by every fragment shader in this repo. These are the pieces that were
// expensive to get right once and would be expensive to get wrong again.

struct CanvasVertexOut {
    float4 position [[position]];
    float2 uv;
};

// Palettes are picked by eye in sRGB. Every drawable here is extended-linear
// Display P3, so nothing may be composited before it is converted.
static inline float3 srgb_to_linear(float3 c) {
    float3 lo = c / 12.92;
    float3 hi = pow((c + 0.055) / 1.055, float3(2.4));
    return select(lo, hi, c > float3(0.04045));
}

// Interleaved gradient noise, applied just before the panel quantises. Cheap,
// and quiet enough that it reads as film grain rather than a screen door.
// Without it, dark gradients band hard, which is the one flaw that cannot be
// hidden in an app that lives at the bottom of the value range.
static inline float canvas_dither(float2 frag) {
    return fract(52.9829189 * fract(dot(frag, float2(0.06711056, 0.00583715)))) - 0.5;
}

static inline float canvas_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

static inline float canvas_vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(canvas_hash(i),                   canvas_hash(i + float2(1.0, 0.0)), f.x),
               mix(canvas_hash(i + float2(0.0, 1.0)), canvas_hash(i + float2(1.0, 1.0)), f.x),
               f.y);
}

static inline float canvas_fbm(float2 p) {
    float v = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * canvas_vnoise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return v;
}

// Shortest distance from a point to a segment. The bolt is a polyline, so this
// is the whole of its rendering.
static inline float canvas_segment_distance(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

#endif /* CanvasCommon_h */
