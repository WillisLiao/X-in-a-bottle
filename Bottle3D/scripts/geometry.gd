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

	st.generate_normals()
	return st.commit()


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
