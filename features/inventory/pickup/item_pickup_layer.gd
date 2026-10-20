class_name ItemPickupLayer
extends Node2D
## Node cha của mọi ItemPickup trong một map (đặt trong cây Y-sort của EntityContainer). Mỗi map lưu được có một layer.
## - Nhặt: mỗi physics tick, pickup cùng tầng trong `magnet_radius` (đo trên mặt đất, `ground_squash`) bị hút về
##   `collector` và được nhặt khi tới `collect_radius`. Túi không đủ chỗ: nhặt phần vừa, phần còn lại nằm lại;
##   hoàn toàn không còn chỗ thì không hút và phát `pickup_blocked` (giãn cách `blocked_message_cooldown`).
## - Vứt: spawn_drop() tạo pickup tại chỗ (chưa "armed" tới khi người nhặt ra khỏi vùng hút).
## - Save (group `saveable`, theo map): `collected` = pickup_id của pickup đặt sẵn đã nhặt; `dropped` = pickup vứt ra
##   còn trên đất (item, số lượng, vị trí, tầng); `death_bags` = túi đồ rơi khi chết (TASK M2: id, vị trí, tầng, nội dung);
##   `deployed` = vật người chơi dựng (lều: item_id, id, vị trí, tầng).
## collector: node có get_inventory() -> Inventory (Player); tùy chọn is_dead().

signal item_picked(item_id: StringName, amount: int)
signal pickup_blocked(item_id: StringName)
## Vật dựng mới được thêm (đặt từ item hoặc khôi phục từ save) — World nối signal của lều.
signal deployed_added(node: Node2D)

const PICKUP_SCENE: PackedScene = preload("res://features/inventory/pickup/item_pickup.tscn")
const DEATH_BAG_SCENE: PackedScene = preload("res://features/survival/death/death_bag.tscn")
const STATE_VERSION: int = 2

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
	var bags: Array = []
	for bag: DeathBag in get_death_bags():
		bags.append({"id": bag.bag_id, "position": _vec_to_array(bag.global_position), "tier": bag.get_tier(),
			"inventory": bag.get_inventory().to_dict()})
	var deployed: Array = []
	for node: Node in get_deployed():
		var body: Node2D = node as Node2D
		var agent: ElevationAgent = ElevationAgent.find_for(body)
		deployed.append({"item_id": String(body.get(&"item_id")), "id": str(body.call(&"get_deploy_id")),
			"position": _vec_to_array(body.global_position), "tier": agent.get_tier() if agent != null else -1})
	return {"version": STATE_VERSION, "collected": _collected.duplicate(), "dropped": dropped, "death_bags": bags, "deployed": deployed}


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
	for bag: DeathBag in get_death_bags():
		remove_child(bag)
		bag.queue_free()
	for node: Node in get_deployed():
		remove_child(node)
		node.queue_free()
	var no_stacks: Array[ItemStack] = []
	var bags: Variant = state.get("death_bags", [])
	for entry: Variant in (bags if bags is Array else []):
		var data: Dictionary = entry if entry is Dictionary else {}
		var at: Variant = _array_to_vec(data.get("position"))
		if at == null:
			push_warning("[ItemPickupLayer] Bỏ qua túi đồ lỗi trong save: %s" % [entry])
			continue
		var bag: DeathBag = spawn_death_bag(no_stacks, at, _int_or(data.get("tier"), -1), str(data.get("id", "")))
		bag.get_inventory().load_dict(data.get("inventory", {}))
	var deployed: Variant = state.get("deployed", [])
	for entry: Variant in (deployed if deployed is Array else []):
		var data: Dictionary = entry if entry is Dictionary else {}
		var item: ItemDefinition = database.get_item(StringName(str(data.get("item_id", "")))) if database != null else null
		var at: Variant = _array_to_vec(data.get("position"))
		if item == null or item.deploy_scene == null or at == null:
			push_warning("[ItemPickupLayer] Bỏ qua vật đã dựng lỗi trong save: %s" % [entry])
			continue
		spawn_deployed(item, at, _int_or(data.get("tier"), -1), str(data.get("id", "")))


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


# --- Túi đồ khi chết, vật đã dựng (TASK M2) -------------------------------------------------------

func get_death_bags() -> Array[DeathBag]:
	var result: Array[DeathBag] = []
	for child: Node in get_children():
		var bag: DeathBag = child as DeathBag
		if bag != null and not bag.is_queued_for_deletion():
			result.append(bag)
	return result


## Vật người chơi dựng (node có get_deploy_id(), vd. Tent).
func get_deployed() -> Array[Node]:
	var result: Array[Node] = []
	for child: Node in get_children():
		if child.has_method(&"get_deploy_id") and not child.is_queued_for_deletion():
			result.append(child)
	return result


## Tạo túi đồ chứa `stacks` tại vị trí world trên tầng. bag_id rỗng → tự sinh.
func spawn_death_bag(stacks: Array[ItemStack], at: Vector2, tier: int = -1, bag_id: String = "") -> DeathBag:
	var bag: DeathBag = DEATH_BAG_SCENE.instantiate() as DeathBag
	bag.bag_id = bag_id if not bag_id.is_empty() else "bag_%d_%d" % [Time.get_unix_time_from_system(), get_child_count()]
	var agent: ElevationAgent = ElevationAgent.find_for(bag)
	if agent != null:
		agent.initial_tier = tier
	bag.position = to_local(at)
	add_child(bag)
	for stack: ItemStack in stacks:
		bag.get_inventory().add_stack(stack)
	return bag


## Đặt vật dựng từ item (deploy_scene) tại vị trí world trên tầng. deploy_id rỗng → node tự sinh.
func spawn_deployed(item: ItemDefinition, at: Vector2, tier: int = -1, deploy_id: String = "") -> Node2D:
	var node: Node2D = item.deploy_scene.instantiate() as Node2D
	if not deploy_id.is_empty():
		node.set(&"spot_id", deploy_id)
	if node.has_method(&"setup_from_item"):
		node.call(&"setup_from_item", item.id)
	var agent: ElevationAgent = ElevationAgent.find_for(node)
	if agent != null:
		agent.initial_tier = tier
	node.position = to_local(at)
	add_child(node)
	deployed_added.emit(node)
	return node


func _vec_to_array(v: Vector2) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]


## Vector2 từ [x, y] trong save; null nếu sai định dạng.
func _array_to_vec(value: Variant) -> Variant:
	if value is Array and (value as Array).size() == 2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float):
		return Vector2(float(value[0]), float(value[1]))
	return null


func _int_or(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback
