extends "res://tests/test_base.gd"
## Kiểm thử headless TASK M3 trên Environment Prototype (Glade), đi qua input thật khi có thể (E tương tác / khai thác,
## C mở chế tạo, click chuột vào nút, I + rê chuột + F trong túi đồ). Đặt Player bằng cách dịch chuyển (như test M2).
## 0. Chỉnh sau M2: CombatHUD không lệch, lời nhắc [E] không chạm dòng gợi ý phím, túi đồ rỗng tự xóa, tối đa 5 túi,
##    ô kỹ năng 2 = Z, C = chế tạo.
## 1. Vòng lặp đầy đủ: nhổ cỏ + nhặt cành + nhặt đá vụn → chế rìu → chặt cây → chế + dựng lửa trại → hạ enemy lấy thịt
##    → nấu → ăn → đói tăng đúng.
## 2. Thiếu công cụ không khai thác được; công cụ vỡ đúng lúc; nguyên liệu thiếu tô đỏ + nút khóa, không trừ đồ; túi đầy.
## 3. Bàn chế tạo: công thức lều chỉ có khi đứng gần.
## 4. Node mọc lại đúng ngày, kể cả sau save/load.
## 5. Lửa trại: ánh sáng, hết giờ thì tắt, thêm củi nhóm lại, giới hạn mỗi map, lưu/tải. Đuốc: bán kính, cháy hết.
## 6. Save v3: cấu trúc; tải save v2 (M2) và v1 (M1).
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/gathering/test_gathering.gd

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")
const TEST_DIR: String = "user://test_saves_gathering/"
const ARENA: Vector2 = Vector2(22.0, 35.0)

var _saves: SaveServiceScript
var _world: Node  # Không khai báo kiểu World: world.gd dùng tên Autoload (xem test_base.gd).
var _player: Player
var _clock: GameClock
var _layer: ItemPickupLayer
var _resources: ResourceNodeLayer
var _window: CraftingWindow


func _run_tests() -> void:
	_saves = root.get_node("SaveService") as SaveServiceScript
	_saves.save_dir = TEST_DIR
	_saves.autosave_on_quit = false
	_clear_dir()
	await _open_world()
	await _test_hud_and_keys()
	await _test_full_loop()
	await _test_missing_tool()
	await _test_tool_breaks()
	await _test_craft_ui_missing_and_full()
	await _test_workbench()
	await _test_regrow_and_save()
	await _test_campfire()
	await _test_torch()
	await _test_death_bags()
	await _test_load_old_saves()
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
	_layer = _world.pickup_layer
	_resources = _world.resource_layer
	_window = _world.crafting_window


## Không fade, enemy đứng yên ở xa, đồng hồ đứng yên, bỏ vật phẩm đặt sẵn (không lẫn vào túi khi đi ngang).
func _prepare() -> void:
	var settings: SleepSettings = _world.sleep_controller.settings
	settings.fade_time = 0.0
	settings.title_time = 0.0
	var enemy: Node2D = _enemy()
	enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_clock.running = false
	for pickup: ItemPickup in _layer.get_pickups():
		pickup.queue_free()


func _enemy() -> Node2D:
	return _world.get_node("EntityContainer/SimpleEnemy") as Node2D


func _place(grid: Vector2, tier: int = 0) -> void:
	_player.global_position = IsoProjection.to_screen(grid.x, grid.y, IsoProjection.TIER_HEIGHT * tier)
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(tier)


## Đứng ngay trước (phía dưới màn hình) một node / vật và chờ InteractionDetector chọn nó làm mục tiêu.
func _stand_at(target: Node2D, offset: Vector2 = Vector2(0, 20)) -> void:
	_player.global_position = target.global_position + offset
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(4)


func _node(node_id: String) -> ResourceNode:
	return _resources.find_resource(node_id)


func _feedback() -> String:
	return (_world.get_node("UILayer/InteractionFeedback/Label") as Label).text


func _prompt() -> String:
	return (_world.get_node("UILayer/InteractionPrompt") as InteractionPrompt).get_text()


func _bag() -> Inventory:
	return _player.get_inventory()


func _find(bag: Inventory, item_id: StringName) -> int:
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			return i
	return -1


## Nhấn E (input thật) rồi chờ một frame.
func _press_e() -> void:
	await tap_action(&"interact")
	await process_frame


## Click chuột trái thật lên một Control (toạ độ canvas → toạ độ cửa sổ qua stretch của root viewport).
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


## Rê chuột lên ô túi đồ chứa item rồi nhấn F (hành động chính: dùng / trang bị / dựng). Cửa sổ túi đồ mở/đóng bằng I.
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


# ---------------------------------------------------------------- 0. HUD, phím

