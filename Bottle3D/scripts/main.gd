extends Node3D

## Hobbitle.
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

## How far down the drag can push the camera's angle before it stops orbiting
## and starts looking up instead. See `_move_camera`.
const ORBIT_FLOOR := 0.06

## And how far past that it can keep going. A shade under ninety degrees of
## total travel, which is one unhurried drag up the screen.
const PITCH_MIN := -1.62
const ZOOM_MIN := 0.42
const ZOOM_MAX := 1.65

const VOID := Color("0B0906")

var _camera: Camera3D
var _key: DirectionalLight3D
var _fill: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial

## The two things in the sky you can actually point at. Drawn, not inferred -
## see `_build_bodies`.
var _sun_body: MeshInstance3D
var _moon_body: MeshInstance3D

## Zero in the working hour, one in the middle of a break. Everything about the
## sky - its colour, which body is up, how warm the low sun is - is driven off
## this one smoothed number rather than off `resting()` directly, so a break
## arrives as a sunset rather than as a cut.
var _night := 0.0

## The island's designed day sky, held so the night blend has something to
## interpolate away from every frame.
var _sky_day_top := Color("3E76C4")
var _sky_day_horizon := Color("E3D2AE")
var _sky_night_top := Color("10162E")
var _sky_night_horizon := Color("1E2740")

## Where the sun and moon are, held between frames rather than recomputed from
## scratch, so each can be frozen while it is invisible - see `_rest_light`.
var _sun_elev := 32.0
var _sun_azim := 0.0
var _moon_elev := 30.0
var _moon_azim := 0.0

## The last `_night` the sky material was written at. Writing a procedural sky's
## colours re-renders its radiance map, which is not something to do sixty times
## a second on a phone that has to stay cool for twenty-five minutes - and for
## all but a few seconds an hour this value does not move at all.
var _sky_written := -1.0

## What the lower hemisphere settles into, far below the horizon. The island's
## own haze colour, so distance and fog agree.
var _haze_floor := Color("2A2A44")
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
var _arg_pitch := NAN
var _capturing := false
var _elapsed: float = 0.0


func _ready() -> void:
	Engine.max_fps = TARGET_FPS
	_has_sensors = OS.has_feature("mobile")

	_build_environment()
	_build_camera()
	_build_lights()
	_build_bodies()
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
	if not is_nan(_arg_pitch):
		_pitch = _arg_pitch


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


