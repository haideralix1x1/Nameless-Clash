class_name WeaponData
extends Resource

@export var id: int = 0
@export var code_name: String = "ak47"
@export var display_name: String = "AK-47"
@export var category: String = "Assault Rifle"
@export var description: String = ""
@export var damage: int = 24
@export var fire_interval: float = 0.135
@export var burst_count: int = 1
@export var burst_interval: float = 0.058
@export var mag_size: int = 30
@export var initial_reserve: int = -1
@export var reload_time: float = 1.5
@export var single_shell_reload: bool = false
@export var gravity_scale: float = 0.0
@export var is_suppressed: bool = false
@export var recoil_impulse: float = 55.0
@export var vertical_recoil_bias: float = 0.035
@export var bullet_speed: float = 1280.0
@export var spread_deg: float = 2.8
@export var pellet_count: int = 1
@export var bullet_range: float = 0.0
@export var damage_falloff_start: float = 9999.0

const WEAPON_RANGES_PATH: String = "res://assets/data/weapon_ranges.json"
const USER_WEAPON_RANGES_PATH: String = "user://weapon_ranges.json"
const WEAPON_STATS_PATH: String = "res://assets/data/weapon_stats.json"
const USER_WEAPON_STATS_PATH: String = "user://weapon_stats.json"
const TEX_SELECTION_SHEET: Texture2D = preload("res://assets/sprites/weapons_selection_sheet.png")
const TEX_FLOOR_SHEET: Texture2D = preload("res://assets/sprites/weapons_floor_sheet.png")
const TEX_AGENT_SHEET: Texture2D = preload("res://assets/sprites/weapons_agent_sheet.png")
const SELECTION_COLS: int = 16
const SELECTION_ROWS: int = 10
const FLOOR_COLS: int = 6
const AGENT_COLS: int = 10

const SELECTION_COL_BY_ID: Dictionary = {
	0: 0, 1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 8, 9: 9, 10: 10,
	12: 10, 14: 2,
	18: 11, 19: 12, 20: 13, 21: 14, 23: 15
}
const FLOOR_COL_BY_ID: Dictionary = {
	11: 0, 13: 1, 15: 2, 16: 3, 17: 4, 22: 5
}
const AGENT_COL_BY_STYLE: Dictionary = {
	"scythe": 0,
	"magma_hammer": 1,
	"bow": 2,
	"orc_axe": 3,
	"boxing_glove": 4,
	"yagami_katana": 5,
	"rook_frost_blade": 6,
	"afera_spear": 7,
	"bruski_revolver": 8,
	"stone_hammer": 9
}


static func get_weapon_sprite_spec(weapon_id: int, skin_id: int = 0) -> Dictionary:
	if FLOOR_COL_BY_ID.has(weapon_id):
		var fc: int = int(FLOOR_COL_BY_ID[weapon_id])
		return {
			"tex": TEX_FLOOR_SHEET,
			"hframes": FLOOR_COLS,
			"vframes": 1,
			"frame": fc,
			"region": Rect2(fc * 256.0, 0.0, 256.0, 128.0)
		}
	var sc: int = int(SELECTION_COL_BY_ID.get(weapon_id, clampi(weapon_id, 0, SELECTION_COLS - 1)))
	var row: int = clampi(skin_id, 0, SELECTION_ROWS - 1)
	return {
		"tex": TEX_SELECTION_SHEET,
		"hframes": SELECTION_COLS,
		"vframes": SELECTION_ROWS,
		"frame": row * SELECTION_COLS + sc,
		"region": Rect2(sc * 256.0, row * 128.0, 256.0, 128.0)
	}


static func get_weapon_atlas_texture(weapon_id: int, skin_id: int = 0) -> AtlasTexture:
	var spec: Dictionary = get_weapon_sprite_spec(weapon_id, skin_id)
	var at := AtlasTexture.new()
	at.atlas = spec["tex"] as Texture2D
	at.region = spec["region"] as Rect2
	return at


static func get_agent_weapon_region(style_name: String) -> Rect2:
	var col: int = int(AGENT_COL_BY_STYLE.get(style_name, -1))
	if col < 0:
		return Rect2()
	return Rect2(col * 256.0, 0.0, 256.0, 128.0)
