class_name NightOverlay
extends Node2D
## Lớp phủ ánh sáng ngày/đêm (TASK M4): một hình chữ nhật phủ vùng camera đang thấy, vẽ trên mọi thứ của canvas map
## (z tuyệt đối gần tối đa), shader nhân màu (blend_mul): màu môi trường `ambient` (ngày → hoàng hôn → ánh trăng) +
## ánh sáng của nguồn sáng mạnh nhất tại mỗi điểm (lấy max, không cộng dồn → không cháy trắng khi lửa trại, đuốc,
## tầm nhìn chồng nhau). UI ở CanvasLayer riêng không bị ảnh hưởng.
## Thay cho CanvasModulate + PointLight2D (blend Add) của M2: một lượt vẽ cho mọi nguồn sáng (Light2D trên renderer
## Compatibility vẽ lại mọi vật trong vùng của từng đèn). DayNightLighting gọi set_lights() mỗi frame.

const MAX_LIGHTS: int = 32
const Z: int = RenderingServer.CANVAS_ITEM_Z_MAX - 1
const SHADER: Shader = preload("res://world/environment/time/night_overlay.gdshader")

var _material: ShaderMaterial
var _rect: Rect2 = Rect2()
## Số nguồn sáng đã gửi cho shader ở lần cập nhật gần nhất (test/debug).
var light_count: int = 0


func _ready() -> void:
	z_index = Z
	z_as_relative = false
	top_level = true
	global_transform = Transform2D.IDENTITY
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material


## Vùng world đang hiển thị (theo canvas transform của viewport).
func get_visible_rect() -> Rect2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return Rect2()
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()


## Cập nhật màu môi trường + danh sách nguồn sáng (đã lọc theo vùng nhìn thấy, tối đa MAX_LIGHTS, ưu tiên gần tâm).
func set_lights(ambient: Color, lights: Array[VisionLight]) -> void:
	var visible_rect: Rect2 = get_visible_rect()
	var center: Vector2 = visible_rect.get_center()
	var candidates: Array[VisionLight] = []
	for light: VisionLight in lights:
		if light.get_strength() > 0.001 and light.intersects(visible_rect):
			candidates.append(light)
	if candidates.size() > MAX_LIGHTS:
		candidates.sort_custom(func(a: VisionLight, b: VisionLight) -> bool:
			return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
		candidates.resize(MAX_LIGHTS)
	var shapes: PackedVector4Array = PackedVector4Array()
	var tints: PackedVector4Array = PackedVector4Array()
	shapes.resize(MAX_LIGHTS)
	tints.resize(MAX_LIGHTS)
	for i: int in candidates.size():
		var light: VisionLight = candidates[i]
		var strength: float = light.get_strength()
		shapes[i] = Vector4(light.global_position.x, light.global_position.y, light.radius, light.inner_ratio)
		tints[i] = Vector4(light.color.r * strength, light.color.g * strength, light.color.b * strength, maxf(light.ground_squash, 0.01))
	light_count = candidates.size()
	_material.set_shader_parameter(&"ambient", Vector3(ambient.r, ambient.g, ambient.b))
	_material.set_shader_parameter(&"light_count", light_count)
	_material.set_shader_parameter(&"light_shape", shapes)
	_material.set_shader_parameter(&"light_tint", tints)
	if not visible_rect.is_equal_approx(_rect):
		_rect = visible_rect
		queue_redraw()


func _draw() -> void:
	if _rect.has_area():
		draw_rect(_rect.grow(8.0), Color.WHITE)
