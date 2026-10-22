class_name PauseMenu
extends Control
## Menu tạm dừng (TASK M6). World mở bằng Esc (`pause_menu`) khi không có cửa sổ nào đang mở, hoặc khi cửa sổ game mất focus
## (Cài đặt → Gameplay). Mở = dừng game thật (SceneTree.paused: đồng hồ, quái, cây, buff, đói, lửa trại, đuốc đứng yên);
## menu chạy cả khi dừng (process ALWAYS). Mở túi đồ KHÔNG dừng game (như cũ).
## Nút: Tiếp tục · Lưu (World.get_save_block_reason: không lưu khi bị truy đuổi / đang chuyển tầng...; chọn ô) · Tải ·
## Cài đặt · Hướng dẫn phím · Về màn hình chính / Thoát game.
## Về màn hình chính / Thoát game / nút đóng cửa sổ (TASK M6.1): tự ghi vào bản TỰ LƯU của ô đang chơi (không đụng bản thủ
## công) rồi mới đi. Lúc không lưu được (World.get_save_block_reason: đang bị truy đuổi...) mà có tiến trình chưa lưu thì
## hỏi xác nhận, nói rõ lý do.
## Esc: đóng lớp trên cùng (hộp xác nhận → màn con → menu = tiếp tục chơi).
## Ảnh chụp nhỏ cho bản lưu thủ công lấy lúc mở menu (khung hình game chưa có menu).

signal opened
signal closed

const BUTTONS: Array[String] = ["Tiếp tục", "Lưu", "Tải", "Cài đặt", "Hướng dẫn phím", "Về màn hình chính", "Thoát game"]
const TITLE_SCENE: String = "res://app/main.tscn"

## World (lý do không lưu được, map hiện tại). Duck-typing: get_save_block_reason() -> String.
var world: Node
## Thoát game thật (test thay bằng hàm ghi nhận để không tắt tiến trình test).
var quit_handler: Callable

var _frame: PanelContainer
var _status: Label
var _snapshot: Image
var _subpanel: Control


