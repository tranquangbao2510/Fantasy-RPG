class_name ResourceNodeDefinition
extends Resource
## Một loại node tài nguyên (TASK M3; dữ liệu thiết kế, chỉ đọc): cây, đá, bụi mọng, bụi cỏ.
## - Khai thác: mỗi lần tương tác (E) trừ "sức khai thác" (tay không = ResourceNode.HAND_POWER, công cụ =
##   ItemDefinition.harvest_power) vào `toughness`; đủ → nhận `yield_table` (vào thẳng túi).
## - `required_tool`: &"" = tay không; &"axe" / &"pickaxe" = phải cầm công cụ loại đó ở tay chính (mỗi lần trừ 1 độ bền).
##   Thiếu công cụ: nếu có `hand_table` (vd. nhặt cành dưới gốc cây) thì nhặt được `hand_uses` lần mỗi chu kỳ mọc; hết
##   thì hiện `missing_tool_text` ("Cần rìu").
## - `depletes`: true → node bị phá (ẩn, không chặn đường) tới khi mọc lại; false → vẫn đứng đó (bụi mọng), chỉ hết quả.
## - Mọc lại sau `regrow_days` ngày game (lúc 0:00 của ngày đó).

@export var id: StringName = &""
@export var display_name: String = ""
@export var required_tool: StringName = &""
## Động từ trên lời nhắc tương tác ("Chặt", "Đập", "Hái", "Nhổ").
@export var harvest_verb: String = "Khai thác"
@export var missing_tool_text: String = ""
## Tổng sức khai thác cần để thu hoạch một lần.
@export_range(1, 50) var toughness: int = 1
@export var yield_table: LootTable
@export var depletes: bool = true
@export_range(1, 30) var regrow_days: int = 1

@export_group("Nhặt bằng tay khi thiếu công cụ")
@export var hand_verb: String = ""
@export var hand_table: LootTable
@export_range(0, 10) var hand_uses: int = 0


func needs_tool() -> bool:
	return required_tool != &""


func can_hand_gather() -> bool:
	return hand_table != null and hand_uses > 0


func get_validation_errors(database: ItemDatabase) -> Array[String]:
	var errors: Array[String] = []
	if id == &"" or display_name.is_empty():
		errors.append("id / display_name rỗng")
	if yield_table == null or yield_table.entries.is_empty():
		errors.append("thiếu yield_table")
	else:
		errors.append_array(yield_table.get_validation_errors(database))
	if needs_tool() and missing_tool_text.is_empty():
		errors.append("cần công cụ nhưng thiếu missing_tool_text")
	if hand_table != null:
		errors.append_array(hand_table.get_validation_errors(database))
	return errors
