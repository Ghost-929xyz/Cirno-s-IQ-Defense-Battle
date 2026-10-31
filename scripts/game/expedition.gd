extends Node2D

const Simulation = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
const Session = preload("res://scripts/autoload/session.gd")
const Saves = preload("res://scripts/autoload/save_manager.gd")
const FONT = preload("res://assets/fonts/unifont.otf")
const Art = preload("res://scripts/data/tiny_swords_art.gd")
const ResourceArt = preload("res://scripts/effects/resource_art.gd")
const CELL := 21.0
const MAX_ZOOM := 32.0
const FogLayer = preload("res://scripts/ui/rts_fog.gd")
const ORIGIN := Vector2.ZERO
const MAP_RECT := Rect2(0, 0, 1180, 660)
const DOCK_SIZE := Vector2(680, 208)
const DOCK_COLLAPSED_HEIGHT := 40.0
const DOCK_BOTTOM := 648.0
var zoom := 21.0
var zoom_target := 21.0
var zoom_anchor := Vector2.ZERO
var zoom_animating := false
var camera_center := Vector2(20, 25)
var panning := false
var world_overlay: Node2D
var minimap: Control
var drawers: Dictionary = {}
var tab_buttons: Dictionary = {}
var spell_buttons: Dictionary = {}
var category_buttons: Dictionary = {}
var roster_category := "步战"
var open_drawer := "recruit"
var pending_cards: Array = []
var card_buttons: Dictionary = {}
var confirm_cards_button: Button
var army_buttons: Dictionary = {}
var army_label: Label
var army_scroll: ScrollContainer
var research_buttons: Dictionary = {}
var research_views: Dictionary = {}
var research_categories: Dictionary = {}
var all_select_stage := 0
var all_select_kind := "swordsman"
var last_group_selection: Array = []
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
var control_groups: Dictionary = {}
var group_buttons: Dictionary = {}
var last_group_key := -1
var last_group_press := -1000
var idle_button: Button
var fog: Node2D
var command_strip: Control
var selected_building := -1
var selected_prop := -1
var hovered_building := -1
var building_cursor := Vector2(-1, -1)
var mode := "select"
const FrostMenu = preload("res://scripts/ui/frost_menu.gd")
var game_menu: Control
var game_menu_status: Label
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
var dock_collapsed := false
var dock_toggle: Button
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
var wave_button: Button
var vision_crystal: Node2D
var torch_heat: Node2D
var winter_weather: Node2D
@export var random_map_enabled := true
@onready var tile_map: Node2D = $Battlefield/FogLakeTileMap

func _ready() -> void:
	sim.configure_terrain(tile_map.terrain_water_cells(), tile_map.terrain_obstacle_cells())
	sim.register_trees(tile_map.trees.get_used_cells())
	if Session.pending_load_slot >= 0:
		var slot: int = Session.pending_load_slot
		Session.pending_load_slot = -1
		if not sim.restore(Saves.read_slot(slot)):
			sim.message = "存档不属于新版远征，未覆盖原文件。请返回菜单选择新的游戏。"
	elif random_map_enabled:
		var requested := Session.requested_map_seed
		var seed_value := randi_range(0, 2147483647) if requested.is_empty() else int(requested)
		sim.generate_map(seed_value)
	if not sim.generated_layout.is_empty(): tile_map.paint_generated(sim.generated_layout)
	control_groups = sim.control_groups
	fog = Node2D.new()
	fog.set_script(FogLayer)
	fog.sim = sim
	tile_map.add_child(fog)
	world_overlay = Node2D.new()
	world_overlay.set_script(preload("res://scripts/ui/rts_world_overlay.gd"))
	world_overlay.game = self
	world_overlay.position = -ORIGIN
	world_overlay.z_index = 10
	$Battlefield.add_child(world_overlay)
	build_ui()
	if sim.phase in ["cards", "base"]:
		zoom = CELL
		camera_center = Vector2(40, 25)
	else: focus_home()
	update_camera()
	last_wave_seen = sim.wave
	wave_campaign = sim.campaign
	last_phase = sim.phase
	show_phase_overlay()
	refresh_ui()
	tile_map.sync(sim, 0.0, paused)
	winter_weather = Node2D.new()
	winter_weather.set_script(preload("res://scripts/effects/rts_winter_weather.gd"))
	winter_weather.z_index = 20
	$Battlefield.add_child(winter_weather)
	winter_weather.setup(tile_map, sim)
	torch_heat = preload("res://scripts/effects/torch_heat.gd").new()
	torch_heat.game = self
	world_overlay.add_child(torch_heat)
	vision_crystal = preload("res://scripts/effects/vision_crystal.gd").new()
	vision_crystal.game = self
	world_overlay.add_child(vision_crystal)
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null: audio.bind_game(self)

func _exit_tree() -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null: audio.leave_game(self)

func _process(delta: float) -> void:
	update_smooth_zoom(delta)
	if panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE): panning = false
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging = false
	var pan := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)), float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if get_window().has_focus() and not panning and not dragging and get_viewport().gui_get_hovered_control() == null:
		pan += edge_pan_direction(building_cursor)
	if pan != Vector2.ZERO and not simulation_blocked() and sim.active(): center_camera(camera_center + pan.normalized() * delta * 450.0 / zoom)
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
	update_building_feedback()
	tile_map.update_unit_feedback(selected)
	winter_weather.sync(sim, simulation_blocked())
	torch_heat.sync()
	vision_crystal.sync()
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

func minimum_zoom() -> float:
	# The entire map fits at the limit; any aspect-ratio margins remain fogged.
	return minf(MAP_RECT.size.x / Simulation.WIDTH, MAP_RECT.size.y / Simulation.HEIGHT)

func edge_pan_direction(pos: Vector2) -> Vector2:
	if not MAP_RECT.has_point(pos) or simulation_blocked() or not sim.active(): return Vector2.ZERO
	var direction := Vector2.ZERO
	if pos.x < 16: direction.x = -1
	elif pos.x >= MAP_RECT.end.x - 16: direction.x = 1
	if pos.y < 16: direction.y = -1
	elif pos.y >= MAP_RECT.end.y - 16: direction.y = 1
	return direction

func center_camera(pos: Vector2) -> void:
	zoom_animating = false
	zoom_target = zoom
	camera_center = pos
	update_camera()

func update_camera() -> void:
	zoom = clampf(zoom, minimum_zoom(), MAX_ZOOM)
	zoom_target = clampf(zoom_target, minimum_zoom(), MAX_ZOOM)
	var half := MAP_RECT.size / zoom * 0.5
	var extent := Vector2(Simulation.WIDTH, Simulation.HEIGHT)
	for axis in 2:
		camera_center[axis] = clampf(camera_center[axis], minf(half[axis], extent[axis] * 0.5), maxf(extent[axis] - half[axis], extent[axis] * 0.5))
	tile_map.scale = Vector2.ONE * zoom / 64.0
	tile_map.position = MAP_RECT.size * 0.5 - camera_center * zoom

