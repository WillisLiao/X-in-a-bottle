class_name LostLightsVisual
extends Node3D

## A small flock whose motion is visible but never demands precision.

const GATE_AT := Vector3(7.0, 0.0, 2.8)
const HOME_AT := Vector3(3.0, 0.0, 2.5)
const OUTWARD_AT := Vector3(19.0, 0.0, 0.4)

var _state: FableState
var _root := Node3D.new()
var _lights: Array[MeshInstance3D] = []
var _elapsed := 0.0

func _init(state: FableState) -> void:
	_state = state
	add_child(_root)

func set_state(state: FableState) -> void:
	_state = state

func gate_position() -> Vector3:
	return GATE_AT

func home_position() -> Vector3:
	return HOME_AT

func outward_position() -> Vector3:
	return OUTWARD_AT

func rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	_lights.clear()
	for i in 7:
		var light := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.09
		mesh.height = 0.18
		mesh.radial_segments = 6
		mesh.rings = 3
		light.mesh = mesh
		light.material_override = World.glow_material(Color(2.5, 1.15, 0.30), 0.96)
		_root.add_child(light)
		_lights.append(light)
	_build_permanent()

func animate_flock(delta: float, destination: String) -> void:
	_elapsed += delta
	var target := home_position() if destination == FableState.HOME else outward_position()
	for i in _lights.size():
		var start := gate_position() + Vector3((i - 3) * 0.32, 0.7 + fposmod(i * 0.31, 0.45), 0)
		var t := clampf(_elapsed / 3.2, 0.0, 1.0)
		var arc := sin(t * PI) * (0.65 + i * 0.03)
		_lights[i].position = start.lerp(target, t) + Vector3(0, arc, sin(_elapsed * 1.7 + i) * 0.12)

func finish(destination: String) -> void:
	for light in _lights:
		light.visible = false
	_build_permanent()

func _build_permanent() -> void:
	var resolution := _state.resolution("lost_lights")
	if resolution == FableState.HOME:
		for at in [HOME_AT + Vector3(-0.8, 0.8, 0), HOME_AT + Vector3(0.4, 1.0, 0.1), HOME_AT + Vector3(1.0, 0.6, 0)]:
			_add_window(at)
	elif resolution == FableState.OUTWARD:
		var road := MeshInstance3D.new()
		road.mesh = Geometry.tube(PackedVector3Array([GATE_AT, OUTWARD_AT]), 0.10, 0.14, 6, false)
		road.material_override = World.glow_material(Color(1.3, 0.58, 0.18), 0.55)
		_root.add_child(road)
		for i in 4:
			_add_window(GATE_AT.lerp(OUTWARD_AT, 0.22 + i * 0.20) + Vector3(0, 0.5 + fposmod(i * 0.2, 0.3), 0))

func _add_window(at: Vector3) -> void:
	var light := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	mesh.radial_segments = 6
	mesh.rings = 3
	light.mesh = mesh
	light.position = at
	light.material_override = World.glow_material(Color(2.4, 1.05, 0.28), 0.95)
	_root.add_child(light)
