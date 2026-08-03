class_name Duelist
extends CharacterBody3D

const PULP_LIT := preload("res://shaders/pulp_lit.gdshader")
const BALLISTICS := preload("res://scripts/rift_ballistics.gd")

signal defeated(victim: Duelist, killer: Duelist)
signal fire_requested(shooter: Duelist, weapon: Weapon, origin: Vector3, direction: Vector3)
signal scatter_shot(shooter_id: String, origin: Vector3, end: Vector3, team: Team, weapon: Weapon, hit_target: bool)
signal damaged(amount: float, remaining: float)

enum Team { SUN, VOID }
enum Stance { STAND, CROUCH, PRONE }
enum Weapon { PULSE, SCATTER }

const HEALTH := 100.0
const WALK_SPEED := 7.2
const M4_MAGAZINE_SIZE := 30
const M4_RESERVE_AMMO := 90
const M4_RELOAD_SECONDS := 1.55
const SCATTER_COOLDOWN := 0.72
const SCATTER_RANGE := 17.0
const SCATTER_DAMAGE := 13.0
const GRAVITY := 26.0
const JUMP_SPEED := 9.3
const CARRY_SPEED_MULTIPLIER := 0.88

var team: Team = Team.SUN
var actor_id := ""
var health := HEALTH
var eliminated := false
var carrying_seed := false
var stance: Stance = Stance.STAND
var weapon: Weapon = Weapon.PULSE
var magazine_rounds := M4_MAGAZINE_SIZE
var reserve_ammo := M4_RESERVE_AMMO
var reload_remaining := 0.0
var match_active := false
var _fire_remaining := 0.0
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _torso: MeshInstance3D
var _band: MeshInstance3D
var _body_visual_root: Node3D
var _weapon_root: Node3D
var _weapon_mesh: MeshInstance3D
var _weapon_core: MeshInstance3D
var _muzzle_flare: MeshInstance3D
var _rail_slots: Array[MeshInstance3D] = []
var _signal_spine: MeshInstance3D
var _survey_frame: MeshInstance3D
var _friendly_pennant: MeshInstance3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _pose_distance := 0.0
var _aiming := false
var _recoil_remaining := 0.0
var _fire_flash_remaining := 0.0
var _damage_flash_remaining := 0.0
var _local_camera := false
var _render_visuals := true
var _authoritative_collision := true
var _pending_jump := false

var head: Node3D
var camera: Camera3D

func build(assigned_team: Team, local_camera: bool, render_visuals: bool = true, authoritative_collision: bool = true) -> void:
	team = assigned_team
	_local_camera = local_camera
	_render_visuals = render_visuals
	_authoritative_collision = authoritative_collision
	collision_layer = 2 if authoritative_collision else 0
	collision_mask = 1 | 2

	_collision = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.48
	_capsule.height = 1.8
	_collision.shape = _capsule
	_collision.position.y = 0.9
	add_child(_collision)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.46, 0.0)
	add_child(head)

	if local_camera and _render_visuals:
		camera = Camera3D.new()
		camera.fov = 78.0
		# World silhouettes live on layer 1; the local view model gets its own layer so it never leaks to another client.
		camera.cull_mask = 1 | 2
		camera.current = true
		head.add_child(camera)

	if _render_visuals:
		if local_camera:
			_build_first_person_weapon()
		else:
			_build_character_silhouette()
			_build_world_weapon()
		_rebuild_weapon_models()

func set_actor_id(next_actor_id: String) -> void:
	actor_id = next_actor_id

func set_friendly_presenter(friendly: bool) -> void:
	if not _render_visuals or _local_camera or not friendly or _friendly_pennant != null:
		return
	_friendly_pennant = MeshInstance3D.new()
	var pennant_mesh := BoxMesh.new()
	pennant_mesh.size = Vector3(0.22, 0.12, 0.035)
	_friendly_pennant.mesh = pennant_mesh
	_friendly_pennant.position = Vector3(-0.4, 1.42, 0.05)
	_friendly_pennant.material_override = _material(_team_glow(), 0.42)
	_friendly_pennant.layers = 1
	add_child(_friendly_pennant)

func set_carrying_seed(carrying: bool) -> void:
	carrying_seed = carrying and not eliminated

