class_name ResourceNode
extends Interactable
## Node tài nguyên đặt trong map (TASK M3): cây, đá, bụi mọng, bụi cỏ — loại do `definition` quyết định.
## E (InteractionDetector) = một lần khai thác bằng công cụ đang cầm ở tay chính (EquipmentSlots.get_tool()).
## Đồ thu được vào THẲNG túi người chơi (phần không vừa rơi xuống đất cạnh node) — chọn vì vòng lặp khai thác lặp lại
## nhiều lần: không phải nhặt thêm từng món, không lạc đồ trong bóng tối, không thêm vật phẩm rơi vào save.
## Con của ResourceNodeLayer (đếm ngày mọc lại + lưu trạng thái). Cấu trúc scene:
## - `Available` (Node2D): hình khi còn tài nguyên (cây, quả mọng...) — có thể chứa thân va chạm (tắt khi bị phá);
## - `Depleted` (Node2D, tùy chọn): hình khi đã bị phá (gốc cây, đá vụn).

## Một lần khai thác / nhặt xong — `stacks` là đồ đã nhận.
signal harvested(node: ResourceNode, stacks: Array[ItemStack])

## Sức khai thác của tay không.
const HAND_POWER: int = 1
const GROUP: StringName = &"resource_nodes"

@export var definition: ResourceNodeDefinition
## ID ổn định trong map (lưu trạng thái).
@export var node_id: String = ""

## Sức khai thác còn thiếu cho lần thu hoạch hiện tại.
var progress_left: int = 0
var depleted: bool = false
## Ngày game mọc lại / hồi lượt nhặt tay (0 = không chờ).
var regrow_day: int = 0
## Số lần còn nhặt được bằng tay trong chu kỳ này.
var hand_left: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _actor: Node2D

@onready var _available: Node2D = get_node_or_null(^"Available") as Node2D
@onready var _depleted: Node2D = get_node_or_null(^"Depleted") as Node2D


func _ready() -> void:
	add_to_group(GROUP)
	rng.randomize()
	if definition != null:
		interaction_name = definition.display_name
	reset_full()


## Về trạng thái đầy (mới mọc / chưa từng khai thác).
func reset_full() -> void:
	depleted = false
	regrow_day = 0
	progress_left = definition.toughness if definition != null else 1
	hand_left = definition.hand_uses if definition != null else 0
	_apply_visual()


func can_interact(actor: Node2D) -> bool:
	_actor = actor
	return interaction_enabled and definition != null and not depleted


## Lời nhắc theo công cụ người chơi đang cầm: "Chặt (Độ bền 38/40)", "Nhặt cành · Cần rìu", "Cần rìu".
func get_interaction_prompt() -> String:
	if definition == null:
		return interaction_prompt
	if not definition.needs_tool():
		return definition.harvest_verb
	var equipment: EquipmentSlots = _equipment_of(_actor)
	var tool: ItemDefinition = equipment.get_tool() if equipment != null else null
	if tool != null and tool.tool_type == definition.required_tool:
		return "%s (%s)" % [definition.harvest_verb, tool.describe_wear(equipment.get_stack(&"weapon"))]
	if definition.can_hand_gather() and hand_left > 0:
		return "%s · %s" % [definition.hand_verb, definition.missing_tool_text]
	return definition.missing_tool_text


## Lý do không khai thác được lúc này ("" nếu được) — vd. "Cần rìu".
func get_block_reason(actor: Node2D) -> String:
	if definition == null or depleted:
		return "Không còn gì để lấy."
	if not definition.needs_tool() or _has_required_tool(actor):
		return ""
	if definition.can_hand_gather() and hand_left > 0:
		return ""
	return definition.missing_tool_text


## Mức hoàn thành lần thu hoạch hiện tại (0..1).
func get_progress() -> float:
	if definition == null:
		return 0.0
	return 1.0 - float(progress_left) / definition.toughness


## Trạng thái lưu (rỗng = đầy, không cần lưu).
func save_node_state() -> Dictionary:
	if not depleted and regrow_day == 0 and progress_left == definition.toughness and hand_left == definition.hand_uses:
		return {}
	return {"depleted": depleted, "regrow_day": regrow_day, "progress_left": progress_left, "hand_left": hand_left}


func load_node_state(state: Dictionary) -> void:
	reset_full()
	if state.is_empty() or definition == null:
		return
	depleted = state.get("depleted", false) == true
	regrow_day = _int_or(state.get("regrow_day"), 0)
	progress_left = clampi(_int_or(state.get("progress_left"), definition.toughness), 1, definition.toughness)
	hand_left = clampi(_int_or(state.get("hand_left"), definition.hand_uses), 0, definition.hand_uses)
	_apply_visual()


