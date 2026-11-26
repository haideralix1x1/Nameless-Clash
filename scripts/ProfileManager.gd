extends Node

signal profile_changed
signal coins_changed(new_coins: int)
signal gun_skins_changed
signal agents_unlocked_changed
signal economy_config_changed
signal new_badges_changed

const ECONOMY_CONFIG_PATH: String = "res://assets/data/coin_economy.json"
const USER_ECONOMY_CONFIG_PATH: String = "user://coin_economy.json"
const CRATE_TABLES_PATH: String = "res://assets/data/crate_tables.json"
const USER_CRATE_TABLES_PATH: String = "user://crate_tables.json"
const DEFAULT_AGENT_UNLOCK_PRICE: int = 5000
const DAILY_BONUS_COINS: int = 100
const STANDARD_CRATE_PRICE: int = 1000
const PREMIUM_CRATE_PRICE: int = 2000
const PREMIUM_SKIN_PRICE_THRESHOLD: int = 5000

const COIN_SHOP_PACKS: Array[Dictionary] = [
	{"sku": "coins_pack_starter", "name": "Pouch of NC",       "coins": 1200,   "bonus_coins": 0,     "price_usd": "$0.99",  "tag": "STARTER",    "tier": 0, "accent": Color(0.42, 0.84, 1.0)},
	{"sku": "coins_pack_handful", "name": "Stack of NC",       "coins": 3000,   "bonus_coins": 500,   "price_usd": "$2.99",  "tag": "+500 BONUS", "tier": 1, "accent": Color(0.36, 0.96, 0.58)},
	{"sku": "coins_pack_chest",   "name": "Tactical Chest",    "coins": 6500,   "bonus_coins": 1500,  "price_usd": "$4.99",  "tag": "POPULAR",    "tier": 2, "accent": Color(1.0, 0.84, 0.24)},
	{"sku": "coins_pack_vault",   "name": "Warlord Vault",     "coins": 15000,  "bonus_coins": 5000,  "price_usd": "$9.99",  "tag": "+33% BONUS", "tier": 3, "accent": Color(0.98, 0.58, 0.22)},
	{"sku": "coins_pack_royal",   "name": "Champion Hoard",    "coins": 35000,  "bonus_coins": 15000, "price_usd": "$19.99", "tag": "HOT DEAL",   "tier": 4, "accent": Color(0.84, 0.46, 1.0)},
	{"sku": "coins_pack_mega",    "name": "Nameless Treasury", "coins": 100000, "bonus_coins": 50000, "price_usd": "$49.99", "tag": "BEST VALUE", "tier": 5, "accent": Color(1.0, 0.88, 0.30)}
]

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
# Per-weapon display name & accent color overrides when a weapon's custom art differs from the shared preset theme
const WEAPON_SKIN_META_OVERRIDES: Dictionary = {
	"2": {
		"desert_camo": {"name": "Hazard Striker", "badge": Color(1.0, 0.84, 0.16), "bullet": Color(1.0, 0.86, 0.20)}
	},
	"7": {
		"desert_camo": {"name": "Steampunk Brass", "badge": Color(0.86, 0.60, 0.30), "bullet": Color(1.0, 0.72, 0.34)},
		"ocean_wave":  {"name": "Sapphire Sovereign", "badge": Color(0.32, 0.56, 1.0), "bullet": Color(0.38, 0.68, 1.0)}
	},
	"8": {
		"desert_camo":   {"name": "Wasteland Rust", "badge": Color(0.86, 0.50, 0.24), "bullet": Color(1.0, 0.62, 0.28)},
		"ocean_wave":    {"name": "Sapphire Sovereign", "badge": Color(0.32, 0.56, 1.0), "bullet": Color(0.38, 0.68, 1.0)},
		"nebula":        {"name": "Amethyst Crystal", "badge": Color(0.95, 0.34, 0.72), "bullet": Color(1.0, 0.40, 0.78)},
		"crimson_royal": {"name": "Relic Bronze", "badge": Color(0.84, 0.66, 0.34), "bullet": Color(0.96, 0.78, 0.40)}
	},
	"9": {
		"ocean_wave":    {"name": "Navy Sovereign", "badge": Color(0.36, 0.62, 1.0), "bullet": Color(0.42, 0.70, 1.0)},
		"crimson_royal": {"name": "Blood Obsidian", "badge": Color(0.92, 0.24, 0.26), "bullet": Color(1.0, 0.24, 0.24)}
	},
	"10": {
		"ocean_wave": {"name": "Steampunk Brass", "badge": Color(0.86, 0.58, 0.28), "bullet": Color(1.0, 0.68, 0.30)},
		"arctic":     {"name": "Cryo Core", "badge": Color(0.45, 0.88, 1.0), "bullet": Color(0.45, 0.92, 1.0)}
	},
	"18": {
		"ocean_wave":    {"name": "Wasteland Rust", "badge": Color(0.86, 0.52, 0.26), "bullet": Color(1.0, 0.62, 0.28)},
		"crimson_royal": {"name": "Neon Graffiti", "badge": Color(1.0, 0.38, 0.86), "bullet": Color(1.0, 0.42, 0.88)}
	},
	"20": {
		"ocean_wave":    {"name": "Cobalt Royal", "badge": Color(0.32, 0.58, 1.0), "bullet": Color(0.38, 0.68, 1.0)},
		"nebula":        {"name": "Wasp Tactical", "badge": Color(1.0, 0.86, 0.20), "bullet": Color(1.0, 0.88, 0.24)},
		"crimson_royal": {"name": "Crimson Tiger", "badge": Color(1.0, 0.28, 0.24), "bullet": Color(1.0, 0.30, 0.24)}
	},
	"23": {
		"desert_camo": {"name": "Wasteland Rust", "badge": Color(0.86, 0.52, 0.28), "bullet": Color(1.0, 0.62, 0.30)},
		"ocean_wave":  {"name": "Sapphire Sovereign", "badge": Color(0.34, 0.60, 1.0), "bullet": Color(0.40, 0.70, 1.0)}
	}
}
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

# Expandable catalog of customizable Dummy characters for Character Customization / Gunfight.
# Add more entries (up to 10-20+) here as new dummy sprite sets are added; part pools auto-sync.
const CUSTOM_DUMMIES: Array[Dictionary] = [
	{
		"name": "Cole",
		"role": "Tactical Trooper",
		"part_id": 3,
		"skin_id": 3, "head_id": 3, "torso_id": 3, "legs_id": 3, "hands_id": 3, "accessories_id": 3,
		"shirt": Color.WHITE, "pants": Color.WHITE, "skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE
	},
	{
		"name": "Leon",
		"role": "Golden Guard",
		"part_id": 5,
		"skin_id": 5, "head_id": 5, "torso_id": 5, "legs_id": 5, "hands_id": 5, "accessories_id": 5,
		"shirt": Color.WHITE, "pants": Color.WHITE, "skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE
	},
	{
		"name": "Marcus",
		"role": "Silver Sentinel",
		"part_id": 6,
		"skin_id": 6, "head_id": 6, "torso_id": 6, "legs_id": 6, "hands_id": 6, "accessories_id": 6,
		"shirt": Color.WHITE, "pants": Color.WHITE, "skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE
	},
	{
		"name": "Arthur",
		"role": "Iron Paladin",
		"part_id": 8,
		"skin_id": 8, "head_id": 8, "torso_id": 8, "legs_id": 8, "hands_id": 8, "accessories_id": 8,
		"shirt": Color.WHITE, "pants": Color.WHITE, "skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE
	},
	{
		"name": "Victor",
		"role": "Royal Vanguard",
		"part_id": 9,
		"skin_id": 9, "head_id": 9, "torso_id": 9, "legs_id": 9, "hands_id": 9, "accessories_id": 9,
		"shirt": Color.WHITE, "pants": Color.WHITE, "skin": Color.WHITE, "helmet": Color.WHITE, "gear": Color.WHITE
	}
]

