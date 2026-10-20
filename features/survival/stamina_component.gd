class_name StaminaComponent
extends Node
## Stamina (TASK M2): tốn khi chạy (theo giây) và né (mỗi lần). Hồi nhanh khi không dùng (`regen_delay`).
## Cạn về 0 → "kiệt sức": không chạy/né được tới khi hồi lại `exhausted_recover_threshold`.
## Không hồi khi đói thấp (HungerComponent.blocks_stamina_regen). Hệ số buff STAMINA_REGEN nếu có BuffComponent.

signal stamina_changed(current: float, maximum: float)
signal exhausted_changed(exhausted: bool)

@export var settings: StaminaSettings
@export var hunger: HungerComponent
@export var buffs: BuffComponent

var current: float = 0.0
var _regen_wait: float = 0.0
var _exhausted: bool = false


func _ready() -> void:
	if settings == null:
		push_warning("[StaminaComponent] Thiếu StaminaSettings — dùng mặc định.")
		settings = StaminaSettings.new()
	current = settings.max_stamina


func _physics_process(delta: float) -> void:
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	if current >= settings.max_stamina or not can_regenerate():
		return
	var multiplier: float = buffs.get_multiplier(BuffDefinition.Stat.STAMINA_REGEN) if buffs != null else 1.0
	_set_current(current + settings.regen_per_second * multiplier * delta)


func get_max() -> float:
	return settings.max_stamina


func is_exhausted() -> bool:
	return _exhausted


func can_regenerate() -> bool:
	return hunger == null or not hunger.blocks_stamina_regen()


func can_sprint() -> bool:
	return not _exhausted and current > 0.0


func can_dodge() -> bool:
	return not _exhausted and current + 0.0001 >= settings.dodge_cost


## Tiêu stamina khi chạy trong `delta` giây. Hết thì kiệt sức.
func drain_sprint(delta: float) -> void:
	if can_sprint():
		_use(settings.sprint_cost_per_second * delta)


## Tiêu stamina cho một lần né. false (không trừ) nếu không đủ / đang kiệt sức.
func try_dodge() -> bool:
	if not can_dodge():
		return false
	_use(settings.dodge_cost)
	return true


func restore(amount: float) -> void:
	if amount > 0.0:
		_set_current(current + amount)


func refill() -> void:
	_regen_wait = 0.0
	_set_current(settings.max_stamina)


func load_value(value: Variant) -> void:
	_regen_wait = 0.0
	_set_current(float(value) if (value is int or value is float) else settings.max_stamina)


func _use(amount: float) -> void:
	_regen_wait = settings.regen_delay
	_set_current(current - amount)


func _set_current(value: float) -> void:
	var clamped: float = clampf(value, 0.0, settings.max_stamina)
	var changed: bool = not is_equal_approx(clamped, current)
	current = clamped
	if current <= 0.0 and not _exhausted:
		_exhausted = true
		exhausted_changed.emit(true)
	elif _exhausted and current >= settings.exhausted_recover_threshold:
		_exhausted = false
		exhausted_changed.emit(false)
	if changed:
		stamina_changed.emit(current, settings.max_stamina)
