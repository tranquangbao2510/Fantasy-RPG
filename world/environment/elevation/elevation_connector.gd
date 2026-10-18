class_name ElevationConnector
extends Area2D
## Lối chuyển tầng (cầu thang, dốc): hành lang hình bình hành từ `bottom` (chân, lower_tier) tới `top` (đỉnh, upper_tier),
## bề rộng theo vector `half_width` (toạ độ local, màn hình). Trong map isometric, `half_width` song song cạnh vách
## và `top − bottom` đi theo trục chéo của lưới + độ cao tầng → cầu thang chạy chéo đúng phép chiếu.
## Khi một thân có ElevationAgent ở trong hành lang, agent ở trạng thái chuyển tầng (chỉ va chạm layer `world`
## + lan can hai bên); khi rời Area, tầng mới = phía mà thân đi ra (chiếu lên trục bottom → top).
## ElevationMap khoét hành lang khỏi tường tầng dưới và thêm hành lang vào vùng đi được của tầng trên.

## Physics layer của lan can (mặc định `world`, áp dụng cho mọi tầng).
const RAILING_LAYER: int = 1

@export var lower_tier: int = 0
@export var upper_tier: int = 1
@export var bottom: Vector2 = Vector2(0, 48)
@export var top: Vector2 = Vector2(0, -48)
@export var half_width: Vector2 = Vector2(24, 0)
## Area kéo dài thêm ở hai đầu (px, theo trục bottom → top) để thân rời hẳn mép vách rồi mới đổi tầng.
@export var exit_margin: float = 16.0


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	var axis: Vector2 = (top - bottom).normalized() * exit_margin
	var area_shape: CollisionPolygon2D = CollisionPolygon2D.new()
	area_shape.polygon = _parallelogram(bottom - axis, top + axis)
	add_child(area_shape)
	_build_railings()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Hành lang (global) — dùng bởi ElevationMap.
func get_corridor_polygon() -> PackedVector2Array:
	return global_transform * _parallelogram(bottom, top)


## Tầng tương ứng với vị trí world: phía đỉnh (so với trung điểm hành lang) → upper_tier.
func get_tier_for(world_point: Vector2) -> int:
	var local: Vector2 = to_local(world_point)
	return upper_tier if (local - (bottom + top) * 0.5).dot(top - bottom) > 0.0 else lower_tier


func _parallelogram(from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([from - half_width, from + half_width, to + half_width, to - half_width])


func _build_railings() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Railings"
	body.collision_layer = 1 << (RAILING_LAYER - 1)
	body.collision_mask = 0
	add_child(body)
	for side: float in [-1.0, 1.0]:
		var segment: SegmentShape2D = SegmentShape2D.new()
		segment.a = bottom + half_width * side
		segment.b = top + half_width * side
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
