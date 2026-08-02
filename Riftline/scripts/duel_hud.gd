class_name DuelHud
extends Control

var movement := Vector2.ZERO
var fire_held := false
var aim_held := false
var health := 100.0
var damage_flash := 0.0
var camera_sensitivity := 1.0
var ads_sensitivity := 0.72
var gyro_enabled := false

var _look_delta := Vector2.ZERO
var _jump_requested := false
var _crouch_requested := false
var _prone_requested := false
var _weapon_switch_requested := false
var _left_touch := -1
var _right_touch := -1
var _left_fire_touch := -1
var _right_fire_touch := -1
var _aim_touch := -1
var _jump_touch := -1
var _crouch_touch := -1
var _prone_touch := -1
var _switch_touch := -1
var _left_origin := Vector2.ZERO
var _left_position := Vector2.ZERO
var _sun_score := 0
var _void_score := 0
var _stance := Duelist.Stance.STAND
var _weapon := Duelist.Weapon.PULSE
var _settings_open := false
var _aim_toggle := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_control_settings()
	queue_redraw()

func _process(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta * 2.8)
	queue_redraw()

func take_look_delta() -> Vector2:
	var delta := _look_delta
	_look_delta = Vector2.ZERO
	return delta * (ads_sensitivity if aim_held else camera_sensitivity)

func take_jump() -> bool:
	var requested := _jump_requested
	_jump_requested = false
	return requested

func take_crouch() -> bool:
	var requested := _crouch_requested
	_crouch_requested = false
	return requested

func take_prone() -> bool:
	var requested := _prone_requested
	_prone_requested = false
	return requested

func take_weapon_switch() -> bool:
	var requested := _weapon_switch_requested
	_weapon_switch_requested = false
	return requested

func set_score(sun: int, void_score: int) -> void:
	_sun_score = sun
	_void_score = void_score

func set_stance(stance: Duelist.Stance) -> void:
	_stance = stance

func set_weapon(weapon: Duelist.Weapon) -> void:
	_weapon = weapon

func open_settings() -> void:
	_settings_open = true

