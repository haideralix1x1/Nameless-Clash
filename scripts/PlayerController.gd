extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal fuel_changed(current: float, maximum: float)
signal ammo_changed(current: int, mag_size: int, is_reloading: bool)
signal weapon_changed(weapon_data: WeaponData)
signal died_signal(respawn_seconds: float)
signal respawned_signal
signal bombs_changed(count: int, bomb_type: String)
signal zoom_changed(zoom_level: int, max_zoom: int)
signal agent_state_changed(cooldowns: Array, max_cooldowns: Array, held_throwable: int, stun_left: float)
signal nearby_weapon_changed(crate_idx: int, weapon_id: int)
signal nearby_interactable_changed(inter_idx: int, label_text: String)
signal held_prop_changed(prop_kind: String)
signal agent_abilities_changed

const BULLET_SCENE: PackedScene = preload("res://scenes/Bullet.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://scenes/Explosion.tscn")
const BOMB_SCRIPT: Script = preload("res://scripts/Bomb.gd")
const TEX_SOUL_GHOST: Texture2D = preload("res://assets/sprites/soul_ghost.png")
const ZOOM_LEVEL_VALUES: Array[float] = [1.30, 1.12, 0.98, 0.86, 0.76, 0.68, 0.60]

const MOVE_SPEED: float = 310.0
const CROUCH_SPEED: float = 165.0
const GROUND_ACCEL: float = 2100.0
const AIR_ACCEL: float = 1250.0
const FRICTION: float = 1900.0
const GRAVITY: float = 1080.0
const JUMP_VELOCITY: float = -465.0
const WALL_SLIDE_SPEED: float = 135.0
const WALL_JUMP_X: float = 320.0
const JETPACK_THRUST: float = 1850.0
const JETPACK_MAX_UP_SPEED: float = -430.0
const MAX_FUEL: float = 100.0
const FUEL_CONSUME_RATE: float = 18.0
const FUEL_RECHARGE_GROUND: float = 55.0
const FUEL_RECHARGE_AIR: float = 20.0
const RESPAWN_TIME: float = 3.0
const MAX_SCREEN_SHAKE: float = 3.2

@export var peer_id: int = 1
@export var player_name: String = "Trooper"
@export var color_index: int = 0
@export var team_id: int = 0
@export var is_bot: bool = false
var is_preview_dummy: bool = false
var preview_move_x: float = 0.0
var preview_jump: bool = false
@export var is_local_human: bool = false

# Modular Avatar Appearance
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

# Synchronized state properties
@export var aim_angle: float = 0.0
@export var facing_right: bool = true
@export var is_jetpacking: bool = false
@export var is_crouching: bool = false
@export var health: int = 100
@export var jetpack_fuel: float = 100.0
@export var current_weapon_id: int = 0
@export var primary_weapon_id: int = 0
@export var secondary_weapon_id: int = 9
@export var weapon_skin_id: int = 0
@export var m4a1_rail_mod: int = 0
@export var is_dead: bool = false
@export var anim_frame: int = 0

var max_health: int = 100
var current_ammo: int = 30
const SPAWN_INVULN_SEC: float = 3.0
var is_reloading: bool = false
var spawn_invuln_timer: float = SPAWN_INVULN_SEC
var _equipped_primary_id: int = 0
var nearby_weapon_crate: int = -1
var nearby_weapon_id: int = -1
var nearby_interactable_idx: int = -1
var held_prop_kind: String = ""
var custom_ability_slots: Array[Dictionary] = []
var reverse_controls_timer: float = 0.0

# Virtual joystick overrides fed from HUD
var virtual_move: Vector2 = Vector2.ZERO
var virtual_jetpack: bool = false
var virtual_aim: Vector2 = Vector2.ZERO
var virtual_fire: bool = false
var pointer_over_ui: bool = false

var _weapon: WeaponData = WeaponData.get_weapon(0, 0, 0)
var _fire_cooldown: float = 0.0
var _reload_timer: float = 0.0
var _damage_by_attacker: Dictionary = {}
var _primary_reserve_ammo: int = -1
var _secondary_reserve_ammo: int = -1
var _primary_saved_ammo: int = -1
var _secondary_saved_ammo: int = -1
var _original_secondary_id: int = 9
var _active_slot: int = 0
var _fuel_recharge_delay: float = 0.0
var _respawn_timer: float = 0.0
var _anim_timer: float = 0.0
var _flash_timer: float = 0.0
var _fire_anim_timer: float = 0.0
var _hit_flash_timer: float = 0.0
var _shake_amount: float = 0.0
var _bot_think_timer: float = 0.0
var _bot_strafe_dir: float = 1.0
var _bot_want_jetpack: bool = false
var _bot_allow_fire: bool = true
var _bot_aim_error: float = 0.0
var _bot_weapon_pickup_cd: float = 0.0
var _bot_loot_focus_timer: float = 0.0
var _bot_loot_origin: Vector2 = Vector2.ZERO
var _spawn_points: Array[Vector2] = []
var _net_sync_accum: float = 0.0
var _ability_recharge_timer: float = 0.0

const GRAB_PLAYER_RANGE: float = 92.0
const THROW_PLAYER_SPEED: float = 980.0
const THROWN_SELF_DAMAGE: int = 70
const THROWN_TARGET_DAMAGE: int = 30
const THROWN_WALL_DAMAGE: int = 70
const DEFAULT_SHOE_ITEM_ID: int = 5
const SHOE_COOLDOWN_SEC: float = 5.0
const SHOE_WINDUP_SEC: float = 1.0

# Agent Clash Mode state
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0, 1.0]
var ability_max_cooldowns: Array[float] = [6.0, 8.0, 8.5, 22.0]
var ability_kill_progress: int = 0
var _next_unlock_slot: int = 0
var ult_points: int = 0
var held_throwable_id: int = -1
var held_throwables: Array[int] = []
var shoe_cooldown_timer: float = 0.0
var _shoe_windup_timer: float = 0.0
var grabbed_player_id: int = 0
var carried_by_peer_id: int = 0
var _grab_hold_timer: float = 0.0
var _grab_cooldown: float = 0.0
var thrown_by_peer_id: int = 0
var thrown_by_name: String = ""
var thrown_by_team: int = -1
var thrown_by_rook_frost: bool = false
var thrown_flight_timer: float = 0.0
var _thrown_flight_elapsed: float = 0.0
var stun_timer: float = 0.0
var invis_timer: float = 0.0
var speed_boost_timer: float = 0.0
var speed_boost_mult: float = 1.0
var nyx_frenzy_timer: float = 0.0
var control_lock_timer: float = 0.0
var gravity_lock_timer: float = 0.0
var freeze_timer: float = 0.0
var ability_lock_timer: float = 0.0
var flashbang_timer: float = 0.0
var invincible_timer: float = 0.0
var damage_reduction_timer: float = 0.0
var slow_mo_timer: float = 0.0
var time_stop_timer: float = 0.0
var touch_teleport_timer: float = 0.0
var touch_fire_timer: float = 0.0
var touch_banish_timer: float = 0.0
var banish_after_fx_timer: float = 0.0
var _banish_fx_accum: float = 0.0
var bubble_trap_timer: float = 0.0
var bubble_trap_hp: int = 0
var bubble_trap_lock_timer: float = 0.0
var deathless_timer: float = 0.0
var zoom_out_timer: float = 0.0
var gradual_heal_timer: float = 0.0
var _gradual_heal_accum: float = 0.0
var boar_ride_timer: float = 0.0
var _boar_hit_cooldowns: Dictionary = {}
var _boar_sprite: Sprite2D = null
var _ice_overlay: Node2D = null
var _deathless_overlay: Node2D = null
var _invincible_overlay: Node2D = null
var _bat_ult_timer: float = 0.0
var _bat_ult_target: Node2D = null
var _bat_ult_hit_done: bool = false
var _bat_ult_sprite: Sprite2D = null
var _contra_ult_shots_left: int = 0
var _contra_ult_shot_timer: float = 0.0
var _contra_ult_dmg: int = 0
var _contra_ult_col: Color = Color(1.0, 0.35, 0.20)
var _contra_ult_name: String = "Target-Follow Bazooka"
var _contra_ult_local: bool = false
var _magnet_timer: float = 0.0
var _magnet_anchor: Vector2 = Vector2.ZERO
var _fly_kick_timer: float = 0.0
var _fly_kick_dir: Vector2 = Vector2.RIGHT
var _fly_kick_target: Node2D = null
var _fly_kick_hit_ids: Array[int] = []
var _spear_timer: float = 0.0
var _spear_dir: Vector2 = Vector2.RIGHT
var _spear_dmg: int = 45
var _spear_label: String = "Running Punch"
var _spear_hit_ids: Array[int] = []
var _shadow_dash_timer: float = 0.0
var _shadow_dash_dir: Vector2 = Vector2.RIGHT
var _shadow_dash_dmg: int = 25
var _shadow_dash_hit_ids: Array[int] = []
var _yagami_ult_timer: float = 0.0
var _yagami_ult_start: Vector2 = Vector2.ZERO
var _yagami_ult_end: Vector2 = Vector2.ZERO
var _yagami_ult_target: Node2D = null
var _yagami_ult_slashed: bool = false
var _yagami_ult_slash_timer: float = 0.0
var _flurry_state: int = 0
var _flurry_timer: float = 0.0
var _flurry_hit_accum: float = 0.0
var _flurry_smoke_accum: float = 0.0
var _flurry_target: Node2D = null
var _flurry_dmg: int = 200
var _flurry_name: String = "Knockout Flurry"
var _flurry_auth: bool = false
var headless_timer: float = 0.0
var _headless_proj: Node = null
const TEX_VAMPIRE_BAT: Texture2D = preload("res://assets/sprites/summons/bat.png")
const TEX_WAR_BOAR: Texture2D = preload("res://assets/sprites/summons/boar.png")
var dual_shotgun_timer: float = 0.0
var dual_shotgun_shots: int = 0
var _dual_shotgun_accum: float = 0.0
var _dual_shotgun_spr_1: Sprite2D = null
var _dual_shotgun_spr_2: Sprite2D = null
const TEX_WEAPONS_SHEET: Texture2D = preload("res://assets/sprites/weapons_sheet.png")
var auto_mg_timer: float = 0.0
var _auto_mg_accum: float = 0.0
var electric_laser_timer: float = 0.0
var _electric_laser_accum: float = 0.0
var personal_shield_hp: int = 0
var personal_shield_timer: float = 0.0
var slippery_timer: float = 0.0
var earth_shake_timer: float = 0.0
var poison_dot_timer: float = 0.0
var _poison_dot_accum: float = 0.0
var _poison_attacker_id: int = 0
var _poison_attacker_name: String = ""
var cryo_shatter_timer: float = 0.0
var _cryo_shatter_accum: float = 0.0
var _cryo_attacker_id: int = 0
var _cryo_attacker_name: String = ""
var last_world_tap_pos: Vector2 = Vector2.ZERO
var has_world_tap: bool = false
var _hook_pull_target: Vector2 = Vector2.INF
var _hook_pull_timer: float = 0.0
var _laser_visual_timer: float = 0.0
var _laser_visual_angle: float = 0.0
var _laser_visual_color: Color = Color.ORANGE
var _laser_visual_width: float = 22.0
var _laser_visual_len: float = 520.0
var _melee_swing_timer: float = 0.0
var _agent_weapon_node: Node2D = null
var _agent_hud_sync_accum: float = 0.0

# Normal Gunfight Mode Preset & Bomb state
var selected_gun_preset_id: int = 0
const BOMB_TYPES: Array[String] = ["frag", "sticky", "time", "mine", "cluster"]
var bomb_count: int = 3
var max_bombs: int = 3
var bomb_inventory: Dictionary = {}
var bomb_type: String = "frag"
var current_zoom_level: int = 1
var taunt_id: int = 0
var _taunt_timer: float = 0.0
var _taunt_cooldown: float = 0.0
var _taunt_anim: String = ""
var _bomb_cooldown: float = 0.0
var _bomb_throw_timer: float = 0.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _modular_rig: ModularCharacter = $ModularRig
@onready var _weapon_pivot: Node2D = $WeaponPivot
@onready var _primary_weapon: Sprite2D = $WeaponPivot/PrimaryWeapon
@onready var _secondary_weapon: Sprite2D = $WeaponPivot/SecondaryWeapon
@onready var _muzzle_primary: Marker2D = $WeaponPivot/MuzzlePrimary
@onready var _muzzle_secondary: Marker2D = $WeaponPivot/MuzzleSecondary
@onready var _muzzle_flash: Sprite2D = $WeaponPivot/MuzzleFlash
@onready var _rpg_backblast: CPUParticles2D = $WeaponPivot/RPGBackblast
@onready var _jetpack_particles: CPUParticles2D = $JetpackParticles
@onready var _overhead_ui: Node2D = $OverheadUI
@onready var _name_label: Label = $OverheadUI/NameLabel
@onready var _health_fill: ColorRect = $OverheadUI/HealthBarBg/HealthBarFill
@onready var _audio_sfx: AudioStreamPlayer2D = $AudioSfx
@onready var _jetpack_audio: AudioStreamPlayer2D = $JetpackAudio
@onready var _camera: Camera2D = $Camera2D


func setup_player(
	p_id: int,
	p_name: String,
	p_color_idx: int,
	p_is_bot: bool,
	spawn_positions: Array[Vector2],
	p_team: int = 0,
	avatar_dict: Dictionary = {}
) -> void:
	peer_id = p_id
	player_name = p_name
	color_index = p_color_idx
	team_id = clampi(p_team, 0, 1)
	is_bot = p_is_bot
	_spawn_points = spawn_positions

	var av: Dictionary = ProfileManager.sanitize_avatar(avatar_dict)
	archetype_id = int(av["archetype_id"])
	skin_id = int(av["skin_id"])
	head_id = int(av["head_id"])
	torso_id = int(av["torso_id"])
	legs_id = int(av["legs_id"])
	hands_id = int(av["hands_id"])
	accessories_id = int(av["accessories_id"])
	shirt_color = av["shirt_color"] as Color
	pants_color = av["pants_color"] as Color
	skin_color = av["skin_color"] as Color
	helmet_color = av["helmet_color"] as Color
	gear_color = av["gear_color"] as Color
	primary_weapon_id = WeaponData.sanitize_weapon_id(int(av["primary_weapon_id"]))
	secondary_weapon_id = WeaponData.sanitize_weapon_id(int(av["secondary_weapon_id"]))
	_equipped_primary_id = primary_weapon_id
	_original_secondary_id = secondary_weapon_id
	_active_slot = 0
	current_weapon_id = primary_weapon_id
	_primary_reserve_ammo = -1
	_secondary_reserve_ammo = -1
	max_bombs = 3 if NetworkManager.allow_explosives else 0
	bomb_count = max_bombs
	bomb_inventory.clear()
	if max_bombs > 0:
		bomb_inventory[bomb_type] = max_bombs
	weapon_skin_id = int(av["weapon_skin_id"])
	m4a1_rail_mod = int(av["m4a1_rail_mod"])
	taunt_id = int(av.get("taunt_id", 0))

	var auth_id: int = 1 if p_id < 0 else p_id
	set_multiplayer_authority(auth_id)

	if p_is_bot:
		is_local_human = false
	elif not NetworkManager.is_network_active():
		is_local_human = true
	else:
		is_local_human = (p_id == NetworkManager.get_local_peer_id())


func _ready() -> void:
	add_to_group("players")
	spawn_invuln_timer = SPAWN_INVULN_SEC
	_init_agent_kit()
	_apply_modular_textures()
	if NetworkManager.random_guns_mode and not _is_agent_logic_active() and not is_preview_dummy:
		assign_random_loadout()
	else:
		_apply_weapon(current_weapon_id)
	_apply_team_visuals()
	_camera.enabled = is_local_human
	if is_local_human:
		_camera.make_current()
	_muzzle_flash.visible = false
	_update_overhead_ui()
	_emit_hud_signals()


func _init_agent_kit() -> void:
	ability_kill_progress = 0
	_next_unlock_slot = 0
	if NetworkManager.is_unlimited_abilities_active() and not is_bot:
		ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
		ult_points = 4
	else:
		ability_cooldowns = [0.0, 0.0, 0.0, 1.0]
		ult_points = 0
	if AgentData.is_ray_lina(archetype_id):
		_roll_ray_lina_random_kit()
	else:
		custom_ability_slots.clear()
		var ag: Dictionary = AgentData.get_agent(archetype_id)
		var abils: Array = ag["abilities"]
		var ult: Dictionary = ag["ultimate"]
		ability_max_cooldowns = [
			float(abils[0].get("cooldown", 6.0)),
			float(abils[1].get("cooldown", 6.0)),
			float(abils[2].get("cooldown", 6.0)),
			float(ult.get("cooldown", 18.0))
		]
	if _agent_weapon_node == null and is_instance_valid(_weapon_pivot):
		var vis := AgentWeaponVisual.new()
		vis.name = "AgentWeaponVisual"
		_weapon_pivot.add_child(vis)
		_agent_weapon_node = vis
	if not NetworkManager.kill_scored.is_connected(_on_kill_scored):
		NetworkManager.kill_scored.connect(_on_kill_scored)
	if is_local_human:
		agent_abilities_changed.emit()


func get_active_ability_slot(slot_idx: int) -> Dictionary:
	if custom_ability_slots.size() == 4 and slot_idx >= 0 and slot_idx < 4:
		return custom_ability_slots[slot_idx]
	return AgentData.get_ability_slot(archetype_id, slot_idx)


func _roll_ray_lina_random_kit() -> void:
	custom_ability_slots.clear()
	var valid_ids: Array[int] = []
	for idx in range(AgentData.AGENTS.size()):
		if not AgentData.is_ray_lina(idx):
			valid_ids.append(idx)
	if valid_ids.is_empty():
		valid_ids.append(0)
	for slot_i in range(3):
		var src_ag: Dictionary = AgentData.get_agent(valid_ids[randi() % valid_ids.size()])
		var src_ab: Dictionary = (src_ag["abilities"][slot_i] as Dictionary).duplicate(true)
		custom_ability_slots.append(src_ab)
	var ult_ag: Dictionary = AgentData.get_agent(valid_ids[randi() % valid_ids.size()])
	custom_ability_slots.append((ult_ag["ultimate"] as Dictionary).duplicate(true))
	ability_max_cooldowns = [
		float(custom_ability_slots[0].get("cooldown", 6.0)),
		float(custom_ability_slots[1].get("cooldown", 6.0)),
		float(custom_ability_slots[2].get("cooldown", 6.0)),
		float(custom_ability_slots[3].get("cooldown", 18.0))
	]


func _has_locked_ability_or_ult() -> bool:
	for i in range(3):
		if ability_cooldowns[i] > 0.0:
			return true
	return ult_points < 4 or ability_cooldowns[3] > 0.0


func _grant_ability_or_ult_reward() -> void:
	for offset in range(3):
		var candidate: int = (_next_unlock_slot + offset) % 3
		if ability_cooldowns[candidate] > 0.0:
			ability_cooldowns[candidate] = 0.0
			_next_unlock_slot = (candidate + 1) % 3
			return
	ult_points = mini(4, ult_points + 1)
	if ult_points >= 4:
		ability_cooldowns[3] = 0.0


func can_collect_ult_point() -> bool:
	return NetworkManager.is_agent_clash_mode() and not is_dead and ult_points < 4


func collect_ult_point() -> void:
	if not can_collect_ult_point():
		return
	ult_points = mini(4, ult_points + 1)
	if ult_points >= 4:
		ability_cooldowns[3] = 0.0
	_play_local_sfx("res://assets/audio/pickup.wav", -2.0, 1.2)
	if is_local_human:
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)


func _on_kill_scored(killer_id: int, victim_id: int) -> void:
	if killer_id != peer_id or victim_id == peer_id:
		return
	if _is_agent_logic_active():
		if not _has_locked_ability_or_ult():
			ability_kill_progress = 0
		else:
			ability_kill_progress += 1
			if ability_kill_progress >= 2:
				ability_kill_progress = 0
				_grant_ability_or_ult_reward()
		if is_local_human:
			agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
	if not AgentData.is_ray_lina(archetype_id):
		return
	var victim_arch: int = -1
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and int(p.get("peer_id")) == victim_id:
			victim_arch = int(p.get("archetype_id"))
			break
	if victim_arch < 0 or AgentData.is_ray_lina(victim_arch):
		return
	var ag: Dictionary = AgentData.get_agent(victim_arch)
	custom_ability_slots = [
		(ag["abilities"][0] as Dictionary).duplicate(true),
		(ag["abilities"][1] as Dictionary).duplicate(true),
		(ag["abilities"][2] as Dictionary).duplicate(true),
		(ag["ultimate"] as Dictionary).duplicate(true)
	]
	ability_cooldowns = [0.0, 0.0, 0.0, 0.0 if ult_points >= 4 else 1.0]
	ability_max_cooldowns = [
		float(custom_ability_slots[0].get("cooldown", 6.0)),
		float(custom_ability_slots[1].get("cooldown", 6.0)),
		float(custom_ability_slots[2].get("cooldown", 6.0)),
		float(custom_ability_slots[3].get("cooldown", 18.0))
	]
	if is_local_human:
		agent_abilities_changed.emit()
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)


func switch_agent_in_game(new_arch_id: int) -> void:
	var idx: int = wrapi(new_arch_id, 0, ProfileManager.ARCHETYPES.size())
	ProfileManager.apply_archetype_preset(idx, true)
	archetype_id = ProfileManager.archetype_id
	skin_id = ProfileManager.skin_id
	head_id = ProfileManager.head_id
	torso_id = ProfileManager.torso_id
	legs_id = ProfileManager.legs_id
	hands_id = ProfileManager.hands_id
	accessories_id = ProfileManager.accessories_id
	shirt_color = ProfileManager.shirt_color
	pants_color = ProfileManager.pants_color
	skin_color = ProfileManager.skin_color
	helmet_color = ProfileManager.helmet_color
	gear_color = ProfileManager.gear_color
	auto_mg_timer = 0.0
	electric_laser_timer = 0.0
	dual_shotgun_timer = 0.0
	dual_shotgun_shots = 0
	_update_dual_shotgun_visuals(false)
	personal_shield_hp = 0
	personal_shield_timer = 0.0
	boar_ride_timer = 0.0
	speed_boost_timer = 0.0
	speed_boost_mult = 1.0
	nyx_frenzy_timer = 0.0
	invis_timer = 0.0
	invincible_timer = 0.0
	damage_reduction_timer = 0.0
	deathless_timer = 0.0
	zoom_out_timer = 0.0
	gradual_heal_timer = 0.0
	_contra_ult_shots_left = 0
	_contra_ult_shot_timer = 0.0
	_magnet_timer = 0.0
	touch_teleport_timer = 0.0
	touch_fire_timer = 0.0
	touch_banish_timer = 0.0
	_bat_ult_timer = 0.0
	_fly_kick_timer = 0.0
	_spear_timer = 0.0
	_shadow_dash_timer = 0.0
	_flurry_state = 0
	_flurry_timer = 0.0
	queue_redraw()
	_init_agent_kit()
	_apply_modular_textures()
	_apply_team_visuals()
	_apply_weapon_visuals()
	_emit_hud_signals()


func _apply_modular_textures() -> void:
	if not is_node_ready() or _modular_rig == null:
		return
	if _is_agent_logic_active():
		var ag_id: int = clampi(archetype_id, 0, ProfileManager.ARCHETYPES.size() - 1)
		var arch: Dictionary = ProfileManager.ARCHETYPES[ag_id]
		var parts: Dictionary = arch.get("parts", {})
		var base_part: int = ProfileManager.get_archetype_part_id(ag_id)
		_modular_rig.apply_loadout({
			"archetype": ag_id,
			"skin_id": int(parts.get("skin", base_part)),
			"head_id": int(parts.get("head", base_part)),
			"torso_id": int(parts.get("torso", base_part)),
			"legs_id": int(parts.get("legs", base_part)),
			"hands_id": int(parts.get("hands", base_part)),
			"accessories_id": int(parts.get("acc", base_part)),
			"shirt_color": arch.get("shirt", Color.WHITE),
			"pants_color": arch.get("pants", Color.WHITE),
			"skin_color": arch.get("skin", Color.WHITE),
			"helmet_color": arch.get("helmet", Color.WHITE),
			"gear_color": arch.get("gear", Color.WHITE),
		})
		return
	_modular_rig.apply_loadout({
		"archetype": archetype_id,
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
	})


func _exit_tree() -> void:
	if is_instance_valid(_audio_sfx) and _audio_sfx.playing:
		_audio_sfx.stop()
	if is_instance_valid(_jetpack_audio) and _jetpack_audio.playing:
		_jetpack_audio.stop()


func _is_controlled_locally() -> bool:
	if not NetworkManager.is_network_active():
		return is_local_human or is_bot
	return is_multiplayer_authority()


func add_screen_shake(strength: float) -> void:
	if is_local_human:
		_shake_amount = minf(MAX_SCREEN_SHAKE, maxf(_shake_amount, strength) + strength * 0.15)


func _physics_process(delta: float) -> void:
	if NetworkManager.match_over and not is_preview_dummy:
		velocity = Vector2.ZERO
		return
	if spawn_invuln_timer > 0.0:
		spawn_invuln_timer = maxf(0.0, spawn_invuln_timer - delta)

	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if _flash_timer <= 0.0:
			_muzzle_flash.visible = false

	if _fire_anim_timer > 0.0:
		_fire_anim_timer = maxf(0.0, _fire_anim_timer - delta)

	if _melee_swing_timer > 0.0:
		_melee_swing_timer = maxf(0.0, _melee_swing_timer - delta)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
	if reverse_controls_timer > 0.0:
		reverse_controls_timer = maxf(0.0, reverse_controls_timer - delta)
	if invis_timer > 0.0:
		invis_timer = maxf(0.0, invis_timer - delta)
	if control_lock_timer > 0.0:
		control_lock_timer = maxf(0.0, control_lock_timer - delta)
	if gravity_lock_timer > 0.0:
		gravity_lock_timer = maxf(0.0, gravity_lock_timer - delta)
	if freeze_timer > 0.0:
		freeze_timer = maxf(0.0, freeze_timer - delta)
	if ability_lock_timer > 0.0:
		ability_lock_timer = maxf(0.0, ability_lock_timer - delta)
	if flashbang_timer > 0.0:
		flashbang_timer = maxf(0.0, flashbang_timer - delta)
	if invincible_timer > 0.0:
		invincible_timer = maxf(0.0, invincible_timer - delta)
	if damage_reduction_timer > 0.0:
		damage_reduction_timer = maxf(0.0, damage_reduction_timer - delta)
	if slow_mo_timer > 0.0:
		slow_mo_timer = maxf(0.0, slow_mo_timer - delta)
	if time_stop_timer > 0.0:
		time_stop_timer = maxf(0.0, time_stop_timer - delta)
	if touch_teleport_timer > 0.0:
		touch_teleport_timer = maxf(0.0, touch_teleport_timer - delta)
	if touch_fire_timer > 0.0:
		touch_fire_timer = maxf(0.0, touch_fire_timer - delta)
		queue_redraw()
	if touch_banish_timer > 0.0:
		touch_banish_timer = maxf(0.0, touch_banish_timer - delta)
		queue_redraw()
	if banish_after_fx_timer > 0.0:
		banish_after_fx_timer = maxf(0.0, banish_after_fx_timer - delta)
		_banish_fx_accum += delta
		if _banish_fx_accum >= 0.09 and not is_dead:
			_banish_fx_accum = 0.0
			_spawn_rising_particles(global_position + Vector2(randf_range(-16.0, 16.0), randf_range(-20.0, 12.0)), Color(0.84, 0.48, 1.0), false, 5)
			_spawn_rising_particles(global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-18.0, 10.0)), Color(0.45, 0.90, 1.0), false, 3)
		queue_redraw()
	if bubble_trap_lock_timer > 0.0:
		bubble_trap_lock_timer = maxf(0.0, bubble_trap_lock_timer - delta)
	if bubble_trap_timer > 0.0:
		bubble_trap_timer = maxf(0.0, bubble_trap_timer - delta)
		if bubble_trap_timer <= 0.0:
			bubble_trap_hp = 0
			bubble_trap_lock_timer = 0.0
		queue_redraw()
	if deathless_timer > 0.0:
		deathless_timer = maxf(0.0, deathless_timer - delta)
	if zoom_out_timer > 0.0:
		zoom_out_timer = maxf(0.0, zoom_out_timer - delta)
	if slippery_timer > 0.0:
		slippery_timer = maxf(0.0, slippery_timer - delta)
	if earth_shake_timer > 0.0:
		earth_shake_timer = maxf(0.0, earth_shake_timer - delta)
		if is_local_human:
			add_screen_shake(2.6)
		if is_on_floor():
			velocity.x += randf_range(-22.0, 22.0)
	if headless_timer > 0.0:
		headless_timer = maxf(0.0, headless_timer - delta)
		if _headless_proj != null and not is_instance_valid(_headless_proj):
			headless_timer = 0.0
			_headless_proj = null
	if _laser_visual_timer > 0.0:
		_laser_visual_timer = maxf(0.0, _laser_visual_timer - delta)
		queue_redraw()

	if _shake_amount > 0.0:
		_shake_amount = maxf(0.0, _shake_amount - delta * 18.0)
	if is_local_human and is_instance_valid(_camera):
		var bounds: Vector2 = _get_arena_bounds()
		if zoom_out_timer > 0.0:
			_camera.limit_left = 0
			_camera.limit_top = 0
			_camera.limit_right = int(bounds.x)
			_camera.limit_bottom = int(bounds.y)
		else:
			_camera.limit_left = 0
			_camera.limit_top = -76
			_camera.limit_right = int(bounds.x)
			_camera.limit_bottom = int(bounds.y) + 170
		var s: float = _shake_amount * SettingsManager.screen_shake_intensity
		var base_off := Vector2.ZERO if zoom_out_timer > 0.0 else Vector2(0.0, 24.0)
		var target_off: Vector2 = base_off + (Vector2(randf_range(-s, s), randf_range(-s, s)) if s > 0.05 else Vector2.ZERO)
		_camera.offset = _camera.offset.lerp(target_off, 0.45)
		var target_zoom_val: float = get_target_camera_zoom()
		var target_zoom := Vector2(target_zoom_val, target_zoom_val)
		_camera.zoom = _camera.zoom.lerp(target_zoom, clampf(delta * 8.0, 0.0, 1.0))

	if _is_controlled_locally():
		if is_dead:
			_process_dead(delta)
		else:
			_process_alive(delta)
		if NetworkManager.is_network_active():
			_net_sync_accum += delta
			if _net_sync_accum >= 0.05:
				_net_sync_accum = 0.0
				_sync_net_state_rpc.rpc(global_position, velocity, aim_angle, facing_right, is_jetpacking, is_crouching, is_dead, health, anim_frame)
	else:
		_apply_weapon_visuals()
		stun_timer = maxf(0.0, stun_timer - delta)
		freeze_timer = maxf(0.0, freeze_timer - delta)
		control_lock_timer = maxf(0.0, control_lock_timer - delta)
		ability_lock_timer = maxf(0.0, ability_lock_timer - delta)
		invis_timer = maxf(0.0, invis_timer - delta)
		time_stop_timer = maxf(0.0, time_stop_timer - delta)
		invincible_timer = maxf(0.0, invincible_timer - delta)
		deathless_timer = maxf(0.0, deathless_timer - delta)
		speed_boost_timer = maxf(0.0, speed_boost_timer - delta)
		nyx_frenzy_timer = maxf(0.0, nyx_frenzy_timer - delta)
		bubble_trap_lock_timer = maxf(0.0, bubble_trap_lock_timer - delta)
		if bubble_trap_timer > 0.0:
			bubble_trap_timer = maxf(0.0, bubble_trap_timer - delta)
			if bubble_trap_timer <= 0.0:
				bubble_trap_hp = 0
		touch_banish_timer = maxf(0.0, touch_banish_timer - delta)
		thrown_flight_timer = maxf(0.0, thrown_flight_timer - delta)

	_update_visual_state(delta)
	_update_overhead_ui()


func _process_dead(delta: float) -> void:
	var grav_eff: float = GRAVITY * clampf(NetworkManager.gravity_scale, 0.0, 1.0)
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	velocity.y = minf(velocity.y + grav_eff * delta, 700.0)
	is_jetpacking = false
	move_and_slide()

	_respawn_timer -= delta
	if is_local_human:
		died_signal.emit(maxf(0.0, _respawn_timer))
	if _respawn_timer <= 0.0:
		_respawn_self()