func _test_hud_and_keys() -> void:
	# CombatHUD không bị lệch trong scene (lỗi 619f391: editor lưu offset (77, −65) đẩy HUD ra ngoài màn hình).
	for path: String in [SCENE_PATH, "res://world/world.tscn", "res://world/sandbox/combat_sandbox.tscn"]:
		var state: SceneState = (load(path) as PackedScene).get_state()
		var offset_props: Array[String] = []
		for i: int in state.get_node_count():
			if str(state.get_node_name(i)) != "CombatHUD":
				continue
			for p: int in state.get_node_property_count(i):
				var prop: String = str(state.get_node_property_name(i, p))
				if prop.begins_with("offset_") or prop == "position" or prop.begins_with("anchor"):
					offset_props.append("%s=%s" % [prop, state.get_node_property_value(i, p)])
		check("combat_hud_no_offset_override_%s" % path.get_file().get_basename(), offset_props.is_empty(), str(offset_props))
	var hud: CombatHUD = _world.combat_hud
	var health_box: Control = hud.get_node("PlayerHealth") as Control
	check("combat_hud_on_screen", hud.get_global_rect().position == Vector2.ZERO and health_box.get_global_rect().position.y >= 0.0
		and health_box.get_global_rect().position.x >= 0.0, str(health_box.get_global_rect()))
	# Lời nhắc [E] không chồng dòng gợi ý phím (đứng cạnh bụi cỏ để lời nhắc hiện).
	await _stand_at(_node("glade_grass_1"))
	var prompt: Control = _world.get_node("UILayer/InteractionPrompt") as Control
	var hint: Label = hud.get_node("HintLabel") as Label
	await process_frame
	# Cả khung nhãn gợi ý (đã giãn theo số dòng thật) — chặt hơn chỉ phần chữ.
	var hint_rect: Rect2 = hint.get_global_rect()
	check("hint_rect_fits_text", hint_rect.size.y >= hint.get_line_count() * hint.get_line_height() - 1, "%s, %d dòng" % [hint_rect, hint.get_line_count()])
	check("prompt_visible", prompt.visible and _prompt().contains("Nhổ — Bụi cỏ"), _prompt())
	check("prompt_not_overlapping_hint", not prompt.get_global_rect().intersects(hint_rect), "%s vs %s" % [prompt.get_global_rect(), hint_rect])
	# Phím: C = chế tạo, ô kỹ năng 2 = Z (C không còn là phím kỹ năng).
	var slot2: InputEventKey = InputMap.action_get_events(&"skill_slot_2")[0] as InputEventKey
	var craft: InputEventKey = InputMap.action_get_events(&"craft_toggle")[0] as InputEventKey
	check("keys_z_and_c", slot2.physical_keycode == KEY_Z and craft.physical_keycode == KEY_C)
	await tap_action(&"craft_toggle")
	var caster: SkillCastingController = _player.get_node("SkillCastingController") as SkillCastingController
	check("c_opens_crafting_not_skill", _window.is_open() and caster.get_state() == SkillCastingController.State.IDLE
		and _player.is_combat_input_blocked())
	await tap_action(&"craft_toggle")
	check("c_closes_crafting", not _window.is_open() and not _player.is_combat_input_blocked())


# ---------------------------------------------------------------- 1. vòng lặp đầy đủ

