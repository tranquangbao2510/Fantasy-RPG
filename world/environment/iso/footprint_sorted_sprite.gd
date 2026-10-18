@tool
class_name FootprintSortedSprite
extends Node2D
## Sprite lớn trong map isometric (cầu vòm, cầu thang, tường dài) được cắt thành các lát dọc rộng `slice_width` px.
## Mỗi lát là một node Y-sort riêng, neo tại MÉP TRƯỚC của `footprint` (polygon chân vật trên mặt đất, local) tại
## giữa lát → entity đứng trước phần nào của vật thì vẽ đè lên phần đó, đứng sau thì bị che; không cần một anchor
## duy nhất cho cả vật dài chạy chéo. Node con sinh ra không có owner nên không lưu vào scene.
## Node này phải nằm trong cây Y-sort (mọi node cha tới EntityContainer đều bật y_sort_enabled).

@export var texture: Texture2D:
	set(value):
		texture = value
		_queue_rebuild()
## Vị trí góc trên-trái của ảnh (local, px world) và tỉ lệ texel → world.
@export var image_offset: Vector2 = Vector2.ZERO:
	set(value):
		image_offset = value
		_queue_rebuild()
@export var image_scale: float = 0.5:
	set(value):
		image_scale = value
		_queue_rebuild()
@export var footprint: PackedVector2Array = PackedVector2Array():
	set(value):
		footprint = value
		_queue_rebuild()
@export var slice_width: float = 16.0:
	set(value):
		slice_width = maxf(4.0, value)
		_queue_rebuild()

var _rebuild_queued: bool = false


func _ready() -> void:
	y_sort_enabled = true
	_rebuild()


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
	if texture == null:
		return
	var width_px: float = texture.get_width() * image_scale
	var slices: int = maxi(1, ceili(width_px / slice_width))
	var texel_step: float = texture.get_width() / float(slices)
	for k: int in slices:
		var x0: float = image_offset.x + k * texel_step * image_scale
		var cx: float = x0 + texel_step * image_scale * 0.5
		var slice: Sprite2D = Sprite2D.new()
		slice.set_meta(&"generated", true)
		slice.texture = texture
		slice.centered = false
		slice.region_enabled = true
		slice.region_rect = Rect2(k * texel_step, 0, texel_step, texture.get_height())
		slice.scale = Vector2(image_scale, image_scale)
		slice.position = Vector2(cx, _front_y(cx))
		slice.offset = (Vector2(x0, image_offset.y) - slice.position) / image_scale
		add_child(slice)


## y lớn nhất của footprint tại hoành độ x (mép trước); ngoài footprint thì dùng điểm gần nhất.
func _front_y(x: float) -> float:
	if footprint.size() < 3:
		return 0.0
	var best: float = -INF
	var nearest: Vector2 = footprint[0]
	for i: int in footprint.size():
		var a: Vector2 = footprint[i]
		var b: Vector2 = footprint[(i + 1) % footprint.size()]
		if absf(a.x - x) < absf(nearest.x - x):
			nearest = a
		if (a.x - x) * (b.x - x) <= 0.0 and absf(b.x - a.x) > 0.001:
			best = maxf(best, lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	return best if best > -INF else nearest.y
