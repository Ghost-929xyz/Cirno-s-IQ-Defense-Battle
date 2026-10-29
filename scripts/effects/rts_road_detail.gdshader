shader_type canvas_item;
render_mode unshaded;
uniform sampler2D sand_atlas : filter_nearest, repeat_disable;
uniform vec2 atlas_size;
varying vec2 map_pixels;

void vertex() {
	map_pixels = VERTEX * 0.25;
}

void fragment() {
	vec4 border = COLOR;
	vec2 grain_uv = (vec2(6.0, 1.0) * 64.0 + fract(map_pixels / 64.0) * 64.0) / atlas_size;
	vec3 grain = texture(sand_atlas, grain_uv).rgb;
	COLOR = vec4(mix(border.rgb, grain, 0.8), border.a);
}
