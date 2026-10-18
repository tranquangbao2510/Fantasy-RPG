extends Interactable
## Tinh thể thử nghiệm: mỗi lần tương tác đổi qua lại giữa hai màu. Không có hiệu ứng gameplay.

@export var color_a: Color = Color(0.35, 0.75, 1.0)
@export var color_b: Color = Color(0.85, 0.4, 1.0)

var _is_alternate: bool = false

@onready var _gem: Polygon2D = $Visual/Gem


func _ready() -> void:
	_gem.color = color_a


func _perform_interaction(_actor: Node2D) -> String:
	_is_alternate = not _is_alternate
	_gem.color = color_b if _is_alternate else color_a
	return "Tinh thể chuyển sang màu tím." if _is_alternate else "Tinh thể trở lại màu xanh."
