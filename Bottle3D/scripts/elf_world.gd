class_name ElfWorld
extends World

## Elves in a Bottle.
##
## A workshop that actually runs. There is a chain - ore is cut from the seam,
## beaten into ingots at the anvil, boiled down to sparks at the cauldron, and
## fed to the lamp, which is the only reason any of it happens. Starve any link
## and everything downstream stalls, and the lamp goes dim.
##
## Nothing here is animation. Every ore, ingot and spark is a real object that
## sits in a pile until somebody lifts it, travels in their hands, and is set
## down somewhere else. Piles get shorter when things are taken from them. An
## earlier version faked all of this: a crate blinked into a carrier's hands and
## the two stacks it moved between never changed, which is a scene playing back
## rather than work being done.
##
## The elves are not running a script either. Each one has traits it keeps for
## life - how fast it walks, how long it works before it needs a sit down, what
## job it likes, whether it prefers company - and every time it finishes
## something it looks at the whole workshop and decides what is worth doing now.
## Because they all score the same situation through different traits, they
## divide the labour themselves, and a jam somewhere pulls whoever is nearest
## and least busy toward it. Two elves never do the same thing for the same
## reason.

const TUNIC := Color("46A05E")
const TRIM := Color("E8C36A")
const SKIN := Color("F0BE92")
const HAT := Color("D2503F")
const BOOT := Color("6B4630")
const EYE := Color("2A1F1A")
const CHEEK := Color("E28C7A")
const WOOD := Color("6B4A32")
const IRON := Color("3E4550")
const EMBER := Color("FF9A4A")
const ROCK := Color("57606E")
const INGOT_COLOR := Color("FF9E5C")
const SPARK_COLOR := Color("9BE8FF")
const FLOOR := Color("171426")

enum Kind { ORE, INGOT, SPARK }
enum Task { NONE, CUT, CARRY, FORGE, BREW, FEED, REST, IDLE }

const FLOOR_Y := -0.95


## A heap of real things. Items are meshes that live here until someone takes
## one, and the heap visibly shortens when they do.
class Pile:
	var kind: Kind
	var at: Vector3
	var stand: Vector3
	var items: Array[Node3D] = []
	var limit := 6

	func room() -> bool:
		return items.size() < limit

	func count() -> int:
		return items.size()

	## Stacked in a rough spiral so a full pile is a heap and not a tower.
	func settle() -> void:
		for i in items.size():
			var ring := i / 3
			var slot := i % 3
			var angle := TAU * float(slot) / 3.0 + float(ring) * 0.7
			items[i].position = at + Vector3(
				cos(angle) * 0.085 * (0.4 if ring == 0 else 1.0),
				0.045 + float(ring) * 0.075,
				sin(angle) * 0.085 * (0.4 if ring == 0 else 1.0))


class Bench:
	var task: Task
	var stand: Vector3
	var taken_by: int = -1
	var input: Pile
	var output: Pile
	var progress := 0.0
	var duration := 6.0


class Elf:
	var id: int
	var node: Node3D
	var arms: Array[Node3D] = []
	var legs: Array[Node3D] = []

	# Kept for life. Two elves given the same situation reach different
	# conclusions because these differ, which is the whole of the division of
	# labour here - nobody is assigned anything.
	var pace := 0.30
	var stamina := 1.0
	var likes: Task = Task.NONE
	var sociable := 0.0
	var fidget := 0.0

	var energy := 1.0
	var task: Task = Task.NONE
	var bench: Bench
	var from_pile: Pile
	var to_pile: Pile
	var carrying: Node3D
	var carry_kind: Kind
	var tool: Node3D
	var target: Vector3
	var work_left := 0.0
	var pause := 0.0
	var grown := 0.0
	var phase := 0.0
	var last_task: Task = Task.NONE

var _elves: Array[Elf] = []
var _piles: Array[Pile] = []
var _benches: Array[Bench] = []

var _seam_out: Pile
var _anvil_in: Pile
var _anvil_out: Pile
var _pot_in: Pile
var _pot_out: Pile

var _hearth := Vector3(-1.95, FLOOR_Y, 0.42)
var _lamp_stand := Vector3(0.35, FLOOR_Y, 0.10)
var _lamp_at := Vector3(0.05, FLOOR_Y, -0.42)

