extends "res://tests/test_base.gd"
## Kiểm thử TASK M7 (art đợt 2 — đồ vật gameplay + icon chuyển từ Polygon2D sang PNG):
## 1. object_art.json: mọi asset trong phạm vi có đủ PNG cho mọi trạng thái, kích thước khớp JSON, lề trong suốt ≥ 4 texel,
##    import theo style guide mục 10 (mipmaps, fix_alpha_border).
## 2. Mọi item trong item_database có icon 128 × 128 (đủ nét ở ô túi đồ cửa sổ 1920 × 1080).
## 3. Mọi giai đoạn của mọi cây trồng (đọc CropBook) có ảnh.
## 4. Không còn Polygon2D trong Visual (và trong cả scene, trừ ngọn lửa trại vẽ bằng code) của các scene trong phạm vi.
## 5. Trên Glade, qua input thật (E, chuột trái, Esc): rương mở / đóng đổi ảnh; khai thác node (khoai dại, bụi mọng, cây,
##    đá) đổi ảnh full → depleted; cày / gieo / tưới đổi ảnh đất + tint ướt, lớn lên đổi ảnh giai đoạn; lưu / tải giữ
##    đúng ảnh; bù nhìn rung khi trúng đòn (bóng đứng yên); vật phẩm trên đất dùng icon thu nhỏ.
## 6. Tool sinh art không ghi đè art thật (chỉ ghi khi chưa có file, hoặc --force đúng tên).
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/art/test_object_art.gd

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const TEST_DIR: String = "user://test_saves_m7/"
const TOOL_ROOT: String = "user://test_object_art_tool/"
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")
const ArtTool: GDScript = preload("res://tools/object_art/generate_object_art.gd")

## Asset bắt buộc của đợt 2 → trạng thái (cây trồng kiểm riêng theo CropBook).
const REQUIRED: Dictionary = {
	"workbench": ["default"], "campfire": ["default"], "stone_mill": ["default"], "chest": ["closed", "open"],
	"bed": ["default"], "tent": ["default"], "notice_board": ["default"], "class_training_station": ["default"],
	"death_bag": ["default"], "training_dummy": ["default"], "tree_stump": ["default"], "rock_node": ["full", "depleted"],
	"berry_bush": ["full", "depleted"], "wild_potato": ["full", "depleted"], "soil_tilled": ["default"],
}
## Scene trong phạm vi → asset mà ObjectSprite của nó phải dùng.
const SCENES: Dictionary = {
	"res://features/crafting/stations/workbench.tscn": ["workbench"],
	"res://features/crafting/stations/campfire.tscn": ["campfire"],
	"res://features/crafting/stations/stone_mill.tscn": ["stone_mill"],
	"res://features/inventory/chest/chest.tscn": ["chest"],
	"res://features/interaction/examples/test_chest.tscn": ["chest"],
	"res://features/survival/rest/bed.tscn": ["bed"],
	"res://features/survival/rest/tent.tscn": ["tent"],
	"res://features/interaction/examples/notice_board.tscn": ["notice_board"],
	"res://features/classes/station/class_training_station.tscn": ["class_training_station"],
	"res://features/survival/death/death_bag.tscn": ["death_bag"],
	"res://entities/enemies/training_dummy/training_dummy.tscn": ["training_dummy"],
	"res://features/gathering/nodes/tree_node.tscn": ["tree_stump"],
	"res://features/gathering/nodes/rock_node.tscn": ["rock_node"],
	"res://features/gathering/nodes/berry_bush_node.tscn": ["berry_bush"],
	"res://features/gathering/nodes/wild_potato_node.tscn": ["wild_potato"],
	"res://features/inventory/pickup/item_pickup.tscn": [],
}

var _world: Node  # Không khai báo kiểu World: world.gd dùng tên Autoload (xem test_base.gd).
var _player: Player
var _saves: SaveServiceScript


func _run_tests() -> void:
	_saves = root.get_node("SaveService") as SaveServiceScript
	_saves.save_dir = TEST_DIR
	clear_dir(TEST_DIR)
	_test_catalog()
	_test_icons()
	_test_crop_stages()
	await _test_scenes()
	await _open_world()
	await _test_chest()
	await _test_resource_nodes()
	await _test_farming()
	await _test_save_load()
	await _test_dummy_shake()
	await _test_pickup_icon()
	_test_tool_no_overwrite()
	clear_dir(TEST_DIR)


