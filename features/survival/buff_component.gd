class_name BuffComponent
extends Node
## Buff tạm thời đang có trên nhân vật (TASK M2). Mỗi buff_id một bản; áp lại thì làm mới thời gian.
## Các buff cùng Stat nhân dồn. Thời gian đếm theo giây thực (physics).
## TASK M4: lưu vào save (buff_id + giây còn lại); khôi phục cần tra BuffDefinition theo id (ItemDatabase.find_buff).

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
	apply_for(buff, buff.duration)


## Áp buff với thời gian còn lại cho trước (khôi phục save). seconds ≤ 0 → bỏ qua.
func apply_for(buff: BuffDefinition, seconds: float) -> void:
	if buff == null or not buff.is_valid() or seconds <= 0.0:
		return
	_active[buff.buff_id] = [buff, minf(seconds, buff.duration)]
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


## Save: [{id, left}] (giây thực còn lại).
func to_list() -> Array:
	var result: Array = []
	for buff_id: StringName in _active:
		result.append({"id": String(buff_id), "left": snappedf(_active[buff_id][1], 0.01)})
	return result


## Khôi phục từ save: `lookup(buff_id) -> BuffDefinition` (null = buff không còn tồn tại → bỏ qua, cảnh báo).
func load_list(value: Variant, lookup: Callable) -> void:
	_active.clear()
	for entry: Variant in (value if value is Array else []):
		if not entry is Dictionary:
			continue
		var buff: BuffDefinition = lookup.call(StringName(str(entry.get("id", "")))) as BuffDefinition
		var left: Variant = entry.get("left")
		if buff == null:
			push_warning("[BuffComponent] Buff không tồn tại '%s' — bỏ qua." % entry.get("id", ""))
			continue
		if (left is int or left is float) and float(left) > 0.0:
			_active[buff.buff_id] = [buff, minf(float(left), buff.duration)]
	buffs_changed.emit()
