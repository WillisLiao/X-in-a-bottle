# Handoff

Read this first.
Update the top section at the end of each session.
Dated detail goes in `devlogs/`, not here.

## Where the work is

**The Meadow Act is implemented in the current working tree.**
The version-two fable catalog migrates the shipped Sleeping Hill record and adds Rooted Gate, Field of Lost Lights, deterministic migration, Shore settlement, and act capture hooks.
The pure test is `tools/fable_state_test.gd`.
The next session should deploy the act to an iPhone and tune the map-scale composition from device captures.

**`Bottle3D/` is the live project. It is called Hobbitle and the bundle ID is
`com.lull.hobbitle`.** Godot 4.7, landscape.

### If you are new to this repo, read in this order

1. **The rest of this file**, for what the product is and what is decided.
2. **`handoffs/WORKING-NOTES.md`**, for the tacit knowledge: how to run and
   capture, five failure modes that give no clue what they are, the invariants
   that look like bugs and must not be "fixed", and the house style. All of it
   was learned by losing time to it.
3. **`handoffs/DESIGN-offline-long-road.md`**, for the active product direction.
4. **`handoffs/NEXT-SESSION-meadow-act.md`**, for the next implementation mission.
5. **`handoffs/DESIGN-one-world.md`**, for the physical five-region map that the offline game reuses.
6. `devlogs/2026-08-02.md` if you want the reasoning behind a specific number.
   It is long. Most constants in the code have their argument there.

### Where the world came from

On 2026-08-02 the owner decided to drop island-choosing entirely: the five
biomes became five regions of one world that the hobbits expand across.
`DESIGN-one-world.md` has the reasoning, the mechanics and what it does to the code.
Its paid-region business-model experiment was superseded and then removed by the living-world pivot.
Treat it as history rather than a directive.

**The first slice of it is built.** The picker is deleted, the five regions
sit at authored positions in one world, and pinching out past where a region
used to stop keeps receding until you can see all of them. Tap one to travel.
See `devlogs/2026-08-02.md` for the whole account, and:

```
scripts/region.gd    where the five places are, and why each number
scripts/land.gd      the ground, lifted out of ElfWorld so any region can draw
scripts/country.gd   the four regions nobody is standing in - scenery, no tick
```

The terrain was also reworked twice on the owner's notes and is now faceted
with the hard edges taken off - `Land.SOFTEN` is the one dial. The background,
which was a flat pale wall across two thirds of every frame, now graduates.

Since then: the ground records where people walk (`Wear`, `ground.gdshader`),
the regions are joined by necks of land (`Causeway`), and expansion is a hobbit
carrying a lantern to the next region (`Task.CARRY_FIRE` in `elf_world.gd`).

```
scripts/wear.gd      where they have walked. One byte a patch, only ever up
scripts/causeway.gd  the necks between regions - and they answer `height`,
                     which is what lets an elf walk out of its own region
```

**Current work: `handoffs/DESIGN-offline-long-road.md`.**
On 2026-08-02 the owner rejected the location-based social direction because an offline game is the actual product constraint.
Hobbitle is now a wordless expedition fable in which a familiar band crosses five strange regions and leaves permanent folk-story changes behind.
It is not a focus app and it must never need a player to leave the renderer running to progress.

The route and rumor slice is built and remains useful as map and renderer machinery.
`RouteBook`, `CommunityRoads`, and `FieldMarks` now describe imagined fantasy routes, not real-world movement or a future service.
Do not add GPS, a location permission, accounts, a server, a shared borough, or a fake community.

`NEXT-SESSION-what-the-other-sites-build.md` remains useful historical design work on deterministic generators and saved seeds.
The earlier feed and app-open construction progression remain prototype machinery rather than the released game's loop.
The paid locks were removed with the living-world slice.

**Completed in `9cbf377`: `handoffs/NEXT-SESSION-map-first-field-loop.md`.**
The title now enters the living field map, legacy construction pauses there, and the close village is a deliberate camera descent.

**Next work: `handoffs/NEXT-SESSION-meadow-act.md`.**
It turns The Sleeping Hill proof into a complete Meadow Act with two more myths, permanent map-visible choices, and the band's migration to Shore.

**The map-first field loop is now built.** `main.gd` has explicit `FIELD` and
`VILLAGE` modes, title entry and `--screen=field` open at full map distance,
and the legacy world only advances in village mode.
`FieldMarks` makes the unclaimed route rumor legible at field scale and gives a
brief warm claim bloom through the existing `Country.claim_rumor()` path.
`--screen=map` remains a compatibility alias.

**In order:**

- **What a second and third site build.** Still the largest genuine unknown in
  the whole direction. `plan.gd` knows how to make one three-storey house.
- **Nothing signposts the pinch.** The picker used to be the way to the other
  places. There is now no hint that the gesture goes that far.
- **The world is lit by the region you are standing in**, so at map zoom the
  Ice's cold key sits over the Dunes.
