class_name UIStyle
extends RefCounted

const FONT_MAIN: FontFile = preload("res://assets/Layer Lab/Fonts/LilitaOne-Regular.ttf")
const FONT_TITLE: FontFile = FONT_MAIN

const BTN_TEXTURES: Dictionary = {
	"green": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Green.Png"),
	"blue": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Blue.Png"),
	"orange": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Orange.Png"),
	"purple": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Purple.Png"),
	"red": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Red.Png"),
	"sky": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Sky.Png"),
	"dark": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Dark.Png"),
	"gray": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Gray.Png"),
	"yellow": preload("res://assets/Layer Lab/Sprite/Components/Button/Button01_Yellow.Png")
}

const FRAME_TEXTURES: Dictionary = {
	"blue": preload("res://assets/Layer Lab/Sprite/Components/Frame/CardFrame03_Single_Blue.png"),
	"green": preload("res://assets/Layer Lab/Sprite/Components/Frame/CardFrame03_Single_Green.png"),
	"orange": preload("res://assets/Layer Lab/Sprite/Components/Frame/CardFrame03_Single_Orange.png"),
	"purple": preload("res://assets/Layer Lab/Sprite/Components/Frame/CardFrame03_Single_Purple.png")
}

const ICONS: Dictionary = {
	"battle": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Battle.Png"),
	"sword": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Sword.Png"),
	"boom": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Boom.Png"),
	"gear": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Gear.Png"),
	"user": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_User.Png"),
	"wifi": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Wifi_On.Png"),
	"thunder": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Thunder.Png"),
	"timer": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Timer.Png"),
	"target": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Target.Png"),
	"close": preload("res://assets/Layer Lab/Sprite/Components/Icon_PictoIcons/32/Pictoicon_Close.Png")
}

const CLASSIC_PALETTES: Dictionary = {
	"green": {
		"bg": Color(0.15, 0.25, 0.18, 0.96),
		"border": Color(0.35, 0.56, 0.39, 0.95),
		"bevel": Color(0.08, 0.14, 0.10, 0.98)
	},
	"blue": {
		"bg": Color(0.13, 0.19, 0.27, 0.96),
		"border": Color(0.33, 0.48, 0.64, 0.95),
		"bevel": Color(0.07, 0.11, 0.16, 0.98)
	},
	"sky": {
		"bg": Color(0.13, 0.19, 0.27, 0.96),
		"border": Color(0.33, 0.48, 0.64, 0.95),
		"bevel": Color(0.07, 0.11, 0.16, 0.98)
	},
	"orange": {
		"bg": Color(0.25, 0.19, 0.11, 0.96),
		"border": Color(0.64, 0.49, 0.25, 0.95),
		"bevel": Color(0.14, 0.10, 0.05, 0.98)
	},
	"yellow": {
		"bg": Color(0.25, 0.19, 0.11, 0.96),
		"border": Color(0.64, 0.49, 0.25, 0.95),
		"bevel": Color(0.14, 0.10, 0.05, 0.98)
	},
	"purple": {
		"bg": Color(0.18, 0.16, 0.26, 0.96),
		"border": Color(0.45, 0.41, 0.62, 0.95),
		"bevel": Color(0.10, 0.09, 0.15, 0.98)
	},
	"red": {
		"bg": Color(0.27, 0.13, 0.14, 0.96),
		"border": Color(0.62, 0.28, 0.28, 0.95),
		"bevel": Color(0.15, 0.06, 0.07, 0.98)
	},
	"gray": {
		"bg": Color(0.13, 0.16, 0.20, 0.95),
		"border": Color(0.28, 0.34, 0.42, 0.92),
		"bevel": Color(0.07, 0.09, 0.12, 0.98)
	},
	"dark": {
		"bg": Color(0.13, 0.16, 0.20, 0.95),
		"border": Color(0.28, 0.34, 0.42, 0.92),
		"bevel": Color(0.07, 0.09, 0.12, 0.98)
	}
}


static func get_icon(icon_name: String) -> Texture2D:
	return ICONS.get(icon_name, null) as Texture2D


static func _get_classic_palette(variant: String) -> Dictionary:
	var key := variant.to_lower()
	if CLASSIC_PALETTES.has(key):
		return CLASSIC_PALETTES[key]
	return CLASSIC_PALETTES["blue"]


