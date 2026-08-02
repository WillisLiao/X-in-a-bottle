class_name Geometry
extends RefCounted

## Mesh building shared by the environments.
##
## Bolts and branches are both swept tubes, so the sweep lives here rather than
## being written twice and drifting apart.

## Sweeps a ring along a polyline.
##
## The frame is carried from segment to segment rather than rebuilt from a fixed
## up-vector, or the tube twists wherever the path doubles back on itself.
##
## `taper_ends` rounds a bolt off to a point at both ends. A branch wants a flat
## base where it meets its parent, so it passes false.
static func tube(points: PackedVector3Array,
                 radius_start: float,
                 radius_end: float,
                 sides: int = 6,
                 taper_ends: bool = true) -> ArrayMesh:
	if points.size() < 2:
		return ArrayMesh.new()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	append_tube(st, points, radius_start, radius_end, sides, taper_ends)
	st.generate_normals()
	return st.commit()


## Appends a swept tube to an already-open triangle surface.
## `CommunityRoads` needs one surface for a whole neighborhood. Appending the
## completed meshes with `SurfaceTool.append_from` looked like the right cheap
## shortcut, but produced detached segments on the Mobile renderer. Keeping the
## vertices in this source surface preserves the batching without asking Godot
## to remap a sequence of generated mesh surfaces.
static func append_tube(st: SurfaceTool,
		points: PackedVector3Array,
		radius_start: float,
		radius_end: float,
		sides: int = 6,
		taper_ends: bool = true) -> void:
	if points.size() < 2:
		return

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

		normal = normal - tangent * normal.dot(tangent)
		if normal.length() < 0.001:
			normal = tangent.cross(Vector3.RIGHT)
			if normal.length() < 0.001:
				normal = tangent.cross(Vector3.UP)
		normal = normal.normalized()
		var binormal := tangent.cross(normal)

		var t := float(i) / float(points.size() - 1)
		var radius: float = lerpf(radius_start, radius_end, t)
		if taper_ends:
			radius *= 0.25 + 0.75 * sin(t * PI)

		var ring := PackedVector3Array()
		for s in sides:
			var a := TAU * float(s) / float(sides)
			ring.append(points[i] + (normal * cos(a) + binormal * sin(a)) * radius)
		rings.append(ring)

	for i in rings.size() - 1:
		for s in sides:
			var n := (s + 1) % sides
			st.add_vertex(rings[i][s])
			st.add_vertex(rings[i][n])
			st.add_vertex(rings[i + 1][n])
			st.add_vertex(rings[i][s])
			st.add_vertex(rings[i + 1][n])
			st.add_vertex(rings[i + 1][s])


## Midpoint displacement in three dimensions. Used for bolts, and for the wander
## in a branch so it is never a straight stick.
##
## The offset decays slower than the textbook halving, which keeps the
## high-frequency kinks. At 0.5 the result smooths into a bent wire.
static func jagged(from: Vector3, to: Vector3, offset: float,
                   passes: int = 3) -> PackedVector3Array:
	var points := PackedVector3Array([from, to])

	for _pass in passes:
		var next := PackedVector3Array([points[0]])
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			next.append((a + b) * 0.5 + Vector3(
				randf_range(-offset, offset),
				randf_range(-offset, offset),
				randf_range(-offset, offset)))
			next.append(b)
		points = next
		offset *= 0.62

	return points


## A faceted crystal.
##
## An icosahedron with each vertex pushed in or out at random, and face normals
## set per triangle rather than averaged. The flat shading is the whole point:
## smooth normals make any of this read as a pebble, and it is the hard facets
## catching light at different angles that say ice.
static func crystal(radius: float, jitter: float) -> ArrayMesh:
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var v := [
		Vector3(-1, phi, 0), Vector3(1, phi, 0),
		Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi),
		Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1),
		Vector3(-phi, 0, -1), Vector3(-phi, 0, 1),
	]

	# Squashed on one axis as well as jittered, so a drift of these is a heap of
	# different shards rather than the same rock twelve times.
	var squash := Vector3(randf_range(0.7, 1.3), randf_range(0.6, 1.2),
	                      randf_range(0.7, 1.3))

	for i in v.size():
		v[i] = v[i].normalized() * radius * (1.0 + randf_range(-jitter, jitter))
		v[i] *= squash

	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = v[f[0]]
		var b: Vector3 = v[f[1]]
		var c: Vector3 = v[f[2]]
		st.set_normal((b - a).cross(c - a).normalized())
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)

	return st.commit()
