class_name FableJourneySource
extends RefCounted

## Capture source for the same fixed story steps a player reaches by touch.
## It is part of the fantasy world, so no platform or external signal is needed.

signal step_reached(step: int)

func play() -> void:
	for step in FableJourney.STEP_COUNT:
		step_reached.emit(step)
