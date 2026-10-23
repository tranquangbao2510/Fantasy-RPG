extends SceneTree
## Sinh khuôn PNG cho đồ vật gameplay + icon item (TASK M7, art đợt 2). Mỗi asset / trạng thái:
## - `<dir>/<file>.png` — ảnh GAME (đúng kích thước xuất): hình polygon placeholder cũ vẽ lại ở 2 texel / px, lề trong
##   suốt ≥ 4 texel → game nhìn như trước. Art thật: ghi đè file này (cùng kích thước, chân vật đúng anchor).
## - `tools/object_art/templates/<file>.png` — KHUÔN HƯỚNG DẪN để căn art gen AI (luôn sinh lại): ảnh game + bóng code +
##   thoi footprint (xanh lơ), khung chiều cao (vàng), chữ thập ở điểm neo (đỏ), viền lề 4 texel (xám).
## - `core/object_art/object_art.json` — tên, file, kích thước, anchor (texel), footprint, chiều cao, trạng thái,
##   texel_scale; ObjectSprite đọc lúc chạy (luôn ghi lại — dữ liệu do tool này quản lý).
## - Icon item: `features/items/icons/<id>.png` 128 × 128 (ô màu theo loại + chữ cái đầu, như placeholder M1 × 2).
##
## LUẬT GHI ĐÈ: ảnh game / icon chỉ được ghi khi file CHƯA tồn tại, hoặc khi có `--force` kèm tên cụ thể
## (tên file không đuôi, icon thêm tiền tố `icon:`). Chạy lại tool không bao giờ đè art thật. (tests/art/test_object_art.gd)
##
## Chạy từ thư mục gốc project (headless được), rồi --import (file mới: bật mipmaps — xem tools/README.txt):
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/object_art/generate_object_art.gd
##   ... generate_object_art.gd -- --force chest_closed,icon:wood     (ghi đè đúng các file này)
##   ... generate_object_art.gd -- --only chest,icon:wood              (chỉ xử lý các asset / icon này)
##   ... generate_object_art.gd -- --sheet res://docs/reports/M7/templates_grid.png   (ảnh lưới mọi khuôn)
## Biến môi trường OBJECT_ART_ROOT (mặc định res://): thư mục gốc để ghi (test dùng thư mục tạm).

const Canvas := preload("res://tools/object_art/canvas.gd")
const Shapes := preload("res://tools/object_art/object_shapes.gd")

const JSON_PATH: String = "core/object_art/object_art.json"
const TEMPLATE_DIR: String = "tools/object_art/templates"
const ICON_DIR: String = "features/items/icons"
const ITEM_DATABASE: String = "res://features/items/data/item_database.tres"
const CROP_BOOK: String = "res://features/farming/data/crop_book.tres"
const TEXEL_SCALE: float = 0.5
const TEXELS_PER_PX: float = 2.0
## Lề trong suốt (texel) quanh vùng vẽ `box`.
const MARGIN: int = 4
const ICON_SIZE: int = 128

## Đất cày (FarmField: ô = 1 ô lưới iso, inset 0.06, 2 luống) — màu khô; đất ướt = ảnh này × FarmField.wet_soil_tint.
const SOIL_COLOR: Color = Color(0.7, 0.53, 0.33)
const FURROW_COLOR: Color = Color(0, 0, 0, 0.18)
const CELL_AXIS_I: Vector2 = Vector2(32, 16)
const CELL_AXIS_J: Vector2 = Vector2(-32, 16)