static func make_custom_button_stylebox(
	bg: Color,
	border: Color,
	bevel: Color,
	margin_h: int = 16,
	margin_v: int = 10,
	pressed_state: bool = false
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bevel if pressed_state else border.lerp(bevel, 0.18)
	sb.set_corner_radius_all(8)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 3 if pressed_state else 2
	sb.border_width_bottom = 2 if pressed_state else 4
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	sb.shadow_size = 1 if pressed_state else 3
	sb.shadow_offset = Vector2(0, 1 if pressed_state else 2)
	sb.content_margin_left = float(margin_h)
	sb.content_margin_right = float(margin_h)
	sb.content_margin_top = float(margin_v)
	sb.content_margin_bottom = float(margin_v)
	return sb


static func make_button_stylebox(_tex: Texture2D, tint: Color = Color.WHITE, margin_h: int = 16, margin_v: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = tint
	sb.border_color = tint.lightened(0.22)
	sb.set_corner_radius_all(8)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 3
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	sb.shadow_size = 2
	sb.shadow_offset = Vector2(0, 1)
	sb.content_margin_left = float(margin_h)
	sb.content_margin_right = float(margin_h)
	sb.content_margin_top = float(margin_v)
	sb.content_margin_bottom = float(margin_v)
	return sb


static func make_card_stylebox(variant: String = "blue", tint: Color = Color(1.0, 1.0, 1.0, 0.94), margin_h: int = 16, margin_v: int = 12) -> StyleBoxFlat:
	var pal: Dictionary = _get_classic_palette(variant)
	var border_col: Color = pal["border"] as Color
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, clampf(tint.a, 0.88, 0.96))
	sb.border_color = border_col
	sb.set_corner_radius_all(10)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 3
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = float(margin_h)
	sb.content_margin_right = float(margin_h)
	sb.content_margin_top = float(margin_v)
	sb.content_margin_bottom = float(margin_v)
	return sb


static func style_layer_button(btn: Button, variant: String = "blue", icon_name: String = "", margin_h: int = 16, margin_v: int = 10) -> void:
	if btn == null:
		return
	var pal: Dictionary = _get_classic_palette(variant)
	var bg: Color = pal["bg"] as Color
	var border: Color = pal["border"] as Color
	var bevel: Color = pal["bevel"] as Color

	btn.add_theme_stylebox_override("normal", make_custom_button_stylebox(bg, border, bevel, margin_h, margin_v, false))
	btn.add_theme_stylebox_override("hover", make_custom_button_stylebox(bg.lightened(0.07), border.lightened(0.10), bevel, margin_h, margin_v, false))
	btn.add_theme_stylebox_override("pressed", make_custom_button_stylebox(bg.darkened(0.10), border.darkened(0.08), bevel, margin_h, margin_v, true))
	btn.add_theme_stylebox_override("disabled", make_custom_button_stylebox(bg.darkened(0.28), border.darkened(0.32), bevel, margin_h, margin_v, false))
	btn.add_theme_stylebox_override("focus", make_custom_button_stylebox(bg, border.lightened(0.12), bevel, margin_h, margin_v, false))

	btn.add_theme_font_override("font", FONT_MAIN)
	btn.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	btn.add_theme_color_override("font_hover_color", Color(0.98, 0.99, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.82, 0.86, 0.90))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62, 0.85))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.09, 0.92))
	btn.add_theme_constant_override("outline_size", 2)

	if not icon_name.is_empty():
		var ic: Texture2D = get_icon(icon_name)
		if ic != null:
			btn.icon = ic
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 24)
			btn.add_theme_color_override("icon_normal_color", Color(0.88, 0.91, 0.95, 0.90))
			btn.add_theme_color_override("icon_hover_color", Color(0.96, 0.98, 1.0, 0.96))
			btn.add_theme_color_override("icon_pressed_color", Color(0.76, 0.80, 0.86, 0.90))


static func make_inline_new_badge(text: String = "NEW", font_size: int = 10) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.16, 0.22, 0.98)
	sb.border_color = Color(1.0, 0.88, 0.34, 0.98)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 1.5
	sb.content_margin_bottom = 1.5
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 2
	badge.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", FONT_MAIN)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.86))
	lbl.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.04, 0.95))
	lbl.add_theme_constant_override("outline_size", 2)
	badge.add_child(lbl)
	return badge


static func attach_new_badge(parent: Control, badge_name: String = "NewBadge", text: String = "NEW", offset_right: float = -6.0, offset_top: float = 6.0, font_size: int = 11) -> PanelContainer:
	var existing: PanelContainer = parent.get_node_or_null(badge_name) as PanelContainer
	if existing != null:
		return existing
	var badge := make_inline_new_badge(text, font_size)
	badge.name = badge_name
	badge.z_index = 4
	badge.anchor_left = 1.0
	badge.anchor_right = 1.0
	badge.anchor_top = 0.0
	badge.anchor_bottom = 0.0
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_END
	badge.offset_left = offset_right
	badge.offset_right = offset_right
	badge.offset_top = offset_top
	badge.offset_bottom = offset_top
	parent.add_child(badge)
	return badge


static func set_new_badge_visible(parent: Control, is_visible: bool, badge_name: String = "NewBadge", offset_right: float = -6.0, offset_top: float = 6.0, font_size: int = 11) -> void:
	if parent == null:
		return
	var badge: PanelContainer = parent.get_node_or_null(badge_name) as PanelContainer
	if is_visible:
		if badge == null:
			badge = attach_new_badge(parent, badge_name, "NEW", offset_right, offset_top, font_size)
		badge.visible = true
	elif badge != null:
		badge.visible = false
