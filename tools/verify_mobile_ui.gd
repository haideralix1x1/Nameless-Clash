extends SceneTree

const AgentDataScript = preload("res://scripts/AgentData.gd")
const WeaponDataScript = preload("res://scripts/Weapon.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_checks")


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		push_error("VERIFY FAIL: " + msg)


func _collect_png_files(dir_path: String, out_files: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		_assert(false, "Cannot open directory: " + dir_path)
		return
	d.list_dir_begin()
	var name: String = d.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = d.get_next()
			continue
		var full_path: String = dir_path.path_join(name)
		if d.current_is_dir():
			_collect_png_files(full_path, out_files)
		elif name.to_lower().ends_with(".png"):
			out_files.append(full_path)
		name = d.get_next()
	d.list_dir_end()


func _find_descendant_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for c in node.get_children():
		var found: Node = _find_descendant_by_name(c, target_name)
		if found != null:
			return found
	return null


func _find_first_tab_container(node: Node) -> TabContainer:
	if node is TabContainer:
		return node as TabContainer
	for c in node.get_children():
		var found := _find_first_tab_container(c)
		if found != null:
			return found
	return null


func _run_checks() -> void:
	var nm: Node = root.get_node_or_null("NetworkManager")
	var sm: Node = root.get_node_or_null("SettingsManager")
	var pm: Node = root.get_node_or_null("ProfileManager")
	_assert(nm != null and sm != null and pm != null, "Autoloads NetworkManager/SettingsManager/ProfileManager missing")
	if nm == null or sm == null:
		quit(1)
		return

	var saved_rules: Dictionary = nm.get_rules_dict()
	var saved_mode: int = int(nm.match_mode)

	# 1. File size audit (< 5 KB = 5120 bytes)
	var pngs: Array[String] = []
	_collect_png_files("res://assets/sprites/modular", pngs)
	_collect_png_files("res://assets/Layer Lab", pngs)
	_assert(pngs.size() >= 144, "Expected at least 144 modular + UI PNGs, found %d" % pngs.size())
	var max_bytes: int = 0
	var over_5kb: Array[String] = []
	for p in pngs:
		var fa := FileAccess.open(p, FileAccess.READ)
		if fa == null:
			_assert(false, "Failed to open PNG: " + p)
			continue
		var sz: int = int(fa.get_length())
		fa.close()
		if sz > max_bytes:
			max_bytes = sz
		if sz >= 5120:
			over_5kb.append("%s (%d B)" % [p, sz])
	_assert(over_5kb.is_empty(), "PNG files >= 5120 B: " + ", ".join(over_5kb))
	print("CHECK 1 PNG SIZE AUDIT: checked=%d max_bytes=%d over_5kb=%d" % [pngs.size(), max_bytes, over_5kb.size()])

	# 2. AgentData: 24 unique kits, Ignis all fire, stun bombs
	var agents: Array = AgentDataScript.AGENTS
	_assert(agents.size() == 24, "Expected 24 Agents in AgentData, got %d" % agents.size())
	_assert(AgentDataScript.THROWABLE_ITEMS.size() == 7, "Expected 7 THROWABLE_ITEMS, got %d" % AgentDataScript.THROWABLE_ITEMS.size())
	var shoe_item: Dictionary = AgentDataScript.get_throwable(5)
	var stone_item: Dictionary = AgentDataScript.get_throwable(6)
	_assert(str(shoe_item.get("name", "")) == "Heavy Combat Shoe" and str(shoe_item.get("style", "")) == "thrown_shoe", "Throwable 5 should be Heavy Combat Shoe")
	_assert(str(stone_item.get("name", "")) == "Jagged Boulder Stone" and str(stone_item.get("style", "")) == "thrown_stone", "Throwable 6 should be Jagged Boulder Stone")
	var ignis: Dictionary = AgentDataScript.get_agent(21)
	_assert(str(ignis.get("agent_name", "")) == "Ignis", "Expected agent 21 to be Ignis")
	var ignis_abils: Array = ignis.get("abilities", [])
	_assert(ignis_abils.size() == 3, "Ignis must have 3 abilities")
	_assert(str(ignis_abils[0].get("kind", "")) == "fireball", "Ignis [Q] should be fireball")
	_assert(str(ignis_abils[1].get("kind", "")) == "flame_wave", "Ignis [E] should be flame_wave")
	_assert(str(ignis_abils[2].get("kind", "")) == "lava_bomb", "Ignis [C] should be lava_bomb")
	_assert(str(ignis.get("ultimate", {}).get("kind", "")) == "ult_firestorm", "Ignis Ult should be ult_firestorm")

	var non_dmg_kinds: Array[String] = ["block", "speed", "wall", "decoy", "heal", "stealth", "berserk", "teleport"]
	var stun_bomb_count: int = 0
	for ag in agents:
		var abils: Array = ag.get("abilities", [])
		_assert(abils.size() == 3, "Agent %s does not have 3 abilities" % str(ag.get("agent_name", "?")))
		for ab in abils:
			var kind: String = str(ab.get("kind", ""))
			if not non_dmg_kinds.has(kind):
				_assert(int(ab.get("damage", 0)) > 0, "Combat ability %s has zero damage" % str(ab.get("name", kind)))
			if kind == "stun_bomb" or kind == "lava_bomb":
				stun_bomb_count += 1
				var desc_l: String = str(ab.get("desc", "")).to_lower()
				_assert("bomb" in desc_l and "stun" in desc_l, "Stun bomb ability description unclear: " + desc_l)
	_assert(stun_bomb_count >= 1, "Expected at least 1 stun_bomb/lava_bomb stun ability")
	print("CHECK 2 AGENT DATA: agents=%d ignis_verified=true stun_bomb_abilities=%d" % [agents.size(), stun_bomb_count])

	# 3. PlayerController.apply_stun self-immunity & enemy stun
	nm.match_mode = 2
	var player_scene := load("res://scenes/Player.tscn") as PackedScene
	_assert(player_scene != null, "Failed to load res://scenes/Player.tscn")
	if player_scene != null:
		var p_node: Node = player_scene.instantiate()
		p_node.set("peer_id", 1)
		root.add_child(p_node)
		await process_frame
		p_node.apply_stun(2.0, 1)
		_assert(float(p_node.get("stun_timer")) == 0.0, "Player stunned self! stun_timer=%s" % str(p_node.get("stun_timer")))
		p_node.apply_stun(2.0, 2)
		_assert(float(p_node.get("stun_timer")) >= 1.9, "Enemy stun failed! stun_timer=%s" % str(p_node.get("stun_timer")))
		p_node.queue_free()
		await process_frame
	print("CHECK 3 STUN SELF-IMMUNITY & ENEMY STUN: ok")

	# 3B. 3-Player Grab & Throw Collision (shoe/stone + grabbing negative-ID bot and throwing onto 3rd player)
	if player_scene != null:
		nm.match_mode = 2
		nm.apply_rules_dict({"gravity_scale": 0.0})
		var p1: Node = player_scene.instantiate()
		var p2: Node = player_scene.instantiate()
		var p3: Node = player_scene.instantiate()
		p1.set("peer_id", 1)
		p1.set("is_local_human", true)
		p1.set("team_id", 0)
		p1.set("position", Vector2(400, 500))
		p1.set("spawn_invuln_timer", 0.0)
		p2.set("peer_id", -1)
		p2.set("is_bot", true)
		p2.set("team_id", 1)
		p2.set("position", Vector2(450, 500))
		p2.set("spawn_invuln_timer", 0.0)
		p2.set("_bot_think_timer", 5.0)
		p2.set("_bot_allow_fire", false)
		p2.set("_bot_want_jetpack", false)
		p2.set("_bot_strafe_dir", 0.0)
		p3.set("peer_id", -2)
		p3.set("is_bot", true)
		p3.set("team_id", 1)
		p3.set("position", Vector2(540, 500))
		p3.set("spawn_invuln_timer", 0.0)
		p3.set("_bot_think_timer", 5.0)
		p3.set("_bot_allow_fire", false)
		p3.set("_bot_want_jetpack", false)
		p3.set("_bot_strafe_dir", 0.0)
		root.add_child(p1)
		root.add_child(p2)
		root.add_child(p3)
		await process_frame
		p1.global_position = Vector2(400, 500)
		p2.global_position = Vector2(450, 500)
		p3.global_position = Vector2(540, 500)
		p1.set("health", 100)
		p2.set("health", 100)
		p3.set("health", 100)
		p1.set("spawn_invuln_timer", 0.0)
		p2.set("spawn_invuln_timer", 0.0)
		p3.set("spawn_invuln_timer", 0.0)
		p2.set("_bot_think_timer", 5.0)
		p2.set("_bot_allow_fire", false)
		p3.set("_bot_think_timer", 5.0)
		p3.set("_bot_allow_fire", false)
		p1.throw_held_item()
		_assert(int(p1.get("grabbed_player_id")) == -1, "p1 failed to grab p2 (-1), got %s" % str(p1.get("grabbed_player_id")))
		_assert(int(p2.get("carried_by_peer_id")) == 1, "p2 carried_by_peer_id expected 1, got %s" % str(p2.get("carried_by_peer_id")))
		p3.global_position = Vector2(540, 500)
		p3.set("velocity", Vector2.ZERO)
		p1.set("aim_angle", 0.0)
		p1.throw_held_item()
		_assert(int(p1.get("grabbed_player_id")) == 0, "p1 failed to release p2 on throw")
		_assert(int(p2.get("carried_by_peer_id")) == 0, "p2 carried_by_peer_id should reset on throw")
		for _step in range(20):
			await physics_frame
			if float(p2.get("thrown_flight_timer")) <= 0.0:
				break
		_assert(int(p2.get("health")) == 64, "Thrown player p2 expected hp=64 (100-36), got %s/%s" % [str(p2.get("health")), str(p2.get("max_health"))])
		_assert(int(p3.get("health")) == 56, "Hit player p3 expected hp=56 (100-44), got %s/%s" % [str(p3.get("health")), str(p3.get("max_health"))])
		_assert(int(p1.get("health")) == 100, "Thrower p1 should stay unharmed (hp=100), got %s/%s" % [str(p1.get("health")), str(p1.get("max_health"))])
		p1.queue_free()
		p2.queue_free()
		p3.queue_free()
		await process_frame
		await process_frame
		nm.apply_rules_dict(saved_rules)
	nm.match_mode = saved_mode
	print("CHECK 3B GRAB & THROW PLAYER (3-PLAYER COLLISION): ok")

	# 4. WeaponData.GUN_PRESETS & Game Rules filtering
	_assert(WeaponDataScript.GUN_PRESETS.size() == 6, "Expected 6 GUN_PRESETS")
	nm.apply_rules_dict({
		"unlimited_jetpack": true,
		"gravity_scale": 0.35,
		"only_pistols": true,
		"allow_snipers": false,
		"allow_shotguns": false,
		"allow_explosives": false
	})
	_assert(bool(nm.unlimited_jetpack) == true, "unlimited_jetpack did not apply")
	_assert(absf(float(nm.gravity_scale) - 0.35) < 0.01, "gravity_scale did not clamp/apply")
	var pistol_preset: Dictionary = WeaponDataScript.get_effective_preset(0)
	_assert(int(pistol_preset["primary"]) == 9 and int(pistol_preset["secondary"]) == 9, "only_pistols failed to force Glock 17")
	_assert(int(pistol_preset["bombs"]) == 0, "allow_explosives=false failed to zero bombs")

	nm.apply_rules_dict({
		"unlimited_jetpack": false,
		"gravity_scale": 1.0,
		"only_pistols": false,
		"allow_snipers": false,
		"allow_shotguns": false,
		"allow_explosives": false
	})
	_assert(not WeaponDataScript.is_weapon_allowed(7) and not WeaponDataScript.is_weapon_allowed(8), "Snipers should be disallowed")
	_assert(not WeaponDataScript.is_weapon_allowed(5) and not WeaponDataScript.is_weapon_allowed(6), "Shotguns should be disallowed")
	_assert(not WeaponDataScript.is_weapon_allowed(10), "RPG should be disallowed")
	var sniper_preset: Dictionary = WeaponDataScript.get_effective_preset(4)
	_assert(int(sniper_preset["primary"]) != 7 and int(sniper_preset["secondary"]) != 8, "Sniper preset should be filtered")
	print("CHECK 4 GUN PRESETS & RULES FILTERING: ok")

	# 5. Scene & HUD UI instantiation + cleanup
	var scene_paths: Array[String] = [
		"res://scenes/MainMenu.tscn",
		"res://scenes/AvatarGarage.tscn",
		"res://scenes/SettingsMenu.tscn",
		"res://scenes/Lobby.tscn"
	]
	for sp in scene_paths:
		var ps := load(sp) as PackedScene
		_assert(ps != null, "Failed to load scene: " + sp)
		if ps == null:
			continue
		var inst: Node = ps.instantiate()
		root.add_child(inst)
		await process_frame
		if sp.ends_with("SettingsMenu.tscn"):
			var tc: TabContainer = _find_first_tab_container(inst)
			_assert(tc != null and _find_descendant_by_name(tc, "Game Rules") != null, "SettingsMenu missing Game Rules tab")
		inst.queue_free()
		await process_frame

	# Verify HUD.gd directly
	var hud_script := load("res://scripts/HUD.gd") as GDScript
	_assert(hud_script != null, "Failed to load scripts/HUD.gd")
	if hud_script != null:
		nm.match_mode = 0
		nm.apply_rules_dict({"unlimited_jetpack": true})
		var hud: CanvasLayer = hud_script.new() as CanvasLayer
		root.add_child(hud)
		await process_frame
		hud.call("_on_fuel_changed", 50.0, 100.0)
		var fuel_lbl: Label = hud.get("_fuel_label") as Label
		_assert(fuel_lbl != null and "∞" in fuel_lbl.text, "HUD jetpack infinity label missing: %s" % (fuel_lbl.text if fuel_lbl else "null"))
		hud.call("_open_preset_selector", 10.0)
		var overlay: Control = hud.get("_preset_overlay") as Control
		_assert(overlay != null and overlay.visible, "HUD preset selector overlay did not open")
		hud.queue_free()
		await process_frame

	# Verify Arena.tscn in Gunfight & Agent Clash
	for mode_val in [0, 2]:
		nm.match_mode = mode_val
		var arena_ps := load("res://scenes/Arena.tscn") as PackedScene
		_assert(arena_ps != null, "Failed to load Arena.tscn")
		if arena_ps != null:
			var arena_inst: Node = arena_ps.instantiate()
			root.add_child(arena_inst)
			await process_frame
			arena_inst.queue_free()
			await process_frame

	# Restore rules cleanly
	nm.match_mode = saved_mode
	nm.apply_rules_dict(saved_rules)

	await process_frame
	await process_frame

	if _failures.is_empty():
		print("ALL_VERIFY_MOBILE_UI_CHECKS_PASSED")
		quit(0)
	else:
		print("VERIFY_MOBILE_UI_FAILED count=%d" % _failures.size())
		quit(1)
