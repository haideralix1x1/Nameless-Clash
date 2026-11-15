extends Control

const UIStyle = preload("res://scripts/UIStyle.gd")
const TEX_BG: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const TEX_WEAPONS: Texture2D = preload("res://assets/sprites/weapons_sheet.png")

const TAB_NAMES: Array[String] = ["HEROES", "OUTFIT", "COLORS", "WEAPONS"]
const GEAR_SPECS: Array[Dictionary] = [
	{"label": "Helmet / Head", "prop": "head_id"},
	{"label": "Armor / Shirt", "prop": "torso_id"},
	{"label": "Pants / Boots", "prop": "legs_id"},
	{"label": "Gloves", "prop": "hands_id"},
	{"label": "Back / Belt", "prop": "accessories_id"},
	{"label": "Body Type", "prop": "skin_id"}
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
var _hero_name_label: Label
var _hero_role_label: Label
var _agent_summary_label: Label

var _tab_buttons: Array[Button] = []
var _tab_pages: Array[Control] = []
var _active_tab: int = 0

var _pose_buttons: Array[Button] = []
var _hero_cards: Array[Button] = []
var _layer_labels: Dictionary = {}

var _active_color_prop: String = "shirt_color"
var _channel_buttons: Dictionary = {}
var _custom_color_btn: ColorPickerButton

var _editing_secondary: bool = false
var _slot_primary_btn: Button
var _slot_secondary_btn: Button
var _camo_btn: Button
var _rail_btn: Button

var _weapon_icon_rect: TextureRect
var _weapon_title_label: Label
var _weapon_sub_label: Label
var _bar_dmg: ProgressBar
var _bar_rpm: ProgressBar
var _bar_acc: ProgressBar
var _bar_mob: ProgressBar
var _weapon_trait_label: Label
var _weapon_cards: Array[Button] = []


func _ready() -> void:
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
	UIStyle.style_layer_button(btn, _variant_for_color(accent), "", 12, 8)


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = TEX_BG
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	margin.add_child(root_v)

	# Mobile Top Navigation Bar
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10)
	root_v.add_child(top_bar)

	var menu_btn := Button.new()
	menu_btn.text = "< MENU"
	menu_btn.custom_minimum_size = Vector2(124, 50)
	menu_btn.add_theme_font_size_override("font_size", 18)
	_style_button(menu_btn, Color(0.14, 0.18, 0.26, 0.95), Color(0.55, 0.72, 0.95))
	menu_btn.pressed.connect(func(): NetworkManager.go_to_main_menu())
	top_bar.add_child(menu_btn)

	var title := Label.new()
	title.text = "HERO & ARMORY"
	title.add_theme_font_size_override("font_size", 26)
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
	_name_input.custom_minimum_size = Vector2(175, 44)
	_name_input.add_theme_font_size_override("font_size", 17)
	_name_input.text_changed.connect(_on_name_changed)
	top_bar.add_child(_name_input)

	var lobby_btn := Button.new()
	lobby_btn.text = "WIFI LOBBY"
	lobby_btn.custom_minimum_size = Vector2(146, 50)
	lobby_btn.add_theme_font_size_override("font_size", 17)
	_style_button(lobby_btn, Color(0.10, 0.22, 0.36, 0.95), Color(0.28, 0.72, 1.0))
	lobby_btn.pressed.connect(func(): NetworkManager.go_to_lobby())
	top_bar.add_child(lobby_btn)

	var play_btn := Button.new()
	play_btn.text = "PLAY NOW ▶"
	play_btn.custom_minimum_size = Vector2(165, 50)
	play_btn.add_theme_font_size_override("font_size", 18)
	_style_button(play_btn, Color(0.10, 0.34, 0.18, 0.98), Color(0.28, 0.92, 0.45))
	play_btn.pressed.connect(func(): NetworkManager.go_to_arena())
	top_bar.add_child(play_btn)

	# Main 2-Pane Split: Hero Stage (Left) + Tabbed Customization Deck (Right)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root_v.add_child(split)

	_build_hero_stage(split)
	_build_customization_deck(split)


