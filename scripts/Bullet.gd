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
var _distance_traveled: float = 0.0

var _age: float = 0.0
var _trail_points: PackedVector2Array = PackedVector2Array()
var _finished: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _trail: Line2D = $Trail


func _ready() -> void:
	rotation = velocity.angle()
	_sprite.texture = TEX_LASER if is_laser else TEX_BULLET
	_sprite.modulate = bullet_color
	if is_explosive:
		_sprite.scale = Vector2(1.6, 1.8)
	elif is_laser:
		_sprite.scale = Vector2(1.4, 1.1)

	_trail.default_color = Color(bullet_color.r, bullet_color.g, bullet_color.b, 0.75)
	_trail.width = 5.0 if is_laser else (6.0 if is_explosive else 3.0)
	_trail_points.append(global_position)
	_trail_points.append(global_position)
	_update_trail_visual()


func _physics_process(delta: float) -> void:
	if _finished:
		return

	_age += delta
	if _age >= max_lifetime:
		if is_explosive:
			_trigger_explosion(global_position)
		queue_free()
		return

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


func _update_trail_visual() -> void:
	var local_pts := PackedVector2Array()
	for pt in _trail_points:
		local_pts.append(to_local(pt))
	_trail.points = local_pts


func _handle_collision(collider: Object, hit_pos: Vector2) -> void:
	_finished = true
	if is_explosive:
		_trigger_explosion(hit_pos)
		queue_free()
		return

	if collider != null and collider.is_in_group("players"):
		if NetworkManager.match_mode == 1 and int(collider.get("team_id")) == shooter_team and int(collider.get("peer_id")) != shooter_peer_id:
			_finished = false
			global_position = hit_pos + velocity.normalized() * 6.0
			return
		if can_deal_damage and collider.has_method("apply_hit"):
			var final_damage: int = _compute_falloff_damage()
			var knockback: Vector2 = velocity.normalized() * 140.0
			collider.apply_hit(final_damage, shooter_peer_id, weapon_name, shooter_name, knockback)
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
