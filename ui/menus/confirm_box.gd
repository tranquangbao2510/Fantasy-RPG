class_name ConfirmBox
extends Control
## Hộp xác nhận (TASK M6): nền mờ + câu hỏi + hai nút. Esc (pause_menu / ui_cancel) = chọn "không". Tự giải phóng sau khi
## trả lời. Chạy cả khi game tạm dừng (process ALWAYS).

signal answered(yes: bool)

var _yes_button: Button
var _no_button: Button
var _message: String


## Mở hộp trên `parent`; nút "không" có focus sẵn (Enter không vô tình đồng ý).
static func open(parent: Node, message: String, yes_text: String = "Đồng ý", no_text: String = "Hủy") -> ConfirmBox:
	var box: ConfirmBox = ConfirmBox.new()
	box.name = "ConfirmBox"
	box._message = message
	parent.add_child(box)
	box._build(yes_text, no_text)
	return box


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func get_message() -> String:
	return _message


func answer(yes: bool) -> void:
	if is_queued_for_deletion():
		return
	answered.emit(yes)
	queue_free()


func _build(yes_text: String, no_text: String) -> void:
	var center: CenterContainer = MenuUI.modal_root(self)
	var frame: PanelContainer = MenuUI.panel(Vector2(420, 0))
	center.add_child(frame)
	var box: VBoxContainer = MenuUI.vbox(16)
	frame.add_child(box)
	var text: Label = MenuUI.label(_message, 17)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 420
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(text)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 16)
	box.add_child(row)
	_yes_button = MenuUI.button(yes_text, answer.bind(true), 160)
	_no_button = MenuUI.button(no_text, answer.bind(false), 160)
	row.add_child(_yes_button)
	row.add_child(_no_button)
	_no_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE_ACTION) or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		answer(false)
