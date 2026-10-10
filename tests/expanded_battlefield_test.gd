extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Field = preload("res://scripts/data/rts_battlefield.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)
func run() -> void:
	var s = Sim.new()
	check(s.WIDTH * s.HEIGHT == 4000, "Four times original map area")
	for base in Field.BASE_SITES:
		for camp in Field.CAMPS:
			check(not s.navigation.get_id_path(Vector2i(base), Vector2i(camp)).is_empty(), "All bases can reach both enemy camps")
	for pos in Field.BASE_SITES + Field.HOUSES + Field.CAMPS + Field.CHESTS + Field.WILDLIFE:
		check(s.walkable(Vector2i(pos)), "Landmark placed on land: " + str(pos))
	# Each bridge is a distinct crossing: the other two can be closed without isolating either bank.
	for kept_y in [10, 25, 40]:
		s.walls.clear()
		for y in [10, 11, 25, 26, 40, 41]:
			if y == kept_y or y == kept_y + 1: continue
			for x in range(Field.river_center(y) - 1, Field.river_center(y) + 2): s.walls.append({"x": x, "y": y, "ttl": 25.0})
		s.rebuild_navigation()
		var route: Array[Vector2i] = s.navigation.get_id_path(Vector2i(8, 25), Vector2i(73, 40))
		check(not route.is_empty(), "Route remains open through crossing " + str(kept_y))
		check(route.any(func(cell): return Field.crossing(cell) and cell.y in [kept_y, kept_y + 1]), "Path uses remaining bridge")
	s.walls.clear()
	s.rebuild_navigation()
	check(s.navigation.get_id_path(Vector2i(50, 25), Vector2i(54, 25)).is_empty(), "Island is isolated before spell")
	s.choose_card("mana")
	s.choose_card("supplies")
	s.choose_base(1)
	check(s.cast("bridge", Vector2(51, 25)) and not s.navigation.get_id_path(Vector2i(50, 25), Vector2i(54, 25)).is_empty(), "One ice bridge opens island")
	for kind in s.catalog:
		var u: Dictionary = s.add_unit(kind, 0, Vector2(5, 5))
		var speed: float = s.catalog[kind].move_speed
		check(speed >= 1.6 and speed <= 2.8, "Bounded movement speed: " + kind)
		s.move_unit(u, Vector2(15, 5), 0.1)
		var distance: float = s.point(u).distance_to(Vector2(5, 5))
		check(is_equal_approx(distance, speed * 0.1), "Actual displacement uses balanced speed: " + kind)
		s.set_point(u, Vector2(5, 5))
		u.path_revision = -1
		u.slow_time = 2.0
		u.slow = 0.3
		s.move_unit(u, Vector2(15, 5), 0.1)
		check(is_equal_approx(s.point(u).distance_to(Vector2(5, 5)), distance * 0.7), "Slow applies after speed balance: " + kind)
	var legacy := s.snapshot()
	legacy.erase("map_version")
	legacy.units = [s.units[0].duplicate(true)]
	legacy.units[0].x = 5.0
	legacy.units[0].y = 12.0
	var restored = Sim.new()
	check(restored.restore(legacy), "Old RTS saves migrate")
	check(restored.point(restored.units[0]) == Vector2(10, 24), "Old position scales once")
	var current := restored.snapshot()
	check(restored.restore(current) and restored.point(restored.units[0]) == Vector2(10, 24), "Current saves do not migrate twice")
	var game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.pick_card("supplies")
	game.pick_card("mana")
	game.sim.choose_base(1)
	await process_frame
	game.paused = true
	for scale_value in [8.6, 14.0, 21.0, 32.0]:
		game.zoom = scale_value
		game.center_camera(Vector2(40, 25))
		var spot := Vector2(42, 25)
		check(game.map_point(game.world_to_screen(spot)).distance_to(spot) < 0.001, "Camera world/input round trip at zoom " + str(scale_value))
	game.center_camera(Vector2(-100, -100))
	check(game.visible_world_rect().position.x >= -0.01 and game.visible_world_rect().position.y >= -0.01, "Camera clamps west and north")
	game.center_camera(Vector2(1000, 1000))
	check(game.visible_world_rect().end.x <= 80.01 and game.visible_world_rect().end.y <= 50.01, "Camera clamps east and south")
	game.toggle_drawer("recruit")
	game.filter_roster("骑乘")
	check(game.drawers.recruit.visible and game.train_buttons.values().filter(func(button): return button.visible).size() == 5, "Recruit drawer shows one family")
	game.toggle_drawer("research")
	check(not game.drawers.recruit.visible and game.drawers.research.visible, "Only one command panel opens at a time")
	game.paused = false
	game.set_mode("bridge")
	check(game.open_drawer.is_empty() and game.mode == "bridge", "Spell targeting closes blocking drawer")
	game.zoom = 21.0
	game.focus_home()
	game.tile_map.sync(game.sim, 0.0, false)
	var base: Dictionary = game.sim.buildings[0]
	var base_view: Sprite2D = game.tile_map.building_views[int(base.id)]
	check(base_view.global_position.distance_to(game.screen_point(base)) < 0.01, "Rendered sprites align with selection after camera movement")
	game.mode = "select"
	var soldier: Dictionary = game.sim.living(0)[0]
	var soldier_screen: Vector2 = game.world_to_screen(game.sim.point(soldier) + Vector2(0, -0.4))
	game.select_area(soldier_screen, soldier_screen)
	check(game.selected == [soldier.id], "Click selection follows camera transform")
	var order_event := InputEventMouseButton.new()
	order_event.button_index = MOUSE_BUTTON_RIGHT
	order_event.pressed = true
	order_event.position = game.world_to_screen(Vector2(18, 25))
	game._unhandled_input(order_event)
	check(soldier.order == "move" and Vector2(soldier.goal_x, soldier.goal_y).distance_to(Vector2(18, 25)) < 0.01, "Screen right-click sends correct world move order")
	game.center_camera(Vector2(42, 20))
	var spell_event := InputEventMouseButton.new()
	spell_event.button_index = MOUSE_BUTTON_LEFT
	spell_event.pressed = true
	spell_event.position = game.world_to_screen(Vector2(42, 12))
	game.set_mode("bridge")
	game._unhandled_input(spell_event)
	check(game.sim.walkable(Vector2i(42, 12)) and game.mode == "select", "Screen-targeted spell freezes intended river cell")
	var anchored: Vector2 = game.map_point(game.MAP_RECT.get_center())
	game.zoom_at(game.MAP_RECT.get_center(), 1.15)
	check(game.map_point(game.MAP_RECT.get_center()).distance_to(anchored) < 0.01, "Zoom preserves world point under cursor away from bounds")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.minimap.size * Vector2(0.75, 0.7)
	game.minimap._gui_input(click)
	check(game.camera_center.x > 50 and game.camera_center.y > 30, "Minimap click navigates camera while paused or active")
	game.queue_free()
	await process_frame
	print("EXPANDED_BATTLEFIELD_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
