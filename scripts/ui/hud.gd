class_name BattleHUD
extends CanvasLayer

const PixelUITheme = preload("res://scripts/ui/pixel_ui.gd")
const CirnoSprite = preload("res://scripts/entities/cirno_sprite.gd")
const MinimapScript = preload("res://scripts/ui/minimap.gd")

signal build_item_selected(build_id: String)
signal start_wave_requested
signal upgrade_structure_requested
signal modifier_card_selected(pool: String, modifier_id: String)
signal hero_skill_requested(slot: String)
signal restart_requested
signal menu_requested
## 需求 5：波末结算确认 → 游戏转入祝福三选一。
signal settlement_continue_requested

const VIEWPORT_SIZE := Vector2(1180.0, 660.0)
const TOP_BAR_HEIGHT := 72.0
const DOCK_HEIGHT := 126.0
const DOCK_COLLAPSED_HEIGHT := 36.0
const MINIMAP_SIZE := Vector2(176.0, 132.0)

var _hp_label: Label
var _hp_bar: ProgressBar
var _resource_label: Label
var _wave_label: Label
var _status_label: Label

var _dock: Panel
var _dock_content: Control
var _dock_toggle: Button
var _dock_collapsed := false

var _start_button: Button
var _build_buttons: Dictionary = {}
var _skill_buttons: Dictionary = {}

var _detail_panel: Panel
var _structure_detail_label: Label
var _upgrade_button: Button

var _modifier_overlay: Control
var _modifier_title: Label
var _modifier_subtitle: Label
var _modifier_buttons: Array[Button] = []
var _modifier_choices: Array[Dictionary] = []
var _modifier_pool := ""

var _settlement_overlay: Control
var _settlement_title: Label
var _settlement_body: Label

var _result_overlay: Control
var _result_title: Label
var _result_description: Label

var _minimap: BattleMinimap

var _selected_build_id := "icicle"
var _selected_structure: DefenseStructure
var _frost := 0
var _hp_bar_fill_tier := 2


func _ready() -> void:
	_build_top_bar()
	_build_minimap()
	_build_dock()
	_build_detail_panel()
	_build_modifier_overlay()
	_build_settlement_overlay()
	_build_result_overlay()
	select_build_item("icicle")


## 右上角小地图：缩略全图 + 镜头范围，点击跳转。
func _build_minimap() -> void:
	_minimap = MinimapScript.new()
	_minimap.position = Vector2(VIEWPORT_SIZE.x - MINIMAP_SIZE.x - 8.0, TOP_BAR_HEIGHT + 8.0)
	_minimap.size = MINIMAP_SIZE
	add_child(_minimap)


## 由游戏场景注入引用，小地图借此读取单位位置并回传镜头跳转。
func setup_minimap(game: Node) -> void:
	if _minimap != null:
		_minimap.setup(game)


