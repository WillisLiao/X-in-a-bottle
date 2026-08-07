class_name FocusHud
extends CanvasLayer

signal food_requested
signal rally_requested

## The entire focus interface.
##
## It is intentionally quiet: one name, one honest elapsed time, and one
## status for the people in the scene. There is no score, session picker, or
## progress bar to manage. The work is leaving the app here.

const INK := Color("F3E7D0")
const MUTED := Color(0.95, 0.90, 0.80, 0.48)
const QUIET := Color(0.95, 0.90, 0.80, 0.30)

var _brand: Label
var _clock: Label
var _status: Label
var _note: Label
var _actions: FocusActions
var _feedback := ""
var _feedback_left := 0.0


func _init() -> void:
	layer = 120


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_brand = _label("HOBBITLE", 30, MUTED)
	_brand.position = Vector2(84.0, 56.0)
	root.add_child(_brand)

	_clock = _label("FOCUS 00:00:00", 34, INK)
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.offset_left = -470.0
	_clock.offset_right = -84.0
	_clock.offset_top = 52.0
	_clock.offset_bottom = 100.0
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_clock)

	_status = _label("BUILDING", 30, INK)
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 84.0
	_status.offset_right = 500.0
	_status.offset_top = -142.0
	_status.offset_bottom = -102.0
	root.add_child(_status)

	_note = _label("Leave them to it.", 24, QUIET)
	_note.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_note.offset_left = 84.0
	_note.offset_right = 600.0
	_note.offset_top = -94.0
	_note.offset_bottom = -58.0
	root.add_child(_note)

	_actions = FocusActions.new()
	_actions.food_tapped.connect(func(): food_requested.emit())
	_actions.rally_tapped.connect(func(): rally_requested.emit())
	add_child(_actions)


func _process(delta: float) -> void:
	if _feedback_left > 0.0:
		_feedback_left = maxf(0.0, _feedback_left - delta)


func tap(at: Vector2) -> bool:
	return _actions != null and _actions.tap(at)


func show_feedback(title: String) -> void:
	_feedback = title
	_feedback_left = 3.5


func update_state(focus_seconds: float, resting: bool,
		rest_seconds: float, food_ready: bool, rally_ready: bool) -> void:
	if not is_inside_tree() or _clock == null:
		return

	_clock.text = "FOCUS %s" % _format_time(focus_seconds)
	_actions.set_state(food_ready, rally_ready)
	if _feedback_left > 0.0:
		_status.text = _feedback
		_note.text = "The work carries on."
	elif resting:
		_status.text = "RESTING"
		_note.text = "Back to building in %s" % _format_time(rest_seconds)
	else:
		_status.text = "BUILDING"
		_note.text = "Leave them to it."


func _label(text: String, size_px: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
