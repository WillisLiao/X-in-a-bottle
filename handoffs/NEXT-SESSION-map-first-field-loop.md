# Next session: Map-first field loop

For Luna Medium.

Read `HANDOFF.md`, `WORKING-NOTES.md`, and `DESIGN-living-world.md` before opening Godot or moving code.
This document is the next implementation pass after commit `c35e875`.

## The correction

The current visual result is still the old app.
After the title, `Main._on_begin()` enters a close construction region and the player watches hobbits build.
The new road is a good technical proof, but it is visually a feature laid on top of a passive construction toy.

That is the wrong front door for a location-based social settlement game.
The first thing a player sees after the title must be the living field map.
The close village is a destination and a reward, not the activity the app asks the player to do.

The new first impression must answer three questions without a tutorial card:

1. This is a world with other places in it.
2. My real movement leaves a visible trace here.
3. There is one nearby mystery I can touch now.

## Chosen interface direction

Three directions were considered.

**Game dashboard over a map** was rejected.
It would make routes, materials, social activity, and construction legible quickly, but it would turn Hobbitle into a familiar mobile dashboard with badges, counters, and chores.
It contradicts the wordless, no-numbers, in-world interface constraint.

**Close village as home with a map button** was rejected.
It preserves the existing art and costs little architecture work, but it is exactly the passive builder view the owner said does not feel like a game.
Putting the living world behind an icon would make it feel secondary again.

**Field map as home, with the village reached by a physical camera descent** is selected.
The map already exists as one continuous world-space camera state.
It gives routes, rumors, distant hearths, and future borough change the entire frame.
Pinching into the player's hearth remains spatially continuous and makes the construction scene feel earned rather than mandatory.

The map should not imitate a conventional street map.
It is a night field of floating terrain, warm roads, hearths, weather, and a single living invitation.
The visual language is a lantern looking across a country, not a game HUD.

## Experience to build

### Entry

Keep the title minimal, but remove the sentence about hobbits building while the phone is still.
That statement belongs to the retired focus-app prototype and tells a new player to watch rather than move.
The title can retain `Hobbitle` and one short product sentence, such as "The paths you walk become roads."
Do not add a menu, a start checklist, a currency readout, or a tutorial modal.

Tapping the title's single action enters the field at full map distance.
It should use the existing camera's continuous world transform rather than cut to a separate scene.
The chosen home region still sits visibly near the foreground, with the rest of the arc beyond it.

### Field state

The field is a real top-level view mode, not merely `Main._zoom == ZOOM_MAX`.
While in field state:

- The active `ElfWorld` may remain built as static scenery, but its simulation must not advance.
- The existing map fog, distant regions, causeways, hearths, roads, and `RumorMarks` remain live.
- Pinching inward toward the home hearth enters village view.
- Pinching back out returns to field state without a screen transition.
- A tap on an unclaimed rumor claims it through the existing `Country.claim_rumor()` path.
- A tap on a settled home region descends to village view.
- The old construction actions, meal trigger, and break behavior must not intercept field taps.

The field's first local demo is the existing deterministic route.
`--route-reset --route=meadow-shore --screen=field` must open with one warm route from the Meadow toward Shore and an obvious unclaimed rumor near its midpoint.
This is a capture and developer-demo source only.
Do not sneak a fake route into release saves to make a fresh install look active.

### Rumor moment

The current star halo is correct in principle but too easily mistaken for a small rendering detail.
In field state it is the one active invitation, so it must be readable before the player starts hunting the screen.

Keep the marker wordless.
Use the existing four-point glint language, but add a restrained field-scale response:

- Its outer rays breathe at a slow, non-urgent rhythm.
- The nearby road ember briefly brightens into the marker, connecting cause and effect.
- Pressing it compresses the rays toward the point before the existing stone remains.
- Claiming it should produce one brief warm bloom and a small physical roadside marker.

Do not use a notification badge, a red dot, an exclamation point, a quest card, a timer, a count, or a text label.
The response must happen inside 100ms of the tap and must remain interruptible.

### Village descent

The village scene still has value as a close reward.
It is where a player can inspect the people, personal architecture, and the consequences of discoveries later.

Make the descent feel like moving toward a place in the field.
The camera should aim at the home hearth and ease inward from the map instead of swapping scenes or presenting a button.
The inverse gesture should return to the same field composition.
Preserve yaw where possible, so the player can recognize the road or distant region they just came from.

Do not make building progress the primary activity in this pass.
Do not add a job selector, resource counter, speed-up, or a reason to leave the app running.
The legacy construction simulation is reusable visual machinery while the player is visiting a village, nothing more.

## Architecture

### `scripts/main.gd`

Introduce an explicit view mode such as `ViewMode.FIELD` and `ViewMode.VILLAGE`.
Do not let unrelated checks infer the product mode from a zoom float.
`_map` can remain a continuous camera blend, while the named mode decides input priority and whether the legacy world advances.

