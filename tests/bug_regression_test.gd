extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const SessionScript = preload("res://scripts/autoload/session.gd")
const EnemyScript = preload("res://scripts/entities/enemy.gd")
const AllyScript = preload("res://scripts/entities/ally_unit.gd")
const BarracksScript = preload("res://scripts/entities/barracks.gd")

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	SessionScript.tutorial_done = true
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	printerr("FAIL: %s" % message)


func _make_game() -> FogLakeLevel:
	var game := MainScene.instantiate() as FogLakeLevel
	root.add_child(game)
	await process_frame
	return game


func _discard_game(game: FogLakeLevel) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame


func _make_enemy(game: FogLakeLevel, start: Vector2, finish: Vector2 = Vector2.INF) -> FairyEnemy:
	var enemy := EnemyScript.new() as FairyEnemy
	game.enemies.add_child(enemy)
	if not finish.is_finite():
		finish = start + Vector2(200.0, 0.0)
	enemy.setup(PackedVector2Array([start, finish]), EnemyCatalog.get_definition("dew_fairy"), 1.0)
	return enemy


func _run() -> void:
	await _test_input_skill_range_health_build_and_targeting()
	await _test_wave_reward_replaces_prep_regen()
	await _test_last_elite_drop_and_pause()
	await _test_final_elite_reward_precedes_victory()
	await _test_finished_state_stops_simulation()
	await _test_last_leak_damage_precedes_wave_finish()

	if _failures.is_empty():
		print("BUG_REGRESSION_OK checks=%d" % _checks)
		quit(0)
		return
	printerr("BUG_REGRESSION_FAILED checks=%d failures=%d" % [_checks, _failures.size()])
	quit(1)


func _test_input_skill_range_health_build_and_targeting() -> void:
	var game := await _make_game()

	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_4
	game._unhandled_input(key_event)
	_expect(game._selected_build_id == "guard_barracks", "数字键必须更新实际建筑选择")
	_expect(game.hud._selected_build_id == "guard_barracks", "数字键必须同步 HUD 建筑选择")
	_expect(game.map_view.build_preview_id == "guard_barracks", "数字键必须同步地图建造预览")

	game.phase = FogLakeLevel.Phase.COMBAT
	game._hero._freeze_cooldown = 0.0
	_expect(not game._hero.try_cast_skill("freeze"), "R 在范围内没有目标时必须返回失败")
	_expect(game._hero.get_skill_ready("freeze"), "R 空放失败后不得进入冷却")
	var skill_enemy := _make_enemy(
		game,
		game._hero.global_position + Vector2(100.0, 0.0),
		game._hero.global_position + Vector2(180.0, 0.0)
	)
	_expect(game._hero.try_cast_skill("freeze"), "R 有合法目标时必须返回成功")
	_expect(not game._hero.get_skill_ready("freeze"), "R 成功后必须进入冷却")
	skill_enemy.queue_free()
	await process_frame

	var ally := AllyScript.new() as AllyUnit
	game.allies.add_child(ally)
	ally.setup(game, AllyCatalog.get_definition("ice_guard"), Vector2(100.0, 100.0))
	var range_enemy := _make_enemy(game, Vector2(155.0, 100.0))
	_expect(range_enemy._find_combat_target() == ally, "敌人必须能在 55px 距离发现友军")

	game._hero.current_hp = 100.0
	game._hero.update_modifiers({"hero_max_hp_add": 30.0})
	game._hero.heal(30.0)
	_expect(is_equal_approx(game._hero.current_hp, 130.0), "生命上限祝福不得把 30 治疗重复结算为 60")
	_expect(is_equal_approx(game._hero.max_hp, 220.0), "生命上限祝福必须正确提高上限")

	game._on_build_item_selected("icicle")
	var build_cell := Vector2i(-1, -1)
	for y in range(game.map_view.ROWS):
		for x in range(game.map_view.COLS):
			var candidate := Vector2i(x, y)
			if game.can_build_at("icicle", candidate):
				build_cell = candidate
				break
		if build_cell.x >= 0:
			break
	_expect(build_cell.x >= 0, "测试地图必须存在可建造的塔位置")
	game._try_build_structure(build_cell)
	_expect(game.towers.get_child_count() == 1, "合法位置必须能建造防御塔")
	_expect(not game.can_build_at("icicle", build_cell), "已占用位置的预览与实际建造都必须判为非法")
	_expect(not bool(game.map_view._build_validator.call("icicle", build_cell)), "地图预览必须使用包含建筑占用的统一校验")

	var tower := game.towers.get_child(0) as CirnoTower
	var target_enemy := _make_enemy(game, tower.global_position + Vector2(40.0, 0.0))
	_expect(tower.can_accept_priority_target(), "防御塔必须声明支持优先目标")
	_expect(tower.set_priority_target(target_enemy), "射程内敌人必须可被塔指定为优先目标")

	var barracks := BarracksScript.new() as FairyBarracks
	game.barracks_container.add_child(barracks)
	barracks.setup(game, BarracksCatalog.get_definition("guard_barracks"))
	_expect(not barracks.can_accept_priority_target(), "兵营不得声明支持攻击目标")
	_expect(not barracks.set_priority_target(target_enemy), "兵营不得接受无效的攻击指令")

	ally.global_position = target_enemy.global_position - Vector2(80.0, 0.0)
	_expect(ally.set_priority_target(target_enemy), "友军必须能接受允许范围内的优先目标")
	target_enemy.global_position = ally.global_position + Vector2(500.0, 0.0)
	ally._process(0.01)
	_expect(not is_instance_valid(ally._priority_target), "友军必须放弃超出追击范围的手动目标")

	await _discard_game(game)


