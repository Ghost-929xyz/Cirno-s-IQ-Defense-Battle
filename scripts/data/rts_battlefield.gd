extends RefCounted
## Shared topology for the editable map, simulation, previews and migration.
const WIDTH := 80
const HEIGHT := 50
const VERSION := 2
const CENTRAL_BASE := Vector2(40, 25)
const BASE_SITES := [Vector2(8, 10), Vector2(8, 25), Vector2(8, 40)]
const HOUSES := [Vector2(27, 10), Vector2(29, 27), Vector2(27, 40), Vector2(56, 25), Vector2(65, 34)]
const CAMPS := [Vector2(72, 7), Vector2(73, 40)]
const CHESTS := [Vector2(14, 6), Vector2(30, 17), Vector2(13, 43), Vector2(48, 8), Vector2(54, 25), Vector2(62, 36), Vector2(73, 25)]
const WILDLIFE := [Vector2(30, 18), Vector2(48, 9), Vector2(62, 37), Vector2(54, 24)]
const ROUTES := [
	[Vector2i(8, 10), Vector2i(28, 10), Vector2i(28, 8), Vector2i(47, 8), Vector2i(47, 10), Vector2i(61, 10), Vector2i(61, 7), Vector2i(74, 7)],
	[Vector2i(8, 25), Vector2i(30, 25), Vector2i(30, 26), Vector2i(48, 26), Vector2i(48, 34), Vector2i(66, 34), Vector2i(66, 25), Vector2i(76, 25)],
	[Vector2i(8, 40), Vector2i(28, 40), Vector2i(28, 42), Vector2i(47, 42), Vector2i(47, 40), Vector2i(74, 40)],
	[Vector2i(12, 10), Vector2i(12, 40)],
	[Vector2i(30, 10), Vector2i(30, 40)],
	[Vector2i(48, 8), Vector2i(48, 40)],
	[Vector2i(74, 7), Vector2i(74, 40)],
]

static func river_center(y: int) -> int:
	# Keep both rows of each bridge aligned, then curve between the crossings.
	if y in [10, 11]: return 42
	if y in [25, 26]: return 37
	if y in [40, 41]: return 39
	return 39 + roundi(3.0 * sin(float(y) * 0.16))

static func crossing(cell: Vector2i) -> bool:
	return cell.y in [10, 11, 25, 26, 40, 41] and absi(cell.x - river_center(cell.y)) <= 1

static func water(cell: Vector2i) -> bool:
	if Vector2(cell).distance_to(CENTRAL_BASE) <= 7.0: return false
	if cell.x < 2 or cell.y < 2 or cell.x >= WIDTH - 2 or cell.y >= HEIGHT - 2: return true
	if crossing(cell): return false
	if absi(cell.x - river_center(cell.y)) <= 1: return true
	# Lakes force northern and southern approaches to bend around their shores.
	if lake(cell, Vector2(23, 18), Vector2(5.5, 4.5)): return true
	if lake(cell, Vector2(21, 35), Vector2(5.5, 3.5)): return true
	if lake(cell, Vector2(67, 16), Vector2(4.5, 4.0)): return true
	# A closed moat leaves the shrine island accessible only through ice magic.
	return ((cell.x in [51, 59] and cell.y >= 20 and cell.y <= 30)
		or (cell.y in [20, 30] and cell.x >= 51 and cell.x <= 59))

static func lake(cell: Vector2i, center: Vector2, radius: Vector2) -> bool:
	var offset := (Vector2(cell) - center) / radius
	return offset.length_squared() < 0.9 + 0.12 * sin(float(cell.x + cell.y) * 1.3)

static func road_cells() -> Dictionary:
	var cells: Dictionary = {}
	for route in ROUTES:
		for i in range(1, route.size()):
			var p: Vector2i = route[i - 1]
			var end: Vector2i = route[i]
			while true:
				for offset in [Vector2i.ZERO, Vector2i.DOWN]:
					var cell: Vector2i = p + offset
					if not water(cell) and not crossing(cell): cells[cell] = true
				if p == end: break
				p += Vector2i(signi(end.x - p.x), signi(end.y - p.y))
	# Bridge approaches remain visibly connected even where the river bends.
	for y in [10, 11, 25, 26, 40, 41]:
		for x in range(32, 49):
			var cell := Vector2i(x, y)
			if not water(cell) and not crossing(cell): cells[cell] = true
	return cells
