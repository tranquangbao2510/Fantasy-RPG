extends "res://tests/test_base.gd"
## Kiểm thử headless cho vật phẩm trên đất, rương và Save/Load (TASK M1) trên Environment Prototype (Glade):
## 1. Pickup: chạm thì nhặt (hút trong bán kính ngắn), thông báo "+N Tên"; túi đầy thì không nhặt + thông báo;
##    chỉ nhặt cùng tầng; đồ vứt ra không bị nhặt lại ngay tại chỗ.
## 2. Rương: tương tác (E) mở cửa sổ rương + túi, khóa đánh thường/kỹ năng; chuyển đồ; đi xa thì tự đóng.
## 3. Save: lưu → đổi scene (reset) → tải ra đúng vị trí, tầng, HP, túi, trang bị, class/level/mastery/kỹ năng,
##    rương, pickup đã nhặt không quay lại, đồ vứt ra còn nguyên. Ghi an toàn (.bak, không còn .tmp).
## 4. File hỏng → rơi về .bak; cả hai hỏng → báo lỗi, không crash; field thiếu → mặc định; schema mới hơn → từ chối;
##    migration được gọi cho schema cũ; HP 0 trong save → hồi đầy; tự lưu khi đóng cửa sổ; map không lưu được
##    (Combat Sandbox).
## Ghi save vào user://test_saves/ (xóa sạch đầu và cuối test).
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/save/test_save_load.gd
## Thoát mã 1 nếu có ca thất bại.

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const TEST_DIR: String = "user://test_saves/"
const S: float = IsoProjection.GROUND_SQUASH
const ARENA: Vector2 = Vector2(22.0, 35.0)
const CASTER: StringName = &"test_caster"
const FIGHTER: StringName = &"test_fighter"
## Script test được biên dịch trước khi Autoload đăng ký: không dùng tên SaveService trực tiếp.
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")

var _saves: SaveServiceScript
var _world: Node
var _player: Player
var _layer: ItemPickupLayer


func _run_tests() -> void:
	_saves = root.get_node("SaveService") as SaveServiceScript
	_saves.save_dir = TEST_DIR
	_saves.autosave_on_quit = false
	_clear_dir()
	await _open_world()
	await _test_pickups()
	await _test_chest()
	await _test_save_roundtrip()
	await _test_quick_keys()
	await _test_corrupted_files()
	await _test_missing_fields()
	_test_schema_versions()
	_test_autosave_on_quit()
	await _test_not_saveable_map()
	_clear_dir()


func _clear_dir() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)


func _open_world() -> void:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	_world = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_world)
	current_scene = _world
	_bind_world()
	await frames(4)
	_park_enemy()


func _bind_world() -> void:
	_world = current_scene
	_player = _world.get_node("EntityContainer/Player") as Player
	_layer = _world.get_node("EntityContainer/Items") as ItemPickupLayer


func _park_enemy() -> void:
	var enemy: Node2D = _world.get_node("EntityContainer/SimpleEnemy") as Node2D
	enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	(_world.get_node("EnemySpawner") as EnemySpawner).enabled = false


## Đặt Player tại điểm lưới trên tầng.
func _place(grid: Vector2, tier: int = 0) -> void:
	_player.global_position = IsoProjection.to_screen(grid.x, grid.y, IsoProjection.TIER_HEIGHT * tier)
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(tier)


func _pickup(name: String) -> ItemPickup:
	var node: Node = _layer.get_node_or_null(name)
	return node as ItemPickup if node != null and not node.is_queued_for_deletion() else null


# ---------------------------------------------------------------- 1. pickup