func _build_hero_stage(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.62
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.95), Color(0.98, 0.58, 0.16, 0.92), 14, 16, 14))
	parent.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	_hero_name_label = Label.new()
	_hero_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_name_label.add_theme_font_size_override("font_size", 24)
	_hero_name_label.modulate = Color(1.0, 0.85, 0.30)
	v.add_child(_hero_name_label)

	_hero_role_label = Label.new()
	_hero_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_role_label.add_theme_font_size_override("font_size", 15)
	_hero_role_label.modulate = Color(0.68, 0.88, 1.0)
	v.add_child(_hero_role_label)

	var stage := PanelContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", _make_style(Color(0.03, 0.05, 0.09, 0.96), Color(0.22, 0.36, 0.56, 0.7), 12, 4, 4))
	v.add_child(stage)

	var anchor_wrap := Control.new()
	stage.add_child(anchor_wrap)

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER)
	anchor_wrap.add_child(anchor)

	_preview = SoldierPreview.new()
	_preview.scale = Vector2(4.6, 4.6)
	anchor.add_child(_preview)

	# Pose Selector Buttons
	var pose_row := HBoxContainer.new()
	pose_row.add_theme_constant_override("separation", 8)
	v.add_child(pose_row)

	_pose_buttons.clear()
	var poses: Array[String] = ["IDLE", "RUN", "FLY", "FIRE"]
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

	# 4 Big Category Tabs
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
	_tab_pages.append(_build_heroes_tab(deck_v))
	_tab_pages.append(_build_outfit_tab(deck_v))
	_tab_pages.append(_build_colors_tab(deck_v))
	_tab_pages.append(_build_weapons_tab(deck_v))


func _build_heroes_tab(parent: VBoxContainer) -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	var hint := Label.new()
	hint.text = "Tap any Agent Hero to load their signature look, gun, and Agent Clash powers."
	hint.modulate = Color(0.72, 0.88, 1.0)
	hint.add_theme_font_size_override("font_size", 15)
	v.add_child(hint)

	_agent_summary_label = Label.new()
	_agent_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_agent_summary_label.add_theme_font_size_override("font_size", 14)
	_agent_summary_label.modulate = Color(0.86, 0.72, 1.0)
	v.add_child(_agent_summary_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)

	_hero_cards.clear()
	for i in range(ProfileManager.ARCHETYPES.size()):
		var arch: Dictionary = ProfileManager.ARCHETYPES[i]
		var card := Button.new()
		card.custom_minimum_size = Vector2(0, 70)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_font_size_override("font_size", 16)
		card.text = "%s\n%s" % [str(arch["name"]).to_upper(), ProfileManager.ARCHETYPE_ROLES[i]]
		card.pressed.connect(_on_hero_card_pressed.bind(i))
		grid.add_child(card)
		_hero_cards.append(card)

	return scroll


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
	hint.text = "Mix and match gear parts from all %d Soldiers." % ProfileManager.ARCHETYPES.size()
	hint.modulate = Color(0.72, 0.88, 1.0)
	hint.add_theme_font_size_override("font_size", 15)
	v.add_child(hint)

	_layer_labels.clear()
	for spec in GEAR_SPECS:
		var prop: String = str(spec["prop"])
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_style(Color(0.09, 0.13, 0.20, 0.92), Color(0.24, 0.42, 0.68, 0.8), 10, 12, 8))
		v.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var lbl := Label.new()
		lbl.text = str(spec["label"])
		lbl.custom_minimum_size = Vector2(145, 0)
		lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(lbl)

		var prev_btn := Button.new()
		prev_btn.text = "◀"
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
		next_btn.text = "▶"
		next_btn.custom_minimum_size = Vector2(56, 46)
		next_btn.add_theme_font_size_override("font_size", 18)
		_style_button(next_btn, Color(0.14, 0.20, 0.30), Color(0.45, 0.72, 0.98))
		next_btn.pressed.connect(_step_layer.bind(prop, 1))
		row.add_child(next_btn)

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


