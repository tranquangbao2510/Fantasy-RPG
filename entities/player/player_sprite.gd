class_name PlayerSprite
extends AnimatedSprite2D
## Hình nhân vật 8 hướng của Player (TASK CHAR-01). Chỉ hiển thị: đọc trạng thái từ thân, HP, đòn đánh, kỹ năng;
## không đổi logic/chỉ số nào.
##
## - SpriteFrames sinh bằng tools/player_sprites/ từ hero_sprites.json: animation `<tên>_<hướng>`, metadata
##   `anchor` (điểm chân trong canvas, px texel) và `texel_scale` → offset/scale đặt lúc _ready (chân = origin Player).
## - Hướng: hướng nhìn của Player (màn hình) đổi sang mặt phẳng đất (GroundSpace, `squash` nhận qua
##   set_ground_squash — IsoActorAdapter gọi; map cũ giữ 1) rồi làm tròn về 1 trong 8 hướng DIRECTIONS.
## - Ưu tiên: death > attack / cast (cái bắt đầu sau thắng) > hit > run / walk / idle.
##   attack_1/2/3 theo bước combo, tua tốc độ cho đúng windup + active + recovery của bước;
##   cast tua theo cast time; hit/death tua về `hit_duration`/`death_duration`; death giữ frame cuối.
## - Player chỉ có một tốc độ (`move_speed`): chọn run khi tốc độ trên mặt đất ≥ `run_speed_threshold`, walk khi
##   thấp hơn (vd. bị passive làm chậm, trượt dọc tường). Locomotion phát ở fps gốc.

const DIRECTIONS: PackedStringArray = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
const ATTACK_ANIMATIONS: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]

enum Action { NONE, ATTACK, CAST, HIT, DEATH }

@export var body: CharacterBody2D
@export var health: HealthComponent
@export var attack: BasicAttackController
@export var skills: SkillCastingController
## Tốc độ trên mặt đất (px/s) từ đó trở lên dùng run thay cho walk.
@export var run_speed_threshold: float = 110.0
## Dưới tốc độ này (px/s trên mặt đất) coi như đứng yên.
@export var idle_speed_threshold: float = 8.0
## Thời lượng hiển thị animation hit (không chặn input; đang đánh/cast thì không phát).
@export var hit_duration: float = 0.3
## Kỹ năng không có cast time (Instant/không vận sức) vẫn phát cast tối thiểu chừng này.
@export var min_cast_duration: float = 0.35
@export var death_duration: float = 1.5

var _ground_squash: float = 1.0
var _direction: int = 0
var _action: Action = Action.NONE
var _action_base: StringName = &""
var _action_speed: float = 1.0
var _action_time_left: float = 0.0
var _action_direction: int = 0
var _restart_pending: bool = false
var _base: StringName = &""


## Hàng sheet (chỉ số trong DIRECTIONS) cho một hướng màn hình, đo trên mặt đất. S = (0, 1) trên mặt đất (về camera);
## góc tăng theo chiều kim đồng hồ trên màn hình (y hướng xuống) đúng thứ tự S, SW, W, ...
static func direction_index(screen_direction: Vector2, squash: float) -> int:
	var ground: Vector2 = GroundSpace.to_ground(screen_direction, squash)
	if ground.is_zero_approx():
		return 0
	return posmod(roundi((ground.angle() - PI * 0.5) / (PI * 0.25)), DIRECTIONS.size())


## Animation cho bước combo (0-based). Vũ khí > 3 bước quay vòng attack_1/2/3.
static func attack_animation(step_index: int) -> StringName:
	return ATTACK_ANIMATIONS[posmod(step_index, ATTACK_ANIMATIONS.size())]


## Hệ số speed_scale để animation dài `native_duration` giây phát hết trong `target_duration` giây.
static func speed_scale_for(native_duration: float, target_duration: float) -> float:
	return native_duration / target_duration if target_duration > 0.0 else 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if sprite_frames != null:
		centered = false
		offset = -(sprite_frames.get_meta(&"anchor", Vector2.ZERO) as Vector2)
		var texel_scale: float = sprite_frames.get_meta(&"texel_scale", 1.0)
		scale = Vector2(texel_scale, texel_scale)
	if health != null:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
		health.revived.connect(_on_revived)
	if attack != null:
		attack.step_started.connect(_on_attack_step_started)
	if skills != null:
		skills.cast_started.connect(_on_cast_started)
		skills.cast_cancelled.connect(_on_cast_cancelled)
	_refresh()
	play()


