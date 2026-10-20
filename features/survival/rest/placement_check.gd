class_name PlacementCheck
extends RefCounted
## Kiểm tra chỗ đặt vật dựng (lều, TASK M2): "đất trống, đúng tầng, không chồng vật cản".
## - Đúng tầng: ElevationMap (nếu map có) cho tầng tại điểm == tầng của người dựng (điểm dưới gầm cầu tính là tầng cao
##   → không dựng được ở đó).
## - Đất trống: TerrainLogic (nếu có) không phải nước / vách / vực.
## - Không chồng vật cản: footprint ellipse (bán kính trên mặt đất) không chạm thân va chạm của map (layer world + vách
##   tầng đó), thân enemy, hay vật tương tác khác (rương, giường, lều...). Bỏ qua các RID trong `exclude` (Player).

const BLOCKED_TERRAIN: Array[StringName] = [&"water", &"cliff", &"void"]
const INTERACTION_LAYER: int = 1 << 2
const ENEMY_LAYER: int = 1 << 3


## "" nếu đặt được, ngược lại là lý do (hiện cho người chơi).
static func get_block_reason(space: PhysicsDirectSpaceState2D, scene: Node, at: Vector2, tier: int, radius: float,
		squash: float, exclude: Array[RID] = []) -> String:
	var elevation: ElevationMap = scene.get_tree().get_first_node_in_group(ElevationMap.GROUP) as ElevationMap
	if elevation != null and tier >= 0 and elevation.get_tier_at(at) != tier:
		return "Không dựng được ở đây (mặt đất không bằng phẳng)."
	for node: Node in scene.find_children("*", "TerrainLogic", true, false):
		var terrain: StringName = (node as TerrainLogic).get_terrain_at(at)
		if BLOCKED_TERRAIN.has(terrain):
			return "Không dựng được trên %s." % {&"water": "nước", &"cliff": "vách đá", &"void": "vực"}[terrain]
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = GroundSpace.polygon_shape(GroundSpace.circle(Vector2.ZERO, radius, squash, 12))
	query.transform = Transform2D(0.0, at)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = exclude
	var tier_bits: int = ElevationMap.tier_bit(tier) if elevation != null and tier >= 0 else 0
	query.collision_mask = 1 | tier_bits | ENEMY_LAYER | INTERACTION_LAYER
	if not space.intersect_shape(query, 1).is_empty():
		return "Không đủ chỗ trống để dựng."
	return ""
