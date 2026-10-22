class_name DebugKeys
extends RefCounted
## Phím debug (TASK M6): chỉ hoạt động ở bản debug (`OS.is_debug_build()` — chạy từ editor / bản export debug); bản export
## release không phản hồi phím nào trong danh sách này. Mọi node xử lý phím debug kiểm tra `DebugKeys.enabled()`.
## Bảng liệt kê các phím (DebugKeysPanel) bật / tắt bằng F12 (`debug_panel`) — cũng chỉ ở bản debug.
## Test giả lập bản release bằng `simulate_release = true` (không chạy được bản export trong test).

## Giả lập bản release (test).
static var simulate_release: bool = false

const PANEL_ACTION: StringName = &"debug_panel"

## [action, mô tả] theo thứ tự hiển thị trong bảng debug.
const ENTRIES: Array = [
	[&"debug_spawn_shade", "Sinh Bóng ma cạnh người chơi"],
	[&"debug_spawn_wolves", "Sinh bầy sói cạnh người chơi"],
	[&"debug_combat_panel", "Bảng debug combat (Combat Sandbox)"],
	[&"debug_spawn_ghoul", "Sinh Thây ma cạnh người chơi"],
	[&"quick_save", "Lưu nhanh vào ô đang chơi"],
	[&"debug_crop_grow", "Cây ở ô dưới con trỏ +1 giai đoạn"],
	[&"debug_time_fast", "Bật / tắt tua giờ ×10"],
	[&"debug_time_skip", "+1 giờ game"],
	[&"quick_load", "Tải nhanh bản mới nhất của ô đang chơi"],
	[&"debug_enemy_radius", "Vẽ bán kính phát hiện của quái"],
	[&"debug_farm_water", "Tưới hết ruộng"],
	[&"debug_panel", "Bật / tắt bảng này + bảng thông tin môi trường"],
	[&"debug_reset", "Reset thử nghiệm (Combat Sandbox / test_map)"],
	[&"debug_weapon_1", "Vũ khí thử 1"],
	[&"debug_weapon_2", "Vũ khí thử 2"],
	[&"debug_weapon_3", "Vũ khí thử 3"],
	[&"debug_progression", "Bảng Class / Progression thử nghiệm"],
]


static func enabled() -> bool:
	return OS.is_debug_build() and not simulate_release


static func actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Array in ENTRIES:
		result.append(entry[0])
	return result


static func is_debug_action(action: StringName) -> bool:
	return actions().has(action)
