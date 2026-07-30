extends Node3D

## Bottle, in 3D.
##
## The phone is the bottle, so nothing draws a vessel. Stillness fills whichever
## world is open; touching the screen or moving the phone empties it faster than
## it fills. Swipe left and right to change what is in there.

## Held at 30 rather than 60. The phone ran warm enough to notice, and this app
## sits on a desk for twenty-five minutes at a time. Nothing here is a brief
## event that could be missed - everything caught stays caught - so half the
## frames cost nothing and buy back a cool phone.
const TARGET_FPS := 30

## Far enough that a stray thumb does not change world, short enough that a
## deliberate swipe always lands.
const SWIPE_THRESHOLD := 70.0

const TITLE_SECONDS := 2.0

var _camera: Camera3D
var _worlds: Array[World] = []
var _index := 0
var _title: Label

var _charge := Charge.new()

## Smoothed device motion. Heavy smoothing, because one spike from a door
## closing must not empty someone's bottle.
var _agitation: float = 0.0

## Slowly-followed average of the accelerometer. Agitation is measured as
## deviation from this rather than from an assumed gravity vector.
var _accel_baseline: Vector3 = Vector3.ZERO
var _baseline_ready := false

var _touched_this_frame := false
var _tilt: Vector2 = Vector2.ZERO
var _has_sensors := false
var _drag_from: Vector2 = Vector2.ZERO
var _look: float = 0.0

var _capture_path: String = ""
var _capture_after: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	Engine.max_fps = TARGET_FPS
	_has_sensors = OS.has_feature("mobile")

	_build_environment()
	_build_camera()
	_build_lights()
	_build_finish()
	_build_title()
	_read_capture_args()

	_worlds = [LightningWorld.new(), TreeWorld.new(), IceWorld.new(), ElfWorld.new()]
	for w in _worlds:
		add_child(w)
		w.build()
		w.visible = false

		# The bottle is never empty. Something is in there the moment it opens,
		# so the first thing seen is the thing itself and not a black screen to
		# be earned.
		for _i in Charge.STARTING_OBJECTS:
			w.advance(999.0, Charge.STARTING_OBJECTS, false)

	_index = clampi(_index, 0, _worlds.size() - 1)
	_worlds[_index].visible = true
	_announce()


func _process(delta: float) -> void:
	_elapsed += delta

	_read_motion(delta)

	var was_disturbed := _charge.is_disturbed
	_charge.update(delta, _agitation, _touched_this_frame)
	_touched_this_frame = false

	var world := _worlds[_index]
	if _charge.is_disturbed and not was_disturbed:
		world.disturbed()

	world.advance(delta, _charge.population(world.capacity), _charge.is_disturbed)

	_move_camera(delta)
	_maybe_capture()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_drag_from = event.position
		else:
			_finish_drag(event.position)
		_disturb()
	elif event is InputEventScreenDrag:
		_disturb()
	elif event is InputEventMouseButton:
		if event.pressed:
			_drag_from = event.position
		else:
			_finish_drag(event.position)
		_disturb()


func _disturb() -> void:
	_touched_this_frame = true
	_charge.disturb()


## Swiping changes world. It still costs, because it is still touching the
## phone, but it is how you choose what to sit with.
func _finish_drag(at: Vector2) -> void:
	var moved := at - _drag_from
	if absf(moved.x) < SWIPE_THRESHOLD or absf(moved.x) < absf(moved.y):
		return

	_worlds[_index].visible = false
	_index = wrapi(_index + (1 if moved.x < 0 else -1), 0, _worlds.size())
	_worlds[_index].visible = true
	_announce()


func _announce() -> void:
	_title.text = _worlds[_index].title
	_title.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_interval(TITLE_SECONDS)
	tween.tween_property(_title, "modulate:a", 0.0, 0.9)


