class_name Menu
extends CanvasLayer

## The way in.
##
## Two screens, and between them they have four words of copy and one control.
## This is a focus app, so the menu's job is to be got through and not to be
## enjoyed, and anything here that invites a second look is working against the
## product.
##
## ## What it is not
##
## It is not a game's level select. There are no thumbnails, no stars, no
## percentages, no locked islands, no "recommended next". A percentage in
## particular would be the single most damaging thing that could be put on this
## screen: the moment progress is a number, somebody optimises it, and the only
## way to optimise anything here is to leave the phone alone longer than you
## meant to.
##
## ## The plots
##
## Each island is one flat chip of its own ground - the real terrain colours the
## world is built from, not an illustration of them - with a black house standing
## on it that is exactly as tall as the house actually is. Five of those side by
## side tell you, at a glance and without a word, which places you have been
## working and how far each one got. Identity and progress are the same mark,
## which is one mark rather than two.
##
## Underneath, the phase, in the language of a building site rather than a game:
## Footings, Storey 2, Services, Lining. It is the only progress language in the
## app, and it says what is happening rather than how much is left.

signal begin
signal chose(island: int)
signal dismissed

enum Screen { TITLE, PICKER, NONE }

## The layout is in viewport units, and the viewport is 2622 x 1206. About three
## units to the point, so a 44pt touch target is 132 and body text is around 46.
const MARGIN := 250.0
const PLOT_W := 372.0
const PLOT_GAP := 60.0
const CHIP_H := 248.0

const INK := Color("EFE3CB")
const VOID := Color("0B0906")
const EMBER := Color("FF9A4A")

var _screen: Screen = Screen.NONE
var _title_root: Control
var _picker_root: Control
var _plots: Array = []
var _action: Label
var _hint: Label


