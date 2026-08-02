# Working notes

Things that will cost you an hour if you have not seen this repo before.

Read `HANDOFF.md` first for what the product is. This file is only the tacit
knowledge: conventions that are not written in the code, invariants that look
like bugs, and failure modes that give no useful clue what they are.

Everything here was learned by losing time to it.

---

## Running it

The live project is `Bottle3D/`. Godot 4.7, landscape, mobile renderer.

```sh
cd Bottle3D
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 2622x1206 \
  -- --screen=world --island=0 --capture=/tmp/shot.png --after=20
```

Arguments, all after the bare `--`:

| Flag | Does |
| --- | --- |
| `--screen=` | `title`, `world` or `map` |
| `--island=` / `--region=` | 0 Meadow, 1 Ice, 2 Dunes, 3 Shore, 4 Green |
| `--yaw=` `--pitch=` | degrees, in the units a drag produces |
| `--zoom=` | 0.42 close, 1.0 default, 3.0 full map |
| `--rest=` | drop straight into a break, 0 to 1 through it |
| `--fire=` | send the lantern to a region at launch |
| `--route=` | add `meadow-shore` or `meadow-green` as a local coarse route |
| `--route-reset` | clear saved local routes before applying `--route` |
| `--capture=` `--after=` | write a PNG after N seconds, then quit |

**Look at captures. Do not assume.** A previous session shipped a sun nobody
could see and believed it was working, because the screenshot that "proved" it
could not have contained the sun at any camera angle a thumb could reach. Every
visual claim in the devlogs after that point is backed by an image.

**The engine takes 20-40 seconds to start, render and quit.** A capture with
`--after=200` needs a four minute wall clock. Run it in the background rather
than blocking on it.

Deploy to a connected iPhone:

```sh
cd Bottle3D && ./deploy.sh
```

It needs the phone reachable, which means unlocked and either on USB or on the
same Wi-Fi. `xcrun devicectl list devices` must say `connected`, not
`connecting` or `unavailable`.

---

## Five things that will bite

