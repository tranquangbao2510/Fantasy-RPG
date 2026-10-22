class_name EnemySpawner
extends Node
## Sinh quái theo bảng spawn của map (TASK M4). Một node trong World (map có GameClock); Combat Sandbox không có.
## - Mỗi `table.spawn_interval` giây thử một lần: chọn dòng (SpawnTable.pick: đúng khung giờ, còn chỗ dưới
##   max_on_map / max_total), chọn điểm hợp lệ (get_spawn_block_reason) quanh người chơi, sinh đủ bầy hoặc không sinh.
## - Khung giờ sinh quái đêm: SpawnTable.night_from_minute (18:00) → trước bình minh (TASK M4.1).
## - Bình minh (GameClock vào DAWN/DAY): quái đêm trong vùng camera thấy mờ dần, ngoài màn hình biến mất ngay.
## - Lưu trong save (map, id `enemies`): loại, HP, vị trí, tầng, bầy của từng con còn sống. Tải lại ban ngày → áp luật
##   bình minh (sau khi mọi saveable đã nạp, vì thứ tự nạp đồng hồ / spawner không cố định).
## - Phím debug (build debug): F1 Bóng ma, F2 bầy sói, F4 Thây ma (sinh gần người chơi, bỏ qua luật màn hình / cap),
##   F10 bật/tắt vẽ bán kính phát hiện (EnemyDebugView).
## Signal cho âm thanh / HUD gắn sau: enemy_spawned, enemy_alerted, dawn_cleared.

signal enemy_spawned(enemy: Enemy)
signal enemy_alerted(enemy: Enemy)
## Bình minh đã dọn quái đêm (`count` con).
signal dawn_cleared(count: int)

const STATE_VERSION: int = 1
const DEBUG_ACTIONS: Array[StringName] = [&"debug_spawn_shade", &"debug_spawn_wolves", &"debug_spawn_ghoul"]

@export var table: SpawnTable
@export var clock: GameClock
@export var player: Node2D
## Nơi thêm quái (EntityContainer — Y-sort cùng Player).
@export var container: Node2D
## Tỉ lệ dọc mặt đất (0.5 = map isometric: quái sinh ra được gắn IsoActorAdapter).
@export var ground_squash: float = 1.0
@export var enabled: bool = true
@export var save_id: String = "enemies"
## enemy_id ứng với từng phím debug (DEBUG_ACTIONS).
@export var debug_spawn_ids: Array[StringName] = [&"shade", &"night_wolf", &"forest_ghoul"]
## Vùng map (world) — World đặt lúc _ready. Rect2() = không kiểm tra.
var map_rect: Rect2 = Rect2()

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawned: Array[Enemy] = []
var _timer: float = 0.0
var _next_pack_id: int = 1
## Lưới địa hình của map (tìm một lần). null = map không có.
var _terrain: TerrainLogic
var _terrain_searched: bool = false


func _ready() -> void:
	rng.randomize()
	add_to_group(&"saveable")
	if clock != null:
		clock.phase_changed.connect(_on_phase_changed)
	if table != null:
		_timer = table.spawn_interval
		for error: String in table.get_validation_errors():
			push_error("[EnemySpawner] Bảng spawn lỗi: %s" % error)


func _physics_process(delta: float) -> void:
	if not enabled or table == null or player == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = table.spawn_interval
	try_spawn()


func _unhandled_input(event: InputEvent) -> void:
	if not DebugKeys.enabled():
		return
	for i: int in DEBUG_ACTIONS.size():
		if event.is_action_pressed(DEBUG_ACTIONS[i]) and i < debug_spawn_ids.size():
			debug_spawn(debug_spawn_ids[i])
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"debug_enemy_radius"):
		set_debug_radius_visible(not EnemyDebugView.shown)
		get_viewport().set_input_as_handled()