static func create(p_world: Node) -> PauseMenu:
	var menu: PauseMenu = PauseMenu.new()
	menu.name = "PauseMenu"
	menu.world = p_world
	return menu


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	hide()
	var center: CenterContainer = MenuUI.modal_root(self)
	_frame = MenuUI.panel(Vector2(340, 0))
	center.add_child(_frame)
	var box: VBoxContainer = MenuUI.vbox(10)
	_frame.add_child(box)
	box.add_child(MenuUI.title("Tạm dừng"))
	for text: String in BUTTONS:
		var button: Button = MenuUI.button(text, _on_button.bind(text))
		button.name = text
		box.add_child(button)
	_status = MenuUI.label("", 14, MenuUI.WARNING_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 300
	box.add_child(_status)


func is_open() -> bool:
	return visible


func get_status_text() -> String:
	return _status.text


## Màn con đang mở (SaveSlotList / SettingsPanel / KeyGuidePanel) hoặc null.
func get_subpanel() -> Control:
	return _subpanel if _subpanel != null and is_instance_valid(_subpanel) and not _subpanel.is_queued_for_deletion() else null


func get_button(text: String) -> Button:
	return _frame.find_child(text, true, false) as Button


func open() -> void:
	if visible:
		return
	_snapshot = SaveService.capture_thumbnail()
	_status.text = ""
	get_tree().paused = true
	show()
	MenuUI.focus_first(self)
	opened.emit()


## Tiếp tục chơi.
func resume() -> void:
	if not visible:
		return
	_close_subpanel()
	for child: Node in get_children():
		if child is ConfirmBox:
			child.queue_free()
	hide()
	get_tree().paused = false
	closed.emit()


## Nút đóng cửa sổ game (AppOverlay → World.request_quit): như nút Thoát game (tự lưu rồi thoát).
func request_quit() -> void:
	open()
	_on_button("Thoát game")


func _on_button(text: String) -> void:
	_status.text = ""
	match text:
		"Tiếp tục":
			resume()
		"Lưu":
			_open_save()
		"Tải":
			_open_subpanel(SaveSlotList.create(SaveSlotList.Mode.LOAD, SaveService.current_slot))
			(_subpanel as SaveSlotList).load_requested.connect(_on_load_requested)
		"Cài đặt":
			_open_subpanel(SettingsPanel.create())
		"Hướng dẫn phím":
			_open_subpanel(KeyGuidePanel.create())
		"Về màn hình chính":
			_autosave_then("Về màn hình chính", _go_to_title)
		"Thoát game":
			_autosave_then("Thoát game", _quit)


func _open_save() -> void:
	var reason: String = str(world.call(&"get_save_block_reason")) if world != null and world.has_method(&"get_save_block_reason") else ""
	if reason.is_empty() and not SaveService.can_save():
		reason = "Không lưu được ở map này."
	if not reason.is_empty():
		_status.text = reason
		return
	_open_subpanel(SaveSlotList.create(SaveSlotList.Mode.SAVE, SaveService.current_slot))
	(_subpanel as SaveSlotList).save_requested.connect(_on_save_requested)


func _on_save_requested(slot: int) -> void:
	if SaveService.save_game(slot, SaveService.MANUAL, _snapshot):
		_close_subpanel()
		_status.text = "Đã lưu vào ô %d." % slot
	elif _subpanel is SaveSlotList:
		(_subpanel as SaveSlotList).set_status(SaveService.last_error)


func _on_load_requested(slot: int, kind: StringName) -> void:
	var do_load: Callable = func() -> void:
		if not SaveService.load_game(slot, kind) and _subpanel is SaveSlotList:
			(_subpanel as SaveSlotList).set_status("Không tải được: %s" % SaveService.last_error)
	if SaveService.has_unsaved_progress():
		ConfirmBox.open(_subpanel if get_subpanel() != null else self, "Tiến trình chưa lưu sẽ mất. Vẫn tải?", "Tải").answered.connect(
			func(yes: bool) -> void:
				if yes:
					do_load.call())
	else:
		do_load.call()


## Tự lưu vào bản tự lưu của ô đang chơi rồi làm `action`. Không lưu được (bị truy đuổi, ghi lỗi...) mà có tiến trình
## chưa lưu → hỏi xác nhận kèm lý do.
func _autosave_then(action_text: String, action: Callable) -> void:
	var reason: String = ""
	if SaveService.can_save():
		reason = str(world.call(&"get_save_block_reason")) if world != null and world.has_method(&"get_save_block_reason") else ""
		if reason.is_empty() and not SaveService.autosave(_snapshot):
			reason = SaveService.last_error
	if reason.is_empty() or not SaveService.has_unsaved_progress():
		action.call()
		return
	var message: String = "%s — không tự lưu được, tiến trình chưa lưu sẽ bị mất.\n%s?" % [reason.trim_suffix("."), action_text]
	ConfirmBox.open(self, message, action_text).answered.connect(func(yes: bool) -> void:
		if yes:
			action.call()
		else:
			MenuUI.focus_first(self))


func _quit() -> void:
	if quit_handler.is_valid():
		quit_handler.call()
	else:
		get_tree().quit()


func _go_to_title() -> void:
	SaveService.new_session()
	AppOverlay.ensure(get_tree()).change_scene(TITLE_SCENE)


func _open_subpanel(panel: Control) -> void:
	_close_subpanel()
	_subpanel = panel
	_frame.hide()
	add_child(panel)
	panel.connect(&"closed", _on_subpanel_closed)


func _close_subpanel() -> void:
	var panel: Control = get_subpanel()
	if panel != null:
		panel.call(&"close")
	_subpanel = null


func _on_subpanel_closed() -> void:
	_subpanel = null
	_frame.show()
	MenuUI.focus_first(self)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(InputActions.PAUSE_ACTION) or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		resume()