func _test_pickups() -> void:
	var bag: Inventory = _player.get_inventory()
	var toast: PickupToast = _world.get_node("UILayer/PickupToast") as PickupToast
	# Chạm (đứng cách ~20 px mặt đất): bị hút lại rồi nhặt.
	var wood: ItemPickup = _pickup("WoodPickup")
	_player.global_position = wood.global_position + GroundSpace.to_screen(Vector2(20, 0), S)
	await frames(20)
	check("pickup_on_touch", bag.count_of(&"wood") == 5 and _pickup("WoodPickup") == null and _layer.is_collected("glade_wood_1"),
		"wood=%d" % bag.count_of(&"wood"))
	check("pickup_toast", toast.get_lines().has("+5 Gỗ"), str(toast.get_lines()))
	# Ngoài bán kính hút: không nhặt.
	var stone: ItemPickup = _pickup("StonePickup")
	_player.global_position = stone.global_position + GroundSpace.to_screen(Vector2(_layer.magnet_radius + 12, 0), S)
	await frames(10)
	check("pickup_out_of_range", _pickup("StonePickup") != null and not bag.has(&"stone"))
	# Túi đầy: không nhặt, có thông báo.
	var blocked: Array[StringName] = []
	_layer.pickup_blocked.connect(func(id: StringName) -> void: blocked.append(id))
	var saved_bag: Dictionary = bag.to_dict()
	bag.clear()
	for i: int in bag.get_size():
		bag.add(&"test_sword", 1)
	_player.global_position = stone.global_position
	await frames(10)
	check("pickup_full_bag_rejected", _pickup("StonePickup") != null and not bag.has(&"stone") and blocked.has(&"stone"))
	check("pickup_full_bag_toast", toast.get_lines().any(func(line: String) -> bool: return line.contains("Túi đầy")), str(toast.get_lines()))
	bag.load_dict(saved_bag)
	await frames(10)
	check("pickup_after_space_freed", _pickup("StonePickup") == null and bag.count_of(&"stone") == 3)
	# Khác tầng: cùng điểm màn hình nhưng Player ở tầng 0 → không nhặt; lên tầng 1 → nhặt.
	var relic: ItemPickup = _pickup("RelicPickup")
	check("relic_on_tier_1", relic.get_tier() == 1, "tier=%d" % relic.get_tier())
	_player.global_position = relic.global_position
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(10)
	check("pickup_other_tier_ignored", _pickup("RelicPickup") != null)
	ElevationAgent.find_for(_player).set_tier(1)
	await frames(10)
	check("pickup_same_tier", _pickup("RelicPickup") == null and bag.has(&"ancient_relic"))
	# Đồ vứt ra: không nhặt lại ngay; đi ra xa rồi quay lại thì nhặt.
	_place(ARENA)
	await frames(2)
	bag.remove(&"stone", 3)
	var dropped: ItemPickup = _layer.spawn_drop(ItemStack.new(&"stone", 3), _player.global_position, 0)
	await frames(10)
	check("dropped_not_repicked_immediately", is_instance_valid(dropped) and not dropped.is_queued_for_deletion() and not bag.has(&"stone"))
	_player.global_position += GroundSpace.to_screen(Vector2(_layer.magnet_radius + 20, 0), S)
	await frames(3)
	_player.global_position = dropped.global_position
	await frames(10)
	check("dropped_picked_after_leaving", bag.count_of(&"stone") == 3)


# ---------------------------------------------------------------- 2. rương

func _test_chest() -> void:
	var chest: Chest = _world.get_node("EntityContainer/Chest") as Chest
	var window: InventoryWindow = _world.get_node("UILayer/InventoryWindow") as InventoryWindow
	var detector: InteractionDetector = _player.get_node("InteractionDetector") as InteractionDetector
	check("chest_starting_items", chest.get_inventory().count_of(&"wood") == 10 and chest.get_inventory().has(&"test_dagger"))
	_player.global_position = chest.global_position + Vector2(0, 14)
	await frames(4)
	check("chest_interact_opens_window", detector.try_interact() and window.is_open() and window.get_open_chest() == chest and chest.is_open())
	check("ui_blocks_combat", _player.is_combat_input_blocked())
	var moved: int = chest.get_inventory().quick_transfer(_find(chest.get_inventory(), &"wood"), _player.get_inventory())
	check("chest_transfer_to_bag", moved == 10 and _player.get_inventory().count_of(&"wood") == 15)
	await _test_window_actions(window, chest)
	_player.global_position += Vector2(InventoryWindow.CHEST_MAX_DISTANCE + 20, 0)
	await process_frame
	await process_frame
	check("chest_auto_close_when_far", not window.is_open() and not chest.is_open() and not _player.is_combat_input_blocked())
	window.open()
	check("inventory_toggle_blocks", window.is_open() and _player.is_combat_input_blocked())
	window.close()
	check("inventory_close_unblocks", not _player.is_combat_input_blocked())


