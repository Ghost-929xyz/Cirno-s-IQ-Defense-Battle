extends Node2D

const Simulation = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
const Session = preload("res://scripts/autoload/session.gd")
const Saves = preload("res://scripts/autoload/save_manager.gd")
const FONT = preload("res://assets/fonts/unifont.otf")
const Art = preload("res://scripts/data/tiny_swords_art.gd")
const CELL := 21.0
const ORIGIN := Vector2.ZERO
const MAP_RECT := Rect2(0, 0, 1180, 660)
var zoom := 21.0
var camera_center := Vector2(20, 25)
var panning := false
var world_overlay: Node2D
var minimap: Control
var drawers: Dictionary = {}
var tab_buttons: Dictionary = {}
var spell_buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var roster_category := "步战"
var open_drawer := ""
const FAMILIES := {
	"步战": ["swordsman", "guard", "paladin", "heavy_infantry"],
	"远程": ["archer", "sniper", "ice_archer", "sniper_plus", "ice_archer_plus"],
	"骑乘": ["cavalry", "ranger", "lancer", "scout", "cataphract"],
	"特战": ["assassin", "hermit", "berserker", "hermit_dodge", "hermit_blink", "berserker_plus"],
}
const BLUE := Color("82e0ee")
const GOLD := Color("f0c777")
const RED := Color("f18c83")
var sim := Simulation.new()
var selected: Array = []
var selected_building := -1
var mode := "select"
var paused := false
var accumulator := 0.0
var hud_clock := 0.0
var autosave_clock := 0.0
var last_phase := ""
var drag_start := Vector2.ZERO
var dragging := false
var hover := Vector2.ZERO
var layer: CanvasLayer
var resource_labels: Dictionary = {}
var dock: Panel
var tactical_overlay: Control
var tactical_map: Control
var wave_intro: Control
var last_wave_seen := 0
var wave_campaign := 1
var objective: Label
var status: Label
var details: Label
var roster: GridContainer
var overlay: Panel
var pause_button: Button
var train_buttons: Dictionary = {}
var tech_button: Button
var tier_button: Button
var wave_button: Button
@onready var tile_map: Node2D = $Battlefield/FogLakeTileMap

func _ready() -> void:
	sim.configure_terrain(tile_map.terrain_water_cells())
	world_overlay = Node2D.new()
	world_overlay.set_script(preload("res://scripts/ui/rts_world_overlay.gd"))
	world_overlay.game = self
	world_overlay.position = -ORIGIN
	world_overlay.z_index = 10
	$Battlefield.add_child(world_overlay)
	build_ui()
	if Session.pending_load_slot >= 0:
		var slot: int = Session.pending_load_slot
		Session.pending_load_slot = -1
		if not sim.restore(Saves.read_slot(slot)):
			sim.message = "存档不属于新版远征，未覆盖原文件。请返回菜单选择新的游戏。"
	if sim.phase in ["cards", "base"]:
		zoom = 12.8
		camera_center = Vector2(40, 25)
	else: focus_home()
	update_camera()
	last_wave_seen = sim.wave
	wave_campaign = sim.campaign
	last_phase = sim.phase
	show_phase_overlay()
	refresh_ui()
	tile_map.sync(sim, 0.0, paused)

func _process(delta: float) -> void:
	if panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE): panning = false
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging = false
	var pan := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if pan != Vector2.ZERO and open_drawer.is_empty() and not tactical_overlay.visible and not wave_intro.active: center_camera(camera_center + pan.normalized() * delta * 450.0 / zoom)
	observe_waves()
	if not simulation_blocked():
		accumulator += minf(delta, 0.2)
		while accumulator >= 0.05:
			sim.step(0.05)
			accumulator -= 0.05
			observe_waves()
			if wave_intro.active:
				accumulator = 0
				break
	if sim.phase != last_phase:
		if last_phase in ["cards", "base"] and sim.active():
			zoom = CELL
			focus_home()
		last_phase = sim.phase
		show_phase_overlay()
		if sim.phase in ["prep", "victory", "defeat"]: save_progress(false)
	selected = selected.filter(func(id): return not sim.entity(int(id)).is_empty() and sim.entity(int(id)).hp > 0)
	hud_clock += delta
	autosave_clock += delta
	if hud_clock >= 0.15:
		hud_clock = 0
		refresh_ui()
	if autosave_clock >= 20 and sim.active():
		autosave_clock = 0
		save_progress(false)
	tile_map.sync(sim, delta, simulation_blocked() or not sim.active())
	world_overlay.queue_redraw()
	minimap.queue_redraw()
	queue_redraw()

