extends RefCounted
## The 192px tree tile is rendered 64px below its painted cell center.
## Its trunk sits two logical cells below the painted anchor on the 64px grid.
const TRUNK_OFFSET := Vector2i(0, 2)
const SPRITE_OFFSET := Vector2(0, -64)
static func trunk_cell(anchor: Vector2i) -> Vector2i:
	return anchor + TRUNK_OFFSET

static func entity_id(anchor: Vector2i) -> int:
	return -10000 - anchor.y * 80 - anchor.x
