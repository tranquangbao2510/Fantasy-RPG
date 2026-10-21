class_name EquipmentSlots
extends Node
## Ô trang bị của nhân vật (M1: `weapon`, `head`; M2: `offhand` — đèn lồng). Mỗi ô giữ một ItemStack (count 1) hoặc trống.
## - Ô `weapon` đồng bộ hai chiều với WeaponEquipment (hệ thống vũ khí có sẵn):
##   trang bị item vũ khí → equip_weapon(item.weapon) (bị từ chối, vd. luật class, thì item ở lại túi);
##   vũ khí đổi từ nơi khác (phím debug 1/2/3) → ô weapon nhận item tương ứng trong database (item cũ bị bỏ — debug);
##   vũ khí bị gỡ (đổi class không dùng được) → item về túi (túi đầy: gọi `overflow_handler`, không có thì giữ trong ô).
## - Ô `head`: chỉ lưu và hiển thị (M1 chưa có chỉ số/ngoại hình).
## - Hao mòn (TASK M3): `wear(slot, n)` trừ độ bền công cụ (ItemStack.data["durability"]); `burn(phút)` đốt món cháy được
##   đang mặc (đuốc, data["fuel"]). Về 0 → món biến mất khỏi ô (ô weapon: gỡ vũ khí) và phát `item_depleted`.

signal changed
## Trang bị bị từ chối (item không hợp lệ, sai ô, hệ thống vũ khí từ chối...).
signal equip_rejected(item_id: StringName, reason: String)
## Món đang mặc hỏng / cháy hết và biến mất khỏi ô (TASK M3).
signal item_depleted(item_id: StringName, slot_name: StringName)

const SLOTS: Array[StringName] = ItemDefinition.EQUIP_SLOTS
const STATE_VERSION: int = 1

@export var database: ItemDatabase
@export var inventory: Inventory
@export var weapon_equipment: WeaponEquipment

## Callable(stack: ItemStack) -> bool: nơi đặt item khi túi đầy (vd. vứt xuống đất). Tùy chọn.
var overflow_handler: Callable

var _slots: Dictionary[StringName, ItemStack] = {}
var _syncing: bool = false


func _ready() -> void:
	if weapon_equipment != null:
		weapon_equipment.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(weapon_equipment.get_weapon())


## Bản sao item ở ô; null nếu trống.
func get_stack(slot_name: StringName) -> ItemStack:
	var stack: ItemStack = _slots.get(slot_name)
	return stack.duplicate_stack() if stack != null else null


func get_item(slot_name: StringName) -> ItemDefinition:
	var stack: ItemStack = _slots.get(slot_name)
	return database.get_item(stack.item_id) if stack != null and database != null else null


## Bán kính sáng cộng thêm từ đồ đang mặc (TASK M2: đèn lồng ở ô offhand). 0 = không có.
func get_light_radius() -> float:
	var total: float = 0.0
	for slot_name: StringName in _slots:
		var item: ItemDefinition = get_item(slot_name)
		if item != null:
			total += item.light_radius
	return total


## Tổng giáp của đồ đang mặc (TASK M4, vd. áo da ở ô body). Hurtbox giảm sát thương theo DamageInfo.mitigate().
func get_armor() -> int:
	var total: int = 0
	for slot_name: StringName in _slots:
		var item: ItemDefinition = get_item(slot_name)
		if item != null:
			total += item.armor
	return total


## Màu ánh sáng của món phát sáng đang mặc (món đầu tiên); `fallback` nếu không có.
func get_light_color(fallback: Color) -> Color:
	for slot_name: StringName in SLOTS:
		var item: ItemDefinition = get_item(slot_name)
		if item != null and item.is_light_source():
			return item.light_color
	return fallback


## Công cụ khai thác đang cầm ở tay chính (null nếu tay không hoặc cầm vũ khí thường).
func get_tool() -> ItemDefinition:
	var item: ItemDefinition = get_item(&"weapon")
	return item if item != null and item.is_tool() else null


## Trừ `amount` độ bền của món ở ô. Về 0 → món vỡ (gỡ khỏi ô, `item_depleted`). Trả về true nếu món vừa vỡ.
func wear(slot_name: StringName, amount: int = 1) -> bool:
	var stack: ItemStack = _slots.get(slot_name)
	var item: ItemDefinition = get_item(slot_name)
	if stack == null or item == null or item.max_durability <= 0 or amount <= 0:
		return false
	var left: int = item.durability_of(stack) - amount
	if left > 0:
		stack.data["durability"] = left
		changed.emit()
		return false
	_set_slot(slot_name, null)
	item_depleted.emit(item.id, slot_name)
	return true


## Đặt một giá trị trong ItemStack.data của món ở ô (TASK M5: lượng nước của bình tưới). false nếu ô trống.
func set_stack_data(slot_name: StringName, key: String, value: Variant) -> bool:
	var stack: ItemStack = _slots.get(slot_name)
	if stack == null:
		return false
	stack.data[key] = value
	changed.emit()
	return true


## Thời gian game trôi `minutes` phút: món cháy được đang mặc (đuốc) hao nhiên liệu; hết → biến mất (`item_depleted`).
func burn(minutes: float) -> void:
	if minutes <= 0.0:
		return
	for slot_name: StringName in _slots.keys():
		var stack: ItemStack = _slots[slot_name]
		var item: ItemDefinition = get_item(slot_name)
		if item == null or item.burn_minutes <= 0.0:
			continue
		var left: float = item.fuel_of(stack) - minutes
		if left > 0.0:
			stack.data["fuel"] = snappedf(left, 0.01)
			changed.emit()
		else:
			_set_slot(slot_name, null)
			item_depleted.emit(item.id, slot_name)


