class_name ElfWorld
extends World

## Elves in a Bottle.
##
## They arrive while the phone is left alone and busy themselves with work
## nobody can quite make out. Moving the phone is an earthquake and some flee.
##
## Built from lit primitives rather than drawn as a silhouette. The flat version
## could not be rescued by tuning: a figure needs light falling across it to
## read as a body rather than a shape, and that is the whole argument for being
## in 3D here.

const TUNIC := Color("3E7A56")
const TRIM := Color("C8A860")
const SKIN := Color("E8C4A0")
const HAT := Color("2F5F8A")

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
	# They stand on a floor, so the camera aims low and close rather than at the
	# origin, which framed them against the bottom edge with an empty screen
	# above.
	focus = Vector3(0, -0.72, 0)
	distance = 2.6


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
		if toward.length() > 0.02:
			e.node.position += toward.normalized() * minf(delta * 0.28, toward.length())
			# Face the way they are going.
			var want := atan2(toward.x, toward.z)
			e.node.rotation.y = lerp_angle(e.node.rotation.y, want, delta * 2.0)

		var walking: float = clampf(toward.length() * 4.0, 0.0, 1.0)
		var swing := sin(_time * 3.0 + e.phase) * 0.5 * walking

		for a in e.arms.size():
			e.arms[a].rotation.x = swing * (1.0 if a == 0 else -1.0)
		for l in e.legs.size():
			e.legs[l].rotation.x = -swing * (1.0 if l == 0 else -1.0)

		# A small bob, so a standing elf is still alive.
		e.node.position.y = _floor_y() + abs(sin(_time * 3.0 + e.phase)) * 0.02 * walking


func _grow() -> bool:
	if _elves.size() >= capacity:
		return false

	var e := Elf.new()
	e.phase = randf() * TAU
	e.restless = randf_range(1.0, 6.0)
	e.node = _build_body()

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
	e.node.rotation.y = randf() * TAU

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
	var angle := randf() * TAU
	var radius := randf_range(0.15, 0.95)
	return Vector3(cos(angle) * radius, _floor_y(), sin(angle) * radius)


## A small figure: pointed hat, ears, tunic, arms and legs. Low segment counts
## throughout - it is 40cm tall on screen and the silhouette does the work.
func _build_body() -> Node3D:
	var root := Node3D.new()

	var tunic := World.solid_material(TUNIC, 0.9)
	var trim := World.solid_material(TRIM, 0.55)
	var skin := World.solid_material(SKIN, 0.8)
	var hat := World.solid_material(HAT, 0.9)

	root.add_child(_capsule(Vector3(0, 0.20, 0), 0.075, 0.20, tunic))
	root.add_child(_sphere(Vector3(0, 0.375, 0), 0.062, skin))

	# Ears, swept back and up. Small, but they are what says elf rather than
	# small person.
	for side in [-1.0, 1.0]:
		var ear := _cone(Vector3(side * 0.055, 0.40, -0.01), 0.022, 0.075, skin)
		ear.rotation = Vector3(0.2, 0.0, side * -0.9)
		root.add_child(ear)

	# Hat: a long cone leaning back, sitting on a brim.
	#
	# The cone's base has to clear the top of the skull. Sunk even slightly into
	# the sphere, the two surfaces interpenetrate and the intersection reads as a
	# jagged crown - which is exactly how it came out first time. Head centre is
	# 0.375 with radius 0.062, so the crown is at 0.437 and the cone of height
	# 0.20 centres at 0.545.
	var cap := _cone(Vector3(0, 0.545, -0.025), 0.070, 0.20, hat)
	cap.rotation.x = -0.24
	root.add_child(cap)

	# Brim, wider than the skull so it reads as a separate piece of clothing.
	root.add_child(_capsule(Vector3(0, 0.432, 0), 0.076, 0.010, trim))

	# Arms and legs hang from pivots so they swing from the shoulder and hip
	# rather than sliding.
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * 0.082, 0.285, 0)
		shoulder.add_child(_capsule(Vector3(0, -0.075, 0), 0.026, 0.10, tunic))
		root.add_child(shoulder)

		var hip := Node3D.new()
		hip.position = Vector3(side * 0.040, 0.105, 0)
		hip.add_child(_capsule(Vector3(0, -0.055, 0), 0.030, 0.075, trim))
		root.add_child(hip)

	return root


func _capsule(at: Vector3, radius: float, height: float,
              mat: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height + radius * 2.0
	mesh.radial_segments = 7
	mesh.rings = 3
	return _instance(mesh, at, mat)


func _sphere(at: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	return _instance(mesh, at, mat)


func _cone(at: Vector3, radius: float, height: float,
           mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 7
	mesh.rings = 1
	return _instance(mesh, at, mat)


func _instance(mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
