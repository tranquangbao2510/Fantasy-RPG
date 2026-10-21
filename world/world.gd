class_name World
extends Node2D
## Gốc của môi trường game.
## Cung cấp các container và nối các module (camera, interaction UI) với nhau; không chứa logic gameplay.
## Các module khác thêm node vào container qua các hàm public bên dưới; thực thể sinh ra lúc chạy gọi register_entity().
## Dùng chung cho Test World và Combat Sandbox (các export tùy chọn: thiếu thì bỏ qua phần tương ứng).

@export var camera: GameCamera
@export var camera_target: Node2D
@export var map_bounds: MapBounds
@export var interaction_detector: InteractionDetector
@export var interaction_prompt: InteractionPrompt
@export var interaction_feedback: InteractionFeedback
@export var player_health: HealthComponent
@export var combat_hud: CombatHUD
@export var player_weapon: WeaponEquipment
@export var player_attack: BasicAttackController
@export var player_skills: SkillLoadout
@export var player_caster: SkillCastingController
@export var skill_bar: SkillBar
@export var player: Player
@export var player_classes: ClassManager
@export var player_level: CharacterLevel
@export var progression_panel: ProgressionPanel
## Tùy chọn (Combat Sandbox): bảng debug combat và điều phối tình huống thử nghiệm.
@export var debug_panel: CombatDebugPanel
@export var scenario_controller: ScenarioController
## ID map ổn định cho Save/Load (khớp MapCatalog). Rỗng = map không lưu được (vd. Combat Sandbox).
@export var map_id: StringName = &""
## Tùy chọn (TASK M1): cửa sổ túi đồ, lớp vật phẩm trên đất, thông báo nhặt đồ.
@export var inventory_window: InventoryWindow
@export var pickup_layer: ItemPickupLayer
@export var pickup_toast: PickupToast
## Tùy chọn (TASK M2): đồng hồ, ánh sáng ngày/đêm + tầm nhìn đêm, ngủ, chết & hồi sinh, đánh dấu túi đồ.
@export var clock: GameClock
@export var day_night: DayNightLighting
@export var sleep_controller: SleepController
@export var death_controller: DeathController
@export var death_marker: DeathBagMarker
## Tùy chọn (TASK M3): sổ công thức + cửa sổ chế tạo / nấu ăn (phím C, bàn chế tạo, lửa trại), lớp node tài nguyên.
@export var recipe_book: RecipeBook
@export var crafting_window: CraftingWindow
@export var resource_layer: ResourceNodeLayer
## Tùy chọn (TASK M4): sinh quái theo bảng spawn (quái đêm), biểu ngữ trời tối, viền đỏ khi trúng đòn, chỉ báo quái
## đang đuổi ngoài màn hình.
@export var enemy_spawner: EnemySpawner
@export var night_banner: NightBanner
@export var hit_vignette: HitVignette
@export var threat_indicator: ThreatIndicator
## Tùy chọn (TASK M4.1): navmesh theo tầng cho quái tìm đường — bake lại khi vật dựng / node tài nguyên đổi.
@export var tier_navigation: TierNavigation

@onready var _environment: Node2D = $Environment
@onready var _map_container: Node2D = $MapContainer
@onready var _entity_container: Node2D = $EntityContainer
@onready var _camera_container: Node2D = $CameraContainer
## Hiệu ứng ngắn hạn (HitSpark) vẽ trên entity; nếu scene không có thì dùng EntityContainer.
@onready var _effect_container: Node2D = get_node_or_null(^"EffectContainer") as Node2D


func _ready() -> void:
	_setup_camera()
	_setup_interaction_ui()
	_setup_combat_hud()
	if skill_bar != null and player_skills != null and player_caster != null:
		skill_bar.bind(player_skills, player_caster)
	_setup_progression()
	_setup_inventory()
	_setup_save()
	_setup_survival()
	_setup_crafting()
	_setup_night()
	_setup_sandbox()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_reset"):
		reset_test_state()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"quick_save"):
		if SaveService.save_game():
			_show_feedback("Đã lưu (slot %d)." % SaveService.DEFAULT_SLOT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"quick_load"):
		# Đánh dấu đã xử lý TRƯỚC khi tải: load_game() gỡ scene hiện tại khỏi cây ngay, sau đó get_viewport() là null.
		get_viewport().set_input_as_handled()
		SaveService.load_game()


func get_environment_container() -> Node2D:
	return _environment


func get_map_container() -> Node2D:
	return _map_container


func get_entity_container() -> Node2D:
	return _entity_container


func get_camera_container() -> Node2D:
	return _camera_container


