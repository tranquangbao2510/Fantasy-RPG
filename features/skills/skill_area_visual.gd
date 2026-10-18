class_name SkillAreaVisual
extends Node2D
## Vẽ vùng của một kỹ năng trong world coordinates (indicator khi ngắm, flash khi thi triển).
## Chỉ hiển thị: không có collision, không gây damage. Hình dạng lấy từ cùng SkillDefinition + SkillTarget với effect.
## Map isometric (target.ground_squash < 1): vẽ hình trên mặt phẳng đất (ellipse 2:1, hình bình hành, quạt nén dọc).
## Vì top_level, z_index là tuyệt đối: hệ thống elevation đặt z theo tầng của người cast (SkillCastingController.set_elevation).

const ARC_SEGMENTS: int = 24

var _definition: SkillDefinition
var _target: SkillTarget
var _color: Color = Color.WHITE
var _tween: Tween


func _ready() -> void:
	# Vẽ theo tọa độ world, không theo transform của người thi triển.
	top_level = true
	global_transform = Transform2D.IDENTITY
	hide()


func is_showing() -> bool:
	return visible and _definition != null


func show_area(definition: SkillDefinition, target: SkillTarget, color: Color) -> void:
	_kill_tween()
	_definition = definition
	_target = target
	_color = color
	modulate = Color.WHITE
	show()
	queue_redraw()


## Hiện vùng rồi mờ dần trong duration giây (phản hồi khi effect xảy ra).
func flash(definition: SkillDefinition, target: SkillTarget, color: Color, duration: float = 0.3) -> void:
	show_area(definition, target, color)
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", 0.0, duration)
	_tween.tween_callback(clear)


func clear() -> void:
	_kill_tween()
	_definition = null
	_target = null
	hide()


func _draw() -> void:
	if _definition == null or _target == null:
		return
	var outline: Color = Color(_color, minf(1.0, _color.a * 2.5))
	if _target.ground_squash != 1.0:
		_draw_ground(outline)
		return
	match _definition.targeting_type:
		SkillDefinition.TargetingType.SELF:
			var r: float = _definition.radius if _definition.radius > 0.0 else 14.0
			draw_circle(_target.origin, r, _color)
			draw_arc(_target.origin, r, 0.0, TAU, ARC_SEGMENTS * 2, outline, 1.0)
		SkillDefinition.TargetingType.GROUND_CIRCLE:
			draw_arc(_target.origin, _definition.cast_range, 0.0, TAU, ARC_SEGMENTS * 2, Color(outline, 0.25), 1.0)
			draw_circle(_target.point, _definition.radius, _color)
			draw_arc(_target.point, _definition.radius, 0.0, TAU, ARC_SEGMENTS * 2, outline, 1.0)
		SkillDefinition.TargetingType.LINE:
			var side: Vector2 = _target.direction.orthogonal() * _definition.width / 2.0
			var end: Vector2 = _target.origin + _target.direction * _definition.cast_range
			var rect: PackedVector2Array = PackedVector2Array([
				_target.origin + side, end + side, end - side, _target.origin - side])
			draw_colored_polygon(rect, _color)
			rect.append(rect[0])
			draw_polyline(rect, outline, 1.0)
		SkillDefinition.TargetingType.CONE:
			var half: float = deg_to_rad(_definition.angle_degrees) / 2.0
			var base: float = _target.direction.angle()
			var points: PackedVector2Array = PackedVector2Array([_target.origin])
			for i: int in ARC_SEGMENTS + 1:
				var a: float = base - half + (2.0 * half) * float(i) / ARC_SEGMENTS
				points.append(_target.origin + Vector2.from_angle(a) * _definition.cast_range)
			draw_colored_polygon(points, _color)
			points.append(_target.origin)
			draw_polyline(points, outline, 1.0)


func _draw_ground(outline: Color) -> void:
	var s: float = _target.ground_squash
	var shape: PackedVector2Array
	match _definition.targeting_type:
		SkillDefinition.TargetingType.SELF:
			shape = GroundSpace.circle(_target.origin, _definition.radius if _definition.radius > 0.0 else 14.0, s, ARC_SEGMENTS * 2)
		SkillDefinition.TargetingType.GROUND_CIRCLE:
			var range_ring: PackedVector2Array = GroundSpace.circle(_target.origin, _definition.cast_range, s, ARC_SEGMENTS * 2)
			range_ring.append(range_ring[0])
			draw_polyline(range_ring, Color(outline, 0.25), 1.0)
			shape = GroundSpace.circle(_target.point, _definition.radius, s, ARC_SEGMENTS * 2)
		SkillDefinition.TargetingType.LINE:
			shape = GroundSpace.rect(GroundSpace.direction(_target.direction, s), _definition.cast_range, _definition.width, s)
			for i: int in shape.size():
				shape[i] += _target.origin
		SkillDefinition.TargetingType.CONE:
			shape = GroundSpace.cone(_target.origin, GroundSpace.direction(_target.direction, s), _definition.cast_range,
				deg_to_rad(_definition.angle_degrees) / 2.0, s, ARC_SEGMENTS)
	if shape.size() < 3:
		return
	draw_colored_polygon(shape, _color)
	shape.append(shape[0])
	draw_polyline(shape, outline, 1.0)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
