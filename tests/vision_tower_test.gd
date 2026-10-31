extends SceneTree
const Art = preload("res://scripts/effects/resource_art.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = load("res://scenes/tutorial.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    var sim = game.sim
    sim.choose_card("supplies")
    sim.choose_card("mana")
    var site = sim.resource_sites.filter(func(s): return s.kind == "vision_tower")[0]
    var unit = sim.living(0)[0]
    sim.set_point(unit, sim.point(site) + Vector2(1, 0))
    sim.update_visibility()
    game.vision_crystal.sync()
    var light = game.vision_crystal.lights[site.id]
    assert(not light.visible, "Neutral tower must not emit active glow")
    game.selected = [unit.id]
    var top = sim.point(site) + Vector2(0, -2.1)
    assert(game.resource_hit(site, top), "Tower crown must be clickable")
    game.contextual_order(top)
    assert(unit.order == "capture" and unit.target == site.id)
    sim.step_resources(2.0)
    game.vision_crystal.sync()
    assert(not light.visible, "Partial capture must not activate tower")
    sim.step_resources(3.1)
    assert(site.team == 0)
    game.vision_crystal.sync()
    assert(light.visible, "Capture must light the crystal")
    for zoom in [12.0, 21.0, 32.0]:
        game.zoom = zoom
        game.vision_crystal.sync()
        var center = game.screen_point(site) + Art.tower_crystal_offset() * zoom / game.CELL
        assert((light.position + light.size * 0.5).distance_to(center) < 0.01)
    var saved = sim.snapshot().duplicate(true)
    site.team = 1
    game.vision_crystal.sync()
    assert(not light.visible, "Losing ownership must extinguish glow")
    assert(sim.restore(saved))
    sim.update_visibility()
    game.vision_crystal.sync()
    assert(light.visible, "Loaded ownership must restore glow")
    sim.visible_cells.clear()
    game.vision_crystal.sync()
    assert(not light.visible, "Glow must not reveal a fogged tower")
    sim.resource_sites.clear()
    game.vision_crystal.sync()
    assert(game.vision_crystal.lights.is_empty())
    print("VISION_TOWER_TEST_OK")
    game.queue_free()
    await process_frame
    quit()
