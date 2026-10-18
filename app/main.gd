extends Control
## Màn hình khởi động tạm thời.
## Hiển thị trạng thái project và cho phép chuyển vào World Scene, Combat Sandbox hoặc Environment Prototype (scene thử nghiệm).

const WORLD_SCENE_PATH: String = "res://world/world.tscn"
const SANDBOX_SCENE_PATH: String = "res://world/sandbox/combat_sandbox.tscn"
const ENVIRONMENT_SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"

@onready var _status_label: Label = %StatusLabel
@onready var _enter_button: Button = %EnterButton
@onready var _sandbox_button: Button = %SandboxButton
@onready var _environment_button: Button = %EnvironmentButton


func _ready() -> void:
	var project_name: String = ProjectSettings.get_setting("application/config/name", "Fantasy RPG")
	var engine_version: String = Engine.get_version_info().get("string", "unknown")
	_status_label.text = "%s\nGodot %s" % [project_name, engine_version]
	_enter_button.pressed.connect(_change_scene.bind(WORLD_SCENE_PATH))
	_sandbox_button.pressed.connect(_change_scene.bind(SANDBOX_SCENE_PATH))
	_environment_button.pressed.connect(_change_scene.bind(ENVIRONMENT_SCENE_PATH))
	_enter_button.grab_focus()


func _change_scene(path: String) -> void:
	_enter_button.disabled = true
	_sandbox_button.disabled = true
	_environment_button.disabled = true
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("[Main] Không thể chuyển sang %s (lỗi %s)." % [path, error_string(error)])
		_status_label.text = "Không thể tải scene.\n%s" % error_string(error)
		_enter_button.disabled = false
		_sandbox_button.disabled = false
		_environment_button.disabled = false
