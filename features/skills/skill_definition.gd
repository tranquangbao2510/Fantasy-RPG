class_name SkillDefinition
extends Resource
## Định nghĩa một kỹ năng chủ động (dữ liệu thiết kế, chỉ đọc lúc chạy). Không chứa cooldown/charges đang chạy.
## Không phụ thuộc vũ khí; thuộc về class (ClassDefinition.skills). Level/nhánh tiến hóa tạo bản sao runtime
## qua create_variant(), không sửa Resource này. Mọi giá trị là placeholder.

enum TargetingType {
	SELF,          ## Tại vị trí người thi triển; `radius` (0 = chỉ bản thân).
	LINE,          ## Hình chữ nhật từ người thi triển theo hướng ngắm; `cast_range` × `width`.
	GROUND_CIRCLE, ## Hình tròn tại điểm ngắm (bị kẹp trong `cast_range`); `radius`.
	CONE,          ## Hình quạt phía trước; bán kính `cast_range`, góc `angle_degrees`.
}

enum CastMode {
	NORMAL,  ## Nhấn → ngắm → click trái xác nhận.
	QUICK,   ## Giữ phím → ngắm → thả để xác nhận.
	INSTANT, ## Nhấn → dùng hướng/vị trí chuột lúc nhấn, không có bước ngắm.
}

enum EffectType {
	DAMAGE, ## Gây sát thương lên Hurtbox phe đối địch trong vùng.
	HEAL,   ## Hồi HP cho người thi triển.
}

## ID ổn định, không phụ thuộc tên hiển thị (vd. &"test_arc_slash").
@export var skill_id: StringName = &""
@export var display_name: String = ""
## Tên ngắn cho ô HUD.
@export var short_name: String = ""
@export_multiline var description: String = ""
## Chế độ thi triển gợi ý; ô kỹ năng có thể ghi đè lúc chạy.
@export var default_cast_mode: CastMode = CastMode.NORMAL

@export_group("Targeting")
@export var targeting_type: TargetingType = TargetingType.SELF
@export var cast_range: float = 0.0
@export var radius: float = 0.0
@export var width: float = 0.0
@export var angle_degrees: float = 90.0

@export_group("Timing")
## Thời gian vận sức sau khi xác nhận, trước khi hiệu ứng xảy ra (0 = ngay physics tick kế).
@export var cast_time: float = 0.0
## Thời gian hồi một charge. Với max_charges = 1 đây chính là cooldown thông thường.
@export var cooldown: float = 1.0
@export var max_charges: int = 1
## Khoảng nghỉ tối thiểu giữa hai lần thi triển liên tiếp (dù còn charge).
@export var recast_delay: float = 0.0

@export_group("Effect")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var effect_amount: int = 0
## Tốc độ đẩy lùi (px/s) cho effect DAMAGE, hướng từ tâm hiệu ứng ra mục tiêu.
@export var knockback: float = 0.0

@export_group("Indicator")
@export var indicator_color: Color = Color(0.4, 0.8, 1.0, 0.35)

@export_group("Progression")
## Cấp tối đa của kỹ năng (1 = không nâng cấp).
@export var max_level: int = 1
## level_modifiers[i] áp dụng từ level i + 2 trở đi (cộng dồn). Số phần tử <= max_level − 1.
@export var level_modifiers: Array[SkillModifier] = []
## Các nhánh tiến hóa (branch_id duy nhất). Rỗng = không có tiến hóa.
@export var evolution_branches: Array[SkillEvolutionBranch] = []


func get_evolution_branch(branch_id: StringName) -> SkillEvolutionBranch:
	for branch: SkillEvolutionBranch in evolution_branches:
		if branch != null and branch.branch_id == branch_id:
			return branch
	return null


## Bản sao runtime đã áp skill level, nhánh tiến hóa (branch_id rỗng = chưa tiến hóa) và % hiệu ứng từ passive.
## Không sửa Resource này. Kết quả có thể không hợp lệ nếu dữ liệu modifier sai — người gọi kiểm tra is_valid().
func create_variant(level: int, branch_id: StringName = &"", effect_percent: float = 0.0) -> SkillDefinition:
	var variant: SkillDefinition = duplicate() as SkillDefinition
	for i: int in clampi(level - 1, 0, level_modifiers.size()):
		if level_modifiers[i] != null:
			level_modifiers[i].apply_to(variant)
	var branch: SkillEvolutionBranch = get_evolution_branch(branch_id) if branch_id != &"" else null
	if branch != null:
		branch.modifier.apply_to(variant)
	if effect_percent != 0.0:
		variant.effect_amount = maxi(0, roundi(variant.effect_amount * (1.0 + effect_percent / 100.0)))
	return variant


## Kiểm tra dữ liệu progression: cấp hợp lệ, nhánh có ID duy nhất, mọi tổ hợp level × nhánh cho ra definition hợp lệ.
func is_progression_valid() -> bool:
	if max_level < 1 or level_modifiers.size() > max_level - 1 or level_modifiers.has(null):
		return false
	var ids: Array[StringName] = [&""]
	for branch: SkillEvolutionBranch in evolution_branches:
		if branch == null or not branch.is_valid() or ids.has(branch.branch_id):
			return false
		ids.append(branch.branch_id)
	for level: int in range(1, max_level + 1):
		for id: StringName in ids:
			if not create_variant(level, id).is_valid():
				return false
	return true


func is_valid() -> bool:
	if skill_id == &"" or display_name.is_empty() or effect_amount < 0 or knockback < 0.0:
		return false
	if cast_time < 0.0 or cooldown < 0.0 or recast_delay < 0.0 or max_charges < 1:
		return false
	match targeting_type:
		TargetingType.SELF:
			return radius >= 0.0
		TargetingType.LINE:
			return cast_range > 0.0 and width > 0.0
		TargetingType.GROUND_CIRCLE:
			return cast_range >= 0.0 and radius > 0.0
		TargetingType.CONE:
			return cast_range > 0.0 and angle_degrees > 0.0 and angle_degrees <= 360.0
	return false
