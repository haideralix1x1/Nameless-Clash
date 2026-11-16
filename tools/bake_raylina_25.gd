extends SceneTree

const S: int = 128

func _init() -> void:
	var s_skin := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_head := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_torso := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_legs := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_hands := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_acc := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)

	var b_legs := _load("res://assets/sprites/modular/legs_18.png")
	var b_hands := _load("res://assets/sprites/modular/hands_18.png")

	var sc: float = 128.0 / 96.0
	for f in range(8):
		var ox: int = f * S
		var bob: float = (1.0 if f in [1, 2, 4] else (3.0 if f == 6 else 0.0)) * sc
		var dead: bool = (f == 7)
		var hx: float = (24.0 if dead else 48.0) * sc
		var hy: float = (66.0 if dead else 33.0) * sc + (0.0 if dead else bob)
		var ty: float = (68.0 if dead else 53.0) * sc + (0.0 if dead else bob)

		# 1. legs_25: Sleek dark boots + ice-blue skirt sash trim
		if b_legs != null:
			s_legs.blit_rect(b_legs, Rect2i(ox, 0, S, S), Vector2i(ox, 0))
		if not dead:
			_fill_ellipse(s_legs, ox + 48.0 * sc, ty + 18.0 * sc, 15.0 * sc, 6.0 * sc, Color(0.58, 0.78, 0.94))
			_fill_ellipse(s_legs, ox + 48.0 * sc, ty + 16.0 * sc, 12.0 * sc, 4.5 * sc, Color(0.16, 0.26, 0.30))

		# 2. hands_25: Sleek fair hands + silver-blue bracers
		if b_hands != null:
			s_hands.blit_rect(b_hands, Rect2i(ox, 0, S, S), Vector2i(ox, 0))
		if not dead:
			_fill_circle(s_hands, ox + 29.0 * sc, ty + 16.0 * sc, 4.8 * sc, Color(0.98, 0.87, 0.80))
			_fill_circle(s_hands, ox + 66.0 * sc, ty + 16.0 * sc, 4.8 * sc, Color(0.98, 0.87, 0.80))
			_fill_ellipse(s_hands, ox + 29.0 * sc, ty + 11.0 * sc, 4.5 * sc, 3.0 * sc, Color(0.64, 0.80, 0.94))
			_fill_ellipse(s_hands, ox + 66.0 * sc, ty + 11.0 * sc, 4.5 * sc, 3.0 * sc, Color(0.64, 0.80, 0.94))

		# 3. skin_25: Pretty chibi elf face (smooth fair skin, big sparkling eyes, blush, gentle smile, elf ear)
		_fill_circle(s_skin, ox + hx, hy, 18.0 * sc, Color(0.99, 0.89, 0.83))
		_stroke_circle(s_skin, ox + hx, hy, 18.0 * sc, 2.2, Color(0.10, 0.08, 0.12))
		# Pointed elf ear with soft inner pink shadow
		_fill_triangle(s_skin, Vector2(ox + hx - 15.0 * sc, hy - 2.0 * sc), Vector2(ox + hx - 27.0 * sc, hy - 9.0 * sc), Vector2(ox + hx - 14.0 * sc, hy + 4.0 * sc), Color(0.98, 0.85, 0.78))
		_fill_triangle(s_skin, Vector2(ox + hx - 16.0 * sc, hy - 1.5 * sc), Vector2(ox + hx - 24.0 * sc, hy - 6.5 * sc), Vector2(ox + hx - 15.5 * sc, hy + 2.0 * sc), Color(0.92, 0.70, 0.66))
		# Soft rosy cheek blush
		_fill_ellipse(s_skin, ox + hx - 2.0 * sc, hy + 5.5 * sc, 3.8 * sc, 2.0 * sc, Color(1.0, 0.68, 0.70, 0.45))
		_fill_ellipse(s_skin, ox + hx + 12.5 * sc, hy + 5.5 * sc, 3.4 * sc, 2.0 * sc, Color(1.0, 0.68, 0.70, 0.45))
		# Big sparkling eyes + winged lashes + thin graceful brows
		for ex in [ox + hx + 0.5 * sc, ox + hx + 10.5 * sc]:
			_fill_ellipse(s_skin, ex, hy - 0.5 * sc, 3.8 * sc, 4.2 * sc, Color(0.99, 0.99, 1.0))
			_fill_circle(s_skin, ex + 0.4 * sc, hy, 2.5 * sc, Color(0.28, 0.46, 0.72))
			_fill_circle(s_skin, ex + 0.5 * sc, hy + 0.2 * sc, 1.3 * sc, Color(0.08, 0.10, 0.16))
			_fill_circle(s_skin, ex - 0.7 * sc, hy - 1.2 * sc, 1.0 * sc, Color(1.0, 1.0, 1.0))
			# Winged lash & thin arched brow
			_draw_line(s_skin, ex - 3.6 * sc, hy - 3.6 * sc, ex + 4.2 * sc, hy - 3.2 * sc, 1.6, Color(0.08, 0.06, 0.10))
			_draw_line(s_skin, ex - 3.0 * sc, hy - 6.4 * sc, ex + 3.0 * sc, hy - 6.8 * sc, 1.2, Color(0.14, 0.10, 0.18))
		# Cute gentle smile
		_draw_line(s_skin, ox + hx + 3.5 * sc, hy + 9.2 * sc, ox + hx + 6.5 * sc, hy + 10.0 * sc, 1.3, Color(0.76, 0.42, 0.46))
		_draw_line(s_skin, ox + hx + 6.5 * sc, hy + 10.0 * sc, ox + hx + 9.5 * sc, hy + 9.0 * sc, 1.3, Color(0.76, 0.42, 0.46))

		# 4. head_25: Smooth flowing dark plum hair (sweeping bangs + long side locks, zero bumpy circles)
		var h_dark := Color(0.14, 0.10, 0.20)
		var h_mid := Color(0.22, 0.15, 0.30)
		var h_hi := Color(0.36, 0.24, 0.46)
		# Smooth dome crown
		_fill_ellipse(s_head, ox + hx - 1.0 * sc, hy - 7.0 * sc, 21.5 * sc, 15.0 * sc, h_dark)
		# Flowing side locks down behind & beside face
		_fill_ellipse(s_head, ox + hx - 15.0 * sc, hy + 5.0 * sc, 8.0 * sc, 15.0 * sc, h_dark)
		_fill_ellipse(s_head, ox + hx + 15.5 * sc, hy + 4.5 * sc, 6.5 * sc, 13.0 * sc, h_dark)
		# Soft glossy hair highlights on crown & bangs
		_fill_ellipse(s_head, ox + hx - 2.0 * sc, hy - 12.5 * sc, 14.0 * sc, 6.5 * sc, h_mid)
		_fill_ellipse(s_head, ox + hx + 1.0 * sc, hy - 14.0 * sc, 9.0 * sc, 3.0 * sc, h_hi)
		# Clear clean oval for face + elf ear
		_clear_ellipse(s_head, ox + hx + 4.0 * sc, hy + 2.5 * sc, 13.2 * sc, 11.8 * sc)
		_clear_ellipse(s_head, ox + hx - 19.5 * sc, hy - 4.0 * sc, 7.5 * sc, 4.8 * sc)
		# Sweeping side-parted bang over forehead
		_draw_line(s_head, ox + hx - 6.0 * sc, hy - 14.0 * sc, ox + hx + 13.0 * sc, hy - 7.5 * sc, 3.2 * sc, h_dark)
		_draw_line(s_head, ox + hx - 9.0 * sc, hy - 13.0 * sc, ox + hx - 15.0 * sc, hy - 3.0 * sc, 3.2 * sc, h_dark)

		# 5. torso_25: Forest-teal fitted tunic + ice-blue sash + silver-blue feathered pauldrons
		_fill_ellipse(s_torso, ox + 48.0 * sc, ty + 10.0 * sc, 14.5 * sc, 11.5 * sc, Color(0.16, 0.27, 0.29))
		_draw_line(s_torso, ox + 37.0 * sc, ty + 2.0 * sc, ox + 58.0 * sc, ty + 16.0 * sc, 3.0 * sc, Color(0.64, 0.84, 0.96))
		_fill_rect(s_torso, int((34.0 * sc)), int(ty + 14.5 * sc), int(28.0 * sc), int(3.8 * sc), Color(0.68, 0.86, 0.98))
		# Clean silver-blue feathered pauldrons
		_fill_ellipse(s_torso, ox + 32.0 * sc, ty + 4.0 * sc, 7.5 * sc, 5.0 * sc, Color(0.18, 0.24, 0.36))
		_fill_ellipse(s_torso, ox + 64.0 * sc, ty + 4.0 * sc, 7.5 * sc, 5.0 * sc, Color(0.18, 0.24, 0.36))
		_fill_ellipse(s_torso, ox + 30.0 * sc, ty + 5.5 * sc, 3.8 * sc, 2.2 * sc, Color(0.78, 0.88, 0.98))
		_fill_ellipse(s_torso, ox + 66.0 * sc, ty + 5.5 * sc, 3.8 * sc, 2.2 * sc, Color(0.78, 0.88, 0.98))

		# 6. accessories_25: Flowing dark-teal & ice-blue trimmed cloak
		_fill_ellipse(s_acc, ox + 29.0 * sc, ty + 11.0 * sc, 10.0 * sc, 14.5 * sc, Color(0.14, 0.22, 0.26))
		_fill_ellipse(s_acc, ox + 25.0 * sc, ty + 13.0 * sc, 4.5 * sc, 12.5 * sc, Color(0.60, 0.82, 0.96))

	s_skin.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/skin_25.png"))
	s_head.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/head_25.png"))
	s_torso.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/torso_25.png"))
	s_legs.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/legs_25.png"))
	s_hands.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/hands_25.png"))
	s_acc.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/accessories_25.png"))
	print("Baked pretty Ray Lina 25 sprites at 128x128 cleanly.")
	quit()


