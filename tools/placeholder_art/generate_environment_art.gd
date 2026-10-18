extends SceneTree
## Sinh placeholder art cho Environment Prototype (TASK VISUAL 01) bằng code — không dùng asset bên ngoài.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/placeholder_art/generate_environment_art.gd
## Sau khi sinh lại: mở Editor (hoặc chạy --headless --import) để Godot import lại PNG.
##
## Quy ước (xem docs/visual/environment-style-guide.md) — isometric dimetric 2:1 từ VISUAL-02:
## - Mật độ texel = 2 texel / 1 đơn vị world (sprite dùng scale 0.5). Tile thoi 64×32, tầng 64 px; texture nền vẽ top-down.
## - Ánh sáng chính từ trên-trái màn hình; bóng đổ về dưới-phải.
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
		# Vẽ top-down (nhìn thẳng xuống mặt đất): nét đa hướng; shader chiếu lên mặt phẳng iso.
		var ang: float = rng.randf() * TAU
		var tip: Vector2 = p + Vector2.from_angle(ang) * length
		var light: float = rng.randf_range(0.8, 1.3)
		var tip_col: Color = _shade(base, light).lerp(Color(0.62, 0.7, 0.28), 0.18 * light)
		c.stroke(p.x, p.y, tip.x, tip.y, rng.randf_range(0.8, 1.1), 0.45, _shade(base, 0.8), tip_col, 0.75, 0.5)
	# Điểm sáng (cỏ đón nắng) tập trung ở vùng macro sáng.
	for i: int in 2600:
		var p: Vector2 = Vector2(rng.randf() * size.x, rng.randf() * size.y)
		if macro[int(p.y) * size.x + int(p.x)] < rng.randf_range(0.3, 0.8):
			continue
		var tip: Vector2 = p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(3, 6)
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


## Đá lát vuông 8×8 viên / 512 texel (1 viên ≈ 1 tile lưới). Shader chiếu lên mặt phẳng iso → viên đá thành hình thoi.
func _stone_floor(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(512, 512)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color.BLACK, true)
	var cell: float = 64.0
	var grain: FastNoiseLite = _noise(seed_value, 0.08, 3)
	var moss_n: PackedFloat32Array = _seamless(seed_value + 5, size, 0.02, 3)
	var tints: PackedColorArray = PackedColorArray()
	for i: int in 64:
		tints.append(Color(0.6, 0.57, 0.5).lerp(Color(0.5, 0.5, 0.48), rng.randf()) * rng.randf_range(0.85, 1.1))
	for y: int in size.y:
		for x: int in size.x:
			var cx: int = int(x / cell)
			var cy: int = int(y / cell)
			var lx: float = fposmod(x, cell)
			var ly: float = fposmod(y, cell)
			var edge: float = minf(minf(lx, cell - lx), minf(ly, cell - ly))
			var col: Color = tints[(cy * 8 + cx) % 64]
			col.a = 1.0
			col = _shade(col, 0.9 + _n01(grain, x, y) * 0.2)
			# Bevel: cạnh trên-trái sáng, dưới-phải tối.
			var near: float = 1.0 - smoothstep(2.0, 8.0, edge)
			var lit: float = 1.0 if (lx < cell - lx and lx <= ly) or (ly < cell - ly and ly < lx) else -1.0
			col = _shade(col, 1.0 + near * 0.22 * lit)
			var m: float = moss_n[y * size.x + x]
			if edge < 2.4:
				col = Color(0.2, 0.19, 0.15).lerp(Color(0.26, 0.34, 0.14), smoothstep(0.45, 0.7, m))
			elif edge < 7.0 and m > 0.6:
				col = col.lerp(Color(0.32, 0.42, 0.16), (m - 0.6) * 1.8 * (1.0 - edge / 7.0))
			c.set_c(x, y, col)
	_cracks(c, rng, 40, 26, Color(0.18, 0.17, 0.14))
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


# ---------------------------------------------------------------- isometric painting

## Toạ độ texel (mật độ 2) của điểm lưới (i, j) và độ cao z (px world) so với gốc o: x = (i − j)·64, y = (i + j)·32 − 2z.
func _iso(i: float, j: float, z: float = 0.0) -> Vector2:
	return Vector2((i - j) * 64.0, (i + j) * 32.0 - z * 2.0)


