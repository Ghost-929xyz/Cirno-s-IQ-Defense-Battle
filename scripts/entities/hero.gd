class_name CirnoHero
extends Node2D

const ProjectileScript = preload("res://scripts/entities/projectile.gd")

var arena_rect := Rect2()
var move_target := Vector2.INF
var attack_range := 145.0
var attack_interval := 0.68
var attack_damage := 18.0
var move_speed := 150.0
var frost_nova_cooldown := 8.0
var absolute_freeze_cooldown := 16.0

var _owner_game: Node
var _attack_cooldown := 0.0
var _nova_cooldown := 0.0
var _freeze_cooldown := 0.0
var _bob_time := 0.0
var _damage_multiplier := 1.0
var _attack_speed_multiplier := 1.0
var _cooldown_multiplier := 1.0


func _ready() -> void:
	add_to_group("hero")
	z_index = 14


func setup(owner_game: Node, play_rect: Rect2) -> void:
	_owner_game = owner_game
	arena_rect = play_rect
	global_position = play_rect.get_center()
	update_modifiers(owner_game.get_hero_modifiers())
	queue_redraw()


func update_modifiers(modifiers: Dictionary) -> void:
	_damage_multiplier = float(modifiers.get("hero_damage_multiplier", 1.0))
	_attack_speed_multiplier = float(modifiers.get("hero_attack_speed_multiplier", 1.0))
	_cooldown_multiplier = clampf(float(modifiers.get("hero_cooldown_multiplier", 1.0)), 0.5, 1.0)
	attack_interval = 0.68 / _attack_speed_multiplier
	frost_nova_cooldown = 8.0 * _cooldown_multiplier
	absolute_freeze_cooldown = 16.0 * _cooldown_multiplier
	queue_redraw()


func set_move_target(world_position: Vector2) -> void:
	move_target = Vector2(
		clampf(world_position.x, arena_rect.position.x + 12.0, arena_rect.end.x - 12.0),
		clampf(world_position.y, arena_rect.position.y + 12.0, arena_rect.end.y - 12.0)
	)
	queue_redraw()


func try_cast_skill(slot: String) -> bool:
	if slot == "nova" and _nova_cooldown <= 0.0:
		_cast_frost_nova()
		return true
	if slot == "freeze" and _freeze_cooldown <= 0.0:
		_cast_absolute_freeze()
		return true
	return false


func trigger_baka_passive() -> void:
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if global_position.distance_to(enemy.global_position) <= 135.0:
			enemy.take_damage(8.0 * _damage_multiplier)
			if is_instance_valid(enemy):
				enemy.apply_slow(0.58, 2.8)
	if is_instance_valid(_owner_game):
		_owner_game.spawn_hit_effect(global_position, Color("#dffcff"), 138.0)


func get_skill_text(slot: String) -> String:
	if slot == "nova":
		return "Q 冰霜新星  %.1fs" % maxf(0.0, _nova_cooldown)
	return "R 完美冻结  %.1fs" % maxf(0.0, _freeze_cooldown)


func get_skill_ready(slot: String) -> bool:
	if slot == "nova":
		return _nova_cooldown <= 0.0
	return _freeze_cooldown <= 0.0


func _process(delta: float) -> void:
	_bob_time += delta
	_attack_cooldown -= delta
	_nova_cooldown = maxf(0.0, _nova_cooldown - delta)
	_freeze_cooldown = maxf(0.0, _freeze_cooldown - delta)

	if move_target.is_finite():
		var offset := move_target - global_position
		if offset.length() <= 5.0:
			move_target = Vector2.INF
		else:
			global_position += offset.normalized() * minf(offset.length(), move_speed * delta)

	var target := _find_target()
	if target != null and _attack_cooldown <= 0.0:
		_fire_at(target)
		_attack_cooldown = attack_interval
	queue_redraw()


func _find_target() -> FairyEnemy:
	var nearest: FairyEnemy = null
	var nearest_distance := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= attack_range and distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _fire_at(target: FairyEnemy) -> void:
	var projectile: TowerProjectile = ProjectileScript.new()
	_owner_game.add_projectile(projectile)
	projectile.global_position = global_position
	projectile.setup(
		target,
		attack_damage * _damage_multiplier,
		520.0,
		Color("#bdf7ff"),
		0.0,
		0.78,
		0.8,
		0.0
	)


func _cast_frost_nova() -> void:
	_nova_cooldown = frost_nova_cooldown
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if global_position.distance_to(enemy.global_position) <= 145.0:
			enemy.take_damage(28.0 * _damage_multiplier)
			if is_instance_valid(enemy):
				enemy.apply_slow(0.48, 3.0)
	_owner_game.spawn_hit_effect(global_position, Color("#a8f4ff"), 152.0)


func _cast_absolute_freeze() -> void:
	var target: FairyEnemy = null
	var nearest_distance := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= 250.0 and distance < nearest_distance:
			target = enemy
			nearest_distance = distance
	if target == null:
		return
	_freeze_cooldown = absolute_freeze_cooldown
	target.apply_freeze(3.0)
	target.take_damage(16.0 * _damage_multiplier)
	_owner_game.spawn_hit_effect(target.global_position, Color("#ffffff"), 48.0)


func _draw() -> void:
	var bob := sin(_bob_time * 5.2) * 2.2
	if move_target.is_finite():
		draw_arc(move_target, 12.0, 0.0, TAU, 24, Color(0.72, 0.96, 1.0, 0.72), 2.0)
		draw_line(Vector2.ZERO, move_target - global_position, Color(0.65, 0.92, 1.0, 0.18), 1.5)

	draw_circle(Vector2(0.0, 13.0 + bob), 17.0, Color(0.01, 0.04, 0.09, 0.35))
	for angle_index in range(6):
		var angle := TAU * float(angle_index) / 6.0
		draw_line(Vector2(0.0, bob), Vector2.from_angle(angle) * 25.0, Color(0.73, 0.96, 1.0, 0.7), 4.0)
	draw_circle(Vector2(0.0, bob), 18.0, Color("#f4ffff"))
	draw_circle(Vector2(0.0, bob + 2.0), 15.0, Color("#69c9f1"))
	draw_circle(Vector2(-6.0, -6.0 + bob), 3.0, Color("#173752"))
	draw_circle(Vector2(6.0, -6.0 + bob), 3.0, Color("#173752"))
	draw_arc(Vector2(0.0, bob + 5.0), 7.0, 0.2, PI - 0.2, 12, Color("#173752"), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-7.0, 8.0 + bob), "⑨", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#f7ffff"))
	draw_string(ThemeDB.fallback_font, Vector2(-30.0, 37.0), "琪露诺", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e8fcff"))
