extends SceneTree
func _initialize() -> void: call_deferred("run")
func grab() -> Image:
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    return root.get_texture().get_image()
func changes(a: Image, b: Image, rect: Rect2i) -> int:
    var count := 0
    for y in range(rect.position.y, rect.end.y):
        for x in range(rect.position.x, rect.end.x):
            if a.get_pixel(x,y) != b.get_pixel(x,y): count += 1
    return count
func run() -> void:
    var game = load("res://scenes/tutorial.tscn").instantiate()
    root.add_child(game)
    game.sim.choose_card("supplies")
    game.sim.choose_card("mana")
    game.next_lesson()
    await create_timer(0.3).timeout
    game.paused = true
    game.lesson_panel.hide()
    game.zoom = 32
    game.zoom_target = 32
    game.center_camera(Vector2(46,22))
    for site in game.sim.resource_sites: game.sim.reveal_circle(game.sim.point(site),6)
    game.sim.visibility_revision += 1
    game.tile_map.sync(game.sim,0,true)
    var spring = game.sim.resource_sites[1]
    var view = game.tile_map.prop_views[spring.id]
    var local_rect = view.get_rect()
    var transform = view.get_global_transform_with_canvas()
    var pos = transform * (local_rect.position + local_rect.size * Vector2(0.25,0.55))
    var extent = local_rect.size * Vector2(0.5,0.3) * game.zoom / 64.0
    var region = Rect2i(pos,extent)
    game.sim.elapsed = 5
    var neutral_a = await grab()
    game.sim.elapsed = 6
    var neutral_b = await grab()
    var still = changes(neutral_a,neutral_b,region)
    spring.team = 0
    game.sim.resource_sites[0].team = 0
    game.sim.resource_sites[2].team = 0
    game.sim.elapsed = 5
    var active_a = await grab()
    game.sim.elapsed = 6
    var active_b = await grab()
    var flowing = changes(active_a,active_b,region)
    active_b.save_png("res://.tools/props-final-active.png")
    neutral_b.save_png("res://.tools/props-final-neutral.png")
    print("SPRING_RENDER_TEST neutral_changes=%d active_changes=%d" % [still,flowing])
    var failed = still != 0 or flowing == 0
    game.queue_free()
    await process_frame
    quit(1 if failed else 0)
