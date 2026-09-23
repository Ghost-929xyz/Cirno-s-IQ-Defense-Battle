class_name TowerCatalog
extends RefCounted

## 防御塔数值。需求 7：伤害整体下调约 25%（约 ×0.75），生命小幅下调。

const ORDER := ["icicle", "rime", "baka"]
const DATA := {
	"icicle": {
		"id": "icicle",
		"category": "tower",
		"name": "冰锥琪露诺",
		"role": "单体输出",
		"short": "锥",
		"description": "低造价、稳定索敌，适合填补防线空位。",
		"cost": 30,
		"max_hp": 100.0,
		"armor": 0.0,
		"range_cells": 2.7,
		"damage": 11.0,
		"cooldown": 0.85,
		"projectile_speed": 480.0,
		"attack_kind": "single",
		"splash_radius": 0.0,
		"slow_factor": 1.0,
		"slow_duration": 0.0,
		"color": "#75d9ff",
	},
	"rime": {
		"id": "rime",
		"category": "tower",
		"name": "雾凇琪露诺",
		"role": "范围减速",
		"short": "霜",
		"description": "命中小范围目标并施加持续减速。",
		"cost": 45,
		"max_hp": 110.0,
		"armor": 1.0,
		"range_cells": 2.55,
		"damage": 6.0,
		"cooldown": 1.10,
		"projectile_speed": 360.0,
		"attack_kind": "splash",
		"splash_radius": 68.0,
		"slow_factor": 0.62,
		"slow_duration": 2.5,
		"color": "#93efe6",
	},
	"baka": {
		"id": "baka",
		"category": "tower",
		"name": "⑨式冰炮",
		"role": "重型爆发",
		"short": "⑨",
		"description": "攻速慢，但单发伤害和溅射范围很高。",
		"cost": 75,
		"max_hp": 130.0,
		"armor": 2.0,
		"range_cells": 2.4,
		"damage": 27.0,
		"cooldown": 2.20,
		"projectile_speed": 300.0,
		"attack_kind": "splash",
		"splash_radius": 92.0,
		"slow_factor": 1.0,
		"slow_duration": 0.0,
		"color": "#58c8f4",
	},
}


static func get_definition(tower_id: String) -> Dictionary:
	return DATA.get(tower_id, {}).duplicate(true)
