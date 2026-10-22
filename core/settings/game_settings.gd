class_name GameSettings
extends RefCounted
## Cài đặt của người chơi (TASK M6), lưu ở `user://settings.cfg` — tách riêng khỏi save, không theo ô save. Đổi giá trị
## (set_value / bind / reset_bindings) thì áp dụng NGAY + ghi file + phát `changed`.
## Một instance dùng chung, nạp lười ở lần gọi get_instance() đầu tiên (màn hình tiêu đề / World / AppOverlay gọi lúc _ready)
## — không phải Autoload: chỉ là dữ liệu + hàm áp dụng lên AudioServer / DisplayServer / Engine / InputMap.
## - Âm thanh: âm lượng bus Master / Music / SFX (default_bus_layout.tres; chưa có âm thanh thật).
## - Hình ảnh: toàn màn hình, vsync, giới hạn FPS (0 = không giới hạn), hiện FPS (AppOverlay), ánh trăng ban đêm
##   (DayNightLighting đọc, kẹp trong [MOONLIGHT_MIN, MOONLIGHT_MAX] — chỉ đổi màu vẽ, không đổi luật tầm nhìn).
## - Gameplay: tự tạm dừng khi cửa sổ mất focus; hiện bảng gợi ý phím lần đầu chơi mới.
## - Điều khiển: phím của mọi action trong InputActions (tối đa MAX_BINDINGS / action); trùng phím → find_conflict + bind(swap).

signal changed(key: StringName)

## Đường dẫn file (test đổi sang file riêng).
static var config_path: String = "user://settings.cfg"
static var _instance: GameSettings

const BUSES: Dictionary[StringName, String] = {&"master_volume": "Master", &"music_volume": "Music", &"sfx_volume": "SFX"}
const FPS_LIMITS: Array[int] = [30, 60, 120, 0]
const MOONLIGHT_MIN: float = 0.10
const MOONLIGHT_MAX: float = 0.30
const DEFAULTS: Dictionary[StringName, Variant] = {
	&"master_volume": 1.0,
	&"music_volume": 0.8,
	&"sfx_volume": 1.0,
	&"fullscreen": false,
	&"vsync": true,
	&"fps_limit": 0,
	&"show_fps": false,
	&"moonlight": 0.16,
	&"pause_on_focus_loss": true,
	&"show_start_hints": true,
}
## Khóa → section trong settings.cfg.
const SECTIONS: Dictionary[StringName, String] = {
	&"master_volume": "audio", &"music_volume": "audio", &"sfx_volume": "audio",
	&"fullscreen": "display", &"vsync": "display", &"fps_limit": "display", &"show_fps": "display", &"moonlight": "display",
	&"pause_on_focus_loss": "gameplay", &"show_start_hints": "gameplay",
}
const CONTROLS_SECTION: String = "controls"

var _values: Dictionary[StringName, Variant] = DEFAULTS.duplicate()


## Instance dùng chung (nạp file + áp dụng ở lần gọi đầu).
static func get_instance() -> GameSettings:
	if _instance == null:
		_instance = GameSettings.new()
		_instance.load_file()
		_instance.apply_all()
	return _instance


## Bỏ instance hiện tại (test: mô phỏng mở lại game). Lần get_instance() sau nạp lại file.
static func reset_instance() -> void:
	_instance = null


func get_value(key: StringName) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


