extends SceneTree
## Sinh placeholder art cho Environment Prototype (TASK VISUAL 01) bằng code — không dùng asset bên ngoài.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/placeholder_art/generate_environment_art.gd
## Sau khi sinh lại: mở Editor (hoặc chạy --headless --import) để Godot import lại PNG.
##
## Quy ước (xem docs/visual/environment-style-guide.md):
## - Mật độ texel = 2 texel / 1 đơn vị world (sprite dùng scale 0.5).
## - Ánh sáng chính từ trên-trái (tây bắc); bóng đổ về dưới-phải.
## - Đây là PLACEHOLDER kỹ thuật, không phải production art.

const Painter := preload("res://tools/placeholder_art/painter.gd")
const OUT: String = "res://world/environment/art/"

## Hướng tới nguồn sáng trong mặt phẳng ảnh (trên-trái) và trong 3D (z hướng ra người xem).
var L2: Vector2 = Vector2(-0.62, -0.78).normalized()
var L3: Vector3 = Vector3(-0.55, -0.6, 0.58).normalized()


func _init() -> void:
	var only: String = OS.get_environment("ART_ONLY")
	var jobs: Dictionary = {
		"ground": _ground_textures,
		"cliff": _cliff_textures,
		"trees": _trees,
		"plants": _plants,
		"rocks": _rocks,
		"ruins": _ruins,
		"structures": _structures,
		"decals": _decals,
		"fx": _fx,
		"scenery": _scenery,
		"logic": _logic_tiles,
	}
	for key: String in jobs:
		if only != "" and not only.split(",").has(key):
			continue
		print("[art] ", key)
		var job: Callable = jobs[key]
		job.call()
	quit()


# ---------------------------------------------------------------- helpers

func _dir(sub: String) -> String:
	var path: String = OUT + sub + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	return path


func _noise(seed_value: int, freq: float, octaves: int = 4, kind: FastNoiseLite.NoiseType = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.noise_type = kind
	n.fractal_octaves = octaves
	return n


## Ảnh noise lặp liền mạch, trả về mảng [0..1].
func _seamless(seed_value: int, size: Vector2i, freq: float, octaves: int = 4) -> PackedFloat32Array:
	var n: FastNoiseLite = _noise(seed_value, freq, octaves)
	var img: Image = n.get_seamless_image(size.x, size.y, false, false, 0.15)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(size.x * size.y)
	for y: int in size.y:
		for x: int in size.x:
			out[y * size.x + x] = img.get_pixel(x, y).r
	return out


func _n01(n: FastNoiseLite, x: float, y: float) -> float:
	return n.get_noise_2d(x, y) * 0.5 + 0.5


func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


func _jitter(rng: RandomNumberGenerator, c: Color, amount: float) -> Color:
	var f: float = 1.0 + rng.randf_range(-amount, amount)
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f * (1.0 + rng.randf_range(-amount, amount) * 0.4), 0, 1), clampf(c.b * f, 0, 1), c.a)


## Ramp nhiều điểm màu theo t ∈ [0, 1].
func _ramp(stops: Array[Color], t: float) -> Color:
	t = clampf(t, 0.0, 0.9999) * (stops.size() - 1)
	var i: int = floori(t)
	return stops[i].lerp(stops[i + 1], t - i)


## Voronoi lặp theo trục x (và y nếu wrap_y). Trả về [id ô gần nhất, d1, d2] cho mỗi pixel.
func _voronoi(size: Vector2i, cell: Vector2, rng: RandomNumberGenerator, wrap_y: bool) -> Dictionary:
	var gx: int = maxi(1, roundi(size.x / cell.x))
	var gy: int = maxi(1, roundi(size.y / cell.y))
	var cw: float = float(size.x) / gx
	var ch: float = float(size.y) / gy
	var points: PackedVector2Array = PackedVector2Array()
	for j: int in gy:
		for i: int in gx:
			points.append(Vector2((i + rng.randf_range(0.15, 0.85)) * cw, (j + rng.randf_range(0.15, 0.85)) * ch))
	var ids: PackedInt32Array = PackedInt32Array()
	var d1s: PackedFloat32Array = PackedFloat32Array()
	var d2s: PackedFloat32Array = PackedFloat32Array()
	ids.resize(size.x * size.y)
	d1s.resize(size.x * size.y)
	d2s.resize(size.x * size.y)
	for y: int in size.y:
		var cj: int = floori(y / ch)
		for x: int in size.x:
			var ci: int = floori(x / cw)
			var best: float = 1e9
			var second: float = 1e9
			var best_id: int = 0
			for oj: int in range(-1, 2):
				var jj: int = cj + oj
				var shift_y: float = 0.0
				if wrap_y:
					shift_y = floorf(float(jj) / gy) * size.y
					jj = posmod(jj, gy)
				elif jj < 0 or jj >= gy:
					continue
				for oi: int in range(-1, 2):
					var ii: int = ci + oi
					var shift_x: float = floorf(float(ii) / gx) * size.x
					ii = posmod(ii, gx)
					var p: Vector2 = points[jj * gx + ii] + Vector2(shift_x, shift_y)
					var d: float = p.distance_to(Vector2(x + 0.5, y + 0.5))
					if d < best:
						second = best
						best = d
						best_id = jj * gx + ii
					elif d < second:
						second = d
			ids[y * size.x + x] = best_id
			d1s[y * size.x + x] = best
			d2s[y * size.x + x] = second
	return {"id": ids, "d1": d1s, "d2": d2s, "points": points}


## Bevel cho ảnh có mask alpha: sáng ở cạnh trên-trái, tối ở cạnh dưới-phải.
func _bevel(c: Painter, k: int, light: float, dark: float) -> void:
	var src: PackedFloat32Array = c.px.duplicate()
	for y: int in c.h:
		for x: int in c.w:
			var i: int = (y * c.w + x) * 4
			var a: float = src[i + 3]
			if a < 0.5:
				continue
			var tl: float = _alpha_of(src, c.w, c.h, x - k, y - k)
			var br: float = _alpha_of(src, c.w, c.h, x + k, y + k)
			var f: float = 1.0 + (1.0 - tl) * light - (1.0 - br) * dark
			c.px[i] = src[i] * f
			c.px[i + 1] = src[i + 1] * f
			c.px[i + 2] = src[i + 2] * f


