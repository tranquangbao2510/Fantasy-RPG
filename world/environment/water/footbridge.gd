class_name Footbridge
extends Node2D
## Cầu gỗ thấp (cùng tầng với mặt nước): vùng `deck_size` (local, căn giữa) được khoét khỏi collision của Stream.
## Phẳng sát mặt đất nên nằm trong nhóm Ground (vẽ dưới entity), không cần Y-sort.

@export var deck_size: Vector2 = Vector2(56, 124)


func get_walkable_polygon() -> PackedVector2Array:
	var h: Vector2 = deck_size * 0.5
	return global_transform * PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
