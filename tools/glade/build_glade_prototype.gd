extends SceneTree
## Dựng lại Environment Prototype isometric (khu Glade) từ dữ liệu bố cục bên dưới (VISUAL-02, commit từ VISUAL-02.1).
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/glade/build_glade_prototype.gd
## CẢNH BÁO: GHI ĐÈ world/environment_prototype/environment_prototype.tscn, 15 scene prop trong world/environment/props/,
## tileset logic và các material .tres — mọi chỉnh sửa tay trong Editor trên các file đó sẽ mất. Nên commit trước khi chạy.
## Toạ độ bố cục theo lưới (i, j) của IsoProjection; sau khi chạy, chạy lại tests/environment để kiểm tra.

const ENV: String = "res://world/environment/"
const ART: String = "res://world/environment/art/"
const PROTO: String = "res://world/environment_prototype/"
const N: int = 40
const H: float = 64.0
const ABYSS_H: float = 192.0
const HAZE: Color = Color(0.6, 0.68, 0.72)

var sroot: Node
var mat_ground: ShaderMaterial
var mat_ground_high: ShaderMaterial
var mat_stone: ShaderMaterial
var mat_dirt: ShaderMaterial
var tileset: TileSet

# ---------------- layout (toạ độ lưới i, j)
var LAND: PackedVector2Array = PackedVector2Array([
	Vector2(1, 0.8), Vector2(5, 0.4), Vector2(9, 1.0), Vector2(13, 0.5), Vector2(17, 0.9), Vector2(21, 0.4), Vector2(25, 1.1), Vector2(29, 0.6), Vector2(33, 1.0), Vector2(37, 0.5), Vector2(39.2, 0.9),
	Vector2(39.5, 4), Vector2(39.0, 8), Vector2(39.6, 12), Vector2(39.2, 16), Vector2(39.7, 20), Vector2(39.1, 24), Vector2(39.6, 26.2), Vector2(39.6, 28.2), Vector2(39.2, 32), Vector2(39.5, 36), Vector2(39.0, 39.3),
	Vector2(36, 39.6), Vector2(32, 39.1), Vector2(28, 39.6), Vector2(24, 39.2), Vector2(20, 39.7), Vector2(16, 39.1), Vector2(12, 39.5), Vector2(8, 39.0), Vector2(4, 39.6), Vector2(0.8, 39.2),
	Vector2(0.5, 36), Vector2(1.0, 32), Vector2(0.4, 28), Vector2(0.9, 24), Vector2(0.5, 20), Vector2(1.1, 16), Vector2(0.6, 12), Vector2(1.0, 8), Vector2(0.5, 4)])
var PLATEAU: PackedVector2Array = PackedVector2Array([Vector2(6.5, 4.5), Vector2(18.5, 4.5), Vector2(20, 5.5), Vector2(20, 15.5), Vector2(18.8, 17), Vector2(12.5, 17), Vector2(9, 17), Vector2(6.6, 16.6), Vector2(6, 13), Vector2(6, 6)])
var OUTCROP: PackedVector2Array = PackedVector2Array([Vector2(24.6, 6.5), Vector2(30, 5.5), Vector2(32, 7), Vector2(32.5, 11), Vector2(30.5, 13.5), Vector2(26, 13.5), Vector2(24.6, 12)])
var PLAZA: PackedVector2Array = PackedVector2Array([Vector2(8.5, 6), Vector2(15.5, 6), Vector2(15.5, 12.5), Vector2(8.5, 12.5)])
var PATH_MAIN: PackedVector2Array = PackedVector2Array([Vector2(29, 35.5), Vector2(27.5, 33.6), Vector2(25, 32), Vector2(21, 30), Vector2(18.6, 28.6), Vector2(17.5, 27.2), Vector2(17.5, 23.6), Vector2(16, 22), Vector2(13.5, 21), Vector2(11.3, 20.0), Vector2(10.75, 19.3)])
var PATH_BRANCH: PackedVector2Array = PackedVector2Array([Vector2(16, 22), Vector2(19, 21.4), Vector2(21.25, 19), Vector2(21.25, 14), Vector2(21.25, 9), Vector2(21.25, 4), Vector2(21.0, 1.8)])
var PATH_UPPER: PackedVector2Array = PackedVector2Array([Vector2(10.75, 16.6), Vector2(11.6, 15.0), Vector2(14.2, 13.6), Vector2(17.0, 12.0), Vector2(19.0, 10.6), Vector2(20.2, 10.35)])
var STREAM: PackedVector2Array = PackedVector2Array([Vector2(3, 24), Vector2(6, 24.5), Vector2(9.5, 23.6), Vector2(13, 24.2), Vector2(16.5, 25.2), Vector2(20, 25.8), Vector2(23.5, 25.3), Vector2(27, 26), Vector2(30.5, 27.2), Vector2(34, 27.5), Vector2(37, 27.2), Vector2(39.55, 27.2)])
const STAIRS_I: float = 10.0
const STAIRS_W: float = 1.5
const STAIRS_RUN: float = 1.75
const STAIRS_J: float = 17.0
const BRIDGE_I: float = 20.0
const BRIDGE_J: float = 9.6
const BRIDGE_A: float = 4.6
const BRIDGE_B: float = 1.5
const FOOT_I: float = 16.95
const FOOT_J: float = 23.6


func _init() -> void:
	_build_tileset()
	_build_props()
	_build_world()
	quit()


# ---------------------------------------------------------------- helpers

func iso(i: float, j: float, z: float = 0.0) -> Vector2:
	return Vector2((i - j) * 32.0, (i + j) * 16.0 - z)


func isopoly(grid: PackedVector2Array, z: float = 0.0) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for g: Vector2 in grid:
		out.append(iso(g.x, g.y, z))
	return out


## Điểm màn hình → toạ độ "mặt phẳng đất" (bỏ nén dọc) dùng cho Line2D trong node GroundPlane.
func groundpts(grid: PackedVector2Array, z: float = 0.0) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for g: Vector2 in grid:
		var s: Vector2 = iso(g.x, g.y, z)
		out.append(Vector2(s.x, s.y * 2.0))
	return out


func ellipse(center: Vector2, rx: float, sides: int = 12) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in sides:
		var a: float = TAU * k / sides
		out.append(center + Vector2(cos(a) * rx, sin(a) * rx * 0.5))
	return out


func tex(path: String) -> Texture2D:
	return load(ART + path) as Texture2D


func add(parent: Node, node: Node, name_: String = "") -> Node:
	if name_ != "":
		node.name = name_
	parent.add_child(node)
	node.owner = sroot
	return node


func node2d(parent: Node, name_: String, pos: Vector2 = Vector2.ZERO) -> Node2D:
	var n: Node2D = Node2D.new()
	n.position = pos
	return add(parent, n, name_) as Node2D


func save_scene(scene_root: Node, path: String) -> void:
	var packed: PackedScene = PackedScene.new()
	packed.pack(scene_root)
	print("saved ", path, " ", error_string(ResourceSaver.save(packed, path)))


func save_res(res: Resource, path: String) -> Resource:
	print("saved ", path, " ", error_string(ResourceSaver.save(res, path)))
	return load(path)


func instance(parent: Node, path: String, pos: Vector2, name_: String = "") -> Node:
	var inst: Node = (load(path) as PackedScene).instantiate()
	if name_ != "":
		inst.name = name_
	(inst as Node2D).position = pos
	parent.add_child(inst, true)
	inst.owner = sroot
	return inst


func script_node(base: Node, script_path: String) -> Node:
	base.set_script(load(script_path))
	return base


