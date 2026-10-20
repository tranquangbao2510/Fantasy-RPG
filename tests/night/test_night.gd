extends "res://tests/test_base.gd"
## Kiểm thử headless TASK M4 (quái đêm) trên Environment Prototype (Glade). Đi qua input thật khi có thể (E ngủ, C chế
## tạo + click, I + rê chuột + F ăn, F1/F2/F4/F10 phím debug, Shift/D khi đo bán kính phát hiện). Hành vi AI chạy thật
## theo physics frame; một số ca tăng detection_range của con quái đang thử để nó chắc chắn đuổi (ghi rõ tại chỗ).
## 1. Spawn: không trong vùng sáng / màn hình / sai tầng / nước; chỉ từ hoàng hôn; bầy đúng số lượng; đầy cap không sinh thêm.
## 2. Phát hiện: cầm đuốc × 1.5, đứng yên < đi < chạy.
## 3. Shade không vào vùng sáng, đuốc làm nó lùi; sói vây + lần lượt lao vào, máu < 25 % bỏ chạy; thây ma telegraph.
## 4. Đòn: Shade hút mana, giáp giảm sát thương đúng công thức, viền đỏ; HUD "Trời sắp tối…" / "Màn đêm buông xuống";
##    chỉ báo quái ngoài màn hình; không ngủ được khi quái gần.
## 5. Bình minh xóa sạch quái đêm (trong màn hình mờ dần, ngoài màn hình biến mất ngay). Phím debug.
## 6. Chế tạo giáo xương / áo da / đuốc tinh chất; bảng rơi đồ.
## 7. Save v4: lưu/tải giữa đêm (quái, HP, vị trí, bầy, buff, enemy đặt sẵn); tải ban ngày áp luật bình minh;
##    tải save v1, v2, v3. Combat Sandbox giữ nguyên.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/night/test_night.gd

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const SANDBOX_PATH: String = "res://world/sandbox/combat_sandbox.tscn"
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")
const TEST_DIR: String = "user://test_saves_night/"
const ARENA: Vector2 = Vector2(22.0, 35.0)
const S: float = 0.5

var _saves: SaveServiceScript
var _world: Node  # Không khai báo kiểu World: world.gd dùng tên Autoload (xem test_base.gd).
var _player: Player
var _clock: GameClock
var _spawner: EnemySpawner
var _layer: ItemPickupLayer
var _table: SpawnTable
var _alerts: int = 0


func _run_tests() -> void:
	_saves = root.get_node("SaveService") as SaveServiceScript
	_saves.save_dir = TEST_DIR
	_saves.autosave_on_quit = false
	_clear_dir()
	await _open_world()
	_test_data()
	await _test_spawn_rules()
	await _test_pack_and_cap()
	await _test_detection()
	await _test_shade_light()
	await _test_wolves()
	await _test_ghoul_and_hits()
	await _test_hud_warnings()
	await _test_threat_indicator()
	await _test_sleep_blocked()
	await _test_debug_keys()
	await _test_dawn()
	await _test_crafting()
	await _test_save_mid_night()
	await _test_load_day_applies_dawn()
	await _test_load_old_saves()
	await _test_sandbox_unchanged()
	_clear_dir()


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
	await frames(4)
	_prepare()


func _bind() -> void:
	_world = current_scene
	_player = _world.player
	_clock = _world.clock
	_spawner = _world.enemy_spawner
	_layer = _world.pickup_layer
	_table = _spawner.table
	_spawner.enemy_alerted.connect(func(_enemy: Enemy) -> void: _alerts += 1)


## Không fade khi ngủ, enemy đặt sẵn đứng yên ở xa, đồng hồ đứng yên, spawner chỉ sinh khi test gọi.
func _prepare() -> void:
	var settings: SleepSettings = _world.sleep_controller.settings
	settings.fade_time = 0.0
	settings.title_time = 0.0
	var enemy: Node2D = _simple_enemy()
	if enemy != null:
		enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_clock.running = false
	_spawner.enabled = false
	_spawner.rng.seed = 20261021
	for pickup: ItemPickup in _layer.get_pickups():
		pickup.queue_free()


func _simple_enemy() -> Node2D:
	return _world.get_node_or_null("EntityContainer/SimpleEnemy") as Node2D


func _place(grid: Vector2, tier: int = 0) -> void:
	_player.global_position = IsoProjection.to_screen(grid.x, grid.y, IsoProjection.TIER_HEIGHT * tier)
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(tier)
	(_world.camera as GameCamera).set_target(_player)
	await frames(3)


func _set_time(hour: int, minute: int = 0) -> void:
	_clock.set_time(_clock.get_day(), hour * 60 + minute)
	await frames(2)


func _clear_enemies() -> void:
	for enemy: Enemy in _spawner.get_enemies():
		enemy.queue_free()
	for node: Node in _world.get_tree().get_nodes_in_group(&"enemies"):
		if node != _simple_enemy() and is_instance_valid(node):
			node.queue_free()
	await frames(2)


## Điểm cách Player `distance` px mặt đất theo hướng `angle` (radian).
func _around(distance: float, angle: float = 0.0, from: Vector2 = Vector2.INF) -> Vector2:
	var origin: Vector2 = _player.global_position if from == Vector2.INF else from
	return origin + GroundSpace.to_screen(Vector2.from_angle(angle) * distance, S)


