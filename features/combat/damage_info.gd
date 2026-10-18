class_name DamageInfo
extends RefCounted
## Dữ liệu của một lần gây sát thương. Một DamageInfo dùng chung cho mọi mục tiêu trúng trong cùng một đòn.
## Mục tiêu được xác định bởi Hurtbox nhận đòn. Mở rộng sau này (loại sát thương, knockback, ...) thêm field tại đây.

var amount: int = 0
## Thực thể gây sát thương (gốc scene của attacker). Dùng để tránh tự đánh chính mình.
var source: Node


func _init(p_amount: int = 0, p_source: Node = null) -> void:
	amount = p_amount
	source = p_source


func is_valid() -> bool:
	return amount > 0