## What the whole workshop is for. Burns down on its own and is topped up by
## sparks, so a stalled chain is visible as the room going dark.
var _lamp_fuel := 0.55
var _lamp_node: MeshInstance3D
var _lamp_light: OmniLight3D

var _time := 0.0
var _quake := 0.0
var _next_id := 0


func _init() -> void:
	title = "Elves in a Bottle"
	capacity = 11
	spawn_seconds = 1.6

	focus = Vector3(0, -0.58, 0)
	distance = 3.5

	key_color = Color("FFE3B8")
	key_energy = 1.45
	fill_color = Color("8C7FB8")
	fill_energy = 0.45
	ambient_color = Color("3A3050")
	ambient_energy = 0.85


func build() -> void:
	_build_floor()
	_build_seam(Vector3(-1.55, FLOOR_Y, -0.15))
	_build_anvil(Vector3(-0.45, FLOOR_Y, -0.10))
	_build_cauldron(Vector3(0.95, FLOOR_Y, -0.15))
	_build_lamp(_lamp_at)
	_build_hearth(_hearth)


func held() -> int:
	return _elves.size()


func _tick(delta: float, _population: int, _disturbed: bool) -> void:
	_time += delta
	_quake = maxf(0.0, _quake - delta * 1.4)

	position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) \
		* _quake * 0.09

	# The lamp burns whether anyone tends it or not. This is the clock the whole
	# workshop runs against: let the chain stall and the room dims.
	_lamp_fuel = maxf(0.0, _lamp_fuel - delta * 0.012)
	var glow := 0.25 + _lamp_fuel * 1.9
	if _lamp_node:
		var mat: StandardMaterial3D = _lamp_node.material_override
		mat.emission_energy_multiplier = glow + sin(_time * 1.7) * 0.12
	if _lamp_light:
		_lamp_light.light_energy = 0.25 + _lamp_fuel * 1.5

	for e in _elves:
		_tick_elf(e, delta)


# --- the mind ----------------------------------------------------------------

## Everything an elf does comes through here. It is called whenever one has
## nothing in hand and nothing in progress, and it scores the whole workshop
## rather than following an order.
func _decide(e: Elf) -> void:
	e.bench = null
	e.from_pile = null
	e.to_pile = null

	# Tiredness is not a rule, it is a weight. A stubborn elf will keep working
	# well past the point a soft one has gone to sit down.
	if e.energy < 0.18 * e.stamina:
		e.task = Task.REST
		e.target = _hearth + Vector3(randf_range(-0.18, 0.18), 0, randf_range(-0.1, 0.1))
		return

	var best := Task.IDLE
	var best_score := 0.35 + e.fidget
	var best_bench: Bench = null
	var best_from: Pile = null
	var best_to: Pile = null

	# Feeding the lamp. Gets more urgent the darker it gets, which is what pulls
	# everyone toward the end of the chain when the room starts to fade.
	if _pot_out.count() > 0:
		var score := (1.6 - _lamp_fuel) * 1.4
		score = _weigh(e, Task.FEED, score, _pot_out.stand)
		if score > best_score:
			best_score = score
			best = Task.FEED
			best_from = _pot_out

	# Moving stock along. Urgency comes from how starved the next step is, so a
	# hungry cauldron pulls carriers without anybody scheduling them.
	for pair in [[_anvil_out, _pot_in], [_seam_out, _anvil_in]]:
		var from: Pile = pair[0]
		var to: Pile = pair[1]
		if from.count() > 0 and to.room():
			var score := 0.55 + float(from.count()) * 0.16 \
				+ (0.5 if to.count() == 0 else 0.0)
			score = _weigh(e, Task.CARRY, score, from.stand)
			if score > best_score:
				best_score = score
				best = Task.CARRY
				best_from = from
				best_to = to

	# Standing at a bench. Only if it is free and has something to work on.
	for b in _benches:
		if b.taken_by != -1 and b.taken_by != e.id:
			continue
		if b.input and b.input.count() == 0:
			continue
		if b.output and not b.output.room():
			continue
		var score := 0.75 + (0.25 if b.input == null else float(b.input.count()) * 0.12)
		score = _weigh(e, b.task, score, b.stand)
		if score > best_score:
			best_score = score
			best = b.task
			best_bench = b
			best_from = null
			best_to = null

	e.task = best
	e.bench = best_bench
	e.from_pile = best_from
	e.to_pile = best_to

	match best:
		Task.FEED, Task.CARRY:
			e.target = best_from.stand
		Task.IDLE:
			# Their own time. Wandering, looking at things, standing near
			# someone. Not filler: an elf that never does anything unprompted
			# reads as a machine waiting for input.
			e.target = _somewhere_own(e)
			e.pause = randf_range(1.5, 5.0)
		_:
			if best_bench:
				best_bench.taken_by = e.id
				e.target = best_bench.stand