func gradient_strip(alpha_mid: float, color: Color) -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.5, Color(color.r, color.g, color.b, alpha_mid))
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.width = 4
	t.height = 64
	t.fill_to = Vector2(0, 1)
	return t


## Line2D nằm trên mặt phẳng đất: đặt trong node GroundPlane (scale y 0.5) — bề rộng đúng theo mặt đất iso.
func ground_line(parent: Node, name_: String, grid: PackedVector2Array, width_tiles: float, texture: Texture2D, material: Material, z: float = 0.0) -> Line2D:
	var plane: Node2D = parent.get_node_or_null("GroundPlane") as Node2D
	if plane == null:
		plane = node2d(parent, "GroundPlane")
		plane.scale = Vector2(1, 0.5)
	var l: Line2D = Line2D.new()
	l.points = groundpts(grid, z)
	l.width = width_tiles * 45.25
	l.texture = texture
	l.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	l.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	l.material = material
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	return add(plane, l, name_) as Line2D


func _scatter(parent: Node, name_: String, texture_path: String, columns: int, count: int, seed_v: int, scale_range: Vector2, avoid_lines: Array, avoid_nodes: Array, inside: Array, along: Line2D = null, edge_offset: Vector2 = Vector2.ZERO, flat: bool = false, area: Rect2 = Rect2(-1300, -40, 2600, 1340)) -> Node2D:
	var s: Node2D = Node2D.new()
	s.set_script(load(ENV + "terrain/decal_scatter.gd"))
	s.name = name_
	parent.add_child(s)
	s.owner = sroot
	s.set("texture", tex(texture_path))
	s.set("atlas_columns", columns)
	s.set("count", count)
	s.set("seed_value", seed_v)
	s.set("area", area)
	s.set("scale_range", scale_range)
	s.set("flat_on_ground", flat)
	var lines: Array[Line2D] = []
	for l: Variant in avoid_lines:
		lines.append(l)
	s.set("avoid_lines", lines)
	var nodes: Array[Node2D] = []
	for n: Variant in avoid_nodes:
		nodes.append(n)
	s.set("avoid_nodes", nodes)
	var ins: Array[Node2D] = []
	for n: Variant in inside:
		ins.append(n)
	s.set("inside_nodes", ins)
	if along != null:
		s.set("along_line", along)
		s.set("edge_offset", edge_offset)
	return s


func ground_material(path: String, albedo: String, tiles: float, anti_tiling: float, tint_a: Color, tint_b: Color) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(ENV + "terrain/terrain_ground.gdshader")
	m.set_shader_parameter("albedo", tex(albedo))
	m.set_shader_parameter("macro_noise", tex("fx/water_noise.png"))
	m.set_shader_parameter("tiles_per_texture", tiles)
	m.set_shader_parameter("anti_tiling", anti_tiling)
	m.set_shader_parameter("tint_a", tint_a)
	m.set_shader_parameter("tint_b", tint_b)
	return save_res(m, ENV + "terrain/" + path) as ShaderMaterial


func path_material(file: String, albedo: String, tint: Color, edge_start: float, rim: float, extra: Dictionary = {}) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(ENV + "terrain/terrain_path.gdshader")
	m.set_shader_parameter("albedo", tex(albedo))
	m.set_shader_parameter("edge_noise", tex("fx/water_noise.png"))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("edge_start", edge_start)
	m.set_shader_parameter("rim_darken", rim)
	for key: String in extra:
		m.set_shader_parameter(key, extra[key])
	return save_res(m, ENV + "terrain/" + file) as ShaderMaterial


func ambient(node: Node2D, amplitude: Vector2, period: float, alpha_range: Vector2) -> void:
	node.set_script(load(ENV + "atmosphere/ambient_drift.gd"))
	node.set("amplitude", amplitude)
	node.set("period", period)
	node.set("alpha_range", alpha_range)


func mist(pos: Vector2, scl: Vector2, alpha: float, tint: Color = Color.WHITE) -> Sprite2D:
	var m: Sprite2D = Sprite2D.new()
	m.texture = tex("fx/mist.png")
	m.position = pos
	m.scale = scl
	m.modulate = Color(tint, alpha)
	ambient(m, Vector2(30, 5), 24.0 + absf(pos.x) * 0.004, Vector2(alpha * 0.6, alpha))
	return m


# ---------------------------------------------------------------- tileset (isometric)

func _build_tileset() -> void:
	tileset = TileSet.new()
	tileset.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tileset.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tileset.tile_size = Vector2i(64, 32)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "terrain")
	tileset.set_custom_data_layer_type(0, TYPE_STRING_NAME)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(1, "elevation")
	tileset.set_custom_data_layer_type(1, TYPE_INT)
	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	src.texture = tex("terrain/terrain_logic_tiles.png")
	src.texture_region_size = Vector2i(64, 32)
	tileset.add_source(src, 0)
	var names: Array[StringName] = [&"grass", &"dirt", &"water", &"cliff", &"high", &"void"]
	for i: int in names.size():
		src.create_tile(Vector2i(i, 0))
		var data: TileData = src.get_tile_data(Vector2i(i, 0), 0)
		data.set_custom_data("terrain", names[i])
		data.set_custom_data("elevation", 1 if names[i] == &"high" else 0)
	tileset = save_res(tileset, ENV + "terrain/terrain_logic_tileset.tres") as TileSet


# ---------------------------------------------------------------- props

func _prop(name_: String, texture_path: String, margin: float, sliced: Array) -> Node2D:
	var p: Node2D = Node2D.new()
	p.name = name_
	p.set_script(load(ENV + "props/environment_prop.gd"))
	sroot = p
	var t: Texture2D = tex(texture_path)
	var w: float = t.get_width() * 0.5
	var shadow: Sprite2D = Sprite2D.new()
	shadow.texture = tex("decals/shadow_soft.png")
	shadow.z_index = -1
	shadow.modulate = Color(1, 1, 1, 0.55)
	# Ellipse 2:1 trên mặt đất, lệch về dưới-phải (nguồn sáng trên-trái).
	shadow.scale = Vector2(w * 1.0 / 256.0, w * 0.5 / 128.0)
	shadow.position = Vector2(w * 0.14, w * 0.04)
	add(p, shadow, "Shadow")
	if sliced.is_empty():
		var visual: Sprite2D = Sprite2D.new()
		visual.texture = t
		visual.scale = Vector2(0.5, 0.5)
		visual.offset = Vector2(0, -(t.get_height() * 0.5 - margin))
		add(p, visual, "Visual")
	else:
		p.y_sort_enabled = true
		var fs: Node2D = Node2D.new()
		fs.set_script(load(ENV + "iso/footprint_sorted_sprite.gd"))
		fs.set("texture", t)
		fs.set("image_scale", 0.5)
		fs.set("image_offset", Vector2(-t.get_width() * 0.25, margin * 0.5 - t.get_height() * 0.5))
		fs.set("footprint", sliced[0])
		add(p, fs, "Visual")
	return p


func _collision(p: Node2D, polygon: PackedVector2Array) -> void:
	var body: StaticBody2D = p.get_node_or_null("Collision") as StaticBody2D
	if body == null:
		body = StaticBody2D.new()
		add(p, body, "Collision")
	var cp: CollisionPolygon2D = CollisionPolygon2D.new()
	cp.polygon = polygon
	add(body, cp, "Footprint%d" % body.get_child_count())


func _fader(p: Node2D, polygon: PackedVector2Array) -> void:
	var f: Area2D = Area2D.new()
	f.set_script(load(ENV + "props/occlusion_fader.gd"))
	f.collision_mask = 2
	add(p, f, "OcclusionFader")
	var cp: CollisionPolygon2D = CollisionPolygon2D.new()
	cp.polygon = polygon
	add(f, cp, "Shape")
	f.set("target", p.get_node("Visual"))