## Asset: dir (art/ cạnh scene), box (vùng vẽ, px world, so với chân vật), footprint [tâm, bề rộng thoi 2:1],
## height (chiều cao đề xuất, px world), states: tên → danh sách lớp vẽ. Lớp: ["shapes", khóa object_shapes],
## ["prop", scene prop môi trường — dán ảnh Visual của nó], ["soil"], ["crop", id, giai đoạn]. shadow: khóa bóng code.
const ASSETS: Array[Dictionary] = [
	{"name": "workbench", "dir": "res://features/crafting/stations/art", "box": Rect2(-28, -36, 56, 44),
		"footprint": [Vector2(0, -4), 40.0], "height": 22.0, "shadow": "workbench",
		"states": {"default": [["shapes", "workbench/default"]]}},
	{"name": "campfire", "dir": "res://features/crafting/stations/art", "box": Rect2(-20, -16, 40, 28),
		"footprint": [Vector2(0, 0), 28.0], "height": 8.0, "shadow": "campfire",
		"states": {"default": [["shapes", "campfire/default"]]}},
	{"name": "stone_mill", "dir": "res://features/crafting/stations/art", "box": Rect2(-20, -34, 40, 42),
		"footprint": [Vector2(0, -3), 24.0], "height": 22.0, "shadow": "stone_mill",
		"states": {"default": [["shapes", "stone_mill/default"]]}},
	{"name": "chest", "dir": "res://features/inventory/chest/art", "box": Rect2(-20, -36, 40, 42),
		"footprint": [Vector2(0, -4), 30.0], "height": 24.0, "shadow": "chest",
		"states": {"closed": [["shapes", "chest/closed"]], "open": [["shapes", "chest/open"]]}},
	{"name": "bed", "dir": "res://features/survival/rest/art", "box": Rect2(-28, -28, 56, 34),
		"footprint": [Vector2(0, -4), 40.0], "height": 17.0, "shadow": "bed",
		"states": {"default": [["shapes", "bed/default"]]}},
	{"name": "tent", "dir": "res://features/survival/rest/art", "box": Rect2(-28, -48, 56, 54),
		"footprint": [Vector2(0, 0), 40.0], "height": 28.0, "shadow": "tent",
		"states": {"default": [["shapes", "tent/default"]]}},
	{"name": "notice_board", "dir": "res://features/interaction/examples/art", "box": Rect2(-24, -46, 48, 50),
		"footprint": [Vector2(0, -2), 28.0], "height": 38.0, "shadow": "notice_board",
		"states": {"default": [["shapes", "notice_board/default"]]}},
	{"name": "class_training_station", "dir": "res://features/classes/station/art", "box": Rect2(-24, -44, 48, 48),
		"footprint": [Vector2(0, -3), 22.0], "height": 34.0, "shadow": "class_training_station",
		"states": {"default": [["shapes", "class_training_station/default"]]}},
	{"name": "death_bag", "dir": "res://features/survival/death/art", "box": Rect2(-16, -24, 32, 28),
		"footprint": [Vector2(0, 0), 20.0], "height": 17.0, "shadow": "death_bag",
		"states": {"default": [["shapes", "death_bag/default"]]}},
	{"name": "training_dummy", "dir": "res://entities/enemies/training_dummy/art", "box": Rect2(-22, -46, 44, 50),
		"footprint": [Vector2(0, -2), 16.0], "height": 38.0, "shadow": "training_dummy",
		"states": {"default": [["shapes", "training_dummy/default"]]}},
	{"name": "tree_stump", "dir": "res://features/gathering/nodes/art", "box": Rect2(-18, -22, 36, 28),
		"footprint": [Vector2(0, 0), 20.0], "height": 12.0, "shadow": "tree_stump",
		"states": {"default": [["shapes", "tree_stump/default"]]}},
	{"name": "rock_node", "dir": "res://features/gathering/nodes/art", "box": Rect2(-30, -42, 60, 48),
		"footprint": [Vector2(0, -7), 40.0], "height": 34.0, "shadow": "",
		"states": {"full": [["prop", "res://world/environment/props/rock_small.tscn"]], "depleted": [["shapes", "rock_node/depleted"]]}},
	{"name": "berry_bush", "dir": "res://features/gathering/nodes/art", "box": Rect2(-40, -58, 80, 64),
		"footprint": [Vector2(0, -6), 51.0], "height": 50.0, "shadow": "",
		"states": {"full": [["prop", "res://world/environment/props/bush_b.tscn"], ["shapes", "berry_bush/berries"]],
			"depleted": [["prop", "res://world/environment/props/bush_b.tscn"]]}},
	{"name": "wild_potato", "dir": "res://features/gathering/nodes/art", "box": Rect2(-18, -28, 36, 34),
		"footprint": [Vector2(0, 0), 24.0], "height": 20.0, "shadow": "wild_potato",
		"states": {"full": [["shapes", "wild_potato/full"]], "depleted": [["shapes", "wild_potato/depleted"]]}},
	{"name": "soil_tilled", "dir": "res://features/farming/art", "box": Rect2(-34, -18, 68, 36),
		"footprint": [Vector2(0, 0), 64.0], "height": 0.0, "shadow": "",
		"states": {"default": [["soil"]]}},
]
## Cây trồng: một asset `crop_<id>` / cây trong CropBook, trạng thái stage_0..stages−1 (đọc từ data). Ảnh phủ cả ô
## (4 khóm), neo tại tâm ô.
const CROP_DIR: String = "res://features/farming/art"
const CROP_BOX: Rect2 = Rect2(-34, -44, 68, 56)

