extends SceneTree
## Encode the approved avatar at Windows icon sizes, preserving alpha.
func _initialize() -> void:
	var original := Image.load_from_file("res://assets/ui/cirno_avatar.png")
	var sizes := [16,24,32,48,64,128,256]
	var frames: Array[PackedByteArray] = []
	for extent in sizes:
		var icon := original.duplicate() as Image
		icon.resize(extent,extent,Image.INTERPOLATE_LANCZOS)
		frames.append(icon.save_png_to_buffer())
	var output := FileAccess.open("res://assets/ui/cirno_avatar.ico",FileAccess.WRITE)
	output.store_16(0)
	output.store_16(1)
	output.store_16(sizes.size())
	var offset := 6 + 16 * sizes.size()
	for i in sizes.size():
		output.store_8(sizes[i] % 256)
		output.store_8(sizes[i] % 256)
		output.store_16(0)
		output.store_16(1)
		output.store_16(32)
		output.store_32(frames[i].size())
		output.store_32(offset)
		offset += frames[i].size()
	for frame in frames: output.store_buffer(frame)
	output.close()
	quit()
