extends Node

signal player_list_updated
signal match_settings_updated
signal game_rules_updated
signal lan_servers_updated(servers: Array)
signal connection_succeeded
signal connection_failed(reason: String)
signal server_disconnected
signal match_started
signal killfeed_event(killer_name: String, victim_name: String, weapon_name: String)
signal kill_scored(killer_id: int, victim_id: int)
signal chat_message_received(sender_name: String, message: String)
signal interactable_toggled(inter_idx: int, new_state: bool)

const GAME_PORT: int = 44334
const DISCOVERY_PORT: int = 44335
const MAX_CLIENTS: int = 6
const MAX_BOTS: int = 10

const MAP_NAMES: Array[String] = [
	"Bunker Base",
	"Factory Ruins",
	"Desert Outpost",
	"Catacombs Maze",
	"Outpost Towers",
	"Soarin Islands",
	"Pharaoh Pyramid",
	"Snow Blind",
	"Substructure",
	"High Tower",
	"Ring Arena",
	"Lunar Station",
	"Jungle Cliff"
]

const MODE_NAMES: Array[String] = [
	"Free-For-All",
	"Red vs. Blue",
	"Agent Clash (FFA)",
	"Agent Clash (Teams)"
]

const TEAM_COLORS: Array[Color] = [
	Color(0.24, 0.65, 1.0, 1.0),   # 0: Blue Team
	Color(1.0, 0.28, 0.28, 1.0),   # 1: Red Team
	Color(0.22, 0.88, 0.48, 1.0),  # 2: Emerald
	Color(1.0, 0.78, 0.16, 1.0),   # 3: Gold
	Color(0.75, 0.36, 1.0, 1.0),   # 4: Violet
	Color(1.0, 0.48, 0.14, 1.0)    # 5: Blaze Orange
]

const TEAM_NAMES: Array[String] = [
	"Blue Team",
	"Red Team"
]

const BOT_DIFFICULTY_NAMES: Array[String] = [
	"Easy",
	"Mid",
	"Hard"
]

const TEST_BOT_BEHAVIORS: Array[String] = [
	"Still",
	"Move",
	"Fight"
]

var local_player_name: String = "Trooper"
var local_color_index: int = 0
var local_team: int = 0
var local_room_name: String = "Hotspot Arena"
var bot_count: int = 3
var bot_difficulty: int = 1      # 0 = Easy, 1 = Mid, 2 = Hard
var match_mode: int = 0         # 0 = Free-For-All, 1 = Red vs Blue
var selected_map_id: int = 0    # 0 = Bunker Base, 1 = Factory Ruins, 2 = Desert Outpost
var test_mode_enabled: bool = false
var test_bot_behavior: int = 0   # 0 = Still, 1 = Move, 2 = Fight
var test_bot_count: int = 1      # 1..MAX_BOTS in Test/Practice Mode

# Custom Game Rules / Mutators
var unlimited_jetpack: bool = false
var gravity_scale: float = 1.0
var only_pistols: bool = false
var allow_snipers: bool = true
var allow_shotguns: bool = true
var allow_explosives: bool = true

var players: Dictionary = {}
var discovered_servers: Dictionary = {}

var _udp_broadcaster: PacketPeerUDP = null
var _udp_listener: PacketPeerUDP = null
var _broadcast_timer: float = 0.0
var _is_listening_lan: bool = false


func _ready() -> void:
	randomize()
	_ensure_input_map()
	local_player_name = ProfileManager.player_name
	apply_rules_dict(SettingsManager.get_rules_dict())
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	ensure_offline_player()


func _process(delta: float) -> void:
	if is_host_active():
		_broadcast_timer += delta
		if _broadcast_timer >= 1.0:
			_broadcast_timer = 0.0
			_broadcast_lan_presence()

	if _is_listening_lan and _udp_listener != null:
		_poll_lan_packets()


func _exit_tree() -> void:
	stop_lan_discovery()
	_stop_broadcaster()