func _alpha_of(src: PackedFloat32Array, w: int, h: int, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 0.0
	return src[(y * w + x) * 4 + 3]


## Rêu theo mặt hướng lên (vùng trên của mask) + noise.
func _moss(c: Painter, seed_value: int, amount: float, top_bias: float = 0.6) -> void:
	var n: FastNoiseLite = _noise(seed_value, 0.045, 3)
	var moss_dark: Color = Color(0.22, 0.33, 0.12)
	var moss_light: Color = Color(0.45, 0.55, 0.2)
	for y: int in c.h:
		for x: int in c.w:
			var a: float = c.get_alpha(x, y)
			if a < 0.5:
				continue
			var up: float = 1.0 - c.get_alpha(x, y - 4)
			var t: float = _n01(n, x, y)
			var m: float = smoothstep(0.62 - amount * 0.3, 0.8 - amount * 0.3, t) * (up * top_bias + (1.0 - top_bias) * 0.5)
			if m > 0.02:
				c.blend(x, y, moss_dark.lerp(moss_light, _n01(n, x * 3.0, y * 3.0)), clampf(m, 0, 0.85))


## Vết nứt ngẫu nhiên (random walk).
func _cracks(c: Painter, rng: RandomNumberGenerator, count: int, length: int, col: Color) -> void:
	for i: int in count:
		var p: Vector2 = Vector2(rng.randf_range(0, c.w), rng.randf_range(0, c.h))
		if c.get_alpha(int(p.x), int(p.y)) < 0.5:
			continue
		var dir: Vector2 = Vector2.from_angle(rng.randf_range(0, TAU))
		for s: int in length:
			dir = dir.rotated(rng.randf_range(-0.5, 0.5)).normalized()
			p += dir
			if c.get_alpha(int(p.x), int(p.y)) < 0.5:
				break
			c.blend(int(p.x), int(p.y), col, 0.7)
			c.blend(int(p.x) + 1, int(p.y) + 1, Color(1, 1, 1), 0.08)


# ---------------------------------------------------------------- ground

func _ground_textures() -> void:
	var dir: String = _dir("ground")
	_grass(dir + "grass_base.png", 11)
	_dirt(dir + "dirt_base.png", 21)
	_stone_floor(dir + "stone_floor.png", 31)


func _grass(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(512, 512)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color.BLACK, true)
	var macro: PackedFloat32Array = _seamless(seed_value, size, 0.006, 3)
	var warm: PackedFloat32Array = _seamless(seed_value + 1, size, 0.012, 3)
	var detail: PackedFloat32Array = _seamless(seed_value + 2, size, 0.06, 2)
	var dark: Color = Color(0.24, 0.37, 0.15)
	var mid: Color = Color(0.34, 0.49, 0.2)
	var dry: Color = Color(0.48, 0.52, 0.22)
	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x
			var col: Color = dark.lerp(mid, smoothstep(0.1, 0.9, macro[i]))
			col = col.lerp(dry, smoothstep(0.58, 0.85, warm[i]) * 0.45)
			col = _shade(col, 0.92 + detail[i] * 0.16)
			c.set_c(x, y, col)
	# Mảng màu lớn mềm (mottling).
	for i: int in 320:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var base: Color = c.get_c(int(p.x), int(p.y))
		c.dab(p.x, p.y, rng.randf_range(10, 26), _jitter(rng, base, 0.14), 0.22, 0.1)
	# Khe tối giữa các ngọn cỏ.
	for i: int in 3200:
		c.dab(rng.randf() * size.x, rng.randf() * size.y, rng.randf_range(0.8, 1.6), Color(0.07, 0.15, 0.06), 0.45, 0.3)
	# Ngọn cỏ: nét ngắn hướng lên, gốc tối – ngọn sáng.
	for i: int in 15000:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var base: Color = c.get_c(int(p.x), int(p.y))
		var length: float = rng.randf_range(4, 10)
		var ang: float = -PI / 2 + rng.randf_range(-0.55, 0.55)
		var tip: Vector2 = p + Vector2.from_angle(ang) * length
		var light: float = rng.randf_range(0.8, 1.3)
		var tip_col: Color = _shade(base, light).lerp(Color(0.62, 0.7, 0.28), 0.18 * light)
		c.stroke(p.x, p.y, tip.x, tip.y, rng.randf_range(0.8, 1.1), 0.45, _shade(base, 0.8), tip_col, 0.75, 0.5)
	# Điểm sáng (cỏ đón nắng) tập trung ở vùng macro sáng.
	for i: int in 2600:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		if macro[int(p.y) * size.x + int(p.x)] < rng.randf_range(0.3, 0.8):
			continue
		var tip: Vector2 = p + Vector2.from_angle(-PI / 2 + rng.randf_range(-0.4, 0.4)) * rng.randf_range(3, 6)
		c.stroke(p.x, p.y, tip.x, tip.y, 0.7, 0.4, Color(0.5, 0.62, 0.24), Color(0.74, 0.8, 0.38), 0.55, 0.5)
	c.save(path)


func _dirt(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(512, 512)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color.BLACK, true)
	var macro: PackedFloat32Array = _seamless(seed_value, size, 0.008, 3)
	var spots: PackedFloat32Array = _seamless(seed_value + 1, size, 0.03, 3)
	var light: Color = Color(0.6, 0.47, 0.31)
	var mid: Color = Color(0.47, 0.35, 0.23)
	var soil: Color = Color(0.3, 0.22, 0.15)
	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x
			var col: Color = mid.lerp(light, smoothstep(0.3, 0.8, macro[i]))
			col = col.lerp(soil, smoothstep(0.55, 0.8, spots[i]) * 0.6)
			c.set_c(x, y, col)
	for i: int in 380:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		c.dab(p.x, p.y, rng.randf_range(8, 22), _jitter(rng, c.get_c(int(p.x), int(p.y)), 0.12), 0.25, 0.1)
	# Hạt đất mịn.
	for i: int in 7000:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var f: float = rng.randf_range(0.75, 1.25)
		c.dab(p.x, p.y, rng.randf_range(0.6, 1.2), _shade(c.get_c(int(p.x), int(p.y)), f), 0.6, 0.4)
	# Sỏi nhỏ: bóng dưới-phải, thân, highlight trên-trái.
	for i: int in 700:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var r: float = rng.randf_range(1.4, 4.2)
		var ang: float = rng.randf_range(0, TAU)
		var stone: Color = Color(0.55, 0.5, 0.43).lerp(Color(0.42, 0.36, 0.3), rng.randf())
		c.ellipse(p.x + r * 0.35, p.y + r * 0.4, r * 1.1, r * 0.75, ang, Color(0.16, 0.11, 0.07), 0.45, 0.2)
		c.ellipse(p.x, p.y, r, r * 0.72, ang, stone, 0.95, 0.65)
		c.ellipse(p.x - r * 0.3, p.y - r * 0.3, r * 0.45, r * 0.3, ang, _shade(stone, 1.35), 0.6, 0.3)
	c.save(path)


func _stone_floor(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(512, 512)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color.BLACK, true)
	var vor: Dictionary = _voronoi(size, Vector2(92, 74), rng, true)
	var ids: PackedInt32Array = vor["id"]
	var d1s: PackedFloat32Array = vor["d1"]
	var d2s: PackedFloat32Array = vor["d2"]
	var points: PackedVector2Array = vor["points"]
	var grain: FastNoiseLite = _noise(seed_value, 0.08, 3)
	var moss_n: PackedFloat32Array = _seamless(seed_value + 5, size, 0.02, 3)
	var tints: PackedColorArray = PackedColorArray()
	for i: int in points.size():
		tints.append(Color(0.6, 0.57, 0.5).lerp(Color(0.5, 0.5, 0.48), rng.randf()) * rng.randf_range(0.85, 1.1))
	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x
			var edge: float = d2s[i] - d1s[i]
			var col: Color = tints[ids[i]]
			col.a = 1.0
			col = _shade(col, 0.9 + _n01(grain, x, y) * 0.2)
			# Bevel: hướng từ tâm viên đá; cạnh hướng về nguồn sáng sáng hơn.
			var center: Vector2 = points[ids[i]]
			var to_px: Vector2 = Vector2(wrapf(x - center.x, -size.x / 2.0, size.x / 2.0), wrapf(y - center.y, -size.y / 2.0, size.y / 2.0)).normalized()
			var near: float = 1.0 - smoothstep(2.0, 9.0, edge)
			col = _shade(col, 1.0 + near * 0.28 * to_px.dot(L2))
			if edge < 2.6:
				var mortar: Color = Color(0.2, 0.19, 0.15).lerp(Color(0.26, 0.34, 0.14), smoothstep(0.45, 0.7, moss_n[i]))
				col = mortar
			elif edge < 7.0 and moss_n[i] > 0.6:
				col = col.lerp(Color(0.32, 0.42, 0.16), (moss_n[i] - 0.6) * 1.8 * (1.0 - edge / 7.0))
			c.set_c(x, y, col)
	_cracks(c, rng, 40, 30, Color(0.18, 0.17, 0.14))
	c.save(path)


# ---------------------------------------------------------------- cliffs

func _cliff_textures() -> void:
	var dir: String = _dir("cliff")
	_cliff_face(dir + "cliff_face.png", 41)
	_cliff_lip(dir + "cliff_lip.png", 42)
	_cliff_base(dir + "cliff_base.png", 43)


## Mặt vách 512×128 (= 256×64 world), lặp theo x. Các mặt đá (facet) Voronoi kéo dài theo chiều dọc.
func _cliff_face(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(512, 128)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color.BLACK, true)
	# Heightfield = khối đá (Voronoi kéo dài dọc, mỗi khối nhô một độ cao) + noise gồ ghề; ánh sáng tính từ pháp tuyến.
	var vor: Dictionary = _voronoi(size, Vector2(64, 96), rng, false)
	var ids: PackedInt32Array = vor["id"]
	var d1s: PackedFloat32Array = vor["d1"]
	var d2s: PackedFloat32Array = vor["d2"]
	var lift: PackedFloat32Array = PackedFloat32Array()
	var tints: PackedColorArray = PackedColorArray()
	for i: int in (vor["points"] as PackedVector2Array).size():
		lift.append(rng.randf_range(0.0, 5.0))
		tints.append(Color(0.55, 0.49, 0.4).lerp(Color(0.47, 0.45, 0.42), rng.randf()))
	var rough: PackedFloat32Array = _seamless(seed_value + 3, size, 0.022, 5)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(size.x * size.y)
	for i: int in size.x * size.y:
		heights[i] = lift[ids[i]] * 0.7 + minf(d2s[i] - d1s[i], 14.0) * 0.3 + rough[i] * 18.0
	var grain: FastNoiseLite = _noise(seed_value, 0.09, 3)
	var moss: PackedFloat32Array = _seamless(seed_value + 4, size, 0.03, 3)
	var shadow_tint: Color = Color(0.22, 0.22, 0.28)
	for y: int in size.y:
		var v: float = float(y) / size.y
		for x: int in size.x:
			var i: int = y * size.x + x
			var hx: float = heights[y * size.x + posmod(x + 1, size.x)] - heights[y * size.x + posmod(x - 1, size.x)]
			var hy: float = heights[mini(y + 1, size.y - 1) * size.x + x] - heights[maxi(y - 1, 0) * size.x + x]
			var n: Vector3 = Vector3(-hx, -hy, 2.2).normalized()
			var lit: float = clampf(n.dot(L3) * 0.85 + 0.2, 0.0, 1.0)
			var col: Color = shadow_tint.lerp(tints[ids[i]], smoothstep(0.0, 0.8, lit))
			col = col.lerp(Color(0.88, 0.8, 0.64), pow(lit, 3.0) * 0.4)
			col = _shade(col, 0.9 + _n01(grain, x, y) * 0.2)
			# Đỉnh sáng (nắng chiếu mép trên), chân tối (AO).
			col = _shade(col, lerpf(1.08, 0.58, smoothstep(0.15, 1.0, v)))
			var m: float = smoothstep(0.64, 0.82, moss[i]) * (1.0 - v) * 1.1
			col = col.lerp(Color(0.28, 0.38, 0.15), clampf(m, 0, 0.75))
			col.a = 1.0
			c.set_c(x, y, col)
	# Dây leo rủ từ mép trên.
	for i: int in 26:
		var x0: float = rng.randf() * size.x
		var length: float = rng.randf_range(16, 70)
		var p: Vector2 = Vector2(x0, 0)
		var steps: int = int(length / 2.0)
		for s: int in steps:
			p += Vector2(rng.randf_range(-0.7, 0.7), 2.0)
			var leaf: Color = Color(0.2, 0.36, 0.14).lerp(Color(0.42, 0.56, 0.2), rng.randf())
			c.dab(p.x, p.y, rng.randf_range(1.0, 2.2), leaf, 0.9, 0.5)
	c.save(path)


## Mép cỏ trên vách 512×48 (= 256×24 world): 12 texel trên mép (phủ lên mặt trên), phần dưới rủ xuống mặt vách.
func _cliff_lip(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(512, 48)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color(0, 0, 0, 0), true)
	var n: FastNoiseLite = _noise(seed_value, 0.03, 3)
	var grass_dark: Color = Color(0.16, 0.3, 0.12)
	var grass_mid: Color = Color(0.3, 0.46, 0.17)
	for x: int in size.x:
		# Lặp liền mạch: dùng noise theo góc trên vòng tròn.
		var ang: float = TAU * x / size.x
		var nv: float = _n01(n, cos(ang) * 80.0, sin(ang) * 80.0)
		var top: float = 6.0 + nv * 4.0
		var bottom: float = 20.0 + nv * 12.0
		for y: int in size.y:
			if y < top or y > bottom:
				continue
			var t: float = (y - top) / maxf(1.0, bottom - top)
			var a: float = smoothstep(0.0, 0.25, t)
			c.blend(x, y, grass_mid.lerp(grass_dark, t), a)
		# Bóng AO dưới mép cỏ (trên mặt vách).
		for y: int in range(int(bottom), mini(size.y, int(bottom) + 10)):
			c.blend(x, y, Color(0.05, 0.05, 0.08), 0.45 * (1.0 - (y - bottom) / 10.0))
	# Ngọn cỏ rủ xuống và ngọn hướng lên ở mép trên.
	for i: int in 2200:
		var x: float = rng.randf() * size.x
		var y: float = rng.randf_range(10, 28)
		if c.get_alpha(int(x), int(y)) < 0.5:
			continue
		var down: bool = rng.randf() < 0.65
		var length: float = rng.randf_range(3, 10)
		var ang: float = (PI / 2 if down else -PI / 2) + rng.randf_range(-0.5, 0.5)
		var tip: Vector2 = Vector2(x, y) + Vector2.from_angle(ang) * length
		var col: Color = grass_mid.lerp(Color(0.6, 0.7, 0.28), rng.randf() * (0.3 if down else 0.8))
		c.stroke(x, y, tip.x, tip.y, 0.9, 0.4, col, _shade(col, 0.85 if down else 1.15), 0.85, 0.5)
	c.save(path)


## Chân vách 512×48: đá vụn + cỏ, nửa trên nằm trên mặt vách, nửa dưới trên mặt đất.
func _cliff_base(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(512, 48)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color(0, 0, 0, 0), true)
	for i: int in 260:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf_range(20, 40))
		var r: float = rng.randf_range(2.5, 7.5)
		var stone: Color = Color(0.5, 0.46, 0.4).lerp(Color(0.38, 0.36, 0.34), rng.randf())
		c.ellipse(p.x + r * 0.4, p.y + r * 0.45, r * 1.15, r * 0.7, 0, Color(0.06, 0.06, 0.06), 0.4, 0.2)
		c.ellipse(p.x, p.y, r, r * 0.75, rng.randf_range(-0.3, 0.3), stone, 1.0, 0.7)
		c.ellipse(p.x - r * 0.3, p.y - r * 0.32, r * 0.5, r * 0.32, 0, _shade(stone, 1.35), 0.7, 0.3)
	for i: int in 1600:
		var x: float = rng.randf() * size.x
		var y: float = rng.randf_range(26, 44)
		var tip: Vector2 = Vector2(x, y) + Vector2.from_angle(-PI / 2 + rng.randf_range(-0.6, 0.6)) * rng.randf_range(4, 14)
		var col: Color = Color(0.22, 0.36, 0.13).lerp(Color(0.5, 0.6, 0.24), rng.randf())
		c.stroke(x, y, tip.x, tip.y, 1.0, 0.4, _shade(col, 0.75), col, 0.85, 0.5)
	c.save(path)


