@tool
class_name ElevatedDeck
extends Node2D
## Mặt sàn tầng cao không chặn tầng dưới (lối đi trên vòm, cầu đá): chỉ thêm vùng đi được cho `tier`.
## Tầng dưới đi qua bên dưới tự do (trừ trụ/mố nếu có collision riêng).
## Hiển thị thường là FootprintSortedSprite (cắt lát, mỗi lát neo tại mép trước của chân cầu) để entity tầng thấp
## đứng trước cầu vẽ đè lên cầu, đứng sau/dưới gầm bị cầu che. Occupant tầng cao vẽ trên cầu nhờ z_index theo tầng.

@export var tier: int = 1
## Vùng đi được của mặt cầu (local, màn hình) — map isometric: hình bình hành theo trục lưới.
@export var deck_polygon: PackedVector2Array = PackedVector2Array()


func get_walkable_polygon() -> PackedVector2Array:
	return global_transform * deck_polygon
