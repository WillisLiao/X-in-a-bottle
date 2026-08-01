class_name Causeway
extends RefCounted

## The necks of land that join one region to the next.
##
## These exist for two reasons and the second one is the important one.
##
## **A lantern cannot be carried across open haze.** Expansion in this world is
## somebody walking a light to the next region and lighting a second hearth
## there - see `DESIGN-one-world.md` - and that assumes the walk is possible.
## Five plates floating apart with nothing between them is not a world you can
## spread across. It is five islands you can be teleported between, which is the
## exact thing the whole direction replaced.
##
## **And five plates floating apart is a picture of five islands.** The map read
## as the old design even though the code underneath it was the new one. A chain
## of headlands joined by low ground reads as one place at a glance, which is
## what "one world spreading along a coast" is supposed to look like and what
## the map has to sell in about eight seconds with no voiceover.
##
## ## What they are not
##
## Not bridges. Nothing here is built, nothing is a structure, and there is no
## deck, no rail and no piling. They are ground - a saddle of bare rock and sand
## sagging between two shores, the way a spit joins a headland to an island at
## low water. The app has refused every opportunity to draw architecture it did
## not have to draw and this is not the place to start.
##
## They are also not walkways in the sense of being flat. A dead level ribbon
## reads as a plank across a gap. These dip in the middle, crown across their
## width, and fall away at the sides exactly as the shoreline does.
##
## ## The colour is the point
##
## A neck runs from one climate's shore to the next one's, and it is coloured by
## interpolating between them. So the join from the Green to the Ice goes from
## wet dark earth to grey shingle over its length, and the join from the Shore
## to the Dunes bleaches out as it goes. The world grades into itself rather
## than being five swatches, and it costs one lerp.

## How far the middle of a neck sags below the shores it joins. Enough to read
## as a saddle rather than a ramp, not so far that it reads as a slung cable -
## which is exactly what the first attempt looked like.
const SAG := 0.40

## Half-width where it meets the land, and at the narrowest point in the middle.
## Wide at the ends so it merges into the shore instead of butting against it.
##
## The first attempt was less than half this and it was the whole problem: at
## three units across against a thirty unit gap and regions seventeen wide, a
## neck was two pixels on the map and read as a wire strung between two plates.
## Land that joins two places has to look like land you could walk five abreast
## on, because the point of it is that somebody is going to walk it.
const WIDE := 2.2
const NARROW := 1.3

## How much the middle bows sideways off the straight line between the two
## shores. A ruled line between two organic shapes is the one thing that would
## give away that this was generated.
const BOW := 2.6

## How far each end is buried in the region it leaves.
const BED := 1.4

## Along and across. Along is generous because the thing is thirty units long
## and its silhouette against the haze is most of what is seen of it.
const SEGMENTS := 44
const RIBS := 7


## The neck between two regions, in the coordinates everything else is using -
## which is to say offset for whichever region is currently being lived in.
static func between(a: int, b: int, active: int) -> MeshInstance3D:
	var land_a := Land.new(a)
	var land_b := Land.new(b)
	var from := Region.offset(a, active)
	var to := Region.offset(b, active)

	var toward := (to - from).normalized()
	# Each end pulled back into the land it leaves, so the neck beds into the
	# shore instead of butting up against it and leaving a seam.
	var start := from + _shore(land_a, toward) - toward * BED
	var end := to + _shore(land_b, -toward) + toward * BED

	var run := end - start
	var along := run.normalized()
	var side := Vector3(-along.z, 0.0, along.x)
	# Bowed one way or the other depending on the pair, so a chain of them
	# wanders rather than zigzagging in step.
	var bow := BOW * (1.0 if (a + b) % 2 == 0 else -1.0)

	var shore_a: Color = Biome.of(a)["shore"]
	var shore_b: Color = Biome.of(b)["shore"]
	var earth_a: Color = Biome.of(a)["earth"]
	var earth_b: Color = Biome.of(b)["earth"]

	var grid: Array[PackedVector3Array] = []
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var arch := sin(t * PI)

		var spine := start + run * t + side * (bow * arch)
		# Sagged in the middle, and never dead level along its length. A neck
		# with a single smooth curve in it reads as something that was extruded.
		spine.y = lerpf(start.y, end.y, t) - SAG * arch \
			+ arch * (0.16 * sin(t * 7.3 + float(a) * 2.0) + 0.10 * sin(t * 13.1))
		var half := lerpf(WIDE, NARROW, arch)

		var rib := PackedVector3Array()
		for j in RIBS:
			# Carried a quarter past the edge on each side, which is where the
			# flank falls away - the same trick the island shoreline uses.
			var u := lerpf(-1.25, 1.25, float(j) / float(RIBS - 1))
			var inside := clampf(absf(u), 0.0, 1.0)
			var p := spine + side * (u * half)
			# Crowned across, then dropped off the edge.
			p.y = spine.y + 0.16 * half * (1.0 - inside * inside) \
				- maxf(0.0, absf(u) - 1.0) * 3.4
			rib.append(p)
		grid.append(rib)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var t := (float(i) + 0.5) / float(SEGMENTS)
		# Weighted toward earth rather than beach, and knocked back a little.
		# Straight shore colour came out brighter than the shores it joins, so
		# the necks were the lightest thing in the frame and pulled the eye off
		# the place the user is actually watching.
		var tone := shore_a.lerp(shore_b, t).lerp(earth_a.lerp(earth_b, t), 0.58) \
			.darkened(0.10)
		for j in RIBS - 1:
			var p0 := grid[i][j]
			var p1 := grid[i][j + 1]
			var p2 := grid[i + 1][j + 1]
			var p3 := grid[i + 1][j]
			# Wound the opposite way round from how it reads, and this cost an
			# hour. Godot's front face is the one whose edge cross product points
			# *away* from the viewer, so ground seen from above wants
			# `cross(e1, e2)` pointing down. Going round the quad the natural way
			# here - across the width first, then along the run - produces the
			# other sign from the way `Land` goes round its grid, and the necks
			# rendered as nothing at all: not dark, not misshapen, absent. Which
			# looks exactly like a mesh that was never built, and sent the search
            # to the vertices, the AABB, the material and the node before it got
			# to the winding.
			_facet(st, p0, p2, p1, tone)
			_facet(st, p0, p3, p2, tone)

	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = Land.plain_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Where a neck leaves a region: the last point along a bearing that is still
## properly dry land.
##
## Marched rather than solved, because the coastline is a wobble function of the
## bearing and the height field has relief on top of it, and forty cheap samples
## once per region pair is not worth an inverse for.
static func _shore(land: Land, toward: Vector3) -> Vector3:
	var out := Vector3.ZERO
	for i in 48:
		var p := toward * (float(i) / 47.0 * (Land.REACH_X + 1.0))
		if land.height(p) < -0.12:
			break
		out = p
	out.y = land.height(out)
	return out


## Faceted the same way the land is - the facet's own normal bent most of the
## way toward flat, so the surface is visibly made of planes without any edge
## between two of them showing. Anything else here and the necks would read as a
## different material from the ground they join.
static func _facet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		tone: Color) -> void:
	var face := (b - a).cross(c - a).normalized()
	if face.y < 0.0:
		face = -face
	var soft := face.lerp(Vector3.UP, Land.SOFTEN).normalized()

	for v in [a, b, c]:
		st.set_normal(soft)
		var drift := 0.02 * sin(v.x * 2.3 - v.z * 1.7)
		st.set_color(Color(tone.r + drift, tone.g + drift,
			tone.b + drift).srgb_to_linear())
		st.add_vertex(v)