func _test_full_loop() -> void:
	var bag: Inventory = _bag()
	var equipment: EquipmentSlots = _player.get_equipment()
	var hunger: HungerComponent = _player.get_hunger()
	bag.clear()
	# Nhổ cỏ (tay không) → sợi.
	for node_id: String in ["glade_grass_1", "glade_grass_2"]:
		var grass: ResourceNode = _node(node_id)
		await _stand_at(grass)
		check("target_%s" % node_id, _world.interaction_detector.get_target() == grass)
		await _press_e()
		check("pull_%s" % node_id, grass.depleted and not (grass.get_node("Available") as Node2D).visible, _feedback())
	check("fiber_gathered", bag.count_of(&"fiber") >= 4, str(bag.count_of(&"fiber")))
	# Nhặt cành dưới gốc cây (tay không, 2 lần mỗi cây) → cành; lời nhắc "Nhặt cành · Cần rìu".
	for node_id: String in ["glade_tree_1", "glade_tree_2"]:
		var tree: ResourceNode = _node(node_id)
		await _stand_at(tree)
		check("tree_prompt_hand_%s" % node_id, _prompt().contains("Nhặt cành · Cần rìu"), _prompt())
		await _press_e()
		await _press_e()
		check("tree_hand_uses_%s" % node_id, tree.hand_left == 0 and not tree.depleted)
	check("branches_gathered", bag.count_of(&"branch") >= 4, str(bag.count_of(&"branch")))
	# Nhặt đá vụn (tay không) quanh tảng đá → đá.
	for node_id: String in ["glade_rock_1", "glade_rock_2"]:
		await _stand_at(_node(node_id))
		await _press_e()
		await _press_e()
	check("stones_gathered", bag.count_of(&"stone") == 4, str(bag.count_of(&"stone")))
	# Chế rìu đá bằng C + click nút.
	check("craft_axe_via_ui", await _craft_via_ui(&"stone_axe") and bag.has(&"stone_axe"), _feedback())
	# Trang bị rìu (I, rê chuột, F) → tay chính.
	await _use_from_bag(&"stone_axe")
	check("equip_axe_main_hand", equipment.get_tool() != null and equipment.get_tool().id == &"stone_axe"
		and (_world.player_weapon as WeaponEquipment).get_weapon().weapon_id == &"stone_axe")
	# Chặt cây: 4 lần (rìu đá sức 1, cây độ bền khai thác 4), mỗi lần −1 độ bền.
	var tree1: ResourceNode = _node("glade_tree_1")
	await _stand_at(tree1)
	check("tree_prompt_axe", _prompt().contains("Chặt (Độ bền 40/40)"), _prompt())
	var wood_before: int = bag.count_of(&"wood")
	for i: int in 4:
		await _press_e()
	check("tree_chopped", tree1.depleted and bag.count_of(&"wood") - wood_before >= 3 and _feedback().contains("Gỗ"), _feedback())
	check("tree_stump_and_no_block", (tree1.get_node("Depleted") as Node2D).visible
		and (tree1.get_node("Available/Collision/Footprint0") as CollisionPolygon2D).disabled)
	check("axe_durability_36", DatabaseHelper.durability(equipment, &"weapon") == 36, str(DatabaseHelper.durability(equipment, &"weapon")))
	# Chế lửa trại rồi dựng (I, rê chuột, F) ở đồng cỏ, trước mặt.
	check("craft_campfire_via_ui", await _craft_via_ui(&"campfire") and bag.has(&"campfire"), _feedback())
	_place(ARENA)
	Input.action_press(&"move_down")
	await frames(3)
	Input.action_release(&"move_down")
	await frames(2)
	await _use_from_bag(&"campfire")
	var fires: Array[Campfire] = _campfires()
	check("campfire_deployed_in_front", fires.size() == 1 and fires[0].lit and not bag.has(&"campfire")
		and fires[0].global_position.y > _player.global_position.y + 10.0, _feedback())
	var fire: Campfire = fires[0]
	# Thịt sống: hạ enemy → rơi thịt (bảng rơi đồ) → nhặt (hút về khi đứng gần).
	var enemy: Node2D = _enemy()
	(enemy.get_node("HealthComponent") as HealthComponent).apply_damage(999)
	await frames(2)
	var meat_drops: Array[ItemPickup] = []
	for pickup: ItemPickup in _layer.get_pickups():
		if pickup.item_id == &"raw_meat":
			meat_drops.append(pickup)
	check("enemy_drops_raw_meat", meat_drops.size() == 1 and meat_drops[0].count >= 1 and meat_drops[0].count <= 2
		and meat_drops[0].global_position.distance_to(enemy.global_position) < 20.0)
	_player.global_position = meat_drops[0].global_position + Vector2(40, 0)
	await frames(4)
	_player.global_position = meat_drops[0].global_position
	await frames(30)
	check("raw_meat_picked_up", bag.has(&"raw_meat"), str(bag.count_of(&"raw_meat")))
	# Nấu ở lửa trại: E → cửa sổ Nấu → click "Nấu" thịt nướng.
	await _stand_at(fire, Vector2(0, 22))
	check("campfire_prompt", _prompt().contains("Nấu ăn / thêm củi"), _prompt())
	await _press_e()
	check("campfire_opens_cook_window", _window.is_open() and _window.get_campfire() == fire
		and _window.get_recipe_ids() == [&"grilled_meat", &"roasted_berry"], str(_window.get_recipe_ids()))
	var cook: Button = _window.get_craft_button(&"grilled_meat")
	check("cook_button_enabled", cook != null and not cook.disabled and cook.text == "Nấu")
	await _click(cook)
	check("cooked_grilled_meat", bag.has(&"grilled_meat") and _feedback().begins_with("Đã nấu Thịt nướng"), _feedback())
	await tap_action(&"ui_cancel")
	check("esc_closes_cook_window", not _window.is_open())
	# Ăn → đói tăng đúng +40.
	hunger.load_value(50.0)
	await _use_from_bag(&"grilled_meat")
	check("eat_grilled_meat_hunger", is_equal_approx(hunger.value, 90.0) and _feedback().begins_with("Đã dùng Thịt nướng"),
		"%.1f %s" % [hunger.value, _feedback()])
	hunger.load_value(100.0)
	_player.get_buffs().clear()


