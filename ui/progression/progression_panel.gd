class_name ProgressionPanel
extends PanelContainer
## Bảng Class / Progression thử nghiệm (không phải UI chính thức). Đọc state qua public API của ClassManager /
## CharacterLevel và làm mới khi `progression_changed`. Nút [Debug] gọi API debug (EXP, học/nâng/tiến hóa kỹ năng,
## mở khóa passive); đổi class / mở khóa class chỉ hiện khi đang có phiên tại trạm huấn luyện — luật vẫn nằm ở
## ClassManager / ClassTrainingStation, UI không tự cho phép.
## Mở/đóng: action `debug_progression` (P, chỉ bản debug — DebugKeys); đóng thêm bằng `skill_cancel` (chuột phải), Esc
## (`ui_cancel`) hoặc nút Đóng.

signal opened
signal closed

const TOGGLE_ACTION: StringName = &"debug_progression"
const CLOSE_ACTION: StringName = &"skill_cancel"
const DEBUG_EXP: int = 40
const DEBUG_MASTERY_EXP: int = 30
const MODE_NAMES: Array[String] = ["Normal", "Quick", "Instant"]
const DEBUG_COLOR: Color = Color(1, 0.75, 0.45)
const HEADER_COLOR: Color = Color(0.6, 0.85, 1)

var _manager: ClassManager
var _character: CharacterLevel
var _opened_by_station: bool = false
var _dirty: bool = false

@onready var _content: VBoxContainer = %Content
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	hide()
	_close_button.pressed.connect(close)


func bind(manager: ClassManager, character: CharacterLevel) -> void:
	_manager = manager
	_character = character
	manager.progression_changed.connect(_queue_refresh)
	manager.switch_session_started.connect(_on_session_started)
	manager.switch_session_ended.connect(_on_session_ended)
	character.exp_changed.connect(func(_level: int, _experience: int) -> void: _queue_refresh())


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	show()
	_rebuild()
	opened.emit()


## Đóng bảng; nếu đang có phiên đổi class thì kết thúc phiên (mất quyền đổi class).
func close() -> void:
	if not visible:
		return
	hide()
	_opened_by_station = false
	if _manager != null:
		_manager.close_switch_session()
	closed.emit()


## Text hiện tại của bảng (dùng cho kiểm thử / debug).
func get_text_dump() -> String:
	var lines: Array[String] = []
	_collect_text(_content, lines)
	return "\n".join(lines)


