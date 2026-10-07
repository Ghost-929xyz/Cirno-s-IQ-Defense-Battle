extends RefCounted
## Deterministic, scene-independent RTS rules. Coordinates are logical cells.
const Rules = preload("res://scripts/data/rts_rules.gd")
const WIDTH := 40
const HEIGHT := 25
const BASE_SITES := [Vector2(5, 6), Vector2(5, 12), Vector2(5, 19)]
var catalog := Rules.catalog()
var units: Array = []
var buildings: Array = []
var chests: Array = []
var walls: Array = []
var bridges: Array = []
var shots: Array = []
var cards: Array = []
var phase := "cards"
var gold := float(Rules.START_GOLD)
var baka := Rules.START_BAKA
var tech := 1
var tier := 1
var wave := 0
var campaign := 1
var timer := Rules.PREP_SECONDS
var elapsed := 0.0
var next_id := 1
var message := "选择两张效果牌，随后选择基地位置。"
var rng := RandomNumberGenerator.new()
var navigation := AStarGrid2D.new()
var navigation_revision := 0
var _painted_water: Dictionary = {}
var _use_painted_terrain := false

func _init() -> void:
	rng.randomize()
	navigation.region = Rect2i(0, 0, WIDTH, HEIGHT)
	navigation.cell_size = Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	navigation.update()
	rebuild_navigation()

func point(entity: Dictionary) -> Vector2:
	return Vector2(float(entity.x), float(entity.y))

func set_point(entity: Dictionary, pos: Vector2) -> void:
	entity.x = pos.x
	entity.y = pos.y

func water(cell: Vector2i) -> bool:
	if _use_painted_terrain: return _painted_water.has(cell)
	var river := cell.x in [19, 20, 21] and cell.y not in [6, 7, 18, 19]
	var island_moat := ((cell.x in [25, 29] and cell.y >= 9 and cell.y <= 15)
		or (cell.y in [9, 15] and cell.x >= 25 and cell.x <= 29))
	return river or island_moat

func configure_terrain(water_cells: Array[Vector2i]) -> void:
	_painted_water.clear()
	for cell in water_cells: _painted_water[cell] = true
	_use_painted_terrain = true
	rebuild_navigation()

func inside(cell: Vector2i) -> bool:
	return Rect2i(0, 0, WIDTH, HEIGHT).has_point(cell)

func walkable(cell: Vector2i) -> bool:
	return inside(cell) and not navigation.is_point_solid(cell)

func rebuild_navigation() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			var blocked := water(cell) and not bridges.has([x, y])
			for wall in walls:
				if Vector2i(point(wall)) == cell:
					blocked = true
			navigation.set_point_solid(cell, blocked)
	navigation_revision += 1

func choose_card(id: String) -> bool:
	if phase != "cards" or cards.has(id) or cards.size() >= 2:
		return false
	var valid := false
	for card in Rules.CARDS:
		if card.id == id:
			valid = true
	if not valid:
		return false
	cards.append(id)
	if id == "supplies": gold += 250
	if id == "mana": baka += 50
	if cards.size() == 2:
		phase = "base"
		message = "点击地图上三个基地候选点中的一个。"
	return true

func choose_base(index: int) -> bool:
	if phase != "base" or index < 0 or index >= BASE_SITES.size():
		return false
	var pos: Vector2 = BASE_SITES[index]
	add_building("base", 0, pos)
	add_unit("swordsman", 0, pos + Vector2(1, 1))
	add_unit("swordsman", 0, pos + Vector2(1, -1))
	add_unit("archer", 0, pos + Vector2(2, 0))
	populate_map()
	phase = "prep"
	message = "框选部队后右键下令；训练援军、建造兵营，或前往宝箱。"
	return true

