class_name Activity
extends RefCounted
## Loại hoạt động tốn sức (TASK M2). Player báo cho HungerComponent; chi phí tra trong HungerSettings.cost_of.

enum Kind {
	SPRINT, ## Chạy (giữ Shift) — chi phí tính theo giây.
	DODGE,  ## Một lần né.
	ATTACK, ## Một bước combo đánh thường.
	SKILL,  ## Một lần thi triển kỹ năng.
}
