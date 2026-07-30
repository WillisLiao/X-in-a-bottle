#include "CanvasCommon.h"
#include "BottleTypes.h"

// Lightning in a Bottle. Bolts are caught and kept, suspended in the dark,
// breathing. The bottle fills with them.

constant float3 kSkyColor   = float3(0.020, 0.026, 0.048);
constant float3 kHazeColor  = float3(0.110, 0.135, 0.230);
constant float3 kBoltColor  = float3(0.880, 0.930, 1.000);
constant float3 kGlowColor  = float3(0.480, 0.660, 1.000);

fragment float4 lightning_fragment(CanvasVertexOut in [[stage_in]],
                                   constant LightningUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2(in.uv.x * aspect, in.uv.y);

    float3 col = srgb_to_linear(kSkyColor);

    // Haze the bolts hang in. Lifts as the bottle fills, so a full one feels
    // charged even in the gaps between the filaments.
    float haze = canvas_fbm(p * 6.0 + float2(u.time * 0.012, -u.time * 0.018));
    haze = smoothstep(0.32, 0.78, haze);
    col += srgb_to_linear(kHazeColor) * haze * (0.030 + 0.070 * u.charge);

    for (int b = 0; b < u.count; b++) {
        float a = u.alphas[b];
        if (a <= 0.01) { continue; }

        // Skip a bolt this pixel is nowhere near. Without this the loop is
        // 12 bolts by 8 segments for every pixel on screen. Bounds arrive in
        // the same aspect-corrected space as p, so they are compared with p.
        if (p.x < u.boundsMin[b].x || p.x > u.boundsMax[b].x ||
            p.y < u.boundsMin[b].y || p.y > u.boundsMax[b].y) { continue; }

        float d = 1e9;
        for (int i = 0; i < kBoltPoints - 1; i++) {
            float2 s = u.points[b * kBoltPoints + i];
            float2 e = u.points[b * kBoltPoints + i + 1];
            d = min(d, canvas_segment_distance(p,
                        float2(s.x * aspect, s.y),
                        float2(e.x * aspect, e.y)));
        }

        // Held lightning is not steady. Each filament breathes on its own
        // phase, so a full bottle looks alive rather than like a photograph.
        float breathe = 0.72 + 0.28 * sin(u.time * 2.1 + u.phases[b]);

        // A hot thin core inside a wide soft halo. Either alone reads as a
        // wire or as a smudge; it needs both.
        float core = exp(-(d * d) / 0.0000090);
        float halo = exp(-(d * d) / 0.0022);

        col += srgb_to_linear(kBoltColor) * core * a * breathe * 0.95;
        col += srgb_to_linear(kGlowColor) * halo * a * breathe * 0.10;
    }

    // The moment one is caught, the whole bottle lifts.
    col += srgb_to_linear(kGlowColor) * u.arrival * 0.045;

    col *= smoothstep(1.45, 0.38, distance(in.uv, float2(0.5)));

    // Being touched or moved. Everything goes flat and cold, so the cost of
    // picking the phone up is visible the instant it happens.
    col *= 1.0 - 0.55 * u.disturbance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
