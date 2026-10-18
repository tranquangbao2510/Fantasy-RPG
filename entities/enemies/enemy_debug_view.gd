class_name EnemyDebugView
extends Node2D
## Thông tin debug của một Enemy (chỉ hiển thị): vòng detection_range, vòng tầm đánh, tên state.
## Bật/tắt chung qua group `debug_info` (set_debug_visible); enemy sinh ra sau đọc trạng thái chung `shown`.

const GROUP: StringName = &"debug_info"

static var shown: bool = false

@export var enemy: Enemy


func _ready() -> void:
	add_to_group(GROUP)
	visible = shown
	if enemy != null:
		enemy.state_changed.connect(func(_state: Enemy.State) -> void: queue_redraw())


func set_debug_visible(value: bool) -> void:
	shown = value
	visible = value
	queue_redraw()


func _draw() -> void:
	if enemy == null:
		return
	draw_arc(Vector2.ZERO, enemy.detection_range, 0.0, TAU, 48, Color(1, 1, 0.4, 0.35), 1.0)
	if enemy.attack != null:
		var reach: float = enemy.attack.attack_range * enemy.attack_trigger_ratio
		draw_arc(enemy.attack.position, reach, 0.0, TAU, 32, Color(1, 0.4, 0.3, 0.5), 1.0)
	if enemy.movement_mode == Enemy.MovementMode.KEEP_DISTANCE:
		draw_arc(Vector2.ZERO, enemy.preferred_distance * enemy.retreat_ratio, 0.0, TAU, 32, Color(0.4, 0.8, 1, 0.4), 1.0)
	var text: String = Enemy.State.keys()[enemy.get_state()]
	draw_string(ThemeDB.fallback_font, Vector2(-24, -44), text, HORIZONTAL_ALIGNMENT_CENTER, 48, 10, Color.WHITE)
