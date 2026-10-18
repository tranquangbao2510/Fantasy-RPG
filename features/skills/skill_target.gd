class_name SkillTarget
extends RefCounted
## Mục tiêu đã giải quyết của một lần thi triển; dùng chung cho indicator và effect để vùng hiển thị khớp vùng tác động.

## Điểm xuất phát (người thi triển).
var origin: Vector2
## Hướng chuẩn hóa từ origin tới điểm ngắm.
var direction: Vector2
## Tâm vùng tác động (GROUND_CIRCLE: điểm ngắm đã kẹp; SELF: origin; LINE/CONE: origin).
var point: Vector2


## Quy tắc prototype: điểm ngắm xa hơn cast_range được kẹp về cast_range (không từ chối).
static func resolve(definition: SkillDefinition, p_origin: Vector2, aim_point: Vector2, fallback_direction: Vector2) -> SkillTarget:
	var target: SkillTarget = SkillTarget.new()
	target.origin = p_origin
	var offset: Vector2 = aim_point - p_origin
	target.direction = offset.normalized() if offset.length() > 1.0 else fallback_direction.normalized()
	match definition.targeting_type:
		SkillDefinition.TargetingType.GROUND_CIRCLE:
			target.point = p_origin + offset.limit_length(definition.cast_range)
		_:
			target.point = p_origin
	return target
