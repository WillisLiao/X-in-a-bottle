class_name RiftlineArena
extends Node3D

const PULP_LIT := preload("res://shaders/pulp_lit.gdshader")
const SNAPSHOT_BUFFER := preload("res://scripts/riftline_snapshot_buffer.gd")
const SUN_COVER_SPAWN := Vector3(-15.0, 0.1, 6.0)
const VOID_COVER_SPAWN := Vector3(16.0, 0.1, -6.0)
## Temporary authority-smoke points for the development squad preview.
## Keep the original index-zero duel spawns unchanged until a real squad arena
## replaces this deliberately unbalanced proof layout.
const SUN_SQUAD_SPAWNS := [Vector3(-15.0, 0.1, 6.0), Vector3(-13.0, 0.1, -2.0), Vector3(-6.0, 0.1, 11.0), Vector3(-10.0, 0.1, -10.0), Vector3(-2.0, 0.1, 7.0)]
const VOID_SQUAD_SPAWNS := [Vector3(16.0, 0.1, -6.0), Vector3(13.0, 0.1, 2.0), Vector3(6.0, 0.1, -11.0), Vector3(10.0, 0.1, 10.0), Vector3(2.0, 0.1, -7.0)]
const SUN_GATE_POSITION := Vector3(-18.5, 0.05, 6.0)
const VOID_GATE_POSITION := Vector3(18.5, 0.05, -6.0)
const OPENING_HOLD_SECONDS := 2.5

var ballistics: RiftBallistics
var hud: DuelHud
var coach: RiftlineFirstMatchCoach
var director: LinebreakMatch
var network: RiftlineNetwork
var rift_link: RiftLinkPanel
var _mouse_captured := false
var _lan_active := false
var _lan_host := false
var _dedicated_server := false
var _presentation_enabled := true
var _lan_peer_ready := false
var _authority_match_started := false
var _lan_phase: LinebreakMatch.Phase = LinebreakMatch.Phase.OPENING
var _lan_tick := 0
var _local_input_sequence := 0
var _authoritative_duelists: Dictionary = {}
var _replica_duelists: Dictionary = {}
var _remote_snapshot_buffers: Dictionary = {}
var _continuous_inputs: Dictionary = {}
var _edge_queues: Dictionary = {}
var _last_sequences: Dictionary = {}
var _actor_for_peer: Dictionary = {}
var _ready_peers: Dictionary = {}
var _pending_inputs: Array[Dictionary] = []
var _local_duelist: Duelist
var _local_actor_id := ""
var _pending_actor_snapshots: Dictionary = {}
var _snapshot_remaining := 0.0
var _join_discovery_started := false
var _local_team: Duelist.Team = Duelist.Team.SUN
var _capture_path := ""
var _capture_after := 2.0
var _capture_settings := false
var _capture_hud_layout := false
var _capture_character := false
var _capture_overview := false
var _capture_rift_link := false
var _offline_squad_size := 0
var _squad_preview := ""
var _capture_fixture_only := false
var _objective_preview := ""
var _weapon_preview := ""
var _ballistics_preview := ""
var _touch_preview := ""
var _presentation_effects: Node3D
var _seen_projectile_fires: Dictionary = {}
var _seen_projectile_impacts: Dictionary = {}
var _last_projectile_fire_id := -1
var _last_projectile_impact_id := -1
var _pending_local_primary_predictions := 0
var _projectile_presentation_pool: Node3D
var _tracer_pool: Array[MeshInstance3D] = []
var _impact_pool: Array[Node3D] = []
var _projectile_tracers: Dictionary = {}
var _tracer_cursor := 0
var _impact_cursor := 0

func _ready() -> void:
	_build_network()
	var command_line_lan := network.start_command_line_mode()
	_dedicated_server = network.is_dedicated_server()
	_presentation_enabled = not _dedicated_server
	if _dedicated_server:
		_build_arena()
		_enter_lan_runtime(true, false)
	else:
		_build_environment()
		_build_arena()
		_read_capture_arguments()
		_capture_fixture_only = not _squad_preview.is_empty()
		_build_match()
		_build_hud()
		_build_first_match_coach()
		_build_rift_link()
		_read_capture_arguments()
		if command_line_lan:
			_enter_lan_runtime(network.multiplayer.is_server(), false)
		else:
			if _squad_preview.is_empty():
				coach.begin_offline_match()
			else:
				coach.hide()
			if not _touch_preview.is_empty():
				hud.set_touch_preview(_touch_preview)
			if not _capture_fixture_only:
				director.begin()
		if not _lan_active:
			if not _objective_preview.is_empty():
				_apply_objective_preview()
			_apply_weapon_preview()
			_apply_ballistics_preview()
	if not _capture_path.is_empty():
		_capture_after_delay()

func _physics_process(delta: float) -> void:
	if _dedicated_server:
		_tick_dedicated_server(delta)
		return
	if _local_duelist == null:
		return
	_sync_objective_presentation()
	_sync_squad_hud()
	if _lan_active:
		_tick_lan_duel(delta)
		return
	if hud.take_rematch():
		director.take_rematch()
	var wants_reload := hud.take_reload() or Input.is_action_just_pressed("reload")
	var look_delta := hud.take_look_delta()
	_local_duelist.apply_look(look_delta)
	if hud.take_reset_training() and coach != null and not _lan_active:
		coach.reset_training()
	if hud.gyro_enabled:
		var gyroscope := Input.get_gyroscope()
		_local_duelist.apply_look(Vector2(gyroscope.y, -gyroscope.x) * 2.4)
	if not director.is_live() or not hud.can_drive_combat():
		# Non-live beats can still show the arena and accept camera look, but no combat intent survives into the next phase.
		hud.take_jump()
		hud.take_crouch()
		hud.take_prone()
		hud.take_weapon_switch()
		_local_duelist.set_combat_pose(false, delta)
		_local_duelist.drive(Vector2.ZERO, false, false, delta)
		hud.show_ammo(_local_duelist.magazine_rounds, _local_duelist.reserve_ammo, _local_duelist.reload_remaining)
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement := hud.movement if hud.movement.length_squared() > 0.001 else keyboard
	if coach != null and not _lan_active:
		coach.observe_movement(movement)
		coach.observe_look(look_delta)
		if hud.fire_held or Input.is_action_pressed("fire"):
			coach.observe_fire()
	if hud.take_crouch():
		_local_duelist.toggle_crouch()
	if hud.take_prone():
		_local_duelist.toggle_prone()
	if hud.take_weapon_switch():
		_local_duelist.switch_weapon()
	if wants_reload:
		_local_duelist.reload_weapon()
	_local_duelist.set_combat_pose(hud.aim_held, delta)
	_local_duelist.drive(movement, hud.fire_held or Input.is_action_pressed("fire"), hud.take_jump() or Input.is_action_just_pressed("jump"), delta)
	_tick_authority_ballistics(delta)
	hud.set_stance(_local_duelist.stance)
	hud.set_weapon(_local_duelist.weapon)
	hud.show_ammo(_local_duelist.magazine_rounds, _local_duelist.reserve_ammo, _local_duelist.reload_remaining)
	_sync_objective_presentation()
	_sync_squad_hud()

func _unhandled_input(event: InputEvent) -> void:
	if _local_duelist == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_captured = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _mouse_captured:
		_local_duelist.apply_look(event.relative)

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("102346")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8ea8cf")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-56, -28, 0)
	key.light_color = Color("ffe0b5")
	key.light_energy = 1.35
	key.shadow_enabled = true
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(10, 5, -4)
	rim.light_color = Color("ec6a4c")
	rim.light_energy = 2.2
	rim.omni_range = 17.0
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-10, 5, 4)
	fill.light_color = Color("72b9ea")
	fill.light_energy = 2.0
	fill.omni_range = 17.0
	add_child(fill)

func _build_arena() -> void:
	if _presentation_enabled:
		_presentation_effects = Node3D.new()
		_presentation_effects.name = "PresentationEffects"
		add_child(_presentation_effects)
	_add_solid_box(Vector3(0, -0.5, 0), Vector3(44, 1, 32), Color("3d547c"), 0.0)
	_add_solid_box(Vector3(0, 3, -16), Vector3(44, 6, 1), Color("28496e"), 0.0)
	_add_solid_box(Vector3(0, 3, 16), Vector3(44, 6, 1), Color("28496e"), 0.0)
	_add_solid_box(Vector3(-22, 3, 0), Vector3(1, 6, 32), Color("28496e"), 0.0)
	_add_solid_box(Vector3(22, 3, 0), Vector3(1, 6, 32), Color("28496e"), 0.0)

	# Four asymmetric blockers create sight-line decisions now and still read as lanes in a five-person match.
	_add_solid_box(Vector3(-4, 1.7, -5), Vector3(3.2, 3.4, 3.2), Color("bd7254"), 0.0)
	_add_solid_box(Vector3(5, 1.7, 4), Vector3(3.2, 3.4, 3.2), Color("d39a52"), 0.0)
	_add_solid_box(Vector3(-10, 1.1, 6), Vector3(2.0, 2.2, 6.2), Color("496f8e"), 0.0)
	_add_solid_box(Vector3(11, 1.1, -6), Vector3(2.0, 2.2, 6.2), Color("496f8e"), 0.0)
	_add_pulp_cylinder(Vector3(-4, 4.2, -5), 0.9, 1.7, Color("e5b46b"))
	_add_pulp_cylinder(Vector3(5, 4.2, 4), 0.9, 1.7, Color("e5b46b"))
	_add_emissive_rail(Vector3(0, 0.06, -10), Vector3(28, 0.08, 0.08), Color("a7dced"))
	_add_emissive_rail(Vector3(0, 0.06, 10), Vector3(28, 0.08, 0.08), Color("f4a55e"))
	_add_emissive_rail(Vector3(-15, 0.06, 0), Vector3(0.08, 0.08, 20), Color("a7dced"))
	_add_emissive_rail(Vector3(15, 0.06, 0), Vector3(0.08, 0.08, 20), Color("f4a55e"))
	_build_landmarks()
	_build_stormgates()