Replace `_on_begin() -> _enter(_island)` with a field-entry method.
It must ensure the home `ElfWorld` and `Country` scenery exist, set the camera to `ZOOM_MAX`, and select `FIELD` before the first frame after the title disappears.

Split the current `_enter()` responsibility if necessary.
One path should prepare the active region's scenery and world state.
The other should intentionally descend into village view.
Do not duplicate world construction or create a second `ElfWorld` just for the map.

Gate `_world.advance(delta)` on village view.
This is essential.
If the map is the game home but the builder simulation continues unseen, the product still burns battery and earns prototype progress while the player is doing the new game.

Reorder `_finish_press()` around field interactions.
Field rumor claims must win over region travel.
Village-only feast handling must not run while the field is active.
Keep the existing generous physical-pixel rumor hit target.

Add `--screen=field` as the canonical capture mode.
Keep `--screen=map` as a compatibility alias if it costs little, because existing documentation and captures use it.

### `scripts/menu.gd`

Remove the focus-app claim from its comments and the visible title hint.
Do not extend the existing `Label`-based title system with new user-facing UI.
If title text changes in this pass, replace it with a custom drawn control using the existing app's understated ink and ember palette.
New interactive controls must be custom `Control` nodes with `_draw()` and pointer handling.

The title still gets one broad tap action.
It must communicate the living-world premise, not a building schedule.

### New field controls

Add at most two focused custom controls.

`FieldMarks` should own the wordless field-scale invitation treatment for roads, hearths, and the one unclaimed rumor.
It may replace `RumorMarks` if that keeps all screen-space field affordances in one deep module.
Do not create a generic HUD manager or a collection of shallow controls.

`ViewModeMark` should replace the remaining bottom-left `Turn` or `Move` `Label` only if this pass has room after the field loop is correct.
Use the already accepted top-right custom-drawn icons from `NEXT-SESSION-hobbitle-for-real.md`.
It is secondary to making the field understandable.

Every new class needs a Godot headless import after it is added.

### `scripts/country.gd` and `scripts/community_roads.gd`

Keep roads as map-level geometry in this pass.
Do not project them onto close terrain or turn them into a road simulation.
Expose only the small data needed for `FieldMarks` to place visible hints correctly.
`RouteBook` stays the domain owner and must not learn screen coordinates, input events, UI timing, or renderer details.

Do not store raw GPS data.
Do not add an iOS location bridge, account logic, backend request, friend system, or anti-spoofing code here.

## Visual rules

The field has one primary visual action: the unclaimed rumor.
The warm road leads toward it, and every other surface is quieter.
The home hearth is a persistent warm anchor, not a button badge.
The map retains darkness and atmosphere, but the road and rumor must survive a glance at the actual iPhone capture resolution.

Use existing earth, ember, hearth, and night colors.
Do not introduce an unrelated gradient dashboard, purple glass cards, textures, or conventional mobile-game chrome.
Use one or two meaningful motions only: the marker's breath and the claim bloom.
Respect reduced motion once native settings are available.

All touch targets must be at least 44 points after device scale is accounted for.
Leave safe space around the Dynamic Island and home indicator.
Never require a gesture alone for a critical action.
The rumor is visible and tappable, while pinch remains the continuous way to visit the village.

## Suggested commit sequence

1. Add named field and village modes in `main.gd`, make title enter the field, and stop legacy simulation in field mode.
2. Build the custom field invitation treatment and claim response.
3. Rewrite the title's focus-app language and remove or replace the legacy bottom-left text control.
4. Capture, inspect, test, update `HANDOFF.md` and `devlogs/`, then commit the finished pass.

Do not combine this pass with native location permission, a server, accounts, social invites, procedural house grammar, purchases, or a visual overhaul of close village construction.
Those are independent product milestones and combining them would hide whether the new front door works.

## Verification

Run headless import after each new `class_name`.
Run the existing `tools/route_book_test.gd` and one-minute `sim.gd` after the main-loop changes.
Run the parser with `--headless --quit`.

Capture each state at 2622x1206 and inspect the PNG before claiming it works:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=field --island=0 --route-reset --route=meadow-shore \
  --capture=/tmp/hobbitle-field-entry.png --after=20
```

The field-entry capture passes only if the road reads before its source code is known and the rumor is visually unmistakable without text.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path Bottle3D \
  --resolution 2622x1206 \
  -- --screen=world --island=0 --route-reset --route=meadow-shore \
  --capture=/tmp/hobbitle-village-descent.png --after=20
```

The village capture passes only if it now reads as a place visited from the field rather than the application itself.
Use a manual device check to confirm the title enters the field, the rumor claims reliably, and an inward pinch can reach the village.

## Definition of done

On a launch with the debug route, the player enters a living map first.
They see one road that implies a real walk, one clear wordless mystery, and a personal hearth among other places.
They can claim the mystery and intentionally descend to the village.
The construction scene no longer asks them to wait and watch as the main game.
No raw GPS, accounts, server code, IAP, themed widgets, textures, numbers, or new passive progression are introduced.
