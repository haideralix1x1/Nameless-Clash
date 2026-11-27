extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const TEX_BG_BUNKER: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const TEX_BG_FACTORY: Texture2D = preload("res://assets/tilemaps/factory_bg.png")
const TEX_BG_DESERT: Texture2D = preload("res://assets/tilemaps/desert_bg.png")
const TEX_TILES: Texture2D = preload("res://assets/tilemaps/bunker_tileset.png")
const TEX_CRATE: Texture2D = preload("res://assets/sprites/weapon_crate.png")
const FLOOR_BOMB_TYPES: Array[String] = ["frag", "sticky", "time", "mine", "cluster"]
const MATCH_START_SFX_PATH: String = "res://assets/audio/reload_shotgun.ogg"

const DEFAULT_ARENA_WIDTH: float = 2240.0
const DEFAULT_ARENA_HEIGHT: float = 1248.0
const DOUBLE_MAP_IDS: Array[int] = [3, 5, 7, 11, 12]

var arena_width: float = DEFAULT_ARENA_WIDTH
var arena_height: float = DEFAULT_ARENA_HEIGHT

var _spawn_points: Array[Vector2] = [
	Vector2(220.0, 1020.0),
	Vector2(2020.0, 1020.0),
	Vector2(480.0, 350.0),
	Vector2(1760.0, 350.0),
	Vector2(1120.0, 230.0),
	Vector2(1120.0, 660.0)
]

var _crate_nodes: Array[Dictionary] = []
var _static_platform_rects: Array[Rect2] = []
var _interactables: Array[Node2D] = []
var _ult_pickups: Array[Node2D] = []
var _mine_mgr: Node2D = null
var _bot_counter: int = 0
var _tile_textures: Array[Texture2D] = []
var _scenery_movers: Array[Dictionary] = []
var _shooting_targets: Array[Node2D] = []
var _shooting_hits: int = 0
var _shooting_score: int = 0
var _shooting_hud_lbl: Label = null

@onready var _world_geometry: Node2D = $WorldGeometry
@onready var _pickups_container: Node2D = $Pickups
@onready var _players_container: Node2D = $Players
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	SettingsManager.play_bgm("arena")
	_play_match_start_sfx()
	NetworkManager.ensure_offline_player()
	if NetworkManager.selected_map_id in DOUBLE_MAP_IDS:
		arena_width = DEFAULT_ARENA_WIDTH * 2.0
		arena_height = DEFAULT_ARENA_HEIGHT * 2.0
	else:
		arena_width = DEFAULT_ARENA_WIDTH
		arena_height = DEFAULT_ARENA_HEIGHT
	_prepare_tile_textures()
	_build_map_background()
	_build_map_scenery()
	_build_map_geometry()
	_build_interactables()
	_build_pickup_crates()
	_spawn_all_participants()
	NetworkManager.reset_match_state()
	_hud.add_bot_requested.connect(_on_add_bot_requested)
	_hud.remove_bot_requested.connect(_on_remove_bot_requested)
	_hud.pickup_weapon_requested.connect(_on_pickup_weapon_requested)
	_hud.interact_requested.connect(_on_interact_requested)
	NetworkManager.interactable_toggled.connect(_on_interactable_toggled)
	NetworkManager.barrel_detonated.connect(_on_barrel_detonated)
	NetworkManager.crate_consumed.connect(_on_crate_consumed)
	NetworkManager.ult_pickup_relocated.connect(_on_ult_pickup_relocated)
	NetworkManager.mine_event.connect(_on_mine_event)
	NetworkManager.player_list_updated.connect(_on_network_players_updated)


func _play_match_start_sfx() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = (load(MATCH_START_SFX_PATH) as AudioStream) if ResourceLoader.exists(MATCH_START_SFX_PATH) else null
	if stream == null and FileAccess.file_exists(MATCH_START_SFX_PATH):
		stream = AudioStreamOggVorbis.load_from_file(MATCH_START_SFX_PATH)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = &"SFX"
	sfx.volume_db = 0.0
	sfx.finished.connect(sfx.queue_free)
	add_child(sfx)
	sfx.play()


func _unhandled_input(event: InputEvent) -> void:
	var tap_pos: Vector2 = Vector2.ZERO
	var is_tap: bool = false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tap_pos = (event as InputEventScreenTouch).position
		is_tap = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).device != InputEvent.DEVICE_ID_EMULATION:
		tap_pos = (event as InputEventMouseButton).position
		is_tap = true
	if not is_tap or get_tree().paused:
		return
	var local_p: Node2D = null
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and p.get("is_local_human") == true and p.has_method("is_alive") and p.is_alive():
			local_p = p as Node2D
			break
	if local_p == null:
		return
	var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * tap_pos
	if float(local_p.get("touch_teleport_timer")) > 0.0 and local_p.has_method("execute_touch_teleport"):
		local_p.execute_touch_teleport(world_pos)
		get_viewport().set_input_as_handled()
		return
	if float(local_p.get("touch_fire_timer")) > 0.0 and local_p.has_method("execute_touch_fire"):
		if local_p.execute_touch_fire(world_pos):
			get_viewport().set_input_as_handled()
			return
	if float(local_p.get("touch_banish_timer")) > 0.0 and local_p.has_method("execute_touch_banish"):
		if local_p.execute_touch_banish(world_pos):
			get_viewport().set_input_as_handled()
			return
	for i in range(_interactables.size()):
		var node: Node2D = _interactables[i]
		if not is_instance_valid(node) or node is InteractableProp:
			continue
		var inter_pos: Vector2 = node.global_position
		if "btn_pos" in node:
			inter_pos = node.global_position + (node.get("btn_pos") as Vector2)
		elif "button_pos" in node:
			inter_pos = node.global_position + (node.get("button_pos") as Vector2)
		var is_remote_button: bool = (node is InteractableFan or node is InteractableMissileLauncher or node is InteractableDoor or node is InteractableSpikeTrap or node is InteractableSwitchHazard)
		if world_pos.distance_to(inter_pos) <= 78.0 and (is_remote_button or local_p.global_position.distance_to(inter_pos) <= 135.0):
			_on_interact_requested(i)
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	NetworkManager.tick_match_timer(delta)
	var t: float = Time.get_ticks_msec() / 1000.0
	for m in _scenery_movers:
		var nd: Node2D = m["node"] as Node2D
		if not is_instance_valid(nd):
			continue
		nd.position += (m["vel"] as Vector2) * delta
		nd.rotation += float(m["spin"]) * delta
		if nd.position.x > arena_width + 90.0:
			nd.position.x = -90.0
		elif nd.position.x < -90.0:
			nd.position.x = arena_width + 90.0
		if nd.position.y > arena_height + 90.0:
			nd.position.y = -90.0
		elif nd.position.y < -90.0:
			nd.position.y = arena_height + 90.0
	for c in _crate_nodes:
		var area: Area2D = c["area"] as Area2D
		if not is_instance_valid(area):
			continue
		if not bool(c["active"]):
			if bool(c.get("one_shot", false)):
				continue
			c["timer"] = float(c["timer"]) - delta
			if float(c["timer"]) <= 0.0:
				var blocked_by_player: bool = false
				if str(c.get("type", "")) == "weapon":
					for p in get_tree().get_nodes_in_group("players"):
						if is_instance_valid(p) and (not p.has_method("is_alive") or p.is_alive()):
							if (p as Node2D).global_position.distance_to(area.global_position) < 85.0:
								blocked_by_player = true
								break
				if blocked_by_player:
					c["timer"] = 0.5
				else:
					c["active"] = true
					area.visible = true
					area.monitoring = true
					area.modulate.a = 1.0
					if str(c.get("type", "")) == "weapon" and not bool(c.get("one_shot", false)):
						c["life_timer"] = 15.0
		else:
			if c.has("despawn_timer"):
				var dt: float = float(c["despawn_timer"]) - delta
				c["despawn_timer"] = dt
				if dt <= 1.0:
					area.modulate.a = clampf(dt, 0.0, 1.0)
				if dt <= 0.0:
					c["active"] = false
					c["timer"] = 9999999.0
					area.visible = false
					area.monitoring = false
					continue
			elif c.has("life_timer"):
				var lt: float = float(c["life_timer"]) - delta
				c["life_timer"] = lt
				if lt <= 5.0 and lt > 0.0:
					var blink_a: float = 0.25 if (int(floor(lt * 8.0)) % 2 == 0) else 1.0
					if lt <= 1.0:
						blink_a *= clampf(lt, 0.0, 1.0)
					area.modulate.a = blink_a
				elif lt > 5.0:
					area.modulate.a = 1.0
				if lt <= 0.0:
					c["active"] = false
					c["timer"] = 9.0
					area.visible = false
					area.monitoring = false
					area.modulate.a = 1.0
					var allowed_ws: Array[int] = WeaponData.get_pickup_weapon_ids()
					var next_w: int = allowed_ws[randi() % allowed_ws.size()]
					c["val"] = next_w
					var w_spr := c["sprite"] as Sprite2D
					if w_spr != null:
						_apply_pickup_weapon_sprite(w_spr, next_w)
					continue
			var visual_node: Node2D = c["sprite"] as Node2D
			if is_instance_valid(visual_node):
				visual_node.position.y = 0.0
	if NetworkManager.is_shooting_range_mode():
		_tick_shooting_range(delta)


func _get_map_theme(map_id: int) -> int:
	match map_id:
		1, 4, 8, 11:
			return 1
		2, 3, 6, 9:
			return 2
		_:
			return 0


func _load_tex_safe(res_path: String) -> Texture2D:
	if ResourceLoader.exists(res_path):
		var res := load(res_path) as Texture2D
		if res != null:
			return res
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(res_path)) == OK:
		return ImageTexture.create_from_image(img)
	return null


func _prepare_tile_textures() -> void:
	var map_id: int = NetworkManager.selected_map_id
	var src_img: Image = null
	var row_y: int = 0
	if map_id >= 3 and map_id <= 12:
		var t_tex := _load_tex_safe("res://assets/tilemaps/tiles_map_%d.png" % map_id)
		if t_tex != null:
			src_img = t_tex.get_image()
	else:
		row_y = clampi(map_id, 0, 2) * 32
		src_img = TEX_TILES.get_image()
	_tile_textures.clear()
	for idx in range(4):
		if src_img != null:
			var sub_img: Image = src_img.get_region(Rect2i(idx * 32, row_y, 32, 32))
			_tile_textures.append(ImageTexture.create_from_image(sub_img))
		else:
			_tile_textures.append(TEX_TILES)


func _build_map_background() -> void:
	var bg_sprite := Sprite2D.new()
	bg_sprite.name = "ArenaBackground"
	var map_id: int = NetworkManager.selected_map_id
	var custom_bg := _load_tex_safe("res://assets/tilemaps/bg_map_%d.png" % map_id)
	bg_sprite.texture = custom_bg if custom_bg != null else TEX_BG_BUNKER
	bg_sprite.centered = false
	bg_sprite.region_enabled = true
	bg_sprite.region_rect = Rect2(0, 0, arena_width, arena_height)
	bg_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg_sprite.z_index = -10
	_world_geometry.add_child(bg_sprite)


func _build_map_scenery() -> void:
	_scenery_movers.clear()
	var map_id: int = NetworkManager.selected_map_id
	if map_id == 11:
		# Lunar Station: ringed planet, moons, and roaming asteroid stones
		var p1 := MapSceneryProp.new()
		p1.kind = "planet_ringed"
		p1.position = Vector2(540, 280)
		p1.z_index = -6
		_world_geometry.add_child(p1)
		var p2 := MapSceneryProp.new()
		p2.kind = "planet_red"
		p2.position = Vector2(1740, 340)
		p2.z_index = -6
		_world_geometry.add_child(p2)
		for i in range(12):
			var ast := MapSceneryProp.new()
			ast.kind = "asteroid"
			ast.position = Vector2(randf_range(120, arena_width - 120), randf_range(120, arena_height - 120))
			ast.scale = Vector2.ONE * randf_range(0.65, 1.45)
			ast.z_index = -5
			_world_geometry.add_child(ast)
			_scenery_movers.append({"node": ast, "vel": Vector2(randf_range(-28, 28), randf_range(-16, 16)), "spin": randf_range(-0.6, 0.6)})
	elif map_id in [5, 12]:
		# Jungle Cliff & Soarin Islands: palm trees, bushes & drifting clouds
		var tree_spots: Array = [Vector2(520, 840), Vector2(3840, 840), Vector2(2240, 1720), Vector2(800, 1840)] if map_id == 12 else [Vector2(560, 1880), Vector2(3880, 1880), Vector2(1120, 1040), Vector2(3320, 1040)]
		for tp in tree_spots:
			var tree := MapSceneryProp.new()
			tree.kind = "palm_tree"
			tree.position = tp
			tree.z_index = -4
			_world_geometry.add_child(tree)
		if map_id == 5:
			for i in range(10):
				var cl := MapSceneryProp.new()
				cl.kind = "cloud"
				cl.position = Vector2(randf_range(150, arena_width - 150), randf_range(140, arena_height * 0.55))
				cl.z_index = -7
				_world_geometry.add_child(cl)
				_scenery_movers.append({"node": cl, "vel": Vector2(randf_range(12, 26), 0.0), "spin": 0.0})
	elif map_id == 7:
		# Snow Blind: snowy pines + falling snowflakes
		for tp in [Vector2(600, 960), Vector2(3840, 960), Vector2(1240, 1680), Vector2(3240, 1680)]:
			var pine := MapSceneryProp.new()
			pine.kind = "snow_pine"
			pine.position = tp
			pine.z_index = -4
			_world_geometry.add_child(pine)
		for i in range(36):
			var flk := MapSceneryProp.new()
			flk.kind = "snowflake"
			flk.position = Vector2(randf_range(60, arena_width - 60), randf_range(60, arena_height - 60))
			flk.z_index = -3
			_world_geometry.add_child(flk)
			_scenery_movers.append({"node": flk, "vel": Vector2(randf_range(-10, 14), randf_range(28, 52)), "spin": 0.4})
	elif map_id in [3, 6]:
		# Catacombs & Pharaoh Pyramid: glowing wall torches
		var sc: float = 2.0 if map_id == 3 else 1.0
		for tp in [Vector2(420, 420), Vector2(1820, 420), Vector2(1120, 520), Vector2(420, 900), Vector2(1820, 900)]:
			var torch := MapSceneryProp.new()
			torch.kind = "torch"
			torch.position = tp * sc
			torch.z_index = -4
			_world_geometry.add_child(torch)


