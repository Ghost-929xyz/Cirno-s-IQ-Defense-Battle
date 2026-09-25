class_name UpgradeCatalog
extends RefCounted

const BLESSINGS := [
	{
		"id": "sharp_icicles",
		"name": "尖锐冰锥",
		"description": "所有防御塔伤害 +20%。",
		"rarity": "普通",
		"max_stacks": 4,
		"effects": {"tower_damage_multiplier_add": 0.20},
	},
	{
		"id": "winter_lesson",
		"name": "冬日补课",
		"description": "每次波末冻气奖励 +40%。",
		"rarity": "普通",
		"max_stacks": 3,
		"effects": {"wave_frost_reward_multiplier_add": 0.40},
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
		"id": "rapid_frost",
		"name": "极速结霜",
		"description": "所有防御塔攻击速度 +12%。",
		"rarity": "普通",
		"max_stacks": 4,
		"effects": {"tower_attack_speed_multiplier_add": 0.12},
	},
	{
		"id": "fairy_drill",
		"name": "妖精操练",
		"description": "己方兵种伤害 +20%。",
		"rarity": "普通",
		"max_stacks": 4,
		"effects": {"ally_damage_multiplier_add": 0.20},
	},
	{
		"id": "stronger_spirits",
		"name": "厚实冰壳",
		"description": "己方兵种最大生命 +20%。",
		"rarity": "普通",
		"max_stacks": 3,
		"effects": {"ally_health_multiplier_add": 0.20},
	},
	{
		"id": "heroic_logic",
		"name": "天才式直觉",
		"description": "琪露诺英雄伤害 +25%。",
		"rarity": "稀有",
		"max_stacks": 4,
		"effects": {"hero_damage_multiplier_add": 0.25},
	},
	{
		"id": "clear_mind",
		"name": "清醒三秒",
		"description": "英雄主动技能冷却 -10%。",
		"rarity": "稀有",
		"max_stacks": 4,
		"effects": {"hero_cooldown_multiplier_add": -0.10},
	},
	{
		"id": "vital_crystal",
		"name": "IQ 结晶扩容",
		"description": "琪露诺最大生命 +30，并立即回复 30 生命。",
		"rarity": "稀有",
		"max_stacks": 3,
		"effects": {"hero_max_hp_add": 30, "heal_now": 30},
	},
	{
		"id": "frozen_economy",
		"name": "冻气精算",
		"description": "所有建筑造价 -8%。",
		"rarity": "稀有",
		"max_stacks": 3,
		"effects": {"build_cost_multiplier_add": -0.08},
	},
]

const ENCHANTS := [
	{
		"id": "crystal_sight",
		"name": "锐霜棱晶",
		"description": "冰晶附魔：防御塔伤害 +30%。",
		"rarity": "冰晶附魔",
		"max_stacks": 3,
		"effects": {"tower_damage_multiplier_add": 0.30},
	},
	{
		"id": "frozen_trigger",
		"name": "霜弦冰晶",
		"description": "冰晶附魔：防御塔攻击速度 +25%。",
		"rarity": "冰晶附魔",
		"max_stacks": 3,
		"effects": {"tower_attack_speed_multiplier_add": 0.25},
	},
	{
		"id": "fairy_warhorn",
		"name": "兵势冰晶",
		"description": "冰晶附魔：己方兵种攻击速度 +25%。",
		"rarity": "冰晶附魔",
		"max_stacks": 3,
		"effects": {"ally_attack_speed_multiplier_add": 0.25},
	},
	{
		"id": "winter_army",
		"name": "冬军冰晶",
		"description": "冰晶附魔：己方兵种生命 +30%。",
		"rarity": "冰晶附魔",
		"max_stacks": 3,
		"effects": {"ally_health_multiplier_add": 0.30},
	},
	{
		"id": "perfect_arithmetic",
		"name": "笨蛋算术冰晶",
		"description": "冰晶附魔：英雄攻击速度 +30%。",
		"rarity": "冰晶附魔",
		"max_stacks": 3,
		"effects": {"hero_attack_speed_multiplier_add": 0.30},
	},
	{
		"id": "snowstorm_core",
		"name": "暴雪核心",
		"description": "冰晶附魔：减速强度 +10%，溅射范围 +15%。",
		"rarity": "冰晶附魔",
		"max_stacks": 3,
		"effects": {"slow_bonus_add": 0.10, "splash_multiplier_add": 0.15},
	},
	{
		"id": "star_ice",
		"name": "明星冰晶",
		"description": "冰晶附魔：英雄技能冷却 -20%。",
		"rarity": "冰晶附魔",
		"max_stacks": 2,
		"effects": {"hero_cooldown_multiplier_add": -0.20},
	},
	{
		"id": "frozen_treasure",
		"name": "冻财冰晶",
		"description": "冰晶附魔：建筑造价 -12%，波末冻气奖励 +10%。",
		"rarity": "冰晶附魔",
		"max_stacks": 2,
		"effects": {"build_cost_multiplier_add": -0.12, "wave_frost_reward_multiplier_add": 0.10},
	},
]


static func get_pool(pool: String) -> Array:
	if pool == "enchant":
		return ENCHANTS.duplicate(true)
	return BLESSINGS.duplicate(true)


static func get_definition(pool: String, upgrade_id: String) -> Dictionary:
	for definition in get_pool(pool):
		if str(definition.get("id", "")) == upgrade_id:
			return definition
	return {}
