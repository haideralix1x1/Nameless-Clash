extends Control

signal closed

const UIStyle = preload("res://scripts/UIStyle.gd")
const TEX_BG: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const SND_TEST_SFX: AudioStream = preload("res://assets/audio/shoot_ak47.wav")

const GOLD_BORDER := Color(1.0, 0.84, 0.24, 0.98)
const GOLD_TEXT := Color(1.0, 0.88, 0.34)
const CARD_BG := Color(0.06, 0.09, 0.15, 0.98)
const HDR_BG := Color(0.11, 0.16, 0.26, 0.96)
const COL1_WIDTH: float = 245.0
const COL3_WIDTH: float = 132.0

var is_embedded_popup: bool = false

var _popup_card: PanelContainer
var _popup_tween: Tween
var _tab_buttons: Array[Button] = []
var _tab_pages: Array[Control] = []
var _active_tab_idx: int = 0
var _slider_knob_tex: Texture2D
var _slider_knob_hl_tex: Texture2D

var _layout_overlay: Control
var _drag_handles: Dictionary = {}
var _dragging_key: String = ""
var _drag_center_offset: Vector2 = Vector2.ZERO
var _layout_backup: Dictionary = {}
var _test_sfx_player: AudioStreamPlayer
var _audio_sync_callbacks: Array[Callable] = []
var _is_syncing_audio_ui: bool = false


func _ready() -> void:
	if not is_embedded_popup:
		SettingsManager.play_bgm("menu")
	_test_sfx_player = AudioStreamPlayer.new()
	_test_sfx_player.bus = "SFX"
	_test_sfx_player.stream = SND_TEST_SFX
	add_child(_test_sfx_player)
	_build_ui()
	if not SettingsManager.settings_changed.is_connected(_sync_audio_ui):
		SettingsManager.settings_changed.connect(_sync_audio_ui)


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


func _style_button(btn: Button, _bg: Color, border: Color, _corner: int = 10) -> void:
	var icon_name: String = "" if btn.icon != null else UIStyle.infer_icon_for_text(btn.text)
	UIStyle.style_layer_button(btn, _variant_for_color(border), icon_name, 14, 8)


func _make_win_card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.border_color = GOLD_BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(1.0, 0.82, 0.22, 0.38)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2.ZERO
	return sb


