class_name FableState
extends RefCounted

## The small, irreversible part of the world that belongs to the offline fable.
## It is deliberately renderer-free so its seed invariant can be tested without
## touching Progress, user://, or a real device configuration.

const SCHEMA_VERSION := 1
const STORY_GENERATOR_VERSION := 1
const DEFAULT_WORLD_SEED := 0x4C554E41
const UNRESOLVED := "unresolved"
const HOLLOW := "hollow"
const GROVE := "grove"

var schema_version := SCHEMA_VERSION
var world_seed: int
var story_generator_version := STORY_GENERATOR_VERSION
var sleeping_hill: String = UNRESOLVED
var sleeping_hill_seed: int

func _init(seed: int = DEFAULT_WORLD_SEED) -> void:
	world_seed = seed
	sleeping_hill_seed = _mix(seed, 0x48494C4C)

static func load() -> FableState:
	var data := Progress.fable_state()
	if data.is_empty():
		return FableState.new(new_world_seed())
	return from_dict(data)

func persist() -> void:
	Progress.set_fable_state(to_dict())
	Progress.flush()

static func from_dict(data: Dictionary) -> FableState:
	var state := FableState.new(int(data.get("world_seed", DEFAULT_WORLD_SEED)))
	state.schema_version = int(data.get("schema_version", SCHEMA_VERSION))
	state.story_generator_version = int(data.get("story_generator_version", STORY_GENERATOR_VERSION))
	state.sleeping_hill = String(data.get("sleeping_hill", UNRESOLVED))
	state.sleeping_hill_seed = int(data.get("sleeping_hill_seed", _mix(state.world_seed, 0x48494C4C)))
	if not [UNRESOLVED, HOLLOW, GROVE].has(state.sleeping_hill):
		state.sleeping_hill = UNRESOLVED
	return state

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"world_seed": world_seed,
		"story_generator_version": story_generator_version,
		"sleeping_hill": sleeping_hill,
		"sleeping_hill_seed": sleeping_hill_seed,
	}

func resolve_sleeping_hill(outcome: String) -> bool:
	if sleeping_hill != UNRESOLVED or not [HOLLOW, GROVE].has(outcome):
		return false
	sleeping_hill = outcome
	return true

static func new_world_seed() -> int:
	return absi(Time.get_unix_time_from_system()) ^ DEFAULT_WORLD_SEED

static func _mix(a: int, b: int) -> int:
	var value := a ^ b
	value = value * 1103515245 + 12345
	return value & 0x7fffffff
