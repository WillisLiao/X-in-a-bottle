# Next session: first playable living world

For Luna Medium.

Read `HANDOFF.md`, `WORKING-NOTES.md`, `DESIGN-living-world.md`, and this file before opening Godot.
The map-first field loop is complete in commit `9cbf377`.
This is the first substantial gameplay milestone after it.

## Mission

Build the first complete Hobbitle story a person can play instead of watch.

A player must be able to take a real short walk, or use a deterministic developer route, and experience this unbroken sequence:

1. Enter the living field from the title.
2. Begin one explicit journey.
3. Cross enough coarse cells for a new route to appear.
4. Reach a wordless rumor at the route's end.
5. Make an irreversible physical choice about that rumor.
6. See a unique permanent change in their village.
7. Send the alternative outcome toward a visible borough wayhouse project.
8. Return to the field and see that the road and the chosen outcome still exist.

The end result must be recordable as a three-minute demo that makes sense with the sound off.
It cannot be a route line plus a passive construction scene.

## What this proves

This pass proves the core product sentence in playable form:

> The walk I take every day becomes a road in this world, and that road changes who lives in my village.

It introduces neither fake social activity nor a general-purpose task list.
The borough project is a truthful local contribution record and a visual promise of the real shared world.
No simulated strangers, fabricated chat, fake online counts, or pretend player names may appear.

The backend is deliberately the following milestone because it needs deployed infrastructure, abuse controls, and real account policy.
This handoff leaves a deep, tested boundary for it rather than a misleading imitation.

## The playable encounter

### The subject

The first rumor is a wayfarer carrying a seed-lantern.
It is not explained in dialogue.
At a new route's endpoint, a small traveler stands beside the road with a warm seed held at chest height.
The seed has a slow glow and the traveler turns between the player's hearth and a distant roadside foundation.

This is not a collectible, a chest, or a monster encounter.
It is an invitation to decide where a person and their possibility belong.

### The choice

The player drags the seed-lantern toward one of two physical destinations that are both visible in the field:

- **Home hearth.** The wayfarer becomes a local resident and the seed becomes a permanent personal village feature.
- **Wayhouse foundation.** The wayfarer carries the seed down the road, and the foundation receives a permanent borough contribution.

Both outcomes must be valid and desirable.
The home choice is identity and personal visual change.
The wayhouse choice is civic authorship and visible public infrastructure.
Neither choice should be framed as optimal.

Do not require the drag alone.
The destinations must have wide tappable regions, and a tap on one after selecting the seed must resolve the same outcome.
The hover path under the dragged seed must make the consequence obvious without text.

### The permanent result

The home outcome adds exactly one seed-derived feature to the village:

- an orchard arch with three low trees;
- a lantern stoop with an amber roof light; or
- a stone sitting wall around a flowering patch.

The result is selected deterministically from the encounter seed and the village seed.
It must survive relaunch.
It must alter the silhouette from the close village view and leave a small warm point visible from the field.

The wayhouse outcome adds one construction element to a real map foundation:

- foundation stones;
- a timber frame; or
- a lantern roof.

The initial local version must only show the player's own contribution.
It must never claim that an empty local save is a bustling community.

The two choices are deliberately asymmetric in location, not reward power.
This gives a player a reason to compare villages and boroughs later without introducing an inventory screen or score.

## Product boundaries

### Build in this pass

- An explicit foreground journey action in the field.
- A private iOS Core Location bridge that emits only coarse cell transitions to Godot.
- Deterministic debug journey injection that exercises the exact same domain path.
- A route endpoint encounter and wordless two-destination resolution.
- A versioned personal-village seed and grammar for the three small permanent features.
- A versioned local borough-project record and a visible wayhouse foundation.
- A clean return from encounter to field and close village.
- Device deployment and captures that prove the full loop.

### Do not build in this pass

- Raw coordinate persistence.
- Background tracking, Always location permission, or a hidden long-running location service.
- A backend, account system, friend graph, push notification, leaderboard, chat, or player names.
- StoreKit, paid boosts, streaks, raids, daily chores, energy, timers, loot boxes, or currencies.
- A replacement for the legacy 498-work construction queue.
- A hundred-house grammar or a multi-site migration of the legacy construction saves.

The point is one complete story, not a false claim that all of Hobbitle is built.

## Location and privacy contract

### Product decision

The game may use precise location only during an explicit foreground journey started by the player.
The location manager stops as soon as the journey has enough valid coarse transitions to create the encounter.
The app does not collect routes in the background and does not ask for Always authorization.

