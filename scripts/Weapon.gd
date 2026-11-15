class_name WeaponData
extends Resource

@export var id: int = 0
@export var code_name: String = "ak47"
@export var display_name: String = "AK-47"
@export var category: String = "Assault Rifle"
@export var description: String = ""
@export var damage: int = 24
@export var fire_interval: float = 0.135
@export var mag_size: int = 30
@export var reload_time: float = 1.5
@export var single_shell_reload: bool = false
@export var recoil_impulse: float = 55.0
@export var vertical_recoil_bias: float = 0.035
@export var bullet_speed: float = 1280.0
@export var spread_deg: float = 2.8
@export var pellet_count: int = 1
@export var damage_falloff_start: float = 9999.0
@export var min_damage_ratio: float = 1.0
@export var move_speed_multiplier: float = 1.0
@export var scope_zoom: float = 1.05
@export var has_backblast: bool = false
@export var has_accessory_rail: bool = false
@export var unlimited_reserve: bool = false
@export var supports_dual_wield: bool = false
@export var is_laser: bool = false
@export var is_explosive: bool = false
@export var explosion_radius: float = 0.0
@export var muzzle_flash_scale: float = 1.0
@export var bullet_color: Color = Color(1.0, 0.85, 0.25)
@export var sound_path: String = "res://assets/audio/shoot_ak47.wav"
@export var sprite_frame: int = 0

const RESOURCE_PATHS: Array[String] = [
	"res://assets/weapons/weapon_0_ak47.tres",
	"res://assets/weapons/weapon_1_m4a1.tres",
	"res://assets/weapons/weapon_2_scarh.tres",
	"res://assets/weapons/weapon_3_mp5.tres",
	"res://assets/weapons/weapon_4_vector.tres",
	"res://assets/weapons/weapon_5_spas12.tres",
	"res://assets/weapons/weapon_6_remington870.tres",
	"res://assets/weapons/weapon_7_awm.tres",
	"res://assets/weapons/weapon_8_svd.tres",
	"res://assets/weapons/weapon_9_glock17.tres",
	"res://assets/weapons/weapon_10_rpg7.tres"
]


static func get_weapon(weapon_id: int, skin_id: int = 0, rail_mod: int = 0) -> WeaponData:
	var idx: int = clampi(weapon_id, 0, RESOURCE_PATHS.size() - 1)
	var base: WeaponData = load(RESOURCE_PATHS[idx]) as WeaponData
	var w: WeaponData = (base.duplicate() as WeaponData) if base != null else _fallback_weapon(idx)

	if w.has_accessory_rail:
		if rail_mod == 1:
			# Suppressor attachment: tighter spread, smaller muzzle flash, quieter tone
			w.spread_deg *= 0.72
			w.muzzle_flash_scale = 0.35
			w.display_name = "M4A1 (Suppressed)"
		elif rail_mod == 2:
			# Tactical Scope attachment: extended zoom & precision
			w.scope_zoom = 0.90
			w.spread_deg *= 0.65
			w.display_name = "M4A1 (Scoped)"

	if skin_id == 2:
		w.bullet_color = Color(0.15, 0.96, 1.0) if (w.id % 2 == 0) else Color(1.0, 0.32, 0.85)
	return w


static func get_weapon_count() -> int:
	return RESOURCE_PATHS.size()


static func _fallback_weapon(idx: int) -> WeaponData:
	var w := WeaponData.new()
	w.id = idx
	return w
