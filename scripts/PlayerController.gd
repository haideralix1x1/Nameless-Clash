extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal fuel_changed(current: float, maximum: float)
signal ammo_changed(current: int, mag_size: int, is_reloading: bool)
signal weapon_changed(weapon_data: WeaponData, dual_wield: bool)
signal died_signal(respawn_seconds: float)
signal respawned_signal
signal bombs_changed(count: int, bomb_type: String)
signal agent_state_changed(cooldowns: Array, max_cooldowns: Array, held_throwable: int, stun_left: float)

const BULLET_SCENE: PackedScene = preload("res://scenes/Bullet.tscn")
const EXPLOSION_SCENE: PackedScene = preload("res://scenes/Explosion.tscn")

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
const FUEL_CONSUME_RATE: float = 38.0
const FUEL_RECHARGE_GROUND: float = 48.0
const FUEL_RECHARGE_AIR: float = 14.0
const RESPAWN_TIME: float = 3.0
const MAX_SCREEN_SHAKE: float = 3.2

@export var peer_id: int = 1
@export var player_name: String = "Trooper"
@export var color_index: int = 0
@export var team_id: int = 0
@export var is_bot: bool = false
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
@export var is_dual_wielding: bool = false
@export var is_dead: bool = false
@export var anim_frame: int = 0

var max_health: int = 100
var current_ammo: int = 30
var is_reloading: bool = false
var spawn_invuln_timer: float = 0.0
var _equipped_primary_id: int = 0

# Virtual joystick overrides fed from HUD
var virtual_move: Vector2 = Vector2.ZERO
var virtual_jetpack: bool = false
var virtual_aim: Vector2 = Vector2.ZERO
var virtual_fire: bool = false
var pointer_over_ui: bool = false

var _weapon: WeaponData = WeaponData.get_weapon(0, 0, 0)
var _fire_cooldown: float = 0.0
var _reload_timer: float = 0.0
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
var _spawn_points: Array[Vector2] = []

const GRAB_PLAYER_RANGE: float = 92.0
const THROW_PLAYER_SPEED: float = 980.0
const THROWN_SELF_DAMAGE: int = 36
const THROWN_TARGET_DAMAGE: int = 44
const THROWN_WALL_DAMAGE: int = 22

# Agent Clash Mode state
var ability_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var ability_max_cooldowns: Array[float] = [6.0, 8.0, 8.5, 22.0]
var held_throwable_id: int = -1
var grabbed_player_id: int = 0
var carried_by_peer_id: int = 0
var _grab_hold_timer: float = 0.0
var _grab_cooldown: float = 0.0
var thrown_by_peer_id: int = 0
var thrown_by_name: String = ""
var thrown_by_team: int = -1
var thrown_flight_timer: float = 0.0
var _thrown_flight_elapsed: float = 0.0
var stun_timer: float = 0.0
var speed_boost_timer: float = 0.0
var speed_boost_mult: float = 1.0
var _melee_swing_timer: float = 0.0
var _agent_weapon_node: Node2D = null
var _agent_hud_sync_accum: float = 0.0

# Normal Gunfight Mode Preset & Bomb state
var selected_gun_preset_id: int = 0
var bomb_count: int = 3
var max_bombs: int = 3
var bomb_type: String = "frag"
var _bomb_cooldown: float = 0.0

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
	current_weapon_id = primary_weapon_id
	max_bombs = 3 if NetworkManager.allow_explosives else 0
	bomb_count = max_bombs
	weapon_skin_id = int(av["weapon_skin_id"])
	m4a1_rail_mod = int(av["m4a1_rail_mod"])

	var auth_id: int = 1 if p_id < 0 else p_id
	set_multiplayer_authority(auth_id)

	if p_is_bot:
		is_local_human = false
	elif not NetworkManager.is_network_active():
		is_local_human = true
	else:
		is_local_human = (p_id == multiplayer.get_unique_id())


func _ready() -> void:
	add_to_group("players")
	_init_agent_kit()
	_apply_modular_textures()
	_apply_weapon(current_weapon_id)
	_apply_team_visuals()
	_camera.enabled = is_local_human
	if is_local_human:
		_camera.make_current()
	_muzzle_flash.visible = false
	_update_overhead_ui()
	_emit_hud_signals()


func _init_agent_kit() -> void:
	ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
	var ag: Dictionary = AgentData.get_agent(archetype_id)
	var abils: Array = ag["abilities"]
	var ult: Dictionary = ag["ultimate"]
	ability_max_cooldowns = [
		float(abils[0]["cooldown"]),
		float(abils[1]["cooldown"]),
		float(abils[2]["cooldown"]),
		float(ult["cooldown"])
	]
	if _agent_weapon_node == null and is_instance_valid(_weapon_pivot):
		var vis := AgentWeaponVisual.new()
		vis.name = "AgentWeaponVisual"
		_weapon_pivot.add_child(vis)
		_agent_weapon_node = vis
	if _agent_weapon_node != null:
		var bw: Dictionary = ag["base_weapon"]
		_agent_weapon_node.set("weapon_style", str(bw["style"]))
		_agent_weapon_node.set("weapon_color", bw["color"] as Color)
		_agent_weapon_node.visible = NetworkManager.is_agent_clash_mode() and not is_dead
		_agent_weapon_node.queue_redraw()


