class_name SkillRuntime
extends RefCounted
## Trạng thái chạy của một kỹ năng trong một ô (charges, hồi charge, recast delay, cast mode).
## Mỗi ô có instance riêng; không ghi vào SkillDefinition.
##
## Quy tắc charge (prototype): mỗi lần thi triển tiêu 1 charge. Khi charges < max, hồi lần lượt
## từng charge sau mỗi `definition.cooldown` giây. Sau mỗi lần thi triển phải chờ `recast_delay`.
## Có thể thi triển khi charges > 0 và hết recast delay.

## Charges hoặc khả năng thi triển thay đổi (UI đọc lại).
signal changed

var definition: SkillDefinition
var cast_mode: SkillDefinition.CastMode
## Controller bật khi kỹ năng này đang vận sức.
var is_casting: bool = false

var _charges: int = 0
var _recharge_left: float = 0.0
var _recast_left: float = 0.0


func _init(p_definition: SkillDefinition, p_cast_mode: SkillDefinition.CastMode) -> void:
	definition = p_definition
	cast_mode = p_cast_mode
	reset()


## Thay definition (vd. bản sao sau khi lên level/tiến hóa) mà giữ charges và thời gian hồi đang chạy.
## Charges bị kẹp theo max mới; nếu max tăng thì bắt đầu hồi charge còn thiếu.
func set_definition(p_definition: SkillDefinition) -> void:
	definition = p_definition
	_charges = mini(_charges, definition.max_charges)
	if _charges < definition.max_charges and _recharge_left <= 0.0:
		_recharge_left = definition.cooldown
	elif _charges >= definition.max_charges:
		_recharge_left = 0.0
	changed.emit()


func get_charges() -> int:
	return _charges


func get_max_charges() -> int:
	return definition.max_charges


## Thời gian tới lúc có thể thi triển lại (0 nếu sẵn sàng).
func get_cooldown_remaining() -> float:
	if _charges == 0:
		return maxf(_recharge_left, _recast_left)
	return _recast_left


## Thời gian tới khi hồi thêm 1 charge (0 nếu đầy).
func get_recharge_remaining() -> float:
	return _recharge_left


func can_cast() -> bool:
	return _charges > 0 and _recast_left <= 0.0


## Lý do không thể thi triển ("" nếu được).
func get_block_reason() -> String:
	if _charges <= 0:
		return "Đang hồi chiêu"
	if _recast_left > 0.0:
		return "Chưa thể dùng lại"
	return ""


## Tiêu 1 charge. Trả về false nếu chưa thể thi triển.
func consume() -> bool:
	if not can_cast():
		return false
	_charges -= 1
	_recast_left = definition.recast_delay
	if _recharge_left <= 0.0:
		_recharge_left = definition.cooldown
	changed.emit()
	return true


func tick(delta: float) -> void:
	var dirty: bool = false
	if _recast_left > 0.0:
		_recast_left = maxf(0.0, _recast_left - delta)
		dirty = _recast_left == 0.0
	if _charges < definition.max_charges:
		_recharge_left -= delta
		if _recharge_left <= 0.0:
			_charges = mini(_charges + 1, definition.max_charges)
			_recharge_left = definition.cooldown if _charges < definition.max_charges else 0.0
			dirty = true
	if dirty:
		changed.emit()


func reset() -> void:
	_charges = definition.max_charges
	_recharge_left = 0.0
	_recast_left = 0.0
	is_casting = false
	changed.emit()
