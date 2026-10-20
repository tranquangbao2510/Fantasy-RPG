class_name DeathBagMarker
extends Control
## Đánh dấu túi đồ rơi khi chết trên HUD (TASK M2): mỗi DeathBag (group `death_bags`) một dấu. Túi trong màn hình:
## dấu nhỏ phía trên túi; ngoài màn hình: mũi tên ở mép màn hình chỉ hướng túi + khoảng cách (px).
## Chỉ hiển thị, đọc vị trí world → màn hình qua canvas transform mỗi frame.

const EDGE_MARGIN: float = 28.0
const COLOR: Color = Color(1, 0.35, 0.3)

## Lấy vị trí người chơi để ghi khoảng cách. Tùy chọn.
var tracked: Node2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## Vị trí (màn hình) và trạng thái các dấu hiện tại: [{position, on_screen, distance}] — dùng cho test/debug.
func get_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var inner: Rect2 = viewport_rect.grow(-EDGE_MARGIN)
	for node: Node in get_tree().get_nodes_in_group(DeathBag.GROUP):
		var bag: DeathBag = node as DeathBag
		if bag == null or bag.is_queued_for_deletion():
			continue
		var screen: Vector2 = bag.get_global_transform_with_canvas().origin
		var on_screen: bool = viewport_rect.has_point(screen)
		var shown: Vector2 = screen + Vector2(0, -26)
		if not on_screen:
			var center: Vector2 = viewport_rect.get_center()
			var direction: Vector2 = (screen - center).normalized()
			var scale_x: float = (inner.size.x * 0.5) / maxf(absf(direction.x), 0.0001)
			var scale_y: float = (inner.size.y * 0.5) / maxf(absf(direction.y), 0.0001)
			shown = center + direction * minf(scale_x, scale_y)
		var distance: float = tracked.global_position.distance_to(bag.global_position) if tracked != null else 0.0
		markers.append({"position": shown, "on_screen": on_screen, "distance": distance, "target": screen})
	return markers


func _draw() -> void:
	var font: Font = get_theme_default_font()
	for marker: Dictionary in get_markers():
		var at: Vector2 = marker["position"]
		if marker["on_screen"]:
			draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -8), at + Vector2(6, -8), at + Vector2(0, 2)]), COLOR)
			continue
		var direction: Vector2 = (Vector2(marker["target"]) - at).normalized()
		var side: Vector2 = direction.orthogonal() * 8.0
		draw_colored_polygon(PackedVector2Array([at + direction * 14.0, at - direction * 6.0 + side, at - direction * 6.0 - side]), COLOR)
		draw_string(font, at - direction * 22.0 + Vector2(-20, 4), "Túi %dm" % roundi(float(marker["distance"]) / 32.0),
			HORIZONTAL_ALIGNMENT_CENTER, 40, 11, COLOR)