func _build_match() -> void:
	director = LinebreakMatch.new()
	add_child(director)
	director.configure(Vector3.ZERO, _gate_positions(), _presentation_enabled)
	_add_spawn_points()
	var offline_roster := RiftlineRoster.new()
	offline_roster.configure(maxi(1, _offline_squad_size), false, _offline_squad_size > 1)
	offline_roster.add_host()
	if _offline_squad_size > 1:
		for index in range(1, _offline_squad_size):
			offline_roster.add_bot("offline_actor_%d" % index, Duelist.Team.SUN)
		for index in range(_offline_squad_size):
			offline_roster.add_bot("offline_actor_%d" % (_offline_squad_size + index), Duelist.Team.VOID)
	else:
		offline_roster.add_bot("offline_actor_1", Duelist.Team.VOID)
	for record in offline_roster.records():
		_ensure_actor(record, str(record.actor_id) == "host", not _capture_fixture_only)

	for duelist in _all_authority_actors():
		if duelist is BotDuelist:
			(duelist as BotDuelist).hold_opening_position(OPENING_HOLD_SECONDS)

	_ensure_ballistics()
	director.score_changed.connect(_on_score_changed)
	director.phase_changed.connect(_on_phase_changed)
	director.match_finished.connect(_on_match_finished)
	director.objective_changed.connect(_on_objective_changed)
	director.objective_event.connect(_on_objective_event)

func _add_spawn_points() -> void:
	var points := SUN_SQUAD_SPAWNS if _offline_squad_size > 1 else [SUN_COVER_SPAWN]
	for point in points:
		director.add_spawn(Duelist.Team.SUN, point)
	points = VOID_SQUAD_SPAWNS if _offline_squad_size > 1 else [VOID_COVER_SPAWN]
	for point in points:
		director.add_spawn(Duelist.Team.VOID, point)

func _ensure_actor(record: Dictionary, local_controlled: bool, authoritative_collision: bool) -> Duelist:
	var actor_id := str(record.get("actor_id", ""))
	var team_value := int(record.get("team", -1))
	if actor_id.is_empty() or team_value < int(Duelist.Team.SUN) or team_value > int(Duelist.Team.VOID):
		return null
	var authority_registry := not _lan_active or _lan_host or _dedicated_server
	var registry: Dictionary = _authoritative_duelists if authority_registry else _replica_duelists
	var existing: Variant = registry.get(actor_id, null)
	if existing is Duelist and is_instance_valid(existing):
		if existing.team == team_value as Duelist.Team:
			if local_controlled:
				_local_duelist = existing
				_local_actor_id = actor_id
			return existing
		_remove_actor(actor_id)
	var is_bot := not bool(record.get("human", true)) and not _lan_active
	var duelist: Duelist = BotDuelist.new() if is_bot else Duelist.new()
	duelist.name = "Actor_%s" % actor_id
	var should_render := _presentation_enabled and not _dedicated_server
	duelist.build(team_value as Duelist.Team, local_controlled and should_render, should_render, authoritative_collision)
	duelist.set_friendly_presenter(not local_controlled and team_value == int(_local_team))
	var spawn := _spawn_for_actor(team_value as Duelist.Team, registry)
	duelist.position = spawn
	duelist.rotation.y = -PI * 0.5 if team_value == int(Duelist.Team.SUN) else PI * 0.5
	duelist.set_actor_id(actor_id)
	add_child(duelist)
	registry[actor_id] = duelist
	if director != null and not _capture_fixture_only:
		director.register_duelist(duelist, actor_id)
		if not authority_registry:
			duelist.set_match_active(director.is_live())
	if authoritative_collision:
		duelist.fire_requested.connect(_on_authority_fire_requested)
		if _lan_active:
			duelist.defeated.connect(_on_lan_defeat)
	elif local_controlled:
		duelist.fire_requested.connect(_on_local_fire_requested)
	duelist.scatter_shot.connect(_on_scatter_shot)
	if local_controlled:
		duelist.damaged.connect(_on_player_damaged)
		_local_duelist = duelist
		_local_actor_id = actor_id
	if not authority_registry and not local_controlled:
		_remote_snapshot_buffers[actor_id] = SNAPSHOT_BUFFER.new()
	return duelist

func _remove_actor(actor_id: String) -> void:
	if actor_id.is_empty():
		return
	if director != null:
		director.unregister_duelist(actor_id)
	for registry in [_authoritative_duelists, _replica_duelists]:
		var candidate: Variant = registry.get(actor_id, null)
		if candidate is Duelist and is_instance_valid(candidate):
			candidate.queue_free()
		registry.erase(actor_id)
	_remote_snapshot_buffers.erase(actor_id)
	_pending_actor_snapshots.erase(actor_id)
	_continuous_inputs.erase(actor_id)
	_edge_queues.erase(actor_id)
	_last_sequences.erase(actor_id)
	if _local_actor_id == actor_id:
		_local_actor_id = ""
		_local_duelist = null

func _actor(actor_id: String) -> Duelist:
	var candidate: Variant = _authoritative_duelists.get(actor_id, null)
	if candidate is Duelist and is_instance_valid(candidate):
		return candidate
	candidate = _replica_duelists.get(actor_id, null)
	return candidate if candidate is Duelist and is_instance_valid(candidate) else null

func _all_authority_actors() -> Array[Duelist]:
	var result: Array[Duelist] = []
	for candidate in _authoritative_duelists.values():
		if candidate is Duelist and is_instance_valid(candidate):
			result.append(candidate)
	return result

func _all_replica_actors() -> Array[Duelist]:
	var result: Array[Duelist] = []
	for candidate in _replica_duelists.values():
		if candidate is Duelist and is_instance_valid(candidate):
			result.append(candidate)
	return result

func _spawn_for_actor(team: Duelist.Team, registry: Dictionary) -> Vector3:
	var points: Array = SUN_SQUAD_SPAWNS if _offline_squad_size > 1 else [SUN_COVER_SPAWN]
	if team == Duelist.Team.VOID:
		points = VOID_SQUAD_SPAWNS if _offline_squad_size > 1 else [VOID_COVER_SPAWN]
	var slot := 0
	for candidate in registry.values():
		if candidate is Duelist and candidate.team == team:
			slot += 1
	return points[posmod(slot, points.size())]

func _preview_actor() -> Duelist:
	for candidate in _all_authority_actors():
		if candidate != _local_duelist:
			return candidate
	return _local_duelist

func _actor_for_team(team: Duelist.Team) -> Duelist:
	for actor in _all_authority_actors():
		if actor.team == team:
			return actor
	for actor in _all_replica_actors():
		if actor.team == team:
			return actor
	return _local_duelist

func _sync_roster_records(records: Variant) -> void:
	var now_msec := Time.get_ticks_msec()
	for pending_actor_id in _pending_actor_snapshots.keys().duplicate():
		var pending_snapshot: Dictionary = _pending_actor_snapshots[pending_actor_id]
		if now_msec - int(pending_snapshot.get("arrival", now_msec)) > 1000:
			_pending_actor_snapshots.erase(pending_actor_id)
	var desired := {}
	var entries: Array = records if records is Array else []
	for raw_record in entries:
		if not raw_record is Dictionary:
			continue
		var record: Dictionary = raw_record
		var actor_id := str(record.get("actor_id", ""))
		if actor_id.is_empty():
			continue
		desired[actor_id] = true
		var is_local := actor_id == _local_actor_id
		_ensure_actor(record, is_local, _lan_host or _dedicated_server or is_local)
	for actor_id in _authoritative_duelists.keys().duplicate():
		if not desired.has(actor_id):
			_remove_actor(actor_id)
	for actor_id in _replica_duelists.keys().duplicate():
		if not desired.has(actor_id):
			_remove_actor(actor_id)
	_sync_squad_hud()
	for actor_id in _pending_actor_snapshots.keys().duplicate():
		if _actor(str(actor_id)) != null:
			var pending: Dictionary = _pending_actor_snapshots[actor_id]
			_update_remote_snapshot(str(actor_id), pending.get("state", {}), int(pending.get("tick", -1)))
			_pending_actor_snapshots.erase(actor_id)

func _authority_records() -> Array[Dictionary]:
	if network != null and network.roster != null:
		return network.roster.records()
	return []

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = DuelHud.new()
	layer.add_child(hud)
	hud.rift_link_requested.connect(_on_rift_link_requested)

func _build_first_match_coach() -> void:
	coach = RiftlineFirstMatchCoach.new()
	coach.cue_changed.connect(hud.set_coach_cue)

