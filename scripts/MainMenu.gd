extends Control

const UIStyle = preload("res://scripts/UIStyle.gd")
const TEX_BG: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const TEX_ICON: Texture2D = preload("res://icon.svg")

var _hub_container: Control
var _credits_overlay: Control
var _preview: SoldierPreview
var _callsign_label: Label
var _loadout_label: Label
var _coin_pill_lbl: Label
var _coin_icon_cache: Texture2D = null
var _mute_top_btn: Button
var _sound_on_icon_cache: Texture2D = null
var _sound_off_icon_cache: Texture2D = null
var _shop_overlay: Control
var _shop_coin_lbl: Label
var _shop_gun_preview: TextureRect
var _shop_gun_title: Label
var _shop_gun_desc_lbl: Label
var _shop_stats_box: VBoxContainer
var _shop_skin_grid: GridContainer
var _shop_status_lbl: Label
var _shop_gun_btns: Dictionary = {}
var _shop_selected_weapon_id: int = 0
var _shop_preview_skin_key: String = ""
var _crate_overlay: Control
var _crate_top_btn: Button
var _crate_coin_lbl: Label
var _daily_claim_btn: Button
var _crate_active_is_premium: bool = false
var _crate_tab_supply_btn: Button
var _crate_tab_premium_btn: Button
var _crate_supply_page: Control
var _crate_premium_page: Control
var _crate_supply_ui: Dictionary = {}
var _crate_premium_ui: Dictionary = {}
var _crate_spinning: bool = false
var _crate_last_win: Dictionary = {}
var _crate_reveal_overlay: Control
var _crate_reveal_title: Label
var _crate_reveal_coin_lbl: Label
var _crate_reveal_sub: Label
var _crate_reveal_body: Control
var _crate_reveal_skip_btn: Button
var _crate_reveal_close_btn: Button
var _crate_reveal_equip_btn: Button
var _crate_reveal_equip_item: Dictionary = {}
var _crate_reveal_skip_requested: bool = false
var _crate_reveal_in_progress: bool = false
var _crate_bigwin_overlay: Control
var _crate_bigwin_rays: Control
var _crate_bigwin_flash: ColorRect
var _crate_bigwin_title: Label
var _crate_bigwin_sub: Label
var _crate_bigwin_cards_row: HBoxContainer
var _crate_bigwin_equip_btn: Button
var _crate_bigwin_best_item: Dictionary = {}
var _crate_bigwin_angle: float = 0.0
var _crate_bigwin_accent: Color = Color(1.0, 0.84, 0.22)
var _ach_overlay: Control
var _ach_top_btn: Button
var _ach_header_lbl: Label
var _ach_coin_lbl: Label
var _ach_list_box: VBoxContainer
var _ach_filter: String = "All"
var _ach_filter_btns: Dictionary = {}
var _ach_collapsed_parents: Dictionary = {}
var _lb_overlay: Control
var _lb_category: String = "solo"
var _lb_selected_idx: int = 0
var _lb_solo_tab_btn: Button
var _lb_local_tab_btn: Button
var _lb_top_tab_btn: Button
var _lb_summary_lbl: Label
var _lb_match_list_box: VBoxContainer
var _lb_detail_box: VBoxContainer
var _transitioning: bool = false
var _diff_buttons: Array[Button] = []
var _agent_select_overlay: Control
var _agent_preview_arena: Node2D
var _agent_kit_title: Label
var _agent_kit_body: Label
var _agent_preview_btns: Array[Button] = []
var _agent_cards: Array[Button] = []
var _agent_select_for_practice: bool = false
var _agent_preview_idx: int = 0
var _agent_play_btn: Button
var _top_shop_btn: Button
var _customize_btn: Button
var _agent_mode_btn: Button
var _coin_shop_top_btn: Button
var _coin_shop_overlay: Control
var _coin_shop_grid: GridContainer
var _coin_shop_coin_lbl: Label
var _coin_shop_return_overlay: Control = null
var _coin_purchase_popup: Control
var _settings_overlay: Control
var _coin_purchase_card: PanelContainer
var _coin_purchase_body: VBoxContainer
var _practice_agent_bot_row: HBoxContainer
var _practice_agent_bot_opt: OptionButton
var _test_mode_overlay: Control
var _test_mode_type_buttons: Array[Button] = []
var _test_bot_beh_buttons: Array[Button] = []
var _test_mode_choice: int = 2
var _test_bot_choice: int = 1
var _test_bot_agent_opt: OptionButton
var _test_grav_slider: HSlider
var _test_grav_val_lbl: Label
var _map_opt: OptionButton
var _map_select_overlay: Control
var _map_preview_tex: TextureRect
var _map_title_label: Label
var _map_preview_cache: Dictionary = {}
var _pending_map_launch: Callable
var _match_settings_overlay: Control
var _ms_for_agent: bool = false
var _ms_title_lbl: Label
var _ms_bot_val_lbl: Label
var _ms_grav_slider: HSlider
var _ms_grav_val_lbl: Label
var _ms_jet_slider: HSlider
var _ms_jet_val_lbl: Label
var _ms_timer_slider: HSlider
var _ms_timer_val_lbl: Label
var _ms_gas_chk: CheckBox
var _ms_random_guns_chk: CheckBox
var _ms_map_btn: Button
var _ms_guns_row: Control
var _ms_guns_menu: MenuButton
var _test_jet_slider: HSlider
var _test_jet_val_lbl: Label
var _local_mode_overlay: Control
var _local_host_overlay: Control
var _local_join_overlay: Control
var _lh_room_input: LineEdit
var _lh_max_lbl: Label
var _lh_mode_btn: Button
var _lh_team_row: Control
var _lh_team_lbl: Label
var _lh_bot_lbl: Label
var _lh_map_btn: Button
var _lh_grav_slider: HSlider
var _lh_grav_lbl: Label
var _lh_jet_slider: HSlider
var _lh_jet_lbl: Label
var _lh_timer_slider: HSlider
var _lh_timer_lbl: Label
var _lh_gas_chk: CheckBox
var _lh_random_guns_chk: CheckBox
var _lj_list_box: VBoxContainer
var _lj_status_lbl: Label
var _is_joining_lan: bool = false


func _ready() -> void:
	SettingsManager.play_bgm("menu")
	_build_ui()
	_play_enter_animation()


func _process(delta: float) -> void:
	if is_instance_valid(_crate_bigwin_overlay) and _crate_bigwin_overlay.visible and is_instance_valid(_crate_bigwin_rays):
		_crate_bigwin_angle += delta * 0.65
		_crate_bigwin_rays.queue_redraw()


func _variant_for_color(col: Color) -> String:
	if col.r > 0.80 and col.g < 0.45 and col.b < 0.45:
		return "red"
	if col.r > 0.80 and col.g > 0.72 and col.b < 0.45:
		return "yellow"
	if col.r > 0.80 and col.g > 0.40:
		return "orange"
	if col.g > 0.75 and col.r < 0.52:
		return "green"
	if col.b > 0.80 and col.r > 0.58 and col.g < 0.65:
		return "purple"
	if col.b > 0.82 and col.g > 0.68:
		return "sky"
	return "blue"


func _make_style(bg: Color, border: Color, corner: int = 12) -> StyleBox:
	var variant: String = _variant_for_color(border)
	if variant == "yellow" or variant == "red":
		variant = "orange"
	elif variant == "sky":
		variant = "blue"
	var mh: int = 12 if corner <= 8 else 16
	var mv: int = 8 if corner <= 8 else 14
	var tint := Color(maxf(bg.r + 0.14, 0.20), maxf(bg.g + 0.14, 0.22), maxf(bg.b + 0.14, 0.28), maxf(bg.a, 0.94))
	return UIStyle.make_card_stylebox(variant, tint, mh, mv)


func _apply_coin_button_icon(btn: Button, max_w: int = 18) -> void:
	btn.icon = _get_coin_icon()
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", max_w)
	btn.remove_theme_color_override("icon_normal_color")
	btn.remove_theme_color_override("icon_hover_color")
	btn.remove_theme_color_override("icon_pressed_color")


func _make_arcade_button(text_str: String, accent: Color, min_h: float = 54.0, font_sz: int = 18, _fill_bg: Color = Color(0.11, 0.15, 0.22, 0.95)) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(0, min_h)
	var upper := text_str.strip_edges().to_upper()
	var icon_name: String = UIStyle.infer_icon_for_text(text_str)
	UIStyle.style_layer_button(btn, _variant_for_color(accent), icon_name, 14, 10)
	if upper == "+ NC":
		_apply_coin_button_icon(btn, 18)
	elif upper.begins_with("BUY "):
		_apply_coin_button_icon(btn, 20)
	btn.add_theme_font_size_override("font_size", font_sz)
	return btn


func _make_icon_card_button(title: String, icon_path: String, accent: Color, min_h: float = 132.0, font_sz: int = 20, _fill_bg: Color = Color(0.11, 0.15, 0.22, 0.95), icon_sz: int = 72) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, min_h)
	var is_compact: bool = min_h < 100.0
	UIStyle.style_layer_button(btn, _variant_for_color(accent), "", 8 if is_compact else 16, 6 if is_compact else 10)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3 if is_compact else 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	var tex: Texture2D = null
	if ResourceLoader.exists(icon_path):
		tex = load(icon_path) as Texture2D
	elif icon_path.ends_with("icon_coin.png"):
		tex = _get_coin_icon()
	if tex != null:
		var icon_rect := TextureRect.new()
		icon_rect.texture = tex
		icon_rect.custom_minimum_size = Vector2(icon_sz, icon_sz)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(icon_rect)
		btn.set_meta("card_icon", icon_rect)
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", UIStyle.FONT_MAIN)
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.09, 0.92))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.modulate = Color(0.97, 0.98, 1.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)
	btn.set_meta("card_label", lbl)
	return btn


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = TEX_BG
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_hub_container = VBoxContainer.new()
	_hub_container.custom_minimum_size = Vector2(960, 560)
	_hub_container.add_theme_constant_override("separation", 10)
	center.add_child(_hub_container)

	# Top Economy Bar: Live Coin Balance + Quick Gun Shop Access
	var econ_bar := HBoxContainer.new()
	econ_bar.add_theme_constant_override("separation", 8)
	_hub_container.add_child(econ_bar)

	var brand_lbl := Label.new()
	brand_lbl.text = "NAMELESS CLASH"
	brand_lbl.add_theme_font_size_override("font_size", 21)
	brand_lbl.modulate = Color(1.0, 0.86, 0.28)
	brand_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	econ_bar.add_child(brand_lbl)

	var coin_pill := PanelContainer.new()
	var cp_sb := StyleBoxFlat.new()
	cp_sb.bg_color = Color(0.14, 0.12, 0.05, 0.96)
	cp_sb.border_color = Color(1.0, 0.84, 0.24, 0.96)
	cp_sb.set_border_width_all(2)
	cp_sb.set_corner_radius_all(12)
	cp_sb.set_content_margin_all(6)
	cp_sb.content_margin_left = 12
	cp_sb.content_margin_right = 10
	coin_pill.add_theme_stylebox_override("panel", cp_sb)
	coin_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	coin_pill.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_open_coin_shop()
	)
	econ_bar.add_child(coin_pill)

	var coin_pill_hb := HBoxContainer.new()
	coin_pill_hb.add_theme_constant_override("separation", 6)
	coin_pill_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_pill_hb.mouse_filter = Control.MOUSE_FILTER_PASS
	coin_pill.add_child(coin_pill_hb)

	_coin_pill_lbl = _add_coin_icon_label(coin_pill_hb, ProfileManager.format_coins(ProfileManager.coins), 22, 17, Color(1.0, 0.88, 0.30), true)

	var coin_plus_btn := _make_arcade_button("+", Color(0.36, 0.98, 0.56), 24.0, 15, Color(0.08, 0.32, 0.16, 0.98))
	coin_plus_btn.custom_minimum_size = Vector2(26, 24)
	coin_plus_btn.tooltip_text = "Open NC Shop"
	coin_plus_btn.pressed.connect(func(): _open_coin_shop())
	coin_pill_hb.add_child(coin_plus_btn)

	ProfileManager.coins_changed.connect(func(new_c: int):
		var c_str: String = ProfileManager.format_coins(new_c)
		if is_instance_valid(_coin_pill_lbl):
			_coin_pill_lbl.text = c_str
		if is_instance_valid(_shop_coin_lbl):
			_shop_coin_lbl.text = c_str
		if is_instance_valid(_crate_coin_lbl) and not _crate_spinning:
			_crate_coin_lbl.text = c_str
		if is_instance_valid(_ach_coin_lbl):
			_ach_coin_lbl.text = c_str
		if is_instance_valid(_coin_shop_coin_lbl):
			_coin_shop_coin_lbl.text = c_str
	)

	_crate_top_btn = _make_arcade_button("CRATES & DAILY", Color(0.35, 0.96, 0.56), 40.0, 14, Color(0.08, 0.24, 0.14, 0.98))
	_crate_top_btn.custom_minimum_size = Vector2(194, 40)
	_crate_top_btn.pressed.connect(_open_crate_overlay)
	econ_bar.add_child(_crate_top_btn)

	_mute_top_btn = Button.new()
	_mute_top_btn.custom_minimum_size = Vector2(114, 40)
	_mute_top_btn.focus_mode = Control.FOCUS_NONE
	_mute_top_btn.expand_icon = true
	_mute_top_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mute_top_btn.add_theme_font_override("font", UIStyle.FONT_MAIN)
	_mute_top_btn.add_theme_font_size_override("font_size", 14)
	_mute_top_btn.add_theme_constant_override("icon_max_width", 22)
	_mute_top_btn.add_theme_constant_override("h_separation", 7)
	_mute_top_btn.pressed.connect(func(): SettingsManager.toggle_master_mute())
	_refresh_mute_button()
	econ_bar.add_child(_mute_top_btn)

	# Main Split: Left Side Rail + Your Soldier Showcase + Right Big Touch Battle Modes
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	_hub_container.add_child(split)

	var win_panel_sb := StyleBoxFlat.new()
	win_panel_sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	win_panel_sb.border_color = Color(1.0, 0.84, 0.24, 0.98)
	win_panel_sb.set_border_width_all(3)
	win_panel_sb.set_corner_radius_all(18)
	win_panel_sb.set_content_margin_all(12)
	win_panel_sb.shadow_color = Color(1.0, 0.82, 0.22, 0.36)
	win_panel_sb.shadow_size = 8
	win_panel_sb.shadow_offset = Vector2.ZERO

	# Left Side Rail: Mobile-Friendly Big-Icon Tiles (Achievements, Leaderboards, NC Shop, Weapons, Credits)
	var left_rail_panel := PanelContainer.new()
	left_rail_panel.custom_minimum_size = Vector2(180, 0)
	var lr_sb := StyleBoxFlat.new()
	lr_sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	lr_sb.border_color = Color(0.32, 0.56, 0.86, 0.85)
	lr_sb.set_border_width_all(2)
	lr_sb.set_corner_radius_all(16)
	lr_sb.set_content_margin_all(10)
	left_rail_panel.add_theme_stylebox_override("panel", lr_sb)
	split.add_child(left_rail_panel)

	var left_rail := VBoxContainer.new()
	left_rail.add_theme_constant_override("separation", 10)
	left_rail_panel.add_child(left_rail)

	_ach_top_btn = _make_icon_card_button("ACHIEVEMENTS", "res://assets/ui/icons/icon_achievements.png", Color(0.76, 0.56, 1.0), 74.0, 14, Color(0.16, 0.10, 0.28, 0.98), 46)
	_ach_top_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ach_top_btn.pressed.connect(_open_achievements_overlay)
	left_rail.add_child(_ach_top_btn)

	var btn_leaderboards := _make_icon_card_button("LEADERBOARDS", "res://assets/ui/icons/icon_leaderboards.png", Color(0.32, 0.88, 1.0), 74.0, 14, Color(0.08, 0.20, 0.30, 0.98), 46)
	btn_leaderboards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_leaderboards.pressed.connect(_open_leaderboard_overlay)
	left_rail.add_child(btn_leaderboards)

	_coin_shop_top_btn = _make_icon_card_button("NC SHOP", "res://assets/ui/icons/icon_coin.png", Color(0.38, 0.98, 0.58), 74.0, 14, Color(0.08, 0.28, 0.14, 0.98), 46)
	_coin_shop_top_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_coin_shop_top_btn.pressed.connect(func(): _open_coin_shop())
	left_rail.add_child(_coin_shop_top_btn)

	_top_shop_btn = _make_icon_card_button("WEAPONS", "res://assets/ui/icons/icon_weapons.png", Color(1.0, 0.82, 0.24), 74.0, 14, Color(0.24, 0.17, 0.05, 0.98), 46)
	_top_shop_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_top_shop_btn.pressed.connect(_open_gun_shop)
	left_rail.add_child(_top_shop_btn)

	var btn_credits := _make_icon_card_button("CREDITS", "res://assets/ui/icons/icon_credits.png", Color(0.95, 0.78, 0.25), 74.0, 14, Color(0.11, 0.15, 0.22, 0.95), 46)
	btn_credits.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_credits.pressed.connect(_open_credits)
	left_rail.add_child(btn_credits)

	# Center-Left Card: Your Soldier Showcase
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.88
	preview_panel.add_theme_stylebox_override("panel", win_panel_sb)
	split.add_child(preview_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	preview_panel.add_child(pv)

	var p_hdr := Label.new()
	p_hdr.text = "YOUR FIGHTER"
	p_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_hdr.add_theme_font_size_override("font_size", 16)
	p_hdr.modulate = Color(0.76, 0.82, 0.94)
	pv.add_child(p_hdr)

	_callsign_label = Label.new()
	_callsign_label.text = ProfileManager.player_name.to_upper()
	_callsign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callsign_label.add_theme_font_size_override("font_size", 28)
	_callsign_label.modulate = Color(1.0, 0.84, 0.24)
	pv.add_child(_callsign_label)

	var stage := PanelContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(210, 168)
	stage.clip_contents = true
	stage.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.12, 0.20, 0.96), Color(0.24, 0.36, 0.56, 0.80), 12))
	pv.add_child(stage)

	var anchor_wrap := Control.new()
	anchor_wrap.draw.connect(func():
		var sz: Vector2 = anchor_wrap.size
		var floor_y: float = minf(sz.y - 16.0, sz.y * 0.5 + 122.0)
		anchor_wrap.draw_rect(Rect2(0.0, floor_y, sz.x, maxf(0.0, sz.y - floor_y)), Color(0.04, 0.06, 0.11, 0.82), true)
		anchor_wrap.draw_line(Vector2(10.0, floor_y), Vector2(sz.x - 10.0, floor_y), Color(1.0, 0.82, 0.28, 0.88), 2.5)
		anchor_wrap.draw_line(Vector2(10.0, floor_y + 3.0), Vector2(sz.x - 10.0, floor_y + 3.0), Color(0.24, 0.36, 0.56, 0.45), 1.5)
	)
	stage.add_child(anchor_wrap)

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER)
	anchor_wrap.add_child(anchor)

	_preview = SoldierPreview.new()
	_preview.shuffle_guns = false
	_preview.hide_weapons = true
	_preview.scale = Vector2(3.8, 3.8)
	anchor.add_child(_preview)

	var prev_agent_btn := _make_arcade_button("<", Color(0.28, 0.56, 0.96), 60.0, 26, Color(0.10, 0.15, 0.26, 0.92))
	prev_agent_btn.custom_minimum_size = Vector2(46, 60)
	prev_agent_btn.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	prev_agent_btn.offset_left = 12.0
	prev_agent_btn.offset_top = -30.0
	prev_agent_btn.offset_right = 58.0
	prev_agent_btn.offset_bottom = 30.0
	prev_agent_btn.pressed.connect(func(): _cycle_main_agent(-1))
	anchor_wrap.add_child(prev_agent_btn)

	var next_agent_btn := _make_arcade_button(">", Color(0.28, 0.56, 0.96), 60.0, 26, Color(0.10, 0.15, 0.26, 0.92))
	next_agent_btn.custom_minimum_size = Vector2(46, 60)
	next_agent_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	next_agent_btn.offset_left = -58.0
	next_agent_btn.offset_top = -30.0
	next_agent_btn.offset_right = -12.0
	next_agent_btn.offset_bottom = 30.0
	next_agent_btn.pressed.connect(func(): _cycle_main_agent(1))
	anchor_wrap.add_child(next_agent_btn)

	_loadout_label = Label.new()
	_loadout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_loadout_label.add_theme_font_size_override("font_size", 17)
	_loadout_label.modulate = Color(0.76, 0.82, 0.88)
	_update_loadout_label()
	pv.add_child(_loadout_label)

	var hero_btn_row := HBoxContainer.new()
	hero_btn_row.add_theme_constant_override("separation", 8)
	pv.add_child(hero_btn_row)

	_customize_btn = _make_arcade_button("CUSTOMIZE", Color(0.86, 0.62, 0.24), 52.0, 16, Color(0.18, 0.14, 0.10, 0.96))
	_customize_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_customize_btn.pressed.connect(func(): _transition_to(NetworkManager.go_to_avatar_garage))
	hero_btn_row.add_child(_customize_btn)

	# Right Card: Big Mobile Battle Mode Buttons
	var nav_panel := PanelContainer.new()
	nav_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_panel.size_flags_stretch_ratio = 1.08
	nav_panel.add_theme_stylebox_override("panel", win_panel_sb.duplicate())
	split.add_child(nav_panel)

	var nav_v := VBoxContainer.new()
	nav_v.add_theme_constant_override("separation", 10)
	nav_v.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_panel.add_child(nav_v)

	var nav_hdr := Label.new()
	nav_hdr.text = "CHOOSE MODE"
	nav_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_hdr.add_theme_font_size_override("font_size", 18)
	nav_hdr.modulate = Color(1.0, 0.84, 0.24)
	nav_v.add_child(nav_hdr)

	var mode_grid := GridContainer.new()
	mode_grid.columns = 2
	mode_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mode_grid.add_theme_constant_override("h_separation", 14)
	mode_grid.add_theme_constant_override("v_separation", 14)
	nav_v.add_child(mode_grid)

	var btn_solo := _make_icon_card_button("GUN GAME", "res://assets/ui/icons/icon_gun_game.png", Color(0.98, 0.78, 0.22), 132.0, 20, Color(0.24, 0.18, 0.06, 0.98), 72)
	var gun_n := StyleBoxFlat.new()
	gun_n.bg_color = Color(0.30, 0.23, 0.05, 0.96)
	gun_n.border_color = Color(0.98, 0.76, 0.22, 0.95)
	gun_n.set_border_width_all(2)
	gun_n.set_corner_radius_all(10)
	var gun_h := gun_n.duplicate() as StyleBoxFlat
	gun_h.bg_color = Color(0.38, 0.29, 0.07, 0.98)
	var gun_p := gun_n.duplicate() as StyleBoxFlat
	gun_p.bg_color = Color(0.22, 0.17, 0.04, 0.98)
	btn_solo.add_theme_stylebox_override("normal", gun_n)
	btn_solo.add_theme_stylebox_override("hover", gun_h)
	btn_solo.add_theme_stylebox_override("pressed", gun_p)
	btn_solo.add_theme_stylebox_override("focus", gun_n)
	btn_solo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_solo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_solo.pressed.connect(func():
		NetworkManager.disconnect_network()
		NetworkManager.test_mode_enabled = false
		NetworkManager.practice_shooting_range = false
		if NetworkManager.is_agent_clash_mode():
			NetworkManager.match_mode = 0
		_open_match_settings(false)
	)
	mode_grid.add_child(btn_solo)

	_agent_mode_btn = _make_icon_card_button("AGENT CLASH", "res://assets/ui/icons/icon_agent_clash.png", Color(0.30, 0.92, 0.48), 132.0, 20, Color(0.09, 0.28, 0.16, 0.98), 72)
	_agent_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agent_mode_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_agent_mode_btn.pressed.connect(func(): _open_agent_select(false))
	mode_grid.add_child(_agent_mode_btn)

	var btn_test := _make_icon_card_button("PRACTICE MODE", "res://assets/ui/icons/icon_practice.png", Color(0.78, 0.42, 1.0), 132.0, 20, Color(0.20, 0.10, 0.34, 0.98), 72)
	btn_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_test.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_test.pressed.connect(_open_test_mode_overlay)
	mode_grid.add_child(btn_test)

	var btn_local := _make_icon_card_button("LOCAL MODE", "res://assets/ui/icons/icon_local_mode.png", Color(0.95, 0.36, 0.34), 132.0, 20, Color(0.28, 0.09, 0.11, 0.98), 72)
	btn_local.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_local.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_local.pressed.connect(_open_local_mode_overlay)
	mode_grid.add_child(btn_local)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	nav_v.add_child(bottom_row)

	var btn_settings := _make_arcade_button("SETTINGS", Color(0.75, 0.84, 0.96), 50.0, 17)
	btn_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_settings.pressed.connect(_open_settings_popup)
	bottom_row.add_child(btn_settings)

	var btn_quit := _make_arcade_button("QUIT", Color(0.92, 0.30, 0.30), 50.0, 17)
	btn_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quit.pressed.connect(func(): get_tree().quit())
	bottom_row.add_child(btn_quit)

	_build_credits_overlay()
	_build_agent_select_overlay()
	_build_test_mode_overlay()
	_build_map_select_overlay()
	_build_match_settings_overlay()
	_build_local_mode_overlays()
	_build_gun_shop_overlay()
	_build_crate_overlay()
	_build_achievements_overlay()
	_build_leaderboard_overlay()
	_build_coin_shop_overlay()
	_build_coin_purchase_popup()
	_build_settings_overlay()
	_update_crate_badge()
	_update_ach_badge()
	_update_new_item_badges()
	if not ProfileManager.new_badges_changed.is_connected(_update_new_item_badges):
		ProfileManager.new_badges_changed.connect(_update_new_item_badges)
	if not SettingsManager.settings_changed.is_connected(_refresh_mute_button):
		SettingsManager.settings_changed.connect(_refresh_mute_button)


func _get_sound_icon(muted: bool) -> Texture2D:
	if not muted and _sound_on_icon_cache != null:
		return _sound_on_icon_cache
	if muted and _sound_off_icon_cache != null:
		return _sound_off_icon_cache

	var sz: int = 28
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var cy: float = 13.5
	var spk_col := Color(0.95, 0.72, 0.72) if muted else Color(0.88, 0.98, 1.0)
	var wave_col := Color(0.62, 0.94, 1.0)
	var x_col := Color(1.0, 0.42, 0.42)
	var wave_center := Vector2(14.0, cy)

	for y in range(sz):
		for x in range(sz):
			var fx := float(x)
			var fy := float(y)
			var px_col := Color(0.0, 0.0, 0.0, 0.0)

			# Speaker body (x: 4..8) + flared cone (x: 8..15)
			if fx >= 3.5 and fx <= 15.5:
				var half_h: float = 3.5 if fx <= 8.0 else lerpf(3.5, 8.2, clampf((fx - 8.0) / 6.5, 0.0, 1.0))
				var dy: float = absf(fy - cy)
				var dx_edge: float = minf(fx - 3.5, 15.5 - fx)
				var a_spk: float = clampf(minf(half_h + 0.6 - dy, dx_edge + 0.4), 0.0, 1.0)
				if a_spk > 0.0:
					px_col = Color(spk_col.r, spk_col.g, spk_col.b, a_spk)

			if muted:
				var pt := Vector2(fx, fy)
				var d1: float = pt.distance_to(Geometry2D.get_closest_point_to_segment(pt, Vector2(18.0, 9.0), Vector2(25.0, 18.0)))
				var d2: float = pt.distance_to(Geometry2D.get_closest_point_to_segment(pt, Vector2(25.0, 9.0), Vector2(18.0, 18.0)))
				var d_min: float = minf(d1, d2)
				var a_x: float = clampf(1.65 - d_min, 0.0, 1.0)
				if a_x > px_col.a:
					px_col = Color(x_col.r, x_col.g, x_col.b, a_x)
			else:
				var dx: float = fx - wave_center.x
				if dx >= 1.2 and absf(fy - cy) <= dx * 1.12:
					var dist: float = Vector2(fx, fy).distance_to(wave_center)
					var a_arc1: float = clampf(1.35 - absf(dist - 5.2), 0.0, 1.0)
					var a_arc2: float = clampf(1.35 - absf(dist - 9.0), 0.0, 1.0)
					var a_arc: float = maxf(a_arc1, a_arc2)
					if a_arc > px_col.a:
						px_col = Color(wave_col.r, wave_col.g, wave_col.b, a_arc)

			img.set_pixel(x, y, px_col)

	var tex := ImageTexture.create_from_image(img)
	if muted:
		_sound_off_icon_cache = tex
	else:
		_sound_on_icon_cache = tex
	return tex


func _refresh_mute_button() -> void:
	if not is_instance_valid(_mute_top_btn):
		return
	var muted: bool = SettingsManager.is_game_muted()
	_mute_top_btn.text = "MUTED" if muted else "SOUND"
	_mute_top_btn.icon = _get_sound_icon(muted)
	_mute_top_btn.tooltip_text = "Unmute full game sound" if muted else "Mute full game sound"

	var sb := StyleBoxFlat.new()
	if muted:
		sb.bg_color = Color(0.28, 0.08, 0.10, 0.98)
		sb.border_color = Color(1.0, 0.36, 0.36, 0.98)
		_mute_top_btn.add_theme_color_override("font_color", Color(1.0, 0.76, 0.76))
		_mute_top_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.88))
		_mute_top_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.88))
	else:
		sb.bg_color = Color(0.08, 0.16, 0.26, 0.98)
		sb.border_color = Color(0.36, 0.86, 1.0, 0.96)
		_mute_top_btn.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
		_mute_top_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		_mute_top_btn.add_theme_color_override("font_pressed_color", Color(0.75, 0.92, 1.0))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0

	var sb_hl := sb.duplicate() as StyleBoxFlat
	sb_hl.bg_color = sb.bg_color.lightened(0.08)
	var sb_pr := sb.duplicate() as StyleBoxFlat
	sb_pr.bg_color = sb.bg_color.darkened(0.10)

	_mute_top_btn.add_theme_stylebox_override("normal", sb)
	_mute_top_btn.add_theme_stylebox_override("hover", sb_hl)
	_mute_top_btn.add_theme_stylebox_override("pressed", sb_pr)
	_mute_top_btn.add_theme_stylebox_override("focus", sb)


