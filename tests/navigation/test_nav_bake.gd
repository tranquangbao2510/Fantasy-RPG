extends "res://tests/test_base.gd"
## Kiểm thử + đo TASK M5 mục 0 (nợ M4.1): bake navmesh không được làm giật game.
## - Đo thời gian từng frame trên luồng chính (Time.get_ticks_usec giữa hai process_frame) khi: vào map, chặt liên tục 5
##   cây bằng E (rìu ở tay chính), dựng / thu lều, dựng / thu lửa trại. Yêu cầu: không frame nào > 33 ms trong các đoạn
##   chặt cây / dựng / thu.
## - Navmesh cũ vẫn dùng được trong lúc bake bản mới (đường tìm được không bao giờ rỗng giữa hai lần bake).
## - Tải save giữa đêm: quái tìm đường không đi khi navmesh tầng của nó chưa sẵn sàng (không đi thẳng vào vật cản), có
##   navmesh rồi thì đuổi theo đường.
## Số liệu in ra (dòng "MEASURE ...") ghi vào báo cáo M5. Đo lại bản bake đồng bộ (M4.1) để so sánh: biến môi trường NAV_SYNC=1.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/navigation/test_nav_bake.gd

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")
const TEST_DIR: String = "user://test_saves_nav/"
const SPIKE_LIMIT_MS: float = 33.0
const ARENA: Vector2 = Vector2(22.0, 35.0)

var _saves: SaveServiceScript
var _world: Node
var _player: Player
var _clock: GameClock
var _nav: TierNavigation

var _monitoring: bool = false
var _last_frame_us: int = 0
var _frame_max_ms: float = 0.0
var _frames_over: int = 0
var _frame_count: int = 0


func _run_tests() -> void:
	_saves = root.get_node("SaveService") as SaveServiceScript
	_saves.save_dir = TEST_DIR
	_saves.autosave_on_quit = false
	_clear_dir()
	process_frame.connect(_on_frame)
	await _test_map_entry()
	await _test_chop_five_trees()
	await _test_deploy_and_pack()
	await _test_old_navmesh_while_baking()
	await _test_load_at_night()
	_clear_dir()


# ---------------------------------------------------------------- đo frame

func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _monitoring and _last_frame_us > 0:
		var ms: float = (now - _last_frame_us) / 1000.0
		_frame_max_ms = maxf(_frame_max_ms, ms)
		_frame_count += 1
		if ms > SPIKE_LIMIT_MS:
			_frames_over += 1
	_last_frame_us = now


func _begin_measure() -> void:
	_frame_max_ms = 0.0
	_frames_over = 0
	_frame_count = 0
	_last_frame_us = Time.get_ticks_usec()
	_monitoring = true


func _end_measure(label: String) -> void:
	_monitoring = false
	print("MEASURE %s: max frame %.1f ms, %d frame > %.0f ms / %d frame, last bake %.1f ms (luồng chính %.1f ms, thread: %s)" % [label,
		_frame_max_ms, _frames_over, SPIKE_LIMIT_MS, _frame_count, _nav.last_bake_ms, _nav.last_main_thread_ms, _nav.last_bake_threaded])


## Chờ tới khi không còn bake nào đang chờ / đang chạy (tối đa `limit` frame).
func _settle(limit: int = 600) -> void:
	for i: int in limit:
		await process_frame
		if not _nav.is_baking():
			break
	await frames(3)


# ---------------------------------------------------------------- helpers

func _clear_dir() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)


func _open_world() -> void:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	_bind()


func _bind() -> void:
	_world = current_scene
	_player = _world.player
	_clock = _world.clock
	_nav = _world.tier_navigation
	# NAV_SYNC=1: bake đồng bộ trên luồng chính như M4.1 — chỉ để đo số liệu "trước khi sửa" (các ca spike sẽ FAIL).
	if OS.get_environment("NAV_SYNC") == "1":
		_nav.threaded = false


func _prepare() -> void:
	var enemy: Node2D = _world.get_node_or_null("EntityContainer/SimpleEnemy") as Node2D
	if enemy != null:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_world.enemy_spawner.enabled = false
	_clock.running = false
	for pickup: ItemPickup in (_world.pickup_layer as ItemPickupLayer).get_pickups():
		pickup.queue_free()