## Turning the island, and leaning over it.
##
## The top of the range is clamped well short of overhead: from directly above
## these stop being people and become hats.
##
## The bottom used to stop at -0.28, which sounds like a detail and was not.
## The island is framed from thirty-six degrees up through a thirty-four degree
## lens, so the horizon sits nineteen degrees above the top of the frame, and
## -0.28 was not enough to pull it down into view - which meant that at no
## angle the user could reach was any part of the actual sky on screen, and
## the sun and moon were unreachable rather than missing. Leaning back far
## enough to see the weather is now allowed, and is the only way to find
## either of them.
func _orbit(by: Vector2) -> void:
	if _menu.showing():
		return
	if by.length() > 2.0:
		_dragged = true
	_yaw = wrapf(_yaw - by.x * ORBIT_RATE, -PI, PI)
	_pitch = clampf(_pitch + by.y * PITCH_RATE, PITCH_MIN, 0.62)
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
	_night = clampf(inverse_lerp(1.0, 0.42, _dim), 0.0, 1.0)

	_key.light_energy = _key_energy * _dim
	_fill.light_energy = _fill_energy * lerpf(1.45, 1.0, _dim)
	_env.ambient_light_energy = _ambient_energy * lerpf(0.72, 1.0, _dim)

	# The sky itself goes over to night, which it never used to - the same blue
	# stayed up through every break, and the lights coming down on an unchanged
	# sky read as a cloud passing rather than as an evening.
	if absf(_night - _sky_written) > 0.02:
		_sky_written = _night
		_write_sky(_sky_day_top.lerp(_sky_night_top, _night),
			_sky_day_horizon.lerp(_sky_night_horizon, _night))

	# The two bodies cross over rather than swapping. The sun is gone by the
	# time the night is three-fifths in, the moon is not there until it is
	# two-fifths, and in the overlap both are faint - which is what dusk is.
	var sun_up := clampf((1.0 - _night) * 2.4, 0.0, 1.0)
	var moon_up := clampf((_night - 0.42) * 2.4, 0.0, 1.0)

	# One slow arc across the whole working hour: low as they wake, high with
	# a gentle drift through the middle, low again as it announces the break
	# before anybody downs tools. Held where it was once it has faded out, so
	# that the reset of the hour - which throws the sun from the west back to
	# the east in a single frame - happens while nobody can see it.
	if sun_up > 0.0:
		var work_t := _world.work_fraction()
		_sun_elev = lerpf(14.0 + 40.0 * sin(work_t * PI), 2.5, _night)
		_sun_azim = lerpf(-58.0, 58.0, work_t)
	_key.rotation_degrees = Vector3(-_sun_elev, _sun_azim, 0)

	# Low sun, warm sun. The disc goes over to orange as it comes down, which
	# is the cheapest possible sunset and reads from across a room.
	var low := 1.0 - clampf(_sun_elev / 34.0, 0.0, 1.0)
	_place_body(_sun_body, _sun_elev, _sun_azim,
		Color(1.35, 1.30, 1.15).lerp(Color(1.50, 0.82, 0.44), low), sun_up)

	var fraction := _world.rest_fraction()
	if moon_up > 0.0 and fraction >= 0.0:
		_moon_elev = 8.0 + 38.0 * sin(fraction * PI)
		_moon_azim = lerpf(58.0, -58.0, fraction)
	_moon.visible = moon_up > 0.004
	if _moon.visible:
		_moon.rotation_degrees = Vector3(-_moon_elev, _moon_azim, 0)
		_moon.light_energy = 0.55 * moon_up * sin(deg_to_rad(_moon_elev))
	_place_body(_moon_body, _moon_elev, _moon_azim,
		Color(1.10, 1.14, 1.25), moon_up)

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

	# Dragging down used to walk the camera round and under the island, which
	# is the one direction there is nothing to see in - and, because the camera
	# always aims at the island, it never turned the view toward the sky no
	# matter how far it went. That is why the sun and the moon were unfindable:
	# not missing, but behind the top edge of the frame at every angle a thumb
	# could reach.
	#
	# So the orbit stops just above level, and everything past that tilts the
	# aim upward from where the camera already is. Keep dragging and the island
	# slides off the bottom of the frame and you are looking at the weather.
	var want := base_pitch + _pitch
	var pitch := clampf(want, ORBIT_FLOOR, 1.18)
	var aim_up := maxf(0.0, ORBIT_FLOOR - want)

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
	if aim_up > 0.0:
		_camera.rotate_object_local(Vector3.RIGHT, aim_up)


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
	# A slow settle rather than a hard band. The lower hemisphere is forty-odd
	# degrees of visible frame in this app rather than a strip at the bottom,
	# so its gradient has as much work to do as the sky's.
	sky_mat.ground_curve = 0.32
	# No sun from the sky material. Every directional light in the scene gets
	# one and none of them is controllable enough to be the sun this app wants -
	# see `_build_lights`.
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	_sky_mat = sky_mat

	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("463E5E")
	env.ambient_light_energy = 0.80
	# Mostly the sky, which is why brightening the sky brightens the island as
	# well as the background. Not entirely, though: without this the per-island
	# ambient colour that `_apply_lighting` sets is dead code, because ambient
	# taken purely from the sky ignores it, and five islands that each chose an
	# ambient tint would all have been getting the same one.
	env.ambient_light_sky_contribution = 0.78

	# Bloom is what turns a lit window into something worth walking toward.
	# Threshold sits below the white point so the hot cores clip into glow.
	env.glow_enabled = true
	env.glow_intensity = 1.20
	env.glow_hdr_threshold = 0.80
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# `glow_bloom` is not the glow. It is a floor added underneath the
	# threshold, so a fraction of *every* pixel gets blurred and added back
	# over the frame whether it is a hearth or a patch of grass. At 0.40 that
	# is a forty percent full-screen haze, which was invisible when this was
	# glowing objects against a black void and turns a daylight scene into
	# milk - which is what "the sky is not bright enough" actually looked
	# like. The sky was never dark. It was washed colourless.
	env.glow_bloom = 0.05

	# Aerial perspective from cheap distance fog, not the volumetric kind. The
	# mobile renderer has none, and it was the most expensive thing in the scene
	# by a distance.
	env.fog_enabled = true
	env.fog_light_color = Color("2A2A44")
	env.fog_light_energy = 0.6
	env.fog_density = 0.016
	# Aerial perspective belongs on the island, not on the sky behind it. At
	# 0.35 a third of every sky pixel was the fog's dark blue-grey, which is a
	# fast way to grey out a colour that was chosen carefully.
	env.fog_sky_affect = 0.10

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0

	_env = env
	world.environment = env
	add_child(world)


