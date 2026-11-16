extends CanvasLayer

signal add_bot_requested
signal remove_bot_requested
signal pickup_weapon_requested(crate_idx: int)
signal interact_requested(inter_idx: int)

const UIStyle = preload("res://scripts/UIStyle.gd")
const WEAPONS_TEX: Texture2D = preload("res://assets/sprites/weapons_sheet.png")
const STICK_RADIUS: float = 84.0
const KNOB_RADIUS: float = 32.0
const PRESET_SELECT_DURATION: float = 5.0
const INDICATOR_MAX_RANGE: float = 1150.0
const INDICATOR_EDGE_MARGIN: float = 34.0

var local_player: Node = null

var _left_touch_idx: int = -1
var _left_mouse_active: bool = false
var _left_center: Vector2 = Vector2(128.0, 585.0)
var _left_knob_offset: Vector2 = Vector2.ZERO

var _right_touch_idx: int = -1
var _right_mouse_active: bool = false
var _right_center: Vector2 = Vector2(1152.0, 585.0)
var _right_knob_offset: Vector2 = Vector2.ZERO

var _killfeed_lines: Array[Dictionary] = []

var _stick_canvas: Control
var _indicator_overlay: Control
var _scope_overlay: Control
var _active_weapon: WeaponData = null
var _hp_bar: ProgressBar
var _hp_label: Label
var _fuel_bar: ProgressBar
var _fuel_label: Label
var _weapon_icon: TextureRect
var _weapon_name_label: Label
var _ammo_label: Label
var _dual_badge: Label
var _net_status_label: Label
var _map_mode_label: Label
var _scoreboard_label: Label
var _killfeed_label: RichTextLabel
var _diag_label: Label
var _respawn_panel: PanelContainer
var _respawn_label: Label
var _add_bot_btn: Button
var _rem_bot_btn: Button
var _test_bot_btn: Button
var _agent_swap_row: HBoxContainer

var _btn_reload: Button
var _btn_switch: Button
var _btn_dual: Button
var _btn_bomb: Button
var _btn_presets: Button
var _btn_zoom: Button
var _btn_shoe: Button
var _btn_pickup: Button
var _nearby_crate_idx: int = -1
var _btn_interact: Button
var _nearby_inter_idx: int = -1
var _btn_throw_prop: Button

var _chat_toggle_btn: Button
var _chat_panel: PanelContainer
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_lines: Array[String] = []
var _chat_toast_label: RichTextLabel
var _chat_toast_items: Array[Dictionary] = []

var _preset_overlay: PanelContainer
var _preset_timer_label: Label
var _preset_cards: Array[Button] = []
var _bomb_type_buttons: Dictionary = {}
var _chosen_bomb_type: String = ""
var _preset_time_left: float = 0.0
var _preset_selection_done: bool = false
var _chosen_preset_idx: int = -1

var _agent_action_panel: VBoxContainer
var _btn_ability_1: Button
var _btn_ability_2: Button
var _btn_ability_3: Button
var _btn_ult: Button
var _btn_throw: Button
var _stun_banner: PanelContainer
var _stun_label: Label

var _layout_overlay: Control
var _layout_handles: Dictionary = {}
var _dragging_key: String = ""
var _drag_center_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	NetworkManager.player_list_updated.connect(_refresh_scoreboard)
	NetworkManager.killfeed_event.connect(_on_killfeed_event)
	NetworkManager.chat_message_received.connect(_on_chat_message_received)
	if NetworkManager.has_signal("game_rules_updated"):
		NetworkManager.game_rules_updated.connect(_sync_mode_hud_visibility)
	SettingsManager.touch_layout_changed.connect(_update_stick_and_button_positions)
	_refresh_scoreboard()
	_update_stick_and_button_positions()
	if not NetworkManager.is_agent_clash_mode():
		_open_preset_selector(PRESET_SELECT_DURATION)


func _exit_tree() -> void:
	_set_preset_pause(false)


func _process(delta: float) -> void:
	_update_stick_and_button_positions()
	if not get_tree().paused:
		_tick_killfeed(delta)
		_tick_chat_toasts(delta)
	_push_input_to_player()
	_update_scope_overlay()
	if is_instance_valid(_indicator_overlay):
		_indicator_overlay.queue_redraw()
	if is_instance_valid(_diag_label):
		_diag_label.visible = SettingsManager.show_diagnostics
		if _diag_label.visible:
			_diag_label.text = "FPS: %d | PLAYERS: %d" % [Engine.get_frames_per_second(), get_tree().get_nodes_in_group("players").size()]
	if is_instance_valid(_btn_shoe) and _btn_shoe.visible and local_player != null:
		var w_t: float = float(local_player.get("_shoe_windup_timer"))
		var cd_t: float = float(local_player.get("shoe_cooldown_timer"))
		if w_t > 0.01:
			_btn_shoe.text = "👟\n%.1fs" % w_t
			_btn_shoe.modulate = Color(1.0, 0.78, 0.28)
		elif cd_t > 0.05:
			_btn_shoe.text = "👟\n%.1fs" % cd_t
			_btn_shoe.modulate = Color(0.55, 0.58, 0.65)
		else:
			_btn_shoe.text = "👟"
			_btn_shoe.modulate = Color.WHITE

	if not NetworkManager.is_agent_clash_mode() and Input.is_action_just_pressed("loadout_menu"):
		_open_preset_selector(PRESET_SELECT_DURATION)

	if is_instance_valid(_preset_overlay) and _preset_overlay.visible:
		_preset_time_left = maxf(0.0, _preset_time_left - delta)
		if is_instance_valid(_preset_timer_label):
			_preset_timer_label.text = "CHOOSE 2-GUN + BOMBS PRESET  (%.1fs)" % _preset_time_left
		if _preset_time_left <= 0.001:
			var fallback_idx: int = _chosen_preset_idx if _chosen_preset_idx >= 0 else 0
			_confirm_preset(fallback_idx)

	if Input.is_action_just_pressed("open_lobby"):
		NetworkManager.go_to_lobby()


func _update_scope_overlay() -> void:
	if is_instance_valid(_scope_overlay):
		_scope_overlay.visible = false


func bind_local_player(player: Node) -> void:
	local_player = player
	if local_player == null:
		return
	local_player.health_changed.connect(_on_health_changed)
	local_player.fuel_changed.connect(_on_fuel_changed)
	local_player.ammo_changed.connect(_on_ammo_changed)
	local_player.weapon_changed.connect(_on_weapon_changed)
	local_player.died_signal.connect(_on_player_died)
	local_player.respawned_signal.connect(_on_player_respawned)
	if local_player.has_signal("bombs_changed"):
		local_player.bombs_changed.connect(_on_bombs_changed)
	if local_player.has_signal("zoom_changed"):
		local_player.zoom_changed.connect(_on_zoom_changed)
	if local_player.has_signal("agent_state_changed"):
		local_player.agent_state_changed.connect(_on_agent_state_changed)
	if local_player.has_signal("nearby_weapon_changed"):
		local_player.nearby_weapon_changed.connect(_on_nearby_weapon_changed)
	if local_player.has_signal("nearby_interactable_changed"):
		local_player.nearby_interactable_changed.connect(_on_nearby_interactable_changed)
	if local_player.has_signal("held_prop_changed"):
		local_player.held_prop_changed.connect(_on_held_prop_changed)
	if local_player.has_signal("agent_abilities_changed"):
		local_player.agent_abilities_changed.connect(func():
			_refresh_agent_hud(local_player.ability_cooldowns, local_player.ability_max_cooldowns, local_player.held_throwable_id, local_player.stun_timer)
		)
	if _chosen_preset_idx >= 0 and not NetworkManager.is_agent_clash_mode() and local_player.has_method("apply_gun_preset"):
		local_player.apply_gun_preset(_chosen_preset_idx)
	if not _chosen_bomb_type.is_empty() and not NetworkManager.is_agent_clash_mode() and local_player.has_method("set_bomb_type"):
		local_player.set_bomb_type(_chosen_bomb_type)
	_on_fuel_changed(float(local_player.get("jetpack_fuel")), 100.0)
	_on_bombs_changed(int(local_player.get("bomb_count")), str(local_player.get("bomb_type")))
	if local_player.has_method("get_max_zoom_level"):
		_on_zoom_changed(int(local_player.get("current_zoom_level")), local_player.get_max_zoom_level())
	_sync_mode_hud_visibility()
	if NetworkManager.is_agent_clash_mode():
		_refresh_agent_hud(local_player.ability_cooldowns, local_player.ability_max_cooldowns, local_player.held_throwable_id, local_player.stun_timer)


func _sync_mode_hud_visibility() -> void:
	var is_agent: bool = NetworkManager.is_agent_clash_mode()
	if is_instance_valid(_btn_reload):
		_btn_reload.visible = not is_agent
	if is_instance_valid(_btn_switch):
		_btn_switch.visible = not is_agent
	if is_instance_valid(_btn_dual):
		_btn_dual.visible = not is_agent
	if is_instance_valid(_btn_bomb):
		_btn_bomb.visible = (not is_agent) and NetworkManager.allow_explosives
	if is_instance_valid(_btn_presets):
		_btn_presets.visible = not is_agent
	if is_instance_valid(_btn_zoom):
		_btn_zoom.visible = not is_agent
	if is_instance_valid(_btn_shoe):
		_btn_shoe.visible = not is_agent
	if is_instance_valid(_btn_pickup):
		_btn_pickup.visible = (not is_agent) and (_nearby_crate_idx >= 0)
	if is_agent and is_instance_valid(_preset_overlay):
		_preset_overlay.visible = false
		_set_preset_pause(false)
	if is_instance_valid(_agent_action_panel):
		_agent_action_panel.visible = is_agent
	if is_instance_valid(_btn_ability_1):
		_btn_ability_1.visible = is_agent
	if is_instance_valid(_btn_ability_2):
		_btn_ability_2.visible = is_agent
	if is_instance_valid(_btn_ability_3):
		_btn_ability_3.visible = is_agent
	if is_instance_valid(_btn_ult):
		_btn_ult.visible = is_agent
	if is_instance_valid(_btn_throw):
		_btn_throw.visible = is_agent
	if is_agent and local_player != null:
		var ag: Dictionary = AgentData.get_agent(int(local_player.get("archetype_id")))
		var bw: Dictionary = ag["base_weapon"]
		_weapon_name_label.text = "%s (%s)" % [str(bw["name"]), str(ag["agent_name"])]
		_ammo_label.text = "∞ BASE WEAPON"
		_ammo_label.modulate = Color(0.45, 0.96, 1.0)
		_dual_badge.visible = false
	elif is_instance_valid(_stun_banner):
		_stun_banner.visible = false


func _clamp_control_pos(center_px: Vector2, ctrl_size: Vector2, vp_size: Vector2) -> Vector2:
	return Vector2(
		clampf(center_px.x - ctrl_size.x * 0.5, 10.0, maxf(10.0, vp_size.x - ctrl_size.x - 10.0)),
		clampf(center_px.y - ctrl_size.y * 0.5, 10.0, maxf(10.0, vp_size.y - ctrl_size.y - 10.0))
	)