## Footprint (local, quanh origin) từ hộp lưới [i0, i0 + a] × [j0, j0 + b] so với điểm gốc lưới (gi, gj).
func box_fp(i0: float, j0: float, a: float, b: float, gi: float, gj: float) -> PackedVector2Array:
	return PackedVector2Array([iso(i0 - gi, j0 - gj), iso(i0 + a - gi, j0 - gj), iso(i0 + a - gi, j0 + b - gj), iso(i0 - gi, j0 + b - gj)])


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _build_props() -> void:
	var dir: String = ENV + "props/"
	# Gốc của prop hộp = điểm giữa cạnh trước SW (hoặc đỉnh dưới) footprint, khớp generator.
	var arch_fp: PackedVector2Array = box_fp(0, 0, 3.0, 0.62, 1.5, 0.62)
	var wall_fp: PackedVector2Array = box_fp(0, 0, 2.4, 0.4, 1.2, 0.4)
	var specs: Array = [
		["tree_oak_a", "props/tree_oak_a.png", 12.0, "tree", []],
		["tree_oak_b", "props/tree_oak_b.png", 12.0, "tree", []],
		["tree_pine", "props/tree_pine.png", 10.0, "pine", []],
		["bush_a", "props/bush_a.png", 6.0, "bush", []],
		["bush_b", "props/bush_b.png", 6.0, "bush", []],
		["fern", "props/fern.png", 6.0, "none", []],
		["rock_large", "props/rock_large.png", 8.0, "rock_large", []],
		["rock_small", "props/rock_small.png", 6.0, "rock_small", []],
		["rock_flat", "props/rock_flat.png", 6.0, "none", []],
		["ruin_pillar", "props/ruin_pillar.png", 3.0, "pillar", []],
		["ruin_pillar_broken", "props/ruin_pillar_broken.png", 3.0, "pillar_low", []],
		["ruin_arch", "props/ruin_arch.png", 4.0, "arch", [arch_fp]],
		["ruin_wall", "props/ruin_wall.png", 4.0, "wall", [wall_fp]],
		["ruin_blocks", "props/ruin_blocks.png", 4.0, "blocks", []],
		["rune_stone", "props/rune_stone.png", 4.0, "rune", []],
	]
	for spec: Array in specs:
		var p: Node2D = _prop(String(spec[0]).to_pascal_case(), spec[1], spec[2], spec[4])
		var t: Texture2D = tex(spec[1])
		var w: float = t.get_width() * 0.5
		var h: float = t.get_height() * 0.5
		var canopy: PackedVector2Array = _rect_poly(Rect2(-w * 0.42, -h + 6, w * 0.84, h - 8))
		match spec[3]:
			"tree":
				_collision(p, ellipse(Vector2(0, -2), 11))
				_fader(p, canopy)
			"pine":
				_collision(p, ellipse(Vector2(0, -2), 9))
				_fader(p, canopy)
			"bush":
				_collision(p, ellipse(Vector2(0, -6), w * 0.34))
			"rock_large":
				_collision(p, ellipse(Vector2(0, -12), w * 0.42))
			"rock_small":
				_collision(p, ellipse(Vector2(0, -7), w * 0.36))
			"pillar":
				_collision(p, box_fp(0, 0, 0.78, 0.78, 0.78, 0.78))
				_fader(p, _rect_poly(Rect2(-w * 0.5, -h + 4, w, h - 8)))
			"pillar_low":
				_collision(p, box_fp(0, 0, 0.78, 0.78, 0.78, 0.78))
			"arch":
				_collision(p, box_fp(0, 0, 0.62, 0.62, 1.5, 0.62))
				_collision(p, box_fp(2.38, 0, 0.62, 0.62, 1.5, 0.62))
				_fader(p, _rect_poly(Rect2(-w * 0.45, -h + 4, w * 0.9, h - 6)))
			"wall":
				_collision(p, wall_fp)
			"blocks":
				_collision(p, box_fp(0, 0, 1.3, 0.9, 1.2, 0.9))
			"rune":
				_collision(p, box_fp(0, 0, 0.55, 0.3, 0.275, 0.3))
				var light: PointLight2D = PointLight2D.new()
				light.texture = tex("fx/glow.png")
				light.color = Color(0.45, 0.9, 1.0)
				light.energy = 0.85
				light.texture_scale = 1.1
				light.position = Vector2(0, -44)
				add(p, light, "GlowLight")
				var halo: Sprite2D = Sprite2D.new()
				halo.texture = tex("fx/glow.png")
				halo.scale = Vector2(0.3, 0.42)
				halo.position = Vector2(-6, -50)
				halo.modulate = Color(0.45, 0.95, 1.0, 0.35)
				var add_mat: CanvasItemMaterial = CanvasItemMaterial.new()
				add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
				halo.material = add_mat
				ambient(halo, Vector2.ZERO, 3.5, Vector2(0.5, 1.0))
				add(p, halo, "GlowHalo")
		if spec[3] == "none":
			(p.get_node("Shadow") as CanvasItem).modulate.a = 0.35
		save_scene(p, dir + spec[0] + ".tscn")


# ---------------------------------------------------------------- world

var land: Node2D
var plateau: Node2D
var outcrop: Node2D
var bridge: Node2D
var logic: TileMapLayer


