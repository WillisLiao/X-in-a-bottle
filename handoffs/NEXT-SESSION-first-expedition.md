# Next session: The Sleeping Hill

For Luna Medium.

Read `HANDOFF.md`, `WORKING-NOTES.md`, `DESIGN-offline-long-road.md`, and this file before opening Godot.
The map-first field loop is complete in `9cbf377`.
The working tree also contains an uncommitted stopped attempt at the superseded location plan.
This session owns that attempt and must adapt or remove it before committing.

## Mission

Build one complete offline expedition that turns the field map into a game.

The player starts in the Meadow field.
They see a sleeping hill beyond the home hearth.
They take the lantern along a short visible road, wake the hill's myth, and choose where the lantern belongs.
The world immediately becomes different and stays different after relaunch.

The player must never need a location permission, a server, a timer, or an app-open construction wait.

## The story

### The Sleeping Hill

The Meadow's first disturbance is a low mossy hill with a slow amber breath under its surface.
It is large enough to read from the field, but quiet enough to feel discovered rather than advertised.
A warm thread leads from the home hearth to the hill.

Tapping the field lantern begins an expedition.
The player guides the lantern along three broad visible cairns on that thread.
This is a tactile route gesture, not a GPS recording and not a fake walking simulation.
Each reached cairn leaves a small permanent ember on the new road.

At the hill, a round seam opens and the lantern seed rises out of it.
The player chooses one of two visible destinations:

- **The home hearth.** The seed becomes a warm round Hollow Door in the close Meadow village.
- **The road beyond the hill.** The seed roots into a Lantern Grove, a visible pair of warm trees along the new field road.

The choice is made by dragging the seed to a destination or by selecting the seed and tapping a destination.
No label, number, speech, card, reward chest, or modal may explain it.
The destination preview must make the consequence clear through the camera, the glow path, and the physical geometry.

Both outcomes are final and equally valuable.
The Hollow Door makes a village more intimate.
The Lantern Grove makes the country more adventurous.

## The complete playable sequence

1. The title enters field mode at the Meadow.
2. The Sleeping Hill is visible before the player touches anything.
3. The player taps the large ember lantern affordance to begin.
4. Three broad cairns appear on the route to the hill.
5. The player drags the lantern across the cairns, or taps each active cairn in order.
6. The route grows an ember seam as each cairn resolves.
7. At the hill, the seed rises and both outcome destinations become visible.
8. The player sends it home or onward.
9. A short, interruptible resolution bloom plays.
10. The field shows the new road and Grove, or the camera descends to show the Hollow Door.
11. Relaunching preserves the result and never replays the unresolved story.

The whole sequence should take less than a minute after the player taps the lantern.
It is a scene with player action, not a loop where the band works unattended.

## First action: reconcile the stopped working tree

Before creating more code, inspect the uncommitted files left by the stopped location-plan attempt.

```text
scripts/debug_location_source.gd
scripts/journey_book.gd
scripts/journey_marks.gd
scripts/encounter_marks.gd
scripts/living_profile.gd
scripts/living_world_visual.gd
tools/living_world_test.gd
```

Keep and adapt the useful separation of persistent state, route validation, visual geometry, and custom-drawn interaction.
Do not commit their current product language or behavior unchanged.

`debug_location_source.gd` must be replaced with an offline `FableJourneySource` or equivalent.
It represents fixed story route steps inside the fantasy world.
It must not mention native location, GPS, cell privacy, a future iOS bridge, or a developer-only source.

`JourneyBook` may remain, but its inputs are story-route steps, not location cells.
It should validate the three steps of the hill path and signal a completed expedition.

`LivingProfile` may remain if it is renamed or rewritten as an offline fable-state record.
Remove borough, shared-world, wayhouse, raw-coordinate, and location terminology.
The first saved state needs only a world seed, a story generator version, and the Sleeping Hill resolution.

`LivingWorldVisual` and `EncounterMarks` are useful starting points, but their generic traveler and home-versus-wayhouse composition do not meet this story.
Replace them with the Sleeping Hill, the cairn route, the seed, the Hollow Door, and the Lantern Grove.

`tools/living_world_test.gd` currently calls `Progress.set_living_profile()` and `Progress.flush()`.
That is a test pollution bug.
The test must become pure before the feature ships, because it currently writes a synthetic world into the player's actual save.

Do not use `git reset`, discard the whole working tree blindly, or erase the map-first work.
Preserve useful code intentionally and remove only the superseded location and fake-borough concepts.

## Save format

Do the save format first.

Add one versioned offline fable record under `Progress`.
The legacy per-region construction records remain untouched because their `done` indices belong to the old fixed queue.

The record must contain:

```text
schema_version
world_seed
story_generator_version
sleeping_hill: unresolved | hollow | grove
sleeping_hill_seed
```

Generate `world_seed` once and persist it before building the hill.
Generate `sleeping_hill_seed` from that world seed and never replace it after reload.
The Hollow Door and Lantern Grove are rebuilt from the saved seed and generator version.

This is the same invariant as the house-grammar warning in `NEXT-SESSION-what-the-other-sites-build.md`.
The generated visual must never change merely because the generator code is later tuned.

