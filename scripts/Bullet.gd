extends Area2D

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/Explosion.tscn")
const TEX_BULLET: Texture2D = preload("res://assets/sprites/bullet.png")
const TEX_LASER: Texture2D = preload("res://assets/sprites/laser_trail.png")
const TEX_RAVEN: Texture2D = preload("res://assets/sprites/characters/summons/raven_proj.png")
const TEX_HEAVY_FORGE: Texture2D = preload("res://assets/sprites/vfx/ogre_falling_forge.png")
const TEX_MUMMY_HEAD: Texture2D = preload("res://assets/sprites/modular/mummy_head.png")

var velocity: Vector2 = Vector2.RIGHT * 1100.0
var damage: int = 16
var shooter_peer_id: int = 1
var shooter_team: int = 0
var shooter_name: String = "Trooper"
var shooter_rid: RID = RID()
var weapon_name: String = "M4A1"
var bullet_color: Color = Color(1.0, 0.85, 0.25)
var is_laser: bool = false
var is_explosive: bool = false
var explosion_radius: float = 120.0
var can_deal_damage: bool = true
var max_lifetime: float = 1.6
var damage_falloff_start: float = 9999.0
var min_damage_ratio: float = 1.0
var close_lethal_dist: float = 0.0
var stun_duration: float = 0.0
var visual_style: String = "bullet"
var spin_speed: float = 0.0
var knockback_mult: float = 1.0
var pierce_walls: bool = false
var gravity_mult: float = 0.0
var is_homing: bool = false
var homing_turn_rate: float = 4.8
var homing_y_offset: float = 0.0
var allow_self_damage: bool = true
var reverse_controls_dur: float = 0.0
var pierce_players: bool = false
var wall_bounces_left: int = 0
var stop_on_vertical_wall: bool = false
var status_effect_name: String = ""
var status_effect_dur: float = 0.0
var on_hit_effect_kind: String = ""
var boomerang_owner: Node2D = null
var boomerang_return_time: float = 0.0
var radius_scale: float = 1.0:
	set(v):
		radius_scale = v
		scale = Vector2(radius_scale, radius_scale)
var detonate_distance: float = 0.0
var max_range: float = 0.0
var _pierced_rids: Array[RID] = []
var _boomerang_returned: bool = false
var _homing_target_pos: Vector2 = Vector2.INF
var _visual_spin: float = 0.0
var _distance_traveled: float = 0.0

var _age: float = 0.0
var _trail_points: PackedVector2Array = PackedVector2Array()
var max_trail_points: int = 8
var _finished: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _trail: Line2D = $Trail


func _ready() -> void:
	rotation = velocity.angle()
	if visual_style == "mummy_head":
		_sprite.visible = true
		_sprite.texture = TEX_MUMMY_HEAD
		_sprite.region_enabled = true
		_sprite.region_rect = Rect2(56, 10, 144, 148)
		_sprite.scale = Vector2(0.26, 0.26)
	elif visual_style != "bullet":
		_sprite.visible = false
	else:
		_sprite.texture = TEX_LASER if is_laser else TEX_BULLET
		_sprite.modulate = bullet_color
		if is_explosive:
			_sprite.scale = Vector2(1.6, 1.8)
		elif is_laser:
			_sprite.scale = Vector2(1.4, 1.1)

	_trail.default_color = Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.75)
	_trail.width = 6.0 if is_explosive else (5.0 if is_laser else 3.0)
	if visual_style == "slash_wave" or visual_style == "smoke_orb":
		_trail.visible = false
	if on_hit_effect_kind == "hook_drag":
		_trail.visible = false
	_trail_points.append(global_position)
	_trail_points.append(global_position)
	_update_trail_visual()
	if radius_scale != 1.0:
		scale = Vector2(radius_scale, radius_scale)
	if visual_style != "bullet":
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _finished:
		return

	_age += delta
	if visual_style == "plasma_ball":
		queue_redraw()
	if _age >= max_lifetime:
		if is_explosive:
			_trigger_explosion(global_position)
		else:
			_spawn_impact_flash(global_position, bullet_color)
		queue_free()
		return

	if visual_style == "heavy_forge":
		if _age < 1.0:
			velocity = Vector2.ZERO
			queue_redraw()
			return
		elif _age - delta < 1.0:
			velocity = Vector2(0.0, 340.0)

	if gravity_mult > 0.0:
		velocity.y += 980.0 * gravity_mult * maxf(0.15, NetworkManager.gravity_scale) * delta

	if boomerang_return_time > 0.0 and _age >= boomerang_return_time and is_instance_valid(boomerang_owner):
		if not _boomerang_returned:
			_boomerang_returned = true
			_pierced_rids.clear()
		var to_owner: Vector2 = boomerang_owner.global_position - global_position
		if to_owner.length() < 34.0:
			if "headless_timer" in boomerang_owner and visual_style == "mummy_head":
				boomerang_owner.set("headless_timer", 0.0)
			queue_free()
			return
		var spd: float = maxf(680.0, velocity.length())
		velocity = to_owner.normalized() * spd
		rotation = velocity.angle()
	elif is_homing:
		_homing_target_pos = _find_homing_target()
		if _homing_target_pos != Vector2.INF:
			var desired_angle: float = (_homing_target_pos - global_position).angle()
			var current_angle: float = velocity.angle()
			var new_angle: float = rotate_toward(current_angle, desired_angle, homing_turn_rate * delta)
			velocity = Vector2.from_angle(new_angle) * velocity.length()
			rotation = new_angle

	var prev_pos: Vector2 = global_position
	var next_pos: Vector2 = prev_pos + velocity * delta

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(prev_pos, next_pos, 3)
	var excl: Array[RID] = []
	if shooter_rid.is_valid():
		excl.append(shooter_rid)
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and p.has_method("is_alive") and not p.is_alive() and p is CollisionObject2D:
			excl.append((p as CollisionObject2D).get_rid())
	for rid in _pierced_rids:
		if rid.is_valid():
			excl.append(rid)
	if not excl.is_empty():
		query.exclude = excl
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true

	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector2 = hit["position"]
		var hit_norm: Vector2 = hit.get("normal", Vector2.UP)
		var collider: Object = hit["collider"]
		_distance_traveled += prev_pos.distance_to(hit_pos)
		global_position = hit_pos
		_trail_points.append(hit_pos)
		_update_trail_visual()
		_handle_collision(collider, hit_pos, hit_norm)
		return

	_distance_traveled += prev_pos.distance_to(next_pos)
	global_position = next_pos
	if detonate_distance > 0.0 and _distance_traveled >= detonate_distance:
		_handle_collision(null, next_pos, Vector2.UP)
		return
	if max_range > 0.0 and _distance_traveled >= max_range:
		if is_explosive:
			_handle_collision(null, next_pos, Vector2.UP)
		else:
			_finished = true
			queue_free()
		return
	if wall_bounces_left > 0 or radius_scale >= 1.3 or visual_style.begins_with("prop_"):
		var hit_r: float = 34.0 if visual_style.begins_with("prop_") else ((9.5 * radius_scale) if visual_style == "big_blade" else ((13.0 * radius_scale + 4.0) if visual_style == "thrown_stone" else (18.0 * radius_scale + 8.0)))
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p) or int(p.get("peer_id")) == shooter_peer_id:
				continue
			if p.has_method("is_alive") and not p.is_alive():
				continue
			if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
				continue
			if p is CollisionObject2D and _pierced_rids.has((p as CollisionObject2D).get_rid()):
				continue
			if (p as Node2D).global_position.distance_to(global_position) <= hit_r:
				_handle_collision(p, global_position)
				return
	_trail_points.append(next_pos)
	while _trail_points.size() > max_trail_points:
		_trail_points.remove_at(0)
	_update_trail_visual()
	if visual_style != "bullet":
		_visual_spin += spin_speed * delta
		if visual_style == "mummy_head" and is_instance_valid(_sprite):
			_sprite.rotation = _visual_spin
		queue_redraw()
	elif on_hit_effect_kind == "hook_drag":
		queue_redraw()