func _build_world() -> void:
	sroot = Node2D.new()
	sroot.name = "EnvironmentPrototype"
	sroot.set_script(load("res://world/world.gd"))
	(sroot as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat_ground = ground_material("ground_grass.tres", "ground/grass_base.png", 6.0, 1.0, Color(1.0, 1.0, 0.97), Color(1.06, 1.0, 0.82))
	mat_ground_high = ground_material("ground_grass_upper.tres", "ground/grass_base.png", 6.0, 1.0, Color(1.08, 1.06, 0.95), Color(1.12, 1.04, 0.84))
	mat_stone = ground_material("ground_stone_plaza.tres", "ground/stone_floor.png", 8.0, 0.0, Color(1, 1, 1), Color(0.96, 0.95, 0.9))
	# Đường đất sáng, mép mềm có cỏ lấn (VISUAL-02.2): pha màu cát, mép mờ rộng + noise 2 tầng.
	mat_dirt = path_material("path_dirt.tres", "ground/dirt_base.png", Color(1.05, 1.02, 0.97), 0.3, 0.06, {"sand_color": Color(0.88, 0.79, 0.6), "sand_mix": 0.45, "edge_noise_strength": 0.55, "edge_noise_scale": 2.0, "edge_detail": 0.45})
	var environment: Node2D = node2d(sroot, "Environment")
	var map_container: Node2D = node2d(sroot, "MapContainer")
	var entities: Node2D = node2d(sroot, "EntityContainer")
	entities.y_sort_enabled = true
	node2d(sroot, "EffectContainer")
	var cam_container: Node2D = node2d(sroot, "CameraContainer")
	var ui: CanvasLayer = CanvasLayer.new()
	ui.layer = 2
	add(sroot, ui, "UILayer")

	var ground: Node2D = node2d(map_container, "GladeMap")
	ground.z_index = -20
	_logic_and_land(ground)
	var elevation: Node2D = _elevation(entities)
	_ground(ground)
	_environment(environment)
	_props(entities)
	var player: Node = _entities(entities)
	_fill_logic()

	var cam: Node = instance(cam_container, "res://world/camera/game_camera.tscn", Vector2.ZERO, "GameCamera")
	cam.set("zoom_step", 0.25)
	cam.set("min_zoom", 1.0)
	cam.set("max_zoom", 3.0)
	cam.set("default_zoom", 2.0)
	for pair: Array in [["res://ui/combat/combat_hud.tscn", "CombatHUD"], ["res://ui/skills/skill_bar.tscn", "SkillBar"], ["res://ui/interaction/interaction_prompt.tscn", "InteractionPrompt"], ["res://ui/interaction/interaction_feedback.tscn", "InteractionFeedback"], ["res://ui/progression/progression_panel.tscn", "ProgressionPanel"], ["res://ui/debug/environment_debug_hud.tscn", "EnvironmentDebugHud"]]:
		var inst: Node = (load(pair[0]) as PackedScene).instantiate()
		inst.name = pair[1]
		ui.add_child(inst)
		inst.owner = sroot
	var dbg: Node = ui.get_node("EnvironmentDebugHud")
	dbg.set("agent", player.get_node("ElevationAgent"))
	dbg.set("terrain_logic", logic)
	dbg.set("camera", cam)
	dbg.set("tracked_body", player)
	sroot.set("camera", cam)
	sroot.set("camera_target", player)
	sroot.set("map_bounds", ground.get_node("MapBounds"))
	sroot.set("interaction_detector", player.get_node("InteractionDetector"))
	sroot.set("interaction_prompt", ui.get_node("InteractionPrompt"))
	sroot.set("interaction_feedback", ui.get_node("InteractionFeedback"))
	sroot.set("player_health", player.get_node("HealthComponent"))
	sroot.set("combat_hud", ui.get_node("CombatHUD"))
	sroot.set("player_weapon", player.get_node("WeaponEquipment"))
	sroot.set("player_attack", player.get_node("BasicAttackController"))
	sroot.set("player_skills", player.get_node("SkillLoadout"))
	sroot.set("player_caster", player.get_node("SkillCastingController"))
	sroot.set("skill_bar", ui.get_node("SkillBar"))
	sroot.set("player", player)
	sroot.set("player_classes", player.get_node("ClassManager"))
	sroot.set("player_level", player.get_node("CharacterLevel"))
	sroot.set("progression_panel", ui.get_node("ProgressionPanel"))
	var _unused: Node = elevation
	save_scene(sroot, PROTO + "environment_prototype.tscn")


func _terrain(parent: Node, name_: String, grid: PackedVector2Array, tier: int, height: float, z: float, top_mat: Material, back_lip: bool) -> Node2D:
	var t: Node2D = Node2D.new()
	t.set_script(load(ENV + "elevation/elevated_terrain.gd"))
	var outline: PackedVector2Array = isopoly(grid, z)
	var max_y: float = -INF
	var cx: float = 0.0
	for p: Vector2 in outline:
		max_y = maxf(max_y, p.y)
		cx += p.x
	t.position = Vector2(roundf(cx / outline.size()), max_y + height)
	var local: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in outline:
		local.append(p - t.position)
	t.set("tier", tier)
	t.set("height", height)
	t.set("outline", local)
	t.set("top_texture", tex("ground/grass_base.png"))
	t.set("top_material", top_mat)
	t.set("face_texture", tex("cliff/cliff_face.png"))
	t.set("lip_texture", tex("cliff/cliff_lip.png"))
	t.set("base_texture", tex("cliff/cliff_base.png") if tier > 0 else null)
	t.set("back_lip", back_lip)
	add(parent, t, name_)
	return t


func _logic_and_land(g: Node2D) -> void:
	logic = TileMapLayer.new()
	logic.set_script(load(ENV + "terrain/terrain_logic.gd"))
	logic.tile_set = tileset
	# TILE_LAYOUT_DIAMOND_DOWN đặt tâm ô (0,0) tại (32, 16); dịch −32 px để khớp IsoProjection.to_screen.
	logic.position = Vector2(-32, 0)
	logic.visible = false
	logic.z_index = 60
	logic.z_as_relative = false
	add(g, logic, "TerrainLogic")
	var bounds: StaticBody2D = StaticBody2D.new()
	bounds.set_script(load(ENV + "iso/iso_map_bounds.gd"))
	bounds.collision_mask = 0
	add(g, bounds, "MapBounds")
	bounds.set("source_layer", logic)
	bounds.set("extra_bottom", ABYSS_H)
	# Nền lấp đầy quanh map (màu sương vực) — không bao giờ lộ khoảng trống khi camera ra mép.
	var haze: Polygon2D = Polygon2D.new()
	haze.polygon = _rect_poly(Rect2(-2400, -1200, 4800, 3400))
	haze.color = HAZE
	haze.z_index = -110
	haze.z_as_relative = false
	add(g, haze, "AbyssHaze")
	# Mặt đất chính: khối nổi trên vực, mép SE/SW lộ vách vực cao.
	land = _terrain(g, "LandMass", LAND, 0, ABYSS_H, 0.0, mat_ground, true)
	var edge: StaticBody2D = StaticBody2D.new()
	edge.collision_mask = 0
	add(g, edge, "LandEdge")
	var loop: CollisionPolygon2D = CollisionPolygon2D.new()
	loop.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	loop.polygon = isopoly(LAND)
	add(edge, loop, "Loop")


func _elevation(entities: Node2D) -> Node2D:
	var em: Node2D = Node2D.new()
	em.set_script(load(ENV + "elevation/elevation_map.gd"))
	em.y_sort_enabled = true
	add(entities, em, "Elevation")
	plateau = _terrain(em, "Plateau", PLATEAU, 1, H, H, mat_ground_high, false)
	outcrop = _terrain(em, "Outcrop", OUTCROP, 1, H, H, mat_ground_high, false)

	# Lối đi trên vòm (tầng 1) bắc từ plateau sang mỏm đá, lối tầng 0 chạy dưới gầm theo trục j.
	bridge = Node2D.new()
	bridge.set_script(load(ENV + "elevation/elevated_deck.gd"))
	bridge.position = iso(BRIDGE_I + BRIDGE_A, BRIDGE_J + BRIDGE_B)
	bridge.y_sort_enabled = true
	bridge.set("tier", 1)
	var deck: PackedVector2Array = PackedVector2Array([iso(BRIDGE_I - 0.3, BRIDGE_J + 0.15, H), iso(BRIDGE_I + BRIDGE_A + 0.3, BRIDGE_J + 0.15, H), iso(BRIDGE_I + BRIDGE_A + 0.3, BRIDGE_J + BRIDGE_B - 0.15, H), iso(BRIDGE_I - 0.3, BRIDGE_J + BRIDGE_B - 0.15, H)])
	var local_deck: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in deck:
		local_deck.append(p - bridge.position)
	bridge.set("deck_polygon", local_deck)
	add(em, bridge, "StoneBridge")
	var bt: Texture2D = tex("structures/stone_bridge.png")
	var origin_texel: Vector2 = Vector2(BRIDGE_B * 64.0 + 4.0, H * 2.0 + 4.0)
	var fs: Node2D = Node2D.new()
	fs.set_script(load(ENV + "iso/footprint_sorted_sprite.gd"))
	fs.set("texture", bt)
	fs.set("image_scale", 0.5)
	fs.set("image_offset", iso(BRIDGE_I, BRIDGE_J) - bridge.position - origin_texel * 0.5)
	var fp: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in isopoly(PackedVector2Array([Vector2(BRIDGE_I, BRIDGE_J), Vector2(BRIDGE_I + BRIDGE_A, BRIDGE_J), Vector2(BRIDGE_I + BRIDGE_A, BRIDGE_J + BRIDGE_B), Vector2(BRIDGE_I, BRIDGE_J + BRIDGE_B)])):
		fp.append(p - bridge.position)
	fs.set("footprint", fp)
	add(bridge, fs, "Visual")
	var fader: Area2D = Area2D.new()
	fader.set_script(load(ENV + "props/occlusion_fader.gd"))
	fader.collision_mask = 2
	fader.set("occluder_tier", 1)
	fader.set("faded_alpha", 0.5)
	fader.set("fade_same_tier", false)
	add(bridge, fader, "OcclusionFader")
	var fcp: CollisionPolygon2D = CollisionPolygon2D.new()
	fcp.polygon = fp
	add(fader, fcp, "Shape")
	fader.set("target", fs)

	# Cầu thang dựa vào vách SW của plateau, đi lên theo trục −j.
	var con: Area2D = Area2D.new()
	con.set_script(load(ENV + "elevation/elevation_connector.gd"))
	var ic: float = STAIRS_I + STAIRS_W * 0.5
	con.position = iso(ic, STAIRS_J + STAIRS_RUN * 0.5)
	con.y_sort_enabled = true
	con.collision_mask = 2 | 8
	con.set("bottom", iso(ic, STAIRS_J + STAIRS_RUN + 0.1) - con.position)
	con.set("top", iso(ic, STAIRS_J - 0.2, H) - con.position)
	con.set("half_width", iso(STAIRS_W * 0.5, 0))
	add(em, con, "CliffStairs")
	var st: Texture2D = tex("structures/cliff_stairs.png")
	var s_origin: Vector2 = Vector2(STAIRS_RUN * 64.0 + 4.0, H * 2.0 + 4.0)
	var sfs: Node2D = Node2D.new()
	sfs.set_script(load(ENV + "iso/footprint_sorted_sprite.gd"))
	sfs.set("texture", st)
	sfs.set("image_scale", 0.5)
	sfs.set("image_offset", iso(STAIRS_I, STAIRS_J) - con.position - s_origin * 0.5)
	var sfp: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in isopoly(PackedVector2Array([Vector2(STAIRS_I, STAIRS_J), Vector2(STAIRS_I + STAIRS_W, STAIRS_J), Vector2(STAIRS_I + STAIRS_W, STAIRS_J + STAIRS_RUN), Vector2(STAIRS_I, STAIRS_J + STAIRS_RUN)])):
		sfp.append(p - con.position)
	sfs.set("footprint", sfp)
	add(con, sfs, "Visual")

	# Chi tiết mặt đất tầng 1: quảng trường đá lát thoi, đường đất chạy xéo trên vách, cỏ/hoa.
	var upper: Node2D = node2d(em, "UpperGroundDetail")
	upper.z_index = 1 * 10 - 6
	var plaza: Polygon2D = Polygon2D.new()
	plaza.polygon = isopoly(PLAZA, H)
	# Không gán texture: shader tự lấy mẫu albedo. Bật repeat vì sampler dùng chung trạng thái với texture của node.
	plaza.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	plaza.material = mat_stone
	add(upper, plaza, "StonePlaza")
	var plaza_edge: Line2D = ground_line(upper, "PlazaEdge", PLAZA + PackedVector2Array([PLAZA[0]]), 0.15, null, null, H)
	plaza_edge.visible = false
	var upath: Line2D = ground_line(upper, "UpperPath", PATH_UPPER, 1.5, tex("ground/dirt_base.png"), mat_dirt, H)
	var tops: Array = [plateau, outcrop]
	_scatter(upper, "PlazaEdgeTufts", "decals/grass_tufts.png", 4, 140, 31, Vector2(0.4, 0.6), [], [], [], plaza_edge, Vector2(-6, 4))
	_scatter(upper, "UpperPathTufts", "decals/grass_tufts.png", 4, 110, 32, Vector2(0.4, 0.6), [], [], tops, upath, Vector2(-8, 3))
	var plaza_node: Node2D = _plaza_area(upper, plaza)
	_scatter(upper, "UpperTufts", "decals/grass_tufts.png", 4, 280, 33, Vector2(0.4, 0.65), [upath], [plaza_node], tops)
	_scatter(upper, "UpperFlowers", "decals/flowers.png", 4, 80, 34, Vector2(0.4, 0.6), [upath], [plaza_node], tops)
	_scatter(upper, "PlazaPebbles", "decals/pebbles.png", 4, 40, 35, Vector2(0.45, 0.7), [], [], [plaza_node])
	_scatter(upper, "UpperMoss", "decals/moss_patch.png", 1, 14, 36, Vector2(0.4, 0.7), [upath], [], tops, null, Vector2.ZERO, true)
	return em


## Node bọc polygon quảng trường để làm avoid/inside node (cần get_walkable_polygon()).
func _plaza_area(parent: Node, plaza: Polygon2D) -> Node2D:
	var deck: Node2D = Node2D.new()
	deck.set_script(load(ENV + "elevation/elevated_deck.gd"))
	deck.set("tier", -1)
	deck.set("deck_polygon", plaza.polygon)
	return add(parent, deck, "PlazaArea") as Node2D


func _ground(g: Node2D) -> void:
	var mat_mud: ShaderMaterial = path_material("shore_mud.tres", "ground/dirt_base.png", Color(0.62, 0.58, 0.5), 0.45, 0.1)
	var water_mat: ShaderMaterial = ShaderMaterial.new()
	water_mat.shader = load(ENV + "water/water_surface.gdshader")
	water_mat.set_shader_parameter("noise_tex", tex("fx/water_noise.png"))
	water_mat.set_shader_parameter("flow_direction", Vector2(1.0, 0.9))
	water_mat = save_res(water_mat, ENV + "water/stream_water.tres") as ShaderMaterial
	var avoid_terr: Array = [plateau, outcrop]

	var trans: Node2D = node2d(g, "Transitions")
	_scatter(trans, "MossPatches", "decals/moss_patch.png", 1, 70, 1, Vector2(0.7, 1.4), [], avoid_terr, [land], null, Vector2.ZERO, true)
	_scatter(trans, "DirtPatches", "decals/dirt_patch.png", 1, 12, 2, Vector2(0.5, 0.9), [], avoid_terr, [land], null, Vector2.ZERO, true)

	var paths: Node2D = node2d(g, "Paths")
	var pm: Line2D = ground_line(paths, "MainPath", PATH_MAIN, 1.7, tex("ground/dirt_base.png"), mat_dirt)
	var pb: Line2D = ground_line(paths, "BranchPath", PATH_BRANCH, 1.4, tex("ground/dirt_base.png"), mat_dirt)

	var stream: Node2D = Node2D.new()
	stream.set_script(load(ENV + "water/stream.gd"))
	add(g, stream, "Stream")
	var wc: Curve = Curve.new()
	wc.add_point(Vector2(0, 1.0))
	wc.add_point(Vector2(0.06, 0.62))
	wc.add_point(Vector2(1, 0.7))
	var shore: Line2D = ground_line(stream, "Shore", STREAM, 2.5, tex("ground/dirt_base.png"), mat_mud)
	shore.width_curve = wc
	var water: Line2D = ground_line(stream, "Water", STREAM, 2.0, tex("fx/water_noise.png"), water_mat)
	water.width_curve = wc
	# Suối đổ thẳng qua mép vực: đầu cuối phẳng, không bo tròn thò ra ngoài.
	water.end_cap_mode = Line2D.LINE_CAP_NONE
	shore.end_cap_mode = Line2D.LINE_CAP_NONE
	stream.set("water_line", water)

	var fb: Node2D = Node2D.new()
	fb.set_script(load(ENV + "water/footbridge.gd"))
	fb.position = iso(FOOT_I + 0.55, FOOT_J + 1.8)
	add(g, fb, "Footbridge")
	var deck: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in isopoly(PackedVector2Array([Vector2(FOOT_I + 0.05, FOOT_J), Vector2(FOOT_I + 1.05, FOOT_J), Vector2(FOOT_I + 1.05, FOOT_J + 3.6), Vector2(FOOT_I + 0.05, FOOT_J + 3.6)])):
		deck.append(p - fb.position)
	fb.set("deck_polygon", deck)
	var fbs: Sprite2D = Sprite2D.new()
	fbs.texture = tex("decals/shadow_soft.png")
	fbs.scale = Vector2(0.55, 0.35)
	fbs.rotation = -0.46
	fbs.position = Vector2(6, 8)
	fbs.modulate = Color(1, 1, 1, 0.55)
	add(fb, fbs, "Shadow")
	var fbv: Sprite2D = Sprite2D.new()
	fbv.texture = tex("structures/footbridge.png")
	fbv.centered = false
	fbv.scale = Vector2(0.5, 0.5)
	var f_origin: Vector2 = Vector2(3.6 * 64.0 + 4.0, 10.0 * 2.0 + 4.0)
	fbv.position = iso(FOOT_I, FOOT_J) - fb.position - f_origin * 0.5
	add(fb, fbv, "Visual")
	stream.set("crossings", [fb] as Array[Node2D])

	# Thác: suối đổ qua mép SE xuống vực.
	var fall: Polygon2D = Polygon2D.new()
	var a: Vector2 = iso(39.6, 26.4)
	var b: Vector2 = iso(39.6, 28.0)
	fall.polygon = PackedVector2Array([a + Vector2(0, -2), b + Vector2(0, -2), b + Vector2(0, ABYSS_H - 20), a + Vector2(0, ABYSS_H - 20)])
	fall.texture = tex("fx/water_noise.png")
	fall.uv = PackedVector2Array([Vector2(0, 0), Vector2(256, 0), Vector2(256, 256), Vector2(0, 256)])
	var wm: ShaderMaterial = ShaderMaterial.new()
	wm.shader = load(ENV + "water/waterfall.gdshader")
	wm.set_shader_parameter("noise_tex", tex("fx/water_noise.png"))
	fall.material = save_res(wm, ENV + "water/waterfall.tres") as ShaderMaterial
	add(g, fall, "Waterfall")
	add(g, mist((a + b) * 0.5 + Vector2(10, ABYSS_H - 40), Vector2(0.5, 0.4), 0.75), "WaterfallMist")
	# Sương dưới chân vách vực.
	var k: int = 0
	for gp: Vector2 in [Vector2(39.5, 6), Vector2(39.4, 16), Vector2(39.3, 34), Vector2(33, 39.4), Vector2(22, 39.4), Vector2(11, 39.3), Vector2(3, 39.3)]:
		add(g, mist(iso(gp.x, gp.y) + Vector2(0, ABYSS_H - 30), Vector2(1.4, 0.55), 0.7), "AbyssMist%d" % k)
		k += 1

	# Bóng AO chân vách tầng cao.
	for t: Node2D in [plateau, outcrop]:
		var chain: PackedVector2Array = _front_chain(isopoly(PLATEAU if t == plateau else OUTCROP, 0))
		var ao: Line2D = Line2D.new()
		ao.points = chain
		ao.width = 26
		ao.texture = gradient_strip(0.45, Color(0.02, 0.04, 0.05))
		ao.texture_mode = Line2D.LINE_TEXTURE_STRETCH
		ao.position = Vector2(0, 3)
		add(g, ao, "CliffBaseShade" + t.name)
	var under: Sprite2D = Sprite2D.new()
	under.texture = tex("decals/shadow_soft.png")
	under.position = iso(BRIDGE_I + BRIDGE_A * 0.5, BRIDGE_J + BRIDGE_B * 0.5)
	under.scale = Vector2(0.75, 0.6)
	under.modulate = Color(1, 1, 1, 0.65)
	add(g, under, "BridgeShadow")
	var shades: Array[Vector3] = [Vector3(34, 33, 1.7), Vector3(3, 12, 1.4), Vector3(3, 31, 1.3), Vector3(35, 8, 1.2)]
	for i: int in shades.size():
		var cs: Sprite2D = Sprite2D.new()
		cs.texture = tex("decals/canopy_shadow.png")
		cs.position = iso(shades[i].x, shades[i].y)
		cs.scale = Vector2(shades[i].z, shades[i].z * 0.5)
		cs.modulate = Color(1, 1, 1, 0.45)
		add(g, cs, "CanopyShade%d" % i)

	var dec: Node2D = node2d(g, "Details")
	var lines_avoid: Array = [pm, pb, shore]
	var terr: Array = [plateau, outcrop, fb]
	_scatter(dec, "PathEdgeTufts", "decals/grass_tufts.png", 4, 300, 11, Vector2(0.45, 0.7), [shore], terr, [land], pm, Vector2(-10, 3))
	_scatter(dec, "BranchEdgeTufts", "decals/grass_tufts.png", 4, 220, 12, Vector2(0.45, 0.7), [shore], terr, [land], pb, Vector2(-8, 3))
	_scatter(dec, "ShoreTufts", "decals/grass_tufts.png", 4, 340, 13, Vector2(0.5, 0.75), [pm], terr, [land], shore, Vector2(-6, 8))
	_scatter(dec, "PathPebbles", "decals/pebbles.png", 4, 90, 14, Vector2(0.4, 0.6), [shore], terr, [land], pm, Vector2(-24, -4))
	_scatter(dec, "MeadowTufts", "decals/grass_tufts.png", 4, 1100, 15, Vector2(0.4, 0.62), lines_avoid, terr, [land])
	_scatter(dec, "MeadowFlowers", "decals/flowers.png", 4, 260, 16, Vector2(0.42, 0.62), lines_avoid, terr, [land], null, Vector2.ZERO, false, Rect2(iso(2, 38).x, iso(2, 26).y, 520, 330))
	_scatter(dec, "ScatteredFlowers", "decals/flowers.png", 4, 120, 17, Vector2(0.4, 0.58), lines_avoid, terr, [land])
	_scatter(dec, "ForestLeaves", "decals/leaf_litter.png", 4, 160, 18, Vector2(0.5, 0.8), lines_avoid, terr, [land], null, Vector2.ZERO, false, Rect2(iso(29, 39).x, iso(29, 29).y, 700, 360))
	_scatter(dec, "CliffPebbles", "decals/pebbles.png", 4, 60, 20, Vector2(0.45, 0.7), lines_avoid, terr, [land], null, Vector2.ZERO, false, Rect2(iso(6, 19).x, iso(20, 17).y + 40, 600, 140))
	var lp: Node2D = _scatter(dec, "SunPatches", "decals/light_patch.png", 1, 14, 21, Vector2(1.2, 2.0), [], [], [land], null, Vector2.ZERO, true, Rect2(iso(2, 36).x, iso(4, 22).y, 760, 420))
	var add_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	(lp as CanvasItem).material = add_mat
	(lp as CanvasItem).modulate = Color(1, 0.9, 0.66, 0.2)
	lp.set("tint_variation", 0.0)


func _front_chain(outline_global: PackedVector2Array) -> PackedVector2Array:
	var n: int = outline_global.size()
	var flags: Array[bool] = []
	for i: int in n:
		var a: Vector2 = outline_global[i]
		var b: Vector2 = outline_global[(i + 1) % n]
		var normal: Vector2 = (b - a).orthogonal().normalized()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + normal, outline_global):
			normal = -normal
		flags.append(normal.y > 0.05)
	var start: int = 0
	for i: int in n:
		if not flags[i]:
			start = (i + 1) % n
	var chain: PackedVector2Array = PackedVector2Array()
	for k: int in n:
		var i: int = (start + k) % n
		if flags[i]:
			if chain.is_empty():
				chain.append(outline_global[i])
			chain.append(outline_global[(i + 1) % n])
	return chain


