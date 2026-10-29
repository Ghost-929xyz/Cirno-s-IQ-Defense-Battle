shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_mask : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(80.0, 50.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

float ice_cracks(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 seed = vec2(hash(cell + offset), hash(cell + offset + vec2(19.7, 41.3)));
			float distance = length(offset + seed - f);
			if (distance < nearest) {
				second = nearest;
				nearest = distance;
			} else {
				second = min(second, distance);
			}
		}
	}
	return 1.0 - smoothstep(0.015, 0.055, second - nearest);
}

void fragment() {
	vec2 p = UV * map_size;
	float water = texture(terrain_mask, UV).r;
	float patches = 0.55 * noise(p * 0.65) + 0.3 * noise(p * 2.3) + 0.15 * noise(p * 7.0);
	float snow = smoothstep(patches - 0.15, patches + 0.15, coverage) * smoothstep(0.0, 0.15, coverage);
	float ice = smoothstep(0.05, 0.6, coverage);
	float veins = ice_cracks(p * 0.7);
	vec3 snow_color = mix(vec3(0.80, 0.90, 0.97), vec3(0.98, 0.99, 1.0), noise(p * 5.0));
	vec3 ice_color = mix(vec3(0.48, 0.76, 0.87), vec3(0.91, 0.98, 1.0), veins * 0.65 + snow * 0.28);
	COLOR = vec4(mix(snow_color, ice_color, water), mix(snow * 0.78, ice * 0.87, water));
}