func _update_trail_visual() -> void:
	var local_pts := PackedVector2Array()
	for pt in _trail_points:
		local_pts.append(to_local(pt))
	_trail.points = local_pts


class SeveredHeadVfx extends Node2D:
	var vel: Vector2 = Vector2(140.0, -260.0)
	var victim: Node = null
	var _age: float = 0.0
	var _life: float = 0.75
	var _has_sprite_head: bool = false

	func _ready() -> void:
		z_index = 26
		if is_instance_valid(victim) and victim.has_node("ModularRig"):
			var rig := victim.get_node("ModularRig")
			if rig != null and "_anim_head" in rig and "_sprite_gear" in rig:
				var anim_h := rig.get("_anim_head") as AnimatedSprite2D
				var gear_s := rig.get("_sprite_gear") as Sprite2D
				if anim_h != null and anim_h.visible and anim_h.sprite_frames != null and anim_h.sprite_frames.has_animation("idle"):
					var h_tex: Texture2D = anim_h.sprite_frames.get_frame_texture("idle", 0)
					if h_tex != null:
						var hs := Sprite2D.new()
						hs.texture = h_tex
						hs.modulate = anim_h.modulate
						hs.flip_h = anim_h.flip_h
						hs.scale = anim_h.scale * rig.scale
						hs.position = Vector2(0.0, 12.0)
						add_child(hs)
						_has_sprite_head = true
				if gear_s != null and gear_s.visible and gear_s.texture != null:
					var gs := Sprite2D.new()
					gs.texture = gear_s.texture
					gs.hframes = gear_s.hframes
					gs.frame = 0
					gs.modulate = gear_s.modulate
					gs.flip_h = gear_s.flip_h
					gs.scale = gear_s.scale * rig.scale
					gs.position = Vector2(0.0, 12.0)
					add_child(gs)
					_has_sprite_head = true
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _life:
			queue_free()
			return
		vel.y += 760.0 * delta
		global_position += vel * delta
		rotation += 11.0 * delta
		var a: float = clampf(1.0 - maxf(0.0, (_age - 0.45) / 0.30), 0.0, 1.0)
		modulate.a = a
		if not _has_sprite_head:
			queue_redraw()

	func _draw() -> void:
		if _has_sprite_head:
			return
		var a: float = clampf(1.0 - maxf(0.0, (_age - 0.45) / 0.30), 0.0, 1.0)
		draw_circle(Vector2.ZERO, 12.0, Color(0.08, 0.05, 0.07, a))
		draw_circle(Vector2.ZERO, 9.5, Color(0.76, 0.56, 0.44, a))
		draw_line(Vector2(-7.0, 6.0), Vector2(7.0, 6.0), Color(0.85, 0.14, 0.18, a), 3.0)
		draw_circle(Vector2(-3.0, -2.0), 2.0, Color(0.08, 0.05, 0.07, a))
		draw_circle(Vector2(3.0, -2.0), 2.0, Color(0.08, 0.05, 0.07, a))


