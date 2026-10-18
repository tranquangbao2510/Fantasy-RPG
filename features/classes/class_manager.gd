class_name ClassManager
extends Node
## Component quản lý class của một nhân vật (gắn vào Player; không phải Autoload).
## Giữ runtime state theo class (ClassProgress): mastery, kỹ năng đã học/level/nhánh, passive, loadout đã lưu.
## Một thời điểm chỉ có một class đang dùng. Nối luật class vào SkillLoadout / WeaponEquipment qua validator,
## áp passive qua PassiveController. Không xử lý input, không biết UI.
##
## Đổi class chỉ được phép trong một "phiên đổi class" do điểm hợp lệ (ClassTrainingStation) mở:
## phiên kết thúc khi đóng giao diện (close_switch_session), rời khỏi phạm vi, station bị xóa hoặc chủ thể chết.
## Quy tắc prototype khi đổi class: hủy ngắm/vận sức/combo, gỡ kỹ năng class cũ, khôi phục loadout đã lưu của
## class mới với runtime mới (charges đầy, cooldown không được bảo toàn), gỡ vũ khí không hợp lệ (không cấp vũ khí mới).

signal class_unlocked(class_id: StringName)
signal class_switched(previous_id: StringName, class_id: StringName)
signal mastery_changed(class_id: StringName, level: int, experience: int)
signal skill_learned(class_id: StringName, skill_id: StringName)
signal skill_level_changed(class_id: StringName, skill_id: StringName, level: int)
signal skill_evolved(class_id: StringName, skill_id: StringName, branch_id: StringName)
signal passives_changed(class_id: StringName)
signal switch_session_started(station: Node2D)
signal switch_session_ended
## Phát sau mọi thay đổi ở trên (UI dùng để làm mới).
signal progression_changed

## Phiên bản cấu trúc to_dict() (chuẩn bị cho Save/Load sau này).
const STATE_VERSION: int = 1

## Các class nhân vật này có thể có (prototype: khai báo trực tiếp, chưa có database class).
@export var classes: Array[ClassDefinition] = []
## Class được mở khóa và dùng ngay từ đầu.
@export var starting_class: ClassDefinition
@export var mastery_curve: LevelCurve
## Số ô passive bổ sung (thông số prototype, chưa phải quyết định gameplay).
@export var additional_passive_limit: int = 2
@export var health: HealthComponent
@export var loadout: SkillLoadout
@export var caster: SkillCastingController
@export var equipment: WeaponEquipment
@export var attack: BasicAttackController
@export var passives: PassiveController

var _definitions: Dictionary[StringName, ClassDefinition] = {}
var _progress: Dictionary[StringName, ClassProgress] = {}
var _current_id: StringName = &""
var _session_station: Node2D
var _session_range: float = 0.0

@onready var _actor: Node2D = get_parent() as Node2D


## ClassManager con trực tiếp của actor (vd. Player); null nếu không có.
static func find_in(actor: Node) -> ClassManager:
	if actor == null:
		return null
	for child: Node in actor.get_children():
		if child is ClassManager:
			return child as ClassManager
	return null


func _ready() -> void:
	if mastery_curve == null or not mastery_curve.is_valid():
		push_warning("[ClassManager] mastery_curve không hợp lệ; mastery giữ level 1.")
		mastery_curve = LevelCurve.new()
	for definition: ClassDefinition in classes:
		_register(definition)
	if loadout != null:
		loadout.set_equip_validator(_get_skill_block_reason)
		loadout.cast_mode_changed.connect(_on_cast_mode_changed)
	if equipment != null:
		equipment.set_equip_validator(_get_weapon_block_reason)
	if health != null:
		health.died.connect(close_switch_session)
	if starting_class != null and _definitions.get(starting_class.class_id) == starting_class:
		unlock_class(starting_class.class_id)
		_activate(starting_class.class_id)


func _physics_process(_delta: float) -> void:
	if _session_station != null and not _is_session_valid():
		close_switch_session()


# --- Class ---------------------------------------------------------------------------------------

func get_current_class() -> ClassDefinition:
	return _definitions.get(_current_id)


func get_current_class_id() -> StringName:
	return _current_id


func get_class_definition(class_id: StringName) -> ClassDefinition:
	return _definitions.get(class_id)


## Mọi class đã đăng ký (theo thứ tự export).
func get_class_ids() -> Array[StringName]:
	return Array(_definitions.keys(), TYPE_STRING_NAME, &"", null)


