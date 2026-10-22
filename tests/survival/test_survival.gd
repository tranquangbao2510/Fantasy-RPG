extends "res://tests/test_base.gd"
## Kiểm thử headless TASK M2 (gộp M2.1, thiết kế v0.2) trên Environment Prototype (Glade). Đi qua input thật khi có thể
## (InputEventAction / Input.action_press → Player, World, GameClock, InteractionDetector, ô túi đồ).
## 1. Đồng hồ: tốc độ, phase, ngày mới lúc 0:00, pause, phím debug tua ×10 / +1 giờ.
## 2. Mana: cast trừ đúng, thiếu mana không cast + Skill Bar báo, hồi theo thời gian.
## 3. Stamina / chạy / né: chạy trừ stamina + nhanh hơn, né trừ stamina, quãng né trên mặt đất iso, không xuyên vách,
##    i-frame chặn sát thương, kiệt sức không né được rồi hồi lại.
## 4. Đói: giảm theo thời gian/hoạt động, < 25 không hồi stamina, = 0 mất HP.
## 5. Ăn: hồi đúng chỉ số, trừ item, đầy bụng không ăn, thịt sống trừ HP nhẹ, buff thịt nướng.
## 6. Tầm nhìn đêm: điểm ngoài bán kính bị che, trong bán kính thấy, đèn lồng tăng bán kính, đá rune mở vùng nhìn.
## 7. Ngủ: điều kiện giờ, sang 6:00 hôm sau, hồi chỉ số, tự lưu, "Ngày N"; ngất lúc 2:00.
## 8. Lều: dựng hợp lệ / không hợp lệ, một lều, ngủ (điểm hồi sinh tạm), thu lại.
## 9. Chết: túi rơi đúng chỗ với đúng đồ, hồi sinh ở chỗ nghỉ, đồ mặc giữ nguyên, nhặt lại túi, chết 2 lần = 2 túi, HUD.
## 10. Save v2: lưu/tải chỉ số, giờ, điểm hồi sinh, lều, túi; migration v1 → v2; không còn Thể lực (Energy).
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/survival/test_survival.gd

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")
const TEST_DIR: String = "user://test_saves_survival/"
const S: float = IsoProjection.GROUND_SQUASH
const ARENA: Vector2 = Vector2(22.0, 35.0)

var _saves: SaveServiceScript
var _world: Node  # Không khai báo kiểu World: world.gd dùng tên Autoload (xem test_base.gd).
var _player: Player
var _clock: GameClock
var _layer: ItemPickupLayer


func _run_tests() -> void:
	_saves = root.get_node("SaveService") as SaveServiceScript
	_saves.save_dir = TEST_DIR
	_clear_dir()
	await _open_world()
	await _test_clock()
	await _test_mana()
	await _test_stamina_and_dodge()
	await _test_hunger()
	await _test_eating()
	await _test_night_vision()
	await _test_sleep()
	await _test_tent()
	await _test_death()
	await _test_save_v2()
	await _test_migration_v1()
	_test_no_energy()
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


## Cấu hình test: không fade (nhanh), enemy đứng yên ở xa, đồng hồ đứng yên trừ khi test cần.
func _prepare() -> void:
	var settings: SleepSettings = _world.sleep_controller.settings
	settings.fade_time = 0.0
	settings.title_time = 0.0
	var enemy: Node2D = _world.get_node("EntityContainer/SimpleEnemy") as Node2D
	enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_clock.running = false
	# TASK M4: test M2 không có quái đêm.
	_world.enemy_spawner.enabled = false


func _place(grid: Vector2, tier: int = 0) -> void:
	_player.global_position = IsoProjection.to_screen(grid.x, grid.y, IsoProjection.TIER_HEIGHT * tier)
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(tier)


func _release_moves() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"sprint"]:
		Input.action_release(action)


func _feedback() -> String:
	return (_world.get_node("UILayer/InteractionFeedback/Label") as Label).text


func _find(bag: Inventory, item_id: StringName) -> int:
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			return i
	return -1


# ---------------------------------------------------------------- 1. đồng hồ

