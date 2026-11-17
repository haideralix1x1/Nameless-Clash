extends SceneTree

const FW: int = 96
const FH: int = 96


func _init() -> void:
	var img := Image.create(FW * 8, FH, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in range(8):
		_draw_frame(img, f)
	var abs_path: String = ProjectSettings.globalize_path("res://assets/sprites/modular/shoe_throw.png")
	img.save_png(abs_path)
	print("Generated shoe_throw.png successfully.")
	quit()


func _dot(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var r2: float = r * r
	for py in range(maxi(0, int(floor(cy - r - 1))), mini(FH, int(ceil(cy + r + 1)))):
		for px in range(maxi(0, int(floor(cx - r - 1))), mini(img.get_width(), int(ceil(cx + r + 1)))):
			var dx: float = float(px) - cx
			var dy: float = float(py) - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(px, py, img.get_pixel(px, py).blend(col))


func _line(img: Image, p1: Vector2, p2: Vector2, r: float, col: Color) -> void:
	var steps: int = maxi(4, int(ceil(p1.distance_to(p2) * 1.5)))
	for i in range(steps + 1):
		var p: Vector2 = p1.lerp(p2, float(i) / float(steps))
		_dot(img, p.x, p.y, r, col)


func _draw_shoe(img: Image, pos: Vector2, angle: float) -> void:
	var dir := Vector2.from_angle(angle)
	var perp := Vector2(-dir.y, dir.x)
	var ink := Color(0.08, 0.08, 0.10, 1.0)
	var leather := Color(0.76, 0.42, 0.18, 1.0)
	var sole := Color(0.18, 0.16, 0.14, 1.0)
	_line(img, pos - dir * 5.0, pos + dir * 6.0, 4.5, ink)
	_line(img, pos - dir * 4.5, pos + dir * 5.5, 3.3, leather)
	_line(img, pos - dir * 4.5 + perp * 2.5, pos + dir * 5.5 + perp * 2.5, 1.5, sole)


func _draw_frame(img: Image, f: int) -> void:
	var ox: float = float(f * FW)
	var bend: float = 0.0
	var lift_leg: float = 0.0
	var shoe_off: float = 0.0
	var arm_throw: float = 0.0
	if f <= 4:
		bend = float(f) / 4.0
		lift_leg = sin(bend * PI * 0.65) * 10.0
		shoe_off = maxf(0.0, float(f - 2) * 4.0)
	else:
		arm_throw = float(f - 4) / 3.0

	# Draw ONLY the shoe overlay (no hardcoded soldier body!) so the player's actual character stays visible
	var foot_pos := Vector2(ox + 56.0 + bend * 4.0, 78.0 - lift_leg)
	if f <= 4:
		var shoe_pos := foot_pos + Vector2(shoe_off, -shoe_off * 0.8)
		_draw_shoe(img, shoe_pos, -0.35 * bend)
		if f >= 2:
			# Small white sock peek on the lifted foot as the shoe comes off
			_dot(img, foot_pos.x - 1.0, foot_pos.y + 1.0, 2.8, Color(0.92, 0.94, 0.98, 0.95))
	else:
		var torso_top := Vector2(ox + 50.0, 42.0)
		var ang: float = lerpf(-2.1, 0.25, arm_throw)
		var hand_pos := torso_top + Vector2.from_angle(ang) * 18.0
		if f < 7:
			_draw_shoe(img, hand_pos, ang + 0.5)
		else:
			# Release speed lines on final frame
			_line(img, hand_pos - Vector2(8, 2), hand_pos + Vector2(6, -2), 1.4, Color(1.0, 0.92, 0.65, 0.85))