func _build_map_geometry() -> void:
	# Shared Outer Perimeter
	_add_platform(Rect2(0, 0, arena_width, 48), 0)
	_add_platform(Rect2(0, arena_height - 64, arena_width, 64), 1)
	_add_platform(Rect2(0, 48, 48, arena_height - 112), 0)
	_add_platform(Rect2(arena_width - 48, 48, 48, arena_height - 112), 0)

	match NetworkManager.selected_map_id:
		1:
			# Map 1: Factory Ruins (tall industrial smokestacks + catwalks + smelter deck)
			_spawn_points = [
				Vector2(200, 1060), Vector2(2040, 1060),
				Vector2(420, 490), Vector2(1820, 490),
				Vector2(1120, 250), Vector2(1120, 810)
			]
			_add_platform(Rect2(140, 910, 280, 32), 2)
			_add_platform(Rect2(1820, 910, 280, 32), 2)
			_add_platform(Rect2(620, 680, 72, 504), 0)   # Left smokestack tower
			_add_platform(Rect2(1548, 680, 72, 504), 0)  # Right smokestack tower
			_add_platform(Rect2(840, 890, 560, 40), 1)   # Smelter deck
			_add_platform(Rect2(240, 560, 380, 34), 1)   # West catwalk
			_add_platform(Rect2(1620, 560, 380, 34), 1)  # East catwalk
			_add_platform(Rect2(860, 340, 520, 34), 2)   # Overhead crane bridge
			_add_platform(Rect2(960, 560, 320, 32), 3)   # Center platform
			_add_swinging_platform(Vector2(610, 48), 290.0, Vector2(180, 26), 0.34, 1.35, 0.0, true, 1)
			_add_swinging_platform(Vector2(1630, 48), 290.0, Vector2(180, 26), 0.34, 1.35, 1.8, true, 1)
		2:
			# Map 2: Desert Outpost (twin sandstone watchtowers + canyon bridge)
			_spawn_points = [
				Vector2(240, 1060), Vector2(2000, 1060),
				Vector2(360, 370), Vector2(1880, 370),
				Vector2(1120, 420), Vector2(1120, 920)
			]
			_add_platform(Rect2(280, 760, 56, 424), 0)   # West watchtower pillar
			_add_platform(Rect2(1904, 760, 56, 424), 0)  # East watchtower pillar
			_add_platform(Rect2(180, 440, 360, 36), 1)   # West turret roof
			_add_platform(Rect2(1700, 440, 360, 36), 1)  # East turret roof
			_add_platform(Rect2(440, 890, 340, 32), 2)
			_add_platform(Rect2(1460, 890, 340, 32), 2)
			_add_platform(Rect2(880, 980, 480, 48), 3)   # Canyon bunker cover
			_add_platform(Rect2(760, 510, 720, 36), 1)   # High canyon bridge
			_add_platform(Rect2(1070, 360, 100, 150), 0) # Bridge obelisk
		0:
			# Map 0: Bunker Base
			_add_platform(Rect2(120, 960, 320, 36), 1)
			_add_platform(Rect2(1800, 960, 320, 36), 1)
			_add_platform(Rect2(580, 960, 64, 224), 3)
			_add_platform(Rect2(1596, 960, 64, 224), 3)
			_add_platform(Rect2(960, 1020, 320, 48), 1)
			_add_platform(Rect2(800, 740, 640, 38), 1)
			_add_platform(Rect2(800, 635, 34, 105), 3)
			_add_platform(Rect2(1406, 635, 34, 105), 3)
			_add_platform(Rect2(340, 720, 280, 32), 2)
			_add_platform(Rect2(1620, 720, 280, 32), 2)
			_add_platform(Rect2(240, 440, 420, 34), 1)
			_add_platform(Rect2(1580, 440, 420, 34), 1)
			_add_platform(Rect2(880, 310, 480, 34), 1)
			_add_platform(Rect2(710, 210, 44, 260), 0)
			_add_platform(Rect2(1486, 210, 44, 260), 0)
			_add_swinging_platform(Vector2(480, 48), 260.0, Vector2(160, 24), 0.35, 1.4, 0.0, true, 1)
			_add_swinging_platform(Vector2(1760, 48), 260.0, Vector2(160, 24), 0.35, 1.4, 2.0, true, 1)
		3:
			# Map 3: Catacombs Maze (DOUBLE SIZE 4480x2496)
			_spawn_points = [
				Vector2(440, 1240), Vector2(4040, 1240),
				Vector2(840, 480), Vector2(3640, 480),
				Vector2(840, 2040), Vector2(3640, 2040)
			]
			_add_platform_2x(Rect2(240, 260, 720, 36), 0)
			_add_platform_2x(Rect2(1280, 260, 720, 36), 0)
			_add_platform_2x(Rect2(240, 960, 720, 36), 0)
			_add_platform_2x(Rect2(1280, 960, 720, 36), 0)
			_add_platform_2x(Rect2(440, 480, 420, 34), 1)
			_add_platform_2x(Rect2(1380, 480, 420, 34), 1)
			_add_platform_2x(Rect2(440, 740, 420, 34), 1)
			_add_platform_2x(Rect2(1380, 740, 420, 34), 1)
			_add_platform_2x(Rect2(980, 600, 280, 40), 3)
			_add_platform_2x(Rect2(820, 296, 36, 184), 2)
			_add_platform_2x(Rect2(1384, 296, 36, 184), 2)
			_add_platform_2x(Rect2(820, 774, 36, 186), 2)
			_add_platform_2x(Rect2(1384, 774, 36, 186), 2)
			_add_platform(Rect2(180, 1180, 420, 42), 1)
			_add_platform(Rect2(3880, 1180, 420, 42), 1)
			_add_platform(Rect2(1980, 560, 520, 42), 3)
			_add_platform(Rect2(1980, 1860, 520, 42), 3)
			_add_platform(Rect2(1280, 1220, 380, 40), 2)
			_add_platform(Rect2(2820, 1220, 380, 40), 2)
			_add_swinging_platform(Vector2(1120, 48), 360.0, Vector2(220, 28), 0.35, 1.35, 0.0, true, 1)
			_add_swinging_platform(Vector2(2240, 48), 640.0, Vector2(260, 30), 0.42, 1.2, 1.4, true, 3)
			_add_swinging_platform(Vector2(3360, 48), 360.0, Vector2(220, 28), 0.35, 1.35, 2.8, true, 1)
		4:
			# Map 4: Outpost Towers (3 top steel watchtowers + cavern tunnels)
			_spawn_points = [
				Vector2(220, 1040), Vector2(2020, 1040),
				Vector2(660, 360), Vector2(1580, 360),
				Vector2(1120, 260), Vector2(1120, 880)
			]
			_add_platform(Rect2(560, 420, 240, 36), 1)
			_add_platform(Rect2(1440, 420, 240, 36), 1)
			_add_platform(Rect2(980, 320, 280, 36), 1)
			_add_platform(Rect2(560, 456, 38, 220), 0)
			_add_platform(Rect2(1642, 456, 38, 220), 0)
			_add_platform(Rect2(240, 740, 440, 36), 2)
			_add_platform(Rect2(1560, 740, 440, 36), 2)
			_add_platform(Rect2(860, 660, 520, 40), 3)
			_add_platform(Rect2(740, 960, 760, 36), 1)
			# 20 extra open-access tactical cover walls & short barriers for Outpost Towers (never sealing any room)
			_add_platform(Rect2(140, 500, 160, 32), 1)
			_add_platform(Rect2(1940, 500, 160, 32), 1)
			_add_platform(Rect2(360, 860, 36, 72), 0)
			_add_platform(Rect2(1844, 860, 36, 72), 0)
			_add_platform(Rect2(580, 1110, 36, 68), 0)
			_add_platform(Rect2(1624, 1110, 36, 68), 0)
			_add_platform(Rect2(880, 1110, 36, 68), 0)
			_add_platform(Rect2(1324, 1110, 36, 68), 0)
			_add_platform(Rect2(320, 620, 36, 68), 0)
			_add_platform(Rect2(1884, 620, 36, 68), 0)
			_add_platform(Rect2(760, 520, 36, 72), 0)
			_add_platform(Rect2(1444, 520, 36, 72), 0)
			_add_platform(Rect2(900, 780, 36, 72), 0)
			_add_platform(Rect2(1304, 780, 36, 72), 0)
			_add_platform(Rect2(1010, 490, 220, 32), 2)
			_add_platform(Rect2(420, 240, 180, 32), 1)
			_add_platform(Rect2(1640, 240, 180, 32), 1)
			_add_platform(Rect2(760, 190, 36, 72), 0)
			_add_platform(Rect2(1444, 190, 36, 72), 0)
			_add_platform(Rect2(1102, 540, 36, 72), 0)
		5:
			# Map 5: Soarin Islands (DOUBLE SIZE 4480x2496)
			_spawn_points = [
				Vector2(520, 1760), Vector2(3960, 1760),
				Vector2(1120, 920), Vector2(3360, 920),
				Vector2(2240, 520), Vector2(2240, 1480)
			]
			_add_platform_2x(Rect2(140, 940, 320, 44), 2)
			_add_platform_2x(Rect2(1780, 940, 320, 44), 2)
			_add_platform_2x(Rect2(420, 520, 340, 40), 1)
			_add_platform_2x(Rect2(1480, 520, 340, 40), 1)
			_add_platform_2x(Rect2(920, 320, 400, 38), 1)
			_add_platform_2x(Rect2(880, 800, 480, 44), 3)
			_add_platform_2x(Rect2(620, 1020, 260, 34), 2)
			_add_platform_2x(Rect2(1360, 1020, 260, 34), 2)
			# Extra floating islands & sky bridges for 4480x2496 scale
			_add_platform(Rect2(240, 680, 460, 46), 2)
			_add_platform(Rect2(3780, 680, 460, 46), 2)
			_add_platform(Rect2(460, 1420, 480, 44), 1)
			_add_platform(Rect2(3540, 1420, 480, 44), 1)
			_add_platform(Rect2(1320, 1280, 380, 42), 3)
			_add_platform(Rect2(2780, 1280, 380, 42), 3)
			_add_platform(Rect2(1040, 520, 420, 40), 1)
			_add_platform(Rect2(3020, 520, 420, 40), 1)
			_add_platform(Rect2(1980, 2140, 520, 48), 2)
			_add_swinging_platform(Vector2(1400, 48), 390.0, Vector2(240, 28), 0.45, 1.25, 0.4, false, 2)
			_add_swinging_platform(Vector2(2240, 48), 960.0, Vector2(260, 30), 0.36, 1.05, 1.8, false, 1)
			_add_swinging_platform(Vector2(3080, 48), 390.0, Vector2(240, 28), 0.45, 1.25, 3.1, false, 2)
		6:
			# Map 6: Pharaoh Pyramid (stepped desert pyramid + inner chambers)
			_spawn_points = [
				Vector2(180, 1060), Vector2(2060, 1060),
				Vector2(520, 620), Vector2(1720, 620),
				Vector2(1120, 220), Vector2(1120, 880)
			]
			_add_platform(Rect2(340, 960, 1560, 40), 2)
			_add_platform(Rect2(520, 740, 1200, 38), 1)
			_add_platform(Rect2(720, 520, 800, 36), 1)
			_add_platform(Rect2(940, 300, 360, 36), 3)
			_add_platform(Rect2(1090, 556, 60, 184), 0)
			_add_platform(Rect2(680, 778, 44, 182), 0)
			_add_platform(Rect2(1516, 778, 44, 182), 0)
		7:
			# Map 7: Snow Blind (DOUBLE SIZE 4480x2496)
			_spawn_points = [
				Vector2(440, 2120), Vector2(4040, 2120),
				Vector2(720, 840), Vector2(3760, 840),
				Vector2(2240, 920), Vector2(2240, 1880)
			]
			_add_platform_2x(Rect2(160, 480, 420, 38), 1)
			_add_platform_2x(Rect2(1660, 480, 420, 38), 1)
			_add_platform_2x(Rect2(160, 320, 48, 160), 0)
			_add_platform_2x(Rect2(2032, 320, 48, 160), 0)
			_add_platform_2x(Rect2(760, 520, 720, 40), 2)
			_add_platform_2x(Rect2(440, 840, 440, 36), 3)
			_add_platform_2x(Rect2(1360, 840, 440, 36), 3)
			_add_platform_2x(Rect2(960, 1000, 320, 40), 1)
			_add_platform(Rect2(240, 1480, 480, 44), 2)
			_add_platform(Rect2(3760, 1480, 480, 44), 2)
			_add_platform(Rect2(1180, 1340, 460, 42), 1)
			_add_platform(Rect2(2840, 1340, 460, 42), 1)
			_add_platform(Rect2(1960, 560, 560, 44), 3)
			_add_platform(Rect2(1980, 1620, 520, 42), 2)
			_add_swinging_platform(Vector2(1500, 48), 540.0, Vector2(230, 28), 0.38, 1.3, 0.2, true, 1)
			_add_swinging_platform(Vector2(2980, 48), 540.0, Vector2(230, 28), 0.38, 1.3, 2.5, true, 1)
		8:
			# Map 8: Substructure (underground industrial shafts & steel walkways)
			_spawn_points = [
				Vector2(220, 1040), Vector2(2020, 1040),
				Vector2(420, 320), Vector2(1820, 320),
				Vector2(1120, 320), Vector2(1120, 820)
			]
			_add_platform(Rect2(220, 380, 560, 32), 1)
			_add_platform(Rect2(1460, 380, 560, 32), 1)
			_add_platform(Rect2(920, 380, 400, 32), 2)
			_add_platform(Rect2(740, 412, 40, 320), 0)
			_add_platform(Rect2(1460, 412, 40, 320), 0)
			_add_platform(Rect2(260, 732, 520, 34), 1)
			_add_platform(Rect2(1460, 732, 520, 34), 1)
			_add_platform(Rect2(900, 880, 440, 38), 3)
		9:
			# Map 9: High Tower (twin side fortresses + tall central spire)
			_spawn_points = [
				Vector2(220, 1040), Vector2(2020, 1040),
				Vector2(300, 360), Vector2(1940, 360),
				Vector2(1120, 220), Vector2(1120, 760)
			]
			_add_platform(Rect2(140, 420, 340, 36), 1)
			_add_platform(Rect2(1760, 420, 340, 36), 1)
			_add_platform(Rect2(440, 456, 44, 340), 0)
			_add_platform(Rect2(1756, 456, 44, 340), 0)
			_add_platform(Rect2(1070, 300, 100, 560), 0)
			_add_platform(Rect2(900, 280, 440, 34), 3)
			_add_platform(Rect2(680, 620, 280, 32), 2)
			_add_platform(Rect2(1280, 620, 280, 32), 2)
			_add_platform(Rect2(880, 960, 480, 38), 1)
		10:
			# Map 10: Ring Arena (circular outer frame + central floating hub)
			_spawn_points = [
				Vector2(260, 620), Vector2(1980, 620),
				Vector2(560, 280), Vector2(1680, 280),
				Vector2(560, 980), Vector2(1680, 980)
			]
			_add_platform(Rect2(480, 260, 1280, 36), 0)
			_add_platform(Rect2(480, 980, 1280, 36), 0)
			_add_platform(Rect2(240, 460, 38, 360), 0)
			_add_platform(Rect2(1962, 460, 38, 360), 0)
			_add_platform(Rect2(920, 600, 400, 44), 3)
			_add_platform(Rect2(560, 620, 220, 32), 2)
			_add_platform(Rect2(1460, 620, 220, 32), 2)
		11:
			# Map 11: Lunar Station (DOUBLE SIZE 4480x2496)
			_spawn_points = [
				Vector2(440, 1240), Vector2(4040, 1240),
				Vector2(2240, 440), Vector2(2240, 2040),
				Vector2(1240, 920), Vector2(3240, 1560)
			]
			_add_platform_2x(Rect2(340, 620, 1560, 36), 1)
			_add_platform_2x(Rect2(1096, 200, 48, 840), 0)
			_add_platform_2x(Rect2(580, 380, 320, 32), 2)
			_add_platform_2x(Rect2(1340, 380, 320, 32), 2)
			_add_platform_2x(Rect2(580, 860, 320, 32), 2)
			_add_platform_2x(Rect2(1340, 860, 320, 32), 2)
			_add_platform(Rect2(160, 740, 460, 42), 1)
			_add_platform(Rect2(3860, 740, 460, 42), 1)
			_add_platform(Rect2(160, 1740, 460, 42), 1)
			_add_platform(Rect2(3860, 1740, 460, 42), 1)
			_add_platform(Rect2(1940, 420, 600, 42), 3)
			_add_platform(Rect2(1940, 2060, 600, 42), 3)
			_add_swinging_platform(Vector2(1300, 48), 520.0, Vector2(240, 28), 0.34, 1.15, 0.0, true, 2)
			_add_swinging_platform(Vector2(3180, 48), 520.0, Vector2(240, 28), 0.34, 1.15, 2.2, true, 2)
		12:
			# Map 12: Jungle Cliff (DOUBLE SIZE 4480x2496)
			_spawn_points = [
				Vector2(440, 720), Vector2(4040, 720),
				Vector2(840, 1760), Vector2(3640, 1760),
				Vector2(2240, 960), Vector2(2240, 2080)
			]
			_add_platform_2x(Rect2(120, 420, 460, 44), 2)
			_add_platform_2x(Rect2(1660, 420, 460, 44), 2)
			_add_platform_2x(Rect2(540, 464, 44, 420), 0)
			_add_platform_2x(Rect2(1656, 464, 44, 420), 0)
			_add_platform_2x(Rect2(780, 540, 680, 34), 1)
			_add_platform_2x(Rect2(240, 920, 300, 36), 1)
			_add_platform_2x(Rect2(1700, 920, 300, 36), 1)
			_add_platform_2x(Rect2(880, 860, 480, 38), 3)
			_add_platform(Rect2(1260, 560, 520, 44), 2)
			_add_platform(Rect2(2700, 560, 520, 44), 2)
			_add_platform(Rect2(220, 1340, 480, 42), 1)
			_add_platform(Rect2(3780, 1340, 480, 42), 1)
			_add_platform(Rect2(1280, 1460, 480, 42), 3)
			_add_platform(Rect2(2720, 1460, 480, 42), 3)
			_add_platform(Rect2(1980, 2140, 520, 46), 1)
			_add_swinging_platform(Vector2(1500, 48), 400.0, Vector2(230, 28), 0.44, 1.3, 0.5, false, 2)
			_add_swinging_platform(Vector2(2240, 48), 640.0, Vector2(250, 30), 0.38, 1.15, 1.9, false, 3)
			_add_swinging_platform(Vector2(2980, 48), 400.0, Vector2(230, 28), 0.44, 1.3, 3.3, false, 2)


func _add_platform_2x(rect: Rect2, tile_idx: int) -> void:
	_add_platform(Rect2(rect.position * 2.0, rect.size * 2.0), tile_idx)


func _add_swinging_platform(anchor: Vector2, rope_len: float, plat_size: Vector2, amp: float, spd: float, phase: float, is_chain: bool, tile_idx: int) -> void:
	var sw := SwingingPlatform.new()
	sw.anchor_pos = anchor
	sw.rope_length = rope_len
	sw.plat_size = plat_size
	sw.swing_amp = amp
	sw.swing_speed = spd
	sw.phase = phase
	sw.is_chain = is_chain
	sw.tile_tex = _tile_textures[clampi(tile_idx, 0, _tile_textures.size() - 1)]
	_world_geometry.add_child(sw)


func _add_platform(rect: Rect2, tile_idx: int) -> void:
	_static_platform_rects.append(rect)
	var body := StaticBody2D.new()
	body.position = rect.position
	body.collision_layer = 1
	body.collision_mask = 0

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.position = rect.size * 0.5
	body.add_child(col)

	var tex_rect := TextureRect.new()
	tex_rect.texture = _tile_textures[clampi(tile_idx, 0, _tile_textures.size() - 1)]
	tex_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tex_rect.stretch_mode = TextureRect.STRETCH_TILE
	var cols: int = maxi(1, int(round(rect.size.x / 32.0)))
	var rows: int = maxi(1, int(round(rect.size.y / 32.0)))
	var snapped_sz := Vector2(float(cols) * 32.0, float(rows) * 32.0)
	tex_rect.size = snapped_sz
	tex_rect.scale = Vector2(rect.size.x / snapped_sz.x, rect.size.y / snapped_sz.y)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(tex_rect)

	_world_geometry.add_child(body)


func _snap_floor_y_at(clamped_x: float, raw_y: float) -> float:
	var best_y: float = arena_height - 64.0
	for rect in _static_platform_rects:
		# Skip ceiling and vertical walls/pillars
		if rect.position.y <= 10.0 or rect.size.x <= 64.0:
			continue
		if rect.size.y > 120.0 and rect.position.y < arena_height - 160.0:
			continue
		if clamped_x >= rect.position.x + 22.0 and clamped_x <= rect.end.x - 22.0:
			if rect.position.y >= raw_y - 24.0 and rect.position.y < best_y:
				best_y = rect.position.y
	return best_y


func _is_spot_clear(pos: Vector2, half_w: float, half_h: float, avoid_items: bool) -> bool:
	var item_rect := Rect2(pos.x - half_w, pos.y - half_h + 2.0, half_w * 2.0, half_h * 2.0 - 4.0)
	for rect in _static_platform_rects:
		if rect.intersects(item_rect):
			return false
	if avoid_items:
		for inter in _interactables:
			if not is_instance_valid(inter):
				continue
			if "fan_pos" in inter:
				if (inter.get("fan_pos") as Vector2).distance_to(pos) < 95.0:
					return false
				if "button_pos" in inter and (inter.get("button_pos") as Vector2).distance_to(pos) < 76.0:
					return false
			elif "door_pos" in inter:
				if (inter.get("door_pos") as Vector2).distance_to(pos) < 90.0:
					return false
				if "button_pos" in inter and (inter.get("button_pos") as Vector2).distance_to(pos) < 76.0:
					return false
			elif "trap_pos" in inter:
				if (inter.get("trap_pos") as Vector2).distance_to(pos) < 90.0:
					return false
				if "button_pos" in inter and (inter.get("button_pos") as Vector2).distance_to(pos) < 76.0:
					return false
			elif inter.global_position.distance_to(pos) < 85.0:
				return false
		for ce in _crate_nodes:
			var a: Node2D = ce.get("area") as Node2D
			if is_instance_valid(a) and a.global_position.distance_to(pos) < 88.0:
				return false
		for up in _ult_pickups:
			if is_instance_valid(up) and up.position.distance_to(pos) < 62.0:
				return false
		for sp in _spawn_points:
			if sp.distance_to(pos) < 100.0:
				return false
		for p in get_tree().get_nodes_in_group("players"):
			if is_instance_valid(p) and (not p.has_method("is_alive") or p.is_alive()):
				if (p as Node2D).global_position.distance_to(pos) < 88.0:
					return false
	return true


func _snap_to_floor(raw_pos: Vector2, half_h: float = 14.0, avoid_items: bool = false) -> Vector2:
	var base_x: float = clampf(raw_pos.x, 88.0, arena_width - 88.0)
	for off_x in [0.0, 64.0, -64.0, 128.0, -128.0, 192.0, -192.0, 256.0, -256.0, 320.0, -320.0, 400.0, -400.0]:
		var cx: float = clampf(base_x + off_x, 88.0, arena_width - 88.0)
		var fy: float = _snap_floor_y_at(cx, raw_pos.y)
		var cand := Vector2(cx, fy - half_h)
		if _is_spot_clear(cand, 28.0, half_h, avoid_items):
			return cand
	return Vector2(base_x, _snap_floor_y_at(base_x, raw_pos.y) - half_h)


