extends Control
const Field = preload("res://scripts/data/rts_battlefield.gd")
var game: Node
var wet_cells: Array[Vector2i] = []
var circular := true
var surface: Node2D
var viewport: SubViewport
var terrain: ImageTexture
var map_rect := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "敌营 ◆  打野 ×  奖励 ●\n点击定位视野 · Tab 展开俯瞰地图"
	var fit := (size - Vector2(30, 30)) / Vector2(Field.WIDTH, Field.HEIGHT)
	var pixel := minf(fit.x, fit.y)
	var extent := Vector2(Field.WIDTH, Field.HEIGHT) * pixel
	map_rect = Rect2((size - extent) * 0.5, extent)
	if circular: map_rect = Rect2(Vector2.ZERO, size)
	build_terrain()
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
	if circular:
		var shader := Shader.new()
		# Map the complete square chart into a disk so corner landmarks are retained.
		shader.code = "shader_type canvas_item; void fragment(){ vec2 p=(UV-vec2(0.5))*2.0; float x=p.x; float y=p.y; float k=2.82842712; vec2 q=vec2(0.5*(sqrt(max(0.0,2.0+x*x-y*y+k*x))-sqrt(max(0.0,2.0+x*x-y*y-k*x))),0.5*(sqrt(max(0.0,2.0-x*x+y*y+k*y))-sqrt(max(0.0,2.0-x*x+y*y-k*y)))); vec4 c=texture(TEXTURE,(q+vec2(1.0))*0.5); c.a*=1.0-smoothstep(0.97,1.0,length(p)); COLOR=c; }"
		var radial_mask := ShaderMaterial.new()
		radial_mask.shader = shader
		display.material = radial_mask
	add_child(display)

func build_terrain() -> void:
	var image := Image.create(Field.WIDTH, Field.HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color("657961"))
	for cell in wet_cells: image.set_pixelv(cell, Color("30556b"))
	for cell in game.tile_map.get_node("Paths").get_used_cells(): image.set_pixelv(cell, Color("b6a876"))
	for cell in game.tile_map.crossings.get_used_cells(): image.set_pixelv(cell, Color("c2af8c"))
	for cell in game.tile_map.get_node("Decorations").get_used_cells():
		if game.tile_map.get_node("Decorations").get_cell_source_id(cell) == 5: image.set_pixelv(cell, Color("3f5e56"))
	terrain = ImageTexture.create_from_image(image)

func surface_point(pos: Vector2) -> Vector2:
	return map_rect.position + (pos + Vector2(0.5, 0.5)) / Vector2(Field.WIDTH, Field.HEIGHT) * map_rect.size

func world_to_local(pos: Vector2) -> Vector2:
	var p := surface_point(pos)
	if not circular: return p
	var q := p / size * 2.0 - Vector2.ONE
	var disk := Vector2(q.x * sqrt(maxf(0, 1.0 - q.y * q.y * 0.5)), q.y * sqrt(maxf(0, 1.0 - q.x * q.x * 0.5)))
	return (disk + Vector2.ONE) * size * 0.5

func local_to_world(pos: Vector2) -> Vector2:
	if circular:
		var q := pos / size * 2.0 - Vector2.ONE
		var k := 2.0 * sqrt(2.0)
		var square := Vector2(
			0.5 * (sqrt(maxf(0, 2 + q.x * q.x - q.y * q.y + k * q.x)) - sqrt(maxf(0, 2 + q.x * q.x - q.y * q.y - k * q.x))),
			0.5 * (sqrt(maxf(0, 2 - q.x * q.x + q.y * q.y + k * q.y)) - sqrt(maxf(0, 2 - q.x * q.x + q.y * q.y - k * q.y))))
		pos = (square + Vector2.ONE) * size * 0.5
	return (pos - map_rect.position) / map_rect.size * Vector2(Field.WIDTH, Field.HEIGHT)

func _has_point(pos: Vector2) -> bool:
	return pos.distance_to(size * 0.5) <= size.x * 0.5 if circular else Rect2(Vector2.ZERO, size).has_point(pos)

func _gui_input(event: InputEvent) -> void:
	if game.wave_intro.active: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if map_rect.has_point(event.position):
			game.center_camera(local_to_world(event.position))
			if not circular: game.toggle_overview()
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if map_rect.has_point(event.position): game.center_camera(local_to_world(event.position))
		accept_event()

func _process(_delta: float) -> void:
	if is_visible_in_tree(): surface.queue_redraw()

func _draw() -> void:
	if circular: draw_arc(size * 0.5, size.x * 0.5 - 1, 0, TAU, 96, Color("91bac1"), 1.2, true)

func draw_map(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color("0c1a22"))
	canvas.draw_texture_rect(terrain, map_rect, false)
	for cell in game.sim.bridges:
		var scale_cell := map_rect.size / Vector2(Field.WIDTH, Field.HEIGHT)
		canvas.draw_rect(Rect2(surface_point(Vector2(cell[0], cell[1])) - scale_cell * 0.5, scale_cell), Color("b6ebef"))
	var icon_size := 3.0 if circular else 6.0
	for pos in Field.WILDLIFE:
		var occupied: bool = game.sim.wildlife_alive_at(pos)
		var p := surface_point(pos)
		var c := Color("f3bf71") if occupied or game.sim.phase in ["base", "cards"] else Color("6f817c")
		canvas.draw_line(p - Vector2(icon_size, icon_size), p + Vector2(icon_size, icon_size), c, 1.7, true)
		canvas.draw_line(p + Vector2(-icon_size, icon_size), p + Vector2(icon_size, -icon_size), c, 1.7, true)
	for chest in game.sim.chests: canvas.draw_circle(surface_point(game.sim.point(chest)), 1.6 if circular else 3.0, Color("f5d58d"))
	for unit in game.sim.units:
		if unit.home == -1: canvas.draw_circle(surface_point(game.sim.point(unit)), 1.25 if circular else 2.5, game.team_color(int(unit.team)))
	for building in game.sim.buildings:
		var p := surface_point(game.sim.point(building))
		var c: Color = game.team_color(int(building.team))
		if building.kind == "outpost":
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -icon_size - 1), p + Vector2(icon_size + 1, 0), p + Vector2(0, icon_size + 1), p + Vector2(-icon_size - 1, 0)]), c)
		else: canvas.draw_rect(Rect2(p - Vector2.ONE * icon_size, Vector2.ONE * icon_size * 2), c)
	if game.sim.phase in ["cards", "base"]:
		for pos in Field.CAMPS:
			var p := surface_point(pos)
			canvas.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), Color("f18c83"))
		for pos in Field.BASE_SITES: canvas.draw_circle(surface_point(pos), icon_size + 1, Color("a2edf1"))
	var visible_world: Rect2 = game.visible_world_rect().intersection(Rect2(0, 0, Field.WIDTH, Field.HEIGHT))
	var scale_map := map_rect.size / Vector2(Field.WIDTH, Field.HEIGHT)
	canvas.draw_rect(Rect2(map_rect.position + visible_world.position * scale_map, visible_world.size * scale_map), Color(0.9, 1.0, 0.98, 0.85), false, 1.0)
