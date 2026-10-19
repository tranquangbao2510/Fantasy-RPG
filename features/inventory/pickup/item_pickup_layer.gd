class_name ItemPickupLayer
extends Node2D
## Node cha của mọi ItemPickup trong một map (đặt trong cây Y-sort của EntityContainer). Mỗi map lưu được có một layer.
## - Nhặt: mỗi physics tick, pickup cùng tầng trong `magnet_radius` (đo trên mặt đất, `ground_squash`) bị hút về
##   `collector` và được nhặt khi tới `collect_radius`. Túi không đủ chỗ: nhặt phần vừa, phần còn lại nằm lại;
##   hoàn toàn không còn chỗ thì không hút và phát `pickup_blocked` (giãn cách `blocked_message_cooldown`).
## - Vứt: spawn_drop() tạo pickup tại chỗ (chưa "armed" tới khi người nhặt ra khỏi vùng hút).
## - Save (group `saveable`, theo map): `collected` = pickup_id của pickup đặt sẵn đã nhặt; `dropped` = pickup vứt ra
##   còn trên đất (item, số lượng, vị trí, tầng).
## collector: node có get_inventory() -> Inventory (Player); tùy chọn is_dead().

signal item_picked(item_id: StringName, amount: int)
signal pickup_blocked(item_id: StringName)

const PICKUP_SCENE: PackedScene = preload("res://features/inventory/pickup/item_pickup.tscn")
const STATE_VERSION: int = 1

@export var database: ItemDatabase
@export var collector: Node2D
@export var save_id: String = "world_items"
## Tỉ lệ dọc của mặt đất (1 = map cũ, 0.5 = isometric).
@export var ground_squash: float = 1.0
@export var magnet_radius: float = 36.0
@export var collect_radius: float = 8.0
@export var magnet_speed: float = 180.0
@export var blocked_message_cooldown: float = 2.0

var _collected: Array[String] = []
var _blocked_at: Dictionary[ItemPickup, float] = {}


func _ready() -> void:
	y_sort_enabled = true
	var ids: Array[String] = []
	for pickup: ItemPickup in get_pickups():
		if not pickup.is_placed():
			continue
		if ids.has(pickup.pickup_id):
			push_error("[ItemPickupLayer] pickup_id trùng '%s' (%s)." % [pickup.pickup_id, pickup.get_path()])
		ids.append(pickup.pickup_id)
		if database != null and not database.has_item(pickup.item_id):
			push_error("[ItemPickupLayer] Pickup '%s' có item không tồn tại: %s" % [pickup.pickup_id, pickup.item_id])


func _physics_process(delta: float) -> void:
	var inventory: Inventory = _get_inventory()
	if inventory == null or (collector.has_method(&"is_dead") and collector.call(&"is_dead")):
		return
	var agent: ElevationAgent = ElevationAgent.find_for(collector)
	var collector_tier: int = agent.get_tier() if agent != null and not agent.is_transitioning() else -1
	for pickup: ItemPickup in get_pickups():
		var offset: Vector2 = collector.global_position - pickup.global_position
		var distance: float = GroundSpace.length(offset, ground_squash)
		if not pickup.armed:
			pickup.armed = distance > magnet_radius
			continue
		if distance > magnet_radius:
			continue
		var tier: int = pickup.get_tier()
		if tier >= 0 and collector_tier >= 0 and tier != collector_tier:
			continue
		if inventory.space_for(pickup.item_id, pickup.data) <= 0:
			_notify_blocked(pickup)
			continue
		if distance > collect_radius:
			var step: float = minf(magnet_speed * delta, distance)
			pickup.global_position += GroundSpace.to_screen(GroundSpace.direction(offset, ground_squash) * step, ground_squash)
			continue
		collect(pickup, inventory)