func _test_clock() -> void:
	check("clock_starts_6am_day1", _clock.get_day() == 1 and is_equal_approx(_clock.get_minute_of_day(), 360.0)
		and _clock.get_phase() == GameClock.Phase.DAWN, "%d %s" % [_clock.get_day(), _clock.format_time()])
	check("clock_speed_20min_per_day", is_equal_approx(_clock.settings.get_minutes_per_second(), 1.2))
	_clock.running = true
	var before: float = _clock.total_minutes
	await seconds(1.0)
	var elapsed: float = _clock.total_minutes - before
	check("clock_runs_realtime", elapsed > 1.0 and elapsed < 1.6, "%.2f phút game / 1 s" % elapsed)
	# Pause: SceneTree bị pause thì đồng hồ đứng.
	paused = true
	before = _clock.total_minutes
	await seconds(0.4)
	check("clock_pauses_with_tree", is_equal_approx(_clock.total_minutes, before))
	paused = false
	_clock.running = false
	# Phase + ngày mới.
	var phases: Array[GameClock.Phase] = []
	var days: Array[int] = []
	_clock.phase_changed.connect(func(phase: GameClock.Phase) -> void: phases.append(phase))
	_clock.day_started.connect(func(day: int) -> void: days.append(day))
	_clock.set_time(1, 6 * 60)
	phases.clear()
	# 6:00 → 0:00 hôm sau (chưa tới giờ ngất 2:00).
	_clock.advance(18 * 60)
	check("clock_phases_in_order", phases == [GameClock.Phase.DAY, GameClock.Phase.DUSK, GameClock.Phase.NIGHT], str(phases))
	check("clock_new_day_at_midnight", days == [2] and _clock.get_day() == 2 and _clock.format_time() == "00:00", _clock.format_time())
	# Phím debug qua input thật: +1 giờ, tua ×10.
	await tap_action(&"debug_time_skip")
	check("debug_skip_hour_via_input", _clock.format_time() == "01:00", _clock.format_time())
	await tap_action(&"debug_time_fast")
	check("debug_fast_via_input", is_equal_approx(_clock.time_scale, 10.0))
	await tap_action(&"debug_time_fast")
	check("debug_fast_toggle_off", is_equal_approx(_clock.time_scale, 1.0))
	var hud: CombatHUD = _world.combat_hud
	check("hud_clock_text", hud.get_clock_text().begins_with("Ngày 2 · 01:00"), hud.get_clock_text())
	_clock.set_time(1, 9 * 60)
	_player.get_hunger().load_value(100.0)


# ---------------------------------------------------------------- 2. mana

func _test_mana() -> void:
	_place(ARENA)
	await frames(2)
	var mana: ManaComponent = _player.get_mana()
	var caster: SkillCastingController = _player.get_node("SkillCastingController") as SkillCastingController
	var bar: SkillBar = _world.skill_bar
	mana.refill()
	# Ô 2 = Test Linear Strike (Instant, 10 mana) — nhấn phím ô qua input thật.
	await tap_action(&"skill_slot_2")
	await frames(2)
	check("cast_spends_mana", is_equal_approx(mana.current, mana.get_max() - 10.0), "%.1f" % mana.current)
	await seconds(0.6)
	mana.load_value(5.0)
	var rejected: Array[String] = []
	caster.cast_rejected.connect(func(_slot: int, reason: String) -> void: rejected.append(reason))
	var charges_before: int = _player.get_node("SkillLoadout").get_runtime(1).get_charges()
	await tap_action(&"skill_slot_2")
	await frames(2)
	check("no_mana_no_cast", rejected.has("Thiếu mana") and mana.current < 5.5
		and _player.get_node("SkillLoadout").get_runtime(1).get_charges() == charges_before, str(rejected))
	check("skill_bar_shows_no_mana", bar.get_slot_view(1).get_status_text().begins_with("Thiếu mana"), bar.get_slot_view(1).get_status_text())
	var low: float = mana.current
	await seconds(1.6)
	check("mana_regenerates", mana.current > low + 1.0, "%.1f → %.1f" % [low, mana.current])
	mana.refill()


# ---------------------------------------------------------------- 3. stamina, chạy, né

