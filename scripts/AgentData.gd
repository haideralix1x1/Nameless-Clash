extends RefCounted
class_name AgentData

const THROWABLE_ITEMS: Array[Dictionary] = [
	{
		"name": "Throwing Axe",
		"damage": 44,
		"speed": 880.0,
		"stun": 0.45,
		"style": "thrown_axe",
		"explosive": false,
		"color": Color(0.85, 0.88, 0.94)
	},
	{
		"name": "Iron Broadsword",
		"damage": 46,
		"speed": 960.0,
		"stun": 0.35,
		"style": "thrown_sword",
		"explosive": false,
		"color": Color(0.75, 0.90, 1.0)
	},
	{
		"name": "Spartan War Spear",
		"damage": 48,
		"speed": 1080.0,
		"stun": 0.40,
		"style": "thrown_spear",
		"explosive": false,
		"color": Color(1.0, 0.84, 0.28)
	},
	{
		"name": "Viking Warhammer",
		"damage": 45,
		"speed": 820.0,
		"stun": 0.90,
		"style": "thrown_hammer",
		"explosive": false,
		"color": Color(0.55, 0.82, 1.0)
	},
	{
		"name": "Runic Bomb Blade",
		"damage": 42,
		"speed": 860.0,
		"stun": 0.50,
		"style": "thrown_sword",
		"explosive": true,
		"color": Color(1.0, 0.48, 0.18)
	},
	{
		"name": "Heavy Combat Shoe",
		"damage": 38,
		"speed": 900.0,
		"stun": 0.65,
		"style": "thrown_shoe",
		"explosive": false,
		"color": Color(0.76, 0.40, 0.18)
	},
	{
		"name": "Jagged Boulder Stone",
		"damage": 42,
		"speed": 840.0,
		"stun": 0.85,
		"style": "thrown_stone",
		"explosive": false,
		"color": Color(0.64, 0.68, 0.74)
	}
]

