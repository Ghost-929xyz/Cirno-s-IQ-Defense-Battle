extends "res://scripts/game/expedition.gd"

const Training = preload("res://scripts/game/tutorial_simulation.gd")
const LESSONS := [
	["cards", "开局策略", "选择两张效果牌并确认。效果会影响本局军团；教学资源充足，可放心尝试。"],
	["camera", "观察战场", "在地图上滚动滚轮缩放，再按方向键或按住中键拖动视角。"],
	["map", "地图情报", "点击右下角小地图定位；按 Tab 打开并关闭全图，按 H 回基地。黑暗区域需要部队探索。"],
	["select", "选择部队", "左键点击一名士兵，再拖动框选多名士兵。A 可先选同类，再按选全军；Shift＋右键追加友军。"],
	["move", "移动", "选中士兵，右键空地移动。等待部队走到目标附近。"],
	["group", "编队", "选中部队，Ctrl＋1 保存编队，再按 1 召回。双击数字可定位该队；0–9 均可使用。"],
	["queue", "连续命令", "先右键远处空地移动，按住 Shift 再右键另一块空地追加路线。"],
	["stop", "停止与防守", "选中部队按 S 停止，再按 D 原地防守。停止会取消队列，防守只攻击射程内敌人。"],
	["idle", "空闲部队", "按 I 定位空闲部队。若无人空闲，先选部队按 S。左侧兵种卡也可选择同类并定位。"],
	["capture", "资源占领", "点击“定位目标”，选中士兵后右键金矿，等待占领完成。金矿产金币，魔力泉产 BAKA，灵视塔提供视野。"],
	["chest", "探索宝箱", "定位目标，派士兵右键宝箱并走到宝箱旁。宝箱与野怪属于可选探索收益。"],
	["house", "施工与容量", "选中场外士兵，打开底部“建造”，选择房屋，再点击附近空地。等待建成；完工建筑提供容量。"],
	["barracks", "建立兵营", "选中士兵，在“建造”页放置兵营并等待完工。红色预览表示位置不可用；Esc 取消放置。"],
	["rally", "集结点", "左键选择基地或兵营（不要选部队），右键空地设置集结点。Shift 可追加集结路线。"],
	["train", "招募军团", "打开“招募”，点击剑士或弓箭手，等待新兵出场。金币和容量决定能否招募，训练队列也占容量。"],
	["well", "魔力生产", "选中士兵，建造一座魔力井并等待完工。BAKA 用于施放冰霜魔法。"],
	["academy", "科技建筑", "选中士兵，建造科技所并等待完工。科技所开放骑兵、刺客及进阶研究。"],
	["research", "兵种路线", "打开“科技”页，选择一个可研究兵种。部分分支互斥，正式远征中需按战术选择。"],
	["garrison", "驻军", "定位房屋，选中剑士或弓箭手，按 G 后点击房屋并等待进入。也可右键完好的友方或中立建筑。"],
	["evacuate", "撤出驻军", "左键选择刚才驻军的建筑，点击指挥栏“撤出”按钮。驻军离开后可继续移动和施工。"],
	["repair", "修复建筑", "教学已让基地受到轻微损伤。定位基地，选中场外士兵，按 R 后点击基地，等待修复完成。"],
	["freeze", "冰冻魔法", "定位训练靶，按 Q，再点击靶子施放冰冻。命中后会暂时阻止敌人行动。"],
	["wall", "冰墙魔法", "按 W，再点击无单位、无建筑的陆地空地，生成临时冰墙。冰墙可以阻挡通路。"],
	["bridge", "冰桥魔法", "定位河面，按 E 点击水面，生成永久冰桥。陆地无法施放，冰桥可开辟新的路线。"],
	["cancel", "取消与暂停", "按 Q 进入施法模式，再按 Esc 取消；按 P 暂停，再按 P 恢复。暂停时可查看战场。"],
	["attack_move", "攻击移动", "选中军团，按 F 后点击空地。部队会边走边迎战；右键敌人则集中攻击指定目标。"],
	["battle", "防守与清剿", "按 Space 迎敌。选部队右键敌军集中攻击，消灭三名训练敌人并摧毁训练据点。可结合编队、防守和魔法。"],
	["chop", "伐木与木材", "定位高亮树木，选中部队后右键伐木。也可先选树木，再按 T 派遣空闲部队。完成后获得 20 木材，树桩可通行。"],
	["campfire", "布置火堆", "选中场外部队，按 C 或在建造页选择火堆，再点击可用陆地。消耗 20 木材，部队抵达后生火；点燃后照亮周边迷雾。"],
	["save", "保存与完成", "按 F5 保存教学进度，再点击“读取教学存档”验证恢复。此存档独立于正式远征的三个槽位。"]
]
var lesson := 0
var seen: Dictionary = {}
var checkpoint: Dictionary = {}
var lesson_panel: Panel
var lesson_text: Label
var next_button: Button
var target_marker: Label
var target_pos := Vector2(40, 25)
var move_origin := Vector2.ZERO
var moving_unit := -1
var starting_army := 0
var finished := false
var old_slot := -1
var lesson_body: Control
var lesson_header: Label
var fold_button: Button
var lesson_folded := false
var panel_dragging := false
var panel_drag_offset := Vector2.ZERO

