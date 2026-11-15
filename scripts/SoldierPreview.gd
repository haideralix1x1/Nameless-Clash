class_name SoldierPreview
extends Node2D

const TEX_WEAPONS: Texture2D = preload("res://assets/sprites/weapons_sheet.png")

var anim_mode: int = 0
var _timer: float = 0.0

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

	_gun_s = Sprite2D.new()
	_gun_s.texture = TEX_WEAPONS
	_gun_s.hframes = 11
	_gun_s.vframes = 3
	_gun_s.position = Vector2(10, 4)
	_gun_s.scale = Vector2(0.68, 0.68)
	_gun_s.z_index = -1
	_weapon_pivot.add_child(_gun_s)

	_gun_p = Sprite2D.new()
	_gun_p.texture = TEX_WEAPONS
	_gun_p.hframes = 11
	_gun_p.vframes = 3
	_gun_p.position = Vector2(14, 0)
	_gun_p.scale = Vector2(0.72, 0.72)
	_weapon_pivot.add_child(_gun_p)

	refresh_from_profile()


func refresh_from_profile() -> void:
	if not is_node_ready() or _modular == null:
		return

	_modular.apply_loadout(ProfileManager.to_dict())

	var w_frame: int = ProfileManager.weapon_skin_id * 11 + ProfileManager.primary_weapon_id
	_gun_p.frame = w_frame
	_gun_s.frame = w_frame
	var w: WeaponData = WeaponData.get_weapon(ProfileManager.primary_weapon_id, ProfileManager.weapon_skin_id, ProfileManager.m4a1_rail_mod)
	_gun_s.visible = w.supports_dual_wield and ProfileManager.primary_weapon_id == 9


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

	_weapon_pivot.position.y = 11.0 if anim_mode == 3 else (7.0 if anim_mode == 2 else 9.0)
	_weapon_pivot.rotation = sin(_timer * 2.0) * 0.08
