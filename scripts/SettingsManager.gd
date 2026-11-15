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
	{"action": "toggle_dual_wield", "label": "Toggle Dual-Wield", "default": KEY_E},
	{"action": "open_lobby", "label": "Open LAN Lobby", "default": KEY_L}
]

# Controls & Input
var move_stick_sensitivity: float = 1.0
var aim_stick_sensitivity: float = 1.0
var invert_y_axis: bool = false
var auto_aim_assist: bool = true

var touch_layout: Dictionary = {}

# Audio
var master_volume: float = 0.85
var sfx_volume: float = 0.85
var music_volume: float = 0.45

# Graphics & Performance
var resolution_index: int = 1
var fullscreen: bool = false
var vsync_enabled: bool = true
var fps_limit_mode: int = 1
var particle_intensity: float = 1.0
var screen_shake_intensity: float = 1.0

var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	_reset_default_touch_layout(false)
	_ensure_audio_buses()
	load_settings()
	_apply_audio_settings()
	_apply_graphics_settings()
	_setup_bgm()


func _exit_tree() -> void:
	if is_instance_valid(_bgm_player) and _bgm_player.playing:
		_bgm_player.stop()
		_bgm_player.stream = null


func _reset_default_touch_layout(emit_save: bool = true) -> void:
	touch_layout = {
		"left_stick": Vector2(0.10, 0.82),
		"right_stick": Vector2(0.90, 0.82),
		"btn_reload": Vector2(0.76, 0.86),
		"btn_switch": Vector2(0.76, 0.74),
		"btn_dual": Vector2(0.24, 0.86)
	}
	if emit_save:
		save_settings()
		touch_layout_changed.emit()


func reset_touch_layout() -> void:
	_reset_default_touch_layout(true)


func set_touch_element_pos(key: String, norm_pos: Vector2) -> void:
	touch_layout[key] = Vector2(clampf(norm_pos.x, 0.05, 0.95), clampf(norm_pos.y, 0.12, 0.94))
	save_settings()
	touch_layout_changed.emit()


func get_touch_element_px(key: String, viewport_size: Vector2) -> Vector2:
	var norm: Vector2 = touch_layout.get(key, Vector2(0.5, 0.5))
	return Vector2(norm.x * viewport_size.x, norm.y * viewport_size.y)


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
	var stream: AudioStream = load("res://assets/audio/bgm_loop.wav") as AudioStream
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_bgm_player.stream = stream
	_bgm_player.volume_db = -4.0
	add_child(_bgm_player)
	if DisplayServer.get_name() != "headless" and stream != null:
		_bgm_player.play()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		save_settings()
		return

	move_stick_sensitivity = clampf(float(cfg.get_value("controls", "move_stick_sensitivity", 1.0)), 0.4, 2.0)
	aim_stick_sensitivity = clampf(float(cfg.get_value("controls", "aim_stick_sensitivity", 1.0)), 0.4, 2.0)
	invert_y_axis = bool(cfg.get_value("controls", "invert_y_axis", false))
	auto_aim_assist = bool(cfg.get_value("controls", "auto_aim_assist", true))

	for k in touch_layout.keys():
		var saved_v: Variant = cfg.get_value("touch_layout", k, touch_layout[k])
		if saved_v is Vector2:
			touch_layout[k] = saved_v

	for item in REBINDABLE_ACTIONS:
		var act: String = str(item["action"])
		var def_kc: int = int(item["default"])
		var kc: int = int(cfg.get_value("keybinds", act, def_kc))
		_apply_action_keycode(act, kc)

	master_volume = clampf(float(cfg.get_value("audio", "master_volume", 0.85)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", 0.85)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", 0.45)), 0.0, 1.0)

	resolution_index = clampi(int(cfg.get_value("graphics", "resolution_index", 1)), 0, RESOLUTIONS.size() - 1)
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", false))
	vsync_enabled = bool(cfg.get_value("graphics", "vsync_enabled", true))
	fps_limit_mode = clampi(int(cfg.get_value("graphics", "fps_limit_mode", 1)), 0, FPS_VALUES.size() - 1)
	particle_intensity = clampf(float(cfg.get_value("graphics", "particle_intensity", 1.0)), 0.0, 1.5)
	screen_shake_intensity = clampf(float(cfg.get_value("graphics", "screen_shake_intensity", 1.0)), 0.0, 1.5)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "move_stick_sensitivity", move_stick_sensitivity)
	cfg.set_value("controls", "aim_stick_sensitivity", aim_stick_sensitivity)
	cfg.set_value("controls", "invert_y_axis", invert_y_axis)
	cfg.set_value("controls", "auto_aim_assist", auto_aim_assist)

	for k in touch_layout.keys():
		cfg.set_value("touch_layout", k, touch_layout[k])

	for item in REBINDABLE_ACTIONS:
		var act: String = str(item["action"])
		cfg.set_value("keybinds", act, get_action_keycode(act))

	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)

	cfg.set_value("graphics", "resolution_index", resolution_index)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("graphics", "vsync_enabled", vsync_enabled)
	cfg.set_value("graphics", "fps_limit_mode", fps_limit_mode)
	cfg.set_value("graphics", "particle_intensity", particle_intensity)
	cfg.set_value("graphics", "screen_shake_intensity", screen_shake_intensity)

	cfg.save(SETTINGS_PATH)


func apply_and_save() -> void:
	_apply_audio_settings()
	_apply_graphics_settings()
	save_settings()
	settings_changed.emit()


func _apply_audio_settings() -> void:
	_set_bus_linear("Master", master_volume)
	_set_bus_linear("SFX", sfx_volume)
	_set_bus_linear("Music", music_volume)


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
