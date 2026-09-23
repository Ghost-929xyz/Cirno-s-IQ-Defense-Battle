class_name AllyCatalog
extends RefCounted

## 己方兵种数值。需求 7：友军整体下调约 25%（约 ×0.75），配合波次数量上调维持压力。

const DATA := {
	"ice_guard": {
		"id": "ice_guard",
		"name": "冰晶近卫",
		"role": "近战/前排",
		"max_hp": 95.0,
		"armor": 2.0,
		"damage": 10.0,
		"attack_interval": 1.05,
		"attack_range": 28.0,
		"move_speed": 76.0,
		"color": "#75c9ff",
		"attack_color": "#d9f7ff",
	},
	"mist_archer": {
		"id": "mist_archer",
		"name": "雾矢射手",
		"role": "远程/单体",
		"max_hp": 54.0,
		"armor": 0.0,
		"damage": 11.0,
		"attack_interval": 0.72,
		"attack_range": 150.0,
		"move_speed": 70.0,
		"projectile_speed": 480.0,
		"color": "#8be3d6",
		"attack_color": "#e7fffb",
	},
	"blizzard_mage": {
		"id": "blizzard_mage",
		"name": "暴雪术士",
		"role": "远程/范围",
		"max_hp": 65.0,
		"armor": 0.0,
		"damage": 15.0,
		"attack_interval": 1.65,
		"attack_range": 135.0,
		"move_speed": 58.0,
		"projectile_speed": 340.0,
		"splash_radius": 54.0,
		"slow_factor": 0.78,
		"slow_duration": 1.2,
		"color": "#aa93f4",
		"attack_color": "#d8ccff",
	},
}


static func get_definition(unit_id: String) -> Dictionary:
	return DATA.get(unit_id, {}).duplicate(true)