func _process_alive(delta: float) -> void:
	if time_stop_timer > 0.0:
		velocity = Vector2.ZERO
		is_jetpacking = false
		_jetpack_particles.emitting = false
		return
	var act_delta: float = delta * (0.20 if slow_mo_timer > 0.0 else 1.0)
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - act_delta)
	if _bomb_cooldown > 0.0:
		_bomb_cooldown = maxf(0.0, _bomb_cooldown - act_delta)
	if _bomb_throw_timer > 0.0:
		_bomb_throw_timer = maxf(0.0, _bomb_throw_timer - act_delta)
	if shoe_cooldown_timer > 0.0:
		shoe_cooldown_timer = maxf(0.0, shoe_cooldown_timer - act_delta)
	if _shoe_windup_timer > 0.0:
		_shoe_windup_timer = maxf(0.0, _shoe_windup_timer - act_delta)
		if is_instance_valid(_modular_rig):
			var prog: float = clampf(1.0 - (_shoe_windup_timer / SHOE_WINDUP_SEC), 0.0, 1.0)
			_modular_rig.play_shoe_throw_frame(prog, not facing_right)
		if _shoe_windup_timer <= 0.0:
			if is_instance_valid(_modular_rig):
				_modular_rig.stop_shoe_throw()
			shoe_cooldown_timer = SHOE_COOLDOWN_SEC
			if is_local_human and NetworkManager.is_agent_clash_mode():
				agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
			var safe_m: Vector2 = _get_safe_muzzle_pos(_muzzle_primary.global_position)
			if NetworkManager.is_network_active():
				throw_item_rpc.rpc(DEFAULT_SHOE_ITEM_ID, safe_m, aim_angle)
			else:
				_throw_item_local(DEFAULT_SHOE_ITEM_ID, safe_m, aim_angle)

	if _hook_pull_timer > 0.0:
		_hook_pull_timer = maxf(0.0, _hook_pull_timer - delta)
		var to_hook: Vector2 = _hook_pull_target - global_position
		if to_hook.length() <= 42.0 or _hook_pull_timer <= 0.0:
			_hook_pull_timer = 0.0
			velocity *= 0.35
		else:
			velocity = to_hook.normalized() * 1250.0
			if is_on_floor() and velocity.y >= -40.0:
				velocity.y = -140.0
			move_and_slide()
			queue_redraw()
			return

	if _is_agent_logic_active():
		if stun_timer > 0.0:
			stun_timer = maxf(0.0, stun_timer - delta)
		if _grab_cooldown > 0.0:
			_grab_cooldown = maxf(0.0, _grab_cooldown - act_delta)
		if speed_boost_timer > 0.0:
			speed_boost_timer = maxf(0.0, speed_boost_timer - delta)
			if speed_boost_timer <= 0.0:
				speed_boost_mult = 1.0
		if nyx_frenzy_timer > 0.0:
			nyx_frenzy_timer = maxf(0.0, nyx_frenzy_timer - delta)
		_tick_agent_buffs_and_dots(delta)
		if _contra_ult_shots_left > 0:
			_contra_ult_shot_timer -= delta
			if _contra_ult_shot_timer <= 0.0:
				_contra_ult_shots_left -= 1
				_contra_ult_shot_timer = 0.24
				_fire_contra_ult_missile()
		if _magnet_timer > 0.0:
			_magnet_timer = maxf(0.0, _magnet_timer - delta)
			if _is_controlled_locally():
				for pk in get_tree().get_nodes_in_group("throwable_pickups"):
					if is_instance_valid(pk) and (pk as Node2D).visible:
						var p2 := pk as Node2D
						var to_anchor: Vector2 = _magnet_anchor - p2.global_position
						var dist: float = to_anchor.length()
						if dist <= 680.0 and dist > 28.0:
							p2.global_position += (to_anchor / dist) * minf(dist - 28.0, 720.0 * delta)
		_agent_hud_sync_accum += delta
		if not is_preview_dummy and NetworkManager.is_agent_clash_mode():
			if _has_locked_ability_or_ult():
				_ability_recharge_timer += delta
				if _ability_recharge_timer >= 10.0:
					_ability_recharge_timer -= 10.0
					_grant_ability_or_ult_reward()
					if is_local_human:
						agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
			else:
				_ability_recharge_timer = 0.0
		if is_local_human and _agent_hud_sync_accum >= 0.08:
			_agent_hud_sync_accum = 0.0
			agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)

		if carried_by_peer_id != 0:
			var carrier := _find_player_by_peer_id(carried_by_peer_id)
			if carrier == null or bool(carrier.get("is_dead")) or int(carrier.get("grabbed_player_id")) != peer_id:
				carried_by_peer_id = 0
				if _collision_shape != null:
					_collision_shape.disabled = false
			else:
				if _collision_shape != null:
					_collision_shape.disabled = true
				global_position = carrier.global_position + Vector2(0.0, -48.0)
				velocity = Vector2.ZERO
				is_jetpacking = false
				var want_punch: bool = false
				if is_local_human:
					want_punch = Input.is_action_pressed("fire") or virtual_fire
				elif is_bot:
					want_punch = true
				if want_punch and _fire_cooldown <= 0.0 and stun_timer <= 0.0 and freeze_timer <= 0.0 and control_lock_timer <= 0.0 and time_stop_timer <= 0.0:
					_fire_cooldown = 0.75 if is_bot else 0.42
					_melee_swing_timer = 0.22
					if carrier.has_method("apply_hit"):
						carrier.apply_hit(18, peer_id, "Escape Punch", player_name, Vector2(0.0, -40.0))
					_spawn_vfx_burst(carrier.global_position + Vector2(0.0, -18.0), 32.0, Color(1.0, 0.82, 0.28))
					_play_local_sfx("res://assets/audio/hit.wav", -2.0, 1.15)
				return

		if grabbed_player_id != 0:
			var victim := _find_player_by_peer_id(grabbed_player_id)
			if victim == null or bool(victim.get("is_dead")):
				grabbed_player_id = 0
				_grab_hold_timer = 0.0
			else:
				victim.global_position = global_position + Vector2(0.0, -48.0)
				_grab_hold_timer -= delta
				if _grab_hold_timer <= 0.0:
					throw_grabbed_player(aim_angle)

		if thrown_flight_timer > 0.0:
			thrown_flight_timer = maxf(0.0, thrown_flight_timer - delta)
			_thrown_flight_elapsed += delta
			if _collision_shape != null:
				_collision_shape.disabled = false
			if _is_controlled_locally() and _check_thrown_player_impact():
				return
			var grav_fly: float = GRAVITY * clampf(NetworkManager.gravity_scale, 0.0, 1.0) * 0.35
			velocity.y = minf(velocity.y + grav_fly * delta, 760.0)
			move_and_slide()
			if _is_controlled_locally():
				_check_thrown_player_impact()
			if thrown_flight_timer <= 0.0:
				thrown_by_peer_id = 0
				thrown_by_rook_frost = false
			return

	if not NetworkManager.is_agent_clash_mode() and is_reloading:
		_reload_timer -= act_delta
		if _reload_timer <= 0.0:
			var res_ammo: int = get_active_reserve_ammo()
			if _weapon.single_shell_reload:
				if res_ammo != 0:
					current_ammo = mini(_weapon.mag_size, current_ammo + 1)
					if res_ammo > 0:
						res_ammo -= 1
						_set_active_reserve_ammo(res_ammo)
					_play_local_sfx("res://assets/audio/pickup.wav", -10.0)
				if current_ammo < _weapon.mag_size and res_ammo != 0:
					_reload_timer = _weapon.reload_time
				else:
					is_reloading = false
				_emit_ammo()
			else:
				is_reloading = false
				if res_ammo >= 0:
					var needed: int = maxi(0, _weapon.mag_size - current_ammo)
					var take: int = mini(needed, res_ammo)
					current_ammo += take
					_set_active_reserve_ammo(res_ammo - take)
				else:
					current_ammo = _weapon.mag_size
				_emit_ammo()

	var move_dir: float = 0.0
	var want_jump: bool = false
	var want_crouch: bool = false
	var want_jet: bool = false
	var want_fire: bool = false

	var is_stunned: bool = _is_agent_logic_active() and (stun_timer > 0.0 or freeze_timer > 0.0 or control_lock_timer > 0.0)

	if is_bot:
		var bot_cmd: Dictionary = _compute_bot_input(delta)
		if not is_stunned:
			move_dir = float(bot_cmd["move_x"])
			want_jump = bool(bot_cmd["jump"])
			want_crouch = bool(bot_cmd["crouch"])
			want_jet = bool(bot_cmd["jetpack"])
			want_fire = bool(bot_cmd["fire"])
			aim_angle = float(bot_cmd["aim_angle"])
	elif is_stunned:
		move_dir = 0.0
		want_jump = false
		want_crouch = false
		want_jet = false
		want_fire = false
	else:
		var kb_x: float = Input.get_axis("move_left", "move_right")
		if absf(virtual_move.x) > 0.12:
			move_dir = clampf(virtual_move.x * SettingsManager.move_stick_sensitivity, -1.0, 1.0)
		else:
			move_dir = kb_x

		var stick_y: float = virtual_move.y * SettingsManager.move_stick_sensitivity
		if SettingsManager.invert_y_axis:
			stick_y = -stick_y

		want_jump = Input.is_action_just_pressed("jump")
		want_crouch = Input.is_action_pressed("crouch") or (stick_y > 0.55)
		var hold_jump_midair: bool = Input.is_action_pressed("jump") and not is_on_floor() and velocity.y > -60.0
		want_jet = Input.is_action_pressed("jetpack") or hold_jump_midair or virtual_jetpack or (stick_y < -0.45)

		var is_mobile_touch: bool = OS.has_feature("mobile") or OS.get_name() == "Android"
		if virtual_aim.length() > 0.15:
			var aim_vec := Vector2(virtual_aim.x, -virtual_aim.y if SettingsManager.invert_y_axis else virtual_aim.y)
			aim_angle = aim_vec.angle()
		elif is_mobile_touch:
			if move_dir > 0.05:
				aim_angle = 0.0
			elif move_dir < -0.05:
				aim_angle = PI
			else:
				aim_angle = 0.0 if facing_right else PI
		else:
			var aim_origin: Vector2 = global_position + Vector2(0.0, 6.0)
			var mouse_delta: Vector2 = get_global_mouse_position() - aim_origin
			if SettingsManager.invert_y_axis:
				mouse_delta.y = -mouse_delta.y
			if mouse_delta.length_squared() >= 64.0:
				aim_angle = mouse_delta.angle()

		if SettingsManager.auto_aim_assist:
			aim_angle = _apply_auto_aim_assist(aim_angle)

		if reverse_controls_timer > 0.0:
			move_dir = -move_dir
			var tmp_j: bool = want_jump
			want_jump = want_crouch
			want_crouch = tmp_j
			aim_angle = wrapf(aim_angle + PI, -PI, PI)

		want_fire = virtual_fire if is_mobile_touch else (virtual_fire or (Input.is_action_pressed("fire") and not pointer_over_ui))
		if touch_teleport_timer > 0.0 or touch_fire_timer > 0.0 or touch_banish_timer > 0.0:
			want_fire = false

		if _is_agent_logic_active():
			if Input.is_action_just_pressed("ability_1"):
				use_agent_ability(0)
			if Input.is_action_just_pressed("ability_2"):
				use_agent_ability(1)
			if Input.is_action_just_pressed("ability_3"):
				use_agent_ability(2)
			if Input.is_action_just_pressed("ability_ult"):
				use_agent_ability(3)
			if Input.is_action_just_pressed("throw_item"):
				throw_held_item()
		else:
			if Input.is_action_just_pressed("reload"):
				start_reload()
			if Input.is_action_just_pressed("switch_weapon"):
				cycle_weapon()
			if Input.is_action_just_pressed("throw_item"):
				throw_bomb()
		if Input.is_action_just_pressed("taunt"):
			trigger_taunt()

	if _taunt_cooldown > 0.0:
		_taunt_cooldown = maxf(0.0, _taunt_cooldown - delta)
	if _taunt_timer > 0.0:
		_taunt_timer = maxf(0.0, _taunt_timer - delta)

	var aim_cos: float = cos(aim_angle)
	if aim_cos > 0.18:
		facing_right = true
	elif aim_cos < -0.18:
		facing_right = false

	if bubble_trap_timer > 0.0:
		is_crouching = false
		_update_crouch_collider(false)
		is_jetpacking = false
		var float_t: float = Time.get_ticks_msec() * 0.001
		var target_vy: float = -72.0 + sin(float_t * 3.1 + float(peer_id)) * 34.0
		velocity.y = move_toward(velocity.y, target_vy, 240.0 * delta)
		var drift_vx: float = move_dir * 75.0 + cos(float_t * 2.2 + float(peer_id)) * 22.0
		velocity.x = move_toward(velocity.x, drift_vx, 140.0 * delta)
		var pre_vel: Vector2 = velocity
		move_and_slide()
		if get_slide_collision_count() > 0:
			var col := get_slide_collision(0)
			if col != null:
				var n: Vector2 = col.get_normal()
				velocity = pre_vel.bounce(n) * 0.85
				if n.y < -0.5:
					velocity.y = minf(velocity.y, -110.0)
		for p in get_tree().get_nodes_in_group("players"):
			if is_instance_valid(p) and p != self and (not p.has_method("is_alive") or p.is_alive()):
				var diff: Vector2 = global_position - (p as Node2D).global_position
				var dist: float = diff.length()
				if dist < 50.0 and dist > 0.01:
					var push_dir: Vector2 = diff / dist
					velocity = push_dir * 340.0 + Vector2(0.0, -85.0)
					break
		if want_fire and _fire_cooldown <= 0.0 and not is_stunned:
			if _is_agent_logic_active():
				_fire_agent_base_weapon()
			else:
				if is_reloading and _weapon.single_shell_reload and current_ammo > 0:
					is_reloading = false
					_emit_ammo()
				if not is_reloading:
					if current_ammo <= 0:
						start_reload()
					else:
						_fire_weapon()
		return

	is_crouching = want_crouch and is_on_floor() and not want_jet and not is_stunned
	_update_crouch_collider(is_crouching)

	var speed_mult: float = 1.0 if NetworkManager.is_agent_clash_mode() else (_weapon.move_speed_multiplier if _weapon != null else 1.0)
	if NetworkManager.is_agent_clash_mode() and speed_boost_timer > 0.0:
		speed_mult *= speed_boost_mult
	if boar_ride_timer > 0.0:
		speed_mult *= 1.68
	if slow_mo_timer > 0.0:
		speed_mult *= 0.20
	if is_bot:
		var bot_diff: int = clampi(NetworkManager.bot_difficulty, 0, 2)
		speed_mult *= (0.72 if bot_diff == 0 else (0.86 if bot_diff == 1 else 1.0))
	var target_speed: float = (CROUCH_SPEED if is_crouching else MOVE_SPEED) * speed_mult * move_dir
	var accel: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var fric: float = FRICTION if is_on_floor() else AIR_ACCEL * 0.45
	if slippery_timer > 0.0 and is_on_floor():
		accel = 25.0
		fric = 0.0
		var slide_dir: float = signf(velocity.x) if absf(velocity.x) > 5.0 else (1.0 if facing_right else -1.0)
		velocity.x = slide_dir * 520.0
	if is_stunned:
		if freeze_timer > 0.0:
			velocity.x = 0.0
		else:
			var stun_fric: float = (FRICTION * 0.85) if is_on_floor() else (AIR_ACCEL * 0.25)
			velocity.x = move_toward(velocity.x, 0.0, stun_fric * delta)
	elif absf(move_dir) > 0.05:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	if want_jump:
		var j_mult: float = 0.20 if slow_mo_timer > 0.0 else 1.0
		if is_on_floor():
			velocity.y = JUMP_VELOCITY * j_mult
			_play_local_sfx("res://assets/audio/jump.wav", -6.0)
		elif is_on_wall_only():
			var wall_normal: Vector2 = get_wall_normal()
			velocity.y = JUMP_VELOCITY * 0.92 * j_mult
			velocity.x = wall_normal.x * WALL_JUMP_X
			_play_local_sfx("res://assets/audio/jump.wav", -6.0)

	var grav_eff: float = GRAVITY * clampf(NetworkManager.gravity_scale, 0.0, 1.0) * (0.09 if slow_mo_timer > 0.0 else 1.0)
	var has_fuel: bool = NetworkManager.unlimited_jetpack or (jetpack_fuel > 0.5)
	if gravity_lock_timer > 0.0:
		velocity = Vector2.ZERO
		is_jetpacking = false
	elif want_jet and has_fuel and not is_crouching:
		is_jetpacking = true
		var jet_spd_mult: float = clampf(NetworkManager.jet_speed_scale, 0.1, 1.0)
		var max_up_spd: float = JETPACK_MAX_UP_SPEED * jet_spd_mult * (0.35 if slow_mo_timer > 0.0 else 1.0)
		velocity.y = maxf(velocity.y - JETPACK_THRUST * jet_spd_mult * act_delta, max_up_spd)
		if NetworkManager.unlimited_jetpack:
			jetpack_fuel = MAX_FUEL
		else:
			jetpack_fuel = maxf(0.0, jetpack_fuel - FUEL_CONSUME_RATE * delta)
			_fuel_recharge_delay = 0.35
	else:
		is_jetpacking = false
		velocity.y += grav_eff * delta
		if not is_on_floor() and want_crouch and NetworkManager.gravity_scale < 0.25:
			velocity.y = minf(velocity.y + 420.0 * delta, 320.0)
		if NetworkManager.unlimited_jetpack:
			jetpack_fuel = MAX_FUEL
		elif _fuel_recharge_delay > 0.0:
			_fuel_recharge_delay = maxf(0.0, _fuel_recharge_delay - delta)
		else:
			var rate: float = FUEL_RECHARGE_GROUND if is_on_floor() else FUEL_RECHARGE_AIR
			jetpack_fuel = minf(MAX_FUEL, jetpack_fuel + rate * delta)

	if is_on_wall_only() and velocity.y > WALL_SLIDE_SPEED and not is_jetpacking:
		velocity.y = WALL_SLIDE_SPEED

	velocity.y = minf(velocity.y, 760.0)
	move_and_slide()

	if want_fire and _fire_cooldown <= 0.0 and not is_stunned:
		if _is_agent_logic_active():
			_fire_agent_base_weapon()
		else:
			if is_reloading and _weapon.single_shell_reload and current_ammo > 0:
				is_reloading = false
				_emit_ammo()
			if not is_reloading:
				if current_ammo <= 0:
					start_reload()
				else:
					_fire_weapon()

	if is_local_human:
		fuel_changed.emit(jetpack_fuel, MAX_FUEL)
		queue_redraw()


func _apply_auto_aim_assist(raw_angle: float) -> float:
	var best_angle: float = raw_angle
	var best_diff: float = deg_to_rad(13.0)
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for node in get_tree().get_nodes_in_group("players"):
		if node == self or not is_instance_valid(node):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		if NetworkManager.is_team_mode() and int(node.get("team_id")) == team_id:
			continue
		if float(node.get("invis_timer")) > 0.0:
			continue
		var delta_v: Vector2 = node.global_position - _weapon_pivot.global_position
		if delta_v.length() > 700.0:
			continue
		var target_ang: float = delta_v.angle()
		var diff: float = absf(angle_difference(raw_angle, target_ang))
		if diff < best_diff:
			var ray := PhysicsRayQueryParameters2D.create(_weapon_pivot.global_position, node.global_position, 1)
			if space_state.intersect_ray(ray).is_empty():
				best_diff = diff
				best_angle = lerp_angle(raw_angle, target_ang, 0.45)
	return best_angle


func _update_crouch_collider(crouching: bool) -> void:
	var cap: CapsuleShape2D = _collision_shape.shape as CapsuleShape2D
	if cap == null:
		return
	if crouching:
		cap.height = 32.0
		_collision_shape.position.y = 11.0
		_weapon_pivot.position.y = 9.0
	else:
		cap.height = 48.0
		_collision_shape.position.y = 3.0
		_weapon_pivot.position.y = 6.0


func get_current_weapon() -> WeaponData:
	return _weapon


func _fire_weapon() -> void:
	_fire_cooldown = _weapon.fire_interval
	if is_bot:
		var bot_diff: int = clampi(NetworkManager.bot_difficulty, 0, 2)
		var fire_delay_mult: float = 1.85 if bot_diff == 0 else (1.35 if bot_diff == 1 else 1.0)
		_fire_cooldown *= fire_delay_mult

	var shots_to_fire: int = 1
	current_ammo = maxi(0, current_ammo - shots_to_fire)
	_emit_ammo()

	var fire_angle: float = aim_angle
	var aim_dir: Vector2 = Vector2.from_angle(fire_angle)
	velocity -= aim_dir * _weapon.recoil_impulse * (1.25 if shots_to_fire == 2 else 1.0)
	add_screen_shake(clampf(_weapon.recoil_impulse * 0.004, 0.15, 0.85))

	_fire_anim_timer = 0.14
	_update_visual_state(0.0)
	_apply_weapon_visuals()
	_sync_muzzle_positions(fire_angle)
	var muzzle_positions := PackedVector2Array([_get_safe_muzzle_pos(_muzzle_primary.global_position)])
	if shots_to_fire == 2:
		muzzle_positions.append(_get_safe_muzzle_pos(_muzzle_secondary.global_position))

	# Predictable vertical recoil bias (positive climbs upward; Kriss Vector negative compensates downward)
	var recoil_sign: float = -1.0 if cos(aim_angle) >= 0.0 else 1.0
	aim_angle = wrapf(aim_angle + recoil_sign * _weapon.vertical_recoil_bias, -PI, PI)

	var seed_val: int = int(Time.get_ticks_usec() % 1000000)
	if NetworkManager.is_network_active():
		spawn_projectiles_rpc.rpc(muzzle_positions, fire_angle, _weapon.id, weapon_skin_id, m4a1_rail_mod, seed_val)
	else:
		_spawn_projectiles_local(muzzle_positions, fire_angle, _weapon.id, weapon_skin_id, m4a1_rail_mod, seed_val)

	if current_ammo <= 0:
		if _is_using_secondary_slot() and secondary_weapon_id != _original_secondary_id and _secondary_reserve_ammo == 0:
			secondary_weapon_id = _original_secondary_id
			_secondary_reserve_ammo = -1
			_secondary_saved_ammo = -1
			set_weapon(secondary_weapon_id)
		elif not _is_using_secondary_slot() and _equipped_primary_id != primary_weapon_id and _primary_reserve_ammo == 0:
			_equipped_primary_id = primary_weapon_id
			_primary_reserve_ammo = -1
			_primary_saved_ammo = -1
			set_weapon(_equipped_primary_id)
		else:
			start_reload()


@rpc("any_peer", "call_local", "reliable")
func spawn_projectiles_rpc(muzzles: PackedVector2Array, base_angle: float, weapon_id: int, skin_id: int, rail_mod: int, rng_seed: int) -> void:
	_spawn_projectiles_local(muzzles, base_angle, weapon_id, skin_id, rail_mod, rng_seed)


func _spawn_projectiles_local(muzzles: PackedVector2Array, base_angle: float, weapon_id: int, skin_id: int, rail_mod: int, rng_seed: int) -> void:
	var w: WeaponData = WeaponData.get_weapon(weapon_id, skin_id, rail_mod)
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var deal_damage: bool = _is_controlled_locally()
	if bubble_trap_timer > 0.0:
		if deal_damage:
			damage_bubble(maxi(10, w.damage))
		_muzzle_flash.scale = Vector2(0.8, 0.8) * w.muzzle_flash_scale
		_muzzle_flash.visible = w.muzzle_flash_scale > 0.05
		_flash_timer = 0.055
		_fire_anim_timer = 0.14
		return
	var spread_rad: float = deg_to_rad(w.spread_deg)

	for m_pos in muzzles:
		for _p in range(w.pellet_count):
			var b := BULLET_SCENE.instantiate()
			var shot_angle: float = base_angle + rng.randf_range(-spread_rad, spread_rad)
			b.global_position = m_pos
			b.velocity = Vector2.from_angle(shot_angle) * w.bullet_speed
			b.damage = w.damage
			b.shooter_peer_id = peer_id
			b.shooter_team = team_id
			b.shooter_name = player_name
			b.shooter_rid = get_rid()
			b.weapon_name = w.display_name
			b.bullet_color = w.bullet_color
			b.is_laser = w.is_laser
			b.is_explosive = w.is_explosive
			b.explosion_radius = w.explosion_radius
			b.damage_falloff_start = w.damage_falloff_start
			b.min_damage_ratio = w.min_damage_ratio
			b.can_deal_damage = deal_damage
			b.is_homing = w.is_homing
			b.stun_duration = w.stun_duration
			if w.custom_visual_style != "bullet":
				b.visual_style = w.custom_visual_style
			elif w.is_explosive:
				b.visual_style = "rocket"
			if w.pellet_count > 1:
				# Shotguns deal strong burst at close-to-mid range (~315 px) and instant kill at close range
				b.max_lifetime = 0.34
				b.knockback_mult = 1.5 / float(w.pellet_count)
				if w.id == 5 or w.id == 6:
					b.close_lethal_dist = 135.0
			else:
				b.max_lifetime = w.custom_lifetime
			if w.bullet_range > 0.0:
				b.max_range = w.bullet_range
				b.max_lifetime = maxf(b.max_lifetime, (w.bullet_range / maxf(100.0, b.velocity.length())) + 0.25)
			if w.id == 7 or w.id == 8:
				b.pierce_players = true
			if w.id == 15:
				b.boomerang_owner = self
				b.on_hit_effect_kind = "hook_gun"
			elif w.id == 16:
				b.on_hit_effect_kind = "bubble_trap"
				b.radius_scale = 1.65
			parent_node.add_child(b)

	_muzzle_flash.scale = Vector2(0.8, 0.8) * w.muzzle_flash_scale
	_muzzle_flash.visible = w.muzzle_flash_scale > 0.05
	_flash_timer = 0.055
	_fire_anim_timer = 0.14

	if w.has_backblast and SettingsManager.particle_intensity > 0.05:
		_rpg_backblast.restart()

	var is_suppressed: bool = w.has_accessory_rail and rail_mod == 1
	var vol_offset: float = -10.0 if is_suppressed else -4.0
	var pitch_override: float = 1.32 if is_suppressed else 0.0
	_play_local_sfx(w.sound_path, vol_offset, pitch_override)


func start_reload() -> void:
	if _is_agent_logic_active():
		return
	if is_reloading or current_ammo >= _weapon.mag_size or is_dead:
		return
	if get_active_reserve_ammo() == 0:
		return
	is_reloading = true
	_reload_timer = _weapon.reload_time
	_emit_ammo()


func cycle_weapon() -> void:
	if NetworkManager.is_agent_clash_mode() or is_dead:
		return
	if _is_using_secondary_slot():
		_secondary_saved_ammo = current_ammo
	else:
		_primary_saved_ammo = current_ammo
	if _equipped_primary_id != secondary_weapon_id or _equipped_primary_id != primary_weapon_id or secondary_weapon_id != _original_secondary_id:
		_active_slot = 1 if _active_slot == 0 else 0
		var next_id: int = secondary_weapon_id if _active_slot == 1 else _equipped_primary_id
		set_weapon(next_id)
		# Glock 17 backup pistol features quick-draw readiness
		if _active_slot == 1:
			_fire_cooldown = minf(_fire_cooldown, 0.08)
	else:
		var next_id: int = (current_weapon_id + 1) % WeaponData.get_weapon_count()
		set_weapon(next_id)


func drop_picked_up_gun() -> void:
	if NetworkManager.is_agent_clash_mode() or is_dead:
		return
	var using_sec: bool = _is_using_secondary_slot()
	var cur_slot_id: int = secondary_weapon_id if using_sec else _equipped_primary_id
	var orig_slot_id: int = _original_secondary_id if using_sec else primary_weapon_id
	if cur_slot_id == orig_slot_id:
		return
	var dropped_mag: int = current_ammo
	var dropped_res: int = _secondary_reserve_ammo if using_sec else _primary_reserve_ammo
	if NetworkManager.is_network_active():
		drop_picked_up_gun_vfx_rpc.rpc(cur_slot_id, global_position, aim_angle, dropped_mag, dropped_res)
	else:
		_spawn_dropped_gun_pickup(cur_slot_id, global_position, aim_angle, dropped_mag, dropped_res)
	if using_sec:
		secondary_weapon_id = _original_secondary_id
		_secondary_reserve_ammo = -1
		_secondary_saved_ammo = -1
		set_weapon(secondary_weapon_id)
	else:
		_equipped_primary_id = primary_weapon_id
		_primary_reserve_ammo = -1
		_primary_saved_ammo = -1
		set_weapon(_equipped_primary_id)
	_play_local_sfx("res://assets/audio/jump.wav", -3.0, 1.1)


@rpc("any_peer", "call_local", "reliable")
func drop_picked_up_gun_vfx_rpc(w_id: int, origin: Vector2, angle: float, saved_mag: int, saved_res: int) -> void:
	_spawn_dropped_gun_pickup(w_id, origin, angle, saved_mag, saved_res)


func _spawn_dropped_gun_pickup(w_id: int, origin: Vector2, angle: float, saved_mag: int, saved_res: int) -> void:
	var arena := get_tree().current_scene
	if arena != null and arena.has_method("spawn_dropped_weapon_pickup"):
		arena.spawn_dropped_weapon_pickup(w_id, origin, angle, saved_mag, saved_res)


func _is_using_secondary_slot() -> bool:
	return _active_slot == 1


func get_active_reserve_ammo() -> int:
	return _secondary_reserve_ammo if _is_using_secondary_slot() else _primary_reserve_ammo


func _set_active_reserve_ammo(val: int) -> void:
	if _is_using_secondary_slot():
		_secondary_reserve_ammo = val
	else:
		_primary_reserve_ammo = val


func set_weapon(new_weapon_id: int) -> void:
	current_weapon_id = WeaponData.sanitize_weapon_id(new_weapon_id)
	_apply_weapon(current_weapon_id)
	if NetworkManager.is_network_active() and _is_controlled_locally():
		sync_weapon_rpc.rpc(current_weapon_id, m4a1_rail_mod)


func apply_gun_preset(preset_idx: int) -> void:
	if _is_agent_logic_active():
		return
	if NetworkManager.random_guns_mode:
		assign_random_loadout()
		return
	selected_gun_preset_id = clampi(preset_idx, 0, WeaponData.GUN_PRESETS.size() - 1)
	var preset: Dictionary = WeaponData.get_effective_preset(selected_gun_preset_id)
	primary_weapon_id = int(preset["primary"])
	secondary_weapon_id = int(preset["secondary"])
	_equipped_primary_id = primary_weapon_id
	_original_secondary_id = secondary_weapon_id
	_active_slot = 0
	_primary_reserve_ammo = -1
	_secondary_reserve_ammo = -1
	_primary_saved_ammo = -1
	_secondary_saved_ammo = -1
	bomb_type = str(preset.get("bomb_type", "frag"))
	max_bombs = int(preset.get("bombs", 3))
	bomb_count = max_bombs
	bomb_inventory.clear()
	if max_bombs > 0:
		bomb_inventory[bomb_type] = max_bombs
	set_weapon(primary_weapon_id)
	if is_local_human:
		bombs_changed.emit(bomb_count, bomb_type)


func assign_random_loadout() -> void:
	if _is_agent_logic_active():
		return
	var allowed: Array[int] = []
	for wid in range(WeaponData.get_weapon_count()):
		if WeaponData.sanitize_weapon_id(wid) == wid:
			allowed.append(wid)
	if allowed.is_empty():
		allowed.append(0)
	primary_weapon_id = allowed[randi() % allowed.size()]
	if allowed.size() > 1:
		var sec_pool: Array[int] = []
		for wid in allowed:
			if wid != primary_weapon_id:
				sec_pool.append(wid)
		secondary_weapon_id = sec_pool[randi() % sec_pool.size()] if not sec_pool.is_empty() else primary_weapon_id
	else:
		secondary_weapon_id = primary_weapon_id
	_equipped_primary_id = primary_weapon_id
	_original_secondary_id = secondary_weapon_id
	_active_slot = 0
	_primary_reserve_ammo = -1
	_secondary_reserve_ammo = -1
	_primary_saved_ammo = -1
	_secondary_saved_ammo = -1
	bomb_type = str(BOMB_TYPES[randi() % BOMB_TYPES.size()]) if not BOMB_TYPES.is_empty() else "frag"
	max_bombs = 3 if NetworkManager.allow_explosives else 0
	bomb_count = max_bombs
	bomb_inventory.clear()
	if max_bombs > 0:
		bomb_inventory[bomb_type] = max_bombs
	set_weapon(primary_weapon_id)
	if is_local_human:
		bombs_changed.emit(bomb_count, bomb_type)


func set_bomb_type(b_type: String) -> void:
	if _is_agent_logic_active():
		return
	var next_t: String = b_type if not b_type.is_empty() else "frag"
	var prev_cnt: int = int(bomb_inventory.get(bomb_type, bomb_count))
	bomb_type = next_t
	if prev_cnt > 0 and not bomb_inventory.has(bomb_type):
		bomb_inventory[bomb_type] = prev_cnt
	_sync_bomb_count_from_inventory()


func _sync_bomb_count_from_inventory() -> void:
	bomb_count = int(bomb_inventory.get(bomb_type, 0))
	if is_local_human:
		bombs_changed.emit(bomb_count, bomb_type)


func add_bomb_pickup(b_type: String, count: int = 1) -> void:
	if NetworkManager.is_agent_clash_mode() or not NetworkManager.allow_explosives or is_dead:
		return
	var clean_t: String = b_type if BOMB_TYPES.has(b_type) else "frag"
	bomb_inventory[clean_t] = int(bomb_inventory.get(clean_t, 0)) + maxi(1, count)
	if int(bomb_inventory.get(bomb_type, 0)) <= 0:
		bomb_type = clean_t
	_sync_bomb_count_from_inventory()
	_play_local_sfx("res://assets/audio/pickup.wav", -2.0)


func grant_full_ult() -> void:
	if is_dead:
		return
	ult_points = 4
	ability_cooldowns[3] = 0.0
	_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.15)
	if is_local_human:
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)


func ready_ability_slot(slot_idx: int) -> void:
	if is_dead or slot_idx < 0 or slot_idx >= 3:
		return
	ability_cooldowns[slot_idx] = 0.0
	_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.3)
	if is_local_human:
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)


func cycle_bomb_type() -> void:
	if NetworkManager.is_agent_clash_mode() or is_dead:
		return
	var avail: Array[String] = []
	for bt in BOMB_TYPES:
		if int(bomb_inventory.get(bt, 0)) > 0:
			avail.append(bt)
	if avail.size() <= 1:
		return
	var cur_idx: int = avail.find(bomb_type)
	bomb_type = avail[(cur_idx + 1) % avail.size()]
	_sync_bomb_count_from_inventory()


func throw_bomb() -> void:
	if NetworkManager.is_agent_clash_mode() or is_dead or bomb_count <= 0 or _bomb_cooldown > 0.0 or not NetworkManager.allow_explosives:
		return
	var thrown_type: String = bomb_type
	var next_cnt: int = maxi(0, int(bomb_inventory.get(thrown_type, bomb_count)) - 1)
	bomb_inventory[thrown_type] = next_cnt
	if next_cnt <= 0:
		for bt in BOMB_TYPES:
			if int(bomb_inventory.get(bt, 0)) > 0:
				bomb_type = bt
				break
	_bomb_cooldown = 0.65
	_sync_bomb_count_from_inventory()
	var safe_m: Vector2 = _get_safe_muzzle_pos(_muzzle_primary.global_position)
	if NetworkManager.is_network_active():
		throw_bomb_rpc.rpc(safe_m, aim_angle, thrown_type)
	else:
		_throw_bomb_local(safe_m, aim_angle, thrown_type)


@rpc("any_peer", "call_local", "reliable")
func throw_bomb_rpc(origin: Vector2, angle: float, b_type: String) -> void:
	_throw_bomb_local(origin, angle, b_type)


func _throw_bomb_local(origin: Vector2, angle: float, b_type: String) -> void:
	_bomb_throw_timer = 0.26
	var local_auth: bool = _is_controlled_locally()
	match b_type:
		"cluster":
			for off in [-0.14, 0.0, 0.14]:
				_spawn_bomb_instance(origin, angle + off, "cluster", 580.0, 48, 125.0, Color(1.0, 0.42, 0.15), "Cluster Bomb", local_auth)
		"sticky":
			_spawn_bomb_instance(origin, angle, "sticky", 660.0, 88, 150.0, Color(0.28, 0.72, 1.0), "Sticky Bomb", local_auth)
		"time":
			_spawn_bomb_instance(origin, angle, "time", 560.0, 105, 185.0, Color(1.0, 0.30, 0.22), "Time Bomb", local_auth)
		"mine":
			_spawn_bomb_instance(origin, angle, "mine", 380.0, 95, 150.0, Color(1.0, 0.62, 0.18), "Mine Bomb", local_auth)
		_:
			_spawn_bomb_instance(origin, angle, "frag", 600.0, 125, 195.0, Color(0.28, 0.92, 0.42), "Frag Bomb", local_auth)
	_play_local_sfx("res://assets/audio/jump.wav", -2.0, 0.65)


func _spawn_bomb_instance(origin: Vector2, angle: float, b_type: String, speed: float, dmg: int, radius: float, col: Color, w_name: String, local_auth: bool) -> Node2D:
	var world_node: Node = get_parent()
	if world_node == null:
		return null
	var bomb: Node2D = BOMB_SCRIPT.new() as Node2D
	bomb.global_position = origin
	bomb.set("bomb_type", b_type)
	bomb.set("velocity", Vector2.from_angle(angle) * speed + Vector2(0.0, -90.0))
	bomb.set("damage", dmg)
	bomb.set("explosion_radius", radius)
	bomb.set("shooter_peer_id", peer_id)
	bomb.set("shooter_team", team_id)
	bomb.set("shooter_name", player_name)
	bomb.set("shooter_rid", get_rid())
	bomb.set("weapon_name", w_name)
	bomb.set("bomb_color", col)
	bomb.set("can_deal_damage", local_auth)
	world_node.add_child(bomb)
	return bomb


@rpc("any_peer", "call_local", "reliable")
func sync_weapon_rpc(weapon_id: int, rail_mod: int = 0) -> void:
	current_weapon_id = weapon_id
	m4a1_rail_mod = rail_mod
	_apply_weapon(weapon_id)


func _apply_weapon(weapon_id: int) -> void:
	var safe_id: int = WeaponData.sanitize_weapon_id(weapon_id)
	current_weapon_id = safe_id
	_weapon = WeaponData.get_weapon(safe_id, weapon_skin_id, m4a1_rail_mod)
	is_reloading = false
	var active_res: int = get_active_reserve_ammo()
	var saved_ammo: int = _secondary_saved_ammo if _is_using_secondary_slot() else _primary_saved_ammo
	if active_res >= 0 and saved_ammo >= 0:
		current_ammo = mini(saved_ammo, _weapon.mag_size)
	else:
		current_ammo = _weapon.mag_size
	current_zoom_level = clampi(current_zoom_level, 1, get_max_zoom_level())
	_apply_weapon_visuals()
	_emit_hud_signals()


func get_max_zoom_level() -> int:
	if NetworkManager.is_agent_clash_mode() or _weapon == null:
		return 1
	return clampi(maxi(2, _weapon.max_zoom_level), 2, ZOOM_LEVEL_VALUES.size())


func get_target_camera_zoom() -> float:
	if zoom_out_timer > 0.0:
		var bounds: Vector2 = _get_arena_bounds()
		var vp_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)
		if vp_size.x > 0.0 and vp_size.y > 0.0 and bounds.x > 0.0 and bounds.y > 0.0:
			var full_map_zoom: float = maxf(vp_size.x / bounds.x, vp_size.y / bounds.y)
			return clampf(full_map_zoom, 0.15, 1.05)
		return 0.58
	if NetworkManager.is_agent_clash_mode() or is_dead or _weapon == null:
		return 1.30
	var lvl: int = clampi(current_zoom_level, 1, get_max_zoom_level())
	return ZOOM_LEVEL_VALUES[lvl - 1]


func cycle_zoom() -> void:
	if NetworkManager.is_agent_clash_mode() or is_dead or _weapon == null:
		return
	var max_z: int = get_max_zoom_level()
	current_zoom_level = 1 if current_zoom_level >= max_z else (current_zoom_level + 1)
	if is_local_human:
		zoom_changed.emit(current_zoom_level, max_z)


const TEX_FLAMETHROWER: Texture2D = preload("res://assets/sprites/weapons/flamethrower.png")
const TEX_HOOK_GUN: Texture2D = preload("res://assets/sprites/weapons/hook_gun.png")
const TEX_BUBBLE_GUN: Texture2D = preload("res://assets/sprites/weapons/bubble_gun.png")
const TEX_MACHINE_GUN: Texture2D = preload("res://assets/sprites/weapons/machine_gun.png")
const TEX_PLASMA_CANNON: Texture2D = preload("res://assets/sprites/weapons/plasma_cannon.png")
var _weapons_sheet_tex: Texture2D = null
var _weapons_base_scale: Vector2 = Vector2.ONE


func _apply_weapon_visuals() -> void:
	if not is_node_ready():
		return
	if _weapons_sheet_tex == null and _primary_weapon != null:
		_weapons_sheet_tex = _primary_weapon.texture
		_weapons_base_scale = _primary_weapon.scale
	if _is_agent_logic_active():
		_primary_weapon.visible = false
		_secondary_weapon.visible = false
		if _agent_weapon_node != null:
			var ag: Dictionary = AgentData.get_agent(archetype_id)
			var bw: Dictionary = ag["base_weapon"]
			_agent_weapon_node.set("weapon_style", str(bw["style"]))
			_agent_weapon_node.set("weapon_color", bw["color"] as Color)
			_agent_weapon_node.visible = (not is_dead) and (str(bw["style"]) != "boxing_glove" or _melee_swing_timer > 0.0)
			_agent_weapon_node.queue_redraw()
		return

	_primary_weapon.visible = true
	if _agent_weapon_node != null:
		_agent_weapon_node.visible = false
	var w: WeaponData = WeaponData.get_weapon(current_weapon_id, weapon_skin_id, m4a1_rail_mod)
	if _weapon_pivot != null:
		_weapon_pivot.scale = Vector2(1.16, 1.16)
	if current_weapon_id == 11:
		_primary_weapon.texture = TEX_FLAMETHROWER
		_primary_weapon.hframes = 1
		_primary_weapon.vframes = 1
		_primary_weapon.frame = 0
		_primary_weapon.position = Vector2(16, 0)
		_primary_weapon.scale = Vector2(0.165, 0.165)
		_secondary_weapon.visible = false
		_sync_muzzle_positions(aim_angle)
		return
	if current_weapon_id == 15:
		_primary_weapon.texture = TEX_HOOK_GUN
		_primary_weapon.hframes = 1
		_primary_weapon.vframes = 1
		_primary_weapon.frame = 0
		_primary_weapon.position = Vector2(16, 0)
		_primary_weapon.scale = Vector2(0.24, 0.24)
		_secondary_weapon.visible = false
		_sync_muzzle_positions(aim_angle)
		return
	if current_weapon_id == 16:
		_primary_weapon.texture = TEX_BUBBLE_GUN
		_primary_weapon.hframes = 1
		_primary_weapon.vframes = 1
		_primary_weapon.frame = 0
		_primary_weapon.position = Vector2(16, 0)
		_primary_weapon.scale = Vector2(0.24, 0.24)
		_secondary_weapon.visible = false
		_sync_muzzle_positions(aim_angle)
		return
	if current_weapon_id == 17:
		_primary_weapon.texture = TEX_MACHINE_GUN
		_primary_weapon.hframes = 1
		_primary_weapon.vframes = 1
		_primary_weapon.frame = 0
		_primary_weapon.position = Vector2(18, 0)
		_primary_weapon.scale = Vector2(0.27, 0.27)
		_secondary_weapon.visible = false
		_sync_muzzle_positions(aim_angle)
		return
	if current_weapon_id == 13:
		_primary_weapon.texture = TEX_PLASMA_CANNON
		_primary_weapon.hframes = 1
		_primary_weapon.vframes = 1
		_primary_weapon.frame = 0
		_primary_weapon.position = Vector2(16, 0)
		_primary_weapon.scale = Vector2(0.24, 0.24)
		_secondary_weapon.visible = false
		_sync_muzzle_positions(aim_angle)
		return
	if _weapons_sheet_tex != null and _primary_weapon.texture != _weapons_sheet_tex:
		_primary_weapon.texture = _weapons_sheet_tex
		_primary_weapon.hframes = 11
		_primary_weapon.vframes = 3
	_primary_weapon.position = Vector2(16, 0)
	_primary_weapon.scale = Vector2(0.24, 0.24)
	_secondary_weapon.position = Vector2(12, 4)
	_secondary_weapon.scale = Vector2(0.225, 0.225)
	var sheet_frame: int = clampi(weapon_skin_id, 0, 2) * 11 + w.sprite_frame
	_primary_weapon.frame = sheet_frame
	_secondary_weapon.frame = sheet_frame
	_secondary_weapon.visible = false
	_sync_muzzle_positions(aim_angle)


