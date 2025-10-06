// Flow-warped iso-lines = subtle dancing vines. No grain.
shader_type canvas_item;
render_mode unshaded;

// Colors
uniform vec4 color_a : source_color = vec4(0.02, 0.03, 0.04, 1.0);
uniform vec4 color_b : source_color = vec4(0.00, 0.10, 0.12, 1.0);
uniform vec4 vine_color : source_color = vec4(0.04, 0.60, 0.62, 1.0);

// Tileable noise (Repeat=Enabled, Filter=Linear, 256–512px)
uniform sampler2D noise_tex : source_color;

// Controls
uniform float base_brightness = 1.0;
uniform float field_scale = 0.0;     // size of the flow field
uniform float field_speed = 1.10;    // flow animation speed
uniform float warp_strength = 3.06;  // domain warp amount
uniform float line_freq = 1.0;       // number of “vines”
uniform float line_width = 0.6;     // thickness of vines
uniform float line_soft = 0.0;      // softness of edges
uniform float mix_amount = 1.5;     // how strongly vines tint the base
uniform float vignette_strength = 0;

float n2(vec2 p) { return texture(noise_tex, p).r; }

float fbm(vec2 p) {
    float a = 0.5;
    float f = 0.0;
    for (int i = 0; i < 4; i++) {
        f += a * n2(p);
        p *= 2.03;
        a *= 0.5;
    }
    return f;
}

// Signed-ish distance to iso-lines of fbm
float iso_lines(vec2 p, float freq) {
    float v = fbm(p);
    float f = fract(v * freq);           // repeat bands
    float d = abs(f - 0.5);              // distance to band center
    return d;                            // small = on the line
}

void fragment() {
    float t = TIME;

    // Vertical base gradient
    vec4 col = mix(color_a, color_b, smoothstep(0.0, 1.0, UV.y));
    col.rgb *= base_brightness;

    // Domain warp by animated flow field
    vec2 p = UV * field_scale;
    vec2 f1 = texture(noise_tex, p + vec2( t*field_speed, -t*field_speed*0.7)).rg * 2.0 - 1.0;
    vec2 f2 = texture(noise_tex, p + vec2(-t*field_speed*0.6,  t*field_speed*0.9)).rg * 2.0 - 1.0;
    vec2 warp = (f1 + f2) * warp_strength;
    vec2 q = p + warp;

    // Two layers with slight offsets/orientations to avoid a grid feel
    float d1 = iso_lines(q,          line_freq);
    float d2 = iso_lines(q + vec2(0.31, -0.17), line_freq * 0.85);

    // Convert distances to line masks
    float w  = line_width;
    float s1 = smoothstep(w + line_soft, w, d1);
    float s2 = smoothstep(w + line_soft, w, d2);
    float vines = max(s1, s2);

    // Fade toward edges
    vec2 c = UV - 0.5;
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    c.x *= aspect;
    float r = length(c);
    vines *= exp(-r * 2.4);

    // Apply tint
    col.rgb = mix(col.rgb, vine_color.rgb, mix_amount * vines);

    // Vignette
    float vig = 1.0 - smoothstep(0.35, 0.90, r);
    col.rgb *= mix(1.0, vig, vignette_strength);

    COLOR = col;
}
