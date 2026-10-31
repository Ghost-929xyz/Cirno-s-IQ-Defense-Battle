extends RefCounted
const UI = preload("res://scripts/ui/frost_menu.gd")

static func add_controls(parent: Control, pos: Vector2, width: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var audio = tree.root.get_node_or_null("GameAudio")
	if audio == null: return
	var keys := ["music","effects","ui"]
	var names := ["背景音乐","战斗音效","菜单音效"]
	for i in keys.size():
		var key: String = keys[i]
		UI.label(parent,names[i],pos+Vector2(0,i*44),Vector2(112,32),18)
		var readout := UI.label(parent,"%d%%" % (audio.volumes[key]*100),pos+Vector2(width-56,i*44),Vector2(56,32),16)
		var slider := HSlider.new()
		slider.name = "Volume_"+key
		slider.position = pos+Vector2(124,i*44+5)
		slider.size = Vector2(width-196,24)
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = audio.volumes[key]*100
		slider.tooltip_text = "设为 0 可静音"
		parent.add_child(slider)
		slider.value_changed.connect(func(value):
			audio.set_volume(key,value/100.0)
			readout.text = "%d%%" % value)
	UI.label(parent,"音乐：Wareya · Electric Sheep / Romantic Children\n原曲：ZUN（上海アリス幻樂団） · 打击音效：Wareya / CC0\n本作是东方Project二次创作作品，非官方作品。",pos+Vector2(0,150),Vector2(width,86),14,Color("8db3c6"))
	var link := RichTextLabel.new()
	link.position = pos+Vector2(0,242)
	link.size = Vector2(width,30)
	link.bbcode_enabled = true
	link.text = "[url=https://warsong.pages.dev/music/cosplay/]音乐来源[/url]  ·  [url=https://warsong.pages.dev/sounds/rpg/]音效来源[/url]  ·  [url=https://warsong.pages.dev/pages/terms/]授权条款[/url]"
	link.add_theme_font_override("normal_font",UI.FONT)
	link.add_theme_font_size_override("normal_font_size",14)
	link.scroll_active = false
	link.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	parent.add_child(link)
