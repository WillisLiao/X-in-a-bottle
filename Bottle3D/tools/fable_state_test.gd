extends SceneTree

func _init() -> void:
	var legacy := {
		"schema_version": 1,
		"world_seed": 42,
		"story_generator_version": 1,
		"sleeping_hill": FableState.HOLLOW,
		"sleeping_hill_seed": 1234,
	}
	var state := FableState.from_dict(legacy)
	assert(state.schema_version == FableState.SCHEMA_VERSION)
	assert(state.resolution("sleeping_hill") == FableState.HOLLOW)
	assert(state.seed_for("sleeping_hill") == 1234)
	assert(FableCatalog.available(state) == FableCatalog.ROOTED_GATE)

	assert(state.resolve(FableCatalog.ROOTED_GATE, FableState.TROLL))
	assert(FableCatalog.available(state) == FableCatalog.LOST_LIGHTS)
	assert(state.resolve(FableCatalog.LOST_LIGHTS, FableState.OUTWARD))
	assert(FableCatalog.available(state) == FableCatalog.MIGRATION)
	assert(state.complete_meadow_act())
	var restored := FableState.from_dict(state.to_dict())
	assert(restored.resolution(FableCatalog.ROOTED_GATE) == FableState.TROLL)
	assert(restored.resolution(FableCatalog.LOST_LIGHTS) == FableState.OUTWARD)
	assert(restored.meadow_act_complete)
	assert(not restored.complete_meadow_act())
	assert(not restored.resolve(FableCatalog.LOST_LIGHTS, FableState.HOME))
	print("fable_state_test passed")
	quit()