const AGENTS: Array[Dictionary] = [
	# 0: Rex Vance // The Soldier
	{
		"id": 0,
		"agent_name": "Rex Vance",
		"title": "The Soldier",
		"role": "Frontline Vanguard",
		"accent": Color(0.45, 0.82, 0.38),
		"base_weapon": {
			"name": "Trench Broadsword",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.34,
			"range": 104.0,
			"color": Color(0.78, 0.92, 0.65),
			"ranged": false
		},
		"abilities": [
			{
				"name": "M4A1 Rifle Burst",
				"kind": "gun_burst",
				"cooldown": 6.0,
				"damage": 14,
				"shots": 6,
				"color": Color(1.0, 0.86, 0.32),
				"desc": "Draw an M4A1 and fire a 6-round rapid rifle burst."
			},
			{
				"name": "Concussion Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 8.0,
				"damage": 20,
				"stun": 1.6,
				"color": Color(0.35, 0.90, 1.0),
				"desc": "Throw a tactical concussion Stun Bomb stunning enemies in its circle 1.6s."
			},
			{
				"name": "Steel Bunker Wall",
				"kind": "wall",
				"cooldown": 9.0,
				"damage": 0,
				"wall_hp": 240,
				"duration": 6.0,
				"color": Color(0.45, 0.68, 0.48),
				"desc": "Deploy a steel barricade that blocks movement and shots."
			}
		],
		"ultimate": {
			"name": "Valkyrie Minigun Barrage",
			"kind": "ult_gun_storm",
			"cooldown": 22.0,
			"damage": 16,
			"shots": 14,
			"stun": 0.4,
			"color": Color(1.0, 0.72, 0.22),
			"desc": "Unleash a 14-round heavy minigun storm across your aim arc."
		}
	},
	# 1: Atlas Jones // The Explorer
	{
		"id": 1,
		"agent_name": "Atlas Jones",
		"title": "The Explorer",
		"role": "Agile Scout",
		"accent": Color(0.86, 0.68, 0.38),
		"base_weapon": {
			"name": "Jungle Machete",
			"style": "sword",
			"damage": 23,
			"cooldown": 0.32,
			"range": 100.0,
			"color": Color(0.92, 0.84, 0.58),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Whip Sprint Dash",
				"kind": "dash_speed",
				"cooldown": 5.5,
				"damage": 18,
				"duration": 4.0,
				"speed_mult": 1.75,
				"color": Color(1.0, 0.84, 0.36),
				"desc": "Dash forward with a whip strike and gain 4s speed boost."
			},
			{
				"name": "Temple Stone Wall",
				"kind": "wall",
				"cooldown": 8.5,
				"damage": 0,
				"wall_hp": 220,
				"duration": 5.5,
				"color": Color(0.76, 0.64, 0.42),
				"desc": "Raise an ancient stone pillar blocking enemies and bullets."
			},
			{
				"name": "Flare Gun Fireball",
				"kind": "fireball",
				"cooldown": 6.5,
				"damage": 38,
				"color": Color(1.0, 0.44, 0.16),
				"desc": "Shoot a blazing explosive flare fireball."
			}
		],
		"ultimate": {
			"name": "Relic Earthquake Slam",
			"kind": "ult_stun_nova",
			"cooldown": 22.0,
			"damage": 58,
			"stun": 2.0,
			"color": Color(1.0, 0.74, 0.25),
			"desc": "Shatter the arena floor, blasting and stunning nearby foes 2.0s."
		}
	},
	# 2: Cole Cassidy // The Outlaw
	{
		"id": 2,
		"agent_name": "Cole Cassidy",
		"title": "The Outlaw",
		"role": "Gunslinger Duelist",
		"accent": Color(0.95, 0.42, 0.24),
		"base_weapon": {
			"name": "Frontier Hunting Bow",
			"style": "bow",
			"damage": 22,
			"cooldown": 0.38,
			"range": 640.0,
			"color": Color(0.96, 0.74, 0.36),
			"ranged": true
		},
		"abilities": [
			{
				"name": "Peacekeeper Fan",
				"kind": "gun_burst",
				"cooldown": 6.0,
				"damage": 16,
				"shots": 6,
				"color": Color(1.0, 0.62, 0.22),
				"desc": "Fan 6 revolver shots rapidly along your aim line."
			},
			{
				"name": "Flashbang Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 8.0,
				"damage": 22,
				"stun": 1.6,
				"color": Color(1.0, 0.95, 0.55),
				"desc": "Throw a saloon Flashbang Stun Bomb stunning enemies in its circle 1.6s."
			},
			{
				"name": "Dynamite Keg Bomb",
				"kind": "lava_bomb",
				"cooldown": 7.5,
				"damage": 12,
				"duration": 3.5,
				"speed_mult": 1.7,
				"stun": 1.6,
				"radius": 110.0,
				"color": Color(0.95, 0.52, 0.28),
				"desc": "Throw a lit frontier dynamite bomb that blasts and stuns enemies in its circle 1.6s."
			}
		],
		"ultimate": {
			"name": "High Noon Deadeye",
			"kind": "ult_gun_storm",
			"cooldown": 22.0,
			"damage": 22,
			"shots": 12,
			"stun": 0.8,
			"color": Color(1.0, 0.32, 0.18),
			"desc": "Unleash 12 high-caliber Deadeye rounds that stagger foes."
		}
	},
	# 3: Jax Striker // Camo Commando
	{
		"id": 3,
		"agent_name": "Jax Striker",
		"title": "Camo Commando",
		"role": "Jungle Raider",
		"accent": Color(0.32, 0.88, 0.45),
		"base_weapon": {
			"name": "Survival Battle Axe",
			"style": "axe",
			"damage": 26,
			"cooldown": 0.38,
			"range": 106.0,
			"color": Color(0.55, 0.92, 0.48),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Guerrilla Turbo Sprint",
				"kind": "speed",
				"cooldown": 6.5,
				"damage": 0,
				"duration": 4.2,
				"speed_mult": 1.85,
				"color": Color(0.35, 1.0, 0.55),
				"desc": "Boost movement and attack speed massively + heal 15 HP."
			},
			{
				"name": "Breacher Buckshot",
				"kind": "shotgun_blast",
				"cooldown": 6.0,
				"damage": 14,
				"shots": 6,
				"color": Color(0.65, 1.0, 0.35),
				"desc": "Blast a wide close-range 6-pellet commando shotgun spread."
			},
			{
				"name": "Jungle Snare Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 8.0,
				"damage": 22,
				"stun": 1.8,
				"color": Color(0.32, 0.95, 0.45),
				"desc": "Throw a camouflaged Snare Stun Bomb stunning enemies in its circle 1.8s."
			}
		],
		"ultimate": {
			"name": "Napalm Fireball Volley",
			"kind": "ult_firestorm",
			"cooldown": 22.0,
			"damage": 38,
			"color": Color(1.0, 0.46, 0.14),
			"desc": "Rain a spread of 6 explosive napalm fireballs."
		}
	},
	# 4: Rook Frost // Spec-Ops Goggles
	{
		"id": 4,
		"agent_name": "Rook Frost",
		"title": "Star Tank",
		"role": "SWAT Breacher",
		"accent": Color(0.38, 0.78, 1.0),
		"base_weapon": {
			"name": "Shock Tonfa Blade",
			"style": "sword",
			"damage": 23,
			"cooldown": 0.33,
			"range": 102.0,
			"color": Color(0.45, 0.84, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Ballistic Riot Wall",
				"kind": "wall",
				"cooldown": 8.5,
				"damage": 0,
				"wall_hp": 260,
				"duration": 6.0,
				"color": Color(0.32, 0.68, 1.0),
				"desc": "Drop a fortified heavy riot barrier wall."
			},
			{
				"name": "Cryo-Shock Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 7.5,
				"damage": 20,
				"stun": 1.9,
				"color": Color(0.32, 0.96, 1.0),
				"desc": "Throw a Cryo-Shock Stun Bomb freezing enemies in its circle 1.9s."
			},
			{
				"name": "Star-Breacher Shotgun",
				"kind": "shotgun_blast",
				"cooldown": 6.5,
				"damage": 13,
				"shots": 6,
				"color": Color(0.85, 0.94, 1.0),
				"desc": "Fire a heavy 6-pellet close-range tank spread."
			}
		],
		"ultimate": {
			"name": "Cryo-Lockdown Nova",
			"kind": "ult_stun_nova",
			"cooldown": 22.0,
			"damage": 56,
			"stun": 2.3,
			"color": Color(0.36, 0.92, 1.0),
			"desc": "Freeze nearby opponents solid for 2.3s with heavy shock damage."
		}
	},
	# 5: Leonidas // Golden Spartan
	{
		"id": 5,
		"agent_name": "Leonidas",
		"title": "Golden Spartan",
		"role": "Arena Champion",
		"accent": Color(1.0, 0.80, 0.22),
		"base_weapon": {
			"name": "Olympian War Spear",
			"style": "spear",
			"damage": 25,
			"cooldown": 0.35,
			"range": 122.0,
			"color": Color(1.0, 0.82, 0.28),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Spartan Spear Volley",
				"kind": "spear_throw",
				"shots": 2,
				"cooldown": 7.0,
				"damage": 28,
				"stun": 1.6,
				"color": Color(1.0, 0.84, 0.24),
				"desc": "Hurl a piercing Olympian war spear along your aim line."
			},
			{
				"name": "Phalanx Bronze Wall",
				"kind": "wall",
				"cooldown": 8.5,
				"damage": 0,
				"wall_hp": 250,
				"duration": 5.8,
				"color": Color(0.92, 0.72, 0.22),
				"desc": "Conjure a bronze phalanx shield wall."
			},
			{
				"name": "Golden Shield Bash",
				"kind": "dash_stun",
				"cooldown": 5.5,
				"damage": 44,
				"color": Color(1.0, 0.78, 0.18),
				"desc": "Dash forward and unleash a Stun Bomb impact in a circle."
			}
		],
		"ultimate": {
			"name": "Wrath of Olympus",
			"kind": "ult_giant_sword",
			"cooldown": 22.0,
			"damage": 64,
			"stun": 1.5,
			"color": Color(1.0, 0.86, 0.20),
			"desc": "Summon giant Olympian solar blades that stun and cleave foes."
		}
	},
	# 6: Maximus // Roman Centurion
	{
		"id": 6,
		"agent_name": "Maximus",
		"title": "Roman Centurion",
		"role": "Legion Officer",
		"accent": Color(0.88, 0.28, 0.28),
		"base_weapon": {
			"name": "Imperial Gladius",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.33,
			"range": 106.0,
			"color": Color(0.92, 0.88, 0.96),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Legion Scutum Wall",
				"kind": "wall",
				"cooldown": 8.5,
				"damage": 0,
				"wall_hp": 250,
				"duration": 5.8,
				"color": Color(0.84, 0.28, 0.28),
				"desc": "Form a crimson legion shield barricade."
			},
			{
				"name": "Iron Pilum Javelin",
				"kind": "spear_throw",
				"shots": 2,
				"cooldown": 6.0,
				"damage": 18,
				"duration": 3.8,
				"speed_mult": 1.75,
				"color": Color(1.0, 0.48, 0.34),
				"desc": "Throw a heavy armor-piercing Roman war javelin."
			},
			{
				"name": "Legion Net Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 7.5,
				"damage": 26,
				"stun": 1.5,
				"color": Color(1.0, 0.72, 0.32),
				"desc": "Throw a weighted Roman net Stun Bomb stunning enemies in its circle 1.7s."
			}
		],
		"ultimate": {
			"name": "Siege Fireball Volley",
			"kind": "ult_firestorm",
			"cooldown": 22.0,
			"damage": 40,
			"color": Color(1.0, 0.38, 0.16),
			"desc": "Call down 6 blazing siege catapult fireballs."
		}
	},
	# 7: Ragnar // Viking Berserker
	{
		"id": 7,
		"agent_name": "Ragnar",
		"title": "Viking Berserker",
		"role": "Northern Raider",
		"accent": Color(0.95, 0.56, 0.18),
		"base_weapon": {
			"name": "Nordic Great-Axe",
			"style": "axe",
			"damage": 28,
			"cooldown": 0.40,
			"range": 112.0,
			"color": Color(0.82, 0.90, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Nordic Throwing Axes",
				"kind": "axe_volley",
				"shots": 2,
				"cooldown": 6.0,
				"damage": 24,
				"duration": 4.2,
				"speed_mult": 1.85,
				"color": Color(1.0, 0.45, 0.18),
				"desc": "Hurl a twin volley of spinning Nordic battle axes."
			},
			{
				"name": "Berserker Bloodlust",
				"kind": "speed",
				"cooldown": 8.0,
				"damage": 28,
				"stun": 1.7,
				"color": Color(0.45, 0.84, 1.0),
				"desc": "Enter a berserk frenzy with huge speed boost + 15 HP."
			},
			{
				"name": "Mjolnir Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 8.5,
				"damage": 22,
				"wall_hp": 230,
				"duration": 5.5,
				"stun": 1.8,
				"radius": 175.0,
				"color": Color(0.48, 0.88, 1.0),
				"desc": "Throw a crackling thunder Stun Bomb stunning enemies in its circle 1.8s."
			}
		],
		"ultimate": {
			"name": "Thor Mjolnir Storm",
			"kind": "ult_stun_nova",
			"cooldown": 22.0,
			"damage": 62,
			"stun": 2.0,
			"color": Color(0.42, 0.88, 1.0),
			"desc": "Bring down thunder that shocks and stuns all nearby foes 2.0s."
		}
	},
	# 8: Galahad // Crusader Knight
	{
		"id": 8,
		"agent_name": "Galahad",
		"title": "Crusader Knight",
		"role": "Templar Paladin",
		"accent": Color(0.92, 0.95, 1.0),
		"base_weapon": {
			"name": "Templar Greatsword",
			"style": "greatsword",
			"damage": 29,
			"cooldown": 0.42,
			"range": 124.0,
			"color": Color(0.94, 0.96, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Excalibur Giant Cleave",
				"kind": "cleave",
				"cooldown": 5.5,
				"damage": 48,
				"color": Color(1.0, 0.92, 0.45),
				"desc": "Swing an enormous radiant greatsword energy wave."
			},
			{
				"name": "Holy Aegis Wall",
				"kind": "wall",
				"cooldown": 8.5,
				"damage": 0,
				"wall_hp": 270,
				"duration": 6.0,
				"color": Color(0.95, 0.88, 0.55),
				"desc": "Create a sanctified golden shield wall."
			},
			{
				"name": "Judgment Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 8.0,
				"damage": 26,
				"stun": 1.7,
				"color": Color(1.0, 0.94, 0.52),
				"desc": "Throw a consecrated light Stun Bomb stunning enemies in its circle 1.7s."
			}
		],
		"ultimate": {
			"name": "Grand Crusade Greatsword",
			"kind": "ult_giant_sword",
			"cooldown": 22.0,
			"damage": 68,
			"stun": 1.0,
			"color": Color(1.0, 0.94, 0.42),
			"desc": "Send 3 colossus Excalibur blades tearing across the map."
		}
	},
	# 9: King Arthur // Royal King
	{
		"id": 9,
		"agent_name": "King Arthur",
		"title": "Royal King",
		"role": "High Sovereign",
		"accent": Color(1.0, 0.78, 0.24),
		"base_weapon": {
			"name": "Caliburn Broadsword",
			"style": "greatsword",
			"damage": 27,
			"cooldown": 0.39,
			"range": 118.0,
			"color": Color(1.0, 0.85, 0.32),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Royal Decree Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 8.0,
				"damage": 26,
				"stun": 1.7,
				"color": Color(1.0, 0.86, 0.28),
				"desc": "Throw a gilded Royal Decree Stun Bomb stunning enemies in its circle 1.8s."
			},
			{
				"name": "Royal Chariot Dash",
				"kind": "dash_speed",
				"cooldown": 5.5,
				"damage": 24,
				"speed_mult": 1.75,
				"duration": 3.8,
				"color": Color(0.86, 0.28, 0.32),
				"desc": "Surge forward in a royal blitz charge with speed boost."
			},
			{
				"name": "Royal Musket Volley",
				"kind": "gun_burst",
				"cooldown": 6.5,
				"damage": 15,
				"shots": 6,
				"color": Color(1.0, 0.82, 0.35),
				"desc": "Fire a rapid 6-round royal flintlock volley."
			}
		],
		"ultimate": {
			"name": "Sovereign Solar Flare",
			"kind": "ult_firestorm",
			"cooldown": 22.0,
			"damage": 40,
			"color": Color(1.0, 0.65, 0.16),
			"desc": "Launch a crown salvo of 6 blazing solar fireballs."
		}
	},
	# 10: Blackbeard // Pirate Buccaneer
	{
		"id": 10,
		"agent_name": "Blackbeard",
		"title": "Barrel Pirate",
		"role": "Sea Buccaneer",
		"accent": Color(0.88, 0.32, 0.32),
		"base_weapon": {
			"name": "Corsair Cutlass",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.32,
			"range": 106.0,
			"color": Color(0.86, 0.90, 0.96),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Blunderbuss Cannon",
				"kind": "shotgun_blast",
				"cooldown": 6.0,
				"damage": 16,
				"shots": 5,
				"color": Color(1.0, 0.70, 0.28),
				"desc": "Blast a 6-shot pirate blunderbuss cannon spread."
			},
			{
				"name": "Grapple Teleport",
				"kind": "teleport",
				"cooldown": 7.0,
				"damage": 24,
				"color": Color(0.95, 0.56, 0.24),
				"desc": "Hook-teleport up to 260px along your aim angle."
			},
			{
				"name": "Powder Keg Mortar",
				"kind": "lava_bomb",
				"cooldown": 7.5,
				"damage": 42,
				"stun": 1.6,
				"radius": 110.0,
				"color": Color(1.0, 0.42, 0.14),
				"desc": "Throw an ignited barrel powder keg bomb that explodes and stuns foes in its circle 1.6s."
			}
		],
		"ultimate": {
			"name": "Galleon Broadside Salvo",
			"kind": "ult_firestorm",
			"cooldown": 22.0,
			"damage": 42,
			"color": Color(1.0, 0.36, 0.12),
			"desc": "Bombard the arena with a 6-shot pirate cannonball barrage."
		}
	},
	# 11: Kenshin // Shadow Ninja
	{
		"id": 11,
		"agent_name": "Kenshin",
		"title": "Shadow Ninja",
		"role": "Silent Assassin",
		"accent": Color(0.68, 0.36, 1.0),
		"base_weapon": {
			"name": "Muramasa Katana",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.28,
			"range": 108.0,
			"color": Color(0.76, 0.48, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Shadow Teleport",
				"kind": "teleport",
				"cooldown": 6.0,
				"damage": 28,
				"color": Color(0.68, 0.36, 1.0),
				"desc": "Blink instantly behind or onto foes, slashing at arrival."
			},
			{
				"name": "Triple Shadow Shurikens",
				"kind": "shuriken_fan",
				"shots": 3,
				"cooldown": 5.5,
				"damage": 42,
				"color": Color(0.62, 0.84, 1.0),
				"desc": "Throw a 3-star fan of razor ninja shurikens."
			},
			{
				"name": "Smoke Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 8.0,
				"damage": 24,
				"stun": 1.6,
				"color": Color(0.74, 0.48, 1.0),
				"desc": "Throw a ninja Smoke Stun Bomb immobilizing enemies in its circle 1.7s."
			}
		],
		"ultimate": {
			"name": "Dragonblade Omnislash",
			"kind": "ult_blink_slash",
			"cooldown": 22.0,
			"damage": 66,
			"stun": 1.1,
			"color": Color(0.74, 0.34, 1.0),
			"desc": "Phantom-teleport strike with massive cursed katana waves."
		}
	},
	# 12: Rotjaw // Brain Zombie
	{
		"id": 12,
		"agent_name": "Rotjaw",
		"title": "Brain Zombie",
		"role": "Undead Brawler",
		"accent": Color(0.45, 0.92, 0.28),
		"base_weapon": {
			"name": "Infected Mutant Claws",
			"style": "claws",
			"damage": 25,
			"cooldown": 0.32,
			"range": 96.0,
			"color": Color(0.58, 0.95, 0.34),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Psychic Brain Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 7.5,
				"damage": 24,
				"stun": 1.9,
				"color": Color(1.0, 0.48, 0.74),
				"desc": "Throw a radioactive Brain Stun Bomb stunning enemies in its circle 1.9s."
			},
			{
				"name": "Rabid Sprint",
				"kind": "speed",
				"cooldown": 6.0,
				"damage": 0,
				"duration": 4.0,
				"speed_mult": 1.85,
				"color": Color(0.55, 0.95, 0.32),
				"desc": "Frenzy forward at terrifying undead speed + regenerate 15 HP."
			},
			{
				"name": "Bile Acid Mortar",
				"kind": "lava_bomb",
				"cooldown": 7.5,
				"damage": 38,
				"stun": 1.6,
				"radius": 110.0,
				"color": Color(0.52, 0.96, 0.24),
				"desc": "Lob a corrosive undead bile bomb that explodes and stuns enemies in an acid circle 1.6s."
			}
		],
		"ultimate": {
			"name": "Doomsday Plague Eruption",
			"kind": "ult_stun_nova",
			"cooldown": 22.0,
			"damage": 60,
			"stun": 1.8,
			"color": Color(0.48, 0.96, 0.28),
			"desc": "Erupt a toxic shockwave dealing heavy damage and 1.8s stun."
		}
	},
	# 13: Marrow // Skull Skeleton
	{
		"id": 13,
		"agent_name": "Marrow",
		"title": "Skull Skeleton",
		"role": "Cursed Warrior",
		"accent": Color(0.88, 0.90, 0.95),
		"base_weapon": {
			"name": "Cursed Bone Bow",
			"style": "bow",
			"damage": 22,
			"cooldown": 0.37,
			"range": 660.0,
			"color": Color(0.88, 0.92, 1.0),
			"ranged": true
		},
		"abilities": [
			{
				"name": "Ribcage Bone Wall",
				"kind": "wall",
				"cooldown": 8.0,
				"damage": 0,
				"wall_hp": 230,
				"duration": 5.8,
				"color": Color(0.88, 0.88, 0.94),
				"desc": "Raise a fortress wall of cursed skeleton bones."
			},
			{
				"name": "Cursed Bone Axes",
				"kind": "axe_volley",
				"shots": 2,
				"cooldown": 6.0,
				"damage": 40,
				"color": Color(0.95, 0.38, 0.22),
				"desc": "Hurl twin cursed spinning skeletal executioner axes."
			},
			{
				"name": "Crypt Shadow Teleport",
				"kind": "teleport",
				"cooldown": 7.0,
				"damage": 22,
				"color": Color(0.66, 0.72, 0.96),
				"desc": "Reassemble instantaneously through shadows up to 260px."
			}
		],
		"ultimate": {
			"name": "Catacomb Skull Storm",
			"kind": "ult_firestorm",
			"cooldown": 22.0,
			"damage": 40,
			"color": Color(0.96, 0.34, 0.28),
			"desc": "Unleash 6 exploding hellfire skulls across the battlefield."
		}
	},
	# 14: Wraith // Spooky Ghost
	{
		"id": 14,
		"agent_name": "Wraith",
		"title": "Azure Flame Mage",
		"role": "Spectral Phantom",
		"accent": Color(0.70, 0.92, 1.0),
		"base_weapon": {
			"name": "Grim Reaper Scythe",
			"style": "scythe",
			"damage": 27,
			"cooldown": 0.38,
			"range": 124.0,
			"color": Color(0.70, 0.94, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Azure Spectral Wisps",
				"kind": "ghost_wisps",
				"shots": 3,
				"cooldown": 5.5,
				"damage": 25,
				"color": Color(0.75, 0.94, 1.0),
				"desc": "Unleash 3 homing azure flame wisps that track enemies."
			},
			{
				"name": "Banshee Stun Wail",
				"kind": "stun_aoe",
				"cooldown": 8.0,
				"damage": 24,
				"stun": 1.8,
				"color": Color(0.64, 0.90, 1.0),
				"desc": "Release a spectral shriek freezing nearby foes for 1.8s."
			},
			{
				"name": "Banshee Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 6.5,
				"damage": 22,
				"duration": 4.2,
				"speed_mult": 1.85,
				"stun": 1.8,
				"radius": 175.0,
				"color": Color(0.82, 0.96, 1.0),
				"desc": "Throw a chilling azure Stun Bomb stunning enemies in its circle 1.8s."
			}
		],
		"ultimate": {
			"name": "Soul Harvest Vortex",
			"kind": "ult_blink_slash",
			"cooldown": 22.0,
			"damage": 66,
			"stun": 1.2,
			"color": Color(0.60, 0.92, 1.0),
			"desc": "Blink forward and reap everything with giant ghostly scythes."
		}
	},
	# 15: Imhotep // Ancient Mummy
	{
		"id": 15,
		"agent_name": "Imhotep",
		"title": "Ancient Mummy",
		"role": "Tomb Guardian",
		"accent": Color(0.95, 0.78, 0.34),
		"base_weapon": {
			"name": "Pharaoh Khopesh Sword",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.34,
			"range": 106.0,
			"color": Color(0.95, 0.80, 0.32),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Mummy Wrap Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 7.5,
				"damage": 22,
				"stun": 2.0,
				"color": Color(0.96, 0.88, 0.62),
				"desc": "Throw a cursed Scarab Stun Bomb stunning enemies in its circle 2.0s."
			},
			{
				"name": "Sandstone Obelisk Wall",
				"kind": "wall",
				"cooldown": 8.5,
				"damage": 0,
				"wall_hp": 250,
				"duration": 6.0,
				"color": Color(0.90, 0.76, 0.44),
				"desc": "Erect a desert sandstone obelisk wall."
			},
			{
				"name": "Solar Scarab Fan",
				"kind": "flame_wave",
				"shots": 3,
				"cooldown": 6.5,
				"damage": 40,
				"color": Color(1.0, 0.54, 0.16),
				"desc": "Throw a blazing 3-orb desert sun-fire fan."
			}
		],
		"ultimate": {
			"name": "Curse of the Pharaoh",
			"kind": "ult_stun_nova",
			"cooldown": 22.0,
			"damage": 60,
			"stun": 2.1,
			"color": Color(1.0, 0.78, 0.24),
			"desc": "Unleash an ancient tomb curse locking nearby foes 2.1s."
		}
	},
	# 16: Aegis-7 // Cyber Robot
	{
		"id": 16,
		"agent_name": "Aegis-7",
		"title": "Cube Mech Robot",
		"role": "Heavy Automaton",
		"accent": Color(0.32, 0.94, 1.0),
		"base_weapon": {
			"name": "Plasma Greatsword",
			"style": "greatsword",
			"damage": 27,
			"cooldown": 0.38,
			"range": 120.0,
			"color": Color(0.32, 0.94, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Laser Gatling Burst",
				"kind": "gun_burst",
				"cooldown": 6.0,
				"damage": 14,
				"shots": 6,
				"color": Color(0.28, 0.96, 1.0),
				"desc": "Deploy arm-mounted laser cannons firing 6 plasma bolts."
			},
			{
				"name": "Quantum Thruster Blink",
				"kind": "teleport",
				"cooldown": 6.5,
				"damage": 22,
				"color": Color(0.38, 0.94, 1.0),
				"desc": "Quantum warp through space up to 260px."
			},
			{
				"name": "Cryo-Shard Interceptor",
				"kind": "ice_shards",
				"shots": 4,
				"cooldown": 8.5,
				"damage": 14,
				"wall_hp": 260,
				"duration": 6.0,
				"color": Color(0.28, 0.88, 1.0),
				"desc": "Fire a 4-shard high-velocity holographic crystal spread."
			}
		],
		"ultimate": {
			"name": "Omega Orbital Cannon",
			"kind": "ult_gun_storm",
			"cooldown": 22.0,
			"damage": 18,
			"shots": 14,
			"stun": 1.2,
			"color": Color(0.32, 0.98, 1.0),
			"desc": "Overload reactors with 14 staggering plasma laser blasts."
		}
	},
	# 17: Viper-X // Bio-Hazard Cyborg
	{
		"id": 17,
		"agent_name": "Viper-X",
		"title": "Bio-Hazard Cyborg",
		"role": "Bio Specialist",
		"accent": Color(0.26, 0.96, 0.56),
		"base_weapon": {
			"name": "Venom Twin Daggers",
			"style": "daggers",
			"damage": 21,
			"cooldown": 0.26,
			"range": 94.0,
			"color": Color(0.32, 0.98, 0.56),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Chem-Flame Spray",
				"kind": "flame_wave",
				"shots": 3,
				"cooldown": 6.0,
				"damage": 40,
				"color": Color(0.32, 0.96, 0.44),
				"desc": "Launch a 3-stream pressurized toxic plasma fireball fan."
			},
			{
				"name": "Bio-Containment Wall",
				"kind": "wall",
				"cooldown": 8.5,
				"damage": 0,
				"wall_hp": 240,
				"duration": 5.8,
				"color": Color(0.26, 0.88, 0.48),
				"desc": "Deploy a bio-containment forcefield wall."
			},
			{
				"name": "Overclock Speed Surge",
				"kind": "speed",
				"cooldown": 6.0,
				"damage": 0,
				"duration": 4.2,
				"speed_mult": 1.85,
				"color": Color(0.40, 1.0, 0.65),
				"desc": "Inject adrenaline booster for hyper movement speed."
			}
		],
		"ultimate": {
			"name": "Neurotoxin Supernova",
			"kind": "ult_stun_nova",
			"cooldown": 22.0,
			"damage": 62,
			"stun": 2.0,
			"color": Color(0.28, 0.98, 0.52),
			"desc": "Detonate a massive bio-cloud paralyzing nearby foes 2.0s."
		}
	},
	# 18: Nyx // Shadow Cat
	{
		"id": 18,
		"agent_name": "Nyx",
		"title": "Shadow Cat",
		"role": "Feline Striker",
		"accent": Color(1.0, 0.78, 0.28),
		"base_weapon": {
			"name": "Nightstalker Claws",
			"style": "claws",
			"damage": 22,
			"cooldown": 0.25,
			"range": 96.0,
			"color": Color(1.0, 0.82, 0.34),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Shadow Pounce Blink",
				"kind": "teleport",
				"cooldown": 5.5,
				"damage": 24,
				"color": Color(0.65, 0.45, 0.98),
				"desc": "Teleport-pounce onto distant ledges or behind enemies."
			},
			{
				"name": "Nine-Lives Hyper Speed",
				"kind": "speed",
				"cooldown": 6.0,
				"damage": 0,
				"speed_mult": 1.85,
				"duration": 4.2,
				"color": Color(1.0, 0.84, 0.32),
				"desc": "Dash at blinding feline speed + heal 15 HP."
			},
			{
				"name": "Golden Bell Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 7.5,
				"damage": 22,
				"stun": 1.6,
				"color": Color(1.0, 0.88, 0.30),
				"desc": "Throw a sonic Golden Bell Stun Bomb stunning enemies in its circle 1.6s."
			}
		],
		"ultimate": {
			"name": "Midnight Panther Flurry",
			"kind": "ult_blink_slash",
			"cooldown": 22.0,
			"damage": 64,
			"stun": 1.2,
			"color": Color(1.0, 0.78, 0.26),
			"desc": "Blink-slash with giant golden crescent claw waves."
		}
	},
	# 19: Ryu // Dragon Hero
	{
		"id": 19,
		"agent_name": "Ryu",
		"title": "Dragon Hero",
		"role": "Blade Hero",
		"accent": Color(0.28, 0.94, 0.68),
		"base_weapon": {
			"name": "Dragonbuster Big Sword",
			"style": "greatsword",
			"damage": 28,
			"cooldown": 0.36,
			"range": 126.0,
			"color": Color(0.32, 0.96, 0.72),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Dragon Breath Fan",
				"kind": "flame_wave",
				"shots": 3,
				"cooldown": 5.5,
				"damage": 42,
				"color": Color(1.0, 0.48, 0.16),
				"desc": "Breathe a 3-fireball fan of searing emerald dragon flames."
			},
			{
				"name": "Giant Blade Wave",
				"kind": "cleave",
				"cooldown": 5.5,
				"damage": 48,
				"color": Color(0.34, 0.98, 0.76),
				"desc": "Slash with your big sword to fire a massive emerald wave."
			},
			{
				"name": "Sky-Dragon Dash",
				"kind": "dash_speed",
				"cooldown": 6.0,
				"damage": 20,
				"duration": 4.0,
				"speed_mult": 1.8,
				"color": Color(0.45, 0.96, 0.72),
				"desc": "Launch forward at dragon speed with a sword rush."
			}
		],
		"ultimate": {
			"name": "Bahamut Mega-Flare",
			"kind": "ult_giant_sword",
			"cooldown": 22.0,
			"damage": 70,
			"stun": 1.2,
			"color": Color(0.32, 1.0, 0.72),
			"desc": "Unleash 3 titanic dragon-fire greatsword beams."
		}
	},
	# 20: Grom // Fierce Orc
	{
		"id": 20,
		"agent_name": "Grom",
		"title": "Fierce Orc",
		"role": "Ogre Warlord",
		"accent": Color(0.78, 0.42, 0.96),
		"base_weapon": {
			"name": "Bloodtusk Giant Cleaver",
			"style": "axe",
			"damage": 30,
			"cooldown": 0.42,
			"range": 116.0,
			"color": Color(0.90, 0.45, 0.98),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Warlord Throwing Axes",
				"kind": "axe_volley",
				"shots": 2,
				"cooldown": 7.5,
				"damage": 26,
				"stun": 1.8,
				"color": Color(0.84, 0.42, 1.0),
				"desc": "Heave twin brutal spinning warlord throwing axes."
			},
			{
				"name": "Skullcrusher Big Slash",
				"kind": "cleave",
				"cooldown": 5.5,
				"damage": 50,
				"color": Color(0.94, 0.36, 0.48),
				"desc": "Heave a gigantic warlord cleaver shockwave."
			},
			{
				"name": "Warcry Shock Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 8.5,
				"damage": 24,
				"wall_hp": 260,
				"duration": 6.0,
				"stun": 1.8,
				"radius": 175.0,
				"color": Color(0.68, 0.42, 0.85),
				"desc": "Throw a concussive shock Stun Bomb stunning enemies in its circle 1.8s."
			}
		],
		"ultimate": {
			"name": "Bloodlust Titan Slam",
			"kind": "ult_giant_sword",
			"cooldown": 22.0,
			"damage": 68,
			"stun": 1.5,
			"color": Color(0.95, 0.34, 0.48),
			"desc": "Hurl 3 colossal warlord cleaver waves that stun foes."
		}
	},
	# 21: Ignis // Magma Golem
	{
		"id": 21,
		"agent_name": "Ignis",
		"title": "Crimson Flame Mage",
		"role": "Lava Colossus",
		"accent": Color(1.0, 0.44, 0.14),
		"base_weapon": {
			"name": "Volcanic Magma Hammer",
			"style": "hammer",
			"damage": 30,
			"cooldown": 0.44,
			"range": 114.0,
			"color": Color(1.0, 0.48, 0.14),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Molten Magma Fireball",
				"kind": "fireball",
				"cooldown": 5.5,
				"damage": 44,
				"color": Color(1.0, 0.38, 0.12),
				"desc": "Hurl a molten magma fireball that detonates in a fiery blast."
			},
			{
				"name": "Scorching Flame Throw",
				"kind": "flame_wave",
				"shots": 3,
				"cooldown": 6.5,
				"damage": 26,
				"wall_hp": 280,
				"duration": 6.0,
				"color": Color(0.95, 0.42, 0.16),
				"desc": "Throw a 3-fireball scorching flame fan across your aim."
			},
			{
				"name": "Lava Geyser Stun Bomb",
				"kind": "lava_bomb",
				"cooldown": 7.5,
				"damage": 28,
				"stun": 1.8,
				"color": Color(1.0, 0.58, 0.18),
				"desc": "Throw a molten Lava Stun Bomb blasting and stunning enemies in its circle 1.6s."
			}
		],
		"ultimate": {
			"name": "Krakatoa Volcano Cataclysm",
			"kind": "ult_firestorm",
			"shots": 9,
			"cooldown": 22.0,
			"damage": 44,
			"color": Color(1.0, 0.32, 0.08),
			"desc": "Erupt 9 blazing magma fireballs raining destruction across the arena."
		}
	},
	# 22: Prism // Crystal Golem
	{
		"id": 22,
		"agent_name": "Prism",
		"title": "Crystal Golem",
		"role": "Quartz Elemental",
		"accent": Color(1.0, 0.56, 0.88),
		"base_weapon": {
			"name": "Diamond Crystal Lance",
			"style": "spear",
			"damage": 26,
			"cooldown": 0.36,
			"range": 122.0,
			"color": Color(1.0, 0.60, 0.88),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Prismatic Shard Volley",
				"kind": "ice_shards",
				"shots": 4,
				"cooldown": 8.0,
				"damage": 14,
				"wall_hp": 260,
				"duration": 6.0,
				"color": Color(1.0, 0.58, 0.86),
				"desc": "Shoot a dazzling 4-bolt crystalline prism spread."
			},
			{
				"name": "Light-Beam Teleport",
				"kind": "teleport",
				"cooldown": 6.5,
				"damage": 24,
				"color": Color(1.0, 0.70, 0.94),
				"desc": "Refract into pure light and teleport up to 260px."
			},
			{
				"name": "Prism Flash Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 7.5,
				"damage": 24,
				"stun": 1.8,
				"color": Color(1.0, 0.64, 0.94),
				"desc": "Throw a blinding quartz Stun Bomb stunning enemies in its circle 1.8s."
			}
		],
		"ultimate": {
			"name": "Crystal Shatterstorm",
			"kind": "ult_gun_storm",
			"cooldown": 22.0,
			"damage": 18,
			"shots": 14,
			"stun": 0.7,
			"color": Color(1.0, 0.56, 0.88),
			"desc": "Unleash 14 high-velocity prismatic shard beams."
		}
	},
	# 23: Zenyu // Tribal Monk
	{
		"id": 23,
		"agent_name": "Zenyu",
		"title": "Tribal Monk",
		"role": "Martial Master",
		"accent": Color(0.98, 0.42, 0.28),
		"base_weapon": {
			"name": "Grandmaster Bo-Staff",
			"style": "staff",
			"damage": 25,
			"cooldown": 0.31,
			"range": 120.0,
			"color": Color(0.95, 0.68, 0.36),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Chi Spirit Fireball",
				"kind": "fireball",
				"cooldown": 5.5,
				"damage": 40,
				"color": Color(1.0, 0.56, 0.18),
				"desc": "Focus inner chi into a blazing explosive fireball."
			},
			{
				"name": "Dim-Mak Stun Bomb",
				"kind": "stun_bomb",
				"cooldown": 7.5,
				"damage": 24,
				"stun": 2.0,
				"color": Color(1.0, 0.84, 0.28),
				"desc": "Throw a chi-charged Stun Bomb stunning enemies in its circle 2.0s."
			},
			{
				"name": "Wind-Step Teleport",
				"kind": "teleport",
				"cooldown": 6.0,
				"damage": 24,
				"color": Color(0.45, 0.94, 0.88),
				"desc": "Instantaneously step across the wind up to 260px."
			}
		],
		"ultimate": {
			"name": "Thousand-Palm Nirvana",
			"kind": "ult_stun_nova",
			"cooldown": 22.0,
			"damage": 64,
			"stun": 2.0,
			"color": Color(1.0, 0.78, 0.24),
			"desc": "Radiate golden enlightenment blasting and stunning foes 2.0s."
		}
	},
	# 24: Raven // Shadow Corvus
	{
		"id": 24,
		"agent_name": "Raven",
		"title": "Shadow Corvus",
		"role": "Dark Mystic",
		"accent": Color(0.58, 0.28, 0.92),
		"base_weapon": {
			"name": "Obsidian Talon Bow",
			"style": "bow",
			"damage": 22,
			"cooldown": 0.36,
			"range": 260.0,
			"color": Color(0.58, 0.28, 0.92),
			"ranged": true
		},
		"abilities": [
			{
				"name": "Murder of Ravens",
				"kind": "raven_swarm",
				"cooldown": 6.5,
				"damage": 28,
				"shots": 3,
				"color": Color(0.28, 0.16, 0.45),
				"desc": "Spawn 3 homing ravens that fly, track, and attack enemies."
			},
			{
				"name": "Dark Telekinesis",
				"kind": "telekinesis",
				"cooldown": 5.5,
				"damage": 38,
				"color": Color(0.68, 0.35, 0.98),
				"desc": "Grab a nearby throwable object and hurl it at an enemy."
			},
			{
				"name": "Shadow Smoke",
				"kind": "reverse_smoke",
				"cooldown": 8.0,
				"damage": 20,
				"duration": 4.0,
				"color": Color(0.18, 0.12, 0.26),
				"desc": "Shoot dark smoke that reverses hit enemies' controls for 4s."
			}
		],
		"ultimate": {
			"name": "Shadow Ambush",
			"kind": "ult_backstab_tp",
			"cooldown": 18.0,
			"damage": 0,
			"color": Color(0.62, 0.24, 0.95),
			"desc": "Teleport directly behind the nearest enemy."
		}
	},
	# 25: Ray Lina // Young Elf
	{
		"id": 25,
		"agent_name": "Ray Lina",
		"title": "Young Elf",
		"role": "Adaptive Prodigy",
		"accent": Color(0.38, 0.96, 0.64),
		"base_weapon": {
			"name": "Sylvan Star Bow",
			"style": "bow",
			"damage": 21,
			"cooldown": 0.34,
			"range": 260.0,
			"color": Color(0.38, 0.96, 0.64),
			"ranged": true
		},
		"abilities": [
			{
				"name": "Random Mimic I",
				"kind": "ice_shards",
				"cooldown": 5.0,
				"damage": 16,
				"color": Color(0.38, 0.96, 0.64),
				"desc": "Randomly rolled ability; steals victim's kit on kill."
			},
			{
				"name": "Random Mimic II",
				"kind": "teleport",
				"cooldown": 6.0,
				"damage": 24,
				"color": Color(0.38, 0.96, 0.64),
				"desc": "Randomly rolled ability; steals victim's kit on kill."
			},
			{
				"name": "Random Mimic III",
				"kind": "fireball",
				"cooldown": 5.5,
				"damage": 38,
				"color": Color(0.38, 0.96, 0.64),
				"desc": "Randomly rolled ability; steals victim's kit on kill."
			}
		],
		"ultimate": {
			"name": "Mimic Ultimate",
			"kind": "ult_blink_slash",
			"cooldown": 20.0,
			"damage": 58,
			"color": Color(0.38, 0.96, 0.64),
			"desc": "Randomly rolled ultimate; steals victim's ultimate on kill."
		}
	}
]
static func get_agent(arch_id: int) -> Dictionary:
	return AGENTS[clampi(arch_id, 0, AGENTS.size() - 1)]


