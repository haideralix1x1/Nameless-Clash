extends Control

const UIStyle = preload("res://scripts/UIStyle.gd")
const TEX_BG: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")

const TAB_NAMES: Array[String] = ["CHARACTERS", "OUTFIT", "COLORS"]
const GEAR_SPECS: Array[Dictionary] = [
	{"label": "Helmet / Hat", "prop": "head_id", "removable": true},
	{"label": "Back Accessory", "prop": "accessories_id", "removable": true},
	{"label": "Facial Accessory", "prop": "face_acc_id", "removable": true},
	{"label": "Armor / Shirt", "prop": "torso_id", "removable": false},
	{"label": "Pants / Boots", "prop": "legs_id", "removable": false},
	{"label": "Gloves", "prop": "hands_id", "removable": false},
	{"label": "Face / Head", "prop": "skin_id", "removable": false}
]
const COLOR_CHANNELS: Array[Dictionary] = [
	{"label": "SHIRT", "prop": "shirt_color"},
	{"label": "PANTS", "prop": "pants_color"},
	{"label": "HELMET", "prop": "helmet_color"},
	{"label": "GEAR", "prop": "gear_color"},
	{"label": "SKIN", "prop": "skin_color"}
]

var _preview: SoldierPreview
var _name_input: LineEdit
var _dummy_name_label: Label
var _dummy_role_label: Label

var _tab_buttons: Array[Button] = []
var _tab_pages: Array[Control] = []
var _active_tab: int = 0

var _pose_buttons: Array[Button] = []
var _dummy_cards: Array[Button] = []
var _layer_labels: Dictionary = {}
var _accessory_toggle_btns: Dictionary = {}
var _slot_new_badges: Dictionary = {}
var _last_equipped_parts: Dictionary = {"head_id": 3, "accessories_id": 3, "face_acc_id": 0}

var _active_color_prop: String = "shirt_color"
var _channel_buttons: Dictionary = {}
var _custom_color_btn: ColorPickerButton


func _ready() -> void:
	if not ProfileManager.is_using_custom_dummy():
		ProfileManager.apply_dummy_preset(ProfileManager.dummy_id, true)
	var cur_dm: Dictionary = ProfileManager.CUSTOM_DUMMIES[clampi(ProfileManager.dummy_id, 0, ProfileManager.CUSTOM_DUMMIES.size() - 1)]
	var def_pid: int = int(cur_dm.get("part_id", 3))
	_last_equipped_parts["head_id"] = ProfileManager.head_id if ProfileManager.head_id >= 0 else int(cur_dm.get("head_id", def_pid))
	_last_equipped_parts["accessories_id"] = ProfileManager.accessories_id if ProfileManager.accessories_id >= 0 else int(cur_dm.get("accessories_id", def_pid))
	_last_equipped_parts["face_acc_id"] = ProfileManager.face_acc_id if ProfileManager.face_acc_id >= 0 else 0
	_build_ui()
	_select_tab(0)
	_select_color_channel("shirt_color")
	_refresh_ui()


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


func _make_style(bg: Color, border: Color, _corner: int = 12, margin_h: int = 14, margin_v: int = 10) -> StyleBox:
	var variant: String = _variant_for_color(border)
	if variant == "yellow" or variant == "red":
		variant = "orange"
	elif variant == "sky":
		variant = "blue"
	var tint := Color(maxf(bg.r + 0.14, 0.20), maxf(bg.g + 0.14, 0.22), maxf(bg.b + 0.14, 0.28), maxf(bg.a, 0.94))
	return UIStyle.make_card_stylebox(variant, tint, margin_h, margin_v)


