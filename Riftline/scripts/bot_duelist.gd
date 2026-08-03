class_name BotDuelist
extends Duelist

var _target: Duelist
var _friendlies: Array[Duelist] = []
var _enemies: Array[Duelist] = []
var _decision_remaining := 0.0
var _reaction_remaining := 0.0
var _tracking_remaining := 0.0
var _shot_cadence_remaining := 0.0
var _burst_remaining := 0.0
var _target_locked := false
var _last_target_velocity := Vector3.ZERO
var _aim_offset := Vector3.ZERO
var _move_goal := Vector2.ZERO
var _random := RandomNumberGenerator.new()
var _linebreak_seed_state: Dictionary = {}
var _friendly_gate := Vector3.ZERO
var _enemy_gate := Vector3.ZERO

func set_linebreak_context(seed_state: Dictionary, friendly_gate: Vector3, enemy_gate: Vector3) -> void:
	set_squad_context([self], _enemies, seed_state, friendly_gate, enemy_gate)

func set_squad_context(friendlies: Array[Duelist], enemies: Array[Duelist], objective_state: Dictionary, friendly_gate: Vector3, enemy_gate: Vector3) -> void:
	_friendlies = friendlies.duplicate()
	_enemies = enemies.duplicate()
	_linebreak_seed_state = objective_state.duplicate(true)
	_friendly_gate = friendly_gate
	_enemy_gate = enemy_gate
	_select_target()

func _ready() -> void:
	_random.randomize()

func hold_opening_position(_seconds: float) -> void:
	# MatchDirector owns the inactive opening phase; this hook only clears stale aim before the hold.
	_target_locked = false
	_reaction_remaining = 0.0
	_tracking_remaining = 0.0
	_move_goal = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if eliminated:
		return
	_select_target()
	if not match_active:
		_target_locked = false
		_move_goal = Vector2.ZERO
		drive(Vector2.ZERO, false, false, delta)
		return
	if _target == null:
		drive(Vector2.ZERO, false, false, delta)
		return
	_decision_remaining = maxf(0.0, _decision_remaining - delta)
	_reaction_remaining = maxf(0.0, _reaction_remaining - delta)
	_tracking_remaining = maxf(0.0, _tracking_remaining - delta)
	_shot_cadence_remaining = maxf(0.0, _shot_cadence_remaining - delta)
	_burst_remaining = maxf(0.0, _burst_remaining - delta)

	var toward := _target.global_position - global_position
	toward.y = 0.0
	var distance := toward.length()
	if distance < 0.01:
		return

	# The bot turns toward the player's lane gradually so a mobile player can read and challenge the peek.
	var desired_yaw := atan2(-toward.x, -toward.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, minf(1.0, delta * 4.4))
	var aim_target := _target.global_position + Vector3.UP * 0.98
	head.rotation.x = clampf(lerpf(head.rotation.x, _pitch_to(aim_target), delta * 4.0), -0.45, 0.4)

	var has_los := _has_line_of_sight()
	if has_los:
		_update_target_lock(delta)
	else:
		_target_locked = false
		_reaction_remaining = 0.0
		_tracking_remaining = 0.0
	if _decision_remaining <= 0.0:
		if not _decide_linebreak_movement(distance, has_los):
			_decide_movement(distance, has_los)
		_decision_remaining = 0.16
	set_combat_pose(_target_locked and _tracking_remaining <= 0.0, delta)
	drive(_move_goal, false, false, delta)

	if not has_los or not _target_locked or _reaction_remaining > 0.0 or _tracking_remaining > 0.0 or _shot_cadence_remaining > 0.0:
		return
	if _burst_remaining <= 0.0:
		# Keep one bounded torso miss for a short burst, rather than rerolling aim on every frame.
		_aim_offset = Vector3(_random.randf_range(-0.46, 0.46), _random.randf_range(-0.2, 0.2), 0.0)
		_burst_remaining = 0.72
	fire_at(_target.global_position + Vector3.UP * 0.98 + _aim_offset)
	_shot_cadence_remaining = 0.18
	_tracking_remaining = 0.1

