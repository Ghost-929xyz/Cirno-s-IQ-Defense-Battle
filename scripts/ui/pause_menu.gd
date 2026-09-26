extends CanvasLayer

## 游戏内暂停菜单：P / Esc 呼出。
## 选项样式与主菜单一致：无边框文字 + 悬浮渐变下划线 + 柔光冰晶 + 上浮膨胀。
## process_mode = ALWAYS，保证 get_tree().paused 时仍能响应输入。

const PixelUITheme = preload("res://scripts/ui/pixel_ui.gd")
const SessionScript = preload("res://scripts/autoload/session.gd")

signal resume_requested
signal save_and_quit_requested
signal quit_requested

var _save_button: Button
var _panel: Panel
var _options_overlay: Control = null


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
	_hide_options_overlay()
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
			if _options_overlay != null:
				_hide_options_overlay()
			else:
				resume_requested.emit()


func _build_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.05, 0.09, 0.72)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	_panel = Panel.new()
	_panel.size = Vector2(460.0, 356.0)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = -_panel.size * 0.5
	_panel.add_theme_stylebox_override("panel", _solid_panel_style())
	add_child(_panel)

	var title := Label.new()
	title.text = "暂停"
	title.position = Vector2(0.0, 22.0)
	title.size = Vector2(460.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#edfdff"))
	_panel.add_child(title)

	var hint := Label.new()
	hint.text = "P / Esc 继续游戏"
	hint.position = Vector2(0.0, 66.0)
	hint.size = Vector2(460.0, 22.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("#8fc7dd"))
	_panel.add_child(hint)

	_add_menu_option("继续游戏", 0, func() -> void: resume_requested.emit())
	_add_menu_option("游戏设置", 1, _show_options_overlay)
	_save_button = _add_menu_option("保存并返回主菜单", 2, func() -> void: save_and_quit_requested.emit())
	_add_menu_option("不保存返回主菜单", 3, func() -> void: quit_requested.emit())


func _add_menu_option(text: String, index: int, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = Vector2(100.0, 100.0 + float(index) * 58.0)
	button.size = Vector2(340.0, 48.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 23)
	_panel.add_child(button)
	PixelUITheme.attach_menu_option_fx(button, _panel, button.position, true)
	button.pressed.connect(handler)
	return button


# ---------------------------------------------------------------- 游戏设置弹层

func _show_options_overlay() -> void:
	_hide_options_overlay()
	_options_overlay = Control.new()
	_options_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_options_overlay)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.05, 0.09, 0.6)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_options_overlay.add_child(dimmer)

	var panel := Panel.new()
	panel.position = Vector2(440.0, 230.0)
	panel.size = Vector2(400.0, 260.0)
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color("#0a2038"), Color("#86e9ff")))
	_options_overlay.add_child(panel)

	var title := Label.new()
	title.text = "游戏设置"
	title.position = Vector2(20.0, 18.0)
	title.size = Vector2(360.0, 34.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#edfdff"))
	panel.add_child(title)

	var reset_tutorial := _make_panel_button("重置新手引导", 15)
	reset_tutorial.position = Vector2(100.0, 80.0)
	reset_tutorial.size = Vector2(200.0, 44.0)
	reset_tutorial.pressed.connect(func() -> void:
		SessionScript.tutorial_done = false
		reset_tutorial.text = "已重置 ✓"
	)
	panel.add_child(reset_tutorial)

	var back_button := _make_panel_button("返回", 15)
	back_button.position = Vector2(140.0, 190.0)
	back_button.size = Vector2(120.0, 44.0)
	back_button.pressed.connect(_hide_options_overlay)
	panel.add_child(back_button)


func _hide_options_overlay() -> void:
	if _options_overlay != null:
		_options_overlay.queue_free()
		_options_overlay = null


## 纯色面板样式：无纹理，半透明深蓝底 + 冰蓝描边。
func _solid_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.13, 0.22, 0.96)
	style.border_color = Color("#86e9ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_top = 10.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 10.0
	return style


func _make_panel_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	PixelUITheme.apply_button_theme(button)
	button.add_theme_color_override("font_color", Color("#e8fcff"))
	return button
