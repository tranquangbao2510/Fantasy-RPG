class_name StartHintsPanel
extends Control
## Bảng gợi ý phím cơ bản lần đầu chơi mới (TASK M6). Game tạm dừng trong lúc hiện. "Đã hiểu" / Esc đóng; ô "Không hiện
## lại" tắt GameSettings `show_start_hints`. Tên phím đọc từ InputMap.

signal closed

var _dont_show: CheckBox


static func create() -> StartHintsPanel:
	var panel: StartHintsPanel = StartHintsPanel.new()
	panel.name = "StartHintsPanel"
	return panel


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var center: CenterContainer = MenuUI.modal_root(self)
	var frame: PanelContainer = MenuUI.panel(Vector2(520, 0))
	center.add_child(frame)
	var box: VBoxContainer = MenuUI.vbox(8)
	frame.add_child(box)
	box.add_child(MenuUI.title("Phím cơ bản", 22))
	for line: String in get_lines():
		box.add_child(MenuUI.label(line, 15))
	box.add_child(MenuUI.label("Xem đủ / đổi phím: %s → Hướng dẫn phím / Cài đặt." % InputHint.action_text(InputActions.PAUSE_ACTION), 13, MenuUI.MUTED_COLOR))
	_dont_show = CheckBox.new()
	_dont_show.name = "DontShowAgain"
	_dont_show.text = "Không hiện lại"
	box.add_child(_dont_show)
	var ok: Button = MenuUI.button("Đã hiểu", close, 200)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ok)
	get_tree().paused = true
	ok.grab_focus.call_deferred()


static func get_lines() -> Array[String]:
	return [
		"Di chuyển: %s / %s / %s / %s · chạy: giữ %s · né: %s" % [InputHint.action_text(&"move_up"), InputHint.action_text(&"move_left"),
			InputHint.action_text(&"move_down"), InputHint.action_text(&"move_right"), InputHint.action_text(&"sprint"), InputHint.action_text(&"dodge")],
		"Đánh: %s · kỹ năng: %s %s %s %s" % [InputHint.action_text(&"basic_attack"), InputHint.action_text(&"skill_slot_1"),
			InputHint.action_text(&"skill_slot_2"), InputHint.action_text(&"skill_slot_3"), InputHint.action_text(&"skill_slot_4")],
		"Tương tác / khai thác / thu hoạch: %s" % InputHint.action_text(&"interact"),
		"Túi đồ: %s · chế tạo: %s · menu: %s" % [InputHint.action_text(&"inventory_toggle"), InputHint.action_text(&"craft_toggle"),
			InputHint.action_text(InputActions.PAUSE_ACTION)],
		"Ngủ ở giường để qua đêm an toàn và tự lưu.",
	]


func set_dont_show_again(on: bool) -> void:
	_dont_show.button_pressed = on


func close() -> void:
	if _dont_show.button_pressed:
		GameSettings.get_instance().set_value(&"show_start_hints", false)
	get_tree().paused = false
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE_ACTION) or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
