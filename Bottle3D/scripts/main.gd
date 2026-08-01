extends Node3D

## Elvle.
##
## The phone is the bottle, so nothing draws a vessel. Five islands, each with
## one house on it that takes about a week of held stillness to finish, and one
## rule holding the whole thing up:
##
##   **They only build while the phone is still.**
##
## Move it and the elves down tools and some of them leave. Put it down and they
## come back, over the next fifteen minutes, and get on with it. That is the
## entire mechanism and there is nothing else to do.
##
## **Nothing that has been built ever comes apart.** A disturbance costs you
## hours forwards, by taking the crew away and making them walk back, and never
## backwards. Against a build that takes a week, a mechanic that can undo an
## evening is a mechanic that teaches people not to open the app.
##
## Every hour of building they stop for a quarter of an hour, and that break only
## runs down while you are here watching it. See `ElfWorld.WORK_PERIOD`.
##
## ## Touching is free now, and that is a change
##
## It used to cost. Every tap and every swipe drained the bottle, on the
## reasoning that handling the phone is handling the phone. That was the right
## instinct and the wrong rule, because it meant the app charged you for turning
## the world round to see what was happening on the far side - it punished
## paying attention, which is the opposite of what a focus app is for.
##
## So the cost is now movement alone, measured on the accelerometer. A phone flat
## on a desk with a finger turning the island is perfectly still and costs
## nothing. A phone picked up is not, and costs a great deal. That is also the
## honest version of the rule: what breaks a stretch of work is picking the thing
## up, not looking at it.
##
## Which frees the gestures to do what they should always have done - drag to
## turn the island, pinch to come in close enough to watch one elf's hands.

const TARGET_FPS := 30

## Everything above this is a hand on the phone. Below it is a desk, a passing
## lorry, somebody walking past.
const ORBIT_RATE := 0.0022
const PITCH_RATE := 0.0016
const ZOOM_MIN := 0.42
const ZOOM_MAX := 1.65

const VOID := Color("0B0906")

var _camera: Camera3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _key_energy := 1.0
var _fill_energy := 1.0
var _ambient_energy := 1.0
var _menu: Menu
var _back: Label
var _mode_label: Label

var _world: ElfWorld
var _island := 0

var _charge := Charge.new()

## Smoothed device motion. Heavy smoothing, because one spike from a door closing
## must not empty somebody's bottle.
var _agitation: float = 0.0

## Slowly-followed average of the accelerometer. Agitation is deviation from this
## rather than from an assumed gravity vector, which works whichever convention
## the platform reports acceleration in.
var _accel_baseline: Vector3 = Vector3.ZERO
var _baseline_ready := false

var _tilt: Vector2 = Vector2.ZERO
var _has_sensors := false

# Where the camera is looking from, which is now the user's business.
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _drift := 0.0

## Whether a one-finger drag turns the island (false) or slides the camera
## over it (true). Reset whenever an island is entered, so nobody arrives at
## a fresh island already panned off to one side.
var _pan_mode := false
var _pan := Vector3.ZERO
const PAN_LIMIT := 3.4

var _touches := {}
var _pinch_from := 0.0
var _pinch_zoom := 1.0
var _press_at := Vector2.ZERO
var _press_time := 0.0
var _dragged := false

## The break used to be drawn as a light crossing the sky in a HUD overlay -
## a hairline arc with a dot travelling along it. The sun and moon now do that
## job for real: the sun sets as the hour ends, the moon rises and sets across
## the break tracking `rest_fraction()` exactly as the arc used to, and the
## hearth becomes the brightest thing on the island while it does. Two
## progress indicators for one event was worse than either alone, so this one
## was deleted rather than kept alongside the other.
var _rest_label: Label
var _dim := 1.0

var _capture_path: String = ""
var _capture_after: float = 0.0
var _capture_screen := "world"
var _force_rest := -1.0
var _arg_yaw := NAN
var _arg_zoom := NAN
var _capturing := false
var _elapsed: float = 0.0


