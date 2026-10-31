shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float clock = 0.0;
uniform float strength = 0.8;
void fragment() {
	vec2 local = UV * 2.0 - 1.0;
	float mask = pow(max(0.0, 1.0 - dot(local, local)), 2.0);
	float waves = sin(UV.y * 19.0 - clock * 5.0) + sin(UV.y * 31.0 + UV.x * 8.0 - clock * 3.0) * 0.4;
	vec2 offset = vec2(waves, sin(UV.x * 15.0 - clock * 4.0) * 0.25) * SCREEN_PIXEL_SIZE * strength * mask;
	COLOR = vec4(texture(screen_texture, SCREEN_UV + offset).rgb, mask * 0.55);
}
