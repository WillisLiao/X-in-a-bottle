#include "CanvasCommon.h"
#include "BottleTypes.h"

// Genies in a Bottle. They arrive one at a time and stay, busying themselves
// with work nobody can quite make out. An earthquake sends some of them
// fleeing.
//
// A genie is built from a head, a torso, two arms and a tail that curls away
// into smoke. The previous attempt was a bright dot with a halo, which is not
// a character.

constant float3 kDarkColor  = float3(0.030, 0.024, 0.048);
constant float3 kHazeColor  = float3(0.130, 0.090, 0.180);
constant float3 kBodyColor  = float3(0.520, 0.880, 0.820);
constant float3 kCoreColor  = float3(0.940, 1.000, 0.900);

/// Capsule that tapers from one radius to the other.
static float sd_taper(float2 p, float2 a, float2 b, float ra, float rb) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h) - mix(ra, rb, h);
}

/// Smooth union, so the parts read as one creature rather than as assembled
/// sausages.
static float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

/// A genie in its own space: y up, roughly 1 unit from tail to crown.
static float sd_genie(float2 q, float t) {
    // Head.
    float d = length(q - float2(0.0, 0.70)) - 0.135;

    // Torso, wide at the shoulders and narrowing to the waist.
    d = smin(d, sd_taper(q, float2(0.0, 0.55), float2(0.0, 0.10), 0.155, 0.105), 0.07);

    // Arms, drifting slightly, as if working at something.
    float swing = sin(t * 0.9) * 0.06;
    d = smin(d, sd_taper(q, float2(0.0, 0.44),
                            float2(0.26, 0.30 + swing), 0.055, 0.028), 0.05);
    d = smin(d, sd_taper(q, float2(0.0, 0.44),
                            float2(-0.24, 0.26 - swing), 0.055, 0.028), 0.05);

    // Tail curling away into smoke instead of legs.
    float curl = sin(t * 0.7) * 0.05;
    d = smin(d, sd_taper(q, float2(0.0, 0.12),
                            float2(0.14 + curl, -0.24), 0.105, 0.055), 0.06);
    d = smin(d, sd_taper(q, float2(0.14 + curl, -0.24),
                            float2(-0.10 + curl, -0.52), 0.055, 0.012), 0.05);

    return d;
}

fragment float4 genies_fragment(CanvasVertexOut in [[stage_in]],
                                constant GenieUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);

    // The earthquake displaces the whole world, not each genie, because it is
    // the bottle that is being shaken.
    float2 uv = in.uv + u.shake;
    float2 p = float2(uv.x * aspect, uv.y);

    float3 col = srgb_to_linear(kDarkColor);

    float haze = canvas_fbm(p * 5.0 + float2(u.time * 0.02, -u.time * 0.03));
    haze = smoothstep(0.34, 0.80, haze);
    col += srgb_to_linear(kHazeColor) * haze * (0.030 + 0.055 * u.charge);

    for (int i = 0; i < u.count; i++) {
        float a = u.alphas[i];
        if (a <= 0.01) { continue; }

        float2 g = float2(u.positions[i].x * aspect, u.positions[i].y);
        float2 d = p - g;

        if (dot(d, d) > 0.045) { continue; }

        float scale = u.scales[i];
        float bob = sin(u.time * 1.05 + u.phases[i]) * 0.008;

        // Local space: y up, flipped by facing, sized by scale.
        float2 q = float2(d.x * u.facings[i], -(d.y + bob)) / scale;

        float sd = sd_genie(q, u.time + u.phases[i]) * scale;

        // A lit body with a brighter heart showing through it, and a lantern
        // glow thrown onto the smoke around.
        float bodyMask = 1.0 - smoothstep(0.0, 0.006, sd);
        float heart = exp(-pow(max(sd, 0.0) / 0.012, 2.0));
        // Reach kept well inside the reject radius above. At 0.055 the glow was
        // still meaningful past the cutoff and every genie sat in a visible
        // circular disc, which is the same mistake as an unpadded bounding box.
        float lantern = exp(-max(sd, 0.0) / 0.028);

        col += srgb_to_linear(kBodyColor) * bodyMask * a * 0.16;
        col += srgb_to_linear(kCoreColor) * heart * a * 0.10;
        col += srgb_to_linear(kBodyColor) * lantern * a * 0.035;
    }

    col *= smoothstep(1.45, 0.40, distance(uv, float2(0.5)));
    col *= 1.0 - 0.30 * u.disturbance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
