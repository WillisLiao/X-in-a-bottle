class_name Plan
extends RefCounted

## What the elves are trying to do, and everything they need before they can.
##
## One three-storey house, on an island that only has room for one. It is not
## built by an animation reaching a hundred per cent: it is built in the order a
## house is actually built, out of materials that do not exist yet, using
## machines that do not exist yet either, and both of those have to be made
## first, from other materials, at workshops that also have to be made first.
##
## That regress is the product. A person opening this on the first day watches
## four elves knap stone and stack it. A person opening it on the seventh watches
## a treadwheel crane swing a glulam beam onto the third storey while somebody
## renders the chimney. Nothing in between is a cutscene.
##
## Everything is one type. A limekiln, a crane, a floor joist and a doorknob are
## all a Work: somewhere on the island, a bill of materials, and a piece of
## geometry that appears when the bill is met and the fitting labour is done.
## There is no second system for machines, which is why the machines can be part
## of the queue rather than a gate bolted across it.
##
## ## On the equipment list
##
## The brief named excavators, concrete pump trucks, boom cranes and dumpsters.
## Those are the right *functions* and they are all here, but a diesel bobcat on
## an island of thirty-centimetre elves reads as a toy dropped into the scene, so
## each one is built as the machine that does that job at their scale and in
## their century: a hand-cranked bucket dredge, a piston pump on a barrel, a
## treadwheel crane, a tipping cart. The construction sequence is real. The
## machinery is theirs.
##
## ## On the arithmetic
##
## The target is that one environment takes a week of real focus, not an evening.
##
## There are about five hundred works, averaging a little over three units of
## material each, so roughly seventeen hundred deliveries. Two thirds of those
## are made materials rather than dug ones, and a made unit is about seven acts
## once its inputs are gathered, hauled and crafted, against three for a raw one.
## That is somewhere near ten thousand acts, and an act - walk there, work, walk
## back - averages twenty-five seconds.
##
## Seventy hobbit-hours, then.
## Against the fixed travelling band of twelve, that is several hours of active
## work spread over the app-open week and its scheduled breaks.
## `EFFORT` is the one dial: it multiplies every bill of materials, so a week can
## become a fortnight or a weekend without touching anything else.

## Multiplies every material cost. See the arithmetic above.
const EFFORT := 1.0

## Stuff. Six things come out of the ground and ten are made from those.
##
## Sixteen is as far as this goes. Every kind needs a mesh you can tell apart in
## an elf's hands from three metres away, and past about this many they stop
## being things and start being inventory.
enum Kind {
	STONE, TIMBER, ORE, CLAY, SAND, FIBRE,
	LIME, IRON, LUMBER, PANEL, CONCRETE, GLASS, PIPE, WIRE, CLOTH, PLASTER,
}

const KIND_COUNT := 16

## Only ever shown in the environment picker, never over an elf's head.
const KIND_NAME := [
	"stone", "timber", "ore", "clay", "sand", "reed",
	"lime", "iron", "lumber", "board", "concrete", "glass",
	"pipe", "wire", "cloth", "plaster",
]

## What each thing looks like in a heap and in a pair of hands.
const KIND_COLOUR := [
	Color("867F76"), Color("6B4A32"), Color("4A4E58"), Color("9C6A4E"),
	Color("C4A878"), Color("A8894F"),
	Color("D8D2C4"), Color("6E7480"), Color("B08A5E"), Color("8E7350"),
	Color("9AA0A0"), Color("8FC6D8"), Color("5A6068"), Color("A2743E"),
	Color("C8B49A"), Color("E2DED2"),
]


## A recipe. Everything not on this list comes out of the ground.
##
## Every one of these takes at least two units in to make one out, which is where
## most of the week comes from. It is also just true: two stone burn down to one
## lime, and nobody has ever got a plank out of half a tree.
static func recipe(kind: int) -> Dictionary:
	match kind:
		Kind.LIME:     return {"in": {Kind.STONE: 2}, "seconds": 9.0}
		Kind.IRON:     return {"in": {Kind.ORE: 2, Kind.LIME: 1}, "seconds": 12.0}
		Kind.LUMBER:   return {"in": {Kind.TIMBER: 2}, "seconds": 8.0}
		Kind.PANEL:    return {"in": {Kind.LUMBER: 2, Kind.FIBRE: 1}, "seconds": 10.0}
		Kind.CONCRETE: return {"in": {Kind.LIME: 1, Kind.SAND: 1, Kind.STONE: 1},
			"seconds": 8.0}
		Kind.GLASS:    return {"in": {Kind.SAND: 2, Kind.LIME: 1}, "seconds": 13.0}
		Kind.PIPE:     return {"in": {Kind.IRON: 2}, "seconds": 11.0}
		Kind.WIRE:     return {"in": {Kind.IRON: 2}, "seconds": 10.0}
		Kind.CLOTH:    return {"in": {Kind.FIBRE: 2}, "seconds": 9.0}
		Kind.PLASTER:  return {"in": {Kind.LIME: 1, Kind.CLAY: 1}, "seconds": 9.0}
	return {}


static func is_made(kind: int) -> bool:
	return not recipe(kind).is_empty()


# --- the house ---------------------------------------------------------------
#
# Elves stand about forty-five centimetres. A storey they can walk about in is
# a little over half a metre, so three of them plus a footing and a roof comes to
# just over two metres - four and a half times the height of the people building
# it, which is what three storeys has always meant.

const HW := 0.72
const HD := 0.54
const STOREY := 0.52

## Top of the slab. Everything above is measured from the ground the house
## stands on, so the whole blueprint can be dropped onto a hillside unchanged.
const DECK0 := 0.10

const PLATE := DECK0 + STOREY * 3.0
const RIDGE := PLATE + 0.38
const EAVE := 0.11

const STUD := 0.032
const JOIST := 0.042


static func deck_y(level: int) -> float:
	return DECK0 + STOREY * float(level)


# --- putting the queue together ----------------------------------------------

static var _cache: Array = []


## The whole project, in the order it happens.
##
## Order is the entire tech tree. There is no dependency graph and no unlock
## table, because a building is not a graph - you cannot pour a footing before
## you have dug for it, and you cannot dig before somebody has built the thing
## that digs. Expressing that as a queue means it cannot deadlock and cannot be
## solved out of sequence, and it means the machines can simply be sitting in the
## line at the point where they first become necessary.
static func works() -> Array:
	if not _cache.is_empty():
		return _cache

	var w := []

	# Nothing yet exists, so the first two things they make are made out of what
	# is lying on the ground: a kiln of stacked stone, and a shed to cut in.
	_survey(w)
	_kiln(w)
	_sawmill(w)
	_smelter(w)

	_earthworks(w)
	_mixer(w)
	_footings(w)
	_slab(w)

	_press(w)
	_deck(w, 0)
	_storey(w, 0)

	_crane(w)
	_scaffold(w)
	_deck(w, 1)
	_storey(w, 1)

	_deck(w, 2)
	_storey(w, 2)

	_roof(w)

	# Three sides close up. The fourth - the one you are looking at - stays open,
	# so the whole of the interior fit-out is a dollhouse rather than a fortnight
	# of nothing visibly happening.
	_envelope(w, false)
	_glassworks(w)
	_openings(w, false)
	_cladding(w, false)

	_pipeworks(w)
	_drawbench(w)
	_services(w)

	_loom(w)
	_insulation(w)
	_plastermill(w)
	_lining(w)

	_stairs(w)
	_finishes(w)
	_fittings(w)
	_paint(w)

	# And then the front goes on, the windows go in, and the lights come on
	# behind them. This is the last hour of a week and it is the only part of the
	# build that is deliberately theatrical.
	_envelope(w, true)
	_openings(w, true)
	_cladding(w, true)
	_handover(w)

	for i in w.size():
		w[i]["index"] = i
		var cost: Dictionary = w[i]["cost"]
		for k in cost:
			cost[k] = maxi(1, int(round(float(cost[k]) * EFFORT)))

	_cache = w
	return w


static func count() -> int:
	return works().size()


## Which phase a given work belongs to, for the environment picker. The only
## number ever shown to the user is which of these is happening.
static func phase_of(index: int) -> String:
	var w := works()
	if index >= w.size():
		return "Finished"
	return w[index]["group"]


