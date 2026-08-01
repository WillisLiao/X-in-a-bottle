class_name ElfWorld
extends World

## Hobbitle. Hobbits in a bottle.
##
## An island, the people living on it, and one house they are trying to build
## that will take them a week.
##
## The people are hobbits and trolls - see `Species` - and have been since the
## rename. The class is still `ElfWorld`, the array is still `_elves`, and the
## prose below still says "elf" in a lot of places, because renaming an
## identifier used four thousand lines deep is a large mechanical edit with
## nothing on the other side of it: nobody using this app ever reads a variable
## name. Do not spend a session on it. What a user sees is the app name, the
## title screen and the bodies on the island, and those are all hobbits now.
##
## Nothing here is animation. Every stone, log, ingot and pane of glass is a real
## object that is dug or made somewhere, sits in a heap until somebody lifts it,
## travels in their hands, and is set down somewhere else. When a joist goes into
## the second floor, three separate elves carried the three lengths of lumber
## that paid for it, and each of those was two trees somebody felled and a trip
## to the sawmill.
##
## The regress is the point, and it goes all the way down. They cannot frame a
## wall without lumber, cannot make lumber without a sawmill, cannot build a
## sawmill without felling trees by hand first. The first hour of a new island is
## four elves knapping stone. The last hour of the seventh day is a treadwheel
## crane swinging a laminated beam onto the third storey while somebody limewashes
## a bedroom. Nothing in between is skipped and nothing is a cutscene.
##
## ## They are not omniscient
##
## This is the thing the whole world is arranged to protect. Each elf only knows
## what it has been close enough, and had a clear enough line, to see. It
## remembers that and acts on it long after it has gone stale. So they walk
## somewhere to find it empty and turn round, go and look because they are not
## sure, carry a stone to the site and discover the walls have started, and
## disagree about what needs doing because they genuinely hold different pictures
## of the same island.
##
## An agent that is never wrong and never surprised has no point of view. It has
## the world's view. Every time behaviour looks slightly off, the fix that
## suggests itself is to let one of them read the real number. That fix is the
## whole thing collapsing, and it must be refused every time.
##
## ## And they are not conscious
##
## They are utility-maximising agents. On finishing anything, an elf scores every
## option it can currently imagine through its own weights and takes the
## maximum. There is no self-model and nothing it is like to be one, and no
## amount of work here will change that, because nobody knows how to and there is
## no test that would tell us if we had.
##
## The goal that *is* specifiable: a person watching one elf for ninety seconds
## comes away believing there is somebody in there. Test it by recording ninety
## seconds following one elf and showing it to two people separately. If they
## independently describe a similar character, it works. If they say "it fetches
## things", it does not.

const LAND_X := Biome.LAND_X
const LAND_Z := Biome.LAND_Z

enum Task { NONE, GATHER, CRAFT, HAUL, DELIVER, FIT, LOOK, REST, IDLE, OWN, PLAY }

## Two bodies, two jobs. Small and quick does the fine work; big and slow does
## what the small ones physically cannot. Roughly nine to three at a full crew.
enum Species { HOBBIT, TROLL }
const TROLL_FRACTION := 0.25

## How far an elf can make out what is in a heap. Small against a thirteen metre
## island, which is the entire point: standing at the mine you have no idea what
## is in the yard and you have to remember.
const SIGHT := 2.8

## The house is two metres tall and lit from inside. You can see how far along it
## is from most of the island, and that is correct - what you cannot see from the
## mine is whether there is any lumber left.
const SITE_SIGHT := 7.0

## How long a memory takes to become worthless.
const FORGET := 90.0

## How much a load of each material slows a walk down, 0 barely noticed and 1
## the heaviest thing on the island. Ordered to match `Plan.Kind`.
const CARRY_DRAG := [
	1.0, 0.55, 0.9, 0.6, 0.5, 0.12,
	0.4, 1.0, 0.5, 0.45, 0.85, 0.35,
	0.6, 0.25, 0.10, 0.35,
]

## How many works are open at once. One at a time and eleven elves queue behind a
## single joist; ten at a time and the house grows in ten places and stops
## reading as a sequence. Four is enough to keep everybody busy while still
## looking like a site with a plan.
const OPEN_WORKS := 4

## An hour of building, then a quarter of an hour off.
##
## The hour is counted in building, not in wall clock, so it survives being put
## down and picked up. The quarter hour is counted in *app open on this island*
## and nothing else: they will not finish their break while you are looking at
## another island or at the home screen.
##
## That asymmetry is the whole idea and it is worth being clear about why it is
## not a trick to keep the app open. Every other timer in this genre runs down
## while you are away, so the correct play is always to leave. This one runs down
## only while you are here, and there is nothing to do while it does - the elves
## have stopped, there is no work to watch, and the only thing on screen is a
## light crossing the sky. It is fifteen minutes of the app explicitly having
## nothing for you. If you take the break with them, they are ready when you come
## back. If you do not, they are still sitting there.
const WORK_PERIOD := 60.0 * 60.0
const REST_PERIOD := 15.0 * 60.0

## The swing, stated as a plane first and an arc inside it second.
##
## An earlier version named the two ends of the swing as directions and slerped
## between them, which is what you reach for and does not work: two directions
## nearly a half turn apart pin down a plane only weakly, and the plane those two
## happened to define was 49 degrees off horizontal, so the tool went round the
## body at chest height like a bat. Stated this way the plane is a decision and
## the arc follows from it.
const SWING_ROLL := 0.68
const SWING_YAW := -0.06
const SWING_STRIKE := 1.25
const SWING_COCK := 2.80

const COCK_GRIP := Vector3(0.020, 0.245, 0.100)
const STRIKE_GRIP := Vector3(0.040, 0.235, 0.110)

## Shoulder to hand. One rigid segment, no elbow.
const ARM := 0.190

var _swing_plane := Basis(Vector3.UP, SWING_YAW) * Basis(Vector3.FORWARD, SWING_ROLL)

const EMBER := Color("FF9A4A")
const TRIM := Color("E8C36A")
const BOOT := Color("6B4630")
const EYE := Color("2A1F1A")
const CHEEK := Color("E28C7A")


## A heap. Mixed, because a mill's input pile takes whatever it eats and a heap
## of two things beside a kiln reads better than two heaps of one.
class Pile:
	var accepts: Array[int] = []
	var at: Vector3
	var stand: Vector3
	var node: Node3D
	var items: Array[Node3D] = []
	var limit := 8

	## How much of any one kind this heap will hold. Without it a mill that eats
	## three things ends up with a heap of eight of the first one to arrive and
	## can never be fed again - and because the elves are hauling on what they
	## believe rather than what is there, several of them will keep bringing more
	## of it. That is the belief system working exactly as intended producing a
	## permanent deadlock, so the ceiling belongs on the heap rather than in
	## their heads.
	var caps := {}

	func room() -> bool:
		return items.size() < limit

	func takes_more(kind: int) -> bool:
		if items.size() >= limit:
			return false
		return of(kind) < int(caps.get(kind, limit))

	func count() -> int:
		return items.size()

	func of(kind: int) -> int:
		var n := 0
		for it in items:
			if int(it.get_meta("kind")) == kind:
				n += 1
		return n

	func takes(kind: int) -> bool:
		return accepts.has(kind)

	func take(kind: int) -> Node3D:
		for i in range(items.size() - 1, -1, -1):
			if int(items[i].get_meta("kind")) == kind:
				var it := items[i]
				items.remove_at(i)
				return it
		return null

	func settle() -> void:
		for i in items.size():
			var ring := i / 3
			var slot := i % 3
			var angle := TAU * float(slot) / 3.0 + float(ring) * 0.7
			var reach := 0.115 * (0.35 if ring == 0 else 1.0)
			items[i].position = Vector3(
				cos(angle) * reach,
				0.05 + float(ring) * 0.072,
				sin(angle) * reach)


## Somewhere one elf at a time stands and turns one thing into another. A quarry
## face and a limekiln are the same object here; the quarry simply has no inputs,
## because the rock is already there.
class Station:
	var id: String
	var out_kind: int
	var inputs: Dictionary = {}
	var seconds := 8.0
	var motion := "swing"
	var tool := "pick"
	var stand: Vector3
	var face: Vector3
	var out_pile: Pile
	var in_pile: Pile
	var taken_by := -1

	func is_source() -> bool:
		return inputs.is_empty()


## Anything under construction, which is everything: a limekiln, a crane, a floor
## joist and a doorknob are all one of these.
class Work:
	var spec: Dictionary
	var index := 0
	var at: Vector3
	var holder: Node3D
	var delivered: Dictionary = {}
	var fitting := 0.0
	var done := false
	var taken_by := -1

	func needs(kind: int) -> int:
		return int(spec["cost"].get(kind, 0)) - int(delivered.get(kind, 0))

	func short() -> Array[int]:
		var out: Array[int] = []
		for k in spec["cost"]:
			if needs(int(k)) > 0:
				out.append(int(k))
		return out

	func ready() -> bool:
		return short().is_empty()


class Elf:
	var id: int
	var seed_value: int
	var node: Node3D
	var rig: Node3D
	var body: Node3D
	var body_scale := Vector3.ONE
	var head: Node3D
	var pupils: Array[Node3D] = []
	var arms: Array[Node3D] = []
	var shoulders: Array[Vector3] = []
	var legs: Array[Node3D] = []

	## Both hands as one point. Everything two-handed hangs off this.
	var grip: Node3D

	# Rolled once from the seed, kept for life.
	var pace := 0.42
	var stamina := 1.0
	var sociable := 0.0
	var fidget := 0.0
	var spot := 0.0
	var route_bias := 0.0
	var gait := 1.0
	var playful := 0.3

	## How often this one breaks stride for something happening off to the
	## side. One of them is a rubbernecker, another never turns its head -
	## the difference is what makes either recognisable on a second watch.
	var rubberneck := 0.5
	var stop_left := 0.0
	var stop_at: Vector3

	## The motor signature. Twelve bodies moving identically is as strong an
	## NPC signal as anything on this list, and it costs nothing beyond
	## another few rolls off the same seed that already gives everything else
	## its individuality.
	var stride_amp := 1.0
	var bounce_amt := 1.0
	var turn_rate := 3.0
	var fidget_kind := 0
	var fidget_phase := 0.0

	## Arriving to find the last unit already gone to somebody else. Look at
	## the empty heap, look at whoever got there first, then turn away - the
	## sequence that makes losing legible rather than just another silent
	## about-face.
	var lose_left := 0.0
	var lose_phase := 0
	var lose_empty: Vector3
	var lose_winner: Vector3
	var lose_has_winner := false

	## The fraction of full pace actually being walked at right now, eased
	## toward a target each tick rather than following it instantly. Constant
	## velocity in a straight line is one of the strongest signs of a lookup
	## table there is.
	var walk_speed := 0.0

	## Hobbit or troll. Fixed for life, and it decides more than the body: a
	## troll carries more, moves slower, and never sets foot at a mill.
	var species: Species = Species.HOBBIT
	var carry_limit := 1
	var carry_count := 0

	## Somewhere of its own. Not the project's, not useful, just a place this one
	## keeps coming back to. Behaviour the shared goal cannot explain is what
	## makes an agent look like it has reasons of its own.
	var haunt: Vector3
	var haunted := -160.0

	## What it has seen, and when. Pile -> { "n": {kind: count}, "seen": time }.
	## An absent key means it has never been there and assumes nothing is there.
	var beliefs := {}

	## What it last understood the site to want. Refreshed only within sight of
	## the house, so an elf at the mine is working from an old idea of the job.
	var site_needs := {}
	var site_ready := 0
	var site_seen := -900.0

	## Formed rather than born. Every task starts equal and creeps up each time
	## this elf finishes one, so a small early accident compounds into a
	## specialism. A history you can watch accumulate is the cheapest available
	## form of a self, and it is the one thing about an elf that is saved.
	var affinity := {}

	## Who it likes. Nudged up by working alongside somebody, down by being cut
	## up on a path or beaten to the last ingot.
	var bond := {}

	## One scalar, -1 to 1, driving posture, gait, pace and how far the head
	## swings. Deliberately does not drive decisions: body language alone gets
	## most of the way, and a mood that changes what an elf wants is much harder
	## to read as a mood.
	var mood := 0.0

	var at: Vector3 = Vector3.ZERO
	var facing: Vector3 = Vector3.FORWARD
	var target: Vector3 = Vector3.ZERO
	var face_at: Vector3 = Vector3.ZERO
	var waypoint: Vector3
	var has_waypoint := false
	var moving := false

	var look_at: Vector3
	var look_left := 0.0
	var point_left := 0.0
	var point_at: Vector3

	## The double-take: a belief just changed materially, and this is the beat of
	## stillness where that becomes something a viewer can watch happen.
	var startle_left := 0.0
	var startle_at: Vector3
	var startle_good := true

	## How long `_decide` held before departing, and what it nearly chose
	## instead. Sits alongside `pause` rather than replacing it - a hesitation is
	## the elf visibly weighing an already-made decision, not a delay before
	## deciding.
	var hesitate_left := 0.0
	var hesitate_at: Vector3
	var rejected_at: Vector3
	var rejected := false

	var energy := 1.0
	var task: Task = Task.NONE
	var station: Station
	var work: Work
	var from_pile: Pile
	var to_pile: Pile
	var want_kind := -1
	var carrying: Node3D
	var carry_kind := -1
	var tool: Node3D
	var tool_kind := ""
	var motion := "swing"
	var work_left := 0.0
	var pause := 0.0
	var grown := 0.0
	var phase := 0.0
	var pastime := ""
	var last_task: Task = Task.NONE
	var handed := -40.0


var _island := 0
var _b := {}
var _pace: Dictionary = {}

## The ground under all of this. Shared with `Country`, which draws the same
## land for the regions nobody is standing in - see `Land`.
var _land: Land

## Where they have walked, which is the one record this app keeps of what the
## user actually did with their attention. See `Wear`.
var _wear := Wear.new()
var _since_wear := 0.0

var _elves: Array[Elf] = []
var _piles: Array[Pile] = []
var _stations: Array[Station] = []
var _works: Array[Work] = []
var _anchors: Dictionary = {}
var _mats: Dictionary = {}

## Every elf who lives here, as the integer they are generated from. They come
## and go with the charge, but the same people come back.
var _residents: PackedInt32Array = PackedInt32Array()
var _resident_affinity := {}

var _fire: OmniLight3D
var _house_light: OmniLight3D

## Places where something just happened, for eyes to be drawn to.
var _events: Array = []

var _time := 0.0
var _quake := 0.0

## How recently the phone moved. While this is up the elves have downed tools -
## which is the whole app in one variable.
var _rattled := 0.0

var _focus := 0.0

## Where they are in the hour, and how much of the break is left.
var _cycle := 0.0
var _rest_left := 0.0
var _rest_note := 0.0

var _next_id := 0
var _since_save := 0.0
var _dirty := false


func _init(island := 0) -> void:
	_island = island
	_b = Biome.of(island)
	_land = Land.new(island)
	_pace = _b["pace"]

	title = Biome.name_of(island)
	capacity = 12
	spawn_seconds = 1.5

	# Back and above, at about forty degrees.
	#
	# The angle is the whole argument. Lower reads faces better but flattens the
	# island into a band with a black sky above and a wall of near ground below;
	# higher composes well but starts showing the tops of hats, and hats are not
	# people. This is the default rather than the only choice now - the camera
	# pitches and zooms, so somebody who wants to be down among them can be.
	# Thirty-six degrees up, which is lower than it was and is only affordable
	# because of the lens below. A wide lens at this pitch put a wall of empty
	# near shore across the bottom third; a long one at the same pitch fits the
	# whole island between a strip of void above and a strip below, which is what
	# a thing in a bottle is supposed to look like, and it reads faces better
	# than looking down on the tops of hats.
	focus = Vector3(0.3, 0.70, -0.2)
	distance = 11.0
	rise = 8.0
	orbit_gain = 0.55

	# A long lens, further back, rather than a wide one up close.
	#
	# At 46 degrees the near shore was four metres from the camera and thirteen
	# from the far one, so perspective tripled it: the bottom third of the frame
	# was empty foreground and the island read as a hillside you were standing
	# on. Thirty-four degrees from twelve metres out flattens that back to a
	# diorama, which is what a thing in a bottle should look like.
	lens = 34.0

	key_color = _b["key"]
	key_energy = _b["key_energy"]
	fill_color = _b["fill"]
	fill_energy = _b["fill_energy"]
	ambient_color = _b["ambient"]
	ambient_energy = _b["ambient_energy"]


func build() -> void:
	# Before anything else, because the cover scattered in `_build_clutter` has
	# to know where the paths are, and by the time somebody reopens a region
	# they have been living in the paths are a week old.
	_wear.from_text(String(Progress.read(_island)["wear"]))

	_build_materials()
	_build_terrain()
	_build_water()
	_build_sources()
	_build_hearth()
	_build_clutter()
	_build_works()
	_restore()


func held() -> int:
	return _elves.size()


# --- the ground --------------------------------------------------------------
#
# Everywhere is a Vector3 with y ignored. Height is read from the land whenever
# something is placed and never carried around, so nothing can end up hovering
# because it was positioned before the ground under it was decided.

func _gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _off(at: Vector3, dx: float, dz: float) -> Vector3:
	return Vector3(at.x + dx, 0.0, at.z + dz)


func _in_front(stand: Vector3, face: Vector3, by: float) -> Vector3:
	return stand + _flat(face - stand) * by


func _flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-10 else Vector3.ZERO


func _spot(name: String) -> Vector3:
	return Biome.LAYOUT[name]


## The height of the land under a place. The terrain mesh, every station and
## every elf's feet read from this one function, so the land and the people on it
## cannot drift apart. It lives in `Land` now, because the four regions nobody is
## standing in have to be drawn from the same ground the one you are in is.
func _ground(p: Vector3) -> float:
	return _land.height(p)


func _on(p: Vector3) -> Vector3:
	return _land.on(p)


## Whether one thing can be seen from another. The whole of an elf's ignorance
## rests on this: the ridge is over a metre high, and an elf on the far side of
## it genuinely cannot see the yard however close it is standing.
func _clear(from: Vector3, to: Vector3, tall: float) -> bool:
	var eye := _ground(from) + 0.40
	var top := _ground(to) + tall
	for i in range(1, 5):
		var t := float(i) / 5.0
		if _ground(from.lerp(to, t)) > lerpf(eye, top, t) + 0.03:
			return false
	return true