static func get_weapon_muzzle_local_pos(weapon_id: int, sprite_frame: int = -1) -> Vector2:
	match weapon_id:
		11: return Vector2(43.2, -4.0) # Flamethrower
		13: return Vector2(41.9, -2.5) # Plasma Cannon
		15: return Vector2(42.4, -4.7) # Hook Gun
		16: return Vector2(37.6, -1.7) # Bubble Gun
		17: return Vector2(49.5, -5.1) # Machine Gun
	var f: int = sprite_frame if sprite_frame >= 0 else clampi(weapon_id, 0, 10)
	match f % 11:
		0: return Vector2(44.1, -5.2) # AK-47
		1: return Vector2(44.1, -1.9) # M4A1
		2: return Vector2(44.1, -1.3) # SCAR-H
		3: return Vector2(40.2, 0.6)  # MP5 / SMG
		4: return Vector2(38.1, -5.7) # Vector / Deagle
		5: return Vector2(44.1, -4.5) # SPAS-12 Shotgun
		6: return Vector2(43.8, -4.9) # Remington 870
		7: return Vector2(44.1, -1.5) # AWM Sniper
		8: return Vector2(44.1, -1.6) # SVD Auto-Sniper
		9: return Vector2(30.0, -7.5) # Glock 17 / Pistol
		10: return Vector2(44.1, -2.1) # RPG-7 Bazooka
	return Vector2(44.0, -3.0)


func _sync_muzzle_positions(ref_aim_angle: float) -> void:
	if _muzzle_primary == null or _muzzle_secondary == null or _muzzle_flash == null:
		return
	var spr_f: int = _weapon.sprite_frame if _weapon != null else clampi(current_weapon_id, 0, 10)
	var base_muz: Vector2 = get_weapon_muzzle_local_pos(current_weapon_id, spr_f)
	var flip_gun: bool = cos(ref_aim_angle) < 0.0
	var muz_y: float = -base_muz.y if flip_gun else base_muz.y
	_muzzle_primary.position = Vector2(base_muz.x, muz_y)
	_muzzle_flash.position = Vector2(base_muz.x + 2.0, muz_y)
	_muzzle_flash.flip_v = flip_gun
	var sec_ratio: float = 0.225 / 0.24
	var sec_x: float = 12.0 + (base_muz.x - 16.0) * sec_ratio
	var sec_dy: float = base_muz.y * sec_ratio
	_muzzle_secondary.position = Vector2(sec_x, 4.0 + (-sec_dy if flip_gun else sec_dy))


func can_grab_throwable() -> bool:
	return NetworkManager.is_agent_clash_mode() and grabbed_player_id == 0 and carried_by_peer_id == 0 and held_throwable_id < 0 and held_throwables.is_empty() and not is_dead


func apply_pickup(pickup_type: String, value: int) -> void:
	if is_dead:
		return
	if pickup_type == "health":
		health = mini(max_health, health + value)
		if health >= max_health:
			_damage_by_attacker.clear()
		if is_local_human:
			health_changed.emit(health, max_health)
	elif pickup_type == "throwable":
		if NetworkManager.is_agent_clash_mode() and held_throwable_id < 0 and held_throwables.is_empty():
			var item_id: int = clampi(value, 0, AgentData.THROWABLE_ITEMS.size() - 1)
			held_throwables.append(item_id)
			held_throwable_id = held_throwables.back()
			if is_local_human:
				agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
	elif pickup_type == "weapon":
		if not NetworkManager.is_agent_clash_mode():
			var new_w_id: int = WeaponData.sanitize_weapon_id(value)
			var picked_w: WeaponData = WeaponData.get_weapon(new_w_id, weapon_skin_id, m4a1_rail_mod)
			var pickup_res: int = 3 if (new_w_id == 10 or new_w_id == 12) else picked_w.mag_size
			if _is_using_secondary_slot():
				if new_w_id == secondary_weapon_id:
					_secondary_saved_ammo = picked_w.mag_size
					_secondary_reserve_ammo = -1 if (new_w_id == _original_secondary_id) else pickup_res
					current_ammo = picked_w.mag_size
					is_reloading = false
					_emit_ammo()
				else:
					secondary_weapon_id = new_w_id
					_secondary_reserve_ammo = -1 if (new_w_id == _original_secondary_id) else pickup_res
					_secondary_saved_ammo = picked_w.mag_size
					set_weapon(secondary_weapon_id)
			elif new_w_id == _equipped_primary_id:
				_primary_saved_ammo = picked_w.mag_size
				_primary_reserve_ammo = -1 if (new_w_id == primary_weapon_id) else pickup_res
				current_ammo = picked_w.mag_size
				is_reloading = false
				_emit_ammo()
			else:
				_equipped_primary_id = new_w_id
				_primary_reserve_ammo = -1 if (new_w_id == primary_weapon_id) else pickup_res
				_primary_saved_ammo = picked_w.mag_size
				set_weapon(_equipped_primary_id)
			if NetworkManager.allow_explosives and bomb_count < max_bombs:
				bomb_count = mini(max_bombs, bomb_count + 1)
				if is_local_human:
					bombs_changed.emit(bomb_count, bomb_type)
			_spawn_pickup_name_popup(picked_w.display_name)
	_play_local_sfx("res://assets/audio/pickup.wav", -2.0)


func _spawn_pickup_name_popup(gun_name: String) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null or gun_name.is_empty():
		return
	var lbl := Label.new()
	lbl.text = gun_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(160.0, 26.0)
	lbl.global_position = global_position + Vector2(-80.0, -78.0)
	lbl.z_index = 45
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.modulate = Color(0.45, 1.0, 0.65)
	parent_node.add_child(lbl)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 22.0, 1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tw.finished.connect(lbl.queue_free)


func set_nearby_weapon(crate_idx: int, w_id: int) -> void:
	if nearby_weapon_crate == crate_idx and nearby_weapon_id == w_id:
		return
	nearby_weapon_crate = crate_idx
	nearby_weapon_id = w_id
	if is_local_human:
		nearby_weapon_changed.emit(crate_idx, w_id)


func set_nearby_interactable(inter_idx: int, label_text: String) -> void:
	nearby_interactable_idx = inter_idx
	if is_local_human:
		nearby_interactable_changed.emit(inter_idx, label_text)


func set_held_prop(prop_kind: String) -> void:
	held_prop_kind = prop_kind
	if is_local_human:
		held_prop_changed.emit(prop_kind)


func throw_held_prop() -> void:
	if held_prop_kind.is_empty() or is_dead:
		return
	var kind: String = held_prop_kind
	set_held_prop("")
	var aim_dir: Vector2 = Vector2.from_angle(aim_angle)
	var spawn_pos: Vector2 = global_position + aim_dir * 26.0 + Vector2(0, -8.0)
	var vel: Vector2 = aim_dir.normalized() * 760.0 + Vector2(0, -120.0)
	if NetworkManager.is_network_active():
		throw_held_prop_rpc.rpc(kind, spawn_pos, vel)
	else:
		_throw_held_prop_local(kind, spawn_pos, vel)


@rpc("any_peer", "call_local", "reliable")
func throw_held_prop_rpc(kind: String, spawn_pos: Vector2, vel: Vector2) -> void:
	_throw_held_prop_local(kind, spawn_pos, vel)


func _throw_held_prop_local(kind: String, spawn_pos: Vector2, vel: Vector2) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var b := BULLET_SCENE.instantiate()
	b.global_position = spawn_pos
	b.velocity = vel
	b.damage = 38
	b.shooter_peer_id = peer_id
	b.shooter_team = team_id
	b.shooter_name = player_name
	b.shooter_rid = get_rid()
	b.weapon_name = kind.replace("_", " ").capitalize()
	b.bullet_color = Color(0.95, 0.85, 0.55)
	b.visual_style = "prop_" + kind
	if kind == "barrel":
		b.is_explosive = true
		b.explosion_radius = 150.0
		b.damage = 120
		b.bullet_color = Color(1.0, 0.45, 0.14)
	b.spin_speed = 9.5
	b.gravity_mult = 0.58
	b.knockback_mult = 1.65
	b.max_lifetime = 2.2
	b.can_deal_damage = _is_controlled_locally()
	parent_node.add_child(b)
	_play_local_sfx("res://assets/audio/pickup.wav", 2.0, 0.72)


func apply_hit(dmg: int, attacker_id: int, weapon_name: String, attacker_name: String, knockback: Vector2) -> void:
	if is_dead or (spawn_invuln_timer > 0.0 and not AgentData.is_ultimate_weapon_name(weapon_name)):
		return
	if NetworkManager.is_network_active():
		request_damage_rpc.rpc(dmg, attacker_id, weapon_name, attacker_name, knockback)
	else:
		_receive_damage_local(dmg, attacker_id, weapon_name, attacker_name, knockback)


@rpc("any_peer", "call_local", "reliable")
func request_damage_rpc(dmg: int, attacker_id: int, weapon_name: String, attacker_name: String, knockback: Vector2) -> void:
	_receive_damage_local(dmg, attacker_id, weapon_name, attacker_name, knockback)


func _is_agent_logic_active() -> bool:
	return is_preview_dummy or NetworkManager.is_agent_clash_mode()


func _receive_damage_local(dmg: int, attacker_id: int, weapon_name: String, attacker_name: String, knockback: Vector2) -> void:
	if is_dead or (spawn_invuln_timer > 0.0 and not AgentData.is_ultimate_weapon_name(weapon_name)):
		return
	if _is_agent_logic_active():
		if attacker_id == peer_id and weapon_name != "Explosive Barrel":
			return
		if invincible_timer > 0.0 or deathless_timer > 0.0 or (invis_timer > 0.0 and str(AgentData.get_agent(archetype_id).get("agent_name", "")) == "Soulless"):
			return
		if personal_shield_hp > 0 and personal_shield_timer > 0.0:
			var absorbed: int = mini(personal_shield_hp, dmg)
			personal_shield_hp -= absorbed
			dmg -= absorbed
			if dmg <= 0:
				_play_local_sfx("res://assets/audio/hit.wav", -5.0, 1.5)
				return
		if damage_reduction_timer > 0.0:
			dmg = maxi(1, int(round(float(dmg) * 0.5)))
	_hit_flash_timer = 0.12
	_play_local_sfx("res://assets/audio/hit.wav", -3.0)
	if SettingsManager.enhanced_visuals:
		add_screen_shake(clampf(float(dmg) * 0.03, 0.35, 1.35))
	if SettingsManager.show_blood:
		_spawn_blood_splatter()
	if SettingsManager.damage_display:
		_spawn_damage_popup(dmg)

	if not _is_controlled_locally():
		return

	velocity += knockback
	if attacker_id != 0 and attacker_id != peer_id and deathless_timer <= 0.0:
		var dealt_hp: int = mini(health, dmg)
		if dealt_hp > 0:
			_damage_by_attacker[attacker_id] = int(_damage_by_attacker.get(attacker_id, 0)) + dealt_hp
	if deathless_timer > 0.0:
		health = maxi(1, health - dmg)
	else:
		health = maxi(0, health - dmg)
	if is_local_human:
		health_changed.emit(health, max_health)

	if health <= 0:
		_trigger_death(attacker_id, weapon_name, attacker_name)


func _trigger_death(attacker_id: int, weapon_name: String, attacker_name: String) -> void:
	if is_dead:
		return
	is_dead = true
	is_jetpacking = false
	is_reloading = false
	stun_timer = 0.0
	invis_timer = 0.0
	speed_boost_timer = 0.0
	speed_boost_mult = 1.0
	nyx_frenzy_timer = 0.0
	control_lock_timer = 0.0
	freeze_timer = 0.0
	ability_lock_timer = 0.0
	flashbang_timer = 0.0
	invincible_timer = 0.0
	damage_reduction_timer = 0.0
	slow_mo_timer = 0.0
	time_stop_timer = 0.0
	touch_teleport_timer = 0.0
	touch_fire_timer = 0.0
	touch_banish_timer = 0.0
	bubble_trap_timer = 0.0
	bubble_trap_hp = 0
	bubble_trap_lock_timer = 0.0
	deathless_timer = 0.0
	zoom_out_timer = 0.0
	gradual_heal_timer = 0.0
	boar_ride_timer = 0.0
	dual_shotgun_timer = 0.0
	dual_shotgun_shots = 0
	auto_mg_timer = 0.0
	electric_laser_timer = 0.0
	personal_shield_hp = 0
	personal_shield_timer = 0.0
	queue_redraw()
	slippery_timer = 0.0
	earth_shake_timer = 0.0
	poison_dot_timer = 0.0
	cryo_shatter_timer = 0.0
	_fly_kick_timer = 0.0
	_spear_timer = 0.0
	_contra_ult_shots_left = 0
	_contra_ult_shot_timer = 0.0
	_magnet_timer = 0.0
	_flurry_state = 0
	_flurry_timer = 0.0
	_flurry_target = null
	_release_grab_state()
	_respawn_timer = RESPAWN_TIME
	var assist_ids: Array = []
	var assist_threshold: float = maxf(1.0, float(max_health) * 0.15)
	for raw_att in _damage_by_attacker.keys():
		var att_id: int = int(raw_att)
		if att_id != attacker_id and att_id != peer_id and float(_damage_by_attacker[raw_att]) >= assist_threshold:
			assist_ids.append(att_id)
	_damage_by_attacker.clear()
	NetworkManager.report_kill(attacker_id, peer_id, weapon_name, attacker_name, player_name, assist_ids)

	if NetworkManager.is_network_active():
		announce_death_rpc.rpc()
	else:
		_on_death_visuals()

	if is_local_human:
		died_signal.emit(RESPAWN_TIME)


@rpc("any_peer", "call_local", "reliable")
func announce_death_rpc() -> void:
	_on_death_visuals()


func _on_death_visuals() -> void:
	is_dead = true
	health = 0
	_weapon_pivot.visible = false
	if is_instance_valid(_modular_rig):
		_modular_rig.stop_shoe_throw()
	_jetpack_particles.emitting = false
	_update_overhead_ui()
	var parent_node: Node = get_parent()
	if parent_node != null:
		var exp := EXPLOSION_SCENE.instantiate()
		exp.global_position = global_position
		exp.explosion_radius = 65.0
		exp.max_damage = 0
		exp.can_deal_damage = false
		parent_node.add_child(exp)
		_spawn_rising_soul(parent_node, global_position)


func _spawn_rising_soul(parent_node: Node, pos: Vector2) -> void:
	var soul := Sprite2D.new()
	soul.texture = TEX_SOUL_GHOST
	var start_pos: Vector2 = pos + Vector2(0.0, -16.0)
	soul.global_position = start_pos
	soul.scale = Vector2(1.15, 1.15)
	soul.z_index = 26
	soul.modulate = Color(1.0, 1.0, 1.0, 0.94)
	parent_node.add_child(soul)
	var tw := soul.create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(soul):
			return
		var wave_x: float = sin(t * TAU * 1.5) * 20.0
		var rise_y: float = -112.0 * (1.0 - pow(1.0 - t, 1.6))
		soul.global_position = start_pos + Vector2(wave_x, rise_y)
		soul.rotation = cos(t * TAU * 1.5) * 0.14
		soul.modulate.a = 0.94 * (1.0 - t * t)
	, 0.0, 1.0, 1.0)
	tw.tween_callback(soul.queue_free)


func _respawn_self() -> void:
	var spawn_pos: Vector2 = Vector2(640.0, 320.0)
	if not _spawn_points.is_empty():
		var others: Array[Vector2] = []
		for p in get_tree().get_nodes_in_group("players"):
			if is_instance_valid(p) and p != self and (not p.has_method("is_alive") or p.is_alive()):
				others.append((p as Node2D).global_position)
		if others.is_empty():
			spawn_pos = _spawn_points[randi() % _spawn_points.size()]
		else:
			var best_sp: Vector2 = _spawn_points[0]
			var best_d: float = -1.0
			var space := get_world_2d().direct_space_state
			for sp in _spawn_points:
				for off_x in [0.0, 140.0, -140.0, 280.0, -280.0]:
					var cand: Vector2 = sp + Vector2(off_x, 0.0)
					if absf(off_x) > 1.0:
						var wall_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(sp, cand + Vector2(signf(off_x) * 24.0, 0.0), 1))
						if not wall_hit.is_empty():
							continue
						var floor_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(cand, cand + Vector2(0.0, 64.0), 1))
						if floor_hit.is_empty():
							continue
					var min_d: float = 1e9
					for op in others:
						var d: float = cand.distance_to(op)
						if d < min_d:
							min_d = d
					if min_d > best_d:
						best_d = min_d
						best_sp = cand
			spawn_pos = best_sp
	global_position = spawn_pos
	velocity = Vector2.ZERO
	health = max_health
	_damage_by_attacker.clear()
	jetpack_fuel = MAX_FUEL
	is_dead = false
	is_reloading = false
	stun_timer = 0.0
	invis_timer = 0.0
	speed_boost_timer = 0.0
	speed_boost_mult = 1.0
	nyx_frenzy_timer = 0.0
	control_lock_timer = 0.0
	freeze_timer = 0.0
	ability_lock_timer = 0.0
	flashbang_timer = 0.0
	invincible_timer = 0.0
	damage_reduction_timer = 0.0
	slow_mo_timer = 0.0
	time_stop_timer = 0.0
	touch_teleport_timer = 0.0
	touch_fire_timer = 0.0
	touch_banish_timer = 0.0
	bubble_trap_timer = 0.0
	bubble_trap_hp = 0
	bubble_trap_lock_timer = 0.0
	deathless_timer = 0.0
	zoom_out_timer = 0.0
	gradual_heal_timer = 0.0
	boar_ride_timer = 0.0
	dual_shotgun_timer = 0.0
	dual_shotgun_shots = 0
	auto_mg_timer = 0.0
	electric_laser_timer = 0.0
	personal_shield_hp = 0
	personal_shield_timer = 0.0
	queue_redraw()
	slippery_timer = 0.0
	earth_shake_timer = 0.0
	poison_dot_timer = 0.0
	cryo_shatter_timer = 0.0
	held_throwable_id = -1
	held_throwables.clear()
	shoe_cooldown_timer = 0.0
	_shoe_windup_timer = 0.0
	_fly_kick_timer = 0.0
	_spear_timer = 0.0
	_contra_ult_shots_left = 0
	_contra_ult_shot_timer = 0.0
	_magnet_timer = 0.0
	_flurry_state = 0
	_flurry_timer = 0.0
	_flurry_target = null
	_release_grab_state()
	if NetworkManager.is_unlimited_abilities_active() and not is_bot:
		ult_points = 4
		ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
	else:
		ability_cooldowns[3] = 0.0 if ult_points >= 4 else 1.0
	if NetworkManager.random_guns_mode and not _is_agent_logic_active():
		assign_random_loadout()
	else:
		bomb_count = max_bombs if NetworkManager.allow_explosives else 0
		bomb_inventory.clear()
		if bomb_count > 0:
			bomb_inventory[bomb_type] = bomb_count
		_primary_reserve_ammo = -1
		_secondary_reserve_ammo = -1
		_primary_saved_ammo = -1
		_secondary_saved_ammo = -1
		current_ammo = _weapon.mag_size
	spawn_invuln_timer = SPAWN_INVULN_SEC

	if NetworkManager.is_network_active():
		announce_respawn_rpc.rpc(spawn_pos)
	else:
		_on_respawn_visuals()

	_emit_hud_signals()
	if is_local_human:
		respawned_signal.emit()


@rpc("any_peer", "call_local", "reliable")
func announce_respawn_rpc(spawn_pos: Vector2) -> void:
	global_position = spawn_pos
	_on_respawn_visuals()


func _on_respawn_visuals() -> void:
	is_dead = false
	velocity = Vector2.ZERO
	health = max_health
	_weapon_pivot.visible = true
	_apply_weapon_visuals()
	_update_overhead_ui()


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _sync_net_state_rpc(pos: Vector2, vel: Vector2, ang: float, f_right: bool, jet: bool, crouch: bool, dead: bool, hp: int, frame_idx: int) -> void:
	if _is_controlled_locally():
		return
	global_position = pos
	velocity = vel
	aim_angle = ang
	facing_right = f_right
	is_jetpacking = jet
	is_crouching = crouch
	is_dead = dead
	health = hp
	anim_frame = frame_idx
	_weapon_pivot.visible = not is_dead


func _update_visual_state(delta: float) -> void:
	if _is_controlled_locally():
		if is_dead:
			anim_frame = 7
		elif is_jetpacking or not is_on_floor():
			anim_frame = 5
		elif is_crouching or _fire_anim_timer > 0.0:
			anim_frame = 6
		elif absf(velocity.x) > 25.0:
			var anim_slow: float = 0.20 if slow_mo_timer > 0.0 else 1.0
			_anim_timer += delta * anim_slow * clampf(absf(velocity.x) / 170.0, 0.8, 2.0)
			var run_frames: Array[int] = [2, 3, 4, 3]
			anim_frame = run_frames[int(_anim_timer * 7.0) % run_frames.size()]
		else:
			_anim_timer += delta
			anim_frame = 0 if int(_anim_timer * 2.2) % 2 == 0 else 1

	var target_z: int = (get_index() % 20) * 16
	if z_index != target_z:
		z_index = target_z
	var safe_frame: int = clampi(anim_frame, 0, 7)
	var flip_x: bool = not facing_right

	if _modular_rig != null:
		_modular_rig.set_headless(headless_timer > 0.0 and not is_dead)
		_modular_rig.set_sync_frame(safe_frame, flip_x)
		if NetworkManager.is_team_mode():
			_modular_rig.apply_layer_colors(NetworkManager.get_team_color(team_id), 0.36)
		else:
			_modular_rig.apply_layer_colors(Color.WHITE, 0.0)

	if is_instance_valid(_ice_overlay):
		_ice_overlay.visible = freeze_timer > 0.0 and not is_dead

	if deathless_timer > 0.0 and not is_dead:
		if _deathless_overlay == null:
			_deathless_overlay = StatusAuraOverlay.new()
			_deathless_overlay.aura_color = Color(1.0, 0.14, 0.14)
			add_child(_deathless_overlay)
		_deathless_overlay.visible = true
	elif is_instance_valid(_deathless_overlay):
		_deathless_overlay.visible = false

	if invincible_timer > 0.0 and invis_timer <= 0.0 and not is_dead:
		if _invincible_overlay == null:
			_invincible_overlay = StatusAuraOverlay.new()
			_invincible_overlay.aura_color = Color(0.22, 0.74, 1.0)
			add_child(_invincible_overlay)
		_invincible_overlay.visible = true
	elif is_instance_valid(_invincible_overlay):
		_invincible_overlay.visible = false

	if freeze_timer > 0.0 and not is_dead:
		_modular_rig.modulate = Color(0.42, 0.86, 1.0, 1.0)
		if _ice_overlay == null:
			_ice_overlay = IceBlockOverlay.new()
			add_child(_ice_overlay)
		_ice_overlay.visible = true
	elif deathless_timer > 0.0 and not is_dead:
		var rage_pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
		_modular_rig.modulate = Color(1.85, 0.20 + rage_pulse * 0.14, 0.20 + rage_pulse * 0.14, 1.0)
	elif invincible_timer > 0.0 and not is_dead:
		var inv_pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
		_modular_rig.modulate = Color(0.28 + inv_pulse * 0.14, 0.78 + inv_pulse * 0.14, 1.85, 1.0)
	elif _hit_flash_timer > 0.0:
		_modular_rig.modulate = Color(1.0, 0.35, 0.35, 1.0)
	elif stun_timer > 0.0:
		var stun_pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.035)
		_modular_rig.modulate = Color(0.55 + stun_pulse * 0.45, 0.92, 1.0, 1.0)
	elif speed_boost_timer > 0.0:
		_modular_rig.modulate = Color(0.76, 1.0, 0.84, 1.0)
	elif slow_mo_timer > 0.0 and not is_dead:
		_modular_rig.modulate = Color(1.0, 0.58, 0.88, 1.0)
	elif ability_lock_timer > 0.0 and not is_dead:
		_modular_rig.modulate = Color(0.74, 0.50, 0.96, 1.0)
	elif spawn_invuln_timer > 0.0:
		var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02)
		_modular_rig.modulate = Color(1.0, 1.0, 1.0, pulse)
	else:
		_modular_rig.modulate = Color.WHITE

	if earth_shake_timer > 0.0 and not is_dead and boar_ride_timer <= 0.0:
		_modular_rig.position = Vector2(randf_range(-4.5, 4.5), -16.5 + randf_range(-3.0, 2.5))
	elif boar_ride_timer <= 0.0:
		_modular_rig.position = Vector2(0.0, -16.5)

	if invis_timer > 0.0 and not is_dead:
		var invis_alpha: float = 0.35 if (is_local_human or is_preview_dummy) else 0.0
		_modular_rig.modulate = Color(0.32, 0.78, 1.85, invis_alpha)
		_weapon_pivot.visible = (is_local_human or is_preview_dummy)
		_weapon_pivot.modulate.a = invis_alpha
	else:
		_weapon_pivot.visible = not is_dead
		_weapon_pivot.modulate.a = 1.0
	var active_stance: String = "none" if is_dead else ("throw_bomb" if _bomb_throw_timer > 0.0 else ("rifle" if NetworkManager.is_agent_clash_mode() else ModularCharacter.get_weapon_stance(current_weapon_id)))
	var w_ov: Dictionary = {}
	if is_instance_valid(_modular_rig):
		if NetworkManager.is_agent_clash_mode() and not is_dead:
			if _melee_swing_timer > 0.0 or _fire_anim_timer > 0.0:
				_modular_rig._current_anim = "agent_attack"
			elif _modular_rig._current_anim == "idle":
				_modular_rig._current_anim = "agent_idle"
		var full_ov: Dictionary = ModularCharacter.get_pose_override(_modular_rig._current_part_id, active_stance, _modular_rig._current_anim)
		w_ov = full_ov.get("weapon", {})
	var swing_offset: float = 0.0
	var is_boxing_glove: bool = (_agent_weapon_node != null and str(_agent_weapon_node.get("weapon_style")) == "boxing_glove")
	if NetworkManager.is_agent_clash_mode() and _melee_swing_timer > 0.0:
		var swing_prog: float = 1.0 - (_melee_swing_timer / 0.22)
		if is_boxing_glove:
			_agent_weapon_node.position.x = lerpf(8.0, 24.0, sin(swing_prog * PI))
		else:
			var swing_dir: float = 1.0 if facing_right else -1.0
			swing_offset = lerpf(-0.95, 0.95, swing_prog) * swing_dir
	elif _agent_weapon_node != null:
		_agent_weapon_node.position.x = 0.0
	if _weapon_pivot != null:
		_weapon_pivot.visible = (electric_laser_timer <= 0.0)
	if is_instance_valid(_modular_rig) and _shoe_windup_timer <= 0.0:
		_modular_rig.hands_z_over_weapon = 2
		if is_dead:
			_modular_rig.apply_weapon_arm_pose("none", aim_angle, facing_right, 0.0, -1.0)
		elif _bomb_throw_timer > 0.0:
			var throw_prog: float = clampf(1.0 - (_bomb_throw_timer / 0.26), 0.0, 1.0)
			_modular_rig.apply_weapon_arm_pose("throw_bomb", aim_angle, facing_right, 0.0, throw_prog)
		elif electric_laser_timer > 0.0:
			_modular_rig.apply_weapon_arm_pose("ult_laser", aim_angle, facing_right, 0.0, -1.0)
		elif NetworkManager.is_agent_clash_mode():
			_modular_rig.apply_weapon_arm_pose("rifle", aim_angle + swing_offset, facing_right, _fire_anim_timer, -1.0)
		else:
			_modular_rig.apply_weapon_arm_pose(active_stance, aim_angle, facing_right, _fire_anim_timer, -1.0)

	var def_wy: float = 9.0 if is_crouching else 6.0
	var extra_pose_rot: float = 0.0
	if is_instance_valid(_modular_rig):
		var sock: Dictionary = _modular_rig.get_weapon_socket_transform(active_stance, facing_right, w_ov, def_wy)
		var crouch_y: float = 3.0 if (is_crouching and w_ov.has("y")) else 0.0
		var rig_scale_ratio: float = _modular_rig.scale.x / 0.92
		_weapon_pivot.position = _modular_rig.position + (sock["pos"] as Vector2) * rig_scale_ratio + Vector2(0.0, crouch_y)
		_weapon_pivot.z_index = int(sock["z"])
		if NetworkManager.is_agent_clash_mode():
			extra_pose_rot = float(sock["pose_rot"])
		_weapon_pivot.rotation = aim_angle + swing_offset + extra_pose_rot
	else:
		var w_dir: float = 1.0 if facing_right else -1.0
		var saved_wy: float = float(w_ov.get("y", def_wy)) + (3.0 if (is_crouching and w_ov.has("y")) else 0.0)
		_weapon_pivot.position = Vector2(float(w_ov.get("x", 2.0)) * w_dir, saved_wy)
		_weapon_pivot.z_index = int(w_ov.get("z", 0))
		if NetworkManager.is_agent_clash_mode():
			extra_pose_rot = w_dir * deg_to_rad(float(w_ov.get("rot", 0.0)))
		_weapon_pivot.rotation = aim_angle + swing_offset + extra_pose_rot
	var flip_gun: bool = not facing_right
	_primary_weapon.flip_v = flip_gun
	_secondary_weapon.flip_v = flip_gun
	_sync_muzzle_positions(aim_angle)
	if is_local_human and SettingsManager.sight_laser and not is_dead:
		queue_redraw()
	if _agent_weapon_node != null:
		_agent_weapon_node.scale.y = -1.0 if flip_gun else 1.0
		if _is_agent_logic_active() and is_boxing_glove:
			_agent_weapon_node.visible = _melee_swing_timer > 0.0 and not is_dead

	var p_ratio: float = clampf(SettingsManager.particle_intensity, 0.0, 1.5)
	var target_amt: int = clampi(int(round(24.0 * p_ratio)), 1, 36)
	if _jetpack_particles.amount != target_amt:
		_jetpack_particles.amount = target_amt
	var hide_invis_fx: bool = (invis_timer > 0.0) and (not is_local_human) and (not is_preview_dummy)
	_jetpack_particles.visible = not hide_invis_fx
	_jetpack_particles.modulate.a = clampf(p_ratio, 0.0, 1.0) * (0.35 if invis_timer > 0.0 else 1.0)
	_jetpack_particles.emitting = (not hide_invis_fx) and is_jetpacking and not is_dead and p_ratio > 0.05

	if is_jetpacking and not is_dead:
		if not _jetpack_audio.playing:
			_jetpack_audio.play()
	elif _jetpack_audio.playing:
		_jetpack_audio.stop()


func _apply_team_visuals() -> void:
	var label_col: Color = NetworkManager.get_team_color(team_id if NetworkManager.is_team_mode() else color_index)
	_name_label.modulate = label_col.lightened(0.35)


func _update_overhead_ui() -> void:
	_overhead_ui.visible = (not is_dead) and (invis_timer <= 0.0 or is_local_human)
	var ag_active: bool = _is_agent_logic_active()
	_name_label.visible = SettingsManager.show_callsigns or (ag_active and (stun_timer > 0.0 or ability_lock_timer > 0.0 or carried_by_peer_id != 0 or thrown_flight_timer > 0.0))
	if ag_active and carried_by_peer_id != 0:
		_name_label.text = "GRABBED!"
		_name_label.modulate = Color(1.0, 0.65, 0.22)
	elif ag_active and thrown_flight_timer > 0.0:
		_name_label.text = "THROWN!"
		_name_label.modulate = Color(1.0, 0.42, 0.22)
	elif ag_active and stun_timer > 0.0:
		_name_label.text = "STUNNED %.1fs" % stun_timer
		_name_label.modulate = Color(0.45, 0.95, 1.0)
	elif ag_active and time_stop_timer > 0.0:
		_name_label.visible = true
		_name_label.text = "TIME FROZEN %.1fs" % time_stop_timer
		_name_label.modulate = Color(0.32, 0.78, 1.0)
	elif ag_active and touch_teleport_timer > 0.0 and is_local_human:
		_name_label.visible = true
		_name_label.text = "TAP TO TELEPORT %.1fs" % touch_teleport_timer
		_name_label.modulate = Color(0.32, 0.86, 1.0)
	elif ag_active and touch_fire_timer > 0.0 and is_local_human:
		_name_label.visible = true
		_name_label.text = "TAP ANYWHERE TO BURN %.1fs" % touch_fire_timer
		_name_label.modulate = Color(1.0, 0.45, 0.16)
	elif ag_active and touch_banish_timer > 0.0:
		_name_label.visible = true
		_name_label.text = ("TAP AREA TO BANISH %.1fs" % touch_banish_timer) if is_local_human else ("BANISH TARGETING %.1fs" % touch_banish_timer)
		_name_label.modulate = Color(0.84, 0.52, 1.0)
	elif ag_active and ability_lock_timer > 0.0:
		_name_label.text = "SUPPRESSED %.1fs" % ability_lock_timer
		_name_label.modulate = Color(0.86, 0.42, 1.0)
	else:
		_name_label.text = player_name
		_apply_team_visuals()
	var ratio: float = clampf(float(health) / float(max_health), 0.0, 1.0)
	_health_fill.size.x = 44.0 * ratio
	if ratio > 0.5:
		_health_fill.color = Color(0.25, 0.9, 0.42)
	elif ratio > 0.25:
		_health_fill.color = Color(0.95, 0.72, 0.18)
	else:
		_health_fill.color = Color(0.95, 0.25, 0.25)


func _emit_hud_signals() -> void:
	if not is_local_human:
		return
	health_changed.emit(health, max_health)
	fuel_changed.emit(jetpack_fuel, MAX_FUEL)
	weapon_changed.emit(_weapon)
	_emit_ammo()
	if _is_agent_logic_active():
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
	else:
		bombs_changed.emit(bomb_count, bomb_type)
		zoom_changed.emit(clampi(current_zoom_level, 1, get_max_zoom_level()), get_max_zoom_level())


func _emit_ammo() -> void:
	if is_local_human:
		ammo_changed.emit(current_ammo, _weapon.mag_size, is_reloading)


func _play_local_sfx(path: String, volume_db_offset: float = 0.0, pitch_override: float = 0.0) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream != null and is_instance_valid(_audio_sfx):
		_audio_sfx.stream = stream
		_audio_sfx.volume_db = volume_db_offset
		_audio_sfx.pitch_scale = pitch_override if pitch_override > 0.0 else randf_range(0.94, 1.06)
		_audio_sfx.play()


func is_alive() -> bool:
	return not is_dead


