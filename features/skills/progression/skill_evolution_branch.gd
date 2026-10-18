class_name SkillEvolutionBranch
extends Resource
## Một nhánh tiến hóa của kỹ năng (dữ liệu thiết kế). Thay đổi thông số qua SkillModifier.
## Điều kiện, tài nguyên, quy tắc đổi/reset nhánh chưa được chốt: hiện chỉ chọn bằng công cụ debug.

## ID ổn định, duy nhất trong một kỹ năng.
@export var branch_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var modifier: SkillModifier


func is_valid() -> bool:
	return branch_id != &"" and not display_name.is_empty() and modifier != null
