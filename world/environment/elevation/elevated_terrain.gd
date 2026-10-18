@tool
class_name ElevatedTerrain
extends Node2D
## Khối địa hình cao (plateau / mỏm đá) của tầng `tier`: mặt trên + mặt vách đùn xuống `height` px (phép chiếu xiên 3/4).
## - `outline`: đường bao MẶT TRÊN (tọa độ local). Đây là dữ liệu logic: vùng đi được của tầng cao và collision lấy từ đây,
##   không lấy từ texture.
## - Hiển thị: Top (Polygon2D) + các FaceChunk (mặt vách, chân vách, mép cỏ) được sinh lại khi sửa thuộc tính
##   (cả trong Editor). Node con sinh ra không có owner nên không lưu vào scene.
## - Mỗi đoạn mặt vách (≤ 32 px) là một node Y-sort riêng neo tại điểm CAO NHẤT của chân vách trong đoạn → với cạnh chéo
##   của lưới isometric, entity tầng thấp đứng trước bất kỳ phần nào của đoạn vẫn vẽ đè lên vách; entity phía sau bị che.
## - Isometric: khối cao lộ hai mặt vách (tây nam + đông nam) vì cả hai cạnh đều hướng xuống màn hình (normal.y > 0).
## - `back_lip`: vẽ mép cỏ ở cạnh phía sau (hướng lên màn hình), dùng cho mép vực của mặt đất chính.
## Ràng buộc: cạnh hướng nam không được có phần mặt trên khác nằm ngay bên dưới trong khoảng `height` (front đơn điệu).

const TEXEL_DENSITY: float = 2.0
const MAX_CHUNK_LENGTH: float = 32.0
const LIP_ABOVE: float = 5.0
const LIP_HEIGHT: float = 24.0
const BASE_HEIGHT: float = 24.0

@export var tier: int = 1:
	set(value):
		tier = value
		_queue_rebuild()
@export var height: float = 64.0:
	set(value):
		height = value
		_queue_rebuild()
@export var outline: PackedVector2Array = PackedVector2Array():
	set(value):
		outline = value
		_queue_rebuild()
@export_group("Visual")
@export var top_texture: Texture2D:
	set(value):
		top_texture = value
		_queue_rebuild()
@export var top_material: Material:
	set(value):
		top_material = value
		_queue_rebuild()
@export var face_texture: Texture2D:
	set(value):
		face_texture = value
		_queue_rebuild()
@export var lip_texture: Texture2D:
	set(value):
		lip_texture = value
		_queue_rebuild()
@export var base_texture: Texture2D:
	set(value):
		base_texture = value
		_queue_rebuild()
## Độ sáng mặt vách theo hướng: mặt hướng tây (về phía nguồn sáng) sáng hơn mặt hướng đông.
@export var face_light_bias: float = 0.22:
	set(value):
		face_light_bias = value
		_queue_rebuild()
@export var back_lip: bool = false:
	set(value):
		back_lip = value
		_queue_rebuild()

var _rebuild_queued: bool = false


func _ready() -> void:
	y_sort_enabled = true
	_rebuild()


## Mặt trên (global) — vùng đi được của tầng `tier`.
func get_walkable_polygon() -> PackedVector2Array:
	return global_transform * outline


## Vùng tầng dưới không đi vào được: mặt trên ∪ mặt vách đùn xuống (global).
func get_blocking_polygon() -> PackedVector2Array:
	if outline.size() < 3:
		return PackedVector2Array()
	var down: Vector2 = Vector2(0, height)
	var sweep: PackedVector2Array = outline.duplicate()
	if Geometry2D.is_polygon_clockwise(sweep):
		sweep.reverse()
	var shifted: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in outline:
		shifted.append(p + down)
	var pieces: Array[PackedVector2Array] = [shifted]
	for i: int in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		if absf(b.x - a.x) > 0.5:
			pieces.append(PackedVector2Array([a, b, b + down, a + down]))
	for piece: PackedVector2Array in pieces:
		var best_area: float = 0.0
		for part: PackedVector2Array in Geometry2D.merge_polygons(sweep, piece):
			var area: float = _area(part)
			if not Geometry2D.is_polygon_clockwise(part) and area > best_area:
				best_area = area
				sweep = part
	return global_transform * sweep


