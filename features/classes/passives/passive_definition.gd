class_name PassiveDefinition
extends Resource
## Định nghĩa một passive (dữ liệu thiết kế, không chứa runtime state).
## Hiệu ứng là một loại prototype + một giá trị; PassiveController cộng tổng các passive đang hoạt động.

enum EffectType {
	MAX_HEALTH,          ## Cộng `amount` vào max HP (số nguyên).
	SKILL_POWER_PERCENT, ## Cộng `amount` % vào effect_amount của kỹ năng (sát thương và hồi máu).
	MOVE_SPEED_PERCENT,  ## Cộng `amount` % vào tốc độ di chuyển.
}

## ID ổn định, không phụ thuộc tên hiển thị.
@export var passive_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect_type: EffectType = EffectType.MAX_HEALTH
@export var amount: float = 0.0


func is_valid() -> bool:
	if passive_id == &"" or display_name.is_empty():
		return false
	match effect_type:
		EffectType.MAX_HEALTH:
			return amount == roundf(amount) and amount > -1000.0
		EffectType.SKILL_POWER_PERCENT, EffectType.MOVE_SPEED_PERCENT:
			return amount > -100.0
	return false
