class_name SkillCastingController
extends Node2D
## Thi triển kỹ năng từ SkillLoadout: IDLE → (TARGETING) → CASTING → effect → IDLE.
## Một controller cho mọi kỹ năng; khác biệt nằm trong SkillDefinition và cast mode của ô.
##
## - NORMAL: nhấn phím ô → TARGETING; click trái (basic_attack) xác nhận; skill_cancel hủy.
## - QUICK: giữ phím ô → TARGETING; thả đúng phím đó xác nhận; skill_cancel trong lúc giữ thì thả không cast.
## - INSTANT: nhấn phím ô → chốt điểm ngắm lúc nhấn, vào CASTING ngay.
## Charge chỉ bị tiêu khi bắt đầu CASTING (không tiêu lúc ngắm). Effect chạy đúng 1 lần trong physics tick
## khi hết cast_time. Đang TARGETING/CASTING thì không bắt đầu kỹ năng khác (phím ô khác khi đang ngắm = hủy ngắm rồi thử ô mới).
## Người gọi chuyển input qua handle_input(); hàm trả về true nếu đã dùng event (để không đánh thường cùng click).

signal targeting_started(slot: int)
signal targeting_ended(slot: int, confirmed: bool)
signal cast_started(slot: int, cast_time: float)
## result: số mục tiêu trúng (DAMAGE) hoặc HP hồi (HEAL).
signal cast_finished(slot: int, result: int)
signal cast_cancelled(slot: int)
signal cast_rejected(slot: int, reason: String)

enum State { IDLE, TARGETING, CASTING }

const SLOT_ACTIONS: Array[StringName] = [&"skill_slot_1", &"skill_slot_2", &"skill_slot_3", &"skill_slot_4"]
const CONFIRM_ACTION: StringName = &"basic_attack"
const CANCEL_ACTION: StringName = &"skill_cancel"

@export var loadout: SkillLoadout
## HP của người thi triển; chết thì hủy mọi thứ, effect HEAL hồi vào đây.
@export var health: HealthComponent
## Hurtbox layer phe đối địch mà effect DAMAGE nhắm tới.
@export_flags_2d_physics var target_layers: int = 0

## Hướng dùng khi điểm ngắm trùng người thi triển.
var fallback_direction: Vector2 = Vector2.DOWN

var _state: State = State.IDLE
var _slot: int = -1
var _target: SkillTarget
var _cast_left: float = 0.0
var _cast_total: float = 0.0
var _aim_provider: Callable
## Runtime đang vận sức (giữ tham chiếu vì ô có thể bị gỡ/đổi trong lúc vận sức).
var _cast_runtime: SkillRuntime
## Map isometric: tỉ lệ dọc mặt đất (vùng kỹ năng đo trên mặt đất) và tầng của người cast. Xem set_ground_squash / set_elevation.
var _ground_squash: float = 1.0
var _tier_mask: int = 0

@onready var _indicator: SkillAreaVisual = $Indicator
@onready var _effect_flash: SkillAreaVisual = $EffectFlash


func _ready() -> void:
	if loadout != null:
		loadout.slot_changed.connect(_on_slot_changed)
		loadout.cast_mode_changed.connect(_on_cast_mode_changed)
	if health != null:
		health.died.connect(cancel_all)


## Callable trả về điểm ngắm (world coordinates), vd. vị trí chuột.
func set_aim_provider(provider: Callable) -> void:
	_aim_provider = provider


func get_state() -> State:
	return _state


## Ô đang ngắm/thi triển; -1 nếu IDLE.
func get_active_slot() -> int:
	return _slot


func is_busy() -> bool:
	return _state != State.IDLE


func is_targeting() -> bool:
	return _state == State.TARGETING


## Tiến độ vận sức 0..1 (−1 nếu không CASTING).
func get_cast_progress() -> float:
	if _state != State.CASTING:
		return -1.0
	return 1.0 if _cast_total <= 0.0 else clampf(1.0 - _cast_left / _cast_total, 0.0, 1.0)


## Mục tiêu hiện tại (đang ngắm: theo chuột; đang cast: đã chốt). null nếu IDLE.
func get_current_target() -> SkillTarget:
	return _target


func get_indicator() -> SkillAreaVisual:
	return _indicator


## Xử lý input liên quan kỹ năng. Trả về true nếu event đã được dùng.
func handle_input(event: InputEvent) -> bool:
	for slot: int in SLOT_ACTIONS.size():
		if event.is_action(SLOT_ACTIONS[slot]):
			if event.is_echo():
				return true
			if event.is_pressed():
				_on_slot_pressed(slot)
			else:
				_on_slot_released(slot)
			return true
	if _state == State.TARGETING and event.is_action_pressed(CONFIRM_ACTION):
		# Đang ngắm: click trái chỉ dành cho kỹ năng (xác nhận NORMAL; QUICK bỏ qua), không đánh thường.
		if loadout.get_cast_mode(_slot) == SkillDefinition.CastMode.NORMAL:
			confirm_targeting()
		return true
	if event.is_action_pressed(CANCEL_ACTION):
		return cancel_current()
	return false


## Xác nhận mục tiêu đang ngắm và bắt đầu thi triển.
func confirm_targeting() -> void:
	if _state != State.TARGETING:
		return
	var slot: int = _slot
	var runtime: SkillRuntime = loadout.get_runtime(slot)
	if runtime == null or not runtime.can_cast():
		cancel_targeting()
		cast_rejected.emit(slot, runtime.get_block_reason() if runtime != null else "Ô trống")
		return
	var target: SkillTarget = _resolve_target(runtime.definition)
	_indicator.clear()
	_state = State.IDLE
	_slot = -1
	targeting_ended.emit(slot, true)
	_begin_cast(slot, target)


