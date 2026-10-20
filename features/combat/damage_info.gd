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
## Mana bị hút khi trúng (TASK M4, vd. Bóng ma). Chủ thể có ManaComponent tự trừ khi Hurtbox báo trúng.
var mana_drain: float = 0.0


func _init(p_amount: int = 0, p_source: Node = null) -> void:
	amount = p_amount
	source = p_source


func is_valid() -> bool:
	return amount > 0


## Sát thương sau giáp (TASK M4): max(1, round(amount × 100 / (100 + armor))). armor ≤ 0 → giữ nguyên.
## Vd. áo da (giáp 30): đòn 28 → 22 (giảm ~23 %).
static func mitigate(amount: int, armor: int) -> int:
	if armor <= 0 or amount <= 0:
		return amount
	return maxi(1, roundi(amount * 100.0 / (100.0 + armor)))
