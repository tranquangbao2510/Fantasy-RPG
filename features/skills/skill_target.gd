class_name SkillTarget
extends RefCounted
## Mục tiêu đã giải quyết của một lần thi triển; dùng chung cho indicator và effect để vùng hiển thị khớp vùng tác động.

## Điểm xuất phát (người thi triển).
var origin: Vector2
## Hướng chuẩn hóa từ origin tới điểm ngắm.
var direction: Vector2
## Tâm vùng tác động (GROUND_CIRCLE: điểm ngắm đã kẹp; SELF: origin; LINE/CONE: origin).
var point: Vector2
## Tỉ lệ dọc của mặt đất (1 = map cũ, 0.5 = isometric): cast_range, radius, width đo trên mặt đất. Xem GroundSpace.
var ground_squash: float = 1.0


## Quy tắc prototype: điểm ngắm xa hơn cast_range (đo trên mặt đất) được kẹp về cast_range (không từ chối).
static func resolve(definition: SkillDefinition, p_origin: Vector2, aim_point: Vector2, fallback_direction: Vector2,
		p_ground_squash: float = 1.0) -> SkillTarget:
	var target: SkillTarget = SkillTarget.new()
	target.origin = p_origin
	target.ground_squash = p_ground_squash
	var offset: Vector2 = aim_point - p_origin
	target.direction = offset.normalized() if offset.length() > 1.0 else fallback_direction.normalized()
	match definition.targeting_type:
		SkillDefinition.TargetingType.GROUND_CIRCLE:
			target.point = p_origin + GroundSpace.limit(offset, definition.cast_range, p_ground_squash)
		_:
			target.point = p_origin
	return target
