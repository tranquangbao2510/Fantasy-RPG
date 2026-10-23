extends SceneTree
## Chụp ảnh so sánh trước / sau khi đổi đồ vật gameplay từ polygon sang sprite (TASK M7).
## Dựng một "phòng trưng bày" (mọi scene thuộc đợt 2, đủ trạng thái) + một góc Glade quanh nhà tạm, camera zoom 2×,
## dừng cây scene (đứng yên lửa / vật phẩm nảy) rồi chụp. Chỉ dùng API public có từ trước M7 → chạy được trên cả code cũ.
## Chạy CÓ CỬA SỔ từ thư mục gốc project (CAPTURE_TAG = before / after):
##   set CAPTURE_TAG=after
##   Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/object_art/capture_gallery.gd --resolution 1152x648
## So sánh: COMPARE=1 (headless được) → docs/reports/M7/diff_<shot>.png + số pixel lệch.

const OUT_DIR: String = "res://docs/reports/M7/"
const SHOTS: Array[String] = ["gallery_stations", "gallery_nodes", "glade_home"]
## Ngưỡng lệch một pixel (kênh màu lớn nhất, 0..1).
const DIFF_THRESHOLD: float = 0.1

const STATIONS: Array[Array] = [
	["res://features/crafting/stations/workbench.tscn", Vector2(45, 120)],
	["res://features/crafting/stations/campfire.tscn", Vector2(135, 120)],
	["res://features/crafting/stations/stone_mill.tscn", Vector2(225, 120)],
	["res://features/inventory/chest/chest.tscn", Vector2(315, 120)],
	["res://features/inventory/chest/chest.tscn", Vector2(405, 120), "open"],
	["res://features/survival/rest/bed.tscn", Vector2(495, 120)],
	["res://features/survival/rest/tent.tscn", Vector2(45, 260)],
	["res://features/interaction/examples/notice_board.tscn", Vector2(135, 260)],
	["res://features/classes/station/class_training_station.tscn", Vector2(225, 260)],
	["res://features/survival/death/death_bag.tscn", Vector2(315, 260)],
	["res://entities/enemies/training_dummy/training_dummy.tscn", Vector2(405, 260)],
	["res://features/interaction/examples/test_chest.tscn", Vector2(495, 260)],
]
const NODES: Array[Array] = [
	["res://features/gathering/nodes/rock_node.tscn", Vector2(1040, 100), false],
	["res://features/gathering/nodes/rock_node.tscn", Vector2(1110, 100), true],
	["res://features/gathering/nodes/berry_bush_node.tscn", Vector2(1190, 100), false],
	["res://features/gathering/nodes/berry_bush_node.tscn", Vector2(1280, 100), true],
	["res://features/gathering/nodes/wild_potato_node.tscn", Vector2(1350, 100), false],
	["res://features/gathering/nodes/wild_potato_node.tscn", Vector2(1410, 100), true],
	["res://features/gathering/nodes/tree_node.tscn", Vector2(1480, 100), true],
]
const PICKUPS: Array[StringName] = [&"wood", &"stone", &"berry", &"stone_axe", &"wheat", &"bread", &"torch", &"tent"]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if OS.get_environment("COMPARE") == "1":
		_compare()
		quit()
		return
	if OS.get_environment("CAPTURE_INVENTORY") == "1":
		await _inventory_shot()
		quit()
		return
	var tag: String = OS.get_environment("CAPTURE_TAG")
	if tag.is_empty():
		tag = "after"
	seed(7)
	var gallery: Node2D = Node2D.new()
	root.add_child(gallery)
	current_scene = gallery
	_build_gallery(gallery)
	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2(2, 2)
	gallery.add_child(camera)
	camera.make_current()
	await _frames(10)
	paused = true
	camera.position = Vector2(288, 162)
	await _frames(5)
	_save(tag, "gallery_stations")
	camera.position = Vector2(1288, 162)
	await _frames(5)
	_save(tag, "gallery_nodes")
	paused = false
	gallery.queue_free()
	await _frames(2)
	await _glade_shot(tag)
	quit()


## Dựng phòng trưng bày trong `gallery` (đã nằm trong cây scene → @onready của scene con chạy ngay khi thêm vào).
func _build_gallery(gallery: Node2D) -> void:
	gallery.name = "Gallery"
	gallery.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var ground: Polygon2D = Polygon2D.new()
	ground.color = Color(0.42, 0.55, 0.33)
	ground.polygon = PackedVector2Array([Vector2(-200, -200), Vector2(2000, -200), Vector2(2000, 600), Vector2(-200, 600)])
	ground.z_index = -10
	gallery.add_child(ground)
	var entities: Node2D = Node2D.new()
	entities.y_sort_enabled = true
	gallery.add_child(entities)
	for entry: Array in STATIONS:
		var node: Node2D = (load(entry[0]) as PackedScene).instantiate() as Node2D
		node.position = entry[1]
		if node is Chest:
			(node as Chest).chest_id = "gallery_%d" % entities.get_child_count()
		entities.add_child(node)
		if entry.size() > 2 and node is Chest:
			(node as Chest).set_open(true)
	for entry: Array in NODES:
		var resource: ResourceNode = (load(entry[0]) as PackedScene).instantiate() as ResourceNode
		resource.position = entry[1]
		entities.add_child(resource)
		if entry[2]:
			resource.load_node_state({"depleted": true})
	var book: CropBook = load("res://features/farming/data/crop_book.tres") as CropBook
	var layer: FarmLayer = FarmLayer.new()
	layer.crop_book = book
	layer.y_sort_enabled = true
	var field: FarmField = FarmField.new()
	field.field_id = "gallery"
	field.position = Vector2(1250, 150)
	layer.add_child(field)
	entities.add_child(layer)
	var plots: Array[FarmPlot] = []
	for r: int in field.rows:
		for c: int in field.columns:
			plots.append(field.get_plot(Vector2i(c, r)))
	var index: int = 0
	for crop: CropDefinition in book.crops:
		for stage: int in crop.stages:
			plots[index].load_plot_state({"state": "planted", "crop": String(crop.id), "age": stage * crop.days_per_stage,
				"watered_day": 1 if stage % 2 == 0 else 0}, book)
			index += 1
	plots[index].load_plot_state({"state": "tilled", "watered_day": 0}, book)
	plots[index + 1].load_plot_state({"state": "tilled", "watered_day": 1}, book)
	field.refresh_soil()
	var items: ItemPickupLayer = ItemPickupLayer.new()
	items.database = load("res://features/items/data/item_database.tres") as ItemDatabase
	items.y_sort_enabled = true
	entities.add_child(items)
	for k: int in PICKUPS.size():
		items.spawn_drop(ItemStack.new(PICKUPS[k], 1), Vector2(1460 + (k % 4) * 26, 230 + (k / 4) * 40))


