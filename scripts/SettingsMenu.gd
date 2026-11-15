extends Control

const TEX_BG: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const SND_TEST_SFX: AudioStream = preload("res://assets/audio/shoot_rifle.wav")

var _tabs: TabContainer
var _listening_action: String = ""
var _keybind_buttons: Dictionary = {}
var _rebind_prompt_label: Label

var _layout_overlay: Control
var _drag_handles: Dictionary = {}
var _dragging_key: String = ""
var _test_sfx_player: AudioStreamPlayer


func _ready() -> void:
	_test_sfx_player = AudioStreamPlayer.new()
	_test_sfx_player.bus = "SFX"
	_test_sfx_player.stream = SND_TEST_SFX
	add_child(_test_sfx_player)
	_build_ui()


func _make_style(bg: Color, border: Color, corner: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _style_button(btn: Button, bg: Color, border: Color, corner: int = 10) -> void:
	btn.add_theme_stylebox_override("normal", _make_style(bg, border, corner))
	btn.add_theme_stylebox_override("hover", _make_style(bg.lightened(0.14), border.lightened(0.3), corner))
	btn.add_theme_stylebox_override("pressed", _make_style(border.darkened(0.4), border.lightened(0.45), corner))


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = TEX_BG
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 14)
	margin.add_child(root_v)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root_v.add_child(header)

	var menu_btn := Button.new()
	menu_btn.text = "< BACK TO MENU"
	menu_btn.custom_minimum_size = Vector2(180, 48)
	menu_btn.add_theme_font_size_override("font_size", 17)
	_style_button(menu_btn, Color(0.14, 0.18, 0.26, 0.95), Color(0.55, 0.72, 0.95))
	menu_btn.pressed.connect(func(): NetworkManager.go_to_main_menu())
	header.add_child(menu_btn)

	var title := Label.new()
	title.text = "GAME SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(1.0, 0.84, 0.28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Tabbed Settings Panel
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.94), Color(0.28, 0.62, 0.92, 0.85), 14))
	root_v.add_child(panel)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_tabs)

	_build_controls_tab()
	_build_audio_tab()
	_build_graphics_tab()
	_build_touch_layout_overlay()


func _build_controls_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Controls"
	_tabs.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	scroll.add_child(v)

	var touch_btn := Button.new()
	touch_btn.text = "CUSTOMIZE TOUCH CONTROLS"
	touch_btn.custom_minimum_size = Vector2(0, 54)
	touch_btn.add_theme_font_size_override("font_size", 18)
	_style_button(touch_btn, Color(0.28, 0.16, 0.06, 0.98), Color(0.98, 0.58, 0.16), 10)
	touch_btn.pressed.connect(_open_layout_editor)
	v.add_child(touch_btn)

	_add_slider_row(v, "Movement Stick Speed:", 0.4, 2.0, 0.05, SettingsManager.move_stick_sensitivity, "%.2fx", 1.0, func(val: float):
		SettingsManager.move_stick_sensitivity = val
		SettingsManager.apply_and_save()
	)

	_add_slider_row(v, "Aim Stick Speed:", 0.4, 2.0, 0.05, SettingsManager.aim_stick_sensitivity, "%.2fx", 1.0, func(val: float):
		SettingsManager.aim_stick_sensitivity = val
		SettingsManager.apply_and_save()
	)

	_add_toggle_row(v, "Invert Up/Down Aim:", SettingsManager.invert_y_axis, func(on: bool):
		SettingsManager.invert_y_axis = on
		SettingsManager.apply_and_save()
	)

	_add_toggle_row(v, "Target Aim Assist:", SettingsManager.auto_aim_assist, func(on: bool):
		SettingsManager.auto_aim_assist = on
		SettingsManager.apply_and_save()
	)

	v.add_child(HSeparator.new())

	_rebind_prompt_label = Label.new()
	_rebind_prompt_label.text = "KEYBOARD CONTROLS  (Tap any button to change key)"
	_rebind_prompt_label.modulate = Color(0.55, 0.88, 1.0)
	v.add_child(_rebind_prompt_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)

	for item in SettingsManager.REBINDABLE_ACTIONS:
		var act: String = str(item["action"])
		var lbl := Label.new()
		lbl.text = str(item["label"])
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(lbl)

		var kb_btn := Button.new()
		kb_btn.custom_minimum_size = Vector2(180, 42)
		_style_button(kb_btn, Color(0.10, 0.15, 0.24), Color(0.36, 0.54, 0.80), 8)
		kb_btn.text = SettingsManager.get_action_key_label(act)
		kb_btn.pressed.connect(_start_rebind.bind(act))
		grid.add_child(kb_btn)
		_keybind_buttons[act] = kb_btn


