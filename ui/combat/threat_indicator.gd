class_name ThreatIndicator
extends Control
## Chỉ báo quái đang đuổi mà ở ngoài màn hình (TASK M4): mũi tên đỏ ở mép màn hình chỉ hướng quái (Enemy trong group
## `enemies`, is_hunting()). Chỉ hiển thị, đọc vị trí world → màn hình qua canvas transform mỗi frame.

const EDGE_MARGIN: float = 22.0
const COLOR: Color = Color(1, 0.25, 0.2, 0.9)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


## [{position, target, enemy}] cho từng quái đang đuổi ngoài màn hình (test/debug).
func get_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, get_viewport_rect().size)
	var scene: Node = get_tree().current_scene
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or not enemy.is_hunting() or (scene != null and not scene.is_ancestor_of(enemy)):
			continue
		var screen: Vector2 = enemy.get_global_transform_with_canvas().origin
		if viewport_rect.has_point(screen):
			continue
		markers.append({"position": ScreenEdge.clamp_to_edge(screen, viewport_rect, EDGE_MARGIN), "target": screen, "enemy": enemy})
	return markers


func _draw() -> void:
	for marker: Dictionary in get_markers():
		draw_colored_polygon(ScreenEdge.arrow(marker["position"], marker["target"], 12.0, 7.0), COLOR)
