extends Control

const UIStyle = preload("res://scripts/UIStyle.gd")
const TEX_BG: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const TEX_ICON: Texture2D = preload("res://icon.svg")

var _hub_container: Control
var _credits_overlay: Control
var _preview: SoldierPreview
var _callsign_label: Label
var _loadout_label: Label
var _transitioning: bool = false
var _diff_buttons: Array[Button] = []
var _agent_select_overlay: Control
var _agent_preview: SoldierPreview
var _agent_kit_title: Label
var _agent_kit_body: Label
var _agent_cards: Array[Button] = []


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


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = TEX_BG
	bg.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	_hub_container = VBoxContainer.new()
	_hub_container.add_theme_constant_override("separation", 18)
	margin.add_child(_hub_container)

	# Clean Mobile Arcade Header
	var header_panel := PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.94), Color(0.98, 0.56, 0.14, 0.95), 14))
	_hub_container.add_child(header_panel)

	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 16)
	header_panel.add_child(h_row)

	var icon_rect := TextureRect.new()
	icon_rect.texture = TEX_ICON
	icon_rect.custom_minimum_size = Vector2(72, 72)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h_row.add_child(icon_rect)

	var title_v := VBoxContainer.new()
	title_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_v.alignment = BoxContainer.ALIGNMENT_CENTER
	h_row.add_child(title_v)

	var title_lbl := Label.new()
	title_lbl.text = "NAMELESS CLASH"
	title_lbl.add_theme_font_override("font", UIStyle.FONT_MAIN)
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.modulate = Color(0.90, 0.78, 0.46)
	title_v.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "2D MULTIPLAYER ARENA SHOOTER"
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.modulate = Color(0.66, 0.74, 0.82)
	title_v.add_child(sub_lbl)

	# Main Split: Left (Your Soldier Showcase) + Right (Big Touch Battle Modes)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 22)
	_hub_container.add_child(split)

	# Left Card: Your Soldier Showcase
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.88
	preview_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.92), Color(0.32, 0.46, 0.62, 0.90), 14))
	split.add_child(preview_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	preview_panel.add_child(pv)

	var p_hdr := Label.new()
	p_hdr.text = "YOUR SOLDIER"
	p_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_hdr.add_theme_font_size_override("font_size", 16)
	p_hdr.modulate = Color(0.70, 0.78, 0.86)
	pv.add_child(p_hdr)

	_callsign_label = Label.new()
	_callsign_label.text = ProfileManager.player_name.to_upper()
	_callsign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callsign_label.add_theme_font_size_override("font_size", 26)
	_callsign_label.modulate = Color(0.90, 0.78, 0.46)
	pv.add_child(_callsign_label)

	var stage := PanelContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(300, 220)
	stage.add_theme_stylebox_override("panel", _make_style(Color(0.03, 0.05, 0.09, 0.94), Color(0.24, 0.38, 0.58, 0.7), 12))
	pv.add_child(stage)

	var anchor_wrap := Control.new()
	stage.add_child(anchor_wrap)

	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER)
	anchor_wrap.add_child(anchor)

	_preview = SoldierPreview.new()
	_preview.scale = Vector2(4.2, 4.2)
	anchor.add_child(_preview)

	_loadout_label = Label.new()
	_loadout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_loadout_label.add_theme_font_size_override("font_size", 16)
	_loadout_label.modulate = Color(0.76, 0.82, 0.88)
	var arch_name: String = ProfileManager.ARCHETYPES[ProfileManager.archetype_id]["name"]
	var pri_weapon: WeaponData = WeaponData.get_weapon(ProfileManager.primary_weapon_id, ProfileManager.weapon_skin_id, ProfileManager.m4a1_rail_mod)
	var sec_weapon: WeaponData = WeaponData.get_weapon(ProfileManager.secondary_weapon_id, ProfileManager.weapon_skin_id, 0)
	_loadout_label.text = "%s\n%s  +  %s" % [arch_name, pri_weapon.display_name, sec_weapon.display_name]
	pv.add_child(_loadout_label)

	var edit_avatar_btn := _make_arcade_button("CUSTOMIZE HERO & WEAPONS", Color(0.86, 0.62, 0.24), 58.0, 18, Color(0.18, 0.14, 0.10, 0.96))
	edit_avatar_btn.pressed.connect(func(): _transition_to(NetworkManager.go_to_avatar_garage))
	pv.add_child(edit_avatar_btn)

	# Right Card: Big Mobile Battle Mode Buttons
	var nav_panel := PanelContainer.new()
	nav_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_panel.size_flags_stretch_ratio = 1.08
	nav_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.92), Color(0.24, 0.56, 0.88, 0.88), 14))
	split.add_child(nav_panel)

	var nav_v := VBoxContainer.new()
	nav_v.add_theme_constant_override("separation", 14)
	nav_v.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_panel.add_child(nav_v)

	var nav_hdr := Label.new()
	nav_hdr.text = "BATTLE MODES"
	nav_hdr.add_theme_font_size_override("font_size", 17)
	nav_hdr.modulate = Color(0.70, 0.78, 0.86)
	nav_v.add_child(nav_hdr)

	var btn_solo := _make_arcade_button("▶  PLAY SOLO (GUNFIGHT)", Color(0.30, 0.92, 0.48), 66.0, 20, Color(0.09, 0.28, 0.16, 0.98))
	btn_solo.pressed.connect(func():
		NetworkManager.disconnect_network()
		if NetworkManager.is_agent_clash_mode():
			NetworkManager.match_mode = 0
		_transition_to(NetworkManager.go_to_arena)
	)
	nav_v.add_child(btn_solo)

	var btn_agent := _make_arcade_button("⚡ AGENT CLASH (ABILITIES MODE)", Color(0.78, 0.42, 1.0), 62.0, 19, Color(0.20, 0.10, 0.34, 0.98))
	btn_agent.pressed.connect(_open_agent_select)
	nav_v.add_child(btn_agent)

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	nav_v.add_child(diff_row)

	var diff_lbl := Label.new()
	diff_lbl.text = "BOT LEVEL:"
	diff_lbl.add_theme_font_size_override("font_size", 14)
	diff_lbl.modulate = Color(0.75, 0.88, 1.0)
	diff_row.add_child(diff_lbl)

	_diff_buttons.clear()
	var diff_labels: Array[String] = ["EASY", "MID", "HARD"]
	for i in range(diff_labels.size()):
		var db := Button.new()
		db.text = diff_labels[i]
		db.custom_minimum_size = Vector2(0, 42)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.add_theme_font_size_override("font_size", 15)
		db.pressed.connect(_select_bot_difficulty.bind(i))
		diff_row.add_child(db)
		_diff_buttons.append(db)
	_refresh_diff_buttons()

	var btn_join_lan := _make_arcade_button("WIFI MULTIPLAYER LOBBY", Color(0.26, 0.74, 1.0), 66.0, 20, Color(0.10, 0.20, 0.34, 0.96))
	btn_join_lan.pressed.connect(func(): _transition_to(NetworkManager.go_to_lobby))
	nav_v.add_child(btn_join_lan)

	var btn_quick_host := _make_arcade_button("QUICK HOST WIFI ROOM", Color(0.98, 0.58, 0.16), 60.0, 18, Color(0.26, 0.15, 0.06, 0.96))
	btn_quick_host.pressed.connect(_on_quick_host_pressed)
	nav_v.add_child(btn_quick_host)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 10)
	nav_v.add_child(bottom_row)

	var btn_settings := _make_arcade_button("SETTINGS", Color(0.75, 0.84, 0.96), 54.0, 17)
	btn_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_settings.pressed.connect(func(): _transition_to(NetworkManager.go_to_settings))
	bottom_row.add_child(btn_settings)

	var btn_credits := _make_arcade_button("CREDITS", Color(0.95, 0.78, 0.25), 54.0, 17)
	btn_credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_credits.pressed.connect(_open_credits)
	bottom_row.add_child(btn_credits)

	var btn_quit := _make_arcade_button("QUIT", Color(0.92, 0.30, 0.30), 54.0, 17)
	btn_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quit.pressed.connect(func(): get_tree().quit())
	bottom_row.add_child(btn_quit)

	_build_credits_overlay()
	_build_agent_select_overlay()