- **The turn/move control.** One `Label` reading "Turn"/"Move" in the bottom
  left of `main.gd`'s `_build_back` - the "Islands" half went with the picker.
  Asked for as icons in the top right, drawn with `_draw()` on a custom
  `Control`. Section 3 of `NEXT-SESSION-hobbitle-for-real.md` has the spec and
  it still stands.
- **The wider polish pass.** Section 5 of the same file.
- **Only neighbours can be settled**, and there is nothing on screen saying so -
  tapping the Dunes from the Meadow does nothing at all. The chain of necks is
  meant to be its own explanation. Worth watching somebody try it.
- **The carrier can be sent while the world is mid-break**, in which case they
  stand on the causeway for the rest of the quarter hour. Correct, and quite a
  strong image, but nobody is told why.

Remaining known nits on the bodies, none of them blocking: a troll's waist
wrap is still barely visible under the gut, and its upper arms merge into the
trunk from some angles.

The native `Lull/` and `Bottle/` are the earlier 2D apps.
Lull is still a live idea; the 2D `Bottle` is superseded and should be retired.

## What Hobbitle is

**Hobbitle**, short for Hobbits in a Bottle, is an offline, wordless expedition fable.
The player guides a familiar band across five strange regions and makes each place a lasting home.
The phone is the bottle, so nothing draws a vessel.

Players discover mythic disturbances, travelers, landmarks, and routes inside the fantasy world.
Their choices build a personal country of roads, villages, and stories that could only have happened in that save.
The world should be exciting to revisit because people and places changed, not because an app was left running.

The five-region construction world presently in `Bottle3D/` is a visual prototype and a source of reusable construction machinery.
Its feed and app-open progression are not the released product direction.
Its paid locks have been removed.

**Nothing that has been built ever comes apart.**
Against a build that takes a week, a mechanic that can undo an evening teaches
people not to open the app.

Legacy construction still has a work and rest simulation because it remains useful visual prototype machinery.
It must never be the source of expedition progress or a reason to leave the app open.

**Touching the screen is free.**
Drag orbits, pinch zooms, and taps do not cost progress.
The small tilt parallax remains because it makes the phone feel like a bottle,
not because it controls work.

## Legacy construction machinery

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

**`biome.gd` - the five regions.**
Shared layout, because it is tuned.
What differs is palette, relief, trees, and what the ground will give you: the
Ice has almost no timber, the Dunes give sand for nothing, the Shore is a long
way from iron, the Green fights you for stone.
Same blueprint, five different arguments about what to do next.

**`elf_world.gd` - the region and the people in it.**
Gather, craft, haul, deliver, fit, eat and cook, plus rest, look, idle, private errands and fishing.
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
Bottle3D/   Hobbitle, the Godot app - the live one
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

`--screen` is `title`, `world` or `map`; `--island` (or `--region`) is 0-4.
`--yaw`, `--pitch`, `--zoom`, `--rest`, and `--fire=<region>` set the camera or send the lantern at launch.
`--route=meadow-shore` or `--route=meadow-green` adds a local coarse route for a capture.
`--route-reset` clears previously saved local routes before the capture route is applied.

After adding any file with a `class_name`, run `--headless --import` once or
every script referencing it fails to parse.

Never leave the Godot editor open while working from the command line.
It rewrites `project.godot` from its stale in-memory copy and has already
silently reverted the renderer and the orientation once each.

## Decisions worth not relitigating

- **There are no paid region gates.** The local purchase flags, map padlocks, and StoreKit seam were removed with the living-world pivot.
- **The game is offline.** Do not add location tracking, permissions, APIs, accounts, servers, shared-world claims, or a fake community.
- **Routes are imagined world geometry.** `Progress` records only local fantasy routes and story resolutions.
- **The feed is legacy prototype behavior.** It is not the progression loop or a reason to keep the renderer open in the released game.
- **No app-open construction rule is legacy prototype behavior.** Expeditions and immediate story outcomes replace passive watched labor as the meaningful player contribution.
- **No percentage anywhere.** Progress is said as "Storey 2" and "Services",
  never "43%". The moment progress is a number somebody optimises it, and the
  only way to optimise anything here is to leave the phone alone longer than you
  meant to.
- **Time spent, never time remaining.** The clock counts the building a region
  has actually had out of you. A countdown is a thing to wait out; a clock that
  only moves while you are working is a record of what you did. Same reason the
  break is a light crossing the sky rather than 14:58.
- **The map is not a screen.** It is the same world seen from further off, and
  it is reached by continuing a pinch. Anything that has to be dismissed is a
  thing standing between somebody and the place they came to look at.
- **Progress only ever goes one way.** Nothing the user does can take a finished
  work off the queue.
- **No stats UI on the elves, no names, no speech, no thought bubbles.** The
  viewer believing there is somebody in there is worth everything; being told
  there is is worth nothing.
- **Do not make them efficient.** A perfectly optimal workforce reads as
  machinery. Hesitation, wasted journeys and mild disagreement are the point.
- **No clinical claims, no AI in the marketing copy.**