func show_damage(current_health: float) -> void:
	health = current_health
	damage_flash = 1.0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		if _settings_open:
			_handle_settings_touch(event.position, true)
		else:
			_handle_drag(event.index, event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		fire_held = event.pressed
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_look_delta += event.relative

func _handle_touch(index: int, point: Vector2, pressed: bool) -> void:
	if _settings_open:
		_handle_settings_touch(point, pressed)
		return
	if not pressed:
		_release_touch(index)
		return
	if _pressed_circle(point, _settings_center(), 28.0):
		_settings_open = true
		_save_control_settings()
		return
	if _pressed_circle(point, _left_fire_center(), 50.0):
		_left_fire_touch = index
		fire_held = true
		return
	if _pressed_circle(point, _right_fire_center(), 70.0):
		_right_fire_touch = index
		fire_held = true
		return
	if _pressed_circle(point, _aim_center(), 42.0):
		_aim_touch = index
		aim_held = not aim_held if _aim_toggle else true
		return
	if _pressed_circle(point, _jump_center(), 40.0):
		_jump_touch = index
		_jump_requested = true
		return
	if _pressed_circle(point, _crouch_center(), 37.0):
		_crouch_touch = index
		_crouch_requested = true
		return
	if _pressed_circle(point, _prone_center(), 37.0):
		_prone_touch = index
		_prone_requested = true
		return
	if _pressed_circle(point, _switch_center(), 37.0):
		_switch_touch = index
		_weapon_switch_requested = true
		return
	if point.x < size.x * 0.43:
		_left_touch = index
		_left_origin = point
		_left_position = point
		return
	_right_touch = index

func _handle_drag(index: int, point: Vector2, relative: Vector2) -> void:
	if index == _left_touch:
		_left_position = point
		movement = (point - _left_origin).limit_length(74.0) / 74.0
	elif index == _right_touch:
		_look_delta += relative

func _release_touch(index: int) -> void:
	if index == _left_touch:
		_left_touch = -1
		movement = Vector2.ZERO
	if index == _right_touch:
		_right_touch = -1
	if index == _left_fire_touch:
		_left_fire_touch = -1
	if index == _right_fire_touch:
		_right_fire_touch = -1
	if _left_fire_touch < 0 and _right_fire_touch < 0:
		fire_held = false
	if index == _aim_touch:
		_aim_touch = -1
		if not _aim_toggle:
			aim_held = false
	if index == _jump_touch:
		_jump_touch = -1
	if index == _crouch_touch:
		_crouch_touch = -1
	if index == _prone_touch:
		_prone_touch = -1
	if index == _switch_touch:
		_switch_touch = -1

func _draw() -> void:
	var friendly := Color("ffad5d")
	var enemy := Color("71cfff")
	var center := size * 0.5

	# The reticle stays clean so that finger controls never compete with target acquisition.
	draw_arc(center, 14.0, 0.12, 1.24, 12, Color(friendly, 0.9), 2.0)
	draw_arc(center, 14.0, 3.26, 4.38, 12, Color(friendly, 0.9), 2.0)
	draw_line(center + Vector2(-25, 0), center + Vector2(-10, 0), Color(friendly, 0.86), 2.0)
	draw_line(center + Vector2(10, 0), center + Vector2(25, 0), Color(friendly, 0.86), 2.0)

	var stick_center := _left_origin if _left_touch >= 0 else Vector2(120, size.y - 112)
	draw_circle(stick_center, 58.0, Color("08142a", 0.42))
	draw_arc(stick_center, 58.0, 0.0, TAU, 32, Color(friendly, 0.38), 2.0)
	var knob := _left_position if _left_touch >= 0 else stick_center
	draw_circle(knob, 24.0, Color(friendly, 0.34))
	draw_arc(knob, 24.0, 0.0, TAU, 24, Color(friendly, 0.9), 2.0)

	_draw_button(_left_fire_center(), 50.0, friendly, _left_fire_touch >= 0, "FIRE")
	_draw_button(_right_fire_center(), 68.0, friendly, _right_fire_touch >= 0, "FIRE")
	_draw_button(_aim_center(), 42.0, enemy, aim_held, "ADS")
	_draw_button(_jump_center(), 40.0, enemy, _jump_touch >= 0, "JUMP")
	_draw_button(_crouch_center(), 37.0, friendly, _stance == Duelist.Stance.CROUCH, "C")
	_draw_button(_prone_center(), 37.0, friendly, _stance == Duelist.Stance.PRONE, "P")
	_draw_button(_switch_center(), 37.0, Color("c292ff"), _switch_touch >= 0, "SWAP")
	_draw_weapon_indicator(friendly)
	_draw_button(_settings_center(), 24.0, enemy, _settings_open, "SET")

	var health_width := 210.0
	draw_rect(Rect2(34, 34, health_width, 8), Color("03101f", 0.72))
	draw_rect(Rect2(34, 34, health_width * health / 100.0, 8), Color(friendly, 0.92))
	for score in _sun_score:
		draw_circle(Vector2(size.x * 0.5 - 19.0 - score * 13.0, 42), 4.0, friendly)
	for score in _void_score:
		draw_circle(Vector2(size.x * 0.5 + 19.0 + score * 13.0, 42), 4.0, enemy)
	if damage_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.18, 0.1, damage_flash * 0.16), false, 22.0)
	if _settings_open:
		_draw_settings_panel(friendly, enemy)

func _draw_button(center: Vector2, radius: float, color: Color, active: bool, label: String) -> void:
	draw_circle(center, radius, Color("071126", 0.58))
	draw_arc(center, radius, 0.0, TAU, 32, Color(color, 0.95 if active else 0.6), 2.5 if active else 1.8)
	var font := ThemeDB.fallback_font
	var font_size := 13 if label.length() > 1 else 20
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-text_width * 0.5, font_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, 0.98))

func _draw_weapon_indicator(color: Color) -> void:
	var center := Vector2(size.x - 480.0, size.y - 84.0)
	draw_rect(Rect2(center - Vector2(34, 20), Vector2(68, 40)), Color("071126", 0.58), true)
	draw_arc(center, 30.0, 0.0, TAU, 24, Color(color, 0.92), 2.0)
	if _weapon == Duelist.Weapon.PULSE:
		draw_rect(Rect2(center - Vector2(16, 4), Vector2(32, 8)), color)
	else:
		for offset in [-10.0, 0.0, 10.0]:
			draw_circle(center + Vector2(offset, 0), 5.0, Color("c292ff"))

func _pressed_circle(point: Vector2, center: Vector2, radius: float) -> bool:
	return point.distance_squared_to(center) <= radius * radius

func _handle_settings_touch(point: Vector2, pressed: bool) -> void:
	if not pressed:
		return
	var panel := _settings_panel()
	if not panel.has_point(point):
		_settings_open = false
		return
	var camera_track := Rect2(panel.position + Vector2(130, 76), Vector2(panel.size.x - 164, 24))
	var ads_track := Rect2(panel.position + Vector2(130, 122), Vector2(panel.size.x - 164, 24))
	if camera_track.grow(12.0).has_point(point):
		camera_sensitivity = clampf((point.x - camera_track.position.x) / camera_track.size.x * 1.4 + 0.3, 0.3, 1.7)
		_save_control_settings()
		return
	if ads_track.grow(12.0).has_point(point):
		ads_sensitivity = clampf((point.x - ads_track.position.x) / ads_track.size.x * 1.4 + 0.3, 0.3, 1.7)
		_save_control_settings()
		return
	if Rect2(panel.position + Vector2(24, 168), Vector2(142, 42)).has_point(point):
		_aim_toggle = not _aim_toggle
		_save_control_settings()
		return
	if Rect2(panel.position + Vector2(184, 168), Vector2(142, 42)).has_point(point):
		gyro_enabled = not gyro_enabled
		_save_control_settings()