func _apply_modular_textures() -> void:
	if not is_node_ready() or _modular_rig == null:
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

	if _shake_amount > 0.0:
		_shake_amount = maxf(0.0, _shake_amount - delta * 18.0)
	if is_local_human and is_instance_valid(_camera):
		var s: float = _shake_amount * SettingsManager.screen_shake_intensity
		var target_off: Vector2 = Vector2(randf_range(-s, s), randf_range(-s, s)) if s > 0.05 else Vector2.ZERO
		_camera.offset = _camera.offset.lerp(target_off, 0.45)
		var target_zoom_val: float = _weapon.scope_zoom if (not NetworkManager.is_agent_clash_mode() and not is_dead and _weapon != null) else 1.05
		var target_zoom := Vector2(target_zoom_val, target_zoom_val)
		_camera.zoom = _camera.zoom.lerp(target_zoom, clampf(delta * 8.0, 0.0, 1.0))

	if _is_controlled_locally():
		if is_dead:
			_process_dead(delta)
		else:
			_process_alive(delta)
	else:
		_apply_weapon_visuals()

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
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _bomb_cooldown > 0.0:
		_bomb_cooldown = maxf(0.0, _bomb_cooldown - delta)

	if NetworkManager.is_agent_clash_mode():
		for i in range(4):
			if ability_cooldowns[i] > 0.0:
				ability_cooldowns[i] = maxf(0.0, ability_cooldowns[i] - delta)
		if stun_timer > 0.0:
			stun_timer = maxf(0.0, stun_timer - delta)
		if _grab_cooldown > 0.0:
			_grab_cooldown = maxf(0.0, _grab_cooldown - delta)
		if speed_boost_timer > 0.0:
			speed_boost_timer = maxf(0.0, speed_boost_timer - delta)
			if speed_boost_timer <= 0.0:
				speed_boost_mult = 1.0
		_agent_hud_sync_accum += delta
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
			return

	if not NetworkManager.is_agent_clash_mode() and is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			if _weapon.single_shell_reload:
				current_ammo = mini(_weapon.mag_size, current_ammo + 1)
				_play_local_sfx("res://assets/audio/pickup.wav", -10.0)
				if current_ammo < _weapon.mag_size:
					_reload_timer = _weapon.reload_time
				else:
					is_reloading = false
				_emit_ammo()
			else:
				is_reloading = false
				current_ammo = _weapon.mag_size
				_emit_ammo()

	var move_dir: float = 0.0
	var want_jump: bool = false
	var want_crouch: bool = false
	var want_jet: bool = false
	var want_fire: bool = false

	var is_stunned: bool = NetworkManager.is_agent_clash_mode() and stun_timer > 0.0

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

		if virtual_aim.length() > 0.15:
			var aim_vec := Vector2(virtual_aim.x, -virtual_aim.y if SettingsManager.invert_y_axis else virtual_aim.y)
			aim_angle = aim_vec.angle()
		else:
			var mouse_delta: Vector2 = get_global_mouse_position() - _weapon_pivot.global_position
			if SettingsManager.invert_y_axis:
				mouse_delta.y = -mouse_delta.y
			aim_angle = mouse_delta.angle()

		if SettingsManager.auto_aim_assist:
			aim_angle = _apply_auto_aim_assist(aim_angle)

		want_fire = virtual_fire or (Input.is_action_pressed("fire") and not pointer_over_ui)

		if NetworkManager.is_agent_clash_mode():
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
			if Input.is_action_just_pressed("toggle_dual_wield"):
				toggle_dual_wield()
			if Input.is_action_just_pressed("throw_item"):
				throw_bomb()

	facing_right = cos(aim_angle) >= 0.0

	is_crouching = want_crouch and is_on_floor() and not want_jet and not is_stunned
	_update_crouch_collider(is_crouching)

	var speed_mult: float = 1.0 if NetworkManager.is_agent_clash_mode() else (_weapon.move_speed_multiplier if _weapon != null else 1.0)
	if NetworkManager.is_agent_clash_mode() and speed_boost_timer > 0.0:
		speed_mult *= speed_boost_mult
	if is_bot:
		var bot_diff: int = clampi(NetworkManager.bot_difficulty, 0, 2)
		speed_mult *= (0.72 if bot_diff == 0 else (0.86 if bot_diff == 1 else 1.0))
	var target_speed: float = (CROUCH_SPEED if is_crouching else MOVE_SPEED) * speed_mult * move_dir
	var accel: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	if is_stunned:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * 2.5 * delta)
	elif absf(move_dir) > 0.05:
		velocity.x = move_toward(velocity.x, target_speed, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, (FRICTION if is_on_floor() else AIR_ACCEL * 0.45) * delta)

	if want_jump:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			_play_local_sfx("res://assets/audio/jump.wav", -6.0)
		elif is_on_wall_only():
			var wall_normal: Vector2 = get_wall_normal()
			velocity.y = JUMP_VELOCITY * 0.92
			velocity.x = wall_normal.x * WALL_JUMP_X
			_play_local_sfx("res://assets/audio/jump.wav", -6.0)

	var grav_eff: float = GRAVITY * clampf(NetworkManager.gravity_scale, 0.0, 1.0)
	var has_fuel: bool = NetworkManager.unlimited_jetpack or (jetpack_fuel > 0.5)
	if want_jet and has_fuel and not is_crouching:
		is_jetpacking = true
		velocity.y = maxf(velocity.y - JETPACK_THRUST * delta, JETPACK_MAX_UP_SPEED)
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
		if NetworkManager.is_agent_clash_mode():
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
	if is_dual_wielding and _weapon.supports_dual_wield:
		_fire_cooldown *= 0.72
	if is_bot:
		var bot_diff: int = clampi(NetworkManager.bot_difficulty, 0, 2)
		var fire_delay_mult: float = 1.85 if bot_diff == 0 else (1.35 if bot_diff == 1 else 1.0)
		_fire_cooldown *= fire_delay_mult

	var shots_to_fire: int = 2 if (is_dual_wielding and _weapon.supports_dual_wield and current_ammo >= 2) else 1
	current_ammo = maxi(0, current_ammo - shots_to_fire)
	_emit_ammo()

	var fire_angle: float = aim_angle
	var aim_dir: Vector2 = Vector2.from_angle(fire_angle)
	velocity -= aim_dir * _weapon.recoil_impulse * (1.25 if shots_to_fire == 2 else 1.0)
	add_screen_shake(clampf(_weapon.recoil_impulse * 0.004, 0.15, 0.85))

	# Predictable vertical recoil bias (positive climbs upward; Kriss Vector negative compensates downward)
	var recoil_sign: float = -1.0 if cos(aim_angle) >= 0.0 else 1.0
	aim_angle = wrapf(aim_angle + recoil_sign * _weapon.vertical_recoil_bias, -PI, PI)

	var muzzle_positions := PackedVector2Array([_muzzle_primary.global_position])
	if shots_to_fire == 2:
		muzzle_positions.append(_muzzle_secondary.global_position)

	var seed_val: int = int(Time.get_ticks_usec() % 1000000)
	if NetworkManager.is_network_active():
		spawn_projectiles_rpc.rpc(muzzle_positions, fire_angle, _weapon.id, weapon_skin_id, m4a1_rail_mod, seed_val)
	else:
		_spawn_projectiles_local(muzzle_positions, fire_angle, _weapon.id, weapon_skin_id, m4a1_rail_mod, seed_val)

	if current_ammo <= 0:
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
	if NetworkManager.is_agent_clash_mode():
		return
	if is_reloading or current_ammo >= _weapon.mag_size or is_dead:
		return
	is_reloading = true
	_reload_timer = _weapon.reload_time
	_emit_ammo()


