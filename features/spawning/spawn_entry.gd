class_name SpawnEntry
extends Resource
## Một dòng của bảng spawn (TASK M4): loại quái, khung giờ, trọng số, số tối đa trên map, tầng cho phép, cỡ bầy.
## Dữ liệu thiết kế (chỉ đọc lúc chạy).

enum Period {
	NIGHT, ## Từ hoàng hôn tới trước bình minh (quái đêm: tan biến lúc bình minh).
	DAY,   ## Từ bình minh tới trước hoàng hôn.
	ANY,   ## Mọi lúc.
}

const PERIOD_NAMES: Array[String] = ["Đêm", "Ngày", "Mọi lúc"]

## Khóa ổn định (trùng Enemy.enemy_id của scene) — lưu trong save.
@export var enemy_id: StringName = &""
@export var scene: PackedScene
@export var period: Period = Period.NIGHT
## Trọng số khi chọn ngẫu nhiên giữa các dòng còn chỗ.
@export var weight: float = 1.0
## Số con loại này tối đa cùng lúc trên map (tính cả bầy).
@export var max_on_map: int = 3
## Tầng (ElevationMap) được phép spawn.
@export var tiers: Array[int] = [0]
## Cỡ bầy: spawn đủ [pack_min, pack_max] con cùng lúc (cùng EnemyPack nếu > 1), thiếu chỗ thì không spawn con nào.
@export_range(1, 8) var pack_min: int = 1
@export_range(1, 8) var pack_max: int = 1


func is_valid() -> bool:
	return enemy_id != &"" and scene != null and weight > 0.0 and max_on_map >= pack_min and not tiers.is_empty() \
		and pack_max >= pack_min


func is_active(night: bool) -> bool:
	return period == Period.ANY or (period == Period.NIGHT) == night


func is_night_only() -> bool:
	return period == Period.NIGHT
