extends SceneTree
var game
var failures := 0
func expect(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func tick(seconds: float) -> void:
    for i in int(seconds * 10): game.sim.step(0.1)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    game = load("res://scenes/tutorial.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    var s = game.sim
    expect(not game.completed(), "Cards must require selection")
    s.choose_card("supplies")
    s.choose_card("mana")
    expect(game.completed(), "Cards complete")
    expect(s.living(1).is_empty(), "Safe training field")
    tick(100)
    expect(s.wave == 0, "No automatic waves")
    var ids: Array = s.living(0).map(func(u): return u.id)
    var site = s.resource_sites[0]
    s.command(ids, "capture", s.point(site), site.id)
    tick(80)
    expect(site.team == 0, "Resource reachable and capturable")
    var chest = s.chests[0]
    s.command(ids, "chest", s.point(chest), chest.id)
    tick(80)
    expect(s.chests.is_empty(), "Chest reachable")
    for kind in ["house", "barracks", "well", "academy"]:
        var built := false
        for y in range(22, 32):
            for x in range(33, 46):
                var pos := Vector2(x, y)
                if s.construction_error(kind, pos, ids).is_empty():
                    expect(s.construct(kind, pos, ids), "Construct " + kind)
                    tick(120)
                    built = s.buildings.any(func(b): return b.kind == kind and b.team == 0 and b.complete)
                    break
            if built: break
        expect(built, "Complete " + kind)
    expect(s.train_unit("archer"), "Training")
    tick(40)
    var research_ok := false
    for kind in s.catalog:
        if s.research_error(kind).is_empty():
            research_ok = s.research_unit(kind)
            break
    expect(research_ok, "Research available")
    var house = s.buildings.filter(func(b): return b.kind == "house")[0]
    s.command(ids, "garrison", s.point(house), house.id)
    tick(100)
    expect(not s.occupants(house.id).is_empty(), "Garrison reachable")
    s.evacuate(house.id)
    expect(s.actions.has("evacuate"), "Evacuation")
    game.lesson = 23
    game.enter_lesson()
    expect(s.cast("bridge", game.target_pos), "Valid bridge target")
    s.battle_allowed = true
    s.start_wave()
    expect(s.living(1).size() == 3, "Three training enemies")
    game.lesson = 26
    game.enter_lesson()
    game.retry_lesson()
    expect(game.lesson == 26, "Retry retains lesson")
    print("TUTORIAL_TEST failures=%d" % failures)
    game.queue_free()
    await process_frame
    quit(failures)
