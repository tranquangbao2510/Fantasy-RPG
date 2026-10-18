class_name AmbientDrift
extends Node2D
## Chuyển động môi trường nhẹ cho sương, tia nắng, tán lá foreground: dao động vị trí và độ trong suốt theo sin.
## Chỉ hiển thị; mỗi node một phase khác nhau (theo vị trí) để không đồng bộ.

@export var amplitude: Vector2 = Vector2(24, 0)
@export var period: float = 14.0
@export var alpha_range: Vector2 = Vector2(1.0, 1.0)

var _origin: Vector2
var _time: float = 0.0


func _ready() -> void:
	_origin = position
	_time = fposmod(position.x * 0.013 + position.y * 0.007, period)


func _process(delta: float) -> void:
	_time += delta
	var phase: float = TAU * _time / period
	position = _origin + Vector2(amplitude.x * sin(phase), amplitude.y * sin(phase * 0.7 + 1.3))
	modulate.a = lerpf(alpha_range.x, alpha_range.y, sin(phase * 0.5) * 0.5 + 0.5)
