class_name BuildCatalog
extends RefCounted

const ORDER := [
	"icicle",
	"rime",
	"baka",
	"guard_barracks",
	"archer_barracks",
	"mage_barracks",
]


static func get_definition(build_id: String) -> Dictionary:
	if TowerCatalog.DATA.has(build_id):
		return TowerCatalog.get_definition(build_id)
	if BarracksCatalog.DATA.has(build_id):
		return BarracksCatalog.get_definition(build_id)
	return {}


static func is_tower(build_id: String) -> bool:
	return TowerCatalog.DATA.has(build_id)


static func is_barracks(build_id: String) -> bool:
	return BarracksCatalog.DATA.has(build_id)
