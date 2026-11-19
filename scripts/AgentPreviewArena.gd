extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")

var arena_width: float = 480.0
var arena_height: float = 190.0

var hero: Node = null
var dummy_bot: Node = null
var _current_arch: int = 0
var _reset_hero_timer: float = 0.0
var _bot_attack_timer: float = 0.0
var _bot_respawn_timer: float = -1.0
var _bot_too_close_timer: float = 0.0
var _hero_dash_casting: bool = false
var _hero_return_delay: float = 0.0
var _hero_pace_dir: float = 1.0
var _cam: Camera2D = null
var _touch_marker_pos: Vector2 = Vector2.ZERO
var _touch_marker_timer: float = 0.0


func _ready() -> void:
	_build_bounds()
	_cam = Camera2D.new()
	_cam.position = Vector2(arena_width * 0.5, arena_height * 0.5)
	_cam.enabled = true
	add_child(_cam)
	_spawn_fighters()


func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var specs := [
		[Vector2(arena_width * 0.5, arena_height - 10.0), Vector2(arena_width, 20.0)], # Floor
		[Vector2(arena_width * 0.5, 4.0), Vector2(arena_width, 24.0)],                # Ceiling
		[Vector2(16.0, arena_height * 0.5), Vector2(32.0, arena_height)],              # Left wall
		[Vector2(arena_width - 25.0, arena_height * 0.5), Vector2(50.0, arena_height)] # Right wall
	]
	for sp in specs:
		var col := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = sp[1]
		col.shape = sh
		col.position = sp[0]
		body.add_child(col)
	queue_redraw()


func _spawn_fighters() -> void:
	var prev_mode: int = NetworkManager.match_mode
	NetworkManager.match_mode = 2

	hero = PLAYER_SCENE.instantiate()
	hero.is_bot = true
	hero.is_preview_dummy = true
	var hero_spawns: Array[Vector2] = [Vector2(120.0, 142.0)]
	hero.setup_player(901, "Preview", 0, true, hero_spawns, 0, ProfileManager.ARCHETYPES[0])
	hero.archetype_id = _current_arch
	hero.spawn_invuln_timer = 0.0
	add_child(hero)

	dummy_bot = PLAYER_SCENE.instantiate()
	dummy_bot.is_bot = true
	dummy_bot.is_preview_dummy = true
	var bot_arch: int = 1 if _current_arch != 1 else 0
	var bot_spawns: Array[Vector2] = [Vector2(355.0, 142.0)]
	dummy_bot.setup_player(902, "Target Bot", 1, true, bot_spawns, 1, ProfileManager.ARCHETYPES[bot_arch])
	dummy_bot.archetype_id = bot_arch
	dummy_bot.spawn_invuln_timer = 0.0
	add_child(dummy_bot)

	NetworkManager.match_mode = prev_mode


func set_agent(arch_id: int) -> void:
	_current_arch = clampi(arch_id, 0, AgentData.AGENTS.size() - 1)
	_hero_dash_casting = false
	_hero_return_delay = 0.0
	_touch_marker_timer = 0.0
	_bot_attack_timer = 0.0
	_bot_respawn_timer = -1.0
	_bot_too_close_timer = 0.0
	if is_instance_valid(_cam):
		_cam.offset = Vector2.ZERO
	_clear_transient_fx()
	var prev_mode: int = NetworkManager.match_mode
	NetworkManager.match_mode = 2
	if is_instance_valid(hero):
		hero._respawn_self()
		hero.archetype_id = _current_arch
		hero._init_agent_kit()
		hero._apply_modular_textures()
		hero._apply_weapon_visuals()
		hero._fly_kick_timer = 0.0
		hero._shadow_dash_timer = 0.0
		hero._bat_ult_timer = 0.0
		hero.preview_move_x = 0.0
		hero.global_position = Vector2(120.0, 142.0)
		hero.velocity = Vector2.ZERO
		hero.aim_angle = 0.0
		hero.facing_right = true
		hero.spawn_invuln_timer = 0.0
		hero.health = hero.max_health
		hero._update_overhead_ui()
		hero.queue_redraw()
	if is_instance_valid(dummy_bot):
		dummy_bot._respawn_self()
		dummy_bot.preview_move_x = 0.0
		dummy_bot.preview_jump = false
		dummy_bot.global_position = Vector2(355.0, 142.0)
		dummy_bot.velocity = Vector2.ZERO
		dummy_bot.aim_angle = PI
		dummy_bot.facing_right = false
		dummy_bot.spawn_invuln_timer = 0.0
		dummy_bot.health = dummy_bot.max_health
		dummy_bot._update_overhead_ui()
		dummy_bot.queue_redraw()
	NetworkManager.match_mode = prev_mode


