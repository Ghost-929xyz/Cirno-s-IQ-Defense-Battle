class_name GameMetrics
extends RefCounted

## 高密度地图统一尺度。
## 256×192 的像素画按 2×2 像素取样，因此地图是 128×96 个逻辑格。
## 每格 12px：琪露诺 24×24 精灵恰好 1:1 原比例显示（高约 2 格），
## 整个世界 1536×1152，比窗口大，由 Camera2D 平移查看。
const MAP_COLS := 128
const MAP_ROWS := 96
const CELL_SIZE := 12.0
const MAP_SCREEN_SIZE := Vector2(MAP_COLS * CELL_SIZE, MAP_ROWS * CELL_SIZE)

## 旧版本每格 600/128 px，世界缩放系数，战斗距离与移动速度按此同步放大。
const LEGACY_CELL_SIZE := 600.0 / 128.0
const WORLD_SCALE := CELL_SIZE / LEGACY_CELL_SIZE

## 旧战斗数值与旧美术原本按 600×450 画面、每格 30px 设计。
const REFERENCE_CELL_SIZE := 30.0
const ART_SCALE := CELL_SIZE / REFERENCE_CELL_SIZE


static func cells(value: float) -> float:
	return float(value) * CELL_SIZE


static func art(value: float) -> float:
	return float(value) * ART_SCALE


## 战斗距离随世界比例放大，保持与地图的相对关系不变。
const COMBAT_RANGE_SCALE := WORLD_SCALE


static func combat_range(value: float) -> float:
	return float(value) * COMBAT_RANGE_SCALE


## 移动/投射物速度（px/s）同样随世界比例放大。
static func speed(value: float) -> float:
	return float(value) * COMBAT_RANGE_SCALE


static func art_min(value: float, minimum: float = 1.0) -> float:
	return maxf(minimum, art(value))
