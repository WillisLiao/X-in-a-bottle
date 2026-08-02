# Next session: what the other four regions build

Written 2026-08-02, at the end of the session that built the one-world pivot.

Read `handoffs/HANDOFF.md` first, then `handoffs/DESIGN-one-world.md`, then this.
The pivot is built: one world, five regions, a map you reach by pinching, ground that records where people walked, necks of land joining the regions, and a lantern somebody carries to settle the next one.

What is not built is the answer to the question `DESIGN-one-world.md` called "the largest genuine unknown in the whole direction", and it is now the thing blocking everything else.

---

## The question

`plan.gd` is 498 works in the order a house is actually built, and it knows how to make exactly one thing: a three-storey house, about a week of held stillness.

There are now five places to put it.

Building the same house five times is what the five-islands design did, and the pivot exists because that is a repeat rather than a continuation.
So: **what is at the second site, and the third, and the twelfth?**

Nothing else on the roadmap can be sized until this is answered.
Seasons, generations, the finite world and the ending all depend on knowing what a world that is *finished* contains.

---

## What the design document already commits to

Worth not relitigating, because these were decided deliberately.

**Twelve to twenty authored sites, and then it is done.**
Note that this is not one site per region.
It is several sites per region, and `DESIGN-one-world.md` says so directly: a queue "would need to belong to a *site*, with several sites per region."

**The world is finite and can be finished.**
"I finished it" is a rare, real, once-per-owner event.
An app about attention that never ends is an app about retention, which is the opposite thing.

**The regions have to interact.**
This is the load-bearing one.
The whole argument for the pivot was that five separate bottlenecks became one supply chain:

> You cannot settle the Ice until the Green is producing lumber to carry there.
> The Dunes' glass has nowhere to go until somebody has framed something to put it in.

If the sites do not consume each other's output, the pivot has bought a nicer map and nothing else.

---

## The shape the answer probably has

Not a decision - the owner's call - but this is where the existing code and the existing design both point, and it is worth starting from here rather than from a blank page.

### Sites are smaller than the house, and there are more of them

The house is 498 works and a week.
Twelve to twenty sites at that size is four months, which is not a finite world, it is a job.

A site nearer 60-120 works is one or two evenings.
The house stays as it is - the largest single thing in the world, the one that takes a week, and the reason the Meadow is where you start.
Everything after it is smaller and more varied: a mill, a jetty, a kiln-house, a watchtower, a bridge over a neck, a boat.

`plan.gd`'s work format already supports this without changing: a work is somewhere on the island, a bill of materials, and geometry that appears when the bill is met.
A limekiln, a floor joist and a doorknob are already the same type.
What is missing is not machinery, it is **authored content**, and that is the real cost of this direction - the largest cost left in the project.

### The bills reach across the world

The single most valuable thing a second site can do is need something the region it stands in cannot make.

The pieces for this mostly exist now:

- The regions are joined by real ground - `Causeway` answers `height`, and `ElfWorld._ground` takes whichever is higher.
- An elf can already walk out of its own region and back. The lantern carrier does it twice per settlement, and every bit of the body work applies to them unchanged.
- `ElfWorld` already holds the `Land` of its neighbours, so somebody standing over there is standing on something.
- The ground already records where people walk, so a route used for hauling **wears into a road by itself**. That is `DESIGN-one-world.md`'s "roads wear in" arriving for free, on the necks, as a consequence of the supply chain rather than as a feature.

What does not exist:

- A heap in one region cannot be seen or reached by an elf in another. `_believed_source`, `_home_for` and the belief system are all scoped to one `ElfWorld`.
- There is no notion of a work whose bill is partly satisfied from abroad.
- Only the region being watched ticks, which is correct and must stay correct. So a cross-region haul is *the watched region's elf walking to the other place and back*, not the other place sending anything.

That last point is a constraint and also the answer: hauling across a neck is a two-minute round trip that you watch, by one person, exactly like the lantern.
It should be rare and deliberate - a handful of loads per site, not a conveyor.

### Order is still the tech tree

`plan.gd`'s best property is that there is no unlock table: you cannot pour a footing before you have dug for it, and you cannot dig before somebody built the thing that digs, so it cannot deadlock.

Whatever is authored next has to keep that.
A site that needs iron from the Shore must come after something that makes iron reachable, by *order*, not by a gate.

**Beware the deadlock this direction can create.**
The existing queue cannot deadlock because everything it needs is local.
The moment a bill needs something from a region that has not been settled, it can.
The safest rule is probably: a site's bill may only reach into regions that are already settled at the time the site opens, which keeps the property by construction.

---

## Before writing four hundred works, answer these

1. **How many sites does a region get?** Twelve to twenty across five regions is two to four each. Is the Meadow's house one site or is it the whole of the Meadow?
2. **Is there a second house anywhere?** Or is the house unique, and everything else infrastructure?
3. **What does finishing look like?** The last work of the last site - what happens on screen? This is the once-per-owner moment and it should be designed before the run-up to it is.
4. **Does anybody live in the new regions?** Right now the lantern lights a hearth and the carrier walks home. Nobody lives there. A settled region with a fire and no people is fine as a waypoint and wrong as a settlement.
5. **What is the Ice for?** It is the furthest, hardest, most timber-starved region, deliberately placed behind the Green. If it is not the last thing you do, the geography is wrong.

---

## Smaller things also owed

These are all real and none of them blocks the above.

**Discoverability, three counts.**
Nothing signposts that the pinch keeps going out to a map - the picker used to be the way to the other places.
Tapping a non-neighbouring region does nothing at all, with no explanation; the chain of necks is meant to be its own explanation and that has never been tested on a person.
And a carrier sent while the world is mid-break stands on the causeway for the rest of the quarter hour, which is correct, striking, and unexplained.

**The world is lit by the region you are standing in.**
At map zoom the Ice's cold key sits over the Dunes.
Invisible until you look at everything at once, wrong eventually.
The fix is a world-level light with the regions contributing to it, and it wants doing before anybody films a trailer.

**Nobody lives in a settled region.** See question 4 above.

**The turn/move control.**
Still one `Label` in the bottom left of `main.gd`'s `_build_back`.
Asked for as drawn icons in the top right - section 3 of `NEXT-SESSION-hobbitle-for-real.md` has the full spec and it still stands.

**The wider polish pass.** Section 5 of the same file.

**Body nits.** A troll's waist wrap is barely visible under the gut, and its upper arms merge into the trunk from some angles.

---

## How to look at any of this

```sh
cd Bottle3D
/Applications/Godot.app/Contents/MacOS/Godot --path . --resolution 2622x1206 \
  -- --screen=world --island=0 --capture=/tmp/shot.png --after=20
```

`--screen` is `title`, `world` or `map`; `--island` (or `--region`) 0-4; also
`--yaw`, `--pitch`, `--zoom`, `--rest` and `--fire=<region>`.

`--fire` sends the lantern at launch, which is the only sane way to look at the
eighty-second walk.
The whole round trip takes about four minutes, so `--after=230` catches them
coming home.

Two things learned the hard way this session and worth keeping:

**Run the sim with a position trace rather than reasoning about it.**
All three lantern bugs were found in one four-minute instrumented run and none
of them would have been found by reading the code.

**A mesh that renders as nothing at all is a winding problem.**
Not dark, not misshapen - absent.
Godot's front face is the one whose edge cross product points away from the
viewer.
This cost an hour and the search went through the vertices, the AABB, the
surface count, the material, visibility and render layers first.
