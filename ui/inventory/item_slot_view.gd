class_name ItemSlotView
extends Panel
## Một ô trong cửa sổ túi đồ: ô của Inventory (`inventory` + `index`) hoặc ô trang bị (`equipment` + `slot_name`).
## Chỉ hiển thị + chuyển thao tác chuột cho InventoryWindow (kéo thả, chuột phải → menu, Shift+click, nhấp đúp, rê chuột);
## không tự sửa dữ liệu.

const SIZE: Vector2 = Vector2(46, 46)

var window: InventoryWindow
var inventory: Inventory
var index: int = -1
var equipment: EquipmentSlots
var slot_name: StringName = &""

var _icon: TextureRect
var _count: Label
var _placeholder: Label
var _style: StyleBoxFlat
## Thanh độ bền / thời gian cháy (TASK M3) ở đáy ô.
var _wear_back: ColorRect
var _wear_bar: ColorRect


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.14, 0.14, 0.2, 0.95)
	_style.set_border_width_all(1)
	_style.border_color = Color(0.4, 0.4, 0.52)
	_style.set_corner_radius_all(3)
	add_theme_stylebox_override(&"panel", _style)
	_placeholder = _add_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, 10, Color(0.6, 0.6, 0.7))
	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_icon)
	_count = _add_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, 13, Color.WHITE)
	_count.add_theme_constant_override(&"outline_size", 4)
	_count.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_wear_back = ColorRect.new()
	_wear_back.color = Color(0, 0, 0, 0.7)
	_wear_back.position = Vector2(5, SIZE.y - 7)
	_wear_back.size = Vector2(SIZE.x - 10, 3)
	_wear_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wear_back)
	_wear_bar = ColorRect.new()
	_wear_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wear_back.add_child(_wear_bar)
	_wear_back.hide()


func setup_inventory(owner_window: InventoryWindow, source: Inventory, slot: int) -> void:
	window = owner_window
	inventory = source
	index = slot


func setup_equipment(owner_window: InventoryWindow, source: EquipmentSlots, name_of_slot: StringName, label: String) -> void:
	window = owner_window
	equipment = source
	slot_name = name_of_slot
	_placeholder.text = label


func is_equipment_slot() -> bool:
	return equipment != null


func get_slot_stack() -> ItemStack:
	if equipment != null:
		return equipment.get_stack(slot_name)
	return inventory.get_stack(index) if inventory != null else null


func refresh(database: ItemDatabase) -> void:
	var stack: ItemStack = get_slot_stack()
	var item: ItemDefinition = database.get_item(stack.item_id) if stack != null and database != null else null
	_icon.texture = item.icon if item != null else null
	_count.text = str(stack.count) if stack != null and stack.count > 1 else ""
	_placeholder.visible = stack == null
	tooltip_text = "%s\n[%s]\n%s" % [item.display_name, item.get_category_name(), item.description] if item != null else ""
	_wear_back.visible = item != null and item.has_wear()
	if _wear_back.visible:
		tooltip_text += "\n" + item.describe_wear(stack)
		var ratio: float = item.wear_ratio(stack)
		_wear_bar.size = Vector2(_wear_back.size.x * ratio, _wear_back.size.y)
		_wear_bar.color = Color(0.4, 0.9, 0.4).lerp(Color(0.95, 0.3, 0.25), 1.0 - ratio)


func set_highlight(enabled: bool) -> void:
	_style.border_color = Color(1, 0.85, 0.4) if enabled else Color(0.4, 0.4, 0.52)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var stack: ItemStack = get_slot_stack()
	if stack == null or window == null:
		return null
	var preview: TextureRect = TextureRect.new()
	preview.texture = _icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = SIZE * 0.8
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	return {"slot_view": self}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return window != null and window.can_drop(_source_of(data), self)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	window.drop_on_slot(_source_of(data), self)


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or window == null:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT:
		window.open_context_menu(self)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_LEFT and button.double_click:
		window.primary_action(self)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_LEFT and button.shift_pressed:
		window.quick_move(self)
		accept_event()


static func _source_of(data: Variant) -> ItemSlotView:
	return (data as Dictionary).get("slot_view") as ItemSlotView if data is Dictionary else null


func _add_label(horizontal: HorizontalAlignment, vertical: VerticalAlignment, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	add_child(label)
	return label


func _on_hover_changed(hovered: bool) -> void:
	if window != null:
		window.set_hovered(self, hovered)
