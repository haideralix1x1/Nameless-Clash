extends Node

signal profile_changed
signal coins_changed(new_coins: int)
signal gun_skins_changed
signal agents_unlocked_changed
signal economy_config_changed

const ECONOMY_CONFIG_PATH: String = "res://assets/data/coin_economy.json"
const USER_ECONOMY_CONFIG_PATH: String = "user://coin_economy.json"
const DEFAULT_AGENT_UNLOCK_PRICE: int = 5000

# Starter unlocked agents (10 total):
# 0: Contra, 1: Mike Jones, 2: Bruski, 5: Warlord, 12: Jack-47,
# 13: Viper-X, 18: Stone, 19: Afera (Tribal Monk), 22: Jackson (Boxer), 23: Grimhare
const STARTER_UNLOCKED_AGENTS: Array[int] = [0, 1, 2, 5, 12, 13, 18, 19, 22, 23]

const GUN_SKIN_CATALOG: Array[Dictionary] = [
	{"key": "default",       "name": "Standard Issue",   "price": 0,   "sheet_row": 0, "tint": Color(1.0, 1.0, 1.0),   "bullet": Color(1.0, 0.85, 0.25), "badge": Color(0.75, 0.80, 0.88)},
	{"key": "desert_camo",   "name": "Desert Camo",      "price": 200, "sheet_row": 1, "tint": Color(0.95, 0.84, 0.64),"bullet": Color(1.0, 0.86, 0.45), "badge": Color(0.86, 0.74, 0.50)},
	{"key": "biohazard",     "name": "Toxic Biohazard",  "price": 300, "sheet_row": 2, "tint": Color(0.54, 1.0, 0.36), "bullet": Color(0.45, 1.0, 0.24), "badge": Color(0.46, 0.96, 0.28)},
	{"key": "ocean_wave",    "name": "Ocean Wave",       "price": 350, "sheet_row": 3, "tint": Color(0.32, 0.94, 1.0), "bullet": Color(0.24, 0.92, 1.0), "badge": Color(0.22, 0.88, 0.96)},
	{"key": "arctic",        "name": "Arctic Glacier",   "price": 400, "sheet_row": 4, "tint": Color(0.82, 0.96, 1.0), "bullet": Color(0.68, 0.94, 1.0), "badge": Color(0.72, 0.92, 1.0)},
	{"key": "neon",          "name": "Cyber Neon",       "price": 450, "sheet_row": 5, "tint": Color(0.56, 0.86, 1.0), "bullet": Color(0.22, 0.92, 1.0), "badge": Color(0.24, 0.84, 1.0)},
	{"key": "magma",         "name": "Molten Magma",     "price": 500, "sheet_row": 6, "tint": Color(1.0, 0.52, 0.26), "bullet": Color(1.0, 0.42, 0.14), "badge": Color(1.0, 0.46, 0.18)},
	{"key": "nebula",        "name": "Cosmic Nebula",    "price": 600, "sheet_row": 7, "tint": Color(0.86, 0.50, 1.0), "bullet": Color(0.84, 0.38, 1.0), "badge": Color(0.82, 0.42, 1.0)},
	{"key": "crimson_royal", "name": "Crimson Imperial", "price": 700, "sheet_row": 8, "tint": Color(1.0, 0.42, 0.44), "bullet": Color(1.0, 0.28, 0.30), "badge": Color(0.96, 0.28, 0.32)},
	{"key": "gold",          "name": "24K Royal Gold",   "price": 850, "sheet_row": 9, "tint": Color(1.0, 0.86, 0.34), "bullet": Color(1.0, 0.88, 0.24), "badge": Color(1.0, 0.84, 0.24)}
]
# Weapons whose columns in weapons_selection_sheet.png contain dedicated custom art for all 10 skin rows (no extra tint needed)
const CUSTOM_SKIN_ART_WEAPONS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 18, 20, 23]
# Weapons that never get skins (always shown with the base/default art)
const NO_SKIN_WEAPONS: Array[int] = [19]
const SHOP_WEAPON_IDS: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 18, 20, 23, 22]

const PROFILE_PATH: String = "user://player_profile.cfg"

