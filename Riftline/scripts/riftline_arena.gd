class_name RiftlineArena
extends Node3D

const PULP_LIT := preload("res://shaders/pulp_lit.gdshader")
const SUN_COVER_SPAWN := Vector3(-15.0, 0.1, 6.0)
const VOID_COVER_SPAWN := Vector3(16.0, 0.1, -6.0)
const OPENING_HOLD_SECONDS := 2.5

var player: Duelist
var bot: BotDuelist
var remote_duelist: Duelist
var hud: DuelHud
var director: MatchDirector
var network: RiftlineNetwork
var rift_link: RiftLinkPanel
var _mouse_captured := false
var _lan_active := false
var _lan_host := false
var _lan_peer_id := 0
var _lan_peer_ready := false
var _lan_phase: MatchDirector.Phase = MatchDirector.Phase.OPENING
var _lan_tick := 0
var _local_input_sequence := 0
var _remote_input: Dictionary = {}
var _pending_inputs: Array[Dictionary] = []
var _remote_target_state: Dictionary = {}
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

func _ready() -> void:
	_build_environment()
	_build_arena()
	_build_match()
	_build_hud()
	_build_lan_flow()
	_read_capture_arguments()
	var command_line_lan := network.start_command_line_mode()
	if command_line_lan:
		_enter_lan_runtime(network.multiplayer.is_server(), false)
	else:
		director.begin()
	if not _capture_path.is_empty():
		_capture_after_delay()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if _lan_active:
		_tick_lan_duel(delta)
		return
	if hud.take_rematch():
		director.take_rematch()
	player.apply_look(hud.take_look_delta())
	if hud.gyro_enabled:
		var gyroscope := Input.get_gyroscope()
		player.apply_look(Vector2(gyroscope.y, -gyroscope.x) * 2.4)
	if not director.is_live() or not hud.can_drive_combat():
		# Non-live beats can still show the arena and accept camera look, but no combat intent survives into the next phase.
		hud.take_jump()
		hud.take_crouch()
		hud.take_prone()
		hud.take_weapon_switch()
		player.set_combat_pose(false, delta)
		player.drive(Vector2.ZERO, false, false, delta)
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement := hud.movement if hud.movement.length_squared() > 0.001 else keyboard
	if hud.take_crouch():
		player.toggle_crouch()
	if hud.take_prone():
		player.toggle_prone()
	if hud.take_weapon_switch():
		player.switch_weapon()
	player.set_combat_pose(hud.aim_held, delta)
	player.drive(movement, hud.fire_held or Input.is_action_pressed("fire"), hud.take_jump() or Input.is_action_just_pressed("jump"), delta)
	hud.set_stance(player.stance)
	hud.set_weapon(player.weapon)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_captured = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _mouse_captured:
		player.apply_look(event.relative)

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

func _build_match() -> void:
	director = MatchDirector.new()
	add_child(director)
	# Each duelist begins with its gray lane block between it and the center.
	# This makes the first action a deliberate peek rather than an instant sight-line.
	director.add_spawn(Duelist.Team.SUN, SUN_COVER_SPAWN)
	director.add_spawn(Duelist.Team.VOID, VOID_COVER_SPAWN)

	player = Duelist.new()
	player.name = "SunDuelist"
	player.build(Duelist.Team.SUN, true)
	player.position = SUN_COVER_SPAWN
	player.rotation.y = -PI * 0.5
	add_child(player)
	director.register_duelist(player)

	bot = BotDuelist.new()
	bot.name = "VoidDuelist"
	bot.build(Duelist.Team.VOID, false)
	bot.position = VOID_COVER_SPAWN
	bot.rotation.y = PI * 0.5
	bot.target = player
	bot.hold_opening_position(OPENING_HOLD_SECONDS)
	add_child(bot)
	director.register_duelist(bot)

	player.shot.connect(_show_shot)
	bot.shot.connect(_show_shot)
	player.damaged.connect(_on_player_damaged)
	director.score_changed.connect(_on_score_changed)
	director.phase_changed.connect(_on_phase_changed)
	director.match_finished.connect(_on_match_finished)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = DuelHud.new()
	layer.add_child(hud)
	hud.rift_link_requested.connect(_on_rift_link_requested)

