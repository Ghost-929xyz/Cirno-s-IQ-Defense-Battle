extends Control

## 游戏开始菜单：标题、开始游戏、操作说明与退出。

const GAME_SCENE_PATH := "res://scenes/main.tscn"
const PixelUITheme = preload("res://scripts/ui/pixel_ui.gd")
const CirnoSprite = preload("res://scripts/entities/cirno_sprite.gd")

var _help_panel: Panel
var _snow: Array[Dictionary] = []


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
	var title := _make_label(self, "琪露诺的智商保卫战", Vector2(140.0, 118.0), Vector2(900.0, 64.0), 46, Color("#ebfdff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var subtitle := _make_label(self, "雾之湖 · 塔防 Roguelike 原型", Vector2(140.0, 190.0), Vector2(900.0, 30.0), 18, Color("#8fc7dd"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 标题旁的像素琪露诺（idle 帧动画展示）。
	var hero_sprite := CirnoSprite.make_sprite()
	if hero_sprite != null:
		hero_sprite.scale = Vector2(3.4, 3.4)
		hero_sprite.position = Vector2(268.0, 158.0)
		add_child(hero_sprite)

	var start_button := _make_menu_button("开始游戏", Color("#2f8b70"), 20)
	start_button.position = Vector2(480.0, 350.0)
	start_button.size = Vector2(220.0, 60.0)
	start_button.pressed.connect(start_game)
	add_child(start_button)

	var help_button := _make_menu_button("操作说明", Color("#246f99"), 15)
	help_button.position = Vector2(480.0, 424.0)
	help_button.size = Vector2(220.0, 48.0)
	help_button.pressed.connect(_toggle_help)
	add_child(help_button)

	var quit_button := _make_menu_button("退出游戏", Color("#5a4a7a"), 15)
	quit_button.position = Vector2(480.0, 484.0)
	quit_button.size = Vector2(220.0, 48.0)
	quit_button.pressed.connect(quit_game)
	add_child(quit_button)

	_build_help_panel()

	var footer := _make_label(self, "保护琪露诺 · 抵御 10 波妖精 · 四面楚歌版本", Vector2(140.0, 620.0), Vector2(900.0, 24.0), 13, Color("#5f8296"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_help_panel() -> void:
	_help_panel = Panel.new()
	_help_panel.position = Vector2(240.0, 100.0)
	_help_panel.size = Vector2(700.0, 460.0)
	_help_panel.visible = false
	_help_panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color("#0a2038"), Color("#86e9ff")))
	add_child(_help_panel)

	var title := _make_label(_help_panel, "操作说明", Vector2(20.0, 16.0), Vector2(660.0, 34.0), 26, Color("#edfdff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var body := _make_label(
		_help_panel,
		"目标：保护琪露诺，击退 10 波妖精。她生命归零即失败。妖精会从 西 / 北 / 南 / 东 四个裂隙进攻。\n\n"
		+ "· 右键空地：移动英雄琪露诺（自动攻击附近妖精）\n"
		+ "· 左键草地格：建造右侧选中的防御塔或兵营（数字键 1-6 快速选择）\n"
		+ "· 左键已有建筑：查看详情并升级（最多 3 级）\n"
		+ "· 右键妖精（选中建筑时）：指定优先攻击目标\n"
		+ "· Q：冰霜新星（范围伤害与减速）    R：完美冻结（冻结最强目标）\n"
		+ "· 空格：开始下一波    Esc：取消选中\n\n"
		+ "资源：击杀妖精与波次结算获得冻气（建造/升级）；\n"
		+ "精英妖精掉落冰晶并触发附魔三选一；波间另有笨蛋灵感三选一。\n"
		+ "妖精会攻击琪露诺，漏过防线偷走 IQ 结晶也会扣她生命；\n"
		+ "兵营只在交战阶段召唤友军，用前排近卫挡住妖精、掩护输出。",
		Vector2(34.0, 60.0),
		Vector2(632.0, 330.0),
		14,
		Color("#c7e4f0")
	)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var close_button := _make_menu_button("返回", Color("#246f99"), 15)
	close_button.position = Vector2(290.0, 392.0)
	close_button.size = Vector2(120.0, 44.0)
	close_button.pressed.connect(_toggle_help)
	_help_panel.add_child(close_button)


func _toggle_help() -> void:
	_help_panel.visible = not _help_panel.visible


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1180.0, 660.0)), Color("#06121f"))

	# 雾之湖轮廓
	var lake_center := Vector2(590.0, 250.0)
	draw_circle(lake_center, 300.0, Color(0.08, 0.22, 0.32, 0.35))
	draw_circle(lake_center, 220.0, Color(0.1, 0.28, 0.4, 0.3))
	draw_arc(lake_center, 300.0, 0.0, TAU, 64, Color(0.35, 0.7, 0.85, 0.25), 2.0)

	# 中央 ⑨ 雪花徽记
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


func _make_menu_button(text: String, color: Color, font_size: int) -> Button:
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


func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _button_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