func cycle_weapon() -> void:
	if NetworkManager.is_agent_clash_mode() or is_dead:
		return
	if _equipped_primary_id != secondary_weapon_id:
		var next_id: int = secondary_weapon_id if current_weapon_id != secondary_weapon_id else _equipped_primary_id
		set_weapon(next_id)
		# Glock 17 backup pistol features quick-draw readiness
		if next_id == secondary_weapon_id:
			_fire_cooldown = minf(_fire_cooldown, 0.08)
	else:
		var next_id: int = (current_weapon_id + 1) % WeaponData.get_weapon_count()
		set_weapon(next_id)


func set_weapon(new_weapon_id: int) -> void:
	current_weapon_id = WeaponData.sanitize_weapon_id(new_weapon_id)
	_apply_weapon(current_weapon_id)
	if NetworkManager.is_network_active() and _is_controlled_locally():
		sync_weapon_rpc.rpc(current_weapon_id, is_dual_wielding, m4a1_rail_mod)


func apply_gun_preset(preset_idx: int) -> void:
	if NetworkManager.is_agent_clash_mode():
		return
	selected_gun_preset_id = clampi(preset_idx, 0, WeaponData.GUN_PRESETS.size() - 1)
	var preset: Dictionary = WeaponData.get_effective_preset(selected_gun_preset_id)
	primary_weapon_id = int(preset["primary"])
	secondary_weapon_id = int(preset["secondary"])
	_equipped_primary_id = primary_weapon_id
	bomb_type = str(preset.get("bomb_type", "frag"))
	max_bombs = int(preset.get("bombs", 3))
	bomb_count = max_bombs
	set_weapon(primary_weapon_id)
	if is_local_human:
		bombs_changed.emit(bomb_count, bomb_type)