func _update_stick_and_button_positions() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_left_center = SettingsManager.get_touch_element_px("left_stick", vp_size)
	_left_center.x = clampf(_left_center.x, STICK_RADIUS + 14.0, maxf(STICK_RADIUS + 14.0, vp_size.x - STICK_RADIUS - 14.0))
	_left_center.y = clampf(_left_center.y, STICK_RADIUS + 14.0, maxf(STICK_RADIUS + 14.0, vp_size.y - STICK_RADIUS - 14.0))
	_right_center = SettingsManager.get_touch_element_px("right_stick", vp_size)
	_right_center.x = clampf(_right_center.x, STICK_RADIUS + 14.0, maxf(STICK_RADIUS + 14.0, vp_size.x - STICK_RADIUS - 14.0))
	_right_center.y = clampf(_right_center.y, STICK_RADIUS + 14.0, maxf(STICK_RADIUS + 14.0, vp_size.y - STICK_RADIUS - 14.0))
	if is_instance_valid(_btn_reload):
		_btn_reload.position = _clamp_control_pos(SettingsManager.get_touch_element_px("btn_reload", vp_size), _btn_reload.size, vp_size)
	if is_instance_valid(_btn_switch):
		_btn_switch.position = _clamp_control_pos(SettingsManager.get_touch_element_px("btn_switch", vp_size), _btn_switch.size, vp_size)
	if is_instance_valid(_btn_dual):
		_btn_dual.position = _clamp_control_pos(SettingsManager.get_touch_element_px("btn_dual", vp_size), _btn_dual.size, vp_size)
	if is_instance_valid(_btn_bomb):
		_btn_bomb.position = _clamp_control_pos(SettingsManager.get_touch_element_px("btn_bomb", vp_size), _btn_bomb.size, vp_size)
	if is_instance_valid(_btn_pickup) and is_instance_valid(_btn_switch):
		var sw_pos: Vector2 = _btn_switch.position
		_btn_pickup.position = _clamp_control_pos(Vector2(sw_pos.x + _btn_switch.size.x * 0.5, sw_pos.y - 48.0), _btn_pickup.size, vp_size)
	if is_instance_valid(_btn_interact) and is_instance_valid(_btn_reload):
		var rld_pos: Vector2 = _btn_reload.position
		_btn_interact.position = _clamp_control_pos(Vector2(rld_pos.x + _btn_reload.size.x * 0.5, rld_pos.y - 48.0), _btn_interact.size, vp_size)
	if is_instance_valid(_agent_action_panel):
		_agent_action_panel.position = _clamp_control_pos(SettingsManager.get_touch_element_px("ability_bar", vp_size), _agent_action_panel.size, vp_size)
	if is_instance_valid(_stick_canvas):
		_stick_canvas.queue_redraw()
	if is_instance_valid(_layout_overlay) and _layout_overlay.visible:
		_position_hud_layout_handles()


func _input(event: InputEvent) -> void:
	if is_instance_valid(_layout_overlay) and _layout_overlay.visible:
		if not _dragging_key.is_empty():
			if event is InputEventMouseMotion:
				_move_hud_layout_handle(_dragging_key, (event as InputEventMouseMotion).position - _drag_center_offset)
			elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
				_dragging_key = ""
			elif event is InputEventScreenDrag:
				_move_hud_layout_handle(_dragging_key, (event as InputEventScreenDrag).position - _drag_center_offset)
			elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
				_dragging_key = ""
		return

	if is_instance_valid(_preset_overlay) and _preset_overlay.visible:
		return

	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			if _is_over_control(te.position):
				return
			var half_w: float = get_viewport().get_visible_rect().size.x * 0.5
			if te.position.x < half_w and _left_touch_idx == -1:
				_left_touch_idx = te.index
				_update_left_stick(te.position)
			elif te.position.x >= half_w and _right_touch_idx == -1:
				_right_touch_idx = te.index
				_update_right_stick(te.position)
		else:
			if te.index == _left_touch_idx:
				_left_touch_idx = -1
				_left_knob_offset = Vector2.ZERO
				_stick_canvas.queue_redraw()
			elif te.index == _right_touch_idx:
				_right_touch_idx = -1
				_right_knob_offset = Vector2.ZERO
				_stick_canvas.queue_redraw()

	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		if de.index == _left_touch_idx:
			_update_left_stick(de.position)
		elif de.index == _right_touch_idx:
			_update_right_stick(de.position)

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.position.distance_to(_left_center) <= STICK_RADIUS + 18.0:
					_left_mouse_active = true
					_update_left_stick(mb.position)
					get_viewport().set_input_as_handled()
				elif mb.position.distance_to(_right_center) <= STICK_RADIUS + 18.0:
					_right_mouse_active = true
					_update_right_stick(mb.position)
					get_viewport().set_input_as_handled()
			else:
				if _left_mouse_active:
					_left_mouse_active = false
					_left_knob_offset = Vector2.ZERO
					_stick_canvas.queue_redraw()
				if _right_mouse_active:
					_right_mouse_active = false
					_right_knob_offset = Vector2.ZERO
					_stick_canvas.queue_redraw()

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _left_mouse_active:
			_update_left_stick(mm.position)
		if _right_mouse_active:
			_update_right_stick(mm.position)


func _is_over_control(screen_pos: Vector2) -> bool:
	if is_instance_valid(_layout_overlay) and _layout_overlay.visible:
		return true
	if is_instance_valid(_preset_overlay) and _preset_overlay.visible:
		if _preset_overlay.get_global_rect().has_point(screen_pos):
			return true
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered != null and hovered is BaseButton:
		return hovered.get_global_rect().has_point(screen_pos)
	return false


func _update_left_stick(pos: Vector2) -> void:
	var delta_v: Vector2 = pos - _left_center
	if delta_v.length() > STICK_RADIUS:
		delta_v = delta_v.normalized() * STICK_RADIUS
	_left_knob_offset = delta_v
	_stick_canvas.queue_redraw()


func _update_right_stick(pos: Vector2) -> void:
	var delta_v: Vector2 = pos - _right_center
	if delta_v.length() > STICK_RADIUS:
		delta_v = delta_v.normalized() * STICK_RADIUS
	_right_knob_offset = delta_v
	_stick_canvas.queue_redraw()


func _push_input_to_player() -> void:
	if local_player == null or not is_instance_valid(local_player):
		return
	var ui_blocking: bool = (
		(is_instance_valid(_layout_overlay) and _layout_overlay.visible)
		or (is_instance_valid(_preset_overlay) and _preset_overlay.visible)
	)
	if ui_blocking:
		local_player.virtual_move = Vector2.ZERO
		local_player.virtual_jetpack = false
		local_player.virtual_aim = Vector2.ZERO
		local_player.virtual_fire = false
		local_player.pointer_over_ui = true
		return
	var left_norm: Vector2 = _left_knob_offset / STICK_RADIUS
	var right_norm: Vector2 = _right_knob_offset / STICK_RADIUS
	local_player.virtual_move = left_norm
	local_player.virtual_jetpack = (left_norm.y < -0.45)
	local_player.virtual_aim = right_norm * SettingsManager.aim_stick_sensitivity
	local_player.virtual_fire = (right_norm.length() * SettingsManager.aim_stick_sensitivity > 0.52)

	var hovered: Control = get_viewport().gui_get_hovered_control()
	local_player.pointer_over_ui = (hovered != null and hovered != _stick_canvas) or _left_mouse_active or _right_mouse_active


func _on_stick_canvas_draw() -> void:
	var bg_col := Color(0.08, 0.12, 0.18, 0.34)
	var ring_col := Color(1.0, 1.0, 1.0, 0.78)
	var inner_ring := Color(1.0, 1.0, 1.0, 0.35)

	# Left Stick: Mini-Militia style 4-way directional pad
	_stick_canvas.draw_circle(_left_center, STICK_RADIUS, bg_col)
	_stick_canvas.draw_arc(_left_center, STICK_RADIUS, 0.0, TAU, 40, ring_col, 2.5)
	_stick_canvas.draw_arc(_left_center, STICK_RADIUS * 0.62, 0.0, TAU, 32, inner_ring, 1.5)
	var arrow_col := Color(0.78, 0.86, 0.98, 0.65)
	var d_off: float = STICK_RADIUS * 0.42
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p: Vector2 = _left_center + dir * d_off
		var perp := Vector2(-dir.y, dir.x)
		_stick_canvas.draw_colored_polygon(PackedVector2Array([
			p + dir * 8.0, p - dir * 5.0 + perp * 7.0, p - dir * 5.0 - perp * 7.0
		]), arrow_col)
	_stick_canvas.draw_circle(_left_center + _left_knob_offset, KNOB_RADIUS, Color(0.48, 0.62, 0.84, 0.75))
	_stick_canvas.draw_arc(_left_center + _left_knob_offset, KNOB_RADIUS, 0.0, TAU, 24, ring_col, 2.0)

	# Right Stick: Red crosshair target ring
	_stick_canvas.draw_circle(_right_center, STICK_RADIUS, bg_col)
	_stick_canvas.draw_arc(_right_center, STICK_RADIUS, 0.0, TAU, 40, ring_col, 2.5)
	var target_col := Color(0.86, 0.28, 0.24, 0.82)
	_stick_canvas.draw_circle(_right_center, STICK_RADIUS * 0.56, Color(0.86, 0.26, 0.22, 0.22))
	_stick_canvas.draw_arc(_right_center, STICK_RADIUS * 0.56, 0.0, TAU, 32, target_col, 2.5)
	_stick_canvas.draw_line(_right_center - Vector2(22.0, 0.0), _right_center + Vector2(22.0, 0.0), Color(1.0, 1.0, 1.0, 0.85), 2.0)
	_stick_canvas.draw_line(_right_center - Vector2(0.0, 22.0), _right_center + Vector2(0.0, 22.0), Color(1.0, 1.0, 1.0, 0.85), 2.0)
	_stick_canvas.draw_circle(_right_center + _right_knob_offset, KNOB_RADIUS, Color(0.92, 0.32, 0.26, 0.78))
	_stick_canvas.draw_arc(_right_center + _right_knob_offset, KNOB_RADIUS, 0.0, TAU, 24, ring_col, 2.0)


