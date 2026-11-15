extends CanvasLayer

signal add_bot_requested

const WEAPONS_TEX: Texture2D = preload("res://assets/sprites/weapons_sheet.png")
const STICK_RADIUS: float = 76.0
const KNOB_RADIUS: float = 28.0

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
var _killfeed_label: Label
var _respawn_panel: PanelContainer
var _respawn_label: Label
var _add_bot_btn: Button

var _btn_reload: Button
var _btn_switch: Button
var _btn_dual: Button


func _ready() -> void:
	_build_ui()
	NetworkManager.player_list_updated.connect(_refresh_scoreboard)
	NetworkManager.killfeed_event.connect(_on_killfeed_event)
	SettingsManager.touch_layout_changed.connect(_update_stick_and_button_positions)
	_refresh_scoreboard()
	_update_stick_and_button_positions()


func _process(delta: float) -> void:
	_update_stick_and_button_positions()
	_tick_killfeed(delta)
	_push_input_to_player()
	_update_scope_overlay()

	if Input.is_action_just_pressed("open_lobby"):
		NetworkManager.go_to_lobby()


func _update_scope_overlay() -> void:
	if not is_instance_valid(_scope_overlay):
		return
	var show_scope: bool = (
		local_player != null
		and local_player.is_alive()
		and _active_weapon != null
		and _active_weapon.scope_zoom < 0.95
	)
	_scope_overlay.visible = show_scope
	if show_scope:
		_scope_overlay.queue_redraw()


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


func _update_stick_and_button_positions() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_left_center = SettingsManager.get_touch_element_px("left_stick", vp_size)
	_right_center = SettingsManager.get_touch_element_px("right_stick", vp_size)
	if is_instance_valid(_btn_reload):
		_btn_reload.position = SettingsManager.get_touch_element_px("btn_reload", vp_size) - _btn_reload.size * 0.5
	if is_instance_valid(_btn_switch):
		_btn_switch.position = SettingsManager.get_touch_element_px("btn_switch", vp_size) - _btn_switch.size * 0.5
	if is_instance_valid(_btn_dual):
		_btn_dual.position = SettingsManager.get_touch_element_px("btn_dual", vp_size) - _btn_dual.size * 0.5
	if is_instance_valid(_stick_canvas):
		_stick_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
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
	var left_norm: Vector2 = _left_knob_offset / STICK_RADIUS
	var right_norm: Vector2 = _right_knob_offset / STICK_RADIUS
	local_player.virtual_move = left_norm
	local_player.virtual_jetpack = (left_norm.y < -0.45)
	local_player.virtual_aim = right_norm * SettingsManager.aim_stick_sensitivity
	local_player.virtual_fire = (right_norm.length() * SettingsManager.aim_stick_sensitivity > 0.52)

	var hovered: Control = get_viewport().gui_get_hovered_control()
	local_player.pointer_over_ui = (hovered != null and hovered != _stick_canvas) or _left_mouse_active or _right_mouse_active


func _on_stick_canvas_draw() -> void:
	var bg_col := Color(0.08, 0.12, 0.18, 0.42)
	var border_col := Color(0.55, 0.72, 0.92, 0.55)
	var knob_col_l := Color(0.28, 0.72, 1.0, 0.78)
	var knob_col_r := Color(1.0, 0.45, 0.22, 0.82)

	_stick_canvas.draw_circle(_left_center, STICK_RADIUS, bg_col)
	_stick_canvas.draw_arc(_left_center, STICK_RADIUS, 0.0, TAU, 36, border_col, 2.5)
	_stick_canvas.draw_circle(_left_center + _left_knob_offset, KNOB_RADIUS, knob_col_l)

	_stick_canvas.draw_circle(_right_center, STICK_RADIUS, bg_col)
	_stick_canvas.draw_arc(_right_center, STICK_RADIUS, 0.0, TAU, 36, Color(1.0, 0.52, 0.24, 0.6), 2.5)
	_stick_canvas.draw_arc(_right_center, STICK_RADIUS * 0.52, 0.0, TAU, 28, Color(1.0, 0.35, 0.2, 0.32), 1.5)
	_stick_canvas.draw_circle(_right_center + _right_knob_offset, KNOB_RADIUS, knob_col_r)


