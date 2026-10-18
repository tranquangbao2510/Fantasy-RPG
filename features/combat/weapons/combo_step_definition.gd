class_name ComboStepDefinition
extends Resource
## Một bước của chuỗi đánh thường (dữ liệu thiết kế, chỉ đọc lúc chạy).
## Dòng thời gian: windup → active (Hitbox bật) → recovery → link_window (nhận input nối bước kế).
## Mọi giá trị là placeholder.

@export var damage: int = 10
## Tầm với (px) tính từ điểm đánh theo hướng tấn công.
@export var attack_range: float = 28.0
## Bề rộng vùng đánh (px), vuông góc với hướng tấn công.
@export var attack_width: float = 24.0
@export var windup: float = 0.05
@export var active: float = 0.1
@export var recovery: float = 0.15
## Thời gian sau recovery còn nhận input để sang bước kế tiếp. Bỏ qua ở bước cuối.
@export var link_window: float = 0.25
## Tốc độ đẩy lùi ban đầu (px/s) theo hướng đòn. 0 = không đẩy.
@export var knockback: float = 0.0
## Màu placeholder của vùng vung đòn.
@export var effect_color: Color = Color(1, 1, 0.85, 0.6)


func is_valid() -> bool:
	return damage >= 0 and attack_range > 0.0 and attack_width > 0.0 \
		and windup >= 0.0 and active > 0.0 and recovery >= 0.0 and link_window >= 0.0 and knockback >= 0.0
