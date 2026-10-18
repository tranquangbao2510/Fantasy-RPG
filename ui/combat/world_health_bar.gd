class_name WorldHealthBar
extends Node2D
## Thanh HP nhỏ vẽ trong world (trên đầu thực thể). Cập nhật qua signal health_changed.

@export var health: HealthComponent
@export var bar_size: Vector2 = Vector2(24, 3)
@export var fill_color: Color = Color(0.85, 0.2, 0.2)
@export var back_color: Color = Color(0, 0, 0, 0.6)


func _ready() -> void:
	if health != null:
		health.health_changed.connect(_on_health_changed)
	queue_redraw()


func _on_health_changed(_current: int, _maximum: int) -> void:
	queue_redraw()


func _draw() -> void:
	if health == null:
		return
	var origin: Vector2 = -bar_size / 2.0
	draw_rect(Rect2(origin - Vector2.ONE, bar_size + Vector2(2, 2)), back_color)
	var ratio: float = clampf(float(health.current_health) / float(health.max_health), 0.0, 1.0)
	if ratio > 0.0:
		draw_rect(Rect2(origin, Vector2(bar_size.x * ratio, bar_size.y)), fill_color)
