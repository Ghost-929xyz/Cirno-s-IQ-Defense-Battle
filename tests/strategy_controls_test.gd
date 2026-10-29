extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func press(game: Node, key: Key, ctrl := false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	event.ctrl_pressed = ctrl
	game._unhandled_input(event)

func right_click(game: Node, pos: Vector2, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.shift_pressed = shift
	event.position = game.world_to_screen(pos)
	game._unhandled_input(event)

func run() -> void:
	var game = load("res://scenes/expedition.tscn").instantiate()
	game.random_map_enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.pick_card("mana")
	game.pick_card("supplies")
	game.confirm_opening_cards()
	game.sim.choose_base(1)
	game.show_phase_overlay()
	game.refresh_ui()
	game.zoom = 21.0
	game.center_camera(Vector2(40, 25))
	var anchor := Vector2(700, 300)
	var anchored_world: Vector2 = game.map_point(anchor)
	game.zoom_at(anchor, 1.15)
	check(game.zoom == 21.0 and game.zoom_target > game.zoom, "Wheel changes a target without jumping the rendered scale")
	var previous := 21.0
	for i in 12:
		game.update_smooth_zoom(1.0 / 60.0)
		check(game.zoom > previous and game.zoom < game.zoom_target, "Zoom progresses smoothly without overshoot")
		check(game.map_point(anchor).distance_to(anchored_world) < 0.001, "Cursor world anchor remains fixed throughout zoom")
		previous = game.zoom
	game.zoom_at(anchor, 1.15)
	check(is_equal_approx(game.zoom_target, 21.0 * 1.15 * 1.15), "Rapid wheel ticks accumulate on the target")
	game.zoom_at(anchor, 1.0 / (1.15 * 1.15 * 1.15))
	game.update_smooth_zoom(1.0 / 60.0)
	check(game.zoom < previous, "Reversing the wheel reverses zoom without a jump")
	for i in 120: game.update_smooth_zoom(1.0 / 60.0)
	check(not game.zoom_animating and game.zoom == game.zoom_target, "Smooth zoom converges and stops")
	game.zoom_at(anchor, 1000.0)
	check(game.zoom_target == 32.0, "Zoom in respects maximum")
	game.zoom_at(anchor, 0.00001)
	check(is_equal_approx(game.zoom_target, 13.2), "Zoom out stops at the scale that fits the whole map")
	for i in 120: game.update_smooth_zoom(1.0 / 60.0)
	var whole_map := Rect2(0, 0, 80, 50)
	var visible: Rect2 = game.visible_world_rect()
	check(visible.grow(0.001).encloses(whole_map) and is_equal_approx(visible.size.y, 50), "Minimum zoom contains the full map and exactly fits its height")
	game.center_camera(Vector2(-100, 1000))
	check(game.camera_center.is_equal_approx(Vector2(40, 25)), "Full-map view stays centered when panning beyond the edge")
	game.zoom_at(anchor, 0.01)
	game.update_smooth_zoom(1.0)
	check(is_equal_approx(game.zoom, 13.2), "Repeated zoom-out cannot shrink below the full-map limit")
	game.center_camera(Vector2(40, 25))
	check(not game.zoom_animating, "Explicit camera navigation cancels residual zoom")
	game.zoom = 21.0
	game.center_camera(Vector2(40, 25))
	game.zoom_at(anchor, 1.15)
	for i in 30: game.update_smooth_zoom(1.0 / 30.0)
	var slow_fps_zoom: float = game.zoom
	game.zoom = 21.0
	game.center_camera(Vector2(40, 25))
	game.zoom_at(anchor, 1.15)
	for i in 144: game.update_smooth_zoom(1.0 / 144.0)
	check(is_equal_approx(game.zoom, slow_fps_zoom), "Zoom smoothing is independent of frame rate")
	game.zoom = 21.0
	game.center_camera(Vector2(20, 25))
	var army: Array = game.sim.living(0)
	var first: Dictionary = army[0]
	var second: Dictionary = army[1]
	var third: Dictionary = army[2]
	game.sim.set_point(first, Vector2(18, 20))
	game.sim.set_point(second, Vector2(21, 20))
	game.sim.set_point(third, Vector2(24, 20))
	right_click(game, game.sim.point(first))
	check(game.selected == [first.id] and first.order == "idle", "Right clicking a friendly unit selects it without issuing a move")
	right_click(game, game.sim.point(second), true)
	check(game.selected == [first.id, second.id], "Shift right click adds a friendly unit")
	press(game, KEY_1, true)
	check(game.control_groups[1] == [first.id, second.id], "Ctrl plus number stores the current selection")
	right_click(game, game.sim.point(third))
	press(game, KEY_2, true)
	check(game.control_groups[1] == [first.id, second.id] and game.control_groups[2] == [third.id], "Groups keep independent copies of selection")
	press(game, KEY_1)
	right_click(game, Vector2(18, 25))
	check(first.order == "move" and second.order == "move" and third.order == "idle", "Only recalled group receives the move order")
	press(game, KEY_2)
	var foe: Dictionary = game.sim.add_unit("swordsman", 1, Vector2(24, 24))
	game.sim.update_visibility()
	right_click(game, game.sim.point(foe))
	check(third.order == "attack" and third.target == foe.id and first.order == "move", "Right clicking enemies still attacks with only the selected group")
	first.hp = 0
	press(game, KEY_1)
	check(game.selected == [second.id] and game.control_groups[1] == [second.id], "Dead members are removed when recalling a group")
	press(game, KEY_1, true)
	game.selected = [third.id]
	press(game, KEY_1, true)
	check(game.control_groups[1] == [third.id], "Ctrl plus number replaces an existing group")
	press(game, KEY_0, true)
	game.selected.clear()
	press(game, KEY_KP_0)
	check(game.selected == [third.id], "Top row zero and keypad zero address the same group")
	game.selected = [second.id]
	press(game, KEY_KP_9, true)
	press(game, KEY_9)
	check(game.selected == [second.id], "Keypad assignment supports the same ten groups")
	press(game, KEY_8)
	check(game.selected.is_empty(), "Empty group clears selection so old troops cannot receive unintended orders")
	press(game, KEY_1, true)
	check(game.control_groups[1] == [third.id], "Empty assignment does not erase an existing group")
	game.selected = [foe.id, game.sim.buildings[0].id]
	press(game, KEY_7, true)
	check(not game.control_groups.has(7), "Enemies and buildings cannot be stored as troop members")
	var card_event := InputEventMouseButton.new()
	card_event.button_index = MOUSE_BUTTON_RIGHT
	card_event.pressed = true
	game.army_buttons[second.kind].gui_input.emit(card_event)
	check(game.selected.has(second.id) and game.selected.all(func(id): return game.sim.entity(id).kind == second.kind), "Right clicking a roster card selects that unit type")
	var local_a: Vector2 = game.minimap.world_to_local(Vector2(10, 10))
	var local_b: Vector2 = game.minimap.world_to_local(Vector2(20, 10))
	var local_c: Vector2 = game.minimap.world_to_local(Vector2(60, 40))
	var local_d: Vector2 = game.minimap.world_to_local(Vector2(70, 40))
	check((local_b - local_a).distance_to(local_d - local_c) < 0.001, "Flat minimap has uniform scale at center and edges")
	game.queue_free()
	await process_frame
	print("STRATEGY_CONTROLS_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
