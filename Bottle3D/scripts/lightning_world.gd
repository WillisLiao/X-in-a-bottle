class_name LightningWorld
extends World

## Lightning in a Bottle. The one it opens on.
##
## Bolts are caught and kept, suspended and breathing. A disturbance shakes some
## loose.

## The volume bolts are placed in, in metres, centred on the origin. Wide and
## shallow, because the screen is now wide and shallow.
const EXTENT := Vector3(2.10, 0.95, 0.80)

var _bolts: Array[Bolt] = []
var _energy: float = 1.0


func _init() -> void:
	title = "Lightning in a Bottle"
	capacity = 9
	spawn_seconds = 1.4


func held() -> int:
	return _bolts.size()


func _tick(delta: float, _population: int, disturbed: bool) -> void:
	# Everything goes cold while the phone is handled, so the cost is visible in
	# the instant it happens rather than only later as fewer bolts.
	var want := 0.25 if disturbed else 1.0
	_energy = lerpf(_energy, want, clampf(delta * 5.0, 0.0, 1.0))
	for bolt in _bolts:
		bolt.set_energy(_energy)


func _grow() -> bool:
	if _bolts.size() >= capacity:
		return false

	var bolt := Bolt.new()
	bolt.build(_fork(), randf() * TAU, Palette.gas())
	bolt.set_energy(_energy)
	add_child(bolt)
	_bolts.append(bolt)
	return true


func _shrink() -> void:
	var leaving := int(ceil(float(_bolts.size()) * LOSS_FRACTION))
	for _i in leaving:
		if _bolts.size() <= 1:
			return
		var index := randi() % _bolts.size()
		_bolts[index].queue_free()
		_bolts.remove_at(index)


## A bolt hanging in the volume rather than falling through it.
##
## Placed with intent rather than uniformly: scattering evenly fills the frame
## corner to corner and leaves nowhere for the eye to rest. Clustering off a
## focal point and leaving the lower volume open is what makes it a composition.
func _fork() -> PackedVector3Array:
	var focus := Vector3(0.0, 0.16, 0.0)
	var start := Vector3(
		clampf(focus.x + randfn(0.0, 1.05), -EXTENT.x, EXTENT.x),
		clampf(focus.y + randfn(0.0, 0.46), -EXTENT.y, EXTENT.y),
		clampf(focus.z + randfn(0.0, 0.44), -EXTENT.z, EXTENT.z))

	var direction := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, -0.25),
		randf_range(-1.0, 1.0)).normalized()

	# A few long filaments carrying the composition, more short ones around
	# them. Uniform lengths read as a pile of identical objects.
	var length := randf_range(1.3, 2.0) if randf() < 0.3 else randf_range(0.45, 1.0)
	return Geometry.jagged(start, start + direction * length, 0.20, 3)