This is the right first implementation for the battery concern that killed the focus-app direction.
Apple's standard location service is more precise and more power-intensive than visits or significant-change monitoring, so it is appropriate only for this player-initiated, short foreground action.
Apple explicitly recommends choosing the lowest-power service that meets the need and stopping it as soon as the required data is obtained.
See [Apple's Core Location guidance](https://developer.apple.com/documentation/CoreLocation/getting-the-current-location-of-a-device).

### Data boundary

The native side receives `CLLocation` values only in memory.
It filters stale, inaccurate, implausibly fast, and duplicate samples.
It quantizes accepted samples into an opaque `WorldCell` before sending them to Godot.
It immediately drops the raw coordinate.

`WorldCell` is the only location type GDScript receives or persists.
It must contain a stable coarse identifier and no latitude, longitude, accuracy, timestamp, altitude, heading, or device identifier.
`RouteBook` continues to store only cell crossings.

Use a coarse regular grid for this local iOS milestone rather than adding H3 or an external mapping dependency prematurely.
Choose the cell width from an on-device walking test, not from a desktop estimate.
It must be broad enough that ordinary GPS drift does not scribble parallel roads, while still allowing a person to cross several cells on one short block.
Document the selected value and capture evidence at the point of use.

The future shared service may replace this grid with a privacy-reviewed hierarchical index.
That decision waits until the server can enforce aggregation thresholds and prevent route reconstruction.

### Native bridge shape

Create a narrow `LocationSource` abstraction for the field loop.

```gdscript
signal cells_arrived(cells: Array[WorldCell])
signal journey_stopped(reason: JourneyStopReason)

func begin_journey() -> void
func stop_journey() -> void
func authorization() -> JourneyAuthorization
```

`DebugLocationSource` feeds named deterministic samples from capture flags.
`IOSLocationSource` is the only implementation that knows about native plugin calls or permission state.
The encounter, route, village, and borough modules must only receive `WorldCell` values.

Use a Godot iOS plugin rather than placing Swift or Objective-C behavior into exported Xcode output.
Godot's iOS export supports special iOS plugins, and the plugin must be rebuilt or configured through the supported export path rather than patched into a generated project.
See [Godot's iOS export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).

Use a clear `NSLocationWhenInUseUsageDescription` purpose string.
The system dialog is unavoidable text, so it must say plainly that Hobbitle turns an active walk into a private, coarse fantasy route and never saves the route's raw coordinates.

### Journey behavior

`JourneyMark` is one custom-drawn ember lantern at the safe lower edge of the field.
It is the visible non-gesture alternative for beginning a journey.
Tapping it gives immediate press feedback, requests authorization only when needed, then shows a restrained amber pulse along the home road while listening.

The journey ends after a small, documented number of valid cell transitions and immediately creates the route-end encounter.
Do not draw a numeric distance, a countdown, or an activity ring.
The lantern's glow becoming fuller and the road growing are the only progress feedback.

If permission is denied, the lantern settles into a quiet dormant state.
Do not nag.
The deterministic developer journey remains available only through capture and debug flags, never as a disguised production action.

## Domain model and save format

Do the save work before building any grammar.
The legacy `Progress` region records remain untouched because their `done` indices are meaningful only to the old fixed queue.
The new living-world state belongs in a new versioned world-level record.

### `LivingProfile`

Add a pure domain record and persistence adapter with these fields:

```text
schema_version
world_seed
home_cell
village: VillageRecord
encounters: EncounterRecord[]
borough: BoroughRecord
```

`schema_version` governs the entire new record.
`world_seed` is generated once and never regenerated after first save.
`home_cell` is the first accepted coarse cell, not a raw coordinate.

### `VillageRecord`

Every generated personal element needs its own generator version and seed before it is rendered.

```text
generator_version
seed
features: VillageFeatureRecord[]
```

Each feature record contains a stable identifier, a kind, its seed, and the resolved encounter identifier.
The renderer rebuilds from this record before applying any visual state.
Never derive a building shape from a current random call after loading a saved choice.

This repeats the save-format rule in `NEXT-SESSION-what-the-other-sites-build.md` on a smaller, safer grammar.
Getting it right here prevents a future village grammar from silently changing existing homes.

### `EncounterRecord`

Derive the encounter identifier from `world_seed`, route-end `WorldCell`, and an encounter generator version.
Save its resolution explicitly.
An unresolved record is allowed only while the encounter is visibly active.
Once resolved, its chosen destination is permanent.

Do not save a sequence of raw route samples to reconstruct the encounter later.

### `BoroughRecord`

The first record is deliberately local but matches the future server's shape:

```text
borough_id
generator_version
wayhouse_seed
own_contribution_ids: PackedStringArray
```

The wayhouse renderer must derive its stage from the player's actual local contributions.
It must not infer a shared population or fabricate outside activity.

## Modules

Keep the interfaces deep and narrow.
Do not put persistence, screen coordinates, and game choices into `main.gd`.

### `JourneyBook`

Owns accepted `WorldCell` sequences, route completion, and the handoff to `RouteBook`.
It rejects duplicates and impossible transitions without knowing where the cells came from.
It exposes one completed journey event, not a stream of renderer state.

### `EncounterBook`

Owns deterministic encounter creation and irreversible resolution.
It accepts a route-end cell and a `LivingProfile` seed.
It exposes the active encounter and one `resolve(destination)` operation.
It does not know whether the player used an iPhone location bridge or a debug journey.

### `VillageGrammar`

Builds the three personal village feature variants from `VillageRecord` values.
It creates low-poly geometry only, with existing material helpers and sRGB-to-linear vertex colors where vertex colors are written.
It must return static meshes or one compact root per completed feature so the village remains within the mobile renderer's 30fps budget.

### `BoroughWayhouse`

Builds the visible map foundation and its one-to-three local construction stages.
It accepts a `BoroughRecord` and has no account or network logic.
The future server should be able to replace the record's content without changing this renderer.

### `EncounterMarks`

Is a custom `Control` responsible only for the screen-space encounter affordance and the seed drag path.
It uses `_draw()`, large physical-pixel hit areas, and no themed widgets.
It must not own persistence or decide encounter results.

Do not create all of these modules if a single existing module can own the responsibility cleanly.
`RumorMarks` may evolve into `EncounterMarks` if the resulting interface stays smaller and clearer.

## Visual direction

The player should feel they found a small human story at the end of a path, not opened a reward crate.

The wayfarer is small, warm, and still.
The road is the line of energy in the composition.
The player hearth and wayhouse are two quiet visible destinations at opposite ends of that line.
The seed is the only bright movable thing.

Use the existing earth, amber, hearth, and nocturnal blue palette.
Do not introduce cards, inventories, modal windows, purple glass, texture assets, generic map pins, or conventional mobile-game effects.
Use only three motions: the seed breath, the destination preview, and the resolution bloom.

The close village change should be immediately legible in silhouette.
Do not hide it behind the legacy build queue or make the player wait for workers to finish.
The choice is a story outcome and should feel consequential immediately.

All custom controls must have at least a 44-point touch target after device scale.
The visible interactive elements must remain away from the Dynamic Island and home indicator.
The active journey lantern, encounter seed, and destinations need visible affordances as well as their gestures.

## Suggested order and commits

1. **Save and domain first.** Add `LivingProfile`, versioned village and borough records, `JourneyBook`, and pure tests for deterministic save and reload.
2. **Connect a developer journey.** Make a named debug journey create an encounter through the same `JourneyBook` path that native location will use.
3. **Build the encounter and permanent geometry.** Add the wayfarer, seed resolution, village features, wayhouse stages, and custom-drawn field interaction.
4. **Add the iOS location bridge.** Implement foreground When In Use permission, in-memory filtering, cell quantization, stop behavior, device deployment, and a real short-walk test.
5. **Polish the complete story.** Tune camera focus, field composition, motion, haptics if the native bridge makes them available, and the return to village or field.
6. **Capture and document.** Inspect every state, record the actual short-walk result, update handoffs and devlog, then commit the completed milestone.

Do not move on to a server or social product just because the data structures now look ready.
First make this one-person story emotionally legible and visually worth sharing.

## Verification

After every new `class_name`, run:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D --headless --import
```

Run pure tests for at least these cases:

- The same `LivingProfile` save rebuilds the same village feature after reload.
- A changed generator version does not silently reinterpret an old record.
- A duplicate or impossible cell sequence does not create a second road or encounter.
- Resolving an encounter once persists the result and cannot resolve it again.
- A local borough contribution creates exactly one wayhouse stage change.

Run the existing route-book test, one-minute simulation, and headless parser.
The old construction simulation must not advance while field state is open.

Add deterministic capture flags such as `--journey=meadow-shore`, `--encounter=wayfarer`, and `--choice=home|wayhouse` if they keep the actual domain path intact.
Do not make a capture-only visual shortcut that bypasses persistence and resolution.

Inspect captures at 2622x1206 for:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=field --journey=meadow-shore --encounter=wayfarer \
  --capture=/tmp/hobbitle-wayfarer.png --after=20
```

Capture each choice in field and village view.
The two outcomes must read as meaningfully different without text.
Deploy to the iPhone and walk far enough to cross the chosen coarse cell threshold.
Verify in the live device save that the app stores only coarse cell values and the route, encounter, village feature, and wayhouse survive a full relaunch.

## Definition of done

The app is no longer something a person merely watches.

A player can choose to take a short journey, see their movement become a road, meet a tangible mystery, make a choice, and leave a unique permanent mark at home or in a public place.
The story is wordless, battery-bounded, private by construction, and visually clear at iPhone scale.
It creates an honest foundation for the later shared world instead of faking one.
