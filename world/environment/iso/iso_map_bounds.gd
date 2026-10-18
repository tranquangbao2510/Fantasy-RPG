class_name IsoMapBounds
extends MapBounds
## Ranh giới cho map isometric: vùng map = hình chữ nhật bao lưới thoi của `source_layer` (TileMapLayer isometric)
## cộng `margin` (để camera thấy cả vách vực / background quanh mép đất). Không tạo collision: mép đất chặn bằng
## tường riêng của map (vực), vì biên đất là hình thoi/không đều chứ không phải hình chữ nhật.
## World dùng get_map_rect() để đặt giới hạn camera như MapBounds thường.

@export var margin: Vector2 = Vector2(96, 96)
## Phần mở rộng thêm xuống dưới (vách vực đổ xuống dưới mép đất).
@export var extra_bottom: float = 160.0


func _ready() -> void:
	if source_layer == null:
		push_warning("[IsoMapBounds] Chưa gán source_layer.")


func get_map_rect() -> Rect2:
	if source_layer == null:
		return Rect2()
	var used: Rect2i = source_layer.get_used_rect()
	var half: Vector2 = Vector2(source_layer.tile_set.tile_size) * 0.5
	var rect: Rect2 = Rect2(source_layer.map_to_local(used.position), Vector2.ZERO)
	for corner: Vector2i in [used.position, Vector2i(used.end.x - 1, used.position.y), Vector2i(used.position.x, used.end.y - 1), used.end - Vector2i.ONE]:
		var c: Vector2 = source_layer.map_to_local(corner)
		rect = rect.expand(c - half).expand(c + half)
	rect = rect.grow_individual(margin.x, margin.y, margin.x, margin.y + extra_bottom)
	var offset: Vector2 = source_layer.position - position
	return Rect2(rect.position + offset, rect.size)