func _init() -> void:
	sim = Training.new()
	random_map_enabled = false

func _ready() -> void:
	old_slot = Session.current_slot
	Session.current_slot = -1
	Session.pending_load_slot = -1
	super._ready()
	lesson_panel = panel_at(Vector2(735, 65), Vector2(430, 249))
	var handle := Control.new()
	handle.name = "TutorialDragHandle"
	handle.size = Vector2(385, 34)
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			panel_dragging = true
			panel_drag_offset = get_viewport().get_mouse_position() - lesson_panel.position
			dragging = false
			panning = false)
	lesson_panel.add_child(handle)
	lesson_header = label_at(handle, "教学提示 · 拖动标题栏", Vector2(12, 5), Vector2(365, 25), 15)
	lesson_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fold_button = button_at(lesson_panel, "▲", Vector2(390, 3), Vector2(32, 28), toggle_lesson_panel)
	fold_button.tooltip_text = "向上收起 / 展开教学提示；拖动标题栏调整位置"
	lesson_body = Control.new()
	lesson_body.position = Vector2(0, 34)
	lesson_body.size = Vector2(430, 215)
	lesson_body.mouse_filter = Control.MOUSE_FILTER_PASS
	lesson_panel.add_child(lesson_body)
	lesson_text = label_at(lesson_body, "", Vector2(12, 10), Vector2(406, 130), 17)
	lesson_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_button = button_at(lesson_body, "下一步", Vector2(298, 170), Vector2(120, 32), next_lesson)
	button_at(lesson_body, "定位目标", Vector2(12, 170), Vector2(100, 32), func(): center_camera(target_pos))
	button_at(lesson_body, "重试本步", Vector2(120, 170), Vector2(100, 32), retry_lesson)
	button_at(lesson_body, "读取教学存档", Vector2(12, 137), Vector2(180, 28), load_training)
	target_marker = label_at(layer, "◎ 教学目标", Vector2.ZERO, Vector2(140, 30), 20)
	target_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enter_lesson()

func _exit_tree() -> void:
	Session.current_slot = old_slot

func toggle_lesson_panel() -> void:
	lesson_folded = not lesson_folded
	lesson_body.visible = not lesson_folded
	lesson_panel.size.y = 34 if lesson_folded else 249
	fold_button.text = "▼" if lesson_folded else "▲"
	clamp_lesson_panel()

func clamp_lesson_panel() -> void:
	lesson_panel.position = lesson_panel.position.clamp(Vector2.ZERO, (get_viewport_rect().size - lesson_panel.size).max(Vector2.ZERO))

func _input(event: InputEvent) -> void:
	super._input(event)
	if not panel_dragging: return
	if event is InputEventMouseMotion:
		lesson_panel.position = event.position - panel_drag_offset
		clamp_lesson_panel()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		panel_dragging = false
		get_viewport().set_input_as_handled()