func _build_weapons_tab(parent: VBoxContainer) -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)

	# Slot Switch + Camo + Rail Controls
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	v.add_child(slot_row)

	_slot_primary_btn = Button.new()
	_slot_primary_btn.text = "PRIMARY GUN"
	_slot_primary_btn.custom_minimum_size = Vector2(0, 46)
	_slot_primary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_primary_btn.add_theme_font_size_override("font_size", 16)
	_slot_primary_btn.pressed.connect(_on_slot_selected.bind(false))
	slot_row.add_child(_slot_primary_btn)

	_slot_secondary_btn = Button.new()
	_slot_secondary_btn.text = "BACKUP PISTOL"
	_slot_secondary_btn.custom_minimum_size = Vector2(0, 46)
	_slot_secondary_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_secondary_btn.add_theme_font_size_override("font_size", 16)
	_slot_secondary_btn.pressed.connect(_on_slot_selected.bind(true))
	slot_row.add_child(_slot_secondary_btn)

	_camo_btn = Button.new()
	_camo_btn.custom_minimum_size = Vector2(150, 46)
	_camo_btn.add_theme_font_size_override("font_size", 15)
	_style_button(_camo_btn, Color(0.14, 0.18, 0.28), Color(0.76, 0.48, 1.0), 8)
	_camo_btn.pressed.connect(_on_cycle_camo)
	slot_row.add_child(_camo_btn)

	_rail_btn = Button.new()
	_rail_btn.custom_minimum_size = Vector2(160, 46)
	_rail_btn.add_theme_font_size_override("font_size", 15)
	_style_button(_rail_btn, Color(0.14, 0.22, 0.28), Color(0.28, 0.85, 0.95), 8)
	_rail_btn.pressed.connect(_on_cycle_rail)
	slot_row.add_child(_rail_btn)

	# Visual Stat Card
	var stat_card := PanelContainer.new()
	stat_card.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.06, 0.11, 0.94), Color(0.45, 0.58, 0.80, 0.8), 10, 12, 10))
	v.add_child(stat_card)

	var sc_v := VBoxContainer.new()
	sc_v.add_theme_constant_override("separation", 6)
	stat_card.add_child(sc_v)

	var top_stat := HBoxContainer.new()
	top_stat.add_theme_constant_override("separation", 12)
	sc_v.add_child(top_stat)

	var w_atlas := AtlasTexture.new()
	w_atlas.atlas = TEX_WEAPONS
	w_atlas.region = Rect2(0, 0, 64, 32)
	_weapon_icon_rect = TextureRect.new()
	_weapon_icon_rect.texture = w_atlas
	_weapon_icon_rect.custom_minimum_size = Vector2(96, 48)
	_weapon_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_stat.add_child(_weapon_icon_rect)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_stat.add_child(title_box)

	_weapon_title_label = Label.new()
	_weapon_title_label.add_theme_font_size_override("font_size", 20)
	_weapon_title_label.modulate = Color(1.0, 0.85, 0.35)
	title_box.add_child(_weapon_title_label)

	_weapon_sub_label = Label.new()
	_weapon_sub_label.add_theme_font_size_override("font_size", 13)
	_weapon_sub_label.modulate = Color(0.75, 0.88, 1.0)
	title_box.add_child(_weapon_sub_label)

	var bars_grid := GridContainer.new()
	bars_grid.columns = 2
	bars_grid.add_theme_constant_override("h_separation", 14)
	bars_grid.add_theme_constant_override("v_separation", 6)
	sc_v.add_child(bars_grid)

	_bar_dmg = _add_stat_bar(bars_grid, "POWER", Color(1.0, 0.36, 0.32))
	_bar_rpm = _add_stat_bar(bars_grid, "FIRE RATE", Color(1.0, 0.72, 0.22))
	_bar_acc = _add_stat_bar(bars_grid, "ACCURACY", Color(0.28, 0.86, 1.0))
	_bar_mob = _add_stat_bar(bars_grid, "SPEED", Color(0.32, 0.94, 0.55))

	_weapon_trait_label = Label.new()
	_weapon_trait_label.add_theme_font_size_override("font_size", 14)
	_weapon_trait_label.modulate = Color(0.68, 0.96, 0.75)
	_weapon_trait_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	sc_v.add_child(_weapon_trait_label)

	# 11-Weapon Touch Grid
	var w_grid := GridContainer.new()
	w_grid.columns = 2
	w_grid.add_theme_constant_override("h_separation", 8)
	w_grid.add_theme_constant_override("v_separation", 8)
	v.add_child(w_grid)

	_weapon_cards.clear()
	for i in range(WeaponData.get_weapon_count()):
		var w_info: WeaponData = WeaponData.get_weapon(i, 0, 0)
		var wb := Button.new()
		wb.text = w_info.display_name
		wb.custom_minimum_size = Vector2(0, 52)
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wb.add_theme_font_size_override("font_size", 16)
		wb.pressed.connect(_on_weapon_card_pressed.bind(i))
		w_grid.add_child(wb)
		_weapon_cards.append(wb)

	return scroll


