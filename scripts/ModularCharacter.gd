class_name ModularCharacter
extends Node2D
## Runtime modular 2D Chibi-Vector character assembler.
## Manages layered Sprite2D / AnimatedSprite2D parts, RGB/Hex tinting,
## and synchronized multi-layer animation playback across LAN peers.

const FRAME_SIZE := Vector2i(96, 96)
const SHEET_FRAMES := 8
const MAX_PART_INDEX := 33

const PART_OWNER_NAMES: Array[String] = [
	"contra", "mike_jones", "bruski", "commando", "rook_frost",
	"spartan", "centurion", "warlord", "crusader", "king",
	"pirate", "yagami", "dead_buddy", "nothing", "wraith",
	"mummy", "jack_47", "viper_x", "nyx", "akuza",
	"mirror_ogre", "ignis", "prism", "afera", "raven",
	"ray_lina", "draken", "soulless", "bramble", "jackson",
	"dummy_urban", "dummy_cyber", "dummy_desert", "dummy_stealth"
]

const FACE_ACC_FILES: Array[String] = [
	"faceacc_0_mustache",
	"faceacc_1_beard",
	"faceacc_2_goatee",
	"faceacc_3_shades",
	"faceacc_4_bandana",
	"faceacc_5_eyepatch"
]


static func get_part_owner_name(part_id: int) -> String:
	var idx: int = clampi(part_id, 0, PART_OWNER_NAMES.size() - 1)
	return PART_OWNER_NAMES[idx]


static func get_part_texture_path(part_kind: String, part_id: int) -> String:
	return "res://assets/sprites/modular/%s_%s.png" % [get_part_owner_name(part_id), part_kind]


static func get_face_acc_texture_path(face_acc_id: int) -> String:
	var idx: int = clampi(face_acc_id, 0, FACE_ACC_FILES.size() - 1)
	return "res://assets/sprites/modular/%s.png" % FACE_ACC_FILES[idx]


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
var _sprite_face_acc: Sprite2D
var _sprite_gear: Sprite2D
var _sprite_hands: Sprite2D
var _sprite_hand_far: Sprite2D
var _sprite_shoe_throw: Sprite2D

var _current_anim: String = "idle"
var _manual_sync_mode: bool = false
var _manual_frame: int = 0
var _flip_h: bool = false
var _custom_full_sheet: bool = false
var _has_headgear: bool = true
var _has_back_acc: bool = true
var _has_face_acc: bool = false
var _is_raven_wing: bool = false
var _is_wraith_cape: bool = false
var _is_nyx_tail: bool = false
var _is_ignis_head_fire: bool = false
var _is_ignis_hands_fire: bool = false
var _is_soulless_smoke: bool = false
var _wing_flap_t: float = 0.0
var _fire_anim_t: float = 0.0
var _jet_bob_t: float = 0.0
var freeze_procedural_anim: bool = false
var current_weapon_id: int = -1
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
var _current_part_id: int = 0

static var _pose_overrides: Dictionary = {}
static var _pose_overrides_loaded: bool = false


static func reload_pose_overrides() -> void:
	_pose_overrides = {"stances": {}, "agents": {}}
	_pose_overrides_loaded = true
	var pose_paths: Array[String] = ["res://assets/data/pose_overrides.json"]
	if OS.has_feature("editor"):
		pose_paths.append("user://pose_overrides.json")
	for path in pose_paths:
		if FileAccess.file_exists(path):
			var txt := FileAccess.get_file_as_string(path)
			var parsed: Variant = JSON.parse_string(txt)
			if parsed is Dictionary:
				var d := parsed as Dictionary
				if d.has("stances") and d["stances"] is Dictionary:
					for k in d["stances"]:
						_pose_overrides["stances"][k] = d["stances"][k]
				if d.has("agents") and d["agents"] is Dictionary:
					for ak in d["agents"]:
						_pose_overrides["agents"][str(ak)] = d["agents"][ak]


static func _merge_pose_bucket(dst: Dictionary, bucket: Variant) -> void:
	if not (bucket is Dictionary):
		return
	var b := bucket as Dictionary
	for pk in b:
		if b[pk] is Dictionary:
			dst[pk] = (b[pk] as Dictionary).duplicate(true)


