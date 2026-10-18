class_name ElevatedDeck
extends Node2D
## Mặt sàn tầng cao không chặn tầng dưới (cầu đá, lối đi trên cao): chỉ thêm vùng đi được cho `tier`.
## Tầng dưới đi qua bên dưới tự do (trừ trụ/mố nếu có collision riêng).
## Origin đặt tại chân mặt trước của cầu để Y-sort cùng entity tầng thấp: entity ở trước chân cầu vẽ đè lên cầu,
## entity ở sau/dưới gầm cầu bị cầu che. Occupant tầng cao vẽ trên cầu nhờ z_index theo tầng (ElevationAgent).

@export var tier: int = 1
## Vùng đi được của mặt cầu (local).
@export var deck_rect: Rect2 = Rect2(-80, -120, 160, 56)


func get_walkable_polygon() -> PackedVector2Array:
	var r: Rect2 = deck_rect
	return global_transform * PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