func _build_network() -> void:
	network = RiftlineNetwork.new()
	add_child(network)
	network.session_status.connect(_on_network_status)
	network.host_discovered.connect(_on_host_discovered)
	network.peer_joined.connect(_on_network_peer_joined)
	network.peer_left.connect(_on_network_peer_left)
	network.input_received.connect(_on_network_input)
	network.snapshot_received.connect(_on_network_snapshot)
	network.reliable_event_received.connect(_on_network_event)
	network.team_assigned.connect(_on_team_assigned)
	network.actor_assigned.connect(_on_actor_assigned)
	network.roster_received.connect(_on_roster_received)

func _build_rift_link() -> void:

	var layer := CanvasLayer.new()
	add_child(layer)
	rift_link = RiftLinkPanel.new()
	layer.add_child(rift_link)
	rift_link.set_squad_mode(_offline_squad_size > 1 or network.team_size > 1)
	rift_link.host_requested.connect(_on_host_requested)
	rift_link.join_requested.connect(_on_join_requested)
	rift_link.cancel_requested.connect(_on_rift_link_cancelled)
	rift_link.retry_requested.connect(_on_join_retry_requested)

func _on_player_damaged(_amount: float, remaining: float) -> void:
	if hud != null:
		hud.show_damage(remaining)

func _on_score_changed(sun: int, void_score: int) -> void:
	if hud != null:
		hud.set_score(sun, void_score)
	if _lan_host:
		network.publish_event({"type": "score", "sun": sun, "void": void_score})

func _on_objective_changed(state: Dictionary) -> void:
	if hud != null:
		hud.set_objective_state(state)

func _on_objective_event(event_type: String, state: Dictionary) -> void:
	if event_type == "objective_delivered":
		_clear_ballistics()
		if coach != null and not _lan_active:
			coach.observe_delivery()
	if hud != null:
		hud.show_objective_event(event_type, state)
	if event_type == "objective_delivered" and _presentation_enabled:
		var gate_position: Vector3 = state.get("gate_position", Vector3.ZERO)
		var scoring_team := int(state.get("scoring_team", int(Duelist.Team.SUN))) as Duelist.Team
		_spawn_delivery_pulse(gate_position, Color("ffb15c") if scoring_team == Duelist.Team.SUN else Color("75dbff"))
	if _lan_host:
		network.publish_event({"type": event_type, "state": state})

func _on_match_finished(winner: Duelist.Team) -> void:
	_clear_ballistics()
	_clear_presentation_effects()
	if hud != null:
		hud.show_match_result(winner)
	if _lan_host:
		network.publish_event({"type": "finished", "winner": int(winner)})

func _on_phase_changed(phase: LinebreakMatch.Phase) -> void:
	if phase != LinebreakMatch.Phase.LIVE:
		_clear_ballistics()
		_clear_presentation_effects()
	_lan_phase = phase
	if phase != LinebreakMatch.Phase.LIVE:
		_continuous_inputs.clear()
		_edge_queues.clear()
	if hud != null:
		hud.set_match_phase(phase)
		hud.set_combat_input_enabled(phase == LinebreakMatch.Phase.LIVE)
	if _lan_host:
		network.publish_event({"type": "phase", "phase": int(phase)})

func _ensure_ballistics() -> void:
	if ballistics != null:
		return
	ballistics = RiftBallistics.new()
	ballistics.name = "RiftBallistics"
	add_child(ballistics)
	ballistics.projectile_fired.connect(_on_projectile_fired)
	ballistics.projectile_impacted.connect(_on_projectile_impacted)
	_build_projectile_presentation_pool()

func _tick_authority_ballistics(delta: float) -> void:
	if ballistics == null or director == null or not director.is_live():
		return
	ballistics.tick_authority(delta)

func _clear_ballistics() -> void:
	if ballistics != null:
		ballistics.clear()
	_pending_local_primary_predictions = 0
	for tracer in _tracer_pool:
		if is_instance_valid(tracer):
			tracer.set_meta("token", int(tracer.get_meta("token", 0)) + 1)
			tracer.visible = false
	for impact in _impact_pool:
		if is_instance_valid(impact):
			impact.set_meta("token", int(impact.get_meta("token", 0)) + 1)
			impact.visible = false

func _on_authority_fire_requested(shooter: Duelist, fired_weapon: Duelist.Weapon, origin: Vector3, direction: Vector3) -> void:
	if ballistics != null:
		ballistics.fire(shooter, fired_weapon, origin, direction)

func _on_local_fire_requested(_shooter: Duelist, fired_weapon: Duelist.Weapon, _origin: Vector3, _direction: Vector3) -> void:
	if fired_weapon != Duelist.Weapon.PULSE or not _presentation_enabled:
		return
	# Joining clients predict only local presentation.  Combat remains authority-owned.
	_pending_local_primary_predictions = mini(_pending_local_primary_predictions + 1, 8)
	_play_shooter_fire(_local_team, fired_weapon)
	if hud != null:
		hud.show_primary_fire_feedback()

func _on_projectile_fired(fact: Dictionary) -> void:
	var projectile_id := int(fact.get("id", -1))
	var projectile_key := "%s:%d" % [str(fact.get("session_id", "legacy")), projectile_id]
	if projectile_id < 0 or _seen_projectile_fires.has(projectile_key):
		return
	_last_projectile_fire_id = maxi(_last_projectile_fire_id, projectile_id)
	_seen_projectile_fires[projectile_key] = Time.get_ticks_msec()
	_trim_projectile_cache(_seen_projectile_fires)
	var shooter_id := str(fact.get("shooter_id", ""))
	var local_prediction := _local_duelist != null and shooter_id == _local_duelist.actor_id and _pending_local_primary_predictions > 0
	if local_prediction:
		_pending_local_primary_predictions -= 1
	if _presentation_enabled:
		if not local_prediction:
			_play_shooter_fire_by_id(shooter_id, Duelist.Weapon.PULSE)
			if _local_duelist != null and shooter_id == _local_duelist.actor_id and hud != null:
				hud.show_primary_fire_feedback()
		_spawn_projectile_tracer(fact)
	if _lan_host:
		network.publish_event(fact)

func _on_projectile_impacted(fact: Dictionary) -> void:
	var projectile_id := int(fact.get("id", -1))
	var projectile_key := "%s:%d" % [str(fact.get("session_id", "legacy")), projectile_id]
	if projectile_id < 0 or _seen_projectile_impacts.has(projectile_key):
		return
	_last_projectile_impact_id = maxi(_last_projectile_impact_id, projectile_id)
	_seen_projectile_impacts[projectile_key] = Time.get_ticks_msec()
	_trim_projectile_cache(_seen_projectile_impacts)
	_cancel_projectile_tracer(fact)
	if _presentation_enabled:
		var team := int(fact.get("team", int(Duelist.Team.SUN))) as Duelist.Team
		_spawn_projectile_impact(fact.get("position", Vector3.ZERO), fact.get("normal", Vector3.UP), team, bool(fact.get("hit_duelist", false)))
		if team == _local_team and bool(fact.get("hit_duelist", false)) and hud != null:
			hud.show_hit_confirm()
	if _lan_host:
		network.publish_event(fact)

func _trim_projectile_cache(cache: Dictionary) -> void:
	while cache.size() > 128:
		cache.erase(cache.keys()[0])

func _on_scatter_shot(shooter_id: String, origin: Vector3, end: Vector3, team: Duelist.Team, fired_weapon: Duelist.Weapon, hit_target: bool) -> void:
	if _presentation_enabled:
		_show_scatter_shot(shooter_id, origin, end, team, fired_weapon, hit_target)
	if _lan_host:
		network.publish_event({"type": "shot", "shooter_id": shooter_id, "origin": origin, "end": end, "team": int(team), "weapon": int(fired_weapon), "hit": hit_target})

func _show_scatter_shot(shooter_id: String, origin: Vector3, end: Vector3, team: Duelist.Team, fired_weapon: Duelist.Weapon, hit_target: bool) -> void:
	if not _presentation_enabled:
		return
	_play_shooter_fire_by_id(shooter_id, fired_weapon)
	if team == _local_team and hit_target and hud != null:
		hud.show_hit_confirm()
	var accent := Color("ffb15c") if team == Duelist.Team.SUN else Color("75dbff")
	_spawn_beam(origin, end, accent.lerp(Color("f4e3ff"), 0.35), 0.036, 0.09)
	_spawn_impact(end, accent, 0.15, 0.12)

func _on_rift_link_requested() -> void:
	hud.set_connection_flow_active(true)
	rift_link.open_menu()

func _on_host_requested() -> void:
	_join_discovery_started = false
	rift_link.show_host()
	var error := network.host_lan()
	if error != OK:
		rift_link.set_status("LINK ERROR")
		return
	_enter_lan_runtime(true, true)

func _on_join_requested() -> void:
	hud.set_connection_flow_active(true)
	if not _join_discovery_started:
		_join_discovery_started = true
		rift_link.show_join()
		network.begin_lan_discovery()
		return
	var error := network.join_discovered_host()
	if error != OK:
		rift_link.set_status("NO RIFT FOUND")
	else:
		_enter_lan_runtime(false, true)
		rift_link.set_status("LINKING")

func _on_join_retry_requested() -> void:
	_join_discovery_started = true
	rift_link.show_join()
	rift_link.show_join()
	network.begin_lan_discovery()

func _on_rift_link_cancelled() -> void:
	_join_discovery_started = false
	if _lan_active:
		_restore_offline_training("RIFT CLOSED")
	else:
		network.stop()
		rift_link.hide_panel()
		hud.set_connection_flow_active(false)