func _find_homing_target() -> Vector2:
	var best_pos: Vector2 = Vector2.INF
	var best_dist_sq: float = 950.0 * 950.0
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		var p_id: int = int(p.get("peer_id")) if "peer_id" in p else -999
		if p_id == shooter_peer_id:
			continue
		if NetworkManager.is_team_mode():
			var p_team: int = int(p.get("team_id")) if "team_id" in p else -1
			if p_team == shooter_team:
				continue
		var d_sq: float = global_position.distance_squared_to(p.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_pos = p.global_position + Vector2(0.0, homing_y_offset)
	return best_pos


func _handle_collision(collider: Object, hit_pos: Vector2, hit_norm: Vector2 = Vector2.UP) -> void:
	_finished = true
	if collider != null and collider.is_in_group("prism_mirrors"):
		var m_owner_id: int = int(collider.get("owner_peer_id"))
		var m_team: int = int(collider.get("owner_team"))
		var m_dir: float = float(collider.get("facing_dir"))
		var same_side: bool = (shooter_peer_id == m_owner_id) or (NetworkManager.is_team_mode() and shooter_team == m_team)
		var from_front: bool = (velocity.x * m_dir) < -1.0
		if same_side or not from_front:
			_finished = false
			if collider is CollisionObject2D:
				_pierced_rids.append((collider as CollisionObject2D).get_rid())
			global_position = hit_pos + velocity.normalized() * 12.0
			return
		var base_ang: float = 0.0 if m_dir > 0.0 else PI
		var rand_ang: float = base_ang + randf_range(-1.15, 1.15)
		velocity = Vector2.from_angle(rand_ang) * maxf(velocity.length(), 420.0)
		rotation = velocity.angle()
		global_position = hit_pos + Vector2.from_angle(rand_ang) * 14.0
		_finished = false
		_spawn_impact_flash(hit_pos, Color(1.0, 0.72, 0.96))
		return
	if collider != null and collider.is_in_group("barrier_walls"):
		if can_deal_damage and collider.has_method("apply_wall_damage"):
			collider.apply_wall_damage(damage)
		if is_explosive:
			_trigger_explosion(hit_pos)
		else:
			_spawn_impact_flash(hit_pos, bullet_color)
		queue_free()
		return

	if collider != null and collider.is_in_group("shooting_targets"):
		if can_deal_damage and collider.has_method("on_target_hit"):
			collider.on_target_hit(damage, hit_pos, shooter_peer_id)
		if is_explosive:
			_trigger_explosion(hit_pos)
		else:
			_spawn_impact_flash(hit_pos, bullet_color)
		queue_free()
		return

	if collider != null and collider.is_in_group("destructible_bombs"):
		var target_obj: Object = collider.get_meta("prop_node") if collider.has_meta("prop_node") else collider
		if can_deal_damage:
			if target_obj.has_method("detonate_barrel"):
				target_obj.detonate_barrel(shooter_peer_id, shooter_name, shooter_team)
			elif target_obj.has_method("on_shot_hit"):
				target_obj.on_shot_hit(damage, shooter_peer_id)
		if is_explosive:
			_trigger_explosion(hit_pos)
		else:
			_spawn_impact_flash(hit_pos, bullet_color)
		queue_free()
		return

	if is_explosive:
		if collider != null and collider.is_in_group("players") and int(collider.get("peer_id")) != shooter_peer_id:
			if not (NetworkManager.is_team_mode() and int(collider.get("team_id")) == shooter_team):
				if can_deal_damage and collider.has_method("apply_hit") and on_hit_effect_kind != "death_kiss":
					collider.apply_hit(damage, shooter_peer_id, weapon_name, shooter_name, velocity.normalized() * 240.0)
		_trigger_explosion(hit_pos)
		queue_free()
		return

	if collider != null and collider.is_in_group("players"):
		if collider.has_method("is_alive") and not collider.is_alive():
			_finished = false
			global_position = hit_pos + velocity.normalized() * 10.0
			return
		if int(collider.get("peer_id")) == shooter_peer_id:
			_finished = false
			global_position = hit_pos + velocity.normalized() * 10.0
			return
		if NetworkManager.is_team_mode() and int(collider.get("team_id")) == shooter_team:
			_finished = false
			global_position = hit_pos + velocity.normalized() * 6.0
			return
		if can_deal_damage and collider.has_method("apply_hit") and on_hit_effect_kind != "death_kiss":
			var final_damage: int = _compute_falloff_damage()
			var knockback: Vector2 = velocity.normalized() * (140.0 * knockback_mult)
			collider.apply_hit(final_damage, shooter_peer_id, weapon_name, shooter_name, knockback)
			if on_hit_effect_kind == "hook_drag" and is_instance_valid(boomerang_owner) and collider.has_method("start_hook_pull"):
				var stop_off: float = 42.0 if (collider as Node2D).global_position.x > boomerang_owner.global_position.x else -42.0
				collider.start_hook_pull(boomerang_owner.global_position + Vector2(stop_off, -8.0))
			elif on_hit_effect_kind == "hook_gun" and is_instance_valid(boomerang_owner) and collider.has_method("request_hook_pull"):
				var stop_off: float = 42.0 if (collider as Node2D).global_position.x > boomerang_owner.global_position.x else -42.0
				collider.request_hook_pull(boomerang_owner.global_position + Vector2(stop_off, -8.0))
			elif on_hit_effect_kind == "bubble_trap" and collider.has_method("apply_bubble_trap"):
				collider.apply_bubble_trap(10.0, 120)
			if stun_duration > 0.0 and collider.has_method("apply_stun"):
				collider.apply_stun(stun_duration, shooter_peer_id)
			if reverse_controls_dur > 0.0 and collider.has_method("apply_reverse_controls"):
				collider.apply_reverse_controls(reverse_controls_dur)
			if status_effect_name != "" and collider.has_method("apply_status"):
				collider.apply_status(status_effect_name, status_effect_dur, shooter_peer_id)
		_spawn_impact_flash(hit_pos, bullet_color)
		if on_hit_effect_kind != "":
			_trigger_on_hit_effect(hit_pos)
		if pierce_players:
			if collider is CollisionObject2D:
				_pierced_rids.append((collider as CollisionObject2D).get_rid())
			_finished = false
			global_position = hit_pos + velocity.normalized() * 12.0
			return
		if visual_style == "smoke_orb" and reverse_controls_dur > 0.0:
			_spawn_impact_flash(hit_pos, Color(0.55, 0.22, 0.85))
			if can_deal_damage:
				for p in get_tree().get_nodes_in_group("players"):
					if is_instance_valid(p) and int(p.get("peer_id")) != shooter_peer_id:
						if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
							continue
						if (p as Node2D).global_position.distance_to(hit_pos) <= 115.0 and p.has_method("apply_reverse_controls"):
							p.apply_reverse_controls(reverse_controls_dur)
	else:
		if wall_bounces_left > 0 and not (stop_on_vertical_wall and absf(hit_norm.x) > 0.6):
			wall_bounces_left -= 1
			_finished = false
			var n: Vector2 = hit_norm.normalized() if hit_norm.length_squared() > 0.01 else Vector2.UP
			velocity = velocity.bounce(n)
			if stop_on_vertical_wall:
				velocity *= 0.74
			rotation = velocity.angle()
			global_position = hit_pos + n * maxf(8.0, 10.0 * radius_scale)
			_spawn_impact_flash(hit_pos, bullet_color)
			return
		if (on_hit_effect_kind == "hook_drag" or on_hit_effect_kind == "hook_gun") and is_instance_valid(boomerang_owner) and boomerang_owner.has_method("start_hook_pull"):
			_spawn_impact_flash(hit_pos, Color(1.0, 0.85, 0.45))
			boomerang_owner.start_hook_pull(hit_pos + hit_norm * 24.0)
		elif on_hit_effect_kind == "ice_platform":
			_trigger_on_hit_effect(hit_pos)
		elif on_hit_effect_kind != "":
			_spawn_impact_flash(hit_pos, Color(1.0, 0.85, 0.45))
			_trigger_on_hit_effect(hit_pos)
		else:
			_spawn_impact_flash(hit_pos, Color(1.0, 0.85, 0.45))
		if visual_style == "heavy_forge":
			_spawn_impact_flash(hit_pos, Color(0.78, 0.34, 1.0))
			if can_deal_damage:
				for p in get_tree().get_nodes_in_group("players"):
					if not is_instance_valid(p) or int(p.get("peer_id")) == shooter_peer_id:
						continue
					if p.has_method("is_alive") and not p.is_alive():
						continue
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
						continue
					if p is CollisionObject2D and _pierced_rids.has((p as CollisionObject2D).get_rid()):
						continue
					var p_pos: Vector2 = (p as Node2D).global_position
					if absf(p_pos.x - hit_pos.x) <= 58.0 and absf(p_pos.y - hit_pos.y) <= 54.0 and p.has_method("apply_hit"):
						p.apply_hit(damage, shooter_peer_id, weapon_name, shooter_name, Vector2(0.0, 260.0))
		if visual_style == "smoke_orb" and reverse_controls_dur > 0.0 and can_deal_damage:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and int(p.get("peer_id")) != shooter_peer_id:
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
						continue
					if (p as Node2D).global_position.distance_to(hit_pos) <= 115.0 and p.has_method("apply_reverse_controls"):
						p.apply_reverse_controls(reverse_controls_dur)

	queue_free()


func _trigger_on_hit_effect(hit_pos: Vector2) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	match on_hit_effect_kind:
		"ability_lock_aoe":
			if can_deal_damage:
				for p in get_tree().get_nodes_in_group("players"):
					if is_instance_valid(p) and int(p.get("peer_id")) != shooter_peer_id:
						if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
							continue
						if (p as Node2D).global_position.distance_to(hit_pos) <= 145.0 and p.has_method("apply_status"):
							p.apply_status("ability_lock", status_effect_dur)
		"jelly_aoe":
			_spawn_impact_flash(hit_pos, bullet_color)
			var parent_n: Node = get_parent()
			if parent_n != null:
				var j_zone := Node2D.new()
				j_zone.set_script(load("res://scripts/PlatformHazardZone.gd"))
				j_zone.set("zone_kind", "jelly_slowmo")
				j_zone.set("global_position", hit_pos)
				j_zone.set("time_left", maxf(3.0, status_effect_dur))
				j_zone.set("radius", 135.0)
				j_zone.set("dps", 0)
				j_zone.set("shooter_id", shooter_peer_id)
				j_zone.set("shooter_team", shooter_team)
				j_zone.set("shooter_name", shooter_name)
				j_zone.set("weapon_name", weapon_name)
				j_zone.set("zone_color", bullet_color)
				j_zone.set("can_deal", can_deal_damage)
				parent_n.add_child(j_zone)
			var b_scene: PackedScene = load("res://scenes/Bullet.tscn") as PackedScene
			for p in get_tree().get_nodes_in_group("players"):
				if not is_instance_valid(p) or int(p.get("peer_id")) == shooter_peer_id:
					continue
				if p.has_method("is_alive") and not p.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
					continue
				var dist: float = (p as Node2D).global_position.distance_to(hit_pos)
				if dist <= 145.0:
					if p.has_method("apply_status"):
						p.apply_status("slow_mo", status_effect_dur)
					if can_deal_damage and damage > 0 and p.has_method("apply_hit"):
						p.apply_hit(damage, shooter_peer_id, weapon_name, shooter_name, Vector2.ZERO)
				elif dist <= 460.0 and parent_n != null and b_scene != null:
					var bubble := b_scene.instantiate()
					var b_dir: Vector2 = ((p as Node2D).global_position - hit_pos).normalized()
					bubble.global_position = hit_pos + b_dir * 12.0
					bubble.velocity = b_dir * 1150.0
					bubble.damage = maxi(6, int(damage * 0.5))
					bubble.shooter_peer_id = shooter_peer_id
					bubble.shooter_team = shooter_team
					bubble.shooter_name = shooter_name
					bubble.shooter_rid = shooter_rid
					bubble.weapon_name = weapon_name
					bubble.bullet_color = Color(1.0, 0.52, 0.88)
					bubble.visual_style = "acid_glob"
					bubble.radius_scale = 0.95
					bubble.gravity_mult = 0.0
					bubble.max_lifetime = 0.75
					bubble.can_deal_damage = can_deal_damage
					bubble.status_effect_name = "slow_mo"
					bubble.status_effect_dur = status_effect_dur
					parent_n.add_child(bubble)
		"death_kiss":
			var dk_parent: Node = get_parent()
			for p in get_tree().get_nodes_in_group("players"):
				if not is_instance_valid(p) or int(p.get("peer_id")) == shooter_peer_id:
					continue
				if p.has_method("is_alive") and not p.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
					continue
				if (p as Node2D).global_position.distance_to(hit_pos) <= 230.0:
					if "headless_timer" in p:
						p.set("headless_timer", 0.65)
					if p.has_method("apply_stun"):
						p.apply_stun(0.55, shooter_peer_id)
					if dk_parent != null:
						var sh := SeveredHeadVfx.new()
						sh.victim = p
						sh.global_position = (p as Node2D).global_position + Vector2(0.0, -18.0)
						sh.vel = Vector2(140.0 if velocity.x >= 0.0 else -140.0, -260.0)
						dk_parent.add_child(sh)
					if can_deal_damage and p.has_method("apply_hit"):
						var target_p: Node = p
						var dmg_val: int = damage
						var s_id: int = shooter_peer_id
						var w_name: String = weapon_name
						var s_name: String = shooter_name
						get_tree().create_timer(0.5).timeout.connect(func():
							if is_instance_valid(target_p) and (not target_p.has_method("is_alive") or target_p.is_alive()):
								if "headless_timer" in target_p:
									target_p.set("headless_timer", 0.0)
								target_p.apply_hit(dmg_val, s_id, w_name, s_name, Vector2(0, -120))
						)
			_spawn_impact_flash(hit_pos, Color(0.95, 0.35, 0.85))
		"ice_platform", "lava_platform":
			var zone := Node2D.new()
			zone.set_script(load("res://scripts/PlatformHazardZone.gd"))
			var is_lava: bool = (on_hit_effect_kind == "lava_platform")
			zone.set_meta("is_lava", is_lava)
			zone.set_meta("shooter_id", shooter_peer_id)
			zone.set_meta("shooter_team", shooter_team)
			zone.set_meta("shooter_name", shooter_name)
			zone.set_meta("weapon_name", weapon_name)
			zone.set_meta("can_deal", can_deal_damage)
			zone.set_meta("time_left", status_effect_dur)
			zone.set_meta("tick_accum", 0.0)
			zone.global_position = hit_pos
			parent_node.add_child(zone)


func _compute_falloff_damage() -> int:
	if close_lethal_dist > 0.0 and _distance_traveled <= close_lethal_dist:
		return maxi(damage, 250)
	if min_damage_ratio >= 0.999 or _distance_traveled <= damage_falloff_start:
		return damage
	var falloff_span: float = maxf(85.0, damage_falloff_start * 0.85)
	var t: float = clampf((_distance_traveled - damage_falloff_start) / falloff_span, 0.0, 1.0)
	var ratio: float = lerpf(1.0, clampf(min_damage_ratio, 0.1, 1.0), t)
	return maxi(1, int(round(float(damage) * ratio)))


func _trigger_explosion(pos: Vector2) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var exp := EXPLOSION_SCENE.instantiate()
	exp.global_position = pos
	exp.explosion_radius = explosion_radius
	exp.max_damage = damage
	exp.shooter_peer_id = shooter_peer_id
	exp.shooter_team = shooter_team
	exp.shooter_name = shooter_name
	exp.weapon_name = weapon_name
	exp.stun_duration = stun_duration
	exp.ring_color = bullet_color
	exp.custom_splash_only = (visual_style == "acid_glob")
	exp.can_deal_damage = can_deal_damage
	exp.allow_self_damage = allow_self_damage
	parent_node.add_child(exp)
	if status_effect_name != "" and status_effect_dur > 0.0:
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p) or int(p.get("peer_id")) == shooter_peer_id:
				continue
			if p.has_method("is_alive") and not p.is_alive():
				continue
			if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
				continue
			if (p as Node2D).global_position.distance_to(pos) <= explosion_radius and p.has_method("apply_status"):
				p.apply_status(status_effect_name, status_effect_dur, shooter_peer_id)