func _spawn(enemy_id: StringName, at: Vector2, tier: int = 0) -> Enemy:
	var enemies: Array[Enemy] = _spawner.spawn_group(_table.find_entry(enemy_id), [at], tier)
	return enemies[0] if not enemies.is_empty() else null


## Số phần tử còn hợp lệ (chưa bị giải phóng) — lambda có kiểu không nhận được object đã free.
func _count_valid(nodes: Array) -> int:
	var count: int = 0
	for i: int in nodes.size():
		if is_instance_valid(nodes[i]):
			count += 1
	return count


func _dist(a: Vector2, b: Vector2) -> float:
	return GroundSpace.length(a - b, S)


func _bag() -> Inventory:
	return _player.get_inventory()


func _find(bag: Inventory, item_id: StringName) -> int:
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			return i
	return -1


func _equip(item_id: StringName) -> bool:
	if _find(_bag(), item_id) < 0:
		_bag().add(item_id, 1)
	return _player.get_equipment().equip_from_inventory(_find(_bag(), item_id))


func _feedback() -> String:
	return (_world.get_node("UILayer/InteractionFeedback/Label") as Label).text


func _reload(slot: int, prepare: bool = true) -> void:
	var done: Array[int] = []
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	_saves.load_game(slot)
	for i: int in 40:
		if not done.is_empty():
			break
		await process_frame
	_bind()
	await frames(2)
	if prepare:
		_prepare()


func _click(control: Control) -> void:
	var at: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame


## Mở cửa sổ chế tạo bằng C, click nút công thức, đóng bằng C.
func _craft_via_ui(recipe_id: StringName) -> bool:
	var window: CraftingWindow = _world.crafting_window
	if not window.is_open():
		await tap_action(&"craft_toggle")
	await process_frame
	var button: Button = window.get_craft_button(recipe_id)
	if button == null or button.disabled:
		await tap_action(&"craft_toggle")
		return false
	await _click(button)
	await tap_action(&"craft_toggle")
	return true


## Rê chuột lên ô túi đồ chứa item rồi nhấn F (dùng / trang bị). Cửa sổ túi đồ mở/đóng bằng I.
func _use_from_bag(item_id: StringName) -> bool:
	var window: InventoryWindow = _world.inventory_window
	await tap_action(&"inventory_toggle")
	window.refresh_now()
	await process_frame
	var slot: int = _find(_bag(), item_id)
	if slot < 0:
		await tap_action(&"inventory_toggle")
		return false
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * window.get_bag_view(slot).get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	await tap_action(&"item_use")
	await process_frame
	await tap_action(&"inventory_toggle")
	return true


# ---------------------------------------------------------------- 0. dữ liệu

func _test_data() -> void:
	var database: ItemDatabase = _bag().database
	check("spawn_table_valid", _table.get_validation_errors().is_empty() and _table.map_id == &"glade"
		and _table.entries.size() == 3, str(_table.get_validation_errors()))
	var wolf_entry: SpawnEntry = _table.find_entry(&"night_wolf")
	check("spawn_table_wolf_pack", wolf_entry.pack_min == 2 and wolf_entry.pack_max == 3 and wolf_entry.is_night_only())
	for entry: SpawnEntry in _table.entries:
		var enemy: Enemy = entry.scene.instantiate() as Enemy
		var dropper: LootDropper = enemy.get_node("LootDropper") as LootDropper
		check("enemy_scene_%s" % entry.enemy_id, enemy.enemy_id == entry.enemy_id and enemy.detection != null
			and dropper.table.get_validation_errors(database).is_empty())
		enemy.free()
	var ids: Array[StringName] = []
	for path: String in ["shade_loot", "night_wolf_loot", "forest_ghoul_loot"]:
		var loot: LootTable = load("res://entities/enemies/loot/%s.tres" % path) as LootTable
		var line: Array[StringName] = []
		for entry: LootEntry in loot.entries:
			line.append(entry.item_id)
		ids.append(StringName(",".join(line)))
	check("loot_tables", ids == [&"shadow_essence", &"raw_meat,hide", &"bone,shadow_essence"], str(ids))
	check("armor_formula", DamageInfo.mitigate(28, 30) == 22 and DamageInfo.mitigate(5, 30) == 4
		and DamageInfo.mitigate(1, 200) == 1 and DamageInfo.mitigate(10, 0) == 10)
	var armor: ItemDefinition = database.get_item(&"leather_armor")
	check("leather_armor_item", armor.armor == 30 and armor.equip_slot == &"body" and armor.is_valid())
	var torch: ItemDefinition = database.get_item(&"torch")
	var essence: ItemDefinition = database.get_item(&"essence_torch")
	check("essence_torch_brighter_longer", essence.light_radius > torch.light_radius and essence.burn_minutes > torch.burn_minutes
		and essence.is_valid())


# ---------------------------------------------------------------- 1. luật spawn