static func get_pose_override(part_id: int, stance: String, anim_name: String = "", frame_idx: int = -1, weapon_id: int = -1) -> Dictionary:
	if not _pose_overrides_loaded:
		reload_pose_overrides()
	var merged: Dictionary = {}
	var anim_key: String = (stance + "@" + anim_name) if anim_name != "" else ""
	var frame_key: String = (anim_key + "#f" + str(frame_idx)) if (anim_key != "" and frame_idx >= 0) else ""
	var stances: Dictionary = _pose_overrides.get("stances", {})
	if stances.has(stance):
		_merge_pose_bucket(merged, stances[stance])
	if anim_key != "" and stances.has(anim_key):
		_merge_pose_bucket(merged, stances[anim_key])
	if frame_key != "" and stances.has(frame_key):
		_merge_pose_bucket(merged, stances[frame_key])
	var agents: Dictionary = _pose_overrides.get("agents", {})
	var ak := str(part_id)
	if agents.has(ak) and agents[ak] is Dictionary:
		var ast: Dictionary = agents[ak]
		if ast.has(stance):
			_merge_pose_bucket(merged, ast[stance])
		if anim_key != "" and ast.has(anim_key):
			_merge_pose_bucket(merged, ast[anim_key])
		if frame_key != "" and ast.has(frame_key):
			_merge_pose_bucket(merged, ast[frame_key])
	if weapon_id >= 0 and stance != "none" and stance != "throw_bomb":
		var ws: String = "w" + str(weapon_id)
		var w_anim: String = (ws + "@" + anim_name) if anim_name != "" else ""
		var w_frame: String = (w_anim + "#f" + str(frame_idx)) if (w_anim != "" and frame_idx >= 0) else ""
		if stances.has(ws):
			_merge_pose_bucket(merged, stances[ws])
		if w_anim != "" and stances.has(w_anim):
			_merge_pose_bucket(merged, stances[w_anim])
		if w_frame != "" and stances.has(w_frame):
			_merge_pose_bucket(merged, stances[w_frame])
		if agents.has(ak) and agents[ak] is Dictionary:
			var ast_w: Dictionary = agents[ak]
			if ast_w.has(ws):
				_merge_pose_bucket(merged, ast_w[ws])
			if w_anim != "" and ast_w.has(w_anim):
				_merge_pose_bucket(merged, ast_w[w_anim])
			if w_frame != "" and ast_w.has(w_frame):
				_merge_pose_bucket(merged, ast_w[w_frame])
	return merged


func _ready() -> void:
	_ensure_layers()
	set_process(true)