func _build_pickup_crates() -> void:
	var crate_specs: Array[Dictionary] = []
	if NetworkManager.is_agent_clash_mode():
		crate_specs = [
			{"pos": Vector2(arena_width * 0.50, arena_height - 120.0), "type": "throwable", "val": 0},
			{"pos": Vector2(arena_width * 0.14, arena_height * 0.72), "type": "throwable", "val": 1},
			{"pos": Vector2(arena_width * 0.86, arena_height * 0.72), "type": "throwable", "val": 2},
			{"pos": Vector2(arena_width * 0.22, arena_height * 0.30), "type": "throwable", "val": 3},
			{"pos": Vector2(arena_width * 0.78, arena_height * 0.30), "type": "throwable", "val": 4},
			{"pos": Vector2(arena_width * 0.38, arena_height * 0.52), "type": "throwable", "val": 0},
			{"pos": Vector2(arena_width * 0.62, arena_height * 0.52), "type": "throwable", "val": 6},
			{"pos": Vector2(arena_width * 0.50, arena_height * 0.52), "type": "health", "val": 45},
			{"pos": Vector2(arena_width * 0.50, arena_height * 0.20), "type": "health", "val": 50}
		]
	else:
		var allowed_ws: Array[int] = WeaponData.get_pickup_weapon_ids()
		var w_space := get_world_2d().direct_space_state
		for sp_idx in range(_spawn_points.size()):
			var w_id: int = allowed_ws[randi() % allowed_ws.size()]
			var sp: Vector2 = _spawn_points[sp_idx]
			var off_x: float = 180.0 if (sp_idx % 2 == 0) else -180.0
			var w_pos: Vector2 = sp + Vector2(off_x, 0.0)
			var w_hit := w_space.intersect_ray(PhysicsRayQueryParameters2D.create(sp, w_pos + Vector2(signf(off_x) * 22.0, 0.0), 1))
			if not w_hit.is_empty():
				var alt_pos: Vector2 = sp - Vector2(off_x, 0.0)
				var alt_hit := w_space.intersect_ray(PhysicsRayQueryParameters2D.create(sp, alt_pos - Vector2(signf(off_x) * 22.0, 0.0), 1))
				w_pos = alt_pos if alt_hit.is_empty() else Vector2(arena_width * 0.50, sp.y)
			crate_specs.append({"pos": w_pos, "type": "weapon", "val": w_id})
		crate_specs.append({"pos": Vector2(arena_width * 0.50, arena_height * 0.52), "type": "health", "val": 45})
		crate_specs.append({"pos": Vector2(arena_width * 0.50, arena_height * 0.20), "type": "health", "val": 50})
		if NetworkManager.allow_explosives:
			for bx in [arena_width * 0.28, arena_width * 0.50, arena_width * 0.72]:
				crate_specs.append({"pos": Vector2(bx, arena_height * 0.72), "type": "bomb", "val": randi() % FLOOR_BOMB_TYPES.size()})

	for i in range(crate_specs.size()):
		var spec: Dictionary = crate_specs[i]
		var half_h: float = 12.0 if str(spec["type"]) == "weapon" else 15.0
		var area := Area2D.new()
		area.position = _snap_to_floor(spec["pos"] as Vector2, half_h, true)
		area.collision_layer = 0
		area.collision_mask = 2

		var cs := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(56, 42) if str(spec["type"]) == "weapon" else (Vector2(34, 34) if str(spec["type"]) == "throwable" else Vector2(30, 30))
		cs.shape = box
		area.add_child(cs)

		var visual: Node2D
		if str(spec["type"]) == "throwable":
			area.add_to_group("throwable_pickups")
			var icon := GroundWeaponIcon.new()
			icon.item_id = int(spec["val"])
			visual = icon
		elif str(spec["type"]) == "weapon":
			var w_spr := Sprite2D.new()
			_apply_pickup_weapon_sprite(w_spr, int(spec["val"]))
			visual = w_spr
		elif str(spec["type"]) == "bomb":
			var b_icon := GroundBombIcon.new()
			b_icon.bomb_idx = int(spec["val"])
			visual = b_icon
		else:
			var spr := Sprite2D.new()
			spr.texture = TEX_CRATE
			spr.scale = Vector2(0.25, 0.25)
			visual = spr
		area.add_child(visual)

		var entry: Dictionary = {
			"area": area,
			"sprite": visual,
			"type": spec["type"],
			"val": spec["val"],
			"active": true,
			"timer": 0.0,
			"phase": float(i) * 1.3
		}
		if str(spec["type"]) == "weapon":
			entry["life_timer"] = 15.0
		_crate_nodes.append(entry)
		area.body_entered.connect(_on_crate_body_entered.bind(i))
		area.body_exited.connect(_on_crate_body_exited.bind(i))
		_pickups_container.add_child(area)

	_ult_pickups.clear()
	if NetworkManager.is_agent_clash_mode():
		for _u in range(3):
			var orb := UltPointPickup.new()
			orb.arena_ref = self
			orb.ult_idx = _ult_pickups.size()
			_pickups_container.add_child(orb)
			_ult_pickups.append(orb)
			orb.relocate_random()


func _build_interactables() -> void:
	_interactables.clear()
	var map_id: int = NetworkManager.selected_map_id
	if map_id == 0:
		# Map 0 (Bunker Base): Wind Fans + Red Switches (exclusive to Bunker Base)
		var fan_specs: Array[Dictionary] = [
			{
				"fan_pos": Vector2(490.0, arena_height - 76.0),
				"button_pos": Vector2(370.0, arena_height - 104.0),
				"push_dir": Vector2.UP,
				"beam_len": 420.0
			},
			{
				"fan_pos": Vector2(68.0, arena_height * 0.50),
				"button_pos": Vector2(76.0, arena_height * 0.50 + 78.0),
				"push_dir": Vector2.RIGHT,
				"beam_len": 440.0
			},
			{
				"fan_pos": Vector2(arena_width - 490.0, arena_height - 76.0),
				"button_pos": Vector2(arena_width - 370.0, arena_height - 104.0),
				"push_dir": Vector2.UP,
				"beam_len": 420.0
			}
		]
		for spec in fan_specs:
			var fan := InteractableFan.new()
			fan.inter_idx = _interactables.size()
			fan.fan_pos = spec["fan_pos"]
			fan.button_pos = spec["button_pos"]
			fan.push_dir = spec["push_dir"]
			fan.beam_length = float(spec["beam_len"])
			_world_geometry.add_child(fan)
			_interactables.append(fan)
	elif map_id == 1:
		# Map 1 (Factory Ruins): Industrial Steam Jump Pads + Missile Launchers
		for px in [arena_width * 0.24, arena_width * 0.76]:
			var pad := InteractableJumpPad.new()
			pad.position = _snap_to_floor(Vector2(px, arena_height - 120.0), 14.0)
			pad.pad_color = Color(1.0, 0.52, 0.16)
			pad.launch_vel = Vector2(0.0, -1080.0)
			_world_geometry.add_child(pad)
		_spawn_missile_launcher_pair(0.14, 0.86, arena_height * 0.52)
	elif map_id == 2:
		# Map 2 (Desert Outpost): Paired Sand Teleporters
		var p_a := _snap_to_floor(Vector2(arena_width * 0.18, arena_height - 120.0), 26.0)
		var p_b := _snap_to_floor(Vector2(arena_width * 0.82, arena_height - 120.0), 26.0)
		for pair in [[p_a, p_b], [p_b, p_a]]:
			var tp := InteractableTeleporter.new()
			tp.inter_idx = _interactables.size()
			tp.position = pair[0]
			tp.target_pos = pair[1]
			tp.portal_color = Color(1.0, 0.78, 0.20)
			_world_geometry.add_child(tp)
			_interactables.append(tp)
	elif map_id == 3:
		# Map 3 (Dungeon): Toggleable Iron Dungeon Doors + Toggle-Activated Steel Spike Spawners
		for dx in [arena_width * 0.26, arena_width * 0.74]:
			var door := InteractableDoor.new()
			door.inter_idx = _interactables.size()
			door.door_pos = _snap_to_floor(Vector2(dx, arena_height - 140.0), 90.0)
			door.button_pos = door.door_pos + Vector2(-72.0 if dx < arena_width * 0.5 else 72.0, 56.0)
			_world_geometry.add_child(door)
			_interactables.append(door)
		for sx in [arena_width * 0.40, arena_width * 0.60]:
			var trap := InteractableSpikeTrap.new()
			trap.inter_idx = _interactables.size()
			trap.trap_pos = _snap_to_floor(Vector2(sx, arena_height - 120.0), 8.0)
			trap.button_pos = trap.trap_pos + Vector2(-104.0, -24.0)
			_world_geometry.add_child(trap)
			_interactables.append(trap)
	elif map_id == 4:
		# Map 4 (Outpost Towers): Switch-Activated Laser Gate + 3+ Auto-Respawning Proximity Mines
		var lg := InteractableSwitchHazard.new()
		lg.inter_idx = _interactables.size()
		lg.hazard_kind = "laser"
		lg.hazard_color = Color(1.0, 0.22, 0.45)
		lg.position = _snap_to_floor(Vector2(arena_width * 0.50, arena_height - 120.0), 18.0)
		_world_geometry.add_child(lg)
		_interactables.append(lg)
		var mine_mgr := ArenaAutoMineManager.new()
		mine_mgr.arena_ref = self
		mine_mgr.target_mines = 3
		_mine_mgr = mine_mgr
		_world_geometry.add_child(mine_mgr)
		_spawn_missile_launcher_pair(0.16, 0.84, arena_height * 0.48)
	elif map_id == 5:
		# Map 5 (Soarin Islands): Emerald Sky-Wind Launch Geysers
		for px in [arena_width * 0.26, arena_width * 0.74]:
			var gey := InteractableJumpPad.new()
			gey.position = _snap_to_floor(Vector2(px, arena_height - 140.0), 14.0)
			gey.pad_color = Color(0.24, 0.92, 0.45)
			gey.launch_vel = Vector2(0.0, -920.0)
			_world_geometry.add_child(gey)
	elif map_id == 6:
		# Map 6 (Pharaoh Pyramid): Solar Flare Shockwave Altar
		var sol := InteractableSwitchHazard.new()
		sol.inter_idx = _interactables.size()
		sol.hazard_kind = "solar_flare"
		sol.hazard_color = Color(1.0, 0.82, 0.22)
		sol.position = _snap_to_floor(Vector2(arena_width * 0.50, arena_height - 120.0), 22.0)
		_world_geometry.add_child(sol)
		_interactables.append(sol)
	elif map_id == 7:
		# Map 7 (Snow Blind): Cryo Freeze Vent Switch
		for cx in [arena_width * 0.28, arena_width * 0.72]:
			var cry := InteractableSwitchHazard.new()
			cry.inter_idx = _interactables.size()
			cry.hazard_kind = "cryo_vent"
			cry.hazard_color = Color(0.35, 0.90, 1.0)
			cry.position = _snap_to_floor(Vector2(cx, arena_height - 120.0), 18.0)
			_world_geometry.add_child(cry)
			_interactables.append(cry)
	elif map_id == 8:
		# Map 8 (Substructure): Automated Defense Sentry Switch
		var sen := InteractableSwitchHazard.new()
		sen.inter_idx = _interactables.size()
		sen.hazard_kind = "sentry"
		sen.hazard_color = Color(0.28, 0.82, 1.0)
		sen.position = _snap_to_floor(Vector2(arena_width * 0.50, arena_height - 120.0), 22.0)
		_world_geometry.add_child(sen)
		_interactables.append(sen)
		_spawn_missile_launcher_pair(0.16, 0.84, arena_height * 0.52)
	elif map_id == 9:
		# Map 9 (High Tower): Speed Boost Shrine
		for sx in [arena_width * 0.26, arena_width * 0.74]:
			var sh := InteractableBoostShrine.new()
			sh.inter_idx = _interactables.size()
			sh.position = _snap_to_floor(Vector2(sx, arena_height - 120.0), 24.0)
			sh.shrine_kind = "speed"
			sh.shrine_color = Color(0.74, 0.36, 1.0)
			_world_geometry.add_child(sh)
			_interactables.append(sh)
	elif map_id == 10:
		# Map 10 (Ring Arena): Ammo & Fuel Supply Dispenser
		for sx in [arena_width * 0.22, arena_width * 0.78]:
			var sup := InteractableBoostShrine.new()
			sup.inter_idx = _interactables.size()
			sup.position = _snap_to_floor(Vector2(sx, arena_height - 120.0), 24.0)
			sup.shrine_kind = "ammo"
			sup.shrine_color = Color(0.28, 0.88, 1.0)
			_world_geometry.add_child(sup)
			_interactables.append(sup)
	elif map_id == 11:
		# Map 11 (Lunar Station): Zero-G Pulse Core + Warp Portals
		var zg := InteractableSwitchHazard.new()
		zg.inter_idx = _interactables.size()
		zg.hazard_kind = "low_g"
		zg.hazard_color = Color(0.55, 0.78, 1.0)
		zg.position = _snap_to_floor(Vector2(arena_width * 0.50, arena_height - 140.0), 22.0)
		_world_geometry.add_child(zg)
		_interactables.append(zg)
		var lp_a := _snap_to_floor(Vector2(arena_width * 0.14, arena_height - 120.0), 26.0)
		var lp_b := _snap_to_floor(Vector2(arena_width * 0.86, arena_height - 120.0), 26.0)
		for pair in [[lp_a, lp_b], [lp_b, lp_a]]:
			var ltp := InteractableTeleporter.new()
			ltp.inter_idx = _interactables.size()
			ltp.position = pair[0]
			ltp.target_pos = pair[1]
			ltp.portal_color = Color(0.32, 0.84, 1.0)
			_world_geometry.add_child(ltp)
			_interactables.append(ltp)
	else:
		# Map 12 (Jungle Cliff): Venom Spore Pod Switch
		for jx in [arena_width * 0.25, arena_width * 0.75]:
			var pod := InteractableSwitchHazard.new()
			pod.inter_idx = _interactables.size()
			pod.hazard_kind = "spore_cloud"
			pod.hazard_color = Color(0.36, 0.96, 0.28)
			pod.position = _snap_to_floor(Vector2(jx, arena_height - 140.0), 20.0)
			_world_geometry.add_child(pod)
			_interactables.append(pod)

	var heal := InteractableHealStation.new()
	heal.inter_idx = _interactables.size()
	heal.position = Vector2(arena_width * 0.50, arena_height - 104.0)
	_world_geometry.add_child(heal)
	_interactables.append(heal)

	var tbox := InteractableTreasureBox.new()
	tbox.inter_idx = _interactables.size()
	tbox.position = _snap_to_floor(Vector2(arena_width * 0.50, arena_height * 0.42), 20.0, true)
	_world_geometry.add_child(tbox)
	_interactables.append(tbox)

	var prop_kinds: Array = _get_map_prop_kinds(NetworkManager.selected_map_id)
	var prop_spots: Array[Vector2] = [
		Vector2(arena_width * 0.16, arena_height - 84.0),
		Vector2(arena_width * 0.38, arena_height - 84.0),
		Vector2(arena_width * 0.62, arena_height - 84.0),
		Vector2(arena_width * 0.84, arena_height - 84.0)
	]
	for p_i in range(prop_spots.size()):
		var pr := InteractableProp.new()
		pr.inter_idx = _interactables.size()
		pr.prop_kind = str(prop_kinds[p_i % prop_kinds.size()])
		pr.position = prop_spots[p_i]
		_world_geometry.add_child(pr)
		_interactables.append(pr)


func _spawn_missile_launcher_pair(left_x_ratio: float, right_x_ratio: float, probe_y: float) -> void:
	var left_pos: Vector2 = _snap_to_floor(Vector2(arena_width * left_x_ratio, probe_y), 26.0, true)
	var right_pos: Vector2 = _snap_to_floor(Vector2(arena_width * right_x_ratio, probe_y), 26.0, true)
	var specs: Array[Dictionary] = [
		{"launcher_pos": left_pos, "button_pos": left_pos + Vector2(-78.0, -4.0), "shoot_dir": Vector2.RIGHT},
		{"launcher_pos": right_pos, "button_pos": right_pos + Vector2(78.0, -4.0), "shoot_dir": Vector2.LEFT}
	]
	for mspec in specs:
		var ml := InteractableMissileLauncher.new()
		ml.inter_idx = _interactables.size()
		ml.launcher_pos = mspec["launcher_pos"]
		ml.button_pos = mspec["button_pos"]
		ml.shoot_dir = mspec["shoot_dir"]
		_world_geometry.add_child(ml)
		_interactables.append(ml)


func _get_map_prop_kinds(map_id: int) -> Array:
	match map_id:
		5, 12:
			return ["wood", "coconut"]
		0, 1, 4, 8:
			return ["chair", "barrel"]
		2, 3, 6, 9:
			return ["pot", "stone"]
		_:
			return ["ice_block", "crate"]


func _on_interact_requested(inter_idx: int) -> void:
	if inter_idx < 0 or inter_idx >= _interactables.size():
		return
	var node: Node2D = _interactables[inter_idx]
	if node is InteractableFan:
		var fan := node as InteractableFan
		NetworkManager.toggle_interactable(inter_idx, not fan.is_on)
	elif node is InteractableMissileLauncher:
		var ml := node as InteractableMissileLauncher
		if ml.cooldown_left <= 0.0:
			NetworkManager.toggle_interactable(inter_idx, true)
	elif node is InteractableHealStation:
		var heal := node as InteractableHealStation
		if heal.cooldown_left <= 0.0:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and p.get("is_local_human") == true and p.has_method("is_alive") and p.is_alive():
					p.apply_pickup("health", 45)
					p.set("jetpack_fuel", minf(100.0, float(p.get("jetpack_fuel")) + 50.0))
					if p.has_method("set_nearby_interactable"):
						p.set_nearby_interactable(-1, "")
					break
			NetworkManager.toggle_interactable(inter_idx, true)
	elif node is InteractableProp:
		var pr := node as InteractableProp
		if pr.is_available:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and p.get("is_local_human") == true and p.has_method("is_alive") and p.is_alive():
					if p.has_method("set_held_prop"):
						p.set_held_prop(pr.prop_kind)
					if p.has_method("set_nearby_interactable"):
						p.set_nearby_interactable(-1, "")
					break
			NetworkManager.toggle_interactable(inter_idx, true)
	elif node is InteractableTeleporter:
		var tp := node as InteractableTeleporter
		if tp.cooldown_left <= 0.0:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and p.get("is_local_human") == true and p.has_method("is_alive") and p.is_alive():
					(p as Node2D).global_position = tp.target_pos + Vector2(0.0, -10.0)
					if p.has_method("set_nearby_interactable"):
						p.set_nearby_interactable(-1, "")
					break
			NetworkManager.toggle_interactable(inter_idx, true)
	elif node is InteractableBoostShrine:
		var sh := node as InteractableBoostShrine
		if sh.cooldown_left <= 0.0:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and p.get("is_local_human") == true and p.has_method("is_alive") and p.is_alive():
					if sh.shrine_kind == "speed":
						p.set("speed_boost_timer", 5.0)
						p.set("speed_boost_mult", 1.45)
					else:
						p.set("jetpack_fuel", 100.0)
						p.apply_pickup("health", 25)
					if p.has_method("set_nearby_interactable"):
						p.set_nearby_interactable(-1, "")
					break
			NetworkManager.toggle_interactable(inter_idx, true)
	elif node is InteractableSwitchHazard:
		var hz := node as InteractableSwitchHazard
		if hz.cooldown_left <= 0.0 and not hz.is_active:
			NetworkManager.toggle_interactable(inter_idx, true)
	elif node is InteractableDoor:
		var dr := node as InteractableDoor
		NetworkManager.toggle_interactable(inter_idx, not dr.is_open)
	elif node is InteractableSpikeTrap:
		var st := node as InteractableSpikeTrap
		NetworkManager.toggle_interactable(inter_idx, not st.is_on)
	elif node is InteractableTreasureBox:
		var tb := node as InteractableTreasureBox
		if tb.cooldown_left <= 0.0:
			for p in get_tree().get_nodes_in_group("players"):
				if is_instance_valid(p) and p.get("is_local_human") == true and p.has_method("is_alive") and p.is_alive():
					ProfileManager.add_coins(ProfileManager.get_treasure_reward())
					if has_node("/root/AchievementManager"):
						get_node("/root/AchievementManager").record_treasure_open()
					if p.has_method("set_nearby_interactable"):
						p.set_nearby_interactable(-1, "")
					break
			NetworkManager.toggle_interactable(inter_idx, randi() % 2 == 0)


