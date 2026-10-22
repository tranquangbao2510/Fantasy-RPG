class_name SettingsPanel
extends Control
## Màn Cài đặt (TASK M6): Âm thanh / Hình ảnh / Gameplay / Điều khiển. Mọi thay đổi gọi GameSettings (áp dụng ngay, ghi
## user://settings.cfg). Điều khiển: mỗi hành động (InputActions) có 2 ô phím; bấm ô → "Nhấn phím…" → phím / nút chuột kế
## tiếp được gán (Esc: hủy, không gán được Esc); chuột phải lên ô = bỏ phím đó. Phím đang dùng cho hành động khác → hỏi hoán
## đổi (ConfirmBox). "Khôi phục mặc định" (có xác nhận). Esc / "Quay lại" → closed.

signal closed

const TAB_NAMES: Array[String] = ["Âm thanh", "Hình ảnh", "Gameplay", "Điều khiển"]

var _settings: GameSettings
var _tabs: TabContainer
var _binding_buttons: Dictionary[String, Button] = {}
var _capture_action: StringName = &""
var _capture_index: int = -1
var _status: Label


static func create() -> SettingsPanel:
	var panel: SettingsPanel = SettingsPanel.new()
	panel.name = "SettingsPanel"
	return panel


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_settings = GameSettings.get_instance()
	var center: CenterContainer = MenuUI.modal_root(self)
	var frame: PanelContainer = MenuUI.panel(Vector2(720, 520))
	center.add_child(frame)
	var box: VBoxContainer = MenuUI.vbox(10)
	frame.add_child(box)
	box.add_child(MenuUI.title("Cài đặt"))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(700, 420)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_tabs)
	_tabs.add_child(_build_audio())
	_tabs.add_child(_build_display())
	_tabs.add_child(_build_gameplay())
	_tabs.add_child(_build_controls())
	for i: int in TAB_NAMES.size():
		_tabs.set_tab_title(i, TAB_NAMES[i])
	_status = MenuUI.label("", 14, MenuUI.WARNING_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var back: Button = MenuUI.button("Quay lại", close, 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	_settings.changed.connect(_on_settings_changed)
	_tabs.get_tab_bar().grab_focus.call_deferred()


func close() -> void:
	closed.emit()
	queue_free()


func show_tab(index: int) -> void:
	_tabs.current_tab = index


func is_capturing() -> bool:
	return _capture_action != &""


func get_status_text() -> String:
	return _status.text


## Nút phím của action ở vị trí index (test).
func get_binding_button(action: StringName, index: int) -> Button:
	return _binding_buttons.get("%s:%d" % [action, index])


## Bắt đầu chờ phím mới cho action/vị trí (giống bấm ô phím).
func begin_capture(action: StringName, index: int) -> void:
	_capture_action = action
	_capture_index = index
	_status.text = ""
	var button: Button = get_binding_button(action, index)
	if button != null:
		button.text = "Nhấn phím… (Esc: hủy)"


func cancel_capture() -> void:
	_capture_action = &""
	_capture_index = -1
	_refresh_bindings()


# --- Dựng các tab --------------------------------------------------------------------------------

func _build_audio() -> Control:
	var box: VBoxContainer = _tab_box("Audio")
	box.add_child(MenuUI.label("Chưa có âm thanh thật — các thanh chỉnh âm lượng bus Master / Nhạc / Hiệu ứng.", 13, MenuUI.MUTED_COLOR))
	_add_slider(box, "Âm lượng chính", &"master_volume", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100))
	_add_slider(box, "Nhạc", &"music_volume", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100))
	_add_slider(box, "Hiệu ứng", &"sfx_volume", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100))
	return box


func _build_display() -> Control:
	var box: VBoxContainer = _tab_box("Display")
	_add_toggle(box, "Toàn màn hình", &"fullscreen")
	_add_toggle(box, "Đồng bộ dọc (vsync)", &"vsync")
	var row: HBoxContainer = _row(box, "Giới hạn FPS")
	var fps: OptionButton = OptionButton.new()
	fps.name = "FpsLimit"
	for limit: int in GameSettings.FPS_LIMITS:
		fps.add_item(str(limit) if limit > 0 else "Không giới hạn", limit)
	fps.select(GameSettings.FPS_LIMITS.find(int(_settings.get_value(&"fps_limit"))))
	fps.item_selected.connect(func(index: int) -> void: _settings.set_value(&"fps_limit", GameSettings.FPS_LIMITS[index]))
	row.add_child(fps)
	_add_toggle(box, "Hiện FPS", &"show_fps")
	_add_slider(box, "Độ sáng ban đêm (ánh trăng)", &"moonlight", GameSettings.MOONLIGHT_MIN, GameSettings.MOONLIGHT_MAX, 0.01,
		func(v: float) -> String: return "%d%%" % roundi(v * 100))
	box.add_child(MenuUI.label("Chỉ đổi độ sáng hiển thị ngoài vùng sáng (màn hình tối); không đổi tầm nhìn / luật quái.", 12, MenuUI.MUTED_COLOR))
	return box


func _build_gameplay() -> Control:
	var box: VBoxContainer = _tab_box("Gameplay")
	_add_toggle(box, "Tự tạm dừng khi cửa sổ game mất focus", &"pause_on_focus_loss")
	_add_toggle(box, "Hiện bảng gợi ý phím khi chơi mới", &"show_start_hints")
	return box


