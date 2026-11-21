extends Control
## Interactive Pose Studio for Nameless Clash.
## Run this scene (F6 in Godot) to drag character parts & weapons into place,
## preview animations, and save pose overrides for MainMenu & gameplay.

const TEX_WEAPONS: Texture2D = preload("res://assets/sprites/weapons_sheet.png")
const PlayerControllerScript = preload("res://scripts/PlayerController.gd")
const STANCES: Array[String] = ["none", "rifle", "pistol", "bazooka", "dual", "throw_bomb"]
const STANCE_LABELS: Array[String] = [
	"Main Menu / Unarmed (none)",
	"Rifle Stance",
	"Pistol Stance",
	"Bazooka Stance",
	"Dual Stance",
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
var _gun_s: Sprite2D
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
var _flip_btn: Button
var _part_btns: Dictionary = {}
var _x_spin: SpinBox
var _y_spin: SpinBox
var _rot_spin: SpinBox
var _z_spin: SpinBox
var _status_lbl: Label

var _selected_part: String = "hand_near"
var _selected_stance: String = "none"
var _selected_agent_idx: int = 0
var _selected_part_id: int = 0
var _per_agent_scope: bool = true
var _agent_mode: bool = false
var _all_anims_scope: bool = true
var _anim_scope_btn: CheckButton
var _facing_right: bool = true
var _anim_playing: bool = false
var _selected_anim: String = "idle"
var _anim_timer: float = 0.0
var _manual_frame: int = 0
var _preview_weapon_id: int = 0

var _dragging: bool = false
var _drag_rotating: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_val: Dictionary = {}
var _drag_start_weapon_val: Dictionary = {}
var _syncing_ui: bool = false

var _pose_data: Dictionary = {"stances": {}, "agents": {}}
var _undo_stack: Array[Dictionary] = []
var _zoom_scale: float = 4.5


func _ready() -> void:
	_load_pose_data()
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
	_status_lbl.text = "Saved pose_overrides.json!" if ok_res else "Saved to user://pose_overrides.json!"
	_status_lbl.modulate = Color(0.35, 0.96, 0.58)


func _make_dock_style(bg: Color, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# 1. TOP TOOLBAR (Agent, Stance, Weapon, Undo, Save)
	var top_bar := PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _make_dock_style(Color(0.10, 0.13, 0.19), 10))
	main_vbox.add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_hbox)

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
	_stance_opt.custom_minimum_size = Vector2(165, 0)
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
	_weapon_opt.custom_minimum_size = Vector2(125, 0)
	for w_idx in range(11):
		var wd := WeaponData.get_weapon(w_idx, 0, false)
		_weapon_opt.add_item("%d: %s" % [w_idx, wd.display_name], w_idx)
	_weapon_opt.item_selected.connect(func(idx: int):
		_preview_weapon_id = idx
		if _agent_mode:
			_agent_mode = false
			_agent_mode_btn.set_pressed_no_signal(false)
		var auto_st: String = ModularCharacter.get_weapon_stance(_preview_weapon_id, _selected_stance == "dual")
		if _selected_stance == "none" or _selected_stance != auto_st:
			_selected_stance = auto_st
			var st_idx := STANCES.find(auto_st)
			if st_idx >= 0:
				_stance_opt.select(st_idx)
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	top_hbox.add_child(_weapon_opt)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(top_spacer)

	var undo_btn := Button.new()
	undo_btn.text = "Undo (Ctrl+Z)"
	undo_btn.pressed.connect(_undo)
	top_hbox.add_child(undo_btn)

	var save_btn := Button.new()
	save_btn.text = "SAVE POSE"
	save_btn.custom_minimum_size = Vector2(120, 34)
	save_btn.modulate = Color(0.45, 1.0, 0.65)
	save_btn.pressed.connect(_save_pose_data)
	top_hbox.add_child(save_btn)

	# 2. MIDDLE 3-COLUMN WORKSPACE (Left Parts Dock | Center Interactive Stage | Right Transform Dock)
	var mid_split := HBoxContainer.new()
	mid_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid_split.add_theme_constant_override("separation", 0)
	main_vbox.add_child(mid_split)

	# 2A. LEFT DOCK: Select Part & Reset
	var left_dock := PanelContainer.new()
	left_dock.custom_minimum_size = Vector2(220, 0)
	left_dock.add_theme_stylebox_override("panel", _make_dock_style(Color(0.11, 0.14, 0.20), 12))
	mid_split.add_child(left_dock)

	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 8)
	left_dock.add_child(left_vb)

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

	_gun_s = Sprite2D.new()
	_gun_s.texture = TEX_WEAPONS
	_gun_s.hframes = 11
	_gun_s.vframes = 3
	_gun_s.position = Vector2(12, 4)
	_gun_s.scale = Vector2(0.215, 0.215)
	_gun_s.z_index = -1
	_weapon_pivot.add_child(_gun_s)

	_gun_p = Sprite2D.new()
	_gun_p.texture = TEX_WEAPONS
	_gun_p.hframes = 11
	_gun_p.vframes = 3
	_gun_p.position = Vector2(16, 0)
	_gun_p.scale = Vector2(0.23, 0.23)
	_weapon_pivot.add_child(_gun_p)

	_agent_weapon_node = PlayerControllerScript.AgentWeaponVisual.new()
	_agent_weapon_node.name = "AgentWeaponVisual"
	_agent_weapon_node.visible = false
	_weapon_pivot.add_child(_agent_weapon_node)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.draw.connect(_on_overlay_draw)
	_overlay.gui_input.connect(_on_overlay_gui_input)
	_canvas_panel.add_child(_overlay)

	# 2C. RIGHT DOCK: Transform & Layer Z-Order
	var right_dock := PanelContainer.new()
	right_dock.custom_minimum_size = Vector2(250, 0)
	right_dock.add_theme_stylebox_override("panel", _make_dock_style(Color(0.11, 0.14, 0.20), 12))
	mid_split.add_child(right_dock)

	var right_vb := VBoxContainer.new()
	right_vb.add_theme_constant_override("separation", 10)
	right_dock.add_child(right_vb)

	right_vb.add_child(_make_section_label("Selected Part Transform"))
	_x_spin = _add_spin_row(right_vb, "Pos X:", -80.0, 80.0, 0.5)
	_y_spin = _add_spin_row(right_vb, "Pos Y:", -80.0, 80.0, 0.5)
	_rot_spin = _add_spin_row(right_vb, "Rot (deg):", -180.0, 180.0, 1.0)
	_z_spin = _add_spin_row(right_vb, "Z-Order:", -10.0, 10.0, 1.0)
	_x_spin.value_changed.connect(func(_v: float): _on_spin_changed())
	_y_spin.value_changed.connect(func(_v: float): _on_spin_changed())
	_rot_spin.value_changed.connect(func(_v: float): _on_spin_changed())
	_z_spin.value_changed.connect(func(_v: float): _on_spin_changed())

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
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.72, 0.78, 0.86)
	right_vb.add_child(hint)

	# 3. BOTTOM TIMELINE BAR (Animation Preview, Scope, Flip, Frame Scrubber)
	var bot_bar := PanelContainer.new()
	bot_bar.add_theme_stylebox_override("panel", _make_dock_style(Color(0.10, 0.13, 0.19), 10))
	main_vbox.add_child(bot_bar)

	var bot_hbox := HBoxContainer.new()
	bot_hbox.add_theme_constant_override("separation", 12)
	bot_bar.add_child(bot_hbox)

	_anim_play_btn = Button.new()
	_anim_play_btn.text = "Activate Anim Preview"
	_anim_play_btn.toggle_mode = true
	_anim_play_btn.custom_minimum_size = Vector2(170, 32)
	_anim_play_btn.toggled.connect(func(on: bool):
		_anim_playing = on
		_anim_play_btn.text = "Pause Anim Preview" if on else "Activate Anim Preview"
	)
	bot_hbox.add_child(_anim_play_btn)

	bot_hbox.add_child(_make_section_label("Animation:"))
	_anim_opt = OptionButton.new()
	_anim_opt.custom_minimum_size = Vector2(150, 0)
	for i in range(ANIMS.size()):
		_anim_opt.add_item(ANIM_LABELS[i], i)
	_anim_opt.item_selected.connect(func(idx: int):
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
			_frame_slider.set_value_no_signal(_manual_frame)
			_frame_lbl.text = "Frame: %d" % _manual_frame
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	bot_hbox.add_child(_anim_opt)

	_anim_scope_btn = CheckButton.new()
	_anim_scope_btn.text = "Apply to All Animations"
	_anim_scope_btn.button_pressed = true
	_anim_scope_btn.toggled.connect(func(on: bool):
		_all_anims_scope = on
		_sync_spinboxes_from_pose()
		_refresh_character_pose()
	)
	bot_hbox.add_child(_anim_scope_btn)

	_flip_btn = Button.new()
	_flip_btn.text = "Flip Facing"
	_flip_btn.pressed.connect(func():
		_facing_right = not _facing_right
		_refresh_character_pose()
	)
	bot_hbox.add_child(_flip_btn)

	_frame_lbl = Label.new()
	_frame_lbl.text = "Frame: 0"
	_frame_lbl.custom_minimum_size = Vector2(68, 0)
	bot_hbox.add_child(_frame_lbl)

	_frame_slider = HSlider.new()
	_frame_slider.min_value = 0
	_frame_slider.max_value = 7
	_frame_slider.step = 1
	_frame_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_frame_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_frame_slider.value_changed.connect(func(val: float):
		_manual_frame = int(val)
		_frame_lbl.text = "Frame: %d" % _manual_frame
		_refresh_character_pose()
	)
	bot_hbox.add_child(_frame_slider)


func _make_section_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(0.86, 0.90, 0.96)
	return l


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


func _get_target_stance_key() -> String:
	if _all_anims_scope:
		return _selected_stance
	return _selected_stance + "@" + _selected_anim


func _get_active_pose_dict() -> Dictionary:
	return ModularCharacter.get_pose_override(_selected_part_id, _selected_stance, _selected_anim)


func _get_default_part_pose(pname: String) -> Dictionary:
	match pname:
		"hand_near":
			match _selected_stance:
				"none": return {"x": -24.0, "y": 2.0, "rot": 0.0}
				"pistol": return {"x": -17.0, "y": 6.0, "rot": rad_to_deg(-1.20)}
				"bazooka": return {"x": -18.0, "y": 3.0, "rot": rad_to_deg(-1.28)}
				"dual": return {"x": -17.0, "y": 6.0, "rot": rad_to_deg(-1.18)}
				_: return {"x": -18.0, "y": 6.0, "rot": rad_to_deg(-1.18)}
		"hand_far":
			match _selected_stance:
				"none": return {"x": 24.0, "y": 2.0, "rot": 0.0}
				"pistol": return {"x": 21.0, "y": 6.0, "rot": rad_to_deg(-0.15)}
				"bazooka": return {"x": 18.0, "y": 5.0, "rot": rad_to_deg(-0.35)}
				"dual": return {"x": 17.0, "y": 5.0, "rot": rad_to_deg(-0.90)}
				_: return {"x": 20.0, "y": 6.0, "rot": rad_to_deg(-0.22)}
		"weapon":
			return {"x": 2.0, "y": 9.0, "rot": 0.0}
		_:
			return {"x": 0.0, "y": 0.0, "rot": 0.0}


func _get_part_val(pname: String) -> Dictionary:
	var d := _get_active_pose_dict()
	if d.has(pname):
		return d[pname]
	return _get_default_part_pose(pname)


func _set_part_val(pname: String, val: Dictionary) -> void:
	var old_hn: Dictionary = (_drag_start_val if _dragging else _get_part_val("hand_near")) if pname == "hand_near" else {}
	var base_w: Dictionary = (_drag_start_weapon_val if (_dragging and not _drag_start_weapon_val.is_empty()) else _get_part_val("weapon")) if pname == "hand_near" else {}
	var skey := _get_target_stance_key()
	var target_container: Dictionary
	if _per_agent_scope:
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
	target_container[pname] = {
		"x": snappedf(float(val.get("x", 0.0)), 0.5),
		"y": snappedf(float(val.get("y", 0.0)), 0.5),
		"rot": snappedf(float(val.get("rot", 0.0)), 1.0),
		"z": int(round(float(val.get("z", 0))))
	}
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
	ModularCharacter._pose_overrides = _pose_data.duplicate(true)
	ModularCharacter._pose_overrides_loaded = true


func _sync_spinboxes_from_pose() -> void:
	_syncing_ui = true
	var val := _get_part_val(_selected_part)
	_x_spin.value = float(val.get("x", 0.0))
	_y_spin.value = float(val.get("y", 0.0))
	_rot_spin.value = float(val.get("rot", 0.0))
	_z_spin.value = float(val.get("z", 0))
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
	_set_part_val(_selected_part, {"x": _x_spin.value, "y": _y_spin.value, "rot": _rot_spin.value, "z": int(_z_spin.value)})
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
		_frame_slider.set_value_no_signal(_manual_frame)
		_frame_lbl.text = "Frame: %d" % _manual_frame
		_refresh_character_pose()
	_overlay.queue_redraw()


func _refresh_character_pose() -> void:
	if _modular == null:
		return
	var flip_h := not _facing_right
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
			var swing_phase: float = fmod(_anim_timer * 2.2, 1.0)
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

	if _agent_mode and _agent_weapon_node != null:
		var ag: Dictionary = AgentData.get_agent(_selected_agent_idx)
		var bw: Dictionary = ag.get("base_weapon", {})
		_agent_weapon_node.set("weapon_style", str(bw.get("style", "sword")))
		_agent_weapon_node.set("weapon_color", bw.get("color", Color.WHITE) as Color)
		_agent_weapon_node.scale = Vector2(-1.0 if flip_h else 1.0, 1.0)
		_agent_weapon_node.visible = true
		_agent_weapon_node.queue_redraw()
		_gun_p.visible = false
		_gun_s.visible = false
	else:
		if _agent_weapon_node != null:
			_agent_weapon_node.visible = false
		_gun_p.visible = true
		_gun_p.position = Vector2(14.0 * dir, 0.0)
		_gun_p.flip_h = flip_h
		_gun_s.flip_h = flip_h
		_gun_p.frame = _preview_weapon_id
		_gun_s.frame = _preview_weapon_id
		_gun_s.visible = (_selected_stance == "dual")
		if _selected_stance == "dual":
			var far_pos: Vector2 = sock["far_pos"] as Vector2
			var far_rot: float = float(sock["far_rot"])
			_gun_s.position = (far_pos - _weapon_pivot.position).rotated(-_weapon_pivot.rotation)
			_gun_s.rotation = far_rot - _weapon_pivot.rotation
		else:
			_gun_s.position = Vector2(18.0 * dir, 4.0)
			_gun_s.rotation = 0.0


func _get_part_screen_pos(pname: String) -> Vector2:
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
	var c := _canvas_panel.size * 0.5
	_overlay.draw_line(Vector2(c.x, 0), Vector2(c.x, _overlay.size.y), Color(1, 1, 1, 0.08), 1.0)
	_overlay.draw_line(Vector2(0, c.y), Vector2(_overlay.size.x, c.y), Color(1, 1, 1, 0.08), 1.0)
	if _selected_stance != "none" or _agent_mode:
		var hn_p := _get_part_screen_pos("hand_near")
		var wp_p := _get_part_screen_pos("weapon")
		_overlay.draw_line(hn_p, wp_p, Color(0.25, 0.95, 1.0, 0.35), 1.5)
	for i in range(PARTS.size()):
		var pname: String = PARTS[i]
		if pname == "weapon" and _selected_stance == "none" and not _agent_mode:
			continue
		var p := _get_part_screen_pos(pname)
		var is_sel := (pname == _selected_part)
		var col := Color(0.25, 0.95, 1.0, 0.95) if is_sel else Color(1, 1, 1, 0.35)
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
			if _selected_part == "weapon" and _modular != null:
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
			_undo()
			get_viewport().set_input_as_handled()