const ARCHETYPES: Array[Dictionary] = [
	{
		"callsign": "Contra",
		"name": "Contra (The Soldier)",
		"desc": "Frontline chibi trooper with a Steel M1 Helmet, olive shirt, and dual chest ammo pouches.",
		"part_id": 0,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 9
	},
	{
		"callsign": "Mike Jones",
		"name": "Mike Jones (The Explorer)",
		"desc": "Rugged field scout wearing a wide Sun Hat, open utility vest, silver belt buckle, and heavy backpack.",
		"part_id": 1,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 1
	},
	{
		"callsign": "Bruski",
		"name": "Bruski (The Outlaw)",
		"desc": "Gritty bearded marksman with a dark Cowboy Hat, red neckerchief, dark vest, and thigh holster.",
		"part_id": 2,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 5
	},
	{
		"callsign": "Soulless",
		"name": "Soulless (Evil Being)",
		"desc": "Playful spectral phantom who pushes foes back, silences abilities, spawns decoys, and turns invisible.",
		"part_id": 27,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 4
	},
	{
		"callsign": "White Frost",
		"name": "White Frost (Spec-Ops)",
		"desc": "SWAT breaching specialist in a dark tactical helmet with twin white ski goggles.",
		"part_id": 4,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 3
	},
	{
		"callsign": "Warlord",
		"name": "Warlord (Viking Berserker)",
		"desc": "Fearsome northern raider with horned iron helm, braided orange beard, and round shield.",
		"part_id": 7,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 6
	},
	{
		"callsign": "Draken",
		"name": "Draken (Vampire)",
		"desc": "Crimson nocturnal lord commanding homing bats, blood spears, damage reduction, and bat-form ambushes.",
		"part_id": 26,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 4
	},
	{
		"callsign": "Yagami",
		"name": "Yagami (Shadow Ninja)",
		"desc": "Silent shinobi assassin with purple cloth mask, silver forehead plate, and back katana.",
		"part_id": 11,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 4
	},
	{
		"callsign": "Dead Buddy",
		"name": "Dead Buddy (Brain Zombie)",
		"desc": "Undead brawler with exposed pink brain, glowing yellow zombie eyes, and tattered jacket.",
		"part_id": 12,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 6
	},
	{
		"callsign": "Nothing",
		"name": "Nothing (Skull Skeleton)",
		"desc": "Risen bone warrior featuring hollow skull sockets, horned cap, and exposed ribcage.",
		"part_id": 13,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 7
	},
	{
		"callsign": "Wraith",
		"name": "Wraith (Undead)",
		"desc": "Haunting phantom floating in an alabaster shroud with grim reaper scythe slung behind.",
		"part_id": 14,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 4
	},
	{
		"callsign": "Pharaoh",
		"name": "Pharaoh (Ancient Mummy)",
		"desc": "Bandage-wrapped tomb guardian with glowing amber eyes and golden pharaoh band.",
		"part_id": 15,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 3
	},
	{
		"callsign": "Jack-47",
		"name": "Jack-47 (Cyber Robot)",
		"desc": "Heavy steel automaton powered by glowing yellow optic sensors and twin thrusters.",
		"part_id": 16,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 10
	},
	{
		"callsign": "Viper-X",
		"name": "Viper-X (Venom Snake)",
		"desc": "Deadly serpent warrior with emerald scales, flared cobra hood, and lethal venom fangs.",
		"part_id": 17,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 7
	},
	{
		"callsign": "Nyx",
		"name": "Nyx (Shadow Cat)",
		"desc": "Agile black feline fighter with pointed ears, golden collar bell, whiskers, and curled tail.",
		"part_id": 18,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 4
	},
	{
		"callsign": "Akuza",
		"name": "Akuza (Dragon Hero)",
		"desc": "Spiky emerald-haired champion equipped with ornate gold-trimmed fantasy armor and blade.",
		"part_id": 19,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 1
	},
	{
		"callsign": "Mirror Ogre",
		"name": "Mirror Ogre (Fierce Orc)",
		"desc": "Purple-skinned ogre warlord boasting twin ivory tusks, cyan mohawk, and bone necklace.",
		"part_id": 20,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 10
	},
	{
		"callsign": "Ignis",
		"name": "Ignis (Magma)",
		"desc": "Volcanic stone colossus pulsing with molten orange magma eyes and glowing rock cracks.",
		"part_id": 21,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 5
	},
	{
		"callsign": "Stone",
		"name": "Stone (Rocky Golem)",
		"desc": "Radiant pink quartz elemental crowned with sharp crystal spires and faceted stone armor.",
		"part_id": 22,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 8
	},
	{
		"callsign": "Afera",
		"name": "Afera (Tribal Monk)",
		"desc": "Battle-hardened brawler with crimson headband, prayer bead necklace, and wooden bo-staff.",
		"part_id": 23,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 0
	},
	{
		"callsign": "Raven",
		"name": "Raven (Shadow Corvus)",
		"desc": "Dark corvus mystic commanding homing ravens, telekinetic throws, and mind-reversing shadow smoke.",
		"part_id": 24,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 3
	},
	{
		"callsign": "Ray Lina",
		"name": "Ray Lina (Young Elf)",
		"desc": "Agile young elf prodigy who starts with random abilities and steals her slain enemy's kit on every kill.",
		"part_id": 25,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 7
	},
	{
		"callsign": "Jackson",
		"name": "Jackson (Heavyweight Boxer)",
		"desc": "Heavyweight Black boxer champion delivering huge boxy punches, running spears, sky-smashes, and knockout flurries.",
		"part_id": 29,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 6
	},
	{
		"callsign": "Grimhare",
		"name": "Grimhare (Cursed Hare)",
		"desc": "Fierce crimson-furred brawler hare in a dark navy vest with swift dashes, uppercuts, and a crimson flurry.",
		"part_id": 28,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 6
	}
]