static var _range_cache_loaded: bool = false
static var _range_cache: Dictionary = {}
static var _stats_cache_loaded: bool = false
static var _stats_cache: Dictionary = {}
@export var min_damage_ratio: float = 1.0
@export var move_speed_multiplier: float = 1.0
@export var scope_zoom: float = 1.05
@export var max_zoom_level: int = 2
@export var has_backblast: bool = false
@export var has_accessory_rail: bool = false
@export var unlimited_reserve: bool = false
@export var supports_dual_wield: bool = false
@export var is_laser: bool = false
@export var is_explosive: bool = false
@export var is_homing: bool = false
@export var custom_visual_style: String = "bullet"
@export var custom_lifetime: float = 1.6
@export var stun_duration: float = 0.0
@export var explosion_radius: float = 0.0
@export var muzzle_flash_scale: float = 1.0
@export var bullet_color: Color = Color(1.0, 0.85, 0.25)
@export var sound_path: String = "res://assets/audio/shoot_ak47.wav"
@export var sprite_frame: int = 0

const RESOURCE_PATHS: Array[String] = [
	"res://assets/weapons/weapon_0_ak47.tres",
	"res://assets/weapons/weapon_1_m4a1.tres",
	"res://assets/weapons/weapon_2_scarh.tres",
	"res://assets/weapons/weapon_3_mp5.tres",
	"res://assets/weapons/weapon_4_vector.tres",
	"res://assets/weapons/weapon_5_spas12.tres",
	"res://assets/weapons/weapon_6_remington870.tres",
	"res://assets/weapons/weapon_7_awm.tres",
	"res://assets/weapons/weapon_8_svd.tres",
	"res://assets/weapons/weapon_9_glock17.tres",
	"res://assets/weapons/weapon_10_rpg7.tres"
]

const GUN_PRESETS: Array[Dictionary] = [
	{
		"name": "Assault Specialist",
		"primary": 0,
		"secondary": 9,
		"bombs": 3,
		"bomb_type": "frag",
		"shield_tier": "medium",
		"shield_hp": 50,
		"helmet_tier": "medium",
		"helmet_hp": 30,
		"helmet_reduce": 0.25,
		"desc": "AK47 + Deagle + 3 Frag • Med Shield & Helmet",
		"accent": "green"
	},
	{
		"name": "Tactical Burst",
		"primary": 1,
		"secondary": 20,
		"bombs": 3,
		"bomb_type": "time",
		"shield_tier": "light",
		"shield_hp": 35,
		"helmet_tier": "medium",
		"helmet_hp": 30,
		"helmet_reduce": 0.25,
		"desc": "M16A4 (4-Burst) + Suppressed Pistol + 3 Time • Light Shield / Med Helmet",
		"accent": "blue"
	},
	{
		"name": "Heavy Striker",
		"primary": 2,
		"secondary": 4,
		"bombs": 3,
		"bomb_type": "cluster",
		"shield_tier": "medium",
		"shield_hp": 50,
		"helmet_tier": "light",
		"helmet_hp": 20,
		"helmet_reduce": 0.15,
		"desc": "SCAR-L + Uzi + 3 Cluster • Med Shield / Light Helmet",
		"accent": "orange"
	},
	{
		"name": "Breacher CQB",
		"primary": 21,
		"secondary": 3,
		"bombs": 3,
		"bomb_type": "sticky",
		"shield_tier": "heavy",
		"shield_hp": 80,
		"helmet_tier": "heavy",
		"helmet_hp": 50,
		"helmet_reduce": 0.35,
		"desc": "Black Shotgun + SMG + 3 Sticky • Heavy Shield & Helmet",
		"accent": "purple"
	},
	{
		"name": "Sniper Recon",
		"primary": 7,
		"secondary": 8,
		"bombs": 3,
		"bomb_type": "mine",
		"shield_tier": "light",
		"shield_hp": 25,
		"helmet_tier": "light",
		"helmet_hp": 20,
		"helmet_reduce": 0.15,
		"desc": "Sniper + Auto Sniper + 3 Mine • Light Shield & Helmet",
		"accent": "sky"
	},
	{
		"name": "Demolitionist",
		"primary": 10,
		"secondary": 9,
		"bombs": 4,
		"bomb_type": "cluster",
		"shield_tier": "heavy",
		"shield_hp": 70,
		"helmet_tier": "light",
		"helmet_hp": 20,
		"helmet_reduce": 0.15,
		"desc": "Bazooka + Deagle + 4 Cluster • Heavy Shield / Light Helmet",
		"accent": "red"
	},
	{
		"name": "Tactical Disruptor",
		"primary": 18,
		"secondary": 19,
		"bombs": 2,
		"bomb_type": "frag",
		"shield_tier": "medium",
		"shield_hp": 50,
		"helmet_tier": "medium",
		"helmet_hp": 30,
		"helmet_reduce": 0.25,
		"desc": "Nade Gun (3/3) + Stun Gun (4s) + 2 Frag • Med Shield & Helmet",
		"accent": "sky"
	},
	{
		"name": "M416 Commando",
		"primary": 23,
		"secondary": 20,
		"bombs": 3,
		"bomb_type": "frag",
		"shield_tier": "light",
		"shield_hp": 35,
		"helmet_tier": "medium",
		"helmet_hp": 30,
		"helmet_reduce": 0.25,
		"desc": "M416 + Suppressed Pistol + 3 Frag • Light Shield / Med Helmet",
		"accent": "blue"
	}
]


