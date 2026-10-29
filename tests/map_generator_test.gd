extends SceneTree
const Generator = preload("res://scripts/data/rts_map_generator.gd")
const Field = preload("res://scripts/data/rts_battlefield.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func run() -> void:
	seed(83124)
	var expected_random := randi()
	seed(83124)
	Generator.generate(0)
	check(randi() == expected_random, "Terrain generation does not consume global randomness")
	var previous: Dictionary = {}
	for seed_value in [0, 1, 2, 3, 8, 17, 42, 99, 125, 255, 1024, 9988, 197401, 20261013, 2147483647, 4294967295, -1]:
		var layout: Dictionary = Generator.generate(seed_value)
		check(layout == Generator.generate(seed_value), "Identical seeds regenerate every terrain layer: " + str(seed_value))
		if not previous.is_empty():
			for layer in ["water", "trees", "decorations"]:
				check(layout[layer] != previous[layer], "Different seeds vary " + layer)
		previous = layout
		check(layout.crossings.size() >= 12 and layout.crossings.size() <= 18, "Outer river crossings survive the central clearing")
		check(layout.trees.size() > 25, "Seed produces substantial woodland")
		check(layout.ground.size() + layout.water.size() + layout.crossings.size() == Field.WIDTH * Field.HEIGHT, "All cells have exactly one terrain type")
		check(layout.roads.is_empty() and not layout.has("fine_roads"), "Road surfaces are removed")
		check(layout.ground.has(Vector2i(Field.CENTRAL_BASE)), "Central spawn is dry land")
		var blocked: Dictionary = {}
		for cell in layout.water: blocked[cell] = true
		for cell in layout.trees:
			check(layout.ground.has(cell) and not layout.roads.has(cell) and not layout.crossings.has(cell), "Trees grow only on unoccupied ground")
			var dry_footprint := true
			var clear_road := true
			# The rendered 192px tile extends across three cells, downward
			# from its anchor due to texture_origin=(0, -64).
			for y in range(0, 3):
				for x in range(-1, 2):
					if not layout.ground.has(cell + Vector2i(x, y)): dry_footprint = false
					if layout.roads.has(cell + Vector2i(x, y)): clear_road = false
			check(dry_footprint, "The full tree sprite stays on dry ground for seed " + str(seed_value))
			check(clear_road, "Roads avoid the entire tree sprite for seed " + str(seed_value))
			blocked[cell] = true
		for site in Field.HOUSES: blocked[Vector2i(site)] = true
		var visited: Dictionary = _flood(Vector2i(Field.CENTRAL_BASE), blocked)
		for base in Field.BASE_SITES:
			check(visited.has(Vector2i(base)), "Every base shares the connected land network")
		for site in Field.BASE_SITES + Field.HOUSES + Field.CAMPS + Field.CHESTS + Field.WILDLIFE:
			var cell := Vector2i(site)
			check(layout.ground.has(cell), "Every landmark is on dry land")
			var accessible := false
			for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if visited.has(cell + offset): accessible = true
			check(accessible, "Every landmark has a reachable interaction approach")
		for spawn_y in [7, 8, 9, 25, 26, 27, 40, 41, 42]:
			check(visited.has(Vector2i(76, spawn_y)), "Every invasion spawn can reach the bases")
		for cell in layout.roads:
			check(layout.ground.has(cell), "Roads never overlap water or bridges")
		for cell in layout.crossings:
			check(visited.has(cell) and not layout.ground.has(cell), "Bridge is traversable and visually exposes its water foundation")
	print("MAP_GENERATOR_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _flood(origin: Vector2i, blocked: Dictionary) -> Dictionary:
	var visited: Dictionary = {origin: true}
	var pending: Array[Vector2i] = [origin]
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = cell + offset
			if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= Field.WIDTH or neighbor.y >= Field.HEIGHT: continue
			if visited.has(neighbor) or blocked.has(neighbor): continue
			visited[neighbor] = true
			pending.append(neighbor)
	return visited
