class_name InventoryWindow
extends Control
## Cửa sổ túi đồ (TASK M1, style tạm). Mở/đóng: `inventory_toggle` (I / Tab), đóng thêm bằng `ui_cancel` (Esc).
## Bảng túi (24 ô) + ô trang bị (Vũ khí, Mũ); mở rương thì hiện thêm bảng rương bên trái.
## Thao tác: kéo thả giữa các ô (túi ↔ túi, túi ↔ rương, túi ↔ trang bị); chuột phải = tách nửa stack;
## Shift+click = chuyển nhanh túi ↔ rương; nhấp đúp = trang bị / tháo; kéo ra ngoài cửa sổ = vứt xuống đất
## (`drop_requested`, World quyết định chỗ rơi). Tooltip: tên, loại, mô tả.
## Chỉ gọi public API của Inventory / EquipmentSlots; không tự tính luật trang bị.

signal opened
signal closed
## Người chơi kéo stack ra ngoài cửa sổ (stack đã được lấy khỏi túi/ô trang bị).
signal drop_requested(stack: ItemStack)
## Thông báo ngắn cho người chơi (vd. túi đầy, không trang bị được).
signal message(text: String)

const TOGGLE_ACTION: StringName = &"inventory_toggle"
const CLOSE_ACTION: StringName = &"ui_cancel"
const COLUMNS: int = 6
const CHEST_COLUMNS: int = 5
## Rời rương xa hơn khoảng này (px) thì bảng tự đóng.
const CHEST_MAX_DISTANCE: float = 80.0
const HINT: String = "Kéo thả: chuyển · Chuột phải: tách nửa · Shift+click: chuyển nhanh (rương) · Nhấp đúp: trang bị/tháo · Kéo ra ngoài: vứt · I / Tab / Esc: đóng"

## Cho phép vứt đồ xuống đất (World bật khi map có ItemPickupLayer).
var can_drop_to_ground: bool = false

var _database: ItemDatabase
var _bag: Inventory
var _equipment: EquipmentSlots
var _actor: Node2D
var _chest: Chest
var _bag_views: Array[ItemSlotView] = []
var _chest_views: Array[ItemSlotView] = []
var _equipment_views: Array[ItemSlotView] = []

var _bag_grid: GridContainer
var _equipment_row: HBoxContainer
var _drop_zone: Control
var _chest_panel: PanelContainer
var _chest_title: Label
var _chest_grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide()


## Gắn túi/trang bị của người chơi. `actor` dùng để đo khoảng cách tới rương đang mở.
func bind(bag: Inventory, equipment: EquipmentSlots, database: ItemDatabase, actor: Node2D) -> void:
	_bag = bag
	_equipment = equipment
	_database = database
	_actor = actor
	for i: int in _bag.get_size():
		var view: ItemSlotView = ItemSlotView.new()
		view.setup_inventory(self, _bag, i)
		_bag_grid.add_child(view)
		_bag_views.append(view)
	for slot: Array in [[&"weapon", "Vũ khí"], [&"head", "Mũ"]]:
		var view: ItemSlotView = ItemSlotView.new()
		view.setup_equipment(self, _equipment, slot[0], slot[1])
		_equipment_row.add_child(view)
		_equipment_views.append(view)
	_bag.changed.connect(_refresh)
	_equipment.changed.connect(_refresh)
	_equipment.equip_rejected.connect(func(_item_id: StringName, reason: String) -> void: message.emit(reason))
	_refresh()


func is_open() -> bool:
	return visible


func get_open_chest() -> Chest:
	return _chest


## Ô hiển thị (dùng cho kiểm thử / debug): túi, rương đang mở, ô trang bị.
func get_bag_view(index: int) -> ItemSlotView:
	return _bag_views[index] if index >= 0 and index < _bag_views.size() else null


func get_chest_view(index: int) -> ItemSlotView:
	return _chest_views[index] if index >= 0 and index < _chest_views.size() else null


