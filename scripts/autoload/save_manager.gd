class_name SaveManager
extends RefCounted

## 存档管理：3 个槽位，JSON 存于 user://saves/slot_N.json。
## 静态实现，与 Session 一样不依赖 autoload，保证测试环境可用。

const SLOT_COUNT := 3
const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1


static func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## 读取槽位原始数据；无存档或损坏时返回空字典。
static func read_slot(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}


static func has_save(slot: int) -> bool:
	return not read_slot(slot).is_empty()


static func write_slot(slot: int, data: Dictionary) -> bool:
	_ensure_dir()
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


static func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## 槽位摘要（存档界面列表展示用）。
static func get_slot_summary(slot: int) -> Dictionary:
	var data := read_slot(slot)
	if data.is_empty():
		return {}
	return {
		"wave": int(data.get("wave_index", -1)) + 1,
		"frost": int(data.get("frost", 0.0)),
		"structures": (data.get("structures", []) as Array).size(),
		"saved_at": str(data.get("saved_at", "")),
	}