func set_ground_squash(squash: float) -> void:
	_ground_squash = squash


## Hướng nhìn hiện tại (màn hình); Player gọi mỗi khi đổi hướng.
func set_facing(screen_direction: Vector2) -> void:
	_direction = direction_index(screen_direction, _ground_squash)


func get_direction_name() -> String:
	return DIRECTIONS[_action_direction if _locks_direction() else _direction]


func get_action() -> Action:
	return _action


## Tên animation gốc (không hướng) đang phát: idle, walk, run, attack_1..3, cast, hit, death.
func get_animation_base() -> StringName:
	return _base


## Thời lượng gốc (giây) của một animation theo fps trong JSON.
func get_native_duration(base: StringName) -> float:
	var animation_name: StringName = StringName("%s_%s" % [base, DIRECTIONS[0]])
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		return 0.0
	return sprite_frames.get_frame_count(animation_name) / sprite_frames.get_animation_speed(animation_name)


## Thời lượng thực của action đang phát (giây) sau khi tua.
func get_action_duration() -> float:
	return get_native_duration(_action_base) / _action_speed


func _physics_process(delta: float) -> void:
	if _action_time_left > 0.0:
		_action_time_left -= delta
		if _action_time_left <= 0.0 and (_action == Action.CAST or _action == Action.HIT):
			_action = Action.NONE
	if _action == Action.ATTACK and not _restart_pending and (attack == null or not attack.is_attacking()):
		_action = Action.NONE
	_refresh()


func _start_action(action: Action, base: StringName, duration: float) -> void:
	_action = action
	_action_base = base
	_action_speed = speed_scale_for(get_native_duration(base), duration)
	_action_time_left = duration
	_restart_pending = true


func _locks_direction() -> bool:
	return _action == Action.ATTACK or _action == Action.CAST or _action == Action.DEATH


func _locomotion_base() -> StringName:
	var speed: float = GroundSpace.length(body.get_real_velocity(), _ground_squash) if body != null else 0.0
	if speed < idle_speed_threshold:
		return &"idle"
	return &"run" if speed >= run_speed_threshold else &"walk"


func _refresh() -> void:
	if sprite_frames == null:
		return
	var base: StringName = _action_base if _action != Action.NONE else _locomotion_base()
	if _restart_pending:
		_action_direction = _direction
	var animation_name: StringName = StringName("%s_%s" % [base, get_direction_name()])
	if _restart_pending:
		_restart_pending = false
		speed_scale = _action_speed
		play(animation_name)
		set_frame_and_progress(0, 0.0)
	elif animation_name != animation:
		# Đổi hướng giữa chừng: giữ nhịp (mọi hướng cùng số frame); đổi loại animation: phát từ đầu.
		var keep_frame: int = frame
		var keep_progress: float = frame_progress
		speed_scale = _action_speed if _action != Action.NONE else 1.0
		play(animation_name)
		if base == _base:
			set_frame_and_progress(keep_frame, keep_progress)
	_base = base


func _on_attack_step_started(step_index: int, _step_count: int, _direction_vector: Vector2) -> void:
	if _action == Action.DEATH:
		return
	var step: ComboStepDefinition = attack.get_step(step_index)
	var duration: float = step.windup + step.active + step.recovery if step != null else 0.0
	_start_action(Action.ATTACK, attack_animation(step_index), duration)


func _on_cast_started(_slot: int, cast_time: float) -> void:
	if _action == Action.DEATH:
		return
	_start_action(Action.CAST, &"cast", maxf(cast_time, min_cast_duration))


func _on_cast_cancelled(_slot: int) -> void:
	if _action == Action.CAST:
		_action = Action.NONE


func _on_damaged(_amount: int) -> void:
	if health.is_dead() or _action == Action.ATTACK or _action == Action.CAST or _action == Action.DEATH:
		return
	_start_action(Action.HIT, &"hit", hit_duration)


func _on_died() -> void:
	_start_action(Action.DEATH, &"death", death_duration)


func _on_revived() -> void:
	_action = Action.NONE
	_action_time_left = 0.0
	_restart_pending = false