func _test_stamina_and_dodge() -> void:
	var stamina: StaminaComponent = _player.get_stamina()
	var sprite: PlayerSprite = _player.get_node("Visual/Sprite") as PlayerSprite
	_place(ARENA)
	stamina.refill()
	await frames(2)
	Input.action_press(&"move_right")
	await frames(6)
	var walk_speed: float = _player.velocity.length()
	Input.action_press(&"sprint")
	await frames(40)
	check("sprint_faster", _player.velocity.length() > walk_speed * 1.4 and sprite.animation == &"run_E",
		"%.0f → %.0f %s" % [walk_speed, _player.velocity.length(), sprite.animation])
	# TASK M3: chạy tiêu 12/s (M2: 20/s) — 40 frame ≈ 0.67 s → ≈ 8.
	check("sprint_drains_stamina", stamina.settings.sprint_cost_per_second == 12.0 and stamina.current < stamina.get_max() - 6.0
		and stamina.current > stamina.get_max() - 10.0, "%.1f" % stamina.current)
	_release_moves()
	await frames(2)
	var after_sprint: float = stamina.current
	await seconds(1.0)
	check("stamina_regenerates", stamina.current > after_sprint + 5.0, "%.1f → %.1f" % [after_sprint, stamina.current])
	# Né qua phím Space: quãng lướt trên mặt đất iso = dodge_distance (đi sang phải).
	stamina.refill()
	_place(ARENA)
	await frames(2)
	var start: Vector2 = _player.global_position
	Input.action_press(&"move_down")
	await tap_action(&"dodge")
	await seconds(_player.mobility.dodge_duration + 0.1)
	_release_moves()
	var ground: float = GroundSpace.length(_player.global_position - start, S)
	# Trong lúc giữ phím còn đi bộ thêm sau khi lướt xong → trừ quãng đi bộ (chỉ kiểm tra cận dưới/ trên rộng).
	check("dodge_spends_stamina", is_equal_approx(stamina.current, stamina.get_max() - stamina.settings.dodge_cost)
		or stamina.current < stamina.get_max(), "%.1f" % stamina.current)
	check("dodge_ground_distance", ground >= _player.mobility.dodge_distance - 4.0 and ground < _player.mobility.dodge_distance + 40.0,
		"%.1f px mặt đất" % ground)
	# Quãng né chính xác: đứng yên, né theo hướng nhìn (xuống = S).
	await seconds(0.7)
	stamina.refill()
	_place(ARENA)
	await frames(2)
	start = _player.global_position
	check("dodge_direct_call", _player.try_dodge())
	await seconds(_player.mobility.dodge_duration + 0.05)
	ground = GroundSpace.length(_player.global_position - start, S)
	check("dodge_exact_ground_distance", absf(ground - _player.mobility.dodge_distance) < 3.0, "%.1f" % ground)
	# I-frame: trong lúc né không nhận sát thương.
	await seconds(0.7)
	var hurtbox: Hurtbox = _player.get_node("Hurtbox") as Hurtbox
	var health: HealthComponent = _player.get_health()
	health.reset()
	_player.try_dodge()
	var info: DamageInfo = DamageInfo.new(10, null)
	check("dodge_iframe_blocks_damage", hurtbox.receive_damage(info) == 0 and health.current_health == health.max_health)
	await seconds(_player.mobility.dodge_invulnerable_time + 0.05)
	check("iframe_ends", hurtbox.receive_damage(info) == 10)
	health.reset()
	# Không xuyên vách: né từ đồng cỏ vào vách SW của plateau (làn i = 12 trống tới chân vách j = 17).
	await seconds(0.7)
	stamina.refill()
	var plateau: ElevatedTerrain = _world.get_node("EntityContainer/Elevation/Plateau") as ElevatedTerrain
	for k: int in 3:
		_place(Vector2(12.0, 17.9))
		Input.action_press(&"move_up")
		Input.action_press(&"move_right")
		await frames(1)
		_player.try_dodge()
		await seconds(_player.mobility.dodge_duration + 0.05)
		_release_moves()
		await seconds(_player.mobility.dodge_cooldown + 0.05)
	check("dodge_blocked_by_cliff", not Geometry2D.is_point_in_polygon(_player.global_position, plateau.get_blocking_polygon())
		and ElevationAgent.find_for(_player).get_tier() == 0, str(IsoProjection.to_grid(_player.global_position)))
	# Kiệt sức: hết stamina → không né được tới khi hồi đủ ngưỡng.
	stamina.load_value(0.0)
	stamina.drain_sprint(1.0)
	stamina.load_value(0.0)
	_place(ARENA)
	await seconds(0.6)
	check("exhausted_cannot_dodge", not _player.try_dodge() or stamina.current >= stamina.settings.dodge_cost)
	stamina.refill()


# ---------------------------------------------------------------- 4. đói

func _test_hunger() -> void:
	var hunger: HungerComponent = _player.get_hunger()
	var health: HealthComponent = _player.get_health()
	hunger.load_value(80.0)
	_clock.advance(60.0)
	check("hunger_decays_with_time", is_equal_approx(hunger.value, 80.0 - hunger.settings.decay_per_hour_awake), "%.2f" % hunger.value)
	var idle_value: float = hunger.value
	_place(ARENA)
	Input.action_press(&"move_left")
	Input.action_press(&"sprint")
	await seconds(1.0)
	_release_moves()
	check("hunger_drains_when_sprinting", hunger.value < idle_value - 0.05, "%.3f → %.3f" % [idle_value, hunger.value])
	# < 25: không hồi stamina.
	hunger.load_value(20.0)
	var stamina: StaminaComponent = _player.get_stamina()
	stamina.load_value(40.0)
	await seconds(1.0)
	check("low_hunger_blocks_stamina_regen", is_equal_approx(stamina.current, 40.0) and _world.combat_hud.is_hunger_warning())
	# = 0: mất HP chậm theo thời gian game (TASK M3: 6 % max HP mỗi giờ game).
	health.reset()
	hunger.load_value(0.0)
	_clock.advance(60.0)
	check("starving_loses_hp", health.current_health == health.max_health - floori(health.max_health * 0.06), "%d" % health.current_health)
	# Đầy HP → chết trong 12–15 phút thực, với max HP của Player (130) lẫn HP gốc (100) — component riêng để Player
	# không chết thật (DeathController sẽ chạy).
	for max_hp: int in [health.max_health, 100]:
		var probe_health: HealthComponent = HealthComponent.new()
		probe_health.max_health = max_hp
		root.add_child(probe_health)
		var probe: HungerComponent = HungerComponent.new()
		probe.settings = hunger.settings
		probe.health = probe_health
		root.add_child(probe)
		probe.load_value(0.0)
		var starving_minutes: float = 0.0
		while not probe_health.is_dead() and starving_minutes < 3000.0:
			probe.pass_time(10.0)
			starving_minutes += 10.0
		var real_minutes: float = starving_minutes / _clock.settings.get_minutes_per_second() / 60.0
		check("starving_full_to_dead_12_15_min_hp%d" % max_hp, probe_health.is_dead() and real_minutes >= 12.0 and real_minutes <= 15.0,
			"%.0f phút game = %.1f phút thực" % [starving_minutes, real_minutes])
		probe.free()
		probe_health.free()
	health.reset()
	hunger.load_value(100.0)
	stamina.refill()