## Traits applied to a raw urgency. Distance, taste, tiredness, and a pull
## toward or away from whoever else is about.
func _weigh(e: Elf, task: Task, score: float, at: Vector3) -> float:
	var away := e.node.position.distance_to(at)
	score -= away * 0.16

	if task == e.likes:
		score += 0.55
	# Sticking with what they were doing, so nobody flickers between two jobs
	# that happen to score alike.
	if task == e.last_task:
		score += 0.22

	score *= lerpf(0.55, 1.0, e.energy)

	if absf(e.sociable) > 0.01:
		var near := 0
		for other in _elves:
			if other.id != e.id and other.node.position.distance_to(at) < 0.75:
				near += 1
		score += float(near) * e.sociable * 0.18

	return score


func _somewhere_own(e: Elf) -> Vector3:
	if e.sociable > 0.15 and _elves.size() > 1:
		# Drift over to whoever is working and watch.
		var other: Elf = _elves[randi() % _elves.size()]
		if other.id != e.id:
			return other.node.position + Vector3(randf_range(-0.4, 0.4), 0,
				randf_range(0.2, 0.45))
	return Vector3(randf_range(-2.0, 2.0), FLOOR_Y, randf_range(-0.2, 0.5))


# --- the body ----------------------------------------------------------------

func _tick_elf(e: Elf, delta: float) -> void:
	if e.grown < 1.0:
		e.grown = minf(e.grown + delta / 1.4, 1.0)
	e.node.scale = Vector3.ONE * (0.2 + 0.8 * e.grown)

	if e.task == Task.NONE:
		_decide(e)

	var toward := e.target - e.node.position
	toward.y = 0.0
	var arrived := toward.length() < 0.08

	if not arrived:
		e.node.position += toward.normalized() * minf(delta * e.pace, toward.length())
		e.node.rotation.y = lerp_angle(e.node.rotation.y,
			atan2(toward.x, toward.z), delta * 2.5)
	else:
		_act(e, delta)

	_animate(e, delta, not arrived)

	# Working costs, walking costs less, sitting pays back.
	if e.task == Task.REST and arrived:
		e.energy = minf(1.0, e.energy + delta * 0.10)
	elif e.work_left > 0.0:
		e.energy = maxf(0.0, e.energy - delta * 0.016)
	else:
		e.energy = maxf(0.0, e.energy - delta * 0.005)


func _act(e: Elf, delta: float) -> void:
	match e.task:
		Task.REST:
			e.pause -= delta
			if e.energy > 0.92:
				_finish(e)

		Task.IDLE:
			e.pause -= delta
			if e.pause <= 0.0:
				_finish(e)

		Task.CARRY, Task.FEED:
			if e.carrying == null:
				# Lift a real item out of a real heap. If somebody beat them to
				# the last one, think again rather than mime it.
				if e.from_pile.count() == 0:
					_finish(e)
					return
				_lift(e, e.from_pile)
				e.target = (_lamp_stand if e.task == Task.FEED else e.to_pile.stand)
			else:
				if e.task == Task.FEED:
					_burn(e)
				else:
					_drop(e, e.to_pile)

		Task.CUT, Task.FORGE, Task.BREW:
			var b := e.bench
			if b == null:
				_finish(e)
				return
			if b.input and b.input.count() == 0:
				_finish(e)
				return
			if b.output and not b.output.room():
				_finish(e)
				return

			if e.work_left <= 0.0:
				e.work_left = b.duration * randf_range(0.85, 1.2)
			if e.tool == null:
				_take_tool(e, b.task)

			e.work_left -= delta * lerpf(0.6, 1.25, e.energy)
			if e.work_left <= 0.0:
				_produce(e, b)