func _on_indicator_overlay_draw() -> void:
	if local_player == null or not is_instance_valid(local_player):
		return
	if local_player.has_method("is_alive") and not local_player.is_alive():
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	var screen_center: Vector2 = vp_size * 0.5
	var c_xform: Transform2D = vp.get_canvas_transform()
	var half_bounds: Vector2 = Vector2(maxf(20.0, screen_center.x - INDICATOR_EDGE_MARGIN), maxf(20.0, screen_center.y - INDICATOR_EDGE_MARGIN))

	for p in get_tree().get_nodes_in_group("players"):
		if p == local_player or not is_instance_valid(p):
			continue
		if p.has_method("is_alive") and not p.is_alive():
			continue
		var world_dist: float = local_player.global_position.distance_to(p.global_position)
		if world_dist > INDICATOR_MAX_RANGE:
			continue
		var sp: Vector2 = c_xform * p.global_position
		if sp.x >= 0.0 and sp.x <= vp_size.x and sp.y >= 0.0 and sp.y <= vp_size.y:
			continue

		var dir: Vector2 = sp - screen_center
		if dir.length_squared() < 0.01:
			continue
		var sx: float = half_bounds.x / maxf(0.001, absf(dir.x))
		var sy: float = half_bounds.y / maxf(0.001, absf(dir.y))
		var edge_pos: Vector2 = screen_center + dir * minf(sx, sy)
		var ang: float = dir.angle()

		var base_col: Color = NetworkManager.get_team_color(int(p.get("color_index")))
		if NetworkManager.is_team_mode() and int(p.get("team_id")) == int(local_player.get("team_id")):
			base_col = Color(0.28, 0.90, 0.52)
		var alpha: float = lerpf(0.95, 0.45, clampf(world_dist / INDICATOR_MAX_RANGE, 0.0, 1.0))
		var col := Color(base_col.r, base_col.g, base_col.b, alpha)

		_indicator_overlay.draw_circle(edge_pos, 14.0, Color(0.05, 0.08, 0.12, alpha * 0.65))
		_indicator_overlay.draw_set_transform(edge_pos, ang, Vector2.ONE)
		var arrow_pts := PackedVector2Array([
			Vector2(14.0, 0.0),
			Vector2(-7.0, -9.0),
			Vector2(-3.0, 0.0),
			Vector2(-7.0, 9.0)
		])
		_indicator_overlay.draw_colored_polygon(arrow_pts, col)
		_indicator_overlay.draw_polyline(PackedVector2Array([
			Vector2(14.0, 0.0), Vector2(-7.0, -9.0), Vector2(-7.0, 9.0), Vector2(14.0, 0.0)
		]), Color(1.0, 1.0, 1.0, alpha * 0.8), 1.5)
		_indicator_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _variant_for_color(col: Color) -> String:
	if col.r > 0.82 and col.g < 0.45 and col.b < 0.45:
		return "red"
	if col.r > 0.82 and col.g > 0.72 and col.b < 0.45:
		return "gold"
	if col.r > 0.82 and col.g > 0.40:
		return "orange"
	if col.g > 0.75 and col.r < 0.50:
		return "green"
	if col.b > 0.82 and col.r > 0.60:
		return "purple"
	if col.b > 0.85 and col.g > 0.80:
		return "sky"
	return "blue"


func _make_panel_style(bg: Color, border: Color) -> StyleBox:
	var variant: String = _variant_for_color(border)
	return UIStyle.make_card_stylebox(variant, Color(maxf(bg.r + 0.14, 0.20), maxf(bg.g + 0.14, 0.22), maxf(bg.b + 0.14, 0.28), maxf(bg.a, 0.92)), 12, 10)


func _on_scope_overlay_draw() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = vp_size * 0.5
	var radius: float = minf(vp_size.x, vp_size.y) * 0.44
	var vig_col := Color(0.02, 0.04, 0.03, 0.42)
	var line_col := Color(0.18, 0.92, 0.48, 0.52)

	# Peripheral scope bars (leave clean center aperture visible for 2D combat)
	var bar_w: float = maxf(0.0, center.x - radius)
	var bar_h: float = maxf(0.0, center.y - radius)
	if bar_w > 0.0:
		_scope_overlay.draw_rect(Rect2(0.0, 0.0, bar_w, vp_size.y), vig_col)
		_scope_overlay.draw_rect(Rect2(vp_size.x - bar_w, 0.0, bar_w, vp_size.y), vig_col)
	if bar_h > 0.0:
		_scope_overlay.draw_rect(Rect2(bar_w, 0.0, vp_size.x - bar_w * 2.0, bar_h), vig_col)
		_scope_overlay.draw_rect(Rect2(bar_w, vp_size.y - bar_h, vp_size.x - bar_w * 2.0, bar_h), vig_col)

	_scope_overlay.draw_arc(center, radius, 0.0, TAU, 72, Color(0.05, 0.12, 0.08, 0.85), 6.0)
	_scope_overlay.draw_arc(center, radius - 3.0, 0.0, TAU, 72, line_col, 1.5)

	# Subtle tactical reticle lines & mil-dot ticks
	_scope_overlay.draw_line(Vector2(center.x - radius, center.y), Vector2(center.x - 42.0, center.y), line_col, 1.5)
	_scope_overlay.draw_line(Vector2(center.x + 42.0, center.y), Vector2(center.x + radius, center.y), line_col, 1.5)
	_scope_overlay.draw_line(Vector2(center.x, center.y - radius), Vector2(center.x, center.y - 42.0), line_col, 1.5)
	_scope_overlay.draw_line(Vector2(center.x, center.y + 42.0), Vector2(center.x, center.y + radius), line_col, 1.5)
	for tick in range(-3, 4):
		if tick == 0:
			continue
		var d: float = float(tick) * 48.0
		_scope_overlay.draw_line(Vector2(center.x + d, center.y - 5.0), Vector2(center.x + d, center.y + 5.0), line_col, 1.5)
		_scope_overlay.draw_line(Vector2(center.x - 5.0, center.y + d), Vector2(center.x + 5.0, center.y + d), line_col, 1.5)


func _make_hud_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _style_action_button(btn: Button, _bg: Color, border: Color, font_sz: int = 15) -> void:
	UIStyle.style_layer_button(btn, _variant_for_color(border), "", 12, 8)
	btn.add_theme_font_size_override("font_size", font_sz)


func _style_circle_btn(btn: Button, bg: Color, border: Color, diameter: int, font_sz: int = 12) -> void:
	btn.custom_minimum_size = Vector2(diameter, diameter)
	btn.size = Vector2(diameter, diameter)
	var radius: int = diameter / 2
	for state_name in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.15) if state_name == "hover" else (bg.darkened(0.18) if state_name == "pressed" else bg)
		sb.border_color = border
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(radius)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		btn.add_theme_stylebox_override(state_name, sb)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _make_compact_glass_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.14, 0.64)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.72)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


