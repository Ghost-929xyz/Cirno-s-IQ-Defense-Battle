extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	var s = Sim.new()
	s.configure_terrain([], [Vector2i(12, 10)])
	s.phase = "prep"
	var house: Dictionary = s.add_building("house", -1, Vector2(14, 10))
	check(not s.walkable(Vector2i(12, 10)) and not s.walkable(Vector2i(14, 10)), "Trees and houses block navigation")
	check(not s.segment_clear(Vector2(10, 10), Vector2(16, 10)), "Straight paths cannot cross obstacles")
	check(not s.segment_clear(Vector2(11, 10), Vector2(12, 11)), "Body clearance prevents cutting a tree corner")
	var soldier: Dictionary = s.add_unit("swordsman", 0, Vector2(10, 10))
	s.move_unit(soldier, Vector2(16.2, 10.3), 0.05)
	check(soldier.path.size() < s.navigation.get_id_path(Vector2i(10, 10), Vector2i(16, 10)).size(), "Path smoothing removes grid waypoints")
	var safe := true
	for i in 160:
		var before: Vector2 = s.point(soldier)
		s.move_unit(soldier, Vector2(16.2, 10.3), 0.05)
		safe = safe and s.segment_clear(before, s.point(soldier))
	check(safe and s.point(soldier).distance_to(Vector2(16.2, 10.3)) < 0.01, "Smoothed route reaches a fractional destination without crossing obstacles")
	s.set_point(soldier, Vector2(5.2, 5.1))
	soldier.path_revision = -1
	s.move_unit(soldier, Vector2(9.7, 7.4), 0.1)
	check(soldier.path.size() == 1, "Open ground uses a single direct segment")
	check(absf(s.point(soldier).x - 5.2) > 0.01 and absf(s.point(soldier).y - 5.1) > 0.01, "Open-ground movement advances on both axes")
	check(s.reachable_goal(s.point(soldier), s.point(house)) != Vector2i(-1, -1), "Blocked house remains accessible for garrison orders")
	s.command([soldier.id], "garrison", s.point(house), house.id)
	for i in 250: s.step_unit(soldier, 0.05)
	check(soldier.home == house.id, "Soldier enters a house from outside its obstacle footprint")
	s.evacuate(house.id)
	check(s.position_clear(s.point(soldier)), "Evacuation places the soldier outside the blocked house")
	var foe: Dictionary = s.add_unit("swordsman", 1, Vector2(15, 10))
	s.hit(foe, house, 10000, false)
	check(s.walkable(Vector2i(14, 10)), "Destroyed house releases its obstacle")
	# Navigation changes invalidate cached smooth paths as well as grid routes.
	s.set_point(soldier, Vector2(5, 5))
	soldier.path_revision = -1
	s.move_unit(soldier, Vector2(10, 5), 0.1)
	s.walls.append({"x": 7, "y": 5, "ttl": 25.0})
	s.rebuild_navigation()
	safe = true
	for i in 100:
		var before: Vector2 = s.point(soldier)
		s.move_unit(soldier, Vector2(10, 5), 0.05)
		safe = safe and s.segment_clear(before, s.point(soldier))
	check(safe and s.point(soldier).distance_to(Vector2(10, 5)) < 0.01, "New ice wall replans an existing smooth route")
	s = Sim.new()
	s.choose_card("supplies")
	s.choose_card("mana")
	s.choose_base(1)
	check(not s.snowing(), "Idle enemy camp guards do not start snowfall")
	s.start_wave()
	check(s.snowing(), "Incoming wave starts snowfall")
	s.update_winter(12.0)
	check(s.snow_cover > 0.6 and s.water_frozen and s.walkable(Vector2i(42, 12)), "Accumulation freezes water into walkable ice")
	check(not s.walkable(Vector2i(0, 0)), "Frozen water preserves the map boundary")
	check(not s.walkable(Vector2i(29, 27)), "Frozen water never removes house obstacles")
	var swimmer: Dictionary = s.add_unit("archer", 0, Vector2(42, 12))
	var saved := JSON.parse_string(JSON.stringify(s.snapshot())) as Dictionary
	var restored = Sim.new()
	check(restored.restore(saved) and restored.water_frozen and restored.walkable(Vector2i(42, 12)), "Saving and restoring preserves winter traversal")
	check(s.cast("bridge", Vector2(42, 12)), "Spell bridge remains independent of seasonal ice")
	var bridged: Dictionary = s.add_unit("swordsman", 0, Vector2(42, 12))
	s.set_point(swimmer, Vector2(41, 16))
	check(s.water(Vector2i(41, 16)), "Thaw test starts a unit on unbridged water")
	for u in s.units:
		if u.team == 1 and u.get("assault_wave", 0) > 0: u.hp = 0
	check(not s.snowing(), "Clearing the invading army stops snowfall")
	s.update_winter(3.0)
	check(not s.water_frozen and not s.walkable(Vector2i(41, 16)), "Thaw restores normal water obstacles")
	check(s.position_clear(s.point(swimmer)) and not s.water(Vector2i(s.point(swimmer).round())), "Thaw relocates waterborne units to shore")
	check(s.walkable(Vector2i(s.point(bridged).round())) and s.point(bridged).distance_to(Vector2(42, 12)) < 2 and s.walkable(Vector2i(42, 12)), "Thaw preserves spell bridges and their units")
	s.phase = "victory"
	s.step(10.0)
	check(s.snow_cover == 0.0, "Accumulated snow also melts after victory")
	var game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.paused = true
	var trees: Array[Vector2i] = game.tile_map.terrain_obstacle_cells()
	check(not trees.is_empty(), "Painted tree cells are read from the map")
	check(trees.all(func(cell): return not game.sim.walkable(cell)), "Every painted tree blocks simulation navigation")
	game.sim.choose_card("supplies")
	game.sim.choose_card("mana")
	game.sim.choose_base(1)
	game.sim.start_wave()
	game.sim.update_winter(12.0)
	game.winter_weather.sync(game.sim, false)
	check(game.winter_weather.flakes.visible and game.winter_weather.flakes.emitting, "Wave displays snowflake particles")
	check(is_equal_approx(game.winter_weather.frost.get_shader_parameter("coverage"), game.sim.snow_cover), "Ground and water frost follow accumulated snow")
	game.winter_weather.sync(game.sim, true)
	check(game.winter_weather.flakes.speed_scale == 0.0, "Pause freezes snowfall")
	for u in game.sim.units:
		if u.team == 1 and u.get("assault_wave", 0) > 0: u.hp = 0
	game.winter_weather.sync(game.sim, false)
	check(not game.winter_weather.flakes.visible and not game.winter_weather.flakes.emitting, "Wave end removes snowfall immediately")
	game.sim.update_winter(10.0)
	game.winter_weather.sync(game.sim, false)
	check(not game.winter_weather.surface.visible, "Fully melted ground hides the frost surface")
	game.queue_free()
	await process_frame
	print("WINTER_NAVIGATION_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