func _add_stat_bar(grid: GridContainer, title_txt: String, bar_col: Color) -> ProgressBar:
	var box := HBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	grid.add_child(box)

	var lbl := Label.new()
	lbl.text = title_txt
	lbl.custom_minimum_size = Vector2(82, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	box.add_child(lbl)

	var bar := ProgressBar.new()
	bar.max_value = 100
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 14)
	bar.modulate = bar_col
	box.add_child(bar)
	return bar


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


func _on_hero_card_pressed(arch_idx: int) -> void:
	ProfileManager.apply_archetype_preset(arch_idx)
	_on_avatar_updated()


func _step_layer(prop_name: String, delta_step: int) -> void:
	var cur: int = int(ProfileManager.get(prop_name))
	ProfileManager.set(prop_name, wrapi(cur + delta_step, 0, ProfileManager.ARCHETYPES.size()))
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
	var count: int = ProfileManager.ARCHETYPES.size()
	ProfileManager.archetype_id = randi() % count
	ProfileManager.head_id = randi() % count
	ProfileManager.torso_id = randi() % count
	ProfileManager.legs_id = randi() % count
	ProfileManager.hands_id = randi() % count
	ProfileManager.accessories_id = randi() % count
	ProfileManager.skin_id = randi() % count
	var swatches := ProfileManager.COLOR_SWATCHES
	ProfileManager.shirt_color = swatches[randi() % swatches.size()]
	ProfileManager.pants_color = swatches[randi() % swatches.size()]
	ProfileManager.helmet_color = swatches[randi() % swatches.size()]
	ProfileManager.gear_color = swatches[randi() % swatches.size()]
	_on_avatar_updated()


func _on_slot_selected(secondary: bool) -> void:
	_editing_secondary = secondary
	_refresh_ui()


func _on_cycle_camo() -> void:
	ProfileManager.weapon_skin_id = wrapi(ProfileManager.weapon_skin_id + 1, 0, ProfileManager.WEAPON_SKIN_NAMES.size())
	_on_avatar_updated()


func _on_cycle_rail() -> void:
	ProfileManager.m4a1_rail_mod = wrapi(ProfileManager.m4a1_rail_mod + 1, 0, ProfileManager.RAIL_MOD_NAMES.size())
	_on_avatar_updated()


func _on_weapon_card_pressed(w_id: int) -> void:
	if _editing_secondary:
		ProfileManager.secondary_weapon_id = w_id
	else:
		ProfileManager.primary_weapon_id = w_id
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
		_:
			return ProfileManager.SKIN_NAMES