static func _get_network_manager() -> Node:
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("NetworkManager")
	return null


static func is_weapon_allowed(weapon_id: int) -> bool:
	if weapon_id == 14:
		return false
	var nm: Node = _get_network_manager()
	if nm == null:
		return true
	if bool(nm.get("only_pistols")):
		return weapon_id == 9
	var rw = nm.get("restricted_weapons")
	if rw is Array and rw.has(weapon_id):
		return false
	if not bool(nm.get("allow_shotguns")) and (weapon_id == 5 or weapon_id == 6):
		return false
	if not bool(nm.get("allow_snipers")) and (weapon_id == 7 or weapon_id == 8):
		return false
	if not bool(nm.get("allow_explosives")) and weapon_id == 10:
		return false
	return true


static func get_allowed_weapon_ids() -> Array[int]:
	var out: Array[int] = []
	for i in range(RESOURCE_PATHS.size()):
		if is_weapon_allowed(i):
			out.append(i)
	if out.is_empty():
		out.append(9)
	return out


static func sanitize_weapon_id(weapon_id: int) -> int:
	if weapon_id == 14:
		return 11
	if weapon_id >= 11 and weapon_id <= 23:
		var nm: Node = _get_network_manager()
		if (weapon_id == 12 or weapon_id == 18) and nm != null and not bool(nm.get("allow_explosives")):
			return 11
		return weapon_id
	var idx: int = wrapi(weapon_id, 0, RESOURCE_PATHS.size())
	if is_weapon_allowed(idx):
		return idx
	var allowed: Array[int] = get_allowed_weapon_ids()
	return allowed[0]


static func get_pickup_weapon_ids() -> Array[int]:
	var out: Array[int] = [11, 13, 15, 16]
	var nm: Node = _get_network_manager()
	var exp_ok: bool = true if nm == null else bool(nm.get("allow_explosives"))
	if exp_ok:
		out.append(12)
	return out


static func get_effective_preset(preset_idx: int) -> Dictionary:
	var idx: int = clampi(preset_idx, 0, GUN_PRESETS.size() - 1)
	var d: Dictionary = GUN_PRESETS[idx].duplicate(true)
	var orig_pri: int = int(d["primary"])
	var orig_sec: int = int(d["secondary"])
	var pri: int = sanitize_weapon_id(orig_pri)
	var sec: int = orig_sec
	if not is_weapon_allowed(sec):
		sec = 9 if is_weapon_allowed(9) else sanitize_weapon_id(orig_sec)
	d["primary"] = pri
	d["secondary"] = sec

	var nm: Node = _get_network_manager()
	var bombs_allowed: bool = true if nm == null else bool(nm.get("allow_explosives"))
	if not bombs_allowed:
		d["bombs"] = 0

	var w_pri: WeaponData = get_weapon(pri, 0, 0)
	var w_sec: WeaponData = get_weapon(sec, 0, 0)
	var b_count: int = int(d["bombs"])
	var b_label: String = "NO BOMBS" if b_count <= 0 else ("%d %s Bombs" % [b_count, str(d["bomb_type"]).capitalize()])
	var rule_tag: String = " [FILTERED]" if (pri != orig_pri or sec != orig_sec or not bombs_allowed) else ""
	d["effective_desc"] = "%s + %s + %s%s" % [w_pri.display_name, w_sec.display_name, b_label, rule_tag]
	return d