func _process(delta: float) -> void:
	if _current_anim == "jetpack" and not freeze_procedural_anim:
		_jet_bob_t += delta * 9.0
		var dir_lean: float = -1.0 if _flip_h else 1.0
		var target_rot: float = dir_lean * (0.11 + sin(_jet_bob_t * 0.75) * 0.04)
		rotation = lerpf(rotation, target_rot, clampf(delta * 10.0, 0.0, 1.0))
	else:
		_jet_bob_t = 0.0
		if freeze_procedural_anim:
			rotation = 0.0
		else:
			rotation = lerpf(rotation, 0.0, clampf(delta * 12.0, 0.0, 1.0))
	if (_is_raven_wing or _is_wraith_cape or _is_nyx_tail) and _sprite_back != null and is_instance_valid(_sprite_back) and _sprite_back.texture != null:
		var base_s: float = float(FRAME_SIZE.y) / float(maxi(_sprite_back.texture.get_height(), 1))
		if _current_anim == "jetpack":
			var dir_sign: float = -1.0 if _flip_h else 1.0
			if _is_raven_wing:
				_wing_flap_t += delta * 18.0
				var flap: float = sin(_wing_flap_t)
				_sprite_back.rotation = dir_sign * (-0.18 + flap * 0.38)
				_sprite_back.position = Vector2(0.0, flap * 4.5 - 2.0)
				_sprite_back.scale = Vector2(base_s * (1.0 + flap * 0.08), base_s * (1.0 - flap * 0.14))
			elif _is_nyx_tail:
				_wing_flap_t += delta * 8.0
				var wag: float = sin(_wing_flap_t)
				var wag2: float = cos(_wing_flap_t * 1.3)
				_sprite_back.rotation = dir_sign * (wag * 0.08)
				_sprite_back.position = Vector2(dir_sign * 1.5, wag * 0.8)
				_sprite_back.scale = Vector2(base_s * (1.0 + wag * 0.02), base_s * (1.0 - wag2 * 0.03))
			else:
				_wing_flap_t += delta * 14.0
				var wave: float = sin(_wing_flap_t)
				var wave2: float = cos(_wing_flap_t * 1.4)
				_sprite_back.rotation = dir_sign * (0.14 + wave * 0.16)
				_sprite_back.position = Vector2(-dir_sign * (2.0 + wave2 * 2.0), wave * 3.0 - 1.0)
				_sprite_back.scale = Vector2(base_s * (1.06 + wave * 0.09), base_s * (0.94 - wave2 * 0.08))
		else:
			_wing_flap_t = 0.0
			_sprite_back.rotation = lerpf(_sprite_back.rotation, 0.0, clampf(delta * 14.0, 0.0, 1.0))
			_sprite_back.position = _sprite_back.position.lerp(Vector2.ZERO, clampf(delta * 14.0, 0.0, 1.0))
			_sprite_back.scale = Vector2.ONE * base_s
	if _is_ignis_head_fire or _is_ignis_hands_fire or _is_soulless_smoke:
		_fire_anim_t += delta * 14.0
		queue_redraw()
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
	_sprite_face_acc = _get_or_create_sprite("Sprite2D_FaceAcc")
	_sprite_gear = _get_or_create_sprite("Sprite2D_Gear")
	_sprite_hand_far = _get_or_create_sprite("Sprite2D_HandFar")
	_sprite_hand_far.hframes = 1
	_sprite_hand_far.region_enabled = true
	_sprite_hands = _get_or_create_sprite("Sprite2D_Hands")
	_sprite_hands.hframes = 1
	_sprite_hands.region_enabled = true
	if _sprite_hand_far.get_index() > _anim_torso.get_index():
		move_child(_sprite_hand_far, _anim_torso.get_index())
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
	var raw_head_id := int(config.get("head_id", def_part))
	var has_explicit_gear_tex := config.has("gear_texture") or config.has("helmet_texture")
	_has_headgear = (raw_head_id >= 0) or has_explicit_gear_tex
	var head_id := clampi(raw_head_id, 0, MAX_PART_INDEX) if raw_head_id >= 0 else skin_id
	_current_part_id = head_id
	var torso_id := clampi(int(config.get("torso_id", def_part)), 0, MAX_PART_INDEX)
	var legs_id := clampi(int(config.get("legs_id", def_part)), 0, MAX_PART_INDEX)
	var raw_acc_id := int(config.get("accessories_id", def_part))
	var has_explicit_back_tex := config.has("back_texture") or config.has("accessories_texture")
	_has_back_acc = (raw_acc_id >= 0) or has_explicit_back_tex
	var acc_id := clampi(raw_acc_id, 0, MAX_PART_INDEX) if raw_acc_id >= 0 else def_part
	var hands_id := clampi(int(config.get("hands_id", def_part)), 0, MAX_PART_INDEX)
	var raw_face_acc_id := int(config.get("face_acc_id", -1))
	_has_face_acc = (raw_face_acc_id >= 0 and raw_face_acc_id < FACE_ACC_FILES.size())

	var head_path := str(config.get("head_texture", config.get("skin_texture",
		get_part_texture_path("skin", skin_id))))
	var gear_path := str(config.get("gear_texture", config.get("helmet_texture",
		get_part_texture_path("head", head_id))))
	var torso_path := str(config.get("torso_texture",
		get_part_texture_path("torso", torso_id)))
	var legs_path := str(config.get("legs_texture",
		get_part_texture_path("legs", legs_id)))
	var back_path := str(config.get("back_texture", config.get("accessories_texture",
		get_part_texture_path("accessories", acc_id))))
	var hands_path := str(config.get("hands_texture",
		get_part_texture_path("hands", hands_id)))

	_custom_full_sheet = false
	_anim_head.visible = true
	if _sprite_face_acc != null:
		_sprite_face_acc.visible = _has_face_acc
	_sprite_gear.visible = _has_headgear
	_sprite_back.visible = _has_back_acc
	_sprite_hands.visible = true
	if _sprite_hand_far != null:
		_sprite_hand_far.visible = true
	_anim_legs.visible = true
	_anim_torso.scale = Vector2.ONE

	_apply_animated_strip(_anim_head, head_path)
	_apply_animated_strip(_anim_torso, torso_path)
	_apply_animated_strip(_anim_legs, legs_path)
	if _has_face_acc and _sprite_face_acc != null:
		_apply_sprite_strip(_sprite_face_acc, get_face_acc_texture_path(raw_face_acc_id))
	if _has_headgear:
		_apply_sprite_strip(_sprite_gear, gear_path)
	if _has_back_acc:
		_apply_sprite_strip(_sprite_back, back_path)
	_is_raven_wing = _has_back_acc and ((acc_id == 24) or back_path.ends_with("raven_accessories.png"))
	_is_wraith_cape = _has_back_acc and ((acc_id == 14) or (acc_id == 21) or (acc_id == 26) or (acc_id == 27) or back_path.ends_with("wraith_accessories.png") or back_path.ends_with("ignis_accessories.png") or back_path.ends_with("draken_accessories.png") or back_path.ends_with("soulless_accessories.png"))
	_is_nyx_tail = _has_back_acc and ((acc_id == 18) or back_path.ends_with("nyx_accessories.png"))
	_is_ignis_head_fire = _has_headgear and ((head_id == 21) or gear_path.ends_with("ignis_head.png"))
	_is_ignis_hands_fire = (hands_id == 21) or hands_path.ends_with("ignis_hands.png")
	_is_soulless_smoke = _has_headgear and ((head_id == 27) or gear_path.ends_with("soulless_head.png"))
	_apply_sprite_strip(_sprite_hands, hands_path)
	_sprite_hands.hframes = 1
	_sprite_hands.region_enabled = true
	if _sprite_hand_far != null:
		_sprite_hand_far.texture = _sprite_hands.texture
		_sprite_hand_far.scale = _sprite_hands.scale
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
	queue_redraw()


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
	if _sprite_face_acc != null:
		_sprite_face_acc.modulate = Color.WHITE.lerp(team_tint, blend * 0.20) if blend > 0.0 else Color.WHITE


