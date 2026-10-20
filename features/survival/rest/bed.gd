class_name Bed
extends RestSpot
## Giường (TASK M2): E để ngủ. Giường `home` là "nhà" tạm (Glade, sẽ chuyển vào nhà ở M5): điểm hồi sinh mặc định khi
## chưa có điểm nào khác hoặc lều đã thu.

@export var home: bool = true


func get_kind() -> String:
	return "bed"


func is_home() -> bool:
	return home


func get_interaction_prompt() -> String:
	return "Ngủ"


func _perform_interaction(_actor: Node2D) -> String:
	sleep_requested.emit(self)
	return ""
