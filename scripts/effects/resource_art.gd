extends RefCounted
## Approved artwork, kept as original PNGs. Regions exclude transparent review padding.
const MINE = preload("res://assets/props/gold_mine.png")
const MINE_CLOSED = preload("res://assets/props/gold_mine_closed.png")
const SPRING = preload("res://assets/props/mana_spring.png")
const CAMPFIRE = preload("res://assets/props/campfire.png")
const VISION_TOWER = preload("res://assets/props/vision_tower.png")
const TOWER_REGION := Rect2(344, 120, 691, 931)
const TOWER_WIDTH := 47.25
const PROP_PIXELS := {"gold_mine": 192, "mana_spring": 176, "vision_tower": 144, "campfire": 80}
static var prop_textures: Dictionary = {}

static func prop_texture(kind: String, occupied: bool = true) -> Texture2D:
	var closed_mine := kind == "gold_mine" and not occupied
	var key := "gold_mine_closed" if closed_mine else kind
	if prop_textures.has(key): return prop_textures[key]
	var original: Texture2D = {"gold_mine": MINE, "mana_spring": SPRING, "vision_tower": VISION_TOWER, "campfire": CAMPFIRE}[kind]
	if closed_mine: original = MINE_CLOSED
	var region: Rect2 = {"gold_mine": MINE_REGION, "mana_spring": SPRING_REGION, "vision_tower": TOWER_REGION, "campfire": FIRE_REGION}[kind]
	var image := original.get_image().get_region(Rect2i(region))
	var width: int = PROP_PIXELS[kind]
	image.resize(width, roundi(width * region.size.y / region.size.x), Image.INTERPOLATE_NEAREST)
	prop_textures[key] = ImageTexture.create_from_image(image)
	return prop_textures[key]
const MINE_REGION := Rect2(110, 165, 1117, 928)
const SPRING_REGION := Rect2(209, 154, 988, 889)
const FIRE_REGION := Rect2(310, 305, 920, 535)
const FIRE_WIDTH := 26.25
const FIRE_HEIGHT := 47.0 * 21.0 / 64.0

static func tower_crystal_offset() -> Vector2:
	# Crystal center in the approved source PNG; use the same crop/scale as the sprite.
	var size := resource_size("vision_tower")
	return Vector2(-size.x * 0.5, -size.y + 9.0 * 21 / 64) + (Vector2(697, 270) - TOWER_REGION.position) / TOWER_REGION.size * size

static func draw_torch(c: Node2D, p: Vector2, scale_factor: float, time: float, seed_value: float) -> void:
	# The legacy torch API also defines camp vision; keep that gameplay contract.
	# Entire painted fire is only 15.42 px high at default zoom, below the 19.36 px pawn.
	var pulse := sin(time * 8 + seed_value) * 0.5 + sin(time * 13 + seed_value) * 0.3
	c.draw_circle(p + Vector2(0, -3) * scale_factor, (11 + pulse) * scale_factor, Color(1, 0.55, 0.15, 0.035))
	# The campfire sprite is now in the world Y-sorted prop layer.
	for i in 4:
		var phase := fposmod(time * (0.5 + i * 0.03) + i * 0.27 + seed_value, 1.0)
		var ember := p + Vector2(sin(i * 9.1 + phase * 4) * (1 + phase * 3), -9 - phase * 7) * scale_factor
		c.draw_rect(Rect2(ember, Vector2.ONE * scale_factor * 0.7), Color(1, 0.75, 0.3, sin(phase * PI) * 0.65))

static func resource_size(kind: String) -> Vector2:
	if PROP_PIXELS.has(kind): return prop_texture(kind).get_size() * 21.0 / 64.0
	return Vector2(16, 25)
