class_name MapCatalog
extends Resource
## Danh mục map lưu được (dữ liệu thiết kế): map_id ổn định → đường dẫn scene. Save chỉ ghi map_id, không ghi đường
## dẫn, nên đổi tên/chuyển file scene chỉ cần sửa catalog. Scene map là World có `map_id` trùng khóa ở đây.
## Giữ đường dẫn (không phải PackedScene) để SaveService (Autoload) không nạp sẵn mọi map lúc khởi động.
## TASK M6: `names` — tên hiển thị của map (danh sách ô save).

@export var scenes: Dictionary[StringName, String] = {}
@export var names: Dictionary[StringName, String] = {}


func get_scene_path(map_id: StringName) -> String:
	return scenes.get(map_id, "")


func has_map(map_id: StringName) -> bool:
	return scenes.has(map_id) and ResourceLoader.exists(scenes[map_id])


func get_display_name(map_id: StringName) -> String:
	return names.get(map_id, String(map_id))