func set_headless(headless: bool) -> void:
	_ensure_layers()
	if _custom_full_sheet:
		return
	_anim_head.visible = not headless
	if _sprite_face_acc != null:
		_sprite_face_acc.visible = (not headless) and _has_face_acc
	_sprite_gear.visible = (not headless) and _has_headgear


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
		var bs := Vector2.ONE * (float(FRAME_SIZE.y) / float(fh))
		spr.scale = bs
		spr.set_meta("base_scale", bs)
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
			var bs := Vector2.ONE * (float(FRAME_SIZE.y) / float(fh))
			anim_node.scale = bs
			anim_node.set_meta("base_scale", bs)


func _apply_part_scale(node: Node2D, ov_part: Dictionary) -> void:
	if node == null:
		return
	var bs: Vector2 = node.get_meta("base_scale", Vector2.ONE) if node.has_meta("base_scale") else node.scale
	node.scale = Vector2(bs.x * float(ov_part.get("sx", 1.0)), bs.y * float(ov_part.get("sy", 1.0)))


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
	for spr in [_sprite_back, _sprite_face_acc, _sprite_gear]:
		if spr != null and spr.texture != null:
			spr.frame = safe
	if _sprite_hands != null and _sprite_hands.texture != null:
		var fw: float = float(_sprite_hands.texture.get_width()) / float(SHEET_FRAMES)
		var fh: float = float(_sprite_hands.texture.get_height())
		var half_w: float = fw * 0.5
		_sprite_hands.region_rect = Rect2(float(safe) * fw, 0.0, half_w, fh)
		if _sprite_hand_far != null:
			_sprite_hand_far.region_rect = Rect2(float(safe) * fw + half_w, 0.0, half_w, fh)


func _apply_flip_to_sprites(flip_h: bool) -> void:
	for spr in [_sprite_back, _sprite_face_acc, _sprite_gear, _sprite_hands, _sprite_hand_far]:
		if spr != null:
			spr.flip_h = flip_h
	var sign_x: float = -1.0 if flip_h else 1.0
	if _sprite_hands != null:
		_sprite_hands.offset = Vector2(-6.0 * sign_x, -6.0)
	if _sprite_hand_far != null:
		_sprite_hand_far.offset = Vector2(9.0 * sign_x, -6.0)


func _draw() -> void:
	if _is_soulless_smoke and is_instance_valid(_sprite_gear) and _sprite_gear.visible:
		_draw_soulless_head_smoke(_sprite_gear.position + Vector2(0.0, -32.0))


