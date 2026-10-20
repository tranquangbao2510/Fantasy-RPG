class_name Player
extends CharacterBody2D
## Player: di chuyển liên tục 8 hướng và điều phối các component (combat, interaction, health).
## Origin đặt tại chân nhân vật để Y-sort đúng trong EntityContainer. Hình: Visual/Sprite (PlayerSprite, 8 hướng).
## Combo đánh thường nằm trong BasicAttackController (dữ liệu từ vũ khí đang trang bị), HP trong HealthComponent;
## Class/passive/progression nằm trong ClassManager, PassiveController, CharacterLevel.
## Sinh tồn (TASK M2): Mana, Stamina, Đói, Buff, ItemUser là component con; script này chỉ đọc input và nối trạng thái.
## - Chạy: giữ `sprint` (Shift) khi đang đi → tốc độ × sprint_multiplier, tiêu stamina + đói theo giây.
## - Né: `dodge` (Space) → lướt `dodge_distance` px trên MẶT ĐẤT theo hướng phím (đứng yên: hướng nhìn) trong
##   `dodge_duration` giây bằng move_and_slide (vách/nước/tầng vẫn chặn), bất tử `dodge_invulnerable_time`, hủy combo
##   và vận sức đang chạy; cần đủ stamina, có cooldown.

## Né xong (sprite dùng để phát animation lướt).
signal dodged(duration: float)

@export var move_speed: float = 160.0
## Hệ số vận tốc theo trục dọc màn hình. 1 = map top-down cũ; 0.5 = map isometric 2:1 (tốc độ đều trên mặt phẳng đất,
## nhấn chéo đi đúng theo trục lưới thoi). Hướng phím vẫn theo màn hình (W = lên màn hình).
@export var vertical_speed_scale: float = 1.0
@export var mobility: MobilitySettings

## Điểm tỉnh dậy / hồi sinh hiện tại (SleepController đặt): {map_id, kind: "bed"/"tent", id}. Rỗng = chưa có.
var respawn_point: Dictionary = {}

## Hướng nhìn cuối cùng; dùng khi chuột trùng vị trí Player.
var _facing: Vector2 = Vector2.DOWN
var _spawn_position: Vector2
## Khi một bảng UI đang nhận input (vd. Progression Panel): bỏ qua đánh thường, kỹ năng và né.
var _combat_input_blocked: bool = false
## Đang ngủ / chết (màn hình mờ): không nhận điều khiển nào.
var _control_locked: bool = false
var _ground_squash: float = 1.0
var _sprinting: bool = false
var _dodge_left: float = 0.0
## Quãng lướt còn lại (px mặt đất) — lướt đúng dodge_distance bất kể nhịp physics.
var _dodge_remaining: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_velocity: Vector2 = Vector2.ZERO

@onready var _sprite: PlayerSprite = $Visual/Sprite
@onready var _passives: PassiveController = $PassiveController
@onready var _classes: ClassManager = $ClassManager
@onready var _health: HealthComponent = $HealthComponent
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _attack: BasicAttackController = $BasicAttackController
@onready var _interaction_detector: InteractionDetector = $InteractionDetector
@onready var _skills: SkillCastingController = $SkillCastingController
@onready var _skill_loadout: SkillLoadout = $SkillLoadout
@onready var _level: CharacterLevel = $CharacterLevel
@onready var _inventory: Inventory = $Inventory
@onready var _equipment: EquipmentSlots = $EquipmentSlots
@onready var _mana: ManaComponent = $ManaComponent
@onready var _stamina: StaminaComponent = $StaminaComponent
@onready var _hunger: HungerComponent = $HungerComponent
@onready var _buffs: BuffComponent = $BuffComponent
@onready var _item_user: ItemUser = $ItemUser


func _ready() -> void:
	_spawn_position = global_position
	if mobility == null:
		mobility = MobilitySettings.new()
	_health.died.connect(_on_died)
	_attack.set_aim_provider(_get_attack_direction)
	_attack.step_started.connect(_on_attack_step_started)
	_skills.set_aim_provider(get_global_mouse_position)
	_skills.cast_started.connect(_on_skill_cast_started)


