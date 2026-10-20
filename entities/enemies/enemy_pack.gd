class_name EnemyPack
extends RefCounted
## Một bầy enemy (TASK M4, sói đêm): các thành viên vây quanh mục tiêu, mỗi lúc chỉ MỘT con được lao vào đánh
## ("lượt tấn công"). Con đang giữ lượt nhả lượt sau đòn đánh, khi chết / bỏ chạy / biến mất, hoặc sau `turn_timeout` giây.

## Giữ lượt quá lâu (kẹt sau vật cản...) thì tự nhả.
var turn_timeout: float = 4.0
var pack_id: int = 0

var _members: Array[Enemy] = []
var _attacker: Enemy
var _turn_started_ms: int = 0


func _init(p_pack_id: int = 0) -> void:
	pack_id = p_pack_id


func add_member(member: Enemy) -> void:
	if not _members.has(member):
		_members.append(member)


func remove_member(member: Enemy) -> void:
	_members.erase(member)
	release_turn(member)


func get_members() -> Array[Enemy]:
	_prune()
	return _members.duplicate()


## Vị trí của thành viên trong vòng vây (0..1) để các con tản đều quanh mục tiêu.
func get_slot(member: Enemy) -> float:
	_prune()
	var index: int = _members.find(member)
	return float(maxi(index, 0)) / maxi(_members.size(), 1)


## Xin lượt tấn công. true nếu thành viên này đang (hoặc vừa được) giữ lượt.
func request_turn(member: Enemy) -> bool:
	if _attacker == member:
		return true
	if _attacker != null and is_instance_valid(_attacker) and not _attacker.is_dead() and _members.has(_attacker) \
			and (Time.get_ticks_msec() - _turn_started_ms) < turn_timeout * 1000.0:
		return false
	_attacker = member
	_turn_started_ms = Time.get_ticks_msec()
	return true


func release_turn(member: Enemy) -> void:
	if _attacker == member:
		_attacker = null


func get_attacker() -> Enemy:
	return _attacker if _attacker != null and is_instance_valid(_attacker) else null


func _prune() -> void:
	for i: int in range(_members.size() - 1, -1, -1):
		if not is_instance_valid(_members[i]):
			_members.remove_at(i)
