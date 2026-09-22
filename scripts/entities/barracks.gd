class_name FairyBarracks
extends DefenseStructure

var spawn_interval := 7.0
var spawn_cooldown := 1.5
var max_units := 3
var unit_id := "ice_guard"

var _living_units: Array[AllyUnit] = []


func _process(delta: float) -> void:
	super._process(delta)
	_living_units = _living_units.filter(func(unit: AllyUnit) -> bool: return is_instance_valid(unit) and unit.is_alive())
	if not is_instance_valid(_owner_game) or not _owner_game.can_barracks_spawn():
		return
	spawn_cooldown -= delta
	if spawn_cooldown > 0.0 or _living_units.size() >= max_units:
		return
	_spawn_unit()
	spawn_cooldown = spawn_interval


func get_detail_text() -> String:
	var current_units := _living_units.size()
	return "%s · Lv.%d\nHP %d / %d · 小队 %d / %d\n召唤 %s · 间隔 %.1f 秒" % [
		get_display_name(),
		level,
		int(ceil(current_hp)),
		int(max_hp),
		current_units,
		max_units,
		str(definition.get("role", "己方兵种")),
		spawn_interval,
	]


func _apply_modifiers(_modifiers: Dictionary) -> void:
	spawn_interval = float(definition.get("spawn_interval", 7.0))


func _recalculate_stats() -> void:
	super._recalculate_stats()
	unit_id = str(definition.get("unit_id", "ice_guard"))
	max_units = int(definition.get("max_units", 3)) + (level - 1)
	spawn_interval = float(definition.get("spawn_interval", 7.0)) * (1.0 - (level - 1) * 0.10)


func _spawn_unit() -> void:
	var unit: AllyUnit = _owner_game.spawn_ally(self, unit_id)
	if unit == null:
		return
	_living_units.append(unit)
	unit.defeated.connect(_on_unit_defeated)


func _on_unit_defeated(unit: AllyUnit) -> void:
	_living_units.erase(unit)
	queue_redraw()


func _draw() -> void:
	if selected or hovered:
		draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 48, Color(0.66, 0.93, 1.0, 0.62), 2.0)

	var color := Color(str(definition.get("color", "#65bde9")))
	if _flash_remaining > 0.0:
		color = color.lerp(Color.WHITE, 0.7)
	draw_circle(Vector2(0.0, 8.0), 25.0, Color(0.01, 0.06, 0.11, 0.48))
	draw_rect(Rect2(Vector2(-23.0, -17.0), Vector2(46.0, 38.0)), Color("#dff8ff"))
	draw_rect(Rect2(Vector2(-18.0, -12.0), Vector2(36.0, 28.0)), color)
	draw_colored_polygon(PackedVector2Array([Vector2(-17, -12), Vector2(0, -29), Vector2(17, -12)]), Color("#f3ffff"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(-8.0, 8.0), str(definition.get("short", "兵")), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#153653"))
	for pip_index in range(level):
		draw_circle(Vector2((pip_index - (level - 1) * 0.5) * 8.0, -36.0), 2.5, Color("#fff08a"))
	_draw_health_bar(-45.0)
