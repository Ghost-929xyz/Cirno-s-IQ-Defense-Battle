extends Node2D
## Saved TileMapLayers support the editor map; seeds replace terrain at runtime.
## Clutter, trees and fine roads have independent layers.
const Art = preload("res://scripts/data/tiny_swords_art.gd")
const Actor = preload("res://scripts/entities/tiny_swords_actor.gd")
const BUILDING_HIGHLIGHT = preload("res://scripts/effects/rts_building_highlight.gdshader")
const TILE_SIZE := 64.0
@onready var water: TileMapLayer = $Water
@onready var ground: TileMapLayer = $Ground
@onready var crossings: TileMapLayer = $Crossings
@onready var ice: TileMapLayer = $Ice
@onready var ice_walls: TileMapLayer = $IceWalls
@onready var actors: Node2D = $Actors
@onready var decorations: TileMapLayer = $Decorations
var unit_views: Dictionary = {}
var building_views: Dictionary = {}
var treasure_views: Dictionary = {}
var _revision := -1
var trees: TileMapLayer
var curved_paths: TileMapLayer

func _ready() -> void:
	# Keep every bit of ground clutter beneath every tree, independent of
	# TileMap cell ordering. Also split existing painted maps on load.
	decorations.z_index = 4
	trees = get_node_or_null("Trees") as TileMapLayer
	if trees == null:
		trees = TileMapLayer.new()
		trees.name = "Trees"
		trees.tile_set = decorations.tile_set
		trees.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(trees)
	trees.z_index = 5
	for cell in decorations.get_used_cells():
		if decorations.get_cell_source_id(cell) != 5: continue
		trees.set_cell(cell, 5, decorations.get_cell_atlas_coords(cell), decorations.get_cell_alternative_tile(cell))
		decorations.erase_cell(cell)
	$Paths.clear()
	prepare_central_camp()

func prepare_central_camp() -> void:
	var filled := {}
	for cell in ground.get_used_cells(): filled[cell] = true
	for y in range(18, 33):
		for x in range(33, 48):
			var cell := Vector2i(x, y)
			if Vector2(cell).distance_to(Vector2(40, 25)) > 7: continue
			filled[cell] = true
			crossings.erase_cell(cell)
			decorations.erase_cell(cell)
			trees.erase_cell(cell)
			$ShoreFoam.erase_cell(cell)
	for cell in filled:
		if Vector2(cell).distance_to(Vector2(40, 25)) < 9: ground.set_cell(cell, 1, terrain_atlas_cell(cell, filled))

func terrain_water_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in water.get_used_cells():
		if ground.get_cell_source_id(cell) == -1 and crossings.get_cell_source_id(cell) == -1: cells.append(cell)
	return cells

func terrain_obstacle_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = trees.get_used_cells()
	for cell in decorations.get_used_cells():
		var data := decorations.get_cell_tile_data(cell)
		if decorations.get_cell_source_id(cell) == 5 or (data != null and data.get_custom_data("terrain") == "tree"):
			cells.append(cell)
	return cells

func paint_generated(layout: Dictionary) -> void:
	for layer_name in ["Water", "ShoreFoam", "Ground", "Paths", "Crossings", "Decorations", "Ice", "IceWalls"]:
		get_node(layer_name).clear()
	trees.clear()
	if is_instance_valid(curved_paths): curved_paths.clear()
	for y in 50:
		for x in 80: water.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	for cell in layout.ground: ground.set_cell(cell, 1, terrain_atlas_cell(cell, layout.ground))
	for cell in layout.crossings: crossings.set_cell(cell, 3, layout.crossings[cell])
	for cell in layout.ground:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not layout.ground.has(neighbor) and not layout.crossings.has(neighbor):
				$ShoreFoam.set_cell(cell, 4, Vector2i.ZERO)
				break
	for cell in layout.trees: trees.set_cell(cell, 5, Vector2i.ZERO)
	for cell in layout.decorations: decorations.set_cell(cell, layout.decorations[cell], Vector2i.ZERO)
	_revision = -1

func terrain_atlas_cell(cell: Vector2i, filled: Dictionary) -> Vector2i:
	var left := filled.has(cell + Vector2i.LEFT)
	var right := filled.has(cell + Vector2i.RIGHT)
	var up := filled.has(cell + Vector2i.UP)
	var down := filled.has(cell + Vector2i.DOWN)
	var x := 1 if left and right else (0 if right else 2)
	var y := 1 if up and down else (0 if down else 2)
	if not left and not right: x = 3
	if not up and not down: y = 3
	return Vector2i(x, y)