static func get_builtin_default_ranges() -> Dictionary:
	return {
		"0": 860.0, "1": 940.0, "2": 960.0, "3": 560.0, "4": 500.0,
		"5": 340.0, "6": 360.0, "7": 1500.0, "8": 1350.0, "9": 620.0,
		"10": 1100.0, "11": 280.0, "12": 1250.0, "13": 1050.0,
		"14": 820.0, "15": 950.0, "16": 750.0, "17": 860.0,
		"18": 820.0, "19": 580.0, "20": 680.0, "21": 380.0, "22": 920.0, "23": 950.0,
	}


static func load_weapon_ranges_dict() -> Dictionary:
	if _range_cache_loaded and not _range_cache.is_empty():
		return _range_cache.duplicate()
	var out: Dictionary = get_builtin_default_ranges()
	for path in [WEAPON_RANGES_PATH, USER_WEAPON_RANGES_PATH]:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				for k in (parsed as Dictionary).keys():
					out[str(k)] = clampf(float((parsed as Dictionary)[k]), 80.0, 4000.0)
	_range_cache = out.duplicate()
	_range_cache_loaded = true
	return out


static func reload_weapon_ranges() -> void:
	_range_cache_loaded = false
	_range_cache.clear()
	load_weapon_ranges_dict()


static func load_weapon_stats_dict() -> Dictionary:
	if _stats_cache_loaded:
		return _stats_cache.duplicate(true)
	var out: Dictionary = {}
	for path in [WEAPON_STATS_PATH, USER_WEAPON_STATS_PATH]:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				for k in (parsed as Dictionary).keys():
					var v: Variant = (parsed as Dictionary)[k]
					if v is Dictionary:
						out[str(k)] = (v as Dictionary).duplicate(true)
	_stats_cache = out.duplicate(true)
	_stats_cache_loaded = true
	return out


static func reload_weapon_stats() -> void:
	_stats_cache_loaded = false
	_stats_cache.clear()
	load_weapon_stats_dict()
	reload_weapon_ranges()


static func get_total_weapon_count() -> int:
	return 24


static func get_base_weapon(weapon_id: int) -> WeaponData:
	var ranges: Dictionary = get_builtin_default_ranges()
	if weapon_id >= 11 and weapon_id <= 23:
		var sw: WeaponData = _get_special_weapon(weapon_id)
		sw.bullet_range = float(ranges.get(str(weapon_id), sw.bullet_range if sw.bullet_range > 0.0 else 800.0))
		return sw
	var idx: int = clampi(weapon_id, 0, RESOURCE_PATHS.size() - 1)
	var base: WeaponData = load(RESOURCE_PATHS[idx]) as WeaponData
	var w: WeaponData = (base.duplicate() as WeaponData) if base != null else _fallback_weapon(idx)
	w.bullet_range = float(ranges.get(str(idx), w.bullet_range if w.bullet_range > 0.0 else 860.0))
	return w


static func _apply_stat_overrides(w: WeaponData, key: String, ranges: Dictionary, stats: Dictionary) -> void:
	w.bullet_range = float(ranges.get(key, w.bullet_range if w.bullet_range > 0.0 else 860.0))
	if stats.has(key) and stats[key] is Dictionary:
		var sd: Dictionary = stats[key] as Dictionary
		if sd.has("bullet_range"): w.bullet_range = maxf(float(sd["bullet_range"]), 40.0)
		if sd.has("damage"): w.damage = maxi(1, int(sd["damage"]))
		if sd.has("fire_interval"): w.fire_interval = maxf(float(sd["fire_interval"]), 0.01)
		if sd.has("spread_deg"): w.spread_deg = maxf(float(sd["spread_deg"]), 0.0)
		if sd.has("bullet_speed"): w.bullet_speed = maxf(float(sd["bullet_speed"]), 50.0)
		if sd.has("mag_size"): w.mag_size = maxi(1, int(sd["mag_size"]))
		if sd.has("reload_time"): w.reload_time = maxf(float(sd["reload_time"]), 0.05)
		if sd.has("recoil_impulse"): w.recoil_impulse = maxf(float(sd["recoil_impulse"]), 0.0)
		if sd.has("pellet_count"): w.pellet_count = maxi(1, int(sd["pellet_count"]))


