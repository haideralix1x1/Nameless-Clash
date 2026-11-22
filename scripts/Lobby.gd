extends Control

const UIStyle = preload("res://scripts/UIStyle.gd")
const TEX_BG: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")

var _name_input: LineEdit
var _room_input: LineEdit
var _ip_input: LineEdit
var _status_label: Label
var _room_ip_banner: Label
var _players_box: GridContainer
var _lan_list_box: VBoxContainer
var _start_btn: Button
var _make_leader_btn: Button
var _ready_btn: Button
var _selected_peer_id: int = -1
var _local_ready: bool = true
var _wait_host_label: Label
var _host_btn: Button
var _join_btn: Button
var _join_row: HBoxContainer
var _disconnect_btn: Button
var _mode_opt: OptionButton
var _map_opt: OptionButton
var _team_toggle_btn: Button
var _bot_minus_btn: Button
var _bot_plus_btn: Button
var _bot_count_label: Label
var _bot_diff_opt: OptionButton
var _local_bot_count: int = 3

var _chk_unlimited_jetpack: CheckBox
var _chk_random_guns: CheckBox
var _chk_only_pistols: CheckBox
var _chk_allow_snipers: CheckBox
var _chk_allow_shotguns: CheckBox
var _chk_allow_explosives: CheckBox
var _gravity_slider: HSlider
var _gravity_val_lbl: Label
var _jet_speed_slider: HSlider
var _jet_speed_val_lbl: Label
var _syncing_rules_ui: bool = false
var _left_panel: PanelContainer
var _lan_sep: HSeparator
var _lan_hdr: Label
var _lan_scroll: ScrollContainer

var _draft_overlay: ColorRect
var _draft_timer_lbl: Label
var _draft_roster_box: VBoxContainer
var _draft_agent_btns: Array[Button] = []
var _draft_info_lbl: Label
var _draft_lock_btn: Button
var _draft_selected_arch: int = 0


func _ready() -> void:
	if not NetworkManager.is_network_active():
		NetworkManager.bot_count = 0
	_local_bot_count = NetworkManager.bot_count
	_build_ui()
	_build_draft_overlay()
	NetworkManager.player_list_updated.connect(_refresh_players)
	NetworkManager.match_settings_updated.connect(_refresh_match_settings_ui)
	NetworkManager.game_rules_updated.connect(_refresh_rules_ui)
	NetworkManager.lan_servers_updated.connect(_refresh_lan_servers)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_conn_failed)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	NetworkManager.agent_draft_started.connect(_on_agent_draft_started)
	NetworkManager.agent_draft_updated.connect(_refresh_agent_draft_ui)

	NetworkManager.start_lan_discovery()
	_refresh_players()
	_refresh_match_settings_ui()
	_refresh_controls_state()


func _exit_tree() -> void:
	NetworkManager.stop_lan_discovery()


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


