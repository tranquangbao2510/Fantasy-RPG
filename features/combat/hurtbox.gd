class_name Hurtbox
extends Area2D
## Vùng nhận đòn của một thực thể; chuyển sát thương vào HealthComponent được gán.
## Không chứa logic điều khiển hay AI. Phe được xác định bằng collision_layer (player_hurtbox / enemy_hurtbox).

signal hit_received(info: DamageInfo, applied: int)

const GROUP: StringName = &"hurtboxes"

@export var health: HealthComponent
## Giáp (TASK M4): giảm sát thương nhận vào theo DamageInfo.mitigate(). Player đặt theo đồ đang mặc.
var armor: int = 0
## Tầng hiện tại của thực thể (bit mask, xem DamageInfo.tier_mask). 0 = không lọc. Map có elevation đặt qua set_elevation().
var tier_mask: int = 0

## Thời gian bất tử còn lại (giây, vd. i-frame khi né — TASK M2). > 0 thì không nhận đòn.
var _invulnerable_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_invulnerable_left -= delta
	if _invulnerable_left <= 0.0:
		_invulnerable_left = 0.0
		set_physics_process(false)


## Bất tử trong `seconds` giây (không rút ngắn khoảng đang có).
func set_invulnerable(seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, seconds)
	set_physics_process(_invulnerable_left > 0.0)


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Khóa chống trúng nhiều lần trong một đòn: nhiều Hurtbox cùng một HealthComponent tính là một mục tiêu.
func get_damage_key() -> Object:
	return health if health != null else self


## Vị trí world đại diện cho điểm trúng đòn (tâm shape đầu tiên), dùng cho phản hồi hình ảnh.
func get_hit_position() -> Vector2:
	for child: Node in get_children():
		var shape: CollisionShape2D = child as CollisionShape2D
		if shape != null:
			return shape.global_position
	return global_position


func can_receive(info: DamageInfo) -> bool:
	return info != null and info.is_valid() and health != null and not health.is_dead() and info.source != owner and not is_invulnerable() \
		and (info.tier_mask == 0 or tier_mask == 0 or (info.tier_mask & tier_mask) != 0)


## Cấu hình từ hệ thống elevation (duck-typing, không phụ thuộc module world). obstacle_mask, ground_z không dùng ở đây.
func set_elevation(p_tier_mask: int, _obstacle_mask: int, _ground_z: int) -> void:
	tier_mask = p_tier_mask


## Nhận sát thương. Trả về lượng HP thực sự bị trừ.
func receive_damage(info: DamageInfo) -> int:
	if not can_receive(info):
		return 0
	var applied: int = health.apply_damage(DamageInfo.mitigate(info.amount, armor))
	if applied > 0:
		hit_received.emit(info, applied)
	return applied