## 需求 3：顶部横贯状态栏 —— 琪露诺血条、冻气、冰晶、波次、状态文字。
func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.position = Vector2.ZERO
	bar.size = Vector2(VIEWPORT_SIZE.x, TOP_BAR_HEIGHT)
	bar.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color(0.02, 0.09, 0.16, 0.94), Color("#3d8caf")))
	add_child(bar)

	# 琪露诺像素头像（精灵表 idle 第 0 帧）。
	var portrait_texture := CirnoSprite.frame_texture("idle", 0)
	if portrait_texture != null:
		var portrait := TextureRect.new()
		portrait.texture = portrait_texture
		portrait.position = Vector2(14.0, 6.0)
		portrait.size = Vector2(56.0, 56.0)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bar.add_child(portrait)

	var title := _make_label(bar, "琪露诺的智商保卫战", Vector2(76.0, 6.0), Vector2(120.0, 44.0), 13, Color("#ebfdff"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_hp_label = _make_label(bar, "琪露诺生命 240 / 240", Vector2(198.0, 6.0), Vector2(212.0, 22.0), 15, Color("#9ff4ff"))
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(198.0, 32.0)
	_hp_bar.size = Vector2(212.0, 16.0)
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 240.0
	_hp_bar.value = 240.0
	_hp_bar.show_percentage = false
	_hp_bar.add_theme_stylebox_override("background", PixelUITheme.bar_back())
	_hp_bar.add_theme_stylebox_override("fill", PixelUITheme.bar_fill(1.0))
	bar.add_child(_hp_bar)

	_resource_label = _make_label(bar, "冻气 180    冰晶 0", Vector2(426.0, 6.0), Vector2(220.0, 22.0), 15, Color("#ddf8ff"))
	_wave_label = _make_label(bar, "准备 · 第 0 / 10 波 · 在场 0", Vector2(426.0, 34.0), Vector2(300.0, 22.0), 13, Color("#b5d7e5"))
	_status_label = _make_label(bar, "", Vector2(734.0, 6.0), Vector2(434.0, 60.0), 12, Color("#8fb4c8"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## 需求 3：底部可收起的半透明 dock —— 塔/兵营建造、技能、开波、收起开关。
func _build_dock() -> void:
	_dock = Panel.new()
	_dock.position = Vector2(0.0, VIEWPORT_SIZE.y - DOCK_HEIGHT)
	_dock.size = Vector2(VIEWPORT_SIZE.x, DOCK_HEIGHT)
	_dock.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color(0.03, 0.11, 0.19, 0.86), Color("#3d8caf")))
	add_child(_dock)

	_dock_content = Control.new()
	_dock_content.position = Vector2.ZERO
	_dock_content.size = Vector2(VIEWPORT_SIZE.x, DOCK_HEIGHT)
	_dock.add_child(_dock_content)

	_dock_toggle = Button.new()
	_dock_toggle.text = "收起 ▼"
	_dock_toggle.position = Vector2(VIEWPORT_SIZE.x - 92.0, 4.0)
	_dock_toggle.size = Vector2(84.0, 26.0)
	_dock_toggle.add_theme_font_size_override("font_size", 12)
	PixelUITheme.apply_button_theme(_dock_toggle)
	_dock_toggle.pressed.connect(_on_dock_toggle_pressed)
	_dock.add_child(_dock_toggle)

	_make_label(_dock_content, "建造 · 数字键 1-6", Vector2(14.0, 6.0), Vector2(176.0, 20.0), 13, Color("#e7fbff"))

	var group := ButtonGroup.new()
	var button_index := 0
	for build_id in BuildCatalog.ORDER:
		var definition := BuildCatalog.get_definition(build_id)
		var button := Button.new()
		button.position = Vector2(14.0 + button_index * 175.0, 30.0)
		button.size = Vector2(168.0, 52.0)
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%d  %s\n%d冻气 · %s" % [
			button_index + 1,
			str(definition.get("name", build_id)),
			int(definition.get("cost", 0)),
			str(definition.get("role", "")),
		]
		button.add_theme_font_size_override("font_size", 11)
		PixelUITheme.apply_button_theme(button)
		button.pressed.connect(_on_build_button_pressed.bind(str(build_id)))
		_dock_content.add_child(button)
		_build_buttons[str(build_id)] = button
		button_index += 1

	_make_label(_dock_content, "技能", Vector2(14.0, 96.0), Vector2(60.0, 22.0), 13, Color("#e7fbff"))

	var nova_button := _make_action_button("Q 冰霜新星", Color("#246f99"))
	nova_button.position = Vector2(80.0, 92.0)
	nova_button.size = Vector2(168.0, 30.0)
	nova_button.pressed.connect(func() -> void: hero_skill_requested.emit("nova"))
	_dock_content.add_child(nova_button)
	_skill_buttons["nova"] = nova_button

	var freeze_button := _make_action_button("R 完美冻结", Color("#6255a8"))
	freeze_button.position = Vector2(258.0, 92.0)
	freeze_button.size = Vector2(168.0, 30.0)
	freeze_button.pressed.connect(func() -> void: hero_skill_requested.emit("freeze"))
	_dock_content.add_child(freeze_button)
	_skill_buttons["freeze"] = freeze_button

	_start_button = _make_action_button("开始第 1 波", Color("#2f8b70"))
	_start_button.position = Vector2(952.0, 88.0)
	_start_button.size = Vector2(210.0, 34.0)
	_start_button.add_theme_font_size_override("font_size", 14)
	_start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	_dock_content.add_child(_start_button)


func _on_dock_toggle_pressed() -> void:
	_dock_collapsed = not _dock_collapsed
	_dock_content.visible = not _dock_collapsed
	if _dock_collapsed:
		_dock.size.y = DOCK_COLLAPSED_HEIGHT
		_dock.position.y = VIEWPORT_SIZE.y - DOCK_COLLAPSED_HEIGHT
		_dock_toggle.text = "展开 ▲"
	else:
		_dock.size.y = DOCK_HEIGHT
		_dock.position.y = VIEWPORT_SIZE.y - DOCK_HEIGHT
		_dock_toggle.text = "收起 ▼"


## 建筑详情：选中单个结构时在右下浮现，平时隐藏，不占用右侧空间（需求 3）。
func _build_detail_panel() -> void:
	_detail_panel = Panel.new()
	_detail_panel.position = Vector2(VIEWPORT_SIZE.x - 312.0, VIEWPORT_SIZE.y - DOCK_HEIGHT - 176.0)
	_detail_panel.size = Vector2(296.0, 168.0)
	_detail_panel.visible = false
	_detail_panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color(0.03, 0.12, 0.21, 0.94), Color("#86e9ff")))
	add_child(_detail_panel)

	var title := _make_label(_detail_panel, "建筑详情", Vector2(12.0, 6.0), Vector2(272.0, 20.0), 13, Color("#e7fbff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_structure_detail_label = _make_label(_detail_panel, "", Vector2(14.0, 30.0), Vector2(268.0, 76.0), 13, Color("#b6d9e8"))
	_structure_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_upgrade_button = _make_action_button("升级", Color("#2f8b70"))
	_upgrade_button.position = Vector2(14.0, 112.0)
	_upgrade_button.size = Vector2(268.0, 44.0)
	_upgrade_button.add_theme_font_size_override("font_size", 14)
	_upgrade_button.pressed.connect(func() -> void: upgrade_structure_requested.emit())
	_detail_panel.add_child(_upgrade_button)


## 需求 4：祝福/附魔弹窗 —— 横向三个选项，phase 门控确保当前波次选择。
func _build_modifier_overlay() -> void:
	_modifier_overlay = Control.new()
	_modifier_overlay.size = VIEWPORT_SIZE
	_modifier_overlay.visible = false
	_modifier_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modifier_overlay)

	var blocker := ColorRect.new()
	blocker.size = VIEWPORT_SIZE
	blocker.color = Color(0.01, 0.03, 0.07, 0.86)
	_modifier_overlay.add_child(blocker)

	var panel := Panel.new()
	panel.position = Vector2((VIEWPORT_SIZE.x - 650.0) * 0.5, 78.0)
	panel.size = Vector2(650.0, 506.0)
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color("#0a2038"), Color("#86e9ff")))
	_modifier_overlay.add_child(panel)

	_modifier_title = _make_label(panel, "笨蛋灵感", Vector2(28.0, 16.0), Vector2(594.0, 36.0), 28, Color("#edfdff"))
	_modifier_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modifier_subtitle = _make_label(panel, "选择一项强化，然后继续。", Vector2(34.0, 56.0), Vector2(582.0, 28.0), 14, Color("#9ac4d7"))
	_modifier_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for index in range(3):
		var button := Button.new()
		button.position = Vector2(30.0 + index * 200.0, 96.0)
		button.size = Vector2(186.0, 324.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_stylebox_override("normal", PixelUITheme.card_style())
		button.add_theme_stylebox_override("hover", PixelUITheme.card_style(Color("#174d67"), Color("#c7f8ff")))
		button.add_theme_stylebox_override("pressed", PixelUITheme.card_style(Color("#0c2438"), Color("#c7f8ff")))
		button.pressed.connect(_on_modifier_card_pressed.bind(index))
		panel.add_child(button)
		_modifier_buttons.append(button)


## 需求 5：波末结算弹窗 —— 显示本波金钱收益，确认后进入祝福三选一。
func _build_settlement_overlay() -> void:
	_settlement_overlay = Control.new()
	_settlement_overlay.size = VIEWPORT_SIZE
	_settlement_overlay.visible = false
	_settlement_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_settlement_overlay)

	var blocker := ColorRect.new()
	blocker.size = VIEWPORT_SIZE
	blocker.color = Color(0.01, 0.03, 0.07, 0.72)
	_settlement_overlay.add_child(blocker)

	var panel := Panel.new()
	panel.position = Vector2(365.0, 206.0)
	panel.size = Vector2(450.0, 248.0)
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color("#0a2038"), Color("#86e9ff")))
	_settlement_overlay.add_child(panel)

	_settlement_title = _make_label(panel, "第 1 波 结算", Vector2(30.0, 20.0), Vector2(390.0, 36.0), 24, Color("#edfdff"))
	_settlement_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_settlement_body = _make_label(panel, "", Vector2(36.0, 68.0), Vector2(378.0, 86.0), 14, Color("#b6d9e8"))
	_settlement_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settlement_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settlement_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var continue_button := _make_action_button("选择祝福 →", Color("#2f8b70"))
	continue_button.position = Vector2(60.0, 174.0)
	continue_button.size = Vector2(330.0, 50.0)
	continue_button.add_theme_font_size_override("font_size", 16)
	continue_button.pressed.connect(func() -> void: settlement_continue_requested.emit())
	panel.add_child(continue_button)


