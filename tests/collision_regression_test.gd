extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func fresh():
	var s = Sim.new()
	s.configure_terrain([])
	s.phase = "prep"
	s.timer = 99999
	s.gold = 99999
	s.baka = 99999
	return s

func body_clear(s, u: Dictionary) -> bool:
	return s.unit_position_clear(s.point(u), u.kind, u.id)

func run() -> void:
	# Real routes through every building type, for both infantry and mounted units.
	for kind in Rules.BUILDINGS:
		for complete in [false, true]:
			for troop in ["swordsman", "cavalry"]:
				var s = fresh()
				var b: Dictionary = s.add_building(kind, 0, Vector2(20,20), complete)
				check(not s.walkable(Vector2i(20,20)), "%s construction=%s blocks its center" % [kind, not complete])
				var u: Dictionary = s.add_unit(troop, 1, Vector2(15,20))
				var clear := true
				for i in 200:
					var previous: Vector2 = s.point(u)
					s.move_unit(u, Vector2(25,20), 0.1)
					clear = clear and body_clear(s,u) and s.segment_clear(previous,s.point(u),Rules.terrain_radius(troop))
				check(clear and s.point(u).distance_to(Vector2(25,20)) < 0.1, "%s %s routes around full footprint" % [kind,troop])
				check(not s.unit_motion_clear(u,Vector2(15,20)), "Large step cannot tunnel through %s" % kind)
				# Melee must still damage structures from their outside edge.
				b.hp = b.max_hp
				u.order = "attack"
				u.target = b.id
				for i in 180:
					s.step_unit(u,0.05)
					if b.hp < b.max_hp: break
				check(b.hp < b.max_hp and body_clear(s,u), "%s remains attackable from outside" % kind)
				var footprint: Array = s.building_cells(kind,s.point(b))
				s.hit(u,b,100000,false)
				check(footprint.all(func(cell): return s.walkable(cell)), "%s destruction releases all occupied cells" % kind)
	# Castle rear and side wings used to be completely traversable.
	for start in [Vector2(15,20),Vector2(25,20),Vector2(20,15),Vector2(20,25)]:
		var s = fresh()
		var b: Dictionary = s.add_building("base",0,Vector2(20,20))
		check(not s.position_clear(Vector2(19,19)) and not s.position_clear(Vector2(21,20)), "Castle rear and both wings are solid")
		var u: Dictionary = s.add_unit("swordsman",0,start)
		b.hp = 1900
		s.command([u.id],"repair",s.point(b),b.id)
		for i in 400: s.step_unit(u,0.05)
		check(b.hp == b.max_hp and body_clear(s,u), "Repair from each side finishes outside castle")
		s.command([u.id],"garrison",s.point(b),b.id)
		for i in 200: s.step_unit(u,0.05)
		check(u.home == b.id, "Garrison reaches a perimeter entrance from each side")
		s.evacuate(b.id)
		check(u.home == -1 and body_clear(s,u), "Evacuation emerges outside the castle")
	var s = fresh()
	var worker: Dictionary = s.add_unit("cavalry",0,Vector2(20,20))
	var b: Dictionary = s.add_building("base",0,Vector2(20,20),false)
	check(body_clear(s,worker), "Placing construction relocates an overlapping mounted unit")
	var water_cells: Array[Vector2i] = [Vector2i(26,20)]
	s.configure_terrain(water_cells)
	check(not s.construction_error("barracks",Vector2(25,20),[worker.id]).is_empty(), "Placement rejects a side wing over water, even with dry center")
	s._terrain_obstacles[Vector2i(26,22)] = true
	s.rebuild_navigation()
	check(not s.construction_error("house",Vector2(25,22),[worker.id]).is_empty(), "Placement rejects a side wing over a tree")
	# Outward rally orders and an enclosed producer cannot spawn through walls.
	b.complete = true
	s.set_rally(b.id,Vector2(26,20))
	for i in 5: s.train_unit("swordsman",b.id)
	for i in 360: s.step(0.05)
	check(s.living(0).size() == 6 and s.living(0).all(func(u): return body_clear(s,u)), "Production and rally keep every recruit outside obstacles")
	s = fresh()
	b = s.add_building("base",0,Vector2(20,20))
	for y in range(18,22):
		for x in range(18,23):
			if x in [18,22] or y in [18,21]: s.walls.append({"x":x,"y":y,"ttl":25.0})
	s.rebuild_navigation()
	check(not s.training_spawn_point(b).is_finite(), "A fully enclosed producer cannot teleport recruits through walls")
	s.train_unit("swordsman",b.id)
	s.step_building(b,4)
	check(s.units.is_empty() and b.queue.size() == 1, "Blocked production waits without consuming the queued unit")
	# New wall placement must use square corner clearance, not only center distance.
	s = fresh()
	worker = s.add_unit("cavalry",0,Vector2(10.7,10.7))
	var before: Vector2 = s.point(worker)
	s.cast("wall",Vector2(10,10))
	check(s.point(worker) == before and body_clear(s,worker) and not s.walls.any(func(w): return Vector2i(s.point(w)) == Vector2i(10,10)), "Ice wall corners cannot overlap a mounted body")
	# Old saves and idle/frozen troops must not keep invalid positions.
	b = s.add_building("base",0,Vector2(20,20))
	var data: Dictionary = s.snapshot().duplicate(true)
	data.units[0].x = 20
	data.units[0].y = 19
	var loaded = Sim.new()
	check(loaded.restore(data) and body_clear(loaded,loaded.units[0]), "Old save moves troops out of the newly solid castle rear")
	s.set_point(worker,Vector2(20,19))
	worker.frozen = 5
	s.step_unit(worker,0.05)
	check(body_clear(s,worker), "Even frozen idle units cannot remain inside an obstacle")
	# Deterministic map seeds and spawned waves cover integration with resources.
	for seed_value in [1,17,42,104729,999999]:
		s = Sim.new()
		s.generate_map(seed_value)
		s.choose_card("supplies")
		s.choose_card("mana")
		check(s.resource_sites.size() == 9, "Resources remain reachable from the now-solid base")
		s.start_wave()
		var clear := true
		for i in 80:
			s.step(0.1)
			clear = clear and s.units.all(func(u): return u.hp <= 0 or u.home != -1 or body_clear(s,u))
		check(clear,"Generated map %d: initial units and wave stay outside all obstacles" % seed_value)
	# Exercise every world obstacle from all eight approach directions, including
	# diagonal corners and long frame steps, using both terrain body sizes.
	for obstacle in ["gold_mine", "mana_spring", "vision_tower", "campfire", "treasure", "tree", "water", "ice_wall"]:
		for troop in ["swordsman", "cavalry"]:
			for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1,-1), Vector2(-1,1), Vector2(1,-1), Vector2(1,1)]:
				s = fresh()
				var center := Vector2(20,20)
				match obstacle:
					"gold_mine", "mana_spring", "vision_tower":
						s.resource_sites.append({"id":s.allocate_id(),"kind":obstacle,"x":20,"y":20,"team":-1,"capture":0.0,"capturing_team":-1})
					"campfire":
						s.add_building("base",0,center - s.TORCH_OFFSETS[0])
					"treasure": s.chests.append({"id":s.allocate_id(),"x":20,"y":20})
					"tree": s._terrain_obstacles[Vector2i(center)] = true
					"water": s._painted_water[Vector2i(center)] = true
					"ice_wall": s.walls.append({"x":20,"y":20,"ttl":25.0})
				s.rebuild_navigation()
				var u: Dictionary = s.add_unit(troop,0,center + direction * 7)
				var destination: Vector2 = center - direction * 7
				var clear := not s.unit_motion_clear(u,destination)
				for i in 240:
					var previous: Vector2 = s.point(u)
					s.move_unit(u,destination,0.1 if i % 20 != 0 else 0.8)
					clear = clear and body_clear(s,u) and s.segment_clear(previous,s.point(u),Rules.terrain_radius(troop))
					if s.point(u).distance_to(destination) < 0.1: break
				check(clear and s.point(u).distance_to(destination) < 0.1, "%s: %s safely routes from %s with variable frame times" % [obstacle,troop,direction])
	# A fast step may neither end on nor sweep through a stationary body.
	for troop in ["swordsman", "cavalry"]:
		s = fresh()
		var moving: Dictionary = s.add_unit(troop,0,Vector2(15,20))
		var standing: Dictionary = s.add_unit("cavalry",1,Vector2(20,20))
		check(not s.unit_motion_clear(moving,Vector2(25,20)), "Swept %s cannot cross another body" % troop)
		var clear := true
		for i in 160:
			s.move_unit(moving,Vector2(25,20),0.2)
			clear = clear and body_clear(s,moving) and body_clear(s,standing)
		check(clear and s.point(moving).distance_to(Vector2(25,20)) < 0.1, "%s detours around a standing mounted unit" % troop)
	print("COLLISION_REGRESSION_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
