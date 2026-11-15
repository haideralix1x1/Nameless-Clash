extends Node

signal profile_changed

const PROFILE_PATH: String = "user://player_profile.cfg"

const ARCHETYPES: Array[Dictionary] = [
	{
		"name": "The Soldier",
		"desc": "Frontline chibi trooper with a Steel M1 Helmet, olive shirt, and dual chest ammo pouches.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 0
	},
	{
		"name": "The Explorer",
		"desc": "Rugged field scout wearing a wide Sun Hat, open utility vest, silver belt buckle, and heavy backpack.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 1
	},
	{
		"name": "The Outlaw",
		"desc": "Gritty bearded marksman with a dark Cowboy Hat, red neckerchief, dark vest, and thigh holster.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 5
	},
	{
		"name": "The Commander",
		"desc": "Field officer in a crimson beret, gold insignia, and reinforced field chest rig.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 2
	},
	{
		"name": "The Spec-Ops",
		"desc": "Night-ops specialist equipped with helmet NVG optics and stealth ballistic vest.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 3
	},
	{
		"name": "The Enforcer",
		"desc": "Heavy riot unit protected by full visor helmet, armored kneepads, and chest plates.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 6
	},
	{
		"name": "The Rebel",
		"desc": "Street fighter in an urban hood, crimson scarf wrap, and denim tactical gear.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 0
	},
	{
		"name": "The Scout",
		"desc": "High-mobility runner with cap, comms headset, and desert light rig.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 4
	},
	{
		"name": "The Cyborg",
		"desc": "Cybernetic fighter featuring metallic plating and glowing cyan optic crest.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 7
	},
	{
		"name": "The Breacher",
		"desc": "Armored vanguard wearing an oversized blast helmet and gold visor.",
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 2
	}
]

const WEAPON_NAMES: Array[String] = [
	"AK-47", "M4A1", "SCAR-H", "MP5", "Kriss Vector",
	"SPAS-12", "Remington 870", "AWM", "Dragunov SVD", "Glock 17", "RPG-7"
]

const WEAPON_SKIN_NAMES: Array[String] = ["Digital Camo", "Solid Matte", "Neon Tracer"]
const RAIL_MOD_NAMES: Array[String] = ["Iron Sights", "Suppressor", "Tactical Scope"]

const ARCHETYPE_ROLES: Array[String] = [
	"Infantry Trooper",
	"Field Adventurer",
	"Outback Marksman",
	"Squad Officer",
	"Night Operative",
	"Riot Breaker",
	"Urban Fighter",
	"Recon Runner",
	"Tech Warrior",
	"Heavy Breacher"
]

const HEAD_NAMES: Array[String] = [
	"Steel Helmet", "Explorer Sun Hat", "Cowboy Hat", "Officer Beret", "NVG Helmet",
	"Riot Shield Helm", "Rebel Hood", "Scout Cap", "Cyber Crest", "Blast Helmet"
]
const TORSO_NAMES: Array[String] = [
	"Olive Pouches", "Explorer Vest", "Outlaw Vest", "Command Rig", "Stealth Suit",
	"Riot Armor", "Rebel Coat", "Light Harness", "Synth Chassis", "Breach Plate"
]
const LEGS_NAMES: Array[String] = [
	"Olive Fatigues", "Field Khakis", "Outlaw Denim", "Officer Boots", "Spec-Ops Pants",
	"Riot Kneepads", "Street Pants", "Scout Cargo", "Cyber Greaves", "Heavy Treads"
]
const HANDS_NAMES: Array[String] = [
	"Bare Hands", "Adventurer Grip", "Outlaw Hands", "Officer Hands", "Stealth Gloves",
	"Riot Gauntlets", "Rebel Grip", "Scout Hands", "Cyber Claws", "Heavy Mitts"
]
const ACC_NAMES: Array[String] = [
	"Infantry Pack", "Trail Backpack", "Thigh Holster", "Comms Unit", "NVG Pack",
	"Riot Thrusters", "Bandolier Pack", "Recon Pack", "Plasma Pack", "Jet Rig"
]
const SKIN_NAMES: Array[String] = [
	"Neutral Face", "Smiling Explorer", "Gritty Bearded", "Stern Vet", "Tactical Mask",
	"Riot Visor", "Masked Rebel", "Focused Scout", "Android Face", "Armored Face"
]

