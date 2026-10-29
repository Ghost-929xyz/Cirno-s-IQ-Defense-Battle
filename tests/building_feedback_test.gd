extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func move_cursor(pos: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	root.push_input(event, true)

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	var game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.pick_card("mana")
	game.pick_card("supplies")
	game.confirm_opening_cards()
	game.sim.choose_base(1)
	game.show_phase_overlay()
	game.zoom = 28.0
	game.focus_home()
	game.tile_map.sync(game.sim, 0.0, true)
	game.refresh_ui()
	game.world_overlay.queue_redraw()
	await process_frame
	var base: Dictionary = {}
	for building in game.sim.buildings:
		if building.kind == "base" and building.team == 0: base = building
	check(not base.is_empty(), "Test expedition has a player base")
	var id := int(base.id)
	var view: Sprite2D = game.tile_map.building_views[id]
	var feedback := view.material as ShaderMaterial
	check(feedback != null, "Building supports sprite feedback")
	var opaque_screen := Vector2.ZERO
	var rect := view.get_rect()
	for y in range(int(rect.position.y), int(rect.end.y), 4):
		for x in range(int(rect.position.x), int(rect.end.x), 4):
			var point := Vector2(x, y)
			if not view.is_pixel_opaque(point): continue
			var screen := view.get_global_transform_with_canvas() * point
			if game.building_at_screen_position(screen) == id:
				opaque_screen = screen
				break
		if opaque_screen != Vector2.ZERO: break
	check(opaque_screen != Vector2.ZERO, "Opaque roof pixels are hittable above the building footprint")
	var transparent_screen := view.get_global_transform_with_canvas() * (rect.position + Vector2.ONE)
	check(game.building_at_screen_position(transparent_screen) != id, "Transparent sprite padding does not count as a hover")
	move_cursor(Vector2(24, 400))
	game.update_building_feedback()
	await capture("res://.tools/building-neutral.png")
	move_cursor(opaque_screen)
	game.update_building_feedback()
	check(game.hovered_building == id, "Mouse motion highlights the opaque building surface")
	check(float(feedback.get_shader_parameter("highlight_amount")) > 0.0, "Hovered building becomes brighter")
	check(float(feedback.get_shader_parameter("outline_amount")) == 0.0, "Hover does not show a selection contour")
	await capture("res://.tools/building-hover.png")
	game.selected_building = id
	move_cursor(transparent_screen)
	game.update_building_feedback()
	check(game.hovered_building != id, "Moving into transparent padding ends hover")
	check(float(feedback.get_shader_parameter("outline_amount")) > 0.0 and float(feedback.get_shader_parameter("highlight_amount")) > 0.0, "Selection contour and highlight survive mouse exit")
	await capture("res://.tools/building-selected.png")
	var screen_width: float = feedback.get_shader_parameter("outline_width") * view.global_scale.x
	game.zoom = 10.0
	game.update_camera()
	game.update_building_feedback()
	check(is_equal_approx(screen_width, float(feedback.get_shader_parameter("outline_width")) * view.global_scale.x), "Outline keeps its screen width when zooming out")
	game.zoom = 28.0
	game.update_camera()
	# A real GUI panel covers the roof; an input event must no longer reach it.
	var panel := Panel.new()
	panel.position = opaque_screen - Vector2(12, 12)
	panel.size = Vector2(24, 24)
	game.layer.add_child(panel)
	move_cursor(opaque_screen + Vector2(1, 1))
	await process_frame
	game.update_building_feedback()
	check(game.hovered_building == -1, "UI over a building suppresses hover feedback")
	check(float(feedback.get_shader_parameter("outline_amount")) > 0.0, "UI hover does not cancel selection")
	panel.queue_free()
	await process_frame
	game.selected_building = -1
	game.tile_map.update_building_feedback(-1, -1)
	check(float(feedback.get_shader_parameter("outline_amount")) == 0.0 and float(feedback.get_shader_parameter("highlight_amount")) == 0.0, "Clearing selection resets feedback")
	game.selected_building = id
	game.tile_map.update_building_feedback(id, id)
	game.sim.buildings.erase(base)
	game.tile_map.sync(game.sim, 0.0, true)
	game.update_building_feedback()
	check(view.material == null and not game.tile_map.building_views.has(id), "Destroyed building ruins have no highlight or contour")
	check(game.selected_building == -1, "Destroyed selection is cleared")
	game.queue_free()
	await process_frame
	print("BUILDING_FEEDBACK_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