func _style_button(btn: Button, _bg: Color, border: Color, _corner: int = 10) -> void:
	UIStyle.style_layer_button(btn, _variant_for_color(border), "", 14, 10)


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

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root_v.add_child(header)

	var menu_btn := Button.new()
	menu_btn.text = "< MENU"
	menu_btn.custom_minimum_size = Vector2(126, 50)
	menu_btn.add_theme_font_size_override("font_size", 18)
	_style_button(menu_btn, Color(0.14, 0.18, 0.26, 0.95), Color(0.55, 0.72, 0.95))
	menu_btn.pressed.connect(func(): NetworkManager.go_to_main_menu())
	header.add_child(menu_btn)

	var title := Label.new()
	title.text = "WIFI MULTIPLAYER"
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color(1.0, 0.84, 0.28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var garage_btn := Button.new()
	garage_btn.text = "CUSTOMIZE HERO"
	garage_btn.custom_minimum_size = Vector2(190, 50)
	garage_btn.add_theme_font_size_override("font_size", 17)
	_style_button(garage_btn, Color(0.20, 0.12, 0.30, 0.95), Color(0.82, 0.48, 1.0))
	garage_btn.pressed.connect(func(): NetworkManager.go_to_avatar_garage())
	header.add_child(garage_btn)

	# Room Status Bar
	var status_panel := PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", _make_style(Color(0.06, 0.09, 0.14, 0.92), Color(0.28, 0.65, 0.95, 0.85)))
	root_v.add_child(status_panel)

	var sr_row := HBoxContainer.new()
	status_panel.add_child(sr_row)

	_status_label = Label.new()
	_status_label.text = "Host a room or tap a nearby Wi-Fi game to join!"
	_status_label.modulate = Color(0.75, 0.92, 1.0)
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sr_row.add_child(_status_label)

	_room_ip_banner = Label.new()
	_room_ip_banner.text = "Room IP: " + NetworkManager.get_primary_local_ip()
	_room_ip_banner.modulate = Color(0.55, 0.98, 0.72)
	_room_ip_banner.add_theme_font_size_override("font_size", 16)
	sr_row.add_child(_room_ip_banner)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root_v.add_child(cols)

	# Left Column: Match Setup & Connect
	_left_panel = PanelContainer.new()
	_left_panel.custom_minimum_size = Vector2(310, 0)
	_left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_panel.add_theme_stylebox_override("panel", _make_style(Color(0.07, 0.1, 0.16, 0.94), Color(0.26, 0.58, 0.9, 0.88)))
	cols.add_child(_left_panel)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_left_panel.add_child(left_scroll)

	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_theme_constant_override("separation", 10)
	left_scroll.add_child(lv)

	var name_row := HBoxContainer.new()
	lv.add_child(name_row)
	var name_lbl := Label.new()
	name_lbl.text = "Your Name:"
	name_lbl.custom_minimum_size = Vector2(115, 0)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_row.add_child(name_lbl)
	_name_input = LineEdit.new()
	_name_input.text = ProfileManager.player_name
	_name_input.custom_minimum_size = Vector2(0, 42)
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text_changed.connect(func(new_t: String):
		NetworkManager.update_local_profile(new_t, NetworkManager.local_color_index)
	)
	name_row.add_child(_name_input)

	var room_row := HBoxContainer.new()
	lv.add_child(room_row)
	var room_lbl := Label.new()
	room_lbl.text = "Room Name:"
	room_lbl.custom_minimum_size = Vector2(115, 0)
	room_lbl.add_theme_font_size_override("font_size", 16)
	room_row.add_child(room_lbl)
	_room_input = LineEdit.new()
	_room_input.text = NetworkManager.local_room_name
	_room_input.custom_minimum_size = Vector2(0, 42)
	_room_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_row.add_child(_room_input)

	lv.add_child(HSeparator.new())

	var match_hdr := Label.new()
	match_hdr.text = "MATCH SETTINGS"
	match_hdr.add_theme_font_size_override("font_size", 16)
	match_hdr.modulate = Color(1.0, 0.80, 0.28)
	lv.add_child(match_hdr)

	var mode_row := HBoxContainer.new()
	lv.add_child(mode_row)
	var mode_lbl := Label.new()
	mode_lbl.text = "Game Mode:"
	mode_lbl.custom_minimum_size = Vector2(115, 0)
	mode_lbl.add_theme_font_size_override("font_size", 15)
	mode_row.add_child(mode_lbl)
	_mode_opt = OptionButton.new()
	_mode_opt.custom_minimum_size = Vector2(0, 44)
	for m_name in NetworkManager.MODE_NAMES:
		_mode_opt.add_item(m_name)
	_mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_opt.item_selected.connect(_on_match_config_changed)
	mode_row.add_child(_mode_opt)

	var team_row := HBoxContainer.new()
	lv.add_child(team_row)
	var team_lbl := Label.new()
	team_lbl.text = "Your Team:"
	team_lbl.custom_minimum_size = Vector2(115, 0)
	team_lbl.add_theme_font_size_override("font_size", 15)
	team_row.add_child(team_lbl)
	_team_toggle_btn = Button.new()
	_team_toggle_btn.custom_minimum_size = Vector2(0, 44)
	_team_toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_toggle_btn.add_theme_font_size_override("font_size", 16)
	_team_toggle_btn.pressed.connect(_on_toggle_team_pressed)
	team_row.add_child(_team_toggle_btn)

	var map_row := HBoxContainer.new()
	lv.add_child(map_row)
	var map_lbl := Label.new()
	map_lbl.text = "Battle Map:"
	map_lbl.custom_minimum_size = Vector2(115, 0)
	map_lbl.add_theme_font_size_override("font_size", 15)
	map_row.add_child(map_lbl)
	_map_opt = OptionButton.new()
	_map_opt.custom_minimum_size = Vector2(0, 44)
	for map_name in NetworkManager.MAP_NAMES:
		_map_opt.add_item(map_name)
	_map_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_opt.item_selected.connect(_on_match_config_changed)
	map_row.add_child(_map_opt)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 8)
	lv.add_child(bot_row)
	var bot_lbl := Label.new()
	bot_lbl.text = "AI Bots:"
	bot_lbl.custom_minimum_size = Vector2(115, 0)
	bot_lbl.add_theme_font_size_override("font_size", 15)
	bot_row.add_child(bot_lbl)

	_bot_minus_btn = Button.new()
	_bot_minus_btn.text = "-"
	_bot_minus_btn.custom_minimum_size = Vector2(48, 44)
	_bot_minus_btn.add_theme_font_size_override("font_size", 20)
	_style_button(_bot_minus_btn, Color(0.14, 0.20, 0.30), Color(0.45, 0.72, 0.98))
	_bot_minus_btn.pressed.connect(_step_bot_count.bind(-1))
	bot_row.add_child(_bot_minus_btn)

	_bot_count_label = Label.new()
	_bot_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bot_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bot_count_label.add_theme_font_size_override("font_size", 17)
	_bot_count_label.modulate = Color(1.0, 0.88, 0.42)
	bot_row.add_child(_bot_count_label)

	_bot_plus_btn = Button.new()
	_bot_plus_btn.text = "+"
	_bot_plus_btn.custom_minimum_size = Vector2(48, 44)
	_bot_plus_btn.add_theme_font_size_override("font_size", 20)
	_style_button(_bot_plus_btn, Color(0.14, 0.20, 0.30), Color(0.45, 0.72, 0.98))
	_bot_plus_btn.pressed.connect(_step_bot_count.bind(1))
	bot_row.add_child(_bot_plus_btn)

	var bot_diff_row := HBoxContainer.new()
	lv.add_child(bot_diff_row)
	var bot_diff_lbl := Label.new()
	bot_diff_lbl.text = "Bot Level:"
	bot_diff_lbl.custom_minimum_size = Vector2(115, 0)
	bot_diff_lbl.add_theme_font_size_override("font_size", 15)
	bot_diff_row.add_child(bot_diff_lbl)
	_bot_diff_opt = OptionButton.new()
	_bot_diff_opt.custom_minimum_size = Vector2(0, 44)
	for d_name in NetworkManager.BOT_DIFFICULTY_NAMES:
		_bot_diff_opt.add_item(d_name)
	_bot_diff_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bot_diff_opt.item_selected.connect(_on_match_config_changed)
	bot_diff_row.add_child(_bot_diff_opt)

	lv.add_child(HSeparator.new())

	var rules_hdr := Label.new()
	rules_hdr.text = "MATCH RULES & WEAPON LIMITS"
	rules_hdr.add_theme_font_size_override("font_size", 14)
	rules_hdr.modulate = Color(0.68, 0.90, 1.0)
	lv.add_child(rules_hdr)

	var grav_row := HBoxContainer.new()
	grav_row.add_theme_constant_override("separation", 8)
	lv.add_child(grav_row)
	var grav_lbl := Label.new()
	grav_lbl.text = "Gravity (0-1):"
	grav_lbl.custom_minimum_size = Vector2(115, 0)
	grav_lbl.add_theme_font_size_override("font_size", 14)
	grav_row.add_child(grav_lbl)
	_gravity_slider = HSlider.new()
	_gravity_slider.min_value = 0.0
	_gravity_slider.max_value = 1.0
	_gravity_slider.step = 0.05
	_gravity_slider.value = NetworkManager.gravity_scale
	_gravity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gravity_slider.value_changed.connect(func(v: float):
		if is_instance_valid(_gravity_val_lbl):
			_gravity_val_lbl.text = "%.2fx" % v
		_on_rules_ui_changed()
	)
	grav_row.add_child(_gravity_slider)
	_gravity_val_lbl = Label.new()
	_gravity_val_lbl.text = "%.2fx" % NetworkManager.gravity_scale
	_gravity_val_lbl.custom_minimum_size = Vector2(52, 0)
	_gravity_val_lbl.add_theme_font_size_override("font_size", 14)
	grav_row.add_child(_gravity_val_lbl)

	var jet_row := HBoxContainer.new()
	jet_row.add_theme_constant_override("separation", 8)
	lv.add_child(jet_row)
	var jet_lbl := Label.new()
	jet_lbl.text = "Jet Speed (0.1-1):"
	jet_lbl.custom_minimum_size = Vector2(115, 0)
	jet_lbl.add_theme_font_size_override("font_size", 14)
	jet_row.add_child(jet_lbl)
	_jet_speed_slider = HSlider.new()
	_jet_speed_slider.min_value = 0.1
	_jet_speed_slider.max_value = 1.0
	_jet_speed_slider.step = 0.05
	_jet_speed_slider.value = NetworkManager.jet_speed_scale
	_jet_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jet_speed_slider.value_changed.connect(func(v: float):
		if is_instance_valid(_jet_speed_val_lbl):
			_jet_speed_val_lbl.text = "%.2fx" % v
		_on_rules_ui_changed()
	)
	jet_row.add_child(_jet_speed_slider)
	_jet_speed_val_lbl = Label.new()
	_jet_speed_val_lbl.text = "%.2fx" % NetworkManager.jet_speed_scale
	_jet_speed_val_lbl.custom_minimum_size = Vector2(52, 0)
	_jet_speed_val_lbl.add_theme_font_size_override("font_size", 14)
	jet_row.add_child(_jet_speed_val_lbl)

	var rules_grid := GridContainer.new()
	rules_grid.columns = 2
	rules_grid.add_theme_constant_override("h_separation", 8)
	rules_grid.add_theme_constant_override("v_separation", 4)
	lv.add_child(rules_grid)

	_chk_unlimited_jetpack = _make_rule_checkbox("Unlimited Jetpack", NetworkManager.unlimited_jetpack)
	rules_grid.add_child(_chk_unlimited_jetpack)
	_chk_random_guns = _make_rule_checkbox("Random Guns", NetworkManager.random_guns_mode)
	rules_grid.add_child(_chk_random_guns)
	_chk_only_pistols = _make_rule_checkbox("Pistols Only", NetworkManager.only_pistols)
	rules_grid.add_child(_chk_only_pistols)
	_chk_allow_snipers = _make_rule_checkbox("Allow Snipers", NetworkManager.allow_snipers)
	rules_grid.add_child(_chk_allow_snipers)
	_chk_allow_shotguns = _make_rule_checkbox("Allow Shotguns", NetworkManager.allow_shotguns)
	rules_grid.add_child(_chk_allow_shotguns)
	_chk_allow_explosives = _make_rule_checkbox("Allow Explosives", NetworkManager.allow_explosives)
	rules_grid.add_child(_chk_allow_explosives)

	lv.add_child(HSeparator.new())

	_host_btn = Button.new()
	_host_btn.text = "CREATE WIFI ROOM"
	_host_btn.custom_minimum_size = Vector2(0, 52)
	_host_btn.add_theme_font_size_override("font_size", 18)
	_style_button(_host_btn, Color(0.26, 0.15, 0.06, 0.96), Color(0.98, 0.58, 0.16))
	_host_btn.pressed.connect(_on_host_pressed)
	lv.add_child(_host_btn)

	_join_row = HBoxContainer.new()
	_join_row.add_theme_constant_override("separation", 8)
	lv.add_child(_join_row)
	_ip_input = LineEdit.new()
	_ip_input.placeholder_text = "Enter Friend's IP"
	_ip_input.text = NetworkManager.get_primary_local_ip()
	_ip_input.custom_minimum_size = Vector2(0, 48)
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_join_row.add_child(_ip_input)
	_join_btn = Button.new()
	_join_btn.text = "JOIN GAME"
	_join_btn.custom_minimum_size = Vector2(130, 48)
	_join_btn.add_theme_font_size_override("font_size", 16)
	_style_button(_join_btn, Color(0.10, 0.22, 0.36, 0.95), Color(0.28, 0.74, 1.0))
	_join_btn.pressed.connect(_on_join_pressed)
	_join_row.add_child(_join_btn)

	_disconnect_btn = Button.new()
	_disconnect_btn.text = "LEAVE ROOM"
	_disconnect_btn.custom_minimum_size = Vector2(0, 46)
	_disconnect_btn.add_theme_font_size_override("font_size", 16)
	_style_button(_disconnect_btn, Color(0.26, 0.10, 0.12, 0.94), Color(0.92, 0.32, 0.32))
	_disconnect_btn.pressed.connect(_on_disconnect_pressed)
	lv.add_child(_disconnect_btn)

	# Right Column: Player Slots + Nearby Rooms + Big Start Battle Button
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_style(Color(0.07, 0.1, 0.16, 0.94), Color(0.95, 0.56, 0.16, 0.88)))
	cols.add_child(right_panel)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right_panel.add_child(rv)

	var slots_hdr := Label.new()
	slots_hdr.text = "SQUAD SLOTS"
	slots_hdr.add_theme_font_size_override("font_size", 16)
	slots_hdr.modulate = Color(1.0, 0.82, 0.35)
	rv.add_child(slots_hdr)

	_players_box = GridContainer.new()
	_players_box.columns = 4
	_players_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_players_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_players_box.add_theme_constant_override("h_separation", 8)
	_players_box.add_theme_constant_override("v_separation", 8)
	rv.add_child(_players_box)

	_lan_sep = HSeparator.new()
	rv.add_child(_lan_sep)

	_lan_hdr = Label.new()
	_lan_hdr.text = "NEARBY WI-FI GAMES"
	_lan_hdr.add_theme_font_size_override("font_size", 16)
	_lan_hdr.modulate = Color(0.55, 0.90, 1.0)
	rv.add_child(_lan_hdr)

	_lan_scroll = ScrollContainer.new()
	_lan_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(_lan_scroll)

	_lan_list_box = VBoxContainer.new()
	_lan_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_scroll.add_child(_lan_list_box)

	var empty_lan := Label.new()
	empty_lan.text = "Searching for nearby Wi-Fi rooms..."
	empty_lan.modulate = Color(0.7, 0.78, 0.88)
	_lan_list_box.add_child(empty_lan)

	_wait_host_label = Label.new()
	_wait_host_label.text = "Waiting for Leader to start battle..."
	_wait_host_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wait_host_label.add_theme_font_size_override("font_size", 17)
	_wait_host_label.modulate = Color(1.0, 0.82, 0.35)
	_wait_host_label.visible = false
	rv.add_child(_wait_host_label)

	var r_act_row := HBoxContainer.new()
	r_act_row.add_theme_constant_override("separation", 10)
	rv.add_child(r_act_row)

	_make_leader_btn = Button.new()
	_make_leader_btn.text = "MAKE LEADER"
	_make_leader_btn.custom_minimum_size = Vector2(0, 52)
	_make_leader_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_leader_btn.add_theme_font_size_override("font_size", 17)
	_style_button(_make_leader_btn, Color(0.24, 0.18, 0.06, 0.96), Color(1.0, 0.78, 0.22))
	_make_leader_btn.pressed.connect(func():
		if _selected_peer_id > 0:
			NetworkManager.transfer_leadership(_selected_peer_id)
	)
	r_act_row.add_child(_make_leader_btn)

	_ready_btn = Button.new()
	_ready_btn.text = "READY"
	_ready_btn.custom_minimum_size = Vector2(0, 56)
	_ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_btn.add_theme_font_size_override("font_size", 19)
	_style_button(_ready_btn, Color(0.09, 0.30, 0.16, 0.96), Color(0.30, 0.92, 0.48))
	_ready_btn.pressed.connect(func():
		_local_ready = not _local_ready
		NetworkManager.set_local_ready(_local_ready)
		_refresh_controls_state()
	)
	r_act_row.add_child(_ready_btn)

	_start_btn = Button.new()
	_start_btn.text = "START BATTLE"
	_start_btn.custom_minimum_size = Vector2(0, 56)
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.add_theme_font_size_override("font_size", 20)
	_style_button(_start_btn, Color(0.09, 0.32, 0.16, 0.98), Color(0.28, 0.92, 0.45))
	_start_btn.pressed.connect(_on_start_pressed)
	r_act_row.add_child(_start_btn)