## Màu nền icon theo ItemDefinition.Category.
const CATEGORY_COLORS: Array[Color] = [
	Color(0.55, 0.42, 0.28), # MATERIAL
	Color(0.78, 0.33, 0.30), # FOOD
	Color(0.45, 0.50, 0.58), # TOOL
	Color(0.38, 0.47, 0.72), # WEAPON
	Color(0.36, 0.60, 0.46), # ARMOR
	Color(0.55, 0.65, 0.30), # SEED
	Color(0.80, 0.62, 0.22), # QUEST
	Color(0.50, 0.50, 0.50), # MISC
]
## Font 5×7 ('#' = điểm sáng) cho chữ cái đầu của icon và nhãn trên ảnh lưới.
const GLYPHS: Dictionary = {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"Đ": ["####.", ".#..#", ".#..#", "###.#", ".#..#", ".#..#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
}
## Bỏ dấu tiếng Việt của chữ cái đầu (giữ riêng Đ).
const BASE_LETTERS: Dictionary = {
	"ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬ": "A", "ÉÈẺẼẸÊẾỀỂỄỆ": "E", "ÍÌỈĨỊ": "I",
	"ÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢ": "O", "ÚÙỦŨỤƯỨỪỬỮỰ": "U", "ÝỲỶỸỴ": "Y",
}

var _root: String = "res://"
var _force: PackedStringArray = PackedStringArray()
var _only: PackedStringArray = PackedStringArray()
var _written: PackedStringArray = PackedStringArray()
var _kept: PackedStringArray = PackedStringArray()
var _templates: Array[Image] = []
var _template_names: PackedStringArray = PackedStringArray()


func _init() -> void:
	quit(_run())


## Luật ghi đè (dùng chung cho ảnh game và icon): chỉ ghi khi file chưa có, hoặc tên nằm trong danh sách --force.
static func should_write(absolute_path: String, art_name: String, force: PackedStringArray) -> bool:
	return not FileAccess.file_exists(absolute_path) or force.has(art_name)


## Mọi asset (gồm cây trồng đọc từ CropBook), đã điền size / anchor / file.
static func build_assets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for spec: Dictionary in ASSETS:
		result.append(spec.duplicate(true))
	var book: CropBook = load(CROP_BOOK) as CropBook
	for crop: CropDefinition in book.crops:
		var states: Dictionary = {}
		for stage: int in crop.stages:
			states["stage_%d" % stage] = [["crop", String(crop.id), stage]]
		result.append({"name": "crop_%s" % crop.id, "dir": CROP_DIR, "box": CROP_BOX, "footprint": [Vector2.ZERO, 64.0],
			"height": crop.mature_height, "shadow": "", "states": states})
	for spec: Dictionary in result:
		var box: Rect2 = spec["box"]
		spec["size"] = Vector2i(roundi(box.size.x * TEXELS_PER_PX) + MARGIN * 2, roundi(box.size.y * TEXELS_PER_PX) + MARGIN * 2)
		spec["anchor"] = Vector2i(roundi(-box.position.x * TEXELS_PER_PX) + MARGIN, roundi(-box.position.y * TEXELS_PER_PX) + MARGIN)
		var files: Dictionary = {}
		for state: String in spec["states"]:
			files[state] = "%s.png" % spec["name"] if state == "default" else "%s_%s.png" % [spec["name"], state]
		spec["files"] = files
	return result


func _run() -> int:
	_root = OS.get_environment("OBJECT_ART_ROOT") if OS.has_environment("OBJECT_ART_ROOT") else "res://"
	var sheet_path: String = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size():
		var next: String = args[k + 1] if k + 1 < args.size() else ""
		match args[k]:
			"--force":
				_force = next.split(",", false)
			"--only":
				_only = next.split(",", false)
			"--sheet":
				sheet_path = next
	var assets: Array[Dictionary] = build_assets()
	var database: ItemDatabase = load(ITEM_DATABASE) as ItemDatabase
	var known: PackedStringArray = PackedStringArray()
	for spec: Dictionary in assets:
		known.append(spec["name"])
		for state: String in spec["files"]:
			known.append(String(spec["files"][state]).get_basename())
	for item: ItemDefinition in database.items:
		known.append("icon:%s" % item.id)
	for name: String in _force + _only:
		if not known.has(name):
			push_error("Tên không tồn tại: '%s' (dùng tên file không đuôi, vd. chest_closed, hoặc icon:wood)" % name)
			return 1
	for spec: Dictionary in assets:
		if not _only.is_empty() and not _only.has(spec["name"]):
			continue
		var err: int = _generate_asset(spec)
		if err != OK:
			return err
	for item: ItemDefinition in database.items:
		var name: String = "icon:%s" % item.id
		if not _only.is_empty() and not _only.has(name):
			continue
		_write(_draw_icon(item), "res://%s/%s.png" % [ICON_DIR, item.id], name)
	_write_json(assets, database)
	if not sheet_path.is_empty():
		_write_sheet(sheet_path)
	print("Đã ghi %d ảnh: %s" % [_written.size(), ", ".join(_written)])
	print("Giữ nguyên %d ảnh đã có (art thật / placeholder cũ; ghi đè: --force <tên>): %s" % [_kept.size(), ", ".join(_kept)])
	return OK


func _generate_asset(spec: Dictionary) -> int:
	for state: String in spec["states"]:
		var canvas: Canvas = Canvas.new(spec["size"].x, spec["size"].y, Vector2(spec["anchor"]), TEXELS_PER_PX)
		for layer: Array in spec["states"][state]:
			_draw_layer(canvas, layer)
		var used: Rect2i = canvas.used_rect()
		var inner: Rect2i = Rect2i(MARGIN, MARGIN, canvas.w - MARGIN * 2, canvas.h - MARGIN * 2)
		if not used.has_area() or not inner.encloses(used):
			push_error("%s/%s: nội dung %s vượt vùng vẽ %s (lề %d texel) — nới `box`" % [spec["name"], state, used, inner, MARGIN])
			return ERR_INVALID_DATA
		var file: String = spec["files"][state]
		_write(canvas.to_image(), String(spec["dir"]).path_join(file), file.get_basename())
		var guide: Image = _draw_template(spec, canvas)
		_templates.append(guide)
		_template_names.append(file.get_basename())
		_save(guide, _abs("res://%s/%s" % [TEMPLATE_DIR, file]))
	return OK


func _draw_layer(canvas: Canvas, layer: Array) -> void:
	match String(layer[0]):
		"shapes":
			for shape: Array in Shapes.SHAPES[layer[1]]:
				canvas.polygon(PackedVector2Array(shape[1]), shape[0])
		"prop":
			var prop: Node = (load(layer[1]) as PackedScene).instantiate()
			var visual: Sprite2D = prop.get_node(^"Visual") as Sprite2D
			var image: Image = Image.load_from_file(ProjectSettings.globalize_path(visual.texture.resource_path))
			var factor: float = visual.scale.x * TEXELS_PER_PX
			if not is_equal_approx(factor, 1.0):
				image.resize(roundi(image.get_width() * factor), roundi(image.get_height() * factor), Image.INTERPOLATE_LANCZOS)
			var top_left: Vector2 = visual.offset - (Vector2(image.get_size()) / factor * 0.5 if visual.centered else Vector2.ZERO)
			canvas.blit(image, Vector2i((canvas.to_texel(visual.position) + top_left * factor).round()))
			prop.free()
		"soil":
			var corners: PackedVector2Array = PackedVector2Array()
			for corner: Vector2 in [-(CELL_AXIS_I + CELL_AXIS_J) * 0.5, (CELL_AXIS_I - CELL_AXIS_J) * 0.5,
					(CELL_AXIS_I + CELL_AXIS_J) * 0.5, (CELL_AXIS_J - CELL_AXIS_I) * 0.5]:
				corners.append(corner * 0.94)
			canvas.polygon(corners, SOIL_COLOR)
			for t: float in [0.35, 0.65]:
				var from: Vector2 = corners[0].lerp(corners[3], t)
				var to: Vector2 = corners[1].lerp(corners[2], t)
				canvas.line(from.lerp(to, 0.1), to.lerp(from, 0.1), FURROW_COLOR, 1.0)
		"crop":
			var crop: CropDefinition = (load(CROP_BOOK) as CropBook).get_crop(StringName(layer[1]))
			for offset: Vector2 in _clump_offsets():
				_draw_clump(canvas, crop, int(layer[2]), offset)


## Khóm cây — hình placeholder M5 (FarmPlot._draw cũ): lá tam giác theo stage_colors, chín thêm 3 bông / quả.
func _draw_clump(canvas: Canvas, crop: CropDefinition, stage: int, offset: Vector2) -> void:
	var color: Color = crop.get_stage_color(stage)
	var ratio: float = float(stage + 1) / crop.stages
	var height: float = crop.mature_height * ratio
	var spread: float = 3.0 + 5.0 * ratio
	var blades: int = 2 + stage
	for k: int in blades:
		var x: float = lerpf(-spread, spread, float(k) / maxf(1.0, blades - 1))
		var top: Vector2 = offset + Vector2(x * 0.6, -height * (0.75 + 0.25 * float(k % 2)))
		canvas.polygon(PackedVector2Array([offset + Vector2(x - 1.2, 0), offset + Vector2(x + 1.2, 0), top]), color)
	if stage == crop.stages - 1:
		for k: int in 3:
			canvas.circle(offset + Vector2(lerpf(-spread, spread, k / 2.0) * 0.6, -height * 0.8), 2.2, crop.fruit_color)


## 4 khóm trong một ô lưới iso, sau → trước (như FarmField cũ).
func _clump_offsets() -> PackedVector2Array:
	var a: Vector2 = CELL_AXIS_I * 0.22
	var b: Vector2 = CELL_AXIS_J * 0.22
	return PackedVector2Array([-a - b, a - b, -a + b, a + b])


## Khuôn hướng dẫn: bóng code → ảnh game → thoi footprint, khung chiều cao, chữ thập neo, viền lề.
func _draw_template(spec: Dictionary, game: Canvas) -> Image:
	var guide: Canvas = Canvas.new(game.w, game.h, game.anchor, TEXELS_PER_PX)
	var shadow_key: String = spec.get("shadow", "")
	if not shadow_key.is_empty():
		var shadow: Array = Shapes.SHADOWS[shadow_key]
		guide.polygon(PackedVector2Array(shadow[1]), shadow[0])
	guide.blit(game.to_image(), Vector2i.ZERO)
	var center: Vector2 = spec["footprint"][0]
	var half: float = float(spec["footprint"][1]) * 0.5
	var ground: PackedVector2Array = PackedVector2Array([center + Vector2(0, -half * 0.5), center + Vector2(half, 0),
		center + Vector2(0, half * 0.5), center + Vector2(-half, 0)])
	var height: float = spec["height"]
	if height > 0.0:
		var top: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in ground:
			top.append(p - Vector2(0, height))
		guide.outline(top, Color(1, 0.85, 0.1, 0.9))
		for k: int in [1, 2, 3]:
			guide.line(ground[k], top[k], Color(1, 0.85, 0.1, 0.9), 1.0 / TEXELS_PER_PX)
	guide.outline(ground, Color(0.1, 0.9, 1.0, 0.95))
	var a: Vector2 = Vector2.ZERO
	guide.line(a - Vector2(4, 0), a + Vector2(4, 0), Color(1, 0.1, 0.1), 1.0 / TEXELS_PER_PX)
	guide.line(a - Vector2(0, 4), a + Vector2(0, 4), Color(1, 0.1, 0.1), 1.0 / TEXELS_PER_PX)
	var image: Image = guide.to_image()
	var border: Color = Color(0.6, 0.6, 0.6, 0.8)
	for x: int in image.get_width():
		for y: int in [MARGIN - 1, image.get_height() - MARGIN]:
			image.set_pixel(x, y, border)
	for y: int in image.get_height():
		for x: int in [MARGIN - 1, image.get_width() - MARGIN]:
			image.set_pixel(x, y, border)
	return image


func _draw_icon(item: ItemDefinition) -> Image:
	# Bố cục icon M1 (64 px) nhân 2: lề 8, bo góc 18, chữ 5×7 mỗi điểm 12 px, bóng chữ lệch 2 px.
	var image: Image = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = CATEGORY_COLORS[item.category]
	var margin: int = 8
	var radius: int = 18
	for y: int in ICON_SIZE:
		for x: int in ICON_SIZE:
			var d: float = _rounded_rect_distance(x + 0.5, y + 0.5, margin, ICON_SIZE - margin, radius)
			if d > 0.5:
				continue
			var color: Color = (base * (1.12 - 0.25 * float(y) / ICON_SIZE)) if d < -6.0 else base.darkened(0.45)
			color.a = clampf(0.5 - d, 0.0, 1.0)
			image.set_pixel(x, y, color)
	var dot: int = 12
	var origin: Vector2i = Vector2i((ICON_SIZE - 5 * dot) / 2, (ICON_SIZE - 7 * dot) / 2)
	_stamp(image, _letter(item.display_name), origin + Vector2i(2, 2), dot, Color(0, 0, 0, 0.45))
	_stamp(image, _letter(item.display_name), origin, dot, Color(1, 0.97, 0.9))
	return image


func _stamp(image: Image, character: String, origin: Vector2i, dot: int, color: Color) -> void:
	var glyph: Array = GLYPHS.get(character, GLYPHS["?"])
	for row: int in 7:
		for col: int in 5:
			if String(glyph[row])[col] != "#":
				continue
			for dy: int in dot:
				for dx: int in dot:
					var p: Vector2i = origin + Vector2i(col * dot + dx, row * dot + dy)
					if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
						image.set_pixelv(p, color)


func _letter(text: String) -> String:
	if text.is_empty():
		return "?"
	var first: String = text.substr(0, 1).to_upper()
	for group: String in BASE_LETTERS:
		if group.contains(first):
			return BASE_LETTERS[group]
	return first


## Khoảng cách có dấu tới hình vuông bo góc [lo, hi]² (âm = bên trong).
func _rounded_rect_distance(x: float, y: float, lo: float, hi: float, radius: float) -> float:
	var cx: float = clampf(x, lo + radius, hi - radius)
	var cy: float = clampf(y, lo + radius, hi - radius)
	return Vector2(x - cx, y - cy).length() - radius


func _write(image: Image, res_path: String, art_name: String) -> void:
	var path: String = _abs(res_path)
	if not should_write(path, art_name, _force):
		_kept.append(art_name)
		return
	_save(image, path)
	_written.append(art_name)


func _write_json(assets: Array[Dictionary], database: ItemDatabase) -> void:
	var out: Dictionary = {}
	for spec: Dictionary in assets:
		var center: Vector2 = spec["footprint"][0]
		out[spec["name"]] = {
			"dir": spec["dir"],
			"size": [spec["size"].x, spec["size"].y],
			"anchor": [spec["anchor"].x, spec["anchor"].y],
			"footprint": {"center": [center.x, center.y], "width": spec["footprint"][1]},
			"height": spec["height"],
			"code_shadow": not String(spec.get("shadow", "")).is_empty(),
			"states": spec["files"],
		}
	var icons: Array[String] = []
	for item: ItemDefinition in database.items:
		icons.append(String(item.id))
	var data: Dictionary = {
		"version": 1,
		"generated_by": "tools/object_art/generate_object_art.gd",
		"texel_scale": TEXEL_SCALE,
		"margin": MARGIN,
		"assets": out,
		"icons": {"dir": "res://" + ICON_DIR, "size": ICON_SIZE, "items": icons},
	}
	var path: String = _abs("res://" + JSON_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", false) + "\n")


## Ảnh lưới mọi khuôn (nền xám, nhãn tên file dưới mỗi ô).
func _write_sheet(res_path: String) -> void:
	var cell: Vector2i = Vector2i(180, 170)
	var columns: int = 8
	var rows: int = ceili(_templates.size() / float(columns))
	var sheet: Image = Image.create(cell.x * columns, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.36, 0.38, 0.36))
	for k: int in _templates.size():
		var image: Image = _templates[k]
		var at: Vector2i = Vector2i((k % columns) * cell.x, (k / columns) * cell.y)
		var fit: Vector2i = image.get_size()
		var bg: Image = Image.create(fit.x, fit.y, false, Image.FORMAT_RGBA8)
		bg.fill(Color(0.45, 0.55, 0.36))
		sheet.blit_rect(bg, Rect2i(Vector2i.ZERO, fit), at + Vector2i((cell.x - fit.x) / 2, 4))
		sheet.blend_rect(image, Rect2i(Vector2i.ZERO, fit), at + Vector2i((cell.x - fit.x) / 2, 4))
		var label: String = _template_names[k].to_upper()
		var x: int = at.x + maxi(2, (cell.x - label.length() * 6) / 2)
		for c: int in label.length():
			_stamp(sheet, label[c], Vector2i(x + c * 6, at.y + cell.y - 12), 1, Color(1, 1, 1))
	_save(sheet, _abs(res_path))


## Đường dẫn tuyệt đối trong thư mục gốc ghi (OBJECT_ART_ROOT).
func _abs(res_path: String) -> String:
	return ProjectSettings.globalize_path(_root.path_join(res_path.trim_prefix("res://")))


func _save(image: Image, absolute_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var err: Error = image.save_png(absolute_path)
	if err != OK:
		push_error("Lưu %s thất bại (%s)" % [absolute_path, error_string(err)])
