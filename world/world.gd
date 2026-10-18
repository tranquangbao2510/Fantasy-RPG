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
	_setup_sandbox()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_reset"):
		reset_test_state()
		get_viewport().set_input_as_handled()


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
			progression_panel.opened.connect(player.set_combat_input_blocked.bind(true))
			progression_panel.closed.connect(player.set_combat_input_blocked.bind(false))
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
