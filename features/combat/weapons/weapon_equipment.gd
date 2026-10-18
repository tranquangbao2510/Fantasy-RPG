class_name WeaponEquipment
extends Node
## Giữ vũ khí đang trang bị của một thực thể (runtime state). Không tính damage, không phải inventory.

## Phát khi vũ khí đổi; null = không trang bị.
signal weapon_changed(weapon: WeaponDefinition)

@export var starting_weapon: WeaponDefinition

var _weapon: WeaponDefinition


func _ready() -> void:
	if starting_weapon != null:
		equip_weapon(starting_weapon)


func get_weapon() -> WeaponDefinition:
	return _weapon


## Điểm mở rộng cho quy tắc trang bị (vd. Class System giới hạn weapon_type_id). Hiện chỉ kiểm tra dữ liệu hợp lệ.
func can_equip(weapon: WeaponDefinition) -> bool:
	return weapon != null and weapon.is_valid()


## Trang bị vũ khí. Trả về false (và giữ vũ khí cũ) nếu definition không hợp lệ.
func equip_weapon(weapon: WeaponDefinition) -> bool:
	if not can_equip(weapon):
		push_warning("[WeaponEquipment] Weapon definition không hợp lệ: %s" % [weapon.resource_path if weapon != null else "null"])
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
