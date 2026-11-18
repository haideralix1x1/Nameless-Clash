class_name WeaponData
extends Resource

@export var id: int = 0
@export var code_name: String = "ak47"
@export var display_name: String = "AK-47"
@export var category: String = "Assault Rifle"
@export var description: String = ""
@export var damage: int = 24
@export var fire_interval: float = 0.135
@export var mag_size: int = 30
@export var reload_time: float = 1.5
@export var single_shell_reload: bool = false
@export var recoil_impulse: float = 55.0
@export var vertical_recoil_bias: float = 0.035
@export var bullet_speed: float = 1280.0
@export var spread_deg: float = 2.8
@export var pellet_count: int = 1
@export var damage_falloff_start: float = 9999.0
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
		"desc": "AK47 + Deagle + 3 Frag Bombs",
		"accent": "green"
	},
	{
		"name": "Tactical Carbine",
		"primary": 1,
		"secondary": 3,
		"bombs": 3,
		"bomb_type": "time",
		"desc": "M4A1 + SMG + 3 Time Bombs",
		"accent": "blue"
	},
	{
		"name": "Heavy Striker",
		"primary": 2,
		"secondary": 4,
		"bombs": 3,
		"bomb_type": "cluster",
		"desc": "SCAR-H + Uzi + 3 Cluster Bombs",
		"accent": "orange"
	},
	{
		"name": "Breacher CQB",
		"primary": 5,
		"secondary": 6,
		"bombs": 3,
		"bomb_type": "sticky",
		"desc": "Shotgun + Pump Shotgun + 3 Sticky Bombs",
		"accent": "purple"
	},
	{
		"name": "Sniper Recon",
		"primary": 7,
		"secondary": 8,
		"bombs": 3,
		"bomb_type": "mine",
		"desc": "Sniper + Auto Sniper + 3 Mine Bombs",
		"accent": "sky"
	},
	{
		"name": "Demolitionist",
		"primary": 10,
		"secondary": 9,
		"bombs": 4,
		"bomb_type": "cluster",
		"desc": "Bazooka + Deagle + 4 Cluster Bombs",
		"accent": "red"
	}
]


static func _get_network_manager() -> Node:
	var ml: MainLoop = Engine.get_main_loop()
	if ml is SceneTree:
		return (ml as SceneTree).root.get_node_or_null("NetworkManager")
	return null


static func is_weapon_allowed(weapon_id: int) -> bool:
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
	if weapon_id >= 11 and weapon_id <= 14:
		var nm: Node = _get_network_manager()
		if weapon_id == 12 and nm != null and not bool(nm.get("allow_explosives")):
			return 11
		return weapon_id
	var idx: int = wrapi(weapon_id, 0, RESOURCE_PATHS.size())
	if is_weapon_allowed(idx):
		return idx
	var allowed: Array[int] = get_allowed_weapon_ids()
	return allowed[0]


static func get_pickup_weapon_ids() -> Array[int]:
	var out: Array[int] = get_allowed_weapon_ids()
	var nm: Node = _get_network_manager()
	var exp_ok: bool = true if nm == null else bool(nm.get("allow_explosives"))
	out.append_array([11, 13, 14])
	if exp_ok:
		out.append(12)
	# Weight special weapons so they appear regularly on the map
	out.append_array([11, 13, 14])
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


static func get_weapon(weapon_id: int, skin_id: int = 0, rail_mod: int = 0) -> WeaponData:
	if weapon_id >= 11 and weapon_id <= 14:
		return _get_special_weapon(weapon_id)
	var idx: int = clampi(weapon_id, 0, RESOURCE_PATHS.size() - 1)
	var base: WeaponData = load(RESOURCE_PATHS[idx]) as WeaponData
	var w: WeaponData = (base.duplicate() as WeaponData) if base != null else _fallback_weapon(idx)

	if w.has_accessory_rail:
		if rail_mod == 1:
			# Suppressor attachment: tighter spread, smaller muzzle flash, quieter tone
			w.spread_deg *= 0.72
			w.muzzle_flash_scale = 0.35
			w.display_name = "M4A1 (Suppressed)"
		elif rail_mod == 2:
			# Tactical Scope attachment: extended zoom & precision
			w.scope_zoom = 0.90
			w.spread_deg *= 0.65
			w.display_name = "M4A1 (Scoped)"

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
			w.mag_size = 3
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
			w.description = "High-energy plasma bolt! Pickup only."
			w.damage = 46
			w.fire_interval = 0.36
			w.mag_size = 12
			w.reload_time = 1.6
			w.recoil_impulse = 95.0
			w.bullet_speed = 1180.0
			w.spread_deg = 1.0
			w.max_zoom_level = 4
			w.is_laser = true
			w.bullet_color = Color(0.28, 0.94, 1.0)
			w.custom_visual_style = "stun_bolt"
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
	return w
