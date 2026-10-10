extends SceneTree
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
func key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event
func run() -> void:
	var game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.pick_card("mana")
	game.pick_card("supplies")
	game.sim.choose_base(1)
	await process_frame
	check(game.MAP_RECT.size == Vector2(1180, 660), "Battlefield extends behind floating HUD")
	check(game.resource_labels.size() == 5 and game.resource_labels.gold.get_theme_font("font") is FontVariation, "Resources use separate bold floating numbers")
	check(game.pause_button.text.is_empty() and game.pause_button.icon_name == "pause", "Top right pause is a flat icon")
	game.toggle_pause()
	check(game.pause_button.icon_name == "play", "Pause icon changes to resume")
	game.toggle_pause()
	check(game.dock.size.x < 660 and is_equal_approx(game.dock.position.x + game.dock.size.x * 0.5, 590), "Command dock is compact and horizontally centered")
	check(game.minimap.circular and game.minimap.position.x > 900 and game.minimap.position.y > 400, "Circular minimap sits bottom right")
	check(not game.minimap._has_point(Vector2.ZERO) and game.minimap._has_point(game.minimap.size * 0.5), "Circular hit area rejects square corners")
	for spot in Field.CAMPS + Field.WILDLIFE + Field.BASE_SITES:
		var local: Vector2 = game.minimap.world_to_local(spot)
		check(game.minimap._has_point(local), "Landmark remains inside circular chart: " + str(spot))
		check(game.minimap.local_to_world(local).distance_to(spot + Vector2(0.5, 0.5)) < 0.01, "Circular projection click round trip: " + str(spot))
	game._unhandled_input(key_event(KEY_TAB))
	check(game.tactical_overlay.visible and game.simulation_blocked() and not game.paused, "Tab overview temporarily suspends battle without changing pause preference")
	var timer_before: float = game.sim.timer
	game._process(0.4)
	check(game.sim.timer == timer_before, "Overview does not advance battle clock")
	game._unhandled_input(key_event(KEY_TAB))
	check(not game.tactical_overlay.visible and not game.simulation_blocked(), "Tab closes overview and resumes")
	game.paused = true
	game.toggle_overview()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.tactical_map.world_to_local(Vector2(45, 30))
	game.tactical_map._gui_input(click)
	check(not game.tactical_overlay.visible and game.paused and game.camera_center.distance_to(Vector2(45.5, 30.5)) < 0.01, "Overview click navigates and preserves existing pause")
	game.paused = false
	game.advance_wave()
	game.wave_intro.set_process(false)
	check(game.wave_intro.active and game.wave_intro.current_wave == 1, "Manual wave starts cinematic immediately")
	check(game.wave_intro.title.visible_characters == 0 and game.wave_intro.modulate.a == 0, "Intro begins transparent with hidden text")
	timer_before = game.sim.timer
	game._process(0.4)
	check(game.sim.timer == timer_before, "Intro suspends combat and timers")
	game.wave_intro.advance(0.2)
	check(game.wave_intro.modulate.a > 0 and game.wave_intro.modulate.a < 1, "Intro fades in gradually")
	game.wave_intro.advance(0.55)
	check(game.wave_intro.title.visible_characters > 0 and game.wave_intro.title.visible_characters < game.wave_intro.title.text.length(), "Typewriter reveals a partial string")
	game.wave_intro.advance(0.7)
	check(game.wave_intro.title.visible_characters == game.wave_intro.title.text.length(), "Typewriter reaches complete wave message")
	game.wave_intro.advance(1.0)
	check(game.wave_intro.modulate.a > 0 and game.wave_intro.modulate.a < 1, "Intro fades back out")
	game.wave_intro.advance(1.0)
	check(not game.wave_intro.active and not game.wave_intro.visible and not game.paused, "Intro returns to original HUD without forcing pause")
	for wave in range(2, 7):
		game.sim.timer = 0.0
		game._process(0.05)
		game.wave_intro.set_process(false)
		check(game.wave_intro.active and game.wave_intro.current_wave == wave, "Timed wave triggers its own intro: " + str(wave))
		game.wave_intro.advance(game.wave_intro.DURATION + 0.01)
		check(not game.wave_intro.active, "Timed intro finishes: " + str(wave))
	game.observe_waves()
	check(not game.wave_intro.active, "No duplicate intro for unchanged wave")
	game.sim.campaign += 1
	game.sim.wave = 0
	game.sim.phase = "prep"
	game.observe_waves()
	game.advance_wave()
	game.wave_intro.set_process(false)
	check(game.wave_intro.active and game.wave_intro.current_wave == 1, "New expedition starts numbering and intros again")
	game.wave_intro.advance(game.wave_intro.DURATION + 0.01)
	game.sim.phase = "prep"
	game.sim.wave = 0
	game.last_wave_seen = 0
	game.sim.start_wave()
	game.sim.start_wave()
	game.observe_waves()
	game.wave_intro.set_process(false)
	check(game.wave_intro.current_wave == 1 and game.wave_intro.pending == [2], "Rapid wave changes are queued")
	game.wave_intro.advance(game.wave_intro.DURATION + 0.01)
	game.wave_intro.set_process(false)
	check(game.wave_intro.current_wave == 2 and game.wave_intro.active, "Queued wave plays after prior intro")
	game.wave_intro.advance(game.wave_intro.DURATION + 0.01)
	game.queue_free()
	await process_frame
	print("FLOATING_UI_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
