extends CanvasLayer

## 新手引导：欢迎弹窗 + 分步引导横幅 + 开波后战斗提示。
## 通过 notify(event_id) 接收游戏事件并推进步骤，乱序完成也可继续。

signal finished
signal skipped

const STEP_MOVE := "move"
const STEP_TOWER := "tower"
const STEP_BARRACKS := "barracks"
const STEP_WAVE := "wave"

const STEPS: Array[Dictionary] = [
	{"id": STEP_MOVE, "title": "移动英雄", "text": "右键点击草地，移动琪露诺（自动攻击附近妖精）。"},
	{"id": STEP_TOWER, "title": "建造防御塔", "text": "选中「冰锥琪露诺」（数字键 1），左键点草地建造防御塔。"},
	{"id": STEP_BARRACKS, "title": "建造兵营", "text": "选中「冰晶兵营」（数字键 4），左键点草地建造兵营。"},
	{"id": STEP_WAVE, "title": "开始战斗", "text": "按空格或点击右下角按钮开始第 1 波，保护琪露诺！"},
]
const COMBAT_TIP := "Q 冰霜新星 · R 完美冻结 · 每 8 杀触发笨蛋寒气。"
const COMBAT_TIP_DURATION := 10.0

var _active := false
var _step_index := 0
var _completed := {}
var _tip_remaining := 0.0

var _welcome: Control
var _banner: Control
var _banner_title_label: Label
var _banner_text_label: Label


func _ready() -> void:
	layer = 2
	_build_welcome()
	_build_banner()


func _process(delta: float) -> void:
	if _tip_remaining <= 0.0:
		return
	_tip_remaining = maxf(0.0, _tip_remaining - delta)
	if _tip_remaining <= 0.0:
		_banner.visible = false


func is_blocking() -> bool:
	return _welcome != null and _welcome.visible


func notify(event_id: String) -> void:
	if not _active:
		return
	if event_id == STEP_WAVE:
		_show_combat_tip()
		return
	_completed[event_id] = true
	while _step_index < STEPS.size() and _completed.has(str(STEPS[_step_index].get("id"))):
		_step_index += 1
	if _step_index >= STEPS.size():
		_show_combat_tip()
	else:
		_refresh_banner()


func _build_welcome() -> void:
	_welcome = Control.new()
	_welcome.size = Vector2(1180.0, 660.0)
	_welcome.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_welcome)

	var blocker := ColorRect.new()
	blocker.size = Vector2(1180.0, 660.0)
	blocker.color = Color(0.01, 0.03, 0.07, 0.86)
	_welcome.add_child(blocker)

	var panel := Panel.new()
	panel.position = Vector2(310.0, 120.0)
	panel.size = Vector2(560.0, 420.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0a2038"), Color("#86e9ff")))
	_welcome.add_child(panel)

	var title := _make_label(panel, "欢迎来到雾之湖", Vector2(20.0, 20.0), Vector2(520.0, 40.0), 30, Color("#edfdff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var body := _make_label(
		panel,
		"妖精们盯上了琪露诺的 IQ！\n\n"
		+ "· 别让妖精打倒琪露诺，她生命归零就失败\n"
		+ "· 妖精会从 西 / 北 / 南 / 东 四个裂隙进攻\n"
		+ "· 妖精攻击琪露诺、或偷走 IQ 结晶都会扣她生命\n"
		+ "· 左键建造、右键移动琪露诺，Q / R 释放技能\n"
		+ "· 击杀妖精获得冻气，波间三选一强化防线\n\n"
		+ "先跟着引导熟悉基本操作吧。",
		Vector2(46.0, 68.0),
		Vector2(468.0, 200.0),
		15,
		Color("#c7e4f0")
	)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var begin_button := _make_button("开始新手引导", Color("#2f8b70"), 16)
	begin_button.position = Vector2(80.0, 296.0)
	begin_button.size = Vector2(400.0, 50.0)
	begin_button.pressed.connect(_on_begin_pressed)
	panel.add_child(begin_button)

	var skip_button := _make_button("直接开战（跳过引导）", Color("#246f99"), 13)
	skip_button.position = Vector2(80.0, 356.0)
	skip_button.size = Vector2(400.0, 40.0)
	skip_button.pressed.connect(_on_skip_pressed)
	panel.add_child(skip_button)


func _build_banner() -> void:
	_banner = Panel.new()
	_banner.position = Vector2(32.0, 6.0)
	_banner.size = Vector2(720.0, 46.0)
	_banner.visible = false
	_banner.add_theme_stylebox_override("panel", _panel_style(Color("#0d2a40"), Color("#8fe8ff")))
	add_child(_banner)

	_banner_title_label = _make_label(_banner, "新手引导 1/4", Vector2(12.0, 13.0), Vector2(110.0, 22.0), 13, Color("#ffe9a0"))
	_banner_text_label = _make_label(_banner, "", Vector2(126.0, 13.0), Vector2(474.0, 22.0), 13, Color("#dcf8ff"))
	_banner_text_label.clip_text = true

	var skip_button := _make_button("跳过引导", Color("#6b4a4a"), 12)
	skip_button.position = Vector2(612.0, 8.0)
	skip_button.size = Vector2(96.0, 30.0)
	skip_button.pressed.connect(_on_skip_pressed)
	_banner.add_child(skip_button)


func _on_begin_pressed() -> void:
	_welcome.visible = false
	_active = true
	_step_index = 0
	_refresh_banner()


func _on_skip_pressed() -> void:
	_active = false
	_tip_remaining = 0.0
	if _welcome != null:
		_welcome.visible = false
	_banner.visible = false
	skipped.emit()


func _refresh_banner() -> void:
	if _step_index >= STEPS.size():
		return
	var step: Dictionary = STEPS[_step_index]
	_banner_title_label.text = "新手引导 %d/%d" % [_step_index + 1, STEPS.size()]
	_banner_text_label.text = "%s — %s" % [str(step.get("title", "")), str(step.get("text", ""))]
	_banner.visible = true


func _show_combat_tip() -> void:
	_active = false
	_banner_title_label.text = "战斗开始"
	_banner_text_label.text = COMBAT_TIP
	_banner.visible = true
	_tip_remaining = COMBAT_TIP_DURATION
	finished.emit()


func _make_button(text: String, color: Color, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
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