func zoom_at(pos: Vector2, factor: float) -> void:
	zoom_target = clampf((zoom_target if zoom_animating else zoom) * factor, minimum_zoom(), MAX_ZOOM)
	zoom_anchor = pos
	zoom_animating = true

func update_smooth_zoom(delta: float) -> void:
	if not zoom_animating: return
	var before := (zoom_anchor - MAP_RECT.get_center()) / zoom + camera_center
	zoom = lerpf(zoom, zoom_target, 1.0 - exp(-14.0 * maxf(delta, 0.0)))
	if absf(zoom_target - zoom) < 0.001:
		zoom = zoom_target
		zoom_animating = false
	camera_center = before - (zoom_anchor - MAP_RECT.get_center()) / zoom
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
	var keys := ["gold", "wood", "baka", "capacity", "tech", "tier"]
	var names := ["金币", "木材", "BAKA", "容量", "科技所", "路线"]
	var offsets := [304, 426, 548, 670, 812, 940]
	for i in keys.size():
		var title := label_at(layer, names[i], Vector2(offsets[i], 10), Vector2(42, 25), 13)
		title.add_theme_color_override("font_color", Color("b8cccf"))
		var number := label_at(layer, "", Vector2(offsets[i] + 46, 3), Vector2(90, 34), 23)
		number.add_theme_font_override("font", font_bold)
		number.add_theme_color_override("font_color", GOLD if keys[i] == "gold" else (BLUE if keys[i] == "baka" else Color("f4f8f6")))
		resource_labels[keys[i]] = number
	pause_button = icon_button_at(layer, "pause", Vector2(1068, 2), toggle_pause, "暂停 / 继续  P")
	icon_button_at(layer, "menu", Vector2(1122, 2), open_game_menu, "游戏菜单 · 存档 / 读取")
	objective = label_at(layer, "", Vector2(23, 39), Vector2(730, 25), 13)
	if not sim.map_seed.is_empty():
		var seed_button := compact_button_at(layer, "地图种子 %s · 复制" % sim.map_seed, Vector2(823, 38), Vector2(332, 29), copy_map_seed)
		seed_button.tooltip_text = "在新游戏界面输入相同种子编号，即可重现这张地图。"
	minimap = Control.new()
	minimap.set_script(preload("res://scripts/ui/rts_minimap.gd"))
	minimap.game = self
	minimap.position = Vector2(970, 500)
	minimap.size = Vector2(192, 132)
	minimap.wet_cells = tile_map.terrain_water_cells()
	layer.add_child(minimap)
	label_at(layer, "Tab  俯瞰地图", Vector2(1002, 633), Vector2(160, 22), 13)
	dock = panel_at(Vector2(236, DOCK_BOTTOM - DOCK_SIZE.y), DOCK_SIZE)
	var dock_style := StyleBoxFlat.new()
	dock_style.bg_color = Color(0.035, 0.08, 0.11, 0.88)
	dock_style.set_corner_radius_all(12)
	dock.add_theme_stylebox_override("panel", dock_style)
	details = label_at(layer, "", dock.position + Vector2(8, -52), Vector2(664, 49), 13)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.85))
	details.add_theme_constant_override("outline_size", 3)
	for i in 3:
		var key: String = ["recruit", "build", "research"][i]
		tab_buttons[key] = compact_button_at(dock, ["招募", "建造", "科技"][i], Vector2(8 + i * 64, 6), Vector2(58, 28), toggle_drawer.bind(key))
	var all_button := compact_button_at(dock, "同类 / 全军 A", Vector2(202, 6), Vector2(112, 28), select_all)
	all_button.tooltip_text = "第一次选中当前兵种的所有场外单位，再按一次选中全部场外部队。"
	compact_button_at(dock, "撤出", Vector2(320, 6), Vector2(50, 28), evacuate_selected)
	compact_button_at(dock, "基地 H", Vector2(376, 6), Vector2(76, 28), focus_home)
	compact_button_at(dock, "存档 F5", Vector2(458, 6), Vector2(94, 28), open_game_menu.bind("save"))
	dock_toggle = compact_button_at(dock, "收起 ▼", Vector2(576, 6), Vector2(96, 28), toggle_dock)
	dock_toggle.tooltip_text = "收起指挥栏以腾出战场视野；点击页签可直接展开。"
	for i in 3:
		var key: String = ["freeze", "wall", "bridge"][i]
		spell_buttons[key] = compact_button_at(dock, ["Q 冰冻 20", "W 冰墙 25", "E 冰桥 20"][i], Vector2(8 + i * 114, 174), Vector2(108, 28), set_mode.bind(key))
	wave_button = compact_button_at(dock, "迎敌  Space", Vector2(356, 174), Vector2(316, 28), advance_wave)
	status = label_at(layer, "", Vector2(14, 558), Vector2(190, 84), 12)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for key in ["recruit", "build", "research"]:
		var p := panel_at(dock.position + Vector2(0, 40), Vector2(680, 130))
		p.visible = key == open_drawer
		drawers[key] = p
	var recruit: Panel = drawers.recruit
	var index := 0
	for name_text in FAMILIES:
		category_buttons[name_text] = compact_button_at(recruit, name_text, Vector2(8 + index * 168, 3), Vector2(160, 24), filter_roster.bind(name_text))
		index += 1
	roster = GridContainer.new()
	roster.columns = 4
	roster.position = Vector2(8, 31)
	roster.add_theme_constant_override("h_separation", 6)
	roster.add_theme_constant_override("v_separation", 4)
	recruit.add_child(roster)
	for kind in sim.catalog:
		var d: Dictionary = sim.catalog[kind]
		var b := compact_button_at(roster, "%s\n%d 金 · %d 容量" % [d.name, d.cost, d.capacity], Vector2.ZERO, Vector2(161, 38), train.bind(kind))
		b.add_theme_font_size_override("font_size", 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = Art.portrait(kind)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 26)
		b.tooltip_text = "%s\n生命 %d | 攻击 %d | 射程 %s\n攻速 %s 次/秒 | 移速 %.1f 格/秒\n%s" % [d.name, d.hp, d.attack, str(d.range), str(d.attack_speed), d.move_speed, d.skill]
		train_buttons[kind] = b
	label_at(recruit, "仅显示已解锁兵种 · 科技所开放骑兵与刺客 · 进阶路线在科技页选择", Vector2(10, 113), Vector2(660, 17), 11)
	var build: Panel = drawers.build
	label_at(build, "选择场外部队，再选择设施并点击陆地。", Vector2(10, 2), Vector2(660, 24), 13)
	for i in 4:
		var b := button_at(build, ["兵营 · 160 金\n训练 / 扩充容量", "魔力井 · 200 金\n持续回复 BAKA", "房屋 · 120 金\n驻军防守 / 治疗", "科技所 · 240 金\n骑兵 / 刺客 / 研究"][i], Vector2(8 + i * 168, 30), Vector2(160, 52), set_mode.bind(["barracks", "well", "house", "academy"][i]))
		b.add_theme_font_size_override("font_size", 13)
	compact_button_at(build, "驻军 G", Vector2(8, 94), Vector2(96, 28), set_mode.bind("garrison"))
	compact_button_at(build, "修复 R", Vector2(110, 94), Vector2(96, 28), set_mode.bind("repair"))
	compact_button_at(build, "伐木 T", Vector2(212, 94), Vector2(96, 28), set_mode.bind("chop"))
	compact_button_at(build, "火堆 C · 20 木", Vector2(314, 94), Vector2(156, 28), set_mode.bind("campfire"))
	label_at(build, "右键树木 · 每棵 20 木材", Vector2(482, 96), Vector2(190, 24), 12)
	var research: Panel = drawers.research
	index = 0
	for family in FAMILIES:
		research_categories[family] = compact_button_at(research, family + "路线", Vector2(8 + index * 168, 3), Vector2(160, 24), filter_roster.bind(family))
		index += 1
	build_research_tree(research)
	build_army_bar()
	build_command_bar()
	filter_roster(roster_category)

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

