class_name ManaComponent
extends Node
## Mana của một nhân vật (TASK M2), giống HealthComponent: chỉ giữ số, không biết UI/kỹ năng.
## Kỹ năng tiêu mana qua SkillCastingController (SkillDefinition.mana_cost). Hồi `regen_per_second` sau `regen_delay`
## giây kể từ lần tiêu cuối (nhân hệ số buff MANA_REGEN nếu có BuffComponent).

signal mana_changed(current: float, maximum: float)

@export var settings: ManaSettings
@export var buffs: BuffComponent

var current: float = 0.0
var _regen_wait: float = 0.0


func _ready() -> void:
	if settings == null:
		push_warning("[ManaComponent] Thiếu ManaSettings — dùng mặc định.")
		settings = ManaSettings.new()
	current = settings.max_mana


func _physics_process(delta: float) -> void:
	if _regen_wait > 0.0:
		_regen_wait -= delta
		return
	if current < settings.max_mana:
		var multiplier: float = buffs.get_multiplier(BuffDefinition.Stat.MANA_REGEN) if buffs != null else 1.0
		_set_current(current + settings.regen_per_second * multiplier * delta)


func get_max() -> float:
	return settings.max_mana


func has_mana(amount: float) -> bool:
	return amount <= 0.0 or current + 0.0001 >= amount


## Tiêu mana. false (không trừ) nếu không đủ.
func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not has_mana(amount):
		return false
	_set_current(current - amount)
	_regen_wait = settings.regen_delay
	return true


## Bị hút mana (TASK M4, đòn Bóng ma): trừ tới 0, không cần đủ; tính như vừa tiêu (chờ regen_delay mới hồi).
func drain(amount: float) -> void:
	if amount <= 0.0:
		return
	_set_current(current - amount)
	_regen_wait = settings.regen_delay


func restore(amount: float) -> void:
	if amount > 0.0:
		_set_current(current + amount)


func refill() -> void:
	_regen_wait = 0.0
	_set_current(settings.max_mana)


func load_value(value: Variant) -> void:
	_regen_wait = 0.0
	_set_current(float(value) if (value is int or value is float) else settings.max_mana)


func _set_current(value: float) -> void:
	var clamped: float = clampf(value, 0.0, settings.max_mana)
	if is_equal_approx(clamped, current):
		current = clamped
		return
	current = clamped
	mana_changed.emit(current, settings.max_mana)