## Tô hình bình hành p0 + u·du + v·dv (u, v ∈ [0,1]); pattern(u, v) trả về màu (alpha 0 = bỏ qua).
func _iso_quad(c: Painter, p0: Vector2, du: Vector2, dv: Vector2, pattern: Callable) -> void:
	var det: float = du.x * dv.y - du.y * dv.x
	if absf(det) < 0.0001:
		return
	var pts: Array[Vector2] = [p0, p0 + du, p0 + dv, p0 + du + dv]
	var lo: Vector2 = pts[0]
	var hi: Vector2 = pts[0]
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y: int in range(floori(lo.y), ceili(hi.y) + 1):
		for x: int in range(floori(lo.x), ceili(hi.x) + 1):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - p0
			var u: float = (d.x * dv.y - d.y * dv.x) / det
			var v: float = (du.x * d.y - du.y * d.x) / det
			if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
				continue
			var col: Color = pattern.call(u, v)
			if col.a > 0.0:
				c.blend(x, y, col, col.a)


## Hộp isometric: gốc o = đỉnh trên của footprint (z = 0); a tile theo i, b tile theo j, cao h px.
## Vẽ 3 mặt nhìn thấy: SE (i = a, tối nhất), SW (j = b, sáng vừa — hướng về nguồn sáng trên-trái), mặt trên (sáng nhất).
## pattern(face, u_px, v_px) → màu nền của mặt; face: 0 = trên, 1 = SW, 2 = SE; u, v tính theo px world dọc mặt.
func _iso_box(c: Painter, o: Vector2, a: float, b: float, h: float, pattern: Callable) -> void:
	var len_a: float = a * 35.78
	var len_b: float = b * 35.78
	_iso_quad(c, o + _iso(a, 0, h), _iso(0, b) , Vector2(0, h * 2.0), func(u: float, v: float) -> Color:
		return _shade(pattern.call(2, u * len_b, v * h), 0.66))
	_iso_quad(c, o + _iso(0, b, h), _iso(a, 0), Vector2(0, h * 2.0), func(u: float, v: float) -> Color:
		return _shade(pattern.call(1, u * len_a, v * h), 0.95))
	_iso_quad(c, o + _iso(0, 0, h), _iso(a, 0), _iso(0, b), func(u: float, v: float) -> Color:
		return _shade(pattern.call(0, u * len_a, v * len_b), 1.15))


## Mẫu khối đá xây: mạch ngang mỗi `course` px, mạch đứng so le mỗi `block` px; mặt trên là đá lát.
func _masonry(grain: FastNoiseLite, course: float, block: float, base: Color) -> Callable:
	return func(face: int, u: float, v: float) -> Color:
		var col: Color = _shade(base, 0.86 + _n01(grain, u * 2.0 + face * 97.0, v * 2.0) * 0.28)
		if face == 0:
			if fposmod(u, block) < 0.8 or fposmod(v, block) < 0.8:
				col = _shade(col, 0.62)
			return col
		var row: float = floorf(v / course)
		var off: float = block * 0.5 if fposmod(row, 2.0) == 1.0 else 0.0
		if fposmod(v, course) < 0.9 or fposmod(u + off, block) < 0.9:
			col = _shade(col, 0.55)
		elif fposmod(v, course) < 1.8:
			col = _shade(col, 1.08)
		return col


# ---------------------------------------------------------------- ruins (isometric)

func _ruins() -> void:
	var dir: String = _dir("props")
	_pillar(dir + "ruin_pillar.png", 81, false)
	_pillar(dir + "ruin_pillar_broken.png", 82, true)
	_arch(dir + "ruin_arch.png", 83)
	_wall(dir + "ruin_wall.png", 84)
	_blocks(dir + "ruin_blocks.png", 85)
	_rune_stone(dir + "rune_stone.png", 86)


const STONE: Color = Color(0.64, 0.61, 0.55)


## Shade một dải hình trụ dọc: u ∈ [-1, 1] ngang thân.
func _cylinder_shade(u: float) -> float:
	var nz: float = sqrt(maxf(0.0, 1.0 - u * u))
	var n: Vector3 = Vector3(u, 0.0, nz)
	return clampf(n.dot(Vector3(L3.x, 0.0, L3.z).normalized()) * 0.75 + 0.35, 0.2, 1.15)