func is_class_unlocked(class_id: StringName) -> bool:
	return _progress.has(class_id)


func get_unlocked_class_ids() -> Array[StringName]:
	return Array(_progress.keys(), TYPE_STRING_NAME, &"", null)


## Mở khóa class (API chung cho NPC / quest / khám phá sau này). Trả về false nếu không tồn tại hoặc đã mở.
## Kỹ năng trong starting_skills được học sẵn và xếp vào loadout mặc định.
func unlock_class(class_id: StringName) -> bool:
	var definition: ClassDefinition = get_class_definition(class_id)
	if definition == null or is_class_unlocked(class_id):
		return false
	var progress: ClassProgress = ClassProgress.new(class_id, mastery_curve)
	for slot: int in definition.starting_skills.size():
		var skill: SkillDefinition = definition.starting_skills[slot]
		progress.skills[skill.skill_id] = SkillProgress.new(skill.skill_id, skill.default_cast_mode)
		progress.loadout[slot] = skill.skill_id
	progress.mastery.changed.connect(_on_mastery_changed.bind(class_id))
	_progress[class_id] = progress
	class_unlocked.emit(class_id)
	progression_changed.emit()
	return true


## Lý do không thể đổi sang class ("" nếu được).
func get_switch_block_reason(class_id: StringName) -> String:
	if get_class_definition(class_id) == null:
		return "Class không tồn tại"
	if not is_class_unlocked(class_id):
		return "Class chưa mở khóa"
	if class_id == _current_id:
		return "Đang dùng class này"
	if _is_actor_dead():
		return "Đã bị hạ gục"
	if not _is_session_valid():
		return "Chỉ đổi class tại trạm huấn luyện"
	return ""


func can_switch_class(class_id: StringName) -> bool:
	return get_switch_block_reason(class_id).is_empty()


func switch_class(class_id: StringName) -> bool:
	if not can_switch_class(class_id):
		return false
	_activate(class_id)
	return true


# --- Phiên đổi class -----------------------------------------------------------------------------

## Mở phiên đổi class từ một điểm hợp lệ; phiên tự kết thúc khi actor cách station quá max_distance.
func open_switch_session(station: Node2D, max_distance: float) -> bool:
	if station == null or _is_actor_dead():
		return false
	if station == _session_station:
		return true
	close_switch_session()
	_session_station = station
	_session_range = max_distance
	if not _is_session_valid():
		_session_station = null
		return false
	switch_session_started.emit(station)
	progression_changed.emit()
	return true


func close_switch_session() -> void:
	if _session_station == null:
		return
	_session_station = null
	switch_session_ended.emit()
	progression_changed.emit()


func has_switch_session() -> bool:
	return _is_session_valid()


func get_switch_station() -> Node2D:
	return _session_station if _is_session_valid() else null


# --- Mastery -------------------------------------------------------------------------------------

## Mastery của class đã mở khóa; null nếu chưa mở khóa.
func get_mastery(class_id: StringName) -> LevelProgress:
	var progress: ClassProgress = _progress.get(class_id)
	return progress.mastery if progress != null else null


## Cộng mastery EXP cho đúng một class (hiện chỉ dùng cho debug). Class chưa mở khóa bị từ chối.
func add_mastery_exp(class_id: StringName, amount: int) -> bool:
	var mastery: LevelProgress = get_mastery(class_id)
	if mastery == null or amount <= 0:
		return false
	mastery.add_exp(amount)
	return true


# --- Kỹ năng -------------------------------------------------------------------------------------

func is_skill_learned(class_id: StringName, skill_id: StringName) -> bool:
	return _get_skill_progress(class_id, skill_id) != null


## Học kỹ năng thuộc class đã mở khóa. Điều kiện học thật chưa được thiết kế (hiện dùng qua debug).
func learn_skill(class_id: StringName, skill_id: StringName) -> bool:
	var progress: ClassProgress = _progress.get(class_id)
	var definition: ClassDefinition = get_class_definition(class_id)
	if progress == null or definition == null or progress.skills.has(skill_id):
		return false
	var skill: SkillDefinition = definition.get_skill(skill_id)
	if skill == null:
		return false
	progress.skills[skill_id] = SkillProgress.new(skill_id, skill.default_cast_mode)
	skill_learned.emit(class_id, skill_id)
	progression_changed.emit()
	return true


