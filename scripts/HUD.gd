extends CanvasLayer

signal add_bot_requested
signal remove_bot_requested
signal pickup_weapon_requested(crate_idx: int)
signal interact_requested(inter_idx: int)

const UIStyle = preload("res://scripts/UIStyle.gd")
const WEAPONS_TEX: Texture2D = preload("res://assets/sprites/weapons_sheet.png")
const TEX_FLAMETHROWER: Texture2D = preload("res://assets/sprites/weapons/flamethrower.png")
const TEX_HOOK_GUN: Texture2D = preload("res://assets/sprites/weapons/hook_gun.png")
const TEX_BUBBLE_GUN: Texture2D = preload("res://assets/sprites/weapons/bubble_gun.png")
const TEX_MACHINE_GUN: Texture2D = preload("res://assets/sprites/weapons/machine_gun.png")
const TEX_PLASMA_CANNON: Texture2D = preload("res://assets/sprites/weapons/plasma_cannon.png")
const STICK_RADIUS: float = 94.0
const KNOB_RADIUS: float = 36.0
const AIM_FIRE_THRESHOLD: float = 0.78
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
var _flashbang_overlay: ColorRect
var _active_weapon: WeaponData = null
var _hp_bar: ProgressBar
var _hp_label: Label
var _fuel_bar: ProgressBar
var _fuel_label: Label
var _weapon_icon: TextureRect
var _agent_portrait: TextureRect
var _agent_hat_overlay: TextureRect
var _target_portrait: TextureRect
var _target_hat_overlay: TextureRect
var _secondary_weapon_icon: TextureRect
var _bomb_hud_icon: BombHudIcon
var _bomb_hud_label: Label
var _weapon_name_label: Label
var _ammo_label: Label
var _target_refresh_accum: float = 0.0
var _net_status_label: Label
var _map_mode_label: Label
var _scoreboard_label: Label
var _kad_label: Label
var _killfeed_label: RichTextLabel
var _diag_label: Label
var _match_timer_pill: PanelContainer
var _match_timer_label: Label
var _combo_banner_label: Label
var _match_end_overlay: Control
var _match_end_title: Label
var _match_end_table: VBoxContainer
var _match_end_again_btn: Button
var _match_end_lobby_btn: Button
var _respawn_panel: PanelContainer
var _respawn_label: Label
var _add_bot_btn: Button
var _rem_bot_btn: Button
var _test_bot_btn: Button
var _agent_swap_row: HBoxContainer

var _top_bar_node: Control
var _btn_reload: Button
var _btn_switch: Button
var _btn_bomb: Button
var _btn_presets: Button
var _btn_zoom: Button
var _btn_shoe: Button
var _btn_pickup: Button
var _nearby_crate_idx: int = -1
var _btn_interact: Button
var _nearby_inter_idx: int = -1
var _nearby_pick_inter_idx: int = -1
var _btn_throw_prop: Button

var _chat_toggle_btn: Button
var _chat_panel: PanelContainer
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_lines: Array[String] = []
var _chat_toast_label: RichTextLabel
var _chat_toast_items: Array[Dictionary] = []

var _preset_backdrop: ColorRect
var _preset_overlay: PanelContainer
var _preset_timer_label: Label
var _preset_cards: Array[Button] = []
var _bomb_type_buttons: Dictionary = {}
var _chosen_bomb_type: String = ""
var _preset_time_left: float = 0.0
var _preset_selection_done: bool = false
var _chosen_preset_idx: int = -1

var _btn_ability_1: Button
var _btn_ability_2: Button
var _btn_ability_3: Button
var _btn_ult: Button
var _stun_banner: PanelContainer
var _stun_label: Label

var _layout_overlay: Control
var _drawer_panel: Control
var _layout_handles: Dictionary = {}
var _dragging_key: String = ""
var _drag_center_offset: Vector2 = Vector2.ZERO


const TEX_UI_BUTTON_ICONS: Texture2D = preload("res://assets/sprites/ui/ui_button_icons.png")
const UI_ICON_CELL: float = 128.0