## Lý do không thể trang bị stack vào ô ("" nếu được).
func get_equip_block_reason(slot_name: StringName, stack: ItemStack) -> String:
	if not SLOTS.has(slot_name):
		return "Ô trang bị không tồn tại"
	if stack == null or stack.is_empty():
		return "Không có vật phẩm"
	var item: ItemDefinition = database.get_item(stack.item_id) if database != null else null
	if item == null:
		return "Vật phẩm không tồn tại"
	if item.equip_slot != slot_name:
		return "%s không trang bị vào ô này" % item.display_name
	if slot_name == &"weapon" and weapon_equipment != null:
		return weapon_equipment.get_equip_block_reason(item.weapon)
	return ""


## Trang bị item ở ô `from_slot` của túi. Món đang mặc ở ô đó đổi chỗ về đúng ô túi vừa lấy.
func equip_from_inventory(from_slot: int, slot_name: StringName = &"") -> bool:
	if inventory == null:
		return false
	var stack: ItemStack = inventory.get_stack(from_slot)
	if stack == null:
		return false
	if slot_name == &"":
		var item: ItemDefinition = database.get_item(stack.item_id) if database != null else null
		slot_name = item.equip_slot if item != null else &""
	var reason: String = get_equip_block_reason(slot_name, stack)
	if not reason.is_empty():
		equip_rejected.emit(stack.item_id, reason)
		return false
	inventory.replace_at(from_slot, _slots.get(slot_name))
	_set_slot(slot_name, stack)
	return true


## Tháo ô về túi (ô `to_slot` nếu chỉ định và hợp lệ, không thì ô trống đầu tiên). false nếu túi đầy.
func unequip_to_inventory(slot_name: StringName, to_slot: int = -1) -> bool:
	var stack: ItemStack = _slots.get(slot_name)
	if stack == null or inventory == null:
		return false
	if to_slot >= 0 and inventory.is_slot_empty(to_slot):
		inventory.replace_at(to_slot, stack)
	elif inventory.add_stack(stack) > 0:
		return false
	_set_slot(slot_name, null)
	return true


## Đặt thẳng item vào ô (không qua túi). Dùng cho load và đồng bộ debug. Không kiểm tra luật vũ khí.
func set_slot(slot_name: StringName, stack: ItemStack) -> void:
	if SLOTS.has(slot_name):
		_set_slot(slot_name, stack)


func to_dict() -> Dictionary:
	var slots: Dictionary = {}
	for slot_name: StringName in _slots:
		slots[String(slot_name)] = _slots[slot_name].to_dict()
	return {"version": STATE_VERSION, "slots": slots}


## Khôi phục từ save. Item không tồn tại / sai ô bị bỏ (cảnh báo). Ô weapon trống → gỡ vũ khí.
func load_dict(value: Variant) -> void:
	var dict: Dictionary = value if value is Dictionary else {}
	var slots: Variant = dict.get("slots", {})
	var saved: Dictionary = slots if slots is Dictionary else {}
	for slot_name: StringName in SLOTS:
		var stack: ItemStack = ItemStack.from_dict(saved.get(String(slot_name)))
		if stack != null:
			var item: ItemDefinition = database.get_item(stack.item_id) if database != null else null
			if item == null or item.equip_slot != slot_name:
				push_warning("[EquipmentSlots] Bỏ qua item lỗi ở ô %s: %s" % [slot_name, stack.item_id])
				stack = null
			else:
				stack.count = 1
		_set_slot(slot_name, stack)


func _set_slot(slot_name: StringName, stack: ItemStack) -> void:
	if stack != null and stack.is_empty():
		stack = null
	if stack == null:
		_slots.erase(slot_name)
	else:
		_slots[slot_name] = stack
	if slot_name == &"weapon" and weapon_equipment != null and not _syncing:
		_syncing = true
		var item: ItemDefinition = get_item(&"weapon")
		if item != null:
			weapon_equipment.equip_weapon(item.weapon)
		else:
			weapon_equipment.unequip_weapon()
		_syncing = false
	changed.emit()


func _on_weapon_changed(weapon: WeaponDefinition) -> void:
	if _syncing:
		return
	var current: ItemDefinition = get_item(&"weapon")
	if weapon == null:
		if current == null:
			return
		# Hệ thống vũ khí gỡ vũ khí (vd. đổi class): trả item về túi, đầy thì nhờ overflow_handler.
		var stack: ItemStack = _slots[&"weapon"]
		_syncing = true
		var placed: bool = inventory != null and inventory.add_stack(stack) == 0
		if not placed and overflow_handler.is_valid():
			placed = overflow_handler.call(stack)
		if placed:
			_slots.erase(&"weapon")
		else:
			push_warning("[EquipmentSlots] Túi đầy: giữ %s trong ô weapon dù vũ khí đã bị gỡ." % stack.item_id)
		_syncing = false
		changed.emit()
		return
	if current != null and current.weapon != null and current.weapon.weapon_id == weapon.weapon_id:
		return
	var item: ItemDefinition = database.find_by_weapon(weapon) if database != null else null
	_syncing = true
	if item != null:
		_slots[&"weapon"] = ItemStack.new(item.id, 1)
	else:
		_slots.erase(&"weapon")
		push_warning("[EquipmentSlots] Không có item cho vũ khí %s." % weapon.weapon_id)
	_syncing = false
	changed.emit()
