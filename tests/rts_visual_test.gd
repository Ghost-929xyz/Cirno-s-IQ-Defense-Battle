extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	menu._show_expedition_help()
	await create_timer(0.3).timeout
	root.get_texture().get_image().save_png("res://.tools/rts-help.png")
	menu.queue_free()
	await process_frame
	var scene = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png("res://.tools/rts-cards.png")
	scene.pick_card("supplies")
	scene.pick_card("mana")
	scene.confirm_opening_cards()
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("res://.tools/rts-base.png")
	scene.sim.choose_base(1)
	scene.sim.gold = 1800
	scene.select_all()
	scene.select_all()
	scene.sim.construct("barracks", Vector2(13, 25), scene.selected)
	scene.sim.cast("bridge", Vector2(42, 12))
	scene.sim.start_wave()
	await create_timer(3.0).timeout
	root.get_texture().get_image().save_png("res://.tools/rts-live.png")
	scene.paused = true
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("res://.tools/rts-battle.png")
	scene.toggle_drawer("recruit")
	scene.filter_roster("骑乘")
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("res://.tools/rts-recruit.png")
	scene.toggle_drawer("recruit")
	scene.toggle_drawer("build")
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("res://.tools/rts-build-orders.png")
	scene.toggle_drawer("build")
	scene.zoom = 8.6
	scene.center_camera(Vector2(40, 25))
	await create_timer(0.2).timeout
	root.get_texture().get_image().save_png("res://.tools/rts-overview.png")
	print("RTS_VISUAL_OK")
	quit()
