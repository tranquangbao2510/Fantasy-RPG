class_name LootDropper
extends Node
## Rơi đồ khi chủ thể chết (TASK M3, vd. enemy rơi thịt sống). Gắn làm con của thực thể có HealthComponent.
## Khi `health.died`: tung `table`, thả từng stack xuống đất cạnh chủ thể (cùng tầng) qua ItemPickupLayer của map
## (group ItemPickupLayer.GROUP, cùng scene). Map không có layer (Combat Sandbox không lưu) → không rơi gì.
## Reset thử nghiệm (R) hồi sinh enemy → chết lần sau lại rơi.

## Đã thả đồ (số stack).
signal dropped(stacks: Array[ItemStack])

@export var table: LootTable
@export var health: HealthComponent
## Bán kính rải đồ quanh chân (px màn hình).
@export var scatter: float = 10.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	if health != null:
		health.died.connect(drop_loot)


## Tung bảng và thả đồ. Trả về các stack đã thả.
func drop_loot() -> Array[ItemStack]:
	var body: Node2D = get_parent() as Node2D
	var layer: ItemPickupLayer = _find_layer()
	if table == null or body == null or layer == null:
		return []
	var agent: ElevationAgent = ElevationAgent.find_for(body)
	var tier: int = agent.get_tier() if agent != null else -1
	var stacks: Array[ItemStack] = table.roll(rng)
	for stack: ItemStack in stacks:
		var offset: Vector2 = Vector2(rng.randf_range(-scatter, scatter), rng.randf_range(-scatter * 0.5, scatter * 0.5))
		layer.spawn_drop(stack, body.global_position + offset, tier)
	if not stacks.is_empty():
		dropped.emit(stacks)
	return stacks


func _find_layer() -> ItemPickupLayer:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	for node: Node in get_tree().get_nodes_in_group(ItemPickupLayer.GROUP):
		if scene == null or scene.is_ancestor_of(node):
			return node as ItemPickupLayer
	return null