# ---------------------------------------------------------------- environment

func _environment(env: Node2D) -> void:
	var cm: CanvasModulate = CanvasModulate.new()
	cm.color = Color(1.0, 0.96, 0.86)
	add(env, cm, "SunTint")
	var bg: Parallax2D = Parallax2D.new()
	bg.scroll_scale = Vector2(0.82, 0.86)
	bg.repeat_size = Vector2(2662, 0)
	bg.repeat_times = 3
	bg.z_index = -100
	add(env, bg, "ScenicBackground")
	var valley: Sprite2D = Sprite2D.new()
	valley.texture = tex("scenery/valley_far.png")
	valley.centered = false
	valley.scale = Vector2(2.6, 2.6)
	valley.position = Vector2(-1331, -1250)
	add(bg, valley, "ValleyFar")
	for i: int in 4:
		add(bg, mist(Vector2(-900 + i * 600, 120 - (i % 2) * 90), Vector2(2.4, 1.0), 0.5, Color(1, 0.97, 0.92)), "ValleyMist%d" % i)

	var atmo: Node2D = node2d(env, "Atmosphere")
	atmo.z_index = 40
	var add_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var shafts: Array[Vector3] = [Vector3(8, 30, 0.13), Vector3(14, 34, 0.11), Vector3(12, 8, 0.12), Vector3(33, 31, 0.1)]
	for i: int in shafts.size():
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex("fx/light_shaft.png")
		s.material = add_mat
		s.position = iso(shafts[i].x, shafts[i].y)
		s.rotation = -0.55
		s.scale = Vector2(3.4, 1.6)
		s.modulate = Color(1, 0.88, 0.62, shafts[i].z)
		ambient(s, Vector2(10, 0), 11.0 + i * 2.0, Vector2(shafts[i].z * 0.5, shafts[i].z))
		add(atmo, s, "LightShaft%d" % i)
	for gp: Vector2 in [Vector2(14, 25), Vector2(26, 26.5)]:
		add(atmo, mist(iso(gp.x, gp.y), Vector2(1.2, 0.5), 0.13, Color(1, 0.96, 0.86)), "StreamMist%d" % int(gp.x))
	var motes: CPUParticles2D = CPUParticles2D.new()
	motes.position = iso(8, 31)
	motes.amount = 36
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.texture = tex("fx/mote.png")
	motes.material = add_mat
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(320, 160)
	motes.gravity = Vector2(0, -2)
	motes.direction = Vector2(0.3, -1)
	motes.spread = 80.0
	motes.initial_velocity_min = 3.0
	motes.initial_velocity_max = 9.0
	motes.scale_amount_min = 0.25
	motes.scale_amount_max = 0.55
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 0.95, 0.75, 0))
	fade.set_color(1, Color(1, 0.95, 0.75, 0))
	fade.add_point(0.5, Color(1, 0.95, 0.75, 0.7))
	motes.color_ramp = fade
	add(atmo, motes, "SunMotes")

	var fg: Node2D = node2d(env, "Foreground")
	fg.z_index = 50
	var leaves: Array[Vector3] = [Vector3(-1250, 1450, 1.0), Vector3(1250, 1450, -1.0), Vector3(-1330, 700, 1.0), Vector3(1330, 650, -1.0)]
	for i: int in leaves.size():
		var s: Sprite2D = Sprite2D.new()
		s.texture = tex("scenery/foreground_leaves.png")
		s.position = Vector2(leaves[i].x, leaves[i].y)
		s.scale = Vector2(0.75 * leaves[i].z, 0.75)
		s.modulate = Color(0.85, 0.9, 0.85, 0.95)
		ambient(s, Vector2(5, 3), 6.0 + i, Vector2(1, 1))
		add(fg, s, "OverhangLeaves%d" % i)