func _on_network_status(status: String) -> void:
	if rift_link != null and rift_link.visible:
		rift_link.set_status(status)
	if status in ["LINK LOST", "LINK FAILED"] and _lan_active and not _dedicated_server:
		_restore_offline_training(status)

func _on_host_discovered(session: Dictionary) -> void:
	_join_discovery_started = true
	if rift_link != null and rift_link.visible:
		rift_link.set_squad_mode(str(session.get("mode", "duel")) == "squad")
		rift_link.set_discovered_session(true)

func _on_network_peer_joined(peer_id: int) -> void:
	if not _lan_active:
		return
	if not _lan_host:
		_lan_peer_ready = true
		network.publish_event({"type": "ready"})
		return
	var actor_id := network.peer_actor_id(peer_id)
	if actor_id.is_empty():
		return
	_actor_for_peer[peer_id] = actor_id
	_continuous_inputs[actor_id] = {}
	_edge_queues[actor_id] = []
	_last_sequences[actor_id] = -1
	if _lan_host:
		_sync_roster_records(_authority_records())
	else:
		_lan_peer_ready = true
		network.publish_event({"type": "ready"})


func _on_network_peer_left(peer_id: int) -> void:
	_clear_ballistics()
	var actor_id := str(_actor_for_peer.get(peer_id, network.peer_actor_id(peer_id)))
	_actor_for_peer.erase(peer_id)
	if not actor_id.is_empty():
		_remove_actor(actor_id)
	if _dedicated_server:
		_authority_match_started = false
		_ready_peers.erase(peer_id)
		_continuous_inputs.erase(actor_id)
		_edge_queues.erase(actor_id)
		_last_sequences.erase(actor_id)
		if director != null:
			_sync_roster_records(_authority_records())
		return
	if _lan_active and not _lan_host:
		_restore_offline_training("LINK LOST")

func _on_network_input(peer_id: int, frame: Dictionary) -> void:
	if not _lan_active or not _lan_host or director == null or not director.is_live():
		return
	var actor_id := str(_actor_for_peer.get(peer_id, network.peer_actor_id(peer_id)))
	if actor_id.is_empty() or _actor(actor_id) == null:
		return
	_continuous_inputs[actor_id] = _continuous_input(frame)
	var edges: Array = _edge_queues.get(actor_id, [])
	edges.append(_discrete_input(frame))
	_edge_queues[actor_id] = edges
	_last_sequences[actor_id] = int(frame.get("sequence", -1))

func _on_network_snapshot(snapshot: Dictionary) -> void:
	if not _lan_active or _lan_host or snapshot.is_empty():
		return
	if director != null:
		var replica_match: Dictionary = snapshot.get("match", snapshot).duplicate(true)
		replica_match["tick"] = int(snapshot.get("tick", -1))
		director.apply_replica_state(replica_match)
	var players: Dictionary = snapshot.get("players", {})
	var local_state: Dictionary = players.get(_local_actor_id, {})
	if not local_state.is_empty():
		var acknowledged := int(local_state.get("last_input", -1))
		var remaining: Array[Dictionary] = []
		for frame in _pending_inputs:
			if int(frame.get("sequence", -1)) > acknowledged:
				remaining.append(frame)
		_pending_inputs = remaining
		if _local_duelist != null:
			_local_duelist.reconcile_from_authority(local_state, _pending_inputs, 1.0 / 60.0)
	for actor_id in players.keys():
		if str(actor_id) == _local_actor_id:
			continue
		var remote_state: Dictionary = players[actor_id]
		if _actor(str(actor_id)) == null:
			_pending_actor_snapshots[str(actor_id)] = {"state": remote_state.duplicate(true), "tick": int(snapshot.get("tick", -1)), "arrival": Time.get_ticks_msec()}
		else:
			_update_remote_snapshot(str(actor_id), remote_state, int(snapshot.get("tick", -1)))
	if hud != null:
		var match_state: Dictionary = snapshot.get("match", snapshot)
		hud.set_score(int(match_state.get("sun_score", 0)), int(match_state.get("void_score", 0)))
	_sync_squad_hud()

func _on_network_event(event: Dictionary, sender_id: int) -> void:
	if event.is_empty():
		return
	var event_type := str(event.get("type", ""))
	if _lan_host:
		if event_type == "ready" and not network.peer_actor_id(sender_id).is_empty():
			_ready_peers[sender_id] = true
			if _authority_roster_ready():
				_start_host_match()
		elif event_type == "rematch_request" and not network.peer_actor_id(sender_id).is_empty() and director != null:
			director.take_rematch()
		return
	match event_type:
		"phase":
			_apply_client_phase(int(event.get("phase", int(LinebreakMatch.Phase.OPENING))))
		"score":
			if hud != null:
				hud.set_score(int(event.get("sun", 0)), int(event.get("void", 0)))
		"finished":
			_clear_ballistics()
			if hud != null:
				hud.show_match_result(int(event.get("winner", int(Duelist.Team.SUN))) as Duelist.Team)
		"defeat":
			_apply_client_defeat(str(event.get("victim_id", "")))
		"projectile_fired":
			_on_projectile_fired(event)
		"projectile_impacted":
			_on_projectile_impacted(event)
		"shot":
			_show_scatter_shot(str(event.get("shooter_id", "")), event.get("origin", Vector3.ZERO), event.get("end", Vector3.ZERO), int(event.get("team", int(Duelist.Team.SUN))) as Duelist.Team, int(event.get("weapon", int(Duelist.Weapon.SCATTER))) as Duelist.Weapon, bool(event.get("hit", false)))
		"spawn":
			_apply_client_spawn(str(event.get("actor_id", "")), event.get("position", null), float(event.get("yaw", 0.0)))
		"roster":
			_sync_roster_records(event.get("records", []))
		"objective_claimed", "objective_dropped", "objective_returned", "objective_delivered":
			_on_objective_event(str(event.get("type", "")), event.get("state", {}))

func _enter_lan_runtime(host: bool, from_player_flow: bool) -> void:
	if _lan_active:
		return
	if coach != null:
		coach.hide()
	_lan_active = true
	_lan_host = host
	_dedicated_server = network.is_dedicated_server()
	_lan_phase = LinebreakMatch.Phase.OPENING
	_lan_tick = 0
	_local_input_sequence = 0
	_pending_inputs.clear()
	_pending_actor_snapshots.clear()
	_clear_ballistics()
	_continuous_inputs.clear()
	_edge_queues.clear()
	_last_sequences.clear()
	_actor_for_peer.clear()
	_ready_peers.clear()
	_authority_match_started = false
	_local_actor_id = network.local_actor_id
	_local_team = network.local_team as Duelist.Team if network.local_team >= 0 else Duelist.Team.SUN
	_replace_match_for_lan(host)
	if hud != null:
		hud.set_connection_flow_active(false if not from_player_flow else true)
	if from_player_flow:
		# The panel remains up until the second human is ready, so the arena cannot consume stale touches.
		if hud != null:
			hud.set_combat_input_enabled(false)

func _replace_match_for_lan(host: bool) -> void:
	_clear_match_nodes()
	if host:
		_ensure_ballistics()
	elif ballistics != null:
		ballistics.queue_free()
		ballistics = null
	director = LinebreakMatch.new()
	add_child(director)
	director.configure(Vector3.ZERO, _gate_positions(), _presentation_enabled)
	var team_points := SUN_SQUAD_SPAWNS if network.team_size > 1 else [SUN_COVER_SPAWN]
	for point in team_points:
		director.add_spawn(Duelist.Team.SUN, point)
	team_points = VOID_SQUAD_SPAWNS if network.team_size > 1 else [VOID_COVER_SPAWN]
	for point in team_points:
		director.add_spawn(Duelist.Team.VOID, point)
	director.score_changed.connect(_on_score_changed)
	director.phase_changed.connect(_on_phase_changed)
	director.match_finished.connect(_on_match_finished)
	director.respawn_started.connect(_on_lan_respawn_started)
	director.objective_changed.connect(_on_objective_changed)
	director.objective_event.connect(_on_objective_event)
	if host:
		_sync_roster_records(_authority_records())
	elif not _local_actor_id.is_empty():
		var local_record := {"actor_id": _local_actor_id, "team": int(_local_team), "human": true}
		_sync_roster_records([local_record])

func _clear_match_nodes() -> void:
	_clear_ballistics()
	if director != null:
		director.queue_free()
	for actor in _all_authority_actors():
		if is_instance_valid(actor):
			actor.queue_free()
	for actor in _all_replica_actors():
		if is_instance_valid(actor):
			actor.queue_free()
	_authoritative_duelists.clear()
	_replica_duelists.clear()
	_remote_snapshot_buffers.clear()
	_continuous_inputs.clear()
	_edge_queues.clear()
	_last_sequences.clear()
	director = null
	_local_duelist = null

func _start_host_match() -> void:
	if _authority_match_started or director == null or not _authority_roster_ready():
		return
	if rift_link != null:
		rift_link.hide_panel()
	if hud != null:
		hud.set_connection_flow_active(false)
	_authority_match_started = true
	director.begin()
	print("Riftline authoritative match started")
	for actor in _all_authority_actors():
		network.publish_event({"type": "spawn", "actor_id": actor.actor_id, "position": actor.global_position, "yaw": actor.rotation.y})