func _build_settings_overlay() -> void:
	var packed := load("res://scenes/SettingsMenu.tscn") as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate() as Control
	if inst == null:
		return
	_settings_overlay = inst
	_settings_overlay.set("is_embedded_popup", true)
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.z_index = 74
	_settings_overlay.visible = false
	add_child(_settings_overlay)


func _open_settings_popup() -> void:
	if _settings_overlay != null:
		_settings_overlay.call("open_popup")


func _build_credits_overlay() -> void:
	_credits_overlay = ColorRect.new()
	_credits_overlay.z_index = 50
	_credits_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_overlay.color = Color(0.02, 0.03, 0.06, 0.84)
	_credits_overlay.visible = false
	add_child(_credits_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 440)
	card.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.11, 0.18, 0.98), Color(0.98, 0.72, 0.22, 0.95), 14))
	cc.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)

	var c_title := Label.new()
	c_title.text = "NAMELESS CLASH"
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_title.add_theme_font_size_override("font_size", 26)
	c_title.modulate = Color(1.0, 0.82, 0.28)
	cv.add_child(c_title)

	const COMPANY_LOGO_PATH: String = "res://assets/company_logo.png"
	var logo_tex: Texture2D = null
	if ResourceLoader.exists(COMPANY_LOGO_PATH):
		logo_tex = load(COMPANY_LOGO_PATH) as Texture2D
	if logo_tex == null:
		var logo_abs: String = ProjectSettings.globalize_path(COMPANY_LOGO_PATH)
		if FileAccess.file_exists(logo_abs):
			var logo_img := Image.load_from_file(logo_abs)
			if logo_img != null and not logo_img.is_empty():
				logo_tex = ImageTexture.create_from_image(logo_img)
	if logo_tex != null:
		var logo_rect := TextureRect.new()
		logo_rect.texture = logo_tex
		logo_rect.custom_minimum_size = Vector2(220, 220)
		logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		cv.add_child(logo_rect)

	var c_body := Label.new()
	c_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	c_body.add_theme_font_size_override("font_size", 15)
	c_body.text = (
		"Developed by Nameless Forge\n\n"
		+ "Fast-Paced 2D Multiplayer Arena Combat!\n"
		+ "Play Solo against AI Bots or battle friends over Local Wi-Fi / Hotspot.\n"
		+ "Visit Character Customization & Weapons to unlock skins and gear."
	)
	cv.add_child(c_body)

	var close_btn := _make_arcade_button("CLOSE", Color(0.98, 0.56, 0.14), 48.0, 18)
	close_btn.pressed.connect(_close_credits)
	cv.add_child(close_btn)


func _play_enter_animation() -> void:
	_hub_container.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hub_container, "modulate:a", 1.0, 0.28)


func _transition_to(target_fn: Callable) -> void:
	if _transitioning:
		return
	_transitioning = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_hub_container, "modulate:a", 0.0, 0.16)
	tw.finished.connect(target_fn)


func _select_bot_difficulty(level: int) -> void:
	NetworkManager.bot_difficulty = clampi(level, 0, 2)
	_refresh_diff_buttons()


func _refresh_diff_buttons() -> void:
	var active_colors: Array[Color] = [
		Color(0.28, 0.90, 0.48),
		Color(0.98, 0.72, 0.20),
		Color(0.95, 0.28, 0.28)
	]
	for i in range(_diff_buttons.size()):
		var db: Button = _diff_buttons[i]
		var is_active: bool = (i == NetworkManager.bot_difficulty)
		var border_col: Color = active_colors[i] if is_active else Color(0.32, 0.42, 0.56)
		var bg_col: Color = active_colors[i].darkened(0.65) if is_active else Color(0.09, 0.12, 0.18, 0.95)
		db.add_theme_stylebox_override("normal", _make_style(bg_col, border_col, 8))
		db.add_theme_stylebox_override("hover", _make_style(bg_col.lightened(0.14), border_col.lightened(0.25), 8))
		db.add_theme_stylebox_override("pressed", _make_style(border_col.darkened(0.35), border_col, 8))
		db.modulate = Color.WHITE if is_active else Color(0.75, 0.80, 0.88)


func _on_quick_host_pressed() -> void:
	var err: Error = NetworkManager.host_game(NetworkManager.local_room_name)
	if err == OK:
		_transition_to(NetworkManager.go_to_lobby)


func _open_credits() -> void:
	_credits_overlay.visible = true
	_credits_overlay.modulate.a = 0.0
	create_tween().tween_property(_credits_overlay, "modulate:a", 1.0, 0.18)


func _close_credits() -> void:
	var tw := create_tween()
	tw.tween_property(_credits_overlay, "modulate:a", 0.0, 0.14)
	tw.finished.connect(func(): _credits_overlay.visible = false)


func _build_agent_select_overlay() -> void:
	_agent_select_overlay = ColorRect.new()
	_agent_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_agent_select_overlay.color = Color(0.02, 0.03, 0.06, 0.90)
	_agent_select_overlay.z_index = 50
	_agent_select_overlay.visible = false
	add_child(_agent_select_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_agent_select_overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.15, 0.98), Color(0.78, 0.42, 1.0, 0.95), 16))
	margin.add_child(panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	panel.add_child(root_v)

	# Top Header: Close (Left) | "Agent Clash" (Center) | Continue (Right)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	root_v.add_child(top_row)

	var close_btn := _make_arcade_button("CLOSE", Color(0.95, 0.42, 0.36), 42.0, 15, Color(0.24, 0.10, 0.12))
	close_btn.custom_minimum_size = Vector2(140, 42)
	close_btn.pressed.connect(_close_agent_select)
	top_row.add_child(close_btn)

	_agent_kit_title = Label.new()
	_agent_kit_title.text = "Agent Clash"
	_agent_kit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_agent_kit_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_agent_kit_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agent_kit_title.add_theme_font_size_override("font_size", 22)
	_agent_kit_title.modulate = Color(1.0, 0.88, 0.36)
	top_row.add_child(_agent_kit_title)

	_agent_play_btn = _make_arcade_button("CONTINUE", Color(0.30, 0.92, 0.48), 42.0, 15, Color(0.09, 0.30, 0.16))
	_agent_play_btn.custom_minimum_size = Vector2(210, 42)
	_agent_play_btn.pressed.connect(func():
		if not _agent_select_for_practice and not ProfileManager.is_agent_unlocked(_agent_preview_idx, false):
			if ProfileManager.buy_agent(_agent_preview_idx):
				ProfileManager.apply_archetype_preset(_agent_preview_idx, true)
				SettingsManager.play_ui_purchase()
				if is_instance_valid(_coin_pill_lbl):
					_coin_pill_lbl.text = ProfileManager.format_coins(ProfileManager.coins)
				if is_instance_valid(_preview):
					_preview.refresh_from_profile()
				_update_loadout_label()
				_refresh_agent_select_ui()
			return
		if _agent_select_for_practice:
			ProfileManager.apply_archetype_preset(_agent_preview_idx, false)
		else:
			ProfileManager.apply_archetype_preset(_agent_preview_idx, true)
		_preview_saved_match_mode = -1
		NetworkManager.disconnect_network()
		NetworkManager.practice_shooting_range = false
		NetworkManager.match_mode = 2
		_close_agent_select()
		if _agent_select_for_practice:
			NetworkManager.test_mode_enabled = true
			NetworkManager.test_bot_behavior = _test_bot_choice
			_open_map_select(func(): _transition_to(NetworkManager.go_to_arena))
		else:
			NetworkManager.test_mode_enabled = false
			_open_match_settings(true)
	)
	top_row.add_child(_agent_play_btn)

	# Main Split Content: Left = Full Preview Screen + Abilities | Right = All Agents (2 per row)
	var main_split := HBoxContainer.new()
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.add_theme_constant_override("separation", 12)
	root_v.add_child(main_split)

	# Left Column: Full Preview Stage + Ability Buttons below it
	var left_card := PanelContainer.new()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_card.size_flags_stretch_ratio = 1.15
	left_card.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.06, 0.11, 0.96), Color(0.32, 0.62, 0.98, 0.8), 12))
	main_split.add_child(left_card)

	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 10)
	left_card.add_child(lv)

	_agent_kit_body = null

	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 270)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true
	stage.add_theme_stylebox_override("panel", _make_style(Color(0.03, 0.04, 0.08, 0.96), Color(0.24, 0.36, 0.56, 0.7), 10))
	lv.add_child(stage)

	var sv_cont := SubViewportContainer.new()
	sv_cont.stretch = true
	sv_cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_child(sv_cont)

	var sv := SubViewport.new()
	sv.world_2d = World2D.new()
	sv.size = Vector2i(660, 290)
	sv.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	sv_cont.add_child(sv)

	_agent_preview_arena = Node2D.new()
	_agent_preview_arena.set_script(load("res://scripts/AgentPreviewArena.gd"))
	sv.add_child(_agent_preview_arena)

	var ab_grid := GridContainer.new()
	ab_grid.columns = 2
	ab_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab_grid.add_theme_constant_override("h_separation", 10)
	ab_grid.add_theme_constant_override("v_separation", 10)
	lv.add_child(ab_grid)

	_agent_preview_btns.clear()
	for slot_i in range(4):
		var is_ult: bool = (slot_i == 3)
		var b_col: Color = Color(1.0, 0.78, 0.24) if is_ult else Color(0.32, 0.78, 1.0)
		var b_bg: Color = Color(0.24, 0.16, 0.06, 0.95) if is_ult else Color(0.08, 0.16, 0.26, 0.95)
		var ab_btn := _make_arcade_button("Ability", b_col, 64.0, 14, b_bg)
		ab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ab_btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ab_btn.expand_icon = true
		ab_btn.clip_text = true
		ab_btn.pressed.connect(_trigger_preview_ability.bind(slot_i))
		ab_grid.add_child(ab_btn)
		_agent_preview_btns.append(ab_btn)

	_practice_agent_bot_row = HBoxContainer.new()
	_practice_agent_bot_row.add_theme_constant_override("separation", 8)
	_practice_agent_bot_row.visible = false
	lv.add_child(_practice_agent_bot_row)

	var p_bot_lbl := Label.new()
	p_bot_lbl.text = "BOT AGENTS:"
	p_bot_lbl.add_theme_font_size_override("font_size", 13)
	p_bot_lbl.modulate = Color(0.75, 0.88, 1.0)
	_practice_agent_bot_row.add_child(p_bot_lbl)

	_practice_agent_bot_opt = OptionButton.new()
	_practice_agent_bot_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_practice_agent_bot_opt.custom_minimum_size = Vector2(0, 32)
	_practice_agent_bot_opt.clip_text = true
	_populate_bot_agent_option_button(_practice_agent_bot_opt)
	_practice_agent_bot_opt.item_selected.connect(func(item_idx: int):
		NetworkManager.practice_bot_agent_id = _practice_agent_bot_opt.get_item_id(item_idx)
		_sync_bot_agent_option_buttons()
	)
	_practice_agent_bot_row.add_child(_practice_agent_bot_opt)

	# Right Column: All Agents Scrollable Grid (2 per row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_split.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	_agent_cards.clear()
	for i in _get_sorted_agent_indices():
		var ag: Dictionary = AgentData.AGENTS[i]
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(0, 108)
		cb.clip_text = true
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cb.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cb.icon = _make_agent_icon(i)
		cb.add_theme_font_size_override("font_size", 15)
		cb.text = "  %s\n  (%s)" % [str(ag["agent_name"]), str(ag["title"])]
		cb.set_meta("agent_idx", i)
		cb.pressed.connect(_select_agent.bind(i))
		var lock_tr := TextureRect.new()
		lock_tr.name = "LockIcon"
		lock_tr.texture = load("res://assets/ui/icons/icon_lock.png") as Texture2D
		lock_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_tr.anchor_left = 1.0
		lock_tr.anchor_right = 1.0
		lock_tr.anchor_top = 0.0
		lock_tr.anchor_bottom = 0.0
		lock_tr.offset_left = -36.0
		lock_tr.offset_top = 8.0
		lock_tr.offset_right = -8.0
		lock_tr.offset_bottom = 36.0
		lock_tr.visible = false
		cb.add_child(lock_tr)
		grid.add_child(cb)
		_agent_cards.append(cb)

	_refresh_agent_select_ui()


const REWORKED_PART_PRIORITY: Array[int] = [
	14, 21, 24, 26, 7, 15, 27, 1, 13, 16, 17, 18, 20, 25, 28, 29, 30, 0
]


func _get_sorted_agent_indices() -> Array[int]:
	var total: int = mini(AgentData.AGENTS.size(), ProfileManager.ARCHETYPES.size())
	var indices: Array[int] = []
	for i in range(total):
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var a_unl: bool = ProfileManager.is_agent_unlocked(a, false)
		var b_unl: bool = ProfileManager.is_agent_unlocked(b, false)
		if a_unl != b_unl:
			return a_unl
		var a_name: String = str(AgentData.AGENTS[a].get("agent_name", "")).to_lower()
		var b_name: String = str(AgentData.AGENTS[b].get("agent_name", "")).to_lower()
		return a_name < b_name
	)
	return indices


func _update_loadout_label() -> void:
	if not is_instance_valid(_loadout_label):
		return
	if ProfileManager.is_using_custom_dummy():
		_loadout_label.text = "Custom Character"
		return
	var arch_d: Dictionary = ProfileManager.ARCHETYPES[clampi(ProfileManager.archetype_id, 0, ProfileManager.ARCHETYPES.size() - 1)]
	var full_name: String = str(arch_d.get("name", "Hero"))
	var callsign: String = str(arch_d.get("callsign", full_name))
	var role_sub: String = full_name.replace(callsign, "").strip_edges().trim_prefix("(").trim_suffix(")")
	_loadout_label.text = ("%s\n%s" % [callsign, role_sub]) if not role_sub.is_empty() else callsign


func _cycle_main_agent(step: int) -> void:
	var order: Array[int] = []
	for i in _get_sorted_agent_indices():
		if ProfileManager.is_agent_unlocked(i, false):
			order.append(i)
	if order.is_empty():
		return
	var cur_pos: int = order.find(ProfileManager.archetype_id)
	if cur_pos < 0:
		cur_pos = 0
	var next_idx: int = order[posmod(cur_pos + step, order.size())]
	_select_agent(next_idx)


func _select_agent(idx: int) -> void:
	_agent_preview_idx = clampi(idx, 0, AgentData.AGENTS.size() - 1)
	if ProfileManager.is_agent_unlocked(_agent_preview_idx, false):
		ProfileManager.apply_archetype_preset(_agent_preview_idx, true)
		if is_instance_valid(_preview):
			_preview.refresh_from_profile()
		_update_loadout_label()
	_refresh_agent_select_ui()


func _refresh_agent_select_ui() -> void:
	var idx: int = clampi(_agent_preview_idx, 0, AgentData.AGENTS.size() - 1)
	var ag: Dictionary = AgentData.get_agent(idx)
	var bw: Dictionary = ag["base_weapon"]
	var abils: Array = ag["abilities"]
	var ult: Dictionary = ag["ultimate"]
	var is_sel_unlocked: bool = ProfileManager.is_agent_unlocked(idx, _agent_select_for_practice)
	var unlock_price: int = ProfileManager.get_agent_unlock_price()
	if is_instance_valid(_agent_kit_title):
		var lock_tag: String = ""
		if not ProfileManager.is_agent_unlocked(idx, false):
			lock_tag = "  (FREE IN PRACTICE)" if _agent_select_for_practice else ("  (%s NC)" % ProfileManager.format_coins(unlock_price))
		_agent_kit_title.text = "Agent Clash  —  %s (%s)%s" % [str(ag["agent_name"]).to_upper(), str(ag["role"]), lock_tag]
	if is_instance_valid(_agent_preview_arena) and _agent_preview_arena.has_method("set_agent"):
		_agent_preview_arena.set_agent(idx)
	if is_instance_valid(_agent_kit_body):
		_agent_kit_body.text = "BASE WEAPON: %s (%d DMG) — Tap an ability below to preview!" % [str(bw["name"]), int(bw["damage"])]
	for si in range(_agent_preview_btns.size()):
		var btn: Button = _agent_preview_btns[si]
		if not is_instance_valid(btn):
			continue
		var ab_slot: Dictionary = ult if si == 3 else (abils[si] as Dictionary)
		var ab_kind: String = str(ab_slot.get("kind", ""))
		btn.icon = AgentData.get_ability_icon_texture(ab_kind)
		if si == 3:
			btn.text = " ULT: %s" % str(ult["name"])
		else:
			btn.text = " %d: %s" % [si + 1, str(abils[si]["name"])]
	if is_instance_valid(_agent_play_btn):
		if _agent_select_for_practice:
			_agent_play_btn.text = "START PRACTICE (AGENT)"
			_agent_play_btn.icon = UIStyle.get_icon("play")
			_agent_play_btn.expand_icon = true
			_agent_play_btn.add_theme_constant_override("icon_max_width", 30)
			_agent_play_btn.disabled = false
			_agent_play_btn.modulate = Color.WHITE
		elif is_sel_unlocked:
			_agent_play_btn.text = "CONTINUE"
			_agent_play_btn.icon = UIStyle.get_icon("play")
			_agent_play_btn.expand_icon = true
			_agent_play_btn.add_theme_constant_override("icon_max_width", 30)
			_agent_play_btn.disabled = false
			_agent_play_btn.modulate = Color.WHITE
		else:
			var can_afford: bool = ProfileManager.coins >= unlock_price
			_agent_play_btn.text = "UNLOCK (%s NC)" % ProfileManager.format_coins(unlock_price)
			_apply_coin_button_icon(_agent_play_btn, 20)
			_agent_play_btn.disabled = not can_afford
			_agent_play_btn.modulate = Color(1.0, 0.88, 0.30) if can_afford else Color(0.60, 0.58, 0.64)
	var sorted_order: Array[int] = _get_sorted_agent_indices()
	var card_by_idx: Dictionary = {}
	for card in _agent_cards:
		var c_idx: int = int(card.get_meta("agent_idx")) if card.has_meta("agent_idx") else -1
		if c_idx >= 0:
			card_by_idx[c_idx] = card
	for pos in range(sorted_order.size()):
		var cid: int = sorted_order[pos]
		if card_by_idx.has(cid):
			var c_node: Button = card_by_idx[cid] as Button
			if is_instance_valid(c_node) and c_node.get_parent() != null:
				c_node.get_parent().move_child(c_node, pos)
	for card in _agent_cards:
		var c_idx: int = int(card.get_meta("agent_idx")) if card.has_meta("agent_idx") else -1
		if c_idx < 0 or c_idx >= AgentData.AGENTS.size():
			continue
		var c_ag: Dictionary = AgentData.AGENTS[c_idx]
		var is_sel: bool = (c_idx == idx)
		var owned_perm: bool = ProfileManager.is_agent_unlocked(c_idx, false)
		var playable_now: bool = ProfileManager.is_agent_unlocked(c_idx, _agent_select_for_practice)
		if owned_perm:
			card.text = "  %s\n  (%s)" % [str(c_ag["agent_name"]), str(c_ag["title"])]
		elif _agent_select_for_practice:
			card.text = "  %s\n  (FREE IN PRACTICE)" % str(c_ag["agent_name"])
		else:
			card.text = "  %s\n  %s NC" % [str(c_ag["agent_name"]), ProfileManager.format_coins(unlock_price)]
		var lock_node: Node = card.get_node_or_null("LockIcon")
		if lock_node is Control:
			(lock_node as Control).visible = not playable_now
		UIStyle.set_new_badge_visible(card, ProfileManager.is_agent_new(c_idx), "NewBadge", -8.0, 8.0, 11)
		var ac: Color = ag["accent"] as Color
		var bg_c: Color = Color(0.22, 0.14, 0.34) if is_sel else (Color(0.10, 0.14, 0.22) if playable_now else Color(0.07, 0.08, 0.12))
		var bd_c: Color = (Color(1.0, 0.84, 0.26) if (is_sel and not playable_now) else (ac if is_sel else (Color(0.28, 0.42, 0.62) if playable_now else Color(0.32, 0.26, 0.20))))
		card.modulate = Color.WHITE if (playable_now or is_sel) else Color(0.72, 0.72, 0.78)
		card.add_theme_stylebox_override("normal", _make_style(bg_c, bd_c, 10))
		card.add_theme_stylebox_override("hover", _make_style(bg_c.lightened(0.14), bd_c.lightened(0.25), 10))
		card.add_theme_stylebox_override("pressed", _make_style(bd_c.darkened(0.35), bd_c, 10))


func _trigger_preview_ability(slot_i: int) -> void:
	var idx: int = clampi(_agent_preview_idx, 0, AgentData.AGENTS.size() - 1)
	var ab: Dictionary = AgentData.get_ability_slot(idx, slot_i)
	if is_instance_valid(_agent_kit_body):
		var prefix: String = "ULT" if slot_i == 3 else ("ABIL %d" % (slot_i + 1))
		_agent_kit_body.text = "%s — %s: %s" % [prefix, str(ab["name"]), str(ab["desc"])]
	if is_instance_valid(_agent_preview_arena) and _agent_preview_arena.has_method("cast_slot"):
		_agent_preview_arena.cast_slot(slot_i)


func _make_agent_icon(arch_idx: int) -> Texture2D:
	var arch: Dictionary = ProfileManager.ARCHETYPES[clampi(arch_idx, 0, ProfileManager.ARCHETYPES.size() - 1)]
	var parts: Dictionary = arch.get("parts", {})
	var def_part: int = ProfileManager.get_archetype_part_id(arch_idx)
	var s_idx: int = clampi(int(parts.get("head", def_part)), 0, ModularCharacter.MAX_PART_INDEX)
	var skin_tex: Texture2D = load(ModularCharacter.get_part_texture_path("skin", s_idx)) as Texture2D
	var head_tex: Texture2D = load(ModularCharacter.get_part_texture_path("head", s_idx)) as Texture2D
	if skin_tex == null:
		return null
	var fw: int = skin_tex.get_width() / 8
	var fh: int = mini(skin_tex.get_height(), int(float(skin_tex.get_height()) * 0.72))
	var crop := Rect2i(0, 0, fw, fh)
	var base_img: Image = skin_tex.get_image().get_region(crop)
	if base_img.get_format() != Image.FORMAT_RGBA8:
		base_img.convert(Image.FORMAT_RGBA8)
	if head_tex != null:
		var h_fw: int = maxi(1, head_tex.get_width() / 8)
		var h_fh: int = mini(head_tex.get_height(), int(float(head_tex.get_height()) * 0.72))
		var head_img: Image = head_tex.get_image().get_region(Rect2i(0, 0, h_fw, h_fh))
		if head_img.get_format() != Image.FORMAT_RGBA8:
			head_img.convert(Image.FORMAT_RGBA8)
		if h_fw != fw or h_fh != fh:
			head_img.resize(fw, fh, Image.INTERPOLATE_BILINEAR)
		base_img.blend_rect(head_img, Rect2i(0, 0, fw, fh), Vector2i.ZERO)
	var used: Rect2i = base_img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	var trimmed: Image = base_img.get_region(used)
	var scale_f: float = 68.0 / float(maxi(used.size.x, used.size.y))
	var tw: int = maxi(1, int(round(float(used.size.x) * scale_f)))
	var th: int = maxi(1, int(round(float(used.size.y) * scale_f)))
	trimmed.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	var sq := Image.create(76, 76, false, Image.FORMAT_RGBA8)
	sq.fill(Color(0, 0, 0, 0))
	sq.blit_rect(trimmed, Rect2i(0, 0, tw, th), Vector2i((76 - tw) / 2, (76 - th) / 2))
	return ImageTexture.create_from_image(sq)


var _preview_saved_match_mode: int = -1


func _populate_bot_agent_option_button(opt: OptionButton) -> void:
	opt.clear()
	opt.add_item("Unique Agents (No Duplicates — Including You)", -1)
	for i in _get_sorted_agent_indices():
		var arch: Dictionary = ProfileManager.ARCHETYPES[i]
		opt.add_item("All Bots: %s" % str(arch.get("name", arch.get("callsign", "Agent"))), i)


func _sync_bot_agent_option_buttons() -> void:
	var target_id: int = NetworkManager.practice_bot_agent_id
	for opt in [_test_bot_agent_opt, _practice_agent_bot_opt]:
		if is_instance_valid(opt):
			var idx: int = opt.get_item_index(target_id)
			if idx >= 0:
				opt.select(idx)


func _open_agent_select(for_practice: bool = false) -> void:
	_preview_saved_match_mode = NetworkManager.match_mode
	NetworkManager.match_mode = 2
	_agent_select_for_practice = for_practice
	_agent_preview_idx = clampi(ProfileManager.archetype_id, 0, AgentData.AGENTS.size() - 1)
	if not for_practice and not ProfileManager.is_agent_unlocked(_agent_preview_idx, false):
		_agent_preview_idx = 0
		ProfileManager.apply_archetype_preset(0, false)
	if is_instance_valid(_practice_agent_bot_row):
		_practice_agent_bot_row.visible = for_practice
	_sync_bot_agent_option_buttons()
	_refresh_agent_select_ui()
	if is_instance_valid(_preview):
		_preview.visible = false
	_agent_select_overlay.visible = true
	_agent_select_overlay.modulate.a = 0.0
	create_tween().tween_property(_agent_select_overlay, "modulate:a", 1.0, 0.16)


func _close_agent_select() -> void:
	if _preview_saved_match_mode >= 0:
		NetworkManager.match_mode = _preview_saved_match_mode
		_preview_saved_match_mode = -1
	if is_instance_valid(_preview):
		_preview.visible = true
	if is_instance_valid(_agent_select_overlay):
		_agent_select_overlay.visible = false
	_update_new_item_badges()


