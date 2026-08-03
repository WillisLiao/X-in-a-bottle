extends SceneTree

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "RiftlineSeedRelayExercise"
	get_root().add_child(root)
	await physics_frame

	assert(int(RiftSeed.State.HOME) == 0)
	assert(int(RiftSeed.State.CARRIED) == 1)
	assert(int(RiftSeed.State.DROPPED) == 2)
	assert(int(RiftSeed.State.IN_FLIGHT) == 3)

	var rules := _make_rules(root)
	var source := _make_duelist(root, Duelist.Team.SUN, "sun_a", Vector3.ZERO)
	var receiver_b := _make_duelist(root, Duelist.Team.SUN, "sun_b", Vector3(6.0, 0.1, 0.0))
	var receiver_c := _make_duelist(root, Duelist.Team.SUN, "sun_c", Vector3(6.0, 0.1, 0.0))
	var enemy := _make_duelist(root, Duelist.Team.VOID, "void_a", Vector3(30.0, 0.1, 0.0))
	for actor in [source, receiver_b, receiver_c, enemy]:
		rules.register_duelist(actor, actor.actor_id)
	rules.begin()
	rules._set_phase(LinebreakMatch.Phase.LIVE)

	assert(not rules.request_seed_pass(source, Vector3(INF, INF, INF)))
	assert(not rules.request_seed_pass(source, Vector3.ZERO))
	rules.seed.tick_authority(0.016, rules._all_duelists())
	assert(rules.seed.state == RiftSeed.State.CARRIED)
	assert(not rules.request_seed_pass(source, Vector3(NAN, 0.0, 0.0)))
	assert(not rules.request_seed_pass(receiver_b, Vector3.RIGHT))

	var original_weapon := source.weapon
	var original_health := source.health
	var launched := [0]
	var caught := [0]
	rules.objective_event.connect(func(event_type: String, _state: Dictionary) -> void:
		if event_type == "objective_relay_launched":
			launched[0] += 1
		elif event_type == "objective_relay_caught":
			caught[0] += 1
	)
	assert(rules.request_seed_pass(source, Vector3.RIGHT))
	assert(rules.seed.state == RiftSeed.State.IN_FLIGHT)
	assert(not source.is_carrying_seed())
	assert(source.weapon == original_weapon and is_equal_approx(source.health, original_health))
	assert(launched[0] == 1)
	rules.seed.tick_authority(0.32, rules._all_duelists())
	assert(rules.seed.state == RiftSeed.State.CARRIED)
	assert(rules.seed.carrier_id() == "sun_b")
	assert(receiver_b.is_carrying_seed())
	assert(not receiver_c.is_carrying_seed())
	assert(caught[0] == 1)
	assert(not rules.request_seed_pass(source, Vector3.RIGHT))

	var client_frame := source.make_input_frame(1, Vector2.ZERO, false, false, false, false, false, false, false, true)
	assert(bool(client_frame.pass_seed))
	assert(rules.seed.state == RiftSeed.State.CARRIED)
	var network := RiftlineNetwork.new()
	root.add_child(network)
	client_frame["protocol"] = 4
	assert(network._validate_input(1, client_frame).is_empty())
	client_frame["protocol"] = RiftlineNetwork.PROTOCOL_VERSION
	assert(not network._validate_input(1, client_frame).is_empty())

	var barrier := _make_solid(root, Vector3(5.0, 1.0, 0.0), Vector3(0.6, 2.0, 4.0))
	await physics_frame
	rules.seed.reset_to_center()
	rules.seed.tick_authority(0.5, rules._all_duelists())
	source.respawn_at(Vector3.ZERO)
	receiver_b.respawn_at(Vector3(12.0, 0.1, 0.0))
	receiver_c.eliminated = true
	rules.seed.tick_authority(0.016, rules._all_duelists())
	assert(rules.request_seed_pass(source, Vector3.RIGHT))
	rules.seed.tick_authority(0.45, rules._all_duelists())
	assert(int(rules.seed.state) == int(RiftSeed.State.DROPPED))
	assert(rules.seed.global_position.x < 5.0)
	barrier.queue_free()
	await physics_frame

	receiver_c.eliminated = false
	var enemy_body := enemy
	enemy_body.global_position = Vector3(5.0, 0.1, 0.0)
	receiver_b.global_position = Vector3(12.0, 0.1, 0.0)
	receiver_c.global_position = Vector3(12.0, 0.1, 0.0)
	await physics_frame
	rules.seed.reset_to_center()
	rules.seed.tick_authority(0.5, rules._all_duelists())
	source.respawn_at(Vector3.ZERO)
	rules.seed.tick_authority(0.016, rules._all_duelists())
	assert(rules.request_seed_pass(source, Vector3.RIGHT))
	rules.seed.tick_authority(0.45, rules._all_duelists())
	assert(int(rules.seed.state) == int(RiftSeed.State.DROPPED))
	assert(not enemy.is_carrying_seed())

	enemy_body.global_position = Vector3(30.0, 0.1, 0.0)
	receiver_b.global_position = Vector3(30.0, 0.1, 5.0)
	receiver_c.global_position = Vector3(30.0, 0.1, -5.0)
	rules.seed.reset_to_center()
	rules.seed.tick_authority(0.5, rules._all_duelists())
	source.respawn_at(Vector3.ZERO)
	rules.seed.tick_authority(0.016, rules._all_duelists())
	assert(rules.request_seed_pass(source, Vector3.RIGHT))
	rules.seed.tick_authority(0.8, rules._all_duelists())
	assert(rules.seed.state == RiftSeed.State.DROPPED)
	assert(int(rules.scores[Duelist.Team.SUN]) == 0)

	var replica := RiftSeed.new()
	root.add_child(replica)
	replica.configure(Vector3.ZERO, {}, false)
	replica.apply_presentation_state({"state": int(RiftSeed.State.IN_FLIGHT), "position": Vector3(2.0, 2.0, 0.0), "velocity": Vector3.RIGHT, "pass_team": int(Duelist.Team.SUN), "flight_token": 2, "lifecycle_token": 12}, Callable())
	assert(not replica.accepts_presentation_state({"state": int(RiftSeed.State.IN_FLIGHT), "flight_token": 1, "lifecycle_token": 12}))
	replica.apply_presentation_state({"state": int(RiftSeed.State.DROPPED), "position": Vector3.ZERO, "flight_token": 1, "lifecycle_token": 11}, Callable())
	assert(replica.state == RiftSeed.State.IN_FLIGHT)
	assert(int(replica.authoritative_state().flight_token) == 2)

	var hud := DuelHud.new()
	root.add_child(hud)
	hud.reload_remaining = 0.0
	assert(not hud.reload_indicator_animates())
	hud.reload_remaining = 0.2
	assert(hud.reload_indicator_animates())
	hud.reload_remaining = 0.0
	assert(not hud.reload_indicator_animates())

	print("Riftline Seed relay exercise: PASS")
	root.free()
	quit()

func _make_rules(root: Node3D) -> LinebreakMatch:
	var rules := LinebreakMatch.new()
	root.add_child(rules)
	rules.configure(Vector3.ZERO, {Duelist.Team.SUN: Vector3(-20.0, 0.05, 0.0), Duelist.Team.VOID: Vector3(20.0, 0.05, 0.0)}, false)
	for team in [Duelist.Team.SUN, Duelist.Team.VOID]:
		rules.add_spawn(team, Vector3.ZERO)
	return rules

func _make_duelist(root: Node3D, team: Duelist.Team, actor_id: String, point: Vector3) -> Duelist:
	var duelist := Duelist.new()
	duelist.build(team, false, false, true)
	duelist.set_actor_id(actor_id)
	duelist.position = point
	root.add_child(duelist)
	duelist.set_match_active(true)
	return duelist

func _make_solid(root: Node3D, point: Vector3, dimensions: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = point
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body
