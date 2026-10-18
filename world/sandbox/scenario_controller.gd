class_name ScenarioController
extends Node
## Điều phối các CombatScenario con trong Combat Sandbox (node cục bộ của scene, không phải manager toàn cục).
## start_scenario(): xóa thực thể của tình huống cũ, reset thử nghiệm World (Player, dummy, đạn đang bay),
## đặt spawn Player, sinh thực thể mới vào spawn_parent và báo World qua entity_spawned để nối HUD/feedback.
## Không đụng tới progression (level, mastery, class, kỹ năng).

signal scenario_started(index: int)
signal entity_spawned(entity: Node)

@export var world: World
@export var player: Player
## Container nhận thực thể sinh ra (EntityContainer, để Y-sort cùng Player).
@export var spawn_parent: Node2D
@export var start_index: int = 0

var _spawned: Array[Node] = []
var _current: int = -1


func get_scenarios() -> Array[CombatScenario]:
	var scenarios: Array[CombatScenario] = []
	for child: Node in get_children():
		if child is CombatScenario:
			scenarios.append(child as CombatScenario)
	return scenarios


func get_current_index() -> int:
	return _current


func get_current_scenario() -> CombatScenario:
	var scenarios: Array[CombatScenario] = get_scenarios()
	return scenarios[_current] if _current >= 0 and _current < scenarios.size() else null


func start_scenario(index: int) -> bool:
	var scenarios: Array[CombatScenario] = get_scenarios()
	if index < 0 or index >= scenarios.size():
		return false
	var scenario: CombatScenario = scenarios[index]
	_clear_spawned()
	_current = index
	player.set_spawn_position(scenario.global_position)
	world.reset_test_state()
	for spawn: ScenarioSpawn in scenario.get_spawns():
		_spawn(spawn)
	if scenario.player_health_ratio < 1.0:
		var health: HealthComponent = player.get_health()
		health.apply_damage(health.current_health - maxi(1, roundi(health.max_health * scenario.player_health_ratio)))
	scenario_started.emit(index)
	return true


## Bắt đầu lại tình huống hiện tại (sinh lại thực thể).
func restart() -> bool:
	return start_scenario(_current)


## Reset các enemy của tình huống hiện tại về vị trí sinh, HP đầy (không sinh lại).
func reset_enemies() -> void:
	for entity: Node in _spawned:
		if is_instance_valid(entity) and entity.has_method(&"reset_state"):
			entity.call(&"reset_state")


## Số enemy của tình huống hiện tại còn sống.
func get_active_enemy_count() -> int:
	var count: int = 0
	for entity: Node in _spawned:
		var enemy: Enemy = entity as Enemy
		if is_instance_valid(enemy) and not enemy.is_dead():
			count += 1
	return count


func get_spawned_count() -> int:
	return _spawned.size()


func _spawn(spawn: ScenarioSpawn) -> void:
	if spawn.scene == null:
		return
	var entity: Node2D = spawn.scene.instantiate() as Node2D
	if entity == null:
		return
	# Đặt vị trí trước add_child để _ready() ghi nhận đúng điểm spawn (reset_state quay về đây).
	entity.position = spawn_parent.to_local(spawn.global_position)
	var enemy: Enemy = entity as Enemy
	if enemy != null:
		enemy.target = player
	spawn_parent.add_child(entity)
	_spawned.append(entity)
	entity_spawned.emit(entity)


func _clear_spawned() -> void:
	for entity: Node in _spawned:
		if is_instance_valid(entity):
			entity.get_parent().remove_child(entity)
			entity.queue_free()
	_spawned.clear()
