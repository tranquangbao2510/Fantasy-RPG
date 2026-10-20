class_name RestSpot
extends Interactable
## Base mỏng cho chỗ ngủ (TASK M2): giường (Bed) và lều (Tent). Có `spot_id` ổn định trong map và tầng
## (ElevationAgent con nếu có). SleepController dùng để ngủ và làm điểm tỉnh dậy / hồi sinh.

const GROUP: StringName = &"rest_spots"

## Người chơi muốn ngủ ở đây (World → SleepController.try_sleep).
signal sleep_requested(spot: RestSpot)

@export var spot_id: String = ""


func _ready() -> void:
	add_to_group(GROUP)


## "bed" / "tent" — lưu trong điểm hồi sinh của Player.
func get_kind() -> String:
	return "bed"


## Ngủ ở đây có biến chỗ này thành "nhà" (điểm hồi sinh mặc định) không.
func is_home() -> bool:
	return false


func get_tier() -> int:
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	return agent.get_tier() if agent != null else -1


## Vị trí Player đứng khi tỉnh dậy (cạnh chỗ ngủ, không chồng lên vật).
func get_wake_position() -> Vector2:
	return global_position + Vector2(0, 14)
