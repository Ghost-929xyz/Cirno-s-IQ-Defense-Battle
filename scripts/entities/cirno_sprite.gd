class_name CirnoSpriteFactory
extends RefCounted

## 琪露诺精灵表加载器：assets/sprites/cirno.png，96x96/帧，自动识别两种版式：
## 1) 四向行走版（8 列 x 4 行 = 768x384）：行序 down / left / right / up，每行 8 帧行走循环；
##    派生 walk_down/left/right/up 与 idle_down/left/right/up（取第 0 帧），
##    另生成 idle/walk/attack/cast/hurt/death 兼容别名，旧状态机无需改动。
## 2) 旧动作版（4 列 x 6 行）：idle / walk / attack / cast / hurt / death，帧均朝右，朝左用 flip_h。

const SHEET_PATH := "res://assets/sprites/cirno.png"
const FRAME_SIZE := Vector2i(96, 96)
const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]

static var _frames: SpriteFrames = null


static func _load_sheet() -> Texture2D:
	if ResourceLoader.exists(SHEET_PATH):
		return load(SHEET_PATH)
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(SHEET_PATH)) == OK:
		return ImageTexture.create_from_image(image)
	return null


static func is_directional(frames: SpriteFrames) -> bool:
	return frames != null and frames.has_animation("walk_down")


static func get_sprite_frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	var sheet := _load_sheet()
	if sheet == null:
		return null
	var frames := SpriteFrames.new()
	var cols := sheet.get_width() / FRAME_SIZE.x
	var rows := sheet.get_height() / FRAME_SIZE.y
	if cols >= 8 and rows >= 4:
		_load_directional(frames, sheet)
	else:
		_load_legacy(frames, sheet)
	_frames = frames
	return frames


## 四向行走版：行 0=down 1=left 2=right 3=up，每行 8 帧。
static func _load_directional(frames: SpriteFrames, sheet: Texture2D) -> void:
	for row in range(DIRECTIONS.size()):
		var suffix := DIRECTIONS[row]
		_add_row(frames, "walk_" + suffix, sheet, row, 8, 9.0, true)
		_add_row(frames, "idle_" + suffix, sheet, row, 1, 5.0, true)
	# 兼容别名：攻击/施法/受击/阵亡暂用 down 行帧顶替，保证旧状态机播放不报错。
	_add_row(frames, "idle", sheet, 0, 1, 5.0, true)
	_add_row(frames, "walk", sheet, 0, 8, 9.0, true)
	_add_row(frames, "attack", sheet, 0, 4, 14.0, false)
	_add_row(frames, "cast", sheet, 0, 4, 11.0, false)
	_add_row(frames, "hurt", sheet, 0, 2, 9.0, false)
	_add_row(frames, "death", sheet, 0, 4, 6.0, false)


## 旧动作版：行 0=idle 1=walk 2=attack 3=cast 4=hurt 5=death。
static func _load_legacy(frames: SpriteFrames, sheet: Texture2D) -> void:
	_add_row(frames, "idle", sheet, 0, 4, 5.0, true)
	_add_row(frames, "walk", sheet, 1, 4, 9.0, true)
	_add_row(frames, "attack", sheet, 2, 4, 14.0, false)
	_add_row(frames, "cast", sheet, 3, 4, 11.0, false)
	_add_row(frames, "hurt", sheet, 4, 2, 9.0, false)
	_add_row(frames, "death", sheet, 5, 4, 6.0, false)


static func _add_row(frames: SpriteFrames, anim: String, sheet: Texture2D, row: int, count: int, fps: float, loop: bool) -> void:
	if frames.has_animation(anim):
		frames.remove_animation(anim)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for index in range(count):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(index * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		atlas.filter_clip = true
		frames.add_frame(anim, atlas)


## 创建战斗用精灵节点。贴图缺失时返回 null，调用方回退到手绘图形。
static func make_sprite() -> AnimatedSprite2D:
	var frames := get_sprite_frames()
	if frames == null:
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = "idle"
	# 96px 帧缩到约 48 世界单位（4 格高）。
	sprite.scale = Vector2(0.5, 0.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.animation_finished.connect(func() -> void:
		if sprite.animation != "death" and sprite.animation != "idle" and sprite.animation != "walk":
			sprite.play("idle")
	)
	sprite.play("idle")
	return sprite


## HUD 头像 / 菜单展示用的单帧贴图。
static func frame_texture(anim: String, index: int) -> Texture2D:
	var frames := get_sprite_frames()
	if frames == null or not frames.has_animation(anim):
		return null
	var count := frames.get_frame_count(anim)
	if count == 0:
		return null
	return frames.get_frame_texture(anim, clampi(index, 0, count - 1))