func _ready() -> void:
	Engine.max_fps = TARGET_FPS
	_has_sensors = OS.has_feature("mobile")

	_build_environment()
	_build_camera()
	_build_lights()
	_build_finish()
	_build_sky()
	_build_back()

	_island = clampi(Progress.last_island(), 0, Biome.COUNT - 1)
	_menu = Menu.new()
	add_child(_menu)
	_menu.begin.connect(_on_begin)
	_menu.chose.connect(_enter)
	_menu.dismissed.connect(_on_dismissed)

	_read_capture_args()

	match _capture_screen:
		"picker":
			_menu.show_picker()
		"world":
			_enter(_island)
		_:
			_menu.show_title()

	# After _enter, which resets the camera to the island's default. Held apart
	# so a capture can ask for an angle and actually get it.
	if not is_nan(_arg_yaw):
		_yaw = _arg_yaw
	if not is_nan(_arg_zoom):
		_zoom = _arg_zoom


func _process(delta: float) -> void:
	_elapsed += delta
	_read_motion(delta)
	_move_camera(delta)
	_fade_back(delta)
	_rest_light(delta)
	_maybe_capture()

	if _world == null or _menu.showing():
		return

	var was_disturbed := _charge.is_disturbed

	# Movement only. A finger on the glass is not a disturbance any more.
	_charge.update(delta, _agitation, false)

	if _charge.is_disturbed and not was_disturbed:
		_world.disturbed()

	_world.advance(delta, _charge.population(_world.capacity), _charge.is_disturbed)


# --- moving between places ---------------------------------------------------

func _on_begin() -> void:
	_menu.show_picker()


func _on_dismissed() -> void:
	if _world != null:
		_menu.hide_all()


func _enter(island: int) -> void:
	if _world != null and _island == island:
		_menu.hide_all()
		return

	_leave()
	_island = clampi(island, 0, Biome.COUNT - 1)
	Progress.set_last_island(_island)
	Progress.flush()

	_world = ElfWorld.new(_island)
	add_child(_world)
	_world.build()

	# The bottle is never empty. Somebody is on the island the moment it opens,
	# so the first thing seen is the place itself and not a black screen to be
	# earned.
	for _i in Charge.STARTING_OBJECTS:
		_world.advance(999.0, Charge.STARTING_OBJECTS, false)

	_apply_lighting(_world)
	_camera.fov = _world.lens
	_yaw = 0.0
	_pitch = 0.0
	_zoom = 1.0
	_pan = Vector3.ZERO
	if _force_rest >= 0.0:
		_world.force_rest(_force_rest)

	_menu.hide_all()
	_back.modulate.a = 0.34
	_drift = 6.0


func _leave() -> void:
	if _world == null:
		return
	_world.persist()
	_world.queue_free()
	_world = null


func _notification(what: int) -> void:
	# Losing twenty seconds of a week-long build because somebody took a call is
	# the one place autosave has to be exact.
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST,
			NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if _world:
			_world.persist()


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_at = event.position
				_press_time = _elapsed
				_dragged = false
			elif _touches.size() == 2:
				_pinch_from = _pinch_span()
				_pinch_zoom = _zoom
		else:
			_touches.erase(event.index)
			if _touches.is_empty():
				_finish_press(event.position)

	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_pinch(_pinch_span())
		elif _pan_mode:
			_pan_camera(event.relative)
		else:
			_orbit(event.relative)

	elif event is InputEventMouseButton:
		# An emulated pointer reports device -1 and would double every gesture.
		if event.device == -1:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 0.92, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom * 1.08, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_at = event.position
				_press_time = _elapsed
				_dragged = false
			else:
				_finish_press(event.position)

	elif event is InputEventMouseMotion and event.device != -1:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if _pan_mode:
				_pan_camera(event.relative)
			else:
				_orbit(event.relative)


func _pinch_span() -> float:
	var points := _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _pinch(span: float) -> void:
	if _pinch_from < 1.0 or span < 1.0:
		return
	_dragged = true
	_zoom = clampf(_pinch_zoom * (_pinch_from / span), ZOOM_MIN, ZOOM_MAX)


## Turning the island, and leaning over it. The pitch is clamped well short of
## overhead: from directly above these stop being people and become hats.
func _orbit(by: Vector2) -> void:
	if _menu.showing():
		return
	if by.length() > 2.0:
		_dragged = true
	_yaw = wrapf(_yaw - by.x * ORBIT_RATE, -PI, PI)
	_pitch = clampf(_pitch + by.y * PITCH_RATE, -0.28, 0.62)
	_drift = 14.0