func populate_map() -> void:
	for pos in [Vector2(12, 6), Vector2(15, 18), Vector2(28, 12)]:
		add_building("house", -1, pos)
	for pos in [Vector2(34, 5), Vector2(35, 20)]:
		var camp := add_building("outpost", 1, pos)
		var guard := add_unit("archer", 1, pos)
		guard.home = camp.id
	for pos in [Vector2(10, 3), Vector2(16, 12), Vector2(25, 4), Vector2(30, 21), Vector2(27, 12)]:
		chests.append({"id": allocate_id(), "x": pos.x, "y": pos.y})
	for pos in [Vector2(16, 11), Vector2(26, 4), Vector2(30, 20)]:
		add_unit("swordsman", 2, pos)

func allocate_id() -> int:
	var value := next_id
	next_id += 1
	return value

func add_building(kind: String, team: int, pos: Vector2, complete := true) -> Dictionary:
	var rule: Dictionary = Rules.BUILDINGS[kind]
	var b := {"id": allocate_id(), "kind": kind, "team": team, "x": pos.x, "y": pos.y,
		"hp": float(rule.hp) if complete else 1.0, "max_hp": float(rule.hp),
		"complete": complete, "queue": [], "train": 0.0, "cooldown": 0.0}
	buildings.append(b)
	return b

func add_unit(kind: String, team: int, pos: Vector2) -> Dictionary:
	var d: Dictionary = catalog[kind]
	var hp := float(d.hp) * (1.15 if team == 0 and cards.has("vitality") else 1.0)
	var u := {"id": allocate_id(), "kind": kind, "team": team, "x": pos.x, "y": pos.y,
		"hp": hp, "max_hp": hp, "attack": float(d.attack), "rank": 0, "kill_value": 0.0,
		"home": -1, "order": "idle", "target": -1, "goal_x": pos.x, "goal_y": pos.y,
		"cooldown": 0.0, "special": 0.0, "frozen": 0.0, "slow_time": 0.0, "slow": 0.0,
		"path": [], "path_revision": -1, "path_goal": [-1, -1]}
	units.append(u)
	return u

func entity(id: int) -> Dictionary:
	for item in units + buildings + chests:
		if int(item.id) == id:
			return item
	return {}

func living(team: int) -> Array:
	return units.filter(func(u): return int(u.team) == team and float(u.hp) > 0)

func capacity() -> int:
	var total := 0
	for b in buildings:
		if int(b.team) == 0 and b.complete and b.hp > 0:
			total += 40 if b.kind == "base" else 20
	return total

func used_capacity() -> int:
	var total := 0
	for u in living(0): total += int(catalog[u.kind].capacity)
	for b in buildings:
		if int(b.team) == 0:
			for kind in b.queue: total += int(catalog[kind].capacity)
	return total

func active() -> bool:
	return phase in ["prep", "defense", "cleanup"]

func train_unit(kind: String, building_id := -1) -> bool:
	if not active() or not catalog.has(kind): return false
	var d: Dictionary = catalog[kind]
	if int(d.tech) > tech or int(d.tier) > tier:
		message = "需要科技 %d / 兵种层级 %d。" % [d.tech, d.tier]
		return false
	if gold < float(d.cost) or used_capacity() + int(d.capacity) > capacity():
		message = "金币或单位容量不足（训练队列也占用容量）。"
		return false
	for b in buildings:
		if int(b.team) == 0 and b.hp > 0 and b.complete and b.kind in ["base", "barracks"] and (building_id == -1 or int(b.id) == building_id):
			if b.queue.size() >= 5:
				continue
			b.queue.append(kind)
			gold -= float(d.cost)
			message = "%s 已加入训练队列。" % d.name
			return true
	message = "需要可用的主基地或兵营（每处队列上限 5）。"
	return false

func research(which: String) -> bool:
	if not active(): return false
	if which == "tech" and tech < 2 and gold >= Rules.TECH_COST:
		gold -= Rules.TECH_COST
		tech += 1
		return true
	if which == "tier" and tier < 3 and gold >= Rules.TIER_COST:
		gold -= Rules.TIER_COST
		tier += 1
		return true
	message = "金币不足，或研究已经达到最高等级。"
	return false

