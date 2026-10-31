extends Node

## 常驻 UI 音效播放器：菜单和暂停界面切换场景时仍能完整播放。
const HOVER_STREAM_PATH := "res://assets/audio/ui/menu_hover.mp3"
const SELECT_STREAM_PATH := "res://assets/audio/ui/menu_select.mp3"

var _hover_player: AudioStreamPlayer
var _select_player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hover_player = _make_player("HoverPlayer", load(HOVER_STREAM_PATH) as AudioStream)
	_select_player = _make_player("SelectPlayer", load(SELECT_STREAM_PATH) as AudioStream)


func play_hover() -> void:
	_play(_hover_player)


func play_select(override_stream: AudioStream = null) -> void:
	_select_player.stream = override_stream if override_stream != null else load(SELECT_STREAM_PATH) as AudioStream
	_play(_select_player)


func _make_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	if AudioServer.get_bus_index("UI") >= 0: player.bus = "UI"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _play(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.play()
