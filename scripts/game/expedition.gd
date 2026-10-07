extends Node2D

const Simulation = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
const Session = preload("res://scripts/autoload/session.gd")
const Saves = preload("res://scripts/autoload/save_manager.gd")
const UI = preload("res://scripts/ui/pixel_ui.gd")
const FONT = preload("res://assets/fonts/unifont.otf")
const Art = preload("res://scripts/data/tiny_swords_art.gd")
const CELL := 21.0
const ORIGIN := Vector2(22, 89)
const MAP_RECT := Rect2(22, 89, 840, 525)
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
var header: Label
var objective: Label
var status: Label
var details: Label
var roster: VBoxContainer
var overlay: Panel
var pause_button: Button
var train_buttons: Dictionary = {}
var tech_button: Button
var tier_button: Button
var wave_button: Button
@onready var tile_map: Node2D = $Battlefield/FogLakeTileMap

func _ready() -> void:
	sim.configure_terrain(tile_map.terrain_water_cells())
	build_ui()
	if Session.pending_load_slot >= 0:
		var slot: int = Session.pending_load_slot
		Session.pending_load_slot = -1
		if not sim.restore(Saves.read_slot(slot)):
			sim.message = "存档不属于新版远征，未覆盖原文件。请返回菜单选择新的游戏。"
	last_phase = sim.phase
	show_phase_overlay()
	refresh_ui()
	tile_map.sync(sim, 0.0, paused)

func _process(delta: float) -> void:
	if not paused:
		accumulator += minf(delta, 0.2)
		while accumulator >= 0.05:
			sim.step(0.05)
			accumulator -= 0.05
	if sim.phase != last_phase:
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
	tile_map.sync(sim, delta, paused or not sim.active())
	queue_redraw()

func screen_point(entity: Dictionary) -> Vector2:
	return ORIGIN + (sim.point(entity) + Vector2(0.5, 0.5)) * CELL

func map_point(pos: Vector2) -> Vector2:
	return ((pos - ORIGIN) / CELL - Vector2(0.5, 0.5)).clamp(Vector2.ZERO, Vector2(39, 24))

