class_name DebugKeysPanel
extends PanelContainer
## Bảng phím debug (TASK M6): liệt kê mọi phím debug (DebugKeys.ENTRIES) với phím hiện tại trong InputMap. World bật / tắt
## bằng F12 (`debug_panel`) — chỉ ở bản debug; bản release không tạo bảng này. Bật bảng cũng hiện các bảng thông tin debug
## khác của map (group `debug_hud`, vd. EnvironmentDebugHud), tắt thì ẩn.

const HUD_GROUP: StringName = &"debug_hud"

var _label: Label


func _init() -> void:
	name = "DebugKeysPanel"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.88)
	style.border_color = Color(1, 0.6, 0.3, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	add_theme_stylebox_override(&"panel", style)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 13)
	add_child(_label)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	position = Vector2(get_viewport_rect().size.x - 420, 150)
	set_open(false)


func is_open() -> bool:
	return visible


func toggle() -> void:
	set_open(not visible)


func set_open(open: bool) -> void:
	_label.text = get_text()
	visible = open
	for node: Node in get_tree().get_nodes_in_group(HUD_GROUP):
		if node is CanvasItem:
			(node as CanvasItem).visible = open


static func get_text() -> String:
	var lines: PackedStringArray = PackedStringArray(["Phím debug (chỉ bản debug)"])
	for entry: Array in DebugKeys.ENTRIES:
		lines.append("%-8s %s" % [InputHint.all_text(entry[0]), entry[1]])
	return "\n".join(lines)
