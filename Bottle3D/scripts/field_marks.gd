class_name FieldMarks
extends Control

## Screen-space field affordances for the one nearby thing worth touching.
##
## The road and hearth already belong to the world. This control only makes
## the unclaimed roadside rumor readable at map distance, without turning the
## field into a dashboard or putting words over it.

const MAP_FROM := 0.30
const OUTER_RAY := 30.0
const HIT_GLOW := Color(1.45, 0.66, 0.18)

var _camera: Camera3D
var _country: Country
var _map := 0.0
var _pulse := 0.0
var _bloom_at := Vector2.ZERO
var _bloom := 0.0


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


func claim_feedback(at: Vector2) -> void:
	_bloom_at = at
	_bloom = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _map < MAP_FROM and _bloom <= 0.0:
		return
	_pulse += delta
	_bloom = maxf(0.0, _bloom - delta * 2.4)
	queue_redraw()


func _draw() -> void:
	if _camera == null or _country == null:
		return
	var alpha := smoothstep(MAP_FROM, 0.54, _map)
	if alpha > 0.001:
		var bounds := get_viewport_rect().size
		for world_at in _country.rumor_positions():
			if _camera.is_position_behind(world_at):
				continue
			var at := _camera.unproject_position(world_at)
			if at.x < -40.0 or at.x > bounds.x + 40.0 or at.y < -40.0 or at.y > bounds.y + 40.0:
				continue
			_draw_rumor(at, alpha)
	if _bloom > 0.0:
		_draw_bloom(_bloom_at, _bloom)


func _draw_rumor(at: Vector2, alpha: float) -> void:
	var breath := 0.82 + 0.18 * sin(_pulse * 1.45)
	var radius := OUTER_RAY * breath
	var ink := Color(1.0, 0.72, 0.32, alpha * breath)
	var dim := Color(1.0, 0.55, 0.16, alpha * 0.42)
	# The short cross-light ties the field marker back to the warm road below.
	draw_line(at + Vector2(-radius * 1.35, 0), at + Vector2(radius * 1.35, 0), dim, 2.0, true)
	draw_line(at + Vector2(0, -radius * 1.35), at + Vector2(0, radius * 1.35), dim, 2.0, true)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -radius), at + Vector2(7.0, -7.0),
		at + Vector2(radius, 0), at + Vector2(7.0, 7.0),
		at + Vector2(0, radius), at + Vector2(-7.0, 7.0),
		at + Vector2(-radius, 0), at + Vector2(-7.0, -7.0),
	]), ink)
	draw_circle(at, 5.0, Color(1.0, 0.94, 0.72, alpha))


func _draw_bloom(at: Vector2, strength: float) -> void:
	var radius := lerpf(10.0, 74.0, 1.0 - strength)
	draw_circle(at, radius, Color(HIT_GLOW, strength * 0.12), false, 3.0, true)
	draw_circle(at, 7.0 + 12.0 * strength, Color(1.0, 0.86, 0.52, strength * 0.48))