const WEAPON_NAMES: Array[String] = [
	"AK47", "M16A4", "SCAR-L", "SMG", "Uzi",
	"Shotgun", "Pump Shotgun", "Sniper", "Auto Sniper", "Glock 21", "Bazooka"
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
	"Corvus Shadow Hood", "Elven Silver Circlet",
	"Nocturnal Count Hood", "Phantom Smoke Hood", "Bramble Spore Crown", "Boxer Hair",
	"Crimson Street Cap", "Cyber Visor Helm", "Desert Boonie Hat", "Stealth NVG Helmet"
]
const TORSO_NAMES: Array[String] = [
	"Olive Pouches", "Explorer Vest", "Outlaw Vest", "Camo Uniform",
	"SWAT Tactical Rig", "Spartan Cuirass", "Roman Lorica", "Viking Fur Jerkin",
	"Crusader Tabard", "Royal Ermine Robe", "Captain Coat", "Shinobi Gi",
	"Tattered Jacket", "Bone Ribcage", "Spectral Shroud", "Mummy Wrappings",
	"Mech Core Chassis", "Hazard Exo-Rig", "Cat Collar & Bell", "Dragon Scale Armor",
	"Orc Bone Harness", "Molten Rock Chest", "Crystal Facet Chest", "Prayer Beads Chest",
	"Shadow Cloak Tunic", "Forest Ranger Tunic",
	"Crimson Cloak Jacket", "Spectral Coat", "Thornhide Tunic", "Heavyweight Singlet",
	"Urban Teal Hoodie", "Cyber Exo-Vest", "Desert Field Vest", "Stealth Ops Rig"
]
const LEGS_NAMES: Array[String] = [
	"Olive Fatigues", "Field Khakis", "Outlaw Denim", "Camo Cargo",
	"Black SWAT Pants", "Spartan Greaves", "Roman Sandals", "Viking Fur Boots",
	"Chainmail Greaves", "Royal Crimson Pants", "Buccaneer Boots", "Shinobi Leggings",
	"Ripped Zombie Slacks", "Skeleton Shin Bones", "Floating Ghost Hem", "Bandaged Legs",
	"Robot Piston Legs", "Bio-Suit Greaves", "Black Cat Paws", "Hero Armor Greaves",
	"Orc Hide Boots", "Obsidian Stompers", "Crystal Pillar Legs", "Monk Martial Wraps",
	"Raven Shadow Boots", "Elven Woodland Boots",
	"Count Boots", "Shadow Slacks", "Bramble Boots", "Boxer Shorts & Boots",
	"Street Denim & Sneakers", "Cyber Armor Greaves", "Desert Cargo Pants", "Stealth Combat Pants"
]
const HANDS_NAMES: Array[String] = [
	"Bare Hands", "Adventurer Grip", "Outlaw Hands", "Camo Trooper",
	"SWAT Gloves", "Spartan Fists", "Roman Bracers", "Viking Fists",
	"Knight Gauntlets", "Royal Hands", "Pirate Grip", "Ninja Wraps",
	"Zombie Claws", "Skeletal Hands", "Ghost Hands", "Mummy Wraps",
	"Robot Pincers", "Bio-Armor Gloves", "Shadow Cat Paws", "Hero Gauntlets",
	"Purple Ogre Fists", "Boulder Fists", "Crystal Fists", "Taped Monk Fists",
	"Shadow Talon Gloves", "Elven Archer Bracers",
	"Vampire Claws", "Shadow Hands", "Vine Grips", "Boxing Gloves",
	"Urban Street Gloves", "Cyber Exo Gloves", "Desert Tactical Wraps", "Stealth Ops Gloves"
]
const ACC_NAMES: Array[String] = [
	"Infantry Pack", "Trail Backpack", "Thigh Holster", "Field Canteen",
	"Comms Pack", "Spartan Crimson Cape", "Centurion Mantle", "Viking Round Shield",
	"Templar Broadsword", "Royal Mantle Cape", "Pirate Cutlass", "Back Katana",
	"Toxic Pack", "Grave Pack", "Grim Reaper Scythe", "Relic Pack",
	"Twin Jet Thrusters", "Isotope Tank", "Black Cat Tail", "Hero Greatsword",
	"Ogre Cleaver", "Lava Spine", "Crystal Cluster", "Wooden Bo-Staff",
	"Corvus Wing Mantle", "Elven Quiver & Bow",
	"Nocturnal Cloak", "Phantom Veil", "Spore Pack", "Champion Belt",
	"Crimson Street Pack", "Cyber Booster Pack", "Desert Comms Pack", "Stealth Wing Pack"
]
const SKIN_NAMES: Array[String] = [
	"Neutral Soldier", "Smiling Explorer", "Bearded Outlaw", "Grinning Commando",
	"Glasses Agent", "Stern Spartan", "Scowling Roman", "Braided Beard",
	"Knight Visor Eyes", "White-Beard King", "Eyepatch Pirate", "Masked Ninja",
	"Drooling Zombie", "Hollow Skull", "Spooky Ghost Face", "Glowing-Eye Mummy",
	"Yellow-Optic Bot", "Green Gas-Mask", "Whiskered Cat", "Amber-Eye Hero",
	"Tusked Purple Orc", "Magma Cracked Face", "Pink Gem Face", "Bearded Monk",
	"Violet-Eye Mystic", "Pointed-Ear Elf",
	"Pale Vampire", "Void Face", "Bramble Mask", "Champion Boxer",
	"Street Grin Face", "Cyber Optic Face", "Desert Scar Face", "Stealth Mask Face"
]
const FACE_ACC_NAMES: Array[String] = [
	"Handlebar Mustache", "Ranger Beard", "Tactical Goatee",
	"Tactical Shades", "Outlaw Bandana", "Battle Eyepatch"
]
const CRATE_COSMETICS: Array[Dictionary] = [
	{"key": "face_mustache",  "slot": "face_acc_id",    "part_id": 0,  "name": "Handlebar Mustache",     "category": "Facial Accessory", "value": 800},
	{"key": "face_beard",     "slot": "face_acc_id",    "part_id": 1,  "name": "Ranger Beard",           "category": "Facial Accessory", "value": 900},
	{"key": "face_goatee",    "slot": "face_acc_id",    "part_id": 2,  "name": "Tactical Goatee",        "category": "Facial Accessory", "value": 850},
	{"key": "face_shades",    "slot": "face_acc_id",    "part_id": 3,  "name": "Tactical Shades",        "category": "Facial Accessory", "value": 1000},
	{"key": "face_bandana",   "slot": "face_acc_id",    "part_id": 4,  "name": "Outlaw Bandana",         "category": "Facial Accessory", "value": 950},
	{"key": "face_eyepatch",  "slot": "face_acc_id",    "part_id": 5,  "name": "Battle Eyepatch",        "category": "Facial Accessory", "value": 900},
	{"key": "skin_urban",     "slot": "skin_id",        "part_id": 30, "name": "Street Grin Face",       "category": "Character Face",   "value": 1000},
	{"key": "skin_cyber",     "slot": "skin_id",        "part_id": 31, "name": "Cyber Optic Face",       "category": "Character Face",   "value": 1200},
	{"key": "skin_desert",    "slot": "skin_id",        "part_id": 32, "name": "Desert Scar Face",       "category": "Character Face",   "value": 1100},
	{"key": "skin_stealth",   "slot": "skin_id",        "part_id": 33, "name": "Stealth Mask Face",      "category": "Character Face",   "value": 1300},
	{"key": "head_urban",     "slot": "head_id",        "part_id": 30, "name": "Crimson Street Cap",     "category": "Helmet / Hat",     "value": 1000},
	{"key": "head_cyber",     "slot": "head_id",        "part_id": 31, "name": "Cyber Visor Helm",       "category": "Helmet / Hat",     "value": 1200},
	{"key": "head_desert",    "slot": "head_id",        "part_id": 32, "name": "Desert Boonie Hat",      "category": "Helmet / Hat",     "value": 1100},
	{"key": "head_stealth",   "slot": "head_id",        "part_id": 33, "name": "Stealth NVG Helmet",     "category": "Helmet / Hat",     "value": 1400},
	{"key": "torso_urban",    "slot": "torso_id",       "part_id": 30, "name": "Urban Teal Hoodie",      "category": "Armor / Shirt",    "value": 1100},
	{"key": "torso_cyber",    "slot": "torso_id",       "part_id": 31, "name": "Cyber Exo-Vest",         "category": "Armor / Shirt",    "value": 1300},
	{"key": "torso_desert",   "slot": "torso_id",       "part_id": 32, "name": "Desert Field Vest",      "category": "Armor / Shirt",    "value": 1150},
	{"key": "torso_stealth",  "slot": "torso_id",       "part_id": 33, "name": "Stealth Ops Rig",        "category": "Armor / Shirt",    "value": 1400},
	{"key": "legs_urban",     "slot": "legs_id",        "part_id": 30, "name": "Street Denim",           "category": "Pants / Boots",    "value": 950},
	{"key": "legs_cyber",     "slot": "legs_id",        "part_id": 31, "name": "Cyber Armor Greaves",    "category": "Pants / Boots",    "value": 1150},
	{"key": "legs_desert",    "slot": "legs_id",        "part_id": 32, "name": "Desert Cargo Pants",     "category": "Pants / Boots",    "value": 1000},
	{"key": "legs_stealth",   "slot": "legs_id",        "part_id": 33, "name": "Stealth Combat Pants",   "category": "Pants / Boots",    "value": 1200},
	{"key": "acc_urban",      "slot": "accessories_id", "part_id": 30, "name": "Crimson Street Pack",    "category": "Back Accessory",   "value": 900},
	{"key": "acc_cyber",      "slot": "accessories_id", "part_id": 31, "name": "Cyber Booster Pack",     "category": "Back Accessory",   "value": 1200},
	{"key": "acc_desert",     "slot": "accessories_id", "part_id": 32, "name": "Desert Comms Pack",      "category": "Back Accessory",   "value": 1000},
	{"key": "acc_stealth",    "slot": "accessories_id", "part_id": 33, "name": "Stealth Wing Pack",      "category": "Back Accessory",   "value": 1300}
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
var dummy_id: int = 0
var archetype_id: int = 0
var skin_id: int = 0
var head_id: int = 0
var torso_id: int = 0
var legs_id: int = 0
var hands_id: int = 0
var accessories_id: int = 0
var face_acc_id: int = -1

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
var owned_cosmetics: Array[String] = []
var last_daily_bonus_date: String = ""
var last_free_crate_date: String = ""
var crate_limits_date: String = ""
var daily_premium_skin_won: bool = false
var daily_non_coin_wins: int = 0
var used_item_keys: Array[String] = []
var flagged_new_keys: Array[String] = []

var kill_reward: int = 25
var treasure_reward: int = 15
var win_reward: int = 100
var match_reward: int = 30
var agent_unlock_price: int = DEFAULT_AGENT_UNLOCK_PRICE
var gun_skin_prices: Dictionary = {}
var premium_gun_skins: Dictionary = {}
var crate_tables: Dictionary = {}


func _ready() -> void:
	load_economy_config()
	load_crate_tables()
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
	face_acc_id = -1

	shirt_color = arch["shirt"]
	pants_color = arch["pants"]
	skin_color = arch["skin"]
	helmet_color = arch["helmet"]
	gear_color = arch["gear"]
	primary_weapon_id = int(arch["weapon"])

	if emit_save:
		notify_changed()


static func get_dummy_part_ids() -> Array[int]:
	var ids: Array[int] = []
	for dm in CUSTOM_DUMMIES:
		var pid: int = clampi(int(dm.get("part_id", 3)), 0, ModularCharacter.MAX_PART_INDEX)
		if not ids.has(pid):
			ids.append(pid)
	if ids.is_empty():
		ids.append(3)
	return ids


func apply_dummy_preset(idx: int, emit_save: bool = true) -> void:
	var safe_idx: int = clampi(idx, 0, CUSTOM_DUMMIES.size() - 1)
	var dm: Dictionary = CUSTOM_DUMMIES[safe_idx]
	var base_part: int = clampi(int(dm.get("part_id", 3)), 0, ModularCharacter.MAX_PART_INDEX)
	dummy_id = safe_idx
	skin_id = int(dm.get("skin_id", base_part))
	head_id = int(dm.get("head_id", base_part))
	torso_id = int(dm.get("torso_id", base_part))
	legs_id = int(dm.get("legs_id", base_part))
	hands_id = int(dm.get("hands_id", base_part))
	accessories_id = int(dm.get("accessories_id", base_part))
	face_acc_id = -1
	shirt_color = dm.get("shirt", Color.WHITE) as Color
	pants_color = dm.get("pants", Color.WHITE) as Color
	skin_color = dm.get("skin", Color.WHITE) as Color
	helmet_color = dm.get("helmet", Color.WHITE) as Color
	gear_color = dm.get("gear", Color.WHITE) as Color
	if emit_save:
		notify_changed()


func owns_cosmetic(ckey: String) -> bool:
	return owned_cosmetics.has(ckey)


func get_cosmetic_def(ckey: String) -> Dictionary:
	for c in CRATE_COSMETICS:
		if str(c["key"]) == ckey:
			return c
	return {}


func grant_cosmetic(ckey: String) -> void:
	if ckey.is_empty():
		return
	if not owned_cosmetics.has(ckey):
		owned_cosmetics.append(ckey)
	save_profile()
	new_badges_changed.emit()
	profile_changed.emit()


func equip_cosmetic(ckey: String) -> bool:
	if not owns_cosmetic(ckey):
		return false
	var cdef: Dictionary = get_cosmetic_def(ckey)
	if cdef.is_empty():
		return false
	if not is_using_custom_dummy():
		apply_dummy_preset(dummy_id, false)
	var slot: String = str(cdef["slot"])
	var pid: int = int(cdef["part_id"])
	set(slot, pid)
	if slot == "torso_id":
		hands_id = pid
	mark_item_used(cosmetic_item_key(ckey))
	notify_changed()
	return true


static func agent_item_key(agent_id: int) -> String:
	return "agent:%d" % agent_id


static func gun_skin_item_key(weapon_id: int, skin_key: String) -> String:
	return "skin:%d:%s" % [weapon_id, skin_key]


static func cosmetic_item_key(cosmetic_key: String) -> String:
	return "cosmetic:%s" % cosmetic_key


static func dummy_item_key(dummy_idx: int) -> String:
	return "dummy:%d" % dummy_idx


static func custom_part_item_key(prop_name: String, part_id: int) -> String:
	return "part:%s:%d" % [prop_name, part_id]


func has_used_item(item_key: String) -> bool:
	return (not item_key.is_empty()) and used_item_keys.has(item_key)


func is_item_new(item_key: String, owned_or_available: bool = true) -> bool:
	if item_key.is_empty() or used_item_keys.has(item_key):
		return false
	return owned_or_available or flagged_new_keys.has(item_key)


func mark_item_new(item_key: String) -> void:
	if item_key.is_empty() or used_item_keys.has(item_key) or flagged_new_keys.has(item_key):
		return
	flagged_new_keys.append(item_key)
	save_profile()
	new_badges_changed.emit()


func mark_item_used(item_key: String) -> void:
	if item_key.is_empty():
		return
	var changed: bool = false
	if not used_item_keys.has(item_key):
		used_item_keys.append(item_key)
		changed = true
	if flagged_new_keys.has(item_key):
		flagged_new_keys.erase(item_key)
		changed = true
	if changed:
		save_profile()
		new_badges_changed.emit()


func is_agent_new(agent_id: int) -> bool:
	return is_agent_unlocked(agent_id, false) and not has_used_item(agent_item_key(agent_id))


func mark_agent_played(agent_id: int) -> void:
	var idx: int = clampi(agent_id, 0, ARCHETYPES.size() - 1)
	if is_agent_unlocked(idx, false):
		mark_item_used(agent_item_key(idx))


func has_any_new_agent() -> bool:
	for i in range(ARCHETYPES.size()):
		if is_agent_new(i):
			return true
	return false


func is_gun_skin_new(weapon_id: int, skin_key: String) -> bool:
	if skin_key.is_empty() or skin_key == "default":
		return false
	return owns_gun_skin(weapon_id, skin_key) and not has_used_item(gun_skin_item_key(weapon_id, skin_key))


func has_any_new_skin_for_weapon(weapon_id: int) -> bool:
	var wk := str(weapon_id)
	if not owned_gun_skins.has(wk) or not (owned_gun_skins[wk] is Array):
		return false
	for raw_sk in (owned_gun_skins[wk] as Array):
		if is_gun_skin_new(weapon_id, str(raw_sk)):
			return true
	return false


func has_any_new_gun_skin() -> bool:
	for raw_wk in owned_gun_skins.keys():
		if has_any_new_skin_for_weapon(int(str(raw_wk))):
			return true
	return false


func is_cosmetic_new(ckey: String) -> bool:
	return owns_cosmetic(ckey) and not has_used_item(cosmetic_item_key(ckey))


func is_dummy_part_new(prop_name: String, part_id: int) -> bool:
	if part_id < 0:
		return false
	var pk: String = custom_part_item_key(prop_name, part_id)
	if flagged_new_keys.has(pk) and not has_used_item(pk):
		return true
	for c in CRATE_COSMETICS:
		var cslot: String = str(c["slot"])
		var match_slot: bool = (cslot == prop_name) or (prop_name == "hands_id" and cslot == "torso_id")
		if match_slot and int(c["part_id"]) == part_id and is_cosmetic_new(str(c["key"])):
			return true
	return false


func has_new_cosmetic_for_slot(prop_name: String) -> bool:
	for pid in get_unlocked_dummy_part_ids_for_slot(prop_name):
		if is_dummy_part_new(prop_name, pid):
			return true
	return false


func mark_dummy_part_used(prop_name: String, part_id: int) -> void:
	if part_id < 0:
		return
	mark_item_used(custom_part_item_key(prop_name, part_id))
	for c in CRATE_COSMETICS:
		var cslot: String = str(c["slot"])
		var match_slot: bool = (cslot == prop_name) or (prop_name == "hands_id" and cslot == "torso_id")
		var ckey: String = str(c["key"])
		if match_slot and int(c["part_id"]) == part_id and owns_cosmetic(ckey):
			mark_item_used(cosmetic_item_key(ckey))


func is_dummy_new(dummy_idx: int) -> bool:
	return dummy_idx >= 0 and dummy_idx < CUSTOM_DUMMIES.size() and not has_used_item(dummy_item_key(dummy_idx))


func mark_dummy_used(dummy_idx: int) -> void:
	if dummy_idx >= 0 and dummy_idx < CUSTOM_DUMMIES.size():
		mark_item_used(dummy_item_key(dummy_idx))


func has_any_new_dummy() -> bool:
	for i in range(CUSTOM_DUMMIES.size()):
		if is_dummy_new(i):
			return true
	return false


func has_any_new_cosmetic() -> bool:
	for c in CRATE_COSMETICS:
		if is_cosmetic_new(str(c["key"])):
			return true
	for fk in flagged_new_keys:
		if (fk.begins_with("part:") or fk.begins_with("cosmetic:")) and not has_used_item(fk):
			return true
	return false


func has_any_new_customization() -> bool:
	return has_any_new_dummy() or has_any_new_cosmetic()


func _seed_initial_used_items() -> void:
	var dk: String = dummy_item_key(dummy_id)
	if not used_item_keys.has(dk):
		used_item_keys.append(dk)
	for raw_wk in equipped_gun_skins.keys():
		var wk := str(raw_wk)
		var sk: String = str(equipped_gun_skins[raw_wk])
		if not sk.is_empty() and sk != "default":
			var sk_id: String = gun_skin_item_key(int(wk), sk)
			if not used_item_keys.has(sk_id):
				used_item_keys.append(sk_id)
	for c in CRATE_COSMETICS:
		var ckey: String = str(c["key"])
		if owns_cosmetic(ckey) and int(get(str(c["slot"]))) == int(c["part_id"]):
			var ck_id: String = cosmetic_item_key(ckey)
			if not used_item_keys.has(ck_id):
				used_item_keys.append(ck_id)


func get_unlocked_dummy_part_ids_for_slot(prop_name: String) -> Array[int]:
	var ids: Array[int] = []
	if prop_name != "face_acc_id":
		for pid in get_dummy_part_ids():
			ids.append(pid)
	for c in CRATE_COSMETICS:
		var cslot: String = str(c["slot"])
		var match_slot: bool = (cslot == prop_name) or (prop_name == "hands_id" and cslot == "torso_id")
		if match_slot and owns_cosmetic(str(c["key"])):
			var cpid: int = int(c["part_id"])
			if not ids.has(cpid):
				ids.append(cpid)
	ids.sort()
	return ids


func is_using_custom_dummy() -> bool:
	if not get_unlocked_dummy_part_ids_for_slot("skin_id").has(skin_id):
		return false
	if not get_unlocked_dummy_part_ids_for_slot("torso_id").has(torso_id):
		return false
	if not get_unlocked_dummy_part_ids_for_slot("legs_id").has(legs_id):
		return false
	if not get_unlocked_dummy_part_ids_for_slot("hands_id").has(hands_id):
		return false
	if head_id >= 0 and not get_unlocked_dummy_part_ids_for_slot("head_id").has(head_id):
		return false
	if accessories_id >= 0 and not get_unlocked_dummy_part_ids_for_slot("accessories_id").has(accessories_id):
		return false
	if face_acc_id >= 0 and not get_unlocked_dummy_part_ids_for_slot("face_acc_id").has(face_acc_id):
		return false
	return true


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
	used_item_keys.clear()
	flagged_new_keys.clear()
	if cfg.load(_get_profile_path()) != OK:
		_seed_initial_used_items()
		save_profile()
		return

	player_name = str(cfg.get_value("profile", "player_name", player_name)).strip_edges().left(16)
	if player_name.is_empty():
		player_name = "Trooper"
	var max_idx: int = ARCHETYPES.size() - 1
	var max_part: int = ModularCharacter.MAX_PART_INDEX
	dummy_id = clampi(int(cfg.get_value("modular", "dummy_id", 0)), 0, CUSTOM_DUMMIES.size() - 1)
	archetype_id = clampi(int(cfg.get_value("modular", "archetype_id", 0)), 0, max_idx)
	var def_part: int = get_archetype_part_id(archetype_id)
	skin_id = clampi(int(cfg.get_value("modular", "skin_id", def_part)), 0, max_part)
	head_id = clampi(int(cfg.get_value("modular", "head_id", def_part)), -1, max_part)
	torso_id = clampi(int(cfg.get_value("modular", "torso_id", def_part)), 0, max_part)
	legs_id = clampi(int(cfg.get_value("modular", "legs_id", def_part)), 0, max_part)
	hands_id = clampi(int(cfg.get_value("modular", "hands_id", def_part)), 0, max_part)
	accessories_id = clampi(int(cfg.get_value("modular", "accessories_id", def_part)), -1, max_part)
	face_acc_id = clampi(int(cfg.get_value("modular", "face_acc_id", -1)), -1, ModularCharacter.FACE_ACC_FILES.size() - 1)

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
	owned_cosmetics.clear()
	var raw_cos: Variant = cfg.get_value("economy", "owned_cosmetics", [])
	if raw_cos is Array:
		for ck in (raw_cos as Array):
			var cks: String = str(ck)
			if not cks.is_empty() and not owned_cosmetics.has(cks):
				owned_cosmetics.append(cks)
	if not is_agent_unlocked(archetype_id, false):
		archetype_id = 0
	last_daily_bonus_date = str(cfg.get_value("economy", "last_daily_bonus_date", ""))
	last_free_crate_date = str(cfg.get_value("economy", "last_free_crate_date", ""))
	crate_limits_date = str(cfg.get_value("economy", "crate_limits_date", ""))
	daily_premium_skin_won = bool(cfg.get_value("economy", "daily_premium_skin_won", false))
	daily_non_coin_wins = maxi(0, int(cfg.get_value("economy", "daily_non_coin_wins", 0)))
	var raw_used: Variant = cfg.get_value("economy", "used_item_keys", [])
	if raw_used is Array:
		for uk in (raw_used as Array):
			var uks: String = str(uk)
			if not uks.is_empty() and not used_item_keys.has(uks):
				used_item_keys.append(uks)
	var raw_flag: Variant = cfg.get_value("economy", "flagged_new_keys", [])
	if raw_flag is Array:
		for fk in (raw_flag as Array):
			var fks: String = str(fk)
			if not fks.is_empty() and not used_item_keys.has(fks) and not flagged_new_keys.has(fks):
				flagged_new_keys.append(fks)
	if not cfg.has_section_key("economy", "used_item_keys"):
		_seed_initial_used_items()
	_ensure_crate_daily_state()


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
	new_badges_changed.emit()
	if has_node("/root/AchievementManager"):
		get_node("/root/AchievementManager").record_agent_or_skin_change()
	notify_changed()
	return true


func grant_agent(arch_idx: int) -> bool:
	var idx: int = clampi(arch_idx, 0, ARCHETYPES.size() - 1)
	if is_agent_unlocked(idx, false):
		return false
	if not unlocked_agents.has(idx):
		unlocked_agents.append(idx)
	save_profile()
	agents_unlocked_changed.emit()
	new_badges_changed.emit()
	if has_node("/root/AchievementManager"):
		get_node("/root/AchievementManager").record_agent_or_skin_change()
	notify_changed()
	return true


func get_gun_skin_def(skin_key: String) -> Dictionary:
	for s in GUN_SKIN_CATALOG:
		if str(s["key"]) == skin_key:
			return s
	return GUN_SKIN_CATALOG[0]


func get_gun_skin_name(weapon_id: int, skin_key: String) -> String:
	var wk := str(weapon_id)
	if WEAPON_SKIN_META_OVERRIDES.has(wk):
		var wm: Dictionary = WEAPON_SKIN_META_OVERRIDES[wk] as Dictionary
		if wm.has(skin_key) and (wm[skin_key] as Dictionary).has("name"):
			return str((wm[skin_key] as Dictionary)["name"])
	return str(get_gun_skin_def(skin_key).get("name", "Standard Issue"))


func get_gun_skin_badge(weapon_id: int, skin_key: String) -> Color:
	var wk := str(weapon_id)
	if WEAPON_SKIN_META_OVERRIDES.has(wk):
		var wm: Dictionary = WEAPON_SKIN_META_OVERRIDES[wk] as Dictionary
		if wm.has(skin_key) and (wm[skin_key] as Dictionary).has("badge"):
			return (wm[skin_key] as Dictionary)["badge"] as Color
	return get_gun_skin_def(skin_key).get("badge", Color(0.75, 0.80, 0.88)) as Color


func get_gun_skin_bullet_color(weapon_id: int, skin_key: String, fallback: Color = Color(1.0, 0.85, 0.25)) -> Color:
	var wk := str(weapon_id)
	if WEAPON_SKIN_META_OVERRIDES.has(wk):
		var wm: Dictionary = WEAPON_SKIN_META_OVERRIDES[wk] as Dictionary
		if wm.has(skin_key) and (wm[skin_key] as Dictionary).has("bullet"):
			return (wm[skin_key] as Dictionary)["bullet"] as Color
	return get_gun_skin_def(skin_key).get("bullet", fallback) as Color


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


func get_equipped_gun_skin_row(weapon_id: int) -> int:
	var sk: String = get_equipped_gun_skin(weapon_id)
	return int(get_gun_skin_def(sk).get("sheet_row", 0))


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


static func get_coin_pack_by_sku(sku: String) -> Dictionary:
	for p in COIN_SHOP_PACKS:
		if str(p.get("sku", "")) == sku:
			return p
	return {}


# Local Play Store purchase preview handler (no live billing API connected yet;
# replace this grant step with platform purchase verification once connected).
func purchase_coin_pack(sku: String) -> Dictionary:
	var pack: Dictionary = get_coin_pack_by_sku(sku)
	if pack.is_empty():
		return {"ok": false, "error": "Unknown NC pack."}
	var base_c: int = maxi(0, int(pack.get("coins", 0)))
	var bonus_c: int = maxi(0, int(pack.get("bonus_coins", 0)))
	var total_c: int = base_c + bonus_c
	add_coins(total_c)
	return {
		"ok": true,
		"sku": sku,
		"name": str(pack.get("name", "NC Pack")),
		"base_coins": base_c,
		"bonus_coins": bonus_c,
		"total_coins": total_c,
		"price_usd": str(pack.get("price_usd", "$0.99")),
		"tier": int(pack.get("tier", 0)),
		"accent": pack.get("accent", Color(1.0, 0.86, 0.28)),
		"order_id": "GPA.DEMO-%06d" % (int(Time.get_unix_time_from_system()) % 1000000),
		"new_balance": coins
	}


func grant_gun_skin(weapon_id: int, skin_key: String) -> void:
	if NO_SKIN_WEAPONS.has(weapon_id) or skin_key.is_empty():
		return
	var wk := str(weapon_id)
	if not owned_gun_skins.has(wk) or not (owned_gun_skins[wk] is Array):
		owned_gun_skins[wk] = ["default"]
	var arr: Array = owned_gun_skins[wk] as Array
	if not arr.has(skin_key):
		arr.append(skin_key)
	save_profile()
	gun_skins_changed.emit()
	new_badges_changed.emit()
	notify_changed()


func buy_gun_skin(weapon_id: int, skin_key: String) -> bool:
	if NO_SKIN_WEAPONS.has(weapon_id):
		return false
	if owns_gun_skin(weapon_id, skin_key):
		equip_gun_skin(weapon_id, skin_key)
		return true
	if has_node("/root/AchievementManager") and get_node("/root/AchievementManager").is_skin_achievement_exclusive(weapon_id, skin_key):
		return false
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
	if skin_key != "default" and not skin_key.is_empty():
		var sk_key: String = gun_skin_item_key(weapon_id, skin_key)
		if not used_item_keys.has(sk_key):
			used_item_keys.append(sk_key)
	save_profile()
	gun_skins_changed.emit()
	new_badges_changed.emit()
	if has_node("/root/AchievementManager"):
		get_node("/root/AchievementManager").record_agent_or_skin_change()
	notify_changed()
	return true


func equip_gun_skin(weapon_id: int, skin_key: String) -> void:
	if not owns_gun_skin(weapon_id, skin_key):
		return
	equipped_gun_skins[str(weapon_id)] = skin_key
	if skin_key != "default" and not skin_key.is_empty():
		mark_item_used(gun_skin_item_key(weapon_id, skin_key))
	else:
		save_profile()
	gun_skins_changed.emit()
	notify_changed()


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "player_name", player_name)
	cfg.set_value("modular", "dummy_id", dummy_id)
	cfg.set_value("modular", "archetype_id", archetype_id)
	cfg.set_value("modular", "skin_id", skin_id)
	cfg.set_value("modular", "head_id", head_id)
	cfg.set_value("modular", "torso_id", torso_id)
	cfg.set_value("modular", "legs_id", legs_id)
	cfg.set_value("modular", "hands_id", hands_id)
	cfg.set_value("modular", "accessories_id", accessories_id)
	cfg.set_value("modular", "face_acc_id", face_acc_id)

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
	cfg.set_value("economy", "owned_cosmetics", owned_cosmetics)
	cfg.set_value("economy", "last_daily_bonus_date", last_daily_bonus_date)
	cfg.set_value("economy", "last_free_crate_date", last_free_crate_date)
	cfg.set_value("economy", "crate_limits_date", crate_limits_date)
	cfg.set_value("economy", "daily_premium_skin_won", daily_premium_skin_won)
	cfg.set_value("economy", "daily_non_coin_wins", daily_non_coin_wins)
	cfg.set_value("economy", "used_item_keys", used_item_keys)
	cfg.set_value("economy", "flagged_new_keys", flagged_new_keys)
	cfg.save(_get_profile_path())


