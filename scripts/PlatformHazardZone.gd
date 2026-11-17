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


func _ready() -> void:
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
	queue_redraw()


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		queue_free()
		return
	_tick_accum += delta
	queue_redraw()
	if _tick_accum < 0.25:
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
		var dist: float = (p as Node2D).global_position.distance_to(global_position)
		if zone_kind == "ice_platform":
			if absf((p as Node2D).global_position.x - global_position.x) <= radius and absf((p as Node2D).global_position.y - global_position.y) <= 64.0:
				if p.has_method("apply_status"):
					p.apply_status("slippery", 0.4)
		elif zone_kind == "lava_platform":
			if absf((p as Node2D).global_position.x - global_position.x) <= radius and absf((p as Node2D).global_position.y - global_position.y) <= 64.0:
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
			draw_rect(Rect2(-radius, -10.0, radius * 2.0, 18.0), Color(0.55, 0.92, 1.0, 0.72 * alpha))
			draw_rect(Rect2(-radius, -10.0, radius * 2.0, 18.0), Color(0.92, 0.99, 1.0, 0.90 * alpha), false, 2.0)
		"lava_platform":
			draw_rect(Rect2(-radius, -10.0, radius * 2.0, 18.0), Color(1.0, 0.36, 0.08, 0.78 * alpha))
			draw_rect(Rect2(-radius, -10.0, radius * 2.0, 18.0), Color(1.0, 0.82, 0.20, 0.90 * alpha), false, 2.0)
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
