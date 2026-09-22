class_name TowerProjectile
extends Node2D

const HitEffectScript = preload("res://scripts/effects/hit_effect.gd")

var _target: Node2D
var _damage := 1.0
var _speed := 400.0
var _color := Color("#9feeff")
var _splash_radius := 0.0
var _slow_factor := 1.0
var _slow_duration := 0.0
var _freeze_duration := 0.0
var _direction := Vector2.RIGHT


func setup(
	target: Node2D,
	damage: float,
	speed: float,
	color: Color,
	splash_radius: float,
	slow_factor: float,
	slow_duration: float,
	freeze_duration: float = 0.0
) -> void:
	_target = target
	_damage = damage
	_speed = speed
	_color = color
	_splash_radius = splash_radius
	_slow_factor = slow_factor
	_slow_duration = slow_duration
	_freeze_duration = freeze_duration
	z_index = 12
	queue_redraw()


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return

	var offset := _target.global_position - global_position
	var distance := offset.length()
	if distance <= maxf(5.0, _speed * delta):
		global_position = _target.global_position
		_impact()
		return

	_direction = offset.normalized()
	global_position += _direction * _speed * delta
	rotation = _direction.angle()


func _impact() -> void:
	if _splash_radius <= 0.0:
		_hit_enemy(_target)
	else:
		for enemy_node in get_tree().get_nodes_in_group("enemies"):
			var enemy := enemy_node as Node2D
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_to(global_position) <= _splash_radius:
				_hit_enemy(enemy)

	_spawn_impact_effect()
	queue_free()


func _hit_enemy(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_method("take_damage"):
		enemy.take_damage(_damage)
	if _slow_duration > 0.0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(_slow_factor, _slow_duration)
	if _freeze_duration > 0.0 and enemy.has_method("apply_freeze"):
		enemy.apply_freeze(_freeze_duration)


func _spawn_impact_effect() -> void:
	var effect: HitEffect = HitEffectScript.new()
	var container := get_parent()
	container.add_child(effect)
	effect.global_position = global_position
	effect.setup(_color, maxf(12.0, _splash_radius if _splash_radius > 0.0 else 18.0))


func _draw() -> void:
	draw_line(Vector2(-_direction.x * 16.0, -_direction.y * 16.0), Vector2.ZERO, Color(_color.r, _color.g, _color.b, 0.28), 5.0)
	draw_circle(Vector2.ZERO, 6.0, _color)
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
