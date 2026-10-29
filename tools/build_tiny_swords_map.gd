extends SceneTree
## Rebuild the editable TileSet and TileMapLayer scene from the original atlas.
const Art = preload("res://scripts/data/tiny_swords_art.gd")
const Simulation = preload("res://scripts/game/rts_simulation.gd")
const Battlefield = preload("res://scripts/data/rts_battlefield.gd")
const SIZE := 64
var tiles := TileSet.new()
var map := Node2D.new()

func _initialize() -> void:
	build.call_deferred()

func atlas(id: int, path: String, region: Vector2i, terrain: String, walkable: bool) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = Art.texture(path)
	source.texture_region_size = region
	tiles.add_source(source, id)
	for y in source.texture.get_height() / region.y:
		for x in source.texture.get_width() / region.x:
			var cell := Vector2i(x, y)
			source.create_tile(cell)
			var data := source.get_tile_data(cell, 0)
			data.set_custom_data("terrain", terrain)
			data.set_custom_data("walkable", walkable)
	return source

func layer(name_text: String, order: int) -> TileMapLayer:
	var result := TileMapLayer.new()
	result.name = name_text
	result.tile_set = tiles
	result.z_index = order
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.add_child(result)
	result.owner = map
	return result

func nine_patch(cell: Vector2i, filled: Dictionary) -> Vector2i:
	var left: bool = filled.has(cell + Vector2i.LEFT)
	var right: bool = filled.has(cell + Vector2i.RIGHT)
	var up: bool = filled.has(cell + Vector2i.UP)
	var down: bool = filled.has(cell + Vector2i.DOWN)
	var x := (1 if left and right else (0 if right else 2))
	var y := (1 if up and down else (0 if down else 2))
	if not left and not right: x = 3
	if not up and not down: y = 3
	return Vector2i(x, y)

func setup_terrain_painting(source: TileSetAtlasSource) -> void:
	tiles.add_terrain_set()
	tiles.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	for t in 2:
		tiles.add_terrain(0)
		tiles.set_terrain_name(0, t, "Grass" if t == 0 else "Sand path")
		tiles.set_terrain_color(0, t, Color("75a44e") if t == 0 else Color("e3c88b"))
		for y in 4:
			for x in 4:
				var data := source.get_tile_data(Vector2i(x + t * 5, y), 0)
				data.terrain_set = 0
				data.terrain = t
				data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, t if x in [1, 2] else -1)
				data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, t if x in [0, 1] else -1)
				data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, t if y in [1, 2] else -1)
				data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, t if y in [0, 1] else -1)