func _anchor(p: Vector3, lift := 0.0, yaw := 0.0) -> Node3D:
	var node := Node3D.new()
	node.position = _on(p) + Vector3(0, lift, 0)
	node.rotation.y = yaw
	add_child(node)
	return node


## How far out a pile's footprint reaches plus a little room to stand.
## `Pile.settle` never places an item further than about 0.115 out from the
## pile's centre, so this clears the heap itself without also pushing out the
## working stand points, which sit roughly 0.35 out from their own pile by
## design.
const PILE_CLEAR := 0.30


## Nowhere anybody should ever be asked to stand: on top of a heap. A haunt
## roll, a rest spot, an idle wander and `_stand_near` can each land inside a
## pile's footprint on their own - this is the one place that pushes any of
## them back out, so the fix does not have to be found again the next time a
## new kind of spot generation shows up.
func _clear_of_piles(p: Vector3) -> Vector3:
	var out := p
	for _pass in range(2):
		for pile in _piles:
			var d := _gap(out, pile.at)
			if d < PILE_CLEAR:
				var away := _flat(out - pile.at)
				if away == Vector3.ZERO:
					away = Vector3.FORWARD
				out = pile.at + away * PILE_CLEAR
	return _ashore(out)


func _ashore(p: Vector3) -> Vector3:
	var kept := p
	for _i in 6:
		if _ground(kept) > -0.16:
			return kept
		kept = Vector3(kept.x * 0.84, 0.0, kept.z * 0.84)
	return _spot("site")


# --- the world tick ----------------------------------------------------------

func _tick(delta: float, _population: int, disturbed: bool) -> void:
	_time += delta
	_quake = maxf(0.0, _quake - delta * 1.4)

	if _rest_left > 0.0:
		# The break runs on app-open time alone. Movement is not a disturbance
		# during it: they have stopped anyway, and charging somebody for picking
		# their phone up during a rest would make the rest a second shift.
		_rest_left = maxf(0.0, _rest_left - delta)
		_rest_note = maxf(0.0, _rest_note - delta)
		_rattled = 0.0
		if _rest_left <= 0.0:
			_wake()
		_dirty = true
	else:
		# The phone moved. Tools go down, work stops accruing, and it takes them a
		# moment to settle back to it - but nothing that is already built comes
		# apart. Undoing the work was the wrong cost: it made a phone call able to
		# erase an evening, and the point is to slow the build down, not to send
		# it backwards.
		if disturbed:
			_rattled = 1.0
		else:
			_rattled = maxf(0.0, _rattled - delta * 0.34)
			_focus += delta
			_cycle += delta
			if _cycle >= WORK_PERIOD:
				_down_tools()

	position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) \
		* _quake * 0.05

	if _fire:
		_fire.light_energy = 1.5 + sin(_time * 7.3) * 0.18 + sin(_time * 3.1) * 0.12

	# The house lights from within as the fittings go in. A lit window across a
	# dark island at the end of a week is the whole reward, so it is earned one
	# lamp at a time rather than switched on at completion.
	if _house_light:
		_house_light.light_energy = _lit() * 3.0

	for i in range(_events.size() - 1, -1, -1):
		if _time - _events[i]["when"] > 2.2:
			_events.remove_at(i)

	for e in _elves:
		_tick_elf(e, delta)

	# The paths go up to the GPU twice a second rather than on every footfall.
	# A dozen people walking would otherwise upload the same small texture a
	# dozen times a frame, and nothing about a track appearing over an hour
	# needs to be seen sooner than this.
	_since_wear += delta
	if _since_wear > 0.5:
		_since_wear = 0.0
		if _wear.flush():
			_dirty = true

	_since_save += delta
	if _dirty and _since_save > 20.0:
		_save()


func _note(at: Vector3) -> void:
	_events.append({"at": at, "when": _time})
	if _events.size() > 10:
		_events.remove_at(0)


func resting() -> bool:
	return _rest_left > 0.0


## How far through the break, zero to one. Drawn as a light crossing the sky
## rather than as a bar with a number on it.
func rest_fraction() -> float:
	if _rest_left <= 0.0:
		return -1.0
	return clampf(1.0 - _rest_left / REST_PERIOD, 0.0, 1.0)


## How far through the working hour, zero to one. The sun's elevation follows
## this, so the last few minutes before a break announce it by the light
## dropping before anything on the ground stops.
func work_fraction() -> float:
	return clampf(_cycle / WORK_PERIOD, 0.0, 1.0)


## An hour is up.
##
## Everybody sets down what they are holding and stops, which has to be done
## properly: an elf caught mid-errand still has a claim on a bench and an ingot
## in its hands, and both have to go back or the island wakes up with a
## permanently reserved sawmill and a missing bar of iron.
func _down_tools() -> void:
	_cycle = 0.0
	_rest_left = REST_PERIOD
	_rest_note = 24.0

	for e in _elves:
		if e.carrying:
			var holder := e.carrying
			e.grip.remove_child(holder)
			var home := _home_for(e.carry_kind)
			for child in holder.get_children():
				holder.remove_child(child)
				if home:
					home.node.add_child(child)
					home.items.append(child)
				else:
					add_child(child)
					child.position = _on(e.at) + Vector3(0, 0.05, 0)
			if home:
				home.settle()
			holder.queue_free()
			e.carrying = null
			e.carry_count = 0
		_finish(e)
		_cheer(e, 0.30)

	_dirty = true
	_save()


func _wake() -> void:
	for e in _elves:
		e.energy = 1.0
		_cheer(e, 0.45)
		_finish(e)
	_dirty = true
	_save()


## How much of the house is lit, which is how much of the fitting-out is done.
func _lit() -> float:
	var on := 0
	var all := 0
	for w in _works:
		if str(w.spec["group"]) in ["Fittings", "Paint", "Front", "Handover"]:
			all += 1
			if w.done:
				on += 1
	return 0.0 if all == 0 else clampf(float(on) / float(all), 0.0, 1.0)


# --- what an elf knows -------------------------------------------------------

## Look around. Only heaps close enough, roughly in front, and not behind
## something refresh what this elf thinks is true.
##
## Every temptation to reach past this and read the real count must be refused.
## The moment one elf does it, all of them are omniscient again and none of the
## behaviour above it means anything.
func _observe(e: Elf) -> void:
	for p in _piles:
		var away := _gap(e.at, p.at)
		if away > SIGHT:
			continue
		if away > 0.6 and not _facing(e, p.at):
			continue
		if away > 0.6 and not _clear(e.at, p.at, 0.20):
			continue
		var n := {}
		for it in p.items:
			var k := int(it.get_meta("kind"))
			n[k] = int(n.get(k, 0)) + 1

		if e.startle_left <= 0.0 and e.beliefs.has(p):
			var old: Dictionary = e.beliefs[p]["n"]
			var old_total := 0
			for k in old:
				old_total += int(old[k])
			var total := 0
			for k in n:
				total += int(n[k])
			# The heap it thought was full has none, the heap it thought was
			# empty has some, or it just moved a lot while this elf's back was
			# turned. Any of those is worth stopping for; a stone or two either
			# way is not.
			var swing: int = absi(total - old_total)
			var emptied := old_total > 0 and total == 0
			var filled := old_total == 0 and total > 0
			if emptied or filled or swing >= 4:
				var severity := clampf(float(swing) / 6.0, 0.5, 1.0)
				_startle(e, p.at, filled or (not emptied and total >= old_total), severity)

		e.beliefs[p] = {"n": n, "seen": _time}

	var site := _spot("site")
	if _gap(e.at, site) < SITE_SIGHT and _clear(e.at, site, 1.10):
		var needs := {}
		var ready := 0
		for w in _open():
			if w.ready():
				ready += 1
			for k in w.short():
				needs[k] = int(needs.get(k, 0)) + w.needs(k)

		# What it is carrying just stopped being wanted, or the site has just
		# started wanting something it is not carrying and had no reason to
		# expect.
		if e.startle_left <= 0.0 and _time - e.site_seen < FORGET * 2.0:
			if e.carrying != null and int(e.site_needs.get(e.carry_kind, 0)) > 0 \
					and int(needs.get(e.carry_kind, 0)) <= 0:
				_startle(e, site, false, 0.75)
			elif e.site_needs.is_empty() and not needs.is_empty():
				_startle(e, site, true, 0.6)

		e.site_needs = needs
		e.site_ready = ready
		e.site_seen = _time


## The moment a belief turns over. This is the only place in the codebase
## where an elf finds out it was wrong, and until now it produced no
## behaviour at all - the belief changed and nothing on screen did. `severity`
## is how wrong: 0.5 barely worth remarking on, 1.0 the heap it was sure about
## has done a complete about-face.
func _startle(e: Elf, at: Vector3, good: bool, severity: float) -> void:
	e.startle_left = lerpf(0.6, 1.2, clampf(severity, 0.0, 1.0))
	e.startle_at = at
	e.startle_good = good
	e.has_waypoint = false
	e.look_at = at
	e.look_left = 0.4


func _facing(e: Elf, at: Vector3) -> bool:
	return _flat(at - e.at).dot(e.facing) > 0.1


func _believes(e: Elf, p: Pile, kind: int) -> int:
	if not e.beliefs.has(p):
		return 0
	return int(e.beliefs[p]["n"].get(kind, 0))


func _stale(e: Elf, p: Pile) -> float:
	if not e.beliefs.has(p):
		return FORGET * 1.6
	return _time - e.beliefs[p]["seen"]


## How much weight to put on a memory. Never zero, or an elf would refuse to act
## on anything old, and never one for long, or it would never go and check.
func _sure(e: Elf, p: Pile) -> float:
	return clampf(1.0 - _stale(e, p) / FORGET, 0.20, 1.0)


func _mood01(e: Elf) -> float:
	return clampf(e.mood * 0.5 + 0.5, 0.0, 1.0)


func _cheer(e: Elf, amount: float) -> void:
	e.mood = clampf(e.mood + amount, -1.0, 1.0)


## Doing a thing makes an elf a little more that kind of elf.
func _reward(e: Elf, t: Task, amount: float) -> void:
	e.affinity[t] = minf(2.4, float(e.affinity.get(t, 1.0)) * (1.0 + amount))
	for k in e.affinity:
		if k != t:
			e.affinity[k] = maxf(0.55, float(e.affinity[k]) * 0.994)
	_resident_affinity[str(e.seed_value)] = e.affinity.duplicate()
	_dirty = true


func _like(e: Elf, other: Elf, amount: float) -> void:
	e.bond[other.id] = clampf(float(e.bond.get(other.id, 0.0)) + amount, -1.0, 1.0)


# --- the mind ----------------------------------------------------------------

## Everything an elf does comes through here. It is called whenever one has
## nothing in hand and nothing in progress, and it scores its own picture of the
## island rather than the island.
func _decide(e: Elf) -> void:
	e.station = null
	e.work = null
	e.from_pile = null
	e.to_pile = null
	e.want_kind = -1

	# The hour is up. What they do with the quarter hour is their own business,
	# which is the entire point of a break.
	if resting():
		_decide_rest(e)
		return

	# Nothing gets decided while the phone is in somebody's hand. They mill,
	# they look up, and they wait for it to be put down.
	if _rattled > 0.35:
		e.task = Task.IDLE
		_head_for(e, _somewhere_own(e))
		e.pause = randf_range(1.0, 2.5)
		return

	# Tiredness is a weight, not a rule. A stubborn elf keeps working well past
	# the point a soft one has gone to sit down.
	if e.energy < 0.18 * e.stamina:
		e.task = Task.REST
		_head_for(e, _stand_near(e, _spot("hearth")), _spot("hearth"))
		return

	var best := Task.IDLE
	var score := 0.34 + e.fidget * 0.7
	var pick := {}

	# The runner-up, kept alongside the winner so a near-tie can be told from a
	# clear call. Nothing here changes what gets chosen - only how long it
	# stands there before leaving.
	var second := 0.0
	var second_at := e.at
	var best_at := e.at

	var open := _open()

	# Setting a piece. Outranks everything, because it is the only step that
	# leaves a mark, and because a work standing fully paid for with nobody
	# fitting it is the one situation on a site that everybody notices.
	for w in open:
		if w.taken_by != -1 and w.taken_by != e.id:
			continue
		if not w.ready():
			continue
		if _time - e.site_seen > FORGET * 2.0:
			continue
		var s := _weigh(e, Task.FIT, 1.90, w.at)
		if s > score:
			second = score
			second_at = best_at
			score = s
			best = Task.FIT
			best_at = w.at
			pick = {"work": w}
		elif s > second:
			second = s
			second_at = w.at

	# Carrying something the site is short of. Urgency comes from how bare this
	# elf last saw the site, so one that walked past ten seconds ago goes and
	# does something about it while one that has been at the mine all minute
	# does not.
	if _time - e.site_seen < FORGET * 2.0:
		for w in open:
			for k in w.short():
				var src := _believed_source(e, k)
				if src == null:
					continue
				var s := _weigh(e, Task.DELIVER,
					1.22 + float(w.needs(k)) * 0.06, src.stand) * _sure(e, src)
				if s > score:
					second = score
					second_at = best_at
					score = s
					best = Task.DELIVER
					best_at = src.stand
					pick = {"work": w, "from": src, "kind": k}
				elif s > second:
					second = s
					second_at = src.stand

	# Feeding a mill. A station short of an input is the commonest reason
	# anything stalls, and hauling to it is the least glamorous job on the
	# island, which is exactly why some elves grow into doing nothing else.
	for st in _stations:
		if st.is_source() or st.in_pile == null:
			continue
		for k in st.inputs:
			var kind := int(k)
			var have := _believes(e, st.in_pile, kind)
			# Two of what a batch needs, not three. Three had them hauling more
			# than half the day: every mill wanting a deep buffer generates a
			# haul option, and with six mills that swamped every other reason to
			# be anywhere. A mill should run hand to mouth and occasionally wait.
			var want := int(st.inputs[k]) * 2
			if have >= want:
				continue
			var src := _believed_source(e, kind, st.in_pile)
			if src == null:
				continue
			var s := _weigh(e, Task.HAUL,
				0.86 + (0.40 if have == 0 else 0.0), src.stand) * _sure(e, src)
			if s > score:
				second = score
				second_at = best_at
				score = s
				best = Task.HAUL
				best_at = src.stand
				pick = {"from": src, "to": st.in_pile, "kind": kind}
			elif s > second:
				second = s
				second_at = src.stand

	# Working a station. Only worth it if there is somewhere to put the output
	# and, for a mill, something to put in.
	for st in _stations:
		if st.taken_by != -1 and st.taken_by != e.id:
			continue
		if st.out_pile == null or not st.out_pile.room():
			continue
		var task := Task.GATHER if st.is_source() else Task.CRAFT
		# A troll does not set foot at a mill. Quarrying, felling and hauling
		# are what it is built for; glazing a window is not, and neither is
		# anything else that turns a raw material into a finished one.
		if task == Task.CRAFT and e.species == Species.TROLL:
			continue
		if not st.is_source():
			var fed := true
			for k in st.inputs:
				if _believes(e, st.in_pile, int(k)) < int(st.inputs[k]):
					fed = false
					break
			if not fed:
				continue
		var pull := 0.78
		# What the site is short of pulls the whole chain behind it. This is the
		# only place a shared goal reaches into an individual decision, and it
		# reaches through what the elf believes rather than what is true.
		if e.site_needs.has(st.out_kind):
			pull += 0.55
		var s := _weigh(e, task, pull, st.stand)
		if s > score:
			second = score
			second_at = best_at
			score = s
			best = task
			best_at = st.stand
			pick = {"station": st}
		elif s > second:
			second = s
			second_at = st.stand

	# Going to look, because it is not sure any more. This turns a stale memory
	# back into knowledge, and it is the only reason an elf ever walks somewhere
	# with no job waiting at the other end.
	var stalest: Pile = null
	var worst := 0.0
	for p in _piles:
		var s := _stale(e, p)
		if s > worst:
			worst = s
			stalest = p
	if stalest:
		var s := _weigh(e, Task.LOOK, 0.14 + minf(worst / 110.0, 0.62), stalest.stand)
		if s > score:
			second = score
			second_at = best_at
			score = s
			best = Task.LOOK
			best_at = stalest.stand
			pick = {"from": stalest}
		elif s > second:
			second = s
			second_at = stalest.stand

	# Its own place. The pull grows the longer it has been away, so every few
	# minutes an elf downs tools and goes and stands somewhere for no reason
	# anybody watching could give.
	var due := minf((_time - e.haunted) / 240.0, 0.55)
	var own := _weigh(e, Task.OWN, 0.22 + due, e.haunt)
	if own > score:
		second = score
		second_at = best_at
		score = own
		best = Task.OWN
		best_at = e.haunt
		pick = {}
	elif own > second:
		second = own
		second_at = e.haunt

	# And their own time. There is a house to build and they are not machines:
	# somebody is always at the water with a line in, and on a good day two of
	# them are kicking something about instead.
	if not _b["pastimes"].is_empty():
		var game: String = _b["pastimes"][randi() % _b["pastimes"].size()]
		var where := _pastime_spot(game)
		var s := _weigh(e, Task.PLAY, 0.20 + e.playful * 0.55, where)
		if s > score:
			second = score
			second_at = best_at
			score = s
			best = Task.PLAY
			best_at = where
			pick = {"game": game, "where": where}
		elif s > second:
			second = s
			second_at = where

	e.task = best
	e.station = pick.get("station", null)
	e.work = pick.get("work", null)
	e.from_pile = pick.get("from", null)
	e.to_pile = pick.get("to", null)
	e.want_kind = int(pick.get("kind", -1))

	# Hesitation, proportional to how close this was to going the other way. A
	# clear win leaves at once; a near-tie stands on the spot, looks at the
	# option it took, glances at the one it did not, and then goes. This is
	# nearly free - the margin is already sitting here about to be thrown away.
	var margin := score - second
	e.hesitate_left = 0.0
	e.rejected = false
	if best != Task.IDLE and second > 0.0:
		var closeness := clampf(1.0 - margin / 0.5, 0.0, 1.0)
		if closeness > 0.08:
			e.hesitate_left = lerpf(0.2, 1.5, closeness)
			e.hesitate_at = best_at
			e.rejected_at = second_at
			e.rejected = true

	match best:
		Task.FIT:
			e.work.taken_by = e.id
			_head_for(e, _stand_near(e, _site_stand(e)), e.work.at)
			_point(e, e.work.at)
		Task.DELIVER, Task.HAUL:
			_head_for(e, _stand_near(e, e.from_pile.stand), e.from_pile.at)
			_point(e, e.from_pile.at)
		Task.LOOK:
			_head_for(e, _stand_near(e, e.from_pile.stand), e.from_pile.at)
		Task.GATHER, Task.CRAFT:
			e.station.taken_by = e.id
			_head_for(e, _stand_near(e, e.station.stand), e.station.face)
		Task.OWN:
			_head_for(e, e.haunt)
			e.pause = randf_range(4.0, 9.0)
		Task.PLAY:
			e.pastime = str(pick["game"])
			_head_for(e, _stand_near(e, pick["where"]), _pastime_face(e.pastime))
			e.pause = randf_range(5.0, 13.0)
		_:
			# An elf that never does anything unprompted reads as a machine
			# waiting for input.
			_head_for(e, _somewhere_own(e))
			e.pause = randf_range(1.5, 5.0) * lerpf(1.6, 0.7, _mood01(e))