func enter_lesson() -> void:
	seen.clear()
	sim.actions.clear()
	paused = false
	tactical_overlay.hide()
	mode = "select"
	starting_army = sim.living(0).size()
	var key: String = LESSONS[lesson][0]
	target_pos = Vector2(40, 25)
	if key == "capture": target_pos = sim.point(sim.resource_sites[0])
	if key == "chest" and not sim.chests.is_empty(): target_pos = sim.point(sim.chests[0])
	if key in ["garrison", "evacuate"]:
		for b in sim.buildings:
			if b.kind == "house":
				target_pos = sim.point(b)
				break
	if key == "repair":
		for b in sim.buildings:
			if b.kind == "base":
				b.hp = b.max_hp - 30
				target_pos = sim.point(b)
	if key == "chop":
		var available: Array = sim.tree_sites.filter(func(tree): return tree.hp > 0)
		available.sort_custom(func(a,b): return sim.point(a).distance_squared_to(Vector2(40,25)) < sim.point(b).distance_squared_to(Vector2(40,25)))
		if not available.is_empty():
			sim.training_tree_id = int(available[0].id)
			target_pos = sim.point(available[0])
	if key == "campfire": sim.wood = maxi(sim.wood, Rules.CAMPFIRE_WOOD)
	if key == "freeze":
		sim.units = sim.units.filter(func(u): return u.team == 0)
		target_pos = sim.safe_cell(Vector2(49, 20))
		var dummy: Dictionary = sim.add_unit("swordsman", 1, target_pos)
		dummy.hp = 10000.0
		dummy.max_hp = 10000.0
		dummy.attack = 0.0
		dummy.order = "hold"
		sim.reveal_circle(target_pos, 4)
	if key == "wall": sim.units = sim.units.filter(func(u): return u.team == 0)
	if key == "bridge":
		var nearest := INF
		for cell in tile_map.terrain_water_cells():
			var distance: float = Vector2(cell).distance_to(Vector2(40, 25))
			if distance < nearest and not sim.bridges.has([cell.x, cell.y]):
				nearest = distance
				target_pos = Vector2(cell)
	sim.battle_allowed = key == "battle"
	checkpoint = sim.snapshot().duplicate(true)
	lesson_text.text = "教学 %d / %d · %s\n%s" % [lesson + 1, LESSONS.size(), LESSONS[lesson][1], LESSONS[lesson][2]]
	next_button.disabled = true

func retry_lesson() -> void:
	sim.restore(checkpoint.duplicate(true))
	control_groups = sim.control_groups
	pending_cards.clear()
	selected.clear()
	selected_building = -1
	wave_intro.active = false
	wave_intro.hide()
	enter_lesson()
	show_phase_overlay()
	refresh_ui()

func next_lesson() -> void:
	if finished:
		return_menu()
		return
	if not completed(): return
	lesson += 1
	if lesson == LESSONS.size():
		finished = true
		paused = true
		target_marker.hide()
		lesson_text.text = "训练完成！\n你已掌握核心操作。正式远征需要防守六波进攻，再清剿敌军与据点。基地和所有己方建筑均被摧毁才会失败。\n返回主菜单，选择“新的游戏”开始远征。"
		next_button.text = "返回菜单"
	else: enter_lesson()

func _process(delta: float) -> void:
	super._process(delta)
	if lesson_panel == null or finished: return
	target_marker.position = world_to_screen(target_pos) + Vector2(-30, -45)
	target_marker.visible = LESSONS[lesson][0] in ["capture", "chest", "garrison", "evacuate", "repair", "freeze", "bridge", "chop"]
	next_button.disabled = not completed()
	next_button.text = "完成 · 下一步" if not next_button.disabled else "等待操作"
	lesson_header.text = "%s 教学 %d/%d · %s" % ["✓" if not next_button.disabled else "≡", lesson + 1, LESSONS.size(), LESSONS[lesson][1]]