func _compute_bot_input(delta: float) -> Dictionary:
	if is_preview_dummy:
		return {
			"move_x": preview_move_x,
			"jump": preview_jump,
			"crouch": false,
			"jetpack": false,
			"fire": false,
			"aim_angle": 0.0 if peer_id == 901 else PI
		}
	if NetworkManager.is_test_mode():
		var tb: int = NetworkManager.test_bot_behavior
		if tb == 0:
			return {
				"move_x": 0.0,
				"jump": false,
				"crouch": false,
				"jetpack": false,
				"fire": false,
				"aim_angle": aim_angle
			}
		elif tb == 1:
			_bot_think_timer -= delta
			if _bot_think_timer <= 0.0:
				_bot_think_timer = randf_range(1.1, 2.2)
				_bot_strafe_dir = -1.0 if randf() < 0.5 else 1.0
				_bot_want_jetpack = randf() < 0.25
			if is_on_wall():
				_bot_strafe_dir = -_bot_strafe_dir
			var mv: float = _bot_strafe_dir if absf(_bot_strafe_dir) > 0.1 else 1.0
			var jmp: bool = is_on_wall() and is_on_floor()
			var jet: bool = _bot_want_jetpack and jetpack_fuel > 30.0
			return {
				"move_x": mv,
				"jump": jmp,
				"crouch": false,
				"jetpack": jet,
				"fire": false,
				"aim_angle": 0.0 if mv >= 0.0 else PI
			}

	var diff: int = clampi(NetworkManager.bot_difficulty, 0, 2)
	_bot_think_timer -= delta
	var nearest_target: Node2D = null
	var nearest_dist: float = 99999.0

	for node in get_tree().get_nodes_in_group("players"):
		if node == self or not is_instance_valid(node):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		if NetworkManager.is_team_mode() and int(node.get("team_id")) == team_id:
			continue
		if float(node.get("invis_timer")) > 0.0:
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_target = node as Node2D

	if _bot_think_timer <= 0.0:
		if diff == 0:
			_bot_think_timer = randf_range(0.75, 1.35)
			if randf() < 0.25:
				_bot_strafe_dir = -1.0 if randf() < 0.5 else 1.0
			_bot_want_jetpack = randf() < 0.10
			_bot_allow_fire = randf() < 0.42
			_bot_aim_error = randf_range(-0.36, 0.36)
		elif diff == 1:
			_bot_think_timer = randf_range(0.48, 0.90)
			if randf() < 0.30:
				_bot_strafe_dir = -1.0 if randf() < 0.5 else 1.0
			_bot_want_jetpack = randf() < 0.22
			_bot_allow_fire = randf() < 0.68
			_bot_aim_error = randf_range(-0.20, 0.20)
		else:
			_bot_think_timer = randf_range(0.28, 0.65)
			if randf() < 0.35:
				_bot_strafe_dir = -1.0 if randf() < 0.5 else 1.0
			_bot_want_jetpack = randf() < 0.42
			_bot_allow_fire = true
			_bot_aim_error = randf_range(-0.07, 0.07)

	var move_x: float = _bot_strafe_dir
	var want_jump: bool = false
	var want_jet: bool = false
	var want_fire: bool = false
	var desired_angle: float = aim_angle

	var agent_mode: bool = NetworkManager.is_agent_clash_mode()
	var is_melee_agent: bool = false
	if agent_mode:
		var bw: Dictionary = AgentData.get_agent(archetype_id)["base_weapon"]
		is_melee_agent = not bool(bw["ranged"])

	var sight_range: float = 440.0 if diff == 0 else (580.0 if diff == 1 else 760.0)
	var jet_chase_dy: float = -120.0 if diff == 0 else (-80.0 if diff == 1 else -65.0)
	var engage_max: float = 115.0 if is_melee_agent else 360.0
	var engage_min: float = 60.0 if is_melee_agent else 160.0

	if _bot_weapon_pickup_cd > 0.0:
		_bot_weapon_pickup_cd = maxf(0.0, _bot_weapon_pickup_cd - delta)
	if _bot_loot_focus_timer > 0.0:
		_bot_loot_focus_timer = maxf(0.0, _bot_loot_focus_timer - delta)
	var arena_ref: Node = get_parent().get_parent() if get_parent() != null else null
	var has_los_to_enemy: bool = false
	if nearest_target != null and nearest_dist < sight_range:
		var los_space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var los_ray := PhysicsRayQueryParameters2D.create(
			_weapon_pivot.global_position,
			nearest_target.global_position,
			1
		)
		has_los_to_enemy = los_space.intersect_ray(los_ray).is_empty()
	var in_active_fight: bool = (nearest_target != null and nearest_dist < 280.0 and has_los_to_enemy)
	var pickup_obj: Dictionary = {"found": false}
	if arena_ref != null and not is_preview_dummy:
		if arena_ref.has_method("try_bot_interact_nearby"):
			arena_ref.call("try_bot_interact_nearby", self)
		if arena_ref.has_method("get_bot_pickup_target"):
			pickup_obj = arena_ref.call("get_bot_pickup_target", self, 540.0, in_active_fight)

	if nearest_target != null:
		var to_target: Vector2 = nearest_target.global_position - _weapon_pivot.global_position
		var dist: float = to_target.length()
		if diff == 2:
			desired_angle = to_target.angle() + randf_range(-0.07, 0.07)
		elif diff == 1:
			desired_angle = lerp_angle(aim_angle, to_target.angle() + _bot_aim_error, clampf(delta * 6.5, 0.0, 1.0))
		else:
			desired_angle = lerp_angle(aim_angle, to_target.angle() + _bot_aim_error, clampf(delta * 3.5, 0.0, 1.0))

		if dist > engage_max:
			move_x = signf(to_target.x)
		elif dist < engage_min:
			move_x = -signf(to_target.x)

		if to_target.y < jet_chase_dy and jetpack_fuel > 25.0:
			want_jet = true
		elif is_on_wall() and jetpack_fuel > 20.0:
			want_jump = true
			want_jet = true
		elif _bot_want_jetpack and jetpack_fuel > 45.0:
			want_jet = true

		if dist < sight_range and _bot_allow_fire:
			var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
			var ray := PhysicsRayQueryParameters2D.create(
				_weapon_pivot.global_position,
				nearest_target.global_position,
				1
			)
			if space_state.intersect_ray(ray).is_empty():
				if agent_mode:
					aim_angle = desired_angle
					if grabbed_player_id != 0 and stun_timer <= 0.0:
						throw_held_item()
					elif held_throwable_id >= 0 and dist < 520.0 and stun_timer <= 0.0:
						throw_held_item()
					elif held_throwable_id == -1 and grabbed_player_id == 0 and dist < 82.0 and stun_timer <= 0.0 and randf() < 0.08:
						throw_held_item()
					var cast_chance: float = 0.04 if diff == 0 else (0.10 if diff == 1 else 0.20)
					if stun_timer <= 0.0 and randf() < cast_chance:
						for slot_i in [3, 0, 1, 2]:
							if ability_cooldowns[slot_i] <= 0.0:
								use_agent_ability(slot_i)
								break
					want_fire = (not is_melee_agent) or dist < 135.0
				else:
					want_fire = true

	# Steer toward freshly opened treasure loot, or smartly toward nearby orbs / weapons / health
	if bool(pickup_obj.get("found", false)):
		var obj_pos: Vector2 = pickup_obj["pos"] as Vector2
		var to_obj: Vector2 = obj_pos - global_position
		var obj_dist: float = to_obj.length()
		var obj_score: float = float(pickup_obj.get("score", 0.0))
		if obj_score >= 180.0 or not in_active_fight or obj_score >= 88.0:
			if absf(to_obj.x) > 12.0:
				move_x = signf(to_obj.x)
			else:
				move_x = 0.0
			if to_obj.y < -52.0 and jetpack_fuel > 20.0:
				want_jet = true
				if is_on_floor():
					want_jump = true
			elif to_obj.y < -22.0 and is_on_floor() and obj_dist < 160.0:
				want_jump = true

	if is_on_wall() and is_on_floor():
		want_jump = true

	return {
		"move_x": move_x,
		"jump": want_jump,
		"crouch": false,
		"jetpack": want_jet,
		"fire": want_fire,
		"aim_angle": desired_angle
	}


# --- AGENT CLASH MODE ABILITIES, STUN, THROWABLES & BARRIERS ---

func apply_stun(duration: float, attacker_id: int = 0) -> void:
	if not _is_agent_logic_active() or is_dead or duration <= 0.0:
		return
	if attacker_id != 0 and attacker_id == peer_id:
		return
	if NetworkManager.is_network_active():
		sync_stun_rpc.rpc(duration, attacker_id)
	else:
		_apply_stun_local(duration, attacker_id)


@rpc("any_peer", "call_local", "reliable")
func sync_stun_rpc(duration: float, attacker_id: int = 0) -> void:
	_apply_stun_local(duration, attacker_id)


func _apply_stun_local(duration: float, attacker_id: int = 0) -> void:
	if is_dead or invincible_timer > 0.0 or deathless_timer > 0.0 or (attacker_id != 0 and attacker_id == peer_id):
		return
	_fly_kick_timer = 0.0
	_spear_timer = 0.0
	_contra_ult_shots_left = 0
	_contra_ult_shot_timer = 0.0
	_magnet_timer = 0.0
	_flurry_state = 0
	_flurry_timer = 0.0
	_flurry_target = null
	_release_grab_state()
	stun_timer = maxf(stun_timer, duration)
	is_jetpacking = false
	if is_local_human:
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)


func gain_ult_charge(_seconds_reduced: float) -> void:
	pass


func _fire_agent_base_weapon() -> void:
	if dual_shotgun_timer > 0.0 and dual_shotgun_shots > 0:
		dual_shotgun_shots -= 1
		if dual_shotgun_shots <= 0:
			dual_shotgun_timer = 0.0
		_fire_cooldown = 0.28
		_melee_swing_timer = 0.20
		_fire_anim_timer = 0.16
		var safe_ds: Vector2 = _get_safe_muzzle_pos(_muzzle_primary.global_position)
		_cast_gun_burst(safe_ds, aim_angle, 25, 6, 16.0, Color(1.0, 0.55, 0.22), "Dual Shotguns", 0.0, 960.0, _is_controlled_locally(), 0.04)
		_play_local_sfx("res://assets/audio/shoot_shotgun.wav", -3.0)
		return
	var ag: Dictionary = AgentData.get_agent(archetype_id)
	var bw: Dictionary = ag["base_weapon"]
	var cd: float = float(bw["cooldown"])
	if nyx_frenzy_timer > 0.0:
		cd *= 0.50
	elif speed_boost_timer > 0.0:
		cd *= 0.72
	if is_bot:
		var bot_diff: int = clampi(NetworkManager.bot_difficulty, 0, 2)
		cd *= (1.85 if bot_diff == 0 else (1.35 if bot_diff == 1 else 1.0))
	_fire_cooldown = cd
	var is_ranged_bw: bool = bool(bw["ranged"])
	var bw_style: String = str(bw.get("style", "sword"))
	if not is_ranged_bw:
		_melee_swing_timer = 0.22
	_fire_anim_timer = 0.16

	var dmg: int = int(bw["damage"]) * (2 if deathless_timer > 0.0 else 1)
	var col: Color = bw["color"] as Color
	var w_label: String = str(bw["name"])
	if is_ranged_bw:
		var safe_m: Vector2 = _get_safe_muzzle_pos(_muzzle_primary.global_position)
		var proj_style: String = "bullet" if (bw_style == "deagle" or bw_style == "gun") else "arrow"
		var pitch_sfx: float = 0.82 if bw_style == "deagle" else 1.45
		if NetworkManager.is_network_active():
			spawn_agent_base_ranged_rpc.rpc(safe_m, aim_angle, dmg, col, w_label, proj_style, pitch_sfx)
		else:
			_spawn_styled_projectile(safe_m, aim_angle, 1180.0 if proj_style == "bullet" else 1020.0, dmg, proj_style, col, w_label, 0.0, 0.0, false, 60.0, 1.0, false, _is_controlled_locally())
			_play_local_sfx("res://assets/audio/shoot_smg.wav", -4.0 if bw_style == "deagle" else -6.0, pitch_sfx)
	else:
		var reach: float = float(bw["range"])
		if _is_controlled_locally():
			var hit_count: int = _apply_melee_arc(global_position, Vector2.from_angle(aim_angle), reach, 72.0, dmg, 0.0, 220.0, w_label)
			if hit_count > 0:
				gain_ult_charge(1.5 * float(hit_count))
		if NetworkManager.is_network_active():
			spawn_slash_vfx_rpc.rpc(_weapon_pivot.global_position, aim_angle, col)
		else:
			_spawn_styled_projectile(_weapon_pivot.global_position + Vector2.from_angle(aim_angle) * 26.0, aim_angle, 520.0, 0, "slash_wave", col, w_label, 0.0, 0.0, false, 40.0, 1.0, true, false, 0.12, 1.1)
			_play_local_sfx("res://assets/audio/jump.wav", -4.0, 1.5)


@rpc("any_peer", "call_local", "reliable")
func spawn_agent_base_ranged_rpc(origin: Vector2, angle: float, dmg: int, col: Color, w_label: String, proj_style: String = "arrow", pitch_sfx: float = 1.45) -> void:
	_spawn_styled_projectile(origin, angle, 1180.0 if proj_style == "bullet" else 1020.0, dmg, proj_style, col, w_label, 0.0, 0.0, false, 60.0, 1.0, false, _is_controlled_locally())
	_play_local_sfx("res://assets/audio/shoot_smg.wav", -4.0 if proj_style == "bullet" else -6.0, pitch_sfx)


@rpc("any_peer", "call_local", "reliable")
func spawn_slash_vfx_rpc(origin: Vector2, angle: float, col: Color) -> void:
	_spawn_styled_projectile(origin + Vector2.from_angle(angle) * 26.0, angle, 520.0, 0, "slash_wave", col, "Slash", 0.0, 0.0, false, 40.0, 1.0, true, false, 0.12, 1.1)
	_play_local_sfx("res://assets/audio/jump.wav", -4.0, 1.5)


func use_agent_ability(slot_idx: int) -> void:
	if not _is_agent_logic_active() or is_dead or stun_timer > 0.0 or freeze_timer > 0.0 or control_lock_timer > 0.0 or ability_lock_timer > 0.0:
		return
	if slot_idx < 0 or slot_idx > 3 or ability_cooldowns[slot_idx] > 0.0:
		return
	if NetworkManager.is_unlimited_abilities_active() and not is_bot:
		ult_points = 4
		ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
	elif slot_idx == 3:
		if ult_points < 4:
			return
		ult_points = 0
		ability_cooldowns[3] = 1.0
	else:
		ability_cooldowns[slot_idx] = 1.0
	if is_local_human:
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
	if NetworkManager.is_network_active():
		execute_ability_rpc.rpc(slot_idx, global_position, aim_angle)
	else:
		_execute_ability_local(slot_idx, global_position, aim_angle)


@rpc("any_peer", "call_local", "reliable")
func execute_ability_rpc(slot_idx: int, cast_pos: Vector2, cast_angle: float) -> void:
	_execute_ability_local(slot_idx, cast_pos, cast_angle)


