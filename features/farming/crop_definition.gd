class_name CropDefinition
extends Resource
## Một loại cây trồng (TASK M5; dữ liệu thiết kế, chỉ đọc): lúa mì, khoai, mọng...
## - Gieo bằng item `seed_item_id` lên ô đất đã cày (FarmPlot).
## - Lớn theo "ngày tuổi": mỗi lần qua `FarmLayer.growth_minute` (6:00) mà hôm trước cây được tưới thì +1 ngày tuổi.
##   Giai đoạn = ngày tuổi / `days_per_stage` (tối đa `stages` − 1 = chín). Chín sau (stages − 1) × days_per_stage ngày.
## - Thu hoạch (E khi chín): `yield_min..yield_max` × `yield_item_id` + `seed_return_min..seed_return_max` × hạt.
##   `multi_harvest` = false → ô về đất cày trống; true → cây ở lại, lùi `regrow_days` ngày tuổi (ra quả lại sau N ngày tưới).
## - Hình placeholder: `stage_colors[giai đoạn]` (màu thân/lá), `fruit_color` (bông / củ / quả khi chín).

@export var id: StringName = &""
@export var display_name: String = ""
## Item gieo ra cây này (hạt, củ giống, quả mọng).
@export var seed_item_id: StringName = &""
@export_range(2, 8) var stages: int = 4
@export_range(1, 10) var days_per_stage: int = 1
@export var yield_item_id: StringName = &""
@export_range(0, 20) var yield_min: int = 1
@export_range(0, 20) var yield_max: int = 1
## Hạt trả lại khi thu (item = seed_item_id).
@export_range(0, 10) var seed_return_min: int = 0
@export_range(0, 10) var seed_return_max: int = 0
@export var multi_harvest: bool = false
## Cây thu nhiều lần: số ngày (tưới) để ra quả lại sau mỗi lần thu.
@export_range(1, 10) var regrow_days: int = 2

@export_group("Hình placeholder")
## Màu theo giai đoạn (0 = mầm ... stages − 1 = chín). Thiếu → màu xanh mặc định.
@export var stage_colors: Array[Color] = []
@export var fruit_color: Color = Color(0.9, 0.8, 0.3)
## Chiều cao cây chín (px màn hình); giai đoạn sớm thấp hơn theo tỉ lệ.
@export var mature_height: float = 18.0


## Ngày tuổi để chín.
func get_mature_age() -> int:
	return (stages - 1) * days_per_stage


func stage_for_age(age: int) -> int:
	return clampi(age / days_per_stage, 0, stages - 1)


func get_stage_color(stage: int) -> Color:
	return stage_colors[stage] if stage >= 0 and stage < stage_colors.size() else Color(0.35, 0.65, 0.3)


func get_validation_errors(database: ItemDatabase) -> Array[String]:
	var errors: Array[String] = []
	if id == &"" or display_name.is_empty():
		errors.append("id / display_name rỗng")
	if yield_min > yield_max or seed_return_min > seed_return_max:
		errors.append("min > max (sản lượng / hạt trả lại)")
	if multi_harvest and regrow_days > get_mature_age():
		errors.append("regrow_days > số ngày để chín")
	if database != null:
		for item_id: StringName in [seed_item_id, yield_item_id]:
			if not database.has_item(item_id):
				errors.append("item không tồn tại: %s" % item_id)
	return errors