## The other half of the toggle: sliding the camera over the island rather
## than turning it round. Grabs the ground plane rather than the yaw, so the
## content follows the finger the way it would with a real map.
func _pan_camera(by: Vector2) -> void:
	if _menu.showing() or _camera == null:
		return
	if by.length() > 2.0:
		_dragged = true

	var basis := _camera.global_transform.basis
	var right := _flat(basis.x)
	var forward := _flat(-basis.z)
	var rate := 0.0032 * _zoom

	_pan -= right * by.x * rate
	_pan += forward * by.y * rate
	if _pan.length() > PAN_LIMIT:
		_pan = _pan.normalized() * PAN_LIMIT
	_drift = 14.0


func _flat(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	return f.normalized() if f.length_squared() > 1e-10 else Vector3.ZERO


func _finish_press(at: Vector2) -> void:
	if _dragged or _elapsed - _press_time > 0.6:
		return
	if at.distance_to(_press_at) > 40.0:
		return

	if _menu.showing():
		_menu.tapped(at)
		return

	# Bottom left corner, where the way back lives, and the toggle just under
	# it for which way a one-finger drag turns.
	if at.x < 620.0 and at.y > 1075.0:
		_pan_mode = not _pan_mode
		return
	if at.x < 620.0 and at.y > 980.0:
		if _world:
			_world.persist()
		_menu.show_picker()


func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 105

	# Said once, at the start of the first break, and then never again. After
	# that a dozen figures lying down round a fire explains itself.
	_rest_label = Label.new()
	_rest_label.text = "They have stopped for a while."
	_rest_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rest_label.offset_top = 372.0
	_rest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rest_label.add_theme_font_size_override("font_size", 42)
	_rest_label.add_theme_color_override("font_color", Color("EFE3CB"))
	_rest_label.modulate.a = 0.0
	_rest_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_rest_label)

	add_child(layer)


## The sun's elevation follows the work hour and the moon's follows the break,
## so the light itself announces what is about to happen before anything on
## the ground does: it starts descending in the last few minutes before a
## break rather than the break simply arriving.
##
## The key comes down, the fill goes cold and the hearth is left doing most of
## the work, so a break looks like one from across a room. It is also the only
## time the fire is the brightest thing on the island, which is the correct
## thing for it to be when everybody has gone to sit round it.
func _rest_light(delta: float) -> void:
	if _world == null:
		return

	var want := 0.42 if _world.resting() else 1.0
	_dim = lerpf(_dim, want, clampf(delta * 0.55, 0.0, 1.0))

	_key.light_energy = _key_energy * _dim
	_fill.light_energy = _fill_energy * lerpf(1.45, 1.0, _dim)
	_env.ambient_light_energy = _ambient_energy * lerpf(0.72, 1.0, _dim)

	var fraction := _world.rest_fraction()

	# One slow arc across the whole working hour: low as they wake, high with
	# a gentle drift through the middle, low again as it announces the break
	# before anybody downs tools.
	var work_t := _world.work_fraction()
	var sun_elevation := sin(work_t * PI)
	var sun_azimuth := lerpf(-58.0, 58.0, work_t)
	_key.rotation_degrees = Vector3(-18.0 - sun_elevation * 46.0, sun_azimuth, 0)

	_moon.visible = fraction >= 0.0
	if fraction >= 0.0:
		var moon_elevation := sin(fraction * PI)
		var moon_azimuth := lerpf(58.0, -58.0, fraction)
		_moon.rotation_degrees = Vector3(-16.0 - moon_elevation * 44.0, moon_azimuth, 0)
		_moon.light_energy = lerpf(0.0, 0.55, moon_elevation)

	var hint: float = _world.rest_hint() if fraction >= 0.0 else 0.0
	_rest_label.modulate.a = lerpf(_rest_label.modulate.a, hint * 0.55,
		clampf(delta * 1.6, 0.0, 1.0))


