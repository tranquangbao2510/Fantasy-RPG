class_name CombatScenario
extends Node2D
## Một tình huống thử nghiệm trong Combat Sandbox (không phải chế độ chơi chính thức).
## Vị trí của node này là điểm spawn của Player; các con ScenarioSpawn là thực thể được sinh ra khi bắt đầu.
## Thêm tình huống: thêm node CombatScenario dưới ScenarioController, đặt vị trí, thêm ScenarioSpawn con.

@export var display_name: String = ""
@export_multiline var description: String = ""
## Tỉ lệ HP của Player khi bắt đầu (1 = đầy). Dùng cho tình huống "bị hạ gục khi đang dùng kỹ năng".
@export_range(0.05, 1.0) var player_health_ratio: float = 1.0


func get_spawns() -> Array[ScenarioSpawn]:
	var spawns: Array[ScenarioSpawn] = []
	for child: Node in get_children():
		if child is ScenarioSpawn:
			spawns.append(child as ScenarioSpawn)
	return spawns