func _step_bot_count(delta_step: int) -> void:
	if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
		return
	_local_bot_count = clampi(_local_bot_count + delta_step, 0, NetworkManager.MAX_BOTS)
	_on_match_config_changed(0)


func _on_match_config_changed(_idx: int) -> void:
	if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
		return
	var diff_idx: int = _bot_diff_opt.selected if is_instance_valid(_bot_diff_opt) else NetworkManager.bot_difficulty
	NetworkManager.host_update_match_settings(
		_mode_opt.selected,
		_map_opt.selected,
		_local_bot_count,
		diff_idx
	)
	_refresh_bot_label()
	_refresh_players()


func _refresh_bot_label() -> void:
	if is_instance_valid(_bot_count_label):
		_bot_count_label.text = "%d / %d Bots" % [_local_bot_count, NetworkManager.MAX_BOTS]


func _on_toggle_team_pressed() -> void:
	var max_teams: int = maxi(2, NetworkManager.team_count)
	var next_team: int = (NetworkManager.local_team + 1) % max_teams
	NetworkManager.set_local_team(next_team)
	_refresh_team_button()


func _refresh_team_button() -> void:
	var max_teams: int = maxi(2, NetworkManager.team_count)
	var t_idx: int = clampi(NetworkManager.local_team, 0, max_teams - 1)
	var t_name: String = NetworkManager.TEAM_NAMES[t_idx] if t_idx < NetworkManager.TEAM_NAMES.size() else "Team %d" % (t_idx + 1)
	_team_toggle_btn.text = "%s (Tap to Switch)" % t_name.to_upper()
	_team_toggle_btn.modulate = NetworkManager.get_team_color(t_idx)