func build_research_tree(parent: Control) -> void:
	var layouts := {
		"步战": {"swordsman": Vector2(8, 64), "guard": Vector2(236, 64), "paladin": Vector2(464, 32), "heavy_infantry": Vector2(464, 96)},
		"远程": {"archer": Vector2(8, 64), "sniper": Vector2(236, 32), "ice_archer": Vector2(236, 96), "sniper_plus": Vector2(464, 32), "ice_archer_plus": Vector2(464, 96)},
		"骑乘": {"cavalry": Vector2(8, 64), "ranger": Vector2(236, 32), "lancer": Vector2(236, 96), "scout": Vector2(464, 32), "cataphract": Vector2(464, 96)},
		"特战": {"assassin": Vector2(8, 64), "hermit": Vector2(236, 40), "berserker": Vector2(236, 96), "hermit_dodge": Vector2(464, 32), "hermit_blink": Vector2(464, 64), "berserker_plus": Vector2(464, 96)},
	}
	for family in layouts:
		var view := Control.new()
		view.size = parent.size
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(view)
		research_views[family] = view
		var layout: Dictionary = layouts[family]
		for kind in layout:
			if not Rules.UNIT_PARENTS.has(kind): continue
			var previous: String = Rules.UNIT_PARENTS[kind]
			var start: Vector2 = layout[previous] + Vector2(208, 14)
			var end: Vector2 = layout[kind] + Vector2(0, 14)
			var line := Line2D.new()
			line.width = 1.5
			line.default_color = Color("6b929c")
			line.points = PackedVector2Array([start, Vector2(start.x + 14, start.y), Vector2(start.x + 14, end.y), end])
			view.add_child(line)
		for kind in layout:
			var button := compact_button_at(view, sim.catalog[kind].name, layout[kind], Vector2(208, 28), research_kind.bind(kind))
			button.add_theme_font_size_override("font_size", 12)
			button.add_theme_color_override("font_disabled_color", Color("9eb8c1"))
			button.tooltip_text = "%s\n%s\n需要建成科技所；分叉路线互斥。\n解锁后可招募新兵，不会转换现有单位。" % [sim.catalog[kind].name, sim.catalog[kind].skill]
			research_buttons[kind] = button

func research_kind(kind: String) -> void:
	if simulation_blocked(): return
	sim.research_unit(kind)
	refresh_ui()

func build_army_bar() -> void:
	army_label = label_at(layer, "军团", Vector2(14, 78), Vector2(188, 26), 16)
	var scroll := ScrollContainer.new()
	army_scroll = scroll
	scroll.position = Vector2(14, 110)
	scroll.size = Vector2(190, 432)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	for kind in sim.catalog:
		var button := button_at(list, "", Vector2.ZERO, Vector2(172, 48), select_army_kind.bind(kind))
		button.add_theme_font_size_override("font_size", 13)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.icon = Art.portrait(kind)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 28)
		army_buttons[kind] = button
		button.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				select_army_kind(kind)
				button.accept_event())

func select_army_kind(kind: String) -> void:
	if simulation_blocked(): return
	mode = "select"
	selected = sim.living(0).filter(func(u): return u.kind == kind).map(func(u): return u.id)
	selected_building = -1
	all_select_stage = 0
	all_select_kind = kind
	var field := sim.living(0).filter(func(u): return u.kind == kind and u.home == -1)
	if not field.is_empty(): center_camera(sim.point(field[0]))
	elif not selected.is_empty():
		selected_building = int(sim.entity(int(selected[0])).home)
		center_camera(sim.point(sim.entity(selected_building)))
	refresh_ui()

func build_command_bar() -> void:
	command_strip = Control.new()
	command_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(command_strip)
	var actions := [["攻击移动 F", set_mode.bind("attack_move")], ["停止 S", issue_stance.bind("stop")], ["原地防守 D", issue_stance.bind("hold")]]
	for i in actions.size(): compact_button_at(command_strip, actions[i][0], Vector2(236 + i * 116, 76), Vector2(108, 28), actions[i][1])
	label_at(command_strip, "Shift 连续指令 · 选基地右键设集结点", Vector2(590, 77), Vector2(350, 26), 12)
	for digit in range(10):
		var button := compact_button_at(command_strip, "%d · 空" % digit, Vector2(236 + digit * 68, 109), Vector2(64, 40), select_control_group.bind(digit))
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = "Ctrl + %d 设置编队；%d 选择；双击数字定位。" % [digit, digit]
		group_buttons[digit] = button
	idle_button = compact_button_at(command_strip, "空闲 0 · I", Vector2(104, 76), Vector2(100, 28), select_idle_unit)
	army_label.size.x = 86

func issue_stance(order: String) -> void:
	if simulation_blocked(): return
	sim.command(selected, order, Vector2.ZERO)
	mode = "select"
	sim.message = "已停止并清空连续指令。" if order == "stop" else "原地防守：只攻击射程内目标，不追击。"
	refresh_ui()

func select_idle_unit() -> void:
	var idle := sim.idle_units()
	if idle.is_empty(): return
	var index := 0
	if selected.size() == 1:
		for i in idle.size():
			if idle[i].id == selected[0]: index = (i + 1) % idle.size()
	selected = [idle[index].id]
	selected_building = -1
	center_camera(sim.point(idle[index]))
	refresh_ui()