## Vùng bản đồ hiện tại theo world coordinates; Rect2() nếu chưa gán map_bounds.
func get_map_rect() -> Rect2:
	if map_bounds == null:
		return Rect2()
	return map_bounds.global_transform * map_bounds.get_map_rect()


## Reset thử nghiệm (không phải cơ chế chính thức): gọi reset_state() trên mọi node thuộc group
## `test_resettable` trong World, rồi đặt lại camera về target để không trượt từ vị trí cũ.
func reset_test_state() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"test_resettable"):
		if is_ancestor_of(node) and node.has_method(&"reset_state"):
			node.call(&"reset_state")
	if camera != null:
		camera.set_target(camera_target)


func _setup_camera() -> void:
	if camera == null:
		return
	if map_bounds != null:
		camera.set_map_rect(get_map_rect())
	camera.set_target(camera_target)


func _setup_interaction_ui() -> void:
	if interaction_detector == null:
		return
	if interaction_prompt != null:
		interaction_detector.target_changed.connect(interaction_prompt.show_target)
	if interaction_feedback != null:
		interaction_detector.interacted.connect(_on_interacted)


func _on_interacted(_target: Interactable, message: String) -> void:
	interaction_feedback.show_message(message)


## Nối HP Player vào HUD và mọi Hurtbox trong World vào số sát thương (một lần lúc _ready;
## thực thể sinh ra sau này cần được nối tương tự khi thêm vào).
func _setup_combat_hud() -> void:
	if combat_hud == null:
		return
	if player_health != null:
		combat_hud.bind_player_health(player_health)
		player_health.healed.connect(_on_player_healed)
	if player_weapon != null:
		combat_hud.bind_weapon(player_weapon)
	if player_attack != null:
		combat_hud.bind_attack(player_attack)
	for node: Node in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		if hurtbox != null and is_ancestor_of(hurtbox):
			_connect_hurtbox(hurtbox)


## Nối thực thể sinh ra lúc chạy (vd. enemy của tình huống sandbox) vào số sát thương / hiệu ứng trúng đòn.
## Gọi nhiều lần cho cùng thực thể không tạo kết nối trùng.
func register_entity(entity: Node) -> void:
	if combat_hud == null:
		return
	for node: Node in entity.find_children("*", "Hurtbox", true, false):
		_connect_hurtbox(node as Hurtbox)


func _connect_hurtbox(hurtbox: Hurtbox) -> void:
	# Callable đã bind không so bằng được với _on_hit_received, nên kiểm tra theo object + tên hàm.
	for connection: Dictionary in hurtbox.hit_received.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == self and callable.get_method() == &"_on_hit_received":
			return
	hurtbox.hit_received.connect(_on_hit_received.bind(hurtbox))


## Combat Sandbox: bảng debug + tình huống mặc định. Bỏ qua nếu scene không có.
func _setup_sandbox() -> void:
	if scenario_controller != null:
		scenario_controller.entity_spawned.connect(register_entity)
	if debug_panel != null:
		debug_panel.bind(self)
	if scenario_controller != null:
		scenario_controller.start_scenario(scenario_controller.start_index)


## Nối Class/Progression vào UI: bảng progression, thông báo unlock/đổi class/từ chối trang bị, chặn input combat khi bảng mở.
func _setup_progression() -> void:
	if player_classes == null:
		return
	if progression_panel != null and player_level != null:
		progression_panel.bind(player_classes, player_level)
		if player != null:
			progression_panel.opened.connect(_refresh_combat_block)
			progression_panel.closed.connect(_refresh_combat_block)
	if combat_hud != null:
		combat_hud.bind_progression(player_classes, player_level)
	if interaction_feedback == null:
		return
	player_classes.class_unlocked.connect(func(class_id: StringName) -> void:
		interaction_feedback.show_message("Đã mở khóa class: %s" % player_classes.get_class_definition(class_id).display_name))
	player_classes.class_switched.connect(func(previous_id: StringName, class_id: StringName) -> void:
		if previous_id != &"":
			interaction_feedback.show_message("Đã chuyển sang class: %s" % player_classes.get_class_definition(class_id).display_name))
	if player_weapon != null:
		player_weapon.equip_rejected.connect(func(weapon: WeaponDefinition, reason: String) -> void:
			interaction_feedback.show_message("Không thể trang bị %s: %s" % [weapon.display_name if weapon != null else "—", reason]))
	if player_skills != null:
		player_skills.equip_rejected.connect(func(_slot: int, skill: SkillDefinition, reason: String) -> void:
			interaction_feedback.show_message("Không thể trang bị %s: %s" % [skill.display_name if skill != null else "—", reason]))


