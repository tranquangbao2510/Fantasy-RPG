class_name SkillLoadout
extends Node
## Đúng 4 ô kỹ năng chủ động đang trang bị (ultimate, nếu có, dùng một trong 4 ô này).
## Mỗi ô giữ một SkillRuntime riêng. Không biết gì về vũ khí hay class.
##
## Quy tắc prototype: một kỹ năng chỉ được nằm ở một ô (trang bị trùng bị từ chối). Đổi trong can_equip().

## Ô thay đổi kỹ năng (definition null = ô trống).
signal slot_changed(slot: int, definition: SkillDefinition)
signal cast_mode_changed(slot: int, mode: SkillDefinition.CastMode)

const SLOT_COUNT: int = 4

## Kỹ năng ban đầu theo ô (tối đa 4 phần tử; null = trống).
@export var starting_skills: Array[SkillDefinition] = []
## Cast mode ban đầu theo ô; thiếu phần tử thì dùng default_cast_mode của kỹ năng.
@export var starting_cast_modes: Array[SkillDefinition.CastMode] = []

var _runtimes: Array[SkillRuntime] = []


func _ready() -> void:
	_runtimes.resize(SLOT_COUNT)
	for slot: int in mini(starting_skills.size(), SLOT_COUNT):
		if starting_skills[slot] != null:
			equip_skill(slot, starting_skills[slot])
			if slot < starting_cast_modes.size():
				set_cast_mode(slot, starting_cast_modes[slot])


func _physics_process(delta: float) -> void:
	for runtime: SkillRuntime in _runtimes:
		if runtime != null:
			runtime.tick(delta)


func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


func get_skill(slot: int) -> SkillDefinition:
	var runtime: SkillRuntime = get_runtime(slot)
	return runtime.definition if runtime != null else null


func get_runtime(slot: int) -> SkillRuntime:
	return _runtimes[slot] if is_valid_slot(slot) else null


## Điểm mở rộng cho Class System (kỹ năng thuộc class, mở khóa, ...). Hiện chỉ kiểm tra dữ liệu và trùng ô.
func can_equip(slot: int, definition: SkillDefinition) -> bool:
	if not is_valid_slot(slot) or definition == null or not definition.is_valid():
		return false
	for other: int in SLOT_COUNT:
		if other != slot and get_skill(other) != null and get_skill(other).skill_id == definition.skill_id:
			return false
	return true


func equip_skill(slot: int, definition: SkillDefinition) -> bool:
	if not can_equip(slot, definition):
		push_warning("[SkillLoadout] Không thể trang bị %s vào ô %d." % [definition.skill_id if definition != null else &"null", slot])
		return false
	_runtimes[slot] = SkillRuntime.new(definition, definition.default_cast_mode)
	slot_changed.emit(slot, definition)
	return true


func unequip_skill(slot: int) -> void:
	if not is_valid_slot(slot) or _runtimes[slot] == null:
		return
	_runtimes[slot] = null
	slot_changed.emit(slot, null)


func get_cast_mode(slot: int) -> SkillDefinition.CastMode:
	var runtime: SkillRuntime = get_runtime(slot)
	return runtime.cast_mode if runtime != null else SkillDefinition.CastMode.NORMAL


## Đổi cast mode của ô (runtime, không sửa Resource).
func set_cast_mode(slot: int, mode: SkillDefinition.CastMode) -> void:
	var runtime: SkillRuntime = get_runtime(slot)
	if runtime == null or runtime.cast_mode == mode:
		return
	runtime.cast_mode = mode
	cast_mode_changed.emit(slot, mode)


func cycle_cast_mode(slot: int) -> void:
	var runtime: SkillRuntime = get_runtime(slot)
	if runtime != null:
		set_cast_mode(slot, ((runtime.cast_mode + 1) % SkillDefinition.CastMode.size()) as SkillDefinition.CastMode)


## Hồi đầy charges, xóa cooldown của mọi ô (reset thử nghiệm).
func reset_runtimes() -> void:
	for runtime: SkillRuntime in _runtimes:
		if runtime != null:
			runtime.reset()