## How far through the whole project the last work of a named phase sits.
##
## The picker draws each island as a house at the stage that island's house is
## actually at, and it needs to know where framing tops out and where the
## cladding closes. Reading those off the queue rather than writing them down
## twice means adding a course of tiles cannot silently put the drawing and the
## build out of step.
static func fraction_after(group: String) -> float:
	var w := works()
	var last := -1
	for i in w.size():
		if str(w[i]["group"]) == group:
			last = i
	if last < 0:
		return 1.0
	return float(last + 1) / float(w.size())


# --- work builders -----------------------------------------------------------

static func _add(w: Array, id: String, group: String, place: String,
		cost: Dictionary, parts: Array, fit := 4.0) -> Dictionary:
	var work := {
		"id": id, "group": group, "place": place,
		"cost": cost, "parts": parts, "fit": fit,
	}
	w.append(work)
	return work


## A crafting station: a work like any other, which on completion starts turning
## one thing into another.
static func _station(w: Array, id: String, group: String, out: int,
		cost: Dictionary, parts: Array, motion := "swing", tool := "hammer") -> void:
	var work := _add(w, id, group, id, cost, parts, 9.0)
	var r := recipe(out)
	work["makes"] = {
		"out": out, "in": r["in"], "seconds": r["seconds"],
		"motion": motion, "tool": tool,
	}


static func _p(shape: String, pos: Vector3, size: Vector3, mat: String,
		rot := Vector3.ZERO) -> Dictionary:
	return {"shape": shape, "pos": pos, "size": size, "mat": mat, "rot": rot}


# --- laying it out -----------------------------------------------------------

## The four walls, as sections of equal width, so a storey going up reads as
## walls arriving rather than sticks appearing.
##
## `front` picks out only the elevation facing the camera, which is the one held
## back until the very end.
static func _wall_runs(front_only: bool) -> Array:
	var runs := []
	if not front_only:
		for i in 4:
			var x := lerpf(-HW, HW, (float(i) + 0.5) / 4.0)
			runs.append({"at": Vector3(x, 0, -HD), "along_x": true, "w": HW * 0.5})
		for i in 3:
			var z := lerpf(-HD, HD, (float(i) + 0.5) / 3.0)
			runs.append({"at": Vector3(-HW, 0, z), "along_x": false, "w": HD * 0.667})
			runs.append({"at": Vector3(HW, 0, z), "along_x": false, "w": HD * 0.667})
	else:
		for i in 4:
			var x := lerpf(-HW, HW, (float(i) + 0.5) / 4.0)
			runs.append({"at": Vector3(x, 0, HD), "along_x": true, "w": HW * 0.5})
	return runs


static func _survey(w: Array) -> void:
	var g := "Survey"

	# The chain and level first, because you cannot set out a building by eye and
	# they know it. One timber, one iron, and until it exists nothing else can
	# start - which is the whole shape of this project stated once, cheaply, in
	# the first minute somebody watches.
	_add(w, "level", g, "survey", {Kind.TIMBER: 2, Kind.IRON: 1}, [
		_p("log", Vector3(0, 0.16, 0), Vector3(0.012, 0.32, 0), "timber"),
		_p("log", Vector3(0.05, 0.30, 0), Vector3(0.010, 0.14, 0), "timber",
			Vector3(0, 0, 1.1)),
		_p("box", Vector3(0, 0.33, 0), Vector3(0.09, 0.03, 0.05), "iron"),
		_p("log", Vector3(-0.10, 0.02, 0.06), Vector3(0.055, 0.03, 0), "iron",
			Vector3(PI * 0.5, 0, 0)),
	], 8.0)

	# Cores taken along the line of the footing, then the plot set out in stakes
	# and string. Both are real steps and both are one timber each, so the first
	# ten minutes of a new environment is somebody actually doing something.
	for i in 4:
		_add(w, "core%d" % i, g, "site", {Kind.CLAY: 1}, [
			_p("log", Vector3(lerpf(-HW, HW, float(i) / 3.0) * 1.2, 0.05,
				HD * 1.3), Vector3(0.022, 0.10, 0), "clay"),
		], 5.0)

	var corner := [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]
	for i in 4:
		var c: Vector3 = corner[i] * Vector3(HW + 0.12, 0, HD + 0.12)
		_add(w, "stake%d" % i, g, "site", {Kind.TIMBER: 1}, [
			_p("log", c + Vector3(0, 0.09, 0), Vector3(0.010, 0.18, 0), "timber"),
			_p("box", c + Vector3(0, 0.17, 0), Vector3(0.045, 0.006, 0.045), "cloth"),
		], 4.0)

	_add(w, "plans", g, "site", {Kind.TIMBER: 2, Kind.CLOTH: 1}, [
		_p("box", Vector3(0, 0.20, HD + 0.34), Vector3(0.34, 0.014, 0.24), "lumber"),
		_p("box", Vector3(0, 0.212, HD + 0.34), Vector3(0.26, 0.004, 0.18), "cloth"),
		_p("log", Vector3(-0.14, 0.10, HD + 0.26), Vector3(0.010, 0.20, 0), "timber"),
		_p("log", Vector3(0.14, 0.10, HD + 0.26), Vector3(0.010, 0.20, 0), "timber"),
	], 7.0)


static func _kiln(w: Array) -> void:
	# Drystone, because there is nothing to bind it with yet. Every other
	# workshop on the island is downstream of this one heap of rocks.
	var parts := []
	for i in 9:
		var a := TAU * float(i) / 9.0
		parts.append(_p("stone", Vector3(cos(a) * 0.17, 0.06, sin(a) * 0.17),
			Vector3(0.075, 0.075, 0.075), "stone"))
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.3
		parts.append(_p("stone", Vector3(cos(a) * 0.14, 0.17, sin(a) * 0.14),
			Vector3(0.062, 0.062, 0.062), "stone"))
	parts.append(_p("cone", Vector3(0, 0.29, 0), Vector3(0.13, 0.16, 0), "stone"))
	parts.append(_p("box", Vector3(0, 0.06, 0.18), Vector3(0.10, 0.11, 0.06), "dark"))
	_station(w, "kiln", "Kilns", Kind.LIME,
		{Kind.STONE: 8, Kind.CLAY: 3}, parts, "sweep", "shovel")


static func _sawmill(w: Array) -> void:
	var parts := [
		_p("box", Vector3(0, 0.09, 0), Vector3(0.52, 0.05, 0.30), "lumber"),
		_p("log", Vector3(-0.22, 0.05, -0.12), Vector3(0.022, 0.10, 0), "timber"),
		_p("log", Vector3(0.22, 0.05, -0.12), Vector3(0.022, 0.10, 0), "timber"),
		_p("log", Vector3(-0.22, 0.05, 0.12), Vector3(0.022, 0.10, 0), "timber"),
		_p("log", Vector3(0.22, 0.05, 0.12), Vector3(0.022, 0.10, 0), "timber"),
		# The blade, and the frame it swings in.
		_p("box", Vector3(0, 0.20, 0), Vector3(0.30, 0.005, 0.02), "iron"),
		_p("log", Vector3(-0.16, 0.17, 0), Vector3(0.012, 0.20, 0), "timber"),
		_p("log", Vector3(0.16, 0.17, 0), Vector3(0.012, 0.20, 0), "timber"),
		_p("log", Vector3(0, 0.27, 0), Vector3(0.010, 0.34, 0), "timber",
			Vector3(0, 0, PI * 0.5)),
	]
	_station(w, "sawmill", "Kilns", Kind.LUMBER,
		{Kind.TIMBER: 6, Kind.STONE: 3}, parts, "sweep", "saw")


static func _smelter(w: Array) -> void:
	var parts := [
		_p("cone", Vector3(0, 0.20, 0), Vector3(0.19, 0.40, 0), "stone"),
		_p("log", Vector3(0, 0.44, 0), Vector3(0.055, 0.12, 0), "stone"),
		_p("box", Vector3(0, 0.06, 0.16), Vector3(0.11, 0.12, 0.07), "dark"),
		# Bellows, on a post, with the handle an elf works.
		_p("box", Vector3(-0.26, 0.16, 0), Vector3(0.20, 0.09, 0.13), "timber"),
		_p("log", Vector3(-0.26, 0.07, 0), Vector3(0.020, 0.14, 0), "timber"),
		_p("log", Vector3(-0.34, 0.24, 0), Vector3(0.011, 0.18, 0), "timber",
			Vector3(0, 0, 0.6)),
		_p("log", Vector3(-0.12, 0.18, 0), Vector3(0.014, 0.16, 0), "iron",
			Vector3(0, 0, PI * 0.5)),
	]
	_station(w, "smelter", "Kilns", Kind.IRON,
		{Kind.STONE: 10, Kind.CLAY: 4, Kind.LUMBER: 2}, parts, "press", "bellows")