## Cột tròn trên bệ vuông isometric. Ảnh 112×300 texel; gốc (điểm chạm đất) = đỉnh dưới của footprint bệ ở giữa đáy ảnh.
func _pillar(path: String, seed_value: int, broken: bool) -> void:
	var size: Vector2i = Vector2i(112, 300 if not broken else 210)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.1, 3)
	var top_n: FastNoiseLite = _noise(seed_value + 1, 0.12, 2)
	var s: float = 0.78
	var bottom: Vector2 = Vector2(size.x * 0.5, size.y - 3.0)
	var o: Vector2 = bottom - _iso(s, s)
	_iso_box(c, o, s, s, 10.0, _masonry(grain, 100.0, 100.0, STONE))
	# Thân trụ: tâm footprint, bán kính 22 texel; mép dưới/trên là cung ellipse 2:1.
	var center: Vector2 = o + _iso(s * 0.5, s * 0.5)
	var r: float = 22.0
	var shaft_bottom: float = center.y - 20.0
	var shaft_top: float = 62.0 if not broken else 40.0
	for y: int in size.y:
		for x: int in size.x:
			var u: float = (x + 0.5 - center.x) / r
			if absf(u) > 1.0:
				continue
			var arc: float = sqrt(1.0 - u * u) * r * 0.5
			var top_limit: float = shaft_top + arc
			if broken:
				top_limit = shaft_top + _n01(top_n, x, 0) * 34.0 + arc
			if y < top_limit - arc * 2.0 or y > shaft_bottom + arc:
				continue
			var col: Color = _shade(STONE, _cylinder_shade(u))
			col = _shade(col, 0.88 + 0.12 * cos(u * PI * 3.5))
			var joint: float = fposmod(shaft_bottom - y, 52.0)
			if joint < 1.6:
				col = _shade(col, 0.6)
			col = _shade(col, 0.85 + _n01(grain, x, y) * 0.3)
			# Mặt cắt trên (ellipse) sáng hơn.
			if y < top_limit:
				col = _shade(STONE, 1.22 * (0.9 + _n01(grain, x * 2.0, y * 2.0) * 0.2))
			c.blend(x, y, col, clampf((1.0 - absf(u)) * r, 0.0, 1.0))
	if not broken:
		# Đầu cột: hộp vuông đặt đúng trên mặt cắt trên của thân (tâm footprint trùng tâm ellipse đỉnh thân).
		var cap_o: Vector2 = Vector2(center.x, shaft_top) - _iso(s * 0.5, s * 0.5)
		_iso_box(c, cap_o, s, s, 14.0, _masonry(grain, 100.0, 100.0, STONE))
	_moss(c, seed_value + 2, 0.45, 0.7)
	_cracks(c, rng, 8, 40, Color(0.2, 0.19, 0.17))
	c.save(path)


