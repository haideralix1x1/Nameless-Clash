class_name UIStyle
extends RefCounted

const FONT_MAIN: FontFile = preload("res://assets/Layer Lab/Fonts/LilitaOne-Regular.ttf")

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


static func get_icon(icon_name: String) -> Texture2D:
	return ICONS.get(icon_name, null) as Texture2D


static func make_button_stylebox(tex: Texture2D, tint: Color = Color.WHITE, margin_h: int = 16, margin_v: int = 10) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 18.0
	sb.texture_margin_right = 18.0
	sb.texture_margin_top = 14.0
	sb.texture_margin_bottom = 16.0
	sb.content_margin_left = float(margin_h)
	sb.content_margin_right = float(margin_h)
	sb.content_margin_top = float(margin_v)
	sb.content_margin_bottom = float(margin_v)
	sb.modulate_color = tint
	return sb


static func make_card_stylebox(variant: String = "blue", tint: Color = Color(1.0, 1.0, 1.0, 0.94), margin_h: int = 16, margin_v: int = 12) -> StyleBoxTexture:
	var tex: Texture2D = FRAME_TEXTURES.get(variant, FRAME_TEXTURES["blue"]) as Texture2D
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 16.0
	sb.texture_margin_right = 16.0
	sb.texture_margin_top = 14.0
	sb.texture_margin_bottom = 16.0
	sb.content_margin_left = float(margin_h)
	sb.content_margin_right = float(margin_h)
	sb.content_margin_top = float(margin_v)
	sb.content_margin_bottom = float(margin_v)
	sb.modulate_color = tint
	return sb


static func style_layer_button(btn: Button, variant: String = "blue", icon_name: String = "", margin_h: int = 16, margin_v: int = 10) -> void:
	if btn == null:
		return
	var tex: Texture2D = BTN_TEXTURES.get(variant, BTN_TEXTURES["blue"]) as Texture2D
	if tex != null:
		btn.add_theme_stylebox_override("normal", make_button_stylebox(tex, Color.WHITE, margin_h, margin_v))
		btn.add_theme_stylebox_override("hover", make_button_stylebox(tex, Color(1.12, 1.12, 1.12, 1.0), margin_h, margin_v))
		btn.add_theme_stylebox_override("pressed", make_button_stylebox(tex, Color(0.82, 0.82, 0.85, 1.0), margin_h, margin_v))
		btn.add_theme_stylebox_override("disabled", make_button_stylebox(tex, Color(0.55, 0.55, 0.60, 0.72), margin_h, margin_v))
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.86))
	btn.add_theme_color_override("font_pressed_color", Color(0.90, 0.90, 0.94))
	btn.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.14, 0.95))
	btn.add_theme_constant_override("outline_size", 3)

	if not icon_name.is_empty():
		var ic: Texture2D = get_icon(icon_name)
		if ic != null:
			btn.icon = ic
			btn.expand_icon = true
			btn.add_theme_constant_override("icon_max_width", 26)