func _path_exists(tier: int = 0) -> bool:
	var map: RID = _world.get_world_2d().navigation_map
	var from: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	return NavigationServer2D.map_get_path(map, from, from + Vector2(60, 0), true, TierNavigation.layer_for_tier(tier)).size() >= 2


func _stand_at(target: Node2D, offset: Vector2 = Vector2(0, 20)) -> void:
	_player.global_position = target.global_position + offset
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(4)


func _press_e() -> void:
	await tap_action(&"interact")
	await process_frame


func _find(item_id: StringName) -> int:
	var bag: Inventory = _player.get_inventory()
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			return i
	return -1


## Rê chuột lên ô túi đồ chứa item rồi nhấn F (dựng lều / lửa trại). Túi đồ mở/đóng bằng I.
func _use_from_bag(item_id: StringName) -> void:
	var window: InventoryWindow = _world.inventory_window
	await tap_action(&"inventory_toggle")
	window.refresh_now()
	await process_frame
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * window.get_bag_view(_find(item_id)).get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	await tap_action(&"item_use")
	await process_frame
	await tap_action(&"inventory_toggle")


# ---------------------------------------------------------------- vào map

func _test_map_entry() -> void:
	await _open_world()
	_prepare()
	var started: int = Time.get_ticks_msec()
	_begin_measure()
	var ready_ms: int = -1
	for i: int in 600:
		await process_frame
		if _path_exists(0) and _path_exists(1):
			ready_ms = Time.get_ticks_msec() - started
			break
	_end_measure("map_entry")
	print("MEASURE map_entry_navmesh_ready: %d ms" % ready_ms)
	check("navmesh_ready_after_entry", ready_ms >= 0, "%d ms" % ready_ms)
	# Frame đầu sau khi vào map còn gồm nạp scene + _ready của mọi node; phần của bake trên luồng chính đo riêng.
	check("map_entry_bake_main_thread_part", _nav.last_bake_threaded and _nav.last_main_thread_ms < SPIKE_LIMIT_MS,
		"%.1f ms" % _nav.last_main_thread_ms)
	await _settle()


# ---------------------------------------------------------------- chặt 5 cây

func _test_chop_five_trees() -> void:
	var resources: ResourceNodeLayer = _world.resource_layer
	var database: ItemDatabase = _player.get_inventory().database
	_player.get_equipment().set_slot(&"weapon", ItemStack.new(&"stone_axe", 1))
	var trees: Array[ResourceNode] = []
	for id: String in ["glade_tree_1", "glade_tree_2", "glade_tree_3", "glade_tree_4"]:
		trees.append(resources.find_resource(id))
	var rebakes: Array[int] = [0]
	_nav.baked.connect(func() -> void: rebakes[0] += 1)
	_begin_measure()
	var chopped: int = 0
	for round_index: int in 2:
		for tree: ResourceNode in trees:
			if chopped >= 5:
				break
			await _stand_at(tree)
			for hit: int in tree.definition.toughness:
				await _press_e()
			# Người chơi chặt cây tiếp theo sau > rebake_delay → mỗi cây một lần bake.
			await frames(40)
			if tree.depleted:
				chopped += 1
		if chopped < 5:
			# Cho cây mọc lại (như tải một save chưa chặt) rồi chặt tiếp tới đủ 5 cây. Không tua đồng hồ 3 ngày: sẽ ngất lúc 2:00.
			resources.load_state({"version": 1, "nodes": {}})
			await frames(2)
	for i: int in 120:
		await process_frame
	await _settle()
	_end_measure("chop_5_trees")
	check("chopped_five_trees", chopped == 5, "%d" % chopped)
	check("chop_rebaked_each_tree", rebakes[0] >= 5, "%d lần bake" % rebakes[0])
	check("chop_no_frame_over_33ms", _frames_over == 0, "max %.1f ms, %d frame > 33 ms" % [_frame_max_ms, _frames_over])
	_player.get_equipment().set_slot(&"weapon", null)
	var _unused: ItemDefinition = database.get_item(&"stone_axe")


# ---------------------------------------------------------------- dựng / thu lều, lửa trại