func _make_tab_stylebox(active: bool, hover: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if active:
		sb.bg_color = Color(0.24, 0.18, 0.06, 0.98)
		sb.border_color = GOLD_BORDER
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(0.12, 0.17, 0.27, 0.95) if hover else Color(0.09, 0.13, 0.21, 0.94)
		sb.border_color = Color(0.45, 0.60, 0.84, 0.82) if hover else Color(0.24, 0.34, 0.50, 0.72)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


func _get_slider_knob_tex(highlight: bool) -> Texture2D:
	if not highlight and _slider_knob_tex != null:
		return _slider_knob_tex
	if highlight and _slider_knob_hl_tex != null:
		return _slider_knob_hl_tex
	var sz: int = 22
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var center := Vector2(float(sz) * 0.5 - 0.5, float(sz) * 0.5 - 0.5)
	var outer_r: float = float(sz) * 0.5 - 1.0
	var inner_r: float = outer_r - 2.6
	var rim_col: Color = Color(1.0, 0.92, 0.45) if highlight else Color(1.0, 0.82, 0.22)
	var core_col: Color = Color(1.0, 0.98, 0.86) if highlight else Color(0.98, 0.92, 0.62)
	for y in range(sz):
		for x in range(sz):
			var d: float = Vector2(float(x), float(y)).distance_to(center)
			if d > outer_r + 0.8:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var a: float = clampf(outer_r + 0.5 - d, 0.0, 1.0)
				var base: Color = core_col if d < inner_r else rim_col
				base.a = a
				img.set_pixel(x, y, base)
	var tex := ImageTexture.create_from_image(img)
	if highlight:
		_slider_knob_hl_tex = tex
	else:
		_slider_knob_tex = tex
	return tex


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	if not is_embedded_popup:
		var bg := TextureRect.new()
		bg.texture = TEX_BG
		bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		bg.stretch_mode = TextureRect.STRETCH_TILE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.03, 0.06, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_close_popup()
	)
	add_child(shade)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)

	_popup_card = PanelContainer.new()
	_popup_card.custom_minimum_size = Vector2(780, 520)
	_popup_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_card.add_theme_stylebox_override("panel", _make_win_card_stylebox())
	cc.add_child(_popup_card)

	var card_v := VBoxContainer.new()
	card_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_v.add_theme_constant_override("separation", 10)
	_popup_card.add_child(card_v)

	# Popup Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	card_v.add_child(header)

	var hdr_spacer := Control.new()
	hdr_spacer.custom_minimum_size = Vector2(98, 0)
	header.add_child(hdr_spacer)

	var title := Label.new()
	title.text = "GAME SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UIStyle.FONT_MAIN)
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(1.0, 0.84, 0.24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(98, 38)
	close_btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(close_btn, "red", "", 14, 8)
	close_btn.pressed.connect(_close_popup)
	header.add_child(close_btn)

	# 2-Tab Bar (CONTROLS & AUDIO only)
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 10)
	card_v.add_child(tab_bar)

	var pages_host := Control.new()
	pages_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_v.add_child(pages_host)

	_tab_buttons.clear()
	_tab_pages.clear()
	var tab_specs: Array[Dictionary] = [
		{"title": "CONTROLS", "icon": "gear"},
		{"title": "AUDIO", "icon": "thunder"}
	]
	for idx in range(tab_specs.size()):
		var spec: Dictionary = tab_specs[idx]
		var tbtn := Button.new()
		tbtn.text = str(spec["title"])
		tbtn.icon = UIStyle.get_icon(str(spec["icon"]))
		tbtn.expand_icon = true
		tbtn.custom_minimum_size = Vector2(0, 42)
		tbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tbtn.focus_mode = Control.FOCUS_NONE
		tbtn.add_theme_font_override("font", UIStyle.FONT_MAIN)
		tbtn.add_theme_font_size_override("font_size", 15)
		tbtn.add_theme_constant_override("icon_max_width", 20)
		tbtn.add_theme_constant_override("h_separation", 8)
		tbtn.pressed.connect(_select_tab.bind(idx))
		tab_bar.add_child(tbtn)
		_tab_buttons.append(tbtn)

	_tab_pages.append(_build_controls_tab(pages_host))
	_tab_pages.append(_build_audio_tab(pages_host))

	_select_tab(0)
	_build_touch_layout_overlay()


func open_popup() -> void:
	_sync_audio_ui()
	_select_tab(0)
	visible = true
	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()
	_popup_card.pivot_offset = (_popup_card.size if _popup_card.size.x > 0.0 else _popup_card.custom_minimum_size) * 0.5
	_popup_card.scale = Vector2(0.92, 0.92)
	_popup_card.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_popup_card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_popup_card, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _close_popup() -> void:
	if _layout_overlay != null and _layout_overlay.visible:
		_cancel_layout_editor()
	if is_embedded_popup:
		visible = false
		closed.emit()
	else:
		NetworkManager.go_to_main_menu()


func _select_tab(idx: int) -> void:
	_active_tab_idx = clampi(idx, 0, maxi(0, _tab_pages.size() - 1))
	for i in range(_tab_pages.size()):
		_tab_pages[i].visible = (i == _active_tab_idx)
	for i in range(_tab_buttons.size()):
		var btn: Button = _tab_buttons[i]
		var is_act: bool = (i == _active_tab_idx)
		btn.add_theme_stylebox_override("normal", _make_tab_stylebox(is_act, false))
		btn.add_theme_stylebox_override("hover", _make_tab_stylebox(is_act, true))
		btn.add_theme_stylebox_override("pressed", _make_tab_stylebox(true, false))
		btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.42) if is_act else Color(0.76, 0.84, 0.96))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.56) if is_act else Color(0.92, 0.96, 1.0))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.96, 0.65))
		btn.add_theme_color_override("icon_normal_color", GOLD_TEXT if is_act else Color(0.72, 0.82, 0.96))
		btn.add_theme_color_override("icon_hover_color", Color(1.0, 0.94, 0.52) if is_act else Color.WHITE)


