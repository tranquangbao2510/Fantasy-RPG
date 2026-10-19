class_name Player
extends CharacterBody2D
## Player: di chuyển liên tục 8 hướng và điều phối các component (combat, interaction, health).
## Origin đặt tại chân nhân vật để Y-sort đúng trong EntityContainer. Hình: Visual/Sprite (PlayerSprite, 8 hướng).
## Combo đánh thường nằm trong BasicAttackController (dữ liệu từ vũ khí đang trang bị), HP trong HealthComponent;
## Class/passive/progression nằm trong ClassManager, PassiveController, CharacterLevel.
## script này chỉ đọc input và nối trạng thái.

@export var move_speed: float = 160.0
## Hệ số vận tốc theo trục dọc màn hình. 1 = map top-down cũ; 0.5 = map isometric 2:1 (tốc độ đều trên mặt phẳng đất,
## nhấn chéo đi đúng theo trục lưới thoi). Hướng phím vẫn theo màn hình (W = lên màn hình).
@export var vertical_speed_scale: float = 1.0

## Hướng nhìn cuối cùng; dùng khi chuột trùng vị trí Player.
var _facing: Vector2 = Vector2.DOWN
var _spawn_position: Vector2
## Khi một bảng UI đang nhận input (vd. Progression Panel): bỏ qua đánh thường và kỹ năng.
var _combat_input_blocked: bool = false

@onready var _sprite: PlayerSprite = $Visual/Sprite
@onready var _passives: PassiveController = $PassiveController
@onready var _classes: ClassManager = $ClassManager
@onready var _health: HealthComponent = $HealthComponent
@onready var _attack: BasicAttackController = $BasicAttackController
@onready var _interaction_detector: InteractionDetector = $InteractionDetector
@onready var _skills: SkillCastingController = $SkillCastingController
@onready var _skill_loadout: SkillLoadout = $SkillLoadout
@onready var _level: CharacterLevel = $CharacterLevel
@onready var _inventory: Inventory = $Inventory
@onready var _equipment: EquipmentSlots = $EquipmentSlots


func _ready() -> void:
	_spawn_position = global_position
	_health.died.connect(_on_died)
	_attack.set_aim_provider(_get_attack_direction)
	_attack.step_started.connect(_on_attack_step_started)
	_skills.set_aim_provider(get_global_mouse_position)
	_skills.cast_started.connect(_on_skill_cast_started)


func _physics_process(_delta: float) -> void:
	if is_dead():
		velocity = Vector2.ZERO
		return
	# get_vector giới hạn độ dài <= 1 nên đi chéo không nhanh hơn đi thẳng.
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = direction * Vector2(1.0, vertical_speed_scale) * move_speed * _passives.get_move_speed_multiplier()
	move_and_slide()
	if direction != Vector2.ZERO and not _attack.is_attacking():
		_set_facing(direction)


## Đầu mối input combat: kỹ năng được hỏi trước (phím ô, xác nhận/hủy ngắm);
## chỉ khi kỹ năng không dùng event và không đang ngắm/vận sức thì click trái mới là đánh thường.
func _unhandled_input(event: InputEvent) -> void:
	if _combat_input_blocked:
		return
	if _skills.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"basic_attack") and not is_dead() and not _skills.is_busy():
		_attack.request_attack()
		get_viewport().set_input_as_handled()


func is_dead() -> bool:
	return _health.is_dead()


## Chặn/mở input combat (đánh thường, kỹ năng) khi UI đang nhận input. Chặn sẽ hủy ngắm/vận sức và combo đang chạy.
## Di chuyển không bị chặn.
func set_combat_input_blocked(blocked: bool) -> void:
	_combat_input_blocked = blocked
	if blocked:
		_skills.cancel_all()
		_attack.cancel()


func is_combat_input_blocked() -> bool:
	return _combat_input_blocked


## Reset thử nghiệm: về spawn, hồi đầy HP, xóa vận tốc và combo đang đánh, bật lại tương tác.
func reset_state() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_attack.cancel()
	_skills.cancel_all()
	_skill_loadout.reset_runtimes()
	_classes.reset_skill_runtimes()
	_health.reset()
	_interaction_detector.set_enabled(true)
	_set_facing(Vector2.DOWN)


func get_health() -> HealthComponent:
	return _health


## Đặt điểm spawn mới (vd. tình huống sandbox) rồi reset_state() để đưa Player về đó an toàn.
func set_spawn_position(spawn: Vector2) -> void:
	_spawn_position = spawn


## Hướng tấn công từ điểm đánh tới world_point; điểm quá gần thì dùng hướng nhìn hiện tại.
func get_aim_direction(world_point: Vector2) -> Vector2:
	var to_point: Vector2 = world_point - _attack.global_position
	return to_point.normalized() if to_point.length() > 4.0 else _facing


func _get_attack_direction() -> Vector2:
	return get_aim_direction(get_global_mouse_position())


func _set_facing(direction: Vector2) -> void:
	_facing = direction.normalized()
	_sprite.set_facing(_facing)
	_skills.fallback_direction = _facing


func _on_skill_cast_started(_slot: int, _cast_time: float) -> void:
	var target: SkillTarget = _skills.get_current_target()
	if target != null and not target.direction.is_zero_approx():
		_set_facing(target.direction)


func _on_attack_step_started(_step_index: int, _step_count: int, direction: Vector2) -> void:
	_set_facing(direction)


func _on_died() -> void:
	velocity = Vector2.ZERO
	_attack.cancel()
	_skills.cancel_all()
	_interaction_detector.set_enabled(false)


func get_inventory() -> Inventory:
	return _inventory


func get_equipment() -> EquipmentSlots:
	return _equipment


# --- Save (TASK M1) ------------------------------------------------------------------------------
# Player trong group `saveable`, đi theo người chơi qua mọi map (global). Thứ tự khôi phục: class/level (passive đổi
# max HP) → trang bị (luật vũ khí theo class) → túi → HP → vị trí/tầng.

func get_save_id() -> String:
	return "player"


func is_save_global() -> bool:
	return true


func save_state() -> Dictionary:
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	return {
		"position": [snappedf(global_position.x, 0.01), snappedf(global_position.y, 0.01)],
		"tier": agent.get_tier() if agent != null else -1,
		"health": _health.current_health,
		"level": _level.to_dict(),
		"classes": _classes.to_dict(),
		"equipment": _equipment.to_dict(),
		"inventory": _inventory.to_dict(),
	}


## Field thiếu → giữ giá trị hiện tại của scene (vị trí spawn, HP đầy...). HP ≤ 0 trong save → hồi đầy (tỉnh lại).
func load_state(state: Dictionary) -> void:
	_attack.cancel()
	_skills.cancel_all()
	velocity = Vector2.ZERO
	if state.has("level"):
		_level.load_dict(state["level"])
	if state.has("classes"):
		_classes.load_dict(state["classes"])
	if state.has("equipment"):
		_equipment.load_dict(state["equipment"])
	if state.has("inventory"):
		_inventory.load_dict(state["inventory"])
	var hp: Variant = state.get("health")
	_health.restore(int(hp) if (hp is int or hp is float) and int(hp) > 0 else _health.max_health)
	var saved_position: Variant = state.get("position")
	if saved_position is Array and saved_position.size() == 2 and (saved_position[0] is float or saved_position[0] is int) \
			and (saved_position[1] is float or saved_position[1] is int):
		global_position = Vector2(saved_position[0], saved_position[1])
	_interaction_detector.set_enabled(true)
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	if agent != null:
		var tier: Variant = state.get("tier", -1)
		agent.set_tier(int(tier) if (tier is int or tier is float) else -1)