func is_carrying_seed() -> bool:
	return carrying_seed and not eliminated

func movement_speed_multiplier() -> float:
	return CARRY_SPEED_MULTIPLIER if is_carrying_seed() else 1.0

func _process(delta: float) -> void:
	if not _render_visuals:
		return
	_pose_distance += Vector2(velocity.x, velocity.z).length() * delta
	_recoil_remaining = maxf(0.0, _recoil_remaining - delta)
	_fire_flash_remaining = maxf(0.0, _fire_flash_remaining - delta)
	_damage_flash_remaining = maxf(0.0, _damage_flash_remaining - delta)
	var moving := Vector2(velocity.x, velocity.z).length() > 0.35
	var gait := sin(_pose_distance * 1.35) if moving else 0.0
	var gait_lag := cos(_pose_distance * 1.35) if moving else 0.0
	var airborne := clampf(velocity.y / JUMP_SPEED, -1.0, 1.0)
	var firing_pose := clampf(_recoil_remaining / 0.22, 0.0, 1.0)
	if _torso != null:
		_torso.position.y = 1.03 + absf(gait) * (0.018 if moving else 0.0)
		_torso.rotation.z = gait_lag * (0.035 if moving else 0.0)
	if _band != null:
		_band.position.y = 1.18
		_band.scale = Vector3.ONE * (1.0 + (_damage_flash_remaining / 0.16) * 0.08)
	if _left_leg != null:
		_left_leg.rotation.x = gait * (0.17 if stance == Stance.STAND else 0.07)
	if _right_leg != null:
		_right_leg.rotation.x = -gait * (0.17 if stance == Stance.STAND else 0.07)
	if _left_arm != null:
		_left_arm.rotation.x = -gait * 0.09
		_left_arm.rotation.z = airborne * 0.08 - firing_pose * 0.05
	if _right_arm != null:
		_right_arm.rotation.x = gait * 0.09
		_right_arm.rotation.z = -airborne * 0.08 + firing_pose * 0.05
	if _survey_frame != null:
		_survey_frame.rotation.z = -gait_lag * 0.025
	if _weapon_root != null:
		var hip := Vector3(0.42, -0.42, -1.22)
		var ads := Vector3(0.0, -0.06, -0.96)
		var target := ads if _aiming and _local_camera else hip
		_weapon_root.position = _weapon_root.position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
		_weapon_root.rotation.x = lerpf(_weapon_root.rotation.x, -_recoil_remaining * (0.75 if weapon == Weapon.PULSE else 1.15), clampf(delta * 20.0, 0.0, 1.0))
	if _muzzle_flare != null:
		var flare := clampf(_fire_flash_remaining / 0.075, 0.0, 1.0)
		_muzzle_flare.scale = Vector3.ONE * flare
	if not _rail_slots.is_empty():
		var sequence := clampf((0.12 - _fire_flash_remaining) / 0.12 * 6.0, 0.0, 6.0)
		for index in _rail_slots.size():
			_set_material_glow(_rail_slots[index], 0.45 if index >= sequence else 1.2)
	_set_material_glow(_band, 1.35 if _damage_flash_remaining > 0.0 else 0.6)

func set_weapon_presentation(next_weapon: Weapon) -> void:
	var clamped := clampi(int(next_weapon), int(Weapon.PULSE), int(Weapon.SCATTER)) as Weapon
	if weapon == clamped and _weapon_mesh != null:
		return
	weapon = clamped
	_recoil_remaining = 0.0
	_fire_flash_remaining = 0.0
	_rebuild_weapon_models()

func play_local_weapon_fire(fired_weapon: Weapon) -> void:
	_play_weapon_fire(fired_weapon)

func play_remote_weapon_fire(fired_weapon: Weapon) -> void:
	_play_weapon_fire(fired_weapon)

func _play_weapon_fire(fired_weapon: Weapon) -> void:
	if not _render_visuals:
		return
	if weapon != fired_weapon:
		set_weapon_presentation(fired_weapon)
	_recoil_remaining = 0.12 if fired_weapon == Weapon.PULSE else 0.22
	_fire_flash_remaining = 0.075 if fired_weapon == Weapon.PULSE else 0.12
	if _weapon_core != null:
		_set_material_glow(_weapon_core, 5.0 if fired_weapon == Weapon.PULSE else 2.8)
	if _muzzle_flare != null:
		_set_material_glow(_muzzle_flare, 8.0 if fired_weapon == Weapon.PULSE else 4.0)

