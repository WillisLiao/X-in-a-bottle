# Next session: Meadow Act

For Luna Medium.

Read `HANDOFF.md`, `WORKING-NOTES.md`, `DESIGN-offline-long-road.md`, and this file before opening Godot.
The Sleeping Hill is complete in commit `435fc8e`.
Inspect its captures and test it on iPhone before changing its domain boundary.

## Mission

Build the first complete offline act of Hobbitle.

The Meadow Act is not three disconnected encounters.
It is a short, finite folktale with a beginning, escalating player choices, and a visible ending.
By its end, the Meadow has become an unmistakably changed home, the full band migrates across the causeway, and the Shore appears as the next unknown country.

The act must be playable in one relaxed sitting without waiting for background work, an app-open timer, a server, or a location permission.

## The act

### Chapter one: The Sleeping Hill

This is built.
The player guides a lantern through cairns, then resolves the hill into a Hollow Door near home or a Lantern Grove along the road.
Keep both outcomes and preserve existing saves exactly.

### Chapter two: The Rooted Gate

The route from Meadow to Shore is blocked by an enormous arch of living roots where the causeway begins.
The field map shows it as a dark green silhouette with a narrow warm seam visible beneath it.
It must read as an impossible door, not as a generic tree or a rock.

Before starting this expedition, the player chooses who carries the lantern.
At the Meadow hearth, one familiar hobbit and one familiar troll stand close enough to distinguish by silhouette.
Dragging one into the lantern circle chooses them.
Tapping either figure after selecting the lantern is the accessible alternative.

- A troll resolves the gate by lifting the root crown and revealing a short run of stone steps.
- A hobbit resolves the gate by carrying the lantern into a burrow seam and opening a flowering root arch.

Neither result is a stronger reward.
The troll result makes the causeway heavier and more monumental.
The hobbit result makes it stranger and more alive.
Both leave a permanent map-visible exit from Meadow toward Shore.

The chosen band member is not a disposable avatar.
Use one of the actual existing residents or its deterministic body seed.
Do not make a second generic character system just for expeditions.
The chosen species and visual outcome must persist in the fable state.

### Chapter three: The Field of Lost Lights

The newly opened gate exposes a field of drifting lights that cannot decide whether to leave Meadow or return to the hearth.
The player guides a small flock by drawing one smooth arc from the gate to one visible destination.
This is the only free-form gesture in the act.
It should feel like shepherding fireflies, not tracing a mobile-game line.

- Guiding the lights home creates a low constellation of warm windows and lanterns around the Meadow village.
- Guiding the lights outward creates a chain of travelling lights along the Shore causeway.

The gesture is forgiving.
Crossing the intended destination region resolves it.
There is no precision failure and no retry punishment.

The act's first two chapters establish a road and an exit.
This final choice decides whether Meadow is remembered as a warm refuge or a place that sends light into the unknown.

### The migration

After all three myths resolve, the Meadow field changes once before the player touches anything.
The full band gathers in a loose line behind the hearth, then the new route toward Shore breathes amber.
Tapping the route begins the migration.

The same band crosses the causeway in a staggered procession.
This is a short directed set piece, not an eighty-second background errand.
It must finish in under ten seconds and remain visually readable throughout.

Use actual resident body seeds and species where practical.
If the legacy `ElfWorld` cannot move all bodies safely across without coupling the expedition system to its work queue, build a one-purpose `MigrationVisual` from those seeds instead.
The visual must still read as the same people leaving the Meadow, not anonymous replacements.

The migration settles Shore and leaves Meadow with its permanent outcome visible from the map.
The camera follows the procession far enough to reveal one distant Shore disturbance, a drowned bell under the tide, then returns control to the player.
Do not build the Shore story in this pass.

## Product rules

- This is entirely offline.
- Do not add device location, accounts, APIs, servers, shared world claims, chat, currency, loot, daily tasks, timers, or background progress.
- Do not add a quest list, chapter counter, character names, speech, or numbers on screen.
- Do not turn the old construction queue into the primary progression system.
- Every chapter changes the physical field or village immediately and permanently.
- There is no failure outcome that removes finished world state.

The game is about choosing what kind of country the band makes, not maximizing a score.

## Architecture

### Generalize `FableState` before adding chapter geometry

The current fable state is intentionally narrow and holds `sleeping_hill` directly.
Do not add two more direct top-level fields and create a three-story special case.

Migrate it to a versioned fable catalog record:

```text
schema_version
world_seed
story_generator_version
fables:
  sleeping_hill: { version, seed, resolution }
  rooted_gate: { version, seed, chosen_species, resolution }
  lost_lights: { version, seed, resolution }
meadow_act_complete: bool
```

The migration from the shipped Sleeping Hill save is mandatory.
Map its existing resolution and seed into the `sleeping_hill` record without rerolling it.
Fresh saves may create all three deterministic records from `world_seed`.