func _on_host_pressed() -> void:
	NetworkManager.update_local_profile(_name_input.text, NetworkManager.local_color_index)
	var err: Error = NetworkManager.host_game(_room_input.text)
	if err == OK:
		_status_label.text = "Room '%s' is LIVE! Friends can join %s" % [NetworkManager.local_room_name, NetworkManager.get_primary_local_ip()]
	_refresh_controls_state()


func _on_join_pressed() -> void:
	NetworkManager.update_local_profile(_name_input.text, NetworkManager.local_color_index)
	var target_ip: String = _ip_input.text.strip_edges()
	_status_label.text = "Joining %s..." % target_ip
	NetworkManager.join_game(target_ip)
	_refresh_controls_state()


func _on_disconnect_pressed() -> void:
	NetworkManager.disconnect_network()
	NetworkManager.go_to_main_menu()


func _on_start_pressed() -> void:
	if NetworkManager.is_network_active() and not NetworkManager.are_all_players_ready():
		if is_instance_valid(_status_label):
			_status_label.text = "All players must be READY before starting!"
		return
	NetworkManager.request_start_match()


func _on_connected() -> void:
	if NetworkManager.is_host_active():
		_status_label.text = "Hosting LIVE! Share Room IP: " + NetworkManager.get_primary_local_ip()
	else:
		_status_label.text = "Connected to Host! Ready to fight."
	_refresh_controls_state()


