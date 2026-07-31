# Next session: a land, and elves that read as individuals

Everything here is about one environment, Elves in a Bottle, in `Bottle3D/`.
The other three worlds are in reasonable shape and are not the priority.

There are two jobs and they support each other.
**A** is the world: turn the small indoor stage into a land they inhabit and
build on.
**B** is the minds: make each elf read as somebody rather than a unit.

Do them together, not in sequence.
A bigger world is what makes ignorance possible, and ignorance is what makes the
minds work, so neither half lands on its own.

---

## Read this first

The elves are not conscious and will not be.
They are utility-maximising agents: on finishing a task each one reads global
state, scores every option through its trait weights, and takes the maximum.
There is no self-model and nothing it is like to be one.

Nobody knows how to build consciousness, there is no test that would confirm it
if we did, and it is therefore not a specifiable requirement.
There is no state in which we could agree it was finished.
Do not accept it as a goal and do not let it quietly become one.

The real goal, which is specifiable and testable:

> A person watching **one** elf for ninety seconds comes away believing there is
> someone in there.

**How to test it.** Record ninety seconds following a single elf. Show it to two
people separately and ask them to describe that elf as a person. If they
independently land on a similar character, it works. If they say "it collects
things" or "it goes to the fire", it does not.

This test should be run at the end of every session that touches the elves.
It is the only honest measure available and it is cheap.

---

## The two root problems

### 1. The elves are omniscient

Every one reads exact pile counts everywhere, instantly, through walls.

A mind is defined as much by what it does not know as by what it does.
An agent that is never wrong, never surprised, and never has to go and look
cannot read as having a point of view, because it does not have one.
It has the world's view.

### 2. The world is a stage, not a place

Everything sits on a 2.45 metre disc with the camera 3.5 metres back.
The whole set is visible at once and nothing is more than a few steps away.

That is not only small, it actively works against the first problem.
If the viewer can see everything, there is nothing for an elf to *not* know, no
reason to travel, nothing to discover, and no way for a journey to mean
anything. Distance is what turns a decision into a commitment.

---

# Part A: the land

## The shape of it

The phone is the bottle, so the land inside should be **a small curved world**,
a terrarium or garden-globe rather than a flat field.
This is the shape that reconciles "bigger world" with "contained in a bottle",
and it makes the existing tilt control suddenly correct: leaning the phone turns
the little world and brings the far side into view.

Concretely: a low-poly sphere or a shallow dome of roughly 7 to 9 metres across,
elves walking on its surface with up being away from the centre.
Camera sits outside it looking in, orbits with tilt, and can be a good deal
further back than it is now.

A flat but much larger island would also work and is simpler.
The globe is the better idea because it keeps everything reachable while
guaranteeing that some of it is always out of sight behind the horizon, which is
exactly the condition Part B needs.

## What is in the land

Regions, spread far enough apart that travelling between them takes real time
and passes out of view:

- **Stone** - the existing seam outcrop, on a rocky slope.
- **Timber** - a stand of trees. Reuse `TreeWorld`'s branch geometry.
- **Clay or reeds** - near water, for the roof.
- **Water** - a pool. Also somewhere they go that is not work.
- **The hearth** - where they rest. Already exists, keep it.
- **The build site** - flat ground, ideally somewhere with a view.

Journeys should be long enough that an elf leaving for timber is gone for a
while and comes back. That absence is doing real work: it is what makes the
place feel inhabited rather than performed.

## What they build

**A house.** Then another. Eventually a hamlet.

This replaces the spire currently in the working tree. The spire was the right
instinct - permanent accumulation rather than fuel burned away - but a house is
better because it needs *several different materials*, and that is what forces
real logistics and real cooperation instead of one queue.

Structure it as a blueprint of slots, each naming a material:

```
foundation  x6   stone
walls       x12  timber
roof        x8   thatch
door        x1   timber
chimney     x3   stone
```

An elf that decides to build looks for the next unfilled slot, works out what it
needs, and goes to get it. The house rises visibly, piece by piece, in a fixed
order so a half-built one is legible as a house rather than a heap.

