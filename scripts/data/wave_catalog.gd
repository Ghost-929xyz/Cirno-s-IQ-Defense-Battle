class_name WaveCatalog
extends RefCounted

const DATA := [
	{
		"name": "迷路的蝌蚪",
		"groups": [
			{"enemy_id": "tadpole", "count": 8, "interval": 0.75, "delay": 0.0},
		],
		"hp_scale": 1.0,
	},
	{
		"name": "跳跳蛙先遣队",
		"groups": [
			{"enemy_id": "tadpole", "count": 6, "interval": 0.85, "delay": 0.0},
			{"enemy_id": "jumper", "count": 5, "interval": 0.55, "delay": 4.0},
		],
		"hp_scale": 1.05,
	},
	{
		"name": "铁甲蛙的锅盖",
		"groups": [
			{"enemy_id": "tadpole", "count": 8, "interval": 0.70, "delay": 0.0},
			{"enemy_id": "armored", "count": 4, "interval": 1.80, "delay": 2.5},
		],
		"hp_scale": 1.1,
	},
	{
		"name": "蛙群大合唱",
		"groups": [
			{"enemy_id": "jumper", "count": 10, "interval": 0.42, "delay": 0.0},
			{"enemy_id": "tadpole", "count": 10, "interval": 0.58, "delay": 2.0},
			{"enemy_id": "armored", "count": 3, "interval": 1.60, "delay": 5.0},
		],
		"hp_scale": 1.15,
	},
	{
		"name": "冰肤蛙不认冻",
		"groups": [
			{"enemy_id": "ice_skin", "count": 8, "interval": 1.0, "delay": 0.0},
			{"enemy_id": "jumper", "count": 9, "interval": 0.45, "delay": 2.0},
			{"enemy_id": "armored", "count": 4, "interval": 1.5, "delay": 4.0},
		],
		"hp_scale": 1.2,
	},
	{
		"name": "雾之湖蛙王",
		"groups": [
			{"enemy_id": "tadpole", "count": 12, "interval": 0.48, "delay": 0.0},
			{"enemy_id": "frog_king", "count": 1, "interval": 1.0, "delay": 5.0},
			{"enemy_id": "ice_skin", "count": 5, "interval": 1.1, "delay": 7.0},
		],
		"hp_scale": 1.0,
	},
]


static func get_wave(index: int) -> Dictionary:
	if index < 0 or index >= DATA.size():
		return {}
	return DATA[index].duplicate(true)


static func wave_count() -> int:
	return DATA.size()
