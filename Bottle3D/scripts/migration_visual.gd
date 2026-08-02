class_name MigrationVisual
extends Node3D

## A brief procession of deterministic resident silhouettes from Meadow to the
## Shore. It is a set piece, not a second workforce simulation.

const START := Vector3(3.0, 0.0, 2.5)
const SHORE := Vector3(25.0, 0.0, -1.8)

var _root := Node3D.new()
var _people: Array[Node3D] = []
var _species: Array[String] = []
var _elapsed := 0.0
var _running := false
var _finished := false

func _init(seeds: Array[Dictionary]) -> void:
	add_child(_root)
	_build_drowned_bell()
	for person in seeds:
		_species.append(String(person.get("species", FableState.HOBBIT)))
		_add_person(int(person.get("seed", 1)), _species.back())

func begin() -> void:
	_running = true
	_finished = false
	_elapsed = 0.0

func advance(delta: float) -> bool:
	if not _running:
		return _finished
	_elapsed += delta
	var t := clampf(_elapsed / 7.5, 0.0, 1.0)
	for i in _people.size():
		var lag := minf(float(i) * 0.06, 0.35)
		var local_t := clampf((t - lag) / (1.0 - lag), 0.0, 1.0)
		var at := START.lerp(SHORE, local_t)
		at.z += sin(local_t * PI) * (0.8 + i * 0.08)
		_people[i].position = at + Vector3(0, 0.06, 0)
		_people[i].rotation.y = lerpf(0.0, -0.12, local_t)
	if t >= 1.0:
		_running = false
		_finished = true
	return _finished

func running() -> bool:
	return _running

func _add_person(seed_value: int, species: String) -> void:
	var person := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var troll := species == FableState.TROLL
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.18 if troll else 0.12
	body_mesh.height = 0.72 if troll else 0.46
	body.mesh = body_mesh
	body.scale = Vector3(1.1 if troll else 0.9, 1.0, 1.0)
	body.position.y = 0.36 if troll else 0.23
	body.material_override = World.solid_material(Color("718469") if troll else Color("B26F4D"))
	person.add_child(body)
	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.06
	glow_mesh.height = 0.12
	glow.mesh = glow_mesh
	glow.position = Vector3(0, 0.46 if troll else 0.31, 0.18)
	glow.material_override = World.glow_material(Color(2.3, 1.0, 0.24), 0.9)
	person.add_child(glow)
	person.position = START
	_root.add_child(person)
	_people.append(person)

func _build_drowned_bell() -> void:
	var bell := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.22
	mesh.outer_radius = 0.34
	mesh.rings = 8
	mesh.ring_segments = 7
	bell.mesh = mesh
	bell.rotation_degrees.x = 90.0
	bell.position = SHORE + Vector3(1.2, 0.32, 0.4)
	bell.material_override = World.glow_material(Color(0.52, 0.72, 0.82), 0.72)
	_root.add_child(bell)
