class_name HealthComponent
extends Node
## HP dùng chung cho mọi thực thể (Player, enemy, dummy). Không biết gì về chủ thể, UI hay animation.
## HP luôn trong [0, max_health]. died phát đúng một lần cho tới khi reset().

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died
## Phát khi reset() đưa thực thể từ trạng thái chết về sống.
signal revived

## Max HP gốc (dữ liệu). Lúc chạy max_health = gốc + bonus (vd. từ passive), xem set_max_health_bonus().
@export var max_health: int = 100

var current_health: int = 0

var _base_max_health: int = 0
var _max_health_bonus: int = 0


func _ready() -> void:
	max_health = maxi(1, max_health)
	_base_max_health = max_health
	current_health = max_health


func is_dead() -> bool:
	return current_health <= 0


## Trừ HP. Trả về lượng HP thực sự bị trừ (0 nếu amount không hợp lệ hoặc đã chết).
func apply_damage(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var applied: int = mini(amount, current_health)
	current_health -= applied
	damaged.emit(applied)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()
	return applied


## Hồi HP, không vượt max_health. Không hồi sinh thực thể đã chết (dùng reset()).
func heal(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var applied: int = mini(amount, max_health - current_health)
	if applied == 0:
		return 0
	current_health += applied
	healed.emit(applied)
	health_changed.emit(current_health, max_health)
	return applied


func get_max_health_bonus() -> int:
	return _max_health_bonus


## Đặt (không cộng dồn) lượng max HP thưởng thêm. Quy tắc prototype: giữ tỉ lệ HP hiện tại,
## kẹp trong [1, max] khi còn sống; đã chết thì vẫn 0 (không hồi sinh).
func set_max_health_bonus(bonus: int) -> void:
	if bonus == _max_health_bonus:
		return
	_max_health_bonus = bonus
	var old_max: int = max_health
	max_health = maxi(1, _base_max_health + bonus)
	if not is_dead():
		current_health = clampi(roundi(float(current_health) * max_health / old_max), 1, max_health)
	health_changed.emit(current_health, max_health)


## Đưa HP về max_health.
func reset() -> void:
	var was_dead: bool = is_dead()
	current_health = max_health
	health_changed.emit(current_health, max_health)
	if was_dead:
		revived.emit()


## Đặt HP trực tiếp (khôi phục save): kẹp trong [1, max_health], không phát damaged/healed.
## Đang chết thì hồi sinh (revived).
func restore(value: int) -> void:
	var was_dead: bool = is_dead()
	current_health = clampi(value, 1, max_health)
	health_changed.emit(current_health, max_health)
	if was_dead:
		revived.emit()
