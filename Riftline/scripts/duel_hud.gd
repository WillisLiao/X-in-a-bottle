class_name DuelHud
extends Control

signal rift_link_requested
signal feedback_preferences_changed(effects_enabled: bool, haptics_enabled: bool)

const CONFIG_PATH := "user://riftline_controls.cfg"
const LAYOUT_SECTION := "hud_layout_v1"
const FEEDBACK_SECTION := "feedback_v1"
const LAYOUT_VERSION := 2
const SNAP_POINTS := 8.0
const DRAG_THRESHOLD := 10.0
const MOVABLE_KEYS := ["move", "left_fire", "right_fire", "ads", "jump", "crouch", "prone", "swap"]

var movement := Vector2.ZERO
var fire_held := false
var aim_held := false
var health := 100.0
var magazine_rounds := Duelist.M4_MAGAZINE_SIZE
var reserve_ammo := Duelist.M4_RESERVE_AMMO
var reload_remaining := 0.0
var damage_flash := 0.0
var hit_confirm := 0.0
var primary_fire_bloom := 0.0
var damage_direction := Vector2.ZERO
var damage_direction_intensity := 0.0
var damage_enemy_team := int(Duelist.Team.VOID)
var objective_feedback_pulse := 0.0
var objective_feedback_team := -1
var camera_sensitivity := 1.0
var ads_sensitivity := 0.72
var gyro_enabled := false
var effects_enabled := true
var haptics_enabled := true
var _stick_mode := MobileTouchRouter.StickMode.FLOATING
var _touch_router := MobileTouchRouter.new()
var _stick_visual_opacity := 0.0
var _stick_visual_target := 0.0
var _coach_cue: Dictionary = {}
var _coach_display_cue: Dictionary = {}

static func save_feedback_preferences(config: ConfigFile, next_effects_enabled: bool, next_haptics_enabled: bool) -> void:
	config.set_value(FEEDBACK_SECTION, "version", 1)
	config.set_value(FEEDBACK_SECTION, "effects", next_effects_enabled)
	config.set_value(FEEDBACK_SECTION, "haptics", next_haptics_enabled)

static func load_feedback_preferences(config: ConfigFile, default_effects_enabled: bool = true, default_haptics_enabled: bool = true) -> Dictionary:
	return {
		"effects_enabled": bool(config.get_value(FEEDBACK_SECTION, "effects", default_effects_enabled)),
		"haptics_enabled": bool(config.get_value(FEEDBACK_SECTION, "haptics", default_haptics_enabled)),
	}
var _coach_visual_opacity := 0.0
var _coach_visual_target := 0.0
var _touch_preview := ""
var _ammo_preview_override := false

var _look_delta := Vector2.ZERO
var _jump_requested := false
var _crouch_requested := false
var _prone_requested := false
var _weapon_switch_requested := false
var _reload_requested := false
var _left_fire_touch := -1
var _right_fire_touch := -1
var _aim_touch := -1
var _jump_touch := -1
var _crouch_touch := -1
var _prone_touch := -1
var _switch_touch := -1
var _sun_score := 0
var _void_score := 0
var _roster_state: Array[Dictionary] = []
var _roster_local_team := int(Duelist.Team.SUN)
var _squad_readability := false
var _objective_state: Dictionary = {"state": int(RiftSeed.State.HOME), "carrier_id": "", "carrier_team": -1}
var _carrier_chevron_active := false
var _carrier_chevron_direction := Vector2.RIGHT
var _objective_message := ""
var _objective_message_remaining := 0.0
var _score_pulse := 0.0
var _score_pulse_team := -1
var _stance := Duelist.Stance.STAND
var _weapon := Duelist.Weapon.PULSE
var _settings_open := false
var _layout_editor := false
var _aim_toggle := false
var _layout: Dictionary = {}
var _selected_layout_key := ""
var _editor_touch := -1
var _editor_drag_start := Vector2.ZERO
var _editor_start_center := Vector2.ZERO
var _editor_dragging := false
var _layout_dirty := false
var _combat_input_enabled := true
var _match_result_visible := false
var _match_result_victory := false
var _rematch_requested := false
var _match_phase: LinebreakMatch.Phase = LinebreakMatch.Phase.OPENING
var _connection_flow_active := false
var _connection_message := ""
var _connection_message_remaining := 0.0
var _reset_training_requested := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout = _default_layout()
	_load_control_settings()
	_touch_router.configure(_stick_mode, _control_center("move"), _stick_radius())
	queue_redraw()

func _process(delta: float) -> void:
	damage_flash = maxf(0.0, damage_flash - delta * 2.8)
	hit_confirm = maxf(0.0, hit_confirm - delta * 6.5)
	primary_fire_bloom = maxf(0.0, primary_fire_bloom - delta * 8.5)
	damage_direction_intensity = maxf(0.0, damage_direction_intensity - delta * 4.0)
	objective_feedback_pulse = maxf(0.0, objective_feedback_pulse - delta * 3.0)
	_objective_message_remaining = maxf(0.0, _objective_message_remaining - delta)
	_score_pulse = maxf(0.0, _score_pulse - delta * 2.8)
	if _objective_message_remaining <= 0.0:
		_objective_message = ""
	_connection_message_remaining = maxf(0.0, _connection_message_remaining - delta)
	if _connection_message_remaining <= 0.0:
		_connection_message = ""
	_stick_visual_opacity = move_toward(_stick_visual_opacity, _stick_visual_target, delta * 12.0)
	_coach_visual_opacity = move_toward(_coach_visual_opacity, _coach_visual_target, delta * 5.5)
	if _coach_visual_target <= 0.0 and _coach_visual_opacity <= 0.01:
		_coach_display_cue = {}
	queue_redraw()

func take_look_delta() -> Vector2:
	var delta := _look_delta + _touch_router.take_look_delta()
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

func take_reload() -> bool:
	var requested := _reload_requested
	_reload_requested = false
	return requested

func take_reset_training() -> bool:
	var requested := _reset_training_requested
	_reset_training_requested = false
	return requested

func set_coach_cue(cue: Dictionary) -> void:
	_coach_cue = cue.duplicate(true)
	if _coach_cue.is_empty():
		_coach_visual_target = 0.0
	else:
		_coach_display_cue = _coach_cue.duplicate(true)
		_coach_visual_target = 1.0
	queue_redraw()

func set_touch_preview(preview: String) -> void:
	_touch_preview = preview
	_ammo_preview_override = preview in ["ammo-low", "reloading"]
	if preview == "two-thumb":
		_layout = _two_thumb_layout()
	elif preview == "four-finger":
		_layout = _four_finger_layout()
	elif preview == "fixed-stick":
		_stick_mode = MobileTouchRouter.StickMode.FIXED
		_touch_router.configure(_stick_mode, _control_center("move"), _stick_radius())
	elif preview in ["floating-left", "floating-edge"]:
		_stick_mode = MobileTouchRouter.StickMode.FLOATING
		_touch_router.configure(_stick_mode, _control_center("move"), _stick_radius())
	if preview in ["floating-left", "floating-edge"]:
		_stick_visual_target = 1.0
		_stick_visual_opacity = 1.0
	if preview == "ammo-low":
		show_ammo(4, 24, 0.0)
	elif preview == "reloading":
		show_ammo(4, 24, Duelist.M4_RELOAD_SECONDS * 0.5)
	if preview == "coach-move":
		set_coach_cue({"key": "move", "text": "DRAG LEFT SIDE TO MOVE", "region": "left"})
	elif preview == "coach-look":
		set_coach_cue({"key": "look", "text": "DRAG RIGHT SIDE TO LOOK", "region": "right"})
	elif preview == "coach-fire":
		set_coach_cue({"key": "fire", "text": "HOLD FIRE TO ENGAGE", "region": "fire"})
	elif preview == "coach-seed":
		set_coach_cue({"key": "seed", "text": "TAKE THE SEED THROUGH THEIR RIFT", "region": "seed"})

func set_score(sun: int, void_score: int) -> void:
	_sun_score = clampi(sun, 0, 3)
	_void_score = clampi(void_score, 0, 3)
	queue_redraw()

