# Next session: make the elves read as individuals

Everything here is about one environment, Elves in a Bottle, in `Bottle3D/`.
The other three worlds are in reasonable shape and are not the priority.

## Read this first

The elves are not conscious and will not be.
They are utility-maximising agents: on finishing a task each one reads global
state, scores every option through its trait weights, and takes the maximum.
There is no self-model and nothing it is like to be one.

Nobody knows how to build consciousness, there is no test that would confirm it
if we did, and it is not a specifiable requirement - there is no state in which
we could agree it was finished.
Do not accept it as a goal, and do not let it quietly become one.

The real goal, which is specifiable and testable:

> A person watching one elf for ninety seconds comes away believing there is
> someone in there.

Test it by showing the same elf to two people separately.
If they independently describe a similar personality, it is working.

## The root problem

**The elves are omniscient.**
Every one reads exact pile counts everywhere, instantly, through walls.

A mind is defined as much by what it does not know as by what it does.
An agent that is never wrong, never surprised, and never has to go and look
cannot read as having a point of view, because it does not have one - it has the
world's view.

Everything else that reads as NPC-ish is downstream of this.

## The blueprint, in priority order

Ordered by perceived interiority bought per unit of work.

### 1. Ignorance and belief

Replace the global reads in `_decide` with a per-elf memory of what it last saw:
*"the anvil had two ore when I was last there."*
Elves act on belief, arrive, and find it wrong.

This alone produces going to check, being surprised, and turning back, none of
which can be faked convincingly.
It is the single biggest lever and everything else is easier once it exists.

Sketch: `Elf.beliefs: Dictionary` keyed by pile, holding `{count, when}`.
Refresh a belief when within a couple of metres and facing roughly toward it.
Decay confidence with age so stale beliefs get checked.

### 2. Gaze

A head that turns, separately from the body.
Most of what humans read as mind is where attention points.

Glance at a passing colleague, look up at the spire, watch someone drop
something. Cheap, and out of all proportion to its cost.

The head is currently welded into the body mesh in `_build_body`; it needs to be
a child node with its own rotation before any of this is possible.

### 3. Mood in the body

One scalar per elf - tired, frustrated, pleased - driving posture, gait, pace and
pause length.
Personality becomes visible without adding a single decision rule.

### 4. Formed preferences

Delete the born-with `likes` trait.
Let affinity grow with repetition and success, so an elf *becomes* the smith over
twenty minutes rather than arriving as one.
A history you can watch accumulate is the cheapest available form of a self.

### 5. Private goals

Something that is not the workshop's goal: a spot it likes to sit in, an object
it keeps going back to, a colleague it follows.
Behaviour the shared goal cannot explain is what makes an agent look like it has
reasons of its own.

### 6. Relationships

Specific others rather than "nearby elves".
Works better near some, avoids others, waits for a particular one.

### 7. Communication

Visible handoffs, pointing, waiting, standing aside.
Coordination you can watch is worth far more than coordination that merely
happens correctly.

### 8. Motor signature

Individual walk cycles, idle fidgets, personal tool rhythms.
Lowest priority: it is polish on top of the above, not a substitute for it.

## State of the code

Branch `main`, everything pushed except the working tree noted below.

Committed and working:

- Four worlds, swipeable, landscape either way up.
- A real production chain: ore cut at the seam, forged to ingots, brewed to
  sparks. Every item is a mesh that is lifted out of a heap, reparented into
  the carrier's hands, and set down elsewhere. Heaps change size.
- Elves decide for themselves via utility scoring over persistent traits.
  Energy drains with work and returns at the hearth.
- Tools in hand while working, angled strikes into a workpiece.
- Per-elf appearance: height, girth, head size, skin, cloth, hat shape and lean,
  ear length, eye spacing, beards on about a third.

**Uncommitted, in `Bottle3D/scripts/elf_world.gd`, compiles but never rendered
or deployed:**

- Individual movement: per-elf standing spots around stations, curved routes via
  a personal waypoint, separation steering so they stop walking single file.
- The spire. Sparks are no longer burned in a lamp; each one carried over
  becomes a permanent piece of a structure that rises through the session and
  lights the room in proportion to its height. A disturbance knocks the top two
  pieces off.

The spire replaced the lamp, so check for stale `_lamp_at`, `_lamp_stand`,
`_lamp_node`, `_lamp_light` and `_lamp_fuel` references before building.
That check was the next thing to run and never ran.

## Known rough

- Ladle sticks out sideways instead of dipping into the pot.
- Tree leaves are low-poly spheres and still read as blobs.
- Two apps named Bottle on the home screen: the 2D build should be retired.
- Whether the mobile-renderer pass actually fixed the phone running warm has
  never been confirmed on device.

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

Never leave the Godot editor open while working from the command line - it
rewrites `project.godot` from its stale in-memory copy and has already silently
reverted the renderer and the orientation once each.
