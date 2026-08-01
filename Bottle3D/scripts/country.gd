class_name Country
extends Node3D

## The four regions you are not standing in.
##
## Everything here is scenery. There are no elves in it, no queue, no heaps and
## no tick - the rule that only what is being watched moves is not softened by
## the world getting bigger, it is what makes a bigger world affordable. A
## region you are not in is a coloured shape on the horizon and it stays one
## until somebody walks there.
##
## ## Why this is not five `ElfWorld`s
##
## Because four of them would be simulating nothing at forty thousand triangles
## each, on a phone that has to stay cool for twenty-five minutes. An `ElfWorld`
## is a place with people in it. This is the land, at the resolution the land is
## worth at forty metres, and nothing else.
##
## ## What the far regions tell you
##
## Three things, none of them written down anywhere on screen:
##
## **Which climate is which**, from the ground colour alone. The five palettes
## were tuned to be different places rather than one place recoloured, and that
## work pays off twice now - it was carrying an island, and it is carrying a map.
##
## **Where you have been**, from the tracks. They are recorded rather than
## drawn - see `Wear` - so a region somebody has spent a week in is crossed with
## paths and one nobody has been to has bare ground, and the difference is
## legible from across the world without a pin, a label or a progress ring.
##
## **How far it is**, because the distance on screen is the distance a hobbit
## would have to walk. Nothing here is a diagram of the world; it is the world,
## seen from further away.

## The grid a far region's land is built on, against the full amount the region
## being lived in gets. Coarser, but not by as much as it looks: the shading is
## smooth now, so what these triangles are still buying is the coastline, and a
## region's outline is most of what tells you which one it is from across a
## world.
const FAR_NX := 26
const FAR_NZ := 18

## Rough cover, so a far region is not a bare shape. Not the real clutter -
## that is blades of grass a centimetre high and none of it survives being
## looked at from forty metres. These are the canopy masses only, which is all
## that is left of a wooded island at that distance anyway.
const CANOPY_CLUMPS := 52

var _active := -1
var _built := {}


## Redraws for a new active region. Everything is positioned relative to
## whichever region is being lived in - see `Region.offset` - so travelling
## moves the scenery rather than the camera.
func show_from(active: int) -> void:
	if _active == active and not _built.is_empty():
		return
	_active = active

	for child in get_children():
		child.queue_free()
	_built.clear()

	for i in Biome.COUNT:
		if i == active:
			continue
		var node := _far_region(i)
		node.position = Region.offset(i, active)
		add_child(node)
		_built[i] = node

	# The necks, including the two that join the region being lived in - that
	# land belongs between the regions rather than to either of them, so it is
	# built here whichever end you are standing at.
	for pair in Region.links():
		add_child(Causeway.between(pair.x, pair.y, active))


## Where a region's centre is right now, in the coordinates everything else in
## the scene is using. The active region answers with the origin, because that
## is where it is.
func where(index: int) -> Vector3:
	return Region.offset(index, _active)


func _far_region(index: int) -> Node3D:
	var root := Node3D.new()
	var land := Land.new(index)

	# The paths as they were left. Nothing wears here - nobody is walking - but
	# a region somebody has lived in for a week is criss-crossed with tracks and
	# one nobody has ever been to has none, and from across the world that is
	# the whole difference between the two. It is the map's only marker and it
	# is not a marker: it is the ground.
	var wear := Wear.new()
	wear.from_text(String(Progress.read(index)["wear"]))

	var ground := MeshInstance3D.new()
	ground.mesh = land.mesh(FAR_NX, FAR_NZ)
	ground.material_override = land.material(wear)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)

	_scatter_canopy(root, land, wear, index)
	return root


## The woods, as lumps.
##
## Placed by the same rule the real trees are - away from the middle of the
## region, off the shoreline, denser where the biome says there is cover - so
## the mass sits where the mass would sit. On the Ice that is almost nothing,
## which is correct and is the whole reason the Ice needs the Green.
func _scatter_canopy(root: Node3D, land: Land, wear: Wear, index: int) -> void:
	var b := Biome.of(index)
	var density: float = b["cover"]
	if density <= 0.01:
		return

	var rng := RandomNumberGenerator.new()
	# Fixed per region, so the far view of a place is the same shape every time
	# it is looked at. A wood that rearranges itself when you glance away is the
	# fastest possible way to make a world feel like a screensaver.
	rng.seed = 0x5EA + index

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planted := 0

	for _try in CANOPY_CLUMPS * 4:
		if planted >= int(float(CANOPY_CLUMPS) * density):
			break
		var at := Vector3(
			rng.randf_range(-Land.LAND_X, Land.LAND_X) * 0.94, 0.0,
			rng.randf_range(-Land.LAND_Z, Land.LAND_Z) * 0.94)
		# Not in the sea, not in the yard, and not across the paths.
		if land.height(at) < 0.0:
			continue
		if Vector2(at.x, at.z).distance_to(Vector2(0.3, -0.5)) < 2.6:
			continue
		if wear.at(at) > 0.30:
			continue

		# Taller than they are wide. Squashed the other way they read as
		# boulders, which on the Ice is a genuinely confusing thing for a stand
		# of stunted conifers to look like.
		var size := rng.randf_range(0.34, 0.62)
		st.append_from(Geometry.crystal(size, 0.30), 0, Transform3D(
			Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, 1.5, 1.0)),
			land.on(at) + Vector3(0, size * 0.70, 0)))
		planted += 1

	if planted == 0:
		return

	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = World.solid_material(b["canopy"], 1.0)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)