func _refresh_ui() -> void:
	var arch_idx: int = clampi(ProfileManager.archetype_id, 0, ProfileManager.ARCHETYPES.size() - 1)
	_hero_name_label.text = str(ProfileManager.ARCHETYPES[arch_idx]["name"]).to_upper()
	_hero_role_label.text = ProfileManager.ARCHETYPE_ROLES[arch_idx]
	if is_instance_valid(_agent_summary_label):
		var ag: Dictionary = AgentData.get_agent(arch_idx)
		var bw: Dictionary = ag["base_weapon"]
		var abils: Array = ag["abilities"]
		var ult: Dictionary = ag["ultimate"]
		_agent_summary_label.text = (
			"⚡ AGENT CLASH KIT — Base: %s | [Q] %s | [E] %s | [C] %s | ★ ULT: %s"
			% [str(bw["name"]), str(abils[0]["name"]), str(abils[1]["name"]), str(abils[2]["name"]), str(ult["name"])]
		)
	_refresh_pose_buttons()

	# Hero preset grid highlight
	for i in range(_hero_cards.size()):
		var sel: bool = (i == arch_idx)
		var bg_c: Color = Color(0.26, 0.18, 0.06) if sel else Color(0.10, 0.14, 0.22)
		var bd_c: Color = Color(1.0, 0.78, 0.24) if sel else Color(0.26, 0.40, 0.62)
		_style_button(_hero_cards[i], bg_c, bd_c, 10)

	# Friendly gear labels
	for spec in GEAR_SPECS:
		var prop: String = str(spec["prop"])
		var names_list: Array[String] = _get_part_names(prop)
		var idx: int = clampi(int(ProfileManager.get(prop)), 0, names_list.size() - 1)
		var lbl: Label = _layer_labels.get(prop) as Label
		if lbl != null:
			lbl.text = names_list[idx]

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

	# Weapons slot & stats
	var active_w_id: int = ProfileManager.secondary_weapon_id if _editing_secondary else ProfileManager.primary_weapon_id
	var w: WeaponData = WeaponData.get_weapon(active_w_id, ProfileManager.weapon_skin_id, ProfileManager.m4a1_rail_mod)

	_style_button(
		_slot_primary_btn,
		Color(0.26, 0.18, 0.06) if not _editing_secondary else Color(0.10, 0.14, 0.22),
		Color(1.0, 0.78, 0.25) if not _editing_secondary else Color(0.32, 0.45, 0.65),
		8
	)
	_style_button(
		_slot_secondary_btn,
		Color(0.26, 0.18, 0.06) if _editing_secondary else Color(0.10, 0.14, 0.22),
		Color(1.0, 0.78, 0.25) if _editing_secondary else Color(0.32, 0.45, 0.65),
		8
	)
	_camo_btn.text = "CAMO: " + ProfileManager.WEAPON_SKIN_NAMES[ProfileManager.weapon_skin_id].split(" ")[0].to_upper()
	_rail_btn.visible = w.has_accessory_rail
	_rail_btn.text = "RAIL: " + ProfileManager.RAIL_MOD_NAMES[ProfileManager.m4a1_rail_mod]

	var atlas: AtlasTexture = _weapon_icon_rect.texture as AtlasTexture
	if atlas != null:
		atlas.region = Rect2(w.sprite_frame * 64, ProfileManager.weapon_skin_id * 32, 64, 32)

	_weapon_title_label.text = w.display_name
	_weapon_sub_label.text = "%s  •  %d Rounds" % [w.category, w.mag_size]

	var burst_dmg: float = float(w.damage * w.pellet_count)
	_bar_dmg.value = clampf(burst_dmg, 12.0, 100.0)
	var rpm: float = 60.0 / maxf(0.03, w.fire_interval)
	_bar_rpm.value = clampf((rpm / 1200.0) * 100.0, 8.0, 100.0)
	_bar_acc.value = clampf(100.0 - w.spread_deg * 8.0, 15.0, 100.0)
	_bar_mob.value = clampf(w.move_speed_multiplier * 90.0, 45.0, 100.0)

	var traits: PackedStringArray = PackedStringArray()
	if w.unlimited_reserve:
		traits.append("Unlimited Ammo & Quick Draw")
	if w.single_shell_reload:
		traits.append("Shell-by-Shell Reload")
	if w.scope_zoom < 0.95:
		traits.append("Zoom Sniper Scope")
	if w.vertical_recoil_bias < 0.0:
		traits.append("Low Recoil Kick")
	if w.has_backblast:
		traits.append("Explosive Blast Rocket")
	if w.has_accessory_rail:
		traits.append("Supports Suppressor / Scope")
	_weapon_trait_label.text = "  •  ".join(traits) if not traits.is_empty() else w.description

	for i in range(_weapon_cards.size()):
		var cur_w: bool = (i == active_w_id)
		var bg_c: Color = Color(0.26, 0.18, 0.06) if cur_w else Color(0.10, 0.14, 0.22)
		var bd_c: Color = Color(1.0, 0.78, 0.25) if cur_w else Color(0.28, 0.42, 0.65)
		_style_button(_weapon_cards[i], bg_c, bd_c, 8)