func _build_test_mode_overlay() -> void:
	_test_mode_overlay = ColorRect.new()
	_test_mode_overlay.z_index = 20
	_test_mode_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_test_mode_overlay.color = Color(0.02, 0.03, 0.06, 0.86)
	_test_mode_overlay.visible = false
	add_child(_test_mode_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_test_mode_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 380)
	card.add_theme_stylebox_override("panel", _make_style(Color(0.07, 0.11, 0.17, 0.98), Color(0.24, 0.86, 0.82, 0.95), 16))
	cc.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	card.add_child(cv)

	var top_row := HBoxContainer.new()
	cv.add_child(top_row)

	var title := Label.new()
	title.text = "PRACTICE MODE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(0.38, 0.92, 0.88)
	top_row.add_child(title)

	var close_btn := _make_arcade_button("CLOSE", Color(0.95, 0.42, 0.36), 38.0, 14)
	close_btn.custom_minimum_size = Vector2(96, 38)
	close_btn.pressed.connect(_close_test_mode_overlay)
	top_row.add_child(close_btn)

	var boxes_row := HBoxContainer.new()
	boxes_row.add_theme_constant_override("separation", 12)
	cv.add_child(boxes_row)

	# Box 1: Gameplay Mode (Gun Mode, Agent Mode)
	var mode_box := PanelContainer.new()
	mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_box.size_flags_stretch_ratio = 0.85
	mode_box.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.08, 0.13, 0.95), Color(0.24, 0.56, 0.68, 0.85), 12))
	boxes_row.add_child(mode_box)

	var mode_vb := VBoxContainer.new()
	mode_vb.add_theme_constant_override("separation", 10)
	mode_box.add_child(mode_vb)

	var mode_lbl := Label.new()
	mode_lbl.text = "GAMEPLAY MODE"
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_lbl.add_theme_font_size_override("font_size", 14)
	mode_lbl.modulate = Color(0.75, 0.85, 0.95)
	mode_vb.add_child(mode_lbl)

	_test_mode_type_buttons.clear()
	var mode_specs: Array[Dictionary] = [
		{"mode": 0, "label": "GUN MODE"},
		{"mode": 2, "label": "AGENT MODE"},
		{"mode": 4, "label": "SHOOTING RANGE"}
	]
	for ms in mode_specs:
		var mb := Button.new()
		mb.text = str(ms["label"])
		mb.custom_minimum_size = Vector2(0, 44)
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.add_theme_font_size_override("font_size", 15)
		mb.pressed.connect(func():
			_test_mode_choice = int(ms["mode"])
			_refresh_test_mode_ui()
		)
		mode_vb.add_child(mb)
		_test_mode_type_buttons.append(mb)

	# Box 2: Bot Behavior (Still, Move Only, Attack) + Bot Count (- / +)
	var bot_box := PanelContainer.new()
	bot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_box.size_flags_stretch_ratio = 1.45
	bot_box.add_theme_stylebox_override("panel", _make_style(Color(0.05, 0.08, 0.13, 0.95), Color(0.24, 0.56, 0.68, 0.85), 12))
	boxes_row.add_child(bot_box)

	var bot_vb := VBoxContainer.new()
	bot_vb.add_theme_constant_override("separation", 10)
	bot_box.add_child(bot_vb)

	var beh_lbl := Label.new()
	beh_lbl.text = "BOT BEHAVIOR"
	beh_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beh_lbl.add_theme_font_size_override("font_size", 14)
	beh_lbl.modulate = Color(0.75, 0.85, 0.95)
	bot_vb.add_child(beh_lbl)

	var beh_row := HBoxContainer.new()
	beh_row.add_theme_constant_override("separation", 8)
	bot_vb.add_child(beh_row)

	_test_bot_beh_buttons.clear()
	var beh_labels: Array[String] = ["STILL", "MOVE ONLY", "ATTACK"]
	for i in range(beh_labels.size()):
		var bb := Button.new()
		bb.text = beh_labels[i]
		bb.custom_minimum_size = Vector2(0, 44)
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.add_theme_font_size_override("font_size", 14)
		bb.pressed.connect(func():
			_test_bot_choice = i
			_refresh_test_mode_ui()
		)
		beh_row.add_child(bb)
		_test_bot_beh_buttons.append(bb)

	var t_bot_row := HBoxContainer.new()
	t_bot_row.add_theme_constant_override("separation", 8)
	bot_vb.add_child(t_bot_row)

	var t_bot_lbl := Label.new()
	t_bot_lbl.text = "BOT COUNT:"
	t_bot_lbl.add_theme_font_size_override("font_size", 14)
	t_bot_lbl.modulate = Color(0.75, 0.85, 0.95)
	t_bot_row.add_child(t_bot_lbl)

	var t_bot_val := Label.new()
	t_bot_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_bot_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_bot_val.add_theme_font_size_override("font_size", 16)
	t_bot_val.modulate = Color(1.0, 0.88, 0.35)
	t_bot_val.text = str(clampi(NetworkManager.test_bot_count, 1, NetworkManager.MAX_BOTS))

	var t_minus := _make_arcade_button("-", Color(0.95, 0.42, 0.36), 40.0, 16)
	t_minus.custom_minimum_size = Vector2(54, 40)
	t_minus.pressed.connect(func():
		NetworkManager.test_bot_count = maxi(1, NetworkManager.test_bot_count - 1)
		t_bot_val.text = str(NetworkManager.test_bot_count)
	)
	t_bot_row.add_child(t_minus)
	t_bot_row.add_child(t_bot_val)

	var t_plus := _make_arcade_button("+", Color(0.32, 0.92, 0.48), 40.0, 16)
	t_plus.custom_minimum_size = Vector2(54, 40)
	t_plus.pressed.connect(func():
		NetworkManager.test_bot_count = mini(NetworkManager.MAX_BOTS, NetworkManager.test_bot_count + 1)
		t_bot_val.text = str(NetworkManager.test_bot_count)
	)
	t_bot_row.add_child(t_plus)

	var t_ag_row := HBoxContainer.new()
	t_ag_row.add_theme_constant_override("separation", 8)
	bot_vb.add_child(t_ag_row)

	var t_ag_lbl := Label.new()
	t_ag_lbl.text = "BOT AGENTS:"
	t_ag_lbl.add_theme_font_size_override("font_size", 14)
	t_ag_lbl.modulate = Color(0.75, 0.85, 0.95)
	t_ag_row.add_child(t_ag_lbl)

	_test_bot_agent_opt = OptionButton.new()
	_test_bot_agent_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_bot_agent_opt.custom_minimum_size = Vector2(0, 38)
	_test_bot_agent_opt.clip_text = true
	_populate_bot_agent_option_button(_test_bot_agent_opt)
	_test_bot_agent_opt.item_selected.connect(func(item_idx: int):
		NetworkManager.practice_bot_agent_id = _test_bot_agent_opt.get_item_id(item_idx)
		_sync_bot_agent_option_buttons()
	)
	t_ag_row.add_child(_test_bot_agent_opt)

	# Bottom section: Gravity Settings & Unlimited Abilities checkbox
	var grav_row := HBoxContainer.new()
	grav_row.add_theme_constant_override("separation", 10)
	cv.add_child(grav_row)

	var grav_lbl := Label.new()
	grav_lbl.text = "GRAVITY:"
	grav_lbl.custom_minimum_size = Vector2(110, 0)
	grav_lbl.add_theme_font_size_override("font_size", 14)
	grav_lbl.modulate = Color(0.75, 0.88, 1.0)
	grav_row.add_child(grav_lbl)

	_test_grav_slider = HSlider.new()
	_test_grav_slider.min_value = 0.0
	_test_grav_slider.max_value = 1.0
	_test_grav_slider.step = 0.05
	_test_grav_slider.value = NetworkManager.gravity_scale
	_test_grav_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_grav_slider.custom_minimum_size = Vector2(0, 28)
	_test_grav_slider.value_changed.connect(func(v: float):
		NetworkManager.gravity_scale = v
		SettingsManager.gravity_scale = v
		if is_instance_valid(_test_grav_val_lbl):
			_test_grav_val_lbl.text = "%.2fx" % v
	)
	grav_row.add_child(_test_grav_slider)

	_test_grav_val_lbl = Label.new()
	_test_grav_val_lbl.custom_minimum_size = Vector2(58, 0)
	_test_grav_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_test_grav_val_lbl.add_theme_font_size_override("font_size", 15)
	_test_grav_val_lbl.modulate = Color(1.0, 0.88, 0.35)
	_test_grav_val_lbl.text = "%.2fx" % NetworkManager.gravity_scale
	grav_row.add_child(_test_grav_val_lbl)

	var jet_row := HBoxContainer.new()
	jet_row.add_theme_constant_override("separation", 10)
	cv.add_child(jet_row)

	var jet_lbl := Label.new()
	jet_lbl.text = "JET SPEED:"
	jet_lbl.custom_minimum_size = Vector2(110, 0)
	jet_lbl.add_theme_font_size_override("font_size", 14)
	jet_lbl.modulate = Color(0.75, 0.88, 1.0)
	jet_row.add_child(jet_lbl)

	_test_jet_slider = HSlider.new()
	_test_jet_slider.min_value = 0.1
	_test_jet_slider.max_value = 1.0
	_test_jet_slider.step = 0.05
	_test_jet_slider.value = NetworkManager.jet_speed_scale
	_test_jet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_test_jet_slider.custom_minimum_size = Vector2(0, 28)
	_test_jet_slider.value_changed.connect(func(v: float):
		NetworkManager.jet_speed_scale = clampf(v, 0.1, 1.0)
		SettingsManager.jet_speed_scale = NetworkManager.jet_speed_scale
		SettingsManager.save_settings()
		if is_instance_valid(_test_jet_val_lbl):
			_test_jet_val_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	)
	jet_row.add_child(_test_jet_slider)

	_test_jet_val_lbl = Label.new()
	_test_jet_val_lbl.custom_minimum_size = Vector2(58, 0)
	_test_jet_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_test_jet_val_lbl.add_theme_font_size_override("font_size", 15)
	_test_jet_val_lbl.modulate = Color(1.0, 0.88, 0.35)
	_test_jet_val_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	jet_row.add_child(_test_jet_val_lbl)

	var unlim_ab_cb := CheckBox.new()
	unlim_ab_cb.text = "  Unlimited Abilities & Ultimate (No Kills Required)"
	unlim_ab_cb.button_pressed = NetworkManager.unlimited_abilities_practice
	unlim_ab_cb.add_theme_font_size_override("font_size", 14)
	unlim_ab_cb.modulate = Color(0.95, 0.88, 0.45)
	unlim_ab_cb.toggled.connect(func(on: bool):
		NetworkManager.unlimited_abilities_practice = on
	)
	cv.add_child(unlim_ab_cb)

	var start_btn := _make_arcade_button("START PRACTICE", Color(0.30, 0.92, 0.56), 50.0, 18)
	start_btn.pressed.connect(func():
		if _test_mode_choice == 2:
			_close_test_mode_overlay()
			_open_agent_select(true)
			return
		NetworkManager.disconnect_network()
		NetworkManager.test_mode_enabled = true
		NetworkManager.practice_shooting_range = (_test_mode_choice == 4)
		NetworkManager.match_mode = 0 if _test_mode_choice == 4 else _test_mode_choice
		NetworkManager.test_bot_behavior = _test_bot_choice
		_close_test_mode_overlay()
		_open_map_select(func(): _transition_to(NetworkManager.go_to_arena))
	)
	cv.add_child(start_btn)
	_refresh_test_mode_ui()


func _refresh_test_mode_ui() -> void:
	var mode_vals: Array[int] = [0, 2, 4]
	for i in range(_test_mode_type_buttons.size()):
		var btn: Button = _test_mode_type_buttons[i]
		var active: bool = (_test_mode_choice == mode_vals[i])
		var bd: Color = Color(0.24, 0.86, 0.82) if active else Color(0.30, 0.40, 0.55)
		var bg: Color = Color(0.10, 0.28, 0.30) if active else Color(0.09, 0.12, 0.18, 0.95)
		btn.add_theme_stylebox_override("normal", _make_style(bg, bd, 8))
		btn.add_theme_stylebox_override("hover", _make_style(bg.lightened(0.12), bd.lightened(0.2), 8))
		btn.modulate = Color.WHITE if active else Color(0.75, 0.80, 0.88)

	var beh_cols: Array[Color] = [Color(0.35, 0.78, 1.0), Color(0.98, 0.75, 0.22), Color(0.95, 0.32, 0.32)]
	for i in range(_test_bot_beh_buttons.size()):
		var btn: Button = _test_bot_beh_buttons[i]
		var active: bool = (_test_bot_choice == i)
		var bd: Color = beh_cols[i] if active else Color(0.30, 0.40, 0.55)
		var bg: Color = beh_cols[i].darkened(0.65) if active else Color(0.09, 0.12, 0.18, 0.95)
		btn.add_theme_stylebox_override("normal", _make_style(bg, bd, 8))
		btn.add_theme_stylebox_override("hover", _make_style(bg.lightened(0.12), bd.lightened(0.2), 8))
		btn.modulate = Color.WHITE if active else Color(0.75, 0.80, 0.88)


func _open_test_mode_overlay() -> void:
	_test_mode_choice = 4 if NetworkManager.is_shooting_range_mode() else (2 if NetworkManager.is_agent_clash_mode() else 0)
	_test_bot_choice = clampi(NetworkManager.test_bot_behavior, 0, 2)
	if is_instance_valid(_test_grav_slider):
		_test_grav_slider.value = NetworkManager.gravity_scale
	if is_instance_valid(_test_grav_val_lbl):
		_test_grav_val_lbl.text = "%.2fx" % NetworkManager.gravity_scale
	_refresh_test_mode_ui()
	_test_mode_overlay.visible = true
	_test_mode_overlay.modulate.a = 0.0
	create_tween().tween_property(_test_mode_overlay, "modulate:a", 1.0, 0.16)


func _close_test_mode_overlay() -> void:
	if is_instance_valid(_test_mode_overlay):
		_test_mode_overlay.visible = false


func _build_map_select_overlay() -> void:
	_map_select_overlay = ColorRect.new()
	_map_select_overlay.z_index = 20
	_map_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_select_overlay.color = Color(0.02, 0.03, 0.06, 0.90)
	_map_select_overlay.visible = false
	add_child(_map_select_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_map_select_overlay.add_child(margin)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.10, 0.16, 0.98), Color(0.32, 0.78, 1.0, 0.95), 16))
	margin.add_child(card)

	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 12)
	card.add_child(mv)

	_map_title_label = Label.new()
	_map_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_title_label.add_theme_font_size_override("font_size", 24)
	_map_title_label.modulate = Color(0.45, 0.90, 1.0)
	mv.add_child(_map_title_label)

	var mid_row := HBoxContainer.new()
	mid_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_row.add_theme_constant_override("separation", 14)
	mv.add_child(mid_row)

	var prev_btn := _make_arcade_button("<", Color(0.36, 0.78, 1.0), 80.0, 28)
	prev_btn.custom_minimum_size = Vector2(76, 0)
	prev_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prev_btn.pressed.connect(func():
		NetworkManager.selected_map_id = wrapi(NetworkManager.selected_map_id - 1, 0, NetworkManager.MAP_NAMES.size())
		_refresh_map_select_ui()
	)
	mid_row.add_child(prev_btn)

	var preview_frame := PanelContainer.new()
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_theme_stylebox_override("panel", _make_style(Color(0.03, 0.05, 0.09, 0.98), Color(0.28, 0.48, 0.72, 0.85), 12))
	mid_row.add_child(preview_frame)

	_map_preview_tex = TextureRect.new()
	_map_preview_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_preview_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_frame.add_child(_map_preview_tex)

	var next_btn := _make_arcade_button(">", Color(0.36, 0.78, 1.0), 80.0, 28)
	next_btn.custom_minimum_size = Vector2(76, 0)
	next_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(func():
		NetworkManager.selected_map_id = wrapi(NetworkManager.selected_map_id + 1, 0, NetworkManager.MAP_NAMES.size())
		_refresh_map_select_ui()
	)
	mid_row.add_child(next_btn)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	mv.add_child(btn_row)

	var back_btn := _make_arcade_button("BACK", Color(0.95, 0.38, 0.36), 56.0, 20, Color(0.26, 0.10, 0.10, 0.96))
	back_btn.custom_minimum_size = Vector2(180, 56)
	back_btn.pressed.connect(func():
		_map_select_overlay.visible = false
		_pending_map_launch = Callable()
	)
	btn_row.add_child(back_btn)

	var select_btn := _make_arcade_button("SELECT MAP", Color(0.30, 0.92, 0.54), 56.0, 20)
	select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_btn.pressed.connect(func():
		if is_instance_valid(_map_opt):
			_map_opt.selected = NetworkManager.selected_map_id
		_map_select_overlay.visible = false
		if _pending_map_launch.is_valid():
			_pending_map_launch.call()
	)
	btn_row.add_child(select_btn)


func _refresh_map_select_ui() -> void:
	var idx: int = clampi(NetworkManager.selected_map_id, 0, NetworkManager.MAP_NAMES.size() - 1)
	if is_instance_valid(_map_title_label):
		_map_title_label.text = "%s  (%d / %d)" % [NetworkManager.MAP_NAMES[idx].to_upper(), idx + 1, NetworkManager.MAP_NAMES.size()]
	if is_instance_valid(_map_preview_tex):
		_map_preview_tex.texture = _get_map_preview_texture(idx)
	if is_instance_valid(_map_opt):
		_map_opt.selected = idx


func _get_map_preview_texture(map_id: int) -> Texture2D:
	if _map_preview_cache.has(map_id):
		return _map_preview_cache[map_id] as Texture2D
	var res_p: String = "res://assets/tilemaps/preview_map_%d.png" % map_id
	var tex: Texture2D = null
	if ResourceLoader.exists(res_p):
		tex = load(res_p) as Texture2D
	if tex == null:
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(res_p)) == OK:
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_map_preview_cache[map_id] = tex
	return tex


func _open_map_select(on_confirm: Callable) -> void:
	_pending_map_launch = on_confirm
	_refresh_map_select_ui()
	move_child(_map_select_overlay, get_child_count() - 1)
	_map_select_overlay.visible = true
	_map_select_overlay.modulate.a = 0.0
	create_tween().tween_property(_map_select_overlay, "modulate:a", 1.0, 0.14)


func _build_match_settings_overlay() -> void:
	_match_settings_overlay = ColorRect.new()
	_match_settings_overlay.z_index = 50
	_match_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_settings_overlay.color = Color(0.02, 0.03, 0.06, 0.88)
	_match_settings_overlay.visible = false
	add_child(_match_settings_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_match_settings_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	card.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.10, 0.16, 0.98), Color(0.30, 0.92, 0.54, 0.95), 16))
	cc.add_child(card)

	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 12)
	card.add_child(mv)

	_ms_title_lbl = Label.new()
	_ms_title_lbl.text = "GUN GAME — MATCH SETTINGS"
	_ms_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ms_title_lbl.add_theme_font_size_override("font_size", 24)
	_ms_title_lbl.modulate = Color(0.35, 0.94, 0.56)
	mv.add_child(_ms_title_lbl)

	# Bot Difficulty
	var d_row := HBoxContainer.new()
	d_row.add_theme_constant_override("separation", 10)
	mv.add_child(d_row)
	var d_lbl := Label.new()
	d_lbl.text = "BOT LEVEL:"
	d_lbl.custom_minimum_size = Vector2(160, 0)
	d_lbl.add_theme_font_size_override("font_size", 16)
	d_lbl.modulate = Color(0.75, 0.88, 1.0)
	d_row.add_child(d_lbl)
	_diff_buttons.clear()
	var diff_labels: Array[String] = ["EASY", "MID", "HARD"]
	for i in range(diff_labels.size()):
		var db := Button.new()
		db.text = diff_labels[i]
		db.custom_minimum_size = Vector2(0, 44)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.add_theme_font_size_override("font_size", 17)
		db.pressed.connect(_select_bot_difficulty.bind(i))
		d_row.add_child(db)
		_diff_buttons.append(db)
	_refresh_diff_buttons()

	# Bot Count
	var b_row := HBoxContainer.new()
	b_row.add_theme_constant_override("separation", 10)
	mv.add_child(b_row)
	var b_lbl := Label.new()
	b_lbl.text = "BOT COUNT:"
	b_lbl.custom_minimum_size = Vector2(160, 0)
	b_lbl.add_theme_font_size_override("font_size", 16)
	b_lbl.modulate = Color(0.75, 0.88, 1.0)
	b_row.add_child(b_lbl)
	var b_minus := _make_arcade_button("-", Color(0.95, 0.42, 0.36), 44.0, 20)
	b_minus.custom_minimum_size = Vector2(68, 44)
	b_minus.pressed.connect(func():
		NetworkManager.bot_count = maxi(0, NetworkManager.bot_count - 1)
		_ms_bot_val_lbl.text = str(NetworkManager.bot_count)
	)
	b_row.add_child(b_minus)
	_ms_bot_val_lbl = Label.new()
	_ms_bot_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ms_bot_val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ms_bot_val_lbl.add_theme_font_size_override("font_size", 20)
	_ms_bot_val_lbl.modulate = Color(1.0, 0.88, 0.35)
	_ms_bot_val_lbl.text = str(NetworkManager.bot_count)
	b_row.add_child(_ms_bot_val_lbl)
	var b_plus := _make_arcade_button("+", Color(0.32, 0.92, 0.48), 44.0, 20)
	b_plus.custom_minimum_size = Vector2(68, 44)
	b_plus.pressed.connect(func():
		NetworkManager.bot_count = mini(NetworkManager.MAX_BOTS, NetworkManager.bot_count + 1)
		_ms_bot_val_lbl.text = str(NetworkManager.bot_count)
	)
	b_row.add_child(b_plus)

	# Gravity
	var g_row := HBoxContainer.new()
	g_row.add_theme_constant_override("separation", 10)
	mv.add_child(g_row)
	var g_lbl := Label.new()
	g_lbl.text = "GRAVITY:"
	g_lbl.custom_minimum_size = Vector2(160, 0)
	g_lbl.add_theme_font_size_override("font_size", 16)
	g_lbl.modulate = Color(0.75, 0.88, 1.0)
	g_row.add_child(g_lbl)
	_ms_grav_slider = HSlider.new()
	_ms_grav_slider.min_value = 0.0
	_ms_grav_slider.max_value = 1.0
	_ms_grav_slider.step = 0.05
	_ms_grav_slider.value = NetworkManager.gravity_scale
	_ms_grav_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ms_grav_slider.custom_minimum_size = Vector2(0, 32)
	_ms_grav_slider.value_changed.connect(func(v: float):
		NetworkManager.gravity_scale = v
		SettingsManager.gravity_scale = v
		if is_instance_valid(_ms_grav_val_lbl):
			_ms_grav_val_lbl.text = "%.2fx" % v
	)
	g_row.add_child(_ms_grav_slider)
	_ms_grav_val_lbl = Label.new()
	_ms_grav_val_lbl.custom_minimum_size = Vector2(64, 0)
	_ms_grav_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ms_grav_val_lbl.add_theme_font_size_override("font_size", 17)
	_ms_grav_val_lbl.modulate = Color(1.0, 0.88, 0.35)
	_ms_grav_val_lbl.text = "%.2fx" % NetworkManager.gravity_scale
	g_row.add_child(_ms_grav_val_lbl)

	# Match Timer (5..20 mins)
	var t_row := HBoxContainer.new()
	t_row.add_theme_constant_override("separation", 10)
	mv.add_child(t_row)
	var t_lbl := Label.new()
	t_lbl.text = "MATCH TIMER:"
	t_lbl.custom_minimum_size = Vector2(160, 0)
	t_lbl.add_theme_font_size_override("font_size", 16)
	t_lbl.modulate = Color(0.75, 0.88, 1.0)
	t_row.add_child(t_lbl)
	_ms_timer_slider = HSlider.new()
	_ms_timer_slider.min_value = NetworkManager.MIN_MATCH_MINUTES
	_ms_timer_slider.max_value = NetworkManager.MAX_MATCH_MINUTES
	_ms_timer_slider.step = 1
	_ms_timer_slider.value = NetworkManager.match_duration_minutes
	_ms_timer_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ms_timer_slider.custom_minimum_size = Vector2(0, 32)
	_ms_timer_slider.value_changed.connect(func(v: float):
		NetworkManager.match_duration_minutes = clampi(int(round(v)), NetworkManager.MIN_MATCH_MINUTES, NetworkManager.MAX_MATCH_MINUTES)
		if is_instance_valid(_ms_timer_val_lbl):
			_ms_timer_val_lbl.text = "%d MIN" % NetworkManager.match_duration_minutes
	)
	t_row.add_child(_ms_timer_slider)
	_ms_timer_val_lbl = Label.new()
	_ms_timer_val_lbl.custom_minimum_size = Vector2(64, 0)
	_ms_timer_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ms_timer_val_lbl.add_theme_font_size_override("font_size", 17)
	_ms_timer_val_lbl.modulate = Color(1.0, 0.88, 0.35)
	_ms_timer_val_lbl.text = "%d MIN" % NetworkManager.match_duration_minutes
	t_row.add_child(_ms_timer_val_lbl)

	# Jet Speed Slider (0.1 to 1.0)
	var j_row := HBoxContainer.new()
	j_row.add_theme_constant_override("separation", 10)
	mv.add_child(j_row)
	var j_lbl := Label.new()
	j_lbl.text = "JET SPEED:"
	j_lbl.custom_minimum_size = Vector2(160, 0)
	j_lbl.add_theme_font_size_override("font_size", 16)
	j_lbl.modulate = Color(0.75, 0.88, 1.0)
	j_row.add_child(j_lbl)
	_ms_jet_slider = HSlider.new()
	_ms_jet_slider.min_value = 0.1
	_ms_jet_slider.max_value = 1.0
	_ms_jet_slider.step = 0.05
	_ms_jet_slider.value = NetworkManager.jet_speed_scale
	_ms_jet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ms_jet_slider.custom_minimum_size = Vector2(0, 32)
	_ms_jet_slider.value_changed.connect(func(v: float):
		NetworkManager.jet_speed_scale = clampf(v, 0.1, 1.0)
		SettingsManager.jet_speed_scale = NetworkManager.jet_speed_scale
		SettingsManager.save_settings()
		if is_instance_valid(_ms_jet_val_lbl):
			_ms_jet_val_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	)
	j_row.add_child(_ms_jet_slider)
	_ms_jet_val_lbl = Label.new()
	_ms_jet_val_lbl.custom_minimum_size = Vector2(64, 0)
	_ms_jet_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ms_jet_val_lbl.add_theme_font_size_override("font_size", 17)
	_ms_jet_val_lbl.modulate = Color(1.0, 0.88, 0.35)
	_ms_jet_val_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	j_row.add_child(_ms_jet_val_lbl)

	# Unlimited Gas
	_ms_gas_chk = CheckBox.new()
	_ms_gas_chk.text = "  Unlimited Jetpack Gas"
	_ms_gas_chk.button_pressed = NetworkManager.unlimited_jetpack
	_ms_gas_chk.add_theme_font_size_override("font_size", 17)
	_ms_gas_chk.toggled.connect(func(on: bool):
		NetworkManager.unlimited_jetpack = on
		SettingsManager.unlimited_jetpack = on
		SettingsManager.save_settings()
	)
	mv.add_child(_ms_gas_chk)

	# Random Guns on Respawn (Gun Game only)
	_ms_random_guns_chk = CheckBox.new()
	_ms_random_guns_chk.text = "  Random Guns on Respawn (No Kit Selection)"
	_ms_random_guns_chk.button_pressed = NetworkManager.random_guns_mode
	_ms_random_guns_chk.add_theme_font_size_override("font_size", 17)
	_ms_random_guns_chk.modulate = Color(0.95, 0.88, 0.45)
	_ms_random_guns_chk.toggled.connect(func(on: bool):
		NetworkManager.random_guns_mode = on
		SettingsManager.random_guns_mode = on
		SettingsManager.save_settings()
	)
	mv.add_child(_ms_random_guns_chk)

	# Restricted Guns Dropdown (Gun Game only)
	_ms_guns_row = HBoxContainer.new()
	_ms_guns_row.add_theme_constant_override("separation", 10)
	mv.add_child(_ms_guns_row)
	var rg_lbl := Label.new()
	rg_lbl.text = "RESTRICT GUNS:"
	rg_lbl.custom_minimum_size = Vector2(160, 0)
	rg_lbl.add_theme_font_size_override("font_size", 16)
	rg_lbl.modulate = Color(0.75, 0.88, 1.0)
	_ms_guns_row.add_child(rg_lbl)
	_ms_guns_menu = MenuButton.new()
	_ms_guns_menu.text = "Restricted Guns: None"
	_ms_guns_menu.custom_minimum_size = Vector2(0, 44)
	_ms_guns_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ms_guns_menu.add_theme_font_size_override("font_size", 16)
	_ms_guns_menu.flat = false
	var pop: PopupMenu = _ms_guns_menu.get_popup()
	pop.hide_on_checkable_item_selection = false
	for grp in WeaponData.get_weapon_category_groups([0, 1, 2, 23, 24, 3, 4, 5, 6, 7, 8, 9, 20, 10, 18]):
		pop.add_separator(str(grp["label"]))
		for wid_v in (grp["ids"] as Array):
			var wi: int = int(wid_v)
			var wd: WeaponData = WeaponData.get_weapon(wi)
			pop.add_check_item(wd.display_name, wi)
			var idx: int = pop.get_item_index(wi)
			if idx >= 0:
				pop.set_item_checked(idx, NetworkManager.restricted_weapons.has(wi))
	pop.id_pressed.connect(func(wid: int):
		var idx: int = pop.get_item_index(wid)
		var now_chk: bool = not pop.is_item_checked(idx)
		pop.set_item_checked(idx, now_chk)
		if now_chk and not NetworkManager.restricted_weapons.has(wid):
			NetworkManager.restricted_weapons.append(wid)
		elif not now_chk:
			NetworkManager.restricted_weapons.erase(wid)
		_refresh_restricted_guns_label()
	)
	_ms_guns_row.add_child(_ms_guns_menu)

	# Select Map Row
	var m_row := HBoxContainer.new()
	m_row.add_theme_constant_override("separation", 10)
	mv.add_child(m_row)
	var m_lbl := Label.new()
	m_lbl.text = "MAP:"
	m_lbl.custom_minimum_size = Vector2(160, 0)
	m_lbl.add_theme_font_size_override("font_size", 16)
	m_lbl.modulate = Color(0.75, 0.88, 1.0)
	m_row.add_child(m_lbl)
	_ms_map_btn = _make_arcade_button("SELECT MAP", Color(0.36, 0.78, 1.0), 46.0, 17)
	_ms_map_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ms_map_btn.pressed.connect(func():
		_open_map_select(func():
			if is_instance_valid(_ms_map_btn):
				_ms_map_btn.text = "MAP: %s" % NetworkManager.MAP_NAMES[clampi(NetworkManager.selected_map_id, 0, NetworkManager.MAP_NAMES.size() - 1)]
		)
	)
	m_row.add_child(_ms_map_btn)

	# Bottom Actions
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 12)
	mv.add_child(act_row)
	var back_btn := _make_arcade_button("BACK", Color(0.95, 0.38, 0.36), 54.0, 19, Color(0.26, 0.10, 0.10, 0.96))
	back_btn.custom_minimum_size = Vector2(160, 54)
	back_btn.pressed.connect(func():
		_match_settings_overlay.visible = false
	)
	act_row.add_child(back_btn)
	var start_btn := _make_arcade_button("START BATTLE", Color(0.30, 0.92, 0.48), 54.0, 20, Color(0.09, 0.28, 0.16, 0.98))
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(func():
		_match_settings_overlay.visible = false
		_transition_to(NetworkManager.go_to_arena)
	)
	act_row.add_child(start_btn)


func _refresh_restricted_guns_label() -> void:
	if not is_instance_valid(_ms_guns_menu):
		return
	var cnt: int = NetworkManager.restricted_weapons.size()
	_ms_guns_menu.text = "Restricted Guns: None" if cnt == 0 else ("Restricted Guns: %d blocked" % cnt)


func _open_match_settings(for_agent_clash: bool) -> void:
	_ms_for_agent = for_agent_clash
	if is_instance_valid(_ms_title_lbl):
		_ms_title_lbl.text = "AGENT CLASH — MATCH SETTINGS" if for_agent_clash else "GUN GAME — MATCH SETTINGS"
		_ms_title_lbl.modulate = Color(0.78, 0.48, 1.0) if for_agent_clash else Color(0.35, 0.94, 0.56)
	if is_instance_valid(_ms_guns_row):
		_ms_guns_row.visible = not for_agent_clash
	if is_instance_valid(_ms_random_guns_chk):
		_ms_random_guns_chk.visible = not for_agent_clash
		_ms_random_guns_chk.button_pressed = NetworkManager.random_guns_mode
	if is_instance_valid(_ms_bot_val_lbl):
		_ms_bot_val_lbl.text = str(NetworkManager.bot_count)
	if is_instance_valid(_ms_grav_slider):
		_ms_grav_slider.value = NetworkManager.gravity_scale
	if is_instance_valid(_ms_grav_val_lbl):
		_ms_grav_val_lbl.text = "%.2fx" % NetworkManager.gravity_scale
	if is_instance_valid(_ms_jet_slider):
		_ms_jet_slider.value = NetworkManager.jet_speed_scale
	if is_instance_valid(_ms_jet_val_lbl):
		_ms_jet_val_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	if is_instance_valid(_ms_timer_slider):
		_ms_timer_slider.value = NetworkManager.match_duration_minutes
	if is_instance_valid(_ms_timer_val_lbl):
		_ms_timer_val_lbl.text = "%d MIN" % NetworkManager.match_duration_minutes
	if is_instance_valid(_ms_gas_chk):
		_ms_gas_chk.button_pressed = NetworkManager.unlimited_jetpack
	if is_instance_valid(_ms_map_btn):
		_ms_map_btn.text = "MAP: %s" % NetworkManager.MAP_NAMES[clampi(NetworkManager.selected_map_id, 0, NetworkManager.MAP_NAMES.size() - 1)]
	_refresh_diff_buttons()
	_refresh_restricted_guns_label()
	_match_settings_overlay.visible = true


