class_name PixelUI
extends RefCounted

## 像素风 UI 贴图库：加载 assets/ui/*.png 九宫格贴图并构建 StyleBoxTexture。
## 贴图缺失时回退为 StyleBoxFlat，保证无素材也能运行。

const UI_DIR := "res://assets/ui/"
const PANEL_MARGIN := 16.0
const CARD_MARGIN := 14.0
const BUTTON_MARGIN := 10.0
const BAR_MARGIN := 6.0

static var _cache: Dictionary = {}


static func _load_texture(file_name: String) -> Texture2D:
	if _cache.has(file_name):
		return _cache[file_name]
	var path := UI_DIR + file_name
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	else:
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) == OK:
			texture = ImageTexture.create_from_image(image)
	_cache[file_name] = texture
	return texture


static func _style_from(file_name: String, margin: float, fallback_bg: Color, fallback_border: Color, content := Vector4(8.0, 8.0, 8.0, 6.0)) -> StyleBox:
	var texture := _load_texture(file_name)
	if texture != null:
		var style := StyleBoxTexture.new()
		style.texture = texture
		style.texture_margin_left = margin
		style.texture_margin_right = margin
		style.texture_margin_top = margin
		style.texture_margin_bottom = margin
		style.content_margin_left = content.x
		style.content_margin_top = content.y
		style.content_margin_right = content.z
		style.content_margin_bottom = content.w
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		return style
	return _flat(fallback_bg, fallback_border, 2, content)


static func _flat(background: Color, border: Color, border_width: int, content := Vector4(8.0, 8.0, 8.0, 6.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = content.x
	style.content_margin_top = content.y
	style.content_margin_right = content.z
	style.content_margin_bottom = content.w
	return style


static func panel_style(fallback_bg := Color(0.03, 0.12, 0.21, 0.94), fallback_border := Color("#86e9ff")) -> StyleBox:
	return _style_from("panel.png", PANEL_MARGIN, fallback_bg, fallback_border, Vector4(10.0, 10.0, 10.0, 10.0))


static func card_style(fallback_bg := Color("#102f4c"), fallback_border := Color("#2e7292")) -> StyleBox:
	return _style_from("card.png", CARD_MARGIN, fallback_bg, fallback_border, Vector4(10.0, 10.0, 10.0, 10.0))


static func button_normal(fallback_bg := Color("#102d46"), fallback_border := Color("#2c6c8e")) -> StyleBox:
	return _style_from("button_normal.png", BUTTON_MARGIN, fallback_bg, fallback_border)


static func button_hover(fallback_bg := Color("#16415d"), fallback_border := Color("#8fe8ff")) -> StyleBox:
	return _style_from("button_hover.png", BUTTON_MARGIN, fallback_bg, fallback_border)


static func button_pressed(fallback_bg := Color("#1b5a78"), fallback_border := Color("#d8fbff")) -> StyleBox:
	return _style_from("button_pressed.png", BUTTON_MARGIN, fallback_bg, fallback_border)


static func button_disabled(fallback_bg := Color("#1a222c"), fallback_border := Color("#46545f")) -> StyleBox:
	return _style_from("button_disabled.png", BUTTON_MARGIN, fallback_bg, fallback_border)


## 稀有度卡框：普通 / 稀有 / 冰晶附魔。
static func card_rarity_style(rarity: String) -> StyleBox:
	match rarity:
		"稀有":
			return _style_from("card_rare.png", CARD_MARGIN, Color("#241a3e"), Color("#c494ff"), Vector4(10.0, 10.0, 10.0, 10.0))
		"冰晶附魔":
			return _style_from("card_enchant.png", CARD_MARGIN, Color("#2e2410"), Color("#ffd66e"), Vector4(10.0, 10.0, 10.0, 10.0))
		_:
			return _style_from("card_common.png", CARD_MARGIN, Color("#102f4c"), Color("#60bee0"), Vector4(10.0, 10.0, 10.0, 10.0))


static func card_rarity_hover_style(rarity: String) -> StyleBox:
	match rarity:
		"稀有":
			return _style_from("card_rare.png", CARD_MARGIN, Color("#332258"), Color("#e6d2ff"), Vector4(10.0, 10.0, 10.0, 10.0))
		"冰晶附魔":
			return _style_from("card_enchant.png", CARD_MARGIN, Color("#403218"), Color("#fff0be"), Vector4(10.0, 10.0, 10.0, 10.0))
		_:
			return _style_from("card_common.png", CARD_MARGIN, Color("#174d67"), Color("#c7f8ff"), Vector4(10.0, 10.0, 10.0, 10.0))


## 小图标贴图（建筑/技能/资源）。
static func icon(file_name: String) -> Texture2D:
	return _load_texture(file_name)


## 小地图边框。
static func minimap_frame_style() -> StyleBox:
	return _style_from("minimap_frame.png", 6.0, Color(0.03, 0.12, 0.21, 0.0), Color("#60bee0"), Vector4(4.0, 4.0, 4.0, 4.0))


static func bar_back(fallback_bg := Color("#0a1c2c"), fallback_border := Color("#2c6c8e")) -> StyleBox:
	return _style_from("bar_back.png", BAR_MARGIN, fallback_bg, fallback_border, Vector4(4.0, 4.0, 4.0, 4.0))


static func bar_fill(ratio: float) -> StyleBox:
	var file_name := "bar_fill_green.png"
	var fallback := Color("#4fd39a")
	if ratio <= 0.35:
		file_name = "bar_fill_red.png"
		fallback = Color("#e05a72")
	elif ratio <= 0.65:
		file_name = "bar_fill_amber.png"
		fallback = Color("#e0b24a")
	return _style_from(file_name, BAR_MARGIN, fallback, fallback.lightened(0.35), Vector4(2.0, 2.0, 2.0, 2.0))


static func apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_normal())
	button.add_theme_stylebox_override("hover", button_hover())
	button.add_theme_stylebox_override("pressed", button_pressed())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", button_disabled())
