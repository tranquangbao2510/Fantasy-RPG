class_name DamageNumbers
extends Control
## Số sát thương / chữ nổi trên màn hình. Neo vào một vị trí world và đổi sang tọa độ màn hình
## mỗi frame bằng canvas transform của viewport, nên đúng vị trí ở mọi mức zoom mà chữ không bị phóng to.

class Entry:
	var label: Label
	var world_position: Vector2
	var age: float = 0.0

@export var lifetime: float = 0.7
## Quãng bay lên (px màn hình) trong suốt lifetime.
@export var rise: float = 28.0

var _entries: Array[Entry] = []


func spawn(world_position: Vector2, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_constant_override(&"outline_size", 4)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var entry: Entry = Entry.new()
	entry.label = label
	entry.world_position = world_position
	_entries.append(entry)
	_place(entry, get_viewport().get_canvas_transform())


func get_active_count() -> int:
	return _entries.size()


func _process(delta: float) -> void:
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	for i: int in range(_entries.size() - 1, -1, -1):
		var entry: Entry = _entries[i]
		entry.age += delta
		if entry.age >= lifetime:
			entry.label.queue_free()
			_entries.remove_at(i)
			continue
		_place(entry, canvas)


func _place(entry: Entry, canvas: Transform2D) -> void:
	var t: float = entry.age / lifetime
	var screen: Vector2 = canvas * entry.world_position
	entry.label.position = screen - entry.label.size / 2.0 + Vector2(0.0, -rise * t)
	entry.label.modulate.a = 1.0 - t * t