When it is finished, start another nearby. Over a long session the land gains a
hamlet. That is the accumulation the whole app is built on, made concrete.

A disturbance knocks pieces off the top, as the spire already does.
What was built can be lost, which is the rule the app runs on.

## Why this matters beyond scale

A house is a shared project with a visible state that every elf can hold an
opinion about. It gives them something to look at, walk toward, stand back and
consider, and disagree about the priority of. None of that is available when the
output is a number.

---

# Part B: interiority

Ordered by perceived interiority bought per unit of work.
Each step lists what to build, roughly how, and how to tell it worked.

## 1. Ignorance and belief

**The single biggest lever. Everything else is easier once this exists.**

Replace the global reads in `_decide` with a per-elf memory of what it last saw.

```gdscript
# On Elf
var beliefs := {}   # pile -> { "count": int, "seen": float }

func believes(pile) -> int:
    if not beliefs.has(pile):
        return 0        # never been there; assumes nothing
    return beliefs[pile].count
```

Refresh a belief only when the elf is genuinely near the thing and roughly
facing it, in `_tick_elf`:

```gdscript
for p in _piles:
    if e.node.position.distance_to(p.at) < 1.2 and _facing(e, p.at):
        e.beliefs[p] = { "count": p.count(), "seen": _time }
```

Then `_decide` scores against `believes()` rather than `count()`, and confidence
decays with `_time - seen` so a stale belief eventually gets checked.

**What this produces for free:** walking somewhere to find it empty, turning
round, going to look because you are not sure, two elves converging on the last
ore and one having to rethink. None of that can be faked convincingly and all of
it reads as a point of view.

**Verify:** watch for an elf arriving somewhere and visibly changing its mind.
If that never happens, beliefs are refreshing too eagerly.

## 2. Gaze

**Highest impact for the least code, once the head is separable.**

Most of what humans read as mind is where attention points.

The head is currently welded into the body in `_build_body`. Make it a child
`Node3D` with its own rotation before anything else here is possible.

Then give each elf a look target chosen by simple priority:

- Something that just changed nearby (a piece placed, something dropped)
- Whoever is nearest and moving
- Where it is walking to
- The build site, occasionally, from anywhere
- Otherwise idle drift

Hold a target for one to three seconds, then move on. Snap between targets over
about 0.2s rather than easing slowly, which is how eyes actually move.

**Verify:** an elf should glance at a colleague walking past without being told
to. If the head only ever points where the body points, it is not doing
anything.

## 3. Mood in the body

One scalar per elf, or two if you want valence and arousal separately, updated
by what happens to it: work completed raises it, a wasted journey lowers it,
resting recovers it, an earthquake spikes it.

Drive posture, gait, pace, pause length, and how far the head swings.
Do not drive decisions with it yet. Body language alone gets most of the way.

**Verify:** two elves standing still should be distinguishable by stance.

## 4. Formed preference

Delete the born-with `likes` trait.

Give each elf an affinity per task, all starting equal, nudged up each time it
completes that task and decaying slowly. The utility score multiplies by
affinity, so small early accidents compound into a specialism.

An elf *becomes* the smith over twenty minutes rather than arriving as one.
A history you can watch accumulate is the cheapest available form of a self.

**Verify:** after twenty minutes, two elves should have measurably different
affinity profiles, and you should be able to point at one and say what it does.

## 5. Private goals

Something that is not the workshop's goal.

A spot it likes to stand in. An object it keeps going back to. A colleague it
follows. A route it prefers even when it is not the shortest.

Give it a small chance of winning the utility contest outright, so occasionally
an elf just goes and does its own thing while there is work to be done.

**Behaviour the shared goal cannot explain is what makes an agent look like it
has reasons of its own.** This is the step that most separates a character from
a well-tuned worker.

## 6. Relationships

A small pairwise affinity table, `Dictionary` keyed by the other elf's id.

Nudge it up when they work near each other or hand something over, down after a
collision or being beaten to a resource.

Then feed it into `_weigh`: prefer stations near liked elves, avoid disliked
ones. Replaces the current blunt `sociable` trait, which only counts bodies.