func _on_conn_failed(reason: String) -> void:
	_status_label.text = "Could not connect: " + reason
	_refresh_controls_state()


func _on_server_disconnected() -> void:
	_status_label.text = "Host closed the room."
	_refresh_controls_state()


func _refresh_match_settings_ui() -> void:
	_mode_opt.selected = NetworkManager.match_mode
	_map_opt.selected = NetworkManager.selected_map_id
	_local_bot_count = NetworkManager.bot_count
	if is_instance_valid(_bot_diff_opt):
		_bot_diff_opt.selected = clampi(NetworkManager.bot_difficulty, 0, 2)
	_refresh_bot_label()
	_refresh_rules_ui()
	_refresh_team_button()
	_refresh_controls_state()


func _make_rule_checkbox(title_txt: String, initial: bool) -> CheckBox:
	var chk := CheckBox.new()
	chk.text = title_txt
	chk.button_pressed = initial
	chk.add_theme_font_size_override("font_size", 13)
	chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk.toggled.connect(func(_on: bool): _on_rules_ui_changed())
	return chk


func _on_rules_ui_changed() -> void:
	if _syncing_rules_ui:
		return
	if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
		return
	SettingsManager.unlimited_jetpack = _chk_unlimited_jetpack.button_pressed
	if is_instance_valid(_chk_random_guns):
		SettingsManager.random_guns_mode = _chk_random_guns.button_pressed
	SettingsManager.only_pistols = _chk_only_pistols.button_pressed
	SettingsManager.allow_snipers = _chk_allow_snipers.button_pressed
	SettingsManager.allow_shotguns = _chk_allow_shotguns.button_pressed
	SettingsManager.allow_explosives = _chk_allow_explosives.button_pressed
	SettingsManager.gravity_scale = clampf(float(_gravity_slider.value), 0.0, 1.0)
	if is_instance_valid(_jet_speed_slider):
		SettingsManager.jet_speed_scale = clampf(float(_jet_speed_slider.value), 0.1, 1.0)
	SettingsManager.apply_and_save()