func _style_button(btn: Button, base_bg: Color, accent: Color, _corner: int = 10) -> void:
	if btn.text.is_empty():
		var tex: Texture2D = UIStyle.BTN_TEXTURES["gray"] as Texture2D
		btn.add_theme_stylebox_override("normal", UIStyle.make_button_stylebox(tex, base_bg, 10, 8))
		btn.add_theme_stylebox_override("hover", UIStyle.make_button_stylebox(tex, base_bg.lightened(0.14), 10, 8))
		btn.add_theme_stylebox_override("pressed", UIStyle.make_button_stylebox(tex, base_bg.darkened(0.22), 10, 8))
		return
	var icon_name: String = "" if btn.icon != null else UIStyle.infer_icon_for_text(btn.text)
	UIStyle.style_layer_button(btn, _variant_for_color(accent), icon_name, 12, 8)


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = TEX_BG
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	margin.add_child(root_v)

	# Top Navigation Bar
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	root_v.add_child(top_bar)

	var menu_btn := Button.new()
	menu_btn.text = "< MENU"
	menu_btn.custom_minimum_size = Vector2(158, 50)
	menu_btn.add_theme_font_size_override("font_size", 18)
	_style_button(menu_btn, Color(0.14, 0.18, 0.26, 0.95), Color(0.55, 0.72, 0.95))
	menu_btn.pressed.connect(func(): NetworkManager.go_to_main_menu())
	top_bar.add_child(menu_btn)

	var title := Label.new()
	title.text = "CHARACTER CUSTOMIZATION"
	title.add_theme_font_size_override("font_size", 25)
	title.modulate = Color(1.0, 0.84, 0.28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	var name_lbl := Label.new()
	name_lbl.text = "NAME"
	name_lbl.modulate = Color(0.72, 0.88, 1.0)
	name_lbl.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.text = ProfileManager.player_name
	_name_input.placeholder_text = "Your Name"
	_name_input.custom_minimum_size = Vector2(180, 44)
	_name_input.add_theme_font_size_override("font_size", 17)
	_name_input.text_changed.connect(_on_name_changed)
	top_bar.add_child(_name_input)

	var lobby_btn := Button.new()
	lobby_btn.text = "WIFI LOBBY"
	lobby_btn.custom_minimum_size = Vector2(182, 50)
	lobby_btn.add_theme_font_size_override("font_size", 17)
	_style_button(lobby_btn, Color(0.10, 0.22, 0.36, 0.95), Color(0.28, 0.72, 1.0))
	lobby_btn.pressed.connect(func(): NetworkManager.go_to_lobby())
	top_bar.add_child(lobby_btn)

	var play_btn := Button.new()
	play_btn.text = "GUNFIGHT"
	play_btn.custom_minimum_size = Vector2(184, 50)
	play_btn.add_theme_font_size_override("font_size", 17)
	_style_button(play_btn, Color(0.10, 0.34, 0.18, 0.98), Color(0.28, 0.92, 0.45))
	play_btn.pressed.connect(func():
		NetworkManager.disconnect_network()
		NetworkManager.test_mode_enabled = false
		NetworkManager.match_mode = 0
		NetworkManager.go_to_arena()
	)
	top_bar.add_child(play_btn)

	# Main 2-Pane Split: Character Stage (Left) + Tabbed Customization Deck (Right)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root_v.add_child(split)

	_build_character_stage(split)
	_build_customization_deck(split)


func _build_character_stage(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.62
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.95), Color(0.98, 0.58, 0.16, 0.92), 14, 16, 14))
	parent.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	_dummy_name_label = Label.new()
	_dummy_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dummy_name_label.add_theme_font_size_override("font_size", 22)
	_dummy_name_label.modulate = Color(1.0, 0.85, 0.30)
	v.add_child(_dummy_name_label)

	_dummy_role_label = Label.new()
	_dummy_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dummy_role_label.add_theme_font_size_override("font_size", 14)
	_dummy_role_label.modulate = Color(0.68, 0.88, 1.0)
	v.add_child(_dummy_role_label)

	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 165)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", _make_style(Color(0.03, 0.05, 0.09, 0.96), Color(0.22, 0.36, 0.56, 0.7), 12, 4, 4))
	v.add_child(stage)

	var anchor_wrap := Control.new()
	stage.add_child(anchor_wrap)

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER)
	anchor_wrap.add_child(anchor)

	_preview = SoldierPreview.new()
	_preview.hide_weapons = true
	_preview.scale = Vector2(4.6, 4.6)
	anchor.add_child(_preview)

	# Pose Selector Buttons
	var pose_row := HBoxContainer.new()
	pose_row.add_theme_constant_override("separation", 8)
	v.add_child(pose_row)

	_pose_buttons.clear()
	var poses: Array[String] = ["IDLE", "RUN", "FLY"]
	for i in range(poses.size()):
		var pb := Button.new()
		pb.text = poses[i]
		pb.custom_minimum_size = Vector2(0, 44)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.add_theme_font_size_override("font_size", 15)
		pb.pressed.connect(_on_pose_pressed.bind(i))
		pose_row.add_child(pb)
		_pose_buttons.append(pb)

	var rand_btn := Button.new()
	rand_btn.text = "RANDOMIZE LOOK"
	rand_btn.custom_minimum_size = Vector2(0, 48)
	rand_btn.add_theme_font_size_override("font_size", 17)
	_style_button(rand_btn, Color(0.24, 0.14, 0.38, 0.96), Color(0.82, 0.48, 1.0))
	rand_btn.pressed.connect(_on_randomize_pressed)
	v.add_child(rand_btn)


