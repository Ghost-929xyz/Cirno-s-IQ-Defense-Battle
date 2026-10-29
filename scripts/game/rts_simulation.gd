extends RefCounted
## Deterministic, scene-independent RTS rules. Coordinates are logical cells.
const Rules = preload("res://scripts/data/rts_rules.gd")
const Battlefield = preload("res://scripts/data/rts_battlefield.gd")
const MapGenerator = preload("res://scripts/data/rts_map_generator.gd")
const WIDTH := Battlefield.WIDTH
const HEIGHT := Battlefield.HEIGHT
const BASE_SITES := Battlefield.BASE_SITES
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
var unlocked_units: Array = ["swordsman", "archer"]
var wave := 0
var campaign := 1
var timer := Rules.PREP_SECONDS
var elapsed := 0.0
var next_id := 1
var message := "手动选择两张效果牌，随后从地图中央的火把营地开始探索。"
var rng := RandomNumberGenerator.new()
var navigation := AStarGrid2D.new()
var navigation_revision := 0
var _painted_water: Dictionary = {}
var _use_painted_terrain := false
var _terrain_obstacles: Dictionary = {}
var snow_cover := 0.0
var water_frozen := false
var map_seed := ""
var generated_layout: Dictionary = {}
var resource_sites: Array = []
var explored_cells: Dictionary = {}
var visible_cells: Dictionary = {}
var visibility_revision := 0
var attack_alerts: Array = []
var control_groups: Dictionary = {}
const RESOURCE_NAMES := {"gold_mine": "金矿", "mana_spring": "魔力泉", "vision_tower": "灵视塔"}
const TORCH_OFFSETS := [Vector2(-4, -3), Vector2(4, -3), Vector2(-4, 3), Vector2(4, 3)]

func _init() -> void:
	rng.randomize()
	navigation.region = Rect2i(0, 0, WIDTH, HEIGHT)
	navigation.cell_size = Vector2.ONE
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	navigation.update()
	rebuild_navigation()

func point(entity: Dictionary) -> Vector2:
	return Vector2(float(entity.x), float(entity.y))

func set_point(entity: Dictionary, pos: Vector2) -> void:
	entity.x = pos.x
	entity.y = pos.y

func water(cell: Vector2i) -> bool:
	if _use_painted_terrain: return _painted_water.has(cell)
	return Battlefield.water(cell)

func configure_terrain(water_cells: Array[Vector2i], obstacle_cells: Array[Vector2i] = []) -> void:
	_painted_water.clear()
	for cell in water_cells: _painted_water[cell] = true
	_use_painted_terrain = true
	_terrain_obstacles.clear()
	for cell in obstacle_cells: _terrain_obstacles[cell] = true
	for y in range(18, 33):
		for x in range(33, 48):
			if Vector2(x, y).distance_to(Battlefield.CENTRAL_BASE) <= 7:
				_painted_water.erase(Vector2i(x, y))
				_terrain_obstacles.erase(Vector2i(x, y))
	rebuild_navigation()

func generate_map(seed_value: int) -> void:
	map_seed = str(seed_value)
	generated_layout = MapGenerator.generate(seed_value)
	configure_terrain(generated_layout.water, generated_layout.trees)

func inside(cell: Vector2i) -> bool:
	return Rect2i(0, 0, WIDTH, HEIGHT).has_point(cell)

func walkable(cell: Vector2i) -> bool:
	return inside(cell) and not navigation.is_point_solid(cell)

func rebuild_navigation() -> void:
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			var frozen := water_frozen and x >= 2 and y >= 2 and x < WIDTH - 2 and y < HEIGHT - 2
			var blocked := (water(cell) and not frozen and not bridges.has([x, y])) or _terrain_obstacles.has(cell)
			for b in buildings:
				if b.kind == "house" and b.hp > 0 and Vector2i(point(b).round()) == cell: blocked = true
			for wall in walls:
				if Vector2i(point(wall)) == cell:
					blocked = true
			navigation.set_point_solid(cell, blocked)
	navigation_revision += 1

func draw_cards() -> Array:
	# Kept for callers of older builds; choosing cards is always explicit now.
	if phase == "cards": message = "请手动选择两张效果牌。"
	return cards.duplicate()

func card_names() -> String:
	var names := PackedStringArray()
	for card in Rules.CARDS:
		if cards.has(card.id): names.append(card.name)
	return "、".join(names)

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
		choose_base(0)
	return true

func choose_base(index: int) -> bool:
	# Compatibility for old callers; a new expedition starts automatically at center.
	if active(): return false
	if phase != "base" or index < 0 or index >= BASE_SITES.size():
		return false
	var pos: Vector2 = Battlefield.CENTRAL_BASE
	add_building("base", 0, pos)
	add_unit("swordsman", 0, pos + Vector2(1, 1))
	add_unit("swordsman", 0, pos + Vector2(1, -1))
	add_unit("archer", 0, pos + Vector2(2, 0))
	populate_map()
	phase = "prep"
	populate_resources()
	update_visibility()
	message = "中央营地已建立。派部队探索，右键占领金矿、魔力泉或灵视塔。"
	return true

func populate_map() -> void:
	for pos in Battlefield.HOUSES:
		add_building("house", -1, pos)
	for pos in Battlefield.CAMPS:
		var camp := add_building("outpost", 1, pos)
		var guard := add_unit("archer", 1, pos)
		guard.home = camp.id
	for pos in Battlefield.CHESTS:
		chests.append({"id": allocate_id(), "x": pos.x, "y": pos.y})
	for pos in Battlefield.WILDLIFE:
		add_unit("swordsman", 2, pos)

func populate_resources() -> void:
	if not resource_sites.is_empty(): return
	var placement := RandomNumberGenerator.new()
	placement.seed = int(map_seed) + 72931
	for kind in ["gold_mine", "mana_spring", "vision_tower", "gold_mine", "mana_spring", "gold_mine", "vision_tower", "gold_mine", "mana_spring"]:
		for attempt in 2000:
			var pos := Vector2(placement.randi_range(5, WIDTH - 6), placement.randi_range(5, HEIGHT - 6))
			if pos.distance_to(Battlefield.CENTRAL_BASE) < 13: continue
			if resource_sites.is_empty() and pos.distance_to(Battlefield.CENTRAL_BASE) > 18: continue
			if not walkable(Vector2i(pos)) or water(Vector2i(pos)): continue
			if (buildings + chests + resource_sites).any(func(item): return point(item).distance_to(pos) < 4): continue
			if navigation.get_id_path(Vector2i(Battlefield.CENTRAL_BASE), Vector2i(pos)).is_empty(): continue
			resource_sites.append({"id": allocate_id(), "kind": kind, "x": pos.x, "y": pos.y, "team": -1, "capture": 0.0, "capturing_team": -1, "discovered": false})
			break

