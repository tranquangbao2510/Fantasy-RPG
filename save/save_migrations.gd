class_name SaveMigrations
extends RefCounted
## Migration giữa các phiên bản save (TASK M2: v1 → v2; TASK M3: v2 → v3; TASK M4: v3 → v4; TASK M5: v4 → v5; TASK M6: v5 → v6). Mỗi hàm nhận dữ liệu version N, trả dữ liệu version N + 1.
## SaveService đăng ký qua register_all() và tự đặt `schema_version` sau mỗi bước.
## Quy ước: migration chỉ thêm/đổi/bỏ field theo cấu trúc; giá trị mặc định ghi rõ ở đây (không đọc Resource thiết kế,
## để save cũ cho cùng kết quả dù thông số game đổi sau này).

## Đồng hồ khi bắt đầu game (TimeSettings mặc định): 6:00 ngày 1.
const DEFAULT_CLOCK: Dictionary = {"version": 1, "day": 1, "minute": 360}


static func register_all(service: Node) -> void:
	service.call(&"register_migration", 1, migrate_1_to_2)
	service.call(&"register_migration", 2, migrate_2_to_3)
	service.call(&"register_migration", 3, migrate_3_to_4)
	service.call(&"register_migration", 4, migrate_4_to_5)
	service.call(&"register_migration", 5, migrate_5_to_6)


## v1 (M1) → v2 (M2: thời gian & sinh tồn).
## - global.clock: thêm, mặc định 6:00 ngày 1.
## - global.player.survival: thêm {} → mọi chỉ số (mana, stamina, đói) đầy, chưa có điểm hồi sinh (về giường "nhà").
## - maps.<id>.world_items: thêm death_bags = [], deployed = [] (chưa có túi đồ rơi / lều).
static func migrate_1_to_2(data: Dictionary) -> Dictionary:
	var global: Dictionary = data.get("global", {}) if data.get("global") is Dictionary else {}
	if not global.has("clock"):
		global["clock"] = DEFAULT_CLOCK.duplicate()
	var player: Variant = global.get("player")
	if player is Dictionary and not (player as Dictionary).has("survival"):
		(player as Dictionary)["survival"] = {}
	data["global"] = global
	var maps: Variant = data.get("maps", {})
	if maps is Dictionary:
		for map_id: Variant in maps:
			var states: Variant = maps[map_id]
			if states is Dictionary and states.get("world_items") is Dictionary:
				var items: Dictionary = states["world_items"]
				if not items.has("death_bags"):
					items["death_bags"] = []
				if not items.has("deployed"):
					items["deployed"] = []
	return data


## v2 (M2) → v3 (M3: khai thác, chế tạo, lửa trại).
## - maps.<id>.resource_nodes: thêm {version 1, nodes: {}} → mọi node tài nguyên đầy (map M2 chưa có node nào bị khai thác).
## - maps.<id>.world_items.deployed[*].state: thêm {} (lều không có trạng thái riêng; lửa trại mới có từ v3 — lưu
##   {fuel, lit}); world_items.version → 3.
## - Độ bền công cụ / thời gian cháy của đuốc: lưu trong ItemStack.data ("durability" / "fuel"; thiếu = mới, đầy). Save v2
##   chưa có công cụ / đuốc nên túi đồ, trang bị, rương giữ nguyên.
static func migrate_2_to_3(data: Dictionary) -> Dictionary:
	var maps: Variant = data.get("maps", {})
	if not maps is Dictionary:
		return data
	for map_id: Variant in maps:
		var states: Variant = maps[map_id]
		if not states is Dictionary:
			continue
		if not (states as Dictionary).has("resource_nodes"):
			states["resource_nodes"] = {"version": 1, "nodes": {}}
		if states.get("world_items") is Dictionary:
			var items: Dictionary = states["world_items"]
			items["version"] = 3
			var deployed: Variant = items.get("deployed", [])
			for entry: Variant in (deployed if deployed is Array else []):
				if entry is Dictionary and not (entry as Dictionary).has("state"):
					entry["state"] = {}
	return data


