class_name MobilitySettings
extends Resource
## Thông số chạy / né của Player (TASK M2). Giá trị mặc định + lý do: docs/architecture.md mục 2m.
## Khoảng cách đo trên MẶT ĐẤT (GroundSpace) nên né trên map isometric đi đúng quãng như map cũ.

## Tốc độ khi giữ Shift = move_speed × hệ số này.
@export var sprint_multiplier: float = 1.5
## Quãng lướt (px mặt đất) và thời gian lướt (giây).
@export var dodge_distance: float = 72.0
@export var dodge_duration: float = 0.2
## Thời gian bất tử tính từ lúc bắt đầu né (giây); dài hơn lúc lướt một chút.
@export var dodge_invulnerable_time: float = 0.3
## Thời gian chờ giữa hai lần né (giây, tính từ lúc kết thúc lướt).
@export var dodge_cooldown: float = 0.5


func get_dodge_speed() -> float:
	return dodge_distance / maxf(dodge_duration, 0.01)
