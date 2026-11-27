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
var flight_dir: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var hp: int = 40
var linked_target: Node2D = null
var clone_arch_id: int = 3
var _modular_clone: ModularCharacter = null
var _attack_cd: float = 0.0
var _phase: float = 0.0
var _wall_gap: float = 110.0
var _attack_anim_timer: float = 0.0
var _attack_dir: Vector2 = Vector2.RIGHT
var _barb_attacking: bool = false
var _barb_attack_elapsed: float = 0.0
var _barb_target: Node = null
var _barb_hit_done: bool = false
const TEX_BARBARIAN_ATTACK: Texture2D = preload("res://assets/sprites/summons/barbarian_attack_sheet.png")

const SUMMON_TEXTURES: Dictionary = {
	"winged_lion": preload("res://assets/sprites/summons/winged_lion_sheet.png"),
	"flash_bird": preload("res://assets/sprites/summons/bird.png"),
	"bat": preload("res://assets/sprites/summons/bat.png"),
	"barbarian": preload("res://assets/sprites/summons/barbarian_sheet.png"),
	"zombie_dog": preload("res://assets/sprites/summons/zombie_dog.png"),
	"bomb_eagle": preload("res://assets/sprites/summons/eagle.png"),
	"shadow_mummy": preload("res://assets/sprites/summons/mummy.png"),
	"small_snake": preload("res://assets/sprites/summons/snake.png"),
	"giant_snake": preload("res://assets/sprites/summons/snake.png"),
	"bee": preload("res://assets/sprites/summons/bee.png"),
	"dragon_strike": preload("res://assets/sprites/summons/dragon.png")
}

const SUMMON_SCALES: Dictionary = {
	"winged_lion": 0.44,
	"flash_bird": 0.44,
	"bat": 0.44,
	"barbarian": 0.42,
	"zombie_dog": 0.52,
	"bomb_eagle": 0.58,
	"shadow_mummy": 0.54,
	"small_snake": 0.38,
	"giant_snake": 0.68,
	"bee": 0.36,
	"dragon_strike": 0.92
}

var _col_shape: CollisionShape2D = null
var _sprite: Sprite2D = null
var _base_scale: float = 0.5


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	add_to_group("agent_summons")
	_col_shape = CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 22.0 if summon_kind in ["winged_lion", "giant_snake", "ghost_clone", "mirror_clone", "turret"] else 15.0
	_col_shape.shape = sh
	add_child(_col_shape)
	if summon_kind in ["ghost_clone", "mirror_clone", "turret"]:
		collision_layer = 2
		add_to_group("destructible_bombs")
		set_meta("prop_node", self)
	if summon_kind == "ghost_clone" or summon_kind == "mirror_clone":
		add_to_group("decoy_targets")
	if summon_kind == "ghost_clone" or summon_kind == "mirror_clone":
		var c_arch: int = int(linked_target.get("archetype_id")) if (summon_kind == "mirror_clone" and is_instance_valid(linked_target)) else clone_arch_id
		var part: int = ProfileManager.get_archetype_part_id(c_arch)
		var arch_d: Dictionary = ProfileManager.ARCHETYPES[clampi(c_arch, 0, ProfileManager.ARCHETYPES.size() - 1)]
		_modular_clone = ModularCharacter.new()
		_modular_clone.scale = Vector2(0.75, 0.75)
		add_child(_modular_clone)
		_modular_clone.apply_loadout({
			"archetype": c_arch,
			"skin_id": part, "head_id": part, "torso_id": part,
			"legs_id": part, "hands_id": part, "accessories_id": part,
			"shirt_color": arch_d.get("shirt", Color.WHITE),
			"pants_color": arch_d.get("pants", Color.WHITE),
			"skin_color": arch_d.get("skin", Color.WHITE),
			"helmet_color": arch_d.get("helmet", Color.WHITE),
			"gear_color": arch_d.get("gear", Color.WHITE)
		})
		_modular_clone.play_state("run", move_dir_x < 0.0)
	body_entered.connect(_on_body_entered)
	if SUMMON_TEXTURES.has(summon_kind):
		_base_scale = float(SUMMON_SCALES.get(summon_kind, 0.5))
		_sprite = Sprite2D.new()
		_sprite.texture = SUMMON_TEXTURES[summon_kind]
		if summon_kind == "barbarian":
			_sprite.hframes = 10
		elif summon_kind == "winged_lion":
			_sprite.hframes = 16
		_sprite.scale = Vector2(_base_scale, _base_scale)
		_sprite.flip_h = move_dir_x < 0.0
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_sprite)
	queue_redraw()


