class_name TierNavigation
extends Node2D
## Navmesh theo tầng cho quái tìm đường (TASK M4.1). Một node trong World của map có ElevationMap (Glade).
## Bake LÚC CHẠY (vách tầng do ElevationMap sinh trong _ready, prop đặt layer theo tầng trong _ready nên không bake sẵn
## trong editor được): mỗi tầng t một NavigationRegion2D con, `navigation_layers = 1 << t`:
## - Vùng đi được: tầng 0 = `ground_outline` (đường bao đất liền, vd. LandEdge/Loop); tầng ≥ 1 = vùng đi được của
##   ElevationMap (mặt trên + mặt cầu + hành lang cầu thang).
## - Vật cản: khối tầng cao chặn tầng đó (ElevationMap.get_blocked_polygons) + mọi shape của StaticBody2D trong scene có
##   collision_layer giao `1 | tier_bit(t)` (tầng 0) hoặc `tier_bit(t)` (tầng ≥ 1) — prop, nước, rương, giường, bàn chế
##   tạo, lửa trại, cây/đá còn tài nguyên. Bỏ qua: thân tường tầng (TierWalls*), đường bao đất liền, WorldBoundaryShape2D,
##   shape đang tắt. Khoảng đệm = `agent_radius` (bán kính quái).
## - Vật dựng / node tài nguyên đổi trạng thái (lửa trại dựng/thu, cây bị chặt/mọc lại) → `request_rebake()` (gộp các yêu
##   cầu trong `rebake_delay` giây rồi bake lại) — chọn bake lại thay vì NavigationObstacle2D vì obstacle chỉ ảnh hưởng
##   avoidance, không ảnh hưởng đường tìm được; việc dựng / chặt hiếm nên chi phí bake chấp nhận được.
## - TASK M5: bake chạy TRÊN THREAD (`bake_from_source_geometry_data_async`, `threaded` = true): luồng chính chỉ gom hình
##   học nguồn (vài ms), phần bake (~50–60 ms ở M4.1, gây giật một frame) chạy nền. Region giữ navmesh cũ tới khi bản mới
##   của mọi tầng xong rồi mới đổi cùng lúc. Có yêu cầu bake mới trong lúc đang bake → bake thêm một lượt sau khi xong.
##   Navmesh tầng chưa có lần nào (vừa vào map / vừa tải save) → quái tìm đường đứng chờ (Enemy._steer_to), không đi thẳng.

signal baked

@export var elevation_map: ElevationMap
@export var ground_outline: CollisionPolygon2D
@export var agent_radius: float = 8.0
@export var rebake_delay: float = 0.4
## false = bake đồng bộ trên luồng chính (như M4.1; để so sánh / debug).
@export var threaded: bool = true

var _regions: Dictionary[int, NavigationRegion2D] = {}
var _rebake_left: float = -1.0
## Bake đang chạy trên thread: tầng → NavigationPolygon đang bake (đổi vào region khi mọi tầng xong).
var _in_flight: Dictionary[int, NavigationPolygon] = {}
var _in_flight_left: int = 0
var _bake_started_us: int = 0
## Có yêu cầu bake trong lúc đang bake → bake lại khi lượt hiện tại xong.
var _rebake_after: bool = false
## Thời gian bake gần nhất (ms, cả các tầng, từ lúc bắt đầu tới lúc navmesh mới được gán) — debug / báo cáo hiệu năng.
var last_bake_ms: float = 0.0
## Phần chạy trên luồng chính của lần bake gần nhất (gom hình học nguồn + gán region, ms).
var last_main_thread_ms: float = 0.0
var last_bake_threaded: bool = false


func _ready() -> void:
	set_process(false)
	# Hai tầng chồng nhau trong cùng map nhiều cạnh trùng vị trí → hạ hệ số lưới gộp cạnh (mặc định 1) để không báo lỗi gộp.
	NavigationServer2D.map_set_merge_rasterizer_cell_scale(get_world_2d().navigation_map, 0.05)
	# Sau _ready của mọi node (prop đặt layer theo tầng, ElevationMap dựng tường).
	bake.call_deferred()


func _process(delta: float) -> void:
	_rebake_left -= delta
	if _rebake_left <= 0.0:
		set_process(false)
		bake()


## Yêu cầu bake lại (gộp nhiều yêu cầu gần nhau).
func request_rebake() -> void:
	_rebake_left = rebake_delay
	set_process(true)


## Đang chờ bake (đã có yêu cầu) hoặc đang bake trên thread.
func is_baking() -> bool:
	return is_processing() or _in_flight_left > 0 or _rebake_after


func get_region(tier: int) -> NavigationRegion2D:
	return _regions.get(tier)


static func layer_for_tier(tier: int) -> int:
	return 1 << clampi(tier, 0, 31)


