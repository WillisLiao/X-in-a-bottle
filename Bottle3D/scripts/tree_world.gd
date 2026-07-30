class_name TreeWorld
extends World

## Tree in a Bottle.
##
## A different dynamic to the others: the objects are connected rather than
## scattered, so stillness builds a structure instead of a collection. A
## disturbance cuts limbs off it.
##
## Cuts always take the outermost branch. Cutting an inner one would orphan
## everything past it and the tree would fall apart rather than be pruned.

# Brown, not bone. Under a key strong enough to read at all, a pale bark washed
# out to near-white and the grove looked like coral.
const BARK := Color("5E4636")
const GROUND := Color("15181F")
const LEAF := Color("4E9A5A")
const LEAF_LIT := Color("8FD48B")

## Branches at or past this depth carry foliage. Second level, not third: at
## third the grove was bare sticks for minutes before a single leaf appeared.
const LEAF_DEPTH := 2

## In landscape the screen is wide and short, so height runs out long before
## width does. One tall tree wastes most of the frame; a row of smaller ones
## fills it and reads better as something growing.
const MAX_TREES := 5

## Where trunks go in, centre first and then outward, so a half-grown grove is
## still balanced rather than drifting off one side.
## The visible width at this camera distance is roughly eight metres, so the
## grove has to span most of that or it huddles in the middle of a wide frame.
const TRUNK_X := [0.0, -1.85, 1.85, -3.30, 3.30]

## A new trunk goes in once the existing trees have this many branches each.
const BRANCHES_PER_TREE := 5

class Branch:
	var node: MeshInstance3D
	var leaves: MeshInstance3D
	var from: Vector3
	var to: Vector3
	var radius: float
	var depth: int
	var direction: Vector3
	var children: int = 0
	var grown: float = 0.0

var _branches: Array[Branch] = []
var _sway: float = 0.0


func _init() -> void:
	title = "Tree in a Bottle"
	capacity = 26
	spawn_seconds = 1.0
	focus = Vector3(0, -0.10, 0)
	distance = 4.6

	# Moonlight, not plasma. Under the cold blue key the bark was nearly black
	# and the grove read as bare wire.
	key_color = Color("CFE0FF")
	key_energy = 1.15
	fill_color = Color("6E8CB8")
	fill_energy = 0.55
	ambient_color = Color("242C42")
	ambient_energy = 0.95


var _trunks := 0


