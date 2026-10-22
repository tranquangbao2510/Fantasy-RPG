extends "res://tests/test_base.gd"
## Kiểm thử headless TASK M5 (trồng trọt) trên Glade, qua input thật khi có thể (E cày / gieo / tưới / múc nước / thu /
## ngủ, C + click chế tạo, I + rê chuột + F dùng / trang bị / dựng, F6 / F11 debug, chuột trỏ ô). Đặt Player bằng dịch
## chuyển, đặt giờ bằng GameClock.set_time (như test M2–M4).
## 1. Vòng lặp đầy đủ: chế cuốc đất → cày → gieo lúa → múc nước → tưới mỗi ngày → ngủ qua đêm → thu → xay bột (cối đá
##    trong nhà) → nướng bánh (lửa trại) → ăn.
## 2. Luật: không tưới không lớn; khô 3 ngày chết; mọng thu nhiều lần đúng chu kỳ; đất bỏ trống 3 ngày về cỏ; không cày
##    ngoài vùng ruộng; túi đầy → nông sản rơi cạnh người chơi; cối đá phải đặt trong nhà; quái đêm không phá cây.
## 3. Cây lớn theo ngày khi ngủ / ngất / ở map khác (thời gian trôi ngoài Glade → tải lại bù đủ ngày).
## 4. Save / load giữa chừng mọi giai đoạn (cả 3 loại cây, ướt / khô, ngày khô, ngày bỏ trống, nước trong bình).
## 5. Save v5 + migration v4 → v5; tải save v1 → v4.
## 6. Phím debug F6 (cây ở ô dưới con trỏ +1 giai đoạn), F11 (tưới hết ruộng).
## 7. Hiệu năng: ruộng 24 ô đầy cây ban đêm + 15 quái (thời gian xử lý mỗi frame; FPS có render đo riêng — báo cáo M5).
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/farming/test_farming.gd

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const TEST_MAP_PATH: String = "res://world/world.tscn"
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")
const TEST_DIR: String = "user://test_saves_farming/"
const ARENA: Vector2 = Vector2(22.0, 35.0)

var _saves: SaveServiceScript
var _world: Node  # Không khai báo kiểu World: world.gd dùng tên Autoload (xem test_base.gd).
var _player: Player
var _clock: GameClock
var _layer: ItemPickupLayer
var _farms: FarmLayer
var _field: FarmField
var _window: CraftingWindow


func _run_tests() -> void:
	_saves = root.get_node("SaveService") as SaveServiceScript
	_saves.save_dir = TEST_DIR
	_clear_dir()
	await _open_world()
	await _test_data()
	await _test_full_loop()
	await _test_no_water_and_death()
	await _test_fallow_and_zone()
	await _test_multi_harvest()
	await _test_full_bag_and_rules()
	await _test_debug_keys()
	await _test_sleep_faint_and_away()
	await _test_save_every_stage()
	await _test_migrations_and_old_saves()
	await _test_performance()
	_clear_dir()


# ---------------------------------------------------------------- helpers

func _clear_dir() -> void:
	clear_dir(TEST_DIR)


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
	_layer = _world.pickup_layer
	_farms = _world.farm_layer
	_field = _farms.find_field("glade_home") if _farms != null else null
	_window = _world.crafting_window


## Không fade khi ngủ, không tự lưu khi ngủ, enemy đặt sẵn đứng yên ở xa, không spawn quái, đồng hồ đứng yên, bỏ vật phẩm
## đặt sẵn (không lẫn vào túi khi đi ngang).
func _prepare() -> void:
	var settings: SleepSettings = _world.sleep_controller.settings
	settings.fade_time = 0.0
	settings.title_time = 0.0
	_world.sleep_controller.autosave = false
	# Tua đồng hồ qua 2:00 trong test không được gây ngất (ngất tua thêm tới 6:00 hôm sau); ca ngất bật lại.
	settings.faint_hour = 99
	var enemy: Node2D = _world.get_node_or_null("EntityContainer/SimpleEnemy") as Node2D
	if enemy != null:
		enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_world.enemy_spawner.enabled = false
	_clock.running = false
	for pickup: ItemPickup in _layer.get_pickups():
		pickup.queue_free()


func _bag() -> Inventory:
	return _player.get_inventory()


func _equipment() -> EquipmentSlots:
	return _player.get_equipment()


func _plot(c: int, r: int) -> FarmPlot:
	return _field.get_plot(Vector2i(c, r))


func _find(bag: Inventory, item_id: StringName) -> int:
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			return i
	return -1


func _feedback() -> String:
	return (_world.get_node("UILayer/InteractionFeedback/Label") as Label).text


func _prompt() -> String:
	return (_world.get_node("UILayer/InteractionPrompt") as InteractionPrompt).get_text()


func _place_at(at: Vector2) -> void:
	_player.global_position = at
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(4)


## Đứng ngay trên tâm ô ruộng (ô đó là mục tiêu tương tác gần nhất).
func _stand_on(plot: FarmPlot) -> void:
	await _place_at(plot.global_position)


func _press_e() -> void:
	await tap_action(&"interact")
	await process_frame


## Tua đồng hồ (luật cây theo ngày); nạp lại đói + HP để tua nhiều ngày không chết đói.
func _skip(minutes: float) -> void:
	_player.get_hunger().load_value(100.0)
	_clock.advance(minutes)
	_player.get_hunger().load_value(100.0)
	_player.get_health().reset()


