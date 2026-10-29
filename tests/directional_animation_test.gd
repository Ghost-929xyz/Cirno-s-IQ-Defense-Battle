extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
const Actor = preload("res://scripts/entities/tiny_swords_actor.gd")
const Art = preload("res://scripts/data/tiny_swords_art.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var sim = Sim.new()
	sim.configure_terrain([])
	sim.phase = "prep"
	var directions := {"left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP, "down": Vector2.DOWN}
	for kind in sim.catalog:
		sim.units.clear()
		var unit: Dictionary = sim.add_unit(kind, 0, Vector2(10, 10))
		var actor = Actor.new()
		root.add_child(actor)
		actor.sync(unit, sim, 1.0 / 60.0, false)
		for direction in directions:
			unit.order = "move"
			sim.set_point(unit, sim.point(unit) + directions[direction] * 0.1)
			actor.sync(unit, sim, 1.0 / 60.0, false)
			check(actor.sprite.animation == "run_" + direction and actor.sprite.flip_h == (direction == "left"), kind + " chooses " + direction)
			check(actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation) == 6, kind + " has a six-frame gait")
			actor.sprite.set_frame_and_progress(2, 0.4)
			for tick in 3: actor.sync(unit, sim, 1.0 / 60.0, false)
			check(actor.sprite.animation == "run_" + direction and actor.sprite.frame == 2, kind + " preserves walking through zero-displacement render frames")
			unit.order = "stop"
			actor.sync(unit, sim, 1.0 / 60.0, false)
			check(actor.sprite.animation == "idle_" + direction, kind + " stops facing the last travel direction")
		unit.order = "move"
		sim.set_point(unit, sim.point(unit) + Vector2.LEFT * 0.1)
		actor.sync(unit, sim, 0.016, false)
		actor.sprite.set_frame_and_progress(3, 0.25)
		sim.set_point(unit, sim.point(unit) + Vector2.UP * 0.1)
		actor.sync(unit, sim, 0.016, false)
		check(actor.sprite.frame == 3 and is_equal_approx(actor.sprite.frame_progress, 0.25), kind + " keeps stride phase through a turn")
		var normal_speed: float = actor.sprite.speed_scale
		unit.slow_time = 3
		unit.slow = 0.5
		actor.sync(unit, sim, 0.016, false)
		check(is_equal_approx(actor.sprite.speed_scale, normal_speed * 0.5), kind + " slows footsteps with movement")
		actor.sync(unit, sim, 0.016, true)
		check(not actor.sprite.is_playing(), kind + " pauses walking")
		unit.frozen = 1
		actor.sync(unit, sim, 0.016, false)
		check(not actor.sprite.is_playing(), kind + " freezes walking")
		check(actor.cardinal_direction(Vector2(1, 1.05), "right") == "right" and actor.cardinal_direction(Vector2(1.05, 1), "down") == "down", "Diagonal steering does not flicker directions")
		unit.frozen = 0
		unit.order = "attack"
		unit.cooldown = 0.5
		sim.shots = [{"attacker_id": unit.id, "x": unit.x, "y": unit.y, "tx": unit.x, "ty": unit.y - 2}]
		actor.sync(unit, sim, 0.016, false)
		check(actor.sprite.animation == "attack_up" and not actor.sprite.flip_h, kind + " transitions from walking to an upward attack")
		unit.order = "move"
		sim.set_point(unit, sim.point(unit) + Vector2.RIGHT * 0.1)
		actor.sync(unit, sim, 0.016, false)
		check(actor.sprite.animation == "run_right", kind + " movement interrupts a lingering attack animation")
		unit.home = 1
		actor.sync(unit, sim, 0.016, false)
		check(not actor.visible and not actor.sprite.is_playing(), kind + " hides and pauses when garrisoned")
		actor.free()
	for family in ["Warrior", "Archer", "Pawn", "Torch"]:
		for team in [0, 1, 2]:
			var frames := Art.troop_frames(family, team)
			for direction in ["up", "down"]:
				for frame_index in 6:
					var frame := frames.get_frame_texture("run_" + direction, frame_index) as AtlasTexture
					check(Rect2(Vector2.ZERO, frame.atlas.get_size()).encloses(frame.region) and frame.region.has_area(), "Supplemental frame stays in atlas bounds")
	print("DIRECTIONAL_ANIMATION_TEST checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
