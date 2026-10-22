class_name AppOverlay
extends CanvasLayer
## Lớp phủ dùng chung của ứng dụng (TASK M6), một node con của /root (tạo lười bằng ensure(), sống qua mọi lần đổi scene —
## không phải Autoload): màn đen chuyển cảnh, nhãn FPS (Cài đặt → Hiện FPS), xử lý nút đóng cửa sổ.
## - change_scene(path, on_loaded): khóa input người chơi + dừng game (SceneTree.paused — quái, đồng hồ, Player đứng yên) →
##   mờ đen → đổi scene → chờ scene mới _ready + 1 frame (setup hoãn chạy xong) → on_loaded (vd. SaveService áp save) →
##   bỏ dừng → sáng lại. Dùng cho: tiêu đề ↔ game, tải save, đổi map.
## - Nút đóng cửa sổ (NOTIFICATION_WM_CLOSE_REQUEST, auto_accept_quit tắt): scene hiện tại có request_quit() → gọi (World
##   cảnh báo tiến trình chưa lưu); không có → thoát.

signal transition_finished

## Thời gian mờ / sáng (giây; test đặt ngắn hơn).
static var fade_time: float = 0.25

static var _instance: AppOverlay

var _fade: ColorRect
var _fps_label: Label
var _busy: bool = false
var _tween: Tween


## Tạo (nếu chưa có) và trả về lớp phủ; nạp + áp dụng GameSettings.
static func ensure(tree: SceneTree) -> AppOverlay:
	if _instance == null or not is_instance_valid(_instance):
		_instance = AppOverlay.new()
		_instance.name = "AppOverlay"
		tree.root.add_child.call_deferred(_instance)
		tree.auto_accept_quit = false
	return _instance


static func get_instance() -> AppOverlay:
	return _instance if _instance != null and is_instance_valid(_instance) else null


## Đang chuyển cảnh (input người chơi bị chặn).
static func is_transitioning() -> bool:
	return get_instance() != null and _instance._busy


func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fps_label = Label.new()
	_fps_label.name = "FPS"
	_fps_label.position = Vector2(8, 4)
	_fps_label.add_theme_color_override(&"font_color", Color(0.6, 1, 0.6))
	_fps_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override(&"outline_size", 4)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fps_label)


func _ready() -> void:
	var settings: GameSettings = GameSettings.get_instance()
	settings.changed.connect(func(_key: StringName) -> void: _refresh_fps_visibility())
	_refresh_fps_visibility()


func _process(_delta: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var scene: Node = get_tree().current_scene
		if scene != null and scene.has_method(&"request_quit"):
			scene.call(&"request_quit")
		else:
			get_tree().quit()


func is_busy() -> bool:
	return _busy


## Chặn input trong lúc chuyển cảnh (lớp phủ là node cuối của /root nên nhận _input trước scene).
func _input(event: InputEvent) -> void:
	if _busy and not (event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


## Đổi sang scene `path` có màn đen + dừng game. `on_loaded(scene)` chạy khi scene mới sẵn sàng (trước khi bỏ dừng).
## Lỗi đổi scene → trả lỗi, sáng lại scene cũ.
func change_scene(path: String, on_loaded: Callable = Callable()) -> Error:
	if _busy:
		return ERR_BUSY
	_busy = true
	if not is_inside_tree():
		await ready
	var tree: SceneTree = get_tree()
	get_parent().move_child(self, -1)
	tree.paused = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	var err: Error = tree.change_scene_to_file(path)
	if err != OK:
		push_warning("[AppOverlay] Không mở được %s (%s)." % [path, error_string(err)])
		tree.paused = false
		await _finish()
		return err
	await tree.scene_changed
	# Scene mới được thêm sau lớp phủ → đưa lớp phủ về cuối để vẫn nhận _input trước.
	get_parent().move_child(self, -1)
	await tree.process_frame
	if on_loaded.is_valid() and tree.current_scene != null:
		on_loaded.call(tree.current_scene)
	tree.paused = false
	await _finish()
	return OK


func _finish() -> void:
	_busy = false
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	await _fade_to(0.0)
	transition_finished.emit()


func _fade_to(alpha: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_fade, "color:a", alpha, fade_time)
	await _tween.finished


func _refresh_fps_visibility() -> void:
	_fps_label.visible = bool(GameSettings.get_instance().get_value(&"show_fps"))