func construct(kind: String, pos: Vector2, builders: Array) -> bool:
	if not active() or kind not in ["barracks", "well", "house"]: return false
	var eligible: Array = []
	for id in builders:
		var u := entity(int(id))
		if not u.is_empty() and u.has("home") and u.team == 0 and u.home == -1 and u.hp > 0: eligible.append(id)
	if eligible.is_empty():
		message = "先选择至少一名建筑外的己方单位。"
		return false
	var cost := float(Rules.BUILDINGS[kind].cost)
	if gold < cost or not walkable(Vector2i(pos)) or water(Vector2i(pos)):
		message = "需要足够金币，并在陆地空地上建造。"
		return false
	for b in buildings:
		if point(b).distance_to(pos) < 2.3:
			message = "建筑之间需预留空间。"
			return false
	gold -= cost
	var site := add_building(kind, 0, pos.round(), false)
	command(eligible, "repair", point(site), int(site.id))
	message = "工地已放置，单位抵达后每人每秒建造 20 点生命。"
	return true

func command(ids: Array, order: String, pos: Vector2, target := -1) -> void:
	if not active(): return
	var index := 0
	for id in ids:
		var u := entity(int(id))
		if u.is_empty() or not u.has("home") or u.team != 0 or u.hp <= 0 or u.home != -1: continue
		u.order = order
		u.target = target
		var goal := pos
		if order == "move" and ids.size() > 1:
			goal = safe_cell(pos + Vector2(index % 4, index / 4) * 0.8)
			index += 1
		u.goal_x = goal.x
		u.goal_y = goal.y
		u.path = []
		u.path_revision = -1

func occupants(building_id: int) -> Array:
	return units.filter(func(u): return int(u.home) == building_id and u.hp > 0)

func garrison(u: Dictionary, b: Dictionary) -> bool:
	if b.is_empty() or not b.has("complete") or not b.complete or b.hp <= 0 or (b.team != -1 and b.team != u.team): return false
	# The source explicitly limits garrisoning to initial troop types.
	if u.kind not in ["swordsman", "archer"]: return false
	if occupants(int(b.id)).size() >= int(Rules.BUILDINGS[b.kind].beds): return false
	b.team = u.team
	u.home = b.id
	u.order = "idle"
	set_point(u, point(b))
	return true

func evacuate(building_id: int) -> void:
	var b := entity(building_id)
	if b.is_empty(): return
	var index := 0
	for u in occupants(building_id):
		u.home = -1
		u.order = "idle"
		set_point(u, safe_cell(point(b) + Vector2(1 + index % 3, index / 3)))
		index += 1

func safe_cell(pos: Vector2) -> Vector2:
	var cell := Vector2i(pos.round()).clamp(Vector2i.ZERO, Vector2i(WIDTH - 1, HEIGHT - 1))
	if walkable(cell): return Vector2(cell)
	for radius in range(1, WIDTH):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, y)
				if walkable(candidate): return Vector2(candidate)
	return Vector2.ZERO

func cast(spell: String, pos: Vector2) -> bool:
	if not active() or not inside(Vector2i(pos)): return false
	var cost := Rules.FREEZE_COST
	if spell == "wall": cost = Rules.WALL_COST
	elif spell == "bridge": cost = Rules.BRIDGE_COST
	elif spell != "freeze": return false
	if baka < cost:
		message = "BAKA 不足。"
		return false
	if spell == "freeze":
		for u in units:
			if u.team != 0 and u.home == -1 and point(u).distance_to(pos) <= 3: u.frozen = Rules.FREEZE_SECONDS
	elif spell == "bridge":
		var changed := false
		for y in range(roundi(pos.y) - 1, roundi(pos.y) + 2):
			for x in range(roundi(pos.x) - 1, roundi(pos.x) + 2):
				var cell := Vector2i(x, y)
				if inside(cell) and water(cell) and not bridges.has([cell.x, cell.y]):
					bridges.append([cell.x, cell.y])
					changed = true
		if not changed:
			message = "选择河面，冻结一条永久冰桥。"
			return false
	else:
		var cells: Array = []
		for dy in [-1, 0, 1]:
			var cell := Vector2i(pos.round()) + Vector2i(0, dy)
			if not walkable(cell) or water(cell): continue
			var occupied := false
			for b in buildings:
				if point(b).distance_to(Vector2(cell)) < 1.8: occupied = true
			for u in units:
				if u.home == -1 and point(u).distance_to(Vector2(cell)) < 0.75: occupied = true
			if not occupied: cells.append(cell)
		if cells.is_empty():
			message = "冰墙需要空地，不能覆盖单位或建筑。"
			return false
		for cell in cells: walls.append({"x": cell.x, "y": cell.y, "ttl": Rules.WALL_SECONDS})
		for u in units:
			if u.team != 0 and u.home == -1 and point(u).distance_to(pos) <= 2: u.frozen = 2.0
	baka -= cost
	rebuild_navigation()
	return true