## Thao tác cửa sổ như người chơi (gọi đúng hàm mà kéo thả / chuột phải / Shift+click / nhấp đúp gọi).
func _test_window_actions(window: InventoryWindow, chest: Chest) -> void:
	var bag: Inventory = _player.get_inventory()
	var weapons: WeaponEquipment = _player.get_node("WeaponEquipment") as WeaponEquipment
	var messages: Array[String] = []
	window.message.connect(func(text: String) -> void: messages.append(text))
	var dagger_slot: int = _find(chest.get_inventory(), &"test_dagger")
	window.quick_move(window.get_chest_view(dagger_slot))
	check("ui_shift_click_chest_to_bag", bag.has(&"test_dagger") and not chest.get_inventory().has(&"test_dagger"))
	var wood_slot: int = _find(bag, &"wood")
	window.split_slot(window.get_bag_view(wood_slot))
	check("ui_right_click_split", bag.get_stack(wood_slot).count == 8 and bag.count_of(&"wood") == 15)
	# Kéo dao găm vào ô vũ khí: Fighter không dùng dao găm → từ chối, có thông báo.
	var weapon_view: ItemSlotView = window.get_equipment_view(&"weapon")
	var dagger_view: ItemSlotView = window.get_bag_view(_find(bag, &"test_dagger"))
	check("ui_can_drop_weapon_slot", window.can_drop(dagger_view, weapon_view) and not window.can_drop(dagger_view, window.get_equipment_view(&"head")))
	window.drop_on_slot(dagger_view, weapon_view)
	check("ui_equip_rejected_by_class", weapons.get_weapon().weapon_id == &"test_sword" and bag.has(&"test_dagger") and not messages.is_empty(),
		str(messages))
	# Kéo kiếm từ ô vũ khí về ô túi trống → tháo; nhấp đúp → trang bị lại.
	var empty: int = bag.first_empty_slot()
	window.drop_on_slot(weapon_view, window.get_bag_view(empty))
	check("ui_unequip_by_drag", weapons.get_weapon() == null and bag.get_stack(empty).item_id == &"test_sword")
	window.primary_action(window.get_bag_view(empty))
	check("ui_double_click_equip", weapons.get_weapon().weapon_id == &"test_sword" and bag.is_slot_empty(empty))
	# Kéo ra ngoài cửa sổ → rơi xuống đất dưới chân, cùng tầng.
	var before: int = _layer.get_pickups().size()
	check("ui_drop_to_ground", window.drop_slot_to_ground(window.get_bag_view(wood_slot)) and bag.count_of(&"wood") == 7
		and _layer.get_pickups().size() == before + 1)
	var dropped: ItemPickup = _layer.get_pickups()[-1]
	check("ui_dropped_at_feet", dropped.item_id == &"wood" and dropped.count == 8 and dropped.global_position.distance_to(_player.global_position) < 10.0)
	dropped.queue_free()
	window.refresh_now()
	check("ui_slot_view_refresh", window.get_bag_view(wood_slot).get_slot_stack() == null and window.get_bag_view(_find(bag, &"wood")).tooltip_text.begins_with("Gỗ"))


func _find(bag: Inventory, item_id: StringName) -> int:
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			return i
	return -1


# ---------------------------------------------------------------- 3. vòng lưu → reset → tải

