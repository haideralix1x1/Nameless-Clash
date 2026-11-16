extends Area2D

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/Explosion.tscn")
const TEX_BULLET: Texture2D = preload("res://assets/sprites/bullet.png")
const TEX_LASER: Texture2D = preload("res://assets/sprites/laser_trail.png")

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
var stun_duration: float = 0.0
var visual_style: String = "bullet"
var spin_speed: float = 0.0
var knockback_mult: float = 1.0
var pierce_walls: bool = false
var gravity_mult: float = 0.0
var is_homing: bool = false
var homing_turn_rate: float = 4.8
var allow_self_damage: bool = true
var reverse_controls_dur: float = 0.0
var _homing_target_pos: Vector2 = Vector2.INF
var _visual_spin: float = 0.0
var _distance_traveled: float = 0.0

var _age: float = 0.0
var _trail_points: PackedVector2Array = PackedVector2Array()
var _finished: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _trail: Line2D = $Trail


func _ready() -> void:
	rotation = velocity.angle()
	if visual_style != "bullet":
		_sprite.visible = false
	else:
		_sprite.texture = TEX_LASER if is_laser else TEX_BULLET
		_sprite.modulate = bullet_color
		if is_explosive:
			_sprite.scale = Vector2(1.6, 1.8)
		elif is_laser:
			_sprite.scale = Vector2(1.4, 1.1)

	_trail.default_color = Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.75)
	_trail.width = 6.0 if visual_style == "slash_wave" or is_explosive else (5.0 if is_laser else 3.0)
	_trail_points.append(global_position)
	_trail_points.append(global_position)
	_update_trail_visual()
	if visual_style != "bullet":
		queue_redraw()


func _physics_process(delta: float) -> void:
	if _finished:
		return

	_age += delta
	if _age >= max_lifetime:
		if is_explosive:
			_trigger_explosion(global_position)
		else:
			_spawn_impact_flash(global_position, bullet_color)
		queue_free()
		return

	if gravity_mult > 0.0:
		velocity.y += 980.0 * gravity_mult * maxf(0.15, NetworkManager.gravity_scale) * delta

	if is_homing:
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
	if not excl.is_empty():
		query.exclude = excl
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector2 = hit["position"]
		var collider: Object = hit["collider"]
		_distance_traveled += prev_pos.distance_to(hit_pos)
		global_position = hit_pos
		_trail_points.append(hit_pos)
		_update_trail_visual()
		_handle_collision(collider, hit_pos)
		return

	_distance_traveled += prev_pos.distance_to(next_pos)
	global_position = next_pos
	_trail_points.append(next_pos)
	if _trail_points.size() > 8:
		_trail_points.remove_at(0)
	_update_trail_visual()
	if visual_style != "bullet":
		_visual_spin += spin_speed * delta
		queue_redraw()


func _update_trail_visual() -> void:
	var local_pts := PackedVector2Array()
	for pt in _trail_points:
		local_pts.append(to_local(pt))
	_trail.points = local_pts


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
			best_pos = p.global_position
	return best_pos


func _handle_collision(collider: Object, hit_pos: Vector2) -> void:
	_finished = true
	if collider != null and collider.is_in_group("barrier_walls"):
		if can_deal_damage and collider.has_method("apply_wall_damage"):
			collider.apply_wall_damage(damage)
		if pierce_walls:
			_finished = false
			global_position = hit_pos + velocity.normalized() * 14.0
			return
		if is_explosive:
			_trigger_explosion(hit_pos)
		else:
			_spawn_impact_flash(hit_pos, bullet_color)
		queue_free()
		return

	if collider != null and collider.is_in_group("destructible_bombs"):
		if can_deal_damage and collider.has_method("on_shot_hit"):
			collider.on_shot_hit(damage, shooter_peer_id)
		if is_explosive:
			_trigger_explosion(hit_pos)
		else:
			_spawn_impact_flash(hit_pos, bullet_color)
		queue_free()
		return

	if is_explosive:
		_trigger_explosion(hit_pos)
		queue_free()
		return

	if collider != null and collider.is_in_group("players"):
		if int(collider.get("peer_id")) == shooter_peer_id:
			_finished = false
			global_position = hit_pos + velocity.normalized() * 10.0
			return
		if NetworkManager.is_team_mode() and int(collider.get("team_id")) == shooter_team:
			_finished = false
			global_position = hit_pos + velocity.normalized() * 6.0
			return
		if can_deal_damage and collider.has_method("apply_hit"):
			var final_damage: int = _compute_falloff_damage()
			var knockback: Vector2 = velocity.normalized() * (140.0 * knockback_mult)
			collider.apply_hit(final_damage, shooter_peer_id, weapon_name, shooter_name, knockback)
			if stun_duration > 0.0 and collider.has_method("apply_stun"):
				collider.apply_stun(stun_duration, shooter_peer_id)
			if reverse_controls_dur > 0.0 and collider.has_method("apply_reverse_controls"):
				collider.apply_reverse_controls(reverse_controls_dur)
		_spawn_impact_flash(hit_pos, bullet_color)
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
		_spawn_impact_flash(hit_pos, Color(1.0, 0.85, 0.45))
		if visual_style == "smoke_orb" and reverse_controls_dur > 0.0 and can_deal_damage:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and int(p.get("peer_id")) != shooter_peer_id:
					if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
						continue
					if (p as Node2D).global_position.distance_to(hit_pos) <= 115.0 and p.has_method("apply_reverse_controls"):
						p.apply_reverse_controls(reverse_controls_dur)

	queue_free()


func _compute_falloff_damage() -> int:
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
	exp.can_deal_damage = can_deal_damage
	exp.allow_self_damage = allow_self_damage
	parent_node.add_child(exp)