func _test_spawn_rules() -> void:
	await _place(ARENA)
	await _set_time(12)
	var day_spawns: int = 0
	for i: int in 10:
		day_spawns += _spawner.try_spawn().size()
	check("no_night_spawn_by_day", day_spawns == 0 and not _spawner.is_night_period())
	await _set_time(17)
	check("night_period_from_dusk", _spawner.is_night_period())
	var dusk: Array[Enemy] = []
	for i: int in 10:
		dusk.append_array(_spawner.try_spawn())
		if not dusk.is_empty():
			break
	check("spawn_starts_at_dusk", not dusk.is_empty())
	await _clear_enemies()
	await _set_time(22)
	var view: Rect2 = _spawner.get_view_rect()
	check("view_rect_follows_camera", view.has_point(_player.global_position) and view.size.x < 700.0, str(view))
	check("reason_on_screen", _spawner.get_spawn_block_reason(_player.global_position + Vector2(60, 0), 0) == "trong màn hình")
	var near_off_screen: Vector2 = _player.global_position + Vector2(view.size.x * 0.5 + _table.screen_margin + 6.0, 0)
	check("reason_too_close", _spawner.get_spawn_block_reason(near_off_screen, 0) == "quá gần người chơi",
		_spawner.get_spawn_block_reason(near_off_screen, 0))
	var plateau: Vector2 = IsoProjection.to_screen(12.0, 14.0, IsoProjection.TIER_HEIGHT)
	check("reason_wrong_tier", _spawner.get_spawn_block_reason(plateau, 0, false).contains("bằng phẳng")
		and not _spawner.get_spawn_block_reason(plateau, 1, false).contains("bằng phẳng"), _spawner.get_spawn_block_reason(plateau, 0, false))
	var water: Vector2 = IsoProjection.to_screen(13.0, 24.2)
	check("reason_water", _spawner.get_spawn_block_reason(water, 0, false).contains("nước"), _spawner.get_spawn_block_reason(water, 0, false))
	var rune: Node2D = _world.get_node("EntityContainer/Props/RuneStone") as Node2D
	check("reason_rune_safe_zone", _spawner.get_spawn_block_reason(rune.global_position + Vector2(30, 0), 1, false) == "trong vùng sáng an toàn")
	var bed: Node2D = _world.get_node("EntityContainer/Bed") as Node2D
	check("reason_bed_lamp_safe_zone", _spawner.get_spawn_block_reason(bed.global_position + Vector2(20, 6), 0, false) == "trong vùng sáng an toàn")
	# Lửa trại đang cháy nằm trên vòng spawn → không quái nào sinh trong vùng sáng của nó.
	var fire: Campfire = _layer.spawn_deployed(_bag().database.get_item(&"campfire"), _around(470.0, 0.0), 0) as Campfire
	await frames(2)
	check("reason_campfire_safe_zone", _spawner.get_spawn_block_reason(fire.global_position + Vector2(40, 0), 0, false) == "trong vùng sáng an toàn")
	var records: Array[Dictionary] = []
	var record: Callable = func(enemy: Enemy) -> void:
		records.append({"position": enemy.global_position, "tier": ElevationAgent.find_for(enemy).initial_tier,
			"view": _spawner.get_view_rect(), "player": _player.global_position})
	_spawner.enemy_spawned.connect(record)
	var loose: SpawnTable = _table.duplicate(true)
	loose.max_total = 200
	for entry: SpawnEntry in loose.entries:
		entry.max_on_map = 100
	_spawner.table = loose
	for i: int in 60:
		_spawner.try_spawn()
	_spawner.table = _table
	_spawner.enemy_spawned.disconnect(record)
	var elevation: ElevationMap = _world.get_tree().get_first_node_in_group(ElevationMap.GROUP) as ElevationMap
	var terrain: TerrainLogic = _world.find_children("*", "TerrainLogic", true, false)[0] as TerrainLogic
	var bad: Array[String] = []
	for r: Dictionary in records:
		var at: Vector2 = r["position"]
		if (r["view"] as Rect2).grow(_table.screen_margin).has_point(at):
			bad.append("on_screen %s" % at)
		if _dist(at, r["player"]) < _table.min_player_distance - 0.5:
			bad.append("too_close %s" % at)
		if fire.get_light().contains(at, 0.0):
			bad.append("in_light %s" % at)
		if elevation.get_tier_at(at) != int(r["tier"]):
			bad.append("tier %s" % at)
		if PlacementCheck.BLOCKED_TERRAIN.has(terrain.get_terrain_at(at)) or terrain.get_terrain_at(at) == &"":
			bad.append("terrain %s %s" % [at, terrain.get_terrain_at(at)])
	check("bulk_spawns_follow_rules", records.size() >= 20 and bad.is_empty(), "%d spawn, lỗi: %s" % [records.size(), bad])
	fire.queue_free()
	await _clear_enemies()


# ---------------------------------------------------------------- 1b. bầy + cap

