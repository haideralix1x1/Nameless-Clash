extends Control

const TEX_BG: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const TEX_ICON: Texture2D = preload("res://icon.svg")

var _hub_container: Control
var _credits_overlay: Control
var _preview: SoldierPreview
var _callsign_label: Label
var _loadout_label: Label
var _transitioning: bool = false


func _ready() -> void:
	_build_ui()
	_play_enter_animation()


func _make_style(bg: Color, border: Color, corner: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(corner)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb


func _make_arcade_button(text_str: String, accent: Color, min_h: float = 54.0, font_sz: int = 18, fill_bg: Color = Color(0.11, 0.15, 0.22, 0.95)) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = Vector2(0, min_h)
	btn.add_theme_font_size_override("font_size", font_sz)

	var normal := _make_style(fill_bg, accent, 10)
	var hover := _make_style(fill_bg.lightened(0.14), accent.lightened(0.35), 10)
	var pressed := _make_style(accent.darkened(0.45), accent.lightened(0.5), 10)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
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
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.modulate = Color(1.0, 0.84, 0.28)
	title_v.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "2D MULTIPLAYER ARENA SHOOTER"
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.modulate = Color(0.68, 0.88, 1.0)
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
	preview_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.92), Color(0.82, 0.48, 1.0, 0.88), 14))
	split.add_child(preview_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	preview_panel.add_child(pv)

	var p_hdr := Label.new()
	p_hdr.text = "YOUR SOLDIER"
	p_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_hdr.add_theme_font_size_override("font_size", 16)
	p_hdr.modulate = Color(0.86, 0.68, 1.0)
	pv.add_child(p_hdr)

	_callsign_label = Label.new()
	_callsign_label.text = ProfileManager.player_name.to_upper()
	_callsign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_callsign_label.add_theme_font_size_override("font_size", 26)
	_callsign_label.modulate = Color(1.0, 0.86, 0.34)
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
	_loadout_label.modulate = Color(0.78, 0.92, 1.0)
	var arch_name: String = ProfileManager.ARCHETYPES[ProfileManager.archetype_id]["name"]
	var pri_weapon: WeaponData = WeaponData.get_weapon(ProfileManager.primary_weapon_id, ProfileManager.weapon_skin_id, ProfileManager.m4a1_rail_mod)
	var sec_weapon: WeaponData = WeaponData.get_weapon(ProfileManager.secondary_weapon_id, ProfileManager.weapon_skin_id, 0)
	_loadout_label.text = "%s\n%s  +  %s" % [arch_name, pri_weapon.display_name, sec_weapon.display_name]
	pv.add_child(_loadout_label)

	var edit_avatar_btn := _make_arcade_button("CUSTOMIZE HERO & WEAPONS", Color(0.82, 0.48, 1.0), 58.0, 18, Color(0.18, 0.11, 0.28, 0.96))
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
	nav_hdr.modulate = Color(0.55, 0.86, 1.0)
	nav_v.add_child(nav_hdr)

	var btn_solo := _make_arcade_button("▶  PLAY SOLO (VS BOTS)", Color(0.30, 0.92, 0.48), 74.0, 22, Color(0.09, 0.28, 0.16, 0.98))
	btn_solo.pressed.connect(func():
		NetworkManager.disconnect_network()
		_transition_to(NetworkManager.go_to_arena)
	)
	nav_v.add_child(btn_solo)

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
		+ "Visit Hero & Armory to customize 10 unique Soldiers\n"
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
