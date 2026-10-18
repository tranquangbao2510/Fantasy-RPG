extends CharacterBody2D
## Player placeholder (TASK 04): di chuyển liên tục 8 hướng.
## Origin đặt tại chân nhân vật để Y-sort đúng trong EntityContainer.

@export var move_speed: float = 160.0

@onready var _facing_pivot: Node2D = $Visual/FacingPivot


func _physics_process(_delta: float) -> void:
	# get_vector giới hạn độ dài <= 1 nên đi chéo không nhanh hơn đi thẳng.
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * move_speed
	move_and_slide()
	if direction != Vector2.ZERO:
		_facing_pivot.rotation = direction.angle()