# ---------------------------------------------------------------- 5. ăn

func _test_eating() -> void:
	var bag: Inventory = _player.get_inventory()
	var hunger: HungerComponent = _player.get_hunger()
	var health: HealthComponent = _player.get_health()
	var window: InventoryWindow = _world.inventory_window
	bag.clear()
	bag.add(&"bread", 2)
	bag.add(&"raw_meat", 1)
	bag.add(&"grilled_meat", 1)
	hunger.load_value(50.0)
	health.reset()
	health.apply_damage(20)
	await tap_action(&"inventory_toggle")
	check("inventory_opens_via_input", window.is_open())
	window.refresh_now()
	# Chuột phải lên ô bánh mì → menu "Dùng" (input chuột thật qua GUI).
	var view: ItemSlotView = window.get_bag_view(_find(bag, &"bread"))
	await process_frame
	# Toạ độ ô (canvas) → toạ độ cửa sổ (input thật đi qua stretch của root viewport).
	var center: Vector2 = root.get_final_transform() * view.get_global_rect().get_center()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = center
	click.global_position = center
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	var menu: PopupMenu = window.get_context_menu()
	check("right_click_opens_use_menu", menu.visible and menu.get_item_text(0) == "Dùng", menu.get_item_text(0) if menu.item_count > 0 else "—")
	if menu.item_count > 0:
		menu.id_pressed.emit(menu.get_item_id(0))
	menu.hide()
	await process_frame
	check("eat_restores_hunger_and_hp", is_equal_approx(hunger.value, 80.0) and health.current_health == health.max_health - 15
		and bag.count_of(&"bread") == 1, "đói %.0f, HP %d" % [hunger.value, health.current_health])
	check("eat_feedback", _feedback().begins_with("Đã dùng Bánh mì"), _feedback())
	# Phím F khi rê chuột lên ô (mouse motion thật để GUI biết ô đang được rê).
	var meat_view: ItemSlotView = window.get_bag_view(_find(bag, &"raw_meat"))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * meat_view.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	var hp_before: int = health.current_health
	await tap_action(&"item_use")
	check("raw_meat_hurts_a_little", not bag.has(&"raw_meat") and health.current_health == hp_before - 3 and is_equal_approx(hunger.value, 90.0),
		"HP %d → %d, đói %.0f" % [hp_before, health.current_health, hunger.value])
	# Đầy bụng: không ăn.
	hunger.load_value(96.0)
	var reason: String = _world.use_item(_find(bag, &"bread"))
	check("full_stomach_refuses", reason.begins_with("Đang no") and bag.count_of(&"bread") == 1, reason)
	# Thịt nướng: buff hồi stamina ×1.5.
	hunger.load_value(30.0)
	check("grilled_meat_eaten", _world.use_item(_find(bag, &"grilled_meat")).is_empty())
	var buffs: BuffComponent = _player.get_buffs()
	check("grilled_meat_buff", buffs.has_buff(&"warm_meal") and is_equal_approx(buffs.get_multiplier(BuffDefinition.Stat.STAMINA_REGEN), 1.5))
	await tap_action(&"inventory_toggle")
	health.reset()
	hunger.load_value(100.0)
	buffs.clear()


# ---------------------------------------------------------------- 6. tầm nhìn đêm

