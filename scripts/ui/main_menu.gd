extends Control

## 游戏开始菜单：标题 + 左侧竖排无边框选项（New Game / Continue / Options / Quit）。
## 选项为深蓝色无文本框样式，悬停时左侧悬浮一片雪花并高亮文本。

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const PixelUITheme = preload("res://scripts/ui/pixel_ui.gd")
const CirnoSprite = preload("res://scripts/entities/cirno_sprite.gd")
const SessionScript = preload("res://scripts/autoload/session.gd")

const TEXT_NORMAL := Color("#2f6b96")
const TEXT_HOVER := Color("#d8fbff")
const TEXT_DISABLED := Color("#2a3d4d")

var _snow: Array[Dictionary] = []
var _menu_row_count := 0

var _slot_overlay: Control = null
var _options_overlay: Control = null
var _overlay_mode := ""


func _ready() -> void:
	_seed_snow()
	_build_ui()


func _process(delta: float) -> void:
	for flake in _snow:
		var position_value: Vector2 = flake["position"]
		position_value.y += float(flake["speed"]) * delta
		position_value.x += float(flake["drift"]) * delta
		if position_value.y > 690.0:
			position_value.y = -24.0
		if position_value.x < -24.0:
			position_value.x = 1204.0
		elif position_value.x > 1204.0:
			position_value.x = -24.0
		flake["position"] = position_value
	queue_redraw()


## 兼容旧入口：直接以无槽位模式进入游戏（测试脚本依赖此方法存在）。
func start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func quit_game() -> void:
	get_tree().quit()


func _seed_snow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923
	for _index in range(56):
		_snow.append({
			"position": Vector2(rng.randf() * 1180.0, rng.randf() * 660.0),
			"speed": rng.randf_range(10.0, 32.0),
			"drift": rng.randf_range(-9.0, 9.0),
			"radius": rng.randf_range(1.5, 4.0),
			"alpha": rng.randf_range(0.22, 0.7),
		})


func _build_ui() -> void:
	_make_label(self, "琪露诺的智商保卫战", Vector2(90.0, 108.0), Vector2(560.0, 60.0), 44, Color("#ebfdff"))

	var banner_texture: Texture2D = PixelUITheme.icon("title_banner.png")
	if banner_texture != null:
		var banner := TextureRect.new()
		banner.texture = banner_texture
		banner.position = Vector2(90.0, 178.0)
		banner.size = Vector2(560.0, 24.0)
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(banner)

	# 右侧：琪露诺立绘作为视觉主体（idle 帧动画）。
	var hero_sprite := CirnoSprite.make_sprite()
	if hero_sprite != null:
		hero_sprite.scale = Vector2(2.1, 2.1)
		hero_sprite.position = Vector2(905.0, 330.0)
		add_child(hero_sprite)

	# 左侧竖排无边框菜单选项。
	var has_any_save := false
	for slot in range(SaveManager.SLOT_COUNT):
		if SaveManager.has_save(slot):
			has_any_save = true
			break

	_menu_row_count = 0
	_add_menu_item("新的游戏", _on_new_game_pressed)
	_add_menu_item("继续游戏", _on_continue_pressed, not has_any_save)
	_add_menu_item("游戏设置", _on_options_pressed)
	_add_menu_item("退出游戏", quit_game)


