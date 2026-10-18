extends Node2D
## Training Dummy (placeholder): mục tiêu đứng yên, không AI. Toàn bộ HP/nhận đòn/phản hồi nằm ở component con.

@onready var _health: HealthComponent = $HealthComponent


func is_dead() -> bool:
	return _health.is_dead()


## Reset thử nghiệm: hồi đầy HP.
func reset_state() -> void:
	_health.reset()