class HudBtnIcon extends Control:
	var kind: String = ""
	var accent: Color = Color.WHITE
	var bomb_type: String = "frag"
	var count: int = 3
	var zoom_level: int = 1
	var max_zoom: int = 2
	var prop_kind: String = "stone"

	func _icon_cell_pos() -> Vector2i:
		match kind:
			"reload":
				return Vector2i(0, 0)
			"swap":
				return Vector2i(1, 0)
			"bomb":
				match bomb_type:
					"time":
						return Vector2i(3, 2)
					"sticky":
						return Vector2i(0, 3)
					"mine":
						return Vector2i(1, 3)
					"cluster":
						return Vector2i(2, 3)
					_:
						return Vector2i(2, 0)
			"throw":
				return Vector2i(3, 0)
			"use":
				return Vector2i(0, 1)
			"pick":
				return Vector2i(1, 1)
			"zoom":
				return Vector2i(2, 1)
			"prop":
				var pk := prop_kind.to_lower()
				if pk.contains("crate") or pk.contains("box"):
					return Vector2i(0, 2)
				elif pk.contains("chair"):
					return Vector2i(1, 2)
				elif pk.contains("barrel"):
					return Vector2i(2, 2)
				else:
					return Vector2i(3, 1)
			"kit":
				return Vector2i(3, 3)
		return Vector2i(-1, -1)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var font: Font = ThemeDB.fallback_font
		var cell := _icon_cell_pos()
		if cell.x >= 0 and TEX_UI_BUTTON_ICONS != null:
			var icon_sz: float = minf(size.x, size.y) * 0.68
			var dst_offset := Vector2(0.0, -3.0) if (kind == "zoom" or kind == "bomb") else Vector2.ZERO
			var dst := Rect2(c - Vector2(icon_sz, icon_sz) * 0.5 + dst_offset, Vector2(icon_sz, icon_sz))
			var src := Rect2(Vector2(cell.x * UI_ICON_CELL, cell.y * UI_ICON_CELL), Vector2(UI_ICON_CELL, UI_ICON_CELL))
			draw_texture_rect_region(TEX_UI_BUTTON_ICONS, dst, src, Color.WHITE)
		if kind == "bomb" and font != null:
			draw_string(font, c + Vector2(6.0, 20.0), "x%d" % maxi(0, count), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		elif kind == "zoom" and font != null:
			var z_txt := "%dx" % zoom_level
			var tsz := font.get_string_size(z_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
			draw_string(font, c + Vector2(-tsz.x * 0.5, 22.0), z_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _attach_btn_icon(btn: Button, kind: String, accent_col: Color) -> HudBtnIcon:
	btn.text = ""
	var ic := HudBtnIcon.new()
	ic.name = "BtnIcon"
	ic.kind = kind
	ic.accent = accent_col
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(ic)
	btn.set_meta("hud_icon", ic)
	return ic


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_flashbang_overlay = ColorRect.new()
	_flashbang_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flashbang_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flashbang_overlay.color = Color(1.0, 1.0, 1.0, 0.0)
	_flashbang_overlay.visible = false
	add_child(_flashbang_overlay)
	move_child(_flashbang_overlay, 0)
	NetworkManager.player_list_updated.connect(_refresh_scoreboard)
	NetworkManager.killfeed_event.connect(_on_killfeed_event)
	NetworkManager.chat_message_received.connect(_on_chat_message_received)
	NetworkManager.match_timer_updated.connect(_on_match_timer_updated)
	NetworkManager.match_ended.connect(_on_match_ended)
	NetworkManager.combo_achieved.connect(_on_combo_achieved)
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
	if NetworkManager.is_agent_clash_mode():
		_target_refresh_accum += delta
		if _target_refresh_accum >= 0.12:
			_target_refresh_accum = 0.0
			_refresh_top_info_pill()
	if is_instance_valid(_flashbang_overlay):
		var fb_t: float = float(local_player.get("flashbang_timer")) if local_player != null else 0.0
		_flashbang_overlay.visible = fb_t > 0.01
		if _flashbang_overlay.visible:
			_flashbang_overlay.color = Color(1.0, 1.0, 1.0, clampf(fb_t * 1.2, 0.0, 1.0))
	if is_instance_valid(_indicator_overlay):
		_indicator_overlay.queue_redraw()
	if is_instance_valid(_diag_label):
		_diag_label.visible = SettingsManager.show_diagnostics
		if _diag_label.visible:
			_diag_label.text = "FPS: %d | PLAYERS: %d" % [Engine.get_frames_per_second(), get_tree().get_nodes_in_group("players").size()]
	if is_instance_valid(_btn_shoe) and _btn_shoe.visible and local_player != null:
		_btn_shoe.text = ""
		var has_held: bool = (not str(local_player.get("held_prop_kind")).is_empty()) or (int(local_player.get("grabbed_player_id")) != 0) or (not (local_player.get("held_throwables") as Array).is_empty())
		var w_t: float = float(local_player.get("_shoe_windup_timer"))
		var cd_t: float = float(local_player.get("shoe_cooldown_timer"))
		if has_held:
			_btn_shoe.modulate = Color(1.0, 0.92, 0.55)
		elif w_t > 0.01:
			_btn_shoe.modulate = Color(1.0, 0.78, 0.28)
		elif cd_t > 0.05:
			_btn_shoe.modulate = Color(0.55, 0.58, 0.65)
		else:
			_btn_shoe.modulate = Color.WHITE

	if is_instance_valid(_preset_overlay) and _preset_overlay.visible:
		_preset_time_left = maxf(0.0, _preset_time_left - delta)
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
	if not NetworkManager.random_guns_mode:
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
		_btn_switch.visible = false
	if is_instance_valid(_btn_bomb):
		_btn_bomb.visible = (not is_agent) and NetworkManager.allow_explosives
	if is_instance_valid(_btn_presets):
		_btn_presets.visible = NetworkManager.is_test_mode() and not is_agent and not NetworkManager.random_guns_mode
	if is_instance_valid(_btn_zoom):
		_btn_zoom.visible = not is_agent
	_refresh_throw_button()
	_refresh_pick_button()
	if (is_agent or NetworkManager.random_guns_mode) and is_instance_valid(_preset_overlay):
		_preset_overlay.visible = false
		_set_preset_pause(false)
	if is_instance_valid(_btn_ability_1):
		_btn_ability_1.visible = is_agent
	if is_instance_valid(_btn_ability_2):
		_btn_ability_2.visible = is_agent
	if is_instance_valid(_btn_ability_3):
		_btn_ability_3.visible = is_agent
	if is_instance_valid(_btn_ult):
		_btn_ult.visible = is_agent
	if is_agent and local_player != null:
		_refresh_top_info_pill()
	elif is_instance_valid(_stun_banner):
		_stun_banner.visible = false
		_refresh_top_info_pill()


func _clamp_control_pos(center_px: Vector2, ctrl_size: Vector2, vp_size: Vector2) -> Vector2:
	return Vector2(
		clampf(center_px.x - ctrl_size.x * 0.5, 10.0, maxf(10.0, vp_size.x - ctrl_size.x - 10.0)),
		clampf(center_px.y - ctrl_size.y * 0.5, 10.0, maxf(10.0, vp_size.y - ctrl_size.y - 10.0))
	)


func _apply_control_layout(ctrl: Control, key: String, vp_size: Vector2) -> void:
	if not is_instance_valid(ctrl):
		return
	var sc: float = SettingsManager.get_touch_element_scale(key)
	var rot_deg: float = SettingsManager.get_touch_element_rot(key)
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = Vector2(sc, sc)
	ctrl.rotation = deg_to_rad(rot_deg)
	ctrl.position = _clamp_control_pos(SettingsManager.get_touch_element_px(key, vp_size), ctrl.size, vp_size)


func _update_stick_and_button_positions() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var l_sc: float = SettingsManager.get_touch_element_scale("left_stick")
	var r_sc: float = SettingsManager.get_touch_element_scale("right_stick")
	var l_rad: float = STICK_RADIUS * l_sc
	var r_rad: float = STICK_RADIUS * r_sc
	_left_center = SettingsManager.get_touch_element_px("left_stick", vp_size)
	_left_center.x = clampf(_left_center.x, l_rad + 14.0, maxf(l_rad + 14.0, vp_size.x - l_rad - 14.0))
	_left_center.y = clampf(_left_center.y, l_rad + 14.0, maxf(l_rad + 14.0, vp_size.y - l_rad - 14.0))
	_right_center = SettingsManager.get_touch_element_px("right_stick", vp_size)
	_right_center.x = clampf(_right_center.x, r_rad + 14.0, maxf(r_rad + 14.0, vp_size.x - r_rad - 14.0))
	_right_center.y = clampf(_right_center.y, r_rad + 14.0, maxf(r_rad + 14.0, vp_size.y - r_rad - 14.0))

	_apply_control_layout(_btn_reload, "btn_reload", vp_size)
	_apply_control_layout(_btn_switch, "btn_switch", vp_size)
	_apply_control_layout(_btn_bomb, "btn_bomb", vp_size)
	_apply_control_layout(_btn_shoe, "btn_shoe", vp_size)
	_apply_control_layout(_btn_zoom, "btn_zoom", vp_size)
	_apply_control_layout(_btn_presets, "btn_presets", vp_size)
	_apply_control_layout(_btn_pickup, "btn_pickup", vp_size)
	_apply_control_layout(_btn_interact, "btn_interact", vp_size)
	_apply_control_layout(_btn_throw_prop, "btn_throw_prop", vp_size)
	_apply_control_layout(_btn_ability_1, "ability_0", vp_size)
	_apply_control_layout(_btn_ability_2, "ability_1", vp_size)
	_apply_control_layout(_btn_ability_3, "ability_2", vp_size)
	_apply_control_layout(_btn_ult, "ability_3", vp_size)

	if is_instance_valid(_top_bar_node):
		var tb_sc: float = SettingsManager.get_touch_element_scale("top_bar_hud")
		var tb_rot: float = SettingsManager.get_touch_element_rot("top_bar_hud")
		var tb_pos: Vector2 = SettingsManager.get_touch_element_px("top_bar_hud", vp_size)
		_top_bar_node.pivot_offset = _top_bar_node.size * 0.5
		_top_bar_node.scale = Vector2(tb_sc, tb_sc)
		_top_bar_node.rotation = deg_to_rad(tb_rot)
		_top_bar_node.position = Vector2(tb_pos.x - _top_bar_node.size.x * 0.5, tb_pos.y - _top_bar_node.size.y * 0.5)

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
			var l_rad: float = STICK_RADIUS * SettingsManager.get_touch_element_scale("left_stick")
			var r_rad: float = STICK_RADIUS * SettingsManager.get_touch_element_scale("right_stick")
			var tap_targeting: bool = (
				local_player != null
				and is_instance_valid(local_player)
				and (float(local_player.get("touch_teleport_timer")) > 0.0 or float(local_player.get("touch_banish_timer")) > 0.0)
			)
			if tap_targeting:
				if te.position.distance_to(_left_center) <= l_rad + 14.0 and _left_touch_idx == -1:
					_left_touch_idx = te.index
					_update_left_stick(te.position)
				elif te.position.distance_to(_right_center) <= r_rad + 14.0 and _right_touch_idx == -1:
					_right_touch_idx = te.index
					_update_right_stick(te.position)
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
		if mb.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var l_rad: float = STICK_RADIUS * SettingsManager.get_touch_element_scale("left_stick")
				var r_rad: float = STICK_RADIUS * SettingsManager.get_touch_element_scale("right_stick")
				if mb.position.distance_to(_left_center) <= l_rad + 18.0:
					_left_mouse_active = true
					_update_left_stick(mb.position)
					get_viewport().set_input_as_handled()
				elif mb.position.distance_to(_right_center) <= r_rad + 18.0:
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
	if is_instance_valid(_drawer_panel) and _drawer_panel.visible:
		if _drawer_panel.get_global_rect().has_point(screen_pos):
			return true
	if is_instance_valid(_preset_overlay) and _preset_overlay.visible:
		if _preset_overlay.get_global_rect().has_point(screen_pos):
			return true
	if is_instance_valid(_btn_interact) and _btn_interact.visible:
		if _btn_interact.get_global_rect().has_point(screen_pos):
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
	var r_rad: float = STICK_RADIUS * SettingsManager.get_touch_element_scale("right_stick")
	var delta_v: Vector2 = pos - _right_center
	if delta_v.length() > r_rad:
		delta_v = delta_v.normalized() * r_rad
	_right_knob_offset = delta_v
	_stick_canvas.queue_redraw()


func _push_input_to_player() -> void:
	if local_player == null or not is_instance_valid(local_player):
		return
	var ui_blocking: bool = (
		(is_instance_valid(_layout_overlay) and _layout_overlay.visible)
		or (is_instance_valid(_preset_overlay) and _preset_overlay.visible)
		or (is_instance_valid(_drawer_panel) and _drawer_panel.visible)
	)
	if ui_blocking:
		local_player.virtual_move = Vector2.ZERO
		local_player.virtual_jetpack = false
		local_player.virtual_aim = Vector2.ZERO
		local_player.virtual_fire = false
		local_player.pointer_over_ui = true
		return
	var left_norm: Vector2 = _left_knob_offset / STICK_RADIUS
	var r_rad: float = maxf(1.0, STICK_RADIUS * SettingsManager.get_touch_element_scale("right_stick"))
	var right_norm: Vector2 = _right_knob_offset / r_rad
	local_player.virtual_move = left_norm
	local_player.virtual_jetpack = (left_norm.y < -0.45)
	local_player.virtual_aim = right_norm * SettingsManager.aim_stick_sensitivity
	local_player.virtual_fire = (right_norm.length() > AIM_FIRE_THRESHOLD)

	var hovered: Control = get_viewport().gui_get_hovered_control()
	local_player.pointer_over_ui = (hovered != null and hovered != _stick_canvas) or _left_mouse_active or _right_mouse_active or (_left_touch_idx != -1) or (_right_touch_idx != -1)


func _on_stick_canvas_draw() -> void:
	var bg_col := Color(0.08, 0.12, 0.18, 0.34)
	var ring_col := Color(1.0, 1.0, 1.0, 0.78)
	var inner_ring := Color(1.0, 1.0, 1.0, 0.35)
	var l_sc: float = SettingsManager.get_touch_element_scale("left_stick")
	var l_rot: float = deg_to_rad(SettingsManager.get_touch_element_rot("left_stick"))
	var r_sc: float = SettingsManager.get_touch_element_scale("right_stick")
	var r_rot: float = deg_to_rad(SettingsManager.get_touch_element_rot("right_stick"))

	# Left Stick: Mini-Militia style 4-way directional pad
	_stick_canvas.draw_set_transform(_left_center, l_rot, Vector2(l_sc, l_sc))
	_stick_canvas.draw_circle(Vector2.ZERO, STICK_RADIUS, bg_col)
	_stick_canvas.draw_arc(Vector2.ZERO, STICK_RADIUS, 0.0, TAU, 40, ring_col, 2.5)
	_stick_canvas.draw_arc(Vector2.ZERO, STICK_RADIUS * 0.62, 0.0, TAU, 32, inner_ring, 1.5)
	var arrow_col := Color(0.78, 0.86, 0.98, 0.65)
	var d_off: float = STICK_RADIUS * 0.42
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var p: Vector2 = dir * d_off
		var perp := Vector2(-dir.y, dir.x)
		_stick_canvas.draw_colored_polygon(PackedVector2Array([
			p + dir * 8.0, p - dir * 5.0 + perp * 7.0, p - dir * 5.0 - perp * 7.0
		]), arrow_col)
	_stick_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_stick_canvas.draw_circle(_left_center + _left_knob_offset, KNOB_RADIUS * l_sc, Color(0.48, 0.62, 0.84, 0.75))
	_stick_canvas.draw_arc(_left_center + _left_knob_offset, KNOB_RADIUS * l_sc, 0.0, TAU, 24, ring_col, 2.0)

	# Right Stick: Inner Aim Zone + Outer Firing Zone Ring
	_stick_canvas.draw_set_transform(_right_center, r_rot, Vector2(r_sc, r_sc))
	var is_firing_zone: bool = (_right_knob_offset.length() > STICK_RADIUS * r_sc * AIM_FIRE_THRESHOLD)
	var outer_fill_col: Color = Color(0.96, 0.24, 0.20, 0.36) if is_firing_zone else Color(0.88, 0.24, 0.20, 0.22)
	var outer_ring_col: Color = Color(1.0, 0.36, 0.28, 0.96) if is_firing_zone else Color(1.0, 0.42, 0.34, 0.88)
	var aim_r: float = STICK_RADIUS * AIM_FIRE_THRESHOLD
	var band_mid_r: float = (STICK_RADIUS + aim_r) * 0.5
	var band_w: float = STICK_RADIUS - aim_r
	# Outer shooting band (between aim_r and STICK_RADIUS)
	_stick_canvas.draw_arc(Vector2.ZERO, band_mid_r, 0.0, TAU, 48, outer_fill_col, band_w)
	_stick_canvas.draw_arc(Vector2.ZERO, STICK_RADIUS, 0.0, TAU, 48, outer_ring_col, 3.0)
	# Tick marks around the outer shooting ring
	for ti in range(8):
		var tang: float = float(ti) * (TAU / 8.0)
		var tdir: Vector2 = Vector2.from_angle(tang)
		_stick_canvas.draw_line(tdir * (aim_r + 3.0), tdir * (STICK_RADIUS - 3.0), Color(1.0, 0.55, 0.45, 0.55), 2.0)
	# Inner aim-only circle (0..aim_r)
	_stick_canvas.draw_circle(Vector2.ZERO, aim_r, Color(0.06, 0.10, 0.16, 0.48))
	_stick_canvas.draw_arc(Vector2.ZERO, aim_r, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.85), 2.2)
	_stick_canvas.draw_line(Vector2(-20.0, 0.0), Vector2(20.0, 0.0), Color(1.0, 1.0, 1.0, 0.85), 2.0)
	_stick_canvas.draw_line(Vector2(0.0, -20.0), Vector2(0.0, 20.0), Color(1.0, 1.0, 1.0, 0.85), 2.0)
	_stick_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var knob_col: Color = Color(1.0, 0.25, 0.20, 0.92) if is_firing_zone else Color(0.92, 0.42, 0.30, 0.80)
	_stick_canvas.draw_circle(_right_center + _right_knob_offset, KNOB_RADIUS * r_sc, knob_col)
	_stick_canvas.draw_arc(_right_center + _right_knob_offset, KNOB_RADIUS * r_sc, 0.0, TAU, 24, ring_col, 2.0)


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

	# Full-Width Responsive Top Bar (positioned via SettingsManager.touch_layout["top_bar_hud"])
	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 10
	top_bar.offset_right = -10
	top_bar.offset_top = 8
	top_bar.offset_bottom = 86
	top_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_theme_constant_override("separation", 8)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bar)
	_top_bar_node = top_bar

	_btn_zoom = Button.new()
	_btn_zoom.text = ""
	_btn_zoom.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_zoom, Color(0.10, 0.14, 0.20, 0.65), Color(1.0, 1.0, 1.0, 0.88), 76, 16)
	_attach_btn_icon(_btn_zoom, "zoom", Color(0.45, 0.88, 1.0))
	_btn_zoom.pressed.connect(func():
		if local_player != null and local_player.has_method("cycle_zoom"):
			local_player.cycle_zoom()
	)
	add_child(_btn_zoom)

	_btn_presets = Button.new()
	_btn_presets.text = "KIT"
	_btn_presets.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_presets, Color(0.14, 0.16, 0.22, 0.65), Color(1.0, 1.0, 1.0, 0.85), 74, 16)
	_btn_presets.pressed.connect(func(): _open_preset_selector(PRESET_SELECT_DURATION))
	add_child(_btn_presets)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(left_spacer)

	# Unified Top HUD Box: HP/Gas + Menu | Weapon/Agent + Ammo | K/A/D | Timer | Chat
	var hud_box := PanelContainer.new()
	hud_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud_box.add_theme_stylebox_override("panel", _make_compact_glass_style())
	top_bar.add_child(hud_box)

	var hud_h := HBoxContainer.new()
	hud_h.add_theme_constant_override("separation", 14)
	hud_box.add_child(hud_h)

	var lv := VBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", 4)
	hud_h.add_child(lv)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	lv.add_child(hp_row)
	_hp_label = Label.new()
	_hp_label.text = "HP"
	_hp_label.custom_minimum_size = Vector2(56, 0)
	_hp_label.add_theme_font_size_override("font_size", 14)
	_hp_label.modulate = Color(1.0, 0.45, 0.82)
	hp_row.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(138, 14)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar.modulate = Color(0.92, 0.24, 0.78)
	hp_row.add_child(_hp_bar)

	var fuel_row := HBoxContainer.new()
	fuel_row.add_theme_constant_override("separation", 6)
	lv.add_child(fuel_row)
	_fuel_label = Label.new()
	_fuel_label.text = "GAS"
	_fuel_label.custom_minimum_size = Vector2(56, 0)
	_fuel_label.add_theme_font_size_override("font_size", 13)
	_fuel_label.modulate = Color(0.42, 0.78, 1.0)
	fuel_row.add_child(_fuel_label)

	_fuel_bar = ProgressBar.new()
	_fuel_bar.max_value = 100
	_fuel_bar.value = 100
	_fuel_bar.show_percentage = false
	_fuel_bar.custom_minimum_size = Vector2(138, 13)
	_fuel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fuel_bar.modulate = Color(0.22, 0.58, 1.0)
	fuel_row.add_child(_fuel_bar)

	var drawer_btn := Button.new()
	drawer_btn.text = "MENU"
	drawer_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	drawer_btn.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(drawer_btn, Color(0.12, 0.16, 0.24, 0.72), Color(1.0, 1.0, 1.0, 0.78), 46, 13)
	hud_h.add_child(drawer_btn)

	_test_bot_btn = Button.new()
	_test_bot_btn.custom_minimum_size = Vector2(96, 40)
	_test_bot_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_test_bot_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(_test_bot_btn, Color(0.08, 0.24, 0.26, 0.94), Color(0.24, 0.86, 0.82), 13)
	_test_bot_btn.visible = NetworkManager.is_test_mode()
	_test_bot_btn.pressed.connect(func():
		NetworkManager.test_bot_behavior = (NetworkManager.test_bot_behavior + 1) % 3
		_refresh_test_bot_btn()
	)
	hud_h.add_child(_test_bot_btn)

	_agent_swap_row = HBoxContainer.new()
	_agent_swap_row.add_theme_constant_override("separation", 4)
	_agent_swap_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_agent_swap_row.visible = NetworkManager.is_test_mode() and NetworkManager.is_agent_clash_mode()
	hud_h.add_child(_agent_swap_row)

	var prev_ag_btn := Button.new()
	prev_ag_btn.text = "<"
	prev_ag_btn.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(prev_ag_btn, Color(0.18, 0.12, 0.28, 0.85), Color(0.78, 0.48, 1.0, 0.9), 40, 16)
	prev_ag_btn.pressed.connect(func():
		if local_player != null and local_player.has_method("switch_agent_in_game"):
			local_player.switch_agent_in_game(int(local_player.get("archetype_id")) - 1)
	)
	_agent_swap_row.add_child(prev_ag_btn)

	var next_ag_btn := Button.new()
	next_ag_btn.text = ">"
	next_ag_btn.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(next_ag_btn, Color(0.18, 0.12, 0.28, 0.85), Color(0.78, 0.48, 1.0, 0.9), 40, 16)
	next_ag_btn.pressed.connect(func():
		if local_player != null and local_player.has_method("switch_agent_in_game"):
			local_player.switch_agent_in_game(int(local_player.get("archetype_id")) + 1)
	)
	_agent_swap_row.add_child(next_ag_btn)

	var sep1 := ColorRect.new()
	sep1.custom_minimum_size = Vector2(2, 36)
	sep1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sep1.color = Color(1.0, 1.0, 1.0, 0.20)
	hud_h.add_child(sep1)

	var w_row := HBoxContainer.new()
	w_row.add_theme_constant_override("separation", 8)
	w_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud_h.add_child(w_row)

	var atlas := AtlasTexture.new()
	atlas.atlas = WEAPONS_TEX
	atlas.region = Rect2(0, 0, 256, 128)
	_weapon_icon = TextureRect.new()
	_weapon_icon.texture = atlas
	_weapon_icon.custom_minimum_size = Vector2(76, 40)
	_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_weapon_icon.gui_input.connect(func(ev: InputEvent):
		var pressed: bool = (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed) or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		if pressed and local_player != null and local_player.has_method("drop_picked_up_gun"):
			local_player.drop_picked_up_gun()
	)
	w_row.add_child(_weapon_icon)

	var p_atlas := AtlasTexture.new()
	p_atlas.region = Rect2(0, 0, 128, 128)
	_agent_portrait = TextureRect.new()
	_agent_portrait.texture = p_atlas
	_agent_portrait.custom_minimum_size = Vector2(54, 54)
	_agent_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_agent_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_agent_portrait.clip_contents = true
	_agent_portrait.visible = false
	var hat_atlas := AtlasTexture.new()
	hat_atlas.region = Rect2(0, 0, 128, 128)
	_agent_hat_overlay = TextureRect.new()
	_agent_hat_overlay.texture = hat_atlas
	_agent_hat_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_agent_hat_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_agent_hat_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_agent_portrait.add_child(_agent_hat_overlay)
	w_row.add_child(_agent_portrait)

	var w_info := VBoxContainer.new()
	w_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_info.alignment = BoxContainer.ALIGNMENT_CENTER
	w_info.add_theme_constant_override("separation", 1)
	w_row.add_child(w_info)

	_weapon_name_label = Label.new()
	_weapon_name_label.text = "AK47"
	_weapon_name_label.clip_text = true
	_weapon_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_weapon_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_name_label.custom_minimum_size = Vector2(114, 0)
	_weapon_name_label.add_theme_font_size_override("font_size", 14)
	w_info.add_child(_weapon_name_label)

	_ammo_label = Label.new()
	_ammo_label.text = "30 / 30"
	_ammo_label.clip_text = true
	_ammo_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ammo_label.add_theme_font_size_override("font_size", 15)
	_ammo_label.modulate = Color(1.0, 0.88, 0.4)
	w_info.add_child(_ammo_label)

	var sec_atlas := AtlasTexture.new()
	sec_atlas.atlas = WEAPONS_TEX
	sec_atlas.region = Rect2(0, 0, 256, 128)
	_secondary_weapon_icon = TextureRect.new()
	_secondary_weapon_icon.texture = sec_atlas
	_secondary_weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_secondary_weapon_icon.custom_minimum_size = Vector2(72, 40)
	_secondary_weapon_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_secondary_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_secondary_weapon_icon.modulate = Color(0.85, 0.90, 0.96, 0.82)
	_secondary_weapon_icon.visible = false
	_secondary_weapon_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_secondary_weapon_icon.gui_input.connect(func(ev: InputEvent):
		var pressed: bool = (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed) or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		if pressed and local_player != null and local_player.has_method("cycle_weapon"):
			local_player.cycle_weapon()
	)
	w_row.add_child(_secondary_weapon_icon)

	_bomb_hud_icon = BombHudIcon.new()
	_bomb_hud_icon.custom_minimum_size = Vector2(40, 40)
	_bomb_hud_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bomb_hud_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	_bomb_hud_icon.gui_input.connect(func(ev: InputEvent):
		var pressed: bool = (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed) or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		if pressed and local_player != null and local_player.has_method("cycle_bomb_type"):
			local_player.cycle_bomb_type()
	)
	_bomb_hud_icon.visible = false
	w_row.add_child(_bomb_hud_icon)

	_bomb_hud_label = Label.new()
	_bomb_hud_label.text = "3"
	_bomb_hud_label.add_theme_font_size_override("font_size", 14)
	_bomb_hud_label.modulate = Color(1.0, 0.72, 0.35)
	_bomb_hud_label.visible = false
	w_row.add_child(_bomb_hud_label)

	var tp_atlas := AtlasTexture.new()
	tp_atlas.region = Rect2(0, 0, 128, 128)
	_target_portrait = TextureRect.new()
	_target_portrait.texture = tp_atlas
	_target_portrait.custom_minimum_size = Vector2(50, 50)
	_target_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_portrait.clip_contents = true
	_target_portrait.visible = false
	var th_atlas := AtlasTexture.new()
	th_atlas.region = Rect2(0, 0, 128, 128)
	_target_hat_overlay = TextureRect.new()
	_target_hat_overlay.texture = th_atlas
	_target_hat_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_hat_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_hat_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_portrait.add_child(_target_hat_overlay)
	w_row.add_child(_target_portrait)

	var kad_sep := ColorRect.new()
	kad_sep.custom_minimum_size = Vector2(2, 36)
	kad_sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kad_sep.color = Color(1.0, 1.0, 1.0, 0.20)
	hud_h.add_child(kad_sep)

	_kad_label = Label.new()
	_kad_label.text = "K:0  A:0  D:0"
	_kad_label.add_theme_font_size_override("font_size", 15)
	_kad_label.modulate = Color(1.0, 0.90, 0.45)
	_kad_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud_h.add_child(_kad_label)

	var timer_sep := ColorRect.new()
	timer_sep.custom_minimum_size = Vector2(2, 36)
	timer_sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	timer_sep.color = Color(1.0, 1.0, 1.0, 0.20)
	timer_sep.visible = not NetworkManager.is_test_mode()
	hud_h.add_child(timer_sep)

	_match_timer_pill = PanelContainer.new()
	_match_timer_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var empty_sb := StyleBoxEmpty.new()
	_match_timer_pill.add_theme_stylebox_override("panel", empty_sb)
	_match_timer_pill.visible = not NetworkManager.is_test_mode()
	hud_h.add_child(_match_timer_pill)

	_match_timer_label = Label.new()
	_match_timer_label.text = "05:00"
	_match_timer_label.add_theme_font_size_override("font_size", 17)
	_match_timer_label.modulate = Color(0.95, 0.96, 1.0)
	_match_timer_pill.add_child(_match_timer_label)

	_chat_toggle_btn = Button.new()
	_chat_toggle_btn.text = "CHAT"
	_chat_toggle_btn.custom_minimum_size = Vector2(88, 40)
	_chat_toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chat_toggle_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(_chat_toggle_btn, "blue", "", 10, 4)
	_chat_toggle_btn.add_theme_font_size_override("font_size", 15)
	hud_h.add_child(_chat_toggle_btn)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(right_spacer)

	# Circular Translucent Touch Action Buttons (positioned via SettingsManager.touch_layout)
	_btn_reload = Button.new()
	_btn_reload.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_reload, Color(0.10, 0.16, 0.26, 0.56), Color(1.0, 1.0, 1.0, 0.82), 70, 14)
	_attach_btn_icon(_btn_reload, "reload", Color(0.35, 0.85, 1.0))
	_btn_reload.pressed.connect(func():
		if local_player != null:
			local_player.start_reload()
	)
	add_child(_btn_reload)

	_btn_switch = Button.new()
	_btn_switch.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_switch, Color(0.20, 0.16, 0.08, 0.56), Color(1.0, 1.0, 1.0, 0.82), 70, 14)
	_attach_btn_icon(_btn_switch, "swap", Color(0.95, 0.78, 0.35))
	_btn_switch.pressed.connect(func():
		if local_player != null:
			local_player.cycle_weapon()
	)
	add_child(_btn_switch)

	_btn_bomb = Button.new()
	_btn_bomb.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_bomb, Color(0.22, 0.12, 0.08, 0.58), Color(1.0, 1.0, 1.0, 0.88), 78, 14)
	_attach_btn_icon(_btn_bomb, "bomb", Color(1.0, 0.62, 0.28))
	_btn_bomb.pressed.connect(func():
		if local_player != null and local_player.has_method("throw_bomb"):
			local_player.throw_bomb()
	)
	add_child(_btn_bomb)

	_btn_shoe = Button.new()
	_btn_shoe.offset_left = 14
	_btn_shoe.offset_top = 96
	_btn_shoe.offset_right = 94
	_btn_shoe.offset_bottom = 176
	_btn_shoe.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(_btn_shoe, Color(0.20, 0.14, 0.10, 0.65), Color(1.0, 1.0, 1.0, 0.85), 80, 16)
	_attach_btn_icon(_btn_shoe, "throw", Color(0.35, 0.95, 0.68))
	_btn_shoe.pressed.connect(func():
		if local_player != null and local_player.has_method("throw_held_item"):
			local_player.throw_held_item()
	)
	add_child(_btn_shoe)

	_btn_pickup = Button.new()
	_btn_pickup.focus_mode = Control.FOCUS_NONE
	_btn_pickup.visible = false
	_style_circle_btn(_btn_pickup, Color(0.10, 0.36, 0.22, 0.88), Color(0.45, 1.0, 0.65, 0.95), 78, 15)
	_attach_btn_icon(_btn_pickup, "pick", Color(0.45, 1.0, 0.65))
	_btn_pickup.pressed.connect(func():
		if not NetworkManager.is_agent_clash_mode() and _nearby_crate_idx >= 0:
			pickup_weapon_requested.emit(_nearby_crate_idx)
		elif _nearby_pick_inter_idx >= 0:
			interact_requested.emit(_nearby_pick_inter_idx)
		elif NetworkManager.is_agent_clash_mode() and local_player != null and local_player.has_method("find_grabbable_player"):
			var tgt: Node2D = local_player.find_grabbable_player()
			if tgt != null and local_player.has_method("grab_player"):
				local_player.grab_player(tgt)
	)
	add_child(_btn_pickup)

	_btn_interact = Button.new()
	_btn_interact.focus_mode = Control.FOCUS_NONE
	_btn_interact.visible = false
	_style_circle_btn(_btn_interact, Color(0.14, 0.28, 0.44, 0.90), Color(0.42, 0.85, 1.0, 0.95), 78, 13)
	_attach_btn_icon(_btn_interact, "use", Color(0.42, 0.85, 1.0))
	_btn_interact.pressed.connect(func():
		if _nearby_inter_idx >= 0:
			interact_requested.emit(_nearby_inter_idx)
	)
	add_child(_btn_interact)

	_btn_throw_prop = Button.new()
	_btn_throw_prop.offset_left = 14
	_btn_throw_prop.offset_top = 190
	_btn_throw_prop.offset_right = 102
	_btn_throw_prop.offset_bottom = 278
	_btn_throw_prop.focus_mode = Control.FOCUS_NONE
	_btn_throw_prop.visible = false
	_style_circle_btn(_btn_throw_prop, Color(0.45, 0.24, 0.10, 0.90), Color(1.0, 0.78, 0.36, 0.95), 88, 15)
	_attach_btn_icon(_btn_throw_prop, "prop", Color(1.0, 0.78, 0.36))
	_btn_throw_prop.pressed.connect(func():
		if local_player != null and local_player.has_method("throw_held_prop"):
			local_player.throw_held_prop()
	)
	add_child(_btn_throw_prop)

	# Individually draggable circular Agent Ability Buttons
	_btn_ability_1 = _create_agent_btn("ABIL 1", Color(0.24, 0.20, 0.06, 0.94), Color(1.0, 0.84, 0.24), 0)
	_btn_ability_2 = _create_agent_btn("ABIL 2", Color(0.10, 0.18, 0.30, 0.94), Color(0.45, 0.95, 0.65), 1)
	_btn_ability_3 = _create_agent_btn("ABIL 3", Color(0.18, 0.14, 0.30, 0.94), Color(0.76, 0.50, 1.0), 2)
	_btn_ult = _create_agent_btn("ULTIMATE", Color(0.32, 0.08, 0.10, 0.96), Color(1.0, 0.28, 0.28), 3)
	add_child(_btn_ability_1)
	add_child(_btn_ability_2)
	add_child(_btn_ability_3)
	add_child(_btn_ult)

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
	_stun_label.text = "STUNNED!"
	_stun_banner.add_child(_stun_label)

	_sync_mode_hud_visibility()

	# Top-Right WiFi Chat Panel (toggled by _chat_toggle_btn in top_bar)
	_chat_panel = PanelContainer.new()
	_chat_panel.anchor_left = 1.0
	_chat_panel.anchor_right = 1.0
	_chat_panel.offset_left = -232
	_chat_panel.offset_right = -12
	_chat_panel.offset_top = 64
	_chat_panel.offset_bottom = 318
	_chat_panel.visible = false
	_chat_panel.add_theme_stylebox_override("panel", UIStyle.make_card_stylebox("blue", Color(0.08, 0.12, 0.18, 0.94), 12, 10))
	add_child(_chat_panel)

	var chat_vbox := VBoxContainer.new()
	chat_vbox.add_theme_constant_override("separation", 6)
	_chat_panel.add_child(chat_vbox)

	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.scroll_following = true
	_chat_log.custom_minimum_size = Vector2(190, 120)
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_font_size_override("normal_font_size", 13)
	chat_vbox.add_child(_chat_log)

	var emoji_row := GridContainer.new()
	emoji_row.columns = 4
	emoji_row.add_theme_constant_override("h_separation", 4)
	emoji_row.add_theme_constant_override("v_separation", 4)
	chat_vbox.add_child(emoji_row)
	for em in ["HAHA", "GG", "NICE", "OUCH", "WHAT?!", "BOOM", "RIP"]:
		var eb := Button.new()
		eb.text = em
		eb.focus_mode = Control.FOCUS_NONE
		eb.custom_minimum_size = Vector2(0, 26)
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIStyle.style_layer_button(eb, "blue", "", 8, 3)
		eb.add_theme_font_size_override("font_size", 10)
		eb.pressed.connect(_send_tease_emoji.bind(em))
		emoji_row.add_child(eb)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	chat_vbox.add_child(input_row)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "WiFi Chat..."
	_chat_input.custom_minimum_size = Vector2(0, 34)
	_chat_input.add_theme_font_size_override("font_size", 13)
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.max_length = 80
	_chat_input.text_submitted.connect(func(_t: String): _send_chat_text())
	input_row.add_child(_chat_input)
	var send_btn := Button.new()
	send_btn.text = "SEND"
	send_btn.custom_minimum_size = Vector2(56, 34)
	send_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(send_btn, "green", "", 10, 4)
	send_btn.add_theme_font_size_override("font_size", 12)
	send_btn.pressed.connect(_send_chat_text)
	input_row.add_child(send_btn)

	_chat_toggle_btn.pressed.connect(func():
		_chat_panel.visible = not _chat_panel.visible
		if _chat_panel.visible:
			_chat_toggle_btn.text = "CHAT"
		if is_instance_valid(_chat_toast_label):
			_chat_toast_label.visible = (not _chat_panel.visible) and (not _chat_toast_items.is_empty())
		_update_killfeed_offset()
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
	_chat_toast_label.offset_top = 64
	_chat_toast_label.offset_bottom = 152
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
	_killfeed_label.offset_left = -440
	_killfeed_label.offset_right = -12
	_killfeed_label.offset_top = 82
	_killfeed_label.offset_bottom = 212
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

	# Full-Screen Pause Menu Overlay (opened via MENU button)
	var pause_overlay := ColorRect.new()
	_drawer_panel = pause_overlay
	pause_overlay.z_index = 40
	pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.color = Color(0.02, 0.03, 0.06, 0.82)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	add_child(pause_overlay)
	drawer_btn.pressed.connect(func():
		pause_overlay.visible = not pause_overlay.visible
		if pause_overlay.visible and is_instance_valid(_respawn_panel):
			_respawn_panel.visible = false
		_sync_offline_pause_state()
	)

	var pause_center := CenterContainer.new()
	pause_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(pause_center)

	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(520, 0)
	var gm_sb := StyleBoxFlat.new()
	gm_sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	gm_sb.border_color = Color(1.0, 0.84, 0.24, 0.98)
	gm_sb.set_border_width_all(3)
	gm_sb.set_corner_radius_all(18)
	gm_sb.set_content_margin_all(22)
	gm_sb.shadow_color = Color(1.0, 0.82, 0.22, 0.36)
	gm_sb.shadow_size = 10
	gm_sb.shadow_offset = Vector2.ZERO
	right_panel.add_theme_stylebox_override("panel", gm_sb)
	pause_center.add_child(right_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 14)
	right_panel.add_child(rv)

	var hdr_box := PanelContainer.new()
	var hdr_style := StyleBoxFlat.new()
	hdr_style.bg_color = Color(0.11, 0.16, 0.26, 0.96)
	hdr_style.set_corner_radius_all(8)
	hdr_style.set_content_margin_all(8)
	hdr_box.add_theme_stylebox_override("panel", hdr_style)
	rv.add_child(hdr_box)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 10)
	hdr_box.add_child(hdr_row)

	var hdr_left_spacer := Control.new()
	hdr_left_spacer.custom_minimum_size = Vector2(44, 40)
	hdr_row.add_child(hdr_left_spacer)

	var pause_title := Label.new()
	pause_title.text = "GAME MENU"
	pause_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 26)
	pause_title.modulate = Color(1.0, 0.84, 0.24)
	hdr_row.add_child(pause_title)

	var close_x_btn := Button.new()
	close_x_btn.text = "X"
	close_x_btn.custom_minimum_size = Vector2(44, 40)
	close_x_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(close_x_btn, Color(0.28, 0.10, 0.12, 0.96), Color(0.95, 0.38, 0.36), 16)
	close_x_btn.pressed.connect(func():
		pause_overlay.visible = false
		_sync_offline_pause_state()
	)
	hdr_row.add_child(close_x_btn)

	_net_status_label = null
	_map_mode_label = null
	_scoreboard_label = null

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 10)
	rv.add_child(nav_row)

	_rem_bot_btn = Button.new()
	_rem_bot_btn.text = "- BOT"
	_rem_bot_btn.custom_minimum_size = Vector2(0, 44)
	_rem_bot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rem_bot_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(_rem_bot_btn, Color(0.26, 0.14, 0.14, 0.94), Color(0.95, 0.42, 0.36), 14)
	_rem_bot_btn.visible = not NetworkManager.is_network_active() or NetworkManager.is_host_active()
	_rem_bot_btn.pressed.connect(func(): remove_bot_requested.emit())
	nav_row.add_child(_rem_bot_btn)

	_add_bot_btn = Button.new()
	_add_bot_btn.text = "+ BOT"
	_add_bot_btn.custom_minimum_size = Vector2(0, 44)
	_add_bot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_bot_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(_add_bot_btn, Color(0.10, 0.26, 0.16, 0.94), Color(0.32, 0.92, 0.48), 14)
	_add_bot_btn.visible = not NetworkManager.is_network_active() or NetworkManager.is_host_active()
	_add_bot_btn.pressed.connect(func(): add_bot_requested.emit())
	nav_row.add_child(_add_bot_btn)
	_refresh_test_bot_btn()

	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 10)
	rv.add_child(audio_row)

	var music_btn := Button.new()
	music_btn.custom_minimum_size = Vector2(0, 44)
	music_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_btn.focus_mode = Control.FOCUS_NONE
	var sync_music_btn := func():
		music_btn.text = "MUSIC: ON" if SettingsManager.music_enabled else "MUSIC: MUTED"
		_style_action_button(music_btn, Color(0.10, 0.24, 0.34, 0.94), Color(0.35, 0.85, 1.0) if SettingsManager.music_enabled else Color(0.65, 0.35, 0.35), 14)
	sync_music_btn.call()
	music_btn.pressed.connect(func():
		SettingsManager.music_enabled = not SettingsManager.music_enabled
		SettingsManager.apply_and_save()
		sync_music_btn.call()
	)
	audio_row.add_child(music_btn)

	var sfx_btn := Button.new()
	sfx_btn.custom_minimum_size = Vector2(0, 44)
	sfx_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_btn.focus_mode = Control.FOCUS_NONE
	var sync_sfx_btn := func():
		sfx_btn.text = "SFX: ON" if SettingsManager.sfx_enabled else "SFX: MUTED"
		_style_action_button(sfx_btn, Color(0.10, 0.26, 0.18, 0.94), Color(0.35, 0.92, 0.55) if SettingsManager.sfx_enabled else Color(0.65, 0.35, 0.35), 14)
	sync_sfx_btn.call()
	sfx_btn.pressed.connect(func():
		SettingsManager.sfx_enabled = not SettingsManager.sfx_enabled
		SettingsManager.apply_and_save()
		sync_sfx_btn.call()
	)
	audio_row.add_child(sfx_btn)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 10)
	rv.add_child(util_row)

	var layout_btn := Button.new()
	layout_btn.text = "TOUCH LAYOUT"
	layout_btn.custom_minimum_size = Vector2(0, 44)
	layout_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(layout_btn, Color(0.24, 0.18, 0.06, 0.94), Color(1.0, 0.78, 0.24), 14)
	layout_btn.pressed.connect(_open_hud_layout_editor)
	util_row.add_child(layout_btn)

	var menu_btn := Button.new()
	menu_btn.text = "LEAVE MATCH"
	menu_btn.custom_minimum_size = Vector2(0, 44)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(menu_btn, Color(0.26, 0.10, 0.12, 0.94), Color(0.95, 0.42, 0.36), 14)
	menu_btn.pressed.connect(func():
		pause_overlay.visible = false
		get_tree().paused = false
		NetworkManager.disconnect_network()
		NetworkManager.go_to_main_menu()
	)
	util_row.add_child(menu_btn)

	var resume_btn := Button.new()
	resume_btn.text = "RESUME"
	resume_btn.custom_minimum_size = Vector2(0, 50)
	resume_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(resume_btn, Color(0.10, 0.30, 0.16, 0.96), Color(0.32, 0.92, 0.48), 18)
	resume_btn.pressed.connect(func():
		pause_overlay.visible = false
		_sync_offline_pause_state()
	)
	rv.add_child(resume_btn)

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
	_build_match_end_overlay()

	_combo_banner_label = Label.new()
	_combo_banner_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_combo_banner_label.position = Vector2(0, 84)
	_combo_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_banner_label.add_theme_font_size_override("font_size", 32)
	_combo_banner_label.modulate = Color(1.0, 0.78, 0.18)
	_combo_banner_label.visible = false
	_combo_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_combo_banner_label)


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "HP %d" % current


