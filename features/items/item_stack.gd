class_name ItemStack
extends RefCounted
## Một chồng vật phẩm trong một ô (runtime state). Chỉ giữ ID + số lượng + dữ liệu riêng (dự phòng độ bền, ...,
## chưa dùng). Hai stack chỉ gộp được khi cùng item_id và cùng data.

var item_id: StringName
var count: int
var data: Dictionary


func _init(p_item_id: StringName = &"", p_count: int = 1, p_data: Dictionary = {}) -> void:
	item_id = p_item_id
	count = p_count
	data = p_data.duplicate(true)


func is_empty() -> bool:
	return item_id == &"" or count <= 0


func can_merge_with(other: ItemStack) -> bool:
	return other != null and other.item_id == item_id and other.data == data


func duplicate_stack() -> ItemStack:
	return ItemStack.new(item_id, count, data)


func to_dict() -> Dictionary:
	var result: Dictionary = {"id": String(item_id), "count": count}
	if not data.is_empty():
		result["data"] = data.duplicate(true)
	return result


## Đọc từ save; null nếu thiếu id / số lượng không hợp lệ.
static func from_dict(value: Variant) -> ItemStack:
	if not value is Dictionary:
		return null
	var dict: Dictionary = value
	var id: String = str(dict.get("id", ""))
	var amount: int = int(dict.get("count", 0)) if (dict.get("count") is int or dict.get("count") is float) else 0
	if id.is_empty() or amount <= 0:
		return null
	var extra: Variant = dict.get("data", {})
	return ItemStack.new(StringName(id), amount, extra if extra is Dictionary else {})