func _decide_linebreak_movement(distance: float, has_los: bool) -> bool:
	if _linebreak_seed_state.is_empty():
		return false
	var seed_state := int(_linebreak_seed_state.get("state", int(RiftSeed.State.HOME)))
	var carrier_id := str(_linebreak_seed_state.get("carrier_id", ""))
	if is_carrying_seed():
		_move_goal = _world_move_goal(_enemy_gate)
		return true
	for friendly in _friendlies:
		if friendly != self and is_instance_valid(friendly) and friendly.is_carrying_seed():
			_move_goal = _world_move_goal(friendly.global_position)
			return true
	if not carrier_id.is_empty() and _target != null and carrier_id == _target.actor_id:
		_move_goal = _world_move_goal(_target.global_position)
		return true
	if seed_state == RiftSeed.State.HOME or seed_state == RiftSeed.State.DROPPED:
		var seed_position: Vector3 = _linebreak_seed_state.get("position", global_position)
		if not has_los or distance > 9.0:
			_move_goal = _world_move_goal(seed_position)
			return true
	return false

func _world_move_goal(goal: Vector3) -> Vector2:
	var direction := goal - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.4:
		return Vector2.ZERO
	var local_direction := global_transform.basis.inverse() * direction.normalized()
	return Vector2(local_direction.x, local_direction.z)

func _update_target_lock(delta: float) -> void:
	var current_velocity := _target.velocity
	var direction_changed := current_velocity.length() > 2.0 and _last_target_velocity.length() > 2.0 and current_velocity.normalized().dot(_last_target_velocity.normalized()) < 0.25
	_last_target_velocity = current_velocity
	if not _target_locked:
		_target_locked = true
		_reaction_remaining = 0.34
		_tracking_remaining = 0.22
	elif direction_changed:
		# A meaningful strafe change costs the bot a fresh read instead of a free head correction.
		_reaction_remaining = maxf(_reaction_remaining, 0.22)
		_tracking_remaining = maxf(_tracking_remaining, 0.18)
		_target_locked = true

func _decide_movement(distance: float, has_los: bool) -> void:
	var strafe := 0.0
	var advance := 0.0
	if distance > 18.0:
		advance = 0.34
	elif distance < 7.0:
		advance = -0.28
	elif has_los:
		# Short, deliberate peeks make the bot readable without turning it into a stationary target.
		strafe = _random.randf_range(-0.55, 0.55)
	else:
		advance = 0.24
	_move_goal = Vector2(strafe, -advance)

func _pitch_to(point: Vector3) -> float:
	var local_point := to_local(point)
	return atan2(local_point.y - head.position.y, -local_point.z)

func _has_line_of_sight() -> bool:
	var origin := head.global_position + Vector3.UP * 0.03
	var query := PhysicsRayQueryParameters3D.create(origin, _target.head.global_position, 1 | 2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == _target

func _select_target() -> void:
	var valid: Array[Duelist] = []
	for candidate in _enemies:
		if is_instance_valid(candidate) and candidate.match_active and not candidate.eliminated:
			valid.append(candidate)
	if valid.is_empty():
		_target = null
		return
	var carrier_id := str(_linebreak_seed_state.get("carrier_id", ""))
	if not carrier_id.is_empty():
		for candidate in valid:
			if candidate.actor_id == carrier_id:
				_target = candidate
				return
	valid.sort_custom(func(a: Duelist, b: Duelist) -> bool:
		var a_distance := global_position.distance_squared_to(a.global_position)
		var b_distance := global_position.distance_squared_to(b.global_position)
		return a_distance < b_distance if not is_equal_approx(a_distance, b_distance) else a.actor_id < b.actor_id
	)
	for candidate in valid:
		var nearby := global_position.distance_to(candidate.global_position) <= 18.0
		if _has_line_of_sight_to(candidate) and (nearby or _advances_objective(candidate)):
			_target = candidate
			return
	_target = null

func _advances_objective(candidate: Duelist) -> bool:
	var carrier_id := str(_linebreak_seed_state.get("carrier_id", ""))
	if not carrier_id.is_empty():
		return candidate.actor_id == carrier_id
	return candidate.global_position.distance_squared_to(_enemy_gate) < global_position.distance_squared_to(_enemy_gate)

func _has_line_of_sight_to(candidate: Duelist) -> bool:
	var origin := head.global_position + Vector3.UP * 0.03
	var query := PhysicsRayQueryParameters3D.create(origin, candidate.head.global_position, 1 | 2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == candidate