func _build_audio_tab() -> void:
	var v := VBoxContainer.new()
	v.name = "Audio"
	v.add_theme_constant_override("separation", 16)
	_tabs.add_child(v)

	_add_slider_row(v, "Master Volume:", 0.0, 1.0, 0.02, SettingsManager.master_volume, "%d%%", 100.0, func(val: float):
		SettingsManager.master_volume = val
		SettingsManager.apply_and_save()
	)

	_add_slider_row(v, "Sound Effects:", 0.0, 1.0, 0.02, SettingsManager.sfx_volume, "%d%%", 100.0, func(val: float):
		SettingsManager.sfx_volume = val
		SettingsManager.apply_and_save()
	)

	_add_slider_row(v, "Background Music:", 0.0, 1.0, 0.02, SettingsManager.music_volume, "%d%%", 100.0, func(val: float):
		SettingsManager.music_volume = val
		SettingsManager.apply_and_save()
	)

	var test_btn := Button.new()
	test_btn.text = "TEST SOUND"
	test_btn.custom_minimum_size = Vector2(220, 48)
	test_btn.add_theme_font_size_override("font_size", 17)
	_style_button(test_btn, Color(0.10, 0.22, 0.36), Color(0.28, 0.74, 1.0))
	test_btn.pressed.connect(func(): _test_sfx_player.play())
	v.add_child(test_btn)


func _build_graphics_tab() -> void:
	var v := VBoxContainer.new()
	v.name = "Graphics"
	v.add_theme_constant_override("separation", 14)
	_tabs.add_child(v)

	var res_row := HBoxContainer.new()
	v.add_child(res_row)
	var res_lbl := Label.new()
	res_lbl.text = "Window Resolution:"
	res_lbl.custom_minimum_size = Vector2(280, 0)
	res_row.add_child(res_lbl)

	var res_opt := OptionButton.new()
	for r in SettingsManager.RESOLUTIONS:
		res_opt.add_item("%d x %d" % [r.x, r.y])
	res_opt.selected = SettingsManager.resolution_index
	res_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_opt.item_selected.connect(func(idx: int):
		SettingsManager.resolution_index = idx
		SettingsManager.apply_and_save()
	)
	res_row.add_child(res_opt)

	_add_toggle_row(v, "Fullscreen Mode:", SettingsManager.fullscreen, func(on: bool):
		SettingsManager.fullscreen = on
		SettingsManager.apply_and_save()
	)

	_add_toggle_row(v, "V-Sync:", SettingsManager.vsync_enabled, func(on: bool):
		SettingsManager.vsync_enabled = on
		SettingsManager.apply_and_save()
	)

	var fps_row := HBoxContainer.new()
	v.add_child(fps_row)
	var fps_lbl := Label.new()
	fps_lbl.text = "Frame Rate Limiter:"
	fps_lbl.custom_minimum_size = Vector2(280, 0)
	fps_row.add_child(fps_lbl)

	var fps_opt := OptionButton.new()
	for lbl_str in SettingsManager.FPS_LABELS:
		fps_opt.add_item(lbl_str)
	fps_opt.selected = SettingsManager.fps_limit_mode
	fps_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_opt.item_selected.connect(func(idx: int):
		SettingsManager.fps_limit_mode = idx
		SettingsManager.apply_and_save()
	)
	fps_row.add_child(fps_opt)

	_add_slider_row(v, "Particle Effects Intensity:", 0.0, 1.5, 0.05, SettingsManager.particle_intensity, "%d%%", 100.0, func(val: float):
		SettingsManager.particle_intensity = val
		SettingsManager.apply_and_save()
	)

	_add_slider_row(v, "Screen Shake Intensity:", 0.0, 1.5, 0.05, SettingsManager.screen_shake_intensity, "%d%%", 100.0, func(val: float):
		SettingsManager.screen_shake_intensity = val
		SettingsManager.apply_and_save()
	)