# ---------------------------------------------------------------- 1–3. dữ liệu

func _test_catalog() -> void:
	var catalog: Dictionary = ObjectSprite.get_catalog()
	check("catalog_texel_scale", is_equal_approx(float(catalog.get("texel_scale", 0)), 0.5) and int(catalog.get("margin", 0)) >= 4)
	var assets: Dictionary = catalog.get("assets", {})
	var missing: Array[String] = []
	for asset: String in REQUIRED:
		var states: Dictionary = assets.get(asset, {}).get("states", {})
		for state: String in REQUIRED[asset]:
			if not states.has(state):
				missing.append("%s/%s" % [asset, state])
	check("catalog_has_required_states", missing.is_empty(), str(missing))
	var bad: Array[String] = []
	var count: int = 0
	for asset: String in assets:
		var info: Dictionary = assets[asset]
		var size: Vector2i = Vector2i(int(info["size"][0]), int(info["size"][1]))
		var anchor: Vector2i = Vector2i(int(info["anchor"][0]), int(info["anchor"][1]))
		if not Rect2i(Vector2i.ZERO, size).has_point(anchor):
			bad.append("%s: anchor %s ngoài ảnh" % [asset, anchor])
		for state: String in info["states"]:
			var path: String = str(info["dir"]).path_join(str(info["states"][state]))
			count += 1
			var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
			if image == null:
				bad.append("%s: không có file" % path)
				continue
			if image.get_size() != size:
				bad.append("%s: %s ≠ %s" % [path, image.get_size(), size])
			var used: Rect2i = image.get_used_rect()
			if not Rect2i(4, 4, size.x - 8, size.y - 8).encloses(used):
				bad.append("%s: lề trong suốt < 4 texel (%s)" % [path, used])
			var problem: String = _import_problem(path)
			if not problem.is_empty():
				bad.append(problem)
	check("catalog_png_size_margin_import", bad.is_empty() and count >= 31, "%d ảnh %s" % [count, bad])


func _test_icons() -> void:
	var database: ItemDatabase = load("res://features/items/data/item_database.tres") as ItemDatabase
	var bad: Array[String] = []
	for item: ItemDefinition in database.items:
		var path: String = "res://features/items/icons/%s.png" % item.id
		var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.get_size() != Vector2i(128, 128):
			bad.append("%s: %s" % [path, image.get_size() if image != null else "thiếu"])
		elif item.icon == null or item.icon.resource_path != path:
			bad.append("%s: item.icon = %s" % [item.id, item.icon.resource_path if item.icon != null else "null"])
		else:
			var problem: String = _import_problem(path)
			if not problem.is_empty():
				bad.append(problem)
	check("icons_all_items_128", bad.is_empty() and database.items.size() >= 37, "%d item %s" % [database.items.size(), bad])
	var listed: Array = ObjectSprite.get_catalog().get("icons", {}).get("items", [])
	check("icons_listed_in_json", listed.size() == database.items.size())
	# Ô túi đồ: icon chiếm (46 − 2 × 4) px viewport gốc 1152 × 648 → ở cửa sổ 1920 × 1080 là ~63 px màn hình.
	var on_screen: float = (ItemSlotView.SIZE.x - 8.0) * 1080.0 / 648.0
	var sample: Texture2D = (database.get_item(&"wood") as ItemDefinition).icon
	check("icon_sharp_in_slot_1080p", sample.get_width() >= on_screen and sample.get_image().has_mipmaps(),
		"icon %d px ≥ ô %.1f px màn hình, mipmaps %s" % [sample.get_width(), on_screen, sample.get_image().has_mipmaps()])


func _test_crop_stages() -> void:
	var book: CropBook = load("res://features/farming/data/crop_book.tres") as CropBook
	var bad: Array[String] = []
	for crop: CropDefinition in book.crops:
		var info: Dictionary = ObjectSprite.get_asset_info(StringName("crop_%s" % crop.id))
		var states: Dictionary = info.get("states", {})
		if states.size() != crop.stages:
			bad.append("%s: %d ảnh / %d giai đoạn" % [crop.id, states.size(), crop.stages])
		var files: Array[String] = []
		for stage: int in crop.stages:
			var file: String = str(states.get("stage_%d" % stage, ""))
			if file.is_empty() or not FileAccess.file_exists(str(info.get("dir", "")).path_join(file)):
				bad.append("%s stage_%d" % [crop.id, stage])
			files.append(file)
		if files.size() != Array(files).filter(func(f: String) -> bool: return files.count(f) == 1).size():
			bad.append("%s: các giai đoạn trùng ảnh" % crop.id)
	check("crop_every_stage_has_image", bad.is_empty() and book.crops.size() >= 3, str(bad))


