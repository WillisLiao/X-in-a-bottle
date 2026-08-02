class_name Feast
extends Node3D

## The meal is not part of `Plan.Kind`.
## Building materials carry recipes, piles, beliefs, and saved stock.
## Food only needs to be seen, eaten, and gone, so keeping it here prevents a
## ten-minute feast from becoming a second construction economy.
enum Food { FISH, FRUIT, BREAD }

const FILL_SECONDS := 2.0 * 60.0 * 60.0

## The terrain shore falls away at 1.02.
## This stays a little inside it, where the ribbon follows solid land rather
## than the folded edge that only exists to finish the ground mesh.
const COAST := 0.95
const STEPS := 120
const HALF_WIDTH := 0.035
const LIFT := 0.028

## Ember holds on the Meadow, Dunes, Shore, and Green.
## The Ice needs a colder, brighter cue because the warm version disappears
## against blue-white snow before bloom can make it legible.
const ACCENT := [
	Color("FF9A4A"),
	Color("B9ECFF"),
	Color("FFB15B"),
	Color("FFE0A0"),
	Color("FFCC70"),
]

var _land: Land
var _material: ShaderMaterial


func _init(land: Land, region: int) -> void:
	_land = land
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/coast.gdshader")
	_material.set_shader_parameter("accent", ACCENT[clampi(region, 0, ACCENT.size() - 1)])

	var rim := MeshInstance3D.new()
	rim.mesh = _mesh()
	rim.material_override = _material
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)


## `breathe` only means the food can be called.
## A completed coast stays deliberately dim through a break, so the resting
## hearth remains the world's brightest event and tapping cannot spend a meal
## while nobody is ready to eat it.
func set_progress(progress: float, breathe: bool) -> void:
	_material.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
	_material.set_shader_parameter("breathe", 1.0 if breathe else 0.0)


## A meal item is deliberately a loose scene object, not a `Pile` entry.
## It only exists long enough to land, be carried, and be eaten.
static func make_food(kind: int) -> Node3D:
	var root := Node3D.new()
	root.set_meta("food", kind)

	var body := MeshInstance3D.new()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)

	match kind:
		Food.FISH:
			var fish := SphereMesh.new()
			fish.radius = 0.060
			fish.height = 0.120
			fish.radial_segments = 7
			fish.rings = 4
			body.mesh = fish
			body.scale = Vector3(1.45, 0.62, 0.72)
			body.rotation.y = randf() * TAU
			body.material_override = World.solid_material(Color("7D9BB0"), 0.52)

			var tail := MeshInstance3D.new()
			var fin := PrismMesh.new()
			fin.left_to_right = 0.11
			fin.size = Vector3(0.05, 0.010, 0.08)
			tail.mesh = fin
			tail.position = Vector3(-0.090, 0.0, 0.0)
			tail.rotation.y = body.rotation.y
			tail.material_override = body.material_override
			tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(tail)
		Food.FRUIT:
			var fruit := SphereMesh.new()
			fruit.radius = 0.058
			fruit.height = 0.116
			fruit.radial_segments = 7
			fruit.rings = 4
			body.mesh = fruit
			body.material_override = World.solid_material(Color("C95D3B"), 0.68)
		Food.BREAD:
			var loaf := CapsuleMesh.new()
			loaf.radius = 0.052
			loaf.height = 0.145
			loaf.radial_segments = 7
			loaf.rings = 3
			body.mesh = loaf
			body.rotation.z = PI * 0.5
			body.material_override = World.solid_material(Color("C99B56"), 0.82)

	return root


func _mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in STEPS:
		var t0 := float(i) / float(STEPS)
		var t1 := float(i + 1) / float(STEPS)
		var inner0 := _point(t0 * TAU, -HALF_WIDTH)
		var outer0 := _point(t0 * TAU, HALF_WIDTH)
		var inner1 := _point(t1 * TAU, -HALF_WIDTH)
		var outer1 := _point(t1 * TAU, HALF_WIDTH)

		# Wound upward like `Land.mesh`.
		# The material disables culling too, because a shallow camera can see the
		# underside of the far shoreline, but the correct winding keeps the mesh
		# useful if that ever changes.
		_vertex(st, inner0, Vector2(t0, 0.0))
		_vertex(st, outer1, Vector2(t1, 1.0))
		_vertex(st, outer0, Vector2(t0, 1.0))
		_vertex(st, inner0, Vector2(t0, 0.0))
		_vertex(st, inner1, Vector2(t1, 0.0))
		_vertex(st, outer1, Vector2(t1, 1.0))

	return st.commit()


func _point(angle: float, width: float) -> Vector3:
	var wobble := 1.0 + 0.10 * sin(angle * 3.0 + 0.7) \
		+ 0.06 * sin(angle * 5.0 + 2.1)
	var edge := COAST * wobble / sqrt(
		pow(cos(angle) / Land.LAND_X, 2.0) + pow(sin(angle) / Land.LAND_Z, 2.0))
	var p := Vector3((edge + width) * cos(angle), 0.0,
		(edge + width) * sin(angle))
	return _land.on(p) + Vector3(0.0, LIFT, 0.0)


func _vertex(st: SurfaceTool, at: Vector3, uv: Vector2) -> void:
	st.set_uv(uv)
	st.set_normal(Vector3.UP)
	st.add_vertex(at)
