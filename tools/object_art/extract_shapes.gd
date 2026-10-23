extends SceneTree
## Trích hình polygon placeholder của đồ vật gameplay (trước TASK M7) thành dữ liệu cho generate_object_art.gd.
## Đã chạy MỘT LẦN trên scene cũ (lúc Visual còn là Polygon2D) → sinh object_shapes.gd; giữ lại để biết nguồn gốc dữ liệu.
## Chạy lại trên scene đã đổi sang sprite sẽ không tìm thấy polygon nào (báo lỗi, không ghi file).
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/object_art/extract_shapes.gd

const OUTPUT: String = "res://tools/object_art/object_shapes.gd"

## [khóa "asset/state", scene, node gốc trong scene, các node con bỏ qua (bóng / lửa — vẽ bằng code)]
const SOURCES: Array[Array] = [
	["workbench/default", "res://features/crafting/stations/workbench.tscn", "Visual", ["Shadow"]],
	["campfire/default", "res://features/crafting/stations/campfire.tscn", "Visual", ["Shadow", "Flame"]],
	["stone_mill/default", "res://features/crafting/stations/stone_mill.tscn", "Visual", ["Shadow"]],
	["chest/closed", "res://features/inventory/chest/chest.tscn", "Visual/Closed", []],
	["chest/open", "res://features/inventory/chest/chest.tscn", "Visual/Open", []],
	["bed/default", "res://features/survival/rest/bed.tscn", "Visual", ["Shadow"]],
	["tent/default", "res://features/survival/rest/tent.tscn", "Visual", ["Shadow"]],
	["notice_board/default", "res://features/interaction/examples/notice_board.tscn", "Visual", ["Shadow"]],
	["class_training_station/default", "res://features/classes/station/class_training_station.tscn", "Visual", ["Shadow"]],
	["death_bag/default", "res://features/survival/death/death_bag.tscn", "Visual", ["Shadow"]],
	["training_dummy/default", "res://entities/enemies/training_dummy/training_dummy.tscn", "Visual", ["Shadow"]],
	["tree_stump/default", "res://features/gathering/nodes/tree_node.tscn", "Depleted", ["Shadow"]],
	["rock_node/depleted", "res://features/gathering/nodes/rock_node.tscn", "Depleted", []],
	["berry_bush/berries", "res://features/gathering/nodes/berry_bush_node.tscn", "Available", []],
	["wild_potato/full", "res://features/gathering/nodes/wild_potato_node.tscn", "Available", ["Shadow"]],
	["wild_potato/depleted", "res://features/gathering/nodes/wild_potato_node.tscn", "Depleted", []],
]
## Bóng (Polygon2D "Shadow") của từng asset → ObjectShadow trong scene + vẽ trên khuôn.
const SHADOWS: Array[Array] = [
	["workbench", "res://features/crafting/stations/workbench.tscn", "Visual/Shadow"],
	["campfire", "res://features/crafting/stations/campfire.tscn", "Visual/Shadow"],
	["stone_mill", "res://features/crafting/stations/stone_mill.tscn", "Visual/Shadow"],
	["chest", "res://features/inventory/chest/chest.tscn", "Visual/Shadow"],
	["bed", "res://features/survival/rest/bed.tscn", "Visual/Shadow"],
	["tent", "res://features/survival/rest/tent.tscn", "Visual/Shadow"],
	["notice_board", "res://features/interaction/examples/notice_board.tscn", "Visual/Shadow"],
	["class_training_station", "res://features/classes/station/class_training_station.tscn", "Visual/Shadow"],
	["death_bag", "res://features/survival/death/death_bag.tscn", "Visual/Shadow"],
	["training_dummy", "res://entities/enemies/training_dummy/training_dummy.tscn", "Visual/Shadow"],
	["tree_stump", "res://features/gathering/nodes/tree_node.tscn", "Depleted/Shadow"],
	["wild_potato", "res://features/gathering/nodes/wild_potato_node.tscn", "Available/Shadow"],
]


func _init() -> void:
	quit(_extract())


func _extract() -> int:
	var lines: PackedStringArray = PackedStringArray([
		"extends RefCounted",
		"## SINH TỰ ĐỘNG bởi extract_shapes.gd từ scene trước TASK M7 — hình polygon placeholder cũ của đồ vật gameplay.",
		"## generate_object_art.gd vẽ lại các hình này vào PNG để game nhìn y như cũ. Không sửa tay trừ khi muốn đổi placeholder.",
		"",
		"## \"asset/state\" → danh sách [màu, điểm polygon (toạ độ local so với origin = chân vật, px world)] theo thứ tự vẽ.",
		"const SHAPES: Dictionary = {",
	])
	for source: Array in SOURCES:
		var scene: Node = (load(source[1]) as PackedScene).instantiate()
		var base: Node2D = scene.get_node(NodePath(source[2])) as Node2D
		var entries: PackedStringArray = PackedStringArray()
		for child: Node in base.get_children():
			if (source[3] as Array).has(String(child.name)):
				continue
			var poly: Polygon2D = child as Polygon2D
			if poly == null:
				continue
			var points: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in poly.polygon:
				points.append(poly.position + p * poly.scale)
			entries.append("\t\t[%s, %s]," % [_color(poly.color), _points(points)])
		scene.free()
		if entries.is_empty():
			push_error("Không có polygon trong %s:%s (scene đã đổi sang sprite?)" % [source[1], source[2]])
			return 1
		lines.append("\t\"%s\": [" % source[0])
		lines.append_array(entries)
		lines.append("\t],")
	lines.append("}")
	lines.append("")
	lines.append("## asset → [màu, polygon] của bóng đổ vẽ bằng code (ObjectShadow) — cùng hình với Polygon2D \"Shadow\" cũ.")
	lines.append("const SHADOWS: Dictionary = {")
	for source: Array in SHADOWS:
		var scene: Node = (load(source[1]) as PackedScene).instantiate()
		var poly: Polygon2D = scene.get_node(NodePath(source[2])) as Polygon2D
		lines.append("\t\"%s\": [%s, %s]," % [source[0], _color(poly.color), _points(poly.polygon)])
		scene.free()
	lines.append("}")
	var file: FileAccess = FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	print("Đã ghi %s" % OUTPUT)
	return 0


func _color(c: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [_num(c.r), _num(c.g), _num(c.b), _num(c.a)]


func _points(points: PackedVector2Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for p: Vector2 in points:
		parts.append("Vector2(%s, %s)" % [_num(p.x), _num(p.y)])
	return "[%s]" % ", ".join(parts)


func _num(value: float) -> String:
	return str(snappedf(value, 0.0001))
