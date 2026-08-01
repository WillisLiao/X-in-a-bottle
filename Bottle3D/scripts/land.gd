class_name Land
extends RefCounted

## The ground of one region, and nothing that stands on it.
##
## This used to live inside `ElfWorld`, where it was perfectly fine right up
## until there was more than one region on screen at once. A region nobody is
## standing in still has to be drawn - it is most of what you are looking at
## when the camera pulls back to the whole world - and it has no elves, no
## queue, no heaps and no reason to be an `ElfWorld` at all. So the land came
## out on its own.
##
## It is an object holding a biome rather than a bag of static functions taking
## one, because `height` is called four times per line-of-sight check and once
## per terrain vertex, and there are a great many of both.
##
## ## What is not in here any more
##
## The paths. This file used to draw seven authored routes out from the site and
## burn them into the ground colour when the region was built - the same paths,
## at full strength, from the first second, in every region including ones
## nobody had ever been to. They are recorded rather than drawn now: see `Wear`
## and `ground.gdshader`.

## Half-extents of a region. Big enough that the walk to the reedbed passes
## behind a ridge and out of sight, small enough to compose in a phone frame.
const LAND_X := Biome.LAND_X
const LAND_Z := Biome.LAND_Z

## And of the mesh, which carries a little past the shoreline so the land has
## somewhere to fall away to. `Wear` and `ground.gdshader` measure against these
## rather than against the land, so a track running down to the water is not
## clipped short of it.
const REACH_X := LAND_X * 1.34
const REACH_Z := LAND_Z * 1.38

var index := 0

var _b := {}
var _relief: Array = []


func _init(region := 0) -> void:
	index = region
	_b = Biome.of(region)
	_relief = Biome.relief(region)


## The height of the land under a place. The terrain mesh, every station and
## every elf's feet read from this one function, so the land and the people on
## it cannot drift apart.
func height(p: Vector3) -> float:
	var h := 0.085 * sin(p.x * 0.85 + 0.4) * cos(p.z * 1.1)
	h += 0.055 * sin(p.z * 1.55 + 1.2)

	for k in _relief:
		var d: Vector3 = k["at"]
		var u: float = (p.x - d.x) / k["rx"]
		var v: float = (p.z - d.z) / k["rz"]
		h += k["amount"] * exp(-(u * u + v * v))

	# The shore, and then nothing. An irregular edge, because a rectangle of
	# ground floating in the dark reads as a diorama base.
	var a := atan2(p.z, p.x)
	var wobble := 1.0 + 0.10 * sin(a * 3.0 + 0.7) + 0.06 * sin(a * 5.0 + 2.1)
	var r := Vector2(p.x / (LAND_X * wobble), p.z / (LAND_Z * wobble)).length()
	var lip := clampf((1.02 - r) / 0.16, 0.0, 1.0)
	return h * lip - (1.0 - lip) * (0.45 + (r - 1.02) * 2.4)


func on(p: Vector3) -> Vector3:
	return Vector3(p.x, height(p), p.z)