func _make_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


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


func _style_action_button(btn: Button, bg: Color, border: Color, font_sz: int = 15) -> void:
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_stylebox_override("normal", _make_hud_btn_style(bg, border))
	btn.add_theme_stylebox_override("hover", _make_hud_btn_style(bg.lightened(0.14), border.lightened(0.3)))
	btn.add_theme_stylebox_override("pressed", _make_hud_btn_style(border.darkened(0.35), border.lightened(0.45)))


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

	# Top-Left Status Card
	var left_panel := PanelContainer.new()
	left_panel.position = Vector2(14, 14)
	left_panel.custom_minimum_size = Vector2(300, 0)
	left_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.14, 0.84), Color(0.24, 0.56, 0.85, 0.85)))
	add_child(left_panel)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left_panel.add_child(lv)

	var hp_row := HBoxContainer.new()
	lv.add_child(hp_row)
	_hp_label = Label.new()
	_hp_label.text = "HP 100"
	_hp_label.custom_minimum_size = Vector2(72, 0)
	hp_row.add_child(_hp_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.show_percentage = false
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.custom_minimum_size = Vector2(0, 16)
	_hp_bar.modulate = Color(0.28, 0.92, 0.45)
	hp_row.add_child(_hp_bar)

	var fuel_row := HBoxContainer.new()
	lv.add_child(fuel_row)
	_fuel_label = Label.new()
	_fuel_label.text = "JET 100%"
	_fuel_label.custom_minimum_size = Vector2(72, 0)
	fuel_row.add_child(_fuel_label)

	_fuel_bar = ProgressBar.new()
	_fuel_bar.max_value = 100
	_fuel_bar.value = 100
	_fuel_bar.show_percentage = false
	_fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fuel_bar.custom_minimum_size = Vector2(0, 14)
	_fuel_bar.modulate = Color(1.0, 0.72, 0.18)
	fuel_row.add_child(_fuel_bar)

	var w_row := HBoxContainer.new()
	w_row.add_theme_constant_override("separation", 8)
	lv.add_child(w_row)

	var atlas := AtlasTexture.new()
	atlas.atlas = WEAPONS_TEX
	atlas.region = Rect2(0, 0, 64, 32)
	_weapon_icon = TextureRect.new()
	_weapon_icon.texture = atlas
	_weapon_icon.custom_minimum_size = Vector2(56, 28)
	_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	w_row.add_child(_weapon_icon)

	var w_info := VBoxContainer.new()
	w_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w_row.add_child(w_info)

	_weapon_name_label = Label.new()
	_weapon_name_label.text = "Assault Rifle"
	w_info.add_child(_weapon_name_label)

	_ammo_label = Label.new()
	_ammo_label.text = "30 / 30"
	_ammo_label.modulate = Color(1.0, 0.88, 0.4)
	w_info.add_child(_ammo_label)

	_dual_badge = Label.new()
	_dual_badge.text = "DUAL"
	_dual_badge.modulate = Color(0.25, 0.95, 1.0)
	_dual_badge.visible = false
	w_row.add_child(_dual_badge)

	# Customizable Touch Action Buttons (positioned via SettingsManager.touch_layout)
	_btn_reload = Button.new()
	_btn_reload.text = "RELOAD"
	_btn_reload.custom_minimum_size = Vector2(108, 48)
	_btn_reload.size = Vector2(108, 48)
	_btn_reload.focus_mode = Control.FOCUS_NONE
	_style_action_button(_btn_reload, Color(0.10, 0.16, 0.26, 0.92), Color(0.55, 0.78, 1.0, 0.9))
	_btn_reload.pressed.connect(func():
		if local_player != null:
			local_player.start_reload()
	)
	add_child(_btn_reload)

	_btn_switch = Button.new()
	_btn_switch.text = "SWAP GUN"
	_btn_switch.custom_minimum_size = Vector2(108, 48)
	_btn_switch.size = Vector2(108, 48)
	_btn_switch.focus_mode = Control.FOCUS_NONE
	_style_action_button(_btn_switch, Color(0.22, 0.16, 0.08, 0.92), Color(1.0, 0.72, 0.24, 0.9))
	_btn_switch.pressed.connect(func():
		if local_player != null:
			local_player.cycle_weapon()
	)
	add_child(_btn_switch)

	_btn_dual = Button.new()
	_btn_dual.text = "DUAL"
	_btn_dual.custom_minimum_size = Vector2(108, 48)
	_btn_dual.size = Vector2(108, 48)
	_btn_dual.focus_mode = Control.FOCUS_NONE
	_style_action_button(_btn_dual, Color(0.08, 0.22, 0.26, 0.92), Color(0.25, 0.92, 1.0, 0.9))
	_btn_dual.pressed.connect(func():
		if local_player != null:
			local_player.toggle_dual_wield()
	)
	add_child(_btn_dual)

	# Top-Right Match & Scoreboard Panel
	var right_panel := PanelContainer.new()
	right_panel.anchor_left = 1.0
	right_panel.anchor_right = 1.0
	right_panel.offset_left = -330
	right_panel.offset_right = -14
	right_panel.offset_top = 14
	right_panel.offset_bottom = 260
	right_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.09, 0.14, 0.84), Color(0.95, 0.55, 0.15, 0.85)))
	add_child(right_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 5)
	right_panel.add_child(rv)

	_net_status_label = Label.new()
	_net_status_label.text = "NAMELESS CLASH"
	_net_status_label.modulate = Color(1.0, 0.78, 0.25)
	rv.add_child(_net_status_label)

	_map_mode_label = Label.new()
	_map_mode_label.text = "Bunker Base • Solo"
	_map_mode_label.modulate = Color(0.82, 0.92, 0.72)
	rv.add_child(_map_mode_label)

	_scoreboard_label = Label.new()
	_scoreboard_label.text = "Loading..."
	rv.add_child(_scoreboard_label)

	_killfeed_label = Label.new()
	_killfeed_label.text = ""
	_killfeed_label.modulate = Color(1.0, 0.72, 0.55)
	rv.add_child(_killfeed_label)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 8)
	rv.add_child(nav_row)

	_add_bot_btn = Button.new()
	_add_bot_btn.text = "+ BOT"
	_add_bot_btn.custom_minimum_size = Vector2(90, 38)
	_add_bot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_bot_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(_add_bot_btn, Color(0.10, 0.26, 0.16, 0.94), Color(0.32, 0.92, 0.48), 14)
	_add_bot_btn.visible = not NetworkManager.is_network_active() or NetworkManager.is_host_active()
	_add_bot_btn.pressed.connect(func(): add_bot_requested.emit())
	nav_row.add_child(_add_bot_btn)

	var menu_btn := Button.new()
	menu_btn.text = "MENU"
	menu_btn.custom_minimum_size = Vector2(90, 38)
	menu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_btn.focus_mode = Control.FOCUS_NONE
	_style_action_button(menu_btn, Color(0.24, 0.12, 0.14, 0.94), Color(0.95, 0.42, 0.36), 14)
	menu_btn.pressed.connect(func(): NetworkManager.go_to_main_menu())
	nav_row.add_child(menu_btn)

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


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "HP %d" % current


func _on_fuel_changed(current: float, maximum: float) -> void:
	_fuel_bar.max_value = maximum
	_fuel_bar.value = current
	_fuel_label.text = "JET %d%%" % int(round(current))


func _on_ammo_changed(current: int, mag_size: int, is_reloading: bool) -> void:
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


func _on_killfeed_event(killer_name: String, victim_name: String, weapon_name: String) -> void:
	var line: String = "%s [%s] -> %s" % [killer_name, weapon_name, victim_name]
	_killfeed_lines.append({"text": line, "ttl": 5.5})
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
		if NetworkManager.match_mode == 1:
			team_tag = "[BLUE] " if int(p.get("team", 0)) == 0 else "[RED] "
		rows.append("%s%s  |  K:%d  D:%d" % [team_tag, str(p.get("name", "Trooper")), int(p.get("kills", 0)), int(p.get("deaths", 0))])
	_scoreboard_label.text = "\n".join(rows)
