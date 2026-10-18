extends Control
## Màn hình khởi động tạm thời.
## Hiển thị trạng thái project và cho phép chuyển vào World Scene.

const WORLD_SCENE_PATH: String = "res://world/world.tscn"

@onready var _status_label: Label = %StatusLabel
@onready var _enter_button: Button = %EnterButton


func _ready() -> void:
	var project_name: String = ProjectSettings.get_setting("application/config/name", "Fantasy RPG")
	var engine_version: String = Engine.get_version_info().get("string", "unknown")
	_status_label.text = "%s\nGodot %s" % [project_name, engine_version]
	_enter_button.pressed.connect(_on_enter_button_pressed)
	_enter_button.grab_focus()


func _on_enter_button_pressed() -> void:
	_enter_button.disabled = true
	var error: Error = get_tree().change_scene_to_file(WORLD_SCENE_PATH)
	if error != OK:
		push_error("[Main] Không thể chuyển sang %s (lỗi %s)." % [WORLD_SCENE_PATH, error_string(error)])
		_status_label.text = "Không thể tải World Scene.\n%s" % error_string(error)
		_enter_button.disabled = false
