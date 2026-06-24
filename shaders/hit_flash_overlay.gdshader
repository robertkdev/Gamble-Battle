shader_type canvas_item;

// Additive-tint overlay that follows the sprite's texture shape.
// Intended to be used on a TextureRect overlaid above the base sprite.
// Drive `amount` (0..1) from code to animate the flash.

render_mode blend_add;

uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 1.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float a = tex.a;
    // Additive contribution scaled by the texture's alpha and effect amount.
    vec3 add_rgb = flash_color.rgb * a * amount;
    // Alpha is not used in additive blending, but keep proportional for consistency/tools.
    COLOR = vec4(add_rgb, a * amount);
}
