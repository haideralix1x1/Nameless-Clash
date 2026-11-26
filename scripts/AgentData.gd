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
	# 0: Contra // The Soldier
	{
		"id": 0,
		"agent_name": "Contra",
		"title": "The Soldier",
		"role": "Frontline Vanguard",
		"accent": Color(0.45, 0.82, 0.38),
		"base_weapon": {
			"name": "Desert Eagle",
			"style": "deagle",
			"damage": 24,
			"cooldown": 0.34,
			"range": 380.0,
			"color": Color(1.0, 0.86, 0.35),
			"ranged": true
		},
		"abilities": [
			{
				"name": "M4A1 Rifle Burst",
				"kind": "gun_burst",
				"shots": 6,
				"damage": 12,
				"color": Color(0.95, 0.85, 0.35),
				"desc": "Fire a rapid 6-round M4A1 burst."
			},
			{
				"name": "Rapid Impact Grenade",
				"kind": "impact_grenade",
				"damage": 55,
				"stun": 0.5,
				"color": Color(0.95, 0.48, 0.18),
				"desc": "Throw a grenade that blasts immediately on impact."
			},
			{
				"name": "Steel Bunker Wall",
				"kind": "wall",
				"damage": 0,
				"wall_hp": 260,
				"duration": 5.5,
				"color": Color(0.55, 0.68, 0.58),
				"desc": "Deploy a steel bunker barrier wall."
			}
		],
		"ultimate": {
			"name": "Target-Follow Bazooka",
			"kind": "ult_homing_bazooka",
			"damage": 100,
			"color": Color(1.0, 0.35, 0.15),
			"desc": "Fire a target-tracking bazooka missile that 1-shots on hit."
		}
	},
	# 1: Mike Jones // The Explorer
	{
		"id": 1,
		"agent_name": "Mike Jones",
		"title": "The Explorer",
		"role": "Field Adventurer",
		"accent": Color(0.86, 0.66, 0.34),
		"base_weapon": {
			"name": "Jungle Machete",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.32,
			"range": 102.0,
			"color": Color(0.92, 0.82, 0.48),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Grapple Hook",
				"kind": "hook_drag",
				"damage": 20,
				"color": Color(0.88, 0.72, 0.32),
				"desc": "Hook an enemy player and drag them straight to you."
			},
			{
				"name": "Flash Bird",
				"kind": "flash_bird",
				"damage": 15,
				"duration": 3.0,
				"color": Color(1.0, 0.96, 0.75),
				"desc": "Spawn a homing bird that blinds the hit enemy's screen white for 3s."
			},
			{
				"name": "Gradual Self Heal",
				"kind": "gradual_heal",
				"damage": 0,
				"duration": 4.0,
				"color": Color(0.32, 0.96, 0.52),
				"desc": "Gradually regenerate health back up to 100%."
			}
		],
		"ultimate": {
			"name": "Winged Lion",
			"kind": "ult_winged_lion",
			"damage": 100,
			"duration": 4.0,
			"color": Color(1.0, 0.78, 0.22),
			"desc": "Summon a winged lion for 4s that chases nearby enemies and kills on attack."
		}
	},
	# 2: Bruski // The Outlaw
	{
		"id": 2,
		"agent_name": "Bruski",
		"title": "The Outlaw",
		"role": "Outback Marksman",
		"accent": Color(0.92, 0.42, 0.24),
		"base_weapon": {
			"name": "Frontier Revolver",
			"style": "bruski_revolver",
			"damage": 24,
			"cooldown": 0.36,
			"range": 260.0,
			"color": Color(0.96, 0.65, 0.32),
			"ranged": true
		},
		"abilities": [
			{
				"name": "Dual Shotguns",
				"kind": "dual_shotguns",
				"damage": 25,
				"shots": 5,
				"duration": 4.0,
				"color": Color(1.0, 0.55, 0.22),
				"desc": "Equip dual shotguns for 4s (up to 5 blasts)."
			},
			{
				"name": "Sticky Bomb",
				"kind": "sticky_bomb",
				"damage": 100,
				"color": Color(1.0, 0.32, 0.18),
				"desc": "Throw a sticky bomb that blasts for 100% damage."
			},
			{
				"name": "Chainsaw Blade",
				"kind": "bouncing_chainsaw",
				"damage": 100,
				"duration": 5.0,
				"color": Color(0.88, 0.88, 0.94),
				"desc": "Throw a wall-bouncing chainsaw blade (5s) that instant-kills on hit."
			}
		],
		"ultimate": {
			"name": "Self Blast",
			"kind": "ult_self_blast",
			"damage": 100,
			"color": Color(1.0, 0.28, 0.12),
			"desc": "Unleash a massive blast around yourself that kills nearby enemies."
		}
	},
	# 3: Soulless // Evil Being
	{
		"id": 3,
		"agent_name": "Soulless",
		"title": "Evil Being",
		"role": "Evil Being",
		"accent": Color(0.68, 0.94, 1.0),
		"base_weapon": {
			"name": "Spectral Touch",
			"style": "sword",
			"damage": 22,
			"cooldown": 0.33,
			"range": 104.0,
			"color": Color(0.75, 0.96, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Spectral Push Circle",
				"kind": "push_circle",
				"damage": 20,
				"stun": 1.0,
				"color": Color(0.65, 0.95, 1.0),
				"desc": "Expand a huge circle that pushes enemies back and stuns 1s."
			},
			{
				"name": "Ability-Lock Smoke",
				"kind": "ability_lock_smoke",
				"damage": 10,
				"duration": 4.0,
				"color": Color(0.92, 0.96, 1.0),
				"desc": "Throw white smoke that locks hit enemies' ability buttons for 4s."
			},
			{
				"name": "Ghost Clones",
				"kind": "ghost_clones",
				"damage": 50,
				"duration": 4.0,
				"color": Color(0.78, 0.96, 1.0),
				"desc": "Create 2 decoy clones for 4s that explode for 50% damage on hit."
			}
		],
		"ultimate": {
			"name": "Phantom Stealth",
			"kind": "ult_ghost_stealth",
			"damage": 0,
			"duration": 7.0,
			"color": Color(0.55, 0.95, 1.0),
			"desc": "Turn invisible & invincible for 7s while still able to attack."
		}
	},
	# 4: White Frost // Spec-Ops
	{
		"id": 4,
		"agent_name": "White Frost",
		"title": "Spec-Ops",
		"role": "Tactical Breacher",
		"accent": Color(0.45, 0.85, 1.0),
		"base_weapon": {
			"name": "Frost Crystal Blade",
			"style": "rook_frost_blade",
			"damage": 23,
			"cooldown": 0.33,
			"range": 100.0,
			"color": Color(0.52, 0.88, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Freeze Shot",
				"kind": "freeze_shot",
				"damage": 20,
				"duration": 2.0,
				"color": Color(0.48, 0.92, 1.0),
				"desc": "Fire an ice shot that freezes the enemy solid for 2s."
			},
			{
				"name": "Slippery Iceball",
				"kind": "ice_platform",
				"damage": 15,
				"duration": 5.0,
				"color": Color(0.68, 0.95, 1.0),
				"desc": "Throw an iceball that turns the hit platform slippery for 5s."
			},
			{
				"name": "Frost Gas Cloud",
				"kind": "frost_gas",
				"damage": 20,
				"duration": 5.0,
				"color": Color(0.82, 0.96, 1.0),
				"desc": "Spawn white frost smoke that deals 20% damage/sec."
			}
		],
		"ultimate": {
			"name": "Cryo Shatter",
			"kind": "ult_cryo_shatter",
			"damage": 100,
			"duration": 3.0,
			"color": Color(0.40, 0.88, 1.0),
			"desc": "Automatically freeze and shatter enemies in close range."
		}
	},
	# 5: Warlord // Viking Berserker
	{
		"id": 6,
		"agent_name": "Warlord",
		"title": "Viking Berserker",
		"role": "Northern Raider",
		"accent": Color(0.95, 0.54, 0.18),
		"base_weapon": {
			"name": "Nordic Great-Axe",
			"style": "axe",
			"damage": 26,
			"cooldown": 0.36,
			"range": 110.0,
			"color": Color(0.88, 0.92, 0.98),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Boar Charge",
				"kind": "boar_ride",
				"damage": 30,
				"duration": 4.0,
				"color": Color(0.92, 0.58, 0.22),
				"desc": "Ride a war boar; deal 30% damage and launch foes on contact."
			},
			{
				"name": "Boomerang Axe",
				"kind": "boomerang_axe",
				"damage": 50,
				"color": Color(0.85, 0.92, 1.0),
				"desc": "Spawn a distant axe that flies back to you, dealing 50% damage."
			},
			{
				"name": "Barbarian Squad",
				"kind": "barbarian_squad",
				"damage": 25,
				"shots": 3,
				"duration": 6.0,
				"color": Color(0.95, 0.45, 0.18),
				"desc": "Spawn 3 physics barbarians that march forward and attack enemies."
			}
		],
		"ultimate": {
			"name": "Earthquake Sphere",
			"kind": "ult_earth_quake_zone",
			"damage": 170,
			"duration": 5.0,
			"color": Color(0.78, 0.52, 0.24),
			"desc": "Blast an earth sphere that shakes enemy screens for 5s and kills in 0.6s inside."
		}
	},
	# 7: Draken // Vampire
	{
		"id": 7,
		"agent_name": "Draken",
		"title": "Vampire",
		"role": "Vampire Lord",
		"accent": Color(0.92, 0.18, 0.32),
		"base_weapon": {
			"name": "Crimson Fangs",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.33,
			"range": 106.0,
			"color": Color(0.95, 0.22, 0.35),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Vampire Bats",
				"kind": "bat_swarm",
				"damage": 25,
				"shots": 3,
				"color": Color(0.72, 0.14, 0.32),
				"desc": "Spawn 3 vampire bats that follow nearby enemies."
			},
			{
				"name": "Blood Armor",
				"kind": "damage_shield_50",
				"damage": 0,
				"duration": 5.0,
				"color": Color(0.88, 0.16, 0.28),
				"desc": "Take 50% less damage for 5 seconds."
			},
			{
				"name": "Blood Lance",
				"kind": "blood_beam",
				"damage": 80,
				"color": Color(0.98, 0.14, 0.22),
				"desc": "Launch a straight blood bolt forward for 80% damage."
			}
		],
		"ultimate": {
			"name": "Bat Execution",
			"kind": "ult_bat_execute",
			"damage": 100,
			"color": Color(0.95, 0.10, 0.24),
			"desc": "Transform into a bat, strike the enemy in front for instant death, and revert."
		}
	},
	# 8: Yagami // Shadow Ninja
	{
		"id": 8,
		"agent_name": "Yagami",
		"title": "Shadow Ninja",
		"role": "Shadow Assassin",
		"accent": Color(0.76, 0.44, 1.0),
		"base_weapon": {
			"name": "Muramasa Katana",
			"style": "yagami_katana",
			"damage": 23,
			"cooldown": 0.30,
			"range": 108.0,
			"color": Color(0.82, 0.56, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Triple Knives",
				"kind": "shuriken_fan",
				"shots": 3,
				"damage": 20,
				"color": Color(0.84, 0.72, 1.0),
				"desc": "Throw 3 ninja knives (20 damage per knife)."
			},
			{
				"name": "Flying Kick",
				"kind": "jump_kick",
				"damage": 50,
				"color": Color(0.72, 0.36, 1.0),
				"desc": "Leap to a nearby enemy and deliver a 50% damage flying kick."
			},
			{
				"name": "Spinning Blade",
				"kind": "spinning_blade",
				"damage": 50,
				"duration": 4.0,
				"color": Color(0.68, 0.44, 0.98),
				"desc": "Throw a huge slow spinning blade (50% damage) that vanishes after 4s."
			}
		],
		"ultimate": {
			"name": "Shadow Execution",
			"kind": "ult_jump_execute",
			"damage": 100,
			"color": Color(0.88, 0.34, 1.0),
			"desc": "Leap to a nearby enemy and execute them instantly."
		}
	},
	# 9: Dead Buddy // Brain Zombie
	{
		"id": 9,
		"agent_name": "Dead Buddy",
		"title": "Brain Zombie",
		"role": "Undead Brawler",
		"accent": Color(0.46, 0.92, 0.28),
		"base_weapon": {
			"name": "Infected Mutant Claws",
			"style": "axe",
			"damage": 25,
			"cooldown": 0.35,
			"range": 100.0,
			"color": Color(0.55, 0.96, 0.35),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Poison Vomit",
				"kind": "poison_vomit",
				"damage": 30,
				"duration": 4.0,
				"color": Color(0.45, 0.95, 0.28),
				"desc": "Hurl toxic vomit that poisons hit enemies."
			},
			{
				"name": "Slow-Mo Jelly Ball",
				"kind": "jelly_slowmo",
				"damage": 15,
				"duration": 4.0,
				"color": Color(0.95, 0.45, 0.78),
				"desc": "Throw a jelly ball that slows hit enemies in its radius for 4s."
			},
			{
				"name": "Zombie Dog",
				"kind": "zombie_dog",
				"damage": 80,
				"duration": 5.0,
				"color": Color(0.58, 0.88, 0.32),
				"desc": "Spawn a physics zombie dog for 5s that runs forward and deals 80% damage on hit."
			}
		],
		"ultimate": {
			"name": "Undying Rage",
			"kind": "ult_deathless_2x",
			"damage": 0,
			"duration": 10.0,
			"color": Color(0.55, 1.0, 0.24),
			"desc": "Become deathless for 10s with 2x base attack damage."
		}
	},
	# 10: Nothing // Skull Skeleton
	{
		"id": 10,
		"agent_name": "Nothing",
		"title": "Skull Skeleton",
		"role": "Skull Skeleton",
		"accent": Color(0.88, 0.90, 0.96),
		"base_weapon": {
			"name": "Cursed Bone Scimitar",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.34,
			"range": 104.0,
			"color": Color(0.92, 0.92, 0.98),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Boomerang Sword",
				"kind": "boomerang_sword",
				"damage": 45,
				"color": Color(0.92, 0.94, 1.0),
				"desc": "Throw a cursed sword forward that boomerangs back to you."
			},
			{
				"name": "Bomb Eagle",
				"kind": "bomb_eagle",
				"damage": 65,
				"duration": 5.0,
				"color": Color(0.95, 0.78, 0.35),
				"desc": "Spawn a bomb eagle (5s) that finds nearby enemies and drops a bomb."
			},
			{
				"name": "Fiery Hand Burn",
				"kind": "fiery_hand_beam",
				"damage": 80,
				"duration": 2.8,
				"color": Color(1.0, 0.45, 0.14),
				"desc": "Spawn a fiery hand that moves slowly toward your forward aim for 80% health damage on hit."
			}
		],
		"ultimate": {
			"name": "Time Freeze",
			"kind": "ult_time_slow",
			"damage": 0,
			"duration": 5.0,
			"color": Color(0.28, 0.72, 1.0),
			"desc": "Emit an expanding blue time wave that stops time for all nearby enemies for 5s, freezing them even in mid-air."
		}
	},
	# 11: Wraith // Undead
	{
		"id": 11,
		"agent_name": "Wraith",
		"title": "Undead",
		"role": "Spectral Phantom",
		"accent": Color(0.64, 0.94, 1.0),
		"base_weapon": {
			"name": "Reaper Soul Scythe",
			"style": "scythe",
			"damage": 24,
			"cooldown": 0.34,
			"range": 114.0,
			"color": Color(0.14, 0.94, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Spectral Invincibility",
				"kind": "invincible_self",
				"damage": 0,
				"duration": 3.0,
				"color": Color(0.68, 0.96, 1.0),
				"desc": "Become invincible for 3 seconds."
			},
			{
				"name": "Touch Teleport",
				"kind": "touch_teleport",
				"damage": 0,
				"duration": 3.0,
				"color": Color(0.32, 0.82, 1.0),
				"desc": "Activate for 3s: tap anywhere on screen to spawn a blue circle and instantly teleport there."
			},
			{
				"name": "Banshee Scream",
				"kind": "scream_wave",
				"damage": 40,
				"stun": 2.0,
				"color": Color(0.24, 0.94, 1.0),
				"desc": "Emit a forward wavy scream that deals 40% damage, shakes enemies, and stuns them for 2s."
			}
		],
		"ultimate": {
			"name": "Soul Harvest",
			"kind": "ult_soul_drag",
			"damage": 100,
			"color": Color(0.45, 0.95, 1.0),
			"desc": "Drag a nearby enemy close and rip their soul for instant death."
		}
	},
	# 12: Pharaoh // Ancient Mummy
	{
		"id": 12,
		"agent_name": "Pharaoh",
		"title": "Ancient Mummy",
		"role": "Tomb Guardian",
		"accent": Color(0.95, 0.78, 0.32),
		"base_weapon": {
			"name": "Pharaoh Khopesh",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.34,
			"range": 104.0,
			"color": Color(1.0, 0.84, 0.38),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Headless Throw",
				"kind": "headless_throw",
				"damage": 50,
				"color": Color(0.98, 0.82, 0.36),
				"desc": "Throw your own head forward along aim; it boomerangs back."
			},
			{
				"name": "Shadow Mummy",
				"kind": "shadow_mummy",
				"damage": 30,
				"duration": 5.0,
				"color": Color(0.85, 0.65, 0.25),
				"desc": "Spawn an unkillable mummy behind a nearby enemy (30% dmg/hit, 5s)."
			},
			{
				"name": "Relic Magnet",
				"kind": "throwable_magnet",
				"damage": 0,
				"duration": 5.0,
				"color": Color(1.0, 0.88, 0.42),
				"desc": "Magnetize and pull nearby throwables toward you for 5s."
			}
		],
		"ultimate": {
			"name": "Death Kiss",
			"kind": "ult_death_kiss",
			"damage": 100,
			"color": Color(0.95, 0.38, 0.82),
			"desc": "Throw a Death Kiss grenade that creates a huge circle and kills all inside."
		}
	},
	# 13: Jack-47 // Cyber Robot
	{
		"id": 13,
		"agent_name": "Jack-47",
		"title": "Cyber Robot",
		"role": "Heavy Automaton",
		"accent": Color(0.32, 0.84, 1.0),
		"base_weapon": {
			"name": "Plasma Riot Rifle",
			"style": "gun",
			"damage": 20,
			"cooldown": 0.28,
			"range": 380.0,
			"color": Color(0.42, 0.88, 1.0),
			"ranged": true
		},
		"abilities": [
			{
				"name": "Auto Machinegun",
				"kind": "auto_machinegun",
				"damage": 12,
				"duration": 5.0,
				"color": Color(0.35, 0.86, 1.0),
				"desc": "Fire an automatic machinegun for 5 seconds."
			},
			{
				"name": "Deploy Turret",
				"kind": "deploy_turret",
				"damage": 40,
				"duration": 10.0,
				"color": Color(0.48, 0.92, 1.0),
				"desc": "Deploy a destructible turret for 10s (40%/shot, 1 shot/sec)."
			},
			{
				"name": "Energy Shield",
				"kind": "equip_shield",
				"damage": 0,
				"wall_hp": 100,
				"duration": 6.0,
				"color": Color(0.35, 0.85, 1.0),
				"desc": "Equip a destructible personal energy shield."
			}
		],
		"ultimate": {
			"name": "Arm Fireball Barrage",
			"kind": "ult_arm_fireballs",
			"damage": 35,
			"shots": 5,
			"color": Color(1.0, 0.45, 0.20),
			"desc": "Launch 5 fireball shots from both robotic arms."
		}
	},
	# 14: Viper-X // Venom Snake
	{
		"id": 14,
		"agent_name": "Viper-X",
		"title": "Venom Snake",
		"role": "Venom Serpent",
		"accent": Color(0.28, 0.96, 0.42),
		"base_weapon": {
			"name": "Venom Injector Spear",
			"style": "spear",
			"damage": 23,
			"cooldown": 0.34,
			"range": 115.0,
			"color": Color(0.36, 0.98, 0.48),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Poison Shot",
				"kind": "poison_shot",
				"damage": 30,
				"duration": 4.0,
				"color": Color(0.32, 0.96, 0.42),
				"desc": "Fire a toxic venom shot that poisons the hit target."
			},
			{
				"name": "Poison Gas",
				"kind": "poison_gas",
				"damage": 15,
				"duration": 10.0,
				"color": Color(0.42, 0.94, 0.32),
				"desc": "Release a toxic gas cloud (10s) that poisons enemies inside."
			},
			{
				"name": "Triple Snakes",
				"kind": "snake_trio",
				"damage": 20,
				"shots": 3,
				"duration": 5.0,
				"color": Color(0.38, 0.95, 0.38),
				"desc": "Spawn 3 small physics snakes one-by-one (20 dmg each)."
			}
		],
		"ultimate": {
			"name": "Apex Viper",
			"kind": "ult_giant_snake",
			"damage": 100,
			"duration": 4.0,
			"color": Color(0.22, 1.0, 0.38),
			"desc": "Spawn a giant viper (4s) that chases enemies and kills in 1 hit."
		}
	},
	# 15: Nyx // Shadow Cat
	{
		"id": 15,
		"agent_name": "Nyx",
		"title": "Shadow Cat",
		"role": "Feline Striker",
		"accent": Color(0.98, 0.52, 0.88),
		"base_weapon": {
			"name": "Panther Twin Claws",
			"style": "sword",
			"damage": 22,
			"cooldown": 0.28,
			"range": 102.0,
			"color": Color(0.98, 0.62, 0.92),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Feline Haste",
				"kind": "speed",
				"damage": 0,
				"duration": 5.0,
				"speed_mult": 1.85,
				"color": Color(0.98, 0.56, 0.92),
				"desc": "Boost movement speed, double base attack speed (2x), and double Shadow Dash & Ult laser damage for 5 seconds."
			},
			{
				"name": "Eagle Zoomout",
				"kind": "zoom_out_4x",
				"damage": 0,
				"duration": 5.0,
				"color": Color(0.75, 0.68, 1.0),
				"desc": "Zoom camera out 4x for 5 seconds for full arena vision."
			},
			{
				"name": "Shadow Dash",
				"kind": "dash_speed",
				"damage": 50,
				"duration": 1.5,
				"speed_mult": 1.75,
				"color": Color(0.98, 0.48, 0.88),
				"desc": "Fast dash towards your current aim direction, dealing 50% damage on hit."
			}
		],
		"ultimate": {
			"name": "Electric Laser Gun",
			"kind": "ult_electric_laser",
			"damage": 29,
			"duration": 10.0,
			"color": Color(0.45, 0.92, 1.0),
			"desc": "Fire an electric laser gun for 10s (melts enemies in ~3.5s on touch)."
		}
	},
	# 16: Akuza // Dragon Hero
	{
		"id": 16,
		"agent_name": "Akuza",
		"title": "Dragon Hero",
		"role": "Blade Hero",
		"accent": Color(0.24, 0.94, 0.64),
		"base_weapon": {
			"name": "Dragon-Fang Saber",
			"style": "sword",
			"damage": 24,
			"cooldown": 0.32,
			"range": 108.0,
			"color": Color(0.35, 0.98, 0.68),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Stun Bomb",
				"kind": "stun_bomb",
				"damage": 25,
				"stun": 2.0,
				"color": Color(0.98, 0.85, 0.25),
				"desc": "Throw a stun bomb that stuns enemies in its blast circle."
			},
			{
				"name": "Twin Fireballs",
				"kind": "twin_fireballs",
				"damage": 40,
				"shots": 2,
				"color": Color(1.0, 0.48, 0.16),
				"desc": "Throw 2 slow fireballs in sequence (40% damage each)."
			},
			{
				"name": "Dragon Flame",
				"kind": "dragon_laser",
				"damage": 80,
				"duration": 4.0,
				"color": Color(1.0, 0.36, 0.12),
				"desc": "Activate for 4s: tap/click anywhere on screen to spawn roaring dragon fire that gradually burns enemies and ignites nearby barrels."
			}
		],
		"ultimate": {
			"name": "Dragon Strike",
			"kind": "ult_dragon_strike",
			"damage": 100,
			"color": Color(0.28, 1.0, 0.62),
			"desc": "Launch a Dragon straight along your aim direction that immediately blasts on any enemy in its path for an instant kill."
		}
	},
	# 17: Mirror Ogre // Fierce Orc
	{
		"id": 17,
		"agent_name": "Mirror Ogre",
		"title": "Fierce Orc",
		"role": "Ogre Warlord",
		"accent": Color(0.76, 0.42, 0.96),
		"base_weapon": {
			"name": "Orc Skull Crusher",
			"style": "orc_axe",
			"damage": 26,
			"cooldown": 0.36,
			"range": 108.0,
			"color": Color(0.84, 0.56, 1.0),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Banish Teleport",
				"kind": "banish_enemy",
				"damage": 10,
				"duration": 3.0,
				"color": Color(0.78, 0.45, 1.0),
				"desc": "Activate and tap any area to spawn a giant 3s portal circle that randomly teleports any enemies inside or entering it."
			},
			{
				"name": "Position Swap",
				"kind": "swap_enemy",
				"damage": 10,
				"color": Color(0.65, 0.85, 1.0),
				"desc": "Swap positions with the enemy fighting in front or behind you."
			},
			{
				"name": "Falling Forge",
				"kind": "slow_spin_axe",
				"damage": 100,
				"duration": 3.0,
				"color": Color(0.92, 0.68, 0.98),
				"desc": "Drop a heavy forge above the nearest enemy in front for an instant kill on impact."
			}
		],
		"ultimate": {
			"name": "Tornado Vortex",
			"kind": "ult_mirror_clone",
			"damage": 100,
			"duration": 6.0,
			"color": Color(0.75, 0.58, 1.0),
			"desc": "Launch a huge tornado forward that chases nearby enemies and kills caught foes in 1s."
		}
	},
	# 18: Ignis // Magma
	{
		"id": 18,
		"agent_name": "Ignis",
		"title": "Magma",
		"role": "Lava Colossus",
		"accent": Color(1.0, 0.42, 0.14),
		"base_weapon": {
			"name": "Volcanic Magma Hammer",
			"style": "magma_hammer",
			"damage": 26,
			"cooldown": 0.36,
			"range": 108.0,
			"color": Color(1.0, 0.44, 0.08),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Triple Fire Shot",
				"kind": "flame_wave",
				"shots": 3,
				"damage": 25,
				"color": Color(1.0, 0.46, 0.14),
				"desc": "Spawn 3 stationary fire blasts: in front, behind, and above you."
			},
			{
				"name": "Lava Platform",
				"kind": "lava_platform",
				"damage": 34,
				"duration": 6.0,
				"color": Color(1.0, 0.32, 0.08),
				"desc": "Throw a fireball that sets a platform on fire (33% damage/sec, kills in 3s)."
			},
			{
				"name": "Rolling Magma Boulder",
				"kind": "rolling_fireball",
				"damage": 55,
				"color": Color(1.0, 0.56, 0.16),
				"desc": "Spawn a huge physics fireball that bounces 5 times before vanishing."
			}
		],
		"ultimate": {
			"name": "Inferno Ring",
			"kind": "ult_inferno_ring",
			"damage": 100,
			"duration": 1.5,
			"color": Color(1.0, 0.28, 0.06),
			"desc": "Grab a nearby enemy close, lock them in a roaring fire, and burn them to death over 1.5s."
		}
	},
	# 19: Stone // Rocky Golem
	{
		"id": 19,
		"agent_name": "Stone",
		"title": "Rocky Golem",
		"role": "Quartz Elemental",
		"accent": Color(0.98, 0.44, 0.82),
		"base_weapon": {
			"name": "Boulder War Hammer",
			"style": "stone_hammer",
			"damage": 25,
			"cooldown": 0.35,
			"range": 106.0,
			"color": Color(0.68, 0.62, 0.54),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Meteor Boulder",
				"kind": "meteor_boulder",
				"damage": 60,
				"color": Color(0.96, 0.52, 0.84),
				"desc": "Throw a giant boulder that bounces continuously for 5s without breaking on hit."
			},
			{
				"name": "Piercing Crystal Shot",
				"kind": "piercing_crystal",
				"damage": 40,
				"color": Color(0.98, 0.65, 0.92),
				"desc": "Fire a slow crystal shot that pierces players until hitting a wall."
			},
			{
				"name": "Prism Mirror",
				"kind": "prism_mirror",
				"damage": 0,
				"duration": 5.0,
				"color": Color(1.0, 0.58, 0.92),
				"desc": "Cast a crystal mirror in front of Prism for 5s that deflects incoming enemy projectiles to random angles."
			}
		],
		"ultimate": {
			"name": "Crystal Crush Walls",
			"kind": "ult_crush_walls",
			"damage": 100,
			"color": Color(1.0, 0.36, 0.80),
			"desc": "Spawn 2 giant crystal walls forward that smash enemies between them."
		}
	},
	# 20: Afera // Tribal Monk
	{
		"id": 20,
		"agent_name": "Afera",
		"title": "Tribal Monk",
		"role": "Martial Master",
		"accent": Color(1.0, 0.66, 0.24),
		"base_weapon": {
			"name": "Tribal Spear",
			"style": "afera_spear",
			"damage": 24,
			"cooldown": 0.32,
			"range": 116.0,
			"color": Color(1.0, 0.74, 0.34),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Twin Spears",
				"kind": "spear_throw",
				"shots": 2,
				"damage": 30,
				"color": Color(1.0, 0.72, 0.28),
				"desc": "Throw 2 tribal spears along your aim direction."
			},
			{
				"name": "Long Spear Thrust",
				"kind": "long_spear",
				"damage": 45,
				"color": Color(1.0, 0.62, 0.22),
				"desc": "Strike enemies at extended range with a long spear."
			},
			{
				"name": "Bee Swarm",
				"kind": "bee_swarm",
				"damage": 15,
				"shots": 5,
				"duration": 7.0,
				"color": Color(1.0, 0.86, 0.20),
				"desc": "Throw a hive that spawns 5 roaming bees for 7s."
			}
		],
		"ultimate": {
			"name": "Spear Impale",
			"kind": "ult_spear_jump",
			"damage": 100,
			"color": Color(1.0, 0.52, 0.14),
			"desc": "Jump forward and stab a nearby enemy for instant death."
		}
	},
	# 21: Raven // Shadow Corvus
	{
		"id": 21,
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
				"name": "Shadow Raven",
				"kind": "raven_swarm",
				"cooldown": 6.5,
				"damage": 70,
				"shots": 1,
				"color": Color(0.28, 0.16, 0.45),
				"desc": "Launch a single homing raven that tracks and strikes an enemy for 70% damage."
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
			"damage": 100,
			"duration": 1.0,
			"color": Color(0.62, 0.24, 0.95),
			"desc": "Teleport behind the nearest enemy in your aim direction and backstab for instant death."
		}
	},
	# 22: Ray Lina // Young Elf
	{
		"id": 22,
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
	},
	# 23: Jackson // Heavyweight Boxer
	{
		"id": 23,
		"agent_name": "Jackson",
		"title": "Heavyweight Boxer",
		"role": "Heavyweight Boxer",
		"accent": Color(0.20, 0.48, 0.92),
		"base_weapon": {
			"name": "Championship Boxing Gloves",
			"style": "boxing_glove",
			"damage": 25,
			"cooldown": 0.30,
			"range": 102.0,
			"color": Color(0.19, 0.46, 0.88),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Huge Boxy Punch",
				"kind": "boxer_huge_punch",
				"damage": 50,
				"stun": 0.8,
				"color": Color(0.22, 0.52, 0.96),
				"desc": "Unleash a huge boxing punch that knocks enemies back and stuns."
			},
			{
				"name": "Running Punch",
				"kind": "running_spear",
				"damage": 45,
				"color": Color(0.98, 0.62, 0.18),
				"desc": "Charge forward like a running punch along your aim direction."
			},
			{
				"name": "Sky Smash Punch",
				"kind": "sky_smash_punch",
				"damage": 60,
				"stun": 1.0,
				"color": Color(0.22, 0.52, 0.96),
				"desc": "Drop a giant fist from above onto a nearby enemy and smash them."
			}
		],
		"ultimate": {
			"name": "Knockout Flurry",
			"kind": "ult_boxer_flurry",
			"damage": 100,
			"color": Color(1.0, 0.18, 0.18),
			"desc": "Rush to a nearby enemy and beat them down with rapid punches till death."
		}
	},
	# 24: Grimhare // Cursed Hare
	{
		"id": 24,
		"agent_name": "Grimhare",
		"title": "Cursed Hare",
		"role": "Brawler Hare",
		"accent": Color(0.88, 0.20, 0.28),
		"base_weapon": {
			"name": "Bramble Fists",
			"style": "grimhare_hand",
			"damage": 24,
			"cooldown": 0.28,
			"range": 102.0,
			"color": Color(0.88, 0.20, 0.28),
			"ranged": false
		},
		"abilities": [
			{
				"name": "Fury Dash",
				"kind": "dash_speed",
				"damage": 32,
				"duration": 3.0,
				"speed_mult": 1.75,
				"color": Color(0.92, 0.24, 0.30),
				"desc": "Surge forward with boosted speed and fierce crimson strikes."
			},
			{
				"name": "Hare Uppercut",
				"kind": "boxer_huge_punch",
				"damage": 48,
				"stun": 0.7,
				"color": Color(0.95, 0.28, 0.32),
				"desc": "Deliver a heavy crimson uppercut that stuns and knocks enemies back."
			},
			{
				"name": "Sky Drop",
				"kind": "sky_smash_punch",
				"damage": 55,
				"stun": 0.9,
				"color": Color(0.85, 0.18, 0.28),
				"desc": "Smash down from above onto a nearby enemy."
			}
		],
		"ultimate": {
			"name": "Crimson Barrage",
			"kind": "ult_boxer_flurry",
			"damage": 100,
			"color": Color(0.96, 0.20, 0.26),
			"desc": "Rush a nearby forward enemy and unleash a rapid crimson punch barrage."
		}
	}
]
static func is_ray_lina(arch_id: int) -> bool:
	return str(get_agent(arch_id).get("agent_name", "")) == "Ray Lina"


