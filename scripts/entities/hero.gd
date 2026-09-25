class_name CirnoHero
extends Node2D

signal defeated(hero: CirnoHero)

const ProjectileScript = preload("res://scripts/entities/projectile.gd")
const CirnoSprite = preload("res://scripts/entities/cirno_sprite.gd")
const Metrics = preload("res://scripts/game/game_metrics.gd")

## 需求 7：英雄数值整体下调（190 血 / 普攻 14 / 新星 22 / 冻结 12 / 被动 6）。
const BASE_MAX_HP := 190.0

var arena_rect := Rect2()
var move_target := Vector2.INF
var attack_range := Metrics.combat_range(145.0)
var attack_interval := 0.68
var attack_damage := 14.0
var move_speed := 150.0
var frost_nova_cooldown := 8.0
var absolute_freeze_cooldown := 16.0
var max_hp := BASE_MAX_HP
var current_hp := BASE_MAX_HP
var armor := 2.0
var hp_regen_per_second := 6.0

var _owner_game: Node
var _attack_cooldown := 0.0
var _nova_cooldown := 0.0
var _freeze_cooldown := 0.0
var _bob_time := 0.0
var _damage_multiplier := 1.0
var _attack_speed_multiplier := 1.0
var _cooldown_multiplier := 1.0
var _flash_remaining := 0.0
var _dead := false
var _selected := false
var _sprite: AnimatedSprite2D = null
var _attack_anim_remaining := 0.0
var _cast_anim_remaining := 0.0
var _hurt_anim_remaining := 0.0
var _facing := 1.0


func _ready() -> void:
	add_to_group("hero")
	z_index = 14
	_sprite = CirnoSprite.make_sprite()
	if _sprite != null:
		_sprite.z_index = 1
		add_child(_sprite)


func setup(owner_game: Node, play_rect: Rect2) -> void:
	_owner_game = owner_game
	arena_rect = play_rect
	global_position = play_rect.get_center()
	update_modifiers(owner_game.get_hero_modifiers())
	current_hp = max_hp
	queue_redraw()


func update_modifiers(modifiers: Dictionary) -> void:
	_damage_multiplier = float(modifiers.get("hero_damage_multiplier", 1.0))
	_attack_speed_multiplier = float(modifiers.get("hero_attack_speed_multiplier", 1.0))
	_cooldown_multiplier = clampf(float(modifiers.get("hero_cooldown_multiplier", 1.0)), 0.5, 1.0)
	attack_interval = 0.68 / _attack_speed_multiplier
	frost_nova_cooldown = 8.0 * _cooldown_multiplier
	absolute_freeze_cooldown = 16.0 * _cooldown_multiplier
	var previous_max := max_hp
	max_hp = BASE_MAX_HP + float(modifiers.get("hero_max_hp_add", 0.0))
	if max_hp > previous_max:
		current_hp += max_hp - previous_max
	current_hp = clampf(current_hp, 0.0, max_hp)
	queue_redraw()


func set_selected(value: bool) -> void:
	_selected = value
	queue_redraw()


func take_damage(raw_damage: float) -> void:
	if _dead:
		return
	current_hp = maxf(0.0, current_hp - maxf(1.0, raw_damage - armor))
	_flash_remaining = 0.14
	_hurt_anim_remaining = 0.22
	queue_redraw()
	if current_hp <= 0.0:
		_die()


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	queue_redraw()


func regen(delta: float) -> void:
	heal(hp_regen_per_second * delta)


func is_alive() -> bool:
	return not _dead and current_hp > 0.0


func get_hp() -> float:
	return current_hp


func get_max_hp() -> float:
	return max_hp


func set_move_target(world_position: Vector2) -> void:
	if _dead:
		return
	move_target = Vector2(
		clampf(world_position.x, arena_rect.position.x + 12.0, arena_rect.end.x - 12.0),
		clampf(world_position.y, arena_rect.position.y + 12.0, arena_rect.end.y - 12.0)
	)
	queue_redraw()


func try_cast_skill(slot: String) -> bool:
	if _dead:
		return false
	if slot == "nova" and _nova_cooldown <= 0.0:
		_cast_frost_nova()
		return true
	if slot == "freeze" and _freeze_cooldown <= 0.0:
		_cast_absolute_freeze()
		return true
	return false


func trigger_baka_passive() -> void:
	if _dead:
		return
	_cast_anim_remaining = 0.55
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if global_position.distance_to(enemy.global_position) <= Metrics.combat_range(135.0):
			enemy.take_damage(6.0 * _damage_multiplier)
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
	if _dead:
		return
	_bob_time += delta
	_attack_cooldown -= delta
	_nova_cooldown = maxf(0.0, _nova_cooldown - delta)
	_freeze_cooldown = maxf(0.0, _freeze_cooldown - delta)
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		queue_redraw()

	if move_target.is_finite():
		var offset := move_target - global_position
		if offset.length() <= 5.0:
			move_target = Vector2.INF
		else:
			global_position += offset.normalized() * minf(offset.length(), move_speed * delta)
			if absf(offset.x) > 1.0:
				_facing = signf(offset.x)

	_attack_anim_remaining = maxf(0.0, _attack_anim_remaining - delta)
	_cast_anim_remaining = maxf(0.0, _cast_anim_remaining - delta)
	_hurt_anim_remaining = maxf(0.0, _hurt_anim_remaining - delta)

	var target := _find_target()
	if target != null and _attack_cooldown <= 0.0:
		_fire_at(target)
		_attack_cooldown = attack_interval
	_update_sprite_animation()
	queue_redraw()


