extends Control
const Field = preload("res://scripts/data/rts_battlefield.gd")
var game: Node
var wet_cells: Array[Vector2i] = []
var expanded_map := false
var surface: Node2D
var viewport: SubViewport
var terrain: ImageTexture
var map_rect := Rect2()
var fog_image: Image
var fog_texture: ImageTexture
var fog_revision := -1
var terrain_revision := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "金色矿点 · 蓝色魔泉 · 紫色灵视塔\n左键定位；右键下令；Shift 连续指令\n红色闪圈：受袭；蓝色外圈：空闲部队"
	var padding := Vector2(30, 30) if expanded_map else Vector2(12, 12)
	var fit := (size - padding) / Vector2(Field.WIDTH, Field.HEIGHT)
	var pixel := minf(fit.x, fit.y)
	var extent := Vector2(Field.WIDTH, Field.HEIGHT) * pixel
	map_rect = Rect2((size - extent) * 0.5, extent)
	build_terrain()
	fog_image = Image.create(Field.WIDTH, Field.HEIGHT, false, Image.FORMAT_RGBA8)
	fog_texture = ImageTexture.create_from_image(fog_image)
	viewport = SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	surface = Node2D.new()
	surface.set_script(preload("res://scripts/ui/rts_map_surface.gd"))
	surface.chart = self
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(surface)
	var display := TextureRect.new()
	display.texture = viewport.get_texture()
	display.size = size
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(display)

func build_terrain() -> void:
	var image := Image.create(Field.WIDTH, Field.HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color("a5c5d3"))
	for cell in wet_cells: image.set_pixelv(cell, Color("30556b"))
	for cell in game.tile_map.crossings.get_used_cells(): image.set_pixelv(cell, Color("c2af8c"))
	for tree in game.sim.tree_sites:
		if tree.hp > 0: image.set_pixelv(Vector2i(game.sim.point(tree)), Color("3f5e56"))
	terrain = ImageTexture.create_from_image(image)
	terrain_revision = game.sim.navigation_revision

func surface_point(pos: Vector2) -> Vector2:
	return map_rect.position + (pos + Vector2(0.5, 0.5)) / Vector2(Field.WIDTH, Field.HEIGHT) * map_rect.size

func world_to_local(pos: Vector2) -> Vector2:
	return surface_point(pos)

func local_to_world(pos: Vector2) -> Vector2:
	return (pos - map_rect.position) / map_rect.size * Vector2(Field.WIDTH, Field.HEIGHT)

func _has_point(pos: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(pos)

func _gui_input(event: InputEvent) -> void:
	if game.wave_intro.active: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if map_rect.has_point(event.position):
			var pos := local_to_world(event.position) - Vector2(0.5, 0.5)
			if expanded_map: game.toggle_overview()
			if not game.simulation_blocked():
				if game.selected.is_empty() and game.selected_building >= 0: game.sim.set_rally(game.selected_building, pos, event.shift_pressed)
				else: game.contextual_order(pos, event.shift_pressed)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if map_rect.has_point(event.position):
			game.center_camera(local_to_world(event.position))
			if expanded_map: game.toggle_overview()
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if map_rect.has_point(event.position): game.center_camera(local_to_world(event.position))
		accept_event()

func _process(_delta: float) -> void:
	if terrain_revision != game.sim.navigation_revision: build_terrain()
	if is_visible_in_tree(): surface.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("91bac1"), false, 1.2)