func world_to_screen(pos: Vector2) -> Vector2:
	return MAP_RECT.get_center() + (pos + Vector2(0.5, 0.5) - camera_center) * zoom

func screen_point(entity: Dictionary) -> Vector2:
	return world_to_screen(sim.point(entity))

func map_point(pos: Vector2) -> Vector2:
	return ((pos - MAP_RECT.get_center()) / zoom + camera_center - Vector2(0.5, 0.5)).clamp(Vector2.ZERO, Vector2(Simulation.WIDTH - 1, Simulation.HEIGHT - 1))

func visible_world_rect() -> Rect2:
	return Rect2(camera_center - MAP_RECT.size / zoom * 0.5, MAP_RECT.size / zoom)

func center_camera(pos: Vector2) -> void:
	camera_center = pos
	update_camera()

func update_camera() -> void:
	var half := MAP_RECT.size / zoom * 0.5
	var extent := Vector2(Simulation.WIDTH, Simulation.HEIGHT)
	for axis in 2:
		camera_center[axis] = clampf(camera_center[axis], minf(half[axis], extent[axis] * 0.5), maxf(extent[axis] - half[axis], extent[axis] * 0.5))
	tile_map.scale = Vector2.ONE * zoom / 64.0
	tile_map.position = MAP_RECT.size * 0.5 - camera_center * zoom

func zoom_at(pos: Vector2, factor: float) -> void:
	var before := (pos - MAP_RECT.get_center()) / zoom + camera_center
	zoom = clampf(zoom * factor, 8.6, 32.0)
	camera_center = before - (pos - MAP_RECT.get_center()) / zoom
	update_camera()

func focus_home() -> void:
	for b in sim.buildings:
		if b.team == 0 and b.kind == "base":
			center_camera(sim.point(b) + Vector2(8, 0))
			return
	center_camera(Vector2(20, 25))