# ---------------------------------------------------------------- trees & plants

func _trees() -> void:
	var dir: String = _dir("props")
	_oak(dir + "tree_oak_a.png", Vector2i(360, 440), 51, 15, 0.0)
	_oak(dir + "tree_oak_b.png", Vector2i(320, 400), 52, 12, 0.08)
	_pine(dir + "tree_pine.png", Vector2i(220, 460), 53)


func _leaf_palette(shift: float) -> Array[Color]:
	return [
		Color(0.05, 0.13, 0.1),
		Color(0.11, 0.25, 0.13),
		Color(0.22, 0.4 + shift * 0.3, 0.15),
		Color(0.42 + shift, 0.57, 0.2),
		Color(0.72, 0.8, 0.38),
	]


func _trunk(c: Painter, rng: RandomNumberGenerator, base: Vector2, top: Vector2, w_base: float, w_top: float) -> void:
	var bark_dark: Color = Color(0.17, 0.11, 0.08)
	var bark_light: Color = Color(0.52, 0.4, 0.29)
	var grain: FastNoiseLite = _noise(rng.randi(), 0.05, 3)
	var bend: float = rng.randf_range(-10, 10)
	# Rễ.
	for i: int in 6:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var root_dir: Vector2 = Vector2(side * rng.randf_range(0.7, 1.0), rng.randf_range(0.05, 0.25)).normalized()
		var start: Vector2 = base + Vector2(side * w_base * 0.25, -6)
		var end: Vector2 = start + root_dir * rng.randf_range(w_base * 0.7, w_base * 1.3)
		c.stroke(start.x, start.y, end.x, end.y, w_base * 0.32, 1.5, _shade(bark_light, 0.6), bark_dark, 1.0, 0.7)
	for y: int in range(int(top.y), int(base.y) + 1):
		var t: float = inverse_lerp(top.y, base.y, y)
		var cx: float = lerpf(top.x, base.x, t) + sin(t * PI) * bend
		var hw: float = lerpf(w_top, w_base, t) * 0.5 + pow(maxf(0.0, t - 0.8) / 0.2, 2.0) * w_base * 0.3
		for x: int in range(floori(cx - hw) - 1, ceili(cx + hw) + 2):
			var u: float = (x + 0.5 - cx) / hw
			if absf(u) > 1.0:
				continue
			var lit: float = clampf(0.55 - u * 0.55 + 0.1 * (1.0 - t), 0.0, 1.0)
			var col: Color = bark_dark.lerp(bark_light, lit)
			var streak: float = _n01(grain, x * 0.6, y * 0.08)
			col = _shade(col, 0.75 + streak * 0.5)
			c.blend(x, y, col, clampf((1.0 - absf(u)) * hw, 0.0, 1.0))


func _oak(path: String, size: Vector2i, seed_value: int, clump_count: int, shift: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var base: Vector2 = Vector2(size.x * 0.5, size.y - 12)
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.4)
	var rx: float = size.x * 0.46
	var ry: float = size.y * 0.36
	_trunk(c, rng, base, Vector2(size.x * 0.5 + rng.randf_range(-6, 6), center.y + ry * 0.3), 48, 22)
	# Cành chính.
	for i: int in 5:
		var start: Vector2 = Vector2(base.x + rng.randf_range(-4, 4), lerpf(base.y, center.y, rng.randf_range(0.55, 0.8)))
		var end: Vector2 = center + Vector2(rng.randf_range(-rx * 0.7, rx * 0.7), rng.randf_range(-ry * 0.3, ry * 0.4))
		c.stroke(start.x, start.y, end.x, end.y, 6.0, 2.0, Color(0.3, 0.21, 0.15), Color(0.2, 0.14, 0.1), 1.0, 0.7)
	_canopy(c, rng, center, rx, ry, clump_count, _leaf_palette(shift), 1.0)
	c.save(path)


