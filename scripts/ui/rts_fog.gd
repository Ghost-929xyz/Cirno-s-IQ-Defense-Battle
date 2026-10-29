extends Node2D
## Visibility belongs to the simulation; this texture only renders its two masks.
const UNEXPLORED_COLOR := Color(0.018, 0.031, 0.047, 1.0)
const MAP_EXTENT := Vector2(80 * 64, 50 * 64)
var sim: RefCounted
var mask: Image
var texture: ImageTexture
var revision := -1

func _ready() -> void:
	z_index = 30
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mask = Image.create(80, 50, false, Image.FORMAT_RGBA8)
	texture = ImageTexture.create_from_image(mask)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
varying vec2 map_uv;
void vertex() {
	map_uv = VERTEX / vec2(5120.0, 3200.0);
}
void fragment() {
	float opacity = 1.0;
	if (all(greaterThanEqual(map_uv, vec2(0.0))) && all(lessThan(map_uv, vec2(1.0)))) {
		vec4 mask = texture(TEXTURE, map_uv);
		float explored = smoothstep(0.15, 0.85, mask.g);
		float visible = smoothstep(0.05, 0.95, mask.r);
		opacity = (1.0 - visible) * mix(1.0, 0.67, explored);
	}
	COLOR = vec4(0.018, 0.031, 0.047, opacity);
}
"""
	var fog_material := ShaderMaterial.new()
	fog_material.shader = shader
	material = fog_material
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	if sim == null or revision == sim.visibility_revision: return
	revision = sim.visibility_revision
	mask.fill(Color(0, 0, 0, 1))
	for key in sim.explored_cells:
		mask.set_pixel(int(key) % 80, int(key) / 80, Color(0, 1, 0, 1))
	for key in sim.visible_cells:
		mask.set_pixel(int(key) % 80, int(key) / 80, Color(1, 1, 0, 1))
	texture.update(mask)
	queue_redraw()

func _draw() -> void:
	# Cover the exterior too, including sprites or effects extending past the edge.
	if texture: draw_texture_rect(texture, Rect2(-MAP_EXTENT, MAP_EXTENT * 3.0), false)