## Ngày `day` bắt đầu: tới ngày mọc lại thì đầy lại. Trả về true nếu vừa mọc lại.
func check_regrow(day: int) -> bool:
	if regrow_day > 0 and day >= regrow_day:
		reset_full()
		return true
	return false


func _perform_interaction(actor: Node2D) -> String:
	var reason: String = get_block_reason(actor)
	if not reason.is_empty():
		return reason
	if definition.needs_tool() and not _has_required_tool(actor):
		return _hand_gather(actor)
	var equipment: EquipmentSlots = _equipment_of(actor)
	var tool: ItemDefinition = equipment.get_tool() if definition.needs_tool() else null
	var power: int = tool.harvest_power if tool != null else HAND_POWER
	var broke_text: String = ""
	if tool != null and equipment.wear(&"weapon"):
		broke_text = " · %s đã vỡ!" % tool.display_name
	progress_left -= power
	if progress_left > 0:
		return "%s %s (%d%%)%s" % [definition.harvest_verb, definition.display_name, roundi(get_progress() * 100.0), broke_text]
	var stacks: Array[ItemStack] = definition.yield_table.roll(rng)
	var text: String = _give(actor, stacks)
	depleted = true
	regrow_day = _today() + definition.regrow_days
	_apply_visual()
	harvested.emit(self, stacks)
	return "%s: %s%s" % [definition.display_name, text, broke_text]


func _hand_gather(actor: Node2D) -> String:
	hand_left -= 1
	var stacks: Array[ItemStack] = definition.hand_table.roll(rng)
	var text: String = _give(actor, stacks)
	if regrow_day <= 0:
		regrow_day = _today() + definition.regrow_days
	harvested.emit(self, stacks)
	var rest: String = "" if hand_left > 0 else " · %s để lấy thêm" % definition.missing_tool_text
	return "%s: %s%s" % [definition.hand_verb, text, rest]


## Cho đồ vào túi actor; phần không vừa rơi xuống đất cạnh node. Trả về mô tả "+3 Gỗ, +1 Cành cây".
func _give(actor: Node2D, stacks: Array[ItemStack]) -> String:
	var inventory: Inventory = actor.call(&"get_inventory") as Inventory if actor != null and actor.has_method(&"get_inventory") else null
	var layer: ItemPickupLayer = _pickup_layer()
	var parts: Array[String] = []
	var spilled: bool = false
	for stack: ItemStack in stacks:
		var left: int = inventory.add_stack(stack) if inventory != null else stack.count
		if left > 0 and layer != null:
			var offset: Vector2 = Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(4.0, 8.0))
			layer.spawn_drop(ItemStack.new(stack.item_id, left, stack.data), global_position + offset, _tier())
			spilled = true
		var item: ItemDefinition = inventory.database.get_item(stack.item_id) if inventory != null and inventory.database != null else null
		parts.append("+%d %s" % [stack.count, item.display_name if item != null else String(stack.item_id)])
	return ", ".join(parts) + (" (túi đầy — phần thừa rơi xuống đất)" if spilled else "")


func _apply_visual() -> void:
	if _available != null:
		_available.visible = not depleted
		# Thân va chạm (thân cây, tảng đá) chỉ chặn đường khi còn đứng đó.
		for shape: Node in _available.find_children("*", "CollisionShape2D", true, false) \
				+ _available.find_children("*", "CollisionPolygon2D", true, false):
			if shape.get_parent() is StaticBody2D:
				shape.set_deferred(&"disabled", depleted and definition != null and definition.depletes)
	if _depleted != null:
		_depleted.visible = depleted


func _has_required_tool(actor: Node2D) -> bool:
	var equipment: EquipmentSlots = _equipment_of(actor)
	var tool: ItemDefinition = equipment.get_tool() if equipment != null else null
	return tool != null and tool.tool_type == definition.required_tool


func _today() -> int:
	var layer: ResourceNodeLayer = get_parent() as ResourceNodeLayer
	return layer.get_day() if layer != null else 1


func _tier() -> int:
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	return agent.get_tier() if agent != null else 0


func _pickup_layer() -> ItemPickupLayer:
	var scene: Node = owner if owner != null else get_tree().current_scene
	for node: Node in get_tree().get_nodes_in_group(ItemPickupLayer.GROUP):
		if scene == null or scene.is_ancestor_of(node):
			return node as ItemPickupLayer
	return null


static func _equipment_of(actor: Node2D) -> EquipmentSlots:
	return actor.call(&"get_equipment") as EquipmentSlots if actor != null and actor.has_method(&"get_equipment") else null


static func _int_or(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback
