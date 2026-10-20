class_name ResourceNodeLayer
extends Node2D
## Node cha của mọi ResourceNode trong một map (TASK M3; trong cây Y-sort của EntityContainer, như ItemPickupLayer).
## - Đếm ngày: nghe GameClock.day_started → node tới ngày mọc lại thì đầy lại (ngủ qua nhiều ngày: mỗi nửa đêm một
##   signal). Map không có GameClock: luôn là ngày 1, node đã phá không mọc lại.
## - Save (group `saveable`, theo map, id `resource_nodes`): {version, nodes: {node_id: trạng thái}} — chỉ lưu node khác
##   trạng thái đầy. Sau khi tải: node đã tới ngày mọc lại thì mọc ngay.
## - Chuyển tiếp `harvested` của mọi node con (World hiện "+3 Gỗ").

signal harvested(node: ResourceNode, stacks: Array[ItemStack])
signal regrown(node: ResourceNode)

const STATE_VERSION: int = 1

@export var clock: GameClock
@export var save_id: String = "resource_nodes"

var _last_day: int = 0


func _ready() -> void:
	y_sort_enabled = true
	var ids: Array[String] = []
	for node: ResourceNode in get_nodes():
		if node.node_id.is_empty() or ids.has(node.node_id):
			push_error("[ResourceNodeLayer] node_id rỗng hoặc trùng '%s' (%s)." % [node.node_id, node.get_path()])
		ids.append(node.node_id)
		node.harvested.connect(func(source: ResourceNode, stacks: Array[ItemStack]) -> void: harvested.emit(source, stacks))
	if clock != null:
		_last_day = clock.get_day()
		clock.minute_changed.connect(_on_minute_changed)


func get_day() -> int:
	return clock.get_day() if clock != null else 1


func get_nodes() -> Array[ResourceNode]:
	var result: Array[ResourceNode] = []
	for child: Node in get_children():
		var node: ResourceNode = child as ResourceNode
		if node != null:
			result.append(node)
	return result


func find_resource(node_id: String) -> ResourceNode:
	for node: ResourceNode in get_nodes():
		if node.node_id == node_id:
			return node
	return null


func get_save_id() -> String:
	return save_id


func save_state() -> Dictionary:
	var nodes: Dictionary = {}
	for node: ResourceNode in get_nodes():
		var state: Dictionary = node.save_node_state()
		if not state.is_empty():
			nodes[node.node_id] = state
	return {"version": STATE_VERSION, "nodes": nodes}


func load_state(state: Dictionary) -> void:
	var nodes: Dictionary = state.get("nodes", {}) if state.get("nodes") is Dictionary else {}
	for node: ResourceNode in get_nodes():
		var saved: Variant = nodes.get(node.node_id, {})
		node.load_node_state(saved if saved is Dictionary else {})
	_regrow_due(get_day())


## Đồng hồ đổi (kể cả nhảy giờ / tải save — thứ tự nạp đồng hồ và layer không cố định nên load_state cũng tự kiểm tra).
func _on_minute_changed(day: int, _minute: int) -> void:
	if day != _last_day:
		_last_day = day
		_regrow_due(day)


func _regrow_due(day: int) -> void:
	for node: ResourceNode in get_nodes():
		if node.check_regrow(day):
			regrown.emit(node)
