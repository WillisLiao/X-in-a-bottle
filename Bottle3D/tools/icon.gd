extends SceneTree

## The home screen mark, generated rather than drawn in an editor.
##
## Run it with:
##
##     /Applications/Godot.app/Contents/MacOS/Godot --headless \
##         --path Bottle3D --script tools/icon.gd
##
## It writes `icon.png` and every size under `icons/`, so the icon is a thing
## the repo can rebuild rather than a binary somebody has to remember how to
## remake. Nothing else in the project imports it at runtime.
##
## ## The mark
##
## A round door in a hillside, under a low sun.
##
## It is the one hobbit signifier that is not a character, which matters
## because a character on a home screen is a mascot and this app does not have
## one. It is also the same picture the app is actually about: a house being
## made in a hill by people you leave alone, seen from outside, closed.
##
## The construction is deliberately the picker's: a band of sky over a band of
## ground, both taken from the meadow's real palette, with one black mark
## standing on it. Godot draws the islands that way, the picker draws the chips
## that way, and now the home screen does too - one mark, three places.
##
## The doorknob is the single point of accent, dead centre of the door the way
## a real one is, and it is the only warm thing above the horizon. Same rule the
## picker follows: the ember gets used once or it stops meaning anything.

# Rendered at twice the delivered size and resampled down, which is cheaper
# than supersampling every pixel by hand and lands in the same place.
const RENDER := 2048
const SIZES := [1024, 180, 167, 152, 120, 87, 80, 76, 60, 58, 40]

## Dusk, in four stops rather than two.
##
## A straight lerp from navy to amber passes through the average of the two,
## which is a dead grey-brown, and the first version of this icon had a wide
## muddy band across its middle because of it. Going navy - violet - rose -
## amber keeps the saturation up the whole way down, which is also what the sky
## actually does.
const SKY := [
	[0.00, Color("1E2A46")],
	[0.52, Color("5E4A68")],
	[0.80, Color("C07A5E")],
	[1.00, Color("E8B478")],
]
const HILL := Color("3C4E33")
const HILL_LIP := Color("5E7449")
const LEAF := Color("C07A3C")
const PLANK := Color("9C5F2C")
const FRAME := Color("241A10")
const KNOB := Color("F2E7CF")
const STEP := Color("BBAE95")

# Everything in fractions of the icon's edge, so the composition is readable
# here rather than buried in pixel arithmetic.
const HORIZON := 0.50
const HILL_CX := 0.5
const HILL_CY := 1.66      ## Centre well below the frame: the top of a very
const HILL_R := 1.20       ## large circle is a hillside, not a mound.
const DOOR_CX := 0.5
const DOOR_CY := 0.685
const DOOR_R := 0.152
const FRAME_W := 0.018
const KNOB_R := 0.020


func _initialize() -> void:
	var img := Image.create(RENDER, RENDER, false, Image.FORMAT_RGB8)
	var n := float(RENDER)

	for py in RENDER:
		var v := (float(py) + 0.5) / n
		for px in RENDER:
			var u := (float(px) + 0.5) / n
			img.set_pixel(px, py, _sample(u, v))

	var here := "res://"
	_write(img, here + "icon.png", 1024)
	for s in SIZES:
		_write(img, "%sicons/icon_%d.png" % [here, s], s)

	print("icon: wrote icon.png and %d sizes under icons/" % SIZES.size())
	quit()


## One point of the picture, in 0-1 space. Edges are softened against the
## pixel's own width rather than with a fixed blur, so the same function is
## correct whatever RENDER is set to.
func _sample(u: float, v: float) -> Color:
	var px := 1.0 / float(RENDER)

	# Sky: a low sun, so most of the gradient's travel happens in the bottom
	# third of it rather than evenly across the whole band.
	var c: Color = _ramp(pow(clampf(v / HORIZON, 0.0, 1.0), 1.45))

	# The hill. A lip of the lighter ground colour along the crest, catching
	# the sun, which is the only modelling in the whole mark.
	var hill := _circle(u, v, HILL_CX, HILL_CY, HILL_R)
	c = c.lerp(HILL_LIP, _inside(hill, px * 1.5))
	c = c.lerp(HILL, _inside(hill + 0.030, px * 1.5))

	# A flagstone under the door, half swallowed by it. Without something
	# meeting the door along the bottom it floats in the hill rather than
	# standing on it.
	c = c.lerp(STEP, _inside(_capsule(u, v, DOOR_CX, DOOR_CY + DOOR_R * 1.02,
		DOOR_R * 0.80, DOOR_R * 0.085), px * 1.5))

	# The door. A dark frame, a warm leaf inside it, seams down the leaf, and
	# the knob dead centre where a hobbit's actually is.
	#
	# The first version had this the other way round - a black leaf inside a
	# cream ring with a dot in the middle - and it read as an eye long before
	# it read as a door. Light-inside-dark is what stops it.
	var door := _circle(u, v, DOOR_CX, DOOR_CY, DOOR_R)
	c = c.lerp(FRAME, _inside(door, px * 1.5))

	var leaf := _inside(door + FRAME_W, px * 1.5)
	var face := LEAF
	for seam in [-0.5, 0.5]:
		face = face.lerp(PLANK, _inside(
			absf(u - (DOOR_CX + seam * DOOR_R * 0.62)) - DOOR_R * 0.016,
			px * 1.5))
	c = c.lerp(face, leaf)

	c = c.lerp(KNOB, _inside(
		_circle(u, v, DOOR_CX, DOOR_CY, KNOB_R), px * 1.5))

	return c


## A multi-stop colour ramp, since Godot's Gradient wants a scene tree.
func _ramp(t: float) -> Color:
	for i in range(SKY.size() - 1):
		var a: Array = SKY[i]
		var b: Array = SKY[i + 1]
		if t <= float(b[0]):
			var span := maxf(float(b[0]) - float(a[0]), 1e-6)
			return (a[1] as Color).lerp(b[1] as Color,
				clampf((t - float(a[0])) / span, 0.0, 1.0))
	return SKY[SKY.size() - 1][1]


## Signed distance to a horizontal stadium - a rectangle with round ends.
func _capsule(u: float, v: float, cx: float, cy: float,
		half: float, r: float) -> float:
	var d := Vector2(maxf(absf(u - cx) - half, 0.0), v - cy)
	return d.length() - r


## Signed distance to a circle: negative inside, positive out.
func _circle(u: float, v: float, cx: float, cy: float, r: float) -> float:
	return Vector2(u - cx, v - cy).length() - r


## Coverage for a signed distance, feathered across one pixel.
func _inside(d: float, feather: float) -> float:
	return clampf(0.5 - d / feather, 0.0, 1.0)


func _write(source: Image, path: String, size: int) -> void:
	var img := Image.create_from_data(source.get_width(), source.get_height(),
		false, source.get_format(), source.get_data())
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	# App Store icons must not carry alpha, and neither should the rest -
	# iOS masks them itself and a transparent corner shows through as black.
	img.convert(Image.FORMAT_RGB8)
	img.save_png(ProjectSettings.globalize_path(path))
