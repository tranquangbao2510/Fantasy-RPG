extends "res://tests/test_base.gd"
## Kiểm thử headless cho Environment Prototype isometric (TASK VISUAL-02): elevation, collision, thứ tự che/fade.
## Chạy:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/environment/test_environment_prototype.gd
## Mỗi ca: đặt Player tại một điểm lưới (i, j) ở tầng cho trước, giữ phím di chuyển theo một hướng MÀN HÌNH
## trong N physics frame, rồi kiểm tra kết quả. Thoát với mã 1 nếu có ca thất bại hoặc lỗi ngoài dự kiến (test_base.gd).

const SCENE_PATH: String = "res://world/environment_prototype/environment_prototype.tscn"
const H: float = IsoProjection.TIER_HEIGHT

var _world: Node
var _player: CharacterBody2D
var _agent: ElevationAgent
var _plateau: ElevatedTerrain
var _cases: Array[Dictionary] = []
var _index: int = -1
var _frames: int = 0
var _never_inside: bool = true


func _run_tests() -> void:
	_world = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_world)
	_player = _world.get_node("EntityContainer/Player") as CharacterBody2D
	_agent = _player.get_node("ElevationAgent") as ElevationAgent
	_plateau = _world.get_node("EntityContainer/Elevation/Plateau") as ElevatedTerrain
	var outcrop: ElevatedTerrain = _world.get_node("EntityContainer/Elevation/Outcrop") as ElevatedTerrain
	var land: PackedVector2Array = (_world.get_node("MapContainer/GladeMap/LandEdge/Loop") as CollisionPolygon2D).polygon
	var stairs_dir: Vector2 = IsoProjection.to_screen(10.75, 16.8, H) - IsoProjection.to_screen(10.75, 18.85)
	var along_i: Vector2 = IsoProjection.to_screen(1, 0)
	var along_j: Vector2 = IsoProjection.to_screen(0, 1)
	_case("stairs_up", Vector2(10.75, 19.4), 0, stairs_dir, 150, func() -> bool:
		return _agent.get_tier() == 1 and not _agent.is_transitioning() and _inside(_plateau.get_walkable_polygon()))
	_case("stairs_down", Vector2(10.75, 15.9), 1, -stairs_dir, 150, func() -> bool:
		return _agent.get_tier() == 0 and not _inside(_plateau.get_blocking_polygon()) and _grid().y > 18.5)
	# Làn i = 12 trống tới chân vách SW (j = 17): Player phải dừng ngay trước chân vách, không lọt vào khối.
	_case("cliff_blocks_low_sw", Vector2(12.0, 21.0), 0, -along_j, 160, func() -> bool:
		return _agent.get_tier() == 0 and not _inside(_plateau.get_blocking_polygon()) and _grid().y < 17.6)
	_case("cliff_blocks_low_se", Vector2(23.0, 13.0), 0, -along_i, 120, func() -> bool:
		return _agent.get_tier() == 0 and not _inside(_plateau.get_blocking_polygon()))
	_case("cliff_blocks_high_sw", Vector2(14.5, 15.0), 1, along_j, 120, func() -> bool:
		return _agent.get_tier() == 1 and _inside(_plateau.get_walkable_polygon()))
	# Đi về mép SE có thể trượt dọc vách lên lối đi trên vòm: hợp lệ miễn là vẫn trong vùng đi được của tầng 1.
	_case("cliff_blocks_high_se", Vector2(18.0, 13.5), 1, along_i, 120, func() -> bool:
		return _agent.get_tier() == 1 and _in_tier_walkable(1))
	_case("bridge_over_arch", Vector2(18.8, 10.35), 1, along_i, 200, func() -> bool:
		return _agent.get_tier() == 1 and _inside(outcrop.get_walkable_polygon()))
	_case("under_arch", Vector2(21.25, 15.0), 0, -along_j, 220, func() -> bool:
		return _agent.get_tier() == 0 and _grid().y < 8.0)
	_case("water_blocks", Vector2(24.0, 29.0), 0, -along_j, 150, func() -> bool:
		return _grid().y > 26.0)
	_case("footbridge", Vector2(17.5, 28.4), 0, -along_j, 200, func() -> bool:
		return _grid().y < 23.4)
	# Thân cây (31, 30): Player có thể trượt vòng qua, nhưng tâm thân không bao giờ lọt vào footprint gốc cây.
	var trunk: PackedVector2Array = IsoProjection.ground_ellipse(IsoProjection.to_screen(31.0, 30.0) + Vector2(0, -2), 11.0)
	_case("tree_trunk_blocks", Vector2(31.0, 31.0), 0, -along_j, 90, func() -> bool:
		return _never_inside, func() -> void:
		_never_inside = _never_inside and not _inside(trunk))
	_case("abyss_edge_sw", Vector2(20.0, 37.5), 0, along_j, 150, func() -> bool:
		return Geometry2D.is_point_in_polygon(_player.global_position, land))
	_case("rim_edge_ne", Vector2(25.0, 3.0), 0, -along_j, 150, func() -> bool:
		return Geometry2D.is_point_in_polygon(_player.global_position, land))
	_case("behind_tree_fades", Vector2(31.0, 29.5), 0, Vector2.ZERO, 30, func() -> bool:
		return _prop_alpha(Vector2(31.0, 30.0)) < 0.9)
	_case("front_of_tree_opaque", Vector2(31.0, 30.6), 0, Vector2.ZERO, 30, func() -> bool:
		return _prop_alpha(Vector2(31.0, 30.0)) > 0.99 and _player.global_position.y > IsoProjection.to_screen(31.0, 30.0).y)
	_case("under_bridge_fades", Vector2(21.25, 10.6), 0, Vector2.ZERO, 30, func() -> bool:
		return _bridge_alpha() < 0.9)
	_case("on_bridge_opaque", Vector2(22.3, 10.35), 1, Vector2.ZERO, 30, func() -> bool:
		return _bridge_alpha() > 0.99 and _player.z_index == ElevationMap.tier_z(1))
	# Các ca chạy trong _physics_process; chờ tới khi xong.
	while _index < _cases.size():
		await physics_frame