func _on_player_healed(amount: int) -> void:
	var body: Node2D = player_health.get_parent() as Node2D
	if body != null:
		combat_hud.show_heal(body.global_position + Vector2(0, -30), amount)


## Phản hồi trúng đòn (chỉ hiển thị): số sát thương + HitSpark; mục tiêu bị hạ gục có vòng lớn hơn.
func _on_hit_received(_info: DamageInfo, applied: int, hurtbox: Hurtbox) -> void:
	var defeated: bool = hurtbox.health != null and hurtbox.health.is_dead()
	var is_player: bool = hurtbox.health == player_health
	var position_on_hit: Vector2 = hurtbox.get_hit_position()
	combat_hud.show_damage(position_on_hit, applied, is_player, defeated)
	var effects: Node2D = _effect_container if _effect_container != null else _entity_container
	HitSpark.spawn(effects, position_on_hit, Color(1, 0.45, 0.4) if is_player else Color(1, 1, 0.85), 7.0)
	if defeated:
		HitSpark.spawn(effects, position_on_hit, Color(1, 0.6, 0.2), 18.0)


## Túi đồ / rương / vật phẩm trên đất (TASK M1). Bỏ qua phần nào scene không có.
func _setup_inventory() -> void:
	if player == null:
		return
	var database: ItemDatabase = player.get_inventory().database
	if inventory_window != null:
		inventory_window.bind(player.get_inventory(), player.get_equipment(), database, player)
		inventory_window.can_drop_to_ground = pickup_layer != null
		inventory_window.opened.connect(_refresh_combat_block)
		inventory_window.closed.connect(_refresh_combat_block)
		inventory_window.drop_requested.connect(_on_drop_requested)
		inventory_window.use_requested.connect(_on_use_requested)
		inventory_window.message.connect(_show_feedback)
		for node: Node in find_children("*", "Chest", true, false):
			(node as Chest).open_requested.connect(inventory_window.open_chest)
	if pickup_layer != null:
		if pickup_layer.collector == null:
			pickup_layer.collector = player
		player.get_equipment().overflow_handler = drop_item
		if pickup_toast != null:
			pickup_layer.item_picked.connect(func(item_id: StringName, amount: int) -> void:
				var item: ItemDefinition = database.get_item(item_id)
				pickup_toast.show_pickup(item_id, item.display_name if item != null else String(item_id), amount))
			pickup_layer.pickup_blocked.connect(func(_item_id: StringName) -> void:
				pickup_toast.show_message("Túi đầy — không nhặt được."))


## Vứt stack xuống đất dưới chân Player (cùng tầng). false nếu map không có ItemPickupLayer.
func drop_item(stack: ItemStack) -> bool:
	if pickup_layer == null or player == null or stack == null:
		return false
	var agent: ElevationAgent = ElevationAgent.find_for(player)
	var offset: Vector2 = Vector2(randf_range(-6.0, 6.0), randf_range(2.0, 5.0))
	return pickup_layer.spawn_drop(stack, player.global_position + offset, agent.get_tier() if agent != null else -1) != null


func _on_drop_requested(stack: ItemStack) -> void:
	if not drop_item(stack):
		# Không vứt được: trả lại túi để không mất đồ.
		player.get_inventory().add_stack(stack)
		_show_feedback("Không vứt đồ được ở đây.")


## Chặn đánh thường/kỹ năng khi có bảng UI đang mở (Progression, túi đồ, chế tạo). Di chuyển vẫn được.
func _refresh_combat_block() -> void:
	if player == null:
		return
	var blocked: bool = (progression_panel != null and progression_panel.is_open()) \
		or (inventory_window != null and inventory_window.is_open()) \
		or (crafting_window != null and crafting_window.is_open())
	player.set_combat_input_blocked(blocked)


func _setup_save() -> void:
	SaveService.loaded.connect(_on_game_loaded)
	SaveService.failed.connect(_show_feedback)


func _on_game_loaded(slot: int) -> void:
	if camera != null:
		camera.set_target(camera_target)
	_show_feedback("Đã tải (slot %d)." % slot)


func _show_feedback(message: String) -> void:
	if interaction_feedback != null:
		interaction_feedback.show_message(message)


# --- Thời gian & sinh tồn (TASK M2) ---------------------------------------------------------------

## Bán kính footprint (px mặt đất) khi kiểm tra chỗ dựng lều / lửa trại.
const DEPLOY_FOOTPRINT_RADIUS: float = 14.0

