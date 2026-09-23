class_name FogLakeLevel
extends Node2D

const TowerScript = preload("res://scripts/entities/tower.gd")
const BarracksScript = preload("res://scripts/entities/barracks.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const AllyScript = preload("res://scripts/entities/ally_unit.gd")
const HeroScript = preload("res://scripts/entities/hero.gd")
const HitEffectScript = preload("res://scripts/effects/hit_effect.gd")
const TutorialOverlayScript = preload("res://scripts/ui/tutorial_overlay.gd")
const SessionScript = preload("res://scripts/autoload/session.gd")

const FROST_START := 180.0
const PREP_FROST_PER_SECOND := 5.0

enum Phase {
	PREP,
	COMBAT,
	UPGRADE,
	ENCHANT,
	FINISHED,
}

@onready var map_view: LakeMapView = $MapView
@onready var towers: Node2D = $Towers
@onready var barracks_container: Node2D = $Barracks
@onready var allies: Node2D = $Allies
@onready var hero_container: Node2D = $Hero
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var effects: Node2D = $Effects
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
var _status_text := "右键移动琪露诺；或选择建筑后点击草地格部署。"
var _enchant_open := false


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

	_setup_tutorial()
	_spawn_hero()
	hud.select_build_item(_selected_build_id)
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
		frost += PREP_FROST_PER_SECOND * float(_upgrade_manager.modifiers.get("frost_regen_multiplier", 1.0)) * delta
		if is_instance_valid(_hero):
			_hero.regen(delta)
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if _tutorial != null and _tutorial.has_method("is_blocking") and _tutorial.call("is_blocking"):
		return
	if event is InputEventMouseMotion:
		map_view.set_hover_cell(map_view.world_to_cell(event.position))
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(event.position)
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.position.x >= 770.0:
			return
		_handle_left_click(event.position)
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_clear_structure_selection()
		elif event.keycode == KEY_SPACE:
			_on_start_wave_requested()
		elif event.keycode == KEY_Q:
			_on_hero_skill_requested("nova")
		elif event.keycode == KEY_R:
			_on_hero_skill_requested("freeze")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var index := int(event.keycode - KEY_1)
			if index >= 0 and index < BuildCatalog.ORDER.size():
				hud.select_build_item(str(BuildCatalog.ORDER[index]))


func add_projectile(projectile: Node2D) -> void:
	projectiles.add_child(projectile)


func spawn_hit_effect(world_position: Vector2, color: Color, radius: float) -> void:
	var effect: HitEffect = HitEffectScript.new()
	effects.add_child(effect)
	effect.global_position = world_position
	effect.setup(color, radius)


func can_barracks_spawn() -> bool:
	return phase == Phase.COMBAT


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


func _handle_left_click(world_position: Vector2) -> void:
	var cell := map_view.world_to_cell(world_position)
	var existing := _find_structure_at(cell)
	if existing != null:
		_select_structure(existing)
		return
	if not map_view.is_inside(cell):
		return
	if map_view.is_buildable(cell):
		_try_build_structure(cell)
	else:
		_status_text = "道路和 IQ 结晶所在格不能建造。"


func _handle_right_click(world_position: Vector2) -> void:
	if _selected_structure != null and is_instance_valid(_selected_structure):
		var enemy := _find_enemy_at(world_position)
		if enemy != null:
			_selected_structure.set_priority_target(enemy)
			_status_text = "%s 已优先锁定 %s。" % [_selected_structure.get_display_name(), str(enemy.definition.get("name", "敌人"))]
			_refresh_hud()
			return
		_clear_structure_selection()
		return
	if is_instance_valid(_hero):
		_hero.set_move_target(world_position)
		_status_text = "琪露诺正在赶路。"
		_notify_tutorial("move")


func _on_build_item_selected(build_id: String) -> void:
	if not BuildCatalog.ORDER.has(build_id):
		return
	_selected_build_id = build_id
	_clear_structure_selection()
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
		return

	var structure: DefenseStructure
	if BuildCatalog.is_tower(_selected_build_id):
		structure = TowerScript.new()
		towers.add_child(structure)
	else:
		structure = BarracksScript.new()
		barracks_container.add_child(structure)
	structure.global_position = map_view.to_global(map_view.cell_to_local(cell))
	structure.setup(self, definition)
	structure.destroyed.connect(_on_structure_destroyed)
	_sync_structure_modifiers(structure)
	_structure_cells[cell] = structure
	frost -= float(cost)
	spawn_hit_effect(structure.global_position, Color("#bdf6ff"), 38.0)
	_status_text = "%s 部署完成。" % structure.get_display_name()
	_notify_tutorial("tower" if structure is CirnoTower else "barracks")
	_refresh_hud()


func _select_structure(structure: DefenseStructure) -> void:
	if _selected_structure != null and is_instance_valid(_selected_structure):
		_selected_structure.set_selected(false)
	_selected_structure = structure
	_selected_structure.set_selected(true)
	hud.show_structure_detail(_selected_structure)
	_status_text = "选中 %s，右键可指定优先攻击目标。" % structure.get_display_name()
	_refresh_hud()


func _clear_structure_selection() -> void:
	if _selected_structure != null and is_instance_valid(_selected_structure):
		_selected_structure.set_selected(false)
	_selected_structure = null
	hud.clear_structure_detail()
	_refresh_hud()


func _find_structure_at(cell: Vector2i) -> DefenseStructure:
	var structure = _structure_cells.get(cell, null)
	if structure != null and is_instance_valid(structure):
		return structure
	_structure_cells.erase(cell)
	return null


func _find_enemy_at(world_position: Vector2) -> FairyEnemy:
	var nearest: FairyEnemy = null
	var nearest_distance := 34.0
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
			break
	if _selected_structure == structure:
		_selected_structure = null
		hud.clear_structure_detail()
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
	var path_points := map_view.get_path_points(
		entrance_id if map_view.has_entrance(entrance_id) else map_view.DEFAULT_ENTRANCE
	)
	var enemy: FairyEnemy = EnemyScript.new()
	enemies.add_child(enemy)
	enemy.setup(path_points, EnemyCatalog.get_definition(enemy_id), hp_scale)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.reached_core.connect(_on_enemy_reached_core)
	_wave_manager.notify_enemy_spawned()


func _on_enemy_defeated(_enemy: FairyEnemy, reward: int, shards: int, world_position: Vector2) -> void:
	frost += float(reward)
	ice_crystals += shards
	kill_count += 1
	total_kills += 1
	spawn_hit_effect(world_position, Color("#9affc9"), 24.0)
	if kill_count % 8 == 0 and is_instance_valid(_hero):
		_hero.trigger_baka_passive()
		_status_text = "笨蛋寒气失控，周围全体减速！"
	_wave_manager.notify_enemy_finished()
	if shards > 0 and phase == Phase.COMBAT and not _enchant_open:
		_begin_enchant_choice()


func _on_enemy_reached_core(enemy: FairyEnemy, leak_damage: int) -> void:
	spawn_hit_effect(map_view.get_core_world_position(), Color("#ff667f"), 42.0)
	_wave_manager.notify_enemy_finished()
	if phase == Phase.FINISHED:
		return
	var enemy_name := str(enemy.definition.get("name", "妖精")) if enemy != null else "妖精"
	_damage_hero(float(leak_damage), "%s 偷走了 IQ，琪露诺受到 %d 点伤害！" % [enemy_name, leak_damage])
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


func _on_wave_finished(index: int) -> void:
	if phase == Phase.FINISHED:
		return
	if index >= WaveCatalog.wave_count() - 1:
		_finish_victory()
		return

	frost += 16.0 + index * 4.0
	ice_crystals += 1
	phase = Phase.UPGRADE
	_status_text = "守住第 %d 波。选择一项笨蛋灵感。" % (index + 1)
	hud.show_modifier_choices("blessing", "笨蛋灵感", "选择一项全局祝福，然后进入下一波。", _upgrade_manager.get_choices("blessing"))
	_refresh_hud()


func _begin_enchant_choice() -> void:
	_enchant_open = true
	phase = Phase.ENCHANT
	_wave_manager.set_paused(true)
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
		phase = Phase.COMBAT
		_wave_manager.set_paused(false)
		_status_text = "获得「%s」，战斗继续。" % str(definition.get("name", "冰晶附魔"))
	else:
		phase = Phase.PREP
		_status_text = "获得「%s」。准备下一波。" % str(definition.get("name", "祝福"))
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
	if not is_instance_valid(_hero):
		return
	if not _hero.try_cast_skill(slot):
		_status_text = "技能尚未冷却。"
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


func _get_unit_spawn_position(origin: Vector2) -> Vector2:
	var nearest_path := map_view.get_closest_path_world_position(origin)
	var offset := nearest_path - origin
	if offset.length() > 58.0:
		offset = offset.normalized() * 58.0
	var result := origin + offset + Vector2(0.0, 18.0)
	var play_rect := map_view.get_play_rect().grow(-15.0)
	return Vector2(clampf(result.x, play_rect.position.x, play_rect.end.x), clampf(result.y, play_rect.position.y, play_rect.end.y))


func _refresh_hud() -> void:
	var phase_text := "准备"
	match phase:
		Phase.COMBAT:
			phase_text = "交战"
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
	phase = Phase.FINISHED
	_status_text = "灵梦退治失败，琪露诺安然无恙。"
	_refresh_hud()
	hud.show_result(true, "你保护了琪露诺，守住了她的 IQ。\n剩余生命：%d / %d\n累计击退妖精：%d" % [get_hero_hp(), get_hero_max_hp(), total_kills])


func _finish_defeat() -> void:
	phase = Phase.FINISHED
	_status_text = "琪露诺倒下了，IQ 被妖精们偷光了。"
	_refresh_hud()
	hud.show_result(false, "琪露诺的生命归零了。\n坚持到第 %d 波，击退妖精 %d 只。" % [wave_index + 1, total_kills])