## One piece finished. Consumes from the input heap and puts a new thing on the
## output heap, so the counts either side of a bench actually move.
func _produce(e: Elf, b: Bench) -> void:
	if b.input and b.input.count() > 0:
		var used: Node3D = b.input.items.pop_back()
		used.queue_free()
		b.input.settle()

	if b.output and b.output.room():
		var made := _make_item(b.output.kind)
		add_child(made)
		b.output.items.append(made)
		b.output.settle()

	e.work_left = 0.0

	# Diligence decides whether they stay on it or wander off after one.
	if randf() > e.stamina * 0.75:
		_finish(e)


func _lift(e: Elf, pile: Pile) -> void:
	var item: Node3D = pile.items.pop_back()
	pile.settle()

	# Reparented, not duplicated. It is the same object in their hands that was
	# on the heap a moment ago.
	remove_child(item)
	e.node.add_child(item)
	item.position = Vector3(0, 0.215, 0.17)
	item.rotation = Vector3(randf() * TAU, randf() * TAU, 0)

	e.carrying = item
	e.carry_kind = pile.kind


func _drop(e: Elf, pile: Pile) -> void:
	if not pile.room():
		# Nowhere to put it. Hang on to it and find somewhere, rather than
		# deleting it, which would quietly leak stock out of the workshop.
		e.target = _hearth
		return

	var item := e.carrying
	e.node.remove_child(item)
	add_child(item)
	pile.items.append(item)
	pile.settle()

	e.carrying = null
	_finish(e)


func _burn(e: Elf) -> void:
	e.node.remove_child(e.carrying)
	e.carrying.queue_free()
	e.carrying = null
	_lamp_fuel = minf(1.0, _lamp_fuel + 0.22)
	_finish(e)


## A tool in the hand, and a workpiece to swing it at. Without both, the arm
## motion is just a body moving on its own, which reads badly however the
## numbers are tuned - the fix is the prop, not the curve.
func _take_tool(e: Elf, task: Task) -> void:
	var tool := Node3D.new()

	if task == Task.BREW:
		# Ladle: a shaft with a bowl on the end, held down into the pot.
		var shaft := MeshInstance3D.new()
		var rod := CapsuleMesh.new()
		rod.radius = 0.011
		rod.height = 0.26
		rod.radial_segments = 6
		rod.rings = 2
		shaft.mesh = rod
		shaft.position = Vector3(0, -0.09, 0)
		shaft.material_override = World.solid_material(WOOD, 0.9)
		tool.add_child(shaft)

		var bowl := MeshInstance3D.new()
		var cup := SphereMesh.new()
		cup.radius = 0.038
		cup.height = 0.050
		cup.radial_segments = 8
		cup.rings = 4
		bowl.mesh = cup
		bowl.position = Vector3(0, -0.215, 0)
		bowl.material_override = World.solid_material(IRON, 0.5)
		tool.add_child(bowl)
	else:
		# Hammer: a haft with a head across the top.
		var haft := MeshInstance3D.new()
		var rod := CapsuleMesh.new()
		rod.radius = 0.012
		rod.height = 0.20
		rod.radial_segments = 6
		rod.rings = 2
		haft.mesh = rod
		haft.position = Vector3(0, -0.07, 0)
		haft.material_override = World.solid_material(WOOD, 0.9)
		tool.add_child(haft)

		var head := MeshInstance3D.new()
		var block := BoxMesh.new()
		block.size = Vector3(0.10, 0.045, 0.045)
		head.mesh = block
		head.position = Vector3(0, -0.185, 0)
		head.material_override = World.solid_material(IRON, 0.4)
		tool.add_child(head)

	# Hangs from the hand at the end of the arm.
	tool.position = Vector3(0, -0.125, 0.02)
	e.arms[0].add_child(tool)
	e.tool = tool


func _drop_tool(e: Elf) -> void:
	if e.tool:
		e.tool.queue_free()
		e.tool = null