## Tán lá: nhiều cụm (clump) vẽ từ sau ra trước; mỗi cụm gồm nền tối + hàng trăm nét lá đổ bóng theo hướng sáng.
func _canopy(c: Painter, rng: RandomNumberGenerator, center: Vector2, rx: float, ry: float, clump_count: int, palette: Array[Color], leaf_scale: float) -> void:
	var clumps: Array[Vector3] = []
	var guard: int = 0
	while clumps.size() < clump_count and guard < 2000:
		guard += 1
		var p: Vector2 = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if p.length() > 1.0:
			continue
		var r: float = rng.randf_range(0.3, 0.46) * rx
		var pos: Vector2 = center + Vector2(p.x * (rx - r * 0.75), p.y * (ry - r * 0.7))
		clumps.append(Vector3(pos.x, pos.y, r))
	clumps.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for clump: Vector3 in clumps:
		var cc: Vector2 = Vector2(clump.x, clump.y)
		var cr: float = clump.z
		for i: int in 14:
			var q: Vector2 = cc + Vector2.from_angle(rng.randf() * TAU) * cr * rng.randf_range(0.0, 0.55)
			c.dab(q.x, q.y, cr * rng.randf_range(0.3, 0.45), palette[1], 0.95, 0.85)
		var count: int = int(cr * cr * 0.2)
		for i: int in count:
			var d: float = pow(rng.randf(), 0.6) * cr * 0.98
			var q: Vector2 = cc + Vector2.from_angle(rng.randf() * TAU) * d
			var local: float = ((q - cc) / cr).dot(L2)
			var global: float = Vector2((q.x - center.x) / rx, (q.y - center.y) / ry).dot(L2)
			var depth: float = d / cr
			var v: float = 0.42 + local * 0.28 * depth + global * 0.22 + rng.randf_range(-0.1, 0.1) - (q.y - center.y) / ry * 0.08
			var leaf_r: float = rng.randf_range(2.8, 5.4) * leaf_scale
			c.ellipse(q.x, q.y, leaf_r, leaf_r * 0.62, rng.randf() * TAU, _ramp(palette, clampf(v, 0.0, 0.86)), 0.95, 0.55)
		for i: int in int(count * 0.06):
			var q: Vector2 = cc + Vector2.from_angle(rng.randf_range(-2.6, -1.0)) * cr * rng.randf_range(0.35, 0.95)
			c.ellipse(q.x, q.y, 2.2 * leaf_scale, 1.4 * leaf_scale, rng.randf() * TAU, palette[4], 0.75, 0.5)


func _pine(path: String, size: Vector2i, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var base: Vector2 = Vector2(size.x * 0.5, size.y - 10)
	_trunk(c, rng, base, Vector2(size.x * 0.5, size.y * 0.3), 26, 8)
	var palette: Array[Color] = [Color(0.04, 0.11, 0.1), Color(0.08, 0.2, 0.15), Color(0.15, 0.33, 0.2), Color(0.3, 0.47, 0.26), Color(0.55, 0.68, 0.38)]
	var tiers: int = 14
	var top_y: float = 10.0
	var bottom_y: float = size.y * 0.8
	for t: int in tiers:
		var f: float = float(t) / (tiers - 1)
		var ty: float = lerpf(top_y, bottom_y, f)
		var half: float = lerpf(12, size.x * 0.47, pow(f, 0.8)) * rng.randf_range(0.9, 1.05)
		var drop: float = lerpf(30, 60, f)
		var count: int = int(half * drop * 1.0)
		# Khối tối làm nền cho tầng lá (tránh nét kim rời rạc trông như vệt mưa).
		for i: int in int(half * 0.5):
			var u0: float = rng.randf_range(-0.85, 0.85)
			var q0: Vector2 = Vector2(base.x + u0 * half * 0.8, ty + drop * (0.35 + 0.3 * absf(u0)) - (1.0 - absf(u0)) * 4.0)
			c.dab(q0.x, q0.y, drop * 0.32 * (1.0 - absf(u0) * 0.4), palette[1], 0.95, 0.6)
		for i: int in count:
			var u: float = rng.randf_range(-1, 1)
			var along: float = rng.randf()
			var q: Vector2 = Vector2(base.x + u * half * (0.35 + along * 0.65), ty + along * drop * (0.55 + 0.45 * absf(u)) - (1.0 - absf(u)) * 6.0)
			var lit: float = -u * 0.35 + (1.0 - along) * 0.25 + rng.randf_range(-0.12, 0.12)
			var v: float = 0.4 + lit - f * 0.08
			var ang: float = PI / 2 + u * 0.9 + rng.randf_range(-0.3, 0.3)
			var tip: Vector2 = q + Vector2.from_angle(ang) * rng.randf_range(3, 7)
			c.stroke(q.x, q.y, tip.x, tip.y, 1.5, 0.6, _ramp(palette, clampf(v, 0.0, 0.95)), _ramp(palette, clampf(v - 0.15, 0.0, 0.95)), 0.95, 0.5)
	c.save(path)


func _plants() -> void:
	var dir: String = _dir("props")
	_bush(dir + "bush_a.png", Vector2i(180, 130), 61, false)
	_bush(dir + "bush_b.png", Vector2i(150, 112), 62, true)
	_fern(dir + "fern.png", Vector2i(120, 90), 63)


func _bush(path: String, size: Vector2i, seed_value: int, flowers: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.56)
	_canopy(c, rng, center, size.x * 0.45, size.y * 0.38, 7, _leaf_palette(0.05), 0.8)
	# AO ở chân bụi.
	for y: int in range(int(size.y * 0.75), size.y):
		for x: int in size.x:
			if c.get_alpha(x, y) > 0.0:
				c.multiply(x, y, lerpf(1.0, 0.55, inverse_lerp(size.y * 0.75, size.y, y)))
	if flowers:
		for i: int in 70:
			var q: Vector2 = center + Vector2(rng.randf_range(-1, 1) * size.x * 0.38, rng.randf_range(-1, 0.6) * size.y * 0.32)
			if c.get_alpha(int(q.x), int(q.y)) < 0.9:
				continue
			var petal: Color = Color(0.95, 0.72, 0.8) if rng.randf() < 0.6 else Color(0.98, 0.95, 0.85)
			c.dab(q.x + 0.6, q.y + 0.8, 2.2, Color(0.1, 0.1, 0.1), 0.35, 0.3)
			c.dab(q.x, q.y, 1.9, petal, 1.0, 0.6)
			c.dab(q.x - 0.5, q.y - 0.5, 0.8, Color(1, 0.95, 0.6), 0.9, 0.5)
	c.save(path)


func _fern(path: String, size: Vector2i, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var base: Vector2 = Vector2(size.x * 0.5, size.y - 6)
	for i: int in 11:
		var ang: float = -PI / 2 + lerpf(-1.25, 1.25, float(i) / 10.0) + rng.randf_range(-0.1, 0.1)
		var length: float = rng.randf_range(38, 54)
		var p: Vector2 = base
		var dir: Vector2 = Vector2.from_angle(ang)
		for s: int in 22:
			var t: float = float(s) / 21.0
			dir = dir.rotated(0.045 * signf(cos(ang)))
			p += dir * length / 22.0
			var leaflet: float = (1.0 - t) * 7.0 + 1.5
			var col: Color = Color(0.16, 0.34, 0.14).lerp(Color(0.48, 0.62, 0.24), t * 0.7 + (0.25 if cos(ang) < 0 else 0.0))
			for side: float in [-1.0, 1.0]:
				var tip: Vector2 = p + dir.rotated(side * 1.1) * leaflet
				c.stroke(p.x, p.y, tip.x, tip.y, 1.2, 0.5, _shade(col, 0.8), col, 0.95, 0.5)
	c.save(path)


# ---------------------------------------------------------------- rocks

func _rocks() -> void:
	var dir: String = _dir("props")
	_rock(dir + "rock_large.png", Vector2i(220, 160), 71, 0.55)
	_rock(dir + "rock_small.png", Vector2i(110, 80), 72, 0.4)
	_rock(dir + "rock_flat.png", Vector2i(170, 90), 73, 0.7)


## Đá: heightfield dạng vòm + facet Voronoi, đổ bóng Lambert theo nguồn sáng trên-trái, rêu ở mặt hướng lên.
func _rock(path: String, size: Vector2i, seed_value: int, moss_amount: float) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var outline: FastNoiseLite = _noise(seed_value, 1.4, 2)
	var facet: Dictionary = _voronoi(size, Vector2(size.x * 0.4, size.y * 0.45), rng, false)
	var d1s: PackedFloat32Array = facet["d1"]
	var d2s: PackedFloat32Array = facet["d2"]
	var ids: PackedInt32Array = facet["id"]
	var tilt: Array[Vector2] = []
	for i: int in (facet["points"] as PackedVector2Array).size():
		tilt.append(Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)))
	var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.55)
	var rx: float = size.x * 0.46
	var ry: float = size.y * 0.42
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(size.x * size.y)
	var grain_h: FastNoiseLite = _noise(seed_value + 7, 0.05, 4)
	for y: int in size.y:
		for x: int in size.x:
			var d: Vector2 = Vector2((x - center.x) / rx, (y - center.y) / ry)
			var ang: float = d.angle()
			var edge: float = 1.0 + 0.16 * outline.get_noise_2d(cos(ang), sin(ang))
			# Đáy phẳng hơn (đá đặt trên mặt đất).
			if d.y > 0.0:
				d.y *= 1.25
			var r: float = d.length() / edge
			if r >= 1.0:
				continue
			var i: int = y * size.x + x
			var dome: float = sqrt(1.0 - r * r)
			var fe: float = d2s[i] - d1s[i]
			heights[i] = dome * 30.0 + (tilt[ids[i]].dot(Vector2(x, y) - center) * 0.08) + minf(fe, 10.0) * 0.5 + grain_h.get_noise_2d(x, y) * 3.5
			c.set_c(x, y, Color(1, 1, 1, clampf((1.0 - r) * 40.0, 0.0, 1.0)))
	var base_col: Color = Color(0.55, 0.52, 0.46)
	var shadow_col: Color = Color(0.2, 0.22, 0.28)
	var grain: FastNoiseLite = _noise(seed_value + 2, 0.12, 3)
	for y: int in size.y:
		for x: int in size.x:
			var i: int = y * size.x + x
			var a: float = c.get_alpha(x, y)
			if a <= 0.0:
				continue
			var hx: float = _h(heights, size, x + 1, y) - _h(heights, size, x - 1, y)
			var hy: float = _h(heights, size, x, y + 1) - _h(heights, size, x, y - 1)
			var n: Vector3 = Vector3(-hx, -hy, 2.0).normalized()
			var lit: float = clampf(n.dot(L3), 0.0, 1.0)
			var col: Color = shadow_col.lerp(base_col, smoothstep(0.05, 0.75, lit))
			col = col.lerp(Color(0.9, 0.84, 0.7), pow(lit, 4.0) * 0.5)
			col = _shade(col, 0.85 + _n01(grain, x, y) * 0.3)
			# AO ở phần chân.
			col = _shade(col, lerpf(1.0, 0.55, smoothstep(0.65, 1.0, float(y) / size.y)))
			col.a = a
			c.set_c(x, y, col)
	_moss(c, seed_value + 3, moss_amount, 0.8)
	_cracks(c, rng, 6, 24, Color(0.14, 0.13, 0.12))
	c.save(path)


