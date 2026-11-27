extends Node

signal settings_changed
signal touch_layout_changed

const SETTINGS_PATH: String = "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

const FPS_VALUES: Array[int] = [30, 60, 0]
const FPS_LABELS: Array[String] = ["30 FPS", "60 FPS", "Unlimited"]

const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_left", "label": "Move Left", "default": KEY_A},
	{"action": "move_right", "label": "Move Right", "default": KEY_D},
	{"action": "jump", "label": "Jump / Wall-Jump", "default": KEY_W},
	{"action": "crouch", "label": "Crouch", "default": KEY_S},
	{"action": "jetpack", "label": "Jetpack Thrust", "default": KEY_SPACE},
	{"action": "reload", "label": "Reload Weapon", "default": KEY_R},
	{"action": "switch_weapon", "label": "Switch Weapon", "default": KEY_Q},
	{"action": "open_lobby", "label": "Open LAN Lobby", "default": KEY_L}
]

# Controls & Input
var move_stick_sensitivity: float = 1.0
var aim_stick_sensitivity: float = 1.0
var invert_y_axis: bool = false
var auto_aim_assist: bool = true

const DEFAULT_UI_LAYOUT_PATH := "res://assets/data/default_ui_layout.json"
const USER_DEFAULT_UI_LAYOUT_PATH := "user://default_ui_layout.json"

var touch_layout: Dictionary = {}
var touch_layout_transforms: Dictionary = {}
var touch_layout_version: int = 5

# Audio
var master_volume: float = 0.85
var sfx_volume: float = 0.85
var music_volume: float = 0.45
var music_enabled: bool = true
var sfx_enabled: bool = true
var master_muted: bool = false

# Graphics & Performance
var resolution_index: int = 3
var fullscreen: bool = false
var vsync_enabled: bool = true
var fps_limit_mode: int = 1
var particle_intensity: float = 1.0
var screen_shake_intensity: float = 1.0
var show_callsigns: bool = true
var sight_laser: bool = true
var show_blood: bool = true
var damage_display: bool = false
var enhanced_visuals: bool = true
var show_diagnostics: bool = false

# Match Game Rules / Mutators (synced with NetworkManager)
var unlimited_jetpack: bool = false
var gravity_scale: float = 1.0
var jet_speed_scale: float = 0.5
var random_guns_mode: bool = false
var only_pistols: bool = false
var allow_snipers: bool = true
var allow_shotguns: bool = true
var allow_explosives: bool = true

const BGM_MENU_PATH: String = "res://assets/audio/menu_music.ogg"
const BGM_ARENA_PATH: String = "res://assets/audio/Stage Music.ogg"
const UI_CLICK_SFX_PATH: String = "res://assets/audio/reload_shotgun.ogg"

var _bgm_player: AudioStreamPlayer
var _bgm_track_key: String = ""
var _bgm_tween: Tween = null
var _bgm_target_db: float = -6.0
var _ui_click_player: AudioStreamPlayer
var _last_ui_click_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reset_default_touch_layout(false)
	_ensure_audio_buses()
	load_settings()
	_apply_audio_settings()
	_apply_graphics_settings()
	_setup_bgm()
	_setup_ui_click_sfx()


func _exit_tree() -> void:
	if is_instance_valid(_bgm_tween):
		_bgm_tween.kill()
		_bgm_tween = null
	if is_instance_valid(_bgm_player) and _bgm_player.playing:
		_bgm_player.stop()
		_bgm_player.stream = null
	if is_instance_valid(_ui_click_player):
		_ui_click_player.stop()
		_ui_click_player.stream = null


