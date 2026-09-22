class_name AllyUnit
extends Node2D

signal defeated(unit: AllyUnit)

const ProjectileScript = preload("res://scripts/entities/projectile.gd")

var definition: Dictionary = {}
var max_hp := 1.0
var current_hp := 1.0

var _owner_game: Node
var _target: FairyEnemy
var _attack_cooldown := 0.0
var _flash_remaining := 0.0
var _bob_time := 0.0
var _active := false
var _damage_multiplier := 1.0
var _attack_speed_multiplier := 1.0
var _health_multiplier := 1.0


func _ready() -> void:
	add_to_group("allies")
	z_index = 9


func setup(owner_game: Node, unit_definition: Dictionary, spawn_position: Vector2) -> void:
	_owner_game = owner_game
	definition = unit_definition.duplicate(true)
	global_position = spawn_position
	update_modifiers(owner_game.get_ally_modifiers())
	current_hp = max_hp
	_active = true
	queue_redraw()


func update_modifiers(modifiers: Dictionary) -> void:
	_damage_multiplier = float(modifiers.get("ally_damage_multiplier", 1.0))
	_attack_speed_multiplier = float(modifiers.get("ally_attack_speed_multiplier", 1.0))
	_health_multiplier = float(modifiers.get("ally_health_multiplier", 1.0))
	max_hp = float(definition.get("max_hp", 80.0)) * _health_multiplier
	current_hp = minf(current_hp if current_hp > 0.0 else max_hp, max_hp)
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_bob_time += delta
	_attack_cooldown -= delta
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		queue_redraw()

	if not is_instance_valid(_target) or not _target.is_alive():
		_target = _find_target()
	if not is_instance_valid(_target):
		return

	var offset := _target.global_position - global_position
	var distance := offset.length()
	var attack_range := float(definition.get("attack_range", 30.0))
	if distance > attack_range:
		var move_speed := float(definition.get("move_speed", 70.0))
		global_position += offset.normalized() * minf(distance - attack_range * 0.85, move_speed * delta)
	elif _attack_cooldown <= 0.0:
		_attack_target()
		_attack_cooldown = float(definition.get("attack_interval", 1.0)) / _attack_speed_multiplier


func take_damage(raw_damage: float) -> void:
	if not _active:
		return
	var armor := float(definition.get("armor", 0.0))
	current_hp -= maxf(1.0, raw_damage - armor)
	_flash_remaining = 0.1
	queue_redraw()
	if current_hp <= 0.0:
		_die()


func is_alive() -> bool:
	return _active and current_hp > 0.0


func _find_target() -> FairyEnemy:
	var nearest: FairyEnemy = null
	var nearest_distance := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _attack_target() -> void:
	var damage := float(definition.get("damage", 10.0)) * _damage_multiplier
	var attack_range := float(definition.get("attack_range", 30.0))
	if attack_range <= 35.0:
		_target.take_damage(damage)
		if _owner_game != null:
			_owner_game.spawn_hit_effect(_target.global_position, Color(str(definition.get("attack_color", "#e8ffff"))), 18.0)
		return
	var projectile: TowerProjectile = ProjectileScript.new()
	_owner_game.add_projectile(projectile)
	projectile.global_position = global_position
	projectile.setup(
		_target,
		damage,
		float(definition.get("projectile_speed", 420.0)),
		Color(str(definition.get("attack_color", "#e8ffff"))),
		float(definition.get("splash_radius", 0.0)),
		float(definition.get("slow_factor", 1.0)),
		float(definition.get("slow_duration", 0.0)),
		0.0
	)


func _die() -> void:
	if not _active:
		return
	_active = false
	defeated.emit(self)
	queue_free()


func _draw() -> void:
	var color := Color(str(definition.get("color", "#82d7ee")))
	if _flash_remaining > 0.0:
		color = color.lerp(Color.WHITE, 0.72)
	var bob := sin(_bob_time * 7.0) * 1.2
	draw_circle(Vector2(0.0, 9.0), 12.0, Color(0.0, 0.0, 0.0, 0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, bob - 2),
		Vector2(-16, bob - 10),
		Vector2(-5, bob - 11),
	]), Color(color.r, color.g, color.b, 0.5))
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, bob - 2),
		Vector2(16, bob - 10),
		Vector2(5, bob - 11),
	]), Color(color.r, color.g, color.b, 0.5))
	draw_circle(Vector2(0.0, bob), 10.0, color)
	draw_circle(Vector2(-4.0, -3.0 + bob), 1.7, Color("#21324c"))
	draw_circle(Vector2(4.0, -3.0 + bob), 1.7, Color("#21324c"))
	var unit_id := str(definition.get("id", "ice_guard"))
	if unit_id == "ice_guard":
		draw_line(Vector2(6.0, 4.0), Vector2(13.0, 16.0), Color("#efffff"), 3.0)
	elif unit_id == "mist_archer":
		draw_arc(Vector2(9.0, 2.0), 8.0, -PI * 0.55, PI * 0.55, 12, Color("#efffff"), 2.0)
	else:
		draw_circle(Vector2(9.0, 3.0), 5.0, Color("#e4d9ff"))
		draw_circle(Vector2(9.0, 3.0), 2.0, Color.WHITE)

	var bar_width := 26.0
	var bar_position := Vector2(-bar_width * 0.5, -20.0)
	draw_rect(Rect2(bar_position, Vector2(bar_width, 4.0)), Color(0.02, 0.05, 0.09, 0.9))
	draw_rect(Rect2(bar_position + Vector2(1.0, 1.0), Vector2((bar_width - 2.0) * clampf(current_hp / max_hp, 0.0, 1.0), 2.0)), Color("#87ecff"))