func start_wave() -> void:
	if phase not in ["prep", "defense"] or wave >= Rules.WAVE_COUNT: return
	wave += 1
	phase = "defense"
	timer = Rules.WAVE_SECONDS
	var amount := 5 + wave * 3 + (campaign - 1) * 2
	for i in amount:
		var kind := "swordsman"
		if i % 3 == 0: kind = "archer"
		if wave >= 3 and i % 5 == 0: kind = "cavalry"
		if wave >= 5 and i % 7 == 0: kind = "sniper"
		var u := add_unit(kind, 1, Vector2(38, 2 + i % 21))
		if i == 1 and wave == 2:
			for b in buildings:
				if b.team == -1:
					u.order = "garrison"
					u.target = b.id
					break
	if wave == 3:
		var site := add_building("outpost", 1, Vector2(31, 15), false)
		var builder := add_unit("swordsman", 1, Vector2(32, 15))
		builder.order = "repair"
		builder.target = site.id
	message = "第 %d / %d 波来袭。敌军会占房与建立据点。" % [wave, Rules.WAVE_COUNT]

func step(delta: float) -> void:
	if not active(): return
	elapsed += delta
	timer -= delta
	if timer <= 0:
		if wave < Rules.WAVE_COUNT: start_wave()
		else:
			phase = "cleanup"
			timer = Rules.WEAK_RAID_SECONDS
			for b in buildings:
				if b.team == 1 and b.complete: add_unit("swordsman", 1, point(b) + Vector2(-1, 0))
			message = "清剿阶段：摧毁敌军据点并消灭所有敌军与野怪。"
	var expired := false
	for wall in walls: wall.ttl -= delta
	for i in range(walls.size() - 1, -1, -1):
		if walls[i].ttl <= 0:
			walls.remove_at(i)
			expired = true
	if expired: rebuild_navigation()
	for s in shots: s.ttl -= delta
	shots = shots.filter(func(s): return s.ttl > 0)
	for b in buildings.duplicate():
		if b.hp > 0: step_building(b, delta)
	for u in units.duplicate():
		if u.hp > 0: step_unit(u, delta)
	units = units.filter(func(u): return u.hp > 0)
	buildings = buildings.filter(func(b): return b.hp > 0)
	check_outcome()

func step_building(b: Dictionary, delta: float) -> void:
	if not b.complete: return
	if b.team == 0:
		if b.kind == "base": gold += delta * 2.0
		if b.kind == "well": baka = minf(300.0, baka + delta * 2.0)
		if not b.queue.is_empty():
			b.train += delta
			if b.train >= Rules.TRAIN_SECONDS:
				b.train = 0.0
				add_unit(b.queue.pop_front(), 0, safe_cell(point(b) + Vector2(1.5, 1.5)))
	var inside_units := occupants(int(b.id))
	var ranged: Array = []
	for u in inside_units:
		u.hp = minf(u.max_hp, u.hp + u.max_hp * (0.05 if b.kind == "base" else 0.02) * delta)
		if catalog[u.kind].ranged: ranged.append(u)
	b.cooldown = maxf(0, b.cooldown - delta)
	if ranged.is_empty() or b.cooldown > 0: return
	var target := nearest_target(b, 5.0, false)
	if target.is_empty(): return
	var count := mini(ranged.size(), int(Rules.BUILDINGS[b.kind].fire))
	for i in count:
		if target.hp <= 0: break
		hit(ranged[i], target, float(catalog.archer.attack), true)
	b.cooldown = 1.0 / float(catalog.archer.attack_speed)

