class_name RiftLinkPanel
extends Control

signal host_requested
signal join_requested
signal cancel_requested
signal retry_requested

enum View { MENU, HOST, JOIN }

var _view: View = View.MENU
var _status := "CHOOSE A LINK"
var _has_discovered_session := false
var _press_feedback := ""
var _feedback_remaining := 0.0
var _squad_mode := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _process(delta: float) -> void:
	_feedback_remaining = maxf(0.0, _feedback_remaining - delta)
	if _feedback_remaining <= 0.0:
		_press_feedback = ""
	queue_redraw()

func open_menu() -> void:
	_view = View.MENU
	_status = "CHOOSE A LINK"
	_has_discovered_session = false
	visible = true
	queue_redraw()

func show_host() -> void:
	_view = View.HOST
	_has_discovered_session = false
	visible = true
	queue_redraw()

func show_join() -> void:
	_view = View.JOIN
	_has_discovered_session = false
	visible = true
	queue_redraw()

func hide_panel() -> void:
	visible = false

func set_status(status: String) -> void:
	_status = status
	queue_redraw()

func set_squad_mode(enabled: bool) -> void:
	_squad_mode = enabled
	queue_redraw()

func set_discovered_session(found: bool) -> void:
	_has_discovered_session = found
	if found:
		_status = "RIFT FOUND"
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tap(event.position)

func _handle_tap(point: Vector2) -> void:
	if _cancel_rect().grow(10.0).has_point(point):
		_press_feedback = "CANCEL"
		_feedback_remaining = 0.2
		cancel_requested.emit()
		return
	if _view == View.MENU:
		if _host_rect().has_point(point):
			_press_feedback = "OPEN"
			_feedback_remaining = 0.2
			_view = View.HOST
			host_requested.emit()
		elif _join_rect().has_point(point):
			_press_feedback = "SEEK"
			_feedback_remaining = 0.2
			_view = View.JOIN
			join_requested.emit()
	elif _view == View.HOST:
		if _host_rect().has_point(point):
			_press_feedback = "OPEN"
			_feedback_remaining = 0.2
			host_requested.emit()
	elif _view == View.JOIN:
		if _has_discovered_session and _join_rect().has_point(point):
			_press_feedback = "LINK"
			_feedback_remaining = 0.2
			join_requested.emit()
		elif not _has_discovered_session and _retry_rect().has_point(point):
			_press_feedback = "RETRY"
			_feedback_remaining = 0.2
			retry_requested.emit()
	queue_redraw()

func _draw() -> void:
	var safe := _safe_rect()
	var accent := Color("ffad5d")
	var cool := Color("71cfff")
	var panel := Rect2(safe.position + Vector2(48, 42), Vector2(safe.size.x - 96, safe.size.y - 84))
	draw_rect(Rect2(Vector2.ZERO, size), Color("020612", 0.88))
	draw_rect(panel, Color("09162d", 0.98))
	draw_line(panel.position, panel.position + Vector2(panel.size.x, 0), accent if _view != View.JOIN else cool, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, panel.position + Vector2(34, 42), "RIFT LINK", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("f1f6ff"))
	draw_string(font, panel.position + Vector2(36, 70), "SQUAD RIFT" if _squad_mode else "ONE RIFT. TWO DUELISTS. SAME AIR.", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("a9bfe2"))
	if _squad_mode:
		_draw_squad_slots(panel.position + Vector2(panel.size.x - 170, 62), accent if _view != View.JOIN else cool)
	_draw_status(panel, font, cool if _view == View.JOIN else accent)
	if _view == View.MENU:
		_draw_action(_host_rect(), "OPEN RIFT", accent, true)
		_draw_action(_join_rect(), "SEEK RIFT", cool, false)
	elif _view == View.HOST:
		_draw_icon(panel.position + Vector2(panel.size.x * 0.5, 185), accent, false)
		draw_string(font, panel.position + Vector2(0, 232), "THE RIFT IS OPEN", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 20, Color("f1f6ff"))
		draw_string(font, panel.position + Vector2(0, 258), "WAITING FOR THE SQUAD" if _squad_mode else "WAITING FOR ONE RIVAL", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color(accent, 0.9))
		_draw_action(_host_rect(), "OPEN RIFT", accent, true)
	elif _view == View.JOIN:
		_draw_icon(panel.position + Vector2(panel.size.x * 0.5, 185), cool, _has_discovered_session)
		if _has_discovered_session:
			draw_string(font, panel.position + Vector2(0, 232), "A RIFT IS NEAR", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 20, Color("f1f6ff"))
			draw_string(font, panel.position + Vector2(0, 258), "STEP INTO THE SQUAD RIFT" if _squad_mode else "STEP THROUGH TO DUEL", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color(cool, 0.9))
			_draw_action(_join_rect(), "ENTER RIFT", cool, true)
		else:
			draw_string(font, panel.position + Vector2(0, 232), "LISTENING FOR A RIFT", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 20, Color("f1f6ff"))
			draw_string(font, panel.position + Vector2(0, 258), "NO ADDRESS NEEDED", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 13, Color(cool, 0.9))
			_draw_action(_retry_rect(), "RETRY", cool, false)
	_draw_cancel(panel, font)

