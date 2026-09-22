class_name CirnoTower
extends DefenseStructure

const ProjectileScript = preload("res://scripts/entities/projectile.gd")

var range_pixels := 150.0
var attack_interval := 1.0
var fire_cooldown := 0.0

var _damage_multiplier := 1.0
var _attack_speed_multiplier := 1.0
var _health_multiplier := 1.0
var _slow_bonus := 0.0
var _splash_multiplier := 1.0
var _priority_target: Node2D


func _process(delta: float) -> void:
	super._process(delta)
	fire_cooldown -= delta
	if fire_cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	_fire_at(target)
	fire_cooldown = attack_interval


func update_modifiers(modifiers: Dictionary) -> void:
	_apply_modifiers(modifiers)
	_recalculate_stats()
	current_hp = minf(maxf(1.0, current_hp), max_hp)
	queue_redraw()


func set_priority_target(target: Node2D) -> void:
	_priority_target = target


func get_detail_text() -> String:
	return "%s · Lv.%d\nHP %d / %d · 伤害 %d\n射程 %.1f 格 · 间隔 %.2f 秒" % [
		get_display_name(),
		level,
		int(ceil(current_hp)),
		int(max_hp),
		int(round(float(definition.get("current_damage", 0.0)))),
		range_pixels / 60.0,
		attack_interval,
	]


func _apply_modifiers(modifiers: Dictionary) -> void:
	_damage_multiplier = float(modifiers.get("tower_damage_multiplier", 1.0))
	_attack_speed_multiplier = float(modifiers.get("tower_attack_speed_multiplier", 1.0))
	_health_multiplier = float(modifiers.get("tower_health_multiplier", 1.0))
	_slow_bonus = float(modifiers.get("slow_bonus", 0.0))
	_splash_multiplier = float(modifiers.get("splash_multiplier", 1.0))


func _recalculate_stats() -> void:
	super._recalculate_stats()
	max_hp *= _health_multiplier
	range_pixels = float(definition.get("range_cells", 2.5)) * 60.0 * (1.0 + (level - 1) * 0.08)
	var damage := float(definition.get("damage", 10.0)) * (1.0 + (level - 1) * 0.34) * _damage_multiplier
	attack_interval = float(definition.get("cooldown", 1.0)) / (1.0 + (level - 1) * 0.12) / _attack_speed_multiplier
	fire_cooldown = minf(fire_cooldown, attack_interval)
	definition["current_damage"] = damage
	definition["current_splash"] = float(definition.get("splash_radius", 0.0)) * _splash_multiplier
	definition["current_slow_factor"] = clampf(float(definition.get("slow_factor", 1.0)) - _slow_bonus, 0.28, 1.0)
	queue_redraw()


func _find_target() -> Node2D:
	if is_instance_valid(_priority_target):
		var fairy := _priority_target as FairyEnemy
		if fairy != null and fairy.is_alive() and global_position.distance_to(fairy.global_position) <= range_pixels:
			return fairy
		else:
			_priority_target = null

	var nearest: Node2D = null
	var nearest_distance := INF
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= range_pixels and distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


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
		float(definition.get("slow_duration", 0.0)),
		0.0
	)


func _draw() -> void:
	if selected or hovered:
		draw_circle(Vector2.ZERO, range_pixels, Color(0.45, 0.9, 1.0, 0.075))
		draw_arc(Vector2.ZERO, range_pixels, 0.0, TAU, 64, Color(0.62, 0.94, 1.0, 0.72), 2.0)

	var base_color := Color(str(definition.get("color", "#8fe9ff")))
	if _flash_remaining > 0.0:
		base_color = base_color.lerp(Color.WHITE, 0.72)
	draw_circle(Vector2(0.0, 8.0), 24.0, Color(0.01, 0.06, 0.12, 0.48))
	draw_circle(Vector2.ZERO, 23.0, Color("#e7fbff"))
	draw_circle(Vector2.ZERO, 19.0, base_color)

	var tower_id := str(definition.get("id", "icicle"))
	if tower_id == "icicle":
		draw_colored_polygon(PackedVector2Array([Vector2(-7, 9), Vector2(0, 28), Vector2(7, 9)]), Color("#eefeff"))
		draw_circle(Vector2.ZERO, 10.0, Color("#5fbee9"))
	elif tower_id == "rime":
		for angle_index in range(6):
			var angle := TAU * float(angle_index) / 6.0
			draw_line(Vector2.ZERO, Vector2.from_angle(angle) * 20.0, Color("#efffff"), 3.0)
		draw_circle(Vector2.ZERO, 7.0, Color("#82e9ed"))
	else:
		draw_circle(Vector2(0.0, 1.0), 15.0, Color("#2d77ab"))
		draw_circle(Vector2.ZERO, 9.0, Color("#e8fdff"))
		draw_string(ThemeDB.fallback_font, Vector2(-7.0, 6.0), "9", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#173d5b"))

	for pip_index in range(level):
		draw_circle(Vector2((pip_index - (level - 1) * 0.5) * 8.0, -28.0), 2.5, Color("#fff08a"))
	_draw_health_bar(-39.0)