func build() -> void:
	# Ground, so the trunks are rooted in something rather than hanging in a
	# void. Dark enough to stay a suggestion.
	var disc := CylinderMesh.new()
	disc.top_radius = 4.6
	disc.bottom_radius = 4.6
	disc.height = 0.05
	disc.radial_segments = 28
	disc.rings = 1

	var ground := MeshInstance3D.new()
	ground.mesh = disc
	ground.position = Vector3(0, -1.32, -0.1)
	ground.material_override = World.solid_material(GROUND, 1.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

	_plant()


func held() -> int:
	return _branches.size()


func _tick(delta: float, _population: int, disturbed: bool) -> void:
	_sway += delta * (0.15 if disturbed else 0.4)

	for i in _branches.size():
		var b := _branches[i]

		# Growing branches extend rather than fade in, so growth reads as the
		# tree putting out a limb instead of one appearing.
		if b.grown < 1.0:
			b.grown = minf(b.grown + delta / 1.8, 1.0)
			b.node.scale = Vector3.ONE * maxf(b.grown, 0.02)

		if b.leaves:
			b.leaves.visible = b.grown > 0.55
			var s: float = clampf((b.grown - 0.55) / 0.45, 0.0, 1.0)
			b.leaves.scale = Vector3.ONE * s

		# Anchored at the base and fullest at the tip, each on its own phase, so
		# the canopy bends rather than sliding as one rigid piece.
		var lean := sin(_sway + float(i) * 0.7) * 0.012 * float(b.depth)
		b.node.rotation.z = lean
		if b.leaves:
			b.leaves.position = b.to + Vector3(lean * 1.6, 0, 0)


func _grow() -> bool:
	if _branches.size() >= capacity:
		return false

	# Another tree, or another branch on the trees already here. Planting only
	# once the grove is evenly grown keeps it from becoming one full tree beside
	# four bare sticks.
	if _trunks < MAX_TREES and _branches.size() >= _trunks * BRANCHES_PER_TREE:
		_plant()
		return true

	# Shallowest first, then least forked. Sorting by children before depth
	# always extends whichever tip is newest, and the tree grows depth-first as
	# a single whip rather than as a tree.
	var parent: Branch = null
	for b in _branches:
		if b.children >= 2:
			continue
		if parent == null or b.depth < parent.depth \
				or (b.depth == parent.depth and b.children < parent.children):
			parent = b
	if parent == null:
		return false

	parent.children += 1

	# Alternate sides using the total count as well as the parent's, or every
	# first child leans the same way and the tree spirals to one side.
	var side := 1.0 if (parent.children + _branches.size()) % 2 == 0 else -1.0
	var axis := Vector3.FORWARD if _branches.size() % 3 == 0 else Vector3.RIGHT

	var swung := parent.direction.rotated(axis, side * 0.55).normalized()
	# Pulled back toward vertical at every level, or the spread compounds along
	# a limb and the outer branches end up pointing at the floor.
	var direction := swung.lerp(Vector3.UP, 0.22).normalized()
	direction = direction.rotated(Vector3.UP, randf_range(-0.5, 0.5)).normalized()

	var length := 0.56 * pow(0.80, float(parent.depth)) * randf_range(0.85, 1.15)
	var radius := parent.radius * 0.72

	_add_branch(parent.to, parent.to + direction * length,
				radius, parent.depth + 1, direction)
	return true


func _shrink() -> void:
	var leaving := int(ceil(float(_branches.size()) * LOSS_FRACTION))
	for _i in leaving:
		# Never the trunk. A bottle with no tree in it is a punishment rather
		# than a cost.
		if _branches.size() <= _trunks:
			return

		var outermost: Branch = null
		var index := -1
		for j in _branches.size():
			# Trunks stay. A bottle with no trees in it is a punishment rather
			# than a cost.
			if _branches[j].depth == 0:
				continue
			if outermost == null or _branches[j].depth >= outermost.depth:
				outermost = _branches[j]
				index = j
		if index < 0:
			return

		# The parent gets its slot back, so the tree regrows into the gap.
		for b in _branches:
			if b.to.is_equal_approx(outermost.from):
				b.children = maxi(0, b.children - 1)

		outermost.node.queue_free()
		if outermost.leaves:
			outermost.leaves.queue_free()
		_branches.remove_at(index)


func _plant() -> void:
	var x: float = TRUNK_X[_trunks] + randf_range(-0.12, 0.12)
	var z := randf_range(-0.45, 0.25)

	# Later trees are a little shorter and thinner, so the grove has a front and
	# a back rather than being a row of identical objects.
	var scale := 1.0 - float(_trunks) * 0.07
	var base := Vector3(x, -1.30, z)

	_trunks += 1
	_add_branch(base, base + Vector3(0, 0.95 * scale, 0),
				0.090 * scale, 0, Vector3.UP)


func _add_branch(from: Vector3, to: Vector3, radius: float,
                 depth: int, direction: Vector3) -> void:
	var b := Branch.new()
	b.from = from
	b.to = to
	b.radius = radius
	b.depth = depth
	b.direction = direction

	# A slight wander, so no branch is a straight stick.
	var path := Geometry.jagged(from, to, radius * 0.9, 2)

	b.node = MeshInstance3D.new()
	b.node.mesh = Geometry.tube(path, radius, radius * 0.72, 6, false)
	b.node.material_override = World.solid_material(BARK, 0.85)
	b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(b.node)

	if depth >= LEAF_DEPTH:
		b.leaves = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.17
		sphere.height = 0.28
		sphere.radial_segments = 7
		sphere.rings = 4
		b.leaves.mesh = sphere
		var mat := World.solid_material(LEAF, 0.95)
		mat.emission_enabled = true
		mat.emission = LEAF_LIT
		# Barely any. At 0.12 the clusters clipped into the bloom pass and the
		# canopy glowed like something radioactive.
		mat.emission_energy_multiplier = 0.03
		b.leaves.material_override = mat
		b.leaves.position = to
		b.leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(b.leaves)

	_branches.append(b)