# ---------------------------------------------------------------- 4. scene

func _test_scenes() -> void:
	var holder: Node2D = Node2D.new()
	root.add_child(holder)
	var polygons: Array[String] = []
	var sprites: Array[String] = []
	for path: String in SCENES:
		var scene: Node = (load(path) as PackedScene).instantiate()
		if scene is Chest:
			(scene as Chest).chest_id = "m7_test"
		holder.add_child(scene)
		for poly: Node in scene.find_children("*", "Polygon2D", true, false):
			# Ngọn lửa trại giữ hiệu ứng code (ngoài Visual).
			if not (scene is Campfire and scene.get_node("Flame").is_ancestor_of(poly)):
				polygons.append("%s:%s" % [path.get_file(), scene.get_path_to(poly)])
		var used: Array[String] = []
		for node: Node in scene.find_children("*", "", true, false):
			var sprite: ObjectSprite = node as ObjectSprite
			if sprite != null:
				used.append(String(sprite.asset))
				if sprite.texture == null:
					sprites.append("%s: %s không có ảnh" % [path.get_file(), sprite.asset])
		for asset: String in SCENES[path]:
			if not used.has(asset):
				sprites.append("%s: thiếu ObjectSprite %s" % [path.get_file(), asset])
	check("no_polygon2d_in_visual", polygons.is_empty(), str(polygons))
	check("scenes_use_object_sprite", sprites.is_empty(), str(sprites))
	var flame: Node = holder.get_children().filter(func(n: Node) -> bool: return n is Campfire)[0].get_node("Flame")
	check("campfire_flame_still_code", flame.find_children("*", "Polygon2D", true, false).size() == 2 and flame.get_parent() is Campfire)
	var sprite: ObjectSprite = holder.find_child("Sprite", true, false) as ObjectSprite
	var info: Dictionary = ObjectSprite.get_asset_info(sprite.asset)
	check("sprite_offset_scale_from_json", sprite.offset == -Vector2(float(info["anchor"][0]), float(info["anchor"][1]))
		and sprite.scale == Vector2(0.5, 0.5) and not sprite.centered
		and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "%s %s %s" % [sprite.asset, sprite.offset, sprite.scale])
	expect_error("không có trạng thái 'missing'")
	sprite.set_state(&"missing")
	check("unknown_state_reports_error", sprite.texture != null)
	holder.queue_free()
	await frames(2)


# ---------------------------------------------------------------- 5. Glade, input thật

func _open_world() -> void:
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(4)
	_bind()
	_prepare()


func _bind() -> void:
	_world = current_scene
	_player = _world.player


func _prepare() -> void:
	var enemy: Node2D = _world.get_node_or_null("EntityContainer/SimpleEnemy") as Node2D
	if enemy != null:
		enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_world.enemy_spawner.enabled = false
	(_world.clock as GameClock).running = false
	for pickup: ItemPickup in (_world.pickup_layer as ItemPickupLayer).get_pickups():
		pickup.queue_free()


func _place_at(at: Vector2) -> void:
	_player.global_position = at
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(0)
	await frames(4)


func _hold(tool_id: StringName) -> void:
	_player.get_equipment().set_slot(&"weapon", ItemStack.new(tool_id, 1) if tool_id != &"" else null)


func _target() -> Interactable:
	return (_player.get_node("InteractionDetector") as InteractionDetector).get_target()


func _press_e() -> void:
	await tap_action(&"interact")
	await process_frame


func _node(node_id: String) -> ResourceNode:
	return (_world.resource_layer as ResourceNodeLayer).find_resource(node_id)


func _file(sprite: ObjectSprite) -> String:
	return sprite.get_texture_path().get_file() if sprite != null and sprite.visible else "(ẩn)"


## Ảnh đang hiện của một node tài nguyên (Sprite trực tiếp, hoặc Sprite trong Depleted đang hiện).
func _node_image(node: ResourceNode) -> String:
	var sprite: ObjectSprite = node.get_node_or_null("Sprite") as ObjectSprite
	if sprite == null:
		var depleted: Node2D = node.get_node_or_null("Depleted") as Node2D
		return _file(depleted.get_node("Sprite") as ObjectSprite) if depleted != null and depleted.visible else "(hình prop)"
	return _file(sprite)


