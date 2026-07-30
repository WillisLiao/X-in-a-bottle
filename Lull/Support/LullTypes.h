#ifndef LullTypes_h
#define LullTypes_h

#include <simd/simd.h>

// Shared by Drift.metal and Swift so a layout mismatch is a compile error
// rather than a silently corrupted frame.
//
// Field order keeps the two float2s first so the struct stays 8-byte aligned
// with no implicit padding.
typedef struct {
    vector_float2 resolution;
    vector_float2 lightPos;
    vector_float2 presencePos;

    float drift;
    float luminance;
    float saturation;
    float lightRadius;

    // Peak of the light in linear terms. Low by necessity: this is looked at
    // in a dark room, so anything approaching 1.0 reads as a lamp rather than
    // an ember and defeats the entire purpose.
    float lightIntensity;

    // The step the display quantises to, so the dither is sized to the panel
    // rather than to the framebuffer. Needs tuning on real hardware.
    float ditherAmount;

    // Reduce Motion scales the drifting field down rather than freezing it.
    float motionScale;

    // How strongly the fog thickens where something is hiding. Faint at a
    // distance so it has to be noticed rather than read, stronger as the ember
    // closes in so approaching it feels like confirmation.
    float presenceHint;

    // 0 when nothing is resolving, then 0 to 1 across the bloom.
    float presenceResolve;
} LullUniforms;

#endif /* LullTypes_h */
