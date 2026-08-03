class_name RiftlinePracticePanel
extends Control

signal drill_requested(drill: String)
signal local_rift_requested

const INK := Color("071126")
const PANEL := Color("0e1d38")
const PAPER := Color("f1f6ff")
const MUTED := Color("9bb2d1")
const SUN := Color("ffb15c")
const VOID := Color("75dbff")
const CREW_IDENTITY := preload("res://scripts/riftline_crew_identity.gd")
const CREW_PROFILE := preload("res://scripts/riftline_crew_profile.gd")
const RESPONSIVE := preload("res://scripts/riftline_responsive_layout.gd")

var _board := false
var _crew_board := false
var _selected := "solo"
var _selected_frame := "vane"
var _button_rects: Dictionary = {}
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_selected_frame = CREW_PROFILE.load_frame()
	queue_redraw()

func show_entry(last_drill: String = "solo") -> void:
	_board = false
	_crew_board = false
	_selected = last_drill if last_drill in ["solo", "wing", "full"] else "solo"
	visible = true
	queue_redraw()

func open_board() -> void:
	_board = true
	_crew_board = false
	visible = true
	queue_redraw()

func open_crew_board() -> void:
	_board = false
	_crew_board = true
	visible = true
	queue_redraw()

func apply_preview(preview: String) -> void:
	match preview:
		"entry":
			show_entry(_selected)
		"board":
			open_board()
		"crew-board":
			open_crew_board()
		"vane", "cradle", "keel", "loom":
			_selected_frame = preview
			open_crew_board()
		"wing":
			_selected = "wing"
			show_entry(_selected)
		"full-line":
			_selected = "full"
			open_board()
		"solo", "wing", "full":
			_selected = preview
			visible = false
			drill_requested.emit(preview)
		"local-rift":
			visible = false
			local_rift_requested.emit()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed := false
	var point := Vector2.ZERO
	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
		point = event.position
	elif event is InputEventScreenTouch:
		# iOS touch-to-mouse emulation is disabled so movement gestures cannot
		# accidentally fire.  Handle the native tap event at the same seam.
		pressed = event.pressed
		point = event.position
	if pressed:
		for key in _button_rects.keys():
			if _button_rects[key].has_point(point):
				_accept(str(key))
				accept_event()

func _accept(key: String) -> void:
	match key:
		"enter":
			visible = false
			drill_requested.emit(_selected)
		"choose":
			open_board()
		"crew":
			open_crew_board()
		"crew-back":
			show_entry(_selected)
		"vane", "cradle", "keel", "loom":
			_selected_frame = key
			CREW_PROFILE.save_frame(_selected_frame)
			open_crew_board()
		"back":
			show_entry(_selected)
		"local-rift":
			visible = false
			local_rift_requested.emit()
		"solo", "wing", "full":
			_selected = key
			visible = false
			drill_requested.emit(key)