## Nút có text bắt đầu bằng prefix (dùng cho kiểm thử / debug); null nếu không có.
func find_button(prefix: String) -> Button:
	return _find_button(_content, prefix)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION) and DebugKeys.enabled():
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif visible and (event.is_action_pressed(CLOSE_ACTION) or event.is_action_pressed(&"ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _dirty and visible:
		_rebuild()


func _queue_refresh() -> void:
	_dirty = true


func _on_session_started(_station: Node2D) -> void:
	_opened_by_station = true
	open()
	_queue_refresh()


func _on_session_ended() -> void:
	if _opened_by_station and visible:
		close()
	_queue_refresh()


func _rebuild() -> void:
	_dirty = false
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if _manager == null:
		return
	var class_id: StringName = _manager.get_current_class_id()
	var current: ClassDefinition = _manager.get_current_class()

	_add_header("Nhân vật")
	var row: HBoxContainer = _add_row()
	var exp_text: String = "MAX" if _character.get_exp_to_next() == 0 else "%d / %d" % [_character.get_exp(), _character.get_exp_to_next()]
	_add_label(row, "Character Lv %d · EXP %s" % [_character.get_level(), exp_text])
	_add_button(row, "[Debug] +%d EXP" % DEBUG_EXP, func() -> void: _character.add_exp(DEBUG_EXP), true)

	_add_header("Class")
	var unlocked: Array[String] = []
	for id: StringName in _manager.get_unlocked_class_ids():
		unlocked.append(_manager.get_class_definition(id).display_name)
	_add_label(_add_row(), "Đang dùng: %s · Đã mở khóa: %s" % [current.display_name if current != null else "—", ", ".join(unlocked)])
	_build_station_section()
	if current == null:
		return
	var mastery: LevelProgress = _manager.get_mastery(class_id)
	row = _add_row()
	var mastery_text: String = "MAX" if mastery.is_max_level() else "%d / %d" % [mastery.experience, mastery.get_exp_to_next()]
	_add_label(row, "Mastery %s: Lv %d · EXP %s" % [current.display_name, mastery.level, mastery_text])
	_add_button(row, "[Debug] +%d Mastery" % DEBUG_MASTERY_EXP, func() -> void: _manager.add_mastery_exp(class_id, DEBUG_MASTERY_EXP), true)

	_add_header("Passive")
	var signature: PassiveDefinition = current.signature_passive
	_add_label(_add_row(), "Signature (cố định): %s — %s" % [signature.display_name, signature.description])
	_add_label(_add_row(), "Passive bổ sung: %d / %d ô" % [_manager.get_equipped_passive_ids(class_id).size(), _manager.additional_passive_limit])
	for passive: PassiveDefinition in current.additional_passives:
		_build_passive_row(class_id, passive)

	_add_header("Kỹ năng (4 ô: %s)" % "/".join(SkillCastingController.SLOT_ACTIONS.map(
		func(action: StringName) -> String: return InputHint.action_text(action))))
	for skill: SkillDefinition in current.skills:
		_build_skill_rows(class_id, skill)


func _build_station_section() -> void:
	var station: ClassTrainingStation = _manager.get_switch_station() as ClassTrainingStation
	if station == null:
		_add_label(_add_row(), "Đổi class: chỉ tại trạm huấn luyện.", Color(0.75, 0.75, 0.75))
		return
	var row: HBoxContainer = _add_row()
	_add_label(row, "Trạm huấn luyện:")
	for id: StringName in _manager.get_class_ids():
		var definition: ClassDefinition = _manager.get_class_definition(id)
		if _manager.is_class_unlocked(id):
			var button: Button = _add_button(row, "Chuyển sang %s" % definition.display_name, func() -> void: _manager.switch_class(id))
			button.disabled = not _manager.can_switch_class(id)
			button.tooltip_text = _manager.get_switch_block_reason(id)
		elif station.get_debug_unlockable_ids().has(id):
			_add_button(row, "[Debug] Mở khóa %s" % definition.display_name, func() -> void: station.debug_unlock_class(_manager, id), true)


func _build_passive_row(class_id: StringName, passive: PassiveDefinition) -> void:
	var row: HBoxContainer = _add_row()
	var equipped: bool = _manager.get_equipped_passive_ids(class_id).has(passive.passive_id)
	_add_label(row, "%s %s — %s" % ["●" if equipped else "○", passive.display_name, passive.description])
	if not _manager.is_passive_unlocked(class_id, passive.passive_id):
		_add_button(row, "[Debug] Mở khóa", func() -> void: _manager.unlock_passive(class_id, passive.passive_id), true)
	elif equipped:
		_add_button(row, "Gỡ", func() -> void: _manager.unequip_passive(class_id, passive.passive_id))
	else:
		var button: Button = _add_button(row, "Trang bị", func() -> void: _manager.equip_passive(class_id, passive.passive_id))
		var reason: String = _manager.get_passive_equip_block_reason(class_id, passive.passive_id)
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason


func _build_skill_rows(class_id: StringName, skill: SkillDefinition) -> void:
	var row: HBoxContainer = _add_row()
	var skill_id: StringName = skill.skill_id
	if not _manager.is_skill_learned(class_id, skill_id):
		_add_label(row, "%s — chưa học" % skill.display_name, Color(0.7, 0.7, 0.7))
		_add_button(row, "[Debug] Học", func() -> void: _manager.learn_skill(class_id, skill_id), true)
		return
	var branch_id: StringName = _manager.get_skill_branch(class_id, skill_id)
	var branch: SkillEvolutionBranch = skill.get_evolution_branch(branch_id)
	var effective: SkillDefinition = _manager.get_effective_skill(class_id, skill_id)
	var slot: int = _manager.loadout.find_slot(skill_id) if _manager.loadout != null else -1
	_add_label(row, "%s Lv %d/%d · %s · Nhánh: %s · %s %d" % [
		skill.display_name, _manager.get_skill_level(class_id, skill_id), skill.max_level,
		MODE_NAMES[_manager.get_skill_cast_mode(class_id, skill_id)],
		branch.display_name if branch != null else "—",
		"Hồi" if effective.effect_type == SkillDefinition.EffectType.HEAL else "Dmg", effective.effect_amount])
	if _manager.can_level_up_skill(class_id, skill_id):
		_add_button(row, "[Debug] +Lv", func() -> void: _manager.level_up_skill(class_id, skill_id), true)

	row = _add_row()
	_add_label(row, "    Ô:")
	for target_slot: int in SkillLoadout.SLOT_COUNT:
		var key: String = InputHint.action_text(SkillCastingController.SLOT_ACTIONS[target_slot])
		var button: Button = _add_button(row, key, func() -> void: _manager.equip_skill(target_slot, skill_id))
		button.disabled = target_slot == slot
	if slot >= 0:
		_add_button(row, "Gỡ", func() -> void: _manager.unequip_skill(slot))
	for evolution: SkillEvolutionBranch in skill.evolution_branches:
		var button: Button = _add_button(row, "[Debug] Nhánh %s" % evolution.display_name,
			func() -> void: _manager.select_evolution_branch(class_id, skill_id, evolution.branch_id), true)
		button.disabled = evolution.branch_id == branch_id
		button.tooltip_text = evolution.description


func _add_header(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", HEADER_COLOR)
	label.add_theme_font_size_override(&"font_size", 14)
	_content.add_child(label)


func _add_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)
	_content.add_child(row)
	return row


func _add_label(row: HBoxContainer, text: String, color: Color = Color.WHITE) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 120
	row.add_child(label)
	return label


func _add_button(row: HBoxContainer, text: String, action: Callable, is_debug: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 11)
	if is_debug:
		button.add_theme_color_override(&"font_color", DEBUG_COLOR)
	button.pressed.connect(action)
	row.add_child(button)
	return button


func _collect_text(node: Node, lines: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Label:
			lines.append((child as Label).text)
		elif child is Button:
			lines.append("[%s]" % (child as Button).text)
		_collect_text(child, lines)


func _find_button(node: Node, prefix: String) -> Button:
	for child: Node in node.get_children():
		var button: Button = child as Button
		if button != null and button.text.begins_with(prefix):
			return button
		var found: Button = _find_button(child, prefix)
		if found != null:
			return found
	return null