## The three lights, and the reason none of them draws itself.
##
## `ProceduralSkyMaterial` does put a sun in the sky for each of the first four
## `DirectionalLight3D`s in the scene, so the previous session's assumption was
## not wrong exactly - but it was never checked, and what it actually produces
## is a wide soft halo rather than a disc, because the size of that halo comes
## from the light's `light_angular_distance`, which defaults to zero. Worse,
## every directional light gets one: the fill was quietly painting a second sun
## into the sky from behind, at 152 degrees, which is most of why nobody could
## find the real one.
##
## The property last session reached for was `light_angular_size`, which does
## not exist; the real name is `light_angular_distance`. Setting it correctly
## does produce a disc. It is still the wrong mechanism for this app, because
## the disc's brightness is the light's brightness - so the moon, which is dim
## on purpose, would be invisible on purpose too, and a sun that has to dim at
## dusk would shrink out of the sky instead of going orange.
##
## So all three are `SKY_MODE_LIGHT_ONLY` and the sun and moon are drawn as
## real objects in `_build_bodies`, where their size, colour and glow are ours.
func _build_lights() -> void:
	_key = DirectionalLight3D.new()
	_key.shadow_enabled = false
	_key.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_key)

	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(-14, 152, 0)
	_fill.shadow_enabled = false
	_fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_fill)

	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("AEC4E6")
	_moon.light_energy = 0.0
	_moon.visible = false
	_moon.shadow_enabled = false
	_moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_moon)


## How far out the sun and moon are hung. Inside the camera's far plane with
## room to spare, and far enough past the island that no amount of orbiting or
## panning gets near them.
const BODY_DIST := 44.0

## Apparent diameter, in degrees. The real sun is half of one degree, which on
## a phone held at arm's length is four pixels and not worth drawing. These are
## the size the sun is remembered as rather than the size it is.
const SUN_ANGLE := 5.4
const MOON_ANGLE := 4.6


## The sun and the moon, as two billboards hung a long way off.
##
## Unshaded, so nothing lights them and they are exactly the colour they are
## told to be; fog disabled, so forty metres of aerial perspective does not
## grey out the one thing in the frame that is meant to be the brightest; and
## an albedo pushed past white, so both clip through the glow threshold in
## `_build_environment` and bloom rather than sitting flat.
func _build_bodies() -> void:
	_sun_body = _sky_body(_disc(Color("FFF6DC"), Color("FFC55E"), 0), SUN_ANGLE)
	_moon_body = _sky_body(_disc(Color("F2F5FF"), Color("A8BEE4"), 3), MOON_ANGLE)
	_moon_body.visible = false