var _tent_menu: PopupMenu
var _tent_menu_target: Tent


func _setup_survival() -> void:
	if player == null:
		return
	var item_user: ItemUser = player.get_item_user()
	item_user.deploy_handler = _deploy_item
	item_user.used.connect(func(_item_id: StringName, message: String) -> void: _show_feedback(message))
	if combat_hud != null:
		combat_hud.bind_survival(player.get_mana(), player.get_stamina(), player.get_hunger(), player.get_buffs())
		combat_hud.set_death_panel_enabled(death_controller == null)
		if clock != null:
			combat_hud.bind_clock(clock)
	if clock != null:
		clock.time_passed.connect(player.pass_game_time)
	if death_marker != null:
		death_marker.tracked = player
	for node: Node in find_children("*", "RestSpot", true, false):
		_connect_rest_spot(node as RestSpot)
	if pickup_layer != null:
		pickup_layer.deployed_added.connect(func(node: Node2D) -> void:
			if node is RestSpot:
				_connect_rest_spot(node as RestSpot))
	if sleep_controller != null:
		sleep_controller.slept.connect(func(day: int) -> void: _show_feedback("Ngày %d — đã ngủ dậy và tự lưu." % day))
		sleep_controller.fainted.connect(func(_day: int) -> void: _show_feedback("Bạn đã ngất vì thức quá khuya."))
	if death_controller != null:
		death_controller.bag_discarded.connect(func(_bag_id: String) -> void:
			_show_feedback("Túi đồ cũ nhất đã biến mất (tối đa %d túi)." % death_controller.max_death_bags))
	player.get_equipment().item_depleted.connect(_on_item_depleted)


## Dùng item ở ô túi (từ cửa sổ túi đồ): ăn, dựng lều...
func use_item(slot: int) -> String:
	var reason: String = player.get_item_user().use_slot(slot)
	if not reason.is_empty():
		_show_feedback(reason)
	return reason


## Menu lều (Ngủ / Thu lều). Trả về menu đang mở.
func open_tent_menu(tent: Tent) -> PopupMenu:
	if _tent_menu == null:
		_tent_menu = PopupMenu.new()
		_tent_menu.id_pressed.connect(func(id: int) -> void: choose_tent_action(_tent_menu_target, id))
		(get_node(^"UILayer") if has_node(^"UILayer") else self).add_child(_tent_menu)
	_tent_menu.clear()
	_tent_menu.add_item("Ngủ", 0)
	_tent_menu.add_item("Thu lều", 1)
	_tent_menu_target = tent
	_tent_menu.reset_size()
	_tent_menu.position = Vector2i(get_viewport().get_mouse_position()) + get_window().position
	_tent_menu.popup()
	return _tent_menu


## 0 = ngủ, 1 = thu lều.
func choose_tent_action(tent: Tent, action: int) -> void:
	if tent == null or not is_instance_valid(tent):
		return
	if action == 0:
		tent.request_sleep()
	else:
		tent.request_pack()


func _connect_rest_spot(spot: RestSpot) -> void:
	if spot.sleep_requested.is_connected(_on_sleep_requested):
		return
	spot.sleep_requested.connect(_on_sleep_requested)
	var tent: Tent = spot as Tent
	if tent != null:
		tent.menu_requested.connect(open_tent_menu)
		tent.pack_requested.connect(_on_tent_pack_requested)


func _on_sleep_requested(spot: RestSpot) -> void:
	if sleep_controller == null:
		_show_feedback("Không ngủ được ở map này.")
		return
	var reason: String = sleep_controller.try_sleep(spot)
	if not reason.is_empty():
		_show_feedback(reason)


func _on_tent_pack_requested(tent: Tent) -> void:
	if player.get_inventory().add(tent.item_id, 1) > 0:
		_show_feedback("Túi đầy, không thu lều được.")
		return
	if sleep_controller != null:
		sleep_controller.forget_spot(tent)
	tent.queue_free()
	_show_feedback("Đã thu lều vào túi.")


func _on_use_requested(slot: int) -> void:
	use_item(slot)


