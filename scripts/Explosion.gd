extends Node2D

var explosion_radius: float = 120.0
var max_damage: int = 0
var shooter_peer_id: int = 0
var shooter_team: int = 0
var shooter_name: String = ""
var weapon_name: String = "Rocket Launcher"
var can_deal_damage: bool = false
var allow_self_damage: bool = false
var stun_duration: float = 0.0
var ring_color: Color = Color(1.0, 0.72, 0.25)
var custom_splash_only: bool = false
var lightning_orb_only: bool = false

var _elapsed: float = 0.0
var _duration: float = 0.38
var _ring_radius: float = 8.0
var _ring_alpha: float = 1.0
var _dealt_damage: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _audio: AudioStreamPlayer2D = $AudioStreamPlayer2D


func _ready() -> void:
	if stun_duration > 0.0:
		_duration = 0.60
	var scale_factor: float = clampf(explosion_radius / 60.0, 0.7, 2.8)
	_sprite.scale = Vector2(scale_factor, scale_factor)
	_sprite.frame = 0
	if custom_splash_only or lightning_orb_only:
		_sprite.visible = false
	if _audio != null:
		if max_damage > 0:
			_audio.stream = _create_big_blast_stream()
			_audio.volume_db = 4.0
			_audio.pitch_scale = randf_range(0.90, 1.05)
			_audio.play()
		elif _audio.stream != null:
			_audio.volume_db = -14.0
			_audio.pitch_scale = randf_range(1.25, 1.55)
			_audio.play()
	for node in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(node) and node.has_method("add_screen_shake"):
			var dist: float = global_position.distance_to(node.global_position)
			if dist < 650.0:
				node.add_screen_shake(clampf(1.0 - dist / 650.0, 0.1, 1.0) * (2.6 if max_damage > 0 else 0.8))
	if can_deal_damage and (max_damage > 0 or stun_duration > 0.0) and not _dealt_damage:
		_dealt_damage = true
		call_deferred("_apply_splash_damage")


func _process(delta: float) -> void:
	_elapsed += delta
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	if _elapsed >= _duration:
		_sprite.visible = false
	elif not custom_splash_only and not lightning_orb_only:
		var frame_idx: int = clampi(int(progress * 8.0), 0, 7)
		_sprite.frame = frame_idx
		_sprite.modulate.a = clampf((1.0 - progress) * 3.0, 0.0, 1.0)
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
		var ring_col := Color(ring_color.r, ring_color.g, ring_color.b, _ring_alpha * 0.85)
		if stun_duration > 0.0:
			draw_circle(Vector2.ZERO, explosion_radius, Color(ring_color.r, ring_color.g, ring_color.b, _ring_alpha * 0.28))
			draw_arc(Vector2.ZERO, explosion_radius, 0.0, TAU, 40, ring_col, 4.0)
			draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, _ring_alpha * 0.85), 2.5)
		else:
			if lightning_orb_only:
				var prog: float = clampf(_elapsed / maxf(_duration, 0.01), 0.0, 1.0)
				var circle_r: float = lerpf(explosion_radius * 0.55, explosion_radius, prog)
				var orb_r: float = lerpf(14.0, 7.0, prog)
				# Outer purple circle glow + crisp neon ring
				draw_circle(Vector2.ZERO, circle_r, Color(0.54, 0.16, 0.96, _ring_alpha * 0.24))
				draw_arc(Vector2.ZERO, circle_r, 0.0, TAU, 36, Color(0.76, 0.30, 1.0, _ring_alpha * 0.95), 4.0)
				draw_arc(Vector2.ZERO, circle_r * 0.94, 0.0, TAU, 36, Color(0.94, 0.78, 1.0, _ring_alpha * 0.65), 1.6)
				# Center glowing orb
				draw_circle(Vector2.ZERO, orb_r * 1.35, Color(0.66, 0.22, 1.0, _ring_alpha * 0.55))
				draw_circle(Vector2.ZERO, orb_r, Color(0.84, 0.52, 1.0, _ring_alpha * 0.92))
				draw_circle(Vector2.ZERO, orb_r * 0.52, Color(0.98, 0.92, 1.0, _ring_alpha))
				# Animated purple neon lightning bolts crackling inside the circle
				var bolt_step: int = int(_elapsed * 32.0)
				for bi in range(7):
					var base_ang: float = float(bi) * (TAU / 7.0) + float(bolt_step % 5) * 0.37 + sin(_elapsed * 24.0 + float(bi)) * 0.25
					var p0: Vector2 = Vector2.from_angle(base_ang) * (orb_r * 0.65)
					var zig1: float = sin(_elapsed * 48.0 + float(bi) * 2.1) * 0.34
					var zig2: float = cos(_elapsed * 52.0 + float(bi) * 1.7) * 0.28
					var p1: Vector2 = Vector2.from_angle(base_ang + zig1) * (circle_r * 0.44)
					var p2: Vector2 = Vector2.from_angle(base_ang - zig2) * (circle_r * 0.74)
					var p3: Vector2 = Vector2.from_angle(base_ang + zig1 * 0.4) * (circle_r * 0.95)
					var neon_col := Color(0.74, 0.28, 1.0, _ring_alpha * 0.92)
					var core_col := Color(0.97, 0.88, 1.0, _ring_alpha)
					draw_line(p0, p1, neon_col, 3.6)
					draw_line(p1, p2, neon_col, 3.2)
					draw_line(p2, p3, neon_col, 2.6)
					draw_line(p0, p1, core_col, 1.6)
					draw_line(p1, p2, core_col, 1.4)
					draw_line(p2, p3, core_col, 1.2)
				return
			if custom_splash_only:
				draw_circle(Vector2.ZERO, _ring_radius * 0.85, Color(ring_color.r, ring_color.g, ring_color.b, _ring_alpha * 0.42))
				draw_circle(Vector2.ZERO, _ring_radius * 0.45, Color(ring_color.lightened(0.35).r, ring_color.lightened(0.35).g, ring_color.lightened(0.35).b, _ring_alpha * 0.65))
			draw_arc(Vector2.ZERO, _ring_radius, 0.0, TAU, 32, ring_col, 3.5)


