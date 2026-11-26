extends Node

signal achievement_unlocked(ach_id: String, title: String)
signal achievements_changed

const CONFIG_PATH: String = "res://assets/data/achievements_config.json"
const USER_CONFIG_PATH: String = "user://achievements_config.json"
const SAVE_PATH: String = "user://achievements_progress.cfg"

# Ordered list of all 100 achievement definitions
var definitions: Array[Dictionary] = []
var _def_by_id: Dictionary = {}
# Persistent player stats & claim state
var stats: Dictionary = {}
var claimed: Dictionary = {}
var notified: Dictionary = {}


func _ready() -> void:
	_build_default_100()
	load_config()
	load_progress()
	call_deferred("_sync_derived_stats")


func _add_ach(id: String, title: String, desc: String, category: String, stat_key: String, target: int, reward_coins: int, parent_id: String = "", reward_skin: String = "", exclusive_skin: bool = false) -> void:
	var d: Dictionary = {
		"id": id,
		"title": title,
		"desc": desc,
		"category": category,
		"parent": parent_id,
		"stat": stat_key,
		"target": target,
		"reward_coins": reward_coins,
		"reward_skin": reward_skin,
		"exclusive_skin": exclusive_skin
	}
	definitions.append(d)
	_def_by_id[id] = d


