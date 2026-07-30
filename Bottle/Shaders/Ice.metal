#include "CanvasCommon.h"
#include "BottleTypes.h"

// Ice in a Bottle. Angular blocks form one after another and stay, stacking up
// from the bottom. Moving the phone melts some of them away.

constant float3 kDeepColor = float3(0.020, 0.032, 0.055);
constant float3 kIceColor  = float3(0.520, 0.740, 0.870);
constant float3 kEdgeColor = float3(0.900, 0.970, 1.000);
constant float3 kMeltColor = float3(0.400, 0.620, 0.780);

static float sd_box(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

fragment float4 ice_fragment(CanvasVertexOut in [[stage_in]],
                             constant IceUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2(in.uv.x * aspect, in.uv.y);

    float3 col = srgb_to_linear(kDeepColor);

    float body = 0.0;
    float edge = 0.0;

    for (int i = 0; i < u.count; i++) {
        float a = u.alphas[i];
        if (a <= 0.01) { continue; }

        float2 c = float2(u.centers[i].x * aspect, u.centers[i].y);
        float2 d = p - c;

        // Cheap reject before the rotation and the box.
        if (dot(d, d) > 0.055) { continue; }

        float s = sin(u.rotations[i]);
        float k = cos(u.rotations[i]);
        float2 local = float2(d.x * k - d.y * s, d.x * s + d.y * k);

        // A block, not a crystal. Barely rounded corners, because ice broken
        // off a sheet has edges and this environment is the one that has to
        // look solid.
        // Not named `half`: that is a reserved type in Metal.
        float2 extent = float2(u.sizes[i].x * aspect, u.sizes[i].y);
        float sd = sd_box(local, extent, 0.012);

        // Forming blocks grow into place rather than fading in flat.
        float grow = mix(0.55, 1.0, a);
        sd += (1.0 - grow) * 0.05;

        float fill = 1.0 - smoothstep(-0.004, 0.004, sd);
        body = max(body, fill * a);

        // Bright line along the edge, where a real block catches light.
        edge = max(edge, exp(-abs(sd) / 0.006) * a);
    }

    // Internal fracture planes, only visible inside the ice, so a block has
    // depth instead of being a flat cut-out.
    float facet = canvas_fbm(p * 22.0 + float2(u.time * 0.008, 0.0));
    facet = smoothstep(0.40, 0.80, facet);

    col += srgb_to_linear(kIceColor) * body * (0.070 + 0.090 * facet);
    col += srgb_to_linear(kEdgeColor) * edge * 0.20;

    // Thawing. A wet sheen washes down the ice, so a disturbance looks like
    // loss rather than like dimming.
    if (u.melt > 0.0) {
        float wet = canvas_fbm(p * 9.0 - float2(0.0, u.time * 0.6));
        col += srgb_to_linear(kMeltColor) * u.melt * body * wet * 0.22;
        col += srgb_to_linear(kMeltColor) * u.melt * 0.008;
    }

    col *= smoothstep(1.45, 0.40, distance(in.uv, float2(0.5)));
    col *= 1.0 - 0.35 * u.disturbance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