func refresh_army_bar() -> void:
	var army := sim.living(0)
	army_label.text = "军团 %d" % army.size()
	idle_button.text = "空闲 %d · I" % sim.idle_units().size()
	for digit in group_buttons:
		var members := available_group_members(control_groups.get(digit, []))
		var hp := 0.0
		var maximum := 0.0
		var fighting := false
		for id in members:
			var unit: Dictionary = sim.entity(int(id))
			hp += unit.hp
			maximum += unit.max_hp
			fighting = fighting or sim.unit_in_combat(unit)
		group_buttons[digit].text = "%d · %d人\n%s %d%%" % [digit, members.size(), "交战" if fighting else "待命", roundi(100 * hp / maxf(1, maximum))] if not members.is_empty() else "%d · 空" % digit
		group_buttons[digit].modulate = RED if fighting else (GOLD if not members.is_empty() and selected == members else Color.WHITE)
		group_buttons[digit].tooltip_text = "编队 %d · 生命 %.0f/%.0f · %d 人\nCtrl + 数字设置，双击数字定位。" % [digit, hp, maximum, members.size()]
	for kind in army_buttons:
		var troops := army.filter(func(u): return u.kind == kind)
		var button: Button = army_buttons[kind]
		button.visible = not troops.is_empty()
		if troops.is_empty(): continue
		var inside := troops.filter(func(u): return u.home != -1).size()
		button.text = "%s × %d\n场外 %d · 驻军 %d" % [sim.catalog[kind].name, troops.size(), troops.size() - inside, inside]
		button.tooltip_text = "左键或右键选择全部%s并定位。\nCtrl + 数字键编队，数字键选择编队。\n一级 %d 名 · 二级 %d 名\n驻军也计入总数；驻军需先撤出才能移动。" % [sim.catalog[kind].name, troops.filter(func(u): return u.rank == 1).size(), troops.filter(func(u): return u.rank == 2).size()]
		button.modulate = GOLD if troops.any(func(u): return selected.has(u.id)) else Color.WHITE

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
	tactical_map.expanded_map = true
	tactical_map.position = Vector2(190, 90)
	tactical_map.size = Vector2(800, 500)
	tactical_map.wet_cells = tile_map.terrain_water_cells()
	tactical_overlay.add_child(tactical_map)
	label_at(tactical_overlay, "金矿 ■  魔泉 ●  灵视 ▲  红圈受袭  |  左键定位 · 右键下令 · Tab 收起", Vector2(204, 607), Vector2(780, 28), 15)
	tactical_overlay.visible = false

func toggle_overview() -> void:
	if wave_intro.active: return
	update_dock_layout()
	dragging = false
	panning = false
	mode = "select"
	tactical_overlay.visible = not tactical_overlay.visible

func simulation_blocked() -> bool:
	return paused or is_instance_valid(game_menu) or tactical_overlay.visible or wave_intro.active

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
	update_dock_layout()
	mode = "select"
	dragging = false
	panning = false
	for wave in range(last_wave_seen + 1, sim.wave + 1): wave_intro.queue_wave(wave)
	last_wave_seen = sim.wave
	accumulator = 0.0


func toggle_drawer(key: String) -> void:
	open_drawer = key
	dock_collapsed = false
	mode = "select"
	dragging = false
	update_dock_layout()

func toggle_dock() -> void:
	dock_collapsed = not dock_collapsed
	dragging = false
	update_dock_layout()

func update_dock_layout() -> void:
	var command_visible := sim.phase not in ["cards", "base"]
	dock.visible = command_visible
	dock.size = Vector2(DOCK_SIZE.x, DOCK_COLLAPSED_HEIGHT if dock_collapsed else DOCK_SIZE.y)
	dock.position.y = DOCK_BOTTOM - dock.size.y
	dock_toggle.text = "展开 ▲" if dock_collapsed else "收起 ▼"
	details.visible = command_visible
	details.position = dock.position + Vector2(8, -52)
	for key in drawers:
		drawers[key].position = dock.position + Vector2(0, 40)
		drawers[key].visible = command_visible and not dock_collapsed and key == open_drawer
	for button in spell_buttons.values(): button.visible = not dock_collapsed
	wave_button.visible = not dock_collapsed
	for name_text in tab_buttons: tab_buttons[name_text].modulate = GOLD if name_text == open_drawer else Color.WHITE

func filter_roster(category: String) -> void:
	roster_category = category
	for kind in train_buttons: train_buttons[kind].visible = kind in FAMILIES[category] and sim.unit_unlocked(kind)
	for key in category_buttons: category_buttons[key].modulate = BLUE if key == category else Color.WHITE
	for key in research_categories: research_categories[key].modulate = BLUE if key == category else Color.WHITE
	for key in research_views: research_views[key].visible = key == category