func _build_customization_deck(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.95), Color(0.26, 0.62, 0.95, 0.9), 14, 16, 14))
	parent.add_child(panel)

	var deck_v := VBoxContainer.new()
	deck_v.add_theme_constant_override("separation", 12)
	panel.add_child(deck_v)

	# 3 Category Tabs: CHARACTERS | OUTFIT | COLORS
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 8)
	deck_v.add_child(tab_bar)

	_tab_buttons.clear()
	for i in range(TAB_NAMES.size()):
		var tb := Button.new()
		tb.text = TAB_NAMES[i]
		tb.custom_minimum_size = Vector2(0, 50)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.add_theme_font_size_override("font_size", 18)
		tb.pressed.connect(_select_tab.bind(i))
		tab_bar.add_child(tb)
		_tab_buttons.append(tb)

	_tab_pages.clear()
	_tab_pages.append(_build_characters_tab(deck_v))
	_tab_pages.append(_build_outfit_tab(deck_v))
	_tab_pages.append(_build_colors_tab(deck_v))


func _build_characters_tab(parent: VBoxContainer) -> Control:
	var root_v := VBoxContainer.new()
	root_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.add_theme_constant_override("separation", 10)
	parent.add_child(root_v)

	var hint := Label.new()
	hint.text = "Select one of %d customizable characters. Modify accessories, outfit & colors in the tabs above." % ProfileManager.CUSTOM_DUMMIES.size()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.72, 0.88, 1.0)
	hint.add_theme_font_size_override("font_size", 15)
	root_v.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_v.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)

	_dummy_cards.clear()
	for i in range(ProfileManager.CUSTOM_DUMMIES.size()):
		var dm: Dictionary = ProfileManager.CUSTOM_DUMMIES[i]
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(0, 74)
		cb.clip_text = true
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cb.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cb.icon = _make_dummy_icon(i)
		cb.add_theme_font_size_override("font_size", 16)
		cb.set_meta("dummy_idx", i)
		cb.text = "  %s\n  %s" % [str(dm["name"]), str(dm["role"])]
		cb.pressed.connect(_on_dummy_card_pressed.bind(i))
		grid.add_child(cb)
		_dummy_cards.append(cb)

	var footer := Label.new()
	footer.text = "More customizable characters will be added here."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.modulate = Color(0.62, 0.74, 0.88)
	footer.add_theme_font_size_override("font_size", 14)
	root_v.add_child(footer)

	return root_v


