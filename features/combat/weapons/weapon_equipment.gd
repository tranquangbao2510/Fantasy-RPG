class_name WeaponEquipment
extends Node
## Giữ vũ khí đang trang bị của một thực thể (runtime state). Không tính damage, không phải inventory.

## Phát khi vũ khí đổi; null = không trang bị.
signal weapon_changed(weapon: WeaponDefinition)
## Trang bị bị từ chối (dữ liệu lỗi hoặc luật validator, vd. class không dùng loại vũ khí này).
signal equip_rejected(weapon: WeaponDefinition, reason: String)

@export var starting_weapon: WeaponDefinition

var _weapon: WeaponDefinition
var _equip_validator: Callable


func _ready() -> void:
	if starting_weapon != null:
		equip_weapon(starting_weapon)


func get_weapon() -> WeaponDefinition:
	return _weapon


## Luật trang bị bổ sung (vd. ClassManager giới hạn weapon_type_id).
## Callable(weapon: WeaponDefinition) -> String: "" = cho phép, ngược lại là lý do từ chối.
func set_equip_validator(validator: Callable) -> void:
	_equip_validator = validator


## Lý do không thể trang bị ("" nếu được).
func get_equip_block_reason(weapon: WeaponDefinition) -> String:
	if weapon == null or not weapon.is_valid():
		return "Vũ khí không hợp lệ"
	if _equip_validator.is_valid():
		return _equip_validator.call(weapon)
	return ""


func can_equip(weapon: WeaponDefinition) -> bool:
	return get_equip_block_reason(weapon).is_empty()


## Trang bị vũ khí. Trả về false (và giữ vũ khí cũ) nếu bị từ chối.
func equip_weapon(weapon: WeaponDefinition) -> bool:
	var reason: String = get_equip_block_reason(weapon)
	if not reason.is_empty():
		if weapon == null or not weapon.is_valid():
			push_warning("[WeaponEquipment] Weapon definition không hợp lệ: %s" % [weapon.resource_path if weapon != null else "null"])
		equip_rejected.emit(weapon, reason)
		return false
	if weapon == _weapon:
		return true
	_weapon = weapon
	weapon_changed.emit(_weapon)
	return true


func unequip_weapon() -> void:
	if _weapon == null:
		return
	_weapon = null
	weapon_changed.emit(null)