static func is_ultimate_weapon_name(w_name: String) -> bool:
	if w_name.is_empty():
		return false
	for ag in AGENTS:
		var ult: Dictionary = ag.get("ultimate", {})
		if str(ult.get("name", "")) == w_name:
			return true
	return false


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

const ABILITY_ICONS_PATH: String = "res://assets/ui/ability_icons_sheet.png"
const ABILITY_ICON_INDEX: Dictionary = {
	"ability_lock_smoke": 0,
	"auto_machinegun": 1,
	"banish_enemy": 2,
	"barbarian_squad": 3,
	"bat_swarm": 4,
	"bee_swarm": 5,
	"blood_beam": 6,
	"boar_ride": 7,
	"bomb_eagle": 8,
	"boomerang_axe": 9,
	"boomerang_sword": 10,
	"bouncing_chainsaw": 11,
	"boxer_huge_punch": 12,
	"damage_shield_50": 13,
	"dash_speed": 14,
	"deploy_turret": 15,
	"dragon_laser": 16,
	"dual_shotguns": 17,
	"equip_shield": 18,
	"fiery_hand_beam": 19,
	"fireball": 20,
	"flame_wave": 21,
	"flash_bird": 22,
	"freeze_shot": 23,
	"frost_gas": 24,
	"ghost_clones": 25,
	"gradual_heal": 26,
	"gun_burst": 27,
	"headless_throw": 28,
	"hook_drag": 29,
	"ice_platform": 30,
	"ice_shards": 31,
	"impact_grenade": 32,
	"invincible_self": 33,
	"jelly_slowmo": 34,
	"jump_kick": 35,
	"lava_platform": 36,
	"long_spear": 37,
	"meteor_boulder": 38,
	"piercing_crystal": 39,
	"poison_gas": 40,
	"poison_shot": 41,
	"poison_vomit": 42,
	"prism_mirror": 43,
	"push_circle": 44,
	"raven_swarm": 45,
	"reverse_smoke": 46,
	"rolling_fireball": 47,
	"running_spear": 48,
	"scream_wave": 49,
	"shadow_mummy": 50,
	"shuriken_fan": 51,
	"sky_smash_punch": 52,
	"slow_spin_axe": 53,
	"snake_trio": 54,
	"spear_throw": 55,
	"speed": 56,
	"spinning_blade": 57,
	"sticky_bomb": 58,
	"stun_bomb": 59,
	"swap_enemy": 60,
	"telekinesis": 61,
	"teleport": 62,
	"throwable_magnet": 63,
	"touch_teleport": 64,
	"twin_fireballs": 65,
	"ult_arm_fireballs": 66,
	"ult_backstab_tp": 67,
	"ult_bat_execute": 68,
	"ult_blink_slash": 69,
	"ult_boxer_flurry": 70,
	"ult_crush_walls": 71,
	"ult_cryo_shatter": 72,
	"ult_death_kiss": 73,
	"ult_deathless_2x": 74,
	"ult_dragon_strike": 75,
	"ult_earth_quake_zone": 76,
	"ult_electric_laser": 77,
	"ult_ghost_stealth": 78,
	"ult_giant_snake": 79,
	"ult_homing_bazooka": 80,
	"ult_inferno_ring": 81,
	"ult_jump_execute": 82,
	"ult_mirror_clone": 83,
	"ult_self_blast": 84,
	"ult_soul_drag": 85,
	"ult_spear_jump": 86,
	"ult_time_slow": 87,
	"ult_winged_lion": 88,
	"wall": 89,
	"zombie_dog": 90,
	"zoom_out_4x": 91
}

