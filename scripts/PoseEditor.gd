extends Control
## Interactive Pose Studio for Nameless Clash.
## Run this scene (F6 in Godot) to drag character parts & weapons into place,
## preview animations, and save pose overrides for MainMenu & gameplay.

const TEX_WEAPONS: Texture2D = preload("res://assets/sprites/weapons_selection_sheet.png")
const PlayerControllerScript = preload("res://scripts/PlayerController.gd")
const STANCES: Array[String] = ["none", "rifle", "pistol", "bazooka", "throw_bomb"]
const STANCE_LABELS: Array[String] = [
	"Main Menu / Unarmed (none)",
	"Rifle Stance",
	"Pistol Stance",
	"RPG 7 Stance",
	"Throw Bomb Stance"
]
const ANIMS: Array[String] = ["idle", "run", "jetpack", "firing", "agent_idle", "agent_attack", "dead"]
const ANIM_LABELS: Array[String] = [
	"Idle",
	"Run",
	"Jetpack",
	"Firing",
	"Agent Mode Idle",
	"Agent Mode Attack",
	"Dead"
]
const PREVIEW_ANIM_DEFS: Dictionary = {
	"idle": {"frames": [0, 1], "fps": 3.5},
	"run": {"frames": [2, 3, 4, 3], "fps": 10.5},
	"jetpack": {"frames": [5, 5], "fps": 6.0},
	"firing": {"frames": [0, 6], "fps": 7.5},
	"agent_idle": {"frames": [0, 1], "fps": 3.5},
	"agent_attack": {"frames": [2, 6, 3, 0], "fps": 8.0},
	"dead": {"frames": [0, 6, 7, 7], "fps": 2.5},
}
const PARTS: Array[String] = ["head", "torso", "legs", "back", "hand_near", "hand_far", "weapon"]
const PART_LABELS: Array[String] = ["Head", "Torso", "Legs", "Back / Wing", "Near Hand", "Far Hand", "Weapon"]

var _canvas_panel: Control
var _stage_root: Node2D
var _modular: ModularCharacter
var _weapon_pivot: Node2D
var _gun_p: Sprite2D
var _agent_weapon_node: Node2D
var _overlay: Control

var _agent_opt: OptionButton
var _scope_btn: CheckButton
var _agent_mode_btn: CheckButton
var _stance_opt: OptionButton
var _weapon_opt: OptionButton
var _anim_play_btn: Button
var _anim_opt: OptionButton
var _frame_slider: HSlider
var _frame_lbl: Label
var _kf_btns: Array[Button] = []
var _flip_btn: Button
var _part_btns: Dictionary = {}
var _x_spin: SpinBox
var _y_spin: SpinBox
var _rot_spin: SpinBox
var _z_spin: SpinBox
var _sx_spin: SpinBox
var _sy_spin: SpinBox
var _status_lbl: Label

var _selected_part: String = "hand_near"
var _selected_stance: String = "none"
var _selected_agent_idx: int = 0
var _selected_part_id: int = 0
var _per_agent_scope: bool = true
var _per_weapon_scope: bool = true
var _weapon_scope_btn: CheckButton
var _agent_mode: bool = false
var _all_anims_scope: bool = true
var _anim_scope_btn: CheckButton
var _per_frame_scope: bool = false
var _frame_scope_btn: CheckButton
var _facing_right: bool = true
var _anim_playing: bool = false
var _selected_anim: String = "idle"
var _anim_timer: float = 0.0
var _manual_frame: int = 0
var _preview_weapon_id: int = 0
var _copied_keyframe: Dictionary = {}
var _temp_preview_overrides: Dictionary = {}

var _dragging: bool = false
var _drag_rotating: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_val: Dictionary = {}
var _drag_start_weapon_val: Dictionary = {}
var _syncing_ui: bool = false

var _pose_data: Dictionary = {"stances": {}, "agents": {}}
var _weapon_muzzles: Dictionary = {}
var _undo_stack: Array[Dictionary] = []
var _zoom_scale: float = 4.5

const UI_ELEMENT_ORDER: Array[String] = [
	"left_stick", "right_stick", "btn_reload", "btn_switch", "btn_bomb",
	"btn_shoe", "btn_zoom", "btn_presets", "btn_pickup", "btn_interact",
	"btn_throw_prop", "ability_0", "ability_1", "ability_2", "ability_3", "top_bar_hud"
]
const UI_ELEMENT_META: Dictionary = {
	"left_stick":     {"label": "Move Stick",        "short": "MOVE",    "kind": "stick",  "size": Vector2(188, 188), "color": Color(0.28, 0.78, 1.00)},
	"right_stick":    {"label": "Aim / Shoot Stick", "short": "AIM",     "kind": "stick",  "size": Vector2(188, 188), "color": Color(1.00, 0.45, 0.35)},
	"btn_reload":     {"label": "Reload",            "short": "RLD",     "kind": "circle", "size": Vector2(70, 70),   "color": Color(0.35, 0.85, 1.00)},
	"btn_switch":     {"label": "Switch Weapon",     "short": "SWAP",    "kind": "circle", "size": Vector2(70, 70),   "color": Color(0.95, 0.78, 0.35)},
	"btn_bomb":       {"label": "Bomb / Grenade",    "short": "FRAG",    "kind": "circle", "size": Vector2(78, 78),   "color": Color(1.00, 0.62, 0.28)},
	"btn_shoe":       {"label": "Throw Throwable",   "short": "THROW",   "kind": "circle", "size": Vector2(80, 80),   "color": Color(0.35, 0.95, 0.68)},
	"btn_zoom":       {"label": "Zoom Toggle",       "short": "1x/2x",   "kind": "circle", "size": Vector2(76, 76),   "color": Color(0.45, 0.82, 1.00)},
	"btn_presets":    {"label": "Gun Presets",       "short": "KIT",     "kind": "circle", "size": Vector2(74, 74),   "color": Color(0.95, 0.78, 0.32)},
	"btn_pickup":     {"label": "Pickup Weapon",     "short": "PICK",    "kind": "circle", "size": Vector2(78, 78),   "color": Color(0.45, 1.00, 0.65)},
	"btn_interact":   {"label": "Use / Interact",    "short": "USE",     "kind": "circle", "size": Vector2(78, 78),   "color": Color(0.42, 0.85, 1.00)},
	"btn_throw_prop": {"label": "Throw Prop",        "short": "PROP",    "kind": "circle", "size": Vector2(88, 88),   "color": Color(1.00, 0.78, 0.36)},
	"ability_0":      {"label": "Ability 1",         "short": "AB1",     "kind": "circle", "size": Vector2(74, 74),   "color": Color(1.00, 0.84, 0.24)},
	"ability_1":      {"label": "Ability 2",         "short": "AB2",     "kind": "circle", "size": Vector2(74, 74),   "color": Color(0.45, 0.95, 0.65)},
	"ability_2":      {"label": "Ability 3",         "short": "AB3",     "kind": "circle", "size": Vector2(74, 74),   "color": Color(0.76, 0.50, 1.00)},
	"ability_3":      {"label": "Ultimate",          "short": "ULT",     "kind": "circle", "size": Vector2(74, 74),   "color": Color(1.00, 0.28, 0.28)},
	"top_bar_hud":    {"label": "Top HUD Bar",       "short": "HP / GAS | WEAPON | K/A/D | TIME", "kind": "topbar", "size": Vector2(660, 58), "color": Color(0.28, 0.88, 0.96)},
}

var _active_editor_tab: int = 0
var _tab_pose_btn: Button
var _tab_ui_btn: Button
var _tab_range_btn: Button
var _tab_coin_btn: Button
var _tab_nc_shop_btn: Button
var _tab_ach_crate_btn: Button
var _pose_mode_root: VBoxContainer
var _ui_setter_root: VBoxContainer
var _range_mode_root: VBoxContainer
var _coin_mode_root: VBoxContainer
var _nc_shop_root: VBoxContainer
var _ach_crate_root: VBoxContainer

var _ac_subtab: int = 0
var _ac_sub_ach_btn: Button
var _ac_sub_crate_btn: Button
var _ac_ach_panel: Control
var _ac_crate_panel: Control
var _ac_selected_ach_id: String = ""
var _ac_ach_btns: Dictionary = {}
var _ac_ach_title_lbl: Label
var _ac_ach_desc_lbl: Label
var _ac_ach_coins_spin: SpinBox
var _ac_ach_target_spin: SpinBox
var _ac_ach_weapon_opt: OptionButton
var _ac_ach_skin_opt: OptionButton
var _ac_ach_excl_cb: CheckBox
var _ac_ach_status_lbl: Label
var _ac_syncing: bool = false

var _ac_crate_key: String = "standard"
var _ac_crate_std_btn: Button
var _ac_crate_prem_btn: Button
var _ac_crate_list_box: VBoxContainer
var _ac_crate_total_lbl: Label
var _ac_crate_status_lbl: Label
var _ac_add_type_opt: OptionButton
var _ac_add_coins_spin: SpinBox
var _ac_add_weapon_opt: OptionButton
var _ac_add_skin_opt: OptionButton
var _ac_add_chance_spin: SpinBox

var _coin_kill_spin: SpinBox
var _coin_treasure_spin: SpinBox
var _coin_win_spin: SpinBox
var _coin_match_spin: SpinBox
var _coin_agent_spin: SpinBox
var _coin_bal_lbl: Label
var _coin_status_lbl: Label
var _reset_player_dlg: ConfirmationDialog
var _coin_selected_wid: int = 0
var _coin_gun_btns: Dictionary = {}
var _coin_skin_spins: Dictionary = {}
var _coin_gun_title_lbl: Label
var _coin_gun_preview: TextureRect
var _coin_skin_list_box: VBoxContainer
var _coin_syncing: bool = false
var _nc_shop_list_box: GridContainer
var _nc_shop_status_lbl: Label
var _nc_shop_pack_editors: Array[Dictionary] = []

const BUNKER_W: float = 2240.0
const BUNKER_H: float = 1248.0
const BUNKER_PLATFORMS: Array[Rect2] = [
	Rect2(0, 1216, 2240, 32),      # Floor
	Rect2(0, 0, 2240, 28),         # Ceiling
	Rect2(0, 0, 28, 1248),         # Left Wall
	Rect2(2212, 0, 28, 1248),      # Right Wall
	Rect2(120, 960, 320, 36),
	Rect2(1800, 960, 320, 36),
	Rect2(580, 960, 64, 224),
	Rect2(1596, 960, 64, 224),
	Rect2(960, 1020, 320, 48),
	Rect2(800, 740, 640, 38),
	Rect2(800, 635, 34, 105),
	Rect2(1406, 635, 34, 105),
	Rect2(340, 720, 280, 32),
	Rect2(1620, 720, 280, 32),
	Rect2(240, 440, 420, 34),
	Rect2(1580, 440, 420, 34),
	Rect2(880, 310, 480, 34),
	Rect2(710, 210, 44, 260),
	Rect2(1486, 210, 44, 260),
]

var _weapon_ranges: Dictionary = {}
var _weapon_stats: Dictionary = {}
var _range_selected_wid: int = 0
var _range_gun_btns: Dictionary = {}
var _range_canvas: Control
var _muzzle_canvas: Control
var _weapon_subtab: int = 0 # 0 = Muzzle / Aim Point (default), 1 = Range Setter (Bunker)
var _subtab_muzzle_btn: Button
var _subtab_range_btn: Button
var _muzzle_zoom: float = 8.0
var _muzzle_dragging: bool = false
var _w_muz_x_spin: SpinBox
var _w_muz_y_spin: SpinBox
var _range_shooter_pos: Vector2 = Vector2(480.0, 920.0)
var _range_aim_angle: float = 0.0
var _range_drag_mode: int = 0 # 0=none, 1=move shooter, 2=aim+set range
var _range_syncing: bool = false
var _range_gun_lbl: Label
var _range_stats_lbl: Label
var _range_spin: SpinBox
var _range_slider: HSlider
var _w_dmg_spin: SpinBox
var _w_rof_spin: SpinBox
var _w_spread_spin: SpinBox
var _w_speed_spin: SpinBox
var _w_mag_spin: SpinBox
var _w_reload_spin: SpinBox
var _w_recoil_spin: SpinBox
var _w_pellet_spin: SpinBox
var _range_status_lbl: Label

var _ui_layout_data: Dictionary = {}
var _ui_selected_id: String = "left_stick"
var _ui_preview_mode: int = 0 # 0 = All Elements, 1 = Gunfight HUD, 2 = Agent HUD
var _ui_snap_grid: bool = false
var _ui_canvas: Control
var _ui_elem_btns: Dictionary = {}
var _ui_sel_lbl: Label
var _ui_x_spin: SpinBox
var _ui_y_spin: SpinBox
var _ui_scale_spin: SpinBox
var _ui_scale_slider: HSlider
var _ui_rot_spin: SpinBox
var _ui_rot_slider: HSlider
var _ui_status_lbl: Label
var _ui_syncing: bool = false
var _ui_dragging: bool = false
var _ui_drag_rotating: bool = false
var _ui_drag_start_mouse: Vector2 = Vector2.ZERO
var _ui_drag_start_elem: Dictionary = {}



func _ready() -> void:
	if not OS.has_feature("editor"):
		push_error("Nameless Studio is editor-only and unavailable in exported builds.")
		get_tree().quit()
		return
	_load_pose_data()
	_weapon_muzzles = WeaponData.load_weapon_muzzles().duplicate(true)
	_load_ui_layout_data()
	_load_weapon_ranges()
	_build_ui()
	_apply_agent(0)
	_refresh_character_pose()


func _load_pose_data() -> void:
	_pose_data = {"stances": {}, "agents": {}}
	for path in ["res://assets/data/pose_overrides.json", "user://pose_overrides.json"]:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				var d := parsed as Dictionary
				if d.has("stances") and d["stances"] is Dictionary:
					_pose_data["stances"] = (d["stances"] as Dictionary).duplicate(true)
				if d.has("agents") and d["agents"] is Dictionary:
					_pose_data["agents"] = (d["agents"] as Dictionary).duplicate(true)


func _save_pose_data() -> void:
	var json_str := JSON.stringify(_pose_data, "  ")
	var dir_err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/data"))
	var ok_res := false
	var f_res := FileAccess.open("res://assets/data/pose_overrides.json", FileAccess.WRITE)
	if f_res != null:
		f_res.store_string(json_str)
		f_res.close()
		ok_res = true
	var f_usr := FileAccess.open("user://pose_overrides.json", FileAccess.WRITE)
	if f_usr != null:
		f_usr.store_string(json_str)
		f_usr.close()
	ModularCharacter.reload_pose_overrides()
	WeaponData.save_weapon_muzzles(_weapon_muzzles, true)
	_status_lbl.text = "Saved pose_overrides.json & weapon_muzzles.json!" if ok_res else "Saved to user://!"
	_status_lbl.modulate = Color(0.35, 0.96, 0.58)