func cell_key(pos: Vector2) -> int:
	var cell := Vector2i(pos.round())
	return cell.y * WIDTH + cell.x if inside(cell) else -1

func is_visible(pos: Vector2) -> bool:
	return visible_cells.has(cell_key(pos))

func is_explored(pos: Vector2) -> bool:
	return explored_cells.has(cell_key(pos))

func reveal_circle(pos: Vector2, radius: float) -> void:
	for y in range(maxi(0, floori(pos.y - radius)), mini(HEIGHT, ceili(pos.y + radius) + 1)):
		for x in range(maxi(0, floori(pos.x - radius)), mini(WIDTH, ceili(pos.x + radius) + 1)):
			if Vector2(x, y).distance_squared_to(pos) <= radius * radius:
				visible_cells[y * WIDTH + x] = true

func torch_positions() -> Array:
	var result: Array = []
	for b in buildings:
		if b.team == 0 and b.kind == "base" and b.hp > 0:
			for offset in TORCH_OFFSETS: result.append(point(b) + offset)
	return result

func update_visibility() -> void:
	visible_cells.clear()
	for pos in torch_positions(): reveal_circle(pos, 6.0)
	for u in living(0):
		if u.home == -1: reveal_circle(point(u), 5.0 if u.kind != "scout" else 8.0)
	for b in buildings:
		if b.team == 0 and b.hp > 0 and b.kind != "base": reveal_circle(point(b), 4.0)
	for site in resource_sites:
		if site.team == 0: reveal_circle(point(site), 5.0)
	for key in visible_cells: explored_cells[key] = true
	for site in resource_sites:
		if is_visible(point(site)): site.discovered = true
	visibility_revision += 1

func resource_known(site: Dictionary) -> bool:
	return site.discovered or resource_sites.any(func(s): return s.kind == "vision_tower" and s.team == 0)

func step_resources(delta: float) -> void:
	for site in resource_sites:
		var claimants := units.filter(func(u): return u.hp > 0 and u.home == -1 and u.order == "capture" and u.target == site.id and point(u).distance_to(point(site)) <= 1.8)
		if not claimants.is_empty():
			var team: int = claimants[0].team
			var contested := units.any(func(u): return u.hp > 0 and u.home == -1 and hostile(team, int(u.team)) and point(u).distance_to(point(site)) < 3.5)
			if not contested:
				if site.capturing_team != team:
					site.capturing_team = team
					site.capture = 0.0
				site.capture += delta
				if site.capture >= 5.0 or site.team == team:
					site.team = team
					site.capture = 0.0
					for u in claimants: finish_order(u)
					message = "已占领%s。" % RESOURCE_NAMES[site.kind]
		else:
			site.capture = 0.0
			site.capturing_team = -1
		if site.team == 0:
			if site.kind == "gold_mine": gold += delta * 3.0
			elif site.kind == "mana_spring": baka = minf(300, baka + delta * 2.0)

func set_rally(building_id: int, pos: Vector2, append := false) -> bool:
	if not active(): return false
	var b := entity(building_id)
	if b.is_empty() or not b.has("complete") or b.team != 0 or b.kind not in ["base", "barracks"]: return false
	if not append: b.rally = []
	b.rally.append({"order": "move", "x": pos.x, "y": pos.y, "target": -1})
	message = "已设置%s集结路线（%d 个点）。" % [Rules.BUILDINGS[b.kind].name, b.rally.size()]
	return true

func start_order(u: Dictionary, order: Dictionary) -> void:
	u.order = order.order
	u.target = int(order.get("target", -1))
	u.goal_x = order.x
	u.goal_y = order.y
	u.path = []
	u.path_revision = -1

func finish_order(u: Dictionary) -> void:
	u.order = "idle"
	u.target = -1
	u.path = []
	if not u.get("orders", []).is_empty(): start_order(u, u.orders.pop_front())

func unit_in_combat(u: Dictionary) -> bool:
	return float(u.get("combat_until", 0.0)) > elapsed

func idle_units() -> Array:
	return living(0).filter(func(u): return u.home == -1 and u.order in ["idle", "stop"] and u.get("orders", []).is_empty() and not unit_in_combat(u))

func allocate_id() -> int:
	var value := next_id
	next_id += 1
	return value

func add_building(kind: String, team: int, pos: Vector2, complete := true) -> Dictionary:
	var rule: Dictionary = Rules.BUILDINGS[kind]
	var b := {"id": allocate_id(), "kind": kind, "team": team, "x": pos.x, "y": pos.y,
		"hp": float(rule.hp) if complete else 1.0, "max_hp": float(rule.hp),
		"complete": complete, "queue": [], "train": 0.0, "cooldown": 0.0, "rally": []}
	buildings.append(b)
	if kind == "house":
		rebuild_navigation()
		for u in units:
			if u.hp > 0 and u.home == -1 and not position_clear(point(u)):
				set_point(u, free_unit_position(point(u), u.kind, int(u.id)))
				u.path_revision = -1
	return b

func add_unit(kind: String, team: int, pos: Vector2) -> Dictionary:
	pos = free_unit_position(pos, kind)
	if not pos.is_finite(): return {}
	var d: Dictionary = catalog[kind]
	var hp := float(d.hp) * (1.15 if team == 0 and cards.has("vitality") else 1.0)
	var u := {"id": allocate_id(), "kind": kind, "team": team, "x": pos.x, "y": pos.y,
		"hp": hp, "max_hp": hp, "attack": float(d.attack), "rank": 0, "kill_value": 0.0,
		"spawn_x": pos.x, "spawn_y": pos.y,
		"home": -1, "order": "idle", "target": -1, "goal_x": pos.x, "goal_y": pos.y,
		"cooldown": 0.0, "special": 0.0, "frozen": 0.0, "slow_time": 0.0, "slow": 0.0,
		"raid_target": -1, "raid_clock": 0.0, "raid_revision": -1,
		"path": [], "path_revision": -1, "path_goal": [-1, -1], "orders": [], "combat_until": 0.0}
	units.append(u)
	return u

func entity(id: int) -> Dictionary:
	for item in units + buildings + chests + resource_sites:
		if int(item.id) == id:
			return item
	return {}

func living(team: int) -> Array:
	return units.filter(func(u): return int(u.team) == team and float(u.hp) > 0)

func wildlife_alive_at(pos: Vector2) -> bool:
	return units.any(func(u): return u.team == 2 and u.hp > 0 and Vector2(float(u.get("spawn_x", u.x)), float(u.get("spawn_y", u.y))).distance_to(pos) < 1)

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

