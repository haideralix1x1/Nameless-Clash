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
signal barrel_detonated(inter_idx: int, attacker_id: int, attacker_name: String, attacker_team: int)
signal crate_consumed(crate_idx: int, next_val: int)
signal ult_pickup_relocated(ult_idx: int, new_pos: Vector2)
signal mine_event(action: String, mine_id: int, pos: Vector2)
signal match_timer_updated(time_left: float)
signal match_ended(winner_text: String, rankings: Array)
signal combo_achieved(killer_id: int, killer_name: String, combo_count: int)

const GAME_PORT: int = 44334
const DISCOVERY_PORT: int = 44335
const MAX_CLIENTS: int = 20
const MAX_BOTS: int = 10
const MIN_MATCH_MINUTES: int = 5
const MAX_MATCH_MINUTES: int = 20
const DEFAULT_MATCH_MINUTES: int = 5
const COMBO_WINDOW_SEC: float = 5.0

var match_duration_minutes: int = DEFAULT_MATCH_MINUTES
var match_time_left: float = float(DEFAULT_MATCH_MINUTES * 60)
var match_over: bool = false
var match_in_progress: bool = false
var _timer_sync_accum: float = 0.0

const MAP_NAMES: Array[String] = [
	"Bunker Base",
	"Factory Ruins",
	"Desert Outpost",
	"Dungeon",
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
	Color(1.0, 0.48, 0.14, 1.0),   # 5: Blaze Orange
	Color(0.20, 0.90, 0.90, 1.0),  # 6: Cyan
	Color(0.98, 0.42, 0.76, 1.0),  # 7: Pink
	Color(0.68, 0.96, 0.24, 1.0),  # 8: Lime
	Color(0.92, 0.92, 0.96, 1.0)   # 9: Silver
]

const TEAM_NAMES: Array[String] = [
	"Blue Team",
	"Red Team",
	"Emerald Team",
	"Gold Team",
	"Violet Team",
	"Orange Team",
	"Cyan Team",
	"Pink Team",
	"Lime Team",
	"Silver Team"
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
var test_bot_count: int = 6      # 1..MAX_BOTS in Test/Practice Mode

# Custom Game Rules / Mutators
var unlimited_jetpack: bool = false
var unlimited_abilities_practice: bool = true
var gravity_scale: float = 1.0
var only_pistols: bool = false
var allow_snipers: bool = true
var allow_shotguns: bool = true
var allow_explosives: bool = true
var restricted_weapons: Array = []
var max_room_players: int = 20
var team_count: int = 2
var leader_peer_id: int = 1

var players: Dictionary = {}
var bot_stats: Dictionary = {}
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


func is_unlimited_abilities_active() -> bool:
	return test_mode_enabled and unlimited_abilities_practice


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
		"assists": int(existing.get("assists", 0)),
		"deaths": int(existing.get("deaths", 0)),
		"combos": int(existing.get("combos", 0)),
		"max_combo": int(existing.get("max_combo", 0)),
		"combo_streak": int(existing.get("combo_streak", 0)),
		"combo_timer": float(existing.get("combo_timer", 0.0)),
		"ready": true,
		"avatar": ProfileManager.to_dict()
	}


func ensure_offline_player() -> void:
	if not is_network_active() and players.is_empty():
		players[1] = _build_local_player_dict()


func get_local_peer_id() -> int:
	if is_network_active() and multiplayer != null:
		return multiplayer.get_unique_id()
	return 1


func sync_local_profile() -> void:
	var my_id: int = get_local_peer_id()
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
	var max_t: int = maxi(1, team_count) - 1
	local_team = clampi(team_idx, 0, max_t)
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
	var max_t: int = maxi(1, team_count) - 1
	if players.has(sender_id):
		players[sender_id]["team"] = clampi(team_idx, 0, max_t)
		if is_team_mode():
			players[sender_id]["color_index"] = clampi(team_idx, 0, max_t)
		sync_all_players.rpc(players)


func set_local_ready(is_ready: bool) -> void:
	if is_network_active():
		set_player_ready_rpc.rpc_id(1, is_ready)
	elif players.has(1):
		players[1]["ready"] = is_ready
		player_list_updated.emit()


