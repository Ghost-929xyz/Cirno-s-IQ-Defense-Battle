extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func fresh():
	var s = Sim.new()
	s.configure_terrain([])
	s.phase = "prep"
	return s

func run() -> void:
	for kind in Rules.BUILDINGS:
		var s = fresh()
		var building: Dictionary = s.add_building(kind, 0, Vector2(10, 10), false)
		check(not s.walkable(Vector2i(10, 10)), "Construction blocks its footprint: " + kind)
		check(not s.segment_clear(Vector2(8, 10), Vector2(12, 10)), "Cannot walk through a building: " + kind)
		var u: Dictionary = s.add_unit("cavalry", 0, Vector2(8, 10))
		var safe := true
		for i in 160:
			var before: Vector2 = s.point(u)
			s.move_unit(u, Vector2(12, 10), 0.05)
			safe = safe and not s.segment_hits_cell(before, s.point(u), Vector2i(10, 10), Rules.terrain_radius(u.kind))
		check(safe and s.point(u).distance_to(Vector2(12, 10)) < 0.1, "Routes around building without getting stuck: " + kind)
		var foe: Dictionary = s.add_unit("swordsman", 1, Vector2(12, 12))
		s.hit(foe, building, 10000, false)
		check(s.walkable(Vector2i(10, 10)), "Destroyed building releases navigation: " + kind)

	var s = fresh()
	var rider: Dictionary = s.add_unit("cavalry", 0, Vector2(9.25, 9.25))
	s.add_building("house", 0, Vector2(10, 10))
	check(s.unit_position_clear(s.point(rider), rider.kind, rider.id), "Construction displaces the entire mounted footprint")
	s = fresh()
	rider = s.add_unit("cavalry", 0, Vector2(9.25, 9.25))
	s.cast("wall", Vector2(10, 10))
	check(s.unit_position_clear(s.point(rider), rider.kind, rider.id), "Ice walls never clip a mounted unit at a diagonal corner")

	s = fresh()
	var soldier: Dictionary = s.add_unit("swordsman", 0, Vector2(8, 10))
	var base: Dictionary = s.add_building("base", 0, Vector2(10, 10))
	s.garrison(soldier, base)
	for y in s.HEIGHT:
		for x in s.WIDTH: s.navigation.set_point_solid(Vector2i(x, y), true)
	s.evacuate(base.id)
	check(s.point(soldier).is_finite() and soldier.home == base.id, "A sealed garrison waits instead of writing an infinite position")
	s.navigation.set_point_solid(Vector2i(12, 10), false)
	s.evacuate(base.id)
	check(soldier.home == -1 and s.unit_position_clear(s.point(soldier), soldier.kind, soldier.id), "A newly opened exit releases the waiting garrison")

	s = fresh()
	var water: Array[Vector2i] = []
	for y in s.HEIGHT: water.append(Vector2i(12, y))
	s.configure_terrain(water)
	soldier = s.add_unit("swordsman", 0, Vector2(10, 10))
	s.command([soldier.id], "move", Vector2(14, 10))
	for i in 80: s.step_unit(soldier, 0.05)
	check(soldier.order != "move" and s.point(soldier).x < 12, "Unreachable orders cannot remain stuck forever or teleport across water")

	s = fresh()
	rider = s.add_unit("cavalry", 0, Vector2(10, 10))
	s.command([rider.id], "move", Vector2(10.33, 10))
	s.walls.append({"x": 11, "y": 10, "ttl": 25.0})
	s.rebuild_navigation()
	for i in 80: s.step_unit(rider, 0.05)
	check(rider.order == "idle" and s.unit_position_clear(s.point(rider), rider.kind, rider.id), "A new obstacle redirects a mounted destination using mounted clearance")

	s = fresh()
	s.configure_terrain([], [Vector2i(11, 11)])
	soldier = s.add_unit("swordsman", 0, Vector2(10.4, 10.3))
	var safe := true
	for i in 160:
		var before: Vector2 = s.point(soldier)
		s.move_unit(soldier, Vector2(10, 13), 0.05)
		safe = safe and s.segment_clear(before, s.point(soldier))
	check(safe and s.point(soldier).distance_to(Vector2(10, 13)) < 0.1, "Fractional starts route safely around an obstacle corner")

	s = fresh()
	base = s.add_building("outpost", 1, Vector2(10, 10))
	soldier = s.add_unit("swordsman", 0, Vector2(8, 10))
	base.team = 0
	s.garrison(soldier, base)
	base.team = 1
	var footprint: Array = s.building_cells(base.kind, s.point(base))
	var enclosure := {}
	for cell in footprint:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not footprint.has(neighbor): enclosure[neighbor] = true
	for cell in enclosure: s.walls.append({"x": cell.x, "y": cell.y, "ttl": 25.0})
	s.rebuild_navigation()
	soldier.orders = [{"order": "move", "x": 15.0, "y": 10.0, "target": -1}]
	s.step_unit(soldier, 0.1)
	check(soldier.home == base.id, "Queued garrison orders cannot tunnel through a ring of walls")
	check(not s.training_spawn_point(base).is_finite(), "A producer with sealed entrances cannot spawn across its walls")
	var count: int = s.units.size()
	s.spawn_weak_raid()
	check(s.units.size() == count, "A sealed enemy camp cannot spawn raiders outside the enclosure")

	s = fresh()
	soldier = s.add_unit("swordsman", 0, Vector2(10, 10))
	s.command([soldier.id], "move", Vector2(14, 10))
	s.command([soldier.id], "move", Vector2(8, 10), -1, true)
	s.configure_terrain(water)
	for i in 100: s.step_unit(soldier, 0.05)
	check(soldier.order == "idle" and s.point(soldier).distance_to(Vector2(8, 10)) < 0.3, "A newly disconnected route releases the next queued order")

	for scenario in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(5, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(5, 1)]:
		var gap: int = scenario.x
		s = fresh()
		var barrier: Array[Vector2i] = []
		for y in s.HEIGHT:
			if y < 14 or y >= 14 + gap: barrier.append(Vector2i(18, y))
		s.configure_terrain(barrier)
		for side in 2:
			for row in 4:
				var u: Dictionary = s.add_unit("cavalry" if row % 2 == 0 else "swordsman", 0, Vector2(10 if side == 0 else 26, 13 + row * 2))
				s.command([u.id], "move", Vector2(30 if side == 0 else 6, 13 + row * 2))
		var movers: Array = s.units.duplicate()
		if scenario.y == 1: movers.reverse()
		safe = true
		for i in 1000:
			for u in movers:
				var before: Vector2 = s.point(u)
				s.step_unit(u, 0.05)
				safe = safe and s.segment_clear(before, s.point(u), Rules.terrain_radius(u.kind)) and s.unit_position_clear(s.point(u), u.kind, u.id)
		check(safe, "Opposing mixed formations never overlap or cross riverbanks: gap " + str(gap))
		var arrived: int = s.units.filter(func(u): return u.order == "idle").size()
		if arrived != 8:
			for u in s.units: print("TRAFFIC ", JSON.stringify({"id": u.id, "position": s.point(u), "goal": Vector2(u.goal_x, u.goal_y), "path": u.path, "blocked": u.get("blocked_time", 0)}))
		check(arrived == 8, "Opposing formations finish crossing: gap %d reverse %d arrived %d/8" % [gap, scenario.y, arrived])

	s = fresh()
	soldier = s.add_unit("swordsman", 0, Vector2(5, 5))
	s.add_unit("cavalry", 0, Vector2(8, 5))
	check(not s.unit_motion_clear(soldier, Vector2(12, 5)), "A large time step cannot tunnel through another unit")
	s.configure_terrain([], [Vector2i(8, 7)])
	check(not s.segment_clear(Vector2(5, 7), Vector2(12, 7)), "A large time step cannot tunnel through terrain")
	print("NAVIGATION_COLLISION_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