func _draw_settings_panel(friendly: Color, enemy: Color) -> void:
	var panel := _settings_panel()
	draw_rect(Rect2(Vector2.ZERO, size), Color("020612", 0.68))
	draw_rect(panel, Color("0b1730", 0.98))
	draw_line(panel.position, panel.position + Vector2(panel.size.x, 0), friendly, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, panel.position + Vector2(24, 34), "COMBAT SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f1f6ff"))
	draw_string(font, panel.position + Vector2(24, 91), "CAMERA", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, enemy)
	draw_string(font, panel.position + Vector2(24, 137), "ADS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, enemy)
	_draw_setting_slider(panel.position + Vector2(130, 88), panel.size.x - 164, camera_sensitivity, friendly)
	_draw_setting_slider(panel.position + Vector2(130, 134), panel.size.x - 164, ads_sensitivity, friendly)
	_draw_setting_chip(Rect2(panel.position + Vector2(24, 168), Vector2(142, 42)), "AIM %s" % ("TAP" if _aim_toggle else "HOLD"), friendly, _aim_toggle)
	_draw_setting_chip(Rect2(panel.position + Vector2(184, 168), Vector2(142, 42)), "GYRO %s" % ("ON" if gyro_enabled else "OFF"), Color("c292ff"), gyro_enabled)
	_draw_setting_chip(Rect2(panel.position + Vector2(344, 168), Vector2(142, 42)), "QUICK SWAP", Color("c292ff"), true)
	draw_string(font, panel.position + Vector2(24, panel.size.y - 22), "Tap outside to return", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("92a7c7"))

func _draw_setting_slider(position: Vector2, width: float, value: float, color: Color) -> void:
	draw_line(position, position + Vector2(width, 0), Color("233b64"), 5.0)
	var normalized := (value - 0.3) / 1.4
	draw_line(position, position + Vector2(width * normalized, 0), color, 5.0)
	draw_circle(position + Vector2(width * normalized, 0), 9.0, color)

func _draw_setting_chip(rect: Rect2, text: String, color: Color, active: bool) -> void:
	draw_rect(rect, Color(color, 0.18 if active else 0.07), true)
	draw_rect(rect, Color(color, 0.86), false, 1.4)
	var font := ThemeDB.fallback_font
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, rect.get_center() + Vector2(-text_width * 0.5, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func _settings_panel() -> Rect2:
	return Rect2(size * 0.5 - Vector2(260, 130), Vector2(520, 260))

func _load_control_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://riftline_controls.cfg") != OK:
		return
	camera_sensitivity = clampf(float(config.get_value("sensitivity", "camera", camera_sensitivity)), 0.3, 1.7)
	ads_sensitivity = clampf(float(config.get_value("sensitivity", "ads", ads_sensitivity)), 0.3, 1.7)
	gyro_enabled = bool(config.get_value("controls", "gyro", gyro_enabled))
	_aim_toggle = bool(config.get_value("controls", "aim_toggle", _aim_toggle))

func _save_control_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("sensitivity", "camera", camera_sensitivity)
	config.set_value("sensitivity", "ads", ads_sensitivity)
	config.set_value("controls", "gyro", gyro_enabled)
	config.set_value("controls", "aim_toggle", _aim_toggle)
	config.save("user://riftline_controls.cfg")

func _left_fire_center() -> Vector2:
	return Vector2(102.0, 130.0)

func _right_fire_center() -> Vector2:
	return Vector2(size.x - 112.0, size.y - 112.0)

func _aim_center() -> Vector2:
	return Vector2(size.x - 218.0, size.y - 206.0)

func _jump_center() -> Vector2:
	return Vector2(size.x - 218.0, size.y - 102.0)

func _crouch_center() -> Vector2:
	return Vector2(size.x - 310.0, size.y - 102.0)

func _prone_center() -> Vector2:
	return Vector2(size.x - 394.0, size.y - 102.0)

func _switch_center() -> Vector2:
	return Vector2(size.x - 394.0, size.y - 198.0)

func _settings_center() -> Vector2:
	return Vector2(size.x - 44.0, 46.0)