func step_unit(u: Dictionary, delta: float) -> void:
	var d: Dictionary = catalog[u.kind]
	u.cooldown = maxf(0, u.cooldown - delta)
	u.special = maxf(0, u.special - delta)
	u.frozen = maxf(0, u.frozen - delta)
	u.slow_time = maxf(0, u.slow_time - delta)
	if u.rank == 2: u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.03 * delta)
	if u.home != -1 or u.frozen > 0: return
	if u.kind == "paladin":
		for ally in units:
			if ally.team == u.team and ally.home == -1 and ally.hp > 0 and point(ally).distance_to(point(u)) <= 2:
				ally.hp = minf(ally.max_hp, ally.hp + 3 * delta)
	if u.order in ["repair", "garrison", "chest"]:
		var goal := entity(int(u.target))
		if goal.is_empty() or (goal.has("hp") and goal.hp <= 0):
			u.order = "idle"
		elif point(u).distance_to(point(goal)) > 1.5:
			move_unit(u, point(goal), delta)
			return
		else:
			if u.order == "repair":
				if goal.team != u.team: u.order = "idle"
				else:
					goal.hp = minf(goal.max_hp, goal.hp + 20 * (1.5 if u.team == 0 and cards.has("builders") else 1.0) * delta)
					if goal.hp >= goal.max_hp:
						goal.complete = true
						u.order = "idle"
			elif u.order == "garrison":
				if not garrison(u, goal): message = "仅剑士与弓箭手可驻军；建筑须完工且有空位。"
				u.order = "idle"
			else:
				open_chest(goal, u)
				u.order = "idle"
			return
	if u.order == "move":
		var destination := Vector2(u.goal_x, u.goal_y)
		if point(u).distance_to(destination) < 0.3: u.order = "idle"
		else:
			move_unit(u, destination, delta)
			return
	var sniper: bool = u.kind in ["sniper", "sniper_plus"]
	var target: Dictionary = {}
	if u.order == "attack":
		target = entity(int(u.target))
		if target.is_empty() or not target.has("hp") or target.hp <= 0 or (target.has("home") and target.home != -1 and not sniper):
			u.order = "idle"
			target = {}
		elif sniper and target.has("complete"):
			var defenders := occupants(int(target.id))
			if not defenders.is_empty(): target = defenders[0]
	if target.is_empty(): target = nearest_target(u, 10.0 if u.team != 2 else 4.0, sniper)
	if target.is_empty() and u.team == 1: target = nearest_target(u, 100.0, sniper, true)
	if target.is_empty(): return
	var distance := point(u).distance_to(point(target))
	if u.kind == "hermit_blink" and u.special <= 0 and distance > 1 and distance <= 3 and walkable(Vector2i(point(target))):
		set_point(u, point(target))
		u.special = 10.0
		distance = 0.0
	if u.kind == "cataphract" and u.special <= 0 and distance <= 2:
		for foe in units:
			if hostile(int(u.team), int(foe.team)) and foe.home == -1 and point(u).distance_to(point(foe)) <= 2: foe.frozen = maxf(foe.frozen, 1.0)
		u.special = 10.0
	var reach := float(d.range) + (0.7 if target.has("complete") else 0.0)
	if distance > reach:
		move_unit(u, point(target), delta)
	elif u.cooldown <= 0:
		hit(u, target, float(u.attack), bool(d.ranged))
		var slow_factor := 1.0 - float(u.slow) if u.slow_time > 0 else 1.0
		u.cooldown = 1.0 / (float(d.attack_speed) * slow_factor)