func _case(label: String, grid: Vector2, tier: int, screen_dir: Vector2, frame_count: int, verify: Callable, each_frame: Callable = Callable()) -> void:
	_cases.append({"name": label, "grid": grid, "tier": tier, "dir": screen_dir, "frames": frame_count, "check": verify, "each_frame": each_frame})


func _physics_process(_delta: float) -> bool:
	if _world == null:
		return false
	if _index >= 0 and _frames > 0:
		_frames -= 1
		var each_frame: Callable = _cases[_index]["each_frame"]
		if each_frame.is_valid():
			each_frame.call()
		return false
	if _index >= 0:
		_release()
		var c: Dictionary = _cases[_index]
		var ok: bool = (c["check"] as Callable).call()
		check(c["name"], ok, "grid=%s tier=%d" % [_grid().snapped(Vector2(0.01, 0.01)), _agent.get_tier()])
	_index += 1
	if _index >= _cases.size():
		return false
	_begin_case(_cases[_index])
	return false


func _begin_case(c: Dictionary) -> void:
	var grid: Vector2 = c["grid"]
	var tier: int = c["tier"]
	_player.global_position = IsoProjection.to_screen(grid.x, grid.y, H * tier)
	_player.velocity = Vector2.ZERO
	_agent.initial_tier = tier
	_agent.reset_state()
	_frames = int(c["frames"]) + 3
	_never_inside = true
	var screen_dir: Vector2 = c["dir"]
	if screen_dir == Vector2.ZERO:
		return
	# Player nhân vận tốc dọc với vertical_speed_scale → chia ngược để thân đi đúng hướng màn hình mong muốn.
	var scale_y: float = float(_player.get("vertical_speed_scale"))
	var input: Vector2 = Vector2(screen_dir.x, screen_dir.y / scale_y).normalized()
	_press.call_deferred(input)


func _press(input: Vector2) -> void:
	if input.x > 0.0:
		Input.action_press(&"move_right", input.x)
	elif input.x < 0.0:
		Input.action_press(&"move_left", -input.x)
	if input.y > 0.0:
		Input.action_press(&"move_down", input.y)
	elif input.y < 0.0:
		Input.action_press(&"move_up", -input.y)


func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


## Toạ độ lưới của Player (bỏ phần độ cao tầng).
func _grid() -> Vector2:
	return IsoProjection.to_grid(_player.global_position + Vector2(0, H * _agent.get_tier()))


func _in_tier_walkable(tier: int) -> bool:
	var map: ElevationMap = _world.get_node("EntityContainer/Elevation") as ElevationMap
	for polygon: PackedVector2Array in map.get_walkable_polygons(tier):
		if _inside(polygon):
			return true
	return false


func _inside(polygon: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(_player.global_position, polygon)


func _prop_alpha(grid: Vector2) -> float:
	var target: Vector2 = IsoProjection.to_screen(grid.x, grid.y)
	for node: Node in _world.get_node("EntityContainer/Props").get_children():
		var prop: Node2D = node as Node2D
		if prop.global_position.distance_to(target) < 4.0:
			return (prop.get_node("Visual") as CanvasItem).modulate.a
	push_error("Không tìm thấy prop tại %s" % grid)
	return -1.0


func _bridge_alpha() -> float:
	return (_world.get_node("EntityContainer/Elevation/StoneBridge/Visual") as CanvasItem).modulate.a