func set_roster_state(records: Array[Dictionary], local_team: int, squad_readability: bool) -> void:
	_roster_state.clear()
	for record in records:
		_roster_state.append(record.duplicate(true))
	_roster_local_team = local_team
	_squad_readability = squad_readability
	queue_redraw()

func set_objective_state(state: Dictionary) -> void:
	if state.has("objective") and state.get("objective") is Dictionary:
		_objective_state = state.get("objective")
	else:
		_objective_state = state.duplicate(true)
	queue_redraw()

func set_carrier_navigation(active: bool, direction: Vector2 = Vector2.RIGHT) -> void:
	_carrier_chevron_active = active
	if direction.length_squared() > 0.01:
		_carrier_chevron_direction = direction.normalized()
	queue_redraw()

func safe_area_rect() -> Rect2:
	return _safe_rect()

func show_objective_event(event_type: String, _state: Dictionary) -> void:
	match event_type:
		"objective_claimed":
			_objective_message = "SEED CLAIMED"
		"objective_dropped":
			_objective_message = "SEED DROPPED"
		"objective_returned":
			_objective_message = "SEED RETURNS"
		"objective_delivered":
			_objective_message = "LINE BREACHED"
			_score_pulse = 1.0
			_score_pulse_team = int(_state.get("scoring_team", -1))
		_:
			return
	_objective_message_remaining = 1.4
	queue_redraw()

func show_practice_cue(message: String) -> void:
	_objective_message = message
	_objective_message_remaining = 1.8
	queue_redraw()

func set_stance(stance: Duelist.Stance) -> void:
	_stance = stance

func set_weapon(weapon: Duelist.Weapon) -> void:
	_weapon = weapon

func show_ammo(magazine: int, reserve: int, reload_time: float) -> void:
	if _ammo_preview_override:
		return
	magazine_rounds = clampi(magazine, 0, Duelist.M4_MAGAZINE_SIZE)
	reserve_ammo = clampi(reserve, 0, Duelist.M4_RESERVE_AMMO)
	reload_remaining = maxf(0.0, reload_time)
	queue_redraw()

func open_settings() -> void:
	_release_all_touch_ownership()
	_layout_editor = false
	_settings_open = true
	queue_redraw()

func open_hud_layout() -> void:
	_release_all_touch_ownership()
	_settings_open = false
	_layout_editor = true
	_selected_layout_key = ""
	_layout_dirty = false
	queue_redraw()

func set_combat_input_enabled(enabled: bool) -> void:
	_combat_input_enabled = enabled
	if not enabled:
		_release_all_touch_ownership()
	queue_redraw()

func set_connection_flow_active(active: bool) -> void:
	_connection_flow_active = active
	if active:
		_release_all_touch_ownership()
	queue_redraw()

func show_connection_message(message: String) -> void:
	_connection_message = message
	_connection_message_remaining = 2.8
	queue_redraw()

func can_drive_combat() -> bool:
	return _combat_input_enabled and not _connection_flow_active and not _settings_open and not _layout_editor and not _match_result_visible

func set_match_phase(phase: LinebreakMatch.Phase) -> void:
	_match_phase = phase
	if phase != LinebreakMatch.Phase.FINISHED:
		_match_result_visible = false
		_rematch_requested = false
	queue_redraw()

func show_match_result(winner: Duelist.Team) -> void:
	_match_result_victory = int(winner) == _roster_local_team
	_match_result_visible = true
	_rematch_requested = false
	_release_all_touch_ownership()
	queue_redraw()

func take_rematch() -> bool:
	var requested := _rematch_requested
	_rematch_requested = false
	return requested

func show_damage(current_health: float) -> void:
	health = current_health
	damage_flash = maxf(damage_flash, 1.0)
	queue_redraw()

func show_damage_direction(direction: Vector2, intensity: float, enemy_team: int) -> void:
	damage_direction = direction
	damage_direction_intensity = clampf(intensity, 0.0, 1.0)
	damage_enemy_team = enemy_team
	queue_redraw()

func show_hit_confirm() -> void:
	hit_confirm = 1.0
	queue_redraw()

func show_primary_fire_feedback() -> void:
	primary_fire_bloom = minf(1.0, primary_fire_bloom + 0.72)
	queue_redraw()