func _h(heights: PackedFloat32Array, size: Vector2i, x: int, y: int) -> float:
	x = clampi(x, 0, size.x - 1)
	y = clampi(y, 0, size.y - 1)
	return heights[y * size.x + x]


# ---------------------------------------------------------------- ruins

func _ruins() -> void:
	var dir: String = _dir("props")
	_pillar(dir + "ruin_pillar.png", Vector2i(84, 270), 81, false)
	_pillar(dir + "ruin_pillar_broken.png", Vector2i(84, 180), 82, true)
	_arch(dir + "ruin_arch.png", Vector2i(320, 300), 83)
	_wall(dir + "ruin_wall.png", Vector2i(260, 150), 84)
	_blocks(dir + "ruin_blocks.png", Vector2i(180, 100), 85)
	_rune_stone(dir + "rune_stone.png", Vector2i(96, 170), 86)


const STONE: Color = Color(0.64, 0.61, 0.55)


## Shade một dải hình trụ dọc: u ∈ [-1, 1] ngang thân.
func _cylinder_shade(u: float) -> float:
	var nz: float = sqrt(maxf(0.0, 1.0 - u * u))
	var n: Vector3 = Vector3(u, 0.0, nz)
	return clampf(n.dot(Vector3(L3.x, 0.0, L3.z).normalized()) * 0.75 + 0.35, 0.2, 1.15)


func _pillar(path: String, size: Vector2i, seed_value: int, broken: bool) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.1, 3)
	var top_n: FastNoiseLite = _noise(seed_value + 1, 0.12, 2)
	var cx: float = size.x * 0.5
	var shaft_hw: float = size.x * 0.3
	var plinth_h: float = 22.0
	var cap_h: float = 0.0 if broken else 26.0
	var bottom: float = size.y - 4.0
	var shaft_top: float = 14.0 + cap_h
	for y: int in size.y:
		for x: int in size.x:
			var hw: float = shaft_hw
			var region: int = 0
			if y > bottom - plinth_h:
				hw = size.x * 0.46
				region = 1
			elif not broken and y < shaft_top:
				hw = size.x * 0.46 if y > 14.0 + cap_h * 0.4 else size.x * 0.42
				region = 2
			var top_limit: float = 14.0
			if broken:
				top_limit = 14.0 + _n01(top_n, x, 0) * 40.0
			if y < top_limit or y > bottom:
				continue
			var u: float = (x + 0.5 - cx) / hw
			if absf(u) > 1.0:
				continue
			var lit: float = _cylinder_shade(u) if region == 0 else (1.05 - u * 0.35)
			var col: Color = _shade(STONE, lit)
			if region == 0:
				# Rãnh dọc (fluting).
				col = _shade(col, 0.88 + 0.12 * cos(u * PI * 3.5))
				# Mạch nối giữa các khối trụ.
				var joint: float = fposmod(y - shaft_top, 52.0)
				if joint < 1.6:
					col = _shade(col, 0.55)
				elif joint < 3.0:
					col = _shade(col, 1.1)
			col = _shade(col, 0.85 + _n01(grain, x, y) * 0.3)
			col = _shade(col, lerpf(1.0, 0.7, smoothstep(bottom - plinth_h - 30, bottom, y)))
			col.a = clampf((1.0 - absf(u)) * hw * 1.2, 0.0, 1.0)
			c.set_c(x, y, col)
	if broken:
		# Mặt cắt gãy (nhìn từ trên): elip sáng ở đỉnh.
		for i: int in 30:
			var q: Vector2 = Vector2(cx + rng.randf_range(-shaft_hw * 0.7, shaft_hw * 0.7), 20.0 + rng.randf_range(0, 22))
			if c.get_alpha(int(q.x), int(q.y)) > 0.5 and c.get_alpha(int(q.x), int(q.y) - 3) < 0.5:
				c.ellipse(q.x, q.y + 2, 5, 2.5, 0, _shade(STONE, 1.3), 0.7, 0.4)
	_bevel(c, 2, 0.12, 0.25)
	_moss(c, seed_value + 2, 0.45, 0.7)
	_cracks(c, rng, 8, 40, Color(0.2, 0.19, 0.17))
	c.save(path)


func _arch(path: String, size: Vector2i, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.09, 3)
	var pier_w: float = 52.0
	var bottom: float = size.y - 4.0
	var spring: float = size.x * 0.5 + 2.0
	var center: Vector2 = Vector2(size.x * 0.5, spring)
	var r_in: float = size.x * 0.5 - pier_w
	var r_out: float = size.x * 0.5 - 4.0
	for y: int in size.y:
		for x: int in size.x:
			var inside: bool = false
			var shade: float = 1.0
			var joint: bool = false
			# Trụ vuông hai bên.
			if y >= spring and y <= bottom and (x < pier_w + 4 or x > size.x - pier_w - 4) and x > 4 and x < size.x - 4:
				inside = true
				var course: float = fposmod(bottom - y, 30.0)
				joint = course < 1.8
				var local_x: float = fposmod(x - 4, size.x - pier_w - 8)
				if fposmod(floorf((bottom - y) / 30.0), 2.0) == 1.0:
					joint = joint or absf(local_x - pier_w * 0.5) < 1.0
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if y < spring and d >= r_in and d <= r_out:
				var ang: float = rad_to_deg((Vector2(x, y) - center).angle())
				# Đoạn vòm bị vỡ phía phải.
				if ang > -62.0 and ang < -22.0:
					continue
				inside = true
				joint = fposmod(ang, 14.0) < 1.2 or absf(d - r_in) < 1.2
				if d < r_in + 8.0:
					shade = 0.7
			if not inside:
				continue
			var col: Color = _shade(STONE, shade * (0.85 + _n01(grain, x, y) * 0.3))
			if joint:
				col = _shade(col, 0.5)
			col = _shade(col, lerpf(1.0, 0.72, smoothstep(spring, bottom, y)))
			c.set_c(x, y, col)
	_bevel(c, 2, 0.16, 0.3)
	_moss(c, seed_value + 1, 0.55, 0.7)
	_cracks(c, rng, 14, 40, Color(0.2, 0.19, 0.17))
	# Dây leo rủ từ vòm.
	for i: int in 9:
		var p: Vector2 = center + Vector2.from_angle(deg_to_rad(rng.randf_range(-170, -90))) * rng.randf_range(r_in, r_out)
		for s: int in rng.randi_range(14, 40):
			p += Vector2(rng.randf_range(-0.6, 0.6), 1.6)
			c.dab(p.x, p.y, rng.randf_range(1.2, 2.4), Color(0.2, 0.36, 0.14).lerp(Color(0.45, 0.58, 0.22), rng.randf()), 0.95, 0.5)
	c.save(path)