func label_at(parent: Node, text: String, pos: Vector2, size: Vector2, font_size := 16) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("daecf0"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	UI.apply_button_theme(b)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func panel_at(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102735")
	style.border_color = Color("386075")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", style)
	layer.add_child(p)
	return p

func build_ui() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	var top := panel_at(Vector2(12, 10), Vector2(1156, 67))
	label_at(top, "雾之湖  /  冰华远征", Vector2(14, 6), Vector2(260, 26), 21)
	header = label_at(top, "", Vector2(278, 7), Vector2(640, 24), 18)
	objective = label_at(top, "", Vector2(14, 36), Vector2(930, 22), 15)
	pause_button = button_at(top, "暂停 P", Vector2(940, 13), Vector2(95, 38), toggle_pause)
	button_at(top, "菜单", Vector2(1040, 13), Vector2(96, 38), return_menu)
	var side := panel_at(Vector2(876, 89), Vector2(292, 525))
	label_at(side, "部队与科技", Vector2(14, 10), Vector2(260, 26), 21)
	tech_button = button_at(side, "科技 II · 240", Vector2(12, 44), Vector2(130, 32), func():
		if not paused: sim.research("tech"))
	tier_button = button_at(side, "层级提升 · 180", Vector2(149, 44), Vector2(130, 32), func():
		if not paused: sim.research("tier"))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 85)
	scroll.size = Vector2(268, 189)
	side.add_child(scroll)
	roster = VBoxContainer.new()
	roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(roster)
	for kind in sim.catalog:
		var d: Dictionary = sim.catalog[kind]
		var b := button_at(roster, "%s · %d 金 / %d 容量" % [d.name, d.cost, d.capacity], Vector2.ZERO, Vector2(248, 32), train.bind(kind))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon = Art.portrait(kind)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 24)
		b.tooltip_text = "%s\n生命 %d | 攻击 %d | 射程 %s\n攻速 %s 次/秒 | 移速 %s 格/秒\n暴击 %.0f%% ×%.1f | 科技 %d / 层级 %d\n%s" % [d.name, d.hp, d.attack, str(d.range), str(d.attack_speed), str(d.move_speed), d.crit_chance * 100, d.crit_multiplier, d.tech, d.tier, d.skill]
		train_buttons[kind] = b
	label_at(side, "选择单位后建造", Vector2(14, 280), Vector2(260, 20), 15)
	button_at(side, "兵营 160", Vector2(12, 305), Vector2(84, 32), set_mode.bind("barracks"))
	button_at(side, "魔井 200", Vector2(103, 305), Vector2(84, 32), set_mode.bind("well"))
	button_at(side, "房屋 120", Vector2(194, 305), Vector2(84, 32), set_mode.bind("house"))
	label_at(side, "BAKA 魔法  ·  点击地图施放", Vector2(14, 345), Vector2(266, 20), 15)
	button_at(side, "Q 冰冻 20", Vector2(12, 370), Vector2(84, 32), set_mode.bind("freeze"))
	button_at(side, "W 冰墙 25", Vector2(103, 370), Vector2(84, 32), set_mode.bind("wall"))
	button_at(side, "E 冰桥 20", Vector2(194, 370), Vector2(84, 32), set_mode.bind("bridge"))
	button_at(side, "全选 A", Vector2(12, 413), Vector2(84, 32), select_all)
	button_at(side, "驻军撤出", Vector2(103, 413), Vector2(84, 32), evacuate_selected)
	button_at(side, "存档 F5", Vector2(194, 413), Vector2(84, 32), save_progress.bind(true))
	wave_button = button_at(side, "提前迎敌  ·  Space", Vector2(12, 459), Vector2(266, 36), func():
		if not paused: sim.start_wave())
	var bottom := panel_at(Vector2(12, 623), Vector2(1156, 30))
	status = label_at(bottom, "", Vector2(10, 3), Vector2(1140, 25), 15)
	details = label_at(layer, "", Vector2(29, 95), Vector2(820, 70), 14)
	details.add_theme_color_override("font_shadow_color", Color.BLACK)
	details.add_theme_constant_override("shadow_offset_x", 1)
	details.add_theme_constant_override("shadow_offset_y", 1)

func refresh_ui() -> void:
	header.text = "金币 %d    BAKA %d    容量 %d / %d    科技 %d · 层级 %d" % [sim.gold, sim.baka, sim.used_capacity(), sim.capacity(), sim.tech, sim.tier]
	var phase_names := {"cards": "开局选牌", "base": "选择基地", "prep": "部署探索", "defense": "抵御进攻", "cleanup": "清剿敌军", "victory": "远征胜利", "defeat": "远征失败"}
	objective.text = "远征 %d  ·  %s  ·  波次 %d/%d  ·  %.0f 秒   |   左键框选 · 右键下令 · A 全选 · Esc 取消" % [sim.campaign, phase_names[sim.phase], sim.wave, Rules.WAVE_COUNT, maxf(0, sim.timer)]
	if sim.phase == "cleanup": objective.text = "清剿敌军与据点  ·  敌军 %d  ·  野怪 %d  |  红色敌军 · 琥珀色野怪 · 右键建筑进攻" % [sim.living(1).size(), sim.living(2).size()]
	status.text = ("已暂停  |  " if paused else "") + sim.message
	pause_button.text = "继续 P" if paused else "暂停 P"
	tech_button.disabled = not sim.active() or sim.tech >= 2 or sim.gold < Rules.TECH_COST
	tier_button.disabled = not sim.active() or sim.tier >= 3 or sim.gold < Rules.TIER_COST
	wave_button.disabled = not sim.active() or sim.wave >= Rules.WAVE_COUNT
	for kind in train_buttons:
		var d: Dictionary = sim.catalog[kind]
		train_buttons[kind].disabled = not sim.active() or sim.gold < d.cost or sim.tech < d.tech or sim.tier < d.tier or sim.used_capacity() + d.capacity > sim.capacity()
	details.text = ""
	var b: Dictionary = sim.entity(selected_building)
	if not b.is_empty() and b.has("complete"):
		details.text = "%s  %.0f / %.0f HP  驻军 %d/%d  %s\n训练队列 %d  |  右键：修复未满血建筑 / 进驻完好建筑" % [Rules.BUILDINGS[b.kind].name, b.hp, b.max_hp, sim.occupants(selected_building).size(), Rules.BUILDINGS[b.kind].beds, "完工" if b.complete else "建造中", b.queue.size()]
	elif selected.size() == 1:
		var u: Dictionary = sim.entity(int(selected[0]))
		if not u.is_empty(): details.text = "%s  %.0f / %.0f HP  战功 %d / %d  晋升 %d/2\n%s" % [sim.catalog[u.kind].name, u.hp, u.max_hp, u.kill_value, sim.catalog[u.kind].cost * 3, u.rank, sim.catalog[u.kind].skill]
	elif selected.size() > 1: details.text = "已选中 %d 名部队  |  右键移动、攻击、驻军、修复或寻宝" % selected.size()

