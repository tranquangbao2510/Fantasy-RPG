class_name HitVignette
extends Control
## Viền đỏ quanh màn hình khi Player bị đánh trúng (TASK M4). Mức đậm theo tỉ lệ sát thương / max HP (tối thiểu
## `min_alpha`), mờ dần trong `fade_time` giây. Chỉ hiển thị; nối qua bind(health).

@export var color: Color = Color(0.85, 0.05, 0.05)
@export var min_alpha: float = 0.25
@export var max_alpha: float = 0.6
@export var fade_time: float = 0.6

var _alpha: float = 0.0
var _texture: GradientTexture2D


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 1))
	gradient.add_point(0.55, Color(1, 1, 1, 0))
	_texture = GradientTexture2D.new()
	_texture.gradient = gradient
	_texture.fill = GradientTexture2D.FILL_RADIAL
	_texture.fill_from = Vector2(0.5, 0.5)
	_texture.fill_to = Vector2(1.0, 0.5)
	_texture.width = 128
	_texture.height = 128
	set_process(false)


func bind(health: HealthComponent) -> void:
	health.damaged.connect(func(amount: int) -> void: flash(float(amount) / maxf(health.max_health, 1.0)))


## Nháy viền đỏ; `ratio` = sát thương / max HP.
func flash(ratio: float) -> void:
	_alpha = maxf(_alpha, clampf(min_alpha + ratio * 2.0, min_alpha, max_alpha))
	set_process(true)
	queue_redraw()


func get_alpha() -> float:
	return _alpha


func _process(delta: float) -> void:
	_alpha = maxf(0.0, _alpha - delta * max_alpha / maxf(fade_time, 0.01))
	if _alpha <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _alpha > 0.0:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false, Color(color.r, color.g, color.b, _alpha))
