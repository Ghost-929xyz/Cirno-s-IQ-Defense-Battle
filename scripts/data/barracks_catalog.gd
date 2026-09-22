class_name BarracksCatalog
extends RefCounted

const ORDER := ["guard_barracks", "archer_barracks", "mage_barracks"]
const DATA := {
	"guard_barracks": {
		"id": "guard_barracks",
		"category": "barracks",
		"name": "冰晶兵营",
		"role": "近卫召唤",
		"short": "卫",
		"description": "定期召唤冰晶近卫，在前排截停妖精。",
		"unit_id": "ice_guard",
		"cost": 65,
		"max_hp": 175.0,
		"armor": 2.0,
		"spawn_interval": 7.0,
		"max_units": 3,
		"color": "#61b9f0",
	},
	"archer_barracks": {
		"id": "archer_barracks",
		"category": "barracks",
		"name": "雾矢兵营",
		"role": "远程召唤",
		"short": "弓",
		"description": "定期召唤雾矢射手，压制路过的单体目标。",
		"unit_id": "mist_archer",
		"cost": 75,
		"max_hp": 150.0,
		"armor": 1.0,
		"spawn_interval": 6.0,
		"max_units": 4,
		"color": "#7fd5d0",
	},
	"mage_barracks": {
		"id": "mage_barracks",
		"category": "barracks",
		"name": "暴雪兵营",
		"role": "范围召唤",
		"short": "法",
		"description": "定期召唤暴雪术士，用范围冰爆清理妖精群。",
		"unit_id": "blizzard_mage",
		"cost": 85,
		"max_hp": 160.0,
		"armor": 1.0,
		"spawn_interval": 8.0,
		"max_units": 3,
		"color": "#a98df4",
	},
}


static func get_definition(barracks_id: String) -> Dictionary:
	return DATA.get(barracks_id, {}).duplicate(true)
