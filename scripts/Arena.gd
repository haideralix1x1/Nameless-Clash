extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const TEX_BG_BUNKER: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const TEX_BG_FACTORY: Texture2D = preload("res://assets/tilemaps/factory_bg.png")
const TEX_BG_DESERT: Texture2D = preload("res://assets/tilemaps/desert_bg.png")
const TEX_TILES: Texture2D = preload("res://assets/tilemaps/bunker_tileset.png")
const TEX_CRATE: Texture2D = preload("res://assets/sprites/weapon_crate.png")
const TEX_WEAPONS: Texture2D = preload("res://assets/sprites/weapons_sheet.png")

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
var _interactables: Array[Node2D] = []
var _bot_counter: int = 0
var _tile_textures: Array[Texture2D] = []
var _scenery_movers: Array[Dictionary] = []

@onready var _world_geometry: Node2D = $WorldGeometry
@onready var _pickups_container: Node2D = $Pickups
@onready var _players_container: Node2D = $Players
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
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
	_build_pickup_crates()
	_build_interactables()
	_spawn_all_participants()
	_hud.add_bot_requested.connect(_on_add_bot_requested)
	_hud.remove_bot_requested.connect(_on_remove_bot_requested)
	_hud.pickup_weapon_requested.connect(_on_pickup_weapon_requested)
	_hud.interact_requested.connect(_on_interact_requested)
	NetworkManager.interactable_toggled.connect(_on_interactable_toggled)


func _process(delta: float) -> void:
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
			c["timer"] = float(c["timer"]) - delta
			if float(c["timer"]) <= 0.0:
				c["active"] = true
				area.visible = true
				area.monitoring = true
		else:
			var visual_node: Node2D = c["sprite"] as Node2D
			if is_instance_valid(visual_node):
				visual_node.position.y = sin(t * 3.5 + float(c["phase"])) * 5.0


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
			_add_swinging_platform(Vector2(660, 48), 320.0, Vector2(180, 26), 0.38, 1.35, 0.0, true, 1)
			_add_swinging_platform(Vector2(1580, 48), 320.0, Vector2(180, 26), 0.38, 1.35, 1.8, true, 1)
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
			_add_swinging_platform(Vector2(1120, 48), 520.0, Vector2(220, 28), 0.35, 1.35, 0.0, true, 1)
			_add_swinging_platform(Vector2(2240, 48), 640.0, Vector2(260, 30), 0.42, 1.2, 1.4, true, 3)
			_add_swinging_platform(Vector2(3360, 48), 520.0, Vector2(220, 28), 0.35, 1.35, 2.8, true, 1)
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
			_add_swinging_platform(Vector2(1400, 48), 580.0, Vector2(240, 28), 0.45, 1.25, 0.4, false, 2)
			_add_swinging_platform(Vector2(2240, 48), 960.0, Vector2(260, 30), 0.36, 1.05, 1.8, false, 1)
			_add_swinging_platform(Vector2(3080, 48), 580.0, Vector2(240, 28), 0.45, 1.25, 3.1, false, 2)
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
			_add_swinging_platform(Vector2(1500, 48), 560.0, Vector2(230, 28), 0.44, 1.3, 0.5, false, 2)
			_add_swinging_platform(Vector2(2240, 48), 640.0, Vector2(250, 30), 0.38, 1.15, 1.9, false, 3)
			_add_swinging_platform(Vector2(2980, 48), 560.0, Vector2(230, 28), 0.44, 1.3, 3.3, false, 2)


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
	tex_rect.size = rect.size
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(tex_rect)

	_world_geometry.add_child(body)


func _build_pickup_crates() -> void:
	var crate_specs: Array[Dictionary] = []
	if NetworkManager.is_agent_clash_mode():
		crate_specs = [
			{"pos": Vector2(1120, 1140), "type": "throwable", "val": 0},
			{"pos": Vector2(280, 925), "type": "throwable", "val": 1},
			{"pos": Vector2(1960, 925), "type": "throwable", "val": 2},
			{"pos": Vector2(440, 410), "type": "throwable", "val": 3},
			{"pos": Vector2(1800, 410), "type": "throwable", "val": 4},
			{"pos": Vector2(880, 705), "type": "throwable", "val": 0},
			{"pos": Vector2(1360, 705), "type": "throwable", "val": 6},
			{"pos": Vector2(1120, 710), "type": "health", "val": 45},
			{"pos": Vector2(1120, 280), "type": "health", "val": 50}
		]
	else:
		var allowed_ws: Array[int] = WeaponData.get_pickup_weapon_ids()
		for sp_idx in range(_spawn_points.size()):
			var w_id: int = allowed_ws[randi() % allowed_ws.size()]
			var off_x: float = randf_range(-90.0, 90.0)
			crate_specs.append({"pos": _spawn_points[sp_idx] + Vector2(off_x, -12.0), "type": "weapon", "val": w_id})
		crate_specs.append({"pos": Vector2(arena_width * 0.5, arena_height * 0.57), "type": "health", "val": 45})
		crate_specs.append({"pos": Vector2(arena_width * 0.5, arena_height * 0.22), "type": "health", "val": 50})

	for i in range(crate_specs.size()):
		var spec: Dictionary = crate_specs[i]
		var area := Area2D.new()
		area.position = spec["pos"]
		area.collision_layer = 0
		area.collision_mask = 2

		var cs := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(34, 34) if str(spec["type"]) == "throwable" else Vector2(30, 30)
		cs.shape = box
		area.add_child(cs)

		var visual: Node2D
		if str(spec["type"]) == "throwable":
			var icon := GroundWeaponIcon.new()
			icon.item_id = int(spec["val"])
			visual = icon
		elif str(spec["type"]) == "weapon":
			var w_spr := Sprite2D.new()
			w_spr.texture = TEX_WEAPONS
			w_spr.hframes = 11
			w_spr.vframes = 3
			w_spr.frame = WeaponData.get_weapon(int(spec["val"]), 0, 0).sprite_frame
			w_spr.scale = Vector2(0.95, 0.95)
			visual = w_spr
		else:
			var spr := Sprite2D.new()
			spr.texture = TEX_CRATE
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
		_crate_nodes.append(entry)
		area.body_entered.connect(_on_crate_body_entered.bind(i))
		area.body_exited.connect(_on_crate_body_exited.bind(i))
		_pickups_container.add_child(area)


