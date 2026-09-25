class_name CirnoSpriteFactory
extends RefCounted

## 琪露诺精灵表加载器：assets/sprites/cirno.png，24x24/帧，4 列。
## 行序：idle(4) / walk(4) / attack(4) / cast(4) / hurt(2) / death(4)。
## 帧均朝右绘制，需要朝左时设置 flip_h。

const SHEET_PATH := "res://assets/sprites/cirno.png"
const FRAME_SIZE := Vector2i(24, 24)
const ROW_IDLE := 0
const ROW_WALK := 1
const ROW_ATTACK := 2
const ROW_CAST := 3
const ROW_HURT := 4
const ROW_DEATH := 5

static var _frames: SpriteFrames = null


static func _load_sheet() -> Texture2D:
	if ResourceLoader.exists(SHEET_PATH):
		return load(SHEET_PATH)
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(SHEET_PATH)) == OK:
		return ImageTexture.create_from_image(image)
	return null


static func get_sprite_frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	var sheet := _load_sheet()
	if sheet == null:
		return null
	var frames := SpriteFrames.new()
	_add_row(frames, "idle", sheet, ROW_IDLE, 4, 5.0, true)
	_add_row(frames, "walk", sheet, ROW_WALK, 4, 9.0, true)
	_add_row(frames, "attack", sheet, ROW_ATTACK, 4, 14.0, false)
	_add_row(frames, "cast", sheet, ROW_CAST, 4, 11.0, false)
	_add_row(frames, "hurt", sheet, ROW_HURT, 2, 9.0, false)
	_add_row(frames, "death", sheet, ROW_DEATH, 4, 6.0, false)
	_frames = frames
	return frames


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
	sprite.scale = Vector2(1.0, 1.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
