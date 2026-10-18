class_name ElevationAgent
extends Node
## Component gắn vào CharacterBody2D (Player, enemy) trong map có ElevationMap.
## Giữ tầng hiện tại và áp lên thân: collision_mask = mask gốc (không gồm bit tầng) + bit của tầng hiện tại;
## z_index = tầng × ElevationMap.TIER_Z_STEP. Chỉ đổi tầng qua ElevationConnector (không đi xuyên vách).
## Map không có ElevationMap: component không làm gì (tương thích map cũ).

signal tier_changed(tier: int, transitioning: bool)

## -1 = tự xác định từ vị trí lúc bắt đầu (ElevationMap.get_tier_at).
@export var initial_tier: int = -1

var _body: CollisionObject2D
var _map: ElevationMap
var _base_mask: int = 0
var _tier: int = 0
var _connectors: Array[ElevationConnector] = []


static func find_for(body: Node) -> ElevationAgent:
	for child: Node in body.get_children():
		if child is ElevationAgent:
			return child as ElevationAgent
	return null


func _ready() -> void:
	_body = get_parent() as CollisionObject2D
	if _body == null:
		push_warning("[ElevationAgent] Cha không phải CollisionObject2D; bỏ qua.")
		return
	add_to_group(&"test_resettable")
	_base_mask = _body.collision_mask & ~ElevationMap.all_tier_bits()
	_setup.call_deferred()


func get_tier() -> int:
	return _tier


func is_transitioning() -> bool:
	return not _connectors.is_empty()


func enter_connector(connector: ElevationConnector) -> void:
	if _map == null or _connectors.has(connector):
		return
	_connectors.append(connector)
	_apply()


func exit_connector(connector: ElevationConnector) -> void:
	if not _connectors.has(connector):
		return
	_connectors.erase(connector)
	if _connectors.is_empty():
		_tier = connector.get_tier_for(_body.global_position)
	_apply()


## Reset thử nghiệm: thân có thể vừa bị dịch chuyển → bỏ trạng thái chuyển tầng, tính lại tầng từ vị trí mới.
func reset_state() -> void:
	_connectors.clear()
	_setup.call_deferred()


func _setup() -> void:
	_map = get_tree().get_first_node_in_group(ElevationMap.GROUP) as ElevationMap
	if _map == null:
		return
	_tier = initial_tier if initial_tier >= 0 else _map.get_tier_at(_body.global_position)
	_apply()


func _apply() -> void:
	var body_item: CanvasItem = _body as CanvasItem
	if is_transitioning():
		# Trên cầu thang: chỉ còn lan can + layer world chặn; vẽ ở tầng cao để không bị mặt vách che.
		_body.collision_mask = _base_mask
		var top: int = _tier
		for connector: ElevationConnector in _connectors:
			top = maxi(top, connector.upper_tier)
		body_item.z_index = ElevationMap.tier_z(top)
	else:
		_body.collision_mask = _base_mask | ElevationMap.tier_bit(_tier)
		body_item.z_index = ElevationMap.tier_z(_tier)
	tier_changed.emit(_tier, is_transitioning())
