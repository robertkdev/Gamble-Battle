shader_type canvas_item;

// Bottom-up scan highlight that only affects non-transparent pixels.
// Apply to a TextureRect/CanvasItem that draws the unit sprite.

uniform float progress : hint_range(0.0, 1.0) = 0.0;        // 0..1 from bottom (0) to top (1)
uniform float width    : hint_range(0.01, 1.0) = 0.25;      // band width as fraction of height
uniform vec4 color     : source_color = vec4(1.0, 0.9, 0.3, 1.0);
uniform float strength : hint_range(0.0, 2.0) = 0.7;        // intensity of highlight blend
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.01; // mask non-transparent pixels

void fragment() {
    vec4 base = texture(TEXTURE, UV);

    // 1. Visibility mask: 1 for visible sprite pixels, 0 for near-transparent
    float visible = step(alpha_threshold, base.a);

    // 2. Band shape along bottom->top
    float yinv = 1.0 - UV.y;
    float half_w = max(0.0001, width * 0.5);
    float d = abs(yinv - progress);
    float band = 1.0 - smoothstep(0.0, half_w, d);
    band = clamp(band, 0.0, 1.0);

    // 3. Highlight only where visible
    float intensity = clamp(band * strength * visible, 0.0, 1.0);
    vec3 boosted = clamp(base.rgb + color.rgb * intensity, 0.0, 1.0);

    COLOR = vec4(boosted, base.a);
}
