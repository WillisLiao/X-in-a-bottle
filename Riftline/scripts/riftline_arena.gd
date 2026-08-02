class_name RiftlineArena
extends Node3D

const PULP_LIT := preload("res://shaders/pulp_lit.gdshader")
const SUN_COVER_SPAWN := Vector3(-15.0, 0.1, 6.0)
const VOID_COVER_SPAWN := Vector3(16.0, 0.1, -6.0)
const OPENING_HOLD_SECONDS := 2.5

var player: Duelist
var bot: BotDuelist
var hud: DuelHud
var director: MatchDirector
var _mouse_captured := false
var _capture_path := ""
var _capture_after := 2.0
var _capture_settings := false
var _capture_hud_layout := false
var _capture_character := false
var _capture_overview := false

func _ready() -> void:
	_build_environment()
	_build_arena()
	_build_match()
	_build_hud()
	_read_capture_arguments()
	if not _capture_path.is_empty():
		_capture_after_delay()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement := hud.movement if hud.movement.length_squared() > 0.001 else keyboard
	player.apply_look(hud.take_look_delta())
	if hud.gyro_enabled:
		var gyroscope := Input.get_gyroscope()
		player.apply_look(Vector2(gyroscope.y, -gyroscope.x) * 2.4)
	if hud.take_crouch():
		player.toggle_crouch()
	if hud.take_prone():
		player.toggle_prone()
	if hud.take_weapon_switch():
		player.switch_weapon()
	player.set_combat_pose(hud.aim_held, delta)
	player.drive(movement, hud.fire_held or Input.is_action_pressed("fire"), hud.take_jump() or Input.is_action_just_pressed("jump"), delta)
	hud.set_stance(player.stance)
	hud.set_weapon(player.weapon)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_captured = event.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and _mouse_captured:
		player.apply_look(event.relative)

func _build_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("102346")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8ea8cf")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-56, -28, 0)
	key.light_color = Color("ffe0b5")
	key.light_energy = 1.35
	key.shadow_enabled = true
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(10, 5, -4)
	rim.light_color = Color("ec6a4c")
	rim.light_energy = 2.2
	rim.omni_range = 17.0
	add_child(rim)

	var fill := OmniLight3D.new()
	fill.position = Vector3(-10, 5, 4)
	fill.light_color = Color("72b9ea")
	fill.light_energy = 2.0
	fill.omni_range = 17.0
	add_child(fill)

func _build_arena() -> void:
	_add_solid_box(Vector3(0, -0.5, 0), Vector3(44, 1, 32), Color("3d547c"), 0.0)
	_add_solid_box(Vector3(0, 3, -16), Vector3(44, 6, 1), Color("28496e"), 0.0)
	_add_solid_box(Vector3(0, 3, 16), Vector3(44, 6, 1), Color("28496e"), 0.0)
	_add_solid_box(Vector3(-22, 3, 0), Vector3(1, 6, 32), Color("28496e"), 0.0)
	_add_solid_box(Vector3(22, 3, 0), Vector3(1, 6, 32), Color("28496e"), 0.0)

	# Four asymmetric blockers create sight-line decisions now and still read as lanes in a five-person match.
	_add_solid_box(Vector3(-4, 1.7, -5), Vector3(3.2, 3.4, 3.2), Color("bd7254"), 0.0)
	_add_solid_box(Vector3(5, 1.7, 4), Vector3(3.2, 3.4, 3.2), Color("d39a52"), 0.0)
	_add_solid_box(Vector3(-10, 1.1, 6), Vector3(2.0, 2.2, 6.2), Color("496f8e"), 0.0)
	_add_solid_box(Vector3(11, 1.1, -6), Vector3(2.0, 2.2, 6.2), Color("496f8e"), 0.0)
	_add_pulp_cylinder(Vector3(-4, 4.2, -5), 0.9, 1.7, Color("e5b46b"))
	_add_pulp_cylinder(Vector3(5, 4.2, 4), 0.9, 1.7, Color("e5b46b"))
	_add_emissive_rail(Vector3(0, 0.06, -10), Vector3(28, 0.08, 0.08), Color("a7dced"))
	_add_emissive_rail(Vector3(0, 0.06, 10), Vector3(28, 0.08, 0.08), Color("f4a55e"))
	_add_emissive_rail(Vector3(-15, 0.06, 0), Vector3(0.08, 0.08, 20), Color("a7dced"))
	_add_emissive_rail(Vector3(15, 0.06, 0), Vector3(0.08, 0.08, 20), Color("f4a55e"))

