extends Node

signal profile_changed

const PROFILE_PATH: String = "user://player_profile.cfg"

const ARCHETYPES: Array[Dictionary] = [
	{
		"callsign": "Contra",
		"name": "Contra (The Soldier)",
		"desc": "Frontline chibi trooper with a Steel M1 Helmet, olive shirt, and dual chest ammo pouches.",
		"part_id": 0,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 0
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
		"callsign": "Rook Frost",
		"name": "Rook Frost (Spec-Ops)",
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
		"shirt": Color(0.75, 0.14, 0.22), "pants": Color(0.22, 0.14, 0.22),
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color(0.65, 0.12, 0.22),
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
		"name": "Wraith (Spooky Ghost)",
		"desc": "Haunting phantom floating in an alabaster shroud with grim reaper scythe slung behind.",
		"part_id": 14,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 4
	},
	{
		"callsign": "Mummy",
		"name": "Mummy (Ancient Mummy)",
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
		"name": "Viper-X (Bio-Hazard Cyborg)",
		"desc": "Toxic hazard trooper sealed inside an emerald gas-mask visor and pressurized rig.",
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
		"name": "Ignis (Magma Golem)",
		"desc": "Volcanic stone colossus pulsing with molten orange magma eyes and glowing rock cracks.",
		"part_id": 21,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 5
	},
	{
		"callsign": "Prism",
		"name": "Prism (Crystal Golem)",
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
		"part_id": 23,
		"shirt": Color.WHITE, "pants": Color.WHITE,
		"skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE,
		"weapon": 6
	}
]

const WEAPON_NAMES: Array[String] = [
	"AK47", "M4A1", "SCAR-H", "SMG", "Uzi",
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
	"Martial Master", "Dark Mystic", "Agile Elf Prodigy", "Heavyweight Boxer"
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
	if archetype_id == 22 and (shirt_color.is_equal_approx(Color(0.88, 0.16, 0.20)) or skin_color.is_equal_approx(Color(0.38, 0.23, 0.15))):
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