func _build_outfit_tab(parent: VBoxContainer) -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	var hint := Label.new()
	hint.text = "Mix outfit parts and add or remove accessories anytime."
	hint.modulate = Color(0.72, 0.88, 1.0)
	hint.add_theme_font_size_override("font_size", 15)
	v.add_child(hint)

	_layer_labels.clear()
	_accessory_toggle_btns.clear()
	_slot_new_badges.clear()
	for spec in GEAR_SPECS:
		var prop: String = str(spec["prop"])
		var removable: bool = bool(spec.get("removable", false))
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_style(Color(0.09, 0.13, 0.20, 0.92), Color(0.24, 0.42, 0.68, 0.8), 10, 12, 8))
		v.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var lbl_wrap := HBoxContainer.new()
		lbl_wrap.custom_minimum_size = Vector2(172, 0)
		lbl_wrap.add_theme_constant_override("separation", 6)
		lbl_wrap.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_child(lbl_wrap)

		var lbl := Label.new()
		lbl.text = str(spec["label"])
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lbl.add_theme_font_size_override("font_size", 16)
		lbl_wrap.add_child(lbl)

		var slot_nb: PanelContainer = UIStyle.make_inline_new_badge("NEW", 10)
		slot_nb.visible = false
		lbl_wrap.add_child(slot_nb)
		_slot_new_badges[prop] = slot_nb

		var prev_btn := Button.new()
		prev_btn.text = "<"
		prev_btn.custom_minimum_size = Vector2(56, 46)
		prev_btn.add_theme_font_size_override("font_size", 18)
		_style_button(prev_btn, Color(0.14, 0.20, 0.30), Color(0.45, 0.72, 0.98))
		prev_btn.pressed.connect(_step_layer.bind(prop, -1))
		row.add_child(prev_btn)

		var val_lbl := Label.new()
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.add_theme_font_size_override("font_size", 17)
		val_lbl.modulate = Color(1.0, 0.9, 0.48)
		row.add_child(val_lbl)
		_layer_labels[prop] = val_lbl

		var next_btn := Button.new()
		next_btn.text = ">"
		next_btn.custom_minimum_size = Vector2(56, 46)
		next_btn.add_theme_font_size_override("font_size", 18)
		_style_button(next_btn, Color(0.14, 0.20, 0.30), Color(0.45, 0.72, 0.98))
		next_btn.pressed.connect(_step_layer.bind(prop, 1))
		row.add_child(next_btn)

		if removable:
			var tog_btn := Button.new()
			tog_btn.text = "REMOVE"
			tog_btn.custom_minimum_size = Vector2(106, 46)
			tog_btn.add_theme_font_size_override("font_size", 14)
			tog_btn.pressed.connect(_on_toggle_accessory.bind(prop))
			row.add_child(tog_btn)
			_accessory_toggle_btns[prop] = tog_btn

	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 10)
	v.add_child(quick_row)

	var strip_btn := Button.new()
	strip_btn.text = "REMOVE ALL ACCESSORIES"
	strip_btn.custom_minimum_size = Vector2(0, 46)
	strip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_btn.add_theme_font_size_override("font_size", 15)
	_style_button(strip_btn, Color(0.28, 0.12, 0.12), Color(0.95, 0.42, 0.36), 8)
	strip_btn.pressed.connect(_on_remove_all_accessories)
	quick_row.add_child(strip_btn)

	var reset_btn := Button.new()
	reset_btn.text = "RESET CHARACTER"
	reset_btn.custom_minimum_size = Vector2(0, 46)
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.add_theme_font_size_override("font_size", 15)
	_style_button(reset_btn, Color(0.12, 0.24, 0.34), Color(0.35, 0.78, 1.0), 8)
	reset_btn.pressed.connect(_on_reset_dummy_pressed)
	quick_row.add_child(reset_btn)

	return scroll


func _build_colors_tab(parent: VBoxContainer) -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	var theme_hdr := Label.new()
	theme_hdr.text = "QUICK UNIFORM THEMES"
	theme_hdr.modulate = Color(1.0, 0.82, 0.32)
	theme_hdr.add_theme_font_size_override("font_size", 15)
	v.add_child(theme_hdr)

	var pal_grid := GridContainer.new()
	pal_grid.columns = 3
	pal_grid.add_theme_constant_override("h_separation", 8)
	pal_grid.add_theme_constant_override("v_separation", 8)
	v.add_child(pal_grid)

	for i in range(ProfileManager.MILITARY_PALETTES.size()):
		var pal: Dictionary = ProfileManager.MILITARY_PALETTES[i]
		var pb := Button.new()
		pb.text = str(pal["name"])
		pb.custom_minimum_size = Vector2(0, 44)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.add_theme_font_size_override("font_size", 15)
		var base_c: Color = pal["shirt"] as Color
		_style_button(pb, base_c.darkened(0.35), base_c.lightened(0.35), 8)
		pb.pressed.connect(_on_palette_pressed.bind(i))
		pal_grid.add_child(pb)

	v.add_child(HSeparator.new())

	var ch_hdr := Label.new()
	ch_hdr.text = "TAP WHAT TO PAINT"
	ch_hdr.modulate = Color(0.62, 0.90, 1.0)
	ch_hdr.add_theme_font_size_override("font_size", 15)
	v.add_child(ch_hdr)

	var ch_row := HBoxContainer.new()
	ch_row.add_theme_constant_override("separation", 8)
	v.add_child(ch_row)

	_channel_buttons.clear()
	for ch in COLOR_CHANNELS:
		var prop: String = str(ch["prop"])
		var cb := Button.new()
		cb.text = str(ch["label"])
		cb.custom_minimum_size = Vector2(0, 46)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.add_theme_font_size_override("font_size", 15)
		cb.pressed.connect(_select_color_channel.bind(prop))
		ch_row.add_child(cb)
		_channel_buttons[prop] = cb

	var swatch_hdr := Label.new()
	swatch_hdr.text = "TAP A COLOR SWATCH"
	swatch_hdr.modulate = Color(0.62, 0.90, 1.0)
	swatch_hdr.add_theme_font_size_override("font_size", 15)
	v.add_child(swatch_hdr)

	var swatch_grid := GridContainer.new()
	swatch_grid.columns = 4
	swatch_grid.add_theme_constant_override("h_separation", 8)
	swatch_grid.add_theme_constant_override("v_separation", 8)
	v.add_child(swatch_grid)

	for sw_col in ProfileManager.COLOR_SWATCHES:
		var sb := Button.new()
		sb.text = ""
		sb.custom_minimum_size = Vector2(0, 48)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(sb, sw_col, sw_col.lightened(0.45), 10)
		sb.pressed.connect(_on_swatch_pressed.bind(sw_col))
		swatch_grid.add_child(sb)

	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 10)
	v.add_child(custom_row)

	var cust_lbl := Label.new()
	cust_lbl.text = "CUSTOM PICKER:"
	cust_lbl.add_theme_font_size_override("font_size", 15)
	custom_row.add_child(cust_lbl)

	_custom_color_btn = ColorPickerButton.new()
	_custom_color_btn.text = "PICK ANY COLOR"
	_custom_color_btn.custom_minimum_size = Vector2(0, 46)
	_custom_color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_color_btn.edit_alpha = false
	_custom_color_btn.color_changed.connect(_on_custom_color_picked)
	custom_row.add_child(_custom_color_btn)

	return scroll