func _test_pack_and_cap() -> void:
	await _place(ARENA)
	await _set_time(22)
	var wolves_only: SpawnTable = _table.duplicate(true)
	wolves_only.entries = [_table.find_entry(&"night_wolf").duplicate(true)]
	_spawner.table = wolves_only
	var pack: Array[Enemy] = []
	for i: int in 20:
		pack = _spawner.try_spawn()
		if not pack.is_empty():
			break
	var same_pack: bool = not pack.is_empty() and pack[0].pack != null and pack.all(func(e: Enemy) -> bool: return e.pack == pack[0].pack)
	check("wolf_pack_size", pack.size() >= 2 and pack.size() <= 3 and same_pack and pack[0].pack.get_members().size() == pack.size(),
		"%d" % pack.size())
	for i: int in 40:
		_spawner.try_spawn()
	var wolves: int = int(_spawner.count_by_type().get(&"night_wolf", 0))
	var blocked: bool = _spawner.try_spawn().is_empty()
	check("wolf_cap_respected", wolves <= 6 and wolves >= 5 and blocked, "%d" % wolves)
	await _clear_enemies()
	# Bảng đầy đủ: tổng ≤ max_total, từng loại ≤ max_on_map; đầy thì không sinh thêm.
	_spawner.table = _table
	for i: int in 80:
		_spawner.try_spawn()
	var counts: Dictionary = _spawner.count_by_type()
	var total: int = _spawner.get_enemies().size()
	var per_type_ok: bool = true
	for entry: SpawnEntry in _table.entries:
		per_type_ok = per_type_ok and int(counts.get(entry.enemy_id, 0)) <= entry.max_on_map
	check("table_caps_respected", total <= _table.max_total and total >= _table.max_total - 1 and per_type_ok, "%d %s" % [total, counts])
	var capped: SpawnTable = _table.duplicate(true)
	capped.max_total = total
	_spawner.table = capped
	var extra: int = 0
	for i: int in 10:
		extra += _spawner.try_spawn().size()
	check("full_cap_no_spawn", extra == 0 and _spawner.get_enemies().size() == total)
	_spawner.table = _table
	await _clear_enemies()


# ---------------------------------------------------------------- 2. phát hiện

func _test_detection() -> void:
	await _place(ARENA)
	await _set_time(22)
	var shade: Enemy = _spawn(&"shade", _around(400.0))
	await frames(2)
	var base: float = shade.detection_range
	var still: float = shade.get_detection_radius()
	check("detect_still_smaller", is_equal_approx(still, base * 0.5), "%.1f" % still)
	check("equip_torch", _equip(&"torch") and _player.is_holding_light())
	var with_torch: float = shade.get_detection_radius()
	check("torch_detection_x1_5", is_equal_approx(with_torch / still, 1.5), "%.2f" % (with_torch / still))
	press_action(&"move_right")
	await frames(3)
	var walking: float = shade.get_detection_radius()
	press_action(&"sprint")
	await frames(3)
	var sprinting: float = shade.get_detection_radius()
	press_action(&"sprint", false)
	press_action(&"move_right", false)
	await frames(2)
	check("detect_walk_vs_run", with_torch < walking and walking < sprinting and is_equal_approx(sprinting, base * 1.5),
		"%.1f %.1f %.1f" % [with_torch, walking, sprinting])
	_player.get_equipment().unequip_to_inventory(&"offhand")
	check("no_light_after_unequip", not _player.is_holding_light())
	await _clear_enemies()


# ---------------------------------------------------------------- 3. Shade sợ sáng

func _test_shade_light() -> void:
	await _place(ARENA)
	await _set_time(22)
	var fire: Campfire = _layer.spawn_deployed(_bag().database.get_item(&"campfire"), _player.global_position + Vector2(0, -24), 0) as Campfire
	await frames(2)
	var radius: float = fire.get_light().radius
	var shade: Enemy = _spawn(&"shade", _around(radius + 50.0, 0.3, fire.global_position))
	shade.detection_range = 2000.0  # chắc chắn đuổi Player đứng trong vùng sáng
	var nearest: float = INF
	var states: Dictionary = {}
	for i: int in 420:
		await physics_frame
		nearest = minf(nearest, _dist(shade.global_position, fire.global_position))
		states[shade.get_state()] = true
	check("shade_never_enters_light", nearest >= radius - 1.0, "gần nhất %.1f / bán kính %.0f" % [nearest, radius])
	check("shade_hovers_at_edge", nearest < radius + shade.light_margin + 30.0 and states.has(Enemy.State.CHASE),
		"%.1f %s" % [nearest, states.keys()])
	check("shade_alert_signal", _alerts > 0)
	# Lửa trại vừa nhóm cạnh Shade: nó đi ra khỏi vùng sáng.
	shade.global_position = fire.global_position + GroundSpace.to_screen(Vector2(radius * 0.8, 0), S)
	await frames(40)
	check("shade_leaves_light", _dist(shade.global_position, fire.global_position) > radius * 0.8 + 10.0)
	fire.queue_free()
	await _clear_enemies()
	# Đuốc: Shade ở gần thì lùi lại; không cầm đuốc thì nó áp sát.
	await _place(ARENA)
	_equip(&"torch")
	shade = _spawn(&"shade", _around(60.0))
	shade.detection_range = 2000.0
	var torch_states: Dictionary = {}
	for i: int in 60:
		await physics_frame
		torch_states[shade.get_state()] = true
	var after_torch: float = _dist(shade.global_position, _player.global_position)
	check("torch_repels_shade", after_torch > 80.0 and torch_states.has(Enemy.State.AVOID_LIGHT), "%.1f %s" % [after_torch, torch_states.keys()])
	_player.get_equipment().unequip_to_inventory(&"offhand")
	await _clear_enemies()
	shade = _spawn(&"shade", _around(60.0))
	shade.detection_range = 2000.0
	await frames(70)
	check("no_torch_shade_approaches", _dist(shade.global_position, _player.global_position) < 45.0,
		"%.1f" % _dist(shade.global_position, _player.global_position))
	await _clear_enemies()