func _campfires() -> Array[Campfire]:
	var result: Array[Campfire] = []
	for node: Node in _layer.get_deployed():
		if node is Campfire:
			result.append(node as Campfire)
	return result


# ---------------------------------------------------------------- 2. thiếu công cụ / vỡ / UI

func _test_missing_tool() -> void:
	var bag: Inventory = _bag()
	var equipment: EquipmentSlots = _player.get_equipment()
	var axe: ItemStack = equipment.get_stack(&"weapon")
	equipment.set_slot(&"weapon", null)
	# Đá: đã nhặt hết đá vụn (2 lần) → không có cuốc thì không lấy được gì.
	var rock: ResourceNode = _node("glade_rock_1")
	await _stand_at(rock)
	var stones: int = bag.count_of(&"stone")
	check("rock_prompt_needs_pickaxe", _prompt().contains("Cần cuốc"), _prompt())
	await _press_e()
	check("rock_without_pickaxe_refused", bag.count_of(&"stone") == stones and rock.progress_left == rock.definition.toughness
		and _feedback() == "Cần cuốc", _feedback())
	# Cầm rìu vẫn không đập được đá.
	equipment.set_slot(&"weapon", axe)
	await _press_e()
	check("axe_cannot_mine_rock", bag.count_of(&"stone") == stones and _feedback() == "Cần cuốc"
		and DatabaseHelper.durability(equipment, &"weapon") == 36, _feedback())
	# Cây hết lượt nhặt cành, tay không → "Cần rìu".
	equipment.set_slot(&"weapon", null)
	var tree: ResourceNode = _node("glade_tree_2")
	await _stand_at(tree)
	var wood: int = bag.count_of(&"wood")
	await _press_e()
	check("tree_without_axe_refused", bag.count_of(&"wood") == wood and tree.progress_left == tree.definition.toughness
		and _feedback() == "Cần rìu", _feedback())
	equipment.set_slot(&"weapon", axe)


func _test_tool_breaks() -> void:
	var equipment: EquipmentSlots = _player.get_equipment()
	# Rìu còn 2 độ bền: lần 1 còn 1, lần 2 vỡ (biến mất khỏi tay, thông báo).
	equipment.set_slot(&"weapon", ItemStack.new(&"stone_axe", 1, {"durability": 2}))
	var tree: ResourceNode = _node("glade_tree_2")
	await _stand_at(tree)
	await _press_e()
	check("axe_1_left", DatabaseHelper.durability(equipment, &"weapon") == 1 and tree.progress_left == 3)
	await _press_e()
	check("axe_breaks_exactly", equipment.get_stack(&"weapon") == null and _feedback().contains("Rìu đá đã vỡ")
		and (_world.player_weapon as WeaponEquipment).get_weapon() == null and tree.progress_left == 2, _feedback())
	await _press_e()
	check("broken_axe_cannot_chop", tree.progress_left == 2 and _feedback() == "Cần rìu", _feedback())
	equipment.set_slot(&"weapon", ItemStack.new(&"stone_axe", 1))


func _test_craft_ui_missing_and_full() -> void:
	var bag: Inventory = _bag()
	bag.clear()
	bag.add(&"branch", 1)
	# Xa lửa trại (dựng cạnh ARENA ở phần 1) và bàn chế tạo: chỉ công thức tay.
	_place(Vector2(20.0, 31.0))
	await frames(2)
	await tap_action(&"craft_toggle")
	var button: Button = _window.get_craft_button(&"stone_axe")
	var text: String = _window.get_ingredient_text(&"stone_axe")
	check("missing_ingredients_red", text.contains("[color=%s]Cành cây 1/2[/color]" % CraftingWindow.MISSING_COLOR)
		and text.contains("[color=%s]Đá 0/2[/color]" % CraftingWindow.MISSING_COLOR), text)
	check("missing_button_locked", button.disabled and button.tooltip_text == "Thiếu nguyên liệu")
	await _click(button)
	check("missing_no_deduction", bag.count_of(&"branch") == 1 and not bag.has(&"stone_axe"))
	check("hand_station_lists_only_hand", not _window.get_recipe_ids().has(&"tent") and not _window.get_recipe_ids().has(&"grilled_meat"))
	# Đủ nguyên liệu → nút mở, nguyên liệu xanh (làm mới khi túi đổi).
	bag.add(&"branch", 1)
	bag.add(&"stone", 2)
	bag.add(&"fiber", 3)
	await process_frame
	check("ingredients_ok_unlock", not _window.get_craft_button(&"stone_axe").disabled
		and not _window.get_ingredient_text(&"stone_axe").contains(CraftingWindow.MISSING_COLOR))
	# Túi đầy: nguyên liệu không nhường ô → chặn, báo rõ, không trừ đồ.
	var filler: Array[StringName] = [&"wood", &"herb", &"berry", &"raw_meat", &"bread", &"test_helmet", &"ancient_relic", &"lantern",
		&"tent", &"bandage", &"torch", &"roasted_berry", &"grilled_meat", &"test_dagger", &"test_heavy", &"test_sword", &"campfire"]
	for item_id: StringName in filler:
		bag.add(item_id, 1)
	bag.add(&"stone", 97)
	bag.add(&"fiber", 96)
	bag.add(&"branch", 97)
	while not bag.is_full():
		bag.add(&"stone_pickaxe", 1)
	await process_frame
	var before: Dictionary = bag.to_dict()
	check("full_bag_button_locked", _window.get_craft_button(&"stone_axe").disabled
		and _window.get_craft_button(&"stone_axe").tooltip_text.begins_with("Túi đầy"), _window.get_craft_button(&"stone_axe").tooltip_text)
	var reason: String = _window.craft(&"stone_axe")
	check("full_bag_craft_blocked", reason.begins_with("Túi đầy") and bag.to_dict() == before and _feedback().begins_with("Túi đầy"), reason)
	await tap_action(&"craft_toggle")
	bag.clear()


