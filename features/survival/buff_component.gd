class_name BuffComponent
extends Node
## Buff tạm thời đang có trên nhân vật (TASK M2). Mỗi buff_id một bản; áp lại thì làm mới thời gian.
## Các buff cùng Stat nhân dồn. Thời gian đếm theo giây thực (physics). Không lưu vào save (giới hạn M2).

signal buffs_changed

## buff_id → [BuffDefinition, giây còn lại]
var _active: Dictionary[StringName, Array] = {}


func _physics_process(delta: float) -> void:
	if _active.is_empty():
		return
	var expired: bool = false
	for buff_id: StringName in _active.keys():
		_active[buff_id][1] -= delta
		if _active[buff_id][1] <= 0.0:
			_active.erase(buff_id)
			expired = true
	if expired:
		buffs_changed.emit()


func apply(buff: BuffDefinition) -> void:
	if buff == null or not buff.is_valid():
		return
	_active[buff.buff_id] = [buff, buff.duration]
	buffs_changed.emit()


func clear() -> void:
	_active.clear()
	buffs_changed.emit()


func has_buff(buff_id: StringName) -> bool:
	return _active.has(buff_id)


func get_time_left(buff_id: StringName) -> float:
	return _active[buff_id][1] if _active.has(buff_id) else 0.0


func get_multiplier(stat: BuffDefinition.Stat) -> float:
	var result: float = 1.0
	for entry: Array in _active.values():
		var buff: BuffDefinition = entry[0]
		if buff.stat == stat:
			result *= buff.multiplier
	return result


## Danh sách mô tả "Ấm bụng: hồi stamina ×1.5 (1:45)" cho HUD.
func describe() -> Array[String]:
	var lines: Array[String] = []
	for entry: Array in _active.values():
		var left: int = ceili(entry[1])
		lines.append("%s (%d:%02d)" % [(entry[0] as BuffDefinition).describe(), left / 60, left % 60])
	return lines
