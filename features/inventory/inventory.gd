class_name Inventory
extends Node
## Component túi đồ / kho N ô (Player, rương). Logic thuần: không biết UI, không biết thế giới.
## Mỗi ô là một ItemStack hoặc trống (null). Số lượng mỗi ô ≤ max_stack của item (tra qua ItemDatabase).
## Mọi thao tác thay đổi phát `changed` đúng một lần. Getter trả về bản sao (không sửa trực tiếp được).

signal changed

## Phiên bản cấu trúc to_dict().
const STATE_VERSION: int = 1

@export var database: ItemDatabase
@export_range(1, 200) var size: int = 24:
	set(value):
		size = maxi(1, value)
		_slots.resize(size)

var _slots: Array[ItemStack] = []


func _init() -> void:
	_slots.resize(size)


func get_size() -> int:
	return size


## Bản sao stack ở ô; null nếu trống / ngoài phạm vi.
func get_stack(slot: int) -> ItemStack:
	if not is_valid_slot(slot) or _slots[slot] == null:
		return null
	return _slots[slot].duplicate_stack()


func is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < size


func is_slot_empty(slot: int) -> bool:
	return is_valid_slot(slot) and _slots[slot] == null


func first_empty_slot() -> int:
	for i: int in size:
		if _slots[i] == null:
			return i
	return -1


func is_full() -> bool:
	return first_empty_slot() < 0


func count_of(item_id: StringName) -> int:
	var total: int = 0
	for stack: ItemStack in _slots:
		if stack != null and stack.item_id == item_id:
			total += stack.count
	return total


func has(item_id: StringName, amount: int = 1) -> bool:
	return count_of(item_id) >= amount


## Số lượng item còn nhét vừa (gộp vào stack cũ + ô trống).
func space_for(item_id: StringName, data: Dictionary = {}) -> int:
	var max_stack: int = _max_stack(item_id)
	if max_stack <= 0:
		return 0
	var probe: ItemStack = ItemStack.new(item_id, 1, data)
	var space: int = 0
	for stack: ItemStack in _slots:
		if stack == null:
			space += max_stack
		elif stack.can_merge_with(probe):
			space += maxi(0, max_stack - stack.count)
	return space


## Thêm item: lấp các stack cùng loại trước, rồi tới ô trống đầu tiên. Trả về số KHÔNG thêm được (0 = đủ chỗ).
## id không có trong database: không thêm gì, trả về toàn bộ.
func add(item_id: StringName, amount: int, data: Dictionary = {}) -> int:
	if amount <= 0:
		return 0
	var max_stack: int = _max_stack(item_id)
	if max_stack <= 0:
		push_warning("[Inventory] Item không tồn tại: %s" % item_id)
		return amount
	var remaining: int = amount
	var probe: ItemStack = ItemStack.new(item_id, 1, data)
	for stack: ItemStack in _slots:
		if remaining <= 0:
			break
		if stack != null and stack.can_merge_with(probe) and stack.count < max_stack:
			var moved: int = mini(remaining, max_stack - stack.count)
			stack.count += moved
			remaining -= moved
	for i: int in size:
		if remaining <= 0:
			break
		if _slots[i] == null:
			var moved: int = mini(remaining, max_stack)
			_slots[i] = ItemStack.new(item_id, moved, data)
			remaining -= moved
	if remaining != amount:
		changed.emit()
	return remaining


func add_stack(stack: ItemStack) -> int:
	if stack == null or stack.is_empty():
		return 0
	return add(stack.item_id, stack.count, stack.data)