func _draw_status(panel: Rect2, font: Font, color: Color) -> void:
	draw_string(font, panel.position + Vector2(36, 108), _status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	draw_line(panel.position + Vector2(36, 120), panel.position + Vector2(panel.size.x - 36, 120), Color("20375d"), 1.0)

func _draw_action(rect: Rect2, label: String, color: Color, primary: bool) -> void:
	var expected_feedback := "OPEN" if label == "OPEN RIFT" else "SEEK" if label == "SEEK RIFT" else "RETRY" if label == "RETRY" else "LINK"
	var feedback := _press_feedback == expected_feedback and _feedback_remaining > 0.0
	draw_rect(rect, Color(color, 0.24 if primary else 0.1) if not feedback else Color(color, 0.4), true)
	draw_rect(rect, Color(color, 0.96), false, 2.0)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, rect.get_center() + Vector2(-width * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)

func _draw_cancel(panel: Rect2, font: Font) -> void:
	draw_rect(_cancel_rect(), Color("101f3a", 0.7), true)
	draw_rect(_cancel_rect(), Color("7890b2", 0.8), false, 1.2)
	draw_string(font, _cancel_rect().get_center() + Vector2(-32, 5), "CANCEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b6c9e8"))

func _draw_icon(center: Vector2, color: Color, active: bool) -> void:
	draw_circle(center, 42.0, Color(color, 0.12 if not active else 0.22))
	draw_arc(center, 42.0, 0.0, TAU, 32, Color(color, 0.46 if not active else 0.94), 2.0)
	draw_arc(center, 26.0, -1.1, 1.2, 16, color, 3.0)
	draw_arc(center, 26.0, 2.0, 4.3, 16, color, 3.0)
	draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), color, 2.0)

func _draw_squad_slots(origin: Vector2, color: Color) -> void:
	for index in 5:
		var center := origin + Vector2(index * 18.0, 0.0)
		draw_arc(center, 5.0, 0.0, TAU, 12, Color(color, 0.72), 1.3)

func _host_rect() -> Rect2:
	var panel := _panel_rect()
	return Rect2(panel.position + Vector2(82, _action_stack_top()), Vector2(panel.size.x - 164, 56))

func _join_rect() -> Rect2:
	var panel := _panel_rect()
	return Rect2(panel.position + Vector2(82, _action_stack_top() + 64), Vector2(panel.size.x - 164, 56))

func _retry_rect() -> Rect2:
	var panel := _panel_rect()
	return Rect2(panel.position + Vector2(82, _action_stack_top()), Vector2(panel.size.x - 164, 56))

func _cancel_rect() -> Rect2:
	var panel := _panel_rect()
	return Rect2(panel.position + Vector2(82, _action_stack_top() + 128), Vector2(panel.size.x - 164, 44))

func _action_stack_top() -> float:
	# Keep the three 44-point-class targets in one stack even on short landscape windows.
	return maxf(0.0, _panel_rect().size.y - 172.0)

func _panel_rect() -> Rect2:
	var safe := _safe_rect()
	return Rect2(safe.position + Vector2(48, 42), Vector2(safe.size.x - 96, safe.size.y - 84))

func _safe_rect() -> Rect2:
	var fallback := Rect2(24.0, 24.0, maxf(1.0, size.x - 48.0), maxf(1.0, size.y - 48.0))
	var display_safe := DisplayServer.get_display_safe_area()
	if display_safe.size.x <= 0 or display_safe.size.y <= 0:
		return fallback
	var candidate := Rect2(Vector2(display_safe.position), Vector2(display_safe.size))
	if candidate.position.x >= -1.0 and candidate.position.y >= -1.0 and candidate.end.x <= size.x + 1.0 and candidate.end.y <= size.y + 1.0:
		return candidate
	return fallback