func throw_bomb() -> void:
	if NetworkManager.is_agent_clash_mode() or is_dead or bomb_count <= 0 or _bomb_cooldown > 0.0 or not NetworkManager.allow_explosives:
		return
	bomb_count = maxi(0, bomb_count - 1)
	_bomb_cooldown = 0.65
	if is_local_human:
		bombs_changed.emit(bomb_count, bomb_type)
	if NetworkManager.is_network_active():
		throw_bomb_rpc.rpc(_muzzle_primary.global_position, aim_angle, bomb_type)
	else:
		_throw_bomb_local(_muzzle_primary.global_position, aim_angle, bomb_type)


@rpc("any_peer", "call_local", "reliable")
func throw_bomb_rpc(origin: Vector2, angle: float, b_type: String) -> void:
	_throw_bomb_local(origin, angle, b_type)


func _throw_bomb_local(origin: Vector2, angle: float, b_type: String) -> void:
	var local_auth: bool = _is_controlled_locally()
	if b_type == "cluster":
		for off in [-0.14, 0.0, 0.14]:
			_spawn_styled_projectile(
				origin, angle + off, 700.0, 48, "frag_bomb",
				Color(1.0, 0.42, 0.15), "Cluster Bomb", 0.0, 12.0,
				true, 125.0, 1.35, false, local_auth, 1.8, 1.0, 0.72
			)
	else:
		_spawn_styled_projectile(
			origin, angle, 740.0, 82, "frag_bomb",
			Color(0.28, 0.92, 0.42), "Frag Bomb", 0.0, 10.0,
			true, 155.0, 1.5, false, local_auth, 1.9, 1.05, 0.72
		)
	_play_local_sfx("res://assets/audio/jump.wav", -2.0, 0.65)


func toggle_dual_wield() -> void:
	if NetworkManager.is_agent_clash_mode():
		return
	if not _weapon.supports_dual_wield or is_dead:
		return
	is_dual_wielding = not is_dual_wielding
	_apply_weapon_visuals()
	_emit_hud_signals()
	if NetworkManager.is_network_active() and _is_controlled_locally():
		sync_weapon_rpc.rpc(current_weapon_id, is_dual_wielding, m4a1_rail_mod)


@rpc("any_peer", "call_local", "reliable")
func sync_weapon_rpc(weapon_id: int, dual: bool, rail_mod: int = 0) -> void:
	current_weapon_id = weapon_id
	is_dual_wielding = dual
	m4a1_rail_mod = rail_mod
	_apply_weapon(weapon_id)


func _apply_weapon(weapon_id: int) -> void:
	var safe_id: int = WeaponData.sanitize_weapon_id(weapon_id)
	current_weapon_id = safe_id
	_weapon = WeaponData.get_weapon(safe_id, weapon_skin_id, m4a1_rail_mod)
	if not _weapon.supports_dual_wield:
		is_dual_wielding = false
	is_reloading = false
	current_ammo = _weapon.mag_size
	_apply_weapon_visuals()
	_emit_hud_signals()


func _apply_weapon_visuals() -> void:
	if not is_node_ready():
		return
	if NetworkManager.is_agent_clash_mode():
		_primary_weapon.visible = false
		_secondary_weapon.visible = false
		if _agent_weapon_node != null:
			var ag: Dictionary = AgentData.get_agent(archetype_id)
			var bw: Dictionary = ag["base_weapon"]
			_agent_weapon_node.set("weapon_style", str(bw["style"]))
			_agent_weapon_node.set("weapon_color", bw["color"] as Color)
			_agent_weapon_node.visible = not is_dead
			_agent_weapon_node.queue_redraw()
		return

	_primary_weapon.visible = true
	if _agent_weapon_node != null:
		_agent_weapon_node.visible = false
	var w: WeaponData = WeaponData.get_weapon(current_weapon_id, weapon_skin_id, m4a1_rail_mod)
	var sheet_frame: int = clampi(weapon_skin_id, 0, 2) * 11 + w.sprite_frame
	_primary_weapon.frame = sheet_frame
	_secondary_weapon.frame = sheet_frame
	_secondary_weapon.visible = is_dual_wielding and w.supports_dual_wield and not is_dead


func can_grab_throwable() -> bool:
	return NetworkManager.is_agent_clash_mode() and held_throwable_id == -1 and grabbed_player_id == 0 and carried_by_peer_id == 0 and not is_dead


