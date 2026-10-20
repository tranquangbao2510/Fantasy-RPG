class_name SkillBar
extends VBoxContainer
## Skill HUD: đúng 4 ô theo SkillLoadout, thông báo ngắn khi bị từ chối.
## Không tự tính cooldown: đọc SkillRuntime / SkillCastingController mỗi frame và nghe signal.
## Nút cast mode trên mỗi ô là công cụ thử nghiệm (gọi SkillLoadout.cycle_cast_mode).

const SLOT_SCENE: PackedScene = preload("res://ui/skills/skill_slot_view.tscn")

@export var message_time: float = 1.5

var _loadout: SkillLoadout
var _caster: SkillCastingController
var _views: Array[SkillSlotView] = []
var _message_left: float = 0.0

@onready var _message_label: Label = %MessageLabel
@onready var _slots: HBoxContainer = %Slots


func _ready() -> void:
	_message_label.text = ""
	for slot: int in SkillLoadout.SLOT_COUNT:
		var view: SkillSlotView = SLOT_SCENE.instantiate()
		_slots.add_child(view)
		view.setup(slot, InputHint.action_text(SkillCastingController.SLOT_ACTIONS[slot]))
		view.mode_button_pressed.connect(_on_mode_button_pressed)
		_views.append(view)


func bind(loadout: SkillLoadout, caster: SkillCastingController) -> void:
	_loadout = loadout
	_caster = caster
	loadout.slot_changed.connect(_on_slot_changed)
	loadout.cast_mode_changed.connect(_on_cast_mode_changed)
	caster.cast_rejected.connect(_on_cast_rejected)
	for slot: int in SkillLoadout.SLOT_COUNT:
		_on_slot_changed(slot, loadout.get_skill(slot))


func get_slot_view(slot: int) -> SkillSlotView:
	return _views[slot]


func get_message() -> String:
	return _message_label.text


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message_label.text = ""
	if _loadout == null:
		return
	var active_slot: int = _caster.get_active_slot()
	for slot: int in SkillLoadout.SLOT_COUNT:
		var progress: float = _caster.get_cast_progress() if slot == active_slot else -1.0
		var runtime: SkillRuntime = _loadout.get_runtime(slot)
		var mana_ok: bool = runtime == null or _caster.has_mana_for(runtime.definition)
		_views[slot].refresh(runtime, progress, slot == active_slot and _caster.is_targeting(), mana_ok)


func _on_slot_changed(slot: int, definition: SkillDefinition) -> void:
	_views[slot].set_skill(definition)
	if definition != null:
		_views[slot].set_cast_mode(_loadout.get_cast_mode(slot))


func _on_cast_mode_changed(slot: int, mode: SkillDefinition.CastMode) -> void:
	_views[slot].set_cast_mode(mode)


func _on_mode_button_pressed(slot: int) -> void:
	if _loadout != null:
		_loadout.cycle_cast_mode(slot)


func _on_cast_rejected(slot: int, reason: String) -> void:
	_message_label.text = "[%s] %s" % [InputHint.action_text(SkillCastingController.SLOT_ACTIONS[slot]), reason]
	_message_left = message_time
