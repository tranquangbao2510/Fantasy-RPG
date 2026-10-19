class_name CharacterLevel
extends Node
## Cấp độ tổng thể của nhân vật (dùng chung cho mọi class). Độc lập với Class Mastery.
## Không thưởng EXP tự động, không tăng chỉ số: hiện chỉ có EXP debug (quy tắc thưởng chưa được chốt).

signal level_changed(level: int)
signal exp_changed(level: int, experience: int)

@export var curve: LevelCurve

var _progress: LevelProgress


func _ready() -> void:
	if curve == null or not curve.is_valid():
		push_warning("[CharacterLevel] LevelCurve không hợp lệ; nhân vật giữ level 1.")
		curve = LevelCurve.new()
	_progress = LevelProgress.new(curve)
	_progress.changed.connect(func(level: int, experience: int) -> void: exp_changed.emit(level, experience))
	_progress.leveled_up.connect(func(level: int) -> void: level_changed.emit(level))


func get_level() -> int:
	return _progress.level


func get_exp() -> int:
	return _progress.experience


func get_exp_to_next() -> int:
	return _progress.get_exp_to_next()


func get_max_level() -> int:
	return _progress.get_max_level()


## Cộng EXP (hiện chỉ dùng cho debug). Trả về số level tăng.
func add_exp(amount: int) -> int:
	return _progress.add_exp(amount)


func to_dict() -> Dictionary:
	return _progress.to_dict()


## Khôi phục từ to_dict() (save). Field thiếu → level 1.
func load_dict(value: Variant) -> void:
	_progress.load_dict(value)
	level_changed.emit(_progress.level)
