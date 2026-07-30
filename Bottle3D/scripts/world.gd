class_name World
extends Node3D

## One world inside the bottle.
##
## Every world obeys the same rule: things are caught and kept. Stillness adds
## another object and it stays; disturbance takes a share away. What that looks
## like is entirely up to the world - lightning held in the air, a tree putting
## out branches, ice stacking up, elves arriving.

## Shown briefly when swiped to, then it fades away.
var title: String = ""

## How many things a completely full bottle holds.
var capacity: int = 9

## Gap between arrivals, so the bottle fills visibly rather than all at once
## when the population crosses a threshold.
var spawn_seconds: float = 1.4

## Where the camera should aim. A world that sits on a floor needs a lower
## target than one suspended in mid-air, or it frames up against the bottom
## edge with the whole top of the screen empty.
var focus: Vector3 = Vector3.ZERO

## How far back the camera sits.
var distance: float = 4.0

## Fraction lost per disturbance. Never all of it: losing the lot would make a
## disturbance a reset rather than a cost, and the cost is the product.
const LOSS_FRACTION := 0.30

var _since_spawn: float = 0.0


## Called once when the world is first shown.
func build() -> void:
	pass


func _tick(_delta: float, _population: int, _disturbed: bool) -> void:
	pass


## Add one thing. Returns false if it could not.
func _grow() -> bool:
	return false


## Take a share away.
func _shrink() -> void:
	pass


func held() -> int:
	return 0


func advance(delta: float, population: int, disturbed: bool) -> void:
	_since_spawn += delta
	if held() < population and _since_spawn > spawn_seconds:
		if _grow():
			_since_spawn = 0.0

	_tick(delta, population, disturbed)


## Called on the frame a disturbance begins.
func disturbed() -> void:
	_shrink()


## An unlit additive material, used for everything that glows in here. Unshaded
## keeps it cheap on the mobile renderer, which matters more than it looks.
static func glow_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = color
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	return mat


static func solid_material(color: Color, roughness: float = 0.65) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	return mat
