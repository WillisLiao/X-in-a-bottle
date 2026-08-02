class_name CommunityRoads
extends Node3D

## The map's visible proof that movement has become part of the world.
##
## Roads are held above the far terrain and only appear at map distance.
## A real close-up road needs terrain projection and local art direction, which
## is a later job. Drawing this first as a close-view prop would be a false
## promise that every future route automatically belongs on every hill.

const MAP_FROM := 0.30
const ROAD_TONE := Color("75401F")
const CLAIMED_TONE := Color("D8B16A")
const RUMOR_TONE := Color(1.55, 0.82, 0.30)
const ROAD_EMBER := Color(1.20, 0.46, 0.10)
const HIT_RADIUS := 132.0

var _book: RouteBook
var _active := Region.HOME
var _map := 0.0
var _unclaimed_positions: Array[Vector3] = []


func _init(book: RouteBook, active: int) -> void:
	_book = book
	_active = active
	_build()
	set_map(0.0)


func set_map(amount: float) -> void:
	_map = clampf(amount, 0.0, 1.0)
	visible = _map >= MAP_FROM


func claim_at(screen_at: Vector2, camera: Camera3D) -> bool:
	if _map < MAP_FROM or camera == null:
		return false
	var nearest := ""
	# Captures and high-density iPhones use physical pixels here, so 132 gives a
	# full forty-four-point target at three-times scale. The marker is delicate;
	# its hit area must not be.
	var distance := HIT_RADIUS
	for site in _book.sites():
		if bool(site["claimed"]):
			continue
		var at := _at(site["at"])
		if camera.is_position_behind(at):
			continue
		var hit := camera.unproject_position(at).distance_to(screen_at)
		if hit < distance:
			distance = hit
			nearest = String(site["id"])
	if nearest.is_empty():
		return false
	if not _book.claim_site(nearest):
		return false
	# A map controller owns this player action, so it is the right place to
	# commit it. Keeping RouteBook mutation pure lets simulations test a claim
	# without accidentally writing their synthetic route into a real save.
	_book.persist()
	return true


func rumor_positions() -> Array:
	return _unclaimed_positions


func _build() -> void:
	var beds := SurfaceTool.new()
	var embers := SurfaceTool.new()
	beds.begin(Mesh.PRIMITIVE_TRIANGLES)
	embers.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_roads := false
	for edge in _book.segments():
		var from := _at(edge["a"])
		var to := _at(edge["b"])
		var centre := (from + to) * 0.5
		# The crown keeps a long chain from reading as a laser line on the map.
		centre.y += 0.12
		var spine := PackedVector3Array([from, centre, to])
		Geometry.append_tube(beds, spine, 0.24, 0.24, 5, false)

		# The earth-coloured bed says road in daylight. The ember seam is what
		# lets a route still read after dusk, when a player is most likely to
		# inspect a map after walking home. A bright solid tube was tried first
		# and read as a laser, so only its centre emits.
		Geometry.append_tube(embers, spine, 0.065, 0.065, 5, false)
		has_roads = true

	if has_roads:
		# One bed and one ember mesh keep a dense future neighborhood at two draw
		# calls, instead of creating one Node3D pair for every crossed cell.
		var road := MeshInstance3D.new()
		beds.generate_normals()
		road.mesh = beds.commit()
		road.material_override = World.solid_material(ROAD_TONE, 0.94)
		road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(road)

		var ember := MeshInstance3D.new()
		embers.generate_normals()
		ember.mesh = embers.commit()
		ember.material_override = World.glow_material(ROAD_EMBER, 0.72)
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ember)

	for site in _book.sites():
		_build_site(site)


func _build_site(site: Dictionary) -> void:
	var root := Node3D.new()
	root.position = _at(site["at"])
	root.set_meta("site_id", site["id"])

	var stone := MeshInstance3D.new()
	stone.mesh = Geometry.crystal(0.32, 0.18)
	stone.material_override = World.solid_material(
		CLAIMED_TONE if bool(site["claimed"]) else ROAD_TONE, 0.72)
	stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stone)

	if not bool(site["claimed"]):
		var ember := MeshInstance3D.new()
		var globe := SphereMesh.new()
		globe.radius = 0.16
		globe.height = 0.32
		globe.radial_segments = 7
		globe.rings = 4
		ember.mesh = globe
		ember.position.y = 0.38
		ember.material_override = World.glow_material(RUMOR_TONE, 0.88)
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ember)

	if not bool(site["claimed"]):
		_unclaimed_positions.append(root.position + Vector3(0.0, 0.42, 0.0))
	add_child(root)


func _at(global_at: Vector2) -> Vector3:
	var relative := global_at - Vector2(Region.origin(_active).x,
		Region.origin(_active).z)
	return Vector3(relative.x, 0.58, relative.y)