func _test_night_vision() -> void:
	var lighting: DayNightLighting = _world.day_night
	var light: VisionLight = _player.get_node("VisionLight") as VisionLight
	_place(ARENA)
	_clock.set_time(1, 12 * 60)
	await frames(2)
	var far: Vector2 = _player.global_position + Vector2(300, 0)
	check("day_everything_visible", lighting.darkness == 0.0 and lighting.is_point_visible(far) and not light.is_lit()
		and lighting.get_overlay().light_count == 0)
	_clock.set_time(1, 23 * 60)
	await frames(2)
	var radius: float = lighting.get_vision_radius()
	# TASK M3: không đen hẳn — còn ánh trăng 12–18 % (kênh sáng nhất của màu môi trường; TASK M4: NightOverlay).
	var ambient: Color = lighting.get_ambient_color()
	check("night_darkness_moonlight", lighting.darkness == 1.0 and ambient.v >= 0.12 and ambient.v <= 0.18
		and is_equal_approx(ambient.v, lighting.settings.moonlight) and light.is_lit() and lighting.get_overlay().light_count >= 1, "%s" % ambient)
	check("night_far_is_moonlit", is_equal_approx(lighting.get_visibility(_player.global_position + Vector2(900, 0)), lighting.settings.moonlight))
	check("night_near_visible", lighting.is_point_visible(_player.global_position + Vector2(radius * 0.5, 0)))
	check("night_far_hidden", not lighting.is_point_visible(_player.global_position + Vector2(radius * 1.3, 0)))
	# Bán kính đo trên mặt đất: theo chiều dọc màn hình chỉ bằng một nửa.
	check("night_radius_ground_ellipse", not lighting.is_point_visible(_player.global_position + Vector2(0, radius * 0.7)))
	check("light_size_matches_radius", is_equal_approx(light.radius, radius) and is_equal_approx(light.ground_squash, S))
	# Đèn lồng ở ô offhand: bán kính tăng, ánh sáng ấm.
	var bag: Inventory = _player.get_inventory()
	bag.clear()
	bag.add(&"lantern", 1)
	check("equip_lantern_offhand", _player.get_equipment().equip_from_inventory(0) and _player.get_equipment().get_stack(&"offhand") != null)
	await frames(2)
	check("lantern_increases_radius", is_equal_approx(lighting.get_vision_radius(), radius + 96.0)
		and lighting.is_point_visible(_player.global_position + Vector2(radius * 1.1, 0)), "%.0f" % lighting.get_vision_radius())
	check("lantern_warm_light", light.color.is_equal_approx(Color(1, 0.78, 0.45)))
	_player.get_equipment().unequip_to_inventory(&"offhand")
	# Nguồn sáng thế giới: đá rune mở vùng nhìn quanh nó dù Player ở xa.
	var rune: Node2D = _world.get_node("EntityContainer/Props/RuneStone") as Node2D
	check("rune_light_reveals_area", lighting.is_point_visible(rune.global_position + Vector2(30, 0))
		and _player.global_position.distance_to(rune.global_position) > 400.0)
	# Hoàng hôn: chuyển mượt (giữa 0 và 1).
	_clock.set_time(1, 18 * 60)
	lighting.update_lighting()
	check("dusk_partial_darkness", lighting.darkness > 0.2 and lighting.darkness < 0.8, "%.2f" % lighting.darkness)
	_clock.set_time(1, 9 * 60)
	await frames(1)


# ---------------------------------------------------------------- 7. ngủ

func _bed() -> Bed:
	return _world.get_node("EntityContainer/Bed") as Bed


func _walk_to_spot(spot: Node2D) -> void:
	_player.global_position = spot.global_position + Vector2(0, 14)
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(4)