func _test_final_elite_reward_precedes_victory() -> void:
	var game := await _make_game()
	game.phase = FogLakeLevel.Phase.COMBAT
	game._wave_manager.current_index = WaveCatalog.wave_count() - 1
	game._wave_manager.running = true
	game._wave_manager.paused = false
	game._wave_manager._events = []
	game._wave_manager._event_index = 0
	game._wave_manager._alive_enemies = 1
	var drop_position := Vector2(400.0, 260.0)
	game._on_enemy_defeated(null, 0, 3, drop_position)
	_expect(game.phase == FogLakeLevel.Phase.COMBAT, "最终精英掉落未处理前不得提前显示胜利")
	_expect(game._pending_wave_finished_index == WaveCatalog.wave_count() - 1, "最终波必须等待精英奖励处理")
	_expect(game._pick_up_drop(drop_position), "最终精英奖励必须可拾取")
	var choices: Array[Dictionary] = game.hud._modifier_choices
	_expect(not choices.is_empty(), "最终精英奖励必须提供附魔选择")
	if not choices.is_empty():
		game._on_modifier_card_selected("enchant", str(choices[0].get("id", "")))
	_expect(game.phase == FogLakeLevel.Phase.FINISHED, "最终附魔选择完成后必须继续胜利结算")
	_expect(game.world.process_mode == Node.PROCESS_MODE_DISABLED, "最终胜利结算必须保持战斗世界冻结")
	await _discard_game(game)


func _test_wave_reward_replaces_prep_regen() -> void:
	var game := await _make_game()
	game.phase = FogLakeLevel.Phase.PREP
	var starting_frost := game.frost
	game._process(60.0)
	_expect(is_equal_approx(game.frost, starting_frost), "准备阶段等待不得持续获得冻气")

	game._complete_wave(0)
	_expect(game.phase == FogLakeLevel.Phase.SETTLEMENT, "非最终波结束后必须进入结算")
	_expect(is_equal_approx(game.frost, starting_frost), "选择祝福前不得提前发放波末冻气")
	game._on_settlement_continue_requested()
	game._on_modifier_card_selected("blessing", "winter_lesson")
	_expect(is_equal_approx(game.frost, starting_frost + 22.0), "新取得的 +40% 奖励词条必须立即作用于第 1 波的 16 冻气奖励")
	_expect(is_equal_approx(float(game._upgrade_manager.modifiers["wave_frost_reward_multiplier"]), 1.4), "波末奖励倍率必须正确累计")

	var after_first_reward := game.frost
	game._complete_wave(1)
	_expect(is_equal_approx(game.frost, after_first_reward), "第 2 波奖励也必须等到祝福选择后发放")
	game._on_settlement_continue_requested()
	game._on_modifier_card_selected("blessing", "sharp_icicles")
	_expect(is_equal_approx(game.frost, after_first_reward + 28.0), "第 2 波基础奖励应提升至 20，并继承 +40% 奖励倍率")
	await _discard_game(game)


