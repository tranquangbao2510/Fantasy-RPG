class_name VisionLight
extends Node2D
## Nguồn sáng mở vùng nhìn ban đêm (TASK M2): quanh Player, đá rune, đèn nhà, lửa trại... Vùng sáng là hình tròn trên
## MẶT ĐẤT bán kính `radius` (ellipse 2:1 trên map iso theo `ground_squash`): sáng đều tới `inner_ratio`, mờ dần tới mép.
## Cường độ = độ tối × `energy` (ban ngày tắt). DayNightLighting điều khiển mọi node trong group `vision_light`, dùng
## cover_at() để tính "điểm nhìn thấy" và gửi các nguồn sáng cho NightOverlay vẽ (TASK M4: không còn PointLight2D con).
## TASK M4: `safe_zone` = vùng an toàn (lửa trại đang cháy, đá rune, đèn cạnh giường): quái không spawn trong đó,
## quái sợ sáng (Shade) không bước vào.

const GROUP: StringName = &"vision_light"

@export var radius: float = 120.0:
	set(value):
		radius = maxf(value, 1.0)
@export var color: Color = Color(1, 0.85, 0.6)
@export var energy: float = 1.0
@export_range(0.0, 0.95) var inner_ratio: float = 0.6
@export var ground_squash: float = 1.0
## Vùng an toàn trước quái đêm (TASK M4). Tầm nhìn của Player, đèn cầm tay không phải vùng an toàn.
@export var safe_zone: bool = false

var darkness: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)


## Map isometric (IsoActorAdapter gọi khi gắn trên Player).
func set_ground_squash(squash: float) -> void:
	ground_squash = squash


func set_darkness(value: float) -> void:
	darkness = clampf(value, 0.0, 1.0)


## Cường độ hiện tại (0 khi ban ngày hoặc bị ẩn, vd. lửa trại đã tắt).
func get_strength() -> float:
	return darkness * energy if is_visible_in_tree() else 0.0


## Đang phát sáng (ban đêm/hoàng hôn và không bị ẩn).
func is_lit() -> bool:
	return get_strength() > 0.001


## Mức che phủ của nguồn sáng tại điểm world (0..1): 1 trong phần lõi, giảm tuyến tính tới 0 ở mép bán kính.
func cover_at(point: Vector2) -> float:
	if not is_visible_in_tree():
		return 0.0
	var distance: float = GroundSpace.length(point - global_position, ground_squash) / radius
	if distance <= inner_ratio:
		return 1.0
	return clampf((1.0 - distance) / maxf(1.0 - inner_ratio, 0.001), 0.0, 1.0)


## Điểm nằm trong vùng sáng (bán kính + `margin` px mặt đất). Không xét ngày/đêm, chỉ xét đèn có đang bật không.
func contains(point: Vector2, margin: float = 0.0) -> bool:
	return is_visible_in_tree() and GroundSpace.length(point - global_position, ground_squash) < radius + margin


## Khung bao vùng sáng (màn hình) giao với `rect`.
func intersects(rect: Rect2) -> bool:
	var half: Vector2 = Vector2(radius, radius * ground_squash)
	return Rect2(global_position - half, half * 2.0).intersects(rect)


## Nguồn sáng an toàn đang bật chứa điểm (null nếu không có). Chỉ xét nguồn sáng trong `scene`.
static func find_safe_light(scene: Node, point: Vector2, margin: float = 0.0) -> VisionLight:
	if scene == null or not scene.is_inside_tree():
		return null
	for node: Node in scene.get_tree().get_nodes_in_group(GROUP):
		var light: VisionLight = node as VisionLight
		if light != null and light.safe_zone and scene.is_ancestor_of(light) and light.contains(point, margin):
			return light
	return null