func apply_pickup(pickup_type: String, value: int) -> void:
	if is_dead:
		return
	if pickup_type == "health":
		health = mini(max_health, health + value)
		if is_local_human:
			health_changed.emit(health, max_health)
	elif pickup_type == "throwable":
		if NetworkManager.is_agent_clash_mode():
			held_throwable_id = clampi(value, 0, AgentData.THROWABLE_ITEMS.size() - 1)
			if is_local_human:
				agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
	elif pickup_type == "weapon":
		if not NetworkManager.is_agent_clash_mode():
			_equipped_primary_id = WeaponData.sanitize_weapon_id(value)
			set_weapon(_equipped_primary_id)
			if NetworkManager.allow_explosives and bomb_count < max_bombs:
				bomb_count = mini(max_bombs, bomb_count + 1)
				if is_local_human:
					bombs_changed.emit(bomb_count, bomb_type)
	_play_local_sfx("res://assets/audio/pickup.wav", -2.0)


func apply_hit(dmg: int, attacker_id: int, weapon_name: String, attacker_name: String, knockback: Vector2) -> void:
	if is_dead or spawn_invuln_timer > 0.0:
		return
	if NetworkManager.is_network_active():
		request_damage_rpc.rpc(dmg, attacker_id, weapon_name, attacker_name, knockback)
	else:
		_receive_damage_local(dmg, attacker_id, weapon_name, attacker_name, knockback)


@rpc("any_peer", "call_local", "reliable")
func request_damage_rpc(dmg: int, attacker_id: int, weapon_name: String, attacker_name: String, knockback: Vector2) -> void:
	_receive_damage_local(dmg, attacker_id, weapon_name, attacker_name, knockback)


func _receive_damage_local(dmg: int, attacker_id: int, weapon_name: String, attacker_name: String, knockback: Vector2) -> void:
	if is_dead or spawn_invuln_timer > 0.0:
		return
	_hit_flash_timer = 0.12
	_play_local_sfx("res://assets/audio/hit.wav", -3.0)
	add_screen_shake(clampf(float(dmg) * 0.03, 0.35, 1.35))

	if not _is_controlled_locally():
		return

	velocity += knockback
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
	speed_boost_timer = 0.0
	speed_boost_mult = 1.0
	_release_grab_state()
	_respawn_timer = RESPAWN_TIME
	NetworkManager.report_kill(attacker_id, peer_id, weapon_name, attacker_name, player_name)

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
	_weapon_pivot.visible = false
	_jetpack_particles.emitting = false
	var parent_node: Node = get_parent()
	if parent_node != null:
		var exp := EXPLOSION_SCENE.instantiate()
		exp.global_position = global_position
		exp.explosion_radius = 65.0
		exp.max_damage = 0
		exp.can_deal_damage = false
		parent_node.add_child(exp)


func _respawn_self() -> void:
	var spawn_pos: Vector2 = Vector2(640.0, 320.0)
	if not _spawn_points.is_empty():
		spawn_pos = _spawn_points[randi() % _spawn_points.size()]
	global_position = spawn_pos
	velocity = Vector2.ZERO
	health = max_health
	jetpack_fuel = MAX_FUEL
	is_dead = false
	is_reloading = false
	stun_timer = 0.0
	speed_boost_timer = 0.0
	speed_boost_mult = 1.0
	held_throwable_id = -1
	_release_grab_state()
	ability_cooldowns = [0.0, 0.0, 0.0, 0.0]
	bomb_count = max_bombs if NetworkManager.allow_explosives else 0
	current_ammo = _weapon.mag_size
	spawn_invuln_timer = 1.6

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
	_weapon_pivot.visible = true
	_apply_weapon_visuals()