func _add_slider_row(
	parent: VBoxContainer,
	title_txt: String,
	min_v: float,
	max_v: float,
	step_v: float,
	initial: float,
	fmt: String,
	display_scale: float,
	on_change: Callable
) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = title_txt
	lbl.custom_minimum_size = Vector2(280, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(72, 0)
	val_lbl.text = fmt % (initial * display_scale)
	row.add_child(val_lbl)

	slider.value_changed.connect(func(v: float):
		val_lbl.text = fmt % (v * display_scale)
		on_change.call(v)
	)


func _add_toggle_row(parent: VBoxContainer, title_txt: String, initial: bool, on_toggle: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = title_txt
	lbl.custom_minimum_size = Vector2(280, 0)
	row.add_child(lbl)

	var chk := CheckButton.new()
	chk.button_pressed = initial
	chk.text = "Enabled" if initial else "Disabled"
	chk.toggled.connect(func(on: bool):
		chk.text = "Enabled" if on else "Disabled"
		on_toggle.call(on)
	)
	row.add_child(chk)


func _start_rebind(action_name: String) -> void:
	_listening_action = action_name
	_rebind_prompt_label.text = "PRESS ANY KEY TO BIND '%s' (ESC TO CANCEL)" % action_name.to_upper()
	_rebind_prompt_label.modulate = Color(1.0, 0.72, 0.2)
	if _keybind_buttons.has(action_name):
		(_keybind_buttons[action_name] as Button).text = "[ Waiting for Key... ]"


func _input(event: InputEvent) -> void:
	if not _listening_action.is_empty() and event is InputEventKey:
		var kev := event as InputEventKey
		if kev.pressed and not kev.echo:
			var kc: int = int(kev.physical_keycode if kev.physical_keycode != KEY_NONE else kev.keycode)
			if kc != KEY_ESCAPE:
				SettingsManager.set_keybind(_listening_action, kc)
			if _keybind_buttons.has(_listening_action):
				(_keybind_buttons[_listening_action] as Button).text = SettingsManager.get_action_key_label(_listening_action)
			_listening_action = ""
			_rebind_prompt_label.text = "KEYBOARD CONTROLS  (Tap any button to change key)"
			_rebind_prompt_label.modulate = Color(0.55, 0.88, 1.0)
			get_viewport().set_input_as_handled()
		return

	if _layout_overlay.visible and not _dragging_key.is_empty():
		if event is InputEventMouseMotion:
			_move_handle(_dragging_key, (event as InputEventMouseMotion).position)
		elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
			_dragging_key = ""
		elif event is InputEventScreenDrag:
			_move_handle(_dragging_key, (event as InputEventScreenDrag).position)
		elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
			_dragging_key = ""


func _build_touch_layout_overlay() -> void:
	_layout_overlay = ColorRect.new()
	_layout_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layout_overlay.color = Color(0.03, 0.05, 0.08, 0.94)
	_layout_overlay.visible = false
	add_child(_layout_overlay)

	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.5
	top_bar.anchor_right = 0.5
	top_bar.offset_left = -350
	top_bar.offset_right = 350
	top_bar.offset_top = 18
	top_bar.offset_bottom = 70
	top_bar.add_theme_constant_override("separation", 12)
	_layout_overlay.add_child(top_bar)

	var info := Label.new()
	info.text = "Drag sticks and buttons where you want them:"
	info.add_theme_font_size_override("font_size", 16)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(info)

	var reset_btn := Button.new()
	reset_btn.text = "RESET"
	reset_btn.custom_minimum_size = Vector2(120, 48)
	reset_btn.add_theme_font_size_override("font_size", 16)
	_style_button(reset_btn, Color(0.24, 0.14, 0.14), Color(0.95, 0.42, 0.35), 10)
	reset_btn.pressed.connect(func():
		SettingsManager.reset_touch_layout()
		_position_layout_handles()
	)
	top_bar.add_child(reset_btn)

	var done_btn := Button.new()
	done_btn.text = "SAVE LAYOUT"
	done_btn.custom_minimum_size = Vector2(150, 48)
	done_btn.add_theme_font_size_override("font_size", 16)
	_style_button(done_btn, Color(0.09, 0.32, 0.16), Color(0.28, 0.92, 0.45), 10)
	done_btn.pressed.connect(func(): _layout_overlay.visible = false)
	top_bar.add_child(done_btn)

	var handle_specs: Array[Dictionary] = [
		{"key": "left_stick", "label": "MOVE", "size": Vector2(148, 148), "col": Color(0.25, 0.68, 1.0)},
		{"key": "right_stick", "label": "AIM & FIRE", "size": Vector2(148, 148), "col": Color(1.0, 0.48, 0.22)},
		{"key": "btn_reload", "label": "RELOAD", "size": Vector2(108, 48), "col": Color(0.68, 0.80, 0.98)},
		{"key": "btn_switch", "label": "SWAP GUN", "size": Vector2(108, 48), "col": Color(0.95, 0.76, 0.28)},
		{"key": "btn_dual", "label": "DUAL", "size": Vector2(108, 48), "col": Color(0.28, 0.92, 1.0)}
	]

	for spec in handle_specs:
		var key: String = str(spec["key"])
		var col: Color = spec["col"] as Color
		var btn := Button.new()
		btn.text = str(spec["label"])
		btn.custom_minimum_size = spec["size"]
		btn.size = spec["size"]
		btn.add_theme_font_size_override("font_size", 16)
		_style_button(btn, col.darkened(0.55), col, 24)
		btn.button_down.connect(func(): _dragging_key = key)
		btn.button_up.connect(func(): _dragging_key = "")
		_layout_overlay.add_child(btn)
		_drag_handles[key] = btn


func _open_layout_editor() -> void:
	_layout_overlay.visible = true
	_position_layout_handles()


func _position_layout_handles() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	for key in _drag_handles.keys():
		var ctrl: Control = _drag_handles[key] as Control
		ctrl.position = SettingsManager.get_touch_element_px(key, vp_size) - ctrl.size * 0.5


func _move_handle(key: String, screen_pos: Vector2) -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var norm := Vector2(screen_pos.x / maxf(1.0, vp_size.x), screen_pos.y / maxf(1.0, vp_size.y))
	SettingsManager.set_touch_element_pos(key, norm)
	var ctrl: Control = _drag_handles[key] as Control
	ctrl.position = SettingsManager.get_touch_element_px(key, vp_size) - ctrl.size * 0.5
