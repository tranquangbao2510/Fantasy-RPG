class_name StoneMill
extends CraftingStation
## Cối đá (TASK M5): chế ở bàn chế tạo (item `stone_mill`, ItemDefinition.deploy_scene), đặt TRONG NHÀ (gần giường nhà —
## ItemDefinition.deploy_home_radius, World kiểm tra). Trạm "Cối đá" (RecipeDefinition.Station.MILL): xay lúa mì → bột.
## E → mở cửa sổ chế tạo (công thức tay + các trạm đang ở gần). Có thân va chạm (đặt trước mặt như lửa trại).
## Lưu bởi ItemPickupLayer (`deployed`, không có trạng thái riêng).

const ITEM_ID: StringName = &"stone_mill"

## ID ổn định của vật dựng (ItemPickupLayer đặt khi khôi phục save).
var spot_id: String = ""
var item_id: StringName = ITEM_ID


func setup_from_item(p_item_id: StringName) -> void:
	item_id = p_item_id
	if spot_id.is_empty():
		spot_id = "stone_mill_%d_%04d" % [Time.get_unix_time_from_system(), randi() % 10000]


func get_deploy_id() -> String:
	return spot_id


func get_interaction_prompt() -> String:
	return "Xay bột"
