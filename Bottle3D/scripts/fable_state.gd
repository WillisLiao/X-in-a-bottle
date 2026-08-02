class_name FableState
extends RefCounted

## Versioned, renderer-free state for the finite Meadow Act.
## `from_dict` is the migration boundary for the shipped Sleeping Hill record.

const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const STORY_GENERATOR_VERSION := 1
const DEFAULT_WORLD_SEED := 0x4C554E41
const UNRESOLVED := "unresolved"
const HOLLOW := "hollow"
const GROVE := "grove"
const TROLL := "troll"
const HOBBIT := "hobbit"
const HOME := "home"
const OUTWARD := "outward"

var schema_version := SCHEMA_VERSION
var world_seed: int
var story_generator_version := STORY_GENERATOR_VERSION
var fables: Dictionary = {}
var meadow_act_complete := false

func _init(seed: int = DEFAULT_WORLD_SEED) -> void:
	world_seed = seed
	fables = {
		"sleeping_hill": _record("HILL", UNRESOLVED),
		"rooted_gate": _record("GATE", UNRESOLVED),
		"lost_lights": _record("LIGHTS", UNRESOLVED),
	}

static func load() -> FableState:
	var data := Progress.fable_state()
	if data.is_empty():
		return FableState.new(new_world_seed())
	return from_dict(data)

func persist() -> void:
	Progress.set_fable_state(to_dict())
	Progress.flush()

static func from_dict(data: Dictionary) -> FableState:
	# A shipped v1 record has no catalog. Preserve both its resolution and its
	# exact hill seed, then derive only the two new chapter seeds.
	var state := FableState.new(int(data.get("world_seed", DEFAULT_WORLD_SEED)))
	state.schema_version = SCHEMA_VERSION
	state.story_generator_version = int(data.get("story_generator_version", STORY_GENERATOR_VERSION))
	if data.has("fables"):
		for id in state.fables:
			var incoming: Dictionary = data["fables"].get(id, {})
			state.fables[id] = state._merge_record(state.fables[id], incoming)
	else:
		var hill_resolution := String(data.get("sleeping_hill", UNRESOLVED))
		var hill: Dictionary = (state.fables["sleeping_hill"] as Dictionary).duplicate(true)
		hill["resolution"] = hill_resolution
		hill["seed"] = int(data.get("sleeping_hill_seed", hill["seed"]))
		hill["version"] = int(data.get("story_generator_version", STORY_GENERATOR_VERSION))
		state.fables["sleeping_hill"] = hill
	state.meadow_act_complete = bool(data.get("meadow_act_complete", false))
	return state

func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"world_seed": world_seed,
		"story_generator_version": story_generator_version,
		"fables": fables,
		"meadow_act_complete": meadow_act_complete,
	}

func record(id: String) -> Dictionary:
	return fables.get(id, {})

func resolution(id: String) -> String:
	return String(record(id).get("resolution", UNRESOLVED))

func seed_for(id: String) -> int:
	return int(record(id).get("seed", _mix(world_seed, id.hash())))

func resolve(id: String, resolution_value: String) -> bool:
	if not fables.has(id) or resolution(id) != UNRESOLVED:
		return false
	var accepted: Array = {
		"sleeping_hill": [HOLLOW, GROVE],
		"rooted_gate": [TROLL, HOBBIT],
		"lost_lights": [HOME, OUTWARD],
	}.get(id, [])
	if not accepted.has(resolution_value):
		return false
	var entry: Dictionary = fables[id]
	entry["resolution"] = resolution_value
	if id == "rooted_gate":
		entry["chosen_species"] = resolution_value
	fables[id] = entry
	return true

func complete_meadow_act() -> bool:
	if meadow_act_complete or not all_chapters_resolved():
		return false
	meadow_act_complete = true
	return true

func all_chapters_resolved() -> bool:
	return resolution("sleeping_hill") != UNRESOLVED \
		and resolution("rooted_gate") != UNRESOLVED \
		and resolution("lost_lights") != UNRESOLVED

static func new_world_seed() -> int:
	return absi(Time.get_unix_time_from_system()) ^ DEFAULT_WORLD_SEED

func _record(salt: String, resolution_value: String) -> Dictionary:
	return {"version": STORY_GENERATOR_VERSION, "seed": _mix(world_seed, salt.hash()), "resolution": resolution_value}

func _merge_record(base: Dictionary, incoming: Dictionary) -> Dictionary:
	var merged := base.duplicate(true)
	for key in incoming:
		merged[key] = incoming[key]
	if not merged.has("version"):
		merged["version"] = STORY_GENERATOR_VERSION
	return merged

static func _mix(a: int, b: int) -> int:
	var value := a ^ b
	value = value * 1103515245 + 12345
	return value & 0x7fffffff
