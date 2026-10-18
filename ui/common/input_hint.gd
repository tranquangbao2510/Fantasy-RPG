class_name InputHint
extends RefCounted
## Tên hiển thị của phím/nút đầu tiên gán cho một action trong Input Map (vd. "Q", "Chuột trái").


static func action_text(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.as_text_physical_keycode() if key.physical_keycode != KEY_NONE else key.as_text_keycode()
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse != null:
			match mouse.button_index:
				MOUSE_BUTTON_LEFT:
					return "Chuột trái"
				MOUSE_BUTTON_RIGHT:
					return "Chuột phải"
			return "Chuột %d" % mouse.button_index
	return "?"
