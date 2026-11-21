extends Node2D

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/Explosion.tscn")
const TEX_BOMB_TIME: Texture2D = preload("res://assets/sprites/weapons/bomb_time.png")
const TEX_BOMB_FRAG: Texture2D = preload("res://assets/sprites/weapons/bomb_frag.png")
const TEX_BOMB_MINE: Texture2D = preload("res://assets/sprites/weapons/bomb_mine.png")
const TEX_BOMB_CLUSTER: Texture2D = preload("res://assets/sprites/weapons/bomb_cluster.png")
const TEX_BOMB_STICKY: Texture2D = preload("res://assets/sprites/weapons/bomb_sticky.png")

var bomb_type: String = "frag"
var velocity: Vector2 = Vector2.ZERO
var damage: int = 82
var explosion_radius: float = 155.0
var shooter_peer_id: int = 1
var shooter_team: int = 0
var shooter_name: String = "Trooper"
var shooter_rid: RID = RID()
var weapon_name: String = "Frag Bomb"
var bomb_color: Color = Color(0.28, 0.92, 0.42)
var can_deal_damage: bool = true
var allow_self_damage: bool = true
var stick_fuse_override: float = 0.0

var _age: float = 0.0
var _fuse_time: float = 2.0
var _settled: bool = false
var _stuck: bool = false
var _stuck_target: Node2D = null
var _stuck_offset: Vector2 = Vector2.ZERO
var _armed: bool = false
var _arm_timer: float = 0.0
var _trigger_radius: float = 48.0
var _exploded: bool = false
var _spin: float = 0.0

var _beep_times: Array[float] = [0.9, 1.8, 2.7, 3.45]
var _beep_idx: int = 0
var _beep_flash: float = 0.0
var _beep_player: AudioStreamPlayer2D = null
var _hit_body: BombHitbox = null


class BombHitbox extends StaticBody2D:
	var bomb_ref: Node = null

	func on_shot_hit(_dmg: int = 0, _attacker_id: int = 0) -> void:
		if bomb_ref != null and is_instance_valid(bomb_ref) and bomb_ref.has_method("detonate_from_hit"):
			bomb_ref.detonate_from_hit()


func _ready() -> void:
	match bomb_type:
		"sticky":
			_fuse_time = 3.0
		"time":
			_fuse_time = 4.0
			_beep_player = AudioStreamPlayer2D.new()
			_beep_player.stream = _create_beep_stream()
			_beep_player.volume_db = 2.0
			_beep_player.max_distance = 1400.0
			add_child(_beep_player)
		"mine":
			_fuse_time = -1.0
			_trigger_radius = 48.0
			_hit_body = BombHitbox.new()
			_hit_body.bomb_ref = self
			_hit_body.collision_layer = 2
			_hit_body.collision_mask = 0
			_hit_body.add_to_group("destructible_bombs")
			var col := CollisionShape2D.new()
			var shape := CircleShape2D.new()
			shape.radius = 13.0
			col.shape = shape
			_hit_body.add_child(col)
			add_child(_hit_body)
		_:
			_fuse_time = 2.0
	queue_redraw()