## Đổi một cài đặt: kẹp / ép kiểu, áp dụng ngay, ghi file, phát changed.
func set_value(key: StringName, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_error("[GameSettings] Không có cài đặt '%s'." % key)
		return
	_values[key] = _sanitize(key, value)
	_apply(key)
	save_file()
	changed.emit(key)


func load_file() -> void:
	_values = DEFAULTS.duplicate()
	var config: ConfigFile = ConfigFile.new()
	if config.load(config_path) != OK:
		return
	for key: StringName in DEFAULTS:
		if config.has_section_key(SECTIONS[key], key):
			_values[key] = _sanitize(key, config.get_value(SECTIONS[key], key))
	if config.has_section(CONTROLS_SECTION):
		for action: String in config.get_section_keys(CONTROLS_SECTION):
			if not InputActions.is_remappable(StringName(action)):
				push_warning("[GameSettings] Bỏ qua phím của action lạ '%s'." % action)
				continue
			var events: Array[InputEvent] = []
			var saved: Variant = config.get_value(CONTROLS_SECTION, action)
			for text: Variant in (saved if saved is Array or saved is PackedStringArray else []):
				var event: InputEvent = InputActions.event_from_string(str(text))
				if event != null and InputActions.is_bindable(event) and events.size() < InputActions.MAX_BINDINGS:
					events.append(event)
			_set_action_events(StringName(action), events)


func save_file() -> void:
	var config: ConfigFile = ConfigFile.new()
	for key: StringName in DEFAULTS:
		config.set_value(SECTIONS[key], key, _values[key])
	for action: StringName in InputActions.remappable():
		var texts: PackedStringArray = PackedStringArray()
		for event: InputEvent in InputActions.bindable_events(action):
			texts.append(InputActions.event_to_string(event))
		config.set_value(CONTROLS_SECTION, action, texts)
	var err: Error = config.save(config_path)
	if err != OK:
		push_warning("[GameSettings] Không ghi được %s (%s)." % [config_path, error_string(err)])


func apply_all() -> void:
	for key: StringName in DEFAULTS:
		_apply(key)


# --- Điều khiển ----------------------------------------------------------------------------------

## Phím thứ `index` của action (null nếu chưa gán).
func get_binding(action: StringName, index: int) -> InputEvent:
	var events: Array[InputEvent] = InputActions.bindable_events(action)
	return events[index] if index >= 0 and index < events.size() else null


## Action + vị trí đang dùng phím này (ngoài `action`/`index` đang đổi); {} nếu không trùng.
func find_conflict(event: InputEvent, action: StringName, index: int = -1) -> Dictionary:
	for other: StringName in InputActions.remappable():
		var events: Array[InputEvent] = InputActions.bindable_events(other)
		for i: int in events.size():
			if other == action and i == index:
				continue
			if InputActions.same_input(events[i], event):
				return {"action": other, "index": i}
	return {}


## Gán `event` vào vị trí `index` của action. Phím đang dùng ở chỗ khác: `swap` = true → chỗ đó nhận phím cũ của vị trí này
## (vị trí này trống thì chỗ kia bị bỏ phím); `swap` = false → không đổi gì. Esc / sự kiện lạ → từ chối.
## Trả về "" nếu đã đổi, ngược lại là lý do.
func bind(action: StringName, index: int, event: InputEvent, swap: bool = false) -> String:
	if not InputActions.is_remappable(action):
		return "Không đổi được phím của hành động này."
	if event == null or not InputActions.is_bindable(event):
		return "Không dùng được phím này."
	if index < 0 or index >= InputActions.MAX_BINDINGS:
		return "Vị trí phím không hợp lệ."
	var new_event: InputEvent = InputActions.normalized(event)
	var events: Array[InputEvent] = InputActions.bindable_events(action)
	var previous: InputEvent = events[index] if index < events.size() else null
	var conflict: Dictionary = find_conflict(new_event, action, index)
	if not conflict.is_empty():
		if not swap:
			return "Phím %s đang dùng cho \"%s\"." % [InputActions.event_text(new_event), InputActions.display_name(conflict["action"])]
		var other: StringName = conflict["action"]
		var at: int = conflict["index"]
		if other == action:
			# Cùng action (đổi phím chính ↔ phụ): đổi chỗ trong danh sách của chính nó.
			if previous != null:
				events[at] = previous
			else:
				events.remove_at(at)
				index = events.size()
		else:
			var other_events: Array[InputEvent] = InputActions.bindable_events(other)
			if previous != null:
				other_events[at] = previous
			else:
				other_events.remove_at(at)
			_set_action_events(other, other_events)
	if index < events.size():
		events[index] = new_event
	else:
		events.append(new_event)
	_set_action_events(action, events)
	save_file()
	changed.emit(&"controls")
	return ""


## Bỏ phím ở vị trí `index` của action.
func unbind(action: StringName, index: int) -> void:
	var events: Array[InputEvent] = InputActions.bindable_events(action)
	if index < 0 or index >= events.size():
		return
	events.remove_at(index)
	_set_action_events(action, events)
	save_file()
	changed.emit(&"controls")


## Khôi phục phím mặc định (project.godot) cho mọi action đổi được.
func reset_bindings() -> void:
	for action: StringName in InputActions.remappable():
		_set_action_events(action, InputActions.default_events(action))
	save_file()
	changed.emit(&"controls")


# --- Nội bộ --------------------------------------------------------------------------------------

## Thay các phím / nút chuột của action, giữ sự kiện loại khác (vd. tay cầm sau này).
func _set_action_events(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		return
	for old: InputEvent in InputActions.bindable_events(action):
		InputMap.action_erase_event(action, old)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func _sanitize(key: StringName, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[key]
	match typeof(fallback):
		TYPE_BOOL:
			return bool(value) if value is bool or value is int or value is float else fallback
		TYPE_FLOAT:
			if not (value is float or value is int):
				return fallback
			if key == &"moonlight":
				return clampf(float(value), MOONLIGHT_MIN, MOONLIGHT_MAX)
			return clampf(float(value), 0.0, 1.0)
		TYPE_INT:
			if not (value is float or value is int):
				return fallback
			return int(value) if FPS_LIMITS.has(int(value)) else fallback
	return fallback


func _apply(key: StringName) -> void:
	var value: Variant = _values[key]
	if BUSES.has(key):
		var bus: int = AudioServer.get_bus_index(BUSES[key])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(value), 0.0001)))
			AudioServer.set_bus_mute(bus, float(value) <= 0.001)
		return
	match key:
		&"fullscreen":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		&"vsync":
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
		&"fps_limit":
			Engine.max_fps = int(value)