## Vòm đá cổ trên hai trụ vuông, mặt vòm nằm trong mặt phẳng SW (chạy theo trục i).
## Ảnh 300×300 texel; gốc = điểm giữa cạnh trước (SW) của chân hai trụ.
func _arch(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(300, 330)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.09, 3)
	var span: float = 3.0
	var pier: float = 0.62
	var depth: float = 0.62
	var pier_h: float = 66.0
	# Gốc o: đỉnh trên footprint (i = 0, j = 0); đặt sao cho toàn bộ nằm trong ảnh.
	var o: Vector2 = Vector2(size.x * 0.5, size.y - 4.0) - _iso(span * 0.5, depth) - Vector2(0, 0)
	o -= Vector2(0, 0)
	var mason: Callable = _masonry(grain, 15.0, 22.0, STONE)
	# Vòng vòm: tâm giữa nhịp, trong mặt phẳng (i, z) — vẽ lớp sau (tối) rồi lớp trước.
	var r_in: float = (span * 0.5 - pier) * 35.78
	var r_out: float = r_in + 15.0
	for layer: int in 2:
		var jplane: float = 0.0 if layer == 0 else depth
		var shade: float = 0.58 if layer == 0 else 0.95
		var p0: Vector2 = o + _iso(0, jplane, pier_h + r_out)
		_iso_quad(c, p0, _iso(span, 0), Vector2(0, (r_out) * 2.0), func(u: float, v: float) -> Color:
			var sx: float = (u - 0.5) * span * 35.78
			var tz: float = (1.0 - v) * r_out
			var d: float = Vector2(sx, tz).length()
			if d < r_in or d > r_out:
				return Color(0, 0, 0, 0)
			var ang: float = rad_to_deg(atan2(tz, sx))
			if ang > 22.0 and ang < 58.0:
				return Color(0, 0, 0, 0)
			var col: Color = _shade(STONE, shade * (0.86 + _n01(grain, sx * 2.0, tz * 2.0) * 0.28))
			if fposmod(ang, 14.0) < 1.4 or absf(d - r_in) < 0.9:
				col = _shade(col, 0.55)
			return col)
	_iso_box(c, o, pier, depth, pier_h, mason)
	_iso_box(c, o + _iso(span - pier, 0), pier, depth, pier_h, mason)
	_moss(c, seed_value + 1, 0.55, 0.7)
	_cracks(c, rng, 14, 40, Color(0.2, 0.19, 0.17))
	for i: int in 8:
		var p: Vector2 = o + _iso(rng.randf_range(0.3, span - 0.3), depth, pier_h + rng.randf_range(4.0, r_out - 4.0))
		for k: int in rng.randi_range(12, 34):
			p += Vector2(rng.randf_range(-0.6, 0.6), 1.6)
			c.dab(p.x, p.y, rng.randf_range(1.2, 2.4), Color(0.2, 0.36, 0.14).lerp(Color(0.45, 0.58, 0.22), rng.randf()), 0.95, 0.5)
	c.save(path)


## Tường đổ dài theo trục i (2.4 × 0.4 tile), đỉnh gãy. Ảnh 220×200; gốc = giữa cạnh trước SW của chân tường.
func _wall(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(220, 200)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.09, 3)
	var top_n: FastNoiseLite = _noise(seed_value + 1, 0.9, 3)
	var a: float = 2.4
	var b: float = 0.4
	var hmax: float = 52.0
	var o: Vector2 = Vector2(size.x * 0.5, size.y - 4.0) - _iso(a * 0.5, b)
	var mason: Callable = _masonry(grain, 11.0, 20.0, STONE)
	# Mỗi cột theo i có chiều cao riêng (đỉnh gãy); vẽ từ sau ra trước theo i.
	var cols: int = 12
	for k: int in cols:
		var i0: float = a * k / cols
		var hk: float = hmax * (0.45 + 0.55 * _n01(top_n, k * 0.37, 0.0))
		_iso_box(c, o + _iso(i0, 0), a / cols + 0.002, b, hk, mason)
	_moss(c, seed_value + 2, 0.6, 0.8)
	_cracks(c, rng, 10, 30, Color(0.2, 0.19, 0.17))
	c.save(path)


func _blocks(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(200, 130)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.1, 3)
	var o: Vector2 = Vector2(size.x * 0.5, size.y - 4.0) - _iso(1.2, 0.9)
	var mason: Callable = _masonry(grain, 100.0, 100.0, STONE)
	_iso_box(c, o + _iso(0.1, 0.0), 0.8, 0.5, 18.0, mason)
	_iso_box(c, o + _iso(0.7, 0.35), 0.5, 0.45, 26.0, mason)
	_iso_box(c, o + _iso(0.0, 0.5), 0.6, 0.4, 14.0, mason)
	_iso_box(c, o + _iso(0.9, 0.0), 0.3, 0.3, 10.0, mason)
	_moss(c, seed_value + 1, 0.55, 0.8)
	_cracks(c, rng, 6, 20, Color(0.2, 0.19, 0.17))
	c.save(path)


