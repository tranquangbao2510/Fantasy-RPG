class_name ElevationAgent
extends Node
## Component gắn vào thực thể (Player, enemy, bù nhìn) trong map có ElevationMap.
## Giữ tầng hiện tại và áp lên thực thể:
## - CollisionObject2D: collision_mask = mask gốc (không gồm bit tầng) + bit của tầng hiện tại.
## - CanvasItem: z_index = tầng × ElevationMap.TIER_Z_STEP.
## - Combat (TASK VISUAL-02.1): gọi set_elevation(tier_mask, obstacle_mask, ground_z) trên mọi node con có hàm này
##   (Hurtbox, BasicAttackController, AttackComponent, SkillCastingController — duck-typing, module combat không
##   phụ thuộc world). tier_mask = 1 << tầng: đòn/đạn/kỹ năng chỉ trúng Hurtbox có mask giao nhau.
##   Trong hành lang cầu thang: tier_mask = tầng dưới | tầng trên của connector (đánh và bị đánh bởi cả hai tầng),
##   obstacle_mask = 0 (đạn bắn ra không bị vách chặn ngay tại chỗ), indicator vẽ ở tầng trên.
## Chỉ đổi tầng qua ElevationConnector (không đi xuyên vách). Map không có ElevationMap: không làm gì.

signal tier_changed(tier: int, transitioning: bool)

## -1 = tự xác định từ vị trí lúc bắt đầu (ElevationMap.get_tier_at).
@export var initial_tier: int = -1

## z của vùng chỉ báo kỹ năng so với z của tầng: trên mặt đất/chi tiết mặt đất của tầng, dưới occupant.
const INDICATOR_Z_OFFSET: int = -3

var _body: Node2D
var _collider: CollisionObject2D
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
	_body = get_parent() as Node2D
	if _body == null:
		push_warning("[ElevationAgent] Cha không phải Node2D; bỏ qua.")
		return
	_collider = _body as CollisionObject2D
	add_to_group(&"test_resettable")
	if _collider != null:
		_base_mask = _collider.collision_mask & ~ElevationMap.all_tier_bits()
	_setup.call_deferred()


func get_tier() -> int:
	return _tier


func is_transitioning() -> bool:
	return not _connectors.is_empty()


## Mask tầng dùng cho combat (xem mô tả lớp).
func get_tier_mask() -> int:
	var mask: int = 1 << _tier
	for connector: ElevationConnector in _connectors:
		mask |= (1 << connector.lower_tier) | (1 << connector.upper_tier)
	return mask


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


## Đặt tầng trực tiếp (khôi phục save, vật phẩm rơi theo tầng người vứt): bỏ trạng thái chuyển tầng.
## tier < 0 = tính từ vị trí như lúc bắt đầu. Không đổi initial_tier (reset R vẫn dùng giá trị của scene).
func set_tier(tier: int) -> void:
	_connectors.clear()
	if tier < 0:
		_setup()
		return
	_tier = tier
	if _map == null:
		_map = get_tree().get_first_node_in_group(ElevationMap.GROUP) as ElevationMap if is_inside_tree() else null
	if _map != null:
		_apply()


func _setup() -> void:
	_map = get_tree().get_first_node_in_group(ElevationMap.GROUP) as ElevationMap
	if _map == null:
		return
	_tier = initial_tier if initial_tier >= 0 else _map.get_tier_at(_body.global_position)
	_apply()


func _apply() -> void:
	var top: int = _tier
	for connector: ElevationConnector in _connectors:
		top = maxi(top, connector.upper_tier)
	var obstacle_mask: int = 0
	if is_transitioning():
		# Trên cầu thang: chỉ còn lan can + layer world chặn; vẽ ở tầng cao để không bị mặt vách che.
		if _collider != null:
			_collider.collision_mask = _base_mask
	else:
		obstacle_mask = ElevationMap.tier_bit(_tier)
		if _collider != null:
			_collider.collision_mask = _base_mask | obstacle_mask
	_body.z_index = ElevationMap.tier_z(top)
	var tier_mask: int = get_tier_mask()
	for node: Node in _body.find_children("*", "", true, false):
		if node.has_method(&"set_elevation"):
			node.call(&"set_elevation", tier_mask, obstacle_mask, ElevationMap.tier_z(top) + INDICATOR_Z_OFFSET)
	tier_changed.emit(_tier, is_transitioning())
