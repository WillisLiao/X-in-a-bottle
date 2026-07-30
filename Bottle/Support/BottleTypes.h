#ifndef BottleTypes_h
#define BottleTypes_h

#include <simd/simd.h>

// The phone is the bottle. Nothing here draws a vessel: every environment fills
// the screen edge to edge, and the glass is the one you are holding.

// A bolt is a polyline built by midpoint displacement, four passes deep.
// Two points become 3, 5, 9, then 17.
#define kMaxBoltPoints 17
#define kMaxCrystals   26
#define kMaxGenies     22

typedef struct {
    vector_float2 resolution;

    // Normalised view space, origin top left. Only the first boltCount count.
    vector_float2 boltPoints[kMaxBoltPoints];

    float time;

    // The sky lighting up. Decays slowly, so the afterglow outlasts the bolt
    // exactly as it does in a real storm.
    float flash;

    // The bolt itself. Decays fast, because a strike is over long before the
    // light it threw has finished fading.
    float boltAlpha;

    // How full the bottle is, 0 to 1.
    float charge;

    // Rises while the phone is touched or moved.
    float disturbance;

    float ditherAmount;
    int boltCount;
} LightningUniforms;

typedef struct {
    vector_float2 resolution;

    // Crystal seeds, and how far each has grown.
    vector_float2 seeds[kMaxCrystals];
    float radii[kMaxCrystals];

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

    vector_float2 positions[kMaxGenies];

    // Bobbing offset, so no two drift in step.
    float phases[kMaxGenies];

    // Fades in on arrival and out on fleeing, so nothing ever pops.
    float alphas[kMaxGenies];

    float time;
    float charge;
    float disturbance;

    // Screen displacement during an earthquake.
    vector_float2 shake;

    float ditherAmount;
    int count;
} GenieUniforms;

#endif /* BottleTypes_h */
