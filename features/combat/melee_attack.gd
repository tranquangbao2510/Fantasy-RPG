class_name MeleeAttack
extends Node2D
## Đòn cận chiến dùng chung cho Player và enemy.
## attack(direction): xoay theo hướng → (windup) → bật Hitbox trong `duration` → nghỉ `cooldown`.
## Chỉ xoay node này (Hitbox + visual), không xoay thực thể.
## Mọi thông số là placeholder, chỉnh trong Inspector của từng instance.

signal attack_started(direction: Vector2)
signal attack_finished

enum Phase { READY, WINDUP, ACTIVE, COOLDOWN }

@export var damage: int = 10
## Tầm với (px) tính từ vị trí node này theo hướng tấn công.
@export var attack_range: float = 28.0
@export var attack_width: float = 24.0
## Thời gian báo trước trước khi Hitbox bật (0 = đánh ngay).
@export var windup: float = 0.0
@export var duration: float = 0.12
@export var cooldown: float = 0.35
## Hurtbox layer mà đòn này nhắm tới (phe đối địch).
@export_flags_2d_physics var target_layers: int = 0
## HP của chủ thể; không tấn công khi đã chết.
@export var health: HealthComponent
@export var windup_color: Color = Color(1, 0.6, 0.2, 0.35)
@export var active_color: Color = Color(1, 1, 0.8, 0.6)

var _phase: Phase = Phase.READY
var _time_left: float = 0.0

@onready var _hitbox: Hitbox = $Hitbox
@onready var _shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(attack_range, attack_width)
	_shape.shape = rect
	_shape.position = Vector2(attack_range / 2.0, 0.0)
	var half: float = attack_width / 2.0
	_visual.polygon = PackedVector2Array([
		Vector2(0, -half), Vector2(attack_range, -half), Vector2(attack_range, half), Vector2(0, half)])
	_visual.hide()
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = target_layers


func can_attack() -> bool:
	return _phase == Phase.READY and not _is_owner_dead()


func is_attacking() -> bool:
	return _phase == Phase.WINDUP or _phase == Phase.ACTIVE


func get_hitbox() -> Hitbox:
	return _hitbox


## Bắt đầu một đòn. Trả về false nếu đang bận, đang nghỉ hoặc chủ thể đã chết.
func attack(direction: Vector2) -> bool:
	if not can_attack() or direction.is_zero_approx():
		return false
	rotation = direction.angle()
	attack_started.emit(direction.normalized())
	if windup > 0.0:
		_phase = Phase.WINDUP
		_time_left = windup
		_visual.color = windup_color
		_visual.show()
	else:
		_start_active()
	return true


## Hủy đòn đang diễn ra và xóa cooldown (dùng khi chết / reset).
func cancel() -> void:
	_hitbox.deactivate()
	_visual.hide()
	_phase = Phase.READY
	_time_left = 0.0


func _physics_process(delta: float) -> void:
	if _phase == Phase.READY:
		return
	if is_attacking() and _is_owner_dead():
		cancel()
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	match _phase:
		Phase.WINDUP:
			_start_active()
		Phase.ACTIVE:
			_hitbox.deactivate()
			_visual.hide()
			_phase = Phase.COOLDOWN
			_time_left = cooldown
			attack_finished.emit()
		Phase.COOLDOWN:
			_phase = Phase.READY


func _start_active() -> void:
	_phase = Phase.ACTIVE
	_time_left = duration
	_visual.color = active_color
	_visual.show()
	_hitbox.activate(DamageInfo.new(damage, owner))


func _is_owner_dead() -> bool:
	return health != null and health.is_dead()
