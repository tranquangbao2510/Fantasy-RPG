class_name VisionLight
extends Node2D
## Nguồn sáng mở vùng nhìn ban đêm (TASK M2): quanh Player, đá rune, đèn nhà... Tạo một PointLight2D con dùng texture
## gradient tròn (sáng đều tới `inner_ratio`, mờ dần tới mép), bán kính đo trên MẶT ĐẤT (node con nén dọc theo
## `ground_squash` → ellipse 2:1 trên map iso). Ban ngày tắt.
## Pha trộn MIX (TASK M3, thay ADD của M2): vùng sáng kéo màu về `albedo × màu đích` theo alpha của texture, màu đích =
## ambient (SunTint hiện tại).lerp(`color`, độ tối) × `energy`. Nhiều nguồn chồng nhau không cộng dồn → không cháy trắng
## (ADD: 2–3 lửa trại chồng nhau vượt 1.0 → trắng xoá); bình minh/hoàng hôn màu đích ≈ ambient nên bật/tắt không giật.
## DayNightLighting điều khiển mọi node trong group `vision_light` và dùng cover_at() để tính "điểm nhìn thấy".

const GROUP: StringName = &"vision_light"
const TEXTURE_SIZE: int = 256

static var _textures: Dictionary[int, GradientTexture2D] = {}

@export var radius: float = 120.0:
	set(value):
		radius = maxf(value, 1.0)
		_apply_shape()
@export var color: Color = Color(1, 0.85, 0.6):
	set(value):
		color = value
		_apply_color()
@export var energy: float = 1.0:
	set(value):
		energy = value
		_apply_color()
@export_range(0.0, 0.95) var inner_ratio: float = 0.6:
	set(value):
		inner_ratio = value
		_apply_shape()
@export var ground_squash: float = 1.0:
	set(value):
		ground_squash = value
		_apply_shape()

var darkness: float = 0.0
## Màu SunTint hiện tại (DayNightLighting gán mỗi frame).
var ambient: Color = Color.WHITE
var _light: PointLight2D


func _ready() -> void:
	add_to_group(GROUP)
	_light = PointLight2D.new()
	_light.name = "Light"
	_light.blend_mode = Light2D.BLEND_MODE_MIX
	add_child(_light)
	_apply_shape()
	set_darkness(darkness)


## Map isometric (IsoActorAdapter gọi khi gắn trên Player).
func set_ground_squash(squash: float) -> void:
	ground_squash = squash


func set_darkness(value: float) -> void:
	darkness = clampf(value, 0.0, 1.0)
	_apply_color()


func set_ambient(value: Color) -> void:
	ambient = value
	_apply_color()


func _apply_color() -> void:
	if _light == null:
		return
	_light.color = ambient.lerp(color, darkness)
	_light.energy = energy
	_light.enabled = darkness > 0.001 and energy > 0.001


func get_light() -> PointLight2D:
	return _light


## Mức che phủ của nguồn sáng tại điểm world (0..1): 1 trong phần lõi, giảm tuyến tính tới 0 ở mép bán kính.
func cover_at(point: Vector2) -> float:
	if not is_visible_in_tree():
		return 0.0
	var distance: float = GroundSpace.length(point - global_position, ground_squash) / radius
	if distance <= inner_ratio:
		return 1.0
	return clampf((1.0 - distance) / maxf(1.0 - inner_ratio, 0.001), 0.0, 1.0)


func _apply_shape() -> void:
	if _light == null:
		return
	_light.texture = _texture_for(inner_ratio)
	_light.texture_scale = 2.0 * radius / TEXTURE_SIZE
	_light.scale = Vector2(1.0, ground_squash)


static func _texture_for(inner: float) -> GradientTexture2D:
	var key: int = roundi(inner * 100.0)
	if _textures.has(key):
		return _textures[key]
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(inner, Color.WHITE)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = TEXTURE_SIZE
	texture.height = TEXTURE_SIZE
	_textures[key] = texture
	return texture