func colour(p: Vector3) -> Color:
	var c: Color = _b["ground"]
	c = c.lerp(_b["ground_lit"], clampf(p.y * 0.7 + 0.42, 0.0, 1.0))

	# Patchiness at a scale bigger than a facet. Without it the whole region is
	# one flat colour and no amount of cover planted on top rescues it.
	#
	# Three waves rather than one, at frequencies that do not divide into each
	# other and on axes that are not the grid's. A single `sin(x) * cos(z)` is a
	# plaid: it lines its light and dark patches up with the ground mesh, and
	# two regular patterns on top of each other are far more visible than either
	# alone. This wanders instead.
	var patch := 0.5 + 0.30 * sin(p.x * 0.71 + p.z * 0.43 + 0.3) \
		+ 0.16 * sin(p.x * 1.13 - p.z * 1.67 - 0.8) \
		+ 0.09 * sin(p.x * 2.87 + p.z * 2.31 + 1.9)
	c = c.lerp(_b["patch"], clampf(patch, 0.0, 1.0) * 0.34)

	for place in ["quarry", "mine"]:
		var d := _gap(p, Biome.LAYOUT[place]) / 1.30
		c = c.lerp(_b["rocky"], clampf(exp(-d * d), 0.0, 0.95))

	for place in ["pool", "sandbank"]:
		var d := _gap(p, Biome.LAYOUT[place]) / 1.20
		c = c.lerp(_b["shore"], clampf(exp(-d * d), 0.0, 0.90))

	# Bare ground as the land falls away to the shore.
	c = c.lerp(Color(_b["shore"]).darkened(0.35), clampf(-p.y * 1.6, 0.0, 0.85))

	# The last of the variation, and it used to be white noise: every facet
	# given its own random shift of up to three and a half per cent, which at
	# that facet size is salt and pepper. It made the ground look soiled rather
	# than varied, and it was half of why the terrain was tiring to look at.
	#
	# Now it drifts. Neighbouring vertices get nearly the same shift, so the
	# tone moves across the ground in broad sweeps the way light does, and only
	# a whisper of the old randomness is left to keep the sweeps from looking
	# ruled on.
	var v := 0.026 * sin(p.x * 3.1 - p.z * 1.9 + 0.6) \
		+ 0.018 * sin(p.x * 1.3 + p.z * 4.1 - 2.2) \
		+ randf_range(-0.005, 0.005)
	return Color(clampf(c.r + v, 0, 1), clampf(c.g + v, 0, 1), clampf(c.b + v, 0, 1))


## How far out the mesh is carried before it is folded back onto the shoreline.
## Past `1.02` the height field is already falling away into nothing; this is
## where the geometry stops following it down.
const EDGE := 1.26

## How far a vertex may wander from where the grid put it, as a fraction of one
## cell. Just under a half, so no vertex can cross a neighbour and turn a facet
## inside out.
const JITTER := 0.44


## The whole region as one mesh.
##
## `nx` and `nz` are the grid, and they are the only dial on what a region costs
## to draw. The region being lived in gets the full amount; the four you can see
## from across the world get a fraction of it.
##
## ## Faceted, but with the edges taken off
##
## There are two wrong answers here and the ground has been both of them.
##
## **Flat shaded**, which it was until 2026-08-02: every triangle its own plane
## and its own colour, on a perfectly regular lattice split corner to corner the
## same way every time. That is a mesh you can see through the render. You can
## count the triangles, the diagonals run in one direction across the whole
## region, and over twenty-five minutes of looking at it, it is tiring.
##
## **Fully smooth**, which was tried immediately afterwards and is worse: shade
## a coarse mesh off the height field alone and the land stops being made of
## anything. It reads as a wax blob. All of the craft goes out of it.
##
## What is here is the third thing. Every triangle still has its own normal, so
## the ground is still visibly built out of planes - but that normal is bent
## most of the way toward the smooth field normal before it is used, which takes
## the hard crease off every shared edge. You can see that the land is faceted.
## You cannot pick out where one facet stops and the next starts. See `SOFTEN`,
## which is the entire dial.
##
## Two smaller things hold it up:
##
## **The vertices wander.** Each is nudged off its lattice point by up to just
## under half a cell, from a hash of its own indices, so the same region is the
## same shape every time and no two facets are the same shape as each other.
##
## **The outline is not the grid's.** Every vertex past the shoreline is folded
## back onto it, which turns a rectangle with its corners hanging off into a
## closed, wandering coastline - see `EDGE`.
func mesh(nx := 50, nz := 32) -> ArrayMesh:
	var grid: Array[PackedVector3Array] = []
	for j in nz + 1:
		var row := PackedVector3Array()
		for i in nx + 1:
			row.append(_vertex(i, j, nx, nz))
		grid.append(row)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var a := grid[j][i]
			var b := grid[j][i + 1]
			var c := grid[j + 1][i + 1]
			var d := grid[j + 1][i]
			# Alternating diagonals, so the mesh does not crease along one
			# direction everywhere the ground is steep.
			if (i + j) % 2 == 0:
				_facet(st, a, b, c)
				_facet(st, a, c, d)
			else:
				_facet(st, a, b, d)
				_facet(st, b, c, d)
	return st.commit()


## How far each facet's normal is bent toward the shape of the land underneath
## it. Nought is flat shading and every edge is a crease; one is fully smooth
## and the ground is a blob. This is the whole look of the terrain in one
## number, and it wants to stay nearer the top than the bottom.
const SOFTEN := 0.72