func _test_sleep() -> void:
	var bed: Bed = _bed()
	var health: HealthComponent = _player.get_health()
	var hunger: HungerComponent = _player.get_hunger()
	DirAccess.remove_absolute(_saves.get_slot_path(1, &"autosave"))
	_clock.set_time(1, 10 * 60)
	await _walk_to_spot(bed)
	await tap_action(&"interact")
	await frames(2)
	check("cannot_sleep_daytime", _clock.format_time() == "10:00" and _feedback().begins_with("Chưa tới giờ ngủ"), _feedback())
	_clock.set_time(1, 22 * 60)
	health.reset()
	health.apply_damage(60)
	hunger.load_value(80.0)
	var slept: Array[int] = []
	_world.sleep_controller.slept.connect(func(day: int) -> void: slept.append(day), CONNECT_ONE_SHOT)
	await tap_action(&"interact")
	for i: int in 20:
		if not slept.is_empty():
			break
		await process_frame
	check("sleep_to_6am_next_day", slept == [2] and _clock.get_day() == 2 and _clock.format_time() == "06:00",
		"%d %s" % [_clock.get_day(), _clock.format_time()])
	# TASK M3: giường nhà hồi 100 % HP.
	check("sleep_heals_bed_full", is_equal_approx(_world.sleep_controller.settings.heal_ratio_for("bed"), 1.0)
		and health.current_health == health.max_health, "%d" % health.current_health)
	check("sleep_hunger_by_sleep_rate", absf(hunger.value - (80.0 - 8.0 * hunger.settings.decay_per_hour_sleeping)) < 0.05, "%.2f" % hunger.value)
	check("sleep_autosaves", FileAccess.file_exists(_saves.get_slot_path(1, &"autosave")) and not FileAccess.file_exists(_saves.get_slot_path(1)))
	check("sleep_sets_respawn_to_bed", _player.respawn_point.get("id") == bed.spot_id and _player.respawn_point.get("kind") == "bed")
	check("sleep_day_title", (_world.get_node("UILayer/SleepOverlay") as SleepOverlay).last_title == "Ngày 2"
		and not _player.is_control_locked())
	# Ngất lúc 2:00 (TASK M3): tỉnh TẠI CHỖ lúc 6:00 cùng ngày, không hồi HP, không tự lưu, đói −10 (+ giảm theo nhịp ngủ).
	_place(ARENA)
	var faint_at: Vector2 = _player.global_position
	hunger.load_value(80.0)
	DirAccess.remove_absolute(_saves.get_slot_path(1, &"autosave"))
	_clock.set_time(3, 1 * 60 + 59)
	health.reset()
	health.apply_damage(30)
	var fainted: Array[int] = []
	_world.sleep_controller.fainted.connect(func(day: int) -> void: fainted.append(day), CONNECT_ONE_SHOT)
	_clock.advance(2.0)
	for i: int in 20:
		if not fainted.is_empty():
			break
		await process_frame
	check("faint_at_2am", fainted == [3] and _clock.format_time() == "06:00" and _clock.get_day() == 3, _clock.format_time())
	check("faint_wakes_in_place", _player.global_position.distance_to(faint_at) < 1.0)
	var expected_hunger: float = 80.0 - 2.0 / 60.0 * hunger.settings.decay_per_hour_awake - 4.0 * hunger.settings.decay_per_hour_sleeping - 10.0
	check("faint_hunger_penalty", absf(hunger.value - expected_hunger) < 0.05, "%.2f (mong đợi %.2f)" % [hunger.value, expected_hunger])
	check("faint_no_autosave", not FileAccess.file_exists(_saves.get_slot_path(1, &"autosave")))
	check("faint_no_heal", health.current_health == health.max_health - 30)
	health.reset()


# ---------------------------------------------------------------- 8. lều

func _test_tent() -> void:
	var bag: Inventory = _player.get_inventory()
	bag.clear()
	bag.add(&"tent", 1)
	# Không hợp lệ: chồng lên rương / trên nước.
	var chest: Node2D = _world.get_node("EntityContainer/Chest") as Node2D
	_player.global_position = chest.global_position + Vector2(0, 6)
	await frames(2)
	var reason: String = _world.use_item(_find(bag, &"tent"))
	check("tent_blocked_by_object", reason == "Không đủ chỗ trống để dựng." and bag.has(&"tent"), reason)
	_place(Vector2(24.0, 25.8))
	await frames(2)
	reason = _world.use_item(_find(bag, &"tent"))
	check("tent_blocked_on_water", not reason.is_empty() and bag.has(&"tent"), reason)
	# Hợp lệ: đồng cỏ trống.
	_place(ARENA)
	await frames(2)
	reason = _world.use_item(_find(bag, &"tent"))
	var tents: Array[Node] = _layer.get_deployed()
	check("tent_placed", reason.is_empty() and tents.size() == 1 and not bag.has(&"tent")
		and (tents[0] as Node2D).global_position.distance_to(_player.global_position) < 1.0, reason)
	var tent: Tent = tents[0] as Tent
	bag.add(&"tent", 1)
	_place(ARENA + Vector2(2.0, 0.0))
	await frames(2)
	reason = _world.use_item(_find(bag, &"tent"))
	check("only_one_tent", reason.begins_with("Đã có một lều") and bag.has(&"tent"), reason)
	bag.clear()
	# Ngủ ở lều (E → menu → Ngủ) lúc đêm → điểm tỉnh dậy tạm thời tại lều.
	_clock.set_time(3, 21 * 60)
	await _walk_to_spot(tent)
	await tap_action(&"interact")
	await process_frame
	var menu: PopupMenu = _world.open_tent_menu(tent)
	check("tent_menu", menu.get_item_text(0) == "Ngủ" and menu.get_item_text(1) == "Thu lều")
	menu.hide()
	var tent_health: HealthComponent = _player.get_health()
	tent_health.reset()
	tent_health.apply_damage(100)
	var before_tent: int = tent_health.current_health
	var slept: Array[int] = []
	_world.sleep_controller.slept.connect(func(day: int) -> void: slept.append(day), CONNECT_ONE_SHOT)
	_world.choose_tent_action(tent, 0)
	for i: int in 20:
		if not slept.is_empty():
			break
		await process_frame
	check("sleep_in_tent", slept == [4] and _player.respawn_point.get("kind") == "tent" and _player.respawn_point.get("id") == tent.spot_id)
	check("wake_spot_is_tent", _world.sleep_controller.get_wake_spot() == tent)
	# TASK M3: lều hồi 70 % HP (giường 100 %).
	check("sleep_in_tent_heals_70", tent_health.current_health == mini(tent_health.max_health, before_tent + roundi(tent_health.max_health * 0.7)),
		"%d → %d" % [before_tent, tent_health.current_health])
	tent_health.reset()
	# Lưu/tải lều (vòng save → đổi scene → load).
	var tent_position: Vector2 = tent.global_position
	check("tent_saved", _saves.save_game(2))
	await _reload(2)
	var loaded: Array[Node] = _layer.get_deployed()
	check("tent_loaded", loaded.size() == 1 and (loaded[0] as Node2D).global_position.distance_to(tent_position) < 0.1
		and _world.sleep_controller.get_wake_spot() == loaded[0])
	tent = loaded[0] as Tent
	# Thu lều → vào túi, điểm tỉnh dậy về giường nhà.
	_world.choose_tent_action(tent, 1)
	await process_frame
	check("tent_packed", _player.get_inventory().has(&"tent") and _layer.get_deployed().is_empty()
		and _player.respawn_point.is_empty() and _world.sleep_controller.get_wake_spot() == _bed())


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