## v3 (M3) → v4 (M4: quái đêm, lưu enemy + buff).
## - maps.<id>.enemies: thêm {version 1, enemies: []} → chưa có quái do EnemySpawner sinh (M3 chưa có quái đêm).
##   Enemy đặt sẵn trong scene (save id `enemy:<save_id>`) không có trong save cũ → giữ HP / vị trí của scene (như M3).
## - global.player.survival.buffs: thêm [] (M3 không lưu buff → tải lại không còn buff, như hành vi M3).
static func migrate_3_to_4(data: Dictionary) -> Dictionary:
	var global: Dictionary = data.get("global", {}) if data.get("global") is Dictionary else {}
	var player: Variant = global.get("player")
	if player is Dictionary and (player as Dictionary).get("survival") is Dictionary:
		var survival: Dictionary = player["survival"]
		if not survival.has("buffs"):
			survival["buffs"] = []
	data["global"] = global
	var maps: Variant = data.get("maps", {})
	if maps is Dictionary:
		for map_id: Variant in maps:
			var states: Variant = maps[map_id]
			if states is Dictionary and not (states as Dictionary).has("enemies"):
				states["enemies"] = {"version": 1, "enemies": []}
	return data


## v4 (M4) → v5 (M5: trồng trọt).
## - maps.<id>.farms: thêm {version 1, fields: {}} → mọi ô ruộng là cỏ (M4 chưa có ruộng). Không có `last_tick` →
##   FarmLayer coi như đã xử lý tới giờ hiện tại của đồng hồ (không bù ngày).
##   Cấu trúc đầy đủ (M5): {version, last_tick, fields: {field_id: {plots: {"c,r": {state ("tilled" / "planted"), crop,
##   stage, age, watered_day, wet, dry_days, fallow_days}}}}} — ô cỏ không lưu.
## - Lượng nước trong bình tưới: ItemStack.data["water"] (thiếu = rỗng), như độ bền / nhiên liệu ở v3. Save v4 chưa có
##   bình tưới nên túi đồ, trang bị, rương giữ nguyên.
static func migrate_4_to_5(data: Dictionary) -> Dictionary:
	var maps: Variant = data.get("maps", {})
	if maps is Dictionary:
		for map_id: Variant in maps:
			var states: Variant = maps[map_id]
			if states is Dictionary and not (states as Dictionary).has("farms"):
				states["farms"] = {"version": 1, "fields": {}}
	return data


## v5 (M5) → v6 (M6: ô save + ruộng đúng lưới).
## - Ruộng `glade_home`: M5 là 6 × 4 ô NỬA ô lưới iso (góc trên tại lưới (28.5, 33)); M6 là 6 × 4 ô ĐÚNG 1 ô lưới (góc
##   trên tại (26, 33)). Mỗi ô cũ chuyển sang ô mới chứa tâm của nó (cây giữ đúng chỗ trên mặt đất). Nhiều ô cũ rơi vào cùng
##   ô mới → giữ ô "tiến xa nhất" (có cây, nhiều ngày tuổi nhất; không thì đất cày); cây của các ô còn lại được TRẢ VỀ TÚI:
##   cây chưa chín → 1 hạt / củ giống, cây chín → `MATURE_REFUND` (sản lượng tối thiểu). Ô cũ nằm ngoài lưới mới cũng trả
##   như vậy. Đồ trả ghi vào `farms.refunds = [{id, count}]`; FarmLayer cho vào túi khi tải (túi đầy → rơi cạnh người chơi).
## - Vật dựng (lửa trại, lều, cối đá) nằm trong vùng ruộng mới → bỏ khỏi map, trả 1 item về túi (refunds) — không mất đồ.
## - farms.version → 2.
## - Ô save: chỉ đổi chỗ file (SaveService._ensure_layout), không đổi nội dung.
const FIELD_REMAP_V6: Dictionary = {
	"glade_home": {"map_id": "glade", "old_origin": [28.5, 33.0], "old_cell": 0.5, "new_origin": [26.0, 33.0], "columns": 6, "rows": 4},
}
## Hạt trả lại khi cây chưa chín bị bỏ (theo CropDefinition.seed_item_id lúc M6).
const SEED_OF_CROP: Dictionary = {"wheat": "wheat_seed", "potato": "seed_potato", "berry_bush": "berry"}
## Cây chín bị bỏ: trả [item, số lượng] = sản lượng tối thiểu (CropDefinition.yield_min lúc M6).
const MATURE_REFUND: Dictionary = {"wheat": ["wheat", 2], "potato": ["potato", 2], "berry_bush": ["berry", 2]}
## Giai đoạn chín (mọi cây M5 đều 4 giai đoạn).
const MATURE_STAGE: int = 3