func apply_damage_presentation(_amount: float, _remaining: float) -> void:
	if not _render_visuals:
		return
	_damage_flash_remaining = 0.16
	_set_material_glow(_band, 1.35)

func apply_look(delta: Vector2) -> void:
	if eliminated:
		return
	rotate_y(-delta.x * 0.006)
	head.rotation.x = clampf(head.rotation.x - delta.y * 0.006, -1.05, 0.9)

func set_match_active(active: bool) -> void:
	match_active = active
	if not active:
		velocity.x = 0.0
		velocity.z = 0.0
		_fire_remaining = 0.0
		reload_remaining = 0.0
		_pending_jump = false

func make_input_frame(sequence: int, move_input: Vector2, aiming: bool, firing: bool, wants_jump: bool, crouch_edge: bool, prone_edge: bool, weapon_switch_edge: bool, reload_edge: bool) -> Dictionary:
	return {
		"sequence": sequence,
		"move_x": clampf(move_input.x, -1.0, 1.0),
		"move_y": clampf(move_input.y, -1.0, 1.0),
		"yaw": rotation.y,
		"pitch": head.rotation.x if head != null else 0.0,
		"aim": aiming,
		"fire": firing,
		"jump": wants_jump,
		"crouch": crouch_edge,
		"prone": prone_edge,
		"weapon_switch": weapon_switch_edge,
		"reload": reload_edge,
	}

func authoritative_state(server_tick: int, last_input_sequence: int) -> Dictionary:
	return {
		"tick": server_tick,
		"last_input": last_input_sequence,
		"position": global_position,
		"velocity": velocity,
		"yaw": rotation.y,
		"pitch": head.rotation.x if head != null else 0.0,
		"health": health,
		"magazine_rounds": magazine_rounds,
		"reserve_ammo": reserve_ammo,
		"reload_remaining": reload_remaining,
		"stance": int(stance),
		"weapon": int(weapon),
		"eliminated": eliminated,
		"carrying_seed": is_carrying_seed(),
	}

func apply_input_frame(frame: Dictionary, delta: float, simulate_combat: bool) -> void:
	if frame.is_empty():
		apply_continuous_input({}, delta, simulate_combat)
		return
	if eliminated or not match_active:
		apply_continuous_input({}, delta, false)
		return
	apply_discrete_input(frame)
	apply_continuous_input(frame, delta, simulate_combat)

func apply_discrete_input(frame: Dictionary) -> void:
	if frame.is_empty() or eliminated or not match_active:
		return
	if bool(frame.get("crouch", false)):
		toggle_crouch()
	if bool(frame.get("prone", false)):
		toggle_prone()
	if bool(frame.get("weapon_switch", false)):
		switch_weapon()
	if bool(frame.get("reload", false)):
		reload_weapon()
	if bool(frame.get("jump", false)):
		_pending_jump = true

func apply_continuous_input(frame: Dictionary, delta: float, simulate_combat: bool) -> void:
	if eliminated or not match_active:
		_pending_jump = false
		_simulate_motion(Vector2.ZERO, false, delta)
		return
	# Absolute look values make a frame replayable after a correction and remove peer-specific mouse deltas.
	if not frame.is_empty():
		rotation.y = float(frame.get("yaw", rotation.y))
		if head != null:
			head.rotation.x = clampf(float(frame.get("pitch", head.rotation.x)), -1.05, 0.9)
	var move_input := Vector2(float(frame.get("move_x", 0.0)), float(frame.get("move_y", 0.0))) if not frame.is_empty() else Vector2.ZERO
	var wants_jump := _pending_jump
	_pending_jump = false
	_simulate_motion(move_input, wants_jump, delta)
	if not frame.is_empty() and bool(frame.get("fire", false)) and simulate_combat:
		fire_forward()