## Khung giờ quái đêm sinh: từ SpawnTable.night_from_minute (18:00) tới trước bình minh (TASK M4.1; M4: từ hoàng hôn 17:00).
## Map không có đồng hồ: luôn là ngày.
func is_night_period() -> bool:
	if clock == null or table == null:
		return false
	var minute: float = clock.get_minute_of_day()
	return minute >= table.night_from_minute or minute < clock.settings.dawn_start


## Bình minh / ban ngày (GameClock phase DAWN, DAY): quái đêm phải tan biến.
func is_daylight() -> bool:
	if clock == null:
		return true
	var phase: GameClock.Phase = clock.get_phase()
	return phase == GameClock.Phase.DAWN or phase == GameClock.Phase.DAY


## Quái còn sống do spawner quản lý.
func get_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy: Enemy in _spawned:
		if is_instance_valid(enemy) and not enemy.is_dead() and not enemy.is_fading():
			result.append(enemy)
	return result


## enemy_id → số con còn sống.
func count_by_type() -> Dictionary:
	var counts: Dictionary = {}
	for enemy: Enemy in get_enemies():
		counts[enemy.enemy_id] = int(counts.get(enemy.enemy_id, 0)) + 1
	return counts


## Thử một lần spawn theo bảng. Trả về các con vừa sinh (rỗng nếu không dòng nào còn chỗ / không tìm được chỗ).
func try_spawn() -> Array[Enemy]:
	var result: Array[Enemy] = []
	if table == null or player == null:
		return result
	var counts: Dictionary = count_by_type()
	var total: int = get_enemies().size()
	var entry: SpawnEntry = table.pick(rng, is_night_period(), counts, total)
	if entry == null:
		return result
	var room: int = mini(entry.max_on_map - int(counts.get(entry.enemy_id, 0)), table.max_total - total)
	var size: int = mini(rng.randi_range(entry.pack_min, entry.pack_max), room)
	if size < entry.pack_min:
		return result
	var tier: int = entry.tiers[rng.randi_range(0, entry.tiers.size() - 1)]
	for attempt: int in table.position_attempts:
		var angle: float = rng.randf() * TAU
		var distance: float = rng.randf_range(table.min_player_distance, table.max_player_distance)
		var anchor: Vector2 = player.global_position + GroundSpace.to_screen(Vector2.from_angle(angle) * distance, ground_squash)
		if not get_spawn_block_reason(anchor, tier).is_empty():
			continue
		var points: Array[Vector2] = _pack_points(anchor, tier, size, true)
		if points.size() == size:
			return spawn_group(entry, points, tier)
	return result


## Lý do điểm không spawn được ("" = được). `check_view` = kiểm tra ngoài màn hình + khoảng cách tới người chơi.
func get_spawn_block_reason(point: Vector2, tier: int, check_view: bool = true) -> String:
	var scene: Node = _scene()
	if scene == null:
		return "không có scene"
	if map_rect.has_area() and not map_rect.has_point(point):
		return "ngoài map"
	if check_view:
		if get_view_rect().grow(table.screen_margin if table != null else 0.0).has_point(point):
			return "trong màn hình"
		if player != null and GroundSpace.length(point - player.global_position, ground_squash) < \
				(table.min_player_distance if table != null else 0.0):
			return "quá gần người chơi"
	if VisionLight.find_safe_light(scene, point, table.safe_zone_margin if table != null else 0.0) != null:
		return "trong vùng sáng an toàn"
	if not _terrain_searched:
		_terrain_searched = true
		var found: Array[Node] = scene.find_children("*", "TerrainLogic", true, false)
		_terrain = found[0] as TerrainLogic if not found.is_empty() else null
	if _terrain != null and _terrain.get_terrain_at(point) == &"":
		return "ngoài lưới địa hình"
	var radius: float = table.footprint_radius if table != null else 10.0
	return PlacementCheck.get_block_reason(scene.get_viewport().world_2d.direct_space_state, scene, point, tier, radius, ground_squash,
		[], false)