## How one elf spends the break.
##
## Not a single "everybody sits by the fire" animation. The whole island stopping
## at once is the most legible thing that happens all hour, and if all twelve do
## the same thing it undoes every bit of individuality the rest of the code is
## spent on. So it goes through the same traits: the tired sleep, the playful get
## a game going, the solitary walk off to the place that is theirs, and somebody
## is always at the water.
func _decide_rest(e: Elf) -> void:
	e.station = null
	e.work = null
	e.from_pile = null
	e.to_pile = null
	e.want_kind = -1

	var options := ["sleep", "sit", "away"]
	for p in _b["pastimes"]:
		if not options.has(str(p)):
			options.append(str(p))

	# How far into the break it is. A quarter of an hour has a shape: they knock
	# off and go straight to the water or start a game, and they end it asleep
	# round the fire. Weighting sleep by how much of the break has gone is what
	# produces that arc, and without it nobody ever lies down at all - a crew
	# that has just stopped working is not tired yet, so a tiredness term alone
	# never wins.
	var late := rest_fraction()

	var best := "sit"
	var score := -1.0
	for game in options:
		var s := randf() * 0.30
		match game:
			"sleep":
				s += 0.20 + (1.0 - e.energy) * 1.05 + late * 0.72
			"sit":
				s += 0.60 + e.sociable * 0.55
			"away":
				s += 0.42 - e.sociable * 0.55
			"fish":
				s += 0.46 + (1.0 - e.playful) * 0.30
			"swim":
				s += 0.30 + e.playful * 0.50
			_:
				s += 0.34
		if s > score:
			score = s
			best = game

	e.task = Task.PLAY
	e.pastime = best
	e.pause = randf_range(30.0, 95.0)

	var where := _rest_spot(e, best)
	_head_for(e, _stand_near(e, where), _pastime_face(best))


func _rest_spot(e: Elf, game: String) -> Vector3:
	match game:
		"sleep", "sit":
			var a := randf() * TAU
			return _clear_of_piles(_off(_spot("hearth"), cos(a) * randf_range(0.55, 1.15),
				sin(a) * randf_range(0.50, 1.0)))
		"away":
			return _clear_of_piles(e.haunt)
	return _pastime_spot(game)


## The heap this elf would go to for a given kind, by its own reckoning. Never
## the real answer - only somewhere it remembers seeing some.
func _believed_source(e: Elf, kind: int, not_this: Pile = null) -> Pile:
	var best: Pile = null
	var best_score := 0.0
	for p in _piles:
		if p == not_this:
			continue
		var n := _believes(e, p, kind)
		if n <= 0:
			continue
		var s := (0.6 + float(n) * 0.10) * _sure(e, p) - _gap(e.at, p.at) * 0.06
		if s > best_score:
			best_score = s
			best = p
	return best


func _weigh(e: Elf, task: Task, score: float, at: Vector3) -> float:
	# Two and a half pence a metre. It was more than twice this when the island
	# was half the size, and carrying that number across doubled every errand's
	# cost: the quarry scored below sitting down, so a full crew spent its day
	# at the fire. Distance should make an elf think, not refuse.
	score -= _gap(e.at, at) * 0.042

	score *= float(e.affinity.get(task, 1.0))

	# Sticking with what they were doing, so nobody flickers between two jobs
	# that happen to score alike. Only for work: carrying the bonus onto idling,
	# fishing and wandering off is how a crew of twelve ends up spending half its
	# day at the water, each of them individually well justified.
	if task == e.last_task and task in [Task.GATHER, Task.CRAFT, Task.HAUL,
			Task.DELIVER, Task.FIT]:
		score += 0.18

	score *= lerpf(0.55, 1.0, e.energy)
	score *= lerpf(0.82, 1.14, _mood01(e))

	# Company, and whose company. The blunt version counted bodies; this one
	# knows which bodies, so an elf with a friend at the sawmill finds reasons
	# to be at the sawmill.
	if absf(e.sociable) > 0.01 or not e.bond.is_empty():
		var pull := 0.0
		for other in _elves:
			if other.id == e.id or _gap(other.at, at) > 1.2:
				continue
			pull += e.sociable * 0.14 + float(e.bond.get(other.id, 0.0)) * 0.22
		score += pull

	return score


## Somewhere near a station rather than exactly on its mark, chosen per elf, so
## two of them never occupy the same patch of ground and a queue looks like
## people gathered round rather than a line.
func _stand_near(e: Elf, at: Vector3) -> Vector3:
	var r := 0.20 + absf(e.route_bias) * 0.28
	return _clear_of_piles(_off(at, cos(e.spot) * r, sin(e.spot) * r * 0.7))


## Where to stand to work on the house. Round the outside, at the elf's own
## angle, because eleven elves converging on one point is a scrum.
func _site_stand(e: Elf) -> Vector3:
	var site := _spot("site")
	var a := e.spot
	return _ashore(_off(site, cos(a) * (Plan.HW + 0.55), sin(a) * (Plan.HD + 0.55)))


## Sets a destination and, if it is far enough away, a waypoint off to one side,
## so the walk is a curve of this elf's own rather than the straight line
## everybody else takes.
func _head_for(e: Elf, at: Vector3, face := Vector3.ZERO) -> void:
	e.target = at
	e.face_at = face
	e.has_waypoint = false

	var away := _gap(e.at, at)
	if away < 1.1 or absf(e.route_bias) < 0.08:
		return

	var along := _flat(at - e.at)
	var side := Vector3(-along.z, 0.0, along.x)
	e.waypoint = _ashore((e.at + at) * 0.5 + side * e.route_bias * away * 0.30)
	e.has_waypoint = true


## Pointing at where you are about to go, before you go. Coordination you can
## watch is worth far more than coordination that merely happens correctly, and
## this is the cheapest legible piece of it there is.
func _point(e: Elf, at: Vector3) -> void:
	if randf() > 0.45:
		return
	e.point_at = at
	e.point_left = randf_range(0.5, 1.1)


func _somewhere_own(e: Elf) -> Vector3:
	if e.sociable > 0.15 and _elves.size() > 1:
		var other: Elf = _elves[randi() % _elves.size()]
		if other.id != e.id:
			return _clear_of_piles(_off(other.at, randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)))
	return _clear_of_piles(_off(e.at, randf_range(-2.2, 2.2), randf_range(-1.8, 1.8)))


func _pastime_spot(game: String) -> Vector3:
	match game:
		"fish", "swim":
			var a := randf() * TAU
			return _ashore(_off(_spot("pool"), cos(a) * 1.15, sin(a) * 1.0))
		"shade":
			return _off(_spot("grove"), randf_range(-1.0, 1.0), randf_range(-0.8, 0.8))
	return _off(_spot("hearth"), randf_range(-0.7, 0.7), randf_range(-0.6, 0.6))


func _pastime_face(game: String) -> Vector3:
	match game:
		"fish", "swim":
			return _spot("pool")
	return _spot("hearth")


# --- the body ----------------------------------------------------------------

func _tick_elf(e: Elf, delta: float) -> void:
	if e.grown < 1.0:
		e.grown = minf(e.grown + delta / 1.4, 1.0)
	e.rig.scale = Vector3.ONE * (0.2 + 0.8 * e.grown)

	_observe(e)

	if e.startle_left > 0.0:
		_tick_startle(e, delta)
		return

	if e.task == Task.NONE:
		_decide(e)

	if e.hesitate_left > 0.0:
		_tick_hesitate(e, delta)
		return

	var aim := e.waypoint if e.has_waypoint else e.target
	var gap := _gap(e.at, aim)

	if e.has_waypoint and gap < 0.30:
		e.has_waypoint = false
		aim = e.target
		gap = _gap(e.at, aim)

	var arrived := (not e.has_waypoint) and gap < 0.14
	e.moving = not arrived

	if e.stop_left > 0.0:
		_tick_stop_look(e, delta)
		return

	# Something just happened within noticing range while this one had
	# somewhere else to be. Not everybody looks up - see `rubberneck` - and a
	# fresh event only gets one frame's chance to catch a passer-by, so the
	# same landing does not stop half the island in a row.
	if not arrived and e.startle_left <= 0.0 and e.hesitate_left <= 0.0:
		for i in range(_events.size() - 1, -1, -1):
			var ev: Dictionary = _events[i]
			if _time - ev["when"] > delta * 1.5:
				break
			var d := _gap(e.at, ev["at"])
			if d > 3.2 or d < 0.3:
				continue
			if randf() > e.rubberneck * 0.55:
				continue
			e.stop_left = randf_range(0.4, 0.7)
			e.stop_at = ev["at"]
			_tick_stop_look(e, delta)
			return

	if not arrived:
		var heading := _flat(aim - e.at)

		# Keep out of each other's way. Without this they walk through one
		# another and converge into single file across the middle of the island.
		var push := Vector3.ZERO
		for other in _elves:
			if other.id == e.id:
				continue
			var d := _gap(e.at, other.at)
			if d > 0.001 and d < 0.34:
				push += _flat(e.at - other.at) * (0.34 - d) / 0.34
				# Being cut up costs a little goodwill, and being cut up by the
				# same elf repeatedly costs a lot.
				_like(e, other, -delta * 0.05)
		if push.length() > 0.001:
			var bent := _flat(heading + push * 1.15)
			if bent != Vector3.ZERO:
				heading = bent

		# Constant velocity in a straight line is one of the strongest signs of
		# a lookup table there is, so pace is a target eased toward rather than
		# a number applied directly. Slower carrying stone or iron than reed or
		# cloth, slower going uphill and quicker going down since the gradient
		# is free, and quicker still when the site is waiting on what is in
		# the hands right now.
		var target := lerpf(0.84, 1.14, _mood01(e))

		if e.carrying != null and e.carry_kind >= 0 \
				and e.carry_kind < CARRY_DRAG.size():
			target *= lerpf(1.0, 0.55, CARRY_DRAG[e.carry_kind])

		var grade := _ground(e.at + heading * 0.5) - _ground(e.at)
		target *= clampf(1.0 - grade * 2.4, 0.55, 1.35)

		if e.carrying != null and e.task == Task.DELIVER \
				and int(e.site_needs.get(e.carry_kind, 0)) > 0:
			target *= 1.18
		elif e.task == Task.LOOK or e.task == Task.OWN:
			target *= 0.85

		# Accelerate from rest and decelerate into arrival, both over about
		# half a second.
		e.walk_speed = lerpf(e.walk_speed, target, clampf(delta / 0.5, 0.0, 1.0))
		var braking := clampf(gap / (e.pace * 0.5 + 0.05), 0.25, 1.0)

		var step: float = minf(delta * e.pace * e.walk_speed * braking, gap)
		e.at += heading * step
		_tread(e, step)
		e.facing = _flat(e.facing.lerp(heading, clampf(delta * e.turn_rate, 0.0, 1.0)))
		_maybe_hand_over(e)
	else:
		e.walk_speed = 0.0
		if e.face_at != Vector3.ZERO:
			var want := _flat(e.face_at - e.at)
			if want != Vector3.ZERO:
				e.facing = _flat(e.facing.lerp(want, clampf(delta * e.turn_rate, 0.0, 1.0)))
		_act(e, delta)

	if e.facing == Vector3.ZERO:
		e.facing = Vector3.FORWARD

	e.point_left = maxf(0.0, e.point_left - delta)

	# Standing near somebody for a while is how anybody comes to like anybody.
	if not e.moving:
		for other in _elves:
			if other.id != e.id and not other.moving and _gap(e.at, other.at) < 1.0:
				_like(e, other, delta * 0.02)

	_place(e)
	_animate(e, delta, not arrived)
	_gaze(e, delta)

	# Feeling settles back toward level on its own. Nothing stays cheerful or
	# sour for longer than the thing that caused it deserves.
	e.mood = lerpf(e.mood, 0.0, clampf(delta * 0.035, 0.0, 1.0))

	if e.task == Task.REST and arrived:
		e.energy = minf(1.0, e.energy + delta * 0.10)
		_cheer(e, delta * 0.05)
	elif e.task == Task.PLAY and arrived:
		e.energy = minf(1.0, e.energy + delta * 0.03)
		_cheer(e, delta * 0.09)
	elif e.work_left > 0.0:
		e.energy = maxf(0.0, e.energy - delta * 0.016)
	else:
		e.energy = maxf(0.0, e.energy - delta * 0.005)


## Dead stop, mid-stride if it has to be. The head snaps onto whatever just
## surprised it faster than the ordinary gaze snap, the body takes a beat of
## stillness with a small recoil-and-drop or lean-and-lift depending on
## whether the news was good, and then it goes back to deciding with the
## fresher picture it just this second acquired.
func _tick_startle(e: Elf, delta: float) -> void:
	e.moving = false
	e.startle_left -= delta

	var want := _flat(e.startle_at - e.at)
	if want != Vector3.ZERO:
		e.facing = _flat(e.facing.lerp(want, clampf(delta * 20.0, 0.0, 1.0)))

	e.look_at = e.startle_at
	e.look_left = 0.3

	_place(e)
	_animate(e, delta, false)
	_gaze(e, delta, true)

	if e.startle_left <= 0.0:
		# Re-decide now, with what it just found out, rather than finishing
		# whatever it was in the middle of when the belief turned over.
		e.task = Task.NONE
		e.pause = 0.0


## The already-made decision, visibly weighed one more time before the body
## commits to it. Looks mostly at where it is about to go, occasionally at
## the option that nearly won instead, and departs the moment the hold runs
## out - the target and waypoint were set by `_decide` already, so nothing
## else has to happen when it does.
func _tick_hesitate(e: Elf, delta: float) -> void:
	e.moving = false
	e.hesitate_left -= delta

	var glancing := e.rejected \
		and fposmod(_time * 1.1 + float(e.seed_value), 2.2) < 0.45
	var look_target := e.rejected_at if glancing else e.hesitate_at
	e.look_at = look_target
	e.look_left = 0.25

	if glancing:
		e.point_at = e.rejected_at
		e.point_left = 0.3
	elif e.point_left <= 0.0:
		_point(e, e.hesitate_at)

	var want := _flat(e.hesitate_at - e.at)
	if want != Vector3.ZERO:
		e.facing = _flat(e.facing.lerp(want, clampf(delta * 3.0, 0.0, 1.0)))

	_place(e)
	_animate(e, delta, false)
	_gaze(e, delta, true)

	if e.hesitate_left <= 0.0:
		e.rejected = false


## A beat of stillness for something that happened off to the side while this
## one had somewhere else to be. Movement resumes on its own once `stop_left`
## runs out - the target and waypoint never changed.
func _tick_stop_look(e: Elf, delta: float) -> void:
	e.moving = false
	e.stop_left -= delta

	e.look_at = e.stop_at
	e.look_left = 0.2

	var want := _flat(e.stop_at - e.at)
	if want != Vector3.ZERO:
		e.facing = _flat(e.facing.lerp(want, clampf(delta * 6.0, 0.0, 1.0)))

	_place(e)
	_animate(e, delta, false)
	_gaze(e, delta, true)


func _place(e: Elf) -> void:
	e.node.position = _on(e.at)
	e.node.rotation.y = atan2(e.facing.x, e.facing.z)


## Two elves meeting on a path, one loaded and one not, and the load changing
## hands. It saves nobody any real time and that is fine - the point is that a
## viewer can watch two of them cooperate rather than infer it from a graph.
func _maybe_hand_over(e: Elf) -> void:
	if e.carrying == null or _time - e.handed < 25.0:
		return
	if e.task != Task.DELIVER and e.task != Task.HAUL:
		return

	for other in _elves:
		if other.id == e.id or other.carrying != null:
			continue
		if other.task != Task.IDLE and other.task != Task.LOOK:
			continue
		if _gap(e.at, other.at) > 0.42:
			continue
		if _gap(other.at, e.target) > _gap(e.at, e.target) - 0.7:
			continue

		var item := e.carrying
		e.grip.remove_child(item)
		other.grip.add_child(item)
		item.position = Vector3(0, -0.03, 0.0)

		other.carrying = item
		other.carry_kind = e.carry_kind
		other.carry_count = e.carry_count
		other.task = e.task
		other.work = e.work
		other.to_pile = e.to_pile
		other.want_kind = e.want_kind
		other.handed = _time
		if other.task == Task.DELIVER:
			_head_for(other, _stand_near(other, _site_stand(other)), other.work.at)
		else:
			_head_for(other, _stand_near(other, other.to_pile.stand), other.to_pile.at)

		e.carrying = null
		e.carry_count = 0
		e.handed = _time
		_like(e, other, 0.10)
		_like(other, e, 0.10)
		_cheer(e, 0.05)
		_cheer(other, 0.05)
		_note(e.node.global_position)
		_finish(e)
		return


## Whoever is holding the thing this one just arrived too late for.
func _find_carrier(e: Elf, kind: int) -> Elf:
	var best: Elf = null
	var closest := 4.5
	for o in _elves:
		if o.id == e.id or o.carrying == null or o.carry_kind != kind:
			continue
		var d := _gap(e.at, o.at)
		if d < closest:
			closest = d
			best = o
	return best