func _finish(e: Elf) -> void:
	_drop_tool(e)
	if e.bench and e.bench.taken_by == e.id:
		e.bench.taken_by = -1
	e.last_task = e.task
	e.task = Task.NONE
	e.work_left = 0.0
	e.pause = 0.0


func _animate(e: Elf, delta: float, walking_now: bool) -> void:
	var walking := 1.0 if walking_now else 0.0
	var stride := sin(_time * 3.0 * (e.pace / 0.30) + e.phase) * 0.5 * walking

	for l in e.legs.size():
		e.legs[l].rotation.x = -stride * (1.0 if l == 0 else -1.0)

	var arm_a := stride
	var arm_b := -stride

	if e.carrying:
		arm_a = -1.35
		arm_b = -1.35
	elif not walking_now and e.work_left > 0.0 and e.tool != null:
		match e.task:
			Task.CUT, Task.FORGE:
				# A sharp fall and a slow lift, because a hammer is not a
				# metronome. The beat is theirs, not the world's.
				var beat := fposmod(_time * (1.1 + e.pace) + e.phase, 1.0)
				var swing: float = (1.0 - beat) if beat < 0.25 else (beat - 0.25) / 0.75

				# Shallow, and across the body rather than straight up and down.
				# A full vertical range with an empty hand reads as something
				# other than work; angled, with a hammer in it and an anvil
				# under it, it reads as striking.
				arm_a = -1.05 + swing * 0.80
				arm_b = -0.55
				e.arms[0].rotation.z = -0.42 - swing * 0.22
				e.node.rotation.x = swing * 0.07
			Task.BREW:
				# Both hands on the ladle, going round the pot.
				var turn := _time * 1.4 + e.phase
				arm_a = -1.05 + sin(turn) * 0.18
				arm_b = -1.00 + cos(turn) * 0.14
				e.arms[0].rotation.z = -0.20 + cos(turn) * 0.18
				e.node.rotation.z = sin(turn) * 0.05
	elif e.task == Task.REST and not walking_now:
		arm_a = 0.25
		arm_b = 0.25

	if e.tool == null:
		# Nothing in hand, so nothing to swing. Arms return to the walk.
		e.arms[0].rotation.z = lerpf(e.arms[0].rotation.z, 0.0, clampf(delta * 6.0, 0, 1))
		e.node.rotation.x = lerpf(e.node.rotation.x, 0.0, clampf(delta * 6.0, 0, 1))
		e.node.rotation.z = lerpf(e.node.rotation.z, 0.0, clampf(delta * 6.0, 0, 1))

	e.arms[0].rotation.x = lerpf(e.arms[0].rotation.x, arm_a, clampf(delta * 8.0, 0, 1))
	e.arms[1].rotation.x = lerpf(e.arms[1].rotation.x, arm_b, clampf(delta * 8.0, 0, 1))

	var bounce := absf(sin(_time * 3.0 + e.phase)) * 0.022 * walking
	var breath := sin(_time * 1.1 + e.phase) * 0.006 * (1.0 - walking)
	var sit := -0.055 if (e.task == Task.REST and not walking_now) else 0.0
	e.node.position.y = FLOOR_Y + bounce + breath + sit


# --- arrivals and departures -------------------------------------------------

func _grow() -> bool:
	if _elves.size() >= capacity:
		return false

	var e := Elf.new()
	e.id = _next_id
	_next_id += 1

	# Born different, and it sticks. These are what make one elf a hauler and
	# another a smith without anybody deciding it.
	e.pace = randf_range(0.22, 0.40)
	e.stamina = randf_range(0.55, 1.0)
	e.sociable = randf_range(-0.25, 0.40)
	e.fidget = randf_range(0.0, 0.45)
	e.likes = [Task.CUT, Task.FORGE, Task.BREW, Task.CARRY, Task.FEED][randi() % 5]
	e.phase = randf() * TAU
	e.energy = randf_range(0.7, 1.0)

	e.node = _build_body(e)
	e.node.position = Vector3(randf_range(-2.2, 2.2), FLOOR_Y, 0.55)
	e.node.rotation.y = randf_range(-0.8, 0.8)
	e.target = e.node.position

	add_child(e.node)
	_elves.append(e)
	return true


