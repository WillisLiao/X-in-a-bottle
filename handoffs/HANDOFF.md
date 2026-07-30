# Handoff - two apps

Read this first.
Update the top section at the end of each session.
Dated detail goes in `devlogs/`, not here.

## Repo shape

One xcodegen project, two independent iOS apps that share a rendering layer.
`Lull.xcodeproj` is disposable: run `xcodegen generate` after adding files.

```
Shared/     MetalCanvas, CanvasRenderer, canvas_vertex, colour and dither helpers
Lull/       the sleep app
Bottle/     the focus app
```

`Shared/` exists because the four things that were expensive to get wrong once
live there and are not written twice: the extended-linear Display P3 drawable,
the overshooting fullscreen triangle, sRGB to linear conversion, and the dither.

Signing: team `45MSS5RXML`, automatic, in `project.yml`.
Both apps build for device and are installed on the test iPhone 15 Pro.

## Lull

A game engineered to make you stop playing it, so you can fall asleep.

No streaks, no score, no fail state, no notifications (the permission is never
requested). You steer a warm ember through fog. Over twenty minutes the world
slows, dims and quietens, and after ninety seconds without a touch the ember
picks its own heading, drifts on without you, and fades to true black.

Things hide in the fog and resolve when you reach them. Nothing is ever kept:
there is no collection and no count, and there never will be.

**Verified:** fade measured by mean frame luminance, 19.07 while steering,
12.71 after letting go, 4.21 mid-fade, 0.00 at the end, then the view pauses.

## Bottle - "X in a Bottle"

A focus app. **The phone is the bottle**, so nothing draws a vessel: every
environment fills the screen edge to edge and the glass is the one in your hand.

Leave the phone alone and the bottle fills. Touch the screen or move it and it
drains, twelve times faster than it fills. A ten second glance at a notification
costs two minutes of focus. That asymmetry is the entire mechanism.

There is no interaction. Touching is only ever a disturbance, which is the point.

Swipe left and right for environments. Each expresses the same charge and the
same disturbance in its own idiom.

| environment | charge is | disturbance is |
| --- | --- | --- |
| **Lightning in a Bottle** (free) | strike frequency and reach | the storm blown flat |
| **Ice in a Bottle** (paid) | crystals nucleating and creeping | a thaw, with a wet sheen |
| **Genies in a Bottle** (paid) | how many have arrived | an earthquake, and some flee |

Freemium by non-consumable IAP per environment. Bought once, kept forever.
That is not in tension with the no-subscription rule: the rule is no recurring
billing, not no money.

Guided Access is the intended companion: the user triple-clicks the side button
to lock themselves in. **The app cannot do this itself** -
`UIAccessibility.requestGuidedAccessSession` only works on supervised MDM
devices, so all we can do is teach the gesture. That is better anyway: choosing
to lock yourself in is a commitment device, being trapped is a dark pattern.

**Verified in simulator** with the fill time temporarily cut to 10 seconds. All
three environments render at full charge. Lightning measured 7.59 quiet and
55.39 during a strike.

## Next

**Both**
1. Look at both on a real OLED in a dark room. Everything else is guesswork.
2. `git init`. Still not a repo.
3. Real names and bundle IDs. `Bottle` and `com.lull.bottle` are placeholders,
   and "Lull" is very likely taken on the App Store.

**Lull**
4. Audio on the decay curve, so sound and image wind down together.
5. The resolve moment needs to become something worth reaching: right now it is
   a pale ring, not a small beautiful thing.
6. Play it in bed at 3am. The only test that matters is whether the phone gets
   put down.

**Bottle**
7. **Bolts need branches.** A single polyline still reads as one strand rather
   than lightning. Biggest visual gap in the free environment, which is the one
   everybody sees first.
8. **Genies are placeholder art.** The behaviour is real - they arrive, wander,
   work at nothing in particular, and flee in an earthquake - but they are soft
   wisps, not characters. This is a paid environment, so it cannot ship looking
   like this. Needs real character design, not another shader tweak.
9. Thunder, delayed after the flash and quieter with distance.
10. Tune `agitationThreshold` (0.035) against real desks. A phone on a wobbly
    table must not drain, a phone being picked up must.
11. Nothing marks which environment you are on, or that others exist. The swipe
    is currently undiscoverable.
12. StoreKit 2 for the paid environments. Nothing is gated yet - all three are
    reachable.
13. Decide what happens at a full bottle. Currently nothing, it just stays full.

## Decisions worth not relitigating

- **One-time purchase, never a subscription**, in both. A sleep product that
  bills monthly is self-refuting, and so is a focus product.
- **No clinical claims in Lull, ever.** It is harm reduction against
  doomscrolling, not a treatment for insomnia. Medical framing is both an App
  Store risk and a credibility risk.
- **No AI in the marketing copy.** r/iosapps rule 6 is No AI, and every
  AI-framed post in the research sat at 0 to 2 upvotes.
- **Touching never helps in either app.** In Lull it keeps you in the session
  but never winds the night back up. In Bottle it is purely a cost.
- **Bottle has no collection, no streak, no history.** The reward for focusing
  is the storm you are looking at, and it is gone when you leave.