func hostile(a: int, b: int) -> bool:
	return b >= 0 and a != b

func nearest_target(source: Dictionary, radius: float, sniper: bool, buildings_only := false) -> Dictionary:
	var best: Dictionary = {}
	var distance := radius
	for target in units + buildings:
		if target.hp <= 0 or not hostile(int(source.team), int(target.team)): continue
		if buildings_only and target.has("home"): continue
		if target.has("home") and target.home != -1 and not sniper: continue
		var current := point(source).distance_to(point(target))
		var detection := radius
		if source.has("kind") and catalog.has(source.kind) and catalog[source.kind].ranged and target.kind in ["hermit", "hermit_dodge", "hermit_blink"]: detection *= 0.6
		if current <= distance and current <= detection and (best.is_empty() or current < distance):
			distance = current
			best = target
	return best

func move_unit(u: Dictionary, destination: Vector2, delta: float) -> void:
	var start := Vector2i(point(u).round())
	var finish := Vector2i(destination.round()).clamp(Vector2i.ZERO, Vector2i(WIDTH - 1, HEIGHT - 1))
	if not walkable(start):
		set_point(u, safe_cell(point(u)))
		start = Vector2i(point(u))
	if not walkable(finish): return
	if u.path_revision != navigation_revision or u.path_goal != [finish.x, finish.y]:
		u.path = []
		for cell in navigation.get_id_path(start, finish): u.path.append([cell.x, cell.y])
		if not u.path.is_empty(): u.path.pop_front()
		u.path_revision = navigation_revision
		u.path_goal = [finish.x, finish.y]
	var target := destination
	if not u.path.is_empty(): target = Vector2(u.path[0][0], u.path[0][1])
	elif start != finish: return
	var speed := float(catalog[u.kind].move_speed) * (1.0 - float(u.slow) if u.slow_time > 0 else 1.0)
	set_point(u, point(u).move_toward(target, speed * delta))
	if point(u).distance_to(target) < 0.05 and not u.path.is_empty(): u.path.pop_front()

func hit(attacker: Dictionary, target: Dictionary, amount: float, ranged: bool) -> void:
	if target.hp <= 0: return
	var d: Dictionary = catalog[attacker.kind]
	if target.has("home"):
		if target.home != -1 and attacker.kind not in ["sniper", "sniper_plus"]: return
		if ranged:
			var defense: Dictionary = catalog[target.kind]
			if attacker.kind in ["archer", "ice_archer", "ice_archer_plus"] and rng.randf() < float(defense.dodge): return
			amount *= float(defense.ranged_damage_modifier)
	if rng.randf() < float(d.crit_chance): amount *= float(d.crit_multiplier)
	target.hp = maxf(0, target.hp - amount)
	shots.append({"x": attacker.x, "y": attacker.y, "tx": target.x, "ty": target.y, "ttl": 0.15, "team": attacker.team, "attacker_id": attacker.id, "ranged": ranged})
	if target.has("home") and attacker.kind in ["ice_archer", "ice_archer_plus"]:
		target.slow = 0.3 if attacker.kind == "ice_archer_plus" else 0.2
		target.slow_time = 3.0
	if target.hp <= 0:
		if target.has("home"):
			var value := float(catalog[target.kind].cost)
			credit_kill(attacker, value)
			if attacker.team == 0:
				gold += value * Rules.KILL_GOLD_RATIO
				if target.team == 2:
					baka = minf(300, baka + 15)
					credit_kill(attacker, float(d.cost) * 1.5)
		else:
			evacuate(int(target.id))
			if attacker.team == 0: gold += 80

func credit_kill(unit: Dictionary, value: float) -> void:
	unit.kill_value += value
	var threshold := float(catalog[unit.kind].cost) * 3
	while unit.rank < 2 and unit.kill_value > threshold:
		unit.kill_value -= threshold
		unit.rank += 1
		unit.max_hp *= 1.3
		unit.hp = minf(unit.max_hp, unit.hp * 1.3)
		unit.attack *= 1.3

