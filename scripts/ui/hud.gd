class_name BattleHUD
extends CanvasLayer

signal build_item_selected(build_id: String)
signal start_wave_requested
signal upgrade_structure_requested
signal modifier_card_selected(pool: String, modifier_id: String)
signal hero_skill_requested(slot: String)
signal restart_requested

const PANEL_X := 770.0
const PANEL_WIDTH := 398.0

var _iq_label: Label
var _resource_label: Label
var _wave_label: Label
var _status_label: Label
var _structure_detail_label: Label
var _start_button: Button
var _upgrade_button: Button
var _build_buttons: Dictionary = {}
var _skill_buttons: Dictionary = {}

var _modifier_overlay: Control
var _modifier_title: Label
var _modifier_subtitle: Label
var _modifier_buttons: Array[Button] = []
var _modifier_choices: Array[Dictionary] = []
var _modifier_pool := ""

var _result_overlay: Control
var _result_title: Label
var _result_description: Label

var _selected_build_id := "icicle"
var _selected_structure: DefenseStructure
var _frost := 0


func _ready() -> void:
	_build_side_panel()
	_build_modifier_overlay()
	_build_result_overlay()
	select_build_item("icicle")


func _build_side_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(PANEL_X, 12.0)
	panel.size = Vector2(PANEL_WIDTH, 636.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#071a2d"), Color("#3d8caf")))
	add_child(panel)

	var title := _make_label(panel, "琪露诺的智商保卫战", Vector2(16.0, 8.0), Vector2(366.0, 30.0), 21, Color("#ebfdff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_iq_label = _make_label(panel, "IQ 20 / 20", Vector2(18.0, 40.0), Vector2(362.0, 24.0), 18, Color("#9ff4ff"))
	_resource_label = _make_label(panel, "冻气 180   冰晶 0", Vector2(18.0, 64.0), Vector2(362.0, 24.0), 16, Color("#ddf8ff"))
	_wave_label = _make_label(panel, "准备 · 第 0 / 10 波 · 在场 0", Vector2(18.0, 90.0), Vector2(362.0, 22.0), 14, Color("#b5d7e5"))
	_status_label = _make_label(panel, "右键移动琪露诺；选择建筑后点击草地格部署。", Vector2(18.0, 113.0), Vector2(362.0, 46.0), 12, Color("#8fb4c8"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var build_title := _make_label(panel, "建造 · 数字键 1-6", Vector2(18.0, 162.0), Vector2(362.0, 20.0), 15, Color("#e7fbff"))
	build_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var group := ButtonGroup.new()
	var button_index := 0
	for build_id in BuildCatalog.ORDER:
		var definition := BuildCatalog.get_definition(build_id)
		var column := button_index % 2
		var row := button_index / 2
		var button := Button.new()
		button.position = Vector2(18.0 + column * 184.0, 184.0 + row * 70.0)
		button.size = Vector2(178.0, 62.0)
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%d  %s\n%d冻气 · %s" % [
			button_index + 1,
			str(definition.get("name", build_id)),
			int(definition.get("cost", 0)),
			str(definition.get("role", "")),
		]
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_stylebox_override("normal", _button_style(Color("#102d46"), Color("#2c6c8e"), 1))
		button.add_theme_stylebox_override("hover", _button_style(Color("#16415d"), Color("#8fe8ff"), 2))
		button.add_theme_stylebox_override("pressed", _button_style(Color("#1b5a78"), Color("#d8fbff"), 2))
		button.pressed.connect(_on_build_button_pressed.bind(str(build_id)))
		panel.add_child(button)
		_build_buttons[str(build_id)] = button
		button_index += 1

	var skill_title := _make_label(panel, "琪露诺技能", Vector2(18.0, 399.0), Vector2(362.0, 20.0), 14, Color("#e7fbff"))
	skill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var nova_button := _make_action_button("Q 冰霜新星", Color("#246f99"))
	nova_button.position = Vector2(18.0, 421.0)
	nova_button.size = Vector2(178.0, 38.0)
	nova_button.pressed.connect(func() -> void: hero_skill_requested.emit("nova"))
	panel.add_child(nova_button)
	_skill_buttons["nova"] = nova_button

	var freeze_button := _make_action_button("R 完美冻结", Color("#6255a8"))
	freeze_button.position = Vector2(202.0, 421.0)
	freeze_button.size = Vector2(178.0, 38.0)
	freeze_button.pressed.connect(func() -> void: hero_skill_requested.emit("freeze"))
	panel.add_child(freeze_button)
	_skill_buttons["freeze"] = freeze_button

	_structure_detail_label = _make_label(panel, "点击已有建筑可查看状态并升级。\n右键建筑后点击妖精可指定优先目标。", Vector2(18.0, 468.0), Vector2(362.0, 55.0), 12, Color("#d7edf5"))
	_structure_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_upgrade_button = _make_action_button("升级选中建筑", Color("#8a6b2a"))
	_upgrade_button.position = Vector2(18.0, 530.0)
	_upgrade_button.size = Vector2(362.0, 34.0)
	_upgrade_button.visible = false
	_upgrade_button.pressed.connect(func() -> void: upgrade_structure_requested.emit())
	panel.add_child(_upgrade_button)

	_start_button = _make_action_button("开始第 1 波", Color("#2f8b70"))
	_start_button.position = Vector2(18.0, 576.0)
	_start_button.size = Vector2(362.0, 44.0)
	_start_button.add_theme_font_size_override("font_size", 17)
	_start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	panel.add_child(_start_button)


func _build_modifier_overlay() -> void:
	_modifier_overlay = Control.new()
	_modifier_overlay.size = Vector2(1180.0, 660.0)
	_modifier_overlay.visible = false
	_modifier_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modifier_overlay)

	var blocker := ColorRect.new()
	blocker.size = Vector2(1180.0, 660.0)
	blocker.color = Color(0.01, 0.03, 0.07, 0.84)
	_modifier_overlay.add_child(blocker)

	var panel := Panel.new()
	panel.position = Vector2(270.0, 72.0)
	panel.size = Vector2(650.0, 514.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0a2038"), Color("#86e9ff")))
	_modifier_overlay.add_child(panel)

	_modifier_title = _make_label(panel, "笨蛋灵感", Vector2(28.0, 18.0), Vector2(594.0, 38.0), 28, Color("#edfdff"))
	_modifier_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modifier_subtitle = _make_label(panel, "选择一项强化，然后继续。", Vector2(34.0, 60.0), Vector2(582.0, 30.0), 14, Color("#9ac4d7"))
	_modifier_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for index in range(3):
		var button := Button.new()
		button.position = Vector2(30.0 + index * 198.0, 112.0)
		button.size = Vector2(184.0, 304.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_stylebox_override("normal", _button_style(Color("#102f4c"), Color("#2e7292"), 2))
		button.add_theme_stylebox_override("hover", _button_style(Color("#174d67"), Color("#c7f8ff"), 3))
		button.pressed.connect(_on_modifier_card_pressed.bind(index))
		panel.add_child(button)
		_modifier_buttons.append(button)


func _build_result_overlay() -> void:
	_result_overlay = Control.new()
	_result_overlay.size = Vector2(1180.0, 660.0)
	_result_overlay.visible = false
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result_overlay)

	var blocker := ColorRect.new()
	blocker.size = Vector2(1180.0, 660.0)
	blocker.color = Color(0.01, 0.03, 0.07, 0.90)
	_result_overlay.add_child(blocker)

	var panel := Panel.new()
	panel.position = Vector2(350.0, 158.0)
	panel.size = Vector2(480.0, 334.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0b223b"), Color("#8cecff")))
	_result_overlay.add_child(panel)

	_result_title = _make_label(panel, "IQ 保卫成功！", Vector2(30.0, 34.0), Vector2(420.0, 48.0), 32, Color("#c9fff0"))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_description = _make_label(panel, "你守住了琪露诺的 IQ。", Vector2(45.0, 104.0), Vector2(390.0, 100.0), 17, Color("#b6d9e8"))
	_result_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var restart := _make_action_button("再守一次", Color("#2f8b70"))
	restart.position = Vector2(100.0, 235.0)
	restart.size = Vector2(280.0, 54.0)
	restart.add_theme_font_size_override("font_size", 18)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(restart)


func update_resources(iq: int, max_iq: int, frost: int, ice_crystals: int, wave_text: String, status_text: String) -> void:
	_frost = frost
	_iq_label.text = "IQ  %d / %d" % [iq, max_iq]
	_resource_label.text = "冻气  %d   冰晶  %d" % [frost, ice_crystals]
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
	_update_upgrade_button()


func refresh_structure_detail(structure: DefenseStructure, frost: int) -> void:
	if structure == null or not is_instance_valid(structure):
		clear_structure_detail()
		return
	_selected_structure = structure
	_frost = frost
	_structure_detail_label.text = structure.get_detail_text()
	_upgrade_button.visible = true
	_update_upgrade_button()


func clear_structure_detail() -> void:
	_selected_structure = null
	_structure_detail_label.text = "点击已有建筑可查看状态并升级。\n右键建筑后点击妖精可指定优先目标。"
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
	button.add_theme_stylebox_override("normal", _button_style(color.darkened(0.38), color.lightened(0.08), 2))
	button.add_theme_stylebox_override("hover", _button_style(color.darkened(0.16), Color("#d8fbff"), 2))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.04), Color.WHITE, 2))
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
