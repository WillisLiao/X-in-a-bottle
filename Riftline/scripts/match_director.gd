class_name MatchDirector
extends Node

signal score_changed(sun: int, void_score: int)
signal respawn_started(victim: Duelist)

const TEAM_SIZE := 1
const SCORE_TO_WIN := 5
const RESPAWN_DELAY := 1.25

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

func add_spawn(team: Duelist.Team, point: Vector3) -> void:
	spawn_points[team].append(point)

func register_duelist(duelist: Duelist) -> void:
	rosters[duelist.team].append(duelist)
	duelist.defeated.connect(_on_defeated)

func _on_defeated(victim: Duelist, killer: Duelist) -> void:
	if killer != null:
		scores[killer.team] += 1
		score_changed.emit(scores[Duelist.Team.SUN], scores[Duelist.Team.VOID])
	respawn_started.emit(victim)
	_respawn_after_delay(victim)

func _respawn_after_delay(victim: Duelist) -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	var points: Array = spawn_points[victim.team]
	if points.is_empty():
		return
	var team_roster: Array = rosters[victim.team]
	var roster_index: int = team_roster.find(victim)
	victim.respawn_at(points[posmod(roster_index, points.size())])
