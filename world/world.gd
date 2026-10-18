extends Node2D
## Gốc của môi trường game.
## Cung cấp các container và nối các module (camera, interaction UI) với nhau; không chứa logic gameplay.
## Các module khác thêm node vào container qua các hàm public bên dưới.

@export var camera: GameCamera
@export var camera_target: Node2D
@export var map_bounds: MapBounds
@export var interaction_detector: InteractionDetector
@export var interaction_prompt: InteractionPrompt
@export var interaction_feedback: InteractionFeedback
@export var player_health: HealthComponent
@export var combat_hud: CombatHUD

@onready var _environment: Node2D = $Environment
@onready var _map_container: Node2D = $MapContainer
@onready var _entity_container: Node2D = $EntityContainer
@onready var _camera_container: Node2D = $CameraContainer


func _ready() -> void:
	_setup_camera()
	_setup_interaction_ui()
	_setup_combat_hud()


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
	for node: Node in get_tree().get_nodes_in_group(Hurtbox.GROUP):
		var hurtbox: Hurtbox = node as Hurtbox
		if hurtbox != null and is_ancestor_of(hurtbox):
			hurtbox.hit_received.connect(_on_hit_received.bind(hurtbox))


func _on_hit_received(_info: DamageInfo, applied: int, hurtbox: Hurtbox) -> void:
	var defeated: bool = hurtbox.health != null and hurtbox.health.is_dead()
	combat_hud.show_damage(hurtbox.get_hit_position(), applied, hurtbox.health == player_health, defeated)
