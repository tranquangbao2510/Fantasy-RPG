class_name GameCamera
extends Camera2D
## Camera theo target, zoom theo bậc, giới hạn trong vùng bản đồ (TASK 05; zoom lẻ từ TASK VISUAL 01).
## Không biết gì về Player hay map cụ thể: bên ngoài gọi set_target() và set_map_rect().
## Smoothing dùng thuộc tính có sẵn của Camera2D (position_smoothing_enabled / _speed).
## Mặc định zoom_step = 1 (mức nguyên như map pixel cũ). Map vẽ tay đặt zoom_step < 1 (vd. 0.25):
## không ép integer scaling; texture dùng lọc tuyến tính + mipmap nên không vỡ hạt khi zoom lẻ.

@export var default_zoom: float = 2.0
@export var min_zoom: float = 1.0
@export var max_zoom: float = 4.0
## Bước zoom mỗi nấc lăn chuột; zoom luôn là bội số của bước này.
@export var zoom_step: float = 1.0

var _target: Node2D
var _map_rect: Rect2
var _has_map_rect: bool = false
var _requested_zoom: float = 2.0
var _fallback_warned: bool = false


func _ready() -> void:
	_requested_zoom = default_zoom
	get_viewport().size_changed.connect(_apply_zoom)
	_apply_zoom()


func _physics_process(_delta: float) -> void:
	# Target di chuyển trong physics tick nên camera cũng cập nhật ở đây (process_callback = Physics).
	if is_instance_valid(_target):
		global_position = _get_follow_position()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"camera_zoom_in"):
		_change_zoom(1)
	elif event.is_action_pressed(&"camera_zoom_out"):
		_change_zoom(-1)


## Đặt node cần theo dõi. Camera nhảy ngay tới target, không trượt từ vị trí cũ.
func set_target(target: Node2D) -> void:
	_target = target
	if not is_instance_valid(_target):
		push_warning("[GameCamera] Target không hợp lệ; camera đứng yên.")
		return
	global_position = _get_follow_position()
	reset_smoothing()


## Đặt vùng bản đồ (world coordinates). Camera không nhìn ra ngoài vùng này.
func set_map_rect(rect: Rect2) -> void:
	_map_rect = rect
	_has_map_rect = true
	limit_left = floori(rect.position.x)
	limit_top = floori(rect.position.y)
	limit_right = ceili(rect.end.x)
	limit_bottom = ceili(rect.end.y)
	_apply_zoom()


## Mức zoom hiện tại (số nguyên gần nhất; giữ cho code cũ).
func get_zoom_level() -> int:
	return roundi(zoom.x)


func get_zoom_value() -> float:
	return zoom.x


func _change_zoom(direction: int) -> void:
	_requested_zoom = clampf(_snap(zoom.x + direction * zoom_step), min_zoom, max_zoom)
	_apply_zoom()


func _snap(value: float) -> float:
	return roundf(value / zoom_step) * zoom_step


## Zoom thực tế = mức người chơi chọn, nhưng không nhỏ hơn mức tối thiểu (bội số zoom_step) để vùng nhìn nằm gọn trong map.
func _apply_zoom() -> void:
	var lowest: float = maxf(min_zoom, _get_min_zoom_covering_map())
	var level: float = clampf(_requested_zoom, lowest, max_zoom)
	if lowest > max_zoom:
		# Viewport quá lớn so với map: vượt max_zoom thay vì để lộ vùng ngoài bản đồ.
		level = lowest
		if not _fallback_warned:
			push_warning("[GameCamera] Viewport quá lớn so với map; dùng zoom %.2fx (vượt max_zoom)." % level)
			_fallback_warned = true
	zoom = Vector2(level, level)
	if is_instance_valid(_target):
		global_position = _get_follow_position()


func _get_min_zoom_covering_map() -> float:
	if not _has_map_rect or _map_rect.size.x <= 0.0 or _map_rect.size.y <= 0.0:
		return zoom_step
	var view: Vector2 = get_viewport_rect().size
	var ratio: float = maxf(view.x / _map_rect.size.x, view.y / _map_rect.size.y)
	return maxf(zoom_step, ceilf(ratio / zoom_step - 0.0001) * zoom_step)


## Vị trí target, kẹp sao cho nửa vùng nhìn không vượt mép map.
## Kẹp trước khi smoothing để camera không "trôi" quá limit rồi bị chậm khi quay lại.
func _get_follow_position() -> Vector2:
	var pos: Vector2 = _target.global_position
	if not _has_map_rect:
		return pos
	var half_view: Vector2 = get_viewport_rect().size / zoom / 2.0
	var min_pos: Vector2 = _map_rect.position + half_view
	var max_pos: Vector2 = _map_rect.end - half_view
	pos.x = _map_rect.get_center().x if min_pos.x > max_pos.x else clampf(pos.x, min_pos.x, max_pos.x)
	pos.y = _map_rect.get_center().y if min_pos.y > max_pos.y else clampf(pos.y, min_pos.y, max_pos.y)
	return pos