func _on_interactable_toggled(inter_idx: int, new_state: bool) -> void:
	if inter_idx < 0 or inter_idx >= _interactables.size():
		return
	var node: Node2D = _interactables[inter_idx]
	if node is InteractableFan:
		(node as InteractableFan).set_fan_state(new_state)
	elif node is InteractableMissileLauncher:
		(node as InteractableMissileLauncher).fire_missile()
	elif node is InteractableHealStation:
		(node as InteractableHealStation).trigger_cooldown()
	elif node is InteractableProp:
		(node as InteractableProp).pick_up_prop()
	elif node is InteractableTeleporter:
		(node as InteractableTeleporter).trigger_cooldown()
	elif node is InteractableBoostShrine:
		(node as InteractableBoostShrine).trigger_cooldown()
	elif node is InteractableSwitchHazard:
		(node as InteractableSwitchHazard).activate_hazard()
	elif node is InteractableDoor:
		(node as InteractableDoor).set_door_state(new_state)
	elif node is InteractableSpikeTrap:
		(node as InteractableSpikeTrap).set_trap_state(new_state)
	elif node is InteractableTreasureBox:
		(node as InteractableTreasureBox).trigger_opened()
		var origin_p: Vector2 = node.global_position
		if NetworkManager.is_agent_clash_mode():
			if new_state:
				_spawn_treasure_drop(origin_p, _snap_to_floor(origin_p, 16.0, false), "ult_full", 3)
			else:
				var slots: Array[int] = [0, 1, 2]
				slots.shuffle()
				_spawn_treasure_drop(origin_p, _snap_to_floor(origin_p + Vector2(-42.0, 0.0), 12.0, false), "abil_orb", slots[0])
				_spawn_treasure_drop(origin_p, _snap_to_floor(origin_p + Vector2(42.0, 0.0), 12.0, false), "abil_orb", slots[1])
		else:
			_spawn_treasure_drop(origin_p, _snap_to_floor(origin_p + Vector2(-58.0, 0.0), 15.0, false), "health", 100)
			var tb_pool: Array[int] = [22, 17]
			if NetworkManager.allow_explosives:
				tb_pool.append(12)
			var tb_weapon_id: int = tb_pool[randi() % tb_pool.size()]
			_spawn_treasure_drop(origin_p, _snap_to_floor(origin_p + Vector2(58.0, 0.0), 12.0, false), "weapon", tb_weapon_id)
			if NetworkManager.allow_explosives:
				var b_type_str: String = "frag"
				var best_d: float = 1e9
				for p in get_tree().get_nodes_in_group("players"):
					if is_instance_valid(p) and (not p.has_method("is_alive") or p.is_alive()):
						var d: float = (p as Node2D).global_position.distance_to(origin_p)
						if d < best_d:
							best_d = d
							b_type_str = str(p.get("bomb_type"))
				var b_idx: int = maxi(0, FLOOR_BOMB_TYPES.find(b_type_str))
				for bx_off in [-36.0, 0.0, 36.0]:
					_spawn_treasure_drop(origin_p, _snap_to_floor(origin_p + Vector2(bx_off, 0.0), 14.0, false), "bomb", b_idx)


func _on_barrel_detonated(inter_idx: int, attacker_id: int, attacker_name: String, attacker_team: int) -> void:
	if inter_idx < 0 or inter_idx >= _interactables.size():
		return
	var node: Node2D = _interactables[inter_idx]
	if node is InteractableProp:
		(node as InteractableProp).detonate_barrel_local(attacker_id, attacker_name, attacker_team)


func _on_crate_consumed(crate_idx: int, next_val: int) -> void:
	if crate_idx < 0 or crate_idx >= _crate_nodes.size():
		return
	var entry: Dictionary = _crate_nodes[crate_idx]
	var p_type: String = str(entry["type"])
	entry["active"] = false
	entry["timer"] = 9999999.0 if bool(entry.get("one_shot", false)) else (6.0 if p_type == "throwable" else 9.0)
	var area: Area2D = entry["area"] as Area2D
	area.visible = false
	area.set_deferred("monitoring", false)
	if p_type == "throwable":
		entry["val"] = next_val
		var icon := entry["sprite"] as GroundWeaponIcon
		if icon != null:
			icon.item_id = next_val
			icon.queue_redraw()
	elif p_type == "weapon":
		entry["val"] = next_val
		var w_spr := entry["sprite"] as Sprite2D
		if w_spr != null:
			_apply_pickup_weapon_sprite(w_spr, next_val)
	elif p_type == "bomb":
		entry["val"] = next_val
		var b_icon := entry["sprite"] as GroundBombIcon
		if b_icon != null:
			b_icon.bomb_idx = next_val
			b_icon.queue_redraw()


func _spawn_treasure_drop(origin_pos: Vector2, target_pos: Vector2, drop_type: String, drop_val: int) -> void:
	if not is_instance_valid(_pickups_container):
		return
	var idx: int = _crate_nodes.size()
	var area := Area2D.new()
	area.position = origin_pos + Vector2(0.0, -10.0)
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = false

	var cs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(56, 42) if drop_type == "weapon" else Vector2(30, 30)
	cs.shape = box
	area.add_child(cs)

	var visual: Node2D
	if drop_type == "weapon":
		var spr := Sprite2D.new()
		_apply_pickup_weapon_sprite(spr, drop_val)
		visual = spr
	elif drop_type == "bomb":
		var b_icon := GroundBombIcon.new()
		b_icon.bomb_idx = drop_val
		visual = b_icon
	elif drop_type == "ult_full" or drop_type == "abil_orb":
		var orb_vis := TreasurePointOrb.new()
		orb_vis.orb_kind = drop_type
		orb_vis.slot_idx = drop_val
		visual = orb_vis
	else:
		var spr := Sprite2D.new()
		spr.texture = TEX_CRATE
		spr.scale = Vector2(0.25, 0.25)
		visual = spr
	area.add_child(visual)

	var entry: Dictionary = {
		"area": area,
		"sprite": visual,
		"type": drop_type,
		"val": drop_val,
		"active": true,
		"one_shot": true,
		"from_treasure": true,
		"target_pos": target_pos,
		"timer": 0.0,
		"phase": float(idx) * 1.3
	}
	_crate_nodes.append(entry)
	area.body_entered.connect(_on_crate_body_entered.bind(idx))
	area.body_exited.connect(_on_crate_body_exited.bind(idx))
	_pickups_container.add_child(area)

	var mid_pos: Vector2 = Vector2((origin_pos.x + target_pos.x) * 0.5, minf(origin_pos.y, target_pos.y) - 52.0)
	var tw := area.create_tween()
	tw.tween_property(area, "position", mid_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(area, "position", target_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(area) and bool(entry.get("active", false)):
			area.monitoring = true
	)


func spawn_dropped_weapon_pickup(w_id: int, origin_pos: Vector2, angle: float, saved_mag: int, saved_res: int) -> void:
	if not is_instance_valid(_pickups_container):
		return
	var idx: int = _crate_nodes.size()
	var area := Area2D.new()
	area.position = origin_pos + Vector2(0.0, -10.0)
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = false

	var cs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(56, 42)
	cs.shape = box
	area.add_child(cs)

	var spr := Sprite2D.new()
	_apply_pickup_weapon_sprite(spr, w_id)
	area.add_child(spr)

	var entry: Dictionary = {
		"area": area,
		"sprite": spr,
		"type": "weapon",
		"val": w_id,
		"active": true,
		"one_shot": true,
		"despawn_timer": 5.0,
		"saved_mag": saved_mag,
		"saved_res": saved_res,
		"timer": 0.0,
		"phase": float(idx) * 1.3
	}
	_crate_nodes.append(entry)
	area.body_entered.connect(_on_crate_body_entered.bind(idx))
	area.body_exited.connect(_on_crate_body_exited.bind(idx))
	_pickups_container.add_child(area)

	var dir_x: float = signf(cos(angle))
	if dir_x == 0.0:
		dir_x = 1.0
	var target_pos: Vector2 = _snap_to_floor(origin_pos + Vector2(dir_x * 84.0, 26.0), 12.0, false)
	var mid_pos: Vector2 = Vector2((origin_pos.x + target_pos.x) * 0.5, minf(origin_pos.y, target_pos.y) - 38.0)
	var rot_tw := spr.create_tween()
	rot_tw.tween_property(spr, "rotation", dir_x * TAU, 0.42)
	rot_tw.tween_property(spr, "rotation", 0.0, 0.05)
	var tw := area.create_tween()
	tw.tween_property(area, "position", mid_pos, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(area, "position", target_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(area) and bool(entry.get("active", false)):
			area.monitoring = true
	)


func _on_ult_pickup_relocated(ult_idx: int, new_pos: Vector2) -> void:
	if ult_idx < 0 or ult_idx >= _ult_pickups.size():
		return
	var u: Node2D = _ult_pickups[ult_idx]
	if is_instance_valid(u):
		u.position = new_pos


func _on_mine_event(action: String, mine_id: int, pos: Vector2) -> void:
	if is_instance_valid(_mine_mgr) and _mine_mgr.has_method("handle_network_mine_event"):
		_mine_mgr.handle_network_mine_event(action, mine_id, pos)


func _random_ground_throwable_id() -> int:
	var pool: Array[int] = []
	for idx in range(AgentData.THROWABLE_ITEMS.size()):
		if idx != 5:  # Heavy Combat Shoe is default throwable, no ground pickup needed
			pool.append(idx)
	return pool[randi() % pool.size()]


func _on_crate_body_entered(body: Node2D, crate_idx: int) -> void:
	var entry: Dictionary = _crate_nodes[crate_idx]
	if not bool(entry["active"]):
		return
	if body.is_in_group("players") and body.has_method("apply_pickup"):
		if body.has_method("is_alive") and not body.is_alive():
			return
		var is_local_actor: bool = (body.get("is_local_human") == true) or (body.get("is_bot") == true and (not NetworkManager.is_network_active() or NetworkManager.is_host_active()))
		if not is_local_actor:
			return
		var p_type: String = str(entry["type"])
		if p_type == "throwable":
			if not body.has_method("can_grab_throwable") or not body.can_grab_throwable():
				return
			var val: int = int(entry["val"])
			body.apply_pickup("throwable", val)
			var next_val: int = _random_ground_throwable_id()
			NetworkManager.consume_crate(crate_idx, next_val)
			return

		if p_type == "weapon":
			if body.get("is_local_human") == true and body.has_method("set_nearby_weapon"):
				body.set_nearby_weapon(crate_idx, int(entry["val"]))
			elif body.get("is_bot") == true and not NetworkManager.is_agent_clash_mode():
				_try_bot_pickup_weapon_crate(crate_idx, body)
			return

		if p_type == "bomb":
			if not NetworkManager.allow_explosives or NetworkManager.is_agent_clash_mode():
				return
			var b_idx: int = clampi(int(entry["val"]), 0, FLOOR_BOMB_TYPES.size() - 1)
			if body.has_method("add_bomb_pickup"):
				body.add_bomb_pickup(FLOOR_BOMB_TYPES[b_idx], 1)
			NetworkManager.consume_crate(crate_idx, randi() % FLOOR_BOMB_TYPES.size())
			return

		if p_type == "ult_full":
			if body.has_method("grant_full_ult"):
				body.grant_full_ult()
			NetworkManager.consume_crate(crate_idx, 0)
			return

		if p_type == "abil_orb":
			if body.has_method("ready_ability_slot"):
				body.ready_ability_slot(int(entry["val"]))
			NetworkManager.consume_crate(crate_idx, 0)
			return

		var val: int = int(entry["val"])
		body.apply_pickup(p_type, val)
		NetworkManager.consume_crate(crate_idx, val)


func _on_crate_body_exited(body: Node2D, crate_idx: int) -> void:
	if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_weapon"):
		if int(body.get("nearby_weapon_crate")) == crate_idx:
			body.set_nearby_weapon(-1, -1)


func _on_pickup_weapon_requested(crate_idx: int) -> void:
	if crate_idx < 0 or crate_idx >= _crate_nodes.size():
		return
	var entry: Dictionary = _crate_nodes[crate_idx]
	if not bool(entry["active"]) or str(entry["type"]) != "weapon":
		return
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p) and p.get("is_local_human") == true and p.has_method("is_alive") and p.is_alive():
			_consume_weapon_crate(crate_idx, p)
			if p.has_method("set_nearby_weapon"):
				p.set_nearby_weapon(-1, -1)
			break


func _consume_weapon_crate(crate_idx: int, body: Node2D) -> void:
	var entry: Dictionary = _crate_nodes[crate_idx]
	var val: int = int(entry["val"])
	body.apply_pickup("weapon", val)
	if entry.has("saved_mag"):
		body.set("current_ammo", int(entry["saved_mag"]))
		if body.has_method("_set_active_reserve_ammo"):
			body.call("_set_active_reserve_ammo", int(entry["saved_res"]))
		if body.has_method("_emit_ammo"):
			body.call("_emit_ammo")
	var allowed_ws: Array[int] = WeaponData.get_pickup_weapon_ids()
	var next_w: int = allowed_ws[randi() % allowed_ws.size()]
	NetworkManager.consume_crate(crate_idx, next_w)


func _try_bot_pickup_weapon_crate(crate_idx: int, bot: Node2D) -> bool:
	if crate_idx < 0 or crate_idx >= _crate_nodes.size():
		return false
	var entry: Dictionary = _crate_nodes[crate_idx]
	if not bool(entry["active"]) or str(entry["type"]) != "weapon":
		return false
	if NetworkManager.is_agent_clash_mode():
		return false
	var val: int = int(entry["val"])
	var cur_w: int = int(bot.get("current_weapon_id")) if "current_weapon_id" in bot else -1
	if val == cur_w:
		return false
	var cd: float = float(bot.get("_bot_weapon_pickup_cd")) if "_bot_weapon_pickup_cd" in bot else 0.0
	var is_treasure_gun: bool = bool(entry.get("from_treasure", false)) or val == 17 or val == 22 or val == 12
	if is_treasure_gun:
		# High chance to pick up Treasure Box exclusive weapons (Groza / Machine Gun / Follow Rocket)
		if randf() > 0.90:
			if "_bot_weapon_pickup_cd" in bot:
				bot.set("_bot_weapon_pickup_cd", 3.0)
			return false
	else:
		# Regular floor guns are optional — only pick up occasionally when passing by
		if cd > 0.0:
			return false
		if randf() > 0.28:
			if "_bot_weapon_pickup_cd" in bot:
				bot.set("_bot_weapon_pickup_cd", 4.5)
			return false
	_consume_weapon_crate(crate_idx, bot)
	if "_bot_weapon_pickup_cd" in bot:
		bot.set("_bot_weapon_pickup_cd", 12.0 if not is_treasure_gun else 8.0)
	return true


func try_bot_interact_nearby(bot: Node2D) -> void:
	if not is_instance_valid(bot) or (bot.has_method("is_alive") and not bot.is_alive()):
		return
	if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
		return
	var bpos: Vector2 = bot.global_position
	var b_hp: float = float(bot.get("health")) if "health" in bot else 100.0
	var b_max_hp: float = float(bot.get("max_health")) if "max_health" in bot else 100.0
	for i in range(_interactables.size()):
		var node: Node2D = _interactables[i]
		if not is_instance_valid(node):
			continue
		if node is InteractableTreasureBox:
			var tb := node as InteractableTreasureBox
			if tb.cooldown_left <= 0.0 and bpos.distance_to(tb.global_position) <= 95.0:
				if "_bot_loot_focus_timer" in bot:
					bot.set("_bot_loot_focus_timer", 2.8)
					bot.set("_bot_loot_origin", tb.global_position)
				NetworkManager.toggle_interactable(i, randi() % 2 == 0)
				return
		elif node is InteractableHealStation:
			var hs := node as InteractableHealStation
			if hs.cooldown_left <= 0.0 and b_hp < b_max_hp * 0.65 and bpos.distance_to(hs.global_position) <= 95.0:
				if bot.has_method("apply_pickup"):
					bot.apply_pickup("health", 45)
				NetworkManager.toggle_interactable(i, true)
				return
		elif node is InteractableBoostShrine:
			var bs := node as InteractableBoostShrine
			if bs.cooldown_left <= 0.0 and bpos.distance_to(bs.global_position) <= 95.0:
				if bot.has_method("apply_pickup"):
					bot.apply_pickup("health", 25)
				NetworkManager.toggle_interactable(i, true)
				return
	for ci in range(_crate_nodes.size()):
		var c: Dictionary = _crate_nodes[ci]
		if not bool(c["active"]):
			continue
		var area: Area2D = c["area"] as Area2D
		if not is_instance_valid(area) or not area.monitoring:
			continue
		var p_type: String = str(c["type"])
		if p_type == "weapon":
			if not NetworkManager.is_agent_clash_mode() and bpos.distance_to(area.global_position) <= 48.0:
				if _try_bot_pickup_weapon_crate(ci, bot):
					return
		elif bool(c.get("from_treasure", false)) and bpos.distance_to(area.global_position) <= 44.0:
			_on_crate_body_entered(bot, ci)
			return


func get_bot_pickup_target(bot: Node2D, max_dist: float = 520.0, in_combat: bool = false) -> Dictionary:
	var result: Dictionary = {"found": false, "pos": Vector2.ZERO, "score": -1.0}
	if not is_instance_valid(bot) or (bot.has_method("is_alive") and not bot.is_alive()):
		return result
	var bpos: Vector2 = bot.global_position
	var b_hp: float = float(bot.get("health")) if "health" in bot else 100.0
	var b_max_hp: float = float(bot.get("max_health")) if "max_health" in bot else 100.0
	var hp_ratio: float = b_hp / maxf(b_max_hp, 1.0)
	var agent_mode: bool = NetworkManager.is_agent_clash_mode()
	var can_ult: bool = bot.has_method("can_collect_ult_point") and bot.can_collect_ult_point()
	var can_throw: bool = bot.has_method("can_grab_throwable") and bot.can_grab_throwable()
	var cur_w: int = int(bot.get("current_weapon_id")) if "current_weapon_id" in bot else -1
	var w_cd: float = float(bot.get("_bot_weapon_pickup_cd")) if "_bot_weapon_pickup_cd" in bot else 0.0
	var loot_focus: float = float(bot.get("_bot_loot_focus_timer")) if "_bot_loot_focus_timer" in bot else 0.0
	var loot_origin: Vector2 = bot.get("_bot_loot_origin") as Vector2 if "_bot_loot_origin" in bot else bpos
	var best_score: float = -1.0
	var best_pos: Vector2 = Vector2.ZERO

	# 0. Immediately sweep up loot from a treasure box this bot just opened
	if loot_focus > 0.0:
		var found_loot: bool = false
		for c in _crate_nodes:
			if not bool(c["active"]) or not bool(c.get("from_treasure", false)):
				continue
			var area: Area2D = c["area"] as Area2D
			if not is_instance_valid(area):
				continue
			var p_type: String = str(c["type"])
			var val: int = int(c["val"])
			if p_type == "weapon" and (agent_mode or val == cur_w):
				continue
			if p_type == "bomb" and (agent_mode or not NetworkManager.allow_explosives):
				continue
			if p_type == "health" and hp_ratio >= 0.95:
				continue
			var land_pos: Vector2 = c.get("target_pos", area.global_position) as Vector2
			if land_pos.distance_to(loot_origin) <= 180.0:
				var d: float = bpos.distance_to(land_pos)
				var sc: float = 250.0 - d * 0.25
				if sc > best_score:
					best_score = sc
					best_pos = land_pos
					found_loot = true
		if found_loot:
			result["found"] = true
			result["pos"] = best_pos
			result["score"] = best_score
			return result
		elif loot_focus < 2.2:
			# All treasure drops already picked up
			bot.set("_bot_loot_focus_timer", 0.0)

	# 1. Ready Treasure Boxes & Heal/Boost Stations
	for node in _interactables:
		if not is_instance_valid(node):
			continue
		var d: float = bpos.distance_to(node.global_position)
		if d > max_dist:
			continue
		var base_pri: float = 0.0
		if node is InteractableTreasureBox and (node as InteractableTreasureBox).cooldown_left <= 0.0:
			base_pri = 132.0 if not in_combat else (122.0 if d <= 220.0 else 0.0)
		elif node is InteractableHealStation and (node as InteractableHealStation).cooldown_left <= 0.0:
			if hp_ratio < 0.55 and not in_combat:
				base_pri = 135.0
			elif hp_ratio <= 0.30 and in_combat and d <= 260.0:
				base_pri = 125.0
		elif node is InteractableBoostShrine and (node as InteractableBoostShrine).cooldown_left <= 0.0 and not in_combat:
			base_pri = 65.0
		if base_pri > 0.0:
			var sc: float = base_pri - d * 0.14
			if sc > best_score:
				best_score = sc
				best_pos = node.global_position

	# 2. Floating Ult Orbs (Agent Clash)
	if can_ult:
		for up in _ult_pickups:
			if not is_instance_valid(up):
				continue
			var d: float = bpos.distance_to(up.global_position)
			if d <= max_dist and (not in_combat or d <= 180.0):
				var sc: float = 115.0 - d * 0.15
				if sc > best_score:
					best_score = sc
					best_pos = up.global_position

	# 3. Ground Crates & Treasure Drops (ability orbs, ult_full, floor weapons, health, bombs, throwables)
	for c in _crate_nodes:
		if not bool(c["active"]):
			continue
		var area: Area2D = c["area"] as Area2D
		if not is_instance_valid(area):
			continue
		var d: float = bpos.distance_to(area.global_position)
		if d > max_dist:
			continue
		var p_type: String = str(c["type"])
		var val: int = int(c["val"])
		var base_pri: float = 0.0
		match p_type:
			"ult_full":
				if agent_mode:
					base_pri = 150.0 if (not in_combat or d <= 220.0) else 0.0
			"abil_orb":
				if agent_mode:
					base_pri = 130.0 if (not in_combat or d <= 180.0) else 0.0
			"health":
				if hp_ratio < 0.55 and not in_combat:
					base_pri = 135.0
				elif hp_ratio <= 0.30 and in_combat and d <= 260.0:
					base_pri = 125.0
				elif hp_ratio < 0.75 and d <= 90.0:
					base_pri = 105.0
			"weapon":
				if not agent_mode and val != cur_w:
					var is_treasure_gun: bool = bool(c.get("from_treasure", false)) or val == 17 or val == 22 or val == 12
					if is_treasure_gun:
						if not in_combat or d <= 220.0:
							base_pri = 138.0
					elif w_cd <= 0.0 and not in_combat and d <= 155.0:
						# Floor guns are optional: only detour slightly if already passing close by
						base_pri = 36.0
			"bomb":
				if not agent_mode and NetworkManager.allow_explosives and not in_combat:
					base_pri = 58.0
			"throwable":
				if agent_mode and can_throw and not in_combat:
					base_pri = 68.0
		if base_pri > 0.0:
			var sc: float = base_pri - d * 0.14
			if sc > best_score:
				best_score = sc
				best_pos = area.global_position

	if best_score > 0.0:
		result["found"] = true
		result["pos"] = best_pos
		result["score"] = best_score
	return result


func _apply_pickup_weapon_sprite(w_spr: Sprite2D, w_id: int) -> void:
	var eq_key: String = ProfileManager.get_equipped_gun_skin(w_id)
	var spec: Dictionary = WeaponData.get_weapon_sprite_spec(w_id, ProfileManager.get_equipped_gun_skin_row(w_id))
	w_spr.texture = spec["tex"] as Texture2D
	w_spr.hframes = int(spec["hframes"])
	w_spr.vframes = int(spec["vframes"])
	w_spr.frame = int(spec["frame"])
	w_spr.modulate = ProfileManager.get_gun_skin_tint(w_id, eq_key)
	w_spr.scale = Vector2(0.313, 0.313) if w_id == 17 else (Vector2(0.295, 0.295) if w_id == 12 else Vector2(0.278, 0.278))


func _pick_safest_spawn() -> Vector2:
	if _spawn_points.is_empty():
		return Vector2(640.0, 320.0)
	var occupied: Array[Vector2] = []
	if is_instance_valid(_players_container):
		for ch in _players_container.get_children():
			if ch is Node2D and (not ch.has_method("is_alive") or ch.is_alive()):
				occupied.append((ch as Node2D).global_position)
	if occupied.is_empty():
		return _spawn_points[randi() % _spawn_points.size()]

	var candidates: Array[Vector2] = []
	var space := get_world_2d().direct_space_state
	for sp in _spawn_points:
		candidates.append(sp)
		for off_x in [140.0, -140.0, 280.0, -280.0]:
			var cand: Vector2 = sp + Vector2(off_x, 0.0)
			if cand.x < 90.0 or cand.x > arena_width - 90.0:
				continue
			var wall_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(sp, cand + Vector2(signf(off_x) * 24.0, 0.0), 1))
			if not wall_hit.is_empty():
				continue
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(cand, cand + Vector2(0.0, 64.0), 1))
			if floor_hit.is_empty():
				continue
			candidates.append(cand)

	# Also generate well-spaced points along walkable floors/platforms
	for r in _static_platform_rects:
		if r.size.x < 160.0:
			continue
		if r.size.y > 120.0 and r.position.y < arena_height - 160.0:
			continue
		var sy: float = r.position.y - 38.0
		if sy < 90.0 or sy > arena_height - 60.0:
			continue
		var sx: float = maxf(96.0, r.position.x + 64.0)
		var ex: float = minf(arena_width - 96.0, r.position.x + r.size.x - 64.0)
		var x: float = sx
		while x <= ex:
			var pt := Vector2(x, sy)
			var clear_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(pt + Vector2(0.0, -28.0), pt + Vector2(0.0, 12.0), 1))
			if clear_hit.is_empty():
				candidates.append(pt)
			x += 180.0

	var best_pos: Vector2 = _spawn_points[0]
	var best_min_d: float = -1.0
	for cand in candidates:
		var near_gun: bool = false
		for ce in _crate_nodes:
			if bool(ce.get("active", false)) and str(ce.get("type", "")) == "weapon":
				var ca: Node2D = ce.get("area") as Node2D
				if is_instance_valid(ca) and cand.distance_to(ca.global_position) < 85.0:
					near_gun = true
					break
		if near_gun:
			continue
		var min_d: float = 1e9
		for occ in occupied:
			var d: float = cand.distance_to(occ)
			if d < min_d:
				min_d = d
		if min_d > best_min_d:
			best_min_d = min_d
			best_pos = cand
	return best_pos