func _tick_lan_duel(delta: float) -> void:
	if _local_duelist == null:
		return
	if hud.take_rematch():
		if _lan_host and director != null:
			director.take_rematch()
		elif not _lan_host:
			network.publish_event({"type": "rematch_request"})
	_local_duelist.apply_look(hud.take_look_delta())
	if hud.gyro_enabled:
		var gyroscope := Input.get_gyroscope()
		_local_duelist.apply_look(Vector2(gyroscope.y, -gyroscope.x) * 2.4)
	var live := director != null and director.is_live() if _lan_host else _lan_phase == LinebreakMatch.Phase.LIVE
	var wants_reload := hud.take_reload() or Input.is_action_just_pressed("reload")
	if not live or not hud.can_drive_combat():
		hud.take_jump()
		hud.take_crouch()
		hud.take_prone()
		hud.take_weapon_switch()
		_local_duelist.set_combat_pose(false, delta)
		_local_duelist.apply_input_frame({}, delta, false)
	else:
		var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var movement := hud.movement if hud.movement.length_squared() > 0.001 else keyboard
		var frame := _local_duelist.make_input_frame(
			_local_input_sequence,
			movement,
			hud.aim_held,
			hud.fire_held or Input.is_action_pressed("fire"),
			hud.take_jump() or Input.is_action_just_pressed("jump"),
			hud.take_crouch(),
			hud.take_prone(),
			hud.take_weapon_switch(),
			wants_reload)
		_local_input_sequence += 1
		_local_duelist.set_combat_pose(bool(frame.aim), delta)
		if _lan_host:
			_local_duelist.apply_input_frame(frame, delta, true)
			for actor_id in _authoritative_duelists.keys():
				if str(actor_id) == _local_actor_id:
					continue
				var target := _actor(str(actor_id))
				if target == null:
					continue
				for edge in _edge_queues.get(actor_id, []):
					target.apply_discrete_input(edge)
				_edge_queues[actor_id] = []
				target.apply_continuous_input(_continuous_inputs.get(actor_id, {}), delta, true)
		else:
			_local_duelist.apply_input_frame(frame, delta, false)
			if _local_duelist.weapon == Duelist.Weapon.PULSE and bool(frame.fire):
				# The joining client predicts only the local carbine presentation.  No scatter ray or hit path runs here.
				_local_duelist.fire_forward()
			_pending_inputs.append(frame)
			network.send_input(frame)
	hud.set_stance(_local_duelist.stance)
	hud.set_weapon(_local_duelist.weapon)
	hud.show_ammo(_local_duelist.magazine_rounds, _local_duelist.reserve_ammo, _local_duelist.reload_remaining)
	hud.show_damage(_local_duelist.health)
	if not _lan_host:
		_smooth_remote_presentation()
	if _lan_host:
		_lan_tick += 1
		_tick_authority_ballistics(delta)
		_snapshot_remaining -= delta
		if _snapshot_remaining <= 0.0:
			_snapshot_remaining = 0.05
			_publish_lan_snapshot()

func _smooth_remote_presentation() -> void:
	for actor_id in _remote_snapshot_buffers.keys():
		var actor := _actor(str(actor_id))
		var buffer: RefCounted = _remote_snapshot_buffers[actor_id]
		if actor == null or buffer == null:
			continue
		var presented: Dictionary = buffer.sample(network.simulation_clock)
		if not presented.is_empty():
			actor.apply_presentation_state(presented)

func _update_remote_snapshot(actor_id: String, remote_state: Dictionary, host_tick: int) -> void:
	var actor := _actor(actor_id)
	var buffer: RefCounted = _remote_snapshot_buffers.get(actor_id, null)
	if actor == null or buffer == null or remote_state.is_empty():
		return
	var next_eliminated := bool(remote_state.get("eliminated", false))
	var previous: Dictionary = buffer.sample(network.simulation_clock)
	var should_reset := not previous.is_empty() and next_eliminated != bool(previous.get("eliminated", false))
	var incoming_position: Vector3 = remote_state.get("position", actor.global_position)
	if actor.global_position.distance_to(incoming_position) > 3.0:
		should_reset = true
	if should_reset:
		buffer.clear()
		actor.apply_presentation_state(remote_state)
	buffer.push(remote_state, host_tick, network.simulation_clock)

func _tick_dedicated_server(delta: float) -> void:
	if not _lan_active or director == null:
		return
	var applied: Dictionary = {}
	for actor_id in _authoritative_duelists.keys():
		var target: Duelist = _authoritative_duelists[actor_id]
		if target == null:
			continue
		if _continuous_inputs.has(actor_id):
			applied[actor_id] = true
		var edges: Array = _edge_queues.get(actor_id, [])
		_edge_queues[actor_id] = []
		if director.is_live():
			for edge in edges:
				target.apply_discrete_input(edge)
			target.apply_continuous_input(_continuous_inputs.get(actor_id, {}), delta, true)
		else:
			target.apply_continuous_input({}, delta, false)
	for actor_id in _authoritative_duelists.keys():
		if not applied.has(actor_id):
			(_authoritative_duelists[actor_id] as Duelist).apply_continuous_input({}, delta, false)
	_tick_authority_ballistics(delta)
	_lan_tick += 1
	_snapshot_remaining -= delta
	if _snapshot_remaining <= 0.0:
		_snapshot_remaining = 0.05
		_publish_lan_snapshot()

func _publish_lan_snapshot() -> void:
	if director == null:
		return
	var match_state := director.authoritative_state()
	var players := {}
	for actor_id in _authoritative_duelists.keys():
		var duelist: Duelist = _authoritative_duelists[actor_id]
		players[actor_id] = duelist.authoritative_state(_lan_tick, _last_sequence_for(duelist))
	var snapshot := {
		"tick": _lan_tick,
		"match": match_state,
		"phase": int(match_state.get("phase", int(director.phase))),
		"sun_score": int(match_state.get("sun_score", 0)),
		"void_score": int(match_state.get("void_score", 0)),
		"objective": match_state.get("objective", {}),
		"players": players,
	}
	network.publish_snapshot(snapshot)

func _last_sequence_for(duelist: Duelist) -> int:
	return _local_input_sequence - 1 if duelist.actor_id == _local_actor_id else int(_last_sequences.get(duelist.actor_id, -1))

func _apply_client_phase(next_phase: int) -> void:
	_lan_phase = next_phase as LinebreakMatch.Phase
	if _lan_phase != LinebreakMatch.Phase.LIVE:
		_clear_ballistics()
	for buffer in _remote_snapshot_buffers.values():
		(buffer as RefCounted).clear()
	if hud != null:
		hud.set_match_phase(_lan_phase)
		hud.set_combat_input_enabled(_lan_phase == LinebreakMatch.Phase.LIVE)
	for actor in _all_replica_actors():
		actor.set_match_active(_lan_phase == LinebreakMatch.Phase.LIVE)
	if _lan_phase == LinebreakMatch.Phase.LIVE:
		if rift_link != null:
			rift_link.hide_panel()
		if hud != null:
			hud.set_connection_flow_active(false)

func _on_team_assigned(team_value: int) -> void:
	if team_value < int(Duelist.Team.SUN) or team_value > int(Duelist.Team.VOID):
		return
	_local_team = team_value as Duelist.Team

func _on_actor_assigned(actor_id: String, team_value: int) -> void:
	if actor_id.is_empty() or team_value < int(Duelist.Team.SUN) or team_value > int(Duelist.Team.VOID):
		return
	_local_actor_id = actor_id
	_local_team = team_value as Duelist.Team
	if _lan_active and not _lan_host and not _dedicated_server:
		_sync_roster_records([{"actor_id": actor_id, "team": team_value, "human": true}])

func _on_roster_received(records: Array[Dictionary]) -> void:
	if not _lan_active or _lan_host:
		return
	_sync_roster_records(records)

func _authority_roster_ready() -> bool:
	if network == null or network.roster == null or not network.roster.is_ready():
		return false
	var remote_required := 0
	for record in network.roster.records():
		if bool(record.get("human", false)) and int(record.get("peer_id", -1)) > 0:
			remote_required += 1
	return _ready_peers.size() >= remote_required

func _on_lan_defeat(victim: Duelist, killer: Duelist) -> void:
	if _lan_host:
		network.publish_event({"type": "defeat", "victim_id": victim.actor_id, "killer_id": killer.actor_id})

func _on_lan_respawn_started(victim: Duelist) -> void:
	_clear_presentation_effects()
	if _lan_host:
		network.publish_event({"type": "spawn", "actor_id": victim.actor_id, "position": victim.global_position, "yaw": victim.rotation.y})

func _apply_client_defeat(actor_id: String) -> void:
	var victim := _actor(actor_id)
	if victim != null:
		victim.apply_presentation_state({"health": 0.0, "eliminated": true})

func _apply_client_spawn(actor_id: String, position: Variant = null, yaw: float = 0.0) -> void:
	_clear_ballistics()
	_clear_presentation_effects()
	var target := _actor(actor_id)
	if target == null:
		return
	if position == null or not position is Vector3:
		return
	target.apply_presentation_state({
		"position": position,
		"velocity": Vector3.ZERO,
		"yaw": yaw,
		"pitch": 0.0,
		"health": Duelist.HEALTH,
		"stance": int(Duelist.Stance.STAND),
		"weapon": int(Duelist.Weapon.PULSE),
		"eliminated": false,
	})
	if target == _local_duelist:
		_pending_inputs.clear()