func apply_presentation_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	# Presentation state is deliberately side-effect free: it cannot raycast, damage, score, or change phase.
	global_position = state.get("position", global_position)
	velocity = state.get("velocity", Vector3.ZERO)
	rotation.y = float(state.get("yaw", rotation.y))
	if head != null:
		head.rotation.x = clampf(float(state.get("pitch", head.rotation.x)), -1.05, 0.9)
	health = clampf(float(state.get("health", health)), 0.0, HEALTH)
	magazine_rounds = clampi(int(state.get("magazine_rounds", magazine_rounds)), 0, M4_MAGAZINE_SIZE)
	reserve_ammo = clampi(int(state.get("reserve_ammo", reserve_ammo)), 0, M4_RESERVE_AMMO)
	reload_remaining = maxf(0.0, float(state.get("reload_remaining", reload_remaining)))
	var next_stance := clampi(int(state.get("stance", int(stance))), int(Stance.STAND), int(Stance.PRONE))
	if stance != next_stance:
		_apply_stance(next_stance as Stance)
	var next_weapon := clampi(int(state.get("weapon", int(weapon))), int(Weapon.PULSE), int(Weapon.SCATTER))
	if weapon != next_weapon:
		set_weapon_presentation(next_weapon as Weapon)
	eliminated = bool(state.get("eliminated", eliminated))
	set_carrying_seed(bool(state.get("carrying_seed", carrying_seed)))
	visible = not eliminated
	collision_layer = 0 if eliminated or not _authoritative_collision else 2

func reconcile_from_authority(state: Dictionary, unacknowledged_frames: Array, delta: float) -> void:
	if state.is_empty():
		return
	var server_position: Vector3 = state.get("position", global_position)
	var position_error := global_position.distance_to(server_position)
	var server_yaw := float(state.get("yaw", rotation.y))
	var yaw_error := absf(angle_difference(rotation.y, server_yaw))
	# Small errors are hidden by a short blend; large errors need an immediate authoritative reset.
	var corrected := state.duplicate(true)
	_pending_jump = false
	if position_error <= 0.8 and yaw_error <= 0.22:
		corrected["position"] = global_position.lerp(server_position, clampf(delta * 10.0, 0.0, 1.0))
		corrected["yaw"] = lerp_angle(rotation.y, server_yaw, clampf(delta * 10.0, 0.0, 1.0))
	apply_presentation_state(corrected)
	for frame in unacknowledged_frames:
		if frame is Dictionary:
			_apply_replay_frame(frame, delta)

func _apply_replay_frame(frame: Dictionary, delta: float) -> void:
	if eliminated or not match_active:
		return
	apply_discrete_input(frame)
	apply_continuous_input(frame, delta, false)