## Vùng world camera đang thấy.
func get_view_rect() -> Rect2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Rect2()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()


## Sinh một nhóm theo dòng bảng tại các điểm (≥ 2 điểm → chung một EnemyPack). Không kiểm tra luật vị trí.
func spawn_group(entry: SpawnEntry, points: Array[Vector2], tier: int) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var pack: EnemyPack = null
	if points.size() > 1:
		pack = EnemyPack.new(_next_pack_id)
		_next_pack_id += 1
	for point: Vector2 in points:
		var enemy: Enemy = _spawn_one(entry, point, tier, pack)
		if enemy != null:
			result.append(enemy)
	return result


## Bình minh: quái đêm trong vùng nhìn thấy mờ dần, ngoài màn hình biến mất ngay. Trả về số con đã dọn.
func clear_night_enemies() -> int:
	var view: Rect2 = get_view_rect()
	var count: int = 0
	for enemy: Enemy in _spawned.duplicate():
		if not is_instance_valid(enemy) or enemy.is_fading():
			continue
		var entry: SpawnEntry = table.find_entry(enemy.enemy_id) if table != null else null
		if entry != null and not entry.is_night_only():
			continue
		enemy.fade_out(table.dawn_fade_time if view.has_point(enemy.global_position) else 0.0)
		_spawned.erase(enemy)
		count += 1
	if count > 0:
		dawn_cleared.emit(count)
	return count


## Debug: sinh `enemy_id` (cả bầy theo bảng) cạnh người chơi, bỏ qua luật màn hình / khoảng cách / cap / khung giờ.
func debug_spawn(enemy_id: StringName) -> Array[Enemy]:
	var entry: SpawnEntry = table.find_entry(enemy_id) if table != null else null
	if entry == null or player == null:
		return []
	var agent: ElevationAgent = ElevationAgent.find_for(player)
	var tier: int = agent.get_tier() if agent != null else entry.tiers[0]
	for attempt: int in 24:
		var angle: float = TAU * attempt / 24.0
		var anchor: Vector2 = player.global_position + GroundSpace.to_screen(Vector2.from_angle(angle) * 120.0, ground_squash)
		if not get_spawn_block_reason(anchor, tier, false).is_empty():
			continue
		var points: Array[Vector2] = _pack_points(anchor, tier, entry.pack_max, false)
		if points.size() >= entry.pack_min:
			return spawn_group(entry, points, tier)
	return []


func set_debug_radius_visible(value: bool) -> void:
	EnemyDebugView.shown = value
	for node: Node in get_tree().get_nodes_in_group(EnemyDebugView.GROUP):
		(node as EnemyDebugView).set_debug_visible(value)


# --- Nội bộ --------------------------------------------------------------------------------------

func _scene() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


## Điểm đầu + các điểm quanh nó (cách nhau ≥ 2 footprint) cho cả bầy; trả về ít hơn `size` nếu thiếu chỗ.
func _pack_points(anchor: Vector2, tier: int, size: int, check_view: bool) -> Array[Vector2]:
	var points: Array[Vector2] = [anchor]
	var spread: float = table.pack_spread if table != null else 32.0
	var spacing: float = (table.footprint_radius if table != null else 10.0) * 2.0
	var tries: int = 0
	while points.size() < size and tries < size * 12:
		tries += 1
		var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(spacing, spread)
		var point: Vector2 = anchor + GroundSpace.to_screen(offset, ground_squash)
		var crowded: bool = points.any(func(other: Vector2) -> bool:
			return GroundSpace.length(other - point, ground_squash) < spacing)
		if not crowded and get_spawn_block_reason(point, tier, check_view).is_empty():
			points.append(point)
	return points


