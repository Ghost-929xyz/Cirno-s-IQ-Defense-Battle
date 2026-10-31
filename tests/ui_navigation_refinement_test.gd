extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var s = Sim.new()
	s.configure_terrain([])
	s.phase = "prep"
	var a: Dictionary = s.add_unit("swordsman",0,Vector2(20-0.4,20))
	var b: Dictionary = s.add_unit("swordsman",0,Vector2(20+0.4,20))
	check(s.point(a) == Vector2(19.6,20) and s.point(b) == Vector2(20.4,20),"Separate bodies may share a coarse navigation cell")
	s.units.clear()
	s.add_unit("swordsman",0,Vector2(20,19.25))
	s.add_unit("swordsman",0,Vector2(20,20.75))
	a = s.add_unit("swordsman",0,Vector2(15,20))
	var deviation := 0.0
	var distance := 0.0
	var clear := true
	for i in 120:
		var before: Vector2 = s.point(a)
		s.move_unit(a,Vector2(25,20),0.05)
		deviation = maxf(deviation,absf(s.point(a).y-20))
		distance += before.distance_to(s.point(a))
		clear = clear and s.unit_position_clear(s.point(a),a.kind,a.id)
	check(clear and s.point(a).distance_to(Vector2(25,20)) < 0.1 and deviation < 0.01 and distance <= 10.01,"Infantry traverses the real gap directly without a cell-sized detour")
	print("NARROW_ROUTE distance=%.2f sideways=%.2f" % [distance,deviation])
	var game = load("res://scenes/expedition.tscn").instantiate()
	game.random_map_enabled = false
	root.add_child(game)
	game.sim.choose_card("supplies")
	game.sim.choose_card("mana")
	game.show_phase_overlay()
	game.selected = game.sim.living(0).map(func(u): return u.id)
	game.sim.command(game.selected,"move",Vector2(45,30))
	check(game.command_markers() == [Vector2(45,30)],"A group move displays exactly one shared destination")
	game.sim.command(game.selected,"move",Vector2(47,32),-1,true)
	check(game.command_markers() == [Vector2(47,32)],"Queued commands display only the final shared destination")
	game.sim.command(game.selected,"stop",Vector2.ZERO)
	check(game.command_markers().is_empty(),"Stopping removes stale destination markers")
	game.open_game_menu()
	check(game.simulation_blocked(),"Menu pauses simulation")
	var before: float = game.sim.elapsed
	await create_timer(0.15).timeout
	check(game.sim.elapsed == before,"Time stays frozen while using the archive menu")
	await capture("res://.tools/refined-pause-menu.png")
	game.game_menu.show_page("save")
	check(game.game_menu.panel.get_children().filter(func(n): return n is Button).size() == 4,"In-game archive contains three slots and a back button")
	await capture("res://.tools/refined-game-save.png")
	game.game_menu.show_help()
	await capture("res://.tools/refined-help.png")
	game.close_game_menu()
	check(not game.simulation_blocked(),"Closing menu resumes an unpaused game")
	game.paused = true
	game.open_game_menu()
	game.close_game_menu()
	check(game.simulation_blocked(),"Closing menu preserves prior manual pause")
	game.queue_free()
	await process_frame
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	menu._on_new_game_pressed()
	await capture("res://.tools/refined-archive.png")
	check(is_instance_valid(menu._seed_input),"New-game archive retains seed input")
	menu._on_options_pressed()
	await capture("res://.tools/refined-settings.png")
	menu.queue_free()
	await process_frame
	print("UI_NAVIGATION_REFINEMENT checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
