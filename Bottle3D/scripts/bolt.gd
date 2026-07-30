class_name Bolt
extends Node3D

## One captured bolt, suspended in the bottle.
##
## Built as a real tube in 3D rather than a line drawn on a flat canvas. That is
## the whole reason for moving to 3D: the tube has volume, it lights the fog
## around it, it occludes and is occluded, and it shifts against the others when
## the phone tilts. None of that is available to a 2D shader.

## Sides around the tube. Six is plenty at this scale and keeps the mesh cheap
## when a full bottle holds a dozen of these.
const SIDES := 6

## The bright inner filament, and the wider soft sheath around it. A single
## tube reads as a wire; it needs a hot core inside a haze.
const CORE_RADIUS := 0.007
const SHEATH_RADIUS := 0.070

var _core: MeshInstance3D
var _sheath: MeshInstance3D
var _light: OmniLight3D
var _phase: float = 0.0
var _energy: float = 0.0
var _gas: Color = Palette.PLASMA

## Seconds of holding before a bolt is as cool as it gets. The signature of the
## whole environment: a full bottle is a history, with bright new arrivals
## against old filaments that have nearly gone out.
const COOL_SECONDS := 150.0

var _age_seconds: float = 0.0


func build(points: PackedVector3Array, phase: float, gas: Color) -> void:
	_phase = phase
	_gas = gas

	_core = MeshInstance3D.new()
	_core.mesh = _tube(points, CORE_RADIUS)
	_core.material_override = _core_material()
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	_sheath = MeshInstance3D.new()
	_sheath.mesh = _tube(points, SHEATH_RADIUS)
	_sheath.material_override = _sheath_material()
	_sheath.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sheath)

	# A real light, so the bolt illuminates the fog and anything near it rather
	# than merely being bright itself. This is what sells it as plasma.
	_light = OmniLight3D.new()
	_light.position = points[points.size() / 2]
	_light.light_color = _gas
	_light.omni_range = 1.5
	_light.light_volumetric_fog_energy = 1.8
	_light.shadow_enabled = false
	add_child(_light)


## 0 to 1. Held lightning is not steady, so this drives a breathing on top.
func set_energy(value: float) -> void:
	_energy = value


func _process(delta: float) -> void:
	_phase += delta
	_age_seconds += delta

	var age := clampf(_age_seconds / COOL_SECONDS, 0.0, 1.0)
	var cooled := Palette.cooled(_gas, age)

	# Older bolts breathe more slowly as well as more dimly, so a full bottle
	# has rhythm in it rather than one uniform pulse.
	var breathe := 0.70 + 0.30 * sin(_phase * (2.3 - age * 1.1))

	# Never all the way out. A dead filament reads as a bug, not as age.
	var lit: float = _energy * breathe * (1.0 - age * 0.72)

	_core.material_override.emission_energy_multiplier = 9.0 * lit
	_core.material_override.emission = Palette.CORE.lerp(cooled, age * 0.6)

	_sheath.material_override.emission_energy_multiplier = 0.85 * lit
	_sheath.material_override.emission = cooled

	_light.light_energy = 0.85 * lit
	_light.light_color = cooled


func _core_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Palette.CORE
	mat.albedo_color = Palette.CORE
	return mat


func _sheath_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# Drawn from the inside as well, so the haze wraps the core instead of
	# presenting a hard silhouette against it.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = _gas
	mat.albedo_color = Color(_gas.r, _gas.g, _gas.b, 0.075)
	return mat


## Sweeps a ring along the polyline. The frame is carried from segment to
## segment rather than rebuilt from a fixed up-vector, or the tube twists
## wherever the path turns back on itself.
func _tube(points: PackedVector3Array, radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var normal := Vector3.UP
	var rings: Array[PackedVector3Array] = []

	for i in points.size():
		var tangent: Vector3
		if i == 0:
			tangent = (points[1] - points[0]).normalized()
		elif i == points.size() - 1:
			tangent = (points[i] - points[i - 1]).normalized()
		else:
			tangent = (points[i + 1] - points[i - 1]).normalized()

		# Re-orthogonalise the carried normal against the new tangent.
		normal = (normal - tangent * normal.dot(tangent))
		if normal.length() < 0.001:
			normal = tangent.cross(Vector3.RIGHT)
		normal = normal.normalized()
		var binormal := tangent.cross(normal)

		# Tapered at both ends so a bolt fades to a point instead of stopping
		# at a flat disc.
		var t := float(i) / float(points.size() - 1)
		var taper: float = sin(t * PI)
		taper = 0.25 + 0.75 * taper

		var ring := PackedVector3Array()
		for s in SIDES:
			var a := TAU * float(s) / float(SIDES)
			ring.append(points[i] + (normal * cos(a) + binormal * sin(a)) * radius * taper)
		rings.append(ring)

	for i in rings.size() - 1:
		for s in SIDES:
			var n := (s + 1) % SIDES
			var a := rings[i][s]
			var b := rings[i][n]
			var c := rings[i + 1][n]
			var d := rings[i + 1][s]
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)

	st.generate_normals()
	return st.commit()