## Bớt tối đa `amount` item theo id (từ ô cuối lên). Trả về số đã bớt.
func remove(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var removed: int = 0
	for i: int in range(size - 1, -1, -1):
		if removed >= amount:
			break
		var stack: ItemStack = _slots[i]
		if stack == null or stack.item_id != item_id:
			continue
		var taken: int = mini(amount - removed, stack.count)
		stack.count -= taken
		removed += taken
		if stack.count <= 0:
			_slots[i] = null
	if removed > 0:
		changed.emit()
	return removed


## Lấy `amount` item ra khỏi ô (-1 = cả stack). Trả về stack đã lấy (null nếu ô trống).
func remove_at(slot: int, amount: int = -1) -> ItemStack:
	if not is_valid_slot(slot) or _slots[slot] == null:
		return null
	var stack: ItemStack = _slots[slot]
	var taken: int = stack.count if amount < 0 else mini(amount, stack.count)
	if taken <= 0:
		return null
	var result: ItemStack = ItemStack.new(stack.item_id, taken, stack.data)
	stack.count -= taken
	if stack.count <= 0:
		_slots[slot] = null
	changed.emit()
	return result


## Đặt stack vào ô, trả về stack cũ (null nếu trống). Dùng cho trang bị/đổi chỗ giữa các container.
## Không kiểm tra max_stack ngoài việc kẹp số lượng.
func replace_at(slot: int, stack: ItemStack) -> ItemStack:
	if not is_valid_slot(slot):
		return stack
	var previous: ItemStack = _slots[slot]
	_slots[slot] = _sanitize(stack)
	changed.emit()
	return previous


## Thêm stack vào đúng ô: ô trống → đặt vào; cùng loại → gộp tới max_stack. Trả về số không vào được.
func add_to_slot(slot: int, stack: ItemStack) -> int:
	if stack == null or stack.is_empty():
		return 0
	if not is_valid_slot(slot):
		return stack.count
	var max_stack: int = _max_stack(stack.item_id)
	if max_stack <= 0:
		return stack.count
	var target: ItemStack = _slots[slot]
	if target == null:
		var placed: int = mini(stack.count, max_stack)
		_slots[slot] = ItemStack.new(stack.item_id, placed, stack.data)
		changed.emit()
		return stack.count - placed
	if not target.can_merge_with(stack):
		return stack.count
	var moved: int = mini(stack.count, max_stack - target.count)
	if moved <= 0:
		return stack.count
	target.count += moved
	changed.emit()
	return stack.count - moved


func swap(a: int, b: int) -> bool:
	if not is_valid_slot(a) or not is_valid_slot(b) or a == b:
		return false
	var temp: ItemStack = _slots[a]
	_slots[a] = _slots[b]
	_slots[b] = temp
	changed.emit()
	return true


## Gộp stack ô `from` vào ô `to` (cùng item): chuyển tối đa tới max_stack, phần dư ở lại `from`.
func merge(from: int, to: int) -> bool:
	if not is_valid_slot(from) or not is_valid_slot(to) or from == to:
		return false
	var source: ItemStack = _slots[from]
	var target: ItemStack = _slots[to]
	if source == null or target == null or not target.can_merge_with(source):
		return false
	var moved: int = mini(source.count, _max_stack(target.item_id) - target.count)
	if moved <= 0:
		return false
	target.count += moved
	source.count -= moved
	if source.count <= 0:
		_slots[from] = null
	changed.emit()
	return true


## Kéo ô `from` sang ô `to` trong cùng túi: ô đích trống → chuyển; cùng loại → gộp; khác loại → đổi chỗ.
func move(from: int, to: int) -> bool:
	if not is_valid_slot(from) or not is_valid_slot(to) or from == to or _slots[from] == null:
		return false
	if _slots[to] == null:
		_slots[to] = _slots[from]
		_slots[from] = null
		changed.emit()
		return true
	if _slots[to].can_merge_with(_slots[from]):
		return merge(from, to)
	return swap(from, to)


## Kéo ô `from` của túi này sang ô `to` của túi khác (rương ↔ túi): trống → chuyển; cùng loại → gộp (phần dư ở lại);
## khác loại → đổi chỗ.
func transfer_to(from: int, other: Inventory, to: int) -> bool:
	if other == self:
		return move(from, to)
	if other == null or not is_valid_slot(from) or not other.is_valid_slot(to) or _slots[from] == null:
		return false
	var source: ItemStack = _slots[from]
	var target: ItemStack = other._slots[to]
	if target != null and not target.can_merge_with(source):
		_slots[from] = other.replace_at(to, source)
		changed.emit()
		return true
	var left: int = other.add_to_slot(to, source)
	if left == source.count:
		return false
	source.count = left
	if source.count <= 0:
		_slots[from] = null
	changed.emit()
	return true


## Chuyển nhanh cả stack ở ô sang túi khác (Shift+click). Trả về số đã chuyển.
func quick_transfer(from: int, other: Inventory) -> int:
	if other == null or other == self or not is_valid_slot(from) or _slots[from] == null:
		return 0
	var source: ItemStack = _slots[from]
	var left: int = other.add_stack(source)
	var moved: int = source.count - left
	if moved <= 0:
		return 0
	source.count = left
	if source.count <= 0:
		_slots[from] = null
	changed.emit()
	return moved


## Tách `amount` item từ ô sang ô trống đầu tiên. Trả về ô mới, -1 nếu không tách được (stack 1 hoặc túi đầy).
func split(slot: int, amount: int) -> int:
	if not is_valid_slot(slot) or _slots[slot] == null:
		return -1
	var source: ItemStack = _slots[slot]
	if amount <= 0 or amount >= source.count:
		return -1
	var target: int = first_empty_slot()
	if target < 0:
		return -1
	_slots[target] = ItemStack.new(source.item_id, amount, source.data)
	source.count -= amount
	changed.emit()
	return target


## Tách nửa stack (làm tròn xuống) sang ô trống đầu tiên.
func split_half(slot: int) -> int:
	var stack: ItemStack = _slots[slot] if is_valid_slot(slot) else null
	return split(slot, stack.count / 2) if stack != null else -1


func clear() -> void:
	_slots.fill(null)
	changed.emit()


func to_dict() -> Dictionary:
	var slots: Array = []
	for i: int in size:
		if _slots[i] != null:
			var entry: Dictionary = _slots[i].to_dict()
			entry["slot"] = i
			slots.append(entry)
	return {"version": STATE_VERSION, "size": size, "slots": slots}


## Thay toàn bộ nội dung bằng dữ liệu save. Bỏ qua (cảnh báo) ô ngoài phạm vi, ô trùng, item không tồn tại;
## số lượng kẹp theo max_stack. Kích thước túi giữ theo scene (không đọc `size` từ save).
func load_dict(value: Variant) -> void:
	_slots.fill(null)
	var dict: Dictionary = value if value is Dictionary else {}
	var entries: Variant = dict.get("slots", [])
	for entry: Variant in (entries if entries is Array else []):
		var stack: ItemStack = ItemStack.from_dict(entry)
		var slot: int = int((entry as Dictionary).get("slot", -1)) if entry is Dictionary else -1
		if stack == null or not is_valid_slot(slot) or _slots[slot] != null:
			push_warning("[Inventory] Bỏ qua ô lỗi trong save: %s" % [entry])
			continue
		if _max_stack(stack.item_id) <= 0:
			push_warning("[Inventory] Bỏ qua item không tồn tại trong save: %s" % stack.item_id)
			continue
		_slots[slot] = _sanitize(stack)
	changed.emit()


func _max_stack(item_id: StringName) -> int:
	return database.get_max_stack(item_id) if database != null else 0


func _sanitize(stack: ItemStack) -> ItemStack:
	if stack == null or stack.is_empty():
		return null
	var max_stack: int = _max_stack(stack.item_id)
	if max_stack > 0 and stack.count > max_stack:
		stack.count = max_stack
	return stack
