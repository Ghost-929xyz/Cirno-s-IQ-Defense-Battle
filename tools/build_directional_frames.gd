extends SceneTree
## Derive atlas rectangles/foot anchors without changing the generated PNG.
const SOURCE := "res://assets/sprites/troops_vertical_walk.png"

func _initialize() -> void:
	var image := Image.load_from_file(SOURCE)
	var bands: Array = []
	var beginning := -1
	for y in image.get_height():
		var pixels := 0
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.45: pixels += 1
		if pixels >= 6 and beginning == -1: beginning = y
		elif pixels < 6 and beginning != -1:
			if y - beginning >= 15: bands.append([beginning, y])
			beginning = -1
	if beginning != -1: bands.append([beginning, image.get_height()])
	if bands.size() != 8:
		push_error("Expected 8 separated sprite rows, got " + str(bands))
		quit(1)
		return
	var rows: Array = []
	var reference_heights := [86.0, 86.0, 80.0, 80.0, 60.0, 60.0, 88.0, 88.0]
	var width := image.get_width() / 6
	for row in 8:
		var entries: Array = []
		var heights: Array = []
		for column in 6:
			var low := Vector2i(image.get_width(), image.get_height())
			var high := Vector2i.ZERO
			for y in range(bands[row][0], bands[row][1]):
				for x in range(column * width, (column + 1) * width):
					if image.get_pixel(x, y).a < 0.45: continue
					low = low.min(Vector2i(x, y))
					high = high.max(Vector2i(x, y))
			var left := image.get_width()
			var right := 0
			for y in range(high.y - 3, high.y + 1):
				for x in range(low.x, high.x + 1):
					if image.get_pixel(x, y).a < 0.6: continue
					left = mini(left, x)
					right = maxi(right, x)
			var region := Rect2i(Vector2i(maxi(0, low.x - 4), maxi(0, low.y - 4)), high - low + Vector2i(9, 9))
			region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			entries.append({"region": [region.position.x, region.position.y, region.size.x, region.size.y], "anchor": [(left + right) * 0.5 - region.position.x, high.y + 1 - region.position.y]})
			heights.append(high.y - low.y + 1)
		heights.sort()
		rows.append({"scale": reference_heights[row] / float(heights[3]), "frames": entries})
	var file := FileAccess.open("res://assets/sprites/troops_vertical_walk.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"columns": 6, "rows": rows, "source": SOURCE}, "\t"))
	print("DIRECTIONAL_ATLAS_READY rows=8 frames=48 bands=", bands)
	quit()
