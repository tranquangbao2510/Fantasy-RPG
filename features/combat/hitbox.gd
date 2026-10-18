class_name Hitbox
extends Area2D
## Vùng gây đòn. Chỉ hoạt động giữa activate() và deactivate().
## Mỗi lần activate là một đòn: mỗi mục tiêu chỉ bị trúng tối đa một lần.
## Phe mục tiêu do collision_mask quyết định (vd. chỉ dò enemy_hurtbox).

signal hit_landed(hurtbox: Hurtbox, applied: int)

var _info: DamageInfo
var _hit_keys: Array[Object] = []


func _ready() -> void:
	monitorable = false
	monitoring = false


func is_active() -> bool:
	return _info != null


func activate(info: DamageInfo) -> void:
	_info = info
	_hit_keys.clear()
	set_deferred(&"monitoring", true)


func deactivate() -> void:
	_info = null
	_hit_keys.clear()
	set_deferred(&"monitoring", false)


func _physics_process(_delta: float) -> void:
	# Dò bằng get_overlapping_areas() (cập nhật mỗi physics step) thay vì area_entered,
	# để cả mục tiêu đã đứng sẵn trong vùng lúc bật cũng bị trúng; _hit_keys chặn trúng lặp.
	if _info == null or not monitoring:
		return
	for area: Area2D in get_overlapping_areas():
		var hurtbox: Hurtbox = area as Hurtbox
		if hurtbox == null:
			continue
		var key: Object = hurtbox.get_damage_key()
		if _hit_keys.has(key):
			continue
		_hit_keys.append(key)
		var applied: int = hurtbox.receive_damage(_info)
		if applied > 0:
			hit_landed.emit(hurtbox, applied)
