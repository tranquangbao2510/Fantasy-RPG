extends SceneTree
## Chơi thử vòng lặp trồng trọt bằng GAME THẬT có cửa sổ (TASK M6, mục 0): mở màn hình tiêu đề → Chơi mới (ô 1) → đi bộ
## (giữ phím di chuyển thật), E, C + click, I + rê chuột + F, ngủ ở giường... — mọi bước gửi input thật qua
## Input.parse_input_event (bot tự lái, không gọi thẳng hàm gameplay), chụp ảnh từng bước vào docs/reports/M6/.
## Để rút ngắn: cho sẵn nguyên liệu chế cuốc / bình tưới / cối đá / lửa trại + 4 hạt lúa (ghi rõ trong báo cáo), tua giờ bằng
## phím debug F8 (+1 giờ). Cài đặt + save dùng file riêng (user://playtest_*), không đụng dữ liệu thật.
## Chạy CÓ CỬA SỔ từ thư mục gốc project:
##   Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/playtest/farming_playtest.gd --resolution 1152x648

const OUT_DIR: String = "res://docs/reports/M6/"
const SAVE_DIR: String = "user://playtest_saves/"
const SETTINGS_PATH: String = "user://playtest_settings.cfg"
const STEP_FRAMES: int = 2

var _world: Node
var _player: Player
var _log: PackedStringArray = PackedStringArray()
var _shot_index: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSettings.config_path = SETTINGS_PATH
	DirAccess.remove_absolute(SETTINGS_PATH)
	GameSettings.reset_instance()
	# Bot chạy trong lúc cửa sổ có thể mất focus (terminal) — tắt tự tạm dừng để bước đi không bị đứng.
	GameSettings.get_instance().set_value(&"pause_on_focus_loss", false)
	var saves: Node = root.get_node(^"SaveService")
	saves.set(&"save_dir", SAVE_DIR)
	_clear(SAVE_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	change_scene_to_file("res://app/main.tscn")
	await _frames(20)
	await _shot("title", "Màn hình tiêu đề (chưa có save → không có nút Tiếp tục)")
	await _click(MenuUI.find_button(current_scene, "Chơi mới"))
	await _shot("new_game_slots", "Chơi mới → chọn ô save")
	await _click(MenuUI.find_button(current_scene.find_child("Slot1", true, false), "Chơi mới ở ô này"))
	await _wait(func() -> bool: return current_scene != null and str(current_scene.get(&"map_id")) == "glade" and not AppOverlay.is_transitioning(), 600)
	await _frames(20)
	_world = current_scene
	_player = _world.get(&"player") as Player
	(_world.get(&"enemy_spawner") as EnemySpawner).enabled = false
	await _shot("start_hints", "Lần đầu chơi mới: bảng gợi ý phím (game tạm dừng)")
	await _click(MenuUI.find_button(current_scene, "Đã hiểu"))
	# Nguyên liệu cho sẵn (rút ngắn khâu lượm nhặt — đã kiểm ở M3).
	var bag: Inventory = _player.get_inventory()
	for entry: Array in [[&"branch", 2], [&"stone", 8], [&"fiber", 4], [&"wood", 5], [&"wheat_seed", 4], [&"campfire", 1], [&"grilled_meat", 4]]:
		bag.add(entry[0], entry[1])
	_note("Cho sẵn: 2 cành, 8 đá, 4 sợi, 5 gỗ, 4 hạt lúa mì, 1 lửa trại, 4 thịt nướng (ăn mỗi sáng — tua giờ bằng F8 vẫn trừ đói).")
	var field: FarmField = (_world.get(&"farm_layer") as FarmLayer).find_field("glade_home")
	await _shot("glade_field", "Ruộng mới 6 × 4 ô lưới thật cạnh nhà tạm (giường + bàn chế tạo dời xuống phía nam)")
	# 1. Chế cuốc, bình tưới, cối đá ở bàn chế tạo.
	var bench: Node2D = _world.get_node(^"EntityContainer/Workbench") as Node2D
	await _walk_to(bench.global_position + Vector2(0, 22))
	await _tap(&"interact")
	var window: CraftingWindow = _world.get(&"crafting_window") as CraftingWindow
	for recipe: StringName in [&"stone_hoe", &"watering_can", &"stone_mill"]:
		var button: Button = window.get_craft_button(recipe)
		if button != null and not button.disabled:
			await _click(button)
		else:
			_note("Không chế được %s ở bàn (nút %s)." % [recipe, "khóa" if button != null else "không có"])
	await _shot("crafting", "E ở bàn chế tạo → chế cuốc đất, bình tưới, cối đá")
	await _tap(&"craft_toggle")
	# 2. Trang bị cuốc (I → rê chuột lên ô → F), cày 4 ô.
	await _use_from_bag(&"stone_hoe", "inventory_hoe")
	var plots: Array[FarmPlot] = [field.get_plot(Vector2i(1, 1)), field.get_plot(Vector2i(2, 1)), field.get_plot(Vector2i(3, 1)), field.get_plot(Vector2i(4, 1))]
	for plot: FarmPlot in plots:
		await _walk_to(plot.global_position)
		await _tap(&"interact")
	await _shot("tilled", "Cày 4 ô (E khi cầm cuốc, đứng trên ô)")
	# 3. Gieo: túi có 2 loại hạt (lúa mì + quả mọng) → ô đầu hiện menu chọn (↓ + Enter), các ô sau E gieo luôn.
	for plot: FarmPlot in plots:
		await _walk_to(plot.global_position)
		await _tap(&"interact")
		var seed_menu: PopupMenu = _world.get(&"_seed_menu") as PopupMenu
		if seed_menu != null and seed_menu.visible:
			await _shot("seed_menu", "E trên đất cày khi túi có nhiều loại hạt → menu chọn hạt cạnh con trỏ")
			await _tap_key(KEY_DOWN)
			await _tap_key(KEY_ENTER)
	await _shot("planted", "Gieo hạt lúa mì (E trên đất đã cày)")
	_note("Đã cày %d / 4 ô, gieo %d / 4 ô." % [plots.filter(func(p: FarmPlot) -> bool: return p.tilled).size(),
		plots.filter(func(p: FarmPlot) -> bool: return p.has_crop()).size()])
	# 4. Bình tưới: múc nước ở mép suối, tưới, ngủ — 3 đêm.
	await _use_from_bag(&"watering_can", "")
	var source: Node2D = _world.get_node(^"EntityContainer/WaterSource1") as Node2D
	for night: int in 3:
		await _walk_to(source.global_position + Vector2(0, 16))
		# E có thể trúng bụi cỏ sát mép suối trước (ưu tiên tương tác gần nhất) → nhấn lại tới khi bình đầy.
		for attempt: int in 4:
			await _tap(&"interact")
			if _water_left() > 0:
				break
			_note("Đêm %d: E lần %d ở mép suối không múc nước (%s)." % [night + 1, attempt + 1, _feedback()])
		if night == 0:
			await _shot("fill_water", "Múc nước ở mép suối (E khi cầm bình tưới)")
		for plot: FarmPlot in plots:
			await _walk_to(plot.global_position)
			await _tap(&"interact")
		_note("Đêm %d: tưới %d / 4 ô." % [night + 1, plots.filter(func(p: FarmPlot) -> bool: return p.is_wet()).size()])
		if night == 0:
			await _shot("watered", "Tưới: đất ướt sẫm màu tới hết ngày")
		await _sleep_in_bed()
		await _use_from_bag(&"grilled_meat", "")
		await _walk_to(field.get_plot(Vector2i(2, 2)).global_position)
		await _shot("morning_%d" % (night + 1), "Sáng ngày %d: cây được tưới hôm trước lớn thêm 1 ngày" % _clock().get_day())
	_note("Sau 3 đêm: tuổi cây %s." % str(plots.map(func(p: FarmPlot) -> int: return p.age)))
	# 5. Thu hoạch.
	for plot: FarmPlot in plots:
		await _walk_to(plot.global_position)
		await _tap(&"interact")
	await _shot("harvested", "Thu hoạch (E): lúa mì + hạt vào túi")
	_note("Thu được %d lúa mì, %d hạt." % [bag.count_of(&"wheat"), bag.count_of(&"wheat_seed")])
	# 6. Cối đá trong nhà, xay bột.
	var bed: Node2D = _world.get_node(^"EntityContainer/Bed") as Node2D
	await _walk_to(bed.global_position + Vector2(56, 6))
	await _use_from_bag(&"stone_mill", "")
	var mill: Node2D = null
	for node: Node in (_world.get(&"pickup_layer") as ItemPickupLayer).get_deployed():
		if node is StoneMill:
			mill = node as Node2D
	if mill == null:
		_note("Không đặt được cối đá: %s" % _feedback())
	else:
		await _walk_to(mill.global_position + Vector2(0, 22))
		await _tap(&"interact")
		var flour: Button = window.get_craft_button(&"flour")
		var milled: int = 0
		while flour != null and not flour.disabled and milled < 3:
			await _click(flour)
			milled += 1
			flour = window.get_craft_button(&"flour")
		await _shot("mill", "Cối đá cạnh giường: xay 3 lúa → 1 bột")
		await _tap(&"craft_toggle")
	# 7. Lửa trại: nướng bánh, ăn.
	# Bãi đất trống chỗ xuất phát (ô ruộng là vùng tương tác nên không dựng sát ruộng được).
	await _walk_to(Vector2(-150, 905))
	await _use_from_bag(&"campfire", "")
	var fire: Node2D = null
	for node: Node in (_world.get(&"pickup_layer") as ItemPickupLayer).get_deployed():
		if node is Campfire:
			fire = node as Node2D
	if fire != null:
		await _walk_to(fire.global_position + Vector2(0, 26))
		await _tap(&"interact")
		var bake: Button = window.get_craft_button(&"bread")
		if bake != null and not bake.disabled:
			await _click(bake)
		await _shot("bread", "Lửa trại: nướng bánh mì từ bột")
		await _tap(&"craft_toggle")
	else:
		_note("Không dựng được lửa trại: %s" % _feedback())
	_player.get_hunger().load_value(50.0)
	await _use_from_bag(&"bread", "")
	_note("Đói sau khi ăn bánh: %.0f / 100 (trước 50)." % _player.get_hunger().value)
	await _shot("ate", "Ăn bánh mì (+30 đói)")
	# 8. Menu tạm dừng, lưu, tải, hướng dẫn phím, cài đặt.
	await _tap_key(KEY_ESCAPE)
	await _shot("pause_menu", "Esc: menu tạm dừng (game dừng thật)")
	var menu: Node = _world.get(&"pause_menu")
	await _click(menu.call(&"get_button", "Lưu") as Button)
	await _shot("save_slots", "Lưu → chọn ô (ô 1 đang chơi, đã có bản tự lưu khi ngủ)")
	await _click(MenuUI.find_button(menu.find_child("Slot1", true, false), "Lưu vào ô này"))
	await _shot("saved", "Lưu xong → quay lại menu tạm dừng, báo \"Đã lưu vào ô 1\"")
	await _click(menu.call(&"get_button", "Tải") as Button)
	await _shot("load_slots", "Tải game: mỗi ô có bản thủ công + bản tự lưu, ảnh nhỏ, ngày / giờ game, thời gian chơi, giờ lưu, map")
	await _tap_key(KEY_ESCAPE)
	await _click(menu.call(&"get_button", "Hướng dẫn phím") as Button)
	await _shot("key_guide", "Hướng dẫn phím (đọc InputMap, chia nhóm)")
	await _tap_key(KEY_ESCAPE)
	await _click(menu.call(&"get_button", "Cài đặt") as Button)
	await _shot("settings_audio", "Cài đặt → Âm thanh")
	var settings: Node = menu.call(&"get_subpanel")
	settings.call(&"show_tab", 1)
	await _shot("settings_display", "Cài đặt → Hình ảnh")
	settings.call(&"show_tab", 3)
	await _shot("settings_controls", "Cài đặt → Điều khiển (đổi phím)")
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_ESCAPE)
	# Đêm: độ sáng ban đêm mặc định.
	await _walk_to(field.get_plot(Vector2i(2, 2)).global_position)
	_clock().set_time(_clock().get_day(), 23 * 60)
	await _shot("night_field", "Ruộng ban đêm (ánh trăng mặc định 16 %)")
	var file: FileAccess = FileAccess.open(ProjectSettings.globalize_path(OUT_DIR).path_join("playtest_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(_log) + "\n")
	file.close()
	print("\n".join(_log))
	quit()


# --- Lái bot bằng input thật ------------------------------------------------------------------

func _clock() -> GameClock:
	return _world.get(&"clock") as GameClock


func _water_left() -> int:
	var equipment: EquipmentSlots = _player.get_equipment()
	var item: ItemDefinition = equipment.get_item(&"weapon")
	return item.water_of(equipment.get_stack(&"weapon")) if item != null else -1


func _feedback() -> String:
	return (_world.get_node(^"UILayer/InteractionFeedback/Label") as Label).text


func _note(text: String) -> void:
	_log.append(text)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _wait(condition: Callable, max_frames: int) -> bool:
	for i: int in max_frames:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


func _tap(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(STEP_FRAMES)
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(STEP_FRAMES + 4)


func _tap_key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames(STEP_FRAMES + 2)


func _mouse_to(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await _frames(2)


func _click(control: Control) -> void:
	if control == null:
		_note("Không tìm thấy nút để click.")
		return
	var at: Vector2 = root.get_final_transform() * control.get_global_rect().get_center()
	await _mouse_to(at)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


## Đi tới đích theo đường navmesh tầng 0 (cùng navmesh quái dùng) — mỗi chặng giữ phím di chuyển thật (8 hướng).
func _walk_to(target: Vector2) -> void:
	var map: RID = _world.get_world_2d().navigation_map
	var path: PackedVector2Array = NavigationServer2D.map_get_path(map, _player.global_position, target, true, TierNavigation.layer_for_tier(0))
	for i: int in range(1, path.size() - 1):
		await _walk_straight(path[i], 10.0)
	# Đích nằm trong vật cản (mép nước…) → dừng ở điểm gần nhất navmesh trả về.
	await _walk_straight(path[path.size() - 1] if not path.is_empty() else target, 6.0)


## Giữ phím di chuyển hướng về điểm (8 hướng) tới khi tới nơi; kẹt quá lâu thì ghi lại.
func _walk_straight(target: Vector2, reach: float) -> void:
	var stuck_frames: int = 0
	var last: Vector2 = _player.global_position
	for frame: int in 900:
		var delta: Vector2 = target - _player.global_position
		if delta.length() < reach:
			break
		_set_move(&"move_right", delta.x > 3.0)
		_set_move(&"move_left", delta.x < -3.0)
		_set_move(&"move_down", delta.y > 2.0)
		_set_move(&"move_up", delta.y < -2.0)
		await physics_frame
		if _player.global_position.distance_to(last) < 0.2:
			stuck_frames += 1
			if stuck_frames > 60:
				_note("Bot kẹt khi đi tới %s (đang ở %s)." % [target.round(), _player.global_position.round()])
				break
		else:
			stuck_frames = 0
		last = _player.global_position
	for action: StringName in [&"move_right", &"move_left", &"move_down", &"move_up"]:
		_set_move(action, false)
	await _frames(4)


func _set_move(action: StringName, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)


## I → rê chuột lên ô chứa item → F (dùng / trang bị / dựng) → I.
func _use_from_bag(item_id: StringName, shot_name: String) -> void:
	var window: InventoryWindow = _world.get(&"inventory_window") as InventoryWindow
	await _tap(&"inventory_toggle")
	window.refresh_now()
	await _frames(2)
	var bag: Inventory = _player.get_inventory()
	var slot: int = -1
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			slot = i
			break
	if slot < 0:
		_note("Không có %s trong túi." % item_id)
		await _tap(&"inventory_toggle")
		return
	await _mouse_to(root.get_final_transform() * window.get_bag_view(slot).get_global_rect().get_center())
	if not shot_name.is_empty():
		await _shot(shot_name, "I: túi đồ → rê chuột lên %s → F (trang bị)" % item_id)
	await _tap(&"item_use")
	await _tap(&"inventory_toggle")


func _sleep_in_bed() -> void:
	while _clock().get_hour() < 20 and _clock().get_hour() >= 6:
		await _tap_key(KEY_F8)
	var bed: Node2D = _world.get_node(^"EntityContainer/Bed") as Node2D
	await _walk_to(bed.global_position + Vector2(0, 16))
	await _tap(&"interact")
	var sleep: SleepController = _world.get(&"sleep_controller") as SleepController
	await _wait(func() -> bool: return not sleep.is_busy(), 900)
	await _frames(10)
	if _clock().get_hour() != 6:
		_note("Ngủ không thành công: %s" % _feedback())


func _shot(name: String, caption: String) -> void:
	await _frames(8)
	_shot_index += 1
	var file_name: String = "%02d_%s.jpg" % [_shot_index, name]
	root.get_texture().get_image().save_jpg(ProjectSettings.globalize_path(OUT_DIR).path_join(file_name), 0.85)
	_log.append("[%s] %s" % [file_name, caption])


func _clear(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_clear(dir_path.path_join(sub))
		dir.remove(sub)
	for file: String in dir.get_files():
		dir.remove(file)