func _spawn_impact_flash(pos: Vector2, col: Color) -> void:
	if visual_style == "slash_wave":
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var exp := EXPLOSION_SCENE.instantiate()
	exp.global_position = pos
	exp.max_damage = 0
	exp.can_deal_damage = false
	if weapon_name == "Obsidian Talon Bow":
		exp.lightning_orb_only = true
		exp.ring_color = col
		exp.explosion_radius = 40.0
	else:
		exp.explosion_radius = 28.0
		exp.modulate = col
	parent_node.add_child(exp)


func _draw() -> void:
	if on_hit_effect_kind == "hook_drag" and is_instance_valid(boomerang_owner):
		draw_line(Vector2.ZERO, to_local(boomerang_owner.global_position), Color(0.88, 0.72, 0.32), 3.0)
	if visual_style == "bullet":
		return
	if visual_style in ["rocket", "homing_rocket"]:
		if is_homing and _homing_target_pos != Vector2.INF:
			var t_local: Vector2 = to_local(_homing_target_pos)
			draw_line(Vector2.ZERO, t_local, Color(1.0, 0.25, 0.20, 0.35), 1.5)
			draw_arc(t_local, 22.0, 0.0, TAU, 24, Color(1.0, 0.28, 0.22, 0.85), 2.2)
			draw_line(t_local + Vector2(-28, 0), t_local + Vector2(-14, 0), Color(1.0, 0.35, 0.25, 0.9), 2.0)
			draw_line(t_local + Vector2(14, 0), t_local + Vector2(28, 0), Color(1.0, 0.35, 0.25, 0.9), 2.0)
			draw_line(t_local + Vector2(0, -28), t_local + Vector2(0, -14), Color(1.0, 0.35, 0.25, 0.9), 2.0)
			draw_line(t_local + Vector2(0, 14), t_local + Vector2(0, 28), Color(1.0, 0.35, 0.25, 0.9), 2.0)
		draw_set_transform(Vector2.ZERO, velocity.angle() - rotation, Vector2.ONE)
		var flame_len: float = 12.0 + sin(_age * 48.0) * 5.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(-11.0, -4.0), Vector2(-11.0 - flame_len, 0.0), Vector2(-11.0, 4.0)
		]), Color(1.0, 0.55, 0.12, 0.92))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-11.0, -2.2), Vector2(-11.0 - flame_len * 0.6, 0.0), Vector2(-11.0, 2.2)
		]), Color(1.0, 0.94, 0.55))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12.0, -3.5), Vector2(-6.0, -8.0), Vector2(-4.0, -3.5)
		]), Color(0.28, 0.32, 0.36))
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12.0, 3.5), Vector2(-6.0, 8.0), Vector2(-4.0, 3.5)
		]), Color(0.28, 0.32, 0.36))
		draw_rect(Rect2(-11.0, -3.8, 17.0, 7.6), Color(0.36, 0.44, 0.32))
		var nose_col: Color = Color(1.0, 0.24, 0.18) if visual_style == "homing_rocket" else Color(0.88, 0.38, 0.16)
		draw_colored_polygon(PackedVector2Array([
			Vector2(6.0, -4.2), Vector2(17.0, 0.0), Vector2(6.0, 4.2)
		]), nose_col)
		if visual_style == "homing_rocket":
			draw_arc(Vector2(10.0, 0.0), 8.0, 0.0, TAU, 16, Color(1.0, 0.35, 0.28, 0.75), 1.8)
		return
	draw_set_transform(Vector2.ZERO, _visual_spin, Vector2.ONE)
	match visual_style:
		"fireball":
			var life_t: float = clampf(_age / maxf(max_lifetime, 0.01), 0.0, 1.0)
			var bs: float = lerpf(1.25, 2.85, life_t)
			var fade_a: float = clampf(1.0 - maxf(0.0, (life_t - 0.65) / 0.35), 0.15, 1.0)
			draw_circle(Vector2(-6.0 * bs, 0.0), 15.0 * bs, Color(0.95, 0.24, 0.06, 0.30 * fade_a))
			draw_circle(Vector2.ZERO, 13.5 * bs, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.45 * fade_a))
			draw_circle(Vector2(2.0 * bs, 0.0), 9.5 * bs, Color(1.0, 0.52, 0.12, 0.90 * fade_a))
			draw_circle(Vector2(4.0 * bs, 0.0), 5.5 * bs, Color(1.0, 0.94, 0.58, fade_a))
		"acid_glob":
			draw_circle(Vector2.ZERO, 11.5, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.38))
			draw_circle(Vector2(-2.0, 1.0), 7.2, bullet_color)
			draw_circle(Vector2(3.0, -2.0), 4.2, bullet_color.lightened(0.35))
			draw_circle(Vector2(-3.5, -2.5), 2.2, Color(0.92, 1.0, 0.78))
		"ice_shard":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-11.0, 0.0), Vector2(0.0, -5.5), Vector2(14.0, 0.0), Vector2(0.0, 5.5)
			]), bullet_color)
			draw_line(Vector2(-4.0, -1.5), Vector2(8.0, -0.5), Color(1.0, 1.0, 1.0, 0.85), 2.0)
		"shuriken":
			for k in range(4):
				var ang: float = float(k) * PI * 0.5
				var tip: Vector2 = Vector2.from_angle(ang) * 11.0
				var side: Vector2 = Vector2.from_angle(ang + 0.45) * 4.5
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO, side, tip]), bullet_color)
			draw_circle(Vector2.ZERO, 2.5, Color(0.14, 0.16, 0.22))
		"big_blade":
			draw_circle(Vector2.ZERO, 12.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.25))
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color.WHITE, 2.2)
			for k in range(6):
				var ang: float = float(k) * TAU / 6.0
				var tip: Vector2 = Vector2.from_angle(ang) * 15.0
				var side: Vector2 = Vector2.from_angle(ang + 0.42) * 8.0
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO, side, tip]), bullet_color)
			draw_circle(Vector2.ZERO, 4.0, Color(0.12, 0.14, 0.20))
		"ghost_wisp":
			draw_circle(Vector2.ZERO, 12.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.28))
			draw_circle(Vector2.ZERO, 7.5, bullet_color)
			draw_circle(Vector2(1.5, -1.5), 3.0, Color.WHITE)
		"arrow":
			var lt_step: int = int(_age * 28.0)
			var zig_a: float = sin(float(lt_step) * 2.3 + _age * 36.0) * 5.0
			var zig_b: float = cos(float(lt_step) * 1.9 + _age * 42.0) * 5.5
			var bolt_pts := PackedVector2Array([
				Vector2(-20.0, zig_a * 0.4),
				Vector2(-10.0, -zig_b),
				Vector2(-2.0, zig_a),
				Vector2(7.0, -zig_b * 0.75),
				Vector2(17.0, 0.0),
			])
			var neon_glow := Color(0.66, 0.18, 1.0, 0.36)
			var neon_mid := Color(0.84, 0.38, 1.0, 0.96)
			var neon_core := Color(0.98, 0.90, 1.0, 1.0)
			draw_circle(Vector2(12.0, 0.0), 11.0, Color(0.68, 0.20, 1.0, 0.28))
			draw_polyline(bolt_pts, neon_glow, 9.0)
			draw_polyline(bolt_pts, neon_mid, 4.4)
			draw_polyline(bolt_pts, neon_core, 2.0)
			# Small crackling side arcs
			draw_line(Vector2(-2.0, zig_a), Vector2(-6.0, zig_a + (8.0 if lt_step % 2 == 0 else -8.0)), neon_mid, 1.8)
			draw_line(Vector2(7.0, -zig_b * 0.75), Vector2(4.0, -zig_b * 0.75 + (-7.0 if lt_step % 2 == 0 else 7.0)), neon_core, 1.4)
		"slash_wave":
			var age_frac: float = clampf(_age / maxf(max_lifetime, 0.01), 0.0, 1.0)
			var fade: float = 1.0 - age_frac * 0.45
			var bc: Color = bullet_color
			var bc_hi: Color = bc.lightened(0.45)
			var bc_core: Color = bc.lightened(0.80)
			# Outer neon bloom ribbon
			_draw_tapered_slash_arc(Vector2(-10.0, 0.0), 42.0, -1.35, 1.35, 24, Color(bc.r, bc.g, bc.b, 0.30 * fade), 18.0)
			# Flowing layered energy streaks
			_draw_tapered_slash_arc(Vector2(-10.0, 0.0), 39.0, -1.30, 1.30, 24, Color(bc.r, bc.g, bc.b, 0.68 * fade), 10.0)
			_draw_tapered_slash_arc(Vector2(-14.0, 0.0), 35.0, -1.15, 1.15, 20, Color(bc_hi.r, bc_hi.g, bc_hi.b, 0.72 * fade), 6.0)
			# Crisp white-hot leading edge
			_draw_tapered_slash_arc(Vector2(-8.0, 0.0), 42.0, -1.22, 1.22, 22, Color(bc_core.r, bc_core.g, bc_core.b, 0.96 * fade), 3.6)
			# Glowing energy bubbles & sparks along the outer arc
			var spark_angles: Array[float] = [-0.95, -0.55, -0.18, 0.15, 0.52, 0.88]
			for si in range(spark_angles.size()):
				var ang: float = spark_angles[si]
				var dist_out: float = 48.0 + float((si * 7) % 13) + age_frac * 14.0
				var sp_pos: Vector2 = Vector2(-10.0, 0.0) + Vector2.from_angle(ang) * dist_out
				var r_bub: float = 2.0 + float(si % 3) * 1.1
				if si % 2 == 0:
					draw_arc(sp_pos, r_bub, 0.0, TAU, 12, Color(bc_hi.r, bc_hi.g, bc_hi.b, 0.78 * fade), 1.4)
				else:
					draw_circle(sp_pos, r_bub * 0.85, Color(bc_core.r, bc_core.g, bc_core.b, 0.88 * fade))
		"stun_bolt":
			draw_circle(Vector2.ZERO, 9.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.45))
			draw_polyline(PackedVector2Array([
				Vector2(-11.0, -4.0), Vector2(-3.0, 3.0), Vector2(3.0, -3.0), Vector2(11.0, 4.0)
			]), Color.WHITE, 3.0)
		"plasma_ball":
			var pulse: float = 1.0 + 0.14 * sin(_age * 28.0)
			var flicker: float = sin(_age * 36.0) * 3.5
			# Outer blue burning aura & flame tail
			draw_circle(Vector2(-10.0, flicker * 0.5), 16.0 * pulse, Color(0.08, 0.42, 1.0, 0.30))
			draw_circle(Vector2(-19.0, -flicker * 0.4), 10.5 * pulse, Color(0.90, 0.97, 1.0, 0.45))
			draw_circle(Vector2.ZERO, 24.0 * pulse, Color(0.08, 0.48, 1.0, 0.34))
			# Main electric-blue plasma sphere
			draw_circle(Vector2.ZERO, 15.5 * pulse, Color(0.16, 0.76, 1.0, 0.94))
			# White fire tongues flickering around the ball
			for k in range(6):
				var fang: float = float(k) * (TAU / 6.0) + _age * 9.0
				var fpos := Vector2.from_angle(fang) * (12.0 + 2.5 * sin(_age * 30.0 + float(k)))
				draw_circle(fpos, 4.2, Color(0.96, 0.99, 1.0, 0.88))
			# Bright white-hot burning core
			draw_circle(Vector2.ZERO, 9.2 * pulse, Color(0.96, 0.99, 1.0, 0.98))
		"stun_bomb":
			draw_circle(Vector2.ZERO, 14.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.30))
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.85), 2.5)
			draw_circle(Vector2.ZERO, 8.0, bullet_color)
			draw_circle(Vector2(-2.0, -2.0), 3.2, Color.WHITE)
			draw_polyline(PackedVector2Array([
				Vector2(-7.0, 0.0), Vector2(7.0, 0.0)
			]), Color.WHITE, 2.0)
			draw_polyline(PackedVector2Array([
				Vector2(0.0, -7.0), Vector2(0.0, 7.0)
			]), Color.WHITE, 2.0)
		"thrown_axe":
			draw_line(Vector2(-11.0, 0.0), Vector2(11.0, 0.0), Color(0.45, 0.28, 0.14), 3.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(3.0, -11.0), Vector2(12.0, -7.0), Vector2(12.0, 7.0), Vector2(3.0, 11.0)
			]), bullet_color)
		"thrown_sword":
			draw_line(Vector2(-12.0, 0.0), Vector2(-6.0, 0.0), Color(0.35, 0.22, 0.12), 4.0)
			draw_line(Vector2(-6.0, -6.0), Vector2(-6.0, 6.0), Color(0.95, 0.78, 0.28), 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5.0, -3.5), Vector2(14.0, 0.0), Vector2(-5.0, 3.5)
			]), bullet_color)
		"thrown_spear":
			draw_line(Vector2(-15.0, 0.0), Vector2(8.0, 0.0), Color(0.62, 0.44, 0.22), 3.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(17.0, 0.0), Vector2(6.0, -4.5), Vector2(6.0, 4.5)
			]), bullet_color)
		"grapple_hook":
			draw_circle(Vector2(-4.0, 0.0), 4.0, Color(0.55, 0.58, 0.65))
			draw_polyline(PackedVector2Array([Vector2(-4.0, 0.0), Vector2(12.0, 0.0)]), Color(0.85, 0.88, 0.94), 3.0)
			draw_polyline(PackedVector2Array([Vector2(4.0, -10.0), Vector2(14.0, 0.0), Vector2(4.0, 10.0)]), Color(0.92, 0.78, 0.35), 3.5)
		"thrown_hammer":
			draw_line(Vector2(-11.0, 0.0), Vector2(7.0, 0.0), Color(0.45, 0.28, 0.14), 3.5)
			draw_rect(Rect2(3.0, -10.0, 10.0, 20.0), bullet_color)
			draw_rect(Rect2(3.0, -10.0, 10.0, 20.0), Color(0.12, 0.14, 0.20), false, 2.0)
		"thrown_shoe":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-11.0, -9.0), Vector2(-1.0, -9.0), Vector2(2.0, -1.0),
				Vector2(12.0, 1.0), Vector2(12.0, 8.0), Vector2(-11.0, 8.0)
			]), bullet_color)
			draw_rect(Rect2(-11.0, 5.5, 23.0, 3.5), Color(0.16, 0.14, 0.12))
			draw_line(Vector2(-2.0, -4.0), Vector2(3.0, -1.0), Color.WHITE, 2.0)
		"raven_stone":
			draw_circle(Vector2.ZERO, 17.0, Color(0.58, 0.22, 0.96, 0.26))
			var rs_pts := PackedVector2Array([
				Vector2(-14.0, -4.0), Vector2(-6.0, -14.0), Vector2(8.0, -12.0),
				Vector2(15.0, 1.0), Vector2(7.0, 13.0), Vector2(-9.0, 12.0)
			])
			draw_colored_polygon(rs_pts, Color(0.12, 0.11, 0.16))
			draw_polyline(rs_pts + PackedVector2Array([rs_pts[0]]), Color(0.04, 0.04, 0.06), 2.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-8.0, -8.0), Vector2(5.0, -9.0), Vector2(7.0, 0.0), Vector2(-4.0, 2.0)
			]), Color(0.24, 0.18, 0.36))
			draw_line(Vector2(-7.0, -3.0), Vector2(1.0, 2.0), Color(0.74, 0.32, 1.0), 2.5)
			draw_line(Vector2(1.0, 2.0), Vector2(8.0, -5.0), Color(0.90, 0.65, 1.0), 1.8)
			draw_line(Vector2(1.0, 2.0), Vector2(4.0, 9.0), Color(0.74, 0.32, 1.0), 2.0)
		"thrown_stone":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12.0, -4.0), Vector2(-5.0, -12.0), Vector2(7.0, -10.0),
				Vector2(13.0, 1.0), Vector2(6.0, 11.0), Vector2(-8.0, 10.0)
			]), bullet_color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-6.0, -6.0), Vector2(4.0, -7.0), Vector2(6.0, 1.0), Vector2(-3.0, 2.0)
			]), bullet_color.lightened(0.28))
		"fiery_hand":
			# Outer roaring flame aura
			draw_circle(Vector2(-2.0, 0.0), 16.0, Color(1.0, 0.28, 0.05, 0.38))
			draw_circle(Vector2(2.0, 0.0), 12.5, Color(1.0, 0.58, 0.12, 0.65))
			# Skeletal palm
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10.0, -5.0), Vector2(2.0, -7.0), Vector2(6.0, 0.0),
				Vector2(2.0, 7.0), Vector2(-10.0, 5.0)
			]), Color(0.95, 0.92, 0.86))
			# 4 forward clawed fingers + thumb covered in fire
			for fy in [-6.0, -2.0, 2.0, 6.0]:
				draw_line(Vector2(3.0, fy), Vector2(13.0, fy * 1.15), Color(1.0, 0.55, 0.10), 4.0)
				draw_line(Vector2(3.0, fy), Vector2(12.0, fy * 1.1), Color(0.96, 0.94, 0.88), 2.2)
			draw_line(Vector2(-2.0, -6.0), Vector2(3.0, -12.0), Color(1.0, 0.68, 0.15), 3.2)
			draw_circle(Vector2(-6.0, 0.0), 4.5, Color(1.0, 0.90, 0.35, 0.85))
		"mummy_head":
			draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(1.0, 0.82, 0.24, 0.45), 2.0)
		"grenade", "frag_bomb":
			draw_circle(Vector2.ZERO, 10.5, Color(0.18, 0.24, 0.20))
			draw_arc(Vector2.ZERO, 10.5, 0.0, TAU, 20, bullet_color, 2.8)
			draw_circle(Vector2(-3.0, -3.0), 3.0, Color(1.0, 1.0, 1.0, 0.45))
		"hook_gun_claw":
			if is_instance_valid(boomerang_owner):
				draw_line(Vector2.ZERO, to_local(boomerang_owner.global_position), Color(0.88, 0.72, 0.32, 0.85), 2.5)
			draw_line(Vector2(-8.0, 0.0), Vector2(6.0, 0.0), Color(0.88, 0.72, 0.32), 4.0)
			draw_line(Vector2(2.0, -8.0), Vector2(11.0, -4.0), Color(0.95, 0.82, 0.38), 3.0)
			draw_line(Vector2(2.0, 8.0), Vector2(11.0, 4.0), Color(0.95, 0.82, 0.38), 3.0)
			draw_circle(Vector2(6.0, 0.0), 3.5, Color(1.0, 0.92, 0.55))
		"bubble_trap_orb":
			draw_circle(Vector2.ZERO, 14.0, Color(0.32, 0.88, 1.0, 0.32))
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(0.65, 0.96, 1.0, 0.95), 2.8)
			draw_arc(Vector2.ZERO, 10.5, -2.3, -1.0, 10, Color(1.0, 1.0, 1.0, 0.85), 2.0)
			draw_arc(Vector2.ZERO, 11.0, 0.4, 1.4, 10, Color(1.0, 0.58, 0.92, 0.7), 1.8)
		"heavy_forge":
			draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
			# Animated purple & cyan falling shockwave streaks above the upright forge (60% scale)
			var f_pulse: float = 0.65 + 0.35 * sin(_age * 24.0)
			for si in range(5):
				var sx: float = (float(si) - 2.0) * 6.5
				var sy_len: float = 14.0 + float((si * 7) % 8) + sin(_age * 28.0 + float(si)) * 3.5
				var s_col := Color(0.76, 0.32, 1.0, 0.50 * f_pulse) if si % 2 == 0 else Color(0.24, 0.92, 1.0, 0.50 * f_pulse)
				draw_line(Vector2(sx, -8.0), Vector2(sx, -8.0 - sy_len), s_col, 2.0)
			draw_texture_rect(TEX_HEAVY_FORGE, Rect2(-20.0, -13.0, 40.0, 26.0), false)
		"prop_chair":
			draw_line(Vector2(-16, -28), Vector2(-16, 20), Color(0.55, 0.60, 0.68), 6.0)
			draw_line(Vector2(-16, -2), Vector2(18, -2), Color(0.55, 0.60, 0.68), 6.0)
			draw_line(Vector2(15, -2), Vector2(15, 20), Color(0.55, 0.60, 0.68), 6.0)
			draw_rect(Rect2(-18, -28, 8, 24), Color(0.28, 0.45, 0.72))
			draw_rect(Rect2(-16, -6, 35, 8), Color(0.28, 0.45, 0.72))
		"prop_wood":
			draw_rect(Rect2(-14, -6, 28, 12), Color(0.46, 0.28, 0.14))
			draw_rect(Rect2(-14, -6, 28, 12), Color(0.24, 0.14, 0.07), false, 2.0)
			draw_line(Vector2(-8, -2), Vector2(8, -2), Color(0.62, 0.40, 0.22), 2.0)
			draw_circle(Vector2(12, 0), 4.5, Color(0.76, 0.58, 0.34))
		"prop_coconut":
			draw_circle(Vector2.ZERO, 10.0, Color(0.40, 0.24, 0.12))
			draw_circle(Vector2(-3, -3), 3.0, Color(0.54, 0.34, 0.18))
			draw_circle(Vector2(3, -2), 1.6, Color(0.18, 0.10, 0.05))
		"prop_barrel":
			draw_rect(Rect2(-22, -33, 44, 66), Color(0.82, 0.20, 0.16))
			draw_rect(Rect2(-22, -33, 44, 66), Color(0.20, 0.22, 0.26), false, 3.0)
			draw_line(Vector2(-22, -11), Vector2(22, -11), Color(0.95, 0.76, 0.20), 6.0)
			draw_line(Vector2(-22, 11), Vector2(22, 11), Color(0.30, 0.34, 0.40), 4.5)
		"prop_pot":
			draw_circle(Vector2(0, 2), 9.5, Color(0.74, 0.42, 0.24))
			draw_rect(Rect2(-6, -11, 12, 6), Color(0.64, 0.35, 0.19))
			draw_rect(Rect2(-7, -12, 14, 3), Color(0.86, 0.54, 0.32))
		"prop_stone":
			draw_rect(Rect2(-11, -9, 22, 18), Color(0.54, 0.52, 0.48))
			draw_rect(Rect2(-11, -9, 22, 18), Color(0.30, 0.28, 0.25), false, 2.0)
			draw_line(Vector2(-5, -3), Vector2(5, 3), Color(0.34, 0.32, 0.29), 2.0)
		"prop_ice_block":
			draw_rect(Rect2(-11, -11, 22, 22), Color(0.62, 0.88, 1.0, 0.88))
			draw_rect(Rect2(-11, -11, 22, 22), Color(0.92, 0.98, 1.0), false, 2.0)
			draw_line(Vector2(-6, -6), Vector2(4, 4), Color.WHITE, 2.0)
		"prop_crate":
			draw_rect(Rect2(-11, -11, 22, 22), Color(0.26, 0.34, 0.46))
			draw_rect(Rect2(-11, -11, 22, 22), Color(0.38, 0.86, 0.98), false, 2.0)
			draw_line(Vector2(-11, -11), Vector2(11, 11), Color(0.38, 0.86, 0.98, 0.6), 2.0)
		"raven":
			var flap_s: float = sin(_age * 20.0)
			var flip_y: float = -1.0 if velocity.x < 0.0 else 1.0
			draw_set_transform(Vector2.ZERO, velocity.angle() - rotation - _visual_spin, Vector2(1.0 + flap_s * 0.06, (1.0 - flap_s * 0.14) * flip_y))
			# Glowing neon purple shadow trail behind each raven
			draw_line(Vector2(-32.0, 0.0), Vector2(-6.0, 0.0), Color(0.66, 0.18, 1.0, 0.34), 10.0)
			draw_line(Vector2(-24.0, -4.0), Vector2(-4.0, -2.0), Color(0.82, 0.36, 1.0, 0.55), 3.2)
			draw_line(Vector2(-22.0, 4.0), Vector2(-4.0, 2.0), Color(0.82, 0.36, 1.0, 0.55), 3.2)
			draw_circle(Vector2.ZERO, 20.0, Color(0.68, 0.20, 1.0, 0.16))
			draw_texture_rect(TEX_RAVEN, Rect2(-25.0, -25.0, 50.0, 50.0), false)
		"smoke_orb":
			draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
			var pulse: float = 1.0 + sin(_age * 6.5) * 0.06
			var smoke_outer := Color(0.08, 0.09, 0.13, 0.36)
			var smoke_mid := Color(0.14, 0.16, 0.22, 0.46)
			var smoke_hi := Color(0.28, 0.32, 0.40, 0.34)
			var smoke_core := Color(0.20, 0.23, 0.30, 0.42)
			# Soft outer billowing smoke cloud puffs (semi-transparent)
			var outer_puffs: Array[Vector4] = [
				Vector4(0.0, 2.0, 36.0, 0.0),
				Vector4(-22.0, 4.0, 25.0, 1.1),
				Vector4(22.0, 5.0, 24.0, 2.3),
				Vector4(-14.0, -14.0, 23.0, 3.5),
				Vector4(14.0, -13.0, 22.0, 4.7),
				Vector4(0.0, -20.0, 20.0, 5.4),
			]
			for po in outer_puffs:
				var drift := Vector2(sin(_age * 3.8 + po.w) * 3.5, cos(_age * 3.2 + po.w) * 2.5)
				var rad: float = po.z * pulse
				draw_circle(Vector2(po.x, po.y) + drift, rad + 5.0, smoke_outer)
				draw_circle(Vector2(po.x, po.y) + drift, rad, smoke_mid)
			# Inner swirling smoke highlights (gives soft layered cloud volume)
			var hi_puffs: Array[Vector3] = [
				Vector3(-12.0, -10.0, 15.0),
				Vector3(10.0, -12.0, 13.5),
				Vector3(-18.0, 6.0, 12.0),
				Vector3(16.0, 4.0, 12.5),
				Vector3(0.0, -2.0, 18.0),
			]
			for hp in hi_puffs:
				var h_drift := Vector2(cos(_age * 4.5 + hp.x) * 2.5, sin(_age * 4.0 + hp.y) * 2.0)
				draw_circle(Vector2(hp.x, hp.y) + h_drift, hp.z * pulse, smoke_core)
				draw_circle(Vector2(hp.x - 3.0, hp.y - 3.0) + h_drift, hp.z * 0.68 * pulse, smoke_hi)
			# Rising & curling transparent vapor puffs
			for vi in range(10):
				var v_phase: float = fmod(_age * 1.15 + float(vi) / 10.0, 1.0)
				var swirl_a: float = float(vi) * 1.3 + _age * 2.4
				var vx: float = sin(swirl_a) * (10.0 + v_phase * 14.0) + (float(vi % 5) - 2.0) * 7.0
				var vy: float = -10.0 - v_phase * 42.0
				var vr: float = lerpf(8.0, 18.0, v_phase)
				var va: float = sin(v_phase * PI) * 0.42
				draw_circle(Vector2(vx, vy), vr, Color(0.11, 0.13, 0.18, va))
				draw_circle(Vector2(vx - 2.5, vy - 2.5), vr * 0.62, Color(0.26, 0.30, 0.38, va * 0.72))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_tapered_slash_arc(center: Vector2, rad: float, start_a: float, end_a: float, steps: int, col: Color, max_w: float) -> void:
	for i in range(steps):
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var mid_t: float = (t0 + t1) * 0.5
		var taper: float = sin(mid_t * PI)
		var w: float = maxf(0.8, max_w * taper * taper)
		var a0: float = lerpf(start_a, end_a, t0)
		var a1: float = lerpf(start_a, end_a, t1)
		draw_line(center + Vector2.from_angle(a0) * rad, center + Vector2.from_angle(a1) * rad, Color(col.r, col.g, col.b, col.a * (0.35 + 0.65 * taper)), w)