func _update_visual_state(delta: float) -> void:
	if _is_controlled_locally():
		if is_dead:
			anim_frame = 7
		elif is_jetpacking or not is_on_floor():
			anim_frame = 5
		elif is_crouching or _fire_anim_timer > 0.0:
			anim_frame = 6
		elif absf(velocity.x) > 25.0:
			_anim_timer += delta * clampf(absf(velocity.x) / 170.0, 0.8, 2.0)
			var run_frames: Array[int] = [2, 3, 4, 3]
			anim_frame = run_frames[int(_anim_timer * 7.0) % run_frames.size()]
		else:
			_anim_timer += delta
			anim_frame = 0 if int(_anim_timer * 2.2) % 2 == 0 else 1

	var safe_frame: int = clampi(anim_frame, 0, 7)
	var flip_x: bool = not facing_right

	if _modular_rig != null:
		_modular_rig.set_sync_frame(safe_frame, flip_x)
		if NetworkManager.is_team_mode():
			_modular_rig.apply_layer_colors(NetworkManager.get_team_color(team_id), 0.36)
		else:
			_modular_rig.apply_layer_colors(Color.WHITE, 0.0)

	if _hit_flash_timer > 0.0:
		_modular_rig.modulate = Color(1.0, 0.35, 0.35, 1.0)
	elif stun_timer > 0.0:
		var stun_pulse: float = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.035)
		_modular_rig.modulate = Color(0.55 + stun_pulse * 0.45, 0.92, 1.0, 1.0)
	elif speed_boost_timer > 0.0:
		_modular_rig.modulate = Color(0.76, 1.0, 0.84, 1.0)
	elif spawn_invuln_timer > 0.0:
		var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02)
		_modular_rig.modulate = Color(1.0, 1.0, 1.0, pulse)
	else:
		_modular_rig.modulate = Color.WHITE

	_weapon_pivot.visible = not is_dead
	_weapon_pivot.position.y = 9.0 if is_crouching else 6.0
	var swing_offset: float = 0.0
	if NetworkManager.is_agent_clash_mode() and _melee_swing_timer > 0.0:
		var swing_prog: float = 1.0 - (_melee_swing_timer / 0.22)
		var swing_dir: float = 1.0 if facing_right else -1.0
		swing_offset = lerpf(-0.95, 0.95, swing_prog) * swing_dir
	_weapon_pivot.rotation = aim_angle + swing_offset
	var flip_gun: bool = cos(aim_angle) < 0.0
	_primary_weapon.flip_v = flip_gun
	_secondary_weapon.flip_v = flip_gun
	if _agent_weapon_node != null:
		_agent_weapon_node.scale.y = -1.0 if flip_gun else 1.0

	var p_ratio: float = clampf(SettingsManager.particle_intensity, 0.0, 1.5)
	var target_amt: int = clampi(int(round(24.0 * p_ratio)), 1, 36)
	if _jetpack_particles.amount != target_amt:
		_jetpack_particles.amount = target_amt
	_jetpack_particles.modulate.a = clampf(p_ratio, 0.0, 1.0)
	_jetpack_particles.emitting = is_jetpacking and not is_dead and p_ratio > 0.05

	if is_jetpacking and not is_dead:
		if not _jetpack_audio.playing:
			_jetpack_audio.play()
	elif _jetpack_audio.playing:
		_jetpack_audio.stop()


func _apply_team_visuals() -> void:
	var label_col: Color = NetworkManager.get_team_color(team_id if NetworkManager.is_team_mode() else color_index)
	_name_label.modulate = label_col.lightened(0.35)


func _update_overhead_ui() -> void:
	_overhead_ui.visible = not is_dead
	if NetworkManager.is_agent_clash_mode() and carried_by_peer_id != 0:
		_name_label.text = "✋ GRABBED!"
		_name_label.modulate = Color(1.0, 0.65, 0.22)
	elif NetworkManager.is_agent_clash_mode() and thrown_flight_timer > 0.0:
		_name_label.text = "☄ THROWN!"
		_name_label.modulate = Color(1.0, 0.42, 0.22)
	elif NetworkManager.is_agent_clash_mode() and stun_timer > 0.0:
		_name_label.text = "⚡ STUNNED %.1fs" % stun_timer
		_name_label.modulate = Color(0.45, 0.95, 1.0)
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
	weapon_changed.emit(_weapon, is_dual_wielding)
	_emit_ammo()
	if NetworkManager.is_agent_clash_mode():
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
	else:
		bombs_changed.emit(bomb_count, bomb_type)


func _emit_ammo() -> void:
	if is_local_human:
		ammo_changed.emit(current_ammo, _weapon.mag_size, is_reloading)


func _play_local_sfx(path: String, volume_db_offset: float = 0.0, pitch_override: float = 0.0) -> void:
	var stream: AudioStream = load(path) as AudioStream
	if stream != null:
		_audio_sfx.stream = stream
		_audio_sfx.volume_db = volume_db_offset
		_audio_sfx.pitch_scale = pitch_override if pitch_override > 0.0 else randf_range(0.94, 1.06)
		_audio_sfx.play()


func is_alive() -> bool:
	return not is_dead


func _compute_bot_input(delta: float) -> Dictionary:
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
	if not NetworkManager.is_agent_clash_mode() or is_dead or duration <= 0.0:
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
	if is_dead or (attacker_id != 0 and attacker_id == peer_id):
		return
	_release_grab_state()
	stun_timer = maxf(stun_timer, duration)
	is_jetpacking = false
	if is_local_human:
		agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)


func gain_ult_charge(seconds_reduced: float) -> void:
	if NetworkManager.is_agent_clash_mode():
		ability_cooldowns[3] = maxf(0.0, ability_cooldowns[3] - seconds_reduced)