## Agitation as deviation from a slowly-followed baseline, rather than
## accelerometer minus gravity.
##
## The subtraction approach assumes the platform reports acceleration with
## gravity included. If it already removes gravity, the difference is a constant
## 1G and the bottle reads as permanently shaken. Measuring deviation from
## whatever the signal rests at works under either convention, and dividing by
## the baseline magnitude makes it unit-agnostic.
##
## The baseline follows slowly, which also means a steady tilt is absorbed
## rather than punished. Leaning the phone to look into the bottle stays free.
func _read_motion(delta: float) -> void:
	if not _has_sensors:
		return

	var accel := Input.get_accelerometer()
	if accel.length() < 0.01:
		accel = Input.get_gravity()
	if accel.length() < 0.01:
		return

	if not _baseline_ready:
		_accel_baseline = accel
		_baseline_ready = true

	_accel_baseline = _accel_baseline.lerp(accel, clampf(delta * 0.6, 0.0, 1.0))

	var scale := maxf(_accel_baseline.length(), 0.001)
	_agitation = _agitation * 0.82 \
		+ ((accel - _accel_baseline).length() / scale) * 0.18


func _move_camera(delta: float) -> void:
	var world := _worlds[_index]
	var distance: float = world.distance
	var focus: Vector3 = world.focus

	if _has_sensors:
		# Tilting looks into the bottle. This is the payoff for being in 3D, and
		# it costs nothing in disturbance: the baseline absorbs a steady lean,
		# so leaning is free while picking the phone up is not.
		var g := Input.get_gravity()
		if g.length() > 0.1:
			g = g.normalized()
			_tilt = _tilt.lerp(Vector2(g.x, g.z), clampf(delta * 2.2, 0.0, 1.0))
		_camera.position = focus + Vector3(
			sin(_tilt.x * 0.55) * distance,
			(_tilt.y + 1.0) * 0.45,
			cos(_tilt.x * 0.55) * distance)
	else:
		_look += delta * 0.10
		var yaw := sin(_look) * 0.22
		_camera.position = focus + Vector3(
			sin(yaw) * distance,
			sin(_look * 0.6) * 0.16,
			cos(yaw) * distance)

	_camera.look_at(focus, Vector3.UP)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()

	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.VOID

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.DEEP_INDIGO
	env.ambient_light_energy = 0.55

	# Bloom is what turns an emissive tube into plasma. Threshold sits below the
	# white point so the hot cores actually clip into glow.
	env.glow_enabled = true
	env.glow_intensity = 1.30
	env.glow_bloom = 0.45
	env.glow_hdr_threshold = 0.70
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# Aerial perspective from cheap distance fog, not the volumetric kind. The
	# mobile renderer has none, and it was the most expensive thing in the
	# scene by a distance.
	env.fog_enabled = true
	env.fog_light_color = Palette.DEEP_INDIGO
	env.fog_light_energy = 0.6
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0

	world.environment = env
	add_child(world)


## One key light and one fill. The lightning is emissive and needs neither, but
## the tree, the ice and the elves are lit surfaces, and a figure with no light
## falling across it reads as a silhouette - which is exactly what was wrong
## with the flat version.
func _build_lights() -> void:
	var key := DirectionalLight3D.new()
	key.light_color = Color("BCD2FF")
	key.light_energy = 0.85
	key.rotation_degrees = Vector3(-42, -34, 0)
	key.shadow_enabled = false
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.light_color = Palette.PLASMA
	fill.light_energy = 0.28
	fill.rotation_degrees = Vector3(-14, 152, 0)
	fill.shadow_enabled = false
	add_child(fill)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 46.0
	_camera.position = Vector3(0, 0, 4.0)
	# No depth of field. It is a per-pixel blur pass for a scene that reads
	# perfectly well without one, and heat is the constraint here.
	add_child(_camera)
	_camera.current = true


func _build_finish() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/finish.gdshader")
	rect.material = mat

	layer.add_child(rect)
	add_child(layer)


func _build_title() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 96.0
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.62))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE

	layer.add_child(_title)
	add_child(layer)


func _read_capture_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--after="):
			_capture_after = float(arg.trim_prefix("--after="))
		elif arg.begins_with("--world="):
			_index = int(arg.trim_prefix("--world="))


func _maybe_capture() -> void:
	if _capture_path.is_empty() or _elapsed < _capture_after:
		return

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_path)
	_capture_path = ""
	get_tree().quit()