func _build_default_100() -> void:
	definitions.clear()
	_def_by_id.clear()

	# 1. BLAST 500 (6: 1 Main + 5 Subs)
	_add_ach("blast_500", "Blast 500", "Master all 5 explosives — score 500 total explosive kills.", "Blast 500", "blast_total", 500, 2500, "", "0:gold", true)
	_add_ach("blast_frag_100", "Frag Grenadier", "Kill 100 enemies with Frag Grenades.", "Blast 500", "bomb_kill_frag", 100, 400, "blast_500")
	_add_ach("blast_time_100", "Ticking Time", "Kill 100 enemies with Time Bombs.", "Blast 500", "bomb_kill_time", 100, 400, "blast_500")
	_add_ach("blast_mine_100", "Minefield Expert", "Kill 100 enemies with Proximity Mines.", "Blast 500", "bomb_kill_mine", 100, 400, "blast_500")
	_add_ach("blast_sticky_100", "Sticky Situation", "Kill 100 enemies with Sticky Bombs.", "Blast 500", "bomb_kill_sticky", 100, 400, "blast_500")
	_add_ach("blast_cluster_100", "Cluster Storm", "Kill 100 enemies with Cluster Bombs.", "Blast 500", "bomb_kill_cluster", 100, 400, "blast_500")

	# 2. GUNMASTER (17: 1 Main + 16 Subs)
	_add_ach("gun_master", "GunMaster", "Complete all 16 GunMaster weapon sub-achievements.", "GunMaster", "gunmaster_subs_done", 16, 5000, "", "23:nebula", true)
	var gm_guns: Array[Array] = [
		[0, "AK47"], [1, "M16A4"], [2, "SCAR-L"], [3, "SMG"],
		[4, "Uzi"], [5, "Shotgun"], [6, "Pump Shotgun"], [7, "Sniper"],
		[8, "Auto Sniper"], [9, "Glock 21"], [10, "Bazooka"], [11, "Flamethrower"],
		[13, "Plasma Cannon"], [18, "Nade Gun"], [20, "Suppressed Pistol"], [23, "M416"]
	]
	for g in gm_guns:
		var wid: int = int(g[0])
		var wname: String = str(g[1])
		_add_ach("gun_kill_%d" % wid, "%s Master" % wname, "Kill 100 enemies with %s." % wname, "GunMaster", "weapon_kill_%d" % wid, 100, 350, "gun_master")

	# 3. AGENTS (19)
	_add_ach("unlock_agents_1", "New Recruit", "Unlock 1 locked Agent with NC.", "Agents", "unlocked_agents_count", 1, 250)
	_add_ach("unlock_agents_3", "Squad Builder", "Unlock 3 locked Agents with NC.", "Agents", "unlocked_agents_count", 3, 600)
	_add_ach("unlock_agents_5", "Elite Roster", "Unlock 5 locked Agents with NC.", "Agents", "unlocked_agents_count", 5, 1000)
	_add_ach("unlock_agents_10", "Commander", "Unlock 10 locked Agents with NC.", "Agents", "unlocked_agents_count", 10, 2000)
	_add_ach("unlock_agents_all", "Full Assembly", "Unlock all 14 locked Agents.", "Agents", "unlocked_agents_count", 14, 3500)
	_add_ach("unlock_wraith", "Soul Reaper", "Unlock Wraith.", "Agents", "unlocked_agent_10", 1, 300)
	_add_ach("unlock_ignis", "Volcanic Fury", "Unlock Ignis.", "Agents", "unlocked_agent_17", 1, 300)
	_add_ach("unlock_draken", "Night Lord", "Unlock Draken.", "Agents", "unlocked_agent_6", 1, 300)
	_add_ach("unlock_yagami", "Shadow Shinobi", "Unlock Yagami.", "Agents", "unlocked_agent_7", 1, 300)
	_add_ach("unlock_raven", "Corvus Mystic", "Unlock Raven.", "Agents", "unlocked_agent_20", 1, 300)
	_add_ach("unlock_soulless", "Phantom Menace", "Unlock Soulless.", "Agents", "unlocked_agent_3", 1, 300)
	_add_ach("unlock_pharaoh", "Ancient Curse", "Unlock Pharaoh.", "Agents", "unlocked_agent_11", 1, 300)
	_add_ach("agent_kills_50", "Agent Initiate", "Score 50 kills in Agent Clash mode.", "Agents", "agent_mode_kills", 50, 300)
	_add_ach("agent_kills_200", "Agent Veteran", "Score 200 kills in Agent Clash mode.", "Agents", "agent_mode_kills", 200, 800)
	_add_ach("agent_kills_500", "Agent Legend", "Score 500 kills in Agent Clash mode.", "Agents", "agent_mode_kills", 500, 3000, "", "7:magma", true)
	_add_ach("ult_use_25", "Ultimate Surge", "Use Ultimate abilities 25 times.", "Agents", "ult_uses", 25, 250)
	_add_ach("ult_use_100", "Ultimate Force", "Use Ultimate abilities 100 times.", "Agents", "ult_uses", 100, 600)
	_add_ach("ult_use_500", "Ultimate Overlord", "Use Ultimate abilities 500 times.", "Agents", "ult_uses", 500, 2000)
	_add_ach("ability_use_250", "Skill Tactician", "Use Agent abilities 250 times.", "Agents", "ability_uses", 250, 500)

	# 4. COMBAT, COMBOS & SINGLE-MATCH FEATS (20)
	_add_ach("total_kills_10", "First Blood x10", "Eliminate 10 enemies total.", "Combat", "total_kills", 10, 100)
	_add_ach("total_kills_50", "Skirmisher", "Eliminate 50 enemies total.", "Combat", "total_kills", 50, 200)
	_add_ach("total_kills_100", "Centurion", "Eliminate 100 enemies total.", "Combat", "total_kills", 100, 350)
	_add_ach("total_kills_250", "Sharpshooter", "Eliminate 250 enemies total.", "Combat", "total_kills", 250, 600)
	_add_ach("total_kills_500", "War Machine", "Eliminate 500 enemies total.", "Combat", "total_kills", 500, 1000)
	_add_ach("total_kills_1000", "Executioner", "Eliminate 1,000 enemies total.", "Combat", "total_kills", 1000, 1800)
	_add_ach("total_kills_2500", "Apex Predator", "Eliminate 2,500 enemies total.", "Combat", "total_kills", 2500, 3000)
	_add_ach("total_kills_5000", "Nameless Champion", "Eliminate 5,000 enemies total.", "Combat", "total_kills", 5000, 5000)
	_add_ach("combo_3", "Triple Threat", "Get a 3x kill combo.", "Combat", "best_combo", 3, 150)
	_add_ach("combo_5", "5x Unstoppable", "Get a 5x kill combo.", "Combat", "best_combo", 5, 400)
	_add_ach("combo_10", "10x Rampage", "Get a 10x kill combo.", "Combat", "best_combo", 10, 1200)
	_add_ach("combo_15", "15x Immortal", "Get a 15x kill combo.", "Combat", "best_combo", 15, 2500)
	_add_ach("match_kills_10", "Warmup Match", "Kill 10 enemies in 1 game.", "Combat", "best_match_kills", 10, 150)
	_add_ach("match_kills_20", "Dominator", "Kill 20 enemies in 1 game.", "Combat", "best_match_kills", 20, 350)
	_add_ach("match_kills_30", "30-Bomb!", "Kill 30 enemies in 1 game.", "Combat", "best_match_kills", 30, 800)
	_add_ach("match_kills_40", "40-Bomb Legend!", "Kill 40 enemies in 1 game.", "Combat", "best_match_kills", 40, 1800)
	_add_ach("match_kills_50", "50-Bomb Mythic!", "Kill 50 enemies in 1 game.", "Combat", "best_match_kills", 50, 3500)
	_add_ach("headshots_25", "Headhunter", "Score 25 headshot kills.", "Combat", "headshot_kills", 25, 250)
	_add_ach("headshots_100", "Deadeye", "Score 100 headshot kills.", "Combat", "headshot_kills", 100, 600)
	_add_ach("headshots_250", "Surgical Precision", "Score 250 headshot kills.", "Combat", "headshot_kills", 250, 1400)

	# 5. PICKUPS & TREASURE (14)
	_add_ach("treasure_10", "Treasure Seeker", "Open Treasure Boxes 10 times.", "Pickups", "treasure_opens", 10, 150)
	_add_ach("treasure_50", "Loot Raider", "Open Treasure Boxes 50 times.", "Pickups", "treasure_opens", 50, 400)
	_add_ach("treasure_100", "Vault Breaker", "Open Treasure Boxes 100 times.", "Pickups", "treasure_opens", 100, 800)
	_add_ach("treasure_200", "Treasure King", "Open Treasure Boxes 200 times.", "Pickups", "treasure_opens", 200, 1600)
	_add_ach("pickup_groza_10", "Groza Hunter", "Pick up OTs-14 Groza 10 times.", "Pickups", "pickup_groza", 10, 200)
	_add_ach("pickup_groza_50", "Groza Specialist", "Pick up OTs-14 Groza 50 times.", "Pickups", "pickup_groza", 50, 600)
	_add_ach("pickup_groza_100", "Groza Fanatic", "Pick up OTs-14 Groza 100 times.", "Pickups", "pickup_groza", 100, 1200)
	_add_ach("pickup_mg_10", "Heavy Gunner", "Pick up Machine Gun 10 times.", "Pickups", "pickup_mg", 10, 200)
	_add_ach("pickup_mg_50", "Bullet Hose", "Pick up Machine Gun 50 times.", "Pickups", "pickup_mg", 50, 600)
	_add_ach("pickup_mg_100", "Juggernaut", "Pick up Machine Gun 100 times.", "Pickups", "pickup_mg", 100, 1200)
	_add_ach("kill_groza_50", "Groza Reaper", "Kill 50 enemies with OTs-14 Groza.", "Pickups", "weapon_kill_22", 50, 450)
	_add_ach("kill_groza_100", "Groza Overlord", "Kill 100 enemies with OTs-14 Groza.", "Pickups", "weapon_kill_22", 100, 900)
	_add_ach("kill_mg_50", "Suppressing Fire", "Kill 50 enemies with Machine Gun.", "Pickups", "weapon_kill_17", 50, 450)
	_add_ach("kill_mg_100", "Lead Storm", "Kill 100 enemies with Machine Gun.", "Pickups", "weapon_kill_17", 100, 900)

	# 6. ECONOMY, SKINS, CRATES, DAILY & WINS (24)
	_add_ach("own_skins_1", "Fresh Coat", "Own 1 gun skin.", "Economy", "owned_skins_count", 1, 150)
	_add_ach("own_skins_5", "Skin Enthusiast", "Own 5 gun skins.", "Economy", "owned_skins_count", 5, 400)
	_add_ach("own_skins_10", "Skin Collector", "Own 10 gun skins.", "Economy", "owned_skins_count", 10, 800)
	_add_ach("own_skins_25", "Armory Curator", "Own 25 gun skins.", "Economy", "owned_skins_count", 25, 1600)
	_add_ach("own_skins_50", "Luxury Arsenal", "Own 50 gun skins.", "Economy", "owned_skins_count", 50, 3000)
	_add_ach("own_skins_100", "Mythic Vault", "Own 100 gun skins.", "Economy", "owned_skins_count", 100, 6000)
	_add_ach("open_crates_1", "First Unbox", "Open 1 crate.", "Economy", "crates_opened", 1, 150)
	_add_ach("open_crates_10", "Crate Opener", "Open 10 crates.", "Economy", "crates_opened", 10, 500)
	_add_ach("open_crates_25", "Lucky Spinner", "Open 25 crates.", "Economy", "crates_opened", 25, 1000)
	_add_ach("open_crates_50", "High Roller", "Open 50 crates.", "Economy", "crates_opened", 50, 2000)
	_add_ach("open_crates_100", "Crate Tycoon", "Open 100 crates.", "Economy", "crates_opened", 100, 4000)
	_add_ach("open_prem_crates_1", "VIP Unbox", "Open 1 Premium Crate.", "Economy", "prem_crates_opened", 1, 250)
	_add_ach("open_prem_crates_5", "VIP Collector", "Open 5 Premium Crates.", "Economy", "prem_crates_opened", 5, 750)
	_add_ach("open_prem_crates_25", "VIP Legend", "Open 25 Premium Crates.", "Economy", "prem_crates_opened", 25, 2500)
	_add_ach("daily_bonus_1", "Daily Visitor", "Collect 1 Daily Bonus.", "Economy", "daily_bonuses", 1, 100)
	_add_ach("daily_bonus_10", "Loyal Trooper", "Collect 10 Daily Bonuses.", "Economy", "daily_bonuses", 10, 500)
	_add_ach("daily_bonus_30", "Monthly Regular", "Collect 30 Daily Bonuses.", "Economy", "daily_bonuses", 30, 1200)
	_add_ach("daily_bonus_100", "100-Day Legend", "Collect 100 Daily Bonuses.", "Economy", "daily_bonuses", 100, 4000)
	_add_ach("win_matches_1", "First Victory", "Win 1 match.", "Economy", "matches_won", 1, 200)
	_add_ach("win_matches_10", "Champion", "Win 10 matches.", "Economy", "matches_won", 10, 600)
	_add_ach("win_matches_50", "Grand Champion", "Win 50 matches.", "Economy", "matches_won", 50, 1800)
	_add_ach("win_matches_100", "Undisputed King", "Win 100 matches.", "Economy", "matches_won", 100, 3500)
	_add_ach("play_matches_10", "Arena Regular", "Finish 10 matches.", "Economy", "matches_played", 10, 250)
	_add_ach("play_matches_100", "Arena Veteran", "Finish 100 matches.", "Economy", "matches_played", 100, 1500)


