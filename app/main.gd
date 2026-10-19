extends Control
## Màn hình khởi động tạm thời.
## Hiển thị trạng thái project; "Tiếp tục" tải save slot 1 (mờ nếu chưa có save). Các nút còn lại bắt đầu phiên mới
## (SaveService.new_session) và chuyển vào World Scene, Combat Sandbox hoặc Environment Prototype (scene thử nghiệm).

const WORLD_SCENE_PATH: String = "res://world/world.tscn"
const SANDBOX_SCENE_PATH: String = "res://world/sandbox/combat_sandbox.tscn"
const ENVIRONMENT_SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"

@onready var _status_label: Label = %StatusLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _enter_button: Button = %EnterButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _environment_button: Button = %EnvironmentButton


func _ready() -> void:
	var project_name: String = ProjectSettings.get_setting("application/config/name", "Fantasy RPG")
	var engine_version: String = Engine.get_version_info().get("string", "unknown")
	_status_label.text = "%s\nGodot %s" % [project_name, engine_version]
	_continue_button.disabled = not SaveService.has_save()
	_continue_button.pressed.connect(_continue)
	_enter_button.pressed.connect(_change_scene.bind(WORLD_SCENE_PATH))
	_sandbox_button.pressed.connect(_change_scene.bind(SANDBOX_SCENE_PATH))
	_environment_button.pressed.connect(_change_scene.bind(ENVIRONMENT_SCENE_PATH))
	if not _continue_button.disabled:
		_continue_button.grab_focus()
	else:
		_enter_button.grab_focus()


func _continue() -> void:
	_set_buttons_disabled(true)
	if not SaveService.load_game():
		_status_label.text = "Không tải được save.\n%s" % SaveService.last_error
		_set_buttons_disabled(false)
		_continue_button.disabled = not SaveService.has_save()


func _change_scene(path: String) -> void:
	_set_buttons_disabled(true)
	SaveService.new_session()
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("[Main] Không thể chuyển sang %s (lỗi %s)." % [path, error_string(error)])
		_status_label.text = "Không thể tải scene.\n%s" % error_string(error)
		_set_buttons_disabled(false)
		_continue_button.disabled = not SaveService.has_save()


func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in [_continue_button, _enter_button, _sandbox_button, _environment_button]:
		button.disabled = disabled
