class_name ActMarks
extends Control

## Projected touch layer for Rooted Gate, Lost Lights, and migration.
## It keeps the critical alternatives broad and visible without labels.

signal rooted_species_chosen(species: String)
signal lost_destination_chosen(destination: String)
signal migration_tapped

var stage := ""
var _camera: Camera3D
var _gate: RootedGateVisual
var _lights: LostLightsVisual
var _dragging := false
var _drag_species := ""
var _pulse := 0.0
var _lantern_at := Vector2.ZERO
var _hobbit_at := Vector2.ZERO
var _troll_at := Vector2.ZERO
var _home_at := Vector2.ZERO
var _outward_at := Vector2.ZERO
var _gate_at := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_context(camera: Camera3D, gate: RootedGateVisual, lights: LostLightsVisual) -> void:
	_camera = camera
	_gate = gate
	_lights = lights

func set_stage(value: String) -> void:
	stage = value
	queue_redraw()

func begin_drag(at: Vector2) -> bool:
	_update_positions()
	if stage == "rooted_choosing":
		if at.distance_to(_troll_at) < 90.0:
			_drag_species = FableState.TROLL
		elif at.distance_to(_hobbit_at) < 90.0:
			_drag_species = FableState.HOBBIT
		else:
			return false
		_dragging = true
		return true
	if stage == "lost_choosing" and at.distance_to(_gate_at) < 100.0:
		_dragging = true
		return true
	return false

func drag_to(at: Vector2) -> bool:
	if not _dragging:
		return false
	_update_positions()
	if stage == "rooted_choosing" and at.distance_to(_lantern_at) < 105.0:
		rooted_species_chosen.emit(_drag_species)
		_dragging = false
		return true
	if stage == "lost_choosing":
		if at.distance_to(_home_at) < 130.0:
			lost_destination_chosen.emit(FableState.HOME)
			_dragging = false
			return true
		if at.distance_to(_outward_at) < 130.0:
			lost_destination_chosen.emit(FableState.OUTWARD)
			_dragging = false
			return true
	return false

func end_drag() -> void:
	_dragging = false
	_drag_species = ""

func tap(at: Vector2) -> bool:
	_update_positions()
	if stage == "rooted_dormant" and at.distance_to(_gate_at) < 150.0:
		stage = "rooted_choosing"
		queue_redraw()
		return true
	if stage == "rooted_choosing":
		if at.distance_to(_troll_at) < 100.0:
			rooted_species_chosen.emit(FableState.TROLL)
			return true
		if at.distance_to(_hobbit_at) < 100.0:
			rooted_species_chosen.emit(FableState.HOBBIT)
			return true
	if stage == "lost_dormant" and at.distance_to(_gate_at) < 150.0:
		stage = "lost_choosing"
		queue_redraw()
		return true
	if stage == "lost_choosing":
		if at.distance_to(_home_at) < 140.0:
			lost_destination_chosen.emit(FableState.HOME)
			return true
		if at.distance_to(_outward_at) < 140.0:
			lost_destination_chosen.emit(FableState.OUTWARD)
			return true
	if stage == "migration_ready" and at.distance_to(_outward_at) < 170.0:
		migration_tapped.emit()
		return true
	return false

func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	if _camera == null or stage == "":
		return
	_update_positions()
	if stage == "rooted_dormant":
		_draw_gate(_gate_at, false)
	elif stage == "rooted_choosing":
		_draw_gate(_gate_at, true)
		_draw_lantern(_lantern_at)
		_draw_person(_hobbit_at, false)
		_draw_person(_troll_at, true)
	elif stage == "lost_dormant":
		_draw_gate(_gate_at, false)
		_draw_flock(_gate_at)
	elif stage == "lost_choosing":
		draw_line(_gate_at, _home_at, Color(1.0, 0.64, 0.20, 0.24), 5.0, true)
		draw_line(_gate_at, _outward_at, Color(1.0, 0.64, 0.20, 0.24), 5.0, true)
		_draw_flock(_gate_at)
		_draw_destination(_home_at, true)
		_draw_destination(_outward_at, false)
	elif stage == "migration_ready":
		draw_line(_gate_at, _outward_at, Color(1.0, 0.64, 0.20, 0.34), 8.0, true)
		_draw_lantern(_outward_at)

func _update_positions() -> void:
	if _gate == null:
		return
	_lantern_at = _camera.unproject_position(_gate.lantern_position())
	_hobbit_at = _camera.unproject_position(_gate.gate_position() + Vector3(-1.45, 0.55, 0.7))
	_troll_at = _camera.unproject_position(_gate.gate_position() + Vector3(1.45, 0.85, 0.7))
	_gate_at = _camera.unproject_position(_gate.gate_position() + Vector3(0, 0.7, 0))
	_home_at = _camera.unproject_position(_lights.home_position() + Vector3(0, 0.5, 0)) if _lights else _lantern_at
	_outward_at = _camera.unproject_position(_lights.outward_position() + Vector3(0, 0.5, 0)) if _lights else _gate_at

func _draw_gate(at: Vector2, bright: bool) -> void:
	var color := Color(0.24, 0.50, 0.30, 0.82 if bright else 0.48)
	draw_circle(at, 82.0, Color(color, 0.11))
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-62, 30), at + Vector2(-47, -20), at + Vector2(0, -58),
		at + Vector2(47, -20), at + Vector2(62, 30),
	]), color)
	draw_line(at + Vector2(0, 18), at + Vector2(0, -34), Color(1.0, 0.66, 0.24, 0.86), 5.0, true)

func _draw_lantern(at: Vector2) -> void:
	draw_circle(at, 54.0, Color(1.0, 0.54, 0.15, 0.16))
	draw_circle(at, 20.0, Color(1.0, 0.70, 0.28, 0.96))
	draw_circle(at + Vector2(0, -8), 7.0, Color(1.0, 0.95, 0.70, 1.0))

func _draw_person(at: Vector2, troll: bool) -> void:
	var color := Color(0.42, 0.52, 0.42, 0.92) if troll else Color(0.70, 0.42, 0.30, 0.92)
	draw_circle(at, 58.0, Color(color, 0.12))
	draw_circle(at + Vector2(0, -26 if troll else -19), 24.0 if troll else 17.0, color)
	draw_rect(Rect2(at + Vector2(-28 if troll else -20, -5), Vector2(56 if troll else 40, 47 if troll else 34)), color)

func _draw_flock(at: Vector2) -> void:
	for i in 7:
		var p: Vector2 = at + Vector2((i - 3) * 18.0, sin(_pulse * 2.0 + i) * 13.0 - 20.0)
		draw_circle(p, 9.0, Color(1.0, 0.72, 0.25, 0.90))

func _draw_destination(at: Vector2, home: bool) -> void:
	var color := Color(1.0, 0.68, 0.26, 0.86) if home else Color(0.74, 0.70, 0.46, 0.86)
	draw_circle(at, 72.0, Color(color, 0.10))
	if home:
		draw_circle(at, 24.0, color)
		draw_line(at + Vector2(-19, 19), at + Vector2(19, 19), Color(0.30, 0.16, 0.10, 0.9), 5.0, true)
	else:
		draw_line(at + Vector2(0, 25), at + Vector2(0, -26), color, 8.0, true)
		draw_circle(at + Vector2(0, -35), 23.0, Color(color, 0.72))