func get_pickups() -> Array[ItemPickup]:
	var result: Array[ItemPickup] = []
	for child: Node in get_children():
		var pickup: ItemPickup = child as ItemPickup
		if pickup != null and not pickup.is_queued_for_deletion():
			result.append(pickup)
	return result


## Nhặt pickup vào túi ngay (bỏ qua khoảng cách). Trả về số đã nhặt.
func collect(pickup: ItemPickup, inventory: Inventory) -> int:
	var left: int = inventory.add(pickup.item_id, pickup.count, pickup.data)
	var taken: int = pickup.count - left
	if taken > 0:
		item_picked.emit(pickup.item_id, taken)
	if left <= 0:
		if pickup.is_placed() and not _collected.has(pickup.pickup_id):
			_collected.append(pickup.pickup_id)
		_blocked_at.erase(pickup)
		pickup.queue_free()
	else:
		pickup.count = left
		_notify_blocked(pickup)
	return taken


## Tạo pickup tại vị trí world `at` trên tầng `tier` (-1 = theo vị trí). Pickup chưa "armed".
func spawn_drop(stack: ItemStack, at: Vector2, tier: int = -1) -> ItemPickup:
	if stack == null or stack.is_empty() or (database != null and not database.has_item(stack.item_id)):
		return null
	var pickup: ItemPickup = PICKUP_SCENE.instantiate() as ItemPickup
	pickup.item_id = stack.item_id
	pickup.count = stack.count
	pickup.data = stack.data.duplicate(true)
	pickup.armed = false
	var agent: ElevationAgent = ElevationAgent.find_for(pickup)
	if agent != null:
		agent.initial_tier = tier
	pickup.position = to_local(at)
	add_child(pickup)
	return pickup


func is_collected(pickup_id: String) -> bool:
	return _collected.has(pickup_id)


# --- Save ----------------------------------------------------------------------------------------

func get_save_id() -> String:
	return save_id


func save_state() -> Dictionary:
	var dropped: Array = []
	for pickup: ItemPickup in get_pickups():
		if pickup.is_placed():
			continue
		var entry: Dictionary = pickup.get_item_stack().to_dict()
		entry["position"] = [snappedf(pickup.global_position.x, 0.01), snappedf(pickup.global_position.y, 0.01)]
		entry["tier"] = pickup.get_tier()
		dropped.append(entry)
	return {"version": STATE_VERSION, "collected": _collected.duplicate(), "dropped": dropped}


func load_state(state: Dictionary) -> void:
	_collected.clear()
	var collected: Variant = state.get("collected", [])
	for id: Variant in (collected if collected is Array else []):
		if not _collected.has(str(id)):
			_collected.append(str(id))
	for pickup: ItemPickup in get_pickups():
		if not pickup.is_placed() or _collected.has(pickup.pickup_id):
			remove_child(pickup)
			pickup.queue_free()
	_blocked_at.clear()
	var dropped: Variant = state.get("dropped", [])
	for entry: Variant in (dropped if dropped is Array else []):
		var stack: ItemStack = ItemStack.from_dict(entry)
		var at: Variant = (entry as Dictionary).get("position") if entry is Dictionary else null
		if stack == null or not at is Array or (at as Array).size() != 2:
			push_warning("[ItemPickupLayer] Bỏ qua vật phẩm rơi lỗi trong save: %s" % [entry])
			continue
		var tier: Variant = (entry as Dictionary).get("tier", -1)
		spawn_drop(stack, Vector2(float(at[0]), float(at[1])), int(tier) if (tier is int or tier is float) else -1)


func _get_inventory() -> Inventory:
	if collector == null or not is_instance_valid(collector) or not collector.has_method(&"get_inventory"):
		return null
	return collector.call(&"get_inventory") as Inventory


func _notify_blocked(pickup: ItemPickup) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _blocked_at.get(pickup, -INF) < blocked_message_cooldown:
		return
	_blocked_at[pickup] = now
	pickup_blocked.emit(pickup.item_id)