Provide a pure load-from-dictionary constructor or serializer for tests.
The unit test must not read or write `Progress`, `user://`, or the real configuration file.

## Architecture

### `FableState`

Owns the versioned persistent data described above.
It contains no renderer nodes, input events, or screen coordinates.
It exposes the unresolved or resolved Sleeping Hill state and one irreversible resolution operation.

### `FableJourney`

Owns the three-step expedition state.
It receives intentional route-step input from the field interaction.
It emits a completion event once all visible cairns are reached in order.
It is not a clock, route recorder, or background process.

### `SleepingHillVisual`

Owns the actual world geometry for the hill, cairns, new road seam, seed, Hollow Door, and Lantern Grove.
It should be built from low-poly primitive and project geometry helpers, not textures.
It must be positioned relative to the active Meadow region so it remains correct if the camera or world origin moves.

The hill needs a distinct silhouette.
Do not use a single generic boulder.
Try a low wide body with a moss cap, a closed round seam, and a slight warm light leaking from below.
If the first capture reads only as a rock, change the silhouette before adding more effects.

### `ExpeditionMarks`

Owns all screen-space field interaction for this story.
It is a custom `Control` with `_draw()`.
It draws the field lantern, active cairn, seed, wide destination regions, and brief resolution bloom.

It receives real world positions from `SleepingHillVisual` and projects them through the current camera each frame.
Do not hard-code viewport fractions for story destinations.
The marker must remain aligned during orbit, map movement, and on both iPhone and capture resolutions.

Expose both drag and tap alternatives with at least a 44-point hit area after device scale.
The motion needs to be interruptible and visible within 100ms of touch.

### `main.gd`

Keep `FIELD` and `VILLAGE` modes from `9cbf377`.
Field mode remains the primary home and legacy `ElfWorld.advance(delta)` remains paused there.

Add a narrowly scoped expedition state, separate from view mode.
Its only states are dormant, carrying, choosing, and resolved.
Input priority in field mode is:

1. Active expedition interaction.
2. Field lantern starts the Sleeping Hill expedition.
3. Existing rumor and region interactions.

The old feast and close-village builder actions must never intercept the expedition.
On a Hollow Door resolution, descend into village view after the bloom.
On a Lantern Grove resolution, remain in field view and reframe the road and trees.

## Visual and interaction rules

The Sleeping Hill is the only active invitation in a fresh field.
Remove or quiet any old route rumor that competes with it during this story.

The user needs to understand the next action from the world itself:

- The home hearth is warm and stable.
- The hill breathes slowly at the far end of the route.
- The lantern is bright and tappable.
- Only the next cairn is bright while carrying.
- The seed's two glow paths lead toward visibly different places.

Use the existing ember, earth, hearth, meadow green, and night-blue palette.
Do not add a dashboard, notification badge, progress bar, generic pin, text tutorial, themed widget, texture, or number.

The journey needs no score and no fail state.
If the player lets go of the lantern, it settles at the last reached cairn.
It never resets completed segments or punishes them.

## Capture hooks

Replace the superseded `--journey` and `--choice=home|wayhouse` hooks with story-specific hooks.

```text
--story=sleeping-hill
--story-reset
--story-stage=dormant|carrying|choosing|hollow|grove
```

The hooks must drive the same fable-state and visual path as real input.
They must not inject finished meshes that the player path cannot create.

Use these captures and inspect every PNG before saying the story reads:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=field --story-reset --story=sleeping-hill \
  --capture=/tmp/hobbitle-sleeping-hill.png --after=20
```

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=field --story-reset --story=sleeping-hill --story-stage=choosing \
  --capture=/tmp/hobbitle-sleeping-hill-choice.png --after=20
```

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=field --story-reset --story=sleeping-hill --story-stage=grove \
  --capture=/tmp/hobbitle-sleeping-hill-grove.png --after=20
```

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=world --story-reset --story=sleeping-hill --story-stage=hollow \
  --capture=/tmp/hobbitle-sleeping-hill-hollow.png --after=20
```

The fresh-field capture passes only when a person who has not read the source notices the hill and the lantern path.
The choosing capture passes only when the two destinations have distinct visual meaning without labels.
The resolved captures pass only when the home and road outcomes clearly differ at a glance.

## Verification

Run headless import after each new `class_name`.
Run the existing route-book test and one-minute legacy simulation.
Run a new pure fable-state test that proves seeds and resolutions survive serialize and deserialize without writing `Progress`.
Run `--headless --quit` after each structural stage.

Manually test on iPhone:

- Title enters the field with the Sleeping Hill visible.
- The lantern, cairns, seed, and both destinations have forgiving touch targets.
- The drag and tap alternatives both resolve the story.
- Field mode does not advance the legacy builder simulation.
- Relaunch preserves Hollow Door or Lantern Grove exactly.

Commit in focused stages:

1. Offline fable state and pure tests.
2. Sleeping Hill geometry and route interaction.
3. Choice resolution and permanent visual outcomes.
4. Captures, handoff update, devlog, and final verification.

## Definition of done

Hobbitle opens as a playable expedition game.
Within one minute, the player guides a lantern to a myth, makes a wordless choice, and permanently changes either their Meadow village or its first road.
The whole experience is offline, immediate, battery-bounded, and visually different from merely watching builders work.
