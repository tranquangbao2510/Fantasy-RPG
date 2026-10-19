class_name IsoActorAdapter
extends Node
## Cấu hình một actor placeholder (Player, enemy, bù nhìn) cho map isometric, lúc _ready, không sửa scene gốc:
## - Di chuyển: đặt `vertical_speed_scale` của actor (nếu có) — 0.5 = tốc độ đều trên mặt đất 2:1; mặc định 0.7
##   (VISUAL-02.2, chọn qua thử nghiệm: đi dọc nhanh hơn, đỡ "lê"). Chỉnh ở đây
##   (hoặc ô debug trên EnvironmentDebugHud lúc chạy) để thử cảm giác.
## - Combat: gọi set_ground_squash(GROUND_SQUASH) trên mọi node con có hàm này (đòn đánh, enemy AI, kỹ năng) →
##   tầm đánh/hitbox/đạn/vùng kỹ năng tính trên mặt phẳng đất, gốc dời về chân; Hurtbox đổi sang ellipse 2:1 tại chân.
## - Hiển thị: bóng ellipse 2:1 lệch nhẹ về dưới-phải; marker hướng nhìn nằm trên mặt đất.
## - Collision thân: ellipse dẹt 2:1.
## Hướng nhìn và đòn đánh vẫn theo con trỏ chuột trên màn hình.

@export var shadow: Polygon2D
@export var facing_pivot: Node2D
@export var body_shape: CollisionShape2D
@export var shadow_radius: float = 11.0
@export var body_radius: float = 7.0
## Bán kính (trên mặt đất) của vùng nhận đòn tại chân.
@export var hurtbox_radius: float = 10.0
## Hệ số vận tốc dọc áp cho actor (Player/Enemy.vertical_speed_scale). Mặc định 0.7 cho map isometric 2:1 (0.5 = đều tuyệt đối trên mặt đất).
@export var vertical_speed_scale: float = 0.7


func _ready() -> void:
	var actor: Node = get_parent()
	if &"vertical_speed_scale" in actor:
		actor.set(&"vertical_speed_scale", vertical_speed_scale)
	for node: Node in actor.find_children("*", "", true, false):
		if node.has_method(&"set_ground_squash"):
			node.call(&"set_ground_squash", IsoProjection.GROUND_SQUASH)
			# Hình học combat nằm trên mặt đất → gốc tại chân (scene gốc đặt ngang ngực cho map top-down).
			if node is Node2D and node.get_parent() == actor:
				(node as Node2D).position = Vector2.ZERO
		if node is Hurtbox:
			(node as Node2D).position = Vector2.ZERO
			for child: Node in node.get_children():
				var hurt_shape: CollisionShape2D = child as CollisionShape2D
				if hurt_shape != null:
					hurt_shape.shape = GroundSpace.polygon_shape(IsoProjection.ground_ellipse(Vector2.ZERO, hurtbox_radius, 12))
					hurt_shape.position = Vector2(0, -1)
	if actor.has_method(&"set_ground_squash"):
		actor.call(&"set_ground_squash", IsoProjection.GROUND_SQUASH)
	if shadow != null:
		shadow.polygon = IsoProjection.ground_ellipse(Vector2(2, 1), shadow_radius)
	if facing_pivot != null:
		# Hoãn tới sau _ready của actor: actor lấy tham chiếu FacingPivot theo đường dẫn trong _ready của nó.
		_move_marker_to_ground.call_deferred()
	if body_shape != null:
		var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
		shape.points = IsoProjection.ground_ellipse(Vector2.ZERO, body_radius, 10)
		body_shape.shape = shape
		body_shape.position = Vector2(0, -1)


func _move_marker_to_ground() -> void:
	var ground: Node2D = Node2D.new()
	ground.name = "GroundPlane"
	ground.scale = Vector2(1.0, IsoProjection.GROUND_SQUASH)
	var parent: Node = facing_pivot.get_parent()
	parent.add_child(ground)
	# Ngay sau bóng: marker nằm trên mặt đất, thân nhân vật vẽ đè lên.
	parent.move_child(ground, mini(1, parent.get_child_count() - 1))
	facing_pivot.reparent(ground, false)
	facing_pivot.position = Vector2.ZERO
