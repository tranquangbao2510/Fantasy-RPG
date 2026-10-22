class_name InputHint
extends RefCounted
## Tên hiển thị của phím/nút đầu tiên gán cho một action trong Input Map (vd. "Q", "Chuột trái"). Đọc InputMap lúc gọi
## (TASK M6: đổi phím trong Cài đặt thì chỗ hiển thị gọi lại — nghe GameSettings.changed(&"controls")).


static func action_text(action: StringName) -> String:
	var events: Array[InputEvent] = InputActions.bindable_events(action)
	return InputActions.event_text(events[0]) if not events.is_empty() else "?"


## Mọi phím của action: "I / Tab".
static func all_text(action: StringName) -> String:
	return InputActions.action_keys_text(action)
