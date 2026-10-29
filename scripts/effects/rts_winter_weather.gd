extends Node2D
## Screen-space flakes and world-space accumulation share simulation weather.
const FrostShader = preload("res://scripts/effects/rts_frost.gdshader")
var flakes: CPUParticles2D
var frost: ShaderMaterial
var surface: Polygon2D

func setup(map: Node2D, sim) -> void:
	var mask := Image.create(sim.WIDTH, sim.HEIGHT, false, Image.FORMAT_RGBA8)
	for y in sim.HEIGHT:
		for x in sim.WIDTH:
			mask.set_pixel(x, y, Color.WHITE if sim.water(Vector2i(x, y)) else Color.BLACK)
	surface = Polygon2D.new()
	surface.name = "WinterSurface"
	surface.z_index = 4
	surface.polygon = PackedVector2Array([Vector2.ZERO, Vector2(sim.WIDTH * 64, 0), Vector2(sim.WIDTH * 64, sim.HEIGHT * 64), Vector2(0, sim.HEIGHT * 64)])
	surface.uv = PackedVector2Array([Vector2.ZERO, Vector2(sim.WIDTH, 0), Vector2(sim.WIDTH, sim.HEIGHT), Vector2(0, sim.HEIGHT)])
	surface.texture = ImageTexture.create_from_image(mask)
	frost = ShaderMaterial.new()
	frost.shader = FrostShader
	frost.set_shader_parameter("terrain_mask", surface.texture)
	frost.set_shader_parameter("map_size", Vector2(sim.WIDTH, sim.HEIGHT))
	surface.material = frost
	map.add_child(surface)
	flakes = CPUParticles2D.new()
	flakes.name = "Snowflakes"
	flakes.position = Vector2(590, -25)
	flakes.amount = 240
	flakes.lifetime = 11.0
	flakes.preprocess = 1.0
	flakes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flakes.emission_rect_extents = Vector2(690, 12)
	flakes.direction = Vector2(0.15, 1.0)
	flakes.spread = 16.0
	flakes.gravity = Vector2(2, 5)
	flakes.initial_velocity_min = 52.0
	flakes.initial_velocity_max = 85.0
	flakes.angular_velocity_min = -24.0
	flakes.angular_velocity_max = 24.0
	flakes.scale_amount_min = 0.12
	flakes.scale_amount_max = 0.3
	flakes.color = Color(0.92, 0.98, 1.0, 0.82)
	flakes.texture = snowflake_texture()
	flakes.emitting = false
	add_child(flakes)
	sync(sim, false)

func snowflake_texture() -> Texture2D:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for branch in 6:
		var direction := Vector2.from_angle(branch * TAU / 6.0)
		paint_line(image, Vector2(11.5, 11.5), Vector2(11.5, 11.5) + direction * 10.0)
		for side in [-1, 1]:
			var joint := Vector2(11.5, 11.5) + direction * 6.0
			paint_line(image, joint, joint + direction.rotated(side * PI / 3.0) * 3.5)
	return ImageTexture.create_from_image(image)

func paint_line(image: Image, start: Vector2, finish: Vector2) -> void:
	for i in 32:
		var pixel := Vector2i(start.lerp(finish, float(i) / 31.0).round())
		image.set_pixel(pixel.x, pixel.y, Color.WHITE)

func sync(sim, paused: bool) -> void:
	frost.set_shader_parameter("coverage", sim.snow_cover)
	surface.visible = sim.snow_cover > 0.001
	# Hiding immediately at wave end prevents a lingering particle tail while
	# the simulation independently melts accumulated snow over several seconds.
	flakes.visible = sim.snowing()
	flakes.emitting = flakes.visible
	flakes.speed_scale = 0.0 if paused else 1.0
