extends Area2D

var summon_kind: String = "bat"
var owner_peer_id: int = 0
var owner_team: int = -1
var owner_name: String = "Agent"
var weapon_name: String = "Summon"
var can_deal: bool = false
var time_left: float = 5.0
var damage: int = 25
var move_dir_x: float = 1.0
var vel: Vector2 = Vector2.ZERO
var hp: int = 40
var linked_target: Node2D = null
var _attack_cd: float = 0.0
var _phase: float = 0.0
var _wall_gap: float = 110.0

var _col_shape: CollisionShape2D = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_col_shape = CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 22.0 if summon_kind in ["winged_lion", "giant_snake", "ghost_clone", "mirror_clone", "turret"] else 15.0
	_col_shape.shape = sh
	add_child(_col_shape)
	if summon_kind in ["ghost_clone", "mirror_clone", "turret"]:
		collision_layer = 2
		add_to_group("destructible_bombs")
		set_meta("prop_node", self)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func on_shot_hit(dmg: int, attacker_id: int) -> void:
	if attacker_id == owner_peer_id:
		return
	if summon_kind == "ghost_clone":
		queue_free()
		return
	if summon_kind == "mirror_clone":
		if can_deal and is_instance_valid(linked_target) and linked_target.has_method("apply_hit"):
			linked_target.apply_hit(dmg, owner_peer_id, weapon_name, owner_name, Vector2.ZERO)
		return
	if summon_kind == "turret":
		hp -= dmg
		if hp <= 0:
			queue_free()


func _physics_process(delta: float) -> void:
	time_left -= delta
	_phase += delta * 6.0
	if _attack_cd > 0.0:
		_attack_cd = maxf(0.0, _attack_cd - delta)
	if time_left <= 0.0:
		if summon_kind == "bomb_eagle":
			_drop_eagle_bomb()
		queue_free()
		return

	match summon_kind:
		"flash_bird", "winged_lion", "bat", "shadow_mummy", "giant_snake", "mini_prism":
			var spd: float = 340.0 if summon_kind == "winged_lion" else (320.0 if summon_kind == "giant_snake" else (300.0 if summon_kind == "flash_bird" else 260.0))
			var target: Node2D = _find_nearest_enemy(950.0)
			if target != null:
				var dir: Vector2 = (target.global_position - global_position).normalized()
				global_position += dir * spd * delta
				if summon_kind == "shadow_mummy" and global_position.distance_to(target.global_position) <= 34.0 and _attack_cd <= 0.0:
					_attack_cd = 0.75
					if can_deal and target.has_method("apply_hit"):
						target.apply_hit(damage, owner_peer_id, weapon_name, owner_name, dir * 180.0)
			else:
				global_position.x += move_dir_x * spd * 0.65 * delta
		"bee":
			var b_target: Node2D = _find_nearest_enemy(420.0)
			if b_target != null:
				var b_dir: Vector2 = (b_target.global_position - global_position).normalized()
				global_position += b_dir * 250.0 * delta
			else:
				global_position += Vector2(cos(_phase * 0.7) * 140.0, sin(_phase * 1.1) * 90.0) * delta
		"barbarian", "zombie_dog", "small_snake":
			var g_spd: float = 240.0 if summon_kind == "zombie_dog" else 195.0
			vel.x = move_dir_x * g_spd
			vel.y = minf(vel.y + 920.0 * delta, 650.0)
			var space := get_world_2d().direct_space_state
			var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, 20.0), 1)
			var hit := space.intersect_ray(ray)
			if not hit.is_empty() and vel.y > 0.0:
				global_position.y = (hit["position"] as Vector2).y - 16.0
				vel.y = 0.0
			global_position += vel * delta
		"bomb_eagle":
			var e_target: Node2D = _find_nearest_enemy(900.0)
			if e_target != null:
				var above := e_target.global_position + Vector2(0.0, -78.0)
				var to_above := above - global_position
				global_position += to_above.normalized() * 290.0 * delta
				if absf(global_position.x - e_target.global_position.x) < 24.0:
					_drop_eagle_bomb()
					queue_free()
					return
			else:
				global_position.x += move_dir_x * 230.0 * delta
		"turret":
			if _attack_cd <= 0.0:
				var t_target: Node2D = _find_nearest_enemy(520.0)
				if t_target != null:
					_attack_cd = 1.0
					if can_deal:
						var b := preload("res://scenes/Bullet.tscn").instantiate()
						b.global_position = global_position + Vector2(0.0, -14.0)
						b.velocity = (t_target.global_position - b.global_position).normalized() * 980.0
						b.damage = damage
						b.shooter_peer_id = owner_peer_id
						b.shooter_team = owner_team
						b.shooter_name = owner_name
						b.weapon_name = weapon_name
						b.bullet_color = Color(0.35, 0.92, 1.0)
						b.can_deal_damage = true
						b.max_lifetime = 1.2
						get_parent().add_child(b)
		"ghost_clone":
			global_position.x += move_dir_x * 130.0 * delta
			global_position.y += sin(_phase) * 35.0 * delta
		"mirror_clone":
			if is_instance_valid(linked_target):
				global_position = global_position.lerp(linked_target.global_position + Vector2(48.0 * move_dir_x, 0.0), clampf(delta * 4.0, 0.0, 1.0))
		"crush_walls":
			_wall_gap = maxf(0.0, _wall_gap - 360.0 * delta)
			if _wall_gap <= 6.0:
				if can_deal:
					for p in get_tree().get_nodes_in_group("players"):
						if is_instance_valid(p) and int(p.get("peer_id")) != owner_peer_id:
							if NetworkManager.is_team_mode() and int(p.get("team_id")) == owner_team:
								continue
							if absf((p as Node2D).global_position.x - global_position.x) <= 70.0 and absf((p as Node2D).global_position.y - global_position.y) <= 90.0:
								p.apply_hit(damage, owner_peer_id, weapon_name, owner_name, Vector2.ZERO)
				queue_free()
				return
	queue_redraw()


