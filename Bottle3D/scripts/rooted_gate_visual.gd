class_name RootedGateVisual
extends Node3D

## The impossible Meadow exit. The arch is deliberately low and wide so its
## silhouette reads as a sealed door at map distance, not as a tree.

const GATE_AT := Vector3(7.0, 0.0, 2.8)
const LANTERN_AT := Vector3(3.0, 0.0, 2.5)
const SHORE_EXIT := Vector3(25.0, 0.0, -1.8)

var _state: FableState
var _root := Node3D.new()

func _init(state: FableState) -> void:
	_state = state
	add_child(_root)

func set_state(state: FableState) -> void:
	_state = state

func gate_position() -> Vector3:
	return GATE_AT

func lantern_position() -> Vector3:
	return LANTERN_AT

func exit_position() -> Vector3:
	return SHORE_EXIT

func rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	_build_gate()
	if _state.resolution("rooted_gate") == FableState.TROLL:
		_build_steps()
	elif _state.resolution("rooted_gate") == FableState.HOBBIT:
		_build_flowering_arch()

func _build_gate() -> void:
	var left := MeshInstance3D.new()
	left.mesh = Geometry.crystal(0.72, 0.24)
	left.scale = Vector3(0.72, 2.3, 0.82)
	left.position = GATE_AT + Vector3(-0.95, 1.1, 0)
	left.material_override = World.solid_material(Color("294936"))
	_root.add_child(left)
	var right := MeshInstance3D.new()
	right.mesh = Geometry.crystal(0.72, 0.24)
	right.scale = Vector3(0.72, 2.3, 0.82)
	right.position = GATE_AT + Vector3(0.95, 1.1, 0)
	right.material_override = World.solid_material(Color("294936"))
	_root.add_child(right)
	var crown := MeshInstance3D.new()
	crown.mesh = Geometry.tube(PackedVector3Array([
		GATE_AT + Vector3(-1.0, 2.0, 0), GATE_AT + Vector3(-0.4, 2.45, 0),
		GATE_AT + Vector3(0.4, 2.45, 0), GATE_AT + Vector3(1.0, 2.0, 0),
	]), 0.38, 0.48, 7, false)
	crown.material_override = World.solid_material(Color("355B3D"))
	_root.add_child(crown)
	var seam := MeshInstance3D.new()
	var seam_mesh := BoxMesh.new()
	seam_mesh.size = Vector3(0.16, 1.5, 0.08)
	seam.mesh = seam_mesh
	seam.position = GATE_AT + Vector3(0, 0.78, 0.32)
	seam.material_override = World.glow_material(Color(1.4, 0.62, 0.20), 0.82)
	_root.add_child(seam)

func _build_steps() -> void:
	for i in 3:
		var step := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.45 - i * 0.16, 0.18, 0.48)
		step.mesh = box
		step.position = GATE_AT + Vector3(0, 0.09 + i * 0.18, 0.45 + i * 0.35)
		step.material_override = World.solid_material(Color("81745E"))
		_root.add_child(step)

func _build_flowering_arch() -> void:
	var arch := MeshInstance3D.new()
	arch.mesh = Geometry.tube(PackedVector3Array([
		GATE_AT + Vector3(-1.0, 0.0, 0), GATE_AT + Vector3(-0.8, 1.0, 0),
		GATE_AT + Vector3(0, 1.9, 0), GATE_AT + Vector3(0.8, 1.0, 0),
		GATE_AT + Vector3(1.0, 0.0, 0),
	]), 0.20, 0.28, 6, false)
	arch.material_override = World.solid_material(Color("4E7549"))
	_root.add_child(arch)
	for at in [GATE_AT + Vector3(-0.75, 0.6, 0.28), GATE_AT + Vector3(0.65, 1.2, 0.28), GATE_AT + Vector3(0.0, 1.85, 0.28)]:
		var flower := MeshInstance3D.new()
		flower.mesh = Geometry.crystal(0.24, 0.18)
		flower.position = at
		flower.material_override = World.glow_material(Color(1.2, 0.50, 0.34), 0.84)
		_root.add_child(flower)