static func _earthworks(w: Array) -> void:
	var g := "Earthworks"

	# The dredge. A bucket on a boom, cranked by hand, standing in for the
	# excavator - same job, same century as everything else on the island.
	_add(w, "dredge", g, "dredge", {Kind.IRON: 6, Kind.LUMBER: 5}, [
		_p("box", Vector3(0, 0.05, 0), Vector3(0.34, 0.09, 0.26), "lumber"),
		_p("log", Vector3(-0.13, 0.01, 0.14), Vector3(0.05, 0.30, 0), "timber",
			Vector3(PI * 0.5, 0, 0)),
		_p("log", Vector3(0.13, 0.01, 0.14), Vector3(0.05, 0.30, 0), "timber",
			Vector3(PI * 0.5, 0, 0)),
		_p("log", Vector3(0, 0.30, -0.02), Vector3(0.020, 0.46, 0), "timber",
			Vector3(-0.75, 0, 0)),
		_p("box", Vector3(0, 0.44, 0.24), Vector3(0.13, 0.10, 0.12), "iron"),
		_p("log", Vector3(0.19, 0.16, -0.04), Vector3(0.055, 0.03, 0), "iron",
			Vector3(0, 0, PI * 0.5)),
		_p("log", Vector3(0.25, 0.16, -0.04), Vector3(0.010, 0.09, 0), "timber"),
	], 12.0)

	# Barrows, which is how the spoil actually moves.
	for i in 2:
		_add(w, "barrow%d" % i, g, "site", {Kind.LUMBER: 2, Kind.IRON: 1}, [
			_p("box", Vector3(-0.55 + float(i) * 0.30, 0.11, HD + 0.50),
				Vector3(0.18, 0.10, 0.14), "lumber"),
			_p("log", Vector3(-0.55 + float(i) * 0.30, 0.05, HD + 0.42),
				Vector3(0.050, 0.025, 0), "iron", Vector3(0, 0, PI * 0.5)),
			_p("log", Vector3(-0.60 + float(i) * 0.30, 0.13, HD + 0.60),
				Vector3(0.008, 0.20, 0), "timber", Vector3(PI * 0.4, 0, 0)),
			_p("log", Vector3(-0.50 + float(i) * 0.30, 0.13, HD + 0.60),
				Vector3(0.008, 0.20, 0), "timber", Vector3(PI * 0.4, 0, 0)),
		], 6.0)

	# Shoring, all the way round the dig, which is the part of an excavation
	# anybody who has stood next to one remembers.
	for i in 8:
		var a := TAU * float(i) / 8.0
		var at := Vector3(cos(a) * (HW + 0.16), 0.0, sin(a) * (HD + 0.16))
		_add(w, "shore%d" % i, g, "site", {Kind.LUMBER: 2}, [
			_p("box", at + Vector3(0, -0.045, 0), Vector3(0.30, 0.13, 0.030),
				"lumber", Vector3(0, -a + PI * 0.5, 0)),
			_p("log", at + Vector3(0, 0.02, 0), Vector3(0.014, 0.16, 0), "timber"),
		], 5.0)


static func _mixer(w: Array) -> void:
	# Batching plant and pump in one work. A barrel that turns, a hopper, and a
	# piston on a beam that gets the mix up to where the pour is - which is what
	# the pump truck on the brief is for, at the scale of the people using it.
	var parts := [
		_p("log", Vector3(0, 0.22, 0), Vector3(0.15, 0.30, 0), "timber",
			Vector3(0, 0, PI * 0.5)),
		_p("log", Vector3(-0.20, 0.10, 0), Vector3(0.018, 0.24, 0), "timber",
			Vector3(0, 0, 0.4)),
		_p("log", Vector3(0.20, 0.10, 0), Vector3(0.018, 0.24, 0), "timber",
			Vector3(0, 0, -0.4)),
		_p("log", Vector3(0.20, 0.22, 0), Vector3(0.050, 0.030, 0), "iron",
			Vector3(0, 0, PI * 0.5)),
		_p("log", Vector3(0.26, 0.22, 0), Vector3(0.009, 0.10, 0), "timber"),
		_p("box", Vector3(-0.02, 0.40, 0), Vector3(0.20, 0.10, 0.18), "iron"),
		# The stand pipe, up the side of where the house will be.
		_p("log", Vector3(0.32, 0.34, 0), Vector3(0.022, 0.62, 0), "iron"),
		_p("log", Vector3(0.32, 0.64, 0.14), Vector3(0.020, 0.28, 0), "iron",
			Vector3(PI * 0.5, 0, 0)),
	]
	_station(w, "mixer", "Concrete", Kind.CONCRETE,
		{Kind.IRON: 5, Kind.LUMBER: 4, Kind.STONE: 4}, parts, "press", "bellows")


static func _footings(w: Array) -> void:
	var g := "Footings"

	# Twelve pads: a cage of drawn iron, then the pour on top of it. Two works
	# per pad, in that order, because that is the order and because a cage
	# standing in an empty trench for a while is one of the few sights on a site
	# that tells you exactly what is about to happen.
	var pads := []
	for i in 4:
		var x := lerpf(-HW, HW, float(i) / 3.0)
		pads.append(Vector3(x, 0, -HD))
		pads.append(Vector3(x, 0, HD))
	for i in 2:
		var z := lerpf(-HD, HD, (float(i) + 0.5) / 2.0)
		pads.append(Vector3(-HW, 0, z))
		pads.append(Vector3(HW, 0, z))

	for i in pads.size():
		var at: Vector3 = pads[i]
		var cage := []
		for j in 3:
			cage.append(_p("log", at + Vector3(-0.05 + float(j) * 0.05, 0.03, 0),
				Vector3(0.006, 0.16, 0), "iron", Vector3(PI * 0.5, 0, 0)))
			cage.append(_p("log", at + Vector3(0, 0.03, -0.05 + float(j) * 0.05),
				Vector3(0.006, 0.16, 0), "iron", Vector3(0, 0, PI * 0.5)))
		_add(w, "cage%d" % i, g, "site", {Kind.IRON: 2}, cage, 4.0)

		_add(w, "pad%d" % i, g, "site", {Kind.CONCRETE: 3, Kind.STONE: 1}, [
			_p("box", at + Vector3(0, 0.035, 0), Vector3(0.19, 0.07, 0.19),
				"concrete"),
		], 6.0)


static func _slab(w: Array) -> void:
	var g := "Slab"

	# Formwork, mesh, then the pour in bays. Ten works across the footprint, so
	# the ground floor arrives as a floor being laid rather than a rectangle
	# switching on.
	for i in 3:
		for j in 2:
			var x := lerpf(-HW, HW, (float(i) + 0.5) / 3.0)
			var z := lerpf(-HD, HD, (float(j) + 0.5) / 2.0)
			_add(w, "mesh%d_%d" % [i, j], g, "site", {Kind.IRON: 2}, [
				_p("box", Vector3(x, 0.045, z), Vector3(HW * 0.62, 0.004, HD * 0.90),
					"iron"),
			], 4.0)
			_add(w, "bay%d_%d" % [i, j], g, "site",
				{Kind.CONCRETE: 3, Kind.SAND: 1}, [
					_p("box", Vector3(x, 0.06, z),
						Vector3(HW * 0.66, 0.09, HD * 0.96), "concrete"),
				], 7.0)


static func _press(w: Array) -> void:
	var parts := [
		_p("box", Vector3(0, 0.08, 0), Vector3(0.36, 0.06, 0.30), "lumber"),
		_p("log", Vector3(-0.15, 0.24, -0.12), Vector3(0.016, 0.34, 0), "timber"),
		_p("log", Vector3(0.15, 0.24, -0.12), Vector3(0.016, 0.34, 0), "timber"),
		_p("box", Vector3(0, 0.30, 0), Vector3(0.34, 0.05, 0.26), "lumber"),
		_p("log", Vector3(0, 0.42, 0), Vector3(0.012, 0.20, 0), "iron"),
		_p("log", Vector3(0, 0.52, 0), Vector3(0.070, 0.022, 0), "timber",
			Vector3(0, 0, PI * 0.5)),
		_p("box", Vector3(0, 0.13, 0.02), Vector3(0.30, 0.014, 0.22), "lumber"),
	]
	_station(w, "press", "Boards", Kind.PANEL,
		{Kind.LUMBER: 5, Kind.IRON: 4}, parts, "press", "bellows")