func _build_local_mode_overlays() -> void:
	# 1. Local Mode choice (HOST / JOIN)
	_local_mode_overlay = ColorRect.new()
	_local_mode_overlay.z_index = 50
	_local_mode_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_local_mode_overlay.color = Color(0.02, 0.03, 0.06, 0.88)
	_local_mode_overlay.visible = false
	add_child(_local_mode_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_local_mode_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.10, 0.16, 0.98), Color(0.28, 0.76, 1.0, 0.95), 16))
	cc.add_child(card)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 16)
	card.add_child(lv)

	var l_hdr := Label.new()
	l_hdr.text = "LOCAL WI-FI MODE"
	l_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_hdr.add_theme_font_size_override("font_size", 26)
	l_hdr.modulate = Color(0.38, 0.85, 1.0)
	lv.add_child(l_hdr)

	var hj_row := HBoxContainer.new()
	hj_row.add_theme_constant_override("separation", 16)
	lv.add_child(hj_row)

	var host_big := _make_icon_card_button("HOST ROOM", "res://assets/ui/icons/icon_host_room.png", Color(0.98, 0.62, 0.20), 146.0, 21, Color(0.24, 0.14, 0.06, 0.98), 76)
	host_big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_big.pressed.connect(func():
		_local_mode_overlay.visible = false
		_open_local_host()
	)
	hj_row.add_child(host_big)

	var join_big := _make_icon_card_button("JOIN ROOM", "res://assets/ui/icons/icon_join_room.png", Color(0.30, 0.82, 1.0), 146.0, 21, Color(0.09, 0.20, 0.34, 0.98), 76)
	join_big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_big.pressed.connect(func():
		_local_mode_overlay.visible = false
		_open_local_join()
	)
	hj_row.add_child(join_big)

	var close_lm := _make_arcade_button("BACK", Color(0.95, 0.38, 0.36), 50.0, 18)
	close_lm.pressed.connect(func(): _local_mode_overlay.visible = false)
	lv.add_child(close_lm)

	# 2. Local Host Setup Overlay
	_local_host_overlay = ColorRect.new()
	_local_host_overlay.z_index = 50
	_local_host_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_local_host_overlay.color = Color(0.02, 0.03, 0.06, 0.88)
	_local_host_overlay.visible = false
	add_child(_local_host_overlay)

	var hcc := CenterContainer.new()
	hcc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_local_host_overlay.add_child(hcc)

	var hcard := PanelContainer.new()
	hcard.custom_minimum_size = Vector2(640, 0)
	hcard.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.10, 0.16, 0.98), Color(0.98, 0.62, 0.20, 0.95), 16))
	hcc.add_child(hcard)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	hcard.add_child(hv)

	var h_title := Label.new()
	h_title.text = "CREATE LOCAL ROOM"
	h_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_title.add_theme_font_size_override("font_size", 24)
	h_title.modulate = Color(1.0, 0.78, 0.28)
	hv.add_child(h_title)

	var rn_row := HBoxContainer.new()
	rn_row.add_theme_constant_override("separation", 10)
	hv.add_child(rn_row)
	var rn_lbl := Label.new()
	rn_lbl.text = "ROOM NAME:"
	rn_lbl.custom_minimum_size = Vector2(160, 0)
	rn_lbl.add_theme_font_size_override("font_size", 16)
	rn_row.add_child(rn_lbl)
	_lh_room_input = LineEdit.new()
	_lh_room_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lh_room_input.custom_minimum_size = Vector2(0, 42)
	_lh_room_input.add_theme_font_size_override("font_size", 17)
	rn_row.add_child(_lh_room_input)

	var mp_row := HBoxContainer.new()
	mp_row.add_theme_constant_override("separation", 10)
	hv.add_child(mp_row)
	var mp_lbl := Label.new()
	mp_lbl.text = "MAX PLAYERS:"
	mp_lbl.custom_minimum_size = Vector2(160, 0)
	mp_lbl.add_theme_font_size_override("font_size", 16)
	mp_row.add_child(mp_lbl)
	var mp_min := _make_arcade_button("-", Color(0.95, 0.42, 0.36), 40.0, 18)
	mp_min.custom_minimum_size = Vector2(60, 40)
	mp_min.pressed.connect(func():
		NetworkManager.max_room_players = maxi(2, NetworkManager.max_room_players - 1)
		NetworkManager.team_count = clampi(NetworkManager.team_count, 2, maxi(2, NetworkManager.max_room_players / 2))
		_refresh_local_host_labels()
	)
	mp_row.add_child(mp_min)
	_lh_max_lbl = Label.new()
	_lh_max_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lh_max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lh_max_lbl.add_theme_font_size_override("font_size", 18)
	mp_row.add_child(_lh_max_lbl)
	var mp_pls := _make_arcade_button("+", Color(0.32, 0.92, 0.48), 40.0, 18)
	mp_pls.custom_minimum_size = Vector2(60, 40)
	mp_pls.pressed.connect(func():
		NetworkManager.max_room_players = mini(20, NetworkManager.max_room_players + 1)
		_refresh_local_host_labels()
	)
	mp_row.add_child(mp_pls)

	var md_row := HBoxContainer.new()
	md_row.add_theme_constant_override("separation", 10)
	hv.add_child(md_row)
	var md_lbl := Label.new()
	md_lbl.text = "MODE:"
	md_lbl.custom_minimum_size = Vector2(160, 0)
	md_lbl.add_theme_font_size_override("font_size", 16)
	md_row.add_child(md_lbl)
	_lh_mode_btn = _make_arcade_button("Free-For-All", Color(0.36, 0.78, 1.0), 42.0, 16)
	_lh_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lh_mode_btn.pressed.connect(func():
		NetworkManager.match_mode = (NetworkManager.match_mode + 1) % NetworkManager.MODE_NAMES.size()
		_refresh_local_host_labels()
	)
	md_row.add_child(_lh_mode_btn)

	_lh_team_row = HBoxContainer.new()
	_lh_team_row.add_theme_constant_override("separation", 10)
	hv.add_child(_lh_team_row)
	var tm_lbl := Label.new()
	tm_lbl.text = "TEAMS:"
	tm_lbl.custom_minimum_size = Vector2(160, 0)
	tm_lbl.add_theme_font_size_override("font_size", 16)
	_lh_team_row.add_child(tm_lbl)
	var tm_min := _make_arcade_button("-", Color(0.95, 0.42, 0.36), 40.0, 18)
	tm_min.custom_minimum_size = Vector2(60, 40)
	tm_min.pressed.connect(func():
		NetworkManager.team_count = maxi(2, NetworkManager.team_count - 1)
		_refresh_local_host_labels()
	)
	_lh_team_row.add_child(tm_min)
	_lh_team_lbl = Label.new()
	_lh_team_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lh_team_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lh_team_lbl.add_theme_font_size_override("font_size", 18)
	_lh_team_row.add_child(_lh_team_lbl)
	var tm_pls := _make_arcade_button("+", Color(0.32, 0.92, 0.48), 40.0, 18)
	tm_pls.custom_minimum_size = Vector2(60, 40)
	tm_pls.pressed.connect(func():
		NetworkManager.team_count = mini(maxi(2, NetworkManager.max_room_players / 2), NetworkManager.team_count + 1)
		_refresh_local_host_labels()
	)
	_lh_team_row.add_child(tm_pls)

	var lb_row := HBoxContainer.new()
	lb_row.add_theme_constant_override("separation", 10)
	hv.add_child(lb_row)
	var lb_lbl := Label.new()
	lb_lbl.text = "BOTS:"
	lb_lbl.custom_minimum_size = Vector2(160, 0)
	lb_lbl.add_theme_font_size_override("font_size", 16)
	lb_row.add_child(lb_lbl)
	var lb_min := _make_arcade_button("-", Color(0.95, 0.42, 0.36), 40.0, 18)
	lb_min.custom_minimum_size = Vector2(60, 40)
	lb_min.pressed.connect(func():
		NetworkManager.bot_count = maxi(0, NetworkManager.bot_count - 1)
		_refresh_local_host_labels()
	)
	lb_row.add_child(lb_min)
	_lh_bot_lbl = Label.new()
	_lh_bot_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lh_bot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lh_bot_lbl.add_theme_font_size_override("font_size", 18)
	lb_row.add_child(_lh_bot_lbl)
	var lb_pls := _make_arcade_button("+", Color(0.32, 0.92, 0.48), 40.0, 18)
	lb_pls.custom_minimum_size = Vector2(60, 40)
	lb_pls.pressed.connect(func():
		NetworkManager.bot_count = mini(NetworkManager.MAX_BOTS, NetworkManager.bot_count + 1)
		_refresh_local_host_labels()
	)
	lb_row.add_child(lb_pls)

	var lt_row := HBoxContainer.new()
	lt_row.add_theme_constant_override("separation", 10)
	hv.add_child(lt_row)
	var lt_lbl := Label.new()
	lt_lbl.text = "MATCH TIMER:"
	lt_lbl.custom_minimum_size = Vector2(160, 0)
	lt_lbl.add_theme_font_size_override("font_size", 16)
	lt_row.add_child(lt_lbl)
	_lh_timer_slider = HSlider.new()
	_lh_timer_slider.min_value = NetworkManager.MIN_MATCH_MINUTES
	_lh_timer_slider.max_value = NetworkManager.MAX_MATCH_MINUTES
	_lh_timer_slider.step = 1
	_lh_timer_slider.value = NetworkManager.match_duration_minutes
	_lh_timer_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lh_timer_slider.custom_minimum_size = Vector2(0, 32)
	_lh_timer_slider.value_changed.connect(func(v: float):
		NetworkManager.match_duration_minutes = clampi(int(round(v)), NetworkManager.MIN_MATCH_MINUTES, NetworkManager.MAX_MATCH_MINUTES)
		if is_instance_valid(_lh_timer_lbl):
			_lh_timer_lbl.text = "%d MIN" % NetworkManager.match_duration_minutes
	)
	lt_row.add_child(_lh_timer_slider)
	_lh_timer_lbl = Label.new()
	_lh_timer_lbl.custom_minimum_size = Vector2(64, 0)
	_lh_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lh_timer_lbl.add_theme_font_size_override("font_size", 17)
	_lh_timer_lbl.modulate = Color(1.0, 0.88, 0.35)
	_lh_timer_lbl.text = "%d MIN" % NetworkManager.match_duration_minutes
	lt_row.add_child(_lh_timer_lbl)

	var lj_row := HBoxContainer.new()
	lj_row.add_theme_constant_override("separation", 10)
	hv.add_child(lj_row)
	var lj_lbl := Label.new()
	lj_lbl.text = "JET SPEED:"
	lj_lbl.custom_minimum_size = Vector2(160, 0)
	lj_lbl.add_theme_font_size_override("font_size", 16)
	lj_row.add_child(lj_lbl)
	_lh_jet_slider = HSlider.new()
	_lh_jet_slider.min_value = 0.1
	_lh_jet_slider.max_value = 1.0
	_lh_jet_slider.step = 0.05
	_lh_jet_slider.value = NetworkManager.jet_speed_scale
	_lh_jet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lh_jet_slider.custom_minimum_size = Vector2(0, 32)
	_lh_jet_slider.value_changed.connect(func(v: float):
		NetworkManager.jet_speed_scale = clampf(v, 0.1, 1.0)
		SettingsManager.jet_speed_scale = NetworkManager.jet_speed_scale
		SettingsManager.save_settings()
		if is_instance_valid(_lh_jet_lbl):
			_lh_jet_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	)
	lj_row.add_child(_lh_jet_slider)
	_lh_jet_lbl = Label.new()
	_lh_jet_lbl.custom_minimum_size = Vector2(64, 0)
	_lh_jet_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lh_jet_lbl.add_theme_font_size_override("font_size", 17)
	_lh_jet_lbl.modulate = Color(1.0, 0.88, 0.35)
	_lh_jet_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	lj_row.add_child(_lh_jet_lbl)

	_lh_random_guns_chk = CheckBox.new()
	_lh_random_guns_chk.text = "  Random Guns on Respawn (No Kit Selection)"
	_lh_random_guns_chk.button_pressed = NetworkManager.random_guns_mode
	_lh_random_guns_chk.add_theme_font_size_override("font_size", 16)
	_lh_random_guns_chk.modulate = Color(0.95, 0.88, 0.45)
	_lh_random_guns_chk.toggled.connect(func(on: bool):
		NetworkManager.random_guns_mode = on
		SettingsManager.random_guns_mode = on
		SettingsManager.save_settings()
	)
	hv.add_child(_lh_random_guns_chk)

	var lm_row := HBoxContainer.new()
	lm_row.add_theme_constant_override("separation", 10)
	hv.add_child(lm_row)
	var lm_lbl := Label.new()
	lm_lbl.text = "MAP:"
	lm_lbl.custom_minimum_size = Vector2(160, 0)
	lm_lbl.add_theme_font_size_override("font_size", 16)
	lm_row.add_child(lm_lbl)
	_lh_map_btn = _make_arcade_button("SELECT MAP", Color(0.36, 0.78, 1.0), 42.0, 16)
	_lh_map_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lh_map_btn.pressed.connect(func():
		_open_map_select(func(): _refresh_local_host_labels())
	)
	lm_row.add_child(_lh_map_btn)

	var l_act := HBoxContainer.new()
	l_act.add_theme_constant_override("separation", 12)
	hv.add_child(l_act)
	var l_back := _make_arcade_button("BACK", Color(0.95, 0.38, 0.36), 52.0, 18)
	l_back.custom_minimum_size = Vector2(150, 52)
	l_back.pressed.connect(func():
		_local_host_overlay.visible = false
		_local_mode_overlay.visible = true
	)
	l_act.add_child(l_back)
	var create_btn := _make_arcade_button("CREATE ROOM", Color(0.30, 0.92, 0.48), 52.0, 19, Color(0.09, 0.28, 0.16, 0.98))
	create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	create_btn.pressed.connect(func():
		var saved_bots: int = NetworkManager.bot_count
		var err: Error = NetworkManager.host_game(_lh_room_input.text)
		NetworkManager.bot_count = saved_bots
		if err == OK:
			_local_host_overlay.visible = false
			_transition_to(NetworkManager.go_to_lobby)
	)
	l_act.add_child(create_btn)

	# 3. Local Join Server List Overlay
	_local_join_overlay = ColorRect.new()
	_local_join_overlay.z_index = 50
	_local_join_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_local_join_overlay.color = Color(0.02, 0.03, 0.06, 0.88)
	_local_join_overlay.visible = false
	add_child(_local_join_overlay)

	var jcc := CenterContainer.new()
	jcc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_local_join_overlay.add_child(jcc)

	var jcard := PanelContainer.new()
	jcard.custom_minimum_size = Vector2(620, 420)
	jcard.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.10, 0.16, 0.98), Color(0.30, 0.82, 1.0, 0.95), 16))
	jcc.add_child(jcard)

	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 12)
	jcard.add_child(jv)

	var j_title := Label.new()
	j_title.text = "NEARBY LOCAL SERVERS"
	j_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	j_title.add_theme_font_size_override("font_size", 24)
	j_title.modulate = Color(0.38, 0.85, 1.0)
	jv.add_child(j_title)

	_lj_status_lbl = Label.new()
	_lj_status_lbl.text = "Searching for nearby Wi-Fi rooms..."
	_lj_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lj_status_lbl.add_theme_font_size_override("font_size", 15)
	_lj_status_lbl.modulate = Color(0.75, 0.88, 1.0)
	jv.add_child(_lj_status_lbl)

	var jscroll := ScrollContainer.new()
	jscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	jscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	jv.add_child(jscroll)

	_lj_list_box = VBoxContainer.new()
	_lj_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lj_list_box.add_theme_constant_override("separation", 10)
	jscroll.add_child(_lj_list_box)

	var j_back := _make_arcade_button("BACK", Color(0.95, 0.38, 0.36), 50.0, 18)
	j_back.pressed.connect(func():
		_is_joining_lan = false
		NetworkManager.stop_lan_discovery()
		_local_join_overlay.visible = false
		_local_mode_overlay.visible = true
	)
	jv.add_child(j_back)

	NetworkManager.lan_servers_updated.connect(_refresh_local_join_list)
	NetworkManager.connection_succeeded.connect(func():
		if _is_joining_lan:
			_is_joining_lan = false
			NetworkManager.stop_lan_discovery()
			_local_join_overlay.visible = false
			_transition_to(NetworkManager.go_to_lobby)
	)
	NetworkManager.connection_failed.connect(func(reason: String):
		if _is_joining_lan and is_instance_valid(_lj_status_lbl):
			_is_joining_lan = false
			_lj_status_lbl.text = "Failed: " + reason
	)


func _open_local_mode_overlay() -> void:
	_local_mode_overlay.visible = true


func _open_local_host() -> void:
	NetworkManager.bot_count = 0
	if is_instance_valid(_lh_room_input):
		_lh_room_input.text = NetworkManager.local_room_name
	_refresh_local_host_labels()
	_local_host_overlay.visible = true


func _refresh_local_host_labels() -> void:
	if is_instance_valid(_lh_max_lbl):
		_lh_max_lbl.text = "%d Players" % NetworkManager.max_room_players
	if is_instance_valid(_lh_mode_btn):
		_lh_mode_btn.text = NetworkManager.MODE_NAMES[clampi(NetworkManager.match_mode, 0, NetworkManager.MODE_NAMES.size() - 1)]
	if is_instance_valid(_lh_team_row):
		_lh_team_row.visible = NetworkManager.is_team_mode()
	if is_instance_valid(_lh_team_lbl):
		_lh_team_lbl.text = "%d Teams" % NetworkManager.team_count
	if is_instance_valid(_lh_bot_lbl):
		_lh_bot_lbl.text = "%d Bots" % NetworkManager.bot_count
	if is_instance_valid(_lh_timer_slider):
		_lh_timer_slider.value = NetworkManager.match_duration_minutes
	if is_instance_valid(_lh_timer_lbl):
		_lh_timer_lbl.text = "%d MIN" % NetworkManager.match_duration_minutes
	if is_instance_valid(_lh_jet_slider):
		_lh_jet_slider.value = NetworkManager.jet_speed_scale
	if is_instance_valid(_lh_jet_lbl):
		_lh_jet_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	if is_instance_valid(_lh_random_guns_chk):
		_lh_random_guns_chk.visible = not NetworkManager.is_agent_clash_mode()
		_lh_random_guns_chk.button_pressed = NetworkManager.random_guns_mode
	if is_instance_valid(_lh_map_btn):
		_lh_map_btn.text = "MAP: %s" % NetworkManager.MAP_NAMES[clampi(NetworkManager.selected_map_id, 0, NetworkManager.MAP_NAMES.size() - 1)]


func _open_local_join() -> void:
	_is_joining_lan = false
	if is_instance_valid(_lj_status_lbl):
		_lj_status_lbl.text = "Searching for nearby Wi-Fi rooms..."
	NetworkManager.start_lan_discovery()
	_refresh_local_join_list(NetworkManager.discovered_servers.values())
	_local_join_overlay.visible = true


func _refresh_local_join_list(servers: Array) -> void:
	if not is_instance_valid(_lj_list_box):
		return
	for c in _lj_list_box.get_children():
		c.queue_free()
	if servers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No local servers found yet..."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.modulate = Color(0.7, 0.78, 0.88)
		_lj_list_box.add_child(empty_lbl)
		return
	for srv in servers:
		var ip: String = str(srv.get("ip", ""))
		var room: String = str(srv.get("room", "Hotspot Arena"))
		var count: int = int(srv.get("players", 1))
		var max_p: int = int(srv.get("max", NetworkManager.max_room_players))
		var map_n: String = str(srv.get("map", "Bunker Base"))
		var mode_n: String = str(srv.get("mode", "Free-For-All"))
		var btn := _make_arcade_button("JOIN  %s  •  %s [%s]  (%d/%d)" % [room, map_n, mode_n, count, max_p], Color(0.30, 0.82, 1.0), 54.0, 17, Color(0.10, 0.22, 0.36, 0.96))
		btn.pressed.connect(func():
			_is_joining_lan = true
			if is_instance_valid(_lj_status_lbl):
				_lj_status_lbl.text = "Joining %s..." % room
			NetworkManager.join_game(ip)
		)
		_lj_list_box.add_child(btn)


# --- COIN SYSTEM & GUN SKIN SHOP ---

func _build_gun_shop_overlay() -> void:
	_shop_overlay = ColorRect.new()
	_shop_overlay.color = Color(0.02, 0.04, 0.08, 0.86)
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.visible = false
	add_child(_shop_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(980, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	sb.border_color = Color(1.0, 0.84, 0.24, 0.98)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	cc.add_child(card)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	card.add_child(root_v)

	# Header Row
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	root_v.add_child(hdr)

	var title := Label.new()
	title.text = "WEAPONS  •  INSPECT STATS, EQUIP & BUY SKINS"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(1.0, 0.86, 0.28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	_shop_coin_lbl = _add_coin_icon_label(hdr, ProfileManager.format_coins(ProfileManager.coins), 22, 19, Color(1.0, 0.90, 0.30), false)

	var shop_get_coins := _make_arcade_button("+ NC", Color(0.36, 0.98, 0.56), 34.0, 14, Color(0.09, 0.30, 0.16, 0.96))
	shop_get_coins.custom_minimum_size = Vector2(104, 34)
	shop_get_coins.pressed.connect(func(): _open_coin_shop(_shop_overlay))
	hdr.add_child(shop_get_coins)

	var close_btn := _make_arcade_button("CLOSE", Color(0.92, 0.34, 0.34), 38.0, 15, Color(0.26, 0.08, 0.10, 0.96))
	close_btn.custom_minimum_size = Vector2(105, 38)
	close_btn.pressed.connect(func():
		_shop_overlay.visible = false
		_hub_container.visible = true
		_update_new_item_badges()
	)
	hdr.add_child(close_btn)

	# Body Split: Left Weapon List + Right Skin Preview & Cards
	var body_h := HBoxContainer.new()
	body_h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_h.add_theme_constant_override("separation", 14)
	root_v.add_child(body_h)

	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(265, 0)
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_h.add_child(left_scroll)

	var left_vb := VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_vb)

	_shop_gun_btns.clear()
	var shop_groups: Array[Dictionary] = WeaponData.get_weapon_category_groups(ProfileManager.SHOP_WEAPON_IDS)
	for g_idx in range(shop_groups.size()):
		var grp: Dictionary = shop_groups[g_idx]
		var cat_lbl := Label.new()
		cat_lbl.text = str(grp["label"])
		cat_lbl.add_theme_font_size_override("font_size", 11)
		cat_lbl.modulate = grp["color"] as Color
		if g_idx > 0:
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_top", 6)
			pad.add_child(cat_lbl)
			left_vb.add_child(pad)
		else:
			left_vb.add_child(cat_lbl)
		for wid_v in (grp["ids"] as Array):
			var wid: int = int(wid_v)
			var wd := WeaponData.get_weapon(wid, 0, 0)
			var gbtn := Button.new()
			gbtn.custom_minimum_size = Vector2(0, 44)
			gbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			gbtn.text = "  %s" % wd.display_name
			gbtn.icon = WeaponData.get_weapon_atlas_texture(wid, ProfileManager.get_equipped_gun_skin_row(wid))
			gbtn.expand_icon = true
			gbtn.add_theme_font_size_override("font_size", 15)
			gbtn.pressed.connect(func(): _select_shop_weapon(wid))
			left_vb.add_child(gbtn)
			_shop_gun_btns[wid] = gbtn

	var right_v := VBoxContainer.new()
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.add_theme_constant_override("separation", 10)
	body_h.add_child(right_v)

	# Preview & Weapon Stats Box
	var prev_panel := PanelContainer.new()
	prev_panel.custom_minimum_size = Vector2(0, 168)
	var prev_sb := StyleBoxFlat.new()
	prev_sb.bg_color = Color(0.08, 0.12, 0.20, 0.96)
	prev_sb.border_color = Color(0.28, 0.56, 0.92, 0.85)
	prev_sb.set_border_width_all(2)
	prev_sb.set_corner_radius_all(12)
	prev_sb.set_content_margin_all(10)
	prev_panel.add_theme_stylebox_override("panel", prev_sb)
	right_v.add_child(prev_panel)

	var prev_split := HBoxContainer.new()
	prev_split.add_theme_constant_override("separation", 14)
	prev_panel.add_child(prev_split)

	var prev_vb := VBoxContainer.new()
	prev_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_vb.size_flags_stretch_ratio = 1.05
	prev_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	prev_vb.add_theme_constant_override("separation", 4)
	prev_split.add_child(prev_vb)

	_shop_gun_title = Label.new()
	_shop_gun_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_gun_title.add_theme_font_size_override("font_size", 16)
	_shop_gun_title.modulate = Color(1.0, 0.92, 0.42)
	prev_vb.add_child(_shop_gun_title)

	_shop_gun_preview = TextureRect.new()
	_shop_gun_preview.custom_minimum_size = Vector2(240, 86)
	_shop_gun_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shop_gun_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_vb.add_child(_shop_gun_preview)

	_shop_gun_desc_lbl = Label.new()
	_shop_gun_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_gun_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shop_gun_desc_lbl.add_theme_font_size_override("font_size", 11)
	_shop_gun_desc_lbl.modulate = Color(0.72, 0.84, 0.96)
	prev_vb.add_child(_shop_gun_desc_lbl)

	var vsep := VSeparator.new()
	vsep.modulate = Color(0.35, 0.55, 0.85, 0.45)
	prev_split.add_child(vsep)

	_shop_stats_box = VBoxContainer.new()
	_shop_stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_stats_box.size_flags_stretch_ratio = 0.95
	_shop_stats_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_stats_box.add_theme_constant_override("separation", 6)
	prev_split.add_child(_shop_stats_box)

	# Skin Cards Grid
	var skin_scroll := ScrollContainer.new()
	skin_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skin_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_v.add_child(skin_scroll)

	_shop_skin_grid = GridContainer.new()
	_shop_skin_grid.columns = 2
	_shop_skin_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_skin_grid.add_theme_constant_override("h_separation", 10)
	_shop_skin_grid.add_theme_constant_override("v_separation", 10)
	skin_scroll.add_child(_shop_skin_grid)

	_shop_status_lbl = Label.new()
	_shop_status_lbl.text = "Select a weapon on the left and buy or equip skins!"
	_shop_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_status_lbl.add_theme_font_size_override("font_size", 14)
	_shop_status_lbl.modulate = Color(0.75, 0.86, 0.98)
	right_v.add_child(_shop_status_lbl)


func _open_gun_shop() -> void:
	_hub_container.visible = false
	_shop_overlay.visible = true
	if is_instance_valid(_shop_coin_lbl):
		_shop_coin_lbl.text = ProfileManager.format_coins(ProfileManager.coins)
	_select_shop_weapon(_shop_selected_weapon_id)


func _select_shop_weapon(wid: int) -> void:
	_shop_selected_weapon_id = wid
	_shop_preview_skin_key = ProfileManager.get_equipped_gun_skin(wid)
	for k in _shop_gun_btns:
		var b: Button = _shop_gun_btns[k] as Button
		b.modulate = Color(1.0, 0.88, 0.34) if int(k) == wid else Color(0.84, 0.88, 0.96)
	_refresh_shop_skins()


func _refresh_shop_weapon_stats(wd: WeaponData) -> void:
	if not is_instance_valid(_shop_stats_box):
		return
	for c in _shop_stats_box.get_children():
		c.queue_free()
	var total_dmg: float = float(wd.damage * maxi(1, wd.pellet_count))
	var dmg_txt: String = ("%d x%d" % [wd.damage, wd.pellet_count]) if wd.pellet_count > 1 else ("%d" % wd.damage)
	var rof_rps: float = 1.0 / maxf(0.04, wd.fire_interval)
	var rof_txt: String = ("%d-Burst (%.1f/s)" % [wd.burst_count, rof_rps]) if wd.burst_count > 1 else ("%.1f /s" % rof_rps)
	var range_px: float = wd.bullet_range if wd.bullet_range > 0.0 else 1800.0
	var range_txt: String = ("%d px" % int(round(wd.bullet_range))) if wd.bullet_range > 0.0 else "Long"
	var mag_txt: String = "%d  •  %.2fs" % [wd.mag_size, wd.reload_time]
	var acc_ratio: float = clampf(1.0 - (wd.spread_deg / 12.0), 0.12, 1.0)
	var acc_txt: String = "%.1f° spread" % wd.spread_deg

	var rows: Array[Dictionary] = [
		{"lbl": "DAMAGE",     "val": dmg_txt,   "ratio": clampf(total_dmg / 115.0, 0.08, 1.0), "col": Color(1.0, 0.42, 0.32)},
		{"lbl": "FIRE RATE",  "val": rof_txt,   "ratio": clampf(rof_rps / 14.0, 0.08, 1.0),    "col": Color(1.0, 0.80, 0.24)},
		{"lbl": "RANGE",      "val": range_txt, "ratio": clampf(range_px / 2200.0, 0.08, 1.0), "col": Color(0.35, 0.86, 1.0)},
		{"lbl": "MAG / RLD",  "val": mag_txt,   "ratio": clampf(float(wd.mag_size) / 60.0, 0.08, 1.0), "col": Color(0.45, 0.96, 0.58)},
		{"lbl": "ACCURACY",   "val": acc_txt,   "ratio": acc_ratio,                            "col": Color(0.76, 0.56, 1.0)}
	]
	for r in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		_shop_stats_box.add_child(hb)

		var l := Label.new()
		l.text = str(r["lbl"])
		l.custom_minimum_size = Vector2(76, 0)
		l.add_theme_font_size_override("font_size", 11)
		l.modulate = Color(0.76, 0.84, 0.95)
		hb.add_child(l)

		var pb := ProgressBar.new()
		pb.min_value = 0.0
		pb.max_value = 1.0
		pb.value = float(r["ratio"])
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 10)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg_sb := StyleBoxFlat.new()
		bg_sb.bg_color = Color(0.05, 0.07, 0.12, 0.95)
		bg_sb.set_corner_radius_all(4)
		var fill_sb := StyleBoxFlat.new()
		fill_sb.bg_color = r["col"] as Color
		fill_sb.set_corner_radius_all(4)
		pb.add_theme_stylebox_override("background", bg_sb)
		pb.add_theme_stylebox_override("fill", fill_sb)
		hb.add_child(pb)

		var v := Label.new()
		v.text = str(r["val"])
		v.custom_minimum_size = Vector2(96, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_theme_font_size_override("font_size", 11)
		v.modulate = (r["col"] as Color).lightened(0.2)
		hb.add_child(v)


func _refresh_shop_skins() -> void:
	if not is_instance_valid(_shop_skin_grid):
		return
	var wid: int = _shop_selected_weapon_id
	var wd := WeaponData.get_weapon(wid, 0, 0)
	var eq_key: String = ProfileManager.get_equipped_gun_skin(wid)
	var prev_key: String = _shop_preview_skin_key if not _shop_preview_skin_key.is_empty() else eq_key
	var prev_def: Dictionary = ProfileManager.get_gun_skin_def(prev_key)
	var state_tag: String = "Equipped" if prev_key == eq_key else "Preview"
	_shop_gun_title.text = "%s  —  %s: %s" % [wd.display_name, state_tag, ProfileManager.get_gun_skin_name(wid, prev_key)]
	_shop_gun_preview.texture = WeaponData.get_weapon_atlas_texture(wid, int(prev_def.get("sheet_row", 0)))
	_shop_gun_preview.modulate = ProfileManager.get_gun_skin_tint(wid, prev_key)
	if _shop_gun_btns.has(wid):
		var sb_btn: Button = _shop_gun_btns[wid] as Button
		if is_instance_valid(sb_btn):
			sb_btn.icon = WeaponData.get_weapon_atlas_texture(wid, ProfileManager.get_equipped_gun_skin_row(wid))
	for gk in _shop_gun_btns:
		var gb: Button = _shop_gun_btns[gk] as Button
		if is_instance_valid(gb):
			UIStyle.set_new_badge_visible(gb, ProfileManager.has_any_new_skin_for_weapon(int(str(gk))), "NewBadge", -6.0, 4.0, 10)
	if is_instance_valid(_shop_gun_desc_lbl):
		var cat_str: String = wd.category if not wd.category.is_empty() else "Weapon"
		_shop_gun_desc_lbl.text = "%s  •  %s" % [cat_str, wd.description] if not wd.description.is_empty() else cat_str
	_refresh_shop_weapon_stats(wd)
	if is_instance_valid(_shop_coin_lbl):
		_shop_coin_lbl.text = ProfileManager.format_coins(ProfileManager.coins)
	if is_instance_valid(_coin_pill_lbl):
		_coin_pill_lbl.text = ProfileManager.format_coins(ProfileManager.coins)

	for c in _shop_skin_grid.get_children():
		c.queue_free()

	for sdef in ProfileManager.GUN_SKIN_CATALOG:
		var skey: String = str(sdef["key"])
		var sname: String = ProfileManager.get_gun_skin_name(wid, skey)
		var price: int = ProfileManager.get_gun_skin_price(wid, skey)
		var tint: Color = ProfileManager.get_gun_skin_tint(wid, skey)
		var badge: Color = ProfileManager.get_gun_skin_badge(wid, skey)
		var owned: bool = ProfileManager.owns_gun_skin(wid, skey)
		var equipped: bool = (eq_key == skey)
		var is_previewed: bool = (prev_key == skey)

		var scard := PanelContainer.new()
		scard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scard.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.10, 0.22, 0.16, 0.98) if equipped else (Color(0.18, 0.24, 0.36, 0.98) if is_previewed else Color(0.11, 0.16, 0.25, 0.96))
		csb.border_color = Color(0.32, 0.96, 0.52) if equipped else (Color(1.0, 0.90, 0.36) if is_previewed else badge)
		csb.set_border_width_all(3 if is_previewed else 2)
		csb.set_corner_radius_all(10)
		csb.set_content_margin_all(10)
		scard.add_theme_stylebox_override("panel", csb)
		scard.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_shop_preview_skin_key = skey
				_refresh_shop_skins()
		)
		_shop_skin_grid.add_child(scard)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		scard.add_child(row)

		var icon_tr := TextureRect.new()
		icon_tr.custom_minimum_size = Vector2(78, 40)
		icon_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_tr.mouse_filter = Control.MOUSE_FILTER_PASS
		icon_tr.texture = WeaponData.get_weapon_atlas_texture(wid, int(sdef.get("sheet_row", 0)))
		icon_tr.modulate = tint
		row.add_child(icon_tr)

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.alignment = BoxContainer.ALIGNMENT_CENTER
		info_v.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(info_v)

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 6)
		name_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		name_row.mouse_filter = Control.MOUSE_FILTER_PASS
		info_v.add_child(name_row)

		var nl := Label.new()
		nl.text = sname
		nl.add_theme_font_size_override("font_size", 14)
		nl.modulate = badge.lightened(0.25)
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		name_row.add_child(nl)

		if skey != "default":
			var tk: String = ProfileManager.get_gun_skin_tier(wid, skey)
			var tc: Color = ProfileManager.get_skin_tier_color(tk)
			var tpill := PanelContainer.new()
			tpill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tpill.mouse_filter = Control.MOUSE_FILTER_PASS
			var tsb := StyleBoxFlat.new()
			tsb.bg_color = tc.darkened(0.74)
			tsb.border_color = tc
			tsb.set_border_width_all(1)
			tsb.set_corner_radius_all(5)
			tsb.content_margin_left = 6.0
			tsb.content_margin_right = 6.0
			tsb.content_margin_top = 1.0
			tsb.content_margin_bottom = 1.0
			tpill.add_theme_stylebox_override("panel", tsb)
			var tlbl := Label.new()
			tlbl.text = ProfileManager.get_skin_tier_label(tk)
			tlbl.add_theme_font_size_override("font_size", 9)
			tlbl.modulate = tc.lightened(0.18)
			tlbl.mouse_filter = Control.MOUSE_FILTER_PASS
			tpill.add_child(tlbl)
			name_row.add_child(tpill)

		if ProfileManager.is_gun_skin_new(wid, skey):
			name_row.add_child(UIStyle.make_inline_new_badge("NEW", 10))

		var is_ach_excl: bool = AchievementManager.is_skin_achievement_exclusive(wid, skey)
		if equipped:
			var pl := Label.new()
			pl.text = "EQUIPPED"
			pl.modulate = Color(0.35, 0.96, 0.55)
			pl.add_theme_font_size_override("font_size", 12)
			pl.mouse_filter = Control.MOUSE_FILTER_PASS
			info_v.add_child(pl)
		elif owned:
			var pl := Label.new()
			pl.text = "OWNED"
			pl.modulate = Color(0.75, 0.85, 0.96)
			pl.add_theme_font_size_override("font_size", 12)
			pl.mouse_filter = Control.MOUSE_FILTER_PASS
			info_v.add_child(pl)
		elif is_ach_excl:
			var pl := Label.new()
			pl.text = "ACHIEVEMENT ONLY"
			pl.modulate = Color(1.0, 0.62, 0.98)
			pl.add_theme_font_size_override("font_size", 12)
			pl.mouse_filter = Control.MOUSE_FILTER_PASS
			info_v.add_child(pl)
		else:
			_add_coin_icon_label(info_v, ProfileManager.format_coins(price), 15, 12, Color(1.0, 0.84, 0.28), false)

		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(92, 36)
		act_btn.focus_mode = Control.FOCUS_NONE
		if equipped:
			act_btn.text = "ACTIVE"
			act_btn.disabled = true
		elif owned:
			act_btn.text = "EQUIP"
			act_btn.pressed.connect(func():
				_shop_preview_skin_key = skey
				ProfileManager.equip_gun_skin(wid, skey)
				_shop_status_lbl.text = "Equipped %s on %s!" % [sname, wd.display_name]
				_shop_status_lbl.modulate = Color(0.45, 1.0, 0.65)
				_refresh_shop_skins()
			)
		elif is_ach_excl:
			act_btn.text = "LOCKED"
			act_btn.disabled = true
			act_btn.modulate = Color(0.86, 0.56, 1.0)
			act_btn.tooltip_text = "Unlock via Achievement: %s" % AchievementManager.get_exclusive_skin_achievement_title(wid, skey)
		else:
			act_btn.text = "BUY"
			act_btn.disabled = ProfileManager.coins < price
			act_btn.modulate = Color(1.0, 0.86, 0.28) if ProfileManager.coins >= price else Color(0.55, 0.58, 0.65)
			act_btn.pressed.connect(func():
				if ProfileManager.buy_gun_skin(wid, skey):
					_shop_preview_skin_key = skey
					_shop_status_lbl.text = "Purchased & equipped %s for %s NC!" % [sname, ProfileManager.format_coins(price)]
					_shop_status_lbl.modulate = Color(0.45, 1.0, 0.65)
					SettingsManager.play_ui_purchase()
					_refresh_shop_skins()
				else:
					_shop_status_lbl.text = "Not enough NC! Need %s NC." % ProfileManager.format_coins(price)
					_shop_status_lbl.modulate = Color(1.0, 0.42, 0.35)
			)
		row.add_child(act_btn)


