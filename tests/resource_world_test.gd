extends SceneTree
const Art = preload("res://scripts/effects/resource_art.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures += 1
        push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
    var game = load("res://scenes/tutorial.tscn").instantiate()
    root.add_child(game)
    game.set_process(false)
    var s = game.sim
    s.choose_card("supplies")
    s.choose_card("mana")
    game.show_phase_overlay()
    var unit = s.living(0)[0]
    for site in s.resource_sites:
        for dx in [-1,0,1]:
            check(not s.walkable(Vector2i(s.point(site)) + Vector2i(dx,0)), "Resource footprint blocks navigation")
        check(s.reachable_goal(s.point(unit), s.point(site)) != Vector2i(-1,-1), "Resource has a reachable interaction edge")
        s.command([unit.id], "capture", s.point(site), site.id)
        for i in 1400:
            s.step(0.05)
            if s.prop_obstacles.has(Vector2i(s.point(unit).round())):
                check(false, "Moving unit penetrated a resource")
                break
            if site.team == 0: break
        check(site.team == 0, "Unit walks around obstacles and completes capture")
    var fire = s.torch_positions()[0]
    check(not s.walkable(Vector2i(fire)), "Campfire blocks walking")
    check(not s.segment_clear(fire - Vector2(2,0), fire + Vector2(2,0)), "Direct motion cannot pass through campfire")
    check(not s.construct("well", fire, [unit.id]), "Building cannot be placed on campfire")
    s.set_point(unit, s.free_unit_position(fire - Vector2(3,0), unit.kind, unit.id))
    s.command([unit.id], "move", fire + Vector2(3,0))
    for i in 1000:
        s.step(0.05)
        if s.prop_obstacles.has(Vector2i(s.point(unit).round())):
            check(false, "Unit crossed campfire collision")
            break
        if unit.order == "idle": break
    check(s.point(unit).distance_to(fire + Vector2(3,0)) < 0.4, "Unit finds a route around the campfire")
    var chest = s.chests[0]
    var chest_pos = s.point(chest)
    s.reveal_circle(chest_pos, 4)
    game.tile_map.sync(s, 0, true)
    var treasure_view = game.tile_map.treasure_views[chest.id]
    var treasure_point = treasure_view.get_global_transform_with_canvas() * treasure_view.offset
    game.select_area(treasure_point, treasure_point)
    game.update_building_feedback()
    check(game.selected_prop == chest.id and treasure_view.material.get_shader_parameter("outline_amount") == 1.0, "Treasure uses building selection contour")
    check(not s.walkable(Vector2i(chest_pos)), "Treasure blocks until collected")
    s.command([unit.id], "chest", chest_pos, chest.id)
    for i in 1400:
        s.step(0.05)
        if s.chests.is_empty(): break
    check(s.chests.is_empty() and s.walkable(Vector2i(chest_pos)), "Picking up treasure restores navigation")
    var snapshot = s.snapshot().duplicate(true)
    snapshot.units[0].x = fire.x
    snapshot.units[0].y = fire.y
    check(s.restore(snapshot), "Old save restores")
    check(s.position_clear(s.point(s.units[0])), "Loading relocates a unit inside a new obstacle")
    game.tile_map.sync(s, 0, true)
    game.selected.clear()
    for site in s.resource_sites:
        s.reveal_circle(s.point(site), 4)
        game.tile_map.sync(s, 0, true)
        var view = game.tile_map.prop_views[site.id]
        check(view.texture.get_width() == Art.PROP_PIXELS[site.kind] and view.scale == Vector2.ONE, "Prop shares the terrain pixel scale")
        var point = view.get_global_transform_with_canvas() * (view.offset + Vector2(0,-8))
        game.select_area(point, point)
        game.update_building_feedback()
        check(game.selected_prop == site.id and view.material.get_shader_parameter("outline_amount") == 1.0, "Resource selection uses building highlight")
        check(view.material.get_shader_parameter("occupied"), "Captured material changes to active state")
        site.team = -1
        game.tile_map.sync(s,0,true)
        check(not view.material.get_shader_parameter("occupied"), "Losing ownership restores dormant material")
    var mouse_down := InputEventMouseButton.new()
    mouse_down.button_index = MOUSE_BUTTON_LEFT
    mouse_down.pressed = true
    game.lesson_panel.get_node("TutorialDragHandle").gui_input.emit(mouse_down)
    check(game.panel_dragging, "Pressing teaching header begins dragging")
    var motion := InputEventMouseMotion.new()
    motion.position = Vector2(-500, 200)
    game._input(motion)
    var mouse_up := InputEventMouseButton.new()
    mouse_up.button_index = MOUSE_BUTTON_LEFT
    mouse_up.pressed = false
    game._input(mouse_up)
    check(not game.panel_dragging and game.lesson_panel.position.x < 735, "Header drag moves the hint and release ends dragging")
    game.toggle_lesson_panel()
    check(game.lesson_folded and not game.lesson_body.visible and game.lesson_panel.size.y == 34, "Teaching hint folds upward to a handle")
    game.lesson_panel.position = Vector2(1500,-200)
    game.clamp_lesson_panel()
    check(game.lesson_panel.position.x <= 750 and game.lesson_panel.position.y == 0, "Teaching handle stays inside the viewport")
    game.toggle_lesson_panel()
    check(game.lesson_body.visible and game.lesson_panel.size.y == 249, "Teaching hint expands again")
    print("RESOURCE_WORLD_TEST checks=%d failures=%d" % [checks, failures])
    game.queue_free()
    await process_frame
    quit(failures)