func _execute_ability_local(slot_idx: int, cast_pos: Vector2, cast_angle: float) -> void:
	var ab: Dictionary = get_active_ability_slot(slot_idx)
	var kind: String = str(ab.get("kind", "cleave"))
	var dmg: int = int(ab.get("damage", 25))
	var stun_dur: float = float(ab.get("stun", 0.0))
	var col: Color = ab.get("color", Color.WHITE) as Color
	var ab_name: String = str(ab.get("name", "Ability"))
	var p_style: String = str(ab.get("proj_style", "fireball"))
	var origin: Vector2 = cast_pos + Vector2(0.0, 4.0) + Vector2.from_angle(cast_angle) * 28.0
	var local_auth: bool = _is_controlled_locally()
	_fire_anim_timer = 0.22
	_melee_swing_timer = 0.22

	match kind:
		"cleave":
			_cast_cleave_or_giant(origin, cast_angle, dmg, stun_dur, col, ab_name, 1, 0.0, 1.85, local_auth)
			_play_local_sfx("res://assets/audio/shoot_shotgun.wav", -5.0, 1.35)
		"ult_giant_sword":
			_cast_cleave_or_giant(origin, cast_angle, dmg, stun_dur, col, ab_name, 3, 0.20, 2.35, local_auth)
			add_screen_shake(2.2)
			_play_local_sfx("res://assets/audio/explosion.wav", -3.0, 1.15)
		"fireball":
			_cast_fireballs(origin, cast_angle, dmg, stun_dur, col, ab_name, 1, local_auth, p_style)
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -4.0, 1.15)
		"flame_wave":
			var fw_rng := RandomNumberGenerator.new()
			fw_rng.seed = hash(str(peer_id) + "_" + str(int(cast_pos.x)) + "_" + str(int(cast_pos.y)))
			var fwd_sign: float = 1.0 if facing_right else -1.0
			var blast_rad: float = 115.0
			var offsets: Array[Vector2] = [
				Vector2(fwd_sign * fw_rng.randf_range(78.0, 118.0), fw_rng.randf_range(-18.0, 18.0)),
				Vector2(-fwd_sign * fw_rng.randf_range(78.0, 118.0), fw_rng.randf_range(-18.0, 18.0)),
				Vector2(fw_rng.randf_range(-24.0, 24.0), -fw_rng.randf_range(78.0, 118.0)),
			]
			for off_v in offsets:
				var spawn_p: Vector2 = cast_pos + off_v
				_spawn_vfx_burst(spawn_p, blast_rad, col)
				_spawn_rising_particles(spawn_p, col, false, 6)
				if local_auth:
					for p in get_tree().get_nodes_in_group("players"):
						if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
							if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
								continue
							if p.has_method("is_alive") and not p.is_alive():
								continue
							if (p as Node2D).global_position.distance_to(spawn_p) <= blast_rad and p.has_method("apply_hit"):
								var kb: Vector2 = ((p as Node2D).global_position - spawn_p).normalized() * 240.0
								p.apply_hit(dmg, peer_id, ab_name, player_name, kb)
								gain_ult_charge(2.0)
			add_screen_shake(2.0)
			_play_local_sfx("res://assets/audio/explosion.wav", -3.0, 1.15)
		"lava_bomb":
			_cast_lava_bomb(origin, cast_angle, dmg, stun_dur, col, ab_name, local_auth, str(ab.get("proj_style", "fireball")))
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -3.0, 0.95)
		"ult_firestorm":
			_cast_fireballs(origin, cast_angle, dmg, stun_dur, col, ab_name, int(ab.get("shots", 7)), local_auth, p_style)
			add_screen_shake(2.4)
			_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 0.95)
		"ice_shards":
			_cast_multi_proj(origin, cast_angle, dmg, int(ab.get("shots", 4)), 22.0, "ice_shard", col, ab_name, stun_dur, 1080.0, 0.0, false, local_auth, 1.0, 1.2)
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -3.0, 1.45)
		"spear_throw":
			_cast_multi_proj(origin, cast_angle, dmg, int(ab.get("shots", 1)), 0.0, "thrown_spear", col, ab_name, stun_dur, 1140.0, 0.0, false, local_auth, 1.3, 1.4)
			_play_local_sfx("res://assets/audio/jump.wav", -2.0, 0.72)
		"axe_volley":
			_cast_multi_proj(origin, cast_angle, dmg, int(ab.get("shots", 2)), 14.0, "thrown_axe", col, ab_name, stun_dur, 880.0, 18.0, false, local_auth, 1.4, 1.35)
			_play_local_sfx("res://assets/audio/jump.wav", -2.0, 0.78)
		"shuriken_fan":
			_cast_multi_proj(origin, cast_angle, dmg, int(ab.get("shots", 3)), 18.0, "shuriken", col, ab_name, stun_dur, 1120.0, 22.0, false, local_auth, 1.15, 1.25)
			_play_local_sfx("res://assets/audio/shoot_smg.wav", -4.0, 1.65)
		"ghost_wisps":
			_cast_multi_proj(origin, cast_angle, dmg, int(ab.get("shots", 3)), 18.0, "ghost_wisp", col, ab_name, stun_dur, 760.0, 0.0, true, local_auth, 1.45, 1.25)
			_play_local_sfx("res://assets/audio/pickup.wav", -2.0, 0.65)
		"teleport":
			_cast_teleport(cast_pos, cast_angle, 260.0, dmg, stun_dur, col, ab_name, false, local_auth)
			_play_local_sfx("res://assets/audio/pickup.wav", 0.0, 1.4)
		"ult_blink_slash":
			_cast_teleport(cast_pos, cast_angle, 310.0, dmg, stun_dur, col, ab_name, true, local_auth)
			add_screen_shake(2.2)
			_play_local_sfx("res://assets/audio/explosion.wav", -3.0, 1.25)
		"speed":
			speed_boost_timer = float(ab.get("duration", 4.0))
			speed_boost_mult = float(ab.get("speed_mult", 1.8))
			if ab_name == "Feline Haste":
				nyx_frenzy_timer = float(ab.get("duration", 5.0))
			if local_auth:
				health = mini(max_health, health + 15)
				if health >= max_health:
					_damage_by_attacker.clear()
				if is_local_human:
					health_changed.emit(health, max_health)
			_spawn_vfx_burst(cast_pos, 65.0, col)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.25)
		"dash_speed":
			speed_boost_timer = float(ab.get("duration", 3.8))
			speed_boost_mult = float(ab.get("speed_mult", 1.75))
			if ab_name == "Shadow Dash":
				_shadow_dash_timer = 0.24
				_shadow_dash_dir = Vector2.from_angle(cast_angle)
				_shadow_dash_dmg = dmg * (2 if nyx_frenzy_timer > 0.0 else 1)
				_shadow_dash_hit_ids.clear()
				control_lock_timer = 0.24
			else:
				velocity += Vector2.from_angle(cast_angle) * 620.0
				if local_auth and dmg > 0:
					var d_hits: int = _apply_melee_arc(cast_pos, Vector2.from_angle(cast_angle), 130.0, 75.0, dmg, stun_dur, 320.0, ab_name)
					if d_hits > 0:
						gain_ult_charge(2.0 * float(d_hits))
			_spawn_vfx_burst(cast_pos, 75.0, col)
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 1.4)
		"dash_stun":
			velocity += Vector2.from_angle(cast_angle) * 600.0
			_cast_stun_bomb(origin, cast_angle, dmg, stun_dur, col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/explosion.wav", -4.0, 1.35)
		"stun_bolt", "stun_aoe", "stun_bomb":
			# Always throw a visible Stun Bomb along aim that stuns enemies in its landing circle (never stuns self)
			_cast_stun_bomb(origin, cast_angle, dmg, stun_dur, col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 1.15)
		"ult_stun_nova":
			_cast_stun_bomb(origin, cast_angle, dmg, stun_dur, col, ab_name, local_auth, 280.0, 740.0)
			add_screen_shake(2.4)
			_play_local_sfx("res://assets/audio/explosion.wav", -1.0, 0.85)
		"wall":
			_spawn_barrier_wall(cast_pos, cast_angle, int(ab.get("wall_hp", 240)), float(ab.get("duration", 5.5)), col)
			_play_local_sfx("res://assets/audio/pickup.wav", -2.0, 0.72)
		"gun_burst":
			_cast_gun_burst(origin, cast_angle, dmg, int(ab.get("shots", 6)), 7.0, col, ab_name, stun_dur, 1280.0, local_auth)
			_play_local_sfx("res://assets/audio/shoot_m4a1.wav", -3.0)
		"shotgun_blast":
			_cast_gun_burst(origin, cast_angle, maxi(dmg, 20), maxi(int(ab.get("shots", 7)), 7), 14.0, col, ab_name, stun_dur, 920.0, local_auth, 0.24)
			_play_local_sfx("res://assets/audio/shoot_shotgun.wav", -3.0)
		"ult_gun_storm":
			_cast_gun_burst(origin, cast_angle, dmg, int(ab.get("shots", 14)), 14.0, col, ab_name, stun_dur, 1340.0, local_auth)
			add_screen_shake(2.0)
			_play_local_sfx("res://assets/audio/shoot_scar.wav", -2.0, 0.92)
		"raven_swarm":
			_cast_raven_swarm(origin, cast_angle, dmg, col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/pickup.wav", 0.0, 1.35)
		"telekinesis":
			_cast_telekinesis(cast_pos, cast_angle, dmg, col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/jump.wav", 0.0, 0.85)
		"reverse_smoke":
			_cast_reverse_smoke(origin, cast_angle, dmg, float(ab.get("duration", 4.0)), col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -3.0, 1.25)
		"ult_backstab_tp":
			_cast_backstab_teleport(cast_pos, dmg, col, ab_name, local_auth)
			add_screen_shake(2.0)
			_play_local_sfx("res://assets/audio/explosion.wav", -3.0, 1.3)
		"impact_grenade":
			var ig := _spawn_custom_bullet(origin, cast_angle, 740.0, dmg, "grenade", col, ab_name, stun_dur, 1.1, false, 2.2, local_auth)
			if ig != null:
				ig.is_explosive = true
				ig.explosion_radius = 145.0
				ig.radius_scale = 1.25
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -3.0, 1.15)
		"ult_homing_bazooka":
			_contra_ult_dmg = dmg
			_contra_ult_col = col
			_contra_ult_name = ab_name
			_contra_ult_local = local_auth
			_contra_ult_shots_left = 2
			_contra_ult_shot_timer = 0.24
			_fire_contra_ult_missile()
		"hook_drag":
			var hk := _spawn_custom_bullet(origin, cast_angle, 1240.0, dmg, "grapple_hook", col, ab_name, 0.2, 0.0, false, 0.45, local_auth)
			if hk != null:
				hk.on_hit_effect_kind = "hook_drag"
				hk.boomerang_owner = self
			_play_local_sfx("res://assets/audio/jump.wav", -2.0, 1.2)
		"flash_bird":
			_spawn_summon("flash_bird", origin, dmg, 5.0, col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.4)
		"gradual_heal":
			gradual_heal_timer = float(ab.get("duration", 4.0))
			_gradual_heal_accum = 0.0
			_spawn_rising_particles(cast_pos, Color(0.28, 0.98, 0.48), true, 10)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.1)
		"ult_winged_lion":
			var wl := _spawn_summon("winged_lion", origin, dmg, float(ab.get("duration", 4.0)), col, ab_name, local_auth)
			if wl != null:
				wl.flight_dir = Vector2.from_angle(cast_angle)
			add_screen_shake(2.2)
			_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 1.1)
		"dual_shotguns":
			dual_shotgun_timer = float(ab.get("duration", 4.0))
			dual_shotgun_shots = int(ab.get("shots", 5))
			_dual_shotgun_accum = 0.0
			_fire_dual_shotgun_blast()
			_play_local_sfx("res://assets/audio/shoot_shotgun.wav", -2.0, 1.15)
		"sticky_bomb":
			var sb := _spawn_bomb_instance(origin, cast_angle, "sticky", 720.0, dmg, 165.0, col, ab_name, local_auth)
			if sb != null:
				sb.stick_fuse_override = 1.0
				sb.allow_self_damage = false
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -3.0, 1.2)
		"bouncing_chainsaw":
			var cs := _spawn_custom_bullet(origin, cast_angle, 760.0, dmg, "shuriken", col, ab_name, 0.0, 0.0, false, float(ab.get("duration", 5.0)), local_auth)
			if cs != null:
				cs.wall_bounces_left = 10
				cs.spin_speed = 24.0
				cs.radius_scale = 1.45
			_play_local_sfx("res://assets/audio/shoot_smg.wav", -2.0, 0.75)
		"ult_self_blast":
			if local_auth:
				for p in get_tree().get_nodes_in_group("players"):
					if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
						if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
							continue
						if (p as Node2D).global_position.distance_to(cast_pos) <= 270.0 and p.has_method("apply_hit"):
							p.apply_hit(dmg, peer_id, ab_name, player_name, ((p as Node2D).global_position - cast_pos).normalized() * 600.0)
				for b_node in get_tree().get_nodes_in_group("destructible_bombs"):
					if is_instance_valid(b_node) and b_node is Node2D and (b_node as Node2D).global_position.distance_to(cast_pos) <= 270.0:
						var prop_obj: Object = b_node.get_meta("prop_node") if b_node.has_meta("prop_node") else b_node
						if prop_obj.has_method("detonate_barrel"):
							prop_obj.detonate_barrel(peer_id, player_name, team_id)
						elif prop_obj.has_method("on_shot_hit"):
							prop_obj.on_shot_hit(dmg, peer_id)
			_spawn_vfx_burst(cast_pos, 270.0, col)
			add_screen_shake(2.8)
			_play_local_sfx("res://assets/audio/explosion.wav", -1.0, 0.9)
		"push_circle":
			var rad: float = 320.0
			var push_force: float = 1480.0
			var lift_force: float = -420.0
			if local_auth:
				for p in get_tree().get_nodes_in_group("players"):
					if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
						if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
							continue
						if (p as Node2D).global_position.distance_to(cast_pos) <= rad and p.has_method("apply_hit"):
							var push_d: Vector2 = ((p as Node2D).global_position - cast_pos).normalized()
							if push_d.length_squared() < 0.01:
								push_d = Vector2.from_angle(cast_angle)
							p.apply_hit(dmg, peer_id, ab_name, player_name, push_d * push_force + Vector2(0.0, lift_force))
							if stun_dur > 0.0 and p.has_method("apply_stun"):
								p.apply_stun(stun_dur, peer_id)
			_spawn_air_wave_circle(cast_pos, rad, Color(0.55, 0.90, 1.0))
			_play_local_sfx("res://assets/audio/explosion.wav", -3.0, 1.35)
		"scream_wave":
			var sw_rad: float = 340.0
			var sw_half_cone: float = deg_to_rad(48.0)
			if local_auth:
				for p in get_tree().get_nodes_in_group("players"):
					if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
						if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
							continue
						var diff_v: Vector2 = (p as Node2D).global_position - cast_pos
						if diff_v.length() <= sw_rad and absf(wrapf(diff_v.angle() - cast_angle, -PI, PI)) <= sw_half_cone and p.has_method("apply_hit"):
							p.apply_hit(dmg, peer_id, ab_name, player_name, Vector2.ZERO)
							if stun_dur > 0.0 and p.has_method("apply_stun"):
								p.apply_stun(stun_dur, peer_id)
							if p.has_method("apply_status"):
								p.apply_status("earth_shake", minf(stun_dur, 1.5))
							if p.has_method("add_screen_shake"):
								p.add_screen_shake(4.5)
			_spawn_scream_wave_vfx(cast_pos, cast_angle, sw_rad, col)
			add_screen_shake(2.0)
			_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 1.35)
		"ability_lock_smoke":
			var sm := _spawn_custom_bullet(origin, cast_angle, 860.0, dmg, "smoke_orb", col, ab_name, 0.0, 0.0, false, 1.3, local_auth)
			if sm != null:
				sm.status_effect_name = "ability_lock"
				sm.status_effect_dur = float(ab.get("duration", 4.0))
				sm.on_hit_effect_kind = "ability_lock_aoe"
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -3.0, 1.2)
		"ghost_clones":
			var dur_c: float = float(ab.get("duration", 4.0))
			var gc_dmg: int = dmg if dmg > 0 else 50
			var gc1 := _spawn_summon("ghost_clone", cast_pos + Vector2(-46, 0), gc_dmg, dur_c, col, ab_name, local_auth, -1.0)
			if gc1 != null:
				gc1.clone_arch_id = archetype_id
			var gc2 := _spawn_summon("ghost_clone", cast_pos + Vector2(46, 0), gc_dmg, dur_c, col, ab_name, local_auth, 1.0)
			if gc2 != null:
				gc2.clone_arch_id = archetype_id
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.25)
		"ult_ghost_stealth":
			invis_timer = float(ab.get("duration", 7.0))
			invincible_timer = float(ab.get("duration", 7.0))
			_spawn_rising_particles(cast_pos, Color(0.45, 0.85, 1.0), false, 10)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 0.85)
		"freeze_shot":
			var fz := _spawn_custom_bullet(origin, cast_angle, 1020.0, dmg, "ice_shard", col, ab_name, 0.0, 0.0, false, 1.4, local_auth)
			if fz != null:
				fz.status_effect_name = "freeze"
				fz.status_effect_dur = float(ab.get("duration", 3.0))
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 1.35)
		"ice_platform":
			var ib := _spawn_custom_bullet(origin, cast_angle, 880.0, dmg, "ice_shard", col, ab_name, 0.0, 18.0, false, 1.4, local_auth)
			if ib != null:
				ib.on_hit_effect_kind = "ice_platform"
				ib.status_effect_dur = float(ab.get("duration", 5.0))
				ib.radius_scale = 1.4
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 1.1)
		"frost_gas", "poison_gas":
			_spawn_hazard_zone(kind, cast_pos, float(ab.get("duration", 5.0)), 145.0, dmg, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -3.0, 1.3)
		"ult_cryo_shatter":
			var cs_rad: float = 420.0
			_spawn_vfx_burst(cast_pos, cs_rad * 0.35, Color(0.32, 0.84, 1.0, 0.85), true)
			_spawn_rising_particles(cast_pos, Color(0.45, 0.92, 1.0), false, 18)
			_spawn_cryo_wave(cast_pos, cs_rad, local_auth)
			add_screen_shake(1.8)
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -1.0, 0.85)
		"boar_ride":
			boar_ride_timer = float(ab.get("duration", 4.0))
			_boar_hit_cooldowns.clear()
			_spawn_vfx_burst(cast_pos, 75.0, col)
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 0.75)
		"boomerang_axe":
			var spawn_p: Vector2 = cast_pos + Vector2.from_angle(cast_angle) * 320.0
			var bax := _spawn_custom_bullet(spawn_p, cast_angle + PI, 760.0, dmg, "thrown_axe", col, ab_name, 0.0, 0.0, false, 1.4, local_auth)
			if bax != null:
				bax.boomerang_owner = self
				bax.boomerang_return_time = 0.01
				bax.spin_speed = 18.0
				bax.pierce_players = true
				bax.pierce_walls = false
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 0.85)
		"barbarian_squad":
			_spawn_barbarian_squad(origin, cast_angle, dmg, float(ab.get("duration", 6.0)), col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 0.8)
		"ult_earth_quake_zone":
			_spawn_earthquake_wave(cast_pos, 480.0, float(ab.get("duration", 5.0)), dmg, ab_name, local_auth)
			add_screen_shake(2.2)
			_play_local_sfx("res://assets/audio/explosion.wav", -1.0, 0.75)
		"bat_swarm":
			var bat_targets: Array[Node2D] = []
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
						continue
					if p.has_method("is_alive") and not p.is_alive():
						continue
					bat_targets.append(p as Node2D)
			bat_targets.sort_custom(func(a: Node2D, b: Node2D) -> bool:
				return a.global_position.distance_squared_to(cast_pos) < b.global_position.distance_squared_to(cast_pos)
			)
			for bati in range(3):
				var bat_s := _spawn_summon("bat", origin + Vector2(0.0, (float(bati) - 1.0) * 24.0), dmg, 8.0, col, ab_name, local_auth)
				if bat_s != null and not bat_targets.is_empty():
					bat_s.linked_target = bat_targets[bati % bat_targets.size()]
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.35)
		"damage_shield_50":
			damage_reduction_timer = float(ab.get("duration", 5.0))
			for _bb in range(6):
				var bb := _spawn_summon("blood_bubble", cast_pos + Vector2(randf_range(-28.0, 28.0), randf_range(-34.0, 6.0)), 20, 4.5, col, "Blood Bubble", local_auth)
				if bb != null:
					bb.vel = Vector2.from_angle(randf() * TAU) * randf_range(55.0, 95.0)
			_spawn_rising_particles(cast_pos, Color(0.88, 0.16, 0.28), false, 8)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 0.9)
		"blood_beam":
			_cast_beam_attack(origin, cast_angle, 540.0, 26.0, dmg, col, ab_name, 0.35, local_auth)
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 0.9)
		"ult_bat_execute":
			control_lock_timer = 1.0
			_bat_ult_timer = 0.85
			_bat_ult_hit_done = false
			_bat_ult_target = _find_nearest_enemy_player(cast_pos, 520.0)
			_spawn_rising_particles(cast_pos, Color(0.88, 0.16, 0.28), false, 8)
			add_screen_shake(1.8)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.35)
		"jump_kick":
			_fly_kick_timer = 0.36
			var front_x: float = 1.0 if facing_right else -1.0
			if absf(cos(cast_angle)) > 0.25:
				front_x = 1.0 if cos(cast_angle) >= 0.0 else -1.0
			facing_right = front_x >= 0.0
			var kick_tgt: Node2D = null
			var best_kick_d: float = 460.0 * 460.0
			var space_k := get_world_2d().direct_space_state
			for p in get_tree().get_nodes_in_group("players"):
				if not is_instance_valid(p) or int(p.get("peer_id")) == peer_id:
					continue
				if p.has_method("is_alive") and not p.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
					continue
				var p_pos: Vector2 = (p as Node2D).global_position
				if (p_pos.x - cast_pos.x) * front_x < -16.0:
					continue
				if absf(p_pos.y - cast_pos.y) <= 150.0:
					var d_sq: float = p_pos.distance_squared_to(cast_pos)
					if d_sq < best_kick_d:
						var ray_k := PhysicsRayQueryParameters2D.create(cast_pos, p_pos, 1)
						var hit_k := space_k.intersect_ray(ray_k)
						if hit_k.is_empty():
							best_kick_d = d_sq
							kick_tgt = p as Node2D
			_fly_kick_target = kick_tgt
			if kick_tgt != null:
				_fly_kick_dir = (kick_tgt.global_position - cast_pos).normalized()
				aim_angle = _fly_kick_dir.angle()
				facing_right = _fly_kick_dir.x >= 0.0
			else:
				_fly_kick_dir = Vector2(front_x, 0.0)
				aim_angle = 0.0 if front_x >= 0.0 else PI
			_fly_kick_hit_ids.clear()
			control_lock_timer = 0.36
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 1.25)
		"spinning_blade":
			var sb := _spawn_custom_bullet(origin, cast_angle, 135.0, dmg, "big_blade", col, ab_name, 0.0, 0.0, false, float(ab.get("duration", 4.0)), local_auth)
			if sb != null:
				sb.spin_speed = 18.0
				sb.radius_scale = 4.6
			_play_local_sfx("res://assets/audio/jump.wav", -2.0, 0.9)
		"slow_spin_axe":
			var fwd_x: float = 1.0 if cos(cast_angle) >= 0.0 else -1.0
			var tgt_fg: Node2D = null
			var best_fg_sq: float = 520.0 * 520.0
			for p in get_tree().get_nodes_in_group("players"):
				if not is_instance_valid(p) or p == self:
					continue
				if p.has_method("is_alive") and not p.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
					continue
				var dx: float = (p as Node2D).global_position.x - cast_pos.x
				if dx * fwd_x <= 0.0:
					continue
				var d_sq: float = cast_pos.distance_squared_to((p as Node2D).global_position)
				if d_sq < best_fg_sq:
					best_fg_sq = d_sq
					tgt_fg = p as Node2D
			var target_base: Vector2 = tgt_fg.global_position if tgt_fg != null else (cast_pos + Vector2(fwd_x * 220.0, 0.0))
			var drop_pos: Vector2 = target_base + Vector2(0.0, -140.0)
			var space_state_fg: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
			var up_ray := PhysicsRayQueryParameters2D.create(target_base + Vector2(0.0, -16.0), drop_pos + Vector2(0.0, -24.0), 1)
			up_ray.collide_with_areas = false
			up_ray.collide_with_bodies = true
			var up_hit: Dictionary = space_state_fg.intersect_ray(up_ray)
			if not up_hit.is_empty():
				drop_pos.y = maxf(drop_pos.y, up_hit["position"].y + 28.0)
			drop_pos.y = maxf(76.0, drop_pos.y)
			var fg := _spawn_custom_bullet(drop_pos, PI * 0.5, 0.0, 100, "heavy_forge", col, ab_name, 0.0, 2.4, false, 3.5, local_auth)
			if fg != null:
				fg.radius_scale = 2.0
				fg.knockback_mult = 2.5
				fg.pierce_players = true
			_play_local_sfx("res://assets/audio/explosion.wav", -3.0, 0.75)
		"ult_jump_execute":
			control_lock_timer = 0.95
			var fwd_dir: Vector2 = Vector2.from_angle(cast_angle)
			var best_fwd: Node2D = null
			var best_fwd_d2: float = 540.0 * 540.0
			for p in get_tree().get_nodes_in_group("players"):
				if not is_instance_valid(p) or int(p.get("peer_id")) == peer_id:
					continue
				if p.has_method("is_alive") and not p.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
					continue
				var dv: Vector2 = (p as Node2D).global_position - cast_pos
				if dv.length_squared() < best_fwd_d2 and fwd_dir.dot(dv.normalized()) > 0.25:
					best_fwd_d2 = dv.length_squared()
					best_fwd = p as Node2D
			_yagami_ult_target = best_fwd
			_yagami_ult_start = cast_pos
			var raw_end: Vector2 = (best_fwd.global_position + Vector2(-36.0 if cast_pos.x < best_fwd.global_position.x else 36.0, -4.0)) if best_fwd != null else (cast_pos + fwd_dir * 240.0)
			_yagami_ult_end = _clamp_to_arena(raw_end)
			_yagami_ult_timer = 0.55
			_yagami_ult_slashed = false
			_yagami_ult_slash_timer = 0.0
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 0.85)
		"ult_spear_jump":
			var tgt_je: Node2D = _find_nearest_enemy_player(cast_pos, 460.0)
			if tgt_je != null:
				control_lock_timer = 0.72
				var dir_x: float = 1.0 if tgt_je.global_position.x >= cast_pos.x else -1.0
				facing_right = dir_x >= 0.0
				aim_angle = (tgt_je.global_position - cast_pos).angle()
				var start_p: Vector2 = cast_pos
				var land_p: Vector2 = tgt_je.global_position + Vector2(-28.0 * dir_x, -4.0)
				if tgt_je.has_method("apply_stun"):
					tgt_je.apply_stun(0.55, peer_id)
				var parent_n: Node = get_parent()
				if parent_n != null:
					var sp_vfx := SpearImpaleVfx.new()
					sp_vfx.caster = self
					sp_vfx.target_pos = tgt_je.global_position
					sp_vfx.global_position = cast_pos
					parent_n.add_child(sp_vfx)
				var jump_tw := create_tween()
				jump_tw.tween_method(func(t: float):
					if is_instance_valid(self) and not is_dead:
						var arc_y: float = -sin(t * PI) * 82.0
						global_position = start_p.lerp(land_p, t) + Vector2(0.0, arc_y)
						velocity = Vector2.ZERO
						if is_instance_valid(tgt_je):
							aim_angle = (tgt_je.global_position - global_position).angle()
							facing_right = tgt_je.global_position.x >= global_position.x
				, 0.0, 1.0, 0.36)
				jump_tw.finished.connect(func():
					if is_instance_valid(self) and not is_dead:
						_melee_swing_timer = 0.22
						if is_instance_valid(tgt_je) and (not tgt_je.has_method("is_alive") or tgt_je.is_alive()):
							aim_angle = (tgt_je.global_position - global_position).angle()
							if local_auth and tgt_je.has_method("apply_hit"):
								tgt_je.apply_hit(dmg, peer_id, ab_name, player_name, Vector2(dir_x * 220.0, -140.0))
							_spawn_rising_particles(tgt_je.global_position, col, false, 10)
						add_screen_shake(2.4)
						_play_local_sfx("res://assets/audio/hit.wav", 0.0, 0.9)
				)
				_play_local_sfx("res://assets/audio/jump.wav", -1.0, 1.15)
			else:
				control_lock_timer = 0.35
				velocity += Vector2.from_angle(cast_angle) * 680.0
				_play_local_sfx("res://assets/audio/jump.wav", -1.0, 1.15)
		"poison_vomit":
			var vomit_col := Color(0.30, 0.98, 0.22)
			var pv := _spawn_custom_bullet(origin, cast_angle, 780.0, dmg, "acid_glob", vomit_col, ab_name, 0.0, 0.0, false, 1.8, local_auth)
			if pv != null:
				pv.radius_scale = 1.6
				pv.is_explosive = true
				pv.explosion_radius = 95.0
				pv.status_effect_name = "poison"
				pv.status_effect_dur = float(ab.get("duration", 4.0))
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 0.95)
		"poison_shot":
			var ps := _spawn_custom_bullet(origin, cast_angle, 920.0, dmg, "smoke_orb", col, ab_name, 0.0, 0.0, false, 1.4, local_auth)
			if ps != null:
				ps.status_effect_name = "poison"
				ps.status_effect_dur = float(ab.get("duration", 4.0))
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 0.95)
		"jelly_slowmo":
			var jb := _spawn_custom_bullet(origin, cast_angle, 780.0, dmg, "acid_glob", col, ab_name, 0.0, 0.0, false, 1.6, local_auth)
			if jb != null:
				jb.radius_scale = 1.65
				jb.status_effect_name = "slow_mo"
				jb.status_effect_dur = float(ab.get("duration", 4.0))
				jb.on_hit_effect_kind = "jelly_aoe"
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -3.0, 1.2)
		"zombie_dog":
			_spawn_summon("zombie_dog", origin, dmg, float(ab.get("duration", 5.0)), col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/jump.wav", -2.0, 0.85)
		"ult_deathless_2x":
			deathless_timer = float(ab.get("duration", 10.0))
			stun_timer = 0.0
			freeze_timer = 0.0
			ability_lock_timer = 0.0
			slow_mo_timer = 0.0
			time_stop_timer = 0.0
			control_lock_timer = 0.0
			_spawn_vfx_burst(cast_pos, 95.0, col)
			add_screen_shake(2.0)
			_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 0.8)
		"boomerang_sword", "headless_throw":
			var is_head: bool = (kind == "headless_throw")
			var bs := _spawn_custom_bullet(origin, cast_angle, 840.0, dmg, "mummy_head" if is_head else "thrown_spear", col, ab_name, 0.0, 0.0, false, 1.8, local_auth)
			if bs != null:
				bs.boomerang_owner = self
				bs.boomerang_return_time = 0.42
				bs.spin_speed = 14.0 if is_head else 18.0
				bs.pierce_players = true
				bs.pierce_walls = false
				if is_head:
					bs.radius_scale = 1.35
					headless_timer = 1.85
					_headless_proj = bs
			_play_local_sfx("res://assets/audio/jump.wav", -2.0, 1.1)
		"bomb_eagle":
			_spawn_summon("bomb_eagle", cast_pos + Vector2(0, -40), dmg, float(ab.get("duration", 5.0)), col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.1)
		"fiery_hand_beam":
			var fh := _spawn_custom_bullet(origin, cast_angle, 290.0, dmg, "fiery_hand", col, ab_name, 0.35, 0.0, false, float(ab.get("duration", 2.8)), local_auth)
			if fh != null:
				fh.radius_scale = 2.4
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -2.0, 1.0)
		"ult_time_slow":
			var tf_dur: float = float(ab.get("duration", 5.0))
			var tf_radius: float = 460.0
			if local_auth:
				for p in get_tree().get_nodes_in_group("players"):
					if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
						if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
							continue
						if (p as Node2D).global_position.distance_to(cast_pos) <= tf_radius and p.has_method("apply_status"):
							p.apply_status("time_stop", tf_dur)
			_spawn_time_freeze_wave(cast_pos, tf_radius)
			add_screen_shake(1.8)
			_play_local_sfx("res://assets/audio/pickup.wav", 0.0, 0.55)
		"invincible_self":
			invincible_timer = float(ab.get("duration", 3.0))
			_spawn_rising_particles(cast_pos, Color(0.45, 0.88, 1.0), false, 10)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.15)
		"touch_teleport":
			if is_bot or is_preview_dummy:
				var tp_pos: Vector2 = last_world_tap_pos if (is_preview_dummy and has_world_tap) else (cast_pos + Vector2.from_angle(cast_angle) * 260.0)
				_execute_touch_teleport_local(_clamp_to_arena(tp_pos))
			else:
				touch_teleport_timer = float(ab.get("duration", 3.0))
				_spawn_air_wave_circle(cast_pos, 64.0, Color(0.28, 0.78, 1.0))
				_play_local_sfx("res://assets/audio/pickup.wav", -2.0, 1.25)
		"ult_soul_drag":
			_spawn_rising_particles(cast_pos, Color(0.38, 0.88, 1.0), false, 12)
			var tgt_sd: Node2D = _find_nearest_enemy_player(cast_pos, 340.0)
			if tgt_sd != null:
				control_lock_timer = 1.28
				gravity_lock_timer = 1.28
				velocity = Vector2.ZERO
				var dir_x: float = 1.0 if tgt_sd.global_position.x >= cast_pos.x else -1.0
				facing_right = dir_x >= 0.0
				aim_angle = 0.0 if facing_right else PI
				var grab_pos: Vector2 = cast_pos + Vector2(28.0 * dir_x, 0.0)
				if tgt_sd.has_method("apply_stun"):
					tgt_sd.apply_stun(1.25, peer_id)
				if "gravity_lock_timer" in tgt_sd:
					tgt_sd.set("gravity_lock_timer", 1.25)
					tgt_sd.set("velocity", Vector2.ZERO)
				var pull_tw := create_tween()
				pull_tw.tween_property(tgt_sd, "global_position", grab_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				var parent_n: Node = get_parent()
				if parent_n != null:
					var sh_vfx := SoulHarvestVfx.new()
					sh_vfx.caster = self
					sh_vfx.victim = tgt_sd
					sh_vfx.dir_x = dir_x
					sh_vfx.global_position = cast_pos
					parent_n.add_child(sh_vfx)
				var kill_tw := create_tween()
				kill_tw.tween_interval(1.22)
				kill_tw.finished.connect(func():
					if is_instance_valid(tgt_sd) and (not tgt_sd.has_method("is_alive") or tgt_sd.is_alive()):
						if local_auth and tgt_sd.has_method("apply_hit"):
							tgt_sd.apply_hit(dmg, peer_id, ab_name, player_name, Vector2.ZERO)
						_spawn_vfx_burst(tgt_sd.global_position, 95.0, Color(0.35, 0.88, 1.0, 0.90), true)
						_spawn_rising_particles(tgt_sd.global_position, Color(0.45, 0.94, 1.0), false, 14)
						_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 0.75)
				)
				_play_local_sfx("res://assets/audio/pickup.wav", 0.0, 0.75)
			else:
				_spawn_vfx_burst(cast_pos, 90.0, Color(0.35, 0.88, 1.0, 0.90), true)
			add_screen_shake(2.0)
		"shadow_mummy":
			var tgt_sm: Node2D = _find_nearest_enemy_player(cast_pos, 850.0)
			var sm_pos: Vector2 = (tgt_sm.global_position + Vector2(-44.0, 0.0)) if tgt_sm != null else origin
			_spawn_summon("shadow_mummy", sm_pos, dmg, float(ab.get("duration", 5.0)), col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 0.75)
		"throwable_magnet":
			_magnet_anchor = cast_pos
			_magnet_timer = 0.65
			if local_auth:
				for pk in get_tree().get_nodes_in_group("throwable_pickups"):
					if is_instance_valid(pk) and (pk as Node2D).visible:
						var p2 := pk as Node2D
						if p2.global_position.distance_to(cast_pos) <= 680.0:
							p2.global_position = p2.global_position.lerp(cast_pos, 0.35)
			var mag_col := Color(0.28, 0.80, 1.0)
			var parent_mag: Node = get_parent()
			if parent_mag != null:
				var wave := AirWaveCircleVfx.new()
				wave.global_position = cast_pos
				wave.max_radius = 240.0
				wave.wave_color = mag_col
				parent_mag.add_child(wave)
			_spawn_rising_particles(cast_pos, mag_col, false, 12)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.3)
		"ult_death_kiss":
			var dk := _spawn_custom_bullet(origin, cast_angle, 780.0, dmg, "grenade", col, ab_name, 0.0, 0.0, false, 1.4, local_auth)
			if dk != null:
				dk.on_hit_effect_kind = "death_kiss"
				dk.radius_scale = 1.5
				dk.is_homing = true
				dk.homing_turn_rate = 11.0
				dk.homing_y_offset = -18.0
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -2.0, 1.1)
		"auto_machinegun":
			auto_mg_timer = float(ab.get("duration", 5.0))
			_auto_mg_accum = 0.0
			_play_local_sfx("res://assets/audio/shoot_m4a1.wav", -2.0)
		"deploy_turret":
			var tur := _spawn_summon("turret", cast_pos + Vector2(36.0 * (1.0 if facing_right else -1.0), 4.0), dmg, float(ab.get("duration", 5.0)), col, ab_name, local_auth)
			if tur != null:
				tur.hp = 60
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 0.9)
		"equip_shield":
			personal_shield_hp = int(ab.get("wall_hp", 100))
			personal_shield_timer = float(ab.get("duration", 6.0))
			_spawn_rising_particles(cast_pos, Color(0.35, 0.85, 1.0), false, 10)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.0)
		"ult_arm_fireballs":
			_cast_fireballs(origin, cast_angle, dmg, 0.0, col, ab_name, int(ab.get("shots", 5)), local_auth, "fireball")
			add_screen_shake(2.0)
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -2.0, 1.0)
		"snake_trio":
			for si in range(3):
				_spawn_summon("small_snake", origin + Vector2(float(si) * 20.0 * (1.0 if facing_right else -1.0), 0.0), dmg, float(ab.get("duration", 5.0)), col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.2)
		"ult_giant_snake":
			_spawn_summon("giant_snake", origin, dmg, float(ab.get("duration", 4.0)), col, ab_name, local_auth)
			add_screen_shake(2.2)
			_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 1.0)
		"zoom_out_4x":
			zoom_out_timer = float(ab.get("duration", 5.0))
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.3)
		"ult_electric_laser":
			electric_laser_timer = float(ab.get("duration", 10.0))
			_electric_laser_accum = 0.0
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 1.2)
		"twin_fireballs":
			_cast_fireballs(origin, cast_angle, dmg, 0.0, col, ab_name, 2, local_auth, "fireball")
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -2.0, 0.95)
		"dragon_laser":
			if is_bot or is_preview_dummy:
				var tgt_fire: Node2D = _find_nearest_enemy_player(cast_pos, 750.0)
				var fire_spot: Vector2 = tgt_fire.global_position if tgt_fire != null else (cast_pos + Vector2.from_angle(cast_angle) * 180.0)
				_execute_touch_fire_local(_clamp_to_arena(fire_spot))
			else:
				touch_fire_timer = float(ab.get("duration", 4.0))
				_spawn_air_wave_circle(cast_pos, 64.0, Color(1.0, 0.42, 0.14))
				_play_local_sfx("res://assets/audio/pickup.wav", -2.0, 1.25)
		"ult_dragon_strike":
			control_lock_timer = 0.35
			var ds_dir: Vector2 = Vector2.from_angle(cast_angle)
			var ds_spawn: Vector2 = cast_pos + ds_dir * 42.0
			var drg := _spawn_summon("dragon_strike", ds_spawn, dmg, 2.2, col, ab_name, local_auth)
			if drg != null:
				drg.set("flight_dir", ds_dir)
				drg.set("move_dir_x", 1.0 if ds_dir.x >= 0.0 else -1.0)
			add_screen_shake(1.6)
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -1.0, 0.78)
		"banish_enemy":
			if is_bot or is_preview_dummy:
				var tgt_bn: Node2D = _find_nearest_enemy_player(cast_pos, 650.0)
				var zone_center: Vector2 = tgt_bn.global_position if tgt_bn != null else (cast_pos + Vector2.from_angle(cast_angle) * 200.0)
				_spawn_banish_circle_local(_clamp_to_arena(zone_center))
			else:
				touch_banish_timer = 5.0
				_spawn_air_wave_circle(cast_pos, 68.0, Color(0.78, 0.45, 1.0))
				_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 0.8)
		"swap_enemy":
			var tgt_sw: Node2D = _find_nearest_enemy_player(cast_pos, 420.0)
			if tgt_sw != null and absf(tgt_sw.global_position.y - cast_pos.y) <= 110.0:
				var tmp_p: Vector2 = global_position
				global_position = tgt_sw.global_position
				tgt_sw.global_position = tmp_p
				_spawn_rising_particles(global_position, Color(0.30, 0.82, 1.0), false, 14)
				_spawn_rising_particles(tgt_sw.global_position, Color(0.30, 0.82, 1.0), false, 14)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.25)
		"ult_mirror_clone":
			var t_fwd: float = 1.0 if cos(cast_angle) >= 0.0 else -1.0
			var tor := _spawn_summon("tornado", cast_pos + Vector2(t_fwd * 44.0, -24.0), 100, float(ab.get("duration", 6.0)), col, ab_name, local_auth)
			if tor != null:
				tor.move_dir_x = t_fwd
			add_screen_shake(2.0)
			_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 0.8)
		"lava_platform":
			var lp := _spawn_custom_bullet(origin, cast_angle, 880.0, dmg, "fireball", col, ab_name, 0.0, 18.0, false, 1.4, local_auth)
			if lp != null:
				lp.on_hit_effect_kind = "lava_platform"
				lp.status_effect_dur = float(ab.get("duration", 6.0))
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -2.0, 1.0)
		"rolling_fireball":
			var rf := _spawn_custom_bullet(origin, cast_angle, 460.0, dmg, "fireball", col, ab_name, 0.0, 0.85, false, 5.0, local_auth)
			if rf != null:
				rf.radius_scale = 2.0
				rf.wall_bounces_left = 5
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -2.0, 0.8)
		"ult_inferno_ring":
			var tgt_near: Node2D = _find_nearest_enemy_player(cast_pos, 440.0)
			var hook_angle: float = cast_angle
			if tgt_near != null:
				hook_angle = (tgt_near.global_position - cast_pos).angle()
			facing_right = cos(hook_angle) >= 0.0
			aim_angle = hook_angle
			control_lock_timer = maxf(control_lock_timer, 0.25)
			var parent_hook: Node = get_parent()
			if parent_hook != null:
				var gh := InfernoGrappleHook.new()
				gh.caster = self
				gh.cast_pos = cast_pos
				gh.dir = Vector2.from_angle(hook_angle)
				gh.ab_name = ab_name
				gh.local_auth = local_auth
				gh.global_position = cast_pos
				parent_hook.add_child(gh)
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 0.85)
		"meteor_boulder":
			var mb := _spawn_custom_bullet(origin, cast_angle, 560.0, dmg, "thrown_stone", col, ab_name, 0.6, 0.95, false, 5.0, local_auth)
			if mb != null:
				mb.radius_scale = 5.0
				mb.wall_bounces_left = 999
				mb.stop_on_vertical_wall = false
				mb.pierce_players = true
				mb.spin_speed = 8.0
			_play_local_sfx("res://assets/audio/explosion.wav", -3.0, 0.85)
		"piercing_crystal":
			var pc := _spawn_custom_bullet(origin, cast_angle, 560.0, dmg, "ice_shard", col, ab_name, 0.0, 0.0, false, 3.0, local_auth)
			if pc != null:
				pc.pierce_players = true
				pc.radius_scale = 1.4
			_play_local_sfx("res://assets/audio/shoot_vector.wav", -2.0, 1.1)
		"prism_mirror", "mini_prisms":
			_spawn_prism_mirror(float(ab.get("duration", 5.0)), col)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.3)
		"ult_crush_walls":
			var cw_pos: Vector2 = cast_pos + Vector2.from_angle(cast_angle) * 180.0
			_spawn_summon("crush_walls", cw_pos, dmg, 1.2, col, ab_name, local_auth)
			add_screen_shake(2.4)
			_play_local_sfx("res://assets/audio/explosion.wav", -1.0, 0.8)
		"long_spear":
			_cast_beam_attack(origin, cast_angle, 230.0, 22.0, dmg, col, ab_name, 0.25, local_auth)
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 0.85)
		"bee_swarm":
			for bei in range(5):
				_spawn_summon("bee", origin + Vector2(randf_range(-24, 24), randf_range(-24, 24)), dmg, float(ab.get("duration", 7.0)), col, ab_name, local_auth)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.4)
		"boxer_huge_punch":
			if local_auth:
				_apply_melee_arc(cast_pos, Vector2.from_angle(cast_angle), 165.0, 95.0, dmg, stun_dur, 680.0, ab_name)
			var parent_hp: Node = get_parent()
			if parent_hp != null:
				var hf := BoxingFistVfx.new()
				hf.start_pos = cast_pos + Vector2.from_angle(cast_angle) * 20.0
				hf.end_pos = cast_pos + Vector2.from_angle(cast_angle) * 115.0
				hf.fist_angle = cast_angle
				hf.fist_scale = 1.15
				hf.slam_time = 0.14
				hf.global_position = hf.start_pos
				parent_hp.add_child(hf)
			add_screen_shake(1.8)
			_play_local_sfx("res://assets/audio/hit.wav", -1.0, 0.85)
		"running_spear":
			_spear_timer = 0.34
			_spear_dir = Vector2.from_angle(cast_angle)
			_spear_dmg = dmg
			_spear_label = ab_name
			_spear_hit_ids.clear()
			facing_right = _spear_dir.x >= 0.0
			velocity = _spear_dir * 940.0
			_spawn_vfx_burst(cast_pos, 68.0, col, true)
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 0.9)
		"sky_smash_punch":
			var tgt_sp: Node2D = _find_nearest_enemy_player(cast_pos, 540.0)
			var sp_pos: Vector2 = tgt_sp.global_position if tgt_sp != null else (cast_pos + Vector2.from_angle(cast_angle) * 180.0)
			var parent_sp: Node = get_parent()
			if parent_sp != null:
				var sky_fist := BoxingFistVfx.new()
				sky_fist.start_pos = sp_pos + Vector2(0.0, -135.0)
				sky_fist.end_pos = sp_pos + Vector2(0.0, -8.0)
				sky_fist.fist_angle = PI * 0.5
				sky_fist.fist_scale = 1.65
				sky_fist.slam_time = 0.18
				sky_fist.global_position = sky_fist.start_pos
				parent_sp.add_child(sky_fist)
			var smash_tw := create_tween()
			smash_tw.tween_interval(0.18)
			smash_tw.finished.connect(func():
				if is_instance_valid(self):
					var p_node: Node = get_parent()
					if p_node != null:
						var ring := AirWaveCircleVfx.new()
						ring.global_position = sp_pos
						ring.max_radius = 135.0
						ring.wave_color = col
						p_node.add_child(ring)
					if local_auth:
						for p in get_tree().get_nodes_in_group("players"):
							if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
								if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
									continue
								if (p as Node2D).global_position.distance_to(sp_pos) <= 135.0 and p.has_method("apply_hit"):
									p.apply_hit(dmg, peer_id, ab_name, player_name, Vector2(0.0, 420.0))
									if stun_dur > 0.0 and p.has_method("apply_stun"):
										p.apply_stun(stun_dur, peer_id)
					add_screen_shake(2.4)
					_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 0.85)
			)
		"ult_boxer_flurry":
			var tgt_bf: Node2D = null
			var best_bf_d: float = 320.0
			var aim_fwd: Vector2 = Vector2.from_angle(cast_angle)
			var space_bf := get_world_2d().direct_space_state
			for node in get_tree().get_nodes_in_group("players"):
				if not (node is Node2D) or node == self:
					continue
				if node.has_method("is_alive") and not node.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(node.get("team_id")) == team_id:
					continue
				var e_pos: Vector2 = (node as Node2D).global_position
				var delta_v: Vector2 = e_pos - cast_pos
				var dist_v: float = delta_v.length()
				if dist_v > best_bf_d or dist_v < 1.0:
					continue
				# Same floor/elevation band (not above/below floor or roof)
				if absf(delta_v.y) > 95.0:
					continue
				# Must be in front / forward-aimed cone
				if aim_fwd.dot(delta_v / dist_v) < 0.35:
					continue
				# Must have clear line of sight (no wall/floor/roof blocking)
				var rq_bf := PhysicsRayQueryParameters2D.create(cast_pos, e_pos, 1)
				rq_bf.collide_with_areas = false
				rq_bf.collide_with_bodies = true
				if not space_bf.intersect_ray(rq_bf).is_empty():
					continue
				best_bf_d = dist_v
				tgt_bf = node as Node2D
			if tgt_bf != null:
				_flurry_target = tgt_bf
				_flurry_state = 1
				_flurry_timer = 0.55
				_flurry_hit_accum = 0.0
				_flurry_smoke_accum = 0.0
				_flurry_dmg = maxi(200, dmg)
				_flurry_name = ab_name
				_flurry_auth = local_auth
				control_lock_timer = 2.55
				facing_right = tgt_bf.global_position.x >= global_position.x
				aim_angle = (tgt_bf.global_position - global_position).angle()
			else:
				_flurry_state = 0
				_flurry_target = null
				velocity += Vector2.from_angle(cast_angle) * 680.0
				_spawn_vfx_burst(cast_pos + Vector2.from_angle(cast_angle) * 72.0, 95.0, col)
				add_screen_shake(1.8)
			_play_local_sfx("res://assets/audio/jump.wav", -1.0, 1.25)


func apply_reverse_controls(dur: float) -> void:
	if is_dead or spawn_invuln_timer > 0.0:
		return
	if NetworkManager.is_network_active():
		apply_reverse_controls_rpc.rpc(dur)
	else:
		reverse_controls_timer = maxf(reverse_controls_timer, dur)


@rpc("any_peer", "call_local", "reliable")
func apply_reverse_controls_rpc(dur: float) -> void:
	reverse_controls_timer = maxf(reverse_controls_timer, dur)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local_human or is_dead or not NetworkManager.is_agent_clash_mode():
		return
	if event is InputEventScreenTouch and event.pressed:
		last_world_tap_pos = get_canvas_transform().affine_inverse() * event.position
		has_world_tap = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not pointer_over_ui:
			last_world_tap_pos = get_global_mouse_position()
			has_world_tap = true


func start_hook_pull(target_pos: Vector2) -> void:
	if is_dead:
		return
	_hook_pull_target = target_pos
	_hook_pull_timer = clampf(global_position.distance_to(target_pos) / 1250.0 + 0.10, 0.15, 0.70)
	queue_redraw()


func request_hook_pull(target_pos: Vector2) -> void:
	if is_dead or spawn_invuln_timer > 0.0:
		return
	if NetworkManager.is_network_active():
		sync_hook_pull_rpc.rpc(target_pos)
	else:
		start_hook_pull(target_pos)


@rpc("any_peer", "call_local", "reliable")
func sync_hook_pull_rpc(target_pos: Vector2) -> void:
	start_hook_pull(target_pos)


func apply_bubble_trap(dur: float = 10.0, hp: int = 120) -> void:
	if is_dead or spawn_invuln_timer > 0.0:
		return
	if NetworkManager.is_network_active():
		sync_bubble_trap_rpc.rpc(dur, hp)
	else:
		_apply_bubble_trap_local(dur, hp)


@rpc("any_peer", "call_local", "reliable")
func sync_bubble_trap_rpc(dur: float, hp: int) -> void:
	_apply_bubble_trap_local(dur, hp)


func _apply_bubble_trap_local(dur: float, hp: int) -> void:
	if is_dead:
		return
	bubble_trap_timer = dur
	bubble_trap_hp = hp
	bubble_trap_lock_timer = 2.0
	velocity = Vector2(randf_range(-45.0, 45.0), -135.0)
	queue_redraw()


func damage_bubble(dmg: int) -> void:
	if bubble_trap_timer <= 0.0:
		return
	if NetworkManager.is_network_active():
		sync_damage_bubble_rpc.rpc(dmg)
	else:
		_damage_bubble_local(dmg)


@rpc("any_peer", "call_local", "reliable")
func sync_damage_bubble_rpc(dmg: int) -> void:
	_damage_bubble_local(dmg)


func _damage_bubble_local(dmg: int) -> void:
	if bubble_trap_timer <= 0.0:
		return
	if bubble_trap_lock_timer > 0.0:
		bubble_trap_hp = maxi(1, bubble_trap_hp - dmg)
		queue_redraw()
		return
	bubble_trap_hp -= dmg
	if bubble_trap_hp <= 0:
		bubble_trap_timer = 0.0
		bubble_trap_hp = 0
		bubble_trap_lock_timer = 0.0
		_play_local_sfx("res://assets/audio/hit.wav", -4.0)
	queue_redraw()


func apply_status(effect_name: String, dur: float, _extra: float = 0.0) -> void:
	if is_dead or spawn_invuln_timer > 0.0:
		return
	if NetworkManager.is_network_active():
		apply_status_rpc.rpc(effect_name, dur, _extra)
	else:
		_apply_status_local(effect_name, dur, _extra)


@rpc("any_peer", "call_local", "reliable")
func apply_status_rpc(effect_name: String, dur: float, _extra: float = 0.0) -> void:
	_apply_status_local(effect_name, dur, _extra)


func _apply_status_local(effect_name: String, dur: float, _extra: float = 0.0) -> void:
	if invincible_timer > 0.0 or deathless_timer > 0.0:
		return
	match effect_name:
		"freeze":
			freeze_timer = maxf(freeze_timer, dur)
		"ability_lock":
			ability_lock_timer = maxf(ability_lock_timer, dur)
		"flashbang":
			flashbang_timer = maxf(flashbang_timer, dur)
		"slow_mo":
			slow_mo_timer = maxf(slow_mo_timer, dur)
		"time_stop":
			time_stop_timer = maxf(time_stop_timer, dur)
			velocity = Vector2.ZERO
			is_jetpacking = false
		"slippery":
			slippery_timer = maxf(slippery_timer, dur)
		"earth_shake":
			earth_shake_timer = maxf(earth_shake_timer, dur)
		"reverse_controls":
			reverse_controls_timer = maxf(reverse_controls_timer, dur)
		"stun":
			stun_timer = maxf(stun_timer, dur)
		"poison":
			poison_dot_timer = maxf(poison_dot_timer, dur)
			_poison_dot_accum = 0.0
			_poison_attacker_id = int(_extra)
			var patt := _find_player_by_peer_id(_poison_attacker_id)
			_poison_attacker_name = str(patt.get("player_name")) if patt != null else "Dead Buddy"
		"cryo_shatter":
			cryo_shatter_timer = maxf(cryo_shatter_timer, dur)
			_cryo_shatter_accum = 0.0
			_cryo_attacker_id = int(_extra)
			var att := _find_player_by_peer_id(_cryo_attacker_id)
			_cryo_attacker_name = str(att.get("player_name")) if att != null else "Rook Frost"


