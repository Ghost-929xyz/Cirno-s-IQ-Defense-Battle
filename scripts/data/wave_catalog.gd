class_name WaveCatalog
extends RefCounted

## 十波配置：每个分组指定 entrance（west / north / south / east）出兵方向。
## 第 2 波引入北口，第 4 波引入南口，第 7 波引入东口，之后四路齐发。

const DATA := [
	{
		"name": "露水妖精来敲门",
		"groups": [
			{"enemy_id": "dew_fairy", "count": 12, "interval": 0.60, "delay": 0.0, "entrance": "west"},
		],
		"hp_scale": 1.00,
	},
	{
		"name": "风妖精抢跑",
		"groups": [
			{"enemy_id": "dew_fairy", "count": 8, "interval": 0.70, "delay": 0.0, "entrance": "west"},
			{"enemy_id": "wind_fairy", "count": 6, "interval": 0.45, "delay": 3.0, "entrance": "north"},
		],
		"hp_scale": 1.05,
	},
	{
		"name": "岩壳妖精的锅盖",
		"groups": [
			{"enemy_id": "dew_fairy", "count": 8, "interval": 0.55, "delay": 0.0, "entrance": "north"},
			{"enemy_id": "stone_fairy", "count": 6, "interval": 1.30, "delay": 2.0, "entrance": "west"},
		],
		"hp_scale": 1.10,
	},
	{
		"name": "雾之湖大合唱",
		"groups": [
			{"enemy_id": "wind_fairy", "count": 10, "interval": 0.40, "delay": 0.0, "entrance": "west"},
			{"enemy_id": "dew_fairy", "count": 10, "interval": 0.50, "delay": 1.5, "entrance": "north"},
			{"enemy_id": "stone_fairy", "count": 5, "interval": 1.25, "delay": 4.0, "entrance": "south"},
		],
		"hp_scale": 1.16,
	},
	{
		"name": "霜灵妖精不认冻",
		"groups": [
			{"enemy_id": "frost_fairy", "count": 8, "interval": 0.80, "delay": 0.0, "entrance": "north"},
			{"enemy_id": "wind_fairy", "count": 9, "interval": 0.40, "delay": 2.0, "entrance": "south"},
			{"enemy_id": "fairy_captain", "count": 1, "interval": 1.0, "delay": 6.0, "entrance": "west"},
		],
		"hp_scale": 1.22,
	},
	{
		"name": "兵营检验战",
		"groups": [
			{"enemy_id": "stone_fairy", "count": 8, "interval": 1.00, "delay": 0.0, "entrance": "south"},
			{"enemy_id": "dew_fairy", "count": 14, "interval": 0.42, "delay": 2.0, "entrance": "west"},
			{"enemy_id": "frost_fairy", "count": 6, "interval": 0.95, "delay": 5.0, "entrance": "north"},
		],
		"hp_scale": 1.28,
	},
	{
		"name": "妖精队长的巡游",
		"groups": [
			{"enemy_id": "fairy_captain", "count": 2, "interval": 3.2, "delay": 0.0, "entrance": "west"},
			{"enemy_id": "wind_fairy", "count": 14, "interval": 0.34, "delay": 1.5, "entrance": "north"},
			{"enemy_id": "stone_fairy", "count": 6, "interval": 1.10, "delay": 4.5, "entrance": "south"},
			{"enemy_id": "dew_fairy", "count": 8, "interval": 0.55, "delay": 3.0, "entrance": "east"},
		],
		"hp_scale": 1.34,
	},
	{
		"name": "双重冻气回响",
		"groups": [
			{"enemy_id": "frost_fairy", "count": 10, "interval": 0.70, "delay": 0.0, "entrance": "east"},
			{"enemy_id": "dew_fairy", "count": 18, "interval": 0.34, "delay": 2.0, "entrance": "west"},
			{"enemy_id": "fairy_captain", "count": 2, "interval": 4.0, "delay": 6.0, "entrance": "north"},
		],
		"hp_scale": 1.42,
	},
	{
		"name": "幻想乡全员找上门",
		"groups": [
			{"enemy_id": "stone_fairy", "count": 10, "interval": 0.78, "delay": 0.0, "entrance": "west"},
			{"enemy_id": "wind_fairy", "count": 16, "interval": 0.30, "delay": 2.0, "entrance": "north"},
			{"enemy_id": "frost_fairy", "count": 10, "interval": 0.70, "delay": 4.5, "entrance": "south"},
			{"enemy_id": "fairy_captain", "count": 3, "interval": 2.8, "delay": 7.0, "entrance": "east"},
		],
		"hp_scale": 1.50,
	},
	{
		"name": "博丽灵梦亲自上门",
		"groups": [
			{"enemy_id": "dew_fairy", "count": 14, "interval": 0.42, "delay": 0.0, "entrance": "west"},
			{"enemy_id": "frost_fairy", "count": 8, "interval": 0.75, "delay": 2.5, "entrance": "north"},
			{"enemy_id": "fairy_captain", "count": 2, "interval": 3.2, "delay": 5.5, "entrance": "south"},
			{"enemy_id": "reimu", "count": 1, "interval": 1.0, "delay": 10.0, "entrance": "east"},
		],
		"hp_scale": 1.00,
	},
]


static func get_wave(index: int) -> Dictionary:
	if index < 0 or index >= DATA.size():
		return {}
	return DATA[index].duplicate(true)


static func wave_count() -> int:
	return DATA.size()
