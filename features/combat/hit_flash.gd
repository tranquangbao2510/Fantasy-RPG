class_name HitFlash
extends Node
## Phản hồi hình ảnh theo HealthComponent: nháy màu khi trúng đòn, tô xám khi chết, khôi phục khi hồi sinh.
## Chỉ đổi modulate của `visual`; không ảnh hưởng logic sát thương.

@export var health: HealthComponent
@export var visual: CanvasItem
@export var flash_color: Color = Color(1, 0.3, 0.3)
@export var dead_color: Color = Color(0.35, 0.35, 0.35, 0.85)
@export var flash_time: float = 0.15

var _tween: Tween


func _ready() -> void:
	if health == null or visual == null:
		return
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.revived.connect(_on_revived)


func _on_damaged(_amount: int) -> void:
	if health.is_dead():
		return
	_kill_tween()
	visual.modulate = flash_color
	_tween = create_tween()
	_tween.tween_property(visual, ^"modulate", Color.WHITE, flash_time)


func _on_died() -> void:
	_kill_tween()
	visual.modulate = dead_color


func _on_revived() -> void:
	_kill_tween()
	visual.modulate = Color.WHITE


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