# ---------------------------------------------------------------- 3. bàn chế tạo

func _test_workbench() -> void:
	var bag: Inventory = _bag()
	bag.clear()
	bag.add(&"wood", 4)
	bag.add(&"fiber", 8)
	bag.add(&"branch", 4)
	var bench: Workbench = _world.get_node("EntityContainer/Workbench") as Workbench
	await _stand_at(bench, Vector2(0, 24))
	check("workbench_prompt", _prompt().contains("Chế tạo — Bàn chế tạo"), _prompt())
	await _press_e()
	check("workbench_e_opens_window", _window.is_open() and _window.get_recipe_ids().has(&"tent")
		and _window.get_stations() == [RecipeDefinition.Station.WORKBENCH], str(_window.get_recipe_ids()))
	await _click(_window.get_craft_button(&"tent"))
	check("workbench_craft_tent", bag.has(&"tent") and not bag.has(&"wood"), _feedback())
	# Đi xa: công thức lều biến mất khỏi danh sách (làm mới theo vị trí).
	_place(ARENA)
	await seconds(0.4)
	check("away_from_workbench_no_tent", _window.is_open() and not _window.get_recipe_ids().has(&"tent"), str(_window.get_recipe_ids()))
	await tap_action(&"craft_toggle")
	bag.clear()


# ---------------------------------------------------------------- 4. mọc lại + save/load

func _test_regrow_and_save() -> void:
	# Ngày 1: cỏ (mọc sau 1 ngày) và cây 1 (3 ngày) đã bị phá ở phần 1.
	var grass: ResourceNode = _node("glade_grass_1")
	var tree: ResourceNode = _node("glade_tree_1")
	check("regrow_days_set", grass.regrow_day == 2 and tree.regrow_day == 4, "%d %d" % [grass.regrow_day, tree.regrow_day])
	_clock.set_time(1, 23 * 60)
	_clock.advance(61.0)
	check("grass_regrows_next_day", _clock.get_day() == 2 and not grass.depleted and (grass.get_node("Available") as Node2D).visible)
	check("tree_not_yet", tree.depleted)
	# Lưu ngày 2 (cây còn gốc, lửa trại đang cháy, rìu đã mòn), tải lại.
	var equipment: EquipmentSlots = _player.get_equipment()
	equipment.set_slot(&"weapon", ItemStack.new(&"stone_axe", 1, {"durability": 17}))
	var fire: Campfire = _campfires()[0]
	fire.fuel_minutes = 123.0
	check("save_v3", _saves.save_game(2))
	var data: Dictionary = _saves.read_save(2)
	var nodes: Dictionary = data["maps"]["glade"]["resource_nodes"]["nodes"]
	var deployed: Array = data["maps"]["glade"]["world_items"]["deployed"]
	check("save_v3_structure", int(data["schema_version"]) == 3 and nodes.has("glade_tree_1") and nodes["glade_tree_1"]["depleted"] == true
		and nodes["glade_tree_1"]["regrow_day"] == 4.0 and not nodes.has("glade_grass_1"), JSON.stringify(nodes))
	check("save_v3_campfire_state", deployed.size() == 1 and deployed[0]["item_id"] == "campfire"
		and deployed[0]["state"] == {"fuel": 123.0, "lit": true}, JSON.stringify(deployed))
	check("save_v3_tool_durability", data["global"]["player"]["equipment"]["slots"]["weapon"]["data"] == {"durability": 17.0})
	await _reload(2)
	tree = _node("glade_tree_1")
	check("loaded_tree_still_stump", tree.depleted and tree.regrow_day == 4 and _clock.get_day() == 2)
	check("loaded_tool_durability", DatabaseHelper.durability(_player.get_equipment(), &"weapon") == 17)
	var fires: Array[Campfire] = _campfires()
	check("loaded_campfire", fires.size() == 1 and fires[0].lit and absf(fires[0].fuel_minutes - 123.0) < 1.0,
		"%d %s" % [fires.size(), [fires[0].lit, fires[0].fuel_minutes] if not fires.is_empty() else []])
	# Ngày 3: chưa; 0:00 ngày 4: mọc lại.
	_clock.set_time(3, 12 * 60)
	await process_frame
	check("tree_not_regrown_day3", tree.depleted)
	_clock.set_time(3, 23 * 60 + 59)
	_clock.advance(2.0)
	await process_frame
	check("tree_regrows_day4", _clock.get_day() == 4 and not tree.depleted and not (tree.get_node("Available/Collision/Footprint0") as CollisionPolygon2D).disabled,
		"%d %s %s" % [_clock.get_day(), tree.depleted, (tree.get_node("Available/Collision/Footprint0") as CollisionPolygon2D).disabled])
	# Tải save khi đã quá ngày mọc lại: save ngày 2 nhưng đồng hồ lưu ở ngày 5 → mọc ngay sau khi tải.
	var edited: Dictionary = _saves.read_save(2)
	edited["global"]["clock"]["day"] = 5
	_saves.write_save(3, edited)
	await _reload(3)
	check("load_past_regrow_day", not _node("glade_tree_1").depleted and _clock.get_day() == 5)


