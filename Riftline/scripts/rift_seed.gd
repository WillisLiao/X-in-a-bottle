class_name RiftSeed
extends Node3D

signal claimed(carrier: Duelist)
signal dropped(position: Vector3)
signal returned_to_center
signal delivered(carrier: Duelist, scoring_team: Duelist.Team, gate_position: Vector3)
signal relay_launched(state: Dictionary)
signal relay_caught(state: Dictionary)
signal relay_disrupted(state: Dictionary)

enum State { HOME, CARRIED, DROPPED, IN_FLIGHT }

const PICKUP_RADIUS := 1.15
const SCORING_RADIUS := 1.5
const DROP_TIMEOUT_SECONDS := 4.0
const HOME_HEIGHT := 0.7
const CARRIER_HEIGHT := 2.05
# Fourteen metres at eighteen metres per second keeps Concourse passes readable
# and contestable; longer launches would skip the gate-side decision window.
const RELAY_RANGE := 14.0
const RELAY_SPEED := 18.0
const RELAY_LIFT := 2.4
const RELAY_GRAVITY := 7.5
const RELAY_CATCH_RADIUS := 1.6
const RELAY_RECATCH_EXCLUSION_SECONDS := 0.34
const RELAY_COOLDOWN_SECONDS := 0.46
const RELAY_MAX_FLIGHT_SECONDS := RELAY_RANGE / RELAY_SPEED
const RELAY_ARENA_HALF_EXTENTS := Vector3(62.0, 12.0, 38.0)

var state: State = State.HOME
var center := Vector3.ZERO
var gate_positions: Dictionary = {}

var _carrier: Duelist
var _carrier_id := ""
var _dropped_remaining := 0.0
var _delivery_locked := false
var _flight_velocity := Vector3.ZERO
var _flight_start_position := Vector3.ZERO
var _flight_remaining := 0.0
var _flight_source_id := ""
var _flight_team: Duelist.Team = Duelist.Team.SUN
var _flight_token := 0
var _lifecycle_token := 0
var _recatch_exclusion_remaining := 0.0
var _relay_cooldown_remaining := 0.0
var _presentation_lifecycle_token := -1
var _presentation_enabled := false
var _visual_root: Node3D
var _well: MeshInstance3D
var _core: MeshInstance3D
var _ring_a: MeshInstance3D
var _ring_b: MeshInstance3D
var _tether: MeshInstance3D
var _fragments: Array[MeshInstance3D] = []
var _flight_wake: Array[MeshInstance3D] = []
var _presentation_team: Duelist.Team = Duelist.Team.SUN

func configure(next_center: Vector3, next_gate_positions: Dictionary, presentation_enabled: bool) -> void:
	center = next_center
	gate_positions = next_gate_positions.duplicate(true)
	_presentation_enabled = presentation_enabled
	if _presentation_enabled and _visual_root == null:
		_build_presentation()
	reset_to_center()

func tick_authority(delta: float, eligible_duelists: Array[Duelist]) -> void:
	_recatch_exclusion_remaining = maxf(0.0, _recatch_exclusion_remaining - delta)
	_relay_cooldown_remaining = maxf(0.0, _relay_cooldown_remaining - delta)
	if state == State.HOME:
		_claim_nearest(eligible_duelists)
	elif state == State.CARRIED:
		if not is_instance_valid(_carrier) or _carrier.eliminated:
			drop_at(global_position)
			return
		_carrier.set_carrying_seed(true)
		global_position = _carrier.global_position + Vector3.UP * CARRIER_HEIGHT
		var enemy_gate_team := Duelist.Team.SUN if _carrier.team == Duelist.Team.VOID else Duelist.Team.VOID
		if gate_positions.has(enemy_gate_team):
			var gate_position: Vector3 = gate_positions[enemy_gate_team]
			if _horizontal_distance(_carrier.global_position, gate_position) <= SCORING_RADIUS and not _delivery_locked:
				_delivery_locked = true
				delivered.emit(_carrier, _carrier.team, gate_position)
	elif state == State.DROPPED:
		_dropped_remaining = maxf(0.0, _dropped_remaining - delta)
		if _dropped_remaining <= 0.0:
			reset_to_center()
	elif state == State.IN_FLIGHT:
		_tick_flight(delta, eligible_duelists)