func _build_ui() -> void:
	_scope_overlay = Control.new()
	_scope_overlay.name = "SniperScopeOverlay"
	_scope_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.visible = false
	_scope_overlay.draw.connect(_on_scope_overlay_draw)
	add_child(_scope_overlay)

	_stick_canvas = Control.new()
	_stick_canvas.name = "VirtualStickOverlay"
	_stick_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_canvas.draw.connect(_on_stick_canvas_draw)
	add_child(_stick_canvas)

	_indicator_overlay = Control.new()
	_indicator_overlay.name = "OffscreenIndicatorOverlay"
	_indicator_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_indicator_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator_overlay.draw.connect(_on_indicator_overlay_draw)
	add_child(_indicator_overlay)

	# Top-Center Compact Mobile Status Bar (Mini-Militia style)
	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.5
	top_bar.anchor_right = 0.5
	top_bar.offset_left = -310
	top_bar.offset_right = 310
	top_bar.offset_top = 8
	top_bar.offset_bottom = 66
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 8)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)

	# Left Compact Pill: HP + Jetpack + Gear/Menu toggle
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(214, 52)
	left_panel.add_theme_stylebox_override("panel", _make_compact_glass_style())
	top_bar.add_child(left_panel)

	var left_h := HBoxContainer.new()
	left_h.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_h)

	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", 4)
	left_h.add_child(lv)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	lv.add_child(hp_row)
	_hp_label = Label.new()
	_hp_label.text = "♥"
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.modulate = Color(1.0, 0.45, 0.82)
	hp_row.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size = Vector2(118, 13)
	_hp_bar.modulate = Color(0.92, 0.24, 0.78)
	hp_row.add_child(_hp_bar)

	var fuel_row := HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 4)
	lv.add_child(fuel_row)
	_fuel_label = Label.new()
	_fuel_label.text = "▲"
	_fuel_label.add_theme_font_size_override("font_size", 11)
	_fuel_label.modulate = Color(0.42, 0.78, 1.0)
	fuel_row.add_child(_fuel_label)

	_fuel_bar = ProgressBar.new()
	_fuel_bar.max_value = 100
	_fuel_bar.value = 100
	_fuel_bar.show_percentage = false
	_fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fuel_bar.custom_minimum_size = Vector2(118, 12)
	_fuel_bar.modulate = Color(0.22, 0.58, 1.0)
	fuel_row.add_child(_fuel_bar)

	var drawer_btn := Button.new()
	drawer_btn.text = "⚙"
	drawer_btn.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(drawer_btn, Color(0.12, 0.16, 0.24, 0.72), Color(1.0, 1.0, 1.0, 0.78), 36, 16)
	left_h.add_child(drawer_btn)

	# Center Pill: Test Bot Toggle (in Test Mode) or Compact Score Pill
	_test_bot_btn = Button.new()
	_test_bot_btn.custom_minimum_size = Vector2(104, 38)
	_test_bot_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(_test_bot_btn, Color(0.08, 0.24, 0.26, 0.94), Color(0.24, 0.86, 0.82), 12)
	_test_bot_btn.visible = NetworkManager.is_test_mode()
	_test_bot_btn.pressed.connect(func():
		NetworkManager.test_bot_behavior = (NetworkManager.test_bot_behavior + 1) % 3
		_refresh_test_bot_btn()
	)
	top_bar.add_child(_test_bot_btn)

	_agent_swap_row = HBoxContainer.new()
	_agent_swap_row.add_theme_constant_override("separation", 4)
	_agent_swap_row.visible = NetworkManager.is_test_mode() and NetworkManager.is_agent_clash_mode()
	top_bar.add_child(_agent_swap_row)

	var prev_ag_btn := Button.new()
	prev_ag_btn.text = "◀"
	prev_ag_btn.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(prev_ag_btn, Color(0.18, 0.12, 0.28, 0.85), Color(0.78, 0.48, 1.0, 0.9), 36, 14)
	prev_ag_btn.pressed.connect(func():
		if local_player != null and local_player.has_method("switch_agent_in_game"):
			local_player.switch_agent_in_game(int(local_player.get("archetype_id")) - 1)
	)
	_agent_swap_row.add_child(prev_ag_btn)

	var next_ag_btn := Button.new()
	next_ag_btn.text = "▶"
	next_ag_btn.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(next_ag_btn, Color(0.18, 0.12, 0.28, 0.85), Color(0.78, 0.48, 1.0, 0.9), 36, 14)
	next_ag_btn.pressed.connect(func():
		if local_player != null and local_player.has_method("switch_agent_in_game"):
			local_player.switch_agent_in_game(int(local_player.get("archetype_id")) + 1)
	)
	_agent_swap_row.add_child(next_ag_btn)

	# Right Compact Pill: Weapon Icon + Ammo + Dual Badge
	var weapon_panel := PanelContainer.new()
	weapon_panel.custom_minimum_size = Vector2(214, 52)
	weapon_panel.add_theme_stylebox_override("panel", _make_compact_glass_style())
	top_bar.add_child(weapon_panel)

	var w_row := HBoxContainer.new()
	w_row.add_theme_constant_override("separation", 8)
	weapon_panel.add_child(w_row)

	var atlas := AtlasTexture.new()
	atlas.atlas = WEAPONS_TEX
	atlas.region = Rect2(0, 0, 64, 32)
	_weapon_icon = TextureRect.new()
	_weapon_icon.texture = atlas
	_weapon_icon.custom_minimum_size = Vector2(54, 26)
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	w_row.add_child(_weapon_icon)

	var w_info := VBoxContainer.new()
	w_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_info.alignment = BoxContainer.ALIGNMENT_CENTER
	w_info.add_theme_constant_override("separation", 0)
	w_row.add_child(w_info)

	_weapon_name_label = Label.new()
	_weapon_name_label.text = "AK47"
	_weapon_name_label.add_theme_font_size_override("font_size", 12)
	w_info.add_child(_weapon_name_label)

	_ammo_label = Label.new()
	_ammo_label.text = "30 / 30"
	_ammo_label.add_theme_font_size_override("font_size", 13)
	_ammo_label.modulate = Color(1.0, 0.88, 0.4)
	w_info.add_child(_ammo_label)

	_dual_badge = Label.new()
	_dual_badge.text = "DUAL"
	_dual_badge.add_theme_font_size_override("font_size", 11)
	_dual_badge.modulate = Color(0.25, 0.95, 1.0)
	_dual_badge.visible = false
	w_row.add_child(_dual_badge)

	# Circular Translucent Touch Action Buttons (positioned via SettingsManager.touch_layout)
	_btn_reload = Button.new()
	_btn_reload.text = "RLD"
	_btn_reload.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_reload, Color(0.10, 0.16, 0.26, 0.56), Color(1.0, 1.0, 1.0, 0.82), 62, 12)
	_btn_reload.pressed.connect(func():
		if local_player != null:
			local_player.start_reload()
	)
	add_child(_btn_reload)

	_btn_switch = Button.new()
	_btn_switch.text = "SWAP"
	_btn_switch.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_switch, Color(0.20, 0.16, 0.08, 0.56), Color(1.0, 1.0, 1.0, 0.82), 62, 12)
	_btn_switch.pressed.connect(func():
		if local_player != null:
			local_player.cycle_weapon()
	)
	add_child(_btn_switch)

	_btn_dual = Button.new()
	_btn_dual.text = "DUAL"
	_btn_dual.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_dual, Color(0.08, 0.22, 0.26, 0.56), Color(1.0, 1.0, 1.0, 0.82), 60, 12)
	_btn_dual.pressed.connect(func():
		if local_player != null:
			local_player.toggle_dual_wield()
	)
	add_child(_btn_dual)

	_btn_bomb = Button.new()
	_btn_bomb.text = "FRAG\nx3"
	_btn_bomb.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_bomb, Color(0.22, 0.12, 0.08, 0.58), Color(1.0, 1.0, 1.0, 0.88), 72, 12)
	_btn_bomb.pressed.connect(func():
		if local_player != null and local_player.has_method("throw_bomb"):
			local_player.throw_bomb()
	)
	add_child(_btn_bomb)

	_btn_presets = Button.new()
	_btn_presets.text = "KIT"
	_btn_presets.offset_left = 82
	_btn_presets.offset_top = 14
	_btn_presets.offset_right = 138
	_btn_presets.offset_bottom = 70
	_btn_presets.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_presets, Color(0.14, 0.16, 0.22, 0.65), Color(1.0, 1.0, 1.0, 0.85), 56, 13)
	_btn_presets.pressed.connect(func(): _open_preset_selector(PRESET_SELECT_DURATION))
	add_child(_btn_presets)

	_btn_zoom = Button.new()
	_btn_zoom.text = "1x\n/2x"
	_btn_zoom.offset_left = 14
	_btn_zoom.offset_top = 12
	_btn_zoom.offset_right = 74
	_btn_zoom.offset_bottom = 72
	_btn_zoom.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_zoom, Color(0.10, 0.14, 0.20, 0.65), Color(1.0, 1.0, 1.0, 0.88), 60, 13)
	_btn_zoom.pressed.connect(func():
		if local_player != null and local_player.has_method("cycle_zoom"):
			local_player.cycle_zoom()
	)
	add_child(_btn_zoom)

	_btn_shoe = Button.new()
	_btn_shoe.text = "👟"
	_btn_shoe.offset_left = 16
	_btn_shoe.offset_top = 80
	_btn_shoe.offset_right = 72
	_btn_shoe.offset_bottom = 136
	_btn_shoe.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_shoe, Color(0.20, 0.14, 0.10, 0.65), Color(1.0, 1.0, 1.0, 0.85), 56, 16)
	_btn_shoe.pressed.connect(func():
		if local_player != null and local_player.has_method("throw_shoe"):
			local_player.throw_shoe()
	)
	add_child(_btn_shoe)

	_btn_pickup = Button.new()
	_btn_pickup.text = "PICK\nGUN"
	_btn_pickup.focus_mode = Control.FOCUS_NONE
	_btn_pickup.visible = false
	_style_circle_btn(_btn_pickup, Color(0.10, 0.36, 0.22, 0.88), Color(0.45, 1.0, 0.65, 0.95), 74, 12)
	_btn_pickup.pressed.connect(func():
		if _nearby_crate_idx >= 0:
			pickup_weapon_requested.emit(_nearby_crate_idx)
	)
	add_child(_btn_pickup)

	_btn_interact = Button.new()
	_btn_interact.text = "USE\nFAN"
	_btn_interact.focus_mode = Control.FOCUS_NONE
	_btn_interact.visible = false
	_style_circle_btn(_btn_interact, Color(0.14, 0.28, 0.44, 0.90), Color(0.42, 0.85, 1.0, 0.95), 74, 12)
	_btn_interact.pressed.connect(func():
		if _nearby_inter_idx >= 0:
			interact_requested.emit(_nearby_inter_idx)
	)
	add_child(_btn_interact)

	_btn_throw_prop = Button.new()
	_btn_throw_prop.text = "THROW\nPROP"
	_btn_throw_prop.offset_left = 14
	_btn_throw_prop.offset_top = 144
	_btn_throw_prop.offset_right = 84
	_btn_throw_prop.offset_bottom = 214
	_btn_throw_prop.focus_mode = Control.FOCUS_NONE
	_btn_throw_prop.visible = false
	_style_circle_btn(_btn_throw_prop, Color(0.45, 0.24, 0.10, 0.90), Color(1.0, 0.78, 0.36, 0.95), 70, 12)
	_btn_throw_prop.pressed.connect(func():
		if local_player != null and local_player.has_method("throw_held_prop"):
			local_player.throw_held_prop()
	)
	add_child(_btn_throw_prop)

	# Agent Clash Mode Draggable Ability & Throwable Controls (compact 2x2 grid)
	_agent_action_panel = VBoxContainer.new()
	_agent_action_panel.custom_minimum_size = Vector2(500, 114)
	_agent_action_panel.size = Vector2(500, 114)
	_agent_action_panel.add_theme_constant_override("separation", 6)
	_agent_action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_agent_action_panel)

	var top_agent_row := HBoxContainer.new()
	top_agent_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_agent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_agent_action_panel.add_child(top_agent_row)

	_btn_throw = Button.new()
	_btn_throw.text = "THROW SHOE"
	_btn_throw.custom_minimum_size = Vector2(220, 34)
	_btn_throw.focus_mode = Control.FOCUS_NONE
	_style_action_button(_btn_throw, Color(0.16, 0.22, 0.14, 0.92), Color(0.95, 0.80, 0.28, 0.95), 14)
	_btn_throw.pressed.connect(func():
		if local_player != null:
			local_player.throw_held_item()
	)
	top_agent_row.add_child(_btn_throw)

	var ab_row := GridContainer.new()
	ab_row.columns = 2
	ab_row.add_theme_constant_override("h_separation", 8)
	ab_row.add_theme_constant_override("v_separation", 6)
	ab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_agent_action_panel.add_child(ab_row)

	_btn_ability_1 = _create_agent_btn("ABIL 1", Color(0.10, 0.18, 0.30, 0.94), Color(0.38, 0.78, 1.0), 0)
	_btn_ability_2 = _create_agent_btn("ABIL 2", Color(0.10, 0.18, 0.30, 0.94), Color(0.45, 0.95, 0.65), 1)
	_btn_ability_3 = _create_agent_btn("ABIL 3", Color(0.18, 0.14, 0.30, 0.94), Color(0.76, 0.50, 1.0), 2)
	_btn_ult = _create_agent_btn("ULTIMATE", Color(0.32, 0.14, 0.08, 0.96), Color(1.0, 0.72, 0.20), 3)
	ab_row.add_child(_btn_ability_1)
	ab_row.add_child(_btn_ability_2)
	ab_row.add_child(_btn_ability_3)
	ab_row.add_child(_btn_ult)

	_stun_banner = PanelContainer.new()
	_stun_banner.anchor_left = 0.5
	_stun_banner.anchor_right = 0.5
	_stun_banner.offset_left = -130
	_stun_banner.offset_right = 130
	_stun_banner.offset_top = 18
	_stun_banner.offset_bottom = 60
	_stun_banner.visible = false
	_stun_banner.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.20, 0.32, 0.94), Color(0.38, 0.94, 1.0, 0.98)))
	add_child(_stun_banner)

	_stun_label = Label.new()
	_stun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stun_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stun_label.add_theme_font_size_override("font_size", 18)
	_stun_label.modulate = Color(0.55, 0.96, 1.0)
	_stun_label.text = "⚡ STUNNED!"
	_stun_banner.add_child(_stun_label)

	_sync_mode_hud_visibility()

	# Top-Right WiFi Chat Bar (with quick tease emojis)
	_chat_toggle_btn = Button.new()
	_chat_toggle_btn.text = "💬 CHAT"
	_chat_toggle_btn.focus_mode = Control.FOCUS_NONE
	_chat_toggle_btn.anchor_left = 1.0
	_chat_toggle_btn.anchor_right = 1.0
	_chat_toggle_btn.offset_left = -124
	_chat_toggle_btn.offset_right = -12
	_chat_toggle_btn.offset_top = 8
	_chat_toggle_btn.offset_bottom = 42
	UIStyle.style_layer_button(_chat_toggle_btn, "blue", "", 12, 5)
	_chat_toggle_btn.add_theme_font_size_override("font_size", 14)
	add_child(_chat_toggle_btn)

	_chat_panel = PanelContainer.new()
	_chat_panel.anchor_left = 1.0
	_chat_panel.anchor_right = 1.0
	_chat_panel.offset_left = -430
	_chat_panel.offset_right = -12
	_chat_panel.offset_top = 46
	_chat_panel.offset_bottom = 300
	_chat_panel.visible = false
	_chat_panel.add_theme_stylebox_override("panel", UIStyle.make_card_stylebox("blue", Color(0.08, 0.12, 0.18, 0.94), 12, 10))
	add_child(_chat_panel)

	var chat_vbox := VBoxContainer.new()
	chat_vbox.add_theme_constant_override("separation", 6)
	_chat_panel.add_child(chat_vbox)

	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.custom_minimum_size = Vector2(390, 140)
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_font_size_override("normal_font_size", 15)
	chat_vbox.add_child(_chat_log)

	var emoji_row := HBoxContainer.new()
	emoji_row.add_theme_constant_override("separation", 6)
	chat_vbox.add_child(emoji_row)
	for em in ["😜", "😂", "💨", "🖕", "❓"]:
		var eb := Button.new()
		eb.text = em
		eb.focus_mode = Control.FOCUS_NONE
		eb.custom_minimum_size = Vector2(68, 36)
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyle.style_layer_button(eb, "blue", "", 8, 5)
		eb.add_theme_font_size_override("font_size", 18)
		eb.pressed.connect(_send_tease_emoji.bind(em))
		emoji_row.add_child(eb)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	chat_vbox.add_child(input_row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "WiFi Chat..."
	_chat_input.custom_minimum_size = Vector2(0, 36)
	_chat_input.add_theme_font_size_override("font_size", 15)
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.max_length = 80
	_chat_input.text_submitted.connect(func(_t: String): _send_chat_text())
	input_row.add_child(_chat_input)
	var send_btn := Button.new()
	send_btn.text = "SEND"
	send_btn.custom_minimum_size = Vector2(76, 36)
	send_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(send_btn, "green", "", 12, 5)
	send_btn.add_theme_font_size_override("font_size", 14)
	send_btn.pressed.connect(_send_chat_text)
	input_row.add_child(send_btn)

	_chat_toggle_btn.pressed.connect(func():
		_chat_panel.visible = not _chat_panel.visible
		if _chat_panel.visible:
			_chat_toggle_btn.text = "💬 CHAT"
		if is_instance_valid(_chat_toast_label):
			_chat_toast_label.visible = (not _chat_panel.visible) and (not _chat_toast_items.is_empty())
		if is_instance_valid(_killfeed_label):
			_killfeed_label.offset_top = 308 if _chat_panel.visible else 138
			_killfeed_label.offset_bottom = _killfeed_label.offset_top + 100
	)

	# Floating borderless chat lines under CHAT button (no box, fades away)
	_chat_toast_label = RichTextLabel.new()
	_chat_toast_label.bbcode_enabled = true
	_chat_toast_label.fit_content = true
	_chat_toast_label.scroll_active = false
	_chat_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_toast_label.anchor_left = 1.0
	_chat_toast_label.anchor_right = 1.0
	_chat_toast_label.offset_left = -360
	_chat_toast_label.offset_right = -12
	_chat_toast_label.offset_top = 48
	_chat_toast_label.offset_bottom = 136
	_chat_toast_label.add_theme_font_size_override("normal_font_size", 14)
	_chat_toast_label.add_theme_constant_override("outline_size", 3)
	_chat_toast_label.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.10, 0.95))
	_chat_toast_label.visible = false
	add_child(_chat_toast_label)

	# Floating Killfeed (top-right, below chat bar, highlighted for local kills/deaths)
	_killfeed_label = RichTextLabel.new()
	_killfeed_label.bbcode_enabled = true
	_killfeed_label.fit_content = true
	_killfeed_label.scroll_active = false
	_killfeed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_killfeed_label.anchor_left = 1.0
	_killfeed_label.anchor_right = 1.0
	_killfeed_label.offset_left = -300
	_killfeed_label.offset_right = -12
	_killfeed_label.offset_top = 42
	_killfeed_label.offset_bottom = 142
	_killfeed_label.add_theme_font_size_override("normal_font_size", 13)
	add_child(_killfeed_label)

	_diag_label = Label.new()
	_diag_label.anchor_top = 1.0
	_diag_label.anchor_bottom = 1.0
	_diag_label.offset_left = 12
	_diag_label.offset_right = 220
	_diag_label.offset_top = -28
	_diag_label.offset_bottom = -6
	_diag_label.add_theme_font_size_override("font_size", 12)
	_diag_label.modulate = Color(0.45, 0.95, 0.62, 0.85)
	_diag_label.visible = SettingsManager.show_diagnostics
	add_child(_diag_label)

	# Collapsible Scoreboard & Match Menu Drawer (opened via ⚙ button)
	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 0.5
	right_panel.anchor_right = 0.5
	right_panel.offset_left = -180
	right_panel.offset_right = 180
	right_panel.offset_top = 72
	right_panel.offset_bottom = 260
	right_panel.custom_minimum_size = Vector2(360, 0)
	right_panel.visible = false
	right_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.14, 0.92), Color(0.95, 0.55, 0.15, 0.88)))
	add_child(right_panel)
	drawer_btn.pressed.connect(func(): right_panel.visible = not right_panel.visible)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	right_panel.add_child(rv)

	_net_status_label = Label.new()
	_net_status_label.text = "NAMELESS CLASH"
	_net_status_label.add_theme_font_size_override("font_size", 13)
	_net_status_label.clip_text = true
	_net_status_label.modulate = Color(1.0, 0.78, 0.25)
	rv.add_child(_net_status_label)

	_map_mode_label = Label.new()
	_map_mode_label.text = "Bunker Base • Solo"
	_map_mode_label.add_theme_font_size_override("font_size", 12)
	_map_mode_label.clip_text = true
	_map_mode_label.modulate = Color(0.82, 0.92, 0.72)
	rv.add_child(_map_mode_label)

	_scoreboard_label = Label.new()
	_scoreboard_label.text = "Loading..."
	_scoreboard_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_scoreboard_label.add_theme_font_size_override("font_size", 12)
	rv.add_child(_scoreboard_label)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 6)
	rv.add_child(nav_row)

	_rem_bot_btn = Button.new()
	_rem_bot_btn.text = "- BOT"
	_rem_bot_btn.custom_minimum_size = Vector2(68, 36)
	_rem_bot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rem_bot_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(_rem_bot_btn, Color(0.26, 0.14, 0.14, 0.94), Color(0.95, 0.42, 0.36), 12)
	_rem_bot_btn.visible = not NetworkManager.is_network_active() or NetworkManager.is_host_active()
	_rem_bot_btn.pressed.connect(func(): remove_bot_requested.emit())
	nav_row.add_child(_rem_bot_btn)

	_add_bot_btn = Button.new()
	_add_bot_btn.text = "+ BOT"
	_add_bot_btn.custom_minimum_size = Vector2(88, 36)
	_add_bot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_bot_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(_add_bot_btn, Color(0.10, 0.26, 0.16, 0.94), Color(0.32, 0.92, 0.48), 12)
	_add_bot_btn.visible = not NetworkManager.is_network_active() or NetworkManager.is_host_active()
	_add_bot_btn.pressed.connect(func(): add_bot_requested.emit())
	nav_row.add_child(_add_bot_btn)
	_refresh_test_bot_btn()

	var layout_btn := Button.new()
	layout_btn.text = "LAYOUT"
	layout_btn.custom_minimum_size = Vector2(78, 36)
	layout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(layout_btn, Color(0.24, 0.18, 0.06, 0.94), Color(1.0, 0.78, 0.24), 12)
	layout_btn.pressed.connect(_open_hud_layout_editor)
	nav_row.add_child(layout_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.custom_minimum_size = Vector2(72, 36)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(menu_btn, Color(0.24, 0.12, 0.14, 0.94), Color(0.95, 0.42, 0.36), 12)
	menu_btn.pressed.connect(func(): NetworkManager.go_to_main_menu())
	nav_row.add_child(menu_btn)

	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 6)
	rv.add_child(audio_row)

	var music_btn := Button.new()
	music_btn.custom_minimum_size = Vector2(0, 36)
	music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_btn.focus_mode = Control.FOCUS_NONE
	var sync_music_btn := func():
		music_btn.text = "MUSIC: ON" if SettingsManager.music_enabled else "MUSIC: MUTED"
		_style_action_button(music_btn, Color(0.10, 0.24, 0.34, 0.94), Color(0.35, 0.85, 1.0) if SettingsManager.music_enabled else Color(0.65, 0.35, 0.35), 12)
	sync_music_btn.call()
	music_btn.pressed.connect(func():
		SettingsManager.music_enabled = not SettingsManager.music_enabled
		SettingsManager.apply_and_save()
		sync_music_btn.call()
	)
	audio_row.add_child(music_btn)

	var sfx_btn := Button.new()
	sfx_btn.custom_minimum_size = Vector2(0, 36)
	sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_btn.focus_mode = Control.FOCUS_NONE
	var sync_sfx_btn := func():
		sfx_btn.text = "SFX: ON" if SettingsManager.sfx_enabled else "SFX: MUTED"
		_style_action_button(sfx_btn, Color(0.10, 0.26, 0.18, 0.94), Color(0.35, 0.92, 0.55) if SettingsManager.sfx_enabled else Color(0.65, 0.35, 0.35), 12)
	sync_sfx_btn.call()
	sfx_btn.pressed.connect(func():
		SettingsManager.sfx_enabled = not SettingsManager.sfx_enabled
		SettingsManager.apply_and_save()
		sync_sfx_btn.call()
	)
	audio_row.add_child(sfx_btn)

	# Respawn Center Banner
	_respawn_panel = PanelContainer.new()
	_respawn_panel.anchor_left = 0.5
	_respawn_panel.anchor_right = 0.5
	_respawn_panel.anchor_top = 0.5
	_respawn_panel.anchor_bottom = 0.5
	_respawn_panel.offset_left = -160
	_respawn_panel.offset_right = 160
	_respawn_panel.offset_top = -34
	_respawn_panel.offset_bottom = 34
	_respawn_panel.visible = false
	_respawn_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.14, 0.04, 0.05, 0.92), Color(1.0, 0.3, 0.25, 0.95)))
	add_child(_respawn_panel)

	_respawn_label = Label.new()
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_respawn_label.text = "KIA - RESPAWNING IN 3.0s"
	_respawn_panel.add_child(_respawn_label)
	_build_preset_overlay()
	_build_hud_layout_overlay()


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "♥%d" % current