func label_at(parent: Node, text: String, pos: Vector2, size: Vector2, font_size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("daecf0"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.05, 0.08, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func button_at(parent: Node, text: String, pos: Vector2, size: Vector2, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = size
	b.size = size
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 15)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("20333c") if state == "normal" else (Color("304c54") if state == "hover" else Color("14262e"))
		style.border_color = Color("77c4ca") if state in ["hover", "pressed", "focus"] else Color("344a53")
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(8)
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", Color("dce7e5"))
	b.add_theme_color_override("font_disabled_color", Color("697e84"))
	b.add_theme_color_override("font_hover_color", Color("ffffff"))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func panel_at(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101f29")
	style.border_color = Color("32464f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", style)
	layer.add_child(p)
	return p

func build_ui() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	# Soft edge shading keeps floating text readable without panels or borders.
	var edge_shade := ColorRect.new()
	edge_shade.size = Vector2(1180, 660)
	edge_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float top=(1.0-smoothstep(0.0,0.19,UV.y))*0.68; float bottom=smoothstep(0.78,1.0,UV.y)*0.28; COLOR=vec4(0.02,0.05,0.08,max(top,bottom)); }"
	var material_shade := ShaderMaterial.new()
	material_shade.shader = shader
	edge_shade.material = material_shade
	layer.add_child(edge_shade)
	label_at(layer, "冰华战线 / 雾之湖", Vector2(22, 7), Vector2(270, 30), 19)
	var font_bold := FontVariation.new()
	font_bold.base_font = FONT
	font_bold.variation_embolden = 0.8
	var keys := ["gold", "baka", "capacity", "tech", "tier"]
	var names := ["金币", "BAKA", "容量", "科技", "层级"]
	var offsets := [326, 470, 620, 802, 922]
	for i in keys.size():
		var title := label_at(layer, names[i], Vector2(offsets[i], 10), Vector2(42, 25), 13)
		title.add_theme_color_override("font_color", Color("b8cccf"))
		var number := label_at(layer, "", Vector2(offsets[i] + 46, 3), Vector2(100, 34), 25)
		number.add_theme_font_override("font", font_bold)
		number.add_theme_color_override("font_color", GOLD if keys[i] == "gold" else (BLUE if keys[i] == "baka" else Color("f4f8f6")))
		resource_labels[keys[i]] = number
	pause_button = icon_button_at(layer, "pause", Vector2(1068, 2), toggle_pause, "暂停 / 继续  P")
	icon_button_at(layer, "menu", Vector2(1122, 2), return_menu, "返回菜单")
	objective = label_at(layer, "", Vector2(23, 39), Vector2(730, 25), 13)
	minimap = Control.new()
	minimap.set_script(preload("res://scripts/ui/rts_minimap.gd"))
	minimap.game = self
	minimap.position = Vector2(970, 440)
	minimap.size = Vector2(192, 192)
	minimap.wet_cells = tile_map.terrain_water_cells()
	layer.add_child(minimap)
	label_at(layer, "Tab  俯瞰地图", Vector2(1002, 633), Vector2(160, 22), 13)
	dock = panel_at(Vector2(273, 562), Vector2(634, 86))
	var dock_style := StyleBoxFlat.new()
	dock_style.bg_color = Color(0.035, 0.08, 0.11, 0.88)
	dock_style.set_corner_radius_all(17)
	dock.add_theme_stylebox_override("panel", dock_style)
	details = label_at(layer, "", Vector2(291, 508), Vector2(598, 49), 13)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.85))
	details.add_theme_constant_override("outline_size", 3)
	for i in 3:
		var key: String = ["recruit", "build", "research"][i]
		tab_buttons[key] = compact_button_at(dock, ["招募军团", "建造设施", "科技研究"][i], Vector2(12 + i * 99, 9), Vector2(91, 30), toggle_drawer.bind(key))
	compact_button_at(dock, "全选 A", Vector2(314, 9), Vector2(62, 30), select_all)
	compact_button_at(dock, "撤出", Vector2(382, 9), Vector2(62, 30), evacuate_selected)
	compact_button_at(dock, "基地 H", Vector2(450, 9), Vector2(74, 30), focus_home)
	compact_button_at(dock, "存档 F5", Vector2(530, 9), Vector2(92, 30), save_progress.bind(true))
	for i in 3:
		var key: String = ["freeze", "wall", "bridge"][i]
		spell_buttons[key] = compact_button_at(dock, ["Q 冰冻 20", "W 冰墙 25", "E 冰桥 20"][i], Vector2(12 + i * 120, 47), Vector2(112, 30), set_mode.bind(key))
	wave_button = compact_button_at(dock, "迎敌  Space", Vector2(382, 47), Vector2(240, 30), advance_wave)
	status = label_at(layer, "", Vector2(22, 594), Vector2(230, 48), 12)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for key in ["recruit", "build", "research"]:
		var p := panel_at(Vector2(230, 220), Vector2(720, 258))
		p.visible = false
		drawers[key] = p
		button_at(p, "收起 ×", Vector2(616, 12), Vector2(88, 30), toggle_drawer.bind(key))
	var recruit: Panel = drawers.recruit
	label_at(recruit, "军团招募", Vector2(20, 10), Vector2(420, 30), 22)
	var index := 0
	for name_text in FAMILIES:
		category_buttons[name_text] = button_at(recruit, name_text, Vector2(20 + index * 172, 52), Vector2(160, 30), filter_roster.bind(name_text))
		index += 1
	roster = GridContainer.new()
	roster.columns = 3
	roster.position = Vector2(20, 94)
	roster.add_theme_constant_override("h_separation", 10)
	roster.add_theme_constant_override("v_separation", 10)
	recruit.add_child(roster)
	for kind in sim.catalog:
		var d: Dictionary = sim.catalog[kind]
		var b := button_at(roster, "%s\n%d 金 · %d 容量" % [d.name, d.cost, d.capacity], Vector2.ZERO, Vector2(220, 66), train.bind(kind))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = Art.portrait(kind)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 36)
		b.tooltip_text = "%s\n生命 %d | 攻击 %d | 射程 %s\n攻速 %s 次/秒 | 移速 %.1f 格/秒\n需要科技 %d / 层级 %d\n%s" % [d.name, d.hp, d.attack, str(d.range), str(d.attack_speed), d.move_speed, d.tech, d.tier, d.skill]
		train_buttons[kind] = b
	filter_roster(roster_category)
	var build: Panel = drawers.build
	label_at(build, "营地建设", Vector2(20, 10), Vector2(420, 30), 22)
	label_at(build, "选择部队，再选择设施并点击陆地。", Vector2(20, 53), Vector2(650, 28), 15)
	for i in 3:
		button_at(build, ["兵营 · 160 金\n训练援军 / 扩充容量", "魔力井 · 200 金\n持续回复 BAKA", "房屋 · 120 金\n驻军防守 / 恢复生命"][i], Vector2(20 + i * 232, 104), Vector2(216, 112), set_mode.bind(["barracks", "well", "house"][i]))
	compact_button_at(build, "驻军 G", Vector2(20, 224), Vector2(110, 26), set_mode.bind("garrison"))
	compact_button_at(build, "修复 R", Vector2(142, 224), Vector2(110, 26), set_mode.bind("repair"))
	label_at(build, "受损建筑也可直接驻军", Vector2(280, 226), Vector2(390, 24), 13)
	var research: Panel = drawers.research
	label_at(research, "战地研究", Vector2(20, 10), Vector2(420, 30), 22)
	label_at(research, "科技与层级共同决定可招募的兵种。", Vector2(20, 53), Vector2(650, 28), 15)
	tech_button = button_at(research, "科技 II · 240 金\n解锁进阶科技", Vector2(20, 104), Vector2(332, 112), func():
		if not simulation_blocked(): sim.research("tech"))
	tier_button = button_at(research, "提升层级 · 180 金\n解锁高阶兵种", Vector2(366, 104), Vector2(332, 112), func():
		if not simulation_blocked(): sim.research("tier"))

	build_tactical_overlay()
	var intro_layer := CanvasLayer.new()
	intro_layer.layer = 50
	add_child(intro_layer)
	wave_intro = Control.new()
	wave_intro.set_script(preload("res://scripts/ui/rts_wave_intro.gd"))
	intro_layer.add_child(wave_intro)

