extends SceneTree
const Sim = preload("res://scripts/game/rts_simulation.gd")
var checks := 0
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func fresh():
	var s = Sim.new()
	s.configure_terrain([])
	s.phase = "prep"
	for kind in s.catalog:
		s.catalog[kind].crit_chance = 0
		s.catalog[kind].dodge = 0
	return s
func kinds(s) -> Array: return s.audio_events.map(func(e): return e.kind)
func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	var audio = root.get_node("GameAudio")
	var has_output := AudioServer.get_driver_name() != "Dummy"
	audio.set_process(false)
	var saved_volumes: Dictionary = audio.volumes.duplicate()
	for key in saved_volumes: audio.set_volume(key,0.8,false)
	check(audio.music_players.size() == 2 and audio.voices.size() == 10,"Persistent mixer has two tracks and ten effect voices")
	for key in audio.music_players:
		var player: AudioStreamPlayer = audio.music_players[key]
		check(player.playing == has_output and player.stream.loop and player.stream.get_length() > 60,"Music loads, loops and plays when audio output exists: " + key)
	for key in audio.effects:
		check(audio.effects[key][0].get_length() > 0.05,"Valid effect: " + key)
	for bus in ["Music","BattleSFX","UI"]: check(AudioServer.get_bus_index(bus) > 0,"Independent audio bus: " + bus)
	var s = fresh()
	check(audio.desired_music(s) == "calm","Inter-wave preparation is calm")
	s.start_wave()
	check(audio.desired_music(s) == "battle","Incoming wave switches music before enemies reach the camera")
	for enemy in s.living(1): enemy.hp = 0
	check(audio.desired_music(s) == "calm","Cleared wave returns to calm even while waiting for the timer")
	var u: Dictionary = s.add_unit("swordsman",0,Vector2(10,10))
	u.combat_until = s.elapsed+3
	check(audio.desired_music(s) == "battle","Exploration skirmishes also use battle music")
	s.elapsed += 3.1
	check(audio.desired_music(s) == "calm","Combat grace period expires back to calm")
	for phase in ["victory","defeat","cards","base"]:
		s.phase = phase
		u.combat_until = s.elapsed+3
		check(audio.desired_music(s) == "calm","Non-combat phase stays calm: " + phase)
	s = fresh()
	u = s.add_unit("swordsman",0,Vector2(10,10))
	var foe: Dictionary = s.add_unit("swordsman",1,Vector2(11,10))
	s.hit(u,foe,1,false)
	check(kinds(s) == ["melee_hit"],"Successful melee hit emits exactly one impact")
	s.audio_events.clear()
	u = s.add_unit("archer",0,Vector2(12,10))
	s.hit(u,foe,1,true)
	check(kinds(s) == ["arrow_release","arrow_hit"],"Ranged attack emits release and impact")
	s.audio_events.clear()
	u = s.add_unit("ice_archer",0,Vector2(13,10))
	s.hit(u,foe,999,true)
	check(kinds(s) == ["arrow_release","frost_hit","unit_down"],"Ice attack and unit death have distinct feedback")
	s.audio_events.clear()
	s.hit(u,foe,1,true)
	check(s.audio_events.is_empty(),"Dead targets do not emit duplicate sounds")
	var building: Dictionary = s.add_building("outpost",1,Vector2(20,20))
	s.hit(u,building,99999,true)
	check(kinds(s).has("building_break"),"Destroyed structure emits destruction feedback")
	s.audio_events.clear()
	var state: int = s.rng.state
	for i in 150: s.emit_audio("chop",Vector2(i,10))
	check(s.audio_events.size() == 96 and s.audio_events[0].x == 54,"Catch-up event queue is bounded and keeps recent events")
	check(s.rng.state == state,"Audio events do not alter simulation randomness")
	var snapshot: Dictionary = s.snapshot()
	check(not snapshot.has("audio_events"),"Transient sounds are excluded from saves")
	check(s.restore(snapshot) and s.audio_events.is_empty(),"Loading clears pending sounds")
	var game = load("res://scenes/expedition.tscn").instantiate()
	game.random_map_enabled = false
	root.add_child(game)
	game.set_process(false)
	game.sim.phase = "prep"
	game.wave_intro.active = false
	game.sim.start_wave()
	audio.mix = 0
	audio._process(0.75)
	check(audio.mode == "battle" and is_equal_approx(audio.mix,0.5),"Incoming wave crossfades halfway over 0.75 seconds")
	for player in audio.music_players.values(): check(player.volume_db < -8 and player.volume_db > -80,"Both tracks have bounded gain during transition")
	audio._process(0.75)
	check(audio.mix == 1,"Crossfade completes in 1.5 seconds")
	game.paused = true
	audio._process(0.5)
	check(audio.duck == -7 and audio.music_players.battle.playing == has_output,"Pause lowers music while preserving playback")
	game.paused = false
	for enemy in game.sim.living(1): enemy.hp = 0
	audio._process(1.5)
	check(audio.mode == "calm" and audio.mix == 0 and audio.duck == 0,"Clearing enemies restores calm at normal volume")
	audio.stop_effects()
	audio._last_sound.clear()
	var pos: Vector2 = game.camera_center
	game.sim.reveal_circle(pos,2)
	game.sim.emit_audio("melee_hit",pos)
	audio.consume_events(game)
	check(game.sim.audio_events.is_empty() and audio.voices.any(func(v): return v.playing),"Visible on-screen events are consumed and played")
	audio.stop_effects()
	audio._last_sound.clear()
	game.sim.emit_audio("chop",Vector2(79,49))
	audio.consume_events(game)
	check(not audio.voices.any(func(v): return v.playing),"Off-screen or hidden events remain inaudible")
	game.paused = true
	game.sim.emit_audio("melee_hit",pos)
	audio.consume_events(game)
	check(game.sim.audio_events.is_empty() and not audio.voices.any(func(v): return v.playing),"Pause drops stale events and stops battle voices")
	game.paused = false
	audio._last_sound.clear()
	check(audio.play_effect("melee_hit",Vector2(590,330)),"Available voice plays impact")
	check(not audio.play_effect("melee_hit",Vector2(590,330)),"Same-frame impacts are throttled")
	for i in 12:
		audio._clock += 0.1
		audio.play_effect("melee_hit",Vector2(590,330))
	check(audio.voices.filter(func(v): return v.playing).size() <= 3,"Identical effects are capped at three concurrent voices")
	audio.set_volume("effects",0,false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("BattleSFX")) and not audio.play_effect("chop",Vector2.ZERO),"Zero effects volume mutes and skips new sounds")
	game.open_game_menu()
	game.game_menu.show_audio()
	check(game.game_menu.panel.find_children("Volume_*","HSlider",false,false).size() == 3,"In-game settings expose three independent sliders")
	await capture("res://.tools/battle-audio-settings.png")
	game.queue_free()
	await process_frame
	check(audio._game == null and audio.mode == "calm","Leaving game releases binding and returns to menu music")
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	menu._on_options_pressed()
	check(menu.find_children("Volume_*","HSlider",true,false).size() == 3,"Main menu also exposes audio settings")
	await capture("res://.tools/main-audio-settings.png")
	menu.queue_free()
	await process_frame
	for key in saved_volumes: audio.set_volume(key,saved_volumes[key],false)
	audio.stop_effects()
	for player in audio.music_players.values(): player.stop()
	await create_timer(0.12).timeout
	print("BATTLE_AUDIO_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