func _on_fuel_changed(current: float, maximum: float) -> void:
	_fuel_bar.max_value = maximum
	if NetworkManager.unlimited_jetpack:
		_fuel_bar.value = maximum
		_fuel_label.text = "▲∞"
	else:
		_fuel_bar.value = current
		_fuel_label.text = "▲%d" % int(round(current))


func _on_ammo_changed(current: int, mag_size: int, is_reloading: bool) -> void:
	if NetworkManager.is_agent_clash_mode():
		_ammo_label.text = "∞ BASE WEAPON"
		_ammo_label.modulate = Color(0.45, 0.96, 1.0)
		return
	if is_reloading:
		if _active_weapon != null and _active_weapon.single_shell_reload:
			_ammo_label.text = "LOADING SHELL (%d/%d)" % [current, mag_size]
		else:
			_ammo_label.text = "RELOADING..."
		_ammo_label.modulate = Color(1.0, 0.45, 0.25)
	else:
		if _active_weapon != null and _active_weapon.unlimited_reserve:
			_ammo_label.text = "%d / ∞" % current
		else:
			_ammo_label.text = "%d / %d" % [current, mag_size]
		_ammo_label.modulate = Color(1.0, 0.88, 0.4)


func _on_weapon_changed(weapon_data: WeaponData, dual_wield: bool) -> void:
	_active_weapon = weapon_data
	if NetworkManager.is_agent_clash_mode() and local_player != null:
		var ag: Dictionary = AgentData.get_agent(int(local_player.get("archetype_id")))
		var bw: Dictionary = ag["base_weapon"]
		_weapon_name_label.text = "%s (%s)" % [str(bw["name"]), str(ag["agent_name"])]
		_dual_badge.visible = false
		return
	_weapon_name_label.text = weapon_data.display_name
	_dual_badge.visible = dual_wield and weapon_data.supports_dual_wield
	var atlas: AtlasTexture = _weapon_icon.texture as AtlasTexture
	var skin_row: int = local_player.weapon_skin_id if local_player != null else 0
	if atlas != null:
		atlas.region = Rect2(weapon_data.sprite_frame * 64, skin_row * 32, 64, 32)