static func _deck(w: Array, level: int) -> void:
	var g := "Floor %d" % (level + 1)
	var y := deck_y(level)

	# On the slab there is nothing to span, so the ground floor is boards on
	# sleepers. Above it, engineered joists: a web between two flanges, which at
	# this size is three thin boxes and reads exactly right.
	if level == 0:
		for i in 6:
			var x := lerpf(-HW, HW, (float(i) + 0.5) / 6.0)
			_add(w, "gfloor%d" % i, g, "site", {Kind.LUMBER: 2}, [
				_p("box", Vector3(x, y + 0.008, 0),
					Vector3(HW * 0.32, 0.016, HD * 1.9), "lumber"),
			], 4.0)
		return

	for i in 7:
		var z := lerpf(-HD * 0.88, HD * 0.88, float(i) / 6.0)
		_add(w, "joist%d_%d" % [level, i], g, "site", {Kind.LUMBER: 3}, [
			_p("box", Vector3(0, y - 0.010, z), Vector3(HW * 2.0, 0.010, 0.05),
				"lumber"),
			_p("box", Vector3(0, y - 0.030, z), Vector3(HW * 2.0, 0.030, 0.014),
				"lumber"),
			_p("box", Vector3(0, y - 0.050, z), Vector3(HW * 2.0, 0.010, 0.05),
				"lumber"),
		], 6.0)

	for i in 2:
		_add(w, "hanger%d_%d" % [level, i], g, "site", {Kind.IRON: 2}, [
			_p("box", Vector3(lerpf(-HW, HW, float(i)) * 0.97, y - 0.03, 0),
				Vector3(0.014, 0.06, HD * 1.9), "iron"),
		], 4.0)

	for i in 6:
		var x := lerpf(-HW, HW, (float(i) + 0.5) / 6.0)
		_add(w, "subfloor%d_%d" % [level, i], g, "site", {Kind.PANEL: 3}, [
			_p("box", Vector3(x, y + 0.006, 0),
				Vector3(HW * 0.32, 0.012, HD * 1.94), "panel"),
		], 5.0)


static func _storey(w: Array, level: int) -> void:
	var g := "Storey %d" % (level + 1)
	var base := deck_y(level)
	var top := base + STOREY

	for i in 4:
		var along_x: bool = i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(0, base + 0.02, side * HD) if along_x \
			else Vector3(side * HW, base + 0.02, 0)
		var size := Vector3(HW * 2.0, 0.035, 0.06) if along_x \
			else Vector3(0.06, 0.035, HD * 2.0)
		_add(w, "sole%d_%d" % [level, i], g, "site", {Kind.LUMBER: 2}, [
			_p("box", at, size, "lumber"),
		], 4.0)

	for i in 4:
		var sx := -1.0 if i < 2 else 1.0
		var sz := -1.0 if i % 2 == 0 else 1.0
		_add(w, "post%d_%d" % [level, i], g, "site", {Kind.LUMBER: 3}, [
			_p("box", Vector3(sx * HW, base + STOREY * 0.5, sz * HD),
				Vector3(0.055, STOREY, 0.055), "lumber"),
		], 5.0)

	# Iron columns down the middle, carrying what is above. Only the two lower
	# storeys need them, which is both true and a nice quiet detail: the top of
	# the house is visibly lighter than the bottom.
	if level < 2:
		for i in 2:
			_add(w, "column%d_%d" % [level, i], g, "site", {Kind.IRON: 4}, [
				_p("box", Vector3(lerpf(-0.32, 0.32, float(i)),
					base + STOREY * 0.5, 0), Vector3(0.026, STOREY, 0.026), "iron"),
				_p("box", Vector3(lerpf(-0.32, 0.32, float(i)),
					base + STOREY * 0.5, 0), Vector3(0.010, STOREY, 0.062), "iron"),
				_p("box", Vector3(lerpf(-0.32, 0.32, float(i)), top - 0.02, 0),
					Vector3(0.08, 0.02, 0.08), "iron"),
			], 6.0)

	var runs := _wall_runs(false) + _wall_runs(true)
	for i in runs.size():
		var run: Dictionary = runs[i]
		var at: Vector3 = run["at"]
		var along_x: bool = run["along_x"]
		var half: float = run["w"] * 0.5
		var parts := []
		for s in 3:
			var t := lerpf(-half, half, float(s) / 2.0) * 0.82
			var p := at + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t))
			parts.append(_p("box", p + Vector3(0, base + STOREY * 0.5, 0),
				Vector3(STUD, STOREY - 0.06, STUD), "lumber"))
		# Noggings, which is what stops a stud wall reading as a comb.
		var nog := Vector3(half * 1.5, 0.022, STUD) if along_x \
			else Vector3(STUD, 0.022, half * 1.5)
		parts.append(_p("box", at + Vector3(0, base + STOREY * 0.52, 0), nog,
			"lumber"))
		_add(w, "wall%d_%d" % [level, i], g, "site", {Kind.LUMBER: 3, Kind.IRON: 1},
			parts, 6.0)

	# Glulam over the openings. Laminated, so it is drawn as four thin boards
	# rather than one beam, and it costs what a laminated beam costs.
	for i in 2:
		var sz := -1.0 if i == 0 else 1.0
		var parts := []
		for lam in 4:
			parts.append(_p("box",
				Vector3(0, top - 0.055 + float(lam) * 0.013, sz * HD),
				Vector3(HW * 1.9, 0.012, 0.055), "glulam"))
		_add(w, "header%d_%d" % [level, i], g, "site", {Kind.LUMBER: 5}, parts, 8.0)

	for i in 4:
		var along_x: bool = i < 2
		var side := -1.0 if i % 2 == 0 else 1.0
		var at := Vector3(0, top - 0.018, side * HD) if along_x \
			else Vector3(side * HW, top - 0.018, 0)
		var size := Vector3(HW * 2.0, 0.036, 0.06) if along_x \
			else Vector3(0.06, 0.036, HD * 2.0)
		_add(w, "plate%d_%d" % [level, i], g, "site", {Kind.LUMBER: 2, Kind.IRON: 1}, [
			_p("box", at, size, "lumber"),
		], 5.0)


static func _crane(w: Array) -> void:
	# A treadwheel crane. Two elves walk inside the drum and the jib lifts: it is
	# the machine that made cathedrals, it is exactly the boom truck on the
	# brief, and it is the single best-looking thing on the island - which is
	# why it earns a real jib, a back-stay holding it up rather than a stick
	# implying one, and a counterweight explaining why the whole thing does
	# not tip into the pit the moment something heavy goes on the hook.
	var parts := [
		_p("box", Vector3(0, 0.06, 0), Vector3(0.30, 0.10, 0.30), "lumber"),
		_p("log", Vector3(0, 0.44, 0), Vector3(0.030, 0.76, 0), "timber"),
		_p("log", Vector3(0.30, 0.86, 0), Vector3(0.022, 0.72, 0), "timber",
			Vector3(0, 0, -1.05)),
		_p("log", Vector3(-0.16, 0.62, 0), Vector3(0.014, 0.44, 0), "timber",
			Vector3(0, 0, 0.6)),

		# The counterweight. Nothing else on the island explains itself just
		# by sitting there the way a slab of iron hung off the short end of a
		# lever does.
		_p("box", Vector3(-0.24, 0.16, 0), Vector3(0.11, 0.11, 0.16), "iron"),
		_p("log", Vector3(-0.24, 0.24, 0), Vector3(0.010, 0.10, 0), "iron"),
	]
	for i in 10:
		var a := TAU * float(i) / 10.0
		parts.append(_p("log", Vector3(cos(a) * 0.15, 0.30 + sin(a) * 0.15, 0),
			Vector3(0.008, 0.20, 0), "timber", Vector3(PI * 0.5, 0, 0)))
		parts.append(_p("box", Vector3(cos(a) * 0.15, 0.30 + sin(a) * 0.15, 0),
			Vector3(0.10, 0.010, 0.20), "lumber", Vector3(0, 0, -a)))

	# The jib itself, out from the top of the mast to the hook - thicker and
	# longer than the strut it used to be, because a crane's whole silhouette
	# is this one line.
	parts.append(_p("log", Vector3(0.20, 0.98, 0), Vector3(0.026, 0.80, 0),
		"timber", Vector3(0, 0, -1.00)))

	# A back-stay from the jib's tip to the foot of the mast, doing visibly
	# what the strut used to do only by implication: hold the beam up against
	# the load on the hook.
	parts.append(_p("log", Vector3(0.28, 0.66, 0), Vector3(0.006, 0.92, 0),
		"wire", Vector3(0, 0, 0.62)))

	# The hook, hanging on its own line rather than bolted straight to the
	# jib, so a load going up reads as something suspended and not something
	# stuck to the end of a stick.
	parts.append(_p("log", Vector3(0.55, 1.05, 0), Vector3(0.005, 0.20, 0), "iron"))
	parts.append(_p("box", Vector3(0.55, 0.93, 0), Vector3(0.05, 0.05, 0.05), "iron"))
	_add(w, "crane", "Crane", "crane",
		{Kind.LUMBER: 10, Kind.IRON: 7, Kind.CLOTH: 2}, parts, 18.0)