func _build_result_overlay() -> void:
	_result_overlay = Control.new()
	_result_overlay.size = VIEWPORT_SIZE
	_result_overlay.visible = false
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result_overlay)

	var blocker := ColorRect.new()
	blocker.size = VIEWPORT_SIZE
	blocker.color = Color(0.01, 0.03, 0.07, 0.90)
	_result_overlay.add_child(blocker)

	var panel := Panel.new()
	panel.position = Vector2(350.0, 158.0)
	panel.size = Vector2(480.0, 334.0)
	panel.add_theme_stylebox_override("panel", PixelUITheme.panel_style(Color("#0b223b"), Color("#8cecff")))
	_result_overlay.add_child(panel)

	_result_title = _make_label(panel, "IQ 保卫成功！", Vector2(30.0, 34.0), Vector2(420.0, 48.0), 32, Color("#c9fff0"))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_description = _make_label(panel, "你守住了琪露诺的 IQ。", Vector2(45.0, 104.0), Vector2(390.0, 100.0), 17, Color("#b6d9e8"))
	_result_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var restart := _make_action_button("再守一次", Color("#2f8b70"))
	restart.position = Vector2(55.0, 235.0)
	restart.size = Vector2(175.0, 54.0)
	restart.add_theme_font_size_override("font_size", 17)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(restart)

	var menu_button := _make_action_button("返回主菜单", Color("#2c6c8e"))
	menu_button.position = Vector2(250.0, 235.0)
	menu_button.size = Vector2(175.0, 54.0)
	menu_button.add_theme_font_size_override("font_size", 17)
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	panel.add_child(menu_button)


