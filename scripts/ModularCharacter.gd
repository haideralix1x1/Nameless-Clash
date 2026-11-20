class_name ModularCharacter
extends Node2D
## Runtime modular 2D Chibi-Vector character assembler.
## Manages layered Sprite2D / AnimatedSprite2D parts, RGB/Hex tinting,
## and synchronized multi-layer animation playback across LAN peers.

const FRAME_SIZE := Vector2i(96, 96)
const SHEET_FRAMES := 8
const MAX_PART_INDEX := 27

const ANIM_DEFS: Dictionary = {
	"idle": {"frames": [0, 1], "fps": 3.5, "loop": true},
	"run": {"frames": [2, 3, 4, 3], "fps": 10.5, "loop": true},
	"jetpack": {"frames": [5], "fps": 6.0, "loop": true},
	"firing": {"frames": [6], "fps": 8.0, "loop": false},
	"crouch": {"frames": [6], "fps": 4.0, "loop": false},
	"dead": {"frames": [7], "fps": 1.0, "loop": false},
}

var _sprite_back: Sprite2D
var _anim_legs: AnimatedSprite2D
var _anim_torso: AnimatedSprite2D
var _anim_head: AnimatedSprite2D
var _sprite_gear: Sprite2D
var _sprite_hands: Sprite2D
var _sprite_hand_far: Sprite2D
var _sprite_shoe_throw: Sprite2D

var _current_anim: String = "idle"
var _manual_sync_mode: bool = false
var _manual_frame: int = 0
var _flip_h: bool = false
var _custom_full_sheet: bool = false
var hands_z_over_weapon: int = 0

var _base_colors: Dictionary = {
	"shirt": Color.WHITE,
	"pants": Color.WHITE,
	"skin": Color.WHITE,
	"helmet": Color.WHITE,
	"gear": Color.WHITE,
}

var _tex_cache: Dictionary = {}
var _frames_cache: Dictionary = {}


func _ready() -> void:
	_ensure_layers()
	set_process(true)


func _process(_delta: float) -> void:
	if _manual_sync_mode or _anim_legs == null:
		return
	var mapped_frame := _get_sheet_frame_for_anim(_current_anim, _anim_legs.frame)
	_apply_sheet_frame_to_sprites(mapped_frame)


func _ensure_layers() -> void:
	if _sprite_back != null and is_instance_valid(_sprite_back):
		return

	_sprite_back = _get_or_create_sprite("Sprite2D_Back")
	_anim_legs = _get_or_create_animated("AnimatedSprite2D_Legs")
	_anim_torso = _get_or_create_animated("AnimatedSprite2D_Torso")
	_anim_head = _get_or_create_animated("AnimatedSprite2D_Head")
	_sprite_gear = _get_or_create_sprite("Sprite2D_Gear")
	_sprite_hand_far = _get_or_create_sprite("Sprite2D_HandFar")
	_sprite_hand_far.hframes = 1
	_sprite_hand_far.region_enabled = true
	_sprite_hands = _get_or_create_sprite("Sprite2D_Hands")
	_sprite_hands.hframes = 1
	_sprite_hands.region_enabled = true
	if _sprite_hand_far.get_index() > _sprite_hands.get_index():
		move_child(_sprite_hand_far, _sprite_hands.get_index())
	_sprite_shoe_throw = _get_or_create_sprite("Sprite2D_ShoeThrow")
	if ResourceLoader.exists("res://assets/sprites/modular/shoe_throw.png"):
		_sprite_shoe_throw.texture = load("res://assets/sprites/modular/shoe_throw.png") as Texture2D
	else:
		var abs_p: String = ProjectSettings.globalize_path("res://assets/sprites/modular/shoe_throw.png")
		var img := Image.new()
		if img.load(abs_p) == OK:
			_sprite_shoe_throw.texture = ImageTexture.create_from_image(img)
	_sprite_shoe_throw.visible = false


func _get_or_create_sprite(node_name: String) -> Sprite2D:
	var existing := get_node_or_null(node_name) as Sprite2D
	if existing != null:
		existing.hframes = SHEET_FRAMES
		existing.centered = true
		existing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		return existing
	var spr := Sprite2D.new()
	spr.name = node_name
	spr.hframes = SHEET_FRAMES
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(spr)
	return spr


