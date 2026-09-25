class_name FairyEnemy
extends Node2D

const Metrics = preload("res://scripts/game/game_metrics.gd")

signal defeated(enemy: FairyEnemy, reward: int, shards: int, world_position: Vector2)
signal reached_core(enemy: FairyEnemy, leak_damage: int)

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
var _freeze_remaining := 0.0
var _bob_time := 0.0
var _attack_cooldown := 0.0
var _scan_cooldown := 0.0
var _combat_target: Node2D


func _ready() -> void:
	add_to_group("enemies")
	z_index = 8


func setup(path_points: PackedVector2Array, enemy_definition: Dictionary, hp_scale: float) -> void:
	_path_points = path_points
	definition = enemy_definition.duplicate(true)
	max_hp = float(definition.get("max_hp", 1.0)) * hp_scale
	current_hp = max_hp
	global_position = _path_points[0]
	_active = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return

	_bob_time += delta
	_attack_cooldown -= delta
	_scan_cooldown -= delta
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		queue_redraw()

	if _slow_remaining > 0.0:
		_slow_remaining = maxf(0.0, _slow_remaining - delta)
		if is_zero_approx(_slow_remaining):
			_slow_factor = 1.0
			queue_redraw()
	if _freeze_remaining > 0.0:
		_freeze_remaining = maxf(0.0, _freeze_remaining - delta)
		queue_redraw()
		return

	if not is_instance_valid(_combat_target) or _combat_target.is_queued_for_deletion():
		_combat_target = null
	if _combat_target == null and _scan_cooldown <= 0.0:
		_scan_cooldown = 0.35
		_combat_target = _find_combat_target()

	if is_instance_valid(_combat_target):
		var engage_range := Metrics.combat_range(float(definition.get("attack_range", 36.0)) + 12.0)
		if global_position.distance_to(_combat_target.global_position) > engage_range:
			_combat_target = null
		else:
			if _attack_cooldown <= 0.0 and _combat_target.has_method("take_damage"):
				_combat_target.take_damage(float(definition.get("attack_damage", 8.0)))
				_attack_cooldown = float(definition.get("attack_interval", 1.0))
			return

	_move_along_path(delta)


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


func apply_freeze(duration: float) -> void:
	if not _active or duration <= 0.0:
		return
	var resistance := clampf(float(definition.get("freeze_resistance", 0.0)), 0.0, 0.85)
	_freeze_remaining = maxf(_freeze_remaining, duration * (1.0 - resistance))
	queue_redraw()


func is_alive() -> bool:
	return _active and current_hp > 0.0


func is_elite() -> bool:
	return bool(definition.get("elite", false))


func is_boss() -> bool:
	return bool(definition.get("boss", false))


func _find_combat_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for ally_node in get_tree().get_nodes_in_group("allies"):
		var ally := ally_node as AllyUnit
		if ally == null or not is_instance_valid(ally) or not ally.is_alive():
			continue
		var distance := global_position.distance_to(ally.global_position)
		if distance <= Metrics.combat_range(62.0) and distance < nearest_distance:
			nearest = ally
			nearest_distance = distance

	for hero_node in get_tree().get_nodes_in_group("hero"):
		var hero := hero_node as CirnoHero
		if hero == null or not is_instance_valid(hero) or not hero.is_alive():
			continue
		var hero_distance := global_position.distance_to(hero.global_position)
		if hero_distance <= Metrics.combat_range(45.0) and hero_distance < nearest_distance:
			nearest = hero
			nearest_distance = hero_distance

	var structure_reach := Metrics.combat_range(float(definition.get("attack_range", 36.0)) + 18.0)
	for structure_node in get_tree().get_nodes_in_group("structures"):
		var structure := structure_node as DefenseStructure
		if structure == null or not is_instance_valid(structure) or not structure.is_alive():
			continue
		var distance := global_position.distance_to(structure.global_position)
		if distance <= structure_reach and distance < nearest_distance:
			nearest = structure
			nearest_distance = distance
	return nearest


