class_name IsoActorAdapter
extends Node
## Chỉnh phần hiển thị của actor placeholder (Player, enemy) cho map isometric, lúc _ready, không sửa scene gốc:
## - Bóng đổ: ellipse 2:1 lệch nhẹ về dưới-phải (nguồn sáng trên-trái).
## - Marker hướng nhìn: đặt lên mặt phẳng đất (nén dọc 0.5) tại chân, vẫn xoay theo hướng màn hình như cũ.
## - Collision thân: ellipse dẹt 2:1 thay cho hình tròn (footprint đúng trên mặt đất iso).
## Không đổi logic di chuyển/combat; hướng nhìn và đòn đánh vẫn theo con trỏ chuột trên màn hình.

@export var shadow: Polygon2D
@export var facing_pivot: Node2D
@export var body_shape: CollisionShape2D
@export var shadow_radius: float = 11.0
@export var body_radius: float = 7.0


func _ready() -> void:
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
