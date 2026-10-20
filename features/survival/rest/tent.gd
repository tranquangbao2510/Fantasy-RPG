class_name Tent
extends RestSpot
## Lều đã dựng (TASK M2, item `tent` — ItemDefinition.deploy_scene). E mở menu: Ngủ / Thu lều (World hiện menu).
## Chỉ một lều dựng cùng lúc (World kiểm tra). Ngủ ở lều → điểm tỉnh dậy / hồi sinh tạm thời tại lều tới khi thu lều.
## Không chặn đường đi (không có thân va chạm). Lưu bởi ItemPickupLayer (mục `deployed`).

## Người chơi muốn thu lều về túi.
signal pack_requested(tent: Tent)
## Người chơi tương tác: World hiện menu chọn Ngủ / Thu lều.
signal menu_requested(tent: Tent)

const ITEM_ID: StringName = &"tent"

var item_id: StringName = ITEM_ID


func get_kind() -> String:
	return "tent"


func get_interaction_prompt() -> String:
	return "Lều (ngủ / thu)"


## Gọi khi đặt từ item (World) — id ổn định cho save.
func setup_from_item(p_item_id: StringName) -> void:
	item_id = p_item_id
	if spot_id.is_empty():
		spot_id = "tent_%d" % Time.get_unix_time_from_system()


func get_deploy_id() -> String:
	return spot_id


func request_sleep() -> void:
	sleep_requested.emit(self)


func request_pack() -> void:
	pack_requested.emit(self)


func _perform_interaction(_actor: Node2D) -> String:
	menu_requested.emit(self)
	return ""
