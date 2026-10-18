class_name MeleeAttack
extends AttackComponent
## Đòn cận chiến hình chữ nhật (attack_range × attack_width) dùng Hitbox; telegraph = chính vùng đó khi windup.
## Map isometric: hình chữ nhật nằm trên mặt phẳng đất (hình bình hành trên màn hình) theo hướng đòn.
## Mỗi lần ACTIVE là một Hitbox.activate() mới → mỗi mục tiêu trúng tối đa một lần/đòn.

@export var attack_width: float = 24.0

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


func get_hitbox() -> Hitbox:
	return _hitbox


func _apply_direction() -> void:
	if ground_squash == 1.0:
		return
	var points: PackedVector2Array = GroundSpace.rect(get_ground_direction(), attack_range, attack_width, ground_squash)
	_shape.shape = GroundSpace.polygon_shape(points)
	_shape.position = Vector2.ZERO
	_visual.polygon = points


func _on_windup_started() -> void:
	_visual.color = windup_color
	_visual.show()


func _on_active_started() -> void:
	_visual.color = active_color
	_visual.show()
	_hitbox.activate(_make_damage())


func _on_active_ended() -> void:
	_hitbox.deactivate()
	_visual.hide()


func _on_cancelled() -> void:
	_hitbox.deactivate()
	_visual.hide()