## Đặt item dựng được (lều, lửa trại — TASK M3) tại chỗ Player đứng (hoặc trước mặt `deploy_offset` px mặt đất).
## Giới hạn số lượng mỗi map theo ItemDefinition.max_per_map. "" = thành công, ngược lại là lý do.
func _deploy_item(item: ItemDefinition) -> String:
	if pickup_layer == null:
		return "Không dựng được ở đây."
	if item.max_per_map > 0 and pickup_layer.count_deployed(item.id) >= item.max_per_map:
		if item.max_per_map == 1:
			return "Đã có một %s đang dựng — thu %s cũ trước." % [item.display_name.to_lower(), item.display_name.to_lower()]
		return "Đã đủ %d %s trên map này." % [item.max_per_map, item.display_name.to_lower()]
	var agent: ElevationAgent = ElevationAgent.find_for(player)
	if agent != null and agent.is_transitioning():
		return "Không dựng được trên cầu thang."
	var tier: int = agent.get_tier() if agent != null else -1
	var squash: float = pickup_layer.ground_squash
	var at: Vector2 = player.global_position
	if item.deploy_offset > 0.0:
		var ahead: Vector2 = GroundSpace.direction(player.get_facing(), squash)
		at += GroundSpace.to_screen(ahead * item.deploy_offset, squash)
	var exclude: Array[RID] = []
	for node: Node in [player] + player.find_children("*", "CollisionObject2D", true, false):
		exclude.append((node as CollisionObject2D).get_rid())
	var reason: String = PlacementCheck.get_block_reason(get_world_2d().direct_space_state, self, at, tier,
		DEPLOY_FOOTPRINT_RADIUS, squash, exclude)
	if not reason.is_empty():
		return reason
	pickup_layer.spawn_deployed(item, at, tier)
	return ""


# --- Khai thác, chế tạo, nấu ăn (TASK M3) ---------------------------------------------------------

func _setup_crafting() -> void:
	if player == null:
		return
	var database: ItemDatabase = player.get_inventory().database
	if crafting_window != null and recipe_book != null:
		crafting_window.bind(recipe_book, database, player.get_inventory(), player,
			pickup_layer.ground_squash if pickup_layer != null else 1.0)
		crafting_window.opened.connect(_refresh_combat_block)
		crafting_window.closed.connect(_refresh_combat_block)
		crafting_window.message.connect(_show_feedback)
		for node: Node in find_children("*", "CraftingStation", true, false):
			_connect_station(node as CraftingStation)
		if pickup_layer != null:
			pickup_layer.deployed_added.connect(func(node: Node2D) -> void:
				if node is CraftingStation:
					_connect_station(node as CraftingStation))
	if resource_layer != null and pickup_toast != null:
		resource_layer.harvested.connect(func(_node: ResourceNode, stacks: Array[ItemStack]) -> void:
			for stack: ItemStack in stacks:
				var item: ItemDefinition = database.get_item(stack.item_id)
				pickup_toast.show_pickup(stack.item_id, item.display_name if item != null else String(stack.item_id), stack.count))


## Mở cửa sổ chế tạo tại trạm (bàn chế tạo) hoặc chế độ Nấu (lửa trại).
func open_station(station: CraftingStation) -> void:
	if crafting_window == null:
		return
	if station is Campfire:
		crafting_window.open_campfire(station as Campfire)
	else:
		crafting_window.open()


func _connect_station(station: CraftingStation) -> void:
	if not station.open_requested.is_connected(open_station):
		station.open_requested.connect(open_station)


## Công cụ vỡ / đuốc cháy hết.
func _on_item_depleted(item_id: StringName, _slot_name: StringName) -> void:
	var item: ItemDefinition = player.get_inventory().database.get_item(item_id)
	if item == null:
		return
	_show_feedback("%s đã cháy hết." % item.display_name if item.burn_minutes > 0.0 else "%s đã vỡ!" % item.display_name)


# --- Đêm nguy hiểm: quái đêm (TASK M4) ------------------------------------------------------------

func _setup_night() -> void:
	if enemy_spawner != null:
		enemy_spawner.map_rect = get_map_rect()
		enemy_spawner.enemy_spawned.connect(register_entity)
	if night_banner != null and day_night != null:
		day_night.dusk_warning.connect(night_banner.show_text.bind("Trời sắp tối…"))
		day_night.night_started.connect(night_banner.show_text.bind("Màn đêm buông xuống"))
	if hit_vignette != null and player_health != null:
		hit_vignette.bind(player_health)
	if tier_navigation != null:
		if pickup_layer != null:
			pickup_layer.deployed_added.connect(func(node: Node2D) -> void:
				tier_navigation.request_rebake()
				node.tree_exited.connect(tier_navigation.request_rebake))
		if resource_layer != null:
			resource_layer.harvested.connect(func(node: ResourceNode, _stacks: Array[ItemStack]) -> void:
				if node.depleted:
					tier_navigation.request_rebake())
			resource_layer.regrown.connect(func(_node: ResourceNode) -> void: tier_navigation.request_rebake())
