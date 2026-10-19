class_name ItemDefinition
extends Resource
## Định nghĩa một vật phẩm (dữ liệu thiết kế, chỉ đọc lúc chạy). Không chứa trạng thái (số lượng, vị trí, độ bền):
## trạng thái nằm trong ItemStack của Inventory. Save chỉ lưu `id`.

enum Category { MATERIAL, FOOD, TOOL, WEAPON, ARMOR, SEED, QUEST, MISC }

const CATEGORY_NAMES: Array[String] = ["Nguyên liệu", "Thức ăn", "Công cụ", "Vũ khí", "Trang phục", "Hạt giống", "Nhiệm vụ", "Khác"]
## Ô trang bị hợp lệ (EquipmentSlots). &"" = không trang bị được.
const EQUIP_SLOTS: Array[StringName] = [&"weapon", &"head"]

## ID ổn định, không phụ thuộc tên hiển thị (vd. &"wood"). Lưu trong save.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.MISC
@export_range(1, 999) var max_stack: int = 99
@export var sell_price: int = 0
@export var tags: Array[StringName] = []
## Ô trang bị của item (&"weapon", &"head"); &"" = không trang bị được.
@export var equip_slot: StringName = &""
## Item vũ khí: WeaponDefinition dùng khi trang bị (đánh thường/combo do hệ thống vũ khí xử lý).
@export var weapon: WeaponDefinition


func get_category_name() -> String:
	return CATEGORY_NAMES[category]


func is_equippable() -> bool:
	return equip_slot != &""


## Danh sách lỗi dữ liệu (rỗng = hợp lệ).
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("id rỗng")
	if display_name.is_empty():
		errors.append("display_name rỗng")
	if max_stack < 1:
		errors.append("max_stack < 1")
	if sell_price < 0:
		errors.append("sell_price < 0")
	if equip_slot != &"" and not EQUIP_SLOTS.has(equip_slot):
		errors.append("equip_slot không hợp lệ: %s" % equip_slot)
	if category == Category.WEAPON and (weapon == null or not weapon.is_valid()):
		errors.append("item vũ khí thiếu WeaponDefinition hợp lệ")
	if weapon != null and equip_slot != &"weapon":
		errors.append("có weapon nhưng equip_slot không phải weapon")
	if is_equippable() and max_stack != 1:
		errors.append("item trang bị phải có max_stack = 1")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