func show_objective_feedback(event_type: String, scoring_team: int) -> void:
	objective_feedback_pulse = 1.0
	objective_feedback_team = scoring_team
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if _connection_flow_active:
		return
	if _match_result_visible:
		if event is InputEventScreenTouch and event.pressed and _rematch_rect().grow(12.0).has_point(event.position):
			_rematch_requested = true
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _rematch_rect().grow(12.0).has_point(event.position):
			_rematch_requested = true
		return
	if event is InputEventScreenTouch:
		if _layout_editor:
			_handle_editor_touch(event.index, event.position, event.pressed)
		elif _settings_open:
			_handle_settings_touch(event.position, event.pressed)
		else:
			_handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		if _layout_editor:
			_handle_editor_drag(event.index, event.position)
		elif _settings_open:
			_handle_settings_touch(event.position, true)
		else:
			_handle_drag(event.index, event.position, event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if _layout_editor:
			_handle_editor_touch(0, event.position, event.pressed)
		elif _settings_open:
			_handle_settings_touch(event.position, event.pressed)
		else:
			if event.pressed and _pressed_circle(event.position, _reload_center(), _reload_radius() + 12.0):
				_reload_requested = true
				fire_held = false
			else:
				fire_held = event.pressed
	elif event is InputEventMouseMotion:
		if _layout_editor and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_handle_editor_drag(0, event.position)
		elif not _settings_open and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_look_delta += event.relative

func _handle_touch(index: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		_release_touch(index)
		return
	if _pressed_circle(point, _settings_center(), 30.0):
		open_settings()
		return
	if not _combat_input_enabled:
		return
	if _pressed_circle(point, _reload_center(), _reload_radius() + 12.0):
		_reload_requested = true
		return
	var key := _action_key_at(point)
	if key == "left_fire":
		_left_fire_touch = index
		fire_held = true
		return
	if key == "right_fire":
		_right_fire_touch = index
		fire_held = true
		return
	if key == "ads":
		_aim_touch = index
		aim_held = not aim_held if _aim_toggle else true
		return
	if key == "jump":
		_jump_touch = index
		_jump_requested = true
		return
	if key == "crouch":
		_crouch_touch = index
		_crouch_requested = true
		return
	if key == "prone":
		_prone_touch = index
		_prone_requested = true
		return
	if key == "swap":
		_switch_touch = index
		_weapon_switch_requested = true
		return
	if not _safe_rect().has_point(point):
		return
	_touch_router.configure(_stick_mode, _control_center("move"), _stick_radius())
	var role := _touch_router.begin(index, point, _movement_region(), _stick_radius())
	movement = _touch_router.movement()
	if role == MobileTouchRouter.Role.MOVE:
		_stick_visual_target = 1.0

func _handle_drag(index: int, point: Vector2, relative: Vector2) -> void:
	_touch_router.drag(index, point, relative)
	movement = _touch_router.movement()

func _release_touch(index: int) -> void:
	_touch_router.end(index)
	movement = _touch_router.movement()
	if not _touch_router.has_movement_owner() and _touch_preview.is_empty():
		_stick_visual_target = 0.0
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

func _release_all_touch_ownership() -> void:
	_touch_router.reset()
	_left_fire_touch = -1
	_right_fire_touch = -1
	_aim_touch = -1
	_jump_touch = -1
	_crouch_touch = -1
	_prone_touch = -1
	_switch_touch = -1
	_editor_touch = -1
	movement = Vector2.ZERO
	fire_held = false
	aim_held = false
	_look_delta = Vector2.ZERO
	_jump_requested = false
	_crouch_requested = false
	_prone_requested = false
	_weapon_switch_requested = false
	_reload_requested = false
	_stick_visual_target = 0.0

func _draw() -> void:
	if _layout_editor:
		_draw_layout_editor()
		return
	_draw_gameplay_hud()
	if _settings_open:
		_draw_settings_panel(_friendly_color(), _enemy_color())

func _draw_gameplay_hud() -> void:
	var friendly := _friendly_color()
	var enemy := _enemy_color()
	var center := size * 0.5
	_draw_coach_cue(friendly, enemy)

	# The reticle stays clean for touch aiming, with a short directional bloom that recovers quickly.
	var bloom_radius := 14.0 + primary_fire_bloom * 3.0
	var bloom_gap := 10.0 + primary_fire_bloom * 4.0
	var bloom_span := 25.0 + primary_fire_bloom * 6.0
	draw_arc(center, bloom_radius, 0.12, 1.24, 12, Color(friendly, 0.9), 2.0)
	draw_arc(center, bloom_radius, 3.26, 4.38, 12, Color(friendly, 0.9), 2.0)
	draw_line(center + Vector2(-bloom_span, 0), center + Vector2(-bloom_gap, 0), Color(friendly, 0.86), 2.0)
	draw_line(center + Vector2(bloom_gap, 0), center + Vector2(bloom_span, 0), Color(friendly, 0.86), 2.0)
	if hit_confirm > 0.0:
		var confirm_color := Color("fff0b0", 0.95 * hit_confirm)
		var confirm_radius := 23.0 + (1.0 - hit_confirm) * 7.0
		for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.RIGHT.rotated(angle)
			var inner := center + direction * (confirm_radius - 7.0)
			var outer := center + direction * confirm_radius
			draw_line(inner, outer, confirm_color, 2.5)

	var stick_anchor := _control_center("move")
	var stick_radius := _stick_radius()
	var stick_is_active := _touch_router.has_movement_owner() or _touch_preview in ["floating-left", "floating-edge"]
	var stick_is_visible := stick_is_active or (_stick_mode == MobileTouchRouter.StickMode.FLOATING and _stick_visual_opacity > 0.01)
	var stick_center := _touch_router.stick_origin() if stick_is_visible else stick_anchor
	var knob := _touch_router.stick_knob() if stick_is_visible else stick_center
	var stick_alpha := _control_opacity("move")
	if _stick_mode == MobileTouchRouter.StickMode.FLOATING:
		stick_alpha *= _stick_visual_opacity if stick_is_active else 0.28
	if _touch_preview == "floating-left":
		stick_center = _preview_stick_origin(Vector2(220.0, 410.0), stick_radius)
		knob = stick_center + Vector2(30.0, -22.0)
	elif _touch_preview == "floating-edge":
		stick_center = _preview_stick_origin(Vector2(28.0, 430.0), stick_radius)
		knob = stick_center + Vector2(32.0, -12.0)
	draw_circle(stick_center, stick_radius, Color("08142a", 0.42 * stick_alpha))
	draw_arc(stick_center, stick_radius, 0.0, TAU, 32, Color(friendly, 0.38 * stick_alpha), 2.0)
	if _stick_mode == MobileTouchRouter.StickMode.FIXED or stick_is_active or _stick_visual_opacity > 0.01:
		draw_circle(knob, 24.0 * _control_scale("move"), Color(friendly, 0.34 * stick_alpha))
		draw_arc(knob, 24.0 * _control_scale("move"), 0.0, TAU, 24, Color(friendly, 0.9 * stick_alpha), 2.0)

	_draw_button("left_fire", friendly, _left_fire_touch >= 0)
	_draw_button("right_fire", friendly, _right_fire_touch >= 0)
	_draw_button("ads", enemy, aim_held)
	_draw_button("jump", enemy, _jump_touch >= 0)
	_draw_button("crouch", friendly, _stance == Duelist.Stance.CROUCH)
	_draw_button("prone", friendly, _stance == Duelist.Stance.PRONE)
	_draw_button("swap", Color("c292ff"), _switch_touch >= 0)
	if _weapon == Duelist.Weapon.PULSE:
		_draw_button_fixed(_reload_center(), _reload_radius(), Color("e6a25b"), reload_remaining > 0.0, "reload")
	_draw_weapon_indicator(friendly)
	_draw_button_fixed(_settings_center(), 24.0, enemy, _settings_open, "SET")
	if _touch_preview in ["two-thumb", "four-finger"]:
		_draw_button_preview("left_fire", friendly)
		_draw_button_preview("right_fire", friendly)
	if _touch_preview == "reloading":
		_draw_reload_sweep(_reload_center(), _reload_radius(), Color("fff0b0"))
	if _touch_preview in ["floating-left", "floating-edge"]:
		_draw_preview_floating_stick(friendly)

	var safe := _safe_rect()
	var health_width := 210.0
	draw_rect(Rect2(safe.position + Vector2(10, 10), Vector2(health_width, 8)), Color("03101f", 0.72))
	var health_color := friendly
	if health <= 30.0:
		var low_pulse := 0.65 + sin(Time.get_ticks_msec() * 0.012) * 0.35
		health_color = Color("ef8b78", low_pulse)
	draw_rect(Rect2(safe.position + Vector2(10, 10), Vector2(health_width * health / 100.0, 8)), health_color)
	_draw_objective_strip(safe, friendly, enemy)
	_draw_carrier_chevron(safe, friendly)
	if _squad_readability:
		_draw_team_life_strip(safe, friendly, enemy)
	if damage_direction_intensity > 0.0:
		var damage_color := _team_color(damage_enemy_team)
		var direction := damage_direction if damage_direction.length_squared() > 0.01 else Vector2.DOWN
		var edge_radius := minf(size.x, size.y) * 0.44
		var edge_angle := atan2(direction.y, direction.x)
		draw_arc(center, edge_radius, edge_angle - 0.18, edge_angle + 0.18, 14, Color(damage_color, damage_direction_intensity * 0.9), 7.0)
	if _match_result_visible:
		_draw_match_result()
	elif _match_phase == LinebreakMatch.Phase.OPENING:
		_draw_round_beat("BREAK THE LINE", "TAKE THE SEED THROUGH THEIR RIFT", friendly)
	elif _match_phase == LinebreakMatch.Phase.INTERMISSION:
		_draw_round_beat("LINE BREACHED", "THE SEED RETURNS TO CENTER", enemy)
	if not _connection_message.is_empty():
		var message_rect := Rect2(Vector2(size.x * 0.5 - 170.0, _safe_rect().position.y + 52.0), Vector2(340.0, 46.0))
		draw_rect(message_rect, Color("0b1730", 0.94))
		draw_line(message_rect.position, message_rect.position + Vector2(message_rect.size.x, 0), enemy, 2.0)
		var font := ThemeDB.fallback_font
		draw_string(font, message_rect.get_center() + Vector2(-font.get_string_size(_connection_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, 5), _connection_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f1f6ff"))

func _friendly_color() -> Color:
	return _team_color(_roster_local_team)

func _enemy_color() -> Color:
	return _team_color(Duelist.Team.VOID if _roster_local_team == int(Duelist.Team.SUN) else Duelist.Team.SUN)

func _team_color(team: int) -> Color:
	return Color("ffad5d") if team == int(Duelist.Team.SUN) else Color("71cfff")

func _draw_objective_strip(safe: Rect2, friendly: Color, enemy: Color) -> void:
	var center := Vector2(size.x * 0.5, safe.position.y + 18.0)
	for index in 3:
		_draw_seed_glyph(center + Vector2(-42.0 - index * 16.0, 0.0), friendly, index < _sun_score)
		_draw_seed_glyph(center + Vector2(42.0 + index * 16.0, 0.0), enemy, index < _void_score)
	if _score_pulse > 0.0 and _score_pulse_team >= 0:
		var score := _sun_score if _score_pulse_team == int(Duelist.Team.SUN) else _void_score
		if score > 0:
			var score_center := center + Vector2(-42.0 - (score - 1) * 16.0, 0.0) if _score_pulse_team == int(Duelist.Team.SUN) else center + Vector2(42.0 + (score - 1) * 16.0, 0.0)
			draw_arc(score_center, 8.0 + (1.0 - _score_pulse) * 9.0, 0.0, TAU, 24, Color("fff4c7", _score_pulse * 0.85), 2.0)
	var state := int(_objective_state.get("state", int(RiftSeed.State.HOME)))
	var carrier_team := int(_objective_state.get("carrier_team", -1))
	var objective_accent := _team_color(carrier_team) if carrier_team >= 0 else Color("fff0b0")
	if state == RiftSeed.State.DROPPED:
		objective_accent = Color("fff0b0")
	_draw_seed_glyph(center, objective_accent, state == RiftSeed.State.CARRIED)
	if objective_feedback_pulse > 0.0:
		var feedback_color := _team_color(objective_feedback_team) if objective_feedback_team >= 0 else Color("fff0b0")
		draw_arc(center, 10.0 + (1.0 - objective_feedback_pulse) * 18.0, 0.0, TAU, 24, Color(feedback_color, objective_feedback_pulse * 0.9), 2.5)

func _draw_carrier_chevron(safe: Rect2, color: Color) -> void:
	if not _carrier_chevron_active:
		return
	var direction := _carrier_chevron_direction
	var center := Vector2(safe.position.x + safe.size.x * 0.5, safe.position.y + safe.size.y * 0.42)
	if absf(direction.x) >= absf(direction.y):
		center.x = safe.end.x - 30.0 if direction.x >= 0.0 else safe.position.x + 30.0
	if absf(direction.x) < absf(direction.y):
		center.y = safe.position.y + 86.0 if direction.y < 0.0 else safe.end.y - 164.0
	var tip := center + direction * 15.0
	var wing := Vector2(-direction.y, direction.x) * 9.0
	var chevron := PackedVector2Array([tip, center - direction * 8.0 + wing, center - direction * 8.0 - wing])
	var pulse := 0.75 + sin(Time.get_ticks_msec() * 0.006) * 0.15
	draw_colored_polygon(chevron, Color(color, 0.16 * pulse))
	draw_polyline(PackedVector2Array([tip, center - direction * 8.0 + wing, center - direction * 8.0 - wing, tip]), Color(color, 0.92 * pulse), 2.4)

func _draw_team_life_strip(safe: Rect2, friendly: Color, enemy: Color) -> void:
	var center := Vector2(size.x * 0.5, safe.position.y + 45.0)
	var sun_index := 0
	var void_index := 0
	for record in _roster_state:
		var team := int(record.get("team", -1))
		var eliminated := bool(record.get("eliminated", false))
		var is_local_team := team == _roster_local_team
		var color := friendly if team == int(Duelist.Team.SUN) else enemy
		var slot := sun_index if team == int(Duelist.Team.SUN) else void_index
		var direction := -1.0 if team == int(Duelist.Team.SUN) else 1.0
		var point := center + Vector2(direction * (34.0 + slot * 15.0), 0.0)
		_draw_team_marker(point, color, not eliminated, is_local_team)
		if team == int(Duelist.Team.SUN):
			sun_index += 1
		else:
			void_index += 1

func _draw_team_marker(center: Vector2, color: Color, living: bool, friendly_marker: bool) -> void:
	var half_width := 5.0 if friendly_marker else 4.0
	var height := 5.0 if living else 4.0
	var chevron := PackedVector2Array([
		center + Vector2(-half_width, -height),
		center + Vector2(half_width, 0.0),
		center + Vector2(-half_width, height),
	])
	if living:
		draw_colored_polygon(chevron, Color(color, 0.72))
	else:
		draw_polyline(chevron, Color(color, 0.72), 1.4)
		draw_line(center + Vector2(-half_width * 0.5, 0.0), center + Vector2(half_width * 0.5, 0.0), Color("f1f6ff", 0.76), 1.0)

func _draw_seed_glyph(center: Vector2, color: Color, filled: bool) -> void:
	var diamond := PackedVector2Array([center + Vector2(0, -6), center + Vector2(6, 0), center + Vector2(0, 6), center + Vector2(-6, 0)])
	if filled:
		draw_colored_polygon(diamond, Color(color, 0.82))
	else:
		draw_polyline(diamond, Color(color, 0.55), 1.5)
	draw_line(center + Vector2(-2, 0), center + Vector2(2, 0), Color("fff4c7", 0.85 if filled else 0.34), 1.2)

func _draw_button(key: String, color: Color, active: bool) -> void:
	var spec: Dictionary = _control_specs()[key]
	_draw_button_fixed(_control_center(key), _control_radius(key), color, active, key, _control_opacity(key))

func _draw_button_fixed(center: Vector2, radius: float, color: Color, active: bool, label: String, opacity: float = 1.0) -> void:
	draw_circle(center, radius, Color("071126", 0.58 * opacity))
	draw_arc(center, radius, 0.0, TAU, 32, Color(color, (0.95 if active else 0.6) * opacity), 2.5 if active else 1.8)
	if _control_specs().has(label) or label == "reload":
		_draw_control_glyph(center, radius, color, label, active, opacity)
		return
	var font := ThemeDB.fallback_font
	var font_size := 13 if label.length() > 1 else 20
	var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, center + Vector2(-text_width * 0.5, font_size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, 0.98 * opacity))

func _draw_control_glyph(center: Vector2, radius: float, color: Color, key: String, active: bool, opacity: float) -> void:
	var glyph_color := Color(color, (0.98 if active else 0.86) * opacity)
	var weight := 3.0 if active else 2.2
	match key:
		"left_fire", "right_fire":
			draw_circle(center, radius * 0.18, glyph_color)
			draw_arc(center, radius * 0.48, -0.9, 0.9, 12, glyph_color, weight)
			draw_arc(center, radius * 0.48, PI - 0.9, PI + 0.9, 12, glyph_color, weight)
		"ads":
			draw_arc(center + Vector2(0, 4), radius * 0.34, PI, TAU, 12, glyph_color, weight)
			draw_line(center + Vector2(-radius * 0.38, 4), center + Vector2(radius * 0.38, 4), glyph_color, weight)
		"jump":
			draw_polyline(PackedVector2Array([center + Vector2(-radius * 0.34, 5), center, center + Vector2(radius * 0.34, 5)]), glyph_color, weight)
			draw_line(center, center + Vector2(0, -radius * 0.38), glyph_color, weight)
		"crouch":
			draw_circle(center + Vector2(-radius * 0.16, -radius * 0.18), radius * 0.13, glyph_color)
			draw_line(center + Vector2(-radius * 0.28, 0), center + Vector2(radius * 0.22, 0), glyph_color, weight)
			draw_line(center + Vector2(-radius * 0.2, 0), center + Vector2(-radius * 0.34, radius * 0.3), glyph_color, weight)
			draw_line(center + Vector2(radius * 0.18, 0), center + Vector2(radius * 0.34, radius * 0.3), glyph_color, weight)
		"prone":
			draw_circle(center + Vector2(-radius * 0.28, -radius * 0.1), radius * 0.12, glyph_color)
			draw_line(center + Vector2(-radius * 0.18, 0), center + Vector2(radius * 0.34, 0), glyph_color, weight)
			draw_line(center + Vector2(radius * 0.2, 0), center + Vector2(radius * 0.38, radius * 0.22), glyph_color, weight)
		"swap":
			draw_line(center + Vector2(-radius * 0.34, -5), center + Vector2(radius * 0.3, -5), glyph_color, weight)
			draw_line(center + Vector2(radius * 0.3, -5), center + Vector2(radius * 0.14, -radius * 0.18), glyph_color, weight)
			draw_line(center + Vector2(radius * 0.34, 5), center + Vector2(-radius * 0.3, 5), glyph_color, weight)
			draw_line(center + Vector2(-radius * 0.3, 5), center + Vector2(-radius * 0.14, radius * 0.18), glyph_color, weight)
		"reload":
			_draw_reload_sweep(center, radius * 0.58, glyph_color)

func _draw_weapon_indicator(color: Color) -> void:
	var safe := _safe_rect()
	var center := Vector2(safe.end.x - 480.0, safe.end.y - 84.0)
	draw_rect(Rect2(center - Vector2(34, 20), Vector2(68, 40)), Color("071126", 0.58), true)
	draw_arc(center, 30.0, 0.0, TAU, 24, Color(color, 0.92), 2.0)
	if _weapon == Duelist.Weapon.PULSE:
		draw_rect(Rect2(center - Vector2(15, 4), Vector2(30, 8)), color)
		draw_line(center + Vector2(14, -4), center + Vector2(23, -11), color, 3.0)
		draw_line(center + Vector2(14, 4), center + Vector2(23, 11), color, 3.0)
		draw_circle(center + Vector2(-8, 0), 3.0, Color("fff0b0"))
		var font := ThemeDB.fallback_font
		_draw_magazine_read(center + Vector2(0.0, -28.0), color)
		if reload_remaining > 0.0:
			draw_string(font, center + Vector2(-32.0, 43.0), "LOADING", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff0b0", 0.94))
			_draw_reload_sweep(center, 30.0, Color("fff0b0"))
	else:
		for offset in [-10.0, -5.0, 0.0, 5.0, 10.0]:
			draw_circle(center + Vector2(offset, 0), 3.8, Color("c292ff"))
		draw_line(center + Vector2(15, -10), center + Vector2(15, 10), Color("d8c4ff"), 3.0)

func _draw_magazine_read(center: Vector2, color: Color) -> void:
	var magazine_ratio := clampf(float(magazine_rounds) / float(Duelist.M4_MAGAZINE_SIZE), 0.0, 1.0)
	var filled_segments := ceili(magazine_ratio * 5.0) if magazine_rounds > 0 else 0
	for index in 5:
		var segment := Rect2(center + Vector2(-28.0 + index * 12.0, -4.0), Vector2(9.0, 8.0))
		draw_rect(segment, Color(color, 0.88 if index < filled_segments else 0.14), index < filled_segments)
		draw_rect(segment, Color(color, 0.56), false, 1.0)
	var reserve_ratio := clampf(float(reserve_ammo) / float(Duelist.M4_RESERVE_AMMO), 0.0, 1.0)
	var reserve_blocks := ceili(reserve_ratio * 3.0) if reserve_ammo > 0 else 0
	for index in 3:
		var block := Rect2(center + Vector2(-17.0 + index * 12.0, 10.0), Vector2(8.0, 4.0))
		draw_rect(block, Color("fff0b0", 0.7 if index < reserve_blocks else 0.12), index < reserve_blocks)
		draw_rect(block, Color("fff0b0", 0.42), false, 1.0)

func _draw_reload_sweep(center: Vector2, radius: float, color: Color) -> void:
	var phase := fmod(Time.get_ticks_msec() / 1000.0, 1.0)
	draw_arc(center, radius + 5.0, -PI * 0.5, -PI * 0.5 + TAU * phase, 24, Color(color, 0.92), 3.0)
	draw_line(center + Vector2(-radius * 0.42, radius * 0.42), center + Vector2(radius * 0.42, radius * 0.42), Color(color, 0.82), 2.0)

func _draw_button_preview(key: String, color: Color) -> void:
	var center := _control_center(key)
	draw_arc(center, _control_radius(key) + 8.0, 0.0, TAU, 32, Color(color, 0.45), 2.0)

func _draw_preview_floating_stick(color: Color) -> void:
	var radius := _stick_radius()
	var point := Vector2(220.0, 410.0) if _touch_preview == "floating-left" else Vector2(28.0, 430.0)
	var origin := _preview_stick_origin(point, radius)
	var knob := origin + (Vector2(30.0, -22.0) if _touch_preview == "floating-left" else Vector2(32.0, -12.0))
	draw_circle(origin, radius, Color("08142a", 0.42))
	draw_arc(origin, radius, 0.0, TAU, 32, Color(color, 0.55), 2.0)
	draw_circle(knob, 24.0 * _control_scale("move"), Color(color, 0.38))
	draw_arc(knob, 24.0 * _control_scale("move"), 0.0, TAU, 24, Color(color, 0.95), 2.0)

func _draw_coach_cue(friendly: Color, enemy: Color) -> void:
	if _coach_display_cue.is_empty() or _coach_visual_opacity <= 0.01:
		return
	var safe := _safe_rect()
	var cue_alpha := _coach_visual_opacity
	var region := str(_coach_display_cue.get("region", ""))
	var accent := enemy if region == "right" else friendly
	if region == "left":
		draw_arc(_control_center("move"), _control_radius("move") + 12.0, 0.0, TAU, 32, Color(accent, 0.5 * cue_alpha), 2.5)
	elif region == "right":
		draw_arc(Vector2(safe.end.x - 76.0, safe.position.y + 118.0), 36.0, -PI * 0.8, PI * 0.8, 20, Color(accent, 0.5 * cue_alpha), 2.5)
	elif region == "fire":
		var pulse := 0.38 + 0.32 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
		for key in ["left_fire", "right_fire"]:
			draw_arc(_control_center(key), _control_radius(key) + 10.0, 0.0, TAU, 32, Color(accent, pulse * cue_alpha), 2.0)
	var rect := Rect2(Vector2(size.x * 0.5 - 190.0, safe.position.y + 62.0), Vector2(380.0, 30.0))
	if region == "seed":
		rect = Rect2(Vector2(size.x * 0.5 - 260.0, safe.end.y - 148.0), Vector2(520.0, 30.0))
	draw_rect(rect, Color("071126", 0.72 * cue_alpha), true)
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color(accent, 0.75 * cue_alpha), 1.5)
	var font := ThemeDB.fallback_font
	var text := str(_coach_display_cue.get("text", ""))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, rect.get_center() + Vector2(-width * 0.5, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f1f6ff", 0.95 * cue_alpha))

func _draw_match_result() -> void:
	var accent := _friendly_color() if _match_result_victory else _enemy_color()
	var card := _match_result_card()
	draw_rect(Rect2(Vector2.ZERO, size), Color("020612", 0.78))
	draw_rect(card, Color("0b1730", 0.99))
	draw_line(card.position, card.position + Vector2(card.size.x, 0), accent, 3.0)
	var emblem := card.position + Vector2(54, 62)
	if _match_result_victory:
		var diamond := PackedVector2Array([emblem + Vector2(0, -22), emblem + Vector2(22, 0), emblem + Vector2(0, 22), emblem + Vector2(-22, 0)])
		draw_colored_polygon(diamond, Color(accent, 0.26))
		draw_polyline(diamond, Color(accent, 0.96), 2.5)
	else:
		draw_circle(emblem, 22.0, Color(accent, 0.2))
		draw_arc(emblem, 22.0, 0.0, TAU, 24, accent, 2.5)
		draw_line(emblem + Vector2(-10, -10), emblem + Vector2(10, 10), accent, 2.5)
		draw_line(emblem + Vector2(10, -10), emblem + Vector2(-10, 10), accent, 2.5)
	var font := ThemeDB.fallback_font
	var title := "VICTORY" if _match_result_victory else "DEFEAT"
	draw_string(font, card.position + Vector2(98, 67), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("f1f6ff"))
	draw_string(font, card.position + Vector2(100, 94), "THE RIFT HOLDS" if _match_result_victory else "THE RIFT PUSHES BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(accent, 0.92))
	draw_string(font, card.position + Vector2(32, 128), "RESET THE DUEL AND TRY A NEW LINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b6c9e8"))
	draw_rect(_rematch_rect(), Color(accent, 0.16), true)
	draw_rect(_rematch_rect(), Color(accent, 0.92), false, 1.8)
	var label := "REMATCH"
	var label_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, _rematch_rect().get_center() + Vector2(-label_width * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, accent)

func _draw_round_beat(title: String, subtitle: String, accent: Color) -> void:
	var center := size * 0.5 + Vector2(0, 72)
	var width := 290.0 if title == "READY" else 380.0
	var rect := Rect2(center - Vector2(width * 0.5, 28), Vector2(width, 56))
	draw_rect(rect, Color("071126", 0.72))
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), accent, 2.0)
	var font := ThemeDB.fallback_font
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, center + Vector2(-title_width * 0.5, 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f1f6ff"))
	var subtitle_width := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(font, center + Vector2(-subtitle_width * 0.5, 20), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(accent, 0.9))

func _match_result_card() -> Rect2:
	return Rect2(size * 0.5 - Vector2(260, 130), Vector2(520, 260))

func _rematch_rect() -> Rect2:
	var card := _match_result_card()
	return Rect2(card.position + Vector2(140, 174), Vector2(240, 54))

func _pressed_circle(point: Vector2, center: Vector2, radius: float) -> bool:
	return point.distance_squared_to(center) <= radius * radius

func _handle_settings_touch(point: Vector2, pressed: bool) -> void:
	if not pressed:
		return
	var panel := _settings_panel()
	if not panel.has_point(point):
		_settings_open = false
		_release_all_touch_ownership()
		return
	var camera_track := Rect2(panel.position + Vector2(154, 76), Vector2(panel.size.x - 190, 24))
	var ads_track := Rect2(panel.position + Vector2(154, 122), Vector2(panel.size.x - 190, 24))
	if camera_track.grow(12.0).has_point(point):
		camera_sensitivity = clampf((point.x - camera_track.position.x) / camera_track.size.x * 1.4 + 0.3, 0.3, 1.7)
		_save_control_settings()
		return
	if ads_track.grow(12.0).has_point(point):
		ads_sensitivity = clampf((point.x - ads_track.position.x) / ads_track.size.x * 1.4 + 0.3, 0.3, 1.7)
		_save_control_settings()
		return
	if Rect2(panel.position + Vector2(24, 168), Vector2(142, 44)).has_point(point):
		_aim_toggle = not _aim_toggle
		_save_control_settings()
		return
	if Rect2(panel.position + Vector2(184, 168), Vector2(142, 44)).has_point(point):
		gyro_enabled = not gyro_enabled
		_save_control_settings()
		return
	if _effects_rect(panel).has_point(point):
		effects_enabled = not effects_enabled
		_save_control_settings()
		feedback_preferences_changed.emit(effects_enabled, haptics_enabled)
		return
	if _haptics_rect(panel).has_point(point):
		haptics_enabled = not haptics_enabled
		_save_control_settings()
		feedback_preferences_changed.emit(effects_enabled, haptics_enabled)
		return
	if _stick_mode_rect(panel).has_point(point):
		_stick_mode = MobileTouchRouter.StickMode.FIXED if _stick_mode == MobileTouchRouter.StickMode.FLOATING else MobileTouchRouter.StickMode.FLOATING
		_touch_router.configure(_stick_mode, _control_center("move"), _stick_radius())
		_save_control_settings()
		return
	if _hud_layout_rect(panel).has_point(point):
		open_hud_layout()
		return
	if _reset_training_rect(panel).has_point(point):
		_reset_training_requested = true
		_settings_open = false
		_release_all_touch_ownership()
		return
	if _rift_link_rect(panel).has_point(point):
		_settings_open = false
		_release_all_touch_ownership()
		rift_link_requested.emit()

func _draw_settings_panel(friendly: Color, enemy: Color) -> void:
	var panel := _settings_panel()
	draw_rect(Rect2(Vector2.ZERO, size), Color("020612", 0.68))
	draw_rect(panel, Color("0b1730", 0.98))
	draw_line(panel.position, panel.position + Vector2(panel.size.x, 0), friendly, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, panel.position + Vector2(24, 34), "COMBAT SETTINGS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f1f6ff"))
	draw_string(font, panel.position + Vector2(24, 91), "CAMERA", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, enemy)
	draw_string(font, panel.position + Vector2(24, 137), "ADS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, enemy)
	_draw_setting_slider(panel.position + Vector2(154, 88), panel.size.x - 190, camera_sensitivity, friendly)
	_draw_setting_slider(panel.position + Vector2(154, 134), panel.size.x - 190, ads_sensitivity, friendly)
	_draw_setting_chip(Rect2(panel.position + Vector2(24, 168), Vector2(142, 44)), "AIM %s" % ("TAP" if _aim_toggle else "HOLD"), friendly, _aim_toggle)
	_draw_setting_chip(Rect2(panel.position + Vector2(184, 168), Vector2(142, 44)), "GYRO %s" % ("ON" if gyro_enabled else "OFF"), Color("c292ff"), gyro_enabled)
	_draw_setting_chip(Rect2(panel.position + Vector2(344, 168), Vector2(142, 44)), "QUICK SWAP", Color("c292ff"), true)
	_draw_setting_chip(_effects_rect(panel), "EFFECTS %s" % ("ON" if effects_enabled else "OFF"), friendly, effects_enabled)
	_draw_setting_chip(_haptics_rect(panel), "HAPTICS %s" % ("ON" if haptics_enabled else "OFF"), Color("c292ff"), haptics_enabled)
	_draw_setting_chip(_stick_mode_rect(panel), "STICK %s" % ("FLOAT" if _stick_mode == MobileTouchRouter.StickMode.FLOATING else "FIXED"), friendly, _stick_mode == MobileTouchRouter.StickMode.FLOATING)
	_draw_setting_chip(_hud_layout_rect(panel), "HUD LAYOUT", enemy, true)
	_draw_setting_chip(_reset_training_rect(panel), "RESET TRAINING", Color("e57c70"), false)
	_draw_setting_chip(_rift_link_rect(panel), "RIFT LINK", Color("71cfff"), false)
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

func _draw_layout_editor() -> void:
	var friendly := _friendly_color()
	var enemy := _enemy_color()
	draw_rect(Rect2(Vector2.ZERO, size), Color("020612", 0.62))
	var safe := _safe_rect()
	for x in range(int(safe.position.x), int(safe.end.x) + 1, 32):
		draw_line(Vector2(x, safe.position.y), Vector2(x, safe.end.y), Color("8ea8cf", 0.11), 1.0)
	for y in range(int(safe.position.y), int(safe.end.y) + 1, 32):
		draw_line(Vector2(safe.position.x, y), Vector2(safe.end.x, y), Color("8ea8cf", 0.11), 1.0)
	draw_rect(safe, Color(enemy, 0.44), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, safe.position + Vector2(12, 26), "HUD LAYOUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f1f6ff"))
	draw_string(font, safe.position + Vector2(12, 48), "Select a control, then drag to place", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b6c9e8"))
	for key in MOVABLE_KEYS:
		_draw_editor_control(key, friendly if key in ["move", "left_fire", "right_fire", "crouch", "prone"] else enemy)
	var panel := _editor_panel()
	draw_rect(panel, Color("0b1730", 0.98))
	draw_line(panel.position, panel.position + Vector2(panel.size.x, 0), friendly, 2.0)
	var selected_label := "SELECT A CONTROL" if _selected_layout_key.is_empty() else str(_control_specs()[_selected_layout_key].label)
	draw_string(font, panel.position + Vector2(20, 25), selected_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, enemy)
	draw_string(font, panel.position + Vector2(170, 25), "GRID LOCK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("92a7c7"))
	_draw_setting_chip(_editor_button_rect("size_down"), "SIZE -", friendly, false)
	_draw_setting_chip(_editor_button_rect("size_up"), "SIZE +", friendly, false)
	_draw_setting_chip(_editor_button_rect("opacity_down"), "FADE -", Color("c292ff"), false)
	_draw_setting_chip(_editor_button_rect("opacity_up"), "FADE +", Color("c292ff"), false)
	_draw_setting_chip(_editor_button_rect("two_thumb"), "TWO THUMB", enemy, false)
	_draw_setting_chip(_editor_button_rect("four_finger"), "FOUR FINGER", enemy, false)
	_draw_setting_chip(_editor_button_rect("reset"), "RESET", Color("e57c70"), false)
	_draw_setting_chip(_editor_button_rect("done"), "DONE", friendly, true)

func _draw_editor_control(key: String, color: Color) -> void:
	var center := _control_center(key)
	var radius := _control_radius(key)
	var opacity := _control_opacity(key)
	var spec: Dictionary = _control_specs()[key]
	if key == "move":
		draw_circle(center, radius, Color("08142a", 0.5 * opacity))
		draw_arc(center, radius, 0.0, TAU, 32, Color(color, 0.82 * opacity), 2.0)
	else:
		draw_circle(center, radius, Color("071126", 0.62 * opacity))
		draw_arc(center, radius, 0.0, TAU, 32, Color(color, 0.9 * opacity), 2.2)
	var font := ThemeDB.fallback_font
	var label := "MOVE" if key == "move" else str(spec.label)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, center + Vector2(-width * 0.5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(color, opacity))
	if key == _selected_layout_key:
		draw_arc(center, radius + 8.0, 0.0, TAU, 40, Color("f1f6ff", 0.95), 3.0)
		draw_circle(center, 4.0, Color("f1f6ff"))

func _handle_editor_touch(index: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		if index == _editor_touch:
			if _editor_dragging:
				_save_control_settings()
			_editor_touch = -1
			_editor_dragging = false
		return
	for button in ["size_down", "size_up", "opacity_down", "opacity_up", "two_thumb", "four_finger", "reset", "done"]:
		if _editor_button_rect(button).has_point(point):
			_apply_editor_action(button)
			return
	var key := _layout_key_at(point)
	if not key.is_empty():
		_selected_layout_key = key
		_editor_touch = index
		_editor_drag_start = point
		_editor_start_center = _control_center(key)
		_editor_dragging = false
		queue_redraw()

func _handle_editor_drag(index: int, point: Vector2) -> void:
	if index != _editor_touch or _selected_layout_key.is_empty():
		return
	if not _editor_dragging and point.distance_to(_editor_drag_start) < DRAG_THRESHOLD:
		return
	_editor_dragging = true
	_set_layout_center(_selected_layout_key, _editor_start_center + point - _editor_drag_start)
	_layout_dirty = true
	queue_redraw()

func _apply_editor_action(action: String) -> void:
	if action == "done":
		if _layout_dirty:
			_save_control_settings()
		_release_all_touch_ownership()
		_layout_editor = false
		_settings_open = false
		return
	if action == "reset":
		_layout = _default_layout()
		_selected_layout_key = ""
		_layout_dirty = true
		_save_control_settings()
		_release_all_touch_ownership()
		queue_redraw()
		return
	if action == "two_thumb":
		_layout = _two_thumb_layout()
	elif action == "four_finger":
		_layout = _four_finger_layout()
	else:
		if _selected_layout_key.is_empty():
			return
		var data: Dictionary = _layout[_selected_layout_key]
		if action == "size_down":
			data.scale = clampf(float(data.scale) - 0.1, 0.7, 1.35)
		elif action == "size_up":
			data.scale = clampf(float(data.scale) + 0.1, 0.7, 1.35)
		elif action == "opacity_down":
			data.opacity = clampf(float(data.opacity) - 0.1, 0.35, 1.0)
		elif action == "opacity_up":
			data.opacity = clampf(float(data.opacity) + 0.1, 0.35, 1.0)
	_enforce_layout_constraints()
	_layout_dirty = true
	_save_control_settings()
	queue_redraw()

func _editor_panel() -> Rect2:
	return Rect2(Vector2(size.x * 0.5 - 380.0, _safe_rect().position.y + 74.0), Vector2(760.0, 132.0))

func _editor_button_rect(button: String) -> Rect2:
	var panel := _editor_panel()
	var y := panel.position.y + 88.0
	if button in ["size_down", "size_up", "opacity_down", "opacity_up"]:
		y = panel.position.y + 42.0
	var x := panel.position.x
	var width := 0.0
	match button:
		"size_down", "size_up":
			width = 74.0
			x += 20.0 if button == "size_down" else 100.0
		"opacity_down", "opacity_up":
			width = 84.0
			x += 184.0 if button == "opacity_down" else 276.0
		"two_thumb":
			width = 112.0
			x += 20.0
		"four_finger":
			width = 122.0
			x += 140.0
		"reset":
			width = 82.0
			x += 480.0
		"done":
			width = 82.0
			x += 572.0
	return Rect2(x, y, width, 44.0)

func _settings_panel() -> Rect2:
	return Rect2(size * 0.5 - Vector2(260, 220), Vector2(520, 440))

func _rift_link_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + Vector2(244, 330), Vector2(180, 44))

func _stick_mode_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + Vector2(24, 276), Vector2(142, 44))

func _hud_layout_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + Vector2(184, 276), Vector2(210, 44))

func _reset_training_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + Vector2(24, 330), Vector2(210, 44))

func _effects_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + Vector2(24, 222), Vector2(142, 44))