func reset_full_player_data() -> void:
	var abs_p: String = ProjectSettings.globalize_path(_get_profile_path())
	if FileAccess.file_exists(abs_p):
		DirAccess.remove_absolute(abs_p)

	player_name = _default_name()
	dummy_id = 0
	apply_archetype_preset(0, false)
	face_acc_id = -1

	primary_weapon_id = 0
	secondary_weapon_id = 9
	weapon_skin_id = 0
	m4a1_rail_mod = 0
	taunt_id = 0

	coins = 500
	owned_gun_skins.clear()
	equipped_gun_skins.clear()
	unlocked_agents.clear()
	owned_cosmetics.clear()
	last_daily_bonus_date = ""
	last_free_crate_date = ""
	crate_limits_date = ""
	daily_premium_skin_won = false
	daily_non_coin_wins = 0
	used_item_keys.clear()
	flagged_new_keys.clear()
	_seed_initial_used_items()
	_ensure_crate_daily_state()
	save_profile()

	if has_node("/root/AchievementManager"):
		get_node("/root/AchievementManager").reset_player_progress()

	coins_changed.emit(coins)
	gun_skins_changed.emit()
	agents_unlocked_changed.emit()
	new_badges_changed.emit()
	profile_changed.emit()
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").sync_local_profile()


