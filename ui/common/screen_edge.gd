class_name ScreenEdge
extends RefCounted
## Toán học chỉ báo ở mép màn hình (TASK M4, tách từ DeathBagMarker của M2): điểm trên mép khung `inner` theo hướng
## từ tâm màn hình tới điểm ngoài màn hình.


static func clamp_to_edge(screen_point: Vector2, viewport_rect: Rect2, margin: float) -> Vector2:
	var inner: Rect2 = viewport_rect.grow(-margin)
	var center: Vector2 = viewport_rect.get_center()
	var direction: Vector2 = (screen_point - center).normalized()
	var scale_x: float = (inner.size.x * 0.5) / maxf(absf(direction.x), 0.0001)
	var scale_y: float = (inner.size.y * 0.5) / maxf(absf(direction.y), 0.0001)
	return center + direction * minf(scale_x, scale_y)


## Mũi tên tam giác tại `at` chỉ về `toward`.
static func arrow(at: Vector2, toward: Vector2, length: float = 14.0, half_width: float = 8.0) -> PackedVector2Array:
	var direction: Vector2 = (toward - at).normalized()
	var side: Vector2 = direction.orthogonal() * half_width
	return PackedVector2Array([at + direction * length, at - direction * 6.0 + side, at - direction * 6.0 - side])