func _create_tab_table(pages_host: Control, col1: String, col2: String, col3: String) -> Dictionary:
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 8)
	pages_host.add_child(page)

	var hdr_panel := PanelContainer.new()
	var hdr_sb := StyleBoxFlat.new()
	hdr_sb.bg_color = HDR_BG
	hdr_sb.border_color = Color(1.0, 0.84, 0.24, 0.82)
	hdr_sb.border_width_bottom = 2
	hdr_sb.set_corner_radius_all(8)
	hdr_sb.content_margin_left = 12.0
	hdr_sb.content_margin_right = 12.0
	hdr_sb.content_margin_top = 7.0
	hdr_sb.content_margin_bottom = 7.0
	hdr_panel.add_theme_stylebox_override("panel", hdr_sb)
	page.add_child(hdr_panel)

	var hdr_row := HBoxContainer.new()
	hdr_row.add_theme_constant_override("separation", 12)
	hdr_panel.add_child(hdr_row)

	var h1 := Label.new()
	h1.text = col1
	h1.custom_minimum_size = Vector2(COL1_WIDTH, 0)
	h1.add_theme_font_size_override("font_size", 13)
	h1.modulate = Color(1.0, 0.86, 0.34)
	hdr_row.add_child(h1)

	var h2 := Label.new()
	h2.text = col2
	h2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h2.add_theme_font_size_override("font_size", 13)
	h2.modulate = Color(0.76, 0.84, 0.96)
	hdr_row.add_child(h2)

	var h3 := Label.new()
	h3.text = col3
	h3.custom_minimum_size = Vector2(COL3_WIDTH, 0)
	h3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h3.add_theme_font_size_override("font_size", 13)
	h3.modulate = Color(0.45, 0.96, 0.56)
	hdr_row.add_child(h3)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var rows_v := VBoxContainer.new()
	rows_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_v.add_theme_constant_override("separation", 6)
	rows_v.set_meta("row_idx", 0)
	scroll.add_child(rows_v)

	return {"page": page, "rows": rows_v}