func _test_chest() -> void:
	var chest: Chest = _world.get_node("EntityContainer/Chest") as Chest
	var sprite: ObjectSprite = chest.get_node("Visual/Sprite") as ObjectSprite
	check("chest_starts_closed", _file(sprite) == "chest_closed.png", _file(sprite))
	await _place_at(chest.global_position + Vector2(0, 14))
	await _press_e()
	await frames(2)
	check("chest_open_image_on_e", chest.is_open() and _file(sprite) == "chest_open.png", "%s %s" % [chest.is_open(), _file(sprite)])
	await tap_action(&"ui_cancel")
	await frames(2)
	check("chest_closed_image_on_esc", not chest.is_open() and _file(sprite) == "chest_closed.png", _file(sprite))


## Khai thác tới khi node hết (E nhiều lần), trả về số lần nhấn.
func _harvest(node: ResourceNode, tool_id: StringName) -> int:
	_hold(tool_id)
	await _place_at(node.global_position + Vector2(0, 16))
	var presses: int = 0
	while not node.depleted and presses < 10:
		if _target() != node:
			break
		await _press_e()
		presses += 1
	return presses


func _test_resource_nodes() -> void:
	for entry: Array in [["glade_wild_potato_1", &"", "wild_potato_full.png", "wild_potato_depleted.png"],
			["glade_berry_bush_1", &"", "berry_bush_full.png", "berry_bush_depleted.png"],
			["glade_rock_1", &"stone_pickaxe", "rock_node_full.png", "rock_node_depleted.png"],
			["glade_tree_1", &"stone_axe", "(hình prop)", "tree_stump.png"]]:
		var node: ResourceNode = _node(entry[0])
		var before: String = _node_image(node)
		var presses: int = await _harvest(node, entry[1])
		check("node_image_%s" % entry[0], before == entry[2] and node.depleted and _node_image(node) == entry[3],
			"%s → %s (E × %d, mục tiêu %s)" % [before, _node_image(node), presses, _target()])
	_hold(&"")
	var potato: ResourceNode = _node("glade_wild_potato_1")
	var shadow: CanvasItem = potato.get_node("Available") as CanvasItem
	check("wild_potato_shadow_hidden_when_dug", not shadow.visible)


func _test_farming() -> void:
	var field: FarmField = (_world.farm_layer as FarmLayer).find_field("glade_home")
	var plot: FarmPlot = field.get_plot(Vector2i(0, 0))
	var soil: ObjectSprite = field.get_soil_sprite(plot.cell)
	check("soil_hidden_on_grass", not plot.tilled and not soil.visible)
	_hold(&"stone_hoe")
	await _place_at(field.to_global(plot.position) + Vector2(0, 10))
	await _press_e()
	check("soil_image_when_tilled", plot.tilled and _file(soil) == "soil_tilled.png" and soil.modulate == Color.WHITE,
		"%s %s %s (mục tiêu %s)" % [plot.tilled, _file(soil), soil.modulate, _target()])
	_hold(&"")
	# Chỉ một loại hạt trong túi → E gieo luôn (không mở menu chọn hạt).
	var bag: Inventory = _player.get_inventory()
	for seed_id: StringName in [&"berry", &"seed_potato", &"wheat_seed"]:
		bag.remove(seed_id, bag.count_of(seed_id))
	bag.add(&"wheat_seed", 1)
	await frames(2)
	await _press_e()
	var crop: ObjectSprite = plot.get_crop_sprite()
	check("crop_stage0_image_on_plant", plot.has_crop() and _file(crop) == "crop_wheat_stage_0.png", "%s (mục tiêu %s, %s)" % [_file(crop), _target(), (_world.get_node("UILayer/InteractionFeedback/Label") as Label).text])
	_player.get_equipment().set_slot(&"weapon", ItemStack.new(&"watering_can", 1, {"water": 5}))
	await frames(2)
	await _press_e()
	check("soil_wet_tint_after_water", plot.is_wet() and soil.modulate == field.wet_soil_tint, str(soil.modulate))
	# Qua 6:00 hôm sau (đã tưới hôm trước) → lớn 1 giai đoạn → đổi ảnh; sang ngày mới đất khô lại.
	var clock: GameClock = _world.clock
	clock.advance(GameClock.MINUTES_PER_DAY - (clock.total_minutes - floorf(clock.total_minutes / GameClock.MINUTES_PER_DAY) * GameClock.MINUTES_PER_DAY) + 360.0 + 1.0)
	await frames(2)
	check("crop_image_changes_with_stage", plot.get_stage() == 1 and _file(crop) == "crop_wheat_stage_1.png", "%d %s" % [plot.get_stage(), _file(crop)])
	check("soil_dry_next_day", not plot.is_wet() and soil.modulate == Color.WHITE, str(soil.modulate))
	_hold(&"")
	var book: CropBook = (_world.farm_layer as FarmLayer).crop_book
	var wrong: Array[String] = []
	var other: FarmPlot = field.get_plot(Vector2i(1, 0))
	for kind: CropDefinition in book.crops:
		for stage: int in kind.stages:
			other.load_plot_state({"state": "planted", "crop": String(kind.id), "age": stage * kind.days_per_stage}, book)
			var expected: String = "crop_%s_stage_%d.png" % [kind.id, stage]
			if _file(other.get_crop_sprite()) != expected:
				wrong.append("%s ≠ %s" % [_file(other.get_crop_sprite()), expected])
	check("every_stage_shows_its_image", wrong.is_empty(), str(wrong))
	other.load_plot_state({"state": "planted", "crop": "potato", "age": 4}, book)
	field.get_plot(Vector2i(2, 0)).load_plot_state({"state": "tilled", "watered_day": clock.get_day()}, book)