func _on_fuel_changed(current: float, maximum: float) -> void:
	_fuel_bar.max_value = maximum
	if NetworkManager.unlimited_jetpack:
		_fuel_bar.value = maximum
		_fuel_label.text = "GAS INF"
	else:
		_fuel_bar.value = current
		_fuel_label.text = "▲%d" % int(round(current))


func _on_ammo_changed(current: int, mag_size: int, is_reloading: bool) -> void:
	if NetworkManager.is_agent_clash_mode():
		_refresh_top_info_pill()
		return
	if is_reloading:
		if _active_weapon != null and _active_weapon.single_shell_reload:
			_ammo_label.text = "LOADING SHELL (%d/%d)" % [current, mag_size]
		else:
			_ammo_label.text = "RELOADING..."
		_ammo_label.modulate = Color(1.0, 0.45, 0.25)
	else:
		var res_ammo: int = int(local_player.get_active_reserve_ammo()) if (local_player != null and local_player.has_method("get_active_reserve_ammo")) else -1
		if res_ammo >= 0:
			_ammo_label.text = "%d / %d" % [current, res_ammo]
			if current <= 0 and res_ammo <= 0:
				_ammo_label.modulate = Color(1.0, 0.35, 0.30)
			else:
				_ammo_label.modulate = Color(1.0, 0.88, 0.4)
		elif _active_weapon != null and _active_weapon.unlimited_reserve:
			_ammo_label.text = "%d / ∞" % current
			_ammo_label.modulate = Color(1.0, 0.88, 0.4)
		else:
			_ammo_label.text = "%d / %d" % [current, mag_size]
			_ammo_label.modulate = Color(1.0, 0.88, 0.4)