func _draw_soulless_head_smoke(origin: Vector2) -> void:
	var t: float = _fire_anim_t * 0.11
	for i in range(6):
		var phase: float = fmod(t + float(i) / 6.0, 1.0)
		var drift_x: float = sin((t + float(i)) * 4.2) * (6.0 + phase * 8.0) + (float(i % 3) - 1.0) * 5.0
		var rise_y: float = -phase * 28.0
		var r: float = lerpf(4.0, 10.5, phase)
		var a: float = sin(phase * PI) * 0.52
		var p: Vector2 = origin + Vector2(drift_x, rise_y)
		draw_circle(p, r, Color(0.06, 0.07, 0.10, a))
		draw_circle(p + Vector2(-1.5, -1.5), r * 0.55, Color(0.20, 0.22, 0.28, a * 0.65))


func _draw_animated_flame_cluster(origin: Vector2, sc: float, phase: float) -> void:
	var t: float = _fire_anim_t + phase
	for i in range(4):
		var fi: float = float(i)
		var ox: float = (fi - 1.5) * 4.5 * sc
		var sway: float = sin(t * 1.1 + fi * 1.8) * 3.2 * sc
		var h: float = (13.0 + sin(t * 1.4 + fi * 2.3) * 4.5) * sc
		var w: float = 4.2 * sc
		var base := origin + Vector2(ox, 0.0)
		var tip := base + Vector2(sway, -h)
		var pts := PackedVector2Array([
			base + Vector2(-w, 0.0),
			base + Vector2(-w * 0.55 + sway * 0.4, -h * 0.55),
			tip,
			base + Vector2(w * 0.55 + sway * 0.4, -h * 0.55),
			base + Vector2(w, 0.0),
		])
		draw_colored_polygon(pts, Color(1.0, 0.34, 0.05, 0.85))
		var core_pts := PackedVector2Array([
			base + Vector2(-w * 0.5, 0.0),
			base + Vector2(sway * 0.45, -h * 0.72),
			base + Vector2(w * 0.5, 0.0),
		])
		draw_colored_polygon(core_pts, Color(1.0, 0.82, 0.24, 0.90))
	for ei in range(2):
		var ep: float = fmod(t * 0.14 + float(ei) * 0.5, 1.0)
		var ex: float = sin(t * 0.8 + float(ei) * 3.1) * 7.0 * sc
		var ey: float = -ep * 20.0 * sc - 4.0 * sc
		draw_circle(origin + Vector2(ex, ey), 1.6 * sc, Color(1.0, 0.88, 0.35, 1.0 - ep))


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
	var vis_nodes: Array = [_anim_legs, _anim_torso] if _custom_full_sheet else [_sprite_back, _anim_legs, _anim_torso, _anim_head, _sprite_face_acc, _sprite_gear, _sprite_hands, _sprite_hand_far]
	for n in vis_nodes:
		if n != null:
			n.visible = true
	if _sprite_back != null:
		_sprite_back.visible = (not _custom_full_sheet) and _has_back_acc
	if _sprite_face_acc != null:
		_sprite_face_acc.visible = (not _custom_full_sheet) and _has_face_acc
	if _sprite_gear != null:
		_sprite_gear.visible = (not _custom_full_sheet) and _has_headgear

	var dir: float = -1.0 if flip_h else 1.0
	var p: float = clampf(progress_0_to_1, 0.0, 1.0)
	if p <= 0.62:
		# Phase 1: Bend down toward lifted foot and pull shoe off
		var bend: float = sin((p / 0.62) * PI * 0.85)
		var upper_pos := Vector2(dir * 5.5 * bend, 5.0 * bend)
		var upper_rot: float = dir * 0.36 * bend
		for u in [_sprite_back, _anim_torso, _anim_head, _sprite_face_acc, _sprite_gear]:
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
		for u in [_sprite_back, _anim_torso, _anim_head, _sprite_face_acc, _sprite_gear]:
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
	var vis_nodes: Array = [_anim_legs, _anim_torso] if _custom_full_sheet else [_sprite_back, _anim_legs, _anim_torso, _anim_head, _sprite_face_acc, _sprite_gear, _sprite_hands, _sprite_hand_far]
	for n in [_sprite_back, _anim_legs, _anim_torso, _anim_head, _sprite_face_acc, _sprite_gear, _sprite_hands, _sprite_hand_far]:
		if n != null:
			n.visible = (n in vis_nodes)
			n.position = Vector2.ZERO
			n.rotation = 0.0
	if _sprite_back != null:
		_sprite_back.visible = (not _custom_full_sheet) and _has_back_acc
	if _sprite_face_acc != null:
		_sprite_face_acc.visible = (not _custom_full_sheet) and _has_face_acc
	if _sprite_gear != null:
		_sprite_gear.visible = (not _custom_full_sheet) and _has_headgear
	var sign_x: float = -1.0 if _flip_h else 1.0
	if _sprite_hands != null:
		_sprite_hands.position = Vector2(-26.0 * sign_x, 6.0)
	if _sprite_hand_far != null:
		_sprite_hand_far.position = Vector2(23.0 * sign_x, 6.0)


