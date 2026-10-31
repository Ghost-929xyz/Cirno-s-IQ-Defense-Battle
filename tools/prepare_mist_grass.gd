extends SceneTree
## Normalize the approved ImageGen atlas to the engine's original tile grid.
## The original alpha mask and untouched sand preserve tile seams and coastlines.
func _initialize() -> void:
	var original := Image.load_from_file("res://assets/tiny_swords/Terrain/Ground/Tilemap_Flat.png")
	var generated := Image.load_from_file("res://assets/terrain/mist_grass_source.png")
	generated.resize(original.get_width(),original.get_height(),Image.INTERPOLATE_NEAREST)
	var result := original.duplicate() as Image
	for y in original.get_height():
		for x in original.get_width()/2:
			var alpha := original.get_pixel(x,y).a
			if alpha == 0: continue
			var pixel := generated.get_pixel(x,y)
			if pixel.a < 0.5:
				var best_distance := INF
				for dy in range(-4,5):
					for dx in range(-4,5):
						var at := Vector2i(x+dx,y+dy)
						if at.x < 0 or at.y < 0 or at.x >= original.get_width()/2 or at.y >= original.get_height(): continue
						var candidate := generated.get_pixelv(at)
						var distance := dx*dx+dy*dy
						if candidate.a >= 0.5 and distance < best_distance:
							best_distance = distance
							pixel = candidate
			pixel.a = alpha
			result.set_pixel(x,y,pixel)
	var error := result.save_png("res://assets/terrain/mist_grass_tiles.png")
	print("MIST_GRASS_ATLAS size=",result.get_size()," error=",error)
	quit(0 if error == OK else 1)