static func _scaffold(w: Array) -> void:
	var g := "Crane"

	# Standards, ledgers and boards, up all three storeys, plus the harnesses.
	# Real scaffold arrives in lifts and so does this, which is another thing the
	# viewer sees happen before the thing it enables.
	for lift in 3:
		var y := deck_y(lift)
		var parts := []
		for i in 4:
			var sx := -1.0 if i < 2 else 1.0
			var sz := -1.0 if i % 2 == 0 else 1.0
			parts.append(_p("log", Vector3(sx * (HW + 0.18), y + STOREY * 0.5,
				sz * (HD + 0.18)), Vector3(0.013, STOREY, 0), "timber"))
		for sz in [-1.0, 1.0]:
			parts.append(_p("log", Vector3(0, y + STOREY - 0.06,
				sz * (HD + 0.18)), Vector3(0.010, (HW + 0.18) * 2.0, 0), "timber",
				Vector3(0, 0, PI * 0.5)))
			parts.append(_p("box", Vector3(0, y + STOREY - 0.04,
				sz * (HD + 0.18)), Vector3((HW + 0.18) * 2.0, 0.012, 0.14),
				"lumber"))
		_add(w, "scaffold%d" % lift, g, "site", {Kind.LUMBER: 4, Kind.IRON: 1},
			parts, 8.0)

	_add(w, "harness", g, "site", {Kind.CLOTH: 3, Kind.IRON: 2}, [
		_p("box", Vector3(HW + 0.30, 0.30, HD * 0.2), Vector3(0.10, 0.02, 0.08),
			"cloth"),
		_p("log", Vector3(HW + 0.30, 0.16, HD * 0.2), Vector3(0.010, 0.28, 0),
			"timber"),
		_p("log", Vector3(HW + 0.30, 0.34, HD * 0.2), Vector3(0.035, 0.02, 0),
			"iron", Vector3(PI * 0.5, 0, 0)),
	], 6.0)


static func _roof(w: Array) -> void:
	var g := "Roof"
	var run := HD + EAVE
	var rise := RIDGE - PLATE
	var pitch := atan2(rise, run)
	var slope := sqrt(run * run + rise * rise)

	_add(w, "ridge", g, "site", {Kind.LUMBER: 6, Kind.IRON: 1}, [
		_p("box", Vector3(0, RIDGE - 0.03, 0), Vector3(HW * 2.1, 0.055, 0.05),
			"glulam"),
	], 10.0)

	for i in 5:
		var x := lerpf(-HW, HW, float(i) / 4.0) * 0.97
		var parts := []
		for sz in [-1.0, 1.0]:
			parts.append(_p("box",
				Vector3(x, (PLATE + RIDGE) * 0.5, sz * run * 0.5),
				Vector3(0.032, 0.045, slope), "lumber",
				Vector3(sz * pitch, 0, 0)))
		_add(w, "rafter%d" % i, g, "site", {Kind.LUMBER: 3}, parts, 6.0)

	for i in 3:
		var x := lerpf(-HW, HW, (float(i) + 0.5) / 3.0) * 0.9
		_add(w, "collar%d" % i, g, "site", {Kind.LUMBER: 2}, [
			_p("box", Vector3(x, PLATE + rise * 0.45, 0),
				Vector3(0.028, 0.028, run * 1.1), "lumber"),
		], 4.0)

	for i in 4:
		for sz in [-1.0, 1.0]:
			var x := lerpf(-HW, HW, (float(i) + 0.5) / 4.0)
			_add(w, "rsheath%d_%s" % [i, "n" if sz < 0 else "p"], g, "site",
				{Kind.PANEL: 3}, [
					_p("box", Vector3(x, (PLATE + RIDGE) * 0.5 + 0.03,
						sz * run * 0.5), Vector3(HW * 0.5, 0.012, slope), "panel",
						Vector3(sz * pitch, 0, 0)),
				], 5.0)

	for i in 2:
		for sz in [-1.0, 1.0]:
			var x := lerpf(-HW, HW, (float(i) + 0.5) / 2.0)
			_add(w, "felt%d_%s" % [i, "n" if sz < 0 else "p"], g, "site",
				{Kind.CLOTH: 2}, [
					_p("box", Vector3(x, (PLATE + RIDGE) * 0.5 + 0.042,
						sz * run * 0.5), Vector3(HW * 1.02, 0.005, slope),
						"felt", Vector3(sz * pitch, 0, 0)),
				], 4.0)

	# Tiles, laid in courses from the eaves up. Twenty works, and this is the
	# stretch where the house stops being a frame and becomes a building.
	for course in 5:
		for i in 2:
			for sz in [-1.0, 1.0]:
				var x := lerpf(-HW, HW, (float(i) + 0.5) / 2.0)
				var t := (float(course) + 0.5) / 5.0
				var parts := []
				for c in 3:
					var xx := x + lerpf(-HW * 0.5, HW * 0.5, (float(c) + 0.5) / 3.0)
					parts.append(_p("box",
						Vector3(xx, lerpf(PLATE, RIDGE, t) + 0.05,
							sz * lerpf(run, 0.02, t) * 0.5),
						Vector3(HW * 0.32, 0.014, slope / 5.0 * 1.15), "tile",
						Vector3(sz * pitch, 0, 0)))
				_add(w, "tile%d_%d_%s" % [course, i, "n" if sz < 0 else "p"], g,
					"site", {Kind.CLAY: 2, Kind.LIME: 1}, parts, 5.0)


static func _envelope(w: Array, front: bool) -> void:
	var g := "Front" if front else "Envelope"
	var runs := _wall_runs(front)

	for i in runs.size():
		var run: Dictionary = runs[i]
		var at: Vector3 = run["at"]
		var along_x: bool = run["along_x"]
		var wide: float = run["w"]
		for level in 3:
			var y := deck_y(level) + STOREY * 0.5
			var size := Vector3(wide, STOREY, 0.012) if along_x \
				else Vector3(0.012, STOREY, wide)
			var out := 0.026 if along_x else 0.026
			var push := Vector3(0, 0, signf(at.z) * out) if along_x \
				else Vector3(signf(at.x) * out, 0, 0)
			_add(w, "sheath%s%d_%d" % ["f" if front else "", i, level], g, "site",
				{Kind.PANEL: 3, Kind.IRON: 1}, [
					_p("box", at + Vector3(0, y, 0) + push, size, "panel"),
				], 5.0)

	# Wrap and flashing, one work per elevation per pair of storeys. It is a
	# thin, dull, entirely correct step and skipping it would be the first place
	# the sequence stopped being real.
	var wraps := 2 if front else 5
	for i in wraps:
		_add(w, "wrap%s%d" % ["f" if front else "", i], g, "site",
			{Kind.CLOTH: 3}, [
				_p("box", Vector3(lerpf(-HW, HW, (float(i) + 0.5) / float(wraps)),
					deck_y(0) + STOREY * 1.5,
					(HD + 0.04) * (1.0 if front else -1.0)),
					Vector3(HW * 2.0 / float(wraps), STOREY * 3.0, 0.004), "felt"),
			], 4.0)