static func get_builtin_default_ui_layout() -> Dictionary:
	return {
		"left_stick": {"x": 0.12, "y": 0.76, "scale": 1.0, "rot": 0.0},
		"right_stick": {"x": 0.88, "y": 0.76, "scale": 1.0, "rot": 0.0},
		"btn_reload": {"x": 0.75, "y": 0.85, "scale": 1.0, "rot": 0.0},
		"btn_switch": {"x": 0.76, "y": 0.66, "scale": 1.0, "rot": 0.0},
		"btn_bomb": {"x": 0.90, "y": 0.50, "scale": 1.0, "rot": 0.0},
		"btn_shoe": {"x": 0.042, "y": 0.189, "scale": 1.0, "rot": 0.0},
		"btn_zoom": {"x": 0.045, "y": 0.065, "scale": 1.0, "rot": 0.0},
		"btn_presets": {"x": 0.105, "y": 0.065, "scale": 1.0, "rot": 0.0},
		"btn_pickup": {"x": 0.88, "y": 0.558, "scale": 1.0, "rot": 0.0},
		"btn_interact": {"x": 0.68, "y": 0.85, "scale": 1.0, "rot": 0.0},
		"btn_throw_prop": {"x": 0.045, "y": 0.325, "scale": 1.0, "rot": 0.0},
		"ability_0": {"x": 0.36, "y": 0.86, "scale": 1.0, "rot": 0.0},
		"ability_1": {"x": 0.45, "y": 0.86, "scale": 1.0, "rot": 0.0},
		"ability_2": {"x": 0.54, "y": 0.86, "scale": 1.0, "rot": 0.0},
		"ability_3": {"x": 0.63, "y": 0.86, "scale": 1.0, "rot": 0.0},
		"top_bar_hud": {"x": 0.50, "y": 0.055, "scale": 1.0, "rot": 0.0},
	}


static func load_default_ui_layout_dict() -> Dictionary:
	var out: Dictionary = get_builtin_default_ui_layout()
	var layout_paths: Array[String] = [DEFAULT_UI_LAYOUT_PATH]
	if OS.has_feature("editor"):
		layout_paths.append(USER_DEFAULT_UI_LAYOUT_PATH)
	for path in layout_paths:
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				var d := parsed as Dictionary
				var elems: Variant = d.get("elements", d)
				if elems is Dictionary:
					for k in (elems as Dictionary):
						var v: Variant = (elems as Dictionary)[k]
						if v is Dictionary:
							var vd := v as Dictionary
							out[k] = {
								"x": clampf(float(vd.get("x", 0.5)), 0.02, 0.98),
								"y": clampf(float(vd.get("y", 0.5)), 0.02, 0.98),
								"scale": clampf(float(vd.get("scale", 1.0)), 0.35, 2.5),
								"rot": clampf(float(vd.get("rot", 0.0)), -180.0, 180.0),
							}
	return out


func _reset_default_touch_layout(emit_save: bool = true) -> void:
	var def_map: Dictionary = load_default_ui_layout_dict()
	touch_layout.clear()
	touch_layout_transforms.clear()
	for k in def_map.keys():
		var item: Dictionary = def_map[k]
		touch_layout[k] = Vector2(float(item["x"]), float(item["y"]))
		touch_layout_transforms[k] = {
			"scale": float(item.get("scale", 1.0)),
			"rot": float(item.get("rot", 0.0)),
		}
	touch_layout_version = 6
	if emit_save:
		save_settings()
		touch_layout_changed.emit()


func reset_touch_layout() -> void:
	_reset_default_touch_layout(true)


func restore_touch_layout(saved_layout: Dictionary) -> void:
	touch_layout = saved_layout.duplicate(true)
	save_settings()
	touch_layout_changed.emit()


func set_touch_element_pos(key: String, norm_pos: Vector2) -> void:
	touch_layout[key] = Vector2(clampf(norm_pos.x, 0.02, 0.98), clampf(norm_pos.y, 0.02, 0.98))
	save_settings()
	touch_layout_changed.emit()


func set_touch_element_transform(key: String, norm_pos: Vector2, sc: float, rot_deg: float) -> void:
	touch_layout[key] = Vector2(clampf(norm_pos.x, 0.02, 0.98), clampf(norm_pos.y, 0.02, 0.98))
	touch_layout_transforms[key] = {
		"scale": clampf(sc, 0.35, 2.5),
		"rot": clampf(rot_deg, -180.0, 180.0),
	}
	save_settings()
	touch_layout_changed.emit()


func get_touch_element_px(key: String, viewport_size: Vector2) -> Vector2:
	var norm: Vector2 = touch_layout.get(key, Vector2(0.5, 0.5))
	return Vector2(norm.x * viewport_size.x, norm.y * viewport_size.y)