func _get_or_create_animated(node_name: String) -> AnimatedSprite2D:
	var existing := get_node_or_null(node_name) as AnimatedSprite2D
	if existing != null:
		existing.centered = true
		existing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		return existing
	var anim := AnimatedSprite2D.new()
	anim.name = node_name
	anim.centered = true
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(anim)
	return anim


func apply_loadout(config: Dictionary) -> void:
	_ensure_layers()

	var arch_idx := clampi(int(config.get("archetype", config.get("archetype_id", 0))), 0, MAX_PART_INDEX)
	var def_part := arch_idx
	var skin_id := clampi(int(config.get("skin_id", def_part)), 0, MAX_PART_INDEX)
	var head_id := clampi(int(config.get("head_id", def_part)), 0, MAX_PART_INDEX)
	var torso_id := clampi(int(config.get("torso_id", def_part)), 0, MAX_PART_INDEX)
	var legs_id := clampi(int(config.get("legs_id", def_part)), 0, MAX_PART_INDEX)
	var acc_id := clampi(int(config.get("accessories_id", def_part)), 0, MAX_PART_INDEX)
	var hands_id := clampi(int(config.get("hands_id", def_part)), 0, MAX_PART_INDEX)

	var head_path := str(config.get("head_texture", config.get("skin_texture",
		"res://assets/sprites/modular/skin_%d.png" % skin_id)))
	var gear_path := str(config.get("gear_texture", config.get("helmet_texture",
		"res://assets/sprites/modular/head_%d.png" % head_id)))
	var torso_path := str(config.get("torso_texture",
		"res://assets/sprites/modular/torso_%d.png" % torso_id))
	var legs_path := str(config.get("legs_texture",
		"res://assets/sprites/modular/legs_%d.png" % legs_id))
	var back_path := str(config.get("back_texture", config.get("accessories_texture",
		"res://assets/sprites/modular/accessories_%d.png" % acc_id)))
	var hands_path := str(config.get("hands_texture",
		"res://assets/sprites/modular/hands_%d.png" % hands_id))

	_custom_full_sheet = false
	_anim_head.visible = true
	_sprite_gear.visible = true
	_sprite_back.visible = true
	_sprite_hands.visible = true
	if _sprite_hand_far != null:
		_sprite_hand_far.visible = true
	_anim_legs.visible = true
	_anim_torso.scale = Vector2.ONE

	_apply_animated_strip(_anim_head, head_path)
	_apply_animated_strip(_anim_torso, torso_path)
	_apply_animated_strip(_anim_legs, legs_path)
	_apply_sprite_strip(_sprite_gear, gear_path)
	_apply_sprite_strip(_sprite_back, back_path)
	_apply_sprite_strip(_sprite_hands, hands_path)
	_sprite_hands.hframes = 1
	_sprite_hands.region_enabled = true
	if _sprite_hand_far != null:
		_sprite_hand_far.texture = _sprite_hands.texture
		_sprite_hand_far.hframes = 1
		_sprite_hand_far.region_enabled = true

	_base_colors["shirt"] = _parse_color(config.get("shirt_color", Color.WHITE), Color.WHITE)
	_base_colors["pants"] = _parse_color(config.get("pants_color", Color.WHITE), Color.WHITE)
	_base_colors["skin"] = _parse_color(config.get("skin_color", Color.WHITE), Color.WHITE)
	_base_colors["helmet"] = _parse_color(config.get("helmet_color", Color.WHITE), Color.WHITE)
	_base_colors["gear"] = _parse_color(config.get("gear_color", _base_colors["helmet"]), Color.WHITE)

	if config.has("team_tint"):
		var team_tint := _parse_color(config.get("team_tint"), Color.WHITE)
		apply_layer_colors(team_tint, float(config.get("team_blend", 0.25)))
	else:
		apply_layer_colors(Color.WHITE, 0.0)

	if _manual_sync_mode:
		set_sync_frame(_manual_frame, _flip_h)
	else:
		play_state(_current_anim, _flip_h)


