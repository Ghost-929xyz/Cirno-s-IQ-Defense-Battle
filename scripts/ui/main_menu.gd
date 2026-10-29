extends Control

## 游戏开始菜单：标题 + 左侧竖排无边框选项。
## 选项为深蓝色无文本框样式，悬停时左侧浮现雪花并高亮文本。
## 用户提供的后景粒子、立绘、前景粒子依次叠放，菜单与弹窗置于其上。

const GAME_SCENE_PATH := "res://scenes/expedition.tscn"
const PixelUITheme = preload("res://scripts/ui/pixel_ui.gd")
const SessionScript = preload("res://scripts/autoload/session.gd")
const PIXEL_FONT: FontFile = preload("res://assets/fonts/fusion_pixel_12px_prop.ttf")
const HERO_STANDEE: Texture2D = preload("res://assets/ui/menu_character.png")
const PARTICLES_BACK: Texture2D = preload("res://assets/ui/menu_particles_back.png")
const PARTICLES_FRONT: Texture2D = preload("res://assets/ui/menu_particles_front.png")
const MENU_BACKGROUND: Texture2D = preload("res://assets/ui/menu_background.png")
const TITLE_COLUMN_LEFT := 116.0
const TITLE_COLUMN_WIDTH := 456.0
const MAIN_TITLE_NUDGE_X := 10.0

const TEXT_NORMAL := Color("#2f6b96")
const TEXT_HOVER := Color("#d8fbff")
const TEXT_DISABLED := Color("#2a3d4d")

var _menu_row_count := 0

var _slot_overlay: Control = null
var _options_overlay: Control = null
var _overlay_mode := ""
var _seed_input: LineEdit
var _seed_hint: Label

# 立绘动效状态
var _hero: TextureRect = null
var _hero_base_position := Vector2.ZERO
var _float_time := 0.0
var _rear_particles: Sprite2D
var _front_particles: Sprite2D
const PARTICLE_POSITION := Vector2(-12, -124)


func _ready() -> void:
	_build_ui()


## 兼容旧入口：直接以无槽位模式进入游戏（测试脚本依赖此方法存在）。
func start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func quit_game() -> void:
	get_tree().quit()


func _build_ui() -> void:
	# 背景图：铺满窗口，降低 30% 不透明度（alpha=0.7），叠在深色底板上。
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.custom_minimum_size = Vector2.ZERO
	background.texture = MENU_BACKGROUND
	background.position = Vector2.ZERO
	background.size = Vector2(1180.0, 660.0)
	background.modulate = Color(1.0, 1.0, 1.0, 0.7)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_rear_particles = _add_particle_layer("ParticlesBack", PARTICLES_BACK, 0.8)

	# 右侧：新立绘作为视觉主体（边缘柔光 + 微微飘动）。
	var hero := TextureRect.new()
	hero.name = "CharacterStandee"
	hero.texture = HERO_STANDEE
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.custom_minimum_size = Vector2.ZERO
	# Keep the supplied full-canvas artwork proportional, including its transparent left margin.
	hero.size = Vector2(660.0 * HERO_STANDEE.get_width() / HERO_STANDEE.get_height(), 660.0)
	hero.position = Vector2(180.0, 0.0)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hero.pivot_offset = hero.size * 0.5
	hero.material = _make_hero_glow_material()
	add_child(hero)
	_hero = hero
	_hero_base_position = hero.position
	_front_particles = _add_particle_layer("ParticlesFront", PARTICLES_FRONT, 0.9)
	# Restore falling snow above the artwork and below menu controls.
	var snow := get_node_or_null("GPUParticles2D") as GPUParticles2D
	if snow != null:
		snow.preprocess = snow.lifetime
		move_child(snow, get_child_count() - 1)
	_build_title_block()

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