## One island, drawn as a chip of its own ground with its own house on it.
class Plot:
	extends Control

	var index := 0
	var tint := {}
	var progress := 0.0
	var lit := false

	func _draw() -> void:
		var w := size.x
		var h := Menu.CHIP_H
		var horizon := h * 0.52

		# Sky first, then land. Both taken from the palette the world is actually
		# built out of - the haze colour above and the ground colour below - so
		# the chip and the place agree without anybody having to keep them in
		# step, and a glance across the five reads as five climates.
		draw_rect(Rect2(0, 0, w, horizon), Color(tint["fog"]).lightened(0.26))
		draw_rect(Rect2(0, horizon, w, h - horizon), tint["ground_lit"])
		draw_rect(Rect2(0, h - (h - horizon) * 0.30, w, (h - horizon) * 0.30),
			Color(tint["ground"]).darkened(0.06))
		draw_line(Vector2(0, horizon), Vector2(w, horizon),
			Color(tint["shore"], 0.75), 2.0)

		_draw_plot(w, horizon + 44.0)

		# A hairline, and nothing else. The island you were last on is the only
		# thing on this screen allowed to use the accent.
		draw_rect(Rect2(0, 0, w, h), Menu.EMBER if lit else Color(Menu.INK, 0.20),
			false, 2.0)

	## The house, at the stage the house is actually at.
	##
	## Not a bar and not a percentage. Staked ground, then a footing, then open
	## framing, then something with a roof on it, then lit windows - which means
	## five islands side by side tell you what is happening on each of them
	## without a single number, and the difference between "framing" and "clad"
	## is legible from across a room.
	func _draw_plot(w: float, base: float) -> void:
		# The stages are read off the real queue rather than guessed, so the
		# drawing cannot drift out of step with the build. A house reaches full
		# height when the frame tops out, a third of the way through - after that
		# it gets a roof, then walls, then windows, then lights, and none of
		# those make it taller. That is the shape of a real build and it is why a
		# bar would be the wrong picture.
		var dug := Plan.fraction_after("Earthworks")
		var poured := Plan.fraction_after("Slab")
		var framed := Plan.fraction_after("Storey 3")
		var roofed := Plan.fraction_after("Roof")
		var clad := Plan.fraction_after("Cladding")

		var body := Color("15110C")
		var mid := w * 0.5
		var wide := 88.0
		var full := 124.0
		var p := progress

		if p < dug:
			# Set out but not dug. Four stakes and a string line, which is
			# exactly what they do in the first ten minutes.
			for i in 4:
				var x := mid + (-1.0 if i % 2 == 0 else 1.0) * wide * 0.5
				var y := base - (7.0 if i < 2 else 0.0)
				draw_line(Vector2(x, y), Vector2(x, y - 15.0), Color(body, 0.75), 3.0)
			draw_line(Vector2(mid - wide * 0.5, base - 12.0),
				Vector2(mid + wide * 0.5, base - 12.0), Color(body, 0.40), 2.0)
			return

		if p < poured:
			# Dug and shored, with the footing going in along the bottom.
			draw_line(Vector2(mid - wide * 0.58, base + 6.0),
				Vector2(mid + wide * 0.58, base + 6.0), Color(body, 0.45), 3.0)
			for i in 2:
				var x := mid + (-1.0 if i == 0 else 1.0) * wide * 0.58
				draw_line(Vector2(x, base + 6.0), Vector2(x, base - 16.0),
					Color(body, 0.45), 3.0)
			var run := clampf((p - dug) / maxf(poured - dug, 0.001), 0.0, 1.0)
			draw_rect(Rect2(mid - wide * 0.5, base - 10.0, wide * run, 10.0), body)
			return

		draw_rect(Rect2(mid - wide * 0.5, base - 10.0, wide, 10.0), body)
		var top := base - 10.0

		if p < framed:
			# Framing, open to the sky, which is what the island looks like for
			# the better part of two days.
			var up := clampf((p - poured) / maxf(framed - poured, 0.001), 0.0, 1.0) * full
			for i in 4:
				var x := mid + lerpf(-wide * 0.5, wide * 0.5, float(i) / 3.0)
				draw_line(Vector2(x, top), Vector2(x, top - up), Color(body, 0.9), 5.0)
			for level in 3:
				var y := top - full / 3.0 * float(level + 1)
				if y > top - up:
					draw_line(Vector2(mid - wide * 0.5, y),
						Vector2(mid + wide * 0.5, y), Color(body, 0.9), 5.0)
			return

		var eaves := top - full

		if p < roofed:
			# Topped out. Still open, now with rafters on it.
			for i in 4:
				var x := mid + lerpf(-wide * 0.5, wide * 0.5, float(i) / 3.0)
				draw_line(Vector2(x, top), Vector2(x, eaves), Color(body, 0.9), 5.0)
			for level in 3:
				draw_line(Vector2(mid - wide * 0.5, top - full / 3.0 * float(level + 1)),
					Vector2(mid + wide * 0.5, top - full / 3.0 * float(level + 1)),
					Color(body, 0.9), 5.0)
			draw_line(Vector2(mid - wide * 0.62, eaves), Vector2(mid, eaves - 34.0),
				Color(body, 0.9), 5.0)
			draw_line(Vector2(mid + wide * 0.62, eaves), Vector2(mid, eaves - 34.0),
				Color(body, 0.9), 5.0)
			return

		draw_rect(Rect2(mid - wide * 0.5, eaves, wide, full), body)
		draw_colored_polygon(PackedVector2Array([
			Vector2(mid - wide * 0.62, eaves),
			Vector2(mid + wide * 0.62, eaves),
			Vector2(mid, eaves - 34.0)]), body)

		if p < clad:
			return

		# Openings, dark until the last hour of the week and then lit. The lights
		# are the last thing that happens out there and the last thing here.
		var glow := Color(Menu.EMBER, 0.90)
		var dark := Color("2A241C")
		for level in 3:
			var y := top - 30.0 - float(level) * (full / 3.0)
			for side in [-27.0, 9.0]:
				var on := p > 0.88 and float(level) < (p - 0.88) / 0.04
				draw_rect(Rect2(mid + side, y, 18.0, 20.0), glow if on else dark)


func _init() -> void:
	layer = 120


func show_title() -> void:
	_clear()
	_screen = Screen.TITLE

	var root := _panel()
	_title_root = root

	var mark := _label("Elvle", 190, Color(INK, 0.95))
	mark.anchor_left = 0.0
	mark.anchor_right = 1.0
	mark.offset_top = 404.0
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(mark)

	var rule := ColorRect.new()
	rule.color = Color(INK, 0.22)
	rule.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rule.position = Vector2(2622.0 * 0.5 - 1.0, 644.0)
	rule.size = Vector2(2.0, 2.0)
	root.add_child(rule)

	var under := _label("Elves in a bottle", 46, Color(INK, 0.48))
	under.anchor_left = 0.0
	under.anchor_right = 1.0
	under.offset_top = 688.0
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(under)

	_action = _label("Continue" if Progress.seen_title() else "Begin", 58,
		Color(INK, 0.86))
	_action.anchor_left = 0.0
	_action.anchor_right = 1.0
	_action.offset_top = 856.0
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_action)

	# The rule draws itself across under the wordmark, once, and then nothing on
	# this screen moves again.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(rule, "size:x", 300.0, 0.55).set_ease(Tween.EASE_OUT)
	tween.tween_property(rule, "position:x", 2622.0 * 0.5 - 150.0, 0.55) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 1.0, 0.4).from(0.0)


