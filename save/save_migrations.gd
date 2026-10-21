class_name SaveMigrations
extends RefCounted
## Migration giữa các phiên bản save (TASK M2: v1 → v2; TASK M3: v2 → v3; TASK M4: v3 → v4; TASK M5: v4 → v5). Mỗi hàm nhận dữ liệu version N, trả dữ liệu version N + 1.
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