func has_academy() -> bool:
	return buildings.any(func(b): return b.team == 0 and b.kind == "academy" and b.complete and b.hp > 0)

func unit_unlocked(kind: String) -> bool:
	if kind in ["cavalry", "assassin"]: return has_academy() or unlocked_units.has(kind)
	return unlocked_units.has(kind)

func branch_cost(kind: String) -> int:
	return Rules.TIER_COST if int(catalog[kind].tier) <= 2 else Rules.TECH_COST

func branch_conflict(kind: String) -> bool:
	var current := kind
	while Rules.UNIT_PARENTS.has(current):
		for group in Rules.EXCLUSIVE_BRANCHES:
			if current in group:
				for sibling in group:
					if sibling != current and unlocked_units.has(sibling): return true
		current = Rules.UNIT_PARENTS[current]
	return false

func research_error(kind: String) -> String:
	if not active(): return "战斗开始后才能研究。"
	if not Rules.UNIT_PARENTS.has(kind): return "此单位无需分支研究。"
	if not has_academy(): return "先建成科技所。"
	if unit_unlocked(kind): return "已解锁。"
	if branch_conflict(kind): return "已选择另一条互斥路线。"
	if not unit_unlocked(Rules.UNIT_PARENTS[kind]): return "先研究前置兵种。"
	if gold < branch_cost(kind): return "研究金币不足。"
	return ""

func research_unit(kind: String) -> bool:
	var error := research_error(kind)
	if not error.is_empty():
		message = error
		return false
	gold -= branch_cost(kind)
	unlocked_units.append(kind)
	tech = 2
	tier = maxi(tier, int(catalog[kind].tier))
	message = "已解锁%s，可在招募栏训练；同节点的另一条路线已关闭。" % catalog[kind].name
	return true

func train_unit(kind: String, building_id := -1) -> bool:
	if not active() or not catalog.has(kind): return false
	var d: Dictionary = catalog[kind]
	if not unit_unlocked(kind):
		message = "先建成科技所或研究对应兵种路线。"
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
	return research_unit(which)

func construction_error(kind: String, pos: Vector2, builders: Array) -> String:
	if not active() or kind not in ["barracks", "well", "house", "academy"]: return "当前无法建造。"
	var eligible: Array = []
	for id in builders:
		var u := entity(int(id))
		if not u.is_empty() and u.has("home") and u.team == 0 and u.home == -1 and u.hp > 0: eligible.append(id)
	if eligible.is_empty():
		return "先选择至少一名建筑外的己方单位。"
	var cost := float(Rules.BUILDINGS[kind].cost)
	var cell := Vector2i(pos.round())
	if gold < cost or not walkable(cell) or water(cell):
		return "需要足够金币，并在陆地空地上建造。"
	for b in buildings:
		if point(b).distance_to(Vector2(cell)) < 2.3:
			return "建筑之间需预留空间。"
	return ""

func construct(kind: String, pos: Vector2, builders: Array, append := false) -> bool:
	var error := construction_error(kind, pos, builders)
	if not error.is_empty():
		message = error
		return false
	var eligible := builders.filter(func(id):
		var u := entity(int(id))
		return not u.is_empty() and u.has("home") and u.team == 0 and u.home == -1 and u.hp > 0)
	gold -= float(Rules.BUILDINGS[kind].cost)
	var site := add_building(kind, 0, pos.round(), false)
	command(eligible, "repair", point(site), int(site.id), append)
	message = "工地已放置，单位抵达后每人每秒建造 20 点生命。"
	return true

func command(ids: Array, order: String, pos: Vector2, target := -1, append := false) -> void:
	if not active(): return
	var index := 0
	var reserved: Array = []
	for id in ids:
		var u := entity(int(id))
		if u.is_empty() or not u.has("home") or u.team != 0 or u.hp <= 0 or u.home != -1: continue
		var goal := pos
		if order in ["move", "attack_move"] and ids.size() > 1:
			var columns := ceili(sqrt(float(ids.size())))
			goal = pos + Vector2(index % columns - (columns - 1) * 0.5, index / columns) * 1.65
			index += 1
		if order in ["move", "attack_move"]:
			goal = free_unit_position(goal, u.kind, int(u.id), reserved)
			if not goal.is_finite(): continue
			reserved.append({"x": goal.x, "y": goal.y, "kind": u.kind})
		var instruction := {"order": order, "x": goal.x, "y": goal.y, "target": target}
		if append and (u.order not in ["idle", "stop"] or not u.get("orders", []).is_empty()):
			u.orders.append(instruction)
		else:
			if not append: u.orders = []
			start_order(u, instruction)

func occupants(building_id: int) -> Array:
	return units.filter(func(u): return int(u.home) == building_id and u.hp > 0)

func garrison(u: Dictionary, b: Dictionary) -> bool:
	if u.is_empty() or u.hp <= 0 or u.home != -1 or u.team not in [0, 1]: return false
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
		set_point(u, free_unit_position(point(b) + Vector2(1 + index % 3, index / 3), u.kind, int(u.id)))
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

func training_spawn_point(building: Dictionary, kind := "swordsman") -> Vector2:
	# Search reachable cells outward from the producer. Occupied cells can be
	# traversed during the search, but cannot be chosen as a spawn position.
	var origin := Vector2i(safe_cell(point(building)))
	var pending: Array[Vector2i] = [origin]
	var visited := {origin: true}
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		var pos := Vector2(cell)
		var occupied := false
		for b in buildings:
			if b.hp > 0 and point(b).distance_to(pos) < 1.5:
				occupied = true
				break
		if not occupied: occupied = not unit_position_clear(pos, kind) or units.any(func(u): return u.hp > 0 and u.home == -1 and point(u).distance_to(pos) < 1.25)
		if not occupied: return pos
		for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var neighbor: Vector2i = cell + offset
			if visited.has(neighbor) or not walkable(neighbor): continue
			visited[neighbor] = true
			pending.append(neighbor)
	return Vector2.INF

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
		var u := add_unit(kind, 1, Vector2(76, [7, 25, 40][i % 3] + (i / 3) % 3))
		u.assault_wave = wave
		if i == 1 and wave >= 2:
			assign_enemy_occupation(u)
	if wave == 3:
		var pos := enemy_build_site(Vector2(67, 28))
		if pos != Vector2(-1, -1):
			var site := add_building("outpost", 1, pos, false)
			var builder := add_unit("swordsman", 1, safe_cell(pos + Vector2(1, 0)))
			builder.order = "repair"
			builder.target = site.id
	message = "第 %d / %d 波来袭。敌军会占房与建立据点。" % [wave, Rules.WAVE_COUNT]

