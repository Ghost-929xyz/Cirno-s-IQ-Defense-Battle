extends Control
const UI = preload("res://scripts/ui/frost_menu.gd")
const Saves = preload("res://scripts/autoload/save_manager.gd")
const Session = preload("res://scripts/autoload/session.gd")
var game
var panel: Panel

func setup(owner_game, page := "pause") -> void:
	game = owner_game
	name = "ExpeditionMenu"
	size = Vector2(1180, 660)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.01, 0.04, 0.08, 0.83)
	dimmer.size = size
	add_child(dimmer)
	panel = Panel.new()
	panel.size = Vector2(680, 540)
	panel.position = (size - panel.size) * 0.5
	add_child(panel)
	show_page(page)

func reset_panel(title: String, subtitle: String) -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()
	UI.decorate(panel, title, subtitle)

func show_page(page := "pause") -> void:
	if page in ["save", "load"]:
		show_slots(page)
		return
	reset_panel("远征暂停", "ICE FRONTLINE  /  指挥档案")
	UI.label(panel, "第 %d 波   ·   金币 %d   ·   木材 %d   ·   部队 %d" % [game.sim.wave, game.sim.gold, game.sim.wood, game.sim.living(0).size()], Vector2(36,124), Vector2(610,30), 18)
	UI.button(panel,"继续远征",Vector2(36,176),Vector2(608,54),game.close_game_menu)
	var save := UI.button(panel,"保存进度",Vector2(36,244),Vector2(296,54),show_page.bind("save"))
	save.disabled = not game.sim.active()
	UI.button(panel,"读取进度",Vector2(348,244),Vector2(296,54),show_page.bind("load"))
	UI.button(panel,"操作说明",Vector2(36,312),Vector2(296,48),show_help)
	UI.button(panel,"声音设置 / 鸣谢",Vector2(348,312),Vector2(296,48),show_audio)
	UI.button(panel,"返回主菜单",Vector2(36,374),Vector2(608,48),game.return_menu)
	UI.label(panel, str(game.sim.message), Vector2(36,438), Vector2(608,46), 15, Color("8db3c6")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.label(panel,"Esc / P 关闭菜单  ·  已绑定槽位的远征返回时自动保存",Vector2(36,498),Vector2(608,24),14,Color("7195aa"))

func show_slots(mode: String) -> void:
	reset_panel("保存远征" if mode == "save" else "读取远征", "三份独立档案  /  选择要使用的槽位")
	if game.has_method("load_training"):
		UI.label(panel,"新手训练使用独立进度，不占用远征档案。",Vector2(36,150),Vector2(608,36))
		var action := UI.button(panel,"保存教学进度" if mode == "save" else "读取教学进度",Vector2(36,220),Vector2(608,60),func():
			if mode == "save": game.save_progress(true); show_page()
			else: game.load_training(); game.close_game_menu())
		action.disabled = mode == "load" and not FileAccess.file_exists("user://tutorial_progress.json")
	else:
		for slot in Saves.SLOT_COUNT:
			var summary := Saves.get_slot_summary(slot)
			var y := 126.0 + slot * 100
			var text := "档案 %02d    ·    空槽位" % (slot + 1)
			if not summary.is_empty():
				text = "档案 %02d    ·    第 %d 波    ·    金币 %d\n%s" % [slot+1,summary.wave,summary.frost,str(summary.saved_at).replace("T","  ")]
			var action := UI.button(panel,text,Vector2(36,y),Vector2(608,82),choose_slot.bind(mode,slot))
			action.alignment = HORIZONTAL_ALIGNMENT_LEFT
			action.disabled = mode == "load" and (summary.is_empty() or summary.get("mode") != "rts")
	UI.button(panel,"返回",Vector2(36,460),Vector2(608,46),show_page)

func choose_slot(mode: String, slot: int, confirmed := false) -> void:
	if mode == "save" and Saves.has_save(slot) and not confirmed:
		reset_panel("覆盖档案 %02d？" % (slot+1),"此槽位的旧进度将被当前远征替换")
		UI.button(panel,"确认保存",Vector2(36,200),Vector2(608,56),choose_slot.bind(mode,slot,true))
		UI.button(panel,"取消",Vector2(36,280),Vector2(608,48),show_slots.bind(mode))
		return
	if mode == "save":
		if Saves.write_slot(slot,game.sim.snapshot()):
			Session.current_slot = slot
			game.sim.message = "已保存至档案 %02d。" % (slot+1)
		else: game.sim.message = "保存失败，请检查磁盘空间。"
		show_page()
	else:
		Session.current_slot = slot
		Session.pending_load_slot = slot
		game.get_tree().change_scene_to_file("res://scenes/expedition.tscn")

func show_help() -> void:
	reset_panel("指挥手册", "常用操作  /  战场保持暂停")
	var text := "左键选择 / 框选，右键移动或交互\n行军遇敌优先迎战，战后继续原任务\nShift + 右键追加指令；F 攻击移动\nS 停止，D 原地防守，I 选择空闲部队\nCtrl + 数字编队，数字选择编队\n\nQ 冰冻 · W 冰墙 · E 冰桥\nG 驻军 · R 修复 · H 回基地\nTab 战术地图 · 滚轮缩放 · 中键拖动\nT 伐木 · C 布置火堆（20 木材）\nF5 快速保存至当前槽位"
	UI.label(panel,text,Vector2(36,128),Vector2(608,320),16)
	UI.button(panel,"返回",Vector2(36,460),Vector2(608,46),show_page)

func show_audio() -> void:
	reset_panel("声音设置", "波次间舒缓探索  /  来袭时电子战斗曲")
	preload("res://scripts/ui/audio_settings.gd").add_controls(panel,Vector2(36,128),608)
	UI.button(panel,"返回",Vector2(36,460),Vector2(608,46),show_page)
