#include "CanvasCommon.h"
#include "BottleTypes.h"

// Genies in a Bottle. Small lights that arrive while the phone is left alone
// and busy themselves with work nobody can quite make out.
//
// The behaviour is real. The way a genie looks is not finished: these are soft
// flames with a suggestion of form, enough to judge the loop and nowhere near
// enough to sell a paid environment.

constant float3 kDarkColor  = float3(0.030, 0.024, 0.048);
constant float3 kHazeColor  = float3(0.130, 0.090, 0.180);
constant float3 kGenieColor = float3(0.980, 0.780, 0.420);
constant float3 kCoolColor  = float3(0.520, 0.820, 0.900);

fragment float4 genies_fragment(CanvasVertexOut in [[stage_in]],
                                constant GenieUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);

    // The earthquake displaces the whole world, not the genies individually,
    // because it is the bottle that is being shaken.
    float2 uv = in.uv + u.shake;
    float2 p = float2(uv.x * aspect, uv.y);

    float3 col = srgb_to_linear(kDarkColor);

    // Smoke they live in.
    float haze = canvas_fbm(p * 5.0 + float2(u.time * 0.02, -u.time * 0.03));
    haze = smoothstep(0.34, 0.80, haze);
    col += srgb_to_linear(kHazeColor) * haze * (0.030 + 0.050 * u.charge);

    for (int i = 0; i < u.count; i++) {
        float a = u.alphas[i];
        if (a <= 0.01) { continue; }

        float2 g = float2(u.positions[i].x * aspect, u.positions[i].y);
        float2 d = p - g;

        // Bobbing, each on its own phase so no two move in step.
        d.y += sin(u.time * 1.1 + u.phases[i]) * 0.006;

        // Taller than wide and pinched at the top, so it reads as a wisp with a
        // head rather than as a dot. The first attempt stretched this far too
        // far and every genie came out a vertical smear.
        float2 shaped = float2(d.x * 1.7, d.y * 1.0 + max(0.0, -d.y) * 0.7);
        float q = dot(shaped, shaped);

        // Tight bright heart inside a softer body, so there is something to
        // focus on rather than a cloud with no centre.
        float heart = exp(-q / 0.000045);
        float body  = exp(-q / 0.00035);
        float halo  = exp(-dot(d, d) / 0.0048);

        col += srgb_to_linear(kGenieColor) * (heart * 0.85 + body * 0.30) * a;
        col += srgb_to_linear(kCoolColor) * halo * a * 0.026;
    }

    col *= smoothstep(1.45, 0.40, distance(uv, float2(0.5)));
    col *= 1.0 - 0.30 * u.disturbance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
