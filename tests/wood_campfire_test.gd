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
func fresh():
	var s = Sim.new()
	s.configure_terrain([])
	s.register_trees([Vector2i(20,8)])
	s.resource_sites.append({"id":s.allocate_id(),"kind":"vision_tower","team":-1,"x":65,"y":40,"capture":0.0,"capturing_team":-1,"discovered":false})
	s.phase = "prep"
	s.timer = 99999
	return s
func tick(s, u: Dictionary, count := 1) -> void:
	for i in count:
		s.elapsed += 0.05
		s.update_visibility()
		s.step_unit(u,0.05)
func run() -> void:
	var s = fresh()
	var tree: Dictionary = s.tree_sites[0]
	var u: Dictionary = s.add_unit("swordsman",0,Vector2(16,10))
	check(not s.walkable(Vector2i(20,10)) and s.entity(tree.id) == tree,"Standing trees are targetable obstacles")
	s.command([u.id],"chop",s.point(tree),tree.id)
	tick(s,u,70)
	check(tree.hp > 0 and tree.hp < tree.max_hp and s.wood == 0,"Wood is not awarded until the tree is felled")
	var restored = Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))),"Partially chopped tree restores")
	u = restored.units[0]
	var remaining: float = restored.tree_sites[0].hp
	check(remaining == tree.hp and u.order == "chop" and u.target == tree.id,"Tree progress and the worker's order survive loading")
	s = restored
	tree = s.tree_sites[0]
	tick(s,u,200)
	check(tree.hp == 0 and s.wood == Rules.TREE_WOOD and u.order == "idle","Felling awards wood exactly once and frees the worker")
	check(s.walkable(Vector2i(20,10)),"A felled tree releases its trunk collision")
	s.command([u.id],"chop",s.point(tree),tree.id)
	tick(s,u,10)
	check(s.wood == Rules.TREE_WOOD,"A stump cannot be harvested repeatedly")
	# Two workers share the tree's progress without duplicating its reward.
	var cooperative = fresh()
	var first: Dictionary = cooperative.add_unit("swordsman",0,Vector2(19,10))
	var second: Dictionary = cooperative.add_unit("swordsman",0,Vector2(21,10))
	var source: Dictionary = cooperative.tree_sites[0]
	cooperative.command([first.id,second.id],"chop",cooperative.point(source),source.id)
	for i in 65:
		tick(cooperative,first)
		cooperative.step_unit(second,0.05)
	check(source.hp == 0 and cooperative.wood == Rules.TREE_WOOD,"Cooperative chopping finishes faster and grants one reward")
	# Fire placement reserves wood and collision before walking to the site.
	s.update_visibility()
	var fire_pos := Vector2(22,10)
	check(s.campfire_error(fire_pos,[u.id]).is_empty(),"A visible free land cell accepts a campfire")
	check(s.place_campfire(fire_pos,[u.id]) and s.wood == 0 and s.campfires.size() == 1,"Campfire placement consumes twenty wood once")
	var fire: Dictionary = s.campfires[0]
	check(not fire.complete and s.torch_positions().is_empty() and not s.walkable(Vector2i(fire_pos)),"A fire under construction blocks movement but provides no light")
	check(not s.place_campfire(Vector2(24,10),[u.id]) and s.wood == 0,"Insufficient wood cannot create another campfire")
	tick(s,u,30)
	var planned = Sim.new()
	check(planned.restore(s.snapshot()) and not planned.campfires[0].complete and planned.campfires[0].progress == fire.progress,"Unfinished campfire progress and paid wood survive loading")
	s = planned
	u = s.units[0]
	fire = s.campfires[0]
	tick(s,u,160)
	check(fire.complete and s.torch_positions().has(fire_pos),"Worker walks to the edge and lights the fire")
	check(s.unit_position_clear(s.point(u),u.kind,u.id),"The worker never stands inside the fire")
	s.set_point(u,Vector2(35,10))
	s.update_visibility()
	check(s.is_visible(fire_pos + Vector2(5,0)),"A completed fire retains its own visibility after troops leave")
	check(not s.segment_clear(fire_pos-Vector2(2,0),fire_pos+Vector2(2,0)),"Movement cannot cross a newly built fire")
	var saved: Dictionary = s.snapshot().duplicate(true)
	var loaded = Sim.new()
	check(loaded.restore(saved) and loaded.wood == 0 and loaded.tree_sites[0].hp == 0 and loaded.campfires[0].complete,"Wood, stumps and lit fires all survive loading")
	loaded.wood = 40
	var worker: Dictionary = loaded.units[0]
	loaded.set_point(worker,Vector2(25,24))
	loaded.update_visibility()
	check(not loaded.campfire_error(loaded.point(worker),[worker.id]).is_empty(),"Fire placement rejects a unit's feet")
	var wet: Array[Vector2i] = [Vector2i(23,21)]
	loaded._painted_water[wet[0]] = true
	loaded.rebuild_navigation()
	check(not loaded.campfire_error(Vector2(wet[0]),[worker.id]).is_empty(),"Fire placement rejects water")
	check(not loaded.campfire_error(Vector2(60,20),[worker.id]).is_empty(),"Fire placement rejects unseen ground")
	# A save made before the wood feature retains its configured woodland.
	var old := saved.duplicate(true)
	for key in ["wood","tree_sites","campfires"]: old.erase(key)
	var legacy = fresh()
	check(legacy.restore(old) and legacy.wood == 0 and legacy.campfires.is_empty() and legacy.tree_sites[0].hp == 60,"Old saves gain defaults without losing their standing trees")
	# Seeing a hostile pauses chopping without discarding its target.
	s = fresh()
	u = s.add_unit("swordsman",0,Vector2(19,10))
	tree = s.tree_sites[0]
	s.command([u.id],"chop",s.point(tree),tree.id)
	var foe: Dictionary = s.add_unit("swordsman",1,Vector2(16,10))
	tick(s,u)
	check(u.engaging_target == foe.id and u.order == "chop" and tree.hp == tree.max_hp,"Workers prioritize combat and retain their tree target")
	foe.hp = 0
	tick(s,u,220)
	check(s.wood == Rules.TREE_WOOD,"Chopping resumes after combat")
	# UI: select a visible tree and dispatch an idle worker without changing terrain.
	var game = load("res://scenes/expedition.tscn").instantiate()
	game.random_map_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.sim.choose_card("supplies")
	game.sim.choose_card("mana")
	game.show_phase_overlay()
	var pick: Dictionary = game.sim.tree_sites[0]
	game.sim.reveal_circle(game.sim.point(pick),5)
	game.center_camera(game.sim.point(pick))
	game.tile_map.sync(game.sim,0,true)
	var anchor := Vector2i(pick.anchor_x,pick.anchor_y)
	var view: Sprite2D = game.tile_map.tree_views[anchor]
	var at := view.get_global_transform_with_canvas() * view.offset
	game.select_area(at,at)
	game.update_building_feedback()
	check(game.selected_prop == pick.id and view.material.get_shader_parameter("outline_amount") == 1.0,"Tree selection uses the shared building highlight")
	game.set_mode("chop")
	check(game.sim.living(0).any(func(unit): return unit.order == "chop" and unit.target == pick.id),"Selected tree dispatches an idle worker using T")
	pick.hp = 0
	game.sim.wood = 20
	game.sim.rebuild_navigation()
	game.tile_map.sync(game.sim,0,true)
	game.refresh_ui()
	check(view.frame == 8 and game.resource_labels.wood.text == "20","Felled tree displays its stump and wood appears in the HUD")
	game.queue_free()
	await process_frame
	# The tutorial teaches both new actions through the same live simulation.
	var training = load("res://scenes/tutorial.tscn").instantiate()
	root.add_child(training)
	training.set_process(false)
	training.sim.choose_card("supplies")
	training.sim.choose_card("mana")
	training.lesson = 27
	training.enter_lesson()
	var teaching_tree: Dictionary = training.sim.entity(training.sim.training_tree_id)
	var ids: Array = training.sim.living(0).map(func(unit): return unit.id)
	training.sim.command(ids,"chop",training.sim.point(teaching_tree),int(teaching_tree.id))
	for i in 900:
		training.sim.step(0.05)
		if training.completed(): break
	check(training.completed() and training.sim.wood >= Rules.TREE_WOOD,"The chopping tutorial can be completed by actually harvesting its tree")
	training.next_lesson()
	var builders: Array = training.sim.living(0)
	var center: Vector2 = training.sim.point(builders[0])
	var placed := false
	for y in range(-3,4):
		for x in range(-3,4):
			var pos := center + Vector2(x,y)
			if training.sim.campfire_error(pos,ids).is_empty():
				placed = training.sim.place_campfire(pos,ids)
				break
		if placed: break
	for i in 240:
		training.sim.step(0.05)
		if training.completed(): break
	check(placed and training.completed(),"The campfire tutorial completes through real placement and lighting")
	training.queue_free()
	await process_frame
	# The approved art keeps the original alpha and yellow sand exact.
	var original := load("res://assets/tiny_swords/Terrain/Ground/Tilemap_Flat.png").get_image() as Image
	var mist := load("res://assets/terrain/mist_grass_tiles.png").get_image() as Image
	var consistent := original.get_size() == mist.get_size()
	for y in original.get_height():
		for x in original.get_width():
			consistent = consistent and original.get_pixel(x,y).a == mist.get_pixel(x,y).a
			if x >= 320: consistent = consistent and original.get_pixel(x,y) == mist.get_pixel(x,y)
	check(consistent and mist.get_pixel(90,90).b > mist.get_pixel(90,90).r,"Silver-blue grass retains exact tile transparency and original sand")
	print("WOOD_CAMPFIRE_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