## 无边框菜单选项：深蓝色文字；悬停/聚焦时文本高亮并微微上浮膨胀，
## 文字下方浮现亮冰蓝渐变下划线，左侧出现柔光冰晶。
func _add_menu_item(text: String, handler: Callable, disabled := false) -> void:
	var row_y := 300.0 + float(_menu_row_count) * 58.0
	_menu_row_count += 1

	var button := Button.new()
	button.text = text
	button.position = Vector2(140.0, row_y)
	button.size = Vector2(320.0, 48.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.disabled = disabled
	button.add_theme_font_size_override("font_size", 27)
	add_child(button)
	PixelUITheme.attach_menu_option_fx(button, self, button.position)
	if not disabled:
		button.pressed.connect(handler)


# ---------------------------------------------------------------- 存档槽位界面

func _on_new_game_pressed() -> void:
	_overlay_mode = "new"
	_show_slot_overlay("选择存档槽位 · 开始新游戏")


func _on_continue_pressed() -> void:
	_overlay_mode = "continue"
	_show_slot_overlay("选择存档槽位 · 继续游戏")


func _show_slot_overlay(title_text: String) -> void:
	_hide_overlays()
	_slot_overlay = _make_overlay_dimmer()

	var panel := Panel.new()
	panel.position = Vector2(290.0, 120.0)
	panel.size = Vector2(600.0, 420.0)
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color("#0a2038"), Color("#86e9ff")))
	_slot_overlay.add_child(panel)

	var title := _make_label(panel, title_text, Vector2(20.0, 18.0), Vector2(560.0, 34.0), 24, Color("#edfdff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for slot in range(SaveManager.SLOT_COUNT):
		_build_slot_row(panel, slot)

	var back_button := _make_panel_button("返回", 15)
	back_button.position = Vector2(240.0, 356.0)
	back_button.size = Vector2(120.0, 44.0)
	back_button.pressed.connect(_hide_overlays)
	panel.add_child(back_button)


func _build_slot_row(panel: Panel, slot: int) -> void:
	var summary := SaveManager.get_slot_summary(slot)
	var has_save := not summary.is_empty()
	var row := Button.new()
	row.position = Vector2(40.0, 74.0 + float(slot) * 92.0)
	row.size = Vector2(520.0, 76.0)
	row.add_theme_font_size_override("font_size", 17)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	PixelUITheme.apply_button_theme(row)

	if has_save:
		row.text = "  槽位 %d    第 %d 波 · 冻气 %d · 建筑 %d 座\n  保存于 %s" % [
			slot + 1,
			int(summary.get("wave", 0)),
			int(summary.get("frost", 0)),
			int(summary.get("structures", 0)),
			str(summary.get("saved_at", "")),
		]
		row.add_theme_color_override("font_color", Color("#e8fcff"))
	else:
		row.text = "  槽位 %d    < 空存档 >" % (slot + 1)
		row.add_theme_color_override("font_color", Color("#7fa8bd"))

	var selectable := false
	if _overlay_mode == "new":
		selectable = true
		if has_save:
			row.text += "\n  （选择将覆盖此存档）"
	elif _overlay_mode == "continue":
		selectable = has_save
	row.disabled = not selectable
	if selectable:
		row.pressed.connect(func() -> void: _on_slot_chosen(slot))
	panel.add_child(row)


func _on_slot_chosen(slot: int) -> void:
	if _overlay_mode == "new":
		SessionScript.current_slot = slot
		SessionScript.pending_load_slot = -1
		SaveManager.delete_slot(slot)
	else:
		SessionScript.current_slot = slot
		SessionScript.pending_load_slot = slot
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


# ---------------------------------------------------------------- Options 界面

func _on_options_pressed() -> void:
	_hide_overlays()
	_options_overlay = _make_overlay_dimmer()

	var panel := Panel.new()
	panel.position = Vector2(390.0, 190.0)
	panel.size = Vector2(400.0, 260.0)
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color("#0a2038"), Color("#86e9ff")))
	_options_overlay.add_child(panel)

	var title := _make_label(panel, "游戏设置", Vector2(20.0, 18.0), Vector2(360.0, 34.0), 24, Color("#edfdff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
	back_button.pressed.connect(_hide_overlays)
	panel.add_child(back_button)


func _make_overlay_dimmer() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.05, 0.09, 0.6)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dimmer)
	return overlay


func _hide_overlays() -> void:
	if _slot_overlay != null:
		_slot_overlay.queue_free()
		_slot_overlay = null
	if _options_overlay != null:
		_options_overlay.queue_free()
		_options_overlay = null


# ---------------------------------------------------------------- 绘制与工具

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1180.0, 660.0)), Color("#06121f"))

	# 雾之湖轮廓
	var lake_center := Vector2(590.0, 250.0)
	draw_circle(lake_center, 300.0, Color(0.08, 0.22, 0.32, 0.35))
	draw_circle(lake_center, 220.0, Color(0.1, 0.28, 0.4, 0.3))
	draw_arc(lake_center, 300.0, 0.0, TAU, 64, Color(0.35, 0.7, 0.85, 0.25), 2.0)

	# 中央雪花徽记
	for spoke_index in range(6):
		var angle := TAU * float(spoke_index) / 6.0 + PI / 6.0
		var direction := Vector2.from_angle(angle)
		draw_line(lake_center + direction * 40.0, lake_center + direction * 180.0, Color(0.62, 0.9, 1.0, 0.14), 10.0)
		draw_line(lake_center + direction * 40.0, lake_center + direction * 180.0, Color(0.75, 0.95, 1.0, 0.1), 3.0)
	draw_circle(lake_center, 96.0, Color(0.16, 0.42, 0.6, 0.35))
	draw_circle(lake_center, 72.0, Color(0.65, 0.9, 1.0, 0.16))

	# 飘雪
	for flake in _snow:
		draw_circle(flake["position"], float(flake["radius"]), Color(0.82, 0.95, 1.0, float(flake["alpha"])))


func _make_panel_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	PixelUITheme.apply_button_theme(button)
	button.add_theme_color_override("font_color", Color("#e8fcff"))
	return button


func _make_label(
	parent: Node,
	text: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
