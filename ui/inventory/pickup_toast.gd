class_name PickupToast
extends VBoxContainer
## Thông báo ngắn xếp chồng ở mép trái màn hình ("+3 Gỗ", "Túi đầy"). Mỗi dòng tự mờ dần sau `display_time` giây;
## tối đa `max_lines` dòng. Nhặt liên tiếp cùng item trong lúc dòng còn hiện thì cộng dồn vào dòng đó.

@export var display_time: float = 2.2
@export var max_lines: int = 5

const FADE_TIME: float = 0.4

var _lines: Dictionary[StringName, Label] = {}
var _amounts: Dictionary[StringName, int] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## "+amount Tên" — cộng dồn nếu dòng của item này còn hiện.
func show_pickup(item_id: StringName, display_name: String, amount: int) -> void:
	var label: Label = _lines.get(item_id)
	if label != null and is_instance_valid(label):
		_amounts[item_id] += amount
		label.text = "+%d %s" % [_amounts[item_id], display_name]
		_restart(label, item_id)
		return
	_amounts[item_id] = amount
	_lines[item_id] = _add_line("+%d %s" % [amount, display_name], Color(0.85, 1, 0.8), item_id)


func show_message(text: String, color: Color = Color(1, 0.75, 0.6)) -> void:
	_add_line(text, color, &"")


func get_lines() -> Array[String]:
	var result: Array[String] = []
	for child: Node in get_children():
		if child is Label and not child.is_queued_for_deletion():
			result.append((child as Label).text)
	return result


func _add_line(text: String, color: Color, item_id: StringName) -> Label:
	while get_child_count() >= max_lines:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	add_child(label)
	_restart(label, item_id)
	return label


func _restart(label: Label, item_id: StringName) -> void:
	label.modulate.a = 1.0
	if label.has_meta(&"tween"):
		(label.get_meta(&"tween") as Tween).kill()
	var tween: Tween = label.create_tween()
	tween.tween_interval(display_time)
	tween.tween_property(label, ^"modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(func() -> void:
		if item_id != &"" and _lines.get(item_id) == label:
			_lines.erase(item_id)
		label.queue_free())
	label.set_meta(&"tween", tween)