func get_touch_element_scale(key: String) -> float:
	if touch_layout_transforms.has(key):
		return clampf(float((touch_layout_transforms[key] as Dictionary).get("scale", 1.0)), 0.35, 2.5)
	return 1.0


func get_touch_element_rot(key: String) -> float:
	if touch_layout_transforms.has(key):
		return clampf(float((touch_layout_transforms[key] as Dictionary).get("rot", 0.0)), -180.0, 180.0)
	return 0.0


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("Music") == -1:
		var idx2: int = AudioServer.bus_count
		AudioServer.add_bus(idx2)
		AudioServer.set_bus_name(idx2, "Music")
		AudioServer.set_bus_send(idx2, "Master")


func _setup_bgm() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Music"
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player.volume_db = _bgm_target_db
	add_child(_bgm_player)
	call_deferred("_start_initial_bgm")


func _start_initial_bgm() -> void:
	if not is_instance_valid(_bgm_player) or _bgm_player.playing or not _bgm_track_key.is_empty():
		return
	var cur_path: String = ""
	if get_tree() != null and get_tree().current_scene != null:
		cur_path = str(get_tree().current_scene.scene_file_path)
	if cur_path.contains("PoseEditor") or cur_path.contains("SplashScreen"):
		return
	elif cur_path.contains("Arena"):
		play_bgm("arena", false)
	else:
		play_bgm("menu", false)


