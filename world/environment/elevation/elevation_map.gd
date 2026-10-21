class_name ElevationMap
extends Node2D
## Gốc hệ thống Discrete Elevation Tiers của một map (TASK VISUAL 01).
## Đặt trong EntityContainer (y_sort_enabled) để các khối địa hình cao Y-sort cùng entity.
## Lúc _ready, gom hình học từ con cháu (ElevatedTerrain, ElevatedDeck, ElevationConnector) và sinh collision theo tầng:
## - Tầng t ≥ 1: tường = đường bao vùng đi được của tầng t (mặt trên + mặt cầu + hành lang connector).
## - Tầng dưới (base tier): tường = đường bao khối địa hình cao (mặt trên ∪ mặt vách) trừ hành lang connector.
## Mỗi tầng một physics layer riêng; ElevationAgent đổi collision_mask của thân theo tầng hiện tại.
## Nguồn sự thật cho tầng/collision là hình học này (không phải texture, không phải lưới logic).

const GROUP: StringName = &"elevation_map"
## Physics layer (đánh số 1..32) của tầng 0; tầng t dùng layer FIRST_TIER_LAYER + t.
const FIRST_TIER_LAYER: int = 7
const MAX_TIERS: int = 2
## Mỗi tầng cách nhau TIER_Z_STEP z_index: occupant tầng cao luôn vẽ trên nội dung tầng thấp.
const TIER_Z_STEP: int = 10
## Chi tiết mặt đất của tầng cao (decal trên mặt plateau): dưới occupant của tầng đó.
const GROUND_DETAIL_Z_OFFSET: int = -6

var _walkable: Dictionary = {}  # tier -> Array[PackedVector2Array] (global)
var _blocked: Dictionary = {}  # tier -> Array[PackedVector2Array] (global): khối tầng cao chặn tầng này (TASK M4.1)
var _built: bool = false


static func tier_bit(tier: int) -> int:
	return 1 << (FIRST_TIER_LAYER - 1 + clampi(tier, 0, MAX_TIERS - 1))


static func all_tier_bits() -> int:
	var bits: int = 0
	for t: int in MAX_TIERS:
		bits |= tier_bit(t)
	return bits


static func tier_z(tier: int) -> int:
	return tier * TIER_Z_STEP


func _ready() -> void:
	add_to_group(GROUP)
	y_sort_enabled = true
	if Engine.is_editor_hint():
		return
	_build()


## Tầng tại một điểm world: tầng cao nhất có vùng đi được chứa điểm, ngược lại 0.
## Lưu ý: dưới mặt cầu, điểm thuộc cả hai tầng → trả tầng cao. Dùng cho spawn/reset, không dùng mỗi frame.
func get_tier_at(world_point: Vector2) -> int:
	_build()
	for tier: int in range(MAX_TIERS - 1, 0, -1):
		for polygon: PackedVector2Array in _walkable.get(tier, []):
			if Geometry2D.is_point_in_polygon(world_point, polygon):
				return tier
	return 0


func get_walkable_polygons(tier: int) -> Array:
	_build()
	return _walkable.get(tier, [])


## Vùng bị khối tầng cao chặn ở tầng `tier` (đã trừ hành lang cầu thang; polygon cùng chiều kim đồng hồ là lỗ). Dùng để bake
## navmesh theo tầng (TierNavigation, TASK M4.1).
func get_blocked_polygons(tier: int) -> Array:
	_build()
	return _blocked.get(tier, [])


func _build() -> void:
	if _built:
		return
	_built = true
	var terrains: Array[Node] = find_children("*", "ElevatedTerrain", true, false)
	var decks: Array[Node] = find_children("*", "ElevatedDeck", true, false)
	var connectors: Array[Node] = find_children("*", "ElevationConnector", true, false)
	var walk_sources: Dictionary = {}
	var block_sources: Dictionary = {}
	for node: Node in terrains:
		var terrain: ElevatedTerrain = node as ElevatedTerrain
		_append(walk_sources, terrain.tier, terrain.get_walkable_polygon())
		_append(block_sources, terrain.tier - 1, terrain.get_blocking_polygon())
	for node: Node in decks:
		var deck: ElevatedDeck = node as ElevatedDeck
		_append(walk_sources, deck.tier, deck.get_walkable_polygon())
	for node: Node in connectors:
		var connector: ElevationConnector = node as ElevationConnector
		_append(walk_sources, connector.upper_tier, connector.get_corridor_polygon())
	for tier: int in MAX_TIERS:
		var walls: Array[PackedVector2Array] = []
		if tier > 0:
			var walkable: Array[PackedVector2Array] = _union(walk_sources.get(tier, []))
			_walkable[tier] = walkable
			walls.append_array(walkable)
		var blocked: Array[PackedVector2Array] = _union(block_sources.get(tier, []))
		for node: Node in connectors:
			var connector: ElevationConnector = node as ElevationConnector
			if connector.lower_tier == tier:
				blocked = _subtract(blocked, connector.get_corridor_polygon())
		_blocked[tier] = blocked
		walls.append_array(blocked)
		if not walls.is_empty():
			_add_wall_body(tier, walls)


func _append(target: Dictionary, tier: int, polygon: PackedVector2Array) -> void:
	if tier < 0 or polygon.size() < 3:
		return
	# Polygon đầu vào luôn là "outer" (ngược chiều kim đồng hồ); polygon cùng chiều kim đồng hồ bị coi là lỗ.
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	if not target.has(tier):
		target[tier] = [] as Array[PackedVector2Array]
	(target[tier] as Array[PackedVector2Array]).append(polygon)


## Hợp các polygon; giữ cả lỗ (hole) như một vòng tường riêng.
func _union(polygons: Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in polygons:
		var current: PackedVector2Array = polygon
		var keep: Array[PackedVector2Array] = []
		for other: PackedVector2Array in result:
			if Geometry2D.is_polygon_clockwise(other) or Geometry2D.intersect_polygons(current, other).is_empty():
				keep.append(other)
				continue
			var merged: Array[PackedVector2Array] = Geometry2D.merge_polygons(current, other)
			current = PackedVector2Array()
			for part: PackedVector2Array in merged:
				if Geometry2D.is_polygon_clockwise(part):
					keep.append(part)
				elif part.size() > current.size():
					current = part
		keep.append(current)
		result = keep
	return result


func _subtract(polygons: Array[PackedVector2Array], cutter: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_polygon_clockwise(polygon):
			result.append(polygon)
			continue
		result.append_array(Geometry2D.clip_polygons(polygon, cutter))
	return result


func _add_wall_body(tier: int, loops: Array[PackedVector2Array]) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "TierWalls%d" % tier
	body.collision_layer = tier_bit(tier)
	body.collision_mask = 0
	add_child(body)
	body.global_transform = Transform2D.IDENTITY
	for loop: PackedVector2Array in loops:
		var shape: CollisionPolygon2D = CollisionPolygon2D.new()
		# SEGMENTS: vòng kín chặn từ cả hai phía (agent tầng thấp ở ngoài, agent tầng cao ở trong).
		shape.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		shape.polygon = loop
		body.add_child(shape)