func _haptics_rect(panel: Rect2) -> Rect2:
	return Rect2(panel.position + Vector2(184, 222), Vector2(142, 44))

func _safe_rect() -> Rect2:
	var fallback := Rect2(24.0, 24.0, maxf(1.0, size.x - 48.0), maxf(1.0, size.y - 48.0))
	var display_safe := DisplayServer.get_display_safe_area()
	if display_safe.size.x <= 0 or display_safe.size.y <= 0:
		return fallback
	var candidate := Rect2(Vector2(display_safe.position), Vector2(display_safe.size))
	if candidate.position.x >= -1.0 and candidate.position.y >= -1.0 and candidate.end.x <= size.x + 1.0 and candidate.end.y <= size.y + 1.0:
		return candidate
	return fallback

func _settings_center() -> Vector2:
	var safe := _safe_rect()
	return Vector2(safe.end.x - 42.0, safe.position.y + 42.0)

func _reload_center() -> Vector2:
	var safe := _safe_rect()
	return Vector2(safe.end.x - 390.0, safe.end.y - 84.0)

func _reload_radius() -> float:
	return 34.0

func _control_specs() -> Dictionary:
	return {
		"move": {"radius": 58.0, "label": "MOVE"},
		"left_fire": {"radius": 50.0, "label": "FIRE"},
		"right_fire": {"radius": 68.0, "label": "FIRE"},
		"ads": {"radius": 42.0, "label": "ADS"},
		"jump": {"radius": 40.0, "label": "JUMP"},
		"crouch": {"radius": 37.0, "label": "C"},
		"prone": {"radius": 37.0, "label": "P"},
		"swap": {"radius": 37.0, "label": "SWAP"},
	}

