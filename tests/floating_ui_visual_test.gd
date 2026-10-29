extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.3).timeout
	game.pick_card("mana")
	game.pick_card("supplies")
	game.confirm_opening_cards()
	await process_frame
	game.sim.choose_base(1)
	game.sim.gold = 1800
	game.select_all()
	await create_timer(0.3).timeout
	game.refresh_ui()
	await capture("res://.tools/floating-hud.png")
	game.toggle_drawer("build")
	await capture("res://.tools/compact-build.png")
	game.toggle_drawer("research")
	game.filter_roster("特战")
	await capture("res://.tools/compact-research.png")
	game.toggle_dock()
	await capture("res://.tools/compact-collapsed.png")
	game.toggle_drawer("recruit")
	game.filter_roster("步战")
	game.toggle_overview()
	await create_timer(0.2).timeout
	await capture("res://.tools/floating-overview.png")
	game.toggle_overview()
	game.advance_wave()
	game.wave_intro.set_process(false)
	game.wave_intro.advance(0.8)
	await capture("res://.tools/floating-wave-typing.png")
	game.wave_intro.advance(0.65)
	await capture("res://.tools/floating-wave-full.png")
	game.wave_intro.advance(0.96)
	await capture("res://.tools/floating-wave-fade.png")
	game.wave_intro.advance(1.0)
	await create_timer(0.2).timeout
	await capture("res://.tools/floating-wave-restored.png")
	print("FLOATING_UI_VISUAL_OK")
	quit()
