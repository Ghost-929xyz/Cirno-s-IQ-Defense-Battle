extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Art = preload("res://scripts/data/tiny_swords_art.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func run() -> void:
	var game = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var map = game.tile_map
	check(map.get_node("Ground") is TileMapLayer, "Real editable TileMapLayer ground")
	check(map.water.get_used_cells().size() == 1000, "Full map water base")
	check(map.ground.tile_set.resource_path == "res://resources/tilesets/tiny_swords.tres", "Saved reusable TileSet")
	check(map.ground.tile_set.get_terrains_count(0) == 2, "Grass and sand terrain painting sets")
	var original = Sim.new()
	var matching := true
	for y in Sim.HEIGHT:
		for x in Sim.WIDTH:
			if original.water(Vector2i(x, y)) != game.sim.water(Vector2i(x, y)): matching = false
	check(matching, "All painted cells match the existing gameplay layout")
	check(map.crossings.get_used_cells().size() == 12 and game.sim.walkable(Vector2i(20, 6)), "Wooden bridges preserve crossing routes")
	var foam_on_land := true
	for cell in map.get_node("ShoreFoam").get_used_cells():
		if map.ground.get_cell_source_id(cell) == -1: foam_on_land = false
	check(foam_on_land, "Foam centers are hidden under land")
	game.pick_card("supplies")
	game.pick_card("mana")
	game.sim.choose_base(1)
	map.sync(game.sim, 0.05, false)
	check(map.unit_views.size() == game.sim.units.size(), "Every unit has an animated view")
	check(map.building_views.size() == game.sim.buildings.size(), "Every building has a texture")
	game.select_all()
	game.contextual_order(Vector2(27, 12))
	check(game.sim.living(0)[0].order == "chest", "Island reward beside a building remains clickable")
	var u: Dictionary = game.sim.living(0)[0]
	var view = map.unit_views[int(u.id)]
	check(view.sprite is AnimatedSprite2D and view.sprite.animation == "idle", "Initial troop idle animation")
	game.sim.set_point(u, game.sim.point(u) + Vector2.LEFT)
	map.sync(game.sim, 0.05, false)
	check(view.sprite.animation == "run" and view.sprite.flip_h, "Movement selects run and left-facing orientation")
	game.sim.set_point(u, Vector2(7, 12))
	var enemy: Dictionary = game.sim.add_unit("swordsman", 1, Vector2(8, 12))
	game.sim.hit(u, enemy, 1, false)
	u.cooldown = 0.25
	map.sync(game.sim, 0.05, false)
	check(view.sprite.animation == "attack_side", "Combat event selects directional attack")
	map.sync(game.sim, 0.05, true)
	check(not view.sprite.is_playing(), "Pause freezes unit animation")
	var base: Dictionary = game.sim.buildings[0]
	game.sim.garrison(u, base)
	map.sync(game.sim, 0.05, false)
	check(not view.visible, "Garrison hides field sprite")
	game.sim.evacuate(base.id)
	map.sync(game.sim, 0.05, false)
	check(view.visible, "Evacuating restores field sprite")
	check(game.sim.cast("bridge", Vector2(20, 12)), "Bridge spell succeeds")
	map.sync(game.sim, 0.05, false)
	check(map.ice.get_cell_source_id(Vector2i(20, 12)) == 30 and game.sim.walkable(Vector2i(20, 12)), "Ice tiles and traversability update together")
	check(map.ice.get_cell_tile_data(Vector2i(20, 12)).get_custom_data("walkable"), "Ice tile has correct editor metadata")
	check(game.sim.cast("wall", Vector2(10, 12)), "Wall spell succeeds")
	map.sync(game.sim, 0.05, false)
	check(map.ice_walls.get_cell_source_id(Vector2i(10, 12)) == 31 and not game.sim.walkable(Vector2i(10, 12)), "Wall tile blocks the same logical cell")
	game.sim.step(26)
	map.sync(game.sim, 0.05, false)
	check(map.ice_walls.get_used_cells().is_empty() and game.sim.walkable(Vector2i(10, 12)), "Expired wall clears both map and navigation")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.sim.snapshot()))
	game.sim.bridges.clear()
	game.sim.rebuild_navigation()
	map.sync(game.sim, 0.05, false)
	game.sim.restore(saved)
	map.sync(game.sim, 0.05, false)
	check(map.ice.get_cell_source_id(Vector2i(20, 12)) == 30, "Loading restores frozen terrain visuals")
	# Editor changes are consumed by gameplay, not merely painted on top.
	map.ground.erase_cell(Vector2i(3, 3))
	game.sim.configure_terrain(map.terrain_water_cells())
	check(not game.sim.walkable(Vector2i(3, 3)), "Erasing ground in TileMap changes traversability")
	var valid_frames := true
	for family in ["Warrior", "Archer", "Pawn", "Torch"]:
		for team in [0, 1, 2]:
			var frames := Art.troop_frames(family, team)
			for animation in frames.get_animation_names():
				for index in frames.get_frame_count(animation):
					var frame := frames.get_frame_texture(animation, index) as AtlasTexture
					if not Rect2(Vector2.ZERO, frame.atlas.get_size()).encloses(frame.region): valid_frames = false
	check(valid_frames, "All animation atlas regions are within source sheets")
	var exported_units: Dictionary = game.sim.catalog
	for kind in exported_units:
		check(Art.portrait(kind) != null, "Portrait mapping for " + kind)
	game.queue_free()
	await process_frame
	print("TINY_SWORDS_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
