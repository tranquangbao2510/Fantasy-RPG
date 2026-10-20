class_name HungerComponent
extends Node
## Đói (TASK M2), thang 0–100 (100 = no). Giảm theo thời gian trong game (pass_time — World nối từ GameClock),
## giảm thêm theo hoạt động (exert). Dưới `low_threshold`: chặn hồi stamina. Bằng 0: mất HP chậm (% max HP mỗi giờ game).
## Không tự đọc đồng hồ: map không có GameClock thì đói chỉ giảm theo hoạt động.

signal hunger_changed(value: float, maximum: float)

@export var settings: HungerSettings
## Nhận sát thương khi đói lả.
@export var health: HealthComponent

var value: float = 0.0
## HP đói lả chưa trừ (phần lẻ cộng dồn giữa các lần thời gian trôi).
var _starving_damage: float = 0.0


func _ready() -> void:
	if settings == null:
		push_warning("[HungerComponent] Thiếu HungerSettings — dùng mặc định.")
		settings = HungerSettings.new()
	value = settings.max_hunger


func get_max() -> float:
	return settings.max_hunger


func is_low() -> bool:
	return value < settings.low_threshold


func is_full() -> bool:
	return value >= settings.full_threshold


func is_starving() -> bool:
	return value <= 0.0


func blocks_stamina_regen() -> bool:
	return is_low()


## Thời gian game trôi `minutes` phút (thức hoặc ngủ). Đói lả thì trừ HP theo chu kỳ.
func pass_time(minutes: float, sleeping: bool = false) -> void:
	if minutes <= 0.0:
		return
	var rate: float = settings.decay_per_hour_sleeping if sleeping else settings.decay_per_hour_awake
	var starving_before: float = minutes - (value / (rate / 60.0) if rate > 0.0 else minutes)
	_set_value(value - rate * minutes / 60.0)
	if is_starving():
		_starve(clampf(starving_before, 0.0, minutes))
	else:
		_starving_damage = 0.0


## Hoạt động tốn sức (SPRINT tính theo giây: amount = số giây).
func exert(kind: Activity.Kind, amount: float = 1.0) -> void:
	_set_value(value - settings.cost_of(kind) * amount)


func restore(amount: float) -> void:
	if amount != 0.0:
		_set_value(value + amount)


func load_value(saved: Variant) -> void:
	_starving_damage = 0.0
	_set_value(float(saved) if (saved is int or saved is float) else settings.max_hunger)


func _starve(minutes: float) -> void:
	if health == null or health.is_dead():
		return
	_starving_damage += health.max_health * settings.starving_percent_per_hour / 100.0 * minutes / 60.0
	var damage: int = floori(_starving_damage)
	if damage <= 0:
		return
	_starving_damage -= damage
	health.apply_damage(damage)


func _set_value(new_value: float) -> void:
	var clamped: float = clampf(new_value, 0.0, settings.max_hunger)
	if is_equal_approx(clamped, value):
		value = clamped
		return
	value = clamped
	hunger_changed.emit(value, settings.max_hunger)