func _on_weapon_changed(weapon_data: WeaponData) -> void:
	_active_weapon = weapon_data
	if NetworkManager.is_agent_clash_mode() and local_player != null:
		_refresh_top_info_pill()
		return
	_weapon_name_label.text = weapon_data.display_name
	var skin_row: int = local_player.weapon_skin_id if local_player != null else 0
	_set_weapon_icon_texture(_weapon_icon, weapon_data, skin_row)
	_refresh_top_info_pill()


func _set_weapon_icon_texture(icon_rect: TextureRect, w_data: WeaponData, skin_row: int) -> void:
	if not is_instance_valid(icon_rect) or w_data == null:
		return
	if w_data.id == 11 or w_data.id == 13 or w_data.id == 15 or w_data.id == 16 or w_data.id == 17:
		icon_rect.texture = TEX_FLAMETHROWER if w_data.id == 11 else (TEX_PLASMA_CANNON if w_data.id == 13 else (TEX_HOOK_GUN if w_data.id == 15 else (TEX_BUBBLE_GUN if w_data.id == 16 else TEX_MACHINE_GUN)))
		return
	var atlas: AtlasTexture = icon_rect.texture as AtlasTexture
	if atlas == null:
		atlas = AtlasTexture.new()
		atlas.atlas = WEAPONS_TEX
		icon_rect.texture = atlas
	atlas.region = Rect2(w_data.sprite_frame * 256, skin_row * 128, 256, 128)


