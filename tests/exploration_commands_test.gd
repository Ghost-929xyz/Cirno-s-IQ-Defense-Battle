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

func fresh(seed_value := 10086):
	var s = Sim.new()
	s.generate_map(seed_value)
	s.choose_card("supplies")
	s.choose_card("mana")
	return s

func capture(name_text: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/exploration-" + name_text + ".png")

func run() -> void:
	for seed_value in [0, 7, 10086, 20261022, 2147483647]:
		var seeded = fresh(seed_value)
		check(seeded.phase == "prep" and seeded.point(seeded.buildings[0]) == Field.CENTRAL_BASE, "Cards start directly at central base")
		check(seeded.resource_sites.size() == 9 and seeded.generated_layout.roads.is_empty(), "Seed has nine resource sites and no road layer")
		check(seeded.resource_sites.all(func(site): return not seeded.resource_known(site)), "Every resource location starts unknown")
		for site in seeded.resource_sites:
			check(not seeded.walkable(Vector2i(seeded.point(site))) and seeded.reachable_goal(Field.CENTRAL_BASE, seeded.point(site)) != Vector2i(-1, -1), "Every solid resource has a reachable interaction edge from central camp")
	var s = fresh()
	check(s.is_visible(Field.CENTRAL_BASE) and s.torch_positions().size() == 4 and not s.is_visible(Vector2(72, 7)), "Four camp torches light only the opening surroundings")
	var initial_gold: float = s.gold
	s.step_building(s.buildings[0], 10.0)
	check(s.gold == initial_gold, "Base provides no passive gold")
	var scout: Dictionary = s.living(0)[0]
	var mine: Dictionary = s.resource_sites.filter(func(site): return site.kind == "gold_mine")[0]
	s.set_point(scout, s.point(mine) + Vector2(1, 0))
	s.update_visibility()
	check(mine.discovered and s.is_visible(s.point(mine)), "Scouting discovers a resource")
	s.command([scout.id], "capture", s.point(mine), mine.id)
	s.step_resources(4.9)
	check(mine.team == -1 and mine.capture > 4, "Occupation requires time")
	s.step_resources(0.2)
	check(mine.team == 0 and scout.order == "idle", "Occupation completes and frees the unit")
	initial_gold = s.gold
	s.step_resources(2)
	check(is_equal_approx(s.gold - initial_gold, 6.0), "Occupied mine produces three gold per second")
	var spring: Dictionary = s.resource_sites.filter(func(site): return site.kind == "mana_spring")[0]
	spring.team = 0
	var mana: float = s.baka
	s.step_resources(2)
	check(is_equal_approx(s.baka - mana, 4), "Owned spring produces BAKA")
	var tower: Dictionary = s.resource_sites.filter(func(site): return site.kind == "vision_tower")[0]
	tower.team = 0
	s.update_visibility()
	var remote: Dictionary = s.resource_sites.filter(func(site): return not s.is_visible(s.point(site)))[0]
	check(s.resource_known(remote) and not s.is_visible(s.point(remote)) and not remote.discovered, "Tower reveals resource intelligence without clearing remote fog")
	tower.team = -1
	s.set_point(scout, Field.CENTRAL_BASE)
	mine.team = -1
	s.update_visibility()
	check(s.is_explored(s.point(mine)) and not s.is_visible(s.point(mine)) and mine.discovered, "Exploration memory survives loss of sight")
	# Isolated combat in the central dry clearing.
	s = fresh()
	s.units.clear()
	var archer: Dictionary = s.add_unit("archer", 0, Vector2(38, 25))
	var foe: Dictionary = s.add_unit("swordsman", 1, Vector2(41, 25))
	foe.hp = 10000.0
	s.update_visibility()
	s.command([archer.id], "attack_move", Vector2(44, 25))
	s.step_unit(archer, 0.05)
	check(foe.hp < 10000 and archer.order == "attack_move", "Attack move engages encountered enemies while retaining its destination")
	foe.hp = 0
	for i in 100: s.step_unit(archer, 0.1)
	check(archer.order == "idle" and s.point(archer).distance_to(Vector2(44, 25)) < 0.4, "Attack move resumes and reaches its destination after combat")
	s.set_point(archer, Vector2(38, 25))
	foe.hp = 10000
	s.set_point(foe, Vector2(44, 25))
	s.command([archer.id], "hold", Vector2.ZERO)
	for i in 20: s.step_unit(archer, 0.1)
	check(s.point(archer) == Vector2(38, 25) and foe.hp == 10000, "Hold does not chase beyond weapon range")
	s.set_point(foe, Vector2(41, 25))
	s.step_unit(archer, 1)
	check(s.point(archer) == Vector2(38, 25) and foe.hp < 10000, "Hold fires without moving")
	foe.hp = 0
	s.command([archer.id], "move", Vector2(40, 23))
	s.command([archer.id], "move", Vector2(43, 23), -1, true)
	check(archer.orders.size() == 1 and archer.goal_x == 40, "Shift appends without replacing the first order")
	for i in 100: s.step_unit(archer, 0.1)
	check(archer.orders.is_empty() and s.point(archer).distance_to(Vector2(43, 23)) < 0.4, "Queued waypoints execute sequentially")
	s.command([archer.id], "move", Vector2(38, 25))
	s.command([archer.id], "attack_move", Vector2(42, 25), -1, true)
	s.command([archer.id], "stop", Vector2.ZERO)
	var stopped: Vector2 = s.point(archer)
	s.step_unit(archer, 1)
	check(archer.orders.is_empty() and s.point(archer) == stopped, "Stop cancels the queue and halts movement")
	s.elapsed += 10
	check(s.idle_units().has(archer), "Stopped noncombat troops are reported idle")
	var base: Dictionary = s.buildings[0]
	check(s.set_rally(base.id, Vector2(43, 27)) and s.set_rally(base.id, Vector2(44, 28), true), "Producer accepts a multi-point rally route")
	base.queue = ["swordsman"]
	s.step_building(base, 3.0)
	var recruit: Dictionary = s.living(0).back()
	check(recruit.order == "move" and recruit.orders.size() == 1 and recruit.goal_x == 43, "New troops inherit the producer's rally route")
	foe.hp = 10000
	s.hit(foe, archer, 1, false)
	check(s.attack_alerts.size() == 1 and s.unit_in_combat(archer) and not s.idle_units().has(archer), "Friendly damage creates an alert and combat status")
	s.hit(foe, archer, 1, false)
	check(s.attack_alerts.size() == 1, "Nearby repeated hits merge into one minimap alert")
	s.control_groups[2] = [archer.id, recruit.id]
	s.resource_sites[0].team = 0
	s.resource_sites[0].discovered = true
	s.update_visibility()
	var restored = Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "Exploration save restores through real JSON")
	check(restored.control_groups[2].size() == 2 and restored.buildings[0].rally.size() == 2 and restored.entity(recruit.id).orders.size() == 1, "Save preserves groups, rally routes and unit queues")
	check(restored.resource_sites[0].team == 0 and restored.explored_cells.size() >= s.explored_cells.size(), "Save preserves resource ownership and exploration")
	var legacy: Dictionary = s.snapshot()
	for key in ["resource_sites", "explored_cells", "control_groups", "exploration_version"]: legacy.erase(key)
	legacy.map_generator_version = 1
	check(restored.restore(legacy) and restored.resource_sites.size() == 9, "Older saves acquire exploration resources without losing their army")
	var queued = fresh()
	var builder: Dictionary = queued.living(0)[0]
	queued.command([builder.id], "move", Vector2(43, 25))
	check(queued.construct("well", Vector2(42, 29), [builder.id], true) and builder.order == "move" and builder.orders[0].order == "repair", "Shift construction retains movement and queues the building work")
	queued.command([builder.id], "garrison", queued.point(queued.buildings[0]), queued.buildings[0].id)
	queued.command([builder.id], "move", Vector2(43, 23), -1, true)
	for i in 160: queued.step_unit(builder, 0.1)
	check(builder.home == -1 and builder.order == "idle" and queued.point(builder).distance_to(Vector2(43, 23)) < 0.4, "Queued movement resumes after entering and leaving a garrison")
	queued.attack_alerts = [{"x": 40, "y": 25, "until": queued.elapsed + 0.1}]
	queued.step(0.2)
	check(queued.attack_alerts.is_empty(), "Expired attack alerts disappear")
	if DisplayServer.get_name() != "headless":
		var menu = load("res://scenes/menu.tscn").instantiate()
		root.add_child(menu)
		menu._show_expedition_help()
		await capture("help")
		menu.queue_free()
		await process_frame
	var game = load("res://scenes/expedition.tscn").instantiate()
	game.random_map_enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.pick_card("mana")
	game.pick_card("supplies")
	game.confirm_opening_cards()
	game.sim.update_visibility()
	game.tile_map.sync(game.sim, 0, true)
	game.refresh_ui()
	game.fog.refresh()
	check(game.sim.phase == "prep" and (not is_instance_valid(game.overlay) or game.overlay.is_queued_for_deletion()), "UI proceeds from card confirmation directly into play")
	check(game.tile_map.get_node("Paths").get_used_cells().is_empty(), "Hand-painted map also removes road tiles")
	var enemy: Dictionary = game.sim.living(1)[0]
	check(not game.tile_map.unit_views[enemy.id].visible and not game.building_hit(game.sim.buildings[1], game.sim.point(game.sim.buildings[1])), "Fog hides remote enemy sprites and prevents unseen building selection")
	check(game.fog.mask.get_pixel(72, 7).r == 0 and game.fog.mask.get_pixel(72, 7).g == 0, "Unexplored map remains fully concealed")
	game.selected = [game.sim.living(0)[0].id]
	game.assign_control_group(1)
	game.center_camera(Vector2(65, 25))
	game.select_control_group(1)
	game.select_control_group(1)
	check(game.camera_center.distance_to(game.sim.point(game.sim.entity(game.selected[0]))) < 1, "Double number press centers on the selected group")
	check(game.group_buttons[1].text.contains("1人") and game.group_buttons[1].text.contains("100%"), "Group UI displays member count and health")
	game.select_idle_unit()
	check(game.selected.size() == 1 and game.idle_button.text.contains("空闲"), "Idle indicator cycles to a unit")
	game.world_overlay.queue_redraw()
	await capture("opening")
	var tower_ui: Dictionary = game.sim.resource_sites.filter(func(site): return site.kind == "vision_tower")[0]
	tower_ui.team = 0
	game.sim.update_visibility()
	game.toggle_overview()
	await capture("intelligence")
	game.toggle_overview()
	var explorer: Dictionary = game.sim.living(0)[0]
	var nearby_site: Dictionary = game.sim.resource_sites[0]
	game.sim.set_point(explorer, game.sim.point(nearby_site) + Vector2(1, 0))
	game.sim.update_visibility()
	game.center_camera(game.sim.point(nearby_site))
	game.sim.command([explorer.id], "capture", game.sim.point(nearby_site), nearby_site.id)
	game.sim.step_resources(2.5)
	game.tile_map.sync(game.sim, 0, true)
	game.world_overlay.queue_redraw()
	game.fog.refresh()
	await capture("resource")
	game.selected = [explorer.id]
	game.sim.command(game.selected, "stop", Vector2.ZERO)
	var map_click := InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_RIGHT
	map_click.pressed = true
	map_click.position = game.minimap.world_to_local(Vector2(43, 23))
	game.minimap._gui_input(map_click)
	map_click.shift_pressed = true
	map_click.position = game.minimap.world_to_local(Vector2(44, 23))
	game.minimap._gui_input(map_click)
	check(explorer.order == "move" and explorer.orders.size() == 1 and is_equal_approx(explorer.orders[0].x, 44), "Minimap right clicks issue movement and Shift waypoints")
	game.selected.clear()
	game.selected_building = game.sim.buildings[0].id
	map_click.shift_pressed = false
	game.minimap._gui_input(map_click)
	check(game.sim.buildings[0].rally.size() == 1 and is_equal_approx(game.sim.buildings[0].rally[0].x, 44), "Minimap can set a selected producer's rally point")
	game.queue_free()
	await process_frame
	print("EXPLORATION_COMMANDS_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
