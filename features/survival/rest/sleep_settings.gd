class_name SleepSettings
extends Resource
## Ngủ, ngất, hồi sinh (TASK M2). Giá trị mặc định + lý do: docs/architecture.md mục 2m. Phút trong ngày: 360 = 6:00.

## Ngủ được từ `sleep_from_minute` tới trước `wake_minute` (qua nửa đêm).
@export_range(0, 1439) var sleep_from_minute: int = 1080
@export_range(0, 1439) var wake_minute: int = 360
## Còn thức tới giờ này thì ngất: tỉnh lại TẠI CHỖ lúc wake_minute, không hồi HP, không tự lưu, đói −`faint_hunger_penalty`
## (TASK M3; cộng với phần đói giảm theo nhịp ngủ trong mấy giờ ngất).
@export_range(0, 23) var faint_hour: int = 2
@export var faint_hunger_penalty: float = 10.0
## Ngủ xong hồi thêm (tỉ lệ max) HP: giường (nhà) / lều (TASK M3: giường 100 %, lều 70 %); mana như nhau.
@export_range(0.0, 1.0) var sleep_heal_ratio: float = 1.0
@export_range(0.0, 1.0) var tent_heal_ratio: float = 0.7
@export_range(0.0, 1.0) var sleep_mana_ratio: float = 1.0
## Hồi sinh sau khi chết với tỉ lệ HP này.
@export_range(0.05, 1.0) var respawn_health_ratio: float = 0.5
## Màn hình mờ dần / sáng lại (giây) và thời gian hiện "Ngày N".
@export var fade_time: float = 0.8
@export var title_time: float = 1.5


## Giờ hiện tại có ngủ được không.
func can_sleep_at(minute_of_day: float) -> bool:
	return minute_of_day >= sleep_from_minute or minute_of_day < wake_minute


## Tỉ lệ hồi HP khi ngủ ở chỗ ngủ loại `kind` ("bed" / "tent").
func heal_ratio_for(kind: String) -> float:
	return tent_heal_ratio if kind == "tent" else sleep_heal_ratio


func format_window() -> String:
	return "%02d:%02d–%02d:%02d" % [sleep_from_minute / 60, sleep_from_minute % 60, wake_minute / 60, wake_minute % 60]