func _tick_agent_buffs_and_dots(delta: float) -> void:
	if gradual_heal_timer > 0.0:
		gradual_heal_timer = maxf(0.0, gradual_heal_timer - delta)
		_gradual_heal_accum += delta
		if _gradual_heal_accum >= 0.2:
			_gradual_heal_accum = 0.0
			health = mini(max_health, health + 5)
			if health >= max_health:
				_damage_by_attacker.clear()
			_spawn_rising_particles(global_position, Color(0.28, 0.98, 0.48), true, 3)
			if is_local_human:
				health_changed.emit(health, max_health)
	if dual_shotgun_timer > 0.0:
		dual_shotgun_timer = maxf(0.0, dual_shotgun_timer - delta)
		_update_dual_shotgun_visuals(true)
		_dual_shotgun_accum += delta
		if _dual_shotgun_accum >= 0.48 and dual_shotgun_shots > 0:
			_dual_shotgun_accum = 0.0
			_fire_dual_shotgun_blast()
		if dual_shotgun_timer <= 0.0 or dual_shotgun_shots <= 0:
			dual_shotgun_timer = 0.0
			dual_shotgun_shots = 0
			_update_dual_shotgun_visuals(false)
	else:
		_update_dual_shotgun_visuals(false)
	if personal_shield_timer > 0.0:
		personal_shield_timer = maxf(0.0, personal_shield_timer - delta)
		if personal_shield_timer <= 0.0:
			personal_shield_hp = 0
		queue_redraw()
	if _flurry_state == 1:
		_flurry_timer = maxf(0.0, _flurry_timer - delta)
		if not is_instance_valid(_flurry_target) or (_flurry_target.has_method("is_alive") and not _flurry_target.is_alive()):
			_flurry_state = 0
			_flurry_target = null
			control_lock_timer = 0.0
		else:
			var to_f: Vector2 = _flurry_target.global_position - global_position
			var dist_f: float = to_f.length()
			if dist_f <= 58.0:
				_flurry_state = 2
				_flurry_timer = 2.0
				_flurry_hit_accum = 0.0
				_flurry_smoke_accum = 0.0
				control_lock_timer = 2.0
				if _flurry_auth and _flurry_target.has_method("apply_stun"):
					_flurry_target.apply_stun(2.1, peer_id)
				_spawn_flurry_dust_puff(_flurry_target.global_position)
			elif _flurry_timer <= 0.0:
				_flurry_state = 0
				_flurry_target = null
				control_lock_timer = 0.0
			else:
				var rush_dir: Vector2 = to_f / maxf(1.0, dist_f)
				velocity = rush_dir * 1350.0
				facing_right = rush_dir.x >= 0.0
				aim_angle = rush_dir.angle()
				move_and_slide()
				_spawn_rising_particles(global_position, Color(0.95, 0.85, 0.65, 0.7), false, 2)
	elif _flurry_state == 2:
		_flurry_timer = maxf(0.0, _flurry_timer - delta)
		_flurry_hit_accum += delta
		_flurry_smoke_accum += delta
		if not is_instance_valid(_flurry_target) or (_flurry_target.has_method("is_alive") and not _flurry_target.is_alive()):
			_flurry_state = 0
			_flurry_target = null
			control_lock_timer = 0.0
		else:
			var tgt_p: Vector2 = _flurry_target.global_position
			var osc: float = sin(_flurry_timer * 26.0) * 20.0
			global_position = tgt_p + Vector2(-24.0 + osc if osc >= 0.0 else 24.0 + osc, -2.0)
			velocity = Vector2.ZERO
			facing_right = global_position.x <= tgt_p.x
			aim_angle = 0.0 if facing_right else PI
			_melee_swing_timer = 0.14
			if _flurry_smoke_accum >= 0.12:
				_flurry_smoke_accum = 0.0
				_spawn_flurry_dust_puff(tgt_p)
			if _flurry_hit_accum >= 0.28:
				_flurry_hit_accum = 0.0
				add_screen_shake(0.8)
				_play_local_sfx("res://assets/audio/hit.wav", -3.0, randf_range(0.95, 1.25))
				if _flurry_auth and _flurry_target.has_method("apply_hit"):
					_flurry_target.apply_hit(8, peer_id, _flurry_name, player_name, Vector2.ZERO)
			if _flurry_timer <= 0.0:
				_flurry_state = 0
				control_lock_timer = 0.0
				var fin_dir: float = 1.0 if facing_right else -1.0
				_spawn_vfx_burst(tgt_p, 130.0, Color(1.0, 0.68, 0.22))
				add_screen_shake(3.0)
				_play_local_sfx("res://assets/audio/explosion.wav", -1.0, 1.05)
				if _flurry_auth and is_instance_valid(_flurry_target) and _flurry_target.has_method("apply_hit"):
					_flurry_target.apply_hit(_flurry_dmg, peer_id, _flurry_name, player_name, Vector2(fin_dir * 520.0, -260.0))
				_flurry_target = null

	if _bat_ult_timer > 0.0:
		_bat_ult_timer = maxf(0.0, _bat_ult_timer - delta)
		if _bat_ult_sprite == null:
			_bat_ult_sprite = Sprite2D.new()
			_bat_ult_sprite.texture = TEX_VAMPIRE_BAT
			_bat_ult_sprite.scale = Vector2(0.76, 0.76)
			_bat_ult_sprite.z_index = 6
			_bat_ult_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(_bat_ult_sprite)
		if is_instance_valid(_modular_rig):
			_modular_rig.visible = false
		_bat_ult_sprite.visible = true
		var flap: float = sin(Time.get_ticks_msec() * 0.025)
		_bat_ult_sprite.scale = Vector2(0.76 + flap * 0.06, 0.76 - flap * 0.08)
		var move_v: Vector2 = Vector2.from_angle(aim_angle) * 780.0
		if is_instance_valid(_bat_ult_target) and (not _bat_ult_target.has_method("is_alive") or _bat_ult_target.is_alive()):
			var to_t: Vector2 = _bat_ult_target.global_position - global_position
			move_v = to_t.normalized() * 980.0
			_bat_ult_sprite.flip_h = to_t.x < 0.0
			if not _bat_ult_hit_done and to_t.length() <= 46.0:
				_bat_ult_hit_done = true
				if _is_controlled_locally() and _bat_ult_target.has_method("apply_hit"):
					_bat_ult_target.apply_hit(100, peer_id, "Bat Execution", player_name, Vector2.ZERO)
				_spawn_rising_particles(_bat_ult_target.global_position, Color(0.95, 0.14, 0.25), false, 12)
				_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 1.2)
				_bat_ult_timer = minf(_bat_ult_timer, 0.18)
		else:
			_bat_ult_sprite.flip_h = not facing_right
		velocity = move_v
		move_and_slide()
		if _bat_ult_timer <= 0.0:
			_bat_ult_sprite.visible = false
			if is_instance_valid(_modular_rig):
				_modular_rig.visible = true
			control_lock_timer = 0.0
			velocity *= 0.25
	elif is_instance_valid(_bat_ult_sprite) and _bat_ult_sprite.visible:
		_bat_ult_sprite.visible = false
		if is_instance_valid(_modular_rig):
			_modular_rig.visible = true
	if _yagami_ult_slash_timer > 0.0:
		_yagami_ult_slash_timer = maxf(0.0, _yagami_ult_slash_timer - delta)
		queue_redraw()
	if _yagami_ult_timer > 0.0:
		_yagami_ult_timer = maxf(0.0, _yagami_ult_timer - delta)
		var yt: float = clampf(1.0 - (_yagami_ult_timer / 0.55), 0.0, 1.0)
		var arc_y: float = -sin(yt * PI) * 115.0
		var next_p: Vector2 = _clamp_to_arena(_yagami_ult_start.lerp(_yagami_ult_end, yt) + Vector2(0.0, arc_y))
		global_position = next_p
		velocity = Vector2.ZERO
		if yt >= 0.72 and not _yagami_ult_slashed:
			_yagami_ult_slashed = true
			_yagami_ult_slash_timer = 0.42
			if _is_controlled_locally():
				_apply_melee_arc(global_position, Vector2.from_angle(aim_angle), 155.0, 130.0, 100, 0.0, 260.0, "Shadow Execution")
				if is_instance_valid(_yagami_ult_target) and _yagami_ult_target.has_method("is_alive") and _yagami_ult_target.is_alive() and _yagami_ult_target.has_method("apply_hit"):
					_yagami_ult_target.apply_hit(100, peer_id, "Shadow Execution", player_name, Vector2.ZERO)
			add_screen_shake(2.6)
			_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 1.25)
		if _yagami_ult_timer <= 0.0:
			control_lock_timer = 0.0
		queue_redraw()
	if _shadow_dash_timer > 0.0:
		_shadow_dash_timer = maxf(0.0, _shadow_dash_timer - delta)
		velocity = _shadow_dash_dir * 1200.0
		move_and_slide()
		if _is_controlled_locally() and _shadow_dash_dmg > 0:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
						continue
					if p.has_method("is_alive") and not p.is_alive():
						continue
					var pid: int = int(p.get("peer_id"))
					if not _shadow_dash_hit_ids.has(pid) and (p as Node2D).global_position.distance_to(global_position) <= 56.0:
						_shadow_dash_hit_ids.append(pid)
						if p.has_method("apply_hit"):
							p.apply_hit(_shadow_dash_dmg, peer_id, "Shadow Dash", player_name, _shadow_dash_dir * 260.0)
							gain_ult_charge(2.0)
		if _shadow_dash_timer <= 0.0:
			velocity *= 0.25
		queue_redraw()
	if _fly_kick_timer > 0.0:
		_fly_kick_timer = maxf(0.0, _fly_kick_timer - delta)
		var close_home: bool = false
		if is_instance_valid(_fly_kick_target) and (not _fly_kick_target.has_method("is_alive") or _fly_kick_target.is_alive()):
			var to_t: Vector2 = _fly_kick_target.global_position - global_position
			if to_t.length() > 4.0:
				_fly_kick_dir = to_t.normalized()
				facing_right = _fly_kick_dir.x >= 0.0
			close_home = to_t.length() <= 110.0
		var arc_vy: float = 0.0 if close_home else (-190.0 if _fly_kick_timer > 0.18 else 220.0)
		var kick_spd: float = 860.0 if _fly_kick_timer > 0.18 else 960.0
		velocity = _fly_kick_dir * kick_spd + Vector2(0.0, arc_vy)
		move_and_slide()
		if _is_controlled_locally():
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
						continue
					if p.has_method("is_alive") and not p.is_alive():
						continue
					var pid: int = int(p.get("peer_id"))
					if not (_fly_kick_hit_ids.has(pid)) and (p as Node2D).global_position.distance_to(global_position) <= 58.0:
						_fly_kick_hit_ids.append(pid)
						if p.has_method("apply_hit"):
							p.apply_hit(50, peer_id, "Flying Kick", player_name, _fly_kick_dir * 620.0 + Vector2(0.0, -220.0))
						_spawn_rising_particles((p as Node2D).global_position, Color(0.76, 0.44, 1.0), false, 8)
						_play_local_sfx("res://assets/audio/hit.wav", -1.0, 1.1)
						_fly_kick_timer = 0.0
						_fly_kick_target = null
						control_lock_timer = 0.0
						velocity *= 0.25
						break
		if _fly_kick_timer <= 0.0:
			_fly_kick_target = null
			facing_right = _fly_kick_dir.x >= 0.0
			velocity *= 0.35
	if _spear_timer > 0.0:
		_spear_timer = maxf(0.0, _spear_timer - delta)
		velocity = _spear_dir * 940.0
		facing_right = _spear_dir.x >= 0.0
		move_and_slide()
		if _is_controlled_locally():
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
						continue
					if p.has_method("is_alive") and not p.is_alive():
						continue
					var pid: int = int(p.get("peer_id"))
					if not _spear_hit_ids.has(pid) and (p as Node2D).global_position.distance_to(global_position) <= 64.0:
						_spear_hit_ids.append(pid)
						if p.has_method("apply_hit"):
							p.apply_hit(_spear_dmg, peer_id, _spear_label, player_name, _spear_dir * 680.0 + Vector2(0.0, -240.0))
						if p.has_method("apply_stun"):
							p.apply_stun(0.45, peer_id)
						_spawn_vfx_burst((p as Node2D).global_position, 56.0, Color(0.98, 0.62, 0.18), true)
						_play_local_sfx("res://assets/audio/hit.wav", -1.0, 0.95)
						add_screen_shake(1.2)
		if _spear_timer <= 0.0:
			velocity *= 0.35
	if boar_ride_timer > 0.0:
		boar_ride_timer = maxf(0.0, boar_ride_timer - delta)
		if _boar_sprite == null:
			_boar_sprite = Sprite2D.new()
			_boar_sprite.texture = TEX_WAR_BOAR
			_boar_sprite.scale = Vector2(0.64, 0.64)
			_boar_sprite.z_index = 3
			_boar_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(_boar_sprite)
		_boar_sprite.visible = true
		var move_face_right: bool = (velocity.x >= 0.0) if absf(velocity.x) > 25.0 else facing_right
		_boar_sprite.flip_h = not move_face_right
		var gallop: float = absf(sin(Time.get_ticks_msec() * 0.018))
		_boar_sprite.position = Vector2(0.0, 14.0 - gallop * 4.0)
		_boar_sprite.rotation = (0.08 if move_face_right else -0.08) * (gallop - 0.5)
		if is_instance_valid(_modular_rig):
			_modular_rig.position.y = -18.0 - gallop * 4.0
			_modular_rig.z_index = 4
	else:
		if is_instance_valid(_boar_sprite):
			_boar_sprite.visible = false
		if is_instance_valid(_modular_rig):
			_modular_rig.position.y = -16.5
			_modular_rig.z_index = 0
	if boar_ride_timer > 0.0:
		for k in _boar_hit_cooldowns.keys():
			_boar_hit_cooldowns[k] = float(_boar_hit_cooldowns[k]) - delta
			if float(_boar_hit_cooldowns[k]) <= 0.0:
				_boar_hit_cooldowns.erase(k)
		if absf(velocity.x) > 40.0:
			var fwd_x: float = signf(velocity.x)
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and int(p.get("peer_id")) != peer_id:
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
						continue
					if p.has_method("is_alive") and not p.is_alive():
						continue
					var dx: float = (p as Node2D).global_position.x - global_position.x
					if dx * fwd_x < -8.0:
						continue
					var pid: int = int(p.get("peer_id"))
					if not _boar_hit_cooldowns.has(pid) and (p as Node2D).global_position.distance_to(global_position) <= 64.0:
						_boar_hit_cooldowns[pid] = 0.65
						var kb_dir: Vector2 = ((p as Node2D).global_position - global_position).normalized()
						if kb_dir.length_squared() < 0.01:
							kb_dir = Vector2(fwd_x, 0.0)
						if p.has_method("apply_hit"):
							p.apply_hit(30, peer_id, "Boar Charge", player_name, kb_dir * 780.0 + Vector2(0.0, -240.0))
		queue_redraw()
	if auto_mg_timer > 0.0:
		auto_mg_timer = maxf(0.0, auto_mg_timer - delta)
		_auto_mg_accum += delta
		if _auto_mg_accum >= 0.11:
			_auto_mg_accum = 0.0
			var mg_orig: Vector2 = _get_safe_muzzle_pos(_muzzle_primary.global_position)
			var mg_b = _spawn_custom_bullet(mg_orig, aim_angle + randf_range(-0.04, 0.04), 1280.0, 12, "bullet", Color(0.35, 0.86, 1.0), "Auto Machinegun", 0.0, 0.0, false, 1.1, _is_controlled_locally())
			if mg_b != null:
				mg_b.max_trail_points = 2
			_play_local_sfx("res://assets/audio/shoot_m4a1.wav", -7.0, 1.1)
	if electric_laser_timer > 0.0:
		electric_laser_timer = maxf(0.0, electric_laser_timer - delta)
		_laser_visual_timer = 0.12
		_laser_visual_angle = aim_angle
		_laser_visual_color = Color(0.45, 0.92, 1.0)
		_laser_visual_width = 16.0
		_laser_visual_len = 560.0
		_electric_laser_accum += delta
		if _electric_laser_accum >= 0.27:
			_electric_laser_accum = 0.0
			var laser_tick_dmg: int = 16 if nyx_frenzy_timer > 0.0 else 8
			_cast_beam_attack(global_position + Vector2.from_angle(aim_angle) * 24.0, aim_angle, 560.0, 22.0, laser_tick_dmg, Color(0.45, 0.92, 1.0), "Electric Laser Gun", 0.12, _is_controlled_locally())
	if poison_dot_timer > 0.0:
		poison_dot_timer = maxf(0.0, poison_dot_timer - delta)
		_poison_dot_accum += delta
		if _poison_dot_accum >= 0.5:
			_poison_dot_accum = 0.0
			_spawn_rising_particles(global_position, Color(0.35, 0.98, 0.24), false, 3)
			if _is_controlled_locally():
				_receive_damage_local(5, _poison_attacker_id, "Poison", _poison_attacker_name, Vector2.ZERO)
	if cryo_shatter_timer > 0.0:
		cryo_shatter_timer = maxf(0.0, cryo_shatter_timer - delta)
		_cryo_shatter_accum += delta
		if _cryo_shatter_accum >= 0.3:
			_cryo_shatter_accum = 0.0
			_spawn_rising_particles(global_position, Color(0.45, 0.90, 1.0), false, 4)
			if _is_controlled_locally():
				_receive_damage_local(11, _cryo_attacker_id, "Cryo Shatter", _cryo_attacker_name, Vector2.ZERO)


func _fire_dual_shotgun_blast() -> void:
	if dual_shotgun_shots <= 0 or is_dead:
		return
	dual_shotgun_shots -= 1
	_fire_anim_timer = 0.16
	var perp: Vector2 = Vector2.from_angle(aim_angle + PI * 0.5) * 9.0
	var base_m: Vector2 = _get_safe_muzzle_pos(_muzzle_primary.global_position)
	var local_auth: bool = _is_controlled_locally()
	# Two shotguns firing normal shotgun pellets & range (speed 960, lifetime 0.42 ~400px range)
	for off_v in [-perp, perp]:
		_cast_gun_burst(base_m + off_v, aim_angle, 12, 5, 13.0, Color(1.0, 0.78, 0.30), "Dual Shotguns", 0.0, 960.0, local_auth, 0.38)
	_play_local_sfx("res://assets/audio/shoot_shotgun.wav", -3.0, 1.05)


func _update_dual_shotgun_visuals(show: bool) -> void:
	if show and not is_dead:
		for idx in range(2):
			var spr: Sprite2D = _dual_shotgun_spr_1 if idx == 0 else _dual_shotgun_spr_2
			if spr == null:
				spr = Sprite2D.new()
				spr.texture = TEX_WEAPONS_SHEET
				spr.hframes = 11
				spr.vframes = 3
				spr.frame = 5 # Shotgun sprite
				spr.scale = Vector2(0.28, 0.28)
				spr.z_index = 6 if idx == 0 else 4
				add_child(spr)
				if idx == 0:
					_dual_shotgun_spr_1 = spr
				else:
					_dual_shotgun_spr_2 = spr
			spr.visible = true
			var dir: Vector2 = Vector2.from_angle(aim_angle)
			var y_off: float = -6.0 if idx == 0 else 6.0
			spr.position = Vector2(0.0, -4.0 + y_off) + dir * 18.0
			spr.rotation = aim_angle
			spr.flip_v = cos(aim_angle) < 0.0
	else:
		if is_instance_valid(_dual_shotgun_spr_1):
			_dual_shotgun_spr_1.visible = false
		if is_instance_valid(_dual_shotgun_spr_2):
			_dual_shotgun_spr_2.visible = false


	var bounds: Vector2 = _get_arena_bounds()
	if global_position.x < -24.0 or global_position.x > bounds.x + 24.0 or global_position.y < -60.0 or global_position.y > bounds.y + 60.0:
		if _is_controlled_locally() and not is_dead:
			_trigger_death(0, "Out of Bounds", "Arena")
		return


func _get_arena_bounds() -> Vector2:
	var par: Node = get_parent()
	while par != null:
		if "arena_width" in par and "arena_height" in par:
			return Vector2(float(par.get("arena_width")), float(par.get("arena_height")))
		par = par.get_parent()
	var cs: Node = get_tree().current_scene if is_inside_tree() else null
	if cs != null and "arena_width" in cs and "arena_height" in cs:
		return Vector2(float(cs.get("arena_width")), float(cs.get("arena_height")))
	return Vector2(2200.0, 1200.0)


func _clamp_to_arena(pos: Vector2) -> Vector2:
	var bounds: Vector2 = _get_arena_bounds()
	return Vector2(clampf(pos.x, 64.0, bounds.x - 64.0), clampf(pos.y, 64.0, bounds.y - 64.0))


func _fire_contra_ult_missile() -> void:
	if is_dead:
		return
	var launch_angle: float = aim_angle
	var best_dist_sq: float = 950.0 * 950.0
	var best_pos: Vector2 = Vector2.INF
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or p == self:
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
			continue
		var d_sq: float = global_position.distance_squared_to((p as Node2D).global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_pos = (p as Node2D).global_position
	if best_pos != Vector2.INF:
		launch_angle = (best_pos - global_position).angle()
	var origin: Vector2 = global_position + Vector2.from_angle(launch_angle) * 26.0
	var bz := _spawn_custom_bullet(origin, launch_angle, 820.0, _contra_ult_dmg, "homing_rocket", _contra_ult_col, _contra_ult_name, 0.0, 0.0, true, 4.0, _contra_ult_local)
	if bz != null:
		bz.is_explosive = true
		bz.explosion_radius = 165.0
		bz.homing_turn_rate = 9.0
	add_screen_shake(2.2)
	_play_local_sfx("res://assets/audio/shoot_rpg.wav", -1.0, 0.85)


func _spawn_custom_bullet(origin: Vector2, angle: float, spd: float, dmg: int, style: String, col: Color, w_name: String, stun_dur: float, grav: float, homing: bool, life: float, local_auth: bool) -> Node:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	var b := BULLET_SCENE.instantiate()
	b.global_position = origin
	b.velocity = Vector2.from_angle(angle) * spd
	b.damage = dmg
	b.shooter_peer_id = peer_id
	b.shooter_team = team_id
	b.shooter_name = player_name
	b.shooter_rid = get_rid()
	b.weapon_name = w_name
	b.bullet_color = col
	b.visual_style = style
	b.stun_duration = stun_dur
	b.gravity_mult = grav
	b.is_homing = homing
	b.allow_self_damage = false
	b.can_deal_damage = local_auth
	b.max_lifetime = life
	parent_node.add_child(b)
	return b


func _spawn_summon(kind: String, pos: Vector2, dmg: int, dur: float, _col: Color, w_name: String, local_auth: bool, dir_override: float = 0.0) -> Node:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	var s := Area2D.new()
	s.set_script(load("res://scripts/AgentSummon.gd"))
	s.summon_kind = kind
	s.owner_peer_id = peer_id
	s.owner_team = team_id
	s.owner_name = player_name
	s.weapon_name = w_name
	s.can_deal = local_auth
	s.time_left = dur
	s.damage = dmg
	s.move_dir_x = dir_override if dir_override != 0.0 else (1.0 if facing_right else -1.0)
	s.global_position = pos
	parent_node.add_child(s)
	return s


func _spawn_hazard_zone(kind: String, pos: Vector2, dur: float, rad: float, dps_val: int, w_name: String, local_auth: bool) -> Node2D:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	var hz := Node2D.new()
	hz.set_script(load("res://scripts/PlatformHazardZone.gd"))
	hz.zone_kind = kind
	hz.shooter_id = peer_id
	hz.shooter_team = team_id
	hz.shooter_name = player_name
	hz.weapon_name = w_name
	hz.can_deal = local_auth
	hz.time_left = dur
	hz.radius = rad
	hz.dps = dps_val
	hz.global_position = pos
	parent_node.add_child(hz)
	return hz


func _cast_beam_attack(origin: Vector2, angle: float, beam_len: float, beam_width: float, dmg: int, col: Color, w_name: String, vis_dur: float, local_auth: bool) -> void:
	_laser_visual_timer = maxf(_laser_visual_timer, vis_dur)
	_laser_visual_angle = angle
	_laser_visual_color = col
	_laser_visual_width = beam_width
	_laser_visual_len = beam_len
	queue_redraw()
	if not local_auth:
		return
	var dir: Vector2 = Vector2.from_angle(angle)
	var end_pt: Vector2 = origin + dir * beam_len
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or int(p.get("peer_id")) == peer_id:
			continue
		if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment((p as Node2D).global_position, origin, end_pt)
		if closest.distance_to((p as Node2D).global_position) <= beam_width + 22.0 and p.has_method("apply_hit"):
			p.apply_hit(dmg, peer_id, w_name, player_name, dir * 240.0)
	for b_node in get_tree().get_nodes_in_group("destructible_bombs"):
		if not is_instance_valid(b_node) or not (b_node is Node2D):
			continue
		var b_pos: Vector2 = (b_node as Node2D).global_position
		var b_closest: Vector2 = Geometry2D.get_closest_point_to_segment(b_pos, origin, end_pt)
		if b_closest.distance_to(b_pos) <= beam_width + 26.0:
			var prop_obj: Object = b_node.get_meta("prop_node") if b_node.has_meta("prop_node") else b_node
			if prop_obj.has_method("detonate_barrel"):
				prop_obj.detonate_barrel(peer_id, player_name, team_id)
			elif prop_obj.has_method("on_shot_hit"):
				prop_obj.on_shot_hit(dmg, peer_id)


func _find_nearest_enemy_player(from_pos: Vector2, max_range: float = 1600.0) -> Node2D:
	var best: Node2D = null
	var best_d2: float = max_range * max_range
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or p == self:
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
			continue
		if float(p.get("invis_timer")) > 0.0:
			continue
		var d2: float = from_pos.distance_squared_to((p as Node2D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = p as Node2D
	for d in get_tree().get_nodes_in_group("decoy_targets"):
		if not is_instance_valid(d):
			continue
		if int(d.get("owner_peer_id")) == peer_id:
			continue
		if NetworkManager.is_team_mode() and int(d.get("owner_team")) == team_id:
			continue
		if d.has_method("is_alive") and not d.is_alive():
			continue
		var dd2: float = from_pos.distance_squared_to((d as Node2D).global_position)
		if dd2 < best_d2:
			best_d2 = dd2
			best = d as Node2D
	return best


func _cast_raven_swarm(origin: Vector2, angle: float, dmg: int, col: Color, ab_name: String, local_auth: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var b := BULLET_SCENE.instantiate()
	b.global_position = origin
	b.velocity = Vector2.from_angle(angle) * 370.0
	b.damage = dmg
	b.shooter_peer_id = peer_id
	b.shooter_team = team_id
	b.shooter_name = player_name
	b.shooter_rid = get_rid()
	b.weapon_name = ab_name
	b.bullet_color = col
	b.visual_style = "raven"
	b.scale = Vector2(1.25, 1.25)
	b.is_homing = true
	b.homing_turn_rate = 9.0
	b.allow_self_damage = false
	b.can_deal_damage = local_auth
	b.max_lifetime = 4.2
	parent_node.add_child(b)


func _cast_telekinesis(cast_pos: Vector2, cast_angle: float, dmg: int, col: Color, ab_name: String, local_auth: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var grab_style: String = "raven_stone"
	var start_pos: Vector2 = cast_pos + Vector2.from_angle(cast_angle) * 64.0
	# Prefer grabbing a nearby ground throwable crate or map prop (never grabs players)
	var best_prop: Node2D = null
	var best_crate: Dictionary = {}
	var best_d2: float = 540.0 * 540.0
	var arena_node := get_tree().current_scene
	if arena_node != null and "_crate_nodes" in arena_node:
		for c_entry in arena_node.get("_crate_nodes"):
			if bool(c_entry.get("active", false)) and str(c_entry.get("type", "")) == "throwable":
				var area := c_entry.get("area") as Area2D
				if is_instance_valid(area):
					var d2: float = cast_pos.distance_squared_to(area.global_position)
					if d2 < best_d2:
						best_d2 = d2
						best_crate = c_entry
	if arena_node != null and "_interactables" in arena_node:
		for inter in arena_node.get("_interactables"):
			if is_instance_valid(inter) and "prop_kind" in inter and bool(inter.get("is_available")):
				var d2: float = cast_pos.distance_squared_to((inter as Node2D).global_position)
				if d2 < best_d2:
					best_d2 = d2
					best_prop = inter as Node2D
					best_crate = {}
	if not best_crate.is_empty():
		var item_info: Dictionary = AgentData.get_throwable(int(best_crate.get("val", 0)))
		grab_style = str(item_info.get("style", "thrown_stone"))
		var c_area := best_crate.get("area") as Area2D
		start_pos = c_area.global_position
		best_crate["active"] = false
		best_crate["timer"] = 6.0
		c_area.visible = false
		c_area.set_deferred("monitoring", false)
	elif best_prop != null:
		grab_style = "prop_" + str(best_prop.get("prop_kind"))
		start_pos = best_prop.global_position
		if best_prop.has_method("pick_up_prop"):
			best_prop.pick_up_prop()

	var tk := TelekinesisDragEffect.new()
	tk.caster = self
	tk.start_pos = start_pos
	tk.cast_angle = cast_angle
	tk.grab_style = grab_style
	tk.dmg = dmg
	tk.col = col
	tk.ab_name = ab_name
	tk.local_auth = local_auth
	parent_node.add_child(tk)


func _cast_reverse_smoke(origin: Vector2, angle: float, dmg: int, dur: float, col: Color, ab_name: String, local_auth: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var b := BULLET_SCENE.instantiate()
	b.global_position = origin
	b.velocity = Vector2.from_angle(angle) * 760.0
	b.damage = dmg
	b.shooter_peer_id = peer_id
	b.shooter_team = team_id
	b.shooter_name = player_name
	b.shooter_rid = get_rid()
	b.weapon_name = ab_name
	b.bullet_color = col
	b.visual_style = "smoke_orb"
	b.reverse_controls_dur = dur
	b.allow_self_damage = false
	b.can_deal_damage = local_auth
	b.max_lifetime = 1.8
	parent_node.add_child(b)


func _cast_backstab_teleport(cast_pos: Vector2, _dmg: int, col: Color, ab_name: String, local_auth: bool) -> void:
	var aim_dir: Vector2 = Vector2.from_angle(aim_angle)
	var target: Node2D = null
	var best_sq: float = 520.0 * 520.0
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or p == self:
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		if NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id:
			continue
		var diff: Vector2 = (p as Node2D).global_position - cast_pos
		var d_sq: float = diff.length_squared()
		if d_sq > best_sq or d_sq < 1.0:
			continue
		# Must be roughly on the same fight level (not far above/below platforms)
		if absf(diff.y) > 135.0:
			continue
		# Must be in the forward aim cone (or very close in-the-fight brawl <= 160px)
		var forward_dot: float = diff.normalized().dot(aim_dir)
		if forward_dot < 0.45 and d_sq > 160.0 * 160.0:
			continue
		best_sq = d_sq
		target = p as Node2D
	_spawn_vfx_burst(cast_pos, 58.0, col, false, true)
	if target != null:
		var t_facing: bool = bool(target.get("facing_right")) if "facing_right" in target else true
		var behind_dist: float = 48.0
		var behind_off: Vector2 = Vector2(-behind_dist if t_facing else behind_dist, -4.0)
		var dest: Vector2 = _clamp_to_arena(target.global_position + behind_off)
		global_position = dest
		velocity = Vector2.ZERO
		facing_right = target.global_position.x >= global_position.x
		aim_angle = (target.global_position - global_position).angle()
		control_lock_timer = 1.05
		if local_auth and target.has_method("apply_stun"):
			target.apply_stun(1.05, peer_id)
		_spawn_vfx_burst(global_position, 64.0, col, false, true)
		_fire_anim_timer = 0.85
		if is_instance_valid(_modular_rig):
			_modular_rig.play_state("idle", not facing_right)
		get_tree().create_timer(0.72).timeout.connect(func():
			if is_dead or not is_instance_valid(target):
				return
			if target.has_method("is_alive") and not target.is_alive():
				return
			_melee_swing_timer = 0.25
			if is_instance_valid(_modular_rig):
				_modular_rig.play_state("firing", not facing_right)
			var bpos: Vector2 = target.global_position
			var blood_col := Color(0.88, 0.04, 0.10)
			if local_auth and target.has_method("apply_hit"):
				target.apply_hit(100, peer_id, ab_name, player_name, Vector2(380.0 if facing_right else -380.0, -180.0))
			_spawn_vfx_burst(bpos, 72.0, Color(0.76, 0.30, 1.0), false, true)
			_spawn_rising_particles(bpos, blood_col, false, 24)
			_play_local_sfx("res://assets/audio/hit.wav", 0.0, 0.85)
		)
	else:
		_cast_teleport(cast_pos, aim_angle, 280.0, 0, 0.0, col, ab_name, false, local_auth, true)


func _cast_cleave_or_giant(origin: Vector2, angle: float, dmg: int, stun_dur: float, col: Color, ab_name: String, count: int, spread: float, proj_scale: float, local_auth: bool) -> void:
	if local_auth:
		var reach: float = 165.0 if count == 1 else 210.0
		var hits: int = _apply_melee_arc(global_position, Vector2.from_angle(angle), reach, 82.0, dmg, stun_dur, 380.0, ab_name)
		if hits > 0 and count == 1:
			gain_ult_charge(2.0 * float(hits))
	for i in range(count):
		var off: float = (float(i) - float(count - 1) * 0.5) * spread
		_spawn_styled_projectile(origin, angle + off, 780.0, dmg, "slash_wave", col, ab_name, stun_dur, 0.0, false, 60.0, 1.5, true, local_auth, 0.55, proj_scale)


func _cast_fireballs(origin: Vector2, angle: float, dmg: int, stun_dur: float, col: Color, ab_name: String, count: int, local_auth: bool, style: String = "fireball") -> void:
	var spread: float = 0.16 if count > 1 else 0.0
	for i in range(count):
		var off: float = (float(i) - float(count - 1) * 0.5) * spread
		_spawn_styled_projectile(origin, angle + off, 840.0, dmg, style, col, ab_name, stun_dur, 0.0, true, 135.0, 1.4, false, local_auth, 1.35, 1.25)


func _cast_stun_bomb(origin: Vector2, angle: float, dmg: int, stun_dur: float, col: Color, ab_name: String, local_auth: bool, radius: float = 175.0, speed: float = 820.0) -> void:
	var final_stun: float = maxf(stun_dur, 1.4)
	_spawn_styled_projectile(origin, angle, speed, dmg, "stun_bomb", col, ab_name, final_stun, 6.0, true, radius, 0.9, false, local_auth, 0.95, 1.25, 0.48)


func _cast_lava_bomb(origin: Vector2, angle: float, dmg: int, stun_dur: float, col: Color, ab_name: String, local_auth: bool, style: String = "fireball") -> void:
	_spawn_styled_projectile(origin, angle, 780.0, dmg, style, col, ab_name, stun_dur, 10.0, true, 165.0, 1.6, false, local_auth, 1.15, 1.35, 0.52)


func _cast_multi_proj(origin: Vector2, angle: float, dmg: int, count: int, spread_deg: float, style: String, col: Color, ab_name: String, stun_dur: float, speed: float, spin_spd: float, pierce_w: bool, local_auth: bool, life: float, proj_scale: float, is_exp: bool = false, exp_rad: float = 120.0) -> void:
	for i in range(count):
		var off: float = 0.0
		if count > 1:
			var frac: float = (float(i) / float(count - 1)) - 0.5
			off = deg_to_rad(spread_deg) * frac
		_spawn_styled_projectile(origin, angle + off, speed, dmg, style, col, ab_name, stun_dur, spin_spd, is_exp, exp_rad, 1.1, pierce_w, local_auth, life, proj_scale)


func _cast_teleport(cast_pos: Vector2, angle: float, max_dist: float, dmg: int, stun_dur: float, col: Color, ab_name: String, with_beams: bool, local_auth: bool, lightning_orb: bool = false) -> void:
	_spawn_vfx_burst(cast_pos, 70.0, col, false, lightning_orb)
	var dir: Vector2 = Vector2.from_angle(angle)
	var raw_target: Vector2 = cast_pos + dir * max_dist
	var dest: Vector2 = raw_target
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(cast_pos, raw_target, 1)
	var hit: Dictionary = space_state.intersect_ray(ray)
	if not hit.is_empty():
		dest = (hit["position"] as Vector2) - dir * 32.0
	dest.x = clampf(dest.x, 72.0, 2168.0)
	dest.y = clampf(dest.y, 72.0, 1140.0)
	global_position = dest
	velocity.y = minf(velocity.y, 80.0)
	_spawn_vfx_burst(dest, 115.0 if not with_beams else 160.0, col, false, lightning_orb)
	if local_auth:
		var hits: int = _apply_radial_aoe(dest, 125.0 if not with_beams else 165.0, dmg, stun_dur, 300.0, ab_name)
		if hits > 0 and not with_beams:
			gain_ult_charge(2.0 * float(hits))
	if with_beams:
		_spawn_styled_projectile(dest + dir * 24.0, angle - 0.16, 860.0, dmg, "slash_wave", col, ab_name, stun_dur, 0.0, false, 60.0, 1.4, true, local_auth, 0.65, 2.2)
		_spawn_styled_projectile(dest + dir * 24.0, angle + 0.16, 860.0, dmg, "slash_wave", col, ab_name, stun_dur, 0.0, false, 60.0, 1.4, true, local_auth, 0.65, 2.2)


func _cast_gun_burst(origin: Vector2, angle: float, dmg: int, shots: int, spread_deg: float, col: Color, ab_name: String, stun_dur: float, speed: float, local_auth: bool, life: float = 1.1) -> void:
	for i in range(shots):
		var frac: float = (float(i) / float(maxi(1, shots - 1))) - 0.5
		var off: float = deg_to_rad(spread_deg) * frac
		_spawn_styled_projectile(origin, angle + off, speed, dmg, "bullet", col, ab_name, stun_dur, 0.0, false, 60.0, 0.85, false, local_auth, life, 1.15)


func _spawn_barrier_wall(cast_pos: Vector2, angle: float, wall_hp: int, duration: float, col: Color) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var dir: Vector2 = Vector2.from_angle(angle)
	var wall_pos: Vector2 = cast_pos + dir * 105.0
	wall_pos.x = clampf(wall_pos.x, 76.0, 2164.0)
	wall_pos.y = clampf(wall_pos.y, 96.0, 1120.0)
	var wall := BarrierWall.new()
	wall.global_position = wall_pos
	wall.setup_wall(wall_hp, duration, col)
	parent_node.add_child(wall)


func _apply_melee_arc(origin: Vector2, dir: Vector2, reach: float, half_deg: float, dmg: int, stun_dur: float, kb_str: float, label: String) -> int:
	var cos_limit: float = cos(deg_to_rad(half_deg))
	var hit_count: int = 0
	for node in get_tree().get_nodes_in_group("players"):
		if node == self or not is_instance_valid(node) or int(node.get("peer_id")) == peer_id:
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		if NetworkManager.is_team_mode() and int(node.get("team_id")) == team_id:
			continue
		var delta_v: Vector2 = node.global_position - origin
		var dist: float = delta_v.length()
		if dist > reach:
			continue
		var facing_ok: bool = dist < 36.0 or dir.dot(delta_v.normalized()) >= cos_limit
		if facing_ok and node.has_method("apply_hit"):
			var kb: Vector2 = (delta_v.normalized() if dist > 1.0 else dir) * kb_str
			node.apply_hit(dmg, peer_id, label, player_name, kb)
			if stun_dur > 0.0 and node.has_method("apply_stun"):
				node.apply_stun(stun_dur, peer_id)
			hit_count += 1
	for wall in get_tree().get_nodes_in_group("barrier_walls"):
		if is_instance_valid(wall) and wall.has_method("apply_wall_damage"):
			if origin.distance_to(wall.global_position) <= reach + 32.0:
				wall.apply_wall_damage(dmg)
	for d_node in get_tree().get_nodes_in_group("decoy_targets"):
		if not is_instance_valid(d_node) or not (d_node is Node2D):
			continue
		if int(d_node.get("owner_peer_id")) == peer_id:
			continue
		if NetworkManager.is_team_mode() and int(d_node.get("owner_team")) == team_id:
			continue
		var d_delta: Vector2 = (d_node as Node2D).global_position - origin
		if d_delta.length() <= reach and (d_delta.length() < 36.0 or dir.dot(d_delta.normalized()) >= cos_limit):
			if d_node.has_method("on_shot_hit"):
				d_node.on_shot_hit(dmg, peer_id)
				hit_count += 1
	return hit_count


func _apply_radial_aoe(origin: Vector2, radius: float, dmg: int, stun_dur: float, kb_str: float, label: String) -> int:
	var hit_count: int = 0
	for node in get_tree().get_nodes_in_group("players"):
		if node == self or not is_instance_valid(node) or int(node.get("peer_id")) == peer_id:
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		if NetworkManager.is_team_mode() and int(node.get("team_id")) == team_id:
			continue
		var dist: float = origin.distance_to(node.global_position)
		if dist <= radius and node.has_method("apply_hit"):
			var dir: Vector2 = (node.global_position - origin).normalized()
			if dir.length_squared() < 0.01:
				dir = Vector2.UP
			node.apply_hit(dmg, peer_id, label, player_name, dir * kb_str + Vector2(0.0, -120.0))
			if stun_dur > 0.0 and node.has_method("apply_stun"):
				node.apply_stun(stun_dur, peer_id)
			hit_count += 1
	for wall in get_tree().get_nodes_in_group("barrier_walls"):
		if is_instance_valid(wall) and wall.has_method("apply_wall_damage"):
			if origin.distance_to(wall.global_position) <= radius:
				wall.apply_wall_damage(dmg)
	return hit_count


func _find_player_by_peer_id(pid: int) -> Node2D:
	if pid == 0 or not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(node) and int(node.get("peer_id")) == pid:
			return node as Node2D
	return null


func find_grabbable_player() -> Node2D:
	if not NetworkManager.is_agent_clash_mode() or is_dead or stun_timer > 0.0:
		return null
	if grabbed_player_id != 0 or carried_by_peer_id != 0 or _grab_cooldown > 0.0 or not is_inside_tree():
		return null
	var best: Node2D = null
	var best_dist: float = GRAB_PLAYER_RANGE
	for node in get_tree().get_nodes_in_group("players"):
		if node == self or not is_instance_valid(node):
			continue
		if bool(node.get("is_dead")) or float(node.get("spawn_invuln_timer")) > 0.0:
			continue
		if int(node.get("carried_by_peer_id")) != 0 or int(node.get("grabbed_player_id")) != 0:
			continue
		if NetworkManager.is_team_mode() and int(node.get("team_id")) == team_id:
			continue
		if float(node.get("invis_timer")) > 0.0:
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d <= best_dist:
			best_dist = d
			best = node as Node2D
	return best


func _release_grab_state() -> void:
	if grabbed_player_id != 0:
		var v := _find_player_by_peer_id(grabbed_player_id)
		if v != null:
			v.set("carried_by_peer_id", 0)
			var vcs := v.get("_collision_shape") as CollisionShape2D
			if vcs != null:
				vcs.disabled = false
		grabbed_player_id = 0
	if carried_by_peer_id != 0:
		var c := _find_player_by_peer_id(carried_by_peer_id)
		if c != null and int(c.get("grabbed_player_id")) == peer_id:
			c.set("grabbed_player_id", 0)
		carried_by_peer_id = 0
	_grab_hold_timer = 0.0
	thrown_by_peer_id = 0
	thrown_flight_timer = 0.0
	_thrown_flight_elapsed = 0.0
	if _collision_shape != null:
		_collision_shape.disabled = false


func grab_player(target: Node2D) -> bool:
	if target == null:
		return false
	var target_pid: int = int(target.get("peer_id"))
	if target_pid == 0:
		return false
	if NetworkManager.is_network_active():
		sync_grab_player_rpc.rpc(target_pid)
	else:
		_grab_player_local(target_pid)
	return grabbed_player_id == target_pid


@rpc("any_peer", "call_local", "reliable")
func sync_grab_player_rpc(target_pid: int) -> void:
	_grab_player_local(target_pid)


func _grab_player_local(target_pid: int) -> void:
	var target := _find_player_by_peer_id(target_pid)
	if target == null:
		return
	grabbed_player_id = target_pid
	_grab_hold_timer = 3.5
	target.set("carried_by_peer_id", peer_id)
	target.set("stun_timer", 0.0)
	target.set("velocity", Vector2.ZERO)
	var tcs := target.get("_collision_shape") as CollisionShape2D
	if tcs != null:
		tcs.disabled = true
	target.global_position = global_position + Vector2(0.0, -48.0)
	_play_local_sfx("res://assets/audio/pickup.wav", -2.0, 0.9)


func throw_grabbed_player(angle: float) -> void:
	if grabbed_player_id == 0:
		return
	var victim_pid: int = grabbed_player_id
	if NetworkManager.is_network_active():
		sync_throw_player_rpc.rpc(victim_pid, global_position, angle)
	else:
		_throw_player_local(victim_pid, global_position, angle)


@rpc("any_peer", "call_local", "reliable")
func sync_throw_player_rpc(victim_pid: int, origin: Vector2, angle: float) -> void:
	_throw_player_local(victim_pid, origin, angle)


func _throw_player_local(victim_pid: int, origin: Vector2, angle: float) -> void:
	grabbed_player_id = 0
	_grab_hold_timer = 0.0
	_grab_cooldown = 1.2
	var victim := _find_player_by_peer_id(victim_pid)
	if victim == null:
		return
	victim.set("carried_by_peer_id", 0)
	var vcs := victim.get("_collision_shape") as CollisionShape2D
	if vcs != null:
		vcs.disabled = false
	victim.global_position = origin + Vector2.from_angle(angle) * 30.0 + Vector2(0.0, -10.0)
	victim.set("velocity", Vector2.from_angle(angle) * THROW_PLAYER_SPEED)
	victim.set("thrown_by_peer_id", peer_id)
	victim.set("thrown_by_name", player_name)
	victim.set("thrown_by_team", team_id)
	victim.set("thrown_by_rook_frost", str(AgentData.get_agent(archetype_id).get("agent_name", "")) == "Rook Frost")
	victim.set("thrown_flight_timer", 0.70)
	victim.set("_thrown_flight_elapsed", 0.0)
	victim.set("stun_timer", maxf(float(victim.get("stun_timer")), 0.75))
	_play_local_sfx("res://assets/audio/jump.wav", -2.0, 0.7)
	if victim.has_method("_is_controlled_locally") and victim._is_controlled_locally():
		victim._check_thrown_player_impact()


func _check_thrown_player_impact() -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group("players"):
		if node == self or not is_instance_valid(node) or bool(node.get("is_dead")):
			continue
		if int(node.get("peer_id")) == thrown_by_peer_id:
			continue
		if NetworkManager.is_team_mode() and int(node.get("team_id")) == thrown_by_team:
			continue
		if global_position.distance_to(node.global_position) <= 56.0:
			var t_id: int = thrown_by_peer_id
			var t_name: String = thrown_by_name
			var hit_dir: Vector2 = velocity.normalized() if velocity.length() > 1.0 else Vector2.RIGHT
			thrown_flight_timer = 0.0
			thrown_by_peer_id = 0
			_thrown_flight_elapsed = 0.0
			apply_hit(THROWN_SELF_DAMAGE, t_id, "Thrown Player Impact", t_name, -hit_dir * 260.0)
			apply_stun(1.1, t_id)
			node.apply_hit(THROWN_TARGET_DAMAGE, t_id, "Thrown Player (%s)" % player_name, t_name, hit_dir * 420.0)
			if node.has_method("apply_stun"):
				node.apply_stun(1.2, t_id)
			_spawn_vfx_burst((global_position + node.global_position) * 0.5, 58.0, Color(1.0, 0.65, 0.20))
			return true
	if _thrown_flight_elapsed >= 0.06 and (is_on_wall() or is_on_floor() or is_on_ceiling()):
		var t_id: int = thrown_by_peer_id
		var t_name: String = thrown_by_name
		var shatter_kill: bool = thrown_by_rook_frost and freeze_timer > 0.0
		thrown_flight_timer = 0.0
		thrown_by_peer_id = 0
		thrown_by_rook_frost = false
		_thrown_flight_elapsed = 0.0
		if shatter_kill:
			freeze_timer = 0.0
			apply_hit(9999, t_id, "Frozen Shatter Wall Slam", t_name, Vector2.ZERO)
			_spawn_vfx_burst(global_position, 64.0, Color(0.55, 0.90, 1.0))
		else:
			apply_hit(THROWN_WALL_DAMAGE, t_id, "Thrown Wall Slam", t_name, Vector2.ZERO)
			_spawn_vfx_burst(global_position, 42.0, Color(0.95, 0.55, 0.20))
		return true
	return false


func throw_held_item() -> void:
	if is_dead or stun_timer > 0.0 or carried_by_peer_id != 0:
		return
	if not held_prop_kind.is_empty():
		throw_held_prop()
		return
	if grabbed_player_id != 0:
		throw_grabbed_player(aim_angle)
		if is_local_human and NetworkManager.is_agent_clash_mode():
			agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
		return
	if not held_throwables.is_empty():
		var item_id: int = held_throwables.pop_back()
		held_throwable_id = held_throwables.back() if not held_throwables.is_empty() else -1
		if is_local_human and NetworkManager.is_agent_clash_mode():
			agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
		var safe_m: Vector2 = _get_safe_muzzle_pos(_muzzle_primary.global_position)
		if NetworkManager.is_network_active():
			throw_item_rpc.rpc(item_id, safe_m, aim_angle)
		else:
			_throw_item_local(item_id, safe_m, aim_angle)
		return
	# Shoe throwing disabled for now (kept intact in throw_shoe() for future use)
	const SHOE_THROW_ENABLED: bool = false
	if SHOE_THROW_ENABLED:
		throw_shoe()


func throw_shoe() -> void:
	if is_dead or stun_timer > 0.0 or carried_by_peer_id != 0:
		return
	if shoe_cooldown_timer <= 0.0 and _shoe_windup_timer <= 0.0:
		_shoe_windup_timer = SHOE_WINDUP_SEC
		_play_local_sfx("res://assets/audio/jump.wav", -6.0, 1.35)
		if is_local_human and NetworkManager.is_agent_clash_mode():
			agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)


@rpc("any_peer", "call_local", "reliable")
func throw_item_rpc(item_id: int, origin: Vector2, angle: float) -> void:
	_throw_item_local(item_id, origin, angle)


func _throw_item_local(item_id: int, origin: Vector2, angle: float) -> void:
	var item: Dictionary = AgentData.get_throwable(item_id)
	_spawn_styled_projectile(
		origin,
		angle,
		float(item["speed"]),
		int(item["damage"]),
		str(item["style"]),
		item["color"] as Color,
		str(item["name"]),
		float(item["stun"]),
		18.0,
		bool(item.get("explosive", false)),
		125.0,
		1.8,
		false,
		_is_controlled_locally(),
		1.8,
		1.35
	)
	_play_local_sfx("res://assets/audio/jump.wav", -3.0, 0.75)


func _spawn_styled_projectile(
	origin: Vector2,
	angle: float,
	speed: float,
	dmg: int,
	style: String,
	col: Color,
	w_label: String,
	stun_dur: float,
	spin_spd: float,
	explosive: bool,
	exp_radius: float,
	kb_mult: float,
	pierce_w: bool,
	deal_dmg: bool,
	life: float = 1.6,
	proj_scale: float = 1.0,
	grav_mult: float = 0.0
) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var b := BULLET_SCENE.instantiate()
	b.global_position = origin
	b.velocity = Vector2.from_angle(angle) * speed
	b.damage = dmg
	b.shooter_peer_id = peer_id
	b.shooter_team = team_id
	b.shooter_name = player_name
	b.shooter_rid = get_rid()
	b.weapon_name = w_label
	b.bullet_color = col
	b.visual_style = style
	b.spin_speed = spin_spd
	b.stun_duration = stun_dur
	b.is_explosive = explosive
	b.explosion_radius = exp_radius
	b.knockback_mult = kb_mult
	b.pierce_walls = pierce_w
	b.gravity_mult = grav_mult
	b.can_deal_damage = deal_dmg
	b.allow_self_damage = false
	b.max_lifetime = life
	b.scale = Vector2(proj_scale, proj_scale)
	parent_node.add_child(b)


func _spawn_air_wave_circle(pos: Vector2, max_rad: float, col: Color) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var vfx := AirWaveCircleVfx.new()
	vfx.global_position = pos
	vfx.max_radius = max_rad
	vfx.wave_color = col
	parent_node.add_child(vfx)


func _spawn_cryo_wave(pos: Vector2, max_rad: float, can_apply: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var vfx := AirWaveCircleVfx.new()
	vfx.global_position = pos
	vfx.max_radius = max_rad
	vfx.wave_color = Color(0.45, 0.92, 1.0)
	vfx.cryo_active = true
	vfx.cryo_can_apply = can_apply
	vfx.cryo_caster_id = peer_id
	vfx.cryo_team_id = team_id
	parent_node.add_child(vfx)


func _spawn_earthquake_wave(pos: Vector2, max_rad: float, dur: float, dmg_dps: int, ab_label: String, can_apply: bool) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var vfx := AirWaveCircleVfx.new()
	vfx.global_position = pos
	vfx.max_radius = max_rad
	vfx.wave_color = Color(0.78, 0.50, 0.22)
	vfx.eq_active = true
	vfx.eq_dur = dur
	vfx.eq_dps = dmg_dps
	vfx.eq_label = ab_label
	vfx.eq_caster_name = player_name
	vfx.cryo_can_apply = can_apply
	vfx.cryo_caster_id = peer_id
	vfx.cryo_team_id = team_id
	parent_node.add_child(vfx)


func _spawn_flurry_dust_puff(center_pos: Vector2) -> void:
	var off := Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 14.0))
	_spawn_rising_particles(center_pos + off, Color(0.88, 0.88, 0.92, 0.85), false, 5)
	_spawn_rising_particles(center_pos + off * 0.6, Color(1.0, 0.78, 0.25, 0.90), false, 3)


func _spawn_rising_particles(pos: Vector2, col: Color, is_heal: bool = false, count: int = 8) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var vfx := RisingParticleVfx.new()
	vfx.global_position = pos
	vfx.part_color = col
	vfx.is_heal = is_heal
	vfx.count = count
	parent_node.add_child(vfx)


func _spawn_vfx_burst(pos: Vector2, radius: float, col: Color, custom_splash: bool = false, lightning_orb: bool = false) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var exp := EXPLOSION_SCENE.instantiate()
	exp.global_position = pos
	exp.explosion_radius = radius
	exp.max_damage = 0
	exp.ring_color = col
	exp.custom_splash_only = custom_splash
	exp.lightning_orb_only = lightning_orb
	exp.can_deal_damage = false
	parent_node.add_child(exp)


func _get_safe_muzzle_pos(muzzle_pos: Vector2) -> Vector2:
	var pivot_pos: Vector2 = _weapon_pivot.global_position if is_instance_valid(_weapon_pivot) else global_position
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(pivot_pos, muzzle_pos, 3)
	var excl: Array[RID] = [get_rid()]
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or p == self or not (p is CollisionObject2D):
			continue
		if (p.has_method("is_alive") and not p.is_alive()) or (NetworkManager.is_team_mode() and int(p.get("team_id")) == team_id):
			excl.append((p as CollisionObject2D).get_rid())
	ray.exclude = excl
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	ray.hit_from_inside = true
	var hit: Dictionary = space_state.intersect_ray(ray)
	if not hit.is_empty():
		var col: Object = hit.get("collider")
		if col != null and col.is_in_group("players"):
			return pivot_pos
		var n: Vector2 = hit["normal"]
		return (hit["position"] as Vector2) + n * 2.0
	return muzzle_pos


func _draw() -> void:
	if not is_dead:
		if _shadow_dash_timer > 0.0:
			var back_dir: Vector2 = -_shadow_dash_dir.normalized()
			var perp: Vector2 = Vector2(-back_dir.y, back_dir.x)
			var dash_alpha: float = clampf(_shadow_dash_timer / 0.24, 0.25, 1.0)
			var line_specs: Array = [
				[-15.0, 14.0, 66.0, 3.6],
				[0.0, 18.0, 86.0, 4.6],
				[15.0, 14.0, 66.0, 3.6],
			]
			for spec in line_specs:
				var lat: Vector2 = perp * float(spec[0])
				var p_start: Vector2 = lat + back_dir * float(spec[1])
				var p_end: Vector2 = lat + back_dir * float(spec[2])
				var w: float = float(spec[3])
				draw_line(p_start, p_end, Color(0.72, 0.42, 1.0, 0.85 * dash_alpha), w + 2.2)
				draw_line(p_start, p_end, Color(0.96, 0.92, 1.0, 0.95 * dash_alpha), w * 0.65)
		if touch_fire_timer > 0.0:
			var fire_pulse_r: float = 42.0 + sin(Time.get_ticks_msec() * 0.014) * 5.0
			draw_arc(Vector2.ZERO, fire_pulse_r, 0.0, TAU, 32, Color(1.0, 0.44, 0.12, 0.88), 3.0)
		if touch_banish_timer > 0.0:
			var pulse_r: float = 42.0 + sin(Time.get_ticks_msec() * 0.012) * 5.0
			draw_arc(Vector2.ZERO, pulse_r, 0.0, TAU, 32, Color(0.84, 0.48, 1.0, 0.85), 3.0)
		if banish_after_fx_timer > 0.0:
			var bf_a: float = clampf(banish_after_fx_timer, 0.0, 1.0)
			var bf_r: float = 34.0 + sin(Time.get_ticks_msec() * 0.022) * 5.0
			draw_circle(Vector2.ZERO, bf_r, Color(0.76, 0.36, 1.0, 0.22 * bf_a))
			draw_arc(Vector2.ZERO, bf_r, 0.0, TAU, 28, Color(0.88, 0.56, 1.0, 0.92 * bf_a), 3.0)
			for si in range(4):
				var sp_ang: float = Time.get_ticks_msec() * 0.01 + float(si) * (TAU * 0.25)
				draw_circle(Vector2.from_angle(sp_ang) * (bf_r * 0.78), 3.5, Color(0.55, 0.95, 1.0, 0.95 * bf_a))
		if _hook_pull_timer > 0.0 and _hook_pull_target != Vector2.INF:
			draw_line(Vector2.ZERO, to_local(_hook_pull_target), Color(0.88, 0.72, 0.32), 3.5)
			draw_circle(to_local(_hook_pull_target), 7.0, Color(0.95, 0.82, 0.38))
		if bubble_trap_timer > 0.0:
			var b_rad: float = 38.0
			draw_circle(Vector2(0.0, -4.0), b_rad, Color(0.32, 0.88, 1.0, 0.24))
			draw_arc(Vector2(0.0, -4.0), b_rad, 0.0, TAU, 36, Color(0.65, 0.96, 1.0, 0.92), 3.2)
			draw_arc(Vector2(0.0, -4.0), b_rad - 4.0, -2.4, -1.1, 14, Color(1.0, 1.0, 1.0, 0.85), 2.5)
			draw_arc(Vector2(0.0, -4.0), b_rad - 3.0, 0.3, 1.4, 12, Color(1.0, 0.58, 0.92, 0.65), 2.0)
	if NetworkManager.is_agent_clash_mode() and not is_dead:
		if _laser_visual_timer > 0.0:
			var beam_origin: Vector2 = Vector2(0.0, 5.0) if electric_laser_timer > 0.0 else Vector2.ZERO
			var p1: Vector2 = beam_origin + Vector2.from_angle(_laser_visual_angle) * 24.0
			var p2: Vector2 = beam_origin + Vector2.from_angle(_laser_visual_angle) * _laser_visual_len
			draw_line(p1, p2, Color(_laser_visual_color.r, _laser_visual_color.g, _laser_visual_color.b, 0.72), _laser_visual_width)
			draw_line(p1, p2, Color.WHITE, maxf(3.0, _laser_visual_width * 0.25))
			if electric_laser_timer > 0.0:
				draw_circle(p1, _laser_visual_width * 0.65, Color(_laser_visual_color.r, _laser_visual_color.g, _laser_visual_color.b, 0.75))
				draw_circle(p1, _laser_visual_width * 0.35, Color.WHITE)
		if personal_shield_hp > 0 and personal_shield_timer > 0.0:
			draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 28, Color(0.35, 0.85, 1.0, 0.85), 4.0)
		if freeze_timer > 0.0:
			draw_rect(Rect2(-22.0, -34.0, 44.0, 62.0), Color(0.55, 0.92, 1.0, 0.45))
		if _yagami_ult_slash_timer > 0.0:
			var sa: float = clampf(_yagami_ult_slash_timer / 0.42, 0.0, 1.0)
			var dir_s: float = 1.0 if facing_right else -1.0
			var swing_ang: float = lerpf(-1.25, 0.95, 1.0 - sa) * dir_s
			var blade_dir: Vector2 = Vector2(dir_s * cos(absf(swing_ang)), sin(swing_ang))
			draw_line(Vector2.ZERO, blade_dir * 135.0, Color(0.76, 0.34, 1.0, sa), 16.0)
			draw_line(Vector2.ZERO, blade_dir * 130.0, Color(1.0, 0.95, 1.0, sa), 7.0)
			draw_arc(Vector2.ZERO, 125.0, -1.1 if facing_right else (PI - 1.1), 0.9 if facing_right else (PI + 0.9), 20, Color(0.88, 0.45, 1.0, sa * 0.85), 6.0)
		if _hook_pull_timer > 0.0 and _hook_pull_target != Vector2.INF:
			draw_line(Vector2.ZERO, to_local(_hook_pull_target), Color(0.88, 0.72, 0.32), 3.5)
			draw_circle(to_local(_hook_pull_target), 7.0, Color(0.95, 0.82, 0.38))
		return
	if not is_local_human or is_dead or not SettingsManager.sight_laser:
		return
	if _muzzle_primary == null or not is_instance_valid(_muzzle_primary):
		return
	var laser_len: float = _weapon.bullet_range if (_weapon != null and _weapon.bullet_range > 0.0) else (1400.0 if (_weapon != null and _weapon.max_zoom_level >= 6) else 460.0)
	var start_world: Vector2 = _get_safe_muzzle_pos(_muzzle_primary.global_position)
	var end_world: Vector2 = start_world + Vector2.from_angle(aim_angle) * laser_len
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(start_world, end_world, 1)
	ray.collide_with_areas = false
	ray.collide_with_bodies = true
	var hit: Dictionary = space_state.intersect_ray(ray)
	if not hit.is_empty():
		end_world = hit["position"]
	var p1: Vector2 = to_local(start_world)
	var p2: Vector2 = to_local(end_world)
	draw_line(p1, p2, Color(1.0, 0.16, 0.16, 0.45), 1.6)
	draw_circle(p2, 2.8, Color(1.0, 0.25, 0.22, 0.78))


func _spawn_blood_splatter() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var puff := BloodPuff.new()
	puff.global_position = global_position
	parent_node.add_child(puff)


func _spawn_damage_popup(dmg: int) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % dmg
	lbl.global_position = global_position + Vector2(randf_range(-12.0, 12.0), -36.0)
	lbl.z_index = 40
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.modulate = Color(1.0, 0.85, 0.22)
	parent_node.add_child(lbl)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 28.0, 0.55)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55)
	tw.finished.connect(lbl.queue_free)


func trigger_taunt(override_taunt_id: int = -1) -> void:
	if is_dead or _taunt_cooldown > 0.0:
		return
	var t_id: int = override_taunt_id if override_taunt_id >= 0 else (archetype_id if NetworkManager.is_agent_clash_mode() else taunt_id)
	_taunt_cooldown = 2.2
	if NetworkManager.is_network_active():
		trigger_taunt_rpc.rpc(t_id)
	else:
		_play_taunt_local(t_id)


@rpc("any_peer", "call_local", "reliable")
func trigger_taunt_rpc(t_id: int) -> void:
	_play_taunt_local(t_id)


func _play_taunt_local(t_id: int) -> void:
	var t: Dictionary = AgentData.get_taunt(t_id)
	_taunt_timer = 1.5
	_taunt_anim = str(t.get("anim", "dance"))
	var col: Color = t.get("color", Color.WHITE) as Color
	var sfx_kind: String = str(t.get("sfx", "pop"))
	_play_taunt_sfx(sfx_kind)

	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	if _taunt_anim == "fart" or _taunt_anim == "burp":
		var puff_pos: Vector2 = global_position + Vector2(-18.0 if facing_right else 18.0, 10.0)
		_spawn_vfx_burst(puff_pos, 48.0, col)
	elif _taunt_anim == "salute":
		_spawn_vfx_burst(global_position + Vector2(0.0, -24.0), 42.0, Color(1.0, 0.35, 0.25))
	elif _taunt_anim in ["dance", "disco", "hot_foot", "slap_knee", "laugh"]:
		_spawn_vfx_burst(global_position + Vector2(0.0, -20.0), 44.0, col)
	else:
		_spawn_vfx_burst(global_position + Vector2(0.0, -18.0), 34.0, col)

	var bubble := Label.new()
	var em_txt: String = str(t.get("emoji", ""))
	var over_txt: String = "EZZ!" if t_id == 0 else str(t.get("text", ""))
	bubble.text = "%s %s" % [em_txt, over_txt]
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.custom_minimum_size = Vector2(140.0, 30.0)
	bubble.global_position = global_position + Vector2(-70.0, -82.0)
	bubble.pivot_offset = Vector2(70.0, 15.0)
	bubble.scale = Vector2(0.55, 0.55)
	bubble.z_index = 45
	bubble.add_theme_font_size_override("font_size", 20)
	bubble.add_theme_color_override("font_outline_color", Color.BLACK)
	bubble.add_theme_constant_override("outline_size", 5)
	bubble.modulate = col
	parent_node.add_child(bubble)
	var tw := bubble.create_tween().set_parallel(true)
	tw.tween_property(bubble, "scale", Vector2(1.15, 1.15), 0.14)
	tw.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.14).set_delay(0.14)
	tw.tween_property(bubble, "position:y", bubble.position.y - 30.0, 1.45)
	tw.tween_property(bubble, "modulate:a", 0.0, 1.45).set_delay(0.65)
	tw.finished.connect(bubble.queue_free)


