extends Node2D

var zone_kind: String = "" # "ice_platform", "lava_platform", "frost_gas", "poison_gas", "earth_quake_zone", "inferno_ring"
var shooter_id: int = 0
var shooter_team: int = -1
var shooter_name: String = ""
var weapon_name: String = "Hazard"
var can_deal: bool = false
var time_left: float = 5.0
var radius: float = 120.0
var dps: int = 20
var _tick_accum: float = 0.0
var _left_span: float = 120.0
var _right_span: float = 120.0


func _ready() -> void:
	z_index = 8
	if has_meta("is_lava"):
		zone_kind = "lava_platform" if bool(get_meta("is_lava")) else "ice_platform"
		shooter_id = int(get_meta("shooter_id"))
		shooter_team = int(get_meta("shooter_team"))
		shooter_name = str(get_meta("shooter_name"))
		weapon_name = str(get_meta("weapon_name"))
		can_deal = bool(get_meta("can_deal"))
		time_left = float(get_meta("time_left"))
		radius = 135.0
		dps = 10 if zone_kind == "lava_platform" else 0
	if zone_kind in ["ice_platform", "lava_platform"]:
		_snap_to_platform_bounds()
	queue_redraw()


func _snap_to_platform_bounds() -> void:
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var center_ray := PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -24.0), global_position + Vector2(0.0, 36.0), 1)
	var center_hit := space.intersect_ray(center_ray)
	if not center_hit.is_empty():
		global_position.y = (center_hit["position"] as Vector2).y
	_left_span = 0.0
	_right_span = 0.0
	for step in range(1, 10):
		var dx: float = float(step) * 16.0
		if dx > radius:
			break
		var lr := PhysicsRayQueryParameters2D.create(global_position + Vector2(-dx, -14.0), global_position + Vector2(-dx, 18.0), 1)
		if space.intersect_ray(lr).is_empty():
			break
		_left_span = dx
	for step in range(1, 10):
		var dx: float = float(step) * 16.0
		if dx > radius:
			break
		var rr := PhysicsRayQueryParameters2D.create(global_position + Vector2(dx, -14.0), global_position + Vector2(dx, 18.0), 1)
		if space.intersect_ray(rr).is_empty():
			break
		_right_span = dx
	_left_span = maxf(24.0, _left_span)
	_right_span = maxf(24.0, _right_span)


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	_tick_accum += delta
	queue_redraw()
	var interval: float = 0.08 if zone_kind == "ice_platform" else 0.25
	if _tick_accum < interval:
		return
	_tick_accum = 0.0
	if not can_deal:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		if int(p.get("peer_id")) == shooter_id:
			continue
		if NetworkManager.is_team_mode() and int(p.get("team_id")) == shooter_team:
			continue
		var px: float = (p as Node2D).global_position.x
		var py: float = (p as Node2D).global_position.y
		var dist: float = (p as Node2D).global_position.distance_to(global_position)
		if zone_kind == "ice_platform":
			if px >= global_position.x - _left_span - 12.0 and px <= global_position.x + _right_span + 12.0 and absf(py - global_position.y) <= 58.0:
				if p.has_method("apply_status"):
					p.apply_status("slippery", 0.35)
		elif zone_kind == "lava_platform":
			if px >= global_position.x - _left_span - 12.0 and px <= global_position.x + _right_span + 12.0 and absf(py - global_position.y) <= 58.0:
				if p.has_method("apply_hit"):
					p.apply_hit(maxi(1, int(round(float(dps) * 0.25))), shooter_id, weapon_name, shooter_name, Vector2.ZERO)
		elif dist <= radius:
			if zone_kind == "earth_quake_zone" and p.has_method("apply_status"):
				p.apply_status("earth_shake", 0.45)
			if dps > 0 and p.has_method("apply_hit"):
				p.apply_hit(maxi(1, int(round(float(dps) * 0.25))), shooter_id, weapon_name, shooter_name, Vector2.ZERO)


func _draw() -> void:
	var alpha: float = clampf(time_left, 0.25, 1.0)
	match zone_kind:
		"ice_platform":
			var w: float = _left_span + _right_span
			draw_rect(Rect2(-_left_span, -10.0, w, 18.0), Color(0.32, 0.82, 1.0, 0.58 * alpha))
			draw_rect(Rect2(-_left_span, -10.0, w, 18.0), Color(0.85, 0.98, 1.0, 0.92 * alpha), false, 2.5)
			var x_cur: float = -_left_span + 10.0
			while x_cur < _right_span - 14.0:
				draw_line(Vector2(x_cur, -7.0), Vector2(x_cur + 10.0, 5.0), Color(1.0, 1.0, 1.0, 0.65 * alpha), 2.5)
				x_cur += 26.0
		"lava_platform":
			var lw: float = _left_span + _right_span
			draw_rect(Rect2(-_left_span, -6.0, lw, 14.0), Color(1.0, 0.36, 0.08, 0.80 * alpha))
			draw_rect(Rect2(-_left_span, -6.0, lw, 14.0), Color(1.0, 0.82, 0.20, 0.92 * alpha), false, 2.0)
		"frost_gas":
			draw_circle(Vector2.ZERO, radius, Color(0.84, 0.96, 1.0, 0.30 * alpha))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.75, 0.95, 1.0, 0.75 * alpha), 3.0)
		"poison_gas":
			draw_circle(Vector2.ZERO, radius, Color(0.32, 0.92, 0.35, 0.32 * alpha))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.45, 1.0, 0.38, 0.78 * alpha), 3.0)
		"earth_quake_zone":
			draw_circle(Vector2.ZERO, radius, Color(0.68, 0.45, 0.22, 0.28 * alpha))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.95, 0.65, 0.28, 0.85 * alpha), 4.0)
		"inferno_ring":
			draw_circle(Vector2.ZERO, radius, Color(1.0, 0.32, 0.08, 0.35 * alpha))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.75, 0.18, 0.92 * alpha), 5.0)
