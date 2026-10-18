class_name BasicAttackController
extends Node2D
## Chạy chuỗi đánh thường từ ComboDefinition của vũ khí đang trang bị (WeaponEquipment).
## Một controller dùng cho mọi vũ khí; khác biệt nằm hoàn toàn trong dữ liệu.
##
## Mỗi bước: WINDUP → ACTIVE (Hitbox bật) → RECOVERY → LINK (cửa sổ nối bước kế) → READY.
## - Nhấn khi READY: bước 1. Nhấn trong LINK: bước kế. Hết LINK hoặc xong bước cuối: về bước 1.
## - Nhấn khi đang đánh: chỉ ghi nhớ (1 lần) nếu còn ≤ input_buffer giây tới hết recovery; nếu sớm hơn thì bỏ qua.
##   Lần nhấn được ghi nhớ chạy ngay khi recovery kết thúc (không bỏ qua recovery).
## - Hướng đánh chốt lúc bắt đầu mỗi bước; chỉ xoay node này (Hitbox + visual), không xoay thực thể.
## - Map isometric (ground_squash < 1, đặt qua set_ground_squash()): không xoay node; hitbox/visual là hình chữ nhật
##   trên mặt phẳng đất theo hướng đòn (tầm/bề rộng đo trên mặt đất). Lọc tầng qua set_elevation().

signal step_started(step_index: int, step_count: int, direction: Vector2)
signal phase_changed(phase: Phase, step_index: int, step_count: int)
## Combo về trạng thái sẵn sàng. completed = true nếu đã đánh hết bước cuối.
signal combo_ended(completed: bool)
signal hit_landed(hurtbox: Hurtbox, applied: int)

enum Phase { READY, WINDUP, ACTIVE, RECOVERY, LINK }

@export var equipment: WeaponEquipment
## HP của chủ thể; không tấn công khi đã chết.
@export var health: HealthComponent
## Hurtbox layer phe đối địch mà đòn đánh nhắm tới.
@export_flags_2d_physics var target_layers: int = 0

var _combo: ComboDefinition
var _phase: Phase = Phase.READY
var _step_index: int = -1
var _time_left: float = 0.0
var _buffered: bool = false
var _direction: Vector2 = Vector2.DOWN
var _aim_provider: Callable
var _shape: RectangleShape2D = RectangleShape2D.new()
var _swing_tween: Tween
## Tỉ lệ dọc của mặt đất (1 = map cũ, 0.5 = isometric). Xem GroundSpace.
var _ground_squash: float = 1.0
var _tier_mask: int = 0
var _weapon_length: float = 0.0

@onready var _hitbox: Hitbox = $Hitbox
@onready var _collision: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var _swing_visual: Polygon2D = $SwingVisual
@onready var _weapon_visual: Line2D = $WeaponVisual


func _ready() -> void:
	_collision.shape = _shape
	_hitbox.collision_layer = 0
	_hitbox.collision_mask = target_layers
	_hitbox.hit_landed.connect(_on_hit_landed)
	_swing_visual.hide()
	rotation = _direction.angle()
	if equipment != null:
		equipment.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(equipment.get_weapon())


## Callable trả về Vector2 hướng đánh (vd. tới chuột). Gọi lúc bắt đầu mỗi bước.
func set_aim_provider(provider: Callable) -> void:
	_aim_provider = provider


func get_phase() -> Phase:
	return _phase


## Chỉ số bước hiện tại (0-based); -1 khi chưa đánh.
func get_step_index() -> int:
	return _step_index


func get_step_count() -> int:
	return _combo.get_step_count() if _combo != null else 0


func is_attacking() -> bool:
	return _phase == Phase.WINDUP or _phase == Phase.ACTIVE or _phase == Phase.RECOVERY


func has_buffered_input() -> bool:
	return _buffered


func get_hitbox() -> Hitbox:
	return _hitbox


## Yêu cầu đánh (một lần nhấn). Trả về true nếu bắt đầu bước mới hoặc được ghi nhớ.
func request_attack() -> bool:
	if _combo == null or _is_owner_dead():
		return false
	match _phase:
		Phase.READY:
			_start_step(0)
			return true
		Phase.LINK:
			_start_step(_step_index + 1)
			return true
		_:
			if _buffered or _time_until_step_end() > _combo.input_buffer:
				return false
			_buffered = true
			return true


## Hủy combo đang chạy, tắt Hitbox và về trạng thái sẵn sàng (chết, reset, đổi vũ khí).
func cancel() -> void:
	var was_running: bool = _phase != Phase.READY
	_hitbox.deactivate()
	_hide_swing()
	_buffered = false
	_step_index = -1
	_time_left = 0.0
	_set_phase(Phase.READY)
	if was_running:
		combo_ended.emit(false)


func _physics_process(delta: float) -> void:
	if _phase == Phase.READY:
		return
	if _is_owner_dead():
		cancel()
		return
	_time_left -= delta
	if _time_left > 0.0:
		return
	var step: ComboStepDefinition = _combo.get_step(_step_index)
	match _phase:
		Phase.WINDUP:
			_enter_active(step)
		Phase.ACTIVE:
			_hitbox.deactivate()
			_time_left = step.recovery
			_set_phase(Phase.RECOVERY)
			_fade_swing(step.recovery)
		Phase.RECOVERY:
			_end_recovery(step)
		Phase.LINK:
			_finish_combo(false)