func _glade_shot(tag: String) -> void:
	var scene: Node = (load("res://world/environment_prototype/environment_prototype.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(10)
	(scene.get(&"clock") as GameClock).running = false
	(scene.get(&"clock") as GameClock).set_time(1, 9 * 60)
	(scene.get(&"enemy_spawner") as EnemySpawner).enabled = false
	(scene.get_node(^"UILayer") as CanvasLayer).visible = false
	var field: FarmField = (scene.get(&"farm_layer") as FarmLayer).find_field("glade_home")
	var book: CropBook = load("res://features/farming/data/crop_book.tres") as CropBook
	var k: int = 0
	for plot: FarmPlot in field.get_plots():
		var crop: CropDefinition = book.crops[k % book.crops.size()]
		var stage: int = (k / book.crops.size()) % crop.stages
		if k % 7 == 6:
			plot.load_plot_state({"state": "tilled", "watered_day": k % 2}, book)
		else:
			plot.load_plot_state({"state": "planted", "crop": String(crop.id), "age": stage * crop.days_per_stage, "watered_day": k % 2}, book)
		k += 1
	field.refresh_soil()
	var player: Player = scene.get(&"player") as Player
	player.global_position = Vector2(-250, 1010)
	var camera: GameCamera = scene.get(&"camera") as GameCamera
	camera.zoom = Vector2(2, 2)
	camera.set_target(player)
	await _frames(20)
	paused = true
	await _frames(5)
	_save(tag, "glade_home")
	paused = false


## Túi đồ đầy icon 128 × 128 ở cửa sổ thật (chạy với --resolution 1920x1080: kiểm tra icon trong ô có nét không).
func _inventory_shot() -> void:
	var scene: Node = (load("res://world/environment_prototype/environment_prototype.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(10)
	(scene.get(&"enemy_spawner") as EnemySpawner).enabled = false
	var bag: Inventory = (scene.get(&"player") as Player).get_inventory()
	var database: ItemDatabase = bag.database
	var k: int = 0
	for item: ItemDefinition in database.items:
		if k < bag.get_size() and bag.get_stack(k) == null:
			bag.add_to_slot(k, ItemStack.new(item.id, 1))
		k += 1
	var window: InventoryWindow = scene.get(&"inventory_window") as InventoryWindow
	window.open()
	window.refresh_now()
	await _frames(10)
	_save("inventory", "1080p" if DisplayServer.window_get_size().x == 1920 else "window")


func _save(tag: String, shot: String) -> void:
	var image: Image = root.get_texture().get_image()
	var path: String = OUT_DIR + "%s_%s.png" % [tag, shot]
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	print("Đã lưu %s (%dx%d): %s" % [path, image.get_width(), image.get_height(), error_string(err)])


func _compare() -> void:
	for shot: String in SHOTS:
		var before: Image = Image.load_from_file(ProjectSettings.globalize_path(OUT_DIR + "before_%s.png" % shot))
		var after: Image = Image.load_from_file(ProjectSettings.globalize_path(OUT_DIR + "after_%s.png" % shot))
		if before == null or after == null or before.get_size() != after.get_size():
			print("COMPARE %s: thiếu ảnh hoặc khác kích thước" % shot)
			continue
		var diff: Image = Image.create(before.get_width(), before.get_height(), false, Image.FORMAT_RGB8)
		var over: int = 0
		var total: float = 0.0
		var worst: float = 0.0
		for y: int in before.get_height():
			for x: int in before.get_width():
				var a: Color = before.get_pixel(x, y)
				var b: Color = after.get_pixel(x, y)
				var d: float = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
				total += d
				worst = maxf(worst, d)
				var gray: float = (a.r + a.g + a.b) / 3.0 * 0.35
				if d > DIFF_THRESHOLD:
					over += 1
					diff.set_pixel(x, y, Color(1, 0, 0))
				else:
					diff.set_pixel(x, y, Color(gray, gray, gray).lerp(Color(1, 1, 0), clampf(d / DIFF_THRESHOLD, 0.0, 1.0)))
		diff.save_png(ProjectSettings.globalize_path(OUT_DIR + "diff_%s.png" % shot))
		var pixels: int = before.get_width() * before.get_height()
		print("COMPARE %s: %d / %d pixel lệch > %.2f (%.3f%%), lệch TB %.4f, lớn nhất %.3f" % [shot, over, pixels, DIFF_THRESHOLD,
			100.0 * over / pixels, total / pixels, worst])


func _frames(count: int) -> void:
	for i: int in count:
		await RenderingServer.frame_post_draw
