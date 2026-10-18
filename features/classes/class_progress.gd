class_name ClassProgress
extends RefCounted
## Runtime state của một class đã mở khóa: mastery, kỹ năng đã học, passive, loadout đã lưu.
## Chỉ lưu ID ổn định + số (sẵn sàng serialize); definition được tra lại qua ClassDefinition.

var class_id: StringName
var mastery: LevelProgress
## skill_id → SkillProgress của các kỹ năng đã học.
var skills: Dictionary[StringName, SkillProgress] = {}
## passive_id của passive bổ sung đã mở khóa / đang trang bị (không gồm signature).
var unlocked_passive_ids: Array[StringName] = []
var equipped_passive_ids: Array[StringName] = []
## skill_id theo 4 ô (&"" = trống), khôi phục khi quay lại class.
var loadout: Array[StringName] = []
## skill_id → SkillRuntime (cooldown/charges/cast mode) của kỹ năng đã học. Runtime state thuần, không lưu vào save.
var runtimes: Dictionary[StringName, SkillRuntime] = {}


func _init(p_class_id: StringName, mastery_curve: LevelCurve) -> void:
	class_id = p_class_id
	mastery = LevelProgress.new(mastery_curve)
	loadout.resize(SkillLoadout.SLOT_COUNT)
	loadout.fill(&"")


func to_dict() -> Dictionary:
	var skill_data: Dictionary = {}
	for id: StringName in skills:
		skill_data[String(id)] = skills[id].to_dict()
	return {
		"class_id": String(class_id),
		"mastery": mastery.to_dict(),
		"skills": skill_data,
		"unlocked_passives": unlocked_passive_ids.map(func(id: StringName) -> String: return String(id)),
		"equipped_passives": equipped_passive_ids.map(func(id: StringName) -> String: return String(id)),
		"loadout": loadout.map(func(id: StringName) -> String: return String(id)),
	}
