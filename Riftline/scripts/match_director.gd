class_name MatchDirector
extends Node

signal score_changed(sun: int, void_score: int)
signal phase_changed(phase: Phase)
signal match_finished(winner: Duelist.Team)
signal respawn_started(victim: Duelist)

enum Phase { OPENING, LIVE, INTERMISSION, FINISHED }

const TEAM_SIZE := 1
const SCORE_TO_WIN := 5
const OPENING_HOLD_SECONDS := 2.5
const INTERMISSION_SECONDS := 1.25

var rosters: Dictionary = {
	Duelist.Team.SUN: [],
	Duelist.Team.VOID: [],
}
var scores: Dictionary = {
	Duelist.Team.SUN: 0,
	Duelist.Team.VOID: 0,
}
var spawn_points: Dictionary = {
	Duelist.Team.SUN: [],
	Duelist.Team.VOID: [],
}
var phase: Phase = Phase.OPENING

var _round_generation := 0
var _started := false
var _winner: Duelist.Team = Duelist.Team.SUN

func add_spawn(team: Duelist.Team, point: Vector3) -> void:
	spawn_points[team].append(point)

func register_duelist(duelist: Duelist) -> void:
	if duelist in rosters[duelist.team]:
		return
	rosters[duelist.team].append(duelist)
	duelist.defeated.connect(_on_defeated)

func begin() -> void:
	if _started:
		return
	_started = true
	_start_round()

func is_live() -> bool:
	return phase == Phase.LIVE

func take_rematch() -> bool:
	if phase != Phase.FINISHED:
		return false
	scores[Duelist.Team.SUN] = 0
	scores[Duelist.Team.VOID] = 0
	score_changed.emit(0, 0)
	_start_round()
	return true

func _start_round() -> void:
	_round_generation += 1
	var generation := _round_generation
	_set_phase(Phase.OPENING)
	_reset_duelists_to_cover()
	for duelist in _all_duelists():
		duelist.set_match_active(false)
		if duelist is BotDuelist:
			duelist.hold_opening_position(OPENING_HOLD_SECONDS)
	_opening_gate(generation)

func _opening_gate(generation: int) -> void:
	await get_tree().create_timer(OPENING_HOLD_SECONDS).timeout
	if generation != _round_generation or phase != Phase.OPENING:
		return
	_set_phase(Phase.LIVE)

func _on_defeated(victim: Duelist, killer: Duelist) -> void:
	if phase != Phase.LIVE:
		return
	if not _is_registered(victim) or not _is_registered(killer):
		return
	if killer == victim or killer.team == victim.team:
		return
	var winning_team := killer.team
	scores[winning_team] = mini(SCORE_TO_WIN, int(scores[winning_team]) + 1)
	score_changed.emit(scores[Duelist.Team.SUN], scores[Duelist.Team.VOID])
	_set_all_combat_active(false)
	if scores[winning_team] >= SCORE_TO_WIN:
		_winner = winning_team
		_set_phase(Phase.FINISHED)
		match_finished.emit(_winner)
		return
	_set_phase(Phase.INTERMISSION)
	respawn_started.emit(victim)
	_intermission(_round_generation)

func _intermission(generation: int) -> void:
	await get_tree().create_timer(INTERMISSION_SECONDS).timeout
	if generation != _round_generation or phase != Phase.INTERMISSION:
		return
	_start_round()

func _reset_duelists_to_cover() -> void:
	for team in [Duelist.Team.SUN, Duelist.Team.VOID]:
		var roster: Array = rosters[team]
		var points: Array = spawn_points[team]
		for index in roster.size():
			if points.is_empty():
				continue
			roster[index].respawn_at(points[posmod(index, points.size())])

func _set_all_combat_active(active: bool) -> void:
	for duelist in _all_duelists():
		duelist.set_match_active(active)

func _all_duelists() -> Array:
	var result: Array = []
	result.append_array(rosters[Duelist.Team.SUN])
	result.append_array(rosters[Duelist.Team.VOID])
	return result

func _is_registered(duelist: Duelist) -> bool:
	return duelist != null and duelist in rosters[duelist.team]

func _set_phase(next_phase: Phase) -> void:
	phase = next_phase
	if phase == Phase.LIVE:
		_set_all_combat_active(true)
	else:
		_set_all_combat_active(false)
	phase_changed.emit(phase)
