#include "CanvasCommon.h"

// One vertex function for every screen in this repo.
//
// The triangle deliberately overshoots: p spans 0..2, so NDC spans -1..3 and
// the visible screen is only the p = 0..1 part. UV therefore maps straight from
// p, not from p * 0.5. Getting that wrong puts the whole coordinate space at
// half scale and drops everything into a corner, which is exactly what happened
// the first time and cost an afternoon to find.
vertex CanvasVertexOut canvas_vertex(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);

    CanvasVertexOut out;
    out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    out.uv = float2(p.x, 1.0 - p.y);
    return out;
}