## Tải slot và chờ áp xong; bind lại scene mới.
func _reload(slot: int) -> void:
	var done: Array[int] = []
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	_saves.load_game(slot)
	for i: int in 40:
		if not done.is_empty():
			break
		await process_frame
	_bind()
	await frames(2)
	_prepare()


# ---------------------------------------------------------------- 5. lửa trại, đuốc

func _test_campfire() -> void:
	var bag: Inventory = _bag()
	var lighting: DayNightLighting = _world.day_night
	var fire: Campfire = _campfires()[0]
	_clock.set_time(_clock.get_day(), 22 * 60)
	await frames(2)
	# Player ở xa: chỉ ánh lửa làm thấy được vùng quanh lửa; bán kính lửa > tầm nhìn có đèn lồng.
	_place(Vector2(36.0, 35.0))
	await frames(2)
	var near_fire: Vector2 = fire.global_position + Vector2(fire.get_light().radius * 0.4, 0)
	check("campfire_radius_bigger_than_lantern", fire.get_light().radius > lighting.settings.base_vision_radius + 96.0)
	check("campfire_lights_area", lighting.is_point_visible(near_fire) and fire.get_light().get_light().is_visible_in_tree()
		and fire.get_light().get_light().enabled and _player.global_position.distance_to(near_fire) > 300.0,
		"%.2f %s %s %.0f" % [lighting.get_visibility(near_fire), fire.get_light().get_light().is_visible_in_tree(), fire.get_light().get_light().enabled, _player.global_position.distance_to(near_fire)])
	# Chồng sáng không cháy trắng: MIX (không cộng dồn), màu đích ban đêm = màu lửa (≤ 1), không vượt mức ban ngày.
	var mixed: bool = true
	for node: Node in get_nodes_in_group(VisionLight.GROUP):
		var vl: VisionLight = node as VisionLight
		var target: Color = vl.get_light().color * vl.get_light().energy
		mixed = mixed and vl.get_light().blend_mode == Light2D.BLEND_MODE_MIX and maxf(target.r, maxf(target.g, target.b)) <= 1.0
	check("lights_mix_no_overexposure", mixed and fire.get_light().get_light().color.is_equal_approx(fire.get_light().color),
		"%s %s %s" % [mixed, fire.get_light().get_light().color, fire.get_light().color])
	# Hết giờ → tắt: ánh sáng tắt, còn lại ánh trăng; không nấu được; vẫn đứng đó.
	var burned: Array[bool] = []
	fire.lit_changed.connect(func(lit: bool) -> void: burned.append(lit))
	_clock.advance(fire.fuel_minutes + 1.0)
	check("campfire_burns_out", not fire.lit and burned == [false] and not fire.get_light().is_visible_in_tree()
		and is_equal_approx(lighting.get_visibility(near_fire), lighting.settings.moonlight) and is_instance_valid(fire)
		and not fire.is_station_active())
	# Thêm củi qua cửa sổ Nấu (E → nút "Thêm Gỗ") → nhóm lại.
	bag.clear()
	bag.add(&"wood", 1)
	await _stand_at(fire, Vector2(0, 22))
	check("campfire_prompt_unlit", _prompt().contains("Nhóm lửa"), _prompt())
	await _press_e()
	check("cook_locked_when_out", _window.is_open() and _window.get_craft_button(&"grilled_meat").disabled)
	await _click(_window.get_fuel_button(&"wood"))
	check("campfire_relit_by_wood", fire.lit and is_equal_approx(fire.fuel_minutes, 120.0) and not bag.has(&"wood")
		and fire.get_light().is_visible_in_tree(), _feedback())
	await tap_action(&"ui_cancel")
	# Thân va chạm: Player đi thẳng vào lửa thì bị chặn.
	_player.global_position = fire.global_position + Vector2(-40, 0)
	await frames(2)
	Input.action_press(&"move_right")
	await frames(40)
	Input.action_release(&"move_right")
	check("campfire_blocks_movement", _player.global_position.x < fire.global_position.x - 4.0, "%.1f vs %.1f" % [_player.global_position.x, fire.global_position.x])
	# Chỗ dựng không hợp lệ (trước mặt là thân cây) + giới hạn mỗi map.
	bag.add(&"campfire", 1)
	var tree: ResourceNode = _node("glade_tree_3")
	_player.global_position = tree.global_position + Vector2(0, -18)
	await frames(2)
	Input.action_press(&"move_down")
	await frames(1)
	Input.action_release(&"move_down")
	_player.global_position = tree.global_position + Vector2(0, -18)
	await frames(2)
	var reason: String = _world.use_item(_find(bag, &"campfire"))
	check("campfire_blocked_spot", reason == "Không đủ chỗ trống để dựng." and bag.has(&"campfire"), reason)
	var item: ItemDefinition = bag.database.get_item(&"campfire")
	for i: int in item.max_per_map - 1:
		_layer.spawn_deployed(item, IsoProjection.to_screen(16.0 + i, 31.5), 0)
	_place(ARENA)
	await frames(2)
	reason = _world.use_item(_find(bag, &"campfire"))
	check("campfire_limit_per_map", reason == "Đã đủ 8 lửa trại trên map này." and _campfires().size() == 8, reason)
	for extra: Campfire in _campfires():
		if extra != fire:
			extra.queue_free()
	await process_frame
	bag.clear()


