shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float clock = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float pulse = 0.78 + sin(clock * 2.1) * 0.13 + sin(clock * 3.7) * 0.04;
	float halo = pow(max(0.0, 1.0 - length(p)), 1.7);
	float core = pow(max(0.0, 1.0 - abs(p.x) * 4.0 - abs(p.y) * 1.8), 1.4);
	float motes = 0.0;
	for (int i = 0; i < 4; i++) {
		float seed = float(i);
		float phase = fract(clock * 0.22 + seed * 0.25);
		vec2 center = vec2(sin(seed * 7.1 + clock * 0.7) * 0.42, 0.18 - phase * 0.95);
		float d = max(abs(p.x - center.x), abs(p.y - center.y));
		motes += (1.0 - smoothstep(0.018, 0.045, d)) * sin(phase * 3.14159);
	}
	vec3 tint = mix(vec3(0.58, 0.28, 1.0), vec3(0.92, 0.84, 1.0), clamp(core + motes, 0.0, 1.0));
	COLOR = vec4(tint, clamp((halo * 0.6 + core * 0.45) * pulse + motes * 0.45, 0.0, 0.75));
}
