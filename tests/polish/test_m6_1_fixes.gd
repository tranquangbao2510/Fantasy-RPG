extends "res://tests/test_base.gd"
## Kiểm thử TASK M6.1 (sửa sau M6) trên Glade, qua input thật (E, I + rê chuột + F, giữ phím di chuyển) khi có thể:
## 1. Luật ưu tiên tương tác theo đồ đang cầm: bình tưới → chỗ múc nước (không cắt bụi cỏ sát bên), cuốc đất → ô ruộng,
##    rìu → cây; cầm công cụ không khớp hay tay không → gần nhất như cũ.
## 2. Dựng lều / lửa trại bị chặn nói rõ lý do: quá gần ruộng, có vật cản (có tên / không tên), sai tầng, đất không bằng.
## 3. Chỗ khó chịu M6: đi bộ thẳng từ ruộng tới chỗ múc nước không kẹt; tán cây mờ hẳn khi đứng sau; ô tích / công tắc
##    trong menu có viền rõ.
## (Tự lưu khi thoát / về màn hình chính: tests/app/test_app_shell.gd.)
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/polish/test_m6_1_fixes.gd

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const TEST_DIR: String = "user://test_saves_m6_1/"
const SaveServiceScript: GDScript = preload("res://save/save_service.gd")

var _world: Node  # Không khai báo kiểu World: world.gd dùng tên Autoload (xem test_base.gd).
var _player: Player
var _field: FarmField


func _run_tests() -> void:
	(root.get_node("SaveService") as SaveServiceScript).save_dir = TEST_DIR
	clear_dir(TEST_DIR)
	await _open_world()
	await _test_tool_priority()
	await _test_placement_reasons()
	await _test_walk_to_water()
	await _test_canopy_fade()
	await _test_check_icons()
	clear_dir(TEST_DIR)


# ---------------------------------------------------------------- tiện ích

func _open_world() -> void:
	var scene: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	_world = scene
	_player = _world.player
	_field = (_world.farm_layer as FarmLayer).find_field("glade_home")
	await frames(4)
	var enemy: Node2D = _world.get_node_or_null("EntityContainer/SimpleEnemy") as Node2D
	if enemy != null:
		enemy.global_position = IsoProjection.to_screen(4.0, 30.0)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_world.enemy_spawner.enabled = false
	(_world.clock as GameClock).running = false
	(_world.clock as GameClock).set_time(1, 10 * 60)
	for pickup: ItemPickup in (_world.pickup_layer as ItemPickupLayer).get_pickups():
		pickup.queue_free()


func _place_at(at: Vector2, tier: int = 0) -> void:
	_player.global_position = at
	_player.velocity = Vector2.ZERO
	ElevationAgent.find_for(_player).set_tier(tier)
	await frames(4)


func _hold(tool_id: StringName) -> void:
	_player.get_equipment().set_slot(&"weapon", ItemStack.new(tool_id, 1) if tool_id != &"" else null)


func _target() -> Interactable:
	return (_player.get_node("InteractionDetector") as InteractionDetector).get_target()


func _node(node_id: String) -> ResourceNode:
	for node: Node in get_nodes_in_group(ResourceNode.GROUP):
		if (node as ResourceNode).node_id == node_id:
			return node as ResourceNode
	return null


func _feedback() -> String:
	return (_world.get_node("UILayer/InteractionFeedback/Label") as Label).text


func _water_left() -> int:
	var equipment: EquipmentSlots = _player.get_equipment()
	var item: ItemDefinition = equipment.get_item(&"weapon")
	return item.water_of(equipment.get_stack(&"weapon")) if item != null else -1


func _find(bag: Inventory, item_id: StringName) -> int:
	for i: int in bag.get_size():
		var stack: ItemStack = bag.get_stack(i)
		if stack != null and stack.item_id == item_id:
			return i
	return -1