const BOT_WORD_A: Array[String] = [
	"Shadow", "Neon", "Iron", "Turbo", "Frost", "Blaze",
	"Ghost", "Cyber", "Storm", "Pixel", "Venom", "Rogue",
	"Nova", "Apex", "Crimson", "Steel", "Lunar", "Solar",
	"Silent", "Hyper", "Rapid", "Cobalt", "Vortex", "Phantom"
]
const BOT_WORD_B: Array[String] = [
	"Fox", "Viper", "Wolf", "Hawk", "Byte", "King",
	"Rider", "Ninja", "Raven", "Titan", "Strike", "Falcon",
	"Knight", "Hunter", "Phoenix", "Spark", "Fang", "Drifter",
	"Sniper", "Blade", "Rex", "Flare", "Arrow", "Bolt"
]
var _used_bot_names: Dictionary = {}


func _generate_bot_username() -> String:
	for _attempt in range(30):
		var cand: String = BOT_WORD_A[randi() % BOT_WORD_A.size()] + BOT_WORD_B[randi() % BOT_WORD_B.size()]
		if not _used_bot_names.has(cand):
			_used_bot_names[cand] = true
			return cand
	var fallback: String = "%s%s%d" % [BOT_WORD_A[randi() % BOT_WORD_A.size()], BOT_WORD_B[randi() % BOT_WORD_B.size()], randi() % 99]
	_used_bot_names[fallback] = true
	return fallback


func _spawn_all_participants() -> void:
	NetworkManager.clear_bot_stats()
	_used_bot_names.clear()
	var peer_ids: Array = NetworkManager.players.keys()
	peer_ids.sort()

	for i in range(peer_ids.size()):
		var pid: int = int(peer_ids[i])
		var pinfo: Dictionary = NetworkManager.players[pid]
		var spawn_pos: Vector2 = _pick_safest_spawn()
		var player := PLAYER_SCENE.instantiate()
		player.name = "Player_%d" % pid
		var p_avatar: Dictionary = pinfo.get("avatar", {})
		if not NetworkManager.is_network_active():
			p_avatar = ProfileManager.to_dict()
		player.setup_player(
			pid,
			str(pinfo.get("name", "Trooper")),
			int(pinfo.get("color_index", i % NetworkManager.TEAM_COLORS.size())),
			false,
			_spawn_points,
			int(pinfo.get("team", i % 2)),
			p_avatar
		)
		player.global_position = spawn_pos
		_players_container.add_child(player)
		if player.is_local_human:
			var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
			if cam != null:
				cam.limit_left = 0
				cam.limit_top = -76
				cam.limit_right = int(arena_width)
				cam.limit_bottom = int(arena_height) + 170
			_hud.bind_local_player(player)

	if NetworkManager.is_shooting_range_mode():
		_init_shooting_range()
		return

	var target_bots: int = clampi(NetworkManager.test_bot_count, 1, NetworkManager.MAX_BOTS) if NetworkManager.is_test_mode() else clampi(NetworkManager.bot_count, 0, NetworkManager.MAX_BOTS)
	if NetworkManager.is_test_mode():
		NetworkManager.test_bot_count = target_bots
	else:
		NetworkManager.bot_count = target_bots
	for b in range(target_bots):
		_spawn_bot(b + 1)


func _on_network_players_updated() -> void:
	if not NetworkManager.is_network_active() or _players_container == null:
		return
	var peer_ids: Array = NetworkManager.players.keys()
	peer_ids.sort()
	for i in range(peer_ids.size()):
		var pid: int = int(peer_ids[i])
		var node_name: String = "Player_%d" % pid
		if _players_container.get_node_or_null(node_name) != null:
			continue
		var pinfo: Dictionary = NetworkManager.players[pid]
		var spawn_pos: Vector2 = _pick_safest_spawn()
		var player := PLAYER_SCENE.instantiate()
		player.name = node_name
		var p_avatar: Dictionary = pinfo.get("avatar", {})
		player.setup_player(
			pid,
			str(pinfo.get("name", "Trooper")),
			int(pinfo.get("color_index", i % NetworkManager.TEAM_COLORS.size())),
			false,
			_spawn_points,
			int(pinfo.get("team", i % 2)),
			p_avatar
		)
		player.global_position = spawn_pos
		_players_container.add_child(player)


func _pick_bot_archetype(bot_index: int) -> int:
	var count: int = ProfileManager.ARCHETYPES.size()
	var default_idx: int = (bot_index * 3 + 1) % count
	if not (NetworkManager.is_test_mode() and NetworkManager.is_agent_clash_mode()):
		return default_idx
	var forced: int = NetworkManager.practice_bot_agent_id
	if forced >= 0:
		return clampi(forced, 0, count - 1)
	# Unique agents: no duplicates among the player and all existing bots
	var used: Dictionary = {}
	if is_instance_valid(_players_container):
		for ch in _players_container.get_children():
			if is_instance_valid(ch) and not ch.is_queued_for_deletion() and "archetype_id" in ch:
				used[int(ch.get("archetype_id"))] = true
	used[ProfileManager.archetype_id] = true
	for k in range(count):
		var cand: int = (default_idx + k) % count
		if not used.has(cand):
			return cand
	return default_idx


func _spawn_bot(bot_index: int) -> void:
	_bot_counter = maxi(_bot_counter, bot_index)
	var bot_id: int = -bot_index
	var max_teams: int = maxi(2, NetworkManager.team_count)
	var bot_team: int = bot_index % max_teams
	var color_idx: int = bot_team if NetworkManager.is_team_mode() else (NetworkManager.local_color_index + bot_index) % NetworkManager.TEAM_COLORS.size()
	var spawn_pos: Vector2 = _pick_safest_spawn()

	var arch_idx: int = _pick_bot_archetype(bot_index)
	var arch: Dictionary = ProfileManager.ARCHETYPES[arch_idx]
	var raw_bot_w: int = int(arch["weapon"]) if (bot_index % 2 == 0) else (bot_index % WeaponData.get_weapon_count())
	var bot_weapon: int = WeaponData.sanitize_weapon_id(raw_bot_w)
	var sec_weapon: int = 9 if WeaponData.is_weapon_allowed(9) else bot_weapon
	var bot_name: String = _generate_bot_username()
	NetworkManager.register_bot_stat(bot_id, bot_name, bot_team)
	var part_idx: int = ProfileManager.get_archetype_part_id(arch_idx)
	var bot_avatar: Dictionary = {
		"archetype_id": arch_idx,
		"skin_id": part_idx,
		"head_id": part_idx,
		"torso_id": part_idx,
		"legs_id": part_idx,
		"hands_id": part_idx,
		"accessories_id": part_idx,
		"shirt_color": arch["shirt"],
		"pants_color": arch["pants"],
		"skin_color": arch["skin"],
		"helmet_color": arch["helmet"],
		"gear_color": arch["gear"],
		"primary_weapon_id": bot_weapon,
		"secondary_weapon_id": sec_weapon,
		"weapon_skin_id": bot_index % ProfileManager.WEAPON_SKIN_NAMES.size(),
		"m4a1_rail_mod": bot_index % ProfileManager.RAIL_MOD_NAMES.size()
	}

	var bot := PLAYER_SCENE.instantiate()
	bot.name = "Bot_%d" % bot_index
	bot.setup_player(
		bot_id,
		bot_name,
		color_idx,
		true,
		_spawn_points,
		bot_team,
		bot_avatar
	)
	bot.global_position = spawn_pos
	_players_container.add_child(bot)
	if not NetworkManager.is_agent_clash_mode() and not NetworkManager.random_guns_mode and bot.has_method("apply_gun_preset"):
		bot.apply_gun_preset(randi() % WeaponData.GUN_PRESETS.size())


func _get_active_bots() -> Array[Node]:
	var out: Array[Node] = []
	for child in _players_container.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion() and child.get("is_bot") == true:
			out.append(child)
	return out


func _on_add_bot_requested() -> void:
	if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
		return
	var cur_bots: int = _get_active_bots().size()
	if cur_bots >= NetworkManager.MAX_BOTS:
		return
	if NetworkManager.is_test_mode():
		NetworkManager.test_bot_count = mini(cur_bots + 1, NetworkManager.MAX_BOTS)
		_spawn_bot(_bot_counter + 1)
		NetworkManager.player_list_updated.emit()
		return
	if NetworkManager.is_network_active():
		spawn_extra_bot_rpc.rpc(_bot_counter + 1)
	else:
		NetworkManager.bot_count = mini(cur_bots + 1, NetworkManager.MAX_BOTS)
		_spawn_bot(_bot_counter + 1)
		NetworkManager.player_list_updated.emit()


func _on_remove_bot_requested() -> void:
	if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
		return
	var bots: Array[Node] = _get_active_bots()
	var min_bots: int = 1 if NetworkManager.is_test_mode() else 0
	if bots.size() <= min_bots:
		return
	var victim: Node = bots.back()
	if NetworkManager.is_test_mode():
		NetworkManager.test_bot_count = maxi(min_bots, bots.size() - 1)
		if is_instance_valid(victim):
			victim.queue_free()
		NetworkManager.player_list_updated.emit()
		return
	if NetworkManager.is_network_active():
		remove_extra_bot_rpc.rpc(victim.name)
	else:
		NetworkManager.bot_count = maxi(0, bots.size() - 1)
		if is_instance_valid(victim):
			victim.queue_free()
		NetworkManager.player_list_updated.emit()


@rpc("authority", "call_local", "reliable")
func remove_extra_bot_rpc(bot_node_name: String) -> void:
	var victim: Node = _players_container.get_node_or_null(bot_node_name)
	if is_instance_valid(victim):
		victim.queue_free()
	NetworkManager.bot_count = maxi(0, _get_active_bots().size() - (1 if is_instance_valid(victim) else 0))
	NetworkManager.player_list_updated.emit()


@rpc("authority", "call_local", "reliable")
func spawn_extra_bot_rpc(bot_index: int) -> void:
	if bot_index > NetworkManager.MAX_BOTS:
		return
	NetworkManager.bot_count = clampi(maxi(NetworkManager.bot_count, bot_index), 0, NetworkManager.MAX_BOTS)
	_spawn_bot(bot_index)
	NetworkManager.player_list_updated.emit()


class GroundWeaponIcon extends Node2D:
	var item_id: int = 0

	func _draw() -> void:
		var item: Dictionary = AgentData.get_throwable(item_id)
		var col: Color = item["color"] as Color
		var style: String = str(item["style"])
		draw_circle(Vector2.ZERO, 16.0, Color(col.r, col.g, col.b, 0.22))
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(1.0, 0.88, 0.35, 0.85), 2.0)
		match style:
			"thrown_axe":
				draw_line(Vector2(-10, 8), Vector2(8, -10), Color(0.50, 0.32, 0.16), 3.5)
				draw_colored_polygon(PackedVector2Array([Vector2(0, -10), Vector2(11, -12), Vector2(12, -1), Vector2(3, -1)]), col)
			"thrown_spear":
				draw_line(Vector2(-12, 10), Vector2(8, -8), Color(0.65, 0.45, 0.22), 3.0)
				draw_colored_polygon(PackedVector2Array([Vector2(14, -14), Vector2(4, -9), Vector2(9, -4)]), col)
			"thrown_hammer":
				draw_line(Vector2(-10, 10), Vector2(6, -6), Color(0.50, 0.32, 0.16), 3.5)
				draw_rect(Rect2(1.0, -13.0, 11.0, 11.0), col)
			"thrown_shoe":
				draw_colored_polygon(PackedVector2Array([
					Vector2(-10, -8), Vector2(0, -8), Vector2(2, 0), Vector2(11, 2), Vector2(11, 9), Vector2(-10, 9)
				]), col)
				draw_rect(Rect2(-10.0, 6.0, 21.0, 3.5), Color(0.18, 0.16, 0.14))
				draw_line(Vector2(-2, -4), Vector2(3, -1), Color.WHITE, 2.0)
			"thrown_stone":
				draw_colored_polygon(PackedVector2Array([
					Vector2(-11, -3), Vector2(-4, -11), Vector2(7, -9), Vector2(12, 1), Vector2(6, 10), Vector2(-7, 9)
				]), col)
				draw_polyline(PackedVector2Array([
					Vector2(-6, -5), Vector2(2, -7), Vector2(7, 0)
				]), col.lightened(0.32), 2.0)
			_:
				draw_line(Vector2(-10, 10), Vector2(10, -10), col, 4.0)
				draw_line(Vector2(-9, 3), Vector2(-3, 9), Color(1.0, 0.82, 0.26), 3.0)
				if bool(item.get("explosive", false)):
					draw_circle(Vector2(6, -6), 4.0, Color(1.0, 0.42, 0.12))


