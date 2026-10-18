class_name SkillModifier
extends Resource
## Thay đổi cộng thêm lên thông số của một SkillDefinition (dữ liệu thiết kế, dùng cho skill level / nhánh tiến hóa).
## Chỉ áp lên bản sao runtime (SkillDefinition.create_variant), không bao giờ sửa Resource gốc.
## Mọi giá trị là placeholder; không có công thức tăng tự động.

## Thay tên ngắn trên HUD (rỗng = giữ nguyên).
@export var short_name_override: String = ""

@export_group("Targeting")
@export var cast_range_bonus: float = 0.0
@export var radius_bonus: float = 0.0
@export var width_bonus: float = 0.0
@export var angle_degrees_bonus: float = 0.0

@export_group("Timing")
@export var cast_time_bonus: float = 0.0
@export var cooldown_bonus: float = 0.0
@export var max_charges_bonus: int = 0

@export_group("Effect")
@export var effect_amount_bonus: int = 0
@export var knockback_bonus: float = 0.0

@export_group("Indicator")
@export var override_indicator_color: bool = false
@export var indicator_color: Color = Color(0.4, 0.8, 1.0, 0.35)


## Áp lên `definition` (phải là bản sao runtime).
func apply_to(definition: SkillDefinition) -> void:
	if not short_name_override.is_empty():
		definition.short_name = short_name_override
	definition.cast_range += cast_range_bonus
	definition.radius += radius_bonus
	definition.width += width_bonus
	definition.angle_degrees += angle_degrees_bonus
	definition.cast_time += cast_time_bonus
	definition.cooldown += cooldown_bonus
	definition.max_charges += max_charges_bonus
	definition.effect_amount += effect_amount_bonus
	definition.knockback += knockback_bonus
	if override_indicator_color:
		definition.indicator_color = indicator_color