func _mouse_to(window_point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = window_point
	motion.global_position = window_point
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await process_frame


## I → rê chuột lên ô chứa item → F (dựng) → I. Trả về thông báo hiện ra.
func _deploy_via_bag(item_id: StringName) -> String:
	var bag: Inventory = _player.get_inventory()
	if not bag.has(item_id):
		bag.add(item_id, 1)
	var window: InventoryWindow = _world.inventory_window
	(_world.get_node("UILayer/InteractionFeedback/Label") as Label).text = ""
	await tap_action(&"inventory_toggle")
	window.refresh_now()
	await process_frame
	await _mouse_to(root.get_final_transform() * window.get_bag_view(_find(bag, item_id)).get_global_rect().get_center())
	await tap_action(&"item_use")
	await process_frame
	await tap_action(&"inventory_toggle")
	# Dựng được thì thu lại ngay (ca sau không bị "Đã có một lều").
	for node: Node in (_world.pickup_layer as ItemPickupLayer).get_deployed():
		node.queue_free()
	await process_frame
	return _feedback()


# ---------------------------------------------------------------- 1. ưu tiên theo đồ đang cầm

func _test_tool_priority() -> void:
	# Mép suối: đứng sát bụi cỏ hơn chỗ múc nước.
	var grass: ResourceNode = _node("glade_grass_2")
	var source: WaterSource = _world.get_node("EntityContainer/WaterSource1") as WaterSource
	var toward: Vector2 = (source.global_position - grass.global_position).normalized()
	_hold(&"")
	await _place_at(grass.global_position + toward * 6.0)
	check("stream_bare_hands_nearest_grass", _target() == grass, str(_target()))
	_hold(&"watering_can")
	_player.get_equipment().set_stack_data(&"weapon", ItemDefinition.WATER_KEY, 0)
	await frames(2)
	var hand_left: int = grass.hand_left
	check("stream_can_targets_water", _target() == source, str(_target()))
	await tap_action(&"interact")
	await process_frame
	check("stream_can_e_fills_not_cuts", _water_left() == 10 and grass.hand_left == hand_left, "%d · %s" % [_water_left(), _feedback()])

	# Cầm cuốc đất: ô ruộng thắng bụi khoai dại gần hơn.
	var potato: ResourceNode = _node("glade_wild_potato_1")
	var plot: FarmPlot = _field.get_plot(Vector2i(0, 0))
	toward = (plot.global_position - potato.global_position).normalized()
	var stand: Vector2 = potato.global_position + toward * 0.38 * potato.global_position.distance_to(plot.global_position)
	_hold(&"")
	await _place_at(stand)
	check("field_bare_hands_nearest_potato", _target() == potato, str(_target()))
	_hold(&"stone_hoe")
	await frames(2)
	plot = _target() as FarmPlot
	check("hoe_targets_field_plot", plot != null and plot.get_field() == _field, str(_target()))
	await tap_action(&"interact")
	await process_frame
	check("hoe_e_tills_plot", plot != null and plot.tilled, _feedback())
	if plot != null:
		plot.load_plot_state({}, null)

	# Cầm rìu: cây thắng bụi khoai dại sát bên; cầm cuốc chim (không khớp) → gần nhất như cũ.
	var tree: ResourceNode = _node("glade_tree_3")
	var potato_2: ResourceNode = _node("glade_wild_potato_2")
	toward = (tree.global_position - potato_2.global_position).normalized()
	_hold(&"stone_pickaxe")
	await _place_at(potato_2.global_position + toward * 8.0)
	check("other_tool_keeps_nearest", _target() == potato_2, str(_target()))
	_hold(&"stone_axe")
	await frames(2)
	check("axe_targets_tree", _target() == tree, str(_target()))
	var progress: int = tree.progress_left
	await tap_action(&"interact")
	await process_frame
	check("axe_e_chops_tree", tree.progress_left < progress and potato_2.hand_left == potato_2.definition.hand_uses, _feedback())
	tree.reset_full()
	_hold(&"")


# ---------------------------------------------------------------- 2. lý do không dựng được

func _test_placement_reasons() -> void:
	var bag: Inventory = _player.get_inventory()
	bag.clear()
	_player.get_equipment().set_slot(&"offhand", null)
	# Trên ruộng và sát mép ngoài ruộng.
	await _place_at(_field.get_plot(Vector2i(2, 1)).global_position)
	var reason: String = await _deploy_via_bag(&"tent")
	check("tent_on_field_near_field", reason == PlacementCheck.NEAR_FIELD and bag.has(&"tent"), reason)
	var outside: Vector2 = _field.to_global(_field.axis_i * 2.5 - _field.axis_j * 0.25)
	await _place_at(outside)
	reason = await _deploy_via_bag(&"tent")
	check("tent_beside_field_near_field", _field.plot_at(outside) == null and reason == PlacementCheck.NEAR_FIELD and bag.has(&"tent"), reason)
	# Lửa trại đặt trước mặt: đứng ngoài ruộng (chỗ đứng không chạm ruộng), quay mặt vào ruộng (xuống-trái).
	var facing_spot: Vector2 = _field.to_global(_field.axis_i * 3.0 - _field.axis_j * 0.9)
	await _place_at(facing_spot)
	press_action(&"move_left")
	press_action(&"move_down")
	await physics_frame
	await physics_frame
	press_action(&"move_left", false)
	press_action(&"move_down", false)
	await _place_at(facing_spot)
	reason = await _deploy_via_bag(&"campfire")
	check("campfire_facing_field_near_field", _field.plot_at(facing_spot) == null and reason == PlacementCheck.NEAR_FIELD
		and bag.has(&"campfire"), reason)
	# Có vật cản có tên (rương) và vật cản của map (thân cây thông trang trí ở tầng 0).
	var chest: Interactable = _world.get_node("EntityContainer/Chest") as Interactable
	await _place_at(chest.global_position + Vector2(0, 6))
	reason = await _deploy_via_bag(&"tent")
	check("tent_obstacle_named", reason == PlacementCheck.OBSTACLE_NAMED % chest.get_interaction_name() and bag.has(&"tent"), reason)
	var elevation: ElevationMap = get_first_node_in_group(ElevationMap.GROUP) as ElevationMap
	var pine: Node2D = null
	for prop: Node in _world.get_node("EntityContainer/Props").get_children():
		if prop.name.begins_with("TreePine") and elevation.get_tier_at((prop as Node2D).global_position) == 0:
			pine = prop as Node2D
			break
	await _place_at(pine.global_position + Vector2(0, 8))
	reason = await _deploy_via_bag(&"tent")
	check("tent_obstacle_unnamed", reason == PlacementCheck.OBSTACLE and bag.has(&"tent"), "%s (%s)" % [reason, pine.name])
	# Sai tầng: đứng ở tầng 0 dưới gầm cầu đá (mặt cầu là tầng 1).
	var bridge: Node2D = _world.get_node("EntityContainer/Elevation/StoneBridge") as Node2D
	var deck: PackedVector2Array = bridge.global_transform * (bridge.get(&"deck_polygon") as PackedVector2Array)
	var under: Vector2 = Vector2.ZERO
	for point: Vector2 in deck:
		under += point / deck.size()
	await _place_at(under, 0)
	reason = await _deploy_via_bag(&"tent")
	check("tent_under_bridge_wrong_tier", elevation.get_tier_at(under) != 0 and reason == PlacementCheck.WRONG_TIER and bag.has(&"tent"),
		"%s tầng %d" % [reason, elevation.get_tier_at(under)])
	# Đất không bằng: tâm ở tầng 0 nhưng footprint vắt lên vách plateau.
	var edge: Vector2 = _tier_edge(elevation, IsoProjection.to_screen(12.0, 9.0), Vector2(0, 1))
	await _place_at(edge, 0)
	reason = await _deploy_via_bag(&"tent")
	check("tent_uneven_ground", edge != Vector2.INF and reason == PlacementCheck.UNEVEN_GROUND and bag.has(&"tent"), "%s tại %s" % [reason, edge])
	# Chỗ trống hợp lệ vẫn dựng được.
	await _place_at(IsoProjection.to_screen(22.0, 35.0))
	reason = await _deploy_via_bag(&"tent")
	check("tent_ok_on_open_ground", not bag.has(&"tent"), reason)
	bag.clear()
	await frames(2)


## Đi từ `from` (tầng ≥ 1) theo hướng `step` tới điểm tầng 0 đầu tiên, rồi lùi ra ngoài thêm vài px: tâm tầng 0, footprint
## còn chạm tầng trên. Vector2.INF nếu không tìm được.
func _tier_edge(elevation: ElevationMap, from: Vector2, step: Vector2) -> Vector2:
	var at: Vector2 = from
	for i: int in 2000:
		at += step
		if elevation.get_tier_at(at) == 0:
			return at + step * 3.0
	return Vector2.INF


# ---------------------------------------------------------------- 3. chỗ khó chịu M6

## Giữ phím di chuyển (8 hướng) hướng thẳng về đích, không theo navmesh. true nếu tới nơi trong `max_seconds`.
func _walk_straight(target: Vector2, max_seconds: float) -> bool:
	var actions: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
	var arrived: bool = false
	for i: int in int(max_seconds * 60.0):
		var delta: Vector2 = target - _player.global_position
		if delta.length() < 12.0:
			arrived = true
			break
		var want: Array[StringName] = []
		if absf(delta.x) > 4.0:
			want.append(&"move_right" if delta.x > 0.0 else &"move_left")
		if absf(delta.y) > 4.0:
			want.append(&"move_down" if delta.y > 0.0 else &"move_up")
		for action: StringName in actions:
			if want.has(action) != Input.is_action_pressed(action):
				press_action(action, want.has(action))
		await physics_frame
	for action: StringName in actions:
		press_action(action, false)
	return arrived


func _test_walk_to_water() -> void:
	var bed: Node2D = _world.get_node("EntityContainer/Bed") as Node2D
	var starts: Dictionary[String, Vector2] = {"field": _field.to_global(_field.axis_i * 3.0 - _field.axis_j * 0.6),
		"bed": bed.global_position + Vector2(0, -24)}
	for start_name: String in starts:
		for source_name: String in ["WaterSource1", "WaterSource2"]:
			var source: Node2D = _world.get_node("EntityContainer/" + source_name) as Node2D
			await _place_at(starts[start_name])
			var ok: bool = await _walk_straight(source.global_position, 15.0)
			check("walk_straight_%s_to_%s" % [start_name, source_name.to_snake_case()], ok, "dừng ở %s, còn %.0f px" % [
				_player.global_position.round(), _player.global_position.distance_to(source.global_position)])


func _test_canopy_fade() -> void:
	var oak: Node2D = _world.get_node("EntityContainer/Props/TreeOakA") as Node2D
	var fader: OcclusionFader = oak.get_node("OcclusionFader") as OcclusionFader
	check("tree_fade_alpha_low", fader.faded_alpha <= 0.25, str(fader.faded_alpha))
	await _place_at(oak.global_position + Vector2(0, -20))
	await seconds(0.4)
	var visual: CanvasItem = oak.get_node("Visual") as CanvasItem
	check("tree_fades_when_behind", absf(visual.modulate.a - fader.faded_alpha) < 0.02, str(visual.modulate.a))
	await _place_at(IsoProjection.to_screen(22.0, 35.0))


func _test_check_icons() -> void:
	var panel: Control = (load("res://ui/menus/settings_panel.gd") as GDScript).call(&"create") as Control
	_world.get_node("UILayer").add_child(panel)
	await frames(2)
	var toggles: Array[Node] = panel.find_children("*", "CheckButton", true, false)
	var all_styled: bool = not toggles.is_empty()
	for node: Node in toggles:
		all_styled = all_styled and _icon_has_border((node as Control).get_theme_icon(&"unchecked"))
	check("settings_toggles_have_border", all_styled, "%d công tắc" % toggles.size())
	panel.queue_free()
	var hints: Control = (load("res://ui/menus/start_hints_panel.gd") as GDScript).call(&"create") as Control
	_world.get_node("UILayer").add_child(hints)
	await frames(2)
	var box: CheckBox = hints.find_child("DontShowAgain", true, false) as CheckBox
	check("dont_show_checkbox_has_border", box != null and _icon_has_border(box.get_theme_icon(&"unchecked"))
		and box.get_theme_icon(&"checked") != box.get_theme_icon(&"unchecked"))
	hints.queue_free()
	paused = false
	await frames(2)


## Góc icon là màu viền đục, khác hẳn màu nền khung menu.
func _icon_has_border(icon: Texture2D) -> bool:
	if icon == null:
		return false
	var image: Image = icon.get_image()
	var corner: Color = image.get_pixel(0, 0)
	var inside: Color = image.get_pixel(image.get_width() / 2 - 6, image.get_height() / 2)
	return corner.a > 0.8 and absf(corner.get_luminance() - MenuUI.PANEL_COLOR.get_luminance()) > 0.3 and corner != inside