class MapSceneryProp extends Node2D:
	var kind: String = ""

	func _draw() -> void:
		match kind:
			"planet_ringed":
				draw_circle(Vector2.ZERO, 68.0, Color(0.32, 0.48, 0.88, 0.72))
				draw_circle(Vector2(-16, -14), 42.0, Color(0.50, 0.68, 0.98, 0.35))
				draw_set_transform(Vector2.ZERO, -0.35, Vector2(1.0, 0.32))
				draw_arc(Vector2.ZERO, 108.0, 0.0, TAU, 40, Color(0.86, 0.78, 0.56, 0.75), 10.0)
				draw_arc(Vector2.ZERO, 94.0, 0.0, TAU, 36, Color(0.68, 0.60, 0.44, 0.55), 5.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"planet_red":
				draw_circle(Vector2.ZERO, 44.0, Color(0.78, 0.32, 0.24, 0.75))
				draw_circle(Vector2(-12, -10), 10.0, Color(0.52, 0.18, 0.14, 0.55))
				draw_circle(Vector2(14, 12), 7.0, Color(0.52, 0.18, 0.14, 0.55))
			"asteroid":
				draw_colored_polygon(PackedVector2Array([
					Vector2(-22, -8), Vector2(-8, -20), Vector2(14, -16), Vector2(24, 2), Vector2(10, 18), Vector2(-14, 15)
				]), Color(0.42, 0.44, 0.52, 0.85))
				draw_circle(Vector2(-5, -4), 5.0, Color(0.28, 0.30, 0.36, 0.8))
				draw_circle(Vector2(8, 6), 3.5, Color(0.28, 0.30, 0.36, 0.8))
			"palm_tree":
				draw_line(Vector2(0, 0), Vector2(-8, -96), Color(0.42, 0.26, 0.14), 11.0)
				for a in [-2.6, -2.1, -1.5, -0.9, -0.4]:
					var tip := Vector2(-8, -96) + Vector2.from_angle(a) * 48.0
					draw_line(Vector2(-8, -96), tip, Color(0.20, 0.62, 0.24), 10.0)
				draw_circle(Vector2(22, -6), 14.0, Color(0.18, 0.52, 0.20))
				draw_circle(Vector2(-24, -5), 12.0, Color(0.16, 0.46, 0.18))
			"cloud":
				draw_circle(Vector2.ZERO, 28.0, Color(1, 1, 1, 0.55))
				draw_circle(Vector2(-26, 6), 20.0, Color(1, 1, 1, 0.48))
				draw_circle(Vector2(26, 8), 22.0, Color(1, 1, 1, 0.48))
			"snow_pine":
				draw_line(Vector2(0, 0), Vector2(0, -24), Color(0.36, 0.24, 0.16), 8.0)
				draw_colored_polygon(PackedVector2Array([Vector2(-30, -20), Vector2(0, -76), Vector2(30, -20)]), Color(0.16, 0.42, 0.30))
				draw_colored_polygon(PackedVector2Array([Vector2(-22, -48), Vector2(0, -96), Vector2(22, -48)]), Color(0.20, 0.48, 0.36))
				draw_colored_polygon(PackedVector2Array([Vector2(-14, -74), Vector2(0, -104), Vector2(14, -74)]), Color(0.90, 0.96, 1.0))
			"snowflake":
				draw_circle(Vector2.ZERO, 3.2, Color(0.92, 0.98, 1.0, 0.8))
			"torch":
				draw_rect(Rect2(-4, -14, 8, 22), Color(0.36, 0.24, 0.14))
				draw_circle(Vector2(0, -18), 18.0, Color(1.0, 0.58, 0.16, 0.22))
				draw_circle(Vector2(0, -18), 7.5, Color(1.0, 0.52, 0.14, 0.90))
				draw_circle(Vector2(0, -20), 4.0, Color(1.0, 0.92, 0.45, 0.95))


class SwingingPlatform extends Node2D:
	var anchor_pos: Vector2 = Vector2.ZERO
	var rope_length: float = 320.0
	var plat_size: Vector2 = Vector2(180, 26)
	var swing_amp: float = 0.38
	var swing_speed: float = 1.35
	var phase: float = 0.0
	var is_chain: bool = true
	var tile_tex: Texture2D = null

	var _body: AnimatableBody2D
	var _time: float = 0.0

	func _ready() -> void:
		_body = AnimatableBody2D.new()
		_body.sync_to_physics = true
		_body.collision_layer = 1
		_body.collision_mask = 0
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = plat_size
		col.shape = shape
		_body.add_child(col)

		if tile_tex != null:
			var tr := TextureRect.new()
			tr.texture = tile_tex
			tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			tr.stretch_mode = TextureRect.STRETCH_TILE
			var cols: int = maxi(1, int(round(plat_size.x / 32.0)))
			var rows: int = maxi(1, int(round(plat_size.y / 32.0)))
			var snapped_sz := Vector2(float(cols) * 32.0, float(rows) * 32.0)
			tr.position = -plat_size * 0.5
			tr.size = snapped_sz
			tr.scale = Vector2(plat_size.x / snapped_sz.x, plat_size.y / snapped_sz.y)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_body.add_child(tr)
		add_child(_body)
		_update_pendulum(0.0)

	func _physics_process(delta: float) -> void:
		_time += delta
		_update_pendulum(_time)
		queue_redraw()

	func _update_pendulum(t: float) -> void:
		var angle: float = sin(t * swing_speed + phase) * swing_amp
		_body.position = anchor_pos + Vector2(sin(angle), cos(angle)) * rope_length

	func _draw() -> void:
		if _body == null:
			return
		# Roof hook bracket
		draw_rect(Rect2(anchor_pos.x - 14, anchor_pos.y - 6, 28, 12), Color(0.28, 0.30, 0.36))
		draw_circle(anchor_pos, 7.0, Color(0.55, 0.58, 0.65))
		var left_hook: Vector2 = _body.position + Vector2(-plat_size.x * 0.36, -plat_size.y * 0.5)
		var right_hook: Vector2 = _body.position + Vector2(plat_size.x * 0.36, -plat_size.y * 0.5)
		if is_chain:
			_draw_chain(anchor_pos, left_hook)
			_draw_chain(anchor_pos, right_hook)
		else:
			draw_line(anchor_pos, left_hook, Color(0.64, 0.48, 0.28), 5.0)
			draw_line(anchor_pos, right_hook, Color(0.64, 0.48, 0.28), 5.0)
			draw_circle(left_hook, 5.0, Color(0.45, 0.32, 0.18))
			draw_circle(right_hook, 5.0, Color(0.45, 0.32, 0.18))

	func _draw_chain(from_pt: Vector2, to_pt: Vector2) -> void:
		var dist: float = from_pt.distance_to(to_pt)
		var steps: int = maxi(4, int(dist / 16.0))
		var dir: Vector2 = (to_pt - from_pt) / float(steps)
		for i in range(steps):
			var p0: Vector2 = from_pt + dir * float(i)
			var p1: Vector2 = p0 + dir * 0.72
			var col: Color = Color(0.58, 0.62, 0.68) if (i % 2 == 0) else Color(0.36, 0.40, 0.46)
			draw_line(p0, p1, col, 4.5)


class InteractableMissileLauncher extends Node2D:
	const BULLET_SCENE: PackedScene = preload("res://scenes/Bullet.tscn")
	const RESET_COOLDOWN: float = 5.0
	var inter_idx: int = 0
	var launcher_pos: Vector2 = Vector2.ZERO
	var button_pos: Vector2 = Vector2.ZERO
	var shoot_dir: Vector2 = Vector2.RIGHT
	var cooldown_left: float = 0.0
	var _recoil: float = 0.0
	var _flash_t: float = 0.0
	var _btn_area: Area2D

	func _ready() -> void:
		z_index = 4
		_btn_area = Area2D.new()
		_btn_area.position = button_pos
		_btn_area.collision_layer = 0
		_btn_area.collision_mask = 2
		var bcol := CollisionShape2D.new()
		var bshape := CircleShape2D.new()
		bshape.radius = 52.0
		bcol.shape = bshape
		_btn_area.add_child(bcol)
		_btn_area.body_entered.connect(_on_btn_entered)
		_btn_area.body_exited.connect(_on_btn_exited)
		add_child(_btn_area)
		queue_redraw()

	func fire_missile() -> void:
		if cooldown_left > 0.0:
			return
		cooldown_left = RESET_COOLDOWN
		_recoil = 1.0
		_flash_t = 0.16
		var dir: Vector2 = shoot_dir.normalized() if shoot_dir.length() > 0.01 else Vector2.RIGHT
		var world_root: Node = get_parent().get_parent() if get_parent() != null else get_parent()
		if world_root != null:
			var b := BULLET_SCENE.instantiate()
			b.global_position = global_position + launcher_pos + dir * 34.0
			b.velocity = dir * 820.0
			b.damage = 110
			b.shooter_peer_id = 0
			b.shooter_team = -1
			b.shooter_name = "Defense"
			b.weapon_name = "Missile Launcher"
			b.bullet_color = Color(1.0, 0.42, 0.14)
			b.is_explosive = true
			b.explosion_radius = 155.0
			b.visual_style = "rocket"
			b.max_lifetime = 3.2
			b.can_deal_damage = (not NetworkManager.is_network_active()) or NetworkManager.is_host_active()
			world_root.add_child(b)
			var sfx := AudioStreamPlayer2D.new()
			sfx.global_position = global_position + launcher_pos
			var rpg_path: String = "res://assets/audio/RPG Launch.ogg"
			var rpg_stream: AudioStream = (load(rpg_path) as AudioStream) if ResourceLoader.exists(rpg_path) else null
			if rpg_stream == null and FileAccess.file_exists(rpg_path):
				rpg_stream = AudioStreamOggVorbis.load_from_file(rpg_path)
			if rpg_stream is AudioStreamOggVorbis:
				(rpg_stream as AudioStreamOggVorbis).loop = false
			sfx.stream = rpg_stream
			sfx.volume_db = -1.0
			sfx.max_distance = 1800.0
			sfx.bus = &"SFX"
			sfx.finished.connect(sfx.queue_free)
			world_root.add_child(sfx)
			sfx.play()
		for body in _btn_area.get_overlapping_bodies():
			if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
				body.set_nearby_interactable(-1, "")
		queue_redraw()

	func _process(delta: float) -> void:
		var dirty: bool = false
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
			dirty = true
			if cooldown_left <= 0.0:
				for body in _btn_area.get_overlapping_bodies():
					if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
						body.set_nearby_interactable(inter_idx, "USE\nFIRE MISSILE")
		if _recoil > 0.0:
			_recoil = maxf(0.0, _recoil - delta * 4.5)
			dirty = true
		if _flash_t > 0.0:
			_flash_t = maxf(0.0, _flash_t - delta)
			dirty = true
		if dirty:
			queue_redraw()

	func _on_btn_entered(body: Node2D) -> void:
		if cooldown_left <= 0.0 and body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(inter_idx, "USE\nFIRE MISSILE")

	func _on_btn_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(-1, "")

	func _draw() -> void:
		var dir: Vector2 = shoot_dir.normalized() if shoot_dir.length() > 0.01 else Vector2.RIGHT
		var ready: bool = cooldown_left <= 0.0
		var ink := Color(0.06, 0.08, 0.12)
		# Power cable from button to launcher
		draw_line(button_pos, launcher_pos, Color(0.32, 0.36, 0.44, 0.9), 3.0)
		# Control switch box
		var b_rect := Rect2(button_pos.x - 16.0, button_pos.y - 16.0, 32.0, 32.0)
		draw_rect(b_rect, Color(0.14, 0.16, 0.22))
		draw_rect(b_rect, Color(0.55, 0.62, 0.72), false, 2.5)
		var btn_col: Color = Color(1.0, 0.24, 0.18) if ready else Color(0.32, 0.38, 0.48)
		draw_circle(button_pos, 9.0, btn_col)
		draw_arc(button_pos, 9.0, 0.0, TAU, 16, ink, 2.0)

		# Launcher pedestal & armored turret tube
		var lp: Vector2 = launcher_pos - dir * (_recoil * 8.0)
		draw_rect(Rect2(launcher_pos.x - 18.0, launcher_pos.y + 8.0, 36.0, 18.0), Color(0.20, 0.24, 0.30))
		draw_rect(Rect2(launcher_pos.x - 18.0, launcher_pos.y + 8.0, 36.0, 18.0), ink, false, 2.5)
		var ang: float = dir.angle()
		draw_set_transform(lp, ang, Vector2.ONE)
		# Main olive-steel launcher barrel
		draw_rect(Rect2(-24.0, -12.0, 48.0, 24.0), Color(0.26, 0.32, 0.28))
		draw_rect(Rect2(-24.0, -12.0, 48.0, 24.0), ink, false, 3.0)
		# Caution orange stripe on barrel
		draw_rect(Rect2(8.0, -10.0, 10.0, 20.0), Color(0.95, 0.48, 0.14))
		# Loaded missile warhead peeking out when ready
		if ready:
			draw_colored_polygon(PackedVector2Array([
				Vector2(24.0, -8.5), Vector2(38.0, 0.0), Vector2(24.0, 8.5)
			]), Color(0.95, 0.26, 0.18))
			draw_polyline(PackedVector2Array([
				Vector2(24.0, -8.5), Vector2(38.0, 0.0), Vector2(24.0, 8.5), Vector2(24.0, -8.5)
			]), ink, 2.2)
		if _flash_t > 0.0:
			var fa: float = clampf(_flash_t / 0.16, 0.0, 1.0)
			draw_circle(Vector2(30.0, 0.0), 16.0 * fa, Color(1.0, 0.65, 0.18, fa * 0.9))
			draw_circle(Vector2(28.0, 0.0), 8.0 * fa, Color(1.0, 0.96, 0.72, fa))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# 5-second reload progress bar above launcher while resetting
		if not ready:
			var prog: float = clampf(1.0 - (cooldown_left / RESET_COOLDOWN), 0.0, 1.0)
			var bar_r := Rect2(launcher_pos.x - 22.0, launcher_pos.y - 24.0, 44.0, 6.0)
			draw_rect(bar_r, Color(0.08, 0.10, 0.14, 0.9))
			draw_rect(Rect2(bar_r.position.x + 1.0, bar_r.position.y + 1.0, 42.0 * prog, 4.0), Color(1.0, 0.65, 0.18))
			draw_rect(bar_r, ink, false, 1.5)


class InteractableFan extends Node2D:
	var inter_idx: int = 0
	var fan_pos: Vector2 = Vector2.ZERO
	var button_pos: Vector2 = Vector2.ZERO
	var push_dir: Vector2 = Vector2.UP
	var push_force: float = 1950.0
	var beam_length: float = 420.0
	var beam_width: float = 96.0
	var is_on: bool = false

	var _wind_area: Area2D
	var _btn_area: Area2D
	var _spin: float = 0.0
	var _wind_time: float = 0.0

	func _ready() -> void:
		# Wind push zone
		_wind_area = Area2D.new()
		_wind_area.position = fan_pos + push_dir.normalized() * (beam_length * 0.5)
		_wind_area.collision_layer = 0
		_wind_area.collision_mask = 2
		var w_cs := CollisionShape2D.new()
		var w_box := RectangleShape2D.new()
		if absf(push_dir.y) > absf(push_dir.x):
			w_box.size = Vector2(beam_width, beam_length)
		else:
			w_box.size = Vector2(beam_length, beam_width)
		w_cs.shape = w_box
		_wind_area.add_child(w_cs)
		add_child(_wind_area)

		# Wall switch trigger zone
		_btn_area = Area2D.new()
		_btn_area.position = button_pos
		_btn_area.collision_layer = 0
		_btn_area.collision_mask = 2
		var b_cs := CollisionShape2D.new()
		var b_box := RectangleShape2D.new()
		b_box.size = Vector2(54, 54)
		b_cs.shape = b_box
		_btn_area.add_child(b_cs)
		_btn_area.body_entered.connect(_on_btn_entered)
		_btn_area.body_exited.connect(_on_btn_exited)
		add_child(_btn_area)

	func set_fan_state(state: bool) -> void:
		is_on = state
		for b in _btn_area.get_overlapping_bodies():
			if b.is_in_group("players") and b.get("is_local_human") == true and b.has_method("set_nearby_interactable"):
				b.set_nearby_interactable(inter_idx, "USE\nFAN OFF" if is_on else "USE\nFAN ON")
		queue_redraw()

	func _on_btn_entered(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(inter_idx, "USE\nFAN OFF" if is_on else "USE\nFAN ON")

	func _on_btn_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			if int(body.get("nearby_interactable_idx")) == inter_idx:
				body.set_nearby_interactable(-1, "")

	func _physics_process(delta: float) -> void:
		if is_on:
			_spin += delta * 18.0
			_wind_time += delta
			var dir_n: Vector2 = push_dir.normalized()
			for b in _wind_area.get_overlapping_bodies():
				if b.is_in_group("players") and (not b.has_method("is_alive") or b.is_alive()):
					if b is CharacterBody2D:
						var cb := b as CharacterBody2D
						cb.velocity += dir_n * push_force * delta
						if dir_n.y < -0.5:
							cb.velocity.y = clampf(cb.velocity.y, -780.0, 420.0)
						else:
							cb.velocity.x = clampf(cb.velocity.x, -820.0, 820.0)
			var w_half: Vector2 = Vector2(beam_width * 0.5, beam_length * 0.5) if absf(push_dir.y) > absf(push_dir.x) else Vector2(beam_length * 0.5, beam_width * 0.5)
			var w_rect := Rect2(_wind_area.position - w_half, w_half * 2.0)
			for s in get_tree().get_nodes_in_group("agent_summons"):
				if is_instance_valid(s) and s is Node2D and w_rect.has_point((s as Node2D).global_position) and s.has_method("apply_fan_wind"):
					s.apply_fan_wind(dir_n, push_force, delta)
			queue_redraw()

	func _draw() -> void:
		# Conduit wire connecting button to fan
		draw_line(button_pos, fan_pos, Color(0.24, 0.28, 0.34, 0.85), 3.0)
		# Wall switch box
		draw_rect(Rect2(button_pos - Vector2(14, 18), Vector2(28, 36)), Color(0.20, 0.24, 0.30))
		draw_rect(Rect2(button_pos - Vector2(14, 18), Vector2(28, 36)), Color(0.55, 0.62, 0.72), false, 2.0)
		var led_col: Color = Color(0.22, 1.0, 0.42) if is_on else Color(1.0, 0.25, 0.22)
		draw_circle(button_pos + Vector2(0, -6), 6.0, led_col)
		draw_rect(Rect2(button_pos + Vector2(-7, 4), Vector2(14, 8)), Color(0.75, 0.80, 0.88))

		# Fan housing (oriented perpendicular to push_dir)
		var half_w: float = beam_width * 0.44
		var is_side_fan: bool = absf(push_dir.x) > absf(push_dir.y)
		var housing_rect: Rect2 = Rect2(fan_pos - Vector2(12, half_w), Vector2(24, half_w * 2.0)) if is_side_fan else Rect2(fan_pos - Vector2(half_w, 12), Vector2(half_w * 2.0, 24))
		draw_rect(housing_rect, Color(0.22, 0.26, 0.32))
		draw_rect(housing_rect, Color(0.58, 0.64, 0.72), false, 2.5)
		# Spinning fan blades
		for k in range(3):
			var b_off: float = sin(_spin + float(k) * 2.1) * (half_w * 0.75)
			if is_side_fan:
				draw_line(fan_pos + Vector2(-8, b_off), fan_pos + Vector2(8, b_off), Color(0.75, 0.82, 0.90), 5.0)
			else:
				draw_line(fan_pos + Vector2(b_off, -8), fan_pos + Vector2(b_off, 8), Color(0.75, 0.82, 0.90), 5.0)

		# Air stream streaks when ON
		if is_on:
			var dir_n: Vector2 = push_dir.normalized()
			var perp: Vector2 = Vector2(-dir_n.y, dir_n.x)
			for s in range(6):
				var lane: float = (float(s) - 2.5) * (beam_width * 0.14)
				var frac: float = fmod(_wind_time * 2.4 + float(s) * 0.19, 1.0)
				var p0: Vector2 = fan_pos + perp * lane + dir_n * (frac * (beam_length - 48.0))
				var p1: Vector2 = p0 + dir_n * 44.0
				draw_line(p0, p1, Color(0.72, 0.94, 1.0, 0.55), 3.0)


class InteractableHealStation extends Node2D:
	var inter_idx: int = 0
	var cooldown_left: float = 0.0
	var _area: Area2D

	func _ready() -> void:
		_area = Area2D.new()
		_area.collision_layer = 0
		_area.collision_mask = 2
		var cs := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(60, 60)
		cs.shape = box
		_area.add_child(cs)
		_area.body_entered.connect(_on_entered)
		_area.body_exited.connect(_on_exited)
		add_child(_area)

	func trigger_cooldown() -> void:
		cooldown_left = 12.0
		queue_redraw()

	func _process(delta: float) -> void:
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
			if cooldown_left <= 0.0:
				queue_redraw()

	func _on_entered(body: Node2D) -> void:
		if cooldown_left <= 0.0 and body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(inter_idx, "USE\nHEAL")

	func _on_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			if int(body.get("nearby_interactable_idx")) == inter_idx:
				body.set_nearby_interactable(-1, "")

	func _draw() -> void:
		var ready: bool = cooldown_left <= 0.0
		draw_rect(Rect2(-18, -26, 36, 52), Color(0.14, 0.20, 0.26))
		draw_rect(Rect2(-18, -26, 36, 52), Color(0.32, 0.92, 0.58) if ready else Color(0.45, 0.45, 0.50), false, 2.5)
		var cross_col: Color = Color(0.25, 1.0, 0.52) if ready else Color(0.42, 0.45, 0.50)
		draw_rect(Rect2(-4, -14, 8, 22), cross_col)
		draw_rect(Rect2(-11, -7, 22, 8), cross_col)


class InteractableTreasureBox extends Node2D:
	var inter_idx: int = 0
	var cooldown_left: float = 0.0
	var _pulse_t: float = 0.0
	var _lbl: Label

	func _ready() -> void:
		z_index = -1
		_lbl = Label.new()
		_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lbl.position = Vector2(-36, -42)
		_lbl.custom_minimum_size = Vector2(72, 20)
		_lbl.add_theme_font_size_override("font_size", 12)
		_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		_lbl.add_theme_constant_override("outline_size", 3)
		add_child(_lbl)
		_update_label()
		queue_redraw()

	func trigger_opened() -> void:
		cooldown_left = 30.0
		_update_label()
		queue_redraw()

	func _process(delta: float) -> void:
		_pulse_t += delta
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
			_update_label()
		queue_redraw()

	func _update_label() -> void:
		if not is_instance_valid(_lbl):
			return
		if cooldown_left <= 0.0:
			_lbl.text = "TREASURE"
			_lbl.modulate = Color(1.0, 0.88, 0.30)
		else:
			_lbl.text = "%ds" % int(ceil(cooldown_left))
			_lbl.modulate = Color(0.65, 0.70, 0.78)

	func _draw() -> void:
		var ready: bool = cooldown_left <= 0.0
		if ready:
			var breath: float = 0.5 + 0.5 * sin(_pulse_t * 3.2)
			var glow_r: float = 31.0 + breath * 10.0
			var glow_a: float = 0.12 + breath * 0.14
			draw_circle(Vector2(0, -2), glow_r, Color(1.0, 0.82, 0.22, glow_a))
			draw_arc(Vector2(0, -2), glow_r, 0.0, TAU, 36, Color(1.0, 0.88, 0.35, 0.28 + breath * 0.35), 2.0)
			draw_rect(Rect2(-24, -18, 48, 36), Color(0.48, 0.28, 0.12))
			draw_rect(Rect2(-24, -18, 48, 12), Color(0.62, 0.38, 0.16))
			draw_rect(Rect2(-24, -18, 48, 36), Color(1.0, 0.84, 0.28), false, 3.0)
			draw_line(Vector2(-24, -6), Vector2(24, -6), Color(1.0, 0.84, 0.28), 3.0)
			draw_rect(Rect2(-5, -10, 10, 10), Color(1.0, 0.90, 0.35))
		else:
			draw_rect(Rect2(-24, -6, 48, 24), Color(0.28, 0.18, 0.10, 0.65))
			draw_rect(Rect2(-24, -6, 48, 24), Color(0.45, 0.42, 0.36, 0.75), false, 2.0)


class InteractableProp extends Node2D:
	const EXPLOSION_SCENE: PackedScene = preload("res://scenes/Explosion.tscn")
	var inter_idx: int = 0
	var prop_kind: String = "chair"
	var is_available: bool = true
	var _respawn_timer: float = 0.0
	var _area: Area2D
	var _hit_body: StaticBody2D
	var _hit_col: CollisionShape2D

	func _ready() -> void:
		_area = Area2D.new()
		_area.collision_layer = 0
		_area.collision_mask = 2
		var cs := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(52, 52)
		cs.shape = box
		_area.add_child(cs)
		_area.body_entered.connect(_on_entered)
		_area.body_exited.connect(_on_exited)
		add_child(_area)

		if prop_kind == "barrel":
			_hit_body = StaticBody2D.new()
			_hit_body.collision_layer = 3
			_hit_body.collision_mask = 0
			_hit_body.add_to_group("destructible_bombs")
			_hit_body.set_meta("prop_node", self)
			_hit_col = CollisionShape2D.new()
			var h_box := RectangleShape2D.new()
			h_box.size = Vector2(44, 66)
			_hit_col.shape = h_box
			_hit_col.one_way_collision = true
			_hit_col.position = Vector2(0, -13)
			_hit_body.add_child(_hit_col)
			add_child(_hit_body)

	func detonate_barrel(attacker_id: int = 0, attacker_name: String = "", attacker_team: int = -1) -> void:
		if not is_available or prop_kind != "barrel":
			return
		if NetworkManager.is_network_active():
			var local_id: int = NetworkManager.get_local_peer_id()
			var is_auth_caller: bool = (attacker_id == local_id) or (attacker_id <= 0 and NetworkManager.is_host_active())
			if is_auth_caller:
				NetworkManager.detonate_barrel(inter_idx, attacker_id, attacker_name, attacker_team)
			return
		detonate_barrel_local(attacker_id, attacker_name, attacker_team)

	func detonate_barrel_local(attacker_id: int = 0, attacker_name: String = "", attacker_team: int = -1) -> void:
		if not is_available or prop_kind != "barrel":
			return
		is_available = false
		_respawn_timer = 12.0
		if _hit_col != null:
			_hit_col.set_deferred("disabled", true)
		queue_redraw()
		var world_node: Node = get_parent()
		if world_node != null:
			var exp := EXPLOSION_SCENE.instantiate()
			exp.global_position = global_position + Vector2(0, -14)
			exp.explosion_radius = 165.0
			exp.max_damage = 120
			exp.shooter_peer_id = attacker_id
			exp.shooter_name = attacker_name if not attacker_name.is_empty() else "Explosive Barrel"
			exp.shooter_team = attacker_team
			exp.weapon_name = "Explosive Barrel"
			exp.allow_self_damage = true
			exp.can_deal_damage = (not NetworkManager.is_network_active()) or (attacker_id == NetworkManager.get_local_peer_id()) or (attacker_id <= 0 and NetworkManager.is_host_active())
			world_node.add_child(exp)

	func pick_up_prop() -> void:
		is_available = false
		_respawn_timer = 10.0
		if _hit_col != null:
			_hit_col.set_deferred("disabled", true)
		queue_redraw()

	func _process(delta: float) -> void:
		if not is_available:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				is_available = true
				if _hit_col != null:
					_hit_col.set_deferred("disabled", false)
				queue_redraw()

	func _on_entered(body: Node2D) -> void:
		if is_available and body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(inter_idx, "PICK")

	func _on_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			if int(body.get("nearby_interactable_idx")) == inter_idx:
				body.set_nearby_interactable(-1, "")

	func _draw() -> void:
		if not is_available:
			return
		match prop_kind:
			"chair":
				draw_line(Vector2(-16, -28), Vector2(-16, 20), Color(0.55, 0.60, 0.68), 6.0)
				draw_line(Vector2(-16, -2), Vector2(18, -2), Color(0.55, 0.60, 0.68), 6.0)
				draw_line(Vector2(15, -2), Vector2(15, 20), Color(0.55, 0.60, 0.68), 6.0)
				draw_rect(Rect2(-18, -28, 8, 24), Color(0.28, 0.45, 0.72))
				draw_rect(Rect2(-16, -6, 35, 8), Color(0.28, 0.45, 0.72))
			"wood":
				draw_rect(Rect2(-14, -6, 28, 12), Color(0.46, 0.28, 0.14))
				draw_rect(Rect2(-14, -6, 28, 12), Color(0.24, 0.14, 0.07), false, 2.0)
				draw_line(Vector2(-8, -2), Vector2(8, -2), Color(0.62, 0.40, 0.22), 2.0)
				draw_circle(Vector2(12, 0), 4.5, Color(0.76, 0.58, 0.34))
			"coconut":
				draw_circle(Vector2.ZERO, 10.0, Color(0.40, 0.24, 0.12))
				draw_circle(Vector2(-3, -3), 3.0, Color(0.54, 0.34, 0.18))
			"barrel":
				draw_rect(Rect2(-22, -46, 44, 66), Color(0.82, 0.20, 0.16))
				draw_rect(Rect2(-22, -46, 44, 66), Color(0.20, 0.22, 0.26), false, 3.0)
				draw_line(Vector2(-22, -24), Vector2(22, -24), Color(0.95, 0.76, 0.20), 6.0)
				draw_line(Vector2(-22, -2), Vector2(22, -2), Color(0.30, 0.34, 0.40), 4.5)
			"pot":
				draw_circle(Vector2(0, 2), 10.5, Color(0.10, 0.14, 0.20))
				draw_circle(Vector2(0, 2), 9.0, Color(0.16, 0.62, 0.72))
				draw_rect(Rect2(-6, -11, 12, 6), Color(0.12, 0.48, 0.58))
				draw_rect(Rect2(-7, -12, 14, 3.5), Color(0.96, 0.78, 0.24))
			"stone":
				draw_rect(Rect2(-11, -9, 22, 18), Color(0.54, 0.52, 0.48))
				draw_rect(Rect2(-11, -9, 22, 18), Color(0.30, 0.28, 0.25), false, 2.0)
			"ice_block":
				draw_rect(Rect2(-11, -11, 22, 22), Color(0.62, 0.88, 1.0, 0.88))
				draw_rect(Rect2(-11, -11, 22, 22), Color(0.92, 0.98, 1.0), false, 2.0)
			"crate":
				draw_rect(Rect2(-11, -11, 22, 22), Color(0.26, 0.34, 0.46))
				draw_rect(Rect2(-11, -11, 22, 22), Color(0.38, 0.86, 0.98), false, 2.0)


class UltPointPickup extends Area2D:
	var arena_ref: Node2D = null
	var ult_idx: int = -1
	var _pulse: float = 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 22.0
		cs.shape = circ
		add_child(cs)
		body_entered.connect(_on_body_entered)

	func relocate_random() -> void:
		if arena_ref == null:
			return
		var w: float = float(arena_ref.get("arena_width"))
		var h: float = float(arena_ref.get("arena_height"))
		var raw := Vector2(randf_range(120.0, w - 120.0), randf_range(120.0, h - 100.0))
		position = arena_ref.call("_snap_to_floor", raw, 18.0, true)

	func _process(delta: float) -> void:
		_pulse += delta * 4.0
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if body.is_in_group("players") and body.has_method("can_collect_ult_point") and body.can_collect_ult_point():
			var is_local_actor: bool = (body.get("is_local_human") == true) or (body.get("is_bot") == true and (not NetworkManager.is_network_active() or NetworkManager.is_host_active()))
			if not is_local_actor:
				return
			body.collect_ult_point()
			if NetworkManager.is_network_active() and ult_idx >= 0 and arena_ref != null:
				var w: float = float(arena_ref.get("arena_width"))
				var h: float = float(arena_ref.get("arena_height"))
				var raw := Vector2(randf_range(120.0, w - 120.0), randf_range(120.0, h - 100.0))
				var snapped: Vector2 = arena_ref.call("_snap_to_floor", raw, 18.0, true)
				NetworkManager.relocate_ult_pickup(ult_idx, snapped)
			else:
				call_deferred("relocate_random")

	func _draw() -> void:
		var glow: float = 0.72 + 0.28 * sin(_pulse)
		draw_circle(Vector2.ZERO, 17.0, Color(0.95, 0.72, 0.18, 0.24 * glow))
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 24, Color(1.0, 0.84, 0.24, 0.92), 2.5)
		var pts := PackedVector2Array()
		for i in range(8):
			var ang: float = float(i) * PI * 0.25 - PI * 0.5
			var r: float = 11.0 if i % 2 == 0 else 5.0
			pts.append(Vector2.from_angle(ang) * r)
		draw_colored_polygon(pts, Color(1.0, 0.88, 0.30, 0.98))


class InteractableJumpPad extends Area2D:
	var pad_color: Color = Color(1.0, 0.52, 0.16)
	var launch_vel: Vector2 = Vector2(0.0, -860.0)
	var _pulse: float = 0.0
	var _cd_by_body: Dictionary = {}

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(64, 24)
		cs.shape = box
		add_child(cs)
		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		_pulse += delta * 5.0
		for k in _cd_by_body.keys():
			_cd_by_body[k] = float(_cd_by_body[k]) - delta
			if float(_cd_by_body[k]) <= 0.0:
				_cd_by_body.erase(k)
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if not body.is_in_group("players") or (body.has_method("is_alive") and not body.is_alive()):
			return
		var id: int = body.get_instance_id()
		if _cd_by_body.has(id):
			return
		_cd_by_body[id] = 0.45
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity.y = launch_vel.y
			(body as CharacterBody2D).velocity.x += launch_vel.x
		_pulse = 0.0

	func _draw() -> void:
		var glow: float = 0.65 + 0.35 * sin(_pulse)
		draw_rect(Rect2(-30, -4, 60, 12), Color(0.16, 0.19, 0.26))
		draw_rect(Rect2(-30, -4, 60, 12), pad_color, false, 2.0)
		draw_rect(Rect2(-24, -10, 48, 6), Color(pad_color.r, pad_color.g, pad_color.b, 0.88 * glow))
		draw_line(Vector2(-12, -16 - 4.0 * glow), Vector2(0, -24 - 4.0 * glow), pad_color, 2.5)
		draw_line(Vector2(12, -16 - 4.0 * glow), Vector2(0, -24 - 4.0 * glow), pad_color, 2.5)


class InteractableTeleporter extends Area2D:
	var inter_idx: int = 0
	var target_pos: Vector2 = Vector2.ZERO
	var portal_color: Color = Color(1.0, 0.78, 0.20)
	var cooldown_left: float = 0.0
	var _pulse: float = 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 30.0
		cs.shape = circ
		add_child(cs)
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	func trigger_cooldown() -> void:
		cooldown_left = 3.0
		queue_redraw()

	func _process(delta: float) -> void:
		_pulse += delta * 4.5
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(inter_idx, "USE\nTELEPORT" if cooldown_left <= 0.0 else "CHARGING...")

	func _on_body_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(-1, "")

	func _draw() -> void:
		var ready_col: Color = portal_color if cooldown_left <= 0.0 else Color(0.42, 0.46, 0.54)
		draw_circle(Vector2.ZERO, 24.0, Color(ready_col.r, ready_col.g, ready_col.b, 0.22 + 0.12 * sin(_pulse)))
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, ready_col, 3.0)
		draw_arc(Vector2.ZERO, 13.0, _pulse, _pulse + PI * 1.35, 16, Color.WHITE, 2.2)