func assign_enemy_occupation(u: Dictionary) -> bool:
	var best: Dictionary = {}
	var distance := INF
	for b in buildings:
		if b.team != -1 or not b.complete or b.hp <= 0: continue
		# Do not send successive waves to an island they cannot reach.
		if reachable_goal(point(u), point(b)) == Vector2i(-1, -1): continue
		var current := point(u).distance_to(point(b))
		if current < distance:
			distance = current
			best = b
	if best.is_empty(): return false
	u.order = "garrison"
	u.target = best.id
	return true

func spawn_weak_raid() -> void:
	for b in buildings:
		if b.team == 1 and b.complete and b.hp > 0:
			var raider := add_unit("swordsman", 1, safe_cell(point(b) + Vector2(-1, 0)))
			raider.assault_wave = wave

func snowing() -> bool:
	return phase in ["defense", "cleanup"] and units.any(func(u):
		return u.team == 1 and u.hp > 0 and u.home == -1 and int(u.get("assault_wave", 0)) > 0)

func update_winter(delta: float) -> void:
	var snowfall := snowing()
	snow_cover = move_toward(snow_cover, 1.0 if snowfall else 0.0, delta * (0.055 if snowfall else 0.12))
	var freeze := water_frozen
	if snow_cover >= 0.6: freeze = true
	elif snow_cover <= 0.4: freeze = false
	if freeze == water_frozen: return
	water_frozen = freeze
	rebuild_navigation()
	if not water_frozen:
		for u in units:
			if u.hp <= 0 or u.home != -1 or segment_clear(point(u), point(u), Rules.terrain_radius(u.kind)): continue
			set_point(u, free_unit_position(nearest_shore(point(u)), u.kind, int(u.id)))
			u.path_revision = -1
			if u.order == "move" and not position_clear(Vector2(u.goal_x, u.goal_y)):
				var goal := safe_cell(Vector2(u.goal_x, u.goal_y))
				u.goal_x = goal.x
				u.goal_y = goal.y

func nearest_shore(pos: Vector2) -> Vector2:
	var best := Vector2.INF
	var distance := INF
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			if not walkable(cell): continue
			var current := pos.distance_squared_to(Vector2(cell))
			if current < distance:
				distance = current
				best = Vector2(cell)
	return best if best.is_finite() else safe_cell(pos)

func enemy_build_site(desired: Vector2) -> Vector2:
	for radius in 7:
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var pos := desired + Vector2(x, y)
				if not walkable(Vector2i(pos)) or water(Vector2i(pos)): continue
				if buildings.any(func(b): return b.hp > 0 and point(b).distance_to(pos) < 2.3): continue
				return pos
	return Vector2(-1, -1)

func step(delta: float) -> void:
	if not active():
		update_winter(delta)
		return
	# A surviving player building keeps the expedition active, even without troops.
	check_outcome()
	if not active():
		update_winter(delta)
		return
	elapsed += delta
	update_visibility()
	attack_alerts = attack_alerts.filter(func(alert): return float(alert.until) > elapsed)
	timer -= delta
	if timer <= 0:
		if wave < Rules.WAVE_COUNT: start_wave()
		else:
			phase = "cleanup"
			timer = Rules.WEAK_RAID_SECONDS
			spawn_weak_raid()
			message = "清剿阶段：摧毁敌方据点并消灭敌军；野怪与宝箱可按需探索。"
	var expired := false
	for wall in walls: wall.ttl -= delta
	for i in range(walls.size() - 1, -1, -1):
		if walls[i].ttl <= 0:
			walls.remove_at(i)
			expired = true
	if expired: rebuild_navigation()
	update_winter(delta)
	for s in shots: s.ttl -= delta
	shots = shots.filter(func(s): return s.ttl > 0)
	for b in buildings.duplicate():
		if not active(): break
		if b.hp > 0: step_building(b, delta)
	for u in units.duplicate():
		if not active(): break
		if u.hp > 0: step_unit(u, delta)
	if active(): step_resources(delta)
	units = units.filter(func(u): return u.hp > 0)
	buildings = buildings.filter(func(b): return b.hp > 0)
	update_visibility()
	check_outcome()

func step_building(b: Dictionary, delta: float) -> void:
	if not b.complete: return
	if b.team == 0:
		if b.kind == "well": baka = minf(300.0, baka + delta * 2.0)
		if not b.queue.is_empty():
			b.train += delta
			if b.train >= Rules.TRAIN_SECONDS:
				var spawn := training_spawn_point(b, b.queue[0])
				if spawn.is_finite():
					b.train = 0.0
					var recruit := add_unit(b.queue.pop_front(), 0, spawn)
					if not recruit.is_empty():
						for instruction in b.get("rally", []):
							command([recruit.id], instruction.order, Vector2(instruction.x, instruction.y), int(instruction.get("target", -1)), true)
				else:
					b.train = Rules.TRAIN_SECONDS
					message = "出兵区域已满，请移开建筑附近的部队。"
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
		if target.hp <= 0: target = nearest_target(b, 5.0, false)
		if target.is_empty(): break
		hit(ranged[i], target, float(ranged[i].attack), true)
	b.cooldown = 1.0 / float(catalog.archer.attack_speed)

