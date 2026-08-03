class_name LinebreakMatch
extends Node

signal score_changed(sun: int, void_score: int)
signal phase_changed(phase: Phase)
signal match_finished(winner: Duelist.Team)
signal respawn_started(victim: Duelist)
signal objective_changed(state: Dictionary)
signal objective_event(event_type: String, state: Dictionary)

enum Phase { OPENING, LIVE, INTERMISSION, FINISHED }

const SCORE_TO_WIN := 3
const OPENING_HOLD_SECONDS := 2.5
const INTERMISSION_SECONDS := 1.25
const RESPAWN_DELAY_SECONDS := 1.1

var rosters: Dictionary = {Duelist.Team.SUN: [], Duelist.Team.VOID: []}
var scores: Dictionary = {Duelist.Team.SUN: 0, Duelist.Team.VOID: 0}
var spawn_points: Dictionary = {Duelist.Team.SUN: [], Duelist.Team.VOID: []}
var phase: Phase = Phase.OPENING
var seed: RiftSeed

var _center := Vector3.ZERO
var _gate_positions: Dictionary = {}
var _presentation_enabled := false
var _duelists_by_id: Dictionary = {}
var _round_generation := 0
var _respawn_generation: Dictionary = {}
var _opening_remaining := 0.0
var _intermission_remaining := 0.0
var _started := false
var _winner: Duelist.Team = Duelist.Team.SUN
var _last_replica_tick := -1
var _route_finder := Callable()
var _tactical_facts: Dictionary = {}
var _tactical_planners: Dictionary = {}
var _tactical_elapsed := 0.0
var _tactical_refresh := true
var _tactical_updates := 0

func configure(center: Vector3, gate_positions: Dictionary, presentation_enabled: bool) -> void:
	_center = center
	_gate_positions = gate_positions.duplicate(true)
	_presentation_enabled = presentation_enabled
	if seed != null:
		seed.queue_free()
	seed = RiftSeed.new()
	add_child(seed)
	seed.configure(_center, _gate_positions, _presentation_enabled)
	seed.claimed.connect(_on_seed_claimed)
	seed.dropped.connect(_on_seed_dropped)
	seed.returned_to_center.connect(_on_seed_returned)
	seed.delivered.connect(_on_seed_delivered)
	seed.relay_launched.connect(_on_seed_relay_launched)
	seed.relay_caught.connect(_on_seed_relay_caught)
	seed.relay_disrupted.connect(_on_seed_relay_disrupted)

func add_spawn(team: Duelist.Team, point: Vector3) -> void:
	spawn_points[team].append(point)

func set_route_finder(route_finder: Callable) -> void:
	_route_finder = route_finder
	_sync_bot_context()

func configure_tactics(map_facts: Dictionary, enabled: bool = true) -> void:
	_tactical_facts = map_facts.duplicate(true) if enabled else {}
	_tactical_planners.clear()
	if enabled:
		for team in [Duelist.Team.SUN, Duelist.Team.VOID]:
			var planner := RiftlineSquadTactics.new()
			planner.configure(_tactical_facts)
			_tactical_planners[int(team)] = planner
	_tactical_elapsed = 0.0
	_tactical_refresh = true

func register_duelist(duelist: Duelist, actor_id: String) -> void:
	if not is_instance_valid(duelist) or actor_id.is_empty():
		return
	if duelist in rosters[duelist.team]:
		duelist.set_actor_id(actor_id)
		_duelists_by_id[actor_id] = duelist
		return
	duelist.set_actor_id(actor_id)
	rosters[duelist.team].append(duelist)
	_duelists_by_id[actor_id] = duelist
	_respawn_generation[actor_id] = 0
	_tactical_refresh = true
	duelist.defeated.connect(_on_defeated)

func unregister_duelist(actor_id: String) -> void:
	var duelist: Variant = _duelists_by_id.get(actor_id, null)
	if not duelist is Duelist:
		return
	if seed != null and seed.carrier_id() == actor_id:
		seed.reset_to_center()
	duelist.set_carrying_seed(false)
	if duelist in rosters[duelist.team]:
		rosters[duelist.team].erase(duelist)
	_duelists_by_id.erase(actor_id)
	_respawn_generation.erase(actor_id)
	_tactical_refresh = true
	if rosters[Duelist.Team.SUN].is_empty() or rosters[Duelist.Team.VOID].is_empty():
		_started = false
		_cancel_respawns()
		_set_phase(Phase.OPENING)

func begin() -> void:
	if _started:
		return
	_started = true
	_start_opening()

func is_live() -> bool:
	return phase == Phase.LIVE

func take_rematch() -> bool:
	if phase != Phase.FINISHED:
		return false
	_round_generation += 1
	_clear_tactical_memory()
	_cancel_respawns()
	scores[Duelist.Team.SUN] = 0
	scores[Duelist.Team.VOID] = 0
	score_changed.emit(0, 0)
	_start_opening()
	return true

