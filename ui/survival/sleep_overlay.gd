class_name SleepOverlay
extends Control
## Màn hình mờ khi ngủ / ngất / hồi sinh (TASK M2) + dòng chữ lớn ("Ngày 3"). Các hàm có thể await.

var _shade: ColorRect
var _title: Label
## Dòng chữ lớn gần nhất đã hiện (giữ lại sau khi mờ đi — UI khác / test đọc).
var last_title: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_title = Label.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 34)
	_title.modulate.a = 0.0
	add_child(_title)


func is_dark() -> bool:
	return _shade.color.a > 0.5


func get_title() -> String:
	return _title.text if _title.modulate.a > 0.0 else ""


func fade_out(duration: float) -> void:
	await _tween_alpha(_shade, 1.0, duration)


func fade_in(duration: float) -> void:
	_title.modulate.a = 0.0
	await _tween_alpha(_shade, 0.0, duration)


## Hiện chữ giữa màn hình trong `duration` giây (giữ nguyên khi đã tối).
func show_title(text: String, duration: float) -> void:
	_title.text = text
	last_title = text
	_title.modulate.a = 1.0
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout


func _tween_alpha(item: CanvasItem, alpha: float, duration: float) -> void:
	if duration <= 0.0:
		if item == _shade:
			_shade.color.a = alpha
		return
	var tween: Tween = create_tween()
	tween.tween_property(_shade, ^"color:a", alpha, duration)
	await tween.finished