func _fire_agent_base_weapon() -> void:
	var ag: Dictionary = AgentData.get_agent(archetype_id)
	var bw: Dictionary = ag["base_weapon"]
	var cd: float = float(bw["cooldown"])
	if speed_boost_timer > 0.0:
		cd *= 0.72
	if is_bot:
		var bot_diff: int = clampi(NetworkManager.bot_difficulty, 0, 2)
		cd *= (1.85 if bot_diff == 0 else (1.35 if bot_diff == 1 else 1.0))
	_fire_cooldown = cd
	_melee_swing_timer = 0.22
	_fire_anim_timer = 0.16

	var dmg: int = int(bw["damage"])
	var col: Color = bw["color"] as Color
	var w_label: String = str(bw["name"])
	if bool(bw["ranged"]):
		if NetworkManager.is_network_active():
			spawn_agent_base_ranged_rpc.rpc(_muzzle_primary.global_position, aim_angle, dmg, col, w_label)
		else:
			_spawn_styled_projectile(_muzzle_primary.global_position, aim_angle, 1020.0, dmg, "arrow", col, w_label, 0.0, 0.0, false, 60.0, 1.0, false, _is_controlled_locally())
			_play_local_sfx("res://assets/audio/shoot_smg.wav", -6.0, 1.45)
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
func spawn_agent_base_ranged_rpc(origin: Vector2, angle: float, dmg: int, col: Color, w_label: String) -> void:
	_spawn_styled_projectile(origin, angle, 1020.0, dmg, "arrow", col, w_label, 0.0, 0.0, false, 60.0, 1.0, false, _is_controlled_locally())
	_play_local_sfx("res://assets/audio/shoot_smg.wav", -6.0, 1.45)


@rpc("any_peer", "call_local", "reliable")
func spawn_slash_vfx_rpc(origin: Vector2, angle: float, col: Color) -> void:
	_spawn_styled_projectile(origin + Vector2.from_angle(angle) * 26.0, angle, 520.0, 0, "slash_wave", col, "Slash", 0.0, 0.0, false, 40.0, 1.0, true, false, 0.12, 1.1)
	_play_local_sfx("res://assets/audio/jump.wav", -4.0, 1.5)


func use_agent_ability(slot_idx: int) -> void:
	if not NetworkManager.is_agent_clash_mode() or is_dead or stun_timer > 0.0:
		return
	if slot_idx < 0 or slot_idx > 3 or ability_cooldowns[slot_idx] > 0.0:
		return
	ability_cooldowns[slot_idx] = ability_max_cooldowns[slot_idx]
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
	var ab: Dictionary = AgentData.get_ability_slot(archetype_id, slot_idx)
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
			_cast_fireballs(origin, cast_angle, dmg, stun_dur, col, ab_name, int(ab.get("shots", 3)), local_auth, "fireball")
			_play_local_sfx("res://assets/audio/shoot_rpg.wav", -3.0, 1.3)
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
			if local_auth:
				health = mini(max_health, health + 15)
				if is_local_human:
					health_changed.emit(health, max_health)
			_spawn_vfx_burst(cast_pos, 65.0, col)
			_play_local_sfx("res://assets/audio/pickup.wav", -1.0, 1.25)
		"dash_speed":
			speed_boost_timer = float(ab.get("duration", 3.8))
			speed_boost_mult = float(ab.get("speed_mult", 1.75))
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
			_cast_gun_burst(origin, cast_angle, dmg, int(ab.get("shots", 6)), 18.0, col, ab_name, stun_dur, 1060.0, local_auth)
			_play_local_sfx("res://assets/audio/shoot_shotgun.wav", -3.0)
		"ult_gun_storm":
			_cast_gun_burst(origin, cast_angle, dmg, int(ab.get("shots", 14)), 14.0, col, ab_name, stun_dur, 1340.0, local_auth)
			add_screen_shake(2.0)
			_play_local_sfx("res://assets/audio/shoot_scar.wav", -2.0, 0.92)


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


func _cast_multi_proj(origin: Vector2, angle: float, dmg: int, count: int, spread_deg: float, style: String, col: Color, ab_name: String, stun_dur: float, speed: float, spin_spd: float, pierce_w: bool, local_auth: bool, life: float, proj_scale: float) -> void:
	for i in range(count):
		var off: float = 0.0
		if count > 1:
			var frac: float = (float(i) / float(count - 1)) - 0.5
			off = deg_to_rad(spread_deg) * frac
		_spawn_styled_projectile(origin, angle + off, speed, dmg, style, col, ab_name, stun_dur, spin_spd, false, 60.0, 1.1, pierce_w, local_auth, life, proj_scale)


