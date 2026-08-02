class_name RumorMarks
extends Control

## The screen-space invitation above an unclaimed roadside rumor.
##
## The lantern is a real object in the world. This small four-ray halo is only
## the map-distance affordance that makes it tappable without a word, a pin, or
## a billboard growing out of the terrain.

const MAP_FROM := 0.30

var _camera: Camera3D
var _country: Country
var _map := 0.0
var _pulse := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_context(camera: Camera3D, country: Country) -> void:
	_camera = camera
	_country = country
	queue_redraw()


func set_map(amount: float) -> void:
	_map = clampf(amount, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	if _map < MAP_FROM:
		return
	_pulse += delta
	# The marker is tied to a moving camera, so it must follow an orbit even
	# when the player has not touched it. The motion is deliberately slight: the
	# lantern is the invitation, not an urgent notification.
	queue_redraw()


func _draw() -> void:
	if _camera == null or _country == null:
		return
	var alpha := smoothstep(MAP_FROM, 0.54, _map)
	if alpha <= 0.001:
		return

	var bounds := get_viewport_rect().size
	for world_at in _country.rumor_positions():
		if _camera.is_position_behind(world_at):
			continue
		var at := _camera.unproject_position(world_at)
		if at.x < -24.0 or at.x > bounds.x + 24.0 or at.y < -24.0 or at.y > bounds.y + 24.0:
			continue
		_draw_rumor(at, alpha)


func _draw_rumor(at: Vector2, alpha: float) -> void:
	var breath := 0.78 + 0.22 * sin(_pulse * 2.4)
	var ink := Color(1.0, 0.72, 0.32, alpha * breath)
	var dim := Color(1.0, 0.55, 0.16, alpha * 0.34)
	var radius := 11.0 + breath * 2.0

	# A four-point glint sits more naturally above a lantern than a circular map
	# pin, and its wide centre is an intentionally forgiving tap target below.
	draw_line(at + Vector2(-radius, 0), at + Vector2(radius, 0), dim, 1.6, true)
	draw_line(at + Vector2(0, -radius), at + Vector2(0, radius), dim, 1.6, true)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -radius), at + Vector2(4.0, -4.0),
		at + Vector2(radius, 0), at + Vector2(4.0, 4.0),
		at + Vector2(0, radius), at + Vector2(-4.0, 4.0),
		at + Vector2(-radius, 0), at + Vector2(-4.0, -4.0),
	]), ink)
	draw_circle(at, 3.0, Color(1.0, 0.94, 0.72, alpha))
