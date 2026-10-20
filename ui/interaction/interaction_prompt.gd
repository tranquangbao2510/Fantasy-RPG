class_name InteractionPrompt
extends PanelContainer
## Lời nhắc "[E] Đọc — Bảng thông báo". Ẩn khi không có mục tiêu.
## Chỉ đọc public API của Interactable; phím lấy từ Input Map action `interact`.
## Làm mới chữ mỗi frame khi đang hiện (TASK M3: lời nhắc đổi theo công cụ đang cầm — "Chặt" / "Cần rìu"; mục tiêu bị
## xóa thì ẩn).

const ACTION: StringName = &"interact"

var _target: Interactable

@onready var _label: Label = $Label


func _ready() -> void:
	hide()


func show_target(target: Interactable) -> void:
	_target = target if is_instance_valid(target) else null
	if _target == null:
		hide()
		return
	_update_text()
	show()


func get_text() -> String:
	return _label.text if visible else ""


func _process(_delta: float) -> void:
	if not visible:
		return
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		_target = null
		hide()
		return
	_update_text()


func _update_text() -> void:
	_label.text = "[%s] %s — %s" % [_get_key_text(), _target.get_interaction_prompt(), _target.get_interaction_name()]


func _get_key_text() -> String:
	for event: InputEvent in InputMap.action_get_events(ACTION):
		var key: InputEventKey = event as InputEventKey
		if key == null:
			continue
		if key.physical_keycode != KEY_NONE:
			return key.as_text_physical_keycode()
		return key.as_text_keycode()
	return "?"
