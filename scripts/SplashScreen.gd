extends Control

const SPLASH_VIDEO_PATH: String = "res://assets/splash_video.ogv"
const SPLASH_AUDIO_PATH: String = "res://assets/audio/Splash Audio.ogg"
const MAIN_MENU_PATH: String = "res://scenes/MainMenu.tscn"
const BG_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const DEFAULT_VIDEO_SIZE: Vector2 = Vector2(1280.0, 720.0)
const MAX_VIDEO_SEC: float = 8.0

var _overlay: Control
var _hold_tex: TextureRect
var _video_player: VideoStreamPlayer
var _audio_player: AudioStreamPlayer
var _has_video: bool = false
var _video_done: bool = false
var _video_size_synced: bool = false
var _loaded_menu_scene: PackedScene = null
var _menu_load_done: bool = false
var _elapsed: float = 0.0
var _frames_rendered: int = 0
var _menu_added: bool = false
var _menu_frames: int = 0
var _skip_requested: bool = false
var _fading_out: bool = false
var _threaded_load_started: bool = false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.clip_contents = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(bg)

	_hold_tex = TextureRect.new()
	_hold_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hold_tex.visible = false
	_hold_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hold_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hold_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_hold_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_hold_tex)

	_video_player = VideoStreamPlayer.new()
	_video_player.expand = true
	_video_player.loop = false
	_video_player.autoplay = false
	_video_player.bus = "Master"
	_video_player.volume_db = -80.0
	_video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_video_player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_overlay.add_child(_video_player)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "SplashAudioPlayer"
	_audio_player.bus = "Master"
	_audio_player.volume_db = 0.0
	_audio_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_audio_player)

	_overlay.resized.connect(_fit_video_to_viewport)
	_fit_video_to_viewport()
	call_deferred("_fit_video_to_viewport")

	if DisplayServer.get_name() == "headless":
		set_process(false)
		return

	var video_stream: VideoStream = _load_splash_video()
	if video_stream != null:
		_video_player.stream = video_stream
		_video_player.finished.connect(_on_video_finished)
		_video_player.play()
		_has_video = true
		var audio_stream: AudioStream = _load_splash_audio()
		if audio_stream != null:
			_audio_player.stream = audio_stream
			_audio_player.play()
	else:
		_video_player.visible = false
		_video_done = true

	_threaded_load_started = (ResourceLoader.load_threaded_request(MAIN_MENU_PATH, "PackedScene") == OK)
	set_process(true)


func _exit_tree() -> void:
	if is_instance_valid(_audio_player):
		_audio_player.stop()
		_audio_player.stream = null
	if is_instance_valid(_video_player):
		_video_player.stop()
		_video_player.stream = null


func _fit_video_to_viewport() -> void:
	if not is_instance_valid(_overlay) or not is_instance_valid(_video_player):
		return
	var vp_size: Vector2 = _overlay.size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = get_viewport_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return
	var vid_size: Vector2 = DEFAULT_VIDEO_SIZE
	var tex: Texture2D = _video_player.get_video_texture()
	if tex != null:
		var t_size: Vector2 = tex.get_size()
		if t_size.x > 1.0 and t_size.y > 1.0:
			vid_size = t_size
	var sc: float = minf(vp_size.x / vid_size.x, vp_size.y / vid_size.y)
	var target: Vector2 = vid_size * sc
	_video_player.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_video_player.size = target
	_video_player.position = (vp_size - target) * 0.5


