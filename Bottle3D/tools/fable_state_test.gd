extends SceneTree

func _init() -> void:
	var state := FableState.new(42)
	var original_seed := state.sleeping_hill_seed
	assert(state.resolve_sleeping_hill(FableState.HOLLOW))
	var restored := FableState.from_dict(state.to_dict())
	assert(restored.world_seed == 42)
	assert(restored.sleeping_hill_seed == original_seed)
	assert(restored.sleeping_hill == FableState.HOLLOW)
	assert(not restored.resolve_sleeping_hill(FableState.GROVE))

	var journey := FableJourney.new()
	journey.begin()
	assert(journey.accept_step(0))
	assert(not journey.accept_step(2))
	assert(journey.accept_step(1))
	assert(journey.accept_step(2))
	assert(not journey.active())
	assert(not journey.accept_step(2))
	print("fable_state_test passed")
	quit()