func icon_button_at(parent: Node, kind: String, pos: Vector2, action: Callable, hint: String) -> Button:
	var button := Button.new()
	button.set_script(preload("res://scripts/ui/rts_icon_button.gd"))
	button.icon_name = kind
	button.position = pos
	button.size = Vector2(40, 36)
	button.tooltip_text = hint
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func compact_button_at(parent: Node, text: String, pos: Vector2, extent: Vector2, action: Callable) -> Button:
	var button := button_at(parent, text, pos, extent, action)
	button.add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.28, 0.32, 0.65) if state == "hover" else Color(0.1, 0.2, 0.24, 0.25)
		style.set_corner_radius_all(7)
		style.set_content_margin_all(4)
		button.add_theme_stylebox_override(state, style)
	return button

func build_tactical_overlay() -> void:
	tactical_overlay = Control.new()
	tactical_overlay.size = Vector2(1180, 660)
	tactical_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(tactical_overlay)
	var shade := ColorRect.new()
	shade.size = tactical_overlay.size
	shade.color = Color(0.015, 0.035, 0.055, 0.95)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tactical_overlay.add_child(shade)
	label_at(tactical_overlay, "雾之湖  /  战术俯瞰", Vector2(190, 38), Vector2(720, 40), 25)
	icon_button_at(tactical_overlay, "close", Vector2(950, 40), toggle_overview, "收起  Tab / Esc")
	tactical_map = Control.new()
	tactical_map.set_script(preload("res://scripts/ui/rts_minimap.gd"))
	tactical_map.game = self
	tactical_map.circular = false
	tactical_map.position = Vector2(190, 90)
	tactical_map.size = Vector2(800, 500)
	tactical_map.wet_cells = tile_map.terrain_water_cells()
	tactical_overlay.add_child(tactical_map)
	label_at(tactical_overlay, "◆ 敌营   × 打野点   ● 奖励   蓝 / 红 军团    |    点击定位 · Tab 收起", Vector2(204, 607), Vector2(780, 28), 15)
	tactical_overlay.visible = false

func toggle_overview() -> void:
	if wave_intro.active: return
	if not open_drawer.is_empty(): toggle_drawer(open_drawer)
	dragging = false
	panning = false
	mode = "select"
	tactical_overlay.visible = not tactical_overlay.visible

func simulation_blocked() -> bool:
	return paused or tactical_overlay.visible or wave_intro.active

func advance_wave() -> void:
	if simulation_blocked(): return
	sim.start_wave()
	observe_waves()

func observe_waves() -> void:
	if sim.campaign != wave_campaign:
		wave_campaign = sim.campaign
		last_wave_seen = 0
	if sim.wave < last_wave_seen: last_wave_seen = sim.wave
	if sim.wave <= last_wave_seen: return
	if tactical_overlay.visible: tactical_overlay.visible = false
	if not open_drawer.is_empty(): toggle_drawer(open_drawer)
	dragging = false
	panning = false
	for wave in range(last_wave_seen + 1, sim.wave + 1): wave_intro.queue_wave(wave)
	last_wave_seen = sim.wave
	accumulator = 0.0