# ---------------------------------------------------------------- 3b. sói: vây, lần lượt, bỏ chạy

func _test_wolves() -> void:
	await _place(ARENA)
	await _set_time(22)
	# Player 130 HP chịu được vài cú cắn trong ca này; hồi đầy ở cuối.
	var entry: SpawnEntry = _table.find_entry(&"night_wolf")
	var pack: Array[Enemy] = _spawner.spawn_group(entry, [_around(150.0, 0.0), _around(150.0, 2.0), _around(150.0, 4.0)], 0)
	for wolf: Enemy in pack:
		wolf.detection_range = 2000.0
	var max_attackers: int = 0
	var circled: bool = false
	var attackers: Dictionary = {}
	for i: int in 480:
		await physics_frame
		var holding: int = 0
		for wolf: Enemy in pack:
			if wolf.pack.get_attacker() == wolf:
				holding += 1
				attackers[wolf.get_instance_id()] = true
			circled = circled or wolf.get_state() == Enemy.State.CIRCLE
		max_attackers = maxi(max_attackers, holding)
	check("wolves_circle", circled)
	check("wolves_take_turns", max_attackers == 1 and attackers.size() >= 2, "%d %d" % [max_attackers, attackers.size()])
	var brave: Enemy = pack[0]
	brave.get_health().apply_damage(22)  # 8/30 ≥ 25 %
	var coward: Enemy = pack[1]
	coward.get_health().apply_damage(23)  # 7/30 < 25 %
	var before: float = _dist(coward.global_position, _player.global_position)
	await frames(40)
	check("wolf_flees_below_25", coward.is_fleeing() and coward.get_state() == Enemy.State.FLEE
		and _dist(coward.global_position, _player.global_position) > before + 20.0, "%.0f → %.0f" % [before, _dist(coward.global_position, _player.global_position)])
	check("wolf_above_25_keeps_fighting", not brave.is_fleeing())
	_player.get_health().reset()
	await _clear_enemies()


# ---------------------------------------------------------------- 4. thây ma telegraph, đòn, giáp, viền đỏ, hút mana

func _test_ghoul_and_hits() -> void:
	await _place(ARENA)
	await _set_time(22)
	var health: HealthComponent = _player.get_health()
	health.reset()
	var vignette: HitVignette = _world.hit_vignette
	var ghoul: Enemy = _spawn(&"forest_ghoul", _around(45.0))
	ghoul.detection_range = 2000.0
	var hits: Array[int] = []
	health.damaged.connect(func(amount: int) -> void: hits.append(amount))
	var telegraphed: bool = false
	for i: int in 400:
		await physics_frame
		if ghoul.attack.get_phase() == AttackComponent.Phase.WINDUP:
			telegraphed = telegraphed or (ghoul.attack.get_node("Visual") as CanvasItem).visible
		if not hits.is_empty():
			break
	check("ghoul_telegraph", telegraphed and ghoul.attack.windup >= 0.6)
	check("ghoul_hits_hard", hits.size() == 1 and hits[0] == 28, str(hits))
	check("hit_vignette", vignette.get_alpha() > 0.0)
	await seconds(1.0)
	check("vignette_fades", vignette.get_alpha() < 0.05, "%.2f" % vignette.get_alpha())
	check("equip_leather_armor", _equip(&"leather_armor") and (_player.get_node("Hurtbox") as Hurtbox).armor == 30)
	for i: int in 400:
		await physics_frame
		if hits.size() >= 2:
			break
	check("armor_reduces_damage", hits.size() >= 2 and hits[1] == DamageInfo.mitigate(28, 30), str(hits))
	_player.get_equipment().unequip_to_inventory(&"body")
	await _clear_enemies()
	health.reset()
	# Shade hút mana khi trúng.
	var mana: ManaComponent = _player.get_mana()
	mana.refill()
	var shade: Enemy = _spawn(&"shade", _around(30.0))
	shade.detection_range = 2000.0
	var before_hits: int = hits.size()
	for i: int in 400:
		await physics_frame
		if hits.size() > before_hits:
			break
	check("shade_drains_mana", hits.size() > before_hits and hits.back() == 5 and mana.current <= mana.get_max() - 14.0,
		"%s %.1f" % [hits, mana.current])
	await _clear_enemies()
	health.reset()
	mana.refill()


# ---------------------------------------------------------------- 4b. HUD

func _test_hud_warnings() -> void:
	var banner: NightBanner = _world.night_banner
	var started: Array[bool] = []
	(_world.day_night as DayNightLighting).night_started.connect(func() -> void: started.append(true), CONNECT_ONE_SHOT)
	await _set_time(17, 20)
	banner.last_text = ""
	_clock.advance(15.0)
	await frames(2)
	check("hud_dusk_warning", banner.last_text == "Trời sắp tối…" and banner.get_text() == "Trời sắp tối…", banner.last_text)
	_clock.advance(100.0)
	await frames(2)
	check("hud_night_falls", banner.last_text == "Màn đêm buông xuống" and started == [true], banner.last_text)
	banner.last_text = ""
	await _set_time(17, 45)
	check("hud_no_warning_on_set_time", banner.last_text == "")


