extends RefCounted

const IDENTITY := preload("res://scripts/riftline_crew_identity.gd")
const PATH := "user://riftline_crew_profile.cfg"
const SECTION := "crew_profile"
const VERSION := 1

static func load_frame() -> String:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return "vane"
	var version := int(config.get_value(SECTION, "version", -1))
	if version != VERSION:
		return "vane"
	return IDENTITY.canonical_id(config.get_value(SECTION, "frame_id", "vane"))

static func save_frame(frame_id: String) -> bool:
	var canonical := IDENTITY.canonical_id(frame_id)
	if canonical != frame_id.to_lower():
		return false
	var config := ConfigFile.new()
	config.set_value(SECTION, "version", VERSION)
	config.set_value(SECTION, "frame_id", canonical)
	return config.save(PATH) == OK