func show_picker() -> void:
	_clear()
	_screen = Screen.PICKER

	var root := _panel()
	_picker_root = root
	_plots = []

	var span := PLOT_W * float(Biome.COUNT) + PLOT_GAP * float(Biome.COUNT - 1)
	var left := (2622.0 - span) * 0.5
	var top := 344.0

	for i in Biome.COUNT:
		var column := Control.new()
		column.set_anchors_preset(Control.PRESET_TOP_LEFT)
		column.position = Vector2(left + float(i) * (PLOT_W + PLOT_GAP), top)
		column.size = Vector2(PLOT_W, CHIP_H + 212.0)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(column)

		var plot := Plot.new()
		plot.index = i
		plot.tint = Biome.of(i)
		plot.progress = Progress.fraction(i)
		plot.lit = i == Progress.last_island()
		plot.set_anchors_preset(Control.PRESET_TOP_LEFT)
		plot.size = Vector2(PLOT_W, CHIP_H)
		plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(plot)
		_plots.append({"plot": plot, "column": column})

		var name := _label(Biome.name_of(i), 52, Color(INK, 0.88))
		name.set_anchors_preset(Control.PRESET_TOP_LEFT)
		name.position = Vector2(0, CHIP_H + 34.0)
		name.size = Vector2(PLOT_W, 60.0)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name)

		var phase := _label(Progress.phase(i), 38, Color(INK, 0.42))
		phase.set_anchors_preset(Control.PRESET_TOP_LEFT)
		phase.position = Vector2(0, CHIP_H + 102.0)
		phase.size = Vector2(PLOT_W, 50.0)
		phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(phase)

		# How much building this island has actually had out of you. Time spent,
		# never time remaining: a countdown is a thing to wait out, and a clock
		# that only moves while you are working is a record of what you did.
		var clock := _label(Progress.build_time(i), 34, Color(INK, 0.26))
		clock.set_anchors_preset(Control.PRESET_TOP_LEFT)
		clock.position = Vector2(0, CHIP_H + 154.0)
		clock.size = Vector2(PLOT_W, 46.0)
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(clock)

		# Entering from below, a beat apart. Forty milliseconds is enough to read
		# as five things arriving rather than one thing appearing.
		column.modulate.a = 0.0
		column.position.y += 26.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(column, "modulate:a", 1.0, 0.24) \
			.set_delay(float(i) * 0.04)
		tween.tween_property(column, "position:y", top, 0.26) \
			.set_delay(float(i) * 0.04).set_ease(Tween.EASE_OUT)

	# The one thing this screen has to teach, said once and never again.
	_hint = _label("They only build while the phone is still.", 40, Color(INK, 0.34))
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.offset_top = 1020.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint)


func hide_all() -> void:
	_clear()
	_screen = Screen.NONE


func showing() -> bool:
	return _screen != Screen.NONE


## Nothing here uses Godot's own buttons. The whole app is drawn rather than
## themed, and a default-styled Button in the middle of it would be the one
## element that came from somewhere else.
func tapped(at: Vector2) -> bool:
	match _screen:
		Screen.TITLE:
			Progress.mark_seen()
			begin.emit()
			return true
		Screen.PICKER:
			for entry in _plots:
				var column: Control = entry["column"]
				# The tap area is the whole column, name and phase included,
				# which is 372 x 438 - comfortably past a 44pt target and past
				# the point where anybody has to aim.
				var box := Rect2(column.position, column.size)
				if box.has_point(at):
					chose.emit(int(entry["plot"].index))
					return true
			dismissed.emit()
			return true
	return false


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_plots = []
	_action = null
	_hint = null


func _panel() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var wash := ColorRect.new()
	wash.color = Color(VOID.r, VOID.g, VOID.b, 0.93)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wash)

	add_child(root)
	return root


func _label(text: String, size_px: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
