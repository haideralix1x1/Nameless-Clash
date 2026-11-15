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
		queue_free()
		return

	if gravity_mult > 0.0:
		velocity.y += 980.0 * gravity_mult * maxf(0.15, NetworkManager.gravity_scale) * delta

	var prev_pos: Vector2 = global_position
	var next_pos: Vector2 = prev_pos + velocity * delta

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(prev_pos, next_pos, 3)
	if shooter_rid.is_valid():
		query.exclude = [shooter_rid]
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
		_spawn_impact_flash(hit_pos, bullet_color)
	else:
		_spawn_impact_flash(hit_pos, Color(1.0, 0.85, 0.45))

	queue_free()


func _compute_falloff_damage() -> int:
	if min_damage_ratio >= 0.999 or _distance_traveled <= damage_falloff_start:
		return damage
	var falloff_span: float = maxf(240.0, damage_falloff_start)
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
			draw_line(Vector2(-12.0, 0.0), Vector2(10.0, 0.0), Color(0.55, 0.35, 0.18), 2.5)
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
		"frag_bomb":
			draw_circle(Vector2.ZERO, 9.5, Color(0.16, 0.22, 0.18))
			draw_arc(Vector2.ZERO, 9.5, 0.0, TAU, 16, bullet_color, 2.5)
			draw_rect(Rect2(-3.0, -12.0, 6.0, 4.0), Color(0.75, 0.78, 0.84))
			draw_circle(Vector2(2.0, -12.0), 3.0, Color(1.0, 0.65, 0.18))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