## Which way the ground faces here, taken from the height field rather than from
## any triangle. Sampled a little way out on each side rather than at the point,
## so it describes the shape of the land rather than the exact spot, and the
## surface settles instead of rippling.
func normal(p: Vector3) -> Vector3:
	const STEP := 0.16
	var dx := height(p + Vector3(STEP, 0, 0)) - height(p - Vector3(STEP, 0, 0))
	var dz := height(p + Vector3(0, 0, STEP)) - height(p - Vector3(0, 0, STEP))
	return Vector3(-dx, 2.0 * STEP, -dz).normalized()


## One triangle of ground.
##
## The vertex order is what Godot culls on and it is easy to get backwards - an
## inverted grid renders as nothing but the far slopes, which reads as a
## lighting problem rather than a winding one. So the facet normal is taken from
## the geometry and then forced upward, because ground faces up and there is no
## case here where it does not.
##
## Each of the three vertices then gets that facet normal leaned toward the
## field normal at its own position. Same plane, three slightly different
## normals, so the shading turns gently across the triangle and meets its
## neighbours most of the way rather than butting against them.
func _facet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var face := (b - a).cross(c - a).normalized()
	if face.y < 0.0:
		face = -face

	for v in [a, b, c]:
		st.set_normal(face.lerp(normal(v), SOFTEN).normalized())
		# Colour per vertex rather than per facet. Per facet was the other half
		# of what made this tiring: at this triangle size, a random shift on
		# every one of them is salt and pepper, and it made the ground look
		# soiled rather than varied. The facets are read off the shading now,
		# which is a far quieter way to say the same thing.
		#
		# Converted, because vertex colours are consumed as linear while every
		# colour written down in this project is sRGB. Skipping this is not a
		# subtle error: it lifts mid-tones by about seventy per cent, so a
		# meadow renders as pale sage and a desert as bare white paper, and it
		# looks like a lighting problem rather than a colour space one.
		st.set_color(colour(v).srgb_to_linear())
		st.add_vertex(v)


func _vertex(i: int, j: int, nx: int, nz: int) -> Vector3:
	var cell_x := 2.0 * REACH_X / float(nx)
	var cell_z := 2.0 * REACH_Z / float(nz)

	var x := lerpf(-REACH_X, REACH_X, float(i) / float(nx))
	var z := lerpf(-REACH_Z, REACH_Z, float(j) / float(nz))
	x += (_hash(i, j, 0) - 0.5) * 2.0 * JITTER * cell_x
	z += (_hash(i, j, 1) - 0.5) * 2.0 * JITTER * cell_z

	# Fold everything past the shoreline back onto it. The wobble is a function
	# of the bearing alone, so scaling a point straight in toward the middle
	# lands it exactly on the edge in one step rather than converging on it.
	var a := atan2(z, x)
	var wobble := 1.0 + 0.10 * sin(a * 3.0 + 0.7) + 0.06 * sin(a * 5.0 + 2.1)
	var r := Vector2(x / (LAND_X * wobble), z / (LAND_Z * wobble)).length()
	if r > EDGE:
		x *= EDGE / r
		z *= EDGE / r

	return on(Vector3(x, 0.0, z))


## A stable number in nought to one from a pair of indices. Deterministic, so a
## region has the same coastline and the same facets every time it is looked at.
func _hash(i: int, j: int, salt: int) -> float:
	var h := (i * 73856093) ^ (j * 19349663) ^ ((salt + index * 7) * 83492791)
	return float(absi(h) % 65536) / 65536.0


## The ground's material: its own colours out of the mesh, its paths out of a
## texture.
##
## Everything except the paths is one colour per vertex, which is the cheapest
## possible way to draw a place. The paths cannot be, because they change while
## you are watching and baking them in would mean rebuilding twenty thousand
## vertices every few seconds to move a shade of brown. So they arrive as a
## small texture the shader mixes in - see `Wear` and `ground.gdshader`.
func material(wear: Wear) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/ground.gdshader")
	mat.set_shader_parameter("wear_map", wear.texture())
	mat.set_shader_parameter("earth", _b["earth"])
	mat.set_shader_parameter("half_extent", Vector2(REACH_X, REACH_Z))
	return mat


func _gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
