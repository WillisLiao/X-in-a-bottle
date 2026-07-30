#ifndef BottleTypes_h
#define BottleTypes_h

#include <simd/simd.h>

// The phone is the bottle. Nothing draws a vessel: every environment fills the
// screen edge to edge and the glass is the one you are holding.
//
// The rule every environment obeys: things are CAUGHT AND KEPT. Stillness adds
// another object to the bottle and it stays there. Disturbance takes some away.
// Nothing here is an event that flashes and vanishes, because a bottle you
// cannot see filling is not a bottle.

#define kMaxBolts   12
#define kBoltPoints 9
#define kMaxBlocks  20
#define kMaxElves   14
#define kMaxBranches 44

typedef struct {
    vector_float2 resolution;

    // kMaxBolts polylines laid end to end, kBoltPoints each.
    vector_float2 points[kMaxBolts * kBoltPoints];

    // Per-bolt bounds, so a pixel can skip a bolt it is nowhere near. Without
    // this the inner loop is 12 bolts x 8 segments for every pixel on screen.
    vector_float2 boundsMin[kMaxBolts];
    vector_float2 boundsMax[kMaxBolts];

    float alphas[kMaxBolts];

    // Each captured bolt breathes on its own phase, so a full bottle looks
    // alive rather than like a photograph of wires.
    float phases[kMaxBolts];

    float time;
    float charge;
    float disturbance;

    // Brief bloom as a new bolt is caught.
    float arrival;

    float ditherAmount;
    int count;
} LightningUniforms;

typedef struct {
    vector_float2 resolution;

    vector_float2 centers[kMaxBlocks];
    vector_float2 sizes[kMaxBlocks];
    float rotations[kMaxBlocks];
    float alphas[kMaxBlocks];

    float time;
    float charge;
    float disturbance;

    // Spikes when the phone moves, and drives the wet sheen of melting.
    float melt;

    float ditherAmount;
    int count;
} IceUniforms;

typedef struct {
    vector_float2 resolution;

    vector_float2 positions[kMaxElves];
    float phases[kMaxElves];
    float alphas[kMaxElves];
    float scales[kMaxElves];

    // -1 or 1. Which way an elf is facing.
    float facings[kMaxElves];

    // Screen displacement during an earthquake.
    vector_float2 shake;

    float time;
    float charge;
    float disturbance;
    float ditherAmount;
    int count;
} ElfUniforms;

typedef struct {
    vector_float2 resolution;

    // Every branch is a tapered segment. The trunk is branch 0.
    vector_float2 starts[kMaxBranches];
    vector_float2 ends[kMaxBranches];
    float widthStart[kMaxBranches];
    float widthEnd[kMaxBranches];
    float alphas[kMaxBranches];

    // How much foliage sits at this branch's tip. Only outer branches carry it.
    float leaves[kMaxBranches];

    // Sway phase, so the canopy does not move as one rigid piece.
    float phases[kMaxBranches];

    float time;
    float charge;
    float disturbance;

    // Spikes when a cut happens, and drives the falling leaves.
    float cut;

    float ditherAmount;
    int count;
} TreeUniforms;

#endif /* BottleTypes_h */
