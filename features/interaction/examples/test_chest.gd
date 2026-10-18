extends Interactable
## Rương thử nghiệm: đóng → mở một lần. Không chứa vật phẩm, không lưu trạng thái.

var _is_open: bool = false

@onready var _closed_visual: Node2D = $Visual/Closed
@onready var _open_visual: Node2D = $Visual/Open


func _ready() -> void:
	_update_visual()


func get_interaction_prompt() -> String:
	return "Xem" if _is_open else "Mở"


func _perform_interaction(_actor: Node2D) -> String:
	if _is_open:
		return "Rương đã được mở trước đó."
	_is_open = true
	_update_visual()
	return "Đã mở rương. Bên trong trống rỗng."


func _update_visual() -> void:
	_closed_visual.visible = not _is_open
	_open_visual.visible = _is_open