func _select_tab(tab_idx: int) -> void:
	_active_tab = clampi(tab_idx, 0, _tab_pages.size() - 1)
	for i in range(_tab_pages.size()):
		_tab_pages[i].visible = (i == _active_tab)
		var is_cur: bool = (i == _active_tab)
		var bg_c: Color = Color(0.28, 0.18, 0.06, 0.98) if is_cur else Color(0.11, 0.15, 0.22, 0.9)
		var bd_c: Color = Color(1.0, 0.72, 0.22) if is_cur else Color(0.32, 0.45, 0.65)
		_style_button(_tab_buttons[i], bg_c, bd_c, 10)


func _select_color_channel(prop_name: String) -> void:
	_active_color_prop = prop_name
	_refresh_ui()


func _on_name_changed(txt: String) -> void:
	var clean := txt.strip_edges().left(16)
	ProfileManager.player_name = "Trooper" if clean.is_empty() else clean
	ProfileManager.notify_changed()


func _on_pose_pressed(pose_idx: int) -> void:
	_preview.anim_mode = pose_idx
	_refresh_pose_buttons()


func _on_dummy_card_pressed(dummy_idx: int) -> void:
	ProfileManager.apply_dummy_preset(dummy_idx, true)
	ProfileManager.mark_dummy_used(dummy_idx)
	var dm: Dictionary = ProfileManager.CUSTOM_DUMMIES[clampi(dummy_idx, 0, ProfileManager.CUSTOM_DUMMIES.size() - 1)]
	var def_pid: int = int(dm.get("part_id", 3))
	_last_equipped_parts["head_id"] = int(dm.get("head_id", def_pid))
	_last_equipped_parts["accessories_id"] = int(dm.get("accessories_id", def_pid))
	if ProfileManager.face_acc_id >= 0:
		_last_equipped_parts["face_acc_id"] = ProfileManager.face_acc_id
	_on_avatar_updated()


func _step_layer(prop_name: String, delta_step: int) -> void:
	var allowed: Array[int] = []
	var unlocked: Array[int] = ProfileManager.get_unlocked_dummy_part_ids_for_slot(prop_name)
	if prop_name == "head_id" or prop_name == "accessories_id" or prop_name == "face_acc_id":
		allowed.append(-1)
	for pid in unlocked:
		allowed.append(pid)
	if prop_name == "face_acc_id" and allowed.size() <= 1:
		return
	if allowed.is_empty():
		return
	var cur: int = int(ProfileManager.get(prop_name))
	var pos: int = allowed.find(cur)
	if pos < 0:
		pos = 0
	var next_id: int = allowed[wrapi(pos + delta_step, 0, allowed.size())]
	if next_id >= 0 and (prop_name == "head_id" or prop_name == "accessories_id" or prop_name == "face_acc_id"):
		_last_equipped_parts[prop_name] = next_id
	ProfileManager.set(prop_name, next_id)
	if next_id >= 0:
		ProfileManager.mark_dummy_part_used(prop_name, next_id)
	_on_avatar_updated()