func cancel_targeting() -> void:
	if _state != State.TARGETING:
		return
	var slot: int = _slot
	_indicator.clear()
	_state = State.IDLE
	_slot = -1
	_target = null
	targeting_ended.emit(slot, false)


## Hủy lần vận sức đang chạy. Charge đã tiêu không được hoàn lại (prototype).
func cancel_cast() -> void:
	if _state != State.CASTING:
		return
	var slot: int = _slot
	var runtime: SkillRuntime = _cast_runtime
	if runtime != null:
		runtime.is_casting = false
	_indicator.clear()
	_state = State.IDLE
	_slot = -1
	_target = null
	_cast_runtime = null
	cast_cancelled.emit(slot)


## Hủy mức hiện tại (ngắm trước, rồi vận sức). Trả về true nếu có gì bị hủy.
func cancel_current() -> bool:
	match _state:
		State.TARGETING:
			cancel_targeting()
			return true
		State.CASTING:
			cancel_cast()
			return true
	return false


## Hủy mọi trạng thái (chết, reset).
func cancel_all() -> void:
	cancel_targeting()
	cancel_cast()
	_effect_flash.clear()


func _process(_delta: float) -> void:
	if _state == State.TARGETING:
		var runtime: SkillRuntime = loadout.get_runtime(_slot)
		if runtime == null:
			cancel_targeting()
			return
		_target = _resolve_target(runtime.definition)
		_indicator.show_area(runtime.definition, _target, runtime.definition.indicator_color)


func _physics_process(delta: float) -> void:
	if _state != State.CASTING:
		return
	if health != null and health.is_dead():
		cancel_all()
		return
	_cast_left -= delta
	if _cast_left <= 0.0:
		_execute()


func _on_slot_pressed(slot: int) -> void:
	if health != null and health.is_dead():
		cast_rejected.emit(slot, "Đã bị hạ gục")
		return
	if _state == State.CASTING:
		cast_rejected.emit(slot, "Đang thi triển")
		return
	if _state == State.TARGETING:
		var same_slot: bool = slot == _slot
		cancel_targeting()
		if same_slot:
			return
	var runtime: SkillRuntime = loadout.get_runtime(slot)
	if runtime == null:
		cast_rejected.emit(slot, "Ô trống")
		return
	if not runtime.can_cast():
		cast_rejected.emit(slot, runtime.get_block_reason())
		return
	if runtime.cast_mode == SkillDefinition.CastMode.INSTANT:
		_begin_cast(slot, _resolve_target(runtime.definition))
	else:
		_state = State.TARGETING
		_slot = slot
		_target = _resolve_target(runtime.definition)
		_indicator.show_area(runtime.definition, _target, runtime.definition.indicator_color)
		targeting_started.emit(slot)


func _on_slot_released(slot: int) -> void:
	if _state == State.TARGETING and slot == _slot and loadout.get_cast_mode(slot) == SkillDefinition.CastMode.QUICK:
		confirm_targeting()


func _begin_cast(slot: int, target: SkillTarget) -> void:
	var runtime: SkillRuntime = loadout.get_runtime(slot)
	if runtime == null or not runtime.consume():
		cast_rejected.emit(slot, runtime.get_block_reason() if runtime != null else "Ô trống")
		return
	runtime.is_casting = true
	_cast_runtime = runtime
	_state = State.CASTING
	_slot = slot
	_target = target
	_cast_total = runtime.definition.cast_time
	_cast_left = _cast_total
	if _cast_total > 0.0:
		_indicator.show_area(runtime.definition, target, Color(runtime.definition.indicator_color, runtime.definition.indicator_color.a * 0.5))
	cast_started.emit(slot, _cast_total)


func _execute() -> void:
	var slot: int = _slot
	var runtime: SkillRuntime = _cast_runtime
	var target: SkillTarget = _target
	_indicator.clear()
	_state = State.IDLE
	_slot = -1
	_target = null
	_cast_runtime = null
	if runtime == null:
		return
	runtime.is_casting = false
	var definition: SkillDefinition = runtime.definition
	var result: int = SkillEffectExecutor.execute(definition, target, owner, health,
		get_world_2d().direct_space_state, target_layers, _tier_mask)
	_effect_flash.flash(definition, target, Color(definition.indicator_color, 0.6))
	cast_finished.emit(slot, result)


func _resolve_target(definition: SkillDefinition) -> SkillTarget:
	var aim: Vector2 = _aim_provider.call() if _aim_provider.is_valid() else global_position + fallback_direction
	return SkillTarget.resolve(definition, global_position, aim, fallback_direction, _ground_squash)


func set_ground_squash(squash: float) -> void:
	_ground_squash = squash


## Cấu hình từ hệ thống elevation: kỹ năng chỉ trúng mục tiêu cùng tầng; indicator/flash (top_level) vẽ ở z của tầng.
func set_elevation(tier_mask: int, _obstacle_mask: int, ground_z: int) -> void:
	_tier_mask = tier_mask
	_indicator.z_index = ground_z
	_effect_flash.z_index = ground_z


func _on_slot_changed(slot: int, _definition: SkillDefinition) -> void:
	if slot == _slot:
		cancel_all()


func _on_cast_mode_changed(slot: int, _mode: SkillDefinition.CastMode) -> void:
	if slot == _slot and _state == State.TARGETING:
		cancel_targeting()
