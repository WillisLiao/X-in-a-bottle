# X in a Bottle, and Lull

Two iOS apps that share a rendering layer.
Both are one full-screen fragment shader over one triangle, in near-black, watched rather than played.

## X in a Bottle

A focus app. The phone is the bottle.

Leave it alone and the bottle fills.
Touch the screen or move the phone and it drains, twelve times faster than it fills.
A ten second glance at a notification costs two minutes of focus, and that asymmetry is the whole mechanism.

There is no interaction. Touching is only ever a disturbance.

Swipe for environments. Each expresses the same charge and the same disturbance in its own idiom.

- **Lightning in a Bottle** - free. Charge is how often lightning comes and how far it reaches.
- **Ice in a Bottle** - paid. Crystals nucleate and creep outward, and a disturbance thaws them.
- **Genies in a Bottle** - paid. They arrive, wander, work at nothing in particular, and an earthquake sends some of them fleeing.

Intended to be used with Guided Access, so you lock yourself in and cannot leave.
The app cannot enable that itself and only teaches the gesture, which is the right way round: choosing to lock yourself in is a commitment device, being trapped is a dark pattern.

## Lull

A game engineered to make you stop playing it, so you can fall asleep.

No streaks, no score, no fail state, and no notifications, because the permission is never requested.
You steer a warm ember through fog.
Over twenty minutes the world slows, dims and quietens, and after ninety seconds without a touch the ember picks its own heading, drifts on without you, and fades to black.

## Building

Requires Xcode 26 and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open Lull.xcodeproj
```

`Lull.xcodeproj` and the two `Info.plist` files are generated and not committed.
Run `xcodegen generate` after cloning and after adding any file.

```sh
xcodebuild -project Lull.xcodeproj -scheme Bottle \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build
```

## Layout

```
Shared/      MetalCanvas, CanvasRenderer, canvas_vertex, colour and dither helpers
Lull/        the sleep app
Bottle/      the focus app
handoffs/    living snapshot, read first
devlogs/     dated detail, including what went wrong and why
```

`Shared/` exists because the four things that were expensive to get wrong once live there and are not written twice: the extended-linear Display P3 drawable, the overshooting fullscreen triangle, sRGB to linear conversion, and the dither.
Every one of those caused a real bug before it was moved there.
`devlogs/` has the details.