func _make_table_row_panel(rows_v: VBoxContainer, highlight_gold: bool = false) -> HBoxContainer:
	var r_idx: int = int(rows_v.get_meta("row_idx", 0))
	rows_v.set_meta("row_idx", r_idx + 1)

	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 50)
	var r_sb := StyleBoxFlat.new()
	if highlight_gold:
		r_sb.bg_color = Color(0.20, 0.15, 0.06, 0.94)
		r_sb.border_color = Color(1.0, 0.82, 0.26, 0.92)
		r_sb.set_border_width_all(2)
	else:
		r_sb.bg_color = Color(0.09, 0.13, 0.21, 0.92) if (r_idx % 2 == 0) else Color(0.07, 0.10, 0.17, 0.92)
		r_sb.border_color = Color(0.24, 0.32, 0.46, 0.58)
		r_sb.set_border_width_all(1)
	r_sb.set_corner_radius_all(9)
	r_sb.content_margin_left = 12.0
	r_sb.content_margin_right = 12.0
	r_sb.content_margin_top = 6.0
	r_sb.content_margin_bottom = 6.0
	row_panel.add_theme_stylebox_override("panel", r_sb)
	rows_v.add_child(row_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	row_panel.add_child(hb)
	return hb


func _add_row_label_block(row_hb: HBoxContainer, title_txt: String, desc_txt: String, title_col: Color = Color(0.96, 0.98, 1.0)) -> void:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(COL1_WIDTH, 0)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	row_hb.add_child(vb)

	var lbl := Label.new()
	lbl.text = title_txt
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.modulate = title_col
	vb.add_child(lbl)

	if not desc_txt.is_empty():
		var dl := Label.new()
		dl.text = desc_txt
		dl.add_theme_font_size_override("font_size", 11)
		dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		dl.modulate = Color(0.64, 0.74, 0.88)
		vb.add_child(dl)


func _build_controls_tab(pages_host: Control) -> Control:
	var tbl := _create_tab_table(pages_host, "CONTROL SETTING", "ADJUSTMENT", "VALUE / STATUS")
	var v: VBoxContainer = tbl["rows"] as VBoxContainer

	_add_action_row(v, "Touch Controls Layout", "Drag sticks, fire, reload & ability buttons", "CUSTOMIZE TOUCH CONTROLS", "orange", _open_layout_editor)

	_add_slider_row(v, "Movement Stick Speed", "Left stick movement responsiveness", 0.4, 2.0, 0.05, SettingsManager.move_stick_sensitivity, "%.2fx", 1.0, func(val: float):
		SettingsManager.move_stick_sensitivity = val
		SettingsManager.apply_and_save()
	)

	_add_slider_row(v, "Aim Stick Speed", "Right stick aiming & fire speed", 0.4, 2.0, 0.05, SettingsManager.aim_stick_sensitivity, "%.2fx", 1.0, func(val: float):
		SettingsManager.aim_stick_sensitivity = val
		SettingsManager.apply_and_save()
	)

	_add_toggle_row(v, "Invert Up/Down Aim", "Flip vertical aiming axis", SettingsManager.invert_y_axis, func(on: bool):
		SettingsManager.invert_y_axis = on
		SettingsManager.apply_and_save()
	)

	_add_toggle_row(v, "Target Aim Assist", "Lock aim gently toward nearby foes", SettingsManager.auto_aim_assist, func(on: bool):
		SettingsManager.auto_aim_assist = on
		SettingsManager.apply_and_save()
	)
	return tbl["page"] as Control


func _build_audio_tab(pages_host: Control) -> Control:
	_audio_sync_callbacks.clear()
	var tbl := _create_tab_table(pages_host, "AUDIO CHANNEL", "LEVEL / STATE", "VALUE / STATUS")
	var v: VBoxContainer = tbl["rows"] as VBoxContainer

	var music_row := _add_toggle_row(v, "Music", "Menu trap music & battle themes", SettingsManager.music_enabled and not SettingsManager.master_muted, func(on: bool):
		SettingsManager.music_enabled = on
		if on:
			SettingsManager.master_muted = false
			if SettingsManager.master_volume <= 0.005:
				SettingsManager.master_volume = 0.85
			if SettingsManager.music_volume <= 0.005:
				SettingsManager.music_volume = 0.45
		SettingsManager.apply_and_save()
	)
	var m_btn: Button = music_row["button"] as Button
	var m_lbl: Label = music_row["state_label"] as Label
	_audio_sync_callbacks.append(func():
		var m_on: bool = SettingsManager.music_enabled and not SettingsManager.master_muted
		m_btn.set_pressed_no_signal(m_on)
		m_lbl.text = "Active" if m_on else "Disabled"
		m_lbl.modulate = Color(0.48, 0.94, 0.62) if m_on else Color(0.56, 0.64, 0.76)
		_style_toggle_pill(m_btn, m_on)
	)

	var sfx_row := _add_toggle_row(v, "Sound FX", "Gunfire, blasts, pickups & UI", SettingsManager.sfx_enabled and not SettingsManager.master_muted, func(on: bool):
		SettingsManager.sfx_enabled = on
		if on:
			SettingsManager.master_muted = false
			if SettingsManager.master_volume <= 0.005:
				SettingsManager.master_volume = 0.85
			if SettingsManager.sfx_volume <= 0.005:
				SettingsManager.sfx_volume = 0.85
		SettingsManager.apply_and_save()
	)
	var s_btn: Button = sfx_row["button"] as Button
	var s_lbl: Label = sfx_row["state_label"] as Label
	_audio_sync_callbacks.append(func():
		var s_on: bool = SettingsManager.sfx_enabled and not SettingsManager.master_muted
		s_btn.set_pressed_no_signal(s_on)
		s_lbl.text = "Active" if s_on else "Disabled"
		s_lbl.modulate = Color(0.48, 0.94, 0.62) if s_on else Color(0.56, 0.64, 0.76)
		_style_toggle_pill(s_btn, s_on)
	)

	var master_row := _add_slider_row(v, "Master Volume", "Global output across all audio", 0.0, 1.0, 0.02, SettingsManager.master_volume, "%d%%", 100.0, func(val: float):
		SettingsManager.master_volume = val
		if val > 0.005:
			SettingsManager.master_muted = false
		SettingsManager.apply_and_save()
	)
	var mv_sl: HSlider = master_row["slider"] as HSlider
	var mv_lbl: Label = master_row["value_label"] as Label
	_audio_sync_callbacks.append(func():
		mv_sl.set_value_no_signal(SettingsManager.master_volume)
		mv_lbl.text = "%d%%" % (SettingsManager.master_volume * 100.0)
	)

	var sfx_vol_row := _add_slider_row(v, "Sound Effects", "Weapon & explosion loudness", 0.0, 1.0, 0.02, SettingsManager.sfx_volume, "%d%%", 100.0, func(val: float):
		SettingsManager.sfx_volume = val
		if val > 0.005:
			SettingsManager.sfx_enabled = true
			SettingsManager.master_muted = false
		SettingsManager.apply_and_save()
	)
	var sv_sl: HSlider = sfx_vol_row["slider"] as HSlider
	var sv_lbl: Label = sfx_vol_row["value_label"] as Label
	_audio_sync_callbacks.append(func():
		sv_sl.set_value_no_signal(SettingsManager.sfx_volume)
		sv_lbl.text = "%d%%" % (SettingsManager.sfx_volume * 100.0)
	)

	var music_vol_row := _add_slider_row(v, "Background Music", "Menu & arena music loudness", 0.0, 1.0, 0.02, SettingsManager.music_volume, "%d%%", 100.0, func(val: float):
		SettingsManager.music_volume = val
		if val > 0.005:
			SettingsManager.music_enabled = true
			SettingsManager.master_muted = false
		SettingsManager.apply_and_save()
	)
	var muv_sl: HSlider = music_vol_row["slider"] as HSlider
	var muv_lbl: Label = music_vol_row["value_label"] as Label
	_audio_sync_callbacks.append(func():
		muv_sl.set_value_no_signal(SettingsManager.music_volume)
		muv_lbl.text = "%d%%" % (SettingsManager.music_volume * 100.0)
	)

	_add_action_row(v, "Audio Preview", "Play a sample shot on SFX bus", "TEST SOUND", "sky", func(): _test_sfx_player.play())
	return tbl["page"] as Control


func _sync_audio_ui() -> void:
	if _is_syncing_audio_ui:
		return
	_is_syncing_audio_ui = true
	for cb in _audio_sync_callbacks:
		if cb.is_valid():
			cb.call()
	_is_syncing_audio_ui = false


func _add_slider_row(
	parent: VBoxContainer,
	title_txt: String,
	desc_txt: String,
	min_v: float,
	max_v: float,
	step_v: float,
	initial: float,
	fmt: String,
	display_scale: float,
	on_change: Callable
) -> Dictionary:
	var row := _make_table_row_panel(parent, false)
	_add_row_label_block(row, title_txt, desc_txt)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = initial
	slider.custom_minimum_size = Vector2(0, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE

	var track_sb := StyleBoxFlat.new()
	track_sb.bg_color = Color(0.05, 0.08, 0.13, 0.98)
	track_sb.border_color = Color(0.24, 0.34, 0.50, 0.85)
	track_sb.set_border_width_all(1)
	track_sb.set_corner_radius_all(6)
	track_sb.content_margin_top = 5.0
	track_sb.content_margin_bottom = 5.0

	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = Color(0.94, 0.75, 0.18, 0.95)
	fill_sb.set_corner_radius_all(6)
	fill_sb.content_margin_top = 5.0
	fill_sb.content_margin_bottom = 5.0

	var fill_hl_sb := StyleBoxFlat.new()
	fill_hl_sb.bg_color = GOLD_BORDER
	fill_hl_sb.set_corner_radius_all(6)
	fill_hl_sb.content_margin_top = 5.0
	fill_hl_sb.content_margin_bottom = 5.0

	slider.add_theme_stylebox_override("slider", track_sb)
	slider.add_theme_stylebox_override("grabber_area", fill_sb)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hl_sb)
	slider.add_theme_icon_override("grabber", _get_slider_knob_tex(false))
	slider.add_theme_icon_override("grabber_highlight", _get_slider_knob_tex(true))
	row.add_child(slider)

	var val_pill := PanelContainer.new()
	val_pill.custom_minimum_size = Vector2(COL3_WIDTH, 34)
	val_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vsb := StyleBoxFlat.new()
	vsb.bg_color = Color(0.06, 0.09, 0.15, 0.96)
	vsb.border_color = Color(1.0, 0.82, 0.24, 0.65)
	vsb.set_border_width_all(1)
	vsb.set_corner_radius_all(8)
	val_pill.add_theme_stylebox_override("panel", vsb)
	row.add_child(val_pill)

	var val_lbl := Label.new()
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.modulate = GOLD_TEXT
	val_lbl.text = fmt % (initial * display_scale)
	val_pill.add_child(val_lbl)

	slider.value_changed.connect(func(v: float):
		val_lbl.text = fmt % (v * display_scale)
		on_change.call(v)
	)
	return {"slider": slider, "value_label": val_lbl}


func _style_toggle_pill(btn: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	if on:
		sb.bg_color = Color(0.09, 0.30, 0.16, 0.98)
		sb.border_color = Color(0.35, 0.96, 0.55, 0.98)
		btn.text = "ON"
		btn.icon = UIStyle.get_icon("check")
		btn.add_theme_color_override("font_color", Color(0.55, 1.0, 0.68))
		btn.add_theme_color_override("font_hover_color", Color(0.75, 1.0, 0.85))
		btn.add_theme_color_override("icon_normal_color", Color(0.55, 1.0, 0.68))
	else:
		sb.bg_color = Color(0.18, 0.10, 0.12, 0.96)
		sb.border_color = Color(0.76, 0.36, 0.38, 0.86)
		btn.text = "OFF"
		btn.icon = null
		btn.add_theme_color_override("font_color", Color(1.0, 0.58, 0.56))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.72, 0.70))
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	var sb_hl := sb.duplicate() as StyleBoxFlat
	sb_hl.bg_color = sb.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hl)
	btn.add_theme_stylebox_override("pressed", sb_hl)


