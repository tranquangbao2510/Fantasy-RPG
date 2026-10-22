extends SceneTree
## Sinh ảnh nền màn hình tiêu đề (TASK M6): chụp một khung cảnh Glade lúc chiều muộn, ẩn UI, lưu
## res://app/art/title_background.jpg (placeholder — không phải art thật). Màn hình tiêu đề trôi chậm ảnh này.
## Chạy CÓ CỬA SỔ (cần render) từ thư mục gốc project, rồi import lại (--import) để Godot tạo .import:
##   Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/title/render_title_background.gd --resolution 1920x1080
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . --import

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const OUTPUT_PATH: String = "res://app/art/title_background.jpg"
## Tâm khung hình (toạ độ lưới iso — quảng trường tàn tích; thử chỗ khác: biến môi trường VX, VY) và mức zoom camera.
const VIEW_CENTER: Vector2 = Vector2(12.0, 12.0)
const ZOOM: float = 1.0
## 16:30 — nắng chiều.
const VIEW_MINUTE: int = 16 * 60 + 30


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for i: int in 10:
		await process_frame
	(scene.get(&"clock") as GameClock).running = false
	(scene.get(&"clock") as GameClock).set_time(1, VIEW_MINUTE)
	(scene.get(&"enemy_spawner") as EnemySpawner).enabled = false
	var ui: CanvasLayer = scene.get_node(^"UILayer") as CanvasLayer
	ui.visible = false
	var player: Player = scene.get(&"player") as Player
	var center: Vector2 = VIEW_CENTER
	if OS.has_environment("VX"):
		center = Vector2(OS.get_environment("VX").to_float(), OS.get_environment("VY").to_float())
	player.global_position = IsoProjection.to_screen(center.x, center.y)
	# Bỏ vật placeholder (pickup chữ cái, bù nhìn, bảng, quái thử) khỏi ảnh.
	for path: NodePath in [^"EntityContainer/Items", ^"EntityContainer/TrainingDummy", ^"EntityContainer/NoticeBoard", ^"EntityContainer/SimpleEnemy"]:
		var node: CanvasItem = scene.get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = false
	player.visible = false
	var camera: GameCamera = scene.get(&"camera") as GameCamera
	camera.zoom = Vector2(ZOOM, ZOOM)
	camera.reset_smoothing()
	for i: int in 30:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_jpg(ProjectSettings.globalize_path(OUTPUT_PATH), 0.88)
	print("Đã lưu %s (%dx%d): %s" % [OUTPUT_PATH, image.get_width(), image.get_height(), error_string(err)])
	quit()