func _load_bgm_stream(track_key: String) -> AudioStream:
	var path: String = BGM_ARENA_PATH if track_key == "arena" else BGM_MENU_PATH
	var stream: AudioStream = (load(path) as AudioStream) if ResourceLoader.exists(path) else null
	if stream == null and path.ends_with(".ogg") and FileAccess.file_exists(path):
		stream = AudioStreamOggVorbis.load_from_file(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


func play_bgm(track_key: String, fade: bool = true) -> void:
	if not is_instance_valid(_bgm_player):
		return
	var target_path: String = BGM_ARENA_PATH if track_key == "arena" else BGM_MENU_PATH
	var target_db: float = -6.0
	if _bgm_player.stream != null and (_bgm_track_key == track_key or _bgm_player.stream.resource_path == target_path):
		_bgm_track_key = track_key
		_bgm_target_db = target_db
		if DisplayServer.get_name() != "headless" and not _bgm_player.playing:
			_bgm_player.volume_db = _bgm_target_db
			_bgm_player.play()
		return
	var stream: AudioStream = _load_bgm_stream(track_key)
	if stream == null:
		return
	_bgm_track_key = track_key
	_bgm_target_db = target_db
	if is_instance_valid(_bgm_tween):
		_bgm_tween.kill()
		_bgm_tween = null
	if DisplayServer.get_name() == "headless":
		_bgm_player.stream = stream
		_bgm_player.volume_db = _bgm_target_db
		return
	if fade and _bgm_player.playing:
		_bgm_tween = create_tween()
		_bgm_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_bgm_tween.tween_property(_bgm_player, "volume_db", -32.0, 0.25)
		_bgm_tween.tween_callback(func():
			if is_instance_valid(_bgm_player):
				_bgm_player.stream = stream
				_bgm_player.play()
		)
		_bgm_tween.tween_property(_bgm_player, "volume_db", _bgm_target_db, 0.35)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = _bgm_target_db
		_bgm_player.play()


func stop_bgm(_fade: bool = false) -> void:
	_bgm_track_key = ""
	if is_instance_valid(_bgm_tween):
		_bgm_tween.kill()
		_bgm_tween = null
	if is_instance_valid(_bgm_player) and _bgm_player.playing:
		_bgm_player.stop()


func _setup_ui_click_sfx() -> void:
	_ui_click_player = AudioStreamPlayer.new()
	_ui_click_player.name = "UIClickPlayer"
	_ui_click_player.bus = "SFX"
	_ui_click_player.max_polyphony = 4
	_ui_click_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_click_player.volume_db = -4.0
	var stream: AudioStream = (load(UI_CLICK_SFX_PATH) as AudioStream) if ResourceLoader.exists(UI_CLICK_SFX_PATH) else null
	if stream == null and FileAccess.file_exists(UI_CLICK_SFX_PATH):
		stream = AudioStreamOggVorbis.load_from_file(UI_CLICK_SFX_PATH)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	_ui_click_player.stream = stream
	add_child(_ui_click_player)


func play_ui_click() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not is_instance_valid(_ui_click_player) or _ui_click_player.stream == null:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_ui_click_msec < 65:
		return
	_last_ui_click_msec = now
	_ui_click_player.pitch_scale = randf_range(0.96, 1.04)
	_ui_click_player.play()


func _input(event: InputEvent) -> void:
	var is_touch_or_click: bool = false
	if event is InputEventScreenTouch:
		is_touch_or_click = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		is_touch_or_click = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.device != InputEvent.DEVICE_ID_EMULATION
	if not is_touch_or_click:
		return
	var tree := get_tree()
	if tree == null:
		return
	var cur_scene: Node = tree.current_scene
	if cur_scene == null:
		return
	var cur_path: String = str(cur_scene.scene_file_path)
	if cur_path.contains("PoseEditor") or cur_path.contains("SplashScreen"):
		return
	if cur_path.contains("Arena"):
		if not tree.paused and not _is_arena_ui_open(cur_scene):
			return
	play_ui_click()


func _is_arena_ui_open(arena_scene: Node) -> bool:
	var hud: Node = arena_scene.get_node_or_null("HUD")
	if hud == null:
		return false
	for prop in ["_drawer_panel", "_preset_overlay", "_layout_overlay", "_match_end_overlay", "_chat_panel"]:
		var panel: Variant = hud.get(prop)
		if panel is Control and is_instance_valid(panel) and (panel as Control).visible:
			return true
	return false


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		save_settings()
		return

	move_stick_sensitivity = clampf(float(cfg.get_value("controls", "move_stick_sensitivity", 1.0)), 0.4, 2.0)
	aim_stick_sensitivity = clampf(float(cfg.get_value("controls", "aim_stick_sensitivity", 1.0)), 0.4, 2.0)
	invert_y_axis = bool(cfg.get_value("controls", "invert_y_axis", false))
	auto_aim_assist = bool(cfg.get_value("controls", "auto_aim_assist", true))

	var saved_layout_ver: int = int(cfg.get_value("touch", "layout_version", 1))
	var migrate_touch: bool = saved_layout_ver < 5
	if not migrate_touch:
		for k in touch_layout.keys():
			var saved_v: Variant = cfg.get_value("touch_layout", k, touch_layout[k])
			if saved_v is Vector2:
				touch_layout[k] = saved_v
			var saved_sc: float = float(cfg.get_value("touch_layout_xform", "%s_scale" % k, get_touch_element_scale(k)))
			var saved_rot: float = float(cfg.get_value("touch_layout_xform", "%s_rot" % k, get_touch_element_rot(k)))
			touch_layout_transforms[k] = {
				"scale": clampf(saved_sc, 0.35, 2.5),
				"rot": clampf(saved_rot, -180.0, 180.0),
			}

	for item in REBINDABLE_ACTIONS:
		var act: String = str(item["action"])
		var def_kc: int = int(item["default"])
		var kc: int = int(cfg.get_value("keybinds", act, def_kc))
		_apply_action_keycode(act, kc)

	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 0.85)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.45)), 0.0, 1.0)
	music_enabled = bool(cfg.get_value("audio", "music_enabled", true))
	sfx_enabled = bool(cfg.get_value("audio", "sfx_enabled", true))
	master_muted = bool(cfg.get_value("audio", "master_muted", false))

	var saved_res_ver: int = int(cfg.get_value("graphics", "res_ver", 1))
	var migrate_res: bool = saved_res_ver < 2
	resolution_index = clampi(int(cfg.get_value("graphics", "resolution_index", 3)), 0, RESOLUTIONS.size() - 1)
	if migrate_res and resolution_index == 1:
		resolution_index = 3
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", false))
	vsync_enabled = bool(cfg.get_value("graphics", "vsync_enabled", true))
	fps_limit_mode = clampi(int(cfg.get_value("graphics", "fps_limit_mode", 1)), 0, FPS_VALUES.size() - 1)
	particle_intensity = clampf(float(cfg.get_value("graphics", "particle_intensity", 1.0)), 0.0, 1.5)
	screen_shake_intensity = clampf(float(cfg.get_value("graphics", "screen_shake_intensity", 1.0)), 0.0, 1.5)
	show_callsigns = bool(cfg.get_value("graphics", "show_callsigns", true))
	sight_laser = bool(cfg.get_value("graphics", "sight_laser", true))
	show_blood = bool(cfg.get_value("graphics", "show_blood", true))
	damage_display = bool(cfg.get_value("graphics", "damage_display", false))
	enhanced_visuals = bool(cfg.get_value("graphics", "enhanced_visuals", true))
	show_diagnostics = bool(cfg.get_value("graphics", "show_diagnostics", false))

	unlimited_jetpack = bool(cfg.get_value("game_rules", "unlimited_jetpack", false))
	gravity_scale = clampf(float(cfg.get_value("game_rules", "gravity_scale", 1.0)), 0.0, 1.0)
	jet_speed_scale = clampf(float(cfg.get_value("game_rules", "jet_speed_scale", 0.5)), 0.1, 1.0)
	random_guns_mode = bool(cfg.get_value("game_rules", "random_guns_mode", false))
	only_pistols = bool(cfg.get_value("game_rules", "only_pistols", false))
	allow_snipers = bool(cfg.get_value("game_rules", "allow_snipers", true))
	allow_shotguns = bool(cfg.get_value("game_rules", "allow_shotguns", true))
	allow_explosives = bool(cfg.get_value("game_rules", "allow_explosives", true))
	sync_rules_to_network()
	if migrate_touch or migrate_res:
		save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "move_stick_sensitivity", move_stick_sensitivity)
	cfg.set_value("controls", "aim_stick_sensitivity", aim_stick_sensitivity)
	cfg.set_value("controls", "invert_y_axis", invert_y_axis)
	cfg.set_value("controls", "auto_aim_assist", auto_aim_assist)

	cfg.set_value("touch", "layout_version", touch_layout_version)
	for k in touch_layout.keys():
		cfg.set_value("touch_layout", k, touch_layout[k])
		cfg.set_value("touch_layout_xform", "%s_scale" % k, get_touch_element_scale(k))
		cfg.set_value("touch_layout_xform", "%s_rot" % k, get_touch_element_rot(k))

	for item in REBINDABLE_ACTIONS:
		var act: String = str(item["action"])
		cfg.set_value("keybinds", act, get_action_keycode(act))

	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("audio", "master_muted", master_muted)

	cfg.set_value("graphics", "resolution_index", resolution_index)
	cfg.set_value("graphics", "res_ver", 2)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync_enabled", vsync_enabled)
	cfg.set_value("graphics", "fps_limit_mode", fps_limit_mode)
	cfg.set_value("graphics", "particle_intensity", particle_intensity)
	cfg.set_value("graphics", "screen_shake_intensity", screen_shake_intensity)
	cfg.set_value("graphics", "show_callsigns", show_callsigns)
	cfg.set_value("graphics", "sight_laser", sight_laser)
	cfg.set_value("graphics", "show_blood", show_blood)
	cfg.set_value("graphics", "damage_display", damage_display)
	cfg.set_value("graphics", "enhanced_visuals", enhanced_visuals)
	cfg.set_value("graphics", "show_diagnostics", show_diagnostics)

	cfg.set_value("game_rules", "unlimited_jetpack", unlimited_jetpack)
	cfg.set_value("game_rules", "gravity_scale", clampf(gravity_scale, 0.0, 1.0))
	cfg.set_value("game_rules", "jet_speed_scale", clampf(jet_speed_scale, 0.1, 1.0))
	cfg.set_value("game_rules", "random_guns_mode", random_guns_mode)
	cfg.set_value("game_rules", "only_pistols", only_pistols)
	cfg.set_value("game_rules", "allow_snipers", allow_snipers)
	cfg.set_value("game_rules", "allow_shotguns", allow_shotguns)
	cfg.set_value("game_rules", "allow_explosives", allow_explosives)

	cfg.save(SETTINGS_PATH)


