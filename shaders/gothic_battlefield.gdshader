shader_type canvas_item;

uniform vec4 void_color : source_color = vec4(0.010, 0.008, 0.012, 1.0);
uniform vec4 stone_color : source_color = vec4(0.050, 0.044, 0.052, 1.0);
uniform vec4 blood_haze : source_color = vec4(0.34, 0.020, 0.040, 1.0);
uniform vec4 brass_line : source_color = vec4(0.72, 0.46, 0.22, 1.0);
uniform vec4 blue_iron : source_color = vec4(0.16, 0.23, 0.26, 1.0);
uniform float sigil_strength = 0.28;
uniform float grain_strength = 0.035;
uniform float vignette_strength = 0.86;
uniform float opacity = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float ring(vec2 p, float radius, float width) {
	return 1.0 - smoothstep(width, width * 2.2, abs(length(p) - radius));
}

float line(vec2 p, float angle, float width) {
	vec2 dir = vec2(cos(angle), sin(angle));
	float d = abs(dot(p, dir));
	return 1.0 - smoothstep(width, width * 2.6, d);
}

void fragment() {
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5, 0.5);
	vec2 arena = centered * vec2(1.65, 1.0);

	vec3 col = mix(stone_color.rgb, void_color.rgb, smoothstep(0.05, 0.98, uv.y));
	col = mix(col, blood_haze.rgb, smoothstep(0.0, 0.72, uv.y) * 0.18);
	col = mix(col, blue_iron.rgb, smoothstep(0.65, 0.05, uv.y) * 0.10);

	float grain = hash21(floor(uv * vec2(280.0, 150.0)) + floor(TIME * 8.0));
	col += (grain - 0.5) * grain_strength;

	float rings = ring(arena, 0.31, 0.0035) + ring(arena, 0.43, 0.0025) * 0.65;
	float ward = max(line(arena, 0.785398, 0.0024), line(arena, -0.785398, 0.0024));
	ward = max(ward, line(arena, 0.0, 0.0016) * 0.55);
	float sigil = clamp(rings + ward * 0.65, 0.0, 1.0);
	col = mix(col, brass_line.rgb, sigil * sigil_strength);

	float ember = smoothstep(0.988, 1.0, hash21(floor(uv * vec2(92.0, 54.0)) + vec2(floor(TIME * 0.7))));
	col = mix(col, brass_line.rgb, ember * 0.10);

	float dist = length(centered * vec2(1.08, 1.18));
	float vignette = smoothstep(0.20, 0.78, dist) * vignette_strength;
	col *= mix(1.0, 0.20, vignette);

	COLOR = vec4(col, opacity);
}
