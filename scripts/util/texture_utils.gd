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
