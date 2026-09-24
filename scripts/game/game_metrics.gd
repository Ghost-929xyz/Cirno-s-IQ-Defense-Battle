class_name GameMetrics
extends RefCounted

## 高密度地图统一尺度。
## 256×192 的像素画按 2×2 像素取样，因此地图是 128×96 个逻辑格。
const MAP_SCREEN_SIZE := Vector2(600.0, 450.0)
const MAP_COLS := 128
const MAP_ROWS := 96
const CELL_SIZE := MAP_SCREEN_SIZE.x / float(MAP_COLS)

## 旧战斗数值与旧美术原本按 600×450 画面、每格 30px 设计。
## 战斗距离和速度继续使用屏幕像素，美术尺寸按此比例缩成高密度像素风。
const REFERENCE_CELL_SIZE := 30.0
const ART_SCALE := CELL_SIZE / REFERENCE_CELL_SIZE


static func cells(value: float) -> float:
	return float(value) * CELL_SIZE


static func art(value: float) -> float:
	return float(value) * ART_SCALE


## 战斗距离按原 600×450 屏幕像素尺度，不随逻辑格密度缩小。
const COMBAT_RANGE_SCALE := 1.0


static func combat_range(value: float) -> float:
	return float(value) * COMBAT_RANGE_SCALE


static func art_min(value: float, minimum: float = 1.0) -> float:
	return maxf(minimum, art(value))
