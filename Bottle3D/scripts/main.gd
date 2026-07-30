extends Node3D

## Bottle, in 3D.
##
## The phone is still the bottle, so nothing draws a vessel. What 3D buys is
## everything the flat version could not have: bolts with volume that light the
## fog they hang in, real depth between them, and parallax when the phone is
## tilted - looking into the bottle rather than at a picture of one.

const BoltScene := preload("res://scripts/bolt.gd")

## How many bolts a full bottle holds.
## Nine, not twelve. Twelve tangles: the filaments cross so often that no
## single one can be read, and the image becomes texture rather than subject.
const CAPACITY := 9

## Gap between arrivals while the bottle is filling.
const SPAWN_SECONDS := 1.4

## The volume bolts are placed in, in metres, centred on the origin.
const EXTENT := Vector3(0.80, 1.45, 0.70)

var _camera: Camera3D
var _bolts: Array[Bolt] = []
var _since_spawn: float = 0.0
var _charge: float = 0.0
var _look: Vector2 = Vector2.ZERO

## Set from the command line so a still can be captured without a device.
var _capture_path: String = ""
var _capture_after: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	_build_environment()
	_build_camera()
	_build_finish()
	_read_capture_args()

	# The bottle is never empty. Something is in there the moment it opens.
	for i in 2:
		_spawn()


func _process(delta: float) -> void:
	_elapsed += delta

	# Standing in for the real charge until the motion and touch rules are
	# ported across from the native version.
	_charge = min(_charge + delta * 0.06, 1.0)

	var wanted: int = max(2, int(round(CAPACITY * pow(_charge, 0.45))))

	_since_spawn += delta
	if _bolts.size() < wanted and _since_spawn > SPAWN_SECONDS:
		_spawn()
		_since_spawn = 0.0

	for bolt in _bolts:
		bolt.set_energy(1.0)

	_drift_camera(delta)
	_maybe_capture()


## Slow orbit, so the bolts move against each other and the scene reads as
## having depth. On device this is driven by the gyroscope instead: a gentle
## tilt looks into the bottle, while actually moving the phone is still a
## disturbance.
func _drift_camera(delta: float) -> void:
	_look.x += delta * 0.10
	var yaw := sin(_look.x) * 0.22
	var pitch := sin(_look.x * 0.6) * 0.10

	var distance := 4.0
	_camera.position = Vector3(sin(yaw) * distance, pitch * 1.6, cos(yaw) * distance)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _spawn() -> void:
	if _bolts.size() >= CAPACITY:
		return

	var bolt := Bolt.new()
	bolt.build(_fork(), randf() * TAU, Palette.gas())
	bolt.set_energy(1.0)
	add_child(bolt)
	_bolts.append(bolt)


## A bolt hanging in the volume rather than falling through it. Midpoint
## displacement in three dimensions, so it wanders in depth as well as across.
func _fork() -> PackedVector3Array:
	# Placed with intent rather than uniformly. Scattering evenly through the
	# volume fills the frame corner to corner and leaves nowhere for the eye to
	# rest; clustering off-centre and leaving the lower third open is what makes
	# it a composition instead of a field.
	var focus := Vector3(0.0, 0.28, 0.0)
	var spread := Vector3(
		randfn(0.0, 0.52),
		randfn(0.0, 0.60),
		randfn(0.0, 0.44))

	var start := Vector3(
		clampf(focus.x + spread.x, -EXTENT.x, EXTENT.x),
		clampf(focus.y + spread.y, -EXTENT.y * 0.45, EXTENT.y),
		clampf(focus.z + spread.z, -EXTENT.z, EXTENT.z))

	var direction := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, -0.25),
		randf_range(-1.0, 1.0)).normalized()

	# A few long filaments carrying the composition, and more short ones around
	# them. Uniform lengths read as a pile of identical objects.
	var length := randf_range(1.3, 2.0) if randf() < 0.3 else randf_range(0.45, 1.0)
	var points := PackedVector3Array([start, start + direction * length])
	var offset := 0.20

	for pass_index in 3:
		var next := PackedVector3Array([points[0]])
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			var mid := (a + b) * 0.5
			var jitter := Vector3(
				randf_range(-offset, offset),
				randf_range(-offset, offset),
				randf_range(-offset, offset))
			next.append(mid + jitter)
			next.append(b)
		points = next
		# Slower than the textbook halving, which keeps high-frequency kinks
		# instead of smoothing the bolt into a bent wire.
		offset *= 0.62

	return points


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()

	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.VOID

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.DEEP_INDIGO
	env.ambient_light_energy = 0.06

	# Bloom is what turns an emissive tube into plasma. Threshold kept high so
	# only the hot core blooms and the scene does not wash out.
	env.glow_enabled = true
	env.glow_intensity = 1.30
	env.glow_bloom = 0.45
	env.glow_hdr_threshold = 0.70
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# The bolts light this, which is the single biggest reason to be in 3D.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Palette.DEEP_INDIGO.lightened(0.30)
	env.volumetric_fog_emission = Color(0.02, 0.03, 0.06)
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_length = 12.0

	# Aerial perspective. Without it every filament is equally present and the
	# depth the 3D buys is thrown away.
	env.fog_enabled = true
	env.fog_light_color = Palette.DEEP_INDIGO
	env.fog_light_energy = 0.6
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0

	world.environment = env
	add_child(world)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 46.0
	_camera.position = Vector3(0, 0, 4.0)

	# Shallow focus, so the near bolts sit in front of the far ones instead of
	# every filament being equally sharp.
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 3.4
	attributes.dof_blur_far_transition = 2.0
	attributes.dof_blur_near_enabled = true
	attributes.dof_blur_near_distance = 2.2
	attributes.dof_blur_near_transition = 1.2
	attributes.dof_blur_amount = 0.06
	_camera.attributes = attributes

	add_child(_camera)
	_camera.current = true


## Grain and vignette over the whole frame. Both are quiet: enough to bind the
## image together and take the digital cleanliness off it, not enough to notice
## as an effect.
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


func _maybe_capture() -> void:
	if _capture_path.is_empty() or _elapsed < _capture_after:
		return

	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_capture_path)
	_capture_path = ""
	get_tree().quit()
