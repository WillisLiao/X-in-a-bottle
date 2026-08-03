class_name RiftlineSquadTactics
extends RefCounted

## Authority-only, value-based crew planning for offline Linebreak drills.
## This module deliberately knows nothing about nodes, physics, or the scene tree.

const INTENT_RUN := "run_seed"
const INTENT_CARRY := "carry_line"
const INTENT_ESCORT := "escort"
const INTENT_SCREEN := "screen_lane"
const INTENT_RETURN := "hold_return"
const INTENT_INTERCEPT := "intercept_sighting"
const INTENT_RECOVER := "recover_seed"
const INTENT_RESET := "reset_center"
const INTENT_RELAY_SUPPORT := "relay_support"

var _facts: Dictionary = {}
var _sightings: Dictionary = {}
var _last_orders: Dictionary = {}
var _round_generation := 0

func configure(map_facts: Dictionary) -> void:
	_facts = map_facts.duplicate(true)
	clear()

func clear() -> void:
	_sightings.clear()
	_last_orders.clear()
	_round_generation += 1

func update(team: Duelist.Team, members: Array[Dictionary], objective: Dictionary, sightings: Array[Dictionary], elapsed: float) -> Dictionary:
	_prune_sightings(elapsed)
	for sighting in sightings:
		if not sighting is Dictionary:
			continue
		if not bool(sighting.get("direct_los", false)):
			continue
		var carrier_id := str(sighting.get("carrier_id", ""))
		var expires_at := float(sighting.get("expires_at", elapsed))
		if carrier_id.is_empty() or expires_at <= elapsed:
			continue
		_sightings[carrier_id] = {
			"carrier_id": carrier_id,
			"position": sighting.get("position", Vector3.ZERO),
			"lane": str(sighting.get("lane", "center")),
			"expires_at": expires_at,
		}

	var living: Array[Dictionary] = []
	for member in members:
		if not member is Dictionary or bool(member.get("eliminated", false)):
			continue
		if str(member.get("actor_id", "")).is_empty():
			continue
		living.append(member)
	living.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("actor_id", "")) < str(b.get("actor_id", ""))
	)

	var orders: Dictionary = {}
	if living.size() <= 1:
		_plan_solo(orders, living, objective, elapsed)
	else:
		_plan_crew(orders, team, living, objective, elapsed)
	_last_orders = orders.duplicate(true)
	return orders.duplicate(true)

func _plan_solo(orders: Dictionary, living: Array[Dictionary], objective: Dictionary, elapsed: float) -> void:
	if living.is_empty():
		return
	var member := living[0]
	if bool(member.get("human", false)):
		return
	var actor_id := str(member.get("actor_id", ""))
	var carrier_id := str(objective.get("carrier_id", ""))
	if carrier_id == actor_id:
		orders[actor_id] = _order(INTENT_CARRY, _anchor("gate_escort", Duelist.Team.VOID), "center", elapsed)
		return
	var sighting := _best_sighting()
	if not sighting.is_empty():
		orders[actor_id] = _order(INTENT_INTERCEPT, _lane_post(str(sighting.get("lane", "center")), Duelist.Team.SUN, 0), str(sighting.get("lane", "center")), elapsed)
		return
	var state := int(objective.get("state", int(RiftSeed.State.HOME)))
	if state == int(RiftSeed.State.HOME) or state == int(RiftSeed.State.DROPPED):
		orders[actor_id] = _order(INTENT_RUN if state == int(RiftSeed.State.HOME) else INTENT_RECOVER, _anchor("neutral_seed", Duelist.Team.SUN), "center", elapsed)
	else:
		orders[actor_id] = _order(INTENT_RESET, _anchor("center_return", Duelist.Team.SUN), "center", elapsed)

