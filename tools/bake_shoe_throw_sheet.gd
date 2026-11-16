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
	var ink := Color(0.08, 0.09, 0.12, 1.0)
	var skin := Color(0.95, 0.74, 0.60, 1.0)
	var shirt := Color(0.32, 0.56, 0.34, 1.0)
	var pants := Color(0.24, 0.32, 0.24, 1.0)
	var helmet := Color(0.36, 0.50, 0.30, 1.0)
	var boot := Color(0.42, 0.24, 0.12, 1.0)

	var bend: float = 0.0
	var lift_leg: float = 0.0
	var shoe_off: float = 0.0
	var arm_throw: float = 0.0
	if f <= 4:
		bend = float(f) / 4.0
		lift_leg = sin(bend * PI * 0.65) * 10.0
		shoe_off = maxf(0.0, float(f - 2) * 3.5)
	else:
		arm_throw = float(f - 4) / 3.0

	var hip := Vector2(ox + 48.0, 62.0 + bend * 4.0)
	var torso_top := hip + Vector2(bend * 9.0 - arm_throw * 4.0, -20.0 + bend * 5.0)
	var head_c := torso_top + Vector2(bend * 4.0, -14.0)

	# Standing leg (left)
	_line(img, hip + Vector2(-4, 0), Vector2(ox + 42.0, 82.0), 4.8, ink)
	_line(img, hip + Vector2(-4, 0), Vector2(ox + 42.0, 82.0), 3.4, pants)
	_dot(img, ox + 43.0, 84.0, 4.5, boot)

	# Lifted leg (right) - pulling shoe off in frames 0..4
	var foot_pos := Vector2(ox + 56.0 + bend * 4.0, 80.0 - lift_leg)
	_line(img, hip + Vector2(4, 0), foot_pos, 4.8, ink)
	_line(img, hip + Vector2(4, 0), foot_pos, 3.4, pants)
	if f < 4:
		_draw_shoe(img, foot_pos + Vector2(shoe_off, shoe_off * 0.4), -0.25 * bend)
	else:
		_dot(img, foot_pos.x, foot_pos.y, 3.2, Color(0.88, 0.88, 0.92))  # bare sock!

	# Torso
	_line(img, hip, torso_top, 11.0, ink)
	_line(img, hip, torso_top, 9.2, shirt)

	# Head + helmet
	_dot(img, head_c.x, head_c.y, 12.0, ink)
	_dot(img, head_c.x, head_c.y, 10.2, skin)
	_dot(img, head_c.x, head_c.y - 5.0, 10.8, ink)
	_dot(img, head_c.x, head_c.y - 5.0, 9.0, helmet)
	_dot(img, head_c.x + 5.0, head_c.y - 1.0, 2.0, ink)

	# Reaching / throwing arm + shoe in hand
	var hand_pos: Vector2
	if f <= 4:
		hand_pos = torso_top.lerp(foot_pos + Vector2(shoe_off, 2.0), clampf(0.35 + bend * 0.65, 0.0, 1.0))
	else:
		var ang: float = lerpf(-2.1, 0.25, arm_throw)
		hand_pos = torso_top + Vector2.from_angle(ang) * 18.0
		if f < 7:
			_draw_shoe(img, hand_pos, ang + 0.5)
	_line(img, torso_top + Vector2(3, 3), hand_pos, 4.2, ink)
	_line(img, torso_top + Vector2(3, 3), hand_pos, 2.8, skin)
	_dot(img, hand_pos.x, hand_pos.y, 3.8, skin)
