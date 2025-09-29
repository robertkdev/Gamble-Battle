extends Object
class_name TextureUtils

static func make_circle_texture(color: Color, tex_size: int) -> ImageTexture:
    var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var cx := float(tex_size) * 0.5
    var cy := float(tex_size) * 0.5
    var r := float(tex_size) * 0.45
    var r2 := r * r
    for y in range(tex_size):
        for x in range(tex_size):
            var dx := float(x) - cx
            var dy := float(y) - cy
            var d2: float = dx * dx + dy * dy
            if d2 <= r2:
                img.set_pixel(x, y, color)
    var tex := ImageTexture.create_from_image(img)
    return tex

static func _hash_string(s: String) -> int:
    # djb2 string hash for stable, cross-session color mapping
    var h: int = 5381
    for i in s.length():
        h = ((h << 5) + h) + int(s.unicode_at(i))
        # Constrain to 32-bit signed range to avoid overflow differences
        if h > 0x7fffffff:
            h -= 0x100000000
        elif h < -0x80000000:
            h += 0x100000000
    return h

static func color_for_key(key: String) -> Color:
    var s := String(key)
    if s == "":
        return Color(0.5, 0.5, 0.5, 1.0)
    var hv: int = _hash_string(s)
    # Map to hue in [0,1)
    var hue := fmod(abs(float(hv)), 360.0) / 360.0
    var sat := 0.65
    var val := 0.9
    return Color.from_hsv(hue, sat, val, 1.0)

static func placeholder_icon_for_id(id: String, tex_size: int = 48) -> ImageTexture:
    return make_circle_texture(color_for_key(id), tex_size)