# ---------------------------------------------------------------- props placement

func _place(parent: Node, scene: String, grid: Vector2, tier: int = 0, flip: bool = false) -> Node:
	var inst: Node = instance(parent, ENV + "props/" + scene + ".tscn", iso(grid.x, grid.y, H * tier))
	if tier != 0:
		inst.set("elevation_tier", tier)
	if flip and inst.get_node("Visual") is Sprite2D:
		(inst.get_node("Visual") as Sprite2D).flip_h = true
	return inst


func _props(entities: Node2D) -> void:
	var props: Node2D = node2d(entities, "Props")
	props.y_sort_enabled = true
	# Tầng 1 — quảng trường tàn tích trên plateau.
	_place(props, "ruin_arch", Vector2(12, 7.6), 1)
	_place(props, "ruin_pillar", Vector2(9.6, 7.0), 1)
	_place(props, "ruin_pillar", Vector2(15.2, 7.4), 1)
	_place(props, "ruin_pillar_broken", Vector2(9.6, 11.8), 1)
	_place(props, "ruin_pillar_broken", Vector2(15.0, 11.8), 1)
	_place(props, "ruin_blocks", Vector2(13.6, 13.4), 1)
	_place(props, "rune_stone", Vector2(17.2, 8.6), 1)
	_place(props, "tree_pine", Vector2(7.4, 5.6), 1)
	_place(props, "tree_pine", Vector2(18.8, 5.8), 1)
	_place(props, "tree_oak_b", Vector2(7.2, 8.8), 1, true)
	_place(props, "bush_b", Vector2(18.6, 14.6), 1)
	_place(props, "bush_a", Vector2(7.4, 13.6), 1)
	_place(props, "fern", Vector2(16.6, 15.4), 1)
	_place(props, "rock_small", Vector2(8.4, 15.6), 1)
	# Tầng 1 — mỏm đá bên kia lối đi trên vòm.
	_place(props, "ruin_wall", Vector2(28.4, 9.4), 1)
	_place(props, "ruin_pillar_broken", Vector2(30.6, 11.4), 1)
	_place(props, "bush_a", Vector2(26.2, 7.6), 1)
	_place(props, "rock_small", Vector2(31.0, 8.0), 1)
	_place(props, "tree_pine", Vector2(30.4, 6.6), 1)
	# Tầng 0 — rừng ven mép tây bắc (cạnh sau).
	var nw: Array = [["tree_oak_a", 2.2, 3.5], ["tree_pine", 2.0, 8.0], ["tree_oak_b", 2.6, 11.5], ["tree_oak_a", 2.0, 15.5], ["tree_pine", 2.4, 19.5], ["tree_oak_b", 2.2, 29.0], ["tree_oak_a", 2.6, 33.0], ["tree_pine", 2.2, 36.5], ["tree_oak_a", 4.6, 2.2], ["tree_pine", 4.4, 35.0]]
	for e: Array in nw:
		_place(props, e[0], Vector2(e[1], e[2]), 0, int(e[2]) % 2 == 0)
	# Tầng 0 — dải phía sau plateau / mép đông bắc.
	for e: Array in [["tree_pine", 8.0, 2.0], ["tree_oak_b", 13.0, 2.2], ["tree_pine", 17.5, 2.0], ["tree_oak_a", 26.0, 2.6], ["tree_pine", 33.0, 2.4], ["tree_oak_b", 36.5, 4.0], ["tree_oak_a", 37.0, 10.0], ["tree_pine", 36.0, 15.0]]:
		_place(props, e[0], Vector2(e[1], e[2]), 0, int(e[1]) % 2 == 0)
	# Tầng 0 — đồng cỏ tây nam + suối.
	for e: Array in [["tree_oak_a", 6.0, 31.5], ["tree_oak_b", 11.0, 34.0], ["tree_pine", 15.5, 36.5], ["tree_oak_a", 21.0, 37.0], ["tree_oak_b", 9.0, 37.5]]:
		_place(props, e[0], Vector2(e[1], e[2]), 0, int(e[1]) % 2 == 0)
	_place(props, "rock_large", Vector2(12.5, 29.5))
	_place(props, "rock_small", Vector2(13.6, 30.2))
	_place(props, "rock_flat", Vector2(8.0, 27.5))
	_place(props, "ruin_pillar_broken", Vector2(5.5, 28.2))
	_place(props, "ruin_blocks", Vector2(6.6, 28.8))
	for gp: Vector2 in [Vector2(4.5, 31.0), Vector2(9.0, 30.5), Vector2(14.5, 33.0), Vector2(19.0, 33.5), Vector2(7.5, 21.5), Vector2(13.0, 22.6)]:
		_place(props, "bush_a" if int(gp.x) % 2 == 0 else "bush_b", gp, 0, int(gp.y) % 2 == 0)
	for gp: Vector2 in [Vector2(5.0, 26.8), Vector2(10.5, 26.8), Vector2(22.5, 28.0), Vector2(16.0, 31.0)]:
		_place(props, "fern", gp)
	# Tầng 0 — chân vách (chỉ vật thấp: vật cao ở đây sẽ chồng lên mặt tầng 1).
	_place(props, "rock_large", Vector2(15.0, 19.2))
	_place(props, "rock_small", Vector2(16.2, 19.4))
	_place(props, "bush_a", Vector2(7.6, 18.6))
	_place(props, "fern", Vector2(13.0, 18.6))
	_place(props, "rock_small", Vector2(21.6, 16.4))
	_place(props, "bush_b", Vector2(22.4, 6.0))
	# Tầng 0 — rừng đông nam.
	for e: Array in [["tree_oak_a", 31.0, 30.0], ["tree_pine", 34.5, 30.0], ["tree_oak_b", 37.5, 31.5], ["tree_oak_a", 33.0, 34.0], ["tree_pine", 36.0, 36.5], ["tree_oak_b", 31.0, 37.5], ["tree_oak_a", 37.5, 22.0], ["tree_pine", 34.0, 20.5], ["tree_oak_b", 30.0, 21.0], ["tree_oak_a", 26.5, 20.0], ["tree_pine", 36.5, 25.0]]:
		_place(props, e[0], Vector2(e[1], e[2]), 0, int(e[1]) % 2 == 0)
	for gp: Vector2 in [Vector2(32.5, 32.0), Vector2(35.5, 33.5), Vector2(29.5, 23.5), Vector2(33.0, 23.0), Vector2(25.0, 23.0)]:
		_place(props, "bush_a" if int(gp.x) % 2 == 0 else "bush_b", gp)
	_place(props, "rock_large", Vector2(28.0, 23.6))
	_place(props, "ruin_wall", Vector2(25.5, 36.5))
	_place(props, "ruin_pillar", Vector2(24.0, 37.4))