func _on_player_died(seconds_left: float) -> void:
	_respawn_panel.visible = true
	_respawn_label.text = "ELIMINATED - RESPAWNING IN %.1fs" % seconds_left


func _on_player_respawned() -> void:
	_respawn_panel.visible = false
	if not NetworkManager.is_agent_clash_mode():
		if _chosen_preset_idx >= 0 and local_player != null and local_player.has_method("apply_gun_preset"):
			local_player.apply_gun_preset(_chosen_preset_idx)
		if not _chosen_bomb_type.is_empty() and local_player != null and local_player.has_method("set_bomb_type"):
			local_player.set_bomb_type(_chosen_bomb_type)
		_open_preset_selector(PRESET_SELECT_DURATION)


func _on_nearby_weapon_changed(crate_idx: int, w_id: int) -> void:
	_nearby_crate_idx = crate_idx
	if not is_instance_valid(_btn_pickup):
		return
	if crate_idx < 0 or w_id < 0 or NetworkManager.is_agent_clash_mode():
		_btn_pickup.visible = false
		return
	var w_name: String = WeaponData.get_weapon(w_id, 0, 0).display_name
	_btn_pickup.text = "PICK\n%s" % w_name.substr(0, 7).to_upper()
	_btn_pickup.visible = true
	_update_stick_and_button_positions()


func _on_nearby_interactable_changed(inter_idx: int, label_text: String) -> void:
	_nearby_inter_idx = inter_idx
	if not is_instance_valid(_btn_interact):
		return
	if inter_idx < 0 or label_text.is_empty():
		_btn_interact.visible = false
		return
	_btn_interact.text = label_text
	_btn_interact.visible = true
	_update_stick_and_button_positions()


func _on_held_prop_changed(prop_kind: String) -> void:
	if not is_instance_valid(_btn_throw_prop):
		return
	if prop_kind.is_empty():
		_btn_throw_prop.visible = false
	else:
		_btn_throw_prop.text = "THROW\n%s" % prop_kind.replace("_", " ").to_upper().substr(0, 7)
		_btn_throw_prop.visible = true


func _send_chat_text() -> void:
	if not is_instance_valid(_chat_input):
		return
	var txt: String = _chat_input.text.strip_edges()
	if txt.is_empty():
		return
	_chat_input.text = ""
	_chat_input.release_focus()
	NetworkManager.send_chat_message(txt)
	for em in ["😜", "😂", "💨", "🖕", "❓"]:
		if txt.contains(em):
			if local_player != null and local_player.has_method("trigger_taunt"):
				local_player.trigger_taunt()
			break


func _send_tease_emoji(em: String) -> void:
	NetworkManager.send_chat_message(em)
	if local_player != null and local_player.has_method("trigger_taunt"):
		local_player.trigger_taunt()


func _on_chat_message_received(sender_name: String, message: String) -> void:
	var s_esc: String = sender_name.replace("[", "(").replace("]", ")")
	var m_esc: String = message.replace("[", "(").replace("]", ")")
	_chat_lines.append("[color=#70d0ff]%s:[/color] %s" % [s_esc, m_esc])
	if _chat_lines.size() > 16:
		_chat_lines.remove_at(0)
	if is_instance_valid(_chat_log):
		_chat_log.text = "\n".join(_chat_lines)
	_chat_toast_items.append({"text": "[right][color=#70d0ff]%s:[/color] [color=#ffffff]%s[/color][/right]" % [s_esc, m_esc], "ttl": 4.5})
	if _chat_toast_items.size() > 4:
		_chat_toast_items.remove_at(0)
	_render_chat_toasts()


func _tick_chat_toasts(delta: float) -> void:
	if _chat_toast_items.is_empty():
		return
	var changed: bool = false
	for i in range(_chat_toast_items.size() - 1, -1, -1):
		_chat_toast_items[i]["ttl"] = float(_chat_toast_items[i]["ttl"]) - delta
		if float(_chat_toast_items[i]["ttl"]) <= 0.0:
			_chat_toast_items.remove_at(i)
			changed = true
	if changed:
		_render_chat_toasts()
	elif is_instance_valid(_chat_toast_label) and not _chat_toast_items.is_empty():
		var max_ttl: float = 0.0
		for it in _chat_toast_items:
			max_ttl = maxf(max_ttl, float(it["ttl"]))
		_chat_toast_label.modulate.a = clampf(max_ttl, 0.0, 1.0) if max_ttl < 1.0 else 1.0


func _render_chat_toasts() -> void:
	if not is_instance_valid(_chat_toast_label):
		return
	var lines: PackedStringArray = PackedStringArray()
	for it in _chat_toast_items:
		lines.append(str(it["text"]))
	_chat_toast_label.text = "\n".join(lines)
	_chat_toast_label.modulate.a = 1.0
	var show_toasts: bool = (not _chat_toast_items.is_empty()) and (not is_instance_valid(_chat_panel) or not _chat_panel.visible)
	_chat_toast_label.visible = show_toasts


func _on_killfeed_event(killer_name: String, victim_name: String, weapon_name: String) -> void:
	var local_name: String = str(local_player.get("player_name")) if (local_player != null and is_instance_valid(local_player)) else NetworkManager.local_player_name
	var k_esc: String = killer_name.replace("[", "(").replace("]", ")")
	var v_esc: String = victim_name.replace("[", "(").replace("]", ")")
	var w_esc: String = weapon_name.replace("[", "(").replace("]", ")")
	var bb_line: String
	if victim_name == local_name:
		bb_line = "[right][bgcolor=#5e1818][color=#ff7070] ☠ %s (%s) → %s [/color][/bgcolor][/right]" % [k_esc, w_esc, v_esc]
	elif killer_name == local_name:
		bb_line = "[right][bgcolor=#164a22][color=#66ff88] ★ %s (%s) → %s [/color][/bgcolor][/right]" % [k_esc, w_esc, v_esc]
	else:
		bb_line = "[right][color=#d4dce8]%s (%s) → %s[/color][/right]" % [k_esc, w_esc, v_esc]
	_killfeed_lines.append({"text": bb_line, "ttl": 5.5})
	if _killfeed_lines.size() > 4:
		_killfeed_lines.remove_at(0)
	_render_killfeed()


func _tick_killfeed(delta: float) -> void:
	if _killfeed_lines.is_empty():
		return
	var changed: bool = false
	for i in range(_killfeed_lines.size() - 1, -1, -1):
		_killfeed_lines[i]["ttl"] = float(_killfeed_lines[i]["ttl"]) - delta
		if float(_killfeed_lines[i]["ttl"]) <= 0.0:
			_killfeed_lines.remove_at(i)
			changed = true
	if changed:
		_render_killfeed()


func _render_killfeed() -> void:
	var lines: PackedStringArray = PackedStringArray()
	for item in _killfeed_lines:
		lines.append(str(item["text"]))
	_killfeed_label.text = "\n".join(lines)


func _refresh_scoreboard() -> void:
	if NetworkManager.is_host_active():
		_net_status_label.text = "HOSTING LAN (%d players)" % NetworkManager.players.size()
	elif NetworkManager.is_network_active():
		_net_status_label.text = "LAN CLIENT (%d players)" % NetworkManager.players.size()
	else:
		_net_status_label.text = "LOCAL ARENA (%d Bots)" % NetworkManager.bot_count

	_map_mode_label.text = "%s • %s" % [
		NetworkManager.MAP_NAMES[NetworkManager.selected_map_id],
		NetworkManager.MODE_NAMES[NetworkManager.match_mode]
	]

	var rows: PackedStringArray = PackedStringArray()
	var ids: Array = NetworkManager.players.keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = NetworkManager.players[pid]
		var team_tag: String = ""
		if NetworkManager.is_team_mode():
			team_tag = "[BLUE] " if int(p.get("team", 0)) == 0 else "[RED] "
		rows.append("%s%s  |  K:%d  D:%d" % [team_tag, str(p.get("name", "Trooper")), int(p.get("kills", 0)), int(p.get("deaths", 0))])
	_scoreboard_label.text = "\n".join(rows)

	var cur_bots: int = NetworkManager.test_bot_count if NetworkManager.is_test_mode() else NetworkManager.bot_count
	var min_bots: int = 1 if NetworkManager.is_test_mode() else 0
	var can_edit_bots: bool = (not NetworkManager.is_network_active() or NetworkManager.is_host_active())
	if is_instance_valid(_rem_bot_btn):
		_rem_bot_btn.visible = can_edit_bots
		_rem_bot_btn.disabled = cur_bots <= min_bots
	if is_instance_valid(_add_bot_btn):
		_add_bot_btn.visible = can_edit_bots
		var at_cap: bool = cur_bots >= NetworkManager.MAX_BOTS
		_add_bot_btn.disabled = at_cap
		_add_bot_btn.text = ("MAX %d" % NetworkManager.MAX_BOTS) if at_cap else ("+ BOT (%d/%d)" % [cur_bots, NetworkManager.MAX_BOTS])
	_refresh_test_bot_btn()


func _refresh_test_bot_btn() -> void:
	if not is_instance_valid(_test_bot_btn):
		return
	_test_bot_btn.visible = NetworkManager.is_test_mode()
	var idx: int = clampi(NetworkManager.test_bot_behavior, 0, NetworkManager.TEST_BOT_BEHAVIORS.size() - 1)
	_test_bot_btn.text = "BOT: %s" % NetworkManager.TEST_BOT_BEHAVIORS[idx].to_upper()


func _create_agent_btn(title: String, bg: Color, border: Color, slot_idx: int) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.custom_minimum_size = Vector2(234, 36)
	btn.clip_text = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(btn, bg, border, 12)
	btn.pressed.connect(func():
		if local_player != null:
			local_player.use_agent_ability(slot_idx)
	)
	return btn