func _on_toggle_accessory(prop_name: String) -> void:
	var cur: int = int(ProfileManager.get(prop_name))
	if cur >= 0:
		_last_equipped_parts[prop_name] = cur
		ProfileManager.set(prop_name, -1)
	else:
		var dm_idx: int = clampi(ProfileManager.dummy_id, 0, ProfileManager.CUSTOM_DUMMIES.size() - 1)
		var def_part: int = int(ProfileManager.CUSTOM_DUMMIES[dm_idx].get("part_id", 3))
		var allowed: Array[int] = ProfileManager.get_unlocked_dummy_part_ids_for_slot(prop_name)
		if allowed.is_empty():
			return
		var fallback_id: int = allowed[0] if prop_name == "face_acc_id" else (def_part if allowed.has(def_part) else allowed[0])
		var restore_id: int = int(_last_equipped_parts.get(prop_name, fallback_id))
		if not allowed.has(restore_id):
			restore_id = fallback_id
		ProfileManager.set(prop_name, restore_id)
		ProfileManager.mark_dummy_part_used(prop_name, restore_id)
	_on_avatar_updated()


func _on_remove_all_accessories() -> void:
	if ProfileManager.head_id >= 0:
		_last_equipped_parts["head_id"] = ProfileManager.head_id
	if ProfileManager.accessories_id >= 0:
		_last_equipped_parts["accessories_id"] = ProfileManager.accessories_id
	if ProfileManager.face_acc_id >= 0:
		_last_equipped_parts["face_acc_id"] = ProfileManager.face_acc_id
	ProfileManager.head_id = -1
	ProfileManager.accessories_id = -1
	ProfileManager.face_acc_id = -1
	_on_avatar_updated()


func _on_reset_dummy_pressed() -> void:
	ProfileManager.apply_dummy_preset(ProfileManager.dummy_id, true)
	var dm: Dictionary = ProfileManager.CUSTOM_DUMMIES[clampi(ProfileManager.dummy_id, 0, ProfileManager.CUSTOM_DUMMIES.size() - 1)]
	var def_pid: int = int(dm.get("part_id", 3))
	_last_equipped_parts["head_id"] = int(dm.get("head_id", def_pid))
	_last_equipped_parts["accessories_id"] = int(dm.get("accessories_id", def_pid))
	if ProfileManager.face_acc_id >= 0:
		_last_equipped_parts["face_acc_id"] = ProfileManager.face_acc_id
	_on_avatar_updated()


func _on_palette_pressed(pal_idx: int) -> void:
	ProfileManager.apply_palette(pal_idx)
	_on_avatar_updated()


func _on_swatch_pressed(col: Color) -> void:
	ProfileManager.set(_active_color_prop, col)
	_on_avatar_updated()


func _on_custom_color_picked(col: Color) -> void:
	ProfileManager.set(_active_color_prop, col)
	_on_avatar_updated()


func _on_randomize_pressed() -> void:
	var base_parts: Array[int] = ProfileManager.get_dummy_part_ids()
	var head_pool: Array[int] = [-1]
	for pid in ProfileManager.get_unlocked_dummy_part_ids_for_slot("head_id"):
		head_pool.append(pid)
	var acc_pool: Array[int] = [-1]
	for pid in ProfileManager.get_unlocked_dummy_part_ids_for_slot("accessories_id"):
		acc_pool.append(pid)
	var face_pool: Array[int] = [-1]
	for pid in ProfileManager.get_unlocked_dummy_part_ids_for_slot("face_acc_id"):
		face_pool.append(pid)
	var torso_pool: Array[int] = ProfileManager.get_unlocked_dummy_part_ids_for_slot("torso_id")
	if torso_pool.is_empty():
		torso_pool = base_parts
	var legs_pool: Array[int] = ProfileManager.get_unlocked_dummy_part_ids_for_slot("legs_id")
	if legs_pool.is_empty():
		legs_pool = base_parts
	var hands_pool: Array[int] = ProfileManager.get_unlocked_dummy_part_ids_for_slot("hands_id")
	if hands_pool.is_empty():
		hands_pool = base_parts
	var skin_pool: Array[int] = ProfileManager.get_unlocked_dummy_part_ids_for_slot("skin_id")
	if skin_pool.is_empty():
		skin_pool = base_parts

	ProfileManager.dummy_id = randi() % ProfileManager.CUSTOM_DUMMIES.size()
	ProfileManager.head_id = head_pool[randi() % head_pool.size()]
	ProfileManager.accessories_id = acc_pool[randi() % acc_pool.size()]
	ProfileManager.face_acc_id = face_pool[randi() % face_pool.size()]
	ProfileManager.torso_id = torso_pool[randi() % torso_pool.size()]
	ProfileManager.legs_id = legs_pool[randi() % legs_pool.size()]
	ProfileManager.hands_id = hands_pool[randi() % hands_pool.size()]
	ProfileManager.skin_id = skin_pool[randi() % skin_pool.size()]
	if ProfileManager.head_id >= 0:
		_last_equipped_parts["head_id"] = ProfileManager.head_id
	if ProfileManager.accessories_id >= 0:
		_last_equipped_parts["accessories_id"] = ProfileManager.accessories_id
	if ProfileManager.face_acc_id >= 0:
		_last_equipped_parts["face_acc_id"] = ProfileManager.face_acc_id
	ProfileManager.mark_dummy_used(ProfileManager.dummy_id)
	for slot_prop in ["head_id", "accessories_id", "face_acc_id", "torso_id", "legs_id", "hands_id", "skin_id"]:
		var eq_pid: int = int(ProfileManager.get(slot_prop))
		if eq_pid >= 0:
			ProfileManager.mark_dummy_part_used(slot_prop, eq_pid)
	var swatches := ProfileManager.COLOR_SWATCHES
	ProfileManager.shirt_color = swatches[randi() % swatches.size()]
	ProfileManager.pants_color = swatches[randi() % swatches.size()]
	ProfileManager.helmet_color = swatches[randi() % swatches.size()]
	ProfileManager.gear_color = swatches[randi() % swatches.size()]
	_on_avatar_updated()