func _add_toggle_row(parent: VBoxContainer, title_txt: String, desc_txt: String, initial: bool, on_toggle: Callable) -> Dictionary:
	var row := _make_table_row_panel(parent, false)
	_add_row_label_block(row, title_txt, desc_txt)

	var state_lbl := Label.new()
	state_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_lbl.add_theme_font_size_override("font_size", 13)
	state_lbl.text = "Active" if initial else "Disabled"
	state_lbl.modulate = Color(0.48, 0.94, 0.62) if initial else Color(0.56, 0.64, 0.76)
	row.add_child(state_lbl)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = initial
	btn.expand_icon = true
	btn.custom_minimum_size = Vector2(COL3_WIDTH, 36)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_constant_override("icon_max_width", 18)
	btn.add_theme_constant_override("h_separation", 8)
	_style_toggle_pill(btn, initial)
	btn.toggled.connect(func(on: bool):
		state_lbl.text = "Active" if on else "Disabled"
		state_lbl.modulate = Color(0.48, 0.94, 0.62) if on else Color(0.56, 0.64, 0.76)
		_style_toggle_pill(btn, on)
		on_toggle.call(on)
	)
	row.add_child(btn)
	return {"button": btn, "state_label": state_lbl}


func _add_action_row(parent: VBoxContainer, title_txt: String, desc_txt: String, btn_txt: String, variant: String, on_press: Callable) -> void:
	var row := _make_table_row_panel(parent, true)
	_add_row_label_block(row, title_txt, desc_txt, GOLD_TEXT)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var btn := Button.new()
	btn.text = btn_txt
	btn.custom_minimum_size = Vector2(236, 38)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	UIStyle.style_layer_button(btn, variant, UIStyle.infer_icon_for_text(btn_txt), 14, 8)
	btn.pressed.connect(on_press)
	row.add_child(btn)


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if _layout_overlay.visible:
		if event is InputEventKey:
			var kev := event as InputEventKey
			if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE:
				_cancel_layout_editor()
				get_viewport().set_input_as_handled()
				return
		if not _dragging_key.is_empty():
			if event is InputEventMouseMotion:
				_move_handle(_dragging_key, (event as InputEventMouseMotion).position - _drag_center_offset)
			elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
				_dragging_key = ""
			elif event is InputEventScreenDrag:
				_move_handle(_dragging_key, (event as InputEventScreenDrag).position - _drag_center_offset)
			elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
				_dragging_key = ""
		return

	if event is InputEventKey:
		var kev := event as InputEventKey
		if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE:
			_close_popup()
			get_viewport().set_input_as_handled()