func refresh_ui() -> void:
	var command_visible := sim.phase not in ["cards", "base"]
	update_dock_layout()
	command_strip.visible = command_visible
	army_label.visible = command_visible
	army_scroll.visible = command_visible
	resource_labels.gold.text = "%d" % sim.gold
	resource_labels.wood.text = str(sim.wood)
	resource_labels.baka.text = "%d" % sim.baka
	resource_labels.capacity.text = "%d/%d" % [sim.used_capacity(), sim.capacity()]
	resource_labels.tech.text = "就绪" if sim.has_academy() else "未建"
	resource_labels.tier.text = str(sim.unlocked_units.size() - 2)
	var phase_names := {"cards": "开局选牌", "base": "选择基地", "prep": "部署探索", "defense": "抵御进攻", "cleanup": "清剿敌军", "victory": "远征胜利", "defeat": "远征失败"}
	objective.text = "远征 %02d   /   %s   /   波次 %d/%d   /   %.0f 秒" % [sim.campaign, phase_names[sim.phase], sim.wave, Rules.WAVE_COUNT, maxf(0, sim.timer)]
	if sim.phase == "cleanup": objective.text = "清剿据点   /   敌军 %d   /   敌方建筑 %d   /   野怪为可选探索" % [sim.living(1).size(), sim.buildings.filter(func(b): return b.team == 1 and b.hp > 0).size()]
	status.text = ("已暂停  |  " if paused else "") + sim.message
	pause_button.icon_name = "play" if paused else "pause"
	wave_button.disabled = simulation_blocked() or not sim.active() or sim.wave >= Rules.WAVE_COUNT
	for kind in train_buttons:
		var d: Dictionary = sim.catalog[kind]
		train_buttons[kind].disabled = simulation_blocked() or not sim.active() or sim.gold < d.cost or not sim.unit_unlocked(kind) or sim.used_capacity() + d.capacity > sim.capacity()
	for kind in research_buttons:
		var unlocked := sim.unit_unlocked(kind)
		var error := sim.research_error(kind)
		var state := "可招募" if unlocked else ("路线关闭" if sim.branch_conflict(kind) else ("需科技所" if not sim.has_academy() else "%d 金" % sim.branch_cost(kind)))
		if kind in ["swordsman", "archer"]: state = "初始兵种"
		research_buttons[kind].text = "%s · %s" % [sim.catalog[kind].name, state]
		var prerequisite := "初始即可招募。"
		if kind in ["cavalry", "assassin"]: prerequisite = "科技所完工后自动开放。"
		elif Rules.UNIT_PARENTS.has(kind): prerequisite = "前置：%s · 研究 %d 金\n%s\n分叉路线互斥；解锁新兵招募，不转换现有单位。" % [sim.catalog[Rules.UNIT_PARENTS[kind]].name, sim.branch_cost(kind), error if not error.is_empty() else "可研究。"]
		research_buttons[kind].tooltip_text = "%s\n%s\n%s" % [sim.catalog[kind].name, sim.catalog[kind].skill, prerequisite]
		research_buttons[kind].disabled = simulation_blocked() or not error.is_empty()
		research_buttons[kind].modulate = BLUE if unlocked else Color.WHITE
	filter_roster(roster_category)
	refresh_army_bar()
	for key in spell_buttons:
		spell_buttons[key].modulate = BLUE if mode == key else Color.WHITE
		spell_buttons[key].disabled = simulation_blocked() or not sim.active() or sim.baka < (Rules.WALL_COST if key == "wall" else Rules.FREEZE_COST)
	details.text = "军团待命 · %s\n左键选择 / 框选  ·  右键下令  ·  G 驻军 / R 修复" % sim.card_names()
	if sim.phase == "base": details.text = "开局效果 · %s\n北岸 / 湖西 / 南岸 · 点击高亮格" % sim.card_names()
	var b: Dictionary = sim.entity(selected_building)
	if not b.is_empty() and b.has("complete"):
		details.text = "%s · %.0f/%.0f HP · 驻军 %d/%d · %s\n训练队列 %d · 选部队后 G 驻军 / R 修复" % [Rules.BUILDINGS[b.kind].name, b.hp, b.max_hp, sim.occupants(selected_building).size(), Rules.BUILDINGS[b.kind].beds, "完工" if b.complete else "建造中", b.queue.size()]
	elif selected.size() == 1:
		var u: Dictionary = sim.entity(int(selected[0]))
		if not u.is_empty():
			var progress := "已满级" if u.rank == 2 else "累计经验 %.0f / >%d" % [u.kill_value, sim.catalog[u.kind].cost * (3 if u.rank == 0 else 6)]
			details.text = "%s · %.0f/%.0f HP · %s · 晋升 %d/2\n%s" % [sim.catalog[u.kind].name, u.hp, u.max_hp, progress, u.rank, "一级伤害 +20% · 二级生命上限 +20% / 每秒回复 2%"]
	elif selected.size() > 1: details.text = "已选中 %d 名部队\n右键树木伐木 · C 布置火堆 · G 驻军 / R 修复" % selected.size()
	if selected_prop != -1:
		var prop: Dictionary = sim.entity(selected_prop)
		if prop.get("kind", "") == "tree":
			details.text = "树木 · 伐木进度 %.0f%% · 产出 %d 木材\n选中部队右键伐木；或按 T 派遣最近的空闲部队。" % [(1.0-float(prop.hp)/float(prop.max_hp))*100,Rules.TREE_WOOD] if prop.hp > 0 else "树桩 · 木材已采集\n这片空地现在可以通行，也可布置火堆。"
		elif prop.get("kind", "") == "campfire":
			details.text = "火堆 · %s\n消耗 20 木材，点燃后照亮周边迷雾。" % ("已点燃" if prop.complete else "生火中；选中部队右键继续")

func show_phase_overlay() -> void:
	if is_instance_valid(overlay): overlay.queue_free()
	if sim.phase == "cards":
		overlay = panel_at(Vector2(250, 80), Vector2(680, 444))
		label_at(overlay, "远征准备  ·  手动选牌", Vector2(26, 16), Vector2(620, 32), 26)
		label_at(overlay, "从五张效果牌中选择两张；确认前可以更换。", Vector2(26, 54), Vector2(620, 26), 17)
		card_buttons.clear()
		if pending_cards.is_empty(): pending_cards = sim.cards.duplicate()
		for i in Rules.CARDS.size():
			var c: Dictionary = Rules.CARDS[i]
			card_buttons[c.id] = button_at(overlay, "", Vector2(26, 92 + i * 56), Vector2(628, 48), pick_card.bind(c.id))
		confirm_cards_button = button_at(overlay, "", Vector2(190, 388), Vector2(300, 40), confirm_opening_cards)
		refresh_card_choices()
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
	if sim.phase != "cards" or not card_buttons.has(id) or sim.cards.has(id): return
	if pending_cards.has(id): pending_cards.erase(id)
	elif pending_cards.size() < 2: pending_cards.append(id)
	refresh_card_choices()

func refresh_card_choices() -> void:
	for c in Rules.CARDS:
		if not card_buttons.has(c.id): continue
		card_buttons[c.id].text = "%s  %s   %s" % ["[已选]" if pending_cards.has(c.id) else "[选择]", c.name, c.text]
		card_buttons[c.id].modulate = GOLD if pending_cards.has(c.id) else Color.WHITE
		card_buttons[c.id].disabled = sim.cards.has(c.id) or (pending_cards.size() == 2 and not pending_cards.has(c.id))
	confirm_cards_button.text = "确认效果牌  %d / 2" % pending_cards.size()
	confirm_cards_button.disabled = pending_cards.size() != 2

func confirm_opening_cards() -> void:
	if sim.phase != "cards" or pending_cards.size() != 2: return
	for id in pending_cards:
		if not sim.cards.has(id): sim.choose_card(id)
	focus_home()
	show_phase_overlay()
	refresh_ui()

func draw_opening_cards() -> void:
	confirm_opening_cards()

func train(kind: String) -> void:
	if simulation_blocked(): return
	var b: Dictionary = sim.entity(selected_building)
	sim.train_unit(kind, selected_building if not b.is_empty() and b.team == 0 and b.kind in ["base", "barracks"] else -1)

func set_mode(value: String) -> void:
	if not sim.active() or simulation_blocked(): return
	mode = value
	if value == "chop" and selected.is_empty() and selected_prop != -1:
		dispatch_lumberjack(selected_prop)
		mode = "select"
		return
	var names := {"chop": "要采集的树木", "campfire": "火堆（20 木材）", "barracks": "兵营", "well": "魔力井", "house": "房屋", "academy": "科技所", "freeze": "冰冻", "wall": "冰墙", "bridge": "冰桥", "attack_move": "攻击移动目标"}
	if value in ["garrison", "repair"]:
		sim.message = "点击友方%s建筑，Esc 或右键取消。" % ("或中立已完工" if value == "garrison" else "受损")
	else: sim.message = "点击地图放置%s，Esc 或右键取消。" % names[value]

func select_all() -> void:
	if simulation_blocked() or not sim.active(): return
	var army := sim.living(0).filter(func(u): return u.home == -1)
	selected_building = -1
	if all_select_stage == 1 and selected == last_group_selection:
		selected = army.map(func(u): return u.id)
		all_select_stage = 0
	else:
		if not selected.is_empty():
			var first := sim.entity(int(selected[0]))
			if not first.is_empty(): all_select_kind = first.kind
		if not army.any(func(u): return u.kind == all_select_kind) and not army.is_empty(): all_select_kind = army[0].kind
		selected = army.filter(func(u): return u.kind == all_select_kind).map(func(u): return u.id)
		last_group_selection = selected.duplicate()
		all_select_stage = 1
	refresh_ui()

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

