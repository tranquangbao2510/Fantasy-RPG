class_name MenuUI
extends RefCounted
## Dựng UI menu dùng chung bằng code (TASK M6: màn hình tiêu đề, menu tạm dừng, ô save, cài đặt, hướng dẫn phím) — style tạm.
## Điều khiển: chuột + bàn phím (mũi tên chuyển focus giữa các nút — focus neighbor tự động của Godot; Enter = ui_accept).
## Tay cầm: các action ui_* của Godot đã có nút tay cầm mặc định, nên chỉ cần mỗi màn đặt focus vào một nút (focus_first).

const PANEL_COLOR: Color = Color(0.07, 0.08, 0.11, 0.94)
const BORDER_COLOR: Color = Color(0.85, 0.72, 0.45, 0.85)
const TITLE_COLOR: Color = Color(1, 0.88, 0.6)
const TEXT_COLOR: Color = Color(0.9, 0.9, 0.92)
const MUTED_COLOR: Color = Color(0.62, 0.64, 0.7)
const WARNING_COLOR: Color = Color(1, 0.55, 0.45)
const DIM_COLOR: Color = Color(0, 0, 0, 0.6)
const BUTTON_WIDTH: float = 280.0


static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var container: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	container.add_theme_stylebox_override(&"panel", style)
	container.custom_minimum_size = min_size
	return container


static func title(text: String, size: int = 26) -> Label:
	var result: Label = label(text, size, TITLE_COLOR)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return result


static func label(text: String, size: int = 15, color: Color = TEXT_COLOR) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.add_theme_font_size_override(&"font_size", size)
	result.add_theme_color_override(&"font_color", color)
	return result


static func button(text: String, on_pressed: Callable, min_width: float = BUTTON_WIDTH) -> Button:
	var result: Button = Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(min_width, 38)
	result.add_theme_font_size_override(&"font_size", 16)
	if on_pressed.is_valid():
		result.pressed.connect(on_pressed)
	return result


## Nền mờ phủ cả màn hình (chặn chuột xuống game) + CenterContainer; trả về CenterContainer để đặt khung vào.
static func modal_root(parent: Control) -> CenterContainer:
	parent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	return center


static func vbox(separation: int = 10) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", separation)
	return box


## Focus vào nút đầu tiên đang hiện + bật được (điều khiển bằng bàn phím / tay cầm).
static func focus_first(root: Node) -> void:
	var first: Button = first_button(root)
	if first != null and first.is_inside_tree():
		first.grab_focus()


static func first_button(root: Node) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var candidate: Button = node as Button
		if candidate.is_visible_in_tree() and not candidate.disabled and candidate.focus_mode != Control.FOCUS_NONE:
			return candidate
	return null


## Nút có chữ `text` dưới root (test / tiện ích).
static func find_button(root: Node, text: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


## "06:30" từ phút trong ngày (hoặc tổng phút).
static func format_clock(minute: float) -> String:
	var minute_of_day: int = posmod(int(minute), 1440)
	return "%02d:%02d" % [minute_of_day / 60, minute_of_day % 60]


## "1 giờ 05 phút" / "12 phút" / "45 giây".
static func format_playtime(seconds: float) -> String:
	var total: int = int(seconds)
	if total < 60:
		return "%d giây" % total
	var hours: int = total / 3600
	var minutes: int = (total % 3600) / 60
	return "%d giờ %02d phút" % [hours, minutes] if hours > 0 else "%d phút" % minutes


## "2026-10-21 17:50:12" → "21/10/2026 17:50".
static func format_saved_at(text: String) -> String:
	var parts: PackedStringArray = text.replace("T", " ").split(" ")
	if parts.size() < 2:
		return text
	var date: PackedStringArray = parts[0].split("-")
	if date.size() != 3:
		return text
	return "%s/%s/%s %s" % [date[2], date[1], date[0], parts[1].substr(0, 5)]