func launch_relay(source: Duelist, aim_direction: Vector3) -> bool:
	if state != State.CARRIED or _carrier != source or not is_instance_valid(source):
		return false
	if source.eliminated or not source.match_active or _relay_cooldown_remaining > 0.0:
		return false
	if not _is_finite_vector(aim_direction) or aim_direction.length_squared() < 0.0001:
		return false
	var direction := aim_direction.normalized()
	if not _is_finite_vector(direction):
		return false
	_clear_carrier()
	state = State.IN_FLIGHT
	_flight_source_id = source.actor_id
	_flight_team = source.team
	_presentation_team = source.team
	_flight_velocity = direction * RELAY_SPEED + Vector3.UP * RELAY_LIFT
	_flight_remaining = RELAY_MAX_FLIGHT_SECONDS
	_recatch_exclusion_remaining = RELAY_RECATCH_EXCLUSION_SECONDS
	_relay_cooldown_remaining = RELAY_COOLDOWN_SECONDS
	_flight_token += 1
	_lifecycle_token += 1
	_delivery_locked = false
	global_position = source.global_position + Vector3.UP * (CARRIER_HEIGHT * 0.72)
	_flight_start_position = global_position
	_update_visuals()
	relay_launched.emit(authoritative_state())
	return true

func reset_to_center() -> void:
	var was_dropped := state == State.DROPPED
	_clear_carrier()
	state = State.HOME
	_dropped_remaining = 0.0
	_delivery_locked = false
	_clear_flight()
	_lifecycle_token += 1
	global_position = center + Vector3.UP * HOME_HEIGHT
	_update_visuals()
	if was_dropped:
		returned_to_center.emit()

func drop_at(position: Vector3) -> void:
	if state == State.DROPPED:
		return
	_clear_carrier()
	state = State.DROPPED
	_dropped_remaining = DROP_TIMEOUT_SECONDS
	_delivery_locked = false
	_clear_flight()
	_lifecycle_token += 1
	global_position = Vector3(position.x, HOME_HEIGHT, position.z)
	_update_visuals()
	dropped.emit(global_position)

func authoritative_state() -> Dictionary:
	if state == State.CARRIED and is_instance_valid(_carrier):
		global_position = _carrier.global_position + Vector3.UP * CARRIER_HEIGHT
	_pin_well()
	return {
		"state": int(state),
		"position": global_position,
		"velocity": _flight_velocity if state == State.IN_FLIGHT else Vector3.ZERO,
		"carrier_id": _carrier_id,
		"carrier_team": int(_carrier.team) if is_instance_valid(_carrier) else -1,
		"pass_team": int(_flight_team) if state == State.IN_FLIGHT else -1,
		"source_actor_id": _flight_source_id,
		"flight_remaining": _flight_remaining if state == State.IN_FLIGHT else 0.0,
		"flight_token": _flight_token,
		"lifecycle_token": _lifecycle_token,
		"event_id": "seed:%d" % _lifecycle_token,
	}

func accepts_presentation_state(next_state: Dictionary) -> bool:
	if next_state.is_empty() or not next_state.has("lifecycle_token"):
		return true
	var next_lifecycle := int(next_state.get("lifecycle_token", -1))
	if next_lifecycle < _presentation_lifecycle_token:
		return false
	if next_lifecycle == _presentation_lifecycle_token and next_state.has("flight_token"):
		return int(next_state.get("flight_token", -1)) >= _flight_token
	return true

func apply_presentation_state(next_state: Dictionary, carrier_lookup: Callable) -> bool:
	if next_state.is_empty():
		return false
	if not accepts_presentation_state(next_state):
		return false
	if next_state.has("lifecycle_token"):
		_presentation_lifecycle_token = int(next_state.get("lifecycle_token", _presentation_lifecycle_token))
	var next_state_value := clampi(int(next_state.get("state", int(State.HOME))), int(State.HOME), int(State.IN_FLIGHT)) as State
	state = next_state_value
	_carrier_id = str(next_state.get("carrier_id", ""))
	_presentation_team = int(next_state.get("carrier_team", int(Duelist.Team.SUN))) as Duelist.Team
	_flight_team = int(next_state.get("pass_team", int(_presentation_team))) as Duelist.Team
	_flight_source_id = str(next_state.get("source_actor_id", ""))
	_flight_velocity = next_state.get("velocity", Vector3.ZERO)
	_flight_remaining = maxf(0.0, float(next_state.get("flight_remaining", 0.0)))
	_flight_token = maxi(_flight_token, int(next_state.get("flight_token", _flight_token)))
	_carrier = null
	if not _carrier_id.is_empty() and carrier_lookup.is_valid():
		var candidate: Variant = carrier_lookup.call(_carrier_id)
		if candidate is Duelist:
			_carrier = candidate
	if state == State.CARRIED and is_instance_valid(_carrier):
		global_position = _carrier.global_position + Vector3.UP * CARRIER_HEIGHT
	else:
		global_position = next_state.get("position", center + Vector3.UP * HOME_HEIGHT)
	_pin_well()
	_update_visuals()
	return true