func detonate_from_hit() -> void:
	_explode()


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	_age += delta
	_beep_flash = maxf(0.0, _beep_flash - delta * 4.5)

	if bomb_type == "time" and _beep_idx < _beep_times.size() and _age >= _beep_times[_beep_idx]:
		_beep_idx += 1
		_beep_flash = 1.0
		if is_instance_valid(_beep_player):
			_beep_player.pitch_scale = 1.0 + 0.06 * float(_beep_idx - 1)
			_beep_player.play()

	if _fuse_time > 0.0 and _age >= _fuse_time:
		_explode()
		return

	if _stuck:
		if _stuck_target != null:
			if is_instance_valid(_stuck_target) and (not _stuck_target.has_method("is_alive") or _stuck_target.is_alive()):
				global_position = _stuck_target.global_position + _stuck_offset
			else:
				_stuck = false
				_stuck_target = null
				_settled = false
		queue_redraw()
		return

	if bomb_type == "mine" and _settled:
		if not _armed:
			_arm_timer -= delta
			if _arm_timer <= 0.0:
				_armed = true
		else:
			for p in get_tree().get_nodes_in_group("players"):
				if not is_instance_valid(p):
					continue
				if p.has_method("is_alive") and not p.is_alive():
					continue
				if global_position.distance_to(p.global_position) <= _trigger_radius:
					_explode()
					return
		queue_redraw()
		return

	if not _settled:
		velocity.y += 980.0 * maxf(0.15, NetworkManager.gravity_scale) * delta
		var prev_pos: Vector2 = global_position
		var next_pos: Vector2 = prev_pos + velocity * delta

		var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		var mask: int = 3 if bomb_type == "sticky" else 1
		var query := PhysicsRayQueryParameters2D.create(prev_pos, next_pos, mask)
		var excl: Array[RID] = []
		if shooter_rid.is_valid() and _age < 0.16:
			excl.append(shooter_rid)
		if _hit_body != null and is_instance_valid(_hit_body):
			excl.append(_hit_body.get_rid())
		if bomb_type == "sticky":
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
			var normal: Vector2 = hit["normal"]
			var collider: Object = hit["collider"]
			if bomb_type == "sticky":
				global_position = hit_pos + normal * 4.0
				velocity = Vector2.ZERO
				_stuck = true
				if stick_fuse_override > 0.0:
					_fuse_time = _age + stick_fuse_override
				if collider != null and collider is Node2D and collider.is_in_group("players"):
					_stuck_target = collider as Node2D
					_stuck_offset = global_position - _stuck_target.global_position
				queue_redraw()
				return
			else:
				global_position = hit_pos + normal * 8.0
				var v_n: Vector2 = normal * velocity.dot(normal)
				var v_t: Vector2 = velocity - v_n
				var restitution: float = 0.18 if bomb_type == "mine" else 0.38
				var friction: float = 0.55 if bomb_type == "mine" else 0.76
				velocity = v_t * friction - v_n * restitution
				if normal.y < -0.5 and velocity.length() < 48.0:
					velocity = Vector2.ZERO
					_settled = true
					if bomb_type == "mine":
						_arm_timer = 0.35
		else:
			global_position = next_pos
			_spin += clampf(velocity.x * 0.015, -8.0, 8.0) * delta

	queue_redraw()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var parent_node: Node = get_parent()
	if parent_node != null:
		var exp := EXPLOSION_SCENE.instantiate()
		exp.global_position = global_position
		exp.explosion_radius = explosion_radius
		exp.max_damage = damage
		exp.shooter_peer_id = shooter_peer_id
		exp.shooter_team = shooter_team
		exp.shooter_name = shooter_name
		exp.weapon_name = weapon_name
		exp.ring_color = bomb_color
		exp.can_deal_damage = can_deal_damage
		exp.allow_self_damage = allow_self_damage
		parent_node.add_child(exp)
	queue_free()


func _create_beep_stream() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var dur: float = 0.09
	var count: int = int(sample_rate * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(sample_rate)
		var env: float = 1.0 - (float(i) / float(count)) * 0.35
		var s: float = sin(TAU * 1180.0 * t) * env * 0.55
		var sample_i: int = clampi(int(s * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, sample_i)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	return wav


func _draw() -> void:
	match bomb_type:
		"mine":
			var pulse: float = 0.5 + 0.5 * sin(_age * 7.0)
			if _armed:
				draw_circle(Vector2.ZERO, _trigger_radius, Color(1.0, 0.25, 0.18, 0.09 + 0.05 * pulse))
				draw_arc(Vector2.ZERO, _trigger_radius, 0.0, TAU, 28, Color(1.0, 0.32, 0.22, 0.55 + 0.25 * pulse), 2.0)
			elif _settled:
				draw_arc(Vector2.ZERO, _trigger_radius, 0.0, TAU, 24, Color(1.0, 0.78, 0.25, 0.35), 1.5)
			draw_texture_rect(TEX_BOMB_MINE, Rect2(-14.0, -14.0, 28.0, 28.0), false)
		"time":
			draw_set_transform(Vector2.ZERO, _spin if not _settled else 0.0, Vector2.ONE)
			draw_texture_rect(TEX_BOMB_TIME, Rect2(-15.0, -15.0, 30.0, 30.0), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if _beep_flash > 0.05:
				draw_arc(Vector2.ZERO, 14.0 + (1.0 - _beep_flash) * 26.0, 0.0, TAU, 24, Color(1.0, 0.32, 0.22, _beep_flash * 0.85), 2.5)
			var frac: float = clampf(1.0 - (_age / maxf(0.1, _fuse_time)), 0.0, 1.0)
			draw_arc(Vector2.ZERO, 16.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, Color(1.0, 0.72, 0.22, 0.8), 2.0)
		"sticky":
			draw_set_transform(Vector2.ZERO, _spin if not _stuck else 0.0, Vector2.ONE)
			draw_texture_rect(TEX_BOMB_STICKY, Rect2(-14.0, -14.0, 28.0, 28.0), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"cluster":
			draw_set_transform(Vector2.ZERO, _spin if not _settled else 0.0, Vector2.ONE)
			draw_texture_rect(TEX_BOMB_CLUSTER, Rect2(-14.0, -14.0, 28.0, 28.0), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_:
			draw_set_transform(Vector2.ZERO, _spin if not _settled else 0.0, Vector2.ONE)
			draw_texture_rect(TEX_BOMB_FRAG, Rect2(-14.0, -14.0, 28.0, 28.0), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

