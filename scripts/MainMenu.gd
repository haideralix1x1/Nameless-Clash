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
var _shop_overlay: Control
var _shop_coin_lbl: Label
var _shop_gun_preview: TextureRect
var _shop_gun_title: Label
var _shop_skin_grid: GridContainer
var _shop_status_lbl: Label
var _shop_gun_btns: Dictionary = {}
var _shop_selected_weapon_id: int = 0
var _shop_preview_skin_key: String = ""
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
	_build_ui()
	_play_enter_animation()


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


func _make_arcade_button(text_str: String, accent: Color, min_h: float = 54.0, font_sz: int = 18, _fill_bg: Color = Color(0.11, 0.15, 0.22, 0.95)) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(0, min_h)
	var upper := text_str.to_upper()
	var icon_name := ""
	if upper.contains("SOLO") or upper.contains("BATTLE"):
		icon_name = "battle"
	elif upper.contains("AGENT"):
		icon_name = "thunder"
	elif upper.contains("WIFI") or upper.contains("HOST") or upper.contains("LOBBY"):
		icon_name = "wifi"
	elif upper.contains("CUSTOMIZE"):
		icon_name = "user"
	elif upper.contains("SETTINGS"):
		icon_name = "gear"
	elif upper.contains("CREDITS"):
		icon_name = "target"
	elif upper.contains("QUIT") or upper.contains("CLOSE"):
		icon_name = "close"
	UIStyle.style_layer_button(btn, _variant_for_color(accent), icon_name, 16, 10)
	btn.add_theme_font_size_override("font_size", font_sz)
	return btn


