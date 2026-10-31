extends "res://scripts/game/rts_simulation.gd"

var actions: Dictionary = {}
var battle_allowed := false
var training_tree_id := -1

func update_visibility() -> void:
	super.update_visibility()
	for unit in living(1):
		if unit.max_hp == 10000.0: reveal_circle(point(unit), 4)
	var tree := entity(training_tree_id)
	if not tree.is_empty(): reveal_circle(point(tree), 3)

func mark(key: String) -> void:
	actions[key] = true

func populate_map() -> void:
	add_building("house", -1, safe_cell(Vector2(46, 25)))
	var pos := safe_cell(Vector2(43, 28))
	chests.append({"id": allocate_id(), "x": pos.x, "y": pos.y})

func populate_resources() -> void:
	if not resource_sites.is_empty(): return
	for i in 3:
		var pos := safe_cell(Vector2(44 + i * 3, 20))
		resource_sites.append({"id": allocate_id(), "kind": ["gold_mine", "mana_spring", "vision_tower"][i], "x": pos.x, "y": pos.y, "team": -1, "capture": 0.0, "capturing_team": -1, "discovered": true})

func step(delta: float) -> void:
	timer = 9999.0
	gold = maxf(gold, 3000)
	baka = maxi(baka, 500)
	super.step(delta)

func command(ids: Array, order: String, pos: Vector2, target := -1, append := false) -> void:
	super.command(ids, order, pos, target, append)
	for id in ids:
		var u := entity(int(id))
		if u.is_empty() or not u.has("order") or u.team != 0 or u.home != -1: continue
		if u.order == order or u.orders.any(func(o): return o.order == order):
			mark(order)
			if append and not u.orders.is_empty(): mark("queue")

func cast(spell: String, pos: Vector2) -> bool:
	var ok := super.cast(spell, pos)
	if ok and (spell != "freeze" or living(1).any(func(u): return u.frozen > 0)): mark(spell)
	return ok

func set_rally(id: int, pos: Vector2, append := false) -> bool:
	var ok := super.set_rally(id, pos, append)
	if ok: mark("rally")
	return ok

func train_unit(kind: String, building_id := -1) -> bool:
	var ok := super.train_unit(kind, building_id)
	if ok: mark("train")
	return ok

func research_unit(kind: String) -> bool:
	var ok := super.research_unit(kind)
	if ok: mark("research")
	return ok

func evacuate(id: int) -> void:
	var had_units := not occupants(id).is_empty()
	super.evacuate(id)
	if had_units and occupants(id).is_empty(): mark("evacuate")

func start_wave() -> void:
	if not battle_allowed or wave > 0: return
	wave = 1
	phase = "defense"
	for i in 3:
		var enemy := add_unit("swordsman", 1, safe_cell(Vector2(48 + i, 25)))
		enemy.hp = 30.0
		enemy.attack = 1.0
	var camp := add_building("outpost", 1, safe_cell(Vector2(50, 25)))
	camp.hp = 30.0
	mark("wave")
