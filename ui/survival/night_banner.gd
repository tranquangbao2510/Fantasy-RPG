class_name NightBanner
extends Control
## Dòng chữ lớn báo mốc trời tối (TASK M4): "Trời sắp tối…" (DayNightLighting.dusk_warning), "Màn đêm buông xuống"
## (night_started). Hiện ở phần trên giữa màn hình, mờ vào → giữ → mờ ra. Chỉ hiển thị.

@export var fade_time: float = 0.5
@export var hold_time: float = 2.5

## Dòng gần nhất đã hiện (giữ lại sau khi mờ — test đọc).
var last_text: String = ""

var _label: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 96.0
	_label.offset_bottom = 150.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", 30)
	_label.add_theme_color_override(&"font_color", Color(0.85, 0.88, 1.0))
	_label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override(&"shadow_offset_y", 2)
	_label.modulate.a = 0.0
	add_child(_label)


func show_text(text: String) -> void:
	last_text = text
	_label.text = text
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, ^"modulate:a", 1.0, fade_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property(_label, ^"modulate:a", 0.0, fade_time)


## Chữ đang hiện ("" nếu đã mờ hết).
func get_text() -> String:
	return _label.text if _label.modulate.a > 0.0 or (_tween != null and _tween.is_running()) else ""
