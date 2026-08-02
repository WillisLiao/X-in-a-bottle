# Next session: the stillness rule goes, and four changes with it

Decided by the owner on 2026-08-02, after the one-world pivot shipped.
Nothing here is built. This is a plan, not a spec, and the four changes are
independent enough to be done in any order except where noted.

Read `handoffs/HANDOFF.md` first.
`handoffs/NEXT-SESSION-what-the-other-sites-build.md` is still the larger
question and is not superseded by any of this.

---

## What this reverses, stated plainly once

Three of these changes undo decisions the project's own documents list under
"decisions worth not relitigating", and one contradicts the business model in
`DESIGN-one-world.md`.
That is the owner's call and it is not being argued here.
It is written down because a handoff that does not say so will produce a future
session that "fixes" the code back to match the docs.

| Change | What it reverses |
| --- | --- |
| Stillness rule removed | The premise the whole app was built on: "They only build while the phone is still." |
| Two-hour feed for a 3x speed-up | "No energy timers, no skip-the-wait, no daily rewards." |
| Paid regions | `DESIGN-one-world.md`: no IAP of any kind at launch; paid regions "later, one-time, years apart". |
| Camera bounds removed | Nothing. This one is a straight improvement. |

**The first task of the session is to update the documents, not the code.**
`HANDOFF.md`'s "What Hobbitle is" section, its "Decisions worth not
relitigating" list, and the marketing line about refusals all describe an app
that will no longer exist.
Leaving them contradicting the source is worse than either version.

---

## 1. Remove the stillness rule entirely

Confirmed scope: the whole thing, not just the population loss.
The accelerometer stops being an input. Work continues whether the phone is
still, in a pocket, or being walked with.

### Delete

`scripts/charge.gd` in its entirety, 76 lines.
One thing in it is still needed: `STARTING_OBJECTS := 2`, used twice in
`main.gd` around line 366 for the initial fast-forward. Move that constant to
`ElfWorld` before deleting the file.

`main.gd`:
- `_charge`, `_agitation`, `_accel_baseline`, `_baseline_ready` (around 195-205)
- `_read_motion()` (around 755-780) and its call in `_process`
- the disturbance block in `_process`, lines 318-326

`world.gd`:
- `disturbed()`, `_shrink()`, `LOSS_FRACTION`
- `advance(delta, population, disturbed)` loses its third argument, and probably
  its second as well - see below

`elf_world.gd`:
- `_rattled` and all seven of its uses: lines 472, 678, 688-691, 969, 1660,
  1921, 2697, 2753
- `_shrink()` at 3114, and the whole put-the-carried-thing-back path inside it
- `_quake`, which exists only to shake the world on a disturbance

### Keep

**The tilt parallax.** `_has_sensors` and `_tilt` in `main._move_camera` read
`Input.get_gravity()` for a small lean, and that is a separate mechanism from
agitation. It is the difference between looking at a screen and looking into
something, it costs nothing, and it should survive.

**The work and rest cycle.** `WORK_PERIOD` and `REST_PERIOD` are independent of
the accelerometer and are not part of this change. The break still runs on
app-open time alone.

### What sets the crew size now: answered

Today the population is `_charge.population(capacity)`: nought to twelve over
fifteen minutes of perfect stillness, on a hard front-loaded curve. With the
accelerometer gone there is nothing driving that number.

**Answered on 2026-08-02 by a decision recorded in
`NEXT-SESSION-what-the-other-sites-build.md`: the crew is a single band of about
twelve who travel the world together.** Fixed roster, no curve, nothing to
optimise. Read that file's section "Who is in a region" before touching this,
because it also splits `_residents` into a world-level band and per-region
settlers, and you do not want to do that migration twice.

For this session, the minimum is: keep `World._grow` and `spawn_seconds` so they
still walk in one at a time over about twenty seconds rather than appearing, and
delete the population argument from `advance`. `held() < capacity` becomes the
only condition.

### Knock-on effects worth expecting

`_focus` currently only accrues on the `else` branch of the disturbance check
(`elf_world.gd` around line 692). Once that branch is unconditional, `_focus`
becomes "time the app was open on this region", and `Progress.build_time` means
something different from what its documentation says. Update the comment.

The lantern carrier's halt rule at `elf_world.gd:1660` currently reads
`_rattled > 0.35 or resting()`. It keeps the `resting()` half.

