class_name RiftlineNetwork
extends Node

signal session_status(status: String)
signal host_discovered(session: Dictionary)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal input_received(peer_id: int, frame: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal reliable_event_received(event: Dictionary, sender_id: int)
signal team_assigned(team: int)

const PROJECT_ID := "riftline-lan"
const PROTOCOL_VERSION := 1
const MAX_PEERS := 2
const ENET_PORT := 34711
const DISCOVERY_PORT := 34712
const INPUT_CHANNEL := 1
const SNAPSHOT_CHANNEL := 2
const MAX_FUTURE_INPUT := 24
const MAX_MOVE_COMPONENT := 1.05
const MAX_VIEW_TURN_PER_FRAME := 0.55
const ADVERTISEMENT_INTERVAL := 0.65
const DISCOVERY_TTL := 4.0

enum SessionRole { OFFLINE, APP_HOST, DEDICATED_SERVER, JOINING_CLIENT }

var _peer: ENetMultiplayerPeer
var _discovery_socket: PacketPeerUDP
var _discovery_listening := false
var _advertising := false
var _advertisement_remaining := 0.0
var _discovered_address := ""
var _discovered_marker := ""
var _last_input_sequence: Dictionary = {}
var _last_input_view: Dictionary = {}
var _peer_team: Dictionary = {}
var _session_marker := ""
var session_role: SessionRole = SessionRole.OFFLINE
var local_team := -1
var simulation_clock := 0.0
var _sim_latency := 0.0
var _sim_jitter := 0.0
var _sim_loss_percent := 0.0
var _sim_random := RandomNumberGenerator.new()
var _sim_queue: Array[Dictionary] = []
var _sim_unreliable_sequence := 0
var _sim_last_unreliable_release := -1
var _sim_reliable_release_after := 0.0

func _ready() -> void:
	_read_command_line_options()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	simulation_clock += delta
	_release_simulated_messages()
	if _advertising:
		_advertisement_remaining -= delta
		if _advertisement_remaining <= 0.0:
			_advertisement_remaining = ADVERTISEMENT_INTERVAL
			_advertise_session()
	if _discovery_listening:
		_poll_discovery()

func host_lan() -> Error:
	stop()
	session_role = SessionRole.APP_HOST
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(ENET_PORT, MAX_PEERS)
	if error != OK:
		_peer = null
		session_status.emit("LINK ERROR")
		return error
	multiplayer.multiplayer_peer = _peer
	_session_marker = _new_session_marker()
	_start_advertising()
	session_status.emit("WAITING FOR RIVAL")
	return OK

func begin_lan_discovery() -> void:
	stop()
	session_role = SessionRole.JOINING_CLIENT
	_discovery_socket = PacketPeerUDP.new()
	var error := _discovery_socket.bind(DISCOVERY_PORT)
	if error != OK:
		_discovery_socket = null
		session_status.emit("SCAN UNAVAILABLE")
		return
	_discovery_listening = true
	session_status.emit("SEEKING RIFT")

func join_discovered_host() -> Error:
	if _discovered_address.is_empty():
		session_status.emit("NO RIFT FOUND")
		return ERR_UNAVAILABLE
	return _join_address(_discovered_address)

func stop() -> void:
	_stop_discovery()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_peer = null
	_last_input_sequence.clear()
	_last_input_view.clear()
	_peer_team.clear()
	local_team = -1
	_discovered_address = ""
	_discovered_marker = ""
	_session_marker = ""
	_sim_queue.clear()
	_sim_reliable_release_after = simulation_clock
	session_role = SessionRole.OFFLINE

func send_input(frame: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	_queue_or_send({"kind": "input", "frame": frame})

func publish_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_queue_or_send({"kind": "snapshot", "snapshot": snapshot})

func publish_event(event: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		reliable_event_received.emit(event, multiplayer.get_unique_id())
		_queue_or_send({"kind": "event", "event": event}, true)
	else:
		_queue_or_send({"kind": "client_event", "event": event}, true)

func start_command_line_mode() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--dedicated-server":
			return _start_dedicated_server() == OK
		if argument == "--lan-host":
			return host_lan() == OK
		if argument.begins_with("--lan-join="):
			var address := argument.trim_prefix("--lan-join=")
			if not _is_ipv4(address):
				session_status.emit("LINK ERROR")
				return false
			_discovered_address = address
			session_role = SessionRole.JOINING_CLIENT
			return _join_address(address) == OK
	return false

func is_active() -> bool:
	return multiplayer.multiplayer_peer != null

func _join_address(address: String) -> Error:
	stop()
	session_role = SessionRole.JOINING_CLIENT
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address, ENET_PORT)
	if error != OK:
		_peer = null
		session_status.emit("LINK ERROR")
		return error
	multiplayer.multiplayer_peer = _peer
	session_status.emit("LINKING")
	return OK

func _start_advertising() -> void:
	_discovery_socket = PacketPeerUDP.new()
	var error := _discovery_socket.bind(0)
	if error != OK:
		_discovery_socket = null
		_advertising = false
		return
	_discovery_socket.set_broadcast_enabled(true)
	_discovery_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_advertising = true
	_advertisement_remaining = 0.0

func _stop_discovery() -> void:
	_advertising = false
	_discovery_listening = false
	_advertisement_remaining = 0.0
	if _discovery_socket != null:
		_discovery_socket.close()
	_discovery_socket = null

func _advertise_session() -> void:
	if not _advertising or _discovery_socket == null or not multiplayer.is_server():
		return
	var packet := {
		"project": PROJECT_ID,
		"version": PROTOCOL_VERSION,
		"marker": _session_marker,
		"kind": "dedicated" if session_role == SessionRole.DEDICATED_SERVER else "app_host",
		"issued": Time.get_ticks_msec(),
	}
	_discovery_socket.put_packet(JSON.stringify(packet).to_utf8_buffer())

func _poll_discovery() -> void:
	if _discovery_socket == null:
		return
	while _discovery_socket.get_available_packet_count() > 0:
		var raw := _discovery_socket.get_packet()
		var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = parsed
		if packet.get("project", "") != PROJECT_ID or int(packet.get("version", -1)) != PROTOCOL_VERSION:
			continue
		var issued := int(packet.get("issued", 0))
		if issued > 0 and Time.get_ticks_msec() - issued > int(DISCOVERY_TTL * 1000.0):
			continue
		var marker := str(packet.get("marker", ""))
		if marker.is_empty() or marker == _discovered_marker:
			continue
		_discovered_marker = marker
		_discovered_address = _discovery_socket.get_packet_ip()
		host_discovered.emit({"marker": marker, "address": _discovered_address, "label": "RIFT FOUND"})
		session_status.emit("RIFT FOUND")

func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		var assigned := _assign_peer(peer_id)
		if assigned < 0:
			_peer.disconnect_peer(peer_id, true)
			session_status.emit("RIFT FULL")
			return
		_stop_discovery()
		session_status.emit("RIVAL LINKED")
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_last_input_sequence.erase(peer_id)
	_last_input_view.erase(peer_id)
	_peer_team.erase(peer_id)
	peer_left.emit(peer_id)
	session_status.emit("LINK LOST")

func _on_connected_to_server() -> void:
	_stop_discovery()
	session_status.emit("RIVAL LINKED")
	peer_joined.emit(1)

func _on_connection_failed() -> void:
	session_status.emit("LINK FAILED")
	stop()

func _on_server_disconnected() -> void:
	session_status.emit("LINK LOST")
	peer_left.emit(1)
	stop()

@rpc("any_peer", "call_remote", "unreliable_ordered", INPUT_CHANNEL)
func _rpc_input(frame: Dictionary) -> void:
	if not multiplayer.is_server() or frame.is_empty():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	var validated := _validate_input(sender, frame)
	if validated.is_empty():
		return
	var sequence := int(validated.sequence)
	var previous := int(_last_input_sequence.get(sender, -1))
	if sequence <= previous or sequence > previous + MAX_FUTURE_INPUT:
		return
	_last_input_sequence[sender] = sequence
	_last_input_view[sender] = float(validated.yaw)
	input_received.emit(sender, validated)

@rpc("authority", "call_remote", "unreliable_ordered", SNAPSHOT_CHANNEL)
func _rpc_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		return
	if not snapshot.has("tick") or not snapshot.has("players"):
		return
	snapshot_received.emit(snapshot)

@rpc("authority", "reliable")
func _rpc_event(event: Dictionary) -> void:
	if multiplayer.is_server():
		return
	reliable_event_received.emit(event, 1)
	if str(event.get("type", "")) == "assigned_team":
		local_team = int(event.get("team", -1))
		team_assigned.emit(local_team)

@rpc("any_peer", "reliable")
func _rpc_client_event(event: Dictionary) -> void:
	if not multiplayer.is_server() or event.is_empty():
		return
	var sender := multiplayer.get_remote_sender_id()
	reliable_event_received.emit(event, sender)

func peer_team(peer_id: int) -> int:
	return int(_peer_team.get(peer_id, -1))

func is_authority_server() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

func is_dedicated_server() -> bool:
	return session_role == SessionRole.DEDICATED_SERVER

func _start_dedicated_server() -> Error:
	stop()
	session_role = SessionRole.DEDICATED_SERVER
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(ENET_PORT, MAX_PEERS)
	if error != OK:
		_peer = null
		session_status.emit("LINK ERROR")
		return error
	multiplayer.multiplayer_peer = _peer
	_session_marker = _new_session_marker()
	_start_advertising()
	print("Riftline dedicated authority listening on LAN")
	return OK

func _assign_peer(peer_id: int) -> int:
	if _peer_team.has(peer_id):
		return int(_peer_team[peer_id])
	var max_players := 2 if session_role == SessionRole.DEDICATED_SERVER else 1
	if _peer_team.size() >= max_players:
		return -1
	var assigned := DuelistTeamVoid
	if session_role == SessionRole.DEDICATED_SERVER:
		assigned = DuelistTeamSun if not _peer_team.values().has(DuelistTeamSun) else DuelistTeamVoid
	_peer_team[peer_id] = assigned
	_send_server_event(peer_id, {"type": "assigned_team", "team": assigned})
	print("Riftline peer assigned %s" % ("Sun" if assigned == DuelistTeamSun else "Void"))
	return assigned

const DuelistTeamSun := 0
const DuelistTeamVoid := 1

func _validate_input(peer_id: int, frame: Dictionary) -> Dictionary:
	if not frame.has("sequence") or typeof(frame.sequence) != TYPE_INT:
		return {}
	for key in ["move_x", "move_y", "yaw", "pitch"]:
		if not frame.has(key) or not _is_finite_number(frame[key]):
			return {}
	var move_x := float(frame.move_x)
	var move_y := float(frame.move_y)
	if absf(move_x) > MAX_MOVE_COMPONENT or absf(move_y) > MAX_MOVE_COMPONENT:
		return {}
	var yaw := float(frame.yaw)
	var pitch := clampf(float(frame.pitch), -1.05, 0.9)
	if _last_input_view.has(peer_id) and absf(angle_difference(float(_last_input_view[peer_id]), yaw)) > MAX_VIEW_TURN_PER_FRAME:
		return {}
	for key in ["aim", "fire", "jump", "crouch", "prone", "weapon_switch", "reload"]:
		if not frame.has(key) or typeof(frame[key]) != TYPE_BOOL:
			return {}
	return {
		"sequence": int(frame.sequence),
		"move_x": clampf(move_x, -1.0, 1.0),
		"move_y": clampf(move_y, -1.0, 1.0),
		"yaw": yaw,
		"pitch": pitch,
		"aim": bool(frame.aim),
		"fire": bool(frame.fire),
		"jump": bool(frame.jump),
		"crouch": bool(frame.crouch),
		"prone": bool(frame.prone),
		"weapon_switch": bool(frame.weapon_switch),
		"reload": bool(frame.reload),
	}

func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))