func _build_controls() -> Control:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Controls"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box: VBoxContainer = MenuUI.vbox(6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(MenuUI.label("Bấm ô phím rồi nhấn phím / nút chuột mới (Esc: hủy) · chuột phải lên ô: bỏ phím · Esc cố định cho menu.", 12, MenuUI.MUTED_COLOR))
	for group: Array in InputActions.GROUPS:
		box.add_child(MenuUI.label(group[0], 16, MenuUI.TITLE_COLOR))
		for action: StringName in group[1]:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override(&"separation", 8)
			box.add_child(row)
			var name_label: Label = MenuUI.label(InputActions.display_name(action), 14)
			name_label.custom_minimum_size.x = 300
			row.add_child(name_label)
			for index: int in InputActions.MAX_BINDINGS:
				var button: Button = MenuUI.button("", begin_capture.bind(action, index), 150)
				button.name = "%s_%d" % [action, index]
				button.gui_input.connect(_on_binding_gui_input.bind(action, index))
				row.add_child(button)
				_binding_buttons["%s:%d" % [action, index]] = button
	var reset: Button = MenuUI.button("Khôi phục mặc định", _on_reset_pressed, 220)
	reset.name = "ResetBindings"
	box.add_child(reset)
	_refresh_bindings()
	return scroll


func _tab_box(tab_name: String) -> VBoxContainer:
	var box: VBoxContainer = MenuUI.vbox(12)
	box.name = tab_name
	return box


func _row(box: VBoxContainer, text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	box.add_child(row)
	var name_label: Label = MenuUI.label(text, 15)
	name_label.custom_minimum_size.x = 300
	row.add_child(name_label)
	return row


func _add_toggle(box: VBoxContainer, text: String, key: StringName) -> CheckButton:
	var row: HBoxContainer = _row(box, text)
	var toggle: CheckButton = CheckButton.new()
	toggle.name = String(key)
	toggle.button_pressed = bool(_settings.get_value(key))
	toggle.toggled.connect(func(on: bool) -> void: _settings.set_value(key, on))
	MenuUI.style_check(toggle)
	row.add_child(toggle)
	return toggle


func _add_slider(box: VBoxContainer, text: String, key: StringName, low: float, high: float, step: float,
		format: Callable) -> HSlider:
	var row: HBoxContainer = _row(box, text)
	var slider: HSlider = HSlider.new()
	slider.name = String(key)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.x = 240
	slider.value = float(_settings.get_value(key))
	row.add_child(slider)
	var value_label: Label = MenuUI.label(format.call(slider.value), 14)
	row.add_child(value_label)
	slider.value_changed.connect(func(v: float) -> void:
		_settings.set_value(key, v)
		value_label.text = format.call(v))
	return slider


# --- Điều khiển ----------------------------------------------------------------------------------

func _refresh_bindings() -> void:
	for key: String in _binding_buttons:
		var parts: PackedStringArray = key.split(":")
		var event: InputEvent = _settings.get_binding(StringName(parts[0]), parts[1].to_int())
		_binding_buttons[key].text = InputActions.event_text(event) if event != null else "—"


## Gán phím vừa nhấn cho ô đang chờ; trùng → hỏi hoán đổi.
func apply_captured(event: InputEvent) -> void:
	var action: StringName = _capture_action
	var index: int = _capture_index
	_capture_action = &""
	_capture_index = -1
	var normalized: InputEvent = InputActions.normalized(event)
	var conflict: Dictionary = _settings.find_conflict(normalized, action, index)
	if conflict.is_empty():
		_status.text = _settings.bind(action, index, normalized)
		_refresh_bindings()
		return
	_refresh_bindings()
	var question: String = "Phím %s đang dùng cho \"%s\". Hoán đổi phím giữa hai hành động?" % [
		InputActions.event_text(normalized), InputActions.display_name(conflict["action"])]
	ConfirmBox.open(self, question, "Hoán đổi").answered.connect(func(yes: bool) -> void:
		if yes:
			_status.text = _settings.bind(action, index, normalized, true)
		else:
			_status.text = "Giữ nguyên phím cũ."
		_refresh_bindings())


func _input(event: InputEvent) -> void:
	if not is_capturing():
		return
	if not event.is_pressed() or event.is_echo():
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and InputActions.is_reserved(event):
		get_viewport().set_input_as_handled()
		cancel_capture()
		_status.text = "Đã hủy đổi phím (Esc dành cho menu)."
		return
	if InputActions.is_bindable(event):
		get_viewport().set_input_as_handled()
		apply_captured(event)


func _on_binding_gui_input(event: InputEvent, action: StringName, index: int) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT and not is_capturing():
		_settings.unbind(action, index)
		_refresh_bindings()
		accept_event()


func _on_reset_pressed() -> void:
	ConfirmBox.open(self, "Khôi phục phím mặc định cho mọi hành động?", "Khôi phục").answered.connect(func(yes: bool) -> void:
		if yes:
			_settings.reset_bindings()
			_status.text = "Đã khôi phục phím mặc định."
		_refresh_bindings())


func _on_settings_changed(key: StringName) -> void:
	if key == &"controls" and not is_capturing():
		_refresh_bindings()


func _unhandled_input(event: InputEvent) -> void:
	if is_capturing():
		return
	if event.is_action_pressed(InputActions.PAUSE_ACTION) or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
