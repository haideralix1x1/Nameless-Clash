extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
const TEX_BG_BUNKER: Texture2D = preload("res://assets/tilemaps/bunker_bg.png")
const TEX_BG_FACTORY: Texture2D = preload("res://assets/tilemaps/factory_bg.png")
const TEX_BG_DESERT: Texture2D = preload("res://assets/tilemaps/desert_bg.png")
const TEX_TILES: Texture2D = preload("res://assets/tilemaps/bunker_tileset.png")
const TEX_CRATE: Texture2D = preload("res://assets/sprites/weapon_crate.png")

const ARENA_WIDTH: float = 2240.0
const ARENA_HEIGHT: float = 1248.0

var _spawn_points: Array[Vector2] = [
	Vector2(220.0, 1020.0),
	Vector2(2020.0, 1020.0),
	Vector2(480.0, 350.0),
	Vector2(1760.0, 350.0),
	Vector2(1120.0, 230.0),
	Vector2(1120.0, 660.0)
]

var _crate_nodes: Array[Dictionary] = []
var _bot_counter: int = 0
var _tile_textures: Array[Texture2D] = []

@onready var _world_geometry: Node2D = $WorldGeometry
@onready var _pickups_container: Node2D = $Pickups
@onready var _players_container: Node2D = $Players
@onready var _hud: CanvasLayer = $HUD


func _ready() -> void:
	NetworkManager.ensure_offline_player()
	_prepare_tile_textures()
	_build_map_background()
	_build_map_geometry()
	_build_pickup_crates()
	_spawn_all_participants()
	_hud.add_bot_requested.connect(_on_add_bot_requested)


func _process(delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
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


func _prepare_tile_textures() -> void:
	var row_y: int = clampi(NetworkManager.selected_map_id, 0, 2) * 32
	var src_img: Image = TEX_TILES.get_image()
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
	match NetworkManager.selected_map_id:
		1:
			bg_sprite.texture = TEX_BG_FACTORY
		2:
			bg_sprite.texture = TEX_BG_DESERT
		_:
			bg_sprite.texture = TEX_BG_BUNKER
	bg_sprite.centered = false
	bg_sprite.region_enabled = true
	bg_sprite.region_rect = Rect2(0, 0, ARENA_WIDTH, ARENA_HEIGHT)
	bg_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	bg_sprite.z_index = -10
	_world_geometry.add_child(bg_sprite)


func _build_map_geometry() -> void:
	# Shared Outer Perimeter
	_add_platform(Rect2(0, 0, ARENA_WIDTH, 48), 0)
	_add_platform(Rect2(0, ARENA_HEIGHT - 64, ARENA_WIDTH, 64), 1)
	_add_platform(Rect2(0, 48, 48, ARENA_HEIGHT - 112), 0)
	_add_platform(Rect2(ARENA_WIDTH - 48, 48, 48, ARENA_HEIGHT - 112), 0)

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
		_:
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
			{"pos": Vector2(880, 705), "type": "throwable", "val": 5},
			{"pos": Vector2(1360, 705), "type": "throwable", "val": 6},
			{"pos": Vector2(1120, 710), "type": "health", "val": 45},
			{"pos": Vector2(1120, 280), "type": "health", "val": 50}
		]
	else:
		crate_specs = [
			{"pos": Vector2(1120, 940), "type": "weapon", "val": 2},
			{"pos": Vector2(1120, 710), "type": "health", "val": 45},
			{"pos": Vector2(440, 410), "type": "weapon", "val": 3},
			{"pos": Vector2(1800, 410), "type": "weapon", "val": 4},
			{"pos": Vector2(1120, 280), "type": "health", "val": 50}
		]

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
		_pickups_container.add_child(area)


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
			var next_val: int = randi_range(0, AgentData.THROWABLE_ITEMS.size() - 1)
			entry["val"] = next_val
			var icon := entry["sprite"] as GroundWeaponIcon
			if icon != null:
				icon.item_id = next_val
				icon.queue_redraw()
			var area_t: Area2D = entry["area"] as Area2D
			area_t.visible = false
			area_t.set_deferred("monitoring", false)
			return

		entry["active"] = false
		entry["timer"] = 9.0
		var area: Area2D = entry["area"] as Area2D
		area.visible = false
		area.set_deferred("monitoring", false)
		var val: int = int(entry["val"])
		if p_type == "weapon":
			var allowed_ws: Array[int] = WeaponData.get_allowed_weapon_ids()
			val = allowed_ws[randi() % allowed_ws.size()]
		body.apply_pickup(p_type, val)


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
				cam.limit_right = int(ARENA_WIDTH)
				cam.limit_bottom = int(ARENA_HEIGHT)
			_hud.bind_local_player(player)

	for b in range(NetworkManager.bot_count):
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


func _on_add_bot_requested() -> void:
	if NetworkManager.is_network_active() and not NetworkManager.is_host_active():
		return
	if NetworkManager.is_network_active():
		spawn_extra_bot_rpc.rpc(_bot_counter + 1)
	else:
		NetworkManager.bot_count += 1
		_spawn_bot(_bot_counter + 1)
		NetworkManager.player_list_updated.emit()


@rpc("authority", "call_local", "reliable")
func spawn_extra_bot_rpc(bot_index: int) -> void:
	NetworkManager.bot_count = maxi(NetworkManager.bot_count, bot_index)
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