func _restore_offline_training(message: String) -> void:
	_clear_ballistics()
	_clear_presentation_effects()
	if coach != null:
		coach.hide()
	_lan_active = false
	_lan_host = false
	_lan_peer_ready = false
	network.stop()
	rift_link.hide_panel()
	hud.set_connection_flow_active(false)
	_clear_match_nodes()
	_build_match()
	director.begin()
	hud.show_connection_message(message)

func _sync_objective_presentation() -> void:
	if director == null or not _objective_preview.is_empty():
		return
	var state := director.objective_state()
	if hud != null:
		hud.set_objective_state(state)
	if coach != null and not _lan_active:
		coach.observe_objective(state)

func _sync_squad_hud() -> void:
	if hud == null:
		return
	var actors := _all_replica_actors() if _lan_active and not _lan_host else _all_authority_actors()
	var records: Array[Dictionary] = []
	for actor in actors:
		records.append({"actor_id": actor.actor_id, "team": int(actor.team), "eliminated": actor.eliminated})
	var squad := _offline_squad_size > 1 or (network != null and network.team_size > 1) or records.size() > 2
	hud.set_roster_state(records, int(_local_team), squad)

func _gate_positions() -> Dictionary:
	return {
		Duelist.Team.SUN: SUN_GATE_POSITION,
		Duelist.Team.VOID: VOID_GATE_POSITION,
	}

func _continuous_input(frame: Dictionary) -> Dictionary:
	return {
		"sequence": int(frame.get("sequence", -1)),
		"move_x": float(frame.get("move_x", 0.0)),
		"move_y": float(frame.get("move_y", 0.0)),
		"yaw": float(frame.get("yaw", 0.0)),
		"pitch": float(frame.get("pitch", 0.0)),
		"aim": bool(frame.get("aim", false)),
		"fire": bool(frame.get("fire", false)),
	}

func _discrete_input(frame: Dictionary) -> Dictionary:
	return {
		"sequence": int(frame.get("sequence", -1)),
		"jump": bool(frame.get("jump", false)),
		"crouch": bool(frame.get("crouch", false)),
		"prone": bool(frame.get("prone", false)),
		"weapon_switch": bool(frame.get("weapon_switch", false)),
		"reload": bool(frame.get("reload", false)),
	}

func _play_shooter_fire(team: Duelist.Team, fired_weapon: Duelist.Weapon) -> void:
	for actor in _all_authority_actors():
		if actor.team == team:
			actor.play_local_weapon_fire(fired_weapon) if actor == _local_duelist else actor.play_remote_weapon_fire(fired_weapon)
			return
	for actor in _all_replica_actors():
		if actor.team == team:
			actor.play_local_weapon_fire(fired_weapon) if actor == _local_duelist else actor.play_remote_weapon_fire(fired_weapon)
			return

func _play_shooter_fire_by_id(actor_id: String, fired_weapon: Duelist.Weapon) -> void:
	var actor := _actor(actor_id)
	if actor == null:
		return
	actor.play_local_weapon_fire(fired_weapon) if actor == _local_duelist else actor.play_remote_weapon_fire(fired_weapon)

func _build_projectile_presentation_pool() -> void:
	if not _presentation_enabled or _projectile_presentation_pool != null:
		return
	_projectile_presentation_pool = Node3D.new()
	_projectile_presentation_pool.name = "ProjectilePresentationPool"
	add_child(_projectile_presentation_pool)
	for _index in 12:
		var tracer := MeshInstance3D.new()
		var tracer_mesh := BoxMesh.new()
		tracer_mesh.size = Vector3(0.032, 0.032, 1.2)
		tracer.mesh = tracer_mesh
		tracer.material_override = _pulp_material(Color("fff0b0"), 6.0)
		tracer.visible = false
		_projectile_presentation_pool.add_child(tracer)
		_tracer_pool.append(tracer)
	for _index in 8:
		var impact := Node3D.new()
		impact.name = "CarbineImpact"
		impact.visible = false
		var vertical := MeshInstance3D.new()
		var vertical_mesh := BoxMesh.new()
		vertical_mesh.size = Vector3(0.055, 0.48, 0.025)
		vertical.mesh = vertical_mesh
		vertical.material_override = _pulp_material(Color("fff0b0"), 5.0)
		impact.add_child(vertical)
		var horizontal := MeshInstance3D.new()
		var horizontal_mesh := BoxMesh.new()
		horizontal_mesh.size = Vector3(0.48, 0.055, 0.025)
		horizontal.mesh = horizontal_mesh
		horizontal.material_override = _pulp_material(Color("fff0b0"), 5.0)
		impact.add_child(horizontal)
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.18
		ring_mesh.outer_radius = 0.22
		ring_mesh.rings = 12
		ring_mesh.ring_segments = 8
		ring.mesh = ring_mesh
		ring.rotation.x = PI * 0.5
		ring.material_override = _pulp_material(Color("fff0b0"), 4.0)
		impact.add_child(ring)
		_projectile_presentation_pool.add_child(impact)
		_impact_pool.append(impact)

func _spawn_projectile_tracer(fact: Dictionary) -> void:
	if _tracer_pool.is_empty():
		return
	var tracer := _tracer_pool[_tracer_cursor]
	_tracer_cursor = (_tracer_cursor + 1) % _tracer_pool.size()
	var previous_projectile_key := str(tracer.get_meta("projectile_key", ""))
	if not previous_projectile_key.is_empty() and _projectile_tracers.get(previous_projectile_key) == tracer:
		_projectile_tracers.erase(previous_projectile_key)
	var token := int(tracer.get_meta("token", 0)) + 1
	tracer.set_meta("token", token)
	var origin: Vector3 = fact.get("origin", Vector3.ZERO)
	var velocity: Vector3 = fact.get("velocity", Vector3.ZERO)
	if velocity.length_squared() < 0.0001:
		return
	var direction := velocity.normalized()
	tracer.global_position = origin + direction * 0.55
	tracer.look_at(tracer.global_position + direction, Vector3.UP)
	tracer.scale = Vector3.ONE
	tracer.visible = true
	var team := int(fact.get("team", int(Duelist.Team.SUN))) as Duelist.Team
	_set_projectile_color(tracer, Color("ffb15c") if team == Duelist.Team.SUN else Color("75dbff"), 4.0)
	var projectile_id := int(fact.get("id", -1))
	var projectile_key := "%s:%d" % [str(fact.get("session_id", "legacy")), projectile_id]
	tracer.set_meta("projectile_id", projectile_id)
	tracer.set_meta("projectile_key", projectile_key)
	if projectile_id >= 0:
		_projectile_tracers[projectile_key] = tracer
	_animate_projectile_tracer(tracer, origin, velocity, projectile_key, token)

func _animate_projectile_tracer(tracer: MeshInstance3D, origin: Vector3, velocity: Vector3, projectile_key: String, token: int) -> void:
	var elapsed := 0.0
	while elapsed < 0.07 and is_instance_valid(tracer) and int(tracer.get_meta("token", -1)) == token:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var direction := velocity.normalized()
		tracer.global_position = origin + direction * velocity.length() * elapsed
		tracer.look_at(tracer.global_position + direction, Vector3.UP)
	if is_instance_valid(tracer) and int(tracer.get_meta("token", -1)) == token:
		tracer.visible = false
	if _projectile_tracers.get(projectile_key) == tracer:
		_projectile_tracers.erase(projectile_key)

func _cancel_projectile_tracer(fact: Dictionary) -> void:
	var projectile_key := "%s:%d" % [str(fact.get("session_id", "legacy")), int(fact.get("id", -1))]
	var tracer: MeshInstance3D = _projectile_tracers.get(projectile_key)
	if is_instance_valid(tracer):
		tracer.set_meta("token", int(tracer.get_meta("token", 0)) + 1)
		tracer.visible = false
	_projectile_tracers.erase(projectile_key)

func _spawn_projectile_impact(point: Vector3, normal: Vector3, team: Duelist.Team, hit_duelist: bool) -> void:
	if _impact_pool.is_empty():
		return
	var impact := _impact_pool[_impact_cursor]
	_impact_cursor = (_impact_cursor + 1) % _impact_pool.size()
	var token := int(impact.get_meta("token", 0)) + 1
	impact.set_meta("token", token)
	impact.global_position = point
	var safe_normal := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	impact.look_at(point + safe_normal, Vector3.RIGHT if absf(safe_normal.dot(Vector3.UP)) > 0.92 else Vector3.UP)
	impact.scale = Vector3.ONE * (0.8 if hit_duelist else 0.5)
	var ring := impact.get_child(2) as MeshInstance3D
	if ring != null:
		ring.visible = hit_duelist
	for child in impact.get_children():
		_set_projectile_color(child as MeshInstance3D, Color("ffb15c") if team == Duelist.Team.SUN else Color("75dbff"), 3.8 if hit_duelist else 2.8)
	impact.visible = true
	_animate_projectile_impact(impact, token)

func _animate_projectile_impact(impact: Node3D, token: int) -> void:
	var elapsed := 0.0
	while elapsed < 0.16 and is_instance_valid(impact) and int(impact.get_meta("token", -1)) == token:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		impact.scale = Vector3.ONE * (1.0 + elapsed * 2.0)
	if is_instance_valid(impact) and int(impact.get_meta("token", -1)) == token:
		impact.visible = false

