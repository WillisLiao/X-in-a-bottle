class_name BotDuelist
extends Duelist

var target: Duelist
var _time := 0.0
var _opening_hold_remaining := 0.0

func hold_opening_position(seconds: float) -> void:
	_opening_hold_remaining = maxf(_opening_hold_remaining, seconds)

func _physics_process(delta: float) -> void:
	if eliminated or target == null or target.eliminated:
		return
	_time += delta
	var toward := target.global_position - global_position
	toward.y = 0.0
	var distance := toward.length()
	if distance < 0.01:
		return

	# The opponent must visibly own its half of the arena before it begins its approach.
	# Without this beat, the bot's first movement makes a correct spawn read as if it began at the player's cover.
	var desired_yaw := atan2(-toward.x, -toward.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, minf(1.0, delta * 4.4))
	head.rotation.x = clampf(lerpf(head.rotation.x, -0.03, delta * 4.0), -0.45, 0.4)
	if _opening_hold_remaining > 0.0:
		_opening_hold_remaining = maxf(0.0, _opening_hold_remaining - delta)
		drive(Vector2.ZERO, false, false, delta)
		return

	# It circles rather than walking straight at the player, so the opening duel tests aiming immediately.
	var strafe := sin(_time * 1.8) * 0.82
	var advance := 0.42 if distance > 14.0 else -0.16 if distance < 7.0 else 0.08
	set_combat_pose(false, delta)
	drive(Vector2(strafe, -advance), false, false, delta)
	if distance < 32.0 and _has_line_of_sight():
		fire_at(target.head.global_position)

func _has_line_of_sight() -> bool:
	var origin := head.global_position + Vector3.UP * 0.03
	var query := PhysicsRayQueryParameters3D.create(origin, target.head.global_position, 1 | 2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target