func _spawn_one(entry: SpawnEntry, point: Vector2, tier: int, pack: EnemyPack, state: Dictionary = {}) -> Enemy:
	var enemy: Enemy = entry.scene.instantiate() as Enemy
	if enemy == null:
		push_error("[EnemySpawner] Scene của '%s' không phải Enemy." % entry.enemy_id)
		return null
	enemy.enemy_id = entry.enemy_id
	enemy.target = player
	enemy.pack = pack
	if pack != null:
		pack.add_member(enemy)
	var agent: ElevationAgent = ElevationAgent.new()
	agent.name = "ElevationAgent"
	agent.initial_tier = tier
	enemy.add_child(agent)
	if ground_squash < 1.0:
		var adapter: IsoActorAdapter = IsoActorAdapter.new()
		adapter.name = "IsoActorAdapter"
		adapter.shadow = enemy.get_node_or_null(^"Visual/Shadow") as Polygon2D
		adapter.body_shape = enemy.get_node_or_null(^"CollisionShape2D") as CollisionShape2D
		enemy.add_child(adapter)
	var parent: Node2D = container if container != null else get_parent() as Node2D
	enemy.position = parent.to_local(point) if parent != null else point
	parent.add_child(enemy)
	if not state.is_empty():
		enemy.apply_saved(state)
	_spawned.append(enemy)
	enemy.alerted.connect(enemy_alerted.emit)
	enemy.get_health().died.connect(_on_enemy_died.bind(enemy))
	enemy.tree_exited.connect(func() -> void: _spawned.erase(enemy))
	enemy_spawned.emit(enemy)
	return enemy


func _on_enemy_died(enemy: Enemy) -> void:
	_spawned.erase(enemy)
	var delay: float = table.corpse_time if table != null else 3.0
	get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if is_instance_valid(enemy):
			enemy.fade_out(1.0))


func _on_phase_changed(_phase: GameClock.Phase) -> void:
	if is_daylight():
		clear_night_enemies()


## Sau khi tải save: ban ngày thì dọn quái đêm (luật bình minh).
func _apply_time_rules() -> void:
	if is_daylight():
		clear_night_enemies()


# --- Save ----------------------------------------------------------------------------------------

func get_save_id() -> String:
	return save_id


func save_state() -> Dictionary:
	var enemies: Array = []
	for enemy: Enemy in get_enemies():
		var state: Dictionary = enemy.capture_state()
		state["type"] = String(enemy.enemy_id)
		state["pack"] = enemy.pack.pack_id if enemy.pack != null else 0
		enemies.append(state)
	return {"version": STATE_VERSION, "enemies": enemies}


## Thay quái hiện có bằng quái trong save. Loại không còn trong bảng / HP ≤ 0 / vị trí lỗi → bỏ qua (cảnh báo).
func load_state(state: Dictionary) -> void:
	for enemy: Enemy in _spawned.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	_spawned.clear()
	var packs: Dictionary[int, EnemyPack] = {}
	var entries: Variant = state.get("enemies", [])
	for item: Variant in (entries if entries is Array else []):
		if not item is Dictionary:
			continue
		var saved: Dictionary = item
		var entry: SpawnEntry = table.find_entry(StringName(str(saved.get("type", "")))) if table != null else null
		var hp: Variant = saved.get("hp")
		var position_value: Variant = saved.get("position")
		if entry == null or not (hp is int or hp is float) or int(hp) <= 0 or not (position_value is Array and position_value.size() == 2):
			push_warning("[EnemySpawner] Bỏ quái lỗi trong save: %s" % saved)
			continue
		var pack_id: int = int(saved.get("pack", 0)) if (saved.get("pack") is int or saved.get("pack") is float) else 0
		var pack: EnemyPack = null
		if pack_id > 0:
			if not packs.has(pack_id):
				packs[pack_id] = EnemyPack.new(_next_pack_id)
				_next_pack_id += 1
			pack = packs[pack_id]
		var tier: Variant = saved.get("tier", -1)
		_spawn_one(entry, Vector2(position_value[0], position_value[1]), int(tier) if (tier is int or tier is float) else -1, pack, saved)
	_apply_time_rules.call_deferred()
