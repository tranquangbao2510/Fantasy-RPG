extends SceneTree
## Sinh icon placeholder cho mọi item trong features/items/data/item_database.tres (TASK M1):
## ô vuông bo góc màu theo loại item + chữ cái đầu của display_name (font bitmap 5×7 nhúng sẵn, không cần font).
## Ghi features/items/icons/<id>.png (64×64). Chạy lại khi thêm item; sau đó `--import` và gán `icon` cho item mới.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/item_icons/generate_item_icons.gd
## Icon mới: bật mipmaps/generate trong .import (pickup trên đất thu nhỏ icon).
## GHI ĐÈ icon cũ cùng tên (icon thật làm sau: thay PNG cùng tên rồi đừng chạy lại tool cho item đó).
## Chỉ sinh một số item: biến môi trường ICON_ONLY=wood,stone

const DATABASE_PATH: String = "res://features/items/data/item_database.tres"
const OUTPUT_DIR: String = "res://features/items/icons/"
const SIZE: int = 64
const SCALE: int = 6

## Màu nền theo ItemDefinition.Category.
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

## Font 5×7: mỗi chữ 7 hàng, '#' = điểm sáng.
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
	"?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
}
## Bỏ dấu tiếng Việt của chữ cái đầu (giữ riêng Đ).
const BASE_LETTERS: Dictionary = {
	"ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬ": "A", "ÉÈẺẼẸÊẾỀỂỄỆ": "E", "ÍÌỈĨỊ": "I",
	"ÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢ": "O", "ÚÙỦŨỤƯỨỪỬỮỰ": "U", "ÝỲỶỸỴ": "Y",
}


func _init() -> void:
	quit(_generate())


func _generate() -> int:
	var database: ItemDatabase = load(DATABASE_PATH) as ItemDatabase
	if database == null:
		push_error("Không đọc được %s" % DATABASE_PATH)
		return 1
	var only: PackedStringArray = OS.get_environment("ICON_ONLY").split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var count: int = 0
	for item: ItemDefinition in database.items:
		if item == null or item.id == &"" or (not only.is_empty() and not only.has(String(item.id))):
			continue
		var path: String = OUTPUT_DIR + String(item.id) + ".png"
		var err: Error = _draw_icon(item).save_png(ProjectSettings.globalize_path(path))
		if err != OK:
			push_error("Lưu %s thất bại (%s)" % [path, error_string(err)])
			return 1
		count += 1
	print("Đã sinh %d icon trong %s" % [count, OUTPUT_DIR])
	return 0


func _draw_icon(item: ItemDefinition) -> Image:
	var image: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var base: Color = CATEGORY_COLORS[item.category]
	var margin: int = 4
	var radius: int = 9
	for y: int in SIZE:
		for x: int in SIZE:
			var d: float = _rounded_rect_distance(x + 0.5, y + 0.5, margin, SIZE - margin, radius)
			if d > 0.5:
				continue
			var alpha: float = clampf(0.5 - d, 0.0, 1.0)
			var shade: float = 1.12 - 0.25 * float(y) / SIZE
			var color: Color = (base * shade) if d < -3.0 else base.darkened(0.45)
			color.a = alpha
			image.set_pixel(x, y, color)
	var glyph: Array = GLYPHS.get(_letter(item.display_name), GLYPHS["?"])
	var origin: Vector2i = Vector2i((SIZE - 5 * SCALE) / 2, (SIZE - 7 * SCALE) / 2)
	for row: int in 7:
		for col: int in 5:
			if String(glyph[row])[col] != "#":
				continue
			for dy: int in SCALE:
				for dx: int in SCALE:
					var p: Vector2i = origin + Vector2i(col * SCALE + dx, row * SCALE + dy)
					image.set_pixelv(p + Vector2i(1, 1), Color(0, 0, 0, 0.45))
			for dy: int in SCALE:
				for dx: int in SCALE:
					image.set_pixelv(origin + Vector2i(col * SCALE + dx, row * SCALE + dy), Color(1, 0.97, 0.9))
	return image


func _letter(name: String) -> String:
	if name.is_empty():
		return "?"
	var first: String = name.substr(0, 1).to_upper()
	for group: String in BASE_LETTERS:
		if group.contains(first):
			return BASE_LETTERS[group]
	return first


## Khoảng cách có dấu tới hình vuông bo góc [lo, hi]² (âm = bên trong).
func _rounded_rect_distance(x: float, y: float, lo: float, hi: float, radius: float) -> float:
	var cx: float = clampf(x, lo + radius, hi - radius)
	var cy: float = clampf(y, lo + radius, hi - radius)
	return Vector2(x - cx, y - cy).length() - radius
