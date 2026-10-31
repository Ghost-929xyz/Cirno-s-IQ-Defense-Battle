extends SceneTree
const Art = preload("res://scripts/effects/resource_art.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = load("res://scenes/tutorial.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    game.sim.choose_card("supplies")
    game.sim.choose_card("mana")
    game.selected = [game.sim.living(0)[0].id]
    assert(Art.FIRE_HEIGHT < 59.0 * 21 / 64)
    for site in game.sim.resource_sites:
        if site.kind not in ["gold_mine", "mana_spring"]: continue
        var top = game.sim.point(site) + Vector2(0, -1.6)
        assert(game.resource_hit(site, top), "Visible artwork must be clickable")
        assert(not game.resource_hit(site, game.sim.point(site) + Vector2(5, 0)))
        game.contextual_order(top)
        var unit = game.sim.entity(game.selected[0])
        assert(unit.order == "capture" and unit.target == site.id)
    game.torch_heat.sync()
    assert(game.torch_heat.patches.size() == game.sim.torch_positions().size())
    print("RESOURCE_ART_TEST_OK")
    game.queue_free()
    await process_frame
    quit()