func is_alive() -> bool:
	return time_left > 0.0


func apply_fan_wind(dir_n: Vector2, push_force: float, delta: float) -> void:
	vel += dir_n * push_force * delta
	if dir_n.y < -0.5:
		vel.y = clampf(vel.y, -780.0, 420.0)
	else:
		vel.x = clampf(vel.x, -820.0, 820.0)
	var step: Vector2 = dir_n * 420.0 * delta
	var space := get_world_2d().direct_space_state
	if space != null:
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + step + dir_n * 18.0, 1))
		if hit.is_empty():
			global_position += step
	else:
		global_position += step


func on_shot_hit(dmg: int, attacker_id: int) -> void:
	if attacker_id == owner_peer_id:
		return
	if summon_kind == "ghost_clone":
		_blast_ghost_clone()
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
	if summon_kind == "barbarian" and _barb_attacking:
		_barb_attack_elapsed += delta
		var atk_frame: int = int(_barb_attack_elapsed * 13.5)
		if atk_frame >= 5 and not _barb_hit_done:
			_barb_hit_done = true
			if can_deal and is_instance_valid(_barb_target) and _barb_target.has_method("apply_hit"):
				_barb_target.apply_hit(damage, owner_peer_id, weapon_name, owner_name, Vector2(move_dir_x * 220.0, -120.0))
		if atk_frame >= 12:
			queue_free()
			return
		if is_instance_valid(_sprite):
			_sprite.frame = atk_frame
		return
	if _attack_anim_timer > 0.0:
		_attack_anim_timer = maxf(0.0, _attack_anim_timer - delta)
		global_position += _attack_dir * 260.0 * delta
		if is_instance_valid(_sprite):
			var p_t: float = _attack_anim_timer / 0.35
			_sprite.scale = Vector2(0.96, 0.88).lerp(Vector2(0.72, 0.72), 1.0 - p_t)
			_sprite.rotation = (0.28 if not _sprite.flip_h else -0.28) * p_t
		modulate.a = clampf(_attack_anim_timer / 0.25, 0.0, 1.0)
		queue_redraw()
		if _attack_anim_timer <= 0.0:
			queue_free()
		return

	time_left -= delta
	_phase += delta * 6.0
	if _attack_cd > 0.0:
		_attack_cd = maxf(0.0, _attack_cd - delta)
	if summon_kind in ["winged_lion", "dragon_strike"] and time_left < 0.5:
		modulate.a = clampf(time_left / 0.5, 0.0, 1.0)
	if time_left <= 0.0:
		if summon_kind == "bomb_eagle":
			_drop_eagle_bomb()
		queue_free()
		return

	match summon_kind:
		"dragon_strike":
			var detect_r: float = 185.0
			var d_space := get_world_2d().direct_space_state
			if not is_instance_valid(linked_target) or (linked_target.has_method("is_alive") and not linked_target.is_alive()):
				linked_target = null
				var cand: Node2D = _find_nearest_enemy(detect_r)
				if cand != null:
					var los_hit := d_space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, cand.global_position, 1))
					if los_hit.is_empty():
						linked_target = cand
			var d_dir: Vector2 = flight_dir.normalized() if flight_dir.length() > 0.01 else Vector2(move_dir_x, 0.0)
			var spd_d: float = 540.0
			if is_instance_valid(linked_target):
				d_dir = (linked_target.global_position - global_position).normalized()
				flight_dir = d_dir
				spd_d = 660.0
			global_position += d_dir * spd_d * delta
			if is_instance_valid(_sprite):
				_sprite.flip_h = d_dir.x < 0.0
				_sprite.position.y = sin(_phase * 2.2) * 8.0
				var d_flap: float = sin(_phase * 3.0)
				_sprite.scale = Vector2(_base_scale + d_flap * 0.06, _base_scale - d_flap * 0.07)
			queue_redraw()
			var blast_target: Node2D = linked_target if (is_instance_valid(linked_target) and global_position.distance_to(linked_target.global_position) <= 58.0) else _find_nearest_enemy(58.0)
			if blast_target != null:
				var blast_pos: Vector2 = blast_target.global_position
				if can_deal:
					for p in get_tree().get_nodes_in_group("players"):
						if is_instance_valid(p) and int(p.get("peer_id")) != owner_peer_id:
							if p.has_method("is_alive") and not p.is_alive():
								continue
							if NetworkManager.is_team_mode() and int(p.get("team_id")) == owner_team:
								continue
							if (p as Node2D).global_position.distance_to(blast_pos) <= 155.0 and p.has_method("apply_hit"):
								var kb: Vector2 = ((p as Node2D).global_position - blast_pos).normalized() * 320.0
								p.apply_hit(damage, owner_peer_id, weapon_name, owner_name, kb)
				var exp_scene: PackedScene = load("res://scenes/Explosion.tscn") as PackedScene
				if exp_scene != null and get_parent() != null:
					var exp := exp_scene.instantiate()
					exp.global_position = blast_pos
					exp.explosion_radius = 155.0
					exp.max_damage = 0
					exp.can_deal_damage = false
					exp.play_blast_sfx = true
					get_parent().add_child(exp)
				queue_free()
				return
		"flash_bird", "winged_lion", "bat", "shadow_mummy", "giant_snake", "mini_prism":
			var spd: float = 340.0 if summon_kind == "winged_lion" else (320.0 if summon_kind == "giant_snake" else (300.0 if summon_kind == "flash_bird" else 260.0))
			var detect_r: float = 280.0 if summon_kind == "winged_lion" else (4000.0 if summon_kind == "bat" else 950.0)
			var target: Node2D = null
			if summon_kind == "bat" and is_instance_valid(linked_target) and (not linked_target.has_method("is_alive") or linked_target.is_alive()):
				target = linked_target
			else:
				target = _find_nearest_enemy(detect_r)
			if target != null:
				var dir: Vector2 = (target.global_position - global_position).normalized()
				if summon_kind == "giant_snake":
					var g_space := get_world_2d().direct_space_state
					var g_step: Vector2 = dir * spd * delta
					var g_hit := g_space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + g_step + dir * 18.0, 1))
					if g_hit.is_empty():
						global_position += g_step
					else:
						global_position = (g_hit["position"] as Vector2) - dir * 18.0
				else:
					global_position += dir * spd * delta
				if is_instance_valid(_sprite):
					_sprite.flip_h = dir.x < 0.0
					if summon_kind == "winged_lion" and _sprite.hframes == 16:
						_sprite.frame = int(_phase * 1.32) % 16
						_sprite.position.y = sin(_phase * 1.8) * 5.0
						_sprite.scale = Vector2(_base_scale, _base_scale)
						_sprite.rotation = clampf(dir.y * 0.35, -0.30, 0.30) * (-1.0 if _sprite.flip_h else 1.0)
					elif summon_kind in ["flash_bird", "winged_lion", "bat"]:
						_sprite.position.y = sin(_phase * 1.8) * 6.5
						var flap: float = sin(_phase * 2.6)
						_sprite.scale = Vector2(_base_scale + flap * 0.04, _base_scale - flap * 0.05)
						_sprite.rotation = clampf(dir.y * 0.35, -0.30, 0.30) * (-1.0 if _sprite.flip_h else 1.0)
					else:
						_sprite.position.y = -absf(sin(_phase * 2.4)) * 5.0
						_sprite.rotation = sin(_phase * 2.4) * 0.08
				if summon_kind == "shadow_mummy" and global_position.distance_to(target.global_position) <= 34.0 and _attack_cd <= 0.0:
					_attack_cd = 0.75
					if can_deal and target.has_method("apply_hit"):
						target.apply_hit(damage, owner_peer_id, weapon_name, owner_name, dir * 180.0)
			else:
				var fwd: Vector2 = flight_dir.normalized() if flight_dir.length_squared() > 0.01 else Vector2(move_dir_x, 0.0)
				if summon_kind == "giant_snake":
					var g_space2 := get_world_2d().direct_space_state
					var g_step2: Vector2 = fwd * spd * delta
					var g_hit2 := g_space2.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + g_step2 + fwd * 18.0, 1))
					if g_hit2.is_empty():
						global_position += g_step2
					else:
						global_position = (g_hit2["position"] as Vector2) - fwd * 18.0
				else:
					global_position += fwd * spd * delta
				if is_instance_valid(_sprite):
					_sprite.flip_h = fwd.x < 0.0
					if summon_kind == "winged_lion" and _sprite.hframes == 16:
						_sprite.frame = int(_phase * 1.32) % 16
						_sprite.position.y = sin(_phase * 1.8) * 5.0
						_sprite.scale = Vector2(_base_scale, _base_scale)
					else:
						_sprite.position.y = sin(_phase * 1.8) * 5.5
						var flap2: float = sin(_phase * 2.6)
						_sprite.scale = Vector2(_base_scale + flap2 * 0.04, _base_scale - flap2 * 0.05)
					_sprite.rotation = clampf(fwd.y * 0.35, -0.30, 0.30) * (-1.0 if _sprite.flip_h else 1.0)
		"bee":
			var b_target: Node2D = _find_nearest_enemy(420.0)
			if b_target != null:
				var b_dir: Vector2 = (b_target.global_position - global_position).normalized()
				global_position += b_dir * 250.0 * delta
				if is_instance_valid(_sprite):
					_sprite.flip_h = b_dir.x < 0.0
			else:
				var vx: float = cos(_phase * 0.7) * 140.0
				global_position += Vector2(vx, sin(_phase * 1.1) * 90.0) * delta
				if is_instance_valid(_sprite):
					_sprite.flip_h = vx < 0.0
			if is_instance_valid(_sprite):
				_sprite.position.y = sin(_phase * 4.0) * 4.0
				var bf: float = sin(_phase * 5.5)
				_sprite.scale = Vector2(_base_scale + bf * 0.04, _base_scale - bf * 0.05)
		"blood_bubble":
			global_position += vel * delta + Vector2(0.0, sin(_phase * 1.5) * 18.0) * delta
		"barbarian", "zombie_dog", "small_snake":
			var g_spd: float = 240.0 if summon_kind == "zombie_dog" else 195.0
			var foot_off: float = 34.0 if summon_kind == "barbarian" else 16.0
			vel.x = move_dir_x * g_spd
			vel.y = minf(vel.y + 920.0 * delta, 650.0)
			var space := get_world_2d().direct_space_state
			var ray := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, foot_off + maxf(6.0, vel.y * delta)), 1)
			var hit := space.intersect_ray(ray)
			if not hit.is_empty() and vel.y >= 0.0:
				global_position.y = (hit["position"] as Vector2).y - foot_off
				vel.y = 0.0
			if summon_kind in ["barbarian", "small_snake"]:
				var h_ray := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(move_dir_x * 20.0, 0.0), 1)
				var h_hit := space.intersect_ray(h_ray)
				if not h_hit.is_empty():
					global_position.x = (h_hit["position"] as Vector2).x - move_dir_x * 16.0
					vel.x = 0.0
			global_position += vel * delta
			if is_instance_valid(_sprite):
				_sprite.flip_h = move_dir_x < 0.0
				if summon_kind == "barbarian" and _sprite.hframes == 10:
					_sprite.frame = int(_phase * 2.25) % 10
					_sprite.position.y = 0.0
					_sprite.rotation = 0.0
				else:
					_sprite.position.y = -absf(sin(_phase * 2.5)) * 5.5
					_sprite.rotation = sin(_phase * 2.5) * 0.09
		"bomb_eagle":
			var e_target: Node2D = _find_nearest_enemy(900.0)
			if e_target != null:
				var above := e_target.global_position + Vector2(0.0, -78.0)
				var to_above := above - global_position
				global_position += to_above.normalized() * 290.0 * delta
				if is_instance_valid(_sprite):
					_sprite.flip_h = to_above.x < 0.0
				if absf(global_position.x - e_target.global_position.x) < 24.0:
					_drop_eagle_bomb()
					queue_free()
					return
			else:
				global_position.x += move_dir_x * 230.0 * delta
				if is_instance_valid(_sprite):
					_sprite.flip_h = move_dir_x < 0.0
			if is_instance_valid(_sprite):
				_sprite.position.y = sin(_phase * 2.0) * 6.0
				var ef: float = sin(_phase * 2.8)
				_sprite.scale = Vector2(_base_scale + ef * 0.04, _base_scale - ef * 0.05)
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
			vel.x = move_dir_x * 165.0
			vel.y = minf(vel.y + 920.0 * delta, 650.0)
			var g_space := get_world_2d().direct_space_state
			var g_ray := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, 26.0), 1)
			var g_hit := g_space.intersect_ray(g_ray)
			if not g_hit.is_empty() and vel.y > 0.0:
				global_position.y = (g_hit["position"] as Vector2).y - 22.0
				vel.y = 0.0
			global_position += vel * delta
			if is_instance_valid(_modular_clone):
				if _attack_cd <= 0.0:
					_attack_cd = 0.65
					_modular_clone.play_state("firing", move_dir_x < 0.0)
				elif _attack_cd < 0.45:
					_modular_clone.play_state("run", move_dir_x < 0.0)
		"mirror_clone":
			if is_instance_valid(linked_target):
				global_position = global_position.lerp(linked_target.global_position + Vector2(48.0 * move_dir_x, 0.0), clampf(delta * 4.0, 0.0, 1.0))
		"tornado":
			var t_tgt: Node2D = _find_nearest_enemy(780.0)
			if t_tgt != null:
				var to_t: Vector2 = t_tgt.global_position - global_position
				if to_t.length() > 8.0:
					global_position += to_t.normalized() * 255.0 * delta
			else:
				global_position.x += move_dir_x * 235.0 * delta
			_attack_cd -= delta
			if _attack_cd <= 0.0:
				_attack_cd = 0.10
				if can_deal:
					for p in get_tree().get_nodes_in_group("players"):
						if is_instance_valid(p) and int(p.get("peer_id")) != owner_peer_id:
							if p.has_method("is_alive") and not p.is_alive():
								continue
							if NetworkManager.is_team_mode() and int(p.get("team_id")) == owner_team:
								continue
							if (p as Node2D).global_position.distance_to(global_position) <= 68.0 and p.has_method("apply_hit"):
								var pull_dir: Vector2 = (global_position - (p as Node2D).global_position).normalized()
								p.apply_hit(10, owner_peer_id, weapon_name, owner_name, pull_dir * 95.0 + Vector2(0.0, -70.0))
			queue_redraw()
		"crush_walls":
			_wall_gap = maxf(0.0, _wall_gap - 360.0 * delta)
			if _wall_gap <= 6.0:
				if can_deal:
					for p in get_tree().get_nodes_in_group("players"):
						if is_instance_valid(p) and int(p.get("peer_id")) != owner_peer_id:
							if p.has_method("is_alive") and not p.is_alive():
								continue
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
			if p.has_method("is_alive") and not p.is_alive():
				continue
			if NetworkManager.is_team_mode() and int(p.get("team_id")) == owner_team:
				continue
			if (p as Node2D).global_position.distance_to(global_position) <= 135.0 and p.has_method("apply_hit"):
				p.apply_hit(damage, owner_peer_id, weapon_name, owner_name, Vector2(0.0, -180.0))


