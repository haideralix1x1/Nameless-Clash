extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal fuel_changed(current: float, maximum: float)
signal ammo_changed(current: int, mag_size: int, is_reloading: bool)
signal weapon_changed(weapon_data: WeaponData, dual_wield: bool)
signal died_signal(respawn_seconds: float)
signal respawned_signal

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
var _spawn_points: Array[Vector2] = []

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
	primary_weapon_id = int(av["primary_weapon_id"])
	secondary_weapon_id = int(av["secondary_weapon_id"])
	_equipped_primary_id = primary_weapon_id
	current_weapon_id = primary_weapon_id
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
	_apply_modular_textures()
	_apply_weapon(current_weapon_id)
	_apply_team_visuals()
	_camera.enabled = is_local_human
	if is_local_human:
		_camera.make_current()
	_muzzle_flash.visible = false
	_update_overhead_ui()
	_emit_hud_signals()


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
		_shake_amount = minf(_shake_amount + strength, 24.0)


func _physics_process(delta: float) -> void:
	if spawn_invuln_timer > 0.0:
		spawn_invuln_timer = maxf(0.0, spawn_invuln_timer - delta)

	if _flash_timer > 0.0:
		_flash_timer = maxf(0.0, _flash_timer - delta)
		if _flash_timer <= 0.0:
			_muzzle_flash.visible = false

	if _fire_anim_timer > 0.0:
		_fire_anim_timer = maxf(0.0, _fire_anim_timer - delta)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)

	if _shake_amount > 0.0:
		_shake_amount = maxf(0.0, _shake_amount - delta * 28.0)
	if is_local_human and is_instance_valid(_camera):
		var s: float = _shake_amount * SettingsManager.screen_shake_intensity
		_camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s)) if s > 0.1 else Vector2.ZERO
		var target_zoom_val: float = _weapon.scope_zoom if (not is_dead and _weapon != null) else 1.05
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
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	velocity.y = minf(velocity.y + GRAVITY * delta, 700.0)
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

	if is_reloading:
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

	if is_bot:
		var bot_cmd: Dictionary = _compute_bot_input(delta)
		move_dir = float(bot_cmd["move_x"])
		want_jump = bool(bot_cmd["jump"])
		want_crouch = bool(bot_cmd["crouch"])
		want_jet = bool(bot_cmd["jetpack"])
		want_fire = bool(bot_cmd["fire"])
		aim_angle = float(bot_cmd["aim_angle"])
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

		if Input.is_action_just_pressed("reload"):
			start_reload()
		if Input.is_action_just_pressed("switch_weapon"):
			cycle_weapon()
		if Input.is_action_just_pressed("toggle_dual_wield"):
			toggle_dual_wield()

	facing_right = cos(aim_angle) >= 0.0

	is_crouching = want_crouch and is_on_floor() and not want_jet
	_update_crouch_collider(is_crouching)

	var speed_mult: float = _weapon.move_speed_multiplier if _weapon != null else 1.0
	var target_speed: float = (CROUCH_SPEED if is_crouching else MOVE_SPEED) * speed_mult * move_dir
	var accel: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	if absf(move_dir) > 0.05:
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

	if want_jet and jetpack_fuel > 0.5 and not is_crouching:
		is_jetpacking = true
		velocity.y = maxf(velocity.y - JETPACK_THRUST * delta, JETPACK_MAX_UP_SPEED)
		jetpack_fuel = maxf(0.0, jetpack_fuel - FUEL_CONSUME_RATE * delta)
		_fuel_recharge_delay = 0.35
	else:
		is_jetpacking = false
		velocity.y += GRAVITY * delta
		if _fuel_recharge_delay > 0.0:
			_fuel_recharge_delay = maxf(0.0, _fuel_recharge_delay - delta)
		else:
			var rate: float = FUEL_RECHARGE_GROUND if is_on_floor() else FUEL_RECHARGE_AIR
			jetpack_fuel = minf(MAX_FUEL, jetpack_fuel + rate * delta)

	if is_on_wall_only() and velocity.y > WALL_SLIDE_SPEED and not is_jetpacking:
		velocity.y = WALL_SLIDE_SPEED

	velocity.y = minf(velocity.y, 760.0)
	move_and_slide()

	if want_fire and _fire_cooldown <= 0.0:
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
		if NetworkManager.match_mode == 1 and int(node.get("team_id")) == team_id:
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
		_weapon_pivot.position.y = 4.0
	else:
		cap.height = 48.0
		_collision_shape.position.y = 3.0
		_weapon_pivot.position.y = -4.0


func get_current_weapon() -> WeaponData:
	return _weapon


func _fire_weapon() -> void:
	_fire_cooldown = _weapon.fire_interval
	if is_dual_wielding and _weapon.supports_dual_wield:
		_fire_cooldown *= 0.72

	var shots_to_fire: int = 2 if (is_dual_wielding and _weapon.supports_dual_wield and current_ammo >= 2) else 1
	current_ammo = maxi(0, current_ammo - shots_to_fire)
	_emit_ammo()

	var fire_angle: float = aim_angle
	var aim_dir: Vector2 = Vector2.from_angle(fire_angle)
	velocity -= aim_dir * _weapon.recoil_impulse * (1.25 if shots_to_fire == 2 else 1.0)
	add_screen_shake(clampf(_weapon.recoil_impulse * 0.025, 1.0, 6.0))

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
	if is_reloading or current_ammo >= _weapon.mag_size or is_dead:
		return
	is_reloading = true
	_reload_timer = _weapon.reload_time
	_emit_ammo()


