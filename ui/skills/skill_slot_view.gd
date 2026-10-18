class_name SkillSlotView
extends PanelContainer
## Một ô trên Skill Bar. Chỉ hiển thị giá trị do SkillRuntime / SkillCastingController cung cấp.

## Người dùng bấm nút đổi cast mode (công cụ thử nghiệm).
signal mode_button_pressed(slot: int)

const MODE_NAMES: Array[String] = ["Normal", "Quick", "Instant"]

var slot: int = -1

@onready var _key_label: Label = %KeyLabel
@onready var _name_label: Label = %NameLabel
@onready var _mode_button: Button = %ModeButton
@onready var _status_label: Label = %StatusLabel
@onready var _cast_bar: ProgressBar = %CastBar


func _ready() -> void:
	_mode_button.pressed.connect(func() -> void: mode_button_pressed.emit(slot))
	_cast_bar.hide()


func setup(p_slot: int, key_text: String) -> void:
	slot = p_slot
	_key_label.text = "[%s]" % key_text


func set_skill(definition: SkillDefinition) -> void:
	_name_label.text = definition.short_name if definition != null else "—"
	_mode_button.disabled = definition == null
	if definition == null:
		_mode_button.text = "—"
		_status_label.text = "Trống"


func set_cast_mode(mode: SkillDefinition.CastMode) -> void:
	_mode_button.text = MODE_NAMES[mode]


func get_mode_text() -> String:
	return _mode_button.text


func get_status_text() -> String:
	return _status_label.text


## Cập nhật trạng thái từ runtime. cast_progress < 0 = không vận sức. highlighted = đang ngắm ô này.
func refresh(runtime: SkillRuntime, cast_progress: float, highlighted: bool) -> void:
	if runtime == null:
		modulate = Color(1, 1, 1, 0.5)
		_cast_bar.hide()
		return
	var charges_text: String = ""
	if runtime.get_max_charges() > 1:
		charges_text = " · %d/%d" % [runtime.get_charges(), runtime.get_max_charges()]
	if runtime.can_cast():
		_status_label.text = "Sẵn sàng" + charges_text
	else:
		_status_label.text = "%.1fs%s" % [runtime.get_cooldown_remaining(), charges_text]
	_cast_bar.visible = cast_progress >= 0.0
	if cast_progress >= 0.0:
		_cast_bar.value = cast_progress
	if highlighted:
		modulate = Color(1, 1, 0.6)
	elif runtime.can_cast():
		modulate = Color.WHITE
	else:
		modulate = Color(0.6, 0.6, 0.6)