func _shrink() -> void:
	_quake = 1.0

	var leaving := int(ceil(float(_elves.size()) * LOSS_FRACTION))
	for _i in leaving:
		if _elves.size() <= 1:
			return
		var index := randi() % _elves.size()
		var e := _elves[index]

		# Whatever they were holding is put back rather than vanishing with
		# them, and their bench is freed for whoever arrives next.
		if e.carrying:
			var item := e.carrying
			e.node.remove_child(item)
			add_child(item)
			var home := _pile_for(e.carry_kind)
			if home and home.room():
				home.items.append(item)
				home.settle()
			else:
				item.queue_free()
		if e.bench and e.bench.taken_by == e.id:
			e.bench.taken_by = -1
		_drop_tool(e)

		e.node.queue_free()
		_elves.remove_at(index)


func _pile_for(kind: Kind) -> Pile:
	for p in _piles:
		if p.kind == kind and p.room():
			return p
	return null


# --- the workshop ------------------------------------------------------------

func _make_pile(kind: Kind, at: Vector3, stand: Vector3) -> Pile:
	var p := Pile.new()
	p.kind = kind
	p.at = at
	p.stand = Vector3(stand.x, FLOOR_Y, stand.z)
	_piles.append(p)
	return p


func _make_item(kind: Kind) -> Node3D:
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	match kind:
		Kind.ORE:
			node.mesh = Geometry.crystal(0.055, 0.30)
			node.material_override = World.solid_material(ROCK, 0.9)
		Kind.INGOT:
			var box := BoxMesh.new()
			box.size = Vector3(0.11, 0.045, 0.06)
			node.mesh = box
			var mat := World.solid_material(INGOT_COLOR, 0.4)
			mat.emission_enabled = true
			mat.emission = INGOT_COLOR
			mat.emission_energy_multiplier = 0.5
			node.material_override = mat
		Kind.SPARK:
			var ball := SphereMesh.new()
			ball.radius = 0.042
			ball.height = 0.084
			ball.radial_segments = 8
			ball.rings = 5
			node.mesh = ball
			node.material_override = World.glow_material(SPARK_COLOR, 0.8)

	return node


func _make_bench(task: Task, stand: Vector3, input: Pile, output: Pile,
                 duration: float) -> void:
	var b := Bench.new()
	b.task = task
	b.stand = Vector3(stand.x, FLOOR_Y, stand.z)
	b.input = input
	b.output = output
	b.duration = duration
	_benches.append(b)


func _build_floor() -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 2.45
	disc.bottom_radius = 2.45
	disc.height = 0.05
	disc.radial_segments = 24
	disc.rings = 1

	var node := MeshInstance3D.new()
	node.mesh = disc
	node.position = Vector3(0, FLOOR_Y - 0.025, 0)
	node.material_override = World.solid_material(FLOOR, 0.95)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _build_seam(at: Vector3) -> void:
	# An outcrop to cut ore from. The only thing in here with no input.
	for i in 3:
		var rock := MeshInstance3D.new()
		rock.mesh = Geometry.crystal(randf_range(0.12, 0.20), 0.35)
		rock.position = at + Vector3(randf_range(-0.16, 0.16), 0.10,
			randf_range(-0.10, 0.10))
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		rock.material_override = World.solid_material(ROCK, 0.95)
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rock)

	_seam_out = _make_pile(Kind.ORE, at + Vector3(0.32, 0, 0.16),
		at + Vector3(0.32, 0, 0.42))
	_make_bench(Task.CUT, at + Vector3(0, 0, 0.30), null, _seam_out, 7.0)


func _build_anvil(at: Vector3) -> void:
	var wood := World.solid_material(WOOD, 0.9)
	var iron := World.solid_material(IRON, 0.45)

	_box(at + Vector3(0, 0.22, 0), Vector3(0.30, 0.045, 0.16), wood)
	for side in [-1.0, 1.0]:
		_box(at + Vector3(side * 0.22, 0.11, 0), Vector3(0.045, 0.115, 0.045), wood)
	_box(at + Vector3(0, 0.30, 0), Vector3(0.11, 0.045, 0.085), iron)

	_anvil_in = _make_pile(Kind.ORE, at + Vector3(-0.42, 0, 0.10),
		at + Vector3(-0.42, 0, 0.38))
	_anvil_out = _make_pile(Kind.INGOT, at + Vector3(0.42, 0, 0.10),
		at + Vector3(0.42, 0, 0.38))
	_make_bench(Task.FORGE, at + Vector3(0, 0, 0.30), _anvil_in, _anvil_out, 5.5)