func _test_threat_indicator() -> void:
	await _place(ARENA)
	await _set_time(22)
	var indicator: ThreatIndicator = _world.threat_indicator
	var wolf: Enemy = _spawn(&"night_wolf", _around(520.0, PI))
	wolf.move_speed = 0.0
	wolf.wander_radius = 0.0
	await frames(5)
	check("no_marker_when_not_hunting", indicator.get_markers().is_empty())
	wolf.detection_range = 2000.0
	await frames(5)
	var markers: Array[Dictionary] = indicator.get_markers()
	var viewport_rect: Rect2 = indicator.get_viewport_rect()
	check("marker_for_offscreen_hunter", markers.size() == 1 and viewport_rect.has_point(markers[0]["position"])
		and Vector2(markers[0]["position"]).x < viewport_rect.size.x * 0.25, str(markers))
	await _clear_enemies()


# ---------------------------------------------------------------- 5. không ngủ khi quái gần

func _test_sleep_blocked() -> void:
	var bed: Bed = _world.get_node("EntityContainer/Bed") as Bed
	await _set_time(22)
	_player.global_position = bed.global_position + Vector2(0, 14)
	ElevationAgent.find_for(_player).set_tier(0)
	(_world.camera as GameCamera).set_target(_player)
	await frames(4)
	var ghoul: Enemy = _spawn(&"forest_ghoul", _around(150.0, PI * 0.5))
	ghoul.move_speed = 0.0
	ghoul.wander_radius = 0.0
	ghoul.detection_range = 10.0
	await frames(2)
	await tap_action(&"interact")
	await frames(2)
	check("cannot_sleep_enemy_near", _feedback() == "Có quái gần đây." and _clock.format_time() == "22:00", _feedback())
	# Quái ở xa nhưng đang đuổi → vẫn không ngủ được.
	ghoul.global_position = _around(600.0, PI * 0.5)
	ghoul.detection_range = 2000.0
	await frames(3)
	check("cannot_sleep_enemy_chasing", ghoul.is_hunting() and _world.sleep_controller.get_sleep_block_reason() == "Có quái gần đây.")
	await _clear_enemies()
	var slept: Array[int] = []
	_world.sleep_controller.slept.connect(func(day: int) -> void: slept.append(day), CONNECT_ONE_SHOT)
	await tap_action(&"interact")
	for i: int in 20:
		if not slept.is_empty():
			break
		await process_frame
	check("sleep_ok_when_clear", not slept.is_empty() and _clock.format_time() == "06:00")


# ---------------------------------------------------------------- 5b. phím debug

func _test_debug_keys() -> void:
	await _place(ARENA)
	await _set_time(22)
	await tap_action(&"debug_spawn_shade")
	await tap_action(&"debug_spawn_wolves")
	await tap_action(&"debug_spawn_ghoul")
	await frames(2)
	var counts: Dictionary = _spawner.count_by_type()
	check("debug_spawn_keys", int(counts.get(&"shade", 0)) == 1 and int(counts.get(&"night_wolf", 0)) >= 2
		and int(counts.get(&"forest_ghoul", 0)) == 1, str(counts))
	await tap_action(&"debug_enemy_radius")
	var view: EnemyDebugView = _spawner.get_enemies()[0].get_node("DebugView") as EnemyDebugView
	check("debug_radius_on", EnemyDebugView.shown and view.visible)
	await tap_action(&"debug_enemy_radius")
	check("debug_radius_off", not EnemyDebugView.shown and not view.visible)
	await _clear_enemies()


# ---------------------------------------------------------------- 5c. bình minh

func _test_dawn() -> void:
	await _place(ARENA)
	await _set_time(4, 50)
	var visible_ones: Array[Enemy] = [_spawn(&"shade", _around(60.0, 0.0)), _spawn(&"forest_ghoul", _around(80.0, PI))]
	var hidden_ones: Array[Enemy] = [_spawn(&"shade", _around(520.0, 0.0)), _spawn(&"forest_ghoul", _around(560.0, PI))]
	for enemy: Enemy in visible_ones + hidden_ones:
		enemy.wander_radius = 0.0
		enemy.detection_range = 1.0
	await frames(2)
	var cleared: Array[int] = []
	_spawner.dawn_cleared.connect(func(count: int) -> void: cleared.append(count), CONNECT_ONE_SHOT)
	_clock.advance(15.0)
	await frames(10)
	check("dawn_clears_spawner", _spawner.get_enemies().is_empty() and cleared == [4], str(cleared))
	check("dawn_offscreen_vanish", _count_valid(hidden_ones) == 0)
	check("dawn_onscreen_fade", visible_ones.all(func(e: Enemy) -> bool: return is_instance_valid(e) and e.is_fading() and e.modulate.a < 1.0))
	await seconds(_table.dawn_fade_time + 0.3)
	check("dawn_all_gone", _count_valid(visible_ones) == 0)
	check("dawn_keeps_placed_enemy", _simple_enemy() != null and is_instance_valid(_simple_enemy()))


# ---------------------------------------------------------------- 6. chế tạo