func get_rules_dict() -> Dictionary:
	return {
		"unlimited_jetpack": unlimited_jetpack,
		"gravity_scale": clampf(gravity_scale, 0.0, 1.0),
		"jet_speed_scale": clampf(jet_speed_scale, 0.1, 1.0),
		"random_guns_mode": random_guns_mode,
		"only_pistols": only_pistols,
		"allow_snipers": allow_snipers,
		"allow_shotguns": allow_shotguns,
		"allow_explosives": allow_explosives
	}


func sync_rules_to_network() -> void:
	var nm := get_node_or_null("/root/NetworkManager")
	if nm != null and nm.has_method("host_update_game_rules"):
		nm.host_update_game_rules(get_rules_dict())


func apply_and_save() -> void:
	_apply_audio_settings()
	_apply_graphics_settings()
	sync_rules_to_network()
	save_settings()
	settings_changed.emit()


func _apply_audio_settings() -> void:
	var all_muted: bool = is_game_muted()
	_set_bus_linear("Master", 0.0 if all_muted else master_volume)
	_set_bus_linear("SFX", 0.0 if (all_muted or not sfx_enabled) else sfx_volume)
	_set_bus_linear("Music", 0.0 if (all_muted or not music_enabled) else music_volume)


func is_game_muted() -> bool:
	var no_music: bool = (not music_enabled) or (music_volume <= 0.005)
	var no_sfx: bool = (not sfx_enabled) or (sfx_volume <= 0.005)
	return master_muted or master_volume <= 0.005 or (no_music and no_sfx)


