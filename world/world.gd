extends Node2D
## Gốc của môi trường game (TASK 02).
## Chỉ cung cấp các container; không chứa logic gameplay.
## Các module khác thêm node vào container qua các hàm public bên dưới.

@onready var _environment: Node2D = $Environment
@onready var _map_container: Node2D = $MapContainer
@onready var _entity_container: Node2D = $EntityContainer
@onready var _camera_container: Node2D = $CameraContainer


func get_environment_container() -> Node2D:
	return _environment


func get_map_container() -> Node2D:
	return _map_container


func get_entity_container() -> Node2D:
	return _entity_container


func get_camera_container() -> Node2D:
	return _camera_container
