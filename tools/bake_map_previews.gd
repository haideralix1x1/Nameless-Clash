extends SceneTree

const W: int = 560
const H: int = 312
const ARENA_W: float = 2240.0
const ARENA_H: float = 1248.0


func _init() -> void:
	for map_id in range(13):
		var img := _render_map(map_id)
		var abs_p: String = ProjectSettings.globalize_path("res://assets/tilemaps/preview_map_%d.png" % map_id)
		img.save_png(abs_p)
	print("Rendered 13 actual map previews.")
	quit()


func _load_img(res_path: String) -> Image:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(res_path)) == OK:
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		return img
	return null


func _dot(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var r2: float = r * r
	for py in range(maxi(0, int(floor(cy - r - 1))), mini(H, int(ceil(cy + r + 1)))):
		for px in range(maxi(0, int(floor(cx - r - 1))), mini(W, int(ceil(cx + r + 1)))):
			var dx: float = float(px) - cx
			var dy: float = float(py) - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(px, py, img.get_pixel(px, py).blend(col))


func _render_map(map_id: int) -> Image:
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var bg_path: String = "res://assets/tilemaps/bg_map_%d.png" % map_id

	var bg_img := _load_img(bg_path)
	if bg_img != null:
		var bw: int = bg_img.get_width()
		var bh: int = bg_img.get_height()
		var tile_s: int = 128 if bw <= 256 else 180
		bg_img.resize(tile_s, tile_s, Image.INTERPOLATE_BILINEAR)
		for y in range(0, H, tile_s):
			for x in range(0, W, tile_s):
				out.blit_rect(bg_img, Rect2i(0, 0, mini(tile_s, W - x), mini(tile_s, H - y)), Vector2i(x, y))
		var _unused := bw + bh
	else:
		out.fill(Color(0.10, 0.14, 0.20))

	var is_double: bool = map_id in [3, 5, 7, 11, 12]
	var cur_w: float = ARENA_W * (2.0 if is_double else 1.0)
	var cur_h: float = ARENA_H * (2.0 if is_double else 1.0)
	var sx: float = float(W) / cur_w
	var sy: float = float(H) / cur_h

	# Scenery behind platforms
	if map_id == 11:
		_dot(out, 540 * sx, 280 * sy, 18.0, Color(0.32, 0.48, 0.88, 0.85))
		_dot(out, 1740 * sx, 340 * sy, 12.0, Color(0.78, 0.32, 0.24, 0.85))
		for ap in [Vector2(760, 960), Vector2(1840, 520), Vector2(2840, 1480), Vector2(3640, 1040), Vector2(1480, 1840)]:
			_dot(out, ap.x * sx, ap.y * sy, 5.5, Color(0.50, 0.52, 0.60, 0.90))
	elif map_id in [5, 12]:
		var trees: Array = [Vector2(520, 840), Vector2(3840, 840), Vector2(2240, 1720), Vector2(800, 1840)] if map_id == 12 else [Vector2(560, 1880), Vector2(3880, 1880), Vector2(1120, 1040), Vector2(3320, 1040)]
		for tp in trees:
			var tx: float = tp.x * sx
			var ty: float = tp.y * sy
			out.fill_rect(Rect2i(int(tx - 2), int(ty - 16), 4, 16), Color(0.42, 0.26, 0.14))
			_dot(out, tx, ty - 18, 8.0, Color(0.20, 0.64, 0.24, 0.92))
	elif map_id == 7:
		for tp in [Vector2(600, 960), Vector2(3840, 960), Vector2(1240, 1680), Vector2(3240, 1680)]:
			var tx: float = tp.x * sx
			var ty: float = tp.y * sy
			_dot(out, tx, ty - 10, 7.0, Color(0.18, 0.46, 0.34, 0.95))
			_dot(out, tx, ty - 16, 4.5, Color(0.90, 0.96, 1.0, 0.95))
	elif map_id in [3, 6]:
		var sc: float = 2.0 if map_id == 3 else 1.0
		for tp in [Vector2(420, 420), Vector2(1820, 420), Vector2(1120, 520)]:
			_dot(out, tp.x * sc * sx, tp.y * sc * sy, 6.0, Color(1.0, 0.56, 0.16, 0.85))

	# Load tileset
	var tiles_img: Image
	var row_y: int = 0
	if map_id >= 3:
		tiles_img = _load_img("res://assets/tilemaps/tiles_map_%d.png" % map_id)
	else:
		tiles_img = _load_img("res://assets/tilemaps/bunker_tileset.png")
		row_y = map_id * 32

	var tile_samples: Array[Image] = []
	if tiles_img != null:
		for t_i in range(4):
			var sub := tiles_img.get_region(Rect2i(t_i * 32, row_y, 32, 32))
			sub.resize(12, 12, Image.INTERPOLATE_BILINEAR)
			tile_samples.append(sub)

	var plats: Array[Array] = [
		[Rect2(0, 0, cur_w, 48), 0], [Rect2(0, cur_h - 64, cur_w, 64), 1],
		[Rect2(0, 48, 48, cur_h - 112), 0], [Rect2(cur_w - 48, 48, 48, cur_h - 112), 0]
	]
	match map_id:
		1:
			plats.append_array([[Rect2(140, 910, 280, 32), 2], [Rect2(1820, 910, 280, 32), 2], [Rect2(620, 680, 72, 504), 0], [Rect2(1548, 680, 72, 504), 0], [Rect2(840, 890, 560, 40), 1], [Rect2(240, 560, 380, 34), 1], [Rect2(1620, 560, 380, 34), 1], [Rect2(860, 340, 520, 34), 2], [Rect2(960, 560, 320, 32), 3]])
		2:
			plats.append_array([[Rect2(280, 760, 56, 424), 0], [Rect2(1904, 760, 56, 424), 0], [Rect2(180, 440, 360, 36), 1], [Rect2(1700, 440, 360, 36), 1], [Rect2(440, 890, 340, 32), 2], [Rect2(1460, 890, 340, 32), 2], [Rect2(880, 980, 480, 48), 3], [Rect2(760, 510, 720, 36), 1], [Rect2(1070, 360, 100, 150), 0]])
		3:
			for rp in [[Rect2(240, 260, 720, 36), 0], [Rect2(1280, 260, 720, 36), 0], [Rect2(240, 960, 720, 36), 0], [Rect2(1280, 960, 720, 36), 0], [Rect2(440, 480, 420, 34), 1], [Rect2(1380, 480, 420, 34), 1], [Rect2(440, 740, 420, 34), 1], [Rect2(1380, 740, 420, 34), 1], [Rect2(980, 600, 280, 40), 3], [Rect2(820, 296, 36, 184), 2], [Rect2(1384, 296, 36, 184), 2], [Rect2(820, 774, 36, 186), 2], [Rect2(1384, 774, 36, 186), 2]]:
				plats.append([Rect2((rp[0] as Rect2).position * 2.0, (rp[0] as Rect2).size * 2.0), rp[1]])
			plats.append_array([[Rect2(180, 1180, 420, 42), 1], [Rect2(3880, 1180, 420, 42), 1], [Rect2(1980, 560, 520, 42), 3], [Rect2(1980, 1860, 520, 42), 3], [Rect2(1280, 1220, 380, 40), 2], [Rect2(2820, 1220, 380, 40), 2]])
		4:
			plats.append_array([[Rect2(560, 420, 240, 36), 1], [Rect2(1440, 420, 240, 36), 1], [Rect2(980, 320, 280, 36), 1], [Rect2(560, 456, 38, 220), 0], [Rect2(1642, 456, 38, 220), 0], [Rect2(240, 740, 440, 36), 2], [Rect2(1560, 740, 440, 36), 2], [Rect2(860, 660, 520, 40), 3], [Rect2(740, 960, 760, 36), 1]])
		5:
			for rp in [[Rect2(140, 940, 320, 44), 2], [Rect2(1780, 940, 320, 44), 2], [Rect2(420, 520, 340, 40), 1], [Rect2(1480, 520, 340, 40), 1], [Rect2(920, 320, 400, 38), 1], [Rect2(880, 800, 480, 44), 3], [Rect2(620, 1020, 260, 34), 2], [Rect2(1360, 1020, 260, 34), 2]]:
				plats.append([Rect2((rp[0] as Rect2).position * 2.0, (rp[0] as Rect2).size * 2.0), rp[1]])
			plats.append_array([[Rect2(240, 680, 460, 46), 2], [Rect2(3780, 680, 460, 46), 2], [Rect2(460, 1420, 480, 44), 1], [Rect2(3540, 1420, 480, 44), 1], [Rect2(1320, 1280, 380, 42), 3], [Rect2(2780, 1280, 380, 42), 3], [Rect2(1040, 520, 420, 40), 1], [Rect2(3020, 520, 420, 40), 1], [Rect2(1980, 2140, 520, 48), 2]])
		6:
			plats.append_array([[Rect2(340, 960, 1560, 40), 2], [Rect2(520, 740, 1200, 38), 1], [Rect2(720, 520, 800, 36), 1], [Rect2(940, 300, 360, 36), 3], [Rect2(1090, 556, 60, 184), 0], [Rect2(680, 778, 44, 182), 0], [Rect2(1516, 778, 44, 182), 0]])
		7:
			for rp in [[Rect2(160, 480, 420, 38), 1], [Rect2(1660, 480, 420, 38), 1], [Rect2(160, 320, 48, 160), 0], [Rect2(2032, 320, 48, 160), 0], [Rect2(760, 520, 720, 40), 2], [Rect2(440, 840, 440, 36), 3], [Rect2(1360, 840, 440, 36), 3], [Rect2(960, 1000, 320, 40), 1]]:
				plats.append([Rect2((rp[0] as Rect2).position * 2.0, (rp[0] as Rect2).size * 2.0), rp[1]])
			plats.append_array([[Rect2(240, 1480, 480, 44), 2], [Rect2(3760, 1480, 480, 44), 2], [Rect2(1180, 1340, 460, 42), 1], [Rect2(2840, 1340, 460, 42), 1], [Rect2(1960, 560, 560, 44), 3], [Rect2(1980, 1620, 520, 42), 2]])
		8:
			plats.append_array([[Rect2(220, 380, 560, 32), 1], [Rect2(1460, 380, 560, 32), 1], [Rect2(920, 380, 400, 32), 2], [Rect2(740, 412, 40, 320), 0], [Rect2(1460, 412, 40, 320), 0], [Rect2(260, 732, 520, 34), 1], [Rect2(1460, 732, 520, 34), 1], [Rect2(900, 880, 440, 38), 3]])
		9:
			plats.append_array([[Rect2(140, 420, 340, 36), 1], [Rect2(1760, 420, 340, 36), 1], [Rect2(440, 456, 44, 340), 0], [Rect2(1756, 456, 44, 340), 0], [Rect2(1070, 300, 100, 560), 0], [Rect2(900, 280, 440, 34), 3], [Rect2(680, 620, 280, 32), 2], [Rect2(1280, 620, 280, 32), 2], [Rect2(880, 960, 480, 38), 1]])
		10:
			plats.append_array([[Rect2(480, 260, 1280, 36), 0], [Rect2(480, 980, 1280, 36), 0], [Rect2(240, 460, 38, 360), 0], [Rect2(1962, 460, 38, 360), 0], [Rect2(920, 600, 400, 44), 3], [Rect2(560, 620, 220, 32), 2], [Rect2(1460, 620, 220, 32), 2]])
		11:
			for rp in [[Rect2(340, 620, 1560, 36), 1], [Rect2(1096, 200, 48, 840), 0], [Rect2(580, 380, 320, 32), 2], [Rect2(1340, 380, 320, 32), 2], [Rect2(580, 860, 320, 32), 2], [Rect2(1340, 860, 320, 32), 2]]:
				plats.append([Rect2((rp[0] as Rect2).position * 2.0, (rp[0] as Rect2).size * 2.0), rp[1]])
			plats.append_array([[Rect2(160, 740, 460, 42), 1], [Rect2(3860, 740, 460, 42), 1], [Rect2(160, 1740, 460, 42), 1], [Rect2(3860, 1740, 460, 42), 1], [Rect2(1940, 420, 600, 42), 3], [Rect2(1940, 2060, 600, 42), 3]])
		12:
			for rp in [[Rect2(120, 420, 460, 44), 2], [Rect2(1660, 420, 460, 44), 2], [Rect2(540, 464, 44, 420), 0], [Rect2(1656, 464, 44, 420), 0], [Rect2(780, 540, 680, 34), 1], [Rect2(240, 920, 300, 36), 1], [Rect2(1700, 920, 300, 36), 1], [Rect2(880, 860, 480, 38), 3]]:
				plats.append([Rect2((rp[0] as Rect2).position * 2.0, (rp[0] as Rect2).size * 2.0), rp[1]])
			plats.append_array([[Rect2(1260, 560, 520, 44), 2], [Rect2(2700, 560, 520, 44), 2], [Rect2(220, 1340, 480, 42), 1], [Rect2(3780, 1340, 480, 42), 1], [Rect2(1280, 1460, 480, 42), 3], [Rect2(2720, 1460, 480, 42), 3], [Rect2(1980, 2140, 520, 46), 1]])
		_:
			plats.append_array([[Rect2(120, 960, 320, 36), 1], [Rect2(1800, 960, 320, 36), 1], [Rect2(580, 960, 64, 224), 3], [Rect2(1596, 960, 64, 224), 3], [Rect2(960, 1020, 320, 48), 1], [Rect2(800, 740, 640, 38), 1], [Rect2(340, 720, 280, 32), 2], [Rect2(1620, 720, 280, 32), 2], [Rect2(240, 440, 420, 34), 1], [Rect2(1580, 440, 420, 34), 1], [Rect2(880, 310, 480, 34), 1]])

	for p in plats:
		var r: Rect2 = p[0]
		var ti: int = int(p[1])
		var px0: int = int(r.position.x * sx)
		var py0: int = int(r.position.y * sy)
		var pw: int = maxi(4, int(r.size.x * sx))
		var ph: int = maxi(4, int(r.size.y * sy))
		if tile_samples.size() == 4:
			var ts: Image = tile_samples[clampi(ti, 0, 3)]
			for yy in range(py0, mini(H, py0 + ph), 12):
				for xx in range(px0, mini(W, px0 + pw), 12):
					var cw: int = mini(12, px0 + pw - xx)
					var ch: int = mini(12, py0 + ph - yy)
					out.blit_rect(ts, Rect2i(0, 0, cw, ch), Vector2i(xx, yy))
		else:
			out.fill_rect(Rect2i(px0, py0, pw, ph), Color(0.45, 0.52, 0.62))
	return out