func _refresh_rules_ui() -> void:
	if not is_instance_valid(_chk_unlimited_jetpack):
		return
	_syncing_rules_ui = true
	_chk_unlimited_jetpack.button_pressed = NetworkManager.unlimited_jetpack
	if is_instance_valid(_chk_random_guns):
		_chk_random_guns.button_pressed = NetworkManager.random_guns_mode
	_chk_only_pistols.button_pressed = NetworkManager.only_pistols
	_chk_allow_snipers.button_pressed = NetworkManager.allow_snipers
	_chk_allow_shotguns.button_pressed = NetworkManager.allow_shotguns
	_chk_allow_explosives.button_pressed = NetworkManager.allow_explosives
	_gravity_slider.value = clampf(NetworkManager.gravity_scale, 0.0, 1.0)
	if is_instance_valid(_gravity_val_lbl):
		_gravity_val_lbl.text = "%.2fx" % _gravity_slider.value
	if is_instance_valid(_jet_speed_slider):
		_jet_speed_slider.value = clampf(NetworkManager.jet_speed_scale, 0.1, 1.0)
	if is_instance_valid(_jet_speed_val_lbl) and is_instance_valid(_jet_speed_slider):
		_jet_speed_val_lbl.text = "%.2fx" % _jet_speed_slider.value
	_syncing_rules_ui = false


func _refresh_controls_state() -> void:
	var net_active: bool = NetworkManager.is_network_active()
	var is_host: bool = NetworkManager.is_host_active()
	var is_leader: bool = NetworkManager.is_local_leader()
	var can_edit_match: bool = (not net_active) or is_leader

	if is_instance_valid(_host_btn):
		_host_btn.visible = not net_active
	if is_instance_valid(_join_row):
		_join_row.visible = not net_active

	if is_instance_valid(_left_panel):
		_left_panel.visible = not net_active
	if is_instance_valid(_lan_sep):
		_lan_sep.visible = not net_active
	if is_instance_valid(_lan_hdr):
		_lan_hdr.visible = not net_active
	if is_instance_valid(_lan_scroll):
		_lan_scroll.visible = not net_active

	var all_ready: bool = NetworkManager.are_all_players_ready()
	_start_btn.visible = (not net_active) or is_leader
	_start_btn.disabled = net_active and not all_ready
	_wait_host_label.visible = false
	if is_leader:
		_start_btn.text = ("START BATTLE (%d/%d)" % [NetworkManager.players.size(), NetworkManager.max_room_players]) if all_ready else "WAITING FOR READY..."
	else:
		_start_btn.text = "START BATTLE"

	if is_instance_valid(_make_leader_btn):
		_make_leader_btn.visible = false
	if is_instance_valid(_ready_btn):
		_ready_btn.visible = net_active and not is_leader
		_ready_btn.text = "READY" if _local_ready else "NOT READY"
		if _local_ready:
			_style_button(_ready_btn, Color(0.09, 0.30, 0.16, 0.96), Color(0.30, 0.92, 0.48))
		else:
			_style_button(_ready_btn, Color(0.24, 0.16, 0.08, 0.96), Color(0.98, 0.68, 0.22))

	_mode_opt.disabled = not can_edit_match
	_map_opt.disabled = not can_edit_match
	_bot_minus_btn.disabled = not can_edit_match
	_bot_plus_btn.disabled = not can_edit_match
	if is_instance_valid(_bot_diff_opt):
		_bot_diff_opt.disabled = not can_edit_match
	if is_instance_valid(_chk_unlimited_jetpack):
		_chk_unlimited_jetpack.disabled = not can_edit_match
		if is_instance_valid(_chk_random_guns):
			_chk_random_guns.disabled = not can_edit_match
		_chk_only_pistols.disabled = not can_edit_match
		_chk_allow_snipers.disabled = not can_edit_match
		_chk_allow_shotguns.disabled = not can_edit_match
		_chk_allow_explosives.disabled = not can_edit_match
		_gravity_slider.editable = can_edit_match
		if is_instance_valid(_jet_speed_slider):
			_jet_speed_slider.editable = can_edit_match
	_room_ip_banner.text = "Room IP: " + NetworkManager.get_primary_local_ip()
	_refresh_team_button()


func _refresh_players() -> void:
	for child in _players_box.get_children():
		child.queue_free()

	var ids: Array = NetworkManager.players.keys()
	ids.sort()

	var max_slots: int = clampi(NetworkManager.max_room_players, 2, NetworkManager.MAX_CLIENTS)
	for slot_idx in range(max_slots):
		var box_btn := Button.new()
		box_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box_btn.custom_minimum_size = Vector2(0, 56)
		box_btn.add_theme_font_size_override("font_size", 13)
		var bg_col := Color(0.11, 0.15, 0.22, 0.88)
		var border_col := Color(0.28, 0.36, 0.48, 0.6)
		var slot_text: String = "Slot %d\nOpen" % (slot_idx + 1)

		if slot_idx < ids.size():
			var pid: int = int(ids[slot_idx])
			var info: Dictionary = NetworkManager.players[pid]
			var t_id: int = int(info.get("team", 0))
			var is_ldr: bool = (pid == NetworkManager.leader_peer_id)
			var is_rdy: bool = bool(info.get("ready", true))
			var role: String = "LEADER" if is_ldr else ("READY" if is_rdy else "WAIT")
			var team_txt: String = "FFA" if not NetworkManager.is_team_mode() else NetworkManager.TEAM_NAMES[clampi(t_id, 0, NetworkManager.TEAM_NAMES.size() - 1)]
			border_col = NetworkManager.get_team_color(t_id if NetworkManager.is_team_mode() else int(info.get("color_index", 0)))
			if pid == _selected_peer_id:
				bg_col = Color(0.22, 0.26, 0.14, 0.96)
				border_col = Color(1.0, 0.84, 0.22)
			slot_text = "%s\n%s • %s" % [
				str(info.get("name", "Trooper")),
				role,
				team_txt
			]
			box_btn.pressed.connect(func():
				_selected_peer_id = pid
				_refresh_players()
			)
		else:
			box_btn.disabled = true

		_style_button(box_btn, bg_col, border_col, 8)
		box_btn.text = slot_text
		_players_box.add_child(box_btn)

	_refresh_controls_state()


