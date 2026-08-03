class_name RiftBallistics
extends Node3D

## Authority-only projectile simulation for the Rift Carbine.
##
## The public interface is intentionally small: callers submit an accepted fire
## request, advance the authority once per physics step, and clear on a phase
## boundary.  Projectile records never become scene nodes.

signal projectile_fired(fact: Dictionary)
signal projectile_impacted(fact: Dictionary)

const M4_PROJECTILE_SPEED := 800.0
const M4_FIRE_INTERVAL := 0.086
const M4_DAMAGE := 23.0
const M4_MAX_RANGE := 48.0
# 0.086 seconds is approximately 700 RPM, and 23 damage means five body hits to eliminate a 100 HP duelist.
# The 48 meter cap keeps the fast projectile bounded to the arena's close competitive lanes.
const PROJECTILE_GRAVITY := 9.81
const COLLISION_MASK := 1 | 2

var _next_projectile_id := 1
var _session_id := str(Time.get_ticks_usec())
var _projectiles: Array[Dictionary] = []

func fire(shooter: Duelist, weapon: Duelist.Weapon, origin: Vector3, direction: Vector3) -> bool:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return false
	if not is_instance_valid(shooter) or not shooter.match_active or shooter.eliminated:
		return false
	if weapon != Duelist.Weapon.PULSE or direction.length_squared() < 0.000001:
		return false
	var velocity := direction.normalized() * M4_PROJECTILE_SPEED
	var projectile_id := _next_projectile_id
	_next_projectile_id += 1
	var projectile := {
		"id": projectile_id,
		"shooter": shooter,
		"shooter_id": shooter.actor_id,
		"team": int(shooter.team),
		"weapon": int(weapon),
		"position": origin,
		"source_position": origin,
		"velocity": velocity,
		"remaining_range": M4_MAX_RANGE,
	}
	_projectiles.append(projectile)
	projectile_fired.emit({
		"type": "projectile_fired",
		"session_id": _session_id,
		"id": projectile_id,
		"shooter_id": shooter.actor_id,
		"team": int(shooter.team),
		"weapon": int(weapon),
		"origin": origin,
		"velocity": velocity,
	})
	return true

func tick_authority(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if delta <= 0.0 or _projectiles.is_empty():
		return
	var index := 0
	while index < _projectiles.size():
		var projectile := _projectiles[index]
		var shooter: Variant = projectile.get("shooter", null)
		if not shooter is Duelist or not is_instance_valid(shooter) or shooter.eliminated or not shooter.match_active:
			_projectiles.remove_at(index)
			continue

		var previous_position: Vector3 = projectile.position
		var velocity: Vector3 = projectile.velocity
		velocity.y -= PROJECTILE_GRAVITY * delta
		var travel := velocity * delta
		var travel_distance := travel.length()
		var remaining_range := float(projectile.remaining_range)
		if travel_distance > remaining_range:
			travel = travel.normalized() * remaining_range
			travel_distance = remaining_range
		var next_position := previous_position + travel
		var hit := _sweep(previous_position, next_position, shooter)
		if not hit.is_empty():
			_handle_impact(projectile, hit)
			_projectiles.remove_at(index)
			continue
		if remaining_range <= travel_distance + 0.0001:
			_projectiles.remove_at(index)
			continue
		projectile.position = next_position
		projectile.velocity = velocity
		projectile.remaining_range = remaining_range - travel_distance
		_projectiles[index] = projectile
		index += 1

func clear() -> void:
	_projectiles.clear()

func active_count() -> int:
	return _projectiles.size()

func _sweep(from: Vector3, to: Vector3, shooter: Duelist) -> Dictionary:
	if from.distance_squared_to(to) < 0.0000001:
		return {}
	var world := get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, COLLISION_MASK)
	query.exclude = [shooter.get_rid()]
	return world.direct_space_state.intersect_ray(query)

func _handle_impact(projectile: Dictionary, hit: Dictionary) -> void:
	var shooter: Duelist = projectile.shooter
	var collider: Object = hit.get("collider", null)
	var hit_duelist := false
	var target_id := ""
	if collider is Duelist and collider != shooter and not collider.eliminated and collider.match_active and collider.team != shooter.team:
		hit_duelist = true
		target_id = collider.actor_id
		collider.take_damage(M4_DAMAGE, shooter)
	projectile_impacted.emit({
		"type": "projectile_impacted",
		"session_id": _session_id,
		"id": int(projectile.id),
		"team": int(projectile.team),
		"shooter_id": str(projectile.get("shooter_id", "")),
		"target_id": target_id,
		"source_position": projectile.get("source_position", projectile.get("position", Vector3.ZERO)),
		"damage": M4_DAMAGE if hit_duelist else 0.0,
		"position": hit.get("position", projectile.position),
		"normal": hit.get("normal", Vector3.UP),
		"hit_duelist": hit_duelist,
	})
