class_name ExpeditionMarks
extends Control

## Projected, wordless interaction for the Sleeping Hill.
## Every target is at least 44 points wide and follows the camera.

signal lantern_tapped
signal cairn_tapped(step: int)
signal choice_tapped(outcome: String)

var stage := "dormant"
var _camera: Camera3D
var _visual: SleepingHillVisual
var _pulse := 0.0
var _dragging := false
var _resolution_bloom := 0.0
var _seed_at := Vector2.ZERO
var _hearth_at := Vector2.ZERO
var _hill_at := Vector2.ZERO
var _beyond_at := Vector2.ZERO
var _cairns: Array[Vector2] = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_context(camera: Camera3D, visual: SleepingHillVisual) -> void:
	_camera = camera
	_visual = visual

func set_stage(next: String) -> void:
	stage = next
	queue_redraw()

func play_resolution_bloom() -> void:
	_resolution_bloom = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	_pulse += delta
	_resolution_bloom = maxf(0.0, _resolution_bloom - delta * 2.4)
	queue_redraw()

func begin_drag(at: Vector2) -> bool:
	if stage == "choosing" and at.distance_to(_seed_at) < 70.0:
		_dragging = true
		return true
	if stage == "carrying":
		_dragging = true
		return drag_to(at)
	return false

func drag_to(at: Vector2) -> bool:
	if not _dragging:
		return false
	if stage == "carrying":
		for i in _cairns.size():
			if at.distance_to(_cairns[i]) < 76.0:
				cairn_tapped.emit(i)
				return true
	if stage == "choosing":
		if at.distance_to(_hearth_at) < 120.0:
			choice_tapped.emit("hollow")
			_dragging = false
			return true
		if at.distance_to(_beyond_at) < 120.0:
			choice_tapped.emit("grove")
			_dragging = false
			return true
	return false

func end_drag() -> void:
	_dragging = false

func tap(at: Vector2) -> bool:
	if stage == "dormant" and at.distance_to(_hearth_at) < 105.0:
		lantern_tapped.emit()
		return true
	if stage == "carrying":
		for i in _cairns.size():
			if at.distance_to(_cairns[i]) < 76.0:
				cairn_tapped.emit(i)
				return true
	if stage == "choosing":
		if at.distance_to(_hearth_at) < 120.0:
			choice_tapped.emit("hollow")
			return true
		if at.distance_to(_beyond_at) < 120.0:
			choice_tapped.emit("grove")
			return true
	return false

func _draw() -> void:
	if _camera == null or _visual == null:
		return
	_hearth_at = _project(_visual.hearth_position())
	_hill_at = _project(_visual.hill_position() + Vector3(0, 0.8, 0))
	_seed_at = _project(_visual.seed_position())
	_beyond_at = _project(_visual.road_beyond_position())
	_cairns.clear()
	for at in _visual.cairn_positions():
		_cairns.append(_project(at + Vector3(0, 0.3, 0)))

	var breath := 0.86 + sin(_pulse * 2.0) * 0.14
	if stage == "dormant":
		draw_line(_hearth_at, _hill_at, Color(1.0, 0.58, 0.18, 0.24), 4.0, true)
		_draw_lantern(_hearth_at, breath)
		_draw_hill_invitation(_hill_at, breath)
	elif stage == "carrying":
		_draw_lantern(_cairns[maxi(0, _cairns.size() - 1)], breath)
		for i in _cairns.size():
			_draw_cairn(_cairns[i], i == _visual_cairn_step(), i < _visual_cairn_step())
	elif stage == "choosing":
		draw_line(_seed_at, _hearth_at, Color(1.0, 0.58, 0.18, 0.32), 5.0, true)
		draw_line(_seed_at, _beyond_at, Color(1.0, 0.72, 0.28, 0.32), 5.0, true)
		_draw_seed(_seed_at, breath)
		_draw_destination(_hearth_at, Color(1.0, 0.67, 0.25, 0.88), true)
		_draw_destination(_beyond_at, Color(0.80, 0.72, 0.45, 0.88), false)
	elif stage == "resolved" and _visual._state.sleeping_hill == FableState.GROVE:
		draw_line(_hill_at, _beyond_at, Color(1.0, 0.64, 0.22, 0.55), 8.0, true)
		_draw_grove(_beyond_at)
	if _resolution_bloom > 0.0:
		var bloom_at := _hearth_at if _visual._state.sleeping_hill == FableState.HOLLOW else _beyond_at
		draw_circle(bloom_at, lerpf(22.0, 180.0, 1.0 - _resolution_bloom),
			Color(1.0, 0.70, 0.26, _resolution_bloom * 0.24), false, 9.0, true)

