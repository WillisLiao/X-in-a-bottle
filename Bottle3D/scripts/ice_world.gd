class_name IceWorld
extends World

## Ice in a Bottle.
##
## Shards form one after another and settle into a drift across the floor.
## Moving the phone melts some away, the exposed ones first.
##
## The first pass used boxes with a flat translucent material, which read as
## tinted glass cubes. Ice is faceted and it is the facets catching light at
## different angles that sell it, so these are jittered icosahedra with hard
## per-face normals, a bright specular, and a rim that only shows where the
## surface turns away.

const ICE := Color("9FD0E8")
const CORE := Color("D8F0FF")
const FROST := Color("121C2A")

class Block:
	var node: MeshInstance3D
	var glint: MeshInstance3D
	var target: Vector3
	var spin: Vector3
	var grown: float = 0.0
	var phase: float = 0.0

var _blocks: Array[Block] = []
var _time: float = 0.0
var _melt: float = 0.0


func _init() -> void:
	title = "Ice in a Bottle"
	capacity = 18
	spawn_seconds = 1.1

	focus = Vector3(0, -0.52, 0)
	distance = 3.3

	# Cold, but bright. Ice is a surface that catches light rather than one that
	# emits, so it needs a key strong enough to strike a facet.
	key_color = Color("D8ECFF")
	key_energy = 1.55
	fill_color = Color("5A86C8")
	fill_energy = 0.65
	ambient_color = Color("1C2A3E")
	ambient_energy = 0.85


func build() -> void:
	# A frozen floor, so the shards are lying on something. Dark, and smooth
	# enough that the key light streaks across it.
	var disc := CylinderMesh.new()
	disc.top_radius = 4.4
	disc.bottom_radius = 4.4
	disc.height = 0.05
	disc.radial_segments = 28
	disc.rings = 1

	var floor_node := MeshInstance3D.new()
	floor_node.mesh = disc
	floor_node.position = Vector3(0, -1.02, -0.1)
	# Rough and non-metallic. At 0.28 roughness with a touch of metal the key
	# light struck the floor as a single blown-out white streak across the whole
	# frame - a mirror, not frozen ground.
	var mat := World.solid_material(FROST, 0.92)
	mat.metallic = 0.0
	floor_node.material_override = mat
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_node)


func held() -> int:
	return _blocks.size()


func _tick(delta: float, _population: int, _disturbed: bool) -> void:
	_time += delta
	_melt = maxf(0.0, _melt - delta * 0.8)

	for i in _blocks.size():
		var b := _blocks[i]

		# Shards grow into place rather than fading in, because ice forms.
		if b.grown < 1.0:
			b.grown = minf(b.grown + delta / 1.6, 1.0)
		b.node.scale = Vector3.ONE * (0.15 + 0.85 * b.grown)

		# Almost imperceptible drift, so a still drift is not a photograph.
		b.node.position = b.target + Vector3(0, sin(_time * 0.35 + b.phase) * 0.010, 0)
		b.node.rotation += b.spin * delta

		# A glint that comes and goes as the shard turns, which is what a facet
		# actually does. Each on its own phase so they never twinkle in unison.
		var sparkle: float = maxf(0.0, sin(_time * 0.9 + b.phase * 3.0))
		b.glint.scale = Vector3.ONE * (0.35 + 0.65 * sparkle * b.grown)

		var mat: StandardMaterial3D = b.node.material_override
		mat.emission_energy_multiplier = 0.04 + _melt * 0.30
		# Melting shows as the surface going wet: rougher, less crisp, and the
		# alpha rising as the shard thins.
		mat.roughness = 0.06 + _melt * 0.45


func _grow() -> bool:
	if _blocks.size() >= capacity:
		return false

	var b := Block.new()
	b.phase = randf() * TAU

	# A drift spread across the width rather than a column stacked up the middle,
	# because height is the dimension the landscape screen has least of.
	var depth := float(_blocks.size()) / float(capacity)
	b.target = Vector3(
		randf_range(-2.1, 2.1),
		-0.85 + depth * 0.85 + randf_range(-0.10, 0.10),
		randf_range(-0.55, 0.35))
	b.spin = Vector3(randf_range(-0.03, 0.03), randf_range(-0.04, 0.04), 0)

	b.node = MeshInstance3D.new()
	b.node.mesh = Geometry.crystal(randf_range(0.13, 0.24), 0.28)
	b.node.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	b.node.position = b.target
	b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Translucent, but hard. A high specular and a low roughness are what make a
	# facet flash as it turns; the rim keeps the silhouette legible against the
	# dark, which plain alpha does not.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(ICE.r, ICE.g, ICE.b, 0.50)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.06
	mat.metallic = 0.0
	mat.metallic_specular = 0.95
	mat.rim_enabled = true
	mat.rim = 0.85
	mat.rim_tint = 0.35
	mat.emission_enabled = true
	mat.emission = CORE
	mat.emission_energy_multiplier = 0.04
	# Both faces, so light appears to pass through rather than stopping at the
	# near wall.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	b.node.material_override = mat

	# A small bright core, seen through the shard. Cheap depth: without it a
	# translucent solid has nothing inside it to look at.
	b.glint = MeshInstance3D.new()
	var spark := SphereMesh.new()
	spark.radius = 0.030
	spark.height = 0.060
	spark.radial_segments = 6
	spark.rings = 3
	b.glint.mesh = spark
	b.glint.material_override = World.glow_material(CORE, 0.55)
	b.glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.node.add_child(b.glint)

	add_child(b.node)
	_blocks.append(b)
	return true


func _shrink() -> void:
	_melt = 1.0

	var leaving := int(ceil(float(_blocks.size()) * LOSS_FRACTION))
	for _i in leaving:
		if _blocks.size() <= 1:
			return
		# Topmost first: a drift melts from the exposed surface down.
		var highest := 0
		for j in _blocks.size():
			if _blocks[j].target.y > _blocks[highest].target.y:
				highest = j
		_blocks[highest].node.queue_free()
		_blocks.remove_at(highest)