static var _target_icon_tex: Texture2D = null
static var _hook_icon_tex: Texture2D = null


static func _draw_icon_seg(img: Image, p0: Vector2, p1: Vector2, rad: float, col: Color) -> void:
	var seg_len: float = p0.distance_to(p1)
	var steps: int = maxi(1, int(ceilf(seg_len * 2.0)))
	var r_ceil: int = int(ceilf(rad))
	for s in range(steps + 1):
		var pt: Vector2 = p0.lerp(p1, float(s) / float(steps))
		var cx: int = int(roundf(pt.x))
		var cy: int = int(roundf(pt.y))
		for dy in range(-r_ceil, r_ceil + 1):
			for dx in range(-r_ceil, r_ceil + 1):
				var px: int = cx + dx
				var py: int = cy + dy
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					if Vector2(float(dx), float(dy)).length() <= rad:
						img.set_pixel(px, py, col)


static func _get_hook_icon_texture() -> Texture2D:
	if _hook_icon_tex != null:
		return _hook_icon_tex
	var sz: int = 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var rope_col := Color(1.0, 1.0, 1.0, 1.0)
	var steel_col := Color(1.0, 1.0, 1.0, 1.0)
	var tip_col := Color(1.0, 1.0, 1.0, 1.0)
	# Diagonal rope from bottom-left to hook ring
	_draw_icon_seg(img, Vector2(10.0, 54.0), Vector2(26.0, 38.0), 2.4, rope_col)
	# Hook ring/eyelet
	for a_i in range(32):
		var ang: float = (float(a_i) / 32.0) * TAU
		var pt := Vector2(27.0, 37.0) + Vector2.from_angle(ang) * 5.0
		_draw_icon_seg(img, pt, pt, 1.8, steel_col)
	# Hook shank going up-right
	_draw_icon_seg(img, Vector2(31.0, 33.0), Vector2(44.0, 20.0), 3.0, steel_col)
	# Left & right grapple claws curving back with barbs
	_draw_icon_seg(img, Vector2(44.0, 20.0), Vector2(51.0, 13.0), 3.0, tip_col)
	_draw_icon_seg(img, Vector2(44.0, 20.0), Vector2(48.0, 35.0), 2.8, steel_col)
	_draw_icon_seg(img, Vector2(48.0, 35.0), Vector2(42.0, 42.0), 2.5, tip_col)
	_draw_icon_seg(img, Vector2(44.0, 20.0), Vector2(29.0, 16.0), 2.8, steel_col)
	_draw_icon_seg(img, Vector2(29.0, 16.0), Vector2(22.0, 22.0), 2.5, tip_col)
	_hook_icon_tex = ImageTexture.create_from_image(img)
	return _hook_icon_tex


