class_name CraftingStation
extends Interactable
## Base mỏng cho trạm chế tạo (TASK M3): bàn chế tạo, lửa trại. Đứng trong `use_radius` (đo trên mặt đất), cùng tầng,
## và trạm đang hoạt động (lửa trại: đang cháy) → dùng được công thức của trạm (Crafting.stations_near).
## E → phát `open_requested(self)`; World mở cửa sổ chế tạo (lửa trại: chế độ Nấu).

## Người chơi tương tác: mở cửa sổ chế tạo / nấu ăn tại trạm này.
signal open_requested(station: CraftingStation)

const GROUP: StringName = &"crafting_stations"

@export var station: RecipeDefinition.Station = RecipeDefinition.Station.WORKBENCH
## Khoảng cách tối đa (px mặt đất) từ chân người chơi tới trạm để dùng công thức của trạm.
@export var use_radius: float = 72.0


func _ready() -> void:
	add_to_group(GROUP)


## Trạm có dùng được không (lửa trại đã tắt → false).
func is_station_active() -> bool:
	return true


func get_tier() -> int:
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	return agent.get_tier() if agent != null else -1


func _perform_interaction(_actor: Node2D) -> String:
	open_requested.emit(self)
	return ""