func _cast_teleport(cast_pos: Vector2, angle: float, max_dist: float, dmg: int, stun_dur: float, col: Color, ab_name: String, with_beams: bool, local_auth: bool) -> void:
	_spawn_vfx_burst(cast_pos, 70.0, col)
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
	_spawn_vfx_burst(dest, 115.0 if not with_beams else 160.0, col)
	if local_auth:
		var hits: int = _apply_radial_aoe(dest, 125.0 if not with_beams else 165.0, dmg, stun_dur, 300.0, ab_name)
		if hits > 0 and not with_beams:
			gain_ult_charge(2.0 * float(hits))
	if with_beams:
		_spawn_styled_projectile(dest + dir * 24.0, angle - 0.16, 860.0, dmg, "slash_wave", col, ab_name, stun_dur, 0.0, false, 60.0, 1.4, true, local_auth, 0.65, 2.2)
		_spawn_styled_projectile(dest + dir * 24.0, angle + 0.16, 860.0, dmg, "slash_wave", col, ab_name, stun_dur, 0.0, false, 60.0, 1.4, true, local_auth, 0.65, 2.2)


func _cast_gun_burst(origin: Vector2, angle: float, dmg: int, shots: int, spread_deg: float, col: Color, ab_name: String, stun_dur: float, speed: float, local_auth: bool) -> void:
	for i in range(shots):
		var frac: float = (float(i) / float(maxi(1, shots - 1))) - 0.5
		var off: float = deg_to_rad(spread_deg) * frac
		_spawn_styled_projectile(origin, angle + off, speed, dmg, "bullet", col, ab_name, stun_dur, 0.0, false, 60.0, 0.85, false, local_auth, 1.1, 1.15)


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
		thrown_flight_timer = 0.0
		thrown_by_peer_id = 0
		_thrown_flight_elapsed = 0.0
		apply_hit(THROWN_WALL_DAMAGE, t_id, "Thrown Wall Slam", t_name, Vector2.ZERO)
		_spawn_vfx_burst(global_position, 42.0, Color(0.95, 0.55, 0.20))
		return true
	return false


func throw_held_item() -> void:
	if not NetworkManager.is_agent_clash_mode() or is_dead or stun_timer > 0.0 or carried_by_peer_id != 0:
		return
	if grabbed_player_id != 0:
		throw_grabbed_player(aim_angle)
		if is_local_human:
			agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
		return
	if held_throwable_id >= 0:
		var item_id: int = held_throwable_id
		held_throwable_id = -1
		if is_local_human:
			agent_state_changed.emit(ability_cooldowns, ability_max_cooldowns, held_throwable_id, stun_timer)
		if NetworkManager.is_network_active():
			throw_item_rpc.rpc(item_id, _muzzle_primary.global_position, aim_angle)
		else:
			_throw_item_local(item_id, _muzzle_primary.global_position, aim_angle)
		return
	var target := find_grabbable_player()
	if target != null:
		grab_player(target)
		if is_local_human:
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
	b.max_lifetime = life
	b.scale = Vector2(proj_scale, proj_scale)
	parent_node.add_child(b)


func _spawn_vfx_burst(pos: Vector2, radius: float, col: Color) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var exp := EXPLOSION_SCENE.instantiate()
	exp.global_position = pos
	exp.explosion_radius = radius
	exp.max_damage = 0
	exp.ring_color = col
	exp.can_deal_damage = false
	parent_node.add_child(exp)


class AgentWeaponVisual extends Node2D:
	var weapon_style: String = "sword"
	var weapon_color: Color = Color(0.85, 0.90, 0.98)

	func _draw() -> void:
		match weapon_style:
			"greatsword":
				draw_line(Vector2(4, 0), Vector2(44, 0), weapon_color, 7.0)
				draw_colored_polygon(PackedVector2Array([Vector2(42, -5), Vector2(54, 0), Vector2(42, 5)]), Color.WHITE)
				draw_line(Vector2(10, -8), Vector2(10, 8), Color(0.95, 0.78, 0.28), 4.0)
			"axe":
				draw_line(Vector2(4, 0), Vector2(36, 0), Color(0.55, 0.34, 0.16), 4.0)
				draw_colored_polygon(PackedVector2Array([Vector2(24, -13), Vector2(38, -8), Vector2(38, 10), Vector2(24, 12)]), weapon_color)
			"bow":
				draw_arc(Vector2(10, 0), 18.0, -1.15, 1.15, 16, Color(0.68, 0.45, 0.20), 4.0)
				draw_line(Vector2(17, -16), Vector2(17, 16), weapon_color, 1.8)
			"scythe":
				draw_line(Vector2(2, 0), Vector2(42, 0), Color(0.32, 0.28, 0.38), 4.0)
				draw_colored_polygon(PackedVector2Array([Vector2(38, -2), Vector2(46, 12), Vector2(30, 18), Vector2(34, 4)]), weapon_color)
			"spear":
				draw_line(Vector2(0, 0), Vector2(38, 0), Color(0.65, 0.45, 0.22), 3.5)
				draw_colored_polygon(PackedVector2Array([Vector2(36, -5), Vector2(50, 0), Vector2(36, 5)]), weapon_color)
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
