class_name IceWorld
extends World

## Ice in a Bottle.
##
## Blocks form one after another and settle into a pile. Moving the phone melts
## some away, outermost first, so the pile shrinks from the top.

const ICE := Color("A8D4E8")

class Block:
	var node: MeshInstance3D
	var target: Vector3
	var spin: Vector3
	var grown: float = 0.0

var _blocks: Array[Block] = []
var _time: float = 0.0
var _melt: float = 0.0


func _init() -> void:
	title = "Ice in a Bottle"
	capacity = 18
	spawn_seconds = 1.1
	focus = Vector3(0, -0.45, 0)
	distance = 3.2


func held() -> int:
	return _blocks.size()


func _tick(delta: float, _population: int, _disturbed: bool) -> void:
	_time += delta
	_melt = maxf(0.0, _melt - delta * 0.8)

	for i in _blocks.size():
		var b := _blocks[i]

		# Blocks grow into place rather than fading in, because ice forms.
		if b.grown < 1.0:
			b.grown = minf(b.grown + delta / 1.6, 1.0)
		b.node.scale = Vector3.ONE * (0.15 + 0.85 * b.grown)

		# Almost imperceptible drift, so a still pile is not a photograph.
		var bob := sin(_time * 0.35 + float(i)) * 0.012
		b.node.position = b.target + Vector3(0, bob, 0)
		b.node.rotation += b.spin * delta

		# Melting shows as the surface going wet and bright before it goes.
		var mat: StandardMaterial3D = b.node.material_override
		mat.emission_energy_multiplier = 0.05 + _melt * 0.35


func _grow() -> bool:
	if _blocks.size() >= capacity:
		return false

	var b := Block.new()

	# Stacked from the bottom, because ice in a vessel would settle. Later
	# blocks sit higher, with enough scatter that it is a pile and not a column.
	var depth := float(_blocks.size()) / float(capacity)
	var angle := randf() * TAU
	var spread := 0.55 * (1.0 - depth * 0.45)

	b.target = Vector3(
		cos(angle) * spread * randf_range(0.3, 1.0),
		-1.15 + depth * 1.9 + randf_range(-0.08, 0.08),
		sin(angle) * spread * randf_range(0.3, 1.0))
	b.spin = Vector3(randf_range(-0.04, 0.04), randf_range(-0.05, 0.05), 0)

	var box := BoxMesh.new()
	box.size = Vector3(randf_range(0.22, 0.38),
	                   randf_range(0.16, 0.30),
	                   randf_range(0.20, 0.34))

	b.node = MeshInstance3D.new()
	b.node.mesh = box
	b.node.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	b.node.position = b.target
	b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Ice is not a glow, it is a surface that catches light, which is the one
	# place in this app where a lit material beats an emissive one. Low
	# roughness for the wet look, and enough transparency that the pile reads as
	# depth rather than as a heap of solid cubes.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(ICE.r, ICE.g, ICE.b, 0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	mat.metallic = 0.0
	mat.emission_enabled = true
	mat.emission = ICE
	mat.emission_energy_multiplier = 0.05
	# Both faces, so light appears to pass through the block rather than
	# stopping at the near wall.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	b.node.material_override = mat

	add_child(b.node)
	_blocks.append(b)
	return true


func _shrink() -> void:
	_melt = 1.0

	var leaving := int(ceil(float(_blocks.size()) * LOSS_FRACTION))
	for _i in leaving:
		if _blocks.size() <= 1:
			return
		# Topmost first: a pile melts from the exposed surface down.
		var highest := 0
		for j in _blocks.size():
			if _blocks[j].target.y > _blocks[highest].target.y:
				highest = j
		_blocks[highest].node.queue_free()
		_blocks.remove_at(highest)