`main.gd`'s class documentation is largely about this mechanic and will need
rewriting rather than trimming.

---

## 2. The feed

Every two hours the region's own coastline finishes lighting up and begins to
breathe. Tap it and food rains on the region. They eat, and then work at
**three times speed for ten minutes**.

### The clock

Confirmed: **app-open time on the current region only.** It does not fill while
the app is closed, and it does not fill for a region you are not watching. Same
clock the break already runs on.

Store it per region alongside `focus` and `cycle` in `Progress`, as a single
float of seconds accumulated, and persist it. Two hours is `7200.0`.

Note the interaction with the existing cycle: two hours of app-open time is
roughly two full work hours plus two fifteen-minute breaks, so the feed comes
round a little under every third work period. That is fine, but it means it will
sometimes become available mid-break. Decide whether tapping it during a break is
allowed. Recommended: no, and the glow is held dim while resting.

### The coastline is the progress bar

Decided 2026-08-02, replacing an earlier plan for a circular bar in the corner.

**A light travels round the region's own shoreline.** It sets off from one point
on the coast and works its way round over the two hours. When it closes the
circuit the whole outline begins to breathe - a slow pulse, in and out - and
that is what says it can be tapped.

This is much the better idea and it is worth being clear why, because it is not
just decoration:

**It keeps the app at zero HUD.** The only overlay in the entire product is one
`Label` reading "Turn" or "Move". A ring in the corner would have been the first
piece of furniture, and furniture is what this app has spent its whole life
refusing. A coastline that lights up is the world telling you something, which
is how everything else here already works: the break is a sunset, progress is a
house going up, attention spent is a path worn into the ground.

**It is non-numeric by construction.** There is nothing to read, nothing to
optimise, and no way to express it as a percentage even if somebody wanted to.

**It uses something that was already made real.** The terrain work turned the
shoreline from a rectangle with its corners hanging off into a closed, wandering
outline. That was done for the map's sake and it pays off twice here.

**A full outline reads from across a room.** The glow clips the existing bloom
threshold in `main._build_environment`, so a breathing coast is unmissable
without being loud.

#### How to draw it

A separate thin rim mesh rather than anything done to the ground. Do not try to
find the silhouette in the terrain mesh or shade the edge of it - the folded
coastline has collapsed vertices along it and is the wrong thing to read from.

The shore curve is available in closed form from the same wobble `Land.height`
uses. For a bearing `a`:

```
wobble = 1 + 0.10 * sin(3a + 0.7) + 0.06 * sin(5a + 2.1)
d      = SHORE * wobble / sqrt((cos a / LAND_X)^2 + (sin a / LAND_Z)^2)
point  = (d * cos a, land.height(point), d * sin a)
```

`SHORE` a little inside `1.02` - about `0.95` - so the line sits on the land
rather than part way down the flank. Take the height from `Land.height` so it
follows the relief, and lift it a few centimetres clear of the ground or it will
z-fight along its whole length.

Walk `a` round in a hundred and twenty steps, build a narrow ribbon or a thin
tube, and carry each vertex's position round the loop as `UV.x` in nought to
one. That value is the whole mechanism.

#### The shader

Two uniforms: `progress` in nought to one, and `breathe`.

Below `progress`, lit. Above it, dark, but not invisible - a faint unlit rim all
the way round is what makes the lit part legible as a portion of something
rather than as a stray mark. A short bright head at the leading edge, falling
off behind it over a few per cent of the loop, is what makes it read as
travelling rather than as filling.

Emission well past white so it blooms, in `EMBER` (`FF9A4A`), and warmer at the
head.

Once `progress` reaches one, hand over to `breathe`: the entire outline
modulated by something like `0.55 + 0.45 * sin(t * 1.3)`, a four or five second
period. A breath, not a blink. It must be slow enough to be calm and deep enough
that a glance catches it.

#### Two things that will not behave as expected

**It will not visibly move.** Two hours around a forty-unit perimeter is about
half a centimetre a second. Nobody will ever catch it travelling. That is
acceptable and arguably right - you notice it has got further while you were
away - but it means the *head* has to be clear enough that its position is
readable at a glance, because the position is the only information there is.
Do not waste time trying to make the motion perceptible.

**The Ice will fight it.** A warm glow on a pale blue-white coast is much weaker
than the same glow on the Meadow or the Green. Expect to need a per-biome accent
colour, in the same way each region already designs its own sky. The Ice
probably wants something colder and brighter rather than ember.

