# Godot 4.5 VFX Cheatsheet (2D)

Practical patterns and copy‑pasteable snippets for visual effects in Godot 4.5, focused on 2D (`CanvasItem`) nodes like `Sprite2D` and `TextureRect`.

## Building Blocks

- `CanvasItem.modulate` (GDScript): Multiply/tint a node’s visual color and alpha. Fast and simple for flashes and fades.
- `Tween` (GDScript): Animate properties over time (e.g., color, alpha, scale, position). Use `create_tween()` in Godot 4.x.
- `Shader` + `ShaderMaterial` (CanvasItem shader): Custom pixel/vertex effects, outlines, dissolve, glows, etc.
- `ColorRect` overlay (UI): Full‑rect screen/slot flashes or mask overlays with `z_index` and optional `top_level`.
- `GPUParticles2D`: Burst particles for hits, dust, sparks (use a `ParticlesMaterial` or shader on the process material).
- `AnimationPlayer`: Author multi‑track effects (position/scale/color/material params) if you prefer timeline editing.

Where to put shaders/materials:

- Attach a `ShaderMaterial` to any `CanvasItem` node via its `material` property:
  - `Sprite2D`, `TextureRect`, `Label`, `Polygon2D`, `MeshInstance2D`, etc.
- For global/overlay flashes, add a `ColorRect` (child of a relevant `Control`), set anchors to full rect, and tween its alpha.

Note: If a node uses a material that overrides output color, `modulate` may have reduced or no effect—prefer shader parameters for predictability.

## GDScript Patterns

Hit flash via `modulate` (simple and fast):

```gdscript
# node: CanvasItem (Sprite2D / TextureRect / any CanvasItem)
func play_hit_flash(sprite: CanvasItem, flash_color: Color = Color(1.8, 0.0, 1.8, 1.0), hold: float = 0.06, fade: float = 0.22) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var original := sprite.modulate
	sprite.modulate = flash_color
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		t.tween_interval(hold)
	t.tween_property(sprite, "modulate", original, max(0.01, fade))
```

Overlay flash via `ColorRect` (covers an area, e.g., tile bounds):

```gdscript
func spawn_overlay_flash(parent: Control, color := Color(1, 1, 1, 0.4), duration := 0.25, top_level := false, rect := Rect2()) -> void:
	if parent == null:
		return
	var flash := ColorRect.new()
	parent.add_child(flash)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = color
	flash.z_index = 120
	if top_level:
		flash.top_level = true
		flash.global_position = rect.position
		flash.size = rect.size
	else:
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.offset_left = flash.offset_top = flash.offset_right = flash.offset_bottom = 0
	var t := flash.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(flash, "modulate:a", 0.0, max(0.05, duration))
	t.finished.connect(flash.queue_free)
```

Animating a shader uniform (property path or setter):

```gdscript
func drive_shader_param(mat: ShaderMaterial, param: String, from_v: float, to_v: float, dur: float) -> void:
	if mat == null:
		return
	# Option A: property path
	var t := create_tween()
	t.tween_property(mat, "shader_parameter/%s" % param, to_v, dur).from(from_v)
	# Option B: method driver
	# create_tween().tween_method(func(v): mat.set_shader_parameter(param, v), from_v, to_v, dur)
```

Scale “punch” on hit (sprite squash/expand):

```gdscript
func punch_scale(node: Node2D, factor := 1.15, up := 0.12, down := 0.14) -> void:
	if node == null:
		return
	var base := node.scale
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "scale", base * factor, max(0.01, up)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().set_parallel(true)
	t.tween_property(node, "scale", base, max(0.01, down)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
```

Hooking effects to gameplay events:

```gdscript
# Example of wiring a game/engine signal to visual effects
func _ready() -> void:
	if engine and not engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
		engine.hit_applied.connect(_on_hit_applied)

func _on_hit_applied(team: String, si: int, ti: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, _pcd: float, _ecd: float) -> void:
	if dealt > 0 and after_hp < before_hp:
		var actor := get_target_actor(team, ti)
		if actor and actor.sprite:
			play_hit_flash(actor.sprite)
			punch_scale(actor)
```

## CanvasItem Shader Examples (Godot 4.5)