func _make_icon_card_button(title: String, icon_path: String, accent: Color, min_h: float = 132.0, font_sz: int = 20, _fill_bg: Color = Color(0.11, 0.15, 0.22, 0.95), icon_sz: int = 72) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, min_h)
	UIStyle.style_layer_button(btn, _variant_for_color(accent), "", 16, 10)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(vb)
	if ResourceLoader.exists(icon_path):
		var icon_rect := TextureRect.new()
		icon_rect.texture = load(icon_path)
		icon_rect.custom_minimum_size = Vector2(icon_sz, icon_sz)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(icon_rect)
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.modulate = Color(0.97, 0.98, 1.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lbl)
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
	econ_bar.add_theme_constant_override("separation", 12)
	_hub_container.add_child(econ_bar)

	var brand_lbl := Label.new()
	brand_lbl.text = "NAMELESS CLASH"
	brand_lbl.add_theme_font_size_override("font_size", 22)
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
	cp_sb.content_margin_left = 14
	cp_sb.content_margin_right = 14
	coin_pill.add_theme_stylebox_override("panel", cp_sb)
	econ_bar.add_child(coin_pill)

	_coin_pill_lbl = Label.new()
	_coin_pill_lbl.text = "COINS: %s" % ProfileManager.format_coins(ProfileManager.coins)
	_coin_pill_lbl.add_theme_font_size_override("font_size", 17)
	_coin_pill_lbl.modulate = Color(1.0, 0.88, 0.30)
	coin_pill.add_child(_coin_pill_lbl)
	ProfileManager.coins_changed.connect(func(new_c: int):
		var c_str: String = ProfileManager.format_coins(new_c)
		if is_instance_valid(_coin_pill_lbl):
			_coin_pill_lbl.text = "COINS: %s" % c_str
		if is_instance_valid(_shop_coin_lbl):
			_shop_coin_lbl.text = "COINS: %s" % c_str
	)

	var top_shop_btn := _make_arcade_button("GUN SKIN SHOP", Color(1.0, 0.82, 0.24), 40.0, 16, Color(0.24, 0.17, 0.05, 0.98))
	top_shop_btn.custom_minimum_size = Vector2(170, 40)
	top_shop_btn.pressed.connect(_open_gun_shop)
	econ_bar.add_child(top_shop_btn)

	# Main Split: Left (Your Soldier Showcase) + Right (Big Touch Battle Modes)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
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

	# Left Card: Your Soldier Showcase
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.88
	preview_panel.add_theme_stylebox_override("panel", win_panel_sb)
	split.add_child(preview_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	preview_panel.add_child(pv)

	var p_hdr := Label.new()
	p_hdr.text = "YOUR AGENT"
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

	var edit_avatar_btn := _make_arcade_button("CUSTOMIZE HERO", Color(0.86, 0.62, 0.24), 52.0, 16, Color(0.18, 0.14, 0.10, 0.96))
	edit_avatar_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_avatar_btn.pressed.connect(func(): _transition_to(NetworkManager.go_to_avatar_garage))
	hero_btn_row.add_child(edit_avatar_btn)

	var gun_shop_btn := _make_arcade_button("GUN SHOP", Color(1.0, 0.84, 0.26), 52.0, 16, Color(0.24, 0.18, 0.06, 0.96))
	gun_shop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gun_shop_btn.pressed.connect(_open_gun_shop)
	hero_btn_row.add_child(gun_shop_btn)

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

	var btn_agent := _make_icon_card_button("AGENT CLASH", "res://assets/ui/icons/icon_agent_clash.png", Color(0.30, 0.92, 0.48), 132.0, 20, Color(0.09, 0.28, 0.16, 0.98), 72)
	btn_agent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_agent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_agent.pressed.connect(func(): _open_agent_select(false))
	mode_grid.add_child(btn_agent)

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
	btn_settings.pressed.connect(func(): _transition_to(NetworkManager.go_to_settings))
	bottom_row.add_child(btn_settings)

	var btn_credits := _make_arcade_button("CREDITS", Color(0.95, 0.78, 0.25), 50.0, 17)
	btn_credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_credits.pressed.connect(_open_credits)
	bottom_row.add_child(btn_credits)

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
	card.custom_minimum_size = Vector2(540, 320)
	card.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.11, 0.18, 0.98), Color(0.98, 0.72, 0.22, 0.95), 14))
	cc.add_child(card)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 16)
	card.add_child(cv)

	var c_title := Label.new()
	c_title.text = "NAMELESS CLASH"
	c_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_title.add_theme_font_size_override("font_size", 28)
	c_title.modulate = Color(1.0, 0.82, 0.28)
	cv.add_child(c_title)

	var c_body := Label.new()
	c_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	c_body.add_theme_font_size_override("font_size", 16)
	c_body.text = (
		"Fast-Paced 2D Multiplayer Arena Combat!\n\n"
		+ "Play Solo against AI Bots or battle friends over Local Wi-Fi / Hotspot.\n\n"
		+ "Visit Hero & Armory to customize %d unique Heroes\n" % ProfileManager.ARCHETYPES.size()
		+ "and equip 11 real-world weapons."
	)
	cv.add_child(c_body)

	var close_btn := _make_arcade_button("CLOSE", Color(0.98, 0.56, 0.14), 52.0, 18)
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
				var sfx := AudioStreamPlayer.new()
				sfx.stream = load("res://assets/audio/pickup.wav") as AudioStream
				sfx.bus = &"SFX"
				sfx.finished.connect(sfx.queue_free)
				add_child(sfx)
				sfx.play()
				if is_instance_valid(_coin_pill_lbl):
					_coin_pill_lbl.text = "COINS: %s" % ProfileManager.format_coins(ProfileManager.coins)
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
			lock_tag = "  (FREE IN PRACTICE)" if _agent_select_for_practice else ("  (%s COINS)" % ProfileManager.format_coins(unlock_price))
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
			_agent_play_btn.disabled = false
			_agent_play_btn.modulate = Color.WHITE
		elif is_sel_unlocked:
			_agent_play_btn.text = "CONTINUE"
			_agent_play_btn.disabled = false
			_agent_play_btn.modulate = Color.WHITE
		else:
			var can_afford: bool = ProfileManager.coins >= unlock_price
			_agent_play_btn.text = "UNLOCK (%s COINS)" % ProfileManager.format_coins(unlock_price)
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
			card.text = "  %s\n  %s COINS" % [str(c_ag["agent_name"]), ProfileManager.format_coins(unlock_price)]
		var lock_node: Node = card.get_node_or_null("LockIcon")
		if lock_node is Control:
			(lock_node as Control).visible = not playable_now
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
	for wi in range(WeaponData.get_weapon_count()):
		var wd: WeaponData = WeaponData.get_weapon(wi)
		pop.add_check_item(wd.display_name, wi)
		pop.set_item_checked(wi, NetworkManager.restricted_weapons.has(wi))
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
	title.text = "GUN SKIN SHOP  •  EARN COINS FROM KILLS (+25), TREASURE (+15) & WINS (+100)"
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color(1.0, 0.86, 0.28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(title)

	_shop_coin_lbl = Label.new()
	_shop_coin_lbl.text = "COINS: %s" % ProfileManager.format_coins(ProfileManager.coins)
	_shop_coin_lbl.add_theme_font_size_override("font_size", 19)
	_shop_coin_lbl.modulate = Color(1.0, 0.90, 0.30)
	hdr.add_child(_shop_coin_lbl)

	var close_btn := _make_arcade_button("CLOSE", Color(0.92, 0.34, 0.34), 38.0, 15, Color(0.26, 0.08, 0.10, 0.96))
	close_btn.custom_minimum_size = Vector2(105, 38)
	close_btn.pressed.connect(func():
		_shop_overlay.visible = false
		_hub_container.visible = true
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
	for wid in ProfileManager.SHOP_WEAPON_IDS:
		var wd := WeaponData.get_weapon(wid, 0, 0)
		var gbtn := Button.new()
		gbtn.custom_minimum_size = Vector2(0, 44)
		gbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gbtn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		gbtn.text = "  %s" % wd.display_name
		gbtn.icon = WeaponData.get_weapon_atlas_texture(wid, 0)
		gbtn.expand_icon = true
		gbtn.add_theme_font_size_override("font_size", 15)
		gbtn.pressed.connect(func(): _select_shop_weapon(wid))
		left_vb.add_child(gbtn)
		_shop_gun_btns[wid] = gbtn

	var right_v := VBoxContainer.new()
	right_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_v.add_theme_constant_override("separation", 10)
	body_h.add_child(right_v)

	# Preview Box
	var prev_panel := PanelContainer.new()
	prev_panel.custom_minimum_size = Vector2(0, 150)
	var prev_sb := StyleBoxFlat.new()
	prev_sb.bg_color = Color(0.08, 0.12, 0.20, 0.96)
	prev_sb.border_color = Color(0.28, 0.56, 0.92, 0.85)
	prev_sb.set_border_width_all(2)
	prev_sb.set_corner_radius_all(12)
	prev_sb.set_content_margin_all(10)
	prev_panel.add_theme_stylebox_override("panel", prev_sb)
	right_v.add_child(prev_panel)

	var prev_vb := VBoxContainer.new()
	prev_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	prev_panel.add_child(prev_vb)

	_shop_gun_title = Label.new()
	_shop_gun_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_gun_title.add_theme_font_size_override("font_size", 17)
	_shop_gun_title.modulate = Color(0.95, 0.97, 1.0)
	prev_vb.add_child(_shop_gun_title)

	_shop_gun_preview = TextureRect.new()
	_shop_gun_preview.custom_minimum_size = Vector2(280, 100)
	_shop_gun_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shop_gun_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_vb.add_child(_shop_gun_preview)

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
		_shop_coin_lbl.text = "COINS: %s" % ProfileManager.format_coins(ProfileManager.coins)
	_select_shop_weapon(_shop_selected_weapon_id)


func _select_shop_weapon(wid: int) -> void:
	_shop_selected_weapon_id = wid
	_shop_preview_skin_key = ProfileManager.get_equipped_gun_skin(wid)
	for k in _shop_gun_btns:
		var b: Button = _shop_gun_btns[k] as Button
		b.modulate = Color(1.0, 0.88, 0.34) if int(k) == wid else Color(0.84, 0.88, 0.96)
	_refresh_shop_skins()


func _refresh_shop_skins() -> void:
	if not is_instance_valid(_shop_skin_grid):
		return
	var wid: int = _shop_selected_weapon_id
	var wd := WeaponData.get_weapon(wid, 0, 0)
	var eq_key: String = ProfileManager.get_equipped_gun_skin(wid)
	var prev_key: String = _shop_preview_skin_key if not _shop_preview_skin_key.is_empty() else eq_key
	var prev_def: Dictionary = ProfileManager.get_gun_skin_def(prev_key)
	var state_tag: String = "Equipped" if prev_key == eq_key else "Preview"
	_shop_gun_title.text = "%s  —  %s: %s" % [wd.display_name, state_tag, str(prev_def["name"])]
	_shop_gun_preview.texture = WeaponData.get_weapon_atlas_texture(wid, int(prev_def.get("sheet_row", 0)))
	_shop_gun_preview.modulate = ProfileManager.get_gun_skin_tint(wid, prev_key)
	if is_instance_valid(_shop_coin_lbl):
		_shop_coin_lbl.text = "COINS: %s" % ProfileManager.format_coins(ProfileManager.coins)
	if is_instance_valid(_coin_pill_lbl):
		_coin_pill_lbl.text = "COINS: %s" % ProfileManager.format_coins(ProfileManager.coins)

	for c in _shop_skin_grid.get_children():
		c.queue_free()

	for sdef in ProfileManager.GUN_SKIN_CATALOG:
		var skey: String = str(sdef["key"])
		var sname: String = str(sdef["name"])
		var price: int = ProfileManager.get_gun_skin_price(wid, skey)
		var tint: Color = ProfileManager.get_gun_skin_tint(wid, skey)
		var badge: Color = sdef["badge"] as Color
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

		var nl := Label.new()
		nl.text = sname
		nl.add_theme_font_size_override("font_size", 14)
		nl.modulate = badge.lightened(0.25)
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		info_v.add_child(nl)

		var pl := Label.new()
		pl.text = "EQUIPPED" if equipped else ("OWNED" if owned else ("%s COINS" % ProfileManager.format_coins(price)))
		pl.add_theme_font_size_override("font_size", 12)
		pl.modulate = Color(0.35, 0.96, 0.55) if equipped else (Color(0.75, 0.85, 0.96) if owned else Color(1.0, 0.84, 0.28))
		pl.mouse_filter = Control.MOUSE_FILTER_PASS
		info_v.add_child(pl)

		var act_btn := Button.new()
		act_btn.custom_minimum_size = Vector2(86, 36)
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
		else:
			act_btn.text = "BUY"
			act_btn.disabled = ProfileManager.coins < price
			act_btn.modulate = Color(1.0, 0.86, 0.28) if ProfileManager.coins >= price else Color(0.55, 0.58, 0.65)
			act_btn.pressed.connect(func():
				if ProfileManager.buy_gun_skin(wid, skey):
					_shop_preview_skin_key = skey
					_shop_status_lbl.text = "Purchased & equipped %s for %s coins!" % [sname, ProfileManager.format_coins(price)]
					_shop_status_lbl.modulate = Color(0.45, 1.0, 0.65)
					var sfx := AudioStreamPlayer.new()
					sfx.stream = load("res://assets/audio/pickup.wav") as AudioStream
					sfx.bus = &"SFX"
					sfx.finished.connect(sfx.queue_free)
					add_child(sfx)
					sfx.play()
					_refresh_shop_skins()
				else:
					_shop_status_lbl.text = "Not enough coins! Need %s coins." % ProfileManager.format_coins(price)
					_shop_status_lbl.modulate = Color(1.0, 0.42, 0.35)
			)
		row.add_child(act_btn)