func _ensure_input_map() -> void:
	var key_bindings: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_W, KEY_UP],
		"crouch": [KEY_S, KEY_DOWN],
		"jetpack": [KEY_SPACE],
		"reload": [KEY_R],
		"switch_weapon": [KEY_Q],
		"toggle_dual_wield": [KEY_E],
		"open_lobby": [KEY_L],
		"ability_1": [KEY_Q, KEY_1],
		"ability_2": [KEY_E, KEY_2],
		"ability_3": [KEY_C, KEY_3],
		"ability_ult": [KEY_X, KEY_4],
		"throw_item": [KEY_F, KEY_G],
		"loadout_menu": [KEY_B],
		"taunt": [KEY_T]
	}
	for action_name in key_bindings.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		if InputMap.action_get_events(action_name).is_empty():
			for kc in key_bindings[action_name]:
				var ev := InputEventKey.new()
				ev.physical_keycode = kc
				InputMap.action_add_event(action_name, ev)

	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
	if InputMap.action_get_events("fire").is_empty():
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("fire", mb)


func is_network_active() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func is_host_active() -> bool:
	return is_network_active() and multiplayer.is_server()


func is_agent_clash_mode() -> bool:
	return match_mode == 2 or match_mode == 3


func is_team_mode() -> bool:
	return match_mode == 1 or match_mode == 3


func is_test_mode() -> bool:
	return test_mode_enabled


func get_team_color(color_index: int) -> Color:
	var idx: int = wrapi(color_index, 0, TEAM_COLORS.size())
	return TEAM_COLORS[idx]


func get_local_ips() -> PackedStringArray:
	var ips := PackedStringArray()
	for addr in IP.get_local_addresses():
		if addr.contains(":") or addr.begins_with("127.") or addr.begins_with("169.254."):
			continue
		if addr.is_valid_ip_address() and not ips.has(addr):
			ips.append(addr)
	if ips.is_empty():
		ips.append("127.0.0.1")
	return ips


func get_primary_local_ip() -> String:
	var ips := get_local_ips()
	for addr in ips:
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return ips[0]


func _build_local_player_dict(existing: Dictionary = {}) -> Dictionary:
	local_player_name = ProfileManager.player_name
	return {
		"name": local_player_name,
		"color_index": local_team if is_team_mode() else local_color_index,
		"team": local_team,
		"kills": int(existing.get("kills", 0)),
		"deaths": int(existing.get("deaths", 0)),
		"ready": true,
		"avatar": ProfileManager.to_dict()
	}


func ensure_offline_player() -> void:
	if not is_network_active() and players.is_empty():
		players[1] = _build_local_player_dict()


func sync_local_profile() -> void:
	var my_id: int = multiplayer.get_unique_id() if is_network_active() else 1
	var info: Dictionary = _build_local_player_dict(players.get(my_id, {}))
	if is_network_active():
		register_player.rpc(info)
	else:
		players[1] = info
		player_list_updated.emit()


func update_local_profile(player_name: String, color_idx: int) -> void:
	ProfileManager.player_name = player_name.strip_edges().left(16)
	if ProfileManager.player_name.is_empty():
		ProfileManager.player_name = "Trooper"
	ProfileManager.save_profile()
	local_player_name = ProfileManager.player_name
	local_color_index = wrapi(color_idx, 0, TEAM_COLORS.size())
	sync_local_profile()


func set_local_team(team_idx: int) -> void:
	local_team = clampi(team_idx, 0, 1)
	if is_network_active():
		set_player_team_rpc.rpc(local_team)
	else:
		if players.has(1):
			players[1]["team"] = local_team
			players[1]["color_index"] = local_team if is_team_mode() else local_color_index
		player_list_updated.emit()