## The empty heap, then whoever got there first, then away. Three beats
## rather than one so losing reads as something noticed rather than the walk
## simply ending.
func _tick_lose(e: Elf, delta: float) -> void:
	e.lose_left -= delta

	if e.lose_phase == 0 and e.lose_left < 0.95:
		e.lose_phase = 1 if e.lose_has_winner else 2
	elif e.lose_phase == 1 and e.lose_left < 0.40:
		e.lose_phase = 2

	var target := e.lose_empty
	if e.lose_phase == 1:
		target = e.lose_winner

	e.look_at = target
	e.look_left = 0.2

	if e.lose_phase < 2:
		var want := _flat(target - e.at)
		if want != Vector3.ZERO:
			e.facing = _flat(e.facing.lerp(want, clampf(delta * 5.0, 0.0, 1.0)))

	_animate(e, delta, false)
	_gaze(e, delta, true)

	if e.lose_left <= 0.0:
		_finish(e)


## Two figures facing the same way are scenery; two figures facing each other
## are talking, even in silence. No speech, no bubbles, no names - orientation
## and a small alternating glance do the whole job.
func _address(e: Elf, delta: float) -> void:
	var other: Elf = null
	var closest := 1.3
	for o in _elves:
		if o.id == e.id or o.moving or o.task != Task.IDLE:
			continue
		var d := _gap(e.at, o.at)
		if d < closest:
			closest = d
			other = o
	if other == null:
		return

	var want := _flat(other.at - e.at)
	if want != Vector3.ZERO:
		e.facing = _flat(e.facing.lerp(want, clampf(delta * 2.2, 0.0, 1.0)))

	var jitter := sin(_time * 1.7 + e.phase) * 0.05
	e.look_at = _on(other.at) + Vector3(jitter, 0.34, 0.0)
	e.look_left = randf_range(0.5, 1.1)


func _act(e: Elf, delta: float) -> void:
	if e.lose_left > 0.0:
		_tick_lose(e, delta)
		return

	# Downed tools. Work in progress is held rather than lost, so putting the
	# phone down for a second does not cost the last four minutes of a chop.
	if _rattled > 0.35 and e.task != Task.REST and e.task != Task.IDLE:
		return

	match e.task:
		Task.REST:
			if e.energy > 0.92:
				_finish(e)

		Task.IDLE, Task.OWN, Task.PLAY:
			if e.task == Task.OWN:
				e.haunted = _time
			if e.task == Task.PLAY:
				_play(e, delta)
			if e.task == Task.IDLE:
				_address(e, delta)
			e.pause -= delta
			if e.pause <= 0.0:
				_finish(e)

		Task.LOOK:
			# Standing and taking it in. _observe has already corrected whatever
			# it thought was here, so the pause is the moment you can watch it
			# change its mind.
			if e.pause <= 0.0:
				e.pause = randf_range(0.9, 1.8)
			e.pause -= delta
			if e.pause <= 0.0:
				_finish(e)

		Task.HAUL, Task.DELIVER:
			if e.carrying == null:
				if e.from_pile.of(e.want_kind) == 0:
					# Walked all this way for nothing. It knows better now, and
					# if somebody else got there first, that is worth a look
					# rather than a silent about-face.
					_cheer(e, -0.16)
					var winner := _find_carrier(e, e.want_kind)
					e.lose_empty = e.from_pile.at
					e.lose_has_winner = winner != null
					if winner != null:
						e.lose_winner = winner.node.global_position
					e.lose_phase = 0
					e.lose_left = 1.4
					return
				# Never lift more than the far end can actually use, so a
				# troll's three units cannot overshoot a work's need or flood
				# a mill's small input pile.
				var cap := -1
				if e.task == Task.DELIVER:
					cap = e.work.needs(e.want_kind)
				elif e.task == Task.HAUL:
					cap = maxi(1, e.to_pile.limit - e.to_pile.count())
				_lift(e, e.from_pile, e.want_kind, cap)
				if e.task == Task.HAUL:
					_head_for(e, _stand_near(e, e.to_pile.stand), e.to_pile.at)
				else:
					_head_for(e, _stand_near(e, _site_stand(e)), e.work.at)
				return

			if e.task == Task.HAUL:
				_drop(e, e.to_pile)
				return

			if e.work.done or e.work.needs(e.carry_kind) <= 0:
				# Carried it all the way up here to find it already paid for.
				# Take it back rather than deleting it, which would quietly leak
				# stock off the island.
				_cheer(e, -0.20)
				var home := _home_for(e.carry_kind)
				if home == null:
					_finish(e)
					return
				e.task = Task.HAUL
				e.to_pile = home
				e.work = null
				_head_for(e, _stand_near(e, home.stand), home.at)
				return

			_deliver(e)

		Task.FIT:
			var w := e.work
			if w == null or w.done or not w.ready():
				_finish(e)
				return
			if e.work_left <= 0.0:
				e.work_left = float(w.spec["fit"]) * randf_range(0.85, 1.2)
				if e.tool == null:
					_take_tool(e, "hammer")
					e.motion = "swing"
			e.work_left -= delta * lerpf(0.7, 1.25, e.energy)
			if e.work_left <= 0.0:
				_finish_work(w, e)
				_finish(e)

		Task.GATHER, Task.CRAFT:
			var st := e.station
			if st == null or st.out_pile == null or not st.out_pile.room():
				_finish(e)
				return
			if not st.is_source():
				var fed := true
				for k in st.inputs:
					if st.in_pile.of(int(k)) < int(st.inputs[k]):
						fed = false
						break
				if not fed:
					_cheer(e, -0.12)
					_finish(e)
					return

			if e.work_left <= 0.0:
				e.work_left = st.seconds * randf_range(0.85, 1.2) \
					* float(_pace.get(st.out_kind, 1.0))
			if e.tool == null:
				_take_tool(e, st.tool)
				e.motion = st.motion

			e.work_left -= delta * lerpf(0.6, 1.25, e.energy)
			if e.work_left <= 0.0:
				_produce(e, st)


func _home_for(kind: int, not_this: Pile = null) -> Pile:
	for st in _stations:
		if st.out_kind == kind and st.out_pile and st.out_pile != not_this \
				and st.out_pile.takes_more(kind):
			return st.out_pile
	for p in _piles:
		if p != not_this and p.takes(kind) and p.takes_more(kind):
			return p
	return null


## One thing made. A new object goes onto the heap, so the heap either side of a
## job actually moves.
func _produce(e: Elf, st: Station) -> void:
	if not st.is_source():
		for k in st.inputs:
			for _i in int(st.inputs[k]):
				var used := st.in_pile.take(int(k))
				if used:
					st.in_pile.node.remove_child(used)
					used.queue_free()
		st.in_pile.settle()

	if st.out_pile.room():
		var made := _make_item(st.out_kind)
		st.out_pile.node.add_child(made)
		st.out_pile.items.append(made)
		st.out_pile.settle()
		_note(st.out_pile.node.global_position)

	e.work_left = 0.0
	_cheer(e, 0.10)
	_reward(e, e.task, 0.05)
	_dirty = true

	# Diligence decides whether they stay on it or wander off after one.
	if randf() > e.stamina * 0.78:
		_finish(e)


## Lifts up to `e.carry_limit` units of `kind`, capped further by `cap` if
## given. A hobbit's holder ends up with exactly one item at exactly the
## position a single carried item always sat at, so nothing about a hobbit's
## carry changes; a troll's holds up to three, side by side, which is the
## mechanical half of the two species being different rather than a costume
## swap.
func _lift(e: Elf, pile: Pile, kind: int, cap := -1) -> void:
	var take_n := maxi(1, e.carry_limit)
	if cap >= 0:
		take_n = mini(take_n, maxi(1, cap))

	var held: Array[Node3D] = []
	for _i in take_n:
		var item := pile.take(kind)
		if item == null:
			break
		pile.node.remove_child(item)
		held.append(item)

	if held.is_empty():
		_finish(e)
		return
	pile.settle()

	var holder := Node3D.new()
	e.grip.add_child(holder)
	holder.position = Vector3(0, -0.03, 0.0)
	for i in held.size():
		holder.add_child(held[i])
		held[i].position = Vector3((float(i) - float(held.size() - 1) * 0.5) * 0.065, 0.0, 0.0)

	e.carrying = holder
	e.carry_kind = kind
	e.carry_count = held.size()
	_note(e.node.global_position)


func _drop(e: Elf, pile: Pile) -> void:
	# Arrived to find there is no room for it. This is the commonest way an elf
	# turns out to have been wrong, so it has to end in something rather than in
	# standing there holding a rock: take it somewhere that will have it.
	#
	# "No room" means no room for everything in hand, not just the first unit
	# of it - a troll holding three has to find somewhere that takes three, or
	# a heap at eleven of twelve takes its whole load and sits at fourteen.
	var room_left := maxi(0, pile.limit - pile.items.size())
	if not pile.takes_more(e.carry_kind) or room_left < e.carry_count:
		_cheer(e, -0.14)
		var other := _home_for(e.carry_kind, pile)
		if other:
			e.to_pile = other
			_head_for(e, _stand_near(e, other.stand), other.at)
			return
		# Nowhere on the island wants it. Set it down where it stands rather
		# than deleting it, which would quietly leak stock off the island.
		var loose := e.carrying
		e.grip.remove_child(loose)
		add_child(loose)
		loose.position = _on(_off(e.at, randf_range(-0.2, 0.2),
			randf_range(-0.2, 0.2))) + Vector3(0, 0.05, 0)
		e.carrying = null
		e.carry_count = 0
		_finish(e)
		return

	var holder := e.carrying
	e.grip.remove_child(holder)
	for child in holder.get_children():
		holder.remove_child(child)
		pile.node.add_child(child)
		pile.items.append(child)
	holder.queue_free()
	pile.settle()
	_note(pile.node.global_position)

	e.carrying = null
	e.carry_count = 0
	_cheer(e, 0.07)
	_reward(e, Task.HAUL, 0.04)
	_dirty = true
	_finish(e)


func _deliver(e: Elf) -> void:
	var w := e.work
	var holder := e.carrying
	e.grip.remove_child(holder)
	holder.queue_free()
	e.carrying = null

	w.delivered[e.carry_kind] = int(w.delivered.get(e.carry_kind, 0)) + e.carry_count
	e.carry_count = 0

	# The work has no node until it is finished, so the thing to look at is the
	# ground it is going on rather than the piece that is not there yet.
	_note(_on(w.at) + Vector3(0, 0.4, 0))
	_cheer(e, 0.09)
	_reward(e, Task.DELIVER, 0.05)
	_dirty = true
	_finish(e)


# --- the project -------------------------------------------------------------

func _build_works() -> void:
	for spec in Plan.works():
		var w := Work.new()
		w.spec = spec
		w.index = int(spec["index"])
		w.at = _spot(str(spec["place"]))
		_works.append(w)


## The works that can be worked on right now: the first few unfinished ones, in
## order. Order is the entire tech tree - a crane simply sits in the queue at the
## point it becomes necessary, so nothing needs an unlock table and nothing can
## deadlock.
func _open() -> Array[Work]:
	var out: Array[Work] = []
	for w in _works:
		if w.done:
			continue
		out.append(w)
		if out.size() >= OPEN_WORKS:
			break
	return out


func _finish_work(w: Work, e: Elf = null) -> void:
	w.done = true
	w.holder = _raise(w)
	if e:
		_cheer(e, 0.24)
		_reward(e, Task.FIT, 0.07)
		for other in _elves:
			if other.id != e.id and _gap(e.at, other.at) < 1.6:
				_cheer(other, 0.10)
	_note(w.holder.global_position if w.holder else _on(w.at))

	if w.spec.has("makes"):
		_open_station(w)

	_dirty = true
	_save()


## Puts the geometry in the world.
func _raise(w: Work) -> Node3D:
	var place := str(w.spec["place"])
	if not _anchors.has(place):
		_anchors[place] = _anchor(_spot(place))
	var parent: Node3D = _anchors[place]

	var holder := Node3D.new()
	for part in w.spec["parts"]:
		holder.add_child(_part(part))
	parent.add_child(holder)
	return holder


func _part(part: Dictionary) -> Node3D:
	var node := MeshInstance3D.new()
	var size: Vector3 = part["size"]
	var mat_name := str(part["mat"])

	match str(part["shape"]):
		"box":
			var box := BoxMesh.new()
			box.size = size
			node.mesh = box
		"log":
			var cyl := CylinderMesh.new()
			cyl.top_radius = size.x
			cyl.bottom_radius = size.x * 1.04
			cyl.height = size.y
			cyl.radial_segments = 7
			cyl.rings = 1
			node.mesh = cyl
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = size.x * 0.25
			cone.bottom_radius = size.x
			cone.height = size.y
			cone.radial_segments = 8
			cone.rings = 1
			node.mesh = cone
		"stone":
			node.mesh = Geometry.crystal(1.0, 0.22)
			node.scale = size
		"glow":
			var ball := SphereMesh.new()
			ball.radius = size.x
			ball.height = size.x * 2.0
			ball.radial_segments = 7
			ball.rings = 4
			node.mesh = ball

	node.material_override = _mats.get(mat_name, _mats["lumber"])
	node.position = part["pos"]
	node.rotation = part.get("rot", Vector3.ZERO)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## A finished mill starts turning one thing into another, with a heap either
## side of it.
func _open_station(w: Work) -> void:
	var makes: Dictionary = w.spec["makes"]
	var st := Station.new()
	st.id = str(w.spec["id"])
	st.out_kind = int(makes["out"])
	st.inputs = makes["in"]
	st.seconds = float(makes["seconds"])
	st.motion = str(makes["motion"])
	st.tool = str(makes["tool"])

	var at := w.at
	st.stand = _off(at, 0.0, 0.46)
	st.face = at

	var takes: Array[int] = []
	for k in st.inputs:
		takes.append(int(k))
	st.in_pile = _make_pile(takes, _off(at, -0.62, 0.20), _off(at, -0.62, 0.55))
	st.in_pile.limit = 12
	for k in st.inputs:
		st.in_pile.caps[int(k)] = int(st.inputs[k]) * 4
	st.out_pile = _make_pile([st.out_kind], _off(at, 0.62, 0.20),
		_off(at, 0.62, 0.55))
	st.out_pile.limit = 10
	_stations.append(st)


# --- restoring ---------------------------------------------------------------

func _restore() -> void:
	var state := Progress.read(_island)
	_focus = float(state["focus"])
	_cycle = float(state["cycle"])
	_rest_left = float(state["rest"])
	_residents = state["seeds"]
	_resident_affinity = state["affinity"]

	# Everything finished on a previous day goes up instantly and in silence.
	# Opening an island on the fourth morning should show you the fourth morning,
	# not a time-lapse of the first three.
	var done: PackedInt32Array = state["done"]
	for i in done:
		var index := int(i)
		if index < 0 or index >= _works.size():
			continue
		var w := _works[index]
		w.done = true
		w.holder = _raise(w)
		if w.spec.has("makes"):
			_open_station(w)

	# Materials come back as a total rather than heap by heap. Where things are
	# is cheap to rediscover and expensive to store, and an elf's ignorance about
	# it should not survive a restart anyway.
	var stock: PackedInt32Array = state["stock"]
	for k in mini(stock.size(), Plan.KIND_COUNT):
		var home := _home_for(k)
		for _n in int(stock[k]):
			if home == null or not home.room():
				home = _home_for(k)
			if home == null or not home.room():
				break
			var item := _make_item(k)
			home.node.add_child(item)
			home.items.append(item)
		if home:
			home.settle()

	_build_house_light()


func _state() -> Dictionary:
	var done := PackedInt32Array()
	for w in _works:
		if w.done:
			done.append(w.index)

	var stock := PackedInt32Array()
	stock.resize(Plan.KIND_COUNT)
	for p in _piles:
		for it in p.items:
			var k := int(it.get_meta("kind"))
			stock[k] = stock[k] + 1

	return {
		"done": done, "stock": stock, "focus": _focus,
		"cycle": _cycle, "rest": _rest_left,
		"seeds": _residents, "affinity": _resident_affinity,
		"wear": _wear.to_text(),
	}


func _save() -> void:
	Progress.write(_island, _state())
	Progress.flush()
	_since_save = 0.0
	_dirty = false


## Called by the shell when the app goes away, which is the one moment losing
## the last twenty seconds would actually be felt.
func persist() -> void:
	_save()


## Test hook. Drops straight into a break at a given point through it, so a
## quarter of an hour of resting can be looked at without first spending an hour
## earning it.
func force_rest(at: float) -> void:
	_down_tools()
	_rest_left = REST_PERIOD * (1.0 - clampf(at, 0.0, 1.0))
	_rest_note = 0.0


## Shown for the first few seconds of a break and then never again. The elves
## lying down explain the rest of it.
func rest_hint() -> float:
	return clampf(_rest_note / 6.0, 0.0, 1.0)


func fraction() -> float:
	var n := 0
	for w in _works:
		if w.done:
			n += 1
	return clampf(float(n) / maxf(float(_works.size()), 1.0), 0.0, 1.0)


# --- tools and animation -----------------------------------------------------

