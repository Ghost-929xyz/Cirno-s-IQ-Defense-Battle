extends RefCounted
## Seeded terrain only: combat randomness and game entities are independent.
const Battlefield = preload("res://scripts/data/rts_battlefield.gd")
const WIDTH := Battlefield.WIDTH
const HEIGHT := Battlefield.HEIGHT
const DECORATION_SOURCES := [11, 15, 20, 22, 25]

static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var water_set: Dictionary = {}
	var river: Dictionary = {}
	var roads: Dictionary = {}
	var crossings: Dictionary = {}
	var ground: Dictionary = {}
	var trees: Array[Vector2i] = []
	var decorations: Dictionary = {}
	var landmarks: Array = [Battlefield.CENTRAL_BASE] + Battlefield.BASE_SITES + Battlefield.HOUSES + Battlefield.CAMPS + Battlefield.CHESTS + Battlefield.WILDLIFE
	for spawn_y in [7, 8, 9, 25, 26, 27, 40, 41, 42]:
		landmarks.append(Vector2(76, spawn_y))

	# Three lanes keep the whole battlefield accessible in every season. Their
	# crossing locations and bends vary without moving the strategic landmarks.
	var crossing_rows: Array[int] = [rng.randi_range(7, 12), rng.randi_range(22, 28), rng.randi_range(38, 42)]
	for lane in 3:
		var home_y: int = [10, 25, 40][lane]
		var bridge_y := crossing_rows[lane]
		var west_bend := rng.randi_range(18, 26)
		var east_bend := rng.randi_range(56, 67)
		_route(roads, [Vector2i(8, home_y), Vector2i(west_bend, home_y), Vector2i(west_bend, bridge_y), Vector2i(east_bend, bridge_y), Vector2i(east_bend, home_y), Vector2i(76, home_y)])
	var west_spine := rng.randi_range(11, 15)
	var east_spine := rng.randi_range(71, 74)
	_route(roads, [Vector2i(west_spine, 6), Vector2i(west_spine, 44)])
	_route(roads, [Vector2i(east_spine, 6), Vector2i(east_spine, 44)])
	for site in landmarks:
		_connect_landmark(roads, Vector2i(site))

	var river_mid := rng.randf_range(37.0, 41.0)
	var amplitude := rng.randf_range(2.0, 4.0)
	var phase := rng.randf_range(0.0, TAU)
	var frequency := rng.randf_range(0.11, 0.19)
	var river_centers: Array[int] = []
	for y in HEIGHT:
		river_centers.append(clampi(roundi(river_mid + amplitude * sin(float(y) * frequency + phase)), 35, 43))
	# Both rows of each bridge share the same banks and atlas alignment.
	for bridge_y in crossing_rows:
		river_centers[bridge_y + 1] = river_centers[bridge_y]
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if not _interior(cell): water_set[cell] = true
			if absi(x - river_centers[y]) <= 1:
				river[cell] = true
				water_set[cell] = true
	for bridge_y in crossing_rows:
		for y in range(bridge_y, bridge_y + 2):
			for x in range(river_centers[y] - 1, river_centers[y] + 2):
				var cell := Vector2i(x, y)
				crossings[cell] = Vector2i(x - river_centers[y] + 1, 0)
				water_set.erase(cell)

	var lakes: Array = [
		[Vector2(rng.randf_range(19, 25), rng.randf_range(16, 21)), Vector2(rng.randf_range(3.5, 6.0), rng.randf_range(3.0, 5.0))],
		[Vector2(rng.randf_range(18, 24), rng.randf_range(32, 36)), Vector2(rng.randf_range(4.0, 6.0), rng.randf_range(2.8, 4.3))],
		[Vector2(rng.randf_range(60, 67), rng.randf_range(15, 19)), Vector2(rng.randf_range(3.5, 5.5), rng.randf_range(3.0, 4.5))],
		[Vector2(rng.randf_range(54, 64), rng.randf_range(42, 44)), Vector2(rng.randf_range(3.5, 5.0), rng.randf_range(2.0, 3.2))],
	]
	var lake_phase := rng.randf_range(0, TAU)
	for y in range(2, HEIGHT - 2):
		for x in range(2, WIDTH - 2):
			var cell := Vector2i(x, y)
			if river.has(cell) or crossings.has(cell): continue
			if _near_cells(cell, roads, 1) or _near_landmark(cell, landmarks, 3.4): continue
			for lake in lakes:
				var offset: Vector2 = (Vector2(cell) - lake[0]) / lake[1]
				if offset.length_squared() < 0.90 + 0.12 * sin(float(x + y) * 1.3 + lake_phase):
					water_set[cell] = true
					break

	# A dry central clearing joins both banks and leaves room for the starting camp.
	for y in range(18, 33):
		for x in range(33, 48):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_to(Battlefield.CENTRAL_BASE) <= 7.0:
				water_set.erase(cell)
				crossings.erase(cell)
	# Stable row-major ordering makes snapshots and tests reproducible too.
	var water: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if water_set.has(cell):
				water.append(cell)
				roads.erase(cell)
			elif crossings.has(cell):
				roads.erase(cell)
			else:
				ground[cell] = true
				if Vector2(cell).distance_to(Battlefield.CENTRAL_BASE) > 8 and not _near_cells(cell, roads, 1) and not _near_landmark(cell, landmarks, 3.4):
					candidates.append(cell)

	var groves: Array = []
	for i in 12:
		groves.append([Vector2(rng.randf_range(4, WIDTH - 5), rng.randf_range(4, HEIGHT - 5)), rng.randf_range(4.5, 9.0)])
	# Fisher-Yates uses this map's RNG, whereas Array.shuffle uses global RNG.
	for i in range(candidates.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var swap := candidates[i]
		candidates[i] = candidates[other]
		candidates[other] = swap
	for cell in candidates:
		var in_grove := false
		for grove in groves:
			if Vector2(cell).distance_to(grove[0]) < float(grove[1]):
				in_grove = true
				break
		var plant_tree := in_grove and rng.randf() < 0.24
		if _near_cells(cell, crossings, 2): plant_tree = false
		for existing in trees:
			if Vector2(cell).distance_squared_to(Vector2(existing)) < 6.25:
				plant_tree = false
				break
		if plant_tree:
			trees.append(cell)
		elif rng.randf() < 0.09:
			decorations[cell] = DECORATION_SOURCES[rng.randi_range(0, DECORATION_SOURCES.size() - 1)]
	# The animated tree sheet is 192px wide/tall on a 64px grid and its
	# texture_origin shifts the rendered sprite below its anchor cell.
	# Keep the entire sprite off water, rather than only testing the anchor.
	# Filter after placement to preserve all other seeded terrain/decorations.
	trees = trees.filter(func(cell): return _tree_on_dry_ground(cell, ground))
	var layout := {"water": water, "ground": ground, "roads": roads, "crossings": crossings, "trees": trees, "decorations": decorations}
	# Routes above reserve traversable land; no road surface is painted or advertised.
	layout.roads = {}
	return layout

static func _interior(cell: Vector2i) -> bool:
	return cell.x >= 2 and cell.y >= 2 and cell.x < WIDTH - 2 and cell.y < HEIGHT - 2

static func _tree_on_dry_ground(cell: Vector2i, ground: Dictionary) -> bool:
	# TileMap subtracts texture_origin (0, -64). The 192px sprite therefore
	# spans x=-1..1 and y=0..2 relative to its 64px anchor cell.
	for y in range(0, 3):
		for x in range(-1, 2):
			if not ground.has(cell + Vector2i(x, y)): return false
	return true

static func _route(roads: Dictionary, points: Array) -> void:
	for i in range(1, points.size()):
		var cell: Vector2i = points[i - 1]
		var end: Vector2i = points[i]
		# A 2x2 brush keeps corners and both horizontal/vertical paths wide.
		while true:
			for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
				if _interior(cell + offset): roads[cell + offset] = true
			if cell == end: break
			if cell.x != end.x: cell.x += signi(end.x - cell.x)
			else: cell.y += signi(end.y - cell.y)

static func _connect_landmark(roads: Dictionary, site: Vector2i) -> void:
	var closest := site
	var best_distance := WIDTH + HEIGHT
	for candidate in roads:
		# Roads on the opposite bank are never used for a landmark spur.
		if (site.x < 35) != (candidate.x < 35): continue
		var distance: int = absi(candidate.x - site.x) + absi(candidate.y - site.y)
		if distance < best_distance:
			closest = candidate
			best_distance = distance
	_route(roads, [site, Vector2i(closest.x, site.y), closest])

static func _near_cells(cell: Vector2i, occupied: Dictionary, radius: int) -> bool:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if occupied.has(cell + Vector2i(x, y)): return true
	return false

static func _near_landmark(cell: Vector2i, landmarks: Array, radius: float) -> bool:
	for site in landmarks:
		if Vector2(cell).distance_squared_to(site) < radius * radius: return true
	return false