## 7. Communication

Visible handoffs: one elf carrying to a pile meets one waiting, and passes the
item directly instead of both walking the full route.

Pointing at something before going to it. Standing aside in a doorway. Waiting
for a particular elf to finish before taking the bench.

**Coordination you can watch is worth far more than coordination that merely
happens correctly.** The current elves already cooperate through the utility
function, but none of it is legible, so none of it counts.

## 8. Motor signature

Individual walk cycles, idle fidgets, personal tool rhythms, how they stand when
waiting.

Lowest priority. This is polish on top of the above, not a substitute for it,
and doing it first is the classic way to spend a week and change nothing.

---

## Anti-patterns

Things that look like they should help and do not.

- **Randomness is not personality.** Noise added to timings reads as jitter, not
  character. Personality comes from consistent difference, which means the value
  has to be stored on the elf and reused.
- **More animation is not more life.** The arm-swinging was more animated than
  standing still and read far worse. Motion without a cause is worse than
  stillness.
- **Do not give them speech, names, or thought bubbles.** It replaces inference
  with assertion. The viewer believing there is someone in there is worth
  everything; being told there is is worth nothing.
- **Do not add a stats or status UI.** The moment an elf's state is legible as
  numbers it stops being a creature.
- **Do not make them efficient.** A perfectly optimal workforce reads as
  machinery. Hesitation, wasted journeys and mild disagreement are the point.
- **Do not let the elves reach for global state again** once beliefs exist. It
  will be tempting every time behaviour looks slightly wrong. That temptation is
  the whole thing collapsing.

## Budget

Eleven agents, 30fps, mobile renderer, on a phone that already ran warm once.

Beliefs, gaze and mood are all per-elf scalars and cost nothing.
The costs to watch are the land's triangle count and any per-frame loops over
all pairs of elves. The separation steering already in the working tree is
O(n squared) at n=11, which is fine, but do not add three more of those.

---

## State of the code

Branch `main`, everything pushed.

Committed and working:

- Four worlds, swipeable, landscape either way up.
- A real production chain: ore cut at the seam, forged to ingots, brewed to
  sparks. Every item is a mesh that is lifted out of a heap, reparented into the
  carrier's hands, and set down elsewhere. Heaps change size.
- Elves decide for themselves via utility scoring over persistent traits.
  Energy drains with work and returns at the hearth.
- Tools in hand while working, angled strikes into a workpiece.
- Per-elf appearance: height, girth, head size, skin, cloth, hat shape and lean,
  ear length, eye spacing, beards on about a third.

Committed but **never rendered or deployed**, in `scripts/elf_world.gd`:

- Individual movement: per-elf standing spots around stations, curved routes via
  a personal waypoint, separation steering so they stop walking single file.
- The spire. Sparks are no longer burned in a lamp; each becomes a permanent
  piece of a structure that rises and lights the room in proportion to its
  height. A disturbance knocks the top two pieces off.

**Build it before anything else.** The spire replaced the lamp, so check for
stale `_lamp_at`, `_lamp_stand`, `_lamp_node`, `_lamp_light` and `_lamp_fuel`
references first. That check was next and never ran.

The spire is superseded by the house in Part A, but get it building and looking
right before replacing it, or you will be debugging two things at once.

## Known rough

- Ladle sticks out sideways instead of dipping into the pot.
- Tree leaves are low-poly spheres and still read as blobs.
- Two apps named Bottle on the home screen: the 2D build should be retired.
- Whether the mobile-renderer pass fixed the phone running warm has never been
  confirmed on device.

## Building and deploying

```sh
cd Bottle3D
./deploy.sh          # export, build, install, launch
```

Faster loop for looking at things, no device needed:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 2622x1206 \
  -- --world=3 --capture=/tmp/shot.png --after=120
```

`--world` is 0 lightning, 1 tree, 2 ice, 3 elves.
Wait 100 seconds or more or the bottle has barely filled.

Never leave the Godot editor open while working from the command line.
It rewrites `project.godot` from its stale in-memory copy and has already
silently reverted the renderer and the orientation once each.