func _sky_body(tex: ImageTexture, angle_deg: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = tex
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	# Values above white. A Color is not clamped on its way to the shader, and
	# the glow threshold is 0.80, so this is what makes a sun bloom instead of
	# being a pale sticker.
	mat.albedo_color = Color(1.35, 1.30, 1.15)

	var quad := QuadMesh.new()
	var span := 2.0 * BODY_DIST * tan(deg_to_rad(angle_deg) * 0.5)
	# The texture is mostly halo, so the mesh has to be several times the
	# diameter of the disc it contains.
	quad.size = Vector2(span * DISC_SPAN, span * DISC_SPAN)

	var node := MeshInstance3D.new()
	node.mesh = quad
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


const DISC_TEX := 96
## How much wider the whole billboard is than the solid disc at its centre.
const DISC_SPAN := 2.6


## A body and the air around it, drawn once into a texture.
##
## The disc itself is a flat core with a slightly warmer rim, which is what
## stops it reading as a sticker; outside it the alpha falls away as a cube,
## which is a close enough approximation of atmospheric scatter and, more to
## the point, is what makes the thing look like it is giving off light rather
## than being a circle.
##
## `blotches` puts a few darker patches on the face. Three of them turn a pale
## disc into the moon, which is a startling amount of recognition for nine
## lines of code.
func _disc(core: Color, rim: Color, blotches: int) -> ImageTexture:
	var img := Image.create(DISC_TEX, DISC_TEX, false, Image.FORMAT_RGBA8)
	var half := float(DISC_TEX) * 0.5
	var edge := 1.0 / DISC_SPAN            ## Where the solid disc ends.
	var feather := 1.6 / half

	var seeds: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EA
	for _i in blotches:
		seeds.append(Vector3(rng.randf_range(-0.5, 0.5),
			rng.randf_range(-0.5, 0.5), rng.randf_range(0.16, 0.30)))

	for y in DISC_TEX:
		for x in DISC_TEX:
			var p := Vector2((float(x) + 0.5) / half - 1.0,
				(float(y) + 0.5) / half - 1.0)
			var r := p.length()

			var solid := clampf((edge - r) / feather + 0.5, 0.0, 1.0)
			var halo := pow(clampf(1.0 - (r - edge) / maxf(1.0 - edge, 1e-5),
				0.0, 1.0), 3.0)

			var c := core.lerp(rim, clampf(r / edge, 0.0, 1.0) * 0.85)
			for s in seeds:
				c = c.lerp(c.darkened(0.30), clampf(
					1.0 - Vector2(p.x - s.x, p.y - s.y).length() / s.z, 0.0, 1.0))

			c.a = maxf(solid, halo * 0.42)
			img.set_pixel(x, y, c)

	return ImageTexture.create_from_image(img)


## Hangs a body along a light's direction, at the far end of it. The light
## shines *from* the body, so the body sits opposite the way the light points.
func _place_body(node: MeshInstance3D, elevation: float, azimuth: float,
		tint: Color, up: float) -> void:
	if node == null or _camera == null:
		return
	node.visible = up > 0.004
	if not node.visible:
		return
	var basis := Basis.from_euler(Vector3(deg_to_rad(-elevation),
		deg_to_rad(azimuth), 0.0))
	node.position = _camera.position + basis.z * BODY_DIST
	var mat := node.material_override as StandardMaterial3D
	mat.albedo_color = Color(tint.r, tint.g, tint.b, up)


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

	# The sky used to be derived from this same palette - a ten percent lerp
	# from the ambient colour toward the key, then darkened again. That was the
	# mistake behind "the sky is not bright enough": the ambient colour is a
	# dark violet-grey chosen to sit under a scene, and no small nudge toward a
	# cream key light turns it into a daytime sky. Deriving one number from
	# another is only worth doing when the two actually want to agree, and a
	# sky and a fill light do not.
	#
	# So each island now designs its own, and they differ in the shape of the
	# gradient as well as its colour - the arctic's is flat and pale from top
	# to bottom, the desert's holds deep blue until a hard band of glare at the
	# horizon. See `Biome`.
	_sky_day_top = b["sky_top"]
	_sky_day_horizon = b["sky_horizon"]
	_sky_mat.sky_curve = b["sky_curve"]

	# Night is the island's own, tinted into its haze so the five nights are as
	# different as the five days, if less so - which is true of real nights.
	_sky_night_top = b["sky_night"]
	_sky_night_horizon = Color(b["sky_night"]).lerp(b["fog"], 0.55).lightened(0.05)

	_haze_floor = b["fog"]
	_sky_written = -1.0
	_write_sky(_sky_day_top, _sky_day_horizon)


## The island floats, so the half of the background below the horizon is not
## ground - it is distance.
##
## This is the part that was actually wrong, and it took a capture to see it.
## The camera looks thirty-six degrees down through a thirty-four degree lens,
## which puts the horizon nineteen degrees above the top of the frame: at the
## default angle, and at every angle the user could reach, *none* of what is
## visible behind the island is the sky half of the sky material. All of it is
## the ground half, and the ground half was `earth` darkened by a third - mud.
## Every hour spent tuning `sky_top_color` was spent on a colour nobody had
## ever seen.
##
## So the lower hemisphere carries the horizon colour straight down, settling
## into the island's own haze. The gradient is continuous through the horizon
## line, which is what makes the island read as sitting in luminous air rather
## than as a plate pasted on a backdrop.
func _write_sky(top: Color, horizon: Color) -> void:
	_sky_mat.sky_top_color = top
	_sky_mat.sky_horizon_color = horizon
	_sky_mat.ground_horizon_color = horizon
	_sky_mat.ground_bottom_color = horizon.lerp(_haze_floor, 0.62)


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
		elif arg.begins_with("--pitch="):
			# In the same units the drag produces, so a capture can be taken
			# from an angle a thumb could actually have reached. Without this
			# there was no way to check the sky from the command line at all,
			# which is most of why nobody noticed it was never on screen.
			_arg_pitch = clampf(deg_to_rad(float(arg.trim_prefix("--pitch="))),
				PITCH_MIN, 0.62)
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

	# Printed with every capture, because the last session's sun was assumed to
	# be working from a screenshot that could not have contained it either way.
	# Now a capture says where both bodies are and whether they are drawn, so
	# "I cannot see the sun" and "there is no sun" stay distinguishable.
	print("[capture] sun %.0f deg up, %.0f across, drawn=%s"
		% [_sun_elev, _sun_azim, _sun_body.visible],
		" | moon %.0f deg up, %.0f across, drawn=%s"
		% [_moon_elev, _moon_azim, _moon_body.visible],
		" | night=%.2f" % _night)

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_path)
	_capture_path = ""
	get_tree().quit()
