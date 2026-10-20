class_name ManaSettings
extends Resource
## Thông số Mana (TASK M2). Giá trị mặc định + lý do: docs/architecture.md mục 2m.

@export var max_mana: float = 100.0
## Mana hồi mỗi giây thực.
@export var regen_per_second: float = 4.0
## Thời gian chờ (giây) sau lần tiêu mana trước khi bắt đầu hồi.
@export var regen_delay: float = 1.0