func _set_portrait_frame(rect: TextureRect, tex_path: String) -> void:
	if not is_instance_valid(rect):
		return
	var tex: Texture2D = load(tex_path) as Texture2D
	var at: AtlasTexture = rect.texture as AtlasTexture
	if at == null or tex == null:
		return
	at.atlas = tex
	var fw: float = maxf(1.0, float(tex.get_width()) / 8.0)
	var fh: float = maxf(1.0, float(tex.get_height()))
	if tex_path.ends_with("jackson_sheet.png"):
		at.region = Rect2(fw * 0.14, 0.0, fw * 0.72, fh * 0.58)
	else:
		at.region = Rect2(fw * 0.16, fh * 0.06, fw * 0.68, fh * 0.68)


func _refresh_top_info_pill() -> void:
	var is_agent: bool = NetworkManager.is_agent_clash_mode()
	if is_instance_valid(_weapon_icon):
		_weapon_icon.visible = not is_agent
	if is_instance_valid(_agent_portrait):
		_agent_portrait.visible = is_agent
	if is_instance_valid(_secondary_weapon_icon):
		_secondary_weapon_icon.visible = not is_agent
	if is_instance_valid(_bomb_hud_icon):
		_bomb_hud_icon.visible = (not is_agent) and NetworkManager.allow_explosives
	if is_instance_valid(_bomb_hud_label):
		_bomb_hud_label.visible = (not is_agent) and NetworkManager.allow_explosives

	if local_player == null:
		return

	if is_agent:
		var arch_id: int = int(local_player.get("archetype_id"))
		var ag: Dictionary = AgentData.get_agent(arch_id)
		var part_id: int = ProfileManager.get_archetype_part_id(arch_id)
		_set_portrait_frame(_agent_portrait, ModularCharacter.get_part_texture_path("skin", part_id))
		_set_portrait_frame(_agent_hat_overlay, ModularCharacter.get_part_texture_path("head", part_id))
		if is_instance_valid(_agent_hat_overlay):
			_agent_hat_overlay.visible = true
		if is_instance_valid(_weapon_name_label):
			_weapon_name_label.text = str(ag["agent_name"]).to_upper()
		if is_instance_valid(_ammo_label):
			var best_enemy: Node2D = null
			var best_dist: float = 1e9
			var my_id: int = int(local_player.get("peer_id"))
			var my_team: int = int(local_player.get("team_id"))
			for p in get_tree().get_nodes_in_group("players"):
				if not is_instance_valid(p) or int(p.get("peer_id")) == my_id:
					continue
				if p.has_method("is_alive") and not p.is_alive():
					continue
				if NetworkManager.is_team_mode() and int(p.get("team_id")) == my_team:
					continue
				if float(p.get("invis_timer")) > 0.0:
					continue
				var d: float = (local_player as Node2D).global_position.distance_to((p as Node2D).global_position)
				if d < best_dist:
					best_dist = d
					best_enemy = p as Node2D
			if best_enemy != null:
				var t_name: String = str(best_enemy.get("player_name"))
				_ammo_label.text = "LOCK: %s (%dm)" % [t_name, int(round(best_dist / 16.0))]
				_ammo_label.modulate = Color(1.0, 0.72, 0.35) if best_dist <= 460.0 else Color(0.45, 0.96, 1.0)
				if is_instance_valid(_target_portrait):
					var e_arch: int = int(best_enemy.get("archetype_id"))
					var e_part: int = ProfileManager.get_archetype_part_id(e_arch)
					_target_portrait.visible = true
					_set_portrait_frame(_target_portrait, ModularCharacter.get_part_texture_path("skin", e_part))
					_set_portrait_frame(_target_hat_overlay, ModularCharacter.get_part_texture_path("head", e_part))
					if is_instance_valid(_target_hat_overlay):
						_target_hat_overlay.visible = true
			else:
				_ammo_label.text = "NO TARGET"
				_ammo_label.modulate = Color(0.65, 0.75, 0.85)
				if is_instance_valid(_target_portrait):
					_target_portrait.visible = false
	else:
		if is_instance_valid(_target_portrait):
			_target_portrait.visible = false
		var cur_id: int = int(local_player.get("current_weapon_id"))
		var sec_id: int = int(local_player.get("secondary_weapon_id"))
		var prim_id: int = int(local_player.get("_equipped_primary_id"))
		var other_id: int = sec_id if cur_id != sec_id else prim_id
		var skin_row: int = int(local_player.get("weapon_skin_id"))
		if is_instance_valid(_secondary_weapon_icon):
			var other_w: WeaponData = WeaponData.get_weapon(other_id, skin_row, 0)
			_set_weapon_icon_texture(_secondary_weapon_icon, other_w, skin_row)
		if is_instance_valid(_bomb_hud_icon):
			_bomb_hud_icon.bomb_type = str(local_player.get("bomb_type"))
			_bomb_hud_icon.queue_redraw()
		if is_instance_valid(_bomb_hud_label):
			_bomb_hud_label.text = "%d" % maxi(0, int(local_player.get("bomb_count")))


