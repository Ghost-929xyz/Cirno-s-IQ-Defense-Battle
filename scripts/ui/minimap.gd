class_name BattleMinimap
extends Control

## 小地图：显示整张地图缩略图、敌我位置与当前镜头范围。
## 左键点击或拖动可把镜头跳转到对应位置。

var _game: Node
var _panning := false


func setup(game: Node) -> void:
	_game = game


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _world_to_map(world_position: Vector2) -> Vector2:
	var board: Vector2 = _game.map_view.BOARD_SIZE
	return Vector2(world_position.x / board.x * size.x, world_position.y / board.y * size.y)


func _map_to_world(map_position: Vector2) -> Vector2:
	var board: Vector2 = _game.map_view.BOARD_SIZE
	return Vector2(map_position.x / size.x * board.x, map_position.y / size.y * board.y)


func _gui_input(event: InputEvent) -> void:
	if _game == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_panning = event.pressed
		if _panning:
			_game.move_camera_to(_map_to_world(event.position))
		accept_event()
	elif event is InputEventMouseMotion and _panning:
		_game.move_camera_to(_map_to_world(event.position))
		accept_event()


func _draw() -> void:
	if _game == null or not is_instance_valid(_game):
		return
	var map_view = _game.map_view
	var cols := float(map_view.COLS)
	var rows := float(map_view.ROWS)
	var cell := Vector2(maxf(1.0, size.x / cols), maxf(1.0, size.y / rows))

	# 背景与路径。
	draw_rect(Rect2(Vector2.ZERO, size), Color("#07101c"))
	if map_view._map_texture != null:
		draw_texture_rect(map_view._map_texture, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#16232e"))
		for path_cell in map_view._path_cells:
			draw_rect(Rect2(Vector2(path_cell.x * cell.x, path_cell.y * cell.y), cell), Color("#3d4a55"))

	# IQ 结晶。
	draw_circle(_world_to_map(map_view.get_core_world_position()), 3.0, Color("#ffe26b"))

	# 建筑（防御塔与兵营）。
	for structure_node in get_tree().get_nodes_in_group("structures"):
		var structure := structure_node as Node2D
		if structure != null and is_instance_valid(structure):
			var point := _world_to_map(structure.global_position)
			draw_rect(Rect2(point - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color("#7ec8ff"))

	# 友军。
	for ally_node in get_tree().get_nodes_in_group("allies"):
		var ally := ally_node as Node2D
		if ally != null and is_instance_valid(ally):
			draw_circle(_world_to_map(ally.global_position), 1.6, Color("#9ff4c9"))

	# 敌人。
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as Node2D
		if enemy != null and is_instance_valid(enemy):
			draw_circle(_world_to_map(enemy.global_position), 1.8, Color("#ff7d8f"))

	# 琪露诺。
	var heroes := get_tree().get_nodes_in_group("hero")
	for hero_node in heroes:
		var hero := hero_node as Node2D
		if hero != null and is_instance_valid(hero):
			draw_circle(_world_to_map(hero.global_position), 2.4, Color("#ffffff"))

	# 当前镜头可视范围（加亮冰晶框）。
	var camera := _game._camera as Camera2D
	if camera != null:
		var view_size := get_viewport_rect().size / camera.zoom.x
		var top_left := _world_to_map(camera.position - view_size * 0.5)
		var bottom_right := _world_to_map(camera.position + view_size * 0.5)
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(0.55, 0.9, 1.0, 0.18), true)
		draw_rect(Rect2(top_left, bottom_right - top_left), Color(0.85, 0.97, 1.0, 0.95), false, 1.2)

	# 冰晶双线边框 + 四角亮点。
	draw_rect(Rect2(Vector2.ZERO, size), Color("#60bee0"), false, 1.5)
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), Color(0.24, 0.55, 0.72, 0.6), false, 1.0)
	for corner in [Vector2(1.0, 1.0), Vector2(size.x - 3.0, 1.0), Vector2(1.0, size.y - 3.0), Vector2(size.x - 3.0, size.y - 3.0)]:
		draw_rect(Rect2(corner, Vector2(2.0, 2.0)), Color("#d8fbff"))