func get_equipment_view(slot_name: StringName) -> ItemSlotView:
	for view: ItemSlotView in _equipment_views:
		if view.slot_name == slot_name:
			return view
	return null


## Làm mới mọi ô ngay (bình thường tự làm mới khi túi/rương/trang bị đổi).
func refresh_now() -> void:
	_refresh()


## Vứt nội dung một ô xuống đất như khi kéo ra ngoài cửa sổ. false nếu không vứt được.
func drop_slot_to_ground(view: ItemSlotView) -> bool:
	var data: Dictionary = {"slot_view": view}
	if not _can_drop_to_ground(Vector2.ZERO, data):
		return false
	_drop_to_ground(Vector2.ZERO, data)
	return true


func open() -> void:
	if visible or _bag == null:
		return
	show()
	_refresh()
	opened.emit()


func close() -> void:
	if not visible:
		return
	_set_chest(null)
	hide()
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Mở cửa sổ kèm bảng rương.
func open_chest(chest: Chest) -> void:
	_set_chest(chest)
	if visible:
		_refresh()
	else:
		open()


## Phím mở/đóng bắt trước GUI: Tab còn là phím chuyển focus, nút đang giữ focus sẽ nuốt mất nếu chờ _unhandled_input.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(CLOSE_ACTION):
		close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _chest == null:
		return
	if not is_instance_valid(_chest) or (_actor != null and _actor.global_position.distance_to(_chest.global_position) > CHEST_MAX_DISTANCE):
		close()


# --- Thao tác (ItemSlotView gọi) -----------------------------------------------------------------

func can_drop(from: ItemSlotView, to: ItemSlotView) -> bool:
	if from == null or to == null or from == to or from.get_slot_stack() == null:
		return false
	if not from.is_equipment_slot() and not to.is_equipment_slot():
		return true
	if from.is_equipment_slot() and to.is_equipment_slot():
		return false
	if to.is_equipment_slot():
		var item: ItemDefinition = _database.get_item(from.get_slot_stack().item_id)
		return from.inventory == _bag and item != null and item.equip_slot == to.slot_name
	# Ô trang bị → ô túi: ô trống hoặc món cùng loại ô (đổi chỗ).
	if to.inventory != _bag:
		return false
	var target: ItemStack = to.get_slot_stack()
	var target_item: ItemDefinition = _database.get_item(target.item_id) if target != null else null
	return target == null or (target_item != null and target_item.equip_slot == from.slot_name)


func drop_on_slot(from: ItemSlotView, to: ItemSlotView) -> void:
	if not can_drop(from, to):
		return
	if to.is_equipment_slot():
		_equipment.equip_from_inventory(from.index, to.slot_name)
	elif from.is_equipment_slot():
		if to.get_slot_stack() == null:
			_equipment.unequip_to_inventory(from.slot_name, to.index)
		else:
			_equipment.equip_from_inventory(to.index, from.slot_name)
	else:
		from.inventory.transfer_to(from.index, to.inventory, to.index)


## Chuột phải: tách nửa stack sang ô trống đầu tiên của cùng túi.
func split_slot(view: ItemSlotView) -> void:
	if view.is_equipment_slot() or view.get_slot_stack() == null:
		return
	if view.inventory.split_half(view.index) < 0 and view.get_slot_stack().count > 1:
		message.emit("Không còn ô trống để tách.")


## Shift+click: chuyển cả stack sang bảng bên kia (chỉ khi đang mở rương).
func quick_move(view: ItemSlotView) -> void:
	if _chest == null or view.is_equipment_slot() or view.get_slot_stack() == null:
		return
	var target: Inventory = _chest.get_inventory() if view.inventory == _bag else _bag
	if view.inventory.quick_transfer(view.index, target) == 0:
		message.emit("Không còn chỗ trống.")