func _read_command_line_options() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--dedicated-server":
			session_role = SessionRole.DEDICATED_SERVER
		elif argument == "--lan-host":
			session_role = SessionRole.APP_HOST
		elif argument.begins_with("--lan-join="):
			session_role = SessionRole.JOINING_CLIENT
		elif argument.begins_with("--net-sim-latency-ms="):
			_sim_latency = maxf(0.0, argument.trim_prefix("--net-sim-latency-ms=").to_float() / 1000.0)
		elif argument.begins_with("--net-sim-jitter-ms="):
			_sim_jitter = maxf(0.0, argument.trim_prefix("--net-sim-jitter-ms=").to_float() / 1000.0)
		elif argument.begins_with("--net-sim-loss-percent="):
			_sim_loss_percent = clampf(argument.trim_prefix("--net-sim-loss-percent=").to_float(), 0.0, 100.0)
		elif argument.begins_with("--net-sim-seed="):
			_sim_random.seed = int(argument.trim_prefix("--net-sim-seed="))
	if _sim_latency > 0.0 or _sim_jitter > 0.0 or _sim_loss_percent > 0.0:
		print("Riftline network test profile: latency=%dms jitter=%dms loss=%.1f%%" % [_sim_latency * 1000.0, _sim_jitter * 1000.0, _sim_loss_percent])

