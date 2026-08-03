class_name Duelist
extends CharacterBody3D

const PULP_LIT := preload("res://shaders/pulp_lit.gdshader")

signal defeated(victim: Duelist, killer: Duelist)
signal shot(origin: Vector3, end: Vector3, team: Team)
signal damaged(amount: float, remaining: float)

enum Team { SUN, VOID }
enum Stance { STAND, CROUCH, PRONE }
enum Weapon { PULSE, SCATTER }

const HEALTH := 100.0
const WALK_SPEED := 7.2
const FIRE_COOLDOWN := 0.26
const FIRE_RANGE := 48.0
# Four rifle hits leave eight health, so a clean five-hit exchange decides a duel.
const FIRE_DAMAGE := 23.0
const GRAVITY := 26.0
const JUMP_SPEED := 9.3

var team: Team = Team.SUN
var health := HEALTH
var eliminated := false
var stance: Stance = Stance.STAND
var weapon: Weapon = Weapon.PULSE
var match_active := false
var _fire_remaining := 0.0
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _torso: MeshInstance3D
var _band: MeshInstance3D
var _weapon_mesh: MeshInstance3D
var _local_camera := false

var head: Node3D
var camera: Camera3D

func build(assigned_team: Team, local_camera: bool) -> void:
	team = assigned_team
	_local_camera = local_camera
	collision_layer = 2
	collision_mask = 1 | 2

	_collision = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.48
	_capsule.height = 1.8
	_collision.shape = _capsule
	_collision.position.y = 0.9
	add_child(_collision)

	_torso = MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.66, 0.98, 0.42)
	_torso.mesh = torso_mesh
	_torso.position.y = 1.1
	_torso.material_override = _material(_team_color(), 0.07)
	_torso.layers = 2 if _local_camera else 1
	add_child(_torso)

	# The bright band makes opponents readable against the dark arena before any HUD is learned.
	_band = MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.51
	band_mesh.bottom_radius = 0.51
	band_mesh.height = 0.13
	_band.mesh = band_mesh
	_band.position.y = 1.18
	_band.material_override = _material(_team_glow(), 0.6)
	_band.layers = 2 if _local_camera else 1
	add_child(_band)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.46, 0.0)
	add_child(head)

	_weapon_mesh = MeshInstance3D.new()
	var weapon_mesh := BoxMesh.new()
	weapon_mesh.size = Vector3(0.13, 0.12, 0.56)
	_weapon_mesh.mesh = weapon_mesh
	_weapon_mesh.position = Vector3(0.38, -0.3, -0.82)
	_weapon_mesh.material_override = _material(Color("304769"), 0.35)
	head.add_child(_weapon_mesh)

	if local_camera:
		camera = Camera3D.new()
		camera.fov = 78.0
		camera.cull_mask = 1
		camera.current = true
		head.add_child(camera)

	_build_character_silhouette(local_camera)

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

func make_input_frame(sequence: int, move_input: Vector2, aiming: bool, firing: bool, wants_jump: bool, crouch_edge: bool, prone_edge: bool, weapon_switch_edge: bool) -> Dictionary:
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
		"stance": int(stance),
		"weapon": int(weapon),
		"eliminated": eliminated,
	}

func apply_input_frame(frame: Dictionary, delta: float, simulate_combat: bool) -> void:
	if frame.is_empty():
		_simulate_motion(Vector2.ZERO, false, delta)
		return
	if eliminated or not match_active:
		_simulate_motion(Vector2.ZERO, false, delta)
		return
	# Absolute look values make a frame replayable after a correction and remove peer-specific mouse deltas.
	rotation.y = float(frame.get("yaw", rotation.y))
	if head != null:
		head.rotation.x = clampf(float(frame.get("pitch", head.rotation.x)), -1.05, 0.9)
	if bool(frame.get("crouch", false)):
		toggle_crouch()
	if bool(frame.get("prone", false)):
		toggle_prone()
	if bool(frame.get("weapon_switch", false)):
		switch_weapon()
	_simulate_motion(Vector2(float(frame.get("move_x", 0.0)), float(frame.get("move_y", 0.0))), bool(frame.get("jump", false)), delta)
	if bool(frame.get("fire", false)):
		if simulate_combat:
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
	var next_stance := clampi(int(state.get("stance", int(stance))), int(Stance.STAND), int(Stance.PRONE))
	if stance != next_stance:
		_apply_stance(next_stance as Stance)
	var next_weapon := clampi(int(state.get("weapon", int(weapon))), int(Weapon.PULSE), int(Weapon.SCATTER))
	if weapon != next_weapon:
		weapon = next_weapon as Weapon
		_update_weapon_mesh()
	eliminated = bool(state.get("eliminated", eliminated))
	visible = not eliminated
	collision_layer = 0 if eliminated else 2