# ==============================================================================
# DAILY BONUS (+100 COINS) & CRATE OPENING OVERLAY
# ==============================================================================

func _update_crate_badge() -> void:
	if not is_instance_valid(_crate_top_btn):
		return
	var has_free: bool = ProfileManager.can_claim_daily_bonus() or ProfileManager.can_open_free_daily_crate()
	_crate_top_btn.text = "CRATES & DAILY (!)" if has_free else "CRATES & DAILY"
	_crate_top_btn.modulate = Color(1.0, 0.96, 0.68) if has_free else Color.WHITE


func _update_new_item_badges() -> void:
	UIStyle.set_new_badge_visible(_agent_mode_btn, ProfileManager.has_any_new_agent(), "NewBadge", -10.0, 10.0, 12)
	UIStyle.set_new_badge_visible(_top_shop_btn, ProfileManager.has_any_new_gun_skin(), "NewBadge", -5.0, 3.0, 10)
	UIStyle.set_new_badge_visible(_customize_btn, ProfileManager.has_any_new_customization(), "NewBadge", -6.0, 4.0, 10)


func _build_crate_overlay() -> void:
	_crate_overlay = ColorRect.new()
	_crate_overlay.z_index = 62
	_crate_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_overlay.color = Color(0.02, 0.03, 0.06, 0.92)
	_crate_overlay.visible = false
	add_child(_crate_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(960, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	sb.border_color = Color(1.0, 0.84, 0.24, 0.98)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", sb)
	cc.add_child(card)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	card.add_child(root_v)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	root_v.add_child(hdr)

	var title := Label.new()
	title.text = "CRATES & DAILY BONUS"
	title.add_theme_font_size_override("font_size", 20)
	title.modulate = Color(1.0, 0.88, 0.30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	_crate_coin_lbl = _add_coin_icon_label(hdr, ProfileManager.format_coins(ProfileManager.coins), 22, 19, Color(1.0, 0.90, 0.30), false)

	var crate_get_coins := _make_arcade_button("+ NC", Color(0.36, 0.98, 0.56), 34.0, 14, Color(0.09, 0.30, 0.16, 0.96))
	crate_get_coins.custom_minimum_size = Vector2(104, 34)
	crate_get_coins.pressed.connect(func(): _open_coin_shop(_crate_overlay))
	hdr.add_child(crate_get_coins)

	var close_btn := _make_arcade_button("CLOSE", Color(0.92, 0.34, 0.34), 38.0, 15, Color(0.26, 0.08, 0.10, 0.96))
	close_btn.custom_minimum_size = Vector2(105, 38)
	close_btn.pressed.connect(func():
		if _crate_spinning:
			return
		_crate_overlay.visible = false
		_hub_container.visible = true
		_update_crate_badge()
	)
	hdr.add_child(close_btn)

	# Daily Bonus Bar (+100 coins daily)
	var daily_panel := PanelContainer.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color(0.08, 0.18, 0.13, 0.96)
	dsb.border_color = Color(0.34, 0.96, 0.56, 0.92)
	dsb.set_border_width_all(2)
	dsb.set_corner_radius_all(12)
	dsb.set_content_margin_all(9)
	daily_panel.add_theme_stylebox_override("panel", dsb)
	root_v.add_child(daily_panel)

	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 12)
	daily_panel.add_child(dh)

	var dl := Label.new()
	dl.text = "DAILY LOGIN BONUS  •  Collect +100 FREE NC every day!"
	dl.add_theme_font_size_override("font_size", 16)
	dl.modulate = Color(0.76, 1.0, 0.82)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dh.add_child(dl)

	_daily_claim_btn = _make_arcade_button("COLLECT +100", Color(0.35, 0.98, 0.54), 38.0, 15, Color(0.10, 0.34, 0.18, 0.98))
	_daily_claim_btn.icon = _get_coin_icon()
	_daily_claim_btn.expand_icon = true
	_daily_claim_btn.add_theme_constant_override("icon_max_width", 22)
	_daily_claim_btn.custom_minimum_size = Vector2(226, 38)
	_daily_claim_btn.pressed.connect(func():
		if ProfileManager.claim_daily_bonus():
			SettingsManager.play_ui_purchase()
			var act_ui: Dictionary = _crate_premium_ui if _crate_active_is_premium else _crate_supply_ui
			var sl: Label = act_ui.get("status_lbl") as Label
			if is_instance_valid(sl):
				sl.text = "Collected +100 Daily Bonus NC!"
				sl.modulate = Color(0.45, 1.0, 0.62)
			_refresh_crate_ui()
	)
	dh.add_child(_daily_claim_btn)

	# Separate Crate Screen Switcher Bar (SUPPLY CRATE | PREMIUM CRATE)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 12)
	root_v.add_child(tab_row)

	_crate_tab_supply_btn = _make_arcade_button("SUPPLY CRATE", Color(0.36, 0.82, 1.0), 46.0, 17, Color(0.08, 0.18, 0.30, 0.98))
	_crate_tab_supply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crate_tab_supply_btn.pressed.connect(func():
		if not _crate_spinning:
			_select_crate_screen(false)
	)
	tab_row.add_child(_crate_tab_supply_btn)

	_crate_tab_premium_btn = _make_arcade_button("PREMIUM CRATE", Color(1.0, 0.82, 0.24), 46.0, 17, Color(0.24, 0.12, 0.32, 0.98))
	_crate_tab_premium_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crate_tab_premium_btn.pressed.connect(func():
		if not _crate_spinning:
			_select_crate_screen(true)
	)
	tab_row.add_child(_crate_tab_premium_btn)

	# Two Separate Crate Screens
	var pages_host := Control.new()
	pages_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(pages_host)

	_crate_supply_ui = _build_crate_screen_page(false, pages_host)
	_crate_supply_page = _crate_supply_ui["page"] as Control
	_crate_premium_ui = _build_crate_screen_page(true, pages_host)
	_crate_premium_page = _crate_premium_ui["page"] as Control

	_build_crate_reveal_overlay()
	_build_crate_bigwin_overlay()
	_select_crate_screen(false)


func _build_crate_screen_page(is_premium: bool, host: Control) -> Dictionary:
	var page := PanelContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var accent_c: Color = Color(1.0, 0.80, 0.22) if is_premium else Color(0.34, 0.84, 1.0)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.11, 0.06, 0.18, 0.98) if is_premium else Color(0.06, 0.10, 0.18, 0.98)
	psb.border_color = Color(accent_c.r, accent_c.g, accent_c.b, 0.92)
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(14)
	psb.set_content_margin_all(14)
	page.add_theme_stylebox_override("panel", psb)
	host.add_child(page)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	page.add_child(pv)

	var banner_row := HBoxContainer.new()
	banner_row.add_theme_constant_override("separation", 10)
	pv.add_child(banner_row)

	var title_lbl := Label.new()
	title_lbl.text = "PREMIUM VAULT CRATE" if is_premium else "TACTICAL SUPPLY CRATE"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.modulate = accent_c
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	banner_row.add_child(title_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = "SKINS  •  AGENTS  •  JACKPOT NC" if is_premium else "GUN SKINS  •  NC  •  MYSTERY DROPS"
	tag_lbl.add_theme_font_size_override("font_size", 13)
	tag_lbl.modulate = Color(0.95, 0.86, 0.62) if is_premium else Color(0.72, 0.90, 1.0)
	banner_row.add_child(tag_lbl)

	# Sealed Mystery Strip Viewport (values hidden until opened; arrows above & below center)
	var spin_panel := PanelContainer.new()
	spin_panel.custom_minimum_size = Vector2(0, 184)
	spin_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.03, 0.04, 0.09, 0.98)
	ssb.border_color = Color(accent_c.r, accent_c.g, accent_c.b, 0.85)
	ssb.set_border_width_all(2)
	ssb.set_corner_radius_all(12)
	ssb.set_content_margin_all(6)
	spin_panel.add_theme_stylebox_override("panel", ssb)
	pv.add_child(spin_panel)

	var clip := Control.new()
	clip.clip_contents = true
	clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spin_panel.add_child(clip)

	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 10)
	strip.position = Vector2(12.0, 22.0)
	clip.add_child(strip)

	# Top & bottom pointer arrows (replaces crossing yellow line border)
	var arrow_ctrl := Control.new()
	arrow_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	arrow_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_ctrl.draw.connect(func():
		var cx: float = arrow_ctrl.size.x * 0.5
		var h: float = arrow_ctrl.size.y
		var top_tri := PackedVector2Array([
			Vector2(cx - 14.0, 1.0),
			Vector2(cx + 14.0, 1.0),
			Vector2(cx, 18.0)
		])
		var bot_tri := PackedVector2Array([
			Vector2(cx - 14.0, h - 1.0),
			Vector2(cx + 14.0, h - 1.0),
			Vector2(cx, h - 18.0)
		])
		arrow_ctrl.draw_colored_polygon(top_tri, accent_c)
		arrow_ctrl.draw_polyline(PackedVector2Array([top_tri[0], top_tri[1], top_tri[2], top_tri[0]]), Color(0.04, 0.05, 0.08), 2.0)
		arrow_ctrl.draw_colored_polygon(bot_tri, accent_c)
		arrow_ctrl.draw_polyline(PackedVector2Array([bot_tri[0], bot_tri[1], bot_tri[2], bot_tri[0]]), Color(0.04, 0.05, 0.08), 2.0)
	)
	clip.add_child(arrow_ctrl)

	var status_lbl := Label.new()
	status_lbl.text = "Tap below to open a sealed %s and discover your reward!" % ("Premium Crate" if is_premium else "Supply Crate")
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 15)
	status_lbl.modulate = Color(0.84, 0.92, 1.0)
	pv.add_child(status_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	pv.add_child(btn_row)

	var free_btn: Button = null
	if not is_premium:
		free_btn = _make_arcade_button("OPEN FREE (1/DAY)", Color(0.35, 0.98, 0.56), 50.0, 15, Color(0.09, 0.30, 0.16, 0.98))
		free_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		free_btn.pressed.connect(func(): _start_single_crate_open(false, true))
		btn_row.add_child(free_btn)

	var open1_text: String = "OPEN 1x  %s" % ("2,000" if is_premium else "1,000")
	var open1_btn := _make_arcade_button(open1_text, accent_c, 50.0, 16, Color(0.28, 0.18, 0.06, 0.98) if is_premium else Color(0.10, 0.22, 0.36, 0.98))
	open1_btn.icon = _get_coin_icon()
	open1_btn.expand_icon = true
	open1_btn.add_theme_constant_override("icon_max_width", 24)
	open1_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open1_btn.pressed.connect(func(): _start_single_crate_open(is_premium, false))
	btn_row.add_child(open1_btn)

	var open10_text: String = "OPEN 10x  %s" % ("20,000" if is_premium else "10,000")
	var open10_btn := _make_arcade_button(open10_text, Color(0.88, 0.46, 1.0) if is_premium else Color(1.0, 0.72, 0.24), 50.0, 16, Color(0.24, 0.10, 0.34, 0.98) if is_premium else Color(0.28, 0.16, 0.05, 0.98))
	open10_btn.icon = _get_coin_icon()
	open10_btn.expand_icon = true
	open10_btn.add_theme_constant_override("icon_max_width", 24)
	open10_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open10_btn.pressed.connect(func(): _start_batch_crate_open(is_premium, 10))
	btn_row.add_child(open10_btn)

	return {
		"page": page,
		"clip": clip,
		"strip": strip,
		"status_lbl": status_lbl,
		"free_btn": free_btn,
		"open1_btn": open1_btn,
		"open10_btn": open10_btn
	}


func _select_crate_screen(is_premium: bool) -> void:
	_crate_active_is_premium = is_premium
	if is_instance_valid(_crate_supply_page):
		_crate_supply_page.visible = not is_premium
	if is_instance_valid(_crate_premium_page):
		_crate_premium_page.visible = is_premium
	if is_instance_valid(_crate_tab_supply_btn):
		_crate_tab_supply_btn.modulate = Color(1.0, 1.0, 1.0) if not is_premium else Color(0.62, 0.68, 0.78)
		_crate_tab_supply_btn.scale = Vector2(1.02, 1.02) if not is_premium else Vector2.ONE
	if is_instance_valid(_crate_tab_premium_btn):
		_crate_tab_premium_btn.modulate = Color(1.0, 1.0, 1.0) if is_premium else Color(0.68, 0.66, 0.78)
		_crate_tab_premium_btn.scale = Vector2(1.02, 1.02) if is_premium else Vector2.ONE
	_refresh_crate_ui()


func _open_crate_overlay() -> void:
	_hub_container.visible = false
	_crate_overlay.visible = true
	_populate_idle_crate_strip(_crate_supply_ui, false)
	_populate_idle_crate_strip(_crate_premium_ui, true)
	_select_crate_screen(_crate_active_is_premium)
	_refresh_crate_ui()


func _refresh_crate_ui() -> void:
	var c_str: String = ProfileManager.format_coins(ProfileManager.coins)
	if is_instance_valid(_crate_coin_lbl) and not _crate_spinning:
		_crate_coin_lbl.text = c_str
	if is_instance_valid(_coin_pill_lbl):
		_coin_pill_lbl.text = c_str
	if is_instance_valid(_daily_claim_btn):
		var can_d: bool = ProfileManager.can_claim_daily_bonus()
		_daily_claim_btn.disabled = not can_d
		_daily_claim_btn.text = "COLLECT +100" if can_d else "CLAIMED TODAY ✓"
		_daily_claim_btn.icon = _get_coin_icon() if can_d else null

	if is_instance_valid(_crate_tab_supply_btn):
		_crate_tab_supply_btn.disabled = _crate_spinning
	if is_instance_valid(_crate_tab_premium_btn):
		_crate_tab_premium_btn.disabled = _crate_spinning

	if not _crate_supply_ui.is_empty():
		var fb: Button = _crate_supply_ui.get("free_btn") as Button
		if is_instance_valid(fb):
			var can_f: bool = ProfileManager.can_open_free_daily_crate() and not _crate_spinning
			fb.disabled = not can_f
			fb.text = "OPEN FREE (1/DAY)" if ProfileManager.can_open_free_daily_crate() else "FREE USED TODAY"
		var b1: Button = _crate_supply_ui.get("open1_btn") as Button
		if is_instance_valid(b1):
			b1.disabled = _crate_spinning or ProfileManager.coins < ProfileManager.STANDARD_CRATE_PRICE
		var b10: Button = _crate_supply_ui.get("open10_btn") as Button
		if is_instance_valid(b10):
			b10.disabled = _crate_spinning or ProfileManager.coins < (ProfileManager.STANDARD_CRATE_PRICE * 10)

	if not _crate_premium_ui.is_empty():
		var p1: Button = _crate_premium_ui.get("open1_btn") as Button
		if is_instance_valid(p1):
			p1.disabled = _crate_spinning or ProfileManager.coins < ProfileManager.PREMIUM_CRATE_PRICE
		var p10: Button = _crate_premium_ui.get("open10_btn") as Button
		if is_instance_valid(p10):
			p10.disabled = _crate_spinning or ProfileManager.coins < (ProfileManager.PREMIUM_CRATE_PRICE * 10)

	_update_crate_badge()


func _draw_sealed_crate_graphic(ctrl: Control, is_premium: bool) -> void:
	var w: float = ctrl.size.x
	var h: float = ctrl.size.y
	var pad_x: float = w * 0.14
	var pad_y: float = h * 0.12
	var bw: float = w - pad_x * 2.0
	var bh: float = h - pad_y * 2.0
	var box_rect := Rect2(pad_x, pad_y, bw, bh)
	var body_col: Color = Color(0.24, 0.14, 0.36) if is_premium else Color(0.11, 0.22, 0.34)
	var lid_col: Color = Color(0.32, 0.19, 0.48) if is_premium else Color(0.16, 0.30, 0.45)
	var trim_col: Color = Color(1.0, 0.80, 0.22) if is_premium else Color(0.38, 0.86, 1.0)
	ctrl.draw_rect(box_rect, body_col, true)
	ctrl.draw_rect(Rect2(pad_x, pad_y, bw, bh * 0.34), lid_col, true)
	ctrl.draw_line(Vector2(pad_x, pad_y + bh * 0.34), Vector2(pad_x + bw, pad_y + bh * 0.34), trim_col, 2.5)
	ctrl.draw_rect(box_rect, trim_col, false, 2.5)
	# Center golden latch
	var clasp := Rect2(w * 0.5 - 10.0, pad_y + bh * 0.24, 20.0, 14.0)
	ctrl.draw_rect(clasp, trim_col, true)
	ctrl.draw_rect(clasp, Color(0.06, 0.08, 0.14), false, 1.5)


func _make_mystery_crate_card(is_premium: bool, card_size: Vector2 = Vector2(138, 128), label_txt: String = "MYSTERY CRATE") -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = card_size
	card.pivot_offset = card_size * 0.5
	var accent_c: Color = Color(1.0, 0.80, 0.22) if is_premium else Color(0.36, 0.84, 1.0)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.12, 0.08, 0.20, 0.98) if is_premium else Color(0.07, 0.12, 0.20, 0.98)
	csb.border_color = accent_c
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(12)
	csb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", csb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var box_gfx := Control.new()
	box_gfx.custom_minimum_size = Vector2(card_size.x - 24.0, card_size.y * 0.56)
	box_gfx.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box_gfx.draw.connect(func(): _draw_sealed_crate_graphic(box_gfx, is_premium))
	vb.add_child(box_gfx)

	var q_lbl := Label.new()
	q_lbl.text = "?"
	q_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q_lbl.offset_top = 12.0
	q_lbl.add_theme_font_size_override("font_size", int(clampf(card_size.y * 0.22, 20.0, 38.0)))
	q_lbl.modulate = accent_c
	box_gfx.add_child(q_lbl)

	if not label_txt.is_empty():
		var lbl := Label.new()
		lbl.text = label_txt
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.modulate = Color(0.86, 0.92, 1.0)
		vb.add_child(lbl)

	return card


func _get_coin_icon() -> Texture2D:
	if _coin_icon_cache != null:
		return _coin_icon_cache
	var path: String = "res://assets/ui/icons/icon_coin.png"
	if ResourceLoader.exists(path):
		_coin_icon_cache = load(path) as Texture2D
	if _coin_icon_cache == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			_coin_icon_cache = ImageTexture.create_from_image(img)
	return _coin_icon_cache


func _add_coin_icon_label(parent: Control, initial_text: String, icon_sz: int = 22, font_sz: int = 18, txt_col: Color = Color(1.0, 0.90, 0.30), center_align: bool = false, box_align: int = BoxContainer.ALIGNMENT_BEGIN) -> Label:
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_theme_constant_override("separation", 5)
	if center_align:
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	elif box_align == BoxContainer.ALIGNMENT_END:
		hb.alignment = BoxContainer.ALIGNMENT_END
		hb.size_flags_horizontal = Control.SIZE_SHRINK_END
	parent.add_child(hb)

	var tr := TextureRect.new()
	tr.texture = _get_coin_icon()
	tr.custom_minimum_size = Vector2(int(round(float(icon_sz) * 0.78)), int(round(float(icon_sz) * 1.24)))
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hb.add_child(tr)

	var lbl := Label.new()
	lbl.text = initial_text
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.modulate = txt_col
	hb.add_child(lbl)
	return lbl