func _start_step(index: int) -> void:
	var step: ComboStepDefinition = _combo.get_step(index)
	if step == null:
		_finish_combo(true)
		return
	_step_index = index
	_buffered = false
	var aim: Vector2 = _aim_provider.call() if _aim_provider.is_valid() else _direction
	if not aim.is_zero_approx():
		_direction = aim.normalized()
	if _ground_squash == 1.0:
		rotation = _direction.angle()
		_shape.size = Vector2(step.attack_range, step.attack_width)
		_collision.shape = _shape
		_collision.position = Vector2(step.attack_range / 2.0, 0.0)
		var half: float = step.attack_width / 2.0
		_swing_visual.polygon = PackedVector2Array([
			Vector2(0, -half), Vector2(step.attack_range, -half), Vector2(step.attack_range, half), Vector2(0, half)])
	else:
		rotation = 0.0
		var points: PackedVector2Array = GroundSpace.rect(_ground_direction(), step.attack_range, step.attack_width, _ground_squash)
		_collision.shape = GroundSpace.polygon_shape(points)
		_collision.position = Vector2.ZERO
		_swing_visual.polygon = points
		_update_weapon_visual()
	_show_swing(Color(step.effect_color, step.effect_color.a * 0.35))
	step_started.emit(_step_index, get_step_count(), _direction)
	_time_left = step.windup
	_set_phase(Phase.WINDUP)
	if step.windup <= 0.0:
		_enter_active(step)


func _enter_active(step: ComboStepDefinition) -> void:
	var info: DamageInfo = DamageInfo.new(step.damage, owner)
	info.tier_mask = _tier_mask
	info.knockback = _direction * step.knockback if _ground_squash == 1.0 \
		else GroundSpace.to_screen(_ground_direction() * step.knockback, _ground_squash)
	_hitbox.activate(info)
	_show_swing(step.effect_color)
	_time_left = step.active
	_set_phase(Phase.ACTIVE)


func _end_recovery(step: ComboStepDefinition) -> void:
	var is_last: bool = _step_index >= get_step_count() - 1
	if _buffered:
		_buffered = false
		if is_last:
			combo_ended.emit(true)
			_start_step(0)
		else:
			_start_step(_step_index + 1)
	elif is_last:
		_finish_combo(true)
	else:
		_time_left = step.link_window
		_set_phase(Phase.LINK)


func _finish_combo(completed: bool) -> void:
	_hitbox.deactivate()
	_hide_swing()
	_buffered = false
	_step_index = -1
	_set_phase(Phase.READY)
	combo_ended.emit(completed)


## Thời gian còn lại tới hết recovery của bước hiện tại.
func _time_until_step_end() -> float:
	var step: ComboStepDefinition = _combo.get_step(_step_index)
	match _phase:
		Phase.WINDUP:
			return _time_left + step.active + step.recovery
		Phase.ACTIVE:
			return _time_left + step.recovery
		Phase.RECOVERY:
			return _time_left
	return 0.0


func _set_phase(phase: Phase) -> void:
	_phase = phase
	phase_changed.emit(_phase, _step_index, get_step_count())


func _on_weapon_changed(weapon: WeaponDefinition) -> void:
	cancel()
	_combo = weapon.combo if weapon != null else null
	_weapon_visual.visible = weapon != null
	if weapon != null:
		_weapon_visual.default_color = weapon.visual_color
		_weapon_visual.width = weapon.visual_width
		_weapon_length = weapon.visual_length
		_update_weapon_visual()


func set_ground_squash(squash: float) -> void:
	_ground_squash = squash
	rotation = _direction.angle() if _ground_squash == 1.0 else 0.0
	_update_weapon_visual()


func set_elevation(tier_mask: int, _obstacle_mask: int, _ground_z: int) -> void:
	_tier_mask = tier_mask


func _ground_direction() -> Vector2:
	return GroundSpace.direction(_direction, _ground_squash)


## Vạch vũ khí: map cũ nằm dọc trục x của node đã xoay; map iso vẽ theo hướng đòn trên mặt đất.
func _update_weapon_visual() -> void:
	if _ground_squash == 1.0:
		_weapon_visual.points = PackedVector2Array([Vector2(4, 0), Vector2(4.0 + _weapon_length, 0)])
	else:
		var g: Vector2 = _ground_direction()
		_weapon_visual.points = PackedVector2Array([GroundSpace.to_screen(g * 4.0, _ground_squash), GroundSpace.to_screen(g * (4.0 + _weapon_length), _ground_squash)])


func _on_hit_landed(hurtbox: Hurtbox, applied: int) -> void:
	# Phản hồi nhỏ: vùng vung đòn chớp trắng khi trúng.
	_swing_visual.color = Color(1, 1, 1, 0.85)
	hit_landed.emit(hurtbox, applied)


func _show_swing(color: Color) -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_visual.modulate = Color.WHITE
	_swing_visual.color = color
	_swing_visual.show()


func _fade_swing(duration: float) -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_tween = create_tween()
	_swing_tween.tween_property(_swing_visual, ^"modulate:a", 0.0, maxf(duration, 0.05))


func _hide_swing() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	_swing_visual.hide()


func _is_owner_dead() -> bool:
	return health != null and health.is_dead()
