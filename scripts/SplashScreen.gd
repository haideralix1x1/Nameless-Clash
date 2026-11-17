extends Control

const TEX_LOGO: Texture2D = preload("res://assets/Company-dark.png")
var _elapsed: float = 0.0
var _done: bool = false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.11, 1.0)
	add_child(bg)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	var logo := TextureRect.new()
	logo.texture = TEX_LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(360, 360)
	logo.modulate.a = 0.0
	cc.add_child(logo)

	var tw := create_tween()
	tw.tween_property(logo, "modulate:a", 1.0, 0.45)
	tw.tween_interval(1.0)
	tw.tween_property(logo, "modulate:a", 0.0, 0.35)
	tw.finished.connect(_go_menu)


func _input(event: InputEvent) -> void:
	if _done:
		return
	if (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) or (event is InputEventKey and (event as InputEventKey).pressed):
		_go_menu()


func _go_menu() -> void:
	if _done:
		return
	_done = true
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