func _default_layout() -> Dictionary:
	return _two_thumb_layout()

func _two_thumb_layout() -> Dictionary:
	return {
		"move": _layout_entry(Vector2(0.10, 0.80), 1.0, 0.82),
		"left_fire": _layout_entry(Vector2(0.10, 0.22), 1.0, 0.82),
		"right_fire": _layout_entry(Vector2(0.90, 0.80), 1.0, 0.82),
		"ads": _layout_entry(Vector2(0.79, 0.49), 1.0, 0.78),
		"jump": _layout_entry(Vector2(0.90, 0.59), 1.0, 0.78),
		"crouch": _layout_entry(Vector2(0.76, 0.80), 1.0, 0.78),
		"prone": _layout_entry(Vector2(0.64, 0.80), 1.0, 0.78),
		"swap": _layout_entry(Vector2(0.70, 0.57), 1.0, 0.78),
	}

func _four_finger_layout() -> Dictionary:
	return {
		"move": _layout_entry(Vector2(0.10, 0.79), 1.0, 0.82),
		"left_fire": _layout_entry(Vector2(0.21, 0.60), 0.95, 0.9),
		"right_fire": _layout_entry(Vector2(0.90, 0.79), 1.0, 0.9),
		"ads": _layout_entry(Vector2(0.78, 0.47), 1.0, 0.78),
		"jump": _layout_entry(Vector2(0.90, 0.59), 1.0, 0.82),
		"crouch": _layout_entry(Vector2(0.70, 0.79), 1.0, 0.78),
		"prone": _layout_entry(Vector2(0.58, 0.79), 1.0, 0.78),
		"swap": _layout_entry(Vector2(0.64, 0.56), 1.0, 0.78),
	}