func _build_lan_flow() -> void:
	network = RiftlineNetwork.new()
	add_child(network)
	network.session_status.connect(_on_network_status)
	network.host_discovered.connect(_on_host_discovered)
	network.peer_joined.connect(_on_network_peer_joined)
	network.peer_left.connect(_on_network_peer_left)
	network.input_received.connect(_on_network_input)
	network.snapshot_received.connect(_on_network_snapshot)
	network.reliable_event_received.connect(_on_network_event)

	var layer := CanvasLayer.new()
	add_child(layer)
	rift_link = RiftLinkPanel.new()
	layer.add_child(rift_link)
	rift_link.host_requested.connect(_on_host_requested)
	rift_link.join_requested.connect(_on_join_requested)
	rift_link.cancel_requested.connect(_on_rift_link_cancelled)
	rift_link.retry_requested.connect(_on_join_retry_requested)

func _on_player_damaged(_amount: float, remaining: float) -> void:
	hud.show_damage(remaining)

func _on_score_changed(sun: int, void_score: int) -> void:
	hud.set_score(sun, void_score)
	if _lan_host:
		network.publish_event({"type": "score", "sun": sun, "void": void_score})

func _on_match_finished(winner: Duelist.Team) -> void:
	hud.show_match_result(winner)
	if _lan_host:
		network.publish_event({"type": "finished", "winner": int(winner)})

func _on_phase_changed(phase: MatchDirector.Phase) -> void:
	_lan_phase = phase
	if phase != MatchDirector.Phase.LIVE:
		_remote_input.clear()
	hud.set_match_phase(phase)
	hud.set_combat_input_enabled(phase == MatchDirector.Phase.LIVE)
	if _lan_host:
		network.publish_event({"type": "phase", "phase": int(phase)})