func _build_interactables() -> void:
	_interactables.clear()
	var fan_specs: Array[Dictionary] = [
		{
			"fan_pos": Vector2(arena_width * 0.25, arena_height - 76.0),
			"button_pos": Vector2(arena_width * 0.25 - 120.0, arena_height - 104.0),
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
			"fan_pos": Vector2(arena_width * 0.75, arena_height - 76.0),
			"button_pos": Vector2(arena_width * 0.75 + 120.0, arena_height - 104.0),
			"push_dir": Vector2.UP,
			"beam_len": 420.0
		}
	]
	for i in range(fan_specs.size()):
		var spec: Dictionary = fan_specs[i]
		var fan := InteractableFan.new()
		fan.inter_idx = _interactables.size()
		fan.fan_pos = spec["fan_pos"]
		fan.button_pos = spec["button_pos"]
		fan.push_dir = spec["push_dir"]
		fan.beam_length = float(spec["beam_len"])
		_world_geometry.add_child(fan)
		_interactables.append(fan)

	var heal := InteractableHealStation.new()
	heal.inter_idx = _interactables.size()
	heal.position = Vector2(arena_width * 0.50, arena_height - 104.0)
	_world_geometry.add_child(heal)
	_interactables.append(heal)

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


func _on_interactable_toggled(inter_idx: int, new_state: bool) -> void:
	if inter_idx < 0 or inter_idx >= _interactables.size():
		return
	var node: Node2D = _interactables[inter_idx]
	if node is InteractableFan:
		(node as InteractableFan).set_fan_state(new_state)
	elif node is InteractableHealStation:
		(node as InteractableHealStation).trigger_cooldown()
	elif node is InteractableProp:
		(node as InteractableProp).pick_up_prop()


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
		var p_type: String = str(entry["type"])
		if p_type == "throwable":
			if not body.has_method("can_grab_throwable") or not body.can_grab_throwable():
				return
			entry["active"] = false
			entry["timer"] = 6.0
			var val: int = int(entry["val"])
			body.apply_pickup("throwable", val)
			var next_val: int = _random_ground_throwable_id()
			entry["val"] = next_val
			var icon := entry["sprite"] as GroundWeaponIcon
			if icon != null:
				icon.item_id = next_val
				icon.queue_redraw()
			var area_t: Area2D = entry["area"] as Area2D
			area_t.visible = false
			area_t.set_deferred("monitoring", false)
			return

		if p_type == "weapon":
			if body.get("is_local_human") == true and body.has_method("set_nearby_weapon"):
				body.set_nearby_weapon(crate_idx, int(entry["val"]))
				return
			# Bots can still pick up ground weapons on walkover
			_consume_weapon_crate(crate_idx, body)
			return

		entry["active"] = false
		entry["timer"] = 9.0
		var area: Area2D = entry["area"] as Area2D
		area.visible = false
		area.set_deferred("monitoring", false)
		var val: int = int(entry["val"])
		body.apply_pickup(p_type, val)


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
	entry["active"] = false
	entry["timer"] = 9.0
	var area: Area2D = entry["area"] as Area2D
	area.visible = false
	area.set_deferred("monitoring", false)
	var val: int = int(entry["val"])
	body.apply_pickup("weapon", val)
	var allowed_ws: Array[int] = WeaponData.get_pickup_weapon_ids()
	var next_w: int = allowed_ws[randi() % allowed_ws.size()]
	entry["val"] = next_w
	var w_spr := entry["sprite"] as Sprite2D
	if w_spr != null:
		w_spr.frame = WeaponData.get_weapon(next_w, 0, 0).sprite_frame