func _test_crafting() -> void:
	await _set_time(12)
	var bag: Inventory = _bag()
	bag.clear()
	bag.add(&"branch", 1)
	bag.add(&"fiber", 1)
	bag.add(&"shadow_essence", 1)
	await _place(ARENA)
	check("craft_essence_torch_by_hand", await _craft_via_ui(&"essence_torch") and bag.has(&"essence_torch") and not bag.has(&"shadow_essence"))
	var workbench: Node2D = _world.get_node("EntityContainer/Workbench") as Node2D
	_player.global_position = workbench.global_position + Vector2(0, 26)
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(4)
	bag.add(&"bone", 4)
	bag.add(&"branch", 2)
	bag.add(&"fiber", 5)
	bag.add(&"hide", 4)
	check("craft_bone_spear_workbench", await _craft_via_ui(&"bone_spear") and bag.has(&"bone_spear") and not bag.has(&"bone"))
	check("craft_leather_armor_workbench", await _craft_via_ui(&"leather_armor") and bag.has(&"leather_armor") and not bag.has(&"hide"))
	check("equip_bone_spear_fighter", _equip(&"bone_spear") and _player.get_equipment().get_item(&"weapon").id == &"bone_spear")
	await _place(ARENA)
	bag.add(&"bone", 4)
	bag.add(&"branch", 2)
	bag.add(&"fiber", 2)
	check("craft_spear_needs_workbench", not await _craft_via_ui(&"bone_spear") and bag.count_of(&"bone") == 4)
	bag.clear()


# ---------------------------------------------------------------- 7. save v4

func _test_save_mid_night() -> void:
	await _place(ARENA)
	await _set_time(23)
	var shade: Enemy = _spawn(&"shade", _around(200.0, 0.0))
	var wolves: Array[Enemy] = _spawner.spawn_group(_table.find_entry(&"night_wolf"), [_around(220.0, 2.0), _around(240.0, 2.2)], 0)
	var ghoul: Enemy = _spawn(&"forest_ghoul", _around(260.0, 4.0))
	for enemy: Enemy in [shade, ghoul] + wolves:
		enemy.detection_range = 1.0
		enemy.wander_radius = 0.0
	ghoul.get_health().apply_damage(50)
	var placed: Enemy = _simple_enemy() as Enemy
	placed.get_health().apply_damage(15)
	placed.global_position = IsoProjection.to_screen(6.0, 31.0)
	# Buff "Ấm bụng" bằng input thật (I + rê chuột + F).
	_player.get_hunger().load_value(50.0)
	_bag().add(&"grilled_meat", 1)
	check("eat_for_buff", await _use_from_bag(&"grilled_meat") and _player.get_buffs().has_buff(&"warm_meal"))
	var buff_ids: Array = _player.get_buffs().to_list()
	await frames(2)
	check("save_mid_night", _saves.save_game(2))
	var data: Dictionary = _saves.read_save(2)
	var saved: Array = data["maps"]["glade"]["enemies"]["enemies"]
	var saved_buffs: Array = data["global"]["player"]["survival"]["buffs"]
	check("save_v4_structure", int(data["schema_version"]) == 4 and saved.size() == 4 and not saved_buffs.is_empty()
		and data["maps"]["glade"].has("enemy:glade_simple_enemy"), JSON.stringify(saved))
	var expect: Dictionary = {}
	for state: Dictionary in saved:
		expect[state["type"]] = expect.get(state["type"], []) + [state]
	await _reload(2, false)
	var loaded: Array[Enemy] = _spawner.get_enemies()
	var types: Dictionary = _spawner.count_by_type()
	check("load_enemy_types", loaded.size() == 4 and types.get(&"shade") == 1 and types.get(&"night_wolf") == 2
		and types.get(&"forest_ghoul") == 1, str(types))
	var positions_ok: bool = true
	var hp_ok: bool = true
	for enemy: Enemy in loaded:
		var candidates: Array = expect.get(String(enemy.enemy_id), [])
		var match_found: bool = false
		for state: Dictionary in candidates:
			var at: Vector2 = Vector2(state["position"][0], state["position"][1])
			if at.distance_to(enemy.global_position) < 4.0:
				match_found = true
				hp_ok = hp_ok and enemy.get_health().current_health == int(state["hp"])
		positions_ok = positions_ok and match_found
	check("load_enemy_positions_hp", positions_ok and hp_ok)
	var ghoul_loaded: Array[Enemy] = loaded.filter(func(e: Enemy) -> bool: return e.enemy_id == &"forest_ghoul")
	check("load_ghoul_damaged", ghoul_loaded.size() == 1 and ghoul_loaded[0].get_health().current_health == 70)
	var wolf_loaded: Array[Enemy] = loaded.filter(func(e: Enemy) -> bool: return e.enemy_id == &"night_wolf")
	check("load_wolf_pack_kept", wolf_loaded.size() == 2 and wolf_loaded[0].pack != null and wolf_loaded[0].pack == wolf_loaded[1].pack)
	var placed_after: Enemy = _simple_enemy() as Enemy
	check("load_placed_enemy_hp_position", placed_after != null and placed_after.get_health().current_health == 25
		and placed_after.global_position.distance_to(IsoProjection.to_screen(6.0, 31.0)) < 2.0)
	var buffs_after: Array = _player.get_buffs().to_list()
	check("load_buff_time_left", buffs_after.size() == buff_ids.size() and not buffs_after.is_empty()
		and absf(float(buffs_after[0]["left"]) - float(saved_buffs[0]["left"])) < 1.0, "%s / %s" % [buffs_after, saved_buffs])
	check("load_clock_night", _clock.get_hour() == 23 and _spawner.is_night_period())
	_prepare()