func _spawn_impact_flash(pos: Vector2, col: Color) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var exp := EXPLOSION_SCENE.instantiate()
	exp.global_position = pos
	exp.explosion_radius = 28.0
	exp.max_damage = 0
	exp.can_deal_damage = false
	exp.modulate = col
	parent_node.add_child(exp)


func _draw() -> void:
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
			draw_circle(Vector2.ZERO, 12.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.35))
			draw_circle(Vector2.ZERO, 8.5, bullet_color)
			draw_circle(Vector2(2.0, 0.0), 4.5, Color(1.0, 0.96, 0.72))
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
		"ghost_wisp":
			draw_circle(Vector2.ZERO, 12.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.28))
			draw_circle(Vector2.ZERO, 7.5, bullet_color)
			draw_circle(Vector2(1.5, -1.5), 3.0, Color.WHITE)
		"arrow":
			draw_line(Vector2(-12.0, 0.0), Vector2(10.0, 0.0), Color(0.06, 0.06, 0.09), 5.0)
			draw_line(Vector2(-12.0, 0.0), Vector2(10.0, 0.0), Color(0.68, 0.45, 0.22), 2.8)
			draw_colored_polygon(PackedVector2Array([Vector2(15.5, 0.0), Vector2(5.0, -6.0), Vector2(5.0, 6.0)]), Color(0.06, 0.06, 0.09))
			draw_colored_polygon(PackedVector2Array([Vector2(14.0, 0.0), Vector2(6.0, -4.5), Vector2(6.0, 4.5)]), bullet_color)
		"slash_wave":
			var pts := PackedVector2Array([
				Vector2(-6.0, -24.0), Vector2(10.0, -14.0), Vector2(16.0, 0.0),
				Vector2(10.0, 14.0), Vector2(-6.0, 24.0), Vector2(2.0, 0.0)
			])
			draw_colored_polygon(pts, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.88))
			draw_arc(Vector2(-2.0, 0.0), 22.0, -1.1, 1.1, 14, Color.WHITE, 3.0)
		"stun_bolt":
			draw_circle(Vector2.ZERO, 9.0, Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.45))
			draw_polyline(PackedVector2Array([
				Vector2(-11.0, -4.0), Vector2(-3.0, 3.0), Vector2(3.0, -3.0), Vector2(11.0, 4.0)
			]), Color.WHITE, 3.0)
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
		"thrown_stone":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12.0, -4.0), Vector2(-5.0, -12.0), Vector2(7.0, -10.0),
				Vector2(13.0, 1.0), Vector2(6.0, 11.0), Vector2(-8.0, 10.0)
			]), bullet_color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-6.0, -6.0), Vector2(4.0, -7.0), Vector2(6.0, 1.0), Vector2(-3.0, 2.0)
			]), bullet_color.lightened(0.28))
		"frag_bomb":
			draw_circle(Vector2.ZERO, 9.5, Color(0.16, 0.22, 0.18))
			draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 16, bullet_color, 2.5)
			draw_rect(Rect2(-3.0, -12.0, 6.0, 4.0), Color(0.75, 0.78, 0.84))
			draw_circle(Vector2(2.0, -12.0), 3.0, Color(1.0, 0.65, 0.18))
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
			draw_set_transform(Vector2.ZERO, velocity.angle() - rotation - _visual_spin, Vector2.ONE)
			var flap: float = sin(_age * 22.0) * 11.0
			# Tail feathers
			draw_colored_polygon(PackedVector2Array([
				Vector2(-10, 0), Vector2(-21, -7), Vector2(-18, 0), Vector2(-21, 7)
			]), Color(0.08, 0.07, 0.14))
			# Flapping wings
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4, -2), Vector2(-12, -20 + flap), Vector2(4, -14 + flap * 0.6), Vector2(7, -2)
			]), Color(0.12, 0.10, 0.20))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-4, 2), Vector2(-12, 20 - flap), Vector2(4, 14 - flap * 0.6), Vector2(7, 2)
			]), Color(0.12, 0.10, 0.20))
			# Sleek bird body & head
			draw_colored_polygon(PackedVector2Array([
				Vector2(-12, 0), Vector2(-2, -5.5), Vector2(10, -4.5), Vector2(15, 0), Vector2(10, 4.5), Vector2(-2, 5.5)
			]), Color(0.06, 0.05, 0.10))
			# Sharp raven beak
			draw_colored_polygon(PackedVector2Array([
				Vector2(14, -2.5), Vector2(23, 0.5), Vector2(14, 2.8)
			]), Color(0.24, 0.26, 0.34))
			# Glowing violet eye
			draw_circle(Vector2(11, -1.5), 2.2, Color(0.82, 0.35, 1.0))
			draw_circle(Vector2(11, -1.5), 1.0, Color.WHITE)
		"smoke_orb":
			var pulse: float = 1.0 + sin(_age * 10.0) * 0.08
			draw_circle(Vector2.ZERO, 46.0 * pulse, Color(0.12, 0.08, 0.20, 0.42))
			draw_circle(Vector2(-14, -10), 28.0 * pulse, Color(0.16, 0.10, 0.26, 0.72))
			draw_circle(Vector2(15, 10), 26.0 * pulse, Color(0.08, 0.06, 0.14, 0.78))
			draw_circle(Vector2(12, -14), 22.0 * pulse, Color(0.22, 0.12, 0.36, 0.68))
			draw_circle(Vector2(-12, 14), 24.0 * pulse, Color(0.10, 0.07, 0.18, 0.72))
			draw_arc(Vector2.ZERO, 38.0 * pulse, 0.0, TAU, 28, Color(0.68, 0.32, 0.98, 0.65), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
