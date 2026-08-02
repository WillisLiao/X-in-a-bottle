class_name Menu
extends CanvasLayer

## The way into the living field. One screen, one action, no checklist.
##
## ## The picker is gone
##
## There used to be a second screen: five chips of ground side by side, each
## with a black house on it drawn at the stage that island's house had actually
## reached, and you tapped one to choose where to spend the next hour.
##
## It was the best-drawn thing in the app and it was answering a question that
## should never have been asked. Choosing an island fragmented attention across
## five parallel saves in an app whose whole subject is sustained attention on
## one thing, and four of those saves were frozen at any moment because there is
## no offline progress. On 2026-08-02 the five islands became five regions of
## one world, and the picker became a screen standing between the user and a
## world they can simply look at.
##
## So the map is not a screen any more. Pinch out and the region recedes until
## you can see the whole world and everywhere you have settled in it; pinch in
## and you are close enough to watch one pair of hands. One continuous gesture,
## no menu, and one less thing to be got through. It lives in `main.gd` with the
## rest of the camera, because that is all it is.
##
## What that leaves here is the title, which exists so the app does not open
## straight into a moving scene, and so there is one place to say the only rule
## the app has.

signal begin
signal dismissed

enum Screen { TITLE, NONE }

## The layout is in viewport units, and the viewport is 2622 x 1206. About three
## units to the point, so a 44pt touch target is 132 and body text is around 46.
const INK := Color("EFE3CB")
const VOID := Color("0B0906")
const EMBER := Color("FF9A4A")

var _screen: Screen = Screen.NONE
var _title_root: Control
var _action: Label
var _hint: Label


func _init() -> void:
	layer = 120


func show_title() -> void:
	_clear()
	_screen = Screen.TITLE

	var root := _panel()
	_title_root = root

	var mark := _label("Hobbitle", 190, Color(INK, 0.95))
	mark.anchor_left = 0.0
	mark.anchor_right = 1.0
	mark.offset_top = 380.0
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(mark)

	var rule := ColorRect.new()
	rule.color = Color(INK, 0.22)
	rule.set_anchors_preset(Control.PRESET_TOP_LEFT)
	rule.position = Vector2(2622.0 * 0.5 - 1.0, 620.0)
	rule.size = Vector2(2.0, 2.0)
	root.add_child(rule)

	var under := _label("The paths you walk become roads.", 46, Color(INK, 0.48))
	under.anchor_left = 0.0
	under.anchor_right = 1.0
	under.offset_top = 664.0
	under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(under)

	_action = _label("Continue" if Progress.seen_title() else "Begin", 58,
		Color(INK, 0.86))
	_action.anchor_left = 0.0
	_action.anchor_right = 1.0
	_action.offset_top = 828.0
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_action)

	# The title names the premise, then gets out of the way before the field.
	_hint = _label("Find what the road leaves behind.", 40, Color(INK, 0.30))
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.offset_top = 1000.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint)

	# The rule draws itself across under the wordmark, once, and then nothing on
	# this screen moves again.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(rule, "size:x", 300.0, 0.55).set_ease(Tween.EASE_OUT)
	tween.tween_property(rule, "position:x", 2622.0 * 0.5 - 150.0, 0.55) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 1.0, 0.4).from(0.0)


func hide_all() -> void:
	_clear()
	_screen = Screen.NONE


func showing() -> bool:
	return _screen != Screen.NONE


## Nothing here uses Godot's own buttons. The whole app is drawn rather than
## themed, and a default-styled Button in the middle of it would be the one
## element that came from somewhere else.
func tapped(_at: Vector2) -> bool:
	if _screen != Screen.TITLE:
		return false
	Progress.mark_seen()
	begin.emit()
	return true


func _clear() -> void:
	for child in get_children():
		child.queue_free()
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