func _make_dock_style(bg: Color, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


func _make_flow_bar(parent: Control, bg: Color, pad: int = 6, h_sep: int = 8, v_sep: int = 6) -> HFlowContainer:
	var bar := PanelContainer.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("panel", _make_dock_style(bg, pad))
	parent.add_child(bar)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", h_sep)
	flow.add_theme_constant_override("v_separation", v_sep)
	bar.add_child(flow)
	return flow


func _wrap_panel_vscroll(panel: PanelContainer, vb: VBoxContainer) -> ScrollContainer:
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	return sc


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.clip_contents = true
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# 0. EDITOR MODE TAB BAR (wraps cleanly on narrow screens)
	var tab_hbox := _make_flow_bar(main_vbox, Color(0.06, 0.08, 0.12), 6, 8, 6)

	var studio_lbl := Label.new()
	studio_lbl.text = "NAMELESS STUDIO"
	studio_lbl.add_theme_font_size_override("font_size", 14)
	studio_lbl.modulate = Color(0.58, 0.70, 0.85)
	tab_hbox.add_child(studio_lbl)

	_tab_pose_btn = Button.new()
	_tab_pose_btn.text = "Character Poses"
	_tab_pose_btn.toggle_mode = true
	_tab_pose_btn.custom_minimum_size = Vector2(128, 30)
	_tab_pose_btn.pressed.connect(func(): _switch_editor_tab(0))
	tab_hbox.add_child(_tab_pose_btn)

	_tab_ui_btn = Button.new()
	_tab_ui_btn.text = "In-Game UI Setter"
	_tab_ui_btn.toggle_mode = true
	_tab_ui_btn.custom_minimum_size = Vector2(136, 30)
	_tab_ui_btn.pressed.connect(func(): _switch_editor_tab(1))
	tab_hbox.add_child(_tab_ui_btn)

	_tab_range_btn = Button.new()
	_tab_range_btn.text = "Weapons Studio"
	_tab_range_btn.toggle_mode = true
	_tab_range_btn.custom_minimum_size = Vector2(130, 30)
	_tab_range_btn.pressed.connect(func(): _switch_editor_tab(2))
	tab_hbox.add_child(_tab_range_btn)

	_tab_coin_btn = Button.new()
	_tab_coin_btn.text = "NC Adjustment"
	_tab_coin_btn.toggle_mode = true
	_tab_coin_btn.custom_minimum_size = Vector2(128, 30)
	_tab_coin_btn.pressed.connect(func(): _switch_editor_tab(3))
	tab_hbox.add_child(_tab_coin_btn)

	_tab_nc_shop_btn = Button.new()
	_tab_nc_shop_btn.text = "NC Shop"
	_tab_nc_shop_btn.toggle_mode = true
	_tab_nc_shop_btn.custom_minimum_size = Vector2(106, 30)
	_tab_nc_shop_btn.pressed.connect(func(): _switch_editor_tab(5))
	tab_hbox.add_child(_tab_nc_shop_btn)

	_tab_ach_crate_btn = Button.new()
	_tab_ach_crate_btn.text = "Achievements & Crates"
	_tab_ach_crate_btn.toggle_mode = true
	_tab_ach_crate_btn.custom_minimum_size = Vector2(158, 30)
	_tab_ach_crate_btn.pressed.connect(func(): _switch_editor_tab(4))
	tab_hbox.add_child(_tab_ach_crate_btn)

	var reset_player_btn := Button.new()
	reset_player_btn.text = "Reset Player Data"
	reset_player_btn.custom_minimum_size = Vector2(146, 30)
	reset_player_btn.modulate = Color(1.0, 0.48, 0.44)
	reset_player_btn.tooltip_text = "Wipe all current player NC, skins, cosmetics, unlocked agents, badges & achievements back to a fresh profile"
	reset_player_btn.pressed.connect(_prompt_reset_player_data)
	tab_hbox.add_child(reset_player_btn)

	_reset_player_dlg = ConfirmationDialog.new()
	_reset_player_dlg.title = "Reset Full Player Data?"
	_reset_player_dlg.ok_button_text = "RESET ALL PLAYER DATA"
	_reset_player_dlg.dialog_text = "This wipes ALL data of the current player profile back to defaults:\n- NC reset to 500\n- All unlocked agents, gun skins & cosmetics cleared\n- Daily bonus, free crate & crate limit states cleared\n- All NEW badges & achievement progress cleared\n\nEditor configs (poses, weapon stats, crate tables, NC economy, achievement rewards) are NOT affected."
	_reset_player_dlg.confirmed.connect(_on_confirm_reset_player_data)
	add_child(_reset_player_dlg)

	_pose_mode_root = VBoxContainer.new()
	_pose_mode_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pose_mode_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pose_mode_root.add_theme_constant_override("separation", 0)
	main_vbox.add_child(_pose_mode_root)

	# 1. TOP TOOLBAR (Agent, Stance, Weapon, Undo, Save)
	var top_hbox := _make_flow_bar(_pose_mode_root, Color(0.10, 0.13, 0.19), 8, 8, 6)

	var title := Label.new()
	title.text = "POSE STUDIO"
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color(0.42, 0.92, 1.0)
	top_hbox.add_child(title)

	top_hbox.add_child(_make_section_label("Agent:"))
	_agent_opt = OptionButton.new()
	_agent_opt.custom_minimum_size = Vector2(180, 0)
	for i in range(ProfileManager.ARCHETYPES.size()):
		_agent_opt.add_item("%d: %s" % [i, str(ProfileManager.ARCHETYPES[i].get("name", "Agent"))], i)
	_agent_opt.item_selected.connect(func(idx: int): _apply_agent(idx))
	top_hbox.add_child(_agent_opt)

	_scope_btn = CheckButton.new()
	_scope_btn.text = "This Agent Only"
	_scope_btn.button_pressed = true
	_scope_btn.toggled.connect(func(on: bool):
		_per_agent_scope = on
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	top_hbox.add_child(_scope_btn)

	_agent_mode_btn = CheckButton.new()
	_agent_mode_btn.text = "Agent Mode"
	_agent_mode_btn.button_pressed = false
	_agent_mode_btn.toggled.connect(func(on: bool):
		_agent_mode = on
		if on:
			if _selected_stance == "none":
				_selected_stance = "rifle"
				_stance_opt.select(1)
			if _selected_anim != "agent_idle" and _selected_anim != "agent_attack":
				_selected_anim = "agent_idle"
				_anim_opt.select(ANIMS.find("agent_idle"))
		else:
			if _selected_anim == "agent_idle" or _selected_anim == "agent_attack":
				_selected_anim = "idle"
				_anim_opt.select(0)
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	top_hbox.add_child(_agent_mode_btn)

	top_hbox.add_child(_make_section_label("Stance:"))
	_stance_opt = OptionButton.new()
	_stance_opt.custom_minimum_size = Vector2(140, 0)
	for i in range(STANCES.size()):
		_stance_opt.add_item(STANCE_LABELS[i], i)
	_stance_opt.item_selected.connect(func(idx: int):
		_selected_stance = STANCES[idx]
		if _selected_stance == "none" and _agent_mode:
			_agent_mode = false
			_agent_mode_btn.set_pressed_no_signal(false)
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	top_hbox.add_child(_stance_opt)

	top_hbox.add_child(_make_section_label("Weapon:"))
	_weapon_opt = OptionButton.new()
	_weapon_opt.custom_minimum_size = Vector2(110, 0)
	_populate_grouped_weapon_option(_weapon_opt)
	var def_w_idx: int = _weapon_opt.get_item_index(0)
	if def_w_idx >= 0:
		_weapon_opt.select(def_w_idx)
	_weapon_opt.item_selected.connect(func(idx: int):
		_clear_temp_preview()
		_preview_weapon_id = _weapon_opt.get_item_id(idx)
		if _agent_mode:
			_agent_mode = false
			_agent_mode_btn.set_pressed_no_signal(false)
		var auto_st: String = ModularCharacter.get_weapon_stance(_preview_weapon_id)
		if _selected_stance == "none" or _selected_stance != auto_st:
			_selected_stance = auto_st
			var st_idx := STANCES.find(auto_st)
			if st_idx >= 0:
				_stance_opt.select(st_idx)
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	top_hbox.add_child(_weapon_opt)

	_weapon_scope_btn = CheckButton.new()
	_weapon_scope_btn.text = "This Gun"
	_weapon_scope_btn.tooltip_text = "ON: edits only this specific gun (e.g. M4A1). OFF: edits the shared stance (e.g. all rifles)."
	_weapon_scope_btn.button_pressed = _per_weapon_scope
	_weapon_scope_btn.toggled.connect(func(on: bool):
		_clear_temp_preview()
		_per_weapon_scope = on
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
		_refresh_keyframe_strip()
	)
	top_hbox.add_child(_weapon_scope_btn)

	var undo_btn := Button.new()
	undo_btn.text = "Undo"
	undo_btn.pressed.connect(_undo)
	top_hbox.add_child(undo_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE POSE"
	save_btn.custom_minimum_size = Vector2(96, 30)
	save_btn.modulate = Color(0.45, 1.0, 0.65)
	save_btn.pressed.connect(_save_pose_data)
	top_hbox.add_child(save_btn)

	# 2. MIDDLE 3-COLUMN WORKSPACE (Left Parts Dock | Center Interactive Stage | Right Transform Dock)
	var mid_split := HBoxContainer.new()
	mid_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_split.clip_contents = true
	mid_split.add_theme_constant_override("separation", 0)
	_pose_mode_root.add_child(mid_split)

	# 2A. LEFT DOCK: Select Part & Reset
	var left_dock := PanelContainer.new()
	left_dock.custom_minimum_size = Vector2(210, 0)
	left_dock.add_theme_stylebox_override("panel", _make_dock_style(Color(0.11, 0.14, 0.20), 10))
	mid_split.add_child(left_dock)

	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 5)
	_wrap_panel_vscroll(left_dock, left_vb)

	left_vb.add_child(_make_section_label("Select Part to Move"))
	for i in range(PARTS.size()):
		var pname: String = PARTS[i]
		var btn := Button.new()
		btn.text = PART_LABELS[i]
		btn.toggle_mode = true
		btn.button_pressed = (pname == _selected_part)
		btn.custom_minimum_size = Vector2(0, 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _select_part(pname))
		left_vb.add_child(btn)
		_part_btns[pname] = btn

	left_vb.add_child(_make_section_label("Reset"))
	var rst_part := Button.new()
	rst_part.text = "Reset Selected Part"
	rst_part.pressed.connect(_reset_selected_part)
	left_vb.add_child(rst_part)

	var rst_stance := Button.new()
	rst_stance.text = "Reset Current Stance"
	rst_stance.pressed.connect(_reset_selected_stance)
	left_vb.add_child(rst_stance)

	left_vb.add_child(_make_section_label("Background"))
	var bg_row := HBoxContainer.new()
	bg_row.add_theme_constant_override("separation", 4)
	left_vb.add_child(bg_row)

	var bg_picker := ColorPickerButton.new()
	bg_picker.color = Color(0.07, 0.09, 0.13)
	bg_picker.edit_alpha = false
	bg_picker.custom_minimum_size = Vector2(44, 28)
	bg_picker.tooltip_text = "Pick custom stage background color"
	bg_picker.color_changed.connect(func(c: Color):
		if is_instance_valid(_canvas_panel):
			_canvas_panel.add_theme_stylebox_override("panel", _make_dock_style(c, 0))
	)
	bg_row.add_child(bg_picker)

	var apply_bg := func(c: Color):
		bg_picker.color = c
		if is_instance_valid(_canvas_panel):
			_canvas_panel.add_theme_stylebox_override("panel", _make_dock_style(c, 0))

	for preset in [
		["Dark", Color(0.07, 0.09, 0.13)],
		["White", Color(0.95, 0.96, 0.98)],
		["Gray", Color(0.45, 0.48, 0.52)],
		["Green", Color(0.12, 0.68, 0.24)]
	]:
		var p_btn := Button.new()
		p_btn.text = str(preset[0])
		p_btn.custom_minimum_size = Vector2(0, 28)
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var p_col: Color = preset[1]
		p_btn.pressed.connect(func(): apply_bg.call(p_col))
		bg_row.add_child(p_btn)

	var left_spacer := Control.new()
	left_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vb.add_child(left_spacer)

	_status_lbl = Label.new()
	_status_lbl.text = "Ready. Drag any part in the center!"
	_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_lbl.add_theme_font_size_override("font_size", 12)
	left_vb.add_child(_status_lbl)

	# 2B. CENTER: Interactive Drag Canvas
	_canvas_panel = Panel.new()
	_canvas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_panel.clip_contents = true
	_canvas_panel.add_theme_stylebox_override("panel", _make_dock_style(Color(0.07, 0.09, 0.13), 0))
	mid_split.add_child(_canvas_panel)

	_stage_root = Node2D.new()
	_canvas_panel.add_child(_stage_root)

	_modular = ModularCharacter.new()
	_stage_root.add_child(_modular)

	_weapon_pivot = Node2D.new()
	_weapon_pivot.position = Vector2(2, 9)
	_stage_root.add_child(_weapon_pivot)

	_gun_p = Sprite2D.new()
	_gun_p.texture = TEX_WEAPONS
	_gun_p.hframes = WeaponData.SELECTION_COLS
	_gun_p.vframes = WeaponData.SELECTION_ROWS
	_gun_p.position = Vector2(16, 0)
	_gun_p.scale = Vector2(0.23, 0.23)
	_weapon_pivot.add_child(_gun_p)

	_agent_weapon_node = PlayerControllerScript.AgentWeaponVisual.new()
	_agent_weapon_node.name = "AgentWeaponVisual"
	_agent_weapon_node.visible = false
	_weapon_pivot.add_child(_agent_weapon_node)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 100
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_on_overlay_draw)
	_overlay.gui_input.connect(_on_overlay_gui_input)
	_canvas_panel.add_child(_overlay)

	# 2C. RIGHT DOCK: Transform & Layer Z-Order
	var right_dock := PanelContainer.new()
	right_dock.custom_minimum_size = Vector2(240, 0)
	right_dock.add_theme_stylebox_override("panel", _make_dock_style(Color(0.11, 0.14, 0.20), 10))
	mid_split.add_child(right_dock)

	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 5)
	_wrap_panel_vscroll(right_dock, right_vb)

	right_vb.add_child(_make_section_label("Selected Part Transform"))
	_x_spin = _add_spin_row(right_vb, "Pos X:", -80.0, 80.0, 0.5)
	_y_spin = _add_spin_row(right_vb, "Pos Y:", -80.0, 80.0, 0.5)
	_rot_spin = _add_spin_row(right_vb, "Rot (deg):", -180.0, 180.0, 1.0)
	_z_spin = _add_spin_row(right_vb, "Z-Order:", -10.0, 10.0, 1.0)
	_sx_spin = _add_spin_row(right_vb, "Scale X:", 0.2, 3.0, 0.05)
	_sy_spin = _add_spin_row(right_vb, "Scale Y:", 0.2, 3.0, 0.05)
	_sx_spin.value = 1.0
	_sy_spin.value = 1.0
	_x_spin.value_changed.connect(func(_v: float): _on_spin_changed())
	_y_spin.value_changed.connect(func(_v: float): _on_spin_changed())
	_rot_spin.value_changed.connect(func(_v: float): _on_spin_changed())
	_z_spin.value_changed.connect(func(_v: float): _on_spin_changed())
	_sx_spin.value_changed.connect(func(_v: float): _on_spin_changed())
	_sy_spin.value_changed.connect(func(_v: float): _on_spin_changed())

	right_vb.add_child(_make_section_label("Layer Order (Z)"))
	var z_back_btn := Button.new()
	z_back_btn.text = "Send Back (Z - 1)"
	z_back_btn.pressed.connect(func(): _z_spin.value -= 1.0)
	right_vb.add_child(z_back_btn)

	var z_fwd_btn := Button.new()
	z_fwd_btn.text = "Bring Forward (Z + 1)"
	z_fwd_btn.pressed.connect(func(): _z_spin.value += 1.0)
	right_vb.add_child(z_fwd_btn)

	var right_spacer := Control.new()
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vb.add_child(right_spacer)

	var hint := Label.new()
	hint.text = "Controls:\n• Left-Drag: Move part\n• Right-Drag / Wheel: Rotate\n• Ctrl+Z: Undo\n• Release mouse to drop"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.72, 0.78, 0.86)
	right_vb.add_child(hint)

	# 3. BOTTOM TIMELINE BAR (Animation Preview, Scope, Flip, Frame Scrubber)
	var bot_hbox := _make_flow_bar(_pose_mode_root, Color(0.10, 0.13, 0.19), 5, 6, 4)

	_anim_play_btn = Button.new()
	_anim_play_btn.text = "▶ Play"
	_anim_play_btn.toggle_mode = true
	_anim_play_btn.custom_minimum_size = Vector2(90, 28)
	_anim_play_btn.toggled.connect(func(on: bool):
		_anim_playing = on
		_anim_play_btn.text = "⏸ Pause" if on else "▶ Play"
		if on:
			_clear_temp_preview()
			_sync_spinboxes_from_pose()
			_refresh_character_pose()
	)
	bot_hbox.add_child(_anim_play_btn)

	bot_hbox.add_child(_make_section_label("Anim:"))
	_anim_opt = OptionButton.new()
	_anim_opt.custom_minimum_size = Vector2(126, 0)
	for i in range(ANIMS.size()):
		_anim_opt.add_item(ANIM_LABELS[i], i)
	_anim_opt.item_selected.connect(func(idx: int):
		_clear_temp_preview()
		_selected_anim = ANIMS[idx]
		_anim_timer = 0.0
		if _selected_anim == "agent_idle" or _selected_anim == "agent_attack":
			if not _agent_mode:
				_agent_mode = true
				if _agent_mode_btn != null:
					_agent_mode_btn.set_pressed_no_signal(true)
			if _selected_stance == "none":
				_selected_stance = "rifle"
				var s_idx := STANCES.find("rifle")
				if s_idx >= 0 and _stance_opt != null:
					_stance_opt.select(s_idx)
		var adef: Dictionary = PREVIEW_ANIM_DEFS.get(_selected_anim, {"frames": [0]})
		var frames: Array = adef.get("frames", [0])
		if not frames.is_empty():
			_manual_frame = int(frames[0])
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	bot_hbox.add_child(_anim_opt)

	_anim_scope_btn = CheckButton.new()
	_anim_scope_btn.text = "All Anims"
	_anim_scope_btn.button_pressed = true
	_anim_scope_btn.toggled.connect(func(on: bool):
		_all_anims_scope = on
		if on and is_instance_valid(_frame_scope_btn):
			_per_frame_scope = false
			_frame_scope_btn.set_pressed_no_signal(false)
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	bot_hbox.add_child(_anim_scope_btn)

	_frame_scope_btn = CheckButton.new()
	_frame_scope_btn.text = "● REC"
	_frame_scope_btn.button_pressed = false
	_frame_scope_btn.toggled.connect(func(on: bool):
		_clear_temp_preview()
		_per_frame_scope = on
		_frame_scope_btn.modulate = Color(1.0, 0.35, 0.35) if on else Color.WHITE
		if on and is_instance_valid(_anim_scope_btn):
			_all_anims_scope = false
			_anim_scope_btn.set_pressed_no_signal(false)
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
		_refresh_keyframe_strip()
	)
	bot_hbox.add_child(_frame_scope_btn)

	_flip_btn = Button.new()
	_flip_btn.text = "Flip"
	_flip_btn.pressed.connect(func():
		_facing_right = not _facing_right
		_refresh_character_pose()
	)
	bot_hbox.add_child(_flip_btn)

	_frame_lbl = Label.new()
	_frame_lbl.text = "Frame: 0"
	_frame_lbl.custom_minimum_size = Vector2(56, 0)
	bot_hbox.add_child(_frame_lbl)

	var tl_vbox := VBoxContainer.new()
	tl_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl_vbox.add_theme_constant_override("separation", 0)
	bot_hbox.add_child(tl_vbox)

	_frame_slider = HSlider.new()
	_frame_slider.min_value = 0
	_frame_slider.max_value = 7
	_frame_slider.step = 1
	_frame_slider.tick_count = 8
	_frame_slider.ticks_on_borders = true
	_frame_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame_slider.value_changed.connect(func(val: float):
		_clear_temp_preview()
		_manual_frame = int(val)
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	tl_vbox.add_child(_frame_slider)

	var kf_row := HBoxContainer.new()
	kf_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kf_row.add_theme_constant_override("separation", 2)
	tl_vbox.add_child(kf_row)
	_kf_btns.clear()
	for fi in range(8):
		var fb := Button.new()
		fb.text = str(fi)
		fb.custom_minimum_size = Vector2(24, 20)
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var frame_idx := fi
		fb.pressed.connect(func():
			_clear_temp_preview()
			_manual_frame = frame_idx
			_sync_spinboxes_from_pose()
			_refresh_character_pose()
		)
		kf_row.add_child(fb)
		_kf_btns.append(fb)

	var copy_kf_btn := Button.new()
	copy_kf_btn.text = "Copy"
	copy_kf_btn.custom_minimum_size = Vector2(48, 26)
	copy_kf_btn.pressed.connect(func():
		var fkey := _get_edit_stance_prefix() + "@" + _selected_anim + "#f" + str(_manual_frame)
		var src_dict: Dictionary = {}
		if _per_agent_scope:
			var ak := str(_selected_part_id)
			if _pose_data["agents"].has(ak) and _pose_data["agents"][ak].has(fkey):
				src_dict = (_pose_data["agents"][ak][fkey] as Dictionary).duplicate(true)
		elif _pose_data["stances"].has(fkey):
			src_dict = (_pose_data["stances"][fkey] as Dictionary).duplicate(true)
		if src_dict.is_empty():
			src_dict = _get_active_pose_dict().duplicate(true)
		_copied_keyframe = src_dict
		if is_instance_valid(_status_lbl):
			_status_lbl.text = "Copied keyframe from Frame %d" % _manual_frame
			_status_lbl.modulate = Color(0.45, 0.90, 1.0)
	)
	bot_hbox.add_child(copy_kf_btn)

	var paste_kf_btn := Button.new()
	paste_kf_btn.text = "Paste"
	paste_kf_btn.custom_minimum_size = Vector2(52, 26)
	paste_kf_btn.pressed.connect(func():
		if _copied_keyframe.is_empty():
			if is_instance_valid(_status_lbl):
				_status_lbl.text = "Nothing copied! Click Copy first."
				_status_lbl.modulate = Color(1.0, 0.65, 0.35)
			return
		var fkey := _get_edit_stance_prefix() + "@" + _selected_anim + "#f" + str(_manual_frame)
		_push_undo()
		if _per_agent_scope:
			var ak := str(_selected_part_id)
			if not _pose_data["agents"].has(ak):
				_pose_data["agents"][ak] = {}
			_pose_data["agents"][ak][fkey] = _copied_keyframe.duplicate(true)
		else:
			_pose_data["stances"][fkey] = _copied_keyframe.duplicate(true)
		ModularCharacter._pose_overrides = _pose_data.duplicate(true)
		ModularCharacter._pose_overrides_loaded = true
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
		_refresh_keyframe_strip()
		if is_instance_valid(_status_lbl):
			_status_lbl.text = "Pasted keyframe to Frame %d" % _manual_frame
			_status_lbl.modulate = Color(0.45, 1.0, 0.65)
	)
	bot_hbox.add_child(paste_kf_btn)

	var del_kf_btn := Button.new()
	del_kf_btn.text = "Del"
	del_kf_btn.custom_minimum_size = Vector2(40, 26)
	del_kf_btn.pressed.connect(func():
		var fkey := _get_edit_stance_prefix() + "@" + _selected_anim + "#f" + str(_manual_frame)
		_push_undo()
		if _per_agent_scope:
			var ak := str(_selected_part_id)
			if _pose_data["agents"].has(ak):
				(_pose_data["agents"][ak] as Dictionary).erase(fkey)
		else:
			(_pose_data["stances"] as Dictionary).erase(fkey)
		ModularCharacter._pose_overrides = _pose_data.duplicate(true)
		ModularCharacter._pose_overrides_loaded = true
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
		_refresh_keyframe_strip()
	)
	bot_hbox.add_child(del_kf_btn)

	var copy_guns_btn := Button.new()
	copy_guns_btn.text = "To Guns..."
	copy_guns_btn.tooltip_text = "Copy & replace this gun's animation keyframes onto selected other guns (e.g. M4A1 -> AK47 + 2 others)"
	copy_guns_btn.custom_minimum_size = Vector2(78, 26)
	copy_guns_btn.pressed.connect(_open_copy_to_guns_dialog)
	bot_hbox.add_child(copy_guns_btn)

	_build_ui_setter_tab(main_vbox)
	_build_range_editor_tab(main_vbox)
	_build_coin_economy_tab(main_vbox)
	_build_nc_shop_tab(main_vbox)
	_build_ach_and_crate_tab(main_vbox)
	_switch_editor_tab(0)


func _make_section_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(0.86, 0.90, 0.96)
	return l


func _make_weapon_group_header(title: String, col: Color, top_pad: int = 6) -> Control:
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = col
	if top_pad <= 0:
		return lbl
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_top", top_pad)
	pad.add_child(lbl)
	return pad


func _populate_grouped_weapon_option(opt: OptionButton, filter_ids: Array = [], exclude_ids: Array = []) -> void:
	for grp in WeaponData.get_weapon_category_groups(filter_ids):
		var added_sep: bool = false
		for wid_v in (grp["ids"] as Array):
			var wid: int = int(wid_v)
			if exclude_ids.has(wid):
				continue
			if not added_sep:
				opt.add_separator(str(grp["label"]))
				added_sep = true
			var wd := WeaponData.get_weapon(wid, 0, 0)
			opt.add_item("%d: %s" % [wid, wd.display_name], wid)


func _add_spin_row(parent: Control, label_txt: String, min_v: float, max_v: float, step_v: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(85, 0)
	row.add_child(lbl)
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = step_v
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sb)
	return sb


func _apply_agent(idx: int) -> void:
	_selected_agent_idx = clampi(idx, 0, ProfileManager.ARCHETYPES.size() - 1)
	var arch: Dictionary = ProfileManager.ARCHETYPES[_selected_agent_idx]
	_selected_part_id = int(arch.get("part_id", _selected_agent_idx))
	_modular.apply_loadout({
		"archetype_id": _selected_agent_idx,
		"skin_id": _selected_part_id,
		"head_id": _selected_part_id,
		"torso_id": _selected_part_id,
		"legs_id": _selected_part_id,
		"accessories_id": _selected_part_id,
		"hands_id": _selected_part_id,
		"shirt_color": arch.get("shirt", Color.WHITE),
		"pants_color": arch.get("pants", Color.WHITE),
		"skin_color": arch.get("skin", Color.WHITE),
		"helmet_color": arch.get("helmet", Color.WHITE),
		"gear_color": arch.get("gear", Color.WHITE),
	})
	_sync_spinboxes_from_pose()
	_refresh_character_pose()


func _select_part(pname: String) -> void:
	_selected_part = pname
	for k in _part_btns:
		(_part_btns[k] as Button).button_pressed = (k == pname)
	_sync_spinboxes_from_pose()
	_overlay.queue_redraw()


func _get_active_weapon_id() -> int:
	if not _agent_mode and _selected_stance != "none" and _selected_stance != "throw_bomb":
		return _preview_weapon_id
	return -1


func _get_edit_stance_prefix() -> String:
	if _per_weapon_scope and not _agent_mode and _selected_stance != "none" and _selected_stance != "throw_bomb":
		return "w" + str(_preview_weapon_id)
	return _selected_stance


func _get_target_stance_key() -> String:
	var prefix := _get_edit_stance_prefix()
	if _per_frame_scope:
		return prefix + "@" + _selected_anim + "#f" + str(_manual_frame)
	if _all_anims_scope:
		return prefix
	return prefix + "@" + _selected_anim


func _get_active_pose_dict() -> Dictionary:
	return ModularCharacter.get_pose_override(_selected_part_id, _selected_stance, _selected_anim, _manual_frame, _get_active_weapon_id())


func _open_copy_to_guns_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Copy Animation Keyframes to Guns"
	dlg.ok_button_text = "Replace Selected Guns"
	dlg.min_size = Vector2(420, 360)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg.add_child(vb)

	var src_wd := WeaponData.get_weapon(_preview_weapon_id, 0, false)
	var src_label := ("%d: %s" % [_preview_weapon_id, src_wd.display_name]) if _per_weapon_scope else _selected_stance
	var info := Label.new()
	info.text = "Source: %s  |  Current Anim: %s\nSelect which guns should receive these keyframes:" % [src_label, _selected_anim]
	vb.add_child(info)

	var all_anims_cb := CheckBox.new()
	all_anims_cb.text = "Copy ALL animations (Idle, Run, Jetpack, Firing, Dead)"
	all_anims_cb.button_pressed = false
	vb.add_child(all_anims_cb)

	var quick_hb := HBoxContainer.new()
	quick_hb.add_theme_constant_override("separation", 6)
	vb.add_child(quick_hb)

	var gun_cbs: Array[CheckBox] = []
	var gun_cb_wids: Array[int] = []
	var btn_rifles := Button.new()
	btn_rifles.text = "Rifles"
	btn_rifles.pressed.connect(func():
		for i in range(gun_cbs.size()):
			if not gun_cbs[i].disabled:
				gun_cbs[i].button_pressed = (ModularCharacter.get_weapon_stance(gun_cb_wids[i]) == "rifle")
	)
	quick_hb.add_child(btn_rifles)

	var btn_pistols := Button.new()
	btn_pistols.text = "Pistols/SMGs"
	btn_pistols.pressed.connect(func():
		for i in range(gun_cbs.size()):
			if not gun_cbs[i].disabled:
				gun_cbs[i].button_pressed = (ModularCharacter.get_weapon_stance(gun_cb_wids[i]) == "pistol")
	)
	quick_hb.add_child(btn_pistols)

	var btn_all := Button.new()
	btn_all.text = "All"
	btn_all.pressed.connect(func():
		for i in range(gun_cbs.size()):
			if not gun_cbs[i].disabled:
				gun_cbs[i].button_pressed = true
	)
	quick_hb.add_child(btn_all)

	var btn_none := Button.new()
	btn_none.text = "Clear"
	btn_none.pressed.connect(func():
		for i in range(gun_cbs.size()):
			gun_cbs[i].button_pressed = false
	)
	quick_hb.add_child(btn_none)

	var gun_scroll := ScrollContainer.new()
	gun_scroll.custom_minimum_size = Vector2(0, 260)
	gun_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gun_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(gun_scroll)

	var gun_groups_vb := VBoxContainer.new()
	gun_groups_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gun_groups_vb.add_theme_constant_override("separation", 4)
	gun_scroll.add_child(gun_groups_vb)

	var dlg_groups: Array[Dictionary] = WeaponData.get_weapon_category_groups()
	for g_idx in range(dlg_groups.size()):
		var grp: Dictionary = dlg_groups[g_idx]
		gun_groups_vb.add_child(_make_weapon_group_header(str(grp["label"]), grp["color"] as Color, 6 if g_idx > 0 else 0))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 4)
		gun_groups_vb.add_child(grid)
		for wid_v in (grp["ids"] as Array):
			var w_idx: int = int(wid_v)
			var wd := WeaponData.get_weapon(w_idx, 0, 0)
			var cb := CheckBox.new()
			var is_src: bool = (_per_weapon_scope and w_idx == _preview_weapon_id)
			cb.text = ("%d: %s (Source)" % [w_idx, wd.display_name]) if is_src else ("%d: %s" % [w_idx, wd.display_name])
			cb.disabled = is_src
			grid.add_child(cb)
			gun_cbs.append(cb)
			gun_cb_wids.append(w_idx)

	dlg.confirmed.connect(func():
		var target_ids: Array[int] = []
		for i in range(gun_cbs.size()):
			if gun_cbs[i].button_pressed and not gun_cbs[i].disabled:
				target_ids.append(gun_cb_wids[i])
		if target_ids.is_empty():
			if is_instance_valid(_status_lbl):
				_status_lbl.text = "No target guns selected."
				_status_lbl.modulate = Color(1.0, 0.72, 0.35)
			dlg.queue_free()
			return

		_push_undo()
		var scope_dict: Dictionary
		if _per_agent_scope:
			var ak := str(_selected_part_id)
			if not _pose_data["agents"].has(ak):
				_pose_data["agents"][ak] = {}
			scope_dict = _pose_data["agents"][ak]
		else:
			scope_dict = _pose_data["stances"]

		var src_prefix := _get_edit_stance_prefix()
		var fallback_prefix := _selected_stance
		var anims_to_copy: Array[String] = []
		if all_anims_cb.button_pressed:
			anims_to_copy = ["idle", "run", "jetpack", "firing", "dead"]
		else:
			anims_to_copy = [_selected_anim]
		var copied_names: Array[String] = []

		for tw_id in target_ids:
			var dst_prefix := "w" + str(tw_id)
			var tw_wd := WeaponData.get_weapon(tw_id, 0, false)
			copied_names.append(tw_wd.display_name)
			if all_anims_cb.button_pressed:
				var src_base: Variant = scope_dict.get(src_prefix, scope_dict.get(fallback_prefix, null))
				if src_base is Dictionary and not (src_base as Dictionary).is_empty():
					scope_dict[dst_prefix] = (src_base as Dictionary).duplicate(true)
				else:
					scope_dict.erase(dst_prefix)
			for an in anims_to_copy:
				var src_ak := src_prefix + "@" + an
				var fb_ak := fallback_prefix + "@" + an
				var dst_ak := dst_prefix + "@" + an
				var src_anim_val: Variant = scope_dict.get(src_ak, scope_dict.get(fb_ak, null))
				if src_anim_val is Dictionary and not (src_anim_val as Dictionary).is_empty():
					scope_dict[dst_ak] = (src_anim_val as Dictionary).duplicate(true)
				else:
					scope_dict.erase(dst_ak)
				for fi in range(8):
					var src_fk := src_ak + "#f" + str(fi)
					var fb_fk := fb_ak + "#f" + str(fi)
					var dst_fk := dst_ak + "#f" + str(fi)
					var src_fv: Variant = scope_dict.get(src_fk, scope_dict.get(fb_fk, null))
					if src_fv is Dictionary and not (src_fv as Dictionary).is_empty():
						scope_dict[dst_fk] = (src_fv as Dictionary).duplicate(true)
					else:
						scope_dict.erase(dst_fk)

		ModularCharacter._pose_overrides = _pose_data.duplicate(true)
		ModularCharacter._pose_overrides_loaded = true
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
		_refresh_keyframe_strip()
		if is_instance_valid(_status_lbl):
			var mode_str := "ALL anims" if all_anims_cb.button_pressed else _selected_anim
			_status_lbl.text = "Copied %s to %d gun(s): %s" % [mode_str, copied_names.size(), ", ".join(copied_names)]
			_status_lbl.modulate = Color(0.45, 1.0, 0.65)
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


func _get_default_part_pose(pname: String) -> Dictionary:
	match pname:
		"hand_near":
			match _selected_stance:
				"none": return {"x": -24.0, "y": 2.0, "rot": 0.0}
				"pistol": return {"x": -17.0, "y": 6.0, "rot": rad_to_deg(-1.20)}
				"bazooka": return {"x": -18.0, "y": 3.0, "rot": rad_to_deg(-1.28)}
				_: return {"x": -18.0, "y": 6.0, "rot": rad_to_deg(-1.18)}
		"hand_far":
			match _selected_stance:
				"none": return {"x": 24.0, "y": 2.0, "rot": 0.0}
				"pistol": return {"x": 21.0, "y": 6.0, "rot": rad_to_deg(-0.15)}
				"bazooka": return {"x": 18.0, "y": 5.0, "rot": rad_to_deg(-0.35)}
				_: return {"x": 20.0, "y": 6.0, "rot": rad_to_deg(-0.22)}
		"weapon":
			return {"x": 2.0, "y": 9.0, "rot": 0.0}
		_:
			return {"x": 0.0, "y": 0.0, "rot": 0.0}


func _get_part_val(pname: String) -> Dictionary:
	if pname == "muzzle":
		var wk := str(_preview_weapon_id)
		if _weapon_muzzles.has(wk) and _weapon_muzzles[wk] is Dictionary:
			var m: Dictionary = _weapon_muzzles[wk] as Dictionary
			return {"x": float(m.get("x", 44.0)), "y": float(m.get("y", -3.0)), "rot": 0.0, "z": 0}
		var def_m: Vector2 = PlayerControllerScript.get_weapon_muzzle_local_pos(_preview_weapon_id)
		return {"x": def_m.x, "y": def_m.y, "rot": 0.0, "z": 0}
	var d := _get_active_pose_dict()
	if d.has(pname):
		return d[pname]
	return _get_default_part_pose(pname)


func _clear_temp_preview() -> void:
	if _temp_preview_overrides.is_empty():
		return
	_temp_preview_overrides.clear()
	ModularCharacter._pose_overrides = _pose_data.duplicate(true)
	ModularCharacter._pose_overrides_loaded = true


func _set_part_val(pname: String, val: Dictionary) -> void:
	if pname == "muzzle":
		var wk := str(_preview_weapon_id)
		_weapon_muzzles[wk] = {
			"x": snappedf(float(val.get("x", 44.0)), 0.1),
			"y": snappedf(float(val.get("y", -3.0)), 0.1)
		}
		WeaponData._muzzle_cache[wk] = (_weapon_muzzles[wk] as Dictionary).duplicate(true)
		WeaponData._muzzle_cache_loaded = true
		if is_instance_valid(_status_lbl):
			_status_lbl.text = "Muzzle #%d -> (%.1f, %.1f) — click Save to persist" % [_preview_weapon_id, float(_weapon_muzzles[wk]["x"]), float(_weapon_muzzles[wk]["y"])]
			_status_lbl.modulate = Color(1.0, 0.55, 0.42)
		if is_instance_valid(_overlay):
			_overlay.queue_redraw()
		return
	var old_hn: Dictionary = (_drag_start_val if _dragging else _get_part_val("hand_near")) if pname == "hand_near" else {}
	var base_w: Dictionary = (_drag_start_weapon_val if (_dragging and not _drag_start_weapon_val.is_empty()) else _get_part_val("weapon")) if pname == "hand_near" else {}
	var skey := _get_target_stance_key()
	var target_container: Dictionary
	if not _per_frame_scope:
		target_container = _temp_preview_overrides
	elif _per_agent_scope:
		var agents: Dictionary = _pose_data["agents"]
		var ak := str(_selected_part_id)
		if not agents.has(ak):
			agents[ak] = {}
		if not agents[ak].has(skey):
			agents[ak][skey] = {}
		target_container = agents[ak][skey]
	else:
		var stances: Dictionary = _pose_data["stances"]
		if not stances.has(skey):
			stances[skey] = {}
		target_container = stances[skey]
	var part_dict := {
		"x": snappedf(float(val.get("x", 0.0)), 0.5),
		"y": snappedf(float(val.get("y", 0.0)), 0.5),
		"rot": snappedf(float(val.get("rot", 0.0)), 1.0),
		"z": int(round(float(val.get("z", 0))))
	}
	var sx_val := snappedf(float(val.get("sx", 1.0)), 0.05)
	var sy_val := snappedf(float(val.get("sy", 1.0)), 0.05)
	if absf(sx_val - 1.0) > 0.001:
		part_dict["sx"] = sx_val
	if absf(sy_val - 1.0) > 0.001:
		part_dict["sy"] = sy_val
	target_container[pname] = part_dict
	if pname == "hand_near" and (_selected_stance != "none" or _agent_mode):
		var new_hn: Dictionary = target_container["hand_near"]
		var dx: float = float(new_hn["x"]) - float(old_hn.get("x", 0.0))
		var dy: float = float(new_hn["y"]) - float(old_hn.get("y", 0.0))
		var drot_deg: float = float(new_hn["rot"]) - float(old_hn.get("rot", 0.0))
		if absf(dx) > 0.001 or absf(dy) > 0.001 or absf(drot_deg) > 0.001:
			var wx: float = float(base_w.get("x", 2.0)) + dx
			var wy: float = float(base_w.get("y", 9.0)) + dy
			var wrot: float = float(base_w.get("rot", 0.0)) + drot_deg
			if absf(drot_deg) > 0.001:
				var piv := Vector2(float(new_hn["x"]), float(new_hn["y"]))
				var rel := (Vector2(wx, wy) - piv).rotated(deg_to_rad(drot_deg))
				wx = piv.x + rel.x
				wy = piv.y + rel.y
			target_container["weapon"] = {
				"x": snappedf(wx, 0.5),
				"y": snappedf(wy, 0.5),
				"rot": snappedf(wrot, 1.0),
				"z": int(round(float(base_w.get("z", 0))))
			}
	# Live-sync ModularCharacter static cache so preview reflects edits immediately
	var preview_data := _pose_data.duplicate(true)
	if not _per_frame_scope and not _temp_preview_overrides.is_empty():
		if _per_agent_scope:
			var ak := str(_selected_part_id)
			if not preview_data["agents"].has(ak):
				preview_data["agents"][ak] = {}
			if not preview_data["agents"][ak].has(skey):
				preview_data["agents"][ak][skey] = {}
			for pk in _temp_preview_overrides:
				preview_data["agents"][ak][skey][pk] = (_temp_preview_overrides[pk] as Dictionary).duplicate(true)
		else:
			if not preview_data["stances"].has(skey):
				preview_data["stances"][skey] = {}
			for pk in _temp_preview_overrides:
				preview_data["stances"][skey][pk] = (_temp_preview_overrides[pk] as Dictionary).duplicate(true)
		if is_instance_valid(_status_lbl):
			_status_lbl.text = "Unrecorded preview (enable ● REC to record)"
			_status_lbl.modulate = Color(1.0, 0.78, 0.35)
	ModularCharacter._pose_overrides = preview_data
	ModularCharacter._pose_overrides_loaded = true


func _sync_spinboxes_from_pose() -> void:
	_syncing_ui = true
	var val := _get_part_val(_selected_part)
	_x_spin.value = float(val.get("x", 0.0))
	_y_spin.value = float(val.get("y", 0.0))
	_rot_spin.value = float(val.get("rot", 0.0))
	_z_spin.value = float(val.get("z", 0))
	if is_instance_valid(_sx_spin):
		_sx_spin.value = float(val.get("sx", 1.0))
	if is_instance_valid(_sy_spin):
		_sy_spin.value = float(val.get("sy", 1.0))
	_syncing_ui = false


func _push_undo() -> void:
	_undo_stack.append(_pose_data.duplicate(true))
	if _undo_stack.size() > 40:
		_undo_stack.pop_front()


func _undo() -> void:
	if _undo_stack.is_empty():
		_status_lbl.text = "Nothing to undo."
		_status_lbl.modulate = Color(0.75, 0.78, 0.85)
		return
	_pose_data = _undo_stack.pop_back()
	ModularCharacter._pose_overrides = _pose_data.duplicate(true)
	ModularCharacter._pose_overrides_loaded = true
	_sync_spinboxes_from_pose()
	_refresh_character_pose()
	_status_lbl.text = "Undid last change."
	_status_lbl.modulate = Color(0.95, 0.82, 0.38)


func _on_spin_changed() -> void:
	if _syncing_ui:
		return
	_push_undo()
	_set_part_val(_selected_part, {
		"x": _x_spin.value,
		"y": _y_spin.value,
		"rot": _rot_spin.value,
		"z": int(_z_spin.value),
		"sx": _sx_spin.value if is_instance_valid(_sx_spin) else 1.0,
		"sy": _sy_spin.value if is_instance_valid(_sy_spin) else 1.0
	})
	_refresh_character_pose()


func _reset_selected_part() -> void:
	_push_undo()
	var skey := _get_target_stance_key()
	if _per_agent_scope:
		var ak := str(_selected_part_id)
		if _pose_data["agents"].has(ak) and _pose_data["agents"][ak].has(skey):
			_pose_data["agents"][ak][skey].erase(_selected_part)
	else:
		if _pose_data["stances"].has(skey):
			_pose_data["stances"][skey].erase(_selected_part)
	ModularCharacter._pose_overrides = _pose_data.duplicate(true)
	ModularCharacter._pose_overrides_loaded = true
	_sync_spinboxes_from_pose()
	_refresh_character_pose()


func _reset_selected_stance() -> void:
	_push_undo()
	var skey := _get_target_stance_key()
	if _per_agent_scope:
		var ak := str(_selected_part_id)
		if _pose_data["agents"].has(ak):
			_pose_data["agents"][ak].erase(skey)
	else:
		_pose_data["stances"].erase(skey)
	ModularCharacter._pose_overrides = _pose_data.duplicate(true)
	ModularCharacter._pose_overrides_loaded = true
	_sync_spinboxes_from_pose()
	_refresh_character_pose()


func _refresh_keyframe_strip() -> void:
	if is_instance_valid(_frame_slider):
		_frame_slider.set_value_no_signal(_manual_frame)
	if is_instance_valid(_frame_lbl):
		_frame_lbl.text = "Frame: %d" % _manual_frame
	if _kf_btns.is_empty():
		return
	var ak := str(_selected_part_id)
	var agent_dict: Dictionary = _pose_data.get("agents", {}).get(ak, {}) if _pose_data.get("agents", {}).get(ak) is Dictionary else {}
	var stance_dict: Dictionary = _pose_data.get("stances", {}) if _pose_data.get("stances") is Dictionary else {}
	var adef_strip: Dictionary = PREVIEW_ANIM_DEFS.get(_selected_anim, {"frames": [0]})
	var anim_frames: Array = adef_strip.get("frames", [0])
	var edit_prefix := _get_edit_stance_prefix()
	for fi in range(mini(8, _kf_btns.size())):
		var fb: Button = _kf_btns[fi]
		var fkey := edit_prefix + "@" + _selected_anim + "#f" + str(fi)
		var has_key: bool = (agent_dict.has(fkey) and not (agent_dict[fkey] as Dictionary).is_empty()) or (stance_dict.has(fkey) and not (stance_dict[fkey] as Dictionary).is_empty())
		var in_anim: bool = anim_frames.has(fi)
		fb.text = ("◆" + str(fi)) if has_key else str(fi)
		if fi == _manual_frame:
			fb.modulate = Color(1.0, 0.35, 0.35) if _per_frame_scope else Color(0.30, 0.95, 1.0)
		elif has_key:
			fb.modulate = Color(1.0, 0.85, 0.30, 1.0 if in_anim else 0.50)
		else:
			fb.modulate = Color(0.82, 0.86, 0.92, 1.0 if in_anim else 0.45)


func _process(delta: float) -> void:
	if _canvas_panel != null:
		_stage_root.position = _canvas_panel.size * 0.5
		_stage_root.scale = Vector2(_zoom_scale, _zoom_scale)
	if _anim_playing:
		_anim_timer += delta
		var adef: Dictionary = PREVIEW_ANIM_DEFS.get(_selected_anim, {"frames": [0, 1], "fps": 3.5, "loop": true})
		var frames: Array = adef.get("frames", [0])
		var fps: float = float(adef.get("fps", 4.0))
		var idx: int = int(_anim_timer * fps) % max(1, frames.size())
		_manual_frame = int(frames[idx])
		_refresh_character_pose()
	_overlay.queue_redraw()


func _refresh_character_pose() -> void:
	if _modular == null:
		return
	_refresh_keyframe_strip()
	var flip_h := not _facing_right
	_modular.freeze_procedural_anim = true
	_modular.current_weapon_id = _get_active_weapon_id()
	_modular.set_sync_frame(_manual_frame, flip_h)
	_modular._current_anim = _selected_anim

	var show_weapon := (_selected_stance != "none" or _agent_mode)
	_weapon_pivot.visible = show_weapon
	var w_ov := _get_part_val("weapon")
	var dir: float = 1.0 if _facing_right else -1.0

	var eff_stance := _selected_stance
	if _agent_mode and eff_stance == "none":
		eff_stance = "rifle"

	var recoil_dist: float = 0.0
	if _anim_playing and _selected_anim == "firing":
		var fire_wave: float = absf(sin(_anim_timer * 22.0))
		recoil_dist = fire_wave * 4.5

	var base_aim: float = 0.0 if _facing_right else PI
	_modular.apply_weapon_arm_pose(eff_stance, base_aim, _facing_right, recoil_dist, 0.5 if eff_stance == "throw_bomb" else -1.0)
	if eff_stance == "none":
		var d := _get_active_pose_dict()
		if not d.has("hand_near") and _modular._sprite_hands != null:
			_modular._sprite_hands.position = Vector2(-24.0 * dir, 2.0)
		if not d.has("hand_far") and _modular._sprite_hand_far != null:
			_modular._sprite_hand_far.position = Vector2(24.0 * dir, 2.0)

	# Procedural preview motion applied to the hand so the socketed weapon follows automatically
	if _anim_playing and _modular._sprite_hands != null:
		if _selected_anim == "agent_attack":
			var ag_atk: Dictionary = AgentData.get_agent(_selected_agent_idx)
			var is_ranged_atk: bool = bool((ag_atk.get("base_weapon", {}) as Dictionary).get("ranged", false))
			var swing_phase: float = fmod(_anim_timer * 2.2, 1.0)
			if is_ranged_atk:
				_modular._sprite_hands.position.x -= dir * absf(sin(swing_phase * TAU)) * 3.0
			else:
				var swing_ang: float = sin(swing_phase * TAU) * 45.0
				_modular._sprite_hands.rotation += dir * deg_to_rad(swing_ang)
				_modular._sprite_hands.position.x += dir * sin(swing_phase * TAU) * 4.0
		elif _selected_anim == "agent_idle":
			_modular._sprite_hands.position.y += sin(_anim_timer * 3.5) * 1.5
		elif _selected_anim == "jetpack":
			_modular._sprite_hands.position.y += sin(_anim_timer * 8.0) * 2.0

	# Attach weapon pivot directly to the Near Hand socket (and off-hand gun to Far Hand socket)
	var sock: Dictionary = _modular.get_weapon_socket_transform(eff_stance, _facing_right, w_ov, 9.0)
	_weapon_pivot.position = sock["pos"] as Vector2
	_weapon_pivot.z_index = int(sock["z"])
	_weapon_pivot.rotation = float(sock["rot"])
	_weapon_pivot.scale = Vector2(float(w_ov.get("sx", 1.0)), float(w_ov.get("sy", 1.0)))

	if _agent_mode and _agent_weapon_node != null:
		var ag: Dictionary = AgentData.get_agent(_selected_agent_idx)
		var bw: Dictionary = ag.get("base_weapon", {})
		_agent_weapon_node.set("weapon_style", str(bw.get("style", "sword")))
		_agent_weapon_node.set("weapon_color", bw.get("color", Color.WHITE) as Color)
		_agent_weapon_node.scale = Vector2(-1.0 if flip_h else 1.0, 1.0)
		_agent_weapon_node.visible = true
		_agent_weapon_node.queue_redraw()
		_gun_p.visible = false
	else:
		if _agent_weapon_node != null:
			_agent_weapon_node.visible = false
		_gun_p.visible = true
		var gun_x: float = 18.0 if _preview_weapon_id == 17 else 16.0
		_gun_p.position = Vector2(gun_x * dir, 0.0)
		match _preview_weapon_id:
			17: _gun_p.scale = Vector2(0.27, 0.27)
			19: _gun_p.scale = Vector2(0.20, 0.20)
			20: _gun_p.scale = Vector2(0.21, 0.21)
			22, 23: _gun_p.scale = Vector2(0.25, 0.25)
			_: _gun_p.scale = Vector2(0.24, 0.24)
		_gun_p.flip_h = flip_h
		var spec_p: Dictionary = WeaponData.get_weapon_sprite_spec(_preview_weapon_id, 0)
		_gun_p.texture = spec_p["tex"] as Texture2D
		_gun_p.hframes = int(spec_p["hframes"])
		_gun_p.vframes = int(spec_p["vframes"])
		_gun_p.frame = int(spec_p["frame"])


func _get_part_screen_pos(pname: String) -> Vector2:
	if pname == "muzzle" and _weapon_pivot != null:
		var mv := _get_part_val("muzzle")
		var m_dir := 1.0 if _facing_right else -1.0
		var local_m := Vector2(float(mv.get("x", 44.0)) * m_dir, float(mv.get("y", -3.0)))
		var world_m := _weapon_pivot.position + (local_m * _weapon_pivot.scale).rotated(_weapon_pivot.rotation)
		return _stage_root.position + world_m * _zoom_scale
	if pname == "weapon" and _weapon_pivot != null:
		return _stage_root.position + _weapon_pivot.position * _zoom_scale
	if pname == "hand_near" and _modular != null and _modular._sprite_hands != null:
		return _stage_root.position + _modular._sprite_hands.position * _zoom_scale
	if pname == "hand_far" and _modular != null and _modular._sprite_hand_far != null:
		return _stage_root.position + _modular._sprite_hand_far.position * _zoom_scale
	var val := _get_part_val(pname)
	var dir := 1.0 if _facing_right else -1.0
	var local_p := Vector2(float(val.get("x", 0.0)) * dir, float(val.get("y", 0.0)))
	match pname:
		"head": local_p += Vector2(0, -18)
		"torso": local_p += Vector2(0, 6)
		"legs": local_p += Vector2(0, 24)
		"back": local_p += Vector2(-14 * dir, 4)
	return _stage_root.position + local_p * _zoom_scale


func _on_overlay_draw() -> void:
	var c := _stage_root.position if _stage_root != null else (_canvas_panel.size * 0.5)
	_overlay.draw_line(Vector2(c.x, 0), Vector2(c.x, _overlay.size.y), Color(1.0, 0.85, 0.25, 0.16), 1.0)
	_overlay.draw_line(Vector2(0, c.y), Vector2(_overlay.size.x, c.y), Color(1.0, 0.85, 0.25, 0.16), 1.0)

	# Ground / feet reference line (48px below ModularCharacter center)
	var ground_y := c.y + 48.0 * _zoom_scale
	_overlay.draw_line(Vector2(c.x - 160.0, ground_y), Vector2(c.x + 160.0, ground_y), Color(0.45, 0.95, 0.55, 0.45), 1.5)

	# Origin (0,0) crosshair + ring + label
	var orig_col := Color(1.0, 0.82, 0.22, 0.92)
	_overlay.draw_line(Vector2(c.x - 14.0, c.y), Vector2(c.x + 14.0, c.y), orig_col, 2.0)
	_overlay.draw_line(Vector2(c.x, c.y - 14.0), Vector2(c.x, c.y + 14.0), orig_col, 2.0)
	_overlay.draw_arc(c, 9.0, 0.0, TAU, 24, orig_col, 1.8)
	var font := ThemeDB.fallback_font
	if font != null:
		_overlay.draw_string(font, c + Vector2(14.0, -10.0), "ORIGIN (0,0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, orig_col)
		_overlay.draw_string(font, Vector2(c.x + 166.0, ground_y + 4.0), "GROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.95, 0.55, 0.70))

	if _selected_stance != "none" or _agent_mode:
		var hn_p := _get_part_screen_pos("hand_near")
		var wp_p := _get_part_screen_pos("weapon")
		_overlay.draw_line(hn_p, wp_p, Color(0.25, 0.95, 1.0, 0.35), 1.5)
	if _selected_stance != "none" and not _agent_mode and _weapon_pivot != null:
		var mz_p := _get_part_screen_pos("muzzle")
		var aim_dir := Vector2(1.0 if _facing_right else -1.0, 0.0).rotated(_weapon_pivot.rotation)
		_overlay.draw_line(mz_p, mz_p + aim_dir * 320.0, Color(1.0, 0.14, 0.14, 0.80), 2.2)
		_overlay.draw_line(mz_p + Vector2(-9, 0), mz_p + Vector2(9, 0), Color(1.0, 0.25, 0.22, 0.95), 1.8)
		_overlay.draw_line(mz_p + Vector2(0, -9), mz_p + Vector2(0, 9), Color(1.0, 0.25, 0.22, 0.95), 1.8)
		if font != null and _selected_part == "muzzle":
			_overlay.draw_string(font, mz_p + Vector2(12.0, -10.0), "MUZZLE / AIM", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.35, 0.28))
	for i in range(PARTS.size()):
		var pname: String = PARTS[i]
		if pname == "weapon" and _selected_stance == "none" and not _agent_mode:
			continue
		if pname == "muzzle" and (_selected_stance == "none" or _agent_mode):
			continue
		var p := _get_part_screen_pos(pname)
		var is_sel := (pname == _selected_part)
		var col := (Color(1.0, 0.28, 0.22, 0.98) if pname == "muzzle" else Color(0.25, 0.95, 1.0, 0.95)) if is_sel else (Color(1.0, 0.30, 0.22, 0.72) if pname == "muzzle" else Color(1, 1, 1, 0.35))
		_overlay.draw_circle(p, 7.0 if is_sel else 4.5, col)
		if is_sel:
			_overlay.draw_arc(p, 13.0, 0.0, TAU, 24, col, 2.0)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var best_p := ""
				var best_d := 34.0
				for pname in PARTS:
					if pname == "weapon" and _selected_stance == "none" and not _agent_mode:
						continue
					if pname == "muzzle" and (_selected_stance == "none" or _agent_mode):
						continue
					var d := mb.position.distance_to(_get_part_screen_pos(pname))
					if d < best_d:
						best_d = d
						best_p = pname
				if best_p != "":
					_select_part(best_p)
				_push_undo()
				_dragging = true
				_drag_rotating = (mb.button_index == MOUSE_BUTTON_RIGHT) or mb.shift_pressed
				_drag_start_mouse = mb.position
				_drag_start_val = _get_part_val(_selected_part).duplicate()
				_drag_start_weapon_val = _get_part_val("weapon").duplicate()
			else:
				_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_push_undo()
			var v := _get_part_val(_selected_part)
			v["rot"] = float(v.get("rot", 0.0)) - 5.0
			_set_part_val(_selected_part, v)
			_sync_spinboxes_from_pose()
			_refresh_character_pose()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_push_undo()
			var v := _get_part_val(_selected_part)
			v["rot"] = float(v.get("rot", 0.0)) + 5.0
			_set_part_val(_selected_part, v)
			_sync_spinboxes_from_pose()
			_refresh_character_pose()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		var delta_px := (mm.position - _drag_start_mouse) / _zoom_scale
		var dir := 1.0 if _facing_right else -1.0
		var v := _drag_start_val.duplicate()
		if _drag_rotating or mm.shift_pressed:
			v["rot"] = float(_drag_start_val.get("rot", 0.0)) + (mm.position.x - _drag_start_mouse.x) * 0.5
		else:
			var move_delta := delta_px
			if _selected_part == "muzzle" and _weapon_pivot != null:
				move_delta = delta_px.rotated(-_weapon_pivot.rotation)
				if absf(_weapon_pivot.scale.x) > 0.01:
					move_delta.x /= _weapon_pivot.scale.x
				if absf(_weapon_pivot.scale.y) > 0.01:
					move_delta.y /= _weapon_pivot.scale.y
			elif _selected_part == "weapon" and _modular != null:
				var eff_st := "rifle" if (_agent_mode and _selected_stance == "none") else _selected_stance
				var sock: Dictionary = _modular.get_weapon_socket_transform(eff_st, _facing_right, _drag_start_val, 9.0)
				move_delta = delta_px.rotated(-float(sock["hand_delta_rot"]))
			v["x"] = float(_drag_start_val.get("x", 0.0)) + move_delta.x * dir
			v["y"] = float(_drag_start_val.get("y", 0.0)) + move_delta.y
		_set_part_val(_selected_part, v)
		_sync_spinboxes_from_pose()
		_refresh_character_pose()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_Z and k.ctrl_pressed:
			if _active_editor_tab == 0:
				_undo()
				get_viewport().set_input_as_handled()


# ==============================================================================
# IN-GAME UI SETTER TAB
# ==============================================================================

func _switch_editor_tab(tab_idx: int) -> void:
	_active_editor_tab = tab_idx
	if _pose_mode_root != null:
		_pose_mode_root.visible = (tab_idx == 0)
	if _ui_setter_root != null:
		_ui_setter_root.visible = (tab_idx == 1)
	if _range_mode_root != null:
		_range_mode_root.visible = (tab_idx == 2)
	if _coin_mode_root != null:
		_coin_mode_root.visible = (tab_idx == 3)
	if _nc_shop_root != null:
		_nc_shop_root.visible = (tab_idx == 5)
	if _ach_crate_root != null:
		_ach_crate_root.visible = (tab_idx == 4)
	if _tab_pose_btn != null:
		_tab_pose_btn.set_pressed_no_signal(tab_idx == 0)
		_tab_pose_btn.modulate = Color(0.45, 0.95, 1.0) if tab_idx == 0 else Color(0.75, 0.80, 0.88)
	if _tab_ui_btn != null:
		_tab_ui_btn.set_pressed_no_signal(tab_idx == 1)
		_tab_ui_btn.modulate = Color(0.45, 1.0, 0.68) if tab_idx == 1 else Color(0.75, 0.80, 0.88)
	if _tab_range_btn != null:
		_tab_range_btn.set_pressed_no_signal(tab_idx == 2)
		_tab_range_btn.modulate = Color(1.0, 0.45, 0.42) if tab_idx == 2 else Color(0.75, 0.80, 0.88)
	if _tab_coin_btn != null:
		_tab_coin_btn.set_pressed_no_signal(tab_idx == 3)
		_tab_coin_btn.modulate = Color(1.0, 0.86, 0.28) if tab_idx == 3 else Color(0.75, 0.80, 0.88)
	if _tab_nc_shop_btn != null:
		_tab_nc_shop_btn.set_pressed_no_signal(tab_idx == 5)
		_tab_nc_shop_btn.modulate = Color(0.38, 1.0, 0.58) if tab_idx == 5 else Color(0.75, 0.80, 0.88)
	if _tab_ach_crate_btn != null:
		_tab_ach_crate_btn.set_pressed_no_signal(tab_idx == 4)
		_tab_ach_crate_btn.modulate = Color(0.84, 0.58, 1.0) if tab_idx == 4 else Color(0.75, 0.80, 0.88)
	if tab_idx == 3:
		_sync_coin_economy_ui()
	if tab_idx == 5:
		_refresh_nc_shop_editor()
	if tab_idx == 4:
		_refresh_ac_crate_list()
	if tab_idx != 0:
		_anim_playing = false
		if _anim_play_btn != null:
			_anim_play_btn.set_pressed_no_signal(false)
			_anim_play_btn.text = "Activate Anim Preview"
	if tab_idx == 1 and _ui_canvas != null:
		_ui_canvas.queue_redraw()
	if tab_idx == 2:
		if _range_canvas != null:
			_range_canvas.queue_redraw()
		if _muzzle_canvas != null:
			_muzzle_canvas.queue_redraw()


func _load_ui_layout_data() -> void:
	_ui_layout_data = SettingsManager.load_default_ui_layout_dict()


func _save_ui_layout_as_default() -> void:
	var json_str := JSON.stringify(_ui_layout_data, "\t")
	var saved_res := false
	var f_res := FileAccess.open(SettingsManager.DEFAULT_UI_LAYOUT_PATH, FileAccess.WRITE)
	if f_res != null:
		f_res.store_string(json_str)
		f_res.close()
		saved_res = true

	var f_user := FileAccess.open(SettingsManager.USER_DEFAULT_UI_LAYOUT_PATH, FileAccess.WRITE)
	if f_user != null:
		f_user.store_string(json_str)
		f_user.close()

	SettingsManager.reset_touch_layout()
	if _ui_status_lbl != null:
		if saved_res:
			_ui_status_lbl.text = "Saved as default layout! (res:// + user://)"
		else:
			_ui_status_lbl.text = "Saved as default layout to user://!"
		_ui_status_lbl.modulate = Color(0.45, 1.0, 0.65)


func _build_ui_setter_tab(main_vbox: VBoxContainer) -> void:
	_ui_setter_root = VBoxContainer.new()
	_ui_setter_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_setter_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ui_setter_root.add_theme_constant_override("separation", 0)
	_ui_setter_root.visible = false
	main_vbox.add_child(_ui_setter_root)

	# 1. TOP TOOLBAR
	var top_hbox := _make_flow_bar(_ui_setter_root, Color(0.10, 0.13, 0.19), 8, 8, 6)

	var title := Label.new()
	title.text = "IN-GAME UI SETTER"
	title.add_theme_font_size_override("font_size", 17)
	title.modulate = Color(0.45, 1.0, 0.68)
	top_hbox.add_child(title)

	top_hbox.add_child(_make_section_label("HUD Preview:"))
	var mode_opt := OptionButton.new()
	mode_opt.custom_minimum_size = Vector2(150, 0)
	mode_opt.add_item("All Elements", 0)
	mode_opt.add_item("Gunfight HUD", 1)
	mode_opt.add_item("Agent HUD", 2)
	mode_opt.item_selected.connect(func(idx: int):
		_ui_preview_mode = idx
		if _ui_canvas != null:
			_ui_canvas.queue_redraw()
	)
	top_hbox.add_child(mode_opt)

	var snap_btn := CheckButton.new()
	snap_btn.text = "Snap Grid"
	snap_btn.button_pressed = false
	snap_btn.toggled.connect(func(on: bool):
		_ui_snap_grid = on
		if _ui_canvas != null:
			_ui_canvas.queue_redraw()
	)
	top_hbox.add_child(snap_btn)

	var reset_sel_btn := Button.new()
	reset_sel_btn.text = "Reset Selected"
	reset_sel_btn.pressed.connect(func():
		var builtin := SettingsManager.get_builtin_default_ui_layout()
		if builtin.has(_ui_selected_id):
			_ui_layout_data[_ui_selected_id] = (builtin[_ui_selected_id] as Dictionary).duplicate()
			_sync_ui_inspector()
			if _ui_canvas != null:
				_ui_canvas.queue_redraw()
			if _ui_status_lbl != null:
				_ui_status_lbl.text = "Reset %s to built-in default." % _ui_selected_id
				_ui_status_lbl.modulate = Color(0.85, 0.90, 1.0)
	)
	top_hbox.add_child(reset_sel_btn)

	var reset_all_btn := Button.new()
	reset_all_btn.text = "Reset Built-in"
	reset_all_btn.pressed.connect(func():
		_ui_layout_data = SettingsManager.get_builtin_default_ui_layout()
		_sync_ui_inspector()
		if _ui_canvas != null:
			_ui_canvas.queue_redraw()
		if _ui_status_lbl != null:
			_ui_status_lbl.text = "All elements reset to built-in defaults (unsaved)."
			_ui_status_lbl.modulate = Color(1.0, 0.85, 0.45)
	)
	top_hbox.add_child(reset_all_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE AS DEFAULT"
	save_btn.custom_minimum_size = Vector2(150, 32)
	save_btn.modulate = Color(0.45, 1.0, 0.65)
	save_btn.pressed.connect(_save_ui_layout_as_default)
	top_hbox.add_child(save_btn)

	# 2. MIDDLE 3-COLUMN WORKSPACE
	var mid_split := HBoxContainer.new()
	mid_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_split.clip_contents = true
	mid_split.add_theme_constant_override("separation", 0)
	_ui_setter_root.add_child(mid_split)

	# 2A. LEFT DOCK: UI Elements List
	var left_dock := PanelContainer.new()
	left_dock.custom_minimum_size = Vector2(210, 0)
	left_dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_dock.clip_contents = true
	left_dock.add_theme_stylebox_override("panel", _make_dock_style(Color(0.11, 0.14, 0.20), 10))
	mid_split.add_child(left_dock)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_dock.add_child(left_scroll)

	var left_vb := VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_vb)

	left_vb.add_child(_make_section_label("HUD Elements"))
	for id in UI_ELEMENT_ORDER:
		var meta: Dictionary = UI_ELEMENT_META.get(id, {})
		var btn := Button.new()
		btn.text = str(meta.get("label", id))
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 32)
		btn.pressed.connect(func(): _select_ui_element(id))
		left_vb.add_child(btn)
		_ui_elem_btns[id] = btn

	# 2B. CENTER: Interactive 16:9 HUD Stage
	var stage_panel := Panel.new()
	stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.clip_contents = true
	stage_panel.add_theme_stylebox_override("panel", _make_dock_style(Color(0.05, 0.06, 0.09), 0))
	mid_split.add_child(stage_panel)

	_ui_canvas = Control.new()
	_ui_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_canvas.draw.connect(_on_ui_canvas_draw)
	_ui_canvas.gui_input.connect(_on_ui_canvas_gui_input)
	stage_panel.add_child(_ui_canvas)

	# 2C. RIGHT DOCK: Selected Element Inspector
	var right_dock := PanelContainer.new()
	right_dock.custom_minimum_size = Vector2(250, 0)
	right_dock.add_theme_stylebox_override("panel", _make_dock_style(Color(0.11, 0.14, 0.20), 10))
	mid_split.add_child(right_dock)

	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 10)
	_wrap_panel_vscroll(right_dock, right_vb)

	_ui_sel_lbl = _make_section_label("Selected: Move Stick")
	_ui_sel_lbl.modulate = Color(0.45, 0.95, 1.0)
	right_vb.add_child(_ui_sel_lbl)

	_ui_x_spin = _add_spin_row(right_vb, "Pos X:", 0.02, 0.98, 0.005)
	_ui_y_spin = _add_spin_row(right_vb, "Pos Y:", 0.02, 0.98, 0.005)
	_ui_x_spin.value_changed.connect(func(_v: float): _on_ui_inspector_changed())
	_ui_y_spin.value_changed.connect(func(_v: float): _on_ui_inspector_changed())

	_ui_scale_spin = _add_spin_row(right_vb, "Size (x):", 0.35, 2.50, 0.05)
	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = 0.35
	_ui_scale_slider.max_value = 2.50
	_ui_scale_slider.step = 0.05
	right_vb.add_child(_ui_scale_slider)
	_ui_scale_spin.value_changed.connect(func(v: float):
		if not _ui_syncing:
			_ui_scale_slider.set_value_no_signal(v)
			_on_ui_inspector_changed()
	)
	_ui_scale_slider.value_changed.connect(func(v: float):
		if not _ui_syncing:
			_ui_scale_spin.set_value_no_signal(v)
			_on_ui_inspector_changed()
	)

	_ui_rot_spin = _add_spin_row(right_vb, "Rot (deg):", -180.0, 180.0, 1.0)
	_ui_rot_slider = HSlider.new()
	_ui_rot_slider.min_value = -180.0
	_ui_rot_slider.max_value = 180.0
	_ui_rot_slider.step = 1.0
	right_vb.add_child(_ui_rot_slider)
	_ui_rot_spin.value_changed.connect(func(v: float):
		if not _ui_syncing:
			_ui_rot_slider.set_value_no_signal(v)
			_on_ui_inspector_changed()
	)
	_ui_rot_slider.value_changed.connect(func(v: float):
		if not _ui_syncing:
			_ui_rot_spin.set_value_no_signal(v)
			_on_ui_inspector_changed()
	)

	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 8)
	right_vb.add_child(quick_row)

	var rot_zero_btn := Button.new()
	rot_zero_btn.text = "Rot 0°"
	rot_zero_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_zero_btn.pressed.connect(func(): _ui_rot_spin.value = 0.0)
	quick_row.add_child(rot_zero_btn)

	var scale_one_btn := Button.new()
	scale_one_btn.text = "Size 1.0x"
	scale_one_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_one_btn.pressed.connect(func(): _ui_scale_spin.value = 1.0)
	quick_row.add_child(scale_one_btn)

	var right_spacer := Control.new()
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vb.add_child(right_spacer)

	_ui_status_lbl = Label.new()
	_ui_status_lbl.text = "Drag elements to arrange default HUD."
	_ui_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_ui_status_lbl.modulate = Color(0.75, 0.85, 0.95)
	right_vb.add_child(_ui_status_lbl)

	var hint := Label.new()
	hint.text = "Controls:\n• Left-Drag: Move element\n• Right-Drag / Shift+Drag: Rotate\n• Wheel: Rotate ±5°\n• Ctrl + Wheel: Resize ±0.05x"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.72, 0.78, 0.86)
	right_vb.add_child(hint)

	_select_ui_element("left_stick")


func _select_ui_element(id: String) -> void:
	_ui_selected_id = id
	for k in _ui_elem_btns.keys():
		var b: Button = _ui_elem_btns[k]
		b.set_pressed_no_signal(k == id)
		b.modulate = Color(0.45, 0.95, 1.0) if k == id else Color.WHITE
	_sync_ui_inspector()
	if _ui_canvas != null:
		_ui_canvas.queue_redraw()


func _sync_ui_inspector() -> void:
	if _ui_x_spin == null:
		return
	_ui_syncing = true
	var meta: Dictionary = UI_ELEMENT_META.get(_ui_selected_id, {})
	if _ui_sel_lbl != null:
		_ui_sel_lbl.text = "Selected: %s" % str(meta.get("label", _ui_selected_id))
	var d: Dictionary = _ui_layout_data.get(_ui_selected_id, {"x": 0.5, "y": 0.5, "scale": 1.0, "rot": 0.0})
	_ui_x_spin.value = float(d.get("x", 0.5))
	_ui_y_spin.value = float(d.get("y", 0.5))
	var sc := clampf(float(d.get("scale", 1.0)), 0.35, 2.5)
	_ui_scale_spin.value = sc
	_ui_scale_slider.set_value_no_signal(sc)
	var rot_deg := clampf(float(d.get("rot", 0.0)), -180.0, 180.0)
	_ui_rot_spin.value = rot_deg
	_ui_rot_slider.set_value_no_signal(rot_deg)
	_ui_syncing = false


func _on_ui_inspector_changed() -> void:
	if _ui_syncing:
		return
	_ui_layout_data[_ui_selected_id] = {
		"x": snappedf(_ui_x_spin.value, 0.001),
		"y": snappedf(_ui_y_spin.value, 0.001),
		"scale": snappedf(_ui_scale_spin.value, 0.01),
		"rot": snappedf(_ui_rot_spin.value, 0.1),
	}
	if _ui_canvas != null:
		_ui_canvas.queue_redraw()


func _is_ui_elem_visible(id: String) -> bool:
	if id == "btn_throw_prop":
		return false
	if _ui_preview_mode == 1: # Gunfight HUD
		return not id.begins_with("ability_")
	if _ui_preview_mode == 2: # Agent HUD
		return id not in ["btn_reload", "btn_switch", "btn_bomb", "btn_presets", "btn_zoom", "btn_pickup"]
	return true


func _get_ui_preview_rect() -> Rect2:
	if _ui_canvas == null:
		return Rect2(0, 0, 1280, 720)
	var sz := _ui_canvas.size
	var margin := 20.0
	var avail_w := maxf(200.0, sz.x - margin * 2.0)
	var avail_h := maxf(120.0, sz.y - margin * 2.0)
	var target_aspect := 16.0 / 9.0
	var w := avail_w
	var h := w / target_aspect
	if h > avail_h:
		h = avail_h
		w = h * target_aspect
	var pos := (sz - Vector2(w, h)) * 0.5
	return Rect2(pos, Vector2(w, h))


func _on_ui_canvas_draw() -> void:
	if _ui_canvas == null:
		return
	var vp := _get_ui_preview_rect()
	var vp_scale := vp.size.x / 1280.0
	var font := ThemeDB.fallback_font

	# Arena preview backdrop
	_ui_canvas.draw_rect(vp, Color(0.09, 0.11, 0.16, 1.0), true)
	_ui_canvas.draw_rect(vp, Color(0.32, 0.42, 0.58, 0.9), false, 2.0)

	# Subtle grid & safe area
	if _ui_snap_grid:
		for gx in range(1, 20):
			var px := vp.position.x + vp.size.x * (float(gx) / 20.0)
			_ui_canvas.draw_line(Vector2(px, vp.position.y), Vector2(px, vp.position.y + vp.size.y), Color(1, 1, 1, 0.06), 1.0)
		for gy in range(1, 12):
			var py := vp.position.y + vp.size.y * (float(gy) / 12.0)
			_ui_canvas.draw_line(Vector2(vp.position.x, py), Vector2(vp.position.x + vp.size.x, py), Color(1, 1, 1, 0.06), 1.0)

	# Center crosshairs
	var center := vp.position + vp.size * 0.5
	_ui_canvas.draw_line(Vector2(center.x, vp.position.y), Vector2(center.x, vp.position.y + vp.size.y), Color(0.4, 0.8, 1.0, 0.16), 1.0)
	_ui_canvas.draw_line(Vector2(vp.position.x, center.y), Vector2(vp.position.x + vp.size.x, center.y), Color(0.4, 0.8, 1.0, 0.16), 1.0)

	# Safe margin box
	var safe_pad := vp.size * 0.03
	_ui_canvas.draw_rect(Rect2(vp.position + safe_pad, vp.size - safe_pad * 2.0), Color(1, 1, 1, 0.08), false, 1.0)

	# Draw each HUD element
	for id in UI_ELEMENT_ORDER:
		if not _is_ui_elem_visible(id):
			continue
		var d: Dictionary = _ui_layout_data.get(id, {"x": 0.5, "y": 0.5, "scale": 1.0, "rot": 0.0})
		var meta: Dictionary = UI_ELEMENT_META.get(id, {})
		var elem_pos := vp.position + Vector2(float(d.get("x", 0.5)) * vp.size.x, float(d.get("y", 0.5)) * vp.size.y)
		var elem_scale := float(d.get("scale", 1.0)) * vp_scale
		var elem_rot := deg_to_rad(float(d.get("rot", 0.0)))
		var base_sz: Vector2 = meta.get("size", Vector2(72, 72))
		var col: Color = meta.get("color", Color.WHITE)
		var kind: String = str(meta.get("kind", "circle"))
		var short_txt: String = str(meta.get("short", id))
		var is_sel := (id == _ui_selected_id)

		_ui_canvas.draw_set_transform(elem_pos, elem_rot, Vector2(elem_scale, elem_scale))
		if kind == "stick":
			var r := base_sz.x * 0.5
			if id == "right_stick":
				var aim_r: float = r * 0.78
				var band_mid: float = (r + aim_r) * 0.5
				_ui_canvas.draw_arc(Vector2.ZERO, band_mid, 0.0, TAU, 40, Color(0.96, 0.24, 0.20, 0.28), r - aim_r)
				_ui_canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.38, 0.30, 0.92), 2.8)
				_ui_canvas.draw_circle(Vector2.ZERO, aim_r, Color(0.06, 0.10, 0.16, 0.45))
				_ui_canvas.draw_arc(Vector2.ZERO, aim_r, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.85), 2.0)
			else:
				_ui_canvas.draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.16))
				_ui_canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.85), 2.5)
			_ui_canvas.draw_circle(Vector2.ZERO, r * 0.38, Color(col.r, col.g, col.b, 0.42))
			_ui_canvas.draw_arc(Vector2.ZERO, r * 0.38, 0.0, TAU, 24, Color.WHITE, 1.8)
			if TEX_UI_BUTTON_ICONS != null:
				var s_cell := Vector2i(4, 0) if id == "left_stick" else Vector2i(4, 1)
				var s_sz := r * 0.58
				var s_dst := Rect2(-Vector2(s_sz, s_sz) * 0.5, Vector2(s_sz, s_sz))
				var s_src := Rect2(Vector2(s_cell.x * 128.0, s_cell.y * 128.0), Vector2(128.0, 128.0))
				_ui_canvas.draw_texture_rect_region(TEX_UI_BUTTON_ICONS, s_dst, s_src, Color.WHITE)
		elif kind == "circle":
			var r := base_sz.x * 0.5
			_ui_canvas.draw_circle(Vector2.ZERO, r, Color(0.10, 0.13, 0.18, 0.85))
			_ui_canvas.draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, col, 2.5)
			_draw_ui_button_icon(_ui_canvas, id, r, col, font)
		else:
			var rect := Rect2(-base_sz * 0.5, base_sz)
			_ui_canvas.draw_rect(rect, Color(0.10, 0.13, 0.18, 0.88), true)
			_ui_canvas.draw_rect(rect, col, false, 2.0)

		if font != null and kind != "circle" and kind != "stick":
			var fsize := 13
			var tsz := font.get_string_size(short_txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
			_ui_canvas.draw_string(font, Vector2(-tsz.x * 0.5, tsz.y * 0.32), short_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color.WHITE)

		if is_sel:
			if kind in ["stick", "circle"]:
				var sel_r := base_sz.x * 0.5 + 6.0
				_ui_canvas.draw_arc(Vector2.ZERO, sel_r, 0.0, TAU, 36, Color(0.30, 0.95, 1.0, 0.95), 2.4)
			else:
				var sel_rect := Rect2(-base_sz * 0.5 - Vector2(6, 6), base_sz + Vector2(12, 12))
				_ui_canvas.draw_rect(sel_rect, Color(0.30, 0.95, 1.0, 0.95), false, 2.2)
			# Up direction arrow to visualize rotation clearly
			_ui_canvas.draw_line(Vector2(0, -base_sz.y * 0.5 - 6), Vector2(0, -base_sz.y * 0.5 - 22), Color(1.0, 0.90, 0.30), 2.5)
			_ui_canvas.draw_circle(Vector2(0, -base_sz.y * 0.5 - 22), 4.0, Color(1.0, 0.90, 0.30))

	_ui_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Bottom info bar on canvas
	if font != null:
		var sel_d: Dictionary = _ui_layout_data.get(_ui_selected_id, {})
		var info := "%s  |  X: %.3f  Y: %.3f  Size: %.2fx  Rot: %.1f°" % [
			_ui_selected_id,
			float(sel_d.get("x", 0.5)),
			float(sel_d.get("y", 0.5)),
			float(sel_d.get("scale", 1.0)),
			float(sel_d.get("rot", 0.0))
		]
		_ui_canvas.draw_string(font, Vector2(vp.position.x + 12, vp.position.y + vp.size.y - 12), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.82, 0.94, 1.0))