func _test_last_elite_drop_and_pause() -> void:
	var game := await _make_game()
	game.phase = FogLakeLevel.Phase.COMBAT
	game._wave_manager.current_index = 4
	game._wave_manager.running = true
	game._wave_manager.paused = false
	game._wave_manager._events = []
	game._wave_manager._event_index = 0
	game._wave_manager._alive_enemies = 1

	var drop_position := Vector2(360.0, 240.0)
	var moving_enemy := _make_enemy(game, Vector2(20.0, 20.0), Vector2(220.0, 20.0))
	game._on_enemy_defeated(null, 0, 1, drop_position)
	_expect(game.drops.get_child_count() == 1, "最后一只精英死亡时必须先生成掉落")
	_expect(game._pending_wave_finished_index == 4, "存在未拾取掉落时必须延后波末结算")
	_expect(game.phase == FogLakeLevel.Phase.COMBAT, "等待拾取最后掉落时必须保留可拾取阶段")

	_expect(game._pick_up_drop(drop_position), "精英掉落必须可以拾取")
	_expect(game.phase == FogLakeLevel.Phase.ENCHANT, "拾取精英掉落后必须进入附魔阶段")
	_expect(game.world.process_mode == Node.PROCESS_MODE_DISABLED, "附魔阶段必须冻结整个战斗世界")
	_expect(game._wave_manager.paused, "附魔阶段必须暂停继续出兵")
	var paused_position := moving_enemy.global_position
	await create_timer(0.12).timeout
	_expect(moving_enemy.global_position.is_equal_approx(paused_position), "附魔阶段敌人位置不得变化")

	var choices: Array[Dictionary] = game.hud._modifier_choices
	_expect(not choices.is_empty(), "附魔阶段必须提供可选择的附魔")
	if not choices.is_empty():
		game._on_modifier_card_selected("enchant", str(choices[0].get("id", "")))
	_expect(game.phase == FogLakeLevel.Phase.SETTLEMENT, "处理最后掉落后必须继续原波次结算")
	_expect(game.world.process_mode == Node.PROCESS_MODE_INHERIT, "非最终波附魔结束后必须恢复战斗世界处理")

	await _discard_game(game)


func _test_finished_state_stops_simulation() -> void:
	var game := await _make_game()
	game.phase = FogLakeLevel.Phase.COMBAT
	game._wave_manager.running = true
	var enemy := _make_enemy(game, Vector2(20.0, 40.0), Vector2(240.0, 40.0))
	game._finish_defeat()
	_expect(game.phase == FogLakeLevel.Phase.FINISHED, "失败后必须进入 FINISHED")
	_expect(not game._wave_manager.running, "FINISHED 必须停止 WaveManager")
	_expect(game.world.process_mode == Node.PROCESS_MODE_DISABLED, "FINISHED 必须冻结整个战斗世界")
	var finished_position := enemy.global_position
	await create_timer(0.12).timeout
	_expect(enemy.global_position.is_equal_approx(finished_position), "FINISHED 后敌人不得继续移动")
	await _discard_game(game)


func _test_last_leak_damage_precedes_wave_finish() -> void:
	var game := await _make_game()
	game.phase = FogLakeLevel.Phase.COMBAT
	game._hero.current_hp = game._hero.max_hp
	game._wave_manager.current_index = WaveCatalog.wave_count() - 1
	game._wave_manager.running = true
	game._wave_manager.paused = false
	game._wave_manager._events = []
	game._wave_manager._event_index = 0
	game._wave_manager._alive_enemies = 1
	game._on_enemy_reached_core(null, 45)
	_expect(is_equal_approx(game._hero.current_hp, game._hero.max_hp - 43.0), "最后一只漏怪必须先按护甲结算伤害")
	_expect(game.phase == FogLakeLevel.Phase.FINISHED, "最终波最后一只漏怪结算后必须进入当前规则的结果阶段")
	await _discard_game(game)
