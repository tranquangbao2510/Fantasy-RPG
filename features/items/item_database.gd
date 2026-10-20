class_name ItemDatabase
extends Resource
## Danh mục mọi ItemDefinition (dữ liệu thiết kế). Không phải Autoload: được gán (export) cho component cần tra
## cứu (Inventory, EquipmentSlots, pickup, UI) giống cách ClassManager nhận danh sách class.
## Index theo id được dựng ở lần tra cứu đầu tiên; lúc dựng sẽ validate và báo lỗi (push_error) cho:
## item null, item không hợp lệ, id trùng. Item lỗi / trùng không vào index (tra sẽ trả về null).

@export var items: Array[ItemDefinition] = []

var _index: Dictionary[StringName, ItemDefinition] = {}
var _built: bool = false


func get_item(item_id: StringName) -> ItemDefinition:
	_ensure_index()
	return _index.get(item_id)


func has_item(item_id: StringName) -> bool:
	return get_item(item_id) != null


## Số lượng tối đa mỗi ô; 0 nếu id không tồn tại.
func get_max_stack(item_id: StringName) -> int:
	var item: ItemDefinition = get_item(item_id)
	return item.max_stack if item != null else 0


## Item vũ khí trỏ tới WeaponDefinition này (so theo weapon_id); null nếu không có.
func find_by_weapon(weapon: WeaponDefinition) -> ItemDefinition:
	if weapon == null:
		return null
	_ensure_index()
	for item: ItemDefinition in _index.values():
		if item.weapon != null and item.weapon.weapon_id == weapon.weapon_id:
			return item
	return null


## Buff có buff_id này trong tác dụng của một món ăn (TASK M4: khôi phục buff từ save — save chỉ lưu id). null nếu không có.
func find_buff(buff_id: StringName) -> BuffDefinition:
	_ensure_index()
	for item: ItemDefinition in _index.values():
		if item.consumable != null and item.consumable.buff != null and item.consumable.buff.buff_id == buff_id:
			return item.consumable.buff
	return null


func get_item_ids() -> Array[StringName]:
	_ensure_index()
	return Array(_index.keys(), TYPE_STRING_NAME, &"", null)


## Mọi lỗi dữ liệu của database (rỗng = hợp lệ). Không đổi trạng thái.
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary[StringName, int] = {}
	for i: int in items.size():
		var item: ItemDefinition = items[i]
		if item == null:
			errors.append("items[%d]: null" % i)
			continue
		for error: String in item.get_validation_errors():
			errors.append("items[%d] (%s): %s" % [i, item.id, error])
		if item.id != &"":
			if seen.has(item.id):
				errors.append("items[%d]: id trùng '%s' (đã có ở items[%d])" % [i, item.id, seen[item.id]])
			else:
				seen[item.id] = i
	return errors


## Dựng lại index (vd. sau khi sửa `items` lúc chạy hoặc trong test).
func rebuild() -> void:
	_built = false
	_ensure_index()


func _ensure_index() -> void:
	if _built:
		return
	_built = true
	_index.clear()
	for error: String in get_validation_errors():
		push_error("[ItemDatabase] %s: %s" % [resource_path, error])
	for item: ItemDefinition in items:
		if item != null and item.is_valid() and not _index.has(item.id):
			_index[item.id] = item