static func get_weapon(weapon_id: int, skin_id: int = 0, rail_mod: int = 0) -> WeaponData:
	var ranges: Dictionary = load_weapon_ranges_dict()
	var stats: Dictionary = load_weapon_stats_dict()
	if weapon_id >= 11 and weapon_id <= 23:
		var sw: WeaponData = _get_special_weapon(weapon_id)
		_apply_stat_overrides(sw, str(weapon_id), ranges, stats)
		return sw
	var idx: int = clampi(weapon_id, 0, RESOURCE_PATHS.size() - 1)
	var base: WeaponData = load(RESOURCE_PATHS[idx]) as WeaponData
	var w: WeaponData = (base.duplicate() as WeaponData) if base != null else _fallback_weapon(idx)
	_apply_stat_overrides(w, str(idx), ranges, stats)

	if w.has_accessory_rail:
		if rail_mod == 1:
			# Suppressor attachment: tighter spread, smaller muzzle flash, quieter tone
			w.spread_deg *= 0.72
			w.muzzle_flash_scale = 0.35
			w.display_name = "M16A4 (Suppressed)"
		elif rail_mod == 2:
			# Tactical Scope attachment: extended zoom & precision
			w.scope_zoom = 0.90
			w.spread_deg *= 0.65
			w.bullet_range += 120.0
			w.display_name = "M16A4 (Scoped)"

	if skin_id == 2:
		w.bullet_color = Color(0.15, 0.96, 1.0) if (w.id % 2 == 0) else Color(1.0, 0.32, 0.85)
	return w


static func get_weapon_count() -> int:
	return RESOURCE_PATHS.size()


static func _fallback_weapon(idx: int) -> WeaponData:
	var w := WeaponData.new()
	w.id = idx
	return w


