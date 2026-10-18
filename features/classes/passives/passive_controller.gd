class_name PassiveController
extends Node
## Áp hiệu ứng của tập passive đang hoạt động lên chủ thể.
## Mỗi lần tập passive đổi, tổng hiệu ứng được tính lại từ đầu (không cộng/trừ dần) nên không thể
## tích lũy lặp hay để sót modifier cũ. Passive trùng passive_id chỉ được tính một lần.
## Không biết gì về class: ClassManager quyết định passive nào đang hoạt động.

signal passives_changed

## Nhận max HP thưởng thêm (MAX_HEALTH).
@export var health: HealthComponent

var _active: Array[PassiveDefinition] = []
var _max_health_bonus: int = 0
var _skill_power_percent: float = 0.0
var _move_speed_percent: float = 0.0


## Thay toàn bộ tập passive đang hoạt động.
func set_active_passives(passives: Array[PassiveDefinition]) -> void:
	_active.clear()
	var ids: Array[StringName] = []
	for passive: PassiveDefinition in passives:
		if passive == null or not passive.is_valid() or ids.has(passive.passive_id):
			continue
		ids.append(passive.passive_id)
		_active.append(passive)
	_recalculate()


func clear() -> void:
	set_active_passives([])


func get_active_passives() -> Array[PassiveDefinition]:
	return _active.duplicate()


func get_max_health_bonus() -> int:
	return _max_health_bonus


func get_skill_power_percent() -> float:
	return _skill_power_percent


func get_move_speed_multiplier() -> float:
	return 1.0 + _move_speed_percent / 100.0


func _recalculate() -> void:
	_max_health_bonus = 0
	_skill_power_percent = 0.0
	_move_speed_percent = 0.0
	for passive: PassiveDefinition in _active:
		match passive.effect_type:
			PassiveDefinition.EffectType.MAX_HEALTH:
				_max_health_bonus += roundi(passive.amount)
			PassiveDefinition.EffectType.SKILL_POWER_PERCENT:
				_skill_power_percent += passive.amount
			PassiveDefinition.EffectType.MOVE_SPEED_PERCENT:
				_move_speed_percent += passive.amount
	_move_speed_percent = maxf(_move_speed_percent, -90.0)
	if health != null:
		health.set_max_health_bonus(_max_health_bonus)
	passives_changed.emit()