func step_unit(u: Dictionary, delta: float) -> void:
	var d: Dictionary = catalog[u.kind]
	u.cooldown = maxf(0, u.cooldown - delta)
	u.special = maxf(0, u.special - delta)
	u.frozen = maxf(0, u.frozen - delta)
	u.slow_time = maxf(0, u.slow_time - delta)
	u.raid_clock = maxf(0, float(u.get("raid_clock", 0)) - delta)
	if u.rank == 2: u.hp = minf(u.max_hp, u.hp + u.max_hp * 0.02 * delta)
	if u.home != -1:
		if not u.get("orders", []).is_empty():
			var exit_pos := free_unit_position(point(u) + Vector2(2, 0), u.kind, int(u.id))
			if exit_pos.is_finite():
				u.home = -1
				set_point(u, exit_pos)
				finish_order(u)
		return
	if u.frozen > 0: return
	if u.kind == "paladin":
		for ally in units:
			if ally.team == u.team and ally.home == -1 and ally.hp > 0 and point(ally).distance_to(point(u)) <= 2:
				ally.hp = minf(ally.max_hp, ally.hp + 3 * delta)
	if u.order in ["repair", "garrison", "chest", "capture"]:
		var goal := entity(int(u.target))
		if goal.is_empty() or (goal.has("hp") and goal.hp <= 0):
			finish_order(u)
		elif point(u).distance_to(point(goal)) > 1.5:
			move_unit(u, point(goal), delta)
			return
		else:
			if u.order == "capture": return
			if u.order == "repair":
				if goal.team != u.team: finish_order(u)
				else:
					goal.hp = minf(goal.max_hp, goal.hp + 20 * (1.5 if u.team == 0 and cards.has("builders") else 1.0) * delta)
					if goal.hp >= goal.max_hp:
						goal.complete = true
						finish_order(u)
			elif u.order == "garrison":
				if not garrison(u, goal):
					if u.team == 1 and assign_enemy_occupation(u): return
					message = "仅剑士与弓箭手可驻军；建筑须完工且有空位。"
				if u.home == -1: finish_order(u)
			else:
				open_chest(goal, u)
				finish_order(u)
			return
	if u.order == "move":
		var destination := Vector2(u.goal_x, u.goal_y)
		if not position_clear(destination):
			var redirected := reachable_goal(point(u), destination)
			if redirected == Vector2i(-1, -1):
				finish_order(u)
				return
			destination = Vector2(redirected)
			u.goal_x = destination.x
			u.goal_y = destination.y
		if point(u).distance_to(destination) < 0.3:
			finish_order(u)
			return
		else:
			move_unit(u, destination, delta)
			return
	var sniper: bool = u.kind in ["sniper", "sniper_plus"]
	var target: Dictionary = {}
	if u.order == "attack":
		target = entity(int(u.target))
		if target.is_empty() or not target.has("hp") or target.hp <= 0 or not hostile(int(u.team), int(target.team)) or (u.team == 0 and not is_visible(point(target))) or (target.has("home") and target.home != -1 and not sniper):
			finish_order(u)
			return
		elif sniper and target.has("complete"):
			var defenders := occupants(int(target.id))
			if not defenders.is_empty(): target = defenders[0]
	var stationary: bool = u.order in ["hold", "stop"] or (u.team == 0 and u.order == "idle")
	var stationary_reach := float(d.range) if d.ranged else maxf(float(d.range), Rules.body_radius(u.kind) + 0.70 + 0.12)
	var search_radius := stationary_reach if stationary else (6.0 if u.team == 0 else (10.0 if u.team != 2 else 4.0))
	if target.is_empty(): target = nearest_target(u, search_radius, sniper)
	if target.is_empty() and u.team == 1: target = raid_target(u, sniper)
	if target.is_empty():
		if u.order == "attack_move":
			var destination := Vector2(u.goal_x, u.goal_y)
			if point(u).distance_to(destination) < 0.3: finish_order(u)
			elif reachable_goal(point(u), destination) == Vector2i(-1, -1): finish_order(u)
			else: move_unit(u, destination, delta)
		return
	u.combat_until = elapsed + 2.0
	var distance := point(u).distance_to(point(target))
	if not stationary and u.kind == "hermit_blink" and u.special <= 0 and distance > 1 and distance <= 2 and target.has("home") and target.home == -1 and walkable(Vector2i(point(target).round())):
		var landing := free_unit_position(point(target), u.kind, int(u.id))
		if landing.is_finite():
			set_point(u, landing)
			u.special = 10.0
			u.path_revision = -1
			distance = point(u).distance_to(point(target))
	if u.kind == "cataphract" and u.special <= 0 and distance <= 2:
		for foe in units:
			if hostile(int(u.team), int(foe.team)) and foe.home == -1 and point(u).distance_to(point(foe)) <= 2: foe.frozen = maxf(foe.frozen, 1.0)
		u.special = 10.0
	var reach := float(d.range) + (0.7 if target.has("complete") else 0.0)
	if target.has("home") and not d.ranged: reach = maxf(reach, Rules.body_radius(u.kind) + Rules.body_radius(target.kind) + 0.12)
	if distance > reach:
		if not stationary: move_unit(u, point(target), delta)
	elif u.cooldown <= 0:
		hit(u, target, float(u.attack), bool(d.ranged))
		var slow_factor := 1.0 - float(u.slow) if u.slow_time > 0 else 1.0
		u.cooldown = 1.0 / (float(d.attack_speed) * slow_factor)

func hostile(a: int, b: int) -> bool:
	return b >= 0 and a != b

func raid_target(source: Dictionary, sniper: bool) -> Dictionary:
	var cached := entity(int(source.get("raid_target", -1)))
	if float(source.get("raid_clock", 0)) > 0 and int(source.get("raid_revision", -1)) == navigation_revision:
		if cached.is_empty(): return {}
		if cached.team == 0 and cached.hp > 0 and (not cached.has("home") or cached.home == -1 or sniper) and raid_visible(source, cached): return cached
	var candidates := (buildings + units).filter(func(target):
		return target.team == 0 and target.hp > 0 and (not target.has("home") or target.home == -1 or sniper) and raid_visible(source, target))
	candidates.sort_custom(func(a, b): return point(source).distance_squared_to(point(a)) < point(source).distance_squared_to(point(b)))
	source.raid_clock = 2.0
	source.raid_revision = navigation_revision
	source.raid_target = -1
	for target in candidates:
		if reachable_goal(point(source), point(target)) == Vector2i(-1, -1): continue
		source.raid_target = target.id
		return target
	return {}

func raid_visible(source: Dictionary, target: Dictionary) -> bool:
	if catalog[source.kind].ranged and target.kind in ["hermit", "hermit_dodge", "hermit_blink"]:
		return point(source).distance_to(point(target)) <= 10.0 * 0.6
	return true

func nearest_target(source: Dictionary, radius: float, sniper: bool, buildings_only := false) -> Dictionary:
	var best: Dictionary = {}
	var distance := radius
	for target in units + buildings:
		if target.hp <= 0 or not hostile(int(source.team), int(target.team)): continue
		if source.team == 0 and not is_visible(point(target)): continue
		if buildings_only and target.has("home"): continue
		if target.has("home") and target.home != -1 and not sniper: continue
		var current := point(source).distance_to(point(target))
		var detection := radius
		var ranged_source: bool = source.has("complete") or (source.has("kind") and catalog.has(source.kind) and catalog[source.kind].ranged)
		if ranged_source and target.kind in ["hermit", "hermit_dodge", "hermit_blink"]: detection *= 0.6
		if current <= distance and current <= detection and (best.is_empty() or current < distance):
			distance = current
			best = target
	return best

func reachable_goal(source: Vector2, destination: Vector2) -> Vector2i:
	var start := Vector2i(source.round())
	var finish := Vector2i(destination.round())
	if not walkable(start): start = Vector2i(safe_cell(source))
	if walkable(finish):
		return finish if not navigation.get_id_path(start, finish).is_empty() else Vector2i(-1, -1)
	# Building interactions end at a reachable entrance instead of routing into
	# the house itself. Try every adjacent entrance before declaring it isolated.
	var entrances: Array[Vector2i] = []
	for y in range(-1, 2):
		for x in range(-1, 2):
			var cell := finish + Vector2i(x, y)
			if walkable(cell): entrances.append(cell)
	entrances.sort_custom(func(a, b): return source.distance_squared_to(Vector2(a)) < source.distance_squared_to(Vector2(b)))
	for cell in entrances:
		if not navigation.get_id_path(start, cell).is_empty(): return cell
	return Vector2i(-1, -1)

