class_name EnvironmentProp
extends Node2D
## Object môi trường tái sử dụng (cây, bụi, đá, tàn tích). Origin = điểm tiếp xúc mặt đất (sorting anchor):
## đặt trong cây Y-sort của EntityContainer để Player đứng trước/sau đúng phối cảnh.
## Cấu trúc scene: Shadow (Sprite2D, z_index -1: dưới mọi entity cùng tầng) → Visual (Sprite2D) →
## Collision (StaticBody2D, chỉ ở gốc/thân, tùy chọn) → OcclusionFader (tùy chọn, cho vật cao).
## `elevation_tier` quyết định z_index (tầng cao vẽ trên tầng thấp) và physics layer của Collision.

@export var elevation_tier: int = 0


func _ready() -> void:
	z_index = ElevationMap.tier_z(elevation_tier)
	for child: Node in get_children():
		var body: StaticBody2D = child as StaticBody2D
		if body != null:
			body.collision_layer = ElevationMap.tier_bit(elevation_tier)
			body.collision_mask = 0