func apply_layer_colors(team_tint: Color = Color.WHITE, team_blend: float = 0.0) -> void:
	_ensure_layers()
	var blend := clampf(team_blend, 0.0, 1.0)
	var shirt: Color = _base_colors["shirt"]
	var pants: Color = _base_colors["pants"]
	var skin: Color = _base_colors["skin"]
	var helmet: Color = _base_colors["helmet"]
	var gear: Color = _base_colors["gear"]

	if blend > 0.0:
		shirt = shirt.lerp(team_tint, blend)
		pants = pants.lerp(team_tint, blend * 0.72)
		helmet = helmet.lerp(team_tint, blend)
		gear = gear.lerp(team_tint, blend * 0.65)

	if _custom_full_sheet:
		_anim_torso.modulate = Color.WHITE.lerp(team_tint, blend * 0.45) if blend > 0.0 else Color.WHITE
		_anim_legs.modulate = Color(1.0, 1.0, 1.0, 0.0)
		return
	_anim_torso.modulate = shirt
	_anim_legs.modulate = pants
	_anim_head.modulate = skin
	_sprite_hands.modulate = skin
	if _sprite_hand_far != null:
		_sprite_hand_far.modulate = skin
	_sprite_gear.modulate = helmet
	_sprite_back.modulate = gear


func set_headless(headless: bool) -> void:
	_ensure_layers()
	if _custom_full_sheet:
		return
	_anim_head.visible = not headless
	_sprite_gear.visible = not headless


func play_state(anim_name: String, flip_h: bool = false) -> void:
	_ensure_layers()
	_manual_sync_mode = false
	_flip_h = flip_h

	var target_anim := anim_name if ANIM_DEFS.has(anim_name) else "idle"
	var restart := (_current_anim != target_anim)
	_current_anim = target_anim

	for anim_node in [_anim_legs, _anim_torso, _anim_head]:
		anim_node.flip_h = flip_h
		if anim_node.sprite_frames != null and anim_node.sprite_frames.has_animation(target_anim):
			if restart or anim_node.animation != target_anim or not anim_node.is_playing():
				anim_node.play(target_anim)

	var mapped_frame := _get_sheet_frame_for_anim(target_anim, _anim_legs.frame)
	_apply_sheet_frame_to_sprites(mapped_frame)
	_apply_flip_to_sprites(flip_h)


func set_sync_frame(frame_idx: int, flip_h: bool = false) -> void:
	_ensure_layers()
	_manual_sync_mode = true
	_manual_frame = clampi(frame_idx, 0, SHEET_FRAMES - 1)
	_flip_h = flip_h

	var target_anim := _anim_name_for_sheet_frame(_manual_frame)
	var sub_frame := _sub_frame_for_sheet_frame(target_anim, _manual_frame)
	_current_anim = target_anim

	for anim_node in [_anim_legs, _anim_torso, _anim_head]:
		anim_node.flip_h = flip_h
		if anim_node.sprite_frames != null and anim_node.sprite_frames.has_animation(target_anim):
			anim_node.stop()
			anim_node.animation = target_anim
			anim_node.frame = sub_frame

	_apply_sheet_frame_to_sprites(_manual_frame)
	_apply_flip_to_sprites(flip_h)


func get_active_frame() -> int:
	if _sprite_gear != null:
		return _sprite_gear.frame
	return _manual_frame


func _apply_sprite_strip(spr: Sprite2D, path: String) -> void:
	var tex := _load_texture(path)
	if tex != null:
		spr.texture = tex
		var fh := maxi(tex.get_height(), 1)
		spr.scale = Vector2.ONE * (float(FRAME_SIZE.y) / float(fh))
	spr.hframes = SHEET_FRAMES


func _apply_animated_strip(anim_node: AnimatedSprite2D, path: String) -> void:
	if path.is_empty():
		return
	var sf := _get_or_build_sprite_frames(path)
	if sf != null:
		anim_node.sprite_frames = sf
		var tex := _load_texture(path)
		if tex != null:
			var fh := maxi(tex.get_height(), 1)
			anim_node.scale = Vector2.ONE * (float(FRAME_SIZE.y) / float(fh))


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	else:
		var abs_p: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_p):
			var img := Image.new()
			if img.load(abs_p) == OK:
				tex = ImageTexture.create_from_image(img)
	if tex != null:
		_tex_cache[path] = tex
	return tex