func _entities(entities: Node2D) -> Node:
	var player: Node = instance(entities, "res://entities/player/player.tscn", iso(26.6, 31.4), "Player")
	_agent(player)
	_adapter(player, "Visual/Shadow", "", "CollisionShape2D")
	var board: Node = instance(entities, "res://features/interaction/examples/notice_board.tscn", iso(26.4, 32.4), "NoticeBoard")
	board.set("message", "Environment Prototype (VISUAL-02, isometric): theo đường đất qua cầu gỗ, lên bậc thang đá tới quảng trường tàn tích; đi qua lối trên vòm sang mỏm đá, hoặc theo đường nhánh chui dưới gầm vòm. Nút góc phải trên bật lưới Terrain Logic.")
	var dummy: Node = instance(entities, "res://entities/enemies/training_dummy/training_dummy.tscn", iso(24.5, 34.6), "TrainingDummy")
	_agent(dummy)
	_adapter(dummy, "Visual/Shadow", "", "BlockingBody/CollisionShape2D")
	var enemy: Node = instance(entities, "res://entities/enemies/simple_enemy/simple_enemy.tscn", iso(9.0, 32.5), "SimpleEnemy")
	enemy.set("target", player)
	_agent(enemy)
	_adapter(enemy, "Visual/Shadow", "", "CollisionShape2D")
	return player