class InteractableBoostShrine extends Area2D:
	var inter_idx: int = 0
	var shrine_kind: String = "speed"
	var shrine_color: Color = Color(0.74, 0.36, 1.0)
	var cooldown_left: float = 0.0
	var _pulse: float = 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 30.0
		cs.shape = circ
		add_child(cs)
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	func trigger_cooldown() -> void:
		cooldown_left = 10.0
		queue_redraw()

	func _process(delta: float) -> void:
		_pulse += delta * 3.5
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
		queue_redraw()

	func _on_body_entered(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			var lbl: String = "USE\nSPEED" if shrine_kind == "speed" else "USE\nSUPPLY"
			body.set_nearby_interactable(inter_idx, lbl if cooldown_left <= 0.0 else "CHARGING...")

	func _on_body_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(-1, "")

	func _draw() -> void:
		var c: Color = shrine_color if cooldown_left <= 0.0 else Color(0.40, 0.44, 0.50)
		draw_rect(Rect2(-16, -22, 32, 44), Color(0.12, 0.15, 0.22, 0.92))
		draw_rect(Rect2(-16, -22, 32, 44), c, false, 2.5)
		draw_circle(Vector2(0, -4), 9.0 + 1.5 * sin(_pulse), Color(c.r, c.g, c.b, 0.85))


class InteractableSwitchHazard extends Area2D:
	var inter_idx: int = 0
	var hazard_kind: String = "spikes"
	var hazard_color: Color = Color(0.95, 0.30, 0.28)
	var is_active: bool = false
	var active_left: float = 0.0
	var cooldown_left: float = 0.0
	var _pulse: float = 0.0
	var _tick_accum: float = 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 44.0
		cs.shape = circ
		add_child(cs)
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	func activate_hazard() -> void:
		is_active = true
		active_left = 3.5
		cooldown_left = 8.0
		_tick_accum = 0.0
		_apply_hazard_pulse()
		queue_redraw()

	func _process(delta: float) -> void:
		_pulse += delta * 5.0
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
		if is_active:
			active_left -= delta
			_tick_accum += delta
			if _tick_accum >= 0.45:
				_tick_accum = 0.0
				_apply_hazard_pulse()
			if active_left <= 0.0:
				is_active = false
		queue_redraw()

	func _apply_hazard_pulse() -> void:
		var rad: float = 190.0 if hazard_kind in ["solar_flare", "low_g", "sentry"] else 135.0
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p) or (p.has_method("is_alive") and not p.is_alive()):
				continue
			var d: float = global_position.distance_to((p as Node2D).global_position)
			if d > rad:
				continue
			match hazard_kind:
				"spikes":
					if p.has_method("apply_hit"):
						p.apply_hit(22, 0, "Spike Trap", "Arena", Vector2(0.0, -240.0))
				"laser":
					if p.has_method("apply_hit"):
						p.apply_hit(26, 0, "Laser Gate", "Arena", Vector2(0.0, -140.0))
				"solar_flare":
					var push_d: Vector2 = ((p as Node2D).global_position - global_position).normalized()
					if p.has_method("apply_hit"):
						p.apply_hit(20, 0, "Solar Altar", "Arena", push_d * 420.0 + Vector2(0.0, -180.0))
				"cryo_vent":
					if p.has_method("apply_status"):
						p.apply_status("freeze", 2.0)
				"sentry":
					if p.has_method("apply_hit"):
						p.apply_hit(24, 0, "Sentry Turret", "Arena", Vector2(0.0, -120.0))
				"low_g":
					if p is CharacterBody2D:
						(p as CharacterBody2D).velocity.y = -520.0
				"spore_cloud":
					if p.has_method("apply_status"):
						p.apply_status("poison", 3.0)

	func _on_body_entered(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			var lbl: String = "USE\n" + hazard_kind.replace("_", " ").to_upper()
			body.set_nearby_interactable(inter_idx, lbl if (cooldown_left <= 0.0 and not is_active) else "CHARGING...")

	func _on_body_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(-1, "")

	func _draw() -> void:
		var c: Color = hazard_color if (is_active or cooldown_left <= 0.0) else Color(0.42, 0.46, 0.54)
		draw_rect(Rect2(-18, -14, 36, 28), Color(0.12, 0.14, 0.20, 0.92))
		draw_rect(Rect2(-18, -14, 36, 28), c, false, 2.5)
		draw_circle(Vector2(0, -4), 6.0, c if is_active else Color(0.95, 0.24, 0.24))
		if is_active:
			var rad: float = 190.0 if hazard_kind in ["solar_flare", "low_g", "sentry"] else 135.0
			draw_circle(Vector2.ZERO, rad, Color(c.r, c.g, c.b, 0.16 + 0.08 * sin(_pulse)))
			draw_arc(Vector2.ZERO, rad, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.85), 3.0)


