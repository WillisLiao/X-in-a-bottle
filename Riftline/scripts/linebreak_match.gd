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

func add_spawn(team: Duelist.Team, point: Vector3) -> void:
	spawn_points[team].append(point)

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
		seed.apply_presentation_state(objective, Callable(self, "_lookup_duelist"))
		_update_carrier_flags(objective)
		objective_changed.emit(objective)
	if phase_changed_locally:
		_set_phase(phase)
	score_changed.emit(scores[Duelist.Team.SUN], scores[Duelist.Team.VOID])

func objective_state() -> Dictionary:
	return seed.authoritative_state() if seed != null else {}

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
		seed.tick_authority(delta, _all_duelists())
		_sync_bot_context()
		seed.apply_presentation_state(seed.authoritative_state(), Callable(self, "_lookup_duelist"))

func _start_opening() -> void:
	_round_generation += 1
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
	respawn_started.emit(victim)

func _on_seed_claimed(carrier: Duelist) -> void:
	carrier.set_carrying_seed(true)
	objective_changed.emit(seed.authoritative_state())
	objective_event.emit("objective_claimed", seed.authoritative_state())
	_sync_bot_context()

func _on_seed_dropped(position: Vector3) -> void:
	objective_changed.emit(seed.authoritative_state())
	objective_event.emit("objective_dropped", seed.authoritative_state())
	_sync_bot_context()

func _on_seed_returned() -> void:
	objective_changed.emit(seed.authoritative_state())
	objective_event.emit("objective_returned", seed.authoritative_state())
	_sync_bot_context()

func _on_seed_delivered(carrier: Duelist, scoring_team: Duelist.Team, gate_position: Vector3) -> void:
	if phase != Phase.LIVE or carrier == null or not carrier.is_carrying_seed():
		return
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
		if duelist is BotDuelist:
			var enemy_team := Duelist.Team.SUN if duelist.team == Duelist.Team.VOID else Duelist.Team.VOID
			duelist.set_linebreak_context(state, _gate_positions.get(duelist.team, Vector3.ZERO), _gate_positions.get(enemy_team, Vector3.ZERO))
