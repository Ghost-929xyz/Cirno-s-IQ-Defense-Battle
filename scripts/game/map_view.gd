class_name LakeMapView
extends Node2D

## 地图视图：可从像素画 PNG 读取地图，也可用内置默认地图。
## 像素画规则：1 像素 = 1 格；颜色含义见下方 COLOR_* 与 assets/maps/README_绘制说明.md。
## 若 assets/maps/map.png 存在且合法，则优先使用它；否则回退到内置默认地图。

## 像素画文件路径（相对 res://）。改成你自己的图后，启动游戏即自动生效。
const MAP_IMAGE_PATH := "res://assets/maps/map.png"
const COLOR_PATH := Color("#0a0f14")    # 深色 = 路径（敌人行走，不可建造）
const COLOR_CORE := Color("#ffe26b")    # 黄色 = IQ 结晶（只能有 1 格）
const COLOR_SPAWN := Color("#7ef0a4")   # 绿色 = 琪露诺出生点
const COLOR_LAND := Color("#4a5d68")    # 模板用灰色 = 空地（可建造；其它任意颜色也可以）
const COLOR_TOLERANCE := 0.18           # 颜色容差，避免画图软件轻微变色后读不到

## 内置默认地图参数（仅在读不到像素画时使用）
const DEFAULT_COLS := 20
const DEFAULT_ROWS := 15
const CELL_SIZE := 30.0
const DEFAULT_CORE_CELL := Vector2i(10, 7)
const DEFAULT_HERO_SPAWN_CELL := Vector2i(1, 12)
const DEFAULT_ENTRANCE := "west"
const ENTRANCE_LABELS := {
	"west": "西",
	"north": "北",
	"south": "南",
	"east": "东",
}
## 路宽约 2 格（1 格半宽），保证空地留有充足的建造区域。
const PATH_HALF_WIDTH := 0.9
const PATH_SEGMENT_CELLS := 1.0

## 内置默认地图：各入口的路径关键点（格坐标），经 Catmull-Rom 平滑成弯曲曲线。
const DEFAULT_PATHS := {
	"west": [
		Vector2i(0, 7), Vector2i(3, 7), Vector2i(3, 4), Vector2i(6, 4),
		Vector2i(6, 7), Vector2i(10, 7),
	],
	"north": [
		Vector2i(10, 0), Vector2i(10, 3), Vector2i(8, 3), Vector2i(8, 5),
		Vector2i(10, 7),
	],
	"south": [
		Vector2i(3, 14), Vector2i(3, 11), Vector2i(6, 11), Vector2i(6, 8),
		Vector2i(10, 7),
	],
	"east": [
		Vector2i(19, 7), Vector2i(16, 7), Vector2i(16, 4), Vector2i(13, 4),
		Vector2i(13, 7), Vector2i(10, 7),
	],
}

## 运行时参数（像素画可能改变棋盘尺寸/核心/出生点）
var COLS := DEFAULT_COLS
var ROWS := DEFAULT_ROWS
var BOARD_SIZE := Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)
var CORE_CELL := DEFAULT_CORE_CELL
var HERO_SPAWN_CELL := DEFAULT_HERO_SPAWN_CELL
var PATHS: Dictionary = {}

var hover_cell := Vector2i(-99, -99)
var selected_tower_id := "icicle"
var _path_cells: Dictionary = {}
var _path_local_points: Dictionary = {}
var _path_world_points: Dictionary = {}
var _selection_rect := Rect2()
var _has_selection := false


func _ready() -> void:
	if not _load_map_from_image():
		_setup_default_map()
	_build_paths()
	queue_redraw()


## 优先读取像素画地图。成功返回 true。
func _load_map_from_image() -> bool:
	if not FileAccess.file_exists(MAP_IMAGE_PATH):
		return false
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(MAP_IMAGE_PATH)) != OK:
		push_warning("地图像素画读取失败: %s" % MAP_IMAGE_PATH)
		return false
	COLS = img.get_width()
	ROWS = img.get_height()
	if COLS < 4 or ROWS < 4:
		push_warning("地图像素画尺寸过小（至少 4x4 格）")
		return false
	BOARD_SIZE = Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)
	var path_cells: Dictionary = {}
	var core := Vector2i(-1, -1)
	var spawn := Vector2i(-1, -1)
	for y in range(ROWS):
		for x in range(COLS):
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue  # 透明 = 空地
			var cell := Vector2i(x, y)
			if _color_close(c, COLOR_CORE):
				core = cell
			elif _color_close(c, COLOR_SPAWN):
				spawn = cell
			elif _color_close(c, COLOR_PATH):
				path_cells[cell] = true
	if core.x < 0:
		push_warning("地图像素画里没有核心色（黄），回退到默认地图")
		return false
	CORE_CELL = core
	HERO_SPAWN_CELL = spawn if spawn.x >= 0 else DEFAULT_HERO_SPAWN_CELL
	_path_cells = path_cells
	PATHS = _derive_paths_from_cells()
	if PATHS.is_empty():
		push_warning("地图像素画里没有能从边界通向核心的路径，回退到默认地图")
		return false
	return true


