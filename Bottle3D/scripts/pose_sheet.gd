extends Node3D

## A pose sheet, for tuning a swing.
##
## Animation cannot be tuned from a single screenshot of a world where every elf
## is at a different random phase and half of them are walking. This lays one row
## of elves out side by side, each frozen at a fixed point in the same swing, so
## the whole arc is visible at once and a tool passing through somebody's head is
## obvious rather than a thing you find out about later.
##
## Not part of the app. Run it with:
##   Godot --path . res://PoseSheet.tscn -- --capture=/tmp/sheet.png
##   --tool=pick|axe|sickle|shovel|saw|hammer  --motion=swing|sweep|press
##   --frames=8  --side (to view from the side)
##   --yaw=45 (any angle instead, which is how the app actually sees them)
##
## A slab stands in front of each figure at the spot the swing is aimed at, and
## the ground is drawn, because half of what makes a swing wrong is that it
## lands somewhere other than the work, and neither of those is visible against
## black.

const FRAMES := 8

## Where the blow is meant to land, from the elf's own feet. Kept here rather
## than imported so that a swing which has drifted shows up as a gap.
const WORK_AT := Vector3(0.0, 0.06, 0.375)

var _capture := ""
var _tool := "pick"
var _motion := "swing"
var _frames := FRAMES
var _side := false
var _yaw := 0.0
var _shot := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture = arg.trim_prefix("--capture=")
		elif arg.begins_with("--tool="):
			_tool = arg.trim_prefix("--tool=")
		elif arg.begins_with("--motion="):
			_motion = arg.trim_prefix("--motion=")
		elif arg.begins_with("--frames="):
			_frames = int(arg.trim_prefix("--frames="))
		elif arg == "--side":
			_side = true
		elif arg.begins_with("--yaw="):
			_yaw = deg_to_rad(float(arg.trim_prefix("--yaw=")))

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("101018")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("463E5E")
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_white = 4.0
	env.environment = e
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -26, 0)
	key.light_color = Color("FFE3B8")
	key.light_energy = 1.3
	key.shadow_enabled = false
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-14, 152, 0)
	fill.light_color = Color("9E93BE")
	fill.light_energy = 0.5
	fill.shadow_enabled = false
	add_child(fill)

	var world := ElfWorld.new()
	add_child(world)
	world.build()

	# The land is in the way. Everything built by build() is scenery; hide it all
	# so what is left is the figures.
	for child in world.get_children():
		child.visible = false

	# One clock for the whole sheet, so every elf differs only by its phase.
	world._time = 10.0

	var elves := []
	for i in _frames:
		if not world._grow():
			break
		var elf = world._elves[world._elves.size() - 1]
		elves.append(elf)

		elf.grown = 1.0
		elf.rig.scale = Vector3.ONE
		elf.task = ElfWorld.Task.GATHER
		elf.motion = _motion
		elf.work_left = 9.0
		elf.energy = 1.0
		elf.mood = 0.0
		elf.moving = false
		elf.pace = 0.42
		world._take_tool(elf, _tool)

		# Same beat rate as the world uses, solved backwards for the phase that
		# puts this elf at fraction i/frames of the cycle at the frozen time.
		var want := float(i) / float(_frames)
		elf.phase = want - world._time * (0.80 + elf.pace * 0.5)

		elf.node.position = Vector3((float(i) - (float(_frames) - 1.0) * 0.5) * 0.62,
			0.0, 0.0)
		elf.node.rotation.y = (PI * 0.5 if _side else 0.0) + _yaw
		elf.node.scale = Vector3.ONE

		# The work, where the blow is supposed to land, and the ground it is
		# standing on. A swing judged against nothing looks fine at every phase.
		var slab := MeshInstance3D.new()
		var lump := BoxMesh.new()
		lump.size = Vector3(0.34, WORK_AT.y * 2.0, 0.30)
		slab.mesh = lump
		slab.material_override = World.solid_material(Color("6B6F7A"), 0.85)
		slab.position = WORK_AT * Vector3(1, 0, 1)
		elf.node.add_child(slab)

	# Settle the smoothing, holding the clock still so the pose does not drift.
	for _step in 90:
		for elf in elves:
			world._animate(elf, 0.05, false)
			elf.node.position.y = 0.0

	var span := float(_frames) * 0.62

	# Ground. A boot leaving it is one of the things this sheet exists to catch.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(span * 1.6, 3.0)
	ground.mesh = plane
	ground.material_override = World.solid_material(Color("23232B"), 1.0)
	add_child(ground)

	var cam := Camera3D.new()
	cam.fov = 34.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.30, span * 0.95),
		Vector3(0, 0.26, 0), Vector3.UP)
	cam.current = true


func _process(_delta: float) -> void:
	if _capture.is_empty() or _shot:
		return
	_shot = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_capture)
	get_tree().quit()