func _layout_entry(center: Vector2, scale: float, opacity: float) -> Dictionary:
	return {"center": center, "scale": scale, "opacity": opacity}

func _control_scale(key: String) -> float:
	return float(_layout[key].scale)

func _control_opacity(key: String) -> float:
	return float(_layout[key].opacity)

func _control_radius(key: String) -> float:
	return float(_control_specs()[key].radius) * _control_scale(key)

func _stick_radius() -> float:
	return maxf(_control_radius("move"), 44.0)

func _control_center(key: String) -> Vector2:
	var safe := _safe_rect()
	return safe.position + Vector2(_layout[key].center) * safe.size

func _movement_region() -> Rect2:
	var safe := _safe_rect()
	return Rect2(safe.position, Vector2(safe.size.x * 0.5, safe.size.y))

func _action_key_at(point: Vector2) -> String:
	var closest := ""
	var closest_distance := INF
	for key in MOVABLE_KEYS:
		if key == "move":
			continue
		var hit_radius := maxf(_control_radius(key), 22.0) + 8.0
		var distance := point.distance_to(_control_center(key))
		if distance <= hit_radius and distance < closest_distance:
			closest = key
			closest_distance = distance
	return closest

func _layout_key_at(point: Vector2) -> String:
	var closest := ""
	var closest_distance := INF
	for key in MOVABLE_KEYS:
		var hit_radius := maxf(_control_radius(key), 22.0) + 8.0
		var distance := point.distance_to(_control_center(key))
		if distance <= hit_radius and distance < closest_distance:
			closest = key
			closest_distance = distance
	return closest

