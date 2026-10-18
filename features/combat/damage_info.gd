class_name DamageInfo
extends RefCounted
## Dữ liệu của một lần gây sát thương. Một DamageInfo dùng chung cho mọi mục tiêu trúng trong cùng một đòn.
## Mục tiêu được xác định bởi Hurtbox nhận đòn. Mở rộng sau này (loại sát thương, knockback, ...) thêm field tại đây.

var amount: int = 0
## Thực thể gây sát thương (gốc scene của attacker). Dùng để tránh tự đánh chính mình.
var source: Node
## Vận tốc đẩy lùi ban đầu (px/s, đã gồm hướng). ZERO = không đẩy.
var knockback: Vector2 = Vector2.ZERO
## Tầng của nguồn gây sát thương (bit mask: tầng t = 1 << t). 0 = không lọc theo tầng (map không có elevation).
## Hurtbox chỉ nhận đòn nếu mask hai bên giao nhau (xem Hurtbox.can_receive).
var tier_mask: int = 0


func _init(p_amount: int = 0, p_source: Node = null) -> void:
	amount = p_amount
	source = p_source


func is_valid() -> bool:
	return amount > 0