const WEAPON_NAMES: Array[String] = [
	"AK47", "M16A4", "SCAR-L", "SMG", "Uzi",
	"Shotgun", "Pump Shotgun", "Sniper", "Auto Sniper", "Deagle", "Bazooka"
]

const WEAPON_SKIN_NAMES: Array[String] = ["Digital Camo", "Solid Matte", "Neon Tracer"]
const RAIL_MOD_NAMES: Array[String] = ["Iron Sights", "Suppressor", "Tactical Scope"]

const ARCHETYPE_ROLES: Array[String] = [
	"Infantry Trooper", "Field Adventurer", "Outback Marksman", "Evil Being",
	"Tactical Breacher", "Northern Raider", "Vampire Lord",
	"Shadow Assassin", "Undead Brawler", "Skull Skeleton", "Spectral Phantom",
	"Tomb Guardian", "Heavy Automaton", "Bio Specialist", "Feline Striker",
	"Blade Hero", "Ogre Warlord", "Lava Colossus", "Quartz Elemental",
	"Martial Master", "Dark Mystic", "Agile Elf Prodigy", "Heavyweight Boxer", "Brawler Hare"
]

const HEAD_NAMES: Array[String] = [
	"Steel Helmet", "Explorer Sun Hat", "Cowboy Hat", "Camo M1 Helmet",
	"SWAT Goggles Helm", "Spartan Plume", "Centurion Crest", "Viking Horns",
	"Crusader Great-Helm", "Royal Gold Crown", "Pirate Skull Hat", "Ninja Forehead Plate",
	"Exposed Brain", "Horned Skull Cap", "Ghost Pointed Hood", "Pharaoh Band",
	"Robot Antenna", "Bio-Hazard Crest", "Shadow Cat Ears", "Emerald Spiky Hair",
	"Cyan Orc Mohawk", "Volcanic Rock Crown", "Pink Crystal Spires", "Crimson Headband",
	"Corvus Shadow Hood", "Elven Silver Circlet"
]
const TORSO_NAMES: Array[String] = [
	"Olive Pouches", "Explorer Vest", "Outlaw Vest", "Camo Uniform",
	"SWAT Tactical Rig", "Spartan Cuirass", "Roman Lorica", "Viking Fur Jerkin",
	"Crusader Tabard", "Royal Ermine Robe", "Captain Coat", "Shinobi Gi",
	"Tattered Jacket", "Bone Ribcage", "Spectral Shroud", "Mummy Wrappings",
	"Mech Core Chassis", "Hazard Exo-Rig", "Cat Collar & Bell", "Dragon Scale Armor",
	"Orc Bone Harness", "Molten Rock Chest", "Crystal Facet Chest", "Prayer Beads Chest",
	"Shadow Cloak Tunic", "Forest Ranger Tunic"
]
const LEGS_NAMES: Array[String] = [
	"Olive Fatigues", "Field Khakis", "Outlaw Denim", "Camo Cargo",
	"Black SWAT Pants", "Spartan Greaves", "Roman Sandals", "Viking Fur Boots",
	"Chainmail Greaves", "Royal Crimson Pants", "Buccaneer Boots", "Shinobi Leggings",
	"Ripped Zombie Slacks", "Skeleton Shin Bones", "Floating Ghost Hem", "Bandaged Legs",
	"Robot Piston Legs", "Bio-Suit Greaves", "Black Cat Paws", "Hero Armor Greaves",
	"Orc Hide Boots", "Obsidian Stompers", "Crystal Pillar Legs", "Monk Martial Wraps",
	"Raven Shadow Boots", "Elven Woodland Boots"
]
const HANDS_NAMES: Array[String] = [
	"Bare Hands", "Adventurer Grip", "Outlaw Hands", "Camo Trooper",
	"SWAT Gloves", "Spartan Fists", "Roman Bracers", "Viking Fists",
	"Knight Gauntlets", "Royal Hands", "Pirate Grip", "Ninja Wraps",
	"Zombie Claws", "Skeletal Hands", "Ghost Hands", "Mummy Wraps",
	"Robot Pincers", "Bio-Armor Gloves", "Shadow Cat Paws", "Hero Gauntlets",
	"Purple Ogre Fists", "Boulder Fists", "Crystal Fists", "Taped Monk Fists",
	"Shadow Talon Gloves", "Elven Archer Bracers"
]
const ACC_NAMES: Array[String] = [
	"Infantry Pack", "Trail Backpack", "Thigh Holster", "Field Canteen",
	"Comms Pack", "Spartan Crimson Cape", "Centurion Mantle", "Viking Round Shield",
	"Templar Broadsword", "Royal Mantle Cape", "Pirate Cutlass", "Back Katana",
	"Toxic Pack", "Grave Pack", "Grim Reaper Scythe", "Relic Pack",
	"Twin Jet Thrusters", "Isotope Tank", "Black Cat Tail", "Hero Greatsword",
	"Ogre Cleaver", "Lava Spine", "Crystal Cluster", "Wooden Bo-Staff",
	"Corvus Wing Mantle", "Elven Quiver & Bow"
]
const SKIN_NAMES: Array[String] = [
	"Neutral Soldier", "Smiling Explorer", "Bearded Outlaw", "Grinning Commando",
	"Glasses Agent", "Stern Spartan", "Scowling Roman", "Braided Beard",
	"Knight Visor Eyes", "White-Beard King", "Eyepatch Pirate", "Masked Ninja",
	"Drooling Zombie", "Hollow Skull", "Spooky Ghost Face", "Glowing-Eye Mummy",
	"Yellow-Optic Bot", "Green Gas-Mask", "Whiskered Cat", "Amber-Eye Hero",
	"Tusked Purple Orc", "Magma Cracked Face", "Pink Gem Face", "Bearded Monk",
	"Violet-Eye Mystic", "Pointed-Ear Elf"
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
var taunt_id: int = 0
var coins: int = 500
var owned_gun_skins: Dictionary = {}
var equipped_gun_skins: Dictionary = {}
var unlocked_agents: Array[int] = []

var kill_reward: int = 25
var treasure_reward: int = 15
var win_reward: int = 100
var match_reward: int = 30
var agent_unlock_price: int = DEFAULT_AGENT_UNLOCK_PRICE
var gun_skin_prices: Dictionary = {}
var premium_gun_skins: Dictionary = {}


func _ready() -> void:
	load_economy_config()
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


static func get_archetype_part_id(arch_idx: int) -> int:
	var idx: int = clampi(arch_idx, 0, ARCHETYPES.size() - 1)
	return clampi(int(ARCHETYPES[idx].get("part_id", idx)), 0, ModularCharacter.MAX_PART_INDEX)


static func build_archetype_avatar_dict(arch_idx: int) -> Dictionary:
	var idx: int = clampi(arch_idx, 0, ARCHETYPES.size() - 1)
	var arch: Dictionary = ARCHETYPES[idx]
	var parts: Dictionary = arch.get("parts", {})
	var base_part: int = get_archetype_part_id(idx)
	return {
		"archetype_id": idx,
		"skin_id": int(parts.get("head", base_part)),
		"head_id": int(parts.get("head", base_part)),
		"torso_id": int(parts.get("torso", base_part)),
		"legs_id": int(parts.get("legs", base_part)),
		"hands_id": int(parts.get("hands", base_part)),
		"accessories_id": int(parts.get("accessories", base_part)),
		"shirt_color": arch["shirt"],
		"pants_color": arch["pants"],
		"skin_color": arch["skin"],
		"helmet_color": arch["helmet"],
		"gear_color": arch["gear"],
		"primary_weapon_id": int(arch["weapon"]),
		"secondary_weapon_id": 9,
		"weapon_skin_id": 0,
		"m4a1_rail_mod": 0,
		"taunt_id": 0
	}


func apply_archetype_preset(arch_idx: int, emit_save: bool = true) -> void:
	var idx: int = clampi(arch_idx, 0, ARCHETYPES.size() - 1)
	var arch: Dictionary = ARCHETYPES[idx]
	var parts: Dictionary = arch.get("parts", {})
	var base_part: int = get_archetype_part_id(idx)
	archetype_id = idx
	skin_id = int(parts.get("head", base_part))
	head_id = int(parts.get("head", base_part))
	torso_id = int(parts.get("torso", base_part))
	legs_id = int(parts.get("legs", base_part))
	hands_id = int(parts.get("hands", base_part))
	accessories_id = int(parts.get("accessories", base_part))

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


func _get_profile_path() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--profile="):
			var slot: String = a.substr(10).strip_edges()
			if not slot.is_empty():
				return "user://player_profile_%s.cfg" % slot
	return PROFILE_PATH


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_get_profile_path()) != OK:
		save_profile()
		return

	player_name = str(cfg.get_value("profile", "player_name", player_name)).strip_edges().left(16)
	if player_name.is_empty():
		player_name = "Trooper"
	var max_idx: int = ARCHETYPES.size() - 1
	var max_part: int = ModularCharacter.MAX_PART_INDEX
	archetype_id = clampi(int(cfg.get_value("modular", "archetype_id", 0)), 0, max_idx)
	var def_part: int = get_archetype_part_id(archetype_id)
	skin_id = clampi(int(cfg.get_value("modular", "skin_id", def_part)), 0, max_part)
	head_id = clampi(int(cfg.get_value("modular", "head_id", def_part)), 0, max_part)
	torso_id = clampi(int(cfg.get_value("modular", "torso_id", def_part)), 0, max_part)
	legs_id = clampi(int(cfg.get_value("modular", "legs_id", def_part)), 0, max_part)
	hands_id = clampi(int(cfg.get_value("modular", "hands_id", def_part)), 0, max_part)
	accessories_id = clampi(int(cfg.get_value("modular", "accessories_id", def_part)), 0, max_part)

	shirt_color = cfg.get_value("colors", "shirt_color", shirt_color) as Color
	pants_color = cfg.get_value("colors", "pants_color", pants_color) as Color
	skin_color = cfg.get_value("colors", "skin_color", skin_color) as Color
	helmet_color = cfg.get_value("colors", "helmet_color", helmet_color) as Color
	gear_color = cfg.get_value("colors", "gear_color", gear_color) as Color
	if archetype_id == 22:
		if skin_id == 23 and head_id == 23 and torso_id == 23:
			skin_id = 30
			head_id = 30
			torso_id = 30
			legs_id = 30
			hands_id = 30
			accessories_id = 30
		if shirt_color.is_equal_approx(Color(0.88, 0.16, 0.20)) or skin_color.is_equal_approx(Color(0.38, 0.23, 0.15)):
			shirt_color = Color.WHITE
			pants_color = Color.WHITE
			skin_color = Color.WHITE
			helmet_color = Color.WHITE
			gear_color = Color.WHITE

	primary_weapon_id = clampi(int(cfg.get_value("loadout", "primary_weapon_id", 0)), 0, WEAPON_NAMES.size() - 1)
	secondary_weapon_id = clampi(int(cfg.get_value("loadout", "secondary_weapon_id", 9)), 0, WEAPON_NAMES.size() - 1)
	weapon_skin_id = clampi(int(cfg.get_value("loadout", "weapon_skin_id", 0)), 0, WEAPON_SKIN_NAMES.size() - 1)
	m4a1_rail_mod = clampi(int(cfg.get_value("loadout", "m4a1_rail_mod", 0)), 0, RAIL_MOD_NAMES.size() - 1)
	taunt_id = clampi(int(cfg.get_value("loadout", "taunt_id", 0)), 0, AgentData.TAUNTS.size() - 1)
	coins = maxi(0, int(cfg.get_value("economy", "coins", 500)))
	var raw_owned: Variant = cfg.get_value("economy", "owned_gun_skins", {})
	owned_gun_skins = (raw_owned as Dictionary).duplicate(true) if raw_owned is Dictionary else {}
	var raw_eq: Variant = cfg.get_value("economy", "equipped_gun_skins", {})
	equipped_gun_skins = (raw_eq as Dictionary).duplicate(true) if raw_eq is Dictionary else {}
	unlocked_agents.clear()
	var raw_agents: Variant = cfg.get_value("economy", "unlocked_agents", [])
	if raw_agents is Array:
		for a_id in (raw_agents as Array):
			var ai: int = int(a_id)
			if not unlocked_agents.has(ai):
				unlocked_agents.append(ai)
	if not is_agent_unlocked(archetype_id, false):
		apply_archetype_preset(0, false)