func _set_projectile_color(instance: MeshInstance3D, color: Color, glow: float) -> void:
	if instance == null or not (instance.material_override is ShaderMaterial):
		return
	var material := instance.material_override as ShaderMaterial
	material.set_shader_parameter("base_tint", color)
	material.set_shader_parameter("rim_tint", color)
	material.set_shader_parameter("glow_strength", glow)

func _spawn_beam(origin: Vector3, end: Vector3, color: Color, radius: float, lifetime: float) -> void:
	if _presentation_effects == null or origin.distance_squared_to(end) < 0.0001:
		return
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = origin.distance_to(end)
	beam.mesh = mesh
	beam.material_override = _pulp_material(color, 5.5)
	beam.position = origin.lerp(end, 0.5)
	_presentation_effects.add_child(beam)
	beam.look_at(end, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_remove_presentation_node(beam, lifetime)

func _spawn_impact(point: Vector3, color: Color, radius: float, lifetime: float) -> void:
	if _presentation_effects == null:
		return
	var impact := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	impact.mesh = mesh
	impact.material_override = _pulp_material(color, 5.0)
	impact.position = point
	impact.scale = Vector3(1.0, 1.0, 0.42)
	_presentation_effects.add_child(impact)
	_remove_presentation_node(impact, lifetime)

func _spawn_delivery_pulse(gate_position: Vector3, color: Color) -> void:
	if _presentation_effects == null:
		return
	var pulse := MeshInstance3D.new()
	var pulse_mesh := TorusMesh.new()
	pulse_mesh.inner_radius = 0.28
	pulse_mesh.outer_radius = 0.36
	pulse_mesh.rings = 20
	pulse_mesh.ring_segments = 10
	pulse.mesh = pulse_mesh
	pulse.position = gate_position + Vector3.UP * 1.35
	pulse.material_override = _pulp_material(color, 4.2)
	_presentation_effects.add_child(pulse)
	_animate_delivery_pulse(pulse)
	for side in [-1.0, 1.0]:
		var flare := MeshInstance3D.new()
		flare.mesh = _box_mesh(Vector3(0.08, 2.8, 0.08))
		flare.position = gate_position + Vector3(side * 0.72, 1.4, 0.0)
		flare.material_override = _pulp_material(color, 4.0)
		_presentation_effects.add_child(flare)
		_remove_presentation_node(flare, 0.24)

func _animate_delivery_pulse(pulse: MeshInstance3D) -> void:
	var elapsed := 0.0
	while elapsed < 0.42 and is_instance_valid(pulse):
		await get_tree().process_frame
		var delta := get_process_delta_time()
		elapsed += delta
		var progress := clampf(elapsed / 0.42, 0.0, 1.0)
		pulse.scale = Vector3.ONE * (1.0 + progress * 2.4)
		if pulse.material_override is ShaderMaterial:
			(pulse.material_override as ShaderMaterial).set_shader_parameter("glow_strength", 4.2 * (1.0 - progress))
	if is_instance_valid(pulse):
		pulse.queue_free()

func _remove_presentation_node(node: Node, lifetime: float) -> void:
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(node):
		node.queue_free()

func _clear_presentation_effects() -> void:
	if _presentation_effects == null:
		return
	for child in _presentation_effects.get_children():
		child.queue_free()

func _build_landmarks() -> void:
	if not _presentation_enabled:
		return
	# These are callout shapes, not cover. Their narrow footprint keeps the proven collision and sight-line layout intact.
	var sun_root := Node3D.new()
	sun_root.position = Vector3(-17.0, 0.0, -10.5)
	add_child(sun_root)
	_add_landmark_part(sun_root, _box_mesh(Vector3(0.16, 5.2, 0.16)), Vector3.ZERO, Color("d6ad67"), Vector3(0.0, 0.0, -0.12))
	_add_landmark_part(sun_root, _box_mesh(Vector3(1.65, 0.08, 0.08)), Vector3(0.35, 2.45, 0.0), Color("d6ad67"), Vector3(0.0, 0.0, 0.18))
	_add_landmark_part(sun_root, _box_mesh(Vector3(0.08, 1.3, 0.08)), Vector3(0.72, 2.12, 0.0), Color("ffb15c"), Vector3(0.0, 0.0, -0.26), 2.8)
	_add_landmark_part(sun_root, _cylinder_mesh(0.72, 0.72, 0.06), Vector3(0.38, 1.85, 0.0), Color("ffb15c"), Vector3.ZERO, 3.2)

	var void_root := Node3D.new()
	void_root.position = Vector3(17.0, 0.0, 10.5)
	add_child(void_root)
	_add_landmark_part(void_root, _box_mesh(Vector3(0.16, 5.0, 0.16)), Vector3.ZERO, Color("91b8d3"), Vector3(0.0, 0.0, 0.16))
	_add_landmark_part(void_root, _box_mesh(Vector3(1.9, 0.1, 0.08)), Vector3(-0.32, 2.4, 0.0), Color("91b8d3"), Vector3(0.0, 0.0, -0.22))
	_add_landmark_part(void_root, _box_mesh(Vector3(0.72, 0.05, 0.42)), Vector3(-0.86, 2.42, 0.0), Color("75dbff"), Vector3(0.0, 0.0, 0.08), 2.4)
	_add_landmark_part(void_root, _cylinder_mesh(0.13, 0.13, 0.36), Vector3(0.0, 1.2, 0.0), Color("75dbff"), Vector3(PI * 0.5, 0.0, 0.0), 3.0)

	for frame_data in [[Vector3(-1.8, 0.0, 1.8), -0.12], [Vector3(1.8, 0.0, -1.8), 0.12]]:
		var frame := Node3D.new()
		frame.position = frame_data[0]
		frame.rotation.y = float(frame_data[1])
		add_child(frame)
		_add_landmark_part(frame, _box_mesh(Vector3(0.1, 4.0, 0.1)), Vector3(-0.75, 1.8, 0.0), Color("a7dced"))
		_add_landmark_part(frame, _box_mesh(Vector3(0.1, 4.0, 0.1)), Vector3(0.75, 1.8, 0.0), Color("f4a55e"))
		_add_landmark_part(frame, _box_mesh(Vector3(1.65, 0.1, 0.1)), Vector3(0.0, 3.72, 0.0), Color("dce9ef"), Vector3.ZERO, 0.8)
	_add_emissive_rail(Vector3(0.0, 0.065, -7.0), Vector3(25.0, 0.035, 0.035), Color("8bb8d5"))
	_add_emissive_rail(Vector3(0.0, 0.068, 7.0), Vector3(25.0, 0.035, 0.035), Color("d39a52"))

func _build_stormgates() -> void:
	if not _presentation_enabled:
		return
	_build_stormgate(SUN_GATE_POSITION, Color("ffb15c"), -1.0)
	_build_stormgate(VOID_GATE_POSITION, Color("75dbff"), 1.0)

func _build_stormgate(position: Vector3, color: Color, lean: float) -> void:
	var gate := Node3D.new()
	gate.name = "Stormgate"
	gate.position = position
	add_child(gate)
	_add_landmark_part(gate, _box_mesh(Vector3(0.12, 3.4, 0.12)), Vector3(-0.72, 1.7, 0.0), color, Vector3(0.0, 0.0, lean * 0.08), 0.8)
	_add_landmark_part(gate, _box_mesh(Vector3(0.12, 3.4, 0.12)), Vector3(0.72, 1.7, 0.0), color, Vector3(0.0, 0.0, -lean * 0.08), 0.8)
	_add_landmark_part(gate, _box_mesh(Vector3(1.55, 0.08, 0.08)), Vector3(0.0, 3.3, 0.0), color.lerp(Color("fff4c7"), 0.3), Vector3(0.0, 0.0, lean * 0.08), 1.4)
	_add_landmark_part(gate, _box_mesh(Vector3(0.05, 2.7, 0.05)), Vector3(0.0, 1.5, 0.0), color, Vector3(0.0, 0.0, lean * 0.02), 2.0)

func _add_landmark_part(parent: Node3D, mesh: Mesh, position: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO, glow: float = 0.0) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.material_override = _pulp_material(color, glow)
	parent.add_child(instance)

func _box_mesh(dimensions: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return mesh

func _cylinder_mesh(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	return mesh

func _add_solid_box(position: Vector3, dimensions: Vector3, color: Color, emission: float) -> void:
	var body := StaticBody3D.new()
	body.position = position
	add_child(body)
	if _presentation_enabled:
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = dimensions
		mesh_instance.mesh = box
		mesh_instance.material_override = _pulp_material(color, emission)
		body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)

func _add_emissive_rail(position: Vector3, dimensions: Vector3, color: Color) -> void:
	if not _presentation_enabled:
		return
	var rail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	rail.mesh = box
	rail.position = position
	rail.material_override = _pulp_material(color, 5.5)
	add_child(rail)

func _add_pulp_cylinder(position: Vector3, radius: float, height: float, color: Color) -> void:
	if not _presentation_enabled:
		return
	var cylinder := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	cylinder.mesh = mesh
	cylinder.position = position
	cylinder.material_override = _pulp_material(color, 0.0)
	add_child(cylinder)

func _pulp_material(color: Color, glow: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PULP_LIT
	material.set_shader_parameter("base_tint", color)
	material.set_shader_parameter("shadow_tint", Color("10213d").lerp(color, 0.2))
	material.set_shader_parameter("rim_tint", Color("dce9ef") if glow <= 0.0 else color)
	material.set_shader_parameter("rim_strength", 0.14 if glow <= 0.0 else 0.28)
	material.set_shader_parameter("glow_strength", glow)
	material.set_shader_parameter("brush_scale", 1.3)
	return material

func _read_capture_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--after="):
			_capture_after = maxf(0.2, argument.trim_prefix("--after=").to_float())
		elif argument == "--settings":
			_capture_settings = true
		elif argument == "--hud-layout":
			_capture_hud_layout = true
		elif argument == "--character":
			_capture_character = true
		elif argument == "--overview":
			_capture_overview = true
		elif argument == "--rift-link":
			_capture_rift_link = true
		elif argument.begins_with("--offline-squad="):
			var requested_size := argument.trim_prefix("--offline-squad=")
			if requested_size.is_valid_int() and requested_size.to_int() in [3, 5]:
				_offline_squad_size = requested_size.to_int()
		elif argument.begins_with("--squad-preview="):
			_squad_preview = argument.trim_prefix("--squad-preview=")
			if _squad_preview == "three-versus-three":
				_offline_squad_size = 3
		elif argument.begins_with("--objective-preview="):
			_objective_preview = argument.trim_prefix("--objective-preview=")
		elif argument.begins_with("--weapon-preview="):
			_weapon_preview = argument.trim_prefix("--weapon-preview=")
		elif argument.begins_with("--ballistics-preview="):
			_ballistics_preview = argument.trim_prefix("--ballistics-preview=")
		elif argument.begins_with("--touch-preview="):
			_touch_preview = argument.trim_prefix("--touch-preview=")
	if _capture_settings and hud != null:
		hud.open_settings()
	if _capture_hud_layout and hud != null:
		hud.open_hud_layout()
	if _capture_character and hud != null and _local_duelist != null:
		# This is a renderer-only inspection hook for silhouette review, not an alternate gameplay state.
		var preview_actor := _preview_actor()
		preview_actor.position = Vector3(-2.0, 0.1, 0.0)
		preview_actor.rotation.y = PI * 0.5
		_local_duelist.camera.cull_mask = 1
		_local_duelist.camera.global_position = Vector3(-8.0, 1.65, 0.0)
		_local_duelist.camera.look_at(preview_actor.global_position + Vector3.UP * 0.9)
		preview_actor.set_physics_process(false)
	if _capture_overview and hud != null and _local_duelist != null:
		# A renderer-only inspection hook that lets captures verify both spawn halves at once.
		_local_duelist.camera.cull_mask = 1
		_local_duelist.camera.global_position = Vector3(0.0, 31.0, 27.0)
		_local_duelist.camera.look_at(Vector3(0.0, 0.0, 0.0))
	if _capture_rift_link and hud != null:
		hud.set_connection_flow_active(true)
		rift_link.open_menu()
	if not _touch_preview.is_empty():
		hud.set_touch_preview(_touch_preview)

func _apply_objective_preview() -> void:
	if _lan_active or director == null or director.seed == null:
		return
	# Capture previews freeze only the rules tick and replace its presentation state; they cannot affect LAN authority.
	director.set_physics_process(false)
	var preview := director.objective_state()
	match _objective_preview:
		"sun-carried":
			preview = {"state": int(RiftSeed.State.CARRIED), "position": _local_duelist.global_position + Vector3.UP * RiftSeed.CARRIER_HEIGHT, "carrier_id": _local_duelist.actor_id, "carrier_team": int(Duelist.Team.SUN)}
		"void-carried":
			var void_actor := _actor_for_team(Duelist.Team.VOID)
			preview = {"state": int(RiftSeed.State.CARRIED), "position": void_actor.global_position + Vector3.UP * RiftSeed.CARRIER_HEIGHT, "carrier_id": void_actor.actor_id, "carrier_team": int(Duelist.Team.VOID)}
		"dropped":
			preview = {"state": int(RiftSeed.State.DROPPED), "position": Vector3(0.0, RiftSeed.HOME_HEIGHT, 0.0), "carrier_id": "", "carrier_team": -1}
		"sun-delivery", "void-delivery":
			preview = {"state": int(RiftSeed.State.HOME), "position": Vector3.ZERO + Vector3.UP * RiftSeed.HOME_HEIGHT, "carrier_id": "", "carrier_team": -1}
	director.seed.apply_presentation_state(preview, Callable(director, "_lookup_duelist"))
	hud.set_objective_state(preview)
	hud.set_match_phase(LinebreakMatch.Phase.LIVE)
	if _objective_preview.ends_with("-delivery"):
		var scoring_team := int(Duelist.Team.SUN) if _objective_preview.begins_with("sun") else int(Duelist.Team.VOID)
		var gate_position := VOID_GATE_POSITION if scoring_team == int(Duelist.Team.SUN) else SUN_GATE_POSITION
		hud.show_objective_event("objective_delivered", {"scoring_team": scoring_team, "gate_position": gate_position})

func _apply_weapon_preview() -> void:
	if _local_duelist == null or _weapon_preview.is_empty():
		return
	# Freeze only the capture fixture in a clean live HUD state; it does not alter match authority.
	if director != null:
		director.set_physics_process(false)
	if hud != null:
		hud.set_match_phase(LinebreakMatch.Phase.LIVE)
		hud.set_combat_input_enabled(true)
	match _weapon_preview:
		"carbine-hip":
			_local_duelist.set_weapon_presentation(Duelist.Weapon.PULSE)
			_local_duelist.set_combat_pose(false, 1.0)
		"carbine-ads":
			_local_duelist.set_weapon_presentation(Duelist.Weapon.PULSE)
			_local_duelist.set_combat_pose(true, 1.0)
		"carbine-world":
			var preview_actor := _preview_actor()
			_local_duelist.camera.cull_mask = 1
			preview_actor.position = Vector3(-2.5, 0.1, 0.0)
			preview_actor.rotation.y = PI * 0.5
			_local_duelist.camera.global_position = Vector3(-6.0, 1.7, 0.0)
			_local_duelist.camera.look_at(preview_actor.global_position + Vector3.UP * 0.95)
			preview_actor.set_physics_process(false)
		"scatter":
			_local_duelist.set_weapon_presentation(Duelist.Weapon.SCATTER)
			_local_duelist.set_combat_pose(false, 1.0)

func _apply_ballistics_preview() -> void:
	if _ballistics_preview.is_empty() or not _presentation_enabled or _local_duelist == null:
		return
	if director != null:
		director.set_physics_process(false)
	if hud != null:
		hud.set_match_phase(LinebreakMatch.Phase.LIVE)
		hud.set_combat_input_enabled(true)
	# These are capture-only presenter fixtures.  They never call RiftBallistics.fire,
	# never change health, and intentionally hold a record still so a 60ms live path
	# can be inspected in a screenshot without slowing the real projectile.
	var origin := _local_duelist.camera.global_position + -_local_duelist.camera.global_transform.basis.z * 0.7
	var direction := -_local_duelist.camera.global_transform.basis.z
	var fixture_direction := (direction + _local_duelist.camera.global_transform.basis.x * 0.7).normalized()
	match _ballistics_preview:
		"carbine-tracer":
			_show_capture_tracer(origin + fixture_direction * 0.45, fixture_direction, int(_local_duelist.team))
		"carbine-impact":
			_show_capture_impact(origin + direction * 0.35, -direction, _local_duelist.team, false)
		"carbine-burst":
			for distance in [0.4, 0.9, 1.4]:
				_show_capture_tracer(origin + fixture_direction * distance, fixture_direction, int(_local_duelist.team))

func _show_capture_tracer(position: Vector3, direction: Vector3, team_value: int) -> void:
	if _tracer_pool.is_empty():
		return
	var tracer := _tracer_pool[_tracer_cursor]
	_tracer_cursor = (_tracer_cursor + 1) % _tracer_pool.size()
	tracer.set_meta("token", int(tracer.get_meta("token", 0)) + 1)
	tracer.global_position = position
	tracer.look_at(position + direction, Vector3.UP)
	tracer.scale = Vector3(0.35, 0.35, 0.65)
	tracer.visible = true
	_set_projectile_color(tracer, Color("ffb15c") if team_value == int(Duelist.Team.SUN) else Color("75dbff"), 3.2)

func _show_capture_impact(point: Vector3, normal: Vector3, team: Duelist.Team, hit_duelist: bool) -> void:
	if _impact_pool.is_empty():
		return
	var impact := _impact_pool[_impact_cursor]
	_impact_cursor = (_impact_cursor + 1) % _impact_pool.size()
	impact.set_meta("token", int(impact.get_meta("token", 0)) + 1)
	impact.global_position = point
	impact.look_at(point + normal, Vector3.UP)
	impact.scale = Vector3.ONE * (0.8 if hit_duelist else 0.5)
	var ring := impact.get_child(2) as MeshInstance3D
	if ring != null:
		ring.visible = hit_duelist
	for child in impact.get_children():
		_set_projectile_color(child as MeshInstance3D, Color("ffb15c") if team == Duelist.Team.SUN else Color("75dbff"), 2.8)
	impact.visible = true

func _capture_after_delay() -> void:
	await get_tree().create_timer(_capture_after).timeout
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		push_error("Could not capture Riftline: viewport texture is unavailable")
		get_tree().quit()
		return
	var image := viewport_texture.get_image()
	var error := image.save_png(_capture_path)
	if error != OK:
		push_error("Could not write Riftline capture: %s" % _capture_path)
	get_tree().quit()
