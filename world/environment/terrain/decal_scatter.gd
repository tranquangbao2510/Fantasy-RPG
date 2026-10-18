@tool
class_name DecalScatter
extends Node2D
## Rải chi tiết mặt đất (cụm cỏ, hoa, sỏi, lá, mảng rêu, mảng sáng) theo seed cố định — kết quả giống nhau mỗi lần chạy.
## Vẽ toàn bộ trong một CanvasItem (_draw) nên chi phí thấp và có batching; hiển thị cả trong Editor.
## Hai chế độ:
## - Vùng: rải ngẫu nhiên trong `area` (local), tránh các Line2D trong `avoid_lines` và polygon của `avoid_nodes`.
## - Dọc đường: nếu gán `along_line`, rải dọc hai mép Line2D (che ranh giới đường đất / bờ nước).
## Chỉ hiển thị, không có collision.

@export var texture: Texture2D:
	set(value):
		texture = value
		_queue_rebuild()
## Số ô trong atlas theo chiều ngang (atlas có lề trong suốt giữa các ô để tránh bleeding).
@export var atlas_columns: int = 1:
	set(value):
		atlas_columns = maxi(1, value)
		_queue_rebuild()
@export var count: int = 40:
	set(value):
		count = value
		_queue_rebuild()
@export var seed_value: int = 1:
	set(value):
		seed_value = value
		_queue_rebuild()
@export var area: Rect2 = Rect2(-200, -200, 400, 400):
	set(value):
		area = value
		_queue_rebuild()
@export var scale_range: Vector2 = Vector2(0.4, 0.6):
	set(value):
		scale_range = value
		_queue_rebuild()
## Biến thiên độ sáng ngẫu nhiên (0 = không).
@export var tint_variation: float = 0.12:
	set(value):
		tint_variation = value
		_queue_rebuild()
@export var random_rotation: bool = false:
	set(value):
		random_rotation = value
		_queue_rebuild()
## Decal nằm phẳng trên mặt đất (mảng rêu, bóng, đốm nắng): xoay trên mặt đất rồi nén dọc 2:1 theo phép chiếu iso.
## false: decal đứng (cụm cỏ, hoa) — giữ nguyên, neo tại chân.
@export var flat_on_ground: bool = false:
	set(value):
		flat_on_ground = value
		_queue_rebuild()
@export var avoid_lines: Array[Line2D] = []:
	set(value):
		avoid_lines = value
		_queue_rebuild()
## Node có get_blocking_polygon() hoặc get_walkable_polygon() (ElevatedTerrain, ElevatedDeck, Footbridge...).
@export var avoid_nodes: Array[Node2D] = []:
	set(value):
		avoid_nodes = value
		_queue_rebuild()
## Nếu có: chỉ rải bên trong vùng get_walkable_polygon() của các node này (vd. mặt trên plateau).
@export var inside_nodes: Array[Node2D] = []:
	set(value):
		inside_nodes = value
		_queue_rebuild()
@export var avoid_margin: float = 8.0:
	set(value):
		avoid_margin = value
		_queue_rebuild()
@export_group("Along line")
@export var along_line: Line2D:
	set(value):
		along_line = value
		_queue_rebuild()
## Khoảng lệch thêm so với mép (âm = vào trong đường).
@export var edge_offset: Vector2 = Vector2(-6, 6):
	set(value):
		edge_offset = value
		_queue_rebuild()

var _items: Array[Dictionary] = []
var _rebuild_queued: bool = false


