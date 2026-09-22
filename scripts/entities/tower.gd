class_name CirnoTower
extends Node2D

const ProjectileScript = preload("res://scripts/entities/projectile.gd")

var definition: Dictionary = {}
var level := 1
var range_pixels := 120.0
var attack_interval := 1.0
var selected := false
var hovered := false

var _owner_game: Node
var _cooldown := 0.0
var _damage_multiplier := 1.0
var _attack_speed_multiplier := 1.0
var _slow_bonus := 0.0
var _splash_multiplier := 1.0


func setup(owner_game: Node, tower_definition: Dictionary) -> void:
	_owner_game = owner_game
	definition = tower_definition
	z_index = 10
	_recalculate_stats()
	queue_redraw()


func _process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_fire_at(target)
	_cooldown = attack_interval


func update_modifiers(
	damage_multiplier: float,
	attack_speed_multiplier: float,
	slow_bonus: float,
	splash_multiplier: float
) -> void:
	_damage_multiplier = damage_multiplier
	_attack_speed_multiplier = attack_speed_multiplier
	_slow_bonus = slow_bonus
	_splash_multiplier = splash_multiplier
	_recalculate_stats()


func upgrade() -> bool:
	if level >= 3:
		return false
	level += 1
	_recalculate_stats()
	queue_redraw()
	return true


func get_upgrade_cost() -> int:
	var base_cost := float(definition.get("cost", 30))
	return int(round(base_cost * (0.75 + 0.25 * level)))


func get_display_name() -> String:
	return str(definition.get("name", "琪露诺"))


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_hovered(value: bool) -> void:
	hovered = value
	queue_redraw()


func _recalculate_stats() -> void:
	range_pixels = float(definition.get("range_cells", 2.5)) * 60.0 * (1.0 + (level - 1) * 0.08)
	var damage := float(definition.get("damage", 10.0)) * (1.0 + (level - 1) * 0.34) * _damage_multiplier
	attack_interval = float(definition.get("cooldown", 1.0)) / (1.0 + (level - 1) * 0.12) / _attack_speed_multiplier
	_cooldown = minf(_cooldown, attack_interval)
	# The damage value is carried by every newly spawned projectile.
	definition["current_damage"] = damage
	definition["current_splash"] = float(definition.get("splash_radius", 0.0)) * _splash_multiplier
	definition["current_slow_factor"] = clampf(float(definition.get("slow_factor", 1.0)) - _slow_bonus, 0.25, 1.0)
	queue_redraw()


func _find_target() -> Node2D:
	var best_target: Node2D = null
	var best_progress := -1.0
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FrogEnemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance > range_pixels:
			continue
		var progress := enemy.path_progress
		if progress > best_progress:
			best_progress = progress
			best_target = enemy
	return best_target


func _fire_at(target: Node2D) -> void:
	var projectile: TowerProjectile = ProjectileScript.new()
	_owner_game.add_projectile(projectile)
	projectile.global_position = global_position
	projectile.setup(
		target,
		float(definition.get("current_damage", 10.0)),
		float(definition.get("projectile_speed", 400.0)),
		Color(str(definition.get("color", "#9feeff"))),
		float(definition.get("current_splash", 0.0)),
		float(definition.get("current_slow_factor", 1.0)),
		float(definition.get("slow_duration", 0.0))
	)


func _draw() -> void:
	if selected or hovered:
		draw_circle(Vector2.ZERO, range_pixels, Color(0.48, 0.91, 1.0, 0.08))
		draw_arc(Vector2.ZERO, range_pixels, 0.0, TAU, 64, Color(0.58, 0.94, 1.0, 0.7), 2.0)

	var color := Color(str(definition.get("color", "#8fe9ff")))
	draw_circle(Vector2(0.0, 7.0), 24.0, Color(0.02, 0.08, 0.13, 0.45))
	draw_circle(Vector2.ZERO, 23.0, Color("#e7fbff"))
	draw_circle(Vector2.ZERO, 19.0, color)
	draw_circle(Vector2(0.0, -7.0), 12.0, Color("#f4fdff"))
	draw_circle(Vector2(-7.0, -7.0), 3.0, Color("#173c55"))
	draw_circle(Vector2(7.0, -7.0), 3.0, Color("#173c55"))

	var tower_id := str(definition.get("id", "icicle"))
	if tower_id == "icicle":
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 7), Vector2(0, 24), Vector2(5, 7)]), Color("#e6fdff"))
	elif tower_id == "rime":
		draw_arc(Vector2.ZERO, 14.0, -PI, 0.0, 18, Color("#eaffff"), 3.0)
		draw_circle(Vector2(0.0, 2.0), 4.0, Color("#77dff1"))
	else:
		draw_circle(Vector2(0.0, 4.0), 11.0, Color("#246b9b"))
		draw_circle(Vector2(0.0, 4.0), 6.0, Color("#dffbff"))

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-6.0, 9.0), str(definition.get("short", "冰")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#16384b"))
	for pip_index in range(level):
		draw_circle(Vector2((pip_index - (level - 1) * 0.5) * 8.0, -28.0), 2.5, Color("#fff08a"))