func _set_layout_center(key: String, point: Vector2) -> void:
	var safe := _safe_rect()
	var radius := _control_radius(key)
	var candidate := _clamp_center(point.snapped(Vector2(SNAP_POINTS, SNAP_POINTS)), radius, safe)
	for _pass in 2:
		for other_key in MOVABLE_KEYS:
			if other_key == key:
				continue
			var other_center := _control_center(other_key)
			var required := radius + _control_radius(other_key) + SNAP_POINTS
			var offset := candidate - other_center
			if offset.length() < required:
				candidate = _clamp_center(other_center + (Vector2.RIGHT if offset.length_squared() < 0.01 else offset.normalized()) * required, radius, safe)
	_layout[key].center = _normalized_center(candidate, safe)

func _enforce_layout_constraints() -> void:
	for key in MOVABLE_KEYS:
		_set_layout_center(key, _control_center(key))

func _clamp_center(point: Vector2, radius: float, safe: Rect2) -> Vector2:
	return Vector2(clampf(point.x, safe.position.x + radius, safe.end.x - radius), clampf(point.y, safe.position.y + radius, safe.end.y - radius))

func _normalized_center(point: Vector2, safe: Rect2) -> Vector2:
	return Vector2(clampf((point.x - safe.position.x) / safe.size.x, 0.0, 1.0), clampf((point.y - safe.position.y) / safe.size.y, 0.0, 1.0))