func _build_credits_overlay() -> void:
	_credits_overlay = ColorRect.new()
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
	_hub_container.position.y = 24.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hub_container, "modulate:a", 1.0, 0.28)
	tw.tween_property(_hub_container, "position:y", 0.0, 0.28)


func _transition_to(target_fn: Callable) -> void:
	if _transitioning:
		return
	_transitioning = true
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_hub_container, "modulate:a", 0.0, 0.16)
	tw.tween_property(_hub_container, "position:y", -18.0, 0.16)
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
	_agent_select_overlay.visible = false
	add_child(_agent_select_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	_agent_select_overlay.add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.15, 0.98), Color(0.78, 0.42, 1.0, 0.95), 16))
	margin.add_child(panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	panel.add_child(root_v)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 12)
	root_v.add_child(top_row)

	var hdr := Label.new()
	hdr.text = "⚡ AGENT CLASH — SELECT YOUR HERO & ABILITY KIT"
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_theme_font_size_override("font_size", 24)
	hdr.modulate = Color(0.86, 0.65, 1.0)
	top_row.add_child(hdr)

	var close_btn := _make_arcade_button("CLOSE", Color(0.95, 0.42, 0.36), 44.0, 16, Color(0.24, 0.10, 0.12))
	close_btn.custom_minimum_size = Vector2(110, 44)
	close_btn.pressed.connect(_close_agent_select)
	top_row.add_child(close_btn)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 16)
	root_v.add_child(split)

	# Left Kit Preview Column
	var left_card := PanelContainer.new()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_card.size_flags_stretch_ratio = 0.85
	left_card.add_theme_stylebox_override("panel", _make_style(Color(0.04, 0.06, 0.11, 0.96), Color(0.32, 0.62, 0.98, 0.8), 12))
	split.add_child(left_card)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left_card.add_child(lv)

	_agent_kit_title = Label.new()
	_agent_kit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_agent_kit_title.add_theme_font_size_override("font_size", 22)
	_agent_kit_title.modulate = Color(1.0, 0.86, 0.34)
	lv.add_child(_agent_kit_title)

	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 150)
	stage.add_theme_stylebox_override("panel", _make_style(Color(0.03, 0.04, 0.08, 0.96), Color(0.24, 0.36, 0.56, 0.7), 10))
	lv.add_child(stage)

	var anchor_wrap := Control.new()
	stage.add_child(anchor_wrap)
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_CENTER)
	anchor_wrap.add_child(anchor)

	_agent_preview = SoldierPreview.new()
	_agent_preview.scale = Vector2(3.6, 3.6)
	anchor.add_child(_agent_preview)

	_agent_kit_body = Label.new()
	_agent_kit_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_agent_kit_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_agent_kit_body.add_theme_font_size_override("font_size", 14)
	_agent_kit_body.modulate = Color(0.84, 0.94, 1.0)
	lv.add_child(_agent_kit_body)

	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 10)
	lv.add_child(act_row)

	var play_solo_btn := _make_arcade_button("▶ PLAY AGENT CLASH", Color(0.30, 0.92, 0.48), 52.0, 17, Color(0.09, 0.30, 0.16))
	play_solo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_solo_btn.pressed.connect(func():
		NetworkManager.disconnect_network()
		NetworkManager.match_mode = 2
		_close_agent_select()
		_transition_to(NetworkManager.go_to_arena)
	)
	act_row.add_child(play_solo_btn)

	var lobby_btn := _make_arcade_button("WIFI LOBBY", Color(0.32, 0.78, 1.0), 52.0, 16, Color(0.10, 0.22, 0.36))
	lobby_btn.custom_minimum_size = Vector2(145, 52)
	lobby_btn.pressed.connect(func():
		NetworkManager.match_mode = 2
		_close_agent_select()
		_transition_to(NetworkManager.go_to_lobby)
	)
	act_row.add_child(lobby_btn)

	# Right 24-Agent Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.15
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	_agent_cards.clear()
	for i in range(AgentData.AGENTS.size()):
		var ag: Dictionary = AgentData.AGENTS[i]
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(0, 62)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.add_theme_font_size_override("font_size", 14)
		cb.text = "%s\n(%s)" % [str(ag["agent_name"]), str(ag["title"])]
		cb.pressed.connect(_select_agent.bind(i))
		grid.add_child(cb)
		_agent_cards.append(cb)

	_refresh_agent_select_ui()