func _plan_crew(orders: Dictionary, team: Duelist.Team, living: Array[Dictionary], objective: Dictionary, elapsed: float) -> void:
	var bots: Array[Dictionary] = []
	for member in living:
		if not bool(member.get("human", false)):
			bots.append(member)
	if bots.is_empty():
		return

	var friendly_carrier := _member_with_id(living, str(objective.get("carrier_id", "")))
	var state := int(objective.get("state", int(RiftSeed.State.HOME)))
	var enemy_sighting := _best_sighting()
	var assigned: Dictionary = {}

	if friendly_carrier.is_empty():
		var intent := INTENT_RECOVER if state == int(RiftSeed.State.DROPPED) else INTENT_RUN
		assigned[_actor_id(bots[0])] = _order(intent, _anchor("neutral_seed", team), "center", elapsed)
		if bots.size() > 1:
			assigned[_actor_id(bots[1])] = _order(INTENT_SCREEN, _lane_post(_lane_for_index(0, team), team, 0), _lane_for_index(0, team), elapsed)
		if bots.size() > 2:
			assigned[_actor_id(bots[2])] = _order(INTENT_RETURN, _anchor("center_return", team), "center", elapsed)
	else:
		var carrier_is_human := bool(friendly_carrier.get("human", false))
		if not carrier_is_human:
			var relay_target := _relay_target(living, friendly_carrier, objective)
			if not relay_target.is_empty():
				assigned[_actor_id(friendly_carrier)] = _order(INTENT_RELAY_SUPPORT, relay_target.get("position", Vector3.ZERO), "relay", elapsed)
				assigned[_actor_id(friendly_carrier)]["target_id"] = _actor_id(relay_target)
			else:
				assigned[_actor_id(friendly_carrier)] = _order(INTENT_CARRY, _anchor("gate_escort", team), "center", elapsed)
		var first_bot := bots[0]
		if _actor_id(first_bot) == _actor_id(friendly_carrier) and bots.size() > 1:
			first_bot = bots[1]
		if not _actor_id(first_bot).is_empty():
			assigned[_actor_id(first_bot)] = _order(INTENT_ESCORT, _anchor("gate_escort", team), "escort", elapsed)
		var second_bot := _next_unassigned(bots, assigned)
		if not second_bot.is_empty():
			assigned[_actor_id(second_bot)] = _order(INTENT_SCREEN, _lane_post(_lane_for_index(0, team), team, 1), _lane_for_index(0, team), elapsed)

	if not enemy_sighting.is_empty():
		var intercept_bot := _next_unassigned(bots, assigned)
		if not intercept_bot.is_empty():
			assigned[_actor_id(intercept_bot)] = _order(INTENT_INTERCEPT, _lane_post(str(enemy_sighting.get("lane", "center")), team, 0), str(enemy_sighting.get("lane", "center")), elapsed)
		var support_bot := _next_unassigned(bots, assigned)
		if not support_bot.is_empty():
			assigned[_actor_id(support_bot)] = _order(INTENT_SCREEN, _lane_post(str(enemy_sighting.get("lane", "center")), team, 1), str(enemy_sighting.get("lane", "center")), elapsed)

	for bot in bots:
		var actor_id := _actor_id(bot)
		if not assigned.has(actor_id):
			var lane_index := assigned.size() % 3
			assigned[actor_id] = _order(INTENT_RETURN if lane_index == 2 else INTENT_SCREEN, _lane_post(_lane_for_index(lane_index, team), team, lane_index), _lane_for_index(lane_index, team), elapsed)
	for actor_id in assigned.keys():
		orders[actor_id] = assigned[actor_id]

func _order(intent: String, goal: Vector3, route_kind: String, elapsed: float) -> Dictionary:
	return {
		"intent": intent,
		"goal": goal,
		"fallback_goal": _anchor("center_return", Duelist.Team.SUN),
		"route_kind": route_kind,
		"expires_at": elapsed + 0.85,
		"round_generation": _round_generation,
	}

func _best_sighting() -> Dictionary:
	var candidates: Array[Dictionary] = []
	for value in _sightings.values():
		candidates.append(value)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("carrier_id", "")) < str(b.get("carrier_id", ""))
	)
	return candidates[0] if not candidates.is_empty() else {}

func _prune_sightings(elapsed: float) -> void:
	for carrier_id in _sightings.keys().duplicate():
		if float(_sightings[carrier_id].get("expires_at", 0.0)) <= elapsed:
			_sightings.erase(carrier_id)

func _member_with_id(members: Array[Dictionary], actor_id: String) -> Dictionary:
	if actor_id.is_empty():
		return {}
	for member in members:
		if _actor_id(member) == actor_id:
			return member
	return {}

func _next_unassigned(members: Array[Dictionary], assigned: Dictionary) -> Dictionary:
	for member in members:
		if not assigned.has(_actor_id(member)):
			return member
	return {}

func _relay_target(living: Array[Dictionary], carrier: Dictionary, objective: Dictionary) -> Dictionary:
	if not bool(objective.get("relay_available", false)):
		return {}
	var gate_position: Vector3 = objective.get("gate_position", Vector3.ZERO)
	var carrier_position: Vector3 = carrier.get("position", Vector3.ZERO)
	var candidates: Array[Dictionary] = []
	for member in living:
		if _actor_id(member) == _actor_id(carrier) or bool(member.get("carrying", false)):
			continue
		var position: Vector3 = member.get("position", Vector3.ZERO)
		if position.distance_to(carrier_position) > RiftSeed.RELAY_RANGE:
			continue
		if not bool(member.get("direct_los", false)):
			continue
		if position.distance_squared_to(gate_position) >= carrier_position.distance_squared_to(gate_position):
			continue
		candidates.append(member)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _actor_id(a) < _actor_id(b))
	return candidates[0] if not candidates.is_empty() else {}

func _actor_id(member: Dictionary) -> String:
	return str(member.get("actor_id", ""))

func _lane_for_index(index: int, team: Duelist.Team) -> String:
	var lanes := ["windwalk", "relay_basin", "service_run"]
	var rotation := posmod(_round_generation + int(team), lanes.size())
	return lanes[posmod(index + rotation, lanes.size())]

func _lane_post(lane: String, team: Duelist.Team, offset: int) -> Vector3:
	var lane_posts: Array = _facts.get("lane_posts", {}).get(lane, [])
	if lane_posts.is_empty():
		return _anchor("center_return", team)
	var index := posmod(offset + (0 if team == Duelist.Team.SUN else lane_posts.size() / 2), lane_posts.size())
	return lane_posts[index]

func _anchor(name: String, team: Duelist.Team) -> Vector3:
	var anchors: Dictionary = _facts.get("anchors", {})
	var team_key := "sun" if team == Duelist.Team.SUN else "void"
	var value: Variant = anchors.get(name, null)
	if value is Dictionary:
		return value.get(team_key, Vector3.ZERO)
	if value is Vector3:
		return value
	return _facts.get("seed", Vector3.ZERO)