func update_resources(hero_hp: int, hero_max_hp: int, frost: int, ice_crystals: int, wave_text: String, status_text: String) -> void:
	_frost = frost
	var ratio := clampf(float(hero_hp) / maxf(1.0, float(hero_max_hp)), 0.0, 1.0)
	_hp_label.text = "琪露诺生命  %d / %d" % [hero_hp, hero_max_hp]
	if ratio <= 0.35:
		_hp_label.add_theme_color_override("font_color", Color("#ff9bad"))
	else:
		_hp_label.add_theme_color_override("font_color", Color("#9ff4ff"))
	_hp_bar.max_value = maxf(1.0, float(hero_max_hp))
	_hp_bar.value = float(hero_hp)
	var fill_tier := 0 if ratio <= 0.35 else (1 if ratio <= 0.65 else 2)
	if _hp_bar_fill_tier != fill_tier:
		_hp_bar_fill_tier = fill_tier
		_hp_bar.add_theme_stylebox_override("fill", PixelUITheme.bar_fill(ratio))
	_resource_label.text = "冻气  %d    冰晶  %d" % [frost, ice_crystals]
	_wave_label.text = wave_text
	_status_label.text = status_text
	_update_upgrade_button()


func select_build_item(build_id: String) -> void:
	if not _build_buttons.has(build_id):
		return
	_selected_build_id = build_id
	for key in _build_buttons:
		var button: Button = _build_buttons[key]
		button.button_pressed = str(key) == build_id