## Level kỹ năng đã học; 0 nếu chưa học.
func get_skill_level(class_id: StringName, skill_id: StringName) -> int:
	var skill_progress: SkillProgress = _get_skill_progress(class_id, skill_id)
	return skill_progress.level if skill_progress != null else 0


func can_level_up_skill(class_id: StringName, skill_id: StringName) -> bool:
	var skill_progress: SkillProgress = _get_skill_progress(class_id, skill_id)
	return skill_progress != null and skill_progress.level < _get_base_skill(class_id, skill_id).max_level


## Tăng 1 level (không vượt max_level của SkillDefinition). Chưa có tài nguyên nâng cấp (debug).
func level_up_skill(class_id: StringName, skill_id: StringName) -> bool:
	if not can_level_up_skill(class_id, skill_id):
		return false
	var skill_progress: SkillProgress = _get_skill_progress(class_id, skill_id)
	skill_progress.level += 1
	_refresh_equipped_skill(class_id, skill_id)
	skill_level_changed.emit(class_id, skill_id, skill_progress.level)
	progression_changed.emit()
	return true


## Nhánh tiến hóa đã chọn (&"" = chưa tiến hóa).
func get_skill_branch(class_id: StringName, skill_id: StringName) -> StringName:
	var skill_progress: SkillProgress = _get_skill_progress(class_id, skill_id)
	return skill_progress.branch_id if skill_progress != null else &""


## Chọn nhánh tiến hóa (&"" = bỏ tiến hóa). Quy tắc đổi/reset nhánh chưa chốt: hiện chỉ gọi từ công cụ debug.
func select_evolution_branch(class_id: StringName, skill_id: StringName, branch_id: StringName) -> bool:
	var skill_progress: SkillProgress = _get_skill_progress(class_id, skill_id)
	if skill_progress == null or skill_progress.branch_id == branch_id:
		return false
	if branch_id != &"" and _get_base_skill(class_id, skill_id).get_evolution_branch(branch_id) == null:
		return false
	skill_progress.branch_id = branch_id
	_refresh_equipped_skill(class_id, skill_id)
	skill_evolved.emit(class_id, skill_id, branch_id)
	progression_changed.emit()
	return true


## Cast mode đã chọn cho kỹ năng (lưu theo kỹ năng, giữ khi gỡ khỏi ô); default nếu chưa học.
func get_skill_cast_mode(class_id: StringName, skill_id: StringName) -> SkillDefinition.CastMode:
	var skill_progress: SkillProgress = _get_skill_progress(class_id, skill_id)
	if skill_progress != null:
		return skill_progress.cast_mode
	var skill: SkillDefinition = _get_base_skill(class_id, skill_id)
	return skill.default_cast_mode if skill != null else SkillDefinition.CastMode.NORMAL


## Definition hiệu lực (bản sao runtime theo level, nhánh, passive của class đang dùng); null nếu chưa học.
func get_effective_skill(class_id: StringName, skill_id: StringName) -> SkillDefinition:
	if not is_skill_learned(class_id, skill_id):
		return null
	return _build_skill(class_id, skill_id)


## Trang bị kỹ năng của class đang dùng vào ô; luật class (đã học, thuộc class) do validator của SkillLoadout kiểm tra.
func equip_skill(slot: int, skill_id: StringName) -> bool:
	var definition: ClassDefinition = get_current_class()
	if definition == null or loadout == null:
		return false
	var skill: SkillDefinition = definition.get_skill(skill_id)
	if skill == null:
		return false
	if is_skill_learned(_current_id, skill_id):
		skill = _build_skill(_current_id, skill_id)
	if not _equip_into_loadout(slot, skill):
		return false
	_progress[_current_id].loadout[slot] = skill_id
	progression_changed.emit()
	return true


func unequip_skill(slot: int) -> void:
	if loadout == null or not loadout.is_valid_slot(slot) or _current_id == &"":
		return
	loadout.unequip_skill(slot)
	_progress[_current_id].loadout[slot] = &""
	progression_changed.emit()


## skill_id theo 4 ô đã lưu của class (&"" = trống).
func get_saved_loadout(class_id: StringName) -> Array[StringName]:
	var progress: ClassProgress = _progress.get(class_id)
	return progress.loadout.duplicate() if progress != null else []


# --- Passive -------------------------------------------------------------------------------------

func get_signature_passive(class_id: StringName) -> PassiveDefinition:
	var definition: ClassDefinition = get_class_definition(class_id)
	return definition.signature_passive if definition != null else null


