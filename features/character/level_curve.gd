class_name LevelCurve
extends Resource
## Bảng EXP cần để lên cấp (dữ liệu thiết kế). Dùng chung cho Character Level và Class Mastery.
## Mọi giá trị hiện tại là placeholder, không phải công thức cân bằng chính thức.

## exp_to_next_level[i] = EXP cần để từ level i+1 lên level i+2. Level tối đa = size() + 1.
@export var exp_to_next_level: Array[int] = []


func get_max_level() -> int:
	return exp_to_next_level.size() + 1


## EXP cần để từ `level` lên level kế; 0 nếu đã tối đa hoặc level không hợp lệ.
func get_exp_to_next(level: int) -> int:
	if level < 1 or level >= get_max_level():
		return 0
	return exp_to_next_level[level - 1]


func is_valid() -> bool:
	return exp_to_next_level.all(func(value: int) -> bool: return value > 0)
