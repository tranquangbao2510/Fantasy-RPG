extends SceneTree
## Đo FPS CÓ RENDER (TASK M5) trên Glade: ngày / đêm (ruộng trống), đêm + 24 ô đầy cây, đêm + 24 ô đầy cây + 15 quái
## đang đuổi. Tắt vsync, đồng hồ đứng yên, Player bất tử. Mỗi mục: 60 frame làm nóng rồi đo 300 frame.
## Chạy CÓ CỬA SỔ (không --headless) từ thư mục gốc project:
##   Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/perf/measure_farm_fps.gd --resolution 1152x648

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const ENEMY_COUNT: int = 15


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i: int in 30:
		await process_frame
	var clock: GameClock = scene.get(&"clock") as GameClock
	var spawner: EnemySpawner = scene.get(&"enemy_spawner") as EnemySpawner
	var farms: FarmLayer = scene.get(&"farm_layer") as FarmLayer
	var player: Player = scene.get(&"player") as Player
	clock.running = false
	spawner.enabled = false
	(player.get_node(^"Hurtbox") as Hurtbox).set_invulnerable(99999.0)
	var watch_point: Vector2 = farms.get_plots()[14].global_position + Vector2(0, 40)
	player.global_position = watch_point
	(scene.get(&"camera") as GameCamera).set_target(player)
	clock.set_time(1, 12 * 60)
	await _measure("ngày (ruộng trống)")
	clock.set_time(1, 22 * 60)
	await _measure("đêm (ruộng trống)")
	var k: int = 0
	for plot: FarmPlot in farms.get_plots():
		var crop: CropDefinition = farms.crop_book.crops[k % farms.crop_book.crops.size()]
		plot.load_plot_state({"state": "planted", "crop": String(crop.id), "age": (k % crop.stages) * crop.days_per_stage,
			"watered_day": 1 if k % 2 == 0 else 0}, farms.crop_book)
		k += 1
	await _measure("đêm + 24 ô đầy cây")
	# Sinh quái ở bãi trống (cạnh nhà chật), rồi về ruộng cho quái đuổi tới.
	player.global_position = IsoProjection.to_screen(22.0, 35.0)
	var enemies: Array[Enemy] = []
	var ids: Array[StringName] = [&"shade", &"night_wolf", &"forest_ghoul"]
	var attempt: int = 0
	while enemies.size() < ENEMY_COUNT and attempt < 40:
		enemies.append_array(spawner.debug_spawn(ids[attempt % ids.size()]))
		attempt += 1
	while enemies.size() > ENEMY_COUNT:
		enemies.pop_back().queue_free()
	player.global_position = watch_point
	for i: int in 120:
		await process_frame
	await _measure("đêm + 24 ô đầy cây + %d quái đang đuổi" % enemies.size())
	quit()


func _measure(label: String) -> void:
	for i: int in 60:
		await process_frame
	var started: int = Time.get_ticks_usec()
	var frames_count: int = 300
	for i: int in frames_count:
		await process_frame
	print("FPS %s: %.0f" % [label, frames_count / ((Time.get_ticks_usec() - started) / 1000000.0)])
