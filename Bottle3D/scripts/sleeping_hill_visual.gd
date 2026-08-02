class_name SleepingHillVisual
extends Node3D

## Meadow geometry for the first fable. All positions are world-relative, so the
## custom overlay can project the same objects the camera is showing.

const HEARTH_AT := Vector3(3.0, 0.0, 2.5)
const HILL_AT := Vector3(-2.35, 0.0, -2.55)
const CAIRNS := [Vector3(-0.55, 0.0, 0.80), Vector3(-1.05, 0.0, -0.25), Vector3(-1.70, 0.0, -1.35)]

var _state: FableState
var _root := Node3D.new()
var _route_root := Node3D.new()
var _seed: MeshInstance3D
var _bloom := 0.0

func _init(state: FableState) -> void:
	_state = state
	add_child(_root)
	_root.add_child(_route_root)

func set_state(state: FableState) -> void:
	_state = state

func hill_position() -> Vector3:
	return HILL_AT

func hearth_position() -> Vector3:
	return HEARTH_AT

func cairn_positions() -> Array[Vector3]:
	return CAIRNS.duplicate()

func seed_position() -> Vector3:
	return HILL_AT + Vector3(0.0, 0.90, 0.0)

func road_beyond_position() -> Vector3:
	return HILL_AT + Vector3(-2.0, 0.18, -1.05)

func rebuild() -> void:
	for child in _root.get_children():
		if child != _route_root:
			child.queue_free()
	for child in _route_root.get_children():
		child.queue_free()
	_seed = null
	_build_hill()
	_build_hearth()
	_build_route(_state.resolution("sleeping_hill") != FableState.UNRESOLVED)
	if _state.resolution("sleeping_hill") == FableState.HOLLOW:
		_build_hollow_door()
	elif _state.resolution("sleeping_hill") == FableState.GROVE:
		_build_grove()

func set_route_step(step: int) -> void:
	_build_route(step >= 0)
	for i in mini(step + 1, CAIRNS.size()):
		_build_ember(CAIRNS[i] + Vector3(0.0, 0.12, 0.0))

func raise_seed() -> void:
	if _seed:
		_seed.visible = true

func resolve(outcome: String) -> void:
	_state.resolve("sleeping_hill", outcome)
	rebuild()

func _build_hill() -> void:
	var body := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.55
	mesh.height = 1.45
	mesh.radial_segments = 12
	mesh.rings = 5
	body.mesh = mesh
	body.scale = Vector3(1.35, 0.72, 0.92)
	body.position = HILL_AT + Vector3(0, 0.48, 0)
	body.material_override = World.solid_material(Color("4B4838"))
	_root.add_child(body)

	var cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 1.15
	cap_mesh.height = 0.62
	cap_mesh.radial_segments = 10
	cap_mesh.rings = 4
	cap.mesh = cap_mesh
	cap.scale = Vector3(1.38, 0.52, 0.94)
	cap.position = HILL_AT + Vector3(-0.08, 1.06, 0.02)
	cap.material_override = World.solid_material(Color("5E7148"))
	_root.add_child(cap)

	var seam := MeshInstance3D.new()
	var seam_mesh := TorusMesh.new()
	seam_mesh.inner_radius = 0.36
	seam_mesh.outer_radius = 0.48
	seam_mesh.rings = 10
	seam_mesh.ring_segments = 8
	seam.mesh = seam_mesh
	seam.rotation_degrees.x = 90.0
	seam.position = HILL_AT + Vector3(0, 0.52, 0.96)
	seam.material_override = World.glow_material(Color(1.9, 0.70, 0.20), 0.72)
	_root.add_child(seam)

	_seed = MeshInstance3D.new()
	var seed_mesh := SphereMesh.new()
	seed_mesh.radius = 0.18
	seed_mesh.height = 0.36
	seed_mesh.radial_segments = 8
	seed_mesh.rings = 4
	_seed.mesh = seed_mesh
	_seed.position = seed_position()
	_seed.material_override = World.glow_material(Color(2.7, 1.15, 0.25), 1.0)
	_seed.visible = false
	_root.add_child(_seed)

func _build_hearth() -> void:
	var fire := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.radial_segments = 7
	mesh.rings = 4
	fire.mesh = mesh
	fire.position = HEARTH_AT + Vector3(0, 0.20, 0)
	fire.material_override = World.glow_material(Color(2.8, 1.35, 0.42), 0.95)
	_root.add_child(fire)

func _build_route(on: bool) -> void:
	if not on:
		return
	var points := PackedVector3Array([HEARTH_AT + Vector3(0, 0.04, 0), CAIRNS[0] + Vector3(0, 0.04, 0), CAIRNS[1] + Vector3(0, 0.04, 0), CAIRNS[2] + Vector3(0, 0.04, 0), HILL_AT + Vector3(0, 0.04, 0)])
	var road := MeshInstance3D.new()
	road.mesh = Geometry.tube(points, 0.11, 0.14, 6, false)
	road.material_override = World.glow_material(Color(1.15, 0.48, 0.12), 0.42)
	_route_root.add_child(road)

func _build_ember(at: Vector3) -> void:
	var ember := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 6
	mesh.rings = 3
	ember.mesh = mesh
	ember.position = at
	ember.material_override = World.glow_material(Color(2.6, 1.0, 0.22), 0.92)
	_route_root.add_child(ember)

func _build_hollow_door() -> void:
	var door := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.42
	mesh.outer_radius = 0.62
	mesh.rings = 12
	mesh.ring_segments = 10
	door.mesh = mesh
	door.rotation_degrees.x = 90.0
	door.position = HEARTH_AT + Vector3(-0.65, 0.65, -0.05)
	door.material_override = World.glow_material(Color(2.5, 1.0, 0.25), 0.88)
	_root.add_child(door)

func _build_grove() -> void:
	for at in [Vector3(-2.25, 0, -2.0), Vector3(-3.05, 0, -2.8)]:
		var trunk := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 1.25, 0.16)
		trunk.mesh = box
		trunk.position = at + Vector3(0, 0.62, 0)
		trunk.material_override = World.solid_material(Color("624735"))
		_root.add_child(trunk)
		var crown := MeshInstance3D.new()
		crown.mesh = Geometry.crystal(0.55, 0.20)
		crown.position = at + Vector3(0, 1.35, 0)
		crown.scale = Vector3(0.8, 1.15, 0.8)
		crown.material_override = World.glow_material(Color(1.35, 0.72, 0.20), 0.76)
		_root.add_child(crown)
