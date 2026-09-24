class_name LakeMapView
extends Node2D

const Metrics = preload("res://scripts/game/game_metrics.gd")

## 地图视图：可从像素画 PNG 读取地图，也可用内置默认地图。
## 像素画规则：每 2×2 个图像像素 = 1 个逻辑格；颜色含义见下方 COLOR_*。
## 若 assets/maps/map.png 存在且合法，则优先使用它；否则回退到内置默认地图。

## 像素画文件路径（相对 res://）。改成你自己的图后，启动游戏即自动生效。
const MAP_IMAGE_PATH := "res://assets/maps/map.png"
## 地图画布密度：256×192 像素 → 128×96 个逻辑格。
const MAP_PIXELS_PER_CELL := 2
const COLOR_PATH := Color("#0a0f14")    # 深色 = 路径（敌人行走，不可建造）
const COLOR_CORE := Color("#ffe26b")    # 黄色 = IQ 结晶（只能有 1 格）
const COLOR_SPAWN := Color("#7ef0a4")   # 绿色 = 琪露诺出生点
const COLOR_LAND := Color("#4a5d68")    # 模板用灰色 = 空地（可建造；其它任意颜色也可以）
const COLOR_TOLERANCE := 0.18           # 颜色容差，避免画图软件轻微变色后读不到

## 固定单屏尺寸下的逻辑网格参数。
const DEFAULT_COLS := Metrics.MAP_COLS
const DEFAULT_ROWS := Metrics.MAP_ROWS
const CELL_SIZE := Metrics.CELL_SIZE
const DEFAULT_CORE_CELL := Vector2i(64, 48)
const DEFAULT_HERO_SPAWN_CELL := Vector2i(12, 84)
const DEFAULT_ENTRANCE := "west"
const ENTRANCE_LABELS := {
	"west": "西",
	"north": "北",
	"south": "南",
	"east": "东",
}
## 道路宽约 5 格（半宽 2 格），满足新地图密度下的主路宽度。
const PATH_HALF_WIDTH := 2.1
const PATH_SEGMENT_CELLS := 2.0
## 新地图的细网格只每隔若干格绘制一次，避免密集网格遮挡像素画。
const GRID_STEP_CELLS := 4
## 建造预览占地必须与实际判定一致：兵营 2×2，防御塔 3×3。
const BARRACKS_PREVIEW_OFFSETS := [
	Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(0, 1), Vector2i(1, 1),
]
const TOWER_PREVIEW_OFFSETS := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

