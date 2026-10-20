class_name Crafting
extends RefCounted
## Logic chế tạo (TASK M3), tách khỏi UI — chỉ làm việc với Inventory + RecipeDefinition + danh sách trạm đang ở gần,
## nên kiểm thử được độc lập. Chế tạo tức thì.
## Quy tắc:
## - Thiếu trạm / thiếu nguyên liệu → không làm gì (không trừ đồ), trả về lý do.
## - Túi đầy: kết quả phải vừa túi SAU KHI đã trừ nguyên liệu (nguyên liệu dùng hết có thể nhường ô); không vừa thì
##   CHẶN (không trừ gì, báo "Túi đầy") — chọn chặn thay vì rơi ra đất để không mất đồ mới làm trong bóng tối / dưới nước.


## Nguyên liệu còn thiếu: item_id → số thiếu (rỗng = đủ).
static func get_missing(recipe: RecipeDefinition, inventory: Inventory) -> Dictionary[StringName, int]:
	var missing: Dictionary[StringName, int] = {}
	for item_id: StringName in recipe.ingredients:
		var lacking: int = recipe.ingredients[item_id] - inventory.count_of(item_id)
		if lacking > 0:
			missing[item_id] = lacking
	return missing


## Lý do không chế tạo được ("" nếu được). `stations`: các RecipeDefinition.Station đang dùng được ở vị trí hiện tại.
static func get_block_reason(recipe: RecipeDefinition, inventory: Inventory, stations: Array[int]) -> String:
	if recipe == null or inventory == null:
		return "Không có công thức"
	if recipe.station != RecipeDefinition.Station.NONE and not stations.has(recipe.station):
		if recipe.station == RecipeDefinition.Station.CAMPFIRE:
			return "Cần lửa trại đang cháy"
		return "Cần đứng gần %s" % recipe.get_station_name().to_lower()
	if not get_missing(recipe, inventory).is_empty():
		return "Thiếu nguyên liệu"
	if not _fits_after_consuming(recipe, inventory):
		return "Túi đầy — không còn chỗ cho thành phẩm"
	return ""


## Chế tạo: trừ nguyên liệu, thêm thành phẩm. Trả về "" nếu thành công, ngược lại là lý do (không đổi túi).
static func craft(recipe: RecipeDefinition, inventory: Inventory, stations: Array[int]) -> String:
	var reason: String = get_block_reason(recipe, inventory, stations)
	if not reason.is_empty():
		return reason
	for item_id: StringName in recipe.ingredients:
		inventory.remove(item_id, recipe.ingredients[item_id])
	var left: int = inventory.add(recipe.result_id, recipe.result_count)
	if left > 0:
		push_error("[Crafting] Thành phẩm không vừa túi dù đã kiểm tra: %s" % recipe.id)
	return ""


## Các trạm dùng được quanh `actor`: CraftingStation (group) đang hoạt động, cùng tầng, trong use_radius (đo trên mặt
## đất theo `squash`). Không trùng lặp.
static func stations_near(actor: Node2D, squash: float = 1.0) -> Array[int]:
	var result: Array[int] = []
	if actor == null or not actor.is_inside_tree():
		return result
	for station: CraftingStation in find_stations_near(actor, squash):
		if not result.has(station.station):
			result.append(station.station)
	return result


## Các CraftingStation dùng được quanh actor (gần nhất trước).
static func find_stations_near(actor: Node2D, squash: float = 1.0) -> Array[CraftingStation]:
	var result: Array[CraftingStation] = []
	var agent: ElevationAgent = ElevationAgent.find_for(actor)
	var tier: int = agent.get_tier() if agent != null else -1
	for node: Node in actor.get_tree().get_nodes_in_group(CraftingStation.GROUP):
		var station: CraftingStation = node as CraftingStation
		if station == null or station.is_queued_for_deletion() or not station.is_station_active():
			continue
		if tier >= 0 and station.get_tier() >= 0 and station.get_tier() != tier:
			continue
		if GroundSpace.length(actor.global_position - station.global_position, squash) <= station.use_radius:
			result.append(station)
	result.sort_custom(func(a: CraftingStation, b: CraftingStation) -> bool:
		return actor.global_position.distance_squared_to(a.global_position) < actor.global_position.distance_squared_to(b.global_position))
	return result


static func _fits_after_consuming(recipe: RecipeDefinition, inventory: Inventory) -> bool:
	var sim: Inventory = Inventory.new()
	sim.database = inventory.database
	sim.size = inventory.get_size()
	sim.load_dict(inventory.to_dict())
	for item_id: StringName in recipe.ingredients:
		sim.remove(item_id, recipe.ingredients[item_id])
	var fits: bool = sim.space_for(recipe.result_id) >= recipe.result_count
	sim.free()
	return fits