static func _get_target_icon_texture() -> Texture2D:
	if _target_icon_tex != null:
		return _target_icon_tex
	var sz: int = 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center := Vector2(31.5, 31.5)
	var red_outer := Color(1.0, 1.0, 1.0, 1.0)
	var gold_inner := Color(1.0, 1.0, 1.0, 1.0)
	var white_tick := Color(1.0, 1.0, 1.0, 1.0)
	for y in range(sz):
		for x in range(sz):
			var d: float = Vector2(float(x), float(y)).distance_to(center)
			var dx: float = absf(float(x) - center.x)
			var dy: float = absf(float(y) - center.y)
			if d >= 20.5 and d <= 25.0:
				img.set_pixel(x, y, red_outer)
			elif d >= 11.0 and d <= 14.5:
				img.set_pixel(x, y, gold_inner)
			elif d <= 4.5:
				img.set_pixel(x, y, red_outer)
			elif ((dx <= 2.2 and dy >= 15.0 and dy <= 29.0) or (dy <= 2.2 and dx >= 15.0 and dx <= 29.0)):
				img.set_pixel(x, y, white_tick)
	_target_icon_tex = ImageTexture.create_from_image(img)
	return _target_icon_tex


static func get_ability_icon_texture(kind: String) -> Texture2D:
	if kind == "frost_gas" and ResourceLoader.exists("res://assets/ui/frost_snowflake_icon.png"):
		return load("res://assets/ui/frost_snowflake_icon.png") as Texture2D
	if kind == "running_spear" and ResourceLoader.exists("res://assets/ui/running_punch_icon.png"):
		return load("res://assets/ui/running_punch_icon.png") as Texture2D
	if kind == "ult_homing_bazooka":
		return _get_target_icon_texture()
	if kind == "hook_drag":
		return _get_hook_icon_texture()
	if not ResourceLoader.exists(ABILITY_ICONS_PATH):
		return null
	var sheet := load(ABILITY_ICONS_PATH) as Texture2D
	if sheet == null:
		return null
	var idx: int = int(ABILITY_ICON_INDEX.get(kind, 0))
	var col: int = idx % 10
	var row: int = idx / 10
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(col * 64, row * 64, 64, 64)
	return at