func authoritative_state() -> Dictionary:
	return {
		"phase": int(phase),
		"sun_score": int(scores[Duelist.Team.SUN]),
		"void_score": int(scores[Duelist.Team.VOID]),
		"objective": seed.authoritative_state() if seed != null else {},
	}

func apply_replica_state(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var tick := int(snapshot.get("tick", -1))
	if tick >= 0 and tick <= _last_replica_tick:
		return
	if tick >= 0:
		_last_replica_tick = tick
	var next_phase := clampi(int(snapshot.get("phase", int(Phase.OPENING))), int(Phase.OPENING), int(Phase.FINISHED)) as Phase
	var phase_changed_locally := next_phase != phase
	phase = next_phase
	scores[Duelist.Team.SUN] = clampi(int(snapshot.get("sun_score", 0)), 0, SCORE_TO_WIN)
	scores[Duelist.Team.VOID] = clampi(int(snapshot.get("void_score", 0)), 0, SCORE_TO_WIN)
	if seed != null:
		var objective: Dictionary = snapshot.get("objective", {})
		if seed.apply_presentation_state(objective, Callable(self, "_lookup_duelist")):
			_update_carrier_flags(objective)
			objective_changed.emit(objective)
	if phase_changed_locally:
		_set_phase(phase)
	score_changed.emit(scores[Duelist.Team.SUN], scores[Duelist.Team.VOID])

func objective_state() -> Dictionary:
	return seed.authoritative_state() if seed != null else {}

func request_seed_pass(carrier: Duelist, aim_direction: Vector3) -> bool:
	if not _started or phase != Phase.LIVE or seed == null:
		return false
	if not _is_registered(carrier) or carrier == null or carrier.eliminated or not carrier.match_active:
		return false
	if seed.state != RiftSeed.State.CARRIED or seed.carrier_id() != carrier.actor_id or not carrier.is_carrying_seed():
		return false
	if _living_teammate_count(carrier) <= 0 or not _is_finite_vector(aim_direction) or aim_direction.length_squared() < 0.0001:
		return false
	return seed.launch_relay(carrier, aim_direction)

func _physics_process(delta: float) -> void:
	if not _started or seed == null:
		return
	if phase == Phase.OPENING:
		_opening_remaining = maxf(0.0, _opening_remaining - delta)
		if _opening_remaining <= 0.0:
			_set_phase(Phase.LIVE)
	elif phase == Phase.INTERMISSION:
		_intermission_remaining = maxf(0.0, _intermission_remaining - delta)
		if _intermission_remaining <= 0.0:
			_start_opening()
	elif phase == Phase.LIVE:
		_request_bot_relay()
		seed.tick_authority(delta, _all_duelists())
		_tactical_elapsed += delta
		_sync_bot_context()
		seed.apply_presentation_state(seed.authoritative_state(), Callable(self, "_lookup_duelist"))

func _start_opening() -> void:
	_round_generation += 1
	_clear_tactical_memory()
	_opening_remaining = OPENING_HOLD_SECONDS
	_intermission_remaining = 0.0
	_set_phase(Phase.OPENING)
	_cancel_respawns()
	_reset_duelists_to_cover()
	if seed != null:
		seed.reset_to_center()
		objective_changed.emit(seed.authoritative_state())
	_sync_bot_context()

func _on_defeated(victim: Duelist, killer: Duelist) -> void:
	if phase != Phase.LIVE or not _is_registered(victim) or not _is_registered(killer):
		return
	if killer == victim or killer.team == victim.team:
		return
	if victim.carrying_seed and seed != null:
		seed.drop_at(victim.global_position)
	_schedule_respawn(victim)

func _schedule_respawn(victim: Duelist) -> void:
	var actor_id := victim.actor_id
	var generation := int(_respawn_generation.get(actor_id, 0)) + 1
	_respawn_generation[actor_id] = generation
	var round_generation := _round_generation
	await get_tree().create_timer(RESPAWN_DELAY_SECONDS).timeout
	if round_generation != _round_generation or generation != int(_respawn_generation.get(actor_id, -1)):
		return
	if phase != Phase.LIVE or not is_instance_valid(victim) or not victim.eliminated:
		return
	_respawn_duelist(victim)

func _respawn_duelist(victim: Duelist) -> void:
	var roster: Array = rosters[victim.team]
	var index := roster.find(victim)
	var points: Array = spawn_points[victim.team]
	if index < 0 or points.is_empty():
		return
	victim.respawn_at(points[posmod(index, points.size())])
	_tactical_refresh = true
	respawn_started.emit(victim)

func _on_seed_claimed(carrier: Duelist) -> void:
	_tactical_refresh = true
	carrier.set_carrying_seed(true)
	objective_changed.emit(seed.authoritative_state())
	objective_event.emit("objective_claimed", seed.authoritative_state())
	_sync_bot_context()

func _on_seed_dropped(position: Vector3) -> void:
	_tactical_refresh = true
	objective_changed.emit(seed.authoritative_state())
	objective_event.emit("objective_dropped", seed.authoritative_state())
	_sync_bot_context()

func _on_seed_returned() -> void:
	_tactical_refresh = true
	objective_changed.emit(seed.authoritative_state())
	objective_event.emit("objective_returned", seed.authoritative_state())
	_sync_bot_context()

func _on_seed_delivered(carrier: Duelist, scoring_team: Duelist.Team, gate_position: Vector3) -> void:
	if phase != Phase.LIVE or carrier == null or not carrier.is_carrying_seed():
		return
	_tactical_refresh = true
	var event_state := {
		"state": int(RiftSeed.State.CARRIED),
		"position": gate_position + Vector3.UP * RiftSeed.HOME_HEIGHT,
		"carrier_id": carrier.actor_id,
		"carrier_team": int(carrier.team),
		"scoring_team": int(scoring_team),
		"gate_position": gate_position,
	}
	scores[scoring_team] = mini(SCORE_TO_WIN, int(scores[scoring_team]) + 1)
	score_changed.emit(scores[Duelist.Team.SUN], scores[Duelist.Team.VOID])
	objective_event.emit("objective_delivered", event_state)
	carrier.set_carrying_seed(false)
	if scores[scoring_team] >= SCORE_TO_WIN:
		_winner = scoring_team
		_reset_duelists_to_cover()
		seed.reset_to_center()
		_set_phase(Phase.FINISHED)
		match_finished.emit(_winner)
		return
	_set_phase(Phase.INTERMISSION)
	_reset_duelists_to_cover()
	seed.reset_to_center()
	objective_changed.emit(seed.authoritative_state())
	_intermission_remaining = INTERMISSION_SECONDS

func _on_seed_relay_launched(state: Dictionary) -> void:
	_tactical_refresh = true
	objective_changed.emit(state)
	objective_event.emit("objective_relay_launched", state)
	_sync_bot_context()

func _on_seed_relay_caught(state: Dictionary) -> void:
	_tactical_refresh = true
	objective_changed.emit(state)
	objective_event.emit("objective_relay_caught", state)
	_sync_bot_context()

func _on_seed_relay_disrupted(state: Dictionary) -> void:
	_tactical_refresh = true
	objective_changed.emit(state)
	objective_event.emit("objective_relay_disrupted", state)
	_sync_bot_context()

func _request_bot_relay() -> void:
	if seed == null or seed.state != RiftSeed.State.CARRIED:
		return
	var carriers := _all_duelists()
	carriers.sort_custom(func(a: Duelist, b: Duelist) -> bool: return a.actor_id < b.actor_id)
	for candidate in carriers:
		if not candidate is BotDuelist or not candidate.is_carrying_seed():
			continue
		var aim := (candidate as BotDuelist).seed_relay_aim_direction()
		if aim.length_squared() > 0.0001 and request_seed_pass(candidate, aim):
			return

func _living_teammate_count(carrier: Duelist) -> int:
	var count := 0
	for candidate in _all_duelists():
		if candidate != carrier and candidate.team == carrier.team and not candidate.eliminated and candidate.match_active:
			count += 1
	return count

func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _clear_tactical_memory() -> void:
	_tactical_elapsed = 0.0
	_tactical_refresh = true
	for planner in _tactical_planners.values():
		if planner is RiftlineSquadTactics:
			planner.clear()

func _set_phase(next_phase: Phase) -> void:
	phase = next_phase
	_set_all_combat_active(phase == Phase.LIVE)
	phase_changed.emit(phase)

func _set_all_combat_active(active: bool) -> void:
	for duelist in _all_duelists():
		if is_instance_valid(duelist):
			duelist.set_match_active(active)

func _reset_duelists_to_cover() -> void:
	for team in [Duelist.Team.SUN, Duelist.Team.VOID]:
		var roster: Array = rosters[team]
		var points: Array = spawn_points[team]
		for index in roster.size():
			if not points.is_empty() and is_instance_valid(roster[index]):
				roster[index].respawn_at(points[posmod(index, points.size())])

func _cancel_respawns() -> void:
	for actor_id in _respawn_generation.keys():
		_respawn_generation[actor_id] = int(_respawn_generation[actor_id]) + 1

func _all_duelists() -> Array[Duelist]:
	var result: Array[Duelist] = []
	for team in [Duelist.Team.SUN, Duelist.Team.VOID]:
		for duelist in rosters[team]:
			if is_instance_valid(duelist):
				result.append(duelist)
	return result

func _is_registered(duelist: Duelist) -> bool:
	return is_instance_valid(duelist) and rosters.has(duelist.team) and duelist in rosters[duelist.team]

func _lookup_duelist(actor_id: String) -> Duelist:
	var result: Variant = _duelists_by_id.get(actor_id, null)
	return result if result is Duelist else null

func _update_carrier_flags(objective: Dictionary) -> void:
	var carrier_id := str(objective.get("carrier_id", ""))
	for duelist in _all_duelists():
		duelist.set_carrying_seed(not carrier_id.is_empty() and duelist.actor_id == carrier_id)

func _sync_bot_context() -> void:
	if seed == null:
		return
	var state := seed.authoritative_state()
	for duelist in _all_duelists():
		if duelist is not BotDuelist:
			continue
		var enemy_team := Duelist.Team.SUN if duelist.team == Duelist.Team.VOID else Duelist.Team.VOID
		var friendlies: Array[Duelist] = []
		var enemies: Array[Duelist] = []
		for candidate in _all_duelists():
			(friendlies if candidate.team == duelist.team else enemies).append(candidate)
		var public_state := _tactical_state_for_team(state, duelist.team)
		duelist.set_squad_context(friendlies, enemies, public_state, _gate_positions.get(duelist.team, Vector3.ZERO), _gate_positions.get(enemy_team, Vector3.ZERO))
		duelist.set_route_finder(_route_finder)

	if _tactical_planners.is_empty():
		return
	if not _tactical_refresh and _tactical_elapsed < 0.25:
		return
	_tactical_elapsed = 0.0
	_tactical_refresh = false
	_tactical_updates += 1
	for team in [Duelist.Team.SUN, Duelist.Team.VOID]:
		var planner: RiftlineSquadTactics = _tactical_planners.get(int(team), null)
		if planner == null:
			continue
		var members: Array[Dictionary] = []
		for candidate in rosters[team]:
			if not is_instance_valid(candidate):
				continue
			members.append({
				"actor_id": candidate.actor_id,
				"human": not candidate is BotDuelist,
				"frame_id": candidate.crew_frame_id,
				"eliminated": candidate.eliminated,
				"position": candidate.global_position,
				"carrying": candidate.carrying_seed,
			})
		var sightings: Array[Dictionary] = _carrier_sightings(team, state)
		var tactical_state := _tactical_state_for_team(state, team)
		var relay_carrier := _lookup_duelist(str(state.get("carrier_id", "")))
		if relay_carrier is BotDuelist and relay_carrier.team == team:
			for member in members:
				var relay_target := _lookup_duelist(str(member.get("actor_id", "")))
				member["direct_los"] = relay_target != null and (relay_carrier as BotDuelist).has_direct_line_of_sight_to(relay_target)
		var orders := planner.update(team, members, tactical_state, sightings, Time.get_ticks_msec() / 1000.0)
		for candidate in rosters[team]:
			if candidate is not BotDuelist:
				continue
			var order: Variant = orders.get(candidate.actor_id, {})
			if order is Dictionary and not order.is_empty() and not candidate.eliminated:
				candidate.set_tactical_order(order)
			else:
				candidate.clear_tactical_order()

func _tactical_state_for_team(state: Dictionary, team: Duelist.Team) -> Dictionary:
	var visible := state.duplicate(true)
	var carrier_team := int(state.get("carrier_team", -1))
	if carrier_team >= 0 and carrier_team != int(team):
		visible["position"] = Vector3.ZERO
	var enemy_team := Duelist.Team.VOID if team == Duelist.Team.SUN else Duelist.Team.SUN
	visible["gate_position"] = _gate_positions.get(enemy_team, Vector3.ZERO)
	visible["relay_available"] = seed != null and seed.state == RiftSeed.State.CARRIED
	return visible

func _carrier_sightings(team: Duelist.Team, state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var carrier_id := str(state.get("carrier_id", ""))
	if carrier_id.is_empty():
		return result
	var carrier := _lookup_duelist(carrier_id)
	if carrier == null or carrier.team == team:
		return result
	for observer in rosters[team]:
		if observer is BotDuelist and not observer.eliminated and observer.has_direct_line_of_sight_to(carrier):
			result.append({
				"carrier_id": carrier_id,
				"position": carrier.global_position,
				"lane": _nearest_tactical_lane(carrier.global_position),
				"expires_at": Time.get_ticks_msec() / 1000.0 + 0.8,
				"direct_los": true,
			})
			break
	return result

func _nearest_tactical_lane(position: Vector3) -> String:
	var best := "center"
	var best_distance := INF
	for lane in _tactical_facts.get("lane_posts", {}).keys():
		for post in _tactical_facts.lane_posts[lane]:
			var distance := position.distance_squared_to(post)
			if distance < best_distance:
				best_distance = distance
				best = str(lane)
	return best