func toggle_drawer(key: String) -> void:
	open_drawer = "" if open_drawer == key else key
	dragging = false
	for name_text in drawers: drawers[name_text].visible = name_text == open_drawer
	for name_text in tab_buttons: tab_buttons[name_text].modulate = GOLD if name_text == open_drawer else Color.WHITE

func filter_roster(category: String) -> void:
	roster_category = category
	for kind in train_buttons: train_buttons[kind].visible = kind in FAMILIES[category]
	for key in category_buttons: category_buttons[key].modulate = BLUE if key == category else Color.WHITE

func refresh_ui() -> void:
	resource_labels.gold.text = "%d" % sim.gold
	resource_labels.baka.text = "%d" % sim.baka
	resource_labels.capacity.text = "%d/%d" % [sim.used_capacity(), sim.capacity()]
	resource_labels.tech.text = str(sim.tech)
	resource_labels.tier.text = str(sim.tier)
	var phase_names := {"cards": "开局选牌", "base": "选择基地", "prep": "部署探索", "defense": "抵御进攻", "cleanup": "清剿敌军", "victory": "远征胜利", "defeat": "远征失败"}
	objective.text = "远征 %02d   /   %s   /   波次 %d/%d   /   %.0f 秒" % [sim.campaign, phase_names[sim.phase], sim.wave, Rules.WAVE_COUNT, maxf(0, sim.timer)]
	if sim.phase == "cleanup": objective.text = "清剿据点   /   敌军 %d   /   敌方建筑 %d   /   野怪为可选探索" % [sim.living(1).size(), sim.buildings.filter(func(b): return b.team == 1 and b.hp > 0).size()]
	status.text = ("已暂停  |  " if paused else "") + sim.message
	pause_button.icon_name = "play" if paused else "pause"
	tech_button.disabled = simulation_blocked() or not sim.active() or sim.tech >= 2 or sim.gold < Rules.TECH_COST
	tier_button.disabled = simulation_blocked() or not sim.active() or sim.tier >= 3 or sim.gold < Rules.TIER_COST
	wave_button.disabled = simulation_blocked() or not sim.active() or sim.wave >= Rules.WAVE_COUNT
	for kind in train_buttons:
		var d: Dictionary = sim.catalog[kind]
		train_buttons[kind].disabled = simulation_blocked() or not sim.active() or sim.gold < d.cost or sim.tech < d.tech or sim.tier < d.tier or sim.used_capacity() + d.capacity > sim.capacity()
	for key in spell_buttons:
		spell_buttons[key].modulate = BLUE if mode == key else Color.WHITE
		spell_buttons[key].disabled = simulation_blocked() or not sim.active() or sim.baka < (Rules.WALL_COST if key == "wall" else Rules.FREEZE_COST)
	details.text = "军团待命 · %s\n左键选择 / 框选  ·  右键下令  ·  G 驻军 / R 修复" % sim.card_names()
	if sim.phase == "base": details.text = "开局效果 · %s\n北岸 / 湖西 / 南岸 · 点击地图光环" % sim.card_names()
	var b: Dictionary = sim.entity(selected_building)
	if not b.is_empty() and b.has("complete"):
		details.text = "%s · %.0f/%.0f HP · 驻军 %d/%d · %s\n训练队列 %d · 选部队后 G 驻军 / R 修复" % [Rules.BUILDINGS[b.kind].name, b.hp, b.max_hp, sim.occupants(selected_building).size(), Rules.BUILDINGS[b.kind].beds, "完工" if b.complete else "建造中", b.queue.size()]
	elif selected.size() == 1:
		var u: Dictionary = sim.entity(int(selected[0]))
		if not u.is_empty(): details.text = "%s · %.0f/%.0f HP · 战功 %d/%d · 晋升 %d/2\nG 驻军 / R 修复 · %s" % [sim.catalog[u.kind].name, u.hp, u.max_hp, u.kill_value, sim.catalog[u.kind].cost * 3, u.rank, sim.catalog[u.kind].skill]
	elif selected.size() > 1: details.text = "已选中 %d 名部队\n右键移动 / 攻击 / 寻宝 · G 驻军 / R 修复" % selected.size()