static func _glassworks(w: Array) -> void:
	var parts := [
		_p("cone", Vector3(0, 0.16, 0), Vector3(0.17, 0.32, 0), "stone"),
		_p("box", Vector3(0, 0.05, 0.15), Vector3(0.10, 0.10, 0.06), "dark"),
		_p("box", Vector3(-0.28, 0.10, 0), Vector3(0.30, 0.05, 0.20), "lumber"),
		_p("log", Vector3(-0.28, 0.04, 0), Vector3(0.020, 0.08, 0), "timber"),
		_p("log", Vector3(-0.12, 0.20, 0), Vector3(0.006, 0.26, 0), "iron",
			Vector3(0, 0, PI * 0.42)),
		_p("box", Vector3(-0.34, 0.15, 0), Vector3(0.09, 0.06, 0.09), "glass"),
	]
	_station(w, "glassworks", "Glass", Kind.GLASS,
		{Kind.STONE: 8, Kind.IRON: 4, Kind.CLAY: 3}, parts, "sweep", "shovel")


static func _openings(w: Array, front: bool) -> void:
	var g := "Front" if front else "Envelope"

	# Windows: a frame, a mullion, and glass. On the three closed sides they go
	# in with the envelope; on the front they are the second-to-last thing that
	# happens, and they are what the lights inside shine through.
	var places := []
	if front:
		for level in 3:
			for i in 2:
				places.append({"pos": Vector3(lerpf(-HW, HW, (float(i) + 0.5) / 2.0),
					deck_y(level) + STOREY * 0.55, HD + 0.03), "along_x": true})
	else:
		for level in 3:
			places.append({"pos": Vector3(0, deck_y(level) + STOREY * 0.55, -HD - 0.03),
				"along_x": true})
			for sx in [-1.0, 1.0]:
				places.append({"pos": Vector3(sx * (HW + 0.03),
					deck_y(level) + STOREY * 0.55, 0), "along_x": false})

	for i in places.size():
		var at: Vector3 = places[i]["pos"]
		var along_x: bool = places[i]["along_x"]
		var frame := Vector3(0.24, 0.26, 0.03) if along_x else Vector3(0.03, 0.26, 0.24)
		var pane := Vector3(0.20, 0.22, 0.012) if along_x else Vector3(0.012, 0.22, 0.20)
		var bar := Vector3(0.012, 0.24, 0.022) if along_x else Vector3(0.022, 0.24, 0.012)
		_add(w, "window%s%d" % ["f" if front else "", i], g, "site",
			{Kind.GLASS: 3, Kind.LUMBER: 1}, [
				_p("box", at, frame, "lumber"),
				_p("box", at, pane, "glass"),
				_p("box", at, bar, "lumber"),
			], 6.0)

	if front:
		_add(w, "door", g, "site", {Kind.LUMBER: 3, Kind.IRON: 2}, [
			_p("box", Vector3(0, deck_y(0) + 0.16, HD + 0.035),
				Vector3(0.20, 0.32, 0.022), "lumber"),
			_p("box", Vector3(0, deck_y(0) + 0.16, HD + 0.030),
				Vector3(0.23, 0.35, 0.014), "glulam"),
			_p("log", Vector3(0.07, deck_y(0) + 0.16, HD + 0.050),
				Vector3(0.012, 0.03, 0), "iron", Vector3(PI * 0.5, 0, 0)),
		], 8.0)

		# A porch, because a front door in a blank wall reads as a hatch.
		_add(w, "porch", g, "site", {Kind.LUMBER: 3, Kind.PANEL: 1}, [
			_p("box", Vector3(0, deck_y(0) - 0.02, HD + 0.16),
				Vector3(0.36, 0.030, 0.22), "lumber"),
			_p("log", Vector3(-0.15, deck_y(0) + 0.16, HD + 0.24),
				Vector3(0.016, 0.34, 0), "lumber"),
			_p("log", Vector3(0.15, deck_y(0) + 0.16, HD + 0.24),
				Vector3(0.016, 0.34, 0), "lumber"),
			_p("box", Vector3(0, deck_y(0) + 0.34, HD + 0.20),
				Vector3(0.40, 0.020, 0.26), "panel"),
		], 8.0)


static func _cladding(w: Array, front: bool) -> void:
	var g := "Front" if front else "Cladding"
	var runs := _wall_runs(front)

	for i in runs.size():
		var run: Dictionary = runs[i]
		var at: Vector3 = run["at"]
		var along_x: bool = run["along_x"]
		var wide: float = run["w"]
		for level in 3:
			var y := deck_y(level) + STOREY * 0.5
			var out := 0.040
			var push := Vector3(0, 0, signf(at.z) * out) if along_x \
				else Vector3(signf(at.x) * out, 0, 0)
			# Stone to the ground floor, boarded above. That is how a house of
			# this kind is actually built and it also gives the silhouette a base.
			var parts := []
			if level == 0:
				for c in 5:
					var t := (float(c) + 0.5) / 5.0
					var off := Vector3(lerpf(-wide, wide, t) * 0.42, 0, 0) if along_x \
						else Vector3(0, 0, lerpf(-wide, wide, t) * 0.42)
					parts.append(_p("stone", at + Vector3(0, y, 0) + push + off
						+ Vector3(0, sin(float(c) * 2.1) * 0.09, 0),
						Vector3(0.09, 0.07, 0.09), "stone"))
			else:
				for c in 4:
					var yy := y + lerpf(-STOREY, STOREY, (float(c) + 0.5) / 4.0) * 0.42
					var size := Vector3(wide, 0.048, 0.014) if along_x \
						else Vector3(0.014, 0.048, wide)
					parts.append(_p("box", at + Vector3(0, yy, 0) + push, size,
						"siding"))
			_add(w, "clad%s%d_%d" % ["f" if front else "", i, level], g, "site",
				{Kind.STONE: 3} if level == 0 else {Kind.LUMBER: 2, Kind.IRON: 1},
				parts, 5.0)

	if not front:
		for i in 6:
			var y := 0.10 + float(i) * 0.30
			_add(w, "chimney%d" % i, g, "site", {Kind.STONE: 3, Kind.LIME: 1}, [
				_p("stone", Vector3(-HW * 0.55, y, -HD - 0.10),
					Vector3(0.13, 0.16, 0.11), "stone"),
			], 6.0)


static func _pipeworks(w: Array) -> void:
	var parts := [
		_p("box", Vector3(0, 0.10, 0), Vector3(0.34, 0.07, 0.24), "lumber"),
		_p("log", Vector3(0, 0.24, 0), Vector3(0.028, 0.30, 0), "iron",
			Vector3(0, 0, PI * 0.5)),
		_p("log", Vector3(-0.22, 0.16, 0), Vector3(0.014, 0.12, 0), "iron"),
		_p("log", Vector3(0.22, 0.16, 0), Vector3(0.014, 0.12, 0), "iron"),
		_p("log", Vector3(0.24, 0.24, 0), Vector3(0.045, 0.025, 0), "timber",
			Vector3(0, 0, PI * 0.5)),
	]
	_station(w, "pipeworks", "Services", Kind.PIPE,
		{Kind.IRON: 6, Kind.LUMBER: 4}, parts, "swing", "hammer")


static func _drawbench(w: Array) -> void:
	var parts := [
		_p("box", Vector3(0, 0.11, 0), Vector3(0.46, 0.05, 0.16), "lumber"),
		_p("log", Vector3(-0.20, 0.05, 0), Vector3(0.018, 0.11, 0), "timber"),
		_p("log", Vector3(0.20, 0.05, 0), Vector3(0.018, 0.11, 0), "timber"),
		_p("box", Vector3(-0.20, 0.17, 0), Vector3(0.06, 0.07, 0.10), "iron"),
		_p("log", Vector3(0.14, 0.16, 0), Vector3(0.055, 0.03, 0), "iron",
			Vector3(PI * 0.5, 0, 0)),
		_p("log", Vector3(0.02, 0.16, 0), Vector3(0.004, 0.34, 0), "wire",
			Vector3(0, 0, PI * 0.5)),
	]
	_station(w, "drawbench", "Services", Kind.WIRE,
		{Kind.IRON: 5, Kind.LUMBER: 4}, parts, "sweep", "saw")


