class_name HungerSettings
extends Resource
## Thông số Đói (TASK M2). Thang 0–100: 100 = no, 0 = đói lả. Giá trị mặc định + lý do: docs/architecture.md mục 2m.

@export var max_hunger: float = 100.0
## Giảm mỗi giờ game khi thức / khi ngủ.
@export var decay_per_hour_awake: float = 4.0
@export var decay_per_hour_sleeping: float = 2.0
## Dưới ngưỡng này: không hồi stamina.
@export var low_threshold: float = 25.0
## Từ ngưỡng này trở lên: "no" — không ăn thêm món có hồi đói.
@export var full_threshold: float = 95.0
## Khi đói = 0: mất `starving_damage` HP mỗi `starving_interval_minutes` phút game.
@export var starving_damage: int = 1
@export var starving_interval_minutes: float = 3.0

@export_group("Hoạt động")
@export var sprint_cost_per_second: float = 0.08
@export var dodge_cost: float = 0.5
@export var attack_cost: float = 0.15
@export var skill_cost: float = 0.4


func cost_of(kind: Activity.Kind) -> float:
	match kind:
		Activity.Kind.SPRINT:
			return sprint_cost_per_second
		Activity.Kind.DODGE:
			return dodge_cost
		Activity.Kind.ATTACK:
			return attack_cost
		Activity.Kind.SKILL:
			return skill_cost
	return 0.0
