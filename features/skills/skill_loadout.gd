class_name SkillLoadout
extends Node
## Đúng 4 ô kỹ năng chủ động đang trang bị (ultimate, nếu có, dùng một trong 4 ô này).
## Mỗi ô giữ một SkillRuntime: tự tạo (equip_skill) hoặc nhận từ bên ngoài (equip_runtime, vd. ClassManager giữ
## runtime theo class + kỹ năng để cooldown không bị làm mới khi đổi ô/class). Không biết gì về vũ khí hay class: luật class đi qua set_equip_validator().
##
## Quy tắc prototype: một kỹ năng chỉ được nằm ở một ô (trang bị trùng bị từ chối). Đổi trong get_equip_block_reason().

## Ô thay đổi kỹ năng (definition null = ô trống), hoặc definition của ô được cập nhật (update_definition).
signal slot_changed(slot: int, definition: SkillDefinition)
signal cast_mode_changed(slot: int, mode: SkillDefinition.CastMode)
signal equip_rejected(slot: int, definition: SkillDefinition, reason: String)

const SLOT_COUNT: int = 4

## Kỹ năng ban đầu theo ô (tối đa 4 phần tử; null = trống).
@export var starting_skills: Array[SkillDefinition] = []
## Cast mode ban đầu theo ô; thiếu phần tử thì dùng default_cast_mode của kỹ năng.
@export var starting_cast_modes: Array[SkillDefinition.CastMode] = []

var _runtimes: Array[SkillRuntime] = []
var _equip_validator: Callable
## true = runtime do loadout tạo (equip_skill) và tự tick; false = runtime bên ngoài (equip_runtime), chủ sở hữu tự tick.
var _owned: Array[bool] = []


func _ready() -> void:
	_runtimes.resize(SLOT_COUNT)
	_owned.resize(SLOT_COUNT)
	for slot: int in mini(starting_skills.size(), SLOT_COUNT):
		if starting_skills[slot] != null:
			equip_skill(slot, starting_skills[slot])
			if slot < starting_cast_modes.size():
				set_cast_mode(slot, starting_cast_modes[slot])


func _physics_process(delta: float) -> void:
	for slot: int in SLOT_COUNT:
		if _runtimes[slot] != null and _owned[slot]:
			_runtimes[slot].tick(delta)


func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT


func get_skill(slot: int) -> SkillDefinition:
	var runtime: SkillRuntime = get_runtime(slot)
	return runtime.definition if runtime != null else null


func get_runtime(slot: int) -> SkillRuntime:
	return _runtimes[slot] if is_valid_slot(slot) else null


## Luật trang bị bổ sung (vd. ClassManager: kỹ năng thuộc class đang dùng và đã học).
## Callable(definition: SkillDefinition) -> String: "" = cho phép, ngược lại là lý do từ chối.
func set_equip_validator(validator: Callable) -> void:
	_equip_validator = validator


## Lý do không thể trang bị ("" nếu được): dữ liệu, trùng ô, rồi luật của validator.
func get_equip_block_reason(slot: int, definition: SkillDefinition) -> String:
	if not is_valid_slot(slot):
		return "Ô không hợp lệ"
	if definition == null or not definition.is_valid():
		return "Kỹ năng không hợp lệ"
	for other: int in SLOT_COUNT:
		if other != slot and get_skill(other) != null and get_skill(other).skill_id == definition.skill_id:
			return "Kỹ năng đã ở ô khác"
	if _equip_validator.is_valid():
		return _equip_validator.call(definition)
	return ""


func can_equip(slot: int, definition: SkillDefinition) -> bool:
	return get_equip_block_reason(slot, definition).is_empty()


func equip_skill(slot: int, definition: SkillDefinition) -> bool:
	var reason: String = get_equip_block_reason(slot, definition)
	if not reason.is_empty():
		equip_rejected.emit(slot, definition, reason)
		return false
	_runtimes[slot] = SkillRuntime.new(definition, definition.default_cast_mode)
	_owned[slot] = true
	slot_changed.emit(slot, definition)
	return true


## Trang bị một SkillRuntime có sẵn (do chủ sở hữu bên ngoài giữ và tick, vd. ClassManager), nên cooldown,
## charges và cast mode đi theo runtime chứ không theo ô: gỡ rồi trang bị lại không làm mới charges.
func equip_runtime(slot: int, runtime: SkillRuntime) -> bool:
	var definition: SkillDefinition = runtime.definition if runtime != null else null
	var reason: String = get_equip_block_reason(slot, definition)
	if not reason.is_empty():
		equip_rejected.emit(slot, definition, reason)
		return false
	_runtimes[slot] = runtime
	_owned[slot] = false
	slot_changed.emit(slot, definition)
	return true


## Thay definition của ô đang có cùng skill_id (vd. sau khi lên level/tiến hóa), giữ charges/cooldown và cast mode.
func update_definition(slot: int, definition: SkillDefinition) -> bool:
	var runtime: SkillRuntime = get_runtime(slot)
	if runtime == null or definition == null or not definition.is_valid() or definition.skill_id != runtime.definition.skill_id:
		return false
	runtime.set_definition(definition)
	slot_changed.emit(slot, definition)
	return true


## Ô đang chứa skill_id; -1 nếu không có.
func find_slot(skill_id: StringName) -> int:
	for slot: int in SLOT_COUNT:
		if get_skill(slot) != null and get_skill(slot).skill_id == skill_id:
			return slot
	return -1


func unequip_skill(slot: int) -> void:
	if not is_valid_slot(slot) or _runtimes[slot] == null:
		return
	_runtimes[slot] = null
	_owned[slot] = false
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
