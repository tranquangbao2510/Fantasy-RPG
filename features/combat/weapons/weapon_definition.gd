class_name WeaponDefinition
extends Resource
## Định nghĩa một vũ khí (dữ liệu thiết kế, chỉ đọc lúc chạy). Không chứa trạng thái combat.
## Vũ khí chỉ quyết định đánh thường (combo); kỹ năng chủ động thuộc class, không thuộc vũ khí.

## ID ổn định, không phụ thuộc tên hiển thị (vd. &"test_sword").
@export var weapon_id: StringName = &""
@export var display_name: String = ""
## Loại vũ khí (vd. &"sword"). Class System sau này dùng để xác định vũ khí được phép dùng.
@export var weapon_type_id: StringName = &""
@export var combo: ComboDefinition

@export_group("Placeholder visual")
@export var visual_color: Color = Color(0.85, 0.85, 0.9)
@export var visual_length: float = 18.0
@export var visual_width: float = 3.0


func is_valid() -> bool:
	return weapon_id != &"" and weapon_type_id != &"" and combo != null and combo.is_valid()