class InteractableDoor extends Node2D:
	var inter_idx: int = 0
	var door_pos: Vector2 = Vector2.ZERO
	var button_pos: Vector2 = Vector2.ZERO
	var is_open: bool = false

	var _door_body: StaticBody2D
	var _door_shape: CollisionShape2D
	var _btn_area: Area2D
	var _open_anim: float = 0.0

	func _ready() -> void:
		_door_body = StaticBody2D.new()
		_door_body.position = door_pos
		_door_body.collision_layer = 1
		_door_body.collision_mask = 0
		_door_shape = CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(36, 180)
		_door_shape.shape = box
		_door_body.add_child(_door_shape)
		add_child(_door_body)

		_btn_area = Area2D.new()
		_btn_area.position = button_pos
		_btn_area.collision_layer = 0
		_btn_area.collision_mask = 2
		var b_cs := CollisionShape2D.new()
		var b_box := RectangleShape2D.new()
		b_box.size = Vector2(54, 54)
		b_cs.shape = b_box
		_btn_area.add_child(b_cs)
		_btn_area.body_entered.connect(_on_btn_entered)
		_btn_area.body_exited.connect(_on_btn_exited)
		add_child(_btn_area)

	func set_door_state(open_state: bool) -> void:
		is_open = open_state
		if is_instance_valid(_door_shape):
			_door_shape.set_deferred("disabled", is_open)
		for b in _btn_area.get_overlapping_bodies():
			if b.is_in_group("players") and b.get("is_local_human") == true and b.has_method("set_nearby_interactable"):
				b.set_nearby_interactable(inter_idx, "USE\nCLOSE DOOR" if is_open else "USE\nOPEN DOOR")
		queue_redraw()

	func _process(delta: float) -> void:
		var target: float = 1.0 if is_open else 0.0
		if absf(_open_anim - target) > 0.01:
			_open_anim = move_toward(_open_anim, target, delta * 3.5)
			queue_redraw()

	func _on_btn_entered(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(inter_idx, "USE\nCLOSE DOOR" if is_open else "USE\nOPEN DOOR")

	func _on_btn_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(-1, "")

	func _draw() -> void:
		draw_line(button_pos, door_pos, Color(0.24, 0.28, 0.36, 0.85), 3.0)
		# Door frame
		draw_rect(Rect2(door_pos.x - 22, door_pos.y - 96, 44, 10), Color(0.22, 0.24, 0.30))
		# Sliding dungeon gate
		var gate_h: float = 180.0 * (1.0 - _open_anim * 0.88)
		var gate_rect := Rect2(door_pos.x - 18, door_pos.y - 90, 36, gate_h)
		draw_rect(gate_rect, Color(0.28, 0.20, 0.14))
		draw_rect(gate_rect, Color(0.55, 0.60, 0.68), false, 3.0)
		for bx in [-10.0, 0.0, 10.0]:
			draw_line(Vector2(door_pos.x + bx, door_pos.y - 90), Vector2(door_pos.x + bx, door_pos.y - 90 + gate_h), Color(0.62, 0.68, 0.76), 2.5)
		# Switch box
		draw_rect(Rect2(button_pos.x - 14, button_pos.y - 20, 28, 40), Color(0.18, 0.20, 0.26))
		draw_rect(Rect2(button_pos.x - 14, button_pos.y - 20, 28, 40), Color(0.65, 0.72, 0.85), false, 2.0)
		draw_circle(button_pos + Vector2(0, -6), 7.5, Color(0.22, 0.95, 0.42) if is_open else Color(0.95, 0.24, 0.24))


class InteractableSpikeTrap extends Node2D:
	var inter_idx: int = 0
	var trap_pos: Vector2 = Vector2.ZERO
	var button_pos: Vector2 = Vector2.ZERO
	var is_on: bool = false

	var _spike_area: Area2D
	var _btn_area: Area2D
	var _extend: float = 0.0
	var _hit_cd_by_body: Dictionary = {}

	func _ready() -> void:
		_spike_area = Area2D.new()
		_spike_area.position = trap_pos + Vector2(0, -14)
		_spike_area.collision_layer = 0
		_spike_area.collision_mask = 2
		var s_cs := CollisionShape2D.new()
		var s_box := RectangleShape2D.new()
		s_box.size = Vector2(144, 34)
		s_cs.shape = s_box
		_spike_area.add_child(s_cs)
		add_child(_spike_area)

		_btn_area = Area2D.new()
		_btn_area.position = button_pos
		_btn_area.collision_layer = 0
		_btn_area.collision_mask = 2
		var b_cs := CollisionShape2D.new()
		var b_box := RectangleShape2D.new()
		b_box.size = Vector2(54, 54)
		b_cs.shape = b_box
		_btn_area.add_child(b_cs)
		_btn_area.body_entered.connect(_on_btn_entered)
		_btn_area.body_exited.connect(_on_btn_exited)
		add_child(_btn_area)

	func set_trap_state(on_state: bool) -> void:
		is_on = on_state
		for b in _btn_area.get_overlapping_bodies():
			if b.is_in_group("players") and b.get("is_local_human") == true and b.has_method("set_nearby_interactable"):
				b.set_nearby_interactable(inter_idx, "USE\nSPIKES OFF" if is_on else "USE\nSPIKES ON")
		queue_redraw()

	func _physics_process(delta: float) -> void:
		var target: float = 1.0 if is_on else 0.0
		if absf(_extend - target) > 0.01:
			_extend = move_toward(_extend, target, delta * 5.0)
			queue_redraw()
		for k in _hit_cd_by_body.keys():
			_hit_cd_by_body[k] = float(_hit_cd_by_body[k]) - delta
			if float(_hit_cd_by_body[k]) <= 0.0:
				_hit_cd_by_body.erase(k)
		if not is_on or _extend < 0.35:
			return
		for body in _spike_area.get_overlapping_bodies():
			if not body.is_in_group("players") or (body.has_method("is_alive") and not body.is_alive()):
				continue
			var bid: int = body.get_instance_id()
			if _hit_cd_by_body.has(bid):
				continue
			_hit_cd_by_body[bid] = 0.55
			if body.has_method("apply_hit"):
				body.apply_hit(28, 0, "Dungeon Spikes", "Arena", Vector2(0.0, -340.0))

	func _on_btn_entered(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(inter_idx, "USE\nSPIKES OFF" if is_on else "USE\nSPIKES ON")

	func _on_btn_exited(body: Node2D) -> void:
		if body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(-1, "")

	func _draw() -> void:
		draw_line(button_pos, trap_pos, Color(0.24, 0.28, 0.36, 0.85), 3.0)
		# Floor spike base plate
		draw_rect(Rect2(trap_pos.x - 74, trap_pos.y - 4, 148, 10), Color(0.20, 0.22, 0.28))
		draw_rect(Rect2(trap_pos.x - 74, trap_pos.y - 4, 148, 10), Color(0.50, 0.54, 0.62), false, 2.0)
		# Actual sharp steel triangular spikes emerging when toggled ON
		var sp_h: float = 28.0 * _extend
		if sp_h > 1.0:
			for i in range(8):
				var cx: float = trap_pos.x - 63.0 + float(i) * 18.0
				var base_y: float = trap_pos.y - 4.0
				var tip_y: float = base_y - sp_h
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx - 7.5, base_y), Vector2(cx, tip_y), Vector2(cx + 7.5, base_y)
				]), Color(0.76, 0.80, 0.88))
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx - 2.5, lerpf(base_y, tip_y, 0.65)), Vector2(cx, tip_y), Vector2(cx + 2.5, lerpf(base_y, tip_y, 0.65))
				]), Color(0.92, 0.24, 0.24))
		# Switch box
		draw_rect(Rect2(button_pos.x - 14, button_pos.y - 20, 28, 40), Color(0.18, 0.20, 0.26))
		draw_rect(Rect2(button_pos.x - 14, button_pos.y - 20, 28, 40), Color(0.65, 0.72, 0.85), false, 2.0)
		draw_circle(button_pos + Vector2(0, -6), 7.5, Color(0.22, 0.95, 0.42) if is_on else Color(0.95, 0.24, 0.24))


class ArenaAutoMineManager extends Node2D:
	var arena_ref: Node = null
	var target_mines: int = 3
	var _mines: Dictionary = {}
	var _next_mine_id: int = 1
	var _check_accum: float = 0.2

	func _ready() -> void:
		if not NetworkManager.is_network_active() or NetworkManager.is_host_active():
			call_deferred("_ensure_mines")

	func _process(delta: float) -> void:
		if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
			return
		_check_accum -= delta
		if _check_accum <= 0.0:
			_check_accum = 0.5
			_ensure_mines()

	func _ensure_mines() -> void:
		if arena_ref == null:
			return
		for mid in _mines.keys():
			if not is_instance_valid(_mines[mid]):
				_mines.erase(mid)
		while _mines.size() < target_mines:
			var w: float = float(arena_ref.get("arena_width"))
			var h: float = float(arena_ref.get("arena_height"))
			var raw := Vector2(randf_range(160.0, w - 160.0), randf_range(220.0, h - 120.0))
			var pos: Vector2 = arena_ref.call("_snap_to_floor", raw, 8.0, true)
			var mid: int = _next_mine_id
			_next_mine_id += 1
			NetworkManager.sync_mine_event("spawn", mid, pos)

	func handle_network_mine_event(action: String, mine_id: int, pos: Vector2) -> void:
		if action == "spawn":
			if _mines.has(mine_id) and is_instance_valid(_mines[mine_id]):
				return
			var m := ArenaAutoMine.new()
			m.mine_id = mine_id
			m.position = pos
			add_child(m)
			_mines[mine_id] = m
		elif action == "detonate":
			if _mines.has(mine_id):
				var m: Node = _mines[mine_id]
				_mines.erase(mine_id)
				if is_instance_valid(m) and m.has_method("_detonate_local"):
					m._detonate_local()


class ArenaAutoMine extends Area2D:
	const EXPLOSION_RES: PackedScene = preload("res://scenes/Explosion.tscn")
	var mine_id: int = 0
	var _arm_timer: float = 0.8
	var _pulse: float = 0.0
	var _detonated: bool = false

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 2
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 28.0
		cs.shape = circ
		add_child(cs)

	func _physics_process(delta: float) -> void:
		if _detonated:
			return
		_pulse += delta * 8.0
		if _arm_timer > 0.0:
			_arm_timer = maxf(0.0, _arm_timer - delta)
			queue_redraw()
			return
		if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
			queue_redraw()
			return
		for body in get_overlapping_bodies():
			if body.is_in_group("players") and (not body.has_method("is_alive") or body.is_alive()):
				NetworkManager.sync_mine_event("detonate", mine_id, global_position)
				return
		queue_redraw()

	func _detonate_local() -> void:
		if _detonated:
			return
		_detonated = true
		var parent_node: Node = get_parent()
		if parent_node != null:
			var exp := EXPLOSION_RES.instantiate()
			exp.global_position = global_position
			exp.explosion_radius = 125.0
			exp.max_damage = 68
			exp.shooter_peer_id = 0
			exp.shooter_name = "Outpost Mine"
			exp.weapon_name = "Proximity Mine"
			exp.can_deal_damage = (not NetworkManager.is_network_active()) or NetworkManager.is_host_active()
			exp.allow_self_damage = true
			parent_node.add_child(exp)
		queue_free()

	func _draw() -> void:
		draw_texture_rect_region(WeaponData.TEX_BOMBS_SHEET, Rect2(-13.0, -14.0, 26.0, 26.0), WeaponData.get_bomb_region("mine"))
		var led_on: bool = _arm_timer <= 0.0 and sin(_pulse) > 0.0
		if led_on:
			draw_circle(Vector2(0, -1), 3.0, Color(1.0, 0.25, 0.18, 0.85))


class GroundBombIcon extends Node2D:
	const BOMB_TYPE_BY_IDX: PackedStringArray = ["frag", "sticky", "time", "mine", "cluster"]
	var bomb_idx: int = 0

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 16.0, Color(0.08, 0.12, 0.18, 0.45))
		var r := Rect2(-15.0, -15.0, 30.0, 30.0)
		var b_key: String = BOMB_TYPE_BY_IDX[bomb_idx] if (bomb_idx >= 0 and bomb_idx < BOMB_TYPE_BY_IDX.size()) else "frag"
		draw_texture_rect_region(WeaponData.TEX_BOMBS_SHEET, r, WeaponData.get_bomb_region(b_key))


class TreasurePointOrb extends Node2D:
	var orb_kind: String = "abil_orb"
	var slot_idx: int = 0

	func _draw() -> void:
		if orb_kind == "ult_full":
			draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.28, 0.22, 0.28))
			draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.26, 0.24))
			draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, Color(1.0, 0.86, 0.30), 2.8)
			draw_circle(Vector2(-3.5, -3.5), 4.5, Color(1.0, 0.94, 0.78))
		else:
			var col: Color = Color(1.0, 0.84, 0.24) if slot_idx == 0 else (Color(0.32, 0.94, 0.56) if slot_idx == 1 else Color(0.76, 0.46, 1.0))
			draw_circle(Vector2.ZERO, 12.5, Color(col.r, col.g, col.b, 0.28))
			draw_circle(Vector2.ZERO, 8.5, col)
			draw_arc(Vector2.ZERO, 8.5, 0.0, TAU, 20, Color.WHITE, 1.8)
			draw_circle(Vector2(-2.0, -2.0), 2.5, Color(1.0, 1.0, 1.0, 0.9))


const SHOOTING_RANGE_TARGET_COUNT: int = 6


func _init_shooting_range() -> void:
	_shooting_targets.clear()
	_shooting_hits = 0
	_shooting_score = 0
	if _hud != null and not is_instance_valid(_shooting_hud_lbl):
		_shooting_hud_lbl = Label.new()
		_shooting_hud_lbl.anchor_left = 0.5
		_shooting_hud_lbl.anchor_right = 0.5
		_shooting_hud_lbl.offset_left = -160
		_shooting_hud_lbl.offset_right = 160
		_shooting_hud_lbl.offset_top = 86
		_shooting_hud_lbl.offset_bottom = 114
		_shooting_hud_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shooting_hud_lbl.add_theme_font_size_override("font_size", 16)
		_shooting_hud_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
		_shooting_hud_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		_shooting_hud_lbl.add_theme_constant_override("outline_size", 3)
		_shooting_hud_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud.add_child(_shooting_hud_lbl)
	_update_shooting_hud()
	for _i in range(SHOOTING_RANGE_TARGET_COUNT):
		_spawn_shooting_target()


func _update_shooting_hud() -> void:
	if is_instance_valid(_shooting_hud_lbl):
		_shooting_hud_lbl.text = "SHOOTING RANGE  |  TARGETS: %d  |  SCORE: %d" % [_shooting_hits, _shooting_score]


func _tick_shooting_range(_delta: float) -> void:
	var alive: Array[Node2D] = []
	for t in _shooting_targets:
		if is_instance_valid(t):
			alive.append(t)
	_shooting_targets = alive
	while _shooting_targets.size() < SHOOTING_RANGE_TARGET_COUNT:
		_spawn_shooting_target()


func _spawn_shooting_target() -> void:
	var pos := _find_open_target_pos()
	var tgt := ShootingRangeTarget.new()
	var is_gold: bool = (randf() < 0.25)
	tgt.is_gold = is_gold
	tgt.max_hp = 35.0 if is_gold else 60.0
	tgt.points = 200 if is_gold else 100
	tgt.radius = 20.0 if is_gold else 25.0
	tgt.global_position = pos
	tgt.destroyed.connect(_on_shooting_target_destroyed)
	_world_geometry.add_child(tgt)
	_shooting_targets.append(tgt)


func _find_open_target_pos() -> Vector2:
	var space := get_world_2d().direct_space_state
	var pad_x: float = 130.0
	var pad_y: float = 110.0
	for _attempt in range(28):
		var cand := Vector2(
			randf_range(pad_x, maxf(pad_x + 40.0, arena_width - pad_x)),
			randf_range(pad_y, maxf(pad_y + 40.0, arena_height - pad_y))
		)
		var q := PhysicsPointQueryParameters2D.new()
		q.position = cand
		q.collision_mask = 1
		q.collide_with_bodies = true
		q.collide_with_areas = false
		if not space.intersect_point(q, 1).is_empty():
			continue
		var too_close := false
		for t in _shooting_targets:
			if is_instance_valid(t) and t.global_position.distance_to(cand) < 110.0:
				too_close = true
				break
		if not too_close:
			return cand
	return Vector2(arena_width * 0.5, arena_height * 0.5)


func _on_shooting_target_destroyed(pts: int, _hit_pos: Vector2) -> void:
	_shooting_hits += 1
	_shooting_score += pts
	_update_shooting_hud()


class ShootingRangeTarget extends StaticBody2D:
	signal destroyed(points: int, pos: Vector2)

	var max_hp: float = 60.0
	var hp: float = 60.0
	var points: int = 100
	var radius: float = 25.0
	var is_gold: bool = false
	var _flash_t: float = 0.0
	var _bob_t: float = 0.0
	var _base_y: float = 0.0

	func _ready() -> void:
		hp = max_hp
		_base_y = position.y
		_bob_t = randf() * TAU
		collision_layer = 2
		collision_mask = 0
		add_to_group("shooting_targets")
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = radius
		cs.shape = circ
		add_child(cs)

	func _process(delta: float) -> void:
		_bob_t += delta * 2.6
		position.y = _base_y + sin(_bob_t) * 7.0
		if _flash_t > 0.0:
			_flash_t = maxf(0.0, _flash_t - delta)
			queue_redraw()

	func on_target_hit(dmg: float, hit_pos: Vector2, _shooter_id: int) -> void:
		hp -= dmg
		_flash_t = 0.12
		_spawn_hit_popup(int(roundf(dmg)), hp <= 0.0)
		queue_redraw()
		if hp <= 0.0:
			destroyed.emit(points, hit_pos)
			queue_free()

	func _spawn_hit_popup(dmg_val: int, is_kill: bool) -> void:
		var p := get_parent()
		if p == null:
			return
		var lbl := Label.new()
		lbl.text = "+%d!" % points if is_kill else "-%d" % dmg_val
		lbl.global_position = global_position + Vector2(-18, -radius - 20)
		lbl.add_theme_font_size_override("font_size", 16 if is_kill else 13)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.28) if is_kill else Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 3)
		p.add_child(lbl)
		var tw := lbl.create_tween()
		tw.tween_property(lbl, "position:y", lbl.position.y - 28.0, 0.45)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.45)
		tw.tween_callback(lbl.queue_free)

	func _draw() -> void:
		var outer_col := Color(0.95, 0.72, 0.18) if is_gold else Color(0.88, 0.22, 0.22)
		var mid_col := Color.WHITE
		if _flash_t > 0.0:
			outer_col = Color.WHITE
			mid_col = Color(1.0, 0.92, 0.45)
		draw_circle(Vector2.ZERO, radius + 3.0, Color(0.0, 0.0, 0.0, 0.45))
		draw_circle(Vector2.ZERO, radius, outer_col)
		draw_circle(Vector2.ZERO, radius * 0.68, mid_col)
		draw_circle(Vector2.ZERO, radius * 0.36, outer_col)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(0.12, 0.12, 0.14), 2.2)
		if hp < max_hp:
			var bw: float = radius * 1.8
			var ratio: float = clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
			draw_rect(Rect2(-bw * 0.5, -radius - 10.0, bw, 5.0), Color(0.1, 0.1, 0.1, 0.85), true)
			draw_rect(Rect2(-bw * 0.5, -radius - 10.0, bw * ratio, 5.0), Color(0.32, 0.96, 0.48), true)
