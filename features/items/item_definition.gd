class_name ItemDefinition
extends Resource
## Định nghĩa một vật phẩm (dữ liệu thiết kế, chỉ đọc lúc chạy). Không chứa trạng thái (số lượng, vị trí, độ bền):
## trạng thái nằm trong ItemStack của Inventory. Save chỉ lưu `id`.

enum Category { MATERIAL, FOOD, TOOL, WEAPON, ARMOR, SEED, QUEST, MISC }

const CATEGORY_NAMES: Array[String] = ["Nguyên liệu", "Thức ăn", "Công cụ", "Vũ khí", "Trang phục", "Hạt giống", "Nhiệm vụ", "Khác"]
## Ô trang bị hợp lệ (EquipmentSlots). &"" = không trang bị được.
const EQUIP_SLOTS: Array[StringName] = [&"weapon", &"head", &"offhand", &"body"]

## ID ổn định, không phụ thuộc tên hiển thị (vd. &"wood"). Lưu trong save.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.MISC
@export_range(1, 999) var max_stack: int = 99
@export var sell_price: int = 0
@export var tags: Array[StringName] = []
## Ô trang bị của item (&"weapon", &"head", &"offhand", &"body" — áo, TASK M4); &"" = không trang bị được.
@export var equip_slot: StringName = &""
## Item vũ khí: WeaponDefinition dùng khi trang bị (đánh thường/combo do hệ thống vũ khí xử lý).
@export var weapon: WeaponDefinition
## Item dùng được (ăn/uống, TASK M2): tác dụng khi dùng. null = không dùng được.
@export var consumable: ConsumableEffect
## Item đặt xuống thế giới khi dùng (vd. lều). Scene gốc phải có hàm setup_from_item(item_id) — xem Tent.
@export var deploy_scene: PackedScene

@export_group("Công cụ, độ bền, vật dựng (TASK M3)")
## Loại công cụ khi cầm ở tay chính: &"axe" (rìu), &"pickaxe" (cuốc chim); &"" = không phải công cụ khai thác.
@export var tool_type: StringName = &""
## Sức khai thác mỗi lần (trừ vào độ bền khai thác của node tài nguyên). Tay không = ResourceNode.HAND_POWER.
@export_range(1, 10) var harvest_power: int = 1
## Độ bền tối đa (số lần khai thác); 0 = không hao mòn. Giá trị hiện tại: ItemStack.data["durability"] (thiếu = đầy).
@export var max_durability: int = 0
## Cháy được bao lâu khi trang bị (phút game, vd. đuốc); 0 = không cháy hết. Còn lại: ItemStack.data["fuel"] (thiếu = đầy).
@export var burn_minutes: float = 0.0
## Vật dựng (deploy_scene): số tối đa cùng lúc trên một map (lều 1); 0 = không giới hạn.
@export var max_per_map: int = 0
## Vật dựng: đặt cách chân người chơi bao nhiêu px mặt đất theo hướng nhìn (vật có thân va chạm như lửa trại đặt trước
## mặt để không kẹt người chơi); 0 = ngay chỗ đứng (lều).
@export var deploy_offset: float = 0.0

@export_group("Giáp (TASK M4)")
## Giáp khi đang mặc: sát thương nhận vào × 100 / (100 + tổng giáp) (DamageInfo.mitigate). 0 = không giảm.
@export_range(0, 200) var armor: int = 0

@export_group("Nguồn sáng khi trang bị")
## Bán kính nhìn đêm cộng thêm (px) khi đang trang bị (vd. đèn lồng ở ô offhand). 0 = không phát sáng.
@export var light_radius: float = 0.0
@export var light_color: Color = Color(1, 0.78, 0.45)


func get_category_name() -> String:
	return CATEGORY_NAMES[category]


func is_equippable() -> bool:
	return equip_slot != &""


func is_consumable() -> bool:
	return consumable != null


func is_usable() -> bool:
	return consumable != null or deploy_scene != null


func is_light_source() -> bool:
	return light_radius > 0.0


func is_tool() -> bool:
	return tool_type != &""


## Có hao mòn (độ bền) hoặc cháy hết (đuốc) — hiện thanh + số trên ô đồ / tooltip.
func has_wear() -> bool:
	return max_durability > 0 or burn_minutes > 0.0


## Độ bền hiện tại của stack (thiếu field = mới, đầy).
func durability_of(stack: ItemStack) -> int:
	var value: Variant = stack.data.get("durability") if stack != null else null
	return clampi(int(value), 0, max_durability) if (value is int or value is float) else max_durability


## Thời gian cháy còn lại (phút game) của stack.
func fuel_of(stack: ItemStack) -> float:
	var value: Variant = stack.data.get("fuel") if stack != null else null
	return clampf(float(value), 0.0, burn_minutes) if (value is int or value is float) else burn_minutes


## Tỉ lệ còn lại 0..1 (1 nếu không hao mòn).
func wear_ratio(stack: ItemStack) -> float:
	if max_durability > 0:
		return float(durability_of(stack)) / max_durability
	if burn_minutes > 0.0:
		return fuel_of(stack) / burn_minutes
	return 1.0


## "Độ bền 37/40" / "Còn cháy 3 giờ 20 phút" ("" nếu không hao mòn).
func describe_wear(stack: ItemStack) -> String:
	if max_durability > 0:
		return "Độ bền %d/%d" % [durability_of(stack), max_durability]
	if burn_minutes > 0.0:
		var minutes: int = ceili(fuel_of(stack))
		return "Còn cháy %d giờ %02d phút" % [minutes / 60, minutes % 60]
	return ""


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
	if consumable != null and is_equippable():
		errors.append("item vừa dùng được vừa trang bị được")
	if consumable != null and consumable.buff != null and not consumable.buff.is_valid():
		errors.append("buff của consumable không hợp lệ")
	if consumable != null and deploy_scene != null:
		errors.append("item vừa ăn được vừa dựng được")
	if armor > 0 and not is_equippable():
		errors.append("có giáp nhưng không trang bị được")
	if light_radius < 0.0:
		errors.append("light_radius < 0")
	if has_wear() and max_stack != 1:
		errors.append("item có độ bền / thời gian cháy phải có max_stack = 1")
	if tool_type != &"" and equip_slot != &"weapon":
		errors.append("công cụ phải trang bị ở ô weapon (tay chính)")
	if max_durability < 0 or burn_minutes < 0.0 or max_per_map < 0:
		errors.append("max_durability / burn_minutes / max_per_map < 0")
	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()