func _refresh_lan_servers(servers: Array) -> void:
	for child in _lan_list_box.get_children():
		child.queue_free()

	if servers.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Searching for nearby Wi-Fi rooms..."
		empty_lbl.modulate = Color(0.7, 0.78, 0.88)
		_lan_list_box.add_child(empty_lbl)
		return

	for srv in servers:
		var ip: String = str(srv.get("ip", ""))
		var room: String = str(srv.get("room", "Hotspot Arena"))
		var count: int = int(srv.get("players", 1))
		var max_p: int = int(srv.get("max", NetworkManager.MAX_CLIENTS))
		var map_n: String = str(srv.get("map", "Bunker Base"))
		var mode_n: String = str(srv.get("mode", "Free-For-All"))

		var btn := Button.new()
		btn.text = "JOIN  %s  •  %s [%s]  (%d/%d)" % [room, map_n, mode_n, count, max_p]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 16)
		_style_button(btn, Color(0.10, 0.22, 0.36, 0.95), Color(0.28, 0.74, 1.0), 8)
		btn.pressed.connect(func():
			_ip_input.text = ip
			_on_join_pressed()
		)
		_lan_list_box.add_child(btn)


func _process(_delta: float) -> void:
	if is_instance_valid(_draft_overlay) and _draft_overlay.visible and is_instance_valid(_draft_timer_lbl):
		var secs: int = maxi(0, int(ceil(NetworkManager.agent_draft_timer)))
		_draft_timer_lbl.text = "TIME LEFT: %ds" % secs


func _make_draft_agent_icon(arch_idx: int) -> Texture2D:
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
	var base_img: Image = skin_tex.get_image().get_region(Rect2i(0, 0, fw, fh))
	if base_img.get_format() != Image.FORMAT_RGBA8:
		base_img.convert(Image.FORMAT_RGBA8)
	var skin_col: Color = arch.get("skin", Color.WHITE)
	var helm_col: Color = arch.get("helmet", Color.WHITE)
	if skin_col != Color.WHITE:
		for y in range(fh):
			for x in range(fw):
				var p: Color = base_img.get_pixel(x, y)
				if p.a > 0.01:
					base_img.set_pixel(x, y, Color(p.r * skin_col.r, p.g * skin_col.g, p.b * skin_col.b, p.a))
	if head_tex != null:
		var h_fw: int = maxi(1, head_tex.get_width() / 8)
		var h_fh: int = mini(head_tex.get_height(), int(float(head_tex.get_height()) * 0.72))
		var head_img: Image = head_tex.get_image().get_region(Rect2i(0, 0, h_fw, h_fh))
		if head_img.get_format() != Image.FORMAT_RGBA8:
			head_img.convert(Image.FORMAT_RGBA8)
		if helm_col != Color.WHITE:
			for y in range(h_fh):
				for x in range(h_fw):
					var p: Color = head_img.get_pixel(x, y)
					if p.a > 0.01:
						head_img.set_pixel(x, y, Color(p.r * helm_col.r, p.g * helm_col.g, p.b * helm_col.b, p.a))
		if h_fw != fw or h_fh != fh:
			head_img.resize(fw, fh, Image.INTERPOLATE_BILINEAR)
		base_img.blend_rect(head_img, Rect2i(0, 0, fw, fh), Vector2i.ZERO)
	base_img.resize(40, 40, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(base_img)


func _build_draft_overlay() -> void:
	_draft_overlay = ColorRect.new()
	_draft_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draft_overlay.color = Color(0.02, 0.03, 0.06, 0.90)
	_draft_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_draft_overlay.visible = false
	add_child(_draft_overlay)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_draft_overlay.add_child(margin)

	var card := PanelContainer.new()
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
	margin.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var title := Label.new()
	title.text = "SELECT & LOCK YOUR AGENT  (UNIQUE PER PLAYER)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(1.0, 0.84, 0.24)
	hdr.add_child(title)

	_draft_timer_lbl = Label.new()
	_draft_timer_lbl.text = "TIME LEFT: 25s"
	_draft_timer_lbl.add_theme_font_size_override("font_size", 20)
	_draft_timer_lbl.modulate = Color(0.45, 0.96, 1.0)
	hdr.add_child(_draft_timer_lbl)

	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	vb.add_child(split)

	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(270, 0)
	left_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.12, 0.20, 0.96), Color(0.28, 0.45, 0.70, 0.85)))
	split.add_child(left_panel)

	var l_scroll := ScrollContainer.new()
	l_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(l_scroll)

	_draft_roster_box = VBoxContainer.new()
	_draft_roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draft_roster_box.add_theme_constant_override("separation", 6)
	l_scroll.add_child(_draft_roster_box)

	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.12, 0.20, 0.96), Color(0.28, 0.45, 0.70, 0.85)))
	split.add_child(right_panel)

	var r_scroll := ScrollContainer.new()
	r_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(r_scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	r_scroll.add_child(grid)

	_draft_agent_btns.clear()
	for i in range(AgentData.AGENTS.size()):
		var ag: Dictionary = AgentData.AGENTS[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 14)
		btn.icon = _make_draft_agent_icon(i)
		btn.text = "%s\n(%s)" % [str(ag["agent_name"]), str(ag["title"])]
		var idx: int = i
		btn.pressed.connect(func():
			_draft_selected_arch = idx
			_refresh_agent_draft_ui()
		)
		grid.add_child(btn)
		_draft_agent_btns.append(btn)

	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 12)
	vb.add_child(bot_row)

	_draft_info_lbl = Label.new()
	_draft_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draft_info_lbl.add_theme_font_size_override("font_size", 16)
	_draft_info_lbl.modulate = Color(0.86, 0.92, 1.0)
	bot_row.add_child(_draft_info_lbl)

	_draft_lock_btn = Button.new()
	_draft_lock_btn.text = "LOCK IN AGENT"
	_draft_lock_btn.custom_minimum_size = Vector2(240, 52)
	_draft_lock_btn.add_theme_font_size_override("font_size", 18)
	_style_button(_draft_lock_btn, Color(0.09, 0.32, 0.16, 0.98), Color(0.32, 0.94, 0.50))
	_draft_lock_btn.pressed.connect(func():
		NetworkManager.request_lock_agent(_draft_selected_arch)
	)
	bot_row.add_child(_draft_lock_btn)


