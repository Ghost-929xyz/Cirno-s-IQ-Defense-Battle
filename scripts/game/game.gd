class_name FogLakeLevel
extends Node2D

const TowerScript = preload("res://scripts/entities/tower.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const HitEffectScript = preload("res://scripts/effects/hit_effect.gd")

const IQ_START := 20
const FROST_START := 140.0
const PREP_FROST_PER_SECOND := 4.0

enum Phase {
	PREP,
	COMBAT,
	UPGRADE,
	FINISHED,
}

@onready var map_view: LakeMapView = $MapView
@onready var towers: Node2D = $Towers
@onready var enemies: Node2D = $Enemies
@onready var projectiles: Node2D = $Projectiles
@onready var effects: Node2D = $Effects
@onready var hud: BattleHUD = $HUD

var phase := Phase.PREP
var iq := IQ_START
var max_iq := IQ_START
var frost := FROST_START
var wave_index := -1
var damage_multiplier := 1.0
var attack_speed_multiplier := 1.0
var slow_bonus := 0.0
var splash_multiplier := 1.0

var _wave_manager: WaveManager
var _upgrade_manager: UpgradeManager
var _selected_tower_id := "icicle"
var _selected_tower: CirnoTower
var _tower_cells: Dictionary = {}
var _status_text := "选择一种琪露诺，然后点击草地格。"


func _ready() -> void:
	add_to_group("game")
	_wave_manager = WaveManager.new()
	add_child(_wave_manager)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_finished.connect(_on_wave_finished)
	_wave_manager.spawn_requested.connect(_on_spawn_requested)

	_upgrade_manager = UpgradeManager.new()
	hud.build_tower_selected.connect(_on_build_tower_selected)
	hud.start_wave_requested.connect(_on_start_wave_requested)
	hud.upgrade_tower_requested.connect(_on_upgrade_tower_requested)
	hud.upgrade_card_selected.connect(_on_upgrade_card_selected)
	hud.restart_requested.connect(_on_restart_requested)
	_sync_tower_modifiers()
	_refresh_hud()


func _process(delta: float) -> void:
	if phase == Phase.PREP:
		frost += PREP_FROST_PER_SECOND * float(_upgrade_manager.modifiers.get("frost_regen_multiplier", 1.0)) * delta
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		map_view.set_hover_cell(map_view.world_to_cell(event.position))
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_clear_tower_selection()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.position.x >= 770.0:
			return
		var cell := map_view.world_to_cell(event.position)
		var existing_tower := _find_tower_at(cell)
		if existing_tower != null:
			_select_tower(existing_tower)
		elif map_view.is_buildable(cell):
			_try_build_tower(cell)
		else:
			_status_text = "路径和湖面不能建造。"
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_clear_tower_selection()
		elif event.keycode == KEY_1:
			hud.select_build_tower("icicle")
		elif event.keycode == KEY_2:
			hud.select_build_tower("rime")
		elif event.keycode == KEY_3:
			hud.select_build_tower("baka")
		elif event.keycode == KEY_SPACE:
			_on_start_wave_requested()


func add_projectile(projectile: Node2D) -> void:
	projectiles.add_child(projectile)


func _on_build_tower_selected(tower_id: String) -> void:
	_selected_tower_id = tower_id
	map_view.set_selected_tower_id(tower_id)
	_clear_tower_selection()
	var definition := TowerCatalog.get_definition(tower_id)
	_status_text = "已选择 %s，点击草地格建造。" % str(definition.get("name", tower_id))
	_refresh_hud()


func _try_build_tower(cell: Vector2i) -> void:
	if phase == Phase.UPGRADE or phase == Phase.FINISHED:
		return
	var definition := TowerCatalog.get_definition(_selected_tower_id)
	if definition.is_empty():
		return
	var cost := int(definition.get("cost", 0))
	if frost < float(cost):
		_status_text = "冻气不足，还需要 %d。" % int(ceil(float(cost) - frost))
		return

	var tower: CirnoTower = TowerScript.new()
	towers.add_child(tower)
	tower.global_position = map_view.to_global(map_view.cell_to_local(cell))
	tower.setup(self, definition)
	tower.update_modifiers(damage_multiplier, attack_speed_multiplier, slow_bonus, splash_multiplier)
	_tower_cells[cell] = tower
	frost -= float(cost)
	_spawn_effect(tower.global_position, Color("#bdf6ff"), 34.0)
	_status_text = "%s 部署完成。" % tower.get_display_name()
	_refresh_hud()


func _select_tower(tower: CirnoTower) -> void:
	if _selected_tower != null and is_instance_valid(_selected_tower):
		_selected_tower.set_selected(false)
	_selected_tower = tower
	_selected_tower.set_selected(true)
	hud.show_tower_detail(_selected_tower)
	_status_text = "正在查看 %s Lv.%d。" % [_selected_tower.get_display_name(), _selected_tower.level]
	_refresh_hud()


func _clear_tower_selection() -> void:
	if _selected_tower != null and is_instance_valid(_selected_tower):
		_selected_tower.set_selected(false)
	_selected_tower = null
	hud.clear_tower_detail()
	_refresh_hud()


func _find_tower_at(cell: Vector2i) -> CirnoTower:
	var tower = _tower_cells.get(cell, null)
	if tower != null and is_instance_valid(tower):
		return tower
	_tower_cells.erase(cell)
	return null


func _on_start_wave_requested() -> void:
	if phase != Phase.PREP:
		return
	var next_index := _wave_manager.current_index + 1
	if not _wave_manager.start_wave(next_index):
		return
	phase = Phase.COMBAT
	_clear_tower_selection()
	_status_text = "青蛙开始进攻，守住 IQ 核心！"
	_refresh_hud()


func _on_wave_started(index: int, display_name: String) -> void:
	wave_index = index
	phase = Phase.COMBAT
	_status_text = "第 %d 波：%s" % [index + 1, display_name]
	_refresh_hud()


func _on_spawn_requested(enemy_id: String, hp_scale: float) -> void:
	if phase == Phase.FINISHED:
		return
	var enemy: FrogEnemy = EnemyScript.new()
	enemies.add_child(enemy)
	var path_points := map_view.get_path_points()
	enemy.setup(path_points, EnemyCatalog.get_definition(enemy_id), hp_scale)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.reached_core.connect(_on_enemy_reached_core)
	_wave_manager.notify_enemy_spawned()


func _on_enemy_defeated(_enemy: FrogEnemy, reward: int, world_position: Vector2) -> void:
	frost += float(reward)
	_spawn_effect(world_position, Color("#8cffc0"), 22.0)
	_wave_manager.notify_enemy_finished()


func _on_enemy_reached_core(_enemy: FrogEnemy, iq_damage: int) -> void:
	iq = maxi(0, iq - iq_damage)
	_spawn_effect(map_view.to_global(map_view.cell_to_local(Vector2i(11, 7))), Color("#ff667f"), 38.0)
	if iq <= 0:
		_finish_defeat()
	else:
		_status_text = "青蛙偷走了 %d 点 IQ！" % iq_damage
		_wave_manager.notify_enemy_finished()
	_refresh_hud()


func _on_wave_finished(index: int) -> void:
	if phase == Phase.FINISHED:
		return
	if index >= WaveCatalog.wave_count() - 1:
		_finish_victory()
		return

	frost += 20.0 + index * 5.0
	phase = Phase.UPGRADE
	_status_text = "守住第 %d 波。选择一项笨蛋灵感。" % (index + 1)
	hud.show_upgrade_choices(_upgrade_manager.get_choices())
	_refresh_hud()


func _on_upgrade_card_selected(upgrade_id: String) -> void:
	if phase != Phase.UPGRADE:
		return
	var definition := _upgrade_manager.apply_upgrade(upgrade_id)
	if definition.is_empty():
		return
	var effects: Dictionary = definition.get("effects", {})
	max_iq = IQ_START + int(_upgrade_manager.modifiers.get("iq_max_add", 0))
	if effects.has("heal_now"):
		iq = mini(max_iq, iq + int(effects["heal_now"]))
	iq = mini(iq, max_iq)
	_sync_tower_modifiers()
	hud.hide_upgrade_choices()
	phase = Phase.PREP
	_status_text = "获得「%s」。准备下一波。" % str(definition.get("name", "强化"))
	_refresh_hud()


func _on_upgrade_tower_requested() -> void:
	if _selected_tower == null or not is_instance_valid(_selected_tower):
		return
	if _selected_tower.level >= 3:
		return
	var cost := _selected_tower.get_upgrade_cost()
	if frost < float(cost):
		_status_text = "冻气不足，无法升级。"
		_refresh_hud()
		return
	frost -= float(cost)
	_selected_tower.upgrade()
	_spawn_effect(_selected_tower.global_position, Color("#fff3a0"), 42.0)
	_status_text = "%s 已升级至 Lv.%d。" % [_selected_tower.get_display_name(), _selected_tower.level]
	hud.show_tower_detail(_selected_tower)
	_refresh_hud()


func _sync_tower_modifiers() -> void:
	damage_multiplier = float(_upgrade_manager.modifiers.get("damage_multiplier", 1.0))
	attack_speed_multiplier = float(_upgrade_manager.modifiers.get("attack_speed_multiplier", 1.0))
	slow_bonus = float(_upgrade_manager.modifiers.get("slow_bonus", 0.0))
	splash_multiplier = float(_upgrade_manager.modifiers.get("splash_multiplier", 1.0))
	for tower in towers.get_children():
		if tower.has_method("update_modifiers"):
			tower.update_modifiers(damage_multiplier, attack_speed_multiplier, slow_bonus, splash_multiplier)


func _finish_victory() -> void:
	phase = Phase.FINISHED
	_status_text = "蛙王撤退，IQ 核心安全。"
	_refresh_hud()
	hud.show_result(true, "你守住了琪露诺的 IQ。\n剩余 IQ：%d / %d" % [iq, max_iq])


func _finish_defeat() -> void:
	if phase == Phase.FINISHED:
		return
	phase = Phase.FINISHED
	_wave_manager.stop()
	_status_text = "IQ 归零，琪露诺忘记了自己为什么要防守。"
	_refresh_hud()
	hud.show_result(false, "不要让青蛙碰到 IQ 核心。\n调整塔位与减速塔数量后再试一次。")


func _on_restart_requested() -> void:
	get_tree().reload_current_scene()


func _spawn_effect(world_position: Vector2, color: Color, radius: float) -> void:
	var effect: HitEffect = HitEffectScript.new()
	effects.add_child(effect)
	effect.global_position = world_position
	effect.setup(color, radius)


func _refresh_hud() -> void:
	if not is_instance_valid(hud):
		return
	var wave_text := "准备阶段 · 共 %d 波" % WaveCatalog.wave_count()
	if phase == Phase.COMBAT:
		wave_text = "第 %d / %d 波" % [wave_index + 1, WaveCatalog.wave_count()]
	elif phase == Phase.UPGRADE:
		wave_text = "第 %d 波已守住" % (wave_index + 1)
	elif phase == Phase.FINISHED:
		wave_text = "本局结束"

	var can_start := phase == Phase.PREP
	var start_text := "开始第 %d 波" % (_wave_manager.current_index + 2)
	if _wave_manager.current_index < 0:
		start_text = "开始第 1 波"
	if phase == Phase.UPGRADE:
		start_text = "选择强化后继续"
	elif phase == Phase.FINISHED:
		start_text = "本局已结束"
	hud.set_start_button(can_start, start_text)
	hud.update_resources(iq, max_iq, int(floor(frost)), wave_text, _status_text)
