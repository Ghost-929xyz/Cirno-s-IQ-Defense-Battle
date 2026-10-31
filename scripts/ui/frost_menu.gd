extends RefCounted
## Shared, resolution-independent drawing for archive and pause panels.
const AVATAR = preload("res://assets/ui/cirno_avatar.png")
const FONT = preload("res://assets/fonts/fusion_pixel_12px_prop.ttf")

static func style(bg := Color("102839"), border := Color("42667b"), radius := 12) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.shadow_color = Color(0.01, 0.03, 0.07, 0.5)
	box.shadow_size = 12
	box.shadow_offset = Vector2(0, 6)
	return box

static func button_theme(button: Button) -> void:
	button.add_theme_font_override("font", FONT)
	button.add_theme_color_override("font_color", Color("e5f6fa"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("6d8796"))
	button.add_theme_stylebox_override("normal", style())
	button.add_theme_stylebox_override("hover", style(Color("1a4055"), Color("95dcea")))
	button.add_theme_stylebox_override("pressed", style(Color("22536a"), Color("c9f6ff")))
	button.add_theme_stylebox_override("disabled", style(Color("101d29"), Color("263948")))
	var focus := style(Color(0,0,0,0), Color("c9f6ff"))
	focus.shadow_size = 0
	button.add_theme_stylebox_override("focus", focus)

static func label(parent: Node, text: String, pos: Vector2, extent: Vector2, font_size := 18, tint := Color("d1e6ef")) -> Label:
	var item := Label.new()
	item.text = text
	item.position = pos
	item.size = extent
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", tint)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(item)
	return item

static func decorate(panel: Panel, title: String, subtitle: String) -> void:
	panel.add_theme_stylebox_override("panel", style(Color("0b1c2a"), Color("5c8b9e"), 18))
	var portrait := TextureRect.new()
	portrait.texture = AVATAR
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.position = Vector2(26, 22)
	portrait.size = Vector2(64, 64)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(portrait)
	label(panel, title, Vector2(108, 22), Vector2(panel.size.x - 144, 32), 26, Color("eefcff"))
	label(panel, subtitle, Vector2(108, 60), Vector2(panel.size.x - 144, 26), 15, Color("8db3c6"))
	var line := ColorRect.new()
	line.position = Vector2(28, 104)
	line.size = Vector2(panel.size.x - 56, 1)
	line.color = Color("31576b")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)

static func button(parent: Node, text: String, pos: Vector2, extent: Vector2, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.position = pos
	item.size = extent
	item.add_theme_font_size_override("font_size", 18)
	button_theme(item)
	preload("res://scripts/ui/pixel_ui.gd").attach_button_sound_feedback(item)
	parent.add_child(item)
	item.pressed.connect(callback)
	return item