func _on_player_died(seconds_left: float) -> void:
	var menu_open: bool = (is_instance_valid(_drawer_panel) and _drawer_panel.visible) or (is_instance_valid(_layout_overlay) and _layout_overlay.visible)
	_respawn_panel.visible = not menu_open
	_respawn_label.text = "ELIMINATED - RESPAWNING IN %.1fs" % seconds_left


func _on_player_respawned() -> void:
	_respawn_panel.visible = false
	if not NetworkManager.is_agent_clash_mode() and not NetworkManager.random_guns_mode:
		if _chosen_preset_idx >= 0 and local_player != null and local_player.has_method("apply_gun_preset"):
			local_player.apply_gun_preset(_chosen_preset_idx)
		if not _chosen_bomb_type.is_empty() and local_player != null and local_player.has_method("set_bomb_type"):
			local_player.set_bomb_type(_chosen_bomb_type)
		_open_preset_selector(PRESET_SELECT_DURATION)


func _refresh_throw_button() -> void:
	if not is_instance_valid(_btn_shoe):
		return
	if local_player == null or not is_instance_valid(local_player):
		_btn_shoe.visible = false
		return
	var held_prop: String = str(local_player.get("held_prop_kind")) if "held_prop_kind" in local_player else ""
	var held_list: Variant = local_player.get("held_throwables") if "held_throwables" in local_player else []
	var has_throwable: bool = (held_list is Array and not (held_list as Array).is_empty())
	var grabbed_id: int = int(local_player.get("grabbed_player_id")) if "grabbed_player_id" in local_player else 0
	_btn_shoe.visible = (not held_prop.is_empty()) or has_throwable or (grabbed_id != 0)
	var ic: HudBtnIcon = _btn_shoe.get_meta("hud_icon") as HudBtnIcon if _btn_shoe.has_meta("hud_icon") else null
	if ic != null:
		if not held_prop.is_empty():
			ic.kind = "prop"
			ic.prop_kind = held_prop
		else:
			ic.kind = "throw"
		ic.queue_redraw()


func _refresh_pick_button() -> void:
	if not is_instance_valid(_btn_pickup):
		return
	var is_agent: bool = NetworkManager.is_agent_clash_mode()
	if is_agent:
		_btn_pickup.visible = false
		return
	var has_gun: bool = (_nearby_crate_idx >= 0)
	var has_prop: bool = (_nearby_pick_inter_idx >= 0)
	_btn_pickup.text = ""
	_btn_pickup.visible = has_gun or has_prop
	if _btn_pickup.visible:
		_update_stick_and_button_positions()


func _on_nearby_weapon_changed(crate_idx: int, w_id: int) -> void:
	_nearby_crate_idx = crate_idx if w_id >= 0 else -1
	_refresh_pick_button()


func _on_nearby_interactable_changed(inter_idx: int, label_text: String) -> void:
	_nearby_inter_idx = inter_idx
	_nearby_pick_inter_idx = inter_idx if (inter_idx >= 0 and label_text == "PICK") else -1
	if is_instance_valid(_btn_interact):
		_btn_interact.visible = (inter_idx >= 0 and label_text != "PICK")
		if _btn_interact.visible:
			_update_stick_and_button_positions()
	_refresh_pick_button()


func _on_held_prop_changed(_prop_kind: String) -> void:
	if is_instance_valid(_btn_throw_prop):
		_btn_throw_prop.visible = false
	_refresh_throw_button()


func _taunt_id_for_chat(txt: String) -> int:
	var low: String = txt.to_lower()
	if txt.contains("😜") or low.contains("ezz") or low == "ez" or low.contains(" ez"):
		return 0
	if txt.contains("😂") or low.contains("haha") or low.contains("lmao") or low.contains("lol"):
		return 9
	if low == "gg" or low.contains(" gg"):
		return 1
	if low == "nice" or low.contains("nice"):
		return 22
	if low == "ouch" or txt.contains("💨"):
		return 12
	if txt.contains("🖕"):
		return 3
	if txt.contains("❓") or low.contains("what") or low == "huh" or low == "??":
		return 11
	if txt.contains("🔥") or low == "boom" or low.contains("boom"):
		return 21
	if txt.contains("💀") or low == "rip" or low.contains("rip"):
		return 13
	if txt.contains("🤢"):
		return 20
	return -1


func _send_chat_text() -> void:
	if not is_instance_valid(_chat_input):
		return
	var txt: String = _chat_input.text.strip_edges()
	if txt.is_empty():
		return
	_chat_input.text = ""
	_chat_input.release_focus()
	NetworkManager.send_chat_message(txt)
	var mapped_id: int = _taunt_id_for_chat(txt)
	if mapped_id >= 0 and local_player != null and local_player.has_method("trigger_taunt"):
		local_player.trigger_taunt(mapped_id)


func _send_tease_emoji(em: String) -> void:
	NetworkManager.send_chat_message(em)
	if local_player != null and local_player.has_method("trigger_taunt"):
		local_player.trigger_taunt(_taunt_id_for_chat(em))


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
	_update_killfeed_offset()


func _update_killfeed_offset() -> void:
	if not is_instance_valid(_killfeed_label):
		return
	var top_y: float = 82.0
	if is_instance_valid(_chat_panel) and _chat_panel.visible:
		top_y = 324.0
	elif is_instance_valid(_chat_toast_label) and _chat_toast_label.visible:
		top_y = 156.0
	_killfeed_label.offset_top = top_y
	_killfeed_label.offset_bottom = top_y + 130.0


func _on_killfeed_event(killer_name: String, victim_name: String, weapon_name: String) -> void:
	var local_name: String = str(local_player.get("player_name")) if (local_player != null and is_instance_valid(local_player)) else NetworkManager.local_player_name
	var k_esc: String = killer_name.replace("[", "(").replace("]", ")")
	var v_esc: String = victim_name.replace("[", "(").replace("]", ")")
	var w_esc: String = weapon_name.replace("[", "(").replace("]", ")")
	var bb_line: String
	if victim_name == local_name:
		bb_line = "[right][bgcolor=#5e1818][color=#ff7070] %s (%s) → %s [/color][/bgcolor][/right]" % [k_esc, w_esc, v_esc]
	elif killer_name == local_name:
		bb_line = "[right][bgcolor=#164a22][color=#66ff88] %s (%s) → %s [/color][/bgcolor][/right]" % [k_esc, w_esc, v_esc]
	else:
		bb_line = "[right][color=#d4dce8]%s (%s) → %s[/color][/right]" % [k_esc, w_esc, v_esc]
	_killfeed_lines.append({"text": bb_line, "ttl": 1.0})
	if _killfeed_lines.size() > 5:
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
	if not is_instance_valid(_net_status_label) or not is_instance_valid(_map_mode_label) or not is_instance_valid(_scoreboard_label):
		return
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
		rows.append("%s%s  |  K:%d  A:%d  D:%d" % [team_tag, str(p.get("name", "Trooper")), int(p.get("kills", 0)), int(p.get("assists", 0)), int(p.get("deaths", 0))])
	_scoreboard_label.text = "\n".join(rows)
	if is_instance_valid(_kad_label):
		var local_pid: int = local_player.peer_id if (local_player != null and is_instance_valid(local_player)) else NetworkManager.get_local_peer_id()
		if NetworkManager.players.has(local_pid):
			var lp: Dictionary = NetworkManager.players[local_pid]
			_kad_label.text = "K:%d  A:%d  D:%d" % [int(lp.get("kills", 0)), int(lp.get("assists", 0)), int(lp.get("deaths", 0))]

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
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	_style_circle_btn(btn, bg, border, 74, 11)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 1)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(icon_rect)

	var status_lbl := Label.new()
	status_lbl.text = title
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(status_lbl)

	btn.set_meta("icon_rect", icon_rect)
	btn.set_meta("status_lbl", status_lbl)
	btn.pressed.connect(func():
		if local_player != null:
			local_player.use_agent_ability(slot_idx)
	)
	return btn


func _on_agent_state_changed(cooldowns: Array, max_cooldowns: Array, held_throwable: int, stun_left: float) -> void:
	_refresh_agent_hud(cooldowns, max_cooldowns, held_throwable, stun_left)
	_refresh_throw_button()


