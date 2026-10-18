class_name RangedAttack
extends AttackComponent
## Đòn tầm xa: windup hiện đường telegraph đúng hướng và đúng tầm bay của đạn → ACTIVE bắn một Projectile.
## Đạn được thêm vào cùng container với chủ thể (vd. EntityContainer), không phải con của enemy,
## nên vẫn bay khi enemy di chuyển; đạn tự hủy khi trúng / chạm vật cản / hết tầm / reset.

const PROJECTILE_SCENE: PackedScene = preload("res://features/combat/projectile.tscn")

@export var projectile_speed: float = 200.0
## Tầm bay tối đa của đạn (>= attack_range để đạn tới được mục tiêu ở mép tầm).
@export var projectile_range: float = 220.0
@export var telegraph_width: float = 8.0

var _last_projectile: Projectile

@onready var _telegraph: Line2D = $Telegraph


func _ready() -> void:
	_telegraph.points = PackedVector2Array([Vector2.ZERO, Vector2(projectile_range, 0.0)])
	_telegraph.width = telegraph_width
	_telegraph.hide()


## Đạn bắn gần nhất (null nếu đã bị hủy). Dùng cho kiểm thử / debug.
func get_last_projectile() -> Projectile:
	return _last_projectile if is_instance_valid(_last_projectile) else null


func _apply_direction() -> void:
	if ground_squash == 1.0:
		return
	# Tầm bay đo trên mặt đất → đường telegraph là đoạn thẳng màn hình có độ dài mặt đất = projectile_range.
	_telegraph.points = PackedVector2Array([Vector2.ZERO, GroundSpace.to_screen(get_ground_direction() * projectile_range, ground_squash)])


func _on_windup_started() -> void:
	_telegraph.default_color = windup_color
	_telegraph.show()


func _on_active_started() -> void:
	_telegraph.hide()
	var container: Node = owner.get_parent() if owner != null and owner.get_parent() != null else get_parent()
	var projectile: Projectile = PROJECTILE_SCENE.instantiate()
	projectile.color = active_color
	var direction: Vector2 = Vector2.from_angle(global_rotation) if ground_squash == 1.0 else _direction
	projectile.launch(_make_damage(), direction, projectile_speed, projectile_range, target_layers, ground_squash, obstacle_mask)
	container.add_child(projectile)
	projectile.global_position = global_position
	_last_projectile = projectile


func _on_cancelled() -> void:
	_telegraph.hide()
