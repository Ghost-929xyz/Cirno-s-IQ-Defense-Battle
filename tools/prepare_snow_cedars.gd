extends SceneTree
## Pack the three approved sprites on the existing tree grid without repainting.
## Preserve the original trunk baseline and the harvested stump at frame 8.
const SOURCE := "res://assets/terrain/snow_cedars_source.png"
const OUTPUT := "res://assets/terrain/snow_cedars.png"
const ORIGINAL := "res://assets/tiny_swords/Resources/Trees/Tree.png"
const CELL := Vector2i(192,192)

func _initialize() -> void:
	var original := Image.load_from_file(ORIGINAL)
	var source := Image.load_from_file(SOURCE)
	if original == null or source == null:
		quit(1)
		return
	var atlas := Image.create(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8)
	var old_bounds := original.get_region(Rect2i(Vector2i.ZERO,CELL)).get_used_rect()
	var source_width := source.get_width()/3
	print("SNOW_CEDAR_SOURCE size=",source.get_size()," old_bounds=",old_bounds)
	for variant in 3:
		var region := source.get_region(Rect2i(variant*source_width,0,source_width,source.get_height()))
		# Ignore nearly transparent generation specks when locating the subject.
		# Keep the cropped sprite's original alpha; this only finds its bounds.
		var bounds := subject_bounds(region)
		var cropped := region.get_region(bounds)
		var width := roundi(float(cropped.get_width())*old_bounds.size.y/cropped.get_height())
		cropped.resize(width,old_bounds.size.y,Image.INTERPOLATE_NEAREST)
		var at := Vector2i(variant*CELL.x+(CELL.x-width)/2,old_bounds.end.y-cropped.get_height())
		atlas.blit_rect(cropped,Rect2i(Vector2i.ZERO,cropped.get_size()),at)
		print("SNOW_CEDAR variant=",variant," size=",cropped.get_size()," baseline=",old_bounds.end.y)
	atlas.blit_rect(original,Rect2i(0,CELL.y*2,CELL.x,CELL.y),Vector2i(0,CELL.y*2))
	var error := atlas.save_png(OUTPUT)
	print("SNOW_CEDAR_ATLAS size=",atlas.get_size()," error=",error)
	quit(0 if error == OK else 1)

func subject_bounds(image: Image) -> Rect2i:
	var start := image.get_size()
	var end := Vector2i.ZERO
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a < 0.5: continue
			start.x = mini(start.x,x)
			start.y = mini(start.y,y)
			end.x = maxi(end.x,x+1)
			end.y = maxi(end.y,y+1)
	return Rect2i(start,end-start)
