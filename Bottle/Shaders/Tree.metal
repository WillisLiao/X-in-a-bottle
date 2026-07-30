#include "CanvasCommon.h"
#include "BottleTypes.h"

// Tree in a Bottle. Branches grow out of branches while the phone is left
// alone, and a disturbance cuts limbs off.

constant float3 kNightColor = float3(0.026, 0.030, 0.046);
constant float3 kBarkColor  = float3(0.360, 0.280, 0.230);
constant float3 kLeafColor  = float3(0.380, 0.720, 0.420);
constant float3 kLeafLight  = float3(0.720, 0.920, 0.560);
constant float3 kMoonColor  = float3(0.560, 0.680, 0.900);

/// Tapered capsule: the whole of a branch.
static float sd_branch(float2 p, float2 a, float2 b, float ra, float rb) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h) - mix(ra, rb, h);
}

fragment float4 tree_fragment(CanvasVertexOut in [[stage_in]],
                              constant TreeUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / max(u.resolution.y, 1.0);
    float2 p = float2(in.uv.x * aspect, in.uv.y);

    float3 col = srgb_to_linear(kNightColor);

    // Moonlight from above, so the canopy has a top and a bottom rather than
    // being flatly lit. Cheap, and it does most of the work of making the tree
    // look like an object with volume.
    float sky = 1.0 - smoothstep(0.0, 0.9, in.uv.y);
    col += srgb_to_linear(kMoonColor) * sky * 0.012;

    float bark = 0.0;
    float leaf = 0.0;
    float leafLit = 0.0;

    for (int i = 0; i < u.count; i++) {
        float a = u.alphas[i];
        if (a <= 0.01) { continue; }

        float2 s = float2(u.starts[i].x * aspect, u.starts[i].y);
        float2 e = float2(u.ends[i].x * aspect, u.ends[i].y);

        // Sway. Anchored at the start and full at the tip, so branches bend
        // rather than slide, and each on its own phase so the canopy is not
        // one rigid piece.
        float swayAmount = 0.006 * (1.0 + float(i) * 0.02);
        e.x += sin(u.time * 0.55 + u.phases[i]) * swayAmount;

        // A branch still growing is drawn short rather than faded, so growth
        // reads as extension instead of as something switching on.
        e = mix(s, e, clamp(a * 1.3, 0.0, 1.0));

        float d = sd_branch(p, s, e, u.widthStart[i], u.widthEnd[i]);
        bark = max(bark, (1.0 - smoothstep(-0.002, 0.003, d)) * a);

        float foliage = u.leaves[i];
        if (foliage > 0.01) {
            // A cluster at the tip, broken up hard by noise so it reads as many
            // small leaves rather than one green blob, which is what a bigger
            // radius and gentler noise gave on the first attempt.
            float dl = distance(p, e);
            float radius = 0.034;
            float clump = canvas_fbm(p * 90.0 + float2(u.phases[i] * 7.0, u.time * 0.05));
            clump = smoothstep(0.34, 0.72, clump);
            float mask = 1.0 - smoothstep(radius * (0.20 + 0.80 * clump), radius, dl);
            mask *= foliage;

            leaf = max(leaf, mask);
            // Lit from above: leaves on the upper side of the cluster catch it.
            leafLit = max(leafLit, mask * smoothstep(0.02, -0.03, p.y - e.y));
        }
    }

    col += srgb_to_linear(kBarkColor) * bark * 0.075;
    col += srgb_to_linear(kLeafColor) * leaf * 0.085;
    col += srgb_to_linear(kLeafLight) * leafLit * 0.075;

    // A cut. The tree flashes pale where it has been taken from, and a wash of
    // falling leaves drifts down the screen.
    if (u.cut > 0.0) {
        float fall = canvas_fbm(float2(p.x * 18.0, p.y * 7.0 - u.time * 1.6));
        fall = smoothstep(0.62, 0.92, fall);
        col += srgb_to_linear(kLeafColor) * fall * u.cut * 0.035;
        col += srgb_to_linear(kLeafLight) * leaf * u.cut * 0.10;
    }

    col *= smoothstep(1.50, 0.42, distance(in.uv, float2(0.5, 0.58)));
    col *= 1.0 - 0.30 * u.disturbance;

    col += canvas_dither(in.position.xy) * u.ditherAmount;

    return float4(max(col, float3(0.0)), 1.0);
}
