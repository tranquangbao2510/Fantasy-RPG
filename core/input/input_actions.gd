class_name InputActions
extends RefCounted
## Danh mục hành động người chơi đổi phím được (TASK M6): nhóm + tên hiển thị (màn Hướng dẫn phím, Cài đặt → Điều khiển),
## tên hiển thị của một phím / nút chuột, chuyển sự kiện phím ↔ chuỗi để lưu trong user://settings.cfg.
## Phím đọc từ InputMap lúc chạy (không ghi cứng) — đổi phím thì mọi chỗ hiển thị đổi theo.
## Không đổi được: `pause_menu` (Esc — menu tạm dừng / đóng cửa sổ), các action `ui_*` của Godot, phím debug (DebugKeys).
## Tay cầm: chưa làm — chuỗi lưu có tiền tố loại sự kiện ("key:", "mouse:") nên thêm "joy:" sau này không đổi định dạng.

## Action cố định của Esc.
const PAUSE_ACTION: StringName = &"pause_menu"
## Số phím tối đa cho một action trong Cài đặt (phím chính + phím phụ, vd. W / ↑).
const MAX_BINDINGS: int = 2

## [tên nhóm, [action...]] theo thứ tự hiển thị.
const GROUPS: Array = [
	["Di chuyển", [&"move_up", &"move_down", &"move_left", &"move_right", &"sprint", &"dodge", &"camera_zoom_in", &"camera_zoom_out"]],
	["Chiến đấu", [&"basic_attack"]],
	["Kỹ năng", [&"skill_slot_1", &"skill_slot_2", &"skill_slot_3", &"skill_slot_4", &"skill_cancel"]],
	["Đồ đạc", [&"inventory_toggle", &"craft_toggle", &"item_use"]],
	["Tương tác", [&"interact"]],
]

const NAMES: Dictionary[StringName, String] = {
	&"move_up": "Đi lên",
	&"move_down": "Đi xuống",
	&"move_left": "Sang trái",
	&"move_right": "Sang phải",
	&"sprint": "Chạy (giữ)",
	&"dodge": "Né",
	&"camera_zoom_in": "Phóng to",
	&"camera_zoom_out": "Thu nhỏ",
	&"basic_attack": "Đánh thường",
	&"skill_slot_1": "Kỹ năng 1",
	&"skill_slot_2": "Kỹ năng 2",
	&"skill_slot_3": "Kỹ năng 3",
	&"skill_slot_4": "Kỹ năng 4",
	&"skill_cancel": "Hủy ngắm / vận sức",
	&"inventory_toggle": "Túi đồ",
	&"craft_toggle": "Chế tạo",
	&"item_use": "Dùng / trang bị (trong túi đồ)",
	&"interact": "Tương tác / khai thác / thu hoạch",
	&"pause_menu": "Menu tạm dừng / đóng cửa sổ",
}


## Mọi action đổi phím được (theo thứ tự nhóm).
static func remappable() -> Array[StringName]:
	var result: Array[StringName] = []
	for group: Array in GROUPS:
		for action: StringName in group[1]:
			result.append(action)
	return result


static func is_remappable(action: StringName) -> bool:
	return remappable().has(action)


static func display_name(action: StringName) -> String:
	return NAMES.get(action, String(action))


## Phím không gán được cho hành động nào (Esc).
static func is_reserved(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	return key != null and (key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE)


## Sự kiện dùng làm phím được không (phím bàn phím / nút chuột).
static func is_bindable(event: InputEvent) -> bool:
	return (event is InputEventKey or event is InputEventMouseButton) and not is_reserved(event)


## Tên hiển thị của một phím / nút chuột ("W", "Shift", "Chuột trái").
static func event_text(event: InputEvent) -> String:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if is_reserved(key):
			return "Esc"
		return key.as_text_physical_keycode() if key.physical_keycode != KEY_NONE else key.as_text_keycode()
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null:
		match mouse.button_index:
			MOUSE_BUTTON_LEFT:
				return "Chuột trái"
			MOUSE_BUTTON_RIGHT:
				return "Chuột phải"
			MOUSE_BUTTON_MIDDLE:
				return "Chuột giữa"
			MOUSE_BUTTON_WHEEL_UP:
				return "Lăn chuột lên"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Lăn chuột xuống"
		return "Chuột %d" % mouse.button_index
	return "?"


## Phím hiện tại của action (theo InputMap), nối bằng " / "; "—" nếu chưa gán.
static func action_keys_text(action: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for event: InputEvent in bindable_events(action):
		parts.append(event_text(event))
	return " / ".join(parts) if not parts.is_empty() else "—"


## Các sự kiện phím / chuột hiện gán cho action (bỏ loại khác).
static func bindable_events(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	if not InputMap.has_action(action):
		return result
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			result.append(event)
	return result


## Phím mặc định của action (project.godot).
static func default_events(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	var setting: Variant = ProjectSettings.get_setting("input/%s" % action)
	if setting is Dictionary:
		for event: Variant in (setting as Dictionary).get("events", []):
			if event is InputEventKey or event is InputEventMouseButton:
				result.append((event as InputEvent).duplicate() as InputEvent)
	return result


## Hai sự kiện cùng một phím / nút chuột (bỏ qua trạng thái nhấn, modifier).
static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka: InputEventKey = a as InputEventKey
		var kb: InputEventKey = b as InputEventKey
		return _key_code(ka) == _key_code(kb)
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


## "key:<physical keycode>" / "mouse:<button>"; "" nếu không lưu được.
static func event_to_string(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % _key_code(event as InputEventKey)
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	return ""


## Ngược lại của event_to_string; null nếu chuỗi lỗi.
static func event_from_string(text: String) -> InputEvent:
	var parts: PackedStringArray = text.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var code: int = parts[1].to_int()
	match parts[0]:
		"key":
			if code <= 0:
				return null
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = code as Key
			return key
		"mouse":
			if code <= 0:
				return null
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = code as MouseButton
			return mouse
	return null


## Chuẩn hóa sự kiện người chơi vừa nhấn thành sự kiện gán phím (physical keycode, không modifier).
static func normalized(event: InputEvent) -> InputEvent:
	return event_from_string(event_to_string(event))


static func _key_code(key: InputEventKey) -> int:
	return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
