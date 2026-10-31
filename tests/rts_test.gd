extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func fresh():
	var s = Sim.new()
	s.rng.seed = 99
	s.choose_card("supplies")
	s.choose_card("mana")
	s.choose_base(1)
	return s

func run() -> void:
	test_training_spacing_and_placement()
	var s = Sim.new()
	check(s.catalog.size() == 20, "All spreadsheet rows imported")
	check(s.catalog.cataphract.hp == 450 and s.catalog.hermit_dodge.dodge == 0.4, "Exact spreadsheet values")
	check(not s.choose_base(0), "Cards precede base selection")
	check(s.choose_card("supplies") and not s.choose_card("supplies"), "Distinct opening cards")
	check(s.choose_card("mana") and not s.choose_card("builders"), "Exactly two opening cards")
	check(s.gold == 1150 and s.baka == 150, "Opening card effects")
	check(s.phase == "prep" and s.point(s.buildings[0]) == Vector2(40, 25) and s.capacity() == 40 and s.used_capacity() == 7, "Automatic central base capacity and starting army")
	s.gold = 10000
	check(not s.train_unit("cataphract"), "Tech and tier gate")
	s.add_building("academy", 0, Vector2(13, 25))
	check(s.research_unit("lancer") and s.research_unit("cataphract"), "Research follows the selected cavalry branch")
	check(s.train_unit("cataphract"), "Unlocked unit training")
	check(s.used_capacity() == 13, "Queued capacity reservation")
	var base: Dictionary = s.buildings[0]
	s.step_building(base, Rules.TRAIN_SECONDS)
	check(s.living(0).size() == 4 and s.used_capacity() == 13, "Training converts reservation to unit")
	for i in 16: s.add_unit("archer", 0, Vector2(5, 12))
	check(not s.train_unit("swordsman"), "Capacity cap enforced")
	s = fresh()
	s.gold = 1000
	var worker: Dictionary = s.living(0)[0]
	s.set_point(worker, Vector2(8, 12))
	check(s.construct("barracks", Vector2(8, 12), [worker.id]), "Worker construction")
	var site: Dictionary = s.buildings.back()
	check(s.capacity() == 40, "Unfinished building supplies no capacity")
	s.step_unit(worker, 1.0)
	check(is_equal_approx(site.hp, 21), "20 HP build rate")
	s.step_unit(worker, 50.0)
	check(site.complete and site.hp == 1000 and s.capacity() == 60, "Completion adds 20 capacity")
	site.hp = 500.0
	s.command([worker.id], "repair", s.point(site), site.id)
	s.step_unit(worker, 1.0)
	check(site.hp == 520, "20 HP repair rate")
	check(s.garrison(worker, site), "Initial swordsman can garrison")
	worker.hp = 40
	s.step_building(site, 1.0)
	check(is_equal_approx(worker.hp, 42), "Friendly building 2% heal")
	s.evacuate(site.id)
	base = s.buildings[0]
	check(s.garrison(worker, base), "Base garrison")
	worker.hp = 40
	s.step_building(base, 1.0)
	check(worker.hp == 45, "Base 5% heal")
	var enemy: Dictionary = s.add_unit("swordsman", 1, s.point(base))
	s.hit(enemy, worker, 1000, false)
	check(worker.hp == 45, "Building protects occupants")
	var sniper: Dictionary = s.add_unit("sniper", 1, s.point(base))
	s.hit(sniper, worker, 1, true)
	check(worker.hp < 45, "Sniper bypasses building protection")
	s.hit(enemy, base, 10000, false)
	check(worker.home == -1 and worker.hp > 0, "Destroyed building evacuates occupants")
	var veteran: Dictionary = s.add_unit("swordsman", 0, Vector2(5, 5))
	s.credit_kill(veteran, 240)
	check(veteran.rank == 0, "Threshold is strictly greater than three times price")
	s.credit_kill(veteran, 1)
	check(veteran.rank == 1 and is_equal_approx(veteran.max_hp, 100) and is_equal_approx(veteran.attack, 36), "First promotion increases only damage by 20 percent")
	s.credit_kill(veteran, 241)
	check(veteran.rank == 2 and is_equal_approx(veteran.max_hp, 120) and is_equal_approx(veteran.attack, 36), "Second promotion increases only maximum health by 20 percent")
	veteran.hp = 50
	s.step_unit(veteran, 1)
	check(is_equal_approx(veteran.hp, 52.4), "Veteran 2 percent passive heal")
	s = fresh()
	check(not s.walkable(Vector2i(42, 12)), "Water blocks traversal")
	check(s.cast("bridge", Vector2(42, 12)) and s.walkable(Vector2i(42, 12)), "Ice bridge changes navigation")
	var old_baka: float = s.baka
	check(not s.cast("bridge", Vector2(4, 4)) and s.baka == old_baka, "Invalid cast is not charged")
	check(s.cast("wall", Vector2(10, 12)) and not s.walkable(Vector2i(10, 12)), "Ice wall blocks path")
	s.step(Rules.WALL_SECONDS + 0.1)
	check(s.walkable(Vector2i(10, 12)), "Ice wall expiration restores path")
	enemy = s.add_unit("swordsman", 1, Vector2(8, 8))
	check(s.cast("freeze", Vector2(8, 8)) and enemy.frozen > 0, "Freeze enemies")
	var frozen_pos: Vector2 = s.point(enemy)
	s.step_unit(enemy, 1)
	check(s.point(enemy) == frozen_pos, "Frozen unit cannot move")
	var json_data: Dictionary = JSON.parse_string(JSON.stringify(s.snapshot()))
	var restored = Sim.new()
	check(restored.restore(json_data), "JSON save restores")
	check(restored.used_capacity() == s.used_capacity() and restored.baka == s.baka and restored.bridges == s.bridges, "Resources and terrain round trip")
	check(not restored.restore({"wave_index": 2}), "Legacy save rejected without mutation")
	check(restored.walkable(Vector2i(42, 12)), "Restored ice bridge is traversable")
	s = fresh()
	check(s.reachable_goal(Vector2(50, 25), Vector2(54, 25)) == Vector2i(-1, -1), "Island initially inaccessible")
	check(s.cast("bridge", Vector2(51, 25)) and s.reachable_goal(Vector2(50, 25), Vector2(54, 25)) != Vector2i(-1, -1), "Ice bridge unlocks island exploration")
	# Pure garrison fire must cap at 5 and 8 initial archers, regardless of occupancy.
	s.units.clear()
	s.buildings.clear()
	var house: Dictionary = s.add_building("house", 0, Vector2(5, 5))
	s.catalog.archer.crit_chance = 0.0
	for i in 10:
		var archer: Dictionary = s.add_unit("archer", 0, Vector2(5, 5))
		check(s.garrison(archer, house), "House admits occupant %d" % i)
	var extra: Dictionary = s.add_unit("archer", 0, Vector2(5, 5))
	check(not s.garrison(extra, house), "House rejects eleventh occupant")
	enemy = s.add_unit("swordsman", 1, Vector2(7, 5))
	enemy.hp = 2000.0
	enemy.max_hp = 2000.0
	s.update_visibility()
	s.step_building(house, 0.1)
	check(enemy.hp == 1800, "House fire capped at five archers")
	house.kind = "base"
	house.cooldown = 0.0
	s.step_building(house, 0.1)
	check(enemy.hp == 1480, "Base fire capped at eight archers")
	sniper = s.add_unit("sniper", 1, Vector2(7, 5))
	var sniper_target: Dictionary = s.nearest_target(sniper, 9, true)
	check(sniper_target.has("home"), "Sniper prioritizes occupants over building at same position")
	sniper.order = "attack"
	sniper.target = house.id
	var defender: Dictionary = s.occupants(house.id)[0]
	var defender_hp: float = defender.hp
	s.step_unit(sniper, 0.1)
	check(defender.hp < defender_hp and house.hp == 1000, "Sniper attack-building command penetrates garrison")
	# Special troop behavior uses the supplied spreadsheet values.
	s = fresh()
	s.units.clear()
	s.buildings.clear()
	var ice: Dictionary = s.add_unit("ice_archer_plus", 0, Vector2(5, 5))
	enemy = s.add_unit("cavalry", 1, Vector2(7, 5))
	s.hit(ice, enemy, 1, true)
	check(enemy.slow == 0.3 and enemy.slow_time > 0, "Advanced ice arrow applies movement and attack-speed slow")
	var healer: Dictionary = s.add_unit("paladin", 0, Vector2(5, 6))
	ice.hp = 50.0
	s.step_unit(healer, 1)
	check(ice.hp == 53, "Paladin aura restores 3 HP per second")
	var heavy: Dictionary = s.add_unit("cataphract", 0, Vector2(7, 6))
	s.update_visibility()
	s.step_unit(heavy, 0.1)
	check(enemy.frozen == 1.0 and heavy.special == 10.0, "Cataphract stuns with 10-second cooldown")
	var blink: Dictionary = s.add_unit("hermit_blink", 0, Vector2(9, 5))
	s.command([blink.id], "attack", s.point(enemy), enemy.id)
	s.update_visibility()
	s.step_unit(blink, 0.1)
	check(blink.special == 10 and s.unit_position_clear(s.point(blink), blink.kind, blink.id), "Hermit blink lands beside the target without overlapping")
	var hermit: Dictionary = s.add_unit("hermit", 1, Vector2(13, 5))
	s.units = [ice, hermit]
	check(s.nearest_target(ice, 10, false).is_empty(), "Hermit reduces ranged detection by 40 percent")
	s = fresh()
	s.start_wave()
	s.start_wave()
	check(s.units.any(func(u): return u.team == 1 and u.order == "garrison"), "Enemy sends an occupation unit")
	s.start_wave()
	check(s.buildings.any(func(b): return b.team == 1 and not b.complete), "Enemy constructs new outpost")
	var chest: Dictionary = s.chests[0]
	worker = s.living(0)[0]
	worker.hp = 50
	var reward_gold: float = s.gold
	s.open_chest(chest, worker)
	check(s.gold == reward_gold + 180 and worker.rank == 1 and worker.hp >= 75, "Chest grants currency, advancement and healing effect")
	s.open_chest(chest, worker)
	check(s.gold == reward_gold + 180, "Chest cannot be collected twice")
	s = fresh()
	s.wave = Rules.WAVE_COUNT
	s.phase = "defense"
	s.timer = 0
	s.step(0.05)
	check(s.phase == "cleanup", "Final wave transitions to cleanup")
	s.units = s.living(0)
	s.buildings = s.buildings.filter(func(b): return b.team != 1)
	s.check_outcome()
	check(s.phase == "victory", "Victory requires all enemy units and buildings cleared")
	var unit_ids: Array = s.living(0).map(func(u): return u.id)
	check(s.next_battle() and s.living(0).map(func(u): return u.id) == unit_ids, "Victory retains troops for next battle")
	s.units.clear()
	s.buildings.clear()
	s.check_outcome()
	check(s.phase == "defeat", "Annihilation ends expedition")
	# Run the timed campaign without skipping waves. A durable base isolates the
	# phase/spawn/AI lifecycle from balance, which is assessed separately.
	s = fresh()
	s.buildings[0].hp = 1000000000.0
	s.buildings[0].max_hp = 1000000000.0
	for ally in s.living(0):
		ally.hp = 1000000000.0
		ally.max_hp = 1000000000.0
	for i in 2100: s.step(0.2)
	check(s.wave == Rules.WAVE_COUNT and s.phase == "cleanup", "Full timed campaign reaches cleanup")
	var restored_campaign = Sim.new()
	check(restored_campaign.restore(JSON.parse_string(JSON.stringify(s.snapshot()))), "Full battle state can be restored")
	for i in 20: restored_campaign.step(0.05)
	check(restored_campaign.phase == "cleanup", "Restored battle resumes AI and timers")
	restored_campaign.phase = "victory"
	var finished_gold: float = restored_campaign.gold
	restored_campaign.step(10)
	check(restored_campaign.gold == finished_gold, "Finished state stops economy and combat")
	var scene = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.train_buttons.size() == 20, "Scene creates all unit controls")
	scene.pick_card("supplies")
	scene.pick_card("mana")
	scene.confirm_opening_cards()
	scene.sim.choose_base(0)
	scene.select_all()
	scene.select_all()
	scene.sim.set_point(scene.sim.living(0)[0], Vector2(15, 6))
	scene.sim.update_visibility()
	scene.contextual_order(Vector2(14, 6))
	check(scene.sim.living(0)[0].order == "chest", "Right-click dispatches chest order")
	scene.sim.start_wave()
	for i in 200: scene.sim.step(0.05)
	scene.refresh_ui()
	check(scene.sim.wave == 1, "Battle smoke simulation")
	scene.queue_free()
	await process_frame
	print("RTS_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func test_training_spacing_and_placement() -> void:
	var s = fresh()
	s.gold = 10000
	var base: Dictionary = s.buildings[0]
	var worker: Dictionary = s.living(0)[0]
	var before_preview := JSON.stringify(s.snapshot())
	check(s.construction_error("barracks", Vector2(13.2, 25.1), [worker.id]).is_empty(), "Preview accepts a valid snapped building cell")
	check(not s.construction_error("barracks", s.point(base), [worker.id]).is_empty(), "Preview rejects building proximity")
	check(not s.construction_error("house", Vector2.ZERO, [worker.id]).is_empty(), "Preview rejects water")
	check(not s.construction_error("well", Vector2(13, 25), []).is_empty(), "Preview requires an eligible builder")
	check(JSON.stringify(s.snapshot()) == before_preview, "Preview queries leave the simulation unchanged")
	for i in 5: check(s.train_unit("swordsman", base.id), "Queue five reinforcements")
	for i in 5:
		s.step_building(base, Rules.TRAIN_SECONDS)
		var spawned: Dictionary = s.units.back()
		check(s.walkable(Vector2i(s.point(spawned))), "Trained unit spawns on walkable terrain")
		for u in s.units:
			if u.id == spawned.id or u.hp <= 0 or u.home != -1: continue
			check(s.point(u).distance_to(s.point(spawned)) >= Rules.body_radius(u.kind) + Rules.body_radius(spawned.kind), "Trained bodies keep clearance from existing units")
		for b in s.buildings:
			check(s.point(b).distance_to(s.point(spawned)) >= 1.5, "Trained units spawn outside buildings")
	# A tiny enclosed exit must wait instead of stacking units or spawning
	# across an impassable wall; freeing it releases the completed recruit.
	s = Sim.new()
	s.phase = "prep"
	s.gold = 10000
	base = s.add_building("base", 0, Vector2(8, 25))
	for y in s.HEIGHT:
		for x in s.WIDTH: s.navigation.set_point_solid(Vector2i(x, y), true)
	for x in range(8, 11): s.navigation.set_point_solid(Vector2i(x, 25), false)
	var blocker: Dictionary = s.add_unit("archer", 0, Vector2(10, 25))
	check(s.train_unit("swordsman", base.id), "Queue recruit at enclosed producer")
	s.step_building(base, Rules.TRAIN_SECONDS)
	check(base.queue.size() == 1 and s.units.size() == 1, "Blocked exit retains completed recruit in queue")
	blocker.home = base.id
	s.step_building(base, 0.1)
	check(base.queue.is_empty() and s.units.size() == 2 and s.point(s.units.back()) == Vector2(10, 25), "Cleared exit releases recruit without stacking")