## Đá rune: phiến đá đứng (0.55 × 0.3 tile, cao 82 px), rune phát sáng trên mặt SW.
func _rune_stone(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(110, 220)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.1, 3)
	var a: float = 0.55
	var b: float = 0.3
	var h: float = 82.0
	var o: Vector2 = Vector2(size.x * 0.5, size.y - 4.0) - _iso(a * 0.5, b)
	var base: Color = Color(0.5, 0.52, 0.53)
	_iso_box(c, o, a, b, h, func(face: int, u: float, v: float) -> Color:
		return _shade(base, 0.86 + _n01(grain, u * 2.0 + face * 91.0, v * 2.0) * 0.28))
	_moss(c, seed_value + 2, 0.4, 0.6)
	var glow: Color = Color(0.45, 0.95, 1.0)
	for g: int in 5:
		var p: Vector2 = o + _iso(a * 0.5, b, h - 14.0 - g * 13.0) + Vector2(rng.randf_range(-6, 6), 0)
		for s: int in 3:
			var q: Vector2 = p + Vector2(rng.randf_range(-8, 8), rng.randf_range(-6, 6))
			c.stroke(p.x, p.y, q.x, q.y, 3.6, 3.6, glow, glow, 0.25, 0.1)
			c.stroke(p.x, p.y, q.x, q.y, 1.3, 1.3, Color(0.85, 1.0, 1.0), glow, 1.0, 0.7)
			p = q
	c.save(path)


# ---------------------------------------------------------------- structures (isometric)

func _structures() -> void:
	var dir: String = _dir("structures")
	_stone_bridge(dir + "stone_bridge.png", 91)
	_stairs(dir + "cliff_stairs.png", 92)
	_footbridge(dir + "footbridge.png", 93)


## Lối đi tầng cao trên vòm: hộp dài theo trục i (4.6 × 1.5 tile, cao 64 px = 1 tầng), mặt SW có vòm cho lối đi tầng
## thấp chạy theo trục j xuyên qua. Gốc o = đỉnh trên của footprint; xem BRIDGE_* trong builder để khớp hình học.
func _stone_bridge(path: String, seed_value: int) -> void:
	var a: float = 4.6
	var b: float = 1.5
	var h: float = 64.0
	var size: Vector2i = Vector2i(int((a + b) * 64.0) + 8, int((a + b) * 32.0 + h * 2.0) + 8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.09, 3)
	var o: Vector2 = Vector2(b * 64.0 + 4.0, h * 2.0 + 4.0)
	var deck: Color = Color(0.66, 0.62, 0.55)
	# Tâm vòm cách đầu cầu 1.25 tile: khớp lối đi tầng thấp chạy dưới gầm (xem builder prototype).
	var arch_c: float = 1.25 * 35.78
	var arch_r: float = 34.0
	var pattern: Callable = func(face: int, u: float, v: float) -> Color:
		if face == 0:
			var col0: Color = _shade(deck, 0.88 + _n01(grain, u * 2.0, v * 2.0) * 0.24)
			if fposmod(u, 18.0) < 0.9 or fposmod(v, 13.0) < 0.9:
				col0 = _shade(col0, 0.62)
			if v < 3.0 or v > b * 35.78 - 3.0:
				col0 = _shade(STONE, 1.2)
			return col0
		if face == 1:
			# Vòm: nửa ellipse từ chân (v = h) — tz = khoảng cách từ chân lên.
			var tz: float = h - v
			var dx: float = u - arch_c
			if dx * dx / (arch_r * arch_r) + tz * tz / ((h - 12.0) * (h - 12.0)) < 1.0:
				return Color(0, 0, 0, 0)
		var col: Color = _shade(STONE, 0.86 + _n01(grain, u * 2.0 + face * 77.0, v * 2.0) * 0.28)
		var row: float = floorf(v / 11.0)
		var off: float = 10.0 if fposmod(row, 2.0) == 1.0 else 0.0
		if fposmod(v, 11.0) < 0.9 or fposmod(u + off, 20.0) < 0.9:
			col = _shade(col, 0.55)
		return _shade(col, lerpf(1.0, 0.72, v / h))
	_iso_box(c, o, a, b, h, pattern)
	_moss(c, seed_value + 1, 0.45, 0.7)
	for i: int in 10:
		var p: Vector2 = o + _iso(rng.randf_range(0.2, a - 0.2), b, h - 1.0)
		for s: int in rng.randi_range(10, 40):
			p += Vector2(rng.randf_range(-0.6, 0.6), 1.7)
			if c.get_alpha(int(p.x), int(p.y)) < 0.5:
				break
			c.dab(p.x, p.y, rng.randf_range(1.2, 2.4), Color(0.2, 0.36, 0.14).lerp(Color(0.45, 0.58, 0.22), rng.randf()), 0.95, 0.5)
	c.save(path)


