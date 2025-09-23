shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(0.06, 0.06, 0.08, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float vignette = 0.75; // 0..1 strength
uniform float vignette_softness = 0.6;

void fragment() {
    vec2 uv = UV;
    vec3 col = mix(top_color.rgb, bottom_color.rgb, clamp(uv.y, 0.0, 1.0));

    // Soft vignette
    vec2 centered = uv - vec2(0.5, 0.5);
    float dist = length(centered * vec2(1.1, 1.3));
    float vig = smoothstep(vignette, vignette + vignette_softness, dist);
    col *= mix(1.0, 0.35, vig);

    COLOR = vec4(col, 1.0);
}