@rpc("any_peer", "call_local", "reliable")
func set_player_ready_rpc(is_ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if players.has(sender_id):
		players[sender_id]["ready"] = is_ready
		sync_all_players.rpc(players)


func is_local_leader() -> bool:
	return get_local_peer_id() == leader_peer_id


func transfer_leadership(target_pid: int) -> void:
	if not is_host_active() or not players.has(target_pid):
		return
	sync_leader_rpc.rpc(target_pid)


@rpc("authority", "call_local", "reliable")
func sync_leader_rpc(new_leader_id: int) -> void:
	leader_peer_id = new_leader_id
	player_list_updated.emit()


func request_start_match() -> void:
	if is_host_active():
		host_start_match()
	elif is_network_active() and is_local_leader():
		request_start_match_rpc.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func request_start_match_rpc() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
	if sender_id == leader_peer_id or sender_id == 1:
		host_start_match()


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
		"allow_explosives": allow_explosives,
		"restricted_weapons": restricted_weapons.duplicate(),
		"max_room_players": clampi(max_room_players, 2, MAX_CLIENTS),
		"team_count": clampi(team_count, 2, maxi(2, max_room_players / 2)),
		"match_duration_minutes": clampi(match_duration_minutes, MIN_MATCH_MINUTES, MAX_MATCH_MINUTES)
	}