## 内置默认地图：各入口的路径关键点（格坐标），经 Catmull-Rom 平滑成弯曲曲线。
const DEFAULT_PATHS := {
	"west": [
		Vector2i(0, 48), Vector2i(18, 48), Vector2i(30, 38),
		Vector2i(48, 38), Vector2i(60, 47), Vector2i(64, 48),
	],
	"north": [
		Vector2i(64, 0), Vector2i(64, 18), Vector2i(56, 27),
		Vector2i(56, 37), Vector2i(64, 48),
	],
	"south": [
		Vector2i(40, 95), Vector2i(38, 78), Vector2i(46, 66),
		Vector2i(57, 58), Vector2i(64, 48),
	],
	"east": [
		Vector2i(127, 48), Vector2i(109, 44), Vector2i(96, 32),
		Vector2i(82, 36), Vector2i(72, 43), Vector2i(64, 48),
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
var build_preview_id := "icicle"
var _path_cells: Dictionary = {}
var _image_path_cells: Dictionary = {}
var _uses_image_map := false
var _map_texture: ImageTexture
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
	if img.get_width() % MAP_PIXELS_PER_CELL != 0 or img.get_height() % MAP_PIXELS_PER_CELL != 0:
		push_warning("地图像素画宽高必须是 %d 的倍数" % MAP_PIXELS_PER_CELL)
		return false
	COLS = int(img.get_width() / MAP_PIXELS_PER_CELL)
	ROWS = int(img.get_height() / MAP_PIXELS_PER_CELL)
	if COLS < 4 or ROWS < 4:
		push_warning("地图像素画尺寸过小（至少 4x4 格）")
		return false
	BOARD_SIZE = Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)
	var path_cells: Dictionary = {}
	var core := Vector2i(-1, -1)
	var spawn := Vector2i(-1, -1)
	for y in range(ROWS):
		for x in range(COLS):
			# 每个逻辑格读取 2×2 像素块的中心；画图时请让每个块保持同色。
			var sample_x := x * MAP_PIXELS_PER_CELL + int(MAP_PIXELS_PER_CELL / 2)
			var sample_y := y * MAP_PIXELS_PER_CELL + int(MAP_PIXELS_PER_CELL / 2)
			var c := img.get_pixel(sample_x, sample_y)
			if c.a < 0.5:
				continue
			var cell := Vector2i(x, y)
			if _color_close(c, COLOR_CORE):
				if core.x < 0:
					core = cell
			elif _color_close(c, COLOR_SPAWN):
				if spawn.x < 0:
					spawn = cell
			elif _color_close(c, COLOR_PATH):
				path_cells[cell] = true
	if core.x < 0:
		push_warning("地图像素画里没有核心色（黄），回退到默认地图")
		return false
	CORE_CELL = core
	HERO_SPAWN_CELL = spawn if spawn.x >= 0 else Vector2i(
		clampi(DEFAULT_HERO_SPAWN_CELL.x, 0, COLS - 1),
		clampi(DEFAULT_HERO_SPAWN_CELL.y, 0, ROWS - 1)
	)
	_image_path_cells = path_cells.duplicate()
	_uses_image_map = true
	_map_texture = ImageTexture.create_from_image(img)
	_path_cells = path_cells.duplicate()
	PATHS = _derive_paths_from_cells()
	if PATHS.is_empty():
		push_warning("地图像素画里没有能从边界通向核心的路径，回退到默认地图")
		_uses_image_map = false
		_image_path_cells.clear()
		_map_texture = null
		return false
	return true


func _setup_default_map() -> void:
	COLS = DEFAULT_COLS
	ROWS = DEFAULT_ROWS
	BOARD_SIZE = Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)
	CORE_CELL = DEFAULT_CORE_CELL
	HERO_SPAWN_CELL = DEFAULT_HERO_SPAWN_CELL
	PATHS = DEFAULT_PATHS.duplicate(true)
	_image_path_cells.clear()
	_uses_image_map = false
	_map_texture = null


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
			# 取宽路入口段的中线格，避免敌人从路缘贴边出生。
			var entrance_cell: Vector2i = run[run.size() / 2]
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
	# 像素画中的道路格是玩家画出的真实占地区域；默认地图则从路径曲线光栅化。
	_path_cells = _image_path_cells.duplicate() if _uses_image_map else {}
	_path_local_points.clear()
	_path_world_points.clear()
	for entrance_id in PATHS:
		var waypoints := _to_float_points(PATHS[entrance_id])
		var dense := _sample_catmull_rom(waypoints, 2.0)
		# 玩家像素画的路径格就是权威占地；不要用平滑线额外扩张可建造边界。
		if not _uses_image_map:
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


func cell_position_to_local(cell_position: Vector2) -> Vector2:
	return Vector2(
		(cell_position.x + 0.5) * CELL_SIZE,
		(cell_position.y + 0.5) * CELL_SIZE
	)


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