static func get_throwable(item_id: int) -> Dictionary:
	return THROWABLE_ITEMS[clampi(item_id, 0, THROWABLE_ITEMS.size() - 1)]


static func get_ability_slot(arch_id: int, slot_idx: int) -> Dictionary:
	var ag: Dictionary = get_agent(arch_id)
	if slot_idx == 3:
		return ag["ultimate"]
	var abils: Array = ag["abilities"]
	return abils[clampi(slot_idx, 0, abils.size() - 1)]


const TAUNTS: Array[Dictionary] = [
	{"id": 0, "name": "Tactical Victory Dance", "emoji": "🕺", "text": "EZ!", "anim": "dance", "sfx": "dance", "color": Color(0.45, 0.92, 0.55)},
	{"id": 1, "name": "Moonwalk Slide", "emoji": "✨", "text": "SMOOTH!", "anim": "slide", "sfx": "dance", "color": Color(0.38, 0.85, 1.0)},
	{"id": 2, "name": "Finger-Gun Spin", "emoji": "👉", "text": "Too slow!", "anim": "wink", "sfx": "pop", "color": Color(1.0, 0.78, 0.24)},
	{"id": 3, "name": "Middle Finger Salute", "emoji": "🖕", "text": "PEACE!", "anim": "salute", "sfx": "pop", "color": Color(1.0, 0.35, 0.28)},
	{"id": 4, "name": "Yawn & Watch Check", "emoji": "🥱", "text": "Boring...", "anim": "yawn", "sfx": "huh", "color": Color(0.65, 0.78, 0.95)},
	{"id": 5, "name": "Spartan Chest Pound", "emoji": "🛡️", "text": "THIS IS SPARTA!", "anim": "roar", "sfx": "roar", "color": Color(1.0, 0.42, 0.22)},
	{"id": 6, "name": "Gladiator Thumbs Down", "emoji": "👎", "text": "NOPE.", "anim": "thumbs_down", "sfx": "huh", "color": Color(0.95, 0.30, 0.30)},
	{"id": 7, "name": "Viking War Dance", "emoji": "🪓", "text": "SKOL!", "anim": "stomp", "sfx": "dance", "color": Color(0.55, 0.86, 1.0)},
	{"id": 8, "name": "Polite Tea-Sip Bow", "emoji": "☕", "text": "M'lady", "anim": "bow", "sfx": "pop", "color": Color(0.95, 0.88, 0.55)},
	{"id": 9, "name": "Royal Hair Flip & Laugh", "emoji": "👑", "text": "HAHAHA!", "anim": "laugh", "sfx": "laugh", "color": Color(1.0, 0.84, 0.22)},
	{"id": 10, "name": "Pirate Jig", "emoji": "🏴‍☠️", "text": "YARR!", "anim": "jig", "sfx": "dance", "color": Color(0.95, 0.58, 0.20)},
	{"id": 11, "name": "Ninja \"Huh?\"", "emoji": "❓", "text": "HUH?!", "anim": "huh", "sfx": "huh", "color": Color(0.75, 0.55, 1.0)},
	{"id": 12, "name": "Toxic Fart Cloud", "emoji": "💨", "text": "*BRAAAP!*", "anim": "fart", "sfx": "fart", "color": Color(0.45, 0.92, 0.25)},
	{"id": 13, "name": "Skeleton Shuffle", "emoji": "💀", "text": "RATTLE!", "anim": "rattle", "sfx": "dance", "color": Color(0.88, 0.92, 0.98)},
	{"id": 14, "name": "Peek-a-Boo Spook", "emoji": "👻", "text": "BOO!", "anim": "spook", "sfx": "pop", "color": Color(0.55, 0.95, 1.0)},
	{"id": 15, "name": "Walk Like an Egyptian", "emoji": "🔺", "text": "PHARAOH!", "anim": "egypt", "sfx": "dance", "color": Color(1.0, 0.82, 0.28)},
	{"id": 16, "name": "Robot Breakdance", "emoji": "🤖", "text": "BEEP BOOP", "anim": "robot", "sfx": "dance", "color": Color(0.35, 0.82, 1.0)},
	{"id": 17, "name": "Slap-Knee Laugh", "emoji": "😂", "text": "LMAO!", "anim": "slap_knee", "sfx": "laugh", "color": Color(0.42, 0.96, 0.52)},
	{"id": 18, "name": "Cat Stretch & Lick", "emoji": "😼", "text": "Meow~", "anim": "stretch", "sfx": "pop", "color": Color(0.98, 0.62, 0.88)},
	{"id": 19, "name": "\"Bring It\" Wave", "emoji": "👋", "text": "Come on!", "anim": "bring_it", "sfx": "roar", "color": Color(0.38, 0.82, 1.0)},
	{"id": 20, "name": "Belly Drum & Burp", "emoji": "🤢", "text": "*BURP!*", "anim": "burp", "sfx": "fart", "color": Color(0.58, 0.86, 0.28)},
	{"id": 21, "name": "Spicy Hot-Foot Dance", "emoji": "🔥", "text": "HOT HOT!", "anim": "hot_foot", "sfx": "dance", "color": Color(1.0, 0.42, 0.14)},
	{"id": 22, "name": "Disco Spin & Point", "emoji": "🪩", "text": "GROOVY!", "anim": "disco", "sfx": "dance", "color": Color(0.92, 0.48, 1.0)},
	{"id": 23, "name": "Confused Shrug", "emoji": "🤷", "text": "Huh??", "anim": "shrug", "sfx": "huh", "color": Color(1.0, 0.82, 0.32)}
]


static func get_taunt(taunt_id: int) -> Dictionary:
	return TAUNTS[clampi(taunt_id, 0, TAUNTS.size() - 1)]