func copy_map_seed() -> void:
	DisplayServer.clipboard_set(sim.map_seed)
	sim.message = "地图种子 %s 已复制，可在新游戏中输入此编号。" % sim.map_seed

func return_menu() -> void:
	if sim.phase not in ["cards", "base"]: save_progress(false)
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _input(event: InputEvent) -> void:
	# Track the pointer before GUI handling so leaving the map for a panel clears hover.
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		building_cursor = event.position

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT: building_cursor = Vector2(-1, -1)

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(game_menu):
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_P]: close_game_menu()
		get_viewport().set_input_as_handled()
		return
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
		var digit := control_group_digit(event.keycode)
		if digit >= 0:
			if event.ctrl_pressed: assign_control_group(digit)
			else: select_control_group(digit)
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_P: toggle_pause()
			KEY_H: focus_home()
			KEY_ESCAPE:
				selected_prop = -1
				mode = "select"
				selected.clear()
				selected_building = -1
				all_select_stage = 0
			KEY_A: select_all()
			KEY_F: set_mode("attack_move")
			KEY_S: issue_stance("stop")
			KEY_D: issue_stance("hold")
			KEY_I: select_idle_unit()
			KEY_Q: set_mode("freeze")
			KEY_W: set_mode("wall")
			KEY_E: set_mode("bridge")
			KEY_G: set_mode("garrison")
			KEY_R: set_mode("repair")
			KEY_T: set_mode("chop")
			KEY_C: set_mode("campfire")
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
				var scroll_amount: float = event.factor if event.factor > 0 else 1.0
				zoom_at(event.position, pow(1.15, scroll_amount if event.button_index == MOUSE_BUTTON_WHEEL_UP else -scroll_amount))
				return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			dragging = false
			select_area(drag_start, event.position)
			return
		if not MAP_RECT.has_point(event.position) or simulation_blocked(): return
		var pos := map_point(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if sim.active():
				if mode == "campfire":
					if sim.place_campfire(pos, selected, event.shift_pressed) and not event.shift_pressed: mode = "select"
				elif mode == "chop":
					if order_tree_at(pos,event.shift_pressed) and not event.shift_pressed: mode = "select"
				elif mode in ["barracks", "well", "house", "academy"]:
					if sim.construct(mode, pos, selected, event.shift_pressed) and not event.shift_pressed: mode = "select"
				elif mode in ["freeze", "wall", "bridge"]:
					if sim.cast(mode, pos): mode = "select"
				elif mode in ["garrison", "repair"]:
					if building_order(pos, mode, event.shift_pressed) and not event.shift_pressed: mode = "select"
				elif mode == "attack_move":
					sim.command(selected, "attack_move", pos, -1, event.shift_pressed)
					if not event.shift_pressed: mode = "select"
				else:
					drag_start = event.position
					dragging = true
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if mode != "select": mode = "select"
			elif selected.is_empty() and selected_building >= 0:
				sim.set_rally(selected_building, pos, event.shift_pressed)
			elif not select_friendly_at(pos, event.shift_pressed): contextual_order(pos, event.shift_pressed)

func control_group_digit(key: Key) -> int:
	if key >= KEY_0 and key <= KEY_9: return key - KEY_0
	if key >= KEY_KP_0 and key <= KEY_KP_9: return key - KEY_KP_0
	return -1

func available_group_members(ids: Array) -> Array:
	return ids.filter(func(id):
		var unit: Dictionary = sim.entity(int(id))
		return not unit.is_empty() and unit.has("home") and unit.team == 0 and unit.hp > 0)

func assign_control_group(digit: int) -> void:
	if simulation_blocked() or not sim.active(): return
	var members := available_group_members(selected)
	if members.is_empty():
		sim.message = "先选择己方部队，再按 Ctrl + 数字键编队。"
	else:
		control_groups[digit] = members.duplicate()
		sim.message = "已保存编队 %d：%d 名部队，按 %d 选择。" % [digit, members.size(), digit]
	refresh_ui()

func select_control_group(digit: int) -> void:
	if simulation_blocked() or not sim.active(): return
	var members := available_group_members(control_groups.get(digit, []))
	control_groups[digit] = members
	selected = members.duplicate()
	var now := Time.get_ticks_msec()
	if digit == last_group_key and now - last_group_press < 350 and not members.is_empty():
		var center := Vector2.ZERO
		for id in members: center += sim.point(sim.entity(int(id)))
		center_camera(center / members.size())
	last_group_key = digit
	last_group_press = now
	selected_building = -1
	mode = "select"
	dragging = false
	all_select_stage = 0
	sim.message = "已选编队 %d：%d 名部队。" % [digit, members.size()] if not members.is_empty() else "编队 %d 暂无存活部队，选中部队后按 Ctrl + %d 设置。" % [digit, digit]
	refresh_ui()

func select_friendly_at(pos: Vector2, additive := false) -> bool:
	if not sim.active(): return false
	for unit in sim.living(0):
		if unit.home != -1 or not unit_hit(unit, pos): continue
		if not additive: selected.clear()
		if not selected.has(unit.id): selected.append(unit.id)
		selected_building = -1
		all_select_stage = 0
		dragging = false
		refresh_ui()
		return true
	return false

func select_area(start: Vector2, end: Vector2) -> void:
	selected_prop = -1
	selected.clear()
	selected_building = -1
	all_select_stage = 0
	var rect := Rect2(start, end - start).abs()
	if start.distance_to(end) < 7:
		var pos := map_point(end)
		for u in sim.living(0):
			if u.home == -1 and unit_hit(u, pos):
				selected.append(u.id)
				return
		selected_prop = prop_at_screen_position(end)
		if selected_prop != -1: return
		for b in sim.buildings:
			if building_hit(b, pos):
				selected_building = int(b.id)
				return
	else:
		for u in sim.living(0):
			if u.home == -1 and rect.has_point(screen_point(u)): selected.append(u.id)

func contextual_order(pos: Vector2, append := false) -> void:
	if not sim.active(): return
	for u in sim.units:
		if u.team != 0 and u.hp > 0 and u.home == -1 and sim.is_visible(sim.point(u)) and unit_hit(u, pos):
			sim.command(selected, "attack", pos, int(u.id), append)
			return
	if order_tree_at(pos, append, false): return
	for fire in sim.campfires:
		if not fire.complete and sim.is_visible(sim.point(fire)) and sim.point(fire).distance_to(pos) < 1.0:
			sim.command(selected,"light_fire",sim.point(fire),int(fire.id),append)
			return
	for site in sim.resource_sites:
		if sim.resource_known(site) and resource_hit(site, pos):
			sim.command(selected, "capture", sim.point(site), int(site.id), append)
			return
	# Small rewards can sit beside a tall house. Hit them before the building's
	# larger interaction footprint, otherwise the island reward cannot be clicked.
	for c in sim.chests:
		if sim.is_visible(sim.point(c)) and ((sim.point(c) + Vector2(0, -0.2)).distance_to(pos) < 0.8 or prop_at_screen_position(world_to_screen(pos)) == int(c.id)):
			sim.command(selected, "chest", pos, int(c.id), append)
			return
	for b in sim.buildings:
		if building_hit(b, pos):
			var order := "garrison"
			if b.team == 1: order = "attack"
			elif b.team == 0 and b.hp < b.max_hp: order = "repair"
			sim.command(selected, order, pos, int(b.id), append)
			return
	sim.command(selected, "move", pos, -1, append)

func resource_hit(site: Dictionary, pos: Vector2) -> bool:
	if sim.point(site).distance_to(pos) < 1.5: return true
	var extent := ResourceArt.resource_size(str(site.kind)) / CELL
	return Rect2(sim.point(site) + Vector2(-extent.x * 0.5, -extent.y + 3.0 / CELL), extent).has_point(pos)

func unit_hit(unit: Dictionary, pos: Vector2) -> bool:
	return (sim.point(unit) + Vector2(0, -0.4 * Rules.visual_scale(unit.kind))).distance_to(pos) < (1.12 if unit.kind in Rules.MOUNTED else 0.72)

func building_order(pos: Vector2, order: String, append := false) -> bool:
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
			sim.command(eligible, order, sim.point(b), int(b.id), append)
			return true
		if order == "repair" and b.team == 0 and b.hp > 0:
			sim.command(eligible, order, sim.point(b), int(b.id), append)
			return true
	sim.message = "选择有空位的友方或中立已完工建筑。" if order == "garrison" else "选择己方建筑。"
	return false

func building_hit(building: Dictionary, pos: Vector2) -> bool:
	if building.team != 0 and not sim.is_visible(sim.point(building)): return false
	if sim.point(building).distance_to(pos) < 1.3: return true
	var view: Sprite2D = tile_map.building_views.get(int(building.id))
	if not is_instance_valid(view): return false
	var screen := world_to_screen(pos)
	var local_point := view.to_local(screen)
	return view.get_rect().has_point(local_point) and view.is_pixel_opaque(local_point)

func building_at_screen_position(pos: Vector2) -> int:
	var hit := -1
	var nearest_y := -INF
	for id in tile_map.building_views:
		var view: Sprite2D = tile_map.building_views[id]
		if not is_instance_valid(view) or not view.is_visible_in_tree(): continue
		var local_point := view.get_global_transform_with_canvas().affine_inverse() * pos
		if view.get_rect().has_point(local_point) and view.is_pixel_opaque(local_point):
			# Actors use Y sorting, so the visually frontmost building wins.
			if view.global_position.y >= nearest_y:
				nearest_y = view.global_position.y
				hit = int(id)
	return hit

func prop_at_screen_position(pos: Vector2) -> int:
	var hit := -1
	var front := -INF
	var views: Dictionary = tile_map.selectable_props()
	for id in views:
		var view: Sprite2D = views[id]
		var prop: Dictionary = sim.entity(int(id))
		if prop.get("kind", "") == "tree" and not sim.is_visible(sim.point(prop)): continue
		if not is_instance_valid(view) or not view.is_visible_in_tree(): continue
		var local := view.get_global_transform_with_canvas().affine_inverse() * pos
		if view.get_rect().has_point(local) and view.is_pixel_opaque(local) and view.global_position.y >= front:
			front = view.global_position.y
			hit = int(id)
	var building_id := building_at_screen_position(pos)
	if building_id >= 0 and tile_map.building_views[building_id].global_position.y > front: return -1
	return hit

func update_building_feedback() -> void:
	hovered_building = -1
	var cursor := building_cursor
	var covered := get_viewport().gui_get_hovered_control() != null
	var phase_overlay_open := is_instance_valid(overlay) and not overlay.is_queued_for_deletion() and overlay.visible
	if MAP_RECT.has_point(cursor) and not covered and not phase_overlay_open and not tactical_overlay.visible and not wave_intro.active:
		hovered_building = building_at_screen_position(cursor)
	if selected_building >= 0 and not tile_map.building_views.has(selected_building): selected_building = -1
	if selected_building >= 0:
		var selected_structure: Dictionary = sim.entity(selected_building)
		if not selected_structure.is_empty() and selected_structure.team != 0 and not sim.is_visible(sim.point(selected_structure)): selected_building = -1
	if not selected.is_empty() or selected_building >= 0: selected_prop = -1
	if not tile_map.selectable_props().has(selected_prop): selected_prop = -1
	var hovered_prop := -1
	if MAP_RECT.has_point(cursor) and not covered and not phase_overlay_open and not tactical_overlay.visible and not wave_intro.active:
		hovered_prop = prop_at_screen_position(cursor)
	if hovered_prop != -1: hovered_building = -1
	tile_map.update_building_feedback(hovered_building, selected_building)
	tile_map.update_prop_feedback(hovered_prop, selected_prop)

func _draw() -> void:
	draw_rect(get_viewport_rect(), FogLayer.UNEXPLORED_COLOR)

func draw_world(canvas: Node2D) -> void:
	draw_exploration(canvas)
	for b in sim.buildings:
		if b.team == 0 or sim.is_visible(sim.point(b)): draw_building(canvas, b)
	for u in sim.units:
		if u.home == -1 and (u.team == 0 or sim.is_visible(sim.point(u))): draw_unit(canvas, u)
	for s in sim.shots:
		if not sim.is_visible(sim.point(s)) and not sim.is_visible(Vector2(s.tx, s.ty)): continue
		var start := screen_point(s) + Vector2(0, -13)
		var finish := world_to_screen(Vector2(s.tx, s.ty)) + Vector2(0, -10)
		if s.get("ranged", false):
			var arrow := Art.texture("Factions/Knights/Troops/Archer/Arrow/Arrow.png")
			var position_on_line := start.lerp(finish, 1.0 - float(s.ttl) / 0.15)
			canvas.draw_set_transform(position_on_line, (finish - start).angle(), Vector2.ONE * zoom / 64.0)
			canvas.draw_texture(arrow, -arrow.get_size() / 2.0)
			canvas.draw_set_transform(Vector2.ZERO)
	if dragging:
		var rect := Rect2(drag_start, hover - drag_start).abs()
		canvas.draw_rect(rect, Color(0.5, 0.9, 1, 0.12))
		canvas.draw_rect(rect, BLUE, false, 1)
	if mode != "select" and MAP_RECT.has_point(hover):
		if mode in ["barracks", "well", "house", "academy", "campfire"]:
			var cell := map_point(hover).round()
			var error := sim.campfire_error(cell,selected) if mode == "campfire" else sim.construction_error(mode,cell,selected)
			var tint := BLUE if error.is_empty() else RED
			draw_placement_cell(canvas, cell, tint)
		elif mode == "chop":
			canvas.draw_line(hover + Vector2(-5,5),hover + Vector2(5,-5),GOLD,2)
		else:
			canvas.draw_arc(hover, 3 * zoom if mode == "freeze" else zoom, 0, TAU, 32, BLUE, 2)

func draw_exploration(canvas: Node2D) -> void:
	var scale_factor := zoom / CELL
	for torch in sim.torch_positions():
		if sim.is_visible(torch): ResourceArt.draw_torch(canvas, world_to_screen(torch), scale_factor, sim.elapsed, torch.x + torch.y)
	for tree in sim.tree_sites:
		if tree.hp > 0 and tree.hp < tree.max_hp and sim.is_visible(sim.point(tree)):
			rounded_bar(canvas,Rect2(screen_point(tree)+Vector2(-15,7)*scale_factor,Vector2(30,3)*scale_factor),1.0-float(tree.hp)/float(tree.max_hp),GOLD)
	for fire in sim.campfires:
		if not fire.complete and sim.is_visible(sim.point(fire)):
			rounded_bar(canvas,Rect2(screen_point(fire)+Vector2(-12,6)*scale_factor,Vector2(24,3)*scale_factor),float(fire.progress)/Rules.CAMPFIRE_BUILD_SECONDS,GOLD)
	for site in sim.resource_sites:
		if not sim.is_visible(sim.point(site)): continue
		var p := screen_point(site)
		# Only show progress while capturing; resource props have no surrounding rings.
		if site.capture > 0 and site.capture < 5.0:
			var bar := Rect2(p + Vector2(-16, 8) * scale_factor, Vector2(32, 3) * scale_factor)
			rounded_bar(canvas, bar, float(site.capture) / 5.0, Color.WHITE)
	var b: Dictionary = sim.entity(selected_building)
	if not b.is_empty() and b.team == 0:
		for rally in b.get("rally", []).slice(-1):
			var p := world_to_screen(Vector2(rally.x, rally.y))
			canvas.draw_line(p, p + Vector2(0, -18), GOLD, 2)
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -18), p + Vector2(12, -14), p + Vector2(0, -10)]), GOLD)
	for destination in command_markers():
		var p := world_to_screen(destination)
		var corners := PackedVector2Array([p + Vector2(0,-7), p + Vector2(7,0), p + Vector2(0,7), p + Vector2(-7,0), p + Vector2(0,-7)])
		canvas.draw_polyline(corners, BLUE, 1.5)
		canvas.draw_circle(p, 2, Color.WHITE)