func cast_slot(slot_i: int) -> void:
	if not is_instance_valid(hero):
		return
	var prev_mode: int = NetworkManager.match_mode
	NetworkManager.match_mode = 2
	if hero.is_dead:
		hero._respawn_self()
		hero.global_position = Vector2(120.0, 142.0)
	if hero.global_position.distance_to(Vector2(120.0, 142.0)) > 160.0:
		hero.global_position = Vector2(120.0, 142.0)
		hero.velocity = Vector2.ZERO
	hero.stun_timer = 0.0
	hero.freeze_timer = 0.0
	hero.control_lock_timer = 0.0
	hero.ability_lock_timer = 0.0
	hero.ult_points = 4
	hero.ability_cooldowns.assign([0.0, 0.0, 0.0, 0.0])
	hero.aim_angle = 0.0
	hero.facing_right = true
	if is_instance_valid(dummy_bot):
		hero.last_world_tap_pos = dummy_bot.global_position + Vector2(0.0, -18.0)
		hero.has_world_tap = true
	var ag: Dictionary = AgentData.get_agent(_current_arch)
	var ab_dict: Dictionary = (ag["ultimate"] if slot_i == 3 else ag["abilities"][clampi(slot_i, 0, 2)]) as Dictionary
	var ab_kind: String = str(ab_dict.get("kind", ""))
	var needs_close: bool = ab_kind in ["ult_self_blast", "aoe_push_ring", "aoe_ability_lock", "aoe_freeze_shatter", "aoe_slam_stun", "aoe_knockback_ring", "banshee_scream"]
	if needs_close and is_instance_valid(dummy_bot) and not dummy_bot.is_dead:
		_hero_dash_casting = true
		_hero_return_delay = 0.85
		var target_x: float = maxf(120.0, dummy_bot.global_position.x - 56.0)
		var tw := create_tween()
		tw.tween_property(hero, "global_position:x", target_x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.finished.connect(func():
			_hero_dash_casting = false
			if is_instance_valid(hero) and not hero.is_dead:
				var pm: int = NetworkManager.match_mode
				NetworkManager.match_mode = 2
				hero.ult_points = 4
				hero.ability_cooldowns.assign([0.0, 0.0, 0.0, 0.0])
				hero.use_agent_ability(slot_i)
				NetworkManager.match_mode = pm
		)
	elif ab_kind == "touch_teleport":
		_touch_marker_pos = Vector2(270.0, 96.0)
		_touch_marker_timer = 1.0
		_hero_dash_casting = true
		_hero_return_delay = 0.95
		hero.last_world_tap_pos = _touch_marker_pos
		hero.has_world_tap = true
		var tp_tw := create_tween()
		tp_tw.tween_interval(0.28)
		tp_tw.finished.connect(func():
			_hero_dash_casting = false
			if is_instance_valid(hero) and not hero.is_dead:
				var pm: int = NetworkManager.match_mode
				NetworkManager.match_mode = 2
				hero.ult_points = 4
				hero.ability_cooldowns.assign([0.0, 0.0, 0.0, 0.0])
				hero.last_world_tap_pos = _touch_marker_pos
				hero.has_world_tap = true
				hero.use_agent_ability(slot_i)
				NetworkManager.match_mode = pm
		)
	elif ab_kind == "throwable_magnet":
		_hero_return_delay = 1.2
		var mag_items: Array[Node2D] = []
		var cols: Array[Color] = [Color(0.95, 0.78, 0.22), Color(0.55, 0.85, 1.0), Color(1.0, 0.45, 0.28)]
		var xs: Array[float] = [235.0, 280.0, 322.0]
		for mi in range(3):
			var item := Area2D.new()
			item.set_meta("item_id", mi)
			item.global_position = Vector2(xs[mi], 158.0)
			var poly := Polygon2D.new()
			poly.polygon = PackedVector2Array([Vector2(-7, -7), Vector2(7, -7), Vector2(9, 2), Vector2(0, 9), Vector2(-9, 2)])
			poly.color = cols[mi]
			item.add_child(poly)
			add_child(item)
			mag_items.append(item)
		var mag_tw := create_tween()
		mag_tw.tween_interval(0.16)
		mag_tw.finished.connect(func():
			if is_instance_valid(hero) and not hero.is_dead:
				var pm: int = NetworkManager.match_mode
				NetworkManager.match_mode = 2
				hero.ult_points = 4
				hero.ability_cooldowns.assign([0.0, 0.0, 0.0, 0.0])
				hero.use_agent_ability(slot_i)
				NetworkManager.match_mode = pm
				for idx in range(mag_items.size()):
					var it: Node2D = mag_items[idx]
					if is_instance_valid(it):
						var dest: Vector2 = hero.global_position + Vector2(18.0 + float(idx) * 10.0, 8.0)
						var ptw := create_tween()
						ptw.tween_property(it, "global_position", dest, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
						ptw.tween_interval(0.8)
						ptw.tween_callback(func():
							if is_instance_valid(it):
								it.queue_free()
						)
		)
	else:
		if ab_kind == "ult_homing_bazooka":
			hero.aim_angle = -0.95
			hero.facing_right = true
		_hero_return_delay = 0.75
		hero.use_agent_ability(slot_i)
	NetworkManager.match_mode = prev_mode


func _clear_transient_fx() -> void:
	for c in get_children():
		if c != hero and c != dummy_bot and not (c is StaticBody2D) and not (c is Camera2D):
			c.queue_free()


func _process(delta: float) -> void:
	if is_instance_valid(dummy_bot) and dummy_bot.is_dead:
		if _bot_respawn_timer < 0.0:
			_bot_respawn_timer = 1.0
		else:
			_bot_respawn_timer -= delta
		if _bot_respawn_timer <= 0.0:
			_bot_respawn_timer = -1.0
			var prev_mode: int = NetworkManager.match_mode
			NetworkManager.match_mode = 2
			dummy_bot._respawn_self()
			dummy_bot.global_position = Vector2(355.0, 142.0)
			dummy_bot.velocity = Vector2.ZERO
			dummy_bot.aim_angle = PI
			dummy_bot.facing_right = false
			dummy_bot.spawn_invuln_timer = 0.0
			NetworkManager.match_mode = prev_mode
	else:
		_bot_respawn_timer = -1.0
	if is_instance_valid(hero) and hero.is_dead:
		var prev_mode2: int = NetworkManager.match_mode
		NetworkManager.match_mode = 2
		hero._respawn_self()
		hero.global_position = Vector2(120.0, 142.0)
		hero.velocity = Vector2.ZERO
		hero.aim_angle = 0.0
		hero.facing_right = true
		hero.spawn_invuln_timer = 0.0
		NetworkManager.match_mode = prev_mode2
	if is_instance_valid(hero) and not hero.is_dead:
		if _hero_return_delay > 0.0:
			_hero_return_delay -= delta
		if hero.boar_ride_timer > 0.0:
			if is_instance_valid(dummy_bot) and not dummy_bot.is_dead:
				hero.preview_move_x = 1.0 if hero.global_position.x <= dummy_bot.global_position.x + 16.0 else -1.0
				hero.aim_angle = 0.0 if hero.preview_move_x >= 0.0 else PI
				hero.facing_right = hero.preview_move_x >= 0.0
			else:
				hero.preview_move_x = 1.0
		elif hero.speed_boost_timer > 0.0 and hero.control_lock_timer <= 0.0:
			if hero.global_position.x >= 290.0:
				_hero_pace_dir = -1.0
			elif hero.global_position.x <= 110.0:
				_hero_pace_dir = 1.0
			hero.preview_move_x = _hero_pace_dir
			hero.aim_angle = 0.0 if _hero_pace_dir >= 0.0 else PI
			hero.facing_right = _hero_pace_dir >= 0.0
		elif not _hero_dash_casting and _hero_return_delay <= 0.0 and hero.control_lock_timer <= 0.0 and hero._fly_kick_timer <= 0.0 and hero._bat_ult_timer <= 0.0 and hero._flurry_state == 0:
			if hero.global_position.x > 128.0:
				hero.preview_move_x = -0.85
			else:
				hero.preview_move_x = 0.0
				hero.aim_angle = 0.0
				hero.facing_right = true
		else:
			hero.preview_move_x = 0.0
	for f in [hero, dummy_bot]:
		if is_instance_valid(f) and not f.is_dead:
			var cx: float = clampf(f.global_position.x, 48.0, 412.0)
			var cy: float = clampf(f.global_position.y, 36.0, 152.0)
			if cx != f.global_position.x:
				f.global_position.x = cx
				f.velocity.x = 0.0
			if cy != f.global_position.y:
				f.global_position.y = cy
				f.velocity.y = 0.0
	if is_instance_valid(hero) and not hero.is_dead and is_instance_valid(dummy_bot) and not dummy_bot.is_dead:
		var has_barrier: bool = false
		var has_blood_bubble: bool = false
		var hazard_zone: Node2D = null
		for c in get_children():
			if c.is_in_group("barrier_walls"):
				has_barrier = true
			elif "summon_kind" in c and str(c.get("summon_kind")) == "blood_bubble":
				has_blood_bubble = true
			elif c is Node2D and (c.has_meta("is_lava") or ("zone_kind" in c)):
				hazard_zone = c as Node2D
		if has_barrier:
			dummy_bot.preview_move_x = -0.65
			_bot_too_close_timer = 0.0
		elif has_blood_bubble:
			var bb_x: float = hero.global_position.x + 36.0
			if dummy_bot.global_position.x > bb_x + 10.0:
				dummy_bot.preview_move_x = -0.95
			elif dummy_bot.global_position.x < bb_x - 10.0:
				dummy_bot.preview_move_x = 0.95
			else:
				dummy_bot.preview_move_x = 0.0
		elif hazard_zone != null:
			var hz_x: float = clampf(hazard_zone.global_position.x + 25.0, 195.0, 315.0)
			if dummy_bot.global_position.x > hz_x + 12.0:
				dummy_bot.preview_move_x = -0.85
			elif dummy_bot.global_position.x < hz_x - 12.0:
				dummy_bot.preview_move_x = 0.85
			else:
				dummy_bot.preview_move_x = 0.0
		elif dummy_bot.global_position.x < 345.0:
			dummy_bot.preview_move_x = 1.0
		else:
			dummy_bot.preview_move_x = 0.0
		if not has_barrier and not has_blood_bubble and hazard_zone == null and dummy_bot.carried_by_peer_id == 0 and dummy_bot.stun_timer <= 0.0 and dummy_bot.freeze_timer <= 0.0 and dummy_bot.thrown_flight_timer <= 0.0:
			if dummy_bot.global_position.distance_to(hero.global_position) < 85.0:
				_bot_too_close_timer += delta
				if _bot_too_close_timer >= 0.35:
					_bot_too_close_timer = 0.0
					dummy_bot.global_position = Vector2(355.0, 142.0)
					dummy_bot.velocity = Vector2.ZERO
					dummy_bot.aim_angle = PI
					dummy_bot.facing_right = false
			else:
				_bot_too_close_timer = 0.0
		else:
			_bot_too_close_timer = 0.0
		var bot_slowed: bool = (dummy_bot.slow_mo_timer > 0.0)
		dummy_bot.preview_jump = (bot_slowed and dummy_bot.is_on_floor() and dummy_bot.stun_timer <= 0.0 and dummy_bot.freeze_timer <= 0.0)
		var hero_defending: bool = (
			has_barrier
			or hero.deathless_timer > 0.0
			or hero.invincible_timer > 0.0
			or hero.invis_timer > 0.0
			or hero.personal_shield_hp > 0
			or hero.gradual_heal_timer > 0.0
		)
		if (hero_defending or bot_slowed) and dummy_bot.stun_timer <= 0.0 and dummy_bot.freeze_timer <= 0.0:
			_bot_attack_timer -= delta
			if _bot_attack_timer <= 0.0:
				_bot_attack_timer = 1.15 if bot_slowed else 0.32
				var shoot_origin: Vector2 = dummy_bot.global_position + Vector2(-12.0, -4.0)
				var shoot_angle: float = (hero.global_position - shoot_origin).angle()
				if hero.invis_timer > 0.0:
					shoot_angle = PI - 0.16
				dummy_bot.aim_angle = shoot_angle
				dummy_bot.facing_right = cos(shoot_angle) >= 0.0
				var b_spd: float = 440.0 if bot_slowed else 920.0
				var b_dmg: int = 8 if bot_slowed else 26
				dummy_bot._spawn_styled_projectile(
					shoot_origin, shoot_angle, b_spd, b_dmg, "bullet",
					Color(1.0, 0.36, 0.28), "Bot Fire", 0.0, 0.0, false, 0.0, 0.4, false, true, 1.2
				)
		else:
			_bot_attack_timer = 0.12
	if _touch_marker_timer > 0.0:
		_touch_marker_timer = maxf(0.0, _touch_marker_timer - delta)
		queue_redraw()
	if is_instance_valid(_cam):
		var shaking: bool = (
			(is_instance_valid(dummy_bot) and not dummy_bot.is_dead and dummy_bot.earth_shake_timer > 0.0)
			or (is_instance_valid(hero) and not hero.is_dead and hero.earth_shake_timer > 0.0)
		)
		_cam.offset = Vector2(randf_range(-3.0, 3.0), randf_range(-2.5, 2.5)) if shaking else Vector2.ZERO
		var want_zoom: Vector2 = Vector2(0.55, 0.55) if (is_instance_valid(hero) and not hero.is_dead and hero.zoom_out_timer > 0.0) else Vector2.ONE
		_cam.zoom = _cam.zoom.lerp(want_zoom, clampf(delta * 8.0, 0.0, 1.0))


func _draw() -> void:
	draw_rect(Rect2(-240, -140, arena_width + 480, arena_height + 280), Color(0.03, 0.04, 0.07))
	draw_rect(Rect2(0, 0, arena_width, arena_height), Color(0.05, 0.07, 0.11))
	for x in range(-200, int(arena_width) + 201, 40):
		draw_line(Vector2(x, -140), Vector2(x, arena_height + 140), Color(1, 1, 1, 0.04), 1.0)
	for y in range(-120, int(arena_height) + 121, 40):
		draw_line(Vector2(-240, y), Vector2(arena_width + 240, y), Color(1, 1, 1, 0.04), 1.0)
	draw_rect(Rect2(0, arena_height - 20.0, arena_width, 20.0), Color(0.22, 0.25, 0.32))
	draw_line(Vector2(0, arena_height - 20.0), Vector2(arena_width, arena_height - 20.0), Color(0.95, 0.72, 0.18), 3.0)
	draw_rect(Rect2(0, 0, 20.0, arena_height), Color(0.18, 0.20, 0.26))
	draw_rect(Rect2(arena_width - 20.0, 0, 20.0, arena_height), Color(0.18, 0.20, 0.26))
	draw_rect(Rect2(0, 0, arena_width, arena_height), Color(0.28, 0.45, 0.68, 0.5), false, 2.0)
	if _touch_marker_timer > 0.0:
		var ta: float = clampf(_touch_marker_timer * 1.4, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.025)
		var mr: float = 20.0 + pulse * 4.0
		draw_circle(_touch_marker_pos, mr, Color(0.32, 0.85, 1.0, ta * 0.22))
		draw_arc(_touch_marker_pos, mr, 0.0, TAU, 28, Color(0.42, 0.92, 1.0, ta * 0.92), 2.5)
		draw_circle(_touch_marker_pos, 4.0, Color(1.0, 1.0, 1.0, ta))