func _make_cosmetic_icon(slot: String, part_id: int) -> Texture2D:
	var path: String = ""
	if slot == "face_acc_id":
		path = ModularCharacter.get_face_acc_texture_path(part_id)
	else:
		var pkind: String = slot.trim_suffix("_id")
		path = ModularCharacter.get_part_texture_path(pkind, part_id)
	if path.is_empty():
		return _get_coin_icon()
	var src_img: Image = null
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			src_img = tex.get_image()
	if src_img == null:
		src_img = Image.load_from_file(ProjectSettings.globalize_path(path))
	if src_img == null or src_img.is_empty():
		return _get_coin_icon()
	var fh: int = mini(src_img.get_height(), src_img.get_width())
	if fh <= 0:
		return _get_coin_icon()
	var frame_img: Image = src_img.get_region(Rect2i(0, 0, fh, fh))
	frame_img.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = frame_img.get_used_rect()
	if not used.has_area():
		used = Rect2i(0, 0, fh, fh)
	var side: int = maxi(used.size.x, used.size.y)
	var pad: int = maxi(6, int(float(side) * 0.22))
	var sq: int = maxi(24, side + pad * 2)
	var icon_img := Image.create_empty(sq, sq, false, Image.FORMAT_RGBA8)
	var dst_x: int = int((sq - used.size.x) / 2)
	var dst_y: int = int((sq - used.size.y) / 2)
	icon_img.blit_rect(frame_img, used, Vector2i(dst_x, dst_y))
	icon_img.resize(76, 76, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(icon_img)


func _populate_revealed_card_contents(card: PanelContainer, item: Dictionary, large: bool = false) -> void:
	for c in card.get_children():
		c.queue_free()

	var kind: String = str(item.get("kind", "coins"))
	var is_dup: bool = bool(item.get("is_duplicate", false))
	var border_c: Color = Color(0.92, 0.78, 0.32)
	var bg_c: Color = Color(0.10, 0.13, 0.20, 0.98)
	var bw: int = 2
	var tag_txt: String = "NC"

	if kind == "premium_skin":
		border_c = Color(1.0, 0.80, 0.16)
		bg_c = Color(0.24, 0.12, 0.05, 0.98)
		bw = 4
		tag_txt = "★ PREMIUM SKIN ★"
	elif kind == "rare_skin":
		border_c = Color(0.76, 0.48, 1.0)
		bg_c = Color(0.16, 0.08, 0.26, 0.98)
		bw = 3
		tag_txt = "◆ RARE SKIN ◆"
	elif kind == "agent_unlock":
		border_c = Color(0.86, 0.46, 1.0)
		bg_c = Color(0.18, 0.08, 0.28, 0.98)
		bw = 4
		tag_txt = "★ AGENT BONUS ★" if is_dup else "★ AGENT UNLOCK ★"
	elif kind == "double_coins":
		border_c = Color(0.28, 1.0, 0.56)
		bg_c = Color(0.06, 0.22, 0.14, 0.98)
		bw = 4
		tag_txt = "★ 2x NC! ★"
	elif kind == "dummy_gear":
		border_c = Color(0.98, 0.56, 0.92)
		bg_c = Color(0.20, 0.08, 0.24, 0.98)
		bw = 3
		tag_txt = "★ CHARACTER GEAR ★"
	elif kind == "basic_skin":
		border_c = Color(0.45, 0.86, 1.0)
		bg_c = Color(0.06, 0.16, 0.26, 0.98)
		bw = 3
		tag_txt = "● COMMON SKIN ●"

	var csb := StyleBoxFlat.new()
	csb.bg_color = bg_c
	csb.border_color = border_c
	csb.set_border_width_all(bw)
	csb.set_corner_radius_all(12)
	csb.set_content_margin_all(10 if large else 6)
	card.add_theme_stylebox_override("panel", csb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6 if large else 3)
	card.add_child(vb)

	var tag := Label.new()
	tag.text = tag_txt
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 13 if large else 10)
	tag.modulate = border_c
	vb.add_child(tag)

	if kind == "double_coins":
		var big_2x := Label.new()
		big_2x.text = "2x"
		big_2x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big_2x.add_theme_font_size_override("font_size", 46 if large else 30)
		big_2x.modulate = Color(0.34, 1.0, 0.62)
		vb.add_child(big_2x)
		_add_coin_icon_label(vb, "+%s" % ProfileManager.format_coins(int(item.get("coins_won", 0))), 20 if large else 14, 16 if large else 12, Color(0.95, 1.0, 0.85), true)
	elif kind == "agent_unlock":
		var ag_id: int = int(item.get("agent_id", -1))
		if ag_id >= 0:
			var tr_ag := TextureRect.new()
			tr_ag.texture = _make_agent_icon(ag_id)
			tr_ag.custom_minimum_size = Vector2(96, 96) if large else Vector2(60, 60)
			tr_ag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tr_ag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_ag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			vb.add_child(tr_ag)
		else:
			_add_coin_icon_label(vb, "+%s" % ProfileManager.format_coins(int(item.get("coins_won", 2500))), 24 if large else 16, 26 if large else 18, Color(0.90, 0.65, 1.0), true)
		var ag_lbl := Label.new()
		ag_lbl.text = str(item.get("short_label", item.get("label", "Agent")))
		ag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ag_lbl.clip_text = true
		ag_lbl.add_theme_font_size_override("font_size", 15 if large else 12)
		ag_lbl.modulate = Color(0.96, 0.92, 1.0)
		vb.add_child(ag_lbl)
	elif kind == "dummy_gear":
		var cslot: String = str(item.get("cosmetic_slot", "face_acc_id"))
		var cpid: int = int(item.get("cosmetic_part_id", 0))
		var tr_cg := TextureRect.new()
		tr_cg.texture = _make_cosmetic_icon(cslot, cpid)
		tr_cg.custom_minimum_size = Vector2(92, 92) if large else Vector2(58, 58)
		tr_cg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_cg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vb.add_child(tr_cg)

		var cg_name := Label.new()
		cg_name.text = str(item.get("label", "Character Gear")) if large else str(item.get("short_label", "Character Gear"))
		cg_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cg_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if large else TextServer.AUTOWRAP_OFF
		cg_name.clip_text = true
		cg_name.add_theme_font_size_override("font_size", 14 if large else 11)
		cg_name.modulate = Color(0.98, 0.90, 1.0)
		vb.add_child(cg_name)

		if is_dup:
			_add_coin_icon_label(vb, "DUPLICATE +%s" % ProfileManager.format_coins(int(item.get("coins_won", 200))), 14 if large else 11, 12 if large else 10, Color(1.0, 0.86, 0.36), true)
	elif kind == "premium_skin" or kind == "rare_skin" or kind == "basic_skin":
		var wid: int = int(item.get("weapon_id", 0))
		var skey: String = str(item.get("skin_key", "default"))
		var sdef: Dictionary = ProfileManager.get_gun_skin_def(skey)
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(180, 78) if large else Vector2(120, 52)
		tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = WeaponData.get_weapon_atlas_texture(wid, int(sdef.get("sheet_row", 0)))
		tr.modulate = ProfileManager.get_gun_skin_tint(wid, skey)
		vb.add_child(tr)

		var name_lbl := Label.new()
		name_lbl.text = str(item.get("label", "Gun Skin")) if large else ("%s\n%s" % [str(item.get("weapon_name", "")), str(item.get("skin_name", ""))])
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if large else TextServer.AUTOWRAP_OFF
		name_lbl.clip_text = true
		name_lbl.add_theme_font_size_override("font_size", 14 if large else 11)
		name_lbl.modulate = Color(0.95, 0.97, 1.0)
		vb.add_child(name_lbl)

		if is_dup:
			_add_coin_icon_label(vb, "DUPLICATE +%s" % ProfileManager.format_coins(int(item.get("coins_won", 500))), 14 if large else 11, 12 if large else 10, Color(1.0, 0.86, 0.36), true)
	else:
		var cw: int = int(item.get("coins_won", 200))
		_add_coin_icon_label(vb, "+%s" % ProfileManager.format_coins(cw), 30 if large else 20, 32 if large else 22, Color(1.0, 0.88, 0.30), true)
		var lbl := Label.new()
		lbl.text = "NC"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13 if large else 10)
		lbl.modulate = Color(0.92, 0.95, 1.0)
		vb.add_child(lbl)


func _populate_converted_coins_card(card: PanelContainer, item: Dictionary, large: bool = true) -> void:
	for c in card.get_children():
		c.queue_free()

	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.22, 0.16, 0.04, 0.98)
	csb.border_color = Color(1.0, 0.86, 0.24)
	csb.set_border_width_all(4)
	csb.set_corner_radius_all(12)
	csb.set_content_margin_all(10 if large else 6)
	card.add_theme_stylebox_override("panel", csb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6 if large else 4)
	card.add_child(vb)

	var tag := Label.new()
	tag.text = "DUPLICATE CONVERTED"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 13 if large else 10)
	tag.modulate = Color(1.0, 0.88, 0.32)
	vb.add_child(tag)

	var refund_c: int = int(item.get("coins_won", 0))
	_add_coin_icon_label(vb, "+%s" % ProfileManager.format_coins(refund_c), 40 if large else 28, 32 if large else 22, Color(1.0, 0.92, 0.36), true)

	var sub_lbl := Label.new()
	sub_lbl.text = "CONVERTED TO NC (50%)"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 12 if large else 10)
	sub_lbl.modulate = Color(0.45, 1.0, 0.65)
	vb.add_child(sub_lbl)

	var src_lbl := Label.new()
	src_lbl.text = str(item.get("short_label", item.get("label", "")))
	src_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	src_lbl.clip_text = true
	src_lbl.add_theme_font_size_override("font_size", 11 if large else 9)
	src_lbl.modulate = Color(0.76, 0.82, 0.92)
	vb.add_child(src_lbl)


func _populate_idle_crate_strip(ui_dict: Dictionary, is_premium: bool) -> void:
	if ui_dict.is_empty():
		return
	var strip: HBoxContainer = ui_dict.get("strip") as HBoxContainer
	if not is_instance_valid(strip):
		return
	for c in strip.get_children():
		c.queue_free()
	for _i in range(12):
		strip.add_child(_make_mystery_crate_card(is_premium, Vector2(138, 128), "MYSTERY CRATE"))
	strip.position = Vector2(12.0, 22.0)


func _play_ui_pickup_sfx(pitch: float = 1.0, vol_db: float = 0.0) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = load("res://assets/audio/pickup.wav") as AudioStream
	sfx.bus = &"SFX"
	sfx.pitch_scale = pitch
	sfx.volume_db = vol_db
	sfx.finished.connect(sfx.queue_free)
	add_child(sfx)
	sfx.play()


func _play_crate_chime_sfx() -> void:
	_play_ui_pickup_sfx(1.05, 0.0)
	_play_ui_pickup_sfx(1.42, -3.0)
	var pop := AudioStreamPlayer.new()
	pop.stream = load("res://assets/audio/explosion.wav") as AudioStream
	pop.bus = &"SFX"
	pop.pitch_scale = 1.25
	pop.volume_db = -14.0
	pop.finished.connect(pop.queue_free)
	add_child(pop)
	pop.play()


func _start_single_crate_open(is_premium_crate: bool, use_free_daily: bool) -> void:
	if _crate_spinning:
		return
	_crate_spinning = true
	var res: Dictionary = ProfileManager.open_crate(is_premium_crate, use_free_daily)
	var act_ui: Dictionary = _crate_premium_ui if is_premium_crate else _crate_supply_ui
	var status_lbl: Label = act_ui.get("status_lbl") as Label
	if not bool(res.get("ok", false)):
		_crate_spinning = false
		if is_instance_valid(status_lbl):
			status_lbl.text = str(res.get("error", "Cannot open crate."))
			status_lbl.modulate = Color(1.0, 0.42, 0.36)
		_refresh_crate_ui()
		return

	_crate_last_win = res
	SettingsManager.play_ui_purchase()
	if is_instance_valid(_crate_coin_lbl):
		_crate_coin_lbl.text = ProfileManager.format_coins(int(res.get("coins_before_reward", ProfileManager.coins)))
	if is_instance_valid(status_lbl):
		status_lbl.text = "Opening sealed %s..." % ("Premium Crate" if is_premium_crate else "Supply Crate")
		status_lbl.modulate = Color(1.0, 0.88, 0.35)
	_refresh_crate_ui()

	var strip: HBoxContainer = act_ui.get("strip") as HBoxContainer
	var clip: Control = act_ui.get("clip") as Control
	for c in strip.get_children():
		c.queue_free()

	var total_cards: int = 30
	var win_idx: int = 22
	for _i in range(total_cards):
		strip.add_child(_make_mystery_crate_card(is_premium_crate, Vector2(138, 128), "MYSTERY CRATE"))

	var card_stride: float = 148.0 # 138px card + 10px separation
	var clip_w: float = maxf(640.0, clip.size.x)
	var target_x: float = (clip_w * 0.5) - (float(win_idx) * card_stride + 69.0)
	strip.position = Vector2(12.0, 22.0)

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(strip, "position:x", target_x, 1.55)
	tw.tween_callback(func():
		if is_inside_tree():
			_show_single_box_flip_reveal(res, is_premium_crate)
	)


func _build_crate_reveal_overlay() -> void:
	_crate_reveal_overlay = ColorRect.new()
	_crate_reveal_overlay.z_index = 66
	_crate_reveal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_reveal_overlay.color = Color(0.01, 0.02, 0.05, 0.94)
	_crate_reveal_overlay.visible = false
	add_child(_crate_reveal_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_reveal_overlay.add_child(cc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 540)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.99)
	sb.border_color = Color(1.0, 0.84, 0.24, 0.96)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	cc.add_child(panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	panel.add_child(root_v)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	root_v.add_child(hdr)

	_crate_reveal_title = Label.new()
	_crate_reveal_title.text = "OPENING CRATE"
	_crate_reveal_title.add_theme_font_size_override("font_size", 22)
	_crate_reveal_title.modulate = Color(1.0, 0.88, 0.30)
	_crate_reveal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_crate_reveal_title)

	_crate_reveal_coin_lbl = _add_coin_icon_label(hdr, ProfileManager.format_coins(ProfileManager.coins), 22, 18, Color(1.0, 0.90, 0.30), false)

	_crate_reveal_sub = Label.new()
	_crate_reveal_sub.text = ""
	_crate_reveal_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crate_reveal_sub.add_theme_font_size_override("font_size", 15)
	_crate_reveal_sub.modulate = Color(0.80, 0.92, 1.0)
	root_v.add_child(_crate_reveal_sub)

	_crate_reveal_body = Control.new()
	_crate_reveal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crate_reveal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(_crate_reveal_body)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root_v.add_child(btn_row)

	_crate_reveal_skip_btn = _make_arcade_button("SKIP ANIMATION", Color(0.45, 0.78, 1.0), 44.0, 15, Color(0.10, 0.20, 0.32, 0.98))
	_crate_reveal_skip_btn.custom_minimum_size = Vector2(200, 44)
	_crate_reveal_skip_btn.visible = false
	_crate_reveal_skip_btn.pressed.connect(func(): _crate_reveal_skip_requested = true)
	btn_row.add_child(_crate_reveal_skip_btn)

	_crate_reveal_equip_btn = _make_arcade_button("EQUIP SKIN", Color(0.32, 0.96, 0.55), 44.0, 15, Color(0.09, 0.30, 0.16, 0.98))
	_crate_reveal_equip_btn.custom_minimum_size = Vector2(200, 44)
	_crate_reveal_equip_btn.visible = false
	_crate_reveal_equip_btn.pressed.connect(func():
		_apply_crate_equip_action(_crate_reveal_equip_item, _crate_reveal_equip_btn)
	)
	btn_row.add_child(_crate_reveal_equip_btn)

	_crate_reveal_close_btn = _make_arcade_button("COLLECT", Color(1.0, 0.82, 0.24), 44.0, 16, Color(0.28, 0.18, 0.05, 0.98))
	_crate_reveal_close_btn.custom_minimum_size = Vector2(220, 44)
	_crate_reveal_close_btn.visible = false
	_crate_reveal_close_btn.pressed.connect(func():
		if _crate_reveal_in_progress:
			return
		_crate_reveal_overlay.visible = false
		_crate_spinning = false
		_refresh_crate_ui()
	)
	btn_row.add_child(_crate_reveal_close_btn)


func _build_crate_bigwin_overlay() -> void:
	_crate_bigwin_overlay = ColorRect.new()
	_crate_bigwin_overlay.z_index = 70
	_crate_bigwin_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_bigwin_overlay.color = Color(0.01, 0.02, 0.05, 0.92)
	_crate_bigwin_overlay.visible = false
	add_child(_crate_bigwin_overlay)

	_crate_bigwin_rays = Control.new()
	_crate_bigwin_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_bigwin_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crate_bigwin_rays.draw.connect(func():
		var center: Vector2 = _crate_bigwin_rays.size * 0.5
		var rad: float = maxf(_crate_bigwin_rays.size.x, _crate_bigwin_rays.size.y) * 0.75
		var ac: Color = _crate_bigwin_accent
		for i in range(16):
			var a0: float = _crate_bigwin_angle + float(i) * (TAU / 16.0)
			var a1: float = a0 + (TAU / 32.0) * 0.65
			var pts := PackedVector2Array([
				center,
				center + Vector2(cos(a0), sin(a0)) * rad,
				center + Vector2(cos(a1), sin(a1)) * rad
			])
			_crate_bigwin_rays.draw_colored_polygon(pts, Color(ac.r, ac.g, ac.b, 0.11))
		_crate_bigwin_rays.draw_circle(center, 180.0, Color(ac.r, ac.g, ac.b, 0.12))
	)
	_crate_bigwin_overlay.add_child(_crate_bigwin_rays)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_bigwin_overlay.add_child(cc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 470)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.07, 0.05, 0.14, 0.96)
	bsb.border_color = Color(1.0, 0.84, 0.22, 0.98)
	bsb.set_border_width_all(4)
	bsb.set_corner_radius_all(20)
	bsb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", bsb)
	cc.add_child(panel)

	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 14)
	panel.add_child(bv)

	_crate_bigwin_title = Label.new()
	_crate_bigwin_title.text = "★ BIG DROP! ★"
	_crate_bigwin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crate_bigwin_title.add_theme_font_size_override("font_size", 30)
	_crate_bigwin_title.modulate = Color(1.0, 0.88, 0.28)
	bv.add_child(_crate_bigwin_title)

	_crate_bigwin_sub = Label.new()
	_crate_bigwin_sub.text = ""
	_crate_bigwin_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crate_bigwin_sub.add_theme_font_size_override("font_size", 16)
	_crate_bigwin_sub.modulate = Color(0.86, 0.94, 1.0)
	bv.add_child(_crate_bigwin_sub)

	_crate_bigwin_cards_row = HBoxContainer.new()
	_crate_bigwin_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_crate_bigwin_cards_row.add_theme_constant_override("separation", 14)
	bv.add_child(_crate_bigwin_cards_row)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	bv.add_child(btn_row)

	_crate_bigwin_equip_btn = _make_arcade_button("EQUIP NOW", Color(0.32, 0.96, 0.55), 48.0, 17, Color(0.09, 0.30, 0.16, 0.98))
	_crate_bigwin_equip_btn.custom_minimum_size = Vector2(210, 48)
	_crate_bigwin_equip_btn.visible = false
	_crate_bigwin_equip_btn.pressed.connect(func():
		_apply_crate_equip_action(_crate_bigwin_best_item, _crate_bigwin_equip_btn)
	)
	btn_row.add_child(_crate_bigwin_equip_btn)

	var ok_btn := _make_arcade_button("AWESOME!", Color(1.0, 0.84, 0.24), 48.0, 18, Color(0.30, 0.19, 0.04, 0.98))
	ok_btn.custom_minimum_size = Vector2(220, 48)
	ok_btn.pressed.connect(func():
		_crate_bigwin_overlay.visible = false
	)
	btn_row.add_child(ok_btn)

	_crate_bigwin_flash = ColorRect.new()
	_crate_bigwin_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_bigwin_flash.color = Color(1.0, 0.94, 0.65, 0.0)
	_crate_bigwin_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crate_bigwin_overlay.add_child(_crate_bigwin_flash)


func _is_crate_equipable_item(item: Dictionary) -> bool:
	var k: String = str(item.get("kind", "coins"))
	if (k == "premium_skin" or k == "rare_skin" or k == "basic_skin") and not bool(item.get("is_duplicate", false)) and int(item.get("weapon_id", -1)) >= 0:
		return true
	if k == "agent_unlock" and not bool(item.get("is_duplicate", false)) and int(item.get("agent_id", -1)) >= 0:
		return true
	if k == "dummy_gear" and not bool(item.get("is_duplicate", false)) and not str(item.get("cosmetic_key", "")).is_empty():
		return true
	return false


func _configure_equip_button(btn: Button, item: Dictionary) -> void:
	if not is_instance_valid(btn):
		return
	if not _is_crate_equipable_item(item):
		btn.visible = false
		return
	var k: String = str(item.get("kind", ""))
	if k == "agent_unlock":
		btn.text = "SELECT AGENT"
	elif k == "dummy_gear":
		btn.text = "EQUIP ACCESSORY"
	else:
		btn.text = "EQUIP SKIN"
	btn.disabled = false
	btn.visible = true


func _apply_crate_equip_action(item: Dictionary, btn: Button) -> void:
	var k: String = str(item.get("kind", ""))
	if k == "agent_unlock":
		var ag_id: int = int(item.get("agent_id", -1))
		if ag_id >= 0:
			ProfileManager.apply_archetype_preset(ag_id, true)
			_agent_preview_idx = ag_id
			if is_instance_valid(_preview):
				_preview.refresh_from_profile()
			_update_loadout_label()
			_refresh_agent_select_ui()
			btn.text = "SELECTED ✓"
			btn.disabled = true
	elif k == "dummy_gear" and not str(item.get("cosmetic_key", "")).is_empty():
		if ProfileManager.equip_cosmetic(str(item["cosmetic_key"])):
			if is_instance_valid(_preview):
				_preview.refresh_from_profile()
			_update_loadout_label()
			btn.text = "EQUIPPED ✓"
			btn.disabled = true
	elif int(item.get("weapon_id", -1)) >= 0 and not str(item.get("skin_key", "")).is_empty():
		ProfileManager.equip_gun_skin(int(item["weapon_id"]), str(item["skin_key"]))
		if is_instance_valid(_preview):
			_preview.refresh_from_profile()
		btn.text = "EQUIPPED ✓"
		btn.disabled = true