func bake() -> void:
	if _in_flight_left > 0:
		_rebake_after = true
		return
	_rebake_after = false
	_bake_started_us = Time.get_ticks_usec()
	last_bake_threaded = threaded
	var tiers: int = ElevationMap.MAX_TIERS if elevation_map != null else 1
	var sources: Dictionary[int, NavigationMeshSourceGeometryData2D] = {}
	for tier: int in tiers:
		var source: NavigationMeshSourceGeometryData2D = NavigationMeshSourceGeometryData2D.new()
		_add_walkable(source, tier)
		_add_obstructions(source, tier)
		sources[tier] = source
	_in_flight.clear()
	_in_flight_left = tiers
	for tier: int in tiers:
		var polygon: NavigationPolygon = NavigationPolygon.new()
		polygon.agent_radius = agent_radius
		_in_flight[tier] = polygon
		if threaded:
			NavigationServer2D.bake_from_source_geometry_data_async(polygon, sources[tier],
				TierNavigation._deliver_baked.bind(weakref(self), tier))
		else:
			NavigationServer2D.bake_from_source_geometry_data(polygon, sources[tier])
			_on_tier_baked(tier)
	if threaded:
		last_main_thread_ms = (Time.get_ticks_usec() - _bake_started_us) / 1000.0


## Callback của bake async — có thể chạy trên thread của WorkerThreadPool: chuyển về luồng chính; node đã bị giải phóng
## (đổi scene trong lúc bake) thì bỏ qua.
static func _deliver_baked(ref: WeakRef, tier: int) -> void:
	var navigation: TierNavigation = ref.get_ref() as TierNavigation
	if navigation != null:
		navigation._on_tier_baked.call_deferred(tier)


## Một tầng bake xong; khi mọi tầng xong thì gán navmesh mới vào các region cùng lúc (tới lúc đó region giữ bản cũ).
func _on_tier_baked(_tier: int) -> void:
	_in_flight_left -= 1
	if _in_flight_left > 0 or not is_inside_tree():
		return
	var assign_started: int = Time.get_ticks_usec()
	for tier: int in _in_flight:
		var region: NavigationRegion2D = _regions.get(tier)
		if region == null:
			region = NavigationRegion2D.new()
			region.name = "Tier%d" % tier
			region.navigation_layers = layer_for_tier(tier)
			# Các tầng chồng nhau trong cùng map (mép plateau, cầu): không nối cạnh giữa region — tầng tách nhau bằng layer.
			region.use_edge_connections = false
			add_child(region)
			region.global_transform = Transform2D.IDENTITY
			_regions[tier] = region
		region.navigation_polygon = _in_flight[tier]
	_in_flight.clear()
	last_bake_ms = (Time.get_ticks_usec() - _bake_started_us) / 1000.0
	if threaded:
		last_main_thread_ms += (Time.get_ticks_usec() - assign_started) / 1000.0
	else:
		last_main_thread_ms = last_bake_ms
	baked.emit()
	if _rebake_after:
		bake()


func _add_walkable(source: NavigationMeshSourceGeometryData2D, tier: int) -> void:
	if tier == 0:
		if ground_outline != null:
			source.add_traversable_outline(ground_outline.global_transform * ground_outline.polygon)
		return
	for polygon: PackedVector2Array in elevation_map.get_walkable_polygons(tier):
		if Geometry2D.is_polygon_clockwise(polygon):
			source.add_obstruction_outline(polygon)
		else:
			source.add_traversable_outline(polygon)


func _add_obstructions(source: NavigationMeshSourceGeometryData2D, tier: int) -> void:
	if elevation_map != null:
		for polygon: PackedVector2Array in elevation_map.get_blocked_polygons(tier):
			if not Geometry2D.is_polygon_clockwise(polygon):
				source.add_obstruction_outline(polygon)
	var tier_bit: int = ElevationMap.tier_bit(tier) if elevation_map != null else 0
	var mask: int = (1 | tier_bit) if tier == 0 else tier_bit
	var scene: Node = owner if owner != null else get_parent()
	var outline_body: Node = ground_outline.get_parent() if ground_outline != null else null
	for node: Node in scene.find_children("*", "StaticBody2D", true, false):
		var body: StaticBody2D = node as StaticBody2D
		if body == outline_body or (body.collision_layer & mask) == 0 or String(body.name).begins_with("TierWalls") \
				or not body.is_inside_tree():
			continue
		for child: Node in body.get_children():
			var outline: PackedVector2Array = _shape_outline(child)
			if outline.size() >= 3:
				source.add_obstruction_outline(outline)


## Đường bao world của một CollisionShape2D / CollisionPolygon2D (rỗng nếu không hỗ trợ / đang tắt).
func _shape_outline(node: Node) -> PackedVector2Array:
	var poly_node: CollisionPolygon2D = node as CollisionPolygon2D
	if poly_node != null:
		return PackedVector2Array() if poly_node.disabled else poly_node.global_transform * poly_node.polygon
	var shape_node: CollisionShape2D = node as CollisionShape2D
	if shape_node == null or shape_node.disabled or shape_node.shape == null:
		return PackedVector2Array()
	var xf: Transform2D = shape_node.global_transform
	var shape: Shape2D = shape_node.shape
	if shape is CircleShape2D:
		var r: float = (shape as CircleShape2D).radius
		var points: PackedVector2Array = PackedVector2Array()
		for k: int in 12:
			points.append(Vector2.from_angle(TAU * k / 12.0) * r)
		return xf * points
	if shape is RectangleShape2D:
		var half: Vector2 = (shape as RectangleShape2D).size * 0.5
		return xf * PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	if shape is ConvexPolygonShape2D:
		return xf * (shape as ConvexPolygonShape2D).points
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		var hx: float = capsule.radius
		var hy: float = capsule.height * 0.5
		return xf * PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	return PackedVector2Array()