func _test_save_roundtrip() -> void:
	var bag: Inventory = _player.get_inventory()
	var equipment: EquipmentSlots = _player.get_equipment()
	var classes: ClassManager = _player.get_node("ClassManager") as ClassManager
	var level: CharacterLevel = _player.get_node("CharacterLevel") as CharacterLevel
	var chest: Chest = _world.get_node("EntityContainer/Chest") as Chest
	# Class/progression: mở Caster, cộng mastery, học + nâng kỹ năng, passive, chuyển sang Caster (phiên đổi class giả).
	classes.unlock_class(CASTER)
	classes.add_mastery_exp(FIGHTER, 45)
	classes.learn_skill(FIGHTER, &"test_self_heal")
	classes.level_up_skill(FIGHTER, &"test_arc_slash")
	var passive: StringName = classes.get_class_definition(FIGHTER).additional_passives[0].passive_id
	classes.unlock_passive(FIGHTER, passive)
	classes.equip_passive(FIGHTER, passive)
	level.add_exp(70)
	classes.open_switch_session(_player, 1000.0)
	classes.switch_class(CASTER)
	classes.close_switch_session()
	# Trang bị: dao găm (Caster dùng được) + mũ từ túi.
	bag.add(&"test_dagger", 1)
	bag.add(&"test_helmet", 1)
	equipment.equip_from_inventory(_find(bag, &"test_dagger"))
	equipment.equip_from_inventory(_find(bag, &"test_helmet"))
	bag.add(&"herb", 7)
	chest.get_inventory().add(&"raw_meat", 4)
	# Vứt 2 quả mọng ra đất ở chỗ khác.
	var drop_at: Vector2 = IsoProjection.to_screen(20.0, 33.0)
	_layer.spawn_drop(ItemStack.new(&"berry", 2), drop_at, 0)
	# Vị trí: trên quảng trường tầng 1; HP 63.
	_place(Vector2(12.5, 10.0), 1)
	var health: HealthComponent = _player.get_health()
	health.reset()
	health.apply_damage(health.max_health - 63)
	await frames(3)
	var expected_position: Vector2 = _player.global_position
	var expected: Dictionary = {
		"inventory": JSON.stringify(bag.to_dict()),
		"equipment": JSON.stringify(equipment.to_dict()),
		"classes": JSON.stringify(classes.to_dict()),
		"level": JSON.stringify(level.to_dict()),
		"chest": JSON.stringify(chest.get_inventory().to_dict()),
		"hp": health.current_health,
		"max_hp": health.max_health,
	}
	check("save_game", _saves.save_game(1), _saves.last_error)
	check("save_file_exists", FileAccess.file_exists(_saves.get_slot_path(1)) and not FileAccess.file_exists(_saves.get_slot_path(1) + ".tmp"))
	check("save_second_write_keeps_bak", _saves.save_game(1) and FileAccess.file_exists(_saves.get_backup_path(1)))
	var data: Dictionary = _saves.read_save(1)
	check("save_structure", int(data.get("schema_version")) == _saves.SCHEMA_VERSION and data.get("map_id") == "glade"
		and (data["global"] as Dictionary).has("player") and ((data["maps"] as Dictionary)["glade"] as Dictionary).has("chest:glade_chest")
		and not String(data.get("saved_at")).is_empty(), str(data.keys()))
	# Phá trạng thái trước khi tải (đảm bảo dữ liệu đến từ file).
	bag.clear()
	health.apply_damage(20)
	var loaded_slots: Array[int] = []
	_saves.loaded.connect(func(slot: int) -> void: loaded_slots.append(slot), CONNECT_ONE_SHOT)
	var old_world: Node = _world
	check("load_game_started", _saves.load_game(1), _saves.last_error)
	for i: int in 30:
		await process_frame
		if not loaded_slots.is_empty():
			break
	check("load_replaced_scene", loaded_slots == [1] and not is_instance_valid(old_world) and current_scene != null)
	_bind_world()
	await frames(2)
	var agent: ElevationAgent = ElevationAgent.find_for(_player)
	check("load_position", _player.global_position.distance_to(expected_position) < 0.1, "%s vs %s" % [_player.global_position, expected_position])
	check("load_tier", agent.get_tier() == 1 and _player.z_index == ElevationMap.tier_z(1), "tier=%d" % agent.get_tier())
	check("load_hp", _player.get_health().current_health == expected["hp"] and _player.get_health().max_health == expected["max_hp"],
		"%d/%d" % [_player.get_health().current_health, _player.get_health().max_health])
	check("load_inventory", JSON.stringify(_player.get_inventory().to_dict()) == expected["inventory"])
	check("load_equipment", JSON.stringify(_player.get_equipment().to_dict()) == expected["equipment"]
		and (_player.get_node("WeaponEquipment") as WeaponEquipment).get_weapon().weapon_id == &"test_dagger")
	var classes_after: ClassManager = _player.get_node("ClassManager") as ClassManager
	check("load_classes", JSON.stringify(classes_after.to_dict()) == expected["classes"], JSON.stringify(classes_after.to_dict()))
	check("load_active_class_and_loadout", classes_after.get_current_class_id() == CASTER
		and (_player.get_node("SkillLoadout") as SkillLoadout).get_skill(0) != null)
	check("load_level", JSON.stringify((_player.get_node("CharacterLevel") as CharacterLevel).to_dict()) == expected["level"])
	var chest_after: Chest = current_scene.get_node("EntityContainer/Chest") as Chest
	check("load_chest", JSON.stringify(chest_after.get_inventory().to_dict()) == expected["chest"])
	check("load_collected_pickups_gone", _pickup("WoodPickup") == null and _pickup("StonePickup") == null and _pickup("RelicPickup") == null
		and _pickup("HerbPickup") != null)
	var drops: Array[ItemPickup] = _layer.get_pickups().filter(func(p: ItemPickup) -> bool: return not p.is_placed())
	check("load_dropped_items", drops.size() == 1 and drops[0].item_id == &"berry" and drops[0].count == 2
		and drops[0].global_position.distance_to(drop_at) < 0.1 and drops[0].get_tier() == 0, str(drops))
	_park_enemy()


