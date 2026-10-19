class_name LevelProgress
extends RefCounted
## Runtime state của một tiến trình cấp độ (level + EXP) theo một LevelCurve.
## Dùng cho Character Level và mỗi Class Mastery. Level chỉ tăng; ở level tối đa EXP không tích lũy thêm.

signal changed(level: int, experience: int)
signal leveled_up(level: int)

var curve: LevelCurve
var level: int = 1
var experience: int = 0


func _init(p_curve: LevelCurve) -> void:
	curve = p_curve


func get_max_level() -> int:
	return curve.get_max_level() if curve != null else 1


func is_max_level() -> bool:
	return level >= get_max_level()


## EXP cần để lên level kế (0 nếu đã tối đa).
func get_exp_to_next() -> int:
	return curve.get_exp_to_next(level) if curve != null else 0


## Cộng EXP; trả về số level tăng thêm. amount <= 0 bị bỏ qua.
func add_exp(amount: int) -> int:
	if amount <= 0 or is_max_level():
		return 0
	var gained: int = 0
	experience += amount
	while not is_max_level() and experience >= get_exp_to_next():
		experience -= get_exp_to_next()
		level += 1
		gained += 1
		leveled_up.emit(level)
	if is_max_level():
		experience = 0
	changed.emit(level, experience)
	return gained


## Dữ liệu thuần để lưu (save).
func to_dict() -> Dictionary:
	return {"level": level, "exp": experience}


## Khôi phục từ to_dict(). Field thiếu/sai → mặc định (level 1, exp 0); kẹp level trong [1, max], exp trong
## [0, exp tới level kế). Phát `changed`, không phát `leveled_up`.
func load_dict(value: Variant) -> void:
	var dict: Dictionary = value if value is Dictionary else {}
	var saved_level: Variant = dict.get("level", 1)
	var saved_exp: Variant = dict.get("exp", 0)
	level = clampi(int(saved_level) if (saved_level is int or saved_level is float) else 1, 1, get_max_level())
	experience = int(saved_exp) if (saved_exp is int or saved_exp is float) else 0
	experience = 0 if is_max_level() else clampi(experience, 0, maxi(0, get_exp_to_next() - 1))
	changed.emit(level, experience)