func _build_match() -> void:
	director = MatchDirector.new()
	add_child(director)
	# Each duelist begins with its gray lane block between it and the center.
	# This makes the first action a deliberate peek rather than an instant sight-line.
	director.add_spawn(Duelist.Team.SUN, SUN_COVER_SPAWN)
	director.add_spawn(Duelist.Team.VOID, VOID_COVER_SPAWN)

	player = Duelist.new()
	player.name = "SunDuelist"
	player.build(Duelist.Team.SUN, true)
	player.position = SUN_COVER_SPAWN
	player.rotation.y = -PI * 0.5
	add_child(player)
	director.register_duelist(player)

	bot = BotDuelist.new()
	bot.name = "VoidDuelist"
	bot.build(Duelist.Team.VOID, false)
	bot.position = VOID_COVER_SPAWN
	bot.rotation.y = PI * 0.5
	bot.target = player
	bot.hold_opening_position(OPENING_HOLD_SECONDS)
	add_child(bot)
	director.register_duelist(bot)

	player.shot.connect(_show_shot)
	bot.shot.connect(_show_shot)
	player.damaged.connect(_on_player_damaged)
	director.score_changed.connect(_on_score_changed)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = DuelHud.new()
	layer.add_child(hud)

func _on_player_damaged(_amount: float, remaining: float) -> void:
	hud.show_damage(remaining)

func _on_score_changed(sun: int, void_score: int) -> void:
	hud.set_score(sun, void_score)

func _show_shot(origin: Vector3, end: Vector3, team: Duelist.Team) -> void:
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.025
	mesh.bottom_radius = 0.025
	mesh.height = origin.distance_to(end)
	beam.mesh = mesh
	beam.material_override = _pulp_material(Color("ffb15c") if team == Duelist.Team.SUN else Color("75dbff"), 6.0)
	beam.position = origin.lerp(end, 0.5)
	add_child(beam)
	beam.look_at(end, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	_remove_beam(beam)

func _remove_beam(beam: MeshInstance3D) -> void:
	await get_tree().create_timer(0.055).timeout
	beam.queue_free()

func _add_solid_box(position: Vector3, dimensions: Vector3, color: Color, emission: float) -> void:
	var body := StaticBody3D.new()
	body.position = position
	add_child(body)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh_instance.mesh = box
	mesh_instance.material_override = _pulp_material(color, emission)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)

func _add_emissive_rail(position: Vector3, dimensions: Vector3, color: Color) -> void:
	var rail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	rail.mesh = box
	rail.position = position
	rail.material_override = _pulp_material(color, 5.5)
	add_child(rail)

func _add_pulp_cylinder(position: Vector3, radius: float, height: float, color: Color) -> void:
	var cylinder := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.82
	mesh.bottom_radius = radius
	mesh.height = height
	cylinder.mesh = mesh
	cylinder.position = position
	cylinder.material_override = _pulp_material(color, 0.0)
	add_child(cylinder)

func _pulp_material(color: Color, glow: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PULP_LIT
	material.set_shader_parameter("base_tint", color)
	material.set_shader_parameter("shadow_tint", Color("10213d").lerp(color, 0.2))
	material.set_shader_parameter("rim_tint", Color("dce9ef") if glow <= 0.0 else color)
	material.set_shader_parameter("rim_strength", 0.14 if glow <= 0.0 else 0.28)
	material.set_shader_parameter("glow_strength", glow)
	material.set_shader_parameter("brush_scale", 1.3)
	return material

func _read_capture_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--after="):
			_capture_after = maxf(0.2, argument.trim_prefix("--after=").to_float())
		elif argument == "--settings":
			_capture_settings = true
		elif argument == "--hud-layout":
			_capture_hud_layout = true
		elif argument == "--character":
			_capture_character = true
		elif argument == "--overview":
			_capture_overview = true
	if _capture_settings:
		hud.open_settings()
	if _capture_hud_layout:
		hud.open_hud_layout()
	if _capture_character:
		# This is a renderer-only inspection hook for silhouette review, not an alternate gameplay state.
		bot.position = Vector3(-6.0, 0.1, 0.0)
		bot.set_physics_process(false)
	if _capture_overview:
		# A renderer-only inspection hook that lets captures verify both spawn halves at once.
		player.camera.cull_mask = 1 | 2
		player.camera.global_position = Vector3(0.0, 31.0, 27.0)
		player.camera.look_at(Vector3(0.0, 0.0, 0.0))

func _capture_after_delay() -> void:
	await get_tree().create_timer(_capture_after).timeout
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_capture_path)
	if error != OK:
		push_error("Could not write Riftline capture: %s" % _capture_path)
	get_tree().quit()
