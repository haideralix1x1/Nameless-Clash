extends SceneTree


func _init() -> void:
	for map_id in range(0, 13):
		var bg: Image = _make_bg(map_id)
		bg.save_png(ProjectSettings.globalize_path("res://assets/tilemaps/bg_map_%d.png" % map_id))
		if map_id >= 3:
			var tiles: Image = _make_tiles(map_id)
			tiles.save_png(ProjectSettings.globalize_path("res://assets/tilemaps/tiles_map_%d.png" % map_id))
	print("Generated 13 seamless map backgrounds and 10 tilesets.")
	quit()


func _dot(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var r2: float = r * r
	for py in range(int(floor(cy - r - 1)), int(ceil(cy + r + 1))):
		for px in range(int(floor(cx - r - 1)), int(ceil(cx + r + 1))):
			var dx: float = float(px) - cx
			var dy: float = float(py) - cy
			if dx * dx + dy * dy <= r2:
				var wx: int = posmod(px, w)
				var wy: int = posmod(py, h)
				img.set_pixel(wx, wy, img.get_pixel(wx, wy).blend(col))


func _make_huge_trees_bg(rng: RandomNumberGenerator) -> Image:
	var w: int = 512
	var h: int = 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	# Deep seamless forest canopy backdrop
	img.fill(Color(0.04, 0.09, 0.05))
	for _i in range(95):
		var lx: float = rng.randf_range(0, w)
		var ly: float = rng.randf_range(0, h)
		var lr: float = rng.randf_range(16, 38)
		var shade: float = rng.randf_range(0.06, 0.16)
		_dot(img, lx, ly, lr, Color(shade * 0.6, shade * 1.4, shade * 0.65, 0.55))

	# Draw back-layer & front-layer huge vertical tree trunks (100% periodic in X and Y)
	var trunks: Array[Dictionary] = [
		{"x": 38, "w": 38, "depth": 0},
		{"x": 148, "w": 44, "depth": 0},
		{"x": 276, "w": 36, "depth": 0},
		{"x": 392, "w": 48, "depth": 0},
		{"x": 86, "w": 52, "depth": 1},
		{"x": 212, "w": 64, "depth": 1},
		{"x": 334, "w": 46, "depth": 1},
		{"x": 456, "w": 56, "depth": 1},
	]
	var px_size: int = 4
	for tr in trunks:
		var tx: int = int(tr["x"])
		var tw: int = int(tr["w"])
		var is_front: bool = int(tr["depth"]) == 1
		var dark_bark: Color = Color(0.16, 0.09, 0.06) if is_front else Color(0.09, 0.06, 0.05)
		var mid_bark: Color = Color(0.32, 0.18, 0.11) if is_front else Color(0.15, 0.10, 0.08)
		var hi_bark: Color = Color(0.56, 0.34, 0.18) if is_front else Color(0.24, 0.15, 0.11)
		var edge_col: Color = Color(0.08, 0.04, 0.03)
		for py in range(0, h, px_size):
			var y_phase: float = float(py) / float(h) * TAU
			var sway: int = int(round(sin(y_phase + float(tx) * 0.05) * 2.0))
			for lx in range(0, tw, px_size):
				var wx: int = posmod(tx + lx + sway, w)
				var u: float = float(lx) / float(maxi(1, tw - px_size))
				var col: Color = mid_bark
				if lx == 0 or lx >= tw - px_size:
					col = edge_col
				elif u < 0.22:
					col = hi_bark
				elif u > 0.72:
					col = dark_bark
				else:
					# Periodic pixel-art bark grooves
					var n: float = sin(y_phase * 4.0 + float(lx) * 0.7 + float(tx)) + cos(y_phase * 7.0 - float(lx) * 0.4)
					if n > 0.85:
						col = hi_bark
					elif n < -0.65:
						col = dark_bark
				img.fill_rect(Rect2i(wx, py, px_size, px_size), col)
				# Seamless wrap if fill_rect crosses w
				if wx + px_size > w:
					img.fill_rect(Rect2i(0, py, (wx + px_size) - w, px_size), col)

	# Subtle leafy canopy highlights & tiny forest fireflies
	for _i in range(42):
		_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(10, 22), Color(0.14, 0.38, 0.14, 0.28))
	for _i in range(18):
		_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), 2.0, Color(0.75, 0.95, 0.42, 0.65))
	return img


