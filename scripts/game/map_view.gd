class_name LakeMapView
extends Node2D

## 大地图视图：256x192 高密度网格 + 四条弯曲出兵路径。
## 所有棋盘坐标以「格」为单位，世界坐标通过 cell_to_local / to_global 换算。
## 绘制仅使用少数大矩形与折线，避免逐格绘制 49k 个格子，保证大图性能。

const COLS := 256
const ROWS := 192
const CELL_SIZE := 8.0
const BOARD_SIZE := Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)

const CORE_CELL := Vector2i(224, 96)
const HERO_SPAWN_CELL := Vector2i(28, 168)
const DEFAULT_ENTRANCE := "west"
const ENTRANCE_LABELS := {
	"west": "西",
	"north": "北",
	"south": "南",
	"east": "东",
}
## 每条路从边界入口蜿蜒汇向核心（CORE_CELL）。路宽约 5 格。
const PATH_HALF_WIDTH := 2.5
const PATH_SEGMENT_CELLS := 1.0

## 各入口的路径关键点（格坐标），会经 Catmull-Rom 平滑成弯曲曲线。
const PATHS := {
	"west": [
		Vector2i(4, 108),
		Vector2i(52, 108),
		Vector2i(52, 56),
		Vector2i(100, 56),
		Vector2i(100, 120),
		Vector2i(156, 120),
		Vector2i(156, 62),
		Vector2i(208, 62),
		Vector2i(208, 102),
		Vector2i(224, 96),
	],
	"north": [
		Vector2i(120, 4),
		Vector2i(120, 44),
		Vector2i(64, 44),
		Vector2i(64, 92),
		Vector2i(112, 92),
		Vector2i(112, 140),
		Vector2i(168, 140),
		Vector2i(168, 96),
		Vector2i(224, 96),
	],
	"south": [
		Vector2i(148, 187),
		Vector2i(148, 148),
		Vector2i(196, 148),
		Vector2i(196, 108),
		Vector2i(156, 108),
		Vector2i(156, 70),
		Vector2i(196, 70),
		Vector2i(196, 96),
		Vector2i(224, 96),
	],
	"east": [
		Vector2i(251, 84),
		Vector2i(212, 84),
		Vector2i(212, 44),
		Vector2i(168, 44),
		Vector2i(168, 88),
		Vector2i(168, 126),
		Vector2i(206, 126),
		Vector2i(224, 96),
	],
}

var hover_cell := Vector2i(-99, -99)
var selected_tower_id := "icicle"
var _path_cells: Dictionary = {}
var _path_local_points: Dictionary = {}
var _path_world_points: Dictionary = {}
var _selection_rect := Rect2()
var _has_selection := false


func _ready() -> void:
	_build_paths()
	queue_redraw()


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


func _to_float_points(cells: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for cell in cells:
		result.append(Vector2(cell))
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


func _rasterize_path(samples: PackedVector2Array) -> void:
	var radius := int(ceil(PATH_HALF_WIDTH))
	for sample in samples:
		var center := Vector2i(int(round(sample.x)), int(round(sample.y)))
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


func get_path_points(entrance_id: String = "west") -> PackedVector2Array:
	return _path_world_points.get(entrance_id, _path_world_points.get(DEFAULT_ENTRANCE, PackedVector2Array())).duplicate()


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
	# 边框与空地底色（空地保持空旷深色）
	draw_rect(Rect2(Vector2(-8.0, -8.0), BOARD_SIZE + Vector2(16.0, 16.0)), Color("#050d18"))
	draw_rect(Rect2(Vector2.ZERO, BOARD_SIZE), Color("#0f2734"))

	# 高密度网格线（提升像素密度感）
	var grid_color := Color(0.5, 0.78, 0.95, 0.045)
	for x in range(COLS + 1):
		var px := x * CELL_SIZE
		draw_line(Vector2(px, 0.0), Vector2(px, BOARD_SIZE.y), grid_color, 1.0)
	for y in range(ROWS + 1):
		var py := y * CELL_SIZE
		draw_line(Vector2(0.0, py), Vector2(BOARD_SIZE.x, py), grid_color, 1.0)

	# 深色弯曲路径：深色宽底 + 较亮内线
	for entrance_id in _path_local_points:
		var points := _path_local_points[entrance_id] as PackedVector2Array
		draw_polyline(points, Color("#141f2c"), PATH_HALF_WIDTH * 2.0 * CELL_SIZE, true)
		draw_polyline(points, Color("#2c4759"), 1.4 * CELL_SIZE, true)

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
		var marker_radius := 2.2 * CELL_SIZE
		draw_circle(spawn, marker_radius, Color(0.18, 0.85, 1.0, 0.16))
		draw_arc(spawn, marker_radius * 0.9, angle - 1.1, angle + 1.1, 24, Color("#9cecff"), 2.0)
		var label_position := spawn + direction * (marker_radius * 2.2)
		draw_string(font, label_position + Vector2(-10.0, 5.0), str(ENTRANCE_LABELS.get(entrance_id, "?")), HORIZONTAL_ALIGNMENT_CENTER, 30.0, 12, Color("#dcf8ff"))

	var core_position := cell_to_local(CORE_CELL)
	var core_radius := 3.0 * CELL_SIZE
	draw_circle(core_position, core_radius, Color("#9eeeff"))
	draw_circle(core_position, core_radius * 0.72, Color("#2faee0"))
	draw_line(core_position + Vector2(-core_radius * 0.55, 0), core_position + Vector2(core_radius * 0.55, 0), Color("#effcff"), 2.0)
	draw_line(core_position + Vector2(0, -core_radius * 0.55), core_position + Vector2(0, core_radius * 0.55), Color("#effcff"), 2.0)
	draw_string(font, core_position + Vector2(-24.0, core_radius + 16.0), "IQ 结晶", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#dcf8ff"))


func _draw_hover() -> void:
	if not is_inside(hover_cell):
		return
	var rect := Rect2(Vector2(hover_cell.x * CELL_SIZE, hover_cell.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE)).grow(-1.0)
	var valid_color := Color("#9ff4ff") if is_buildable(hover_cell) else Color("#ff6b83")
	draw_rect(rect, Color(valid_color.r, valid_color.g, valid_color.b, 0.30))
	draw_rect(rect, valid_color, false, 1.5)
	var center := cell_to_local(hover_cell)
	draw_arc(center, CELL_SIZE * 1.9, 0.0, TAU, 24, Color(valid_color.r, valid_color.g, valid_color.b, 0.7), 1.5)


func _draw_selection() -> void:
	if not _has_selection:
		return
	draw_rect(_selection_rect, Color(0.35, 0.95, 1.0, 0.16))
	draw_rect(_selection_rect, Color("#8ef6ff"), false, 1.5)