const COLOR_SWATCHES: Array[Color] = [
	Color.WHITE,             # Original / Natural Colors
	Color(0.58, 0.72, 0.45), # Olive Tint
	Color(0.95, 0.84, 0.66), # Desert Sand
	Color(0.45, 0.66, 0.96), # Spec-Ops Blue
	Color(0.96, 0.44, 0.44), # Crimson Red
	Color(0.98, 0.68, 0.34), # Hazard Orange
	Color(0.98, 0.85, 0.42), # Gold
	Color(0.44, 0.48, 0.56), # Stealth Slate
	Color(0.76, 0.80, 0.86), # Urban Steel
	Color(0.46, 0.94, 0.98), # Cyber Cyan
	Color(0.80, 0.58, 0.98), # Neon Purple
	Color(0.95, 0.80, 0.68)  # Warm Peach
]

const MILITARY_PALETTES: Array[Dictionary] = [
	{"name": "Original Art", "shirt": Color.WHITE, "pants": Color.WHITE, "gear": Color.WHITE},
	{"name": "Olive Drab", "shirt": Color(0.72, 0.84, 0.58), "pants": Color(0.65, 0.76, 0.52), "gear": Color(0.68, 0.78, 0.55)},
	{"name": "Desert Tan", "shirt": Color(0.98, 0.86, 0.68), "pants": Color(0.88, 0.76, 0.58), "gear": Color(0.84, 0.72, 0.54)},
	{"name": "Urban Gray", "shirt": Color(0.76, 0.80, 0.86), "pants": Color(0.62, 0.68, 0.76), "gear": Color(0.58, 0.64, 0.72)},
	{"name": "Crimson Red", "shirt": Color(0.98, 0.52, 0.52), "pants": Color(0.80, 0.46, 0.48), "gear": Color(0.82, 0.42, 0.44)},
	{"name": "Navy SpecOps", "shirt": Color(0.54, 0.74, 0.98), "pants": Color(0.46, 0.62, 0.88), "gear": Color(0.48, 0.64, 0.90)}
]

var player_name: String = "Trooper"
var archetype_id: int = 0
var skin_id: int = 0
var head_id: int = 0
var torso_id: int = 0
var legs_id: int = 0
var hands_id: int = 0
var accessories_id: int = 0

var shirt_color: Color = Color.WHITE
var pants_color: Color = Color.WHITE
var skin_color: Color = Color.WHITE
var helmet_color: Color = Color.WHITE
var gear_color: Color = Color.WHITE

var primary_weapon_id: int = 0
var secondary_weapon_id: int = 9
var weapon_skin_id: int = 0
var m4a1_rail_mod: int = 0


func _ready() -> void:
	player_name = _default_name()
	apply_archetype_preset(0, false)
	load_profile()


func _default_name() -> String:
	var u: String = OS.get_environment("USERNAME")
	if u.is_empty():
		u = OS.get_environment("USER")
	if u.is_empty():
		return "Trooper_%d" % randi_range(10, 99)
	return u.left(14)


func apply_archetype_preset(arch_idx: int, emit_save: bool = true) -> void:
	var idx: int = clampi(arch_idx, 0, ARCHETYPES.size() - 1)
	archetype_id = idx
	skin_id = idx
	head_id = idx
	torso_id = idx
	legs_id = idx
	hands_id = idx
	accessories_id = idx

	var arch: Dictionary = ARCHETYPES[idx]
	shirt_color = arch["shirt"]
	pants_color = arch["pants"]
	skin_color = arch["skin"]
	helmet_color = arch["helmet"]
	gear_color = arch["gear"]
	primary_weapon_id = int(arch["weapon"])

	if emit_save:
		notify_changed()