func _refresh_agent_hud(cooldowns: Array, max_cooldowns: Array, held_throwable: int, stun_left: float) -> void:
	if not NetworkManager.is_agent_clash_mode():
		return
	var arch_id: int = int(local_player.get("archetype_id")) if local_player != null else ProfileManager.archetype_id
	_refresh_top_info_pill()
	var btns: Array[Button] = [_btn_ability_1, _btn_ability_2, _btn_ability_3, _btn_ult]
	var kill_prog: int = int(local_player.get("ability_kill_progress")) if local_player != null else 0
	var ult_pts: int = int(local_player.get("ult_points")) if local_player != null else 0
	var ab_lock: float = float(local_player.get("ability_lock_timer")) if local_player != null else 0.0
	var frz_t: float = float(local_player.get("freeze_timer")) if local_player != null else 0.0
	for i in range(4):
		var btn: Button = btns[i]
		if not is_instance_valid(btn):
			continue
		var ab: Dictionary = local_player.get_active_ability_slot(i) if (local_player != null and local_player.has_method("get_active_ability_slot")) else AgentData.get_ability_slot(arch_id, i)
		var ab_kind: String = str(ab.get("kind", ""))
		var icon_rect: TextureRect = btn.get_meta("icon_rect") as TextureRect if btn.has_meta("icon_rect") else null
		var status_lbl: Label = btn.get_meta("status_lbl") as Label if btn.has_meta("status_lbl") else null
		if is_instance_valid(icon_rect):
			icon_rect.texture = AgentData.get_ability_icon_texture(ab_kind)
		var cd: float = float(cooldowns[i]) if i < cooldowns.size() else 0.0
		var max_cd: float = float(max_cooldowns[i]) if i < max_cooldowns.size() else 1.0
		var _unused := max_cd
		var st_txt: String = "READY"
		if frz_t > 0.0:
			st_txt = "FRZ"
			btn.modulate = Color(0.45, 0.85, 1.0)
		elif ab_lock > 0.0:
			st_txt = "LOCK"
			btn.modulate = Color(0.48, 0.48, 0.56)
		elif stun_left > 0.0:
			st_txt = "STUN"
			btn.modulate = Color(0.55, 0.65, 0.78)
		elif i == 3:
			if ult_pts < 4:
				st_txt = "%d/4 ULT" % ult_pts
				btn.modulate = Color(0.65, 0.68, 0.74)
			else:
				st_txt = "ULT!"
				btn.modulate = Color(1.0, 0.36, 0.36)
		elif cd > 0.05:
			st_txt = "%d/2" % kill_prog
			btn.modulate = Color(0.65, 0.68, 0.74)
		else:
			st_txt = "READY"
			btn.modulate = Color(1.0, 0.86, 0.42) if i == 0 else Color(0.95, 0.98, 1.0)
		if is_instance_valid(status_lbl):
			status_lbl.text = st_txt

	_refresh_pick_button()

	if is_instance_valid(_stun_banner) and is_instance_valid(_stun_label):
		_stun_banner.visible = stun_left > 0.0
		if stun_left > 0.0:
			_stun_label.text = "STUNNED! %.1fs" % stun_left


func _on_bombs_changed(count: int, bomb_type: String) -> void:
	if not is_instance_valid(_btn_bomb):
		return
	var ic: HudBtnIcon = _btn_bomb.get_meta("hud_icon") as HudBtnIcon if _btn_bomb.has_meta("hud_icon") else null
	if ic != null:
		ic.bomb_type = "frag" if bomb_type.is_empty() else bomb_type
		ic.count = maxi(0, count)
		ic.queue_redraw()
	_btn_bomb.text = ""
	_btn_bomb.visible = (not NetworkManager.is_agent_clash_mode()) and NetworkManager.allow_explosives
	if is_instance_valid(_bomb_hud_icon):
		_bomb_hud_icon.bomb_type = bomb_type
		_bomb_hud_icon.queue_redraw()
	if is_instance_valid(_bomb_hud_label):
		_bomb_hud_label.text = "%d" % maxi(0, count)
	_btn_bomb.modulate = Color.WHITE if count > 0 else Color(0.55, 0.58, 0.65)


func _on_zoom_changed(zoom_level: int, max_zoom: int) -> void:
	if not is_instance_valid(_btn_zoom):
		return
	var ic: HudBtnIcon = _btn_zoom.get_meta("hud_icon") as HudBtnIcon if _btn_zoom.has_meta("hud_icon") else null
	if ic != null:
		ic.zoom_level = zoom_level
		ic.max_zoom = max_zoom
		ic.queue_redraw()
	_btn_zoom.text = ""
	_btn_zoom.visible = not NetworkManager.is_agent_clash_mode()
	_btn_zoom.modulate = Color(0.45, 0.92, 1.0) if zoom_level > 1 else Color.WHITE


func _build_preset_overlay() -> void:
	_preset_backdrop = ColorRect.new()
	_preset_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preset_backdrop.color = Color(0.02, 0.04, 0.08, 0.58)
	_preset_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_preset_backdrop.z_index = 40
	_preset_backdrop.visible = false
	add_child(_preset_backdrop)

	_preset_overlay = PanelContainer.new()
	_preset_overlay.anchor_left = 0.5
	_preset_overlay.anchor_right = 0.5
	_preset_overlay.anchor_top = 0.5
	_preset_overlay.anchor_bottom = 0.5
	_preset_overlay.offset_left = -360
	_preset_overlay.offset_right = 360
	_preset_overlay.offset_top = -245
	_preset_overlay.offset_bottom = 245
	_preset_overlay.visible = false
	_preset_overlay.add_theme_stylebox_override("panel", UIStyle.make_card_stylebox("blue", Color(0.16, 0.22, 0.34, 0.98), 16, 14))
	_preset_overlay.visibility_changed.connect(func():
		if is_instance_valid(_preset_backdrop):
			_preset_backdrop.visible = _preset_overlay.visible
	)
	_preset_backdrop.add_child(_preset_overlay)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	_preset_overlay.add_child(pv)

	var hdr := HBoxContainer.new()
	pv.add_child(hdr)

	_preset_timer_label = Label.new()
	_preset_timer_label.text = "CHOOSE 2-GUN + BOMBS PRESET"
	_preset_timer_label.add_theme_font_size_override("font_size", 18)
	_preset_timer_label.modulate = Color(1.0, 0.86, 0.28)
	_preset_timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_preset_timer_label)

	var rand_btn := Button.new()
	rand_btn.text = "RANDOM"
	rand_btn.custom_minimum_size = Vector2(110, 36)
	rand_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(rand_btn, "purple", "", 12, 6)
	rand_btn.pressed.connect(func():
		var r_idx: int = randi() % WeaponData.GUN_PRESETS.size()
		_confirm_preset(r_idx)
	)
	hdr.add_child(rand_btn)

	var keep_btn := Button.new()
	keep_btn.text = "KEEP DEFAULT"
	keep_btn.custom_minimum_size = Vector2(130, 36)
	keep_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(keep_btn, "sky", "close", 12, 6)
	keep_btn.pressed.connect(func(): _confirm_preset(_chosen_preset_idx if _chosen_preset_idx >= 0 else 0))
	hdr.add_child(keep_btn)

	var leave_btn := Button.new()
	leave_btn.text = "LEAVE MATCH"
	leave_btn.custom_minimum_size = Vector2(126, 36)
	leave_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(leave_btn, "red", "", 12, 6)
	leave_btn.pressed.connect(func():
		_preset_overlay.visible = false
		_set_preset_pause(false)
		get_tree().paused = false
		NetworkManager.disconnect_network()
		NetworkManager.go_to_main_menu()
	)
	hdr.add_child(leave_btn)

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
		title_lbl.custom_minimum_size = Vector2(145, 0)
		title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 13)
		row_h.add_child(title_lbl)

		var pri_icon := TextureRect.new()
		pri_icon.name = "PriIcon"
		pri_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pri_icon.custom_minimum_size = Vector2(92, 48)
		pri_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pri_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_h.add_child(pri_icon)

		var pri_lbl := Label.new()
		pri_lbl.name = "PriLbl"
		pri_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pri_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pri_lbl.clip_text = true
		pri_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pri_lbl.add_theme_font_size_override("font_size", 13)
		row_h.add_child(pri_lbl)

		var sec_icon := TextureRect.new()
		sec_icon.name = "SecIcon"
		sec_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sec_icon.custom_minimum_size = Vector2(80, 44)
		sec_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sec_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_h.add_child(sec_icon)

		var sec_lbl := Label.new()
		sec_lbl.name = "SecLbl"
		sec_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sec_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sec_lbl.clip_text = true
		sec_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sec_lbl.add_theme_font_size_override("font_size", 13)
		row_h.add_child(sec_lbl)

		var bomb_icon := TextureRect.new()
		bomb_icon.name = "BombIcon"
		bomb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bomb_icon.custom_minimum_size = Vector2(42, 42)
		bomb_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bomb_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row_h.add_child(bomb_icon)

	_refresh_preset_cards()


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
			at_p.region = Rect2(w_pri.sprite_frame * 256, 0, 256, 128)
			(row_h.get_node("PriIcon") as TextureRect).texture = at_p
			var at_s := AtlasTexture.new()
			at_s.atlas = WEAPONS_TEX
			at_s.region = Rect2(w_sec.sprite_frame * 256, 0, 256, 128)
			(row_h.get_node("SecIcon") as TextureRect).texture = at_s
			var b_icon := row_h.get_node("BombIcon") as TextureRect
			b_icon.visible = bombs_n > 0
			match b_type:
				"cluster": b_icon.texture = BombHudIcon.TEX_BOMB_CLUSTER
				"sticky": b_icon.texture = BombHudIcon.TEX_BOMB_STICKY
				"time": b_icon.texture = BombHudIcon.TEX_BOMB_TIME
				"mine": b_icon.texture = BombHudIcon.TEX_BOMB_MINE
				_: b_icon.texture = BombHudIcon.TEX_BOMB_FRAG


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


func _sync_offline_pause_state() -> void:
	var preset_open: bool = is_instance_valid(_preset_overlay) and _preset_overlay.visible
	var menu_vis: bool = (is_instance_valid(_drawer_panel) and _drawer_panel.visible) or (is_instance_valid(_layout_overlay) and _layout_overlay.visible)
	if menu_vis and is_instance_valid(_respawn_panel):
		_respawn_panel.visible = false
	var offline_only: bool = not NetworkManager.is_network_active()
	var drawer_open: bool = offline_only and is_instance_valid(_drawer_panel) and _drawer_panel.visible
	var layout_open: bool = offline_only and is_instance_valid(_layout_overlay) and _layout_overlay.visible
	_set_preset_pause(preset_open or drawer_open or layout_open)


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
	if NetworkManager.is_agent_clash_mode() or NetworkManager.random_guns_mode:
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


