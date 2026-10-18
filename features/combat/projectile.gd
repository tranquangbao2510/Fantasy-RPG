class_name Projectile
extends Area2D
## Đạn tối giản: bay thẳng, gây sát thương một lần qua Hurtbox.receive_damage(DamageInfo) rồi biến mất.
## Biến mất khi chạm vật cản (raycast layer `world` mỗi tick), khi đi hết max_distance, hoặc khi reset thử nghiệm.
## Phe do collision_mask quyết định (= target_layers của người bắn). Không lặp damage.
## Map isometric (ground_squash < 1): bay trên mặt phẳng đất (tốc độ và tầm bay đo trên mặt đất), thân đạn là ellipse 2:1;
## obstacle_mask thêm layer vách của tầng người bắn → đạn tầng thấp bị vách khối cao chặn.

const GROUP: StringName = &"projectiles"
const WORLD_LAYER: int = 1
## Vật cản thuộc group này không chặn đạn (vd. mặt nước: chặn người đi nhưng đạn bay qua).
const PASSABLE_GROUP: StringName = &"projectile_passable"

@export var radius: float = 4.0
@export var color: Color = Color(1, 0.55, 0.2)

var _info: DamageInfo
var _velocity: Vector2 = Vector2.ZERO
var _distance_left: float = 0.0
var _spent: bool = false
var _ground_squash: float = 1.0
var _obstacle_mask: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"test_resettable")
	monitorable = false
	collision_layer = 0
	area_entered.connect(_on_area_entered)


## Khởi động đạn: gọi trước add_child (hoặc ngay sau) với hướng chuẩn hóa.
func launch(info: DamageInfo, direction: Vector2, speed: float, max_distance: float, target_layers: int,
		ground_squash: float = 1.0, obstacle_mask: int = 0) -> void:
	_info = info
	_ground_squash = ground_squash
	_obstacle_mask = obstacle_mask
	_distance_left = max_distance
	collision_mask = target_layers
	if ground_squash == 1.0:
		_velocity = direction.normalized() * speed
		rotation = direction.angle()
	else:
		_velocity = GroundSpace.to_screen(GroundSpace.direction(direction, ground_squash) * speed, ground_squash)
		rotation = 0.0
		scale = Vector2(1.0, ground_squash)


func is_spent() -> bool:
	return _spent


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var step: Vector2 = _velocity * delta
	# Vật cản: raycast đoạn bay của tick này với layer `world` (tile + MapBounds) + vách tầng, không xuyên dù bay nhanh.
	if _is_blocked(step):
		_finish()
		return
	global_position += step
	_distance_left -= GroundSpace.length(step, _ground_squash)
	if _distance_left <= 0.0:
		_finish()


func _is_blocked(step: Vector2) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, global_position + step, WORLD_LAYER | _obstacle_mask)
	var exclude: Array[RID] = []
	for _attempt: int in 4:
		query.exclude = exclude
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		var collider: Object = hit.get("collider")
		if not (collider is Node and (collider as Node).is_in_group(PASSABLE_GROUP)):
			return true
		exclude.append(hit.get("rid"))
	return false


## Reset thử nghiệm: xóa đạn đang bay để không gây damage sau reset.
func reset_state() -> void:
	_finish()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox: Hurtbox = area as Hurtbox
	if _spent or hurtbox == null or not hurtbox.can_receive(_info):
		return
	hurtbox.receive_damage(_info)
	_finish()


func _finish() -> void:
	if _spent:
		return
	_spent = true
	set_deferred(&"monitoring", false)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 1.5, Color(0, 0, 0, 0.5))
	draw_circle(Vector2.ZERO, radius, color)
