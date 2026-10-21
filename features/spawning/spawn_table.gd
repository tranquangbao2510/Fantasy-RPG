class_name SpawnTable
extends Resource
## Bảng spawn của một map (TASK M4): các SpawnEntry + luật vị trí. Dữ liệu thiết kế (chỉ đọc lúc chạy).
## Luật vị trí (EnemySpawner.get_spawn_block_reason): ngoài vùng camera thấy (+ screen_margin), cách người chơi ≥
## min_player_distance (px mặt đất), đúng tầng, không trên nước / vách / vực / vật cản (PlacementCheck), không trong vùng
## sáng an toàn (VisionLight.safe_zone + safe_zone_margin).

@export var map_id: StringName = &""
@export var entries: Array[SpawnEntry] = []
## Giây thực giữa hai lần thử spawn.
## Quái đêm (SpawnEntry.Period.NIGHT) sinh từ phút này tới trước bình minh (TimeSettings.dawn_start). 18:00 — sau cảnh báo
## "Trời sắp tối…" (17:00, DayNightSettings.dusk_warning_minute) đúng 1 giờ game, trùng giờ bắt đầu ngủ được (TASK M4.1).
@export_range(0, 1439) var night_from_minute: int = 1080
@export var spawn_interval: float = 5.0
## Tổng số quái do bảng này sinh ra tối đa cùng lúc.
@export var max_total: int = 12
@export var min_player_distance: float = 360.0
@export var max_player_distance: float = 720.0
## Lề ngoài vùng camera (px màn hình world) — điểm spawn phải nằm ngoài vùng nhìn thấy + lề.
@export var screen_margin: float = 48.0
@export var safe_zone_margin: float = 24.0
## Số lần thử chọn điểm cho một lần spawn.
@export var position_attempts: int = 16
## Thành viên bầy đứng quanh điểm đầu trong bán kính này (px mặt đất).
@export var pack_spread: float = 32.0
## Bán kính footprint kiểm tra vật cản (px mặt đất).
@export var footprint_radius: float = 10.0
## Bình minh: quái đêm trong tầm nhìn mờ dần trong bao lâu (giây).
@export var dawn_fade_time: float = 1.5
## Xác quái do bảng sinh ra nằm lại bao lâu rồi mờ đi (giây).
@export var corpse_time: float = 3.0


func find_entry(enemy_id: StringName) -> SpawnEntry:
	for entry: SpawnEntry in entries:
		if entry != null and entry.enemy_id == enemy_id:
			return entry
	return null


## Chọn dòng theo trọng số trong số dòng đang hoạt động (`night`) còn chỗ cho ít nhất pack_min con.
## `counts`: enemy_id → số con hiện có; `total`: tổng hiện có. null nếu không dòng nào hợp lệ.
func pick(rng: RandomNumberGenerator, night: bool, counts: Dictionary, total: int) -> SpawnEntry:
	var candidates: Array[SpawnEntry] = []
	var sum: float = 0.0
	for entry: SpawnEntry in entries:
		if entry == null or not entry.is_valid() or not entry.is_active(night):
			continue
		if int(counts.get(entry.enemy_id, 0)) + entry.pack_min > entry.max_on_map or total + entry.pack_min > max_total:
			continue
		candidates.append(entry)
		sum += entry.weight
	if candidates.is_empty():
		return null
	var roll: float = rng.randf() * sum
	for entry: SpawnEntry in candidates:
		roll -= entry.weight
		if roll <= 0.0:
			return entry
	return candidates.back()


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for i: int in entries.size():
		var entry: SpawnEntry = entries[i]
		if entry == null or not entry.is_valid():
			errors.append("entries[%d] không hợp lệ" % i)
		elif seen.has(entry.enemy_id):
			errors.append("enemy_id trùng '%s'" % entry.enemy_id)
		else:
			seen[entry.enemy_id] = true
	if min_player_distance >= max_player_distance:
		errors.append("min_player_distance >= max_player_distance")
	return errors