func _test_load_day_applies_dawn() -> void:
	var data: Dictionary = _saves.read_save(2)
	data["global"]["clock"]["minute"] = 12 * 60
	_saves.write_save(3, data)
	await _reload(3, false)
	await frames(3)
	check("load_day_clears_night_enemies", _spawner.get_enemies().is_empty() and _clock.get_hour() == 12)
	check("load_day_keeps_placed_enemy", _simple_enemy() != null and (_simple_enemy() as Enemy).get_health().current_health == 25)
	_prepare()


func _test_load_old_saves() -> void:
	var at: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	# Save v3 (M3): có node tài nguyên, lửa trại; chưa có quái / buff.
	var v3: Dictionary = {"schema_version": 3, "saved_at": "2026-10-20 18:00:00", "playtime": 400.0, "map_id": "glade",
		"global": {"clock": {"version": 1, "day": 2, "minute": 1300.0},
			"player": {"position": [at.x, at.y + 20.0], "tier": 0, "health": 70,
				"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "fiber", "count": 3}]},
				"survival": {"mana": 40.0, "stamina": 50.0, "hunger": 60.0, "respawn": {}}}},
		"maps": {"glade": {
			"world_items": {"version": 3, "collected": [], "dropped": [], "death_bags": [],
				"deployed": [{"item_id": "campfire", "id": "campfire_old", "position": [at.x + 60.0, at.y], "tier": 0,
					"state": {"fuel": 90.0, "lit": true}}]},
			"resource_nodes": {"version": 1, "nodes": {"glade_tree_1": {"depleted": true, "respawn_day": 5, "durability": 0}}}}}}
	_write(4, v3)
	await _reload(4)
	var migrated: Dictionary = _saves.read_save(4)
	check("load_v3_ok", _clock.get_day() == 2 and _bag().count_of(&"fiber") == 3 and _player.get_health().current_health == 70
		and _layer.get_deployed().size() == 1 and _spawner.get_enemies().is_empty() and _player.get_buffs().to_list().is_empty())
	check("migration_v3_v4", migrated["maps"]["glade"]["enemies"] == {"version": 1, "enemies": []}
		and migrated["global"]["player"]["survival"]["buffs"] == [] and int(migrated["schema_version"]) == 4)
	check("load_v3_resave_v4", _saves.save_game(4) and int(_saves.read_save(4)["schema_version"]) == 4)
	# Save v2 (M2).
	var v2: Dictionary = {"schema_version": 2, "saved_at": "2026-10-20 17:00:00", "playtime": 300.0, "map_id": "glade",
		"global": {"clock": {"version": 1, "day": 3, "minute": 600.0},
			"player": {"position": [at.x, at.y + 20.0], "tier": 0, "health": 80,
				"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "bread", "count": 2}]},
				"survival": {"mana": 50.0, "stamina": 60.0, "hunger": 70.0, "respawn": {}}}},
		"maps": {"glade": {"world_items": {"version": 2, "collected": [], "dropped": [], "death_bags": [], "deployed": []}}}}
	_write(5, v2)
	await _reload(5)
	check("load_v2_ok", _clock.get_day() == 3 and _bag().count_of(&"bread") == 2 and _player.get_health().current_health == 80
		and _spawner.get_enemies().is_empty())
	# Save v1 (M1).
	var v1: Dictionary = {"schema_version": 1, "saved_at": "2026-10-20 00:17:07", "playtime": 12.0, "map_id": "glade",
		"global": {"player": {"position": [at.x, at.y], "tier": 0, "health": 90,
			"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "wood", "count": 5}]}}},
		"maps": {"glade": {"world_items": {"version": 1, "collected": [], "dropped": []}}}}
	_write(6, v1)
	await _reload(6)
	check("load_v1_ok", _bag().count_of(&"wood") == 5 and _clock.get_day() == 1 and _player.get_health().current_health == 90
		and _spawner.get_enemies().is_empty() and _simple_enemy() != null)


func _write(slot: int, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(_saves.get_slot_path(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


# ---------------------------------------------------------------- Combat Sandbox giữ nguyên

func _test_sandbox_unchanged() -> void:
	current_scene.queue_free()
	await process_frame
	var sandbox: Node = (load(SANDBOX_PATH) as PackedScene).instantiate()
	root.add_child(sandbox)
	current_scene = sandbox
	await frames(6)
	check("sandbox_no_spawner", sandbox.find_children("*", "EnemySpawner", true, false).is_empty() and sandbox.get("enemy_spawner") == null)
	var old_style: bool = true
	var count: int = 0
	for node: Node in sandbox.get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or not sandbox.is_ancestor_of(enemy):
			continue
		count += 1
		old_style = old_style and enemy.detection == null and enemy.wander_radius == 0.0 and not enemy.light_averse \
			and enemy.flee_health_ratio == 0.0 and enemy.pack == null and enemy.alert_time == 0.0
	check("sandbox_enemies_old_behavior", count > 0 and old_style, "%d" % count)
