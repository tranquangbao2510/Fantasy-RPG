extends Control
## Màn hình tiêu đề (TASK M6) — Main Scene, game mở lên vào đây (không vào thẳng Glade).
## Nền: ảnh tĩnh cảnh Glade (app/art/title_background.jpg, sinh bằng tools/title/render_title_background.gd) trôi chậm.
## Tên game là chữ placeholder. Nút: Tiếp tục (bản save mới nhất trong mọi ô — ẩn nếu chưa có save) · Chơi mới (chọn ô) ·
## Tải game · Cài đặt · Thoát. Chuột + bàn phím (mũi tên + Enter; focus sẵn nút đầu). Bản debug thêm lối vào map thử nghiệm.
## Đổi scene qua AppOverlay (màn đen).

const TITLE_TEXT: String = "FANTASY RPG"
const SUBTITLE_TEXT: String = "(tên game tạm)"
const BACKGROUND_PATH: String = "res://app/art/title_background.jpg"
const SANDBOX_SCENE_PATH: String = "res://world/sandbox/combat_sandbox.tscn"
const TEST_MAP_SCENE_PATH: String = "res://world/world.tscn"
## Biên độ (px) và chu kỳ (s) trôi nền.
const PAN_AMPLITUDE: Vector2 = Vector2(60, 24)
const PAN_PERIOD: float = 40.0

var _background: TextureRect
var _menu: VBoxContainer
var _continue_button: Button
var _status: Label
var _subpanel: Control
var _time: float = 0.0


func _ready() -> void:
	AppOverlay.ensure(get_tree())
	GameSettings.get_instance()
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	refresh()
	SaveService.slots_changed.connect(refresh)


func _process(delta: float) -> void:
	_time += delta
	if _background != null:
		var phase: float = _time / PAN_PERIOD * TAU
		_background.position = -PAN_AMPLITUDE + Vector2(sin(phase), sin(phase * 0.5)) * PAN_AMPLITUDE


## Ẩn / hiện "Tiếp tục" theo save hiện có, focus nút đầu.
func refresh() -> void:
	_continue_button.visible = SaveService.has_any_save()
	if _subpanel == null:
		MenuUI.focus_first(_menu)


func get_menu() -> Control:
	return _menu


func get_subpanel() -> Control:
	return _subpanel if _subpanel != null and is_instance_valid(_subpanel) and not _subpanel.is_queued_for_deletion() else null


func get_status_text() -> String:
	return _status.text


func continue_game() -> void:
	var latest: Dictionary = SaveService.latest_save()
	if latest.is_empty():
		refresh()
		return
	if not SaveService.load_game(int(latest["slot"]), latest["kind"]):
		_status.text = "Không tải được save: %s" % SaveService.last_error


func _build() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.05, 0.06, 0.08)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	_background = TextureRect.new()
	_background.name = "Background"
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BACKGROUND_PATH):
		_background.texture = load(BACKGROUND_PATH) as Texture2D
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Rộng hơn màn hình một chút để trôi không lộ mép.
	_background.offset_right = PAN_AMPLITUDE.x * 2.0
	_background.offset_bottom = PAN_AMPLITUDE.y * 2.0
	add_child(_background)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_menu = MenuUI.vbox(12)
	_menu.name = "Menu"
	center.add_child(_menu)
	var title: Label = MenuUI.title(TITLE_TEXT, 64)
	title.add_theme_color_override(&"font_outline_color", Color(0.1, 0.06, 0.02))
	title.add_theme_constant_override(&"outline_size", 12)
	_menu.add_child(title)
	var subtitle: Label = MenuUI.label(SUBTITLE_TEXT, 16, MenuUI.MUTED_COLOR)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(subtitle)
	_menu.add_child(Control.new())
	_continue_button = _add_button("Tiếp tục", continue_game)
	_add_button("Chơi mới", _open_slots.bind(SaveSlotList.Mode.NEW_GAME))
	_add_button("Tải game", _open_slots.bind(SaveSlotList.Mode.LOAD))
	_add_button("Cài đặt", func() -> void: _open_subpanel(SettingsPanel.create()))
	_add_button("Thoát", func() -> void: get_tree().quit())
	if DebugKeys.enabled():
		var debug_row: HBoxContainer = HBoxContainer.new()
		debug_row.alignment = BoxContainer.ALIGNMENT_CENTER
		debug_row.add_theme_constant_override(&"separation", 8)
		_menu.add_child(debug_row)
		debug_row.add_child(MenuUI.button("[Debug] Combat Sandbox", _open_debug_scene.bind(SANDBOX_SCENE_PATH), 200))
		debug_row.add_child(MenuUI.button("[Debug] Bản đồ thử nghiệm", _open_debug_scene.bind(TEST_MAP_SCENE_PATH), 200))
	_status = MenuUI.label("", 14, MenuUI.WARNING_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(_status)
	var version: Label = MenuUI.label("Godot %s · bản %s" % [Engine.get_version_info().get("string", "?"),
		"debug" if OS.is_debug_build() else "release"], 12, MenuUI.MUTED_COLOR)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	add_child(version)


func _add_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = MenuUI.button(text, on_pressed)
	button.name = text
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu.add_child(button)
	return button


func _open_slots(mode: SaveSlotList.Mode) -> void:
	var list: SaveSlotList = SaveSlotList.create(mode)
	_open_subpanel(list)
	if mode == SaveSlotList.Mode.LOAD:
		list.load_requested.connect(func(slot: int, kind: StringName) -> void:
			if not SaveService.load_game(slot, kind):
				list.set_status("Không tải được: %s" % SaveService.last_error))
	else:
		list.new_game_requested.connect(func(slot: int) -> void: SaveService.start_new_game(slot))


func _open_subpanel(panel: Control) -> void:
	if get_subpanel() != null:
		panel.queue_free()
		return
	_subpanel = panel
	_menu.hide()
	add_child(panel)
	panel.connect(&"closed", _on_subpanel_closed)


func _on_subpanel_closed() -> void:
	_subpanel = null
	_menu.show()
	_status.text = ""
	refresh()


func _open_debug_scene(path: String) -> void:
	SaveService.new_session()
	AppOverlay.ensure(get_tree()).change_scene(path)
