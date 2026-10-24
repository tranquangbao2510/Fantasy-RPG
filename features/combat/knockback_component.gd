class_name KnockbackComponent
extends Node
## Xung lực đẩy lùi đơn giản cho CharacterBody2D. Nhận DamageInfo.knockback qua Hurtbox.hit_received,
## giảm dần theo `decay`. Script thân thực thể cộng get_velocity() vào velocity trước move_and_slide(),
## nên vật cản vẫn chặn bình thường (không đổi transform trực tiếp).

@export var hurtbox: Hurtbox
@export var health: HealthComponent
## Hệ số nhân knockback nhận vào (0 = miễn nhiễm).
@export var strength_multiplier: float = 1.0
## Độ giảm tốc (px/s²).
@export var decay: float = 900.0

var _velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
	if hurtbox != null:
		hurtbox.hit_received.connect(_on_hit_received)
	if health != null:
		health.died.connect(clear)


func get_velocity() -> Vector2:
	return _velocity


## Thay xung lực đang giảm dần (vd. bỏ thành phần đẩy vào vùng cấm — Enemy._keep_out_of_light).
func set_velocity(value: Vector2) -> void:
	_velocity = value


func clear() -> void:
	_velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_velocity = _velocity.move_toward(Vector2.ZERO, decay * delta)


func _on_hit_received(info: DamageInfo, _applied: int) -> void:
	if health != null and health.is_dead():
		return
	var impulse: Vector2 = info.knockback * strength_multiplier
	if not impulse.is_zero_approx():
		_velocity = impulse
