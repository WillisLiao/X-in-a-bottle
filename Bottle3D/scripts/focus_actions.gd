class_name FocusActions
extends Control

## Two occasional reasons to look at the screen.
##
## These are not a task list. They appear only when the living world has earned
## them, then disappear after one tap. The controls are large, labelled, and
## drawn in the same quiet language as the focus HUD.

signal food_tapped
signal rally_tapped

const INK := Color("F3E7D0")
const EMBER := Color("FF9A4A")
const PANEL := Color(0.07, 0.055, 0.045, 0.82)

var _food_ready := false
var _rally_ready := false
var _food_rect := Rect2()
var _rally_rect := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_state(food_ready: bool, rally_ready: bool) -> void:
	_food_ready = food_ready
	_rally_ready = rally_ready
	queue_redraw()


func tap(at: Vector2) -> bool:
	if _food_ready and _food_rect.has_point(at):
		food_tapped.emit()
		return true
	if _rally_ready and _rally_rect.has_point(at):
		rally_tapped.emit()
		return true
	return false


func _draw() -> void:
	var size := get_viewport_rect().size
	var button_size := Vector2(360.0, 132.0)
	var right := 84.0
	var bottom := 72.0
	var gap := 18.0
	var next_y := size.y - bottom - button_size.y

	_food_rect = Rect2(Vector2(size.x - right - button_size.x, next_y), button_size)
	if _food_ready:
		_draw_food(_food_rect)
		next_y -= button_size.y + gap

	_rally_rect = Rect2(Vector2(size.x - right - button_size.x, next_y), button_size)
	if _rally_ready:
		_draw_rally(_rally_rect)


func _draw_food(rect: Rect2) -> void:
	_draw_panel(rect, EMBER)
	var icon := rect.position + Vector2(42.0, rect.size.y * 0.5)
	draw_circle(icon + Vector2(-13.0, 7.0), 8.0, Color(0.78, 0.37, 0.22, 0.95))
	draw_circle(icon + Vector2(2.0, -7.0), 8.0, Color(0.80, 0.61, 0.24, 0.95))
	draw_circle(icon + Vector2(16.0, 8.0), 8.0, Color(0.44, 0.61, 0.67, 0.95))
	_draw_text(rect, "FOOD RAIN", "Let them eat", EMBER)


func _draw_rally(rect: Rect2) -> void:
	_draw_panel(rect, Color("D6B26A"))
	var icon := rect.position + Vector2(42.0, rect.size.y * 0.5)
	draw_arc(icon + Vector2(0.0, 4.0), 17.0, PI + 0.35, TAU - 0.35,
		18, Color("D6B26A"), 4.0, true)
	draw_line(icon + Vector2(-17.0, 4.0), icon + Vector2(-7.0, -12.0),
		Color("D6B26A"), 4.0, true)
	draw_line(icon + Vector2(17.0, 4.0), icon + Vector2(7.0, -12.0),
		Color("D6B26A"), 4.0, true)
	draw_circle(icon + Vector2(0.0, 4.0), 6.0, Color("D6B26A"))
	_draw_text(rect, "RALLY THEM", "Ring the bell", Color("D6B26A"))


func _draw_panel(rect: Rect2, accent: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL
	box.border_color = Color(accent, 0.76)
	box.set_border_width_all(2)
	box.set_corner_radius_all(18)
	draw_style_box(box, rect)


func _draw_text(rect: Rect2, title: String, subtitle: String,
		accent: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, rect.position + Vector2(82.0, 55.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 27, INK)
	draw_string(font, rect.position + Vector2(82.0, 91.0), subtitle,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color(accent, 0.72))
