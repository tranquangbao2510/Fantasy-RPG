extends SceneTree
## Nền chung cho mọi test headless (TASK M2, mục 0). Test kế thừa file này (`extends "res://tests/test_base.gd"`),
## viết `_run_tests()` (có thể await) và dùng check() / frames() / expect_error().
##
## Test FAIL (thoát mã 1) khi:
## - có ca check() sai;
## - có lỗi engine/script trong lúc chạy mà không được khai báo trước bằng expect_error(): push_error, lỗi runtime
##   GDScript (gọi hàm trên null / instance đã free...), lỗi biên dịch script nạp lúc chạy, lỗi nạp resource...
##   (bắt qua OS.add_logger — cảnh báo push_warning không tính);
## - script test không biên dịch được (Godot thoát mã 1 trước khi chạy);
## - khai báo expect_error() mà lỗi đó không xảy ra.
## Kết quả in "RESULT <đạt>/<tổng> passed" + danh sách lỗi ngoài dự kiến. Chạy tất cả: tests/run_all.gd.
##
## Lưu ý: script test được biên dịch TRƯỚC khi Autoload đăng ký → không dùng tên Autoload (SaveService) trực tiếp
## trong file test (dùng preload script + /root/<Tên>), không khai báo kiểu bằng class có dùng tên Autoload (vd. World —
## dùng Node rồi truy cập thuộc tính động), và mọi thứ chạy sau _init (call_deferred).


class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _mutex: Mutex = Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var text: String = rationale if not rationale.is_empty() else code
		_mutex.lock()
		errors.append("%s (%s:%d %s)" % [text, file.get_file(), line, function])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var result: Array[String] = errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return result


var _passed: int = 0
var _failed: int = 0
var _catcher: ErrorCatcher = ErrorCatcher.new()
## Chuỗi con của lỗi được phép xuất hiện → số lần đã gặp.
var _expected: Dictionary[String, int] = {}
var _unexpected: Array[String] = []


## TASK M6: cài đặt + save của test tách khỏi dữ liệu thật của người chơi (user://settings.cfg, user://saves/).
const TEST_SETTINGS_PATH: String = "user://test_settings.cfg"
const TEST_DEFAULT_SAVE_DIR: String = "user://test_saves_default/"


func _init() -> void:
	OS.add_logger(_catcher)
	GameSettings.config_path = TEST_SETTINGS_PATH
	DirAccess.remove_absolute(TEST_SETTINGS_PATH)
	DebugKeys.simulate_release = false
	AppOverlay.fade_time = 0.02
	_start.call_deferred()


func _start() -> void:
	var saves: Node = root.get_node_or_null(^"SaveService")
	if saves != null:
		saves.set(&"save_dir", TEST_DEFAULT_SAVE_DIR)
		saves.set(&"capture_thumbnails", false)
	await _run_tests()
	finish()


## Lớp con override. Chạy sau khi SceneTree khởi động (Autoload đã có).
func _run_tests() -> void:
	pass


func check(label: String, ok: bool, detail: String = "") -> void:
	_collect_errors()
	print("%s %s %s" % ["PASS" if ok else "FAIL", label, detail])
	if ok:
		_passed += 1
	else:
		_failed += 1


## Cho phép lỗi có chứa `fragment` (vd. lỗi cố ý khi thử file save hỏng). Gọi trước khi gây lỗi.
func expect_error(fragment: String) -> void:
	_collect_errors()
	if not _expected.has(fragment):
		_expected[fragment] = 0


func frames(count: int) -> void:
	for i: int in count:
		await physics_frame


func seconds(duration: float) -> void:
	await create_timer(duration, true, true).timeout


## Gửi một action qua hệ thống input thật (Input → viewport → _input/_unhandled_input của node).
func press_action(action: StringName, pressed: bool = true) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func tap_action(action: StringName) -> void:
	press_action(action, true)
	await process_frame
	press_action(action, false)
	await process_frame


func finish() -> void:
	_collect_errors()
	for fragment: String in _expected:
		if _expected[fragment] == 0:
			print("FAIL expected_error_missing '%s'" % fragment)
			_failed += 1
	for error: String in _unexpected:
		print("FAIL unexpected_error %s" % error)
	var failed: int = _failed + _unexpected.size()
	print("RESULT %d/%d passed%s" % [_passed, _passed + _failed, (" · %d lỗi ngoài dự kiến" % _unexpected.size()) if not _unexpected.is_empty() else ""])
	quit(1 if failed > 0 else 0)


func _collect_errors() -> void:
	for error: String in _catcher.take():
		var allowed: bool = false
		for fragment: String in _expected:
			if error.contains(fragment):
				_expected[fragment] += 1
				allowed = true
				break
		if not allowed:
			_unexpected.append(error)


## Xóa mọi file + thư mục con trong `path` (giữ thư mục `path`). TASK M6: ô save là thư mục con.
func clear_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		clear_dir(path.path_join(sub))
		dir.remove(sub)
	for file: String in dir.get_files():
		dir.remove(file)
