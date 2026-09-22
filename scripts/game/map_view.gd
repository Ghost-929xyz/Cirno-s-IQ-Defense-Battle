class_name LakeMapView
extends Node2D

const COLS := 12
const ROWS := 9
const CELL_SIZE := 60.0
const BOARD_SIZE := Vector2(COLS * CELL_SIZE, ROWS * CELL_SIZE)
const PATH_NODES: Array[Vector2i] = [
	Vector2i(-1, 4),
	Vector2i(2, 4),
	Vector2i(2, 1),
	Vector2i(5, 1),
	Vector2i(5, 4),
	Vector2i(8, 4),
	Vector2i(8, 2),
	Vector2i(10, 2),
	Vector2i(10, 7),
	Vector2i(11, 7),
]

var hover_cell := Vector2i(-99, -99)
var selected_tower_id := "icicle"
var _path_cells: Array[Vector2i] = []


func _ready() -> void:
	_build_path_cells()
	queue_redraw()


func _build_path_cells() -> void:
	_path_cells.clear()
	for node_index in range(PATH_NODES.size() - 1):
		var from := PATH_NODES[node_index]
		var to := PATH_NODES[node_index + 1]
		var delta := to - from
		var step := Vector2i(0, 0)
		if delta.x != 0:
			step.x = 1 if delta.x > 0 else -1
		if delta.y != 0:
			step.y = 1 if delta.y > 0 else -1
		var cursor := from
		while cursor != to:
			if cursor not in _path_cells:
				_path_cells.append(cursor)
			cursor += step
		if to not in _path_cells:
			_path_cells.append(to)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS


func is_path_cell(cell: Vector2i) -> bool:
	return cell in _path_cells


func is_buildable(cell: Vector2i) -> bool:
	return is_inside(cell) and not is_path_cell(cell)


func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5, cell.y * CELL_SIZE + CELL_SIZE * 0.5)


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := to_local(world_position)
	return Vector2i(int(floor(local_position.x / CELL_SIZE)), int(floor(local_position.y / CELL_SIZE)))


func get_path_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	for node in PATH_NODES:
		points.append(position + cell_to_local(node))
	return points


func set_hover_cell(cell: Vector2i) -> void:
	if hover_cell == cell:
		return
	hover_cell = cell
	queue_redraw()


func set_selected_tower_id(tower_id: String) -> void:
	selected_tower_id = tower_id
	queue_redraw()


func distance_in_cells(a: Vector2, b: Vector2) -> float:
	return a.distance_to(b) / CELL_SIZE


func _draw() -> void:
	var board_rect := Rect2(Vector2.ZERO, BOARD_SIZE)
	draw_rect(board_rect.grow(8.0), Color("#071526"))
	draw_rect(board_rect, Color("#18364a"))

	for y in range(ROWS):
		for x in range(COLS):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(x * CELL_SIZE, y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE)).grow(-2.0)
			var base_color := Color("#245d5a") if (x + y) % 2 == 0 else Color("#205552")
			if is_path_cell(cell):
				base_color = Color("#395d72") if (x + y) % 2 == 0 else Color("#33556a")
			draw_rect(rect, base_color)
			if not is_path_cell(cell):
				draw_line(rect.position + Vector2(8.0, 10.0), rect.position + Vector2(17.0, 5.0), Color(0.65, 0.95, 1.0, 0.22), 2.0)
				draw_line(rect.position + Vector2(41.0, 48.0), rect.position + Vector2(50.0, 42.0), Color(0.65, 0.95, 1.0, 0.18), 2.0)

	for cell in _path_cells:
		var center := cell_to_local(cell)
		if cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS:
			draw_circle(center, 3.0, Color(0.78, 0.95, 1.0, 0.35))

	_draw_spawn_and_core()
	_draw_hover()


func _draw_spawn_and_core() -> void:
	var spawn := cell_to_local(PATH_NODES[0])
	draw_circle(spawn, 26.0, Color(0.18, 0.85, 1.0, 0.15))
	draw_arc(spawn, 20.0, -1.2, 1.2, 24, Color("#9cecff"), 3.0)

	var core_cell := Vector2i(11, 7)
	var core_position := cell_to_local(core_cell)
	draw_circle(core_position, 24.0, Color("#9eeeff"))
	draw_circle(core_position, 17.0, Color("#2faee0"))
	draw_line(core_position + Vector2(-13, 0), core_position + Vector2(13, 0), Color("#effcff"), 3.0)
	draw_line(core_position + Vector2(0, -13), core_position + Vector2(0, 13), Color("#effcff"), 3.0)

	var font := ThemeDB.fallback_font
	draw_string(font, core_position + Vector2(-20, 43), "IQ 核心", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#dcf8ff"))


func _draw_hover() -> void:
	if not is_inside(hover_cell):
		return
	var rect := Rect2(Vector2(hover_cell.x * CELL_SIZE, hover_cell.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE)).grow(-3.0)
	var valid_color := Color("#9ff4ff") if is_buildable(hover_cell) else Color("#ff6b83")
	draw_rect(rect, Color(valid_color.r, valid_color.g, valid_color.b, 0.28))
	draw_rect(rect, valid_color, false, 2.0)
	if is_buildable(hover_cell):
		var center := cell_to_local(hover_cell)
		draw_arc(center, 22.0, 0.0, TAU, 32, Color(valid_color.r, valid_color.g, valid_color.b, 0.65), 2.0)
