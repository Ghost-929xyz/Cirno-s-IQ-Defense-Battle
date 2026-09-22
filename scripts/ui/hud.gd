class_name BattleHUD
extends CanvasLayer

signal build_tower_selected(tower_id: String)
signal start_wave_requested
signal upgrade_tower_requested
signal upgrade_card_selected(upgrade_id: String)
signal restart_requested

var _iq_label: Label
var _resource_label: Label
var _wave_label: Label
var _status_label: Label
var _tower_detail_label: Label
var _start_button: Button
var _upgrade_button: Button
var _tower_buttons: Dictionary = {}
var _upgrade_overlay: Control
var _upgrade_buttons: Array[Button] = []
var _upgrade_choices: Array[Dictionary] = []
var _result_overlay: Control
var _result_title: Label
var _result_description: Label

var _selected_tower_id := "icicle"
var _selected_tower: CirnoTower
var _frost := 0
var _iq := 20
var _max_iq := 20


func _ready() -> void:
	_build_side_panel()
	_build_upgrade_overlay()
	_build_result_overlay()
	select_build_tower("icicle")


func _build_side_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(780.0, 18.0)
	panel.size = Vector2(380.0, 624.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0b1d33"), Color("#4187a8")))
	add_child(panel)

	var title := _make_label(panel, "琪露诺的智商保卫战", Vector2(18.0, 14.0), Vector2(344.0, 34.0), 22, Color("#e7fbff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_iq_label = _make_label(panel, "IQ 20 / 20", Vector2(18.0, 54.0), Vector2(344.0, 28.0), 19, Color("#9ff4ff"))
	_resource_label = _make_label(panel, "冻气 140", Vector2(18.0, 82.0), Vector2(344.0, 28.0), 19, Color("#dff8ff"))
	_wave_label = _make_label(panel, "准备阶段 · 共 6 波", Vector2(18.0, 114.0), Vector2(344.0, 28.0), 16, Color("#b7d7e5"))
	_status_label = _make_label(panel, "选择一种琪露诺，然后点击草地格。", Vector2(18.0, 145.0), Vector2(344.0, 45.0), 14, Color("#8fb4c8"))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var section := _make_label(panel, "琪露诺部署", Vector2(18.0, 192.0), Vector2(344.0, 25.0), 17, Color("#e7fbff"))
	section.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	section.add_theme_constant_override("shadow_offset_x", 1)
	section.add_theme_constant_override("shadow_offset_y", 2)

	var button_y := 222.0
	for tower_id in TowerCatalog.ORDER:
		var definition := TowerCatalog.get_definition(tower_id)
		var button := Button.new()
		button.position = Vector2(18.0, button_y)
		button.size = Vector2(344.0, 58.0)
		button.toggle_mode = true
		button.text = "%s  [%d 冻气]\n%s · %s" % [
			str(definition.get("name", tower_id)),
			int(definition.get("cost", 0)),
			str(definition.get("role", "")),
			str(definition.get("description", "")),
		]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_tower_button_pressed.bind(tower_id))
		panel.add_child(button)
		_tower_buttons[tower_id] = button
		button_y += 66.0

	var hint := _make_label(panel, "左键建造 / 选中塔；右键或 Esc 取消。", Vector2(18.0, 423.0), Vector2(344.0, 24.0), 13, Color("#7fa5b9"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_start_button = Button.new()
	_start_button.position = Vector2(18.0, 456.0)
	_start_button.size = Vector2(344.0, 48.0)
	_start_button.text = "开始第 1 波"
	_start_button.add_theme_font_size_override("font_size", 17)
	_start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	panel.add_child(_start_button)

	_tower_detail_label = _make_label(panel, "点击已建造的塔可升级。", Vector2(18.0, 515.0), Vector2(344.0, 50.0), 14, Color("#d7edf5"))
	_tower_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_upgrade_button = Button.new()
	_upgrade_button.position = Vector2(18.0, 572.0)
	_upgrade_button.size = Vector2(344.0, 38.0)
	_upgrade_button.text = "升级选中塔"
	_upgrade_button.visible = false
	_upgrade_button.pressed.connect(func() -> void: upgrade_tower_requested.emit())
	panel.add_child(_upgrade_button)


func _build_upgrade_overlay() -> void:
	_upgrade_overlay = Control.new()
	_upgrade_overlay.size = Vector2(1180.0, 660.0)
	_upgrade_overlay.visible = false
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_upgrade_overlay)

	var blocker := ColorRect.new()
	blocker.size = Vector2(1180.0, 660.0)
	blocker.color = Color(0.01, 0.03, 0.07, 0.82)
	_upgrade_overlay.add_child(blocker)

	var panel := Panel.new()
	panel.position = Vector2(300.0, 92.0)
	panel.size = Vector2(580.0, 476.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0c223b"), Color("#8cecff")))
	_upgrade_overlay.add_child(panel)

	var title := _make_label(panel, "笨蛋灵感", Vector2(30.0, 22.0), Vector2(520.0, 38.0), 28, Color("#e9fcff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _make_label(panel, "选择一项强化，然后继续爬塔。", Vector2(30.0, 63.0), Vector2(520.0, 28.0), 15, Color("#8fb8ca"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for index in range(3):
		var button := Button.new()
		button.position = Vector2(38.0, 108.0 + index * 108.0)
		button.size = Vector2(504.0, 92.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_upgrade_card_pressed.bind(index))
		panel.add_child(button)
		_upgrade_buttons.append(button)


func _build_result_overlay() -> void:
	_result_overlay = Control.new()
	_result_overlay.size = Vector2(1180.0, 660.0)
	_result_overlay.visible = false
	_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_result_overlay)

	var blocker := ColorRect.new()
	blocker.size = Vector2(1180.0, 660.0)
	blocker.color = Color(0.01, 0.03, 0.07, 0.88)
	_result_overlay.add_child(blocker)

	var panel := Panel.new()
	panel.position = Vector2(355.0, 170.0)
	panel.size = Vector2(470.0, 310.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0c223b"), Color("#8cecff")))
	_result_overlay.add_child(panel)

	_result_title = _make_label(panel, "通关", Vector2(30.0, 40.0), Vector2(410.0, 50.0), 34, Color("#e9fcff"))
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_description = _make_label(panel, "IQ 保住了。", Vector2(45.0, 105.0), Vector2(380.0, 70.0), 17, Color("#aacbda"))
	_result_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var restart := Button.new()
	restart.position = Vector2(95.0, 210.0)
	restart.size = Vector2(280.0, 54.0)
	restart.text = "再守一次"
	restart.add_theme_font_size_override("font_size", 18)
	restart.pressed.connect(func() -> void: restart_requested.emit())
	panel.add_child(restart)


func update_resources(iq: int, max_iq: int, frost: int, wave_text: String, status_text: String) -> void:
	_iq = iq
	_max_iq = max_iq
	_frost = frost
	_iq_label.text = "IQ  %d / %d" % [iq, max_iq]
	_resource_label.text = "冻气  %d" % frost
	_wave_label.text = wave_text
	_status_label.text = status_text
	_update_upgrade_button()


func select_build_tower(tower_id: String) -> void:
	_selected_tower_id = tower_id
	for key in _tower_buttons:
		var button: Button = _tower_buttons[key]
		button.button_pressed = key == tower_id
	build_tower_selected.emit(tower_id)


func set_start_button(enabled: bool, text: String) -> void:
	_start_button.disabled = not enabled
	_start_button.text = text


func show_tower_detail(tower: CirnoTower) -> void:
	_selected_tower = tower
	_tower_detail_label.text = "%s · Lv.%d\n点击升级按钮提高伤害、射程与攻速。" % [tower.get_display_name(), tower.level]
	_upgrade_button.visible = true
	_update_upgrade_button()


func clear_tower_detail() -> void:
	_selected_tower = null
	_tower_detail_label.text = "点击已建造的塔可升级。"
	_upgrade_button.visible = false


func show_upgrade_choices(choices: Array[Dictionary]) -> void:
	_upgrade_choices = choices
	for index in range(_upgrade_buttons.size()):
		var button := _upgrade_buttons[index]
		if index >= choices.size():
			button.visible = false
			continue
		var definition := choices[index]
		button.visible = true
		button.text = "%s · %s\n%s" % [
			str(definition.get("rarity", "普通")),
			str(definition.get("name", "强化")),
			str(definition.get("description", "")),
		]
	_upgrade_overlay.visible = true


func hide_upgrade_choices() -> void:
	_upgrade_overlay.visible = false
	_upgrade_choices.clear()


func show_result(victory: bool, description: String) -> void:
	_result_title.text = "IQ 保卫成功！" if victory else "IQ 归零……"
	_result_title.add_theme_color_override("font_color", Color("#c9fff0") if victory else Color("#ff9bad"))
	_result_description.text = description
	_result_overlay.visible = true


func _on_tower_button_pressed(tower_id: String) -> void:
	clear_tower_detail()
	select_build_tower(tower_id)


func _on_upgrade_card_pressed(index: int) -> void:
	if index < 0 or index >= _upgrade_choices.size():
		return
	var upgrade_id := str(_upgrade_choices[index].get("id", ""))
	if not upgrade_id.is_empty():
		upgrade_card_selected.emit(upgrade_id)


func _update_upgrade_button() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		_upgrade_button.visible = false
		return
	_upgrade_button.visible = true
	if _selected_tower.level >= 3:
		_upgrade_button.text = "已满级"
		_upgrade_button.disabled = true
		return
	var cost := _selected_tower.get_upgrade_cost()
	_upgrade_button.text = "升级至 Lv.%d  [%d 冻气]" % [_selected_tower.level + 1, cost]
	_upgrade_button.disabled = _frost < cost


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
