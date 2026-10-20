class_name DetectionProfile
extends Resource
## Cách một enemy phát hiện mục tiêu (TASK M4, quái đêm). Dữ liệu thiết kế, dùng chung giữa các instance (chỉ đọc).
## Bán kính phát hiện thực tế = Enemy.detection_range × hệ số di chuyển của mục tiêu × (light_multiplier nếu mục tiêu
## đang CẦM nguồn sáng — đuốc, đèn lồng: thấy đường nhưng lộ vị trí). Đang đuổi: chỉ bỏ cuộc khi mục tiêu xa hơn
## bán kính × lose_multiplier. Enemy không có profile giữ hành vi cũ (bán kính cố định, không nhớ mục tiêu).
## Mục tiêu cung cấp (duck-typing, không bắt buộc): `is_holding_light() -> bool`, `is_sprinting() -> bool`, `velocity`.

@export var light_multiplier: float = 1.5
@export var sprint_multiplier: float = 1.0
@export var walk_multiplier: float = 0.75
@export var still_multiplier: float = 0.5
## Dưới tốc độ này (px/s) coi là đứng yên.
@export var still_speed: float = 5.0
@export var lose_multiplier: float = 1.5


## Hệ số nhân bán kính phát hiện cho mục tiêu hiện tại.
func multiplier_for(target: Node) -> float:
	var result: float = walk_multiplier
	if target.has_method(&"is_sprinting") and bool(target.call(&"is_sprinting")):
		result = sprint_multiplier
	elif &"velocity" in target and (target.get(&"velocity") as Vector2).length() <= still_speed:
		result = still_multiplier
	if target.has_method(&"is_holding_light") and bool(target.call(&"is_holding_light")):
		result *= light_multiplier
	return result
