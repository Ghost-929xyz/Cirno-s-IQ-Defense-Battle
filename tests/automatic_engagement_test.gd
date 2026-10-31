extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func fresh():
	var s = Sim.new()
	s.configure_terrain([])
	s.phase = "prep"
	s.timer = 9999
	for kind in s.catalog: s.catalog[kind].crit_chance = 0
	return s
func tick(s, u: Dictionary, count := 1) -> void:
	for i in count:
		s.elapsed += 0.05
		s.update_visibility()
		s.step_unit(u,0.05)
func run() -> void:
	var s = fresh()
	var u: Dictionary = s.add_unit("swordsman",0,Vector2(10,10))
	var foe: Dictionary = s.add_unit("swordsman",1,Vector2(13,10))
	s.command([u.id],"move",Vector2(20,10))
	s.command([u.id],"move",Vector2(23,12),-1,true)
	var queued: Array = u.orders.duplicate(true)
	tick(s,u,100)
	check(foe.hp <= 0,"Ordinary movement engages and kills an enemy without an attack-move order")
	check(u.order == "move" and u.goal_x == 20 and u.orders == queued,"Combat preserves the original destination and Shift queue")
	tick(s,u,300)
	check(u.order == "idle" and u.orders.is_empty() and s.point(u).distance_to(Vector2(23,12)) < 0.1,"After combat the troop completes the original route and appended waypoint")
	s = fresh()
	u = s.add_unit("swordsman",0,Vector2(10,10))
	foe = s.add_unit("swordsman",1,Vector2(14.8,10))
	tick(s,u,100)
	check(foe.hp <= 0 and s.point(u).x > 10,"Idle melee troops advance on visible enemies beyond weapon range")
	s = fresh()
	u = s.add_unit("swordsman",0,Vector2(10,10))
	foe = s.add_unit("swordsman",1,Vector2(16,10))
	s.reveal_circle(s.point(foe),2)
	s.step_unit(u,0.05)
	check(s.point(u) == Vector2(10,10) and int(u.get("auto_target",-1)) == -1,"Ally-revealed enemies outside this troop's own sight do not pull it away")
	s = fresh()
	u = s.add_unit("scout",0,Vector2(10,10))
	foe = s.add_unit("swordsman",1,Vector2(17,10))
	tick(s,u)
	check(u.engaging_target == foe.id and s.point(u).x > 10,"Scouts use their full eight-cell sight for automatic engagement")
	s = fresh()
	u = s.add_unit("archer",0,Vector2(10,10))
	foe = s.add_unit("hermit",1,Vector2(14,10))
	tick(s,u)
	check(u.engaging_target == -1,"Hermit concealment still reduces automatic ranged detection")
	for stance in ["hold","stop"]:
		s = fresh()
		u = s.add_unit("swordsman",0,Vector2(10,10))
		foe = s.add_unit("swordsman",1,Vector2(14,10))
		s.command([u.id],stance,Vector2.ZERO)
		tick(s,u,40)
		check(s.point(u) == Vector2(10,10) and foe.hp == foe.max_hp,"%s never chases an enemy outside attack range" % stance)
		s.set_point(foe,Vector2(10.9,10))
		tick(s,u)
		check(foe.hp < foe.max_hp and s.point(u) == Vector2(10,10),"%s still fights in place when an enemy closes in" % stance)
	s = fresh()
	u = s.add_unit("swordsman",0,Vector2(10,10))
	foe = s.add_unit("swordsman",1,Vector2(14,10))
	tick(s,u)
	check(u.engaging_target == foe.id,"A visible hostile is acquired")
	s.set_point(foe,Vector2(30,10))
	s.command([u.id],"move",Vector2(8,10))
	var before_release: Vector2 = s.point(u)
	tick(s,u)
	check(u.engaging_target == -1 and s.point(u).x < before_release.x,"An enemy leaving vision releases the troop to its current move order")
	s = fresh()
	u = s.add_unit("swordsman",0,Vector2(10,10))
	var building: Dictionary = s.add_building("outpost",1,Vector2(14,10))
	foe = s.add_unit("swordsman",1,Vector2(10,14))
	tick(s,u)
	check(u.engaging_target == foe.id,"Enemy troops are prioritized over nearby structures")
	var second: Dictionary = s.add_unit("swordsman",1,Vector2(10,11))
	tick(s,u,10)
	check(u.engaging_target == foe.id,"A valid troop target stays locked instead of oscillating")
	foe.hp = 0
	tick(s,u)
	check(u.engaging_target == second.id,"Killing a target immediately acquires the next threat")
	s = fresh()
	var water: Array[Vector2i] = []
	for y in s.HEIGHT: water.append(Vector2i(12,y))
	s.configure_terrain(water)
	u = s.add_unit("swordsman",0,Vector2(10,10))
	foe = s.add_unit("swordsman",1,Vector2(13,10))
	second = s.add_unit("swordsman",1,Vector2(10,14))
	tick(s,u)
	check(u.engaging_target == second.id,"A visible but unreachable enemy does not prevent engaging a reachable one")
	# Work orders pause for battle, then resume their original target.
	for order in ["repair","garrison","capture","chest"]:
		s = fresh()
		u = s.add_unit("swordsman",0,Vector2(10,10))
		var target: Dictionary
		match order:
			"repair":
				target = s.add_building("house",0,Vector2(18,10))
				target.hp = target.max_hp - 60
			"garrison": target = s.add_building("house",0,Vector2(18,10))
			"capture":
				target = {"id":s.allocate_id(),"kind":"gold_mine","x":18,"y":10,"team":-1,"capture":0.0,"capturing_team":-1,"discovered":true}
				s.resource_sites.append(target)
			"chest":
				target = {"id":s.allocate_id(),"x":18,"y":10}
				s.chests.append(target)
		s.rebuild_navigation()
		foe = s.add_unit("swordsman",1,Vector2(13,10))
		s.command([u.id],order,s.point(target),target.id)
		for i in 150:
			tick(s,u)
			if foe.hp <= 0: break
		check(foe.hp <= 0 and u.order == order and u.target == target.id,"%s route fights first and keeps its interaction target" % order)
		for i in 300:
			tick(s,u)
			s.step_resources(0.05)
		var complete := false
		match order:
			"repair": complete = target.hp == target.max_hp
			"garrison": complete = u.home == target.id
			"capture": complete = target.team == 0
			"chest": complete = s.chests.is_empty()
		check(complete,"%s task completes after the enemy is defeated" % order)
	s = fresh()
	u = s.add_unit("swordsman",0,Vector2(10,10))
	building = s.add_building("outpost",1,Vector2(18,10))
	foe = s.add_unit("swordsman",1,Vector2(13,10))
	s.command([u.id],"attack",s.point(building),building.id)
	tick(s,u)
	check(u.engaging_target == foe.id and u.target == building.id,"A march to attack a structure first engages its defenders without losing the structure order")
	s = fresh()
	u = s.add_unit("archer",0,Vector2(10,11.3))
	var mine := {"id":s.allocate_id(),"kind":"gold_mine","x":10,"y":10,"team":-1,"capture":2.0,"capturing_team":0,"discovered":true}
	s.resource_sites.append(mine)
	s.rebuild_navigation()
	foe = s.add_unit("swordsman",1,Vector2(14,11.3))
	s.command([u.id],"capture",s.point(mine),mine.id)
	tick(s,u)
	s.step_resources(0.05)
	check(u.engaging_target == foe.id and mine.capture <= 2.0,"Occupation does not keep progressing while the claimant engages a distant enemy")
	# A manual focus order remains authoritative even when another enemy is closer.
	s = fresh()
	u = s.add_unit("archer",0,Vector2(10,10))
	foe = s.add_unit("swordsman",1,Vector2(12,10))
	second = s.add_unit("swordsman",1,Vector2(11,11))
	s.command([u.id],"attack",s.point(foe),foe.id)
	tick(s,u)
	check(foe.hp < foe.max_hp and second.hp == second.max_hp,"Explicit troop focus is preserved")
	# Save/load retains the task, never a stale temporary combat target.
	s.command([u.id],"move",Vector2(20,10))
	tick(s,u)
	var restored = Sim.new()
	check(restored.restore(s.snapshot()) and restored.units[0].order == "move" and restored.units[0].goal_x == 20 and restored.units[0].auto_target == -1,"Loading reacquires targets while preserving travel orders")
	# Full simulation: both opponents act, deaths are removed and visibility updates.
	s = fresh()
	s.add_building("base",0,Vector2(5,20))
	u = s.add_unit("swordsman",0,Vector2(10,10))
	foe = s.add_unit("swordsman",1,Vector2(14,10))
	s.command([u.id],"move",Vector2(22,10))
	s.command([u.id],"move",Vector2(24,12),-1,true)
	s.update_visibility()
	var clear := true
	for i in 500:
		s.step(0.05)
		clear = clear and s.units.all(func(unit): return unit.home != -1 or s.unit_position_clear(s.point(unit),unit.kind,unit.id))
	check(foe.hp <= 0 and u.hp > 0 and u.hp < u.max_hp,"Real moving opponents exchange attacks and finish combat")
	check(clear and u.order == "idle" and s.point(u).distance_to(Vector2(24,12)) < 0.1,"Full battle preserves collision safety and completes both original waypoints")
	print("AUTOMATIC_ENGAGEMENT_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