static func _get_special_weapon(w_id: int) -> WeaponData:
	var w := WeaponData.new()
	w.id = w_id
	w.category = "Special"
	match w_id:
		11:
			w.code_name = "flamethrower"
			w.display_name = "Flamethrower"
			w.description = "Rapid fire stream! Pickup only."
			w.damage = 14
			w.fire_interval = 0.06
			w.mag_size = 60
			w.reload_time = 2.0
			w.recoil_impulse = 30.0
			w.bullet_speed = 620.0
			w.spread_deg = 8.0
			w.max_zoom_level = 2
			w.bullet_color = Color(1.0, 0.44, 0.12)
			w.custom_visual_style = "fireball"
			w.custom_lifetime = 0.44
			w.sound_path = "res://assets/audio/shoot_shotgun.wav"
			w.sprite_frame = 10
		12:
			w.code_name = "homing_rpg"
			w.display_name = "Follow Rocket"
			w.description = "Homing missile that tracks enemies! Pickup only."
			w.damage = 78
			w.fire_interval = 1.25
			w.mag_size = 1
			w.reload_time = 2.2
			w.recoil_impulse = 175.0
			w.bullet_speed = 460.0
			w.spread_deg = 1.5
			w.max_zoom_level = 4
			w.is_explosive = true
			w.is_homing = true
			w.has_backblast = true
			w.muzzle_flash_scale = 1.6
			w.explosion_radius = 145.0
			w.bullet_color = Color(1.0, 0.30, 0.22)
			w.custom_visual_style = "homing_rocket"
			w.custom_lifetime = 2.8
			w.sound_path = "res://assets/audio/shoot_rpg.wav"
			w.sprite_frame = 10
		13:
			w.code_name = "plasma_cannon"
			w.display_name = "Plasma Cannon"
			w.description = "High-energy plasma bolt! 50% damage + 3s stun. Pickup only."
			w.damage = 50
			w.stun_duration = 3.0
			w.damage_falloff_start = 9999.0
			w.min_damage_ratio = 1.0
			w.fire_interval = 0.36
			w.mag_size = 12
			w.reload_time = 1.6
			w.recoil_impulse = 95.0
			w.bullet_speed = 920.0
			w.spread_deg = 1.0
			w.max_zoom_level = 4
			w.is_laser = false
			w.bullet_color = Color(0.18, 0.72, 1.0)
			w.custom_visual_style = "plasma_ball"
			w.custom_lifetime = 1.4
			w.sound_path = "res://assets/audio/shoot_sniper.wav"
			w.sprite_frame = 2
		14:
			w.code_name = "minigun"
			w.display_name = "Minigun"
			w.description = "Extreme fire-rate rotary cannon! Pickup only."
			w.damage = 13
			w.fire_interval = 0.055
			w.mag_size = 100
			w.reload_time = 2.4
			w.recoil_impulse = 45.0
			w.bullet_speed = 1350.0
			w.spread_deg = 4.5
			w.max_zoom_level = 3
			w.move_speed_multiplier = 0.88
			w.bullet_color = Color(1.0, 0.88, 0.25)
			w.sound_path = "res://assets/audio/shoot_ak47.wav"
			w.sprite_frame = 2
		15:
			w.code_name = "hook_gun"
			w.display_name = "Hook Gun"
			w.description = "Grapple walls to zip there or hook enemies to drag them! Pickup only."
			w.damage = 10
			w.fire_interval = 0.85
			w.mag_size = 6
			w.reload_time = 1.6
			w.recoil_impulse = 40.0
			w.bullet_speed = 1180.0
			w.spread_deg = 0.5
			w.max_zoom_level = 3
			w.bullet_color = Color(0.95, 0.72, 0.24)
			w.custom_visual_style = "hook_gun_claw"
			w.custom_lifetime = 0.95
			w.sound_path = "res://assets/audio/jump.wav"
			w.sprite_frame = 2
		16:
			w.code_name = "bubble_gun"
			w.display_name = "Bubble Gun"
			w.description = "Trap enemies in a floating bubble for 10s until popped! Pickup only."
			w.damage = 5
			w.fire_interval = 0.90
			w.mag_size = 5
			w.reload_time = 1.8
			w.recoil_impulse = 55.0
			w.bullet_speed = 680.0
			w.spread_deg = 1.5
			w.max_zoom_level = 3
			w.bullet_color = Color(0.35, 0.92, 1.0)
			w.custom_visual_style = "bubble_trap_orb"
			w.custom_lifetime = 1.4
			w.sound_path = "res://assets/audio/pickup.wav"
			w.sprite_frame = 2
		17:
			w.code_name = "machine_gun"
			w.display_name = "Machine Gun"
			w.description = "100-round rapid-fire Machine Gun (100/100)! Treasure Box exclusive."
			w.damage = 14
			w.fire_interval = 0.055
			w.mag_size = 100
			w.reload_time = 2.2
			w.recoil_impulse = 42.0
			w.bullet_speed = 1280.0
			w.spread_deg = 4.0
			w.max_zoom_level = 3
			w.move_speed_multiplier = 0.90
			w.bullet_color = Color(1.0, 0.86, 0.30)
			w.sound_path = "res://assets/audio/shoot_ak47.wav"
			w.sprite_frame = 2
		18:
			w.code_name = "nade_gun"
			w.display_name = "Nade Gun"
			w.category = "Explosive"
			w.description = "Tactical grenade launcher carrying 3/3 lobbed explosive grenades."
			w.damage = 68
			w.fire_interval = 0.72
			w.mag_size = 3
			w.initial_reserve = -1
			w.reload_time = 1.85
			w.recoil_impulse = 110.0
			w.bullet_speed = 680.0
			w.spread_deg = 2.0
			w.gravity_scale = 0.65
			w.is_explosive = true
			w.explosion_radius = 128.0
			w.muzzle_flash_scale = 1.25
			w.max_zoom_level = 3
			w.bullet_color = Color(1.0, 0.50, 0.16)
			w.custom_visual_style = "nade_round"
			w.custom_lifetime = 2.2
			w.sound_path = "res://assets/audio/shoot_rpg.wav"
			w.sprite_frame = 10
		19:
			w.code_name = "stun_gun"
			w.display_name = "Stun Gun"
			w.category = "Tactical"
			w.description = "Electric taser pistol that stuns hit players for 4 seconds."
			w.damage = 12
			w.stun_duration = 4.0
			w.fire_interval = 0.65
			w.mag_size = 6
			w.reload_time = 1.35
			w.recoil_impulse = 20.0
			w.bullet_speed = 1180.0
			w.spread_deg = 1.2
			w.max_zoom_level = 2
			w.bullet_color = Color(0.24, 0.94, 1.0)
			w.custom_visual_style = "stun_bolt"
			w.custom_lifetime = 0.9
			w.sound_path = "res://assets/audio/pickup.wav"
			w.sprite_frame = 9
		20:
			w.code_name = "suppressed_pistol"
			w.display_name = "Suppressed Pistol"
			w.category = "Pistol"
			w.description = "Stealth silenced tactical pistol with tight precision and low recoil."
			w.damage = 22
			w.fire_interval = 0.17
			w.mag_size = 15
			w.reload_time = 1.15
			w.recoil_impulse = 18.0
			w.bullet_speed = 1360.0
			w.spread_deg = 1.0
			w.max_zoom_level = 2
			w.is_suppressed = true
			w.muzzle_flash_scale = 0.22
			w.bullet_color = Color(0.85, 0.94, 1.0)
			w.sound_path = "res://assets/audio/shoot_m4a1.wav"
			w.sprite_frame = 9
		21:
			w.code_name = "black_shotgun"
			w.display_name = "Black Shotgun"
			w.category = "Shotgun"
			w.description = "Matte-black 8-round combat shotgun with full-mag reload and half per-shot damage of Pump Shotgun."
			w.damage = 11
			w.pellet_count = 8
			w.fire_interval = 0.52
			w.mag_size = 8
			w.reload_time = 1.65
			w.single_shell_reload = false
			w.recoil_impulse = 92.0
			w.bullet_speed = 1180.0
			w.spread_deg = 8.8
			w.max_zoom_level = 2
			w.muzzle_flash_scale = 1.15
			w.bullet_color = Color(1.0, 0.76, 0.24)
			w.sound_path = "res://assets/audio/shoot_shotgun.wav"
			w.sprite_frame = 6
		22:
			w.code_name = "groza"
			w.display_name = "OTs-14 Groza"
			w.category = "Special"
			w.description = "Treasure Box exclusive! Uzi fire rate + AK47 damage with low recoil."
			w.damage = 28
			w.fire_interval = 0.068
			w.mag_size = 30
			w.initial_reserve = 120
			w.reload_time = 1.45
			w.recoil_impulse = 22.0
			w.vertical_recoil_bias = 0.012
			w.bullet_speed = 1420.0
			w.spread_deg = 1.8
			w.max_zoom_level = 4
			w.move_speed_multiplier = 1.02
			w.bullet_color = Color(1.0, 0.72, 0.22)
			w.sound_path = "res://assets/audio/shoot_ak47.wav"
			w.sprite_frame = 0
		23:
			w.code_name = "m416"
			w.display_name = "M416"
			w.category = "Assault Rifle"
			w.description = "PUBG-style versatile full-auto 5.56 assault rifle with fast fire rate and ultra-stable recoil."
			w.damage = 21
			w.fire_interval = 0.086
			w.mag_size = 30
			w.initial_reserve = -1
			w.reload_time = 1.35
			w.recoil_impulse = 24.0
			w.vertical_recoil_bias = 0.012
			w.bullet_speed = 1440.0
			w.spread_deg = 1.5
			w.max_zoom_level = 4
			w.move_speed_multiplier = 1.02
			w.muzzle_flash_scale = 0.92
			w.bullet_color = Color(1.0, 0.88, 0.36)
			w.sound_path = "res://assets/audio/shoot_m4a1.wav"
			w.sprite_frame = 1
	return w