func sync_terrain(sim) -> void:
	if _revision == sim.navigation_revision: return
	_revision = sim.navigation_revision
	ice.clear()
	ice_walls.clear()
	for cell in sim.bridges: ice.set_cell(Vector2i(int(cell[0]), int(cell[1])), 30, Vector2i(1, 1))
	for wall in sim.walls: ice_walls.set_cell(Vector2i(sim.point(wall)), 31, Vector2i(3, 0))

func sync(sim, delta: float, paused: bool) -> void:
	sync_terrain(sim)
	var ids: Dictionary = {}
	for unit in sim.units:
		var id := int(unit.id)
		ids[id] = true
		if not unit_views.has(id):
			var actor := Actor.new()
			actor.name = "Unit_%d" % id
			actors.add_child(actor)
			unit_views[id] = actor
		unit_views[id].sync(unit, sim, delta, paused)
		unit_views[id].visible = unit.home == -1 and (unit.team == 0 or sim.is_visible(sim.point(unit)))
	for id in unit_views.keys():
		if not ids.has(id):
			unit_views[id].die()
			unit_views.erase(id)
	ids.clear()
	for building in sim.buildings:
		var id := int(building.id)
		ids[id] = true
		var path := Art.building_path(building.kind, int(building.team), bool(building.complete))
		if not building_views.has(id):
			var view := Sprite2D.new()
			view.name = "Building_%d" % id
			view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var feedback := ShaderMaterial.new()
			feedback.shader = BUILDING_HIGHLIGHT
			view.material = feedback
			actors.add_child(view)
			building_views[id] = view
		var view: Sprite2D = building_views[id]
		view.visible = building.team == 0 or sim.is_visible(sim.point(building))
		view.texture = Art.texture(path)
		view.position = (sim.point(building) + Vector2(0.5, 0.5)) * TILE_SIZE
		view.offset = Vector2(0, -view.texture.get_height() / 2.0 + 15)
		var size := 0.7 if building.kind == "base" else (0.8 if building.kind == "house" else 1.0)
		if building.kind in ["well", "academy"]: size = 0.7
		view.scale = Vector2.ONE * size
		view.modulate = Color(0.85, 0.9, 0.85) if building.team == -1 else Color.WHITE
		if building.kind == "academy": view.modulate = Color(1.0, 0.8, 1.1)
		if building.hp < building.max_hp * 0.3: view.modulate = Color(1.0, 0.65, 0.6)
		view.set_meta("kind", building.kind)
		view.set_meta("team", building.team)
	for id in building_views.keys():
		if not ids.has(id):
			var view: Sprite2D = building_views[id]
			view.material = null
			view.texture = Art.texture(Art.building_path(view.get_meta("kind"), int(view.get_meta("team")), true, true))
			# Ruins are transient visuals; they never add pathing obstacles.
			var tween := create_tween()
			tween.tween_property(view, "modulate:a", 0.0, 1.5).set_delay(0.7)
			tween.tween_callback(view.queue_free)
			building_views.erase(id)
	ids.clear()
	for chest in sim.chests:
		var id := int(chest.id)
		ids[id] = true
		if not treasure_views.has(id):
			var view := Sprite2D.new()
			view.name = "Treasure_%d" % id
			view.texture = Art.texture("Resources/Resources/G_Idle.png")
			view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			actors.add_child(view)
			treasure_views[id] = view
		var view: Sprite2D = treasure_views[id]
		view.visible = sim.is_visible(sim.point(chest))
		view.position = (sim.point(chest) + Vector2(0.5, 0.5)) * TILE_SIZE
		view.offset = Vector2(0, -22)
	for id in treasure_views.keys():
		if not ids.has(id):
			treasure_views[id].queue_free()
			treasure_views.erase(id)

func update_building_feedback(hovered_id: int, selected_id: int) -> void:
	for id in building_views:
		var view: Sprite2D = building_views[id]
		var feedback := view.material as ShaderMaterial
		if feedback == null: continue
		var is_selected: bool = int(id) == selected_id
		var is_hovered: bool = int(id) == hovered_id
		feedback.set_shader_parameter("highlight_amount", 0.26 if is_selected else (0.2 if is_hovered else 0.0))
		feedback.set_shader_parameter("outline_amount", 1.0 if is_selected else 0.0)
		feedback.set_shader_parameter("highlight_color", Color("ffe6a8") if is_selected else Color("d6faff"))
		# Keep the visible outline about two screen pixels wide while zooming.
		feedback.set_shader_parameter("outline_width", clampf(1.8 / maxf(view.global_scale.x, 0.05), 1.0, 32.0))

func update_unit_feedback(selected_ids: Array) -> void:
	var chosen := {}
	for id in selected_ids: chosen[int(id)] = true
	for id in unit_views:
		unit_views[id].set_selected(chosen.has(int(id)))