func _wall(path: String, size: Vector2i, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.09, 3)
	var top_n: FastNoiseLite = _noise(seed_value + 1, 0.011, 3)
	var course_h: float = 22.0
	var brick_w: float = 44.0
	var top_face: float = 16.0
	var bottom: float = size.y - 4.0
	var tints: Dictionary = {}
	for y: int in size.y:
		for x: int in range(4, size.x - 4):
			var top_limit: float = 6.0 + _n01(top_n, x, 0) * 70.0 + (x * 0.15)
			if y < top_limit or y > bottom:
				continue
			var row: int = floori((bottom - y) / course_h)
			var off: float = brick_w * 0.5 if row % 2 == 1 else 0.0
			var col_i: int = floori((x + off) / brick_w)
			var key: int = row * 100 + col_i
			if not tints.has(key):
				tints[key] = rng.randf_range(0.82, 1.12)
				if rng.randf() < 0.06:
					tints[key] = -1.0
			var t: float = tints[key]
			if t < 0.0 and y > top_limit + 20:
				c.set_c(x, y, Color(0.12, 0.11, 0.1, 1))
				continue
			var col: Color = _shade(STONE, absf(t) * (0.85 + _n01(grain, x, y) * 0.3))
			var in_course: float = fposmod(bottom - y, course_h)
			var in_brick: float = fposmod(x + off, brick_w)
			if in_course < 1.8 or in_brick < 1.6:
				col = _shade(col, 0.5)
			# Mặt trên của tường (nhìn từ trên) sáng hơn.
			if y < top_limit + top_face * 0.5:
				col = _shade(col, 1.2)
			col = _shade(col, lerpf(1.0, 0.7, smoothstep(size.y * 0.5, bottom, y)))
			c.set_c(x, y, col)
	_bevel(c, 2, 0.15, 0.3)
	_moss(c, seed_value + 2, 0.6, 0.8)
	_cracks(c, rng, 10, 30, Color(0.2, 0.19, 0.17))
	c.save(path)


func _blocks(path: String, size: Vector2i, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.1, 3)
	var blocks: Array[Rect2] = [Rect2(10, 40, 80, 52), Rect2(80, 50, 70, 44), Rect2(40, 14, 62, 40), Rect2(130, 66, 40, 28)]
	for b: Rect2 in blocks:
		var top_h: float = b.size.y * 0.38
		var t: float = rng.randf_range(0.85, 1.1)
		for y: int in range(int(b.position.y), int(b.end.y)):
			for x: int in range(int(b.position.x), int(b.end.x)):
				var col: Color = _shade(STONE, t * (0.85 + _n01(grain, x, y) * 0.3))
				col = _shade(col, 1.22 if y < b.position.y + top_h else 0.78)
				c.set_c(x, y, col)
	_bevel(c, 2, 0.15, 0.3)
	_moss(c, seed_value + 1, 0.55, 0.8)
	_cracks(c, rng, 6, 20, Color(0.2, 0.19, 0.17))
	c.save(path)


func _rune_stone(path: String, size: Vector2i, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.1, 3)
	var edge_n: FastNoiseLite = _noise(seed_value + 1, 0.08, 2)
	var cx: float = size.x * 0.5
	var bottom: float = size.y - 4.0
	for y: int in size.y:
		var t: float = float(y) / size.y
		var hw: float = lerpf(size.x * 0.28, size.x * 0.44, t) + _n01(edge_n, 0, y) * 5.0
		var top: float = 10.0 + absf(0.0) * 0.0
		for x: int in size.x:
			var u: float = (x + 0.5 - cx) / hw
			if absf(u) > 1.0 or y > bottom:
				continue
			# Đỉnh bo tròn.
			var round_top: float = top + (1.0 - sqrt(maxf(0.0, 1.0 - u * u))) * 22.0
			if y < round_top:
				continue
			var col: Color = _shade(Color(0.5, 0.52, 0.53), (1.05 - u * 0.45) * (0.85 + _n01(grain, x, y) * 0.3))
			col = _shade(col, lerpf(1.05, 0.65, smoothstep(0.6, 1.0, t)))
			col.a = clampf((1.0 - absf(u)) * hw, 0.0, 1.0)
			c.set_c(x, y, col)
	_bevel(c, 2, 0.15, 0.3)
	_moss(c, seed_value + 2, 0.4, 0.6)
	# Rune phát sáng.
	var glow: Color = Color(0.45, 0.95, 1.0)
	var y0: float = 44.0
	for g: int in 5:
		var gy: float = y0 + g * 20.0
		var p: Vector2 = Vector2(cx + rng.randf_range(-8, 8), gy)
		for s: int in 3:
			var q: Vector2 = p + Vector2(rng.randf_range(-9, 9), rng.randf_range(-7, 7))
			c.stroke(p.x, p.y, q.x, q.y, 3.6, 3.6, glow, glow, 0.25, 0.1)
			c.stroke(p.x, p.y, q.x, q.y, 1.3, 1.3, Color(0.85, 1.0, 1.0), glow, 1.0, 0.7)
			p = q
	c.save(path)


# ---------------------------------------------------------------- structures (bridge, stairs, footbridge)

func _structures() -> void:
	var dir: String = _dir("structures")
	_stone_bridge(dir + "stone_bridge.png", 91)
	_stairs(dir + "cliff_stairs.png", 92)
	_footbridge(dir + "footbridge.png", 93)


## Cầu đá tầng cao: 320×240 texel (= 160×120 world). 112 texel trên là mặt cầu, 128 texel dưới là mặt trước có vòm.
func _stone_bridge(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(320, 240)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.09, 3)
	var deck_h: float = 112.0
	var arch_center: Vector2 = Vector2(size.x * 0.5, size.y + 6.0)
	var arch_r: float = 104.0
	for y: int in size.y:
		for x: int in size.x:
			var col: Color
			if y < deck_h:
				# Mặt cầu: đá lát, lan can thấp ở hai mép.
				var row: int = floori(y / 18.0)
				var off: float = 13.0 if row % 2 == 1 else 0.0
				var joint: bool = fposmod(y, 18.0) < 1.4 or fposmod(x + off, 26.0) < 1.4
				col = _shade(Color(0.66, 0.62, 0.55), 0.9 + _n01(grain, x, y) * 0.25)
				if joint:
					col = _shade(col, 0.6)
				if y < 14:
					col = _shade(STONE, 1.1 if y < 8 else 0.8)
				elif y > deck_h - 18:
					col = _shade(STONE, 1.2 if y < deck_h - 11 else 0.95)
			else:
				var d: float = Vector2(x + 0.5, y + 0.5).distance_to(arch_center)
				if d < arch_r:
					continue
				var course: float = fposmod(y - deck_h, 22.0)
				var off2: float = 20.0 if floori((y - deck_h) / 22.0) % 2 == 1 else 0.0
				var joint2: bool = course < 1.6 or fposmod(x + off2, 40.0) < 1.6
				col = _shade(STONE, 0.78 * (0.85 + _n01(grain, x, y) * 0.3))
				if d < arch_r + 14.0:
					var ang: float = rad_to_deg((Vector2(x, y) - arch_center).angle())
					joint2 = fposmod(ang, 10.0) < 1.0 or d < arch_r + 1.5
					col = _shade(col, 0.95)
				if joint2:
					col = _shade(col, 0.55)
				col = _shade(col, lerpf(1.0, 0.65, smoothstep(deck_h, size.y, y)))
			col.a = 1.0
			c.set_c(x, y, col)
	_bevel(c, 2, 0.12, 0.25)
	_moss(c, seed_value + 1, 0.45, 0.7)
	for i: int in 10:
		var p: Vector2 = Vector2(rng.randf() * size.x, deck_h + 2)
		for s: int in rng.randi_range(10, 50):
			p += Vector2(rng.randf_range(-0.6, 0.6), 1.7)
			if c.get_alpha(int(p.x), int(p.y)) < 0.5:
				break
			c.dab(p.x, p.y, rng.randf_range(1.2, 2.4), Color(0.2, 0.36, 0.14).lerp(Color(0.45, 0.58, 0.22), rng.randf()), 0.95, 0.5)
	c.save(path)