func _build_touch_layout_overlay() -> void:
	_layout_overlay = ColorRect.new()
	_layout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout_overlay.color = Color(0.03, 0.05, 0.08, 0.94)
	_layout_overlay.visible = false
	_layout_overlay.z_index = 10
	add_child(_layout_overlay)

	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.5
	top_panel.anchor_right = 0.5
	top_panel.offset_left = -430
	top_panel.offset_right = 430
	top_panel.offset_top = 12
	top_panel.offset_bottom = 72
	var tp_sb := StyleBoxFlat.new()
	tp_sb.bg_color = CARD_BG
	tp_sb.border_color = GOLD_BORDER
	tp_sb.set_border_width_all(2)
	tp_sb.set_corner_radius_all(12)
	tp_sb.content_margin_left = 14.0
	tp_sb.content_margin_right = 14.0
	tp_sb.content_margin_top = 8.0
	tp_sb.content_margin_bottom = 8.0
	top_panel.add_theme_stylebox_override("panel", tp_sb)
	_layout_overlay.add_child(top_panel)

	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_bar)

	var info := Label.new()
	info.text = "Drag sticks & buttons where you want them:"
	info.add_theme_font_size_override("font_size", 15)
	info.modulate = GOLD_TEXT
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(info)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(128, 44)
	back_btn.add_theme_font_size_override("font_size", 15)
	_style_button(back_btn, Color(0.14, 0.18, 0.24), Color(0.62, 0.72, 0.86), 10)
	back_btn.pressed.connect(_cancel_layout_editor)
	top_bar.add_child(back_btn)

	var reset_btn := Button.new()
	reset_btn.text = "RESET"
	reset_btn.custom_minimum_size = Vector2(138, 44)
	reset_btn.add_theme_font_size_override("font_size", 15)
	_style_button(reset_btn, Color(0.24, 0.14, 0.14), Color(0.95, 0.42, 0.35), 10)
	reset_btn.pressed.connect(func():
		SettingsManager.reset_touch_layout()
		_position_layout_handles()
	)
	top_bar.add_child(reset_btn)

	var done_btn := Button.new()
	done_btn.text = "SAVE LAYOUT"
	done_btn.custom_minimum_size = Vector2(178, 44)
	done_btn.add_theme_font_size_override("font_size", 15)
	_style_button(done_btn, Color(0.09, 0.32, 0.16), Color(0.28, 0.92, 0.45), 10)
	done_btn.pressed.connect(func():
		_dragging_key = ""
		_layout_overlay.visible = false
	)
	top_bar.add_child(done_btn)

	var handle_specs: Array[Dictionary] = [
		{"key": "left_stick", "label": "MOVE\nSTICK", "size": Vector2(160, 160), "col": Color(0.25, 0.68, 1.0)},
		{"key": "right_stick", "label": "AIM &\nFIRE", "size": Vector2(160, 160), "col": Color(1.0, 0.48, 0.22)},
		{"key": "btn_reload", "label": "RELOAD", "size": Vector2(116, 48), "col": Color(0.68, 0.80, 0.98)},
		{"key": "btn_bomb", "label": "BOMB", "size": Vector2(116, 48), "col": Color(1.0, 0.56, 0.16)},
		{"key": "ability_bar", "label": "ABILITY BAR\n(Q / E / C / X)", "size": Vector2(360, 76), "col": Color(0.78, 0.48, 1.0)}
	]

	for spec in handle_specs:
		var key: String = str(spec["key"])
		var col: Color = spec["col"] as Color
		var btn := Button.new()
		btn.text = str(spec["label"])
		btn.custom_minimum_size = spec["size"]
		btn.size = spec["size"]
		btn.add_theme_font_size_override("font_size", 14)
		_style_button(btn, col.darkened(0.55), col, 24)
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
		_drag_handles[key] = btn