func _show_single_box_flip_reveal(res: Dictionary, is_premium: bool) -> void:
	_crate_reveal_in_progress = true
	_crate_reveal_skip_requested = false
	_crate_reveal_title.text = "OPENING %s" % ("PREMIUM CRATE" if is_premium else "SUPPLY CRATE")
	_crate_reveal_sub.text = "Unsealing crate..."
	_crate_reveal_coin_lbl.text = ProfileManager.format_coins(int(res.get("coins_before_reward", ProfileManager.coins)))
	_crate_reveal_skip_btn.visible = false
	_crate_reveal_close_btn.visible = false
	_crate_reveal_equip_btn.visible = false
	_crate_reveal_equip_item = res
	for c in _crate_reveal_body.get_children():
		c.queue_free()
	_crate_reveal_overlay.visible = true

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_reveal_body.add_child(cc)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(320, 310)
	cc.add_child(stage)

	var accent_c: Color = Color(1.0, 0.80, 0.22) if is_premium else Color(0.36, 0.84, 1.0)
	var box_base_col: Color = Color(0.24, 0.14, 0.36) if is_premium else Color(0.11, 0.22, 0.34)
	var lid_col: Color = Color(0.34, 0.20, 0.50) if is_premium else Color(0.17, 0.32, 0.48)

	# Hollow Empty Box Container + Separate Animated Lid
	var box_node := Control.new()
	box_node.position = Vector2(50, 90)
	box_node.size = Vector2(220, 165)
	box_node.pivot_offset = Vector2(110, 82)
	stage.add_child(box_node)

	var empty_cavity := Control.new()
	empty_cavity.position = Vector2(0, 44)
	empty_cavity.size = Vector2(220, 121)
	empty_cavity.draw.connect(func():
		# Dark interior rim ("empty box" opening when lid lifts)
		empty_cavity.draw_rect(Rect2(12, -16, 196, 28), Color(0.02, 0.03, 0.06, 0.98), true)
		empty_cavity.draw_rect(Rect2(12, -16, 196, 28), accent_c, false, 2.0)
		# Lower crate front wall
		empty_cavity.draw_rect(Rect2(0, 0, 220, 121), box_base_col, true)
		empty_cavity.draw_rect(Rect2(0, 0, 220, 121), accent_c, false, 3.0)
	)
	box_node.add_child(empty_cavity)

	var box_lid := Control.new()
	box_lid.position = Vector2(-4, 0)
	box_lid.size = Vector2(228, 52)
	box_lid.pivot_offset = Vector2(114, 26)
	box_lid.draw.connect(func():
		box_lid.draw_rect(Rect2(0, 0, 228, 52), lid_col, true)
		box_lid.draw_rect(Rect2(0, 0, 228, 52), accent_c, false, 3.0)
		box_lid.draw_rect(Rect2(96, 32, 36, 18), accent_c, true)
	)
	box_node.add_child(box_lid)

	# Face-down Mystery Card (hidden inside box, pops out & flips)
	var card := _make_mystery_crate_card(is_premium, Vector2(226, 214), "TAP REWARD")
	card.position = Vector2(47, 78)
	card.scale = Vector2.ZERO
	card.visible = false
	stage.add_child(card)

	box_node.scale = Vector2(0.25, 0.25)
	var pop_tw := create_tween()
	pop_tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(box_node, "scale", Vector2.ONE, 0.22)
	await pop_tw.finished
	if not is_inside_tree():
		return

	var shake_tw := create_tween()
	shake_tw.tween_property(box_node, "rotation", -0.07, 0.06)
	shake_tw.tween_property(box_node, "rotation", 0.07, 0.07)
	shake_tw.tween_property(box_node, "rotation", -0.05, 0.06)
	shake_tw.tween_property(box_node, "rotation", 0.0, 0.05)
	await shake_tw.finished
	if not is_inside_tree():
		return

	# Lid lifts off revealing empty box while card pops up!
	card.visible = true
	_crate_reveal_sub.text = "Card emerging..."
	_play_ui_pickup_sfx(0.85, -4.0)
	var open_tw := create_tween().set_parallel(true)
	open_tw.tween_property(box_lid, "position:y", -58.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	open_tw.tween_property(box_lid, "rotation", -0.18, 0.24)
	open_tw.tween_property(box_lid, "modulate:a", 0.0, 0.24)
	open_tw.tween_property(card, "scale", Vector2(1.04, 1.04), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tw.tween_property(card, "position:y", 36.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tw.tween_property(box_node, "position:y", 142.0, 0.28)
	await open_tw.finished
	if not is_inside_tree():
		return

	var fade_box := create_tween()
	fade_box.tween_property(box_node, "modulate:a", 0.0, 0.16)
	await get_tree().create_timer(0.14).timeout
	if not is_inside_tree():
		return

	# Flip the card to reveal reward!
	_crate_reveal_sub.text = "Flipping card..."
	var flip1 := create_tween()
	flip1.tween_property(card, "scale:x", 0.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await flip1.finished
	if not is_inside_tree():
		return

	_populate_revealed_card_contents(card, res, true)
	var k: String = str(res.get("kind", "coins"))
	var is_big: bool = (k == "premium_skin" or k == "rare_skin" or k == "basic_skin" or k == "double_coins" or k == "dummy_gear" or k == "agent_unlock")
	if is_big:
		_play_crate_chime_sfx()
	else:
		_play_ui_pickup_sfx(1.0, 0.0)

	var flip2 := create_tween()
	flip2.tween_property(card, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flip2.tween_property(card, "scale", Vector2.ONE, 0.08)
	await flip2.finished
	if not is_inside_tree():
		return

	_crate_reveal_in_progress = false
	_crate_spinning = false
	_crate_reveal_coin_lbl.text = ProfileManager.format_coins(ProfileManager.coins)
	_crate_coin_lbl.text = _crate_reveal_coin_lbl.text
	_crate_reveal_title.text = "CRATE OPENED!"
	_crate_reveal_sub.text = str(res.get("label", "Reward Unlocked!"))
	_crate_reveal_sub.modulate = res.get("color", Color.WHITE) as Color
	_crate_reveal_close_btn.text = "COLLECT"
	_crate_reveal_close_btn.visible = true
	_configure_equip_button(_crate_reveal_equip_btn, res)

	var act_ui: Dictionary = _crate_premium_ui if is_premium else _crate_supply_ui
	var sl: Label = act_ui.get("status_lbl") as Label
	if is_instance_valid(sl):
		sl.text = "Latest Drop: %s" % str(res.get("label", "Reward"))
		sl.modulate = res.get("color", Color.WHITE) as Color
	_refresh_crate_ui()
	_update_ach_badge()
	_refresh_agent_select_ui()

	if is_big:
		await get_tree().create_timer(0.24).timeout
		if is_inside_tree() and _crate_reveal_overlay.visible:
			_show_big_win_spotlight([res])


func _start_batch_crate_open(is_premium_crate: bool, count: int = 10) -> void:
	if _crate_spinning:
		return
	_crate_spinning = true
	var res: Dictionary = ProfileManager.open_crates_batch(is_premium_crate, count)
	var act_ui: Dictionary = _crate_premium_ui if is_premium_crate else _crate_supply_ui
	var status_lbl: Label = act_ui.get("status_lbl") as Label
	if not bool(res.get("ok", false)):
		_crate_spinning = false
		if is_instance_valid(status_lbl):
			status_lbl.text = str(res.get("error", "Cannot open crates."))
			status_lbl.modulate = Color(1.0, 0.42, 0.36)
		_refresh_crate_ui()
		return

	var items: Array = res.get("items", []) as Array
	SettingsManager.play_ui_purchase()
	var running_coins: int = int(res.get("coins_before_rewards", ProfileManager.coins))
	if is_instance_valid(_crate_coin_lbl):
		_crate_coin_lbl.text = ProfileManager.format_coins(running_coins)
	_refresh_crate_ui()

	_crate_reveal_in_progress = true
	_crate_reveal_skip_requested = false
	_crate_reveal_title.text = "OPENING %dx %s" % [items.size(), "PREMIUM CRATES" if is_premium_crate else "SUPPLY CRATES"]
	_crate_reveal_sub.text = "Sealed crates ready — opening 1 by 1..."
	_crate_reveal_sub.modulate = Color(0.84, 0.94, 1.0)
	_crate_reveal_coin_lbl.text = ProfileManager.format_coins(running_coins)
	_crate_reveal_skip_btn.visible = true
	_crate_reveal_skip_btn.disabled = false
	_crate_reveal_close_btn.visible = false
	_crate_reveal_equip_btn.visible = false
	_crate_reveal_equip_item = {}
	for c in _crate_reveal_body.get_children():
		c.queue_free()
	_crate_reveal_overlay.visible = true

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crate_reveal_body.add_child(cc)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	cc.add_child(grid)

	var cards: Array[PanelContainer] = []
	for i in range(items.size()):
		var mc: PanelContainer = _make_mystery_crate_card(is_premium_crate, Vector2(156, 144), "#%d" % (i + 1))
		mc.scale = Vector2.ZERO
		grid.add_child(mc)
		cards.append(mc)

	# Stagger all 10 sealed mystery boxes onto screen simultaneously
	for i in range(cards.size()):
		var c_node: PanelContainer = cards[i]
		var stw := create_tween()
		stw.tween_interval(float(i) * 0.032)
		stw.tween_property(c_node, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(float(cards.size()) * 0.032 + 0.24).timeout
	if not is_inside_tree():
		return

	await _run_batch_auto_reveal(cards, items, running_coins, is_premium_crate)


func _run_batch_auto_reveal(cards: Array[PanelContainer], items: Array, start_coins: int, is_premium_crate: bool) -> void:
	var running_coins: int = start_coins
	var revealed: Array[bool] = []
	for _r in range(cards.size()):
		revealed.append(false)

	for i in range(cards.size()):
		if not is_inside_tree():
			return
		if _crate_reveal_skip_requested:
			break
		var card: PanelContainer = cards[i]
		var item: Dictionary = items[i] as Dictionary
		var k: String = str(item.get("kind", "coins"))
		var is_big: bool = (k == "premium_skin" or k == "rare_skin" or k == "basic_skin" or k == "double_coins" or k == "dummy_gear" or k == "agent_unlock")

		var f1 := create_tween()
		f1.tween_property(card, "scale", Vector2(1.06, 1.06), 0.05)
		f1.tween_property(card, "scale:x", 0.0, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await f1.finished
		if not is_inside_tree():
			return

		_populate_revealed_card_contents(card, item, false)
		revealed[i] = true
		if is_big:
			_play_crate_chime_sfx()
		else:
			_play_ui_pickup_sfx(0.95 + float(i) * 0.035, -3.0)

		var f2 := create_tween()
		f2.tween_property(card, "scale", Vector2(1.08 if is_big else 1.03, 1.08 if is_big else 1.03), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		f2.tween_property(card, "scale", Vector2.ONE, 0.06)
		await f2.finished
		if not is_inside_tree():
			return

		running_coins += int(item.get("coins_won", 0))
		_crate_reveal_coin_lbl.text = ProfileManager.format_coins(running_coins)
		_crate_reveal_sub.text = "Opened %d / %d" % [i + 1, items.size()]

		if _crate_reveal_skip_requested:
			break
		await get_tree().create_timer(0.28 if is_big else 0.11).timeout

	if not is_inside_tree():
		return

	# Flip any remaining cards immediately if user pressed SKIP
	for i in range(cards.size()):
		if not revealed[i]:
			_populate_revealed_card_contents(cards[i], items[i] as Dictionary, false)
			cards[i].scale = Vector2.ONE

	_crate_reveal_in_progress = false
	_crate_spinning = false
	_crate_reveal_skip_btn.visible = false
	_crate_reveal_coin_lbl.text = ProfileManager.format_coins(ProfileManager.coins)
	_crate_coin_lbl.text = _crate_reveal_coin_lbl.text
	_crate_reveal_title.text = "ALL %d CRATES OPENED!" % items.size()

	# Gather Big Wins (skins, dummy gear, agent unlocks, 2x coins — duplicates convert on spotlight)
	var big_wins: Array[Dictionary] = []
	for raw_it in items:
		var it: Dictionary = raw_it as Dictionary
		var kk: String = str(it.get("kind", "coins"))
		if kk == "premium_skin" or kk == "rare_skin" or kk == "basic_skin" or kk == "double_coins" or kk == "dummy_gear" or kk == "agent_unlock":
			big_wins.append(it)

	big_wins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: int = _crate_bigwin_rank(a)
		var pb: int = _crate_bigwin_rank(b)
		if pa != pb:
			return pa < pb
		return (not bool(a.get("is_duplicate", false))) and bool(b.get("is_duplicate", false))
	)

	var best_eq: Dictionary = {}
	for bw in big_wins:
		if _is_crate_equipable_item(bw):
			best_eq = bw
			break
	_crate_reveal_equip_item = best_eq
	_configure_equip_button(_crate_reveal_equip_btn, best_eq)
	_crate_reveal_close_btn.text = "COLLECT ALL"
	_crate_reveal_close_btn.visible = true

	var act_ui: Dictionary = _crate_premium_ui if is_premium_crate else _crate_supply_ui
	var sl: Label = act_ui.get("status_lbl") as Label
	if not big_wins.is_empty():
		_crate_reveal_sub.text = "JACKPOT! Pulled %d Special Drop(s)!" % big_wins.size()
		_crate_reveal_sub.modulate = Color(1.0, 0.88, 0.28)
		if is_instance_valid(sl):
			sl.text = "10x Pull: %s" % str(big_wins[0].get("label", "Big Drop!"))
			sl.modulate = big_wins[0].get("color", Color(1.0, 0.84, 0.24)) as Color
	else:
		var total_c: int = 0
		for raw_c in items:
			total_c += int((raw_c as Dictionary).get("coins_won", 0))
		_crate_reveal_sub.text = "Total NC Gained: +%s NC" % ProfileManager.format_coins(total_c)
		_crate_reveal_sub.modulate = Color(0.55, 1.0, 0.72)
		if is_instance_valid(sl):
			sl.text = "10x Supply Bonus: +%s NC" % ProfileManager.format_coins(total_c)
			sl.modulate = Color(0.55, 1.0, 0.72)

	_refresh_crate_ui()
	_update_ach_badge()
	_refresh_agent_select_ui()

	if not big_wins.is_empty():
		await get_tree().create_timer(0.32).timeout
		if is_inside_tree() and _crate_reveal_overlay.visible:
			_show_big_win_spotlight(big_wins)


func _crate_bigwin_rank(item: Dictionary) -> int:
	match str(item.get("kind", "coins")):
		"agent_unlock":
			return 0
		"premium_skin":
			return 1
		"rare_skin":
			return 2
		"double_coins":
			return 3
		"basic_skin":
			return 4
		"dummy_gear":
			return 5
		_:
			return 6


func _show_big_win_spotlight(big_wins: Array) -> void:
	if big_wins.is_empty():
		return
	var top_it: Dictionary = big_wins[0] as Dictionary
	var k: String = str(top_it.get("kind", "basic_skin"))
	var accent: Color = top_it.get("color", Color(1.0, 0.84, 0.22)) as Color
	_crate_bigwin_accent = accent

	if big_wins.size() > 1:
		_crate_bigwin_title.text = "★ MEGA JACKPOT! (%d BIG DROPS) ★" % big_wins.size()
	elif k == "agent_unlock":
		_crate_bigwin_title.text = "★ ALL AGENTS OWNED! ★" if bool(top_it.get("is_duplicate", false)) else "★ NEW AGENT UNLOCKED! ★"
	elif k == "premium_skin":
		_crate_bigwin_title.text = "★ LEGENDARY PREMIUM SKIN! ★"
	elif k == "rare_skin":
		_crate_bigwin_title.text = "◆ RARE GUN SKIN UNLOCKED! ◆"
	elif k == "double_coins":
		_crate_bigwin_title.text = "★ 2x NC JACKPOT! ★"
	elif k == "dummy_gear":
		_crate_bigwin_title.text = "★ NEW COSMETIC UNLOCKED! ★"
	else:
		_crate_bigwin_title.text = "● COMMON GUN SKIN UNLOCKED! ●"
	_crate_bigwin_title.modulate = accent

	var names: PackedStringArray = PackedStringArray()
	for raw_bw in big_wins:
		var bw: Dictionary = raw_bw as Dictionary
		names.append(str(bw.get("label", "Reward")))
	_crate_bigwin_sub.text = "  •  ".join(names)

	for c in _crate_bigwin_cards_row.get_children():
		c.queue_free()

	var show_n: int = mini(big_wins.size(), 4)
	var cw: float = 220.0 if show_n <= 2 else (196.0 if show_n == 3 else 178.0)
	var use_large: bool = (show_n <= 3)
	for i in range(show_n):
		var c := PanelContainer.new()
		c.custom_minimum_size = Vector2(cw, 214)
		c.pivot_offset = Vector2(cw * 0.5, 107.0)
		c.scale = Vector2(0.2, 0.2)
		var bw_item: Dictionary = big_wins[i] as Dictionary
		_populate_revealed_card_contents(c, bw_item, use_large)
		_crate_bigwin_cards_row.add_child(c)
		var ctw := create_tween()
		ctw.tween_interval(float(i) * 0.08)
		ctw.tween_property(c, "scale", Vector2(1.06, 1.06), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ctw.tween_property(c, "scale", Vector2.ONE, 0.10)

		if bool(bw_item.get("is_duplicate", false)):
			var conv_tw := c.create_tween()
			conv_tw.tween_interval(0.72 + float(i) * 0.14)
			conv_tw.tween_property(c, "scale", Vector2(1.09, 1.09), 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			conv_tw.tween_property(c, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			conv_tw.tween_callback(func():
				if not is_instance_valid(c):
					return
				_populate_converted_coins_card(c, bw_item, use_large)
				_play_ui_pickup_sfx(1.18, 2.0)
				if big_wins.size() == 1 and is_instance_valid(_crate_bigwin_title):
					_crate_bigwin_title.text = "★ DUPLICATE → NC! ★"
					_crate_bigwin_title.modulate = Color(1.0, 0.86, 0.24)
			)
			conv_tw.tween_property(c, "scale", Vector2(1.10, 1.10), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			conv_tw.tween_property(c, "scale", Vector2.ONE, 0.08)

	_crate_bigwin_best_item = {}
	for raw_bw2 in big_wins:
		var bw2: Dictionary = raw_bw2 as Dictionary
		if _is_crate_equipable_item(bw2):
			_crate_bigwin_best_item = bw2
			break
	_configure_equip_button(_crate_bigwin_equip_btn, _crate_bigwin_best_item)

	_crate_bigwin_overlay.visible = true
	_crate_bigwin_angle = 0.0
	_play_crate_chime_sfx()

	_crate_bigwin_flash.color = Color(1.0, 0.96, 0.72, 0.78)
	var fl_tw := create_tween()
	fl_tw.tween_property(_crate_bigwin_flash, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ==============================================================================
# 100 ACHIEVEMENTS OVERLAY (MAIN + SUB-ACHIEVEMENTS)
# ==============================================================================

func _update_ach_badge() -> void:
	if not is_instance_valid(_ach_top_btn):
		return
	var unclaimed: int = AchievementManager.get_unclaimed_count()
	var lbl_txt: String = ("ACHIEVEMENTS (%d)" % unclaimed) if unclaimed > 0 else "ACHIEVEMENTS"
	if _ach_top_btn.has_meta("card_label"):
		var cl: Label = _ach_top_btn.get_meta("card_label") as Label
		if is_instance_valid(cl):
			cl.text = lbl_txt
	else:
		_ach_top_btn.text = lbl_txt
	_ach_top_btn.modulate = Color(1.0, 0.92, 0.55) if unclaimed > 0 else Color.WHITE


func _build_achievements_overlay() -> void:
	_ach_overlay = ColorRect.new()
	_ach_overlay.z_index = 64
	_ach_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ach_overlay.color = Color(0.02, 0.03, 0.06, 0.92)
	_ach_overlay.visible = false
	add_child(_ach_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ach_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(980, 590)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	sb.border_color = Color(0.76, 0.54, 1.0, 0.98)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	cc.add_child(card)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	card.add_child(root_v)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	root_v.add_child(hdr)

	_ach_header_lbl = Label.new()
	_ach_header_lbl.text = "ACHIEVEMENTS (0 / 100)"
	_ach_header_lbl.add_theme_font_size_override("font_size", 20)
	_ach_header_lbl.modulate = Color(0.86, 0.70, 1.0)
	_ach_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(_ach_header_lbl)

	_ach_coin_lbl = _add_coin_icon_label(hdr, ProfileManager.format_coins(ProfileManager.coins), 22, 18, Color(1.0, 0.90, 0.30), false)

	var close_btn := _make_arcade_button("CLOSE", Color(0.92, 0.34, 0.34), 38.0, 15, Color(0.26, 0.08, 0.10, 0.96))
	close_btn.custom_minimum_size = Vector2(105, 38)
	close_btn.pressed.connect(func():
		_ach_overlay.visible = false
		_hub_container.visible = true
		_update_ach_badge()
	)
	hdr.add_child(close_btn)

	# Category Filter Bar
	var f_row := HBoxContainer.new()
	f_row.add_theme_constant_override("separation", 6)
	root_v.add_child(f_row)

	_ach_filter_btns.clear()
	for cat in ["All", "Blast 500", "GunMaster", "Agents", "Combat", "Pickups", "Economy"]:
		var fb := Button.new()
		fb.text = cat
		fb.custom_minimum_size = Vector2(0, 32)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fb.pressed.connect(func():
			_ach_filter = cat
			_refresh_achievements_list()
		)
		f_row.add_child(fb)
		_ach_filter_btns[cat] = fb

	# Scrollable Achievements List
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	root_v.add_child(sc)

	_ach_list_box = VBoxContainer.new()
	_ach_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ach_list_box.add_theme_constant_override("separation", 7)
	_ach_list_box.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(_ach_list_box)


func _open_achievements_overlay() -> void:
	_hub_container.visible = false
	_ach_overlay.visible = true
	AchievementManager.record_agent_or_skin_change()
	_refresh_achievements_list()


func _refresh_achievements_list() -> void:
	if not is_instance_valid(_ach_list_box):
		return
	var done_c: int = AchievementManager.get_completed_count()
	var tot_c: int = AchievementManager.definitions.size()
	if is_instance_valid(_ach_header_lbl):
		_ach_header_lbl.text = "ACHIEVEMENTS  —  %d / %d COMPLETED" % [done_c, tot_c]
	if is_instance_valid(_ach_coin_lbl):
		_ach_coin_lbl.text = ProfileManager.format_coins(ProfileManager.coins)
	for cat in _ach_filter_btns.keys():
		var b: Button = _ach_filter_btns[cat] as Button
		b.modulate = Color(1.0, 0.88, 0.34) if str(cat) == _ach_filter else Color(0.80, 0.85, 0.94)

	for c in _ach_list_box.get_children():
		c.queue_free()

	var parent_child_counts: Dictionary = {}
	for d in AchievementManager.definitions:
		var pid_str: String = str(d.get("parent", ""))
		if not pid_str.is_empty():
			parent_child_counts[pid_str] = int(parent_child_counts.get(pid_str, 0)) + 1

	for d in AchievementManager.definitions:
		if _ach_filter != "All" and str(d["category"]) != _ach_filter:
			continue
		var aid: String = str(d["id"])
		var parent_id: String = str(d.get("parent", ""))
		var is_sub: bool = not parent_id.is_empty()
		if _ach_filter == "All" and is_sub and bool(_ach_collapsed_parents.get(parent_id, false)):
			continue
		var has_children: bool = (not is_sub) and int(parent_child_counts.get(aid, 0)) > 0
		var is_collapsed: bool = bool(_ach_collapsed_parents.get(aid, false))
		var has_skin: bool = not str(d.get("reward_skin", "")).is_empty()
		var prog: int = AchievementManager.get_progress(aid)
		var target: int = maxi(1, int(d["target"]))
		var completed: bool = AchievementManager.is_completed(aid)
		var claimed_b: bool = AchievementManager.is_claimed(aid)

		var outer := HBoxContainer.new()
		outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer.mouse_filter = Control.MOUSE_FILTER_PASS
		_ach_list_box.add_child(outer)
		if is_sub:
			var indent := Control.new()
			indent.custom_minimum_size = Vector2(28, 0)
			indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			outer.add_child(indent)

		var pcard := PanelContainer.new()
		pcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pcard.mouse_filter = Control.MOUSE_FILTER_PASS
		var csb := StyleBoxFlat.new()
		if claimed_b:
			csb.bg_color = Color(0.08, 0.16, 0.12, 0.92)
			csb.border_color = Color(0.28, 0.72, 0.44, 0.80)
		elif completed:
			csb.bg_color = Color(0.18, 0.15, 0.06, 0.98)
			csb.border_color = Color(1.0, 0.84, 0.24, 0.98)
		elif has_skin:
			csb.bg_color = Color(0.14, 0.09, 0.22, 0.96)
			csb.border_color = Color(0.84, 0.48, 1.0, 0.92)
		else:
			csb.bg_color = Color(0.09, 0.13, 0.20, 0.95)
			csb.border_color = Color(0.26, 0.40, 0.60, 0.80)
		csb.set_border_width_all(2 if (completed or has_skin) else 1)
		csb.set_corner_radius_all(9)
		csb.set_content_margin_all(8)
		pcard.add_theme_stylebox_override("panel", csb)
		outer.add_child(pcard)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		pcard.add_child(row)

		if _ach_filter == "All" and has_children:
			var toggle_btn := Button.new()
			toggle_btn.text = ("▶ %d" % int(parent_child_counts[aid])) if is_collapsed else ("▼ %d" % int(parent_child_counts[aid]))
			toggle_btn.custom_minimum_size = Vector2(54, 34)
			toggle_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			toggle_btn.mouse_filter = Control.MOUSE_FILTER_PASS
			var t_sb := StyleBoxFlat.new()
			t_sb.bg_color = Color(0.16, 0.12, 0.28, 0.96)
			t_sb.border_color = Color(0.76, 0.56, 1.0, 0.85)
			t_sb.set_border_width_all(1)
			t_sb.set_corner_radius_all(7)
			toggle_btn.add_theme_stylebox_override("normal", t_sb)
			toggle_btn.add_theme_stylebox_override("hover", t_sb)
			toggle_btn.add_theme_stylebox_override("pressed", t_sb)
			toggle_btn.add_theme_font_size_override("font_size", 12)
			var cap_aid: String = aid
			toggle_btn.pressed.connect(func():
				_ach_collapsed_parents[cap_aid] = not bool(_ach_collapsed_parents.get(cap_aid, false))
				_refresh_achievements_list()
			)
			row.add_child(toggle_btn)

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.add_theme_constant_override("separation", 3)
		info_v.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(info_v)

		var title_l := Label.new()
		var prefix: String = "↳ " if is_sub else ("★ MAIN: " if has_skin else "")
		title_l.text = "%s%s" % [prefix, str(d["title"])]
		title_l.add_theme_font_size_override("font_size", 14 if is_sub else 15)
		title_l.modulate = Color(1.0, 0.88, 0.34) if (completed or has_skin) else Color(0.94, 0.96, 1.0)
		title_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_v.add_child(title_l)

		var desc_l := Label.new()
		desc_l.text = str(d["desc"])
		desc_l.add_theme_font_size_override("font_size", 11)
		desc_l.modulate = Color(0.74, 0.82, 0.92)
		desc_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_v.add_child(desc_l)

		var pb := ProgressBar.new()
		pb.min_value = 0.0
		pb.max_value = float(target)
		pb.value = float(mini(prog, target))
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 8)
		pb.mouse_filter = Control.MOUSE_FILTER_PASS
		var pb_bg := StyleBoxFlat.new()
		pb_bg.bg_color = Color(0.04, 0.06, 0.10, 0.95)
		pb_bg.set_corner_radius_all(4)
		var pb_fg := StyleBoxFlat.new()
		pb_fg.bg_color = Color(0.32, 0.96, 0.54) if completed else Color(0.38, 0.78, 1.0)
		pb_fg.set_corner_radius_all(4)
		pb.add_theme_stylebox_override("background", pb_bg)
		pb.add_theme_stylebox_override("fill", pb_fg)
		info_v.add_child(pb)

		var rew_v := VBoxContainer.new()
		rew_v.custom_minimum_size = Vector2(185, 0)
		rew_v.alignment = BoxContainer.ALIGNMENT_CENTER
		rew_v.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(rew_v)

		_add_coin_icon_label(rew_v, "+%s" % ProfileManager.format_coins(int(d["reward_coins"])), 16, 13, Color(1.0, 0.86, 0.28), false, BoxContainer.ALIGNMENT_END)

		if has_skin:
			var sk_pair: String = str(d["reward_skin"])
			var parts: PackedStringArray = sk_pair.split(":")
			if parts.size() == 2:
				var swid: int = int(parts[0])
				var sskey: String = parts[1]
				var sk_lbl := Label.new()
				sk_lbl.text = "★ %s (%s)" % [WeaponData.get_weapon(swid, 0, 0).display_name, ProfileManager.get_gun_skin_name(swid, sskey)]
				sk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				sk_lbl.add_theme_font_size_override("font_size", 11)
				sk_lbl.modulate = Color(1.0, 0.62, 0.98)
				rew_v.add_child(sk_lbl)

		var act := Button.new()
		act.custom_minimum_size = Vector2(104, 36)
		if claimed_b:
			act.text = "CLAIMED ✓"
			act.disabled = true
			act.modulate = Color(0.55, 0.88, 0.64)
		elif completed:
			act.text = "CLAIM"
			act.modulate = Color(0.40, 1.0, 0.56)
			act.pressed.connect(func():
				var cr: Dictionary = AchievementManager.claim_achievement(aid)
				if bool(cr.get("ok", false)):
					SettingsManager.play_ui_purchase()
					_refresh_achievements_list()
					_update_ach_badge()
			)
		else:
			act.text = "%d / %d" % [mini(prog, target), target]
			act.disabled = true
			act.modulate = Color(0.70, 0.76, 0.85)
		row.add_child(act)


# ==============================================================================
# COIN SHOP OVERLAY (PLAY STORE PACKS DESIGN & PURCHASE POPUP)
# ==============================================================================

func _build_coin_shop_overlay() -> void:
	_coin_shop_overlay = ColorRect.new()
	_coin_shop_overlay.z_index = 68
	_coin_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_shop_overlay.color = Color(0.02, 0.03, 0.06, 0.92)
	_coin_shop_overlay.visible = false
	add_child(_coin_shop_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_shop_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(960, 565)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 0.99)
	sb.border_color = Color(1.0, 0.84, 0.24, 0.98)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	cc.add_child(card)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	card.add_child(root_v)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	root_v.add_child(hdr)

	var hdr_icon := TextureRect.new()
	hdr_icon.texture = _get_coin_icon()
	hdr_icon.custom_minimum_size = Vector2(22, 34)
	hdr_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hdr_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hdr.add_child(hdr_icon)

	var title := Label.new()
	title.text = "NC SHOP"
	title.add_theme_font_size_override("font_size", 22)
	title.modulate = Color(1.0, 0.88, 0.30)
	hdr.add_child(title)

	var store_pill := PanelContainer.new()
	var sp_sb := StyleBoxFlat.new()
	sp_sb.bg_color = Color(0.08, 0.24, 0.16, 0.96)
	sp_sb.border_color = Color(0.32, 0.92, 0.56, 0.90)
	sp_sb.set_border_width_all(2)
	sp_sb.set_corner_radius_all(8)
	sp_sb.content_margin_left = 10.0
	sp_sb.content_margin_right = 10.0
	sp_sb.content_margin_top = 3.0
	sp_sb.content_margin_bottom = 3.0
	store_pill.add_theme_stylebox_override("panel", sp_sb)
	store_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hdr.add_child(store_pill)

	var sp_lbl := Label.new()
	sp_lbl.text = "NAMELESS CLASH CASH (NC)  •  PLAY STORE PREVIEW"
	sp_lbl.add_theme_font_size_override("font_size", 11)
	sp_lbl.modulate = Color(0.56, 1.0, 0.72)
	store_pill.add_child(sp_lbl)

	var hdr_spacer := Control.new()
	hdr_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hdr_spacer)

	_coin_shop_coin_lbl = _add_coin_icon_label(hdr, ProfileManager.format_coins(ProfileManager.coins), 22, 19, Color(1.0, 0.90, 0.30), false)

	var close_btn := _make_arcade_button("CLOSE", Color(0.92, 0.34, 0.34), 38.0, 15, Color(0.26, 0.08, 0.10, 0.96))
	close_btn.custom_minimum_size = Vector2(105, 38)
	close_btn.pressed.connect(func():
		_coin_shop_overlay.visible = false
		if is_instance_valid(_coin_shop_return_overlay):
			_coin_shop_return_overlay.visible = true
			if _coin_shop_return_overlay == _shop_overlay:
				_refresh_shop_skins()
			elif _coin_shop_return_overlay == _crate_overlay:
				_refresh_crate_ui()
		else:
			_hub_container.visible = true
		_coin_shop_return_overlay = null
	)
	hdr.add_child(close_btn)

	# 3x2 Pack Grid
	_coin_shop_grid = GridContainer.new()
	_coin_shop_grid.columns = 3
	_coin_shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coin_shop_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_coin_shop_grid.add_theme_constant_override("h_separation", 14)
	_coin_shop_grid.add_theme_constant_override("v_separation", 12)
	root_v.add_child(_coin_shop_grid)

	_refresh_coin_shop_grid()

	var foot := Label.new()
	foot.text = "Play Store Preview Mode — No real payment API connected yet. Purchases grant Nameless Clash Cash (NC) immediately for testing."
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 12)
	foot.modulate = Color(0.68, 0.78, 0.92)
	root_v.add_child(foot)


func _refresh_coin_shop_grid() -> void:
	if not is_instance_valid(_coin_shop_grid):
		return
	for c in _coin_shop_grid.get_children():
		c.queue_free()

	for p in ProfileManager.get_coin_shop_packs():
		var sku: String = str(p["sku"])
		var pname: String = str(p["name"])
		var base_c: int = int(p["coins"])
		var bonus_c: int = int(p["bonus_coins"])
		var total_c: int = base_c + bonus_c
		var price_usd: String = str(p["price_usd"])
		var tag_txt: String = str(p.get("tag", ""))
		var tier: int = int(p.get("tier", 0))
		var accent: Color = p.get("accent", Color(1.0, 0.84, 0.24)) as Color

		var pcard := PanelContainer.new()
		pcard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pcard.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var psb := StyleBoxFlat.new()
		psb.bg_color = accent.darkened(0.84)
		psb.bg_color.a = 0.98
		psb.border_color = accent
		psb.set_border_width_all(3 if tier >= 2 else 2)
		psb.set_corner_radius_all(14)
		psb.set_content_margin_all(12)
		psb.shadow_color = Color(accent.r, accent.g, accent.b, 0.22 if tier >= 3 else 0.10)
		psb.shadow_size = 6
		pcard.add_theme_stylebox_override("panel", psb)
		_coin_shop_grid.add_child(pcard)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		pcard.add_child(vb)

		var top_r := HBoxContainer.new()
		top_r.add_theme_constant_override("separation", 6)
		vb.add_child(top_r)

		var nl := Label.new()
		nl.text = pname.to_upper()
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 14)
		nl.modulate = accent.lightened(0.25)
		top_r.add_child(nl)

		if not tag_txt.is_empty():
			var tpill := PanelContainer.new()
			tpill.size_flags_horizontal = Control.SIZE_SHRINK_END
			tpill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var tsb := StyleBoxFlat.new()
			tsb.bg_color = accent.darkened(0.55)
			tsb.border_color = accent
			tsb.set_border_width_all(1)
			tsb.set_corner_radius_all(6)
			tsb.content_margin_left = 7.0
			tsb.content_margin_right = 7.0
			tsb.content_margin_top = 1.5
			tsb.content_margin_bottom = 1.5
			tpill.add_theme_stylebox_override("panel", tsb)
			var tlbl := Label.new()
			tlbl.text = tag_txt
			tlbl.add_theme_font_size_override("font_size", 10)
			tlbl.modulate = Color(1.0, 0.96, 0.80)
			tpill.add_child(tlbl)
			top_r.add_child(tpill)

		var gfx := Control.new()
		gfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gfx.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gfx.custom_minimum_size = Vector2(0, 74)
		gfx.draw.connect(func(): _draw_coin_pack_graphic(gfx, tier, accent))
		vb.add_child(gfx)

		var amt_lbl: Label = _add_coin_icon_label(vb, ProfileManager.format_coins(total_c), 24, 22, Color(1.0, 0.90, 0.34), true)
		amt_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.95))
		amt_lbl.add_theme_constant_override("outline_size", 2)

		var sub_lbl := Label.new()
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 11)
		if bonus_c > 0:
			sub_lbl.text = "%s + %s BONUS NC" % [ProfileManager.format_coins(base_c), ProfileManager.format_coins(bonus_c)]
			sub_lbl.modulate = Color(0.52, 1.0, 0.68)
		else:
			sub_lbl.text = "INSTANT DELIVERY"
			sub_lbl.modulate = Color(0.72, 0.84, 0.96)
		vb.add_child(sub_lbl)

		var buy_btn := _make_arcade_button("BUY  %s" % price_usd, Color(0.38, 1.0, 0.58), 40.0, 16, Color(0.09, 0.34, 0.17, 0.98))
		buy_btn.custom_minimum_size = Vector2(0, 40)
		buy_btn.pressed.connect(_on_buy_coin_pack.bind(sku))
		vb.add_child(buy_btn)


func _draw_coin_pack_graphic(ctrl: Control, tier: int, accent: Color) -> void:
	var w: float = ctrl.size.x
	var h: float = ctrl.size.y
	if w <= 4.0 or h <= 4.0:
		return
	var center := Vector2(w * 0.5, h * 0.53)
	var r: float = minf(w, h) * 0.42
	ctrl.draw_circle(center, r, Color(accent.r, accent.g, accent.b, 0.14))
	ctrl.draw_circle(center, r * 0.65, Color(accent.r, accent.g, accent.b, 0.22))

	var coin_tex: Texture2D = _get_coin_icon()
	if coin_tex == null:
		return

	var tex_sz: Vector2 = coin_tex.get_size()
	var aspect: float = (tex_sz.x / tex_sz.y) if tex_sz.y > 0.0 else 0.60
	var scale_f: float = clampf(h / 74.0, 0.85, 1.35)

	# Each entry is Vector4(offset_x, offset_y, bill_height, rotation_radians)
	var bills: Array = []
	match tier:
		0:
			bills = [
				Vector4(-10.0, 2.0, 48.0, -0.18),
				Vector4(10.0, -2.0, 52.0, 0.14)
			]
		1:
			bills = [
				Vector4(-22.0, 5.0, 46.0, -0.28),
				Vector4(22.0, 5.0, 46.0, 0.28),
				Vector4(0.0, -3.0, 54.0, 0.0)
			]
		2:
			bills = [
				Vector4(-32.0, 8.0, 44.0, -0.36),
				Vector4(32.0, 8.0, 44.0, 0.36),
				Vector4(-16.0, 2.0, 48.0, -0.16),
				Vector4(16.0, 2.0, 48.0, 0.16),
				Vector4(0.0, -5.0, 56.0, 0.0)
			]
		3:
			bills = [
				Vector4(-42.0, 10.0, 42.0, -0.44),
				Vector4(42.0, 10.0, 42.0, 0.44),
				Vector4(-26.0, 6.0, 46.0, -0.28),
				Vector4(26.0, 6.0, 46.0, 0.28),
				Vector4(-13.0, 0.0, 50.0, -0.12),
				Vector4(13.0, 0.0, 50.0, 0.12),
				Vector4(0.0, -6.0, 58.0, 0.0)
			]
		4:
			bills = [
				Vector4(-46.0, 10.0, 42.0, -0.46),
				Vector4(46.0, 10.0, 42.0, 0.46),
				Vector4(-20.0, 8.0, 46.0, -0.20),
				Vector4(20.0, 8.0, 46.0, 0.20),
				Vector4(-32.0, 0.0, 48.0, -0.30),
				Vector4(32.0, 0.0, 48.0, 0.30),
				Vector4(-11.0, -3.0, 52.0, -0.10),
				Vector4(11.0, -3.0, 52.0, 0.10),
				Vector4(0.0, -7.0, 58.0, 0.0)
			]
		_:
			bills = [
				Vector4(-54.0, 12.0, 40.0, -0.52),
				Vector4(54.0, 12.0, 40.0, 0.52),
				Vector4(-34.0, 9.0, 44.0, -0.34),
				Vector4(34.0, 9.0, 44.0, 0.34),
				Vector4(0.0, 8.0, 48.0, 0.0),
				Vector4(-40.0, 1.0, 46.0, -0.38),
				Vector4(40.0, 1.0, 46.0, 0.38),
				Vector4(-18.0, -2.0, 52.0, -0.16),
				Vector4(18.0, -2.0, 52.0, 0.16),
				Vector4(-8.0, -5.0, 56.0, -0.06),
				Vector4(6.0, -7.0, 60.0, 0.05)
			]

	for raw_v in bills:
		var v: Vector4 = raw_v as Vector4
		var bh: float = v.z * scale_f
		var bw: float = bh * aspect
		var bill_pos: Vector2 = center + Vector2(v.x * scale_f, v.y * scale_f)
		ctrl.draw_set_transform(bill_pos, v.w)
		ctrl.draw_texture_rect(coin_tex, Rect2(Vector2(-bw * 0.5, -bh * 0.5), Vector2(bw, bh)), false)
	ctrl.draw_set_transform(Vector2.ZERO, 0.0)

	var spark_pts: Array = [Vector2(-r * 0.85, -r * 0.55), Vector2(r * 0.85, -r * 0.45), Vector2(0.0, -r * 0.92)]
	for raw_sp in spark_pts:
		var sp: Vector2 = raw_sp as Vector2
		var p: Vector2 = center + sp
		var sc: Color = Color(1.0, 0.96, 0.65, 0.88)
		ctrl.draw_line(p + Vector2(-4.0, 0.0), p + Vector2(4.0, 0.0), sc, 1.8)
		ctrl.draw_line(p + Vector2(0.0, -4.0), p + Vector2(0.0, 4.0), sc, 1.8)


func _build_coin_purchase_popup() -> void:
	_coin_purchase_popup = ColorRect.new()
	_coin_purchase_popup.z_index = 72
	_coin_purchase_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_purchase_popup.color = Color(0.01, 0.02, 0.05, 0.84)
	_coin_purchase_popup.visible = false
	add_child(_coin_purchase_popup)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_coin_purchase_popup.add_child(cc)

	_coin_purchase_card = PanelContainer.new()
	_coin_purchase_card.custom_minimum_size = Vector2(470, 380)
	_coin_purchase_card.pivot_offset = Vector2(235.0, 190.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.11, 0.16, 0.99)
	sb.border_color = Color(0.38, 1.0, 0.58, 0.98)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(20)
	sb.shadow_color = Color(0.32, 1.0, 0.54, 0.35)
	sb.shadow_size = 16
	_coin_purchase_card.add_theme_stylebox_override("panel", sb)
	cc.add_child(_coin_purchase_card)

	_coin_purchase_body = VBoxContainer.new()
	_coin_purchase_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_coin_purchase_body.add_theme_constant_override("separation", 10)
	_coin_purchase_card.add_child(_coin_purchase_body)


func _open_coin_shop(return_overlay: Control = null) -> void:
	if _crate_spinning:
		return
	_coin_shop_return_overlay = return_overlay
	_hub_container.visible = false
	if is_instance_valid(_shop_overlay):
		_shop_overlay.visible = false
	if is_instance_valid(_crate_overlay):
		_crate_overlay.visible = false
	if is_instance_valid(_coin_shop_coin_lbl):
		_coin_shop_coin_lbl.text = ProfileManager.format_coins(ProfileManager.coins)
	_refresh_coin_shop_grid()
	_coin_shop_overlay.visible = true


func _on_buy_coin_pack(sku: String) -> void:
	var receipt: Dictionary = ProfileManager.purchase_coin_pack(sku)
	if not bool(receipt.get("ok", false)):
		return
	SettingsManager.play_ui_purchase()
	if is_instance_valid(_coin_shop_coin_lbl):
		_coin_shop_coin_lbl.text = ProfileManager.format_coins(ProfileManager.coins)
	_refresh_crate_ui()
	if is_instance_valid(_shop_overlay) and _coin_shop_return_overlay == _shop_overlay:
		_refresh_shop_skins()
	_show_coin_purchase_popup(receipt)


func _show_coin_purchase_popup(receipt: Dictionary) -> void:
	if not is_instance_valid(_coin_purchase_popup) or not is_instance_valid(_coin_purchase_body):
		return
	for c in _coin_purchase_body.get_children():
		c.queue_free()

	var accent: Color = receipt.get("accent", Color(1.0, 0.86, 0.28)) as Color
	var title := Label.new()
	title.text = "★ PURCHASE SUCCESSFUL! ★"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(0.45, 1.0, 0.62)
	_coin_purchase_body.add_child(title)

	var pname_lbl := Label.new()
	pname_lbl.text = str(receipt.get("name", "NC Pack")).to_upper()
	pname_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pname_lbl.add_theme_font_size_override("font_size", 16)
	pname_lbl.modulate = accent.lightened(0.20)
	_coin_purchase_body.add_child(pname_lbl)

	var gfx := Control.new()
	gfx.custom_minimum_size = Vector2(280, 92)
	gfx.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var tier: int = int(receipt.get("tier", 0))
	gfx.draw.connect(func(): _draw_coin_pack_graphic(gfx, tier, accent))
	_coin_purchase_body.add_child(gfx)

	var total_c: int = int(receipt.get("total_coins", 0))
	var base_c: int = int(receipt.get("base_coins", 0))
	var bonus_c: int = int(receipt.get("bonus_coins", 0))
	var big_c_lbl: Label = _add_coin_icon_label(_coin_purchase_body, "+%s NC" % ProfileManager.format_coins(total_c), 34, 28, Color(1.0, 0.90, 0.32), true)
	big_c_lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02, 0.95))
	big_c_lbl.add_theme_constant_override("outline_size", 2)

	if bonus_c > 0:
		var bonus_lbl := Label.new()
		bonus_lbl.text = "Includes %s Base + %s Bonus NC!" % [ProfileManager.format_coins(base_c), ProfileManager.format_coins(bonus_c)]
		bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_lbl.add_theme_font_size_override("font_size", 13)
		bonus_lbl.modulate = Color(0.55, 1.0, 0.72)
		_coin_purchase_body.add_child(bonus_lbl)

	var rec_panel := PanelContainer.new()
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.04, 0.07, 0.12, 0.96)
	rsb.border_color = Color(0.28, 0.56, 0.86, 0.72)
	rsb.set_border_width_all(1)
	rsb.set_corner_radius_all(10)
	rsb.set_content_margin_all(10)
	rec_panel.add_theme_stylebox_override("panel", rsb)
	_coin_purchase_body.add_child(rec_panel)

	var rec_lbl := Label.new()
	rec_lbl.text = "Google Play (Preview)  •  Paid %s\nOrder #%s" % [str(receipt.get("price_usd", "$0.99")), str(receipt.get("order_id", "GPA.DEMO"))]
	rec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rec_lbl.add_theme_font_size_override("font_size", 12)
	rec_lbl.modulate = Color(0.78, 0.88, 0.98)
	rec_panel.add_child(rec_lbl)

	var bal_row := HBoxContainer.new()
	bal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bal_row.add_theme_constant_override("separation", 6)
	_coin_purchase_body.add_child(bal_row)

	var b_pre := Label.new()
	b_pre.text = "New Balance:"
	b_pre.add_theme_font_size_override("font_size", 14)
	b_pre.modulate = Color(0.84, 0.92, 1.0)
	bal_row.add_child(b_pre)

	_add_coin_icon_label(bal_row, ProfileManager.format_coins(int(receipt.get("new_balance", ProfileManager.coins))), 20, 16, Color(1.0, 0.90, 0.34), true)

	var ok_btn := _make_arcade_button("COLLECT", Color(0.38, 1.0, 0.58), 44.0, 17, Color(0.09, 0.34, 0.17, 0.98))
	ok_btn.custom_minimum_size = Vector2(210, 44)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.pressed.connect(func(): _coin_purchase_popup.visible = false)
	_coin_purchase_body.add_child(ok_btn)

	_coin_purchase_card.scale = Vector2(0.72, 0.72)
	_coin_purchase_popup.visible = true
	var tw := create_tween()
	tw.tween_property(_coin_purchase_card, "scale", Vector2(1.04, 1.04), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_coin_purchase_card, "scale", Vector2.ONE, 0.08)


func _build_leaderboard_overlay() -> void:
	_lb_overlay = ColorRect.new()
	_lb_overlay.z_index = 64
	_lb_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lb_overlay.color = Color(0.02, 0.03, 0.06, 0.92)
	_lb_overlay.visible = false
	add_child(_lb_overlay)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lb_overlay.add_child(cc)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1040, 610)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	sb.border_color = Color(1.0, 0.84, 0.24, 0.98)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(18)
	sb.shadow_color = Color(1.0, 0.82, 0.22, 0.36)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2.ZERO
	card.add_theme_stylebox_override("panel", sb)
	cc.add_child(card)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 10)
	card.add_child(root_v)

	# Header
	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 10)
	root_v.add_child(hdr)

	var title_lbl := Label.new()
	title_lbl.text = "🏆 CAREER & TOP 10 LEADERBOARDS"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.modulate = Color(1.0, 0.84, 0.24)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title_lbl)

	_lb_solo_tab_btn = _make_arcade_button("SOLO CAREER", Color(1.0, 0.84, 0.24), 38.0, 13, Color(0.24, 0.18, 0.05, 0.98))
	_lb_solo_tab_btn.custom_minimum_size = Vector2(166, 38)
	_lb_solo_tab_btn.pressed.connect(func():
		_lb_category = "solo"
		_lb_selected_idx = 0
		_refresh_leaderboard_ui()
	)
	hdr.add_child(_lb_solo_tab_btn)

	_lb_local_tab_btn = _make_arcade_button("MULTIPLAYER", Color(1.0, 0.72, 0.22), 38.0, 13, Color(0.24, 0.14, 0.05, 0.98))
	_lb_local_tab_btn.custom_minimum_size = Vector2(166, 38)
	_lb_local_tab_btn.pressed.connect(func():
		_lb_category = "local"
		_lb_selected_idx = 0
		_refresh_leaderboard_ui()
	)
	hdr.add_child(_lb_local_tab_btn)

	_lb_top_tab_btn = _make_arcade_button("TOP 10 KILLS", Color(0.45, 0.96, 0.56), 38.0, 13, Color(0.08, 0.24, 0.12, 0.98))
	_lb_top_tab_btn.custom_minimum_size = Vector2(166, 38)
	_lb_top_tab_btn.pressed.connect(func():
		_lb_category = "top_kills"
		_lb_selected_idx = 0
		_refresh_leaderboard_ui()
	)
	hdr.add_child(_lb_top_tab_btn)

	var close_btn := _make_arcade_button("CLOSE", Color(0.92, 0.34, 0.34), 38.0, 14, Color(0.26, 0.08, 0.10, 0.96))
	close_btn.custom_minimum_size = Vector2(116, 38)
	close_btn.pressed.connect(func():
		_lb_overlay.visible = false
		_hub_container.visible = true
	)
	hdr.add_child(close_btn)

	# Career Summary Bar (gold-trimmed like Win Screen)
	var sum_panel := PanelContainer.new()
	var sum_sb := StyleBoxFlat.new()
	sum_sb.bg_color = Color(0.14, 0.11, 0.05, 0.94)
	sum_sb.border_color = Color(1.0, 0.82, 0.26, 0.75)
	sum_sb.set_border_width_all(2)
	sum_sb.set_corner_radius_all(10)
	sum_sb.set_content_margin_all(10)
	sum_panel.add_theme_stylebox_override("panel", sum_sb)
	root_v.add_child(sum_panel)

	_lb_summary_lbl = Label.new()
	_lb_summary_lbl.add_theme_font_size_override("font_size", 14)
	_lb_summary_lbl.modulate = Color(1.0, 0.90, 0.45)
	_lb_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum_panel.add_child(_lb_summary_lbl)

	# Split: Left (10 Matches) + Right (Selected Match Details)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	root_v.add_child(split)

	var lp_sb := StyleBoxFlat.new()
	lp_sb.bg_color = Color(0.05, 0.08, 0.14, 0.95)
	lp_sb.border_color = Color(1.0, 0.82, 0.26, 0.55)
	lp_sb.set_border_width_all(2)
	lp_sb.set_corner_radius_all(12)
	lp_sb.set_content_margin_all(10)

	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.42
	left_panel.add_theme_stylebox_override("panel", lp_sb)
	split.add_child(left_panel)

	var left_v := VBoxContainer.new()
	left_v.add_theme_constant_override("separation", 6)
	left_panel.add_child(left_v)

	var l_hdr := Label.new()
	l_hdr.text = "MATCH HISTORY (LATEST 10)"
	l_hdr.add_theme_font_size_override("font_size", 14)
	l_hdr.modulate = Color(1.0, 0.84, 0.24)
	left_v.add_child(l_hdr)

	var l_sc := ScrollContainer.new()
	l_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_v.add_child(l_sc)

	_lb_match_list_box = VBoxContainer.new()
	_lb_match_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lb_match_list_box.add_theme_constant_override("separation", 6)
	l_sc.add_child(_lb_match_list_box)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.58
	right_panel.add_theme_stylebox_override("panel", lp_sb)
	split.add_child(right_panel)

	var r_sc := ScrollContainer.new()
	r_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(r_sc)

	_lb_detail_box = VBoxContainer.new()
	_lb_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lb_detail_box.add_theme_constant_override("separation", 8)
	r_sc.add_child(_lb_detail_box)


