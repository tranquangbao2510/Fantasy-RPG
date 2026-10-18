class_name Hurtbox
extends Area2D
## Vùng nhận đòn của một thực thể; chuyển sát thương vào HealthComponent được gán.
## Không chứa logic điều khiển hay AI. Phe được xác định bằng collision_layer (player_hurtbox / enemy_hurtbox).

signal hit_received(info: DamageInfo, applied: int)

const GROUP: StringName = &"hurtboxes"

@export var health: HealthComponent


func _ready() -> void:
	add_to_group(GROUP)


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
	return info != null and info.is_valid() and health != null and not health.is_dead() and info.source != owner


## Nhận sát thương. Trả về lượng HP thực sự bị trừ.
func receive_damage(info: DamageInfo) -> int:
	if not can_receive(info):
		return 0
	var applied: int = health.apply_damage(info.amount)
	if applied > 0:
		hit_received.emit(info, applied)
	return applied