## Cầu thang đá dựa vào mặt vách SW, đi lên theo hướng −j (lên-phải màn hình). Rộng 1.5 tile theo i, chạy 1.75 tile
## theo j, cao 64 px, 7 bậc. Gốc o = đỉnh trên của footprint (i = 0, j = 0 — mép chân vách).
func _stairs(path: String, seed_value: int) -> void:
	var w: float = 1.5
	var run: float = 1.75
	var h: float = 64.0
	var steps: int = 7
	var size: Vector2i = Vector2i(int((w + run) * 64.0) + 8, int((w + run) * 32.0 + h * 2.0) + 8)
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.1, 3)
	var o: Vector2 = Vector2(run * 64.0 + 4.0, h * 2.0 + 4.0)
	var tread: Color = Color(0.68, 0.64, 0.57)
	for k: int in range(steps - 1, -1, -1):
		var depth: float = run * float(steps - k) / steps
		var hk: float = h * float(k + 1) / steps
		_iso_box(c, o, w, depth, hk, func(face: int, u: float, v: float) -> Color:
			var col: Color = _shade(tread if face == 0 else STONE, 0.86 + _n01(grain, u * 2.0 + face * 53.0, v * 2.0 + k * 31.0) * 0.28)
			if face == 1 and v < 1.4:
				col = _shade(col, 1.25)
			if face == 0 and fposmod(u, 18.0) < 0.8:
				col = _shade(col, 0.7)
			return col)
	_moss(c, seed_value + 1, 0.4, 0.5)
	c.save(path)


## Cầu gỗ thấp bắc theo trục j: rộng 1.1 tile (i), dài 3.6 tile (j), dày 5 px. Gốc o = đỉnh trên của footprint.
func _footbridge(path: String, seed_value: int) -> void:
	var w: float = 1.1
	var length: float = 3.6
	var size: Vector2i = Vector2i(int((w + length) * 64.0) + 8, int((w + length) * 32.0 + 10.0 * 2.0) + 8)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y)
	var grain: FastNoiseLite = _noise(seed_value, 0.04, 3)
	var o: Vector2 = Vector2(length * 64.0 + 4.0, 10.0 * 2.0 + 4.0)
	var wood: Color = Color(0.52, 0.38, 0.25)
	var tints: PackedFloat32Array = PackedFloat32Array()
	for i: int in 40:
		tints.append(rng.randf_range(0.8, 1.15))
	var len_w: float = w * 35.78
	_iso_box(c, o, w, length, 5.0, func(face: int, u: float, v: float) -> Color:
		if face != 0:
			return _shade(Color(0.32, 0.23, 0.15), 0.9)
		# Mặt trên: ván ngang (song song trục i), dầm dọc hai mép.
		if u < 3.5 or u > len_w - 3.5:
			return _shade(Color(0.36, 0.26, 0.17), 0.85 + _n01(grain, u, v * 2.0) * 0.3)
		var plank: int = floori(v / 7.5)
		var s: float = fposmod(v, 7.5)
		var col: Color = _shade(wood, tints[plank % tints.size()] * (0.82 + _n01(grain, u * 2.5 + plank * 50.0, v * 0.3) * 0.35))
		if s < 0.9:
			col = Color(0.1, 0.07, 0.05)
		elif s > 6.6:
			col = _shade(col, 0.72)
		return col)
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
## Phông xa sau vực: 1024×768, lặp theo x. Trên: trời + hai lớp núi (lớp xa có lâu đài mờ); giữa: rừng thung lũng;
## dưới: tan vào màu sương vực (ABYSS_HAZE) để khớp nền lấp đầy quanh map.
const ABYSS_HAZE: Color = Color(0.6, 0.68, 0.72)