func _get_or_build_sprite_frames(path: String) -> SpriteFrames:
	if _frames_cache.has(path):
		return _frames_cache[path] as SpriteFrames

	var sheet := _load_texture(path)
	if sheet == null:
		return null

	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")

	var frame_w := maxi(1, int(sheet.get_width() / float(SHEET_FRAMES)))
	var frame_h := maxi(1, sheet.get_height())

	var atlases: Array[AtlasTexture] = []
	for i in range(SHEET_FRAMES):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		atlases.append(atlas)

	for anim_name in ANIM_DEFS.keys():
		var def: Dictionary = ANIM_DEFS[anim_name]
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, float(def["fps"]))
		sf.set_animation_loop(anim_name, bool(def["loop"]))
		var frames: Array = def["frames"]
		for raw_idx in frames:
			var idx := clampi(int(raw_idx), 0, SHEET_FRAMES - 1)
			sf.add_frame(anim_name, atlases[idx])

	_frames_cache[path] = sf
	return sf


func _get_sheet_frame_for_anim(anim_name: String, sub_frame: int) -> int:
	if not ANIM_DEFS.has(anim_name):
		return 0
	var frames: Array = ANIM_DEFS[anim_name]["frames"]
	if frames.is_empty():
		return 0
	return clampi(int(frames[clampi(sub_frame, 0, frames.size() - 1)]), 0, SHEET_FRAMES - 1)


func _anim_name_for_sheet_frame(sheet_frame: int) -> String:
	match sheet_frame:
		0, 1:
			return "idle"
		2, 3, 4:
			return "run"
		5:
			return "jetpack"
		6:
			return "firing"
		7:
			return "dead"
		_:
			return "idle"


func _sub_frame_for_sheet_frame(anim_name: String, sheet_frame: int) -> int:
	if not ANIM_DEFS.has(anim_name):
		return 0
	var frames: Array = ANIM_DEFS[anim_name]["frames"]
	var found := frames.find(sheet_frame)
	return found if found >= 0 else 0


func _apply_sheet_frame_to_sprites(sheet_frame: int) -> void:
	var safe := clampi(sheet_frame, 0, SHEET_FRAMES - 1)
	for spr in [_sprite_back, _sprite_gear]:
		if spr != null:
			spr.frame = safe
	if _sprite_hands != null and _sprite_hands.texture != null:
		var fw: float = float(_sprite_hands.texture.get_width()) / float(SHEET_FRAMES)
		var fh: float = float(_sprite_hands.texture.get_height())
		var half_w: float = fw * 0.5
		_sprite_hands.region_rect = Rect2(float(safe) * fw, 0.0, half_w, fh)
		if _sprite_hand_far != null:
			_sprite_hand_far.region_rect = Rect2(float(safe) * fw + half_w, 0.0, half_w, fh)


func _apply_flip_to_sprites(flip_h: bool) -> void:
	for spr in [_sprite_back, _sprite_gear, _sprite_hands, _sprite_hand_far]:
		if spr != null:
			spr.flip_h = flip_h
	var sign_x: float = -1.0 if flip_h else 1.0
	if _sprite_hands != null:
		_sprite_hands.offset = Vector2(-6.0 * sign_x, -6.0)
	if _sprite_hand_far != null:
		_sprite_hand_far.offset = Vector2(9.0 * sign_x, -6.0)


func _parse_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String:
		var text := (value as String).strip_edges()
		if Color.html_is_valid(text):
			return Color.html(text)
	return fallback


func apply_taunt_pose(_anim_name: String, _p: float, _facing_right: bool) -> void:
	pass


func reset_taunt_pose() -> void:
	pass