static func get_weapon_stance(w_id: int) -> String:
	if w_id in [3, 4, 9, 19, 20]:
		return "pistol"
	if w_id in [10, 11, 12]:
		return "bazooka"
	return "rifle"


func apply_weapon_arm_pose(stance: String, aim_ang: float, facing_r: bool, fire_kick: float = 0.0, throw_prog: float = -1.0) -> void:
	if _sprite_hands == null or _custom_full_sheet:
		return
	var dir: float = 1.0 if facing_r else -1.0
	var active_stance: String = "throw_bomb" if (stance == "throw_bomb" or throw_prog >= 0.0) else stance
	var active_frame: int = _manual_frame if _manual_sync_mode else (_get_sheet_frame_for_anim(_current_anim, _anim_legs.frame) if _anim_legs != null else 0)
	var ov: Dictionary = get_pose_override(_current_part_id, active_stance, _current_anim, active_frame, current_weapon_id)

	var head_ov: Dictionary = ov.get("head", {})
	var jet_bob_y: float = sin(_jet_bob_t) * 3.0 if (_current_anim == "jetpack" and not freeze_procedural_anim) else 0.0

	var head_pos := Vector2(float(head_ov.get("x", 0.0)) * dir, float(head_ov.get("y", 0.0)) + jet_bob_y)
	var head_rot: float = dir * deg_to_rad(float(head_ov.get("rot", 0.0)))
	var head_z: int = int(head_ov.get("z", 0))
	if _sprite_face_acc != null:
		_sprite_face_acc.position = head_pos
		_sprite_face_acc.rotation = head_rot
		_sprite_face_acc.z_index = head_z
		_apply_part_scale(_sprite_face_acc, head_ov)
	if _sprite_gear != null:
		_sprite_gear.position = head_pos
		_sprite_gear.rotation = head_rot
		_sprite_gear.z_index = head_z
		_apply_part_scale(_sprite_gear, head_ov)
	if _anim_head != null:
		_anim_head.position = head_pos
		_anim_head.rotation = head_rot
		_anim_head.z_index = head_z
		_apply_part_scale(_anim_head, head_ov)
	var torso_ov: Dictionary = ov.get("torso", {})
	if _anim_torso != null:
		_anim_torso.position = Vector2(float(torso_ov.get("x", 0.0)) * dir, float(torso_ov.get("y", 0.0)) + jet_bob_y)
		_anim_torso.rotation = dir * deg_to_rad(float(torso_ov.get("rot", 0.0)))
		_anim_torso.z_index = int(torso_ov.get("z", 0))
		_apply_part_scale(_anim_torso, torso_ov)
	var legs_ov: Dictionary = ov.get("legs", {})
	if _anim_legs != null:
		_anim_legs.position = Vector2(float(legs_ov.get("x", 0.0)) * dir, float(legs_ov.get("y", 0.0)) + jet_bob_y)
		_anim_legs.rotation = dir * deg_to_rad(float(legs_ov.get("rot", 0.0)))
		_anim_legs.z_index = int(legs_ov.get("z", 0))
		_apply_part_scale(_anim_legs, legs_ov)
	var back_ov: Dictionary = ov.get("back", {})
	if _sprite_back != null and not ((_is_raven_wing or _is_wraith_cape or _is_nyx_tail) and _current_anim == "jetpack"):
		_sprite_back.position = Vector2(float(back_ov.get("x", 0.0)) * dir, float(back_ov.get("y", 0.0)) + jet_bob_y)
		_sprite_back.rotation = dir * deg_to_rad(float(back_ov.get("rot", 0.0)))
		_sprite_back.z_index = int(back_ov.get("z", 0))
		_apply_part_scale(_sprite_back, back_ov)

	if _current_anim == "dead" or stance == "none":
		var hn_ov: Dictionary = ov.get("hand_near", {})
		var hf_ov: Dictionary = ov.get("hand_far", {})
		_sprite_hands.z_index = int(hn_ov.get("z", 1))
		_sprite_hands.position = Vector2(float(hn_ov.get("x", -15.5)) * dir, float(hn_ov.get("y", 8.0)) + jet_bob_y)
		_sprite_hands.rotation = dir * deg_to_rad(float(hn_ov.get("rot", 0.0)))
		_apply_part_scale(_sprite_hands, hn_ov)
		if _sprite_hand_far != null:
			_sprite_hand_far.z_index = int(hf_ov.get("z", 0))
			_sprite_hand_far.position = Vector2(float(hf_ov.get("x", 23.0)) * dir, float(hf_ov.get("y", 7.5)) + jet_bob_y)
			_sprite_hand_far.rotation = dir * deg_to_rad(float(hf_ov.get("rot", 0.0)))
			_apply_part_scale(_sprite_hand_far, hf_ov)
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
	var defs: Dictionary = get_default_hand_pose(stance)
	var hn_def: Vector2 = defs["hn_pos"]
	var hn_rot_def: float = float(defs["hn_rot"])
	var hf_def: Vector2 = defs["hf_pos"]
	var hf_rot_def: float = float(defs["hf_rot"])
	var tilt_mul: float = float(defs["tilt_mul"])
	var far_tilt_mul: float = float(defs["far_tilt_mul"])
	var hn_w: Dictionary = ov.get("hand_near", {})
	var hf_w: Dictionary = ov.get("hand_far", {})
	var kick_px: float = 0.0
	if fire_kick > 0.0:
		kick_px = fire_kick if fire_kick > 0.5 else (fire_kick / 0.15) * 3.5
	var kick_vec: Vector2 = Vector2.from_angle(aim_ang) * kick_px
	var kick_rot: float = dir * deg_to_rad(kick_px * 1.8)
	_sprite_hands.z_index = int(hn_w.get("z", maxi(1, hands_z_over_weapon)))
	_sprite_hands.position = Vector2(float(hn_w.get("x", hn_def.x)) * dir, float(hn_w.get("y", hn_def.y)) + jet_bob_y) - kick_vec
	var hn_rot_rad: float = deg_to_rad(float(hn_w["rot"])) if hn_w.has("rot") else hn_rot_def
	_sprite_hands.rotation = dir * hn_rot_rad + rel_tilt * tilt_mul - kick_rot
	_apply_part_scale(_sprite_hands, hn_w)
	if _sprite_hand_far != null:
		_sprite_hand_far.z_index = int(hf_w.get("z", 0))
		_apply_part_scale(_sprite_hand_far, hf_w)
		var far_kick: Vector2 = kick_vec * 0.65 if stance == "dual" else Vector2.ZERO
		_sprite_hand_far.position = Vector2(float(hf_w.get("x", hf_def.x)) * dir, float(hf_w.get("y", hf_def.y)) + jet_bob_y) - far_kick
		var hf_rot_rad: float = deg_to_rad(float(hf_w["rot"])) if hf_w.has("rot") else hf_rot_def
		_sprite_hand_far.rotation = dir * hf_rot_rad + rel_tilt * far_tilt_mul