func apply_palette(palette_idx: int) -> void:
	var pal: Dictionary = MILITARY_PALETTES[clampi(palette_idx, 0, MILITARY_PALETTES.size() - 1)]
	shirt_color = pal["shirt"]
	pants_color = pal["pants"]
	gear_color = pal["gear"]
	helmet_color = pal["shirt"]
	notify_changed()


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		save_profile()
		return

	player_name = str(cfg.get_value("profile", "player_name", player_name)).strip_edges().left(16)
	if player_name.is_empty():
		player_name = "Trooper"
	archetype_id = clampi(int(cfg.get_value("modular", "archetype_id", 0)), 0, 9)
	skin_id = clampi(int(cfg.get_value("modular", "skin_id", archetype_id)), 0, 9)
	head_id = clampi(int(cfg.get_value("modular", "head_id", archetype_id)), 0, 9)
	torso_id = clampi(int(cfg.get_value("modular", "torso_id", archetype_id)), 0, 9)
	legs_id = clampi(int(cfg.get_value("modular", "legs_id", archetype_id)), 0, 9)
	hands_id = clampi(int(cfg.get_value("modular", "hands_id", archetype_id)), 0, 9)
	accessories_id = clampi(int(cfg.get_value("modular", "accessories_id", archetype_id)), 0, 9)

	shirt_color = cfg.get_value("colors", "shirt_color", shirt_color) as Color
	pants_color = cfg.get_value("colors", "pants_color", pants_color) as Color
	skin_color = cfg.get_value("colors", "skin_color", skin_color) as Color
	helmet_color = cfg.get_value("colors", "helmet_color", helmet_color) as Color
	gear_color = cfg.get_value("colors", "gear_color", gear_color) as Color

	primary_weapon_id = clampi(int(cfg.get_value("loadout", "primary_weapon_id", 0)), 0, WEAPON_NAMES.size() - 1)
	secondary_weapon_id = clampi(int(cfg.get_value("loadout", "secondary_weapon_id", 9)), 0, WEAPON_NAMES.size() - 1)
	weapon_skin_id = clampi(int(cfg.get_value("loadout", "weapon_skin_id", 0)), 0, WEAPON_SKIN_NAMES.size() - 1)
	m4a1_rail_mod = clampi(int(cfg.get_value("loadout", "m4a1_rail_mod", 0)), 0, RAIL_MOD_NAMES.size() - 1)


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "player_name", player_name)
	cfg.set_value("modular", "archetype_id", archetype_id)
	cfg.set_value("modular", "skin_id", skin_id)
	cfg.set_value("modular", "head_id", head_id)
	cfg.set_value("modular", "torso_id", torso_id)
	cfg.set_value("modular", "legs_id", legs_id)
	cfg.set_value("modular", "hands_id", hands_id)
	cfg.set_value("modular", "accessories_id", accessories_id)

	cfg.set_value("colors", "shirt_color", shirt_color)
	cfg.set_value("colors", "pants_color", pants_color)
	cfg.set_value("colors", "skin_color", skin_color)
	cfg.set_value("colors", "helmet_color", helmet_color)
	cfg.set_value("colors", "gear_color", gear_color)

	cfg.set_value("loadout", "primary_weapon_id", primary_weapon_id)
	cfg.set_value("loadout", "secondary_weapon_id", secondary_weapon_id)
	cfg.set_value("loadout", "weapon_skin_id", weapon_skin_id)
	cfg.set_value("loadout", "m4a1_rail_mod", m4a1_rail_mod)
	cfg.save(PROFILE_PATH)


func notify_changed() -> void:
	save_profile()
	profile_changed.emit()
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").sync_local_profile()


func to_dict() -> Dictionary:
	return {
		"archetype_id": archetype_id,
		"skin_id": skin_id,
		"head_id": head_id,
		"torso_id": torso_id,
		"legs_id": legs_id,
		"hands_id": hands_id,
		"accessories_id": accessories_id,
		"shirt_color": shirt_color,
		"pants_color": pants_color,
		"skin_color": skin_color,
		"helmet_color": helmet_color,
		"gear_color": gear_color,
		"primary_weapon_id": primary_weapon_id,
		"secondary_weapon_id": secondary_weapon_id,
		"weapon_skin_id": weapon_skin_id,
		"m4a1_rail_mod": m4a1_rail_mod
	}


static func sanitize_avatar(d: Dictionary) -> Dictionary:
	return {
		"archetype_id": clampi(int(d.get("archetype_id", 0)), 0, 9),
		"skin_id": clampi(int(d.get("skin_id", 0)), 0, 9),
		"head_id": clampi(int(d.get("head_id", 0)), 0, 9),
		"torso_id": clampi(int(d.get("torso_id", 0)), 0, 9),
		"legs_id": clampi(int(d.get("legs_id", 0)), 0, 9),
		"hands_id": clampi(int(d.get("hands_id", 0)), 0, 9),
		"accessories_id": clampi(int(d.get("accessories_id", 0)), 0, 9),
		"shirt_color": d.get("shirt_color", Color.WHITE),
		"pants_color": d.get("pants_color", Color.WHITE),
		"skin_color": d.get("skin_color", Color.WHITE),
		"helmet_color": d.get("helmet_color", Color.WHITE),
		"gear_color": d.get("gear_color", Color.WHITE),
		"primary_weapon_id": clampi(int(d.get("primary_weapon_id", 0)), 0, WEAPON_NAMES.size() - 1),
		"secondary_weapon_id": clampi(int(d.get("secondary_weapon_id", 9)), 0, WEAPON_NAMES.size() - 1),
		"weapon_skin_id": clampi(int(d.get("weapon_skin_id", 0)), 0, WEAPON_SKIN_NAMES.size() - 1),
		"m4a1_rail_mod": clampi(int(d.get("m4a1_rail_mod", 0)), 0, RAIL_MOD_NAMES.size() - 1)
	}
