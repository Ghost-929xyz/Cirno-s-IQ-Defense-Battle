class_name UpgradeCatalog
extends RefCounted

const DATA := [
	{
		"id": "sharp_icicles",
		"name": "尖锐冰锥",
		"description": "所有琪露诺伤害 +20%。",
		"rarity": "普通",
		"max_stacks": 4,
		"effects": {"damage_multiplier_add": 0.20},
	},
	{
		"id": "absolute_zero",
		"name": "绝对零度（自称）",
		"description": "所有减速效果额外降低 8% 速度。",
		"rarity": "稀有",
		"max_stacks": 3,
		"effects": {"slow_bonus_add": 0.08},
	},
	{
		"id": "winter_lesson",
		"name": "冬日补课",
		"description": "布置阶段冻气恢复速度 +40%。",
		"rarity": "普通",
		"max_stacks": 3,
		"effects": {"frost_regen_multiplier_add": 0.40},
	},
	{
		"id": "bigger_baka",
		"name": "更大的笨蛋",
		"description": "所有溅射半径 +20%。",
		"rarity": "普通",
		"max_stacks": 3,
		"effects": {"splash_multiplier_add": 0.20},
	},
	{
		"id": "iq_crystal",
		"name": "IQ 结晶扩容",
		"description": "最大 IQ +5，并立即回复 5 IQ。",
		"rarity": "稀有",
		"max_stacks": 2,
		"effects": {"iq_max_add": 5, "heal_now": 5},
	},
]


static func get_all() -> Array:
	return DATA.duplicate(true)


static func get_definition(upgrade_id: String) -> Dictionary:
	for definition in DATA:
		if definition.id == upgrade_id:
			return definition.duplicate(true)
	return {}
