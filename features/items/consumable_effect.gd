class_name ConsumableEffect
extends Resource
## Tác dụng khi dùng (ăn/uống) một item (TASK M2). Gắn vào ItemDefinition.consumable. Dữ liệu thiết kế.
## Số dương = hồi, âm = trừ (vd. thịt sống trừ HP nhẹ). Mở rộng (M3 nấu ăn): món mới chỉ là item + ConsumableEffect;
## thêm loại tác dụng → thêm field ở đây + một dòng trong ConsumableUser.apply_effect.

@export var hunger: float = 0.0
@export var health: int = 0
@export var mana: float = 0.0
## Buff tạm thời (tùy chọn).
@export var buff: BuffDefinition


## Món có làm no không (đang no thì không ăn được món này).
func is_food() -> bool:
	return hunger > 0.0


## "+30 Đói · −3 HP"
func describe() -> String:
	var parts: Array[String] = []
	for pair: Array in [[hunger, "Đói"], [health, "HP"], [mana, "Mana"]]:
		var amount: float = pair[0]
		if amount != 0.0:
			parts.append("%s%s %s" % ["+" if amount > 0.0 else "−", String.num(absf(amount), 0), pair[1]])
	if buff != null:
		parts.append(buff.describe())
	return " · ".join(parts)