func _add_particle_layer(layer_name: String, art: Texture2D, opacity: float) -> Sprite2D:
	# Control positions snap to pixels in this UI viewport. A Sprite2D preserves
	# fractional drift without disabling pixel alignment for menu text/buttons.
	var layer := Sprite2D.new()
	layer.name = layer_name
	layer.texture = art
	layer.centered = false
	layer.scale = Vector2.ONE * (1204.0 / art.get_width())
	layer.position = PARTICLE_POSITION
	layer.modulate.a = opacity
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(layer)
	return layer


## 两段式标题：上行压暗作为系列名，下行以高亮冰蓝描边强化主标题。
func _build_title_block() -> void:
	var series_title := _make_label(
		self,
		"东方冰华战线",
		Vector2(TITLE_COLUMN_LEFT - 8.0, 68.0),
		Vector2(TITLE_COLUMN_WIDTH, 46.0),
		34,
		Color("#397ca5")
	)
	series_title.add_theme_font_override("font", PIXEL_FONT)
	series_title.add_theme_color_override("font_outline_color", Color("#071b31"))
	series_title.add_theme_constant_override("outline_size", 2)
	series_title.add_theme_color_override("font_shadow_color", Color(0.01, 0.08, 0.16, 0.85))
	series_title.add_theme_constant_override("shadow_offset_x", 2)
	series_title.add_theme_constant_override("shadow_offset_y", 2)
	series_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var main_title := _make_label(
		self,
		"冰封幻想乡",
		Vector2(TITLE_COLUMN_LEFT + MAIN_TITLE_NUDGE_X, 106.0),
		Vector2(TITLE_COLUMN_WIDTH, 84.0),
		62,
		Color("#c8f8ff")
	)
	main_title.add_theme_font_override("font", PIXEL_FONT)
	main_title.add_theme_color_override("font_outline_color", Color("#176188"))
	main_title.add_theme_constant_override("outline_size", 5)
	main_title.add_theme_color_override("font_shadow_color", Color(0.01, 0.16, 0.3, 0.95))
	main_title.add_theme_constant_override("shadow_offset_x", 5)
	main_title.add_theme_constant_override("shadow_offset_y", 6)
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_build_title_banner()

	var english_title := _make_label(
		self,
		"Touhou Ice Frontline: Frozen Gensokyo",
		Vector2(TITLE_COLUMN_LEFT, 242.0),
		Vector2(TITLE_COLUMN_WIDTH, 30.0),
		20,
		Color("#78cce5")
	)
	english_title.add_theme_font_override("font", PIXEL_FONT)
	english_title.add_theme_color_override("font_shadow_color", Color(0.01, 0.1, 0.2, 0.85))
	english_title.add_theme_constant_override("shadow_offset_x", 2)
	english_title.add_theme_constant_override("shadow_offset_y", 2)
	english_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 使用原图的有效区域，去掉透明留白并保持图案比例。
func _build_title_banner() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = PixelUITheme.icon("title_banner_shrine.png")
	atlas.region = Rect2(24.0, 268.0, 2124.0, 190.0)
	atlas.filter_clip = true

	var banner := TextureRect.new()
	banner.name = "TitleBanner"
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner.texture = atlas
	var banner_height := TITLE_COLUMN_WIDTH * atlas.region.size.y / atlas.region.size.x
	banner.position = Vector2(TITLE_COLUMN_LEFT, 219.0 - banner_height * 0.5)
	banner.size = Vector2(TITLE_COLUMN_WIDTH, banner_height)
	banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)


# ---------------------------------------------------------------- 立绘动效

func _process(delta: float) -> void:
	if _hero == null:
		return
	_float_time += delta
	var t := _float_time
	# 立绘小范围微微飘动：垂直浮动 + 轻微水平漂移 + 极轻旋转。
	_hero.position = _hero_base_position + Vector2(sin(t * 0.55) * 4.0, sin(t * 0.9) * 7.0)
	_hero.rotation = sin(t * 0.48) * 0.012
	_rear_particles.position = PARTICLE_POSITION + Vector2(sin(t * 0.21) * 3.0, cos(t * 0.26) * 3.0)
	_front_particles.position = PARTICLE_POSITION + Vector2(sin(t * 0.34) * -6.0, sin(t * 0.4) * 5.0)


