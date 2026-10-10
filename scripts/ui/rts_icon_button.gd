extends Button
var icon_name := "pause":
	set(value):
		icon_name = value
		queue_redraw()

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.75, 0.92, 1.0, 0.1)
	hover_style.set_corner_radius_all(10)
	add_theme_stylebox_override("hover", hover_style)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var c := Color("a6f0ed") if is_hovered() else Color("edf8f6")
	var center := size * 0.5
	match icon_name:
		"pause":
			draw_rect(Rect2(center + Vector2(-8, -9), Vector2(5, 18)), c)
			draw_rect(Rect2(center + Vector2(3, -9), Vector2(5, 18)), c)
		"play":
			draw_colored_polygon(PackedVector2Array([center + Vector2(-6, -10), center + Vector2(10, 0), center + Vector2(-6, 10)]), c)
		"menu":
			for y in [-7, 0, 7]: draw_line(center + Vector2(-10, y), center + Vector2(10, y), c, 2, true)
		"close":
			draw_line(center + Vector2(-7, -7), center + Vector2(7, 7), c, 2, true)
			draw_line(center + Vector2(-7, 7), center + Vector2(7, -7), c, 2, true)