func _build_cauldron(at: Vector3) -> void:
	var iron := World.solid_material(IRON, 0.5)

	var pot := SphereMesh.new()
	pot.radius = 0.22
	pot.height = 0.34
	pot.radial_segments = 12
	pot.rings = 6
	var pot_node := MeshInstance3D.new()
	pot_node.mesh = pot
	pot_node.position = at + Vector3(0, 0.18, 0)
	pot_node.material_override = iron
	pot_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pot_node)

	var brew := CylinderMesh.new()
	brew.top_radius = 0.155
	brew.bottom_radius = 0.155
	brew.height = 0.02
	brew.radial_segments = 12
	var brew_node := MeshInstance3D.new()
	brew_node.mesh = brew
	brew_node.position = at + Vector3(0, 0.305, 0)
	brew_node.material_override = World.glow_material(SPARK_COLOR, 0.7)
	brew_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(brew_node)

	_pot_in = _make_pile(Kind.INGOT, at + Vector3(-0.40, 0, 0.10),
		at + Vector3(-0.40, 0, 0.38))
	_pot_out = _make_pile(Kind.SPARK, at + Vector3(0.40, 0, 0.10),
		at + Vector3(0.40, 0, 0.38))
	_make_bench(Task.BREW, at + Vector3(0, 0, 0.30), _pot_in, _pot_out, 6.5)


func _build_lamp(at: Vector3) -> void:
	_box(at + Vector3(0, 0.30, 0), Vector3(0.028, 0.30, 0.028),
		World.solid_material(IRON, 0.5))

	var globe := SphereMesh.new()
	globe.radius = 0.085
	globe.height = 0.17
	globe.radial_segments = 10
	globe.rings = 6

	_lamp_node = MeshInstance3D.new()
	_lamp_node.mesh = globe
	_lamp_node.position = at + Vector3(0, 0.64, 0)
	_lamp_node.material_override = World.glow_material(EMBER, 0.85)
	_lamp_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_lamp_node)

	_lamp_light = OmniLight3D.new()
	_lamp_light.position = at + Vector3(0, 0.64, 0)
	_lamp_light.light_color = EMBER
	_lamp_light.omni_range = 2.8
	_lamp_light.shadow_enabled = false
	add_child(_lamp_light)


func _build_hearth(at: Vector3) -> void:
	# Somewhere to sit down. Not decoration: an elf out of energy walks here and
	# stays until it has some back.
	var wood := World.solid_material(WOOD, 0.95)
	_box(at + Vector3(0, 0.075, 0), Vector3(0.30, 0.075, 0.14), wood)