func draw_map(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("0c1a22"))
	canvas.draw_texture_rect(terrain, map_rect, false)
	for cell in game.sim.bridges:
		var scale_cell := map_rect.size / Vector2(Field.WIDTH, Field.HEIGHT)
		canvas.draw_rect(Rect2(surface_point(Vector2(cell[0], cell[1])) - scale_cell * 0.5, scale_cell), Color("b6ebef"))
	if fog_revision != game.sim.visibility_revision:
		fog_revision = game.sim.visibility_revision
		fog_image.fill(Color("071018"))
		for key in game.sim.explored_cells: fog_image.set_pixel(int(key) % Field.WIDTH, int(key) / Field.WIDTH, Color(0.02, 0.04, 0.06, 0.7))
		for key in game.sim.visible_cells: fog_image.set_pixel(int(key) % Field.WIDTH, int(key) / Field.WIDTH, Color.TRANSPARENT)
		fog_texture.update(fog_image)
	canvas.draw_texture_rect(fog_texture, map_rect, false)
	var icon_size := 6.0 if expanded_map else 3.0
	for pos in Field.WILDLIFE:
		if not game.sim.is_visible(pos): continue
		var occupied: bool = game.sim.wildlife_alive_at(pos)
		var p := surface_point(pos)
		var c := Color("f3bf71") if occupied or game.sim.phase in ["base", "cards"] else Color("6f817c")
		canvas.draw_line(p - Vector2(icon_size, icon_size), p + Vector2(icon_size, icon_size), c, 1.7, true)
		canvas.draw_line(p + Vector2(-icon_size, icon_size), p + Vector2(icon_size, -icon_size), c, 1.7, true)
	for chest in game.sim.chests:
		if game.sim.is_visible(game.sim.point(chest)): canvas.draw_circle(surface_point(game.sim.point(chest)), 3.0 if expanded_map else 1.6, Color("f5d58d"))
	for unit in game.sim.units:
		if unit.team != 0 and not game.sim.is_visible(game.sim.point(unit)): continue
		if unit.home == -1: canvas.draw_circle(surface_point(game.sim.point(unit)), 2.5 if expanded_map else 1.25, game.team_color(int(unit.team)))
	for unit in game.sim.idle_units(): canvas.draw_arc(surface_point(game.sim.point(unit)), 4 if expanded_map else 2.5, 0, TAU, 12, Color("82e0ee"), 1)
	for building in game.sim.buildings:
		if building.team != 0 and not game.sim.is_visible(game.sim.point(building)): continue
		var p := surface_point(game.sim.point(building))
		var c: Color = game.team_color(int(building.team))
		if building.kind == "outpost":
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -icon_size - 1), p + Vector2(icon_size + 1, 0), p + Vector2(0, icon_size + 1), p + Vector2(-icon_size - 1, 0)]), c)
		else: canvas.draw_rect(Rect2(p - Vector2.ONE * icon_size, Vector2.ONE * icon_size * 2), c)
	for site in game.sim.resource_sites:
		if not game.sim.resource_known(site): continue
		var p := surface_point(game.sim.point(site))
		var tint := Color("f0c777") if site.kind == "gold_mine" else (Color("82e0ee") if site.kind == "mana_spring" else Color("cf9eff"))
		canvas.draw_circle(p, icon_size + 1, Color("0b1721"))
		if site.kind == "gold_mine": canvas.draw_rect(Rect2(p - Vector2.ONE * icon_size * 0.65, Vector2.ONE * icon_size * 1.3), tint)
		elif site.kind == "mana_spring": canvas.draw_circle(p, icon_size * 0.8, tint)
		else: canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -icon_size), p + Vector2(icon_size, icon_size), p + Vector2(-icon_size, icon_size)]), tint)
		if site.team == 0: canvas.draw_arc(p, icon_size + 2, 0, TAU, 16, Color("82e0ee"), 1)
		if expanded_map: canvas.draw_string(game.FONT, p + Vector2(8, -5), game.sim.RESOURCE_NAMES[site.kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)
	for alert in game.sim.attack_alerts:
		var radius := (9 if expanded_map else 5) + 4 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008))
		canvas.draw_arc(surface_point(game.sim.point(alert)), radius, 0, TAU, 24, Color("ff665e"), 2)
	var visible_world: Rect2 = game.visible_world_rect().intersection(Rect2(0, 0, Field.WIDTH, Field.HEIGHT))
	var scale_map := map_rect.size / Vector2(Field.WIDTH, Field.HEIGHT)
	canvas.draw_rect(Rect2(map_rect.position + visible_world.position * scale_map, visible_world.size * scale_map), Color(0.9, 1.0, 0.98, 0.85), false, 1.0)