func command_markers() -> Array[Vector2]:
	var markers: Array[Vector2] = []
	for id in selected:
		var u: Dictionary = sim.entity(int(id))
		if u.is_empty() or not u.has("home") or u.hp <= 0 or u.home != -1: continue
		var order: Dictionary = u
		var queued: Array = u.get("orders", [])
		if not queued.is_empty(): order = queued.back()
		if order.order not in ["move", "attack_move"]: continue
		var destination := Vector2(float(order.get("marker_x", order.get("goal_x", order.x))), float(order.get("marker_y", order.get("goal_y", order.y))))
		if not markers.has(destination): markers.append(destination)
	return markers

func draw_placement_cell(canvas: Node2D, cell: Vector2, tint: Color) -> void:
	var rect := Rect2(world_to_screen(cell) - Vector2.ONE * zoom * 0.5, Vector2.ONE * zoom)
	var pulse := 0.23 + 0.09 * sin(Time.get_ticks_msec() * 0.006)
	canvas.draw_rect(rect, Color(tint, pulse))
	canvas.draw_rect(rect, Color(tint, 0.95), false, 2.0)

func team_color(team: int) -> Color:
	return BLUE if team == 0 else (RED if team == 1 else (GOLD if team == 2 else Color("b0bbb2")))

func world_marker_visible(pos: Vector2) -> bool:
	if pos.y < 72: return false
	if Rect2(10, 76, 198, 472).has_point(pos): return false
	if Rect2(dock.position - Vector2(8, 62), dock.size + Vector2(16, 62)).has_point(pos): return false
	return not minimap.get_rect().grow(10).has_point(pos)