func build() -> void:
	tiles.tile_size = Vector2i(SIZE, SIZE)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "terrain")
	tiles.set_custom_data_layer_type(0, TYPE_STRING)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(1, "walkable")
	tiles.set_custom_data_layer_type(1, TYPE_BOOL)
	atlas(0, "Terrain/Water/Water.png", Vector2i(64, 64), "water", false)
	var ground := atlas(1, "Terrain/Ground/Tilemap_Flat.png", Vector2i(64, 64), "ground", true)
	setup_terrain_painting(ground)
	atlas(2, "Terrain/Ground/Tilemap_Elevation.png", Vector2i(64, 64), "cliff", false)
	atlas(3, "Terrain/Bridge/Bridge_All.png", Vector2i(64, 64), "bridge", true)
	# Animated atlas tiles need reserved frame areas instead of overlapping tiles.
	var foam := TileSetAtlasSource.new()
	foam.texture = Art.texture("Terrain/Water/Foam/Foam.png")
	foam.texture_region_size = Vector2i(192, 192)
	tiles.add_source(foam, 4)
	foam.create_tile(Vector2i.ZERO)
	foam.set_tile_animation_columns(Vector2i.ZERO, 8)
	foam.set_tile_animation_frames_count(Vector2i.ZERO, 8)
	foam.set_tile_animation_speed(Vector2i.ZERO, 6)
	var tree := TileSetAtlasSource.new()
	tree.texture = Art.texture("Resources/Trees/Tree.png")
	tree.texture_region_size = Vector2i(192, 192)
	tiles.add_source(tree, 5)
	tree.create_tile(Vector2i.ZERO)
	tree.set_tile_animation_columns(Vector2i.ZERO, 4)
	tree.set_tile_animation_frames_count(Vector2i.ZERO, 4)
	tree.set_tile_animation_speed(Vector2i.ZERO, 5)
	tree.get_tile_data(Vector2i.ZERO, 0).texture_origin = Vector2i(0, -64)
	tree.get_tile_data(Vector2i.ZERO, 0).set_custom_data("terrain", "tree")
	tree.get_tile_data(Vector2i.ZERO, 0).set_custom_data("walkable", false)
	for i in [1, 5, 10, 12, 15]:
		var source := atlas(10 + i, "Deco/%02d.png" % i, Vector2i(64, 64), "decoration", true)
		if source.get_tiles_count() == 0: push_error("Invalid decoration atlas")
	# Separate ice metadata from the elevation proxy used to draw it.
	var ice := atlas(30, "Terrain/Ground/Tilemap_Elevation.png", Vector2i(64, 64), "ice_bridge", true)
	ice.get_tile_data(Vector2i(1, 1), 0).modulate = Color(0.8, 1.2, 1.5)
	var walls := atlas(31, "Terrain/Ground/Tilemap_Elevation.png", Vector2i(64, 64), "ice_wall", false)
	walls.get_tile_data(Vector2i(3, 0), 0).modulate = Color(0.7, 1.15, 1.5)
	DirAccess.make_dir_recursive_absolute("res://resources/tilesets")
	DirAccess.make_dir_recursive_absolute("res://scenes/maps")
	var error := ResourceSaver.save(tiles, "res://resources/tilesets/tiny_swords.tres")
	if error != OK:
		push_error("TileSet save failed")
		quit(1)
		return
	tiles.take_over_path("res://resources/tilesets/tiny_swords.tres")
	map.name = "FogLakeTileMap"
	map.set_script(load("res://scripts/game/tiny_swords_map.gd"))
	var water := layer("Water", 0)
	var shoreline := layer("ShoreFoam", 1)
	var grass := layer("Ground", 2)
	layer("Paths", 3) # Kept empty for scene compatibility.
	var crossings := layer("Crossings", 4)
	var decor := layer("Decorations", 4)
	var tree_layer := layer("Trees", 5)
	layer("Ice", 6)
	layer("IceWalls", 7)
	var sim := Simulation.new()
	var land_cells: Dictionary = {}
	var path_cells: Dictionary = Battlefield.road_cells()
	for y in Simulation.HEIGHT:
		for x in Simulation.WIDTH:
			var cell := Vector2i(x, y)
			water.set_cell(cell, 0, Vector2i.ZERO)
			var crossing := Battlefield.crossing(cell) and Vector2(cell).distance_to(Battlefield.CENTRAL_BASE) > 7
			if not sim.water(cell) and not crossing: land_cells[cell] = true
			if crossing: crossings.set_cell(cell, 3, Vector2i(x - Battlefield.river_center(y) + 1, 0))
	for cell in land_cells: grass.set_cell(cell, 1, nine_patch(cell, land_cells))
	# The opaque center of the foam sheet belongs UNDER land, with only its
	# outer ripples exposed over water. Centering on water creates white squares.
	for cell in land_cells:
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + direction
			if sim.inside(neighbor) and not land_cells.has(neighbor) and crossings.get_cell_source_id(neighbor) == -1:
				shoreline.set_cell(cell, 4, Vector2i.ZERO)
				break
	var landmarks: Array = Battlefield.BASE_SITES + Battlefield.HOUSES + Battlefield.CAMPS + Battlefield.CHESTS
	var tree_cells: Array[Vector2i] = []
	for cell in land_cells:
		if path_cells.has(cell): continue
		var clear := true
		for site in landmarks:
			if Vector2(cell).distance_to(site) < 3.2: clear = false
		if not clear: continue
		# Deterministic groves flank roads while landmark clearings stay readable.
		var grove: bool = (cell.x < 17 or cell.x > 61 or cell.y < 7 or cell.y > 44)
		var plant_tree: bool = grove and (cell.x * 73 + cell.y * 97 + cell.x * cell.y * 3) % 13 == 0
		for planted in tree_cells:
			if Vector2(cell).distance_to(Vector2(planted)) < 2.5: plant_tree = false
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if path_cells.has(cell + offset): plant_tree = false
		if plant_tree:
			tree_layer.set_cell(cell, 5, Vector2i.ZERO)
			tree_cells.append(cell)
		elif (cell.x * 17 + cell.y * 31) % 19 == 0:
			decor.set_cell(cell, [11, 15, 20, 22, 25][(cell.x + cell.y) % 5], Vector2i.ZERO)
	var actors := Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	actors.z_index = 8
	map.add_child(actors)
	actors.owner = map
	var packed := PackedScene.new()
	packed.pack(map)
	error = ResourceSaver.save(packed, "res://scenes/maps/fog_lake_tiles.tscn")
	map.free()
	print("TINY_MAP_BUILT tiles=", Simulation.WIDTH * Simulation.HEIGHT, " result=", error)
	quit(0 if error == OK else 1)