Every visual generator reads a saved seed and generator version before building geometry.
Never reconstruct a different prior choice from a new random call.

### Add a small `FableCatalog`

Use one data-oriented catalog that describes the three Meadow chapters.
It should answer only:

- Which fable is currently available.
- Which region and world positions its visual uses.
- Which interaction mode it needs.
- Which earlier fable unlocks it.
- Which persistent resolutions it accepts.

Do not make a generic quest framework, dialogue system, or event bus.
The catalog exists to prevent three copies of the Sleeping Hill state machine.

`main.gd` should ask the catalog for the active fable and delegate input to that fable's visual and marks.
The renderer must not decide unlock order or persist outcomes.

### Expedition interaction

Keep the Sleeping Hill's focused `FableJourney` behavior for cairn routes.
Extract a small interface only if Rooted Gate and Lost Lights genuinely share it.
Avoid premature abstraction across unlike gestures.

Rooted Gate needs a band-choice state before its route starts.
Lost Lights needs a drawn-arc state with a broad destination test.
Both must have tap alternatives where a drag is the main expression.

New custom controls must project real `Node3D` positions through the camera each frame.
Do not hard-code destinations as fixed viewport fractions.
All targets need at least 44 points after device scale.

### Visual modules

Keep each permanent landscape change in a dedicated renderer with a small saved-state input.

- `SleepingHillVisual` remains the chapter-one renderer.
- `RootedGateVisual` owns root arch, troll stone steps, hobbit flowering arch, and the map-visible Meadow exit.
- `LostLightsVisual` owns the drifting light flock, home lights, and outward causeway lights.
- `MigrationVisual` owns only the short cross-causeway procession and can be freed after it finishes.

Do not add textures.
Use existing low-poly geometry helpers and material helpers.
Every vertex color must go through `.srgb_to_linear()`.
Merge static feature geometry where the mobile renderer would otherwise receive many tiny `MeshInstance3D` nodes.

## Input and camera

The field is still the primary view.
Legacy builder simulation remains paused in field mode.

Input priority is:

1. An active chapter's gesture or destination interaction.
2. The current fable's visible lantern or disturbance.
3. The migration route once Meadow is complete.
4. Existing map interactions.

Chapter completion should frame the changed feature for a moment, but never lock the player into a cutscene or delay input beyond the short resolution bloom.
Migration may control the camera while it runs, but it must end promptly and restore normal field controls.

## Capture hooks

Replace the single-story capture surface with deterministic act hooks.

```text
--act-reset
--fable=sleeping-hill|rooted-gate|lost-lights|migration
--fable-stage=dormant|carrying|choosing|hollow|grove|troll|hobbit|home|outward|complete
```

These flags must set the same persisted fable records and renderer states the player can produce.
They must never bypass migration, seed selection, or the actual resolution path with an unrelated display-only mesh.

Capture and inspect at 2622x1206:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=field --act-reset --fable=rooted-gate --fable-stage=choosing \
  --capture=/tmp/hobbitle-rooted-gate.png --after=20
```

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=field --act-reset --fable=lost-lights --fable-stage=choosing \
  --capture=/tmp/hobbitle-lost-lights.png --after=20
```

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=field --act-reset --fable=migration --fable-stage=complete \
  --capture=/tmp/hobbitle-meadow-migration.png --after=20
```

The captures pass only if a viewer can identify the active strange place, the available physical choice, and the permanent result without reading source code.

## Tests and verification

Add pure tests for:

- Migrating a Sleeping Hill version-one save into the catalog without changing its resolution or seed.
- Fable unlock order.
- Rooted Gate's persisted species and resolution.
- Lost Lights' persisted resolution.
- Idempotent migration completion and Shore settlement.
- No test writes to `Progress`, `user://`, or the real player configuration.

Run all existing pure tests, the one-minute legacy simulation, and `--headless --quit`.
Run Godot import after every new `class_name`.
Inspect every capture and deploy the finished act to the iPhone.

Manually confirm:

- The player can finish all Meadow stories without touching a timer or a construction queue.
- Both Rooted Gate body choices are obvious and lead to visibly distinct world results.
- Lost Lights resolves with either drag or tap.
- The full band migration reads as a single memorable event.
- Relaunch preserves all choices and leaves Shore settled.

## Commit sequence

1. Save migration and fable catalog with pure tests.
2. Rooted Gate and actual band selection.
3. Field of Lost Lights and its permanent outcomes.
4. Migration visual, Shore settlement, camera work, and capture hooks.
5. Captures, device test, handoff and devlog update, then a final commit.

## Definition of done

Hobbitle has a complete first act.
The player makes three kinds of tactile expedition choice, reshapes Meadow in ways visible from both map and village, and sends the familiar band into Shore through a migration worth showing someone.
It is unmistakably an offline adventure game rather than a passive builder with a map.