func reconcile_from_authority(state: Dictionary, unacknowledged_frames: Array, delta: float) -> void:
	if state.is_empty():
		return
	var server_position: Vector3 = state.get("position", global_position)
	var position_error := global_position.distance_to(server_position)
	var server_yaw := float(state.get("yaw", rotation.y))
	var yaw_error := absf(angle_difference(rotation.y, server_yaw))
	# Small errors are hidden by a short blend; large errors need an immediate authoritative reset.
	var corrected := state.duplicate(true)
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
	rotation.y = float(frame.get("yaw", rotation.y))
	if head != null:
		head.rotation.x = clampf(float(frame.get("pitch", head.rotation.x)), -1.05, 0.9)
	if bool(frame.get("crouch", false)):
		toggle_crouch()
	if bool(frame.get("prone", false)):
		toggle_prone()
	if bool(frame.get("weapon_switch", false)):
		# Replaying a correction must not invoke any combat effect.
		weapon = Weapon.SCATTER if weapon == Weapon.PULSE else Weapon.PULSE
		_update_weapon_mesh()
	_simulate_motion(Vector2(float(frame.get("move_x", 0.0)), float(frame.get("move_y", 0.0))), bool(frame.get("jump", false)), delta)

func _simulate_motion(move_input: Vector2, wants_jump: bool, delta: float) -> void:
	_fire_remaining = maxf(0.0, _fire_remaining - delta)
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
	velocity.x = move_toward(velocity.x, desired.x * WALK_SPEED * stance_speed, WALK_SPEED * 12.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z * WALK_SPEED * stance_speed, WALK_SPEED * 12.0 * delta)
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
	_torso.position.y = body_height * 0.61
	_torso.scale.y = body_height / 1.75
	_band.position.y = body_height * 0.63
	head.position.y = body_height - 0.34

func toggle_crouch() -> void:
	set_stance(Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH)

func toggle_prone() -> void:
	set_stance(Stance.STAND if stance == Stance.PRONE else Stance.PRONE)

func set_combat_pose(aiming: bool, delta: float) -> void:
	if eliminated:
		return
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
	if eliminated or not match_active or _fire_remaining > 0.0:
		return
	_fire_remaining = FIRE_COOLDOWN if weapon == Weapon.PULSE else 0.72
	var origin := head.global_position + -head.global_transform.basis.z * 0.46
	var direction := -head.global_transform.basis.z
	if weapon == Weapon.PULSE:
		_fire_ray(origin, direction, FIRE_DAMAGE)
		return
	# The scatter weapon trades range and pace for decisive close-range pressure.
	for spread in [Vector2(-0.07, -0.035), Vector2(-0.035, 0.05), Vector2(0.0, 0.0), Vector2(0.04, -0.045), Vector2(0.075, 0.025)]:
		var pellet: Vector3 = (direction + head.global_transform.basis.x * spread.x + head.global_transform.basis.y * spread.y).normalized()
		_fire_ray(origin, pellet, 13.0, 17.0)

func fire_at(target: Vector3) -> void:
	if eliminated or not match_active or _fire_remaining > 0.0:
		return
	_fire_remaining = FIRE_COOLDOWN
	var origin := head.global_position + Vector3.UP * 0.03
	_fire_ray(origin, (target - origin).normalized(), FIRE_DAMAGE)

func switch_weapon() -> void:
	if eliminated or not match_active:
		return
	weapon = Weapon.SCATTER if weapon == Weapon.PULSE else Weapon.PULSE
	_update_weapon_mesh()

func _update_weapon_mesh() -> void:
	if _weapon_mesh == null:
		return
	var color := Color("ffc05b") if weapon == Weapon.PULSE else Color("b479ff")
	_weapon_mesh.material_override = _material(color, 0.65)