## Cầu thang đá xẻ vào vách: 128×200 texel (= 64×100 world). Đỉnh hòa vào mặt trên, chân đặt trên mặt đất.
func _stairs(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(128, 200)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.1, 3)
	var cheek: float = 16.0
	var steps: int = 8
	var top: float = 24.0
	var bottom: float = size.y - 8.0
	var step_h: float = (bottom - top) / steps
	for y: int in size.y:
		for x: int in size.x:
			var col: Color
			var a: float = 1.0
			if x < cheek or x >= size.x - cheek:
				var block: bool = fposmod(y, 26.0) < 1.6
				col = _shade(STONE, (1.0 if x < cheek else 0.72) * (0.85 + _n01(grain, x, y) * 0.3))
				if block:
					col = _shade(col, 0.55)
			else:
				if y < top:
					a = smoothstep(0.0, top, y)
					col = _shade(Color(0.62, 0.58, 0.5), 0.95)
				else:
					var s: float = fposmod(y - top, step_h)
					var tread: bool = s < step_h * 0.55
					col = _shade(Color(0.66, 0.62, 0.55), (1.15 if tread else 0.66) * (0.85 + _n01(grain, x, y) * 0.3))
					if s < 1.5:
						col = _shade(col, 1.25)
					col = _shade(col, lerpf(1.0, 0.82, float(y) / size.y))
			col.a = a
			c.set_c(x, y, col)
	_bevel(c, 2, 0.1, 0.2)
	_moss(c, seed_value + 1, 0.4, 0.5)
	c.save(path)


## Cầu gỗ thấp qua suối: 128×256 texel (= 64×128 world), ván ngang, dầm dọc hai bên.
func _footbridge(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(128, 256)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.04, 3)
	var plank_h: float = 15.0
	var beam: float = 12.0
	var plank_tints: PackedFloat32Array = PackedFloat32Array()
	for i: int in 40:
		plank_tints.append(rng.randf_range(0.8, 1.15))
	var wood: Color = Color(0.52, 0.38, 0.25)
	for y: int in size.y:
		for x: int in size.x:
			var col: Color
			if x < beam or x >= size.x - beam:
				var u: float = (x - (beam * 0.5 if x < beam else size.x - beam * 0.5)) / (beam * 0.5)
				col = _shade(Color(0.36, 0.26, 0.17), 1.0 - u * 0.35)
				col = _shade(col, 0.85 + _n01(grain, x * 0.3, y * 2.0) * 0.3)
			else:
				var pi: int = floori(y / plank_h)
				var s: float = fposmod(y, plank_h)
				col = _shade(wood, plank_tints[pi % plank_tints.size()])
				col = _shade(col, 0.82 + _n01(grain, x * 2.5 + pi * 50.0, y * 0.25) * 0.35)
				if s < 1.8:
					col = Color(0.1, 0.07, 0.05)
				elif s < 3.0:
					col = _shade(col, 1.18)
				elif s > plank_h - 2.5:
					col = _shade(col, 0.7)
				if absf(x - beam - 6) < 1.5 and absf(s - plank_h * 0.5) < 1.5 or absf(x - (size.x - beam - 6)) < 1.5 and absf(s - plank_h * 0.5) < 1.5:
					col = Color(0.2, 0.2, 0.22)
			col.a = 1.0
			c.set_c(x, y, col)
	c.save(path)


# ---------------------------------------------------------------- decals

func _decals() -> void:
	var dir: String = _dir("decals")
	_atlas_tufts(dir + "grass_tufts.png", 101)
	_atlas_flowers(dir + "flowers.png", 102)
	_atlas_pebbles(dir + "pebbles.png", 103)
	_atlas_leaves(dir + "leaf_litter.png", 104)
	_patch(dir + "moss_patch.png", 105, Color(0.24, 0.4, 0.14), Color(0.42, 0.55, 0.2), 0.85)
	_patch(dir + "dirt_patch.png", 106, Color(0.4, 0.3, 0.2), Color(0.55, 0.43, 0.29), 0.8)
	_soft_blob(dir + "shadow_soft.png", Vector2i(256, 128), Color(0.02, 0.03, 0.05), 1.0)
	_soft_blob(dir + "light_patch.png", Vector2i(256, 256), Color(1.0, 0.92, 0.7), 1.0)
	_canopy_shadow(dir + "canopy_shadow.png", 107)


## Atlas 4 ô 64×64, mỗi ô có lề trong suốt 4 texel (atlas padding chống bleeding khi lọc tuyến tính/mipmap).
func _atlas_cell(c: Painter, cell: int) -> Vector2:
	return Vector2(cell * 64 + 32, 32)