Also worth watching: during a break the hearth is meant to be the brightest
thing in the world, and a breathing coastline would take that away. Holding the
glow dim while `resting()` fixes both this and the mid-break tap question above.

#### Tapping it

There is no target to hit. When the outline is breathing, **a tap anywhere on
the region** feeds them.

Guard it to `_map < 0.35` in `main._finish_press`, because out on the map a tap
on a region already means travel to it or send a lantern. Put it after the
corner toggle and before anything else.

Only the region being watched glows. The far regions in `Country` have no feed
clock running, because nothing accrues in a place nobody is looking at, so their
coastlines stay dark - which incidentally keeps the map readable: one settled
region has a fire, the watched one has a fire and possibly a lit coast.

### The rain

Fish, fruit and bread fall on the region and land on the ground.

Food should **not** be `Plan.Kind` values. Those sixteen are building materials
with recipes and bills attached, and adding food to that enum will drag it into
the queue economy, `_home_for`, the belief system and the save format. Make a
separate lightweight kind - an `enum Food { FISH, FRUIT, BREAD }` on a new
`scripts/feast.gd` - and give it its own small item meshes in the style of
`_make_item`.

Falling: spawn above the region, drop with gravity to `_ground(p)`, land with a
small bounce. Scatter across the region rather than in a pile, weighted away
from the site so it is a thing people walk to.

### Eating and cooking

The owner's description: they cook the meat, and eat bread or fruit straight
away.

Note that "meat" and "fish" are the same item in the list above - settle which
it is. Assumed here: **fish needs cooking at the hearth; fruit and bread do
not.**

Two new tasks on the `Task` enum, and as with `CARRY_FIRE` they must be
**appended, never inserted**, because those values key every elf's saved
`affinity` dictionary:

```
enum Task { NONE, GATHER, CRAFT, HAUL, DELIVER, FIT, LOOK, REST, IDLE, OWN,
	PLAY, CARRY_FIRE, EAT, COOK }
```

`EAT` is a pick-up, a walk-to-somewhere-comfortable, and a pause with the
existing eating motion if there is one. `COOK` is a haul to the hearth, a wait,
and then `EAT`. The hearth already exists and is already the social centre, so
the cooking is nearly free.

Add both to `_decide`'s scoring with a very high weight while food is on the
ground, so the whole crew visibly downs tools for it. That is the moment worth
watching and it should look like a meal, not like a fetch quest.

### The speed-up

Three times, for ten minutes.

Simplest correct implementation: one `_haste` float on `ElfWorld`, defaulting to
1.0, multiplying both `e.pace` in `_tick_elf` and whatever rate `work_left`
counts down at in `_act`. Do not scale `delta`.

**Say the size of this out loud before shipping it.** Ten minutes at 3x is
twenty extra minutes of work per two hours, so a user who takes every feed
finishes a week-long house something like a quarter faster. That is a large
change to the one dial the project has (`Plan.EFFORT`) and it should be a
deliberate number rather than a side effect. Consider 2x, or consider raising
`Plan.EFFORT` to compensate.

It also wants to be visible without a number: they move faster, the animation
rate goes up, and the effect ending should be a settling rather than a cut.

---

## 3. Drop the camera bounds

Small and self-contained. Do this one first as a warm-up.

`main.gd`, `_pan_camera`: `PAN_LIMIT` (3.4) and `PAN_LIMIT_MAP` (26.0) clamp how
far the camera may be slid off the middle of a region. Remove the clamp.

Expect to be able to pan off into empty haze with nothing on screen. That is
acceptable and is what was asked for. If it feels bad, the fix is a soft
rubber-band back rather than reinstating a hard wall.

---

## 4. Locked regions

Confirmed shape: **some locked, some not.**
The Shore and the Green open as they do now, by walking a lantern to them.
The Dunes and the Ice are paid, and carry a white lock icon.

That fits the geography as authored: the Dunes and the Ice are the two far ends
of the arc, each two hops out, and `Region.NEIGHBOURS` already makes them
reachable only through the Shore and the Green respectively.

### Decide: what a purchase actually gives you

Payment removes the lock. Does it also settle the region, or does it only make
it reachable so that somebody still has to carry a lantern there?

Recommended: **payment unlocks, the lantern still settles.** It keeps the one
mechanic in the app that costs attention rather than money, it means a purchase
does not skip anything watchable, and it needs no new code beyond the gate.