func _load(p: String) -> Image:
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(p)) == OK:
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		img.resize(S * 8, S, Image.INTERPOLATE_BILINEAR)
		return img
	return null


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for py in range(maxi(0, y), mini(img.get_height(), y + h)):
		for px in range(maxi(0, x), mini(img.get_width(), x + w)):
			img.set_pixel(px, py, img.get_pixel(px, py).blend(col))


func _fill_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	_fill_ellipse(img, cx, cy, r, r, col)


func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for py in range(maxi(0, int(floor(cy - ry - 1))), mini(img.get_height(), int(ceil(cy + ry + 1)))):
		for px in range(maxi(0, int(floor(cx - rx - 1))), mini(img.get_width(), int(ceil(cx + rx + 1)))):
			var dx: float = (float(px) - cx) / maxf(1.0, rx)
			var dy: float = (float(py) - cy) / maxf(1.0, ry)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(px, py, img.get_pixel(px, py).blend(col))


func _clear_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	for py in range(maxi(0, int(floor(cy - ry - 1))), mini(img.get_height(), int(ceil(cy + ry + 1)))):
		for px in range(maxi(0, int(floor(cx - rx - 1))), mini(img.get_width(), int(ceil(cx + rx + 1)))):
			var dx: float = (float(px) - cx) / maxf(1.0, rx)
			var dy: float = (float(py) - cy) / maxf(1.0, ry)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(px, py, Color(0, 0, 0, 0))