func _on_avatar_updated() -> void:
	ProfileManager.notify_changed()
	_preview.refresh_from_profile()
	_refresh_ui()


func _refresh_pose_buttons() -> void:
	for i in range(_pose_buttons.size()):
		var cur: bool = (_preview.anim_mode == i)
		var bg_c: Color = Color(0.24, 0.16, 0.06) if cur else Color(0.11, 0.15, 0.22)
		var bd_c: Color = Color(1.0, 0.72, 0.22) if cur else Color(0.32, 0.45, 0.65)
		_style_button(_pose_buttons[i], bg_c, bd_c, 8)


func _get_part_names(prop_name: String) -> Array[String]:
	match prop_name:
		"head_id":
			return ProfileManager.HEAD_NAMES
		"torso_id":
			return ProfileManager.TORSO_NAMES
		"legs_id":
			return ProfileManager.LEGS_NAMES
		"hands_id":
			return ProfileManager.HANDS_NAMES
		"accessories_id":
			return ProfileManager.ACC_NAMES
		"face_acc_id":
			return ProfileManager.FACE_ACC_NAMES
		_:
			return ProfileManager.SKIN_NAMES


func _refresh_ui() -> void:
	var dm_idx: int = clampi(ProfileManager.dummy_id, 0, ProfileManager.CUSTOM_DUMMIES.size() - 1)
	var cur_dm: Dictionary = ProfileManager.CUSTOM_DUMMIES[dm_idx]
	_dummy_name_label.text = str(cur_dm.get("name", "FIGHTER")).to_upper()
	_dummy_role_label.text = str(cur_dm.get("role", "Customizable Fighter"))
	_refresh_pose_buttons()

	if _tab_buttons.size() >= 1:
		UIStyle.set_new_badge_visible(_tab_buttons[0], ProfileManager.has_any_new_dummy(), "NewBadge", -6.0, 4.0, 10)
	if _tab_buttons.size() >= 2:
		UIStyle.set_new_badge_visible(_tab_buttons[1], ProfileManager.has_any_new_cosmetic(), "NewBadge", -6.0, 4.0, 10)

	for card in _dummy_cards:
		var c_idx: int = int(card.get_meta("dummy_idx")) if card.has_meta("dummy_idx") else -1
		if c_idx < 0 or c_idx >= ProfileManager.CUSTOM_DUMMIES.size():
			continue
		var sel: bool = (c_idx == dm_idx)
		var bg_c: Color = Color(0.28, 0.18, 0.06) if sel else Color(0.10, 0.14, 0.22)
		var bd_c: Color = Color(1.0, 0.78, 0.25) if sel else Color(0.28, 0.42, 0.62)
		_style_button(card, bg_c, bd_c, 8)
		UIStyle.set_new_badge_visible(card, ProfileManager.is_dummy_new(c_idx), "NewBadge", -6.0, 6.0, 10)

	# Gear & accessory rows
	for spec in GEAR_SPECS:
		var prop: String = str(spec["prop"])
		var raw_val: int = int(ProfileManager.get(prop))
		var unlocked_for_slot: Array[int] = ProfileManager.get_unlocked_dummy_part_ids_for_slot(prop)
		if _slot_new_badges.has(prop):
			var slot_badge: Control = _slot_new_badges[prop] as Control
			if is_instance_valid(slot_badge):
				slot_badge.visible = ProfileManager.has_new_cosmetic_for_slot(prop)
		var lbl: Label = _layer_labels.get(prop) as Label
		if lbl != null:
			if raw_val < 0:
				if prop == "face_acc_id" and unlocked_for_slot.is_empty():
					lbl.text = "Locked (Open Crates)"
					lbl.modulate = Color(0.55, 0.62, 0.74)
				else:
					lbl.text = "None (Removed)"
					lbl.modulate = Color(0.62, 0.68, 0.78)
			else:
				var names_list: Array[String] = _get_part_names(prop)
				var idx: int = clampi(raw_val, 0, names_list.size() - 1)
				lbl.text = names_list[idx]
				lbl.modulate = Color(1.0, 0.9, 0.48)
		if _accessory_toggle_btns.has(prop):
			var tog_btn: Button = _accessory_toggle_btns[prop] as Button
			if is_instance_valid(tog_btn):
				if prop == "face_acc_id" and unlocked_for_slot.is_empty() and raw_val < 0:
					tog_btn.text = "LOCKED"
					tog_btn.disabled = true
					_style_button(tog_btn, Color(0.14, 0.16, 0.22), Color(0.35, 0.40, 0.50), 8)
				elif raw_val < 0:
					tog_btn.text = "ADD"
					tog_btn.disabled = false
					_style_button(tog_btn, Color(0.10, 0.30, 0.16), Color(0.32, 0.92, 0.48), 8)
				else:
					tog_btn.text = "REMOVE"
					tog_btn.disabled = false
					_style_button(tog_btn, Color(0.28, 0.12, 0.12), Color(0.95, 0.42, 0.36), 8)

	# Color channels
	for prop in _channel_buttons.keys():
		var cb: Button = _channel_buttons[prop] as Button
		var col_val: Color = ProfileManager.get(prop) as Color
		var active: bool = (prop == _active_color_prop)
		var bg_c: Color = col_val.darkened(0.25) if active else Color(0.10, 0.14, 0.22)
		var bd_c: Color = Color(1.0, 0.85, 0.28) if active else col_val.lightened(0.25)
		_style_button(cb, bg_c, bd_c, 8)
	if is_instance_valid(_custom_color_btn):
		_custom_color_btn.color = ProfileManager.get(_active_color_prop) as Color


