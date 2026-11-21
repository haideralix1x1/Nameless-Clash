extends Node2D

var preview_rig: Node2D = null
var _active_kind: String = ""
var _col: Color = Color.CYAN
var _timer: float = 0.0
var _dur: float = 1.2
var _tex: Texture2D = null
var _tex2: Texture2D = null
var _phase: float = 0.0


func trigger(kind: String, col: Color, rig: Node2D) -> void:
	_active_kind = kind
	_col = col
	_dur = 1.35
	_timer = _dur
	_phase = 0.0
	preview_rig = rig
	_tex = null
	_tex2 = null
	if is_instance_valid(preview_rig):
		preview_rig.visible = true
		preview_rig.position = Vector2.ZERO
		if preview_rig.has_method("get") and preview_rig.get("_rig") != null:
			var r = preview_rig.get("_rig")
			if r != null and r.has_method("play_state"):
				r.play_state("firing", false)
	match kind:
		"ult_winged_lion":
			_tex = load("res://assets/sprites/summons/winged_lion_sheet.png")
		"flash_bird":
			_tex = load("res://assets/sprites/summons/bird.png")
		"boar_ride":
			_tex = load("res://assets/sprites/summons/boar.png")
		"barbarian_squad":
			_tex = load("res://assets/sprites/summons/barbarian_sheet.png")
		"bat_swarm", "ult_bat_execute":
			_tex = load("res://assets/sprites/summons/bat.png")
		"zombie_dog":
			_tex = load("res://assets/sprites/summons/zombie_dog.png")
		"bomb_eagle":
			_tex = load("res://assets/sprites/summons/eagle.png")
		"shadow_mummy":
			_tex = load("res://assets/sprites/summons/mummy.png")
		"snake_trio", "ult_giant_snake":
			_tex = load("res://assets/sprites/summons/snake.png")
		"ult_dragon_strike":
			_tex = load("res://assets/sprites/summons/dragon.png")
		"bee_swarm":
			_tex = load("res://assets/sprites/summons/bee.png")
		"raven_swarm":
			_tex = load("res://assets/sprites/summons/raven.png")
		"dual_shotguns":
			_tex = load("res://assets/sprites/weapons_sheet.png")
	queue_redraw()


func _process(delta: float) -> void:
	if _timer <= 0.0:
		return
	_timer = maxf(0.0, _timer - delta)
	_phase += delta * 8.0
	if is_instance_valid(preview_rig):
		if _active_kind == "ult_bat_execute":
			preview_rig.visible = _timer <= 0.15
		elif _active_kind == "ult_ghost_stealth":
			preview_rig.modulate.a = 0.28 if _timer > 0.15 else 1.0
		elif _active_kind == "boar_ride":
			preview_rig.position = Vector2(0.0, -14.0 - absf(sin(_phase)) * 4.0) if _timer > 0.1 else Vector2.ZERO
		elif _active_kind in ["jump_kick", "ult_jump_execute", "ult_spear_jump", "running_spear", "dash_speed", "ult_boxer_flurry"]:
			var t_prog: float = 1.0 - (_timer / _dur)
			preview_rig.position.x = sin(t_prog * PI) * 58.0
		else:
			preview_rig.position = Vector2.ZERO
		if _timer <= 0.0:
			preview_rig.visible = true
			preview_rig.modulate.a = 1.0
			preview_rig.position = Vector2.ZERO
			var r = preview_rig.get("_rig")
			if r != null and r.has_method("play_state"):
				r.play_state("idle", false)
	queue_redraw()


