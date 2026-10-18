class_name ClassDefinition
extends Resource
## Định nghĩa một class nhân vật (dữ liệu thiết kế, không chứa runtime state).
## Không xử lý input/damage; không tham chiếu vũ khí cụ thể (chỉ weapon_type_id).
## Kỹ năng chủ động thuộc class; đánh thường thuộc loại vũ khí (WeaponDefinition).

## ID ổn định, không phụ thuộc tên hiển thị (vd. &"test_fighter").
@export var class_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Loại vũ khí class dùng được (so với WeaponDefinition.weapon_type_id).
@export var allowed_weapon_type_ids: Array[StringName] = []
## Kỹ năng chủ động class có thể học.
@export var skills: Array[SkillDefinition] = []
## Kỹ năng được học sẵn khi mở khóa class, đồng thời là loadout mặc định theo thứ tự ô (prototype, tối đa 4).
@export var starting_skills: Array[SkillDefinition] = []
## Passive cố định của class: luôn hoạt động khi class đang dùng, không tháo được.
@export var signature_passive: PassiveDefinition
## Passive bổ sung class có thể trang bị (cần mở khóa trước).
@export var additional_passives: Array[PassiveDefinition] = []


func allows_weapon_type(weapon_type_id: StringName) -> bool:
	return allowed_weapon_type_ids.has(weapon_type_id)


func get_skill(skill_id: StringName) -> SkillDefinition:
	for skill: SkillDefinition in skills:
		if skill != null and skill.skill_id == skill_id:
			return skill
	return null


func has_skill(skill_id: StringName) -> bool:
	return get_skill(skill_id) != null


func get_additional_passive(passive_id: StringName) -> PassiveDefinition:
	for passive: PassiveDefinition in additional_passives:
		if passive != null and passive.passive_id == passive_id:
			return passive
	return null


func is_valid() -> bool:
	return get_validation_errors().is_empty()


## Danh sách lỗi dữ liệu (rỗng = hợp lệ).
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if class_id == &"":
		errors.append("class_id rỗng")
	if display_name.is_empty():
		errors.append("display_name rỗng")
	if allowed_weapon_type_ids.is_empty() or allowed_weapon_type_ids.has(&""):
		errors.append("allowed_weapon_type_ids rỗng hoặc có phần tử rỗng")
	var skill_ids: Array[StringName] = []
	for skill: SkillDefinition in skills:
		if skill == null or not skill.is_valid() or not skill.is_progression_valid():
			errors.append("skills có kỹ năng null/không hợp lệ")
		elif skill_ids.has(skill.skill_id):
			errors.append("skills trùng skill_id %s" % skill.skill_id)
		else:
			skill_ids.append(skill.skill_id)
	if starting_skills.size() > SkillLoadout.SLOT_COUNT:
		errors.append("starting_skills vượt quá %d ô" % SkillLoadout.SLOT_COUNT)
	var starting_ids: Array[StringName] = []
	for skill: SkillDefinition in starting_skills:
		if skill == null or not skill_ids.has(skill.skill_id) or starting_ids.has(skill.skill_id):
			errors.append("starting_skills phải là kỹ năng khác nhau thuộc skills")
		else:
			starting_ids.append(skill.skill_id)
	if signature_passive == null or not signature_passive.is_valid():
		errors.append("signature_passive thiếu hoặc không hợp lệ")
	var passive_ids: Array[StringName] = []
	if signature_passive != null:
		passive_ids.append(signature_passive.passive_id)
	for passive: PassiveDefinition in additional_passives:
		if passive == null or not passive.is_valid():
			errors.append("additional_passives có passive null/không hợp lệ")
		elif passive_ids.has(passive.passive_id):
			errors.append("passive_id trùng (hoặc trùng signature): %s" % passive.passive_id)
		else:
			passive_ids.append(passive.passive_id)
	return errors