func _test_torch() -> void:
	var lighting: DayNightLighting = _world.day_night
	var equipment: EquipmentSlots = _player.get_equipment()
	var bag: Inventory = _bag()
	_place(ARENA)
	bag.add(&"torch", 1)
	await _use_from_bag(&"torch")
	var torch: ItemDefinition = bag.database.get_item(&"torch")
	var base: float = lighting.settings.base_vision_radius
	check("torch_equipped_offhand", equipment.get_stack(&"offhand") != null and equipment.get_stack(&"offhand").item_id == &"torch")
	check("torch_radius_smaller_than_lantern", is_equal_approx(lighting.get_vision_radius(), base + torch.light_radius)
		and lighting.get_vision_radius() < base + 96.0, "%.0f" % lighting.get_vision_radius())
	_clock.advance(torch.burn_minutes - 1.0)
	check("torch_still_burning", equipment.get_stack(&"offhand") != null)
	_clock.advance(2.0)
	check("torch_burned_out", equipment.get_stack(&"offhand") == null and is_equal_approx(lighting.get_vision_radius(), base)
		and _feedback() == "Đuốc đã cháy hết.", _feedback())


# ---------------------------------------------------------------- 0. túi đồ khi chết

func _test_death_bags() -> void:
	var bag: Inventory = _bag()
	var health: HealthComponent = _player.get_health()
	_place(ARENA)
	await frames(2)
	for old: DeathBag in _layer.get_death_bags():
		_layer.remove_death_bag(old)
	var ids: Array[String] = []
	var discarded: Array[String] = []
	var discard_message: String = ""
	_world.death_controller.bag_discarded.connect(func(bag_id: String) -> void: discarded.append(bag_id))
	for i: int in 6:
		bag.add(&"wood", i + 1)
		var respawned: Array[DeathBag] = []
		_world.death_controller.player_respawned.connect(func(b: DeathBag) -> void: respawned.append(b), CONNECT_ONE_SHOT)
		health.apply_damage(health.max_health)
		for f: int in 20:
			if not respawned.is_empty():
				break
			await process_frame
		ids.append(respawned[0].bag_id if not respawned.is_empty() and respawned[0] != null else "")
		if i == 5:
			discard_message = _feedback()
		_place(ARENA)
		await process_frame
	var bags: Array[DeathBag] = _layer.get_death_bags()
	var remaining: Array[String] = []
	for b: DeathBag in bags:
		remaining.append(b.bag_id)
	check("max_5_death_bags", bags.size() == 5 and not remaining.has(ids[0]) and remaining.has(ids[5]), str(remaining))
	check("oldest_bag_discarded", discarded == [ids[0]], str(discarded))
	check("oldest_bag_message", discard_message == "Túi đồ cũ nhất đã biến mất (tối đa 5 túi).", discard_message)
	# Nhặt hết một túi → túi rỗng biến mất ngay; save không còn túi đó.
	var first: DeathBag = bags[0]
	_player.global_position = first.global_position + Vector2(0, 16)
	await frames(4)
	if _world.interaction_detector.get_target() == first:
		await _press_e()
	else:
		first.interact(_player)
	await process_frame
	check("empty_bag_removed", not is_instance_valid(first) or first.is_queued_for_deletion())
	check("empty_bag_not_saved", _saves.save_game(4) and (_saves.read_save(4)["maps"]["glade"]["world_items"]["death_bags"] as Array).size() == 4)
	# Save có túi rỗng (dữ liệu cũ) → không xuất hiện khi tải.
	var data: Dictionary = _saves.read_save(4)
	(data["maps"]["glade"]["world_items"]["death_bags"] as Array).append({"id": "empty_bag", "position": [0.0, 900.0], "tier": 0,
		"inventory": {"version": 1, "size": 24, "slots": []}})
	_saves.write_save(4, data)
	await _reload(4)
	var loaded_ids: Array[String] = []
	for b: DeathBag in _layer.get_death_bags():
		loaded_ids.append(b.bag_id)
	check("empty_bag_dropped_on_load", loaded_ids.size() == 4 and not loaded_ids.has("empty_bag"), str(loaded_ids))
	_player.get_health().reset()