func toggle_master_mute() -> bool:
	if is_game_muted():
		master_muted = false
		music_enabled = true
		sfx_enabled = true
		if master_volume <= 0.005:
			master_volume = 0.85
		if sfx_volume <= 0.005:
			sfx_volume = 0.85
		if music_volume <= 0.005:
			music_volume = 0.45
		apply_and_save()
		if DisplayServer.get_name() != "headless" and is_instance_valid(_bgm_player) and _bgm_player.stream != null and not _bgm_player.playing and not _bgm_track_key.is_empty():
			_bgm_player.volume_db = _bgm_target_db
			_bgm_player.play()
		return false
	master_muted = true
	music_enabled = false
	sfx_enabled = false
	apply_and_save()
	return true


func _set_bus_linear(bus_name: String, linear_val: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear_val <= 0.005:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, -60.0)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val))


func _apply_graphics_settings() -> void:
	Engine.max_fps = FPS_VALUES[clampi(fps_limit_mode, 0, FPS_VALUES.size() - 1)]

	if DisplayServer.get_name() == "headless":
		return

	if OS.has_feature("mobile") or OS.get_name() == "Android":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res: Vector2i = RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
		DisplayServer.window_set_size(res)

	var vsync_mode := DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)


func _apply_action_keycode(action_name: String, physical_kc: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var old_events := InputMap.action_get_events(action_name)
	for ev in old_events:
		if ev is InputEventKey:
			InputMap.action_erase_event(action_name, ev)
	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = physical_kc as Key
	InputMap.action_add_event(action_name, new_ev)


func set_keybind(action_name: String, physical_kc: int) -> void:
	_apply_action_keycode(action_name, physical_kc)
	save_settings()
	settings_changed.emit()


func get_action_keycode(action_name: String) -> int:
	if InputMap.has_action(action_name):
		for ev in InputMap.action_get_events(action_name):
			if ev is InputEventKey:
				var kev := ev as InputEventKey
				return int(kev.physical_keycode if kev.physical_keycode != KEY_NONE else kev.keycode)
	for item in REBINDABLE_ACTIONS:
		if str(item["action"]) == action_name:
			return int(item["default"])
	return KEY_NONE


func get_action_key_label(action_name: String) -> String:
	var kc: int = get_action_keycode(action_name)
	return OS.get_keycode_string(kc as Key)