func _ensure_crate_daily_state() -> void:
	var today: String = get_today_date_str()
	if crate_limits_date != today:
		crate_limits_date = today
		daily_premium_skin_won = false
		daily_non_coin_wins = 0


func get_today_date_str() -> String:
	return Time.get_date_string_from_system()


func can_claim_daily_bonus() -> bool:
	return last_daily_bonus_date != get_today_date_str()


func get_default_crate_tables() -> Dictionary:
	return {
		"standard": [
			{"type": "basic_skin", "chance": 2.0},
			{"type": "dummy_gear", "chance": 4.0},
			{"type": "double_coins", "chance": 0.3},
			{"type": "coins", "coins": 150, "chance": 38.7},
			{"type": "coins", "coins": 250, "chance": 33.0},
			{"type": "coins", "coins": 450, "chance": 22.0}
		],
		"premium": [
			{"type": "premium_skin", "chance": 0.4},
			{"type": "unlock_agent", "chance": 0.4},
			{"type": "basic_skin", "chance": 4.0},
			{"type": "dummy_gear", "chance": 6.0},
			{"type": "double_coins", "chance": 0.3},
			{"type": "coins", "coins": 400, "chance": 36.9},
			{"type": "coins", "coins": 750, "chance": 32.0},
			{"type": "coins", "coins": 1200, "chance": 20.0}
		]
	}


