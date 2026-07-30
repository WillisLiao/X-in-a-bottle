#include "CanvasCommon.h"
#include "BottleTypes.h"

// Elves in a Bottle. They arrive one at a time and stay, busying themselves
// with work nobody can quite make out. An earthquake sends some of them
// fleeing.
//
// A elf is built from a head, a torso, two arms and a tail that curls away
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

/// An elf in its own space: y up, roughly 1 unit from heel to hat.
///
/// Slight of build, long pointed hat, pointed ear, and legs rather than the
/// smoke tail a genie had. The silhouette is doing all the work here, so the
/// proportions matter more than any of the shading below.
static float sd_elf(float2 q, float t) {
    // Head, small relative to the body.
    float d = length(q - float2(0.0, 0.60)) - 0.105;

    // Pointed ear, swept back.
    d = smin(d, sd_taper(q, float2(-0.06, 0.62),
                            float2(-0.19, 0.72), 0.038, 0.004), 0.02);

    // Long hat leaning with the sway, which is most of what makes it an elf
    // rather than a small person.
    float lean = sin(t * 0.6) * 0.05;
    d = smin(d, sd_taper(q, float2(0.0, 0.66),
                            float2(0.10 + lean, 0.86), 0.095, 0.045), 0.04);
    d = smin(d, sd_taper(q, float2(0.10 + lean, 0.86),
                            float2(0.20 + lean * 2.0, 1.00), 0.045, 0.008), 0.03);

    // Torso, narrow shoulders tapering to the waist.
    d = smin(d, sd_taper(q, float2(0.0, 0.50), float2(0.0, 0.14), 0.115, 0.080), 0.05);

    // Arms, drifting as if working at something.
    float swing = sin(t * 0.9) * 0.07;
    d = smin(d, sd_taper(q, float2(0.0, 0.44),
                            float2(0.20, 0.24 + swing), 0.042, 0.022), 0.04);
    d = smin(d, sd_taper(q, float2(0.0, 0.44),
                            float2(-0.19, 0.20 - swing), 0.042, 0.022), 0.04);

    // Legs, one stepping.
    float step = sin(t * 1.3) * 0.05;
    d = smin(d, sd_taper(q, float2(0.0, 0.16),
                            float2(0.09 + step, -0.24), 0.055, 0.028), 0.045);
    d = smin(d, sd_taper(q, float2(0.0, 0.16),
                            float2(-0.08 - step, -0.24), 0.055, 0.028), 0.045);

    return d;
}

fragment float4 elves_fragment(CanvasVertexOut in [[stage_in]],
                                constant ElfUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);

    // The earthquake displaces the whole world, not each elf, because it is
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

        float sd = sd_elf(q, u.time + u.phases[i]) * scale;

        float bodyMask = 1.0 - smoothstep(0.0, 0.006, sd);

        // Form. A flat silhouette reads as a paper cut-out no matter how well
        // the outline is drawn, so the body is lit from the upper left and
        // falls away to the lower right. Cheap: a direction, not a normal.
        float2 fromCore = q - float2(0.0, 0.34);
        float lit = 0.52 + 0.48 * dot(normalize(float2(-0.55, 0.84)),
                                      normalize(fromCore + 1e-4));

        // Rim along the silhouette, brightest where the light strikes it.
        float rim = exp(-abs(sd) / 0.005) * (0.35 + 0.65 * lit);

        float heart = exp(-pow(max(sd, 0.0) / 0.012, 2.0));
        // Reach kept well inside the reject radius above. At 0.055 the glow was
        // still meaningful past the cutoff and every elf sat in a visible
        // circular disc, which is the same mistake as an unpadded bounding box.
        float lantern = exp(-max(sd, 0.0) / 0.028);

        col += srgb_to_linear(kBodyColor) * bodyMask * a * (0.055 + 0.150 * lit);
        col += srgb_to_linear(kCoreColor) * rim * a * 0.075;
        col += srgb_to_linear(kCoreColor) * heart * a * 0.035;
        col += srgb_to_linear(kBodyColor) * lantern * a * 0.030;
    }

    col *= smoothstep(1.45, 0.40, distance(uv, float2(0.5)));
    col *= 1.0 - 0.30 * u.disturbance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