func carrier_id() -> String:
	return _carrier_id

func _claim_nearest(eligible_duelists: Array[Duelist]) -> void:
	var candidates: Array[Duelist] = []
	for duelist in eligible_duelists:
		if not is_instance_valid(duelist) or duelist.eliminated or not duelist.match_active or duelist.is_carrying_seed():
			continue
		if _horizontal_distance(duelist.global_position, center) <= PICKUP_RADIUS:
			candidates.append(duelist)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Duelist, b: Duelist) -> bool:
		var a_distance := _horizontal_distance(a.global_position, center)
		var b_distance := _horizontal_distance(b.global_position, center)
		if not is_equal_approx(a_distance, b_distance):
			return a_distance < b_distance
		return a.actor_id < b.actor_id
	)
	_carrier = candidates[0]
	_carrier_id = _carrier.actor_id
	_presentation_team = _carrier.team
	_lifecycle_token += 1
	_carrier.set_carrying_seed(true)
	state = State.CARRIED
	global_position = _carrier.global_position + Vector3.UP * CARRIER_HEIGHT
	_update_visuals()
	claimed.emit(_carrier)

func _clear_carrier() -> void:
	if is_instance_valid(_carrier):
		_carrier.set_carrying_seed(false)
		_carrier = null
		_carrier_id = ""

func _clear_flight() -> void:
	_flight_velocity = Vector3.ZERO
	_flight_start_position = Vector3.ZERO
	_flight_remaining = 0.0
	_flight_source_id = ""
	_recatch_exclusion_remaining = 0.0

func _tick_flight(delta: float, eligible_duelists: Array[Duelist]) -> void:
	if _flight_remaining <= 0.0:
		_drop_flight(global_position, "expired")
		return
	var previous := global_position
	_flight_velocity += Vector3.DOWN * RELAY_GRAVITY * delta
	var next_position := previous + _flight_velocity * delta
	var hit := _flight_collision(previous, next_position)
	var hit_fraction := 1.0
	if not hit.is_empty():
		var segment := next_position - previous
		if segment.length_squared() > 0.0001:
			hit_fraction = clampf(previous.distance_to(hit.position) / segment.length(), 0.0, 1.0)
	var receiver := _relay_receiver(previous, next_position, hit_fraction, eligible_duelists)
	if receiver != null:
		_catch_flight(receiver, previous.lerp(next_position, _segment_fraction(previous, next_position, receiver.global_position)))
		return
	if not hit.is_empty():
		_drop_flight(hit.position, "blocked")
		return
	global_position = next_position
	_flight_remaining = maxf(0.0, _flight_remaining - delta)
	if not _is_in_legal_arena(global_position) or _flight_remaining <= 0.0:
		_drop_flight(previous, "out_of_bounds" if not _is_in_legal_arena(global_position) else "expired")
	else:
		_update_visuals()

func _relay_receiver(previous: Vector3, next_position: Vector3, hit_fraction: float, eligible_duelists: Array[Duelist]) -> Duelist:
	var candidates: Array[Duelist] = []
	for duelist in eligible_duelists:
		if not is_instance_valid(duelist) or duelist.eliminated or not duelist.match_active:
			continue
		if duelist.team != _flight_team:
			continue
		if _recatch_exclusion_remaining > 0.0 and duelist.actor_id == _flight_source_id:
			continue
		var fraction := _segment_fraction(previous, next_position, duelist.global_position)
		if fraction > hit_fraction + 0.001:
			continue
		var closest := previous.lerp(next_position, fraction)
		if duelist.actor_id == _flight_source_id and closest.distance_to(_flight_start_position) < RELAY_CATCH_RADIUS:
			continue
		if closest.distance_to(duelist.global_position + Vector3.UP * 0.9) <= RELAY_CATCH_RADIUS or closest.distance_to(duelist.global_position) <= RELAY_CATCH_RADIUS:
			candidates.append(duelist)
	if candidates.is_empty():
		return null
	candidates.sort_custom(func(a: Duelist, b: Duelist) -> bool: return a.actor_id < b.actor_id)
	return candidates[0]