static func _area(polygon: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in polygon.size():
		sum += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	return absf(sum) * 0.5


func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	for child: Node in get_children():
		if child.has_meta(&"generated"):
			remove_child(child)
			child.queue_free()
	if outline.size() < 3:
		return
	_build_top()
	_build_faces()


func _build_top() -> void:
	var max_y: float = -INF
	for p: Vector2 in outline:
		max_y = maxf(max_y, p.y)
	var top: Polygon2D = Polygon2D.new()
	top.name = "Top"
	top.set_meta(&"generated", true)
	top.position = Vector2(0, max_y)
	var local: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in outline:
		local.append(p - top.position)
	top.polygon = local
	top.texture = top_texture
	top.texture_offset = top.position * TEXEL_DENSITY
	top.texture_scale = Vector2(TEXEL_DENSITY, TEXEL_DENSITY)
	top.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	top.material = top_material
	add_child(top)


func _build_faces() -> void:
	var distance: float = 0.0
	var index: int = 0
	for i: int in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var edge: Vector2 = b - a
		var length: float = edge.length()
		if length < 0.5:
			continue
		# Pháp tuyến hướng ra ngoài (y xuống dưới trong không gian màn hình).
		var normal: Vector2 = edge.orthogonal().normalized()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + normal * 0.5, outline):
			normal = -normal
		var pieces: int = maxi(1, ceili(length / MAX_CHUNK_LENGTH))
		for k: int in pieces:
			var pa: Vector2 = a.lerp(b, float(k) / pieces)
			var pb: Vector2 = a.lerp(b, float(k + 1) / pieces)
			var piece_length: float = pa.distance_to(pb)
			if normal.y > 0.05 and absf(pb.x - pa.x) > 0.5:
				_add_chunk(index, pa, pb, distance, normal)
				index += 1
			elif back_lip and normal.y < -0.05:
				_add_back_lip(pa, pb, distance)
			distance += piece_length


func _add_chunk(index: int, a: Vector2, b: Vector2, distance: float, normal: Vector2) -> void:
	var chunk: Node2D = Node2D.new()
	chunk.name = "Face%d" % index
	chunk.set_meta(&"generated", true)
	# Neo Y-sort tại điểm cao nhất (y nhỏ nhất) của chân vách trong đoạn.
	chunk.position = Vector2((a.x + b.x) * 0.5, minf(a.y, b.y) + height)
	add_child(chunk)
	var la: Vector2 = a - chunk.position
	var lb: Vector2 = b - chunk.position
	var u0: float = distance * TEXEL_DENSITY
	var u1: float = (distance + a.distance_to(b)) * TEXEL_DENSITY
	var shade: float = clampf(1.0 - normal.x * face_light_bias, 0.6, 1.25)
	var tint: Color = Color(shade, shade, shade * 0.98)
	_add_strip(chunk, face_texture, la, lb, 0.0, height, u0, u1, tint)
	_add_strip(chunk, base_texture, la, lb, height - BASE_HEIGHT * 0.5, height + BASE_HEIGHT * 0.5, u0, u1, Color.WHITE)
	_add_strip(chunk, lip_texture, la, lb, -LIP_ABOVE, LIP_HEIGHT - LIP_ABOVE, u0, u1, Color.WHITE)


## Dải texture đùn theo chiều dọc dưới đoạn a→b, từ offset top tới bottom (px world).
func _add_strip(parent: Node2D, texture: Texture2D, a: Vector2, b: Vector2, top: float, bottom: float, u0: float, u1: float, tint: Color) -> void:
	if texture == null:
		return
	var strip: Polygon2D = Polygon2D.new()
	strip.texture = texture
	strip.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	strip.color = tint
	strip.polygon = PackedVector2Array([a + Vector2(0, top), b + Vector2(0, top), b + Vector2(0, bottom), a + Vector2(0, bottom)])
	# Lặp theo chiều cao: vách cao hơn texture (vd. vách vực) không bị kéo giãn.
	var v1: float = (bottom - top) * TEXEL_DENSITY
	strip.uv = PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, v1), Vector2(u0, v1)])
	parent.add_child(strip)


## Mép cỏ ở cạnh phía sau (mép vực nhìn từ trên): cỏ phủ lên mặt trên, rủ ra phía ngoài (lên màn hình).
func _add_back_lip(a: Vector2, b: Vector2, distance: float) -> void:
	var top_node: Node2D = get_node_or_null(^"Top") as Node2D
	if top_node == null or lip_texture == null:
		return
	var la: Vector2 = a - top_node.position
	var lb: Vector2 = b - top_node.position
	var u0: float = distance * TEXEL_DENSITY
	var u1: float = (distance + a.distance_to(b)) * TEXEL_DENSITY
	# Lật dọc: phần cỏ dày nằm phía trong mặt đất, phần rủ hướng ra vực.
	var strip: Polygon2D = Polygon2D.new()
	strip.texture = lip_texture
	strip.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var h: float = LIP_HEIGHT
	strip.polygon = PackedVector2Array([la + Vector2(0, LIP_ABOVE), lb + Vector2(0, LIP_ABOVE), lb + Vector2(0, LIP_ABOVE - h), la + Vector2(0, LIP_ABOVE - h)])
	var v1: float = float(lip_texture.get_height())
	strip.uv = PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, v1), Vector2(u0, v1)])
	top_node.add_child(strip)