func _simulate_motion(move_input: Vector2, wants_jump: bool, delta: float) -> void:
	_fire_remaining = maxf(0.0, _fire_remaining - delta)
	if reload_remaining > 0.0:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= 0.0:
			var transfer := mini(M4_MAGAZINE_SIZE - magazine_rounds, reserve_ammo)
			magazine_rounds += transfer
			reserve_ammo -= transfer
	if eliminated or not match_active:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var desired := right * move_input.x + forward * -move_input.y
	if desired.length_squared() > 1.0:
		desired = desired.normalized()
	var stance_speed := 1.0 if stance == Stance.STAND else 0.62 if stance == Stance.CROUCH else 0.3
	var speed := WALK_SPEED * stance_speed * movement_speed_multiplier()
	velocity.x = move_toward(velocity.x, desired.x * speed, WALK_SPEED * 12.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z * speed, WALK_SPEED * 12.0 * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = JUMP_SPEED if wants_jump and stance != Stance.PRONE else -0.1
	move_and_slide()

func set_stance(next_stance: Stance) -> void:
	if eliminated or not match_active or stance == next_stance:
		return
	_apply_stance(next_stance)

func _apply_stance(next_stance: Stance) -> void:
	stance = next_stance
	var body_height := 1.8
	var body_radius := 0.48
	match stance:
		Stance.CROUCH:
			body_height = 1.18
			body_radius = 0.42
		Stance.PRONE:
			body_height = 0.68
			body_radius = 0.32
	_capsule.height = body_height
	_capsule.radius = body_radius
	_collision.position.y = body_height * 0.5
	if _body_visual_root != null:
		_body_visual_root.scale.y = body_height / 1.8
	head.position.y = body_height - 0.34

func toggle_crouch() -> void:
	set_stance(Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH)

func toggle_prone() -> void:
	set_stance(Stance.STAND if stance == Stance.PRONE else Stance.PRONE)

func set_combat_pose(aiming: bool, delta: float) -> void:
	if eliminated:
		return
	_aiming = aiming
	if camera != null:
		camera.fov = lerpf(camera.fov, 56.0 if aiming else 78.0, minf(1.0, delta * 13.0))

func drive(move_input: Vector2, wants_fire: bool, wants_jump: bool, delta: float) -> void:
	if eliminated or not match_active:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	_simulate_motion(move_input, wants_jump, delta)

	if wants_fire:
		fire_forward()

func fire_forward() -> void:
	if eliminated or not match_active or _fire_remaining > 0.0 or reload_remaining > 0.0:
		return
	if weapon == Weapon.PULSE and magazine_rounds <= 0:
		reload_weapon()
		return
	_fire_remaining = BALLISTICS.M4_FIRE_INTERVAL if weapon == Weapon.PULSE else SCATTER_COOLDOWN
	var origin := _fire_origin()
	var direction := -head.global_transform.basis.z
	if weapon == Weapon.PULSE:
		magazine_rounds -= 1
		fire_requested.emit(self, weapon, origin, direction)
		return
	_fire_scatter(origin, direction)

func fire_at(target: Vector3) -> void:
	if eliminated or not match_active or _fire_remaining > 0.0 or reload_remaining > 0.0:
		return
	if weapon == Weapon.PULSE and magazine_rounds <= 0:
		reload_weapon()
		return
	_fire_remaining = BALLISTICS.M4_FIRE_INTERVAL if weapon == Weapon.PULSE else SCATTER_COOLDOWN
	var origin := _fire_origin()
	var direction := (target - origin).normalized()
	if weapon == Weapon.PULSE:
		magazine_rounds -= 1
		fire_requested.emit(self, weapon, origin, direction)
		return
	_fire_scatter(origin, direction)

func switch_weapon() -> void:
	if eliminated or not match_active:
		return
	set_weapon_presentation(Weapon.SCATTER if weapon == Weapon.PULSE else Weapon.PULSE)

func reload_weapon() -> bool:
	if eliminated or not match_active or weapon != Weapon.PULSE or reload_remaining > 0.0:
		return false
	if magazine_rounds >= M4_MAGAZINE_SIZE or reserve_ammo <= 0:
		return false
	reload_remaining = M4_RELOAD_SECONDS
	_fire_remaining = maxf(_fire_remaining, 0.12)
	return true

func take_damage(amount: float, attacker: Duelist) -> void:
	if eliminated or not match_active:
		return
	health = maxf(0.0, health - amount)
	apply_damage_presentation(amount, health)
	damaged.emit(amount, health)
	if health <= 0.0:
		eliminated = true
		visible = false
		collision_layer = 0
		defeated.emit(self, attacker)

func respawn_at(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	health = HEALTH
	eliminated = false
	carrying_seed = false
	visible = true
	collision_layer = 2
	_aiming = false
	_recoil_remaining = 0.0
	_fire_flash_remaining = 0.0
	magazine_rounds = M4_MAGAZINE_SIZE
	reserve_ammo = M4_RESERVE_AMMO
	reload_remaining = 0.0
	_damage_flash_remaining = 0.0
	set_weapon_presentation(Weapon.PULSE)
	_apply_stance(Stance.STAND)

func _fire_origin() -> Vector3:
	if is_instance_valid(_muzzle_flare):
		return _muzzle_flare.global_position
	return head.global_position + -head.global_transform.basis.z * 0.46

func _fire_scatter(origin: Vector3, direction: Vector3) -> void:
	# The scatter weapon intentionally keeps its existing close-range ray behavior.
	for spread in [Vector2(-0.07, -0.035), Vector2(-0.035, 0.05), Vector2(0.0, 0.0), Vector2(0.04, -0.045), Vector2(0.075, 0.025)]:
		var pellet: Vector3 = (direction + head.global_transform.basis.x * spread.x + head.global_transform.basis.y * spread.y).normalized()
		_fire_scatter_ray(origin, pellet, SCATTER_DAMAGE, SCATTER_RANGE)

func _fire_scatter_ray(origin: Vector3, direction: Vector3, damage: float, range: float) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range, 1 | 2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := origin + direction * range
	var hit_target := false
	if not hit.is_empty():
		end = hit.position
		var collider: Object = hit.collider
		if collider is Duelist and collider != self and collider.team != team:
			hit_target = true
			collider.take_damage(damage, self)
	scatter_shot.emit(actor_id, origin, end, team, weapon, hit_target)

func _team_color() -> Color:
	return Color("ef6b3f") if team == Team.SUN else Color("4ba9ff")

func _team_glow() -> Color:
	return Color("ffb15c") if team == Team.SUN else Color("7bdbff")

func _build_character_silhouette() -> void:
	# Broad value groups and one asymmetric expedition tool make the adult frame readable without armor language.
	_body_visual_root = Node3D.new()
	_body_visual_root.name = "ExpeditionSilhouette"
	add_child(_body_visual_root)
	var cloth := _material(_team_color(), 0.0)
	var dark := _material(Color("17263e"), 0.0)
	var brass := _material(Color("d6ad67"), 0.0)
	var glow := _material(_team_glow(), 1.4)
	_torso = _add_body_part(_box(Vector3(0.68, 0.92, 0.42)), Vector3(0.0, 1.03, 0.03), cloth)
	_left_leg = _add_body_part(_cylinder(0.15, 0.17, 0.76), Vector3(-0.19, 0.37, 0.02), dark, Vector3(0.0, 0.0, 0.02))
	_right_leg = _add_body_part(_cylinder(0.15, 0.17, 0.76), Vector3(0.19, 0.37, 0.02), dark, Vector3(0.0, 0.0, -0.02))
	_left_arm = _add_body_part(_cylinder(0.11, 0.12, 0.72), Vector3(-0.48, 1.08, 0.0), cloth, Vector3(0.0, 0.0, -0.2))
	_right_arm = _add_body_part(_cylinder(0.11, 0.12, 0.72), Vector3(0.48, 1.08, 0.0), cloth, Vector3(0.0, 0.0, 0.2))
	_band = _add_body_part(_cylinder(0.51, 0.51, 0.13), Vector3(0.0, 1.18, 0.0), glow)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.52
	_add_head_part(head_mesh, Vector3.ZERO, dark)
	_add_head_part(_cylinder(0.33, 0.33, 0.08), Vector3(0.0, 0.22, 0.0), cloth)
	_add_head_part(_box(Vector3(0.38, 0.1, 0.08)), Vector3(0.0, 0.0, -0.24), brass)

	if team == Team.SUN:
		_build_signal_hauler(cloth, dark, brass, glow)
	else:
		_build_storm_surveyor(cloth, dark, brass, glow)

func _build_signal_hauler(cloth: Material, dark: Material, brass: Material, glow: Material) -> void:
	# Rejected alternative: a symmetrical chest rig. The offset coat panel and forked aerial give the courier forward motion.
	_add_body_part(_box(Vector3(0.66, 0.7, 0.09)), Vector3(-0.08, 0.91, -0.37), cloth, Vector3(0.0, 0.0, 0.08))
	_signal_spine = _add_body_part(_box(Vector3(0.12, 0.78, 0.16)), Vector3(0.0, 1.16, 0.34), dark)
	_add_body_part(_box(Vector3(0.1, 0.5, 0.12)), Vector3(-0.32, 1.18, 0.33), brass, Vector3(0.0, 0.0, 0.2))
	_add_body_part(_box(Vector3(0.08, 0.38, 0.08)), Vector3(0.0, 1.72, 0.36), brass, Vector3(0.0, 0.0, -0.28))
	_add_body_part(_box(Vector3(0.42, 0.06, 0.08)), Vector3(0.0, 1.88, 0.36), brass, Vector3(0.0, 0.0, 0.18))
	_add_body_part(_cylinder(0.13, 0.13, 0.38), Vector3(0.0, 1.17, -0.43), glow, Vector3(PI * 0.5, 0.0, 0.0))

func _build_storm_surveyor(cloth: Material, dark: Material, brass: Material, glow: Material) -> void:
	# Rejected alternative: a tall hood. The lateral mantle and folded wind-array frame read as precise survey gear.
	_add_body_part(_cylinder(0.16, 0.43, 0.82), Vector3(0.0, 0.88, -0.02), cloth)
	_add_body_part(_box(Vector3(0.92, 0.12, 0.26)), Vector3(0.0, 1.36, 0.36), cloth, Vector3(0.0, 0.0, 0.08))
	_survey_frame = _add_body_part(_box(Vector3(0.08, 0.92, 0.36)), Vector3(0.0, 1.37, 0.47), dark, Vector3(0.0, 0.0, 0.16))
	_add_body_part(_box(Vector3(0.82, 0.08, 0.16)), Vector3(0.0, 1.62, 0.48), brass, Vector3(0.0, 0.0, 0.11))
	_add_body_part(_box(Vector3(0.52, 0.05, 0.11)), Vector3(0.0, 1.87, 0.48), brass, Vector3(0.0, 0.0, -0.18))
	_add_body_part(_cylinder(0.1, 0.1, 0.28), Vector3(0.0, 1.1, -0.43), glow, Vector3(PI * 0.5, 0.0, 0.0))

func _build_first_person_weapon() -> void:
	_weapon_root = Node3D.new()
	_weapon_root.name = "FirstPersonWeapon"
	_weapon_root.position = Vector3(0.42, -0.42, -1.22)
	_weapon_root.scale = Vector3.ONE * 0.38
	camera.add_child(_weapon_root)

func _build_world_weapon() -> void:
	_weapon_root = Node3D.new()
	_weapon_root.name = "WorldWeapon"
	_weapon_root.position = Vector3(0.38, -0.27, -0.64)
	_weapon_root.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
	_weapon_root.scale = Vector3.ONE * 0.72
	head.add_child(_weapon_root)

func _rebuild_weapon_models() -> void:
	if _weapon_root == null:
		return
	for child in _weapon_root.get_children():
		child.queue_free()
	_weapon_mesh = null
	_weapon_core = null
	_muzzle_flare = null
	_rail_slots.clear()
	var ceramic := _material(Color("3f4b55") if weapon == Weapon.PULSE else Color("687386"), 0.08)
	var dark := _material(Color("17263e"), 0.0)
	var accent := _material(Color("e6a25b") if weapon == Weapon.PULSE else Color("b479ff"), 0.6)
	var hot := _material(Color("fff0b0") if weapon == Weapon.PULSE else Color("d3b2ff"), 3.2)
	if weapon == Weapon.PULSE:
		# Original Rift Carbine silhouette: stock, split receiver, rail handguard, magazine, barrel, sights.
		_weapon_mesh = _add_weapon_part(_box(Vector3(0.30, 0.20, 0.44)), Vector3(0.0, 0.0, 0.06), ceramic)
		_add_weapon_part(_box(Vector3(0.28, 0.13, 0.48)), Vector3(0.0, 0.10, -0.29), dark)
		_add_weapon_part(_box(Vector3(0.035, 0.11, 0.23)), Vector3(0.16, 0.04, -0.17), dark)
		var buffer_tube := _add_weapon_part(_cylinder(0.055, 0.055, 0.45), Vector3(0.0, 0.05, 0.52), dark, Vector3(PI * 0.5, 0.0, 0.0))
		buffer_tube.scale.x = 0.9
		_add_weapon_part(_box(Vector3(0.22, 0.16, 0.32)), Vector3(0.0, 0.05, 0.86), ceramic)
		_add_weapon_part(_box(Vector3(0.24, 0.18, 0.07)), Vector3(0.0, 0.05, 1.03), dark)
		_add_weapon_part(_box(Vector3(0.14, 0.28, 0.16)), Vector3(0.0, -0.21, 0.23), dark, Vector3(-0.18, 0.0, 0.0))
		_add_weapon_part(_box(Vector3(0.15, 0.32, 0.18)), Vector3(0.0, -0.23, -0.04), ceramic, Vector3(-0.12, 0.0, 0.0))
		_add_weapon_part(_box(Vector3(0.18, 0.05, 0.20)), Vector3(0.0, -0.40, -0.04), dark)
		_add_weapon_part(_box(Vector3(0.24, 0.17, 0.70)), Vector3(0.0, 0.03, -0.72), ceramic)
		_add_weapon_part(_box(Vector3(0.27, 0.045, 0.72)), Vector3(0.0, 0.14, -0.72), dark)
		for index in 6:
			_rail_slots.append(_add_weapon_part(_box(Vector3(0.29, 0.035, 0.055)), Vector3(0.0, 0.18, -0.42 - index * 0.12), dark))
		_add_weapon_part(_box(Vector3(0.27, 0.09, 0.12)), Vector3(0.0, 0.02, -1.10), dark)
		_add_weapon_part(_cylinder(0.035, 0.035, 0.52), Vector3(0.0, 0.02, -1.28), dark, Vector3(PI * 0.5, 0.0, 0.0))
		_add_weapon_part(_cylinder(0.067, 0.067, 0.13), Vector3(0.0, 0.02, -1.57), ceramic, Vector3(PI * 0.5, 0.0, 0.0))
		_add_weapon_part(_box(Vector3(0.05, 0.12, 0.10)), Vector3(0.0, 0.22, -0.24), dark)
		_add_weapon_part(_box(Vector3(0.055, 0.15, 0.09)), Vector3(0.0, 0.22, -1.06), dark)
		# A small team-neutral signal component is the only warm accent on the carbine.
		_weapon_core = _add_weapon_part(_box(Vector3(0.10, 0.08, 0.14)), Vector3(0.16, 0.08, -0.54), accent)
		_muzzle_flare = _add_weapon_part(_box(Vector3(0.11, 0.11, 0.16)), Vector3(0.0, 0.02, -1.65), hot)
	else:
		_weapon_mesh = _add_weapon_part(_box(Vector3(0.27, 0.25, 0.58)), Vector3(0.0, 0.0, 0.05), ceramic)
		_add_weapon_part(_box(Vector3(0.34, 0.12, 0.32)), Vector3(0.0, 0.0, -0.32), dark, Vector3(0.0, 0.0, 0.12))
		_weapon_core = _add_weapon_part(_cylinder(0.045, 0.045, 0.2), Vector3(0.0, 0.0, -0.46), hot, Vector3(PI * 0.5, 0.0, 0.0))
		for index in 5:
			_rail_slots.append(_add_weapon_part(_cylinder(0.026, 0.026, 0.1), Vector3(-0.1 + index * 0.05, -0.15, -0.23), accent, Vector3(PI * 0.5, 0.0, 0.0)))
		_add_weapon_part(_box(Vector3(0.07, 0.3, 0.08)), Vector3(0.14, 0.0, -0.04), accent, Vector3(0.0, 0.0, 0.32))
		_muzzle_flare = _add_weapon_part(_box(Vector3(0.18, 0.18, 0.08)), Vector3(0.0, 0.0, -0.65), hot)
	_muzzle_flare.scale = Vector3.ONE * 0.001

func _add_weapon_part(mesh: Mesh, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.material_override = material
	instance.layers = 2 if _local_camera else 1
	_weapon_root.add_child(instance)
	return instance

func _add_body_part(mesh: Mesh, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.material_override = material
	instance.layers = 1
	if _body_visual_root != null:
		_body_visual_root.add_child(instance)
	else:
		add_child(instance)
	return instance

func _add_head_part(mesh: Mesh, position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	head.add_child(instance)

func _box(dimensions: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	return mesh

func _cylinder(top_radius: float, bottom_radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	return mesh

func _material(color: Color, emission_energy: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PULP_LIT
	material.set_shader_parameter("base_tint", color)
	material.set_shader_parameter("shadow_tint", Color("16253d").lerp(color, 0.2))
	material.set_shader_parameter("rim_tint", _team_glow())
	material.set_shader_parameter("rim_strength", 0.24)
	material.set_shader_parameter("glow_strength", emission_energy)
	material.set_shader_parameter("brush_scale", 2.4)
	return material

func _set_material_glow(instance: MeshInstance3D, glow: float) -> void:
	if instance == null or not (instance.material_override is ShaderMaterial):
		return
	(instance.material_override as ShaderMaterial).set_shader_parameter("glow_strength", glow)
