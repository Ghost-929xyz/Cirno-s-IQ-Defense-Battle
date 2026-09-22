class_name UpgradeManager
extends RefCounted

var modifiers := {
	"damage_multiplier": 1.0,
	"attack_speed_multiplier": 1.0,
	"slow_bonus": 0.0,
	"frost_regen_multiplier": 1.0,
	"splash_multiplier": 1.0,
	"iq_max_add": 0,
}

var stacks := {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func get_choices(count: int = 3) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for raw_definition in UpgradeCatalog.get_all():
		var definition: Dictionary = raw_definition
		var upgrade_id := str(definition.get("id", ""))
		var current_stacks := int(stacks.get(upgrade_id, 0))
		if current_stacks < int(definition.get("max_stacks", 1)):
			available.append(definition)

	var choices: Array[Dictionary] = []
	while choices.size() < count and not available.is_empty():
		var index := _rng.randi_range(0, available.size() - 1)
		choices.append(available.pop_at(index))
	return choices


func apply_upgrade(upgrade_id: String) -> Dictionary:
	var definition := UpgradeCatalog.get_definition(upgrade_id)
	if definition.is_empty():
		return {}
	var current_stacks := int(stacks.get(upgrade_id, 0))
	var max_stacks := int(definition.get("max_stacks", 1))
	if current_stacks >= max_stacks:
		return {}

	stacks[upgrade_id] = current_stacks + 1
	var effects: Dictionary = definition.get("effects", {})
	for effect_key in effects:
		var value := float(effects[effect_key])
		match str(effect_key):
			"damage_multiplier_add":
				modifiers["damage_multiplier"] = float(modifiers["damage_multiplier"]) + value
			"slow_bonus_add":
				modifiers["slow_bonus"] = float(modifiers["slow_bonus"]) + value
			"frost_regen_multiplier_add":
				modifiers["frost_regen_multiplier"] = float(modifiers["frost_regen_multiplier"]) + value
			"splash_multiplier_add":
				modifiers["splash_multiplier"] = float(modifiers["splash_multiplier"]) + value
			"iq_max_add":
				modifiers["iq_max_add"] = int(modifiers["iq_max_add"]) + int(value)
	return definition


func get_stacks(upgrade_id: String) -> int:
	return int(stacks.get(upgrade_id, 0))