func load_config() -> void:
	for path in [CONFIG_PATH, USER_CONFIG_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var ov_map: Dictionary = parsed as Dictionary
			for aid in ov_map.keys():
				if _def_by_id.has(aid) and ov_map[aid] is Dictionary:
					var src: Dictionary = ov_map[aid] as Dictionary
					var dst: Dictionary = _def_by_id[aid] as Dictionary
					if src.has("reward_coins"):
						dst["reward_coins"] = maxi(0, int(src["reward_coins"]))
					if src.has("target"):
						dst["target"] = maxi(1, int(src["target"]))
					if src.has("reward_skin"):
						dst["reward_skin"] = str(src["reward_skin"])
					if src.has("exclusive_skin"):
						dst["exclusive_skin"] = bool(src["exclusive_skin"])
					if src.has("title"):
						dst["title"] = str(src["title"])
					if src.has("desc"):
						dst["desc"] = str(src["desc"])


func save_config(save_to_project: bool = true) -> bool:
	var out: Dictionary = {}
	for d in definitions:
		out[str(d["id"])] = {
			"reward_coins": int(d["reward_coins"]),
			"target": int(d["target"]),
			"reward_skin": str(d.get("reward_skin", "")),
			"exclusive_skin": bool(d.get("exclusive_skin", false))
		}
	var txt: String = JSON.stringify(out, "\t")
	var ok_any: bool = false
	var uf := FileAccess.open(USER_CONFIG_PATH, FileAccess.WRITE)
	if uf != null:
		uf.store_string(txt)
		uf.close()
		ok_any = true
	if save_to_project:
		var pf := FileAccess.open(ProjectSettings.globalize_path(CONFIG_PATH), FileAccess.WRITE)
		if pf != null:
			pf.store_string(txt)
			pf.close()
			ok_any = true
	achievements_changed.emit()
	return ok_any


func reset_config_defaults() -> void:
	_build_default_100()
	achievements_changed.emit()


func _get_save_path() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			var slot: String = a.substr(10).strip_edges()
			if not slot.is_empty():
				return "user://achievements_progress_%s.cfg" % slot
	return SAVE_PATH


func load_progress() -> void:
	var cfg := ConfigFile.new()
	stats.clear()
	claimed.clear()
	notified.clear()
	if cfg.load(_get_save_path()) != OK:
		return
	var raw_s: Variant = cfg.get_value("ach", "stats", {})
	stats = (raw_s as Dictionary).duplicate(true) if raw_s is Dictionary else {}
	var raw_c: Variant = cfg.get_value("ach", "claimed", {})
	claimed = (raw_c as Dictionary).duplicate(true) if raw_c is Dictionary else {}
	var raw_n: Variant = cfg.get_value("ach", "notified", {})
	notified = (raw_n as Dictionary).duplicate(true) if raw_n is Dictionary else {}


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ach", "stats", stats)
	cfg.set_value("ach", "claimed", claimed)
	cfg.set_value("ach", "notified", notified)
	cfg.save(_get_save_path())


func reset_player_progress() -> void:
	var abs_p: String = ProjectSettings.globalize_path(_get_save_path())
	if FileAccess.file_exists(abs_p):
		DirAccess.remove_absolute(abs_p)
	stats.clear()
	claimed.clear()
	notified.clear()
	save_progress()
	achievements_changed.emit()


func is_skin_achievement_exclusive(weapon_id: int, skin_key: String) -> bool:
	var pair := "%d:%s" % [weapon_id, skin_key]
	for d in definitions:
		if bool(d.get("exclusive_skin", false)) and str(d.get("reward_skin", "")) == pair:
			return true
	return false


func get_exclusive_skin_achievement_title(weapon_id: int, skin_key: String) -> String:
	var pair := "%d:%s" % [weapon_id, skin_key]
	for d in definitions:
		if bool(d.get("exclusive_skin", false)) and str(d.get("reward_skin", "")) == pair:
			return str(d.get("title", "Achievement"))
	return ""


func get_progress(ach_id: String) -> int:
	if not _def_by_id.has(ach_id):
		return 0
	var d: Dictionary = _def_by_id[ach_id] as Dictionary
	var sk: String = str(d["stat"])
	if sk == "blast_total":
		var tot: int = 0
		for bk in ["bomb_kill_frag", "bomb_kill_time", "bomb_kill_mine", "bomb_kill_sticky", "bomb_kill_cluster"]:
			tot += mini(100, int(stats.get(bk, 0)))
		return tot
	if sk == "gunmaster_subs_done":
		var done_c: int = 0
		for sub in definitions:
			if str(sub.get("parent", "")) == "gun_master":
				if int(stats.get(str(sub["stat"]), 0)) >= int(sub["target"]):
					done_c += 1
		return done_c
	return int(stats.get(sk, 0))


func is_completed(ach_id: String) -> bool:
	if not _def_by_id.has(ach_id):
		return false
	var d: Dictionary = _def_by_id[ach_id] as Dictionary
	return get_progress(ach_id) >= int(d["target"])


func is_claimed(ach_id: String) -> bool:
	return bool(claimed.get(ach_id, false))


func can_claim(ach_id: String) -> bool:
	return is_completed(ach_id) and not is_claimed(ach_id)


func get_unclaimed_count() -> int:
	var c: int = 0
	for d in definitions:
		if can_claim(str(d["id"])):
			c += 1
	return c


func get_completed_count() -> int:
	var c: int = 0
	for d in definitions:
		if is_completed(str(d["id"])):
			c += 1
	return c


func claim_achievement(ach_id: String) -> Dictionary:
	if not can_claim(ach_id):
		return {"ok": false}
	var d: Dictionary = _def_by_id[ach_id] as Dictionary
	claimed[ach_id] = true
	var c_rew: int = int(d.get("reward_coins", 0))
	if c_rew > 0:
		ProfileManager.add_coins(c_rew)
	var sk_pair: String = str(d.get("reward_skin", ""))
	var skin_unlocked: String = ""
	if sk_pair.contains(":"):
		var parts: PackedStringArray = sk_pair.split(":")
		if parts.size() == 2:
			var wid: int = int(parts[0])
			var skey: String = parts[1]
			ProfileManager.grant_gun_skin(wid, skey)
			skin_unlocked = "%s — %s" % [WeaponData.get_weapon(wid, 0, 0).display_name, ProfileManager.get_gun_skin_name(wid, skey)]
	save_progress()
	_sync_derived_stats()
	achievements_changed.emit()
	return {"ok": true, "coins": c_rew, "skin": skin_unlocked}


func increment_stat(stat_key: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	stats[stat_key] = int(stats.get(stat_key, 0)) + amount
	_check_newly_unlocked()
	save_progress()
	achievements_changed.emit()


func set_stat_max(stat_key: String, value: int) -> void:
	if value > int(stats.get(stat_key, 0)):
		stats[stat_key] = value
		_check_newly_unlocked()
		save_progress()
		achievements_changed.emit()


func _sync_derived_stats() -> void:
	var unl_c: int = ProfileManager.unlocked_agents.size()
	stats["unlocked_agents_count"] = maxi(int(stats.get("unlocked_agents_count", 0)), unl_c)
	for aid in ProfileManager.unlocked_agents:
		stats["unlocked_agent_%d" % int(aid)] = 1
	var sk_count: int = 0
	for wk in ProfileManager.owned_gun_skins.keys():
		if ProfileManager.owned_gun_skins[wk] is Array:
			for sk in (ProfileManager.owned_gun_skins[wk] as Array):
				if str(sk) != "default":
					sk_count += 1
	stats["owned_skins_count"] = maxi(int(stats.get("owned_skins_count", 0)), sk_count)
	_check_newly_unlocked()
	save_progress()


func _check_newly_unlocked() -> void:
	for d in definitions:
		var aid: String = str(d["id"])
		if not bool(notified.get(aid, false)) and is_completed(aid):
			notified[aid] = true
			achievement_unlocked.emit(aid, str(d["title"]))


# --- Gameplay Event Helpers ---

func record_kill(weapon_id: int, weapon_name: String, is_agent_mode: bool, is_headshot: bool, combo_count: int, match_kills: int) -> void:
	if NetworkManager.is_test_mode():
		return
	stats["total_kills"] = int(stats.get("total_kills", 0)) + 1
	if is_agent_mode:
		stats["agent_mode_kills"] = int(stats.get("agent_mode_kills", 0)) + 1
	if is_headshot:
		stats["headshot_kills"] = int(stats.get("headshot_kills", 0)) + 1
	if combo_count > int(stats.get("best_combo", 0)):
		stats["best_combo"] = combo_count
	if match_kills > int(stats.get("best_match_kills", 0)):
		stats["best_match_kills"] = match_kills

	var wn_low: String = weapon_name.to_lower()
	if wn_low.contains("frag") or wn_low.contains("nade gun") or wn_low.contains("grenade"):
		stats["bomb_kill_frag"] = int(stats.get("bomb_kill_frag", 0)) + 1
	elif wn_low.contains("time"):
		stats["bomb_kill_time"] = int(stats.get("bomb_kill_time", 0)) + 1
	elif wn_low.contains("mine"):
		stats["bomb_kill_mine"] = int(stats.get("bomb_kill_mine", 0)) + 1
	elif wn_low.contains("sticky"):
		stats["bomb_kill_sticky"] = int(stats.get("bomb_kill_sticky", 0)) + 1
	elif wn_low.contains("cluster"):
		stats["bomb_kill_cluster"] = int(stats.get("bomb_kill_cluster", 0)) + 1

	if weapon_id >= 0:
		var wk := "weapon_kill_%d" % weapon_id
		stats[wk] = int(stats.get(wk, 0)) + 1

	_check_newly_unlocked()
	save_progress()
	achievements_changed.emit()


func record_weapon_pickup(weapon_id: int) -> void:
	if NetworkManager.is_test_mode():
		return
	if weapon_id == 22:
		increment_stat("pickup_groza", 1)
	elif weapon_id == 17:
		increment_stat("pickup_mg", 1)


func record_treasure_open() -> void:
	if NetworkManager.is_test_mode():
		return
	increment_stat("treasure_opens", 1)


func record_ability_use(is_ult: bool) -> void:
	if NetworkManager.is_test_mode():
		return
	if is_ult:
		increment_stat("ult_uses", 1)
	else:
		increment_stat("ability_uses", 1)


func record_match_end(won: bool) -> void:
	if NetworkManager.is_test_mode():
		return
	stats["matches_played"] = int(stats.get("matches_played", 0)) + 1
	if won:
		stats["matches_won"] = int(stats.get("matches_won", 0)) + 1
	_check_newly_unlocked()
	save_progress()
	achievements_changed.emit()


func record_crate_opened(is_premium: bool) -> void:
	stats["crates_opened"] = int(stats.get("crates_opened", 0)) + 1
	if is_premium:
		stats["prem_crates_opened"] = int(stats.get("prem_crates_opened", 0)) + 1
	_sync_derived_stats()
	achievements_changed.emit()


func record_daily_bonus() -> void:
	increment_stat("daily_bonuses", 1)


func record_agent_or_skin_change() -> void:
	_sync_derived_stats()
	achievements_changed.emit()