func _agent(body: Node) -> void:
	var agent: Node = Node.new()
	agent.set_script(load(ENV + "elevation/elevation_agent.gd"))
	add(body, agent, "ElevationAgent")


func _adapter(body: Node, shadow: String, pivot: String, shape: String) -> void:
	var adapter: Node = Node.new()
	adapter.set_script(load(ENV + "iso/iso_actor_adapter.gd"))
	add(body, adapter, "IsoActorAdapter")
	adapter.set("shadow", body.get_node(shadow))
	if pivot != "":
		adapter.set("facing_pivot", body.get_node(pivot))
	adapter.set("body_shape", body.get_node(shape))


# ---------------------------------------------------------------- logic grid

func _dist_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best: float = INF
	for i: int in pts.size() - 1:
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p))
	return best


## Phân loại theo vị trí màn hình (cái đang hiển thị ở đó): tầng cao theo mặt trên, cliff theo vùng vách.
func _fill_logic() -> void:
	var land_s: PackedVector2Array = isopoly(LAND)
	var tops: Array[PackedVector2Array] = [isopoly(PLATEAU, H), isopoly(OUTCROP, H), isopoly(PackedVector2Array([Vector2(BRIDGE_I, BRIDGE_J), Vector2(BRIDGE_I + BRIDGE_A, BRIDGE_J), Vector2(BRIDGE_I + BRIDGE_A, BRIDGE_J + BRIDGE_B), Vector2(BRIDGE_I, BRIDGE_J + BRIDGE_B)]), H)]
	var sweeps: Array[PackedVector2Array] = [_sweep(isopoly(PLATEAU, H)), _sweep(isopoly(OUTCROP, H))]
	var stream_g: PackedVector2Array = groundpts(STREAM)
	var paths_g: Array[PackedVector2Array] = [groundpts(PATH_MAIN), groundpts(PATH_BRANCH)]
	for j: int in N:
		for i: int in N:
			var c: Vector2 = iso(i + 0.5, j + 0.5)
			var cg: Vector2 = Vector2(c.x, c.y * 2.0)
			var id: int = 0
			if not Geometry2D.is_point_in_polygon(c, land_s):
				id = 5
			elif tops.any(func(p: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(c, p)):
				id = 4
			elif sweeps.any(func(p: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(c, p)):
				id = 3
			elif _dist_to_polyline(cg, stream_g) < 2.0 * 45.25 * 0.35:
				id = 2
			elif paths_g.any(func(p: PackedVector2Array) -> bool: return _dist_to_polyline(cg, p) < 0.6 * 45.25):
				id = 1
			logic.set_cell(Vector2i(i, j), 0, Vector2i(id, 0))


func _sweep(outline_global: PackedVector2Array) -> PackedVector2Array:
	var t: Node2D = Node2D.new()
	t.set_script(load(ENV + "elevation/elevated_terrain.gd"))
	t.set("height", H)
	t.set("outline", outline_global)
	get_root().add_child(t)
	var result: PackedVector2Array = t.call("get_blocking_polygon")
	t.queue_free()
	return result
