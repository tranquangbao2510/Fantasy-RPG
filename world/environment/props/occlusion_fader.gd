class_name OcclusionFader
extends Area2D
## Làm mờ `target` (tán cây, mặt cầu) khi một thân cần thấy được (mặc định layer `player`) đứng SAU vật
## (y nhỏ hơn sorting anchor của vật) và không ở tầng cao hơn vật. Chỉ ảnh hưởng hiển thị.

@export var target: CanvasItem
@export var faded_alpha: float = 0.45
@export var fade_time: float = 0.18
## Tầng của vật bị làm mờ; thân ở tầng cao hơn không bị vật che nên không cần làm mờ.
@export var occluder_tier: int = 0
## false: thân cùng tầng với vật không bị che (vd. đứng trên mặt cầu) — chỉ thân ở tầng thấp hơn mới kích hoạt.
@export var fade_same_tier: bool = true

var _bodies: Array[Node2D] = []
var _faded: bool = false
var _tween: Tween


func _ready() -> void:
	collision_layer = 0
	monitorable = false
	body_entered.connect(func(body: Node2D) -> void: _bodies.append(body))
	body_exited.connect(func(body: Node2D) -> void: _bodies.erase(body))


func _physics_process(_delta: float) -> void:
	var occluding: bool = false
	var anchor_y: float = (get_parent() as Node2D).global_position.y if get_parent() is Node2D else global_position.y
	for body: Node2D in _bodies:
		if not is_instance_valid(body) or body.global_position.y >= anchor_y:
			continue
		var agent: ElevationAgent = ElevationAgent.find_for(body)
		var limit: int = occluder_tier if fade_same_tier else occluder_tier - 1
		if agent != null and agent.get_tier() > limit and not agent.is_transitioning():
			continue
		occluding = true
		break
	if occluding != _faded:
		_faded = occluding
		_fade_to(faded_alpha if occluding else 1.0)


func _fade_to(alpha: float) -> void:
	if target == null:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(target, ^"modulate:a", alpha, fade_time)