## 像素精灵状态机：施法 > 受击 > 普攻 > 移动 > 待机。
func _update_sprite_animation() -> void:
	if _sprite == null:
		return
	if _facing < 0.0:
		_sprite.flip_h = true
	else:
		_sprite.flip_h = false
	if _flash_remaining > 0.0:
		_sprite.modulate = Color(2.2, 2.2, 2.2, 1.0)
	else:
		_sprite.modulate = Color.WHITE
	var anim := "idle"
	if _cast_anim_remaining > 0.0:
		anim = "cast"
	elif _hurt_anim_remaining > 0.0:
		anim = "hurt"
	elif _attack_anim_remaining > 0.0:
		anim = "attack"
	elif move_target.is_finite():
		anim = "walk"
	if _sprite.animation != anim:
		_sprite.play(anim)


func _die() -> void:
	if _dead:
		return
	_dead = true
	move_target = Vector2.INF
	if _sprite != null:
		_sprite.modulate = Color.WHITE
		_sprite.play("death")
	if is_instance_valid(_owner_game):
		_owner_game.spawn_hit_effect(global_position, Color("#ff8ba0"), 96.0)
	queue_redraw()
	defeated.emit(self)


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
	_attack_anim_remaining = 0.26
	if is_instance_valid(target):
		var dx := target.global_position.x - global_position.x
		if absf(dx) > 1.0:
			_facing = signf(dx)
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
	_cast_anim_remaining = 0.55
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy := enemy_node as FairyEnemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if global_position.distance_to(enemy.global_position) <= Metrics.combat_range(145.0):
			enemy.take_damage(22.0 * _damage_multiplier)
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
		if distance <= Metrics.combat_range(250.0) and distance < nearest_distance:
			target = enemy
			nearest_distance = distance
	if target == null:
		return
	_freeze_cooldown = absolute_freeze_cooldown
	_cast_anim_remaining = 0.55
	var fdx := target.global_position.x - global_position.x
	if absf(fdx) > 1.0:
		_facing = signf(fdx)
	target.apply_freeze(3.0)
	target.take_damage(12.0 * _damage_multiplier)
	_owner_game.spawn_hit_effect(target.global_position, Color("#ffffff"), 48.0)


func _draw() -> void:
	var body_radius := maxf(4.2, Metrics.cells(0.95))
	var bob := sin(_bob_time * 5.2) * 0.6
	# 需求 9：脚底方向箭头（不再绘制移动轨迹线）
	if not _dead and move_target.is_finite():
		var move_offset := move_target - global_position
		if move_offset.length() > 2.0:
			var direction := move_offset.normalized()
			var arrow_base := Vector2(0.0, body_radius * 1.55 + bob)
			var tip := arrow_base + direction * maxf(7.0, body_radius * 1.8)
			var back_left := arrow_base + direction.rotated(2.55) * maxf(4.0, body_radius)
			var back_right := arrow_base + direction.rotated(-2.55) * maxf(4.0, body_radius)
			draw_colored_polygon(PackedVector2Array([tip, back_left, back_right]), Color(0.10, 0.88, 1.0, 0.88))
			draw_polyline(PackedVector2Array([tip, back_left, back_right, tip]), Color("#dffcff"), 1.0, true)

	if _selected:
		var selection_radius := maxf(7.0, body_radius * 1.65)
		draw_arc(Vector2.ZERO, selection_radius, 0.0, TAU, 40, Color(0.45, 0.96, 1.0, 0.85), 1.6)
		draw_circle(Vector2.ZERO, selection_radius, Color(0.45, 0.96, 1.0, 0.08))

	# 地面影子始终保留；有像素精灵时跳过旧占位圆形身体。
	draw_circle(Vector2(0.0, body_radius * 1.2 + bob), body_radius * 0.95, Color(0.01, 0.04, 0.09, 0.35))
	if _sprite == null:
		for angle_index in range(6):
			var angle := TAU * float(angle_index) / 6.0
			draw_line(Vector2(0.0, bob), Vector2.from_angle(angle) * (body_radius * 1.55), Color(0.73, 0.96, 1.0, 0.7), 1.2)
		draw_circle(Vector2(0.0, bob), body_radius * 1.18, Color("#f4ffff"))
		var body_color := Color("#69c9f1")
		if _dead:
			body_color = Color("#5a6b7d")
		elif _flash_remaining > 0.0:
			body_color = body_color.lerp(Color.WHITE, 0.8)
		draw_circle(Vector2(0.0, bob + body_radius * 0.12), body_radius, body_color)
		draw_circle(Vector2(-body_radius * 0.38, -body_radius * 0.38 + bob), maxf(0.8, body_radius * 0.2), Color("#173752"))
		draw_circle(Vector2(body_radius * 0.38, -body_radius * 0.38 + bob), maxf(0.8, body_radius * 0.2), Color("#173752"))
		if _dead:
			draw_line(Vector2(-body_radius * 0.45, -body_radius * 0.1 + bob), Vector2(body_radius * 0.45, -body_radius * 0.1 + bob), Color("#173752"), 1.5)
		else:
			draw_arc(Vector2(0.0, body_radius * 0.34 + bob), body_radius * 0.45, 0.2, PI - 0.2, 12, Color("#173752"), 1.2)
		draw_string(ThemeDB.fallback_font, Vector2(-body_radius * 0.42, body_radius * 0.52 + bob), "⑨", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#f7ffff"))
	draw_string(ThemeDB.fallback_font, Vector2(-body_radius * 2.0, body_radius * 2.5), "琪露诺", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#e8fcff"))

	# 英雄血条只显示在顶部 HUD，世界内不再绘制，避免遮挡战场。