func _physics_process(delta: float) -> void:
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	if is_dead() or _control_locked:
		velocity = Vector2.ZERO
		_sprinting = false
		_dodge_left = 0.0
		return
	if _dodge_left > 0.0:
		var step: float = mobility.get_dodge_speed() * delta
		velocity = _dodge_velocity * minf(1.0, _dodge_remaining / maxf(step, 0.0001))
		_dodge_remaining -= step
		move_and_slide()
		if _dodge_remaining <= 0.0:
			_dodge_left = 0.0
			_dodge_cooldown = mobility.dodge_cooldown
		return
	# get_vector giới hạn độ dài <= 1 nên đi chéo không nhanh hơn đi thẳng.
	var direction: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_sprinting = direction != Vector2.ZERO and Input.is_action_pressed(&"sprint") and _stamina.can_sprint()
	var speed: float = move_speed * _passives.get_move_speed_multiplier() * _buffs.get_multiplier(BuffDefinition.Stat.MOVE_SPEED)
	if _sprinting:
		speed *= mobility.sprint_multiplier
		_stamina.drain_sprint(delta)
		_hunger.exert(Activity.Kind.SPRINT, delta)
	velocity = direction * Vector2(1.0, vertical_speed_scale) * speed
	move_and_slide()
	if direction != Vector2.ZERO and not _attack.is_attacking():
		_set_facing(direction)


## Đầu mối input combat: kỹ năng được hỏi trước (phím ô, xác nhận/hủy ngắm);
## chỉ khi kỹ năng không dùng event và không đang ngắm/vận sức thì click trái mới là đánh thường.
func _unhandled_input(event: InputEvent) -> void:
	if _combat_input_blocked or _control_locked:
		return
	if event.is_action_pressed(&"dodge"):
		try_dodge()
		get_viewport().set_input_as_handled()
		return
	if _skills.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"basic_attack") and not is_dead() and not _skills.is_busy():
		_attack.request_attack()
		get_viewport().set_input_as_handled()


func is_dead() -> bool:
	return _health.is_dead()


func is_sprinting() -> bool:
	return _sprinting


func is_dodging() -> bool:
	return _dodge_left > 0.0


## Né theo hướng phím đang giữ (đứng yên: hướng nhìn). false nếu đang né/hồi né, thiếu stamina hoặc đã chết.
func try_dodge() -> bool:
	if is_dead() or _control_locked or _dodge_left > 0.0 or _dodge_cooldown > 0.0 or not _stamina.try_dodge():
		return false
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var screen_direction: Vector2 = input * Vector2(1.0, vertical_speed_scale) if input != Vector2.ZERO else _facing
	var ground: Vector2 = GroundSpace.direction(screen_direction, _ground_squash)
	_dodge_velocity = GroundSpace.to_screen(ground * mobility.get_dodge_speed(), _ground_squash)
	_dodge_left = mobility.dodge_duration
	_dodge_remaining = mobility.dodge_distance
	_attack.cancel()
	_skills.cancel_cast()
	_hurtbox.set_invulnerable(mobility.dodge_invulnerable_time)
	_hunger.exert(Activity.Kind.DODGE)
	if input != Vector2.ZERO:
		_set_facing(input)
	dodged.emit(mobility.dodge_duration)
	return true


## Map isometric (IsoActorAdapter gọi): quãng né đo trên mặt đất.
func set_ground_squash(squash: float) -> void:
	_ground_squash = squash


## Chặn/mở input combat (đánh thường, kỹ năng, né) khi UI đang nhận input. Chặn sẽ hủy ngắm/vận sức và combo đang chạy.
## Di chuyển không bị chặn.
func set_combat_input_blocked(blocked: bool) -> void:
	_combat_input_blocked = blocked
	if blocked:
		_skills.cancel_all()
		_attack.cancel()


func is_combat_input_blocked() -> bool:
	return _combat_input_blocked


## Khóa toàn bộ điều khiển (đang ngủ, đang chết/hồi sinh — màn hình mờ).
func set_control_locked(locked: bool) -> void:
	_control_locked = locked
	velocity = Vector2.ZERO
	if locked:
		_skills.cancel_all()
		_attack.cancel()


