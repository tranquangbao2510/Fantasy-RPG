class_name AttackComponent
extends Node2D
## Base class mỏng cho đòn tấn công đơn của enemy (cận chiến, tầm xa).
## Nhịp chung: attack(direction) → xoay theo hướng → WINDUP (telegraph) → ACTIVE → COOLDOWN (hồi) → READY.
## Hướng được chốt lúc gọi attack(); chỉ xoay node này, không xoay thực thể.
## Lớp con override _on_windup_started / _on_active_started / _on_active_ended / _on_cancelled.
## Mọi thông số là placeholder, chỉnh trong Inspector của từng instance.

signal attack_started(direction: Vector2)
signal attack_finished

enum Phase { READY, WINDUP, ACTIVE, COOLDOWN }

@export var damage: int = 10
## Tầm đánh (px) tính từ vị trí node này; AI dùng để quyết định khi nào tấn công.
@export var attack_range: float = 28.0
## Thời gian báo trước (telegraph) trước khi đòn có hiệu lực (0 = ngay).
@export var windup: float = 0.0
## Thời gian đòn có hiệu lực.
@export var duration: float = 0.12
## Thời gian hồi sau đòn.
@export var cooldown: float = 0.35
## Hurtbox layer mà đòn này nhắm tới (phe đối địch).
@export_flags_2d_physics var target_layers: int = 0
## HP của chủ thể; không tấn công khi đã chết.
@export var health: HealthComponent
@export var windup_color: Color = Color(1, 0.6, 0.2, 0.35)
@export var active_color: Color = Color(1, 1, 0.8, 0.6)

var _phase: Phase = Phase.READY
var _time_left: float = 0.0


func get_phase() -> Phase:
	return _phase


func can_attack() -> bool:
	return _phase == Phase.READY and not _is_owner_dead()


func is_attacking() -> bool:
	return _phase == Phase.WINDUP or _phase == Phase.ACTIVE


## Đang hồi sau đòn.
func is_recovering() -> bool:
	return _phase == Phase.COOLDOWN


## Bắt đầu một đòn. Trả về false nếu đang bận, đang hồi hoặc chủ thể đã chết.
func attack(direction: Vector2) -> bool:
	if not can_attack() or direction.is_zero_approx():
		return false
	rotation = direction.angle()
	attack_started.emit(direction.normalized())
	if windup > 0.0:
		_phase = Phase.WINDUP
		_time_left = windup
		_on_windup_started()
	else:
		_start_active()
	return true


## Hủy đòn đang diễn ra và xóa thời gian hồi (chết / reset).
func cancel() -> void:
	_phase = Phase.READY
	_time_left = 0.0
	_on_cancelled()


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
			_on_active_ended()
			_phase = Phase.COOLDOWN
			_time_left = cooldown
			attack_finished.emit()
		Phase.COOLDOWN:
			_phase = Phase.READY


func _start_active() -> void:
	_phase = Phase.ACTIVE
	_time_left = duration
	_on_active_started()


func _on_windup_started() -> void:
	pass


func _on_active_started() -> void:
	pass


func _on_active_ended() -> void:
	pass


func _on_cancelled() -> void:
	pass


func _is_owner_dead() -> bool:
	return health != null and health.is_dead()