func segment_hits_cell(start: Vector2, finish: Vector2, cell: Vector2i, radius := 0.16) -> bool:
	# Slab intersection against the cell enlarged by the unit's body radius.
	var low := Vector2(cell) - Vector2.ONE * (0.5 + radius)
	var high := Vector2(cell) + Vector2.ONE * (0.5 + radius)
	var direction := finish - start
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if absf(direction[axis]) < 0.00001:
			if start[axis] < low[axis] or start[axis] > high[axis]: return false
		else:
			var a: float = (low[axis] - start[axis]) / direction[axis]
			var b: float = (high[axis] - start[axis]) / direction[axis]
			enter = maxf(enter, minf(a, b))
			leave = minf(leave, maxf(a, b))
			if enter > leave: return false
	return true

func segment_clear(start: Vector2, finish: Vector2, radius := 0.16) -> bool:
	var samples := maxi(1, ceili(start.distance_to(finish) * 2.0))
	var checked := {}
	for i in samples + 1:
		var center := Vector2i(start.lerp(finish, float(i) / samples).round())
		for y in range(-1, 2):
			for x in range(-1, 2):
				var cell := center + Vector2i(x, y)
				if checked.has(cell): continue
				checked[cell] = true
				if not walkable(cell) and segment_hits_cell(start, finish, cell, radius): return false
	return true

func position_clear(pos: Vector2) -> bool:
	return segment_clear(pos, pos)

func unit_position_clear(pos: Vector2, kind: String, except_id := -1, reserved: Array = []) -> bool:
	if not pos.is_finite() or not segment_clear(pos, pos, Rules.terrain_radius(kind)): return false
	for other in units:
		if other.hp <= 0 or other.home != -1 or int(other.id) == except_id: continue
		if Vector2i(pos.round()) == Vector2i(point(other).round()): return false
		if pos.distance_squared_to(point(other)) < pow(Rules.body_radius(kind) + Rules.body_radius(other.kind), 2) - 0.00001: return false
	for other in reserved:
		if Vector2i(pos.round()) == Vector2i(point(other).round()): return false
		if pos.distance_to(point(other)) < Rules.body_radius(kind) + Rules.body_radius(other.kind): return false
	return true

func free_unit_position(pos: Vector2, kind: String, except_id := -1, reserved: Array = []) -> Vector2:
	if unit_position_clear(pos, kind, except_id, reserved): return pos
	var origin := Vector2i(safe_cell(pos))
	var pending: Array[Vector2i] = [origin]
	var visited := {origin: true}
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		if unit_position_clear(Vector2(cell), kind, except_id, reserved): return Vector2(cell)
		for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var neighbor: Vector2i = cell + offset
			if visited.has(neighbor) or not walkable(neighbor): continue
			visited[neighbor] = true
			pending.append(neighbor)
	return Vector2.INF

func unit_motion_clear(u: Dictionary, destination: Vector2) -> bool:
	var origin := point(u)
	if not segment_clear(origin, destination, Rules.terrain_radius(u.kind)): return false
	if not unit_position_clear(destination, u.kind, int(u.id)): return false
	# Swept bodies prevent crossing through another unit during a large step.
	var motion := destination - origin
	for other in units:
		if other.hp <= 0 or other.home != -1 or other.id == u.id: continue
		var t := clampf((point(other) - origin).dot(motion) / maxf(motion.length_squared(), 0.00001), 0, 1)
		if (origin + motion * t).distance_to(point(other)) < Rules.body_radius(u.kind) + Rules.body_radius(other.kind) - 0.00001: return false
	return true

func replan_around_units(u: Dictionary, destination: Vector2) -> void:
	var start := Vector2i(point(u).round())
	var marked: Array[Vector2i] = []
	# Temporarily reserve other bodies in the existing grid. Restore the grid
	# before returning so another unit's path never inherits these reservations.
	for other in units:
		if other.hp <= 0 or other.home != -1 or other.id == u.id: continue
		var center := Vector2i(point(other).round())
		var clearance := Rules.body_radius(u.kind) + Rules.body_radius(other.kind)
		for y in range(-2, 3):
			for x in range(-2, 3):
				var cell := center + Vector2i(x, y)
				if cell == start or not walkable(cell): continue
				if cell == center or Vector2(cell).distance_to(point(other)) < clearance:
					navigation.set_point_solid(cell, true)
					marked.append(cell)
	var finish := Vector2i(destination.round())
	var route: Array[Vector2i] = []
	if walkable(finish): route = navigation.get_id_path(start, finish)
	if route.is_empty():
		var candidates: Array[Vector2i] = []
		for y in range(-2, 3):
			for x in range(-2, 3):
				var cell := Vector2i(destination.round()) + Vector2i(x, y)
				if cell != start and walkable(cell): candidates.append(cell)
		candidates.sort_custom(func(a, b):
			var da := Vector2(a).distance_squared_to(destination)
			var db := Vector2(b).distance_squared_to(destination)
			return point(u).distance_squared_to(Vector2(a)) < point(u).distance_squared_to(Vector2(b)) if is_equal_approx(da, db) else da < db)
		for cell in candidates:
			route = navigation.get_id_path(start, cell)
			if not route.is_empty():
				finish = cell
				break
	for cell in marked: navigation.set_point_solid(cell, false)
	if route.size() < 2: return
	u.path = []
	for i in range(1, route.size()): u.path.append([route[i].x, route[i].y])
	if finish == Vector2i(destination.round()) and segment_clear(Vector2(finish), destination, Rules.terrain_radius(u.kind)):
		u.path.append([destination.x, destination.y])

