# Design: Hobbitle, The Long Road

Accepted 2026-08-02.

## The premise

Hobbitle is an offline, wordless expedition fable.
A familiar band of hobbits and trolls crosses a strange country, resolves its myths, and leaves permanent villages and roads behind.

The player does not manage a workforce, collect currency, or wait for a timer.
They choose what promise the traveling band carries into the next impossible place.
Every choice changes the world immediately and permanently.

The final world is a personal folk tale.
It is a completed country that could only have been made by that player.

## The objective

Carry the band's lantern across the five regions and make each region a home.
Each region contains a small chain of mythic expeditions.
An expedition resolves into a new route, a village feature, a resident, a landmark, or a change in the landscape.

The final act is the completed Long Road crossing the whole country.
The band reaches the final village through every place it changed on the way.

The game is finite.
Finishing it should feel like completing a folktale, not falling off a retention treadmill.

## The player loop

1. Enter the field map.
2. Notice one living disturbance in the country.
3. Carry the lantern along a visible route through a short tactile journey.
4. Meet a myth and make one physical, irreversible choice.
5. Watch a brief immediate consequence.
6. Return to the field and see a new permanent part of the world.

The close village is where the player visits the consequence.
Construction animation remains useful as a short aftermath, but it is never the game clock and never makes the player wait.

## The band

The existing hobbits and trolls are the traveling band.
They are not generic workers and do not need player-visible names, statistics, or dialogue.
Their bodies, habits, affinities, pairings, and gestures make them recognizable.

Hobbits suit intimate, delicate, and social myths.
Trolls suit impossible physical problems, such as lifting a fallen star or moving a river stone.
The player eventually chooses who goes on an expedition, but the first expedition may use the established band without adding a roster screen.

Some members may eventually remain in villages they helped create.
That is an emotional outcome, not a resource optimization system.

## The myths

Each biome has its own kind of strangeness.

- Meadow: sleeping hills, buried doors, seed-lanterns, gentle giants.
- Shore: drowned bells, empty boats, tide houses, gull spirits.
- Dunes: mirror storms, glass creatures, walking lights, lost wells.
- Green: migrating roots, remembering trees, animal roads, rain rooms.
- Ice: fallen stars, frozen giants, lights under snow, moving auroras.

Myths do not fail destructively.
The player's choice may make a road stranger, a village more unusual, or a future expedition take a different shape.
Nothing removes a completed feature or punishes a missed day.

## The visual rule

Every meaningful choice must become visible in the world.

A lantern left at a hill may become a warm round door near the home hearth.
A lantern carried through a grove may become a line of glowing trees along a road.
A star carried across Ice may leave the final village blue at night.

The field and the close village must be enough to read the history without a journal, checklist, stat panel, or spoken explanation.

## Offline is a feature

There is no location tracking, account, server, subscription, purchase, leaderboard, chat, daily task, background simulation, or API dependency.

The world is stored locally and works on a plane, in a car, and without a network connection.
The player can later share an exported postcard, clip, or world seed through normal iOS sharing, but that is not part of the core game and does not require a live service.

An offline game cannot truthfully claim that many players are changing one shared world.
It can instead make every player want to show someone the unusual world they made.

## Non-negotiables

- No textures.
- No numbers on screen.
- New UI is custom `Control` `_draw()`, never themed Godot widgets.
- No raw device location data or location permission.
- No background progress or waiting as the core loop.
- No fake social activity or simulated players.
- No destructive loss of completed world state.
- `enum Task` values are appended only.
- All vertex colors use `.srgb_to_linear()`.

## First playable story

`NEXT-SESSION-first-expedition.md` implements the first myth, **The Sleeping Hill**.
It is the proof that Hobbitle is an adventure game rather than a screensaver.
