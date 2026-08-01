# One world

Decided 2026-08-02, by the owner, in conversation.
This supersedes the five-parallel-islands structure.
It is a design direction, not a spec: nothing in it has been built yet.

---

## The change

Stop making the player choose an island.
There is one world, they start in one part of it, and they spread out across the rest of it over the weeks they spend paying attention to it.

The five biomes survive exactly as they are.
They stop being five separate saves and become five **regions of one place**.

---

## Why, beyond it being a nicer idea

The five islands are the weakest part of the current design, and it is worth being specific about why rather than just preferring the new thing.

**They are five parallel saves that never touch.**
Four of them are always frozen, because there is no offline progress and you can only look at one at a time.

**They fragment attention across five things in an app whose subject is sustained attention on one thing.**
That is close to self-refuting, and it quietly reintroduces five progress bars, which `HANDOFF.md` says the app does not want.

**They have no answer to "what happens when the house is finished".**
The current answer is "pick another island and build the same house again."
That is a repeat, not a continuation.

**The genuinely good part of them is wasted.**
`biome.gd` gives each island a different bottleneck: the Ice has almost no timber, the Dunes give sand for nothing, the Shore is a long way from iron, the Green fights you for stone.
Right now those are five puzzles solved in isolation.

In one world they start interacting.
You cannot settle the Ice until the Green is producing lumber to carry there.
The Dunes' glass has nowhere to go until somebody has framed something to put it in.
Five separate arguments about what to do next become one supply chain with geography in it, and the walk between regions is real walking, which is what this engine is already best at.

---

## The mechanics, cheapest and best first

### Zoom out is the map

Delete the picker screen entirely.
Pinch out past the current limit and the region recedes until you are looking at the whole world with your settlements on it; pinch in and you are back close enough to watch one pair of hands.
One continuous gesture, no screen, one less menu.

This is mostly a camera range change plus a level-of-detail rule, because the pinch gesture already exists in `main.gd`.
It is the first thing to build.

### Territory is not a painted area

It is the union of how far each person is willing to walk from a fire.
It grows when they are fed and confident and contracts after a disturbance.

Nothing to paint, nothing to number, and it falls straight out of the belief system that already exists in `elf_world.gd`.

### Expansion is carrying fire

A new region opens when somebody walks a lantern to it.
One hobbit, a long walk, and then a second hearth.

A legible, non-numeric, watchable unlock that reuses the hearth already in the world as the social centre.

### Roads wear in

Paths walked repeatedly become actual tracks in the terrain.
The world physically records where the attention went.

Cheap, probably a heatmap over the ground colour, and likely the most satisfying single item on this list.

### The world is finite and can be finished

Twelve to twenty authored sites, and then it is done.

An app about attention that never ends is an app about retention, which is the opposite thing.
"I finished it" is a rare, real, once-per-owner event, and those get talked about.

### Seasons run on accumulated stillness, not the calendar

Winter arrives when enough hours of held stillness have been put in.
The Ice is only reachable across a winter ice bridge.

Same principle as the existing spent-time clock: time you actually gave it, made visible as weather.

### Generations

They age over weeks of attention.
The one who laid the first footing is old by the time the last roof goes on.

The affinity system already grows specialisms, so an old mason teaching a young one is a small extension with a large payoff.
Still no names, still no stats, still no speech.
Recognition was always the thesis.

---

## Business model

### Paid up front

Ten to fifteen pounds.
No in-app purchases of any kind at launch: not cosmetics, not regions, not anything.

The pivot is what makes this viable.
Five parallel islands were genuinely unsellable in a trailer, because a trailer of five identical builds behind a menu shows nothing.
One world spreading along a coast sells itself in about eight seconds of footage with no voiceover, and without explaining the stillness rule at all.
Sell the world; let them find the mechanic when they arrive.

### Why not a free first region

This was proposed and rejected on 2026-08-02, and the reasoning should not be relitigated cheaply.

A free tier forces you to design a moment of wanting.
You end up tuning the free region so that it runs out at the right time, in the right way, leaving the right itch.
That is manufactured desire engineered into an app whose subject is calm, and it is the same self-refutation that already killed the subscription.

The owner's own objection was also correct on its own terms: the first region is the least interesting one, and somebody who finishes it has no idea what they would be buying.

### The doorway, if one is wanted

Not a free region. A free **look**.

A first-run state, before purchase, where the whole world can be orbited and zoomed and the weather can be watched, and there is nobody in it.
No building, no people, no timer.

It is honest, it has no conversion moment to tune, and the want it creates is the real one: the world is already there and it is empty.

### Apple Arcade as a parallel track

A finite, hand-authored, no-ads, no-IAP game with a distinctive look is close to exactly their brief, and it dissolves the pricing question entirely.
Worth pitching before launch rather than after.

### Later

Paid regions, one-time, years apart, never a season pass, and only if the finite world genuinely wants more.

### Make the refusals the marketing

No ads, no energy timers, no skip-the-wait, no daily rewards, and no notifications ever.
The line already exists in `HANDOFF.md` and should go on the store page: an app that monetises attention is self-refuting.

---

## The two real risks

**It becomes a colony sim.**
Guard rails: the world is finite and authored, and there is never a number on screen.
No territory count, no population count.
You can see how many people there are by looking at them.

**Attention splits.**
With no offline progress, a bigger world advances more slowly per unit of attention, because only what is being watched moves.
That is a feature rather than a bug: expansion becomes a real choice about where to spend your stillness.
But it has to be a stated rule rather than something people discover and read as broken.

---

## What this does to the code

Mostly additive, but not small.

**Survives untouched:** `plan.gd`'s queue, `biome.gd`'s palettes and pace tables, all of `elf_world.gd`'s behaviour work, the sky and the bodies.

**Generalises:** a queue currently belongs to an island and would need to belong to a *site*, with several sites per region.

**Changes shape:** `progress.gd` is keyed per island and would become one world state; `menu.gd`'s picker goes away entirely.

**Needs designing:** what a second, third and fourth site actually build, given that the three-storey house is the only structure `plan.gd` knows how to make.
This is the largest genuine unknown in the whole direction and should be answered before anything is built.