# ---------------------------------------------------------------- 6. save cũ

func _test_load_old_saves() -> void:
	# Save v2 (M2): có lều, túi đồ rơi, chỉ số sinh tồn; chưa có node tài nguyên / lửa trại / độ bền.
	var tent_at: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	var v2: Dictionary = {"schema_version": 2, "saved_at": "2026-10-20 17:00:00", "playtime": 300.0, "map_id": "glade",
		"global": {"clock": {"version": 1, "day": 3, "minute": 600.0},
			"player": {"position": [tent_at.x, tent_at.y + 20.0], "tier": 0, "health": 80,
				"equipment": {"version": 1, "slots": {"weapon": {"id": "test_sword", "count": 1}}},
				"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "bread", "count": 2}]},
				"survival": {"mana": 50.0, "stamina": 60.0, "hunger": 70.0, "respawn": {}}}},
		"maps": {"glade": {"world_items": {"version": 2, "collected": [], "dropped": [], "death_bags": [],
			"deployed": [{"item_id": "tent", "id": "tent_old", "position": [tent_at.x, tent_at.y], "tier": 0}]}}}}
	var file: FileAccess = FileAccess.open(_saves.get_slot_path(5), FileAccess.WRITE)
	file.store_string(JSON.stringify(v2))
	file.close()
	await _reload(5)
	check("load_v2_ok", _clock.get_day() == 3 and _bag().count_of(&"bread") == 2 and absf(_player.get_hunger().value - 70.0) < 0.5
		and _layer.get_deployed().size() == 1 and (_layer.get_deployed()[0] as Tent).spot_id == "tent_old",
		"%d %d %.1f %d %s" % [_clock.get_day(), _bag().count_of(&"bread"), _player.get_hunger().value, _layer.get_deployed().size(), _layer.get_deployed()[0].get(&"spot_id") if not _layer.get_deployed().is_empty() else ""])
	var all_full: bool = true
	for node: ResourceNode in _resources.get_nodes():
		all_full = all_full and not node.depleted
	check("load_v2_nodes_full", all_full)
	check("load_v2_resave_v3", _saves.save_game(5) and int(_saves.read_save(5)["schema_version"]) == 3)
	# Save v1 (M1).
	var v1: Dictionary = {"schema_version": 1, "saved_at": "2026-10-20 00:17:07", "playtime": 12.0, "map_id": "glade",
		"global": {"player": {"position": [tent_at.x, tent_at.y], "tier": 0, "health": 90,
			"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "wood", "count": 5}]}}},
		"maps": {"glade": {"world_items": {"version": 1, "collected": ["glade_wood_1"], "dropped": []}}}}
	file = FileAccess.open(_saves.get_slot_path(6), FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	await _reload(6)
	check("load_v1_ok", _bag().count_of(&"wood") == 5 and _clock.get_day() == 1 and _resources.get_nodes().size() == 15
		and _player.get_health().current_health == 90)


## Đọc độ bền (tiện cho test).
class DatabaseHelper:
	static func durability(equipment: EquipmentSlots, slot_name: StringName) -> int:
		var stack: ItemStack = equipment.get_stack(slot_name)
		var item: ItemDefinition = equipment.get_item(slot_name)
		return item.durability_of(stack) if item != null else -1