func _catch_flight(receiver: Duelist, catch_position: Vector3) -> void:
	state = State.CARRIED
	_carrier = receiver
	_carrier_id = receiver.actor_id
	_presentation_team = receiver.team
	_flight_velocity = Vector3.ZERO
	_flight_remaining = 0.0
	_flight_source_id = ""
	_lifecycle_token += 1
	receiver.set_carrying_seed(true)
	global_position = receiver.global_position + Vector3.UP * CARRIER_HEIGHT
	_update_visuals()
	relay_caught.emit(authoritative_state())

func _drop_flight(position: Vector3, reason: String) -> void:
	var token := _flight_token
	var source_id := _flight_source_id
	var pass_team := int(_flight_team)
	drop_at(position)
	var event_state := authoritative_state()
	event_state["reason"] = reason
	event_state["flight_token"] = token
	event_state["source_actor_id"] = source_id
	event_state["pass_team"] = pass_team
	relay_disrupted.emit(event_state)

func _flight_collision(previous: Vector3, next_position: Vector3) -> Dictionary:
	var world := get_world_3d()
	if world == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(previous, next_position, 1 | 2)
	query.collide_with_areas = false
	var source := _find_actor(_flight_source_id)
	if source != null:
		query.exclude.append(source.get_rid())
	return world.direct_space_state.intersect_ray(query)

func _find_actor(actor_id: String) -> Duelist:
	for node in get_tree().get_nodes_in_group("riftline_duelists"):
		if node is Duelist and node.actor_id == actor_id:
			return node
	return null

func _segment_fraction(start: Vector3, finish: Vector3, point: Vector3) -> float:
	var segment := finish - start
	if segment.length_squared() < 0.0001:
		return 0.0
	return clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)

func _is_in_legal_arena(point: Vector3) -> bool:
	var offset := point - center
	return absf(offset.x) <= RELAY_ARENA_HALF_EXTENTS.x and absf(offset.y) <= RELAY_ARENA_HALF_EXTENTS.y and absf(offset.z) <= RELAY_ARENA_HALF_EXTENTS.z

func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _build_presentation() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "RiftSeedPresentation"
	add_child(_visual_root)
	_well = MeshInstance3D.new()
	var well_mesh := CylinderMesh.new()
	well_mesh.top_radius = 1.2
	well_mesh.bottom_radius = 1.35
	well_mesh.height = 0.12
	_well.mesh = well_mesh
	_well.position = Vector3(0.0, -HOME_HEIGHT + 0.06, 0.0)
	_well.material_override = _material(Color("314a73"), 0.2)
	_visual_root.add_child(_well)
	_pin_well()

	_core = MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.22
	core_mesh.height = 0.44
	_core.mesh = core_mesh
	_core.scale = Vector3.ONE * 1.25
	_core.material_override = _material(Color("fff4c7"), 3.0)
	_visual_root.add_child(_core)

	_ring_a = _make_ring(0.32, 0.07, 0.35)
	_ring_b = _make_ring(0.42, 0.045, -0.25)
	_visual_root.add_child(_ring_a)
	_visual_root.add_child(_ring_b)

	_tether = MeshInstance3D.new()
	var tether_mesh := BoxMesh.new()
	tether_mesh.size = Vector3(0.045, 0.75, 0.045)
	_tether.mesh = tether_mesh
	_tether.position = Vector3(0.0, -0.4, 0.0)
	_tether.material_override = _material(Color("75dbff"), 2.0)
	_visual_root.add_child(_tether)

	for index in 4:
		var fragment := MeshInstance3D.new()
		var fragment_mesh := BoxMesh.new()
		fragment_mesh.size = Vector3(0.07, 0.16, 0.06)
		fragment.mesh = fragment_mesh
		fragment.position = Vector3(0.38 if index % 2 == 0 else -0.34, 0.08 + float(index) * 0.05, 0.0)
		fragment.rotation.z = -0.4 if index % 2 == 0 else 0.45
		fragment.material_override = _material(Color("f4a55e"), 1.8)
		_visual_root.add_child(fragment)
		_fragments.append(fragment)
	for index in 3:
		var wake := MeshInstance3D.new()
		var wake_mesh := BoxMesh.new()
		wake_mesh.size = Vector3(0.045, 0.2, 0.045)
		wake.mesh = wake_mesh
		wake.material_override = _material(Color("fff4c7"), 1.4)
		_visual_root.add_child(wake)
		_flight_wake.append(wake)
	_update_visuals()

