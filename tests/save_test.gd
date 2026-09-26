extends SceneTree

## 新功能回归测试：存档读写恢复、右键拆除返还、暂停菜单。
## 用 check() 代替 assert，保证失败也能跑完并退出。

var _checks := 0
var _failures := 0


func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("CHECK_FAIL: " + label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session_script := load("res://scripts/autoload/session.gd")
	var save_manager := load("res://scripts/autoload/save_manager.gd")

	# 1) 存档管理器：写入 / 读取 / 摘要 / 删除
	save_manager.delete_slot(2)
	check(not save_manager.has_save(2), "slot2 empty after delete")
	check(save_manager.write_slot(2, {"wave_index": 3, "frost": 120.0, "structures": [{"id": "icicle", "anchor": [10, 10], "level": 2, "hp": 50.0}]}), "write_slot returns true")
	check(save_manager.has_save(2), "slot2 has save after write")
	var summary: Dictionary = save_manager.get_slot_summary(2)
	check(int(summary.get("wave", 0)) == 4, "summary wave = wave_index + 1")
	check(int(summary.get("structures", 0)) == 1, "summary structures count")

	# 2) 进入游戏场景：绑定槽位，新局覆盖为初始存档
	session_script.tutorial_done = true
	session_script.current_slot = 2
	session_script.pending_load_slot = -1
	var level_scene := load("res://scenes/main.tscn") as PackedScene
	var level = level_scene.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame

	check(save_manager.has_save(2), "new game wrote initial save")
	var initial: Dictionary = save_manager.read_slot(2)
	check(int(initial.get("wave_index", -99)) == -1, "initial save wave_index -1")

	# 3) 建造一座塔（找 3x3 整片可建的锚点）并保存
	var map_view = level.map_view
	level.frost = 500.0
	var anchor := Vector2i(-1, -1)
	for y in range(1, 94):
		for x in range(1, 126):
			var candidate := Vector2i(x, y)
			if level.can_build_at("icicle", candidate):
				anchor = candidate
				break
		if anchor.x >= 0:
			break
	check(anchor.x >= 0, "found buildable anchor for icicle")
	level._selected_build_id = "icicle"
	level._try_build_structure(anchor)
	var tower_count: int = level.towers.get_child_count()
	check(tower_count == 1, "tower built")
	check(level.save_game(2), "save_game returns true")
	var data: Dictionary = save_manager.read_slot(2)
	check((data.get("structures", []) as Array).size() == 1, "save contains 1 structure")

	# 4) 读档恢复：建筑数量 / 冻气一致，格子索引正确
	var saved_frost: float = level.frost
	level.frost = 0.0
	for tower in level.towers.get_children():
		tower.queue_free()
	await process_frame
	level.restore_game(data)
	await process_frame
	check(level.towers.get_child_count() == tower_count, "restore tower count")
	check(absf(level.frost - saved_frost) < 0.01, "restore frost")
	var restored_tower = level.towers.get_child(0)
	check(level._find_structure_at(level.map_view.world_to_cell(restored_tower.global_position)) == restored_tower, "structure_cells indexed")

	# 5) 右键拆除：返还冻气且格子释放
	var frost_before: float = level.frost
	var demolish_cell: Vector2i = level.map_view.world_to_cell(restored_tower.global_position)
	level._demolish_structure(restored_tower)
	await process_frame
	check(level.towers.get_child_count() == 0, "demolish frees node")
	check(level.frost > frost_before, "demolish refunds frost")
	check(level._find_structure_at(demolish_cell) == null, "demolish frees cells")

	# 6) 暂停菜单存在且可开合
	var pause_menu = level.get_node_or_null("PauseMenu")
	check(pause_menu != null, "pause menu exists")
	level._toggle_pause_menu()
	check(paused, "tree paused after open")
	level._toggle_pause_menu()
	check(not paused, "tree resumed after close")

	save_manager.delete_slot(2)
	session_script.current_slot = -1
	session_script.pending_load_slot = -1
	if _failures > 0:
		print("SAVE_TEST_FAIL checks=%d failures=%d" % [_checks, _failures])
		quit(1)
	else:
		print("SAVE_TEST_OK checks=%d" % _checks)
		quit(0)
