extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func clear_sim():
	var s = Sim.new()
	s.configure_terrain([])
	s.phase = "prep"
	s.timer = 10000
	s.gold = 10000
	return s

func no_overlap(s) -> bool:
	var cells := {}
	for u in s.units:
		if u.hp <= 0 or u.home != -1: continue
		var cell := Vector2i(s.point(u).round())
		if cells.has(cell) or not s.unit_position_clear(s.point(u), u.kind, u.id): return false
		cells[cell] = true
	return true

func run() -> void:
	var s = clear_sim()
	s.add_building("base", 0, Vector2(5, 5))
	var soldier: Dictionary = s.add_unit("swordsman", 0, Vector2(7, 5))
	check(s.unit_unlocked("swordsman") and s.unit_unlocked("archer"), "Initial basic units are available")
	check(s.catalog.keys().filter(func(k): return s.unit_unlocked(k)).size() == 2, "Only two troop types at the start")
	check(not s.train_unit("cavalry") and not s.train_unit("assassin"), "Cannot bypass academy by calling recruitment")
	var academy: Dictionary = s.add_building("academy", 0, Vector2(10, 10), false)
	check(not s.unit_unlocked("cavalry") and not s.research_unit("guard"), "An unfinished academy grants no unlocks")
	s.set_point(soldier, Vector2(10, 9))
	s.command([soldier.id], "repair", s.point(academy), academy.id)
	s.step_unit(soldier, 50)
	check(academy.complete and s.has_academy(), "Workers complete the academy through normal construction")
	check(s.unit_unlocked("cavalry") and s.unit_unlocked("assassin") and not s.unit_unlocked("cataphract"), "Academy unlocks only base mounted and special troops")
	check(not s.research_unit("cataphract"), "A child branch requires its parent")
	var gold_before: float = s.gold
	check(s.research_unit("lancer") and s.gold == gold_before - s.branch_cost("lancer"), "Research charges exactly one branch cost")
	gold_before = s.gold
	check(not s.research_unit("ranger") and not s.research_unit("scout") and s.gold == gold_before, "The unchosen cavalry route and its descendants are closed without charging")
	check(s.research_unit("cataphract") and s.train_unit("cataphract"), "Selected advanced cavalry can be recruited")
	check(not s.research_unit("cataphract"), "Research cannot be purchased twice")
	check(s.research_unit("guard") and s.research_unit("paladin") and not s.research_unit("heavy_infantry"), "Infantry route preserves its prerequisite and fork")
	check(s.research_unit("ice_archer") and s.research_unit("ice_archer_plus") and not s.research_unit("sniper"), "Ranged fork is mutually exclusive")
	check(s.research_unit("hermit") and s.research_unit("hermit_blink") and not s.research_unit("hermit_dodge") and not s.research_unit("berserker_plus"), "Special routes enforce both levels of branching")
	var restored = Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and restored.unlocked_units == s.unlocked_units and restored.branch_conflict("ranger"), "Research choices and closed routes survive saving")
	academy.hp = 0
	check(not s.unit_unlocked("cavalry") and not s.train_unit("assassin") and s.unit_unlocked("cataphract"), "Destroyed academy stops basic specialist recruitment and preserves completed research")
	s = clear_sim()
	soldier = s.add_unit("swordsman", 0, Vector2(5, 5))
	s.credit_kill(soldier, 240)
	check(soldier.rank == 0 and soldier.kill_value == 240, "First threshold is strict and cumulative")
	s.credit_kill(soldier, 1)
	check(soldier.rank == 1 and soldier.attack == 36 and soldier.max_hp == 100 and soldier.kill_value == 241, "First promotion changes only attack")
	s.credit_kill(soldier, 239)
	check(soldier.rank == 1 and soldier.kill_value == 480, "Second threshold is strictly greater than six prices")
	s.credit_kill(soldier, 1)
	check(soldier.rank == 2 and soldier.attack == 36 and is_equal_approx(soldier.max_hp, 120) and soldier.hp == 100, "Second promotion adds maximum health without an instant heal")
	soldier.hp = 50
	s.step_unit(soldier, 1)
	check(is_equal_approx(soldier.hp, 52.4), "Top rank regenerates two percent of maximum HP each second")
	s.credit_kill(soldier, 9999)
	check(soldier.rank == 2 and soldier.attack == 36 and is_equal_approx(soldier.max_hp, 120), "Promotion stats are never applied twice")
	var foe: Dictionary = s.add_unit("archer", 1, Vector2(7, 5))
	var experience: float = soldier.kill_value
	s.hit(soldier, foe, 10000, false)
	check(soldier.kill_value == experience + s.catalog.archer.cost, "A killed enemy grants exactly its price in experience")
	foe = s.add_unit("swordsman", 2, Vector2(7, 6))
	experience = soldier.kill_value
	s.hit(soldier, foe, 10000, false)
	check(soldier.kill_value == experience + s.catalog.swordsman.cost, "Wildlife kills use the same experience rule")
	s = clear_sim()
	for i in 12: s.add_unit("cavalry" if i % 4 == 0 else "swordsman", 0, Vector2(8, 8))
	s.add_building("base", 0, Vector2(40, 25))
	check(no_overlap(s), "Spawns reserve distinct cells and body footprints")
	check(Rules.body_radius("cavalry") > Rules.body_radius("swordsman") and Rules.visual_scale("cavalry") > Rules.visual_scale("swordsman"), "Mounted units have larger visuals and bodies")
	var ids: Array = s.living(0).map(func(u): return u.id)
	s.command(ids, "move", Vector2(20, 15))
	var goals := {}
	for u in s.units: goals[Vector2i(Vector2(u.goal_x, u.goal_y).round())] = true
	check(goals.size() == ids.size(), "Group move assigns unique reserved destination cells")
	var separated := true
	for i in 500:
		s.step(0.05)
		separated = separated and no_overlap(s)
	check(separated, "Moving formations never overlap, including mounted bodies")
	var arrived: int = s.units.filter(func(u): return s.point(u).distance_to(Vector2(u.goal_x, u.goal_y)) < 0.4).size()
	check(arrived == 12, "Crowded formations reach every assigned position: %d/12" % arrived)
	var saved: Dictionary = s.snapshot()
	for u in saved.units:
		u.x = 10
		u.y = 10
	restored = Sim.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))) and no_overlap(restored), "Legacy stacked units are separated when restoring")
	s = clear_sim()
	var base: Dictionary = s.add_building("base", 0, Vector2(5, 5))
	for i in 10: s.garrison(s.add_unit("swordsman", 0, Vector2(5, 5)), base)
	s.evacuate(base.id)
	check(no_overlap(s) and s.occupants(base.id).is_empty(), "Evacuation reserves separate exits for every garrisoned unit")
	var game = load("res://scenes/expedition.tscn").instantiate()
	game.random_map_enabled = false
	root.add_child(game)
	await process_frame
	game.set_process(false)
	check(game.card_buttons.size() == 5 and game.confirm_cards_button.disabled, "Five clickable cards are presented with confirmation disabled")
	game.pick_card("supplies")
	game.pick_card("mana")
	check(game.sim.cards.is_empty() and game.sim.gold == Rules.START_GOLD and not game.confirm_cards_button.disabled, "Previewing choices grants no effects before confirmation")
	game.pick_card("builders")
	check(game.pending_cards.size() == 2 and not game.pending_cards.has("builders"), "A third card cannot be selected")
	game.pick_card("mana")
	game.pick_card("vitality")
	game.confirm_opening_cards()
	check(game.sim.cards == ["supplies", "vitality"] and game.sim.gold == Rules.START_GOLD + 250 and game.sim.phase == "prep", "Final manual choices are applied before automatic central deployment")
	game.confirm_opening_cards()
	check(game.sim.gold == Rules.START_GOLD + 250, "Confirming again never reapplies rewards")
	game.sim.choose_base(1)
	game.refresh_ui()
	check(game.open_drawer == "recruit" and game.drawers.recruit.visible, "Fixed command area starts visible")
	var fixed_position: Vector2 = game.drawers.recruit.position
	game.toggle_drawer("build")
	game.set_mode("academy")
	check(game.drawers.build.visible and game.drawers.build.position == fixed_position and game.mode == "academy", "Construction uses the shared fixed area and remains visible during placement")
	game.toggle_drawer("research")
	game.filter_roster("特战")
	check(game.research_views["特战"].visible and game.research_buttons.size() == 20 and game.drawers.research.position == fixed_position, "Research tree shares the fixed area and includes every catalogue unit")
	game.filter_roster("骑乘")
	check(not game.train_buttons.cavalry.visible and not game.train_buttons.cataphract.visible, "Locked mounted units are absent from recruitment")
	game.sim.add_building("academy", 0, Vector2(13, 25))
	game.refresh_ui()
	check(game.train_buttons.cavalry.visible and not game.train_buttons.cataphract.visible, "Academy reveals only initial cavalry in the mounted category")
	check(game.army_buttons.swordsman.visible and game.army_buttons.swordsman.text.contains("× 2"), "Army cards display accurate troop counts")
	game.selected.clear()
	game.select_all()
	check(game.selected.size() == 2, "First A selects all troops of one type")
	game.select_all()
	check(game.selected.size() == 3, "Second A selects all field troops")
	game.select_army_kind("archer")
	check(game.selected.size() == 1 and game.sim.entity(game.selected[0]).kind == "archer", "Army card selects and locates its troop type")
	game.select_all()
	check(game.selected.size() == 1, "Changing selection resets the two-stage A sequence")
	game.select_all()
	check(game.selected.size() == 3, "Second A expands the new type selection to the army")
	check(game.edge_pan_direction(Vector2(1, 200)) == Vector2.LEFT and game.edge_pan_direction(Vector2(1179, 200)) == Vector2.RIGHT, "Horizontal window edges pan the view")
	check(game.edge_pan_direction(Vector2(500, 1)) == Vector2.UP and game.edge_pan_direction(Vector2(500, 659)) == Vector2.DOWN, "Vertical window edges pan the view")
	check(game.edge_pan_direction(Vector2(-1, 100)) == Vector2.ZERO and game.edge_pan_direction(Vector2(500, 300)) == Vector2.ZERO, "Outside-window and central pointers do not scroll")
	game.paused = true
	check(game.edge_pan_direction(Vector2(1, 200)) == Vector2.ZERO, "Paused battle suppresses automatic panning")
	game.paused = false
	var horse: Dictionary = game.sim.add_unit("cavalry", 0, Vector2(13, 24))
	game.tile_map.sync(game.sim, 0.05, false)
	var view = game.tile_map.unit_views[int(horse.id)]
	check(is_equal_approx(view.sprite.scale.x, 1.4) and game.unit_hit(horse, game.sim.point(horse) + Vector2(1, -0.56)), "Mounted render scale and pointer hit area both increase")
	if "--visual" in OS.get_cmdline_user_args():
		game.toggle_drawer("research")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/feedback-research.png")
	game.queue_free()
	await process_frame
	print("DOCUMENT_FEEDBACK_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
