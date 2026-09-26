extends CanvasLayer

## 游戏内暂停菜单：P / Esc 呼出，继续、保存并退出或直接退出。
## process_mode = ALWAYS，保证 get_tree().paused 时仍能响应输入。

const PixelUITheme = preload("res://scripts/ui/pixel_ui.gd")

signal resume_requested
signal save_and_quit_requested
signal quit_requested

var _save_button: Button


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func show_menu(can_save: bool) -> void:
	_save_button.disabled = not can_save
	_save_button.tooltip_text = "" if can_save else "仅在备战阶段（且本局绑定了存档槽位）可保存。"
	visible = true
	get_tree().paused = true


func hide_menu() -> void:
	visible = false
	get_tree().paused = false


func is_menu_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P or event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			resume_requested.emit()


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.05, 0.09, 0.72)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color(0.03, 0.12, 0.21, 0.97), Color("#86e9ff")))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-180.0, -140.0)
	add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#edfdff"))
	layout.add_child(title)

	var hint := Label.new()
	hint.text = "P / Esc 继续游戏"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#8fc7dd"))
	layout.add_child(hint)

	var resume_button := _make_button("继续游戏", 18)
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	layout.add_child(resume_button)

	_save_button = _make_button("保存并返回主菜单", 16)
	_save_button.pressed.connect(func() -> void: save_and_quit_requested.emit())
	layout.add_child(_save_button)

	var quit_button := _make_button("不保存返回主菜单", 16)
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	layout.add_child(quit_button)


func _make_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300.0, 46.0)
	button.add_theme_font_size_override("font_size", font_size)
	PixelUITheme.apply_button_theme(button)
	button.add_theme_color_override("font_color", Color("#e8fcff"))
	return button