func is_control_locked() -> bool:
	return _control_locked


## Reset thử nghiệm: về spawn, hồi đầy HP, xóa vận tốc và combo đang đánh, bật lại tương tác.
func reset_state() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_dodge_left = 0.0
	_attack.cancel()
	_skills.cancel_all()
	_skill_loadout.reset_runtimes()
	_classes.reset_skill_runtimes()
	_health.reset()
	_interaction_detector.set_enabled(true)
	_set_facing(Vector2.DOWN)


## Hồi sinh / tỉnh dậy tại vị trí + tầng cho trước với `health_percent` HP (TASK M2: chết, ngất, ngủ dậy ở chỗ khác).
func respawn_at(at: Vector2, tier: int, health_percent: float) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_dodge_left = 0.0
	_attack.cancel()
	_skills.cancel_all()
	_health.restore(maxi(1, roundi(_health.max_health * health_percent)))
	_interaction_detector.set_enabled(true)
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	if agent != null:
		agent.set_tier(tier)


func get_health() -> HealthComponent:
	return _health


func get_mana() -> ManaComponent:
	return _mana


func get_stamina() -> StaminaComponent:
	return _stamina


func get_hunger() -> HungerComponent:
	return _hunger


func get_buffs() -> BuffComponent:
	return _buffs


func get_item_user() -> ItemUser:
	return _item_user


## Thời gian game trôi (World nối từ GameClock.time_passed).
func pass_game_time(minutes: float, sleeping: bool) -> void:
	_hunger.pass_time(minutes, sleeping)


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
	_hunger.exert(Activity.Kind.SKILL)
	var target: SkillTarget = _skills.get_current_target()
	if target != null and not target.direction.is_zero_approx():
		_set_facing(target.direction)


func _on_attack_step_started(_step_index: int, _step_count: int, direction: Vector2) -> void:
	_hunger.exert(Activity.Kind.ATTACK)
	_set_facing(direction)


func _on_died() -> void:
	velocity = Vector2.ZERO
	_dodge_left = 0.0
	_attack.cancel()
	_skills.cancel_all()
	_interaction_detector.set_enabled(false)


func get_inventory() -> Inventory:
	return _inventory


func get_equipment() -> EquipmentSlots:
	return _equipment


# --- Save (TASK M1, M2) --------------------------------------------------------------------------
# Player trong group `saveable`, đi theo người chơi qua mọi map (global). Thứ tự khôi phục: class/level (passive đổi
# max HP) → trang bị (luật vũ khí theo class) → túi → HP → chỉ số sinh tồn → vị trí/tầng.

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
		"survival": {
			"mana": snappedf(_mana.current, 0.01),
			"stamina": snappedf(_stamina.current, 0.01),
			"hunger": snappedf(_hunger.value, 0.01),
			"respawn": respawn_point.duplicate(),
		},
	}


## Field thiếu → giữ giá trị hiện tại của scene (vị trí spawn, HP đầy, chỉ số đầy...). HP ≤ 0 trong save → hồi đầy.
func load_state(state: Dictionary) -> void:
	_attack.cancel()
	_skills.cancel_all()
	velocity = Vector2.ZERO
	_dodge_left = 0.0
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
	var survival: Dictionary = state.get("survival", {}) if state.get("survival") is Dictionary else {}
	_mana.load_value(survival.get("mana"))
	_stamina.load_value(survival.get("stamina"))
	_hunger.load_value(survival.get("hunger"))
	respawn_point = survival.get("respawn", {}) if survival.get("respawn") is Dictionary else {}
	_buffs.clear()
	var saved_position: Variant = state.get("position")
	if saved_position is Array and saved_position.size() == 2 and (saved_position[0] is float or saved_position[0] is int) \
			and (saved_position[1] is float or saved_position[1] is int):
		global_position = Vector2(saved_position[0], saved_position[1])
	_interaction_detector.set_enabled(true)
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	if agent != null:
		var tier: Variant = state.get("tier", -1)
		agent.set_tier(int(tier) if (tier is int or tier is float) else -1)
