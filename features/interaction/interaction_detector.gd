class_name InteractionDetector
extends Area2D
## Component gắn vào actor (Player). Theo dõi Interactable trong phạm vi qua signal Area2D,
## chọn mục tiêu gần nhất và gọi interact() khi có action `interact`.
## Luật ưu tiên theo đồ đang cầm (TASK M6.1): actor cầm công cụ ở tay chính (get_equipment().get_tool()) thì mục tiêu dùng
## công cụ đó (Interactable.uses_tool) thắng mục tiêu không dùng, dù xa hơn (vd. cầm bình tưới ở mép suối → múc nước chứ
## không cắt bụi cỏ sát bên). Không có mục tiêu nào khớp → gần nhất như cũ.
## Không chứa logic của từng loại đối tượng.

## Mục tiêu đổi (null = không có), hoặc prompt của mục tiêu có thể đã đổi sau khi tương tác.
signal target_changed(target: Interactable)
## Đã tương tác với target; message là kết quả do đối tượng trả về.
signal interacted(target: Interactable, message: String)

## Chênh lệch khoảng cách tối thiểu để đổi sang mục tiêu khác (tránh nhảy qua lại khi gần bằng nhau).
const SWITCH_MARGIN: float = 1.0

## Bán kính vùng phát hiện (world px). Phạm vi thực tế = bán kính này + bán kính vùng của Interactable.
@export var detection_radius: float = 48.0

var _candidates: Array[Interactable] = []
var _target: Interactable
var _enabled: bool = true

@onready var _actor: Node2D = get_parent() as Node2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var circle: CircleShape2D = _shape.shape as CircleShape2D
	if circle != null:
		circle.radius = detection_radius
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _physics_process(_delta: float) -> void:
	if _enabled:
		_update_target()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and try_interact():
		get_viewport().set_input_as_handled()


func get_target() -> Interactable:
	return _target if is_instance_valid(_target) else null


## Bật/tắt khả năng tương tác (vd. khi actor bị hạ gục). Tắt sẽ xóa mục tiêu hiện tại.
func set_enabled(value: bool) -> void:
	_enabled = value
	if not _enabled and _target != null:
		_target = null
		target_changed.emit(null)


func is_enabled() -> bool:
	return _enabled


## Tương tác với mục tiêu hiện tại. Trả về false nếu không có mục tiêu hợp lệ hoặc đang bị tắt.
func try_interact() -> bool:
	if not _enabled:
		return false
	_update_target()
	if _target == null:
		return false
	var target: Interactable = _target
	var message: String = target.interact(_actor)
	interacted.emit(target, message)
	target_changed.emit(get_target())
	return true


## tool_type của công cụ actor đang cầm ở tay chính (&"" nếu không cầm công cụ).
func get_tool_type() -> StringName:
	if _actor == null or not _actor.has_method(&"get_equipment"):
		return &""
	var equipment: EquipmentSlots = _actor.call(&"get_equipment") as EquipmentSlots
	var tool: ItemDefinition = equipment.get_tool() if equipment != null else null
	return tool.tool_type if tool != null else &""


func _on_area_entered(area: Area2D) -> void:
	var interactable: Interactable = area as Interactable
	if interactable != null and not _candidates.has(interactable):
		_candidates.append(interactable)


func _on_area_exited(area: Area2D) -> void:
	var interactable: Interactable = area as Interactable
	if interactable != null:
		_candidates.erase(interactable)


func _update_target() -> void:
	for i: int in range(_candidates.size() - 1, -1, -1):
		if not is_instance_valid(_candidates[i]):
			_candidates.remove_at(i)

	var origin: Vector2 = global_position
	var tool_type: StringName = get_tool_type()
	var best: Interactable = null
	var best_distance: float = INF
	var best_matches: bool = false
	for candidate: Interactable in _candidates:
		if not candidate.can_interact(_actor):
			continue
		var matches: bool = tool_type != &"" and candidate.uses_tool(tool_type)
		var distance: float = origin.distance_to(candidate.get_interaction_position())
		if (matches and not best_matches) or (matches == best_matches and distance < best_distance):
			best = candidate
			best_distance = distance
			best_matches = matches

	# Giữ mục tiêu hiện tại nếu nó vẫn hợp lệ, cùng mức ưu tiên và gần như bằng khoảng cách tốt nhất.
	if best != _target and is_instance_valid(_target) and _candidates.has(_target) and _target.can_interact(_actor) \
			and (tool_type != &"" and _target.uses_tool(tool_type)) == best_matches:
		if origin.distance_to(_target.get_interaction_position()) <= best_distance + SWITCH_MARGIN:
			best = _target

	if best != _target:
		_target = best
		target_changed.emit(_target)
