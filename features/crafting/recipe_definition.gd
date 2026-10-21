class_name RecipeDefinition
extends Resource
## Một công thức chế tạo / nấu ăn (TASK M3; dữ liệu thiết kế, chỉ đọc). Tên hiển thị = tên item kết quả.
## Chế tạo tức thì (M3 chưa có thời gian chờ, chưa có mở khóa công thức).

## MILL (TASK M5): cối đá — xay lúa mì thành bột.
enum Station { NONE, WORKBENCH, CAMPFIRE, MILL }

## Tên trạm hiển thị theo Station.
const STATION_NAMES: Array[String] = ["Tay không", "Bàn chế tạo", "Lửa trại", "Cối đá"]

@export var id: StringName = &""
## Nguyên liệu: item_id → số lượng.
@export var ingredients: Dictionary[StringName, int] = {}
@export var result_id: StringName = &""
@export_range(1, 99) var result_count: int = 1
## Trạm yêu cầu: NONE = chế tạo bằng tay ở bất cứ đâu; WORKBENCH / CAMPFIRE / MILL = phải đứng gần trạm đó (lửa đang cháy).
@export var station: Station = Station.NONE


func get_station_name() -> String:
	return STATION_NAMES[station]


func get_validation_errors(database: ItemDatabase) -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("id rỗng")
	if ingredients.is_empty():
		errors.append("không có nguyên liệu")
	for item_id: StringName in ingredients:
		if ingredients[item_id] < 1:
			errors.append("số lượng nguyên liệu %s < 1" % item_id)
		if database != null and not database.has_item(item_id):
			errors.append("nguyên liệu không tồn tại: %s" % item_id)
	if database != null and not database.has_item(result_id):
		errors.append("kết quả không tồn tại: %s" % result_id)
	return errors
