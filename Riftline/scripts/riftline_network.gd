class_name RiftlineNetwork
extends Node

signal session_status(status: String)
signal host_discovered(session: Dictionary)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal input_received(peer_id: int, frame: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal reliable_event_received(event: Dictionary, sender_id: int)

const PROJECT_ID := "riftline-lan"
const PROTOCOL_VERSION := 1
const MAX_PEERS := 2
const ENET_PORT := 34711
const DISCOVERY_PORT := 34712
const INPUT_CHANNEL := 1
const SNAPSHOT_CHANNEL := 2
const MAX_FUTURE_INPUT := 24
const ADVERTISEMENT_INTERVAL := 0.65
const DISCOVERY_TTL := 4.0

var _peer: ENetMultiplayerPeer
var _discovery_socket: PacketPeerUDP
var _discovery_listening := false
var _advertising := false
var _advertisement_remaining := 0.0
var _discovered_address := ""
var _discovered_marker := ""
var _last_input_sequence: Dictionary = {}
var _session_marker := ""

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	if _advertising:
		_advertisement_remaining -= delta
		if _advertisement_remaining <= 0.0:
			_advertisement_remaining = ADVERTISEMENT_INTERVAL
			_advertise_session()
	if _discovery_listening:
		_poll_discovery()

func host_lan() -> Error:
	stop()
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
	_discovered_address = ""
	_discovered_marker = ""
	_session_marker = ""

func send_input(frame: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return
	_rpc_input.rpc_id(1, frame)

func publish_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	_rpc_snapshot.rpc(snapshot)

func publish_event(event: Dictionary) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		reliable_event_received.emit(event, multiplayer.get_unique_id())
		_rpc_event.rpc(event)
	else:
		_rpc_client_event.rpc_id(1, event)

func start_command_line_mode() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument == "--lan-host":
			return host_lan() == OK
		if argument.begins_with("--lan-join="):
			var address := argument.trim_prefix("--lan-join=")
			if not _is_ipv4(address):
				session_status.emit("LINK ERROR")
				return false
			_discovered_address = address
			return _join_address(address) == OK
	return false

func is_active() -> bool:
	return multiplayer.multiplayer_peer != null

func _join_address(address: String) -> Error:
	stop()
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
		_stop_discovery()
		session_status.emit("RIVAL LINKED")
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_last_input_sequence.erase(peer_id)
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
	if sender <= 0 or not frame.has("sequence"):
		return
	var sequence := int(frame.sequence)
	var previous := int(_last_input_sequence.get(sender, -1))
	if sequence <= previous or sequence > previous + MAX_FUTURE_INPUT:
		return
	_last_input_sequence[sender] = sequence
	input_received.emit(sender, frame)

@rpc("authority", "call_remote", "unreliable_ordered", SNAPSHOT_CHANNEL)
func _rpc_snapshot(snapshot: Dictionary) -> void:
	if multiplayer.is_server():
		return
	snapshot_received.emit(snapshot)

@rpc("authority", "reliable")
func _rpc_event(event: Dictionary) -> void:
	if multiplayer.is_server():
		return
	reliable_event_received.emit(event, 1)

@rpc("any_peer", "reliable")
func _rpc_client_event(event: Dictionary) -> void:
	if not multiplayer.is_server() or event.is_empty():
		return
	var sender := multiplayer.get_remote_sender_id()
	reliable_event_received.emit(event, sender)

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