func _make_dummy_icon(dummy_idx: int) -> Texture2D:
	var dm: Dictionary = ProfileManager.CUSTOM_DUMMIES[clampi(dummy_idx, 0, ProfileManager.CUSTOM_DUMMIES.size() - 1)]
	var def_part: int = int(dm.get("part_id", 3))
	var s_idx: int = clampi(int(dm.get("skin_id", def_part)), 0, ModularCharacter.MAX_PART_INDEX)
	var h_idx: int = int(dm.get("head_id", def_part))
	var skin_tex: Texture2D = load(ModularCharacter.get_part_texture_path("skin", s_idx)) as Texture2D
	if skin_tex == null:
		return null
	var fw: int = skin_tex.get_width() / 8
	var fh: int = mini(skin_tex.get_height(), int(float(skin_tex.get_height()) * 0.72))
	var crop := Rect2i(0, 0, fw, fh)
	var base_img: Image = skin_tex.get_image().get_region(crop)
	if base_img.get_format() != Image.FORMAT_RGBA8:
		base_img.convert(Image.FORMAT_RGBA8)
	if h_idx >= 0:
		var head_tex: Texture2D = load(ModularCharacter.get_part_texture_path("head", clampi(h_idx, 0, ModularCharacter.MAX_PART_INDEX))) as Texture2D
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
	var scale_f: float = 44.0 / float(maxi(used.size.x, used.size.y))
	var tw: int = maxi(1, int(round(float(used.size.x) * scale_f)))
	var th: int = maxi(1, int(round(float(used.size.y) * scale_f)))
	trimmed.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	var sq := Image.create(52, 52, false, Image.FORMAT_RGBA8)
	sq.fill(Color(0, 0, 0, 0))
	sq.blit_rect(trimmed, Rect2i(0, 0, tw, th), Vector2i((52 - tw) / 2, (52 - th) / 2))
	return ImageTexture.create_from_image(sq)