func move_unit(u: Dictionary, destination: Vector2, delta: float) -> void:
	var terrain_radius := Rules.terrain_radius(u.kind)
	var start := Vector2i(point(u).round())
	if not segment_clear(point(u), point(u), terrain_radius):
		var free := free_unit_position(point(u), u.kind, int(u.id))
		if not free.is_finite(): return
		set_point(u, free)
		start = Vector2i(point(u))
	var requested := Vector2i(destination.round())
	if u.path_revision != navigation_revision or u.path_goal != [requested.x, requested.y] or u.path.is_empty():
		u.path = []
		if segment_clear(point(u), destination, terrain_radius):
			u.path.append([destination.x, destination.y])
		else:
			var finish := reachable_goal(point(u), destination)
			if finish == Vector2i(-1, -1): return
			var endpoint := destination if segment_clear(destination, destination, terrain_radius) else Vector2(finish)
			var route := navigation.get_id_path(start, finish)
			var anchor := point(u)
			var index := 1
			while index < route.size():
				var furthest := index
				for next in range(index, route.size()):
					if not segment_clear(anchor, Vector2(route[next]), terrain_radius): break
					furthest = next
				anchor = Vector2(route[furthest])
				u.path.append([anchor.x, anchor.y])
				index = furthest + 1
			if not u.path.is_empty() and segment_clear(anchor, endpoint, terrain_radius): u.path.append([endpoint.x, endpoint.y])
		u.path_revision = navigation_revision
		u.path_goal = [requested.x, requested.y]
	if u.path.is_empty(): return
	# Sliding can keep a unit moving without bringing it closer to its goal.
	# Detect that case as well as a completely blocked step and route outside
	# the settled formation instead of oscillating between two neighbours.
	var goal_distance := point(u).distance_to(destination)
	if u.get("progress_goal", []) != [requested.x, requested.y]:
		u["progress_goal"] = [requested.x, requested.y]
		u["progress_clock"] = 0.0
		u["progress_distance"] = goal_distance
	u["progress_clock"] = float(u.get("progress_clock", 0)) + delta
	if u.progress_clock >= 1.0:
		if goal_distance > 0.3 and goal_distance > float(u.progress_distance) - 0.2: replan_around_units(u, destination)
		u.progress_clock = 0.0
		u.progress_distance = goal_distance
	var target := Vector2(u.path[0][0], u.path[0][1])
	var speed := float(catalog[u.kind].move_speed) * (1.0 - float(u.slow) if u.slow_time > 0 else 1.0)
	var next_position := point(u).move_toward(target, speed * delta)
	if not unit_motion_clear(u, next_position):
		u["blocked_time"] = float(u.get("blocked_time", 0)) + delta
		if u.blocked_time >= 0.5:
			replan_around_units(u, destination)
			u.blocked_time = 0.0
			return
		# Slide around bodies without changing the terrain path or crossing walls.
		var direction := (target - point(u)).normalized()
		var moved := false
		for angle in [PI / 4, -PI / 4, PI / 2, -PI / 2]:
			var candidate := point(u) + direction.rotated(angle) * minf(speed * delta, point(u).distance_to(target))
			if unit_motion_clear(u, candidate):
				next_position = candidate
				moved = true
				break
		if not moved: return
	else: u["blocked_time"] = 0.0
	set_point(u, next_position)
	if point(u).distance_to(target) < 0.05 and not u.path.is_empty(): u.path.pop_front()

func hit(attacker: Dictionary, target: Dictionary, amount: float, ranged: bool) -> void:
	if attacker.hp <= 0 or target.hp <= 0 or not hostile(int(attacker.team), int(target.team)): return
	var d: Dictionary = catalog[attacker.kind]
	if target.has("home"):
		if target.home != -1 and attacker.kind not in ["sniper", "sniper_plus"]: return
		if ranged:
			var defense: Dictionary = catalog[target.kind]
			if attacker.kind in ["archer", "ice_archer", "ice_archer_plus"] and rng.randf() < float(defense.dodge): return
			amount *= float(defense.ranged_damage_modifier)
	if rng.randf() < float(d.crit_chance): amount *= float(d.crit_multiplier)
	target.hp = maxf(0, target.hp - amount)
	attacker.combat_until = elapsed + 3.0
	target.combat_until = elapsed + 3.0
	if target.team == 0:
		var nearby := attack_alerts.filter(func(alert): return point(alert).distance_to(point(target)) < 5)
		if nearby.is_empty(): attack_alerts.append({"x": target.x, "y": target.y, "until": elapsed + 6.0})
		else: nearby[0].until = elapsed + 6.0
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
					baka = minf(300, baka + Rules.WILDLIFE_BAKA)
					attacker.hp = minf(attacker.max_hp, attacker.hp + attacker.max_hp * Rules.WILDLIFE_HEAL_RATIO)
					message = "野怪奖励：金币、15 BAKA、等价经验，击杀者恢复 25% 生命。"
		else:
			evacuate(int(target.id))
			if target.kind == "house": rebuild_navigation()
			if attacker.team == 0: gold += 80
		if target.team == 0: check_outcome()

func credit_kill(unit: Dictionary, value: float) -> void:
	unit.kill_value += value
	var cost := float(catalog[unit.kind].cost)
	if unit.rank == 0 and unit.kill_value > cost * 3:
		unit.rank = 1
		unit.attack *= 1.2
	if unit.rank == 1 and unit.kill_value > cost * 6:
		unit.rank = 2
		unit.max_hp *= 1.2

func open_chest(chest: Dictionary, unit: Dictionary) -> void:
	if not chests.has(chest) or unit.team != 0 or unit.hp <= 0 or unit.home != -1: return
	chests.erase(chest)
	gold += 180 * (1.5 if cards.has("scavenger") else 1.0)
	baka = minf(300, baka + 25)
	credit_kill(unit, float(catalog[unit.kind].cost) * 3 + 1)
	for ally in living(0): ally.hp = minf(ally.max_hp, ally.hp + ally.max_hp * 0.25)
	message = "宝箱：金币、25 BAKA、探索者战功晋升、全军恢复 25% 生命。"

func check_outcome() -> void:
	if not active(): return
	if not buildings.any(func(b): return b.team == 0 and b.hp > 0):
		phase = "defeat"
		message = "己方基地及所有建筑均已被摧毁，远征失败。"
		return
	if phase == "cleanup" and living(1).is_empty() and buildings.filter(func(b): return b.team == 1 and b.hp > 0).is_empty():
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
		u.orders = []
		u.target = -1
		u.path = []
		u.path_revision = -1
	# Do not duplicate neutral houses or erase the player's surviving structures.
	for pos in Battlefield.CAMPS:
		var occupied := false
		for b in buildings:
			if point(b).distance_to(pos) < 2: occupied = true
		if not occupied: add_building("outpost", 1, pos)
	for pos in Battlefield.CHESTS:
		if not chests.any(func(c): return point(c).distance_to(pos) < 1):
			chests.append({"id": allocate_id(), "x": pos.x, "y": pos.y})
	for pos in Battlefield.WILDLIFE:
		if not wildlife_alive_at(pos):
			add_unit("swordsman", 2, pos)
	message = "第 %d 场远征，上一场部队与建筑保留。" % campaign
	return true