## F5/F9 đi qua input thật (Input → viewport → World._unhandled_input), không gọi thẳng SaveService.
## Lỗi cũ: World gọi get_viewport() sau khi load_game() đã gỡ scene → lỗi runtime, test_base sẽ bắt.
func _test_quick_keys() -> void:
	DirAccess.remove_absolute(_saves.get_slot_path(1))
	_place(Vector2(23.0, 34.0))
	await frames(2)
	var saved_position: Vector2 = _player.global_position
	await tap_action(&"quick_save")
	var feedback: Label = _world.get_node("UILayer/InteractionFeedback/Label") as Label
	check("f5_saves_via_input", FileAccess.file_exists(_saves.get_slot_path(1)) and feedback.text.begins_with("Đã lưu"), feedback.text)
	_place(ARENA)
	await frames(2)
	var old_world: Node = _world
	var loaded_slots: Array[int] = []
	_saves.loaded.connect(func(slot: int) -> void: loaded_slots.append(slot), CONNECT_ONE_SHOT)
	await tap_action(&"quick_load")
	for i: int in 30:
		if not loaded_slots.is_empty():
			break
		await process_frame
	check("f9_loads_via_input", loaded_slots == [1] and not is_instance_valid(old_world))
	_bind_world()
	await frames(2)
	check("f9_restores_position", _player.global_position.distance_to(saved_position) < 0.1,
		"%s vs %s" % [_player.global_position, saved_position])
	feedback = _world.get_node("UILayer/InteractionFeedback/Label") as Label
	check("f9_feedback", feedback.text.begins_with("Đã tải"), feedback.text)
	_park_enemy()


# ---------------------------------------------------------------- 4. file hỏng / thiếu field / version

