class_name SaveMigrations
extends RefCounted
## Migration giữa các phiên bản save (TASK M2). Mỗi hàm nhận dữ liệu version N, trả dữ liệu version N + 1.
## SaveService đăng ký qua register_all() và tự đặt `schema_version` sau mỗi bước.
## Quy ước: migration chỉ thêm/đổi/bỏ field theo cấu trúc; giá trị mặc định ghi rõ ở đây (không đọc Resource thiết kế,
## để save cũ cho cùng kết quả dù thông số game đổi sau này).

## Đồng hồ khi bắt đầu game (TimeSettings mặc định): 6:00 ngày 1.
const DEFAULT_CLOCK: Dictionary = {"version": 1, "day": 1, "minute": 360}


static func register_all(service: Node) -> void:
	service.call(&"register_migration", 1, migrate_1_to_2)


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
