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
## Khi đói = 0: mất `starving_percent_per_hour` % HP TỐI ĐA mỗi giờ game (TASK M3). Đầy HP → chết sau
## 100 / % giờ game = 100 / % × 60 / (phút game mỗi giây thực) giây thực; mặc định 6 %/giờ, 1 ngày = 1200 s:
## 16.7 giờ game = 1000 phút game = 833 s ≈ 13.9 phút thực, không phụ thuộc max HP (passive +HP vẫn chết cùng lúc).
@export var starving_percent_per_hour: float = 6.0

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
