extends "res://tests/test_base.gd"
## Kiểm thử TASK M6 — khung game: màn hình tiêu đề, menu tạm dừng (Esc), 3 ô save + tự lưu + metadata, chuyển save đơn cũ
## (v1–v5) thành ô 1, ruộng nửa ô → lưới mới (không mất đồ), Cài đặt (lưu / đọc lại), đổi phím (dùng ngay, HUD đổi theo,
## trùng phím → hoán đổi, lưu qua lần mở game sau, khôi phục mặc định), hướng dẫn phím, tự tạm dừng khi mất focus, cảnh báo
## tiến trình chưa lưu, chuyển cảnh chặn input, bản release (giả lập) không có phím debug.
## Đi qua input thật (phím Esc / E / F..., Input.parse_input_event; click chuột lên nút) khi có thể.
## Script test biên dịch trước Autoload: không dùng tên các lớp có dùng SaveService (World, PauseMenu, SaveSlotList,
## SettingsPanel, KeyGuidePanel, StartHintsPanel) làm kiểu — truy cập động.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/app/test_app_shell.gd

const TITLE_PATH: String = "res://app/main.tscn"
const GLADE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const TEST_DIR: String = "user://test_saves_m6/"
const ARENA: Vector2 = Vector2(22.0, 35.0)
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")

var _saves: SaveServiceScript
var _world: Node
var _player: Player
var _clock: GameClock


func _run_tests() -> void:
	_saves = root.get_node("SaveService") as SaveServiceScript
	_saves.save_dir = TEST_DIR
	clear_dir(TEST_DIR)
	await _test_title_and_new_game()
	await _test_pause_freezes_world()
	await _test_esc_closes_panels_first()
	await _test_focus_loss_pause()
	await _test_save_blocked_when_chased()
	await _test_slots()
	await _test_back_to_title_and_continue()
	await _test_legacy_saves_become_slot_1()
	await _test_half_grid_farm_migration()
	await _test_rebinding()
	await _test_settings_persist()
	await _test_release_has_no_debug_keys()
	await _test_quit_warning()
	await _test_transition_blocks_input()
	clear_dir(TEST_DIR)


# ---------------------------------------------------------------- tiện ích