func _test_deploy_and_pack() -> void:
	var bag: Inventory = _player.get_inventory()
	var layer: ItemPickupLayer = _world.pickup_layer
	bag.clear()
	bag.add(&"tent", 1)
	bag.add(&"campfire", 1)
	_player.global_position = IsoProjection.to_screen(ARENA.x, ARENA.y)
	_player.velocity = Vector2.ZERO
	await frames(4)
	_begin_measure()
	await _use_from_bag(&"tent")
	var tent: Tent = null
	var placed: bool = false
	for node: Node in layer.get_deployed():
		if node is Tent:
			tent = node as Tent
			placed = true
	await _settle()
	if tent != null:
		_world.choose_tent_action(tent, 1)
	await _settle()
	_end_measure("tent_deploy_pack")
	check("tent_cycle", placed and bag.has(&"tent"), (_world.get_node("UILayer/InteractionFeedback/Label") as Label).text)
	check("tent_no_frame_over_33ms", _frames_over == 0, "max %.1f ms" % _frame_max_ms)
	_begin_measure()
	await _use_from_bag(&"campfire")
	await _settle()
	var fire: Node2D = null
	var lit: bool = false
	for node: Node in layer.get_deployed():
		if node is Campfire:
			fire = node as Node2D
			lit = true
	if fire != null:
		fire.queue_free()
	await _settle()
	_end_measure("campfire_deploy_remove")
	check("campfire_cycle", lit)
	check("campfire_no_frame_over_33ms", _frames_over == 0, "max %.1f ms" % _frame_max_ms)


# ---------------------------------------------------------------- navmesh cũ dùng được trong lúc bake

func _test_old_navmesh_while_baking() -> void:
	var always_path: bool = true
	var seen_baking: bool = false
	_nav.request_rebake()
	for i: int in 600:
		await process_frame
		if _nav.is_baking():
			seen_baking = true
		if not _path_exists(0):
			always_path = false
		if seen_baking and not _nav.is_baking():
			break
	check("old_navmesh_used_while_baking", seen_baking and always_path, "baking %s, path %s" % [seen_baking, always_path])


# ---------------------------------------------------------------- tải save giữa đêm

func _test_load_at_night() -> void:
	await _settle()
	_clock.set_time(_clock.get_day(), 22 * 60)
	_player.global_position = IsoProjection.to_screen(ARENA.x, ARENA.y)
	await frames(3)
	var spawner: EnemySpawner = _world.enemy_spawner
	var ghouls: Array[Enemy] = spawner.debug_spawn(&"forest_ghoul")
	await frames(3)
	check("night_enemy_spawned", not ghouls.is_empty())
	check("saved_at_night", _saves.save_game(1))
	var loaded: Array[int] = []
	_saves.loaded.connect(func(slot: int) -> void: loaded.append(slot), CONNECT_ONE_SHOT)
	_saves.load_game(1)
	for i: int in 120:
		await process_frame
		if not loaded.is_empty():
			break
	_bind()
	_world.enemy_spawner.enabled = false
	var enemies: Array[Enemy] = _world.enemy_spawner.get_enemies()
	check("night_enemy_restored", enemies.size() == ghouls.size(), "%d" % enemies.size())
	if enemies.is_empty():
		return
	var enemy: Enemy = enemies[0]
	# Đứng trong bán kính phát hiện khi đứng yên của Thây ma (70 px mặt đất).
	_player.global_position = enemy.global_position + Vector2(50, 0)
	_player.velocity = Vector2.ZERO
	var start: Vector2 = enemy.global_position
	var moved_before_ready: float = 0.0
	var ready: bool = false
	for i: int in 600:
		await physics_frame
		if _path_exists(0):
			ready = true
			break
		moved_before_ready = maxf(moved_before_ready, enemy.global_position.distance_to(start))
	print("MEASURE load_at_night: navmesh sẵn sàng sau tải, quái dịch %.1f px trước khi có navmesh" % moved_before_ready)
	check("load_navmesh_ready", ready)
	check("enemy_waits_for_navmesh", moved_before_ready < 1.0, "%.1f px" % moved_before_ready)
	var before: Vector2 = enemy.global_position
	await frames(60)
	check("enemy_moves_with_navmesh", enemy.global_position.distance_to(before) > 4.0 and enemy.is_hunting(),
		"%.1f px, hunting %s" % [enemy.global_position.distance_to(before), enemy.is_hunting()])