func take_damage(amount: float, attacker: Duelist) -> void:
	if eliminated or not match_active:
		return
	health = maxf(0.0, health - amount)
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
	visible = true
	collision_layer = 2
	_apply_stance(Stance.STAND)

func _fire_ray(origin: Vector3, direction: Vector3, damage: float, range: float = FIRE_RANGE) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * range, 1 | 2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var end := origin + direction * range
	if not hit.is_empty():
		end = hit.position
		var collider: Object = hit.collider
		if collider is Duelist:
			collider.take_damage(damage, self)
	shot.emit(origin, end, team)

func _team_color() -> Color:
	return Color("ef6b3f") if team == Team.SUN else Color("4ba9ff")

func _team_glow() -> Color:
	return Color("ffb15c") if team == Team.SUN else Color("7bdbff")

func _build_character_silhouette(local_camera: bool) -> void:
	# The body is a normal adult runner's frame, not an oversized mascot or a real-world military uniform.
	var cloth := _material(_team_color(), 0.0)
	var dark := _material(Color("17263e"), 0.0)
	var brass := _material(Color("d6ad67"), 0.0)
	var glow := _material(_team_glow(), 1.4)
	_add_body_part(_cylinder(0.15, 0.17, 0.76), Vector3(-0.19, 0.37, 0.02), dark, Vector3(0.0, 0.0, 0.02))
	_add_body_part(_cylinder(0.15, 0.17, 0.76), Vector3(0.19, 0.37, 0.02), dark, Vector3(0.0, 0.0, -0.02))
	_add_body_part(_box(Vector3(0.3, 0.16, 0.5)), Vector3(-0.19, 0.05, -0.08), dark)
	_add_body_part(_box(Vector3(0.3, 0.16, 0.5)), Vector3(0.19, 0.05, -0.08), dark)
	_add_body_part(_cylinder(0.11, 0.12, 0.72), Vector3(-0.48, 1.08, 0.0), cloth, Vector3(0.0, 0.0, -0.2))
	_add_body_part(_cylinder(0.11, 0.12, 0.72), Vector3(0.48, 1.08, 0.0), cloth, Vector3(0.0, 0.0, 0.2))

	if not local_camera:
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
	# The Sun courier carries a ceramic relay, with a long asymmetric coat panel that reads at combat distance.
	_add_body_part(_box(Vector3(0.66, 0.7, 0.09)), Vector3(-0.08, 0.91, -0.37), cloth, Vector3(0.0, 0.0, 0.08))
	_add_body_part(_box(Vector3(0.58, 0.55, 0.2)), Vector3(0.0, 1.12, 0.34), dark)
	_add_body_part(_cylinder(0.13, 0.13, 0.38), Vector3(0.0, 1.18, -0.42), glow, Vector3(PI * 0.5, 0.0, 0.0))
	_add_body_part(_box(Vector3(0.1, 0.44, 0.12)), Vector3(-0.32, 1.14, 0.32), brass, Vector3(0.0, 0.0, 0.2))

func _build_storm_surveyor(cloth: Material, dark: Material, brass: Material, glow: Material) -> void:
	# The Void surveyor maps dangerous weather with a folded wind array, not a backpack or conventional armor.
	_add_body_part(_cylinder(0.16, 0.43, 0.82), Vector3(0.0, 0.88, -0.02), cloth)
	_add_body_part(_box(Vector3(0.56, 0.52, 0.24)), Vector3(0.0, 1.2, 0.34), dark)
	_add_body_part(_box(Vector3(0.08, 0.92, 0.36)), Vector3(0.0, 1.37, 0.47), cloth, Vector3(0.0, 0.0, 0.16))
	_add_body_part(_box(Vector3(0.82, 0.08, 0.16)), Vector3(0.0, 1.62, 0.48), brass, Vector3(0.0, 0.0, 0.11))
	_add_body_part(_cylinder(0.1, 0.1, 0.28), Vector3(0.0, 1.1, -0.43), glow, Vector3(PI * 0.5, 0.0, 0.0))

func _add_body_part(mesh: Mesh, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	instance.material_override = material
	instance.layers = 2 if _local_camera else 1
	add_child(instance)

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