func _project(at: Vector3) -> Vector2:
	return _camera.unproject_position(at)

func _visual_cairn_step() -> int:
	return _metadata_step

func set_cairn_step(step: int) -> void:
	_metadata_step = step
	queue_redraw()

var _metadata_step := 0

func _draw_lantern(at: Vector2, breath: float) -> void:
	draw_circle(at, 52.0 * breath, Color(1.0, 0.55, 0.16, 0.16))
	draw_circle(at, 22.0, Color(1.0, 0.70, 0.28, 0.92))
	draw_circle(at + Vector2(0, -8), 8.0, Color(1.0, 0.95, 0.70, 1.0))
	draw_line(at + Vector2(-17, 14), at + Vector2(17, 14), Color(0.30, 0.16, 0.10, 0.95), 5.0, true)

func _draw_hill_invitation(at: Vector2, breath: float) -> void:
	draw_circle(at, 84.0 * breath, Color(1.0, 0.62, 0.22, 0.10))
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-70, 22), at + Vector2(-42, -18), at + Vector2(0, -46),
		at + Vector2(42, -18), at + Vector2(70, 22),
	]), Color(0.34, 0.48, 0.28, 0.52))
	draw_arc(at + Vector2(0, 12), 25.0, PI, TAU, 20, Color(1.0, 0.67, 0.24, 0.86), 5.0, true)

func _draw_cairn(at: Vector2, active: bool, reached: bool) -> void:
	var color := Color(1.0, 0.67, 0.22, 0.95) if active else Color(0.72, 0.52, 0.28, 0.60)
	draw_circle(at, 31.0 if active else 24.0, Color(color, 0.14))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-14, 10), at + Vector2(0, -15), at + Vector2(14, 10)]), color)
	if reached:
		draw_circle(at, 7.0, Color(1.0, 0.88, 0.42, 0.95))

func _draw_seed(at: Vector2, breath: float) -> void:
	draw_circle(at, 38.0 * breath, Color(1.0, 0.55, 0.14, 0.18))
	draw_circle(at, 13.0, Color(1.0, 0.70, 0.24, 0.96))
	draw_circle(at, 5.0, Color(1.0, 0.96, 0.72, 1.0))

func _draw_destination(at: Vector2, color: Color, hearth: bool) -> void:
	draw_circle(at, 60.0, Color(color, 0.10))
	if hearth:
		draw_circle(at, 31.0, Color(color, 0.34))
		draw_circle(at, 20.0, color)
		draw_line(at + Vector2(-16, 17), at + Vector2(16, 17), Color(0.35, 0.18, 0.10, 0.9), 5.0, true)
	else:
		draw_line(at + Vector2(0, 22), at + Vector2(0, -27), color, 7.0, true)
		draw_circle(at + Vector2(0, -35), 24.0, Color(color, 0.72))

func _draw_grove(at: Vector2) -> void:
	for offset in [Vector2(-38, 0), Vector2(38, 0)]:
		var tree: Vector2 = at + offset
		draw_line(tree + Vector2(0, 27), tree + Vector2(0, -26), Color(0.38, 0.25, 0.16, 0.95), 9.0, true)
		draw_circle(tree + Vector2(0, -45), 35.0, Color(1.0, 0.66, 0.22, 0.72))