func _atlas_tufts(path: String, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(256, 64)
	for cell: int in 4:
		var base: Vector2 = Vector2(cell * 64 + 32, 56)
		var blades: int = 26 + cell * 6
		for i: int in blades:
			var ang: float = -PI / 2 + rng.randf_range(-0.9, 0.9)
			var length: float = rng.randf_range(12, 26 + cell * 3)
			var start: Vector2 = base + Vector2(rng.randf_range(-12, 12), rng.randf_range(-2, 2))
			var tip: Vector2 = start + Vector2.from_angle(ang) * length
			tip.x = clampf(tip.x, cell * 64 + 5, cell * 64 + 59)
			tip.y = maxf(tip.y, 5)
			var col: Color = Color(0.24, 0.4, 0.15).lerp(Color(0.56, 0.66, 0.26), rng.randf() * (1.0 if tip.x < base.x else 0.6))
			if cell == 3:
				col = col.lerp(Color(0.62, 0.6, 0.3), 0.4)
			c.stroke(start.x, start.y, tip.x, tip.y, 1.6, 0.5, _shade(col, 0.65), col, 0.95, 0.5)
	c.save(path)


func _atlas_flowers(path: String, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(256, 64)
	var colors: Array[Color] = [Color(0.98, 0.96, 0.86), Color(0.98, 0.82, 0.3), Color(0.92, 0.55, 0.72), Color(0.55, 0.65, 0.98)]
	for cell: int in 4:
		var base: Vector2 = Vector2(cell * 64 + 32, 54)
		for i: int in 9:
			var head: Vector2 = base + Vector2(rng.randf_range(-20, 20), rng.randf_range(-36, -10))
			var stem_start: Vector2 = Vector2(head.x + rng.randf_range(-3, 3), base.y)
			c.stroke(stem_start.x, stem_start.y, head.x, head.y, 0.9, 0.6, Color(0.2, 0.34, 0.14), Color(0.32, 0.48, 0.18), 0.9, 0.5)
			for leaf: int in 2:
				var lp: Vector2 = stem_start.lerp(head, rng.randf_range(0.2, 0.6))
				c.ellipse(lp.x + 3, lp.y, 3.5, 1.4, rng.randf_range(-0.6, 0.6), Color(0.28, 0.45, 0.17), 0.9, 0.5)
		for i: int in 9:
			var head: Vector2 = base + Vector2(rng.randf_range(-20, 20), rng.randf_range(-36, -10))
			var col: Color = colors[cell]
			for p: int in 5:
				var off: Vector2 = Vector2.from_angle(p * TAU / 5 + rng.randf()) * 2.6
				c.dab(head.x + off.x, head.y + off.y, 2.2, _jitter(rng, col, 0.08), 1.0, 0.6)
			c.dab(head.x, head.y, 1.4, Color(0.95, 0.8, 0.25) if cell != 1 else Color(0.6, 0.35, 0.1), 1.0, 0.6)
	c.save(path)


func _atlas_pebbles(path: String, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(256, 64)
	for cell: int in 4:
		for i: int in 4 + cell * 2:
			var p: Vector2 = Vector2(cell * 64 + 32 + rng.randf_range(-18, 18), 36 + rng.randf_range(-14, 14))
			var r: float = rng.randf_range(3, 8)
			var stone: Color = Color(0.58, 0.55, 0.49).lerp(Color(0.42, 0.4, 0.38), rng.randf())
			c.ellipse(p.x + r * 0.4, p.y + r * 0.45, r * 1.15, r * 0.7, 0, Color(0.05, 0.05, 0.05), 0.45, 0.2)
			c.ellipse(p.x, p.y, r, r * 0.72, rng.randf_range(-0.4, 0.4), stone, 1.0, 0.7)
			c.ellipse(p.x - r * 0.32, p.y - r * 0.3, r * 0.45, r * 0.3, 0, _shade(stone, 1.4), 0.75, 0.3)
	c.save(path)


func _atlas_leaves(path: String, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(256, 64)
	var colors: Array[Color] = [Color(0.72, 0.45, 0.18), Color(0.6, 0.3, 0.14), Color(0.78, 0.62, 0.25), Color(0.45, 0.4, 0.2)]
	for cell: int in 4:
		for i: int in 12:
			var p: Vector2 = Vector2(cell * 64 + 32 + rng.randf_range(-20, 20), 32 + rng.randf_range(-18, 18))
			var ang: float = rng.randf() * TAU
			var col: Color = _jitter(rng, colors[(cell + i) % 4], 0.15)
			c.ellipse(p.x + 1, p.y + 1.2, 4.2, 2.0, ang, Color(0.05, 0.04, 0.02), 0.35, 0.3)
			c.ellipse(p.x, p.y, 4.0, 1.8, ang, col, 1.0, 0.6)
	c.save(path)


## Mảng nền mềm (rêu/đất) 256×192 với mép răng cưa tự nhiên, alpha mờ dần.
func _patch(path: String, seed_value: int, dark: Color, light: Color, alpha: float) -> void:
	var size: Vector2i = Vector2i(256, 192)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var shape: FastNoiseLite = _noise(seed_value, 0.025, 4)
	var detail: FastNoiseLite = _noise(seed_value + 1, 0.12, 2)
	var center: Vector2 = Vector2(size) * 0.5
	for y: int in size.y:
		for x: int in size.x:
			var d: float = Vector2((x - center.x) / (size.x * 0.5), (y - center.y) / (size.y * 0.5)).length()
			var m: float = (1.0 - d) * 1.6 + shape.get_noise_2d(x, y) * 0.9
			var a: float = smoothstep(0.1, 0.6, m) * alpha
			a *= 1.0 - smoothstep(0.75, 1.0, d)
			if a <= 0.0:
				continue
			var col: Color = dark.lerp(light, _n01(detail, x, y))
			col.a = a
			c.set_c(x, y, col)
	c.save(path)


func _soft_blob(path: String, size: Vector2i, col: Color, alpha: float) -> void:
	var c: Painter = Painter.new(size.x, size.y)
	var center: Vector2 = Vector2(size) * 0.5
	for y: int in size.y:
		for x: int in size.x:
			var d: float = Vector2((x + 0.5 - center.x) / center.x, (y + 0.5 - center.y) / center.y).length()
			var a: float = pow(clampf(1.0 - d, 0.0, 1.0), 1.6) * alpha
			c.set_c(x, y, Color(col.r, col.g, col.b, a))
	c.save(path)


## Bóng tán cây lốm đốm 512×384: bóng tối + đốm nắng xuyên lá.
func _canopy_shadow(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(512, 384)
	var c: Painter = Painter.new(size.x, size.y)
	var shape: FastNoiseLite = _noise(seed_value, 0.012, 4)
	var dapple: FastNoiseLite = _noise(seed_value + 1, 0.045, 2)
	var center: Vector2 = Vector2(size) * 0.5
	for y: int in size.y:
		for x: int in size.x:
			var d: float = Vector2((x - center.x) / center.x, (y - center.y) / center.y).length()
			var m: float = (1.0 - d) * 1.5 + shape.get_noise_2d(x, y) * 0.7
			var a: float = smoothstep(0.05, 0.6, m)
			a *= 1.0 - smoothstep(0.75, 1.0, d)
			a *= lerpf(1.0, 0.25, smoothstep(0.62, 0.78, _n01(dapple, x, y)))
			c.set_c(x, y, Color(0.03, 0.06, 0.08, a))
	c.save(path)


# ---------------------------------------------------------------- fx

func _fx() -> void:
	var dir: String = _dir("fx")
	var size: Vector2i = Vector2i(256, 256)
	var noise: PackedFloat32Array = _seamless(111, size, 0.02, 4)
	var c: Painter = Painter.new(size.x, size.y)
	for y: int in size.y:
		for x: int in size.x:
			var v: float = noise[y * size.x + x]
			c.set_c(x, y, Color(v, v, v, 1))
	c.save(dir + "water_noise.png")
	# Tia nắng: dải dọc mềm, mờ dần về hai đầu.
	var shaft: Painter = Painter.new(128, 512)
	for y: int in 512:
		for x: int in 128:
			var u: float = absf((x + 0.5) / 64.0 - 1.0)
			var v: float = float(y) / 512.0
			var a: float = pow(1.0 - u, 2.0) * smoothstep(0.0, 0.25, v) * (1.0 - smoothstep(0.6, 1.0, v))
			shaft.set_c(x, y, Color(1.0, 0.95, 0.8, a))
	shaft.save(dir + "light_shaft.png")
	# Sương: mảng noise mềm.
	var mist: Painter = Painter.new(512, 256)
	var mn: FastNoiseLite = _noise(112, 0.01, 4)
	for y: int in 256:
		for x: int in 512:
			var d: float = Vector2((x - 256.0) / 256.0, (y - 128.0) / 128.0).length()
			var a: float = smoothstep(0.0, 0.8, (1.0 - d) * 1.3 + mn.get_noise_2d(x, y) * 0.6) * 0.8
			a *= 1.0 - smoothstep(0.7, 1.0, d)
			mist.set_c(x, y, Color(0.92, 0.95, 1.0, a))
	mist.save(dir + "mist.png")
	_soft_blob(dir + "mote.png", Vector2i(16, 16), Color(1.0, 0.97, 0.8), 1.0)
	_soft_blob(dir + "glow.png", Vector2i(256, 256), Color(1, 1, 1), 1.0)


# ---------------------------------------------------------------- scenery

func _scenery() -> void:
	var dir: String = _dir("scenery")
	_valley(dir + "valley_far.png", 121)
	_foreground_leaves(dir + "foreground_leaves.png", 122)


## Thung lũng xa nhìn từ mép vực: 1024×512, lặp theo x. Trên = xa (mờ xanh), dưới = gần chân vực (tối, nhiều sương).
func _valley(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(1024, 512)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color.BLACK, true)
	var far: Color = Color(0.66, 0.76, 0.8)
	var near: Color = Color(0.17, 0.28, 0.24)
	for y: int in size.y:
		var t: float = float(y) / size.y
		for x: int in size.x:
			c.set_c(x, y, far.lerp(near, smoothstep(0.0, 1.0, t)))
	# Dãy núi xa.
	var ridge: FastNoiseLite = _noise(seed_value, 0.004, 4)
	for x: int in size.x:
		var ang: float = TAU * x / size.x
		var hgt: float = 70.0 + _n01(ridge, cos(ang) * 120.0, sin(ang) * 120.0) * 80.0
		for y: int in range(int(hgt), int(hgt) + 120):
			if y >= size.y:
				break
			var k: float = float(y - hgt) / 120.0
			c.blend(x, y, Color(0.48, 0.58, 0.66).lerp(Color(0.4, 0.5, 0.52), k), 0.85 * (1.0 - k * 0.5))
		c.blend(x, int(hgt), Color(0.85, 0.88, 0.9), 0.5)
	# Lớp ngọn cây: xa → gần, kích thước và độ tương phản tăng dần.
	for layer: int in 6:
		var t: float = float(layer) / 5.0
		var y_band: float = lerpf(170.0, 470.0, t)
		var count: int = int(lerpf(2400, 900, t))
		var r_max: float = lerpf(4.0, 16.0, t)
		var haze: Color = far.lerp(near, lerpf(0.35, 1.0, t))
		for i: int in count:
			var p: Vector2 = Vector2(rng.randf() * size.x, minf(y_band + rng.randf_range(-40, 40), size.y - 18.0))
			var r: float = rng.randf_range(r_max * 0.5, r_max)
			var tree_col: Color = Color(0.12, 0.25, 0.16).lerp(Color(0.3, 0.45, 0.22), rng.randf() * 0.6)
			var col: Color = tree_col.lerp(haze, lerpf(0.75, 0.15, t))
			c.dab(p.x + r * 0.3, p.y + r * 0.3, r, _shade(col, 0.7), 0.9, 0.5)
			c.dab(p.x, p.y, r * 0.85, col, 0.95, 0.5)
			c.dab(p.x - r * 0.3, p.y - r * 0.35, r * 0.45, _shade(col, 1.12), 0.35, 0.2)
	# Sương theo dải.
	var mn: FastNoiseLite = _noise(seed_value + 1, 0.006, 3)
	for y: int in size.y:
		for x: int in size.x:
			var ang: float = TAU * x / size.x
			var band: float = sin(y * 0.03) * 0.5 + 0.5
			var m: float = _n01(mn, cos(ang) * 160.0, sin(ang) * 160.0 + y * 0.8) * band
			c.blend(x, y, Color(0.85, 0.9, 0.95), smoothstep(0.45, 0.9, m) * 0.45)
	c.save(path)


func _foreground_leaves(path: String, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(512, 384)
	var palette: Array[Color] = [Color(0.02, 0.05, 0.04), Color(0.04, 0.09, 0.06), Color(0.07, 0.14, 0.08), Color(0.12, 0.2, 0.1), Color(0.2, 0.28, 0.14)]
	_canopy(c, rng, Vector2(256, 230), 240, 150, 10, palette, 2.6)
	c.save(path)


# ---------------------------------------------------------------- logic tiles

## Atlas 32×32 cho lớp Terrain Logic (chỉ dùng khi bật debug). Thứ tự: grass, dirt, water, cliff, high, void.
func _logic_tiles() -> void:
	var dir: String = _dir("terrain")
	var colors: Array[Color] = [Color(0.3, 0.8, 0.3), Color(0.85, 0.6, 0.3), Color(0.25, 0.55, 1.0), Color(1.0, 0.3, 0.3), Color(0.7, 0.4, 1.0), Color(0.1, 0.1, 0.1)]
	var c: Painter = Painter.new(32 * colors.size(), 32)
	for i: int in colors.size():
		for y: int in 32:
			for x: int in 32:
				var border: bool = x == 0 or y == 0 or x == 31 or y == 31
				var col: Color = colors[i]
				col.a = 0.9 if border else 0.45
				c.set_c(i * 32 + x, y, col)
	c.save(dir + "terrain_logic_tiles.png")