func _open_layout_editor() -> void:
	_dragging_key = ""
	_layout_backup = SettingsManager.touch_layout.duplicate(true)
	_layout_overlay.visible = true
	_position_layout_handles()


func _cancel_layout_editor() -> void:
	_dragging_key = ""
	SettingsManager.restore_touch_layout(_layout_backup)
	_layout_overlay.visible = false


func _clamp_handle_pos(center_px: Vector2, ctrl_size: Vector2, vp_size: Vector2) -> Vector2:
	return Vector2(
		clampf(center_px.x - ctrl_size.x * 0.5, 10.0, maxf(10.0, vp_size.x - ctrl_size.x - 10.0)),
		clampf(center_px.y - ctrl_size.y * 0.5, 10.0, maxf(10.0, vp_size.y - ctrl_size.y - 10.0))
	)


func _position_layout_handles() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	for key in _drag_handles.keys():
		var ctrl: Control = _drag_handles[key] as Control
		ctrl.position = _clamp_handle_pos(SettingsManager.get_touch_element_px(key, vp_size), ctrl.size, vp_size)


func _move_handle(key: String, center_screen_pos: Vector2) -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var ctrl: Control = _drag_handles[key] as Control
	var half_sz: Vector2 = ctrl.size * 0.5
	var clamped_center := Vector2(
		clampf(center_screen_pos.x, half_sz.x + 10.0, maxf(half_sz.x + 10.0, vp_size.x - half_sz.x - 10.0)),
		clampf(center_screen_pos.y, half_sz.y + 10.0, maxf(half_sz.y + 10.0, vp_size.y - half_sz.y - 10.0))
	)
	var norm := Vector2(clamped_center.x / maxf(1.0, vp_size.x), clamped_center.y / maxf(1.0, vp_size.y))
	SettingsManager.set_touch_element_pos(key, norm)
	ctrl.position = _clamp_handle_pos(SettingsManager.get_touch_element_px(key, vp_size), ctrl.size, vp_size)
