extends Control
## Runs in real UI time while Expedition suspends simulation. No pause-state mutation.
signal wave_started(wave: int)
signal wave_finished(wave: int)
const FADE_IN := 0.38
const TYPE_SECONDS := 0.9
const HOLD := 0.8
const FADE_OUT := 0.65
const DURATION := FADE_IN + TYPE_SECONDS + HOLD + FADE_OUT
var active := false
var current_wave := 0
var pending: Array[int] = []
var elapsed := 0.0
var title: Label
var subtitle: Label

func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1180, 660)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.05, 0.78)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var font := FontVariation.new()
	font.base_font = preload("res://assets/fonts/unifont.otf")
	font.variation_embolden = 0.6
	title = Label.new()
	title.position = Vector2(140, 281)
	title.size = Vector2(900, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("f3f9f7"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(140, 367)
	subtitle.size = Vector2(900, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", preload("res://assets/fonts/unifont.otf"))
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("9db7bd"))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)
	visible = false
	set_process(false)

func queue_wave(wave: int) -> void:
	if pending.has(wave) or (active and current_wave == wave): return
	pending.append(wave)
	if not active: start_next()

func start_next() -> void:
	if pending.is_empty():
		active = false
		visible = false
		set_process(false)
		return
	current_wave = pending.pop_front()
	title.text = "第 %02d 波  ·  敌军来袭" % current_wave
	subtitle.text = "守住营地，迎击最终攻势" if current_wave == 6 else "敌军正从三条路线逼近"
	title.visible_characters = 0
	subtitle.modulate.a = 0.0
	elapsed = 0.0
	modulate.a = 0.0
	active = true
	visible = true
	set_process(true)
	wave_started.emit(current_wave)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active: return
	elapsed += delta
	modulate.a = minf(clampf(elapsed / FADE_IN, 0, 1), clampf((DURATION - elapsed) / FADE_OUT, 0, 1))
	title.visible_characters = mini(title.text.length(), floori(clampf((elapsed - FADE_IN) / TYPE_SECONDS, 0, 1) * title.text.length()))
	subtitle.modulate.a = clampf((elapsed - FADE_IN - TYPE_SECONDS + 0.15) / 0.3, 0, 1)
	if elapsed >= DURATION:
		wave_finished.emit(current_wave)
		start_next()