func show_phase_overlay() -> void:
	if is_instance_valid(overlay): overlay.queue_free()
	if sim.phase == "cards":
		overlay = panel_at(Vector2(250, 104), Vector2(680, 365))
		label_at(overlay, "远征准备  ·  随机抽牌", Vector2(26, 20), Vector2(620, 32), 26)
		label_at(overlay, "从以下五张效果牌中随机抽取两张，不会重复。", Vector2(26, 60), Vector2(620, 26), 17)
		for i in Rules.CARDS.size():
			var c: Dictionary = Rules.CARDS[i]
			label_at(overlay, "%s   %s" % [c.name, c.text], Vector2(34, 98 + i * 39), Vector2(610, 32), 17)
		button_at(overlay, "抽取两张效果牌", Vector2(190, 307), Vector2(300, 40), draw_opening_cards)
	elif sim.phase in ["victory", "defeat"]:
		overlay = panel_at(Vector2(340, 186), Vector2(500, 220))
		label_at(overlay, "远征胜利" if sim.phase == "victory" else "远征失败", Vector2(28, 22), Vector2(444, 40), 30)
		label_at(overlay, "部队 %d  ·  建筑 %d  ·  金币 %d" % [sim.living(0).size(), sim.buildings.filter(func(b): return b.team == 0).size(), sim.gold], Vector2(28, 76), Vector2(444, 26), 18)
		if sim.phase == "victory":
			button_at(overlay, "保留军团 · 下一场远征", Vector2(28, 125), Vector2(270, 45), func(): sim.next_battle())
		else:
			button_at(overlay, "重新开始", Vector2(28, 125), Vector2(270, 45), func():
				Session.pending_load_slot = -1
				get_tree().reload_current_scene())
		button_at(overlay, "返回菜单", Vector2(314, 125), Vector2(155, 45), return_menu)

func pick_card(id: String) -> void:
	sim.choose_card(id)
	show_phase_overlay()

func draw_opening_cards() -> void:
	sim.draw_cards()
	show_phase_overlay()
	refresh_ui()

func train(kind: String) -> void:
	if simulation_blocked(): return
	var b: Dictionary = sim.entity(selected_building)
	sim.train_unit(kind, selected_building if not b.is_empty() and b.team == 0 and b.kind in ["base", "barracks"] else -1)

func set_mode(value: String) -> void:
	if not sim.active() or simulation_blocked(): return
	mode = value
	if not open_drawer.is_empty(): toggle_drawer(open_drawer)
	var names := {"barracks": "兵营", "well": "魔力井", "house": "房屋", "freeze": "冰冻", "wall": "冰墙", "bridge": "冰桥"}
	if value in ["garrison", "repair"]:
		sim.message = "点击友方%s建筑，Esc 或右键取消。" % ("或中立已完工" if value == "garrison" else "受损")
	else: sim.message = "点击地图放置%s，Esc 或右键取消。" % names[value]

func select_all() -> void:
	selected.clear()
	selected_building = -1
	for u in sim.living(0):
		if u.home == -1: selected.append(u.id)

func evacuate_selected() -> void:
	if simulation_blocked() or not sim.active(): return
	var b: Dictionary = sim.entity(selected_building)
	if not b.is_empty() and b.team == 0: sim.evacuate(selected_building)

func toggle_pause() -> void:
	paused = not paused
	refresh_ui()

func save_progress(notify: bool) -> void:
	if Session.current_slot < 0:
		if notify: sim.message = "本次为直接运行；从主菜单选择槽位可启用存档。"
		return
	var ok := Saves.write_slot(Session.current_slot, sim.snapshot())
	if notify: sim.message = "远征进度已保存。" if ok else "存档写入失败。"

func return_menu() -> void:
	if sim.phase not in ["cards", "base"]: save_progress(false)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if wave_intro.active: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle_overview()
			get_viewport().set_input_as_handled()
			return
		if tactical_overlay.visible and event.keycode == KEY_ESCAPE:
			toggle_overview()
			return
	if tactical_overlay.visible: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P: toggle_pause()
			KEY_H: focus_home()
			KEY_ESCAPE:
				if not open_drawer.is_empty(): toggle_drawer(open_drawer)
				mode = "select"
				selected.clear()
				selected_building = -1
			KEY_A: select_all()
			KEY_Q: set_mode("freeze")
			KEY_W: set_mode("wall")
			KEY_E: set_mode("bridge")
			KEY_G: set_mode("garrison")
			KEY_R: set_mode("repair")
			KEY_F5: save_progress(true)
			KEY_SPACE: advance_wave()
	if event is InputEventMouseMotion:
		hover = event.position
		if panning: center_camera(camera_center - event.relative / zoom)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed and MAP_RECT.has_point(event.position)
			return
		if MAP_RECT.has_point(event.position) and event.pressed:
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				zoom_at(event.position, 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15)
				return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			dragging = false
			select_area(drag_start, event.position)
			return
		if not MAP_RECT.has_point(event.position) or simulation_blocked(): return
		var pos := map_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if sim.phase == "base":
				for i in Simulation.BASE_SITES.size():
					if pos.distance_to(Simulation.BASE_SITES[i]) < 2: sim.choose_base(i)
			elif sim.active():
				if mode in ["barracks", "well", "house"]:
					if sim.construct(mode, pos, selected): mode = "select"
				elif mode in ["freeze", "wall", "bridge"]:
					if sim.cast(mode, pos): mode = "select"
				elif mode in ["garrison", "repair"]:
					if building_order(pos, mode): mode = "select"
				else:
					drag_start = event.position
					dragging = true
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if mode != "select": mode = "select"
			else: contextual_order(pos)