## A tool in the hand, and something to swing it at. Without both, the arm motion
## is a body moving on its own, which reads badly however the numbers are tuned.
## The fix is the prop, not the curve.
func _take_tool(e: Elf, kind: String) -> void:
	var tool := Node3D.new()
	var iron: Material = _mats["iron"]
	var handle: Material = _mats["timber"]

	var short := kind in ["sickle", "hammer", "rod"]
	var haft := MeshInstance3D.new()
	var rod := CapsuleMesh.new()
	rod.radius = 0.016
	rod.height = 0.15 if short else 0.24
	rod.radial_segments = 7
	rod.rings = 2
	haft.mesh = rod
	haft.position = Vector3(0, -0.085 if short else -0.125, 0)
	haft.material_override = handle
	haft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tool.add_child(haft)

	match kind:
		"pick":
			# A spike one way, a short chisel the other, both canted down off the
			# eye so the point leads into the rock. The head is small against the
			# haft on purpose: at a bigger ratio the silhouette is a horizontal
			# spike and the elf reads as presenting a rifle at every phase.
			tool.add_child(_bit(BoxMesh.new(), Vector3(0.044, 0.044, 0.040),
				Vector3(0, -0.250, 0), Vector3.ZERO, iron))
			var point := CylinderMesh.new()
			point.top_radius = 0.002
			point.bottom_radius = 0.019
			point.height = 0.088
			point.radial_segments = 6
			point.rings = 1
			tool.add_child(_bit(point, Vector3.ONE, Vector3(0.050, -0.262, 0),
				Vector3(0, 0, -PI * 0.5 - 0.30), iron))
			tool.add_child(_bit(BoxMesh.new(), Vector3(0.052, 0.028, 0.036),
				Vector3(-0.040, -0.258, 0), Vector3(0, 0, -0.22), iron))
		"axe":
			var blade := CylinderMesh.new()
			blade.top_radius = 0.075
			blade.bottom_radius = 0.030
			blade.height = 0.090
			blade.radial_segments = 4
			blade.rings = 1
			var bit := _bit(blade, Vector3.ONE, Vector3(0.058, -0.248, 0),
				Vector3(0, PI * 0.25, -PI * 0.5), iron)
			bit.scale = Vector3(1.0, 1.0, 0.38)
			tool.add_child(bit)
			tool.add_child(_bit(BoxMesh.new(), Vector3(0.052, 0.052, 0.040),
				Vector3(-0.012, -0.248, 0), Vector3.ZERO, iron))
		"sickle":
			var hook := MeshInstance3D.new()
			var arc := PackedVector3Array()
			for i in 7:
				var a: float = -0.55 + float(i) * 0.38
				arc.append(Vector3(sin(a) * 0.095, -0.150 - cos(a) * 0.095, 0))
			hook.mesh = Geometry.tube(arc, 0.016, 0.005, 4, false)
			hook.material_override = iron
			hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tool.add_child(hook)
		"shovel":
			tool.add_child(_bit(BoxMesh.new(), Vector3(0.085, 0.10, 0.012),
				Vector3(0, -0.290, 0.012), Vector3(0.22, 0, 0), iron))
		"saw":
			tool.add_child(_bit(BoxMesh.new(), Vector3(0.026, 0.19, 0.004),
				Vector3(0.02, -0.230, 0), Vector3(0, 0, -0.35), iron))
		"rod":
			var line := MeshInstance3D.new()
			var pole := CylinderMesh.new()
			pole.top_radius = 0.003
			pole.bottom_radius = 0.010
			pole.height = 0.42
			pole.radial_segments = 5
			pole.rings = 1
			line.mesh = pole
			line.position = Vector3(0, -0.20, 0)
			line.material_override = handle
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tool.add_child(line)
		"bellows":
			# Nothing in the hands. A bellows or a press is worked by leaning on
			# a lever that belongs to the machine, not to the elf.
			tool.queue_free()
			e.tool = null
			e.tool_kind = kind
			return
		_:
			tool.add_child(_bit(BoxMesh.new(), Vector3(0.044, 0.052, 0.044),
				Vector3(0, -0.250, 0), Vector3.ZERO, iron))

	e.grip.add_child(tool)
	e.tool = tool
	e.tool_kind = kind


