class_name PlacementCheck
extends RefCounted
## Kiểm tra chỗ đặt vật dựng (lều, TASK M2): "đất trống, đúng tầng, không chồng vật cản".
## Lý do bị chặn nói rõ vì sao (TASK M6.1), kiểm theo thứ tự:
## - Sai tầng: ElevationMap (nếu map có) cho tầng tại điểm đặt ≠ tầng của người dựng (điểm dưới gầm cầu tính là tầng cao).
## - Đất không bằng: điểm đặt đúng tầng nhưng footprint vắt qua mép tầng (một điểm trên viền footprint ở tầng khác).
## - Địa hình: TerrainLogic (nếu có) tại điểm đặt là nước / vách / vực.
## - Quá gần ruộng (chỉ khi `building` — dựng lều / lửa trại; quái vẫn sinh được cạnh ruộng): footprint chạm vùng ruộng
##   (FarmField, group `farm_fields`) hoặc ô ruộng.
## - Có vật cản: footprint ellipse (bán kính trên mặt đất) chạm thân va chạm của map (layer world + vách tầng đó), thân
##   enemy, hay vật tương tác khác (rương, giường, lều...). Bỏ qua các RID trong `exclude` (Player).

const BLOCKED_TERRAIN: Array[StringName] = [&"water", &"cliff", &"void"]
const INTERACTION_LAYER: int = 1 << 2
const ENEMY_LAYER: int = 1 << 3
## Số điểm trên viền footprint (kiểm tầng, ruộng).
const OUTLINE_POINTS: int = 12

const WRONG_TIER: String = "Sai tầng: chỗ đặt không cùng tầng với bạn."
const UNEVEN_GROUND: String = "Đất không bằng: chỗ đặt vắt qua mép tầng."
const NEAR_FIELD: String = "Quá gần ruộng: dựng cách ruộng xa hơn."
const OBSTACLE: String = "Có vật cản ở chỗ dựng."
const OBSTACLE_NAMED: String = "Có vật cản: %s chắn chỗ dựng."


## "" nếu đặt được, ngược lại là lý do (hiện cho người chơi).
static func get_block_reason(space: PhysicsDirectSpaceState2D, scene: Node, at: Vector2, tier: int, radius: float,
		squash: float, exclude: Array[RID] = [], building: bool = true) -> String:
	var outline: PackedVector2Array = GroundSpace.circle(Vector2.ZERO, radius, squash, OUTLINE_POINTS)
	var elevation: ElevationMap = scene.get_tree().get_first_node_in_group(ElevationMap.GROUP) as ElevationMap
	if elevation != null and tier >= 0:
		if elevation.get_tier_at(at) != tier:
			return WRONG_TIER
		for point: Vector2 in outline:
			if elevation.get_tier_at(at + point) != tier:
				return UNEVEN_GROUND
	for node: Node in scene.find_children("*", "TerrainLogic", true, false):
		var terrain: StringName = (node as TerrainLogic).get_terrain_at(at)
		if BLOCKED_TERRAIN.has(terrain):
			return "Không dựng được trên %s." % {&"water": "nước", &"cliff": "vách đá", &"void": "vực"}[terrain]
	for node: Node in scene.get_tree().get_nodes_in_group(FarmField.GROUP) if building else []:
		var field: FarmField = node as FarmField
		if field == null or not scene.is_ancestor_of(field):
			continue
		if field.plot_at(at) != null or Array(outline).any(func(point: Vector2) -> bool: return field.plot_at(at + point) != null):
			return NEAR_FIELD
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = GroundSpace.polygon_shape(outline)
	query.transform = Transform2D(0.0, at)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = exclude
	var tier_bits: int = ElevationMap.tier_bit(tier) if elevation != null and tier >= 0 else 0
	query.collision_mask = 1 | tier_bits | ENEMY_LAYER | INTERACTION_LAYER
	var hits: Array[Dictionary] = space.intersect_shape(query, 8)
	if hits.is_empty():
		return ""
	for hit: Dictionary in hits:
		if building and hit.get("collider") is FarmPlot:
			return NEAR_FIELD
	var blocker_name: String = _blocker_name(hits[0].get("collider") as Node)
	return OBSTACLE_NAMED % blocker_name if not blocker_name.is_empty() else OBSTACLE


## Tên vật cản cho người chơi: vật tương tác (rương, giường, lều...) hoặc quái; "" nếu là vật cản của map (cây, đá, tường).
static func _blocker_name(collider: Node) -> String:
	var node: Node = collider
	while node != null:
		if node is Interactable:
			return (node as Interactable).get_interaction_name()
		if node is Enemy:
			return "quái"
		node = node.get_parent()
	return ""