func show_phase_overlay() -> void:
	if is_instance_valid(overlay): overlay.queue_free()
	if sim.phase == "cards":
		overlay = panel_at(Vector2(112, 168), Vector2(680, 365))
		label_at(overlay, "远征准备  ·  五选二", Vector2(26, 20), Vector2(620, 32), 26)
		label_at(overlay, "选择 2 张效果牌，构筑你的开局。", Vector2(26, 60), Vector2(620, 26), 17)
		for i in Rules.CARDS.size():
			var c: Dictionary = Rules.CARDS[i]
			var b := button_at(overlay, "%s   %s" % [c.name, c.text], Vector2(26, 99 + i * 48), Vector2(628, 40), pick_card.bind(c.id))
			b.disabled = sim.cards.has(c.id)
	elif sim.phase in ["victory", "defeat"]:
		overlay = panel_at(Vector2(212, 222), Vector2(500, 220))
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

func train(kind: String) -> void:
	if paused: return
	var b: Dictionary = sim.entity(selected_building)
	sim.train_unit(kind, selected_building if not b.is_empty() and b.team == 0 and b.kind in ["base", "barracks"] else -1)

func set_mode(value: String) -> void:
	if not sim.active() or paused: return
	mode = value
	var names := {"barracks": "兵营", "well": "魔力井", "house": "房屋", "freeze": "冰冻", "wall": "冰墙", "bridge": "冰桥"}
	sim.message = "点击地图放置%s，Esc 或右键取消。" % names[value]

func select_all() -> void:
	selected.clear()
	selected_building = -1
	for u in sim.living(0):
		if u.home == -1: selected.append(u.id)

func evacuate_selected() -> void:
	if paused or not sim.active(): return
	var b: Dictionary = sim.entity(selected_building)
	if not b.is_empty() and b.team == 0: sim.evacuate(selected_building)

func toggle_pause() -> void:
	paused = not paused

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
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P: toggle_pause()
			KEY_ESCAPE:
				mode = "select"
				selected.clear()
				selected_building = -1
			KEY_A: select_all()
			KEY_Q: set_mode("freeze")
			KEY_W: set_mode("wall")
			KEY_E: set_mode("bridge")
			KEY_F5: save_progress(true)
			KEY_SPACE:
				if not paused: sim.start_wave()
	if event is InputEventMouseMotion:
		hover = event.position
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
			dragging = false
			select_area(drag_start, event.position)
			return
		if not MAP_RECT.has_point(event.position) or paused: return
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

func building_hit(building: Dictionary, pos: Vector2) -> bool:
	if sim.point(building).distance_to(pos) < 1.3: return true
	var view: Sprite2D = tile_map.building_views.get(int(building.id))
	if not is_instance_valid(view): return false
	var screen := ORIGIN + (pos + Vector2(0.5, 0.5)) * CELL
	var local_point := view.to_local(screen)
	return view.get_rect().has_point(local_point) and view.is_pixel_opaque(local_point)

