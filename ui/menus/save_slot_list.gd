class_name SaveSlotList
extends Control
## Danh sách 3 ô save (TASK M6) — dùng cho Tải game, Lưu game (menu tạm dừng) và Chơi mới (chọn ô). Mỗi ô hiện ảnh nhỏ,
## và cho từng bản (thủ công / tự lưu): ngày + giờ game, tổng thời gian chơi, thời điểm lưu (giờ thật), tên map — đọc
## metadata (SaveService.list_slots, file meta.json riêng), không đọc cả save.
## - LOAD: "Tải bản thủ công" / "Tải bản tự lưu" → load_requested(slot, kind).
## - SAVE: "Lưu vào ô này" (ô đã có bản thủ công → xác nhận ghi đè) → save_requested(slot).
## - NEW_GAME: "Chơi mới ở ô này" (ô đã có dữ liệu → xác nhận ghi đè) → new_game_requested(slot).
## - "Xóa ô" (có xác nhận) xóa mọi bản của ô. Esc / "Quay lại" → closed.

signal closed
signal load_requested(slot: int, kind: StringName)
signal save_requested(slot: int)
signal new_game_requested(slot: int)

enum Mode { LOAD, SAVE, NEW_GAME }

const TITLES: Array[String] = ["Tải game", "Lưu game", "Chơi mới — chọn ô save"]

var mode: Mode = Mode.LOAD
## Ô đang chơi (đánh dấu trong danh sách; 0 = không có).
var current_slot: int = 0

var _rows: VBoxContainer
var _status: Label


static func create(p_mode: Mode, p_current_slot: int = 0) -> SaveSlotList:
	var list: SaveSlotList = SaveSlotList.new()
	list.name = "SaveSlotList"
	list.mode = p_mode
	list.current_slot = p_current_slot
	return list


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var center: CenterContainer = MenuUI.modal_root(self)
	var frame: PanelContainer = MenuUI.panel(Vector2(760, 0))
	center.add_child(frame)
	var box: VBoxContainer = MenuUI.vbox(12)
	frame.add_child(box)
	box.add_child(MenuUI.title(TITLES[mode]))
	_rows = MenuUI.vbox(10)
	box.add_child(_rows)
	_status = MenuUI.label("", 14, MenuUI.WARNING_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var back: Button = MenuUI.button("Quay lại", close, 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(back)
	refresh()
	SaveService.slots_changed.connect(refresh)
	MenuUI.focus_first.call_deferred(self)


func close() -> void:
	closed.emit()
	queue_free()


func set_status(text: String) -> void:
	_status.text = text


## Dựng lại các dòng từ metadata.
func refresh() -> void:
	if _rows == null:
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for info: Dictionary in SaveService.list_slots():
		_rows.add_child(_build_row(info))


## Chữ mô tả một bản save từ metadata ("—" nếu chưa có).
static func describe(entry: Dictionary) -> String:
	if entry.is_empty():
		return "—"
	return "Ngày %d · %s · %s · đã chơi %s · lưu lúc %s" % [int(entry.get("day", 1)), MenuUI.format_clock(float(entry.get("minute", 0.0))),
		str(entry.get("map_name", entry.get("map_id", "?"))), MenuUI.format_playtime(float(entry.get("playtime", 0.0))),
		MenuUI.format_saved_at(str(entry.get("saved_at", "")))]


func _build_row(info: Dictionary) -> Control:
	var slot: int = info["slot"]
	var manual: Dictionary = info["manual"]
	var auto: Dictionary = info["autosave"]
	var has_data: bool = not manual.is_empty() or not auto.is_empty()
	var row: PanelContainer = PanelContainer.new()
	row.name = "Slot%d" % slot
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", 12)
	row.add_child(line)
	var frame: ColorRect = ColorRect.new()
	frame.color = Color(0.14, 0.15, 0.19)
	frame.custom_minimum_size = Vector2(SaveService.THUMBNAIL_SIZE)
	line.add_child(frame)
	var thumb: TextureRect = TextureRect.new()
	thumb.name = "Thumbnail"
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var newest: StringName = SaveService.newest_kind(slot) if has_data else &""
	thumb.texture = SaveService.load_thumbnail(slot, newest) if has_data else null
	frame.add_child(thumb)
	if thumb.texture == null:
		var empty: Label = MenuUI.label("Chưa có ảnh" if has_data else "Trống", 13, MenuUI.MUTED_COLOR)
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		frame.add_child(empty)
	var text: VBoxContainer = MenuUI.vbox(4)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(MenuUI.label("Ô %d%s%s" % [slot, " (đang chơi)" if slot == current_slot else "", "" if has_data else " — trống"], 18, MenuUI.TITLE_COLOR))
	var manual_label: Label = MenuUI.label("Thủ công: " + describe(manual), 13)
	manual_label.name = "ManualInfo"
	text.add_child(manual_label)
	var auto_label: Label = MenuUI.label("Tự lưu: " + describe(auto), 13, MenuUI.MUTED_COLOR if auto.is_empty() else MenuUI.TEXT_COLOR)
	auto_label.name = "AutoInfo"
	text.add_child(auto_label)
	var buttons: VBoxContainer = MenuUI.vbox(4)
	line.add_child(buttons)
	match mode:
		Mode.LOAD:
			var load_manual: Button = MenuUI.button("Tải bản thủ công", func() -> void: load_requested.emit(slot, SaveService.MANUAL), 170)
			load_manual.disabled = manual.is_empty()
			buttons.add_child(load_manual)
			var load_auto: Button = MenuUI.button("Tải bản tự lưu", func() -> void: load_requested.emit(slot, SaveService.AUTO), 170)
			load_auto.disabled = auto.is_empty()
			buttons.add_child(load_auto)
		Mode.SAVE:
			buttons.add_child(MenuUI.button("Lưu vào ô này", _on_save_pressed.bind(slot, not manual.is_empty()), 170))
		Mode.NEW_GAME:
			buttons.add_child(MenuUI.button("Chơi mới ở ô này", _on_new_game_pressed.bind(slot, has_data), 170))
	var delete: Button = MenuUI.button("Xóa ô", _on_delete_pressed.bind(slot), 170)
	delete.disabled = not has_data
	buttons.add_child(delete)
	return row


func _on_save_pressed(slot: int, has_manual: bool) -> void:
	if not has_manual:
		save_requested.emit(slot)
		return
	ConfirmBox.open(self, "Ô %d đã có bản lưu thủ công. Ghi đè?" % slot, "Ghi đè").answered.connect(func(yes: bool) -> void:
		if yes:
			save_requested.emit(slot))


func _on_new_game_pressed(slot: int, has_data: bool) -> void:
	if not has_data:
		new_game_requested.emit(slot)
		return
	ConfirmBox.open(self, "Ô %d đã có dữ liệu. Chơi mới sẽ XÓA toàn bộ save của ô này (thủ công + tự lưu). Ghi đè?" % slot,
		"Ghi đè").answered.connect(func(yes: bool) -> void:
			if yes:
				new_game_requested.emit(slot))


func _on_delete_pressed(slot: int) -> void:
	ConfirmBox.open(self, "Xóa toàn bộ save của ô %d (thủ công + tự lưu)? Không khôi phục được." % slot, "Xóa").answered.connect(
		func(yes: bool) -> void:
			if yes:
				SaveService.delete_slot(slot)
				set_status("Đã xóa ô %d." % slot)
				MenuUI.focus_first.call_deferred(self))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.PAUSE_ACTION) or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
