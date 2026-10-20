class_name EnemyDebugView
extends Node2D
## Thông tin debug của một Enemy (chỉ hiển thị): vòng phát hiện, vòng tầm đánh, tên state.
## Bật/tắt chung qua group `debug_info` (set_debug_visible); enemy sinh ra sau đọc trạng thái chung `shown`.
## TASK M4: vòng phát hiện là bán kính HIỆN TẠI (Enemy.get_detection_radius — đổi theo việc mục tiêu chạy / cầm đèn),
## vẽ là hình tròn trên mặt đất (ellipse trên map iso); đang đuổi thì thêm vòng bỏ cuộc (nét đứt mờ).

const GROUP: StringName = &"debug_info"

static var shown: bool = false

@export var enemy: Enemy


func _ready() -> void:
	add_to_group(GROUP)
	visible = shown
	set_process(shown)


func _process(_delta: float) -> void:
	queue_redraw()


func set_debug_visible(value: bool) -> void:
	shown = value
	visible = value
	set_process(value)
	queue_redraw()


func _draw() -> void:
	if enemy == null:
		return
	var squash: float = enemy.get_ground_squash()
	var radius: float = enemy.get_detection_radius()
	draw_polyline(_ring(radius, squash), Color(1, 1, 0.4, 0.45), 1.0)
	if enemy.is_hunting() and enemy.detection != null:
		draw_polyline(_ring(radius * enemy.detection.lose_multiplier, squash), Color(1, 0.6, 0.3, 0.25), 1.0)
	if enemy.attack != null:
		var reach: float = enemy.attack.attack_range * enemy.attack_trigger_ratio
		var points: PackedVector2Array = GroundSpace.circle(enemy.attack.position, reach, squash, 32)
		points.append(points[0])
		draw_polyline(points, Color(1, 0.4, 0.3, 0.5), 1.0)
	if enemy.movement_mode == Enemy.MovementMode.KEEP_DISTANCE:
		draw_polyline(_ring(enemy.preferred_distance * enemy.retreat_ratio, squash), Color(0.4, 0.8, 1, 0.4), 1.0)
	var text: String = Enemy.State.keys()[enemy.get_state()]
	draw_string(ThemeDB.fallback_font, Vector2(-30, -44), text, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color.WHITE)


func _ring(radius: float, squash: float) -> PackedVector2Array:
	var points: PackedVector2Array = GroundSpace.circle(Vector2.ZERO, radius, squash, 48)
	points.append(points[0])
	return points