func is_passive_unlocked(class_id: StringName, passive_id: StringName) -> bool:
	var progress: ClassProgress = _progress.get(class_id)
	return progress != null and progress.unlocked_passive_ids.has(passive_id)


## Mở khóa passive bổ sung của class (điều kiện thật chưa thiết kế; hiện dùng qua debug).
func unlock_passive(class_id: StringName, passive_id: StringName) -> bool:
	var progress: ClassProgress = _progress.get(class_id)
	if progress == null or progress.unlocked_passive_ids.has(passive_id):
		return false
	if get_class_definition(class_id).get_additional_passive(passive_id) == null:
		return false
	progress.unlocked_passive_ids.append(passive_id)
	passives_changed.emit(class_id)
	progression_changed.emit()
	return true


func get_equipped_passive_ids(class_id: StringName) -> Array[StringName]:
	var progress: ClassProgress = _progress.get(class_id)
	return progress.equipped_passive_ids.duplicate() if progress != null else []


## Lý do không thể trang bị passive bổ sung ("" nếu được). Cấu hình lưu riêng theo class.
func get_passive_equip_block_reason(class_id: StringName, passive_id: StringName) -> String:
	var progress: ClassProgress = _progress.get(class_id)
	if progress == null:
		return "Class chưa mở khóa"
	var signature: PassiveDefinition = get_signature_passive(class_id)
	if signature != null and signature.passive_id == passive_id:
		return "Signature passive luôn hoạt động"
	if get_class_definition(class_id).get_additional_passive(passive_id) == null:
		return "Passive không thuộc class"
	if not progress.unlocked_passive_ids.has(passive_id):
		return "Passive chưa mở khóa"
	if progress.equipped_passive_ids.has(passive_id):
		return "Đã trang bị"
	if progress.equipped_passive_ids.size() >= additional_passive_limit:
		return "Hết ô passive (%d)" % additional_passive_limit
	return ""


func equip_passive(class_id: StringName, passive_id: StringName) -> bool:
	if not get_passive_equip_block_reason(class_id, passive_id).is_empty():
		return false
	_progress[class_id].equipped_passive_ids.append(passive_id)
	_on_passive_config_changed(class_id)
	return true


## Gỡ passive bổ sung. Signature passive không thể gỡ.
func unequip_passive(class_id: StringName, passive_id: StringName) -> bool:
	var progress: ClassProgress = _progress.get(class_id)
	if progress == null or not progress.equipped_passive_ids.has(passive_id):
		return false
	progress.equipped_passive_ids.erase(passive_id)
	_on_passive_config_changed(class_id)
	return true


# --- Save prep -----------------------------------------------------------------------------------

## Dữ liệu thuần (ID + số) của progression class. Chưa có Save/Load; dùng để kiểm tra cấu trúc.
func to_dict() -> Dictionary:
	var class_data: Dictionary = {}
	for id: StringName in _progress:
		class_data[String(id)] = _progress[id].to_dict()
	return {"version": STATE_VERSION, "active_class": String(_current_id), "classes": class_data}


# --- Nội bộ --------------------------------------------------------------------------------------

func _register(definition: ClassDefinition) -> void:
	if definition == null:
		return
	var errors: Array[String] = definition.get_validation_errors()
	if not errors.is_empty():
		push_warning("[ClassManager] Bỏ qua class không hợp lệ %s: %s" % [definition.resource_path, ", ".join(errors)])
		return
	if _definitions.has(definition.class_id):
		push_warning("[ClassManager] class_id trùng: %s" % definition.class_id)
		return
	_definitions[definition.class_id] = definition


func _activate(class_id: StringName) -> void:
	var previous: StringName = _current_id
	if caster != null:
		caster.cancel_all()
	if attack != null:
		attack.cancel()
	if loadout != null:
		for slot: int in SkillLoadout.SLOT_COUNT:
			loadout.unequip_skill(slot)
	_current_id = class_id
	_apply_passives()
	_restore_loadout()
	_validate_weapon()
	class_switched.emit(previous, class_id)
	progression_changed.emit()


func _restore_loadout() -> void:
	if loadout == null:
		return
	var progress: ClassProgress = _progress[_current_id]
	for slot: int in SkillLoadout.SLOT_COUNT:
		var skill_id: StringName = progress.loadout[slot]
		if skill_id == &"":
			continue
		if not is_skill_learned(_current_id, skill_id) or not _equip_into_loadout(slot, _build_skill(_current_id, skill_id)):
			progress.loadout[slot] = &""


