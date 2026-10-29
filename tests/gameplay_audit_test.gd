extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
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

func fresh():
	var s = Sim.new()
	s.rng.seed = 137
	s.choose_card("supplies")
	s.choose_card("mana")
	s.choose_base(1)
	return s

func run() -> void:
	var s = Sim.new()
	check(s.draw_cards().is_empty() and s.phase == "cards", "Automatic card draw cannot choose for the player")
	check(s.choose_card("supplies") and not s.choose_card("supplies"), "Explicit card choices are distinct")
	var restored = Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and restored.choose_card("mana") and restored.phase == "prep", "Partially chosen legacy save completes at central base")
	s = fresh()
	var base: Dictionary = s.buildings[0]
	var survivor: Dictionary = s.living(0)[0]
	s.units = [survivor]
	check(s.garrison(survivor, base), "Last troop can shelter in base")
	s.check_outcome()
	check(s.active(), "Garrison counts as a surviving army")
	base.queue = ["swordsman"]
	var foe: Dictionary = s.add_unit("sniper", 1, Vector2(12, 25))
	s.hit(foe, survivor, 100000, true)
	check(s.active() and base.hp == 2000 and s.living(0).is_empty(), "Losing every troop does not lose while the base survives")
	var gold_before: float = s.gold
	s.units.erase(foe)
	s.step(Rules.TRAIN_SECONDS)
	check(s.active() and s.gold == gold_before and s.living(0).size() == 1, "Surviving base continues queued training without passive income")
	var surviving_site: Dictionary = s.add_building("well", 0, Vector2(15, 25), false)
	foe = s.add_unit("swordsman", 1, Vector2(12, 25))
	s.hit(foe, base, 100000, false)
	check(s.active() and surviving_site.hp > 0 and not surviving_site.complete, "Base destruction is survivable with an unfinished friendly building")
	s.hit(foe, surviving_site, 100000, false)
	check(s.phase == "defeat" and not s.living(0).is_empty(), "Last friendly building destruction loses immediately even with surviving troops")
	gold_before = s.gold
	var elapsed_before: float = s.elapsed
	s.step(10)
	check(s.gold == gold_before and s.elapsed == elapsed_before, "Defeat stops production and battle simulation")
	s = fresh()
	s.phase = "cleanup"
	s.units = s.units.filter(func(u): return u.team != 1)
	s.buildings = s.buildings.filter(func(b): return b.team != 1)
	s.check_outcome()
	check(s.phase == "victory" and s.living(2).size() == Field.WILDLIFE.size(), "Optional wildlife does not block victory")
	var army: Array = s.living(0).duplicate(true)
	var structures: Array = s.buildings.filter(func(b): return b.team == 0).duplicate(true)
	var chest_ids: Array = s.chests.map(func(c): return c.id)
	s.set_point(s.living(2)[0], Vector2(8, 40))
	check(s.wildlife_alive_at(Field.WILDLIFE[0]), "Roaming wildlife still belongs to its original exploration site")
	check(s.next_battle(), "Victory can continue expedition")
	check(s.living(0).map(func(u): return u.id) == army.map(func(u): return u.id) and s.living(0)[0].hp == army[0].hp, "Troop identities and health survive next battle")
	check(s.buildings[0].id == structures[0].id and s.buildings[0].hp == structures[0].hp, "Structures survive next battle")
	check(s.chests.size() == Field.CHESTS.size() and s.chests.map(func(c): return c.id) == chest_ids and s.living(2).size() == Field.WILDLIFE.size(), "Uncollected exploration objects are not duplicated")
	var cleared: Dictionary = s.chests[0]
	s.open_chest(cleared, s.living(0)[0])
	s.units = s.units.filter(func(u): return u.team == 0)
	s.buildings = s.buildings.filter(func(b): return b.team == 0)
	s.phase = "cleanup"
	s.check_outcome()
	s.next_battle()
	check(s.chests.size() == Field.CHESTS.size() and s.living(2).size() == Field.WILDLIFE.size(), "Cleared exploration sites refill once per expedition")
	var old_save: Dictionary = s.snapshot()
	old_save.chests.append(old_save.chests[0].duplicate(true))
	old_save.chests.back().id = old_save.next_id
	old_save.next_id += 1
	restored = Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(old_save))) and restored.chests.size() == Field.CHESTS.size(), "Legacy stacked treasures are repaired on load")
	var hunter: Dictionary = restored.living(0)[0]
	var wildlife: Dictionary = restored.living(2)[0]
	hunter.hp = 20
	gold_before = restored.gold
	var mana_before: float = restored.baka
	restored.hit(hunter, wildlife, 10000, false)
	check(restored.gold > gold_before and restored.baka == minf(300, mana_before + Rules.WILDLIFE_BAKA) and hunter.kill_value > 0 and hunter.hp > 20, "Wildlife grants gold, advancement, mana and a healing effect")
	var rewarded_hp: float = hunter.hp
	restored.hit(hunter, wildlife, 10000, false)
	check(hunter.hp == rewarded_hp, "Wildlife reward cannot be collected twice")
	# Occupation and construction must finish, rather than merely have an order.
	s = fresh()
	s.start_wave()
	s.start_wave()
	var occupier: Dictionary = s.units.filter(func(u): return u.team == 1 and u.order == "garrison")[0]
	var house: Dictionary = s.entity(int(occupier.target))
	check(s.reachable_goal(s.point(occupier), s.point(house)) != Vector2i(-1, -1), "Enemy chooses a reachable entrance to the blocked house")
	for i in 2500: s.step_unit(occupier, 0.05)
	check(occupier.home == house.id and house.team == 1, "Enemy walks to and captures house")
	s.start_wave()
	var builder: Dictionary = s.units.filter(func(u): return u.team == 1 and u.order == "repair")[0]
	var site: Dictionary = s.entity(int(builder.target))
	for i in 2200: s.step_unit(builder, 0.05)
	check(site.complete and site.hp == 1000, "Enemy builder finishes its outpost")
	s = fresh()
	s.add_building("house", 0, Vector2(67, 28))
	s.start_wave()
	s.start_wave()
	s.start_wave()
	site = s.buildings.filter(func(b): return b.team == 1 and not b.complete)[0]
	check(s.point(site).distance_to(Vector2(67, 28)) >= 2.3 and not s.water(Vector2i(s.point(site))), "Enemy construction respects occupied land")
	house = s.buildings.filter(func(b): return b.team == -1)[0]
	# A rival capture while walking triggers another neutral destination.
	var late: Dictionary = s.add_unit("swordsman", 1, s.point(house))
	late.order = "garrison"
	late.target = house.id
	house.team = 0
	s.step_unit(late, 0.05)
	check(late.order == "garrison" and late.target != house.id, "Failed occupation retargets a neutral house")
	s = fresh()
	s.units = s.living(0)
	for ally in s.units:
		ally.hp = 1000000
		ally.max_hp = 1000000
	s.wave = Rules.WAVE_COUNT
	s.phase = "defense"
	s.timer = 0
	s.step(0.05)
	check(s.phase == "cleanup" and s.living(1).size() == 2 and s.living(1).all(func(u): return u.kind == "swordsman"), "Final wave gives way to small basic raids")
	s.start_wave()
	check(s.wave == Rules.WAVE_COUNT, "Main assault never exceeds finite wave count")
	s.timer = 0
	s.step(0.05)
	check(s.living(1).size() == 4, "Each surviving camp sends one weak troop per interval")
	var camp: Dictionary = s.buildings.filter(func(b): return b.team == 1)[0]
	s.hit(s.living(0)[0], camp, 100000, false)
	var count_before := s.living(1).size()
	s.timer = 0
	s.step(0.05)
	check(s.living(1).size() == count_before + 1, "Destroyed camp no longer sends reinforcements")
	# Enemy pursuit remains meaningful after the player loses every building.
	s = fresh()
	s.buildings.clear()
	s.units = [s.living(0)[0]]
	s.set_point(s.units[0], Vector2(8, 25))
	foe = s.add_unit("swordsman", 1, Vector2(72, 25))
	var pos_before: Vector2 = s.point(foe)
	s.step_unit(foe, 1)
	check(s.point(foe) != pos_before and foe.raid_target == s.units[0].id, "Raid pursues distant surviving troops without buildings")
	s.buildings.clear()
	var island_target: Dictionary = s.add_unit("archer", 0, Vector2(54, 25))
	s.set_point(foe, Vector2(50, 25))
	foe.raid_clock = 0
	check(s.raid_target(foe, false).id == s.units[0].id, "Strategic pursuit skips an inaccessible island target")
	check(s.cast("bridge", Vector2(51, 25)) and s.raid_target(foe, false).id == island_target.id, "New ice bridge invalidates cached raid target")
	# Building fire obeys the archer cap even when occupants have promoted.
	s = fresh()
	s.units.clear()
	s.buildings.clear()
	s.catalog.archer.crit_chance = 0
	house = s.add_building("house", 0, Vector2(5, 5))
	for i in 3:
		var archer: Dictionary = s.add_unit("archer", 0, Vector2(5, 5))
		s.credit_kill(archer, 1000)
		s.garrison(archer, house)
	foe = s.add_unit("swordsman", 1, Vector2(7, 5))
	foe.hp = 10000
	s.update_visibility()
	s.step_building(house, 0.1)
	check(foe.hp == 9856, "Three promoted archers apply their 20 percent damage bonus to garrison fire")
	house.cooldown = 0
	s.units.erase(foe)
	var hermit: Dictionary = s.add_unit("hermit", 1, Vector2(9, 5))
	var hp_before: float = hermit.hp
	s.step_building(house, 0.1)
	check(hermit.hp == hp_before, "Hermit also shortens garrison ranged detection")
	var hidden: Dictionary = s.add_unit("hermit", 0, Vector2(30, 5))
	var ranged_foe: Dictionary = s.add_unit("sniper", 1, Vector2(38, 5))
	s.units = [hidden, ranged_foe]
	s.buildings.clear()
	hp_before = hidden.hp
	s.step_unit(ranged_foe, 0.05)
	check(hidden.hp == hp_before and ranged_foe.raid_target == -1, "Global raid targeting does not bypass hermit detection reduction")
	s.units = [s.add_unit("hermit", 1, Vector2(9, 5))]
	hermit = s.units[0]
	var blink: Dictionary = s.add_unit("hermit_blink", 0, Vector2(6.5, 5))
	s.command([blink.id], "attack", s.point(hermit), hermit.id)
	s.update_visibility()
	s.step_unit(blink, 0.05)
	check(blink.special == 0, "Blink cannot jump farther than two cells")
	s.set_point(blink, Vector2(7, 5))
	s.step_unit(blink, 0.05)
	check(blink.special == 10 and s.unit_position_clear(s.point(blink), blink.kind, blink.id), "Blink triggers at two-cell range")
	s = fresh()
	s.units.clear()
	s.buildings.clear()
	base = s.add_building("base", 0, Vector2(5, 5))
	s.catalog.archer.crit_chance = 0
	for i in 20:
		check(s.garrison(s.add_unit("archer", 0, Vector2(5, 5)), base), "Base accepts occupant " + str(i + 1))
	check(not s.garrison(s.add_unit("archer", 0, Vector2(5, 5)), base), "Base rejects its twenty-first occupant")
	foe = s.add_unit("swordsman", 1, Vector2(7, 5))
	foe.hp = 10000
	s.update_visibility()
	s.step_building(base, 0.1)
	check(foe.hp == 9680, "Twenty occupants still cap at eight initial-archer shots")
	var veteran: Dictionary = s.occupants(base.id)[0]
	s.credit_kill(veteran, 1000)
	veteran.hp = 20
	s.set_point(foe, Vector2(70, 5))
	s.step_building(base, 1)
	s.step_unit(veteran, 1)
	check(is_equal_approx(veteran.hp, 20 + veteran.max_hp * 0.07), "Top-rank base garrison stacks five and two percent healing")
	s = fresh()
	s.units = s.units.filter(func(u): return u.team == 0)
	s.buildings = s.buildings.filter(func(b): return b.team == 0)
	base = s.buildings[0]
	base.hp = 0
	s.buildings.clear()
	s.add_building("house", 0, Vector2(12, 25))
	s.phase = "cleanup"
	var enemy_house: Dictionary = s.add_building("house", 1, Vector2(20, 25))
	s.check_outcome()
	check(s.phase == "cleanup", "Intact empty enemy house still blocks victory and supplies raids")
	s.hit(s.living(0)[0], enemy_house, 10000, false)
	s.check_outcome()
	check(s.phase == "victory", "Army can win without its base when another friendly building survives")
	# UI exposes damaged-building garrison and repair as separate orders.
	var game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.pick_card("supplies")
	game.pick_card("mana")
	game.confirm_opening_cards()
	check(game.sim.phase == "prep" and game.sim.cards.size() == 2, "Opening UI confirms choices and starts at central base")
	game.sim.choose_base(1)
	await process_frame
	game.all_select_stage = 0
	game.select_all()
	game.select_all()
	base = game.sim.buildings[0]
	base.hp = 1000
	game.set_mode("garrison")
	check(game.building_order(game.sim.point(base), "garrison"), "Garrison command accepts damaged base")
	for u in game.sim.living(0):
		game.sim.set_point(u, game.sim.point(base))
		game.sim.step_unit(u, 0.05)
	check(game.sim.occupants(base.id).size() == 3, "Damaged-building order actually shelters all initial troops")
	game.selected_building = base.id
	game.evacuate_selected()
	game.all_select_stage = 0
	game.select_all()
	game.select_all()
	check(game.building_order(game.sim.point(base), "repair"), "Repair command remains independently available")
	var repair_before: float = base.hp
	for u in game.sim.living(0): game.sim.set_point(u, game.sim.point(base))
	for u in game.sim.living(0): game.sim.step_unit(u, 1)
	check(is_equal_approx(base.hp - repair_before, 90 if game.sim.cards.has("builders") else 60), "Selected builders stack their documented repair rates")
	game.queue_free()
	await process_frame
	print("GAMEPLAY_AUDIT_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
