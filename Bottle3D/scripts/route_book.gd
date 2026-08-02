class_name RouteBook
extends RefCounted

## The local record of how a neighborhood becomes a world.
##
## This stores crossings between coarse fantasy cells, not the phone's raw
## locations. The distinction is permanent: a future location service can turn
## a validated visit into these cells, while the renderer and the save stay
## ignorant of where a person actually lives.

## Four metres is broad enough that a noisy location fix does not scribble over
## the map, while still producing a street that turns with a real route rather
## than a line drawn from one suburb to another.
const CELL_SIZE := 4.0
const EDGE_WORDS := 5
const SITE_WORDS := 2

var _edges := {}
var _sites := {}
var _claimed := {}


static func load() -> RouteBook:
	var book := RouteBook.new()
	book.deserialize(Progress.community_roads())
	book.deserialize_sites(Progress.community_sites())
	book.deserialize_claims(Progress.claimed_rumors())
	return book


func persist() -> void:
	Progress.set_community_roads(serialize())
	Progress.set_community_sites(serialize_sites())
	Progress.set_claimed_rumors(serialize_claims())
	# A rumor claim is a discrete player action, not simulation state that can
	# wait for the next world autosave. Losing it to a phone call would make the
	# first real location interaction feel fake.
	Progress.flush()


## Adds one walk after its source has already removed the person's real-world
## coordinates. The source can be the temporary capture hook today or a native
## consented location bridge tomorrow. This object must not care which one it
## was, or it will become the wrong boundary when shared roads arrive.
func record(world_points: PackedVector2Array) -> int:
	var route: Array[Vector2i] = []
	for point in world_points:
		var cell := cell_at(point)
		if route.is_empty() or route.back() != cell:
			route.append(cell)
	if route.size() < 2:
		return 0

	var added := 0
	for i in route.size() - 1:
		var stepped := _line(route[i], route[i + 1])
		for j in stepped.size() - 1:
			_add_edge(stepped[j], stepped[j + 1])
			added += 1

	# A site is the middle of a remembered journey, not an arbitrary map marker.
	# Later it can grow a locally seeded story because this exact cell is stable
	# across restarts and across a server replacing the capture hook.
	var middle := route[route.size() / 2]
	var id := _site_id(middle)
	if not _sites.has(id):
		_sites[id] = middle
	return added


## The only source wired into the first slice. It is capture-only on purpose:
## pretending Godot has a location service would hide the native privacy and
## anti-spoofing work that still needs its own implementation.
func record_debug_route(name: String) -> bool:
	var from := Region.origin(Region.HOME)
	var to: Vector3
	match name:
		"meadow-shore":
			to = Region.origin(3)
		"meadow-green":
			to = Region.origin(4)
		_:
			return false

	var across := from.lerp(to, 0.50)
	var side := Vector3(-(to.z - from.z), 0.0, to.x - from.x).normalized()
	# The bend is only a fraction of a cell at either end, but it prevents the
	# first road from reading like a debug ruler laid across the world.
	across += side * 4.0
	return record(PackedVector2Array([
		Vector2(from.x, from.z), Vector2(across.x, across.z), Vector2(to.x, to.z),
	])) > 0


func segments() -> Array:
	var out: Array = []
	var keys := _edges.keys()
	keys.sort()
	for key in keys:
		var edge: Dictionary = _edges[key]
		out.append({
			"a": cell_centre(edge["a"]),
			"b": cell_centre(edge["b"]),
			"crossings": int(edge["crossings"]),
		})
	return out


func sites() -> Array:
	var out: Array = []
	var ids := _sites.keys()
	ids.sort()
	for id in ids:
		var cell: Vector2i = _sites[id]
		out.append({
			"id": String(id),
			"at": cell_centre(cell),
			"claimed": _claimed.has(id),
		})
	return out


func claim_site(id: String) -> bool:
	if not _sites.has(id) or _claimed.has(id):
		return false
	_claimed[id] = true
	return true


func clear() -> void:
	_edges.clear()
	_sites.clear()
	_claimed.clear()


func serialize() -> PackedInt32Array:
	var words := PackedInt32Array()
	var keys := _edges.keys()
	keys.sort()
	for key in keys:
		var edge: Dictionary = _edges[key]
		var a: Vector2i = edge["a"]
		var b: Vector2i = edge["b"]
		words.append_array(PackedInt32Array([a.x, a.y, b.x, b.y,
			int(edge["crossings"])]))
	return words


func deserialize(words: PackedInt32Array) -> void:
	_edges.clear()
	if words.size() % EDGE_WORDS != 0:
		return
	for i in range(0, words.size(), EDGE_WORDS):
		var a := Vector2i(words[i], words[i + 1])
		var b := Vector2i(words[i + 2], words[i + 3])
		var crossings := maxi(words[i + 4], 1)
		_edges[_edge_id(a, b)] = {"a": a, "b": b, "crossings": crossings}


func serialize_sites() -> PackedInt32Array:
	var words := PackedInt32Array()
	var ids := _sites.keys()
	ids.sort()
	for id in ids:
		var cell: Vector2i = _sites[id]
		words.append_array(PackedInt32Array([cell.x, cell.y]))
	return words


func deserialize_sites(words: PackedInt32Array) -> void:
	_sites.clear()
	if words.size() % SITE_WORDS != 0:
		return
	for i in range(0, words.size(), SITE_WORDS):
		var cell := Vector2i(words[i], words[i + 1])
		_sites[_site_id(cell)] = cell


func serialize_claims() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in _claimed.keys():
		ids.append(String(id))
	ids.sort()
	return ids


func deserialize_claims(ids: PackedStringArray) -> void:
	_claimed.clear()
	for id in ids:
		_claimed[id] = true


static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))


static func cell_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func _add_edge(a: Vector2i, b: Vector2i) -> void:
	if a == b:
		return
	var id := _edge_id(a, b)
	if not _edges.has(id):
		_edges[id] = {"a": a, "b": b, "crossings": 0}
	var edge: Dictionary = _edges[id]
	edge["crossings"] = int(edge["crossings"]) + 1
	_edges[id] = edge


static func _line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	var x := from.x
	var y := from.y
	var dx := absi(to.x - from.x)
	var sx := 1 if from.x < to.x else -1
	var dy := -absi(to.y - from.y)
	var sy := 1 if from.y < to.y else -1
	var err := dx + dy
	while true:
		points.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var twice := err * 2
		if twice >= dy:
			err += dy
			x += sx
		if twice <= dx:
			err += dx
			y += sy
	return points


static func _edge_id(a: Vector2i, b: Vector2i) -> String:
	var first := a
	var second := b
	if b.x < a.x or (b.x == a.x and b.y < a.y):
		first = b
		second = a
	return "%d,%d:%d,%d" % [first.x, first.y, second.x, second.y]


static func _site_id(cell: Vector2i) -> String:
	return "site:%d,%d" % [cell.x, cell.y]