func load_economy_config() -> void:
	kill_reward = 25
	treasure_reward = 15
	win_reward = 100
	match_reward = 30
	agent_unlock_price = DEFAULT_AGENT_UNLOCK_PRICE
	gun_skin_prices = {}
	premium_gun_skins = {}
	for path in [ECONOMY_CONFIG_PATH, USER_ECONOMY_CONFIG_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var txt: String = FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			var d: Dictionary = parsed as Dictionary
			if d.has("kill_reward"):
				kill_reward = maxi(0, int(d["kill_reward"]))
			if d.has("treasure_reward"):
				treasure_reward = maxi(0, int(d["treasure_reward"]))
			if d.has("win_reward"):
				win_reward = maxi(0, int(d["win_reward"]))
			if d.has("match_reward"):
				match_reward = maxi(0, int(d["match_reward"]))
			if d.has("agent_unlock_price"):
				agent_unlock_price = maxi(0, int(d["agent_unlock_price"]))
			if d.has("gun_skin_prices") and d["gun_skin_prices"] is Dictionary:
				var gp: Dictionary = d["gun_skin_prices"] as Dictionary
				for wk in gp.keys():
					if gp[wk] is Dictionary:
						var wkey := str(wk)
						if not gun_skin_prices.has(wkey):
							gun_skin_prices[wkey] = {}
						for sk in (gp[wk] as Dictionary).keys():
							(gun_skin_prices[wkey] as Dictionary)[str(sk)] = maxi(0, int((gp[wk] as Dictionary)[sk]))
			if d.has("premium_gun_skins") and d["premium_gun_skins"] is Dictionary:
				var pg: Dictionary = d["premium_gun_skins"] as Dictionary
				for wk in pg.keys():
					if pg[wk] is Dictionary:
						var wkey := str(wk)
						if not premium_gun_skins.has(wkey):
							premium_gun_skins[wkey] = {}
						for sk in (pg[wk] as Dictionary).keys():
							if bool((pg[wk] as Dictionary)[sk]):
								(premium_gun_skins[wkey] as Dictionary)[str(sk)] = true


func save_economy_config(save_to_project: bool = true) -> bool:
	var payload: Dictionary = {
		"kill_reward": kill_reward,
		"treasure_reward": treasure_reward,
		"win_reward": win_reward,
		"match_reward": match_reward,
		"agent_unlock_price": agent_unlock_price,
		"gun_skin_prices": gun_skin_prices,
		"premium_gun_skins": premium_gun_skins
	}
	var json_txt: String = JSON.stringify(payload, "\t")
	var ok_any: bool = false
	var uf := FileAccess.open(USER_ECONOMY_CONFIG_PATH, FileAccess.WRITE)
	if uf != null:
		uf.store_string(json_txt)
		uf.close()
		ok_any = true
	if save_to_project:
		var abs_path: String = ProjectSettings.globalize_path(ECONOMY_CONFIG_PATH)
		var pf := FileAccess.open(abs_path, FileAccess.WRITE)
		if pf != null:
			pf.store_string(json_txt)
			pf.close()
			ok_any = true
	economy_config_changed.emit()
	return ok_any


func reset_economy_defaults() -> void:
	kill_reward = 25
	treasure_reward = 15
	win_reward = 100
	match_reward = 30
	agent_unlock_price = DEFAULT_AGENT_UNLOCK_PRICE
	gun_skin_prices.clear()
	premium_gun_skins.clear()
	economy_config_changed.emit()


func get_kill_reward() -> int:
	return kill_reward


func get_treasure_reward() -> int:
	return treasure_reward


func get_win_reward() -> int:
	return win_reward


func get_match_reward() -> int:
	return match_reward


func get_agent_unlock_price() -> int:
	return agent_unlock_price


func get_gun_skin_price(weapon_id: int, skin_key: String) -> int:
	if skin_key == "default" or skin_key.is_empty():
		return 0
	var wk := str(weapon_id)
	if gun_skin_prices.has(wk) and gun_skin_prices[wk] is Dictionary:
		var wd: Dictionary = gun_skin_prices[wk] as Dictionary
		if wd.has(skin_key):
			return maxi(0, int(wd[skin_key]))
	return int(get_gun_skin_def(skin_key).get("price", 0))


func set_gun_skin_price(weapon_id: int, skin_key: String, price: int) -> void:
	if skin_key == "default" or skin_key.is_empty():
		return
	var wk := str(weapon_id)
	if not gun_skin_prices.has(wk) or not (gun_skin_prices[wk] is Dictionary):
		gun_skin_prices[wk] = {}
	(gun_skin_prices[wk] as Dictionary)[skin_key] = maxi(0, price)


func is_gun_skin_premium(weapon_id: int, skin_key: String) -> bool:
	if skin_key == "default" or skin_key.is_empty():
		return false
	var wk := str(weapon_id)
	if premium_gun_skins.has(wk) and premium_gun_skins[wk] is Dictionary:
		return bool((premium_gun_skins[wk] as Dictionary).get(skin_key, false))
	return false


func set_gun_skin_premium(weapon_id: int, skin_key: String, is_premium: bool) -> void:
	if skin_key == "default" or skin_key.is_empty():
		return
	var wk := str(weapon_id)
	if not premium_gun_skins.has(wk) or not (premium_gun_skins[wk] is Dictionary):
		premium_gun_skins[wk] = {}
	if is_premium:
		(premium_gun_skins[wk] as Dictionary)[skin_key] = true
	else:
		(premium_gun_skins[wk] as Dictionary).erase(skin_key)


func is_agent_unlocked(arch_idx: int, allow_practice: bool = false) -> bool:
	if allow_practice:
		return true
	var idx: int = clampi(arch_idx, 0, ARCHETYPES.size() - 1)
	if STARTER_UNLOCKED_AGENTS.has(idx):
		return true
	return unlocked_agents.has(idx)


func buy_agent(arch_idx: int) -> bool:
	var idx: int = clampi(arch_idx, 0, ARCHETYPES.size() - 1)
	if is_agent_unlocked(idx, false):
		return true
	var price: int = get_agent_unlock_price()
	if not spend_coins(price):
		return false
	if not unlocked_agents.has(idx):
		unlocked_agents.append(idx)
	save_profile()
	agents_unlocked_changed.emit()
	notify_changed()
	return true


func get_gun_skin_def(skin_key: String) -> Dictionary:
	for s in GUN_SKIN_CATALOG:
		if str(s["key"]) == skin_key:
			return s
	return GUN_SKIN_CATALOG[0]


func get_gun_skin_tint(weapon_id: int, skin_key: String) -> Color:
	if CUSTOM_SKIN_ART_WEAPONS.has(weapon_id) or NO_SKIN_WEAPONS.has(weapon_id):
		return Color.WHITE
	return get_gun_skin_def(skin_key).get("tint", Color.WHITE) as Color


func owns_gun_skin(weapon_id: int, skin_key: String) -> bool:
	if skin_key == "default" or skin_key.is_empty():
		return true
	var wk := str(weapon_id)
	if owned_gun_skins.has(wk) and owned_gun_skins[wk] is Array:
		return (owned_gun_skins[wk] as Array).has(skin_key)
	return false


func get_equipped_gun_skin(weapon_id: int) -> String:
	if NO_SKIN_WEAPONS.has(weapon_id):
		return "default"
	var wk := str(weapon_id)
	if equipped_gun_skins.has(wk):
		var sk: String = str(equipped_gun_skins[wk])
		if owns_gun_skin(weapon_id, sk):
			return sk
	return "default"


func add_coins(amount: int) -> void:
	if amount <= 0:
		return
	coins += amount
	save_profile()
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if amount < 0 or coins < amount:
		return false
	coins -= amount
	save_profile()
	coins_changed.emit(coins)
	return true


static func format_coins(amount: int) -> String:
	var neg: bool = amount < 0
	var v: float = absf(float(amount))
	var out: String = ""
	if v >= 1_000_000_000.0:
		out = _trim_compact_num(v / 1_000_000_000.0, 2) + "B"
	elif v >= 1_000_000.0:
		out = _trim_compact_num(v / 1_000_000.0, 2) + "M"
	elif v >= 1_000.0:
		out = _trim_compact_num(v / 1_000.0, 1) + "K"
	else:
		out = str(int(roundf(v)))
	return ("-" + out) if neg else out


static func _trim_compact_num(val: float, decimals: int) -> String:
	var factor: float = pow(10.0, decimals)
	var rounded: float = floorf(val * factor + 0.0001) / factor
	var s: String = ("%." + str(decimals) + "f") % rounded
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s


func buy_gun_skin(weapon_id: int, skin_key: String) -> bool:
	if owns_gun_skin(weapon_id, skin_key):
		equip_gun_skin(weapon_id, skin_key)
		return true
	var price: int = get_gun_skin_price(weapon_id, skin_key)
	if not spend_coins(price):
		return false
	var wk := str(weapon_id)
	if not owned_gun_skins.has(wk) or not (owned_gun_skins[wk] is Array):
		owned_gun_skins[wk] = ["default"]
	var arr: Array = owned_gun_skins[wk] as Array
	if not arr.has(skin_key):
		arr.append(skin_key)
	equipped_gun_skins[wk] = skin_key
	save_profile()
	gun_skins_changed.emit()
	notify_changed()
	return true


func equip_gun_skin(weapon_id: int, skin_key: String) -> void:
	if not owns_gun_skin(weapon_id, skin_key):
		return
	equipped_gun_skins[str(weapon_id)] = skin_key
	save_profile()
	gun_skins_changed.emit()
	notify_changed()


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
	cfg.set_value("loadout", "taunt_id", taunt_id)
	cfg.set_value("economy", "coins", coins)
	cfg.set_value("economy", "owned_gun_skins", owned_gun_skins)
	cfg.set_value("economy", "equipped_gun_skins", equipped_gun_skins)
	cfg.set_value("economy", "unlocked_agents", unlocked_agents)
	cfg.save(_get_profile_path())


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
		"equipped_gun_skins": equipped_gun_skins.duplicate(true),
		"m4a1_rail_mod": m4a1_rail_mod,
		"taunt_id": taunt_id
	}