func _process(delta: float) -> void:
	_elapsed += delta
	_frames_rendered += 1

	if _threaded_load_started and not _menu_load_done:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(MAIN_MENU_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded_menu_scene = ResourceLoader.load_threaded_get(MAIN_MENU_PATH) as PackedScene
			_menu_load_done = true
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_menu_load_done = true

	if _has_video and not _video_done:
		if not _video_size_synced and is_instance_valid(_video_player):
			var tex: Texture2D = _video_player.get_video_texture()
			if tex != null and tex.get_size().x > 1.0 and tex.get_size().y > 1.0:
				_video_size_synced = true
				_fit_video_to_viewport()
		if _skip_requested or _elapsed >= MAX_VIDEO_SEC or (_frames_rendered > 5 and not _video_player.is_playing()):
			_finish_video()
		if not _video_done:
			return

	if not _menu_added:
		if not _has_video and _frames_rendered < 2:
			return
		if _threaded_load_started and not _menu_load_done:
			return
		var packed: PackedScene = _loaded_menu_scene if _loaded_menu_scene != null else (load(MAIN_MENU_PATH) as PackedScene)
		_attach_main_menu(packed)
		return

	_menu_frames += 1
	if not _fading_out and _menu_frames >= 1:
		_start_reveal_fade()


func _on_video_finished() -> void:
	_finish_video()


func _finish_video() -> void:
	if _video_done:
		return
	_video_done = true
	if is_instance_valid(_video_player):
		var tex: Texture2D = _video_player.get_video_texture()
		if tex != null:
			var img: Image = tex.get_image()
			if img != null and not img.is_empty():
				var w: int = img.get_width()
				var h: int = img.get_height()
				var has_visible_frame: bool = false
				for gx in [0.25, 0.5, 0.75]:
					for gy in [0.25, 0.5, 0.75]:
						var px: Color = img.get_pixel(int(float(w) * gx), int(float(h) * gy))
						if px.a > 0.5 and (px.r + px.g + px.b) > 0.08:
							has_visible_frame = true
							break
					if has_visible_frame:
						break
				if has_visible_frame and is_instance_valid(_hold_tex):
					_hold_tex.texture = ImageTexture.create_from_image(img)
					_hold_tex.visible = true
		if _video_player.is_playing():
			_video_player.stop()
		_video_player.visible = false
	if _skip_requested and is_instance_valid(_audio_player) and _audio_player.playing:
		_audio_player.stop()


func _attach_main_menu(packed: PackedScene) -> void:
	_menu_added = true
	var tree := get_tree()
	if tree == null:
		return
	if packed == null:
		tree.change_scene_to_file(MAIN_MENU_PATH)
		return
	var menu := packed.instantiate()
	if menu == null or tree.root == null:
		tree.change_scene_to_file(MAIN_MENU_PATH)
		return
	tree.root.add_child(menu)
	tree.current_scene = menu


func _start_reveal_fade() -> void:
	if _fading_out:
		return
	_fading_out = true
	if is_instance_valid(_overlay):
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var reveal_sec: float = 0.15 if _skip_requested else 0.25
		var tw := create_tween()
		tw.tween_property(_overlay, "modulate:a", 0.0, reveal_sec)
		if is_instance_valid(_audio_player) and _audio_player.playing:
			tw.parallel().tween_property(_audio_player, "volume_db", -40.0, reveal_sec)
		tw.finished.connect(queue_free)
	else:
		if is_instance_valid(_audio_player) and _audio_player.playing:
			_audio_player.stop()
		queue_free()


func _load_splash_video() -> VideoStream:
	if ResourceLoader.exists(SPLASH_VIDEO_PATH):
		var stream := load(SPLASH_VIDEO_PATH) as VideoStream
		if stream != null:
			return stream
	if FileAccess.file_exists(SPLASH_VIDEO_PATH):
		var theo := VideoStreamTheora.new()
		theo.file = SPLASH_VIDEO_PATH
		return theo
	return null


func _load_splash_audio() -> AudioStream:
	var stream: AudioStream = (load(SPLASH_AUDIO_PATH) as AudioStream) if ResourceLoader.exists(SPLASH_AUDIO_PATH) else null
	if stream == null and FileAccess.file_exists(SPLASH_AUDIO_PATH):
		stream = AudioStreamOggVorbis.load_from_file(SPLASH_AUDIO_PATH)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	return stream


func _input(event: InputEvent) -> void:
	if _fading_out:
		return
	if (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventKey and (event as InputEventKey).pressed):
		_skip_requested = true
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		if _has_video and not _video_done:
			_finish_video()
		elif _menu_added and _menu_frames >= 2:
			_start_reveal_fade()