func _spawn_barbarian_squad(origin: Vector2, cast_angle: float, dmg: int, dur: float, col: Color, ab_name: String, local_auth: bool) -> void:
	var dir_x: float = 1.0 if cos(cast_angle) >= 0.0 else -1.0
	for bi in range(3):
		if not is_inside_tree() or is_dead:
			return
		_spawn_summon("barbarian", origin + Vector2(dir_x * 18.0, -8.0), dmg, dur, col, ab_name, local_auth)
		if bi < 2:
			await get_tree().create_timer(0.45).timeout


func _play_taunt_sfx(kind: String) -> void:
	if _audio_sfx == null or not is_instance_valid(_audio_sfx):
		return
	var sr: int = 22050
	var dur: float = 0.24 if kind == "fart" else 0.16
	var count: int = int(sr * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(sr)
		var env: float = 1.0 - (float(i) / float(count))
		var s: float = 0.0
		match kind:
			"fart":
				var freq: float = lerpf(115.0, 62.0, float(i) / float(count))
				s = sin(TAU * freq * t) * 0.55 + sin(TAU * (freq * 2.1) * t) * 0.35
			"huh":
				var freq: float = lerpf(320.0, 620.0, float(i) / float(count))
				s = sin(TAU * freq * t) * 0.45
			"laugh":
				var pulse: float = 0.5 + 0.5 * sin(TAU * 14.0 * t)
				s = sin(TAU * 540.0 * t) * pulse * 0.45
			"roar":
				s = sin(TAU * 145.0 * t) * 0.5 + sin(TAU * 210.0 * t) * 0.25
			_:
				var freq: float = 520.0 if (i < count / 2) else 760.0
				s = sin(TAU * freq * t) * 0.42
		var sample_i: int = clampi(int(s * env * 28000.0), -32768, 32767)
		data.encode_s16(i * 2, sample_i)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.data = data
	_audio_sfx.stream = wav
	_audio_sfx.pitch_scale = 1.0
	_audio_sfx.play()


class BloodPuff extends Node2D:
	var _drops: Array[Dictionary] = []
	var _age: float = 0.0

	func _ready() -> void:
		z_index = 18
		for _i in range(6):
			var ang: float = randf_range(0.0, TAU)
			var spd: float = randf_range(55.0, 175.0)
			_drops.append({"pos": Vector2.ZERO, "vel": Vector2.from_angle(ang) * spd, "r": randf_range(2.2, 4.2)})

	func _process(delta: float) -> void:
		_age += delta
		if _age >= 0.36:
			queue_free()
			return
		for d in _drops:
			d["vel"] = (d["vel"] as Vector2) + Vector2(0.0, 420.0) * delta
			d["pos"] = (d["pos"] as Vector2) + (d["vel"] as Vector2) * delta
		queue_redraw()

	func _draw() -> void:
		var a: float = 1.0 - (_age / 0.36)
		var col := Color(0.86, 0.08, 0.10, a)
		for d in _drops:
			draw_circle(d["pos"] as Vector2, float(d["r"]), col)


class AgentWeaponVisual extends Node2D:
	const TEX_REAPER_SCYTHE: Texture2D = preload("res://assets/sprites/weapons/reaper_scythe.png")
	const TEX_MAGMA_HAMMER: Texture2D = preload("res://assets/sprites/weapons/magma_hammer.png")
	const TEX_RAVEN_BOW: Texture2D = preload("res://assets/sprites/weapons/raven_shadow_bow.png")
	const TEX_ORC_SKULL_CRUSHER: Texture2D = preload("res://assets/sprites/weapons/orc_skull_crusher.png")
	const TEX_JACKSON_GLOVE: Texture2D = preload("res://assets/sprites/weapons/jackson_boxing_glove.png")
	const TEX_YAGAMI_KATANA: Texture2D = preload("res://assets/sprites/weapons/yagami_katana.png")
	const TEX_ROOK_FROST_BLADE: Texture2D = preload("res://assets/sprites/weapons/rook_frost_blade.png")
	const TEX_AFERA_SPEAR: Texture2D = preload("res://assets/sprites/weapons/afera_tribal_spear.png")
	const TEX_WEAPONS_SHEET_VIS: Texture2D = preload("res://assets/sprites/weapons_sheet.png")
	var weapon_style: String = "sword"
	var weapon_color: Color = Color(0.85, 0.90, 0.98)
	var _flame_t: float = 0.0

	func _process(delta: float) -> void:
		if weapon_style == "magma_hammer":
			_flame_t += delta * 14.0
			queue_redraw()

	func _draw() -> void:
		match weapon_style:
			"deagle":
				var ws: Vector2 = TEX_WEAPONS_SHEET_VIS.get_size()
				var fw: float = ws.x / 11.0
				var fh: float = ws.y / 3.0
				draw_texture_rect_region(TEX_WEAPONS_SHEET_VIS, Rect2(-6.0, -14.0, 56.0, 28.0), Rect2(9.0 * fw, 0.0, fw, fh))
			"afera_spear":
				draw_set_transform(Vector2(10.0, 2.0), -0.18, Vector2.ONE)
				draw_texture_rect(TEX_AFERA_SPEAR, Rect2(-22.0, -5.5, 76.0, 11.0), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"rook_frost_blade":
				draw_set_transform(Vector2(14.0, 4.0), -0.40, Vector2.ONE)
				draw_texture_rect(TEX_ROOK_FROST_BLADE, Rect2(-6.0, -10.0, 48.0, 20.0), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"yagami_katana":
				draw_set_transform(Vector2(14.0, 4.0), -0.45, Vector2.ONE)
				draw_texture_rect(TEX_YAGAMI_KATANA, Rect2(-6.0, -7.0, 52.0, 14.0), false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"boxing_glove":
				draw_texture_rect(TEX_JACKSON_GLOVE, Rect2(2.0, -16.0, 32.0, 32.0), false)
			"greatsword":
				draw_line(Vector2(4, 0), Vector2(44, 0), weapon_color, 7.0)
				draw_colored_polygon(PackedVector2Array([Vector2(42, -5), Vector2(54, 0), Vector2(42, 5)]), Color.WHITE)
				draw_line(Vector2(10, -8), Vector2(10, 8), Color(0.95, 0.78, 0.28), 4.0)
			"orc_axe":
				draw_texture_rect(TEX_ORC_SKULL_CRUSHER, Rect2(-6.0, -17.0, 52.0, 34.0), false)
			"axe":
				var ink_a := Color(0.06, 0.05, 0.09)
				draw_line(Vector2(2, 0), Vector2(38, 0), ink_a, 7.5)
				draw_line(Vector2(4, 0), Vector2(36, 0), Color(0.48, 0.28, 0.14), 4.0)
				draw_colored_polygon(PackedVector2Array([Vector2(21, -15), Vector2(41, -10), Vector2(41, 12), Vector2(21, 14)]), ink_a)
				draw_colored_polygon(PackedVector2Array([Vector2(24, -12), Vector2(38, -8), Vector2(38, 10), Vector2(24, 11)]), weapon_color)
				draw_colored_polygon(PackedVector2Array([Vector2(33, -7), Vector2(38, -8), Vector2(38, 10), Vector2(33, 9)]), weapon_color.lightened(0.35))
			"bow":
				draw_texture_rect(TEX_RAVEN_BOW, Rect2(2.0, -24.0, 32.0, 48.0), false)
			"scythe":
				draw_texture_rect(TEX_REAPER_SCYTHE, Rect2(-12.0, -9.0, 56.0, 32.0), false)
			"spear":
				draw_line(Vector2(0, 0), Vector2(38, 0), Color(0.65, 0.45, 0.22), 3.5)
				draw_colored_polygon(PackedVector2Array([Vector2(36, -5), Vector2(50, 0), Vector2(36, 5)]), weapon_color)
			"magma_hammer":
				draw_texture_rect(TEX_MAGMA_HAMMER, Rect2(-12.0, -14.0, 56.0, 32.0), false)
				var h_center := Vector2(31.0, 1.0)
				for fi in range(5):
					var ang: float = -1.7 + float(fi) * 0.85
					var dir_v := Vector2.from_angle(ang)
					var sway: float = sin(_flame_t * 1.2 + float(fi) * 1.9) * 2.6
					var h: float = 7.5 + sin(_flame_t * 1.5 + float(fi) * 2.3) * 3.0
					var base := h_center + dir_v * 11.0
					var perp := Vector2(-dir_v.y, dir_v.x)
					var tip := base + dir_v * h + perp * sway
					var pts := PackedVector2Array([
						base - perp * 3.2,
						base + dir_v * (h * 0.55) - perp * 1.8 + perp * (sway * 0.4),
						tip,
						base + dir_v * (h * 0.55) + perp * 1.8 + perp * (sway * 0.4),
						base + perp * 3.2,
					])
					draw_colored_polygon(pts, Color(1.0, 0.36, 0.05, 0.82))
					var core := PackedVector2Array([
						base - perp * 1.6,
						base + dir_v * (h * 0.7) + perp * (sway * 0.45),
						base + perp * 1.6,
					])
					draw_colored_polygon(core, Color(1.0, 0.86, 0.24, 0.88))
			"hammer":
				draw_line(Vector2(4, 0), Vector2(34, 0), Color(0.50, 0.30, 0.15), 4.0)
				draw_rect(Rect2(28.0, -11.0, 13.0, 22.0), weapon_color)
			"staff":
				draw_line(Vector2(-6, 0), Vector2(42, 0), Color(0.75, 0.50, 0.24), 4.5)
				draw_circle(Vector2(42, 0), 4.0, weapon_color)
			"claws", "daggers":
				draw_line(Vector2(10, -5), Vector2(28, -7), weapon_color, 3.0)
				draw_line(Vector2(10, 0), Vector2(30, 0), weapon_color, 3.0)
				draw_line(Vector2(10, 5), Vector2(28, 7), weapon_color, 3.0)
			_:
				draw_line(Vector2(6, 0), Vector2(36, 0), weapon_color, 4.5)
				draw_colored_polygon(PackedVector2Array([Vector2(35, -3), Vector2(44, 0), Vector2(35, 3)]), Color.WHITE)
				draw_line(Vector2(10, -6), Vector2(10, 6), Color(0.95, 0.78, 0.28), 3.0)


class BarrierWall extends StaticBody2D:
	var hp: int = 240
	var max_hp: int = 240
	var time_left: float = 5.5
	var wall_color: Color = Color(0.42, 0.86, 1.0)

	func setup_wall(w_hp: int, duration: float, col: Color) -> void:
		max_hp = maxi(40, w_hp)
		hp = max_hp
		time_left = duration
		wall_color = col
		collision_layer = 1
		collision_mask = 0
		add_to_group("barrier_walls")
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(34.0, 144.0)
		cs.shape = rect
		add_child(cs)
		queue_redraw()

	func _process(delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0:
			queue_free()

	func apply_wall_damage(dmg: int) -> void:
		hp -= maxi(1, dmg)
		queue_redraw()
		if hp <= 0:
			queue_free()

	func _draw() -> void:
		var r := Rect2(-17.0, -72.0, 34.0, 144.0)
		draw_rect(r, Color(wall_color.r, wall_color.g, wall_color.b, 0.78))
		draw_rect(r, Color.WHITE, false, 2.5)
		var hp_frac: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
		draw_rect(Rect2(-16.0, -82.0, 32.0 * hp_frac, 5.0), wall_color.lightened(0.35))


class TelekinesisDragEffect extends Node2D:
	var caster: Node2D = null
	var start_pos: Vector2 = Vector2.ZERO
	var cast_angle: float = 0.0
	var grab_style: String = "raven_stone"
	var dmg: int = 38
	var col: Color = Color(0.68, 0.35, 0.98)
	var ab_name: String = "Dark Telekinesis"
	var local_auth: bool = false

	var _elapsed: float = 0.0
	var _drag_dur: float = 0.36
	var _obj_pos: Vector2 = Vector2.ZERO

	func _ready() -> void:
		_obj_pos = start_pos
		global_position = Vector2.ZERO

	func _process(delta: float) -> void:
		_elapsed += delta
		var hold_pos: Vector2 = (caster.global_position + Vector2(0, -34)) if is_instance_valid(caster) else start_pos
		var t: float = clampf(_elapsed / _drag_dur, 0.0, 1.0)
		_obj_pos = start_pos.lerp(hold_pos, t * t * (3.0 - 2.0 * t))
		queue_redraw()
		if _elapsed >= _drag_dur:
			_launch_object()
			queue_free()

	func _launch_object() -> void:
		var parent_node: Node = get_parent()
		if parent_node == null or not is_instance_valid(caster):
			return
		var target: Node2D = caster._find_nearest_enemy_player(_obj_pos, 1400.0) if caster.has_method("_find_nearest_enemy_player") else null
		var throw_dir: Vector2 = (target.global_position - _obj_pos).normalized() if target != null else Vector2.from_angle(cast_angle)
		var b := BULLET_SCENE.instantiate()
		b.global_position = _obj_pos
		b.velocity = throw_dir * 980.0
		b.damage = dmg
		b.shooter_peer_id = int(caster.get("peer_id"))
		b.shooter_team = int(caster.get("team_id"))
		b.shooter_name = str(caster.get("player_name"))
		b.shooter_rid = (caster as CollisionObject2D).get_rid() if caster is CollisionObject2D else RID()
		b.weapon_name = ab_name
		b.bullet_color = col
		b.visual_style = grab_style
		if grab_style == "prop_barrel":
			b.is_explosive = true
			b.explosion_radius = 140.0
			b.damage = 65
			b.bullet_color = Color(1.0, 0.45, 0.14)
		b.spin_speed = 11.0
		b.gravity_mult = 0.25
		b.knockback_mult = 1.65
		b.allow_self_damage = false
		b.can_deal_damage = local_auth
		b.max_lifetime = 2.0
		parent_node.add_child(b)

	func _draw() -> void:
		if is_instance_valid(caster):
			draw_line(caster.global_position + Vector2(0, -10), _obj_pos, Color(col.r, col.g, col.b, 0.78), 3.0)
		draw_circle(_obj_pos, 18.0, Color(col.r, col.g, col.b, 0.30))
		draw_arc(_obj_pos, 16.0, 0.0, TAU, 20, col, 2.5)
		match grab_style:
			"prop_chair":
				draw_line(_obj_pos + Vector2(-10, -16), _obj_pos + Vector2(-10, 12), Color(0.55, 0.60, 0.68), 4.0)
				draw_rect(Rect2(_obj_pos + Vector2(-11, -16), Vector2(6, 14)), Color(0.28, 0.45, 0.72))
				draw_rect(Rect2(_obj_pos + Vector2(-10, -3), Vector2(22, 6)), Color(0.28, 0.45, 0.72))
			"prop_wood":
				draw_rect(Rect2(_obj_pos - Vector2(13, 6), Vector2(26, 12)), Color(0.46, 0.28, 0.14))
				draw_rect(Rect2(_obj_pos - Vector2(13, 6), Vector2(26, 12)), Color(0.24, 0.14, 0.07), false, 2.0)
			"prop_coconut":
				draw_circle(_obj_pos, 10.0, Color(0.40, 0.24, 0.12))
				draw_circle(_obj_pos + Vector2(-3, -3), 3.0, Color(0.54, 0.34, 0.18))
			"prop_barrel":
				draw_rect(Rect2(_obj_pos - Vector2(12, 16), Vector2(24, 32)), Color(0.82, 0.20, 0.16))
				draw_rect(Rect2(_obj_pos - Vector2(12, 16), Vector2(24, 32)), Color(0.20, 0.22, 0.26), false, 2.0)
				draw_line(_obj_pos + Vector2(-12, -5), _obj_pos + Vector2(12, -5), Color(0.95, 0.76, 0.20), 3.5)
			"prop_pot":
				draw_circle(_obj_pos + Vector2(0, 2), 9.5, Color(0.74, 0.42, 0.24))
				draw_rect(Rect2(_obj_pos + Vector2(-6, -10), Vector2(12, 5)), Color(0.64, 0.35, 0.19))
			"prop_ice_block":
				draw_rect(Rect2(_obj_pos - Vector2(10, 10), Vector2(20, 20)), Color(0.62, 0.88, 1.0, 0.88))
				draw_rect(Rect2(_obj_pos - Vector2(10, 10), Vector2(20, 20)), Color(0.92, 0.98, 1.0), false, 2.0)
			"prop_crate":
				draw_rect(Rect2(_obj_pos - Vector2(10, 10), Vector2(20, 20)), Color(0.26, 0.34, 0.46))
				draw_rect(Rect2(_obj_pos - Vector2(10, 10), Vector2(20, 20)), Color(0.38, 0.86, 0.98), false, 2.0)
			"prop_stone":
				draw_rect(Rect2(_obj_pos - Vector2(10, 8), Vector2(20, 16)), Color(0.54, 0.52, 0.48))
				draw_rect(Rect2(_obj_pos - Vector2(10, 8), Vector2(20, 16)), Color(0.30, 0.28, 0.25), false, 2.0)
			_:
				# Black & purple Raven-themed obsidian stone
				var rs := PackedVector2Array([
					_obj_pos + Vector2(-12, -3), _obj_pos + Vector2(-5, -12), _obj_pos + Vector2(7, -10),
					_obj_pos + Vector2(13, 1), _obj_pos + Vector2(6, 11), _obj_pos + Vector2(-8, 10)
				])
				draw_colored_polygon(rs, Color(0.12, 0.11, 0.16))
				draw_line(_obj_pos + Vector2(-6, -2), _obj_pos + Vector2(2, 3), Color(0.76, 0.34, 1.0), 2.5)
				draw_line(_obj_pos + Vector2(2, 3), _obj_pos + Vector2(7, -4), Color(0.90, 0.65, 1.0), 1.8)


class RisingParticleVfx extends Node2D:
	var part_color: Color = Color(0.28, 0.98, 0.48)
	var is_heal: bool = false
	var count: int = 8
	var _particles: Array[Dictionary] = []
	var _age: float = 0.0
	var _life: float = 0.75

	func _ready() -> void:
		z_index = 25
		for _i in range(count):
			_particles.append({
				"pos": Vector2(randf_range(-24.0, 24.0), randf_range(-16.0, 18.0)),
				"vel": Vector2(randf_range(-18.0, 18.0), randf_range(-78.0, -42.0)),
				"sz": randf_range(4.5, 7.5)
			})
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _life:
			queue_free()
			return
		for p in _particles:
			p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		queue_redraw()

	func _draw() -> void:
		var a: float = clampf(1.0 - (_age / _life), 0.0, 1.0)
		var c := Color(part_color.r, part_color.g, part_color.b, a)
		var w := Color(1.0, 1.0, 1.0, a * 0.85)
		for p in _particles:
			var pt: Vector2 = p["pos"] as Vector2
			var sz: float = float(p["sz"])
			if is_heal:
				draw_line(pt + Vector2(-sz, 0), pt + Vector2(sz, 0), c, 3.0)
				draw_line(pt + Vector2(0, -sz), pt + Vector2(0, sz), c, 3.0)
			else:
				draw_circle(pt, sz * 0.65, c)
				draw_circle(pt, sz * 0.28, w)


class AirWaveCircleVfx extends Node2D:
	var max_radius: float = 320.0
	var wave_color: Color = Color(0.55, 0.90, 1.0)
	var cryo_active: bool = false
	var eq_active: bool = false
	var eq_dur: float = 5.0
	var eq_dps: int = 170
	var eq_label: String = "Earthquake Sphere"
	var eq_caster_name: String = ""
	var cryo_can_apply: bool = false
	var cryo_caster_id: int = 0
	var cryo_team_id: int = -1
	var _cryo_hit_pids: Dictionary = {}
	var _age: float = 0.0
	var _life: float = 0.42

	func _ready() -> void:
		z_index = 25
		if eq_active:
			_life = 0.55
		if cryo_active or eq_active:
			_check_wave_hits(48.0)
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		if cryo_active or eq_active:
			var t_cur: float = clampf(_age / _life, 0.0, 1.0)
			var ease_cur: float = 1.0 - pow(1.0 - t_cur, 2.5)
			_check_wave_hits(maxf(48.0, max_radius * ease_cur))
		if _age >= _life:
			queue_free()
			return
		queue_redraw()

	func _check_wave_hits(cur_rad: float) -> void:
		if not is_inside_tree():
			return
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p):
				continue
			var pid: int = int(p.get("peer_id"))
			if pid == cryo_caster_id or _cryo_hit_pids.has(pid):
				continue
			if p.has_method("is_alive") and not p.is_alive():
				continue
			if NetworkManager.is_team_mode() and int(p.get("team_id")) == cryo_team_id:
				continue
			if (p as Node2D).global_position.distance_to(global_position) <= cur_rad:
				_cryo_hit_pids[pid] = true
				var parent_node: Node = get_parent()
				if cryo_active:
					if cryo_can_apply and p.has_method("apply_status"):
						p.apply_status("freeze", 3.0)
						p.apply_status("cryo_shatter", 3.0, float(cryo_caster_id))
					if parent_node != null:
						var rp := RisingParticleVfx.new()
						rp.global_position = (p as Node2D).global_position
						rp.part_color = Color(0.45, 0.90, 1.0)
						rp.count = 12
						parent_node.add_child(rp)
				elif eq_active and parent_node != null:
					var hz := Node2D.new()
					hz.set_script(load("res://scripts/PlatformHazardZone.gd"))
					hz.set("zone_kind", "earth_quake_zone")
					hz.global_position = (p as Node2D).global_position
					hz.set("time_left", eq_dur)
					hz.set("radius", 155.0)
					hz.set("dps", eq_dps)
					hz.set("shooter_id", cryo_caster_id)
					hz.set("shooter_team", cryo_team_id)
					hz.set("shooter_name", eq_caster_name)
					hz.set("weapon_name", eq_label)
					hz.set("can_deal", cryo_can_apply)
					parent_node.add_child(hz)

	func _draw() -> void:
		var t: float = clampf(_age / _life, 0.0, 1.0)
		var ease_t: float = 1.0 - pow(1.0 - t, 2.5)
		var a: float = clampf(1.0 - t, 0.0, 1.0)
		var r1: float = maxf(18.0, max_radius * ease_t)
		var r2: float = maxf(10.0, max_radius * maxf(0.0, ease_t - 0.18))
		draw_circle(Vector2.ZERO, r1, Color(wave_color.r, wave_color.g, wave_color.b, a * 0.14))
		draw_arc(Vector2.ZERO, r1, 0.0, TAU, 48, Color(wave_color.r, wave_color.g, wave_color.b, a * 0.85), 5.0)
		var inner_col: Color = Color(0.95, 0.68, 0.30, a * 0.90) if eq_active else Color(0.95, 0.99, 1.0, a * 0.90)
		draw_arc(Vector2.ZERO, r2, 0.0, TAU, 40, inner_col, 3.5)
		if eq_active and ease_t > 0.34:
			var r3: float = maxf(10.0, max_radius * (ease_t - 0.34))
			draw_arc(Vector2.ZERO, r3, 0.0, TAU, 36, Color(0.62, 0.36, 0.14, a * 0.80), 3.0)


class IceBlockOverlay extends Node2D:
	func _ready() -> void:
		z_index = 12
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-26.0, -38.0, 52.0, 68.0)
		draw_rect(r, Color(0.32, 0.82, 1.0, 0.42))
		draw_rect(r, Color(0.85, 0.98, 1.0, 0.90), false, 2.5)
		draw_line(Vector2(-18.0, -28.0), Vector2(-6.0, -12.0), Color(1.0, 1.0, 1.0, 0.65), 3.0)
		draw_line(Vector2(6.0, -24.0), Vector2(18.0, -6.0), Color(1.0, 1.0, 1.0, 0.50), 2.5)
		draw_line(Vector2(-16.0, 6.0), Vector2(2.0, 22.0), Color(1.0, 1.0, 1.0, 0.45), 2.5)


class StatusAuraOverlay extends Node2D:
	var aura_color: Color = Color(1.0, 0.14, 0.14)

	func _ready() -> void:
		z_index = 11
		queue_redraw()

	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.016)
		var aura_r: float = 34.0 + pulse * 4.0
		var edge_col: Color = aura_color.lightened(0.18)
		draw_circle(Vector2(0.0, -4.0), aura_r, Color(aura_color.r, aura_color.g, aura_color.b, 0.16 + pulse * 0.10))
		draw_arc(Vector2(0.0, -4.0), aura_r, 0.0, TAU, 28, Color(edge_col.r, edge_col.g, edge_col.b, 0.65 + pulse * 0.22), 2.2)


class SoulHarvestVfx extends Node2D:
	var caster: Node2D = null
	var victim: Node2D = null
	var dir_x: float = 1.0
	var _age: float = 0.0
	var _life: float = 1.25

	func _ready() -> void:
		z_index = 26
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _life or not is_instance_valid(caster) or not is_instance_valid(victim):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(caster) or not is_instance_valid(victim):
			return
		var c_hand: Vector2 = to_local(caster.global_position + Vector2(dir_x * 10.0, -4.0))
		var v_heart: Vector2 = to_local(victim.global_position + Vector2(0.0, -4.0))
		if _age < 0.22:
			# Spectral pull tether
			draw_line(c_hand, v_heart, Color(0.45, 0.90, 1.0, 0.85), 3.0)
			return
		var t: float = clampf((_age - 0.22) / 1.0, 0.0, 1.0)
		# Wraith spectral hands reaching onto victim's heart/chest
		var reach_pos: Vector2 = c_hand.lerp(v_heart, clampf(t * 4.0, 0.0, 1.0))
		draw_line(c_hand + Vector2(0.0, -4.0), reach_pos + Vector2(0.0, -3.0), Color(0.35, 0.82, 1.0, 0.88), 4.5)
		draw_line(c_hand + Vector2(0.0, 4.0), reach_pos + Vector2(0.0, 3.0), Color(0.35, 0.82, 1.0, 0.88), 4.5)
		draw_circle(reach_pos, 5.5, Color(0.55, 0.94, 1.0, 0.92))
		# Glowing white soul ball pulled from victim's heart toward Wraith
		var soul_pos: Vector2 = v_heart.lerp(c_hand, t * 0.85) + Vector2(0.0, -sin(t * PI) * 14.0)
		var pulse: float = 0.5 + 0.5 * sin(_age * 28.0)
		draw_circle(soul_pos, 15.0 + pulse * 3.0, Color(0.72, 0.95, 1.0, 0.30))
		draw_circle(soul_pos, 9.5 + pulse * 1.5, Color(1.0, 1.0, 1.0, 0.78))
		draw_circle(soul_pos, 5.5, Color.WHITE)
		draw_line(v_heart, soul_pos, Color(1.0, 1.0, 1.0, 0.55), 2.0)


class SpearImpaleVfx extends Node2D:
	var caster: Node2D = null
	var target_pos: Vector2 = Vector2.ZERO
	var _age: float = 0.0
	var _life: float = 0.65

	func _ready() -> void:
		z_index = 26
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _life or not is_instance_valid(caster):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(caster):
			return
		if _age >= 0.36:
			var t_local: Vector2 = to_local(target_pos + Vector2(0.0, -6.0))
			var alpha: float = clampf(1.0 - maxf(0.0, (_age - 0.36) / 0.29), 0.0, 1.0)
			var imp_p: float = (_age - 0.36) / 0.29
			draw_arc(t_local, lerpf(10.0, 56.0, imp_p), 0.0, TAU, 24, Color(1.0, 0.65, 0.18, alpha * 0.85), 3.5)


class BoxingFistVfx extends Node2D:
	const TEX_GLOVE: Texture2D = preload("res://assets/sprites/weapons/jackson_boxing_glove.png")
	var start_pos: Vector2 = Vector2.ZERO
	var end_pos: Vector2 = Vector2.ZERO
	var fist_angle: float = 0.0
	var fist_scale: float = 1.5
	var slam_time: float = 0.18
	var _age: float = 0.0
	var _hold_fade: float = 0.32

	func _ready() -> void:
		z_index = 26
		rotation = fist_angle
		scale = Vector2(fist_scale, fist_scale)
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		var total_life: float = slam_time + _hold_fade
		if _age >= total_life:
			queue_free()
			return
		var t: float = clampf(_age / maxf(0.01, slam_time), 0.0, 1.0)
		global_position = start_pos.lerp(end_pos, t * t)
		queue_redraw()

	func _draw() -> void:
		var a: float = clampf(1.0 - maxf(0.0, (_age - slam_time) / _hold_fade), 0.0, 1.0)
		draw_circle(Vector2(2.0, 0.0), 26.0, Color(0.28, 0.62, 1.0, 0.24 * a))
		draw_texture_rect(TEX_GLOVE, Rect2(-26.0, -26.0, 52.0, 52.0), false, Color(1.0, 1.0, 1.0, a))


func _spawn_prism_mirror(dur: float, col: Color) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var m := PrismMirrorShield.new()
	m.owner_node = self
	m.owner_peer_id = peer_id
	m.owner_team = team_id
	m.facing_dir = 1.0 if facing_right else -1.0
	m.mirror_color = col
	m.time_left = dur
	m.global_position = global_position + Vector2(m.facing_dir * 42.0, -4.0)
	parent_node.add_child(m)


class PrismMirrorShield extends StaticBody2D:
	var owner_node: Node2D = null
	var owner_peer_id: int = 0
	var owner_team: int = 0
	var facing_dir: float = 1.0
	var mirror_color: Color = Color(1.0, 0.58, 0.92)
	var time_left: float = 5.0

	func _ready() -> void:
		add_to_group("prism_mirrors")
		collision_layer = 2
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(18.0, 92.0)
		cs.shape = rs
		add_child(cs)
		queue_redraw()

	func _process(delta: float) -> void:
		time_left -= delta
		if time_left <= 0.0 or not is_instance_valid(owner_node) or bool(owner_node.get("is_dead")):
			queue_free()
			return
		facing_dir = 1.0 if bool(owner_node.get("facing_right")) else -1.0
		global_position = owner_node.global_position + Vector2(facing_dir * 42.0, -4.0)
		queue_redraw()

	func _draw() -> void:
		var a: float = clampf(time_left * 2.0, 0.25, 0.95)
		var frame_col := Color(0.95, 0.72, 1.0, a)
		var glass_col := Color(0.75, 0.94, 1.0, a * 0.55)
		draw_rect(Rect2(-7.0, -44.0, 14.0, 88.0), glass_col)
		draw_rect(Rect2(-7.0, -44.0, 14.0, 88.0), frame_col, false, 3.0)
		draw_line(Vector2(-3.0, -34.0), Vector2(3.0, -14.0), Color(1.0, 1.0, 1.0, a * 0.85), 2.5)
		draw_line(Vector2(-3.0, 4.0), Vector2(3.0, 24.0), Color(1.0, 1.0, 1.0, a * 0.85), 2.5)


func _spawn_time_freeze_wave(origin: Vector2, max_rad: float) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var w := TimeFreezeWaveVfx.new()
	w.global_position = origin
	w.max_radius = max_rad
	parent_node.add_child(w)


func execute_touch_teleport(target_pos: Vector2) -> void:
	if touch_teleport_timer <= 0.0 or is_dead:
		return
	touch_teleport_timer = 0.0
	_fire_cooldown = maxf(_fire_cooldown, 0.22)
	var safe_pos: Vector2 = _clamp_to_arena(target_pos)
	if NetworkManager.is_network_active():
		execute_touch_teleport_rpc.rpc(safe_pos)
	else:
		_execute_touch_teleport_local(safe_pos)


@rpc("any_peer", "call_local", "reliable")
func execute_touch_teleport_rpc(target_pos: Vector2) -> void:
	_execute_touch_teleport_local(target_pos)


func _execute_touch_teleport_local(target_pos: Vector2) -> void:
	var old_pos: Vector2 = global_position
	_spawn_air_wave_circle(old_pos, 72.0, Color(0.25, 0.78, 1.0))
	_spawn_rising_particles(old_pos, Color(0.35, 0.85, 1.0), false, 8)
	global_position = target_pos
	velocity = Vector2.ZERO
	_spawn_air_wave_circle(target_pos, 84.0, Color(0.25, 0.78, 1.0))
	_spawn_rising_particles(target_pos, Color(0.35, 0.85, 1.0), false, 12)
	_play_local_sfx("res://assets/audio/pickup.wav", 0.0, 1.45)


func execute_touch_fire(world_pos: Vector2) -> bool:
	if touch_fire_timer <= 0.0 or is_dead:
		return false
	touch_fire_timer = 0.0
	_fire_cooldown = maxf(_fire_cooldown, 0.22)
	var fire_pos: Vector2 = _clamp_to_arena(world_pos)
	if NetworkManager.is_network_active():
		execute_touch_fire_rpc.rpc(fire_pos)
	else:
		_execute_touch_fire_local(fire_pos)
	return true


@rpc("any_peer", "call_local", "reliable")
func execute_touch_fire_rpc(fire_pos: Vector2) -> void:
	_execute_touch_fire_local(fire_pos)


func _execute_touch_fire_local(fire_pos: Vector2) -> void:
	touch_fire_timer = 0.0
	var parent_fire: Node = get_parent()
	if parent_fire != null:
		var flame_fx := DragonTapFireVfx.new()
		flame_fx.fire_pos = fire_pos
		flame_fx.caster = self
		flame_fx.shooter_id = peer_id
		flame_fx.shooter_team = team_id
		flame_fx.shooter_name = player_name
		flame_fx.local_auth = _is_controlled_locally()
		parent_fire.add_child(flame_fx)
	_spawn_rising_particles(fire_pos, Color(1.0, 0.45, 0.12), false, 16)
	add_screen_shake(1.6)
	_play_local_sfx("res://assets/audio/explosion.wav", -2.0, 1.15)


func _pick_random_banish_pos(from_pos: Vector2) -> Vector2:
	if is_preview_dummy:
		var p_xs: Array[float] = [95.0, 175.0, 250.0, 385.0]
		var best_px: float = 220.0
		for cand_x in p_xs:
			if absf(cand_x - from_pos.x) >= 85.0:
				best_px = cand_x
				break
		return Vector2(best_px, randf_range(72.0, 142.0))
	if not _spawn_points.is_empty():
		var far_pts: Array[Vector2] = []
		for sp in _spawn_points:
			if sp.distance_to(from_pos) >= 280.0:
				far_pts.append(sp)
		if not far_pts.is_empty():
			var base_sp: Vector2 = far_pts[randi() % far_pts.size()]
			return _clamp_to_arena(base_sp + Vector2(randf_range(-65.0, 65.0), randf_range(-20.0, 10.0)))
		return _clamp_to_arena(_spawn_points[randi() % _spawn_points.size()])
	var bounds: Vector2 = _get_arena_bounds()
	var rx: float = randf_range(160.0, maxf(240.0, bounds.x - 160.0))
	var ry: float = randf_range(160.0, maxf(220.0, bounds.y - 180.0))
	return _clamp_to_arena(Vector2(rx, ry))


func execute_touch_banish(world_pos: Vector2) -> bool:
	if touch_banish_timer <= 0.0 or is_dead:
		return false
	touch_banish_timer = 0.0
	_fire_cooldown = maxf(_fire_cooldown, 0.22)
	var center_pos: Vector2 = _clamp_to_arena(world_pos)
	if NetworkManager.is_network_active():
		spawn_banish_circle_rpc.rpc(center_pos)
	else:
		_spawn_banish_circle_local(center_pos)
	return true


@rpc("any_peer", "call_local", "reliable")
func spawn_banish_circle_rpc(center_pos: Vector2) -> void:
	_spawn_banish_circle_local(center_pos)


func _spawn_banish_circle_local(center_pos: Vector2) -> void:
	touch_banish_timer = 0.0
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var zone := BanishTeleportCircleZone.new()
	zone.caster = self
	zone.caster_peer_id = peer_id
	zone.caster_team = team_id
	zone.local_auth = _is_controlled_locally()
	zone.radius = 115.0 if is_preview_dummy else 165.0
	zone.duration = 3.0
	zone.global_position = center_pos
	parent_node.add_child(zone)
	_spawn_air_wave_circle(center_pos, zone.radius, Color(0.84, 0.48, 1.0))
	_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 0.78)


func trigger_banish_on_victim(target_pid: int, dest_pos: Vector2) -> void:
	if NetworkManager.is_network_active():
		execute_touch_banish_rpc.rpc(target_pid, dest_pos)
	else:
		_execute_touch_banish_local(target_pid, dest_pos)


@rpc("any_peer", "call_local", "reliable")
func execute_touch_banish_rpc(target_pid: int, dest_pos: Vector2) -> void:
	_execute_touch_banish_local(target_pid, dest_pos)


func _execute_touch_banish_local(target_pid: int, dest_pos: Vector2) -> void:
	var target: Node2D = _find_player_by_peer_id(target_pid)
	if target == null or (target.has_method("is_alive") and not target.is_alive()):
		return
	var old_pos: Vector2 = target.global_position
	_spawn_air_wave_circle(old_pos, 90.0, Color(0.84, 0.48, 1.0))
	_spawn_vfx_burst(old_pos, 85.0, Color(0.78, 0.45, 1.0))
	_spawn_rising_particles(old_pos, Color(0.84, 0.56, 1.0), false, 14)
	target.global_position = dest_pos
	if "velocity" in target:
		target.set("velocity", Vector2.ZERO)
	if "banish_after_fx_timer" in target:
		target.set("banish_after_fx_timer", 1.0)
		target.set("_banish_fx_accum", 0.0)
	if _is_controlled_locally() and target.has_method("apply_hit"):
		target.apply_hit(10, peer_id, "Banish Teleport", player_name, Vector2.ZERO)
	_spawn_air_wave_circle(dest_pos, 95.0, Color(0.84, 0.48, 1.0))
	_spawn_vfx_burst(dest_pos, 75.0, Color(0.78, 0.45, 1.0), false, true)
	_spawn_rising_particles(dest_pos, Color(0.84, 0.56, 1.0), false, 18)
	_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 0.9)


