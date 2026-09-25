class_name DefenseStructure
extends Node2D

const Metrics = preload("res://scripts/game/game_metrics.gd")

signal destroyed(structure: DefenseStructure)

var definition: Dictionary = {}
var level := 1
var max_hp := 100.0
var current_hp := 100.0
var selected := false
var hovered := false

var _owner_game: Node
var _flash_remaining := 0.0


func setup(owner_game: Node, structure_definition: Dictionary) -> void:
	_owner_game = owner_game
	definition = structure_definition.duplicate(true)
	add_to_group("structures")
	z_index = 10
	level = 1
	_recalculate_stats()
	current_hp = max_hp
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		queue_redraw()


func take_damage(raw_damage: float) -> void:
	if current_hp <= 0.0:
		return
	var armor := float(definition.get("armor", 0.0))
	current_hp -= maxf(1.0, raw_damage - armor)
	_flash_remaining = 0.12
	queue_redraw()
	if current_hp <= 0.0:
		_destroy_structure()


func heal(amount: float) -> void:
	if current_hp <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + maxf(0.0, amount))
	queue_redraw()


func is_destroyed() -> bool:
	return current_hp <= 0.0


func is_alive() -> bool:
	return not is_destroyed()


func upgrade() -> bool:
	if level >= 3:
		return false
	level += 1
	_recalculate_stats()
	current_hp = minf(max_hp, current_hp + max_hp * 0.35)
	queue_redraw()
	return true


func update_modifiers(modifiers: Dictionary) -> void:
	_apply_modifiers(modifiers)
	_recalculate_stats()
	current_hp = minf(maxf(1.0, current_hp), max_hp)
	queue_redraw()


func get_upgrade_cost() -> int:
	var base_cost := float(definition.get("cost", 40))
	return int(round(base_cost * (0.62 + 0.24 * level)))


func get_display_name() -> String:
	return str(definition.get("name", "防御建筑"))


func get_health_ratio() -> float:
	return clampf(current_hp / maxf(1.0, max_hp), 0.0, 1.0)


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_hovered(value: bool) -> void:
	hovered = value
	queue_redraw()


func get_detail_text() -> String:
	return "%s · Lv.%d\nHP %d / %d" % [get_display_name(), level, int(ceil(current_hp)), int(max_hp)]


func can_accept_priority_target() -> bool:
	return false


func set_priority_target(_target: Node2D) -> bool:
	return false


func _apply_modifiers(_modifiers: Dictionary) -> void:
	pass


func _recalculate_stats() -> void:
	max_hp = float(definition.get("max_hp", 100.0)) * (1.0 + (level - 1) * 0.28)


func _destroy_structure() -> void:
	current_hp = 0.0
	queue_redraw()
	destroyed.emit(self)
	queue_free()


func _draw_health_bar(extra_y: float = -10.0, width: float = 10.0) -> void:
	if current_hp >= max_hp and not selected and not hovered:
		return
	var bar_height := maxf(2.0, Metrics.cells(0.55))
	var bar_position := Vector2(-width * 0.5, extra_y)
	draw_rect(Rect2(bar_position, Vector2(width, bar_height)), Color(0.02, 0.05, 0.09, 0.92))
	var color := Color("#75e7a5")
	if get_health_ratio() < 0.35:
		color = Color("#ff6d82")
	draw_rect(Rect2(bar_position + Vector2(0.5, 0.5), Vector2((width - 1.0) * get_health_ratio(), bar_height - 1.0)), color)