## 立绘边缘柔光：环形采样 alpha 模糊出冰蓝辉光，垫在立绘本体之下。
func _make_hero_glow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float glow_radius = 16.0;
uniform float glow_intensity = 0.5;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float acc = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = float(i) * 0.3926991;
		vec2 dir = vec2(cos(ang), sin(ang));
		acc += texture(TEXTURE, UV + dir * TEXTURE_PIXEL_SIZE * glow_radius).a;
		acc += texture(TEXTURE, UV + dir * TEXTURE_PIXEL_SIZE * glow_radius * 0.5).a;
	}
	acc /= 32.0;
	vec4 glow = vec4(glow_color.rgb, acc * glow_intensity);
	COLOR = mix(glow, tex, tex.a);
}
"""
	var glow_material := ShaderMaterial.new()
	glow_material.shader = shader
	return glow_material


## 无边框菜单选项：悬停/聚焦时文本高亮右移，雪花与渐变线同步淡入。
func _add_menu_item(text: String, handler: Callable, disabled := false) -> void:
	var row_y := 300.0 + float(_menu_row_count) * 58.0
	_menu_row_count += 1

	var button := Button.new()
	button.text = text
	button.position = Vector2(TITLE_COLUMN_LEFT + (TITLE_COLUMN_WIDTH - 300.0) * 0.5, row_y)
	button.size = Vector2(300.0, 48.0)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.disabled = disabled
	button.add_theme_font_size_override("font_size", 25)
	add_child(button)
	PixelUITheme.attach_menu_option_fx(button, self, button.position, true)
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
	if _overlay_mode == "new":
		panel.position.y = 70.0
		panel.size.y = 520.0
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color("#0a2038"), Color("#86e9ff")))
	_slot_overlay.add_child(panel)

	var title := _make_label(panel, title_text, Vector2(20.0, 18.0), Vector2(560.0, 34.0), 24, Color("#edfdff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if _overlay_mode == "new":
		_make_label(panel, "地图种子", Vector2(40, 68), Vector2(100, 32), 18, Color("#c3e9f3"))
		_seed_input = LineEdit.new()
		_seed_input.position = Vector2(140, 64)
		_seed_input.size = Vector2(316, 40)
		_seed_input.placeholder_text = "留空生成随机地图"
		_seed_input.max_length = 10
		_seed_input.add_theme_font_size_override("font_size", 18)
		panel.add_child(_seed_input)
		var random_button := _make_panel_button("随机", 16)
		random_button.position = Vector2(466, 64)
		random_button.size = Vector2(94, 40)
		random_button.pressed.connect(func():
			_seed_input.text = str(randi_range(0, 2147483647))
			_seed_hint.text = "相同编号生成相同地图。选择下方槽位开始。")
		panel.add_child(random_button)
		_seed_hint = _make_label(panel, "输入 0–2147483647 的编号可重现地图；留空随机。", Vector2(40, 111), Vector2(520, 38), 16, Color("#a3c6d5"))
		_seed_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for slot in range(SaveManager.SLOT_COUNT):
		_build_slot_row(panel, slot)

	var back_button := _make_panel_button("返回", 15)
	back_button.position = Vector2(240.0, 356.0)
	if _overlay_mode == "new": back_button.position.y = 456.0
	back_button.size = Vector2(120.0, 44.0)
	back_button.pressed.connect(_hide_overlays)
	panel.add_child(back_button)


func _build_slot_row(panel: Panel, slot: int) -> void:
	var summary := SaveManager.get_slot_summary(slot)
	var has_save := not summary.is_empty()
	var row := Button.new()
	row.position = Vector2(40.0, 74.0 + float(slot) * 92.0)
	if _overlay_mode == "new": row.position.y += 90.0
	row.size = Vector2(520.0, 76.0)
	row.add_theme_font_size_override("font_size", 17)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	PixelUITheme.apply_button_theme(row)
	PixelUITheme.attach_button_sound_feedback(row)

	if has_save:
		row.text = "  槽位 %d    第 %d 波 · %s %d · 建筑 %d 座\n  保存于 %s" % [
			slot + 1,
			int(summary.get("wave", 0)),
			"金币" if summary.get("mode") == "rts" else "冻气",
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
		var seed_text := _seed_input.text.strip_edges() if is_instance_valid(_seed_input) else ""
		if not SessionScript.valid_map_seed(seed_text):
			_seed_hint.text = "种子需为 0–2147483647 的整数，请重新输入。"
			_seed_input.grab_focus()
			return
		SessionScript.requested_map_seed = str(int(seed_text)) if not seed_text.is_empty() else ""
		SessionScript.current_slot = slot
		SessionScript.pending_load_slot = -1
		SaveManager.delete_slot(slot)
	else:
		SessionScript.current_slot = slot
		SessionScript.pending_load_slot = slot
	var destination := GAME_SCENE_PATH
	if _overlay_mode == "continue" and SaveManager.read_slot(slot).get("mode", "legacy") != "rts":
		destination = "res://scenes/main.tscn"
	get_tree().change_scene_to_file(destination)


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
	var help_button := _make_panel_button("新版远征操作说明", 15)
	help_button.position = Vector2(100.0, 132.0)
	help_button.size = Vector2(200.0, 40.0)
	help_button.pressed.connect(_show_expedition_help)
	panel.add_child(help_button)

	var back_button := _make_panel_button("返回", 15)
	back_button.position = Vector2(140.0, 190.0)
	back_button.size = Vector2(120.0, 44.0)
	back_button.pressed.connect(_hide_overlays)
	panel.add_child(back_button)


func _show_expedition_help() -> void:
	_hide_overlays()
	_options_overlay = _make_overlay_dimmer()
	var panel := Panel.new()
	panel.position = Vector2(210.0, 110.0)
	panel.size = Vector2(760.0, 440.0)
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style())
	_options_overlay.add_child(panel)
	_make_label(panel, "冰华远征操作说明", Vector2(30, 20), Vector2(700, 36), 25, Color("#edfdff"))
	_make_label(panel, "确认两张效果牌后，从地图中央的火把营地出发。\n基地不再自动产金币；探索迷雾，右键占领资源点（停留 5 秒）。\n金矿 +3 金/秒，魔力泉 +2 BAKA/秒；灵视塔在小地图揭示资源位置。\n\n左键单选/框选，右键友军选中；A 同类/全军，Shift＋右键友军追加。\nF 攻击移动，S 停止，D 原地防守；Shift 追加移动、攻击、占领或建修。\n左键选基地/兵营后，右键设集结点；Shift＋右键增加路线点。\nCtrl＋0–9 编队；数字键选队，双击数字定位；I 循环选择空闲部队。\n编队栏显示人数/生命/交战状态，小地图红圈提示受袭。\n\nQ 冰冻、W 冰墙、E 冰桥；G 驻军、R 修复；滚轮平滑缩放。\nTab 俯瞰，H 回基地，P 暂停，Space 迎敌，F5 保存；底栏右侧可收起。\n守完六波并清剿敌军与建筑获胜；己方基地和全部建筑被毁才失败。", Vector2(30, 75), Vector2(700, 290), 16, Color("#c3e9f3"))
	var back := _make_panel_button("返回", 16)
	back.position = Vector2(310, 376)
	back.size = Vector2(140, 42)
	back.pressed.connect(_hide_overlays)
	panel.add_child(back)


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
	# 仅保留深色背景底板。
	draw_rect(Rect2(Vector2.ZERO, Vector2(1180.0, 660.0)), Color("#06121f"))


func _make_panel_button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	PixelUITheme.apply_button_theme(button)
	PixelUITheme.attach_button_sound_feedback(button)
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

