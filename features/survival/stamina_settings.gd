class_name StaminaSettings
extends Resource
## Thông số Stamina (TASK M2). Giá trị mặc định + lý do: docs/architecture.md mục 2m.

@export var max_stamina: float = 100.0
## Stamina hồi mỗi giây thực khi không dùng.
@export var regen_per_second: float = 30.0
## Thời gian chờ (giây) sau lần dùng trước khi hồi.
@export var regen_delay: float = 0.6
## Tiêu mỗi giây khi chạy (giữ Shift).
@export var sprint_cost_per_second: float = 20.0
## Tiêu mỗi lần né; phải còn đủ mới né được.
@export var dodge_cost: float = 25.0
## Cạn về 0 thì "kiệt sức": không chạy/né được tới khi hồi lại tới ngưỡng này.
@export var exhausted_recover_threshold: float = 30.0
