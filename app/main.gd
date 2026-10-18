extends Control
## Màn hình khởi động tạm thời (TASK 01).
## Chỉ xác nhận project đã khởi tạo; sẽ được thay thế khi có luồng ứng dụng chính thức.

@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	var project_name: String = ProjectSettings.get_setting("application/config/name", "Fantasy RPG")
	var engine_version: String = Engine.get_version_info().get("string", "unknown")
	_status_label.text = "%s\nKhởi tạo dự án thành công.\nGodot %s" % [project_name, engine_version]
	print("[Main] %s started (Godot %s)." % [project_name, engine_version])