func _box(at: Vector3, half: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = half * 2.0
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


# --- the elf -----------------------------------------------------------------

## No two the same.
##
## Eleven of one figure reads as a production line however well it moves, so
## every elf is rolled at birth: height, girth, head size, skin, cloth, hat
## shape, ear length, eye spacing, and whether it has a beard. All of it is
## fixed for that elf's life, so you start recognising individuals.
func _build_body(e: Elf) -> Node3D:
	var root := Node3D.new()

	# An inner node carries the permanent build, leaving the outer one free for
	# the growing-in animation.
	var body := Node3D.new()
	var height := randf_range(0.86, 1.14)
	body.scale = Vector3(randf_range(0.92, 1.10), height, randf_range(0.92, 1.10))
	root.add_child(body)

	var girth := randf_range(0.078, 0.104)
	var head_r := randf_range(0.072, 0.094)

	var skins := [Color("F0BE92"), Color("E0A87A"), Color("C98A63"), Color("FAD3AE")]
	var cloths := [Color("46A05E"), Color("3B7FA8"), Color("8C5A9E"),
	               Color("B8623C"), Color("4F7A46"), Color("2F6E7A")]
	var hats := [Color("D2503F"), Color("B8792F"), Color("3E6BA8"),
	             Color("7A4470"), Color("C4923A")]
	var beards := [Color("EFEFE6"), Color("C9C4B4"), Color("C9843F")]

	var skin_c: Color = skins[randi() % skins.size()]
	var tunic := World.solid_material(cloths[randi() % cloths.size()], 0.85)
	var trim := World.solid_material(TRIM.lerp(Color("A8763A"), randf()), 0.45)
	var skin := World.solid_material(skin_c, 0.75)
	var hat := World.solid_material(hats[randi() % hats.size()], 0.85)
	var boot := World.solid_material(BOOT.lerp(Color("3A2B22"), randf()), 0.9)
	var eye := World.solid_material(EYE, 0.35)
	var cheek := World.solid_material(skin_c.lerp(CHEEK, 0.75), 0.8)

	body.add_child(_capsule(Vector3(0, 0.185, 0), girth, 0.135, tunic))
	body.add_child(_capsule(Vector3(0, 0.115, 0), girth + 0.002, 0.020, trim))

	var head_y := 0.360 + (head_r - 0.082) * 0.6
	body.add_child(_sphere(Vector3(0, head_y, 0), head_r, skin))

	# Faces differ most in the spacing and size of the eyes, which is what makes
	# one of these look like a different person rather than a recolour.
	var eye_gap := randf_range(0.025, 0.037)
	var eye_r := randf_range(0.0115, 0.0165)
	for side in [-1.0, 1.0]:
		body.add_child(_sphere(Vector3(side * eye_gap, head_y + 0.012,
			head_r * 0.86), eye_r, eye))
		body.add_child(_sphere(Vector3(side * (head_r * 0.68), head_y - 0.022,
			head_r * 0.70), randf_range(0.013, 0.020), cheek))

	# Roughly a third wear a beard.
	if randf() < 0.34:
		var whiskers := _capsule(Vector3(0, head_y - 0.048, head_r * 0.55),
			randf_range(0.030, 0.045), randf_range(0.010, 0.040),
			World.solid_material(beards[randi() % beards.size()], 0.9))
		body.add_child(whiskers)

	var ear_len := randf_range(0.052, 0.098)
	for side in [-1.0, 1.0]:
		var ear := _cone(Vector3(side * (head_r * 0.88), head_y + 0.018, -0.012),
			0.024, ear_len, skin)
		ear.rotation = Vector3(0.25, 0.0, side * -1.0)
		body.add_child(ear)

	# Hats vary in height and lean, which changes the silhouette more than any
	# amount of recolouring does.
	var hat_h := randf_range(0.16, 0.28)
	var lean := randf_range(-0.42, -0.10)
	var brim_y := head_y + head_r * 0.94
	var cap := _cone(Vector3(0, brim_y + hat_h * 0.5, -0.030), head_r * 1.05, hat_h, hat)
	cap.rotation.x = lean
	body.add_child(cap)
	body.add_child(_capsule(Vector3(0, brim_y, 0), head_r * 1.12, 0.012, trim))

	if randf() < 0.7:
		var tip := brim_y + hat_h
		body.add_child(_sphere(Vector3(0, tip * cos(lean) + 0.005,
			-0.030 + tip * sin(lean) * 0.35), randf_range(0.022, 0.034), trim))

	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * (girth + 0.004), 0.255, 0)
		shoulder.add_child(_capsule(Vector3(0, -0.058, 0), 0.030, 0.062, tunic))
		shoulder.add_child(_sphere(Vector3(0, -0.108, 0), 0.028, skin))
		body.add_child(shoulder)
		e.arms.append(shoulder)

		var hip := Node3D.new()
		hip.position = Vector3(side * 0.042, 0.100, 0)
		hip.add_child(_capsule(Vector3(0, -0.040, 0), 0.032, 0.045, trim))
		hip.add_child(_sphere(Vector3(0, -0.082, 0.012), 0.036, boot))
		body.add_child(hip)
		e.legs.append(hip)

	return root


func _capsule(at: Vector3, radius: float, height: float,
              mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height + radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 3
	return _instance(mesh, at, mat)


func _sphere(at: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 9
	mesh.rings = 5
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
