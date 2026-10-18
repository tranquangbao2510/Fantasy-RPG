class_name Stream
extends Node2D
## Suối / sông: hiển thị bằng Line2D (bờ bùn + mặt nước với shader), collision sinh lúc chạy từ đường tâm
## và bề rộng của `water_line` (kể cả width_curve) — không phụ thuộc hình dạng texture.
## Hình học dựng trong toạ độ local của Line2D rồi nhân global_transform: đặt Line2D trong node mặt phẳng đất
## (scale y 0.5) thì collision tự thành dải/khớp ellipse đúng phép chiếu isometric.
## `crossings`: node có get_walkable_polygon() (vd. Footbridge) được khoét khỏi collision để đi qua.
## Không có bơi/lặn/vật lý nước: nước chỉ là vật cản của tầng `elevation_tier`.

## Số cạnh của đa giác xấp xỉ khớp nối tròn giữa các đoạn.
const JOINT_SIDES: int = 10

@export var water_line: Line2D
@export var crossings: Array[Node2D] = []
@export var elevation_tier: int = 0
## Tỉ lệ bề rộng chặn so với bề rộng hiển thị (mép nước nông cho phép đứng sát bờ).
@export var blocking_width_ratio: float = 0.78


func _ready() -> void:
	if water_line == null or water_line.points.size() < 2:
		return
	var cutters: Array[PackedVector2Array] = []
	for node: Node2D in crossings:
		if node != null and node.has_method(&"get_walkable_polygon"):
			cutters.append(node.call(&"get_walkable_polygon"))
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "WaterCollision"
	# Nước chặn người đi nhưng đạn bay qua được.
	body.add_to_group(&"projectile_passable")
	body.collision_layer = ElevationMap.tier_bit(elevation_tier)
	body.collision_mask = 0
	add_child(body)
	body.global_transform = Transform2D.IDENTITY
	for polygon: PackedVector2Array in _build_polygons():
		var pieces: Array[PackedVector2Array] = [polygon]
		for cutter: PackedVector2Array in cutters:
			var next: Array[PackedVector2Array] = []
			for piece: PackedVector2Array in pieces:
				for part: PackedVector2Array in Geometry2D.clip_polygons(piece, cutter):
					if not Geometry2D.is_polygon_clockwise(part):
						next.append(part)
			pieces = next
		for piece: PackedVector2Array in pieces:
			var shape: CollisionPolygon2D = CollisionPolygon2D.new()
			shape.polygon = piece
			body.add_child(shape)


## Đa giác (global) cho từng đoạn + khớp nối, bán kính theo width_curve.
func _build_polygons() -> Array[PackedVector2Array]:
	var points: PackedVector2Array = water_line.points
	var to_world: Transform2D = water_line.global_transform
	var total: float = 0.0
	for i: int in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var result: Array[PackedVector2Array] = []
	var walked: float = 0.0
	var radii: PackedFloat32Array = PackedFloat32Array()
	for i: int in points.size():
		if i > 0:
			walked += points[i - 1].distance_to(points[i])
		var curve_scale: float = water_line.width_curve.sample(walked / total) if water_line.width_curve != null else 1.0
		radii.append(water_line.width * 0.5 * curve_scale * blocking_width_ratio)
	for i: int in points.size():
		var joint: PackedVector2Array = PackedVector2Array()
		for k: int in JOINT_SIDES:
			joint.append(points[i] + Vector2.from_angle(TAU * k / JOINT_SIDES) * radii[i])
		result.append(to_world * joint)
		if i == points.size() - 1:
			break
		var normal: Vector2 = (points[i + 1] - points[i]).orthogonal().normalized()
		result.append(to_world * PackedVector2Array([
			points[i] + normal * radii[i], points[i + 1] + normal * radii[i + 1],
			points[i + 1] - normal * radii[i + 1], points[i] - normal * radii[i],
		]))
	return result
