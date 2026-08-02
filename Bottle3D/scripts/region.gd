class_name Region
extends RefCounted

## Where the five places are, relative to each other.
##
## This is the whole of the one-world pivot in one file. The five biomes were
## five parallel saves that never touched, four of them frozen at any moment
## because you can only look at one at a time and there is no offline progress.
## They are now five regions of one place, laid out along an arc, and the only
## thing that had to be invented to do it was a table of positions.
##
## See `handoffs/DESIGN-one-world.md` for why, at length.
##
## ## The arc, and starting in the middle of it
##
## The Meadow is at the origin and everything else is measured from it, because
## the Meadow is where everybody starts: it is the even one, where nothing is
## scarce and nothing is free.
##
## The other four go out in both directions rather than in a line, so the first
## expansion is a choice about which way to go rather than a step down a
## corridor. East is warm and gets warmer - the Shore, then the Dunes. West is
## wet and gets colder - the Green, then the Ice.
##
## That ordering is not decoration, it is the supply chain. The Green pours out
## timber and fights you for stone; the Ice has almost no timber at all. Putting
## the Ice on the far side of the Green means the only sane way to settle it is
## to have the Green cutting lumber first and then carry it, which is exactly
## the interaction the five separate islands could never have.
##
## ## How far apart
##
## Thirty units between neighbours, against a region that is thirteen across.
## That leaves seventeen units of nothing between one shoreline and the next -
## more than an island's width of gap, which is what it takes for five places to
## read as five places rather than as one broken plate.
##
## Twenty was tried first and was wrong twice over. Five units of gap put the
## neighbours in the frame at close zoom as huge pale slabs jammed against the
## left and right edges, which is not a world with more in it, it is a diorama
## with clutter round it. And it was dishonest about distance: two shores five
## units apart are not somewhere you walk to, they are somewhere you step to.
##
## A hobbit walks a shade under half a unit a second, so a crossing is about
## seventy-five seconds. That is long, and it is meant to be - carrying a
## lantern to the next region happens once per region in the life of a world,
## and a journey you can sit through and watch is the entire point of it.
##
## ## Nothing is between them
##
## There is no sea and no isthmus. The regions sit in the same luminous haze one
## island always sat in, because the app has always drawn a floating diorama and
## five of them in an arc is the same picture, not a different one.
##
## Whether the world eventually wants water under it is a real open question and
## deliberately not answered here - a sea would change the look of the close-up
## view, which is tuned, and it should be decided on purpose rather than as a
## side effect of laying out a map.

## Everybody's first region, and the only one settled on a fresh install.
const HOME := 0

## Where each region's own origin sits in world space. Indices are `Biome`'s.
##
##   0 The Meadow  nearest, in the middle, and where you start
##   3 The Shore   east along the arc
##   2 The Dunes   east again, and the far end of it
##   4 The Green   west, close in
##   1 The Ice     west again, and the furthest thing from home
##
## The z values bow the chain rather than sloping it. A line of five places at
## evenly increasing depth draws a diagonal stripe across the frame with a
## corner of empty sky above it; a curve with the ends further off and the
## middle nearest fills the frame symmetrically, reads as a bay rather than a
## row, and puts home in the foreground where it belongs.
const ORIGINS: Array[Vector3] = [
	Vector3(0.0, 0.0, 11.0),
	Vector3(-56.0, 0.0, -12.0),
	Vector3(56.0, 0.0, -12.0),
	Vector3(29.0, 0.0, 5.0),
	Vector3(-29.0, 0.0, 5.0),
]

## Which regions are joined to which. Not every pair: the arc is a chain, and
## the Ice being four hops from the Dunes is the point of putting it there.
##
## This is a real thing in the world rather than a rule about one. Each of these
## pairs has a neck of land between it - see `Causeway` - because a lantern
## cannot be carried across open haze, and five plates floating apart is a
## picture of five islands, which is the thing this whole direction replaced.
const NEIGHBOURS := {
	0: [3, 4],
	3: [0, 2],
	2: [3],
	4: [0, 1],
	1: [4],
}

## The two distant ends of the world are paid gates.
## Buying one only makes the land available to a lantern.
## It never settles the region or manufactures any progress.
const PAID := [2, 1]


static func requires_purchase(index: int) -> bool:
	return PAID.has(index)


## Every join, once each rather than once from each end.
static func links() -> Array:
	var pairs: Array = []
	for a in NEIGHBOURS:
		for b in NEIGHBOURS[a]:
			if int(a) < int(b):
				pairs.append(Vector2i(int(a), int(b)))
	return pairs


static func origin(index: int) -> Vector3:
	return ORIGINS[clampi(index, 0, Biome.COUNT - 1)]


## Everything positioned relative to whichever region is being lived in.
##
## The active region always sits at the world origin and the other four are
## offset around it, rather than the camera travelling to fixed coordinates.
## That keeps every number inside `ElfWorld` small and local - an elf's feet, a
## line of sight, a heap - and means travelling to another region moves the
## scenery rather than the maths.
static func offset(index: int, from_active: int) -> Vector3:
	return origin(index) - origin(from_active)


static func distance(a: int, b: int) -> float:
	return origin(a).distance_to(origin(b))


## The middle of everything, offset for the active region. What the camera aims
## at once it has pulled back far enough to be looking at the world rather than
## at a place in it.
##
## The middle of the box the regions sit in, not the average of their positions.
## An average is pulled about by wherever the regions happen to be crowded, and
## the thing being framed here is the extent.
static func centre(from_active: int) -> Vector3:
	var lo := ORIGINS[0]
	var hi := ORIGINS[0]
	for p in ORIGINS:
		lo = Vector3(minf(lo.x, p.x), 0.0, minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), 0.0, maxf(hi.z, p.z))
	return (lo + hi) * 0.5 - origin(from_active)


## Half the width of everything there is to see, plus a shoreline at each end.
##
## The camera's furthest zoom is derived from this rather than typed in, so
## moving a region in the table above cannot silently leave a corner of the
## world off the edge of the frame. Width rather than depth because the arc is
## far wider than it is deep and the frame is landscape - the horizontal is what
## runs out first, and by a long way.
static func reach() -> float:
	var lo := ORIGINS[0].x
	var hi := ORIGINS[0].x
	for p in ORIGINS:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return (hi - lo) * 0.5 + Biome.LAND_X * 1.3
