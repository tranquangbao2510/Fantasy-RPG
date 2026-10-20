class_name DeathController
extends Node
## Chết & hồi sinh của Player trong map có save (TASK M2). Map không có node này (Combat Sandbox) giữ hành vi cũ
## ("bị hạ gục", R để reset).
## Khi HP về 0: khóa điều khiển → màn hình mờ → TOÀN BỘ túi đồ (không gồm đồ đang mặc) rơi thành một DeathBag tại
## chỗ chết, cùng tầng → hồi sinh ở chỗ tỉnh dậy (SleepController: lều đã ngủ hoặc giường "nhà") với
## `respawn_health_ratio` HP → sáng lại. Chết tiếp khi chưa nhặt túi cũ: túi mới, túi cũ vẫn còn. Không mất tiền.
## Tối đa `max_death_bags` túi trên map (TASK M3): túi mới vượt giới hạn thì túi CŨ NHẤT (đặt sớm nhất) biến mất cùng đồ
## bên trong, phát `bag_discarded` (World báo cho người chơi).

signal player_respawned(bag: DeathBag)
## Túi cũ nhất bị bỏ vì vượt giới hạn.
signal bag_discarded(bag_id: String)

@export var player: Player
@export var sleep: SleepController
@export var pickup_layer: ItemPickupLayer
@export var settings: SleepSettings
@export var overlay: SleepOverlay
## Số túi đồ tối đa cùng lúc trên một map.
@export_range(1, 50) var max_death_bags: int = 5

var _busy: bool = false


func _ready() -> void:
	if settings == null:
		settings = SleepSettings.new()
	if player != null:
		player.get_health().died.connect(_on_player_died)


func is_busy() -> bool:
	return _busy


func _on_player_died() -> void:
	if _busy:
		return
	_busy = true
	var at: Vector2 = player.global_position
	var agent: ElevationAgent = ElevationAgent.find_for(player)
	var tier: int = agent.get_tier() if agent != null else -1
	player.set_control_locked(true)
	if overlay != null:
		await overlay.fade_out(settings.fade_time)
	var bag: DeathBag = _drop_bag(at, tier)
	if sleep != null:
		sleep.move_player_to_wake_spot(settings.respawn_health_ratio)
	else:
		player.respawn_at(at, tier, settings.respawn_health_ratio)
	if overlay != null:
		await overlay.show_title("Bạn đã gục ngã — tỉnh lại ở chỗ nghỉ", settings.title_time)
		await overlay.fade_in(settings.fade_time)
	player.set_control_locked(false)
	_busy = false
	player_respawned.emit(bag)


func _drop_bag(at: Vector2, tier: int) -> DeathBag:
	var inventory: Inventory = player.get_inventory()
	var stacks: Array[ItemStack] = []
	for i: int in inventory.get_size():
		var stack: ItemStack = inventory.get_stack(i)
		if stack != null:
			stacks.append(stack)
	if stacks.is_empty() or pickup_layer == null:
		return null
	inventory.clear()
	var bags: Array[DeathBag] = pickup_layer.get_death_bags()
	while bags.size() >= max_death_bags:
		var oldest: DeathBag = bags.pop_front()
		pickup_layer.remove_death_bag(oldest)
		bag_discarded.emit(oldest.bag_id)
	return pickup_layer.spawn_death_bag(stacks, at, tier)
