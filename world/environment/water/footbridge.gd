@tool
class_name Footbridge
extends Node2D
## Cầu gỗ thấp (cùng tầng với mặt nước): vùng `deck_polygon` (local) được khoét khỏi collision của Stream.
## Map isometric: polygon là hình bình hành theo trục lưới (cầu bắc chéo). Phẳng sát mặt đất nên nằm trong nhóm
## Ground (vẽ dưới entity), không cần Y-sort.

@export var deck_polygon: PackedVector2Array = PackedVector2Array([Vector2(-28, -62), Vector2(28, -62), Vector2(28, 62), Vector2(-28, 62)])


func get_walkable_polygon() -> PackedVector2Array:
	return global_transform * deck_polygon