func _valley(path: String, seed_value: int) -> void:
	var size: Vector2i = Vector2i(1024, 768)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Painter = Painter.new(size.x, size.y, Color.BLACK, true)
	var sky_top: Color = Color(0.62, 0.74, 0.86)
	var sky_low: Color = Color(0.86, 0.88, 0.84)
	for y: int in size.y:
		var t: float = float(y) / size.y
		for x: int in size.x:
			c.set_c(x, y, sky_top.lerp(sky_low, smoothstep(0.0, 0.32, t)))
	var ridge_far: FastNoiseLite = _noise(seed_value, 0.004, 4)
	var ridge_near: FastNoiseLite = _noise(seed_value + 7, 0.006, 5)
	var castle_x: float = 640.0
	for x: int in size.x:
		var ang: float = TAU * x / size.x
		var far_h: float = 150.0 + _n01(ridge_far, cos(ang) * 120.0, sin(ang) * 120.0) * 90.0
		var near_h: float = 230.0 + _n01(ridge_near, cos(ang) * 90.0, sin(ang) * 90.0) * 80.0
		# Lâu đài trên đỉnh núi xa: tháp + chóp nhọn, cùng màu núi nhưng sáng hơn chút (mờ do khoảng cách).
		var dx: float = absf(x - castle_x)
		var castle_top: float = INF
		if dx < 46.0:
			castle_top = far_h - 34.0 - (12.0 if fposmod(x - castle_x + 46.0, 23.0) < 9.0 else 0.0)
			for tower: float in [-40.0, -8.0, 30.0]:
				var tdx: float = absf(x - castle_x - tower)
				if tdx < 7.0:
					castle_top = minf(castle_top, far_h - 62.0 - (16.0 - tdx * 2.3))
		for y: int in size.y:
			if y >= minf(far_h, castle_top):
				var k: float = clampf((y - far_h) / 160.0, 0.0, 1.0)
				var col: Color = Color(0.56, 0.64, 0.74).lerp(Color(0.5, 0.6, 0.64), k)
				if y < far_h:
					col = Color(0.66, 0.72, 0.8)
				c.set_c(x, y, col)
			if y >= near_h:
				var k2: float = clampf((y - near_h) / 120.0, 0.0, 1.0)
				c.set_c(x, y, Color(0.4, 0.5, 0.52).lerp(Color(0.32, 0.43, 0.4), k2))
		c.blend(x, int(far_h), Color(0.9, 0.92, 0.94), 0.45)
	# Rừng thung lũng: xa → gần.
	for layer: int in 6:
		var t: float = float(layer) / 5.0
		var y_band: float = lerpf(320.0, 560.0, t)
		var count: int = int(lerpf(2400, 900, t))
		var r_max: float = lerpf(4.0, 14.0, t)
		var haze: Color = Color(0.5, 0.6, 0.62).lerp(Color(0.2, 0.32, 0.26), t)
		for i: int in count:
			var p: Vector2 = Vector2(rng.randf() * size.x, y_band + rng.randf_range(-40, 40))
			var r: float = rng.randf_range(r_max * 0.5, r_max)
			var col: Color = Color(0.14, 0.27, 0.18).lerp(Color(0.3, 0.45, 0.22), rng.randf() * 0.6).lerp(haze, lerpf(0.7, 0.2, t))
			c.dab(p.x + r * 0.3, p.y + r * 0.3, r, _shade(col, 0.7), 0.9, 0.5)
			c.dab(p.x, p.y, r * 0.85, col, 0.95, 0.5)
			c.dab(p.x - r * 0.3, p.y - r * 0.35, r * 0.45, _shade(col, 1.12), 0.35, 0.2)
	# Đáy: tan vào sương vực.
	var mn: FastNoiseLite = _noise(seed_value + 1, 0.006, 3)
	for y: int in size.y:
		var fade: float = smoothstep(560.0, 720.0, y)
		for x: int in size.x:
			var ang: float = TAU * x / size.x
			var m: float = _n01(mn, cos(ang) * 160.0, sin(ang) * 160.0 + y * 0.8) * (sin(y * 0.03) * 0.5 + 0.5)
			c.blend(x, y, Color(0.85, 0.9, 0.95), smoothstep(0.45, 0.9, m) * 0.4)
			c.blend(x, y, ABYSS_HAZE, fade)
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
	# Atlas ô thoi 64×32 (khớp TileSet isometric). Thứ tự: grass, dirt, water, cliff, high, void.
	var c: Painter = Painter.new(64 * colors.size(), 32)
	for i: int in colors.size():
		for y: int in 32:
			for x: int in 64:
				var d: float = absf(x + 0.5 - 32.0) / 32.0 + absf(y + 0.5 - 16.0) / 16.0
				if d > 1.0:
					continue
				var col: Color = colors[i]
				col.a = 0.9 if d > 0.88 else 0.45
				c.set_c(i * 64 + x, y, col)
	c.save(dir + "terrain_logic_tiles.png")
