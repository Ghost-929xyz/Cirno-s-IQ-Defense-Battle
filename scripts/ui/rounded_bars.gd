extends RefCounted
static var styles: Dictionary = {}

static func style(color: Color, radius: int) -> StyleBoxFlat:
	var key := "%s:%d" % [color.to_html(), radius]
	if not styles.has(key):
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(radius)
		styles[key] = box
	return styles[key]

static func draw(canvas: CanvasItem, rect: Rect2, ratio: float, color: Color, background := Color("10222c")) -> void:
	var radius := ceili(rect.size.y * 0.5)
	canvas.draw_style_box(style(background, radius), rect)
	if ratio <= 0: return
	canvas.draw_style_box(style(color, radius), Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0, 1), rect.size.y)))
