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

### Decide: what sets the crew size now

This is the part that is not just deletion, and it needs a decision before any
of the above is touched.

Today the population is `_charge.population(capacity)`: nought to twelve over
fifteen minutes of perfect stillness, on a hard front-loaded curve. With the
accelerometer gone there is nothing driving that number.

Recommended: **a full crew, arriving rather than appearing.** Keep
`World._grow` and `spawn_seconds` so the twelve still walk in one at a time over
about twenty seconds when a region opens, and delete the population argument
from `advance` entirely. `held() < capacity` becomes the only condition.

The alternative - crew size grows with time spent in the region - reintroduces a
progress curve on a number, which the app has refused everywhere else.

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

Every two hours you may tap a circular progress bar, and food rains on the
region. They eat, and then work at **three times speed for ten minutes**.

### The clock

Confirmed: **app-open time on the current region only.** It does not fill while
the app is closed, and it does not fill for a region you are not watching. Same
clock the break already runs on.

Store it per region alongside `focus` and `cycle` in `Progress`, as a single
float of seconds accumulated, and persist it. Two hours is `7200.0`.

Note the interaction with the existing cycle: two hours of app-open time is
roughly two full work hours plus two fifteen-minute breaks, so the circle comes
round a little under every third work period. That is fine, but it means the
feed will sometimes become available mid-break. Decide whether tapping it during
a break is allowed. Recommended: no, and the ring is drawn dim while resting.

### The ring

The first real HUD element in the app. The only other one is a `Label` reading
"Turn" or "Move" in the bottom left.

Draw it, do not theme it. Everything in this app is drawn: see the deleted
`Menu.Plot` class in the git history for the house-on-a-chip drawing, which is
the closest precedent. A `Control` with `_draw()` in a `CanvasLayer`, an arc
that fills clockwise, in `EMBER` (`FF9A4A`) against `INK` at low alpha.

It is consistent with the existing rules provided it is **a ring and never a
number**. `Progress.fraction`'s own comment already says "shown as a ring, never
as a percentage", so there is precedent and language for this.

Where: top right is free and is where the turn/move icons were also asked to go.
Those two want designing together rather than separately.

It should fade like `_fade_back` does rather than sitting at full strength for
twenty-five minutes, but it must not fade to nothing once it is full - a full
ring is the one thing on screen asking to be tapped.

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
4. The feed: ring, rain, eat and cook, then the speed-up last so it is tuned
   against a working meal rather than the other way round.
5. Locks, up to but not including the purchase flow.
6. The purchase flow, as its own session.

## Open questions

- Is "meat" the fish, or a fourth food?
- Can the feed be tapped during a break?
- Is 3x for ten minutes the intended size once it is on screen, or was it a
  first guess?
- Does the ring keep filling while the camera is out on the map, where there is
  no single region being watched? Recommended: yes, on the region you last
  stood in, since that is the one whose clock is running everywhere else.
- With the stillness rule gone, what stops the app being left running in a
  pocket? Nothing, and that may be fine, but it was previously the entire
  answer.

## How to look at any of it

```sh
cd Bottle3D
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 2622x1206 \
  -- --screen=world --island=0 --capture=/tmp/shot.png --after=20
```

`--screen` is `title`, `world` or `map`; `--island` (or `--region`) 0-4; also
`--yaw`, `--pitch`, `--zoom`, `--rest` and `--fire=<region>`.

A `--feed` argument that fills the ring instantly will pay for itself within
about ten minutes of working on it, in the same way `--fire` did.