func _blast_ghost_clone() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var exp := preload("res://scenes/Explosion.tscn").instantiate()
	exp.global_position = global_position
	exp.explosion_radius = 125.0
	exp.max_damage = damage if damage > 0 else 50
	exp.shooter_peer_id = owner_peer_id
	exp.shooter_team = owner_team
	exp.shooter_name = owner_name
	exp.weapon_name = "Ghost Clone Blast"
	exp.ring_color = Color(0.65, 0.94, 1.0)
	exp.can_deal_damage = can_deal
	exp.allow_self_damage = false
	parent_node.add_child(exp)


func _blast_bomb_eagle() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var exp := preload("res://scenes/Explosion.tscn").instantiate()
	exp.global_position = global_position
	exp.explosion_radius = 135.0
	exp.max_damage = damage
	exp.shooter_peer_id = owner_peer_id
	exp.shooter_team = owner_team
	exp.shooter_name = owner_name
	exp.weapon_name = weapon_name
	exp.ring_color = Color(0.95, 0.78, 0.35)
	exp.can_deal_damage = can_deal
	exp.allow_self_damage = false
	parent_node.add_child(exp)


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("players"):
		return
	if body.has_method("is_alive") and not body.is_alive():
		return
	if int(body.get("peer_id")) == owner_peer_id:
		return
	if NetworkManager.is_team_mode() and int(body.get("team_id")) == owner_team:
		return
	if summon_kind == "ghost_clone":
		_blast_ghost_clone()
		queue_free()
		return
	if summon_kind == "bomb_eagle":
		_blast_bomb_eagle()
		queue_free()
		return
	if summon_kind in ["shadow_mummy", "turret", "mirror_clone", "crush_walls", "dragon_strike", "tornado"]:
		return
	if summon_kind == "barbarian":
		if _barb_attacking:
			return
		_barb_attacking = true
		_barb_attack_elapsed = 0.0
		_barb_target = body
		_barb_hit_done = false
		set_deferred("monitoring", false)
		if is_instance_valid(_sprite):
			_sprite.texture = TEX_BARBARIAN_ATTACK
			_sprite.hframes = 12
			_sprite.frame = 0
			_sprite.scale = Vector2(_base_scale * 1.57, _base_scale * 1.57)
			_sprite.flip_h = (body as Node2D).global_position.x < global_position.x
		return
	if can_deal and body.has_method("apply_hit"):
		body.apply_hit(damage, owner_peer_id, weapon_name, owner_name, Vector2(move_dir_x * 220.0, -120.0))
		if summon_kind == "flash_bird" and body.has_method("apply_status"):
			body.apply_status("flashbang", 3.0)
	if summon_kind == "winged_lion":
		_attack_anim_timer = 0.35
		_attack_dir = ((body as Node2D).global_position - global_position).normalized()
		if _attack_dir.length_squared() < 0.01:
			_attack_dir = Vector2(move_dir_x, 0.0)
		set_deferred("monitoring", false)
		return
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
		"flash_bird", "bat", "barbarian", "zombie_dog", "bomb_eagle", "shadow_mummy", "small_snake", "giant_snake", "bee":
			pass
		"dragon_strike":
			var pulse_d: float = 0.72 + 0.28 * sin(_phase * 2.5)
			var lock_col: Color = Color(1.0, 0.36, 0.14) if is_instance_valid(linked_target) else Color(0.28, 1.0, 0.62)
			draw_circle(Vector2.ZERO, 185.0, Color(lock_col.r, lock_col.g, lock_col.b, 0.08 * pulse_d))
			draw_arc(Vector2.ZERO, 185.0, 0.0, TAU, 40, Color(lock_col.r, lock_col.g, lock_col.b, 0.55 * pulse_d), 2.5)
		"blood_bubble":
			draw_circle(Vector2.ZERO, 10.0, Color(0.88, 0.12, 0.22, 0.65))
			draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 18, Color(1.0, 0.35, 0.45, 0.92), 2.0)
			draw_circle(Vector2(-3.0, -3.0), 3.0, Color(1.0, 0.85, 0.88, 0.75))
		"winged_lion":
			if _attack_anim_timer > 0.0:
				var slash_a: float = clampf(_attack_anim_timer / 0.35, 0.0, 1.0)
				draw_arc(Vector2(_attack_dir.x * 26.0, 0.0), 34.0, -0.9, 0.9, 14, Color(1.0, 0.88, 0.25, slash_a), 4.5)
				draw_arc(Vector2(_attack_dir.x * 32.0, -6.0), 28.0, -0.7, 0.7, 12, Color(1.0, 1.0, 1.0, slash_a * 0.9), 3.0)
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
			if _attack_cd > 0.48:
				var slash_x: float = 28.0 * move_dir_x
				draw_arc(Vector2(slash_x, -4.0), 22.0, -0.8 if move_dir_x > 0 else (PI - 0.8), 0.8 if move_dir_x > 0 else (PI + 0.8), 10, Color(0.75, 0.96, 1.0, 0.85), 3.0)
		"mirror_clone":
			draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 20, Color(0.95, 0.75, 1.0, 0.65), 2.5)
		"tornado":
			# Huge swirling tornado funnel
			for i in range(9):
				var frac: float = float(i) / 8.0
				var ry: float = lerpf(58.0, -96.0, frac)
				var rx_w: float = lerpf(16.0, 68.0, frac)
				var sway: float = sin(_phase * 4.5 + frac * 4.0) * (10.0 + frac * 8.0)
				var col_ring: Color = Color(0.76, 0.64, 1.0, 0.55 + frac * 0.25) if i % 2 == 0 else Color(0.88, 0.94, 1.0, 0.52)
				draw_set_transform(Vector2(sway, ry), 0.0, Vector2(1.0, 0.34))
				draw_circle(Vector2.ZERO, rx_w, Color(0.62, 0.50, 0.88, 0.22))
				draw_arc(Vector2.ZERO, rx_w, 0.0, TAU, 24, col_ring, 5.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"crush_walls":
			draw_rect(Rect2(-_wall_gap - 24.0, -76.0, 26.0, 152.0), Color(0.98, 0.44, 0.84, 0.85))
			draw_rect(Rect2(_wall_gap - 2.0, -76.0, 26.0, 152.0), Color(0.98, 0.44, 0.84, 0.85))