## Nhấp đúp: trang bị món trong túi / tháo món đang mặc về túi.
func toggle_equip(view: ItemSlotView) -> void:
	if view.is_equipment_slot():
		if view.get_slot_stack() != null and not _equipment.unequip_to_inventory(view.slot_name):
			message.emit("Túi đầy, không tháo được.")
		return
	var stack: ItemStack = view.get_slot_stack()
	var item: ItemDefinition = _database.get_item(stack.item_id) if stack != null else null
	if view.inventory == _bag and item != null and item.is_equippable():
		_equipment.equip_from_inventory(view.index)


func _can_drop_to_ground(_at_position: Vector2, data: Variant) -> bool:
	var from: ItemSlotView = ItemSlotView._source_of(data)
	return can_drop_to_ground and from != null and from.get_slot_stack() != null


func _drop_to_ground(_at_position: Vector2, data: Variant) -> void:
	var from: ItemSlotView = ItemSlotView._source_of(data)
	if from == null:
		return
	var stack: ItemStack = from.get_slot_stack()
	if stack == null:
		return
	if from.is_equipment_slot():
		_equipment.set_slot(from.slot_name, null)
	else:
		stack = from.inventory.remove_at(from.index)
	drop_requested.emit(stack)


# --- Nội bộ --------------------------------------------------------------------------------------

func _set_chest(chest: Chest) -> void:
	if _chest == chest:
		return
	if _chest != null and is_instance_valid(_chest):
		_chest.set_open(false)
		_chest.get_inventory().changed.disconnect(_refresh)
	_chest = chest
	for view: ItemSlotView in _chest_views:
		view.queue_free()
	_chest_views.clear()
	_chest_panel.visible = _chest != null
	if _chest == null:
		return
	_chest.set_open(true)
	_chest.get_inventory().changed.connect(_refresh)
	_chest_title.text = _chest.get_interaction_name()
	for i: int in _chest.get_inventory().get_size():
		var view: ItemSlotView = ItemSlotView.new()
		view.setup_inventory(self, _chest.get_inventory(), i)
		_chest_grid.add_child(view)
		_chest_views.append(view)


func _refresh() -> void:
	if not visible:
		return
	for view: ItemSlotView in _bag_views + _chest_views + _equipment_views:
		view.refresh(_database)


func _build() -> void:
	# Vùng nền phủ cả màn hình: nhận thả đồ (vứt xuống đất) và chặn click xuống thế giới khi cửa sổ mở.
	_drop_zone = Control.new()
	_drop_zone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_drop_zone.set_drag_forwarding(Callable(), _can_drop_to_ground, _drop_to_ground)
	add_child(_drop_zone)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	_chest_panel = _make_panel()
	row.add_child(_chest_panel)
	var chest_box: VBoxContainer = _panel_box(_chest_panel)
	_chest_title = _make_label(chest_box, "Rương", 16)
	_chest_grid = _make_grid(chest_box, CHEST_COLUMNS)
	_chest_panel.hide()
	var bag_panel: PanelContainer = _make_panel()
	row.add_child(bag_panel)
	var bag_box: VBoxContainer = _panel_box(bag_panel)
	_make_label(bag_box, "Túi đồ", 16)
	_equipment_row = HBoxContainer.new()
	_equipment_row.add_theme_constant_override(&"separation", 6)
	bag_box.add_child(_equipment_row)
	_bag_grid = _make_grid(bag_box, COLUMNS)
	var hint: Label = _make_label(bag_box, HINT, 11)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = COLUMNS * (ItemSlotView.SIZE.x + 4)
	hint.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.8))


func _make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.45, 0.6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override(&"panel", style)
	return panel


func _panel_box(panel: PanelContainer) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	return box


func _make_grid(parent: Control, columns: int) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override(&"h_separation", 4)
	grid.add_theme_constant_override(&"v_separation", 4)
	parent.add_child(grid)
	return grid


func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	return label
