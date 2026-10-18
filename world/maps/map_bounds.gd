class_name MapBounds
extends StaticBody2D
## Ranh giới bản đồ: 4 WorldBoundaryShape2D bao quanh vùng đã vẽ của `source_layer`.
## Kích thước map lấy từ TileMapLayer, không hardcode. Dùng chung collision layer với vật cản (`world`).

@export var source_layer: TileMapLayer


func _ready() -> void:
	if source_layer == null:
		push_warning("[MapBounds] Chưa gán source_layer; bỏ qua ranh giới bản đồ.")
		return
	var rect: Rect2 = get_map_rect()
	# normal hướng vào trong map (phía được phép đi).
	_add_boundary(Vector2.DOWN, rect.position.y)
	_add_boundary(Vector2.UP, -rect.end.y)
	_add_boundary(Vector2.RIGHT, rect.position.x)
	_add_boundary(Vector2.LEFT, -rect.end.x)


## Vùng bản đồ (pixel) theo tọa độ local của node này.
func get_map_rect() -> Rect2:
	var tile_size: Vector2 = Vector2(source_layer.tile_set.tile_size)
	var used: Rect2i = source_layer.get_used_rect()
	var offset: Vector2 = source_layer.position - position
	return Rect2(Vector2(used.position) * tile_size + offset, Vector2(used.size) * tile_size)


func _add_boundary(normal: Vector2, distance: float) -> void:
	var shape: WorldBoundaryShape2D = WorldBoundaryShape2D.new()
	shape.normal = normal
	shape.distance = distance
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
