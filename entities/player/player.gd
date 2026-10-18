extends CharacterBody2D
## Player placeholder: di chuyển liên tục 8 hướng và điều phối các component (combat, interaction, health).
## Origin đặt tại chân nhân vật để Y-sort đúng trong EntityContainer.
## Logic tấn công nằm trong MeleeAttack, HP trong HealthComponent; script này chỉ đọc input và nối trạng thái.

@export var move_speed: float = 160.0

## Hướng nhìn cuối cùng; dùng khi chuột trùng vị trí Player.
var _facing: Vector2 = Vector2.DOWN
var _spawn_position: Vector2

@onready var _facing_pivot: Node2D = $Visual/FacingPivot
@onready var _health: HealthComponent = $HealthComponent
@onready var _melee: MeleeAttack = $MeleeAttack
@onready var _interaction_detector: InteractionDetector = $InteractionDetector


func _ready() -> void:
	_spawn_position = global_position
	_health.died.connect(_on_died)


func _physics_process(_delta: float) -> void:
	if is_dead():
		velocity = Vector2.ZERO
		return
	# get_vector giới hạn độ dài <= 1 nên đi chéo không nhanh hơn đi thẳng.
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * move_speed
	move_and_slide()
	if direction != Vector2.ZERO:
		_set_facing(direction)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"basic_attack") and not is_dead():
		var direction: Vector2 = _get_attack_direction()
		if _melee.attack(direction):
			_set_facing(direction)
		get_viewport().set_input_as_handled()


func is_dead() -> bool:
	return _health.is_dead()


## Reset thử nghiệm: về spawn, hồi đầy HP, xóa vận tốc và đòn đang đánh, bật lại tương tác.
func reset_state() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_melee.cancel()
	_health.reset()
	_interaction_detector.set_enabled(true)
	_set_facing(Vector2.DOWN)


## Hướng tấn công từ điểm đánh tới world_point; điểm quá gần thì dùng hướng nhìn hiện tại.
func get_aim_direction(world_point: Vector2) -> Vector2:
	var to_point: Vector2 = world_point - _melee.global_position
	return to_point.normalized() if to_point.length() > 4.0 else _facing


func _get_attack_direction() -> Vector2:
	return get_aim_direction(get_global_mouse_position())


func _set_facing(direction: Vector2) -> void:
	_facing = direction.normalized()
	_facing_pivot.rotation = _facing.angle()


func _on_died() -> void:
	velocity = Vector2.ZERO
	_melee.cancel()
	_interaction_detector.set_enabled(false)
