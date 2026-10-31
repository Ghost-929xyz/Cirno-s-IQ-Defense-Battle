extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Geometry = preload("res://scripts/data/tree_geometry.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var game = load("res://scenes/expedition.tscn").instantiate()
	game.random_map_enabled = false
	root.add_child(game)
	game.paused = true
	game.sim.choose_card("supplies")
	game.sim.choose_card("mana")
	game.show_phase_overlay()
	var map = game.tile_map
	map.sync(game.sim,0,true)
	var anchors: Array[Vector2i] = map.trees.get_used_cells()
	check(not anchors.is_empty() and map.tree_views.size() == anchors.size(),"Every painted tree has a sorted visual")
	var all_clear := true
	for anchor in anchors:
		var trunk := Geometry.trunk_cell(anchor)
		var view: Sprite2D = map.tree_views[anchor]
		all_clear = all_clear and not game.sim.walkable(trunk) and not game.sim.position_clear(Vector2(trunk))
		check(view.get_parent() == map.actors and view.z_index == 0,"Tree shares troop and building Y sorting")
		# Derive original tile bounds from its real atlas data, not the helper offset.
		var tile_data: TileData = map.trees.get_cell_tile_data(anchor)
		var old_center: Vector2 = map.trees.map_to_local(anchor) - Vector2(tile_data.texture_origin)
		check(view.position + view.offset == old_center,"Sorted visual preserves the painted tree position")
	check(all_clear,"All visible trunks block the actual navigation cell")
	check(not map.trees.visible,"Anchor tiles do not duplicate the sorted tree sprites")
	# A tree above the clearing may extend into it; its visible trunk stays solid.
	var s = Sim.new()
	var central_trunk := Vector2i(40,19)
	s.configure_terrain([], [central_trunk])
	check(not s.walkable(central_trunk),"Camp clearing never deletes a visible trunk collision")
	for troop in ["swordsman","cavalry"]:
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(-1,1),Vector2(1,-1),Vector2(1,1)]:
			s = Sim.new()
			var trunk := Vector2i(20,22)
			s.configure_terrain([], [trunk])
			s.phase = "prep"
			var u: Dictionary = s.add_unit(troop,0,Vector2(trunk) + direction*4)
			var destination: Vector2 = Vector2(trunk) - direction*4
			var safe := true
			for i in 200:
				var before: Vector2 = s.point(u)
				s.move_unit(u,destination,0.1 if i%20 else 0.8)
				safe = safe and s.segment_clear(before,s.point(u),Rules.terrain_radius(troop)) and s.unit_position_clear(s.point(u),u.kind,u.id)
			check(safe and s.point(u).distance_to(destination)<0.1,"Infantry and cavalry route around the visible trunk from every direction")
	for seed_value in [1,42,20261013,104729]:
		s = Sim.new()
		s.generate_map(seed_value)
		check(s.generated_layout.trees.all(func(anchor): return not s.walkable(Geometry.trunk_cell(anchor))),"Generated tree trunks match collisions for seed %s" % seed_value)
		s.choose_card("supplies")
		s.choose_card("mana")
		var u: Dictionary = s.living(0)[0]
		var first_trunk := Geometry.trunk_cell(s.generated_layout.trees[0])
		var saved: Dictionary = s.snapshot().duplicate(true)
		saved.units[0].x = first_trunk.x
		saved.units[0].y = first_trunk.y
		var restored = Sim.new()
		check(restored.restore(saved) and restored.unit_position_clear(restored.point(restored.units[0]),restored.units[0].kind,restored.units[0].id),"Old saves relocate units out of corrected tree trunks")
	game.queue_free()
	await process_frame
	print("TREE_COLLISION_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