func _on_agent_state_changed(cooldowns: Array, max_cooldowns: Array, held_throwable: int, stun_left: float) -> void:
	_refresh_agent_hud(cooldowns, max_cooldowns, held_throwable, stun_left)


func _refresh_agent_hud(cooldowns: Array, max_cooldowns: Array, held_throwable: int, stun_left: float) -> void:
	if not NetworkManager.is_agent_clash_mode():
		return
	var arch_id: int = int(local_player.get("archetype_id")) if local_player != null else ProfileManager.archetype_id
	var ag_info: Dictionary = AgentData.get_agent(arch_id)
	var bw_info: Dictionary = ag_info["base_weapon"]
	if is_instance_valid(_weapon_name_label):
		_weapon_name_label.text = "%s (%s)" % [str(bw_info["name"]), str(ag_info["agent_name"])]
	var keys: Array[String] = ["1:", "2:", "3:", "★"]
	var btns: Array[Button] = [_btn_ability_1, _btn_ability_2, _btn_ability_3, _btn_ult]
	for i in range(4):
		var btn: Button = btns[i]
		if not is_instance_valid(btn):
			continue
		var ab: Dictionary = local_player.get_active_ability_slot(i) if (local_player != null and local_player.has_method("get_active_ability_slot")) else AgentData.get_ability_slot(arch_id, i)
		var ab_name: String = str(ab["name"]).left(16)
		var cd: float = float(cooldowns[i]) if i < cooldowns.size() else 0.0
		var max_cd: float = float(max_cooldowns[i]) if i < max_cooldowns.size() else 1.0
		if stun_left > 0.0:
			btn.text = "%s %s • STUN" % [keys[i], ab_name]
			btn.modulate = Color(0.55, 0.65, 0.78)
		elif cd > 0.05:
			btn.text = "%s %s • %.1fs" % [keys[i], ab_name, cd]
			btn.modulate = Color(0.65, 0.68, 0.74)
			var _unused := max_cd
		else:
			btn.text = "%s %s • READY" % [keys[i], ab_name]
			btn.modulate = Color(0.92, 0.82, 0.48) if i == 3 else Color(0.92, 0.94, 0.96)

	if is_instance_valid(_btn_throw):
		if local_player != null and int(local_player.get("grabbed_player_id")) != 0:
			_btn_throw.text = "THROW GRABBED PLAYER!"
			_btn_throw.modulate = Color(1.0, 0.58, 0.22)
		elif held_throwable >= 0:
			var item: Dictionary = AgentData.get_throwable(held_throwable)
			var q_size: int = (local_player.get("held_throwables") as Array).size() if local_player != null else 1
			var count_txt: String = (" (x%d)" % q_size) if q_size > 1 else ""
			_btn_throw.text = "THROW %s%s" % [str(item["name"]).to_upper(), count_txt]
			_btn_throw.modulate = Color(1.0, 0.92, 0.42)
		elif local_player != null and local_player.has_method("find_grabbable_player") and local_player.find_grabbable_player() != null:
			_btn_throw.text = "GRAB ENEMY PLAYER!"
			_btn_throw.modulate = Color(0.42, 0.96, 1.0)
		else:
			var windup_t: float = float(local_player.get("_shoe_windup_timer")) if local_player != null else 0.0
			var shoe_cd: float = float(local_player.get("shoe_cooldown_timer")) if local_player != null else 0.0
			if windup_t > 0.01:
				_btn_throw.text = "TAKING OFF SHOE (%.1fs)" % windup_t
				_btn_throw.modulate = Color(1.0, 0.78, 0.28)
			elif shoe_cd > 0.05:
				_btn_throw.text = "THROW SHOE (%.1fs)" % shoe_cd
				_btn_throw.modulate = Color(0.62, 0.66, 0.72)
			else:
				_btn_throw.text = "THROW SHOE"
				_btn_throw.modulate = Color(0.92, 0.76, 0.48)

	if is_instance_valid(_stun_banner) and is_instance_valid(_stun_label):
		_stun_banner.visible = stun_left > 0.0
		if stun_left > 0.0:
			_stun_label.text = "⚡ STUNNED! %.1fs" % stun_left


func _on_bombs_changed(count: int, bomb_type: String) -> void:
	if not is_instance_valid(_btn_bomb):
		return
	var label_type: String = "FRAG" if bomb_type.is_empty() else bomb_type.to_upper()
	_btn_bomb.text = "%s\nx%d" % [label_type, maxi(0, count)]
	_btn_bomb.visible = (not NetworkManager.is_agent_clash_mode()) and NetworkManager.allow_explosives
	_btn_bomb.modulate = Color.WHITE if count > 0 else Color(0.55, 0.58, 0.65)


func _on_zoom_changed(zoom_level: int, max_zoom: int) -> void:
	if not is_instance_valid(_btn_zoom):
		return
	_btn_zoom.text = "%dx\n/%dx" % [zoom_level, max_zoom]
	_btn_zoom.visible = not NetworkManager.is_agent_clash_mode()
	_btn_zoom.modulate = Color(0.45, 0.92, 1.0) if zoom_level > 1 else Color.WHITE


func _build_preset_overlay() -> void:
	_preset_overlay = PanelContainer.new()
	_preset_overlay.anchor_left = 0.5
	_preset_overlay.anchor_right = 0.5
	_preset_overlay.anchor_top = 0.5
	_preset_overlay.anchor_bottom = 0.5
	_preset_overlay.offset_left = -310
	_preset_overlay.offset_right = 310
	_preset_overlay.offset_top = -215
	_preset_overlay.offset_bottom = 215
	_preset_overlay.visible = false
	_preset_overlay.add_theme_stylebox_override("panel", UIStyle.make_card_stylebox("blue", Color(0.16, 0.22, 0.34, 0.98), 16, 14))
	add_child(_preset_overlay)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	_preset_overlay.add_child(pv)

	var hdr := HBoxContainer.new()
	pv.add_child(hdr)

	_preset_timer_label = Label.new()
	_preset_timer_label.text = "CHOOSE 2-GUN + BOMBS PRESET  (%.1fs)" % PRESET_SELECT_DURATION
	_preset_timer_label.add_theme_font_size_override("font_size", 18)
	_preset_timer_label.modulate = Color(1.0, 0.86, 0.28)
	_preset_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_preset_timer_label)

	var keep_btn := Button.new()
	keep_btn.text = "KEEP DEFAULT"
	keep_btn.custom_minimum_size = Vector2(130, 36)
	keep_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(keep_btn, "sky", "close", 12, 6)
	keep_btn.pressed.connect(func(): _confirm_preset(_chosen_preset_idx if _chosen_preset_idx >= 0 else 0))
	hdr.add_child(keep_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(scroll)

	var list_v := VBoxContainer.new()
	list_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_v.add_theme_constant_override("separation", 8)
	scroll.add_child(list_v)

	_preset_cards.clear()
	for i in range(WeaponData.GUN_PRESETS.size()):
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 74)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.focus_mode = Control.FOCUS_NONE
		var accent: String = str(WeaponData.GUN_PRESETS[i].get("accent", "blue"))
		UIStyle.style_layer_button(card, accent, "", 10, 8)
		card.pressed.connect(_confirm_preset.bind(i))
		list_v.add_child(card)
		_preset_cards.append(card)

		var row_margin := MarginContainer.new()
		row_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		row_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_margin.add_theme_constant_override("margin_left", 12)
		row_margin.add_theme_constant_override("margin_right", 12)
		card.add_child(row_margin)

		var row_h := HBoxContainer.new()
		row_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_h.add_theme_constant_override("separation", 10)
		row_margin.add_child(row_h)

		var title_lbl := Label.new()
		title_lbl.name = "TitleLbl"
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.custom_minimum_size = Vector2(150, 0)
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 13)
		row_h.add_child(title_lbl)

		var pri_icon := TextureRect.new()
		pri_icon.name = "PriIcon"
		pri_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pri_icon.custom_minimum_size = Vector2(58, 30)
		pri_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_h.add_child(pri_icon)

		var pri_lbl := Label.new()
		pri_lbl.name = "PriLbl"
		pri_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pri_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pri_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pri_lbl.add_theme_font_size_override("font_size", 13)
		row_h.add_child(pri_lbl)

		var sec_icon := TextureRect.new()
		sec_icon.name = "SecIcon"
		sec_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sec_icon.custom_minimum_size = Vector2(50, 26)
		sec_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_h.add_child(sec_icon)

		var sec_lbl := Label.new()
		sec_lbl.name = "SecLbl"
		sec_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sec_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sec_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sec_lbl.add_theme_font_size_override("font_size", 13)
		row_h.add_child(sec_lbl)

		var bomb_icon := TextureRect.new()
		bomb_icon.name = "BombIcon"
		bomb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bomb_icon.custom_minimum_size = Vector2(28, 28)
		bomb_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_h.add_child(bomb_icon)

	var bomb_row := HBoxContainer.new()
	bomb_row.add_theme_constant_override("separation", 6)
	pv.add_child(bomb_row)

	var bomb_hdr := Label.new()
	bomb_hdr.text = "BOMB:"
	bomb_hdr.add_theme_font_size_override("font_size", 13)
	bomb_hdr.modulate = Color(1.0, 0.86, 0.35)
	bomb_hdr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bomb_row.add_child(bomb_hdr)

	_bomb_type_buttons.clear()
	var bomb_specs: Array[Dictionary] = [
		{"id": "frag", "label": "Normal (2s)", "accent": "green"},
		{"id": "sticky", "label": "Sticky (3s)", "accent": "blue"},
		{"id": "time", "label": "Time (4s)", "accent": "red"},
		{"id": "mine", "label": "Mine (Prox)", "accent": "orange"}
	]
	for spec in bomb_specs:
		var b_id: String = str(spec["id"])
		var b_btn := Button.new()
		b_btn.text = str(spec["label"])
		b_btn.icon = _make_bomb_icon(b_id)
		b_btn.custom_minimum_size = Vector2(0, 36)
		b_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b_btn.focus_mode = Control.FOCUS_NONE
		UIStyle.style_layer_button(b_btn, str(spec["accent"]), "", 10, 6)
		b_btn.pressed.connect(_select_bomb_type.bind(b_id))
		bomb_row.add_child(b_btn)
		_bomb_type_buttons[b_id] = b_btn

	_refresh_preset_cards()
	_refresh_bomb_type_buttons()


func _select_bomb_type(b_type: String) -> void:
	_chosen_bomb_type = "" if _chosen_bomb_type == b_type else b_type
	_refresh_bomb_type_buttons()


func _refresh_bomb_type_buttons() -> void:
	for b_id in _bomb_type_buttons.keys():
		var btn: Button = _bomb_type_buttons[b_id] as Button
		if not is_instance_valid(btn):
			continue
		var selected: bool = (_chosen_bomb_type == str(b_id))
		btn.modulate = Color(1.25, 1.25, 1.25) if selected else (Color(0.75, 0.78, 0.85) if not _chosen_bomb_type.is_empty() else Color.WHITE)