func _make_bg(map_id: int) -> Image:
	if map_id == 12:
		var rng_t := RandomNumberGenerator.new()
		rng_t.seed = 2012
		return _make_huge_trees_bg(rng_t)

	var w: int = 256
	var h: int = 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + map_id * 77

	match map_id:
		0: # Bunker Base: seamless dark reinforced concrete panels + rivets
			img.fill(Color(0.11, 0.13, 0.16))
			for row in range(0, h, 64):
				img.fill_rect(Rect2i(0, row, w, 2), Color(0.07, 0.08, 0.10))
			for col in range(0, w, 64):
				img.fill_rect(Rect2i(col, 0, 2, h), Color(0.07, 0.08, 0.10))
			for ry in range(10, h, 64):
				for rx in range(10, w, 64):
					_dot(img, rx, ry, 2.0, Color(0.24, 0.28, 0.34, 0.7))
					_dot(img, rx + 44, ry, 2.0, Color(0.24, 0.28, 0.34, 0.7))
					_dot(img, rx, ry + 44, 2.0, Color(0.24, 0.28, 0.34, 0.7))
					_dot(img, rx + 44, ry + 44, 2.0, Color(0.24, 0.28, 0.34, 0.7))
		1: # Factory Ruins: seamless industrial steel girders & warm embers
			img.fill(Color(0.13, 0.12, 0.14))
			for col in range(0, w, 128):
				img.fill_rect(Rect2i(col + 12, 0, 18, h), Color(0.18, 0.16, 0.19))
				img.fill_rect(Rect2i(col + 16, 0, 4, h), Color(0.24, 0.22, 0.25))
			for row in range(0, h, 128):
				img.fill_rect(Rect2i(0, row + 56, w, 12), Color(0.17, 0.15, 0.18))
			for _i in range(22):
				_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(1.5, 3.0), Color(0.95, 0.45, 0.14, 0.32))
		2: # Desert Outpost: seamless warm dusk sky + subtle sand haze
			for y in range(h):
				var t: float = 0.5 - 0.5 * cos(float(y) / float(h) * TAU)
				img.fill_rect(Rect2i(0, y, w, 1), Color(0.54, 0.34, 0.20).lerp(Color(0.68, 0.46, 0.26), t))
			for _i in range(20):
				_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(14, 28), Color(0.86, 0.64, 0.34, 0.14))
		3: # Catacombs Maze: dark carved brick wall + subtle moss cracks
			img.fill(Color(0.14, 0.12, 0.10))
			for row in range(0, h, 32):
				var off: int = 32 if ((row / 32) % 2 == 1) else 0
				img.fill_rect(Rect2i(0, row, w, 2), Color(0.08, 0.07, 0.06))
				for col_x in range(off, w, 64):
					img.fill_rect(Rect2i(col_x % w, row, 2, 32), Color(0.08, 0.07, 0.06))
			for _i in range(28):
				_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(3, 8), Color(0.18, 0.28, 0.14, 0.25))
		4: # Outpost Towers: seamless misty slate sky
			for y in range(h):
				var t: float = 0.5 - 0.5 * cos(float(y) / float(h) * TAU)
				img.fill_rect(Rect2i(0, y, w, 1), Color(0.22, 0.28, 0.36).lerp(Color(0.28, 0.34, 0.42), t))
			for _i in range(18):
				_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(16, 30), Color(0.32, 0.38, 0.46, 0.16))
		5: # Soarin Islands: seamless sky + soft wrapping clouds
			for y in range(h):
				var t: float = 0.5 - 0.5 * cos(float(y) / float(h) * TAU)
				img.fill_rect(Rect2i(0, y, w, 1), Color(0.46, 0.74, 0.96).lerp(Color(0.62, 0.84, 0.98), t))
			for c_pos in [Vector2(54, 62), Vector2(180, 118), Vector2(105, 196)]:
				_dot(img, c_pos.x, c_pos.y, 18, Color(1, 1, 1, 0.50))
				_dot(img, c_pos.x - 16, c_pos.y + 4, 13, Color(1, 1, 1, 0.42))
				_dot(img, c_pos.x + 16, c_pos.y + 5, 14, Color(1, 1, 1, 0.42))
		6: # Pharaoh Pyramid: seamless warm desert sandstone haze
			for y in range(h):
				var t: float = 0.5 - 0.5 * cos(float(y) / float(h) * TAU)
				img.fill_rect(Rect2i(0, y, w, 1), Color(0.42, 0.26, 0.16).lerp(Color(0.56, 0.36, 0.20), t))
			for _i in range(24):
				_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(14, 28), Color(0.76, 0.52, 0.26, 0.14))
		7: # Snow Blind: seamless crisp winter sky + wrapping snow flurries
			for y in range(h):
				var t: float = 0.5 - 0.5 * cos(float(y) / float(h) * TAU)
				img.fill_rect(Rect2i(0, y, w, 1), Color(0.58, 0.74, 0.90).lerp(Color(0.74, 0.86, 0.96), t))
			for _i in range(45):
				_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(1.2, 2.5), Color(1, 1, 1, 0.75))
		8: # Substructure: industrial underground pipes & vents (seamless)
			img.fill(Color(0.10, 0.12, 0.16))
			img.fill_rect(Rect2i(0, 44, w, 14), Color(0.18, 0.22, 0.28))
			img.fill_rect(Rect2i(0, 168, w, 18), Color(0.16, 0.20, 0.25))
			img.fill_rect(Rect2i(84, 0, 16, h), Color(0.15, 0.18, 0.23))
			for vy in range(72, 140, 12):
				img.fill_rect(Rect2i(140, vy, 72, 5), Color(0.06, 0.08, 0.10))
		9: # High Tower: seamless dusk sky
			for y in range(h):
				var t: float = 0.5 - 0.5 * cos(float(y) / float(h) * TAU)
				img.fill_rect(Rect2i(0, y, w, 1), Color(0.20, 0.18, 0.32).lerp(Color(0.34, 0.22, 0.34), t))
			for _i in range(28):
				_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(1.0, 2.0), Color(0.95, 0.90, 1.0, 0.45))
		10: # Ring Arena: dark cyber-grid
			img.fill(Color(0.06, 0.08, 0.13))
			for x in range(0, w, 32):
				img.fill_rect(Rect2i(x, 0, 1, h), Color(0.14, 0.42, 0.62, 0.45))
			for y in range(0, h, 32):
				img.fill_rect(Rect2i(0, y, w, 1), Color(0.14, 0.42, 0.62, 0.45))
		11: # Lunar Station: deep space starfield + wrapping nebula
			img.fill(Color(0.04, 0.05, 0.11))
			_dot(img, 180, 90, 55, Color(0.22, 0.16, 0.48, 0.22))
			_dot(img, 70, 190, 45, Color(0.12, 0.30, 0.52, 0.20))
			for _i in range(65):
				var bright: float = rng.randf_range(0.5, 1.0)
				_dot(img, rng.randf_range(0, w), rng.randf_range(0, h), rng.randf_range(0.8, 1.8), Color(bright, bright, 1.0, 0.9))
	return img


