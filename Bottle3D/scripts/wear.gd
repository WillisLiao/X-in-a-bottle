class_name Wear
extends RefCounted

## Where they have walked.
##
## One number per patch of ground, going up and never down, and it is the
## closest thing this app has to a thesis statement made out of code: **the
## world physically records where the attention went.**
##
## Nothing else here shows you what you did. There is no session count, no
## streak, no graph, no total. There is a hillside with tracks worn across it
## that were not there on Monday, and if you spent Tuesday watching them fetch
## stone the track to the quarry is the deepest one. That is a record of
## attention that cannot be gamed, because the only way to make it is to have
## actually kept the region open and watched.
##
## ## It used to be a lie
##
## Until this existed, `Land` drew seven authored routes out from the site with
## a fixed width and baked them into the ground colour when the region was
## built. Every region had the same paths, at full strength, from the first
## second, including regions nobody had ever been to. It looked right in a
## screenshot and it meant nothing.
##
## ## It only goes one way
##
## Paths do not fade here. Real ones do, and it was tempting, and it is the
## wrong call because against a build that takes a week, anything that quietly
## undoes an evening teaches people not to open the app. What you did stays done.
##
## ## What it costs
##
## Six kilobytes a region, and one texture upload every half second while
## somebody is walking. The ground shader does the rest - see `ground.gdshader`.

## The grid, over the whole mesh extent of a region rather than just the land,
## so a path that runs down to the shoreline is not clipped at the edge.
##
## Ninety-six by sixty-four is a cell of about eighteen centimetres against a
## person a bit over half a metre tall, which is roughly a footstep. Finer than
## that and the texture is storing detail the linear filter throws away again on
## the way to the screen.
const COLS := 96
const ROWS := 64

## Nothing wears past this. A path that has had a thousand crossings should look
## like a path, not like a trench of bare rock through the middle of a meadow,
## and without a ceiling the whole yard eventually goes to earth.
const FULL := 1.0

## How far a single footfall spreads, in cells. A path is about three cells
## across, which is a little wider than one person - which is what a path is.
const SPREAD := 1

var _cells: PackedFloat32Array = PackedFloat32Array()
var _image: Image
var _texture: ImageTexture
var _dirty := false

## The byte form of `_cells`, kept rather than made fresh each time. Both the
## upload and the save want it, it is six thousand entries, and one of them
## happens twice a second for as long as the app is open.
##
## The cells themselves stay floats. A byte is a step of about a two-hundred-
## and-fiftieth, one crossing of a cell deposits about one and a half of those,
## and accumulating in bytes would therefore round away a third of every
## footstep - which over a week is most of the record.
var _bytes: PackedByteArray = PackedByteArray()


func _init() -> void:
	_cells.resize(COLS * ROWS)
	_bytes.resize(COLS * ROWS)
	_image = Image.create_empty(COLS, ROWS, false, Image.FORMAT_R8)
	_texture = ImageTexture.create_from_image(_image)


func texture() -> ImageTexture:
	return _texture


## One footfall. `amount` is how far they moved, so somebody who stops still
## does not grind a hole where they are standing, and somebody dragging a beam
## leaves more behind than somebody strolling.
func tread(p: Vector3, amount: float) -> void:
	if amount <= 0.0:
		return
	var cx := int(floor((p.x / Land.REACH_X * 0.5 + 0.5) * float(COLS)))
	var cy := int(floor((p.z / Land.REACH_Z * 0.5 + 0.5) * float(ROWS)))

	for dy in range(-SPREAD, SPREAD + 1):
		for dx in range(-SPREAD, SPREAD + 1):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or x >= COLS or y < 0 or y >= ROWS:
				continue
			# Centre of the stride takes most of it, the sides a third. Without
			# the falloff a path is one cell wide and reads as a drawn line.
			var falloff := 1.0 if dx == 0 and dy == 0 else 0.34
			var i := y * COLS + x
			var was := _cells[i]
			_cells[i] = minf(FULL, was + amount * falloff)
			if _cells[i] != was:
				_dirty = true


## How worn the ground is here, nought to one. Read by the things that need to
## keep off the paths rather than by the drawing, which reads the texture.
func at(p: Vector3) -> float:
	var x := int(floor((p.x / Land.REACH_X * 0.5 + 0.5) * float(COLS)))
	var y := int(floor((p.z / Land.REACH_Z * 0.5 + 0.5) * float(ROWS)))
	if x < 0 or x >= COLS or y < 0 or y >= ROWS:
		return 0.0
	return _cells[y * COLS + x]


## Pushes whatever has changed up to the GPU, and says whether there was
## anything. Called on a timer rather than per footfall: a dozen people walking
## would otherwise upload the same small texture a dozen times a frame to no
## visible end.
##
## The return is what tells the world it has something new worth saving. Walking
## is progress here, and a session spent watching them fetch stone has to
## survive being put down even if no work happened to finish in it.
func flush() -> bool:
	if not _dirty:
		return false
	_dirty = false
	_image.set_data(COLS, ROWS, false, Image.FORMAT_R8, _packed())
	_texture.update(_image)
	return true


func _packed() -> PackedByteArray:
	for i in _cells.size():
		_bytes[i] = int(clampf(_cells[i], 0.0, 1.0) * 255.0)
	return _bytes


# --- keeping it ---------------------------------------------------------------
#
# One byte a cell, base64'd, because a `PackedByteArray` in a `ConfigFile` is
# written out as six thousand comma-separated decimal numbers and this is a
# quarter of the size and unreadable either way.

func to_text() -> String:
	return Marshalls.raw_to_base64(_packed())


func from_text(text: String) -> void:
	if text.is_empty():
		return
	var bytes := Marshalls.base64_to_raw(text)
	# A save written at a different grid size is not worth migrating - it is a
	# week of footprints, not a week of building, and it comes back.
	if bytes.size() != COLS * ROWS:
		return
	for i in bytes.size():
		_cells[i] = float(bytes[i]) / 255.0
	_dirty = true
	flush()
