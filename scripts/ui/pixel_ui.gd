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
	return preload("res://scripts/ui/rounded_bars.gd").style(fallback_bg, 8)


static func bar_fill(ratio: float) -> StyleBox:
	var fallback := Color("#4fd39a")
	if ratio <= 0.35:
		fallback = Color("#e05a72")
	elif ratio <= 0.65:
		fallback = Color("#e0b24a")
	return preload("res://scripts/ui/rounded_bars.gd").style(fallback, 8)


static func apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_normal())
	button.add_theme_stylebox_override("hover", button_hover())
	button.add_theme_stylebox_override("pressed", button_pressed())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", button_disabled())

static func attach_button_sound_feedback(button: Button) -> void:
	if button.has_meta("ui_sound_feedback_attached"):
		return
	button.set_meta("ui_sound_feedback_attached", true)
	button.mouse_entered.connect(func() -> void:
		if button.disabled:
			return
		var manager := _get_ui_sound_manager()
		if manager != null:
			manager.call("play_hover")
	)
	button.pressed.connect(func() -> void:
		var manager := _get_ui_sound_manager()
		if manager != null:
			manager.call("play_select", button.get_meta("select_sound", null))
	)


static func _get_ui_sound_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("UISoundManager")

# ---------------------------------------------------------------- 菜单选项悬浮特效

const MENU_TEXT_NORMAL := Color("#2f6b96")
const MENU_TEXT_NORMAL_DARK_BG := Color("#7fc7ec")
const MENU_TEXT_HOVER := Color("#d8fbff")
const MENU_TEXT_DISABLED := Color("#2a3d4d")

static var _underline_texture: ImageTexture = null
static var _crystal_texture: ImageTexture = null