func _bit(mesh: Mesh, size: Vector3, at: Vector3, rot: Vector3,
		mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	node.mesh = mesh
	node.position = at
	node.rotation = rot
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


func _drop_tool(e: Elf) -> void:
	if e.tool:
		e.tool.queue_free()
	e.tool = null
	e.tool_kind = ""


func _finish(e: Elf) -> void:
	_drop_tool(e)
	if e.station and e.station.taken_by == e.id:
		e.station.taken_by = -1
	if e.work and e.work.taken_by == e.id:
		e.work.taken_by = -1
	e.last_task = e.task
	e.task = Task.NONE
	e.station = null
	e.work = null
	e.work_left = 0.0
	e.pause = 0.0
	e.face_at = Vector3.ZERO
	e.pastime = ""


## Their own time. Not decoration and not filler: an island where nobody ever
## stops working is a factory, and the difference between a workforce and a
## village is that somebody in a village is always fishing.
func _play(e: Elf, delta: float) -> void:
	match e.pastime:
		"fish":
			if e.tool == null:
				_take_tool(e, "rod")
			# Every so often something takes it, and they haul back.
			if randf() < delta * 0.08:
				_cheer(e, 0.25)
				_note(e.node.global_position)
		"swim":
			e.rig.position.y = -0.14 + sin(_time * 1.6 + e.phase) * 0.012


func _animate(e: Elf, delta: float, walking_now: bool) -> void:
	var m := _mood01(e)
	# The stride amplitude follows the same eased speed the feet actually move
	# at, so a walk that is still accelerating out of a stop shows short steps
	# rather than full-length ones starting from nothing.
	var walking := e.walk_speed if walking_now else 0.0
	var swing_scale := lerpf(0.68, 1.12, m) * e.stride_amp
	var stride := sin(_time * 3.0 * e.gait * (e.pace / 0.42) + e.phase) \
		* 0.5 * walking * swing_scale

	# A low elf stands folded in on itself and a pleased one stands up. Two of
	# them doing nothing at all should still be telling you something.
	var posture := lerpf(0.16, -0.05, m)
	if e.species == Species.TROLL:
		# A permanent hunch, on top of whatever mood is doing.
		posture += 0.16
	var twist := 0.0
	var braced := false

	# Where the hands are, as one point in the rig's own space.
	#
	# Everything two-handed is driven by moving this and then pointing both arms
	# at it, rather than by posing the shoulders. Posing the shoulders is what
	# produced a swing that read as a stick rotating: these arms are one rigid
	# segment with no elbow, so a shoulder turned through three radians is a pole
	# going round, and no amount of retiming rescues it.
	var grip_at := Vector3(0, 0.215, 0.115)
	var grip_dir := Vector3(0.10, -0.94, 0.32)
	var hands := false

	var arm_a := stride
	var arm_b := -stride

	if e.point_left > 0.0:
		# An arm out at where it is about to go. Held for under a second, which
		# is what pointing is.
		var to := e.node.to_local(_on(e.point_at) + Vector3(0, 0.3, 0)).normalized()
		arm_a = -1.15
		arm_b = -stride * 0.4
		_aim_arm(e, 0, Vector3(0.10, 0.26, 0.0) + to * 0.22,
			clampf(delta * 16.0, 0.0, 1.0))
		posture -= 0.04
	elif e.carrying:
		grip_at = Vector3(0, 0.225, 0.185)
		grip_dir = Vector3(0, -0.35, 0.94)
		hands = true
		posture += 0.06
	elif not walking_now and e.work_left > 0.0 and _rattled < 0.35:
		match e.motion:
			"sweep":
				# A scythe or a shovel is a sweep, not a blow: bent over, the
				# blade through low and level, the turn coming from the waist.
				var sweep := sin(_time * 1.4 + e.phase)
				grip_at = Vector3(sweep * 0.13, 0.175, 0.215)
				grip_dir = Vector3(sweep * 0.55, -0.42, 0.72)
				twist = sweep * 0.30
				posture += 0.30
				hands = true
				braced = true
			"press":
				# Leaning on a lever with both hands and letting weight do it.
				var push := (sin(_time * 1.9 + e.phase) * 0.5 + 0.5)
				grip_at = Vector3(0.02, lerpf(0.26, 0.15, push), 0.24)
				grip_dir = Vector3(0, -0.55, 0.84)
				posture += lerpf(0.10, 0.34, push)
				hands = true
				braced = true
			_:
				# A pick swing: the tool turns through the plane set out at the
				# top of this file, the hands hold station, and the body hinges
				# and unwinds underneath it. Slow cock, fast strike, then a beat
				# of stillness with the head in the work.
				var beat := fposmod(_time * (0.80 + e.pace * 0.5) + e.phase, 1.0)
				var up := 0.0
				if beat < 0.58:
					up = pow(beat / 0.58, 0.75)
				elif beat < 0.70:
					up = 1.0 - pow((beat - 0.58) / 0.12, 2.0)

				grip_at = STRIKE_GRIP.lerp(COCK_GRIP, up)
				grip_dir = _swing_dir(up)
				hands = true
				braced = true

				# The hinge is deliberately shallow. Since the rig pivots at the
				# feet rather than the hips, a deep one does not read as bending
				# to the work, it reads as toppling forward.
				posture += lerpf(0.14, -0.04, up)
				twist = lerpf(0.0, -0.26, up)
	elif e.task == Task.PLAY and e.pastime == "fish" and not walking_now:
		grip_at = Vector3(0.05, 0.20, 0.16)
		grip_dir = Vector3(0.18, -0.55, 0.82)
		hands = true
		posture += 0.04
	elif (e.task == Task.REST or (e.task == Task.PLAY
			and e.pastime in ["sit", "sleep", "away"])) and not walking_now:
		arm_a = 0.25
		arm_b = 0.25
		posture = 0.22
		if e.pastime == "sleep":
			arm_a = 0.10
			arm_b = 0.10
			posture = 0.0
	elif _rattled > 0.35 and not walking_now:
		# Stopped and looking up. Nobody carries on hammering while the ground
		# is moving.
		arm_a = -0.30
		arm_b = -0.24
		posture = -0.10
	elif e.task == Task.IDLE and not walking_now and e.lose_left <= 0.0:
		# One personal idle fidget, the same one every time this individual
		# stands still with nothing to do - the thing that makes it somebody
		# you would recognise across two different sessions rather than just
		# a body shape.
		var t := _time * 1.6 + e.fidget_phase
		match e.fidget_kind:
			0: # Adjusting a hat.
				var tug := clampf(sin(t) * 1.6, -1.0, 1.0)
				if tug > 0.2:
					arm_a = lerpf(arm_a, -1.05, tug)
					posture -= 0.02 * tug
			1: # Shifting weight, foot to foot.
				posture += sin(t * 0.6) * 0.05
				twist += sin(t * 0.6) * 0.06
			2: # Wiping hands.
				var wipe := clampf(sin(t * 1.3) * 1.4, -1.0, 1.0)
				if wipe > 0.15:
					arm_a = lerpf(arm_a, -0.55, wipe)
					arm_b = lerpf(arm_b, -0.55, wipe)
			3: # Scratching an ear.
				var scratch := clampf(sin(t * 0.9) * 1.8, -1.0, 1.0)
				if scratch > 0.35:
					arm_b = lerpf(arm_b, -1.25, scratch)

	# The double-take, laid on top of whatever pose was already chosen: a
	# recoil and drop for bad news, a lean in and lift for good, easing in
	# over the hold so it reads as a flinch rather than a snap to a new pose.
	if e.startle_left > 0.0:
		var into := 1.0 - clampf(e.startle_left / 1.2, 0.0, 1.0)
		if e.startle_good:
			posture -= into * 0.22
		else:
			posture += into * 0.32
			if not hands:
				arm_a += into * 0.30
				arm_b += into * 0.30

	var k := clampf(delta * 22.0, 0.0, 1.0)
	var slow := clampf(delta * 6.0, 0.0, 1.0)

	e.grip.position = e.grip.position.lerp(grip_at, k)
	e.grip.basis = Basis(e.grip.basis.get_rotation_quaternion().slerp(
		Quaternion(_hang(grip_dir.normalized())), k))

	if hands:
		# Two hands at two places along the haft, not both at the same point.
		# One near the end and one further up is what a grip looks like; both on
		# the same spot looks like the tool is stuck to them.
		var haft := -e.grip.basis.y
		_aim_arm(e, 0, e.grip.position + haft * 0.030, k)
		_aim_arm(e, 1, e.grip.position + haft * 0.090, k)
	elif e.point_left > 0.0:
		_pose_arm(e, 1, arm_b, k)
	else:
		_pose_arm(e, 0, arm_a, k)
		_pose_arm(e, 1, arm_b, k)

	# Feet planted and one foot back while working. Nobody swings a pick with
	# their heels together. The legs take the posture hinge back out: there is no
	# separate torso node, so leaning forward turns the whole elf about its
	# ankles, and without this the boots come off the ground.
	if braced:
		e.legs[0].rotation.x = lerpf(e.legs[0].rotation.x, -0.22 - posture, slow)
		e.legs[1].rotation.x = lerpf(e.legs[1].rotation.x, 0.14 - posture, slow)
	else:
		for l in e.legs.size():
			e.legs[l].rotation.x = -stride * (1.0 if l == 0 else -1.0)

	# Flat out.
	#
	# Sideways rather than on their back: the rig pivots at the feet, so a
	# quarter turn about Z lays an elf across the ground in profile with its
	# boots where it was standing, and a profile is the only view of a lying
	# figure that reads as asleep rather than as fallen over. Which side depends
	# on the elf, so a dozen of them round a fire are not a row of identical
	# dominoes.
	var down := 0.0
	if e.task == Task.PLAY and e.pastime == "sleep" and not walking_now:
		down = 1.46 * signf(e.route_bias if absf(e.route_bias) > 0.01 else 1.0)
		posture = 0.0
	e.rig.rotation.z = lerpf(e.rig.rotation.z, down, slow * 0.5)

	e.rig.rotation.x = lerpf(e.rig.rotation.x, posture, slow)
	e.rig.rotation.y = lerpf(e.rig.rotation.y, twist, slow)

	var bounce := absf(sin(_time * 3.0 + e.phase)) * 0.022 * walking * e.bounce_amt
	var breath := sin(_time * 1.1 + e.phase) * 0.006 * (1.0 - walking)
	var sit := 0.0
	if not walking_now and (e.task == Task.REST
			or (e.task == Task.PLAY and e.pastime in ["sit", "fish"])):
		sit = -0.055
	if e.task == Task.PLAY and e.pastime == "swim":
		sit = -0.14
	if e.task == Task.PLAY and e.pastime == "sleep" and not walking_now:
		# Lying on their side, the body is a capsule on its side, so the pivot
		# has to come up by about its radius or they sink into the ground.
		sit = 0.062
	e.rig.position.y = bounce + breath + sit


## The haft direction partway through a swing, 0 at the blow and 1 cocked.
func _swing_dir(t: float) -> Vector3:
	var a := lerpf(SWING_STRIKE, SWING_COCK, t)
	return _swing_plane * Vector3(0.0, -cos(a), sin(a))


## Points one arm at a spot given in the rig's space. The arm is a single rigid
## segment, so this is exact for direction and only approximate for length - the
## hand lands short or long by a centimetre or two, which at this size nobody can
## see. What it buys is both hands converging on the tool rather than each
## shoulder being posed by angle, which is the difference between holding
## something and waving.
func _aim_arm(e: Elf, i: int, rig_point: Vector3, k: float) -> void:
	var target := Vector3(rig_point.x / e.body_scale.x,
		rig_point.y / e.body_scale.y, rig_point.z / e.body_scale.z)
	var down := target - e.shoulders[i]
	var reach := down.length()
	if reach < 0.004:
		return
	down /= reach

	e.arms[i].quaternion = e.arms[i].quaternion.slerp(Quaternion(_hang(down)), k)
	e.arms[i].scale.y = lerpf(e.arms[i].scale.y, clampf(reach / ARM, 1.0, 1.18), k)


## A rotation whose -Y axis points along `down`. Both the arms and the tool are
## modelled hanging downward from their origin, so aiming either is the same
## question: which way is down for this thing right now.
func _hang(down: Vector3) -> Basis:
	var side := Vector3.RIGHT - down * down.dot(Vector3.RIGHT)
	if side.length() < 0.25:
		side = Vector3.FORWARD - down * down.dot(Vector3.FORWARD)
	side = side.normalized()
	var up := -down
	return Basis(side, up, side.cross(up))


func _pose_arm(e: Elf, i: int, pitch: float, k: float) -> void:
	e.arms[i].quaternion = e.arms[i].quaternion.slerp(
		Quaternion(Basis.from_euler(Vector3(pitch, 0.0, 0.0))), k)
	e.arms[i].scale.y = lerpf(e.arms[i].scale.y, 1.0, k)


## Where it is looking.
##
## Most of what a person reads as mind is where attention points, and it is
## cheap: one node, a priority list and a hold time. An elf that glances at a
## colleague going past without being told to is doing more for this than any
## amount of extra animation on the body.
func _gaze(e: Elf, delta: float, fast := false) -> void:
	e.look_left -= delta
	if e.look_left <= 0.0 and not fast:
		e.look_at = _pick_look(e)
		e.look_left = randf_range(1.0, 3.0) * lerpf(1.5, 0.75, _mood01(e))

	var local := e.node.to_local(e.look_at)
	var flat := Vector2(local.x, local.z).length()
	var swing := lerpf(0.7, 1.0, _mood01(e))
	var yaw := clampf(atan2(local.x, local.z), -1.15, 1.15) * swing
	var pitch := clampf(-atan2(local.y, maxf(flat, 0.02)), -0.50, 0.42)
	pitch += lerpf(0.20, -0.04, _mood01(e))

	# Eyes snap. Easing a head slowly onto a target is the single most reliable
	# way to make something look like a puppet. The double-take snaps faster
	# still - it is the one moment the head has to arrive before the viewer's
	# does.
	var k := clampf(delta / (0.06 if fast else 0.18), 0.0, 1.0)
	e.head.rotation.y = lerp_angle(e.head.rotation.y, yaw, k)
	e.head.rotation.x = lerpf(e.head.rotation.x, pitch, k)

	# The pupils lead the head rather than waiting for it, exactly the way a
	# real glance works: the eyes move first and the head catches up. A pair
	# of eyes that shift on their own, independent of the head turning, is
	# most of what reads as attention rather than a mounted camera swivelling.
	var pupil_k := clampf(delta * 11.0, 0.0, 1.0)
	for i in e.pupils.size():
		var p := e.pupils[i]
		var r: float = (p.get_parent() as MeshInstance3D).mesh.radius * 0.42
		var target := Vector3(sin(yaw) * r, sin(pitch) * r, p.position.z)
		p.position = p.position.lerp(target, pupil_k)


func _pick_look(e: Elf) -> Vector3:
	var here := e.node.global_position

	# Something just moved.
	for i in range(_events.size() - 1, -1, -1):
		var ev: Dictionary = _events[i]
		if _time - ev["when"] > 1.8:
			continue
		if here.distance_to(ev["at"]) < 3.2:
			return ev["at"]

	# Whoever is nearest and moving, and by preference somebody it likes.
	var watched: Elf = null
	var closest := 2.8
	for o in _elves:
		if o.id == e.id or not o.moving:
			continue
		var d := _gap(e.at, o.at) - float(e.bond.get(o.id, 0.0)) * 0.9
		if d < closest:
			closest = d
			watched = o
	if watched:
		return _on(watched.at) + Vector3(0, 0.36, 0)

	if e.moving:
		return _on(e.target) + Vector3(0, 0.30, 0)

	# The house, from anywhere it can be seen. They look at what they are for.
	if randf() < 0.42 and _gap(e.at, _spot("site")) < 8.0:
		return _on(_spot("site")) + Vector3(0, 0.7 + fraction() * 1.2, 0)

	var idle := _off(e.at, randf_range(-2.4, 2.4), randf_range(-1.8, 2.4))
	return _on(idle) + Vector3(0, randf_range(0.1, 0.6), 0)


# --- arrivals and departures -------------------------------------------------

func _grow() -> bool:
	if _elves.size() >= capacity:
		return false

	# Somebody who lives here, if there is anybody who lives here and is not
	# currently on the island. Same integer, same person: the tall one with the
	# crooked hat who always ends up at the kiln is the same tall one tomorrow.
	var seed_value := -1
	for s in _residents:
		var here := false
		for e in _elves:
			if e.seed_value == s:
				here = true
				break
		if not here:
			seed_value = int(s)
			break
	if seed_value == -1:
		seed_value = randi() % 0x7FFFFFFF
		_residents.append(seed_value)
		_dirty = true

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var e := Elf.new()
	e.id = _next_id
	e.seed_value = seed_value
	_next_id += 1

	# Hobbit or troll, decided once off the seed like everything else, so the
	# same twelve come back the same species every day.
	e.species = Species.TROLL if rng.randf() < TROLL_FRACTION else Species.HOBBIT

	if e.species == Species.TROLL:
		e.pace = rng.randf_range(0.19, 0.27)
		e.stamina = rng.randf_range(0.75, 1.15)
		e.carry_limit = 3
		e.gait = rng.randf_range(0.55, 0.75)
		e.turn_rate = rng.randf_range(1.4, 2.4)
		e.bounce_amt = rng.randf_range(0.35, 0.65)
		e.stride_amp = rng.randf_range(0.70, 0.95)
	else:
		e.pace = rng.randf_range(0.34, 0.52)
		e.stamina = rng.randf_range(0.55, 1.0)
		e.carry_limit = 1
		e.gait = rng.randf_range(0.82, 1.25)
		e.turn_rate = rng.randf_range(2.6, 4.4)
		e.bounce_amt = rng.randf_range(0.75, 1.45)
		e.stride_amp = rng.randf_range(0.85, 1.24)

	e.spot = rng.randf() * TAU
	e.route_bias = rng.randf_range(-0.55, 0.55)
	e.sociable = rng.randf_range(-0.25, 0.40)
	e.fidget = rng.randf_range(0.0, 0.35)
	e.playful = rng.randf_range(0.05, 0.75)
	e.rubberneck = rng.randf_range(0.0, 1.0)
	e.fidget_kind = rng.randi() % 4
	e.fidget_phase = rng.randf() * TAU
	e.phase = rng.randf() * TAU
	e.energy = randf_range(0.7, 1.0)

	# Every task starts worth exactly as much as every other one, unless this
	# elf has been here before, in which case it arrives as whatever it made
	# itself into.
	for t in [Task.GATHER, Task.CRAFT, Task.HAUL, Task.DELIVER, Task.FIT]:
		e.affinity[t] = 1.0
	var kept: Variant = _resident_affinity.get(str(seed_value), null)
	if kept is Dictionary:
		for k in kept:
			e.affinity[int(k)] = float(kept[k])

	var haunts := ["pool", "crest", "grove", "hearth", "site", "sandbank"]
	e.haunt = _clear_of_piles(_off(_spot(haunts[rng.randi() % haunts.size()]),
		rng.randf_range(-1.1, 1.1), rng.randf_range(-1.1, 1.1)))
	e.haunted = _time - randf_range(0.0, 140.0)

	e.at = _ashore(_off(_spot("hearth"), randf_range(-1.3, 1.3),
		randf_range(-1.0, 1.0)))
	e.facing = _flat(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	e.target = e.at
	e.look_at = _on(e.at) + Vector3(0, 0.4, 1.0)

	e.node = Node3D.new()
	e.rig = _build_body(e, rng)
	e.node.add_child(e.rig)
	_shadow_blob(e)
	add_child(e.node)
	_place(e)

	_elves.append(e)
	return true


## Real shadows need a directional shadow map, and that has never been
## measured against a phone left running for twenty-five minutes - see the
## handoff. This is the fallback the doc asks for either way: a soft dark disc
## underfoot costs almost nothing and buys most of the grounding, because
## nothing in this scene is connected to the ground by anything else.
func _shadow_blob(e: Elf) -> void:
	var r := 0.15 if e.species == Species.TROLL else 0.095
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = 0.004
	mesh.radial_segments = 10
	mesh.rings = 1

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.30)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = Vector3(0, 0.006, 0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.node.add_child(node)


## The phone moved, so some of them go.
##
## **Nothing that has been built comes apart.** An earlier version knocked the
## last two works off the top, on the rule that what was built can be lost, and
## it was wrong here. That rule was written for a bottle that filled in fifteen
## minutes and emptied in one; against a build that takes a week it means a phone
## call can erase an evening, and the honest response to a mechanic that can
## erase an evening is to stop opening the app.
##
## Losing people is enough of a cost. The crew takes fifteen unbroken minutes to
## come back up to strength, so a disturbance still costs real hours of building
## - it just costs them forwards, by slowing the work down, rather than backwards
## by undoing it. Progress only ever goes one way now.
func _shrink() -> void:
	if resting():
		return

	_quake = 1.0

	var leaving := int(ceil(float(_elves.size()) * LOSS_FRACTION))
	for _i in leaving:
		if _elves.size() <= 1:
			break
		var index := randi() % _elves.size()
		var e := _elves[index]

		# Whatever they were holding is put back rather than vanishing with them.
		if e.carrying:
			var holder := e.carrying
			e.grip.remove_child(holder)
			var home := _home_for(e.carry_kind)
			for child in holder.get_children():
				holder.remove_child(child)
				if home:
					home.node.add_child(child)
					home.items.append(child)
				else:
					child.queue_free()
			if home:
				home.settle()
			holder.queue_free()
		if e.station and e.station.taken_by == e.id:
			e.station.taken_by = -1
		if e.work and e.work.taken_by == e.id:
			e.work.taken_by = -1
		_drop_tool(e)

		e.node.queue_free()
		_elves.remove_at(index)

	for e in _elves:
		_cheer(e, -0.55)

	_dirty = true
	_save()


# --- materials ---------------------------------------------------------------

func _build_materials() -> void:
	var b := _b
	_mats = {
		"stone": World.solid_material(Color("867F76"), 0.95),
		"dark": World.solid_material(Color("2E2C2A"), 0.9),
		"timber": World.solid_material(b["bark"], 0.9),
		"lumber": World.solid_material(Color("B08A5E"), 0.88),
		"glulam": World.solid_material(Color("C09A68"), 0.80),
		"panel": World.solid_material(Color("8E7350"), 0.95),
		"iron": World.solid_material(Color("6E7480"), 0.35),
		"brass": World.solid_material(Color("C39A4E"), 0.30),
		"concrete": World.solid_material(Color("9AA0A0"), 1.0),
		"clay": World.solid_material(Color("9C6A4E"), 0.95),
		"plaster": World.solid_material(Color("E2DED2"), 1.0),
		"cloth": World.solid_material(Color("C8B49A"), 1.0),
		"felt": World.solid_material(Color("4E4A46"), 1.0),
		"batt": World.solid_material(Color("D8C89E"), 1.0),
		"wire": World.solid_material(Color("A2743E"), 0.40),
		"pipe": World.solid_material(Color("5A6068"), 0.45),
		"floorboard": World.solid_material(Color("8E6A42"), 0.60),
		"cabinet": World.solid_material(Color("7A5636"), 0.70),
		"counter": World.solid_material(Color("6E6862"), 0.35),
		"siding": World.solid_material(b["siding"], 0.90),
		"tile": World.solid_material(b["tile"], 0.85),
		"wash": World.solid_material(Color("F0EAD8"), 1.0),
	}

	# Metal earns a little reflectance rather than just a low roughness -
	# roughness alone reads as wet plastic, and metallic tints the highlight
	# by the albedo instead of leaving it white.
	for m in ["iron", "brass", "wire", "pipe", "counter"]:
		(_mats[m] as StandardMaterial3D).metallic = 0.55
		(_mats[m] as StandardMaterial3D).metallic_specular = 0.6

	# Cloth, plaster and the like get none at all - already at roughness 1.0
	# above, which is the other half of the same rule: everything soft stays
	# soft next to everything that now catches the light.

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.80, 0.86, 0.42)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.04
	glass.metallic = 0.25
	glass.metallic_specular = 0.9
	_mats["glass"] = glass

	_mats["lamp"] = World.glow_material(EMBER, 0.90)


## A fresh material a shade off the shared one, so twenty stones in twenty
## hands are not the same stone twenty times. Cheap here because carried
## items are single, unmerged instances rather than the big batched meshes
## the scattered decoration uses - duplicating a material per pickup costs
## nothing next to duplicating geometry would.
func _jittered(mat_name: String, roughness: float, amount: float) -> StandardMaterial3D:
	var base: Color = (_mats[mat_name] as StandardMaterial3D).albedo_color
	var v := randf_range(-amount, amount)
	var c := Color(clampf(base.r + v, 0.0, 1.0), clampf(base.g + v, 0.0, 1.0),
		clampf(base.b + v, 0.0, 1.0))
	var mat := World.solid_material(c, roughness)
	mat.metallic = (_mats[mat_name] as StandardMaterial3D).metallic
	mat.metallic_specular = (_mats[mat_name] as StandardMaterial3D).metallic_specular
	return mat


## One unit of something, in a heap or in a pair of hands. Every kind has to be
## tellable apart from three metres away or the logistics stop being readable,
## which is most of why there are sixteen and not forty.
func _make_item(kind: int) -> Node3D:
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("kind", kind)

	match kind:
		Plan.Kind.STONE:
			node.mesh = Geometry.crystal(0.062, 0.26)
			node.material_override = _jittered("stone", 0.95, 0.05)
			node.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		Plan.Kind.ORE:
			node.mesh = Geometry.crystal(0.056, 0.34)
			node.material_override = _jittered("iron", 0.35, 0.06)
			node.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		Plan.Kind.TIMBER:
			node.mesh = _cyl(0.033, 0.28, 6)
			node.material_override = _mats["timber"]
			node.rotation = Vector3(PI * 0.5, randf_range(-0.5, 0.5), 0)
		Plan.Kind.LUMBER:
			var plank := BoxMesh.new()
			plank.size = Vector3(0.055, 0.022, 0.28)
			node.mesh = plank
			node.material_override = _mats["lumber"]
			node.rotation = Vector3(0, randf_range(-0.4, 0.4), 0)
		Plan.Kind.PANEL:
			var sheet := BoxMesh.new()
			sheet.size = Vector3(0.20, 0.014, 0.17)
			node.mesh = sheet
			node.material_override = _mats["panel"]
			node.rotation = Vector3(0.15, randf_range(-0.4, 0.4), 0)
		Plan.Kind.CLAY:
			node.mesh = Geometry.crystal(0.058, 0.18)
			node.material_override = _jittered("clay", 0.95, 0.05)
		Plan.Kind.SAND:
			# A sack, because loose sand in a pair of hands is nothing at all.
			var sack := SphereMesh.new()
			sack.radius = 0.055
			sack.height = 0.13
			sack.radial_segments = 7
			sack.rings = 4
			node.mesh = sack
			node.material_override = _mats["cloth"]
		Plan.Kind.FIBRE:
			node.mesh = _cyl(0.048, 0.24, 6)
			node.material_override = World.solid_material(_b["reed"], 1.0)
			node.rotation = Vector3(PI * 0.5, randf_range(-0.5, 0.5), 0)
		Plan.Kind.LIME:
			var tub := CylinderMesh.new()
			tub.top_radius = 0.050
			tub.bottom_radius = 0.042
			tub.height = 0.10
			tub.radial_segments = 7
			tub.rings = 1
			node.mesh = tub
			node.material_override = _mats["plaster"]
		Plan.Kind.IRON:
			var ingot := BoxMesh.new()
			ingot.size = Vector3(0.062, 0.034, 0.13)
			node.mesh = ingot
			node.material_override = _mats["iron"]
			node.rotation = Vector3(0, randf_range(-0.5, 0.5), 0)
		Plan.Kind.CONCRETE:
			var bucket := CylinderMesh.new()
			bucket.top_radius = 0.055
			bucket.bottom_radius = 0.044
			bucket.height = 0.11
			bucket.radial_segments = 8
			bucket.rings = 1
			node.mesh = bucket
			node.material_override = _mats["concrete"]
		Plan.Kind.GLASS:
			var pane := BoxMesh.new()
			pane.size = Vector3(0.16, 0.13, 0.010)
			node.mesh = pane
			node.material_override = _mats["glass"]
			node.rotation = Vector3(0.2, randf_range(-0.3, 0.3), 0)
		Plan.Kind.PIPE:
			node.mesh = _cyl(0.020, 0.26, 7)
			node.material_override = _mats["pipe"]
			node.rotation = Vector3(PI * 0.5, randf_range(-0.4, 0.4), 0)
		Plan.Kind.WIRE:
			var coil := TorusMesh.new()
			coil.inner_radius = 0.032
			coil.outer_radius = 0.058
			coil.rings = 8
			coil.ring_segments = 5
			node.mesh = coil
			node.material_override = _mats["wire"]
			node.rotation = Vector3(PI * 0.5, 0, 0)
		Plan.Kind.CLOTH:
			node.mesh = _cyl(0.045, 0.22, 7)
			node.material_override = _mats["cloth"]
			node.rotation = Vector3(0, randf_range(-0.4, 0.4), PI * 0.5)
		Plan.Kind.PLASTER:
			var board := BoxMesh.new()
			board.size = Vector3(0.19, 0.012, 0.15)
			node.mesh = board
			node.material_override = _mats["plaster"]
			node.rotation = Vector3(0.12, randf_range(-0.4, 0.4), 0)

	return node


func _cyl(radius: float, height: float, sides: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.06
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


# --- the land ----------------------------------------------------------------

func _build_terrain() -> void:
	var node := MeshInstance3D.new()
	node.mesh = _land.mesh()
	node.material_override = _land.material(_wear)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _build_water() -> void:
	var pool := _spot("pool")
	# Just above the bottom of the hollow, not a quarter of a metre above it. Set
	# too high the disc breaks the surface at its rim and the pool reads as a
	# puddle of paint lying on the dune rather than water in a dip.
	var level := _ground(pool) + 0.10
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segs := 24
	var rings := 3
	for r in rings:
		for s in segs:
			var t0 := TAU * float(s) / float(segs)
			var t1 := TAU * float(s + 1) / float(segs)
			var k0 := float(r) / float(rings)
			var k1 := float(r + 1) / float(rings)
			var v00 := _pond(pool, t0, k0, level)
			var v01 := _pond(pool, t1, k0, level)
			var v10 := _pond(pool, t0, k1, level)
			var v11 := _pond(pool, t1, k1, level)
			# Wound the same way round as the ground, or the pool is culled and
			# the hollow it sits in looks like a hole.
			st.set_normal(Vector3.UP)
			if r > 0:
				st.add_vertex(v00)
				st.add_vertex(v11)
				st.add_vertex(v01)
			st.add_vertex(v00)
			st.add_vertex(v10)
			st.add_vertex(v11)

	var node := MeshInstance3D.new()
	node.mesh = st.commit()

	# Glossy and faintly lit from within. There are no reflections on the mobile
	# renderer, so without the sheen a pool is a dark hole in the ground.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _b["water"]
	mat.roughness = 0.10
	mat.metallic = 0.18
	mat.emission_enabled = true
	mat.emission = _b["water"]
	mat.emission_energy_multiplier = 0.42
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _pond(pool: Vector3, around: float, out: float, level: float) -> Vector3:
	var edge := 0.92 + 0.14 * sin(around * 3.0 + 1.1)
	return Vector3(pool.x + cos(around) * edge * out, level,
		pool.z + sin(around) * edge * out * 0.86)


# --- where things come from --------------------------------------------------

func _build_sources() -> void:
	for place in Biome.SOURCES:
		var kind: int = Biome.SOURCES[place]
		var at := _spot(place)
		var out := _make_pile([kind], _off(at, 0.78, 0.42), _off(at, 0.78, 0.80))
		out.limit = 12
		var benches := 2 if kind in [Plan.Kind.STONE, Plan.Kind.TIMBER] else 1

		for i in benches:
			var st := Station.new()
			st.id = place
			st.out_kind = kind
			st.seconds = 7.0 if benches == 2 else 6.0
			st.stand = _off(at, -0.25 + float(i) * 0.50, 0.58)
			st.face = at
			st.out_pile = out
			st.motion = "sweep" if kind in [Plan.Kind.CLAY, Plan.Kind.SAND,
				Plan.Kind.FIBRE] else "swing"
			st.tool = _source_tool(kind)
			_stations.append(st)
			_workpiece(kind, st.stand, at)

		_dress_source(place, kind, at)


func _source_tool(kind: int) -> String:
	match kind:
		Plan.Kind.TIMBER: return "axe"
		Plan.Kind.FIBRE: return "sickle"
		Plan.Kind.CLAY, Plan.Kind.SAND: return "shovel"
	return "pick"


## Something under the tool at the spot the swing actually lands. An arm coming
## down onto bare ground reads as a body moving on its own however good the
## curve is - the prop is what makes it work.
func _workpiece(kind: int, stand: Vector3, face: Vector3) -> void:
	var block := _in_front(stand, face, 0.36)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	match kind:
		Plan.Kind.TIMBER:
			var along := _flat(face - stand)
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.070
			trunk.bottom_radius = 0.085
			trunk.height = 0.85
			trunk.radial_segments = 7
			trunk.rings = 1
			st.append_from(trunk, 0, Transform3D(
				Basis(Vector3.UP, atan2(along.x, along.z))
					* Basis(Vector3.RIGHT, PI * 0.5),
				_on(block) + Vector3(0, 0.085, 0)))
			_merged(st, World.solid_material(_b["bark"], 0.9))
			return
		Plan.Kind.CLAY, Plan.Kind.SAND, Plan.Kind.FIBRE:
			# Loose ground. A shallow scrape, flat enough that a shovel has
			# somewhere to go.
			st.append_from(Geometry.crystal(0.26, 0.20), 0,
				Transform3D(Basis(Vector3.UP, randf() * TAU)
					.scaled(Vector3(1.0, 0.14, 1.0)), _on(block)))
			_merged(st, World.solid_material(Color(_b["shore"]).darkened(0.1), 1.0))
			return

	# Flat, and only ankle high. It was a boulder up to the elf's waist once,
	# which meant the pick had to stop at hand height and the swing had nowhere
	# to go: you cannot dig down into something you are standing beside.
	st.append_from(Geometry.crystal(0.22, 0.24), 0,
		Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(1.0, 0.32, 1.0)),
			_on(block) + Vector3(0, 0.012, 0)))
	_merged(st, _mats["stone"])


