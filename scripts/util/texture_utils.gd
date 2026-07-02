extends Object
class_name TextureUtils

static func make_circle_texture(color: Color, tex_size: int) -> ImageTexture:
    var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var cx: float = float(tex_size) * 0.5
    var cy: float = float(tex_size) * 0.5
    var r: float = float(tex_size) * 0.45
    var r2: float = r * r
    for y in range(tex_size):
        for x in range(tex_size):
            var dx: float = float(x) - cx
            var dy: float = float(y) - cy
            var d2: float = dx * dx + dy * dy
            if d2 <= r2:
                img.set_pixel(x, y, color)
    var tex: ImageTexture = ImageTexture.create_from_image(img)
    return tex

static func try_load_texture(path: String) -> Texture2D:
    if path == "":
        return null
    if ResourceLoader.exists(path, "Texture2D"):
        var resource: Resource = ResourceLoader.load(path, "Texture2D")
        var imported_texture: Texture2D = resource as Texture2D
        if imported_texture != null:
            return imported_texture
    if not FileAccess.file_exists(path):
        return null
    var image: Image = Image.new()
    var error: Error = image.load(path)
    if error != OK or image.is_empty():
        return null
    return ImageTexture.create_from_image(image)

static func load_texture(path: String, fallback_color: Color, fallback_size: int) -> Texture2D:
    var texture: Texture2D = try_load_texture(path)
    if texture != null:
        return texture
    return make_circle_texture(fallback_color, fallback_size)
