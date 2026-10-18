class_name HitSpark
extends Node2D
## Hiệu ứng trúng đòn placeholder: vòng tròn + 4 tia nở ra rồi mờ dần, tự giải phóng sau `lifetime`.
## Chỉ hiển thị (không collision, không damage). Mỗi lần trúng một node ngắn hạn; không có particle.

@export var lifetime: float = 0.22

var _color: Color = Color.WHITE
var _radius: float = 6.0
var _age: float = 0.0


static func spawn(parent: Node, world_position: Vector2, color: Color, radius: float) -> HitSpark:
	var spark: HitSpark = HitSpark.new()
	spark._color = color
	spark._radius = radius
	parent.add_child(spark)
	spark.global_position = world_position
	return spark


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_age / lifetime, 0.0, 1.0)
	var r: float = _radius * (0.5 + t)
	var c: Color = Color(_color, 1.0 - t)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, c, 1.5)
	for i: int in 4:
		var dir: Vector2 = Vector2.from_angle(PI / 4.0 + i * PI / 2.0)
		draw_line(dir * r * 0.6, dir * r * 1.4, c, 1.0)
