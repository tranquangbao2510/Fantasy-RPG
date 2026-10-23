extends Node2D
## Training Dummy (placeholder): mục tiêu đứng yên, không AI. Toàn bộ HP/nhận đòn/phản hồi nằm ở component con.
## Hình: một ảnh tĩnh (ObjectSprite `training_dummy`); trúng đòn → ảnh rung ngang (bóng đứng yên) — TASK M7.

## Biên độ (px world) và thời gian rung khi trúng đòn.
@export var shake_amplitude: float = 2.0
@export var shake_duration: float = 0.25

var _shake_tween: Tween

@onready var _health: HealthComponent = $HealthComponent
@onready var _sprite: Node2D = $Visual/Sprite


func _ready() -> void:
	_health.damaged.connect(_on_damaged)


func is_dead() -> bool:
	return _health.is_dead()


## Đang rung (vừa trúng đòn).
func is_shaking() -> bool:
	return _shake_tween != null and _shake_tween.is_running()


## Reset thử nghiệm: hồi đầy HP.
func reset_state() -> void:
	_health.reset()


func _on_damaged(_amount: int) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	_sprite.position = Vector2.ZERO
	_shake_tween = create_tween()
	var step: float = shake_duration / 5.0
	for k: int in 4:
		var side: float = shake_amplitude * (1.0 - k / 4.0) * (1.0 if k % 2 == 0 else -1.0)
		_shake_tween.tween_property(_sprite, ^"position:x", side, step)
	_shake_tween.tween_property(_sprite, ^"position:x", 0.0, step)