const TEX_UI_BUTTON_ICONS: Texture2D = preload("res://assets/sprites/ui/ui_button_icons.png")


func _draw_ui_button_icon(c: Control, id: String, r: float, _col: Color, font: Font) -> void:
	var cell := Vector2i(-1, -1)
	match id:
		"btn_reload":       cell = Vector2i(0, 0)
		"btn_switch":       cell = Vector2i(1, 0)
		"btn_bomb":         cell = Vector2i(2, 0)
		"btn_shoe":         cell = Vector2i(3, 0)
		"btn_interact":     cell = Vector2i(0, 1)
		"btn_pickup":       cell = Vector2i(1, 1)
		"btn_zoom":         cell = Vector2i(2, 1)
		"btn_throw_prop":   cell = Vector2i(3, 1)
		"btn_presets":      cell = Vector2i(3, 3)
	if cell.x >= 0 and TEX_UI_BUTTON_ICONS != null:
		var icon_sz: float = r * (1.04 if id == "btn_zoom" else 1.36)
		var dst_off := Vector2(0.0, -7.0) if id == "btn_zoom" else (Vector2(0.0, -3.0) if id == "btn_bomb" else Vector2.ZERO)
		var dst := Rect2(-Vector2(icon_sz, icon_sz) * 0.5 + dst_off, Vector2(icon_sz, icon_sz))
		var src := Rect2(Vector2(cell.x * 128.0, cell.y * 128.0), Vector2(128.0, 128.0))
		c.draw_texture_rect_region(TEX_UI_BUTTON_ICONS, dst, src, Color.WHITE)
		if id == "btn_bomb" and font != null:
			c.draw_string(font, Vector2(6, 18), "x3", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		elif id == "btn_zoom" and font != null:
			c.draw_string(font, Vector2(-7, 23), "2x", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
		return
	if font != null:
		var st := str(UI_ELEMENT_META.get(id, {}).get("short", id))
		var tsz := font.get_string_size(st, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		c.draw_string(font, Vector2(-tsz.x * 0.5, tsz.y * 0.32), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _on_ui_canvas_gui_input(event: InputEvent) -> void:
	var vp := _get_ui_preview_rect()
	var vp_scale := vp.size.x / 1280.0

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var picked := ""
				for i in range(UI_ELEMENT_ORDER.size() - 1, -1, -1):
					var id: String = UI_ELEMENT_ORDER[i]
					if not _is_ui_elem_visible(id):
						continue
					var d: Dictionary = _ui_layout_data.get(id, {})
					var meta: Dictionary = UI_ELEMENT_META.get(id, {})
					var elem_pos := vp.position + Vector2(float(d.get("x", 0.5)) * vp.size.x, float(d.get("y", 0.5)) * vp.size.y)
					var elem_scale := maxf(0.35, float(d.get("scale", 1.0))) * vp_scale
					var elem_rot := deg_to_rad(float(d.get("rot", 0.0)))
					var local_p := (mb.position - elem_pos).rotated(-elem_rot) / elem_scale
					var half_sz: Vector2 = meta.get("size", Vector2(72, 72)) * 0.5 + Vector2(8, 8)
					if absf(local_p.x) <= half_sz.x and absf(local_p.y) <= half_sz.y:
						picked = id
						break
				if picked != "":
					_select_ui_element(picked)
					_ui_dragging = true
					_ui_drag_rotating = (mb.button_index == MOUSE_BUTTON_RIGHT or mb.shift_pressed)
					_ui_drag_start_mouse = mb.position
					_ui_drag_start_elem = (_ui_layout_data.get(_ui_selected_id, {}) as Dictionary).duplicate()
			else:
				_ui_dragging = false
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if mb.ctrl_pressed:
				_ui_scale_spin.value = clampf(_ui_scale_spin.value + 0.05, 0.35, 2.50)
			else:
				_ui_rot_spin.value = wrapf(_ui_rot_spin.value - 5.0, -180.0, 180.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if mb.ctrl_pressed:
				_ui_scale_spin.value = clampf(_ui_scale_spin.value - 0.05, 0.35, 2.50)
			else:
				_ui_rot_spin.value = wrapf(_ui_rot_spin.value + 5.0, -180.0, 180.0)
	elif event is InputEventMouseMotion and _ui_dragging:
		var mm := event as InputEventMouseMotion
		var d := _ui_drag_start_elem.duplicate()
		if _ui_drag_rotating or mm.shift_pressed:
			var new_rot := float(_ui_drag_start_elem.get("rot", 0.0)) + (mm.position.x - _ui_drag_start_mouse.x) * 0.5
			d["rot"] = snappedf(clampf(new_rot, -180.0, 180.0), 0.5)
		else:
			var dx := (mm.position.x - _ui_drag_start_mouse.x) / maxf(1.0, vp.size.x)
			var dy := (mm.position.y - _ui_drag_start_mouse.y) / maxf(1.0, vp.size.y)
			var nx := clampf(float(_ui_drag_start_elem.get("x", 0.5)) + dx, 0.02, 0.98)
			var ny := clampf(float(_ui_drag_start_elem.get("y", 0.5)) + dy, 0.02, 0.98)
			if _ui_snap_grid:
				nx = snappedf(nx, 0.025)
				ny = snappedf(ny, 0.025)
			elif absf(nx - 0.5) < 0.008:
				nx = 0.5
			d["x"] = snappedf(nx, 0.001)
			d["y"] = snappedf(ny, 0.001)
		_ui_layout_data[_ui_selected_id] = d
		_sync_ui_inspector()
		_ui_canvas.queue_redraw()


# ==============================================================================
# WEAPON RANGES (BUNKER MAP) TAB
# ==============================================================================

func _get_stat_dict(wid: int) -> Dictionary:
	var k := str(wid)
	if not _weapon_stats.has(k) or not (_weapon_stats[k] is Dictionary):
		var bw := WeaponData.get_base_weapon(wid)
		_weapon_stats[k] = {
			"bullet_range": float(_weapon_ranges.get(k, bw.bullet_range)),
			"damage": bw.damage,
			"fire_interval": bw.fire_interval,
			"spread_deg": bw.spread_deg,
			"bullet_speed": bw.bullet_speed,
			"mag_size": bw.mag_size,
			"reload_time": bw.reload_time,
			"recoil_impulse": bw.recoil_impulse,
			"pellet_count": bw.pellet_count,
		}
	return _weapon_stats[k] as Dictionary


func _load_weapon_ranges() -> void:
	_weapon_ranges = WeaponData.load_weapon_ranges_dict()
	var loaded_stats := WeaponData.load_weapon_stats_dict()
	_weapon_stats.clear()
	for wid in range(WeaponData.get_total_weapon_count()):
		var k := str(wid)
		var bw := WeaponData.get_base_weapon(wid)
		var sd: Dictionary = {
			"bullet_range": float(_weapon_ranges.get(k, bw.bullet_range)),
			"damage": bw.damage,
			"fire_interval": bw.fire_interval,
			"spread_deg": bw.spread_deg,
			"bullet_speed": bw.bullet_speed,
			"mag_size": bw.mag_size,
			"reload_time": bw.reload_time,
			"recoil_impulse": bw.recoil_impulse,
			"pellet_count": bw.pellet_count,
		}
		if loaded_stats.has(k) and loaded_stats[k] is Dictionary:
			var ov: Dictionary = loaded_stats[k] as Dictionary
			for sk in ov.keys():
				sd[sk] = ov[sk]
		_weapon_ranges[k] = float(sd["bullet_range"])
		_weapon_stats[k] = sd


func _save_weapon_ranges() -> void:
	var out_ranges := {}
	var out_stats := {}
	for i in range(WeaponData.get_total_weapon_count()):
		var k := str(i)
		var sd := _get_stat_dict(i)
		sd["bullet_range"] = roundf(float(_weapon_ranges.get(k, sd.get("bullet_range", 860.0))))
		out_ranges[k] = sd["bullet_range"]
		out_stats[k] = sd

	var json_ranges := JSON.stringify(out_ranges, "\t")
	var json_stats := JSON.stringify(out_stats, "\t")
	var saved_res := false

	var fr_res := FileAccess.open(WeaponData.WEAPON_RANGES_PATH, FileAccess.WRITE)
	if fr_res != null:
		fr_res.store_string(json_ranges)
		fr_res.close()
	var fs_res := FileAccess.open(WeaponData.WEAPON_STATS_PATH, FileAccess.WRITE)
	if fs_res != null:
		fs_res.store_string(json_stats)
		fs_res.close()
		saved_res = true

	var fr_user := FileAccess.open(WeaponData.USER_WEAPON_RANGES_PATH, FileAccess.WRITE)
	if fr_user != null:
		fr_user.store_string(json_ranges)
		fr_user.close()
	var fs_user := FileAccess.open(WeaponData.USER_WEAPON_STATS_PATH, FileAccess.WRITE)
	if fs_user != null:
		fs_user.store_string(json_stats)
		fs_user.close()

	WeaponData.reload_weapon_stats()
	WeaponData.save_weapon_muzzles(_weapon_muzzles, true)
	if _range_status_lbl != null:
		_range_status_lbl.text = "Saved stats, ranges & muzzle points!" if saved_res else "Saved to user://!"
		_range_status_lbl.modulate = Color(0.45, 1.0, 0.65)


func _build_range_editor_tab(main_vbox: VBoxContainer) -> void:
	_range_mode_root = VBoxContainer.new()
	_range_mode_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_range_mode_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_range_mode_root.add_theme_constant_override("separation", 0)
	_range_mode_root.visible = false
	main_vbox.add_child(_range_mode_root)

	# 1. TOP TOOLBAR
	var top_hbox := _make_flow_bar(_range_mode_root, Color(0.10, 0.13, 0.19), 8, 8, 6)

	var title := Label.new()
	title.text = "WEAPONS STUDIO"
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color(1.0, 0.45, 0.42)
	top_hbox.add_child(title)

	_subtab_muzzle_btn = Button.new()
	_subtab_muzzle_btn.text = "Muzzle / Aim Point"
	_subtab_muzzle_btn.toggle_mode = true
	_subtab_muzzle_btn.custom_minimum_size = Vector2(150, 32)
	_subtab_muzzle_btn.pressed.connect(func(): _switch_weapon_subtab(0))
	top_hbox.add_child(_subtab_muzzle_btn)

	_subtab_range_btn = Button.new()
	_subtab_range_btn.text = "Range Setter (Bunker)"
	_subtab_range_btn.toggle_mode = true
	_subtab_range_btn.custom_minimum_size = Vector2(165, 32)
	_subtab_range_btn.pressed.connect(func(): _switch_weapon_subtab(1))
	top_hbox.add_child(_subtab_range_btn)

	var reset_sel_btn := Button.new()
	reset_sel_btn.text = "Reset Gun"
	reset_sel_btn.pressed.connect(func():
		var k := str(_range_selected_wid)
		_weapon_stats.erase(k)
		_weapon_muzzles.erase(k)
		WeaponData._muzzle_cache.erase(k)
		var def := WeaponData.get_builtin_default_ranges()
		_weapon_ranges[k] = float(def.get(k, 860.0))
		_get_stat_dict(_range_selected_wid)
		_sync_range_inspector()
		if _range_canvas != null:
			_range_canvas.queue_redraw()
		if _muzzle_canvas != null:
			_muzzle_canvas.queue_redraw()
		if _range_status_lbl != null:
			_range_status_lbl.text = "Reset gun #%d (stats, range & muzzle) to defaults." % _range_selected_wid
			_range_status_lbl.modulate = Color(0.85, 0.90, 1.0)
	)
	top_hbox.add_child(reset_sel_btn)

	var reset_all_btn := Button.new()
	reset_all_btn.text = "Reset All"
	reset_all_btn.pressed.connect(func():
		_weapon_ranges = WeaponData.get_builtin_default_ranges()
		_weapon_stats.clear()
		for wid in range(WeaponData.get_total_weapon_count()):
			_get_stat_dict(wid)
		_sync_range_inspector()
		if _range_canvas != null:
			_range_canvas.queue_redraw()
		if _range_status_lbl != null:
			_range_status_lbl.text = "All weapons reset to defaults (unsaved)."
			_range_status_lbl.modulate = Color(1.0, 0.85, 0.45)
	)
	top_hbox.add_child(reset_all_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE WEAPONS"
	save_btn.custom_minimum_size = Vector2(140, 32)
	save_btn.modulate = Color(0.45, 1.0, 0.65)
	save_btn.pressed.connect(_save_weapon_ranges)
	top_hbox.add_child(save_btn)

	# 2. MIDDLE 3-COLUMN WORKSPACE
	var mid_split := HBoxContainer.new()
	mid_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_split.clip_contents = true
	mid_split.add_theme_constant_override("separation", 0)
	_range_mode_root.add_child(mid_split)

	# 2A. LEFT DOCK: All Weapons
	var left_dock := PanelContainer.new()
	left_dock.custom_minimum_size = Vector2(210, 0)
	left_dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_dock.clip_contents = true
	left_dock.add_theme_stylebox_override("panel", _make_dock_style(Color(0.11, 0.14, 0.20), 10))
	mid_split.add_child(left_dock)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_dock.add_child(left_scroll)

	var left_vb := VBoxContainer.new()
	left_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vb.add_theme_constant_override("separation", 5)
	left_scroll.add_child(left_vb)

	var studio_groups: Array[Dictionary] = WeaponData.get_weapon_category_groups()
	for g_idx in range(studio_groups.size()):
		var grp: Dictionary = studio_groups[g_idx]
		left_vb.add_child(_make_weapon_group_header(str(grp["label"]), grp["color"] as Color, 6 if g_idx > 0 else 2))
		for wid_v in (grp["ids"] as Array):
			var wid: int = int(wid_v)
			var wd := WeaponData.get_weapon(wid, 0, 0)
			var btn := Button.new()
			btn.text = "%d: %s" % [wid, wd.display_name]
			btn.toggle_mode = true
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 30)
			btn.pressed.connect(func(): _select_range_weapon(wid))
			left_vb.add_child(btn)
			_range_gun_btns[wid] = btn

	# 2B. CENTER: Interactive Bunker Base Map Canvas
	var stage_panel := Panel.new()
	stage_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_panel.clip_contents = true
	stage_panel.add_theme_stylebox_override("panel", _make_dock_style(Color(0.05, 0.06, 0.09), 0))
	mid_split.add_child(stage_panel)

	_muzzle_canvas = Control.new()
	_muzzle_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_muzzle_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_muzzle_canvas.draw.connect(_on_muzzle_canvas_draw)
	_muzzle_canvas.gui_input.connect(_on_muzzle_canvas_gui_input)
	stage_panel.add_child(_muzzle_canvas)

	_range_canvas = Control.new()
	_range_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_range_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_range_canvas.draw.connect(_on_range_canvas_draw)
	_range_canvas.gui_input.connect(_on_range_canvas_gui_input)
	stage_panel.add_child(_range_canvas)

	# 2C. RIGHT DOCK: Weapon Stats & Range Inspector
	var right_dock := PanelContainer.new()
	right_dock.custom_minimum_size = Vector2(265, 0)
	right_dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_dock.clip_contents = true
	right_dock.add_theme_stylebox_override("panel", _make_dock_style(Color(0.11, 0.14, 0.20), 10))
	mid_split.add_child(right_dock)

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_dock.add_child(right_scroll)

	var right_vb := VBoxContainer.new()
	right_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vb.add_theme_constant_override("separation", 7)
	right_scroll.add_child(right_vb)

	_range_gun_lbl = _make_section_label("Gun: 0 - AK-47")
	_range_gun_lbl.modulate = Color(1.0, 0.55, 0.45)
	right_vb.add_child(_range_gun_lbl)

	_w_muz_x_spin = _add_spin_row(right_vb, "Muzzle X:", -100.0, 200.0, 0.5)
	_w_muz_y_spin = _add_spin_row(right_vb, "Muzzle Y:", -100.0, 100.0, 0.5)
	_w_muz_x_spin.value_changed.connect(func(v: float):
		if _range_syncing: return
		var cur: Vector2 = _get_muzzle_pos_for_wid(_range_selected_wid)
		_set_muzzle_pos_for_wid(_range_selected_wid, Vector2(v, cur.y))
	)
	_w_muz_y_spin.value_changed.connect(func(v: float):
		if _range_syncing: return
		var cur: Vector2 = _get_muzzle_pos_for_wid(_range_selected_wid)
		_set_muzzle_pos_for_wid(_range_selected_wid, Vector2(cur.x, v))
	)

	_range_spin = _add_spin_row(right_vb, "Range (px):", 80.0, 8000.0, 10.0)
	_range_spin.allow_greater = true
	_range_slider = HSlider.new()
	_range_slider.min_value = 80.0
	_range_slider.max_value = 8000.0
	_range_slider.step = 10.0
	right_vb.add_child(_range_slider)

	_range_spin.value_changed.connect(func(v: float):
		if not _range_syncing:
			_range_slider.set_value_no_signal(v)
			_weapon_ranges[str(_range_selected_wid)] = v
			_get_stat_dict(_range_selected_wid)["bullet_range"] = v
			_update_range_stats_label()
			if _range_canvas != null:
				_range_canvas.queue_redraw()
	)
	_range_slider.value_changed.connect(func(v: float):
		if not _range_syncing:
			_range_spin.set_value_no_signal(v)
			_weapon_ranges[str(_range_selected_wid)] = v
			_get_stat_dict(_range_selected_wid)["bullet_range"] = v
			_update_range_stats_label()
			if _range_canvas != null:
				_range_canvas.queue_redraw()
	)

	_w_dmg_spin    = _add_spin_row(right_vb, "Damage:",      1.0,   600.0,  1.0)
	_w_rof_spin    = _add_spin_row(right_vb, "Fire Delay:",  0.01,  5.00,   0.01)
	_w_spread_spin = _add_spin_row(right_vb, "Spread (°):",  0.0,   50.0,   0.2)
	_w_speed_spin  = _add_spin_row(right_vb, "Speed (px/s):",150.0, 6400.0, 25.0)
	_w_mag_spin    = _add_spin_row(right_vb, "Mag Size:",    1.0,   500.0,  1.0)
	_w_reload_spin = _add_spin_row(right_vb, "Reload (s):",  0.1,   12.0,   0.1)
	_w_recoil_spin = _add_spin_row(right_vb, "Recoil:",      0.0,   700.0,  5.0)
	_w_pellet_spin = _add_spin_row(right_vb, "Pellets:",     1.0,   32.0,   1.0)

	for sb: SpinBox in [_w_dmg_spin, _w_rof_spin, _w_spread_spin, _w_speed_spin, _w_mag_spin, _w_reload_spin, _w_recoil_spin, _w_pellet_spin]:
		sb.allow_greater = true
		sb.value_changed.connect(func(_v: float): _on_weapon_stat_changed())

	_range_stats_lbl = Label.new()
	_range_stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_range_stats_lbl.add_theme_font_size_override("font_size", 12)
	_range_stats_lbl.modulate = Color(0.84, 0.90, 0.96)
	right_vb.add_child(_range_stats_lbl)

	var pos_btn := Button.new()
	pos_btn.text = "Center Shooter on Bunker"
	pos_btn.pressed.connect(func():
		_range_shooter_pos = Vector2(1120.0, 680.0)
		if _range_canvas != null:
			_range_canvas.queue_redraw()
	)
	right_vb.add_child(pos_btn)

	_range_status_lbl = Label.new()
	_range_status_lbl.text = "Drag shooter or red aim line on Bunker."
	_range_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_range_status_lbl.modulate = Color(0.75, 0.85, 0.95)
	right_vb.add_child(_range_status_lbl)

	var hint := Label.new()
	hint.text = "Controls:\n• Drag Cyan Dot: Move shooter\n• Drag Anywhere Else: Aim & set range\n• Wheel: Range ±25px (Shift: ±100px)"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(0.72, 0.78, 0.86)
	right_vb.add_child(hint)

	_select_range_weapon(0)
	_switch_weapon_subtab(0)


func _switch_weapon_subtab(sub_idx: int) -> void:
	_weapon_subtab = sub_idx
	if _muzzle_canvas != null:
		_muzzle_canvas.visible = (sub_idx == 0)
		if sub_idx == 0:
			_muzzle_canvas.queue_redraw()
	if _range_canvas != null:
		_range_canvas.visible = (sub_idx == 1)
		if sub_idx == 1:
			_range_canvas.queue_redraw()
	if _subtab_muzzle_btn != null:
		_subtab_muzzle_btn.set_pressed_no_signal(sub_idx == 0)
		_subtab_muzzle_btn.modulate = Color(1.0, 0.42, 0.36) if sub_idx == 0 else Color(0.76, 0.82, 0.90)
	if _subtab_range_btn != null:
		_subtab_range_btn.set_pressed_no_signal(sub_idx == 1)
		_subtab_range_btn.modulate = Color(0.45, 0.95, 1.0) if sub_idx == 1 else Color(0.76, 0.82, 0.90)


func _get_muzzle_pos_for_wid(wid: int) -> Vector2:
	var k := str(wid)
	if _weapon_muzzles.has(k) and _weapon_muzzles[k] is Dictionary:
		var m: Dictionary = _weapon_muzzles[k] as Dictionary
		return Vector2(float(m.get("x", 44.0)), float(m.get("y", -3.0)))
	return PlayerControllerScript.get_weapon_muzzle_local_pos(wid)


func _set_muzzle_pos_for_wid(wid: int, pos: Vector2) -> void:
	var k := str(wid)
	var clean := Vector2(snappedf(pos.x, 0.1), snappedf(pos.y, 0.1))
	_weapon_muzzles[k] = {"x": clean.x, "y": clean.y}
	WeaponData._muzzle_cache[k] = {"x": clean.x, "y": clean.y}
	WeaponData._muzzle_cache_loaded = true
	if not _range_syncing and _w_muz_x_spin != null and _w_muz_y_spin != null:
		_range_syncing = true
		_w_muz_x_spin.value = clean.x
		_w_muz_y_spin.value = clean.y
		_range_syncing = false
	if _muzzle_canvas != null:
		_muzzle_canvas.queue_redraw()
	if _range_status_lbl != null:
		_range_status_lbl.text = "Gun #%d Muzzle -> (%.1f, %.1f) — click SAVE WEAPONS" % [wid, clean.x, clean.y]
		_range_status_lbl.modulate = Color(1.0, 0.62, 0.38)


func _get_gun_preview_scale_for_wid(wid: int) -> float:
	match wid:
		17: return 0.27
		19: return 0.20
		20: return 0.21
		22, 23, 24: return 0.25
		_: return 0.24


func _on_muzzle_canvas_draw() -> void:
	if _muzzle_canvas == null:
		return
	var sz: Vector2 = _muzzle_canvas.size
	var origin: Vector2 = Vector2(sz.x * 0.36, sz.y * 0.52)
	var z: float = _muzzle_zoom

	# Blueprint grid
	var step_px: float = 10.0 * z
	var gx: float = fmod(origin.x, step_px)
	while gx < sz.x:
		_muzzle_canvas.draw_line(Vector2(gx, 0.0), Vector2(gx, sz.y), Color(1, 1, 1, 0.05), 1.0)
		gx += step_px
	var gy: float = fmod(origin.y, step_px)
	while gy < sz.y:
		_muzzle_canvas.draw_line(Vector2(0.0, gy), Vector2(sz.x, gy), Color(1, 1, 1, 0.05), 1.0)
		gy += step_px
	_muzzle_canvas.draw_line(Vector2(origin.x, 0.0), Vector2(origin.x, sz.y), Color(1.0, 0.85, 0.25, 0.20), 1.2)
	_muzzle_canvas.draw_line(Vector2(0.0, origin.y), Vector2(sz.x, origin.y), Color(1.0, 0.85, 0.25, 0.20), 1.2)

	# Draw weapon sprite at exact PlayerController local offset & scale
	var wid: int = _range_selected_wid
	var gun_x: float = 18.0 if wid == 17 else 16.0
	var gun_sc: float = _get_gun_preview_scale_for_wid(wid)
	var at: AtlasTexture = WeaponData.get_weapon_atlas_texture(wid, 0)
	var draw_w: float = 256.0 * gun_sc * z
	var draw_h: float = 128.0 * gun_sc * z
	var gun_center: Vector2 = origin + Vector2(gun_x * z, 0.0)
	var gun_rect := Rect2(gun_center - Vector2(draw_w * 0.5, draw_h * 0.5), Vector2(draw_w, draw_h))
	_muzzle_canvas.draw_texture_rect(at, gun_rect, false)

	# Weapon pivot marker (0,0)
	_muzzle_canvas.draw_arc(origin, 7.0, 0.0, TAU, 20, Color(0.35, 0.90, 1.0, 0.85), 1.8)
	_muzzle_canvas.draw_circle(origin, 2.5, Color(0.35, 0.90, 1.0, 0.95))

	# Muzzle point & red aiming laser
	var muz_local: Vector2 = _get_muzzle_pos_for_wid(wid)
	var muz_screen: Vector2 = origin + muz_local * z
	_muzzle_canvas.draw_line(muz_screen, Vector2(sz.x - 16.0, muz_screen.y), Color(1.0, 0.14, 0.14, 0.88), 2.5)
	_muzzle_canvas.draw_circle(muz_screen, 6.0, Color(1.0, 0.24, 0.20, 0.95))
	_muzzle_canvas.draw_arc(muz_screen, 13.0, 0.0, TAU, 24, Color(1.0, 0.88, 0.25, 0.95), 2.0)
	_muzzle_canvas.draw_line(muz_screen + Vector2(-18.0, 0.0), muz_screen + Vector2(18.0, 0.0), Color(1.0, 0.35, 0.25, 0.95), 1.6)
	_muzzle_canvas.draw_line(muz_screen + Vector2(0.0, -18.0), muz_screen + Vector2(0.0, 18.0), Color(1.0, 0.35, 0.25, 0.95), 1.6)

	var font := ThemeDB.fallback_font
	if font != null:
		var wd := WeaponData.get_base_weapon(wid)
		_muzzle_canvas.draw_string(font, origin + Vector2(10.0, -10.0), "PIVOT (0,0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 0.92, 1.0, 0.85))
		_muzzle_canvas.draw_string(font, muz_screen + Vector2(16.0, -14.0), "MUZZLE (%.1f, %.1f)" % [muz_local.x, muz_local.y], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.88, 0.30))
		_muzzle_canvas.draw_string(font, Vector2(16.0, sz.y - 16.0), "#%d %s  |  Drag anywhere to place Muzzle / Aim Point  |  Scroll to zoom (%.1fx)" % [wid, wd.display_name, z], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.82, 0.90, 0.98))


func _on_muzzle_canvas_gui_input(event: InputEvent) -> void:
	if _muzzle_canvas == null:
		return
	var origin: Vector2 = Vector2(_muzzle_canvas.size.x * 0.36, _muzzle_canvas.size.y * 0.52)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_muzzle_dragging = mb.pressed
			if mb.pressed:
				var local_p: Vector2 = (mb.position - origin) / _muzzle_zoom
				_set_muzzle_pos_for_wid(_range_selected_wid, local_p)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_muzzle_zoom = clampf(_muzzle_zoom + 0.8, 3.5, 16.0)
			_muzzle_canvas.queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_muzzle_zoom = clampf(_muzzle_zoom - 0.8, 3.5, 16.0)
			_muzzle_canvas.queue_redraw()
	elif event is InputEventMouseMotion and _muzzle_dragging:
		var mm := event as InputEventMouseMotion
		var local_p: Vector2 = (mm.position - origin) / _muzzle_zoom
		_set_muzzle_pos_for_wid(_range_selected_wid, local_p)


func _on_weapon_stat_changed() -> void:
	if _range_syncing:
		return
	var sd := _get_stat_dict(_range_selected_wid)
	sd["damage"]         = int(_w_dmg_spin.value)
	sd["fire_interval"]  = snappedf(_w_rof_spin.value, 0.005)
	sd["spread_deg"]     = snappedf(_w_spread_spin.value, 0.1)
	sd["bullet_speed"]   = snappedf(_w_speed_spin.value, 1.0)
	sd["mag_size"]       = int(_w_mag_spin.value)
	sd["reload_time"]    = snappedf(_w_reload_spin.value, 0.05)
	sd["recoil_impulse"] = snappedf(_w_recoil_spin.value, 1.0)
	sd["pellet_count"]   = int(_w_pellet_spin.value)
	_update_range_stats_label()
	if _range_canvas != null:
		_range_canvas.queue_redraw()


func _select_range_weapon(wid: int) -> void:
	_range_selected_wid = wid
	for k in _range_gun_btns.keys():
		var b: Button = _range_gun_btns[k]
		b.set_pressed_no_signal(int(k) == wid)
		b.modulate = Color(1.0, 0.55, 0.45) if int(k) == wid else Color.WHITE
	_sync_range_inspector()
	if _range_canvas != null:
		_range_canvas.queue_redraw()
	if _muzzle_canvas != null:
		_muzzle_canvas.queue_redraw()


func _sync_range_inspector() -> void:
	if _range_spin == null:
		return
	_range_syncing = true
	var wd := WeaponData.get_base_weapon(_range_selected_wid)
	var sd := _get_stat_dict(_range_selected_wid)
	if _range_gun_lbl != null:
		_range_gun_lbl.text = "#%d %s (%s)" % [_range_selected_wid, wd.display_name, wd.category]
	var cur_muz: Vector2 = _get_muzzle_pos_for_wid(_range_selected_wid)
	if _w_muz_x_spin != null:
		_w_muz_x_spin.value = cur_muz.x
	if _w_muz_y_spin != null:
		_w_muz_y_spin.value = cur_muz.y
	var r_val := maxf(float(_weapon_ranges.get(str(_range_selected_wid), sd.get("bullet_range", 860.0))), 80.0)
	_range_spin.value = r_val
	_range_slider.set_value_no_signal(r_val)
	_w_dmg_spin.value    = float(sd.get("damage", wd.damage))
	_w_rof_spin.value    = float(sd.get("fire_interval", wd.fire_interval))
	_w_spread_spin.value = float(sd.get("spread_deg", wd.spread_deg))
	_w_speed_spin.value  = float(sd.get("bullet_speed", wd.bullet_speed))
	_w_mag_spin.value    = float(sd.get("mag_size", wd.mag_size))
	_w_reload_spin.value = float(sd.get("reload_time", wd.reload_time))
	_w_recoil_spin.value = float(sd.get("recoil_impulse", wd.recoil_impulse))
	_w_pellet_spin.value = float(sd.get("pellet_count", wd.pellet_count))
	_range_syncing = false
	_update_range_stats_label()


func _update_range_stats_label() -> void:
	if _range_stats_lbl == null:
		return
	var sd := _get_stat_dict(_range_selected_wid)
	var r_val := float(_weapon_ranges.get(str(_range_selected_wid), 860.0))
	var dmg := int(sd.get("damage", 16))
	var pel := int(sd.get("pellet_count", 1))
	var rof := maxf(0.03, float(sd.get("fire_interval", 0.15)))
	var spd := maxf(100.0, float(sd.get("bullet_speed", 1000.0)))
	var rpm := 60.0 / rof
	var dps := (float(dmg * pel)) / rof
	var pct := (r_val / BUNKER_W) * 100.0
	var flight_t := r_val / spd
	_range_stats_lbl.text = "ROF: %.0f RPM (%.1f/s)  |  DPS: %.0f\nBunker Width: %.1f%%  |  Flight: %.2fs" % [
		rpm, 1.0 / rof, dps, pct, flight_t
	]


func _get_bunker_preview_rect() -> Rect2:
	if _range_canvas == null:
		return Rect2(0, 0, BUNKER_W, BUNKER_H)
	var sz := _range_canvas.size
	var margin := 20.0
	var avail_w := maxf(240.0, sz.x - margin * 2.0)
	var avail_h := maxf(135.0, sz.y - margin * 2.0)
	var target_aspect := BUNKER_W / BUNKER_H
	var w := avail_w
	var h := w / target_aspect
	if h > avail_h:
		h = avail_h
		w = h * target_aspect
	var pos := (sz - Vector2(w, h)) * 0.5
	return Rect2(pos, Vector2(w, h))


func _raycast_bunker(origin: Vector2, dir: Vector2, max_dist: float) -> Vector2:
	var best_t := 1.0
	var end_p := origin + dir * max_dist
	for plat in BUNKER_PLATFORMS:
		var t_hit := _segment_rect_t(origin, end_p, plat)
		if t_hit >= 0.0 and t_hit < best_t:
			best_t = t_hit
	return origin + dir * (max_dist * best_t)


func _segment_rect_t(p0: Vector2, p1: Vector2, r: Rect2) -> float:
	var d := p1 - p0
	var tmin := 0.0
	var tmax := 1.0
	if absf(d.x) < 0.0001:
		if p0.x < r.position.x or p0.x > r.position.x + r.size.x:
			return -1.0
	else:
		var inv_x := 1.0 / d.x
		var tx1 := (r.position.x - p0.x) * inv_x
		var tx2 := (r.position.x + r.size.x - p0.x) * inv_x
		tmin = maxf(tmin, minf(tx1, tx2))
		tmax = minf(tmax, maxf(tx1, tx2))
	if absf(d.y) < 0.0001:
		if p0.y < r.position.y or p0.y > r.position.y + r.size.y:
			return -1.0
	else:
		var inv_y := 1.0 / d.y
		var ty1 := (r.position.y - p0.y) * inv_y
		var ty2 := (r.position.y + r.size.y - p0.y) * inv_y
		tmin = maxf(tmin, minf(ty1, ty2))
		tmax = minf(tmax, maxf(ty1, ty2))
	if tmax >= tmin and tmin >= 0.0 and tmin <= 1.0:
		return tmin
	return -1.0


func _on_range_canvas_draw() -> void:
	if _range_canvas == null:
		return
	var vp := _get_bunker_preview_rect()
	var sc := vp.size.x / BUNKER_W
	var font := ThemeDB.fallback_font

	# Bunker Backdrop
	_range_canvas.draw_rect(vp, Color(0.08, 0.10, 0.14, 1.0), true)

	# 200px Bunker distance grid
	var gx := 200.0
	while gx < BUNKER_W:
		var sx := vp.position.x + gx * sc
		_range_canvas.draw_line(Vector2(sx, vp.position.y), Vector2(sx, vp.position.y + vp.size.y), Color(1, 1, 1, 0.05), 1.0)
		gx += 200.0
	var gy := 200.0
	while gy < BUNKER_H:
		var sy := vp.position.y + gy * sc
		_range_canvas.draw_line(Vector2(vp.position.x, sy), Vector2(vp.position.x + vp.size.x, sy), Color(1, 1, 1, 0.05), 1.0)
		gy += 200.0

	# Bunker Platforms & Walls
	for plat in BUNKER_PLATFORMS:
		var pr := Rect2(vp.position + plat.position * sc, plat.size * sc)
		_range_canvas.draw_rect(pr, Color(0.24, 0.30, 0.38, 0.95), true)
		_range_canvas.draw_rect(pr, Color(0.42, 0.52, 0.65, 0.95), false, 1.2)

	# Bunker Spawn Points
	for sp: Vector2 in [Vector2(220, 1020), Vector2(2020, 1020), Vector2(480, 350), Vector2(1760, 350), Vector2(1120, 230), Vector2(1120, 660)]:
		var spp: Vector2 = vp.position + sp * sc
		_range_canvas.draw_circle(spp, 4.0, Color(0.45, 0.85, 1.0, 0.35))

	# Shooter & Range Visualization
	var r_px := float(_weapon_ranges.get(str(_range_selected_wid), 860.0))
	var dir := Vector2.from_angle(_range_aim_angle)
	var hit_world := _raycast_bunker(_range_shooter_pos, dir, r_px)
	var max_world := _range_shooter_pos + dir * r_px

	var p_shoot := vp.position + _range_shooter_pos * sc
	var p_hit := vp.position + hit_world * sc
	var p_max := vp.position + max_world * sc

	# Full-range faint circle
	_range_canvas.draw_arc(p_shoot, r_px * sc, 0.0, TAU, 64, Color(1.0, 0.25, 0.22, 0.20), 1.2)
	# Unobstructed extension beyond wall (faint dashed/thin)
	if p_hit.distance_to(p_max) > 2.0:
		_range_canvas.draw_line(p_hit, p_max, Color(1.0, 0.25, 0.22, 0.22), 1.5)
	# Accuracy spread cone
	var sd := _get_stat_dict(_range_selected_wid)
	var spread_rad := deg_to_rad(float(sd.get("spread_deg", 2.0)))
	if spread_rad > 0.002:
		var cone_col := Color(1.0, 0.78, 0.30, 0.35)
		var p_sp1 := vp.position + _raycast_bunker(_range_shooter_pos, Vector2.from_angle(_range_aim_angle - spread_rad), r_px) * sc
		var p_sp2 := vp.position + _raycast_bunker(_range_shooter_pos, Vector2.from_angle(_range_aim_angle + spread_rad), r_px) * sc
		_range_canvas.draw_line(p_shoot, p_sp1, cone_col, 1.4)
		_range_canvas.draw_line(p_shoot, p_sp2, cone_col, 1.4)

	# Active Red Aim / Range Line
	_range_canvas.draw_line(p_shoot, p_hit, Color(1.0, 0.18, 0.18, 0.92), 2.8)
	_range_canvas.draw_circle(p_hit, 5.0, Color(1.0, 0.30, 0.25, 0.95))
	_range_canvas.draw_circle(p_max, 4.5, Color(1.0, 0.70, 0.25, 0.85))

	# Shooter stand-in marker
	_range_canvas.draw_circle(p_shoot, 10.0, Color(0.25, 0.90, 1.0, 0.35))
	_range_canvas.draw_arc(p_shoot, 10.0, 0.0, TAU, 24, Color(0.35, 0.95, 1.0, 0.95), 2.2)
	_range_canvas.draw_circle(p_shoot, 4.0, Color.WHITE)

	_range_canvas.draw_rect(vp, Color(0.35, 0.45, 0.62, 0.9), false, 2.0)

	if font != null:
		var wd := WeaponData.get_weapon(_range_selected_wid, 0, 0)
		var info := "Bunker Base (2240×1248)  |  #%d %s  |  Range: %.0f px (%.1f%% width)" % [
			_range_selected_wid, wd.display_name, r_px, (r_px / BUNKER_W) * 100.0
		]
		_range_canvas.draw_string(font, Vector2(vp.position.x + 12, vp.position.y + vp.size.y - 12), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.88, 0.85))


func _on_range_canvas_gui_input(event: InputEvent) -> void:
	var vp := _get_bunker_preview_rect()
	var sc := vp.size.x / BUNKER_W

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				var p_shoot := vp.position + _range_shooter_pos * sc
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.position.distance_to(p_shoot) <= 18.0:
					_range_drag_mode = 1
				else:
					_range_drag_mode = 2
					var world_m := (mb.position - vp.position) / sc
					var delta_w := world_m - _range_shooter_pos
					if delta_w.length() > 8.0:
						_range_aim_angle = delta_w.angle()
						var new_r := snappedf(clampf(delta_w.length(), 80.0, 8000.0), 10.0)
						_weapon_ranges[str(_range_selected_wid)] = new_r
						_sync_range_inspector()
						_range_canvas.queue_redraw()
			else:
				_range_drag_mode = 0
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			var step := 100.0 if mb.shift_pressed else 25.0
			_range_spin.value = clampf(_range_spin.value + step, 80.0, 8000.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var step := 100.0 if mb.shift_pressed else 25.0
			_range_spin.value = clampf(_range_spin.value - step, 80.0, 8000.0)
	elif event is InputEventMouseMotion and _range_drag_mode != 0:
		var mm := event as InputEventMouseMotion
		var world_m := (mm.position - vp.position) / sc
		if _range_drag_mode == 1:
			_range_shooter_pos.x = clampf(world_m.x, 48.0, BUNKER_W - 48.0)
			_range_shooter_pos.y = clampf(world_m.y, 48.0, BUNKER_H - 48.0)
		elif _range_drag_mode == 2:
			var delta_w := world_m - _range_shooter_pos
			if delta_w.length() > 8.0:
				_range_aim_angle = delta_w.angle()
				var new_r := snappedf(clampf(delta_w.length(), 80.0, 8000.0), 10.0)
				_weapon_ranges[str(_range_selected_wid)] = new_r
				_sync_range_inspector()
		_range_canvas.queue_redraw()


# ==============================================================================
# COIN ADJUSTMENT / ECONOMY TAB
# ==============================================================================

func _build_coin_economy_tab(main_vbox: VBoxContainer) -> void:
	_coin_mode_root = VBoxContainer.new()
	_coin_mode_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coin_mode_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_coin_mode_root.add_theme_constant_override("separation", 0)
	_coin_mode_root.visible = false
	main_vbox.add_child(_coin_mode_root)

	# Top bar
	var top_h := _make_flow_bar(_coin_mode_root, Color(0.10, 0.13, 0.19), 8, 10, 6)

	var hdr := Label.new()
	hdr.text = "NC ECONOMY & SKIN / AGENT PRICE EDITOR"
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.modulate = Color(1.0, 0.86, 0.30)
	top_h.add_child(hdr)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Defaults"
	reset_btn.custom_minimum_size = Vector2(130, 32)
	reset_btn.pressed.connect(func():
		ProfileManager.reset_economy_defaults()
		_sync_coin_economy_ui()
		_coin_status_lbl.text = "Reset NC rewards & prices to defaults (click Save to write file)."
		_coin_status_lbl.modulate = Color(1.0, 0.84, 0.35)
	)
	top_h.add_child(reset_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE NC ECONOMY"
	save_btn.custom_minimum_size = Vector2(165, 32)
	save_btn.modulate = Color(0.42, 1.0, 0.62)
	save_btn.pressed.connect(func():
		for sp in [_coin_kill_spin, _coin_treasure_spin, _coin_win_spin, _coin_match_spin, _coin_agent_spin]:
			if is_instance_valid(sp):
				(sp as SpinBox).apply()
		for k in _coin_skin_spins.keys():
			var s_box = _coin_skin_spins[k]
			if is_instance_valid(s_box):
				(s_box as SpinBox).apply()
		var ok: bool = ProfileManager.save_economy_config(true)
		_coin_status_lbl.text = "Saved assets/data/coin_economy.json!" if ok else "Failed to save coin_economy.json"
		_coin_status_lbl.modulate = Color(0.40, 1.0, 0.58) if ok else Color(1.0, 0.42, 0.38)
	)
	top_h.add_child(save_btn)

	# Body 3 columns: Left = Rewards & Agent Price | Mid = Gun List | Right = Per-Gun Skin Prices
	var split := HBoxContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.clip_contents = true
	split.add_theme_constant_override("separation", 0)
	_coin_mode_root.add_child(split)

	# LEFT COLUMN: Rewards + Agent Price + Dev Balance (scrollable so it never forces split taller than screen)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	left_panel.add_theme_stylebox_override("panel", _make_dock_style(Color(0.08, 0.11, 0.16), 12))
	split.add_child(left_panel)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	_wrap_panel_vscroll(left_panel, lv)

	var rw_hdr := _make_section_label("MATCH NC REWARDS")
	rw_hdr.modulate = Color(1.0, 0.86, 0.32)
	lv.add_child(rw_hdr)

	_coin_kill_spin = _add_coin_spin_row(lv, "NC / Kill:", 0, 10000, 5)
	_coin_kill_spin.value_changed.connect(func(v: float):
		if _coin_syncing: return
		ProfileManager.kill_reward = int(v)
	)
	_coin_treasure_spin = _add_coin_spin_row(lv, "Treasure Box:", 0, 10000, 5)
	_coin_treasure_spin.value_changed.connect(func(v: float):
		if _coin_syncing: return
		ProfileManager.treasure_reward = int(v)
	)
	_coin_win_spin = _add_coin_spin_row(lv, "Match Win:", 0, 10000, 10)
	_coin_win_spin.value_changed.connect(func(v: float):
		if _coin_syncing: return
		ProfileManager.win_reward = int(v)
	)
	_coin_match_spin = _add_coin_spin_row(lv, "Match Finish:", 0, 10000, 5)
	_coin_match_spin.value_changed.connect(func(v: float):
		if _coin_syncing: return
		ProfileManager.match_reward = int(v)
	)

	lv.add_child(HSeparator.new())

	var ag_hdr := _make_section_label("AGENT UNLOCK PRICE")
	ag_hdr.modulate = Color(0.55, 0.86, 1.0)
	lv.add_child(ag_hdr)

	_coin_agent_spin = _add_coin_spin_row(lv, "Each Locked Agent:", 0, 100000, 100)
	_coin_agent_spin.value_changed.connect(func(v: float):
		if _coin_syncing: return
		ProfileManager.agent_unlock_price = int(v)
	)

	var ag_note := Label.new()
	ag_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ag_note.add_theme_font_size_override("font_size", 11)
	ag_note.modulate = Color(0.72, 0.80, 0.90)
	ag_note.text = "Starter agents are unlocked by default. All remaining agents share this NC price in normal modes (all agents are free in Practice Mode)."
	lv.add_child(ag_note)

	lv.add_child(HSeparator.new())

	var bal_hdr := _make_section_label("YOUR TEST BALANCE")
	bal_hdr.modulate = Color(0.45, 0.96, 0.62)
	lv.add_child(bal_hdr)

	_coin_bal_lbl = Label.new()
	_coin_bal_lbl.add_theme_font_size_override("font_size", 15)
	_coin_bal_lbl.modulate = Color(1.0, 0.86, 0.28)
	lv.add_child(_coin_bal_lbl)

	var bal_row := HBoxContainer.new()
	bal_row.add_theme_constant_override("separation", 6)
	lv.add_child(bal_row)

	var add_1k := Button.new()
	add_1k.text = "+1000"
	add_1k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_1k.pressed.connect(func():
		ProfileManager.add_coins(1000)
		_sync_coin_economy_ui()
	)
	bal_row.add_child(add_1k)

	var add_5k := Button.new()
	add_5k.text = "+5000"
	add_5k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_5k.pressed.connect(func():
		ProfileManager.add_coins(5000)
		_sync_coin_economy_ui()
	)
	bal_row.add_child(add_5k)

	var rst_bal := Button.new()
	rst_bal.text = "Set 500"
	rst_bal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rst_bal.pressed.connect(func():
		ProfileManager.coins = 500
		ProfileManager.save_profile()
		ProfileManager.coins_changed.emit(ProfileManager.coins)
		_sync_coin_economy_ui()
	)
	bal_row.add_child(rst_bal)

	var bal_row_big := HBoxContainer.new()
	bal_row_big.add_theme_constant_override("separation", 6)
	lv.add_child(bal_row_big)

	for spec in [
		{"label": "+50K", "amt": 50000, "col": Color.WHITE},
		{"label": "+100K", "amt": 100000, "col": Color.WHITE},
		{"label": "+1M", "amt": 1000000, "col": Color(1.0, 0.88, 0.32)}
	]:
		var btn := Button.new()
		var amt: int = int(spec["amt"])
		btn.text = str(spec["label"])
		btn.modulate = spec["col"] as Color
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			ProfileManager.add_coins(amt)
			_sync_coin_economy_ui()
		)
		bal_row_big.add_child(btn)

	var custom_bal_row := HBoxContainer.new()
	custom_bal_row.add_theme_constant_override("separation", 6)
	lv.add_child(custom_bal_row)

	var custom_spin := SpinBox.new()
	custom_spin.min_value = 0
	custom_spin.max_value = 100000000
	custom_spin.step = 1000
	custom_spin.value = 1000000
	custom_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_bal_row.add_child(custom_spin)

	var add_custom_btn := Button.new()
	add_custom_btn.text = "Add"
	add_custom_btn.pressed.connect(func():
		ProfileManager.add_coins(int(custom_spin.value))
		_sync_coin_economy_ui()
	)
	custom_bal_row.add_child(add_custom_btn)

	var set_custom_btn := Button.new()
	set_custom_btn.text = "Set"
	set_custom_btn.pressed.connect(func():
		ProfileManager.coins = maxi(0, int(custom_spin.value))
		ProfileManager.save_profile()
		ProfileManager.coins_changed.emit(ProfileManager.coins)
		_sync_coin_economy_ui()
	)
	custom_bal_row.add_child(set_custom_btn)

	var rst_full_btn := Button.new()
	rst_full_btn.text = "RESET FULL PLAYER DATA"
	rst_full_btn.custom_minimum_size = Vector2(0, 32)
	rst_full_btn.modulate = Color(1.0, 0.45, 0.42)
	rst_full_btn.pressed.connect(_prompt_reset_player_data)
	lv.add_child(rst_full_btn)

	var sp_v := Control.new()
	sp_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lv.add_child(sp_v)

	_coin_status_lbl = Label.new()
	_coin_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coin_status_lbl.add_theme_font_size_override("font_size", 12)
	_coin_status_lbl.modulate = Color(0.75, 0.85, 0.95)
	_coin_status_lbl.text = "Adjust any reward or individual gun skin price, then click SAVE NC ECONOMY."
	lv.add_child(_coin_status_lbl)

	# MIDDLE COLUMN: Gun Selector
	var mid_panel := PanelContainer.new()
	mid_panel.custom_minimum_size = Vector2(210, 0)
	mid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_panel.clip_contents = true
	mid_panel.add_theme_stylebox_override("panel", _make_dock_style(Color(0.06, 0.09, 0.14), 10))
	split.add_child(mid_panel)

	var mv := VBoxContainer.new()
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_theme_constant_override("separation", 6)
	mid_panel.add_child(mv)

	var gun_hdr := _make_section_label("SELECT GUN")
	gun_hdr.modulate = Color(0.55, 0.88, 1.0)
	mv.add_child(gun_hdr)

	var gun_scroll := ScrollContainer.new()
	gun_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gun_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gun_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mv.add_child(gun_scroll)

	var gun_list := VBoxContainer.new()
	gun_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gun_list.add_theme_constant_override("separation", 4)
	gun_scroll.add_child(gun_list)

	_coin_gun_btns.clear()
	var coin_groups: Array[Dictionary] = WeaponData.get_weapon_category_groups(ProfileManager.SHOP_WEAPON_IDS)
	for g_idx in range(coin_groups.size()):
		var grp: Dictionary = coin_groups[g_idx]
		gun_list.add_child(_make_weapon_group_header(str(grp["label"]), grp["color"] as Color, 6 if g_idx > 0 else 0))
		for wid_v in (grp["ids"] as Array):
			var wid: int = int(wid_v)
			var wd := WeaponData.get_weapon(wid, 0, 0)
			var b := Button.new()
			b.text = "%d: %s" % [wid, wd.display_name]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 32)
			b.pressed.connect(func(): _select_coin_gun(wid))
			gun_list.add_child(b)
			_coin_gun_btns[wid] = b

	# RIGHT COLUMN: Individual Skin Prices for Selected Gun
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.clip_contents = true
	right_panel.add_theme_stylebox_override("panel", _make_dock_style(Color(0.07, 0.10, 0.15), 12))
	split.add_child(right_panel)

	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_theme_constant_override("separation", 10)
	right_panel.add_child(rv)

	var gun_top := HBoxContainer.new()
	gun_top.add_theme_constant_override("separation", 12)
	rv.add_child(gun_top)

	_coin_gun_preview = TextureRect.new()
	_coin_gun_preview.custom_minimum_size = Vector2(140, 64)
	_coin_gun_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin_gun_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gun_top.add_child(_coin_gun_preview)

	var gt_v := VBoxContainer.new()
	gt_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gt_v.alignment = BoxContainer.ALIGNMENT_CENTER
	gun_top.add_child(gt_v)

	_coin_gun_title_lbl = Label.new()
	_coin_gun_title_lbl.add_theme_font_size_override("font_size", 18)
	_coin_gun_title_lbl.modulate = Color(1.0, 0.90, 0.36)
	gt_v.add_child(_coin_gun_title_lbl)

	var tier_rule_lbl := Label.new()
	tier_rule_lbl.text = "Auto Category:  COMMON (< 4,000 NC)  •  RARE (4,000–5,999 NC)  •  PREMIUM (6,000+ NC)"
	tier_rule_lbl.add_theme_font_size_override("font_size", 11)
	tier_rule_lbl.modulate = Color(0.76, 0.86, 0.98)
	gt_v.add_child(tier_rule_lbl)

	var apply_all_btn := Button.new()
	apply_all_btn.text = "Copy This Gun's Skin Prices To ALL Guns"
	apply_all_btn.custom_minimum_size = Vector2(0, 30)
	apply_all_btn.pressed.connect(func():
		for sdef in ProfileManager.GUN_SKIN_CATALOG:
			var skey: String = str(sdef["key"])
			if skey == "default":
				continue
			var p: int = ProfileManager.get_gun_skin_price(_coin_selected_wid, skey)
			for target_wid in ProfileManager.SHOP_WEAPON_IDS:
				ProfileManager.set_gun_skin_price(target_wid, skey, p)
		_coin_status_lbl.text = "Copied this gun's skin prices to all %d guns! Click SAVE to persist." % ProfileManager.SHOP_WEAPON_IDS.size()
		_coin_status_lbl.modulate = Color(0.45, 0.96, 1.0)
	)
	gt_v.add_child(apply_all_btn)

	rv.add_child(HSeparator.new())

	var skin_scroll := ScrollContainer.new()
	skin_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skin_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	skin_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(skin_scroll)

	_coin_skin_list_box = VBoxContainer.new()
	_coin_skin_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_coin_skin_list_box.add_theme_constant_override("separation", 8)
	skin_scroll.add_child(_coin_skin_list_box)

	_sync_coin_economy_ui()


func _add_coin_spin_row(parent: Control, label_txt: String, min_v: int, max_v: int, step_v: int) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	var sb := SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = step_v
	sb.rounded = true
	sb.suffix = " NC"
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sb)
	return sb


func _select_coin_gun(wid: int) -> void:
	_coin_selected_wid = wid
	_refresh_coin_skin_rows()


func _sync_coin_economy_ui() -> void:
	_coin_syncing = true
	if is_instance_valid(_coin_kill_spin):
		_coin_kill_spin.value = ProfileManager.kill_reward
	if is_instance_valid(_coin_treasure_spin):
		_coin_treasure_spin.value = ProfileManager.treasure_reward
	if is_instance_valid(_coin_win_spin):
		_coin_win_spin.value = ProfileManager.win_reward
	if is_instance_valid(_coin_match_spin):
		_coin_match_spin.value = ProfileManager.match_reward
	if is_instance_valid(_coin_agent_spin):
		_coin_agent_spin.value = ProfileManager.agent_unlock_price
	if is_instance_valid(_coin_bal_lbl):
		_coin_bal_lbl.text = "Current Balance: %s NC" % ProfileManager.format_coins(ProfileManager.coins)
	_coin_syncing = false
	_refresh_coin_skin_rows()


func _refresh_coin_skin_rows() -> void:
	if not is_instance_valid(_coin_skin_list_box):
		return
	var wid: int = _coin_selected_wid
	var wd := WeaponData.get_weapon(wid, 0, 0)
	if is_instance_valid(_coin_gun_title_lbl):
		_coin_gun_title_lbl.text = "%s (ID %d) — Individual Skin Prices" % [wd.display_name, wid]
	if is_instance_valid(_coin_gun_preview):
		_coin_gun_preview.texture = WeaponData.get_weapon_atlas_texture(wid, 0)
	for k in _coin_gun_btns:
		var b: Button = _coin_gun_btns[k] as Button
		if is_instance_valid(b):
			b.modulate = Color(1.0, 0.86, 0.30) if int(k) == wid else Color(0.82, 0.86, 0.94)

	for c in _coin_skin_list_box.get_children():
		c.queue_free()
	_coin_skin_spins.clear()

	for sdef in ProfileManager.GUN_SKIN_CATALOG:
		var skey: String = str(sdef["key"])
		var sname: String = ProfileManager.get_gun_skin_name(wid, skey)
		var badge: Color = ProfileManager.get_gun_skin_badge(wid, skey)
		var tint: Color = ProfileManager.get_gun_skin_tint(wid, skey)
		var cur_price: int = ProfileManager.get_gun_skin_price(wid, skey)

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.10, 0.14, 0.21, 0.95)
		csb.border_color = badge
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		csb.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", csb)
		_coin_skin_list_box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(86, 42)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = WeaponData.get_weapon_atlas_texture(wid, int(sdef.get("sheet_row", 0)))
		preview.modulate = tint
		row.add_child(preview)

		var nl := Label.new()
		nl.text = "%s (%s)" % [sname, skey]
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.add_theme_font_size_override("font_size", 14)
		nl.modulate = badge.lightened(0.25)
		row.add_child(nl)

		var tier_pill := PanelContainer.new()
		tier_pill.custom_minimum_size = Vector2(98, 28)
		tier_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tp_sb := StyleBoxFlat.new()
		tp_sb.set_border_width_all(1)
		tp_sb.set_corner_radius_all(6)
		tp_sb.content_margin_left = 8.0
		tp_sb.content_margin_right = 8.0
		tp_sb.content_margin_top = 2.0
		tp_sb.content_margin_bottom = 2.0
		tier_pill.add_theme_stylebox_override("panel", tp_sb)
		var tier_lbl := Label.new()
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tier_lbl.add_theme_font_size_override("font_size", 11)
		tier_pill.add_child(tier_lbl)
		row.add_child(tier_pill)

		var update_tier_pill := func(p_val: int) -> void:
			if skey == "default":
				tier_lbl.text = "DEFAULT"
				var dc := Color(0.72, 0.78, 0.86)
				tier_lbl.modulate = dc
				tp_sb.border_color = dc
				tp_sb.bg_color = dc.darkened(0.78)
				return
			var tk: String = ProfileManager.get_skin_tier_for_price(p_val)
			var tc: Color = ProfileManager.get_skin_tier_color(tk)
			tier_lbl.text = ProfileManager.get_skin_tier_label(tk)
			tier_lbl.modulate = tc.lightened(0.18)
			tp_sb.border_color = tc
			tp_sb.bg_color = tc.darkened(0.75)

		update_tier_pill.call(cur_price)

		var sb := SpinBox.new()
		sb.min_value = 0
		sb.max_value = 50000
		sb.step = 1
		sb.rounded = true
		sb.suffix = " NC"
		sb.custom_minimum_size = Vector2(150, 32)
		sb.value = cur_price
		if skey == "default":
			sb.editable = false
			sb.value = 0
		else:
			sb.value_changed.connect(func(v: float):
				var iv: int = int(v)
				ProfileManager.set_gun_skin_price(wid, skey, iv)
				update_tier_pill.call(iv)
			)
			var le: LineEdit = sb.get_line_edit()
			if le != null:
				le.text_changed.connect(func(raw_txt: String):
					var clean_txt: String = raw_txt.replace(",", "").replace("NC", "").replace("nc", "").strip_edges()
					if clean_txt.is_valid_int():
						var iv: int = clampi(int(clean_txt), 0, 50000)
						ProfileManager.set_gun_skin_price(wid, skey, iv)
						update_tier_pill.call(iv)
				)
		row.add_child(sb)
		_coin_skin_spins[skey] = sb


func _build_nc_shop_tab(main_vbox: VBoxContainer) -> void:
	_nc_shop_root = VBoxContainer.new()
	_nc_shop_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nc_shop_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nc_shop_root.add_theme_constant_override("separation", 0)
	_nc_shop_root.visible = false
	main_vbox.add_child(_nc_shop_root)

	var top_h := _make_flow_bar(_nc_shop_root, Color(0.10, 0.13, 0.19), 8, 10, 6)

	var hdr := Label.new()
	hdr.text = "NC SHOP PACKS EDITOR"
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.modulate = Color(0.38, 1.0, 0.58)
	top_h.add_child(hdr)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Shop Defaults"
	reset_btn.custom_minimum_size = Vector2(155, 32)
	reset_btn.pressed.connect(func():
		ProfileManager.reset_coin_shop_defaults()
		_refresh_nc_shop_editor()
		if is_instance_valid(_nc_shop_status_lbl):
			_nc_shop_status_lbl.text = "Reset NC Shop packs to defaults (click SAVE NC SHOP to write file)."
			_nc_shop_status_lbl.modulate = Color(1.0, 0.84, 0.35)
	)
	top_h.add_child(reset_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE NC SHOP"
	save_btn.custom_minimum_size = Vector2(150, 32)
	save_btn.modulate = Color(0.42, 1.0, 0.62)
	save_btn.pressed.connect(func():
		for ed in _nc_shop_pack_editors:
			var b_sb: SpinBox = ed.get("base_sb") as SpinBox
			var bon_sb: SpinBox = ed.get("bonus_sb") as SpinBox
			if is_instance_valid(b_sb):
				b_sb.apply()
			if is_instance_valid(bon_sb):
				bon_sb.apply()
		var ok: bool = ProfileManager.save_economy_config(true)
		if is_instance_valid(_nc_shop_status_lbl):
			_nc_shop_status_lbl.text = "Saved NC Shop packs to assets/data/coin_economy.json!" if ok else "Failed to save coin_economy.json"
			_nc_shop_status_lbl.modulate = Color(0.40, 1.0, 0.58) if ok else Color(1.0, 0.42, 0.38)
	)
	top_h.add_child(save_btn)

	_nc_shop_status_lbl = Label.new()
	_nc_shop_status_lbl.text = "Edit any pack's name, NC amounts, bonus NC, dollar price, or promo tag, then click SAVE NC SHOP."
	_nc_shop_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nc_shop_status_lbl.add_theme_font_size_override("font_size", 12)
	_nc_shop_status_lbl.modulate = Color(0.76, 0.86, 0.96)
	top_h.add_child(_nc_shop_status_lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_nc_shop_root.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(margin)

	_nc_shop_list_box = GridContainer.new()
	_nc_shop_list_box.columns = 2
	_nc_shop_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nc_shop_list_box.add_theme_constant_override("h_separation", 14)
	_nc_shop_list_box.add_theme_constant_override("v_separation", 12)
	margin.add_child(_nc_shop_list_box)

	_refresh_nc_shop_editor()


func _refresh_nc_shop_editor() -> void:
	if not is_instance_valid(_nc_shop_list_box):
		return
	for c in _nc_shop_list_box.get_children():
		c.queue_free()
	_nc_shop_pack_editors.clear()

	var packs: Array[Dictionary] = ProfileManager.get_coin_shop_packs()
	for pi in range(packs.size()):
		var pack: Dictionary = packs[pi]
		var accent: Color = pack.get("accent", Color(1.0, 0.84, 0.24)) as Color

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.08, 0.12, 0.18, 0.96)
		csb.border_color = accent
		csb.set_border_width_all(2)
		csb.set_corner_radius_all(12)
		csb.set_content_margin_all(12)
		card.add_theme_stylebox_override("panel", csb)
		_nc_shop_list_box.add_child(card)

		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		card.add_child(vb)

		var top_r := HBoxContainer.new()
		top_r.add_theme_constant_override("separation", 8)
		vb.add_child(top_r)

		var pack_idx_lbl := Label.new()
		pack_idx_lbl.text = "PACK #%d" % (pi + 1)
		pack_idx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pack_idx_lbl.add_theme_font_size_override("font_size", 15)
		pack_idx_lbl.modulate = accent.lightened(0.20)
		top_r.add_child(pack_idx_lbl)

		var total_lbl := Label.new()
		total_lbl.add_theme_font_size_override("font_size", 14)
		total_lbl.modulate = Color(1.0, 0.88, 0.30)
		top_r.add_child(total_lbl)

		var update_total := func() -> void:
			var tot: int = maxi(0, int(pack.get("coins", 0))) + maxi(0, int(pack.get("bonus_coins", 0)))
			total_lbl.text = "TOTAL: %s NC" % ProfileManager.format_coins(tot)

		update_total.call()

		var name_le := _add_nc_pack_text_row(vb, "Display Name:", str(pack.get("name", "")))
		name_le.text_changed.connect(func(txt: String): pack["name"] = txt)

		var sku_le := _add_nc_pack_text_row(vb, "SKU ID:", str(pack.get("sku", "")))
		sku_le.text_changed.connect(func(txt: String): pack["sku"] = txt.strip_edges())

		var price_le := _add_nc_pack_text_row(vb, "Price Label:", str(pack.get("price_usd", "$0.99")))
		price_le.text_changed.connect(func(txt: String): pack["price_usd"] = txt)

		var tag_le := _add_nc_pack_text_row(vb, "Promo Tag:", str(pack.get("tag", "")))
		tag_le.placeholder_text = "e.g. POPULAR, +33% BONUS, empty for none"
		tag_le.text_changed.connect(func(txt: String): pack["tag"] = txt)

		var base_sb := _add_coin_spin_row(vb, "Base NC:", 0, 10000000, 1)
		base_sb.value = maxi(0, int(pack.get("coins", 0)))
		base_sb.value_changed.connect(func(v: float):
			pack["coins"] = int(v)
			update_total.call()
		)
		var base_le: LineEdit = base_sb.get_line_edit()
		if base_le != null:
			base_le.text_changed.connect(func(raw_txt: String):
				var clean_txt: String = raw_txt.replace(",", "").replace("NC", "").replace("nc", "").strip_edges()
				if clean_txt.is_valid_int():
					pack["coins"] = clampi(int(clean_txt), 0, 10000000)
					update_total.call()
			)

		var bonus_sb := _add_coin_spin_row(vb, "Bonus NC:", 0, 10000000, 1)
		bonus_sb.value = maxi(0, int(pack.get("bonus_coins", 0)))
		bonus_sb.value_changed.connect(func(v: float):
			pack["bonus_coins"] = int(v)
			update_total.call()
		)
		var bonus_le: LineEdit = bonus_sb.get_line_edit()
		if bonus_le != null:
			bonus_le.text_changed.connect(func(raw_txt: String):
				var clean_txt: String = raw_txt.replace(",", "").replace("NC", "").replace("nc", "").strip_edges()
				if clean_txt.is_valid_int():
					pack["bonus_coins"] = clampi(int(clean_txt), 0, 10000000)
					update_total.call()
			)

		var tier_row := HBoxContainer.new()
		tier_row.add_theme_constant_override("separation", 8)
		vb.add_child(tier_row)
		var tier_lbl := Label.new()
		tier_lbl.text = "Visual Tier:"
		tier_lbl.custom_minimum_size = Vector2(130, 0)
		tier_lbl.add_theme_font_size_override("font_size", 13)
		tier_row.add_child(tier_lbl)
		var tier_opt := OptionButton.new()
		tier_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for t_i in range(6):
			tier_opt.add_item("Tier %d" % t_i, t_i)
		var cur_t: int = clampi(int(pack.get("tier", pi)), 0, 5)
		tier_opt.select(cur_t)
		tier_opt.item_selected.connect(func(idx: int):
			pack["tier"] = tier_opt.get_item_id(idx)
		)
		tier_row.add_child(tier_opt)

		_nc_shop_pack_editors.append({
			"name_le": name_le,
			"sku_le": sku_le,
			"price_le": price_le,
			"tag_le": tag_le,
			"base_sb": base_sb,
			"bonus_sb": bonus_sb,
			"tier_opt": tier_opt
		})


func _add_nc_pack_text_row(parent: Control, label_txt: String, initial_val: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_txt
	lbl.custom_minimum_size = Vector2(130, 0)
	lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)
	var le := LineEdit.new()
	le.text = initial_val
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(le)
	return le


# ==============================================================================
# ACHIEVEMENTS (100) & CRATE LOOT TABLES EDITOR TAB
# ==============================================================================

func _build_ach_and_crate_tab(main_vbox: VBoxContainer) -> void:
	_ach_crate_root = VBoxContainer.new()
	_ach_crate_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ach_crate_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ach_crate_root.add_theme_constant_override("separation", 0)
	_ach_crate_root.visible = false
	main_vbox.add_child(_ach_crate_root)

	# Sub-tab bar
	var top_h := _make_flow_bar(_ach_crate_root, Color(0.10, 0.13, 0.19), 8, 8, 6)

	var hdr := Label.new()
	hdr.text = "ACHIEVEMENTS & CRATES EDITOR"
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.modulate = Color(0.86, 0.64, 1.0)
	top_h.add_child(hdr)

	_ac_sub_ach_btn = Button.new()
	_ac_sub_ach_btn.text = "Achievements (100)"
	_ac_sub_ach_btn.toggle_mode = true
	_ac_sub_ach_btn.custom_minimum_size = Vector2(155, 32)
	_ac_sub_ach_btn.pressed.connect(func(): _switch_ac_subtab(0))
	top_h.add_child(_ac_sub_ach_btn)

	_ac_sub_crate_btn = Button.new()
	_ac_sub_crate_btn.text = "Crate Loot Tables"
	_ac_sub_crate_btn.toggle_mode = true
	_ac_sub_crate_btn.custom_minimum_size = Vector2(155, 32)
	_ac_sub_crate_btn.pressed.connect(func(): _switch_ac_subtab(1))
	top_h.add_child(_ac_sub_crate_btn)

	var save_all_btn := Button.new()
	save_all_btn.text = "SAVE ACHIEVEMENTS & CRATES"
	save_all_btn.custom_minimum_size = Vector2(220, 32)
	save_all_btn.modulate = Color(0.42, 1.0, 0.62)
	save_all_btn.pressed.connect(func():
		var ok1: bool = AchievementManager.save_config(true)
		var ok2: bool = ProfileManager.save_crate_tables(true)
		if is_instance_valid(_ac_ach_status_lbl):
			_ac_ach_status_lbl.text = "Saved achievements_config.json & crate_tables.json!" if (ok1 and ok2) else "Saved to user://!"
			_ac_ach_status_lbl.modulate = Color(0.42, 1.0, 0.62)
		if is_instance_valid(_ac_crate_status_lbl):
			_ac_crate_status_lbl.text = "Saved crate_tables.json & achievements_config.json!" if (ok1 and ok2) else "Saved to user://!"
			_ac_crate_status_lbl.modulate = Color(0.42, 1.0, 0.62)
	)
	top_h.add_child(save_all_btn)

	# --- SUB-TAB 0: ACHIEVEMENTS (100) ---
	var ach_split := HBoxContainer.new()
	ach_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ach_split.clip_contents = true
	ach_split.add_theme_constant_override("separation", 0)
	_ach_crate_root.add_child(ach_split)
	_ac_ach_panel = ach_split

	var al_panel := PanelContainer.new()
	al_panel.custom_minimum_size = Vector2(300, 0)
	al_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	al_panel.clip_contents = true
	al_panel.add_theme_stylebox_override("panel", _make_dock_style(Color(0.07, 0.10, 0.15), 10))
	ach_split.add_child(al_panel)

	var al_sc := ScrollContainer.new()
	al_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	al_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	al_panel.add_child(al_sc)

	var al_vb := VBoxContainer.new()
	al_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	al_vb.add_theme_constant_override("separation", 4)
	al_sc.add_child(al_vb)

	_ac_ach_btns.clear()
	for idx in range(AchievementManager.definitions.size()):
		var d: Dictionary = AchievementManager.definitions[idx]
		var aid: String = str(d["id"])
		var is_sub: bool = not str(d.get("parent", "")).is_empty()
		var b := Button.new()
		b.text = "%d. %s%s" % [idx + 1, ("  ↳ " if is_sub else ""), str(d["title"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 28)
		b.pressed.connect(func(): _select_ac_achievement(aid))
		al_vb.add_child(b)
		_ac_ach_btns[aid] = b

	var ar_panel := PanelContainer.new()
	ar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar_panel.add_theme_stylebox_override("panel", _make_dock_style(Color(0.09, 0.12, 0.18), 14))
	ach_split.add_child(ar_panel)

	var ar_vb := VBoxContainer.new()
	ar_vb.add_theme_constant_override("separation", 12)
	_wrap_panel_vscroll(ar_panel, ar_vb)

	_ac_ach_title_lbl = Label.new()
	_ac_ach_title_lbl.add_theme_font_size_override("font_size", 20)
	_ac_ach_title_lbl.modulate = Color(1.0, 0.88, 0.34)
	ar_vb.add_child(_ac_ach_title_lbl)

	_ac_ach_desc_lbl = Label.new()
	_ac_ach_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ac_ach_desc_lbl.modulate = Color(0.76, 0.86, 0.96)
	ar_vb.add_child(_ac_ach_desc_lbl)

	ar_vb.add_child(HSeparator.new())

	_ac_ach_coins_spin = _add_coin_spin_row(ar_vb, "NC Reward:", 0, 100000, 50)
	_ac_ach_coins_spin.value_changed.connect(func(v: float):
		if _ac_syncing: return
		var d: Dictionary = _get_selected_ac_def()
		if not d.is_empty():
			d["reward_coins"] = int(v)
	)

	_ac_ach_target_spin = _add_coin_spin_row(ar_vb, "Target Count:", 1, 10000, 1)
	_ac_ach_target_spin.suffix = ""
	_ac_ach_target_spin.value_changed.connect(func(v: float):
		if _ac_syncing: return
		var d: Dictionary = _get_selected_ac_def()
		if not d.is_empty():
			d["target"] = maxi(1, int(v))
	)

	var sk_row := HBoxContainer.new()
	sk_row.add_theme_constant_override("separation", 8)
	ar_vb.add_child(sk_row)

	var sk_lbl := Label.new()
	sk_lbl.text = "Reward Skin:"
	sk_lbl.custom_minimum_size = Vector2(130, 0)
	sk_row.add_child(sk_lbl)

	_ac_ach_weapon_opt = OptionButton.new()
	_ac_ach_weapon_opt.add_item("None (NC Only)", -1)
	_populate_grouped_weapon_option(_ac_ach_weapon_opt, ProfileManager.SHOP_WEAPON_IDS, ProfileManager.NO_SKIN_WEAPONS)
	_ac_ach_weapon_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ac_ach_weapon_opt.item_selected.connect(func(_i: int): _apply_ac_skin_dropdowns())
	sk_row.add_child(_ac_ach_weapon_opt)

	_ac_ach_skin_opt = OptionButton.new()
	for sdef in ProfileManager.GUN_SKIN_CATALOG:
		var sk: String = str(sdef["key"])
		if sk != "default":
			_ac_ach_skin_opt.add_item(str(sdef["name"]))
			_ac_ach_skin_opt.set_item_metadata(_ac_ach_skin_opt.item_count - 1, sk)
	_ac_ach_skin_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ac_ach_skin_opt.item_selected.connect(func(_i: int): _apply_ac_skin_dropdowns())
	sk_row.add_child(_ac_ach_skin_opt)

	_ac_ach_excl_cb = CheckBox.new()
	_ac_ach_excl_cb.text = "Achievement-Exclusive Skin (Cannot buy in Weapons Shop or drop from Crates)"
	_ac_ach_excl_cb.modulate = Color(1.0, 0.72, 0.98)
	_ac_ach_excl_cb.toggled.connect(func(on: bool):
		if _ac_syncing: return
		var d: Dictionary = _get_selected_ac_def()
		if not d.is_empty():
			d["exclusive_skin"] = on
	)
	ar_vb.add_child(_ac_ach_excl_cb)

	var rst_ach_btn := Button.new()
	rst_ach_btn.text = "Reset All 100 Achievements to Default Rewards"
	rst_ach_btn.custom_minimum_size = Vector2(0, 32)
	rst_ach_btn.pressed.connect(func():
		AchievementManager.reset_config_defaults()
		_select_ac_achievement(_ac_selected_ach_id)
		_ac_ach_status_lbl.text = "Reset all 100 achievements to default rewards (click SAVE to persist)."
		_ac_ach_status_lbl.modulate = Color(1.0, 0.84, 0.35)
	)
	ar_vb.add_child(rst_ach_btn)

	_ac_ach_status_lbl = Label.new()
	_ac_ach_status_lbl.text = "Select any of the 100 achievements on the left to edit its NC reward, target, or exclusive rare skin."
	_ac_ach_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ac_ach_status_lbl.modulate = Color(0.75, 0.85, 0.95)
	ar_vb.add_child(_ac_ach_status_lbl)

	# --- SUB-TAB 1: CRATE LOOT TABLES (Supply & Premium Crates) ---
	var cr_root := VBoxContainer.new()
	cr_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cr_root.clip_contents = true
	cr_root.add_theme_constant_override("separation", 10)
	_ach_crate_root.add_child(cr_root)
	_ac_crate_panel = cr_root

	var cr_pad := PanelContainer.new()
	cr_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cr_pad.clip_contents = true
	cr_pad.add_theme_stylebox_override("panel", _make_dock_style(Color(0.07, 0.10, 0.15), 12))
	cr_root.add_child(cr_pad)

	var cr_vb := VBoxContainer.new()
	cr_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cr_vb.add_theme_constant_override("separation", 10)
	cr_pad.add_child(cr_vb)

	var cr_sel_row := HFlowContainer.new()
	cr_sel_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr_sel_row.add_theme_constant_override("h_separation", 8)
	cr_sel_row.add_theme_constant_override("v_separation", 6)
	cr_vb.add_child(cr_sel_row)

	_ac_crate_std_btn = Button.new()
	_ac_crate_std_btn.text = "Supply Crate (1,000 NC / 1 Free Daily)"
	_ac_crate_std_btn.toggle_mode = true
	_ac_crate_std_btn.custom_minimum_size = Vector2(265, 32)
	_ac_crate_std_btn.pressed.connect(func():
		_ac_crate_key = "standard"
		_refresh_ac_crate_list()
	)
	cr_sel_row.add_child(_ac_crate_std_btn)

	_ac_crate_prem_btn = Button.new()
	_ac_crate_prem_btn.text = "Premium Crate (2,000 NC)"
	_ac_crate_prem_btn.toggle_mode = true
	_ac_crate_prem_btn.custom_minimum_size = Vector2(220, 32)
	_ac_crate_prem_btn.pressed.connect(func():
		_ac_crate_key = "premium"
		_refresh_ac_crate_list()
	)
	cr_sel_row.add_child(_ac_crate_prem_btn)

	_ac_crate_total_lbl = Label.new()
	_ac_crate_total_lbl.add_theme_font_size_override("font_size", 15)
	_ac_crate_total_lbl.modulate = Color(1.0, 0.88, 0.34)
	cr_sel_row.add_child(_ac_crate_total_lbl)

	var rst_cr_btn := Button.new()
	rst_cr_btn.text = "Reset Crate Defaults"
	rst_cr_btn.pressed.connect(func():
		ProfileManager.crate_tables = ProfileManager.get_default_crate_tables()
		_refresh_ac_crate_list()
		_ac_crate_status_lbl.text = "Reset both crate loot tables to defaults (click SAVE to persist)."
		_ac_crate_status_lbl.modulate = Color(1.0, 0.84, 0.35)
	)
	cr_sel_row.add_child(rst_cr_btn)

	# Add Item Bar
	var add_row := HFlowContainer.new()
	add_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_theme_constant_override("h_separation", 8)
	add_row.add_theme_constant_override("v_separation", 6)
	cr_vb.add_child(add_row)

	_ac_add_type_opt = OptionButton.new()
	_ac_add_type_opt.add_item("NC Drop", 0)
	_ac_add_type_opt.add_item("Random Premium Skin (6000+ NC)", 1)
	_ac_add_type_opt.add_item("Random Rare Skin (4000-5999 NC)", 7)
	_ac_add_type_opt.add_item("Random Common Skin (< 4000 NC)", 2)
	_ac_add_type_opt.add_item("Specific Gun Skin", 3)
	_ac_add_type_opt.add_item("2x NC (Double Balance)", 4)
	_ac_add_type_opt.add_item("Random Locked Agent Unlock", 5)
	_ac_add_type_opt.add_item("Random Character Accessory / Cosmetic", 6)
	_ac_add_type_opt.item_selected.connect(func(_i: int): _sync_ac_add_controls())
	add_row.add_child(_ac_add_type_opt)

	_ac_add_coins_spin = SpinBox.new()
	_ac_add_coins_spin.min_value = 50
	_ac_add_coins_spin.max_value = 50000
	_ac_add_coins_spin.step = 50
	_ac_add_coins_spin.value = 300
	_ac_add_coins_spin.suffix = " NC"
	_ac_add_coins_spin.custom_minimum_size = Vector2(130, 30)
	add_row.add_child(_ac_add_coins_spin)

	_ac_add_weapon_opt = OptionButton.new()
	_populate_grouped_weapon_option(_ac_add_weapon_opt, ProfileManager.SHOP_WEAPON_IDS, ProfileManager.NO_SKIN_WEAPONS)
	var first_crate_w: int = _ac_add_weapon_opt.get_item_index(0)
	if first_crate_w >= 0:
		_ac_add_weapon_opt.select(first_crate_w)
	_ac_add_weapon_opt.visible = false
	add_row.add_child(_ac_add_weapon_opt)

	_ac_add_skin_opt = OptionButton.new()
	for sdef in ProfileManager.GUN_SKIN_CATALOG:
		var sk: String = str(sdef["key"])
		if sk != "default":
			_ac_add_skin_opt.add_item(str(sdef["name"]))
			_ac_add_skin_opt.set_item_metadata(_ac_add_skin_opt.item_count - 1, sk)
	_ac_add_skin_opt.visible = false
	add_row.add_child(_ac_add_skin_opt)

	_ac_add_chance_spin = SpinBox.new()
	_ac_add_chance_spin.min_value = 0.1
	_ac_add_chance_spin.max_value = 100.0
	_ac_add_chance_spin.step = 0.5
	_ac_add_chance_spin.value = 5.0
	_ac_add_chance_spin.suffix = " %"
	_ac_add_chance_spin.custom_minimum_size = Vector2(105, 30)
	add_row.add_child(_ac_add_chance_spin)

	var add_btn := Button.new()
	add_btn.text = "+ ADD TO CRATE"
	add_btn.modulate = Color(0.45, 1.0, 0.65)
	add_btn.pressed.connect(_on_ac_add_crate_item)
	add_row.add_child(add_btn)

	cr_vb.add_child(HSeparator.new())

	var cr_sc := ScrollContainer.new()
	cr_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cr_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cr_vb.add_child(cr_sc)

	_ac_crate_list_box = VBoxContainer.new()
	_ac_crate_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ac_crate_list_box.add_theme_constant_override("separation", 6)
	cr_sc.add_child(_ac_crate_list_box)

	_ac_crate_status_lbl = Label.new()
	_ac_crate_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ac_crate_status_lbl.text = "Add or adjust crate item drop rates (%), then click SAVE ACHIEVEMENTS & CRATES."
	_ac_crate_status_lbl.modulate = Color(0.75, 0.86, 0.96)
	cr_vb.add_child(_ac_crate_status_lbl)

	if not AchievementManager.definitions.is_empty():
		_select_ac_achievement(str(AchievementManager.definitions[0]["id"]))
	_switch_ac_subtab(0)
	_refresh_ac_crate_list()


func _switch_ac_subtab(idx: int) -> void:
	_ac_subtab = idx
	if is_instance_valid(_ac_ach_panel):
		_ac_ach_panel.visible = (idx == 0)
	if is_instance_valid(_ac_crate_panel):
		_ac_crate_panel.visible = (idx == 1)
	if is_instance_valid(_ac_sub_ach_btn):
		_ac_sub_ach_btn.set_pressed_no_signal(idx == 0)
		_ac_sub_ach_btn.modulate = Color(0.86, 0.64, 1.0) if idx == 0 else Color(0.75, 0.80, 0.88)
	if is_instance_valid(_ac_sub_crate_btn):
		_ac_sub_crate_btn.set_pressed_no_signal(idx == 1)
		_ac_sub_crate_btn.modulate = Color(1.0, 0.84, 0.28) if idx == 1 else Color(0.75, 0.80, 0.88)


func _get_selected_ac_def() -> Dictionary:
	for d in AchievementManager.definitions:
		if str(d["id"]) == _ac_selected_ach_id:
			return d
	return {}


func _select_ac_achievement(aid: String) -> void:
	_ac_selected_ach_id = aid
	for k in _ac_ach_btns.keys():
		var b: Button = _ac_ach_btns[k] as Button
		if is_instance_valid(b):
			b.modulate = Color(1.0, 0.88, 0.34) if str(k) == aid else Color(0.82, 0.86, 0.94)
	var d: Dictionary = _get_selected_ac_def()
	if d.is_empty():
		return
	_ac_syncing = true
	_ac_ach_title_lbl.text = "%s  [%s]" % [str(d["title"]), str(d["category"])]
	_ac_ach_desc_lbl.text = "%s  (ID: %s | Stat: %s)" % [str(d["desc"]), aid, str(d["stat"])]
	_ac_ach_coins_spin.value = int(d["reward_coins"])
	_ac_ach_target_spin.value = int(d["target"])
	_ac_ach_excl_cb.button_pressed = bool(d.get("exclusive_skin", false))
	var sk_pair: String = str(d.get("reward_skin", ""))
	if sk_pair.contains(":"):
		var parts: PackedStringArray = sk_pair.split(":")
		var wid: int = int(parts[0])
		var skey: String = parts[1]
		var w_idx: int = _ac_ach_weapon_opt.get_item_index(wid)
		_ac_ach_weapon_opt.select(w_idx if w_idx >= 0 else 0)
		_ac_ach_skin_opt.disabled = false
		for si in range(_ac_ach_skin_opt.item_count):
			if str(_ac_ach_skin_opt.get_item_metadata(si)) == skey:
				_ac_ach_skin_opt.select(si)
				break
	else:
		_ac_ach_weapon_opt.select(0)
		_ac_ach_skin_opt.disabled = true
	_ac_syncing = false


func _apply_ac_skin_dropdowns() -> void:
	if _ac_syncing:
		return
	var d: Dictionary = _get_selected_ac_def()
	if d.is_empty():
		return
	var wid: int = _ac_ach_weapon_opt.get_selected_id()
	if wid < 0:
		d["reward_skin"] = ""
		_ac_ach_skin_opt.disabled = true
	else:
		_ac_ach_skin_opt.disabled = false
		var skey: String = str(_ac_ach_skin_opt.get_item_metadata(_ac_ach_skin_opt.selected))
		d["reward_skin"] = "%d:%s" % [wid, skey]


func _sync_ac_add_controls() -> void:
	var t_id: int = _ac_add_type_opt.get_selected_id()
	_ac_add_coins_spin.visible = (t_id == 0)
	_ac_add_weapon_opt.visible = (t_id == 3)
	_ac_add_skin_opt.visible = (t_id == 3)


func _on_ac_add_crate_item() -> void:
	var t_id: int = _ac_add_type_opt.get_selected_id()
	var ch: float = snappedf(_ac_add_chance_spin.value, 0.1)
	var item: Dictionary = {"chance": ch}
	match t_id:
		0:
			item["type"] = "coins"
			item["coins"] = int(_ac_add_coins_spin.value)
		1:
			item["type"] = "premium_skin"
		7:
			item["type"] = "rare_skin"
		2:
			item["type"] = "basic_skin"
		3:
			item["type"] = "specific_skin"
			item["weapon_id"] = _ac_add_weapon_opt.get_selected_id()
			item["skin_key"] = str(_ac_add_skin_opt.get_item_metadata(_ac_add_skin_opt.selected))
		4:
			item["type"] = "double_coins"
		5:
			item["type"] = "unlock_agent"
		6:
			item["type"] = "dummy_gear"
	if not ProfileManager.crate_tables.has(_ac_crate_key) or not (ProfileManager.crate_tables[_ac_crate_key] is Array):
		ProfileManager.crate_tables[_ac_crate_key] = []
	(ProfileManager.crate_tables[_ac_crate_key] as Array).append(item)
	_refresh_ac_crate_list()


func _refresh_ac_crate_list() -> void:
	if not is_instance_valid(_ac_crate_list_box):
		return
	if is_instance_valid(_ac_crate_std_btn):
		_ac_crate_std_btn.set_pressed_no_signal(_ac_crate_key == "standard")
		_ac_crate_std_btn.modulate = Color(0.45, 0.90, 1.0) if _ac_crate_key == "standard" else Color(0.75, 0.80, 0.88)
	if is_instance_valid(_ac_crate_prem_btn):
		_ac_crate_prem_btn.set_pressed_no_signal(_ac_crate_key == "premium")
		_ac_crate_prem_btn.modulate = Color(1.0, 0.84, 0.28) if _ac_crate_key == "premium" else Color(0.75, 0.80, 0.88)

	for c in _ac_crate_list_box.get_children():
		c.queue_free()

	var arr: Array = ProfileManager.crate_tables.get(_ac_crate_key, []) as Array
	var total_ch: float = 0.0
	for i in range(arr.size()):
		var entry: Dictionary = arr[i] as Dictionary
		var ch: float = float(entry.get("chance", 0.0))
		total_ch += ch

		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var csb := StyleBoxFlat.new()
		csb.bg_color = Color(0.10, 0.14, 0.22, 0.96)
		csb.border_color = Color(0.30, 0.45, 0.68)
		csb.set_border_width_all(1)
		csb.set_corner_radius_all(8)
		csb.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", csb)
		_ac_crate_list_box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)

		var lbl := Label.new()
		var etype: String = str(entry.get("type", "coins"))
		if etype == "premium_skin":
			lbl.text = "★ Random Premium Skin (6000+ NC)"
			lbl.modulate = Color(1.0, 0.84, 0.26)
		elif etype == "rare_skin":
			lbl.text = "◆ Random Rare Skin (4000–5999 NC)"
			lbl.modulate = Color(0.76, 0.48, 1.0)
		elif etype == "basic_skin":
			lbl.text = "● Random Common Skin (< 4000 NC)"
			lbl.modulate = Color(0.45, 0.86, 1.0)
		elif etype == "specific_skin":
			var wid: int = int(entry.get("weapon_id", 0))
			var sk: String = str(entry.get("skin_key", "gold"))
			lbl.text = "★ Specific Skin: %s — %s" % [WeaponData.get_weapon(wid, 0, 0).display_name, ProfileManager.get_gun_skin_name(wid, sk)]
			lbl.modulate = Color(1.0, 0.72, 0.98)
		elif etype == "double_coins":
			lbl.text = "★ 2x NC Crate (Double Your NC!)"
			lbl.modulate = Color(0.32, 1.0, 0.60)
		elif etype == "unlock_agent":
			lbl.text = "★ Random Locked Agent Unlock"
			lbl.modulate = Color(0.86, 0.50, 1.0)
		elif etype == "dummy_gear":
			lbl.text = "★ Random Character Accessory / Cosmetic"
			lbl.modulate = Color(0.98, 0.56, 0.92)
		else:
			lbl.text = "● NC Drop: +%d NC" % int(entry.get("coins", 200))
			lbl.modulate = Color(0.55, 1.0, 0.68)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(lbl)

		var ch_sb := SpinBox.new()
		ch_sb.min_value = 0.1
		ch_sb.max_value = 100.0
		ch_sb.step = 0.5
		ch_sb.suffix = " %"
		ch_sb.custom_minimum_size = Vector2(120, 30)
		ch_sb.value = ch
		var idx_cap: int = i
		ch_sb.value_changed.connect(func(v: float):
			(arr[idx_cap] as Dictionary)["chance"] = snappedf(v, 0.1)
			_update_ac_crate_total_label()
		)
		row.add_child(ch_sb)

		var del_btn := Button.new()
		del_btn.text = "✕"
		del_btn.custom_minimum_size = Vector2(34, 30)
		del_btn.modulate = Color(1.0, 0.42, 0.38)
		del_btn.pressed.connect(func():
			arr.remove_at(idx_cap)
			_refresh_ac_crate_list()
		)
		row.add_child(del_btn)

	_update_ac_crate_total_label()


func _update_ac_crate_total_label() -> void:
	if not is_instance_valid(_ac_crate_total_lbl):
		return
	var arr: Array = ProfileManager.crate_tables.get(_ac_crate_key, []) as Array
	var tot: float = 0.0
	for e in arr:
		if e is Dictionary:
			tot += float((e as Dictionary).get("chance", 0.0))
	_ac_crate_total_lbl.text = "Total Drop Weight: %.1f%% (%d items)" % [tot, arr.size()]


func _prompt_reset_player_data() -> void:
	if is_instance_valid(_reset_player_dlg):
		_reset_player_dlg.popup_centered()


func _on_confirm_reset_player_data() -> void:
	ProfileManager.reset_full_player_data()
	_sync_coin_economy_ui()
	var msg: String = "Reset full player data (NC, skins, cosmetics, agents, daily states & achievements)!"
	if is_instance_valid(_status_lbl):
		_status_lbl.text = msg
	if is_instance_valid(_coin_status_lbl):
		_coin_status_lbl.text = msg
	if is_instance_valid(_ac_ach_status_lbl):
		_ac_ach_status_lbl.text = msg
	if is_instance_valid(_ac_crate_status_lbl):
		_ac_crate_status_lbl.text = msg