func _stroke_circle(img: Image, cx: float, cy: float, r: float, thick: float, col: Color) -> void:
	var r_in: float = maxf(0.0, r - thick)
	for py in range(maxi(0, int(floor(cy - r - 1))), mini(img.get_height(), int(ceil(cy + r + 1)))):
		for px in range(maxi(0, int(floor(cx - r - 1))), mini(img.get_width(), int(ceil(cx + r + 1)))):
			var d: float = sqrt(pow(float(px) - cx, 2.0) + pow(float(py) - cy, 2.0))
			if d <= r and d >= r_in:
				img.set_pixel(px, py, img.get_pixel(px, py).blend(col))


func _draw_line(img: Image, x0: float, y0: float, x1: float, y1: float, r: float, col: Color) -> void:
	var steps: int = maxi(4, int(Vector2(x0, y0).distance_to(Vector2(x1, y1))))
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		_fill_circle(img, lerpf(x0, x1, t), lerpf(y0, y1, t), r, col)


func _fill_triangle(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var min_x: int = maxi(0, int(floor(minf(a.x, minf(b.x, c.x)))))
	var max_x: int = mini(img.get_width() - 1, int(ceil(maxf(a.x, maxf(b.x, c.x)))))
	var min_y: int = maxi(0, int(floor(minf(a.y, minf(b.y, c.y)))))
	var max_y: int = mini(img.get_height() - 1, int(ceil(maxf(a.y, maxf(b.y, c.y)))))
	for py in range(min_y, max_y + 1):
		for px in range(min_x, max_x + 1):
			if Geometry2D.point_is_inside_triangle(Vector2(px, py), a, b, c):
				img.set_pixel(px, py, img.get_pixel(px, py).blend(col))