static func migrate_5_to_6(data: Dictionary) -> Dictionary:
	var maps: Variant = data.get("maps", {})
	if not maps is Dictionary:
		return data
	for field_id: String in FIELD_REMAP_V6:
		var spec: Dictionary = FIELD_REMAP_V6[field_id]
		var states: Variant = (maps as Dictionary).get(spec["map_id"])
		if not states is Dictionary or not (states as Dictionary).get("farms") is Dictionary:
			continue
		var farms: Dictionary = states["farms"]
		var refunds: Array = farms.get("refunds", []) if farms.get("refunds") is Array else []
		var fields: Dictionary = farms.get("fields", {}) if farms.get("fields") is Dictionary else {}
		var field: Variant = fields.get(field_id)
		if field is Dictionary and (field as Dictionary).get("plots") is Dictionary:
			(field as Dictionary)["plots"] = _remap_plots((field as Dictionary)["plots"], spec, refunds)
		var items: Variant = (states as Dictionary).get("world_items")
		if items is Dictionary and (items as Dictionary).get("deployed") is Array:
			var kept: Array = []
			for entry: Variant in (items as Dictionary)["deployed"]:
				if entry is Dictionary and _in_new_field((entry as Dictionary).get("position"), spec):
					_add_refund(refunds, str((entry as Dictionary).get("item_id", "")), 1)
				else:
					kept.append(entry)
			(items as Dictionary)["deployed"] = kept
		farms["refunds"] = refunds
		farms["version"] = 2
	return data


static func _remap_plots(plots: Dictionary, spec: Dictionary, refunds: Array) -> Dictionary:
	var old_origin: Vector2 = Vector2(spec["old_origin"][0], spec["old_origin"][1])
	var new_origin: Vector2 = Vector2(spec["new_origin"][0], spec["new_origin"][1])
	var old_cell: float = spec["old_cell"]
	var winners: Dictionary = {}
	var losers: Array = []
	var keys: Array = plots.keys()
	keys.sort()
	for key: Variant in keys:
		var state: Variant = plots[key]
		var parts: PackedStringArray = str(key).split(",")
		if not state is Dictionary or parts.size() != 2:
			continue
		# Tâm ô cũ trên lưới iso → ô mới chứa nó.
		var center: Vector2 = old_origin + (Vector2(parts[0].to_float(), parts[1].to_float()) + Vector2(0.5, 0.5)) * old_cell
		var cell: Vector2i = Vector2i(floori(center.x - new_origin.x), floori(center.y - new_origin.y))
		if cell.x < 0 or cell.y < 0 or cell.x >= int(spec["columns"]) or cell.y >= int(spec["rows"]):
			losers.append(state)
			continue
		var new_key: String = "%d,%d" % [cell.x, cell.y]
		if not winners.has(new_key):
			winners[new_key] = state
		elif _plot_rank(state) > _plot_rank(winners[new_key]):
			losers.append(winners[new_key])
			winners[new_key] = state
		else:
			losers.append(state)
	for state: Variant in losers:
		var crop: String = str((state as Dictionary).get("crop", ""))
		if str((state as Dictionary).get("state", "")) != "planted" or crop.is_empty():
			continue
		if int((state as Dictionary).get("stage", 0)) >= MATURE_STAGE and MATURE_REFUND.has(crop):
			_add_refund(refunds, MATURE_REFUND[crop][0], MATURE_REFUND[crop][1])
		elif SEED_OF_CROP.has(crop):
			_add_refund(refunds, SEED_OF_CROP[crop], 1)
	return winners


## Ô có cây (nhiều ngày tuổi hơn đứng trước) > đất cày > còn lại.
static func _plot_rank(state: Variant) -> int:
	if not state is Dictionary:
		return 0
	match str((state as Dictionary).get("state", "")):
		"planted":
			return 1000 + int((state as Dictionary).get("age", 0))
		"tilled":
			return 1
	return 0


## Vị trí (toạ độ màn hình [x, y]) nằm trong vùng ruộng mới (theo lưới iso 64 × 32: i = (x/32 + y/16)/2, j = (y/16 − x/32)/2).
static func _in_new_field(position: Variant, spec: Dictionary) -> bool:
	if not position is Array or (position as Array).size() != 2:
		return false
	var x: float = float(position[0])
	var y: float = float(position[1])
	var grid: Vector2 = Vector2((x / 32.0 + y / 16.0) / 2.0, (y / 16.0 - x / 32.0) / 2.0)
	var local: Vector2 = grid - Vector2(spec["new_origin"][0], spec["new_origin"][1])
	return local.x >= 0.0 and local.y >= 0.0 and local.x < float(spec["columns"]) and local.y < float(spec["rows"])


static func _add_refund(refunds: Array, item_id: String, count: int) -> void:
	if item_id.is_empty() or count <= 0:
		return
	for entry: Variant in refunds:
		if entry is Dictionary and str((entry as Dictionary).get("id")) == item_id:
			entry["count"] = int(entry["count"]) + count
			return
	refunds.append({"id": item_id, "count": count})