func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_corrupted_files() -> void:
	expect_error("[SaveService] Không đọc được slot")
	var path: String = _saves.get_slot_path(1)
	_write(path, "{ \"schema_version\": 1, \"map_id\": \"glade\", ")
	var data: Dictionary = _saves.read_save(1)
	check("corrupt_main_falls_back_to_bak", not data.is_empty() and data.get("map_id") == "glade")
	_write(_saves.get_backup_path(1), "not json at all")
	var failures: Array[String] = []
	_saves.failed.connect(func(text: String) -> void: failures.append(text), CONNECT_ONE_SHOT)
	check("corrupt_both_load_fails_cleanly", not _saves.load_game(1) and failures.size() == 1 and current_scene == _world,
		_saves.last_error)
	_write(path, "[1, 2, 3]")
	check("non_object_json_rejected", _saves.read_save(1).is_empty())
	check("missing_slot_rejected", _saves.read_save(7).is_empty() and not _saves.has_save(7))


func _test_missing_fields() -> void:
	# Chỉ có map + vị trí Player: các field khác lấy mặc định (HP đầy, túi rỗng của scene, class khởi đầu...).
	var position: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	_write(_saves.get_slot_path(2), JSON.stringify({"map_id": "glade", "playtime": "abc",
		"global": {"player": {"position": [position.x, position.y], "health": 0, "classes": {"classes": "broken"}}}}))
	var data: Dictionary = _saves.read_save(2)
	check("missing_fields_defaults", data.get("schema_version") == _saves.SCHEMA_VERSION and data.get("playtime") == 0.0
		and data.get("maps") == {}, str(data))
	var loaded_slots: Array[int] = []
	_saves.loaded.connect(func(slot: int) -> void: loaded_slots.append(slot), CONNECT_ONE_SHOT)
	check("missing_fields_load_started", _saves.load_game(2))
	for i: int in 30:
		await process_frame
		if not loaded_slots.is_empty():
			break
	_bind_world()
	await frames(2)
	var classes: ClassManager = _player.get_node("ClassManager") as ClassManager
	check("missing_fields_player", _player.global_position.distance_to(position) < 0.1
		and _player.get_health().current_health == _player.get_health().max_health
		and classes.get_current_class_id() == FIGHTER and _player.get_inventory().first_empty_slot() == 0,
		"hp=%d class=%s" % [_player.get_health().current_health, classes.get_current_class_id()])
	check("missing_fields_map_defaults", _pickup("WoodPickup") != null
		and (current_scene.get_node("EntityContainer/Chest") as Chest).get_inventory().count_of(&"wood") == 10)
	_park_enemy()


func _test_schema_versions() -> void:
	_write(_saves.get_slot_path(3), JSON.stringify({"schema_version": _saves.SCHEMA_VERSION + 1, "map_id": "glade"}))
	check("newer_schema_rejected", _saves.read_save(3).is_empty() and _saves.last_error.contains("mới hơn"), _saves.last_error)
	_write(_saves.get_slot_path(4), JSON.stringify({"schema_version": 0, "map": "glade"}))
	check("missing_migration_rejected", _saves.read_save(4).is_empty())
	_saves.register_migration(0, func(old: Dictionary) -> Dictionary:
		old["map_id"] = old.get("map", "")
		old.erase("map")
		return old)
	var migrated: Dictionary = _saves.read_save(4)
	check("migration_applied", migrated.get("map_id") == "glade" and migrated.get("schema_version") == _saves.SCHEMA_VERSION, str(migrated))


func _test_autosave_on_quit() -> void:
	DirAccess.remove_absolute(_saves.get_slot_path(1))
	DirAccess.remove_absolute(_saves.get_backup_path(1))
	_saves.autosave_on_quit = true
	_saves.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_saves.autosave_on_quit = false
	var data: Dictionary = _saves.read_save(1)
	check("autosave_on_quit", not data.is_empty() and data.get("map_id") == "glade")


func _test_not_saveable_map() -> void:
	var sandbox: Node = (load("res://world/sandbox/combat_sandbox.tscn") as PackedScene).instantiate()
	current_scene.queue_free()
	root.add_child(sandbox)
	current_scene = sandbox
	await frames(2)
	check("sandbox_not_saveable", not _saves.can_save() and not _saves.save_game(9) and not FileAccess.file_exists(_saves.get_slot_path(9)))
	sandbox.queue_free()
	await process_frame