static func _services(w: Array) -> void:
	var g := "Services"

	# Everything that has to be in the wall before the wall closes. This is the
	# stretch the open front elevation exists for: for twenty minutes you are
	# looking straight into a house with its guts showing.
	for i in 4:
		var x := lerpf(-HW, HW, (float(i) + 0.5) / 4.0) * 0.8
		_add(w, "stack%d" % i, g, "site", {Kind.PIPE: 3}, [
			_p("log", Vector3(x, deck_y(0) + STOREY * 1.5, -HD * 0.7),
				Vector3(0.016, STOREY * 3.0, 0), "pipe"),
		], 6.0)

	for level in 3:
		_add(w, "branch%d" % level, g, "site", {Kind.PIPE: 2}, [
			_p("log", Vector3(0, deck_y(level) + 0.08, -HD * 0.7),
				Vector3(0.011, HW * 1.6, 0), "pipe", Vector3(0, 0, PI * 0.5)),
		], 5.0)

	_add(w, "vent", g, "site", {Kind.PIPE: 2, Kind.IRON: 1}, [
		_p("log", Vector3(HW * 0.4, PLATE + 0.24, -HD * 0.3),
			Vector3(0.014, 0.44, 0), "pipe"),
	], 5.0)

	_add(w, "panelboard", g, "site", {Kind.WIRE: 3, Kind.IRON: 2}, [
		_p("box", Vector3(-HW * 0.85, deck_y(0) + 0.24, -HD * 0.8),
			Vector3(0.10, 0.14, 0.05), "iron"),
		_p("box", Vector3(-HW * 0.85, deck_y(0) + 0.24, -HD * 0.8 + 0.03),
			Vector3(0.07, 0.10, 0.01), "dark"),
	], 8.0)

	for level in 3:
		for i in 2:
			_add(w, "circuit%d_%d" % [level, i], g, "site", {Kind.WIRE: 3}, [
				_p("log", Vector3(0, deck_y(level) + 0.16 + float(i) * 0.20,
					-HD * 0.82), Vector3(0.005, HW * 1.8, 0), "wire",
					Vector3(0, 0, PI * 0.5)),
				_p("log", Vector3(lerpf(-HW, HW, float(i)) * 0.7,
					deck_y(level) + 0.26, -HD * 0.82), Vector3(0.005, 0.22, 0),
					"wire"),
			], 5.0)

	# Ducting and the stove that feeds it, which is what this island's HVAC is.
	_add(w, "stove", g, "site", {Kind.IRON: 4, Kind.STONE: 2}, [
		_p("box", Vector3(-HW * 0.55, deck_y(0) + 0.11, -HD * 0.55),
			Vector3(0.16, 0.22, 0.14), "iron"),
		_p("log", Vector3(-HW * 0.55, deck_y(0) + 0.30, -HD * 0.55),
			Vector3(0.026, 0.18, 0), "iron"),
	], 8.0)

	for level in 3:
		_add(w, "duct%d" % level, g, "site", {Kind.IRON: 3}, [
			_p("box", Vector3(-HW * 0.2, deck_y(level) + 0.06, -HD * 0.4),
				Vector3(HW * 1.2, 0.05, 0.05), "iron"),
			_p("box", Vector3(-HW * 0.55, deck_y(level) + 0.24, -HD * 0.55),
				Vector3(0.06, 0.42, 0.06), "iron"),
		], 6.0)


static func _loom(w: Array) -> void:
	var parts := [
		_p("box", Vector3(-0.16, 0.18, 0), Vector3(0.03, 0.36, 0.03), "lumber"),
		_p("box", Vector3(0.16, 0.18, 0), Vector3(0.03, 0.36, 0.03), "lumber"),
		_p("log", Vector3(0, 0.34, 0), Vector3(0.014, 0.34, 0), "timber",
			Vector3(0, 0, PI * 0.5)),
		_p("log", Vector3(0, 0.06, 0), Vector3(0.014, 0.34, 0), "timber",
			Vector3(0, 0, PI * 0.5)),
		_p("box", Vector3(0, 0.20, 0), Vector3(0.26, 0.24, 0.006), "cloth"),
		_p("box", Vector3(0, 0.09, 0.06), Vector3(0.20, 0.03, 0.10), "lumber"),
	]
	_station(w, "loom", "Insulation", Kind.CLOTH,
		{Kind.LUMBER: 5, Kind.IRON: 2}, parts, "sweep", "saw")


static func _insulation(w: Array) -> void:
	var g := "Insulation"
	var runs := _wall_runs(false)
	for i in runs.size():
		var run: Dictionary = runs[i]
		var at: Vector3 = run["at"]
		var along_x: bool = run["along_x"]
		var wide: float = run["w"]
		for level in 3:
			if (i + level) % 2 == 1:
				continue
			var y := deck_y(level) + STOREY * 0.5
			var size := Vector3(wide * 0.94, STOREY - 0.08, 0.026) if along_x \
				else Vector3(0.026, STOREY - 0.08, wide * 0.94)
			_add(w, "batt%d_%d" % [i, level], g, "site", {Kind.CLOTH: 3}, [
				_p("box", at + Vector3(0, y, 0), size, "batt"),
			], 4.0)
	for i in 4:
		_add(w, "loft%d" % i, g, "site", {Kind.CLOTH: 2}, [
			_p("box", Vector3(lerpf(-HW, HW, (float(i) + 0.5) / 4.0), PLATE + 0.03, 0),
				Vector3(HW * 0.46, 0.05, HD * 1.8), "batt"),
		], 4.0)


static func _plastermill(w: Array) -> void:
	var parts := [
		_p("log", Vector3(0, 0.14, 0), Vector3(0.20, 0.10, 0), "stone",
			Vector3(0, 0, PI * 0.5)),
		_p("log", Vector3(0, 0.26, 0), Vector3(0.16, 0.06, 0), "stone",
			Vector3(0, 0, PI * 0.5)),
		_p("log", Vector3(0, 0.34, 0), Vector3(0.010, 0.22, 0), "timber"),
		_p("log", Vector3(0.13, 0.42, 0), Vector3(0.008, 0.28, 0), "timber",
			Vector3(0, 0, PI * 0.5)),
		_p("box", Vector3(0, 0.04, 0), Vector3(0.36, 0.05, 0.36), "lumber"),
	]
	_station(w, "plastermill", "Lining", Kind.PLASTER,
		{Kind.STONE: 6, Kind.IRON: 4, Kind.LUMBER: 3}, parts, "swing", "hammer")


static func _lining(w: Array) -> void:
	var g := "Lining"
	var runs := _wall_runs(false)
	for i in runs.size():
		var run: Dictionary = runs[i]
		var at: Vector3 = run["at"]
		var along_x: bool = run["along_x"]
		var wide: float = run["w"]
		for level in 3:
			var y := deck_y(level) + STOREY * 0.5
			var inward := 0.020
			var push := Vector3(0, 0, -signf(at.z) * inward) if along_x \
				else Vector3(-signf(at.x) * inward, 0, 0)
			var size := Vector3(wide, STOREY - 0.05, 0.010) if along_x \
				else Vector3(0.010, STOREY - 0.05, wide)
			_add(w, "board%d_%d" % [i, level], g, "site",
				{Kind.PLASTER: 3, Kind.IRON: 1}, [
					_p("box", at + Vector3(0, y, 0) + push, size, "plaster"),
				], 5.0)
	for level in 3:
		_add(w, "ceiling%d" % level, g, "site", {Kind.PLASTER: 3}, [
			_p("box", Vector3(0, deck_y(level) + STOREY - 0.05, 0),
				Vector3(HW * 1.9, 0.010, HD * 1.9), "plaster"),
		], 5.0)


