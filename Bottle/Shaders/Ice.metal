#include "CanvasCommon.h"
#include "BottleTypes.h"

// Ice in a Bottle. Crystals nucleate and creep outward while the phone is left
// alone, and thaw when it is not.

constant float3 kDeepColor  = float3(0.020, 0.032, 0.055);
constant float3 kIceColor   = float3(0.640, 0.820, 0.920);
constant float3 kEdgeColor  = float3(0.880, 0.960, 1.000);
constant float3 kMeltColor  = float3(0.400, 0.620, 0.780);

fragment float4 ice_fragment(CanvasVertexOut in [[stage_in]],
                             constant IceUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2(in.uv.x * aspect, in.uv.y);

    float3 col = srgb_to_linear(kDeepColor);

    // Strongest crystal covering this pixel, and how close it is to an edge.
    float body = 0.0;
    float edge = 0.0;

    for (int i = 0; i < u.count; i++) {
        float r = u.radii[i];
        if (r <= 0.0005) { continue; }

        float2 s = float2(u.seeds[i].x * aspect, u.seeds[i].y);
        float2 d = p - s;
        float dist = length(d);
        if (dist > r * 1.6) { continue; }

        // A slow breathing so the ice never looks like a frozen screenshot.
        float breathe = 1.0 + 0.02 * sin(u.time * 0.5 + float(i));
        float reach = r * breathe;
        float norm = dist / max(reach, 1e-4);

        // Six-fold symmetry, as thin spurs rather than as lobes on a disc.
        // Modulating a circle's radius by cos(6θ) - the obvious approach - gives
        // fat rounded petals that read as a flower, which is exactly what the
        // first attempt looked like. Folding the angle into a wedge and putting
        // a narrow gaussian across it gives arms that actually taper.
        float theta = atan2(d.y, d.x) + canvas_hash(u.seeds[i]) * 6.2831853;
        float sector = abs(fract(theta * 6.0 / 6.2831853) - 0.5) * 2.0;

        float arm = exp(-(sector * sector) / 0.026) * (1.0 - smoothstep(0.12, 1.0, norm));

        // Barbs branching off each spur, close to the middle, which is what
        // separates frost from a plain star.
        float barb = exp(-(sector * sector) / 0.34)
            * (1.0 - smoothstep(0.0, 0.42, norm)) * 0.55;

        // A small hard hexagonal heart. Crisp on purpose: everything else here
        // is soft, and ice needs at least one edge you could cut yourself on.
        float core = 1.0 - smoothstep(0.14, 0.18, norm);

        float fill = clamp(max(core, max(arm, barb)), 0.0, 1.0);
        body = max(body, fill);

        // Bright line right at the growing front, where real frost is thickest.
        edge = max(edge, fill * exp(-pow((norm - 0.55) / 0.30, 2.0)));
    }

    // Internal facets. Only visible inside the ice, so the crystal has depth
    // instead of being a flat cut-out.
    float facet = canvas_fbm(p * 26.0 + float2(u.time * 0.01, 0.0));
    facet = smoothstep(0.42, 0.78, facet);

    col += srgb_to_linear(kIceColor) * body * (0.055 + 0.075 * facet);
    col += srgb_to_linear(kEdgeColor) * edge * 0.16;

    // Thawing. A wet sheen washes across the ice, brightest where it is
    // thinnest, so a disturbance looks like loss rather than like dimming.
    if (u.melt > 0.0) {
        float wet = canvas_fbm(p * 9.0 - float2(0.0, u.time * 0.6));
        col += srgb_to_linear(kMeltColor) * u.melt * body * wet * 0.20;
        col += srgb_to_linear(kMeltColor) * u.melt * (1.0 - body) * 0.010;
    }

    col *= smoothstep(1.45, 0.40, distance(in.uv, float2(0.5)));
    col *= 1.0 - 0.35 * u.disturbance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
