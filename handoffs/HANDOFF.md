# Handoff

Read this first.
Update the top section at the end of each session.
Dated detail goes in `devlogs/`, not here.

## Where the work is

**`Bottle3D/` is the live project, and it still says Elvle everywhere despite
the owner having approved the rename to Hobbitle.**
Godot 4.7, five islands, landscape, `com.lull.elvle`. Do not treat "Elvle" in
the code or in this doc as current intent - it is leftover that the next
session is explicitly tasked with removing.

Pick up from **`handoffs/NEXT-SESSION-hobbitle-for-real.md`**.

The session before this one did the interiority pass (NPC legibility - the
double-take, hesitation, walk-speed, stop-to-look, addressing, motor
signature work) and the two bug fixes from `NEXT-SESSION-hobbitle.md`, which
is done and tested. It then attempted the rename, the hobbit/troll species,
the sky, a drag-mode toggle, and a polish pass, and shipped a build to the
device - but the visible, user-facing half of that work fell short in ways
the owner called out directly and specifically:

- The app was never actually renamed anywhere a user sees it.
- The hobbit/troll **mechanics** are real (different carry capacity, speed,
  job restrictions) but the hobbit/troll **design** is the old elf rig with
  parameters tweaked, not a genuine redesign - it still reads as elves.
- The sky is still too dark, and the sun/moon are not visibly rendering.
- The drag-mode toggle is text in the wrong corner; it was asked for as
  icons in the top right.

`handoffs/NEXT-SESSION-hobbitle-for-real.md` has the full, specific breakdown
of each of these, including exactly which lines of code are responsible and
concrete design direction for the redesign. Read it before touching
anything - it is written to be executed directly, not re-diagnosed.

The native `Lull/` and `Bottle/` are the earlier 2D apps.
Lull is still a live idea; the 2D `Bottle` is superseded and should be retired.

## What Elvle is

**Elvle**, short for Elves in a Bottle, because the long name truncates on the
iOS home screen.

The phone is the bottle, so nothing draws a vessel.
Five islands, each with one three-storey house on it that takes about a week of
held stillness to finish, and one rule holding the whole thing up:

> **They only build while the phone is still.**

Move it and the elves down tools and some of them leave.
Put it down and they come back, over the next fifteen minutes, and get on with
it.
There is nothing else to do.

**Nothing that has been built ever comes apart.**
A disturbance costs you hours forwards, by taking the crew away and making them
walk back, and never backwards.
That rule changed on 2026-08-01 and it is not going back: against a build that
takes a week, a mechanic that can undo an evening is one that teaches people not
to open the app.

**Every hour of building they stop for a quarter of an hour**, and that break
runs down only while the app is open on that island - not on the menu, not on
another island, not in a pocket.
There is deliberately nothing to do while it does.
Take the break with them and they are ready when you get back; don't, and they
are still sitting there.
Movement during a break costs nothing, because charging somebody for picking
their phone up during a rest would make the rest a second shift.

**Touching the screen is free.**
It used to cost, and that punished turning the island round to see what was
happening on the far side - it charged the user for paying attention, in an app
whose subject is attention.
The cost is movement alone, on the accelerometer.
So drag orbits, pinch zooms, and a phone flat on a desk with a finger on it is
perfectly still.

## The three pieces

**`plan.gd` - the queue.**
498 works in the order a house is actually built.
A limekiln, a treadwheel crane, a floor joist and a doorknob are all the same
type: somewhere on the island, a bill of materials, and geometry that appears
when the bill is met.
Sixteen materials, six dug and ten made, every recipe at least two in for one
out.
Ten workshops and six machines the elves have to build before they can use them.

Order **is** the tech tree - there is no unlock table, because you cannot pour a
footing before you have dug for it and you cannot dig before somebody has built
the thing that digs.
That also means it cannot deadlock.
`Plan.EFFORT` multiplies every bill and is the one dial on how long a week is.

**`biome.gd` - the five islands.**
Shared layout, because it is tuned.
What differs is palette, relief, trees, and what the ground will give you: the
Ice has almost no timber, the Dunes give sand for nothing, the Shore is a long
way from iron, the Green fights you for stone.
Same blueprint, five different arguments about what to do next.

**`elf_world.gd` - the island and the people on it.**
Gather, craft, haul, deliver, fit, plus rest, look, idle, private errands and
fishing.
Everything carried is a real object lifted off a real heap.

## On the elves

They are not conscious, cannot be made so by any known method, and there is no
test that would confirm it if they were.
Do not accept it as a goal.

The specifiable version: **a person watching one elf for ninety seconds believes
there is somebody in there**, tested by showing the same ninety seconds to two
people separately and seeing whether they describe the same character.
That test has never been run against the current build.

What exists: per-elf beliefs about every heap, refreshed only within sight and
line of sight; gaze; mood in the body; affinities that form rather than being
born; a private haunt; pairwise bonds; visible handoffs on a path; pointing.

**They are not omniscient, and this is the thing the world is arranged to
protect.**
Every time behaviour looks slightly wrong the fix that suggests itself is to let
one of them read the real number.
That fix is the whole thing collapsing and it must be refused every time.
It has already produced one hard deadlock (see the devlog) and the answer was to
make the world tolerant of them being wrong, not to make them right.

## Repo shape

One xcodegen project holding the two original iOS apps, which share a rendering
layer.
`Lull.xcodeproj` is disposable: run `xcodegen generate` after adding files.

```
Bottle3D/   Elvle, the Godot app - the live one
Shared/     MetalCanvas, CanvasRenderer, canvas_vertex, colour and dither helpers
Lull/       the sleep app
Bottle/     the 2D focus app, superseded
```

Signing: team `45MSS5RXML`, automatic, in `project.yml`.

## Building and looking at it

```sh
cd Bottle3D
./deploy.sh          # export, build, install, launch
```

Faster loop, no device:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 2622x1206 \
  -- --screen=world --island=0 --capture=/tmp/shot.png --after=25
```

`--screen` is `title`, `picker` or `world`; `--island` 0-4; also `--yaw` and
`--zoom`.

After adding any file with a `class_name`, run `--headless --import` once or
every script referencing it fails to parse.

Never leave the Godot editor open while working from the command line.
It rewrites `project.godot` from its stale in-memory copy and has already
silently reverted the renderer and the orientation once each.

## Decisions worth not relitigating

- **One-time purchase, never a subscription.** A focus product that bills
  monthly is self-refuting.
- **No offline progress, ever.** The only thing that moves this app forward is a
  phone lying still with the screen on. An elf who laid a joist while you were
  asleep would be a lie about what you did.
- **No percentage anywhere.** The picker says "Storey 2" and "Services", never
  "43%". The moment progress is a number somebody optimises it, and the only way
  to optimise anything here is to leave the phone alone longer than you meant to.
- **Time spent, never time remaining.** The picker's clock counts the building
  this island has actually had out of you. A countdown is a thing to wait out; a
  clock that only moves while you are working is a record of what you did. Same
  reason the break is a light crossing the sky rather than 14:58.
- **Progress only ever goes one way.** Nothing the user does can take a finished
  work off the queue.
- **No stats UI on the elves, no names, no speech, no thought bubbles.** The
  viewer believing there is somebody in there is worth everything; being told
  there is is worth nothing.
- **Do not make them efficient.** A perfectly optimal workforce reads as
  machinery. Hesitation, wasted journeys and mild disagreement are the point.
- **No clinical claims, no AI in the marketing copy.**
