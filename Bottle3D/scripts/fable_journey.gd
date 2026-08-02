class_name FableJourney
extends RefCounted

## Three intentional story steps, not a route recorder and not a clock.

signal completed

const STEP_COUNT := 3
var _next_step := -1
var _reached: Array[int] = []

func begin() -> void:
	_next_step = 0
	_reached.clear()

func accept_step(step: int) -> bool:
	if not active() or step != _next_step:
		return false
	_reached.append(step)
	_next_step += 1
	if _next_step == STEP_COUNT:
		_next_step = -1
		completed.emit()
	return true

func active() -> bool:
	return _next_step >= 0

func next_step() -> int:
	return _next_step

func reached() -> Array[int]:
	return _reached.duplicate()
