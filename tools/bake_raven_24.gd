extends SceneTree

const S: int = 96

func _init() -> void:
	var s_skin := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_head := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_torso := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_legs := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_hands := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)
	var s_acc := Image.create(S * 8, S, false, Image.FORMAT_RGBA8)

	# Use base poses from existing modular sheets for clean frame alignment, then paint Raven's custom parts
	var b_skin := _load("res://assets/sprites/modular/skin_14.png")
	var b_legs := _load("res://assets/sprites/modular/legs_11.png")
	var b_hands := _load("res://assets/sprites/modular/hands_11.png")

	for f in range(8):
		var ox: int = f * S
		var bob: int = 1 if f in [1, 2, 4] else (3 if f == 6 else 0)
		var dead: bool = (f == 7)
		var hx: int = 24 if dead else 48
		var hy: int = 66 if dead else (33 + bob)
		var ty: int = 68 if dead else (53 + bob)

		if b_legs != null:
			s_legs.blit_rect(b_legs, Rect2i(ox, 0, S, S), Vector2i(ox, 0))
		if b_hands != null:
			s_hands.blit_rect(b_hands, Rect2i(ox, 0, S, S), Vector2i(ox, 0))

		# 1. skin_24: Face under hood (normal skin jaw + stubble + deep black upper shadow + glowing violet lightning eye)
		_fill_circle(s_skin, ox + hx, hy, 19.0, Color(0.92, 0.75, 0.65))
		_stroke_circle(s_skin, ox + hx, hy, 19.0, 2.2, Color(0.08, 0.08, 0.12))
		# Stubble jaw
		_fill_ellipse(s_skin, ox + hx + 2, hy + 10, 16.0, 7.5, Color(0.46, 0.43, 0.47, 0.80))
		# Mouth
		_fill_rect(s_skin, ox + hx + 1, hy + 10, 10, 2, Color(0.10, 0.09, 0.14))
		# Deep hood shadow covering upper face/eyes
		_fill_ellipse(s_skin, ox + hx + 1, hy - 4, 18.0, 11.0, Color(0.05, 0.04, 0.08))
		# Glowing violet lightning eye + white core + wisp
		var ex: int = ox + hx + 7
		var ey: int = hy - 1
		_fill_ellipse(s_skin, ex, ey, 6.0, 3.2, Color(0.68, 0.30, 0.98))
		_fill_ellipse(s_skin, ex, ey, 3.2, 1.6, Color(1.0, 0.95, 1.0))
		_draw_line(s_skin, ex + 2, ey - 1, ex + 12, ey - 9, 2.2, Color(0.82, 0.48, 1.0))
		_draw_line(s_skin, ex, ey + 2, ex - 2, ey + 9, 2.0, Color(0.68, 0.30, 0.96))

		# 2. head_24: Dark pointed cowl/hood framing the shadowed face
		_fill_ellipse(s_head, ox + hx, hy - 10, 23.0, 16.0, Color(0.17, 0.18, 0.23))
		_fill_ellipse(s_head, ox + hx - 4, hy - 16, 14.0, 10.0, Color(0.24, 0.25, 0.32))
		_fill_rect(s_head, ox + hx - 22, hy - 10, 8, 22, Color(0.15, 0.16, 0.21))
		_fill_rect(s_head, ox + hx + 14, hy - 10, 8, 18, Color(0.15, 0.16, 0.21))
		_stroke_circle(s_head, ox + hx, hy - 10, 22.0, 2.2, Color(0.07, 0.07, 0.10))
		# Cut out inner face opening so skin_24 shows cleanly
		_clear_ellipse(s_head, ox + hx + 2, hy + 2, 15.0, 12.0)

		# 3. torso_24: Dark charcoal chestplate + scarf + raven brooch + feathered pauldrons
		_fill_ellipse(s_torso, ox + 48, ty + 10, 16.0, 12.0, Color(0.22, 0.24, 0.29))
		_fill_ellipse(s_torso, ox + 48, ty + 10, 12.0, 8.0, Color(0.28, 0.30, 0.36))
		# Scarf around collar
		_fill_ellipse(s_torso, ox + 48, ty + 1, 14.0, 5.0, Color(0.13, 0.14, 0.18))
		# Raven skull brooch
		_fill_circle(s_torso, ox + 48, ty + 6, 3.6, Color(0.38, 0.40, 0.48))
		# Feathered pauldrons
		_fill_ellipse(s_torso, ox + 32, ty + 4, 8.0, 6.0, Color(0.16, 0.17, 0.22))
		_fill_ellipse(s_torso, ox + 64, ty + 4, 8.0, 6.0, Color(0.16, 0.17, 0.22))
		# Belt
		_fill_rect(s_torso, ox + 34, ty + 16, 28, 4, Color(0.14, 0.13, 0.16))

		# 4. accessories_24: Swirling purple shadow flames + tattered black feather cloak
		_fill_ellipse(s_acc, ox + 22, ty + 4, 11.0, 16.0, Color(0.62, 0.30, 0.90, 0.72))
		_fill_ellipse(s_acc, ox + 18, ty - 2, 6.0, 10.0, Color(0.84, 0.58, 1.0, 0.80))
		_fill_ellipse(s_acc, ox + 28, ty + 12, 10.0, 14.0, Color(0.13, 0.14, 0.19))

	var _unused := b_skin
	s_skin.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/skin_24.png"))
	s_head.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/head_24.png"))
	s_torso.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/torso_24.png"))
	s_legs.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/legs_24.png"))
	s_hands.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/hands_24.png"))
	s_acc.save_png(ProjectSettings.globalize_path("res://assets/sprites/modular/accessories_24.png"))
	print("Baked Raven 24 modular sprites cleanly.")
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
