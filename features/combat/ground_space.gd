class_name GroundSpace
extends RefCounted
## Toán học "mặt phẳng đất" cho combat (TASK VISUAL-02.1). `squash` = tỉ lệ dọc của mặt đất trên màn hình:
## 1 = map top-down cũ (mặt đất trùng màn hình, hành vi không đổi); 0.5 = map isometric 2:1.
## Khoảng cách, tầm đánh, bán kính kỹ năng là độ dài TRÊN MẶT ĐẤT; hình tròn trên đất = ellipse 2:1 trên màn hình.
## Không phụ thuộc module world: map iso cấu hình squash cho component qua set_ground_squash().


## Vector màn hình → vector mặt đất (bỏ nén dọc).
static func to_ground(v: Vector2, squash: float) -> Vector2:
	return Vector2(v.x, v.y / squash)


## Vector mặt đất → vector màn hình.
static func to_screen(v: Vector2, squash: float) -> Vector2:
	return Vector2(v.x, v.y * squash)


static func length(v: Vector2, squash: float) -> float:
	return to_ground(v, squash).length()


## Hướng mặt đất (chuẩn hóa) ứng với một hướng/vector màn hình.
static func direction(v: Vector2, squash: float) -> Vector2:
	return to_ground(v, squash).normalized()


## Kẹp vector màn hình sao cho độ dài trên mặt đất ≤ max_length.
static func limit(v: Vector2, max_length: float, squash: float) -> Vector2:
	return to_screen(to_ground(v, squash).limit_length(max_length), squash)


## Hình chữ nhật trên mặt đất bắt đầu tại gốc, dài `length` theo hướng mặt đất `ground_dir`, rộng `width`;
## trả về polygon màn hình (local).
static func rect(ground_dir: Vector2, length: float, width: float, squash: float, start: float = 0.0) -> PackedVector2Array:
	var side: Vector2 = ground_dir.orthogonal() * width * 0.5
	var a: Vector2 = ground_dir * start
	var b: Vector2 = ground_dir * (start + length)
	return PackedVector2Array([to_screen(a + side, squash), to_screen(b + side, squash), to_screen(b - side, squash), to_screen(a - side, squash)])


## Hình tròn bán kính `radius` trên mặt đất (ellipse trên màn hình) quanh `center` (màn hình).
static func circle(center: Vector2, radius: float, squash: float, sides: int = 24) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for k: int in sides:
		out.append(center + to_screen(Vector2.from_angle(TAU * k / sides) * radius, squash))
	return out


## Hình quạt trên mặt đất: đỉnh tại `center`, hướng mặt đất `ground_dir`, nửa góc `half_angle` (radian).
static func cone(center: Vector2, ground_dir: Vector2, radius: float, half_angle: float, squash: float, segments: int = 24) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([center])
	var base: float = ground_dir.angle()
	for i: int in segments + 1:
		var a: float = base - half_angle + 2.0 * half_angle * float(i) / segments
		out.append(center + to_screen(Vector2.from_angle(a) * radius, squash))
	return out


static func polygon_shape(points: PackedVector2Array) -> ConvexPolygonShape2D:
	var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	shape.points = points
	return shape