func play_shoe_throw_frame(progress_0_to_1: float, flip_h: bool) -> void:
	_ensure_layers()
	var vis_nodes: Array = [_anim_legs, _anim_torso] if _custom_full_sheet else [_sprite_back, _anim_legs, _anim_torso, _anim_head, _sprite_gear, _sprite_hands, _sprite_hand_far]
	for n in vis_nodes:
		if n != null:
			n.visible = true

	var dir: float = -1.0 if flip_h else 1.0
	var p: float = clampf(progress_0_to_1, 0.0, 1.0)
	if p <= 0.62:
		# Phase 1: Bend down toward lifted foot and pull shoe off
		var bend: float = sin((p / 0.62) * PI * 0.85)
		var upper_pos := Vector2(dir * 5.5 * bend, 5.0 * bend)
		var upper_rot: float = dir * 0.36 * bend
		for u in [_sprite_back, _anim_torso, _anim_head, _sprite_gear]:
			if u != null:
				u.position = upper_pos
				u.rotation = upper_rot
		if _sprite_hands != null:
			_sprite_hands.position = Vector2(dir * (-26.0 + 7.5 * bend), 6.0 + 11.0 * bend)
			_sprite_hands.rotation = dir * 0.55 * bend
		if _sprite_hand_far != null:
			_sprite_hand_far.position = Vector2(dir * (23.0 + 7.5 * bend), 6.0 + 11.0 * bend)
			_sprite_hand_far.rotation = dir * 0.55 * bend
		if _anim_legs != null:
			_anim_legs.position = Vector2(dir * 2.0 * bend, -2.5 * bend)
			_anim_legs.rotation = -dir * 0.12 * bend
	else:
		# Phase 2: Wind up overhead and hurl the shoe forward
		var throw_t: float = (p - 0.62) / 0.38
		var lean: float = lerpf(-0.28, 0.22, throw_t)
		var upper_pos := Vector2(dir * lean * 8.0, -1.5 * sin(throw_t * PI))
		var upper_rot: float = dir * lean
		for u in [_sprite_back, _anim_torso, _anim_head, _sprite_gear]:
			if u != null:
				u.position = upper_pos
				u.rotation = upper_rot
		if _sprite_hands != null:
			_sprite_hands.position = upper_pos + Vector2(dir * (-26.0 + 4.0), 6.0 - 6.0 * (1.0 - throw_t))
			_sprite_hands.rotation = dir * lerpf(-0.65, 0.35, throw_t)
		if _sprite_hand_far != null:
			_sprite_hand_far.position = upper_pos + Vector2(dir * (23.0 + 4.0), 6.0 - 6.0 * (1.0 - throw_t))
			_sprite_hand_far.rotation = dir * lerpf(-0.65, 0.35, throw_t)
		if _anim_legs != null:
			_anim_legs.position = Vector2.ZERO
			_anim_legs.rotation = 0.0

	if _sprite_shoe_throw != null:
		_sprite_shoe_throw.visible = true
		_sprite_shoe_throw.flip_h = flip_h
		_sprite_shoe_throw.frame = clampi(int(p * float(SHEET_FRAMES)), 0, SHEET_FRAMES - 1)


func stop_shoe_throw() -> void:
	_ensure_layers()
	if _sprite_shoe_throw != null:
		_sprite_shoe_throw.visible = false
	var vis_nodes: Array = [_anim_legs, _anim_torso] if _custom_full_sheet else [_sprite_back, _anim_legs, _anim_torso, _anim_head, _sprite_gear, _sprite_hands, _sprite_hand_far]
	for n in [_sprite_back, _anim_legs, _anim_torso, _anim_head, _sprite_gear, _sprite_hands, _sprite_hand_far]:
		if n != null:
			n.visible = (n in vis_nodes)
			n.position = Vector2.ZERO
			n.rotation = 0.0
	var sign_x: float = -1.0 if _flip_h else 1.0
	if _sprite_hands != null:
		_sprite_hands.position = Vector2(-26.0 * sign_x, 6.0)
	if _sprite_hand_far != null:
		_sprite_hand_far.position = Vector2(23.0 * sign_x, 6.0)


