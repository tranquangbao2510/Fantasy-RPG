class_name KeyGuidePanel
extends Control
## Màn Hướng dẫn phím (TASK M6): mọi hành động người chơi + phím HIỆN TẠI (đọc InputMap lúc mở — đổi phím trong Cài đặt thì
## hướng dẫn đổi theo), chia nhóm Di chuyển / Chiến đấu / Kỹ năng / Đồ đạc / Tương tác (InputActions.GROUPS). Esc / "Quay
## lại" → closed.

signal closed

var _list: VBoxContainer


static func create() -> KeyGuidePanel:
	var panel: KeyGuidePanel = KeyGuidePanel.new()
	panel.name = "KeyGuidePanel"
	return panel


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var center: CenterContainer = MenuUI.modal_root(self)
	var frame: PanelContainer = MenuUI.panel(Vector2(600, 0))
	center.add_child(frame)
	var box: VBoxContainer = MenuUI.vbox(10)
	frame.add_child(box)
	box.add_child(MenuUI.title("Hướng dẫn phím"))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = MenuUI.vbox(4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	refresh()
	var back: Button = MenuUI.button("Quay lại", close, 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	GameSettings.get_instance().changed.connect(func(key: StringName) -> void:
		if key == &"controls":
			refresh())
	back.grab_focus.call_deferred()


func close() -> void:
	closed.emit()
	queue_free()


func refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for line: Array in get_lines():
		var row: HBoxContainer = HBoxContainer.new()
		if line[1] == null:
			row.add_child(MenuUI.label(line[0], 17, MenuUI.TITLE_COLOR))
		else:
			var name_label: Label = MenuUI.label(line[0], 15)
			name_label.custom_minimum_size.x = 340
			row.add_child(name_label)
			row.add_child(MenuUI.label(line[1], 15, Color(0.75, 0.9, 1)))
		_list.add_child(row)


## Các dòng hiển thị: [tiêu đề nhóm, null] hoặc [tên hành động, phím hiện tại] (test đọc).
static func get_lines() -> Array[Array]:
	var lines: Array[Array] = []
	for group: Array in InputActions.GROUPS:
		lines.append([group[0], null])
		for action: StringName in group[1]:
			lines.append([InputActions.display_name(action), InputActions.action_keys_text(action)])
	lines.append(["Hệ thống", null])
	lines.append([InputActions.display_name(InputActions.PAUSE_ACTION) + " (cố định)", InputActions.action_keys_text(InputActions.PAUSE_ACTION)])
	return lines


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE_ACTION) or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