func _draw() -> void:
	if not visible:
		return
	_button_rects.clear()
	draw_rect(Rect2(Vector2.ZERO, size), INK, true)
	draw_line(Vector2(48.0, 42.0), Vector2(size.x - 48.0, 42.0), Color(VOID, 0.24), 1.0)
	draw_string(_font, Vector2(52.0, 31.0), "WhoYouPeekin / FIELD DRILLS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, MUTED)
	if _crew_board:
		_draw_crew_board()
	elif _board:
		_draw_board()
	else:
		_draw_entry()

func _draw_entry() -> void:
	var safe := RESPONSIVE.safe_rect(self)
	var left := safe.position.x + 22.0
	var top := maxf(safe.position.y + 74.0, safe.size.y * 0.18)
	draw_string(_font, Vector2(left, top), "STEP INTO THE STORM", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, PAPER)
	draw_string(_font, Vector2(left, top + 34.0), "A quiet relay bay. A live Seed. A crew that moves with purpose.", HORIZONTAL_ALIGNMENT_LEFT, minf(safe.size.x - 44.0, 720.0), 15, MUTED)
	var diagram_center := Vector2(safe.end.x - minf(220.0, safe.size.x * 0.24), top + 28.0)
	_draw_formation(diagram_center, _selected, 1.0)
	var crew_button_width := minf(250.0, safe.size.x * 0.32)
	_register_button("crew", Rect2(left + minf(270.0, safe.size.x * 0.28), top + 178.0, crew_button_width, 58.0))
	draw_rect(_button_rects["crew"], PANEL, true)
	draw_line(_button_rects["crew"].position, _button_rects["crew"].position + Vector2(_button_rects["crew"].size.x, 0), VOID, 1.5)
	var crew_label := "CREW FRAME: %s" % CREW_IDENTITY.facts(_selected_frame).get("name", "VANE")
	var crew_label_width := _font.get_string_size(crew_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(_font, _button_rects["crew"].get_center() + Vector2(-crew_label_width * 0.5, 5.0), crew_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, PAPER)
	var label := _drill_label(_selected)
	draw_string(_font, Vector2(left, top + 115.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, SUN)
	draw_string(_font, Vector2(left, top + 145.0), _drill_description(_selected), HORIZONTAL_ALIGNMENT_LEFT, minf(safe.size.x - 44.0, 620.0), 15, PAPER)
	var action_y := safe.end.y - 106.0
	_register_button("enter", Rect2(left, action_y, 250.0, 58.0))
	draw_rect(_button_rects["enter"], SUN, true)
	draw_string(_font, _button_rects["enter"].get_center() + Vector2(-45.0, 6.0), "ENTER DRILL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, INK)
	_register_button("choose", Rect2(left + 270.0, action_y, 220.0, 58.0))
	draw_rect(_button_rects["choose"], PANEL, true)
	draw_line(_button_rects["choose"].position, _button_rects["choose"].position + Vector2(220.0, 0), VOID, 1.5)
	draw_string(_font, _button_rects["choose"].get_center() + Vector2(-47.0, 6.0), "CHOOSE DRILL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, PAPER)
	draw_string(_font, Vector2(left, safe.end.y - 18.0), "OFFLINE PRACTICE / LAST DRILL REMEMBERED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, MUTED)

func _draw_crew_board() -> void:
	var safe := RESPONSIVE.safe_rect(self)
	var left := safe.position.x + 48.0
	var top := safe.position.y + 62.0
	draw_string(_font, Vector2(left, top), "CHOOSE YOUR CREW FRAME", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, PAPER)
	draw_string(_font, Vector2(left, top + 30.0), "Field identity changes the outline, never the combat contract.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, MUTED)
	var card_width := minf(270.0, (safe.size.x - 120.0) / 4.0)
	var gap := 18.0
	var start_x := safe.position.x + (safe.size.x - card_width * 4.0 - gap * 3.0) * 0.5
	for index in 4:
		var frame_id: String = CREW_IDENTITY.ORDERED_IDS[index]
		var rect := Rect2(start_x + index * (card_width + gap), top + 66.0, card_width, 250.0)
		_register_button(frame_id, rect)
		var selected := frame_id == _selected_frame
		draw_rect(rect, Color(PANEL, 0.98), true)
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), SUN if selected else VOID, 3.0 if selected else 1.3)
		_draw_frame_glyph(rect.get_center() + Vector2(0.0, -36.0), frame_id, 1.0)
		var facts := CREW_IDENTITY.facts(frame_id)
		draw_string(_font, rect.position + Vector2(18.0, 158.0), str(facts.name), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, PAPER)
		draw_string(_font, rect.position + Vector2(18.0, 184.0), str(facts.purpose), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, SUN if selected else MUTED)
		draw_string(_font, rect.position + Vector2(18.0, 216.0), "SELECTED" if selected else "CHOOSE FRAME", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, PAPER if selected else MUTED)
	_register_button("crew-back", Rect2(safe.end.x - 178.0, safe.end.y - 70.0, 130.0, 52.0))
	draw_rect(_button_rects["crew-back"], PANEL, true)
	draw_string(_font, _button_rects["crew-back"].get_center() + Vector2(-19.0, 5.0), "BACK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, PAPER)

func _draw_frame_glyph(center: Vector2, frame_id: String, scale: float) -> void:
	var ink := Color("17263e")
	var accent := SUN if frame_id == _selected_frame else VOID
	draw_circle(center + Vector2(0.0, 8.0), 16.0 * scale, ink)
	draw_rect(Rect2(center + Vector2(-14.0, 24.0), Vector2(28.0, 40.0) * scale), ink, true)
	match frame_id:
		"vane":
			draw_line(center + Vector2(16.0, 8.0), center + Vector2(30.0, -40.0), accent, 4.0)
			draw_line(center + Vector2(22.0, -38.0), center + Vector2(38.0, -34.0), accent, 3.0)
		"cradle":
			draw_arc(center + Vector2(-14.0, -4.0), 14.0, PI * 0.2, PI * 1.8, 16, accent, 3.0)
			draw_arc(center + Vector2(14.0, -4.0), 14.0, -PI * 0.8, PI * 0.8, 16, accent, 3.0)
		"keel":
			draw_line(center + Vector2(-22.0, 16.0), center + Vector2(22.0, 50.0), accent, 5.0)
			draw_rect(Rect2(center + Vector2(-22.0, 22.0), Vector2(44.0, 14.0)), Color(accent, 0.3), true)
		"loom":
			draw_line(center + Vector2(-10.0, 0.0), center + Vector2(-16.0, -38.0), accent, 3.0)
			draw_line(center + Vector2(10.0, 0.0), center + Vector2(16.0, -38.0), accent, 3.0)

func _draw_board() -> void:
	var safe := RESPONSIVE.safe_rect(self)
	var left := safe.position.x + 22.0
	var top := maxf(safe.position.y + 48.0, safe.size.y * 0.13)
	draw_string(_font, Vector2(left, top), "CHOOSE YOUR FIELD DRILL", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 28, PAPER)
	draw_string(_font, Vector2(left, top + 32.0), "Same Seed. Same gates. Different crew reach.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, MUTED)
	var gap := 18.0
	var card_width := minf(340.0, (safe.size.x - 44.0 - gap * 2.0) / 3.0)
	var start_x := safe.position.x + (safe.size.x - card_width * 3.0 - gap * 2.0) * 0.5
	for index in 3:
		var key: String = ["solo", "wing", "full"][index]
		var rect := Rect2(start_x + index * (card_width + gap), top + 78.0, card_width, 250.0)
		_register_button(key, rect)
		draw_rect(rect, PANEL, true)
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), SUN if key == _selected else VOID, 2.0)
		_draw_formation(rect.position + Vector2(rect.size.x * 0.5, 82.0), key, 0.82)
		draw_string(_font, rect.position + Vector2(24.0, 160.0), _drill_label(key), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, PAPER)
		draw_string(_font, rect.position + Vector2(24.0, 190.0), _drill_description(key), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 48.0, 13, MUTED)
	_register_button("local-rift", Rect2(start_x, top + 360.0, card_width, 58.0))
	draw_rect(_button_rects["local-rift"], Color("182a47"), true)
	draw_string(_font, _button_rects["local-rift"].get_center() + Vector2(-54.0, 5.0), "LOCAL RIFT", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, PAPER)
	draw_string(_font, Vector2(start_x + card_width + gap, top + 395.0), "Nearby local play through the existing relay link.", HORIZONTAL_ALIGNMENT_LEFT, card_width * 2.0, 13, MUTED)
	_register_button("back", Rect2(safe.end.x - 162.0, safe.end.y - 62.0, 140.0, 52.0))
	draw_rect(_button_rects["back"], PANEL, true)
	draw_string(_font, _button_rects["back"].get_center() + Vector2(-18.0, 5.0), "BACK", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, PAPER)

func _draw_formation(center: Vector2, drill: String, scale: float) -> void:
	var line_y := center.y + 42.0 * scale
	draw_line(center + Vector2(-145.0 * scale, 0), center + Vector2(145.0 * scale, 0), Color(MUTED, 0.35), 1.0)
	draw_circle(center, 8.0 * scale, Color("fff4c7"))
	var sun_points: Array[Vector2] = []
	var void_points: Array[Vector2] = []
	match drill:
		"solo":
			sun_points = [center + Vector2(-72.0, 0)]
			void_points = [center + Vector2(72.0, 0)]
		"wing":
			sun_points = [center + Vector2(-74.0, -24.0), center + Vector2(-74.0, 24.0)]
			void_points = [center + Vector2(74.0, -24.0), center + Vector2(74.0, 24.0)]
		_:
			sun_points = [center + Vector2(-82.0, -32.0), center + Vector2(-90.0, 0), center + Vector2(-82.0, 32.0)]
			void_points = [center + Vector2(82.0, -32.0), center + Vector2(90.0, 0), center + Vector2(82.0, 32.0)]
	for point in sun_points:
		draw_circle(point, 8.0 * scale, SUN)
		draw_line(point, center, Color(SUN, 0.28), 1.0)
	for point in void_points:
		draw_circle(point, 8.0 * scale, VOID)
		draw_line(point, center, Color(VOID, 0.28), 1.0)

func _register_button(key: String, rect: Rect2) -> void:
	_button_rects[key] = rect

func _drill_label(key: String) -> String:
	return {"solo": "SOLO LINE", "wing": "WING LINE", "full": "FULL LINE"}.get(key, "SOLO LINE")

func _drill_description(key: String) -> String:
	return {
		"solo": "Read one rival and learn the Seed line.",
		"wing": "Move with a small wing through the Concourse.",
		"full": "Join a full crew across three authored lanes.",
	}.get(key, "Read one rival and learn the Seed line.")