func apply_rules_dict(rules: Dictionary) -> void:
	unlimited_jetpack = bool(rules.get("unlimited_jetpack", unlimited_jetpack))
	gravity_scale = clampf(float(rules.get("gravity_scale", gravity_scale)), 0.0, 1.0)
	only_pistols = bool(rules.get("only_pistols", only_pistols))
	allow_snipers = bool(rules.get("allow_snipers", allow_snipers))
	allow_shotguns = bool(rules.get("allow_shotguns", allow_shotguns))
	allow_explosives = bool(rules.get("allow_explosives", allow_explosives))
	if rules.has("restricted_weapons") and rules["restricted_weapons"] is Array:
		restricted_weapons = (rules["restricted_weapons"] as Array).duplicate()
	max_room_players = clampi(int(rules.get("max_room_players", max_room_players)), 2, MAX_CLIENTS)
	team_count = clampi(int(rules.get("team_count", team_count)), 2, maxi(2, max_room_players / 2))
	match_duration_minutes = clampi(int(rules.get("match_duration_minutes", match_duration_minutes)), MIN_MATCH_MINUTES, MAX_MATCH_MINUTES)
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
	bot_count = 0
	leader_peer_id = 1
	match_in_progress = false
	if not room_name.strip_edges().is_empty():
		local_room_name = room_name.strip_edges().left(24)

	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(GAME_PORT, clampi(max_room_players, 2, MAX_CLIENTS))
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
	match_in_progress = false
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
		"max": max_room_players,
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
		sync_leader_rpc.rpc_id(peer_id, leader_peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	if peer_id == leader_peer_id:
		leader_peer_id = 1
	player_list_updated.emit()
	if multiplayer.is_server():
		sync_all_players.rpc(players)
		sync_leader_rpc.rpc(leader_peer_id)


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
	var default_team: int = (players.size() % maxi(2, team_count)) if not existing.has("team") else int(existing["team"])
	var avatar_dict: Dictionary = ProfileManager.sanitize_avatar(info.get("avatar", {}))
	players[sender_id] = {
		"name": str(info.get("name", "Trooper")).left(16),
		"color_index": int(info.get("color_index", sender_id % TEAM_COLORS.size())),
		"team": clampi(int(info.get("team", default_team)), 0, maxi(1, team_count) - 1),
		"kills": int(existing.get("kills", 0)),
		"assists": int(existing.get("assists", 0)),
		"deaths": int(existing.get("deaths", 0)),
		"combos": int(existing.get("combos", 0)),
		"max_combo": int(existing.get("max_combo", 0)),
		"combo_streak": int(existing.get("combo_streak", 0)),
		"combo_timer": float(existing.get("combo_timer", 0.0)),
		"ready": bool(info.get("ready", true)),
		"avatar": avatar_dict
	}
	sync_all_players.rpc(players)
	if match_in_progress and sender_id != 1:
		start_match_rpc.rpc_id(sender_id, bot_count, match_mode, selected_map_id, bot_difficulty, get_rules_dict())


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
	match_in_progress = true
	bot_count = synced_bot_count
	match_mode = clampi(synced_mode, 0, MODE_NAMES.size() - 1)
	selected_map_id = clampi(synced_map_id, 0, MAP_NAMES.size() - 1)
	bot_difficulty = clampi(synced_bot_diff, 0, 2)
	if not synced_rules.is_empty():
		apply_rules_dict(synced_rules)
	match_started.emit()
	go_to_arena()


func report_kill(killer_id: int, victim_id: int, weapon_name: String, killer_label: String, victim_label: String, assist_ids: Array = []) -> void:
	if is_network_active():
		record_kill_rpc.rpc(killer_id, victim_id, weapon_name, killer_label, victim_label, assist_ids)
	else:
		_apply_kill(killer_id, victim_id, weapon_name, killer_label, victim_label, assist_ids)


@rpc("any_peer", "call_local", "reliable")
func record_kill_rpc(killer_id: int, victim_id: int, weapon_name: String, killer_label: String, victim_label: String, assist_ids: Array = []) -> void:
	_apply_kill(killer_id, victim_id, weapon_name, killer_label, victim_label, assist_ids)


func clear_bot_stats() -> void:
	bot_stats.clear()


func register_bot_stat(bot_id: int, bot_name: String, bot_team: int) -> void:
	bot_stats[bot_id] = {
		"name": bot_name,
		"team": bot_team,
		"is_bot": true,
		"kills": 0,
		"assists": 0,
		"deaths": 0,
		"combos": 0,
		"max_combo": 0,
		"combo_streak": 0,
		"combo_timer": 0.0
	}


func unregister_bot_stat(bot_id: int) -> void:
	bot_stats.erase(bot_id)


func _get_participant_stats(pid: int) -> Dictionary:
	if players.has(pid):
		return players[pid]
	if bot_stats.has(pid):
		return bot_stats[pid]
	return {}


func _apply_kill(killer_id: int, victim_id: int, weapon_name: String, killer_label: String, victim_label: String, assist_ids: Array = []) -> void:
	var kp: Dictionary = _get_participant_stats(killer_id)
	if killer_id != victim_id and not kp.is_empty():
		kp["kills"] = int(kp.get("kills", 0)) + 1
		var c_timer: float = float(kp.get("combo_timer", 0.0))
		var streak: int = (int(kp.get("combo_streak", 0)) + 1) if c_timer > 0.0 else 1
		kp["combo_streak"] = streak
		kp["combo_timer"] = COMBO_WINDOW_SEC
		if streak >= 2:
			kp["max_combo"] = maxi(int(kp.get("max_combo", 0)), streak)
			kp["combos"] = int(kp["max_combo"])
			combo_achieved.emit(killer_id, killer_label, streak)
	for raw_aid in assist_ids:
		var aid: int = int(raw_aid)
		var ap: Dictionary = _get_participant_stats(aid)
		if aid != killer_id and aid != victim_id and not ap.is_empty():
			ap["assists"] = int(ap.get("assists", 0)) + 1
	var vp: Dictionary = _get_participant_stats(victim_id)
	if not vp.is_empty():
		vp["deaths"] = int(vp.get("deaths", 0)) + 1
		vp["combo_streak"] = 0
		vp["combo_timer"] = 0.0
	player_list_updated.emit()
	killfeed_event.emit(killer_label, victim_label, weapon_name)
	kill_scored.emit(killer_id, victim_id)


func reset_match_state() -> void:
	var mins: int = clampi(match_duration_minutes, MIN_MATCH_MINUTES, MAX_MATCH_MINUTES)
	match_time_left = float(mins * 60)
	match_over = false
	_timer_sync_accum = 0.0
	for pid in players.keys():
		players[pid]["kills"] = 0
		players[pid]["assists"] = 0
		players[pid]["deaths"] = 0
		players[pid]["combos"] = 0
		players[pid]["max_combo"] = 0
		players[pid]["combo_streak"] = 0
		players[pid]["combo_timer"] = 0.0
	for bid in bot_stats.keys():
		bot_stats[bid]["kills"] = 0
		bot_stats[bid]["assists"] = 0
		bot_stats[bid]["deaths"] = 0
		bot_stats[bid]["combos"] = 0
		bot_stats[bid]["max_combo"] = 0
		bot_stats[bid]["combo_streak"] = 0
		bot_stats[bid]["combo_timer"] = 0.0
	player_list_updated.emit()
	match_timer_updated.emit(match_time_left)


func tick_match_timer(delta: float) -> void:
	if match_over or is_test_mode():
		return
	for pid in players.keys():
		var ct: float = float(players[pid].get("combo_timer", 0.0))
		if ct > 0.0:
			ct = maxf(0.0, ct - delta)
			players[pid]["combo_timer"] = ct
			if ct <= 0.0:
				players[pid]["combo_streak"] = 0
	for bid in bot_stats.keys():
		var bct: float = float(bot_stats[bid].get("combo_timer", 0.0))
		if bct > 0.0:
			bct = maxf(0.0, bct - delta)
			bot_stats[bid]["combo_timer"] = bct
			if bct <= 0.0:
				bot_stats[bid]["combo_streak"] = 0
	if is_network_active() and not is_host_active():
		return
	match_time_left = maxf(0.0, match_time_left - delta)
	match_timer_updated.emit(match_time_left)
	_timer_sync_accum += delta
	if is_network_active() and is_host_active() and _timer_sync_accum >= 0.5:
		_timer_sync_accum = 0.0
		sync_match_timer_rpc.rpc(match_time_left)
	if match_time_left <= 0.0:
		finish_match()


@rpc("authority", "call_remote", "unreliable")
func sync_match_timer_rpc(t_left: float) -> void:
	match_time_left = t_left
	match_timer_updated.emit(match_time_left)


func get_sorted_rankings() -> Array:
	var rows: Array = []
	for pid in players.keys():
		var d: Dictionary = players[pid].duplicate()
		d["peer_id"] = pid
		d["is_bot"] = false
		rows.append(d)
	for bid in bot_stats.keys():
		var bd: Dictionary = bot_stats[bid].duplicate()
		bd["peer_id"] = bid
		bd["is_bot"] = true
		rows.append(bd)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka: int = int(a.get("kills", 0))
		var kb: int = int(b.get("kills", 0))
		if ka != kb:
			return ka > kb
		var aa: int = int(a.get("assists", 0))
		var ab: int = int(b.get("assists", 0))
		if aa != ab:
			return aa > ab
		var da: int = int(a.get("deaths", 0))
		var db: int = int(b.get("deaths", 0))
		if da != db:
			return da < db
		var ca: int = int(a.get("combos", 0))
		var cb: int = int(b.get("combos", 0))
		if ca != cb:
			return ca > cb
		return int(a.get("max_combo", 0)) > int(b.get("max_combo", 0))
	)
	return rows