## 无边框菜单选项样式：悬浮/聚焦时文字变亮右移，雪花与渐变线同步淡入。
## 雪花尺寸跟随字号，在文字左侧垂直居中，线条从雪花纹样左缘开始。
## button 需已确定 position / size；host 为 button 的父节点（须在场景树内）。
static func attach_menu_option_fx(button: Button, host: Control, base_position: Vector2, dark_background := false) -> void:
	var empty := StyleBoxEmpty.new()
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state_name, empty)
	button.add_theme_color_override("font_color", MENU_TEXT_NORMAL_DARK_BG if dark_background else MENU_TEXT_NORMAL)
	button.add_theme_color_override("font_hover_color", MENU_TEXT_HOVER)
	button.add_theme_color_override("font_pressed_color", MENU_TEXT_HOVER)
	button.add_theme_color_override("font_focus_color", MENU_TEXT_HOVER)
	button.add_theme_color_override("font_disabled_color", MENU_TEXT_DISABLED)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	attach_button_sound_feedback(button)

	var font_size: int = button.get_theme_font_size("font_size")
	var underline_width := clampf(float(button.text.length()) * float(font_size) * 1.05 + 16.0, 80.0, 260.0)
	var text_width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_left := 0.0
	if button.alignment == HORIZONTAL_ALIGNMENT_CENTER:
		text_left = floorf((button.size.x - text_width) * 0.5)
	elif button.alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		text_left = button.size.x - text_width
	var snow_size := float(font_size)
	var selected_text_shift := 10.0
	# 按选中后的文字位置计量，雪花可见右缘与首字相隔半个字符。
	var snow_left := base_position.x + text_left + selected_text_shift - snow_size * 0.5 - snow_size * 0.81
	var line_center_y := base_position.y + button.size.y - 4.0
	# 40px 雪花纹理外围有柔光留白，实体纹样左缘约位于 19%。
	var line_left := snow_left + snow_size * 0.19
	var underline := TextureRect.new()
	underline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	underline.texture = _get_underline_texture()
	underline.position = Vector2(line_left, line_center_y - 3.0)
	underline.size = Vector2(base_position.x + text_left + underline_width - line_left, 6.0)
	underline.stretch_mode = TextureRect.STRETCH_SCALE
	underline.modulate = Color(1.0, 1.0, 1.0, 0.0)
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(underline)

	var crystal := TextureRect.new()
	crystal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crystal.texture = _get_crystal_texture()
	crystal.position = Vector2(snow_left, base_position.y + (button.size.y - snow_size) * 0.5)
	crystal.size = Vector2(snow_size, snow_size)
	crystal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crystal.modulate = Color(1.0, 1.0, 1.0, 0.0)
	crystal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(crystal)

	var state := {"tween": null, "hovered": false, "focused": false}
	var animate := func() -> void:
		var old_tween: Tween = state["tween"]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
		var tween := host.create_tween().set_parallel(true)
		state["tween"] = tween
		var active: bool = not button.disabled and (state["hovered"] or state["focused"])
		var indicator_alpha := 1.0 if active else 0.0
		var target_x := base_position.x + selected_text_shift if active else base_position.x
		tween.tween_property(button, "position:x", target_x, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(underline, "modulate:a", indicator_alpha, 0.18).set_trans(Tween.TRANS_SINE)
		tween.tween_property(crystal, "modulate:a", indicator_alpha, 0.18).set_trans(Tween.TRANS_SINE)

	button.mouse_entered.connect(func() -> void:
		state["hovered"] = true
		animate.call()
	)
	button.mouse_exited.connect(func() -> void:
		state["hovered"] = false
		animate.call()
	)
	button.focus_entered.connect(func() -> void:
		state["focused"] = true
		animate.call()
	)
	button.focus_exited.connect(func() -> void:
		state["focused"] = false
		animate.call()
	)


## 程序化生成渐变下划线贴图：亮冰蓝，左亮右渐隐，纵向中间实两边虚。
static func _get_underline_texture() -> ImageTexture:
	if _underline_texture != null:
		return _underline_texture
	var w := 260
	var h := 6
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for x in range(w):
		var t := float(x) / float(w - 1)
		var a := pow(1.0 - t, 1.4)
		for y in range(h):
			var v := absf(float(y) / float(h - 1) - 0.5) * 2.0
			var va := pow(1.0 - v, 1.2)
			img.set_pixel(x, y, Color(0.62, 0.93, 1.0, a * va))
	_underline_texture = ImageTexture.create_from_image(img)
	return _underline_texture


## 程序化生成冰晶贴图：六臂雪花晶 + 小分支，外围径向柔光。
static func _get_crystal_texture() -> ImageTexture:
	if _crystal_texture != null:
		return _crystal_texture
	var size := 40
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := Vector2(size, size) * 0.5
	var glow_radius := size * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / glow_radius
			if d < 1.0:
				var a := pow(1.0 - d, 2.4) * 0.5
				img.set_pixel(x, y, Color(0.55, 0.9, 1.0, a))
	var arm_len := size * 0.34
	for i in range(6):
		var ang := TAU * float(i) / 6.0 - PI / 2.0
		var dir := Vector2.from_angle(ang)
		_fx_stamp_line(img, center, center + dir * arm_len, 1.7, Color(0.85, 0.98, 1.0, 0.95))
		var branch_at := center + dir * (arm_len * 0.55)
		for sign in [-1.0, 1.0]:
			var bdir := Vector2.from_angle(ang + sign * PI / 3.5)
			_fx_stamp_line(img, branch_at, branch_at + bdir * (arm_len * 0.32), 1.1, Color(0.8, 0.96, 1.0, 0.85))
	_fx_stamp_disc(img, center, 2.2, Color(0.95, 1.0, 1.0, 1.0))
	_crystal_texture = ImageTexture.create_from_image(img)
	return _crystal_texture


static func _fx_stamp_line(img: Image, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var length := from.distance_to(to)
	var steps := maxi(1, int(ceil(length * 2.0)))
	for i in range(steps + 1):
		_fx_stamp_disc(img, from.lerp(to, float(i) / float(steps)), width * 0.5, color)


static func _fx_stamp_disc(img: Image, p: Vector2, r: float, color: Color) -> void:
	var size := img.get_width()
	var r_ceil := int(ceil(r))
	for y in range(int(p.y) - r_ceil, int(p.y) + r_ceil + 1):
		for x in range(int(p.x) - r_ceil, int(p.x) + r_ceil + 1):
			if x < 0 or y < 0 or x >= size or y >= size:
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(p)
			if d > r:
				continue
			var fall := 1.0 - d / maxf(r, 0.001)
			var a: float = color.a * clampf(fall * 1.6, 0.0, 1.0)
			var existing := img.get_pixel(x, y)
			if a > existing.a:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