static func get_weapon_stance(w_id: int, dual: bool = false) -> String:
	if dual:
		return "dual"
	if w_id in [3, 4, 9]:
		return "pistol"
	if w_id in [10, 11, 12, 14]:
		return "bazooka"
	return "rifle"


func apply_weapon_arm_pose(stance: String, aim_ang: float, facing_r: bool, fire_kick: float = 0.0, throw_prog: float = -1.0) -> void:
	if _sprite_hands == null or _custom_full_sheet:
		return
	var dir: float = 1.0 if facing_r else -1.0
	if _current_anim == "dead" or stance == "none":
		_sprite_hands.z_index = 0
		_sprite_hands.position = Vector2(-26.0 * dir, 6.0)
		_sprite_hands.rotation = 0.0
		if _sprite_hand_far != null:
			_sprite_hand_far.position = Vector2(23.0 * dir, 6.0)
			_sprite_hand_far.rotation = 0.0
			_sprite_hand_far.scale = Vector2.ONE
		return

	var base_ang: float = 0.0 if facing_r else PI
	var rel_tilt: float = clampf(angle_difference(base_ang, aim_ang), -0.65, 0.65)

	if stance == "throw_bomb" or throw_prog >= 0.0:
		_sprite_hands.z_index = hands_z_over_weapon
		var p: float = clampf(throw_prog, 0.0, 1.0)
		if p <= 0.25:
			var wind_t: float = p / 0.25
			_sprite_hands.position = Vector2(-24.0 * dir, lerpf(6.0, 2.0, wind_t))
			_sprite_hands.rotation = dir * lerpf(0.0, 2.35, wind_t)
			if _sprite_hand_far != null:
				_sprite_hand_far.position = Vector2(20.0 * dir, 5.0)
				_sprite_hand_far.rotation = -dir * 0.90 * wind_t
		else:
			var swing_t: float = (p - 0.25) / 0.75
			_sprite_hands.position = Vector2(lerpf(-24.0, -12.0, swing_t) * dir, lerpf(2.0, 5.0, swing_t))
			_sprite_hands.rotation = dir * lerpf(2.35, 4.65, swing_t) + rel_tilt * 0.5 * swing_t
			if _sprite_hand_far != null:
				_sprite_hand_far.position = Vector2(20.0 * dir, 6.0)
				_sprite_hand_far.rotation = -dir * lerpf(0.90, 0.30, swing_t)
		return

	# Keep the near arm anchored at the real shoulder socket, resting over the gun grip
	_sprite_hands.z_index = hands_z_over_weapon
	if _sprite_hand_far != null:
		_sprite_hand_far.scale = Vector2(0.82, 0.82)
	match stance:
		"pistol":
			_sprite_hands.position = Vector2(-17.0 * dir, 6.0)
			_sprite_hands.rotation = -dir * 1.20 + rel_tilt * 0.18
			if _sprite_hand_far != null:
				_sprite_hand_far.position = Vector2(21.0 * dir, 6.0)
				_sprite_hand_far.rotation = -dir * 0.15
		"bazooka":
			_sprite_hands.position = Vector2(-18.0 * dir, 3.0)
			_sprite_hands.rotation = -dir * 1.28 + rel_tilt * 0.18
			if _sprite_hand_far != null:
				_sprite_hand_far.position = Vector2(18.0 * dir, 5.0)
				_sprite_hand_far.rotation = -dir * 0.35
		"dual":
			_sprite_hands.position = Vector2(-17.0 * dir, 6.0)
			_sprite_hands.rotation = -dir * 1.18 + rel_tilt * 0.18
			if _sprite_hand_far != null:
				_sprite_hand_far.position = Vector2(17.0 * dir, 5.0)
				_sprite_hand_far.rotation = -dir * 0.90 + rel_tilt * 0.18
		_:
			# "rifle" — anchored at shoulder (-18, 6), forearm & fist resting over gun
			_sprite_hands.position = Vector2(-18.0 * dir, 6.0)
			_sprite_hands.rotation = -dir * 1.18 + rel_tilt * 0.15
			if _sprite_hand_far != null:
				_sprite_hand_far.position = Vector2(20.0 * dir, 6.0)
				_sprite_hand_far.rotation = -dir * 0.22