func load_crate_tables() -> void:
	crate_tables = get_default_crate_tables()
	for path in [CRATE_TABLES_PATH, USER_CRATE_TABLES_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var d: Dictionary = parsed as Dictionary
			for tk in ["standard", "premium"]:
				if d.has(tk) and d[tk] is Array and not (d[tk] as Array).is_empty():
					crate_tables[tk] = (d[tk] as Array).duplicate(true)


func save_crate_tables(save_to_project: bool = true) -> bool:
	var txt: String = JSON.stringify(crate_tables, "\t")
	var ok_any: bool = false
	var uf := FileAccess.open(USER_CRATE_TABLES_PATH, FileAccess.WRITE)
	if uf != null:
		uf.store_string(txt)
		uf.close()
		ok_any = true
	if save_to_project:
		var pf := FileAccess.open(ProjectSettings.globalize_path(CRATE_TABLES_PATH), FileAccess.WRITE)
		if pf != null:
			pf.store_string(txt)
			pf.close()
			ok_any = true
	economy_config_changed.emit()
	return ok_any


func claim_daily_bonus() -> bool:
	if not can_claim_daily_bonus():
		return false
	last_daily_bonus_date = get_today_date_str()
	coins += DAILY_BONUS_COINS
	save_profile()
	coins_changed.emit(coins)
	if has_node("/root/AchievementManager"):
		get_node("/root/AchievementManager").record_daily_bonus()
	return true


func can_open_free_daily_crate() -> bool:
	return last_free_crate_date != get_today_date_str()


func get_crate_skin_pools() -> Dictionary:
	var prem_pool: Array[Dictionary] = []
	var basic_pool: Array[Dictionary] = []
	var ach_mgr: Node = get_node_or_null("/root/AchievementManager")
	for wid in SHOP_WEAPON_IDS:
		if NO_SKIN_WEAPONS.has(wid):
			continue
		for sdef in GUN_SKIN_CATALOG:
			var skey: String = str(sdef["key"])
			if skey == "default":
				continue
			if ach_mgr != null and ach_mgr.is_skin_achievement_exclusive(wid, skey):
				continue
			var price: int = get_gun_skin_price(wid, skey)
			var entry: Dictionary = {"weapon_id": wid, "skin_key": skey, "price": price}
			if price >= PREMIUM_SKIN_PRICE_THRESHOLD or is_gun_skin_premium(wid, skey):
				prem_pool.append(entry)
			else:
				basic_pool.append(entry)
	if prem_pool.is_empty():
		for e in basic_pool:
			if str(e["skin_key"]) in ["gold", "crimson_royal", "nebula"]:
				prem_pool.append(e)
	return {"premium": prem_pool, "basic": basic_pool}


func open_crate(is_premium_crate: bool, use_free_daily: bool = false) -> Dictionary:
	if use_free_daily:
		if is_premium_crate or not can_open_free_daily_crate():
			return {"ok": false, "error": "Free daily crate already opened today!"}
		last_free_crate_date = get_today_date_str()
		save_profile()
	else:
		var cost: int = PREMIUM_CRATE_PRICE if is_premium_crate else STANDARD_CRATE_PRICE
		if not spend_coins(cost):
			return {"ok": false, "error": "Not enough NC! Need %s NC." % format_coins(cost)}

	var coins_after_spend: int = coins
	var res: Dictionary = _roll_single_crate_reward(is_premium_crate)
	res["coins_before_reward"] = coins_after_spend
	return res


func open_crates_batch(is_premium_crate: bool, count: int = 10) -> Dictionary:
	var n: int = maxi(1, count)
	var unit_cost: int = PREMIUM_CRATE_PRICE if is_premium_crate else STANDARD_CRATE_PRICE
	var total_cost: int = unit_cost * n
	if not spend_coins(total_cost):
		return {"ok": false, "error": "Not enough NC! Need %s NC." % format_coins(total_cost)}
	var coins_after_spend: int = coins
	var items: Array = []
	for _i in range(n):
		items.append(_roll_single_crate_reward(is_premium_crate))
	return {
		"ok": true,
		"is_premium": is_premium_crate,
		"items": items,
		"coins_before_rewards": coins_after_spend,
		"final_coins": coins
	}


func _roll_single_crate_reward(is_premium_crate: bool) -> Dictionary:
	_ensure_crate_daily_state()
	var tkey: String = "premium" if is_premium_crate else "standard"
	var entries: Array = crate_tables.get(tkey, get_default_crate_tables()[tkey]) as Array

	var eff_list: Array[Dictionary] = []
	var coin_indices: Array[int] = []
	var shaved_total: float = 0.0
	var rare_divisor: float = pow(2.0, float(mini(daily_non_coin_wins, 20)))
	for e in entries:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e as Dictionary
		var base_w: float = maxf(0.0, float(ed.get("chance", 0.0)))
		var etype: String = str(ed.get("type", "coins"))
		var eff_w: float = base_w
		if etype == "premium_skin":
			if not is_premium_crate or daily_premium_skin_won:
				eff_w = 0.0
			else:
				eff_w = base_w / rare_divisor
		elif etype in ["basic_skin", "specific_skin", "unlock_agent", "dummy_gear", "double_coins"]:
			if etype == "unlock_agent" and not is_premium_crate:
				eff_w = 0.0
			else:
				eff_w = base_w / rare_divisor
		shaved_total += maxf(0.0, base_w - eff_w)
		var slot_idx: int = eff_list.size()
		eff_list.append({"entry": ed, "w": eff_w})
		if etype == "coins":
			coin_indices.append(slot_idx)
	if shaved_total > 0.0:
		if not coin_indices.is_empty():
			var coin_w_sum: float = 0.0
			for ci in coin_indices:
				coin_w_sum += float(eff_list[ci]["w"])
			for ci in coin_indices:
				var share: float = (float(eff_list[ci]["w"]) / coin_w_sum) if coin_w_sum > 0.001 else (1.0 / float(coin_indices.size()))
				eff_list[ci]["w"] = float(eff_list[ci]["w"]) + shaved_total * share
		else:
			eff_list.append({"entry": {"type": "coins", "coins": 400 if is_premium_crate else 200}, "w": shaved_total})

	var total_w: float = 0.0
	for it in eff_list:
		total_w += float(it["w"])
	var chosen: Dictionary = {"type": "coins", "coins": 400 if is_premium_crate else 250}
	if total_w > 0.001:
		var r: float = randf() * total_w
		var acc: float = 0.0
		for it in eff_list:
			acc += float(it["w"])
			if r <= acc:
				chosen = it["entry"] as Dictionary
				break

	var pools: Dictionary = get_crate_skin_pools()
	var prem_pool: Array = pools["premium"] as Array
	var basic_pool: Array = pools["basic"] as Array
	var ctype: String = str(chosen.get("type", "coins"))
	if not is_premium_crate and ctype == "premium_skin":
		ctype = "basic_skin"

	if ctype == "double_coins":
		var floor_bonus: int = (PREMIUM_CRATE_PRICE if is_premium_crate else STANDARD_CRATE_PRICE) * 2
		var bonus: int = mini(maxi(coins, floor_bonus), 50_000_000)
		daily_non_coin_wins += 1
		add_coins(bonus)
		if has_node("/root/AchievementManager"):
			get_node("/root/AchievementManager").record_crate_opened(is_premium_crate)
		return {
			"ok": true,
			"kind": "double_coins",
			"weapon_id": -1,
			"weapon_name": "",
			"skin_key": "",
			"skin_name": "",
			"agent_id": -1,
			"agent_name": "",
			"agent_title": "",
			"cosmetic_key": "",
			"cosmetic_slot": "",
			"cosmetic_part_id": -1,
			"cosmetic_category": "",
			"is_duplicate": false,
			"coins_won": bonus,
			"item_value": bonus,
			"label": "2x NC! (+%s)" % format_coins(bonus),
			"short_label": "2x NC!",
			"color": Color(0.28, 1.0, 0.58)
		}

	if ctype == "dummy_gear":
		var cdef: Dictionary = CRATE_COSMETICS[randi() % CRATE_COSMETICS.size()]
		var ckey: String = str(cdef["key"])
		var cslot: String = str(cdef["slot"])
		var cpid: int = int(cdef["part_id"])
		var cname: String = str(cdef["name"])
		var ccat: String = str(cdef["category"])
		var cval: int = int(cdef.get("value", 900))
		var is_dup_c: bool = owns_cosmetic(ckey)
		var refund_c: int = 0
		daily_non_coin_wins += 1
		if is_dup_c:
			refund_c = maxi(100, int(cval / 2))
			add_coins(refund_c)
		else:
			grant_cosmetic(ckey)
		if has_node("/root/AchievementManager"):
			get_node("/root/AchievementManager").record_crate_opened(is_premium_crate)
		return {
			"ok": true,
			"kind": "dummy_gear",
			"weapon_id": -1,
			"weapon_name": "",
			"skin_key": "",
			"skin_name": "",
			"agent_id": -1,
			"agent_name": "",
			"agent_title": "",
			"cosmetic_key": ckey,
			"cosmetic_slot": cslot,
			"cosmetic_part_id": cpid,
			"cosmetic_category": ccat,
			"is_duplicate": is_dup_c,
			"coins_won": refund_c,
			"item_value": cval,
			"label": "%s (%s)" % [cname, ccat],
			"short_label": cname,
			"color": Color(0.98, 0.56, 0.92)
		}

	if ctype == "unlock_agent":
		var locked: Array[int] = []
		for i in range(ARCHETYPES.size()):
			if not is_agent_unlocked(i, false):
				locked.append(i)
		daily_non_coin_wins += 1
		if not locked.is_empty():
			var ag_id: int = locked[randi() % locked.size()]
			grant_agent(ag_id)
			var ag: Dictionary = AgentData.get_agent(ag_id)
			var ag_name: String = str(ag.get("agent_name", "Agent"))
			var ag_title: String = str(ag.get("title", ""))
			if has_node("/root/AchievementManager"):
				get_node("/root/AchievementManager").record_crate_opened(is_premium_crate)
			return {
				"ok": true,
				"kind": "agent_unlock",
				"weapon_id": -1,
				"weapon_name": "",
				"skin_key": "",
				"skin_name": "",
				"agent_id": ag_id,
				"agent_name": ag_name,
				"agent_title": ag_title,
				"cosmetic_key": "",
				"cosmetic_slot": "",
				"cosmetic_part_id": -1,
				"cosmetic_category": "",
				"is_duplicate": false,
				"coins_won": 0,
				"item_value": get_agent_unlock_price(),
				"label": "%s (%s)" % [ag_name, ag_title],
				"short_label": ag_name,
				"color": Color(0.86, 0.48, 1.0)
			}
		var ag_refund: int = maxi(1000, int(get_agent_unlock_price() / 2))
		add_coins(ag_refund)
		if has_node("/root/AchievementManager"):
			get_node("/root/AchievementManager").record_crate_opened(is_premium_crate)
		return {
			"ok": true,
			"kind": "agent_unlock",
			"weapon_id": -1,
			"weapon_name": "",
			"skin_key": "",
			"skin_name": "",
			"agent_id": -1,
			"agent_name": "All Agents Owned",
			"agent_title": "",
			"cosmetic_key": "",
			"cosmetic_slot": "",
			"cosmetic_part_id": -1,
			"cosmetic_category": "",
			"is_duplicate": true,
			"coins_won": ag_refund,
			"item_value": get_agent_unlock_price(),
			"label": "All Agents Owned (+%s NC)" % format_coins(ag_refund),
			"short_label": "+%s NC" % format_coins(ag_refund),
			"color": Color(0.86, 0.48, 1.0)
		}

	if ctype == "specific_skin" or ctype == "premium_skin" or ctype == "basic_skin":
		var wid: int = -1
		var skey: String = ""
		var is_prem_drop: bool = (ctype == "premium_skin")
		if ctype == "specific_skin":
			wid = int(chosen.get("weapon_id", 0))
			skey = str(chosen.get("skin_key", "gold"))
			var ach_m: Node = get_node_or_null("/root/AchievementManager")
			is_prem_drop = (get_gun_skin_price(wid, skey) >= PREMIUM_SKIN_PRICE_THRESHOLD or is_gun_skin_premium(wid, skey))
			if (ach_m != null and ach_m.is_skin_achievement_exclusive(wid, skey)) or (is_prem_drop and (daily_premium_skin_won or not is_premium_crate)):
				ctype = "coins"
		else:
			var pool: Array = prem_pool if ctype == "premium_skin" else basic_pool
			if pool.is_empty():
				ctype = "coins"
			else:
				var pick: Dictionary = pool[randi() % pool.size()] as Dictionary
				wid = int(pick["weapon_id"])
				skey = str(pick["skin_key"])
		if ctype != "coins" and wid >= 0 and not skey.is_empty():
			var wd := WeaponData.get_weapon(wid, 0, 0)
			var sname: String = get_gun_skin_name(wid, skey)
			var skin_val: int = maxi(200, get_gun_skin_price(wid, skey))
			var is_dup: bool = owns_gun_skin(wid, skey)
			var refund: int = 0
			daily_non_coin_wins += 1
			if is_prem_drop:
				daily_premium_skin_won = true
			if is_dup:
				refund = maxi(100, int(skin_val / 2))
				add_coins(refund)
			else:
				grant_gun_skin(wid, skey)
			if has_node("/root/AchievementManager"):
				get_node("/root/AchievementManager").record_crate_opened(is_premium_crate)
			return {
				"ok": true,
				"kind": "premium_skin" if is_prem_drop else "basic_skin",
				"weapon_id": wid,
				"weapon_name": wd.display_name,
				"skin_key": skey,
				"skin_name": sname,
				"agent_id": -1,
				"agent_name": "",
				"agent_title": "",
				"cosmetic_key": "",
				"cosmetic_slot": "",
				"cosmetic_part_id": -1,
				"cosmetic_category": "",
				"is_duplicate": is_dup,
				"coins_won": refund,
				"item_value": skin_val,
				"label": "%s — %s" % [wd.display_name, sname],
				"short_label": sname,
				"color": Color(1.0, 0.78, 0.18) if is_prem_drop else Color(0.32, 0.86, 1.0)
			}

	var won: int = maxi(50, int(chosen.get("coins", 400 if is_premium_crate else 200)))
	add_coins(won)
	if has_node("/root/AchievementManager"):
		get_node("/root/AchievementManager").record_crate_opened(is_premium_crate)
	return {
		"ok": true,
		"kind": "coins",
		"weapon_id": -1,
		"weapon_name": "",
		"skin_key": "",
		"skin_name": "",
		"agent_id": -1,
		"agent_name": "",
		"agent_title": "",
		"cosmetic_key": "",
		"cosmetic_slot": "",
		"cosmetic_part_id": -1,
		"cosmetic_category": "",
		"is_duplicate": false,
		"coins_won": won,
		"item_value": won,
		"label": "+%d NC" % won,
		"short_label": "+%s NC" % format_coins(won),
		"color": Color(1.0, 0.88, 0.34)
	}


func notify_changed() -> void:
	save_profile()
	profile_changed.emit()
	if has_node("/root/NetworkManager"):
		get_node("/root/NetworkManager").sync_local_profile()


func to_dict() -> Dictionary:
	return {
		"dummy_id": dummy_id,
		"archetype_id": archetype_id,
		"skin_id": skin_id,
		"head_id": head_id,
		"torso_id": torso_id,
		"legs_id": legs_id,
		"hands_id": hands_id,
		"accessories_id": accessories_id,
		"face_acc_id": face_acc_id,
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
		"dummy_id": clampi(int(d.get("dummy_id", 0)), 0, CUSTOM_DUMMIES.size() - 1),
		"archetype_id": clampi(int(d.get("archetype_id", 0)), 0, max_idx),
		"skin_id": clampi(int(d.get("skin_id", 0)), 0, max_part),
		"head_id": clampi(int(d.get("head_id", 0)), -1, max_part),
		"torso_id": clampi(int(d.get("torso_id", 0)), 0, max_part),
		"legs_id": clampi(int(d.get("legs_id", 0)), 0, max_part),
		"hands_id": clampi(int(d.get("hands_id", 0)), 0, max_part),
		"accessories_id": clampi(int(d.get("accessories_id", 0)), -1, max_part),
		"face_acc_id": clampi(int(d.get("face_acc_id", -1)), -1, ModularCharacter.FACE_ACC_FILES.size() - 1),
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
