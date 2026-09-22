class_name WaveManager
extends Node

signal wave_started(index: int, display_name: String)
signal wave_finished(index: int)
signal spawn_requested(enemy_id: String, hp_scale: float)

var current_index := -1
var running := false

var _events: Array[Dictionary] = []
var _event_index := 0
var _elapsed := 0.0
var _alive_enemies := 0


func start_wave(index: int) -> bool:
	if running:
		return false
	var wave := WaveCatalog.get_wave(index)
	if wave.is_empty():
		return false

	current_index = index
	_events.clear()
	_event_index = 0
	_elapsed = 0.0
	_alive_enemies = 0

	var hp_scale := float(wave.get("hp_scale", 1.0))
	for group in wave.get("groups", []):
		var enemy_id := str(group.get("enemy_id", "tadpole"))
		var count := int(group.get("count", 1))
		var interval := float(group.get("interval", 1.0))
		var delay := float(group.get("delay", 0.0))
		for spawn_index in range(count):
			_events.append({
				"time": delay + spawn_index * interval,
				"enemy_id": enemy_id,
				"hp_scale": hp_scale,
			})

	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))
	running = true
	wave_started.emit(current_index, str(wave.get("name", "未知波次")))
	return true


func notify_enemy_spawned() -> void:
	_alive_enemies += 1


func notify_enemy_finished() -> void:
	_alive_enemies = maxi(0, _alive_enemies - 1)
	_try_finish()


func _process(delta: float) -> void:
	if not running:
		return
	_elapsed += delta
	while _event_index < _events.size() and float(_events[_event_index].time) <= _elapsed:
		var event := _events[_event_index]
		_event_index += 1
		spawn_requested.emit(str(event.enemy_id), float(event.hp_scale))
	_try_finish()


func _try_finish() -> void:
	if not running:
		return
	if _event_index >= _events.size() and _alive_enemies <= 0:
		running = false
		wave_finished.emit(current_index)


func stop() -> void:
	running = false
	_events.clear()
	_event_index = 0
	_alive_enemies = 0
