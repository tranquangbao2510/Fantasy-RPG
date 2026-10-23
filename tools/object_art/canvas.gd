extends RefCounted
## Ảnh RGBA (float, straight alpha) cho tool object_art: tô đa giác / hình tròn có khử răng cưa (4 × 4 mẫu mỗi texel),
## đường thẳng, dán ảnh có sẵn. Toạ độ vẽ là toạ độ WORLD của đồ vật (origin = chân vật); `anchor` + `texel_per_px`
## đổi sang texel — như ObjectSprite hiển thị ngược lại (offset = −anchor, scale = 1 / texel_per_px).

const SAMPLES: int = 4

var w: int
var h: int
var anchor: Vector2
var texel_per_px: float
var px: PackedFloat32Array


func _init(width: int, height: int, anchor_texel: Vector2, texels_per_world_px: float = 2.0) -> void:
	w = width
	h = height
	anchor = anchor_texel
	texel_per_px = texels_per_world_px
	px = PackedFloat32Array()
	px.resize(w * h * 4)


func to_texel(world: Vector2) -> Vector2:
	return anchor + world * texel_per_px


## Tô đa giác (toạ độ world) — giống Polygon2D / draw_colored_polygon.
func polygon(points: PackedVector2Array, color: Color) -> void:
	var texel: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		texel.append(to_texel(p))
	var bounds: Rect2 = Rect2(texel[0], Vector2.ZERO)
	for p: Vector2 in texel:
		bounds = bounds.expand(p)
	_fill(bounds, func(s: Vector2) -> bool: return Geometry2D.is_point_in_polygon(s, texel), color)


## Hình tròn đặc (toạ độ world) — giống draw_circle.
func circle(center: Vector2, radius: float, color: Color) -> void:
	var c: Vector2 = to_texel(center)
	var r: float = radius * texel_per_px
	_fill(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), func(s: Vector2) -> bool: return s.distance_squared_to(c) <= r * r, color)


## Đoạn thẳng dày `width` (px world) — giống draw_line.
func line(a: Vector2, b: Vector2, color: Color, width: float = 1.0) -> void:
	var n: Vector2 = (b - a).normalized().orthogonal() * width * 0.5
	polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), color)


## Đường gấp khúc khép kín (khung hướng dẫn) dày `width_texel` texel.
func outline(points: PackedVector2Array, color: Color, width_texel: float = 1.0) -> void:
	for k: int in points.size():
		line(points[k], points[(k + 1) % points.size()], color, width_texel / texel_per_px)


## Dán ảnh (đã cùng mật độ texel) với góc trên-trái tại `top_left` (texel), blend "over".
func blit(image: Image, top_left: Vector2i) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			_blend(top_left.x + x, top_left.y + y, c, c.a)


func duplicate_canvas() -> RefCounted:
	var copy: RefCounted = get_script().new(w, h, anchor, texel_per_px)
	copy.px = px.duplicate()
	return copy


func to_image() -> Image:
	var image: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y: int in h:
		for x: int in w:
			var i: int = (y * w + x) * 4
			image.set_pixel(x, y, Color(px[i], px[i + 1], px[i + 2], px[i + 3]))
	return image


## Phần nội dung (alpha > 0) — để kiểm tra lề trong suốt.
func used_rect() -> Rect2i:
	return to_image().get_used_rect()


func _fill(bounds: Rect2, inside: Callable, color: Color) -> void:
	var x0: int = maxi(0, floori(bounds.position.x))
	var y0: int = maxi(0, floori(bounds.position.y))
	var x1: int = mini(w - 1, ceili(bounds.end.x))
	var y1: int = mini(h - 1, ceili(bounds.end.y))
	var step: float = 1.0 / SAMPLES
	for y: int in range(y0, y1 + 1):
		for x: int in range(x0, x1 + 1):
			var hits: int = 0
			for sy: int in SAMPLES:
				for sx: int in SAMPLES:
					if inside.call(Vector2(x + (sx + 0.5) * step, y + (sy + 0.5) * step)):
						hits += 1
			if hits > 0:
				_blend(x, y, color, color.a * hits / float(SAMPLES * SAMPLES))


func _blend(x: int, y: int, c: Color, a: float) -> void:
	if a <= 0.0 or x < 0 or y < 0 or x >= w or y >= h:
		return
	var i: int = (y * w + x) * 4
	var da: float = px[i + 3]
	var oa: float = a + da * (1.0 - a)
	if oa <= 0.00001:
		return
	var k: float = da * (1.0 - a)
	px[i] = (c.r * a + px[i] * k) / oa
	px[i + 1] = (c.g * a + px[i + 1] * k) / oa
	px[i + 2] = (c.b * a + px[i + 2] * k) / oa
	px[i + 3] = oa
