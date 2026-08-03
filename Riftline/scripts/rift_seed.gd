class_name RiftSeed
extends Node3D

signal claimed(carrier: Duelist)
signal dropped(position: Vector3)
signal returned_to_center
signal delivered(carrier: Duelist, scoring_team: Duelist.Team, gate_position: Vector3)

enum State { HOME, CARRIED, DROPPED }

const PICKUP_RADIUS := 1.15
const SCORING_RADIUS := 1.5
const DROP_TIMEOUT_SECONDS := 4.0
const HOME_HEIGHT := 0.7
const CARRIER_HEIGHT := 2.05

var state: State = State.HOME
var center := Vector3.ZERO
var gate_positions: Dictionary = {}

var _carrier: Duelist
var _carrier_id := ""
var _dropped_remaining := 0.0
var _delivery_locked := false
var _presentation_enabled := false
var _visual_root: Node3D
var _well: MeshInstance3D
var _core: MeshInstance3D
var _ring_a: MeshInstance3D
var _ring_b: MeshInstance3D
var _tether: MeshInstance3D
var _fragments: Array[MeshInstance3D] = []
var _presentation_team: Duelist.Team = Duelist.Team.SUN

func configure(next_center: Vector3, next_gate_positions: Dictionary, presentation_enabled: bool) -> void:
	center = next_center
	gate_positions = next_gate_positions.duplicate(true)
	_presentation_enabled = presentation_enabled
	if _presentation_enabled and _visual_root == null:
		_build_presentation()
	reset_to_center()

func tick_authority(delta: float, eligible_duelists: Array[Duelist]) -> void:
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

func reset_to_center() -> void:
	var was_dropped := state == State.DROPPED
	_clear_carrier()
	state = State.HOME
	_dropped_remaining = 0.0
	_delivery_locked = false
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
		"carrier_id": _carrier_id,
		"carrier_team": int(_carrier.team) if is_instance_valid(_carrier) else -1,
	}

func apply_presentation_state(next_state: Dictionary, carrier_lookup: Callable) -> void:
	if next_state.is_empty():
		return
	var next_state_value := clampi(int(next_state.get("state", int(State.HOME))), int(State.HOME), int(State.DROPPED)) as State
	state = next_state_value
	_carrier_id = str(next_state.get("carrier_id", ""))
	_presentation_team = int(next_state.get("carrier_team", int(Duelist.Team.SUN))) as Duelist.Team
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
	_tether.visible = state == State.CARRIED
	_visual_root.visible = true
	_pin_well()

func _process(delta: float) -> void:
	if not _presentation_enabled or _visual_root == null:
		return
	_pin_well()
	_visual_root.rotation.y += delta * 0.65
	if state != State.CARRIED:
		_visual_root.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.06
	else:
		_visual_root.position.y = 0.0
	for index in _fragments.size():
		_fragments[index].rotation.y += delta * (1.1 + index * 0.2)

func _pin_well() -> void:
	if _well != null:
		_well.global_position = center + Vector3.UP * (-HOME_HEIGHT + 0.06)

func _material(color: Color, glow: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/pulp_lit.gdshader")
	material.set_shader_parameter("base_tint", color)
	material.set_shader_parameter("shadow_tint", Color("16253d").lerp(color, 0.2))
	material.set_shader_parameter("rim_tint", color)
	material.set_shader_parameter("rim_strength", 0.28)
	material.set_shader_parameter("glow_strength", glow)
	material.set_shader_parameter("brush_scale", 2.0)
	return material

func _set_material(instance: MeshInstance3D, color: Color, glow: float) -> void:
	if instance == null or not (instance.material_override is ShaderMaterial):
		return
	var material := instance.material_override as ShaderMaterial
	material.set_shader_parameter("base_tint", color)
	material.set_shader_parameter("rim_tint", color)
	material.set_shader_parameter("glow_strength", glow)
