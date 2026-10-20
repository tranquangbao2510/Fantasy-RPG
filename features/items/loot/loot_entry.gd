class_name LootEntry
extends Resource
## Một dòng của bảng rơi đồ (TASK M3): item, số lượng ngẫu nhiên trong [min_count, max_count], xác suất rơi.

@export var item_id: StringName = &""
@export_range(1, 99) var min_count: int = 1
@export_range(1, 99) var max_count: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0


func is_valid() -> bool:
	return item_id != &"" and min_count >= 1 and max_count >= min_count and chance > 0.0


## "Gỗ 2–3 (60 %)"
func describe(database: ItemDatabase) -> String:
	var item: ItemDefinition = database.get_item(item_id) if database != null else null
	var name: String = item.display_name if item != null else String(item_id)
	var amount: String = str(min_count) if min_count == max_count else "%d–%d" % [min_count, max_count]
	return "%s %s%s" % [name, amount, "" if chance >= 1.0 else " (%d %%)" % roundi(chance * 100.0)]