func finish_match() -> void:
	if match_over:
		return
	var rankings: Array = get_sorted_rankings()
	var winner_text: String = "MATCH COMPLETE!"
	if not rankings.is_empty():
		var top: Dictionary = rankings[0]
		var tied: bool = false
		if rankings.size() > 1:
			var s: Dictionary = rankings[1]
			if int(top.get("kills", 0)) == int(s.get("kills", 0)) and int(top.get("assists", 0)) == int(s.get("assists", 0)) and int(top.get("deaths", 0)) == int(s.get("deaths", 0)) and int(top.get("combos", 0)) == int(s.get("combos", 0)):
				tied = true
		winner_text = "DRAW!" if tied else ("%s WINS!" % str(top.get("name", "Player")).to_upper())
	if is_network_active():
		end_match_rpc.rpc(winner_text, rankings)
	else:
		_apply_match_end(winner_text, rankings)


@rpc("authority", "call_local", "reliable")
func end_match_rpc(winner_text: String, rankings: Array) -> void:
	_apply_match_end(winner_text, rankings)


func _apply_match_end(winner_text: String, rankings: Array) -> void:
	if match_over:
		return
	match_over = true
	match_in_progress = false
	match_time_left = 0.0
	match_timer_updated.emit(0.0)
	match_ended.emit(winner_text, rankings)


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


func detonate_barrel(inter_idx: int, attacker_id: int, attacker_name: String, attacker_team: int) -> void:
	if is_network_active():
		detonate_barrel_rpc.rpc(inter_idx, attacker_id, attacker_name, attacker_team)
	else:
		barrel_detonated.emit(inter_idx, attacker_id, attacker_name, attacker_team)


@rpc("any_peer", "call_local", "reliable")
func detonate_barrel_rpc(inter_idx: int, attacker_id: int, attacker_name: String, attacker_team: int) -> void:
	barrel_detonated.emit(inter_idx, attacker_id, attacker_name, attacker_team)


func consume_crate(crate_idx: int, next_val: int) -> void:
	if is_network_active():
		consume_crate_rpc.rpc(crate_idx, next_val)
	else:
		crate_consumed.emit(crate_idx, next_val)


@rpc("any_peer", "call_local", "reliable")
func consume_crate_rpc(crate_idx: int, next_val: int) -> void:
	crate_consumed.emit(crate_idx, next_val)


func relocate_ult_pickup(ult_idx: int, new_pos: Vector2) -> void:
	if is_network_active():
		relocate_ult_pickup_rpc.rpc(ult_idx, new_pos)
	else:
		ult_pickup_relocated.emit(ult_idx, new_pos)


@rpc("any_peer", "call_local", "reliable")
func relocate_ult_pickup_rpc(ult_idx: int, new_pos: Vector2) -> void:
	ult_pickup_relocated.emit(ult_idx, new_pos)


func sync_mine_event(action: String, mine_id: int, pos: Vector2) -> void:
	if is_network_active():
		if is_host_active():
			sync_mine_event_rpc.rpc(action, mine_id, pos)
	else:
		mine_event.emit(action, mine_id, pos)


@rpc("authority", "call_local", "reliable")
func sync_mine_event_rpc(action: String, mine_id: int, pos: Vector2) -> void:
	mine_event.emit(action, mine_id, pos)


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