static func _stairs(w: Array) -> void:
	var g := "Stairs"

	# Two flights, up the left-hand side, with a landing and a balustrade. This
	# is the work that makes three storeys read as three storeys rather than as
	# one house drawn taller: until there are stairs, there is no reason to
	# believe anybody could get up there.
	for flight in 2:
		var base := deck_y(flight)
		var top := deck_y(flight + 1)
		var sz := -1.0 if flight == 0 else 1.0

		for side in [-1.0, 1.0]:
			_add(w, "stringer%d_%s" % [flight, "n" if side < 0 else "p"], g, "site",
				{Kind.LUMBER: 3}, [
					_p("box", Vector3(-HW * 0.55 + side * 0.10,
						(base + top) * 0.5, sz * HD * 0.35),
						Vector3(0.024, 0.05, STOREY * 1.55), "lumber",
						Vector3(-sz * 0.62, 0, 0)),
				], 5.0)

		for step in 6:
			var t := (float(step) + 0.5) / 6.0
			_add(w, "tread%d_%d" % [flight, step], g, "site", {Kind.LUMBER: 1}, [
				_p("box", Vector3(-HW * 0.55, lerpf(base + 0.04, top, t),
					sz * lerpf(HD * 0.68, HD * 0.02, t)),
					Vector3(0.22, 0.014, 0.075), "lumber"),
			], 3.0)

		for i in 3:
			var t := (float(i) + 0.5) / 3.0
			_add(w, "baluster%d_%d" % [flight, i], g, "site",
				{Kind.IRON: 1, Kind.LUMBER: 1}, [
					_p("log", Vector3(-HW * 0.55 + 0.11,
						lerpf(base + 0.14, top + 0.10, t),
						sz * lerpf(HD * 0.68, HD * 0.02, t)),
						Vector3(0.006, 0.20, 0), "iron"),
				], 3.0)

		_add(w, "rail%d" % flight, g, "site", {Kind.LUMBER: 2}, [
			_p("box", Vector3(-HW * 0.55 + 0.11, (base + top) * 0.5 + 0.22,
				sz * HD * 0.35), Vector3(0.026, 0.020, STOREY * 1.55), "lumber",
				Vector3(-sz * 0.62, 0, 0)),
		], 4.0)

	_add(w, "landing", g, "site", {Kind.LUMBER: 2, Kind.PANEL: 1}, [
		_p("box", Vector3(-HW * 0.55, deck_y(1) + 0.01, 0),
			Vector3(0.26, 0.016, 0.20), "lumber"),
	], 4.0)


static func _finishes(w: Array) -> void:
	var g := "Finishes"

	for level in 3:
		for i in 4:
			_add(w, "floor%d_%d" % [level, i], g, "site", {Kind.LUMBER: 2}, [
				_p("box", Vector3(lerpf(-HW, HW, (float(i) + 0.5) / 4.0),
					deck_y(level) + 0.020, 0),
					Vector3(HW * 0.48, 0.008, HD * 1.86), "floorboard"),
			], 4.0)

	for level in 3:
		_add(w, "indoor%d" % level, g, "site", {Kind.LUMBER: 2}, [
			_p("box", Vector3(HW * 0.35, deck_y(level) + 0.16, -HD * 0.1),
				Vector3(0.020, 0.32, 0.19), "lumber"),
		], 4.0)
		_add(w, "trim%d" % level, g, "site", {Kind.LUMBER: 2}, [
			_p("box", Vector3(0, deck_y(level) + 0.028, -HD + 0.03),
				Vector3(HW * 1.9, 0.030, 0.012), "lumber"),
			_p("box", Vector3(-HW + 0.03, deck_y(level) + 0.028, 0),
				Vector3(0.012, 0.030, HD * 1.9), "lumber"),
		], 4.0)

	for i in 3:
		_add(w, "cabinet%d" % i, g, "site", {Kind.LUMBER: 3, Kind.PANEL: 1}, [
			_p("box", Vector3(lerpf(-HW * 0.7, HW * 0.7, (float(i) + 0.5) / 3.0),
				deck_y(0) + 0.10, -HD * 0.78), Vector3(0.26, 0.17, 0.11),
				"cabinet"),
		], 5.0)

	_add(w, "counter", g, "site", {Kind.STONE: 4, Kind.LIME: 1}, [
		_p("box", Vector3(0, deck_y(0) + 0.195, -HD * 0.78),
			Vector3(HW * 1.5, 0.018, 0.13), "counter"),
	], 6.0)

	for i in 2:
		_add(w, "wardrobe%d" % i, g, "site", {Kind.LUMBER: 3}, [
			_p("box", Vector3(HW * 0.55, deck_y(i + 1) + 0.15, -HD * 0.7),
				Vector3(0.20, 0.30, 0.12), "cabinet"),
		], 5.0)


static func _fittings(w: Array) -> void:
	var g := "Fittings"

	# The lights, which are the only pieces on the island that emit. Every one
	# fitted makes the house a little brighter from outside, so the last hour of
	# a week-long build is a building slowly coming on.
	for level in 3:
		for i in 2:
			_add(w, "light%d_%d" % [level, i], g, "site",
				{Kind.WIRE: 2, Kind.GLASS: 1}, [
					_p("cone", Vector3(lerpf(-HW, HW, (float(i) + 0.5) / 2.0) * 0.7,
						deck_y(level) + STOREY - 0.11, 0),
						Vector3(0.045, 0.06, 0), "brass", Vector3(PI, 0, 0)),
					_p("glow", Vector3(lerpf(-HW, HW, (float(i) + 0.5) / 2.0) * 0.7,
						deck_y(level) + STOREY - 0.14, 0),
						Vector3(0.024, 0.024, 0.024), "lamp"),
				], 5.0)

	for level in 3:
		_add(w, "socket%d" % level, g, "site", {Kind.WIRE: 2}, [
			_p("box", Vector3(-HW + 0.03, deck_y(level) + 0.09, HD * 0.3),
				Vector3(0.010, 0.035, 0.035), "brass"),
			_p("box", Vector3(HW - 0.03, deck_y(level) + 0.09, -HD * 0.3),
				Vector3(0.010, 0.035, 0.035), "brass"),
		], 4.0)

	_add(w, "basin", g, "site", {Kind.PIPE: 2, Kind.CLAY: 2}, [
		_p("box", Vector3(HW * 0.6, deck_y(0) + 0.17, -HD * 0.75),
			Vector3(0.13, 0.05, 0.10), "plaster"),
		_p("log", Vector3(HW * 0.6, deck_y(0) + 0.09, -HD * 0.75),
			Vector3(0.012, 0.14, 0), "pipe"),
	], 5.0)

	_add(w, "bath", g, "site", {Kind.PIPE: 2, Kind.CLAY: 3}, [
		_p("box", Vector3(HW * 0.55, deck_y(1) + 0.06, -HD * 0.65),
			Vector3(0.20, 0.09, 0.12), "plaster"),
	], 5.0)

	_add(w, "hearthstone", g, "site", {Kind.STONE: 3, Kind.LIME: 1}, [
		_p("box", Vector3(-HW * 0.55, deck_y(0) + 0.012, -HD * 0.55),
			Vector3(0.26, 0.020, 0.20), "stone"),
	], 5.0)


static func _paint(w: Array) -> void:
	var g := "Paint"

	# Limewash over the plaster, room by room. It changes the colour of every
	# interior surface fitted so far, which is why it is late and why it is one
	# of the more satisfying things to watch land.
	for level in 3:
		for i in 3:
			_add(w, "wash%d_%d" % [level, i], g, "site",
				{Kind.LIME: 2, Kind.CLAY: 1}, [
					_p("box", Vector3(lerpf(-HW, HW, (float(i) + 0.5) / 3.0),
						deck_y(level) + STOREY * 0.5, -HD + 0.045),
						Vector3(HW * 0.62, STOREY - 0.06, 0.004), "wash"),
				], 4.0)


static func _handover(w: Array) -> void:
	var g := "Handover"

	# The skip. Last piece of equipment on the island and the only one built to
	# take things away, which is the correct note to end a build on.
	_add(w, "skip", g, "skip", {Kind.PANEL: 4, Kind.IRON: 3}, [
		_p("box", Vector3(0, 0.10, 0), Vector3(0.40, 0.16, 0.26), "iron"),
		_p("box", Vector3(0, 0.19, 0), Vector3(0.42, 0.02, 0.28), "dark"),
		_p("log", Vector3(-0.18, 0.02, 0.14), Vector3(0.035, 0.24, 0), "iron",
			Vector3(PI * 0.5, 0, 0)),
		_p("log", Vector3(0.18, 0.02, 0.14), Vector3(0.035, 0.24, 0), "iron",
			Vector3(PI * 0.5, 0, 0)),
	], 10.0)

	for i in 4:
		_add(w, "clear%d" % i, g, "site", {Kind.FIBRE: 1}, [], 9.0)

	# A path to the door, and then it is done.
	_add(w, "path", g, "site", {Kind.STONE: 4}, [
		_p("stone", Vector3(0.02, 0.0, HD + 0.34), Vector3(0.11, 0.02, 0.10), "stone"),
		_p("stone", Vector3(-0.05, 0.0, HD + 0.54), Vector3(0.11, 0.02, 0.10), "stone"),
		_p("stone", Vector3(0.06, 0.0, HD + 0.74), Vector3(0.11, 0.02, 0.10), "stone"),
		_p("stone", Vector3(-0.02, 0.0, HD + 0.94), Vector3(0.11, 0.02, 0.10), "stone"),
	], 8.0)
