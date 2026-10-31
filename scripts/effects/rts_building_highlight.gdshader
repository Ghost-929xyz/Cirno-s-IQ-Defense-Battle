shader_type canvas_item;
render_mode unshaded;

uniform float highlight_amount : hint_range(0.0, 1.0) = 0.0;
uniform float outline_amount : hint_range(0.0, 1.0) = 0.0;
uniform float outline_width : hint_range(1.0, 32.0) = 4.0;
uniform vec4 highlight_color : source_color = vec4(1.0, 0.92, 0.68, 1.0);
uniform vec4 outline_color : source_color = vec4(1.0, 0.82, 0.38, 1.0);
// Animated troop frames occupy subregions of a shared atlas sheet.
uniform vec4 frame_bounds = vec4(0.0, 0.0, 1.0, 1.0);
// Supplemental walking frames use a blue master; only blue cloth/armor changes team color.
uniform int troop_palette = -1;
// Resource props share building selection feedback, with state confined to their material.
uniform int prop_kind = 0;
uniform bool occupied = false;
uniform float prop_clock = 0.0;

void fragment() {
	vec4 source = COLOR;
	if (prop_kind == 2 && occupied && source.b > source.r * 1.25 && source.g > source.r * 1.15 && UV.y > 0.35) {
		// Quantized UV flow keeps water on the same pixel grid as the map.
		vec2 flow = vec2(sin(UV.y * 55.0 - prop_clock * 3.0), sin(UV.x * 29.0 + prop_clock * 2.0));
		vec2 shifted = UV + round(flow * 1.4) * TEXTURE_PIXEL_SIZE;
		vec4 water = texture(TEXTURE, shifted);
		if (water.b > water.r * 1.25 && water.g > water.r * 1.15) source.rgb = water.rgb * (0.95 + 0.09 * sin(UV.y * 70.0 - prop_clock * 4.0));
	}
	if (troop_palette > 0 && source.b > source.r * 1.35 && source.b > source.g * 0.95 && source.b - source.r > 0.07) {
		float value = max(source.r, max(source.g, source.b));
		vec3 team_color = troop_palette == 1 ? vec3(1.0, 0.28, 0.22) : vec3(1.0, 0.78, 0.18);
		source.rgb = mix(source.rgb, team_color * value, 0.88);
	}
	float alpha = texture(TEXTURE, UV).a;
	float edge_alpha = 0.0;
	if (outline_amount > 0.0) {
		// Transparent padding in the original sprite leaves room for an outer contour.
		// Sixteen samples keep corners round at different camera scales.
		for (int i = 0; i < 16; i++) {
			float angle = float(i) * 6.2831853 / 16.0;
			vec2 sample_uv = UV + vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * outline_width;
			if (all(greaterThanEqual(sample_uv, frame_bounds.xy)) && all(lessThan(sample_uv, frame_bounds.zw))) {
				edge_alpha = max(edge_alpha, texture(TEXTURE, sample_uv).a);
			}
		}
	}
	float rim = (1.0 - alpha) * step(0.5, edge_alpha) * outline_amount;
	float glow = highlight_amount * (0.94 + 0.06 * sin(TIME * 3.2));
	source.rgb = mix(source.rgb, highlight_color.rgb, glow);
	float combined_alpha = source.a + rim * (1.0 - source.a);
	vec3 combined_rgb = (source.rgb * source.a + outline_color.rgb * rim * (1.0 - source.a)) / max(combined_alpha, 0.0001);
	COLOR = vec4(combined_rgb, combined_alpha);
}
