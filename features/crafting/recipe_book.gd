class_name RecipeBook
extends Resource
## Danh mục công thức (TASK M3; dữ liệu thiết kế). Không phải Autoload: gán bằng export cho UI chế tạo (như ItemDatabase).
## Thêm công thức: New Resource → RecipeDefinition → thêm vào `recipes` của recipe_book.tres. Không cần sửa code.

@export var recipes: Array[RecipeDefinition] = []


func get_recipe(recipe_id: StringName) -> RecipeDefinition:
	for recipe: RecipeDefinition in recipes:
		if recipe != null and recipe.id == recipe_id:
			return recipe
	return null


## Công thức dùng được với các trạm đang ở gần (`stations`; công thức tay luôn có), theo thứ tự trong `recipes`.
## `only_station` ≥ 0: chỉ lấy công thức của đúng trạm đó (vd. menu Nấu ở lửa trại).
func recipes_for(stations: Array[int], only_station: int = -1) -> Array[RecipeDefinition]:
	var result: Array[RecipeDefinition] = []
	for recipe: RecipeDefinition in recipes:
		if recipe == null:
			continue
		if only_station >= 0 and recipe.station != only_station:
			continue
		if recipe.station == RecipeDefinition.Station.NONE or stations.has(recipe.station):
			result.append(recipe)
	return result


func get_validation_errors(database: ItemDatabase) -> Array[String]:
	var errors: Array[String] = []
	var seen: Array[StringName] = []
	for i: int in recipes.size():
		var recipe: RecipeDefinition = recipes[i]
		if recipe == null:
			errors.append("recipes[%d]: null" % i)
			continue
		for error: String in recipe.get_validation_errors(database):
			errors.append("recipes[%d] (%s): %s" % [i, recipe.id, error])
		if seen.has(recipe.id):
			errors.append("recipes[%d]: id trùng '%s'" % [i, recipe.id])
		seen.append(recipe.id)
	return errors