func set_start_button(enabled: bool, text: String) -> void:
	_start_button.disabled = not enabled
	_start_button.text = text


func show_structure_detail(structure: DefenseStructure) -> void:
	if structure == null or not is_instance_valid(structure):
		clear_structure_detail()
		return
	_selected_structure = structure
	_structure_detail_label.text = structure.get_detail_text()
	_upgrade_button.visible = true
	_detail_panel.visible = true
	_update_upgrade_button()


func refresh_structure_detail(structure: DefenseStructure, frost: int) -> void:
	if structure == null or not is_instance_valid(structure):
		clear_structure_detail()
		return
	_selected_structure = structure
	_frost = frost
	_structure_detail_label.text = structure.get_detail_text()
	_upgrade_button.visible = true
	_detail_panel.visible = true
	_update_upgrade_button()


func clear_structure_detail() -> void:
	_selected_structure = null
	_detail_panel.visible = false
	_upgrade_button.visible = false


func show_modifier_choices(pool: String, title: String, subtitle: String, choices: Array[Dictionary]) -> void:
	_modifier_pool = pool
	_modifier_choices = choices
	_modifier_title.text = title
	_modifier_subtitle.text = subtitle
	for index in range(_modifier_buttons.size()):
		var button := _modifier_buttons[index]
		if index >= choices.size():
			button.visible = false
			continue
		var definition := choices[index]
		button.visible = true
		button.text = "%s\n\n%s\n\n%s" % [
			str(definition.get("rarity", "强化")),
			str(definition.get("name", "未命名")),
			str(definition.get("description", "")),
		]
	_modifier_overlay.visible = true


func hide_modifier_choices() -> void:
	_modifier_overlay.visible = false
	_modifier_choices.clear()


## 需求 5：显示波末结算弹窗。
func show_settlement(wave_number: int, projected_reward: int) -> void:
	_settlement_title.text = "第 %d 波 结算" % wave_number
	_settlement_body.text = "选择祝福后获得：至少 +%d 冻气\n奖励随波次提高；奖励类祝福会立即计入本次结算。\n当前波次兵种已返回兵营附近驻扎。" % projected_reward
	_settlement_overlay.visible = true


func hide_settlement() -> void:
	_settlement_overlay.visible = false


func set_skill_state(slot: String, text: String, ready: bool) -> void:
	if not _skill_buttons.has(slot):
		return
	var button: Button = _skill_buttons[slot]
	button.text = text
	button.disabled = not ready


func show_result(victory: bool, description: String) -> void:
	_result_title.text = "IQ 保卫成功！" if victory else "IQ 归零……"
	_result_title.add_theme_color_override("font_color", Color("#c9fff0") if victory else Color("#ff9bad"))
	_result_description.text = description
	_result_overlay.visible = true


func _on_build_button_pressed(build_id: String) -> void:
	clear_structure_detail()
	select_build_item(build_id)
	build_item_selected.emit(build_id)


func _on_modifier_card_pressed(index: int) -> void:
	if index < 0 or index >= _modifier_choices.size():
		return
	var modifier_id := str(_modifier_choices[index].get("id", ""))
	if not modifier_id.is_empty():
		modifier_card_selected.emit(_modifier_pool, modifier_id)


func _update_upgrade_button() -> void:
	if _selected_structure == null or not is_instance_valid(_selected_structure):
		_upgrade_button.visible = false
		return
	_upgrade_button.visible = true
	if _selected_structure.level >= 3:
		_upgrade_button.text = "已满级"
		_upgrade_button.disabled = true
		return
	var cost := _selected_structure.get_upgrade_cost()
	_upgrade_button.text = "升级至 Lv.%d  [%d 冻气]" % [_selected_structure.level + 1, cost]
	_upgrade_button.disabled = _frost < cost


func _make_action_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 14)
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


func _bar_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style


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