@rpc("any_peer", "call_local", "reliable")
func set_player_team_rpc(team_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if players.has(sender_id):
		players[sender_id]["team"] = clampi(team_idx, 0, 1)
		if is_team_mode():
			players[sender_id]["color_index"] = clampi(team_idx, 0, 1)
		sync_all_players.rpc(players)


func host_update_match_settings(new_mode: int, new_map_id: int, new_bots: int, new_bot_diff: int = -1) -> void:
	match_mode = clampi(new_mode, 0, MODE_NAMES.size() - 1)
	selected_map_id = clampi(new_map_id, 0, MAP_NAMES.size() - 1)
	bot_count = clampi(new_bots, 0, MAX_BOTS)
	if new_bot_diff >= 0:
		bot_difficulty = clampi(new_bot_diff, 0, 2)
	if is_host_active():
		sync_match_settings_rpc.rpc(match_mode, selected_map_id, bot_count, bot_difficulty)
	else:
		match_settings_updated.emit()


@rpc("authority", "call_local", "reliable")
func sync_match_settings_rpc(new_mode: int, new_map_id: int, new_bots: int, new_bot_diff: int = 1) -> void:
	match_mode = clampi(new_mode, 0, MODE_NAMES.size() - 1)
	selected_map_id = clampi(new_map_id, 0, MAP_NAMES.size() - 1)
	bot_count = clampi(new_bots, 0, MAX_BOTS)
	bot_difficulty = clampi(new_bot_diff, 0, 2)
	match_settings_updated.emit()


func get_rules_dict() -> Dictionary:
	return {
		"unlimited_jetpack": unlimited_jetpack,
		"gravity_scale": clampf(gravity_scale, 0.0, 1.0),
		"only_pistols": only_pistols,
		"allow_snipers": allow_snipers,
		"allow_shotguns": allow_shotguns,
		"allow_explosives": allow_explosives
	}


func apply_rules_dict(rules: Dictionary) -> void:
	unlimited_jetpack = bool(rules.get("unlimited_jetpack", unlimited_jetpack))
	gravity_scale = clampf(float(rules.get("gravity_scale", gravity_scale)), 0.0, 1.0)
	only_pistols = bool(rules.get("only_pistols", only_pistols))
	allow_snipers = bool(rules.get("allow_snipers", allow_snipers))
	allow_shotguns = bool(rules.get("allow_shotguns", allow_shotguns))
	allow_explosives = bool(rules.get("allow_explosives", allow_explosives))
	game_rules_updated.emit()


func host_update_game_rules(rules: Dictionary) -> void:
	apply_rules_dict(rules)
	if is_host_active():
		sync_game_rules_rpc.rpc(get_rules_dict())


@rpc("authority", "call_local", "reliable")
func sync_game_rules_rpc(rules: Dictionary) -> void:
	apply_rules_dict(rules)


func host_game(room_name: String = "") -> Error:
	disconnect_network()
	if not room_name.strip_edges().is_empty():
		local_room_name = room_name.strip_edges().left(24)

	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(GAME_PORT, MAX_CLIENTS)
	if err != OK:
		connection_failed.emit("Failed to bind port %d (error %d)" % [GAME_PORT, err])
		return err

	multiplayer.multiplayer_peer = peer
	players.clear()
	players[1] = _build_local_player_dict()
	_start_broadcaster()
	player_list_updated.emit()
	connection_succeeded.emit()
	return OK


func join_game(ip_address: String) -> Error:
	disconnect_network()
	var target_ip: String = ip_address.strip_edges()
	if target_ip.is_empty():
		target_ip = "127.0.0.1"

	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(target_ip, GAME_PORT)
	if err != OK:
		connection_failed.emit("Could not connect to %s:%d (error %d)" % [target_ip, GAME_PORT, err])
		return err

	multiplayer.multiplayer_peer = peer
	players.clear()
	player_list_updated.emit()
	return OK


func disconnect_network() -> void:
	_stop_broadcaster()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	ensure_offline_player()
	player_list_updated.emit()


func start_lan_discovery() -> void:
	stop_lan_discovery()
	_udp_listener = PacketPeerUDP.new()
	_udp_listener.set_broadcast_enabled(true)
	var err: Error = _udp_listener.bind(DISCOVERY_PORT, "*")
	if err == OK:
		_is_listening_lan = true
	else:
		_udp_listener = null
		_is_listening_lan = false


func stop_lan_discovery() -> void:
	_is_listening_lan = false
	if _udp_listener != null:
		_udp_listener.close()
		_udp_listener = null
	discovered_servers.clear()


func _start_broadcaster() -> void:
	_stop_broadcaster()
	_udp_broadcaster = PacketPeerUDP.new()
	_udp_broadcaster.set_broadcast_enabled(true)
	_broadcast_timer = 0.8


func _stop_broadcaster() -> void:
	if _udp_broadcaster != null:
		_udp_broadcaster.close()
		_udp_broadcaster = null


func _broadcast_lan_presence() -> void:
	if _udp_broadcaster == null:
		return
	var host_ip: String = get_primary_local_ip()
	var payload := JSON.stringify({
		"app": "NamelessClash",
		"room": local_room_name,
		"host_ip": host_ip,
		"players": players.size(),
		"max": MAX_CLIENTS,
		"map": MAP_NAMES[selected_map_id],
		"mode": MODE_NAMES[match_mode],
		"port": GAME_PORT
	}).to_utf8_buffer()

	var targets: Array[String] = ["255.255.255.255"]
	for ip in get_local_ips():
		var parts := ip.split(".")
		if parts.size() == 4:
			var bcast: String = "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if not targets.has(bcast):
				targets.append(bcast)

	for dest in targets:
		_udp_broadcaster.set_dest_address(dest, DISCOVERY_PORT)
		_udp_broadcaster.put_packet(payload)


func _poll_lan_packets() -> void:
	var changed: bool = false
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	while _udp_listener.get_available_packet_count() > 0:
		var pkt: PackedByteArray = _udp_listener.get_packet()
		var sender_ip: String = _udp_listener.get_packet_ip()
		var parsed: Variant = JSON.parse_string(pkt.get_string_from_utf8())
		if parsed is Dictionary and parsed.get("app", "") == "NamelessClash":
			var ip: String = sender_ip if not sender_ip.is_empty() else str(parsed.get("host_ip", ""))
			if not ip.is_empty():
				discovered_servers[ip] = {
					"ip": ip,
					"room": str(parsed.get("room", "Hotspot Arena")),
					"players": int(parsed.get("players", 1)),
					"max": int(parsed.get("max", MAX_CLIENTS)),
					"map": str(parsed.get("map", MAP_NAMES[0])),
					"mode": str(parsed.get("mode", MODE_NAMES[0])),
					"last_seen": now_sec
				}
				changed = true

	var stale_keys: Array[String] = []
	for key in discovered_servers.keys():
		if now_sec - float(discovered_servers[key]["last_seen"]) > 4.0:
			stale_keys.append(key)
	for key in stale_keys:
		discovered_servers.erase(key)
		changed = true

	if changed:
		lan_servers_updated.emit(discovered_servers.values())


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		sync_all_players.rpc_id(peer_id, players)
		sync_match_settings_rpc.rpc_id(peer_id, match_mode, selected_map_id, bot_count, bot_difficulty)
		sync_game_rules_rpc.rpc_id(peer_id, get_rules_dict())


func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	player_list_updated.emit()
	if multiplayer.is_server():
		sync_all_players.rpc(players)


func _on_connected_to_server() -> void:
	register_player.rpc_id(1, _build_local_player_dict())
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	disconnect_network()
	connection_failed.emit("Connection timed out or refused by host.")


func _on_server_disconnected() -> void:
	disconnect_network()
	server_disconnected.emit()


@rpc("any_peer", "call_local", "reliable")
func register_player(info: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	var existing: Dictionary = players.get(sender_id, {})
	var default_team: int = (players.size() % 2) if not existing.has("team") else int(existing["team"])
	var avatar_dict: Dictionary = ProfileManager.sanitize_avatar(info.get("avatar", {}))
	players[sender_id] = {
		"name": str(info.get("name", "Trooper")).left(16),
		"color_index": int(info.get("color_index", sender_id % TEAM_COLORS.size())),
		"team": clampi(int(info.get("team", default_team)), 0, 1),
		"kills": int(existing.get("kills", 0)),
		"deaths": int(existing.get("deaths", 0)),
		"ready": bool(info.get("ready", true)),
		"avatar": avatar_dict
	}
	sync_all_players.rpc(players)


@rpc("authority", "call_local", "reliable")
func sync_all_players(all_players: Dictionary) -> void:
	players = all_players.duplicate(true)
	player_list_updated.emit()


func host_start_match() -> void:
	if is_host_active():
		start_match_rpc.rpc(bot_count, match_mode, selected_map_id, bot_difficulty, get_rules_dict())
	else:
		go_to_arena()


@rpc("authority", "call_local", "reliable")
func start_match_rpc(synced_bot_count: int, synced_mode: int, synced_map_id: int, synced_bot_diff: int = 1, synced_rules: Dictionary = {}) -> void:
	bot_count = synced_bot_count
	match_mode = clampi(synced_mode, 0, MODE_NAMES.size() - 1)
	selected_map_id = clampi(synced_map_id, 0, MAP_NAMES.size() - 1)
	bot_difficulty = clampi(synced_bot_diff, 0, 2)
	if not synced_rules.is_empty():
		apply_rules_dict(synced_rules)
	match_started.emit()
	go_to_arena()


func report_kill(killer_id: int, victim_id: int, weapon_name: String, killer_label: String, victim_label: String) -> void:
	if is_network_active():
		record_kill_rpc.rpc(killer_id, victim_id, weapon_name, killer_label, victim_label)
	else:
		_apply_kill(killer_id, victim_id, weapon_name, killer_label, victim_label)


@rpc("any_peer", "call_local", "reliable")
func record_kill_rpc(killer_id: int, victim_id: int, weapon_name: String, killer_label: String, victim_label: String) -> void:
	_apply_kill(killer_id, victim_id, weapon_name, killer_label, victim_label)


func _apply_kill(killer_id: int, victim_id: int, weapon_name: String, killer_label: String, victim_label: String) -> void:
	if killer_id != victim_id and players.has(killer_id):
		players[killer_id]["kills"] = int(players[killer_id].get("kills", 0)) + 1
	if players.has(victim_id):
		players[victim_id]["deaths"] = int(players[victim_id].get("deaths", 0)) + 1
	player_list_updated.emit()
	killfeed_event.emit(killer_label, victim_label, weapon_name)
	kill_scored.emit(killer_id, victim_id)


func send_chat_message(msg: String) -> void:
	var clean: String = msg.strip_edges().substr(0, 80)
	if clean.is_empty():
		return
	var sender: String = local_player_name
	if is_network_active():
		send_chat_rpc.rpc(sender, clean)
	else:
		chat_message_received.emit(sender, clean)


@rpc("any_peer", "call_local", "reliable")
func send_chat_rpc(sender_name: String, message: String) -> void:
	chat_message_received.emit(sender_name, message)


func toggle_interactable(inter_idx: int, new_state: bool) -> void:
	if is_network_active():
		toggle_interactable_rpc.rpc(inter_idx, new_state)
	else:
		interactable_toggled.emit(inter_idx, new_state)


@rpc("any_peer", "call_local", "reliable")
func toggle_interactable_rpc(inter_idx: int, new_state: bool) -> void:
	interactable_toggled.emit(inter_idx, new_state)


func go_to_arena() -> void:
	stop_lan_discovery()
	get_tree().change_scene_to_file("res://scenes/Arena.tscn")


func go_to_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func go_to_main_menu() -> void:
	stop_lan_discovery()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func go_to_avatar_garage() -> void:
	stop_lan_discovery()
	get_tree().change_scene_to_file("res://scenes/AvatarGarage.tscn")


func go_to_settings() -> void:
	stop_lan_discovery()
	get_tree().change_scene_to_file("res://scenes/SettingsMenu.tscn")