func cycle_weapon() -> void:
	if is_dead:
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
	current_weapon_id = wrapi(new_weapon_id, 0, WeaponData.get_weapon_count())
	_apply_weapon(current_weapon_id)
	if NetworkManager.is_network_active() and _is_controlled_locally():
		sync_weapon_rpc.rpc(current_weapon_id, is_dual_wielding, m4a1_rail_mod)


func toggle_dual_wield() -> void:
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
	_weapon = WeaponData.get_weapon(weapon_id, weapon_skin_id, m4a1_rail_mod)
	if not _weapon.supports_dual_wield:
		is_dual_wielding = false
	is_reloading = false
	current_ammo = _weapon.mag_size
	_apply_weapon_visuals()
	_emit_hud_signals()


func _apply_weapon_visuals() -> void:
	if not is_node_ready():
		return
	var w: WeaponData = WeaponData.get_weapon(current_weapon_id, weapon_skin_id, m4a1_rail_mod)
	var sheet_frame: int = clampi(weapon_skin_id, 0, 2) * 11 + w.sprite_frame
	_primary_weapon.frame = sheet_frame
	_secondary_weapon.frame = sheet_frame
	_secondary_weapon.visible = is_dual_wielding and w.supports_dual_wield and not is_dead


func apply_pickup(pickup_type: String, value: int) -> void:
	if is_dead:
		return
	if pickup_type == "health":
		health = mini(max_health, health + value)
		if is_local_human:
			health_changed.emit(health, max_health)
	elif pickup_type == "weapon":
		_equipped_primary_id = wrapi(value, 0, WeaponData.get_weapon_count())
		set_weapon(_equipped_primary_id)
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
	add_screen_shake(4.5)

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
		if NetworkManager.match_mode == 1:
			_modular_rig.apply_layer_colors(NetworkManager.get_team_color(team_id), 0.36)
		else:
			_modular_rig.apply_layer_colors(Color.WHITE, 0.0)

	if _hit_flash_timer > 0.0:
		_modular_rig.modulate = Color(1.0, 0.35, 0.35, 1.0)
	elif spawn_invuln_timer > 0.0:
		var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.02)
		_modular_rig.modulate = Color(1.0, 1.0, 1.0, pulse)
	else:
		_modular_rig.modulate = Color.WHITE

	_weapon_pivot.visible = not is_dead
	_weapon_pivot.position.y = 9.0 if is_crouching else 6.0
	_weapon_pivot.rotation = aim_angle
	var flip_gun: bool = cos(aim_angle) < 0.0
	_primary_weapon.flip_v = flip_gun
	_secondary_weapon.flip_v = flip_gun

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
	var label_col: Color = NetworkManager.get_team_color(team_id if NetworkManager.match_mode == 1 else color_index)
	_name_label.modulate = label_col.lightened(0.35)


func _update_overhead_ui() -> void:
	_overhead_ui.visible = not is_dead
	_name_label.text = player_name
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
	_bot_think_timer -= delta
	var nearest_target: Node2D = null
	var nearest_dist: float = 99999.0

	for node in get_tree().get_nodes_in_group("players"):
		if node == self or not is_instance_valid(node):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		if NetworkManager.match_mode == 1 and int(node.get("team_id")) == team_id:
			continue
		var d: float = global_position.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest_target = node as Node2D

	if _bot_think_timer <= 0.0:
		_bot_think_timer = randf_range(0.28, 0.65)
		if randf() < 0.35:
			_bot_strafe_dir = -1.0 if randf() < 0.5 else 1.0
		_bot_want_jetpack = randf() < 0.42

	var move_x: float = _bot_strafe_dir
	var want_jump: bool = false
	var want_jet: bool = false
	var want_fire: bool = false
	var desired_angle: float = aim_angle

	if nearest_target != null:
		var to_target: Vector2 = nearest_target.global_position - _weapon_pivot.global_position
		var dist: float = to_target.length()
		desired_angle = to_target.angle() + randf_range(-0.07, 0.07)

		if dist > 360.0:
			move_x = signf(to_target.x)
		elif dist < 160.0:
			move_x = -signf(to_target.x)

		if to_target.y < -65.0 and jetpack_fuel > 25.0:
			want_jet = true
		elif is_on_wall() and jetpack_fuel > 20.0:
			want_jump = true
			want_jet = true
		elif _bot_want_jetpack and jetpack_fuel > 45.0:
			want_jet = true

		if dist < 760.0:
			var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
			var ray := PhysicsRayQueryParameters2D.create(
				_weapon_pivot.global_position,
				nearest_target.global_position,
				1
			)
			if space_state.intersect_ray(ray).is_empty():
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
