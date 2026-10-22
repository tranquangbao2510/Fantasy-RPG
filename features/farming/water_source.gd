class_name WaterSource
extends Interactable
## Chỗ múc nước (TASK M5): điểm tương tác đặt ở mép một vùng nước có sẵn (suối trong Glade). E khi cầm bình tưới ở tay
## chính → đổ đầy bình (ItemStack.data["water"] = ItemDefinition.water_capacity). Không có hình riêng (nước đã vẽ sẵn).
## Tạo bằng cách thêm Area2D (layer 3 `interaction`, monitoring tắt) + CollisionShape2D nhỏ, script này.

var _actor: Node2D


func _init() -> void:
	interaction_name = "Nước suối"
	interaction_prompt = "Múc nước"


func get_interaction_prompt() -> String:
	var equipment: EquipmentSlots = _equipment_of(_actor)
	var tool: ItemDefinition = equipment.get_tool() if equipment != null else null
	if tool == null or tool.tool_type != FarmPlot.WATERING_CAN:
		return "Cần bình tưới để múc nước"
	return "Múc nước (%s)" % tool.describe_wear(equipment.get_stack(&"weapon"))


func can_interact(actor: Node2D) -> bool:
	_actor = actor
	return interaction_enabled


func uses_tool(tool_type: StringName) -> bool:
	return tool_type == FarmPlot.WATERING_CAN


func _perform_interaction(actor: Node2D) -> String:
	var equipment: EquipmentSlots = _equipment_of(actor)
	var tool: ItemDefinition = equipment.get_tool() if equipment != null else null
	if tool == null or tool.tool_type != FarmPlot.WATERING_CAN:
		return "Cần cầm bình tưới ở tay chính để múc nước."
	if tool.water_of(equipment.get_stack(&"weapon")) >= tool.water_capacity:
		return "Bình tưới đã đầy."
	equipment.set_stack_data(&"weapon", ItemDefinition.WATER_KEY, tool.water_capacity)
	return "Đã múc đầy %s (%d/%d)." % [tool.display_name.to_lower(), tool.water_capacity, tool.water_capacity]


static func _equipment_of(actor: Node2D) -> EquipmentSlots:
	return actor.call(&"get_equipment") as EquipmentSlots if actor != null and actor.has_method(&"get_equipment") else null