func select_area(start: Vector2, end: Vector2) -> void:
	selected.clear()
	selected_building = -1
	var rect := Rect2(start, end - start).abs()
	if start.distance_to(end) < 7:
		var pos := map_point(end)
		for u in sim.living(0):
			if u.home == -1 and (sim.point(u) + Vector2(0, -0.4)).distance_to(pos) < 0.85:
				selected.append(u.id)
				return
		for b in sim.buildings:
			if building_hit(b, pos):
				selected_building = int(b.id)
				return
	else:
		for u in sim.living(0):
			if u.home == -1 and rect.has_point(screen_point(u)): selected.append(u.id)

func contextual_order(pos: Vector2) -> void:
	if not sim.active(): return
	for u in sim.units:
		if u.team != 0 and u.hp > 0 and u.home == -1 and (sim.point(u) + Vector2(0, -0.4)).distance_to(pos) < 0.85:
			sim.command(selected, "attack", pos, int(u.id))
			return
	# Small rewards can sit beside a tall house. Hit them before the building's
	# larger interaction footprint, otherwise the island reward cannot be clicked.
	for c in sim.chests:
		if (sim.point(c) + Vector2(0, -0.2)).distance_to(pos) < 0.8:
			sim.command(selected, "chest", pos, int(c.id))
			return
	for b in sim.buildings:
		if building_hit(b, pos):
			var order := "garrison"
			if b.team == 1: order = "attack"
			elif b.team == 0 and b.hp < b.max_hp: order = "repair"
			sim.command(selected, order, pos, int(b.id))
			return
	sim.command(selected, "move", pos)

func building_order(pos: Vector2, order: String) -> bool:
	if not sim.active() or simulation_blocked(): return false
	var eligible := selected.filter(func(id):
		var u: Dictionary = sim.entity(int(id))
		return not u.is_empty() and u.has("home") and u.team == 0 and u.home == -1 and u.hp > 0 and (order != "garrison" or u.kind in ["swordsman", "archer"]))
	if eligible.is_empty():
		sim.message = "先选择场外的剑士或弓箭手。" if order == "garrison" else "先选择至少一名场外部队。"
		return false
	for b in sim.buildings:
		if not building_hit(b, pos): continue
		if order == "garrison" and b.team in [-1, 0] and b.complete and b.hp > 0:
			sim.command(eligible, order, sim.point(b), int(b.id))
			return true
		if order == "repair" and b.team == 0 and b.hp > 0:
			sim.command(eligible, order, sim.point(b), int(b.id))
			return true
	sim.message = "选择有空位的友方或中立已完工建筑。" if order == "garrison" else "选择己方建筑。"
	return false

func building_hit(building: Dictionary, pos: Vector2) -> bool:
	if sim.point(building).distance_to(pos) < 1.3: return true
	var view: Sprite2D = tile_map.building_views.get(int(building.id))
	if not is_instance_valid(view): return false
	var screen := world_to_screen(pos)
	var local_point := view.to_local(screen)
	return view.get_rect().has_point(local_point) and view.is_pixel_opaque(local_point)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1180, 660), Color("0b151d"))