func _test_save_load() -> void:
	var chest: Chest = _world.get_node("EntityContainer/Chest") as Chest
	chest.set_open(true)
	check("save_m7", _saves.save_game(1))
	var done: Array[int] = []
	_saves.loaded.connect(func(s: int) -> void: done.append(s), CONNECT_ONE_SHOT)
	_saves.load_game(1)
	for i: int in 60:
		if not done.is_empty():
			break
		await process_frame
	_bind()
	await frames(2)
	_prepare()
	var images: Array[String] = []
	for node_id: String in ["glade_wild_potato_1", "glade_berry_bush_1", "glade_rock_1", "glade_tree_1", "glade_rock_2"]:
		images.append(_node_image(_node(node_id)))
	check("load_keeps_node_images", images == ["wild_potato_depleted.png", "berry_bush_depleted.png", "rock_node_depleted.png",
		"tree_stump.png", "rock_node_full.png"], str(images))
	var field: FarmField = (_world.farm_layer as FarmLayer).find_field("glade_home")
	var crop_a: String = _file(field.get_plot(Vector2i(0, 0)).get_crop_sprite())
	var crop_b: String = _file(field.get_plot(Vector2i(1, 0)).get_crop_sprite())
	var soil_a: ObjectSprite = field.get_soil_sprite(Vector2i(0, 0))
	check("load_keeps_crop_and_soil_images", crop_a == "crop_wheat_stage_1.png" and crop_b == "crop_potato_stage_2.png"
		and soil_a.visible and soil_a.modulate == Color.WHITE and not field.get_soil_sprite(Vector2i(5, 3)).visible
		and field.get_soil_sprite(Vector2i(2, 0)).modulate == field.wet_soil_tint,
		"%s %s %s" % [crop_a, crop_b, soil_a.modulate])
	var sprite: ObjectSprite = _world.get_node("EntityContainer/Chest/Visual/Sprite") as ObjectSprite
	check("load_chest_closed", _file(sprite) == "chest_closed.png", _file(sprite))


func _test_dummy_shake() -> void:
	var dummy: Node2D = _world.get_node("EntityContainer/TrainingDummy") as Node2D
	var sprite: Node2D = dummy.get_node("Visual/Sprite") as Node2D
	var shadow: Node2D = dummy.get_node("Visual/Shadow") as Node2D
	var health: HealthComponent = dummy.get_node("HealthComponent") as HealthComponent
	_hold(&"test_sword")
	await _place_at(dummy.global_position + Vector2(-18, 4))
	var at: Vector2 = root.get_final_transform() * (_world.get_viewport().get_canvas_transform() * (dummy.global_position + Vector2(0, -4)))
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame
	var hp: int = health.current_health
	var moved: float = 0.0
	await press_action(&"basic_attack")
	for i: int in 40:
		await process_frame
		moved = maxf(moved, absf(sprite.position.x))
	await press_action(&"basic_attack", false)
	check("dummy_hit_by_real_attack", health.current_health < hp, "%d → %d" % [hp, health.current_health])
	check("dummy_shakes_on_hit", moved > 0.5 and shadow.position == Vector2.ZERO, "lệch tối đa %.2f px" % moved)
	await seconds(0.4)
	check("dummy_shake_settles", sprite.position == Vector2.ZERO and not dummy.call(&"is_shaking"), str(sprite.position))
	_hold(&"")


