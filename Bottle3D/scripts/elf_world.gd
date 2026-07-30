class_name ElfWorld
extends World

## Elves in a Bottle.
##
## They arrive while the phone is left alone and busy themselves with work
## nobody can quite make out. Moving the phone is an earthquake and some flee.
##
## The first pass read as ghosts, and it was three things stacked rather than
## one: pale skin under a cold blue fill, no faces, and nothing under their
## feet. Warm light, eyes, and a floor between them. Faces do most of the work -
## a blank head at this size is uncanny however good the silhouette is.

const TUNIC := Color("46A05E")
const TRIM := Color("E8C36A")
const SKIN := Color("F0BE92")
const HAT := Color("D2503F")
const BOOT := Color("6B4630")
const EYE := Color("2A1F1A")
const CHEEK := Color("E28C7A")
# Dark. A pale floor takes over the frame and turns the scene into a lit stage
# rather than something glimpsed in a bottle.
const FLOOR := Color("171426")

class Elf:
	var node: Node3D
	var arms: Array[Node3D] = []
	var legs: Array[Node3D] = []
	var target: Vector3
	var phase: float
	var restless: float
	var grown: float = 0.0

var _elves: Array[Elf] = []
var _time: float = 0.0
var _quake: float = 0.0


func _init() -> void:
	title = "Elves in a Bottle"
	capacity = 11
	spawn_seconds = 1.6

	# They stand on a floor. Pulled further back than the first framing, which
	# was set when they were slighter - at the new proportions it cropped them.
	focus = Vector3(0, -0.52, 0)
	distance = 4.9

	# Warm lamplight, and a fill that is warm-neutral rather than blue. The blue
	# fill is what made the skin look dead.
	key_color = Color("FFE3B8")
	key_energy = 1.45
	fill_color = Color("8C7FB8")
	fill_energy = 0.45
	ambient_color = Color("3A3050")
	ambient_energy = 0.85


func build() -> void:
	# Something under their feet. Figures floating in a void read as apparitions
	# however they are lit.
	var disc := CylinderMesh.new()
	disc.top_radius = 2.30
	disc.bottom_radius = 2.30
	disc.height = 0.05
	disc.radial_segments = 24
	disc.rings = 1

	var floor_node := MeshInstance3D.new()
	floor_node.mesh = disc
	floor_node.position = Vector3(0, _floor_y() - 0.025, 0)
	floor_node.material_override = World.solid_material(FLOOR, 0.95)
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_node)


func held() -> int:
	return _elves.size()


func _tick(delta: float, _population: int, _disturbed: bool) -> void:
	_time += delta
	_quake = maxf(0.0, _quake - delta * 1.4)

	# The bottle is shaken, not each elf, so they all lurch together.
	position = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) \
		* _quake * 0.09

	for i in _elves.size():
		var e := _elves[i]

		if e.grown < 1.0:
			e.grown = minf(e.grown + delta / 1.4, 1.0)
		e.node.scale = Vector3.ONE * (0.2 + 0.8 * e.grown)

		# Ambiguous work: drift somewhere, arrive, pick somewhere else. Never
		# explained, because explaining it would ruin it.
		e.restless -= delta
		if e.restless <= 0.0:
			e.target = _somewhere()
			e.restless = randf_range(4.0, 13.0)

		var toward := e.target - e.node.position
		toward.y = 0.0
		if toward.length() > 0.02:
			e.node.position += toward.normalized() * minf(delta * 0.28, toward.length())
			e.node.rotation.y = lerp_angle(e.node.rotation.y,
				atan2(toward.x, toward.z), delta * 2.0)

		var walking: float = clampf(toward.length() * 4.0, 0.0, 1.0)
		var swing := sin(_time * 3.0 + e.phase) * 0.5 * walking

		for a in e.arms.size():
			e.arms[a].rotation.x = swing * (1.0 if a == 0 else -1.0)
		for l in e.legs.size():
			e.legs[l].rotation.x = -swing * (1.0 if l == 0 else -1.0)

		# A bounce while walking and a slow breath while standing, so nobody is
		# ever perfectly still.
		var bounce := absf(sin(_time * 3.0 + e.phase)) * 0.022 * walking
		var breath := sin(_time * 1.1 + e.phase) * 0.006 * (1.0 - walking)
		e.node.position.y = _floor_y() + bounce + breath


