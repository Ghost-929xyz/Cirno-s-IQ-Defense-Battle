class_name WaveCatalog
extends RefCounted

const DATA := [
	{
		"name": "露水妖精来敲门",
		"groups": [
			{"enemy_id": "dew_fairy", "count": 9, "interval": 0.72, "delay": 0.0},
		],
		"hp_scale": 1.0,
	},
	{
		"name": "风妖精抢跑",
		"groups": [
			{"enemy_id": "dew_fairy", "count": 7, "interval": 0.78, "delay": 0.0},
			{"enemy_id": "wind_fairy", "count": 6, "interval": 0.48, "delay": 3.8},
		],
		"hp_scale": 1.02,
	},
	{
		"name": "岩壳妖精的锅盖",
		"groups": [
			{"enemy_id": "dew_fairy", "count": 9, "interval": 0.62, "delay": 0.0},
			{"enemy_id": "stone_fairy", "count": 5, "interval": 1.45, "delay": 2.4},
		],
		"hp_scale": 1.06,
	},
	{
		"name": "雾之湖大合唱",
		"groups": [
			{"enemy_id": "wind_fairy", "count": 12, "interval": 0.38, "delay": 0.0},
			{"enemy_id": "dew_fairy", "count": 12, "interval": 0.52, "delay": 1.8},
			{"enemy_id": "stone_fairy", "count": 4, "interval": 1.4, "delay": 5.0},
		],
		"hp_scale": 1.10,
	},
	{
		"name": "霜灵妖精不认冻",
		"groups": [
			{"enemy_id": "frost_fairy", "count": 9, "interval": 0.86, "delay": 0.0},
			{"enemy_id": "wind_fairy", "count": 10, "interval": 0.42, "delay": 2.0},
			{"enemy_id": "fairy_captain", "count": 1, "interval": 1.0, "delay": 6.0},
		],
		"hp_scale": 1.14,
	},
	{
		"name": "兵营检验战",
		"groups": [
			{"enemy_id": "stone_fairy", "count": 8, "interval": 1.05, "delay": 0.0},
			{"enemy_id": "dew_fairy", "count": 15, "interval": 0.42, "delay": 2.2},
			{"enemy_id": "frost_fairy", "count": 6, "interval": 1.0, "delay": 5.0},
		],
		"hp_scale": 1.20,
	},
	{
		"name": "妖精队长的巡游",
		"groups": [
			{"enemy_id": "fairy_captain", "count": 2, "interval": 3.5, "delay": 0.0},
			{"enemy_id": "wind_fairy", "count": 16, "interval": 0.34, "delay": 1.5},
			{"enemy_id": "stone_fairy", "count": 6, "interval": 1.15, "delay": 4.5},
		],
		"hp_scale": 1.25,
	},
	{
		"name": "双重冻气回响",
		"groups": [
			{"enemy_id": "frost_fairy", "count": 12, "interval": 0.72, "delay": 0.0},
			{"enemy_id": "dew_fairy", "count": 20, "interval": 0.34, "delay": 2.0},
			{"enemy_id": "fairy_captain", "count": 2, "interval": 4.0, "delay": 6.0},
		],
		"hp_scale": 1.32,
	},
	{
		"name": "幻想乡全员找上门",
		"groups": [
			{"enemy_id": "stone_fairy", "count": 10, "interval": 0.80, "delay": 0.0},
			{"enemy_id": "wind_fairy", "count": 18, "interval": 0.30, "delay": 2.0},
			{"enemy_id": "frost_fairy", "count": 10, "interval": 0.72, "delay": 4.5},
			{"enemy_id": "fairy_captain", "count": 3, "interval": 2.8, "delay": 7.0},
		],
		"hp_scale": 1.40,
	},
	{
		"name": "博丽灵梦亲自上门",
		"groups": [
			{"enemy_id": "dew_fairy", "count": 14, "interval": 0.42, "delay": 0.0},
			{"enemy_id": "frost_fairy", "count": 8, "interval": 0.78, "delay": 2.5},
			{"enemy_id": "fairy_captain", "count": 2, "interval": 3.2, "delay": 5.5},
			{"enemy_id": "reimu", "count": 1, "interval": 1.0, "delay": 10.0},
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
