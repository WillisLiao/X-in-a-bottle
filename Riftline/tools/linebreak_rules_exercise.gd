extends SceneTree

func _initialize() -> void:
	var root := Node.new()
	root.name = "LinebreakRulesExercise"
	root.set_process(false)
	root.set_physics_process(false)
	get_root().add_child(root)
	await process_frame

	var rules := LinebreakMatch.new()
	root.add_child(rules)
	rules.configure(Vector3.ZERO, {
		Duelist.Team.SUN: Vector3(-18.5, 0.05, 6.0),
		Duelist.Team.VOID: Vector3(18.5, 0.05, -6.0),
	}, false)
	rules.add_spawn(Duelist.Team.SUN, Vector3(-15.0, 0.1, 6.0))
	rules.add_spawn(Duelist.Team.VOID, Vector3(16.0, 0.1, -6.0))

	var sun := Duelist.new()
	sun.build(Duelist.Team.SUN, false, false, false)
	root.add_child(sun)
	var void_duelist := Duelist.new()
	void_duelist.build(Duelist.Team.VOID, false, false, false)
	root.add_child(void_duelist)
	rules.register_duelist(sun, "sun")
	rules.register_duelist(void_duelist, "void")
	sun.set_match_active(true)
	void_duelist.set_match_active(true)
	rules.begin()
	rules._set_phase(LinebreakMatch.Phase.LIVE)

	# Home claim uses nearest distance first and actor id as the stable tie-break.
	sun.global_position = Vector3.ZERO
	void_duelist.global_position = Vector3.ZERO
	rules.seed.tick_authority(0.016, [void_duelist, sun])
	assert(rules.seed.carrier_id() == "sun")
	assert(sun.is_carrying_seed())
	assert(is_equal_approx(sun.movement_speed_multiplier(), Duelist.CARRY_SPEED_MULTIPLIER))

	# A defeat drops only the carrier, and an invalidated round generation rejects its old timer.
	sun.eliminated = true
	rules._on_defeated(sun, void_duelist)
	assert(rules.seed.state == RiftSeed.State.DROPPED)
	assert(not sun.carrying_seed)
	rules._round_generation += 1
	await create_timer(LinebreakMatch.RESPAWN_DELAY_SECONDS + 0.15).timeout
	assert(sun.eliminated)

	# Dropped state returns to center only after its visible timeout.
	rules.seed.tick_authority(RiftSeed.DROP_TIMEOUT_SECONDS + 0.01, [void_duelist, sun])
	assert(rules.seed.state == RiftSeed.State.HOME)

	# The own gate is not a scoring zone; the opposing gate scores exactly once.
	sun.respawn_at(Vector3.ZERO)
	void_duelist.respawn_at(Vector3(8.0, 0.1, 0.0))
	rules._set_phase(LinebreakMatch.Phase.LIVE)
	rules.seed.reset_to_center()
	rules.seed.tick_authority(0.016, [sun, void_duelist])
	sun.global_position = Vector3(-18.5, 0.1, 6.0)
	rules.seed.tick_authority(0.016, [sun, void_duelist])
	assert(int(rules.scores[Duelist.Team.SUN]) == 0)
	sun.global_position = Vector3(18.5, 0.1, -6.0)
	rules.seed.tick_authority(0.016, [sun, void_duelist])
	assert(int(rules.scores[Duelist.Team.SUN]) == 1)
	assert(rules.phase == LinebreakMatch.Phase.INTERMISSION)

	# Two more deliveries finish the match without any elimination score.
	for _index in 2:
		rules._set_phase(LinebreakMatch.Phase.LIVE)
		sun.respawn_at(Vector3.ZERO)
		rules.seed.reset_to_center()
		rules.seed.tick_authority(0.016, [sun, void_duelist])
		sun.global_position = Vector3(18.5, 0.1, -6.0)
		rules.seed.tick_authority(0.016, [sun, void_duelist])
	assert(int(rules.scores[Duelist.Team.SUN]) == LinebreakMatch.SCORE_TO_WIN)
	assert(rules.phase == LinebreakMatch.Phase.FINISHED)
	assert(sun.global_position == Vector3(-15.0, 0.1, 6.0))
	assert(void_duelist.global_position == Vector3(16.0, 0.1, -6.0))
	assert(rules.take_rematch())
	assert(int(rules.scores[Duelist.Team.SUN]) == 0 and int(rules.scores[Duelist.Team.VOID]) == 0)
	assert(rules.phase == LinebreakMatch.Phase.OPENING)
	assert(not sun.carrying_seed and not void_duelist.carrying_seed)

	# Disconnect cleanup cannot leave a ghost carrier or a stuck objective.
	rules._set_phase(LinebreakMatch.Phase.LIVE)
	sun.respawn_at(Vector3.ZERO)
	rules.seed.reset_to_center()
	rules.seed.tick_authority(0.016, [sun, void_duelist])
	assert(rules.seed.carrier_id() == "sun")
	rules.unregister_duelist("sun")
	assert(rules.seed.state == RiftSeed.State.HOME)
	assert(rules.seed.carrier_id().is_empty())

	# A three-versus-three authority roster scores through one carrier without
	# duplicating the delivery fact.
	var squad_rules := LinebreakMatch.new()
	root.add_child(squad_rules)
	squad_rules.configure(Vector3.ZERO, {
		Duelist.Team.SUN: Vector3(-18.5, 0.05, 6.0),
		Duelist.Team.VOID: Vector3(18.5, 0.05, -6.0),
	}, false)
	squad_rules.configure_tactics({
		"seed": Vector3.ZERO,
		"anchors": {
			"neutral_seed": Vector3.ZERO,
			"center_return": {"sun": Vector3(-5.0, 0.1, 0.0), "void": Vector3(5.0, 0.1, 0.0)},
			"gate_escort": {"sun": Vector3(8.0, 0.1, 0.0), "void": Vector3(-8.0, 0.1, 0.0)},
		},
		"lane_posts": {"windwalk": [Vector3(-4.0, 0.1, 2.0)], "relay_basin": [Vector3(0.0, 0.1, 0.0)], "service_run": [Vector3(4.0, 0.1, -2.0)]},
	}, true)
	for index in 3:
		squad_rules.add_spawn(Duelist.Team.SUN, Vector3(-15.0 + index, 0.1, 6.0))
		squad_rules.add_spawn(Duelist.Team.VOID, Vector3(16.0 - index, 0.1, -6.0))
		var squad_sun: Duelist = BotDuelist.new() if index == 0 else Duelist.new()
		squad_sun.build(Duelist.Team.SUN, false, false, false)
		squad_sun.set_actor_id("sun_%d" % index)
		squad_sun.position = Vector3(-4.0 + index, 0.1, 0.0)
		root.add_child(squad_sun)
		squad_sun.set_match_active(true)
		var squad_void := _make_duelist(root, Duelist.Team.VOID, "void_%d" % index, Vector3(4.0 - index, 0.1, 0.0))
		squad_rules.register_duelist(squad_sun, squad_sun.actor_id)
		squad_rules.register_duelist(squad_void, squad_void.actor_id)
	var delivery_events := [0]
	squad_rules.objective_event.connect(func(event_type: String, _state: Dictionary) -> void:
		if event_type == "objective_delivered":
			delivery_events[0] += 1
	)
	squad_rules.begin()
	squad_rules._set_phase(LinebreakMatch.Phase.LIVE)
	var squad_carrier := squad_rules._lookup_duelist("sun_0")
	squad_carrier.position = Vector3.ZERO
	squad_rules.seed.tick_authority(0.016, squad_rules._all_duelists())
	squad_carrier.position = Vector3(18.5, 0.1, -6.0)
	squad_rules.seed.tick_authority(0.016, squad_rules._all_duelists())
	assert(int(squad_rules.scores[Duelist.Team.SUN]) == 1)
	assert(delivery_events[0] == 1)
	assert(not (squad_rules._lookup_duelist("sun_0") as BotDuelist)._tactical_order.is_empty())

	print("Riftline Linebreak rules exercise: PASS")
	quit()

func _make_duelist(root: Node, team: Duelist.Team, actor_id: String, point: Vector3) -> Duelist:
	var duelist := Duelist.new()
	duelist.build(team, false, false, false)
	duelist.set_actor_id(actor_id)
	duelist.position = point
	root.add_child(duelist)
	duelist.set_match_active(true)
	return duelist