func open_chest(chest: Dictionary, unit: Dictionary) -> void:
	if not chests.has(chest): return
	chests.erase(chest)
	gold += 180 * (1.5 if cards.has("scavenger") else 1.0)
	baka = minf(300, baka + 25)
	credit_kill(unit, float(catalog[unit.kind].cost) * 3 + 1)
	for ally in living(0): ally.hp = minf(ally.max_hp, ally.hp + ally.max_hp * 0.25)
	message = "宝箱：金币、25 BAKA、探索者战功晋升、全军恢复 25% 生命。"

func check_outcome() -> void:
	if not active(): return
	var producers := buildings.filter(func(b): return b.team == 0 and b.complete and b.hp > 0 and b.kind in ["base", "barracks"])
	if living(0).is_empty():
		var can_recover := false
		for b in producers:
			if not b.queue.is_empty() or b.kind == "base" or (gold >= 80 and used_capacity() + 2 <= capacity()): can_recover = true
		if not can_recover:
			phase = "defeat"
			message = "部队已团灭，且没有能够训练援军的基地或兵营。"
	if phase == "cleanup" and living(1).is_empty() and living(2).is_empty() and buildings.filter(func(b): return b.team == 1 and b.hp > 0).is_empty():
		phase = "victory"
		message = "战斗胜利！建筑与部队已保留，可继续下一场远征。"

func next_battle() -> bool:
	if phase != "victory": return false
	campaign += 1
	wave = 0
	timer = Rules.PREP_SECONDS
	phase = "prep"
	for u in units:
		u.order = "idle"
		u.target = -1
	# Do not duplicate neutral houses or erase the player's surviving structures.
	for pos in [Vector2(34, 5), Vector2(35, 20)]:
		var occupied := false
		for b in buildings:
			if point(b).distance_to(pos) < 2: occupied = true
		if not occupied: add_building("outpost", 1, pos)
	for pos in [Vector2(25, 4), Vector2(30, 21)]: chests.append({"id": allocate_id(), "x": pos.x, "y": pos.y})
	message = "第 %d 场远征，上一场部队与建筑保留。" % campaign
	return true

func snapshot() -> Dictionary:
	return {"mode": "rts", "rts_version": 1, "phase": phase, "gold": gold, "baka": baka,
		"tech": tech, "tier": tier, "wave": wave, "campaign": campaign, "timer": timer,
		"elapsed": elapsed, "next_id": next_id, "cards": cards.duplicate(), "units": units.duplicate(true),
		"buildings": buildings.duplicate(true), "chests": chests.duplicate(true), "walls": walls.duplicate(true),
		"bridges": bridges.duplicate(true), "rng_state": str(rng.state), "rng_seed": str(rng.seed)}

func restore(data: Dictionary) -> bool:
	if data.get("mode") != "rts" or int(data.get("rts_version", 0)) != 1: return false
	for key in ["phase", "gold", "baka", "tech", "tier", "wave", "campaign", "timer", "elapsed", "next_id", "cards", "units", "buildings", "chests", "walls", "bridges"]:
		if not data.has(key): return false
	for u in data.units:
		if not catalog.has(u.get("kind", "")): return false
	for b in data.buildings:
		if not Rules.BUILDINGS.has(b.get("kind", "")): return false
	for key in ["phase", "gold", "baka", "tech", "tier", "wave", "campaign", "timer", "elapsed", "next_id", "cards", "units", "buildings", "chests", "walls", "bridges"]:
		set(key, data[key])
	# JSON numbers are floats; grid key arrays require integer cells after loading.
	for i in bridges.size():
		bridges[i] = [int(bridges[i][0]), int(bridges[i][1])]
	rng.seed = int(data.get("rng_seed", "0"))
	rng.state = int(data.get("rng_state", "0"))
	for u in units:
		u.path = []
		u.path_revision = -1
	rebuild_navigation()
	message = "远征进度已恢复。"
	return true