func _show_shot(origin: Vector3, end: Vector3, team: Duelist.Team) -> void:
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = origin.distance_to(end)
	beam.mesh = mesh
	beam.material_override = _pulp_material(Color("ffb15c") if team == Duelist.Team.SUN else Color("75dbff"), 6.0)
	beam.position = origin.lerp(end, 0.5)
	add_child(beam)
	beam.look_at(end, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_remove_beam(beam)

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
	if status in ["LINK LOST", "LINK FAILED"] and _lan_active:
		_restore_offline_training(status)

func _on_host_discovered(_session: Dictionary) -> void:
	_join_discovery_started = true
	if rift_link != null and rift_link.visible:
		rift_link.set_discovered_session(true)

func _on_network_peer_joined(peer_id: int) -> void:
	if not _lan_active:
		return
	if _lan_host:
		_lan_peer_id = peer_id
	else:
		_lan_peer_id = peer_id
		_lan_peer_ready = true
		network.publish_event({"type": "ready"})

func _on_network_peer_left(_peer_id: int) -> void:
	if _lan_active:
		_restore_offline_training("LINK LOST")

func _on_network_input(peer_id: int, frame: Dictionary) -> void:
	if not _lan_active or not _lan_host or peer_id != _lan_peer_id or director == null or not director.is_live():
		return
	_remote_input = frame.duplicate(true)

func _on_network_snapshot(snapshot: Dictionary) -> void:
	if not _lan_active or _lan_host or snapshot.is_empty():
		return
	var players: Dictionary = snapshot.get("players", {})
	var local_state: Dictionary = players.get(_team_key(_local_team), {})
	if not local_state.is_empty():
		var acknowledged := int(local_state.get("last_input", -1))
		var remaining: Array[Dictionary] = []
		for frame in _pending_inputs:
			if int(frame.get("sequence", -1)) > acknowledged:
				remaining.append(frame)
		_pending_inputs = remaining
		player.reconcile_from_authority(local_state, _pending_inputs, 1.0 / 60.0)
	var remote_state: Dictionary = players.get(_team_key(_opposing_team()), {})
	if not remote_state.is_empty():
		_remote_target_state = remote_state.duplicate(true)
		if remote_duelist != null and remote_duelist.global_position == Vector3.ZERO:
			remote_duelist.apply_presentation_state(remote_state)
	hud.set_score(int(snapshot.get("sun_score", 0)), int(snapshot.get("void_score", 0)))

func _on_network_event(event: Dictionary, sender_id: int) -> void:
	if event.is_empty():
		return
	var event_type := str(event.get("type", ""))
	if _lan_host:
		if event_type == "ready" and sender_id == _lan_peer_id and not _lan_peer_ready:
			_lan_peer_ready = true
			_start_host_match()
		elif event_type == "rematch_request" and sender_id == _lan_peer_id and director != null:
			director.take_rematch()
		return
	match event_type:
		"phase":
			_apply_client_phase(int(event.get("phase", int(MatchDirector.Phase.OPENING))))
		"score":
			hud.set_score(int(event.get("sun", 0)), int(event.get("void", 0)))
		"finished":
			hud.show_match_result(int(event.get("winner", int(Duelist.Team.SUN))) as Duelist.Team)
		"defeat":
			_apply_client_defeat(int(event.get("victim", int(Duelist.Team.SUN))))
		"shot":
			_show_shot(event.get("origin", Vector3.ZERO), event.get("end", Vector3.ZERO), int(event.get("team", int(Duelist.Team.SUN))) as Duelist.Team)
		"spawn":
			_apply_client_spawn(int(event.get("team", int(Duelist.Team.SUN))))

func _enter_lan_runtime(host: bool, from_player_flow: bool) -> void:
	if _lan_active:
		return
	_lan_active = true
	_lan_host = host
	_lan_phase = MatchDirector.Phase.OPENING
	_lan_tick = 0
	_local_input_sequence = 0
	_remote_input = {}
	_pending_inputs.clear()
	_remote_target_state = {}
	_local_team = Duelist.Team.SUN if host else Duelist.Team.VOID
	_replace_match_for_lan(host)
	hud.set_connection_flow_active(false if not from_player_flow else true)
	if from_player_flow:
		# The panel remains up until the second human is ready, so the arena cannot consume stale touches.
		hud.set_combat_input_enabled(false)

func _replace_match_for_lan(host: bool) -> void:
	_clear_match_nodes()
	player = Duelist.new()
	player.name = "LocalDuelist"
	player.build(_local_team, true)
	player.position = SUN_COVER_SPAWN if _local_team == Duelist.Team.SUN else VOID_COVER_SPAWN
	player.rotation.y = -PI * 0.5 if _local_team == Duelist.Team.SUN else PI * 0.5
	add_child(player)
	remote_duelist = Duelist.new()
	remote_duelist.name = "RemoteDuelist"
	remote_duelist.build(_opposing_team(), false)
	remote_duelist.position = VOID_COVER_SPAWN if _local_team == Duelist.Team.SUN else SUN_COVER_SPAWN
	remote_duelist.rotation.y = PI * 0.5 if _local_team == Duelist.Team.SUN else -PI * 0.5
	add_child(remote_duelist)
	player.shot.connect(_on_authoritative_shot if host else _show_shot)
	player.damaged.connect(_on_player_damaged)
	if host:
		remote_duelist.shot.connect(_on_authoritative_shot)
		director = MatchDirector.new()
		add_child(director)
		director.add_spawn(Duelist.Team.SUN, SUN_COVER_SPAWN)
		director.add_spawn(Duelist.Team.VOID, VOID_COVER_SPAWN)
		director.register_duelist(player if _local_team == Duelist.Team.SUN else remote_duelist)
		director.register_duelist(remote_duelist if _local_team == Duelist.Team.SUN else player)
		director.score_changed.connect(_on_score_changed)
		director.phase_changed.connect(_on_phase_changed)
		director.match_finished.connect(_on_match_finished)
		director.respawn_started.connect(_on_lan_respawn_started)
		player.defeated.connect(_on_lan_defeat)
		remote_duelist.defeated.connect(_on_lan_defeat)
	else:
		director = null

func _clear_match_nodes() -> void:
	if director != null:
		director.queue_free()
	if bot != null:
		bot.queue_free()
	if player != null:
		player.queue_free()
	if remote_duelist != null:
		remote_duelist.queue_free()
	director = null
	bot = null
	player = null
	remote_duelist = null

func _start_host_match() -> void:
	if director == null or not _lan_peer_ready:
		return
	rift_link.hide_panel()
	hud.set_connection_flow_active(false)
	director.begin()
	network.publish_event({"type": "spawn", "team": int(Duelist.Team.SUN)})
	network.publish_event({"type": "spawn", "team": int(Duelist.Team.VOID)})

func _tick_lan_duel(delta: float) -> void:
	if player == null:
		return
	if hud.take_rematch():
		if _lan_host and director != null:
			director.take_rematch()
		elif not _lan_host:
			network.publish_event({"type": "rematch_request"})
	player.apply_look(hud.take_look_delta())
	if hud.gyro_enabled:
		var gyroscope := Input.get_gyroscope()
		player.apply_look(Vector2(gyroscope.y, -gyroscope.x) * 2.4)
	var live := director != null and director.is_live() if _lan_host else _lan_phase == MatchDirector.Phase.LIVE
	if not live or not hud.can_drive_combat():
		hud.take_jump()
		hud.take_crouch()
		hud.take_prone()
		hud.take_weapon_switch()
		player.set_combat_pose(false, delta)
		player.apply_input_frame({}, delta, false)
	else:
		var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var movement := hud.movement if hud.movement.length_squared() > 0.001 else keyboard
		var frame := player.make_input_frame(
			_local_input_sequence,
			movement,
			hud.aim_held,
			hud.fire_held or Input.is_action_pressed("fire"),
			hud.take_jump() or Input.is_action_just_pressed("jump"),
			hud.take_crouch(),
			hud.take_prone(),
			hud.take_weapon_switch())
		_local_input_sequence += 1
		player.set_combat_pose(bool(frame.aim), delta)
		if _lan_host:
			player.apply_input_frame(frame, delta, true)
			remote_duelist.apply_input_frame(_remote_input, delta, true)
		else:
			player.apply_input_frame(frame, delta, false)
			_pending_inputs.append(frame)
			network.send_input(frame)
	hud.set_stance(player.stance)
	hud.set_weapon(player.weapon)
	hud.show_damage(player.health)
	if not _lan_host and not _remote_target_state.is_empty() and remote_duelist != null:
		_smooth_remote_presentation(delta)
	if _lan_host:
		_lan_tick += 1
		_snapshot_remaining -= delta
		if _snapshot_remaining <= 0.0:
			_snapshot_remaining = 0.05
			_publish_lan_snapshot()

func _smooth_remote_presentation(delta: float) -> void:
	var target := _remote_target_state
	var presented := target.duplicate(true)
	var position: Vector3 = remote_duelist.global_position.lerp(target.get("position", remote_duelist.global_position), clampf(delta * 12.0, 0.0, 1.0))
	presented["position"] = position
	presented["yaw"] = lerp_angle(remote_duelist.rotation.y, float(target.get("yaw", remote_duelist.rotation.y)), clampf(delta * 12.0, 0.0, 1.0))
	presented["pitch"] = lerpf(remote_duelist.head.rotation.x, float(target.get("pitch", remote_duelist.head.rotation.x)), clampf(delta * 12.0, 0.0, 1.0))
	remote_duelist.apply_presentation_state(presented)

func _publish_lan_snapshot() -> void:
	if director == null or remote_duelist == null:
		return
	var host_duelist := player if _local_team == Duelist.Team.SUN else remote_duelist
	var join_duelist := remote_duelist if _local_team == Duelist.Team.SUN else player
	var snapshot := {
		"tick": _lan_tick,
		"phase": int(director.phase),
		"sun_score": int(director.scores[Duelist.Team.SUN]),
		"void_score": int(director.scores[Duelist.Team.VOID]),
		"players": {
			"sun": host_duelist.authoritative_state(_lan_tick, _last_sequence_for(host_duelist)),
			"void": join_duelist.authoritative_state(_lan_tick, _last_sequence_for(join_duelist)),
		},
	}
	network.publish_snapshot(snapshot)

func _last_sequence_for(duelist: Duelist) -> int:
	return _local_input_sequence - 1 if duelist == player else int(_remote_input.get("sequence", -1))

func _apply_client_phase(next_phase: int) -> void:
	_lan_phase = next_phase as MatchDirector.Phase
	hud.set_match_phase(_lan_phase)
	hud.set_combat_input_enabled(_lan_phase == MatchDirector.Phase.LIVE)
	player.set_match_active(_lan_phase == MatchDirector.Phase.LIVE)
	remote_duelist.set_match_active(_lan_phase == MatchDirector.Phase.LIVE)
	if _lan_phase == MatchDirector.Phase.LIVE:
		rift_link.hide_panel()
		hud.set_connection_flow_active(false)

func _on_authoritative_shot(origin: Vector3, end: Vector3, team: Duelist.Team) -> void:
	_show_shot(origin, end, team)
	network.publish_event({"type": "shot", "origin": origin, "end": end, "team": int(team)})

func _on_lan_defeat(victim: Duelist, killer: Duelist) -> void:
	if _lan_host:
		network.publish_event({"type": "defeat", "victim": int(victim.team), "killer": int(killer.team)})

func _on_lan_respawn_started(victim: Duelist) -> void:
	if _lan_host:
		network.publish_event({"type": "spawn", "team": int(victim.team)})

func _apply_client_defeat(team_value: int) -> void:
	var victim := player if team_value == int(_local_team) else remote_duelist
	if victim != null:
		victim.apply_presentation_state({"health": 0.0, "eliminated": true})

func _apply_client_spawn(team_value: int) -> void:
	var target_team := team_value as Duelist.Team
	var target := player if target_team == _local_team else remote_duelist
	if target == null:
		return
	var spawn := SUN_COVER_SPAWN if target_team == Duelist.Team.SUN else VOID_COVER_SPAWN
	target.apply_presentation_state({
		"position": spawn,
		"velocity": Vector3.ZERO,
		"yaw": -PI * 0.5 if target_team == Duelist.Team.SUN else PI * 0.5,
		"pitch": 0.0,
		"health": Duelist.HEALTH,
		"stance": int(Duelist.Stance.STAND),
		"weapon": int(Duelist.Weapon.PULSE),
		"eliminated": false,
	})
	if target == player:
		_pending_inputs.clear()

func _restore_offline_training(message: String) -> void:
	_lan_active = false
	_lan_host = false
	_lan_peer_ready = false
	_lan_peer_id = 0
	network.stop()
	rift_link.hide_panel()
	hud.set_connection_flow_active(false)
	_clear_match_nodes()
	_build_match()
	director.begin()
	hud.show_connection_message(message)

func _opposing_team() -> Duelist.Team:
	return Duelist.Team.VOID if _local_team == Duelist.Team.SUN else Duelist.Team.SUN

func _team_key(team: Duelist.Team) -> String:
	return "sun" if team == Duelist.Team.SUN else "void"

func _remove_beam(beam: MeshInstance3D) -> void:
	await get_tree().create_timer(0.055).timeout
	beam.queue_free()

func _add_solid_box(position: Vector3, dimensions: Vector3, color: Color, emission: float) -> void:
	var body := StaticBody3D.new()
	body.position = position
	add_child(body)
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
	var rail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	rail.mesh = box
	rail.position = position
	rail.material_override = _pulp_material(color, 5.5)
	add_child(rail)

func _add_pulp_cylinder(position: Vector3, radius: float, height: float, color: Color) -> void:
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
	if _capture_settings:
		hud.open_settings()
	if _capture_hud_layout:
		hud.open_hud_layout()
	if _capture_character:
		# This is a renderer-only inspection hook for silhouette review, not an alternate gameplay state.
		bot.position = Vector3(-6.0, 0.1, 0.0)
		bot.set_physics_process(false)
	if _capture_overview:
		# A renderer-only inspection hook that lets captures verify both spawn halves at once.
		player.camera.cull_mask = 1 | 2
		player.camera.global_position = Vector3(0.0, 31.0, 27.0)
		player.camera.look_at(Vector3(0.0, 0.0, 0.0))
	if _capture_rift_link:
		hud.set_connection_flow_active(true)
		rift_link.open_menu()

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
