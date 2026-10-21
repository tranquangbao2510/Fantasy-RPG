class_name CropBook
extends Resource
## Danh mục cây trồng (TASK M5; dữ liệu thiết kế). Không phải Autoload: gán bằng export cho FarmLayer (như RecipeBook).
## Thêm cây: New Resource → CropDefinition → thêm vào `crops` của crop_book.tres (+ item hạt / nông sản). Không sửa code.

@export var crops: Array[CropDefinition] = []


func get_crop(crop_id: StringName) -> CropDefinition:
	for crop: CropDefinition in crops:
		if crop != null and crop.id == crop_id:
			return crop
	return null


## Cây gieo từ item này (null nếu item không phải hạt giống).
func find_by_seed(item_id: StringName) -> CropDefinition:
	for crop: CropDefinition in crops:
		if crop != null and crop.seed_item_id == item_id:
			return crop
	return null


func get_validation_errors(database: ItemDatabase) -> Array[String]:
	var errors: Array[String] = []
	var ids: Array[StringName] = []
	var seeds: Array[StringName] = []
	for i: int in crops.size():
		var crop: CropDefinition = crops[i]
		if crop == null:
			errors.append("crops[%d]: null" % i)
			continue
		for error: String in crop.get_validation_errors(database):
			errors.append("crops[%d] (%s): %s" % [i, crop.id, error])
		if ids.has(crop.id):
			errors.append("crops[%d]: id trùng '%s'" % [i, crop.id])
		if seeds.has(crop.seed_item_id):
			errors.append("crops[%d]: hạt '%s' đã dùng cho cây khác" % [i, crop.seed_item_id])
		ids.append(crop.id)
		seeds.append(crop.seed_item_id)
	return errors
