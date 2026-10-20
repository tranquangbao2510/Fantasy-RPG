class_name BuffDefinition
extends Resource
## Hiệu ứng tạm thời (TASK M2, vd. từ đồ ăn): nhân một chỉ số trong `duration` giây thực. Dữ liệu thiết kế.
## Mở rộng: thêm loại vào Stat + chỗ đọc hệ số (BuffComponent.get_multiplier).

enum Stat {
	STAMINA_REGEN, ## Tốc độ hồi stamina.
	MANA_REGEN,    ## Tốc độ hồi mana.
	MOVE_SPEED,    ## Tốc độ di chuyển.
}

const STAT_NAMES: Array[String] = ["hồi stamina", "hồi mana", "tốc độ"]

## ID ổn định; ăn lại cùng buff thì làm mới thời gian (không cộng dồn).
@export var buff_id: StringName = &""
@export var display_name: String = ""
@export var stat: Stat = Stat.STAMINA_REGEN
@export var multiplier: float = 1.5
@export var duration: float = 120.0


func is_valid() -> bool:
	return buff_id != &"" and not display_name.is_empty() and multiplier > 0.0 and duration > 0.0


## "Ấm bụng: hồi stamina ×1.5"
func describe() -> String:
	return "%s: %s ×%s" % [display_name, STAT_NAMES[stat], String.num(multiplier, 2)]
