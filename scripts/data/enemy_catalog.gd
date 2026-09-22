class_name EnemyCatalog
extends RefCounted

const DATA := {
	"tadpole": {
		"id": "tadpole",
		"name": "蝌蚪",
		"max_hp": 45.0,
		"speed": 60.0,
		"armor": 0.0,
		"reward": 8,
		"iq_damage": 1,
		"slow_resistance": 0.0,
		"radius": 13.0,
		"color": "#7fc86b",
	},
	"jumper": {
		"id": "jumper",
		"name": "跳跳蛙",
		"max_hp": 34.0,
		"speed": 95.0,
		"armor": 0.0,
		"reward": 9,
		"iq_damage": 1,
		"slow_resistance": 0.0,
		"radius": 12.0,
		"color": "#d4dc5d",
	},
	"armored": {
		"id": "armored",
		"name": "铁甲蛙",
		"max_hp": 115.0,
		"speed": 42.0,
		"armor": 3.0,
		"reward": 12,
		"iq_damage": 2,
		"slow_resistance": 0.0,
		"radius": 17.0,
		"color": "#899a73",
	},
	"ice_skin": {
		"id": "ice_skin",
		"name": "冰肤蛙",
		"max_hp": 85.0,
		"speed": 55.0,
		"armor": 2.0,
		"reward": 11,
		"iq_damage": 2,
		"slow_resistance": 0.65,
		"radius": 15.0,
		"color": "#72d8d1",
	},
	"frog_king": {
		"id": "frog_king",
		"name": "雾之湖蛙王",
		"max_hp": 700.0,
		"speed": 32.0,
		"armor": 5.0,
		"reward": 80,
		"iq_damage": 5,
		"slow_resistance": 0.7,
		"radius": 28.0,
		"color": "#556d4a",
	},
}


static func get_definition(enemy_id: String) -> Dictionary:
	return DATA.get(enemy_id, {}).duplicate(true)