func _refresh_preset_cards() -> void:
	for i in range(mini(_preset_cards.size(), WeaponData.GUN_PRESETS.size())):
		var card: Button = _preset_cards[i]
		var eff: Dictionary = WeaponData.get_effective_preset(i)
		var p_id: int = int(eff["primary"])
		var s_id: int = int(eff["secondary"])
		var w_pri: WeaponData = WeaponData.get_weapon(p_id, 0, 0)
		var w_sec: WeaponData = WeaponData.get_weapon(s_id, 0, 0)
		var p_name: String = ProfileManager.WEAPON_NAMES[clampi(p_id, 0, ProfileManager.WEAPON_NAMES.size() - 1)]
		var s_name: String = ProfileManager.WEAPON_NAMES[clampi(s_id, 0, ProfileManager.WEAPON_NAMES.size() - 1)]
		var bombs_n: int = int(eff.get("bombs", 0))
		var b_type: String = str(eff.get("bomb_type", "frag"))
		var bomb_txt: String = ("%dx %s" % [bombs_n, b_type.capitalize()]) if bombs_n > 0 else "No Bombs"

		var row_h := card.get_node_or_null("MarginContainer/HBoxContainer")
		if row_h == null and card.get_child_count() > 0:
			row_h = card.get_child(0).get_child(0)
		if row_h != null:
			(row_h.get_node("TitleLbl") as Label).text = "%s\n(%s)" % [str(eff["name"]), bomb_txt]
			(row_h.get_node("PriLbl") as Label).text = p_name
			(row_h.get_node("SecLbl") as Label).text = s_name
			var at_p := AtlasTexture.new()
			at_p.atlas = WEAPONS_TEX
			at_p.region = Rect2(w_pri.sprite_frame * 64, 0, 64, 32)
			(row_h.get_node("PriIcon") as TextureRect).texture = at_p
			var at_s := AtlasTexture.new()
			at_s.atlas = WEAPONS_TEX
			at_s.region = Rect2(w_sec.sprite_frame * 64, 0, 64, 32)
			(row_h.get_node("SecIcon") as TextureRect).texture = at_s
			var b_icon := row_h.get_node("BombIcon") as TextureRect
			b_icon.visible = bombs_n > 0
			b_icon.texture = _make_bomb_icon(b_type)


func _make_bomb_icon(b_type: String) -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color
	match b_type:
		"sticky":
			col = Color(0.28, 0.72, 1.0)
		"time":
			col = Color(1.0, 0.28, 0.22)
		"mine":
			col = Color(1.0, 0.62, 0.18)
		"cluster":
			col = Color(1.0, 0.42, 0.15)
		_:
			col = Color(0.28, 0.92, 0.42)
	for py in range(24):
		for px in range(24):
			var dx: float = float(px) - 12.0
			var dy: float = float(py) - 13.0
			if b_type == "mine":
				if absf(dx) <= 9.0 and dy >= -2.0 and dy <= 5.0:
					img.set_pixel(px, py, col)
				elif dx * dx + (dy + 4.0) * (dy + 4.0) <= 6.0:
					img.set_pixel(px, py, Color(1.0, 0.2, 0.15))
			elif b_type == "time":
				if absf(dx) <= 7.0 and absf(dy) <= 6.0:
					img.set_pixel(px, py, col if (absf(dx) > 5.0 or absf(dy) > 4.0) else Color(0.14, 0.16, 0.20))
				if dx * dx + dy * dy <= 4.0:
					img.set_pixel(px, py, Color(1.0, 0.25, 0.2))
			else:
				if dx * dx + dy * dy <= 49.0:
					img.set_pixel(px, py, col if dx * dx + dy * dy >= 30.0 else Color(0.18, 0.22, 0.20))
				elif absf(dx) <= 2.5 and py >= 3 and py <= 6:
					img.set_pixel(px, py, Color(0.85, 0.85, 0.90))
	return ImageTexture.create_from_image(img)


func _set_preset_pause(paused: bool) -> void:
	if paused:
		_left_touch_idx = -1
		_left_mouse_active = false
		_left_knob_offset = Vector2.ZERO
		_right_touch_idx = -1
		_right_mouse_active = false
		_right_knob_offset = Vector2.ZERO
		if is_instance_valid(_stick_canvas):
			_stick_canvas.queue_redraw()
		if local_player != null and is_instance_valid(local_player):
			local_player.virtual_move = Vector2.ZERO
			local_player.virtual_jetpack = false
			local_player.virtual_aim = Vector2.ZERO
			local_player.virtual_fire = false
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.paused = paused


func _open_preset_selector(duration_s: float = PRESET_SELECT_DURATION) -> void:
	if not is_instance_valid(_preset_overlay):
		return
	if NetworkManager.is_agent_clash_mode():
		_preset_overlay.visible = false
		_set_preset_pause(false)
		return
	_preset_time_left = duration_s
	_refresh_preset_cards()
	_preset_overlay.visible = true
	_set_preset_pause(true)


func _confirm_preset(preset_idx: int) -> void:
	_chosen_preset_idx = clampi(preset_idx, 0, WeaponData.GUN_PRESETS.size() - 1)
	_preset_selection_done = true
	if is_instance_valid(_preset_overlay):
		_preset_overlay.visible = false
	_set_preset_pause(false)
	if local_player != null and local_player.has_method("apply_gun_preset"):
		local_player.apply_gun_preset(_chosen_preset_idx)
	if not _chosen_bomb_type.is_empty() and local_player != null and local_player.has_method("set_bomb_type"):
		local_player.set_bomb_type(_chosen_bomb_type)


func _build_hud_layout_overlay() -> void:
	_layout_overlay = ColorRect.new()
	_layout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout_overlay.color = Color(0.02, 0.04, 0.07, 0.72)
	_layout_overlay.visible = false
	add_child(_layout_overlay)

	var top_bar := PanelContainer.new()
	top_bar.anchor_left = 0.5
	top_bar.anchor_right = 0.5
	top_bar.offset_left = -330
	top_bar.offset_right = 330
	top_bar.offset_top = 12
	top_bar.offset_bottom = 66
	top_bar.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.14, 0.96), Color(1.0, 0.78, 0.24)))
	_layout_overlay.add_child(top_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top_bar.add_child(row)

	var info := Label.new()
	info.text = "DRAG ANY CONTROL TO MOVE IT"
	info.add_theme_font_size_override("font_size", 15)
	info.modulate = Color(1.0, 0.90, 0.45)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var reset_btn := Button.new()
	reset_btn.text = "RESET"
	reset_btn.custom_minimum_size = Vector2(106, 38)
	reset_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(reset_btn, Color(0.24, 0.14, 0.14), Color(0.95, 0.42, 0.35), 14)
	reset_btn.pressed.connect(func():
		SettingsManager.reset_touch_layout()
		_position_hud_layout_handles()
	)
	row.add_child(reset_btn)

	var done_btn := Button.new()
	done_btn.text = "DONE"
	done_btn.custom_minimum_size = Vector2(116, 38)
	done_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(done_btn, Color(0.09, 0.32, 0.16), Color(0.28, 0.92, 0.45), 14)
	done_btn.pressed.connect(func():
		_dragging_key = ""
		_layout_overlay.visible = false
	)
	row.add_child(done_btn)

	var handle_specs: Array[Dictionary] = [
		{"key": "left_stick", "label": "DRAG\nMOVE STICK", "size": Vector2(168, 168), "col": Color(0.25, 0.68, 1.0)},
		{"key": "right_stick", "label": "DRAG\nAIM & FIRE", "size": Vector2(168, 168), "col": Color(1.0, 0.48, 0.22)},
		{"key": "btn_reload", "label": "RELOAD", "size": Vector2(116, 48), "col": Color(0.68, 0.80, 0.98)},
		{"key": "btn_switch", "label": "SWAP GUN", "size": Vector2(116, 48), "col": Color(0.95, 0.76, 0.28)},
		{"key": "btn_bomb", "label": "BOMB", "size": Vector2(116, 48), "col": Color(1.0, 0.56, 0.16)},
		{"key": "btn_dual", "label": "DUAL", "size": Vector2(116, 48), "col": Color(0.28, 0.92, 1.0)},
		{"key": "ability_bar", "label": "DRAG ABILITY BAR (Q / E / C / X)", "size": Vector2(500, 114), "col": Color(0.78, 0.48, 1.0)},
		{"key": "btn_presets", "label": "KIT", "size": Vector2(68, 42), "col": Color(1.0, 0.80, 0.24)}
	]

	_layout_handles.clear()
	for spec in handle_specs:
		var key: String = str(spec["key"])
		var col: Color = spec["col"] as Color
		var btn := Button.new()
		btn.text = str(spec["label"])
		btn.custom_minimum_size = spec["size"]
		btn.size = spec["size"]
		btn.focus_mode = Control.FOCUS_NONE
		_style_action_button(btn, col.darkened(0.55), col, 13)
		btn.modulate = Color(1.0, 1.0, 1.0, 0.86)
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton:
				var mb := ev as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT:
					if mb.pressed:
						_dragging_key = key
						_drag_center_offset = mb.position - btn.size * 0.5
					else:
						_dragging_key = ""
			elif ev is InputEventScreenTouch:
				var st := ev as InputEventScreenTouch
				if st.pressed:
					_dragging_key = key
					_drag_center_offset = st.position - btn.size * 0.5
				else:
					_dragging_key = ""
		)
		_layout_overlay.add_child(btn)
		_layout_handles[key] = btn


func _open_hud_layout_editor() -> void:
	if not is_instance_valid(_layout_overlay):
		return
	_dragging_key = ""
	_layout_overlay.visible = true
	_position_hud_layout_handles()


func _position_hud_layout_handles() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	for key in _layout_handles.keys():
		var ctrl: Control = _layout_handles[key] as Control
		if is_instance_valid(ctrl):
			ctrl.position = _clamp_control_pos(SettingsManager.get_touch_element_px(key, vp_size), ctrl.size, vp_size)


func _move_hud_layout_handle(key: String, center_screen_pos: Vector2) -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var ctrl: Control = _layout_handles.get(key) as Control
	var half_sz: Vector2 = ctrl.size * 0.5 if is_instance_valid(ctrl) else Vector2(58.0, 24.0)
	var clamped_center := Vector2(
		clampf(center_screen_pos.x, half_sz.x + 10.0, maxf(half_sz.x + 10.0, vp_size.x - half_sz.x - 10.0)),
		clampf(center_screen_pos.y, half_sz.y + 10.0, maxf(half_sz.y + 10.0, vp_size.y - half_sz.y - 10.0))
	)
	var norm := Vector2(clamped_center.x / maxf(1.0, vp_size.x), clamped_center.y / maxf(1.0, vp_size.y))
	SettingsManager.set_touch_element_pos(key, norm)
	if is_instance_valid(ctrl):
		ctrl.position = _clamp_control_pos(SettingsManager.get_touch_element_px(key, vp_size), ctrl.size, vp_size)
