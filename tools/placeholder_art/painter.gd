extends RefCounted
## Bộ "cọ vẽ" tối giản để sinh placeholder art kiểu painterly bằng code (không dùng asset bên ngoài).
## Ảnh lưu dạng RGBA float (straight alpha); blend "over". Tùy chọn wrap để tạo texture lặp liền mạch.

var w: int
var h: int
var wrap: bool
var px: PackedFloat32Array


func _init(width: int, height: int, fill: Color = Color(0, 0, 0, 0), wrap_edges: bool = false) -> void:
	w = width
	h = height
	wrap = wrap_edges
	px = PackedFloat32Array()
	px.resize(w * h * 4)
	for i: int in w * h:
		px[i * 4] = fill.r
		px[i * 4 + 1] = fill.g
		px[i * 4 + 2] = fill.b
		px[i * 4 + 3] = fill.a


func get_c(x: int, y: int) -> Color:
	if wrap:
		x = posmod(x, w)
		y = posmod(y, h)
	elif x < 0 or y < 0 or x >= w or y >= h:
		return Color(0, 0, 0, 0)
	var i: int = (y * w + x) * 4
	return Color(px[i], px[i + 1], px[i + 2], px[i + 3])


func get_alpha(x: int, y: int) -> float:
	if wrap:
		x = posmod(x, w)
		y = posmod(y, h)
	elif x < 0 or y < 0 or x >= w or y >= h:
		return 0.0
	return px[(y * w + x) * 4 + 3]


func set_c(x: int, y: int, c: Color) -> void:
	if wrap:
		x = posmod(x, w)
		y = posmod(y, h)
	elif x < 0 or y < 0 or x >= w or y >= h:
		return
	var i: int = (y * w + x) * 4
	px[i] = c.r
	px[i + 1] = c.g
	px[i + 2] = c.b
	px[i + 3] = c.a


## Blend "over" một màu với độ phủ a tại (x, y).
func blend(x: int, y: int, c: Color, a: float) -> void:
	if a <= 0.0:
		return
	if wrap:
		x = posmod(x, w)
		y = posmod(y, h)
	elif x < 0 or y < 0 or x >= w or y >= h:
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


## Nhân màu (giữ alpha) — dùng cho bóng/AO trên vùng đã vẽ.
func multiply(x: int, y: int, f: float) -> void:
	if wrap:
		x = posmod(x, w)
		y = posmod(y, h)
	elif x < 0 or y < 0 or x >= w or y >= h:
		return
	var i: int = (y * w + x) * 4
	px[i] *= f
	px[i + 1] *= f
	px[i + 2] *= f


## Nét chấm tròn mềm. hardness: phần lõi đặc (0..1).
func dab(cx: float, cy: float, r: float, c: Color, a: float, hardness: float = 0.5) -> void:
	ellipse(cx, cy, r, r, 0.0, c, a, hardness)


func ellipse(cx: float, cy: float, rx: float, ry: float, angle: float, c: Color, a: float, hardness: float = 0.5) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var reach: float = maxf(rx, ry) + 1.0
	var x0: int = floori(cx - reach)
	var x1: int = ceili(cx + reach)
	var y0: int = floori(cy - reach)
	var y1: int = ceili(cy + reach)
	var ca: float = cos(angle)
	var sa: float = sin(angle)
	var soft: float = maxf(0.0001, 1.0 - hardness)
	for y: int in range(y0, y1 + 1):
		var dy: float = y + 0.5 - cy
		for x: int in range(x0, x1 + 1):
			var dx: float = x + 0.5 - cx
			var u: float = (dx * ca + dy * sa) / rx
			var v: float = (-dx * sa + dy * ca) / ry
			var d: float = sqrt(u * u + v * v)
			if d >= 1.0:
				continue
			var f: float = 1.0 if d <= hardness else 1.0 - (d - hardness) / soft
			f = f * f * (3.0 - 2.0 * f)
			blend(x, y, c, a * f)


## Nét cọ thẳng từ (x0,y0) tới (x1,y1), bán kính nội suy r0 → r1, màu nội suy c0 → c1.
func stroke(x0: float, y0: float, x1: float, y1: float, r0: float, r1: float, c0: Color, c1: Color, a: float, hardness: float = 0.6) -> void:
	var length: float = Vector2(x1 - x0, y1 - y0).length()
	var steps: int = maxi(1, ceili(length / maxf(0.5, minf(r0, r1) * 0.6)))
	for i: int in steps + 1:
		var t: float = float(i) / steps
		dab(lerpf(x0, x1, t), lerpf(y0, y1, t), lerpf(r0, r1, t), c0.lerp(c1, t), a, hardness)


func to_image() -> Image:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(w * h * 4)
	for i: int in w * h * 4:
		bytes[i] = clampi(roundi(px[i] * 255.0), 0, 255)
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)


func save(path: String) -> void:
	var err: Error = to_image().save_png(path)
	if err != OK:
		push_error("Không lưu được %s (%s)" % [path, error_string(err)])
	else:
		print("  wrote ", path)