func _build_back() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 110

	_back = Label.new()
	_back.text = "Islands"
	_back.position = Vector2(170.0, 1030.0)
	_back.add_theme_font_size_override("font_size", 40)
	_back.add_theme_color_override("font_color", Color("EFE3CB"))
	_back.add_theme_constant_override("shadow_offset_y", 2)
	_back.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_back.modulate.a = 0.0
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE

	layer.add_child(_back)

	# Which mode dragging is in right now, not which one the tap switches to -
	# that is the way round people actually read a toggle.
	_mode_label = Label.new()
	_mode_label.text = "Turn"
	_mode_label.position = Vector2(170.0, 1078.0)
	_mode_label.add_theme_font_size_override("font_size", 40)
	_mode_label.add_theme_color_override("font_color", Color("EFE3CB"))
	_mode_label.add_theme_constant_override("shadow_offset_y", 2)
	_mode_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_mode_label.modulate.a = 0.0
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	layer.add_child(_mode_label)
	add_child(layer)


## The way out stays on screen rather than being hidden behind a gesture, but it
## settles to almost nothing so it is not something you are looking at for
## twenty-five minutes. It never goes to zero: a control you cannot see is a
## control that is not there.
func _fade_back(delta: float) -> void:
	if _back == null:
		return
	var want := 0.0
	if _world != null and not _menu.showing():
		want = 0.34 if _drift > 0.0 else 0.13
	_drift = maxf(0.0, _drift - delta)
	_back.modulate.a = lerpf(_back.modulate.a, want, clampf(delta * 2.0, 0.0, 1.0))
	_mode_label.text = "Move" if _pan_mode else "Turn"
	_mode_label.modulate.a = _back.modulate.a


# --- motion ------------------------------------------------------------------

## Agitation as deviation from a slowly-followed baseline, rather than
## accelerometer minus gravity.
##
## The subtraction approach assumes the platform reports acceleration with
## gravity included. If it already removes gravity, the difference is a constant
## 1G and the bottle reads as permanently shaken. Measuring deviation from
## whatever the signal rests at works under either convention, and dividing by
## the baseline magnitude makes it unit-agnostic.
##
## The baseline follows slowly, which also means a steady tilt is absorbed rather
## than punished. Leaning the phone to look into the bottle stays free.
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
	if _world == null:
		return

	var nominal: float = _world.distance
	var focal: Vector3 = _world.focus + _pan
	var base_pitch: float = atan2(_world.rise, nominal)
	var away := sqrt(nominal * nominal + _world.rise * _world.rise) * _zoom

	var yaw := _yaw
	var pitch := clampf(base_pitch + _pitch, 0.10, 1.18)

	if _has_sensors:
		# Tilt still adds a little parallax on top of wherever the user has put
		# the camera. It is the difference between looking at a screen and
		# looking into something, and it costs nothing: the baseline absorbs a
		# steady lean, so leaning is free while picking the phone up is not.
		var g := Input.get_gravity()
		if g.length() > 0.1:
			g = g.normalized()
			# Gravity is reported in the device's own frame, which does not turn
			# when the screen does. Held the other way up in landscape, the same
			# lean produces the opposite x.
			var flipped := DisplayServer.screen_get_orientation() \
				== DisplayServer.SCREEN_REVERSE_LANDSCAPE
			var lean := Vector2(g.x, g.z)
			if flipped:
				lean.x = -lean.x
			_tilt = _tilt.lerp(lean, clampf(delta * 2.2, 0.0, 1.0))
		yaw += _tilt.x * _world.orbit_gain
		pitch = clampf(pitch + _tilt.y * 0.12, 0.10, 1.18)

	_camera.position = focal + Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * away
	_camera.look_at(focal, Vector3.UP)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()

	# A sky, not a void. The palette here was tuned for glowing objects against
	# black back when this was Lightning in a Bottle, and it stayed unexamined
	# through a daylight building site with nothing overhead to say where the
	# light was coming from. A sky is not a vessel, so nothing about the
	# phone-is-the-bottle rule objects to having one.
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2E3A5C")
	sky_mat.sky_horizon_color = Color("8C8FA0")
	sky_mat.sky_curve = 0.14
	sky_mat.ground_bottom_color = Color("463E38")
	sky_mat.ground_horizon_color = Color("8C8FA0")
	sky_mat.ground_curve = 0.10
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.15
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	_sky_mat = sky_mat

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("463E5E")
	env.ambient_light_energy = 0.80

	# Bloom is what turns a lit window into something worth walking toward.
	# Threshold sits below the white point so the hot cores clip into glow.
	env.glow_enabled = true
	env.glow_intensity = 1.20
	env.glow_bloom = 0.40
	env.glow_hdr_threshold = 0.80
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# Aerial perspective from cheap distance fog, not the volumetric kind. The
	# mobile renderer has none, and it was the most expensive thing in the scene
	# by a distance.
	env.fog_enabled = true
	env.fog_light_color = Color("2A2A44")
	env.fog_light_energy = 0.6
	env.fog_density = 0.016
	env.fog_sky_affect = 0.35

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0

	_env = env
	world.environment = env
	add_child(world)


