class_name LootTable
extends Resource
## Bảng rơi đồ data-driven (TASK M3): dùng cho node tài nguyên (gỗ, đá, quả mọng...) và enemy (thịt sống).
## Mỗi dòng tung độc lập: rơi với xác suất `chance`, số lượng đều trong [min_count, max_count].

@export var entries: Array[LootEntry] = []


## Tung bảng: danh sách stack (đã gộp theo item, bỏ dòng không rơi). `rng` null → ngẫu nhiên toàn cục.
func roll(rng: RandomNumberGenerator = null) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	for entry: LootEntry in entries:
		if entry == null or not entry.is_valid():
			continue
		var hit: float = rng.randf() if rng != null else randf()
		if hit >= entry.chance:
			continue
		var amount: int = rng.randi_range(entry.min_count, entry.max_count) if rng != null else randi_range(entry.min_count, entry.max_count)
		var merged: bool = false
		for stack: ItemStack in result:
			if stack.item_id == entry.item_id:
				stack.count += amount
				merged = true
		if not merged:
			result.append(ItemStack.new(entry.item_id, amount))
	return result


## Lỗi dữ liệu (dòng null / không hợp lệ / item không có trong database). Rỗng = hợp lệ.
func get_validation_errors(database: ItemDatabase) -> Array[String]:
	var errors: Array[String] = []
	for i: int in entries.size():
		var entry: LootEntry = entries[i]
		if entry == null or not entry.is_valid():
			errors.append("entries[%d] không hợp lệ" % i)
		elif database != null and not database.has_item(entry.item_id):
			errors.append("entries[%d]: item không tồn tại '%s'" % [i, entry.item_id])
	return errors


## "Gỗ 2–3 · Cành 1 (50 %)"
func describe(database: ItemDatabase) -> String:
	var parts: Array[String] = []
	for entry: LootEntry in entries:
		if entry != null and entry.is_valid():
			parts.append(entry.describe(database))
	return " · ".join(parts)
