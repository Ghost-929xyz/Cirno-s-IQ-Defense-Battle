class_name UpgradeManager
extends RefCounted

var modifiers := {
	"tower_damage_multiplier": 1.0,
	"tower_attack_speed_multiplier": 1.0,
	"tower_health_multiplier": 1.0,
	"ally_damage_multiplier": 1.0,
	"ally_attack_speed_multiplier": 1.0,
	"ally_health_multiplier": 1.0,
	"hero_damage_multiplier": 1.0,
	"hero_attack_speed_multiplier": 1.0,
	"hero_cooldown_multiplier": 1.0,
	"slow_bonus": 0.0,
	"splash_multiplier": 1.0,
	"frost_regen_multiplier": 1.0,
	"iq_max_add": 0,
	"build_cost_multiplier": 1.0,
}

var stacks := {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func get_choices(pool: String, count: int = 3) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for raw_definition in UpgradeCatalog.get_pool(pool):
		var definition: Dictionary = raw_definition
		var upgrade_id := str(definition.get("id", ""))
		var current_stacks := int(stacks.get(_stack_key(pool, upgrade_id), 0))
		if current_stacks < int(definition.get("max_stacks", 1)):
			available.append(definition)

	var choices: Array[Dictionary] = []
	while choices.size() < count and not available.is_empty():
		var index := _rng.randi_range(0, available.size() - 1)
		choices.append(available.pop_at(index))
	return choices


func apply_upgrade(pool: String, upgrade_id: String) -> Dictionary:
	var definition := UpgradeCatalog.get_definition(pool, upgrade_id)
	if definition.is_empty():
		return {}
	var key := _stack_key(pool, upgrade_id)
	var current_stacks := int(stacks.get(key, 0))
	var max_stacks := int(definition.get("max_stacks", 1))
	if current_stacks >= max_stacks:
		return {}

	stacks[key] = current_stacks + 1
	var effects: Dictionary = definition.get("effects", {})
	for effect_key in effects:
		_apply_effect(str(effect_key), float(effects[effect_key]))
	return definition


func get_stacks(pool: String, upgrade_id: String) -> int:
	return int(stacks.get(_stack_key(pool, upgrade_id), 0))


func _apply_effect(effect_key: String, value: float) -> void:
	match effect_key:
		"tower_damage_multiplier_add":
			modifiers["tower_damage_multiplier"] = float(modifiers["tower_damage_multiplier"]) + value
		"tower_attack_speed_multiplier_add":
			modifiers["tower_attack_speed_multiplier"] = float(modifiers["tower_attack_speed_multiplier"]) + value
		"tower_health_multiplier_add":
			modifiers["tower_health_multiplier"] = float(modifiers["tower_health_multiplier"]) + value
		"ally_damage_multiplier_add":
			modifiers["ally_damage_multiplier"] = float(modifiers["ally_damage_multiplier"]) + value
		"ally_attack_speed_multiplier_add":
			modifiers["ally_attack_speed_multiplier"] = float(modifiers["ally_attack_speed_multiplier"]) + value
		"ally_health_multiplier_add":
			modifiers["ally_health_multiplier"] = float(modifiers["ally_health_multiplier"]) + value
		"hero_damage_multiplier_add":
			modifiers["hero_damage_multiplier"] = float(modifiers["hero_damage_multiplier"]) + value
		"hero_attack_speed_multiplier_add":
			modifiers["hero_attack_speed_multiplier"] = float(modifiers["hero_attack_speed_multiplier"]) + value
		"hero_cooldown_multiplier_add":
			modifiers["hero_cooldown_multiplier"] = clampf(float(modifiers["hero_cooldown_multiplier"]) + value, 0.5, 1.0)
		"slow_bonus_add":
			modifiers["slow_bonus"] = minf(0.55, float(modifiers["slow_bonus"]) + value)
		"splash_multiplier_add":
			modifiers["splash_multiplier"] = float(modifiers["splash_multiplier"]) + value
		"frost_regen_multiplier_add":
			modifiers["frost_regen_multiplier"] = float(modifiers["frost_regen_multiplier"]) + value
		"iq_max_add":
			modifiers["iq_max_add"] = int(modifiers["iq_max_add"]) + int(value)
		"build_cost_multiplier_add":
			modifiers["build_cost_multiplier"] = clampf(float(modifiers["build_cost_multiplier"]) + value, 0.55, 1.25)
		_:
			pass


func _stack_key(pool: String, upgrade_id: String) -> String:
	return "%s:%s" % [pool, upgrade_id]