static func get_default_hand_pose(stance: String) -> Dictionary:
	var hn_def := Vector2(-18.0, 6.0)
	var hn_rot_def: float = -1.18
	var hf_def := Vector2(20.0, 6.0)
	var hf_rot_def: float = -0.22
	var tilt_mul: float = 0.25
	var far_tilt_mul: float = 0.0
	match stance:
		"pistol":
			hn_def = Vector2(-17.0, 6.0); hn_rot_def = -1.20; tilt_mul = 0.28
			hf_def = Vector2(21.0, 6.0); hf_rot_def = -0.15
		"bazooka":
			hn_def = Vector2(-18.0, 3.0); hn_rot_def = -1.28; tilt_mul = 0.25
			hf_def = Vector2(18.0, 5.0); hf_rot_def = -0.35
		"dual":
			hn_def = Vector2(-17.0, 6.0); hn_rot_def = -1.18; tilt_mul = 0.28
			hf_def = Vector2(17.0, 5.0); hf_rot_def = -0.90; far_tilt_mul = 0.28
		"ult_laser":
			hn_def = Vector2(14.0, 6.0); hn_rot_def = -1.25; tilt_mul = 0.85
			hf_def = Vector2(16.0, 4.0); hf_rot_def = 1.05; far_tilt_mul = 0.85
	return {
		"hn_pos": hn_def,
		"hn_rot": hn_rot_def,
		"hf_pos": hf_def,
		"hf_rot": hf_rot_def,
		"tilt_mul": tilt_mul,
		"far_tilt_mul": far_tilt_mul,
	}


