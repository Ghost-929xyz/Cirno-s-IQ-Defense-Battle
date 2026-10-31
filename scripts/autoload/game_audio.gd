extends Node
## Persistent music mixer and bounded, screen-relative battle sound pool.
const MUSIC_PATHS := {"calm":"res://assets/audio/music/preparation.ogg", "battle":"res://assets/audio/music/battle.ogg"}
const MUSIC_GAIN := {"calm":-5.7, "battle":-12.41}
const EFFECT_PATHS := {
	"melee_hit":["melee_hit_a","melee_hit_b"], "arrow_hit":["arrow_hit"],
	"arrow_release":["arrow_release"], "frost_hit":["frost_hit"],
	"unit_down":["unit_down"], "building_break":["building_break"],
	"spell_cast":["spell_cast"], "chop":["chop"]}
const BUSES := {"music":"Music", "effects":"BattleSFX", "ui":"UI"}
const MAX_VOICES := 10
const CROSSFADE_SECONDS := 1.5
const SETTINGS_PATH := "user://audio_settings.cfg"
var volumes := {"music":0.65, "effects":0.8, "ui":0.8}
var music_players: Dictionary = {}
var effects: Dictionary = {}
var voices: Array[AudioStreamPlayer2D] = []
var mode := "calm"
var mix := 0.0
var duck := 0.0
var muted_for_pause := false
var _game: WeakRef
var _clock := 0.0
var _last_sound: Dictionary = {}
var _settings_clock := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 50
	_rng.randomize()
	for bus_name in BUSES.values():
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0,limiter)
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		for key in volumes: volumes[key] = clampf(float(settings.get_value("volume",key,volumes[key])),0,1)
	for key in volumes: set_volume(key,volumes[key],false)
	for key in MUSIC_PATHS:
		var player := AudioStreamPlayer.new()
		player.name = "Music_" + key
		player.bus = "Music"
		player.stream = load(MUSIC_PATHS[key])
		player.stream.loop = true
		player.volume_db = -80
		add_child(player)
		music_players[key] = player
	for key in EFFECT_PATHS:
		effects[key] = []
		for clip in EFFECT_PATHS[key]: effects[key].append(load("res://assets/audio/combat/%s.wav" % clip))
	for i in MAX_VOICES:
		var voice := AudioStreamPlayer2D.new()
		voice.name = "BattleVoice_%d" % i
		voice.bus = "BattleSFX"
		voice.max_distance = 1100
		voice.attenuation = 0.6
		voice.panning_strength = 1.2
		add_child(voice)
		voices.append(voice)
	enter_menu()

func set_volume(key: String, value: float, persist := true) -> void:
	if not BUSES.has(key): return
	volumes[key] = clampf(value,0,1)
	var bus := AudioServer.get_bus_index(BUSES[key])
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(0.0001,volumes[key])))
		AudioServer.set_bus_mute(bus,volumes[key] <= 0)
	if persist: _settings_clock = 0.4

func _save_settings() -> void:
	var settings := ConfigFile.new()
	for key in volumes: settings.set_value("volume",key,volumes[key])
	settings.save(SETTINGS_PATH)

func enter_menu() -> void:
	_game = null
	mode = "calm"
	muted_for_pause = false
	stop_effects()
	_start_music()

func bind_game(game: Node) -> void:
	_game = weakref(game)
	_last_sound.clear()
	game.sim.audio_events.clear()
	stop_effects()
	_start_music()

func _start_music() -> void:
	# Dedicated/headless runs have no audio output and need no looping decoders.
	if AudioServer.get_driver_name() == "Dummy": return
	for player in music_players.values():
		if not player.playing: player.play()

func leave_game(game: Node) -> void:
	if _game != null and _game.get_ref() == game: enter_menu()

func desired_music(sim) -> String:
	if sim.phase in ["cards","base","victory","defeat"]: return "calm"
	if sim.snowing(): return "battle"
	for unit in sim.living(0):
		if unit.home == -1 and sim.unit_in_combat(unit): return "battle"
	return "calm"

func _process(delta: float) -> void:
	_clock += delta
	if _settings_clock > 0:
		_settings_clock -= delta
		if _settings_clock <= 0: _save_settings()
	var game = _game.get_ref() if _game != null else null
	if is_instance_valid(game) and not game.is_queued_for_deletion():
		mode = desired_music(game.sim)
		muted_for_pause = game.paused or is_instance_valid(game.game_menu) or game.tactical_overlay.visible
		consume_events(game)
		for voice in voices:
			if voice.playing and voice.has_meta("world_position"): voice.position = game.world_to_screen(voice.get_meta("world_position"))
	else:
		mode = "calm"
		muted_for_pause = false
		if _game != null: enter_menu()
	mix = move_toward(mix,1.0 if mode == "battle" else 0.0,delta/CROSSFADE_SECONDS)
	duck = move_toward(duck,-7.0 if muted_for_pause else 0.0,delta*24)
	for key in music_players:
		var weight := sqrt(mix if key == "battle" else 1.0-mix)
		music_players[key].volume_db = maxf(-80,MUSIC_GAIN[key]+linear_to_db(maxf(0.0001,weight))+duck)

func consume_events(game) -> void:
	var events: Array = game.sim.audio_events.duplicate()
	game.sim.audio_events.clear()
	if game.simulation_blocked():
		stop_effects()
		return
	for event in events:
		var pos := Vector2(event.x,event.y)
		if not game.sim.is_visible(pos): continue
		var screen: Vector2 = game.world_to_screen(pos)
		if not Rect2(-80,-80,1340,820).has_point(screen): continue
		play_effect(str(event.kind),screen,pos)

func play_effect(kind: String, screen: Vector2, world := Vector2.INF) -> bool:
	if not effects.has(kind) or volumes.effects <= 0: return false
	var gap := 0.17 if kind in ["unit_down","building_break","chop"] else 0.065
	if _clock-float(_last_sound.get(kind,-100)) < gap: return false
	var voice: AudioStreamPlayer2D
	var same := 0
	for candidate in voices:
		if candidate.playing and candidate.get_meta("kind","") == kind: same += 1
		if not candidate.playing and voice == null: voice = candidate
	if voice == null or same >= 3: return false
	_last_sound[kind] = _clock
	voice.stream = effects[kind][_rng.randi_range(0,effects[kind].size()-1)]
	voice.pitch_scale = _rng.randf_range(0.94,1.06)
	voice.volume_db = -5.0 if kind != "building_break" else -8.0
	voice.position = screen
	voice.set_meta("kind",kind)
	if world.is_finite(): voice.set_meta("world_position",world)
	elif voice.has_meta("world_position"): voice.remove_meta("world_position")
	voice.play()
	return true

func stop_effects() -> void:
	for voice in voices: voice.stop()

func _exit_tree() -> void:
	if _settings_clock > 0: _save_settings()
	for player in music_players.values():
		player.stop()
		player.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	music_players.clear()
	voices.clear()
	effects.clear()