func snapshot() -> Dictionary:
	return {"mode": "rts", "rts_version": 1, "map_version": Battlefield.VERSION, "phase": phase, "gold": gold, "baka": baka,
		"tech": tech, "tier": tier, "unlocked_units": unlocked_units.duplicate(), "feedback_version": 1, "wave": wave, "campaign": campaign, "timer": timer,
		"elapsed": elapsed, "next_id": next_id, "cards": cards.duplicate(), "units": units.duplicate(true),
		"buildings": buildings.duplicate(true), "chests": chests.duplicate(true), "walls": walls.duplicate(true),
		"bridges": bridges.duplicate(true), "snow_cover": snow_cover, "water_frozen": water_frozen,
		"map_seed": map_seed, "map_generator_version": 2, "exploration_version": 1,
		"resource_sites": resource_sites.duplicate(true), "explored_cells": explored_cells.keys(), "control_groups": control_groups.duplicate(true),
		"rng_state": str(rng.state), "rng_seed": str(rng.seed)}

func restore(data: Dictionary) -> bool:
	if data.get("mode") != "rts" or int(data.get("rts_version", 0)) != 1: return false
	var saved_seed := str(data.get("map_seed", ""))
	if not saved_seed.is_empty():
		if not saved_seed.is_valid_int() or int(saved_seed) < 0 or int(saved_seed) > 2147483647: return false
		if int(data.get("map_generator_version", 1)) not in [1, 2]: return false
	for key in ["phase", "gold", "baka", "tech", "tier", "wave", "campaign", "timer", "elapsed", "next_id", "cards", "units", "buildings", "chests", "walls", "bridges"]:
		if not data.has(key): return false
	for u in data.units:
		if not catalog.has(u.get("kind", "")): return false
	for b in data.buildings:
		if not Rules.BUILDINGS.has(b.get("kind", "")): return false
	if not saved_seed.is_empty():
		generate_map(int(saved_seed))
	elif not map_seed.is_empty():
		map_seed = ""
		generated_layout.clear()
		_painted_water.clear()
		_terrain_obstacles.clear()
		_use_painted_terrain = false
	for key in ["phase", "gold", "baka", "tech", "tier", "wave", "campaign", "timer", "elapsed", "next_id", "cards", "units", "buildings", "chests", "walls", "bridges"]:
		set(key, data[key].duplicate(true) if data[key] is Array or data[key] is Dictionary else data[key])
	unlocked_units = ["swordsman", "archer"]
	if data.has("unlocked_units"):
		for kind in data.unlocked_units:
			if catalog.has(kind) and not unlocked_units.has(kind): unlocked_units.append(kind)
	else:
		# Keep legacy recruitment progress; new games use individual branches.
		for kind in catalog:
			if kind not in ["swordsman", "archer"] and int(catalog[kind].tech) <= tech and int(catalog[kind].tier) <= tier: unlocked_units.append(kind)
	# JSON numbers are floats; grid key arrays require integer cells after loading.
	for i in bridges.size():
		bridges[i] = [int(bridges[i][0]), int(bridges[i][1])]
	rng.seed = int(data.get("rng_seed", "0"))
	rng.state = int(data.get("rng_state", "0"))
	snow_cover = clampf(float(data.get("snow_cover", 0.0)), 0.0, 1.0)
	water_frozen = bool(data.get("water_frozen", false)) and snow_cover > 0.4
	for u in units:
		if not u.has("orders"): u.orders = []
		if not u.has("combat_until"): u.combat_until = 0.0
		if int(data.get("feedback_version", 0)) < 1:
			var ratio := float(u.hp) / maxf(1, float(u.max_hp))
			u.kill_value += int(u.rank) * float(catalog[u.kind].cost) * 3
			u.max_hp = float(catalog[u.kind].hp) * (1.15 if u.team == 0 and cards.has("vitality") else 1.0) * (1.2 if u.rank == 2 else 1.0)
			u.hp = ratio * u.max_hp
			u.attack = float(catalog[u.kind].attack) * (1.2 if u.rank >= 1 else 1.0)
		if not u.has("assault_wave"): u.assault_wave = wave if u.team == 1 and u.home == -1 else 0
		u.path = []
		u.path_revision = -1
		u.raid_clock = 0.0
		u.raid_revision = -1
	rebuild_navigation()
	if int(data.get("map_version", 1)) < Battlefield.VERSION:
		migrate_legacy_map()
		message = "旧版远征已迁移至扩展地图，部队与资源已保留。"
	else:
		message = "远征进度已恢复。"
	for u in units:
		if u.hp > 0 and u.home == -1 and not unit_position_clear(point(u), u.kind, int(u.id)):
			var free := free_unit_position(point(u), u.kind, int(u.id))
			if free.is_finite(): set_point(u, free)
	for u in living(2):
		if u.has("spawn_x") and u.has("spawn_y"): continue
		var nearest: Vector2 = Battlefield.WILDLIFE[0]
		for pos in Battlefield.WILDLIFE:
			if point(u).distance_squared_to(pos) < point(u).distance_squared_to(nearest): nearest = pos
		u.spawn_x = nearest.x
		u.spawn_y = nearest.y
	# Older expedition saves may contain stacked copies of uncollected chests.
	var seen_chests := {}
	chests = chests.filter(func(chest):
		var cell := Vector2i(point(chest).round())
		if seen_chests.has(cell): return false
		seen_chests[cell] = true
		return true)
	resource_sites = data.get("resource_sites", []).duplicate(true)
	if phase not in ["cards", "base"]: populate_resources()
	explored_cells.clear()
	for key in data.get("explored_cells", []): explored_cells[int(key)] = true
	control_groups.clear()
	for key in data.get("control_groups", {}): control_groups[int(key)] = data.control_groups[key].duplicate()
	for b in buildings:
		if not b.has("rally"): b.rally = []
	if phase == "base": choose_base(0)
	update_visibility()
	return true

func migrate_legacy_map() -> void:
	# Expand old 40x25 positions once; preserve IDs, queues, rewards and economy.
	var old_bridges := bridges.duplicate(true)
	bridges.clear()
	walls.clear()
	for cell in old_bridges:
		for dy in 2:
			for dx in 2:
				var at := Vector2i(int(cell[0]) * 2 + dx, int(cell[1]) * 2 + dy)
				if inside(at) and water(at) and not bridges.has([at.x, at.y]): bridges.append([at.x, at.y])
	rebuild_navigation()
	for item in buildings + chests + units:
		set_point(item, safe_cell(point(item) * 2.0))
	for u in units:
		var goal := safe_cell(Vector2(float(u.goal_x), float(u.goal_y)) * 2.0)
		u.goal_x = goal.x
		u.goal_y = goal.y
		if u.home != -1:
			var home := entity(int(u.home))
			if not home.is_empty(): set_point(u, point(home))
		u.path = []
		u.path_revision = -1
