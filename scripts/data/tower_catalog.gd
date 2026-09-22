class_name TowerCatalog
extends RefCounted

const ORDER: Array[String] = ["icicle", "rime", "baka"]

const DATA := {
	"icicle": {
		"id": "icicle",
		"name": "冰锥琪露诺",
		"role": "单体输出",
		"short": "冰",
		"description": "便宜的稳定单体伤害，射程优秀。",
		"cost": 30,
		"range_cells": 2.8,
		"damage": 14.0,
		"cooldown": 0.85,
		"projectile_speed": 440.0,
		"attack_kind": "single",
		"splash_radius": 0.0,
		"slow_factor": 1.0,
		"slow_duration": 0.0,
		"color": "#8fe9ff",
	},
	"rime": {
		"id": "rime",
		"name": "雾凇琪露诺",
		"role": "范围减速",
		"short": "凇",
		"description": "低伤害范围命中，令蛙群明显减速。",
		"cost": 45,
		"range_cells": 2.5,
		"damage": 8.0,
		"cooldown": 1.1,
		"projectile_speed": 320.0,
		"attack_kind": "splash",
		"splash_radius": 60.0,
		"slow_factor": 0.65,
		"slow_duration": 2.5,
		"color": "#b8f4ff",
	},
	"baka": {
		"id": "baka",
		"name": "⑨炮琪露诺",
		"role": "范围爆发",
		"short": "⑨",
		"description": "攻速缓慢，但单发和溅射范围都很大。",
		"cost": 70,
		"range_cells": 2.4,
		"damage": 34.0,
		"cooldown": 2.2,
		"projectile_speed": 290.0,
		"attack_kind": "splash",
		"splash_radius": 90.0,
		"slow_factor": 1.0,
		"slow_duration": 0.0,
		"color": "#5ecdf4",
	},
}


static func get_definition(tower_id: String) -> Dictionary:
	return DATA.get(tower_id, {}).duplicate(true)