# ---------------------------------------------------------------- 9. chết

func _test_death() -> void:
	var bag: Inventory = _player.get_inventory()
	var health: HealthComponent = _player.get_health()
	var equipment: EquipmentSlots = _player.get_equipment()
	bag.clear()
	bag.add(&"wood", 7)
	bag.add(&"herb", 3)
	bag.add(&"test_helmet", 1)
	equipment.equip_from_inventory(_find(bag, &"test_helmet"))
	bag.add(&"bread", 2)
	_place(ARENA)
	await frames(2)
	var death_at: Vector2 = _player.global_position
	var respawned: Array[DeathBag] = []
	_world.death_controller.player_respawned.connect(func(bag_node: DeathBag) -> void: respawned.append(bag_node))
	health.apply_damage(health.max_health)
	for i: int in 20:
		if not respawned.is_empty():
			break
		await process_frame
	var first: DeathBag = respawned[0] if not respawned.is_empty() else null
	check("death_drops_bag_at_spot", first != null and first.global_position.distance_to(death_at) < 0.1 and first.get_tier() == 0)
	check("death_bag_contents", first != null and first.get_inventory().count_of(&"wood") == 7 and first.get_inventory().count_of(&"herb") == 3
		and first.get_inventory().count_of(&"bread") == 2)
	check("death_empties_bag_keeps_equipment", bag.first_empty_slot() == 0 and bag.count_of(&"wood") == 0
		and equipment.get_stack(&"head") != null and equipment.get_stack(&"weapon") != null)
	check("respawn_at_home_bed", _player.global_position.distance_to(_bed().get_wake_position()) < 1.0
		and health.current_health == roundi(health.max_health * 0.5) and not _player.is_dead() and not _player.is_control_locked(),
		"HP %d" % health.current_health)
	# Chết lần 2 khi chưa nhặt túi cũ → túi mới, túi cũ còn.
	bag.add(&"stone", 4)
	_place(ARENA + Vector2(3.0, -1.0))
	await frames(2)
	respawned.clear()
	health.apply_damage(health.max_health)
	for i: int in 20:
		if not respawned.is_empty():
			break
		await process_frame
	check("second_death_second_bag", _layer.get_death_bags().size() == 2 and is_instance_valid(first)
		and respawned[0].get_inventory().count_of(&"stone") == 4)
	var marker: DeathBagMarker = _world.death_marker
	check("hud_marks_bags", marker.get_markers().size() == 2)
	# Lưu/tải túi.
	check("bags_saved", _saves.save_game(3))
	await _reload(3)
	var bags: Array[DeathBag] = _layer.get_death_bags()
	var wood_bag: DeathBag = null
	for b: DeathBag in bags:
		if b.get_inventory().has(&"wood"):
			wood_bag = b
	check("bags_loaded", bags.size() == 2 and wood_bag != null and wood_bag.global_position.distance_to(death_at) < 0.1
		and wood_bag.get_inventory().count_of(&"herb") == 3)
	# Nhặt lại bằng E (input thật) → đồ về túi; túi đầy thì phần dư rơi xuống đất.
	bag = _player.get_inventory()
	bag.clear()
	for k: int in bag.get_size() - 1:
		bag.add(&"test_sword", 1)
	_player.global_position = wood_bag.global_position + Vector2(0, 8)
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(4)
	var drops_before: int = _layer.get_pickups().size()
	await tap_action(&"interact")
	await frames(2)
	check("collect_bag_via_e", not is_instance_valid(wood_bag) or wood_bag.is_queued_for_deletion())
	check("collect_bag_fills_then_drops", bag.is_full() and bag.count_of(&"wood") == 7 and _layer.get_pickups().size() == drops_before + 2,
		"drops %d → %d" % [drops_before, _layer.get_pickups().size()])
	check("collect_bag_message", _feedback().contains("rơi xuống đất"), _feedback())
	bag.clear()