## Đặt giờ rồi chờ các node nghe đồng hồ cập nhật.
func _set_time(day: int, hour: int, minute: int = 0) -> void:
	_clock.set_time(day, hour * 60 + minute)
	await frames(2)


## Đứng cạnh giường nhà, nhấn E (ngủ qua đêm tới 6:00). Đặt giờ 20:00 trước nếu đang ban ngày.
func _sleep_in_bed() -> void:
	if _clock.get_hour() < 18 and _clock.get_hour() >= 6:
		await _set_time(_clock.get_day(), 20)
	var bed: Node2D = _world.get_node("EntityContainer/Bed") as Node2D
	await _place_at(bed.global_position + Vector2(0, 14))
	await _press_e()
	for i: int in 60:
		await process_frame
		if not _world.sleep_controller.is_busy():
			break
	await frames(2)


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


func _mouse_to(window_point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = window_point
	motion.global_position = window_point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame


## Rê chuột lên ô túi đồ chứa item rồi nhấn F (hành động chính: dùng / trang bị / dựng). Túi đồ mở/đóng bằng I.
func _use_from_bag(item_id: StringName) -> bool:
	var window: InventoryWindow = _world.inventory_window
	await tap_action(&"inventory_toggle")
	window.refresh_now()
	await process_frame
	var slot: int = _find(_bag(), item_id)
	if slot < 0:
		await tap_action(&"inventory_toggle")
		return false
	await _mouse_to(root.get_final_transform() * window.get_bag_view(slot).get_global_rect().get_center())
	await tap_action(&"item_use")
	await process_frame
	await tap_action(&"inventory_toggle")
	return true


## Mở cửa sổ chế tạo bằng C (nếu chưa mở), click nút của công thức, đóng bằng C.
func _craft_via_ui(recipe_id: StringName) -> bool:
	if not _window.is_open():
		await tap_action(&"craft_toggle")
	await process_frame
	var button: Button = _window.get_craft_button(recipe_id)
	if button == null or button.disabled:
		await tap_action(&"craft_toggle")
		return false
	await _click(button)
	await tap_action(&"craft_toggle")
	return true


func _hurtbox() -> Hurtbox:
	return _player.get_node("Hurtbox") as Hurtbox


func _water_left() -> int:
	var item: ItemDefinition = _equipment().get_item(&"weapon")
	return item.water_of(_equipment().get_stack(&"weapon")) if item != null else -1


## Đặt trạng thái ô (thiết lập cho ca kiểm thử luật — không phải đường input).
func _set_plot(plot: FarmPlot, state: Dictionary) -> void:
	plot.load_plot_state(state, _farms.crop_book)


func _reset_field() -> void:
	for plot: FarmPlot in _farms.get_plots():
		plot.load_plot_state({}, _farms.crop_book)
	_farms.last_tick = _farms._current_tick()


func _reload(slot: int) -> void:
	var done: Array[int] = []
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	_saves.load_game(slot)
	for i: int in 60:
		if not done.is_empty():
			break
		await process_frame
	_bind()
	await frames(2)
	_prepare()


func _write(slot: int, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(_saves.get_slot_path(slot).get_base_dir())
	var file: FileAccess = FileAccess.open(_saves.get_slot_path(slot), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _read_raw(slot: int) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(FileAccess.get_file_as_string(_saves.get_slot_path(slot)))
	return json.data


# ---------------------------------------------------------------- 0. dữ liệu, vùng ruộng

func _test_data() -> void:
	var database: ItemDatabase = _bag().database
	check("crop_book_valid", _farms.crop_book.get_validation_errors(database).is_empty(), str(_farms.crop_book.get_validation_errors(database)))
	check("three_crops", _farms.crop_book.crops.size() == 3 and _farms.crop_book.find_by_seed(&"wheat_seed").id == &"wheat"
		and _farms.crop_book.find_by_seed(&"seed_potato").id == &"potato" and _farms.crop_book.find_by_seed(&"berry").multi_harvest)
	var book: RecipeBook = _world.recipe_book
	check("recipe_book_valid", book.get_validation_errors(database).is_empty(), str(book.get_validation_errors(database)))
	var bad: Array[String] = []
	for id: StringName in [&"stone_hoe", &"watering_can", &"stone_mill", &"wheat_seed", &"wheat", &"flour", &"seed_potato", &"potato", &"roasted_potato"]:
		var item: ItemDefinition = database.get_item(id)
		if item == null or not item.is_valid() or item.icon == null:
			bad.append(String(id))
	check("new_items_valid", bad.is_empty(), str(bad))
	check("hoe_not_pickaxe", database.get_item(&"stone_hoe").tool_type == &"hoe" and database.get_item(&"stone_pickaxe").tool_type == &"pickaxe"
		and database.get_item(&"stone_hoe").max_durability > 0)
	check("field_6x4_near_home", _field != null and _farms.get_plots().size() == 24 and _field.columns == 6 and _field.rows == 4
		and _plot(0, 0).global_position.distance_to((_world.get_node("EntityContainer/Bed") as Node2D).global_position) < 160.0)
	check("mill_recipe_station", book.get_recipe(&"flour").station == RecipeDefinition.Station.MILL
		and book.get_recipe(&"bread").station == RecipeDefinition.Station.CAMPFIRE
		and book.get_recipe(&"roasted_potato").station == RecipeDefinition.Station.CAMPFIRE
		and book.get_recipe(&"stone_hoe").station == RecipeDefinition.Station.WORKBENCH
		and book.get_recipe(&"stone_mill").station == RecipeDefinition.Station.WORKBENCH)
	check("bread_hunger_kept", is_equal_approx(database.get_item(&"bread").consumable.hunger, 30.0))
	check("potato_raw_vs_roasted", database.get_item(&"potato").consumable.hunger > 0.0 and database.get_item(&"potato").consumable.health >= 0
		and database.get_item(&"roasted_potato").consumable.hunger > database.get_item(&"potato").consumable.hunger)
	# Hạt từ bụi cỏ (tỉ lệ thấp), củ giống ở node mới + bụi mọng.
	var grass: ResourceNodeDefinition = load("res://features/gathering/data/grass.tres") as ResourceNodeDefinition
	var seed_chance: float = 0.0
	for entry: LootEntry in grass.yield_table.entries:
		if entry.item_id == &"wheat_seed":
			seed_chance = entry.chance
	check("grass_drops_wheat_seed_low", seed_chance > 0.0 and seed_chance <= 0.25, "%.2f" % seed_chance)
	var potatoes: Array[ResourceNode] = []
	for node: ResourceNode in (_world.resource_layer as ResourceNodeLayer).get_nodes():
		if node.definition.id == &"wild_potato":
			potatoes.append(node)
	check("wild_potato_nodes", potatoes.size() >= 1)
	if not potatoes.is_empty():
		_bag().clear()
		await _place_at(potatoes[0].global_position + Vector2(0, 16))
		await _press_e()
		check("wild_potato_gives_seed_potato", _bag().count_of(&"seed_potato") >= 1, _feedback())


# ---------------------------------------------------------------- 1. vòng lặp đầy đủ

func _test_full_loop() -> void:
	var bag: Inventory = _bag()
	bag.clear()
	_equipment().set_slot(&"weapon", null)
	bag.add(&"branch", 2)
	bag.add(&"stone", 8)
	bag.add(&"fiber", 4)
	bag.add(&"wood", 5)
	bag.add(&"wheat_seed", 1)
	bag.add(&"campfire", 1)
	await _set_time(1, 7)
	# Chế cuốc đất, bình tưới, cối đá ở bàn chế tạo (C + click).
	var bench: Node2D = _world.get_node("EntityContainer/Workbench") as Node2D
	await _place_at(bench.global_position + Vector2(0, 20))
	check("craft_hoe", await _craft_via_ui(&"stone_hoe") and bag.has(&"stone_hoe"), _feedback())
	check("craft_watering_can", await _craft_via_ui(&"watering_can") and bag.has(&"watering_can"), _feedback())
	check("craft_stone_mill", await _craft_via_ui(&"stone_mill") and bag.has(&"stone_mill"), _feedback())
	# Trang bị cuốc (F), cày.
	await _use_from_bag(&"stone_hoe")
	check("hoe_equipped", _equipment().get_tool() != null and _equipment().get_tool().id == &"stone_hoe")
	var plot: FarmPlot = _plot(2, 1)
	await _stand_on(plot)
	check("prompt_till", _prompt().contains("Cày"), _prompt())
	await _press_e()
	check("tilled", plot.tilled and not plot.has_crop(), _feedback())
	check("hoe_wear", _equipment().get_tool().durability_of(_equipment().get_stack(&"weapon")) == 39)
	# Gieo lúa (một loại hạt → gieo luôn).
	check("prompt_plant", _prompt().contains("Gieo Hạt lúa mì"), _prompt())
	await _press_e()
	check("planted_wheat", plot.has_crop() and plot.crop.id == &"wheat" and not bag.has(&"wheat_seed"), _feedback())
	# Cầm bình tưới (cuốc về túi), múc nước ở suối.
	await _use_from_bag(&"watering_can")
	check("can_equipped_empty", _equipment().get_tool().id == &"watering_can" and _water_left() == 0 and bag.has(&"stone_hoe"))
	await _stand_on(plot)
	check("prompt_can_empty", _prompt().contains("hết nước"), _prompt())
	var source: Node2D = _world.get_node("EntityContainer/WaterSource2") as Node2D
	await _place_at(source.global_position + Vector2(0, 18))
	check("prompt_fill", _prompt().contains("Múc nước"), _prompt())
	await _press_e()
	check("can_filled", _water_left() == 10, _feedback())
	# Tưới mỗi ngày + ngủ qua đêm → lớn 1 ngày mỗi đêm; 3 ngày thì chín.
	var ages: Array[int] = []
	for night: int in 3:
		await _stand_on(plot)
		await _press_e()
		if night == 0:
			check("watered_wet", plot.is_wet() and _water_left() == 9, _feedback())
		await _sleep_in_bed()
		ages.append(plot.age)
	check("grows_each_night", ages == [1, 2, 3] and _clock.get_hour() == 6 and _clock.get_day() == 4, "%s ngày %d" % [ages, _clock.get_day()])
	check("wheat_mature", plot.is_mature() and plot.get_stage() == 3)
	check("dry_next_morning", not plot.is_wet())
	# Thu hoạch (E, đang cầm bình tưới — cây chín ưu tiên thu).
	await _stand_on(plot)
	check("prompt_harvest", _prompt().contains("Thu hoạch"), _prompt())
	await _press_e()
	var wheat: int = bag.count_of(&"wheat")
	check("harvest_wheat", wheat >= 2 and wheat <= 3 and bag.count_of(&"wheat_seed") >= 1 and bag.count_of(&"wheat_seed") <= 2
		and not plot.has_crop() and plot.tilled, "%d lúa, %d hạt — %s" % [wheat, bag.count_of(&"wheat_seed"), _feedback()])
	# Cối đá: đặt xa nhà bị từ chối; đặt trong nhà (cạnh giường) được.
	await _place_at(IsoProjection.to_screen(ARENA.x, ARENA.y))
	await _use_from_bag(&"stone_mill")
	check("mill_outside_home_rejected", bag.has(&"stone_mill") and _feedback().contains("trong nhà"), _feedback())
	var mill: StoneMill = null
	for spot: Vector2 in [Vector2(30.0, 38.0), Vector2(29.5, 37.6), Vector2(31.0, 38.3), Vector2(27.0, 37.5)]:
		await _place_at(IsoProjection.to_screen(spot.x, spot.y))
		await _use_from_bag(&"stone_mill")
		for node: Node in _layer.get_deployed():
			if node is StoneMill:
				mill = node as StoneMill
		if mill != null:
			break
	check("mill_placed_in_home", mill != null and not bag.has(&"stone_mill"), _feedback())
	if mill == null:
		return
	# Xay bột ở cối đá (E → cửa sổ chế tạo có công thức cối đá). TASK M6: 3 lúa → 1 bột; vụ một ô cho 2–3 lúa → bù cho đủ 3.
	if wheat < 3:
		bag.add(&"wheat", 3 - wheat)
		wheat = 3
	await _place_at(mill.global_position + Vector2(0, 20))
	check("prompt_mill", _prompt().contains("Xay bột"), _prompt())
	await _press_e()
	var flour_button: Button = _window.get_craft_button(&"flour")
	check("mill_opens_window", _window.is_open() and flour_button != null and not flour_button.disabled and flour_button.text == "Xay")
	if flour_button != null:
		await _click(flour_button)
	await tap_action(&"craft_toggle")
	check("milled_flour", bag.count_of(&"flour") == 1 and bag.count_of(&"wheat") == wheat - 3, _feedback())
	# Nướng bánh ở lửa trại.
	await _place_at(IsoProjection.to_screen(ARENA.x, ARENA.y))
	Input.action_press(&"move_down")
	await frames(3)
	Input.action_release(&"move_down")
	await frames(2)
	await _use_from_bag(&"campfire")
	var fire: Campfire = null
	for node: Node in _layer.get_deployed():
		if node is Campfire:
			fire = node as Campfire
	check("campfire_for_bread", fire != null, _feedback())
	if fire == null:
		return
	await _place_at(fire.global_position + Vector2(0, 22))
	await _press_e()
	var bake: Button = _window.get_craft_button(&"bread")
	check("bread_in_cook_window", _window.is_open() and bake != null and not bake.disabled, str(_window.get_recipe_ids()))
	if bake != null:
		await _click(bake)
	await tap_action(&"ui_cancel")
	check("baked_bread", bag.count_of(&"bread") == 1 and not bag.has(&"flour"), _feedback())
	# Ăn bánh mì: +30 đói như M2.
	var hunger: HungerComponent = _player.get_hunger()
	hunger.load_value(40.0)
	await _use_from_bag(&"bread")
	check("eat_bread", absf(hunger.value - 70.0) < 0.5 and not bag.has(&"bread"), "%.1f %s bread %d" % [hunger.value, _feedback(), bag.count_of(&"bread")])
	hunger.load_value(100.0)
	fire.queue_free()
	await frames(2)


# ---------------------------------------------------------------- 2. không tưới, khô chết

func _test_no_water_and_death() -> void:
	_reset_field()
	await _set_time(_clock.get_day(), 8)
	var start_day: int = _clock.get_day()
	var plot: FarmPlot = _plot(0, 0)
	_set_plot(plot, {"state": "planted", "crop": "wheat", "age": 1})
	_skip(_clock.minutes_until(6 * 60))
	await frames(2)
	check("no_water_no_growth", plot.age == 1 and plot.dry_days == 1 and plot.has_crop(), "age %d dry %d" % [plot.age, plot.dry_days])
	_skip(GameClock.MINUTES_PER_DAY)
	await frames(2)
	check("dry_two_days_alive", plot.has_crop() and plot.dry_days == 2)
	# Tưới một lần → hết khô, lớn.
	plot.water_now()
	_skip(GameClock.MINUTES_PER_DAY)
	await frames(2)
	check("water_resets_dry", plot.age == 2 and plot.dry_days == 0, "age %d dry %d" % [plot.age, plot.dry_days])
	for i: int in 3:
		_skip(GameClock.MINUTES_PER_DAY)
		await frames(1)
	check("dry_three_days_dies", not plot.has_crop() and plot.tilled and plot.fallow_days == 0,
		"crop %s tilled %s ngày %d→%d" % [plot.has_crop(), plot.tilled, start_day, _clock.get_day()])


# ---------------------------------------------------------------- 3. bỏ trống về cỏ, ngoài vùng ruộng

func _test_fallow_and_zone() -> void:
	_reset_field()
	var plot: FarmPlot = _plot(5, 3)
	_equipment().set_slot(&"weapon", ItemStack.new(&"stone_hoe", 1))
	await _stand_on(plot)
	await _press_e()
	check("till_for_fallow", plot.tilled and not plot.has_crop())
	await _set_time(_clock.get_day(), 10)
	_skip(_clock.minutes_until(6 * 60))
	await frames(1)
	_skip(GameClock.MINUTES_PER_DAY)
	await frames(1)
	check("fallow_two_days_still_tilled", plot.tilled and plot.fallow_days == 2)
	_skip(GameClock.MINUTES_PER_DAY)
	await frames(1)
	check("fallow_three_days_grass", not plot.tilled and plot.fallow_days == 0)
	# Ngoài vùng ruộng: E với cuốc không cày gì; điểm ngoài vùng không có ô.
	_reset_field()
	var outside: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	await _place_at(outside)
	await _press_e()
	var tilled: int = 0
	for p: FarmPlot in _farms.get_plots():
		if p.tilled:
			tilled += 1
	check("cannot_till_outside", tilled == 0 and _farms.plot_at(outside) == null and not _prompt().contains("Cày"), _prompt())
	var corner: Vector2 = _field.to_global(Vector2(-4, 0))
	check("plot_at_edges", _farms.plot_at(_plot(0, 0).global_position) == _plot(0, 0) and _farms.plot_at(corner) == null
		and _farms.plot_at(_plot(5, 3).global_position) == _plot(5, 3))


# ---------------------------------------------------------------- 4. mọng thu nhiều lần

func _test_multi_harvest() -> void:
	_reset_field()
	var bag: Inventory = _bag()
	bag.clear()
	bag.add(&"berry", 1)
	await _set_time(_clock.get_day(), 8)
	var plot: FarmPlot = _plot(1, 2)
	_set_plot(plot, {"state": "tilled"})
	_equipment().set_slot(&"weapon", null)
	await _stand_on(plot)
	await _press_e()
	check("plant_berry", plot.has_crop() and plot.crop.id == &"berry_bush" and not bag.has(&"berry"), _feedback())
	var crop: CropDefinition = plot.crop
	var days: int = 0
	while not plot.is_mature() and days < 20:
		await tap_action(&"debug_farm_water")
		_skip(_clock.minutes_until(6 * 60))
		await frames(1)
		days += 1
	check("berry_first_fruit_days", days == crop.get_mature_age(), "%d ngày (cần %d)" % [days, crop.get_mature_age()])
	await _stand_on(plot)
	await _press_e()
	var first: int = bag.count_of(&"berry")
	check("berry_harvest_1", first >= crop.yield_min and first <= crop.yield_max and plot.has_crop() and not plot.is_mature()
		and plot.age == crop.get_mature_age() - crop.regrow_days, "%d quả, age %d" % [first, plot.age])
	# Chưa tưới đủ N ngày thì chưa có quả lại.
	await tap_action(&"debug_farm_water")
	_skip(_clock.minutes_until(6 * 60))
	await frames(1)
	check("berry_not_ready_after_1_day", not plot.is_mature())
	days = 1
	while not plot.is_mature() and days < 10:
		await tap_action(&"debug_farm_water")
		_skip(_clock.minutes_until(6 * 60))
		await frames(1)
		days += 1
	check("berry_regrow_n_days", days == crop.regrow_days, "%d ngày (N = %d)" % [days, crop.regrow_days])
	await _stand_on(plot)
	await _press_e()
	check("berry_harvest_2", bag.count_of(&"berry") >= first + crop.yield_min and plot.has_crop(), "%d mature %s prompt %s fb %s" % [bag.count_of(&"berry"), plot.is_mature(), _prompt(), _feedback()])


# ---------------------------------------------------------------- 5. túi đầy, nhiều loại hạt, quái không phá cây

func _test_full_bag_and_rules() -> void:
	_reset_field()
	var bag: Inventory = _bag()
	bag.clear()
	var plot: FarmPlot = _plot(3, 2)
	_set_plot(plot, {"state": "planted", "crop": "potato", "age": 6})
	for i: int in bag.get_size():
		bag.add_to_slot(i, ItemStack.new(&"test_helmet", 1))
	await _stand_on(plot)
	var before: int = _layer.get_pickups().size()
	await _press_e()
	var dropped: Array[ItemPickup] = []
	for pickup: ItemPickup in _layer.get_pickups():
		if pickup.item_id == &"potato" or pickup.item_id == &"seed_potato":
			dropped.append(pickup)
	check("full_bag_drops_near_player", not dropped.is_empty() and _layer.get_pickups().size() > before
		and dropped[0].global_position.distance_to(_player.global_position) < 20.0 and not plot.has_crop(), _feedback())
	for pickup: ItemPickup in _layer.get_pickups():
		pickup.queue_free()
	bag.clear()
	await frames(2)
	# Nhiều loại hạt: E hỏi chọn (menu), chọn rồi thì nhớ cho lần sau.
	bag.add(&"wheat_seed", 2)
	bag.add(&"seed_potato", 2)
	_farms._selected_seed = &""
	var a: FarmPlot = _plot(0, 3)
	var b: FarmPlot = _plot(1, 3)
	_set_plot(a, {"state": "tilled"})
	_set_plot(b, {"state": "tilled"})
	var asked: Array = []
	_farms.seed_choice_requested.connect(func(_p: FarmPlot, ids: Array[StringName]) -> void: asked.append(ids), CONNECT_ONE_SHOT)
	await _stand_on(a)
	check("prompt_choose_seed", _prompt().contains("chọn hạt"), _prompt())
	await _press_e()
	check("seed_menu_asked", asked.size() == 1 and (asked[0] as Array).size() == 2 and not a.has_crop())
	var ids: Array[StringName] = [&"wheat_seed", &"seed_potato"]
	var menu: PopupMenu = _world.open_seed_menu(a, ids)
	check("seed_menu_items", menu.item_count == 2 and menu.get_item_text(1).contains("Củ giống"), menu.get_item_text(1))
	menu.hide()
	_world.choose_seed_action(a, &"seed_potato")
	check("seed_menu_plants_choice", a.has_crop() and a.crop.id == &"potato" and bag.count_of(&"seed_potato") == 1)
	await _stand_on(b)
	await _press_e()
	check("seed_choice_remembered", b.has_crop() and b.crop.id == &"potato" and not bag.has(&"seed_potato"), _feedback())
	# Quái đêm không phá cây (đuổi người chơi đứng giữa ruộng).
	await _set_time(_clock.get_day(), 22)
	var states: Array[Dictionary] = []
	for p: FarmPlot in _farms.get_plots():
		states.append(p.save_plot_state())
	await _stand_on(_plot(2, 2))
	var ghouls: Array[Enemy] = (_world.enemy_spawner as EnemySpawner).debug_spawn(&"forest_ghoul")
	var wolves: Array[Enemy] = (_world.enemy_spawner as EnemySpawner).debug_spawn(&"night_wolf")
	_hurtbox().set_invulnerable(9999.0)
	await frames(180)
	var same: bool = true
	var k: int = 0
	for p: FarmPlot in _farms.get_plots():
		same = same and p.save_plot_state() == states[k]
		k += 1
	check("enemies_dont_harm_crops", same and (ghouls.size() + wolves.size()) > 0)
	for enemy: Enemy in ghouls + wolves:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_player.get_health().reset()
	await frames(2)


# ---------------------------------------------------------------- 6. phím debug

func _test_debug_keys() -> void:
	_reset_field()
	await _set_time(_clock.get_day(), 9)
	var plot: FarmPlot = _plot(4, 1)
	var other: FarmPlot = _plot(1, 1)
	_set_plot(plot, {"state": "planted", "crop": "potato", "age": 0})
	_set_plot(other, {"state": "planted", "crop": "wheat", "age": 0})
	await _place_at(_plot(0, 3).global_position)
	# Trỏ chuột vào ô (toạ độ world → màn hình → cửa sổ).
	var screen: Vector2 = _world.get_viewport().get_canvas_transform() * plot.global_position
	await _mouse_to(root.get_final_transform() * screen)
	await tap_action(&"debug_crop_grow")
	check("f6_grows_hovered_stage", plot.get_stage() == 1 and other.get_stage() == 0, "%d / %d" % [plot.get_stage(), other.get_stage()])
	await tap_action(&"debug_farm_water")
	check("f11_waters_all", plot.is_wet() and other.is_wet())
	var keys: Dictionary = {&"debug_crop_grow": KEY_F6, &"debug_farm_water": KEY_F11}
	var ok: bool = true
	for action: StringName in keys:
		var event: InputEventKey = InputMap.action_get_events(action)[0] as InputEventKey
		ok = ok and event.physical_keycode == keys[action]
	check("debug_keys_f6_f11", ok)


# ---------------------------------------------------------------- 7. ngủ / ngất / ở map khác

func _test_sleep_faint_and_away() -> void:
	_reset_field()
	await _set_time(_clock.get_day(), 10)
	var plot: FarmPlot = _plot(2, 0)
	_set_plot(plot, {"state": "planted", "crop": "potato", "age": 1})
	plot.water_now()
	# Ngất: tưới lúc 22:00, còn thức tới 2:00 → ngất → tỉnh 6:00 hôm sau → cây lớn như qua đêm.
	await _place_at(IsoProjection.to_screen(ARENA.x, ARENA.y))
	await _set_time(_clock.get_day(), 22)
	plot.water_now()
	await _set_time(_clock.get_day(), 23, 30)
	_world.sleep_controller.settings.faint_hour = 2
	_clock.running = true
	_clock.time_scale = 60.0
	var fainted: Array[int] = []
	_world.sleep_controller.fainted.connect(func(day: int) -> void: fainted.append(day), CONNECT_ONE_SHOT)
	for i: int in 600:
		await process_frame
		if not fainted.is_empty():
			break
	_clock.running = false
	_clock.time_scale = 1.0
	check("faint_counts_as_night", not fainted.is_empty() and plot.age == 2 and _clock.get_hour() == 6, "age %d %s" % [plot.age, _clock.format_time()])
	_world.sleep_controller.settings.faint_hour = 99
	# Ở map khác: lưu ở Glade (cây vừa tưới), sang test_map; thời gian trôi 3 ngày ngoài Glade (đồng hồ global — test_map
	# chưa có đồng hồ nên mô phỏng bằng save có đồng hồ muộn hơn) → tải lại Glade: bù đủ 3 lần 6:00.
	await _set_time(_clock.get_day(), 9)
	_set_plot(plot, {"state": "planted", "crop": "potato", "age": 2})
	plot.water_now()
	var day0: int = _clock.get_day()
	check("away_saved", _saves.save_game(3))
	change_scene_to_file(TEST_MAP_PATH)
	await frames(6)
	check("away_on_test_map", current_scene != null and str(current_scene.get(&"map_id")) == "test_map")
	var data: Dictionary = _read_raw(3)
	data["global"]["clock"]["day"] = day0 + 3
	_write(3, data)
	await _reload(3)
	var back: FarmPlot = _plot(2, 0)
	check("grows_while_away", back.has_crop() and back.age == 3 and back.dry_days == 2 and _clock.get_day() == day0 + 3,
		"age %d dry %d ngày %d" % [back.age, back.dry_days, _clock.get_day()])


# ---------------------------------------------------------------- 8. save / load mọi giai đoạn

func _test_save_every_stage() -> void:
	_reset_field()
	await _set_time(_clock.get_day(), 11)
	var plots: Array[FarmPlot] = _farms.get_plots()
	var k: int = 0
	for crop_id: String in ["wheat", "potato", "berry_bush"]:
		var crop: CropDefinition = _farms.crop_book.get_crop(StringName(crop_id))
		for stage: int in crop.stages:
			var plot: FarmPlot = plots[k]
			_set_plot(plot, {"state": "planted", "crop": crop_id, "age": stage * crop.days_per_stage, "dry_days": stage % 3})
			if stage % 2 == 0:
				plot.water_now()
			k += 1
	_set_plot(plots[k], {"state": "tilled", "fallow_days": 2})
	_set_plot(plots[k + 1], {"state": "tilled", "fallow_days": 0})
	_set_plot(plots[k + 2], {"state": "planted", "crop": "berry_bush", "age": 4, "dry_days": 1})
	plots[k + 2].water_now()
	_equipment().set_slot(&"weapon", ItemStack.new(&"watering_can", 1, {"water": 7}))
	_bag().clear()
	_bag().add_stack(ItemStack.new(&"stone_hoe", 1, {"durability": 33}))
	var before: Array[Dictionary] = []
	for plot: FarmPlot in plots:
		before.append(plot.save_plot_state())
	check("save_mid_growth", _saves.save_game(4))
	var raw: Dictionary = _read_raw(4)
	var farms: Dictionary = raw["maps"]["glade"]["farms"]
	var sample: Dictionary = farms["fields"]["glade_home"]["plots"]["1,0"]
	check("save_farm_structure", int(raw["schema_version"]) == SaveServiceScript.SCHEMA_VERSION and SaveServiceScript.SCHEMA_VERSION == 6
		and farms["version"] == 2 and farms.has("last_tick") and (farms["fields"]["glade_home"]["plots"] as Dictionary).size() == k + 3
		and sample["state"] == "planted" and sample["crop"] == "wheat" and sample["stage"] == 1 and sample["age"] == 1
		and sample.has("wet") and sample.has("dry_days") and sample.has("fallow_days") and sample.has("watered_day"), str(sample))
	check("save_can_water", raw["global"]["player"]["equipment"]["slots"]["weapon"]["data"]["water"] == 7)
	await _reload(4)
	var after: Array[Dictionary] = []
	for plot: FarmPlot in _farms.get_plots():
		after.append(plot.save_plot_state())
	var diff: Array[String] = []
	for i: int in before.size():
		if before[i] != after[i]:
			diff.append("%d: %s != %s" % [i, before[i], after[i]])
	check("load_every_stage_same", diff.is_empty(), str(diff))
	check("load_can_water", _water_left() == 7 and _bag().get_stack(_find(_bag(), &"stone_hoe")).data.get("durability") == 33)
	check("load_wet_dry_visual", _plot(0, 0).is_wet() and not _plot(1, 0).is_wet())
	# Lưu → tải → qua đêm vẫn đúng luật (ô ướt lớn, ô khô thêm ngày khô).
	var wet_age: int = _plot(0, 0).age
	var dry_before: int = _plot(1, 0).dry_days
	_skip(_clock.minutes_until(6 * 60))
	await frames(1)
	check("rules_after_load", _plot(0, 0).age == wet_age + 1 and _plot(1, 0).dry_days == dry_before + 1)


# ---------------------------------------------------------------- 9. migration, save cũ

func _test_migrations_and_old_saves() -> void:
	var at: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	# v4 (M4).
	var v4: Dictionary = {"schema_version": 4, "saved_at": "2026-10-21 18:00:00", "playtime": 500.0, "map_id": "glade",
		"global": {"clock": {"version": 1, "day": 3, "minute": 700.0},
			"player": {"position": [at.x, at.y], "tier": 0, "health": 75,
				"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "hide", "count": 2}]},
				"survival": {"mana": 40.0, "stamina": 50.0, "hunger": 60.0, "respawn": {}, "buffs": []}}},
		"maps": {"glade": {"world_items": {"version": 3, "collected": [], "dropped": [], "death_bags": [], "deployed": []},
			"resource_nodes": {"version": 1, "nodes": {}}, "enemies": {"version": 1, "enemies": []}}}}
	_write(5, v4)
	var migrated: Dictionary = _saves.read_save(5)
	check("migration_v4_to_current", int(migrated["schema_version"]) == SaveServiceScript.SCHEMA_VERSION
		and migrated["maps"]["glade"]["farms"] == {"version": 2, "fields": {}, "refunds": []}, str(migrated["maps"]["glade"]["farms"]))
	await _reload(5)
	var all_grass: bool = true
	for plot: FarmPlot in _farms.get_plots():
		all_grass = all_grass and not plot.tilled
	check("load_v4_ok", _clock.get_day() == 3 and _bag().count_of(&"hide") == 2 and _player.get_health().current_health == 75
		and all_grass and _farms.last_tick == _farms._current_tick())
	check("load_v4_resave_current", _saves.save_game(5) and int(_saves.read_save(5)["schema_version"]) == SaveServiceScript.SCHEMA_VERSION)
	# v3 (M3).
	var v3: Dictionary = {"schema_version": 3, "saved_at": "2026-10-20 18:00:00", "playtime": 400.0, "map_id": "glade",
		"global": {"clock": {"version": 1, "day": 2, "minute": 900.0},
			"player": {"position": [at.x, at.y], "tier": 0, "health": 70,
				"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "fiber", "count": 3}]},
				"survival": {"mana": 40.0, "stamina": 50.0, "hunger": 60.0, "respawn": {}}}},
		"maps": {"glade": {"world_items": {"version": 3, "collected": [], "dropped": [], "death_bags": [], "deployed": []},
			"resource_nodes": {"version": 1, "nodes": {}}}}}
	_write(6, v3)
	await _reload(6)
	check("load_v3_ok", _clock.get_day() == 2 and _bag().count_of(&"fiber") == 3 and _farms.get_plots().size() == 24)
	# v2 (M2).
	var v2: Dictionary = {"schema_version": 2, "saved_at": "2026-10-20 17:00:00", "playtime": 300.0, "map_id": "glade",
		"global": {"clock": {"version": 1, "day": 3, "minute": 600.0},
			"player": {"position": [at.x, at.y], "tier": 0, "health": 80,
				"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "bread", "count": 2}]},
				"survival": {"mana": 50.0, "stamina": 60.0, "hunger": 70.0, "respawn": {}}}},
		"maps": {"glade": {"world_items": {"version": 2, "collected": [], "dropped": [], "death_bags": [], "deployed": []}}}}
	_write(7, v2)
	await _reload(7)
	check("load_v2_ok", _clock.get_day() == 3 and _bag().count_of(&"bread") == 2)
	# v1 (M1).
	var v1: Dictionary = {"schema_version": 1, "saved_at": "2026-10-20 00:17:07", "playtime": 12.0, "map_id": "glade",
		"global": {"player": {"position": [at.x, at.y], "tier": 0, "health": 90,
			"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "wood", "count": 5}]}}},
		"maps": {"glade": {"world_items": {"version": 1, "collected": [], "dropped": []}}}}
	_write(8, v1)
	await _reload(8)
	check("load_v1_ok", _bag().count_of(&"wood") == 5 and _clock.get_day() == 1 and _player.get_health().current_health == 90)
	var v1_migrated: Dictionary = _saves.read_save(8)
	check("migration_chain_v1_current", int(v1_migrated["schema_version"]) == SaveServiceScript.SCHEMA_VERSION and v1_migrated["maps"]["glade"].has("farms")
		and v1_migrated["maps"]["glade"].has("enemies") and v1_migrated["maps"]["glade"].has("resource_nodes"))


# ---------------------------------------------------------------- 10. hiệu năng

func _test_performance() -> void:
	_reset_field()
	await _set_time(_clock.get_day(), 22)
	var k: int = 0
	for plot: FarmPlot in _farms.get_plots():
		var crop_id: String = ["wheat", "potato", "berry_bush"][k % 3]
		var crop: CropDefinition = _farms.crop_book.get_crop(StringName(crop_id))
		_set_plot(plot, {"state": "planted", "crop": crop_id, "age": (k % crop.stages) * crop.days_per_stage})
		k += 1
	await _place_at(IsoProjection.to_screen(ARENA.x, ARENA.y))
	var spawner: EnemySpawner = _world.enemy_spawner
	var enemies: Array[Enemy] = []
	for id: StringName in [&"shade", &"shade", &"shade", &"shade", &"shade", &"night_wolf", &"night_wolf", &"forest_ghoul",
			&"forest_ghoul", &"forest_ghoul", &"forest_ghoul"]:
		if enemies.size() >= 15:
			break
		enemies.append_array(spawner.debug_spawn(id))
	while enemies.size() > 15:
		enemies.pop_back().queue_free()
	_hurtbox().set_invulnerable(9999.0)
	await frames(30)
	# Thời gian thực mỗi frame (headless: không render; Performance.TIME_PROCESS không đáng tin ở headless).
	var samples: int = 180
	var max_ms: float = 0.0
	var started: int = Time.get_ticks_usec()
	var last: int = started
	for i: int in samples:
		await process_frame
		var now: int = Time.get_ticks_usec()
		max_ms = maxf(max_ms, (now - last) / 1000.0)
		last = now
	var avg_ms: float = (last - started) / 1000.0 / samples
	var alive: int = 0
	for enemy: Enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead():
			alive += 1
	print("MEASURE perf_24_crops_night_%d_enemies: trung bình %.2f ms / frame, tối đa %.2f ms (headless, không gồm render)" % [alive, avg_ms, max_ms])
	check("perf_setup", alive >= 15 and _farms.get_plots().all(func(p: FarmPlot) -> bool: return p.has_crop()), "%d quái" % alive)
	check("perf_frame_under_16ms", avg_ms < 16.7, "trung bình %.2f ms, tối đa %.2f ms" % [avg_ms, max_ms])
	for enemy: Enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	await frames(2)