### After adding any file with a `class_name`, run an import once

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --import
```

Without it every script referencing the new class fails to parse, and the error
points at the *referencing* file rather than the new one.

### Never leave the Godot editor open while working from the command line

It rewrites `project.godot` from its stale in-memory copy. It has already
silently reverted the renderer and the orientation, once each.

### A mesh that renders as nothing at all is a winding problem

Not dark, not misshapen. Absent.

Godot's front face is the one whose edge cross product points *away* from the
viewer, so ground seen from above wants `cross(e1, e2)` pointing **down**.

This cost an hour on `causeway.gd`. The search went through the vertex data, the
AABB, the surface count, the material, node visibility and render layers - all
of which were fine - before someone dropped a plain white box at the same
coordinates and watched it appear instantly. `Land.mesh` and `Causeway.mesh` go
round their quads in opposite orders for this reason and both are correct.

### Vertex colours are consumed as linear, and every colour written down here is sRGB

Always `.srgb_to_linear()` on the way in. Skipping it lifts mid-tones by about
seventy per cent, so a meadow renders as pale sage and a desert as bare white
paper, and it looks like a lighting problem rather than a colour space one.

### `ProceduralSkyMaterial.ground_curve` runs backwards from how it reads

**Lower is a faster fall to the bottom colour.** Established by rendering the
two ends in flat red and blue and looking.

This matters more than it sounds: the camera looks down from thirty-six degrees
through a thirty-four degree lens, so everything behind the land is between
nineteen and fifty-three degrees *below* the horizon, and every pixel of the
background is the ground half of the sky. `sky_top_color` is almost never
visible. Hours were once spent tuning a colour nobody had ever seen.

---

## Invariants that look like bugs

Do not "fix" these. Each one is load-bearing and at least one has been broken by
accident already.

**The elves are not omniscient, and the world is arranged to protect that.**
Every time behaviour looks slightly wrong, the fix that suggests itself is to
let one of them read the real number. That fix is the whole thing collapsing and
it must be refused every time. It has already produced one hard deadlock, and
the answer was to make the world tolerant of them being wrong rather than to
make them right. Beliefs are refreshed only within sight and line of sight, and
`FORGET` is ninety seconds.

**Never insert a value into `enum Task`. Append.** Those values are the keys of
every elf's saved `affinity` dictionary. Renumbering silently hands a week of
formed specialisms to the wrong jobs. `CARRY_FIRE` is appended for this reason
and there is a comment saying so.

**`Progress` stores `done` as indices into the queue.** They only mean anything
relative to the queue that produced them. Anything that makes the queue vary has
to save whatever generates it, and a generator version alongside. See the save
format warning in `NEXT-SESSION-what-the-other-sites-build.md`.

**`ElfWorld._on` must go through `_ground`, not through `Land`.** `Land` knows
nothing about the necks between regions, and `_on` places every foot, shadow and
anchor. Delegating it straight to `Land.on` puts a hobbit crossing to the next
region twenty feet under the causeway they are walking on.

**Progress only ever goes one way.** Nothing the user does takes finished work
off the queue, and worn paths never fade. Against a build that takes a week,
anything that quietly undoes an evening teaches people not to open the app.

---

## House style

The code in this repo reads unusually. That is deliberate and it is worth
matching, because the comments are where the design reasoning lives.

**Comments say why, and say what was tried.** Nearly every constant has a
paragraph above it explaining what value was there before, what it looked like,
and why it moved. If you change a tuned number, replace the reasoning rather
than the number alone.

**Write down failures at the point of use.** The winding note lives in
`causeway.gd`, not in a commit message, because that is where the next person
will be standing when it happens to them again.

**Prose conventions:** no em dashes, use a plain hyphen. In long Markdown files
put each sentence on its own line. Do not add an agent name as a commit
co-author.

**Everything is drawn, nothing is themed.** There are no textures anywhere in
the project - every surface is vertex colours on faceted geometry. The UI is
`_draw()` on custom `Control`s; a default-styled Godot `Button` would be the one
element that came from somewhere else. The existing `Label` reading "Turn" or
"Move" is legacy UI; new overlays, including `RumorMarks`, are custom drawn.

**No numbers on screen.** No percentages, no counts, no stats on the elves, no
names, no speech. Progress is said in the language of a building site - "Storey
2", "Services" - or shown as a ring, or shown by the house actually being
further up. You can see how many people there are by looking at them.

**Heat is a product failure.** This app sits on a desk for twenty-five minutes.
The renderer is Mobile rather than Forward+ for that reason, `Engine.max_fps` is
30, shadows are off everywhere, and depth of field was refused. Weigh new work
against this.

---

## Where things are

```
Bottle3D/scripts/
  main.gd        camera, sky, sun and moon, input, the map blend
  menu.gd        the title. One screen. The picker was deleted 2026-08-02
  world.gd       base class - a world in the bottle
  elf_world.gd   4000 lines: the region and the people in it
  plan.gd        498 works in the order a house is actually built
  biome.gd       the five palettes, relief and pace tables
  land.gd        the ground of one region: height, colour, mesh
  region.gd      where the five regions are, and why each number
  country.gd     the four regions you are not standing in. Scenery, no tick
  causeway.gd    the necks between regions - and they answer `height`
  wear.gd        where they have walked. One byte a patch, only ever up
  route_book.gd  coarse local route ledger. Never raw GPS coordinates
  community_roads.gd  map-level trade-road meshes and rumor-site interaction
  rumor_marks.gd custom-drawn map halos for unclaimed rumors
  progress.gd    what survives being put down
  feast.gd       legacy two-hour feed prototype and food item meshes
  coast.gdshader legacy coastline feed fill, head and breathing outline
  ground.gdshader  ground colour plus the worn paths
```

`Lull/` and `Bottle/` are earlier native iOS apps sharing a rendering layer.
`Bottle/` is superseded. Do not work in either without being asked.

---

## The handoffs

`DESIGN-living-world.md` - current product direction.
The local vertical slice is built: a debug coarse route persists as a map road and reveals a claimable rumor.
It has no raw GPS storage, location permissions, accounts, backend, or StoreKit work.

`NEXT-SESSION-map-first-field-loop.md` - next.
It turns the existing continuous map into the game's actual front door and demotes the passive construction view to a village visit.

`NEXT-SESSION-feeding-and-locks.md` - completed historical work from 2026-08-02.
It removed the stillness rule and camera pan bounds and added the two-hour coastline feed.
Its paid-lock portion was removed by the living-world pivot.

`NEXT-SESSION-what-the-other-sites-build.md` - historical grammar research.
Its save-format warning remains valid if the five-region prototype grows multiple generated houses.
The next living-world implementation should instead design an explicit-consent iOS location bridge and a server-authoritative shared-cell protocol.

`DESIGN-one-world.md` - the earlier pivot that produced the current physical map.
Its paid-region business-model section was superseded and should be read as history.

`NEXT-SESSION-hobbitle-for-real.md` is older, from 2026-08-01, and is mostly
done. Two things in it are still live and still correct: section 3, the
turn/move control as drawn icons in the top right, and section 5, a wider polish
pass. Ignore the rest of it, which the one-world pivot overtook.

Dated detail for all of it is in `devlogs/2026-08-02.md`, which is long and
worth skimming before starting anything - most of the numbers in the code have
their reasoning there.
