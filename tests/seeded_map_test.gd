extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Session = preload("res://scripts/autoload/session.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func run() -> void:
	for value in ["", "0", "2147483647", " 12345 ", "00042"]:
		check(Session.valid_map_seed(value), "Accept valid seed " + value)
	for value in ["-1", "+1", "2147483648", "1.5", "12x", "99999999999"]:
		check(not Session.valid_map_seed(value), "Reject invalid seed " + value)
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._on_new_game_pressed()
	check(is_instance_valid(menu._seed_input) and menu._seed_input.text.is_empty(), "New games default to a random seed")
	menu._seed_input.text = "wrong"
	menu._on_slot_chosen(0)
	check(Session.current_slot == -1 and menu._seed_hint.text.contains("重新输入"), "Invalid seed blocks starting before changing a save slot")
	menu.queue_free()
	await process_frame
	Session.requested_map_seed = "20261013"
	var game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.paused = true
	check(game.sim.map_seed == "20261013", "Requested seed reaches the game")
	var wet: Array[Vector2i] = game.tile_map.terrain_water_cells()
	var trees: Array[Vector2i] = game.tile_map.terrain_obstacle_cells()
	check(wet.size() == game.sim.generated_layout.water.size() and wet.all(func(c): return game.sim.water(c)), "Painted water and simulation terrain match")
	check(trees.size() == game.sim.generated_layout.trees.size() and trees.all(func(c): return not game.sim.walkable(c)), "Generated trees remain physical obstacles")
	check(game.tile_map.trees.z_index > game.tile_map.decorations.z_index, "All clutter renders beneath the tree layer")
	check(game.tile_map.decorations.get_used_cells().all(func(c): return game.tile_map.decorations.get_cell_source_id(c) != 5), "Trees are separated from the clutter layer")
	check(game.tile_map.get_node("Paths").get_used_cells().is_empty(), "Road layer is empty")
	check(not is_instance_valid(game.tile_map.curved_paths) and game.sim.generated_layout.roads.is_empty(), "No fine road overlay is created")
	check(game.minimap.wet_cells == wet and game.tactical_map.wet_cells == wet, "Both maps display the generated terrain")
	game.sim.choose_card("supplies")
	game.sim.choose_card("mana")
	game.sim.choose_base(1)
	game.sim.start_wave()
	game.sim.update_winter(15.0)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.sim.snapshot()))
	var restored = Sim.new()
	check(restored.restore(snapshot), "Seeded winter save restores")
	check(restored.map_seed == game.sim.map_seed and restored.generated_layout == game.sim.generated_layout, "Restore reproduces the exact seeded layout")
	var matching := true
	for y in game.sim.HEIGHT:
		for x in game.sim.WIDTH:
			var cell := Vector2i(x, y)
			matching = matching and game.sim.walkable(cell) == restored.walkable(cell)
	check(matching and restored.water_frozen, "Restore retains generated obstacles and frozen water traversal")
	var seed_before: int = restored.rng.state
	restored.generate_map(20261013)
	check(restored.rng.state == seed_before, "Map generation does not change battle random state")
	var invalid := snapshot.duplicate(true)
	invalid.map_generator_version = 99
	check(not restored.restore(invalid), "Unknown generator versions cannot silently change saved terrain")
	var legacy = Sim.new()
	legacy.choose_card("supplies")
	legacy.choose_card("mana")
	legacy.choose_base(1)
	var old_save: Dictionary = legacy.snapshot()
	old_save.erase("map_seed")
	old_save.erase("map_generator_version")
	check(restored.restore(old_save) and restored.map_seed.is_empty(), "Unseeded legacy saves remain supported")
	var first_layout: Dictionary = game.sim.generated_layout
	game.queue_free()
	await process_frame
	var same = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(same)
	await process_frame
	check(same.sim.generated_layout == first_layout, "Starting again with the same seed reproduces the map")
	same.queue_free()
	await process_frame
	Session.requested_map_seed = ""
	var random_game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(random_game)
	await process_frame
	check(not random_game.sim.map_seed.is_empty() and Session.valid_map_seed(random_game.sim.map_seed), "Blank seed creates a shareable numeric map seed")
	random_game.queue_free()
	await process_frame
	print("SEEDED_MAP_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