func _test_pickup_icon() -> void:
	var layer: ItemPickupLayer = _world.pickup_layer
	var pickup: ItemPickup = layer.spawn_drop(ItemStack.new(&"wood", 1), _player.global_position + Vector2(200, 0), 0)
	await frames(2)
	var icon: Sprite2D = pickup.get_node("Icon") as Sprite2D
	var size: float = icon.texture.get_width() * icon.scale.x
	check("pickup_icon_scaled_to_world_size", icon.texture.get_width() == 128 and is_equal_approx(size, pickup.icon_size)
		and pickup.get_node("Shadow") is ObjectShadow, "%.2f px" % size)


# ---------------------------------------------------------------- 6. tool không ghi đè art thật

func _test_tool_no_overwrite() -> void:
	var tool_root: String = ProjectSettings.globalize_path(TOOL_ROOT)
	clear_dir(TOOL_ROOT + "features/inventory/chest/art/")
	clear_dir(TOOL_ROOT + "features/items/icons/")
	var closed: String = tool_root.path_join("features/inventory/chest/art/chest_closed.png")
	var open: String = tool_root.path_join("features/inventory/chest/art/chest_open.png")
	var icon: String = tool_root.path_join("features/items/icons/wood.png")
	check("tool_first_run_writes", _run_tool(["--only", "chest,icon:wood"]) == 0 and FileAccess.file_exists(closed)
		and FileAccess.file_exists(open) and FileAccess.file_exists(icon))
	var generated: PackedByteArray = FileAccess.get_file_as_bytes(closed)
	# "Art thật": ghi đè bằng ảnh khác cùng kích thước.
	for path: String in [closed, icon]:
		var real: Image = Image.load_from_file(path)
		real.fill(Color(1, 0, 1))
		real.save_png(path)
	var real_closed: PackedByteArray = FileAccess.get_file_as_bytes(closed)
	var real_icon: PackedByteArray = FileAccess.get_file_as_bytes(icon)
	var open_before: PackedByteArray = FileAccess.get_file_as_bytes(open)
	check("tool_rerun_keeps_real_art", _run_tool(["--only", "chest,icon:wood"]) == 0
		and FileAccess.get_file_as_bytes(closed) == real_closed and FileAccess.get_file_as_bytes(icon) == real_icon
		and FileAccess.get_file_as_bytes(open) == open_before)
	check("tool_force_named_only", _run_tool(["--only", "chest,icon:wood", "--force", "chest_closed"]) == 0
		and FileAccess.get_file_as_bytes(closed) == generated and FileAccess.get_file_as_bytes(icon) == real_icon)
	check("tool_force_unknown_name_fails", _run_tool(["--only", "chest", "--force", "chest_lid"]) != 0)
	check("should_write_rule", not ArtTool.should_write(icon, "icon:wood", PackedStringArray())
		and ArtTool.should_write(icon, "icon:wood", PackedStringArray(["icon:wood"]))
		and not ArtTool.should_write(icon, "icon:wood", PackedStringArray(["wood"]))
		and ArtTool.should_write(tool_root.path_join("none.png"), "none", PackedStringArray()))
	clear_dir(TOOL_ROOT)


func _run_tool(args: Array[String]) -> int:
	OS.set_environment("OBJECT_ART_ROOT", TOOL_ROOT)
	var output: Array = []
	var full: PackedStringArray = PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/object_art/generate_object_art.gd", "--"])
	full.append_array(PackedStringArray(args))
	var code: int = OS.execute(OS.get_executable_path(), full, output, true)
	OS.unset_environment("OBJECT_ART_ROOT")
	return code


func _import_problem(path: String) -> String:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path + ".import") != OK:
		return "%s: thiếu .import" % path
	if config.get_value("params", "mipmaps/generate", false) != true or config.get_value("params", "process/fix_alpha_border", false) != true:
		return "%s: import sai (cần mipmaps/generate + fix_alpha_border)" % path
	return ""