## What each source looks like from a distance. All merged by material, so a wood
## costs two draw calls rather than sixty.
func _dress_source(place: String, kind: int, at: Vector3) -> void:
	match kind:
		Plan.Kind.STONE, Plan.Kind.ORE:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 22:
				var p := _off(at, randf_range(-1.0, 1.0), randf_range(-0.9, 0.7))
				# Never bigger than the elf working it, or the seam reads as a
				# landslide and the figure in front stops being the subject.
				var size := randf_range(0.08, 0.24)
				st.append_from(Geometry.crystal(size, 0.34), 0,
					Transform3D(Basis(Vector3.UP, randf() * TAU),
						_on(p) + Vector3(0, size * 0.35, 0)))
			if kind == Plan.Kind.ORE:
				# An adit, so a mine is somewhere you go into rather than a
				# differently coloured pile of rocks.
				st.append_from(Geometry.crystal(0.34, 0.16), 0,
					Transform3D(Basis(), _on(at) + Vector3(0, 0.16, -0.30)))
			_merged(st, _mats["stone"] if kind == Plan.Kind.STONE
				else World.solid_material(Color(_b["rocky"]).darkened(0.25), 0.8))

		Plan.Kind.TIMBER:
			var wood := SurfaceTool.new()
			wood.begin(Mesh.PRIMITIVE_TRIANGLES)
			var canopy := SurfaceTool.new()
			canopy.begin(Mesh.PRIMITIVE_TRIANGLES)
			var n := 12 if _b["tree"] == "giant" else 10
			for i in n:
				var p := _off(at, randf_range(-1.5, 1.5), randf_range(-1.2, 1.2))
				_grow_tree(wood, canopy,
					Transform3D(Basis(Vector3.UP, randf() * TAU), _on(p)),
					randf_range(0.75, 1.20))
			_merged(wood, World.solid_material(_b["bark"], 0.9))
			var leaf := World.solid_material(_b["canopy"], 0.95)
			leaf.emission_enabled = true
			leaf.emission = _b["canopy_glow"]
			leaf.emission_energy_multiplier = 0.05
			_merged(canopy, leaf)

		Plan.Kind.FIBRE:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 130:
				var p := _off(at, randf_range(-1.1, 0.9), randf_range(-1.0, 0.8))
				var tall := randf_range(0.16, 0.34)
				var stalk := CylinderMesh.new()
				stalk.top_radius = 0.002
				stalk.bottom_radius = 0.010
				stalk.height = tall
				stalk.radial_segments = 3
				stalk.rings = 1
				var lean := Basis(Vector3(randf_range(-1, 1), 0,
					randf_range(-1, 1)).normalized(), randf_range(0.0, 0.30))
				st.append_from(stalk, 0,
					Transform3D(lean, _on(p) + Vector3(0, tall * 0.45, 0)))
			_merged(st, World.solid_material(_b["reed"], 1.0))

		Plan.Kind.CLAY, Plan.Kind.SAND:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in 14:
				var p := _off(at, randf_range(-1.0, 1.0), randf_range(-0.9, 0.9))
				var size := randf_range(0.10, 0.22)
				st.append_from(Geometry.crystal(size, 0.22), 0,
					Transform3D(Basis(Vector3.UP, randf() * TAU)
						.scaled(Vector3(1.3, 0.35, 1.3)), _on(p)))
			_merged(st, World.solid_material(
				_b["shore"] if kind == Plan.Kind.SAND else Color("9C6A4E"), 1.0))


func _grow_tree(wood: SurfaceTool, canopy: SurfaceTool, base: Transform3D,
		scale: float) -> void:
	var kind := str(_b["tree"])

	if kind == "palm":
		# One long bare trunk with a crown on top. A palm is a silhouette and
		# nothing else, so the trunk leans and the fronds are wide and flat.
		var tall := 1.05 * scale
		var lean := Vector3(randf_range(-0.16, 0.16), 0, randf_range(-0.16, 0.16))
		wood.append_from(Geometry.tube(
			Geometry.jagged(Vector3.ZERO, Vector3(0, tall, 0) + lean * tall,
				0.030 * scale, 2), 0.046 * scale, 0.028 * scale, 6, false), 0, base)
		for i in 7:
			var a := TAU * float(i) / 7.0 + randf_range(-0.2, 0.2)
			var out := Vector3(cos(a), randf_range(0.25, 0.55), sin(a)).normalized()
			var frond := Transform3D(
				Basis(Vector3(-sin(a), 0, cos(a)), randf_range(0.5, 0.9))
					.scaled(Vector3(1.9, 0.16, 0.55)),
				Vector3(0, tall, 0) + lean * tall + out * 0.22 * scale)
			canopy.append_from(Geometry.crystal(0.16 * scale, 0.30), 0, base * frond)
		return

	if kind == "conifer":
		var tall := 0.72 * scale
		wood.append_from(Geometry.tube(
			Geometry.jagged(Vector3.ZERO, Vector3(0, tall, 0), 0.020 * scale, 2),
			0.044 * scale, 0.016 * scale, 6, false), 0, base)
		for i in 4:
			var t := float(i) / 3.0
			var skirt := Transform3D(
				Basis(Vector3.UP, randf() * TAU)
					.scaled(Vector3(lerpf(1.5, 0.5, t), 0.55, lerpf(1.5, 0.5, t))),
				Vector3(0, tall * lerpf(0.35, 1.02, t), 0))
			canopy.append_from(Geometry.crystal(0.17 * scale, 0.26), 0,
				base * skirt)
		return

	var top := Vector3(0, (1.05 if kind == "giant" else 0.68) * scale, 0)
	wood.append_from(Geometry.tube(
		Geometry.jagged(Vector3.ZERO, top, 0.030 * scale, 2),
		0.056 * scale, 0.034 * scale, 6, false), 0, base)

	for i in 4:
		var out := Vector3(randf_range(-1, 1), randf_range(0.8, 1.6),
			randf_range(-1, 1)).normalized()
		var tip := top + out * randf_range(0.22, 0.36) * scale
		wood.append_from(Geometry.tube(
			Geometry.jagged(top * randf_range(0.74, 1.0), tip, 0.025 * scale, 2),
			0.026 * scale, 0.015 * scale, 5, false), 0, base)

		# Foliage as a few overlapping faceted clumps rather than one smooth
		# sphere. A sphere reads as a blob at any size; facets catching the key
		# at different angles read as leaves.
		for _c in 3:
			var clump := Transform3D(
				Basis(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)
					.scaled(Vector3(1.0, 0.60, 1.0)),
				tip + Vector3(randf_range(-0.09, 0.09), randf_range(-0.04, 0.10),
					randf_range(-0.09, 0.09)) * scale)
			canopy.append_from(Geometry.crystal(randf_range(0.10, 0.15) * scale, 0.38),
				0, base * clump)


## Somewhere to sit down. Not decoration: an elf out of energy walks here and
## stays until it has some back, and somebody is nearly always here.
func _build_hearth() -> void:
	var at := _anchor(_spot("hearth"))

	for i in 9:
		var a := TAU * float(i) / 9.0
		var stone := MeshInstance3D.new()
		stone.mesh = Geometry.crystal(randf_range(0.045, 0.070), 0.30)
		stone.position = Vector3(cos(a) * 0.26, 0.02, sin(a) * 0.26)
		stone.material_override = _mats["stone"]
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(stone)

	for side in [-1.0, 1.0]:
		var seat := MeshInstance3D.new()
		seat.mesh = _cyl(0.056, 0.46, 7)
		seat.position = Vector3(side * 0.48, 0.055, 0.10)
		seat.rotation = Vector3(PI * 0.5, side * 0.3, 0)
		seat.material_override = _mats["timber"]
		seat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		at.add_child(seat)

	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.105
	cone.height = 0.26
	cone.radial_segments = 7
	flame.mesh = cone
	flame.position = Vector3(0, 0.14, 0)
	flame.material_override = World.glow_material(EMBER, 0.75)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	at.add_child(flame)

	_fire = OmniLight3D.new()
	_fire.position = Vector3(0, 0.22, 0)
	_fire.light_color = EMBER
	_fire.omni_range = 2.8
	_fire.shadow_enabled = false
	at.add_child(_fire)


func _build_house_light() -> void:
	_house_light = OmniLight3D.new()
	_house_light.position = _on(_spot("site")) + Vector3(0, Plan.deck_y(1), 0)
	_house_light.light_color = EMBER
	_house_light.light_energy = 0.0
	_house_light.omni_range = 3.6
	_house_light.shadow_enabled = false
	add_child(_house_light)


## What makes it look lived on rather than laid out.
##
## Ground cover is the difference between an island and a putting green, but it
## has to be clumped. Evenly scattered tufts read as sprinkles on a bare surface
## and somehow make the emptiness more obvious, not less. Real ground is tussocks
## with worn earth between them.
func _build_clutter() -> void:
	var density: float = _b["cover"]

	var blades: Array[SurfaceTool] = []
	for i in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		blades.append(st)

	var scrub := SurfaceTool.new()
	scrub.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pebbles := SurfaceTool.new()
	pebbles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deadwood := SurfaceTool.new()
	deadwood.begin(Mesh.PRIMITIVE_TRIANGLES)

	for _t in int(190.0 * density):
		var at := _open_ground()
		if at == Vector3.ZERO:
			continue
		var into: SurfaceTool = blades[randi() % blades.size()]
		var spread := randf_range(0.06, 0.16)
		for _b2 in randi_range(5, 10):
			var tall := randf_range(0.07, 0.17)
			var blade := CylinderMesh.new()
			blade.top_radius = 0.0
			blade.bottom_radius = randf_range(0.008, 0.016)
			blade.height = tall
			blade.radial_segments = 3
			blade.rings = 1
			blade.cap_top = false
			blade.cap_bottom = false
			var a := randf() * TAU
			var out := randf() * spread
			var root := _off(at, cos(a) * out, sin(a) * out)
			into.append_from(blade, 0, Transform3D(
				Basis(Vector3(-sin(a), 0, cos(a)), randf_range(0.10, 0.45)),
				_on(root) + Vector3(0, tall * 0.42, 0)))

	for _s in int(48.0 * density):
		var at := _open_ground()
		if at == Vector3.ZERO:
			continue
		for _c in 3:
			var size := randf_range(0.075, 0.145)
			scrub.append_from(Geometry.crystal(size, 0.36), 0, Transform3D(
				Basis(Vector3(randf(), randf(), randf()).normalized(), randf() * TAU)
					.scaled(Vector3(1.0, 0.66, 1.0)),
				_on(_off(at, randf_range(-0.09, 0.09), randf_range(-0.09, 0.09)))
					+ Vector3(0, size * 0.55, 0)))

	for _r in 110:
		var at := _open_ground()
		if at == Vector3.ZERO:
			continue
		var size := randf_range(0.028, 0.075)
		pebbles.append_from(Geometry.crystal(size, 0.34), 0,
			Transform3D(Basis(Vector3.UP, randf() * TAU),
				_on(at) + Vector3(0, size * 0.30, 0)))

	for _w in int(34.0 * density):
		var at := _open_ground()
		if at == Vector3.ZERO:
			continue
		var limb := CylinderMesh.new()
		limb.top_radius = randf_range(0.008, 0.014)
		limb.bottom_radius = randf_range(0.016, 0.026)
		limb.height = randf_range(0.20, 0.44)
		limb.radial_segments = 5
		limb.rings = 1
		deadwood.append_from(limb, 0, Transform3D(
			Basis(Vector3.UP, randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5),
			_on(at) + Vector3(0, 0.020, 0)))

	var grass: Array = _b["grass"]
	_merged(blades[0], World.solid_material(grass[0], 1.0))
	_merged(blades[1], World.solid_material(grass[1], 1.0))
	_merged(scrub, World.solid_material(_b["scrub"], 1.0))
	_merged(pebbles, World.solid_material(Color(_b["rocky"]).darkened(0.20), 0.95))
	_merged(deadwood, World.solid_material(Color(_b["bark"]).lightened(0.10), 0.95))


## A spot with nothing already on it. Returns zero if it gave up, which the
## callers treat as "put nothing here" rather than retrying forever.
func _open_ground() -> Vector3:
	for _try in 10:
		var p := Vector3(randf_range(-LAND_X, LAND_X) * 1.02, 0.0,
			randf_range(-LAND_Z, LAND_Z) * 1.02)
		if _ground(p) < -0.08:
			continue
		var clear := true
		for place in Biome.LAYOUT:
			var near := 1.9 if place == "site" else 0.95
			if _gap(p, _spot(place)) < near:
				clear = false
				break
		if not clear:
			continue
		# Not on the tracks they wear between the places they go.
		if _trodden(p) > 0.45:
			continue
		return p
	return Vector3.ZERO


## How much ground a metre of walking wears.
##
## Tuned against captures taken with it multiplied by forty, which is how you
## look at two hours of walking without waiting two hours. At this value a route
## somebody uses steadily is showing after twenty minutes of being watched and
## is a proper track by the second afternoon.
##
## Which means the marks on a region are, quite literally, a picture of how the
## week went: heavy to the quarry if that was the bottleneck, heavy to the grove
## if it was not, and nothing at all across the corner nobody ever had a reason
## to cross.
##
## Deliberately not fast. A path that appears in five minutes is a feature; a
## path that took a week is a record.
const TREAD := 0.030

## Somebody under a load leans on the ground harder and drags their feet. Worth
## having because it means the routes that wear deepest are the hauling routes,
## which are the ones the week was actually about.
const TREAD_LADEN := 0.9


func _tread(e: Elf, step: float) -> void:
	var amount := step * TREAD
	if e.carrying != null and e.carry_kind >= 0 and e.carry_kind < CARRY_DRAG.size():
		amount *= 1.0 + TREAD_LADEN * CARRY_DRAG[e.carry_kind]
	_wear.tread(e.at, amount)


## How worn the ground is here. Read when scattering cover, so that grass and
## scrub go in wherever the paths were *not* on the day the region was opened -
## which means a region that has been lived in for a week comes back with its
## verges pushed back off the tracks, and a fresh one comes back with grass over
## everything.
##
## Only at build time. Cover that vanished from under somebody's feet as they
## walked would be a lawnmower, not a path.
func _trodden(p: Vector3) -> float:
	return _wear.at(p)