func _setup_default_map() -> void:
	COLS = DEFAULT_COLS
	ROWS = DEFAULT_ROWS
	BOARD_SIZE = Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)
	CORE_CELL = DEFAULT_CORE_CELL
	HERO_SPAWN_CELL = DEFAULT_HERO_SPAWN_CELL
	PATHS = DEFAULT_PATHS.duplicate(true)


## 从像素画路格自动推导：入口（边界路格）→ 核心 的路径。
func _derive_paths_from_cells() -> Dictionary:
	# BFS：从核心出发，沿四连通的路径格扩展，记录每个格的前驱
	var prev := {CORE_CELL: Vector2i(-1, -1)}
	var queue: Array[Vector2i] = [CORE_CELL]
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var cur: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var nb: Vector2i = cur + d
			if _path_cells.has(nb) and not prev.has(nb):
				prev[nb] = cur
				queue.append(nb)
	# 边界上可达的路格 = 入口候选
	var border: Array[Vector2i] = []
	for cell in _path_cells:
		if prev.has(cell) and _is_border_cell(cell):
			border.append(cell)
	# 按边分组、排序、合并相邻格，得到各入口
	var by_side := {"west": [], "north": [], "south": [], "east": []}
	for cell in border:
		by_side[_side_of(cell)].append(cell)
	var result: Dictionary = {}
	for side in by_side:
		var cells: Array = by_side[side]
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return _border_order(a, b, side as String))
		var runs: Array[Array] = []
		for cell in cells:
			if runs.is_empty():
				runs.append([cell])
			else:
				var last_run: Array = runs[runs.size() - 1]
				if _border_adjacent(last_run[last_run.size() - 1], cell):
					last_run.append(cell)
				else:
					runs.append([cell])
		var extra := 0
		for run in runs:
			# 取该段离核心最远的边界格作为入口
			var entrance_cell: Vector2i = run[0]
			var best_dist := -1.0
			for cell in run:
				var dist: float = (cell - CORE_CELL).length()
				if dist > best_dist:
					best_dist = dist
					entrance_cell = cell
			var entrance_id: String = side
			while result.has(entrance_id):
				extra += 1
				entrance_id = side + str(extra)
			result[entrance_id] = _route_cells(prev, entrance_cell)
	return result


func _route_cells(prev: Dictionary, entrance_cell: Vector2i) -> Array:
	var route: Array = []
	var cur := entrance_cell
	while cur.x >= 0:
		route.append(cur)
		cur = prev[cur]
	return route