func _drop_eagle_bomb() -> void:
	if not can_deal:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and int(p.get("peer_id")) != owner_peer_id:
			if NetworkManager.is_team_mode() and int(p.get("team_id")) == owner_team:
				continue
			if (p as Node2D).global_position.distance_to(global_position) <= 135.0 and p.has_method("apply_hit"):
				p.apply_hit(damage, owner_peer_id, weapon_name, owner_name, Vector2(0.0, -180.0))


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("players"):
		return
	if int(body.get("peer_id")) == owner_peer_id:
		return
	if NetworkManager.is_team_mode() and int(body.get("team_id")) == owner_team:
		return
	if summon_kind in ["shadow_mummy", "turret", "ghost_clone", "mirror_clone", "crush_walls", "bomb_eagle"]:
		return
	if can_deal and body.has_method("apply_hit"):
		body.apply_hit(damage, owner_peer_id, weapon_name, owner_name, Vector2(move_dir_x * 220.0, -120.0))
		if summon_kind == "flash_bird" and body.has_method("apply_status"):
			body.apply_status("flashbang", 3.0)
	queue_free()


func _find_nearest_enemy(max_range: float) -> Node2D:
	var best: Node2D = null
	var best_sq: float = max_range * max_range
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		if int(p.get("peer_id")) == owner_peer_id:
			continue
		if NetworkManager.is_team_mode() and int(p.get("team_id")) == owner_team:
			continue
		var d_sq: float = global_position.distance_squared_to((p as Node2D).global_position)
		if d_sq < best_sq:
			best_sq = d_sq
			best = p as Node2D
	return best


func _draw() -> void:
	match summon_kind:
		"flash_bird":
			draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.96, 0.55))
			draw_line(Vector2(-16, -6), Vector2(0, 2), Color.WHITE, 3.0)
			draw_line(Vector2(16, -6), Vector2(0, 2), Color.WHITE, 3.0)
		"winged_lion":
			draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.78, 0.18))
			draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 24, Color.WHITE, 3.0)
			draw_line(Vector2(-26, -12), Vector2(-6, 0), Color(1.0, 0.95, 0.65), 4.0)
			draw_line(Vector2(26, -12), Vector2(6, 0), Color(1.0, 0.95, 0.65), 4.0)
		"bat":
			draw_circle(Vector2.ZERO, 9.0, Color(0.55, 0.10, 0.25))
			draw_line(Vector2(-14, -4), Vector2(14, -4), Color(0.88, 0.18, 0.35), 3.0)
		"barbarian":
			draw_rect(Rect2(-12, -16, 24, 32), Color(0.92, 0.45, 0.18))
			draw_circle(Vector2(0, -18), 10.0, Color(0.95, 0.78, 0.62))
		"zombie_dog":
			draw_rect(Rect2(-16, -10, 32, 20), Color(0.42, 0.86, 0.30))
			draw_circle(Vector2(14 * move_dir_x, -6), 8.0, Color(0.55, 0.95, 0.35))
		"bomb_eagle":
			draw_circle(Vector2.ZERO, 13.0, Color(0.65, 0.48, 0.28))
			draw_circle(Vector2(0, 12), 7.0, Color(0.18, 0.18, 0.22))
		"shadow_mummy":
			draw_rect(Rect2(-13, -20, 26, 40), Color(0.85, 0.72, 0.42, 0.85))
			draw_circle(Vector2(0, -14), 5.0, Color(1.0, 0.82, 0.22))
		"turret":
			draw_rect(Rect2(-14, -14, 28, 28), Color(0.28, 0.65, 0.88))
			draw_rect(Rect2(-14, -14, 28, 28), Color.WHITE, false, 2.0)
			draw_circle(Vector2(0, -14), 8.0, Color(0.45, 0.95, 1.0))
		"small_snake", "giant_snake":
			var r: float = 20.0 if summon_kind == "giant_snake" else 10.0
			draw_circle(Vector2.ZERO, r, Color(0.28, 0.95, 0.36))
			draw_circle(Vector2(-r * 0.9 * move_dir_x, 0), r * 0.7, Color(0.22, 0.82, 0.30))
		"mini_prism":
			draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.48, 0.86))
			draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 6, Color.WHITE, 2.0)
		"bee":
			draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.85, 0.16))
			draw_line(Vector2(-4, -5), Vector2(4, -5), Color.BLACK, 2.0)
		"ghost_clone":
			draw_circle(Vector2(0, -8), 16.0, Color(0.75, 0.96, 1.0, 0.68))
			draw_rect(Rect2(-14, -6, 28, 28), Color(0.75, 0.96, 1.0, 0.55))
		"mirror_clone":
			draw_circle(Vector2(0, -8), 16.0, Color(0.82, 0.52, 1.0, 0.72))
			draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 20, Color(0.95, 0.75, 1.0, 0.9), 2.5)
		"crush_walls":
			draw_rect(Rect2(-_wall_gap - 24.0, -76.0, 26.0, 152.0), Color(0.98, 0.44, 0.84, 0.85))
			draw_rect(Rect2(_wall_gap - 2.0, -76.0, 26.0, 152.0), Color(0.98, 0.44, 0.84, 0.85))