func _preview_stick_origin(point: Vector2, radius: float) -> Vector2:
	var region := _movement_region()
	return Vector2(
		clampf(point.x, region.position.x + radius, region.end.x - radius),
		clampf(point.y, region.position.y + radius, region.end.y - radius))

func _load_control_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	camera_sensitivity = _config_float(config, "sensitivity", "camera", camera_sensitivity, 0.3, 1.7)
	ads_sensitivity = _config_float(config, "sensitivity", "ads", ads_sensitivity, 0.3, 1.7)
	gyro_enabled = bool(config.get_value("controls", "gyro", gyro_enabled))
	_aim_toggle = bool(config.get_value("controls", "aim_toggle", _aim_toggle))
	var feedback_preferences := load_feedback_preferences(config, effects_enabled, haptics_enabled)
	effects_enabled = bool(feedback_preferences.effects_enabled)
	haptics_enabled = bool(feedback_preferences.haptics_enabled)
	var saved_stick_mode := str(config.get_value("controls", "stick_mode", "floating")).to_lower()
	_stick_mode = MobileTouchRouter.StickMode.FIXED if saved_stick_mode == "fixed" else MobileTouchRouter.StickMode.FLOATING
	var has_saved_layout := config.has_section(LAYOUT_SECTION)
	var saved_layout_version := int(config.get_value(LAYOUT_SECTION, "version", 1))
	var migrate_legacy_default := has_saved_layout and saved_layout_version < LAYOUT_VERSION and _saved_layout_matches(_legacy_default_layout(), config)
	for key in MOVABLE_KEYS:
		var fallback: Dictionary = _default_layout()[key] if migrate_legacy_default or not has_saved_layout else _legacy_default_layout()[key]
		var center_x := _config_float(config, LAYOUT_SECTION, "%s_center_x" % key, fallback.center.x, 0.0, 1.0)
		var center_y := _config_float(config, LAYOUT_SECTION, "%s_center_y" % key, fallback.center.y, 0.0, 1.0)
		var scale := _config_float(config, LAYOUT_SECTION, "%s_scale" % key, fallback.scale, 0.7, 1.35)
		var opacity := _config_float(config, LAYOUT_SECTION, "%s_opacity" % key, fallback.opacity, 0.35, 1.0)
		_layout[key] = _layout_entry(Vector2(center_x, center_y), scale, opacity)
	if migrate_legacy_default:
		_layout = _default_layout()
		_save_control_settings()
	elif has_saved_layout and saved_layout_version < LAYOUT_VERSION:
		_save_control_settings()

func _legacy_default_layout() -> Dictionary:
	return {
		"move": _layout_entry(Vector2(0.10, 0.79), 1.0, 0.82),
		"left_fire": _layout_entry(Vector2(0.10, 0.20), 1.0, 0.82),
		"right_fire": _layout_entry(Vector2(0.90, 0.79), 1.0, 0.82),
		"ads": _layout_entry(Vector2(0.78, 0.53), 1.0, 0.78),
		"jump": _layout_entry(Vector2(0.78, 0.79), 1.0, 0.78),
		"crouch": _layout_entry(Vector2(0.67, 0.79), 1.0, 0.78),
		"prone": _layout_entry(Vector2(0.56, 0.79), 1.0, 0.78),
		"swap": _layout_entry(Vector2(0.67, 0.53), 1.0, 0.78),
	}

func _saved_layout_matches(expected: Dictionary, config: ConfigFile) -> bool:
	for key in MOVABLE_KEYS:
		var fallback: Dictionary = expected[key]
		if absf(_config_float(config, LAYOUT_SECTION, "%s_center_x" % key, fallback.center.x, 0.0, 1.0) - float(fallback.center.x)) > 0.01:
			return false
		if absf(_config_float(config, LAYOUT_SECTION, "%s_center_y" % key, fallback.center.y, 0.0, 1.0) - float(fallback.center.y)) > 0.01:
			return false
		if absf(_config_float(config, LAYOUT_SECTION, "%s_scale" % key, fallback.scale, 0.7, 1.35) - float(fallback.scale)) > 0.01:
			return false
		if absf(_config_float(config, LAYOUT_SECTION, "%s_opacity" % key, fallback.opacity, 0.35, 1.0) - float(fallback.opacity)) > 0.01:
			return false
	return true

func _config_float(config: ConfigFile, section: String, key: String, fallback: float, minimum: float, maximum: float) -> float:
	var value: Variant = config.get_value(section, key, fallback)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return fallback
	var numeric := float(value)
	if not is_finite(numeric) or numeric < minimum or numeric > maximum:
		return fallback
	return numeric

func _save_control_settings() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value("sensitivity", "camera", camera_sensitivity)
	config.set_value("sensitivity", "ads", ads_sensitivity)
	config.set_value("controls", "gyro", gyro_enabled)
	config.set_value("controls", "aim_toggle", _aim_toggle)
	config.set_value("controls", "stick_mode", "fixed" if _stick_mode == MobileTouchRouter.StickMode.FIXED else "floating")
	save_feedback_preferences(config, effects_enabled, haptics_enabled)
	config.set_value(LAYOUT_SECTION, "version", LAYOUT_VERSION)
	for key in MOVABLE_KEYS:
		var data: Dictionary = _layout[key]
		config.set_value(LAYOUT_SECTION, "%s_center_x" % key, data.center.x)
		config.set_value(LAYOUT_SECTION, "%s_center_y" % key, data.center.y)
		config.set_value(LAYOUT_SECTION, "%s_scale" % key, data.scale)
		config.set_value(LAYOUT_SECTION, "%s_opacity" % key, data.opacity)
	config.save(CONFIG_PATH)
	_layout_dirty = false