func _key(keycode: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _tap_key(keycode: Key) -> void:
	_key(keycode, true)
	await process_frame
	_key(keycode, false)
	await process_frame


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
	await process_frame


func _button(scope: Node, text: String) -> Button:
	return MenuUI.find_button(scope, text) if scope != null else null


func _confirm_box() -> ConfirmBox:
	for node: Node in root.find_children("ConfirmBox*", "ConfirmBox", true, false):
		if not node.is_queued_for_deletion():
			return node as ConfirmBox
	return null


## Trả lời hộp xác nhận đang mở bằng click.
func _answer(yes_text: String) -> bool:
	var box: ConfirmBox = _confirm_box()
	if box == null:
		return false
	var button: Button = _button(box, yes_text)
	if button == null:
		return false
	await _click(button)
	return true


func _wait_until(condition: Callable, max_frames: int = 240) -> bool:
	for i: int in max_frames:
		if condition.call():
			return true
		await process_frame
	return bool(condition.call())


## Chờ AppOverlay chuyển cảnh xong.
func _wait_transition() -> void:
	await _wait_until(func() -> bool: return not AppOverlay.is_transitioning() and current_scene != null)
	await frames(3)


func _open_glade() -> void:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	var scene: Node = (load(GLADE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(4)
	_bind()
	_prepare()


func _bind() -> void:
	_world = current_scene
	_player = _world.get(&"player") as Player
	_clock = _world.get(&"clock") as GameClock


func _prepare() -> void:
	if _world == null or _clock == null:
		return
	var sleep: SleepController = _world.get(&"sleep_controller") as SleepController
	sleep.settings.fade_time = 0.0
	sleep.settings.title_time = 0.0
	sleep.settings.faint_hour = 99
	var enemy: Node2D = _world.get_node_or_null("EntityContainer/SimpleEnemy") as Node2D
	if enemy != null:
		enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	(_world.get(&"enemy_spawner") as EnemySpawner).enabled = false
	for pickup: ItemPickup in (_world.get(&"pickup_layer") as ItemPickupLayer).get_pickups():
		pickup.queue_free()


func _place(grid: Vector2) -> void:
	_player.global_position = IsoProjection.to_screen(grid.x, grid.y)
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(3)


func _pause_menu() -> Control:
	return _world.get(&"pause_menu") as Control


func _feedback() -> String:
	return (_world.get_node("UILayer/InteractionFeedback/Label") as Label).text


func _clear_enemies() -> void:
	for node: Node in get_nodes_in_group(&"enemies"):
		if node is Enemy and node != _world.get_node_or_null("EntityContainer/SimpleEnemy"):
			node.queue_free()
	await frames(2)


func _meta(slot: int) -> Dictionary:
	return _saves.read_meta(slot)


# ---------------------------------------------------------------- 1. màn hình tiêu đề + chơi mới

func _test_title_and_new_game() -> void:
	var title: Node = (load(TITLE_PATH) as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title
	await frames(3)
	var menu: Control = title.call(&"get_menu") as Control
	var continue_button: Button = _button(menu, "Tiếp tục")
	check("title_is_main_scene", ProjectSettings.get_setting("application/run/main_scene") == TITLE_PATH)
	check("title_continue_hidden_without_save", continue_button != null and not continue_button.visible)
	check("title_buttons", _button(menu, "Chơi mới") != null and _button(menu, "Tải game") != null and _button(menu, "Cài đặt") != null
		and _button(menu, "Thoát") != null)
	check("title_has_background", (title.get_node("Background") as TextureRect).texture != null)
	var focused: Control = title.get_viewport().gui_get_focus_owner()
	check("title_keyboard_focus", focused != null and (focused as Button).text == "Chơi mới", str(focused))
	# Mũi tên xuống + Enter → "Tải game" mở danh sách ô; Esc đóng.
	await _tap_key(KEY_DOWN)
	focused = title.get_viewport().gui_get_focus_owner()
	check("title_arrow_moves_focus", focused != null and (focused as Button).text == "Tải game", str(focused))
	await _tap_key(KEY_ENTER)
	var list: Control = title.call(&"get_subpanel") as Control
	check("title_enter_opens_load_list", list != null and list.name == "SaveSlotList")
	await _tap_key(KEY_ESCAPE)
	check("title_esc_closes_subpanel", title.call(&"get_subpanel") == null and menu.visible)
	# Chơi mới → chọn ô 1 (trống, không hỏi) → vào Glade qua màn đen.
	await _click(_button(menu, "Chơi mới"))
	list = title.call(&"get_subpanel") as Control
	var start_button: Button = _button(list.get_node("Center").find_child("Slot1", true, false), "Chơi mới ở ô này")
	check("new_game_slot_list", list != null and start_button != null)
	await _click(start_button)
	await _wait_transition()
	_bind()
	check("new_game_enters_glade", str(current_scene.get(&"map_id")) == "glade" and _saves.current_slot == 1 and _player != null)
	var hints: Control = current_scene.find_child("StartHintsPanel", true, false) as Control
	check("start_hints_shown_and_paused", hints != null and hints.visible and paused, str(hints))
	if hints != null:
		await _click(hints.find_child("DontShowAgain", true, false) as Control)
		await _click(_button(hints, "Đã hiểu"))
	check("start_hints_closed_dont_show_again", not paused and current_scene.find_child("StartHintsPanel", true, false) == null
		and not bool(GameSettings.get_instance().get_value(&"show_start_hints")))
	_prepare()


# ---------------------------------------------------------------- 2. Esc tạm dừng thật

func _test_pause_freezes_world() -> void:
	await _place(ARENA)
	(_player.get_node("Hurtbox") as Hurtbox).set_invulnerable(9999.0)
	var database: ItemDatabase = _player.get_inventory().database
	_clock.running = true
	_clock.time_scale = 10.0
	_clock.set_time(_clock.get_day(), 22 * 60)
	# Quái đang đuổi, lửa trại, đuốc ở tay phụ, buff Ấm bụng, ruộng có cây được tưới hôm trước, đói.
	var spawner: EnemySpawner = _world.get(&"enemy_spawner") as EnemySpawner
	var wolves: Array[Enemy] = spawner.debug_spawn(&"night_wolf")
	var layer: ItemPickupLayer = _world.get(&"pickup_layer") as ItemPickupLayer
	var fire: Campfire = layer.spawn_deployed(database.get_item(&"campfire"), _player.global_position + Vector2(40, 30), 0) as Campfire
	_player.get_equipment().set_slot(&"offhand", ItemStack.new(&"torch", 1))
	_player.get_buffs().apply(database.find_buff(&"warm_meal"))
	await _wait_until(func() -> bool: return wolves.any(func(w: Enemy) -> bool: return is_instance_valid(w) and w.is_hunting()), 120)
	await seconds(0.2)
	var snapshot: Callable = func() -> Dictionary:
		var torch: ItemStack = _player.get_equipment().get_stack(&"offhand")
		return {"minutes": _clock.total_minutes, "wolf": wolves[0].global_position if is_instance_valid(wolves[0]) else Vector2.ZERO,
			"hunger": _player.get_hunger().value, "fire": fire.fuel_minutes,
			"torch": database.get_item(&"torch").fuel_of(torch) if torch != null else -1.0,
			"buff": _player.get_buffs().get_time_left(&"warm_meal")}
	# Esc thật (cả pause_menu lẫn ui_cancel) → menu tạm dừng.
	await _tap_key(KEY_ESCAPE)
	var menu: Control = _pause_menu()
	check("esc_opens_pause_menu", menu != null and menu.visible and paused)
	var before: Dictionary = snapshot.call()
	await seconds(1.0)
	var during: Dictionary = snapshot.call()
	var frozen: bool = true
	for key: String in before:
		frozen = frozen and before[key] == during[key]
	check("pause_freezes_clock_enemy_hunger_fire_torch_buff", frozen, "%s → %s" % [before, during])
	await _tap_key(KEY_ESCAPE)
	check("esc_resumes", not menu.visible and not paused)
	var resume_started: Dictionary = snapshot.call()
	await seconds(1.0)
	var after: Dictionary = snapshot.call()
	# 1 s thật × 10 (time_scale) × 1.2 phút game / s = ~12 phút game; không nhảy bù thời gian đã dừng.
	var passed: float = after["minutes"] - resume_started["minutes"]
	check("resume_clock_runs_normally", passed > 6.0 and passed < 18.0, "%.2f phút game" % passed)
	check("resume_world_runs", after["hunger"] < resume_started["hunger"] and after["fire"] < resume_started["fire"]
		and after["torch"] < resume_started["torch"] and after["buff"] < resume_started["buff"]
		and (after["wolf"] as Vector2).distance_to(resume_started["wolf"]) > 1.0, "%s → %s" % [resume_started, after])
	# Cây: 5:59 + tạm dừng → không qua 6:00, không lớn; tiếp tục → lớn đúng 1 ngày.
	await _clear_enemies()
	fire.queue_free()
	_player.get_equipment().set_slot(&"offhand", null)
	var farms: FarmLayer = _world.get(&"farm_layer") as FarmLayer
	var plot: FarmPlot = farms.get_plots()[0]
	plot.load_plot_state({"state": "planted", "crop": "wheat", "age": 0, "watered_day": _clock.get_day()}, farms.crop_book)
	_clock.time_scale = 1.0
	_clock.set_time(_clock.get_day() + 1, 5 * 60 + 59)
	farms.catch_up()
	await _tap_key(KEY_ESCAPE)
	await seconds(1.2)
	check("pause_crop_not_growing", plot.age == 0 and _clock.get_minute_of_day() < 360.0, "tuổi %d · %s" % [plot.age, _clock.format_time()])
	await _tap_key(KEY_ESCAPE)
	await _wait_until(func() -> bool: return plot.age == 1, 180)
	check("resume_crop_grows_one_day", plot.age == 1, "tuổi %d" % plot.age)
	_clock.running = false
	_player.get_buffs().clear()


# ---------------------------------------------------------------- 3. Esc đóng cửa sổ trước

func _test_esc_closes_panels_first() -> void:
	var inventory: InventoryWindow = _world.get(&"inventory_window") as InventoryWindow
	await tap_action(&"inventory_toggle")
	check("inventory_open_not_paused", inventory.is_open() and not paused)
	await _tap_key(KEY_ESCAPE)
	check("esc_closes_inventory_first", not inventory.is_open() and not _pause_menu().visible and not paused)
	var crafting: CraftingWindow = _world.get(&"crafting_window") as CraftingWindow
	await tap_action(&"craft_toggle")
	await _tap_key(KEY_ESCAPE)
	check("esc_closes_crafting_first", not crafting.is_open() and not _pause_menu().visible)
	# Hộp xác nhận trong menu: Esc đóng hộp, menu vẫn mở; Esc nữa → tiếp tục chơi.
	await _tap_key(KEY_ESCAPE)
	await _click(_pause_menu().call(&"get_button", "Về màn hình chính") as Button)
	var box: ConfirmBox = _confirm_box()
	check("unsaved_warning_on_title", box != null and box.get_message().contains("chưa lưu"))
	await _tap_key(KEY_ESCAPE)
	check("esc_closes_confirm_first", _confirm_box() == null and _pause_menu().visible and paused)
	await _tap_key(KEY_ESCAPE)
	check("esc_then_resumes", not _pause_menu().visible and not paused)


# ---------------------------------------------------------------- 4. mất focus

func _test_focus_loss_pause() -> void:
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check("focus_out_pauses", _pause_menu().visible and paused)
	await _tap_key(KEY_ESCAPE)
	GameSettings.get_instance().set_value(&"pause_on_focus_loss", false)
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await process_frame
	check("focus_out_option_off", not _pause_menu().visible and not paused)
	GameSettings.get_instance().set_value(&"pause_on_focus_loss", true)


# ---------------------------------------------------------------- 5. không lưu khi bị truy đuổi

func _test_save_blocked_when_chased() -> void:
	await _place(ARENA)
	_clock.set_time(_clock.get_day(), 22 * 60)
	# Đứng yên thì quái chỉ thấy trong 0.5 × tầm phát hiện → cầm đuốc (× 1.5) cho chắc bị phát hiện.
	_player.get_equipment().set_slot(&"offhand", ItemStack.new(&"torch", 1))
	var wolves: Array[Enemy] = (_world.get(&"enemy_spawner") as EnemySpawner).debug_spawn(&"night_wolf")
	var hunting: bool = await _wait_until(func() -> bool: return wolves.any(func(w: Enemy) -> bool: return is_instance_valid(w) and w.is_hunting()), 120)
	await _tap_key(KEY_ESCAPE)
	var menu: Control = _pause_menu()
	await _click(menu.call(&"get_button", "Lưu") as Button)
	check("save_blocked_when_chased", hunting and str(menu.call(&"get_status_text")) == "Không thể lưu khi đang bị truy đuổi"
		and menu.call(&"get_subpanel") == null and not _saves.has_save(1), "%s hunting=%s reason=%s wolves=%d" % [menu.call(&"get_status_text"), hunting, _world.call(&"get_save_block_reason"), wolves.size()])
	check("quick_save_blocked_when_chased", str(_world.call(&"get_save_block_reason")) == "Không thể lưu khi đang bị truy đuổi")
	await _tap_key(KEY_ESCAPE)
	await _clear_enemies()
	_player.get_equipment().set_slot(&"offhand", null)
	# Đang đi giữa hai tầng (cầu thang) → cũng không lưu.
	check("save_ok_when_safe", str(_world.call(&"get_save_block_reason")) == "")
	_clock.set_time(_clock.get_day(), 10 * 60)


# ---------------------------------------------------------------- 6. 3 ô save + tự lưu + metadata

func _save_via_menu(slot: int, overwrite: bool = false) -> bool:
	await _tap_key(KEY_ESCAPE)
	var menu: Control = _pause_menu()
	await _click(menu.call(&"get_button", "Lưu") as Button)
	var list: Control = menu.call(&"get_subpanel") as Control
	if list == null:
		await _tap_key(KEY_ESCAPE)
		return false
	await _click(_button(list.find_child("Slot%d" % slot, true, false), "Lưu vào ô này"))
	if overwrite:
		var box: ConfirmBox = _confirm_box()
		check("overwrite_confirm_slot_%d" % slot, box != null and box.get_message().contains("Ghi đè"))
		await _answer("Ghi đè")
	var ok: bool = str(menu.call(&"get_status_text")) == "Đã lưu vào ô %d." % slot
	await _tap_key(KEY_ESCAPE)
	return ok


func _load_via_menu(slot: int, kind_button: String) -> bool:
	await _tap_key(KEY_ESCAPE)
	var menu: Control = _pause_menu()
	await _click(menu.call(&"get_button", "Tải") as Button)
	var list: Control = menu.call(&"get_subpanel") as Control
	var done: Array[int] = []
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	await _click(_button(list.find_child("Slot%d" % slot, true, false), kind_button))
	if _confirm_box() != null:
		await _answer("Tải")
	await _wait_until(func() -> bool: return not done.is_empty())
	await _wait_transition()
	_bind()
	_prepare()
	return done == [slot]


func _test_slots() -> void:
	clear_dir(TEST_DIR)
	_saves.save_dir = TEST_DIR
	await _place(ARENA)
	_clock.set_time(2, 9 * 60 + 30)
	_player.get_inventory().clear()
	_player.get_inventory().add(&"wood", 7)
	check("save_slot_2_via_menu", await _save_via_menu(2))
	var meta: Dictionary = _meta(2)
	var manual: Dictionary = meta.get("manual", {})
	check("meta_slot_2", int(manual.get("day", 0)) == 2 and int(manual.get("minute", 0)) == 570 and manual.get("map_name") == "Glade"
		and manual.get("map_id") == "glade" and not str(manual.get("saved_at")).is_empty() and float(manual.get("playtime", -1.0)) > 0.0
		and absf(float(manual.get("playtime")) - _saves.playtime) < 5.0 and not meta.has("autosave"), str(meta))
	check("meta_file_separate", FileAccess.file_exists(_saves.get_meta_path(2)) and FileAccess.file_exists(_saves.get_slot_path(2, &"manual")))
	# Ghi đè ô 2 (có xác nhận) ở ngày 3.
	_clock.set_time(3, 8 * 60)
	_player.get_inventory().add(&"wood", 1)
	check("overwrite_slot_2", await _save_via_menu(2, true) and int(_meta(2)["manual"]["day"]) == 3)
	# Ô 3: ngày 4, rồi ngủ ở giường → bản tự lưu của ô 3 (ô đang chơi).
	_clock.set_time(4, 21 * 60)
	_player.get_inventory().clear()
	_player.get_inventory().add(&"stone", 4)
	check("save_slot_3", await _save_via_menu(3))
	(_world.get(&"sleep_controller") as SleepController).autosave = true
	var bed: Node2D = _world.get_node("EntityContainer/Bed") as Node2D
	_player.global_position = bed.global_position + Vector2(0, 14)
	await frames(3)
	await tap_action(&"interact")
	await _wait_until(func() -> bool: return not (_world.get(&"sleep_controller") as SleepController).is_busy())
	meta = _meta(3)
	check("autosave_into_current_slot", meta.has("autosave") and int(meta["autosave"]["day"]) == 5 and int(meta["autosave"]["minute"]) == 360
		and int(meta["manual"]["day"]) == 4 and not _meta(2).has("autosave"), str(meta))
	check("three_slots_listed", _saves.list_slots().size() == 3 and (_saves.list_slots()[0]["manual"] as Dictionary).is_empty())
	check("latest_is_slot_3_autosave", _saves.latest_save() == {"slot": 3, "kind": &"autosave"}, str(_saves.latest_save()))
	# Danh sách đọc metadata, không đọc save: phá file save, danh sách vẫn đúng.
	var real: String = FileAccess.get_file_as_string(_saves.get_slot_path(3, &"manual"))
	var broken: FileAccess = FileAccess.open(_saves.get_slot_path(3, &"manual"), FileAccess.WRITE)
	broken.store_string("{ hỏng")
	broken.close()
	check("list_reads_meta_only", int(_saves.list_slots()[2]["manual"]["day"]) == 4)
	var fixed: FileAccess = FileAccess.open(_saves.get_slot_path(3, &"manual"), FileAccess.WRITE)
	fixed.store_string(real)
	fixed.close()
	# Tải ô 2 bản thủ công (đang có tiến trình chưa lưu → hỏi), rồi ô 3 bản tự lưu.
	_player.get_inventory().clear()
	check("load_slot_2_manual", await _load_via_menu(2, "Tải bản thủ công"))
	check("loaded_slot_2_state", _clock.get_day() == 3 and _player.get_inventory().count_of(&"wood") == 8 and _saves.current_slot == 2,
		"ngày %d gỗ %d" % [_clock.get_day(), _player.get_inventory().count_of(&"wood")])
	check("load_slot_3_autosave", await _load_via_menu(3, "Tải bản tự lưu"))
	check("loaded_slot_3_autosave_state", _clock.get_day() == 5 and absf(_clock.get_minute_of_day() - 360.0) < 1.0
		and _player.get_inventory().count_of(&"stone") == 4, "ngày %d %s đá %d" % [_clock.get_day(), _clock.format_time(), _player.get_inventory().count_of(&"stone")])
	# Xóa ô 2 (có xác nhận).
	await _tap_key(KEY_ESCAPE)
	await _click(_pause_menu().call(&"get_button", "Tải") as Button)
	var list: Control = _pause_menu().call(&"get_subpanel") as Control
	await _click(_button(list.find_child("Slot2", true, false), "Xóa ô"))
	var box: ConfirmBox = _confirm_box()
	check("delete_confirm", box != null and box.get_message().contains("ô 2"))
	await _answer("Xóa")
	check("slot_2_deleted", not _saves.has_save(2) and _meta(2).is_empty() and not DirAccess.dir_exists_absolute(_saves.get_slot_dir(2))
		and _saves.has_save(3))
	var row: Node = list.find_child("Slot2", true, false)
	check("list_refreshes_after_delete", row != null and (row.find_child("ManualInfo", true, false) as Label).text == "Thủ công: —")
	await _tap_key(KEY_ESCAPE)
	await _tap_key(KEY_ESCAPE)
	# Ảnh nhỏ: lưu kèm ảnh → meta + file png (headless không chụp được màn hình nên đưa ảnh vào trực tiếp).
	var image: Image = Image.create(SaveServiceScript.THUMBNAIL_SIZE.x, SaveServiceScript.THUMBNAIL_SIZE.y, false, Image.FORMAT_RGB8)
	image.fill(Color(0.2, 0.6, 0.3))
	check("thumbnail_saved", _saves.save_game(1, &"manual", image) and bool(_meta(1)["manual"]["thumbnail"])
		and _saves.load_thumbnail(1, &"manual") != null)


# ---------------------------------------------------------------- 7. về màn hình chính rồi Tiếp tục

func _test_back_to_title_and_continue() -> void:
	await _place(Vector2(23.0, 34.0))
	_clock.set_time(6, 13 * 60)
	_player.get_inventory().clear()
	_player.get_inventory().add(&"fiber", 9)
	check("save_before_title", await _save_via_menu(1, true))
	var saved_at: Vector2 = _player.global_position
	await _tap_key(KEY_ESCAPE)
	await _click(_pause_menu().call(&"get_button", "Về màn hình chính") as Button)
	check("no_warning_when_saved", _confirm_box() == null)
	await _wait_transition()
	check("back_on_title", current_scene.scene_file_path == TITLE_PATH and not paused)
	var continue_button: Button = _button(current_scene.call(&"get_menu") as Node, "Tiếp tục")
	check("continue_visible", continue_button != null and continue_button.visible)
	var done: Array[int] = []
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	await _click(continue_button)
	await _wait_until(func() -> bool: return not done.is_empty())
	await _wait_transition()
	_bind()
	_prepare()
	check("continue_restores_saved_state", done == [1] and _clock.get_day() == 6 and absf(_clock.get_minute_of_day() - 780.0) < 1.0
		and _player.get_inventory().count_of(&"fiber") == 9 and _player.global_position.distance_to(saved_at) < 0.5,
		"%s ngày %d %s sợi %d lệch %.2f" % [done, _clock.get_day(), _clock.format_time(), _player.get_inventory().count_of(&"fiber"), _player.global_position.distance_to(saved_at)])


# ---------------------------------------------------------------- 8. save đơn cũ v1–v5 → ô 1

func _legacy_sample(version: int) -> Dictionary:
	var at: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	var player: Dictionary = {"position": [at.x, at.y], "tier": 0, "health": 80 + version,
		"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "wood", "count": 10 + version}]}}
	var data: Dictionary = {"schema_version": version, "saved_at": "2026-10-2%d 10:00:00" % version, "playtime": 100.0 * version,
		"map_id": "glade", "global": {"player": player}, "maps": {"glade": {"world_items": {"version": 1, "collected": [], "dropped": []}}}}
	if version >= 2:
		data["global"]["clock"] = {"version": 1, "day": version, "minute": 600.0}
		player["survival"] = {"mana": 50.0, "stamina": 50.0, "hunger": 70.0, "respawn": {}}
		data["maps"]["glade"]["world_items"] = {"version": mini(version, 3), "collected": [], "dropped": [], "death_bags": [], "deployed": []}
	if version >= 3:
		data["maps"]["glade"]["resource_nodes"] = {"version": 1, "nodes": {}}
	if version >= 4:
		data["maps"]["glade"]["enemies"] = {"version": 1, "enemies": []}
		player["survival"]["buffs"] = []
	if version >= 5:
		data["maps"]["glade"]["farms"] = {"version": 1, "last_tick": 0, "fields": {}}
	return data


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _test_legacy_saves_become_slot_1() -> void:
	for version: int in range(1, 6):
		clear_dir(TEST_DIR)
		_write_text(TEST_DIR.path_join("slot_1.json"), JSON.stringify(_legacy_sample(version)))
		_write_text(TEST_DIR.path_join("slot_1.json.bak"), JSON.stringify(_legacy_sample(version)))
		_saves.save_dir = TEST_DIR
		var slots: Array[Dictionary] = _saves.list_slots()
		var manual: Dictionary = slots[0]["manual"]
		check("legacy_v%d_moved_to_slot_1" % version, not FileAccess.file_exists(TEST_DIR.path_join("slot_1.json"))
			and FileAccess.file_exists(_saves.get_slot_path(1, &"manual")) and FileAccess.file_exists(_saves.get_backup_path(1, &"manual"))
			and int(manual.get("day", 0)) == (version if version >= 2 else 1) and manual.get("map_name") == "Glade", str(manual))
		var done: Array[int] = []
		_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
		check("legacy_v%d_load_started" % version, _saves.load_game(1, &"manual"))
		await _wait_until(func() -> bool: return not done.is_empty())
		await _wait_transition()
		_bind()
		_prepare()
		check("legacy_v%d_loaded" % version, done == [1] and _player.get_inventory().count_of(&"wood") == 10 + version
			and _player.get_health().current_health == 80 + version, "gỗ %d" % _player.get_inventory().count_of(&"wood"))


# ---------------------------------------------------------------- 9. ruộng nửa ô cũ → lưới mới, không mất đồ

func _half_grid_save(full_bag: bool) -> Dictionary:
	var data: Dictionary = _legacy_sample(5)
	data["global"]["clock"] = {"version": 1, "day": 3, "minute": 600.0}
	if full_bag:
		var slots: Array = []
		for i: int in 24:
			slots.append({"slot": i, "id": "test_sword", "count": 1})
		data["global"]["player"]["inventory"] = {"version": 1, "size": 24, "slots": slots}
	# Ô cũ (c, r) nửa ô: (0,0) → ô mới (2,0); (1,0) (1,1) (2,0) → cùng ô mới (3,0); (5,3) → (5,1).
	data["maps"]["glade"]["farms"] = {"version": 1, "last_tick": 1, "fields": {"glade_home": {"plots": {
		"0,0": {"state": "planted", "crop": "wheat", "stage": 1, "age": 1, "watered_day": 3, "dry_days": 0, "fallow_days": 0},
		"1,0": {"state": "planted", "crop": "potato", "stage": 1, "age": 3, "watered_day": 0, "dry_days": 1, "fallow_days": 0},
		"1,1": {"state": "planted", "crop": "wheat", "stage": 3, "age": 3, "watered_day": 0, "dry_days": 0, "fallow_days": 0},
		"2,0": {"state": "tilled", "watered_day": 0, "dry_days": 0, "fallow_days": 1},
		"2,1": {"state": "planted", "crop": "berry_bush", "stage": 0, "age": 0, "watered_day": 0, "dry_days": 0, "fallow_days": 0},
		"5,3": {"state": "planted", "crop": "berry_bush", "stage": 2, "age": 4, "watered_day": 0, "dry_days": 0, "fallow_days": 0}}}}}
	# Lửa trại dựng đúng chỗ ô mới (4,1) → trả về túi; lều ngoài ruộng giữ nguyên.
	var fire_at: Vector2 = IsoProjection.to_screen(26.0 + 4.5, 33.0 + 1.5)
	var tent_at: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y + 1.0)
	data["maps"]["glade"]["world_items"]["deployed"] = [
		{"item_id": "campfire", "id": "campfire_old", "position": [fire_at.x, fire_at.y], "tier": 0, "state": {"fuel": 100.0, "lit": true}},
		{"item_id": "tent", "id": "tent_old", "position": [tent_at.x, tent_at.y], "tier": 0, "state": {}}]
	return data


func _test_half_grid_farm_migration() -> void:
	clear_dir(TEST_DIR)
	_saves.save_dir = TEST_DIR
	_write_text(TEST_DIR.path_join("slot_1.json"), JSON.stringify(_half_grid_save(false)))
	var migrated: Dictionary = _saves.read_save(1)
	var farms: Dictionary = migrated["maps"]["glade"]["farms"]
	var plots: Dictionary = farms["fields"]["glade_home"]["plots"]
	check("half_grid_remapped", farms["version"] == 2 and plots.size() == 3 and plots["2,0"]["crop"] == "wheat"
		and plots["3,0"]["crop"] == "potato" and plots["5,1"]["crop"] == "berry_bush", str(plots))
	# Bỏ: lúa chín (1,1) → 2 lúa mì; mầm mọng (2,1) → 1 quả mọng (hạt); đất cày (2,0) → không gì; lửa trại trong ruộng → 1 lửa trại.
	check("half_grid_refunds", farms["refunds"].has({"id": "wheat", "count": 2}) and farms["refunds"].has({"id": "berry", "count": 1})
		and farms["refunds"].has({"id": "campfire", "count": 1}) and farms["refunds"].size() == 3, str(farms["refunds"]))
	check("deployed_in_field_removed", (migrated["maps"]["glade"]["world_items"]["deployed"] as Array).size() == 1
		and migrated["maps"]["glade"]["world_items"]["deployed"][0]["item_id"] == "tent")
	var done: Array[int] = []
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	_saves.load_game(1)
	await _wait_until(func() -> bool: return not done.is_empty())
	await _wait_transition()
	_bind()
	var field: FarmField = (_world.get(&"farm_layer") as FarmLayer).find_field("glade_home")
	var bag: Inventory = _player.get_inventory()
	check("half_grid_loaded_plots", field.get_plot(Vector2i(2, 0)).crop.id == &"wheat" and field.get_plot(Vector2i(3, 0)).crop.id == &"potato"
		and field.get_plot(Vector2i(3, 0)).age == 3 and field.get_plot(Vector2i(5, 1)).crop.id == &"berry_bush")
	check("half_grid_refunds_in_bag", bag.count_of(&"wheat") == 2 and bag.count_of(&"berry") == 1 and bag.count_of(&"campfire") == 1
		and bag.count_of(&"wood") == 15, "lúa %d mọng %d lửa %d" % [bag.count_of(&"wheat"), bag.count_of(&"berry"), bag.count_of(&"campfire")])
	check("half_grid_feedback", _feedback().contains("Ruộng đã chuyển sang lưới mới"), _feedback())
	var layer: ItemPickupLayer = _world.get(&"pickup_layer") as ItemPickupLayer
	var kinds: Array[StringName] = []
	for node: Node in layer.get_deployed():
		kinds.append(StringName(str(node.get(&"item_id"))))
	check("half_grid_deployed_after_load", kinds == [&"tent"], str(kinds))
	# Lưu lại: không còn refunds (không trả hai lần).
	_saves.save_game(1)
	check("refunds_not_saved_again", not (_saves.read_save(1)["maps"]["glade"]["farms"] as Dictionary).has("refunds"))
	# Túi đầy → đồ trả rơi xuống đất cạnh người chơi, không mất.
	clear_dir(TEST_DIR)
	_saves.save_dir = TEST_DIR
	_write_text(TEST_DIR.path_join("slot_1.json"), JSON.stringify(_half_grid_save(true)))
	done.clear()
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	_saves.load_game(1)
	await _wait_until(func() -> bool: return not done.is_empty())
	await _wait_transition()
	_bind()
	await frames(2)
	var dropped: Dictionary = {}
	for pickup: ItemPickup in (_world.get(&"pickup_layer") as ItemPickupLayer).get_pickups():
		if not pickup.is_placed():
			dropped[pickup.item_id] = int(dropped.get(pickup.item_id, 0)) + pickup.count
	check("half_grid_full_bag_drops", dropped.get(&"wheat") == 2 and dropped.get(&"berry") == 1 and dropped.get(&"campfire") == 1, str(dropped))
	_prepare()


# ---------------------------------------------------------------- 10. đổi phím

func _open_controls() -> Control:
	await _tap_key(KEY_ESCAPE)
	await _click(_pause_menu().call(&"get_button", "Cài đặt") as Button)
	var settings: Control = _pause_menu().call(&"get_subpanel") as Control
	settings.call(&"show_tab", 3)
	await frames(2)
	return settings


func _close_menus() -> void:
	for i: int in 4:
		if not _pause_menu().visible:
			break
		await _tap_key(KEY_ESCAPE)


## Click ô phím (cuộn tới ô đó trước — danh sách dài hơn khung).
func _click_binding(panel: Control, action: StringName, index: int) -> void:
	var button: Button = panel.call(&"get_binding_button", action, index) as Button
	(panel.find_child("Controls", true, false) as ScrollContainer).ensure_control_visible(button)
	await frames(2)
	await _click(button)


func _test_rebinding() -> void:
	var settings: GameSettings = GameSettings.get_instance()
	await _place(Vector2(28.6, 32.6))
	var panel: Control = await _open_controls()
	# Bấm ô phím chính của "Tương tác" → nhấn F (đang là "Dùng / trang bị") → hỏi hoán đổi → đồng ý.
	await _click_binding(panel, &"interact", 0)
	check("capture_started", bool(panel.call(&"is_capturing")))
	await _tap_key(KEY_F)
	var box: ConfirmBox = _confirm_box()
	check("conflict_asks_swap", box != null and box.get_message().contains("Dùng / trang bị"), box.get_message() if box != null else "")
	await _answer("Hoán đổi")
	check("swap_applied", InputHint.action_text(&"interact") == "F" and InputHint.action_text(&"item_use") == "E"
		and (panel.call(&"get_binding_button", &"interact", 0) as Button).text == "F")
	# Esc không gán được: hủy chờ phím, phím giữ nguyên.
	await _click_binding(panel, &"dodge", 0)
	await _tap_key(KEY_ESCAPE)
	check("esc_not_bindable", not bool(panel.call(&"is_capturing")) and InputHint.action_text(&"dodge") == "Space" and _pause_menu().visible)
	# Không trùng: kỹ năng 1 → T (gán thẳng).
	await _click_binding(panel, &"skill_slot_1", 0)
	await _tap_key(KEY_T)
	check("bind_without_conflict", InputHint.action_text(&"skill_slot_1") == "T" and _confirm_box() == null)
	# Trùng nhưng không đồng ý → giữ nguyên.
	await _click_binding(panel, &"sprint", 0)
	await _tap_key(KEY_T)
	await _answer("Hủy")
	check("conflict_declined_keeps", InputHint.action_text(&"sprint") == "Shift" and InputHint.action_text(&"skill_slot_1") == "T")
	await _close_menus()
	# Phím mới dùng được ngay: F ở cạnh rương → mở rương; E không còn tương tác.
	var inventory: InventoryWindow = _world.get(&"inventory_window") as InventoryWindow
	await _tap_key(KEY_E)
	check("old_key_no_longer_interacts", not inventory.is_open())
	await _tap_key(KEY_F)
	check("new_key_works_immediately", inventory.is_open(), _feedback())
	await _tap_key(KEY_ESCAPE)
	# HUD đọc InputMap.
	var prompt: InteractionPrompt = _world.get_node("UILayer/InteractionPrompt") as InteractionPrompt
	await frames(2)
	check("hud_prompt_new_key", prompt.get_text().begins_with("[F]"), prompt.get_text())
	var hud: CombatHUD = _world.get(&"combat_hud") as CombatHUD
	check("hud_hint_new_keys", hud.get_hint_text().contains("F: tương tác") and hud.get_hint_text().contains("T/Z/V/X: kỹ năng"), hud.get_hint_text())
	var bar: SkillBar = _world.get(&"skill_bar") as SkillBar
	check("skill_bar_new_key", bar.get_slot_view(0).get_key_text() == "[T]", bar.get_slot_view(0).get_key_text())
	var guide_ok: bool = false
	for line: Array in KeyGuidePanel_lines():
		if line[0] == InputActions.display_name(&"interact"):
			guide_ok = line[1] == "F"
	check("key_guide_follows_binding", guide_ok)
	check("inventory_hint_new_key", (inventory.get_hint_text() as String).contains("E / nhấp đúp"), inventory.get_hint_text())
	# Lưu qua lần mở game sau: bỏ instance + nạp lại InputMap mặc định, rồi đọc settings.cfg.
	var config: ConfigFile = ConfigFile.new()
	check("bindings_written", config.load(GameSettings.config_path) == OK and Array(config.get_value("controls", "interact")) == ["key:%d" % KEY_F])
	# (Giữ instance để các node đang nghe changed không mất kết nối; load_file đọc lại từ đĩa như lúc mở game.)
	InputMap.load_from_project_settings()
	check("defaults_before_reload", InputHint.action_text(&"interact") == "E")
	settings.load_file()
	settings.apply_all()
	check("bindings_persist_restart", InputHint.action_text(&"interact") == "F" and InputHint.action_text(&"item_use") == "E"
		and InputHint.action_text(&"skill_slot_1") == "T")
	# Khôi phục mặc định (có xác nhận).
	panel = await _open_controls()
	var reset: Button = panel.find_child("ResetBindings", true, false) as Button
	(panel.find_child("Controls", true, false) as ScrollContainer).ensure_control_visible(reset)
	await frames(2)
	await _click(reset)
	await _answer("Khôi phục")
	check("reset_defaults", InputHint.action_text(&"interact") == "E" and InputHint.action_text(&"item_use") == "F"
		and InputHint.action_text(&"skill_slot_1") == "Q" and InputHint.all_text(&"move_up") == "W / Up")
	await _close_menus()
	await frames(2)
	check("hud_after_reset", hud.get_hint_text().contains("E: tương tác") and bar.get_slot_view(0).get_key_text() == "[Q]")
	# API: bind thẳng phím trùng không swap → từ chối; Esc → từ chối.
	var esc: InputEventKey = InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	check("api_rejects_esc", not settings.bind(&"interact", 0, esc).is_empty() and InputHint.action_text(&"interact") == "E")


func KeyGuidePanel_lines() -> Array:
	return (load("res://ui/menus/key_guide_panel.gd") as GDScript).call(&"get_lines")


# ---------------------------------------------------------------- 11. cài đặt lưu / đọc lại

func _test_settings_persist() -> void:
	var settings: GameSettings = GameSettings.get_instance()
	await _tap_key(KEY_ESCAPE)
	await _click(_pause_menu().call(&"get_button", "Cài đặt") as Button)
	var panel: Control = _pause_menu().call(&"get_subpanel") as Control
	panel.call(&"show_tab", 1)
	await frames(2)
	await _click(panel.find_child("show_fps", true, false) as Control)
	(panel.find_child("FpsLimit", true, false) as OptionButton).select(1)
	(panel.find_child("FpsLimit", true, false) as OptionButton).item_selected.emit(1)
	(panel.find_child("moonlight", true, false) as HSlider).value = 0.25
	panel.call(&"show_tab", 0)
	(panel.find_child("music_volume", true, false) as HSlider).value = 0.3
	(panel.find_child("sfx_volume", true, false) as HSlider).value = 0.0
	settings.set_value(&"vsync", false)
	await _close_menus()
	var overlay: AppOverlay = AppOverlay.get_instance()
	var day_night: DayNightLighting = _world.get(&"day_night") as DayNightLighting
	var music: int = AudioServer.get_bus_index("Music")
	var sfx: int = AudioServer.get_bus_index("SFX")
	check("audio_buses_exist", music > 0 and sfx > 0 and AudioServer.get_bus_index("Master") == 0)
	check("settings_applied_now", bool(settings.get_value(&"show_fps")) and (overlay.get_node("FPS") as Label).visible
		and Engine.max_fps == 60 and is_equal_approx(day_night.moonlight_override, 0.25)
		and is_equal_approx(AudioServer.get_bus_volume_db(music), linear_to_db(0.3)) and AudioServer.is_bus_mute(sfx),
		"fps %d moon %.2f" % [Engine.max_fps, day_night.moonlight_override])
	_clock.set_time(_clock.get_day(), 23 * 60)
	day_night.update_lighting()
	check("moonlight_changes_ambient", day_night.darkness == 1.0 and day_night.get_ambient_color() != day_night.settings.sun_color(1.0)
		and day_night.get_ambient_color().is_equal_approx(day_night.settings.sun_color(1.0, 0.25)))
	_clock.set_time(_clock.get_day() + 1, 10 * 60)
	settings.load_file()
	settings.apply_all()
	check("settings_reloaded", bool(settings.get_value(&"show_fps")) and int(settings.get_value(&"fps_limit")) == 60
		and is_equal_approx(float(settings.get_value(&"moonlight")), 0.25) and is_equal_approx(float(settings.get_value(&"music_volume")), 0.3)
		and float(settings.get_value(&"sfx_volume")) == 0.0 and not bool(settings.get_value(&"vsync"))
		and bool(settings.get_value(&"pause_on_focus_loss")))
	settings.set_value(&"moonlight", 5.0)
	settings.set_value(&"fps_limit", 77)
	check("settings_sanitized", is_equal_approx(float(settings.get_value(&"moonlight")), GameSettings.MOONLIGHT_MAX)
		and int(settings.get_value(&"fps_limit")) == 0)
	for key: StringName in GameSettings.DEFAULTS:
		settings.set_value(key, GameSettings.DEFAULTS[key])
	check("fps_unlimited_restored", Engine.max_fps == 0)


# ---------------------------------------------------------------- 12. bản release: không phím debug

func _test_release_has_no_debug_keys() -> void:
	DebugKeys.simulate_release = true
	await _place(ARENA)
	_clock.time_scale = 1.0
	_clock.set_time(_clock.get_day(), 22 * 60)
	var minutes: float = _clock.total_minutes
	var enemies_before: int = get_nodes_in_group(&"enemies").size()
	var weapon: WeaponEquipment = _player.get_node("WeaponEquipment") as WeaponEquipment
	var weapon_before: WeaponDefinition = weapon.get_weapon()
	var farms: FarmLayer = _world.get(&"farm_layer") as FarmLayer
	var plot: FarmPlot = farms.get_plots()[1]
	plot.load_plot_state({"state": "planted", "crop": "wheat", "age": 0}, farms.crop_book)
	clear_dir(TEST_DIR)
	_saves.save_dir = TEST_DIR
	for keycode: Key in [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5, KEY_F7, KEY_F8, KEY_F10, KEY_F11, KEY_F12, KEY_R, KEY_1, KEY_2, KEY_P]:
		await _tap_key(keycode)
	await frames(3)
	var panel: Node = current_scene.find_child("DebugKeysPanel", true, false)
	check("release_clock_keys_ignored", _clock.total_minutes - minutes < 1.0 and _clock.time_scale == 1.0, "%.1f" % (_clock.total_minutes - minutes))
	check("release_spawn_keys_ignored", get_nodes_in_group(&"enemies").size() == enemies_before)
	check("release_weapon_keys_ignored", weapon.get_weapon() == weapon_before)
	check("release_quick_save_ignored", not _saves.has_save(_saves.get_active_slot()))
	check("release_farm_keys_ignored", not plot.is_wet() and plot.age == 0)
	check("release_panels_ignored", (panel == null or not (panel as CanvasItem).visible)
		and not (_world.get(&"progression_panel") as Control).visible)
	var hud: CombatHUD = _world.get(&"combat_hud") as CombatHUD
	hud.refresh_key_hints()
	check("release_hud_no_debug_hint", not hud.get_hint_text().contains("debug"), hud.get_hint_text())
	# Màn hình tiêu đề bản release: không có lối vào map thử nghiệm.
	var title: Node = (load(TITLE_PATH) as PackedScene).instantiate()
	root.add_child(title)
	await frames(2)
	check("release_title_no_debug_buttons", _button(title, "[Debug] Combat Sandbox") == null)
	title.queue_free()
	await frames(2)
	DebugKeys.simulate_release = false
	# Bản debug: F12 bật bảng phím debug + bảng thông tin môi trường; F8 +1 giờ.
	await _tap_key(KEY_F12)
	panel = current_scene.find_child("DebugKeysPanel", true, false)
	var env_hud: CanvasItem = get_first_node_in_group(&"debug_hud") as CanvasItem
	check("debug_f12_panel", panel != null and (panel as CanvasItem).visible and env_hud != null and env_hud.visible
		and (panel.call(&"get_text") as String).contains("F6"))
	await _tap_key(KEY_F12)
	check("debug_f12_hides", not (panel as CanvasItem).visible and not env_hud.visible)
	minutes = _clock.total_minutes
	await _tap_key(KEY_F8)
	check("debug_f8_works_in_debug", _clock.total_minutes - minutes >= 59.0)


# ---------------------------------------------------------------- 13. thoát game: cảnh báo

func _test_quit_warning() -> void:
	await _place(ARENA)
	await seconds(1.2)
	check("has_unsaved_progress", _saves.has_unsaved_progress())
	AppOverlay.get_instance().notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await frames(2)
	var box: ConfirmBox = _confirm_box()
	check("window_close_warns_unsaved", box != null and box.get_message().contains("Thoát game") and _pause_menu().visible)
	await _answer("Hủy")
	check("quit_cancelled_keeps_game", _confirm_box() == null and _pause_menu().visible and current_scene == _world)
	await _close_menus()


# ---------------------------------------------------------------- 14. chuyển cảnh chặn input

func _test_transition_blocks_input() -> void:
	await _place(ARENA)
	_saves.save_game(1)
	AppOverlay.fade_time = 0.25
	var start: Vector2 = _player.global_position
	var done: Array[int] = []
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	_saves.load_game(1)
	await frames(2)
	var overlay: AppOverlay = AppOverlay.get_instance()
	Input.action_press(&"move_right")
	await seconds(0.15)
	check("transition_blocks_and_pauses", overlay.is_busy() and paused and _player.global_position.distance_to(start) < 0.5
		and (overlay.get_node("Fade") as ColorRect).color.a > 0.2)
	Input.action_release(&"move_right")
	await _wait_until(func() -> bool: return not done.is_empty())
	await seconds(0.1)
	check("transition_fades_back", not paused and current_scene != null)
	await _wait_transition()
	check("fade_cleared", (overlay.get_node("Fade") as ColorRect).color.a < 0.05)
	AppOverlay.fade_time = 0.02