func _spawn_all_participants() -> void:
	var peer_ids: Array = NetworkManager.players.keys()
	peer_ids.sort()

	for i in range(peer_ids.size()):
		var pid: int = int(peer_ids[i])
		var pinfo: Dictionary = NetworkManager.players[pid]
		var spawn_pos: Vector2 = _spawn_points[i % _spawn_points.size()]
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
				cam.limit_top = 0
				cam.limit_right = int(arena_width)
				cam.limit_bottom = int(arena_height)
			_hud.bind_local_player(player)

	var target_bots: int = clampi(NetworkManager.test_bot_count, 1, NetworkManager.MAX_BOTS) if NetworkManager.is_test_mode() else clampi(NetworkManager.bot_count, 0, NetworkManager.MAX_BOTS)
	if NetworkManager.is_test_mode():
		NetworkManager.test_bot_count = target_bots
	else:
		NetworkManager.bot_count = target_bots
	for b in range(target_bots):
		_spawn_bot(b + 1)


func _spawn_bot(bot_index: int) -> void:
	_bot_counter = maxi(_bot_counter, bot_index)
	var bot_id: int = -bot_index
	var bot_team: int = bot_index % 2
	var color_idx: int = bot_team if NetworkManager.is_team_mode() else (NetworkManager.local_color_index + bot_index) % NetworkManager.TEAM_COLORS.size()
	var spawn_pos: Vector2 = _spawn_points[(bot_index + 1) % _spawn_points.size()]

	var arch_idx: int = (bot_index * 3 + 1) % ProfileManager.ARCHETYPES.size()
	var arch: Dictionary = ProfileManager.ARCHETYPES[arch_idx]
	var raw_bot_w: int = int(arch["weapon"]) if (bot_index % 2 == 0) else (bot_index % WeaponData.get_weapon_count())
	var bot_weapon: int = WeaponData.sanitize_weapon_id(raw_bot_w)
	var sec_weapon: int = 9 if WeaponData.is_weapon_allowed(9) else bot_weapon
	var bot_name: String = "Bot-%d" % bot_index
	if NetworkManager.is_agent_clash_mode():
		bot_name = "%s (Bot)" % str(AgentData.get_agent(arch_idx)["agent_name"])
	var bot_avatar: Dictionary = {
		"archetype_id": arch_idx,
		"skin_id": arch_idx,
		"head_id": (arch_idx + bot_index) % ProfileManager.ARCHETYPES.size(),
		"torso_id": arch_idx,
		"legs_id": arch_idx,
		"hands_id": arch_idx,
		"accessories_id": arch_idx,
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


func _get_active_bots() -> Array[Node]:
	var out: Array[Node] = []
	for child in _players_container.get_children():
		if is_instance_valid(child) and bool(child.get("is_bot")):
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
			tr.position = -plat_size * 0.5
			tr.size = plat_size
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

		# Fan housing
		var half_w: float = beam_width * 0.44
		draw_rect(Rect2(fan_pos - Vector2(half_w, 12), Vector2(half_w * 2.0, 24)), Color(0.22, 0.26, 0.32))
		draw_rect(Rect2(fan_pos - Vector2(half_w, 12), Vector2(half_w * 2.0, 24)), Color(0.58, 0.64, 0.72), false, 2.5)
		# Spinning fan blades
		for k in range(3):
			var bx: float = sin(_spin + float(k) * 2.1) * (half_w * 0.75)
			draw_line(fan_pos + Vector2(bx, -8), fan_pos + Vector2(bx, 8), Color(0.75, 0.82, 0.90), 5.0)

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


class InteractableProp extends Node2D:
	var inter_idx: int = 0
	var prop_kind: String = "chair"
	var is_available: bool = true
	var _respawn_timer: float = 0.0
	var _area: Area2D

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

	func pick_up_prop() -> void:
		is_available = false
		_respawn_timer = 10.0
		queue_redraw()

	func _process(delta: float) -> void:
		if not is_available:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				is_available = true
				queue_redraw()

	func _on_entered(body: Node2D) -> void:
		if is_available and body.is_in_group("players") and body.get("is_local_human") == true and body.has_method("set_nearby_interactable"):
			body.set_nearby_interactable(inter_idx, "PICK\n%s" % prop_kind.replace("_", " ").to_upper().substr(0, 7))

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
				draw_circle(Vector2(0, 2), 9.5, Color(0.74, 0.42, 0.24))
				draw_rect(Rect2(-6, -11, 12, 6), Color(0.64, 0.35, 0.19))
				draw_rect(Rect2(-7, -12, 14, 3), Color(0.86, 0.54, 0.32))
			"stone":
				draw_rect(Rect2(-11, -9, 22, 18), Color(0.54, 0.52, 0.48))
				draw_rect(Rect2(-11, -9, 22, 18), Color(0.30, 0.28, 0.25), false, 2.0)
			"ice_block":
				draw_rect(Rect2(-11, -11, 22, 22), Color(0.62, 0.88, 1.0, 0.88))
				draw_rect(Rect2(-11, -11, 22, 22), Color(0.92, 0.98, 1.0), false, 2.0)
			"crate":
				draw_rect(Rect2(-11, -11, 22, 22), Color(0.26, 0.34, 0.46))
				draw_rect(Rect2(-11, -11, 22, 22), Color(0.38, 0.86, 0.98), false, 2.0)