func _draw() -> void:
	if _timer <= 0.0:
		return
	var t: float = 1.0 - (_timer / _dur)
	var a: float = clampf(_timer / 0.35, 0.0, 1.0)
	var c := Color(_col.r, _col.g, _col.b, a)

	if _tex != null:
		if _active_kind == "dual_shotguns":
			var reg := Rect2(5 * 256, 0, 256, 128)
			draw_texture_rect_region(_tex, Rect2(8, -18, 42, 21), reg)
			draw_texture_rect_region(_tex, Rect2(8, -4, 42, 21), reg)
			draw_line(Vector2(50, -8), Vector2(130, -14 + sin(_phase) * 8), Color(1.0, 0.85, 0.3, a), 3.0)
			draw_line(Vector2(50, 4), Vector2(130, 12 - sin(_phase) * 8), Color(1.0, 0.85, 0.3, a), 3.0)
			return
		var sz: Vector2 = Vector2(76, 76) if _active_kind in ["ult_winged_lion", "ult_dragon_strike", "boar_ride", "ult_giant_snake"] else Vector2(52, 52)
		var pos_x: float = lerpf(24.0, 118.0, t)
		var pos_y: float = sin(_phase) * 8.0 - 8.0
		if _active_kind == "boar_ride":
			pos_x = 0.0
			pos_y = 14.0 - absf(sin(_phase)) * 4.0
		elif _active_kind == "ult_bat_execute":
			pos_x = sin(t * PI) * 72.0
		if _active_kind == "barbarian_squad":
			var f_idx: int = int(_phase * 0.8) % 10
			var fw: float = float(_tex.get_width()) / 10.0
			var fh: float = float(_tex.get_height())
			draw_texture_rect_region(_tex, Rect2(Vector2(pos_x, 4.0) - sz * 0.5, sz), Rect2(float(f_idx) * fw, 0.0, fw, fh))
		elif _active_kind == "ult_winged_lion":
			var lf_idx: int = int(_phase * 0.90) % 16
			var lfw: float = float(_tex.get_width()) / 16.0
			var lfh: float = float(_tex.get_height())
			draw_texture_rect_region(_tex, Rect2(Vector2(pos_x, pos_y) - sz * 0.5, sz), Rect2(float(lf_idx) * lfw, 0.0, lfw, lfh))
		else:
			draw_texture_rect(_tex, Rect2(Vector2(pos_x, pos_y) - sz * 0.5, sz), false)
		return

	match _active_kind:
		"gradual_heal":
			for i in range(6):
				var px: float = -24.0 + float(i) * 10.0
				var py: float = 16.0 - fmod(t * 70.0 + float(i) * 12.0, 62.0)
				draw_line(Vector2(px - 5, py), Vector2(px + 5, py), Color(0.28, 0.98, 0.48, a), 2.8)
				draw_line(Vector2(px, py - 5), Vector2(px, py + 5), Color(0.28, 0.98, 0.48, a), 2.8)
		"push_circle", "scream_wave", "ult_self_blast", "ult_time_slow", "ult_inferno_ring", "ult_earth_quake_zone":
			var r: float = 18.0 + t * 95.0
			draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, a * 0.22))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, c, 4.0)
		"blood_beam", "fiery_hand_beam", "dragon_laser", "ult_electric_laser", "long_spear":
			draw_line(Vector2(18, -4), Vector2(155, -4), c, 12.0)
			draw_line(Vector2(18, -4), Vector2(155, -4), Color(1, 1, 1, a), 4.0)
		"wall", "equip_shield", "damage_shield_50", "invincible_self", "ult_deathless_2x":
			draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 28, c, 4.5)
			draw_circle(Vector2.ZERO, 42.0, Color(c.r, c.g, c.b, a * 0.18))
		"ghost_clones", "ult_mirror_clone":
			draw_circle(Vector2(-68, 0), 18.0, Color(c.r, c.g, c.b, a * 0.65))
			draw_circle(Vector2(68, 0), 18.0, Color(c.r, c.g, c.b, a * 0.65))
		"ult_crush_walls":
			var gap: float = lerpf(85.0, 10.0, t)
			draw_rect(Rect2(60 - gap - 14, -44, 14, 88), c)
			draw_rect(Rect2(60 + gap, -44, 14, 88), c)
		"hook_drag", "touch_teleport", "banish_enemy", "swap_enemy":
			var hx: float = lerpf(18.0, 125.0, t)
			draw_line(Vector2(12, -4), Vector2(hx, -10), c, 3.0)
			draw_circle(Vector2(hx, -10), 7.0, c)
		_:
			var bx: float = lerpf(22.0, 136.0, t)
			draw_circle(Vector2(bx, -6), 11.0, c)
			draw_arc(Vector2(bx, -6), 14.0, 0.0, TAU, 16, Color(1, 1, 1, a), 2.5)
