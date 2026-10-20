class_name DeathBag
extends Interactable
## Túi đồ rơi khi Player chết (TASK M2): chứa toàn bộ túi đồ lúc chết (không gồm đồ đang mặc). E để nhặt lại: mọi
## món vào túi người chơi, phần không vừa rơi xuống đất cạnh đó (ItemPickupLayer.spawn_drop). Chết nhiều lần thì có
## nhiều túi. Nằm trong ItemPickupLayer (lưu ở mục `death_bags`). Group `death_bags` (HUD vẽ mũi tên chỉ hướng).

const GROUP: StringName = &"death_bags"

signal collected(bag: DeathBag, taken: int, dropped: int)

var bag_id: String = ""

@onready var _inventory: Inventory = $Inventory


func _ready() -> void:
	add_to_group(GROUP)


func get_inventory() -> Inventory:
	return _inventory


func get_interaction_prompt() -> String:
	return "Nhặt lại túi"


func get_tier() -> int:
	var agent: ElevationAgent = ElevationAgent.find_for(self)
	return agent.get_tier() if agent != null else -1


func item_count() -> int:
	var total: int = 0
	for i: int in _inventory.get_size():
		var stack: ItemStack = _inventory.get_stack(i)
		if stack != null:
			total += stack.count
	return total


func _perform_interaction(actor: Node2D) -> String:
	var target: Inventory = actor.call(&"get_inventory") as Inventory if actor.has_method(&"get_inventory") else null
	if target == null:
		return ""
	var layer: ItemPickupLayer = get_parent() as ItemPickupLayer
	var taken: int = 0
	var dropped: int = 0
	for i: int in _inventory.get_size():
		var stack: ItemStack = _inventory.get_stack(i)
		if stack == null:
			continue
		var left: int = target.add_stack(stack)
		taken += stack.count - left
		if left > 0:
			dropped += left
			if layer != null:
				var offset: Vector2 = Vector2(randf_range(-10.0, 10.0), randf_range(-4.0, 6.0))
				layer.spawn_drop(ItemStack.new(stack.item_id, left, stack.data), global_position + offset, get_tier())
	_inventory.clear()
	collected.emit(self, taken, dropped)
	queue_free()
	if dropped > 0:
		return "Đã nhặt lại túi: %d món vào túi, %d món rơi xuống đất (túi đầy)." % [taken, dropped]
	return "Đã nhặt lại túi đồ (%d món)." % taken