func _ready() -> void:
	_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	_items.clear()
	if texture == null:
		queue_redraw()
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var avoid_polygons: Array[PackedVector2Array] = []
	for node: Node2D in avoid_nodes:
		if node == null:
			continue
		var polygon: PackedVector2Array = PackedVector2Array()
		if node.has_method(&"get_blocking_polygon"):
			polygon = node.call(&"get_blocking_polygon")
		elif node.has_method(&"get_walkable_polygon"):
			polygon = node.call(&"get_walkable_polygon")
		if polygon.size() >= 3:
			avoid_polygons.append(global_transform.affine_inverse() * polygon)
	var inside_polygons: Array[PackedVector2Array] = []
	for node: Node2D in inside_nodes:
		if node != null and node.has_method(&"get_walkable_polygon"):
			inside_polygons.append(global_transform.affine_inverse() * (node.call(&"get_walkable_polygon") as PackedVector2Array))
	var attempts: int = count * 4
	while _items.size() < count and attempts > 0:
		attempts -= 1
		var pos: Vector2 = _pick_position(rng)
		if not _is_free(pos, avoid_polygons) or not _is_inside(pos, inside_polygons):
			continue
		var cell: int = rng.randi_range(0, atlas_columns - 1)
		var s: float = rng.randf_range(scale_range.x, scale_range.y)
		var f: float = 1.0 + rng.randf_range(-tint_variation, tint_variation)
		_items.append({
			"pos": pos,
			"cell": cell,
			"scale": Vector2(s * (-1.0 if rng.randf() < 0.5 else 1.0), s),
			"rot": rng.randf() * TAU if random_rotation else 0.0,
			"color": Color(f, f, f * 0.98, 1.0),
		})
	_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y)
	queue_redraw()


func _pick_position(rng: RandomNumberGenerator) -> Vector2:
	if along_line == null or along_line.points.size() < 2:
		return Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
	var points: PackedVector2Array = along_line.points
	var i: int = rng.randi_range(0, points.size() - 2)
	# Tính trong toạ độ local của Line2D (vd. mặt phẳng đất iso) rồi mới chuyển sang toạ độ của node này.
	var a: Vector2 = points[i]
	var b: Vector2 = points[i + 1]
	var t: float = rng.randf()
	var normal: Vector2 = (b - a).orthogonal().normalized()
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var offset: float = along_line.width * 0.5 + rng.randf_range(edge_offset.x, edge_offset.y)
	return to_local(along_line.to_global(a.lerp(b, t) + normal * side * offset))


func _is_free(pos: Vector2, avoid_polygons: Array[PackedVector2Array]) -> bool:
	for polygon: PackedVector2Array in avoid_polygons:
		if Geometry2D.is_point_in_polygon(pos, polygon):
			return false
	var world: Vector2 = to_global(pos)
	for line: Line2D in avoid_lines:
		if line == null or line == along_line:
			continue
		var local: Vector2 = line.to_local(world)
		var limit: float = line.width * 0.5 + avoid_margin
		for i: int in line.points.size() - 1:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(local, line.points[i], line.points[i + 1])
			if closest.distance_to(local) < limit:
				return false
	return true


func _is_inside(pos: Vector2, inside_polygons: Array[PackedVector2Array]) -> bool:
	if inside_polygons.is_empty():
		return true
	for polygon: PackedVector2Array in inside_polygons:
		if Geometry2D.is_point_in_polygon(pos, polygon):
			return true
	return false


func _draw() -> void:
	if texture == null:
		return
	var cell_size: Vector2 = Vector2(texture.get_width() / float(atlas_columns), texture.get_height())
	for item: Dictionary in _items:
		var region: Rect2 = Rect2(Vector2(cell_size.x * int(item["cell"]), 0), cell_size)
		if flat_on_ground:
			var ground: Transform2D = Transform2D(0.0, Vector2(1.0, IsoProjection.GROUND_SQUASH), 0.0, item["pos"])
			draw_set_transform_matrix(ground * Transform2D(item["rot"], item["scale"], 0.0, Vector2.ZERO))
		else:
			draw_set_transform(item["pos"], item["rot"], item["scale"])
		# Neo tại chân (giữa cạnh dưới) để cụm cỏ/hoa "mọc" từ điểm đặt.
		draw_texture_rect_region(texture, Rect2(Vector2(-cell_size.x * 0.5, -cell_size.y * (0.5 if random_rotation or flat_on_ground else 0.9)), cell_size), region, item["color"])
	draw_set_transform(Vector2.ZERO)