func _queue_or_send(message: Dictionary, reliable: bool = false) -> void:
	if _sim_latency <= 0.0 and _sim_jitter <= 0.0 and _sim_loss_percent <= 0.0:
		_send_message(message)
		return
	if not reliable and _sim_random.randf() * 100.0 < _sim_loss_percent:
		return
	var delay := _sim_latency + _sim_random.randf_range(-_sim_jitter, _sim_jitter)
	delay = maxf(0.0, delay)
	var queued := message.duplicate(true)
	queued["release_at"] = simulation_clock + delay
	queued["reliable"] = reliable
	if not reliable:
		queued["order"] = _sim_unreliable_sequence
		_sim_unreliable_sequence += 1
	else:
		queued["release_at"] = maxf(float(queued.release_at), _sim_reliable_release_after)
		_sim_reliable_release_after = float(queued.release_at)
	_sim_queue.append(queued)

func _release_simulated_messages() -> void:
	if _sim_queue.is_empty():
		return
	var ready: Array[Dictionary] = []
	var waiting: Array[Dictionary] = []
	for message in _sim_queue:
		if float(message.release_at) <= simulation_clock:
			ready.append(message)
		else:
			waiting.append(message)
	_sim_queue = waiting
	ready.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.release_at) < float(b.release_at))
	for message in ready:
		if not bool(message.reliable):
			var order := int(message.order)
			if order <= _sim_last_unreliable_release:
				continue
			_sim_last_unreliable_release = order
		_send_message(message)

func _send_message(message: Dictionary) -> void:
	match str(message.get("kind", "")):
		"input":
			_rpc_input.rpc_id(1, message.frame)
		"snapshot":
			_rpc_snapshot.rpc(message.snapshot)
		"event":
			_rpc_event.rpc(message.event)
		"event_to_peer":
			_rpc_event.rpc_id(int(message.peer_id), message.event)
		"client_event":
			_rpc_client_event.rpc_id(1, message.event)

func _send_server_event(peer_id: int, event: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_queue_or_send({"kind": "event_to_peer", "peer_id": peer_id, "event": event}, true)

func _new_session_marker() -> String:
	return "%s-%s" % [Time.get_ticks_msec(), randi()]

func _is_ipv4(address: String) -> bool:
	var pieces := address.split(".")
	if pieces.size() != 4:
		return false
	for piece in pieces:
		if piece.is_empty() or not piece.is_valid_int() or int(piece) < 0 or int(piece) > 255:
			return false
	return true