func _build_match_end_overlay() -> void:
	_match_end_overlay = ColorRect.new()
	_match_end_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_end_overlay.color = Color(0.02, 0.03, 0.06, 0.88)
	_match_end_overlay.visible = false
	add_child(_match_end_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_end_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	sb.border_color = Color(1.0, 0.84, 0.24, 0.98)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	sb.shadow_color = Color(1.0, 0.82, 0.22, 0.36)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2.ZERO
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	_match_end_title = Label.new()
	_match_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_match_end_title.add_theme_font_size_override("font_size", 30)
	_match_end_title.modulate = Color(1.0, 0.84, 0.24)
	vb.add_child(_match_end_title)

	var hdr_panel := PanelContainer.new()
	var hdr_sb := StyleBoxFlat.new()
	hdr_sb.bg_color = Color(0.11, 0.16, 0.26, 0.96)
	hdr_sb.set_corner_radius_all(8)
	hdr_sb.set_content_margin_all(8)
	hdr_panel.add_theme_stylebox_override("panel", hdr_sb)
	vb.add_child(hdr_panel)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 6)
	hdr_panel.add_child(hdr_row)
	var col_specs: Array = [
		["RANK", 62, Color(0.76, 0.82, 0.94), HORIZONTAL_ALIGNMENT_CENTER],
		["PLAYER", 0, Color(0.76, 0.82, 0.94), HORIZONTAL_ALIGNMENT_LEFT],
		["KILLS", 68, Color(0.45, 0.96, 0.56), HORIZONTAL_ALIGNMENT_CENTER],
		["ASSISTS", 74, Color(0.42, 0.86, 1.0), HORIZONTAL_ALIGNMENT_CENTER],
		["DEATHS", 70, Color(1.0, 0.48, 0.46), HORIZONTAL_ALIGNMENT_CENTER],
		["COMBOS", 78, Color(1.0, 0.84, 0.35), HORIZONTAL_ALIGNMENT_CENTER]
	]
	for spec in col_specs:
		var h_lbl := Label.new()
		h_lbl.text = str(spec[0])
		if int(spec[1]) > 0:
			h_lbl.custom_minimum_size = Vector2(float(spec[1]), 0)
		else:
			h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_lbl.horizontal_alignment = spec[3]
		h_lbl.add_theme_font_size_override("font_size", 13)
		h_lbl.modulate = spec[2]
		hdr_row.add_child(h_lbl)

	var rows_scroll := ScrollContainer.new()
	rows_scroll.custom_minimum_size = Vector2(600, 240)
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(rows_scroll)

	_match_end_table = VBoxContainer.new()
	_match_end_table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_match_end_table.add_theme_constant_override("separation", 6)
	rows_scroll.add_child(_match_end_table)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	_match_end_again_btn = Button.new()
	_match_end_again_btn.text = "PLAY AGAIN"
	_match_end_again_btn.custom_minimum_size = Vector2(0, 50)
	_match_end_again_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_match_end_again_btn.add_theme_font_size_override("font_size", 18)
	UIStyle.style_layer_button(_match_end_again_btn, "green", "", 10, 6)
	_match_end_again_btn.pressed.connect(func():
		if NetworkManager.is_network_active():
			if NetworkManager.is_local_leader():
				NetworkManager.request_start_match()
		else:
			NetworkManager.go_to_arena()
	)
	btn_row.add_child(_match_end_again_btn)

	_match_end_lobby_btn = Button.new()
	_match_end_lobby_btn.text = "LOBBY"
	_match_end_lobby_btn.custom_minimum_size = Vector2(0, 50)
	_match_end_lobby_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_match_end_lobby_btn.add_theme_font_size_override("font_size", 18)
	UIStyle.style_layer_button(_match_end_lobby_btn, "green", "", 10, 6)
	_match_end_lobby_btn.pressed.connect(func():
		if NetworkManager.is_network_active() and not NetworkManager.is_local_leader():
			NetworkManager.set_local_ready(true)
		NetworkManager.go_to_lobby()
	)
	btn_row.add_child(_match_end_lobby_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MAIN MENU"
	menu_btn.custom_minimum_size = Vector2(0, 50)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.add_theme_font_size_override("font_size", 18)
	UIStyle.style_layer_button(menu_btn, "blue", "", 10, 6)
	menu_btn.pressed.connect(func():
		NetworkManager.disconnect_network()
		NetworkManager.go_to_main_menu()
	)
	btn_row.add_child(menu_btn)


func _on_match_timer_updated(t_left: float) -> void:
	if is_instance_valid(_match_timer_pill):
		_match_timer_pill.visible = not NetworkManager.is_test_mode()
	if not is_instance_valid(_match_timer_label):
		return
	var secs: int = maxi(0, int(ceil(t_left)))
	var mm: int = secs / 60
	var ss: int = secs % 60
	_match_timer_label.text = "%02d:%02d" % [mm, ss]
	if secs <= 10:
		_match_timer_label.modulate = Color(1.0, 0.32, 0.28)
	elif secs <= 30:
		_match_timer_label.modulate = Color(1.0, 0.78, 0.24)
	else:
		_match_timer_label.modulate = Color(0.95, 0.96, 1.0)


func _on_combo_achieved(killer_id: int, killer_name: String, combo_count: int) -> void:
	var local_pid: int = local_player.peer_id if (local_player != null and is_instance_valid(local_player)) else NetworkManager.get_local_peer_id()
	if killer_id != local_pid or not is_instance_valid(_combo_banner_label):
		return
	_combo_banner_label.text = "%dx COMBO! (%s)" % [combo_count, killer_name]
	_combo_banner_label.visible = true
	_combo_banner_label.modulate.a = 1.0
	_combo_banner_label.scale = Vector2(1.2, 1.2)
	var tw := create_tween()
	tw.tween_property(_combo_banner_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.5)
	tw.tween_property(_combo_banner_label, "modulate:a", 0.0, 0.4)
	tw.finished.connect(func():
		if is_instance_valid(_combo_banner_label):
			_combo_banner_label.visible = false
	)


func _on_match_ended(winner_text: String, rankings: Array) -> void:
	if not is_instance_valid(_match_end_overlay) or not is_instance_valid(_match_end_table):
		return
	var is_net_client: bool = NetworkManager.is_network_active() and not NetworkManager.is_local_leader()
	if is_instance_valid(_match_end_again_btn):
		_match_end_again_btn.visible = not is_net_client
	if is_instance_valid(_match_end_lobby_btn):
		_match_end_lobby_btn.visible = NetworkManager.is_network_active()
	_match_end_title.text = winner_text
	for ch in _match_end_table.get_children():
		ch.queue_free()

	var local_name: String = str(local_player.get("player_name")) if (local_player != null and is_instance_valid(local_player)) else NetworkManager.local_player_name
	for i in range(rankings.size()):
		var r: Dictionary = rankings[i] as Dictionary
		var p_name: String = str(r.get("name", "Player"))
		var is_local: bool = (p_name == local_name)
		var is_first: bool = (i == 0)

		var row_panel := PanelContainer.new()
		var r_sb := StyleBoxFlat.new()
		if is_first:
			r_sb.bg_color = Color(0.22, 0.17, 0.07, 0.92)
			r_sb.border_color = Color(1.0, 0.82, 0.26, 0.90)
			r_sb.set_border_width_all(2)
		elif is_local:
			r_sb.bg_color = Color(0.10, 0.19, 0.30, 0.92)
			r_sb.border_color = Color(0.35, 0.78, 1.0, 0.90)
			r_sb.set_border_width_all(2)
		else:
			r_sb.bg_color = Color(0.09, 0.13, 0.21, 0.88) if (i % 2 == 0) else Color(0.07, 0.10, 0.17, 0.88)
			r_sb.border_color = Color(0.22, 0.28, 0.40, 0.45)
			r_sb.set_border_width_all(1)
		r_sb.set_corner_radius_all(8)
		r_sb.set_content_margin_all(8)
		row_panel.add_theme_stylebox_override("panel", r_sb)
		_match_end_table.add_child(row_panel)

		var row_hb := HBoxContainer.new()
		row_hb.add_theme_constant_override("separation", 6)
		row_panel.add_child(row_hb)

		var rank_col: Color = Color(1.0, 0.86, 0.28) if i == 0 else (Color(0.84, 0.88, 0.96) if i == 1 else (Color(0.88, 0.62, 0.38) if i == 2 else Color(0.68, 0.74, 0.86)))
		var rank_txt: String = ("🏆 #1" if i == 0 else "#%d" % [i + 1])
		var cells: Array = [
			[rank_txt, 62, rank_col, HORIZONTAL_ALIGNMENT_CENTER],
			[p_name + (" (YOU)" if is_local else ""), 0, Color(0.45, 0.90, 1.0) if is_local else Color(0.94, 0.96, 1.0), HORIZONTAL_ALIGNMENT_LEFT],
			[str(int(r.get("kills", 0))), 68, Color(0.48, 0.98, 0.58), HORIZONTAL_ALIGNMENT_CENTER],
			[str(int(r.get("assists", 0))), 74, Color(0.46, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER],
			[str(int(r.get("deaths", 0))), 70, Color(1.0, 0.50, 0.48), HORIZONTAL_ALIGNMENT_CENTER],
			[str(int(r.get("combos", 0))), 78, Color(1.0, 0.86, 0.38), HORIZONTAL_ALIGNMENT_CENTER]
		]
		for cell in cells:
			var c_lbl := Label.new()
			c_lbl.text = str(cell[0])
			if int(cell[1]) > 0:
				c_lbl.custom_minimum_size = Vector2(float(cell[1]), 0)
			else:
				c_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				c_lbl.clip_text = true
			c_lbl.horizontal_alignment = cell[3]
			c_lbl.add_theme_font_size_override("font_size", 16)
			c_lbl.modulate = cell[2]
			row_hb.add_child(c_lbl)

	_match_end_overlay.visible = true


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
		_sync_offline_pause_state()
	)
	row.add_child(done_btn)

	var handle_specs: Array[Dictionary] = [
		{"key": "left_stick", "label": "DRAG\nMOVE STICK", "size": Vector2(188, 188), "col": Color(0.25, 0.68, 1.0)},
		{"key": "right_stick", "label": "DRAG\nAIM & FIRE", "size": Vector2(188, 188), "col": Color(1.0, 0.48, 0.22)},
		{"key": "btn_reload", "label": "RLD", "size": Vector2(70, 70), "col": Color(0.68, 0.80, 0.98)},
		{"key": "btn_bomb", "label": "BOMB", "size": Vector2(78, 78), "col": Color(1.0, 0.56, 0.16)},
		{"key": "ability_0", "label": "AB1", "size": Vector2(74, 74), "col": Color(1.0, 0.84, 0.24)},
		{"key": "ability_1", "label": "AB2", "size": Vector2(74, 74), "col": Color(0.45, 0.95, 0.65)},
		{"key": "ability_2", "label": "AB3", "size": Vector2(74, 74), "col": Color(0.76, 0.50, 1.0)},
		{"key": "ability_3", "label": "ULT", "size": Vector2(74, 74), "col": Color(1.0, 0.28, 0.28)}
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
	if is_instance_valid(_drawer_panel):
		_drawer_panel.visible = false
	_dragging_key = ""
	_layout_overlay.visible = true
	_position_hud_layout_handles()
	_sync_offline_pause_state()


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


class BombHudIcon extends Control:
	const TEX_BOMB_TIME: Texture2D = preload("res://assets/sprites/weapons/bomb_time.png")
	const TEX_BOMB_FRAG: Texture2D = preload("res://assets/sprites/weapons/bomb_frag.png")
	const TEX_BOMB_MINE: Texture2D = preload("res://assets/sprites/weapons/bomb_mine.png")
	const TEX_BOMB_CLUSTER: Texture2D = preload("res://assets/sprites/weapons/bomb_cluster.png")
	const TEX_BOMB_STICKY: Texture2D = preload("res://assets/sprites/weapons/bomb_sticky.png")
	var bomb_type: String = "frag"

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.52)
		var r := Rect2(c - Vector2(14.0, 14.0), Vector2(28.0, 28.0))
		match bomb_type:
			"cluster":
				draw_texture_rect(TEX_BOMB_CLUSTER, r, false)
			"sticky":
				draw_texture_rect(TEX_BOMB_STICKY, r, false)
			"time":
				draw_texture_rect(TEX_BOMB_TIME, r, false)
			"mine":
				draw_texture_rect(TEX_BOMB_MINE, r, false)
			_:
				draw_texture_rect(TEX_BOMB_FRAG, r, false)