func completed() -> bool:
	var key: String = LESSONS[lesson][0]
	match key:
		"cards": return sim.cards.size() == 2
		"camera": return seen.has("zoom") and seen.has("pan")
		"map": return seen.has("minimap") and seen.has("overview") and seen.has("home") and not tactical_overlay.visible
		"select": return seen.has("single") and seen.has("box")
		"move":
			var unit: Dictionary = sim.entity(moving_unit)
			return sim.actions.has("move") and not unit.is_empty() and sim.point(unit).distance_to(move_origin) > 2
		"group": return seen.has("assign") and seen.has("recall")
		"stop": return sim.actions.has("stop") and sim.actions.has("hold")
		"idle": return seen.has("idle")
		"capture": return sim.resource_sites.any(func(s): return s.team == 0)
		"chest": return sim.chests.is_empty()
		"chop":
			var tree: Dictionary = sim.entity(sim.training_tree_id)
			return not tree.is_empty() and tree.hp <= 0
		"campfire": return sim.campfires.any(func(fire): return fire.complete)
		"house", "barracks", "well", "academy": return sim.buildings.any(func(b): return b.team == 0 and b.kind == key and b.complete)
		"train": return sim.actions.has("train") and sim.living(0).size() > starting_army
		"garrison": return sim.living(0).any(func(u): return u.home != -1)
		"repair": return sim.actions.has("repair") and sim.buildings.any(func(b): return b.kind == "base" and b.hp >= b.max_hp)
		"cancel": return seen.has("cancel") and seen.has("pause") and not paused
		"battle": return sim.wave > 0 and sim.living(1).is_empty() and not sim.buildings.any(func(b): return b.team == 1) and sim.actions.has("attack")
		"save": return seen.has("save") and seen.has("load")
	return sim.actions.has(key)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not selected.is_empty():
		moving_unit = int(selected[0])
		move_origin = sim.point(sim.entity(int(selected[0])))
	if event is InputEventMouseMotion and panning: seen["pan"] = true
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]: seen["pan"] = true
		if event.keycode == KEY_ESCAPE and mode != "select": seen["cancel"] = true
	super._unhandled_input(event)

func zoom_at(pos: Vector2, factor: float) -> void:
	super.zoom_at(pos, factor)
	seen["zoom"] = true

func center_camera(pos: Vector2) -> void:
	super.center_camera(pos)
	if minimap != null and minimap.get_global_rect().has_point(get_viewport().get_mouse_position()): seen["minimap"] = true

func toggle_overview() -> void:
	super.toggle_overview()
	seen["overview"] = true

func focus_home() -> void:
	super.focus_home()
	seen["home"] = true

func select_area(start: Vector2, end: Vector2) -> void:
	super.select_area(start, end)
	if start.distance_to(end) < 7 and selected.size() == 1: seen["single"] = true
	if start.distance_to(end) >= 7 and selected.size() >= 2: seen["box"] = true

func assign_control_group(digit: int) -> void:
	super.assign_control_group(digit)
	if not control_groups.get(digit, []).is_empty(): seen["assign"] = true

func select_control_group(digit: int) -> void:
	super.select_control_group(digit)
	if not selected.is_empty(): seen["recall"] = true

func select_idle_unit() -> void:
	super.select_idle_unit()
	if not selected.is_empty(): seen["idle"] = true

func toggle_pause() -> void:
	super.toggle_pause()
	if paused: seen["pause"] = true

func save_progress(notify: bool) -> void:
	if not notify: return
	var file := FileAccess.open("user://tutorial_progress.json", FileAccess.WRITE)
	if file == null:
		sim.message = "教学存档写入失败，请检查磁盘。"
		return
	file.store_string(JSON.stringify({"lesson": lesson, "lesson_key": LESSONS[lesson][0], "simulation": sim.snapshot()}))
	file.close()
	seen["save"] = true
	sim.message = "教学进度已保存，不占用远征存档槽。"

func load_training() -> void:
	if not FileAccess.file_exists("user://tutorial_progress.json"): return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://tutorial_progress.json"))
	if not data is Dictionary or not data.has("simulation"): return
	if not sim.restore(data.simulation): return
	lesson = clampi(int(data.get("lesson", 0)), 0, LESSONS.size() - 1)
	var saved_key := str(data.get("lesson_key", "save" if lesson == 27 and not data.simulation.has("wood") else ""))
	for i in LESSONS.size():
		if LESSONS[i][0] == saved_key: lesson = i; break
	finished = false
	enter_lesson()
	seen["save"] = true
	seen["load"] = true
	selected.clear()
	selected_building = -1
	show_phase_overlay()
	refresh_ui()

func show_phase_overlay() -> void:
	super.show_phase_overlay()
	if sim.phase == "cards" and is_instance_valid(overlay): overlay.position.x = 20

func refresh_ui() -> void:
	super.refresh_ui()
	objective.text = "新手训练场  /  资源补给充足  /  无自动来袭  /  正式存档独立"