## The sun and the moon. Both are directional lights, which is what lets a
## procedural sky draw a disc for each without any extra wiring - Godot reads
## the direction and colour straight off the light. The sun carries the day;
## the moon is dark except across a break, when it is the only thing moving.
func _build_lights() -> void:
	_key = DirectionalLight3D.new()
	_key.shadow_enabled = false
	add_child(_key)

	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-14, 152, 0)
	_fill.shadow_enabled = false
	add_child(_fill)

	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("AEC4E6")
	_moon.light_energy = 0.0
	_moon.visible = false
	_moon.shadow_enabled = false
	add_child(_moon)


## The whole palette was tuned for glowing objects against a black void, back
## when this was Lightning in a Bottle, and it stayed that way through a
## daylight building site with a sky now overhead to make the dimness obvious.
## Raised here rather than by editing every energy on every island, so the
## five stay in the same relation to each other they were tuned in.
const LIGHT_BOOST := 1.35

## Each island sets the light it wants to be seen in. An arctic key on a jungle
## floor is the fastest way to make five places look like one place recoloured.
func _apply_lighting(world: World) -> void:
	_key.light_color = world.key_color
	_key_energy = world.key_energy * LIGHT_BOOST
	_fill.light_color = world.fill_color
	_fill_energy = world.fill_energy * LIGHT_BOOST
	_env.ambient_light_color = world.ambient_color
	_ambient_energy = world.ambient_energy * LIGHT_BOOST

	var b := Biome.of(_island)
	_env.fog_light_color = b["fog"]
	_env.fog_density = b["fog_density"]

	# Sky colours derived from the same per-island palette everything else
	# reads from, rather than a second set of tuned constants to keep in step
	# with it.
	var amb: Color = b["ambient"]
	var key: Color = b["key"]
	_sky_mat.sky_top_color = amb.lerp(key, 0.10).darkened(0.05)
	_sky_mat.sky_horizon_color = Color(b["fog"]).lerp(key, 0.45)
	_sky_mat.ground_horizon_color = Color(b["shore"]).lerp(key, 0.25)
	_sky_mat.ground_bottom_color = Color(b["earth"]).darkened(0.35)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 46.0
	_camera.position = Vector3(0, 4, 8)
	_camera.far = 60.0
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


func _read_capture_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--after="):
			_capture_after = float(arg.trim_prefix("--after="))
		elif arg.begins_with("--island="):
			_island = clampi(int(arg.trim_prefix("--island=")), 0, Biome.COUNT - 1)
		elif arg.begins_with("--screen="):
			_capture_screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--yaw="):
			_arg_yaw = deg_to_rad(float(arg.trim_prefix("--yaw=")))
		elif arg.begins_with("--zoom="):
			_arg_zoom = clampf(float(arg.trim_prefix("--zoom=")), ZOOM_MIN, ZOOM_MAX)
		elif arg.begins_with("--rest="):
			# Drops straight into a break, a given fraction of the way through
			# it, so fifteen minutes of it can be looked at without waiting an
			# hour for it to start.
			_force_rest = clampf(float(arg.trim_prefix("--rest=")), 0.0, 1.0)


func _maybe_capture() -> void:
	if _capture_path.is_empty() or _elapsed < _capture_after or _capturing:
		return

	# Awaiting the draw returns to _process, which calls this again on the next
	# frame while the first call is still suspended. Without the guard every
	# subsequent frame tries to save to a path the first one has already cleared.
	_capturing = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_path)
	_capture_path = ""
	get_tree().quit()
