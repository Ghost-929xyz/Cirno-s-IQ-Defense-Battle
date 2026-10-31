extends RefCounted
## Values absent from the source documents are deliberately centralized here.
const START_GOLD := 900
const START_BAKA := 100.0
const PREP_SECONDS := 75.0
const WAVE_SECONDS := 55.0
const WAVE_COUNT := 6
const WEAK_RAID_SECONDS := 35.0
const TRAIN_SECONDS := 3.0
const KILL_GOLD_RATIO := 0.45
const TECH_COST := 240
const TIER_COST := 180
const WALL_COST := 25.0
const FREEZE_COST := 20.0
const BRIDGE_COST := 20.0
const WALL_SECONDS := 25.0
const FREEZE_SECONDS := 4.0
const WILDLIFE_BAKA := 15.0
const WILDLIFE_HEAL_RATIO := 0.25
const TREE_WOOD := 20
const TREE_WORK_SECONDS := 6.0
const CAMPFIRE_WOOD := 20
const CAMPFIRE_BUILD_SECONDS := 3.0
const MOUNTED := ["cavalry", "ranger", "lancer", "scout", "cataphract"]
const UNIT_PARENTS := {
	"guard": "swordsman", "paladin": "guard", "heavy_infantry": "guard",
	"sniper": "archer", "sniper_plus": "sniper", "ice_archer": "archer", "ice_archer_plus": "ice_archer",
	"ranger": "cavalry", "scout": "ranger", "lancer": "cavalry", "cataphract": "lancer",
	"hermit": "assassin", "hermit_dodge": "hermit", "hermit_blink": "hermit",
	"berserker": "assassin", "berserker_plus": "berserker",
}
const EXCLUSIVE_BRANCHES := [["paladin", "heavy_infantry"], ["sniper", "ice_archer"], ["ranger", "lancer"], ["hermit", "berserker"], ["hermit_dodge", "hermit_blink"]]

static func body_radius(kind: String) -> float:
	return 0.50 if kind in MOUNTED else 0.34

static func terrain_radius(kind: String) -> float:
	return 0.30 if kind in MOUNTED else 0.16

static func sight_radius(kind: String) -> float:
	return 8.0 if kind == "scout" else 5.0

static func visual_scale(kind: String) -> float:
	return 1.40 if kind in MOUNTED else (1.14 if kind in ["heavy_infantry", "berserker", "berserker_plus"] else 1.0)
## Cells/second: deliberate battle pacing, independent of source workbook units.
const MOVE_SPEEDS := {
	"swordsman": 1.9, "guard": 1.8, "paladin": 1.8, "heavy_infantry": 1.6,
	"archer": 1.8, "sniper": 1.7, "ice_archer": 1.8, "sniper_plus": 1.7, "ice_archer_plus": 1.8,
	"cavalry": 2.5, "ranger": 2.8, "lancer": 2.4, "scout": 2.8, "cataphract": 2.2,
	"assassin": 2.3, "hermit": 2.2, "berserker": 2.1, "hermit_dodge": 2.2, "hermit_blink": 2.2, "berserker_plus": 2.1,
}
const BUILDINGS := {
	"base": {"name": "主基地", "hp": 2000.0, "cost": 0, "beds": 20, "fire": 8},
	"barracks": {"name": "兵营", "hp": 1000.0, "cost": 160, "beds": 10, "fire": 5},
	"well": {"name": "魔力井", "hp": 1000.0, "cost": 200, "beds": 10, "fire": 5},
	"academy": {"name": "科技所", "hp": 1000.0, "cost": 240, "beds": 10, "fire": 5},
	"house": {"name": "房屋", "hp": 1000.0, "cost": 120, "beds": 10, "fire": 5},
	"outpost": {"name": "敌军营地", "hp": 1000.0, "cost": 160, "beds": 10, "fire": 5},
}
const CARDS := [
	{"id": "supplies", "name": "远征补给", "text": "初始金币 +250"},
	{"id": "mana", "name": "冰湖共鸣", "text": "初始 BAKA +50"},
	{"id": "builders", "name": "巧手工匠", "text": "建造与修复效率 +50%"},
	{"id": "vitality", "name": "不屈军团", "text": "己方单位生命 +15%"},
	{"id": "scavenger", "name": "寻宝直觉", "text": "宝箱金币奖励 +50%"},
]

static func catalog() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/rts/units.json"))
	var result: Dictionary = {}
	for unit in data.units:
		unit["source_move_speed"] = unit.move_speed
		unit.move_speed = MOVE_SPEEDS[unit.id]
		result[unit.id] = unit
	return result