func _grow() -> bool:
	if _elves.size() >= capacity:
		return false

	var e := Elf.new()
	e.phase = randf() * TAU
	e.restless = randf_range(1.0, 6.0)
	e.node = _build_body(e)

	# Placed away from the others. Purely random placement clumps, and a third
	# of the bottle ends up empty while the rest is a pile.
	var best := _somewhere()
	var best_gap := -1.0
	for _try in 12:
		var candidate := _somewhere()
		var gap := 99.0
		for other in _elves:
			gap = minf(gap, candidate.distance_to(other.node.position))
		if gap > best_gap:
			best_gap = gap
			best = candidate

	e.node.position = best
	e.target = best
	# Facing roughly toward the viewer. Fully random rotation meant most of them
	# had their backs turned and the faces - the whole point of the pass - were
	# never seen.
	e.node.rotation.y = randf_range(-0.8, 0.8)

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
		_elves[index].node.queue_free()
		_elves.remove_at(index)


func _floor_y() -> float:
	return -0.95


func _somewhere() -> Vector3:
	# Spread across the width, shallow in depth. A circle wastes the wide screen
	# and puts half of them behind each other.
	return Vector3(randf_range(-1.95, 1.95), _floor_y(), randf_range(-0.5, 0.45))


## A small round figure: big head, short limbs, pointed hat, and a face.
##
## Proportions are deliberately chunky. Slender is elegant and cold; short limbs
## and an oversized head are what read as friendly at a glance, and this is a
## thing you glance at.
func _build_body(e: Elf) -> Node3D:
	var root := Node3D.new()

	var tunic := World.solid_material(TUNIC, 0.85)
	var trim := World.solid_material(TRIM, 0.45)
	var skin := World.solid_material(SKIN, 0.75)
	var hat := World.solid_material(HAT, 0.85)
	var boot := World.solid_material(BOOT, 0.9)
	var eye := World.solid_material(EYE, 0.35)
	var cheek := World.solid_material(CHEEK, 0.8)

	# Body: nearly as wide as it is tall, so it reads as a small round person.
	root.add_child(_capsule(Vector3(0, 0.185, 0), 0.090, 0.135, tunic))
	root.add_child(_capsule(Vector3(0, 0.115, 0), 0.092, 0.020, trim))

	# Head, large on purpose.
	root.add_child(_sphere(Vector3(0, 0.360, 0), 0.082, skin))

	# The face. Two eyes and two cheeks is the whole of it, and it is the
	# difference between a character and an apparition.
	for side in [-1.0, 1.0]:
		root.add_child(_sphere(Vector3(side * 0.030, 0.372, 0.070), 0.0135, eye))
		root.add_child(_sphere(Vector3(side * 0.056, 0.338, 0.058), 0.017, cheek))

	# Ears, swept back and up.
	for side in [-1.0, 1.0]:
		var ear := _cone(Vector3(side * 0.072, 0.378, -0.012), 0.024, 0.070, skin)
		ear.rotation = Vector3(0.25, 0.0, side * -1.0)
		root.add_child(ear)

	# Hat, clearing the crown so the surfaces do not interpenetrate, with a brim
	# wide enough to read as separate clothing and a bobble on the tip.
	var cap := _cone(Vector3(0, 0.545, -0.030), 0.086, 0.215, hat)
	cap.rotation.x = -0.26
	root.add_child(cap)
	root.add_child(_capsule(Vector3(0, 0.437, 0), 0.092, 0.012, trim))
	# On the tip, not near it: the cone leans back 0.26 radians, so the tip lands
	# at 0.649 and -0.058 rather than straight above the brim.
	root.add_child(_sphere(Vector3(0, 0.649, -0.058), 0.030, trim))

	# Arms and legs on pivots, so they swing from the shoulder and hip.
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.092, 0.255, 0)
		shoulder.add_child(_capsule(Vector3(0, -0.058, 0), 0.030, 0.062, tunic))
		shoulder.add_child(_sphere(Vector3(0, -0.108, 0), 0.028, skin))
		root.add_child(shoulder)
		e.arms.append(shoulder)

		var hip := Node3D.new()
		hip.position = Vector3(side * 0.042, 0.100, 0)
		hip.add_child(_capsule(Vector3(0, -0.040, 0), 0.032, 0.045, trim))
		hip.add_child(_sphere(Vector3(0, -0.082, 0.012), 0.036, boot))
		root.add_child(hip)
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
