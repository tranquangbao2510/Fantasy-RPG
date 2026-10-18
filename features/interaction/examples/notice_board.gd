extends Interactable
## Bảng thông báo thử nghiệm: trả về một đoạn thông báo cố định.

@export_multiline var message: String = "Thông báo thử nghiệm."


func _perform_interaction(_actor: Node2D) -> String:
	return message
