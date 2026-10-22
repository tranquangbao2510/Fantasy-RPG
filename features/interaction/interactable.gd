class_name Interactable
extends Area2D
## Base class mỏng cho đối tượng có thể tương tác. Thường là gốc của scene đối tượng.
## Origin = điểm tương tác (chân vật thể), dùng để chọn mục tiêu gần nhất.
## Đối tượng không tự đọc input: InteractionDetector gọi interact().
## Lớp con override _perform_interaction() và, nếu cần, can_interact() / get_interaction_prompt() / uses_tool().

@export var interaction_name: String = "Đối tượng"
@export var interaction_prompt: String = "Tương tác"
@export var interaction_enabled: bool = true


func can_interact(_actor: Node2D) -> bool:
	return interaction_enabled


func get_interaction_name() -> String:
	return interaction_name


func get_interaction_prompt() -> String:
	return interaction_prompt


func get_interaction_position() -> Vector2:
	return global_position


## Đối tượng là việc của công cụ `tool_type` (món đang cầm ở tay chính: `watering_can` → chỗ múc nước, `hoe` → ô ruộng,
## `axe` → cây...). InteractionDetector ưu tiên mục tiêu khớp công cụ đang cầm hơn mục tiêu gần hơn nhưng không khớp.
func uses_tool(_tool_type: StringName) -> bool:
	return false


## Thực hiện tương tác; trả về thông báo kết quả ("" nếu không thực hiện được).
func interact(actor: Node2D) -> String:
	if not can_interact(actor):
		return ""
	return _perform_interaction(actor)


func _perform_interaction(_actor: Node2D) -> String:
	return ""
