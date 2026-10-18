class_name InteractionPrompt
extends PanelContainer
## Lời nhắc "[E] Đọc — Bảng thông báo". Ẩn khi không có mục tiêu.
## Chỉ đọc public API của Interactable; phím lấy từ Input Map action `interact`.

const ACTION: StringName = &"interact"

@onready var _label: Label = $Label


func _ready() -> void:
	hide()


func show_target(target: Interactable) -> void:
	if not is_instance_valid(target):
		hide()
		return
	_label.text = "[%s] %s — %s" % [_get_key_text(), target.get_interaction_prompt(), target.get_interaction_name()]
	show()


func _get_key_text() -> String:
	for event: InputEvent in InputMap.action_get_events(ACTION):
		var key: InputEventKey = event as InputEventKey
		if key == null:
			continue
		if key.physical_keycode != KEY_NONE:
			return key.as_text_physical_keycode()
		return key.as_text_keycode()
	return "?"