func draw_building(canvas: Node2D, b: Dictionary) -> void:
	var pos := screen_point(b)
	if not world_marker_visible(pos): return
	var color := team_color(int(b.team))
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
	rounded_bar(canvas, Rect2(pos, Vector2(width, 4)), ratio, color)

func rounded_bar(canvas: Node2D, rect: Rect2, ratio: float, color: Color) -> void:
	preload("res://scripts/ui/rounded_bars.gd").draw(canvas, rect, ratio, color)

func open_game_menu(page := "pause") -> void:
	if wave_intro.active: return
	close_game_menu()
	dragging = false
	panning = false
	game_menu = preload("res://scripts/ui/expedition_menu.gd").new()
	layer.add_child(game_menu)
	game_menu.setup(self, page)

func close_game_menu() -> void:
	if is_instance_valid(game_menu):
		game_menu.hide()
		game_menu.queue_free()
	game_menu = null

func order_tree_at(pos: Vector2, append := false, notify := true) -> bool:
	var id := prop_at_screen_position(world_to_screen(pos))
	var tree: Dictionary = sim.entity(id)
	if tree.get("kind", "") != "tree":
		for candidate in sim.tree_sites:
			if candidate.hp > 0 and sim.is_visible(sim.point(candidate)) and sim.point(candidate).distance_to(pos) < 0.75:
				tree = candidate
				break
	if tree.get("kind", "") != "tree" or tree.hp <= 0:
		if notify: sim.message = "点击视野内尚未砍伐的树木。"
		return false
	if selected.is_empty():
		selected_prop = int(tree.id)
		if notify: sim.message = "已选中树木；按 T 派遣空闲部队，或先选士兵再右键伐木。"
		return true
	sim.command(selected,"chop",sim.point(tree),int(tree.id),append)
	return true

func dispatch_lumberjack(tree_id: int) -> void:
	var tree: Dictionary = sim.entity(tree_id)
	if tree.get("kind", "") != "tree" or tree.hp <= 0:
		sim.message = "先选中一棵尚未砍伐的树木。"
		return
	var workers: Array = sim.idle_units().filter(func(u): return sim.reachable_goal(sim.point(u),sim.point(tree)) != Vector2i(-1,-1))
	workers.sort_custom(func(a,b): return sim.point(a).distance_squared_to(sim.point(tree)) < sim.point(b).distance_squared_to(sim.point(tree)))
	if workers.is_empty():
		sim.message = "附近没有可用的空闲部队；先选择士兵，再右键树木伐木。"
		return
	sim.command([workers[0].id],"chop",sim.point(tree),int(tree.id))
	sim.message = "已派遣空闲部队伐木，完成后获得 %d 木材。" % Rules.TREE_WOOD
