class_name FrogEnemy
extends Node2D

signal defeated(enemy: FrogEnemy, reward: int, world_position: Vector2)
signal reached_core(enemy: FrogEnemy, iq_damage: int)

var definition: Dictionary = {}
var max_hp := 1.0
var current_hp := 1.0
var path_progress := 0.0

var _path_points := PackedVector2Array()
var _segment_index := 0
var _active := false
var _flash_remaining := 0.0
var _slow_factor := 1.0
var _slow_remaining := 0.0
var _bob_time := 0.0


func _ready() -> void:
	add_to_group("enemies")
	z_index = 8


func setup(path_points: PackedVector2Array, enemy_definition: Dictionary, hp_scale: float) -> void:
	_path_points = path_points
	definition = enemy_definition
	max_hp = float(definition.get("max_hp", 1.0)) * hp_scale
	current_hp = max_hp
	global_position = _path_points[0]
	_active = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return

	_bob_time += delta
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		queue_redraw()

	if _slow_remaining > 0.0:
		_slow_remaining = maxf(0.0, _slow_remaining - delta)
		if is_zero_approx(_slow_remaining):
			_slow_factor = 1.0
			queue_redraw()

	var distance_left := float(definition.get("speed", 50.0)) * _slow_factor * delta
	while distance_left > 0.0 and _segment_index < _path_points.size() - 1:
		var target := _path_points[_segment_index + 1]
		var offset := target - global_position
		var distance_to_target := offset.length()
		if distance_to_target <= distance_left:
			global_position = target
			distance_left -= distance_to_target
			_segment_index += 1
		else:
			global_position += offset.normalized() * distance_left
			distance_left = 0.0

	path_progress = float(_segment_index) / float(maxi(1, _path_points.size() - 1))
	if _segment_index >= _path_points.size() - 1:
		_reach_core()


func take_damage(raw_damage: float) -> void:
	if not _active:
		return
	var armor := float(definition.get("armor", 0.0))
	var dealt_damage := maxf(1.0, raw_damage - armor)
	current_hp -= dealt_damage
	_flash_remaining = 0.08
	queue_redraw()
	if current_hp <= 0.0:
		_die()


func apply_slow(speed_factor: float, duration: float) -> void:
	if not _active or duration <= 0.0:
		return
	var resistance := clampf(float(definition.get("slow_resistance", 0.0)), 0.0, 0.95)
	var resisted_factor := 1.0 - ((1.0 - speed_factor) * (1.0 - resistance))
	if resisted_factor < _slow_factor or _slow_remaining <= 0.0:
		_slow_factor = clampf(resisted_factor, 0.25, 1.0)
	_slow_remaining = maxf(_slow_remaining, duration)
	queue_redraw()


func _die() -> void:
	if not _active:
		return
	_active = false
	defeated.emit(self, int(definition.get("reward", 0)), global_position)
	queue_free()


func _reach_core() -> void:
	if not _active:
		return
	_active = false
	reached_core.emit(self, int(definition.get("iq_damage", 1)))
	queue_free()


func _draw() -> void:
	var radius := float(definition.get("radius", 14.0))
	var base_color := Color(str(definition.get("color", "#7fc86b")))
	if _flash_remaining > 0.0:
		base_color = base_color.lerp(Color.WHITE, 0.78)
	var bob := sin(_bob_time * 7.0) * 1.5
	draw_circle(Vector2(0.0, 10.0), radius * 0.95, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(Vector2(0.0, bob), radius, base_color)
	draw_circle(Vector2(-radius * 0.45, -radius * 0.35 + bob), maxf(2.0, radius * 0.18), Color("#172f3b"))
	draw_circle(Vector2(radius * 0.45, -radius * 0.35 + bob), maxf(2.0, radius * 0.18), Color("#172f3b"))
	draw_arc(Vector2(0.0, bob + radius * 0.2), radius * 0.48, 0.25, PI - 0.25, 12, Color(0.1, 0.2, 0.16, 0.7), 2.0)

	if _slow_remaining > 0.0:
		draw_arc(Vector2.ZERO, radius + 5.0, -PI * 0.2, PI * 1.2, 24, Color("#9fefff"), 2.0)

	var bar_width := maxf(28.0, radius * 2.4)
	var bar_position := Vector2(-bar_width * 0.5, -radius - 11.0)
	draw_rect(Rect2(bar_position, Vector2(bar_width, 5.0)), Color(0.03, 0.06, 0.09, 0.9))
	var ratio := clampf(current_hp / max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar_position + Vector2(1.0, 1.0), Vector2((bar_width - 2.0) * ratio, 3.0)), Color("#7ef0a4"))