static func sanitize_avatar(d: Dictionary) -> Dictionary:
	var max_idx: int = ARCHETYPES.size() - 1
	var max_part: int = ModularCharacter.MAX_PART_INDEX
	return {
		"archetype_id": clampi(int(d.get("archetype_id", 0)), 0, max_idx),
		"skin_id": clampi(int(d.get("skin_id", 0)), 0, max_part),
		"head_id": clampi(int(d.get("head_id", 0)), 0, max_part),
		"torso_id": clampi(int(d.get("torso_id", 0)), 0, max_part),
		"legs_id": clampi(int(d.get("legs_id", 0)), 0, max_part),
		"hands_id": clampi(int(d.get("hands_id", 0)), 0, max_part),
		"accessories_id": clampi(int(d.get("accessories_id", 0)), 0, max_part),
		"shirt_color": d.get("shirt_color", Color.WHITE),
		"pants_color": d.get("pants_color", Color.WHITE),
		"skin_color": d.get("skin_color", Color.WHITE),
		"helmet_color": d.get("helmet_color", Color.WHITE),
		"gear_color": d.get("gear_color", Color.WHITE),
		"primary_weapon_id": clampi(int(d.get("primary_weapon_id", 0)), 0, WEAPON_NAMES.size() - 1),
		"secondary_weapon_id": clampi(int(d.get("secondary_weapon_id", 9)), 0, WEAPON_NAMES.size() - 1),
		"weapon_skin_id": clampi(int(d.get("weapon_skin_id", 0)), 0, WEAPON_SKIN_NAMES.size() - 1),
		"m4a1_rail_mod": clampi(int(d.get("m4a1_rail_mod", 0)), 0, RAIL_MOD_NAMES.size() - 1),
		"taunt_id": clampi(int(d.get("taunt_id", 0)), 0, AgentData.TAUNTS.size() - 1)
	}
