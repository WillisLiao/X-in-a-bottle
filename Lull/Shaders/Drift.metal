#include "CanvasCommon.h"
#include "LullTypes.h"

// The world. A slow drifting fog, a warm ember you steer, and things hiding in
// the fog that resolve when you reach them.

constant float3 kVoidColor = float3(0.016, 0.020, 0.043);
constant float3 kMidColor  = float3(0.120, 0.140, 0.240);
constant float3 kWarmColor = float3(0.980, 0.800, 0.580);

// Deliberately cool, so a found thing never reads as more of the ember.
constant float3 kPaleColor = float3(0.720, 0.860, 0.980);

fragment float4 drift_fragment(CanvasVertexOut in [[stage_in]],
                               constant LullUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2(in.uv.x * aspect, in.uv.y);

    float d = u.drift * u.motionScale;

    // Frequencies matter more than brightness here. At the original 2.2 the
    // base octave gave under one cycle across a 0.46-wide domain: a gradient
    // gradual enough to sit below the eye's contrast sensitivity, which is
    // already poor at low spatial frequency and far worse in the dark. It
    // measured 28/255 of spread and was still invisible on device.
    float field = canvas_fbm(p * 7.0 + float2(d * 0.18, -d * 0.30));
    field = mix(field, canvas_fbm(p * 16.0 - float2(d * 0.09, d * 0.15)), 0.35);

    // Four octaves of value noise cluster around the middle and never reach 0
    // or 1, so the raw field only used about half the palette range.
    field = smoothstep(0.28, 0.72, field);

    float2 lp = float2(u.lightPos.x * aspect, u.lightPos.y);
    float ld = distance(p, lp);
    float glow = exp(-(ld * ld) / max(u.lightRadius * u.lightRadius, 1e-4));

    float3 col = mix(srgb_to_linear(kVoidColor), srgb_to_linear(kMidColor), field);
    col += srgb_to_linear(kWarmColor) * glow * u.lightIntensity * (0.55 + 0.45 * field);

    // Something hiding in the fog. Never a marker: just a thickening, faint
    // enough at range that it has to be noticed rather than read.
    float2 pp = float2(u.presencePos.x * aspect, u.presencePos.y);
    float pd = distance(p, pp);
    col += srgb_to_linear(kPaleColor) * exp(-(pd * pd) / 0.020) * u.presenceHint;

    // Reaching it. A ring that opens outward and thins as it goes, so the fog
    // closing over it is the same gesture as it arriving.
    if (u.presenceResolve > 0.0) {
        float r = 0.02 + u.presenceResolve * 0.17;
        float edge = (pd - r) / 0.020;
        float ring = exp(-edge * edge) * (1.0 - u.presenceResolve);
        col += srgb_to_linear(kPaleColor) * ring * 0.12;
    }

    col *= smoothstep(1.15, 0.35, distance(in.uv, float2(0.5)));

    float lum = dot(col, float3(0.2126, 0.7152, 0.0722));
    col = mix(float3(lum), col, u.saturation);
    col *= u.luminance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
