class_name LockMarks
extends Control

## The locks are screen space, not map pins in the 3D scene.
## A paid gate must be readable from the map without becoming a tree-sized sign
## when the camera comes down, and it must disappear entirely once the camera is
## back in the region where the normal close-view rules apply.

const BODY_HALF := Vector2(15.0, 11.0)
const ROUND := 4.0

var _camera: Camera3D
var _country: Country
var _map := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_context(camera: Camera3D, country: Country) -> void:
	_camera = camera
	_country = country
	queue_redraw()


func set_map(amount: float) -> void:
	var next := clampf(amount, 0.0, 1.0)
	if is_equal_approx(next, _map):
		return
	_map = next
	queue_redraw()


func _process(_delta: float) -> void:
	# The camera can orbit while the map amount is held, so position is sampled
	# every frame even when the fade amount has not changed.
	if _map > 0.01:
		queue_redraw()


func _draw() -> void:
	if _camera == null or _country == null:
		return

	# Fully absent in a close view, then clear before a map tap can reach a
	# distant region. The icon is only an explanation of an unavailable target,
	# not furniture in a place somebody is already looking at.
	var alpha := smoothstep(0.30, 0.58, _map)
	if alpha <= 0.001:
		return

	var bounds := get_viewport_rect().size
	for region in Region.PAID:
		if Progress.purchased(region):
			continue
		var world_at := _country.where(region) + Vector3(0.0, 0.68, 0.0)
		if _camera.is_position_behind(world_at):
			continue
		var at := _camera.unproject_position(world_at)
		if at.x < -BODY_HALF.x or at.x > bounds.x + BODY_HALF.x \
				or at.y < -BODY_HALF.y or at.y > bounds.y + BODY_HALF.y:
			continue
		_draw_lock(at, alpha)


func _draw_lock(at: Vector2, alpha: float) -> void:
	var ink := Color(1.0, 1.0, 1.0, alpha)
	var body := Rect2(at - BODY_HALF, BODY_HALF * 2.0)

	# Four discs and two rectangles make a rounded body without borrowing a
	# themed widget. The solid white silhouette survives the pale Ice and the
	# warm Dunes equally well.
	draw_rect(Rect2(body.position + Vector2(ROUND, 0.0),
		Vector2(body.size.x - ROUND * 2.0, body.size.y)), ink)
	draw_rect(Rect2(body.position + Vector2(0.0, ROUND),
		Vector2(body.size.x, body.size.y - ROUND * 2.0)), ink)
	for corner in [
		body.position + Vector2(ROUND, ROUND),
		body.position + Vector2(body.size.x - ROUND, ROUND),
		body.position + Vector2(ROUND, body.size.y - ROUND),
		body.end - Vector2(ROUND, ROUND),
	]:
		draw_circle(corner, ROUND, ink)

	# The shackle sits behind the body and comes through just enough at the
	# shoulders to say padlock rather than suitcase handle.
	draw_arc(at + Vector2(0.0, -7.0), 9.0, PI, TAU, 18, ink, 3.0, true)
