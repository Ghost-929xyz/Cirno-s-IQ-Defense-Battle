extends RefCounted
## Road generation uses 16px samples while gameplay retains its world cells.
const Field = preload("res://scripts/data/rts_battlefield.gd")
const RESOLUTION := 4
const RADIUS := 2.4

static func apply(layout: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x6D2B79F5
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, Field.WIDTH * RESOLUTION, Field.HEIGHT * RESOLUTION)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for cell in layout.water:
		grid.fill_solid_region(Rect2i(cell * RESOLUTION, Vector2i.ONE * RESOLUTION), true)
	var tree_footprints := {}
	for tree in layout.trees:
		for y in range(0, 3):
			for x in range(-1, 2): tree_footprints[tree + Vector2i(x, y)] = true
		# Reserve the entire tree texture plus half the road width. Routes
		# bend around this area rather than painting sand beneath the canopy.
		var area := Rect2i((tree + Vector2i(-1, 0)) * RESOLUTION - Vector2i.ONE * 3, Vector2i.ONE * 18)
		grid.fill_solid_region(area.intersection(grid.region), true)
	var centers := {}
	var failures: Array[Vector2i] = []
	var rows := {}
	for cell in layout.crossings:
		if layout.crossings[cell] == Vector2i(1, 0): rows[cell.y] = cell.x
	var bridge_rows: Array = rows.keys()
	bridge_rows.sort()
	# Two rows belong to each bridge; use their shared center line.
	for lane in 3:
		var home_y: int = [10, 25, 40][lane]
		var row: int = bridge_rows[lane * 2]
		var bridge_x: int = rows[row]
		var points := PackedVector2Array([
			Vector2(8, home_y), Vector2(20, home_y + rng.randf_range(-3.0, 3.0)),
			Vector2(bridge_x - 4, row + 0.5), Vector2(bridge_x + 4, row + 0.5),
			Vector2(62, home_y + rng.randf_range(-3.0, 3.0)), Vector2(76, home_y)])
		_trace(grid, _curve_samples(points), centers, failures)
	for spine_x in [13.0, 73.0]:
		var points := PackedVector2Array()
		for y in [6.0, 15.0, 25.0, 35.0, 44.0]:
			points.append(Vector2(spine_x + rng.randf_range(-1.8, 1.8), y))
		_trace(grid, _curve_samples(points), centers, failures)
	# Connect settlements and rewards to the network after the main routes
	# exist, so short spurs follow the land and also avoid nearby trees.
	for site in Field.BASE_SITES + Field.HOUSES + Field.CAMPS + Field.CHESTS + Field.WILDLIFE:
		var start := _nearest_free(grid, _fine_cell(site))
		var closest := start
		var distance := INF
		for cell in centers:
			if not grid.region.has_point(cell) or grid.is_point_solid(cell): continue
			var current: float = Vector2(start).distance_squared_to(Vector2(cell))
			if current < distance:
				distance = current
				closest = cell
		var route := grid.get_id_path(start, closest)
		if route.is_empty():
			failures.append(start)
		else:
			_plot_smoothed(route, centers)
	var fine_roads := {}
	var roads := {}
	for center in centers:
		for y in range(-3, 4):
			for x in range(-3, 4):
				if Vector2(x, y).length_squared() > RADIUS * RADIUS: continue
				var fine: Vector2i = center + Vector2i(x, y)
				if not grid.region.has_point(fine): continue
				var coarse := Vector2i(floori(float(fine.x) / RESOLUTION), floori(float(fine.y) / RESOLUTION))
				if not layout.ground.has(coarse) or tree_footprints.has(coarse): continue
				fine_roads[fine] = true
				roads[coarse] = true
	layout.roads = roads
	layout.fine_roads = fine_roads
	layout.road_resolution = RESOLUTION
	layout.road_centers = centers
	layout.road_failures = failures

static func _fine_cell(pos: Vector2) -> Vector2i:
	return Vector2i(((pos + Vector2.ONE * 0.5) * RESOLUTION - Vector2.ONE * 0.5).round())

static func _nearest_free(grid: AStarGrid2D, desired: Vector2i) -> Vector2i:
	if grid.region.has_point(desired) and not grid.is_point_solid(desired): return desired
	for radius in range(1, 17):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if absi(x) != radius and absi(y) != radius: continue
				var cell := desired + Vector2i(x, y)
				if grid.region.has_point(cell) and not grid.is_point_solid(cell): return cell
	return desired

static func _trace(grid: AStarGrid2D, points: PackedVector2Array, centers: Dictionary, failures: Array[Vector2i]) -> void:
	var previous := _nearest_free(grid, _fine_cell(points[0]))
	var combined: Array[Vector2i] = [previous]
	for point in points:
		var target := _nearest_free(grid, _fine_cell(point))
		var route := grid.get_id_path(previous, target)
		if route.is_empty():
			# A guide point may lie in an enclosed grove. Skip it and keep
			# the existing route connected while proceeding toward the exit.
			continue
		for cell in route:
			if combined[-1] != cell: combined.append(cell)
		previous = target
	_plot_smoothed(combined, centers)
	var finish := _nearest_free(grid, _fine_cell(points[-1]))
	if previous != finish: failures.append(finish)

static func _plot_smoothed(route: Array[Vector2i], centers: Dictionary) -> void:
	if route.is_empty(): return
	var corners := PackedVector2Array([Vector2(route[0])])
	for index in range(1, route.size() - 1):
		if route[index] - route[index - 1] != route[index + 1] - route[index]:
			corners.append(Vector2(route[index]))
	if route.size() > 1: corners.append(Vector2(route[-1]))
	var previous := corners[0]
	centers[Vector2i(previous.round())] = true
	for index in range(1, corners.size() - 1):
		var corner := corners[index]
		var incoming := corner - corners[index - 1]
		var outgoing := corners[index + 1] - corner
		var radius := minf(4.0, minf(incoming.length(), outgoing.length()) * 0.45)
		var before := corner - incoming.normalized() * radius
		var after := corner + outgoing.normalized() * radius
		_plot_segment(previous, before, centers)
		var samples := maxi(2, ceili(radius * 4.0))
		previous = before
		for sample in range(1, samples + 1):
			var t := float(sample) / samples
			var point := (1.0 - t) * (1.0 - t) * before + 2.0 * (1.0 - t) * t * corner + t * t * after
			_plot_segment(previous, point, centers)
			previous = point
	_plot_segment(previous, corners[-1], centers)

static func _plot_segment(start: Vector2, finish: Vector2, centers: Dictionary) -> void:
	var steps := maxi(1, ceili(start.distance_to(finish) * 2.0))
	for step in steps + 1:
		centers[Vector2i(start.lerp(finish, float(step) / steps).round())] = true

static func _curve_samples(points: PackedVector2Array) -> PackedVector2Array:
	var samples := PackedVector2Array()
	for index in range(points.size() - 1):
		var p0 := points[maxi(0, index - 1)]
		var p1 := points[index]
		var p2 := points[index + 1]
		var p3 := points[mini(points.size() - 1, index + 2)]
		var steps := maxi(1, ceili(p1.distance_to(p2) / 1.5))
		for step in steps:
			var t := float(step) / steps
			var position := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			samples.append(position)
	samples.append(points[-1])
	return samples