func _make_tiles(map_id: int) -> Image:
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	var pal: Array[Color]
	match map_id:
		3: pal = [Color(0.42, 0.36, 0.28), Color(0.32, 0.27, 0.20), Color(0.52, 0.45, 0.34), Color(0.26, 0.40, 0.22)]
		4: pal = [Color(0.34, 0.38, 0.44), Color(0.26, 0.30, 0.36), Color(0.48, 0.52, 0.58), Color(0.86, 0.62, 0.18)]
		5: pal = [Color(0.46, 0.34, 0.22), Color(0.24, 0.62, 0.24), Color(0.56, 0.44, 0.30), Color(0.30, 0.72, 0.28)]
		6: pal = [Color(0.76, 0.62, 0.36), Color(0.64, 0.50, 0.28), Color(0.86, 0.72, 0.44), Color(0.84, 0.66, 0.22)]
		7: pal = [Color(0.54, 0.68, 0.80), Color(0.86, 0.94, 0.99), Color(0.44, 0.58, 0.72), Color(0.76, 0.88, 0.98)]
		8: pal = [Color(0.26, 0.30, 0.36), Color(0.20, 0.24, 0.30), Color(0.36, 0.40, 0.48), Color(0.92, 0.64, 0.14)]
		9: pal = [Color(0.38, 0.36, 0.44), Color(0.28, 0.26, 0.34), Color(0.50, 0.48, 0.56), Color(0.68, 0.34, 0.28)]
		10: pal = [Color(0.16, 0.22, 0.32), Color(0.12, 0.16, 0.26), Color(0.24, 0.72, 0.94), Color(0.96, 0.54, 0.18)]
		11: pal = [Color(0.52, 0.56, 0.66), Color(0.38, 0.42, 0.52), Color(0.72, 0.78, 0.88), Color(0.32, 0.82, 0.96)]
		_: pal = [Color(0.44, 0.32, 0.20), Color(0.22, 0.58, 0.20), Color(0.54, 0.40, 0.26), Color(0.28, 0.68, 0.24)]

	for idx in range(4):
		var ox: int = idx * 32
		var base_c: Color = pal[idx]
		var top_c: Color = pal[1] if idx in [1, 2] else base_c.lightened(0.20)
		var border_c: Color = base_c.darkened(0.42)
		img.fill_rect(Rect2i(ox, 0, 32, 32), base_c)
		img.fill_rect(Rect2i(ox, 0, 32, 5), top_c)
		img.fill_rect(Rect2i(ox, 0, 32, 2), border_c)
		img.fill_rect(Rect2i(ox, 30, 32, 2), border_c)
		img.fill_rect(Rect2i(ox, 0, 2, 32), border_c)
		img.fill_rect(Rect2i(ox + 30, 0, 2, 32), border_c)
		# Add surface detail (rivets / bricks / grass blades)
		if map_id in [5, 7, 12] and idx in [1, 2]:
			for gx in range(ox + 3, ox + 30, 6):
				img.fill_rect(Rect2i(gx, 5, 2, 3), top_c)
		elif map_id in [4, 8, 10, 11]:
			for rx in [ox + 5, ox + 25]:
				img.fill_rect(Rect2i(rx, 8, 2, 2), base_c.lightened(0.35))
				img.fill_rect(Rect2i(rx, 24, 2, 2), base_c.lightened(0.35))
		else:
			img.fill_rect(Rect2i(ox + 2, 16, 28, 2), border_c)
			img.fill_rect(Rect2i(ox + 15, 5, 2, 11), border_c)
	return img
