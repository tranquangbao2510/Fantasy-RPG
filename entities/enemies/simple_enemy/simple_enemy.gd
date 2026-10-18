extends CharacterBody2D
## Simple Enemy (placeholder): đứng yên khi target ở xa, đuổi khi vào detection_range,
## đứng lại và tấn công bằng MeleeAttack khi đủ gần. Không pathfinding; có thể bị kẹt sau vật cản.
## Chỉ đọc vị trí của target (và is_dead() nếu target có); không truy cập HP của target.

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var target: Node2D
@export var move_speed: float = 70.0
@export var detection_range: float = 150.0
## Tỉ lệ của MeleeAttack.attack_range dùng làm khoảng cách bắt đầu tấn công.
@export_range(0.1, 1.0) var attack_trigger_ratio: float = 0.8

var _state: State = State.IDLE
var _spawn_position: Vector2

@onready var _health: HealthComponent = $HealthComponent
@onready var _melee: MeleeAttack = $MeleeAttack
@onready var _knockback: KnockbackComponent = $KnockbackComponent


func _ready() -> void:
	_spawn_position = global_position
	_health.died.connect(_on_died)


func _physics_process(_delta: float) -> void:
	if _state == State.DEAD:
		return
	velocity = Vector2.ZERO
	if not _has_live_target():
		_state = State.IDLE
	else:
		var to_target: Vector2 = target.global_position - global_position
		var distance: float = to_target.length()
		if distance <= _melee.attack_range * attack_trigger_ratio or _melee.is_attacking():
			_state = State.ATTACK
			_melee.attack(to_target)
		elif distance <= detection_range:
			_state = State.CHASE
			velocity = to_target / distance * move_speed
		else:
			_state = State.IDLE
	# Knockback cộng vào velocity rồi đi qua move_and_slide() nên vật cản vẫn chặn.
	velocity += _knockback.get_velocity()
	move_and_slide()


func get_state() -> State:
	return _state


func is_dead() -> bool:
	return _health.is_dead()


## Reset thử nghiệm: về vị trí spawn, hồi đầy HP, hủy đòn đang đánh.
func reset_state() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_knockback.clear()
	_melee.cancel()
	_health.reset()
	_state = State.IDLE


func _has_live_target() -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method(&"is_dead"):
		var target_dead: bool = target.call(&"is_dead")
		return not target_dead
	return true


func _on_died() -> void:
	_state = State.DEAD
	velocity = Vector2.ZERO
	_melee.cancel()
