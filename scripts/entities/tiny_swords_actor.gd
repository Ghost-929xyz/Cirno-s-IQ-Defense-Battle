extends Node2D
const Art = preload("res://scripts/data/tiny_swords_art.gd")
var sprite: AnimatedSprite2D
var last_position := Vector2.INF
var facing := Vector2.RIGHT
var last_cooldown := 0.0
var attack_remaining := 0.0
var current_family := ""
var current_team := -10
var dying := false

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0, -32)
	add_child(sprite)

func sync(unit: Dictionary, sim, delta: float, paused: bool) -> void:
	visible = int(unit.home) == -1
	var next_position: Vector2 = (sim.point(unit) + Vector2(0.5, 0.5)) * 64
	var motion := Vector2.ZERO if not last_position.is_finite() else next_position - last_position
	position = next_position
	last_position = next_position
	if motion.length_squared() > 0.01: facing = motion.normalized()
	var target: Dictionary = sim.entity(int(unit.target))
	var working: bool = unit.order == "repair" and not target.is_empty() and sim.point(unit).distance_to(sim.point(target)) <= 1.5
	var family: String = Art.family(unit.kind, int(unit.team), working)
	if current_family != family or current_team != int(unit.team):
		current_family = family
		current_team = int(unit.team)
		sprite.sprite_frames = Art.troop_frames(family, current_team)
		sprite.play("idle")
	var attack_started: bool = float(unit.cooldown) > last_cooldown + 0.001
	last_cooldown = float(unit.cooldown)
	if not paused: attack_remaining = maxf(0, attack_remaining - delta)
	if attack_started:
		attack_remaining = minf(0.5, float(unit.cooldown))
		for shot in sim.shots:
			if int(shot.get("attacker_id", -1)) == int(unit.id):
				facing = Vector2(shot.tx - shot.x, shot.ty - shot.y).normalized()
	sprite.flip_h = facing.x < -0.1
	sprite.modulate = Color(0.6, 0.95, 1.2) if "ice_archer" in str(unit.kind) else Color.WHITE
	if unit.frozen > 0: sprite.modulate = Color(0.5, 0.9, 1.3)
	if paused or unit.frozen > 0 or not visible:
		sprite.pause()
		return
	var animation := "idle"
	if attack_remaining > 0 or working:
		animation = "attack_side"
		if absf(facing.y) > absf(facing.x): animation = "attack_up" if facing.y < 0 else "attack_down"
	elif motion.length_squared() > 0.01: animation = "run"
	if attack_started and sprite.animation == animation: sprite.stop()
	sprite.play(animation)
	# Attack sheets finish within the unit's real attack interval.
	sprite.speed_scale = maxf(1, 0.5 / maxf(0.1, attack_remaining)) if attack_started else sprite.speed_scale
	if animation in ["idle", "run"] or working: sprite.speed_scale = 1.0

func die() -> void:
	if dying: return
	dying = true
	if not visible:
		queue_free()
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	Art.add_row(frames, Art.texture("Factions/Knights/Troops/Dead/Dead.png"), "death", 0, 7, 12, false, 128)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, -24)
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1
	sprite.play("death")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_callback(queue_free)
