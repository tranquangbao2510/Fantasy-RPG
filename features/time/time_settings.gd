class_name TimeSettings
extends Resource
## Thông số đồng hồ trong game (dữ liệu thiết kế, TASK M2). Phút trong ngày: 0 = 0:00, 360 = 6:00, 1440 = hết ngày.

## Số giây thực cho một ngày trong game (1200 = 20 phút thực / ngày).
@export var real_seconds_per_day: float = 1200.0
@export var start_day: int = 1
@export_range(0, 1439) var start_minute: int = 360

@export_group("Phase (phút trong ngày)")
## Bình minh bắt đầu / ban ngày / hoàng hôn / ban đêm. Đêm kéo dài qua 0:00 tới bình minh.
@export_range(0, 1439) var dawn_start: int = 300
@export_range(0, 1439) var day_start: int = 420
@export_range(0, 1439) var dusk_start: int = 1020
@export_range(0, 1439) var night_start: int = 1140

@export_group("Debug")
## Hệ số tua nhanh khi bật phím debug tua giờ.
@export var debug_fast_multiplier: float = 10.0
## Số phút nhảy tới mỗi lần nhấn phím debug +giờ.
@export var debug_skip_minutes: int = 60


## Phút game trôi qua mỗi giây thực.
func get_minutes_per_second() -> float:
	return 1440.0 / maxf(real_seconds_per_day, 1.0)


func is_valid() -> bool:
	return real_seconds_per_day > 0.0 and start_day >= 1 and dawn_start < day_start and day_start < dusk_start \
		and dusk_start < night_start