### Code

`Region`: a `PAID` set, `{2, 1}` for the Dunes and the Ice.

`Progress`: purchased regions in the world section, next to `settled`.

`main._tap_region`: currently three branches - settled, unsettled neighbour,
unreachable. Add a fourth ahead of them: locked and unpaid.

`Country._far_region`: draw the lock on regions that are locked and unpaid.

### The icon

White, per the owner. A padlock: a rounded rectangle body and a shackle arc,
drawn with `_draw()` on a `Control`, positioned each frame by
`_camera.unproject_position(_country.where(i))`, exactly as `_tap_region`
already finds regions on screen.

Screen-space rather than a 3D billboard, so it stays a constant readable size
whatever the zoom, and so it can fade out entirely as the camera comes in close
to a region and stops being a map.

### The part that is not small

**There is no in-app purchase machinery in this project at all.**

Godot does not ship StoreKit support for iOS; it needs a plugin, added to the
export, with a native side. Then there is the product setup in App Store
Connect, restore-purchases (required by review), sandbox testing, and the fact
that `deploy.sh` builds a debug configuration that will not exercise any of it.

Budget this as its own session. Everything else in this document is a day's
work; this is not.

Recommended order: build the lock, the gate and the icon against a local
`Progress` flag first, with a debug way to flip it, and treat the actual
purchase flow as a separate piece behind that seam.

---

## Suggested order

1. Update `HANDOFF.md` so it stops describing an app that is being deleted.
2. Camera bounds. Ten minutes, no dependencies.
3. Remove the stillness rule, including the crew-size decision. Everything else
   is easier once this is gone, and the feed in particular would otherwise have
   to reason about being tapped mid-disturbance.
4. The feed, in this order: the coastline glow, then the rain, then eating and
   cooking, and the speed-up last so it is tuned against a working meal rather
   than the other way round. The glow is worth building first even though it is
   the least mechanical part - it is the only bit anyone will look at for two
   hours at a stretch.
5. Locks, up to but not including the purchase flow.
6. The purchase flow, as its own session.

## Answered on 2026-08-02

**Leaving the app running is legitimate play.** With the stillness rule gone,
nothing stops the phone sitting face-down on a desk earning the build, the break
cycle, the feed clock and the worn paths. That was raised and accepted: app-open
time is the currency now.

Two consequences a fresh reader should not have to work out:

The project sets no `display/window/energy_saving/keep_screen_on` override, so
Godot's default of `true` applies and the screen never sleeps. That was harmless
when the premise required the phone to be left alone *in view*; it now means the
app can run indefinitely in a drawer. If that ever wants changing it is one line
in `project.godot`.

`HANDOFF.md` carries a marketing line - "no ads, no energy timers, no
skip-the-wait, no daily rewards", and "an app that monetises attention is
self-refuting" - which is proposed for the store page. With a two-hour boost
timer and paid regions it cannot ship as written. Not a code problem, but
somebody has to rewrite it before launch and it should not be discovered late.

**The feed stays at 3x for ten minutes.** Confirmed, having been told that it
makes a week-long house finish roughly a quarter faster. It is meant to be
dramatic and obviously worth coming back for. Do not quietly soften it while
tuning; if the week needs to stay a week, raise `Plan.EFFORT` instead so the
change is explicit.

## Open questions

- Can the feed be tapped during a break?
- Is 3x for ten minutes the intended size once it is on screen, or was it a
  first guess?
- Does the coastline glow survive a region being finished, or does a completed
  region stop asking to be fed?
- Does the feed clock keep filling while the camera is out on the map, where
  there is no single region being watched? Recommended: yes, on the region you
  last stood in, since that is the one whose clock is running everywhere else.
  The coastline glow follows the clock, so it will be part way round when you
  come back down to it.
- Is "meat" the fish, or a fourth food? Assumed here: it is the fish.

## How to look at any of it

```sh
cd Bottle3D
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 2622x1206 \
  -- --screen=world --island=0 --capture=/tmp/shot.png --after=20
```

`--screen` is `title`, `world` or `map`; `--island` (or `--region`) 0-4; also
`--yaw`, `--pitch`, `--zoom`, `--rest` and `--fire=<region>`.

A `--feed=<0..1>` argument that sets the coastline straight to a given point
round the loop will pay for itself within about ten minutes of working on it, in
the same way `--fire` did. Without it every look at the glow costs two hours.
