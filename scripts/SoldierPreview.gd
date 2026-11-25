class_name SoldierPreview
extends Node2D

const TEX_WEAPONS: Texture2D = preload("res://assets/sprites/weapons_selection_sheet.png")

var anim_mode: int = 0
var shuffle_guns: bool = false
var hide_weapons: bool = false
var _timer: float = 0.0
var _preview_weapon_id: int = -1

var _modular: ModularCharacter
var _weapon_pivot: Node2D
var _gun_p: Sprite2D
var _gun_s: Sprite2D


func _ready() -> void:
	_modular = ModularCharacter.new()
	_modular.name = "ModularCharacter"
	_modular.scale = Vector2(0.75, 0.75)
	add_child(_modular)

	_weapon_pivot = Node2D.new()
	_weapon_pivot.position = Vector2(2, 9)
	add_child(_weapon_pivot)

	_gun_p = Sprite2D.new()
	_gun_p.texture = TEX_WEAPONS
	_gun_p.hframes = WeaponData.SELECTION_COLS
	_gun_p.vframes = WeaponData.SELECTION_ROWS
	_gun_p.position = Vector2(16, 0)
	_gun_p.scale = Vector2(0.23, 0.23)
	_weapon_pivot.add_child(_gun_p)

	refresh_from_profile()


func refresh_from_profile() -> void:
	if not is_node_ready() or _modular == null:
		return

	_modular.apply_loadout(ProfileManager.to_dict())

	var w_id: int = ProfileManager.primary_weapon_id
	if shuffle_guns:
		const BIG_GUN_IDS: Array[int] = [0, 1, 2, 5, 6, 7, 8, 10]
		var next_w: int = BIG_GUN_IDS[randi() % BIG_GUN_IDS.size()]
		if next_w == _preview_weapon_id:
			var idx: int = BIG_GUN_IDS.find(next_w)
			next_w = BIG_GUN_IDS[(idx + 1) % BIG_GUN_IDS.size()]
		w_id = next_w
	_apply_preview_weapon(w_id)


func _apply_preview_weapon(w_id: int) -> void:
	_preview_weapon_id = w_id
	if hide_weapons:
		_weapon_pivot.visible = false
		return
	_weapon_pivot.visible = true
	var spec: Dictionary = WeaponData.get_weapon_sprite_spec(w_id, ProfileManager.weapon_skin_id)
	_gun_p.texture = spec["tex"] as Texture2D
	_gun_p.hframes = int(spec["hframes"])
	_gun_p.vframes = int(spec["vframes"])
	_gun_p.frame = int(spec["frame"])


func _process(delta: float) -> void:
	if _modular == null:
		return
	_timer += delta
	var frame_idx: int = 0
	match anim_mode:
		1:
			var run_seq: Array[int] = [2, 3, 4, 3]
			frame_idx = run_seq[int(_timer * 7.0) % run_seq.size()]
		2:
			frame_idx = 5
		3:
			frame_idx = 6
		_:
			frame_idx = 0 if int(_timer * 2.2) % 2 == 0 else 1

	_modular.set_sync_frame(frame_idx, false)

	if hide_weapons:
		_weapon_pivot.visible = false
		_modular.apply_weapon_arm_pose("none", 0.0, true, 0.0, -1.0)
		return
	var active_w: int = _preview_weapon_id if (shuffle_guns and _preview_weapon_id >= 0) else ProfileManager.primary_weapon_id
	var stance: String = ModularCharacter.get_weapon_stance(active_w)
	var ov: Dictionary = ModularCharacter.get_pose_override(ProfileManager.head_id, stance, _modular._current_anim)
	var w_ov: Dictionary = ov.get("weapon", {})
	var base_wy: float = 11.0 if anim_mode == 3 else (7.0 if anim_mode == 2 else 9.0)
	var idle_sway: float = sin(_timer * 2.0) * 0.08
	_modular.apply_weapon_arm_pose(stance, idle_sway, true, 0.0, -1.0)
	var sock: Dictionary = _modular.get_weapon_socket_transform(stance, true, w_ov, base_wy)
	_weapon_pivot.position = sock["pos"] as Vector2
	_weapon_pivot.z_index = int(sock["z"])
	_weapon_pivot.rotation = float(sock["rot"]) + idle_sway