func set_build_preview(build_id: String) -> void:
	build_preview_id = build_id
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
	# 外框与地图底色。
	draw_rect(Rect2(Vector2(-4.0, -4.0), BOARD_SIZE + Vector2(8.0, 8.0)), Color("#050d18"))
	if _map_texture != null:
		# 玩家绘制的像素画原样显示；最近邻采样保留 2×2 像素块的硬边。
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_texture_rect(_map_texture, Rect2(Vector2.ZERO, BOARD_SIZE), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color("#17313a"))

	# 内置默认地图使用稀疏网格辅助定位；玩家像素画不额外压网格。
	if _map_texture == null:
		var grid_color := Color(0.55, 0.82, 0.95, 0.055)
		for x in range(0, COLS + 1, GRID_STEP_CELLS):
			var px := x * CELL_SIZE
			draw_line(Vector2(px, 0.0), Vector2(px, BOARD_SIZE.y), grid_color, 1.0)
		for y in range(0, ROWS + 1, GRID_STEP_CELLS):
			var py := y * CELL_SIZE
			draw_line(Vector2(0.0, py), Vector2(BOARD_SIZE.x, py), grid_color, 1.0)

	# 默认地图直接绘制路径格；像素画已包含路径颜色，保留原画不覆盖。
	if _map_texture == null:
		for path_cell in _path_cells:
			var cell := path_cell as Vector2i
			draw_rect(
				Rect2(Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE), Vector2(CELL_SIZE + 0.5, CELL_SIZE + 0.5)),
				COLOR_PATH
			)
	# 内置地图补一条路心线；玩家像素画保留原稿，不覆盖用户画的道路。
	if _map_texture == null:
		for entrance_id in _path_local_points:
			var points := _path_local_points[entrance_id] as PackedVector2Array
			draw_polyline(points, Color("#17313d"), 1.25 * CELL_SIZE, true)

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
		var marker_radius := 1.15 * CELL_SIZE
		draw_circle(spawn, marker_radius, Color(0.18, 0.85, 1.0, 0.16))
		draw_arc(spawn, marker_radius * 0.9, angle - 1.1, angle + 1.1, 20, Color("#9cecff"), 1.5)
		var label_position := spawn + direction * (marker_radius * 1.9)
		draw_string(font, label_position + Vector2(-8.0, 4.0), str(ENTRANCE_LABELS.get(entrance_id, "?")), HORIZONTAL_ALIGNMENT_CENTER, 18.0, 12, Color("#dcf8ff"))

	var core_position := cell_to_local(CORE_CELL)
	var core_radius := 1.65 * CELL_SIZE
	draw_circle(core_position, core_radius, Color("#9eeeff"))
	draw_circle(core_position, core_radius * 0.72, Color("#2faee0"))
	draw_line(core_position + Vector2(-core_radius * 0.55, 0), core_position + Vector2(core_radius * 0.55, 0), Color("#effcff"), 2.0)
	draw_line(core_position + Vector2(0, -core_radius * 0.55), core_position + Vector2(0, core_radius * 0.55), Color("#effcff"), 2.0)
	draw_string(font, core_position + Vector2(-18.0, core_radius + 15.0), "IQ 结晶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#dcf8ff"))


func _draw_hover() -> void:
	if not is_inside(hover_cell):
		return
	var offsets: Array = BARRACKS_PREVIEW_OFFSETS if build_preview_id.ends_with("_barracks") else TOWER_PREVIEW_OFFSETS
	var footprint_valid := true
	for offset in offsets:
		var cell: Vector2i = hover_cell + offset
		if not is_buildable(cell):
			footprint_valid = false
			break
	var valid_color := Color("#9ff4ff") if footprint_valid else Color("#ff6b83")
	for offset in offsets:
		var cell: Vector2i = hover_cell + offset
		if not is_inside(cell):
			continue
		var rect := Rect2(Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE)).grow(-0.5)
		draw_rect(rect, Color(valid_color.r, valid_color.g, valid_color.b, 0.30))
		draw_rect(rect, valid_color, false, 1.0)

func _draw_selection() -> void:
	if not _has_selection:
		return
	draw_rect(_selection_rect, Color(0.35, 0.95, 1.0, 0.16))
	draw_rect(_selection_rect, Color("#8ef6ff"), false, 1.5)