func _apply_splash_damage() -> void:
	for node in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(node):
			continue
		if node.has_method("is_alive") and not node.is_alive():
			continue
		var is_barrel: bool = (weapon_name == "Explosive Barrel")
		var is_self: bool = (int(node.get("peer_id")) == shooter_peer_id)
		if is_self and not allow_self_damage and not is_barrel:
			continue
		if not is_barrel and not is_self and NetworkManager.is_team_mode() and int(node.get("team_id")) == shooter_team:
			continue
		var dist: float = global_position.distance_to(node.global_position)
		if dist <= explosion_radius:
			var full_core: bool = is_barrel or weapon_name == "Ghost Clone Blast" or weapon_name == "Frag Bomb"
			var core_ratio: float = 0.45 if weapon_name == "Frag Bomb" else 0.55
			var falloff: float = 1.0 if (full_core and dist <= explosion_radius * core_ratio) else clampf(1.0 - (dist / explosion_radius) * 0.65, 0.25, 1.0)
			var dir: Vector2 = (node.global_position - global_position).normalized()
			if dir.length_squared() < 0.01:
				dir = Vector2.UP
			if max_damage > 0 and node.has_method("apply_hit"):
				var dmg: int = maxi(1, int(round(float(max_damage) * falloff)))
				var knockback: Vector2 = dir * (420.0 * falloff) + Vector2(0.0, -140.0 * falloff)
				node.apply_hit(dmg, shooter_peer_id, weapon_name, shooter_name, knockback)
			if stun_duration > 0.0 and node.has_method("apply_stun"):
				node.apply_stun(stun_duration, shooter_peer_id)
	if max_damage > 0:
		for wall in get_tree().get_nodes_in_group("barrier_walls"):
			if is_instance_valid(wall) and wall.has_method("apply_wall_damage"):
				var w_dist: float = global_position.distance_to(wall.global_position)
				if w_dist <= explosion_radius:
					wall.apply_wall_damage(max_damage)
		for bomb_hb in get_tree().get_nodes_in_group("destructible_bombs"):
			if not is_instance_valid(bomb_hb):
				continue
			var b_dist: float = global_position.distance_to(bomb_hb.global_position)
			if b_dist <= explosion_radius:
				var target_obj: Object = bomb_hb.get_meta("prop_node") if bomb_hb.has_meta("prop_node") else bomb_hb
				if target_obj.has_method("detonate_barrel"):
					target_obj.detonate_barrel(shooter_peer_id, shooter_name, shooter_team)
				elif target_obj.has_method("on_shot_hit"):
					target_obj.on_shot_hit(max_damage, shooter_peer_id)


func _create_big_blast_stream() -> AudioStreamWAV:
	var sr: int = 22050
	var dur: float = 0.72
	var count: int = int(sr * dur)
	var data := PackedByteArray()
	data.resize(count * 2)
	var lp_noise: float = 0.0
	for i in range(count):
		var prog: float = float(i) / float(count)
		var t: float = float(i) / float(sr)
		# Deep sub-bass boom sweep (140Hz -> 30Hz)
		var freq: float = lerpf(140.0, 30.0, pow(prog, 0.45))
		var sub_env: float = exp(-prog * 3.8)
		var sub_wave: float = sin(TAU * freq * t) * sub_env * 0.75
		# Low-passed explosion rumble + punchy crackle
		var raw_n: float = randf_range(-1.0, 1.0)
		var cutoff: float = lerpf(0.55, 0.06, pow(prog, 0.6))
		lp_noise = lerpf(lp_noise, raw_n, cutoff)
		var noise_env: float = exp(-prog * 4.2)
		var crack: float = raw_n * exp(-prog * 22.0) * 0.55
		var mixed: float = clampf(sub_wave + lp_noise * noise_env * 0.85 + crack, -1.0, 1.0)
		data.encode_s16(i * 2, clampi(int(mixed * 32000.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sr
	wav.data = data
	return wav