# ---------------------------------------------------------------- 10. save v2

func _test_save_v2() -> void:
	var mana: ManaComponent = _player.get_mana()
	var stamina: StaminaComponent = _player.get_stamina()
	var hunger: HungerComponent = _player.get_hunger()
	mana.load_value(42.5)
	stamina.load_value(61.0)
	hunger.load_value(37.25)
	_clock.set_time(5, 20 * 60 + 15)
	_world.sleep_controller.set_wake_spot(_bed())
	check("save_v2", _saves.save_game(4))
	var data: Dictionary = _saves.read_save(4)
	var survival: Dictionary = data["global"]["player"]["survival"]
	check("save_v2_structure", int(data["schema_version"]) == SaveServiceScript.SCHEMA_VERSION and data["global"]["clock"]["day"] == 5.0
		and is_equal_approx(survival["hunger"], 37.25) and survival["respawn"]["kind"] == "bed", JSON.stringify(survival))
	mana.refill()
	hunger.load_value(100.0)
	_clock.set_time(1, 360)
	await _reload(4)
	check("load_v2_stats", absf(_player.get_mana().current - 42.5) < 1.5 and absf(_player.get_stamina().current - 61.0) < 2.5
		and absf(_player.get_hunger().value - 37.25) < 0.1, "%.1f %.1f %.2f" % [_player.get_mana().current, _player.get_stamina().current, _player.get_hunger().value])
	check("load_v2_clock", _clock.get_day() == 5 and _clock.format_time() == "20:15", _clock.format_time())
	check("load_v2_respawn", _player.respawn_point.get("id") == _bed().spot_id)


func _test_migration_v1() -> void:
	# Save M1 thật (schema 1): không có clock, không có survival, world_items chưa có death_bags/deployed.
	var position: Vector2 = IsoProjection.to_screen(ARENA.x, ARENA.y)
	var v1: Dictionary = {"schema_version": 1, "saved_at": "2026-10-20 00:17:07", "playtime": 12.0, "map_id": "glade",
		"global": {"player": {"position": [position.x, position.y], "tier": 0, "health": 90,
			"inventory": {"version": 1, "size": 24, "slots": [{"slot": 0, "id": "wood", "count": 5}]}}},
		"maps": {"glade": {"world_items": {"version": 1, "collected": ["glade_wood_1"], "dropped": []}}}}
	DirAccess.make_dir_recursive_absolute(_saves.get_slot_path(5).get_base_dir())
	var file: FileAccess = FileAccess.open(_saves.get_slot_path(5), FileAccess.WRITE)
	file.store_string(JSON.stringify(v1))
	file.close()
	var migrated: Dictionary = _saves.read_save(5)
	# v1 → v2 → v3 (TASK M3): thêm cả resource_nodes; → v4 (TASK M4): enemies + survival.buffs.
	check("migration_v1_v2_structure", int(migrated["schema_version"]) == SaveServiceScript.SCHEMA_VERSION and migrated["global"]["clock"]["minute"] == 360
		and migrated["maps"]["glade"]["resource_nodes"] == {"version": 1, "nodes": {}}
		and migrated["global"]["player"]["survival"] == {"buffs": []} and migrated["maps"]["glade"]["enemies"] == {"version": 1, "enemies": []}
		and migrated["maps"]["glade"]["world_items"]["death_bags"] == [],
		JSON.stringify(migrated["global"]))
	await _reload(5)
	check("migration_v1_loads", _player.get_inventory().count_of(&"wood") == 5 and _player.get_health().current_health == 90
		and _player.get_hunger().value > _player.get_hunger().get_max() - 0.5
		and is_equal_approx(_player.get_mana().current, _player.get_mana().get_max())
		and _clock.get_day() == 1 and _clock.format_time() == "06:00" and _layer.get_death_bags().is_empty(),
		"%d %s wood=%d hp=%d hunger=%.1f mana=%.1f bags=%d" % [_clock.get_day(), _clock.format_time(), _player.get_inventory().count_of(&"wood"),
		_player.get_health().current_health, _player.get_hunger().value, _player.get_mana().current, _layer.get_death_bags().size()])


func _test_no_energy() -> void:
	var names: Array = ProjectSettings.get_global_class_list().map(func(entry: Dictionary) -> String: return str(entry["class"]))
	check("no_energy_classes", not names.has("EnergyComponent") and not names.has("EnergySettings"))
	check("no_energy_in_save", not JSON.stringify(_player.save_state()).to_lower().contains("energy"))