class BanishTeleportCircleZone extends Node2D:
	var caster: Node2D = null
	var caster_peer_id: int = 0
	var caster_team: int = 0
	var local_auth: bool = false
	var radius: float = 165.0
	var duration: float = 3.0
	var _t: float = 0.0
	var _banished_cooldowns: Dictionary = {}

	func _ready() -> void:
		z_index = 14
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		if _t >= duration:
			queue_free()
			return
		for k in _banished_cooldowns.keys().duplicate():
			var rem: float = float(_banished_cooldowns[k]) - delta
			if rem <= 0.0:
				_banished_cooldowns.erase(k)
			else:
				_banished_cooldowns[k] = rem
		if local_auth and is_instance_valid(caster):
			for p in get_tree().get_nodes_in_group("players"):
				if not is_instance_valid(p) or p == caster or int(p.get("peer_id")) == caster_peer_id:
					continue
				if p.has_method("is_alive") and not p.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(p.get("team_id")) == caster_team:
					continue
				var pid: int = int(p.get("peer_id"))
				if _banished_cooldowns.has(pid):
					continue
				var p_node := p as Node2D
				if p_node.global_position.distance_to(global_position) <= radius:
					_banished_cooldowns[pid] = 0.45
					var dest: Vector2 = caster.call("_pick_random_banish_pos", p_node.global_position)
					caster.call("trigger_banish_on_victim", pid, dest)
		queue_redraw()

	func _draw() -> void:
		var rem: float = maxf(0.0, duration - _t)
		var fade: float = clampf(rem / 0.35, 0.0, 1.0) if rem < 0.35 else clampf(_t / 0.15, 0.25, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(_t * 10.0)
		var r: float = radius + sin(_t * 7.5) * 4.0
		# Swirling arcane portal field
		draw_circle(Vector2.ZERO, r, Color(0.56, 0.22, 0.92, 0.20 * fade))
		draw_circle(Vector2.ZERO, r * 0.65, Color(0.76, 0.38, 1.0, (0.12 + pulse * 0.08) * fade))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(0.84, 0.48, 1.0, 0.94 * fade), 4.5)
		draw_arc(Vector2.ZERO, r - 6.0, 0.0, TAU, 48, Color(0.45, 0.92, 1.0, (0.55 + pulse * 0.35) * fade), 2.2)
		# Rotating inner runes/segments
		for i in range(6):
			var a0: float = _t * 2.4 + float(i) * (TAU / 6.0)
			draw_arc(Vector2.ZERO, r * 0.52, a0, a0 + 0.55, 12, Color(0.95, 0.75, 1.0, 0.78 * fade), 3.0)
			var pt: Vector2 = Vector2.from_angle(-_t * 3.0 + float(i) * (TAU / 6.0)) * (r * 0.78)
			draw_circle(pt, 4.5, Color(0.92, 0.68, 1.0, 0.85 * fade))


class TimeFreezeWaveVfx extends Node2D:
	var max_radius: float = 460.0
	var _t: float = 0.0
	var _dur: float = 0.55

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var prog: float = clampf(_t / _dur, 0.0, 1.0)
		var r: float = lerpf(16.0, max_radius, prog)
		var a: float = 1.0 - prog * prog
		draw_circle(Vector2.ZERO, r, Color(0.22, 0.65, 1.0, 0.14 * a))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.32, 0.82, 1.0, 0.92 * a), 5.0)
		draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 36, Color(0.65, 0.92, 1.0, 0.55 * a), 2.5)


func _spawn_scream_wave_vfx(origin: Vector2, ang: float, max_rad: float, col: Color) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var w := ScreamWaveWifiVfx.new()
	w.global_position = origin
	w.aim_ang = ang
	w.max_radius = max_rad
	w.wave_color = col
	parent_node.add_child(w)


class ScreamWaveWifiVfx extends Node2D:
	var aim_ang: float = 0.0
	var max_radius: float = 320.0
	var wave_color: Color = Color(0.78, 0.98, 1.0)
	var _t: float = 0.0
	var _dur: float = 0.45

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var prog: float = clampf(_t / _dur, 0.0, 1.0)
		var half_arc: float = 0.62
		var segs: int = 36
		for arc_i in range(3):
			var local_p: float = clampf(prog * 1.25 - float(arc_i) * 0.14, 0.0, 1.0)
			if local_p <= 0.02:
				continue
			var r: float = lerpf(24.0, max_radius, local_p)
			var a: float = (1.0 - local_p) * 0.95
			var c := Color(wave_color.r, wave_color.g, wave_color.b, a)
			var pts := PackedVector2Array()
			for si in range(segs + 1):
				var frac: float = float(si) / float(segs)
				var ang: float = lerpf(aim_ang - half_arc, aim_ang + half_arc, frac)
				var ripple: float = sin(frac * TAU * 4.5 + _t * 28.0 + float(arc_i) * 1.4) * (9.0 + local_p * 5.0)
				pts.append(Vector2.from_angle(ang) * (r + ripple))
			draw_polyline(pts, c, 7.5 - float(arc_i) * 1.2)
			draw_polyline(pts, Color(0.92, 0.99, 1.0, a * 0.85), 2.4)


class DragonTapFireVfx extends Node2D:
	const TEX_FLAME_SHEET: Texture2D = preload("res://assets/sprites/vfx/inferno_anim_sheet.png")
	const FRAME_COUNT: int = 10
	const FRAME_W: float = 160.0
	const FRAME_H: float = 192.0
	var fire_pos: Vector2 = Vector2.ZERO
	var caster: Node2D = null
	var shooter_id: int = 0
	var shooter_team: int = -1
	var shooter_name: String = ""
	var local_auth: bool = false
	var burn_radius: float = 98.0
	var _t: float = 0.0
	var _dur: float = 2.0
	var _tick_accum: float = 0.15
	var _barrel_check_done: bool = false

	func _ready() -> void:
		z_index = 14
		global_position = Vector2.ZERO

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _dur:
			queue_free()
			return
		if local_auth:
			_tick_accum += delta
			if _tick_accum >= 0.25:
				_tick_accum -= 0.25
				for p in get_tree().get_nodes_in_group("players"):
					if not is_instance_valid(p) or p == caster:
						continue
					if p.has_method("is_alive") and not p.is_alive():
						continue
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
						continue
					if (p as Node2D).global_position.distance_to(fire_pos) <= burn_radius and p.has_method("apply_hit"):
						p.apply_hit(10, shooter_id, "Dragon Flame", shooter_name, Vector2(0.0, -30.0))
						if is_instance_valid(caster) and caster.has_method("gain_ult_charge"):
							caster.call("gain_ult_charge", 0.5)
			if not _barrel_check_done and _t >= 0.30:
				_barrel_check_done = true
				for b in get_tree().get_nodes_in_group("destructible_bombs"):
					if not is_instance_valid(b):
						continue
					if b.has_meta("prop_node"):
						var prop_n: Node2D = b.get_meta("prop_node") as Node2D
						if is_instance_valid(prop_n) and prop_n.global_position.distance_to(fire_pos) <= burn_radius + 22.0 and prop_n.has_method("detonate_barrel"):
							prop_n.call("detonate_barrel", shooter_id, shooter_name, shooter_team)
		queue_redraw()

	func _draw() -> void:
		var prog: float = clampf(_t / _dur, 0.0, 1.0)
		var alpha: float = 1.0 - maxf(0.0, (prog - 0.80) / 0.20)
		var f_idx: int = int(_t * 14.0) % FRAME_COUNT
		var src_rect := Rect2(float(f_idx) * FRAME_W, 0.0, FRAME_W, FRAME_H)
		var fw: float = 165.0
		var fh: float = 195.0
		draw_set_transform(fire_pos + Vector2(0.0, 56.0), 0.0, Vector2.ONE)
		draw_texture_rect_region(TEX_FLAME_SHEET, Rect2(-fw * 0.5, -fh, fw, fh), src_rect, Color(1.0, 1.0, 1.0, 0.96 * alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class InfernoGrabVfx extends Node2D:
	const TEX_FLAME_SHEET: Texture2D = preload("res://assets/sprites/vfx/inferno_anim_sheet.png")
	const FRAME_COUNT: int = 10
	const FRAME_W: float = 160.0
	const FRAME_H: float = 192.0
	var caster: Node2D = null
	var victim: Node2D = null
	var _t: float = 0.0
	var _dur: float = 1.55

	func _ready() -> void:
		z_index = 2
		global_position = Vector2.ZERO

	func _process(delta: float) -> void:
		_t += delta
		if _t >= _dur:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var prog: float = clampf(_t / _dur, 0.0, 1.0)
		var alpha: float = 1.0 - maxf(0.0, (prog - 0.80) / 0.20)
		if not is_instance_valid(caster):
			return
		var center: Vector2 = caster.global_position
		if is_instance_valid(victim):
			center = (caster.global_position + victim.global_position) * 0.5
		var f_idx: int = int(_t * 14.0) % FRAME_COUNT
		var src_rect := Rect2(float(f_idx) * FRAME_W, 0.0, FRAME_W, FRAME_H)
		var fw: float = 185.0
		var fh: float = 215.0
		draw_set_transform(center + Vector2(0.0, 62.0), 0.0, Vector2.ONE)
		draw_texture_rect_region(TEX_FLAME_SHEET, Rect2(-fw * 0.5, -fh, fw, fh), src_rect, Color(1.0, 1.0, 1.0, 0.96 * alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _perform_inferno_ult_on_victim(tgt_inf: Node2D, cast_pos: Vector2, ab_name: String, local_auth: bool) -> void:
	if is_dead or not is_instance_valid(tgt_inf):
		return
	if tgt_inf.has_method("is_alive") and not tgt_inf.is_alive():
		return
	var land_pos: Vector2 = global_position
	# Only snap onto the nearest platform if Ignis successfully hooked an enemy while airborne
	if not is_on_floor():
		var space_inf := get_world_2d().direct_space_state
		for dx_off in [0.0, 120.0, -120.0, 240.0, -240.0]:
			var ray_start: Vector2 = land_pos + Vector2(dx_off, -10.0)
			var ray_end: Vector2 = ray_start + Vector2(0.0, 900.0)
			var rq := PhysicsRayQueryParameters2D.create(ray_start, ray_end, 1)
			rq.collide_with_areas = false
			rq.collide_with_bodies = true
			var rhit: Dictionary = space_inf.intersect_ray(rq)
			if not rhit.is_empty():
				global_position = _clamp_to_arena((rhit["position"] as Vector2) + Vector2(0.0, -30.0))
				land_pos = global_position
				break
	control_lock_timer = 1.55
	gravity_lock_timer = 1.55
	velocity = Vector2.ZERO
	var dir_x: float = 1.0 if tgt_inf.global_position.x >= land_pos.x else -1.0
	facing_right = dir_x >= 0.0
	aim_angle = 0.0 if facing_right else PI
	var grab_pos: Vector2 = land_pos + Vector2(30.0 * dir_x, 0.0)
	if tgt_inf.has_method("apply_stun"):
		tgt_inf.apply_stun(1.55, peer_id)
	if "gravity_lock_timer" in tgt_inf:
		tgt_inf.set("gravity_lock_timer", 1.55)
		tgt_inf.set("velocity", Vector2.ZERO)
	var pull_tw := create_tween()
	pull_tw.tween_property(tgt_inf, "global_position", grab_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var parent_inf: Node = get_parent()
	if parent_inf != null:
		var ig_vfx := InfernoGrabVfx.new()
		ig_vfx.caster = self
		ig_vfx.victim = tgt_inf
		ig_vfx.global_position = land_pos
		parent_inf.add_child(ig_vfx)
	for ti in range(5):
		var burn_tw := create_tween()
		burn_tw.tween_interval(0.30 * float(ti + 1))
		burn_tw.finished.connect(func():
			if is_dead or not is_instance_valid(tgt_inf):
				return
			if tgt_inf.has_method("is_alive") and not tgt_inf.is_alive():
				return
			if local_auth and tgt_inf.has_method("apply_hit"):
				var mhp: float = float(tgt_inf.get("max_health")) if "max_health" in tgt_inf else 100.0
				var tick_dmg: int = maxi(20, int(ceil(mhp / 5.0)))
				tgt_inf.apply_hit(tick_dmg, peer_id, ab_name, player_name, Vector2.ZERO)
			_play_local_sfx("res://assets/audio/explosion.wav", -6.0, 1.35)
		)
	_play_local_sfx("res://assets/audio/explosion.wav", -1.0, 0.85)
	add_screen_shake(2.4)


class InfernoGrappleHook extends Node2D:
	var caster: Node2D = null
	var cast_pos: Vector2 = Vector2.ZERO
	var dir: Vector2 = Vector2.RIGHT
	var ab_name: String = ""
	var local_auth: bool = false
	var speed: float = 1220.0
	var max_dist: float = 440.0
	var _traveled: float = 0.0
	var _state: int = 0 # 0=flying, 1=pulling, 2=missed/retracting
	var _state_t: float = 0.0
	var _hooked_victim: Node2D = null
	var _tip_pos: Vector2 = Vector2.ZERO

	func _ready() -> void:
		z_index = 18
		_tip_pos = cast_pos
		global_position = Vector2.ZERO

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(caster) or (caster.has_method("is_alive") and not caster.is_alive()):
			queue_free()
			return
		if _state == 0:
			var step: float = speed * delta
			var prev_pos: Vector2 = _tip_pos
			var next_pos: Vector2 = prev_pos + dir * step
			_traveled += step

			# Check wall collision first
			var space := get_world_2d().direct_space_state
			var rq := PhysicsRayQueryParameters2D.create(prev_pos, next_pos, 1)
			rq.collide_with_areas = false
			rq.collide_with_bodies = true
			var wall_hit: Dictionary = space.intersect_ray(rq)
			var check_end: Vector2 = wall_hit["position"] if not wall_hit.is_empty() else next_pos

			# Check enemy player hit along segment
			var hit_enemy: Node2D = null
			var best_d: float = 30.0
			var caster_team: int = int(caster.get("team_id")) if "team_id" in caster else 0
			for node in get_tree().get_nodes_in_group("players"):
				if not (node is Node2D) or node == caster:
					continue
				if node.has_method("is_alive") and not node.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(node.get("team_id")) == caster_team:
					continue
				var npos: Vector2 = (node as Node2D).global_position
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(npos, prev_pos, check_end)
				var d: float = npos.distance_to(closest)
				if d <= best_d:
					best_d = d
					hit_enemy = node as Node2D

			if hit_enemy != null:
				_hooked_victim = hit_enemy
				_tip_pos = hit_enemy.global_position
				_state = 1
				_state_t = 0.0
				caster.call("_perform_inferno_ult_on_victim", hit_enemy, cast_pos, ab_name, local_auth)
			elif not wall_hit.is_empty() or _traveled >= max_dist:
				_tip_pos = check_end
				_state = 2
				_state_t = 0.0
			else:
				_tip_pos = next_pos
		elif _state == 1:
			_state_t += delta
			if is_instance_valid(_hooked_victim):
				_tip_pos = _hooked_victim.global_position
			if _state_t >= 0.24:
				queue_free()
				return
		elif _state == 2:
			_state_t += delta
			var origin_now: Vector2 = caster.global_position
			_tip_pos = _tip_pos.lerp(origin_now, clampf(_state_t / 0.14, 0.0, 1.0))
			if _state_t >= 0.14:
				queue_free()
				return
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(caster):
			return
		var start_pos: Vector2 = caster.global_position + Vector2(0.0, -4.0)
		var seg: Vector2 = _tip_pos - start_pos
		var seg_len: float = seg.length()
		if seg_len < 2.0:
			return
		var alpha: float = 1.0 if _state != 2 else clampf(1.0 - _state_t / 0.14, 0.0, 1.0)
		# Cel-shaded magma chain + glowing core
		draw_line(start_pos, _tip_pos, Color(0.14, 0.04, 0.02, 0.9 * alpha), 7.0)
		draw_line(start_pos, _tip_pos, Color(0.98, 0.34, 0.04, 0.95 * alpha), 4.0)
		draw_line(start_pos, _tip_pos, Color(1.0, 0.88, 0.35, 0.95 * alpha), 1.8)
		# Fiery grapple claw head
		var ang: float = seg.angle()
		var fwd: Vector2 = Vector2.from_angle(ang)
		var side: Vector2 = Vector2(-fwd.y, fwd.x)
		var claw := PackedVector2Array([
			_tip_pos + fwd * 10.0,
			_tip_pos - fwd * 6.0 + side * 9.0,
			_tip_pos - fwd * 2.0,
			_tip_pos - fwd * 6.0 - side * 9.0,
		])
		draw_colored_polygon(claw, Color(1.0, 0.72, 0.12, alpha))
		draw_polyline(claw + PackedVector2Array([claw[0]]), Color(0.14, 0.04, 0.02, alpha), 2.2)
