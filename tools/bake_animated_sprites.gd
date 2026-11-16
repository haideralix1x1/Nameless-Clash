extends SceneTree


func _init() -> void:
	_bake_flame_head(21, Color(1.0, 0.28, 0.14), Color(1.0, 0.78, 0.22))
	_bake_flame_head(14, Color(0.28, 0.42, 1.0), Color(0.45, 0.95, 1.0))
	_bake_walk_particles(21, Color(1.0, 0.45, 0.14), Color(1.0, 0.85, 0.25), "ember")
	_bake_walk_particles(14, Color(0.32, 0.65, 1.0), Color(0.55, 0.96, 1.0), "ember")
	_bake_walk_particles(15, Color(0.62, 0.56, 0.44), Color(0.82, 0.76, 0.60), "stone")
	_bake_walk_particles(20, Color(0.48, 0.44, 0.42), Color(0.68, 0.62, 0.58), "stone")
	_bake_crystal_head(22)
	_bake_walk_particles(22, Color(0.95, 0.48, 0.82), Color(1.0, 0.86, 0.96), "crystal")
	_bake_walk_particles(12, Color(0.38, 0.88, 0.24), Color(0.72, 1.0, 0.45), "slime")
	_bake_mech_head(16)
	_bake_walk_particles(16, Color(0.35, 0.88, 1.0), Color(0.88, 0.96, 1.0), "spark")
	print("Baked animated sprite features successfully.")
	quit()


func _load_sheet(rel_path: String) -> Image:
	var abs_path: String = ProjectSettings.globalize_path(rel_path)
	var img := Image.new()
	if img.load(abs_path) != OK:
		push_error("Failed to load: " + abs_path)
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


func _save_sheet(img: Image, rel_path: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(rel_path)
	img.save_png(abs_path)


func _draw_dot(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var r2: float = r * r
	for py in range(maxi(0, int(floor(cy - r - 1))), mini(h, int(ceil(cy + r + 1)))):
		for px in range(maxi(0, int(floor(cx - r - 1))), mini(w, int(ceil(cx + r + 1)))):
			var dx: float = float(px) - cx
			var dy: float = float(py) - cy
			if dx * dx + dy * dy <= r2:
				var dst: Color = img.get_pixel(px, py)
				img.set_pixel(px, py, dst.blend(col))


func _draw_flame_tongue(img: Image, bx: float, by: float, tip_x: float, tip_y: float, base_r: float, outer: Color, core: Color) -> void:
	var steps: int = 8
	for s in range(steps + 1):
		var t: float = float(s) / float(steps)
		var cx: float = lerpf(bx, tip_x, t)
		var cy: float = lerpf(by, tip_y, t)
		var rad: float = lerpf(base_r, 1.0, t)
		_draw_dot(img, cx, cy, rad, outer)
		if t < 0.72:
			_draw_dot(img, cx, cy, rad * 0.55, core)


func _bake_flame_head(arch: int, outer_col: Color, core_col: Color) -> void:
	var path: String = "res://assets/sprites/modular/head_%d.png" % arch
	var img: Image = _load_sheet(path)
	if img == null:
		return
	var fw: int = img.get_width() / 8
	var fh: int = img.get_height()
	for f in range(7):
		var ox: float = float(f * fw)
		var sway: float = sin(float(f) * 1.65) * 4.5
		var lift: float = float((f % 3) * 3)
		# Animated flame tongues on top of head
		_draw_flame_tongue(img, ox + fw * 0.42, fh * 0.24, ox + fw * 0.34 - sway, fh * 0.08 - lift, 4.2, outer_col, core_col)
		_draw_flame_tongue(img, ox + fw * 0.54, fh * 0.22, ox + fw * 0.50 + sway * 0.8, fh * 0.05 - lift * 0.8, 3.8, outer_col, core_col)
		# Floating rising embers
		_draw_dot(img, ox + fw * 0.26 - sway * 0.6, fh * (0.14 - 0.02 * float(f % 3)), 2.1, core_col)
		if f in [1, 2, 4, 5]:
			_draw_dot(img, ox + fw * 0.62 + sway * 0.4, fh * (0.10 - 0.015 * float(f % 2)), 1.7, outer_col)
	_save_sheet(img, path)


func _bake_crystal_head(arch: int) -> void:
	var path: String = "res://assets/sprites/modular/head_%d.png" % arch
	var img: Image = _load_sheet(path)
	if img == null:
		return
	var fw: int = img.get_width() / 8
	var fh: int = img.get_height()
	var glint := Color(1.0, 0.92, 1.0, 0.92)
	for f in range(7):
		var ox: float = float(f * fw)
		var px: float = ox + fw * (0.34 + 0.08 * float(f % 4))
		var py: float = fh * (0.12 + 0.03 * float((f + 1) % 3))
		_draw_dot(img, px, py, 2.2 if f % 2 == 0 else 1.4, glint)
		_draw_dot(img, ox + fw * 0.60, fh * (0.16 - 0.02 * float(f % 3)), 1.6, Color(0.98, 0.62, 0.88, 0.88))
	_save_sheet(img, path)


func _bake_mech_head(arch: int) -> void:
	var path: String = "res://assets/sprites/modular/head_%d.png" % arch
	var img: Image = _load_sheet(path)
	if img == null:
		return
	var fw: int = img.get_width() / 8
	var fh: int = img.get_height()
	for f in range(7):
		var ox: float = float(f * fw)
		var bright: bool = (f % 2 == 1)
		var col: Color = Color(0.32, 0.96, 1.0, 0.95) if bright else Color(0.18, 0.48, 0.72, 0.75)
		var r: float = 2.6 if bright else 1.6
		_draw_dot(img, ox + fw * 0.36, fh * 0.14, r, col)
		_draw_dot(img, ox + fw * 0.56, fh * 0.14, r, col)
	_save_sheet(img, path)


func _bake_walk_particles(arch: int, col_a: Color, col_b: Color, kind: String) -> void:
	var path: String = "res://assets/sprites/modular/legs_%d.png" % arch
	var img: Image = _load_sheet(path)
	if img == null:
		return
	var fw: int = img.get_width() / 8
	var fh: int = img.get_height()
	for f in [2, 3, 4]:
		var ox: float = float(f * fw)
		var step_shift: float = float(f - 2) * 3.5
		if kind == "stone":
			_draw_dot(img, ox + fw * 0.24 - step_shift, fh * 0.86, 2.8, col_a)
			_draw_dot(img, ox + fw * 0.18 - step_shift * 0.7, fh * 0.80, 2.0, col_b)
			_draw_dot(img, ox + fw * 0.31 - step_shift * 0.4, fh * 0.88, 1.8, col_a)
		elif kind == "crystal":
			_draw_dot(img, ox + fw * 0.24 - step_shift, fh * 0.84, 2.4, col_a)
			_draw_dot(img, ox + fw * 0.19 - step_shift * 0.5, fh * 0.77, 1.8, col_b)
		elif kind == "slime":
			_draw_dot(img, ox + fw * 0.25 - step_shift * 0.8, fh * 0.88, 2.6, col_a)
			_draw_dot(img, ox + fw * 0.20 - step_shift * 0.5, fh * 0.82, 1.8, col_b)
		else:
			_draw_dot(img, ox + fw * 0.24 - step_shift, fh * 0.83, 2.3, col_a)
			_draw_dot(img, ox + fw * 0.19 - step_shift * 0.6, fh * 0.76, 1.7, col_b)
	_save_sheet(img, path)