func _is_border_cell(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == COLS - 1 or cell.y == ROWS - 1


func _side_of(cell: Vector2i) -> String:
	if cell.x == 0:
		return "west"
	if cell.x == COLS - 1:
		return "east"
	if cell.y == 0:
		return "north"
	return "south"


func _border_order(a: Vector2i, b: Vector2i, side: String) -> bool:
	if side == "north" or side == "south":
		return a.x < b.x
	return a.y < b.y


func _border_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _color_close(a: Color, b: Color, tolerance: float = COLOR_TOLERANCE) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


func _build_paths() -> void:
	_path_cells.clear()
	for entrance_id in PATHS:
		var waypoints := _to_float_points(PATHS[entrance_id])
		var dense := _sample_catmull_rom(waypoints, 2.0)
		_rasterize_path(dense)
		# 敌人移动点：沿曲线每 PATH_SEGMENT_CELLS 格取一个点
		var movement := PackedVector2Array()
		var last_local := Vector2(-1.0e9, -1.0e9)
		for sample in dense:
			if last_local.x < -1.0e8 or sample.distance_to(last_local) >= PATH_SEGMENT_CELLS * CELL_SIZE:
				movement.append(sample)
				last_local = sample
		if movement.size() < 2:
			movement = dense.duplicate()
		_path_local_points[entrance_id] = movement
		var world := PackedVector2Array()
		for point in movement:
			world.append(to_global(point))
		_path_world_points[entrance_id] = world


## 路径关键点从格坐标换算为本地像素坐标（格中心），供样条/绘制/移动使用。
func _to_float_points(cells: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for cell in cells:
		result.append(cell_to_local(Vector2i(cell)))
	return result


## Catmull-Rom 样条采样，samples_per_cell 控制每个关键点区间的采样密度。
func _sample_catmull_rom(points: Array[Vector2], samples_per_cell: float = 2.0) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n := points.size()
	if n < 2:
		for p in points:
			result.append(p)
		return result
	for i in range(n - 1):
		var p0 := points[maxi(0, i - 1)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(n - 1, i + 2)]
		var segment_length := p1.distance_to(p2)
		var steps := maxi(1, int(ceil(segment_length * samples_per_cell)))
		for s in range(steps):
			var t := float(s) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			var q := 0.5 * (
				(2.0 * p1)
				+ (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			result.append(q)
	result.append(points[n - 1])
	return result


## 把像素采样点落格，标记为不可建造的路径格。
func _rasterize_path(samples: PackedVector2Array) -> void:
	var radius := int(ceil(PATH_HALF_WIDTH))
	for sample in samples:
		var center := Vector2i(int(floor(sample.x / CELL_SIZE)), int(floor(sample.y / CELL_SIZE)))
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if float(dx * dx + dy * dy) <= PATH_HALF_WIDTH * PATH_HALF_WIDTH:
					var cell := center + Vector2i(dx, dy)
					if is_inside(cell):
						_path_cells[cell] = true


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


func is_path_cell(cell: Vector2i) -> bool:
	return _path_cells.has(cell)


func is_core_cell(cell: Vector2i) -> bool:
	return cell == CORE_CELL


func is_entrance_cell(cell: Vector2i) -> bool:
	for entrance_id in PATHS:
		var nodes: Array = PATHS[entrance_id]
		if nodes.size() > 0 and cell == nodes[0]:
			return true
	return false


func is_buildable(cell: Vector2i) -> bool:
	return is_inside(cell) and not is_path_cell(cell) and not is_core_cell(cell) and not is_entrance_cell(cell)


func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := to_local(world_position)
	return Vector2i(int(floor(local_position.x / CELL_SIZE)), int(floor(local_position.y / CELL_SIZE)))


func has_entrance(entrance_id: String) -> bool:
	return PATHS.has(entrance_id)


## 返回第一个可用入口 id（读像素画时入口可能不叫 west）。
func get_first_entrance() -> String:
	for entrance_id in PATHS:
		return entrance_id
	return DEFAULT_ENTRANCE


func get_path_points(entrance_id: String = "") -> PackedVector2Array:
	if entrance_id.is_empty() or not _path_world_points.has(entrance_id):
		entrance_id = get_first_entrance()
	return _path_world_points.get(entrance_id, PackedVector2Array()).duplicate()


func get_core_world_position() -> Vector2:
	return to_global(cell_to_local(CORE_CELL))


func get_hero_spawn_world_position() -> Vector2:
	return to_global(cell_to_local(HERO_SPAWN_CELL))


func get_play_rect() -> Rect2:
	return Rect2(position, BOARD_SIZE)


func get_board_rect_local() -> Rect2:
	return Rect2(Vector2.ZERO, BOARD_SIZE)


func get_closest_path_world_position(origin: Vector2) -> Vector2:
	var closest := origin
	var closest_distance := INF
	for entrance_id in _path_world_points:
		var points := _path_world_points[entrance_id] as PackedVector2Array
		for index in range(points.size() - 1):
			var segment_start := points[index]
			var segment_end := points[index + 1]
			var segment := segment_end - segment_start
			var segment_length_squared := segment.length_squared()
			var candidate := segment_start
			if segment_length_squared > 0.0001:
				var t := clampf((origin - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
				candidate = segment_start + segment * t
			var candidate_distance := origin.distance_squared_to(candidate)
			if candidate_distance < closest_distance:
				closest = candidate
				closest_distance = candidate_distance
	return closest


func set_hover_cell(cell: Vector2i) -> void:
	if hover_cell == cell:
		return
	hover_cell = cell
	queue_redraw()


func set_selected_tower_id(tower_id: String) -> void:
	selected_tower_id = tower_id
	queue_redraw()


func set_selection_rect(world_rect: Rect2) -> void:
	if world_rect.size.length() < 1.0:
		_has_selection = false
	else:
		_has_selection = true
		_selection_rect = to_local_rect(world_rect)
	queue_redraw()


func clear_selection_rect() -> void:
	_has_selection = false
	queue_redraw()


func to_local_rect(world_rect: Rect2) -> Rect2:
	return Rect2(to_local(world_rect.position), world_rect.size)


func distance_in_cells(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b) / CELL_SIZE


func _draw() -> void:
	# 外框与空地底色（空地保持简洁素色，不装饰）
	draw_rect(Rect2(Vector2(-6.0, -6.0), BOARD_SIZE + Vector2(12.0, 12.0)), Color("#050d18"))
	draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color("#17313a"))

	# 细网格线（提升像素密度感）
	var grid_color := Color(0.55, 0.82, 0.95, 0.06)
	for x in range(COLS + 1):
		var px := x * CELL_SIZE
		draw_line(Vector2(px, 0.0), Vector2(px, BOARD_SIZE.y), grid_color, 1.0)
	for y in range(ROWS + 1):
		var py := y * CELL_SIZE
		draw_line(Vector2(0.0, py), Vector2(BOARD_SIZE.x, py), grid_color, 1.0)

	# 深色弯曲路径：深色宽底 + 较亮内线，与空地形成对比
	for entrance_id in _path_local_points:
		var points := _path_local_points[entrance_id] as PackedVector2Array
		draw_polyline(points, Color("#0a131d"), PATH_HALF_WIDTH * 2.0 * CELL_SIZE, true)
		draw_polyline(points, Color("#3d6a80"), 1.1 * CELL_SIZE, true)

	_draw_spawn_and_core()
	_draw_hover()
	_draw_selection()


func _draw_spawn_and_core() -> void:
	var font := ThemeDB.fallback_font
	for entrance_id in PATHS:
		var nodes: Array = PATHS[entrance_id]
		var spawn := cell_to_local(nodes[0])
		var direction := (cell_to_local(nodes[1]) - spawn).normalized()
		var angle := direction.angle()
		var marker_radius := 0.85 * CELL_SIZE
		draw_circle(spawn, marker_radius, Color(0.18, 0.85, 1.0, 0.16))
		draw_arc(spawn, marker_radius * 0.9, angle - 1.1, angle + 1.1, 24, Color("#9cecff"), 2.0)
		var label_position := spawn + direction * (marker_radius * 1.9)
		draw_string(font, label_position + Vector2(-10.0, 5.0), str(ENTRANCE_LABELS.get(entrance_id, "?")), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 12, Color("#dcf8ff"))

	var core_position := cell_to_local(CORE_CELL)
	var core_radius := 1.0 * CELL_SIZE
	draw_circle(core_position, core_radius, Color("#9eeeff"))
	draw_circle(core_position, core_radius * 0.72, Color("#2faee0"))
	draw_line(core_position + Vector2(-core_radius * 0.55, 0), core_position + Vector2(core_radius * 0.55, 0), Color("#effcff"), 2.0)
	draw_line(core_position + Vector2(0, -core_radius * 0.55), core_position + Vector2(0, core_radius * 0.55), Color("#effcff"), 2.0)
	draw_string(font, core_position + Vector2(-24.0, core_radius + 14.0), "IQ 结晶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#dcf8ff"))


func _draw_hover() -> void:
	if not is_inside(hover_cell):
		return
	var rect := Rect2(Vector2(hover_cell.x * CELL_SIZE, hover_cell.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE)).grow(-1.0)
	var valid_color := Color("#9ff4ff") if is_buildable(hover_cell) else Color("#ff6b83")
	draw_rect(rect, Color(valid_color.r, valid_color.g, valid_color.b, 0.30))
	draw_rect(rect, valid_color, false, 1.5)
	var center := cell_to_local(hover_cell)
	draw_arc(center, CELL_SIZE * 0.95, 0.0, TAU, 24, Color(valid_color.r, valid_color.g, valid_color.b, 0.7), 1.5)


func _draw_selection() -> void:
	if not _has_selection:
		return
	draw_rect(_selection_rect, Color(0.35, 0.95, 1.0, 0.16))
	draw_rect(_selection_rect, Color("#8ef6ff"), false, 1.5)