func draw_world(canvas: Node2D) -> void:
	for c in sim.chests:
		var p := screen_point(c)
		canvas.draw_arc(p, 10 * zoom / CELL, 0, TAU, 20, Color(1, 0.88, 0.42, 0.65), 1)
	for b in sim.buildings: draw_building(canvas, b)
	for u in sim.units:
		if u.home == -1: draw_unit(canvas, u)
	for s in sim.shots:
		var start := screen_point(s) + Vector2(0, -13)
		var finish := world_to_screen(Vector2(s.tx, s.ty)) + Vector2(0, -10)
		if s.get("ranged", false):
			var arrow := Art.texture("Factions/Knights/Troops/Archer/Arrow/Arrow.png")
			var position_on_line := start.lerp(finish, 1.0 - float(s.ttl) / 0.15)
			canvas.draw_set_transform(position_on_line, (finish - start).angle(), Vector2.ONE * zoom / 64.0)
			canvas.draw_texture(arrow, -arrow.get_size() / 2.0)
			canvas.draw_set_transform(Vector2.ZERO)
	if sim.phase == "base":
		for i in Simulation.BASE_SITES.size():
			var pos: Vector2 = world_to_screen(Simulation.BASE_SITES[i])
			canvas.draw_circle(pos, 27, Color(0.5, 0.85, 0.9, 0.18))
			canvas.draw_arc(pos, 27, 0, TAU, 32, BLUE, 2)
			canvas.draw_string(FONT, pos + Vector2(-29, -35), ["北岸营地", "湖西前哨", "南岸营地"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if dragging:
		var rect := Rect2(drag_start, hover - drag_start).abs()
		canvas.draw_rect(rect, Color(0.5, 0.9, 1, 0.12))
		canvas.draw_rect(rect, BLUE, false, 1)
	if mode != "select" and MAP_RECT.has_point(hover):
		canvas.draw_arc(hover, 3 * zoom if mode == "freeze" else zoom, 0, TAU, 32, BLUE, 2)

func team_color(team: int) -> Color:
	return BLUE if team == 0 else (RED if team == 1 else (GOLD if team == 2 else Color("b0bbb2")))

func world_marker_visible(pos: Vector2) -> bool:
	if pos.y < 72: return false
	if Rect2(dock.position - Vector2(8, 62), dock.size + Vector2(16, 62)).has_point(pos): return false
	return pos.distance_to(minimap.position + minimap.size * 0.5) > minimap.size.x * 0.5 + 10

func draw_building(canvas: Node2D, b: Dictionary) -> void:
	var pos := screen_point(b)
	if not world_marker_visible(pos): return
	var color := team_color(int(b.team))
	if selected_building == b.id: canvas.draw_arc(pos, 24 * zoom / CELL, 0, TAU, 32, GOLD, 2)
	if zoom < 12 and selected_building != b.id:
		canvas.draw_circle(pos + Vector2(0, 5), 2.0, color)
		return
	health_bar(canvas, pos + Vector2(-21, 7), 42, float(b.hp) / float(b.max_hp), color)
	var text := str(Rules.BUILDINGS[b.kind].name)
	if not b.complete: text = "建造 %.0f%%" % (b.hp / b.max_hp * 100)
	var count := sim.occupants(int(b.id)).size()
	if count > 0: text += " [%d]" % count
	canvas.draw_string(FONT, pos + Vector2(-27, 23), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("142c35"))
	canvas.draw_string(FONT, pos + Vector2(-28, 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func draw_unit(canvas: Node2D, u: Dictionary) -> void:
	var pos := screen_point(u)
	if not world_marker_visible(pos): return
	var color := team_color(int(u.team))
	if selected.has(u.id): canvas.draw_arc(pos + Vector2(0, 3), 10 * zoom / CELL, 0, TAU, 20, GOLD, 1.5)
	if zoom < 12: return
	if u.frozen > 0: canvas.draw_circle(pos, 11, Color(0.5, 0.9, 1, 0.4))
	if u.rank > 0: canvas.draw_string(FONT, pos + Vector2(-4, -33), "II" if u.rank == 2 else "I", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	if u.kind not in ["swordsman", "archer"] and u.team != 2:
		var badge := str(sim.catalog[u.kind].name).left(1)
		if u.kind == "cataphract": badge = "骑"
		canvas.draw_rect(Rect2(pos + Vector2(8, -24), Vector2(14, 14)), Color("193847"))
		canvas.draw_string(FONT, pos + Vector2(9, -12), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	health_bar(canvas, pos + Vector2(-9, 7), 18, float(u.hp) / float(u.max_hp), color)

func health_bar(canvas: Node2D, pos: Vector2, width: float, ratio: float, color: Color) -> void:
	canvas.draw_rect(Rect2(pos, Vector2(width, 3)), Color("10222c"))
	canvas.draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0, 1), 3)), color)
