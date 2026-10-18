class_name Enemy
extends CharacterBody2D
## Enemy prototype dùng chung cho mọi kiểu hành vi thử nghiệm. Khác biệt nằm ở dữ liệu export và
## AttackComponent gắn vào (MeleeAttack, RangedAttack), không ở script riêng.
## State: IDLE → CHASE → ATTACK → RECOVERY (đang hồi đòn) → DEAD. Không pathfinding (có thể kẹt sau vật cản).
## Chỉ đọc vị trí và is_dead() của target; không truy cập HP. Di chuyển + knockback luôn qua move_and_slide().

signal state_changed(state: State)

enum State { IDLE, CHASE, ATTACK, RECOVERY, DEAD }

enum MovementMode {
	CHASE,         ## Đuổi tới tầm đánh rồi tấn công (Melee Chaser).
	STATIONARY,    ## Không di chuyển; tấn công khi target vào tầm (Stationary Attacker).
	KEEP_DISTANCE, ## Giữ khoảng cách preferred_distance, tấn công trong tầm (Ranged).
}

@export var target: Node2D
@export var movement_mode: MovementMode = MovementMode.CHASE
@export var move_speed: float = 70.0
## Chỉ phát hiện target trong khoảng này (px, từ chân tới chân).
@export var detection_range: float = 150.0
## Tỉ lệ của attack.attack_range dùng làm khoảng cách bắt đầu tấn công.
@export_range(0.1, 1.0) var attack_trigger_ratio: float = 0.8
## KEEP_DISTANCE: lùi lại khi target gần hơn preferred_distance × retreat_ratio.
@export var preferred_distance: float = 110.0
@export_range(0.1, 1.0) var retreat_ratio: float = 0.75
@export var attack: AttackComponent

var _state: State = State.IDLE
var _spawn_position: Vector2

@onready var _health: HealthComponent = $HealthComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent


func _ready() -> void:
	_spawn_position = global_position
	_health.died.connect(_on_died)


func _physics_process(_delta: float) -> void:
	if _state == State.DEAD:
		return
	velocity = Vector2.ZERO
	_set_state(_think())
	# Knockback cộng vào velocity rồi đi qua move_and_slide() nên vật cản vẫn chặn.
	velocity += _knockback.get_velocity()
	move_and_slide()


func get_state() -> State:
	return _state


func get_health() -> HealthComponent:
	return _health


func is_dead() -> bool:
	return _health.is_dead()


## Reset thử nghiệm: về vị trí spawn, hồi đầy HP, hủy đòn đang đánh.
func reset_state() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_knockback.clear()
	if attack != null:
		attack.cancel()
	_health.reset()
	_set_state(State.IDLE)


## Quyết định state và velocity (chưa gồm knockback) cho tick này.
func _think() -> State:
	if attack == null or not _has_live_target():
		return State.IDLE
	if attack.is_attacking():
		return State.ATTACK
	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	if distance > detection_range:
		return State.IDLE
	var in_range: bool = distance <= attack.attack_range * attack_trigger_ratio
	if movement_mode == MovementMode.KEEP_DISTANCE and distance < preferred_distance * retreat_ratio:
		velocity = -to_target / distance * move_speed
		return State.CHASE
	if in_range:
		if attack.attack(to_target):
			return State.ATTACK
		return State.RECOVERY if attack.is_recovering() else State.ATTACK
	if movement_mode == MovementMode.STATIONARY:
		return State.IDLE
	velocity = to_target / distance * move_speed
	return State.CHASE


func _set_state(state: State) -> void:
	if state != _state:
		_state = state
		state_changed.emit(_state)


func _has_live_target() -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method(&"is_dead"):
		var target_dead: bool = target.call(&"is_dead")
		return not target_dead
	return true


func _on_died() -> void:
	velocity = Vector2.ZERO
	if attack != null:
		attack.cancel()
	_set_state(State.DEAD)