func _merged(st: SurfaceTool, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _make_pile(accepts: Array[int], at: Vector3, stand: Vector3) -> Pile:
	var p := Pile.new()
	p.accepts = accepts
	p.at = _ashore(at)
	p.stand = _ashore(stand)
	p.node = _anchor(p.at)
	_piles.append(p)
	return p


# --- the elf -----------------------------------------------------------------

## No two the same.
##
## Twelve of one figure reads as a production line however well it moves, so
## every elf is rolled at birth: height, girth, head size, skin, cloth, hat
## shape, ear length, eye spacing, and whether it has a beard. All of it comes
## out of one integer, which is why the same people can come back tomorrow.
##
## The head is its own node rather than welded to the body, because everything
## worth doing with attention needs it to turn on its own.
## The two bodies are built by two different functions on purpose.
##
## The version before this one had a single builder with `if troll` scattered
## through it, and every difference between the species was a number fed to the
## same shapes: the same capsule torso, the same ball head, the same cone ears
## made shorter, the same cone hat swapped for cone horns. That is a parameter
## sweep and not a design, and it showed - a hobbit and an elf squinted at were
## the same outline at different sizes, which is exactly what was complained
## about.
##
## The test being aimed at here is the silhouette test: take all the colour and
## all the detail away, leave the outline, and a hobbit and a troll have to be
## two different shapes. So:
##
##   A hobbit is a pear. Narrow at the shoulders, wide and low at the belly,
##   short-legged, with a mass of curly hair that is most of the head's
##   outline, round ears that stay near the skull, and feet too big for it.
##
##   A troll is a cliff. Angular, asymmetric, built from faceted lumps rather
##   than one smooth capsule, one shoulder higher than the other, a head wider
##   than it is tall, and hands like shovels.
##
## Neither of them is the old rig with different arguments.
func _build_body(e: Elf, rng: RandomNumberGenerator) -> Node3D:
	var troll := e.species == Species.TROLL
	var root := Node3D.new()

	var body := Node3D.new()
	# Big and heavy, or small and quick - the silhouette has to say which one
	# is which from across the island, before anybody sees a colour.
	var height := rng.randf_range(1.38, 1.62) if troll else rng.randf_range(0.66, 0.84)
	body.scale = Vector3(rng.randf_range(0.92, 1.10), height,
		rng.randf_range(0.92, 1.10))
	root.add_child(body)
	e.body = body
	e.body_scale = body.scale

	# Hung off the rig rather than the body, so a tool is the same size in a tall
	# elf's hands as in a short one's, and so a swing through half a circle is
	# not sheared by the body's stretch.
	e.grip = Node3D.new()
	e.grip.position = Vector3(0, 0.215, 0.115)
	root.add_child(e.grip)

	# Hobbits are wider for their height than the elves were. Most of what makes
	# something read as stout rather than small is the ratio, not the size.
	var girth := rng.randf_range(0.130, 0.168) if troll else rng.randf_range(0.098, 0.126)
	var head_r := rng.randf_range(0.088, 0.108) if troll else rng.randf_range(0.070, 0.090)

	var skins := [Color("F0BE92"), Color("E0A87A"), Color("C98A63"), Color("FAD3AE")]
	var troll_skins := [Color("8A9088"), Color("7A8272"), Color("94816C"), Color("6E7A6A")]
	var cloths := [Color("46A05E"), Color("3B7FA8"), Color("8C5A9E"),
		Color("B8623C"), Color("4F7A46"), Color("2F6E7A")]
	var troll_wraps := [Color("6E5A44"), Color("5A4E3C"), Color("70603E")]
	var hats := [Color("D2503F"), Color("B8792F"), Color("3E6BA8"),
		Color("7A4470"), Color("C4923A")]
	var beards := [Color("EFEFE6"), Color("C9C4B4"), Color("C9843F")]
	var mosses := [Color("5A7A44"), Color("6E8C4E"), Color("4E6E3A")]
	var hairs := [Color("4A3524"), Color("6E4A2A"), Color("8A5A32"),
		Color("3A2A1E"), Color("A8763A"), Color("54402E"), Color("2E241C")]

	var skin_c: Color = (troll_skins if troll else skins)[
		rng.randi() % (troll_skins.size() if troll else skins.size())]
	var tunic := World.solid_material((troll_wraps if troll else cloths)[
		rng.randi() % (troll_wraps.size() if troll else cloths.size())], 0.85)
	var trim := World.solid_material(TRIM.lerp(Color("A8763A"), rng.randf()), 0.45)
	var skin := World.solid_material(skin_c, 0.75 if not troll else 0.95)
	var hat := World.solid_material(hats[rng.randi() % hats.size()], 0.85)
	var horn := World.solid_material(Color("D8CDB8"), 0.55)
	var moss := World.solid_material(mosses[rng.randi() % mosses.size()], 1.0)
	var boot := World.solid_material(
		skin_c.darkened(0.15) if troll else skin_c.darkened(0.05), 0.85)
	var eye := World.solid_material(EYE, 0.35)
	var cheek := World.solid_material(skin_c.lerp(CHEEK, 0.55 if troll else 0.75), 0.8)
	var hair := World.solid_material(hairs[rng.randi() % hairs.size()], 0.95)
	var leather := World.solid_material(Color("4A3628").lerp(
		Color("6E5238"), rng.randf()), 0.9)

	if troll:
		_troll_torso(body, rng, girth, tunic, moss, skin)
	else:
		_hobbit_torso(body, rng, girth, tunic, trim, leather)

	# Everything above the neck hangs off one node, built around its own origin,
	# so turning the head turns the face, ears, hat and beard together.
	var head := Node3D.new()
	# A troll's sits higher, and on nothing - the mass below it comes up to
	# meet it, so there is no neck, only a head resting on a shoulder.
	head.position = Vector3(0, (0.394 if troll else 0.352)
		+ (head_r - 0.082) * 0.6, 0)
	body.add_child(head)
	e.head = head

	# The one surface every camera in this app eventually settles on. Worth
	# the extra dozen triangles that the scattered background rocks are not.
	#
	# A troll's is wider than it is tall and cut with fewer facets, so it reads
	# as hewn next to a hobbit's, which stays round and smooth.
	var skull := _sphere(Vector3.ZERO, head_r, skin, 7 if troll else 14,
		4 if troll else 8)
	if troll:
		skull.scale = Vector3(1.34, 0.76, 1.02)
	head.add_child(skull)

	# Faces differ most in the spacing and size of the eyes, which is what makes
	# one of these look like a different person rather than a recolour.
	#
	# Eyes are most of where attention reads from and most of what "cute"
	# is, so they get real effort: a white with a pupil that can slide inside
	# it, rather than a single dark ball a head has to swing to point.
	var eye_gap := rng.randf_range(0.025, 0.037)
	var eye_r := rng.randf_range(0.0115, 0.0165)
	var white_mat := World.solid_material(Color("F5F0E6"), 0.20)
	var glint_mat := World.solid_material(Color("FFFFFF"), 0.05)
	glint_mat.emission_enabled = true
	glint_mat.emission = Color("FFFFFF")
	glint_mat.emission_energy_multiplier = 0.6
	for side in [-1.0, 1.0]:
		var socket := _sphere(Vector3(side * eye_gap, 0.012, head_r * 0.86),
			eye_r * 1.18, white_mat, 8, 5)
		head.add_child(socket)
		var pupil := _sphere(Vector3(0, 0, eye_r * 0.55), eye_r * 0.60, eye, 7, 4)
		socket.add_child(pupil)
		e.pupils.append(pupil)
		socket.add_child(_sphere(Vector3(eye_r * 0.28, eye_r * 0.36, eye_r * 0.92),
			eye_r * 0.22, glint_mat, 5, 3))
		head.add_child(_sphere(Vector3(side * (head_r * 0.68), -0.022, head_r * 0.70),
			rng.randf_range(0.013, 0.020), cheek))

	if not troll and rng.randf() < 0.34:
		head.add_child(_capsule(Vector3(0, -0.048, head_r * 0.55),
			rng.randf_range(0.030, 0.045), rng.randf_range(0.010, 0.040),
			World.solid_material(beards[rng.randi() % beards.size()], 0.9)))

	if troll and rng.randf() < 0.4:
		head.add_child(_sphere(Vector3(rng.randf_range(-0.02, 0.02), 0.010,
			head_r * 0.62), rng.randf_range(0.014, 0.022), moss))

	# Ears.
	#
	# The old ones were cones for both species, shortened for the hobbits, and
	# that was the single worst thing on the figure: a cone is a point however
	# short you cut it, and a point on the side of a head reads as an elf at any
	# length. So neither of these is a cone any more. A hobbit's is a small
	# rounded disc pressed flat to the skull; a troll's is a blunt faceted lump
	# hanging off the side of it.
	for side in [-1.0, 1.0]:
		var ear: MeshInstance3D
		if troll:
			ear = _sphere(Vector3(side * (head_r * 1.24), -0.004, -0.008),
				rng.randf_range(0.026, 0.036), skin, 6, 3)
			ear.scale = Vector3(0.6, 1.0, 0.75)
		else:
			ear = _sphere(Vector3(side * (head_r * 0.94), 0.008, -0.006),
				rng.randf_range(0.020, 0.027), skin, 8, 5)
			ear.scale = Vector3(0.38, 1.0, 0.82)
		head.add_child(ear)

	if troll:
		# Horn stubs instead of a hat. A troll never wears one, and no two of
		# them match - one is always the worse for something.
		for side in [-1.0, 1.0]:
			var stub := _cone(Vector3(side * head_r * 0.62, head_r * 0.58,
				-head_r * 0.16), 0.019, rng.randf_range(0.022, 0.052), horn)
			stub.rotation = Vector3(0.3, 0.0, side * -0.4 + rng.randf_range(-0.2, 0.2))
			head.add_child(stub)
	else:
		_hobbit_hair(head, rng, head_r, hair, hat, trim)

	# Arms long enough to hold something in both hands. They used to reach 0.108,
	# a fifth of the body, and two hands can only meet where both arms reach - at
	# that length a disc six centimetres across pinned to the chest, with no room
	# for a swing and the top of any arc inside the head.
	#
	# A troll's shoulders sit at different heights, which is most of what makes
	# it read as a lump of a thing rather than a large hobbit - a body that is
	# symmetrical about its spine looks manufactured, and nothing else on the
	# island is.
	var lopside := rng.randf_range(0.012, 0.030) * (1.0 if rng.randf() < 0.5 else -1.0)
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		if troll:
			shoulder.position = Vector3(side * (girth + 0.020),
				0.262 + side * lopside, 0)
			# Thick to the wrist and then a hand out of proportion to it. Trolls
			# carry three of anything; the hands are the reason you believe it.
			shoulder.add_child(_capsule(Vector3(0, -0.086, 0), 0.040, 0.120, skin))
			var fist := _sphere(Vector3(0, -ARM * 1.04, 0.004), 0.048, skin, 6, 4)
			fist.scale = Vector3(1.0, 0.86, 1.12)
			shoulder.add_child(fist)
		else:
			shoulder.position = Vector3(side * (girth + 0.002), 0.250, 0)
			shoulder.add_child(_capsule(Vector3(0, -0.078, 0), 0.026, 0.098, tunic))
			shoulder.add_child(_sphere(Vector3(0, -ARM, 0), 0.026, skin))
		body.add_child(shoulder)
		e.arms.append(shoulder)
		e.shoulders.append(shoulder.position)

		var hip := Node3D.new()
		if troll:
			hip.position = Vector3(side * 0.068, 0.104, 0)
			hip.add_child(_capsule(Vector3(0, -0.038, 0), 0.050, 0.030, tunic))
			var slab := _sphere(Vector3(0, -0.082, 0.014), 0.050, skin, 6, 3)
			slab.scale = Vector3(0.86, 0.52, 1.20)
			hip.add_child(slab)
		else:
			hip.position = Vector3(side * 0.046, 0.092, 0)
			# Short legs. A hobbit is not a small person, it is a differently
			# proportioned one, and the leg-to-body ratio is where that lives -
			# it is what every drawing of one gets right before anything else.
			hip.add_child(_capsule(Vector3(0, -0.030, 0), 0.030, 0.022, leather))
			_hobbit_foot(hip, rng, skin)
		body.add_child(hip)
		e.legs.append(hip)

	return root


## A pear, not a capsule.
##
## Narrow across the shoulders and wide and low at the waist, which is the whole
## difference between a stout person and a short one. Built as two stacked
## masses rather than a single tube so the outline actually changes width on the
## way down - a capsule with a belly sphere stuck on the front of it, which is
## what this was before, is still a capsule from the side.
##
## The waistcoat is a real garment over the shirt rather than a second colour on
## the same shape: it stops at a hem, it has a hide edge, and it has buttons
## down the middle of it. Three small spheres is all "buttons" needs to be.
func _hobbit_torso(body: Node3D, rng: RandomNumberGenerator, girth: float,
		shirt: Material, trim: Material, leather: Material) -> void:
	# Shoulders and chest: the narrow end.
	body.add_child(_sphere(Vector3(0, 0.242, 0), girth * 0.86, shirt, 10, 6))

	# The waistcoat, which is most of the body. Wider than the chest and hung
	# lower, so the silhouette swells on the way down and then stops.
	var belly := _sphere(Vector3(0, 0.166, 0.004), girth * 1.04, trim, 11, 7)
	belly.scale = Vector3(1.0, 0.94, 1.0)
	body.add_child(belly)

	# The hem, and the belt under it.
	#
	# Cylinders rather than capsules, which matters more than it sounds like.
	# `_capsule` adds `radius * 2` to whatever height it is given, so a short
	# wide one is not a band at all - it is a sphere. Every belt in this file
	# was a sphere, which was invisible while the torso was a tube of the same
	# width and became a problem the moment the legs got short enough to be
	# worth seeing.
	body.add_child(_instance(_cyl(girth * 0.98, 0.020, 10),
		Vector3(0, 0.116, 0), trim))
	body.add_child(_instance(_cyl(girth * 0.93, 0.024, 10),
		Vector3(0, 0.098, 0), leather))

	# Buttons, up the front, in the trim's own metal rather than a third colour.
	var brass := World.solid_material(TRIM.lightened(0.15), 0.35)
	for i in 3:
		body.add_child(_sphere(
			Vector3(0, 0.142 + float(i) * 0.028, girth * 1.02 - float(i) * 0.004),
			rng.randf_range(0.0075, 0.0105), brass, 6, 4))


## A cliff face.
##
## The troll before this was a hobbit-shaped capsule at a larger scale with a
## hunch and two patches of moss, and no amount of grey makes that read as
## stone. This one is assembled out of four faceted lumps that do not line up
## with each other, at low enough segment counts that every one of them has
## visible flats - the same language the terrain is built in, which is the only
## honest way to say "rock" in a project that has refused textures everywhere
## else.
func _troll_torso(body: Node3D, rng: RandomNumberGenerator, girth: float,
		wrap: Material, moss: Material, skin: Material) -> void:
	# The main mass, leaning. Six segments, so it is a hewn block rather than
	# a ball, and turned off-axis so no two silhouettes of it are the same.
	#
	# Sized so that the head clears the top of it and the arms clear the sides.
	# The first pass at this was half again as big and the result was a boulder
	# with a pick in it - no head, no shoulders, nothing to read a creature
	# from. A troll has to be lumpen and still be somebody.
	var trunk := _sphere(Vector3(0, 0.186, 0), girth * 0.82, skin, 6, 4)
	trunk.scale = Vector3(1.10, 1.20, 0.90)
	trunk.rotation = Vector3(rng.randf_range(-0.10, 0.10),
		rng.randf_range(0.0, TAU), rng.randf_range(-0.14, 0.14))
	body.add_child(trunk)

	# One shoulder up over the neck. This is the shape that says the thing is
	# built wrong and gets away with it.
	var hump_side := 1.0 if rng.randf() < 0.5 else -1.0
	var hump := _sphere(Vector3(hump_side * girth * 0.86, 0.268, -0.012),
		rng.randf_range(0.042, 0.056), skin, 6, 3)
	hump.rotation = Vector3(0, rng.randf_range(0.0, TAU), hump_side * 0.3)
	body.add_child(hump)

	# A gut, low and forward, and a slab of hip under it.
	var gut := _sphere(Vector3(0, 0.138, girth * 0.26), girth * 0.76, skin, 6, 4)
	gut.scale = Vector3(1.06, 0.82, 0.94)
	body.add_child(gut)

	# The one piece of clothing a troll owns: a wrap round the middle, sitting
	# crooked. Only the waist, because a troll that dressed properly would be a
	# short broad hobbit again.
	var kilt := _instance(_cyl(girth * 0.84, 0.078, 7), Vector3(0, 0.126, 0), wrap)
	kilt.rotation = Vector3(rng.randf_range(-0.09, 0.09), 0,
		rng.randf_range(-0.09, 0.09))
	body.add_child(kilt)

	# Moss, on whatever faces up. Trolls stand still for a long time.
	for _i in rng.randi_range(2, 4):
		var around := rng.randf() * TAU
		body.add_child(_sphere(
			Vector3(sin(around) * girth * 0.62, rng.randf_range(0.19, 0.27),
				cos(around) * girth * 0.56),
			rng.randf_range(0.016, 0.028), moss, 6, 3))


## The big bare foot, which the brief asked for twice and got a slightly larger
## boot-coloured ball both times.
##
## Long, flat, bare, and with toes on it. The toes are three spheres and will be
## two pixels each from across the island, which is fine - they are not there to
## be counted, they are there so that the front of the foot is lumpy rather than
## round, and lumpy at the front is what a foot is.
func _hobbit_foot(hip: Node3D, rng: RandomNumberGenerator, skin: Material) -> void:
	var sole := _sphere(Vector3(0, -0.078, 0.020), 0.044, skin, 9, 5)
	sole.scale = Vector3(0.92, 0.50, 1.42)
	hip.add_child(sole)

	var spread := rng.randf_range(0.013, 0.017)
	for i in 3:
		hip.add_child(_sphere(
			Vector3((float(i) - 1.0) * spread, -0.080, 0.020 + 0.050),
			rng.randf_range(0.0085, 0.0115), skin, 6, 4))


## Hair, which nothing rendered at all before this.
##
## A cluster of overlapping balls sitting on the skull, the same trick the beard
## already used at the chin. It is cheap and it is the single biggest change to
## the outline on the whole figure: a bald sphere with a cone on it was an elf
## in a hat, and a lumpy mass of curls is a hobbit whatever else it is wearing.
##
## Which is also why the hat is now rare. A tall pointed hat was doing the work
## of saying "small fantasy person", and it was saying the wrong one.
func _hobbit_hair(head: Node3D, rng: RandomNumberGenerator, head_r: float,
		hair: Material, hat: Material, trim: Material) -> void:
	var curls := rng.randi_range(7, 10)
	var seat := head_r * 0.80
	for i in curls:
		# Round the crown and down the back, leaving the face clear. Biased
		# behind the ears so the front hairline sits where a hairline sits.
		var around := TAU * (float(i) / float(curls)) + rng.randf_range(-0.3, 0.3)
		var lift := rng.randf_range(0.30, 0.95)
		var back := -cos(around) * 0.30
		head.add_child(_sphere(
			Vector3(sin(around) * seat * (1.0 - lift * 0.45),
				head_r * (0.34 + lift * 0.62),
				cos(around) * seat * (1.0 - lift * 0.45) + back * head_r),
			rng.randf_range(0.026, 0.042), hair, 7, 4))

	# A fringe, low at the front, so the hair has an edge rather than stopping
	# wherever the last ball happened to land.
	for side in [-1.0, 1.0]:
		head.add_child(_sphere(
			Vector3(side * head_r * 0.46, head_r * 0.52, head_r * 0.62),
			rng.randf_range(0.024, 0.032), hair, 7, 4))

	# Some of them do wear something, and when they do it is a soft thing that
	# sits down on the hair rather than a cone standing up off a bald head.
	if rng.randf() < 0.22:
		var crown := _sphere(Vector3(0, head_r * 0.92, -0.006),
			head_r * 0.96, hat, 9, 5)
		crown.scale = Vector3(1.0, 0.58, 1.0)
		head.add_child(crown)
		var brim := _sphere(Vector3(0, head_r * 0.74, 0.004),
			head_r * 1.34, hat, 10, 4)
		brim.scale = Vector3(1.0, 0.12, 1.0)
		head.add_child(brim)
		head.add_child(_capsule(Vector3(0, head_r * 0.86, 0),
			head_r * 0.99, 0.006, trim))


func _capsule(at: Vector3, radius: float, height: float,
		mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height + radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 3
	return _instance(mesh, at, mat)


func _sphere(at: Vector3, radius: float, mat: Material,
		segs := 9, rings := 5) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segs
	mesh.rings = rings
	return _instance(mesh, at, mat)


func _cone(at: Vector3, radius: float, height: float,
		mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 9
	mesh.rings = 1
	return _instance(mesh, at, mat)


func _instance(mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