Attach these by creating a `Shader`, a `ShaderMaterial`, setting the shader on it, then assigning the material to your `CanvasItem.material`.

Simple tint/flash uniform (mix to a color):

```glsl
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0; // 0=off, 1=full

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 base = tex * COLOR; // includes modulate
	vec4 target = vec4(flash_color.rgb, base.a);
	vec4 mixed = mix(base, target, flash_amount);
	COLOR = vec4(mixed.rgb, base.a);
}
```

Outline (sample neighboring alpha; cheap 8‑tap):

```glsl
shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_px : hint_range(0.0, 8.0) = 1.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * outline_px;
	float a0 = texture(TEXTURE, UV).a;
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2( px.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0,  px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px)).a);
	a = max(a, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2( px)).a);
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float edge = step(0.001, a - a0);
	vec3 rgb = mix(base.rgb, outline_color.rgb, edge * outline_color.a);
	float out_a = max(base.a, edge * outline_color.a);
	COLOR = vec4(rgb, out_a);
}
```

Dissolve (threshold with noise):

```glsl
shader_type canvas_item;

uniform sampler2D noise_tex : source_color, filter_linear_mipmap;
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.0, 0.2) = 0.04;
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float n = texture(noise_tex, UV).r;
	float mask = smoothstep(threshold - edge_width, threshold, n);
	if (n < threshold) discard; // burned away
	vec4 base = tex * COLOR;
	vec3 edge_mix = mix(edge_color.rgb, base.rgb, mask);
	COLOR = vec4(edge_mix, base.a);
}
```

Directional scan/sweep highlight (drive `progress` 0→1 from code):

```glsl
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float width : hint_range(0.0, 0.5) = 0.2;
uniform float strength : hint_range(0.0, 2.0) = 0.9;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.3, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	float band = 1.0 - smoothstep(progress - width, progress + width, UV.y);
	vec3 add = color.rgb * band * strength;
	COLOR = vec4(base.rgb + add, base.a);
}
```

Applying a shader from code (Godot 4.x):

```gdscript
var sh := Shader.new()
sh.code = preload("res://path/to/your_shader.gdshader").code # or set string code directly
var mat := ShaderMaterial.new()
mat.shader = sh
sprite.material = mat # sprite is CanvasItem

# Drive parameters
mat.set_shader_parameter("flash_amount", 1.0)
create_tween().tween_property(mat, "shader_parameter/flash_amount", 0.0, 0.25)
```

## Effect Options You Can Mix & Match

- Tint/flash: via `modulate` or a shader uniform (color/amount).
- Blink/invulnerability: tween `modulate.a` or toggle `visible` quickly.
- Scale/position punch: squash/stretch or nudge position for impact.
- Outline on hit: enable outline shader or set outline strength briefly.
- Dissolve on death: animate `threshold` uniform from 0→1.
- Scan/sweep: drive `progress` across 0→1 to create a highlight pass.
- Overlay flash: area `ColorRect` with alpha fade, optionally `top_level` + `z_index` to sit above UI.
- Particles: `GPUParticles2D` burst, short lifetime, one‑shot.
- Screen shake: tween camera/parent `offset` or use a camera shake script.
- Damage numbers: spawn `Label`→float up→fade out.

## Tips and Troubleshooting

- If `modulate` appears ignored, the material/shader likely overwrites color; switch to a shader uniform and mix with the sampled texture.
- Prefer reusing a single `ShaderMaterial` per sprite for multiple effects; drive uniforms instead of swapping materials each frame.
- Tweening shader params: property path is `"shader_parameter/<name>"`.
- For overlay flashes that must ignore parent transforms/clipping, set `ColorRect.top_level = true` and position in global coordinates.
- Use `z_index` consistently so overlays aren’t hidden under sprites/bars.
- Avoid creating many short‑lived tweens per frame; chain or reuse where possible.

## References

- Godot 4.x shaders overview: docs → Shaders → Shading language
- CanvasItem shaders (2D): shader_type `canvas_item`
- `ShaderMaterial` and `set_shader_parameter`
- Tweens (`create_tween`, `tween_property`, `tween_method`)
- Particles2D and `ParticlesMaterial`

These examples follow Godot 4.x syntax and are compatible with 4.5.
