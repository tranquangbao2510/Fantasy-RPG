class_name SkillProgress
extends RefCounted
## Runtime state của một kỹ năng đã học: level, nhánh tiến hóa đã chọn, cast mode người chơi chọn.
## Tồn tại độc lập với ô trang bị (unequip không làm mất).

var skill_id: StringName
var level: int = 1
## &"" = chưa tiến hóa.
var branch_id: StringName = &""
var cast_mode: SkillDefinition.CastMode


func _init(p_skill_id: StringName, p_cast_mode: SkillDefinition.CastMode) -> void:
	skill_id = p_skill_id
	cast_mode = p_cast_mode


func to_dict() -> Dictionary:
	return {"level": level, "branch": String(branch_id), "cast_mode": cast_mode}