func _equip_into_loadout(slot: int, skill: SkillDefinition) -> bool:
	if not loadout.equip_skill(slot, skill):
		return false
	var skill_progress: SkillProgress = _get_skill_progress(_current_id, skill.skill_id)
	if skill_progress != null:
		loadout.set_cast_mode(slot, skill_progress.cast_mode)
	return true


func _validate_weapon() -> void:
	if equipment == null or equipment.get_weapon() == null:
		return
	if not equipment.can_equip(equipment.get_weapon()):
		if attack != null:
			attack.cancel()
		equipment.unequip_weapon()


func _apply_passives() -> void:
	if passives == null:
		return
	var active: Array[PassiveDefinition] = []
	var definition: ClassDefinition = get_current_class()
	if definition != null:
		active.append(definition.signature_passive)
		for passive_id: StringName in _progress[_current_id].equipped_passive_ids:
			active.append(definition.get_additional_passive(passive_id))
	passives.set_active_passives(active)
	_refresh_all_equipped_skills()


func _on_passive_config_changed(class_id: StringName) -> void:
	if class_id == _current_id:
		_apply_passives()
	passives_changed.emit(class_id)
	progression_changed.emit()


func _build_skill(class_id: StringName, skill_id: StringName) -> SkillDefinition:
	var base: SkillDefinition = _get_base_skill(class_id, skill_id)
	var skill_progress: SkillProgress = _get_skill_progress(class_id, skill_id)
	var power: float = passives.get_skill_power_percent() if passives != null and class_id == _current_id else 0.0
	var variant: SkillDefinition = base.create_variant(skill_progress.level, skill_progress.branch_id, power)
	if not variant.is_valid():
		push_warning("[ClassManager] Biến thể kỹ năng %s không hợp lệ; dùng definition gốc." % skill_id)
		return base
	return variant


func _refresh_equipped_skill(class_id: StringName, skill_id: StringName) -> void:
	if class_id != _current_id or loadout == null:
		return
	var slot: int = loadout.find_slot(skill_id)
	if slot >= 0:
		loadout.update_definition(slot, _build_skill(class_id, skill_id))


func _refresh_all_equipped_skills() -> void:
	if loadout == null:
		return
	for slot: int in SkillLoadout.SLOT_COUNT:
		var skill: SkillDefinition = loadout.get_skill(slot)
		if skill != null:
			loadout.update_definition(slot, _build_skill(_current_id, skill.skill_id))


func _get_base_skill(class_id: StringName, skill_id: StringName) -> SkillDefinition:
	var definition: ClassDefinition = get_class_definition(class_id)
	return definition.get_skill(skill_id) if definition != null else null


func _get_skill_progress(class_id: StringName, skill_id: StringName) -> SkillProgress:
	var progress: ClassProgress = _progress.get(class_id)
	return progress.skills.get(skill_id) if progress != null else null


func _get_skill_block_reason(skill: SkillDefinition) -> String:
	var definition: ClassDefinition = get_current_class()
	if definition == null:
		return "Chưa có class"
	if not definition.has_skill(skill.skill_id):
		return "Không thuộc class %s" % definition.display_name
	if not is_skill_learned(_current_id, skill.skill_id):
		return "Chưa học kỹ năng"
	return ""


func _get_weapon_block_reason(weapon: WeaponDefinition) -> String:
	var definition: ClassDefinition = get_current_class()
	if definition != null and not definition.allows_weapon_type(weapon.weapon_type_id):
		return "%s không dùng được loại vũ khí %s" % [definition.display_name, weapon.weapon_type_id]
	return ""


func _is_actor_dead() -> bool:
	return health != null and health.is_dead()


func _is_session_valid() -> bool:
	if _session_station == null or not is_instance_valid(_session_station) or _is_actor_dead():
		return false
	return _actor == null or _actor.global_position.distance_to(_session_station.global_position) <= _session_range


func _on_mastery_changed(level: int, experience: int, class_id: StringName) -> void:
	mastery_changed.emit(class_id, level, experience)
	progression_changed.emit()


func _on_cast_mode_changed(slot: int, mode: SkillDefinition.CastMode) -> void:
	var skill: SkillDefinition = loadout.get_skill(slot)
	var skill_progress: SkillProgress = _get_skill_progress(_current_id, skill.skill_id) if skill != null else null
	if skill_progress != null:
		skill_progress.cast_mode = mode