func _select_agent(idx: int) -> void:
	ProfileManager.apply_archetype_preset(idx, true)
	if is_instance_valid(_preview):
		_preview.refresh_from_profile()
	_refresh_agent_select_ui()


func _refresh_agent_select_ui() -> void:
	var idx: int = clampi(ProfileManager.archetype_id, 0, AgentData.AGENTS.size() - 1)
	var ag: Dictionary = AgentData.get_agent(idx)
	var bw: Dictionary = ag["base_weapon"]
	var abils: Array = ag["abilities"]
	var ult: Dictionary = ag["ultimate"]
	if is_instance_valid(_agent_kit_title):
		_agent_kit_title.text = "%s — %s" % [str(ag["agent_name"]).to_upper(), str(ag["role"])]
	if is_instance_valid(_agent_preview):
		_agent_preview.refresh_from_profile()
	if is_instance_valid(_agent_kit_body):
		_agent_kit_body.text = (
			"∞ BASE WEAPON: %s (%d DMG)\n" % [str(bw["name"]), int(bw["damage"])]
			+ "[Q] %s (%.1fs): %s\n" % [str(abils[0]["name"]), float(abils[0]["cooldown"]), str(abils[0]["desc"])]
			+ "[E] %s (%.1fs): %s\n" % [str(abils[1]["name"]), float(abils[1]["cooldown"]), str(abils[1]["desc"])]
			+ "[C] %s (%.1fs): %s\n" % [str(abils[2]["name"]), float(abils[2]["cooldown"]), str(abils[2]["desc"])]
			+ "★ ULTIMATE [X] (%.0fs): %s — %s\n" % [float(ult["cooldown"]), str(ult["name"]), str(ult["desc"])]
			+ "Ground Axes/Swords spawn across the map — grab & throw with [F]!"
		)
	for i in range(_agent_cards.size()):
		var is_sel: bool = (i == idx)
		var ac: Color = ag["accent"] as Color
		var bg_c: Color = Color(0.22, 0.14, 0.34) if is_sel else Color(0.10, 0.14, 0.22)
		var bd_c: Color = ac if is_sel else Color(0.28, 0.42, 0.62)
		_agent_cards[i].add_theme_stylebox_override("normal", _make_style(bg_c, bd_c, 8))
		_agent_cards[i].add_theme_stylebox_override("hover", _make_style(bg_c.lightened(0.14), bd_c.lightened(0.25), 8))
		_agent_cards[i].add_theme_stylebox_override("pressed", _make_style(bd_c.darkened(0.35), bd_c, 8))


func _open_agent_select() -> void:
	_refresh_agent_select_ui()
	_agent_select_overlay.visible = true
	_agent_select_overlay.modulate.a = 0.0
	create_tween().tween_property(_agent_select_overlay, "modulate:a", 1.0, 0.16)


func _close_agent_select() -> void:
	if is_instance_valid(_agent_select_overlay):
		_agent_select_overlay.visible = false
