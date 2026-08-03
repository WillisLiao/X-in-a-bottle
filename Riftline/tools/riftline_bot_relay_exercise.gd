extends SceneTree

func _initialize() -> void:
	var root := Node3D.new()
	root.name = "RiftlineBotRelayExercise"
	get_root().add_child(root)
	await physics_frame

	var bot := BotDuelist.new()
	bot.build(Duelist.Team.SUN, false, false, true)
	bot.set_actor_id("sun_bot")
	bot.position = Vector3(-8.0, 0.1, 0.0)
	root.add_child(bot)
	bot.set_match_active(true)

	var receiver := Duelist.new()
	receiver.build(Duelist.Team.SUN, false, false, true)
	receiver.set_actor_id("sun_receiver")
	receiver.position = Vector3(4.0, 0.1, 0.0)
	root.add_child(receiver)
	receiver.set_match_active(true)

	var enemy := Duelist.new()
	enemy.build(Duelist.Team.VOID, false, false, true)
	enemy.set_actor_id("void_hidden")
	enemy.position = Vector3(30.0, 0.1, 12.0)
	root.add_child(enemy)
	enemy.set_match_active(true)

	var objective := {"state": int(RiftSeed.State.CARRIED), "carrier_id": bot.actor_id}
	bot.set_squad_context([bot, receiver], [enemy], objective, Vector3(24.0, 0.1, 0.0), Vector3(24.0, 0.1, 0.0))
	bot.set_tactical_order({"intent": RiftlineSquadTactics.INTENT_RELAY_SUPPORT, "target_id": receiver.actor_id})
	bot.set_carrying_seed(true)
	await physics_frame
	assert(bot.seed_relay_aim_direction().length_squared() > 0.9)

	var wall := _make_solid(root, Vector3(-2.0, 1.0, 0.0), Vector3(0.6, 2.0, 4.0))
	await physics_frame
	assert(bot.seed_relay_aim_direction() == Vector3.ZERO)
	_free_node(wall)
	await physics_frame

	receiver.position = Vector3(24.0, 0.1, 0.0)
	await physics_frame
	assert(bot.seed_relay_aim_direction() == Vector3.ZERO)
	bot.set_tactical_order({"intent": RiftlineSquadTactics.INTENT_RELAY_SUPPORT, "target_id": "missing"})
	assert(bot.seed_relay_aim_direction() == Vector3.ZERO)

	print("Riftline bot relay exercise: PASS")
	root.free()
	quit()

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

func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.free()