func _open_leaderboard_overlay() -> void:
	_hub_container.visible = false
	_lb_overlay.visible = true
	_lb_selected_idx = 0
	_refresh_leaderboard_ui()


func _refresh_leaderboard_ui() -> void:
	if not is_instance_valid(_lb_match_list_box) or not is_instance_valid(_lb_detail_box):
		return
	_lb_solo_tab_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if _lb_category == "solo" else Color(0.58, 0.56, 0.50, 0.78)
	_lb_local_tab_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if _lb_category == "local" else Color(0.58, 0.56, 0.50, 0.78)
	_lb_top_tab_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if _lb_category == "top_kills" else Color(0.58, 0.56, 0.50, 0.78)

	var matches: Array = []
	if _lb_category == "top_kills":
		matches = ProfileManager.get_top_kills_records()
		var solo_c: Dictionary = ProfileManager.get_career_data("solo").get("career", {}) as Dictionary
		var local_c: Dictionary = ProfileManager.get_career_data("local").get("career", {}) as Dictionary
		var tot_m: int = int(solo_c.get("matches", 0)) + int(local_c.get("matches", 0))
		var tot_w: int = int(solo_c.get("wins", 0)) + int(local_c.get("wins", 0))
		var tot_k: int = int(solo_c.get("kills", 0)) + int(local_c.get("kills", 0))
		var best_k: int = maxi(int(solo_c.get("best_kills", 0)), int(local_c.get("best_kills", 0)))
		var best_s: int = maxi(int(solo_c.get("best_score", 0)), int(local_c.get("best_score", 0)))
		_lb_summary_lbl.text = "MY TOP 10 KILLS (SOLO & MULTIPLAYER)   •   Total Matches: %d   |   Total Wins: %d   |   Total Kills: %d   |   Best Match Kills: %d   |   Best Score: %d" % [
			tot_m, tot_w, tot_k, best_k, best_s
		]
	else:
		var data: Dictionary = ProfileManager.get_career_data(_lb_category)
		var c: Dictionary = data.get("career", {}) as Dictionary
		matches = data.get("recent_matches", []) as Array
		var m_cnt: int = int(c.get("matches", 0))
		var wins: int = int(c.get("wins", 0))
		var kills: int = int(c.get("kills", 0))
		var deaths: int = int(c.get("deaths", 0))
		var assists: int = int(c.get("assists", 0))
		var win_pct: int = int(round((float(wins) / float(maxi(1, m_cnt))) * 100.0)) if m_cnt > 0 else 0
		var kd: float = float(kills) / float(maxi(1, deaths))
		var mode_tag: String = "SOLO" if _lb_category == "solo" else "MULTIPLAYER"
		_lb_summary_lbl.text = "%s CAREER   •   Matches: %d   |   Wins: %d (%d%%)   |   K: %d  /  D: %d  /  A: %d   |   K/D: %.2f   |   Best Score: %d   |   Best Combo: %dx" % [
			mode_tag, m_cnt, wins, win_pct, kills, deaths, assists, kd, int(c.get("best_score", 0)), int(c.get("best_combo", 0))
		]

	for ch in _lb_match_list_box.get_children():
		ch.queue_free()
	for ch in _lb_detail_box.get_children():
		ch.queue_free()

	if matches.is_empty():
		var empty_l := Label.new()
		empty_l.text = "No matches recorded here yet.\nPlay a match to populate your Career!"
		empty_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_l.modulate = Color(0.84, 0.80, 0.66)
		_lb_match_list_box.add_child(empty_l)

		var empty_r := Label.new()
		empty_r.text = "Select any match on the left to inspect:\n• Match Winner & Full Scoreboard Table\n• Whom I Killed & How Many Times\n• Who Killed Me & How Many Times"
		empty_r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_r.modulate = Color(0.88, 0.84, 0.70)
		_lb_detail_box.add_child(empty_r)
		return

	_lb_selected_idx = clampi(_lb_selected_idx, 0, matches.size() - 1)
	for i in range(matches.size()):
		var m: Dictionary = matches[i] as Dictionary
		var is_sel: bool = (i == _lb_selected_idx)
		var won: bool = bool(m.get("local_won", false))
		var cat_lbl: String = "MULTIPLAYER" if str(m.get("category", "solo")) == "local" else "SOLO"
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 62)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b_sb := StyleBoxFlat.new()
		if is_sel:
			b_sb.bg_color = Color(0.24, 0.18, 0.06, 0.96)
			b_sb.border_color = Color(1.0, 0.86, 0.24, 1.0)
			b_sb.set_border_width_all(2)
		else:
			b_sb.bg_color = Color(0.09, 0.12, 0.19, 0.90) if (i % 2 == 0) else Color(0.07, 0.10, 0.16, 0.90)
			b_sb.border_color = Color(1.0, 0.82, 0.26, 0.45) if won else Color(0.28, 0.34, 0.46, 0.50)
			b_sb.set_border_width_all(1)
		b_sb.set_corner_radius_all(8)
		b_sb.set_content_margin_all(8)
		btn.add_theme_stylebox_override("normal", b_sb)
		btn.add_theme_stylebox_override("hover", b_sb)
		btn.add_theme_stylebox_override("pressed", b_sb)
		btn.add_theme_color_override("font_color", Color(1.0, 0.90, 0.42) if is_sel else (Color(0.84, 0.96, 0.72) if won else Color(0.88, 0.90, 0.96)))
		if _lb_category == "top_kills":
			var rank_prefix: String = "🏆 #1" if i == 0 else ("#%d" % [i + 1])
			btn.text = "%s  [%s]  %d KILLS  •  Score: %d  (%s)\n%s  •  %s  •  %s" % [
				rank_prefix,
				cat_lbl,
				int(m.get("kills", 0)),
				int(m.get("score", 0)),
				"WIN" if won else "LOSS",
				str(m.get("mode", "Match")),
				str(m.get("map_name", "Arena")),
				str(m.get("timestamp", ""))
			]
		else:
			btn.text = "[%s]  %dK / %dD / %dA  •  Score: %d\n%s  •  %s  •  %s" % [
				"WIN" if won else "LOSS",
				int(m.get("kills", 0)),
				int(m.get("deaths", 0)),
				int(m.get("assists", 0)),
				int(m.get("score", 0)),
				str(m.get("mode", "Match")),
				str(m.get("map_name", "Arena")),
				str(m.get("timestamp", ""))
			]
		var cap_i: int = i
		btn.pressed.connect(func():
			_lb_selected_idx = cap_i
			_refresh_leaderboard_ui()
		)
		_lb_match_list_box.add_child(btn)

	# Selected Match Details — Win Screen Table Style
	var sel: Dictionary = matches[_lb_selected_idx] as Dictionary
	var sel_won: bool = bool(sel.get("local_won", false))
	var sel_cat_lbl: String = "MULTIPLAYER" if str(sel.get("category", "solo")) == "local" else "SOLO"

	var win_banner := PanelContainer.new()
	var wb_sb := StyleBoxFlat.new()
	wb_sb.bg_color = Color(0.22, 0.17, 0.06, 0.96) if sel_won else Color(0.18, 0.09, 0.10, 0.95)
	wb_sb.border_color = Color(1.0, 0.84, 0.24, 0.98) if sel_won else Color(0.95, 0.38, 0.34, 0.92)
	wb_sb.set_border_width_all(2)
	wb_sb.set_corner_radius_all(10)
	wb_sb.set_content_margin_all(10)
	win_banner.add_theme_stylebox_override("panel", wb_sb)
	_lb_detail_box.add_child(win_banner)

	var wb_lbl := Label.new()
	wb_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wb_lbl.text = "%s\n[%s]  %s  •  %s  •  %s" % [
		str(sel.get("winner", "MATCH COMPLETE")),
		sel_cat_lbl,
		str(sel.get("mode", "Match")),
		str(sel.get("map_name", "Arena")),
		str(sel.get("timestamp", ""))
	]
	wb_lbl.add_theme_font_size_override("font_size", 17)
	wb_lbl.modulate = Color(1.0, 0.86, 0.28) if sel_won else Color(1.0, 0.72, 0.68)
	win_banner.add_child(wb_lbl)

	# Scoreboard Table Header (exact Win Screen columns + SCORE)
	var hdr_panel := PanelContainer.new()
	var hdr_sb := StyleBoxFlat.new()
	hdr_sb.bg_color = Color(0.14, 0.12, 0.07, 0.96)
	hdr_sb.border_color = Color(1.0, 0.84, 0.24, 0.55)
	hdr_sb.set_border_width_all(1)
	hdr_sb.set_corner_radius_all(8)
	hdr_sb.set_content_margin_all(8)
	hdr_panel.add_theme_stylebox_override("panel", hdr_sb)
	_lb_detail_box.add_child(hdr_panel)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 6)
	hdr_panel.add_child(hdr_row)
	var col_specs: Array = [
		["RANK", 54, Color(1.0, 0.86, 0.34), HORIZONTAL_ALIGNMENT_CENTER],
		["PLAYER", 0, Color(0.92, 0.94, 0.98), HORIZONTAL_ALIGNMENT_LEFT],
		["KILLS", 54, Color(0.45, 0.96, 0.56), HORIZONTAL_ALIGNMENT_CENTER],
		["ASSISTS", 62, Color(0.42, 0.86, 1.0), HORIZONTAL_ALIGNMENT_CENTER],
		["DEATHS", 58, Color(1.0, 0.48, 0.46), HORIZONTAL_ALIGNMENT_CENTER],
		["COMBO", 58, Color(1.0, 0.84, 0.35), HORIZONTAL_ALIGNMENT_CENTER],
		["SCORE", 64, Color(1.0, 0.88, 0.28), HORIZONTAL_ALIGNMENT_CENTER]
	]
	for spec in col_specs:
		var h_lbl := Label.new()
		h_lbl.text = str(spec[0])
		if int(spec[1]) > 0:
			h_lbl.custom_minimum_size = Vector2(float(spec[1]), 0)
		else:
			h_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h_lbl.horizontal_alignment = spec[3]
		h_lbl.add_theme_font_size_override("font_size", 12)
		h_lbl.modulate = spec[2]
		hdr_row.add_child(h_lbl)

	var rows: Array = sel.get("rankings", []) as Array
	if rows.is_empty():
		var no_r := Label.new()
		no_r.text = "No player scoreboard data."
		no_r.modulate = Color(0.70, 0.76, 0.86)
		_lb_detail_box.add_child(no_r)
	else:
		for ri in range(rows.size()):
			var rd: Dictionary = rows[ri] as Dictionary
			var is_me: bool = bool(rd.get("is_me", false))
			var is_bot: bool = bool(rd.get("is_bot", false))
			var is_first: bool = (ri == 0)

			var row_p := PanelContainer.new()
			var r_sb := StyleBoxFlat.new()
			if is_first:
				r_sb.bg_color = Color(0.22, 0.17, 0.07, 0.94)
				r_sb.border_color = Color(1.0, 0.82, 0.26, 0.92)
				r_sb.set_border_width_all(2)
			elif is_me:
				r_sb.bg_color = Color(0.10, 0.19, 0.30, 0.94)
				r_sb.border_color = Color(0.35, 0.78, 1.0, 0.92)
				r_sb.set_border_width_all(2)
			else:
				r_sb.bg_color = Color(0.09, 0.13, 0.21, 0.90) if (ri % 2 == 0) else Color(0.07, 0.10, 0.17, 0.90)
				r_sb.border_color = Color(0.22, 0.28, 0.40, 0.45)
				r_sb.set_border_width_all(1)
			r_sb.set_corner_radius_all(8)
			r_sb.set_content_margin_all(7)
			row_p.add_theme_stylebox_override("panel", r_sb)
			_lb_detail_box.add_child(row_p)

			var row_hb := HBoxContainer.new()
			row_hb.add_theme_constant_override("separation", 6)
			row_p.add_child(row_hb)

			var rank_col: Color = Color(1.0, 0.86, 0.28) if is_first else (Color(0.84, 0.88, 0.96) if ri == 1 else (Color(0.88, 0.62, 0.38) if ri == 2 else Color(0.68, 0.74, 0.86)))
			var rank_txt: String = "🏆 #1" if is_first else ("#%d" % [ri + 1])
			var p_tag: String = " (YOU)" if is_me else (" [BOT]" if is_bot else "")
			var cells: Array = [
				[rank_txt, 54, rank_col, HORIZONTAL_ALIGNMENT_CENTER],
				[str(rd.get("name", "Player")) + p_tag, 0, Color(0.45, 0.90, 1.0) if is_me else Color(0.94, 0.96, 1.0), HORIZONTAL_ALIGNMENT_LEFT],
				[str(int(rd.get("kills", 0))), 54, Color(0.48, 0.98, 0.58), HORIZONTAL_ALIGNMENT_CENTER],
				[str(int(rd.get("assists", 0))), 62, Color(0.46, 0.88, 1.0), HORIZONTAL_ALIGNMENT_CENTER],
				[str(int(rd.get("deaths", 0))), 58, Color(1.0, 0.50, 0.48), HORIZONTAL_ALIGNMENT_CENTER],
				[str(int(rd.get("max_combo", 0))), 58, Color(1.0, 0.86, 0.38), HORIZONTAL_ALIGNMENT_CENTER],
				[str(int(rd.get("score", 0))), 64, Color(1.0, 0.90, 0.36), HORIZONTAL_ALIGNMENT_CENTER]
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
				c_lbl.add_theme_font_size_override("font_size", 14)
				c_lbl.modulate = cell[2]
				row_hb.add_child(c_lbl)

	# Head-to-head breakdown tables: Whom I Killed vs Who Killed Me
	var h2h_row := HBoxContainer.new()
	h2h_row.add_theme_constant_override("separation", 10)
	_lb_detail_box.add_child(h2h_row)

	_add_h2h_card(h2h_row, "WHOM I KILLED", "KILLS", sel.get("killed_by_me", {}) as Dictionary, Color(0.45, 0.96, 0.56))
	_add_h2h_card(h2h_row, "WHO KILLED ME", "DEATHS", sel.get("killed_me", {}) as Dictionary, Color(1.0, 0.48, 0.46))


func _add_h2h_card(parent_row: HBoxContainer, title_txt: String, count_col_txt: String, counts_dict: Dictionary, accent: Color) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.16, 0.95)
	sb.border_color = Color(1.0, 0.82, 0.26, 0.65)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", sb)
	parent_row.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	card.add_child(v)

	var hdr_p := PanelContainer.new()
	var h_sb := StyleBoxFlat.new()
	h_sb.bg_color = Color(0.14, 0.12, 0.07, 0.95)
	h_sb.set_corner_radius_all(6)
	h_sb.set_content_margin_all(6)
	hdr_p.add_theme_stylebox_override("panel", h_sb)
	v.add_child(hdr_p)

	var hdr_hb := HBoxContainer.new()
	hdr_p.add_child(hdr_hb)

	var hdr := Label.new()
	hdr.text = title_txt
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.modulate = Color(1.0, 0.84, 0.28)
	hdr_hb.add_child(hdr)

	var cnt_hdr := Label.new()
	cnt_hdr.text = count_col_txt
	cnt_hdr.custom_minimum_size = Vector2(56, 0)
	cnt_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt_hdr.add_theme_font_size_override("font_size", 12)
	cnt_hdr.modulate = accent
	hdr_hb.add_child(cnt_hdr)

	if counts_dict.is_empty():
		var none_l := Label.new()
		none_l.text = "None"
		none_l.add_theme_font_size_override("font_size", 13)
		none_l.modulate = Color(0.65, 0.72, 0.82)
		v.add_child(none_l)
		return

	var pairs: Array = []
	for k in counts_dict.keys():
		pairs.append({"name": str(k), "count": int(counts_dict[k])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["count"]) > int(b["count"])
	)
	for pi in range(pairs.size()):
		var p: Dictionary = pairs[pi] as Dictionary
		var row_p := PanelContainer.new()
		var r_sb := StyleBoxFlat.new()
		r_sb.bg_color = Color(0.09, 0.13, 0.21, 0.88) if (pi % 2 == 0) else Color(0.07, 0.10, 0.17, 0.88)
		r_sb.set_corner_radius_all(5)
		r_sb.set_content_margin_all(5)
		row_p.add_theme_stylebox_override("panel", r_sb)
		v.add_child(row_p)

		var row_hb := HBoxContainer.new()
		row_p.add_child(row_hb)

		var n_lbl := Label.new()
		n_lbl.text = str(p["name"])
		n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n_lbl.clip_text = true
		n_lbl.add_theme_font_size_override("font_size", 13)
		n_lbl.modulate = Color(0.92, 0.96, 1.0)
		row_hb.add_child(n_lbl)

		var c_lbl := Label.new()
		c_lbl.text = str(int(p["count"]))
		c_lbl.custom_minimum_size = Vector2(56, 0)
		c_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c_lbl.add_theme_font_size_override("font_size", 13)
		c_lbl.modulate = accent
		row_hb.add_child(c_lbl)