func _draw() -> void:
	for c in sim.chests:
		var p := screen_point(c)
		draw_arc(p, 10, 0, TAU, 20, Color(1, 0.88, 0.42, 0.65), 1)
	for b in sim.buildings: draw_building(b)
	for u in sim.units:
		if u.home == -1: draw_unit(u)
	for s in sim.shots:
		var start := screen_point(s) + Vector2(0, -13)
		var finish := ORIGIN + (Vector2(s.tx, s.ty) + Vector2(0.5, 0.5)) * CELL + Vector2(0, -10)
		if s.get("ranged", false):
			var arrow := Art.texture("Factions/Knights/Troops/Archer/Arrow/Arrow.png")
			var position_on_line := start.lerp(finish, 1.0 - float(s.ttl) / 0.15)
			draw_set_transform(position_on_line, (finish - start).angle(), Vector2.ONE * 0.33)
			draw_texture(arrow, -arrow.get_size() / 2.0)
			draw_set_transform(Vector2.ZERO)
	if sim.phase == "base":
		for i in Simulation.BASE_SITES.size():
			var pos: Vector2 = ORIGIN + (Simulation.BASE_SITES[i] + Vector2(0.5, 0.5)) * CELL
			draw_circle(pos, 27, Color(0.5, 0.85, 0.9, 0.18))
			draw_arc(pos, 27, 0, TAU, 32, BLUE, 2)
			draw_string(FONT, pos + Vector2(-29, -35), ["北岸营地", "湖心前哨", "南岸营地"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	if dragging:
		var rect := Rect2(drag_start, hover - drag_start).abs()
		draw_rect(rect, Color(0.5, 0.9, 1, 0.12))
		draw_rect(rect, BLUE, false, 1)
	if mode != "select" and MAP_RECT.has_point(hover):
		draw_arc(hover, 3 * CELL if mode == "freeze" else CELL, 0, TAU, 32, BLUE, 2)
	draw_rect(MAP_RECT, Color("476c78"), false, 2)

func team_color(team: int) -> Color:
	return BLUE if team == 0 else (RED if team == 1 else (GOLD if team == 2 else Color("b0bbb2")))

func draw_building(b: Dictionary) -> void:
	var pos := screen_point(b)
	var color := team_color(int(b.team))
	if selected_building == b.id: draw_arc(pos, 24, 0, TAU, 32, GOLD, 2)
	health_bar(pos + Vector2(-21, 7), 42, float(b.hp) / float(b.max_hp), color)
	var text := str(Rules.BUILDINGS[b.kind].name)
	if not b.complete: text = "建造 %.0f%%" % (b.hp / b.max_hp * 100)
	var count := sim.occupants(int(b.id)).size()
	if count > 0: text += " [%d]" % count
	draw_string(FONT, pos + Vector2(-27, 23), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("142c35"))
	draw_string(FONT, pos + Vector2(-28, 22), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func draw_unit(u: Dictionary) -> void:
	var pos := screen_point(u)
	var color := team_color(int(u.team))
	if selected.has(u.id): draw_arc(pos + Vector2(0, 3), 10, 0, TAU, 20, GOLD, 1.5)
	if u.frozen > 0: draw_circle(pos, 11, Color(0.5, 0.9, 1, 0.4))
	if u.rank > 0: draw_string(FONT, pos + Vector2(-4, -33), "II" if u.rank == 2 else "I", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
	if u.kind not in ["swordsman", "archer"] and u.team != 2:
		var badge := str(sim.catalog[u.kind].name).left(1)
		if u.kind == "cataphract": badge = "骑"
		draw_rect(Rect2(pos + Vector2(8, -24), Vector2(14, 14)), Color("193847"))
		draw_string(FONT, pos + Vector2(9, -12), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	health_bar(pos + Vector2(-9, 7), 18, float(u.hp) / float(u.max_hp), color)

func health_bar(pos: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(width, 3)), Color("10222c"))
	draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0, 1), 3)), color)
