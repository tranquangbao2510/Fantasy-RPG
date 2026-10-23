@tool
class_name ObjectShadow
extends Node2D
## Bóng đổ của đồ vật gameplay (TASK M7) — vẽ bằng code (ellipse / đa giác 2:1 tại chân), không nằm trong PNG.
## Chọn bóng code thay vì vẽ trong ảnh: mọi trạng thái (rương đóng / mở, node còn / hết) dùng chung một bóng; art gen AI
## không phải khớp hình bóng; giống cách làm của prop môi trường (bóng là lớp riêng). IsoActorAdapter (bù nhìn ở map iso)
## đặt lại `polygon` như với Polygon2D của enemy.

@export var polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		polygon = value
		queue_redraw()
@export var color: Color = Color(0, 0, 0, 0.35):
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	if polygon.size() >= 3:
		draw_colored_polygon(polygon, color)
