class_name FogLakeLevel
extends Node2D

const Metrics = preload("res://scripts/game/game_metrics.gd")

const TowerScript = preload("res://scripts/entities/tower.gd")
const BarracksScript = preload("res://scripts/entities/barracks.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const AllyScript = preload("res://scripts/entities/ally_unit.gd")
const HeroScript = preload("res://scripts/entities/hero.gd")
const HitEffectScript = preload("res://scripts/effects/hit_effect.gd")
const EnchantDropScript = preload("res://scripts/entities/drop.gd")
const TutorialOverlayScript = preload("res://scripts/ui/tutorial_overlay.gd")
const SessionScript = preload("res://scripts/autoload/session.gd")

const FROST_START := 180.0
const WAVE_FROST_REWARD_BASE := 16.0
const WAVE_FROST_REWARD_STEP := 4.0

## 新地图需求：兵营 2×2 格，共 4 格。
const BARRACKS_FOOTPRINT := [
	Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(1, 1),
]
## 新地图需求：防御塔 3×3 格，共 9 格。
const TOWER_FOOTPRINT := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

enum Phase {
	PREP,
	COMBAT,
	## 需求 5：波末结算。
	SETTLEMENT,
	UPGRADE,
	ENCHANT,
	FINISHED,
}

@onready var map_view: LakeMapView = $World/MapView
@onready var world: Node2D = $World
@onready var towers: Node2D = $World/Towers
@onready var barracks_container: Node2D = $World/Barracks
@onready var allies: Node2D = $World/Allies
@onready var hero_container: Node2D = $World/Hero
@onready var enemies: Node2D = $World/Enemies
@onready var projectiles: Node2D = $World/Projectiles
@onready var effects: Node2D = $World/Effects
@onready var drops: Node2D = $World/Drops
@onready var hud: BattleHUD = $HUD

var phase := Phase.PREP
var frost := FROST_START
var ice_crystals := 0
var wave_index := -1
var kill_count := 0
var total_kills := 0

var _wave_manager: WaveManager
var _upgrade_manager: UpgradeManager
var _hero: CirnoHero
var _tutorial: CanvasLayer
var _selected_build_id := "icicle"
var _selected_structure: DefenseStructure
var _structure_cells: Dictionary = {}
var _selected_nodes: Array[Node2D] = []
var _status_text := "右键移动琪露诺；左键建造或框选；WASD/中键平移镜头，滚轮缩放。"
var _enchant_open := false
var _unclaimed_enchant_drops := 0
var _pending_wave_finished_index := -1
var _pending_wave_reward_index := -1

var _drag_start_screen := Vector2.ZERO
var _drag_start_world := Vector2.ZERO
var _is_dragging := false
const _DRAG_THRESHOLD := 6.0

## 大地图镜头：WASD/方向键/中键拖拽平移，滚轮缩放，小地图点击跳转。
const CAMERA_PAN_SPEED := 760.0
const CAMERA_MAX_ZOOM := 2.5
const CAMERA_ZOOM_MARGIN := 0.95

var _camera: Camera2D
var _camera_dragging := false


func _ready() -> void:
	add_to_group("game")
	_wave_manager = WaveManager.new()
	add_child(_wave_manager)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_finished.connect(_on_wave_finished)
	_wave_manager.spawn_requested.connect(_on_spawn_requested)

	_upgrade_manager = UpgradeManager.new()
	hud.build_item_selected.connect(_on_build_item_selected)
	hud.start_wave_requested.connect(_on_start_wave_requested)
	hud.upgrade_structure_requested.connect(_on_upgrade_structure_requested)
	hud.modifier_card_selected.connect(_on_modifier_card_selected)
	hud.hero_skill_requested.connect(_on_hero_skill_requested)
	hud.restart_requested.connect(_on_restart_requested)
	hud.menu_requested.connect(_on_menu_requested)
	hud.settlement_continue_requested.connect(_on_settlement_continue_requested)

	_setup_camera()
	_setup_tutorial()
	_spawn_hero()
	map_view.set_build_validator(can_build_at)
	map_view.set_build_preview(_selected_build_id)
	hud.select_build_item(_selected_build_id)
	hud.setup_minimap(self)
	_refresh_hud()


func _setup_tutorial() -> void:
	if SessionScript.tutorial_done:
		return
	_tutorial = TutorialOverlayScript.new()
	_tutorial.name = "TutorialOverlay"
	add_child(_tutorial)
	_tutorial.finished.connect(_on_tutorial_done)
	_tutorial.skipped.connect(_on_tutorial_done)


func _on_tutorial_done() -> void:
	SessionScript.tutorial_done = true


func _process(delta: float) -> void:
	if phase == Phase.PREP:
		if is_instance_valid(_hero):
			_hero.regen(delta)
	_update_camera(delta)
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _tutorial != null and _tutorial.has_method("is_blocking") and _tutorial.call("is_blocking"):
		return

	if event is InputEventMouseMotion:
		if _camera_dragging:
			_camera.position -= event.relative / _camera.zoom.x
			return
		if _is_dragging:
			var end_world := get_global_mouse_position()
			map_view.set_selection_rect(Rect2(_drag_start_world, Vector2.ZERO).expand(end_world))
		else:
			map_view.set_hover_cell(map_view.world_to_cell(get_global_mouse_position()))
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_camera(1.12)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_camera(1.0 / 1.12)
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_camera_dragging = event.pressed
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_left_drag()
			else:
				_end_left_drag()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(get_global_mouse_position())
			return
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_clear_selection()
		elif event.keycode == KEY_SPACE:
			_on_start_wave_requested()
		elif event.keycode == KEY_Q:
			_on_hero_skill_requested("nova")
		elif event.keycode == KEY_R:
			_on_hero_skill_requested("freeze")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var index := int(event.keycode - KEY_1)
			if index >= 0 and index < BuildCatalog.ORDER.size():
				_on_build_item_selected(str(BuildCatalog.ORDER[index]))


## 创建并居中战斗镜头；限制在棋盘范围内。
func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "BattleCamera"
	add_child(_camera)
	var board := map_view.BOARD_SIZE
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(board.x)
	_camera.limit_bottom = int(board.y)
	_camera.position = map_view.get_hero_spawn_world_position()
	_camera.make_current()


## 小地图点击/拖拽跳转镜头。
func move_camera_to(world_position: Vector2) -> void:
	if _camera == null:
		return
	_camera.position = world_position


func _update_camera(delta: float) -> void:
	if _camera == null:
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction != Vector2.ZERO:
		_camera.position += direction.normalized() * CAMERA_PAN_SPEED * delta / _camera.zoom.x


## 能完整看到整张地图的最小缩放。
func _min_camera_zoom() -> float:
	var board := map_view.BOARD_SIZE
	var viewport_size := get_viewport_rect().size
	return minf(viewport_size.x / board.x, viewport_size.y / board.y) * CAMERA_ZOOM_MARGIN


## 以鼠标位置为锚点缩放镜头。
func _zoom_camera(factor: float) -> void:
	if _camera == null:
		return
	var old_zoom := _camera.zoom.x
	var new_zoom := clampf(old_zoom * factor, _min_camera_zoom(), CAMERA_MAX_ZOOM)
	if is_equal_approx(new_zoom, old_zoom):
		return
	var viewport_size := get_viewport_rect().size
	var screen := get_viewport().get_mouse_position()
	var world_before := _camera.position + (screen - viewport_size * 0.5) / old_zoom
	_camera.zoom = Vector2(new_zoom, new_zoom)
	_camera.position = world_before - (screen - viewport_size * 0.5) / new_zoom


func add_projectile(projectile: Node2D) -> void:
	projectiles.add_child(projectile)


func spawn_hit_effect(world_position: Vector2, color: Color, radius: float) -> void:
	var effect: HitEffect = HitEffectScript.new()
	effects.add_child(effect)
	effect.global_position = world_position
	effect.setup(color, radius)


func can_barracks_spawn() -> bool:
	return phase == Phase.COMBAT


func is_combat() -> bool:
	return phase == Phase.COMBAT


func get_cell_size() -> float:
	return map_view.CELL_SIZE


func get_ally_modifiers() -> Dictionary:
	return _upgrade_manager.modifiers


func get_hero_modifiers() -> Dictionary:
	return _upgrade_manager.modifiers


func spawn_ally(barracks: FairyBarracks, unit_id: String) -> AllyUnit:
	var definition := AllyCatalog.get_definition(unit_id)
	if definition.is_empty():
		return null
	var unit: AllyUnit = AllyScript.new()
	allies.add_child(unit)
	var spawn_position := _get_unit_spawn_position(barracks.global_position)
	unit.setup(self, definition, spawn_position)
	unit.set_home(barracks)
	return unit


func _spawn_hero() -> void:
	_hero = HeroScript.new()
	hero_container.add_child(_hero)
	_hero.setup(self, map_view.get_play_rect())
	_hero.global_position = map_view.get_hero_spawn_world_position()
	_hero.defeated.connect(_on_hero_defeated)


func get_hero_hp() -> int:
	if not is_instance_valid(_hero):
		return 0
	return int(ceil(_hero.get_hp()))


func get_hero_max_hp() -> int:
	if not is_instance_valid(_hero):
		return 0
	return int(round(_hero.get_max_hp()))


func _begin_left_drag() -> void:
	_drag_start_screen = get_viewport().get_mouse_position()
	_drag_start_world = get_global_mouse_position()
	_is_dragging = true
	map_view.clear_selection_rect()


func _end_left_drag() -> void:
	_is_dragging = false
	map_view.clear_selection_rect()
	var end_world := get_global_mouse_position()
	var drag_distance := get_viewport().get_mouse_position().distance_to(_drag_start_screen)
	if drag_distance >= _DRAG_THRESHOLD:
		_select_objects_in_rect(Rect2(_drag_start_world, Vector2.ZERO).expand(end_world))
	else:
		_handle_left_click(end_world)


func _handle_left_click(world_position: Vector2) -> void:
	# 需求 8：优先拾取掉落物
	if _pick_up_drop(world_position):
		return

	var cell := map_view.world_to_cell(world_position)
	var existing := _find_structure_at(cell)
	if existing != null:
		_set_selection([existing])
		return

	var unit := _find_ally_at(world_position)
	if unit != null:
		_set_selection([unit])
		return
	if is_instance_valid(_hero) and _hero.is_alive() and world_position.distance_to(_hero.global_position) <= Metrics.art(32.0):
		_set_selection([_hero])
		return

	if not map_view.is_inside(cell):
		if _selected_nodes.size() > 0:
			_clear_selection()
		return
	if map_view.is_buildable(cell):
		_clear_selection()
		_try_build_structure(cell)
	else:
		if _selected_nodes.size() > 0:
			_clear_selection()
		else:
			_status_text = "道路和 IQ 结晶所在格不能建造。"
			_refresh_hud()


func _handle_right_click(world_position: Vector2) -> void:
	# 需求 10：框选/点选后，右键妖精指定优先攻击目标
	if _selected_nodes.size() > 0:
		var enemy := _find_enemy_at(world_position)
		if enemy != null:
			var assigned := 0
			for node in _selected_nodes:
				if not is_instance_valid(node) or not node.has_method("can_accept_priority_target"):
					continue
				if not bool(node.call("can_accept_priority_target")):
					continue
				if bool(node.call("set_priority_target", enemy)):
					assigned += 1
			if assigned > 0:
				_status_text = "已为 %d 个选中目标指定优先攻击 %s。" % [assigned, str(enemy.definition.get("name", "敌人"))]
			else:
				_status_text = "选中的对象无法攻击该目标，或目标已超出允许范围。"
			_refresh_hud()
			return
		_clear_selection()
		_refresh_hud()
		return
	if is_instance_valid(_hero):
		_hero.set_move_target(world_position)
		_status_text = "琪露诺正在赶路。"
		_notify_tutorial("move")
		_refresh_hud()


func _pick_up_drop(world_position: Vector2) -> bool:
	var nearest_drop: EnchantDrop = null
	var nearest_distance := Metrics.art(40.0)
	for drop_node in drops.get_children():
		var drop := drop_node as EnchantDrop
		if drop == null or not is_instance_valid(drop):
			continue
		var distance := world_position.distance_to(drop.global_position)
		if distance <= nearest_distance:
			nearest_drop = drop
			nearest_distance = distance
	if nearest_drop == null:
		return false
	ice_crystals += nearest_drop.shards
	_unclaimed_enchant_drops = maxi(0, _unclaimed_enchant_drops - 1)
	nearest_drop.queue_free()
	_status_text = "拾取了冰晶附魔（+%d 冰晶）。" % nearest_drop.shards
	if phase == Phase.COMBAT and not _enchant_open:
		_begin_enchant_choice()
	else:
		_refresh_hud()
	return true


func _on_build_item_selected(build_id: String) -> void:
	if not BuildCatalog.ORDER.has(build_id):
		return
	_selected_build_id = build_id
	hud.select_build_item(build_id)
	map_view.set_build_preview(build_id)
	_clear_selection()
	var definition := BuildCatalog.get_definition(build_id)
	_status_text = "已选择 %s，点击草地格部署。" % str(definition.get("name", build_id))
	_refresh_hud()


func _try_build_structure(cell: Vector2i) -> void:
	if phase == Phase.UPGRADE or phase == Phase.ENCHANT or phase == Phase.FINISHED:
		return
	var definition := BuildCatalog.get_definition(_selected_build_id)
	if definition.is_empty():
		return
	var cost := _get_build_cost(definition)
	if frost < float(cost):
		_status_text = "冻气不足，还需要 %d。" % int(ceil(float(cost) - frost))
		_refresh_hud()
		return
	var footprint := _get_footprint_cells(_selected_build_id, cell)
	if not _footprint_valid(footprint):
		_status_text = "该区域无法建造：需避开道路、IQ 结晶与其他建筑。"
		_refresh_hud()
		return

	var structure: DefenseStructure
	if BuildCatalog.is_tower(_selected_build_id):
		structure = TowerScript.new()
		towers.add_child(structure)
	else:
		structure = BarracksScript.new()
		barracks_container.add_child(structure)
	structure.global_position = map_view.to_global(
		map_view.cell_position_to_local(_get_footprint_center(_selected_build_id, cell))
	)
	structure.setup(self, definition)
	structure.destroyed.connect(_on_structure_destroyed)
	_sync_structure_modifiers(structure)
	for footprint_cell in footprint:
		_structure_cells[footprint_cell] = structure
	map_view.queue_redraw()
	frost -= float(cost)
	spawn_hit_effect(structure.global_position, Color("#bdf6ff"), 38.0)
	_status_text = "%s 部署完成。" % structure.get_display_name()
	_notify_tutorial("tower" if structure is CirnoTower else "barracks")
	_refresh_hud()


## 需求 6：返回某类建筑在锚点处的完整占地格集合。
func _get_footprint_cells(build_id: String, anchor: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if BuildCatalog.is_barracks(build_id):
		for offset in BARRACKS_FOOTPRINT:
			cells.append(anchor + offset)
	else:
		for offset in TOWER_FOOTPRINT:
			cells.append(anchor + offset)
	return cells


## 偶数尺寸兵营以 2×2 中心摆放；奇数尺寸防御塔直接以锚点为中心。
func _get_footprint_center(build_id: String, anchor: Vector2i) -> Vector2:
	if BuildCatalog.is_barracks(build_id):
		return Vector2(anchor) + Vector2(0.5, 0.5)
	return Vector2(anchor)


func _footprint_valid(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not map_view.is_buildable(cell):
			return false
		if _structure_cells.has(cell):
			return false
	return true


func can_build_at(build_id: String, anchor: Vector2i) -> bool:
	if not BuildCatalog.ORDER.has(build_id):
		return false
	return _footprint_valid(_get_footprint_cells(build_id, anchor))


func _set_selection(nodes: Array) -> void:
	for node in _selected_nodes:
		if is_instance_valid(node) and node.has_method("set_selected"):
			node.set_selected(false)
	_selected_nodes = []
	for node in nodes:
		if node != null and is_instance_valid(node):
			_selected_nodes.append(node)
			if node.has_method("set_selected"):
				node.set_selected(true)
	_sync_selection_ui()


func _clear_selection() -> void:
	_set_selection([])


func _remove_from_selection(node: Node) -> void:
	if _selected_nodes.has(node):
		_selected_nodes.erase(node)
		_sync_selection_ui()


func _sync_selection_ui() -> void:
	var structure: DefenseStructure = null
	for node in _selected_nodes:
		if node is DefenseStructure and is_instance_valid(node):
			structure = node as DefenseStructure
			break
	if structure != null and _selected_nodes.size() == 1:
		_selected_structure = structure
		hud.show_structure_detail(structure)
	else:
		if _selected_structure != null:
			_selected_structure = null
			hud.clear_structure_detail()


## 需求 10：左键框选友军与防御塔。
func _select_objects_in_rect(rect: Rect2) -> void:
	var nodes: Array[Node2D] = []
	for structure_node in get_tree().get_nodes_in_group("structures"):
		var structure := structure_node as DefenseStructure
		if structure != null and is_instance_valid(structure) and rect.has_point(structure.global_position):
			nodes.append(structure)
	for ally_node in get_tree().get_nodes_in_group("allies"):
		var ally := ally_node as AllyUnit
		if ally != null and is_instance_valid(ally) and ally.is_alive() and rect.has_point(ally.global_position):
			nodes.append(ally)
	if is_instance_valid(_hero) and _hero.is_alive() and rect.has_point(_hero.global_position):
		nodes.append(_hero)
	_set_selection(nodes)
	if nodes.size() > 0:
		_status_text = "已框选 %d 个目标，右键妖精可指定优先攻击。" % nodes.size()
	else:
		_status_text = "框选区域没有友方单位。"
	_refresh_hud()


func _find_ally_at(world_position: Vector2) -> AllyUnit:
	var nearest: AllyUnit = null
	var nearest_distance := Metrics.art(22.0)
	for ally_node in get_tree().get_nodes_in_group("allies"):
		var ally := ally_node as AllyUnit
		if ally == null or not is_instance_valid(ally) or not ally.is_alive():
			continue
		var distance := world_position.distance_to(ally.global_position)
		if distance <= nearest_distance:
			nearest = ally
			nearest_distance = distance
	return nearest


func _find_structure_at(cell: Vector2i) -> DefenseStructure:
	var structure = _structure_cells.get(cell, null)
	if structure != null and is_instance_valid(structure):
		return structure
	if structure == null:
		_structure_cells.erase(cell)
	return null


func _find_enemy_at(world_position: Vector2) -> FairyEnemy:
	var nearest: FairyEnemy = null
	var nearest_distance := Metrics.art(34.0)
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var distance := world_position.distance_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _on_structure_destroyed(structure: DefenseStructure) -> void:
	for cell in _structure_cells.keys():
		if _structure_cells[cell] == structure:
			_structure_cells.erase(cell)
	_remove_from_selection(structure)
	if _selected_structure == structure:
		_selected_structure = null
		hud.clear_structure_detail()
	map_view.queue_redraw()
	_status_text = "%s 被妖精击毁了。" % structure.get_display_name()
	_refresh_hud()


func _on_start_wave_requested() -> void:
	if phase != Phase.PREP:
		return
	var next_index := _wave_manager.current_index + 1
	if not _wave_manager.start_wave(next_index):
		return
	phase = Phase.COMBAT
	_status_text = "妖精开始进攻，别让琪露诺被打倒！"
	_notify_tutorial("wave")
	_refresh_hud()


func _on_wave_started(index: int, display_name: String) -> void:
	wave_index = index
	phase = Phase.COMBAT
	_status_text = "第 %d 波：%s" % [index + 1, display_name]
	_refresh_hud()


func _on_spawn_requested(enemy_id: String, hp_scale: float, entrance_id: String) -> void:
	if phase == Phase.FINISHED:
		return
	var final_entrance := entrance_id
	if not map_view.has_entrance(final_entrance):
		final_entrance = map_view.DEFAULT_ENTRANCE if map_view.has_entrance(map_view.DEFAULT_ENTRANCE) else map_view.get_first_entrance()
	var path_points := map_view.get_path_points(final_entrance)
	var enemy: FairyEnemy = EnemyScript.new()
	enemies.add_child(enemy)
	enemy.setup(path_points, EnemyCatalog.get_definition(enemy_id), hp_scale)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.reached_core.connect(_on_enemy_reached_core)
	_wave_manager.notify_enemy_spawned()


func _on_enemy_defeated(_enemy: FairyEnemy, reward: int, shards: int, world_position: Vector2) -> void:
	frost += float(reward)
	kill_count += 1
	total_kills += 1
	spawn_hit_effect(world_position, Color("#9affc9"), 24.0)
	if kill_count % 8 == 0 and is_instance_valid(_hero):
		_hero.trigger_baka_passive()
		_status_text = "笨蛋寒气失控，周围全体减速！"
	# 需求 8：精英不再直接弹窗，改为掉落物，左键拾取后触发附魔。
	if shards > 0 and phase == Phase.COMBAT:
		_spawn_enchant_drop(world_position, shards)
	_wave_manager.notify_enemy_finished()


func _spawn_enchant_drop(world_position: Vector2, shards: int) -> void:
	var drop: EnchantDrop = EnchantDropScript.new()
	drops.add_child(drop)
	drop.global_position = world_position
	drop.setup(shards)
	_unclaimed_enchant_drops += 1


func _on_enemy_reached_core(enemy: FairyEnemy, leak_damage: int) -> void:
	if phase == Phase.FINISHED:
		return
	spawn_hit_effect(map_view.get_core_world_position(), Color("#ff667f"), 42.0)
	var enemy_name := str(enemy.definition.get("name", "妖精")) if enemy != null else "妖精"
	_damage_hero(float(leak_damage), "%s 偷走了 IQ，琪露诺受到 %d 点伤害！" % [enemy_name, leak_damage])
	_wave_manager.notify_enemy_finished()
	_refresh_hud()


func _on_hero_defeated(_hero_node: CirnoHero) -> void:
	if phase == Phase.FINISHED:
		return
	_finish_defeat()


func _damage_hero(amount: float, message: String) -> void:
	if phase == Phase.FINISHED or not is_instance_valid(_hero) or not _hero.is_alive():
		return
	_hero.take_damage(amount)
	_status_text = message
	if not _hero.is_alive():
		_finish_defeat()


## 需求 5：波末结算 —— 计算本波金钱收益，兵种随后自动回到出生兵营驻扎。
func _on_wave_finished(index: int) -> void:
	if phase == Phase.FINISHED:
		return
	if _unclaimed_enchant_drops > 0 or _enchant_open:
		_pending_wave_finished_index = index
		phase = Phase.COMBAT
		_status_text = "本波敌人已清空，拾取并选择剩余的冰晶附魔后结算。"
		_refresh_hud()
		return
	_complete_wave(index)


func _complete_wave(index: int) -> void:
	if index >= WaveCatalog.wave_count() - 1:
		_finish_victory()
		return

	_pending_wave_reward_index = index
	var projected_reward := _get_wave_frost_reward(index)
	ice_crystals += 1
	phase = Phase.SETTLEMENT
	_status_text = "守住第 %d 波，选择笨蛋灵感后领取冻气奖励。" % (index + 1)
	hud.show_settlement(index + 1, projected_reward)
	_refresh_hud()


func _on_settlement_continue_requested() -> void:
	if phase != Phase.SETTLEMENT:
		return
	phase = Phase.UPGRADE
	_status_text = "选择一项笨蛋灵感，并领取本波冻气奖励。"
	hud.hide_settlement()
	hud.show_modifier_choices("blessing", "笨蛋灵感", "选择后立即领取本波冻气奖励；奖励类祝福本次生效。", _upgrade_manager.get_choices("blessing"))
	_refresh_hud()


func _begin_enchant_choice() -> void:
	_enchant_open = true
	phase = Phase.ENCHANT
	_wave_manager.set_paused(true)
	_set_combat_simulation_paused(true)
	_status_text = "精英妖精掉落了冰晶。选择一项附魔。"
	hud.show_modifier_choices("enchant", "冰晶附魔", "精英掉落：为整支防线注入一枚冰晶。", _upgrade_manager.get_choices("enchant"))
	_refresh_hud()


func _on_modifier_card_selected(pool: String, modifier_id: String) -> void:
	if pool == "enchant" and phase != Phase.ENCHANT:
		return
	if pool != "enchant" and phase != Phase.UPGRADE:
		return
	var definition := _upgrade_manager.apply_upgrade(pool, modifier_id)
	if definition.is_empty():
		return
	var effects: Dictionary = definition.get("effects", {})
	_sync_all_modifiers()
	if effects.has("heal_now") and is_instance_valid(_hero):
		_hero.heal(float(effects["heal_now"]))
	hud.hide_modifier_choices()

	if pool == "enchant":
		_enchant_open = false
		_wave_manager.set_paused(false)
		_set_combat_simulation_paused(false)
		if _pending_wave_finished_index >= 0 and _unclaimed_enchant_drops <= 0:
			var finished_index := _pending_wave_finished_index
			_pending_wave_finished_index = -1
			_complete_wave(finished_index)
		else:
			phase = Phase.COMBAT
			if _pending_wave_finished_index >= 0:
				_status_text = "获得「%s」，请继续拾取剩余附魔。" % str(definition.get("name", "冰晶附魔"))
			else:
				_status_text = "获得「%s」，战斗继续。" % str(definition.get("name", "冰晶附魔"))
	else:
		var frost_reward := 0
		if _pending_wave_reward_index >= 0:
			frost_reward = _get_wave_frost_reward(_pending_wave_reward_index)
			frost += float(frost_reward)
			_pending_wave_reward_index = -1
		phase = Phase.PREP
		_status_text = "获得「%s」，波末冻气 +%d。准备下一波。" % [str(definition.get("name", "祝福")), frost_reward]
	_refresh_hud()


func _on_upgrade_structure_requested() -> void:
	if _selected_structure == null or not is_instance_valid(_selected_structure):
		return
	if _selected_structure.level >= 3:
		return
	var cost := _selected_structure.get_upgrade_cost()
	if frost < float(cost):
		_status_text = "冻气不足，无法升级。"
		_refresh_hud()
		return
	frost -= float(cost)
	_selected_structure.upgrade()
	_sync_structure_modifiers(_selected_structure)
	spawn_hit_effect(_selected_structure.global_position, Color("#fff3a0"), 44.0)
	_status_text = "%s 已升级至 Lv.%d。" % [_selected_structure.get_display_name(), _selected_structure.level]
	hud.show_structure_detail(_selected_structure)
	_refresh_hud()


func _on_hero_skill_requested(slot: String) -> void:
	if phase != Phase.COMBAT or not is_instance_valid(_hero):
		return
	if not _hero.try_cast_skill(slot):
		_status_text = "技能尚未冷却，或范围内没有合法目标。"
	else:
		_status_text = "琪露诺释放了%s。" % ("冰霜新星" if slot == "nova" else "完美冻结")
	_refresh_hud()


func _on_restart_requested() -> void:
	get_tree().reload_current_scene()


func _on_menu_requested() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _notify_tutorial(event_id: String) -> void:
	if _tutorial != null and is_instance_valid(_tutorial):
		_tutorial.call("notify", event_id)


func _sync_all_modifiers() -> void:
	for structure in get_tree().get_nodes_in_group("structures"):
		_sync_structure_modifiers(structure as DefenseStructure)
	for ally in get_tree().get_nodes_in_group("allies"):
		var unit := ally as AllyUnit
		if unit != null and is_instance_valid(unit):
			unit.update_modifiers(_upgrade_manager.modifiers)
	if is_instance_valid(_hero):
		_hero.update_modifiers(_upgrade_manager.modifiers)


func _sync_structure_modifiers(structure: DefenseStructure) -> void:
	if structure == null or not is_instance_valid(structure):
		return
	var structure_modifiers := _upgrade_manager.modifiers.duplicate(true)
	if structure is FairyBarracks:
		structure_modifiers["tower_damage_multiplier"] = 1.0
	structure.update_modifiers(structure_modifiers)


func _get_build_cost(definition: Dictionary) -> int:
	return int(round(float(definition.get("cost", 0)) * float(_upgrade_manager.modifiers.get("build_cost_multiplier", 1.0))))


func _get_wave_frost_reward(index: int) -> int:
	var base_reward := WAVE_FROST_REWARD_BASE + maxf(0.0, float(index)) * WAVE_FROST_REWARD_STEP
	var multiplier := float(_upgrade_manager.modifiers.get("wave_frost_reward_multiplier", 1.0))
	return maxi(0, int(round(base_reward * multiplier)))


func _get_unit_spawn_position(origin: Vector2) -> Vector2:
	var nearest_path := map_view.get_closest_path_world_position(origin)
	var offset := nearest_path - origin
	var max_offset := Metrics.art(58.0)
	if offset.length() > max_offset:
		offset = offset.normalized() * max_offset
	var result := origin + offset + Vector2(0.0, Metrics.art(18.0))
	var play_rect := map_view.get_play_rect().grow(-Metrics.art(15.0))
	return Vector2(clampf(result.x, play_rect.position.x, play_rect.end.x), clampf(result.y, play_rect.position.y, play_rect.end.y))


func _set_combat_simulation_paused(value: bool) -> void:
	world.process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT


func _stop_combat_simulation() -> void:
	if is_instance_valid(_wave_manager):
		_wave_manager.stop()
	_set_combat_simulation_paused(true)


func _refresh_hud() -> void:
	var phase_text := "准备"
	match phase:
		Phase.COMBAT:
			phase_text = "交战"
		Phase.SETTLEMENT:
			phase_text = "结算"
		Phase.UPGRADE:
			phase_text = "选择祝福"
		Phase.ENCHANT:
			phase_text = "选择附魔"
		Phase.FINISHED:
			phase_text = "结算"
	var wave_text := "%s · 第 %d / %d 波 · 在场 %d" % [
		phase_text,
		maxi(0, wave_index + 1),
		WaveCatalog.wave_count(),
		enemies.get_child_count(),
	]
	hud.update_resources(get_hero_hp(), get_hero_max_hp(), int(frost), ice_crystals, wave_text, _status_text)
	hud.set_start_button(phase == Phase.PREP, "开始第 %d 波" % mini(WaveCatalog.wave_count(), wave_index + 2))
	if is_instance_valid(_hero):
		hud.set_skill_state("nova", _hero.get_skill_text("nova"), _hero.get_skill_ready("nova") and phase != Phase.FINISHED)
		hud.set_skill_state("freeze", _hero.get_skill_text("freeze"), _hero.get_skill_ready("freeze") and phase != Phase.FINISHED)
	if _selected_structure != null and is_instance_valid(_selected_structure):
		hud.refresh_structure_detail(_selected_structure, int(frost))


func _finish_victory() -> void:
	_pending_wave_finished_index = -1
	phase = Phase.FINISHED
	_stop_combat_simulation()
	_status_text = "灵梦退治失败，琪露诺安然无恙。"
	_refresh_hud()
	hud.show_result(true, "你保护了琪露诺，守住了她的 IQ。\n剩余生命：%d / %d\n累计击退妖精：%d" % [get_hero_hp(), get_hero_max_hp(), total_kills])


func _finish_defeat() -> void:
	phase = Phase.FINISHED
	_stop_combat_simulation()
	_status_text = "琪露诺倒下了，IQ 被妖精们偷光了。"
	_refresh_hud()
	hud.show_result(false, "琪露诺的生命归零了。\n坚持到第 %d 波，击退妖精 %d 只。" % [wave_index + 1, total_kills])
