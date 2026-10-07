extends Node2D
## Static TileMapLayers are saved in the scene and can be painted in Godot.
## Only spell layers change at runtime. Simulation reads the painted terrain.
const Art = preload("res://scripts/data/tiny_swords_art.gd")
const Actor = preload("res://scripts/entities/tiny_swords_actor.gd")
const TILE_SIZE := 64.0
@onready var water: TileMapLayer = $Water
@onready var ground: TileMapLayer = $Ground
@onready var crossings: TileMapLayer = $Crossings
@onready var ice: TileMapLayer = $Ice
@onready var ice_walls: TileMapLayer = $IceWalls
@onready var actors: Node2D = $Actors
var unit_views: Dictionary = {}
var building_views: Dictionary = {}
var treasure_views: Dictionary = {}
var _revision := -1

func terrain_water_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in water.get_used_cells():
		if ground.get_cell_source_id(cell) == -1 and crossings.get_cell_source_id(cell) == -1: cells.append(cell)
	return cells

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
			actors.add_child(view)
			building_views[id] = view
		var view: Sprite2D = building_views[id]
		view.texture = Art.texture(path)
		view.position = (sim.point(building) + Vector2(0.5, 0.5)) * TILE_SIZE
		view.offset = Vector2(0, -view.texture.get_height() / 2.0 + 15)
		var size := 0.7 if building.kind == "base" else (0.8 if building.kind == "house" else 1.0)
		if building.kind == "well": size = 0.7
		view.scale = Vector2.ONE * size
		view.modulate = Color(0.85, 0.9, 0.85) if building.team == -1 else Color.WHITE
		if building.hp < building.max_hp * 0.3: view.modulate = Color(1.0, 0.65, 0.6)
		view.set_meta("kind", building.kind)
		view.set_meta("team", building.team)
	for id in building_views.keys():
		if not ids.has(id):
			var view: Sprite2D = building_views[id]
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
		view.position = (sim.point(chest) + Vector2(0.5, 0.5)) * TILE_SIZE
		view.offset = Vector2(0, -22)
	for id in treasure_views.keys():
		if not ids.has(id):
			treasure_views[id].queue_free()
			treasure_views.erase(id)