func _move_along_path(delta: float) -> void:
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


func _die() -> void:
	if not _active:
		return
	_active = false
	defeated.emit(
		self,
		int(definition.get("reward", 0)),
		int(definition.get("shard_drop", 0)),
		global_position
	)
	queue_free()


func _reach_core() -> void:
	if not _active:
		return
	_active = false
	reached_core.emit(self, int(definition.get("leak_damage", 5)))
	queue_free()


func _draw() -> void:
	var radius := maxf(2.4, Metrics.art(float(definition.get("radius", 14.0))))
	var body_color := Color(str(definition.get("color", "#d487e8")))
	if _flash_remaining > 0.0:
		body_color = body_color.lerp(Color.WHITE, 0.75)
	var bob := sin(_bob_time * 6.5) * Metrics.art(2.0)

	draw_circle(Vector2(0.0, radius + 4.0), radius * 0.86, Color(0.0, 0.0, 0.0, 0.2))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-radius * 0.8, -radius * 0.2 + bob),
		Vector2(-radius * 1.8, -radius * 0.8 + bob),
		Vector2(-radius * 0.7, -radius * 0.9 + bob),
	]), Color(body_color.r, body_color.g, body_color.b, 0.48))
	draw_colored_polygon(PackedVector2Array([
		Vector2(radius * 0.8, -radius * 0.2 + bob),
		Vector2(radius * 1.8, -radius * 0.8 + bob),
		Vector2(radius * 0.7, -radius * 0.9 + bob),
	]), Color(body_color.r, body_color.g, body_color.b, 0.48))
	draw_circle(Vector2(0.0, bob), radius, body_color)
	draw_circle(Vector2(-radius * 0.42, -radius * 0.32 + bob), maxf(2.0, radius * 0.17), Color("#24304a"))
	draw_circle(Vector2(radius * 0.42, -radius * 0.32 + bob), maxf(2.0, radius * 0.17), Color("#24304a"))
	draw_arc(Vector2(0.0, bob + radius * 0.24), radius * 0.43, 0.25, PI - 0.25, 12, Color(0.16, 0.14, 0.25, 0.75), 2.0)

	if is_boss():
		draw_arc(Vector2(0.0, bob), radius + 7.0, PI, TAU, 20, Color("#ff526d"), 4.0)
		draw_circle(Vector2(0.0, -radius - 8.0 + bob), 5.0, Color("#ffe26b"))
	if is_elite() and not is_boss():
		draw_arc(Vector2(0.0, bob), radius + 5.0, PI, TAU, 18, Color("#ffe26b"), 3.0)

	if _slow_remaining > 0.0 or _freeze_remaining > 0.0:
		var ring_color := Color("#efffff") if _freeze_remaining > 0.0 else Color("#9fefff")
		draw_arc(Vector2.ZERO, radius + 5.0, -PI * 0.2, PI * 1.2, 24, ring_color, 2.0)

	# 高密度地图只保留很小的状态条，血量主要由顶部 HUD 和受击反馈表达。
	if current_hp < max_hp - 0.01 or is_elite() or is_boss():
		var bar_width := maxf(6.0, radius * 2.4)
		var bar_position := Vector2(-bar_width * 0.5, -radius - maxf(2.0, Metrics.art(14.0)))
		var bar_height := 2.0 if is_boss() else 1.5
		draw_rect(Rect2(bar_position, Vector2(bar_width, bar_height)), Color(0.03, 0.06, 0.09, 0.9))
		var ratio := clampf(current_hp / max_hp, 0.0, 1.0)
		var bar_color := Color("#ff6b82") if is_boss() else Color("#7ef0a4")
		draw_rect(Rect2(bar_position + Vector2(0.5, 0.5), Vector2(maxf(0.5, (bar_width - 1.0) * ratio), 0.5)), bar_color)
