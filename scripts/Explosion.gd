extends Node2D

var explosion_radius: float = 120.0
var max_damage: int = 0
var shooter_peer_id: int = 0
var shooter_team: int = 0
var shooter_name: String = ""
var weapon_name: String = "Rocket Launcher"
var can_deal_damage: bool = false

var _elapsed: float = 0.0
var _duration: float = 0.38
var _ring_radius: float = 8.0
var _ring_alpha: float = 1.0
var _dealt_damage: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	var scale_factor: float = clampf(explosion_radius / 60.0, 0.7, 2.8)
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_sprite.frame = 0
	if _audio.stream != null:
		_audio.pitch_scale = randf_range(0.92, 1.08)
		_audio.play()
	for node in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(node) and node.has_method("add_screen_shake"):
			var dist: float = global_position.distance_to(node.global_position)
			if dist < 650.0:
				node.add_screen_shake(clampf(1.0 - dist / 650.0, 0.1, 1.0) * (14.0 if max_damage > 0 else 4.0))
	if can_deal_damage and max_damage > 0 and not _dealt_damage:
		_dealt_damage = true
		call_deferred("_apply_splash_damage")


func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var frame_idx: int = clampi(int(progress * 6.0), 0, 5)
	_sprite.frame = frame_idx
	_ring_radius = lerpf(10.0, explosion_radius, progress)
	_ring_alpha = 1.0 - progress
	queue_redraw()
	if _elapsed >= _duration and not _audio.playing:
		queue_free()
	elif _elapsed >= 0.65:
		_audio.stop()
		queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_audio) and _audio.playing:
		_audio.stop()


func _draw() -> void:
	if _ring_alpha > 0.02:
		var ring_col := Color(1.0, 0.72, 0.25, _ring_alpha * 0.75)
		draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 32, ring_col, 3.5)


func _apply_splash_damage() -> void:
	for node in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(node):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		if NetworkManager.match_mode == 1 and int(node.get("team_id")) == shooter_team and int(node.get("peer_id")) != shooter_peer_id:
			continue
		var dist: float = global_position.distance_to(node.global_position)
		if dist <= explosion_radius:
			var falloff: float = clampf(1.0 - (dist / explosion_radius) * 0.65, 0.25, 1.0)
			var dmg: int = maxi(1, int(round(float(max_damage) * falloff)))
			var dir: Vector2 = (node.global_position - global_position).normalized()
			if dir.length_squared() < 0.01:
				dir = Vector2.UP
			var knockback: Vector2 = dir * (420.0 * falloff) + Vector2(0.0, -140.0 * falloff)
			if node.has_method("apply_hit"):
				node.apply_hit(dmg, shooter_peer_id, weapon_name, shooter_name, knockback)