func _make_ring(outer_radius: float, thickness: float, tilt: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = outer_radius - thickness
	mesh.outer_radius = outer_radius
	mesh.rings = 16
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.rotation = Vector3(tilt, 0.0, tilt * 0.6)
	ring.material_override = _material(Color("ffb15c"), 1.4)
	return ring

func _update_visuals() -> void:
	if _visual_root == null:
		return
	var accent := Color("f4a55e") if _carrier_id.is_empty() else Color("ffb15c") if _presentation_team == Duelist.Team.SUN else Color("75dbff")
	_set_material(_ring_a, accent, 1.6)
	_set_material(_ring_b, accent.lerp(Color("fff4c7"), 0.3), 1.3)
	_set_material(_tether, accent, 2.2)
	for fragment in _fragments:
		_set_material(fragment, accent.lerp(Color("fff4c7"), 0.25), 1.8)
	for wake in _flight_wake:
		_set_material(wake, accent.lerp(Color("fff4c7"), 0.35), 1.6)
	_tether.visible = state == State.CARRIED or state == State.IN_FLIGHT
	for wake in _flight_wake:
		wake.visible = state == State.IN_FLIGHT
	_visual_root.visible = true
	_pin_well()

func _process(delta: float) -> void:
	if not _presentation_enabled or _visual_root == null:
		return
	_pin_well()
	_visual_root.rotation.y += delta * 0.65
	if state == State.IN_FLIGHT:
		_update_flight_visuals()
	elif state != State.CARRIED:
		_visual_root.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.06
	else:
		_visual_root.position.y = 0.0
	for index in _fragments.size():
		_fragments[index].rotation.y += delta * (1.1 + index * 0.2)

func _update_flight_visuals() -> void:
	if _flight_velocity.length_squared() < 0.0001:
		return
	var direction := _flight_velocity.normalized()
	_tether.global_position = global_position - direction * 0.34
	_tether.look_at(_tether.global_position + direction, Vector3.UP)
	_tether.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_tether.scale = Vector3.ONE * Vector3(1.0, 1.25, 1.0)
	for index in _flight_wake.size():
		var wake := _flight_wake[index]
		wake.global_position = global_position - direction * (0.55 + index * 0.3)
		wake.look_at(wake.global_position + direction, Vector3.UP)
		wake.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		wake.scale = Vector3.ONE * (1.0 - index * 0.18)

func _pin_well() -> void:
	if _well != null:
		_well.global_position = center + Vector3.UP * (-HOME_HEIGHT + 0.06)

func _material(color: Color, glow: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/pulp_lit.gdshader")
	var linear_color := color.srgb_to_linear()
	material.set_shader_parameter("base_tint", linear_color)
	material.set_shader_parameter("shadow_tint", Color("16253d").srgb_to_linear().lerp(linear_color, 0.2))
	material.set_shader_parameter("rim_tint", linear_color)
	material.set_shader_parameter("rim_strength", 0.28)
	material.set_shader_parameter("glow_strength", glow)
	material.set_shader_parameter("brush_scale", 2.0)
	return material

func _set_material(instance: MeshInstance3D, color: Color, glow: float) -> void:
	if instance == null or not (instance.material_override is ShaderMaterial):
		return
	var material := instance.material_override as ShaderMaterial
	var linear_color := color.srgb_to_linear()
	material.set_shader_parameter("base_tint", linear_color)
	material.set_shader_parameter("rim_tint", linear_color)
	material.set_shader_parameter("glow_strength", glow)