func get_weapon_socket_transform(stance: String, facing_r: bool, w_ov: Dictionary = {}, default_wy: float = 9.0) -> Dictionary:
	var dir: float = 1.0 if facing_r else -1.0
	var defs: Dictionary = get_default_hand_pose(stance)
	var hn_def: Vector2 = defs["hn_pos"]
	var hn_rot_def: float = float(defs["hn_rot"])

	var active_stance: String = "throw_bomb" if stance == "throw_bomb" else stance
	var active_frame: int = _manual_frame if _manual_sync_mode else (_get_sheet_frame_for_anim(_current_anim, _anim_legs.frame) if _anim_legs != null else 0)
	var ov: Dictionary = get_pose_override(_current_part_id, active_stance, _current_anim, active_frame, current_weapon_id)
	var hn_w: Dictionary = ov.get("hand_near", {})
	var pose_hn_pos := Vector2(float(hn_w.get("x", hn_def.x)) * dir, float(hn_w.get("y", hn_def.y)))
	var hn_pose_rot_rad: float = deg_to_rad(float(hn_w["rot"])) if hn_w.has("rot") else hn_rot_def
	var pose_hn_rot: float = dir * hn_pose_rot_rad

	var cur_hn_pos: Vector2 = _sprite_hands.position if _sprite_hands != null else pose_hn_pos
	var cur_hn_rot: float = _sprite_hands.rotation if _sprite_hands != null else pose_hn_rot
	var runtime_delta_rot: float = cur_hn_rot - pose_hn_rot

	var wx: float = float(w_ov.get("x", 2.0))
	var wy: float = float(w_ov.get("y", default_wy))
	var wrot: float = dir * deg_to_rad(float(w_ov.get("rot", 0.0)))
	var wz: int = int(w_ov.get("z", 0))

	# Socket grip offset from the posed Near Hand pivot to the Weapon pivot
	var grip_offset: Vector2 = Vector2(wx * dir, wy) - pose_hn_pos
	var socket_pos: Vector2 = cur_hn_pos + grip_offset.rotated(runtime_delta_rot)
	var socket_rot: float = wrot + runtime_delta_rot

	# Off-hand socket for Dual Stance secondary gun attached to Far Hand
	var hf_def: Vector2 = defs["hf_pos"]
	var hf_rot_def: float = float(defs["hf_rot"])
	var hf_w: Dictionary = ov.get("hand_far", {})
	var pose_hf_pos := Vector2(float(hf_w.get("x", hf_def.x)) * dir, float(hf_w.get("y", hf_def.y)))
	var hf_pose_rot_rad: float = deg_to_rad(float(hf_w["rot"])) if hf_w.has("rot") else hf_rot_def
	var pose_hf_rot: float = dir * hf_pose_rot_rad
	var cur_hf_pos: Vector2 = _sprite_hand_far.position if _sprite_hand_far != null else pose_hf_pos
	var cur_hf_rot: float = _sprite_hand_far.rotation if _sprite_hand_far != null else pose_hf_rot
	var far_runtime_rot: float = cur_hf_rot - pose_hf_rot
	var far_grip_offset: Vector2 = Vector2((wx + 12.0) * dir, wy + 4.0) - pose_hf_pos
	var far_socket_pos: Vector2 = cur_hf_pos + far_grip_offset.rotated(far_runtime_rot)
	var far_socket_rot: float = wrot + far_runtime_rot

	return {
		"pos": socket_pos,
		"rot": socket_rot,
		"pose_rot": wrot,
		"hand_delta_rot": runtime_delta_rot,
		"z": wz,
		"far_pos": far_socket_pos,
		"far_rot": far_socket_rot,
	}


