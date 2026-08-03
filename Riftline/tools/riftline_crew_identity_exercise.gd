extends SceneTree

const IDENTITY := preload("res://scripts/riftline_crew_identity.gd")
const ROSTER := preload("res://scripts/riftline_roster.gd")
const LOBBY := preload("res://scripts/riftline_lobby.gd")

func _initialize() -> void:
	assert(IDENTITY.ORDERED_IDS == ["vane", "cradle", "keel", "loom"])
	for frame_id in IDENTITY.ORDERED_IDS:
		assert(IDENTITY.valid_id(frame_id))
		assert(not str(IDENTITY.facts(frame_id).get("name", "")).is_empty())
	assert(IDENTITY.canonical_id("unknown") == "vane")
	assert(IDENTITY.bot_frame_for_slot(0, 3) == "vane")
	assert(IDENTITY.bot_frame_for_slot(1, 3) == "cradle")

	var roster := ROSTER.new()
	assert(roster.configure(1, false, false))
	var host := roster.add_host("keel")
	var peer := roster.assign_peer(17, "loom")
	assert(host.frame_id == "keel")
	assert(peer.frame_id == "loom")
	assert(roster.set_frame_for_actor("host", "cradle"))
	assert(str(roster.record("host").frame_id) == "cradle")
	assert(not roster.set_frame_for_actor("host", "not-a-frame"))

	var lobby := LOBBY.new()
	assert(lobby.configure(1, RiftlineMap.Id.DUEL_YARD, false))
	lobby.add_host("vane")
	lobby.admit_peer(22, "keel")
	assert(lobby.request_peer_frame(22, "loom"))
	assert(str(lobby.public_state().records[1].frame_id) == "loom")
	var revision := int(lobby.public_state().revision)
	assert(not lobby.request_peer_frame(22, "loom"))
	assert(int(lobby.public_state().revision) == revision)
	assert(not lobby.request_peer_frame(22, "bad"))

	print("Riftline crew identity exercise: PASS")
	quit()
