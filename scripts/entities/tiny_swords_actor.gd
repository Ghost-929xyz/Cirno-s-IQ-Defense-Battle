extends Node2D
const Art = preload("res://scripts/data/tiny_swords_art.gd")
const Rules = preload("res://scripts/data/rts_rules.gd")
const SelectionShader = preload("res://scripts/effects/rts_building_highlight.gdshader")
var sprite: AnimatedSprite2D
var last_position := Vector2.INF
var facing := Vector2.RIGHT
var facing_direction := "right"
var movement_remaining := 0.0
const MOVEMENT_GRACE := 0.10 # Bridge the 20 Hz simulation steps at higher render rates.
var last_cooldown := 0.0
var attack_remaining := 0.0
var current_family := ""
var current_team := -10
var dying := false
var current_visual_scale := 1.0

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0, -32)
	var feedback := ShaderMaterial.new()
	feedback.shader = SelectionShader
	sprite.material = feedback
	sprite.frame_changed.connect(_update_frame_bounds)
	sprite.frame_changed.connect(_fit_current_frame)
	sprite.animation_changed.connect(_update_frame_bounds)
	add_child(sprite)

func set_selected(value: bool) -> void:
	var feedback := sprite.material as ShaderMaterial
	if feedback == null or dying: return
	var active := value and visible
	feedback.set_shader_parameter("highlight_amount", 0.26 if active else 0.0)
	feedback.set_shader_parameter("outline_amount", 1.0 if active else 0.0)
	feedback.set_shader_parameter("highlight_color", Color("ffe6a8"))
	feedback.set_shader_parameter("outline_width", clampf(1.8 / maxf(sprite.global_scale.x, 0.05), 1.0, 32.0))
	_update_frame_bounds()

func _update_frame_bounds() -> void:
	var feedback := sprite.material as ShaderMaterial
	if feedback == null or sprite.sprite_frames == null: return
	if not sprite.sprite_frames.has_animation(sprite.animation): return
	if sprite.frame >= sprite.sprite_frames.get_frame_count(sprite.animation): return
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var atlas := frame as AtlasTexture
	var bounds := Vector4(0, 0, 1, 1)
	if atlas != null and atlas.atlas != null:
		var size := atlas.atlas.get_size()
		bounds = Vector4(atlas.region.position.x / size.x, atlas.region.position.y / size.y, atlas.region.end.x / size.x, atlas.region.end.y / size.y)
	feedback.set_shader_parameter("frame_bounds", bounds)

