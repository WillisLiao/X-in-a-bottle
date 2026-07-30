#include "CanvasCommon.h"
#include "BottleTypes.h"

// Lightning in a Bottle. The screen is the bottle, so the storm fills it and
// there is no vessel drawn anywhere.

constant float3 kSkyColor   = float3(0.020, 0.026, 0.048);
constant float3 kCloudColor = float3(0.115, 0.140, 0.235);
constant float3 kBoltColor  = float3(0.880, 0.930, 1.000);
constant float3 kFlashColor = float3(0.560, 0.700, 1.000);

fragment float4 lightning_fragment(CanvasVertexOut in [[stage_in]],
                                   constant LightningUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2(in.uv.x * aspect, in.uv.y);

    float3 col = srgb_to_linear(kSkyColor);

    // Cloud. Frequencies chosen the hard way in Lull: below about four cycles
    // across the screen a dark field is invisible no matter how bright it is,
    // because eye contrast sensitivity collapses at low spatial frequency.
    float cloud = canvas_fbm(p * 6.0 + float2(u.time * 0.014, -u.time * 0.021));
    cloud = mix(cloud, canvas_fbm(p * 14.0 - float2(u.time * 0.010, u.time * 0.016)), 0.38);
    cloud = smoothstep(0.30, 0.76, cloud);

    // Weighted toward the top, where the weather is. The bottom of the screen
    // stays open so a full-reach bolt has somewhere to arrive.
    float ceiling = 1.0 - smoothstep(0.05, 0.95, in.uv.y);
    float density = cloud * mix(0.35, 1.0, ceiling);

    // Only really visible when lit, which is what makes the dark between
    // strikes feel occupied rather than empty.
    col += srgb_to_linear(kCloudColor) * density * (0.10 + 2.4 * u.flash);

    if (u.boltAlpha > 0.0 && u.boltCount > 1) {
        float d = 1e9;
        for (int i = 0; i < u.boltCount - 1; i++) {
            float2 a = float2(u.boltPoints[i].x * aspect, u.boltPoints[i].y);
            float2 c = float2(u.boltPoints[i + 1].x * aspect, u.boltPoints[i + 1].y);
            d = min(d, canvas_segment_distance(p, a, c));
        }

        // A hot thin core inside a wide soft halo. Either alone reads as a wire
        // or as a smudge; it needs both.
        float core = exp(-(d * d) / 0.0000110);
        float halo = exp(-(d * d) / 0.0016);
        col += srgb_to_linear(kBoltColor) * (core * 0.95 + halo * 0.18) * u.boltAlpha;
    }

    // The whole sky lifting, not just the clouds.
    col += srgb_to_linear(kFlashColor) * u.flash * (0.020 + 0.030 * u.charge);

    col *= smoothstep(1.45, 0.35, distance(in.uv, float2(0.5, 0.42)));

    // Being touched or moved. The sky goes flat and cold, so the cost of
    // picking the phone up is visible the instant it happens.
    col *= 1.0 - 0.55 * u.disturbance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
