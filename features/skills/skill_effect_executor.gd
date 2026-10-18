class_name SkillEffectExecutor
extends RefCounted
## Thực thi effect của một lần thi triển. Gọi trong physics tick (dùng PhysicsDirectSpaceState2D).
## DAMAGE: tìm Hurtbox phe đối địch (collision_mask = target_layers) trong vùng, mỗi mục tiêu 1 lần,
## gây sát thương qua Hurtbox.receive_damage(DamageInfo) — cùng Damage System với đánh thường.
## HEAL: HealthComponent.heal() của người thi triển.
## Map isometric (target.ground_squash < 1): vùng tác dụng dựng trên mặt phẳng đất (tròn → ellipse 2:1, chữ nhật → hình
## bình hành), góc quạt so trên mặt đất. tier_mask (≠ 0) chỉ cho trúng Hurtbox cùng tầng.

const MAX_RESULTS: int = 32


## Trả về số mục tiêu bị trúng (DAMAGE) hoặc lượng HP hồi được (HEAL).
static func execute(definition: SkillDefinition, target: SkillTarget, caster: Node, caster_health: HealthComponent,
		space: PhysicsDirectSpaceState2D, target_layers: int, tier_mask: int = 0) -> int:
	match definition.effect_type:
		SkillDefinition.EffectType.HEAL:
			return caster_health.heal(definition.effect_amount) if caster_health != null else 0
		SkillDefinition.EffectType.DAMAGE:
			var hits: int = 0
			for hurtbox: Hurtbox in find_hurtboxes(definition, target, space, target_layers):
				var info: DamageInfo = DamageInfo.new(definition.effect_amount, caster)
				info.tier_mask = tier_mask
				info.knockback = _knockback_direction(definition, target, hurtbox) * definition.knockback
				if hurtbox.receive_damage(info) > 0:
					hits += 1
			return hits
	return 0


## Hurtbox trong vùng tác động, không trùng mục tiêu (nhiều Hurtbox cùng HealthComponent tính một lần).
static func find_hurtboxes(definition: SkillDefinition, target: SkillTarget, space: PhysicsDirectSpaceState2D,
		target_layers: int) -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	var query: PhysicsShapeQueryParameters2D = _build_query(definition, target)
	if query == null:
		return found
	query.collision_mask = target_layers
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var keys: Array[Object] = []
	for result: Dictionary in space.intersect_shape(query, MAX_RESULTS):
		var hurtbox: Hurtbox = result.get("collider") as Hurtbox
		if hurtbox == null or keys.has(hurtbox.get_damage_key()):
			continue
		if definition.targeting_type == SkillDefinition.TargetingType.CONE and not _in_cone(definition, target, hurtbox):
			continue
		keys.append(hurtbox.get_damage_key())
		found.append(hurtbox)
	return found


static func _build_query(definition: SkillDefinition, target: SkillTarget) -> PhysicsShapeQueryParameters2D:
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	var s: float = target.ground_squash
	if s != 1.0:
		return _build_ground_query(query, definition, target, s)
	match definition.targeting_type:
		SkillDefinition.TargetingType.SELF:
			if definition.radius <= 0.0:
				return null
			query.shape = _circle(definition.radius)
			query.transform = Transform2D(0.0, target.origin)
		SkillDefinition.TargetingType.GROUND_CIRCLE:
			query.shape = _circle(definition.radius)
			query.transform = Transform2D(0.0, target.point)
		SkillDefinition.TargetingType.CONE:
			# Hình tròn bán kính cast_range rồi lọc theo góc (_in_cone).
			query.shape = _circle(definition.cast_range)
			query.transform = Transform2D(0.0, target.origin)
		SkillDefinition.TargetingType.LINE:
			var rect: RectangleShape2D = RectangleShape2D.new()
			rect.size = Vector2(definition.cast_range, definition.width)
			query.shape = rect
			query.transform = Transform2D(target.direction.angle(), target.origin + target.direction * definition.cast_range / 2.0)
	return query


## Map isometric: shape là polygon màn hình dựng từ hình trên mặt đất, đặt tại gốc (transform chỉ tịnh tiến).
static func _build_ground_query(query: PhysicsShapeQueryParameters2D, definition: SkillDefinition, target: SkillTarget,
		s: float) -> PhysicsShapeQueryParameters2D:
	match definition.targeting_type:
		SkillDefinition.TargetingType.SELF:
			if definition.radius <= 0.0:
				return null
			query.shape = GroundSpace.polygon_shape(GroundSpace.circle(Vector2.ZERO, definition.radius, s))
			query.transform = Transform2D(0.0, target.origin)
		SkillDefinition.TargetingType.GROUND_CIRCLE:
			query.shape = GroundSpace.polygon_shape(GroundSpace.circle(Vector2.ZERO, definition.radius, s))
			query.transform = Transform2D(0.0, target.point)
		SkillDefinition.TargetingType.CONE:
			query.shape = GroundSpace.polygon_shape(GroundSpace.circle(Vector2.ZERO, definition.cast_range, s))
			query.transform = Transform2D(0.0, target.origin)
		SkillDefinition.TargetingType.LINE:
			query.shape = GroundSpace.polygon_shape(GroundSpace.rect(GroundSpace.direction(target.direction, s), definition.cast_range, definition.width, s))
			query.transform = Transform2D(0.0, target.origin)
	return query


static func _circle(radius: float) -> CircleShape2D:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	return circle


## Prototype: so góc tới tâm vùng nhận đòn (Hurtbox.get_hit_position()) với nửa góc quạt.
static func _in_cone(definition: SkillDefinition, target: SkillTarget, hurtbox: Hurtbox) -> bool:
	var s: float = target.ground_squash
	var to_hit: Vector2 = GroundSpace.to_ground(hurtbox.get_hit_position() - target.origin, s)
	if to_hit.is_zero_approx():
		return true
	return absf(GroundSpace.direction(target.direction, s).angle_to(to_hit)) <= deg_to_rad(definition.angle_degrees) / 2.0


static func _knockback_direction(definition: SkillDefinition, target: SkillTarget, hurtbox: Hurtbox) -> Vector2:
	match definition.targeting_type:
		SkillDefinition.TargetingType.LINE, SkillDefinition.TargetingType.CONE:
			return _project(GroundSpace.direction(target.direction, target.ground_squash), target)
	var away: Vector2 = GroundSpace.to_ground(hurtbox.global_position - target.point, target.ground_squash)
	return _project(away.normalized() if not away.is_zero_approx() else GroundSpace.direction(target.direction, target.ground_squash), target)


## Hướng mặt đất (đơn vị) → vector màn hình nhân với lực knockback (map cũ: giữ nguyên).
static func _project(ground_dir: Vector2, target: SkillTarget) -> Vector2:
	return GroundSpace.to_screen(ground_dir, target.ground_squash)
