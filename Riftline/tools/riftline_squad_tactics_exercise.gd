extends SceneTree

func _initialize() -> void:
	var planner := RiftlineSquadTactics.new()
	planner.configure(_facts())
	var neutral := {"state": int(RiftSeed.State.HOME), "carrier_id": ""}
	var wing := _members(["a_bot", "b_bot", "host"], "host")
	var wing_orders := planner.update(Duelist.Team.SUN, wing, neutral, [], 0.0)
	assert(wing_orders["a_bot"].intent == "run_seed")
	assert(wing_orders["b_bot"].intent == "screen_lane")
	assert(wing_orders["b_bot"].goal != wing_orders["a_bot"].goal)

	planner.clear()
	var full := _members(["a_bot", "b_bot", "c_bot", "d_bot", "host"], "host")
	var full_orders := planner.update(Duelist.Team.SUN, full, neutral, [], 0.0)
	assert(full_orders.size() == 4)
	var goals := {}
	for order in full_orders.values():
		goals[str(order.goal)] = true
	assert(goals.size() >= 3)

	var player_carrier := neutral.duplicate()
	player_carrier["state"] = int(RiftSeed.State.CARRIED)
	player_carrier["carrier_id"] = "host"
	var player_orders := planner.update(Duelist.Team.SUN, wing, player_carrier, [], 0.1)
	assert(player_orders["a_bot"].intent in ["escort", "screen_lane"])
	assert(player_orders["b_bot"].intent in ["escort", "screen_lane"])

	var bot_carrier := player_carrier.duplicate()
	bot_carrier["carrier_id"] = "a_bot"
	var bot_orders := planner.update(Duelist.Team.SUN, wing, bot_carrier, [], 0.2)
	assert(bot_orders["a_bot"].intent == "carry_line")
	assert(bot_orders["b_bot"].intent == "escort")
	assert(bot_orders["b_bot"].goal != Vector3.ZERO)

	var dropped := {"state": int(RiftSeed.State.DROPPED), "carrier_id": ""}
	var dropped_orders := planner.update(Duelist.Team.SUN, wing, dropped, [], 0.3)
	assert(dropped_orders["a_bot"].intent == "recover_seed")
	assert(dropped_orders["a_bot"].goal != dropped_orders["b_bot"].goal)

	var sighted: Array[Dictionary] = [{"carrier_id": "void_carrier", "position": Vector3(17.0, 0.1, 25.0), "lane": "windwalk", "expires_at": 1.0, "direct_los": true}]
	var sighted_orders := planner.update(Duelist.Team.SUN, full, neutral, sighted, 0.4)
	var intercepts := 0
	var screens := 0
	for order in sighted_orders.values():
		intercepts += 1 if order.intent == "intercept_sighting" else 0
		screens += 1 if order.intent == "screen_lane" and order.route_kind == "windwalk" else 0
	assert(intercepts <= 1)
	assert(screens <= 1)

	var unseen_orders := planner.update(Duelist.Team.SUN, full, neutral, [], 2.0)
	for order in unseen_orders.values():
		assert(order.goal != Vector3(17.0, 0.1, 25.0))

	var repeat := RiftlineSquadTactics.new()
	repeat.configure(_facts())
	repeat.clear()
	var repeat_orders := repeat.update(Duelist.Team.SUN, full, neutral, [], 0.0)
	assert(_order_signature(full_orders) == _order_signature(repeat_orders))
	var eliminated := _members(["a_bot", "b_bot", "host"], "host")
	for member in eliminated:
		if member.actor_id == "a_bot":
			member["eliminated"] = true
	var no_dead := repeat.update(Duelist.Team.SUN, eliminated, neutral, [], 0.1)
	assert(not no_dead.has("a_bot"))
	repeat.clear()
	var after_clear := repeat.update(Duelist.Team.SUN, full, neutral, [], 0.0)
	for order in after_clear.values():
		assert(order.intent != "intercept_sighting")

	print("Riftline squad tactics exercise: PASS")
	quit()

func _members(ids: Array[String], human_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in ids.size():
		result.append({
			"actor_id": ids[index],
			"human": ids[index] == human_id,
			"eliminated": false,
			"position": Vector3(-20.0 + index * 8.0, 0.1, 0.0),
			"carrying": false,
		})
	return result

func _facts() -> Dictionary:
	return {
		"seed": Vector3.ZERO,
		"anchors": {
			"neutral_seed": Vector3.ZERO,
			"center_return": {"sun": Vector3(-26.0, 0.1, 0.0), "void": Vector3(26.0, 0.1, 0.0)},
			"gate_escort": {"sun": Vector3(40.0, 0.1, 0.0), "void": Vector3(-40.0, 0.1, 0.0)},
		},
		"lane_posts": {
			"windwalk": [Vector3(-30.0, 0.1, 25.0), Vector3(0.0, 0.1, 27.0), Vector3(30.0, 0.1, 25.0)],
			"relay_basin": [Vector3(-25.0, 0.1, 0.0), Vector3(0.0, 0.1, 0.0), Vector3(25.0, 0.1, 0.0)],
			"service_run": [Vector3(-30.0, 0.1, -25.0), Vector3(0.0, 0.1, -27.0), Vector3(30.0, 0.1, -25.0)],
		},
	}

func _order_signature(orders: Dictionary) -> String:
	var parts: Array[String] = []
	for actor_id in orders.keys():
		var order: Dictionary = orders[actor_id]
		parts.append("%s:%s:%s" % [actor_id, order.intent, order.route_kind])
	parts.sort()
	return ",".join(parts)
