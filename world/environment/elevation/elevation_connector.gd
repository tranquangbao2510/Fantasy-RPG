class_name ElevationConnector
extends Area2D
## Lối chuyển tầng (cầu thang, dốc): hành lang `corridor_size` nối lower_tier (phía +Y local) và upper_tier (phía −Y local).
## Xoay node để đổi hướng. Khi một thân có ElevationAgent ở trong hành lang, agent ở trạng thái chuyển tầng
## (chỉ va chạm layer `world` + lan can hai bên); khi rời Area, tầng mới = phía mà thân đi ra.
## ElevationMap khoét hành lang khỏi tường tầng dưới và thêm hành lang vào vùng đi được của tầng trên.

## Physics layer của lan can (mặc định `world`, áp dụng cho mọi tầng).
const RAILING_LAYER: int = 1

@export var lower_tier: int = 0
@export var upper_tier: int = 1
## Kích thước hành lang (rộng × dài theo hướng lên/xuống), local.
@export var corridor_size: Vector2 = Vector2(48, 96)
## Area kéo dài thêm ở hai đầu để thân rời hẳn mép vách rồi mới đổi tầng.
@export var exit_margin: float = 16.0


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(corridor_size.x, corridor_size.y + exit_margin * 2.0)
	var area_shape: CollisionShape2D = CollisionShape2D.new()
	area_shape.shape = shape
	add_child(area_shape)
	_build_railings()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Hành lang (global) — dùng bởi ElevationMap.
func get_corridor_polygon() -> PackedVector2Array:
	var h: Vector2 = corridor_size * 0.5
	return global_transform * PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])


## Tầng tương ứng với vị trí world (phía trên/dưới của connector).
func get_tier_for(world_point: Vector2) -> int:
	return upper_tier if to_local(world_point).y < 0.0 else lower_tier


func _build_railings() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Railings"
	body.collision_layer = 1 << (RAILING_LAYER - 1)
	body.collision_mask = 0
	add_child(body)
	var h: Vector2 = corridor_size * 0.5
	for side: float in [-1.0, 1.0]:
		var segment: SegmentShape2D = SegmentShape2D.new()
		segment.a = Vector2(side * h.x, -h.y)
		segment.b = Vector2(side * h.x, h.y)
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.shape = segment
		body.add_child(shape)


func _on_body_entered(body: Node2D) -> void:
	var agent: ElevationAgent = ElevationAgent.find_for(body)
	if agent != null:
		agent.enter_connector(self)


func _on_body_exited(body: Node2D) -> void:
	var agent: ElevationAgent = ElevationAgent.find_for(body)
	if agent != null:
		agent.exit_connector(self)