func sync(unit: Dictionary, sim, delta: float, paused: bool) -> void:
	visible = int(unit.home) == -1
	current_visual_scale = Rules.visual_scale(unit.kind)
	var next_position: Vector2 = (sim.point(unit) + Vector2(0.5, 0.5)) * 64
	var initialized := last_position.is_finite()
	var motion := next_position - last_position if initialized else Vector2.ZERO
	position = next_position
	last_position = next_position
	var moved := motion.length_squared() > 0.01 and motion.length() < 256.0
	if not paused:
		movement_remaining = maxf(0, movement_remaining - delta)
		if moved:
			movement_remaining = MOVEMENT_GRACE
			facing = motion.normalized()
			facing_direction = cardinal_direction(facing, facing_direction)
	if unit.order in ["stop", "hold"] or (not moved and unit.team == 0 and unit.order == "idle" and int(unit.get("engaging_target", -1)) == -1):
		movement_remaining = 0.0
	var target: Dictionary = sim.entity(int(unit.target))
	var working: bool = int(unit.get("engaging_target", -1)) == -1 and unit.order in ["repair", "chop", "light_fire"] and not target.is_empty() and sim.target_distance(sim.point(unit), target) <= 1.5
	if working:
		movement_remaining = 0.0
		var toward: Vector2 = sim.point(target) - sim.point(unit)
		if toward.length_squared() > 0.001:
			facing = toward.normalized()
			facing_direction = cardinal_direction(facing, facing_direction)
	var family: String = Art.family(unit.kind, int(unit.team), working)
	if current_family != family or current_team != int(unit.team):
		current_family = family
		current_team = int(unit.team)
		sprite.sprite_frames = Art.troop_frames(family, current_team)
		sprite.play("idle")
	var attack_started: bool = initialized and float(unit.cooldown) > last_cooldown + 0.001
	last_cooldown = float(unit.cooldown)
	if not paused: attack_remaining = maxf(0, attack_remaining - delta)
	if attack_started:
		movement_remaining = 0.0
		attack_remaining = minf(0.5, float(unit.cooldown))
		for shot in sim.shots:
			if int(shot.get("attacker_id", -1)) == int(unit.id):
				facing = Vector2(shot.tx - shot.x, shot.ty - shot.y).normalized()
				facing_direction = cardinal_direction(facing)
	sprite.flip_h = facing_direction == "left"
	sprite.modulate = Color(0.6, 0.95, 1.2) if "ice_archer" in str(unit.kind) else Color.WHITE
	if unit.frozen > 0: sprite.modulate = Color(0.5, 0.9, 1.3)
	if paused or unit.frozen > 0 or not visible:
		fit_frame(unit)
		sprite.pause()
		return
	var moving := movement_remaining > 0
	var animation := "idle_" + facing_direction
	if (attack_remaining > 0 and not moving) or working:
		animation = "attack_side"
		if facing_direction in ["up", "down"]: animation = "attack_" + facing_direction
	elif moving: animation = "run_" + facing_direction
	var preserve_stride: bool = str(sprite.animation).begins_with("run_") and animation.begins_with("run_") and sprite.animation != animation
	var stride := (sprite.frame + sprite.frame_progress) / maxf(1, sprite.sprite_frames.get_frame_count(sprite.animation))
	if attack_started and sprite.animation == animation: sprite.stop()
	sprite.play(animation)
	if preserve_stride:
		var frame_position := stride * sprite.sprite_frames.get_frame_count(animation)
		sprite.set_frame_and_progress(int(frame_position), fmod(frame_position, 1.0))
	fit_frame(unit)
	# Attack sheets finish within the unit's real attack interval.
	sprite.speed_scale = maxf(1, 0.5 / maxf(0.1, attack_remaining)) if attack_started else sprite.speed_scale
	if animation.begins_with("idle_") or working: sprite.speed_scale = 1.0
	elif animation.begins_with("run_"):
		var pace := float(sim.catalog[unit.kind].move_speed) / 1.9
		if unit.slow_time > 0: pace *= 1.0 - float(unit.slow)
		sprite.speed_scale = clampf(pace, 0.25, 1.8)

func cardinal_direction(direction: Vector2, previous := "") -> String:
	# Hysteresis keeps diagonal routes from switching rows at every tiny correction.
	var horizontal := absf(direction.x) >= absf(direction.y)
	if previous in ["left", "right"]: horizontal = absf(direction.y) <= absf(direction.x) * 1.2
	elif previous in ["up", "down"]: horizontal = absf(direction.x) > absf(direction.y) * 1.2
	return ("left" if direction.x < 0 else "right") if horizontal else ("up" if direction.y < 0 else "down")

func fit_frame(unit: Dictionary) -> void:
	_fit_current_frame()
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var vertical := frame.has_meta("walk_scale")
	(sprite.material as ShaderMaterial).set_shader_parameter("troop_palette", int(unit.team) if vertical else -1)

func _fit_current_frame() -> void:
	if dying or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation): return
	if sprite.frame >= sprite.sprite_frames.get_frame_count(sprite.animation): return
	var frame := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var size := frame.get_size()
	if frame.has_meta("walk_scale"):
		var art_scale: float = frame.get_meta("walk_scale")
		var anchor: Vector2 = frame.get_meta("foot_anchor")
		sprite.scale = Vector2.ONE * current_visual_scale * art_scale
		sprite.offset = size * 0.5 - anchor + Vector2(0, 4.0 / art_scale)
	else:
		sprite.scale = Vector2.ONE * current_visual_scale
		sprite.offset = Vector2(0, -32)

func die() -> void:
	if dying: return
	dying = true
	sprite.material = null
	if not visible:
		queue_free()
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	Art.add_row(frames, Art.texture("Factions/Knights/Troops/Dead/Dead.png"), "death", 0, 7, 12, false, 128)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, -24)
	sprite.scale = Vector2.ONE * current_visual_scale
	sprite.modulate = Color.WHITE
	sprite.speed_scale = 1
	sprite.play("death")
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_callback(queue_free)