func _on_agent_draft_started() -> void:
	_draft_selected_arch = clampi(ProfileManager.archetype_id, 0, AgentData.AGENTS.size() - 1)
	if is_instance_valid(_draft_overlay):
		_draft_overlay.visible = true
	_refresh_agent_draft_ui()


func _refresh_agent_draft_ui() -> void:
	if not is_instance_valid(_draft_overlay) or not _draft_overlay.visible:
		return
	var locks: Dictionary = NetworkManager.agent_draft_locks
	var my_id: int = NetworkManager.get_local_peer_id()
	var my_locked: bool = locks.has(my_id)
	var my_locked_arch: int = int(locks.get(my_id, -1))

	var taken_by: Dictionary = {}
	for pid in locks.keys():
		taken_by[int(locks[pid])] = int(pid)

	if not my_locked and taken_by.has(_draft_selected_arch):
		for i in range(AgentData.AGENTS.size()):
			if not taken_by.has(i):
				_draft_selected_arch = i
				break

	for child in _draft_roster_box.get_children():
		child.queue_free()
	var p_keys: Array = NetworkManager.players.keys()
	p_keys.sort()
	for pid in p_keys:
		var p_int: int = int(pid)
		var p_name: String = str(NetworkManager.players[pid].get("name", "Player"))
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		if locks.has(p_int):
			var a_name: String = str(AgentData.get_agent(int(locks[p_int]))["agent_name"])
			lbl.text = "%s: LOCKED [%s]" % [p_name, a_name]
			lbl.modulate = Color(0.45, 0.96, 0.56)
		else:
			lbl.text = "%s: Picking..." % p_name
			lbl.modulate = Color(1.0, 0.84, 0.35)
		_draft_roster_box.add_child(lbl)

	for i in range(_draft_agent_btns.size()):
		var btn: Button = _draft_agent_btns[i]
		var ag: Dictionary = AgentData.AGENTS[i]
		if taken_by.has(i):
			var owner_id: int = int(taken_by[i])
			var owner_name: String = str(NetworkManager.players.get(owner_id, {}).get("name", "Player"))
			if owner_id == my_id:
				btn.disabled = true
				btn.text = "%s\n[LOCKED BY YOU]" % str(ag["agent_name"])
				_style_button(btn, Color(0.10, 0.34, 0.18, 0.98), Color(0.35, 0.98, 0.52))
			else:
				btn.disabled = true
				btn.text = "%s\n[TAKEN: %s]" % [str(ag["agent_name"]), owner_name]
				_style_button(btn, Color(0.14, 0.14, 0.18, 0.70), Color(0.35, 0.38, 0.45))
		else:
			btn.disabled = my_locked
			btn.text = "%s\n(%s)" % [str(ag["agent_name"]), str(ag["title"])]
			if i == _draft_selected_arch and not my_locked:
				_style_button(btn, Color(0.28, 0.22, 0.06, 0.98), Color(1.0, 0.84, 0.24))
			else:
				_style_button(btn, Color(0.10, 0.15, 0.24, 0.95), Color(0.30, 0.48, 0.72))

	if my_locked:
		var l_name: String = str(AgentData.get_agent(my_locked_arch)["agent_name"])
		_draft_info_lbl.text = "Locked %s! Waiting for other players to lock..." % l_name
		_draft_lock_btn.disabled = true
		_draft_lock_btn.text = "LOCKED (%s)" % l_name
	else:
		var sel_ag: Dictionary = AgentData.get_agent(_draft_selected_arch)
		_draft_info_lbl.text = "Selected: %s — %s" % [str(sel_ag["agent_name"]), str(sel_ag["title"])]
		_draft_lock_btn.disabled = taken_by.has(_draft_selected_arch)
		_draft_lock_btn.text = "LOCK IN"
