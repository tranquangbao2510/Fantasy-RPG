class_name CraftingWindow
extends Control
## Cửa sổ chế tạo / nấu ăn (TASK M3; style tạm như túi đồ). Chỉ hiển thị + gọi logic Crafting / Campfire.
## - `craft_toggle` (C) mở/đóng chế độ Chế tạo: liệt kê công thức dùng được ở vị trí hiện tại (tay + trạm ở gần đang
##   hoạt động — Crafting.stations_near, làm mới khi đi lại). Nguyên liệu thiếu tô đỏ, nút "Chế tạo" bị khóa (tooltip =
##   lý do). Chế tạo tức thì.
## - Lửa trại: open_campfire(lửa) = chế độ Nấu — trạng thái lửa, nút thêm gỗ / cành, công thức lửa trại (khóa khi lửa tắt).
##   Đi xa quá `use_radius` × 1.5 → tự đóng.
## - `ui_cancel` (Esc) đóng. Khi mở: World chặn input combat (như túi đồ); di chuyển vẫn được.

signal opened
signal closed
## Thông báo ngắn cho người chơi (đã chế tạo, thiếu nguyên liệu, túi đầy...).
signal message(text: String)
signal crafted(recipe: RecipeDefinition)

const TOGGLE_ACTION: StringName = &"craft_toggle"
const CLOSE_ACTION: StringName = &"ui_cancel"
const MISSING_COLOR: String = "#ff6b5e"
const OK_COLOR: String = "#b9f5a8"
## Làm mới danh sách theo vị trí mỗi khoảng này (giây).
const REFRESH_INTERVAL: float = 0.25

var _book: RecipeBook
var _database: ItemDatabase
var _bag: Inventory
var _actor: Node2D
var _squash: float = 1.0
var _campfire: Campfire
var _stations: Array[int] = []
## recipe_id → {"button": Button, "label": RichTextLabel}
var _rows: Dictionary[StringName, Dictionary] = {}
var _refresh_left: float = 0.0

var _title: Label
var _hint: Label
var _status: Label
var _fuel_row: HBoxContainer
var _list: VBoxContainer
var _empty_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide()


## Gắn sổ công thức + túi người chơi. `squash`: tỉ lệ mặt đất của map (đo khoảng cách tới trạm).
func bind(book: RecipeBook, database: ItemDatabase, bag: Inventory, actor: Node2D, squash: float = 1.0) -> void:
	_book = book
	_database = database
	_bag = bag
	_actor = actor
	_squash = squash
	_bag.changed.connect(_refresh_states)


func is_open() -> bool:
	return visible


func get_campfire() -> Campfire:
	return _campfire


## Mở chế độ Chế tạo (mọi công thức dùng được ở vị trí hiện tại).
func open() -> void:
	_campfire = null
	_show()


## Mở chế độ Nấu tại lửa trại.
func open_campfire(campfire: Campfire) -> void:
	_campfire = campfire
	_show()


func close() -> void:
	if not visible:
		return
	_campfire = null
	hide()
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## Trạm đang dùng được (chế độ Nấu: lửa trại đang cháy).
func get_stations() -> Array[int]:
	return _stations.duplicate()


## Id các công thức đang hiện (theo thứ tự).
func get_recipe_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for recipe_id: StringName in _rows:
		ids.append(recipe_id)
	return ids


func get_craft_button(recipe_id: StringName) -> Button:
	return _rows[recipe_id]["button"] if _rows.has(recipe_id) else null


## Dòng nguyên liệu (BBCode: thiếu = màu đỏ).
func get_ingredient_text(recipe_id: StringName) -> String:
	return (_rows[recipe_id]["label"] as RichTextLabel).text if _rows.has(recipe_id) else ""


func get_fuel_button(item_id: StringName) -> Button:
	if _fuel_row == null:
		return null
	for child: Node in _fuel_row.get_children():
		if child.get_meta(&"fuel_item", &"") == item_id:
			return child as Button
	return null


## Chế tạo công thức (như bấm nút). "" nếu thành công.
func craft(recipe_id: StringName) -> String:
	var recipe: RecipeDefinition = _book.get_recipe(recipe_id) if _book != null else null
	_update_stations()
	var reason: String = Crafting.craft(recipe, _bag, _stations)
	if reason.is_empty():
		var item: ItemDefinition = _database.get_item(recipe.result_id)
		message.emit("Đã %s %s ×%d." % [_verb(recipe).to_lower(),
			item.display_name if item != null else String(recipe.result_id), recipe.result_count])
		crafted.emit(recipe)
	else:
		message.emit(reason)
	_rebuild()
	return reason


func add_fuel(item_id: StringName) -> String:
	if _campfire == null or not is_instance_valid(_campfire):
		return "Không có lửa trại"
	var was_lit: bool = _campfire.lit
	var reason: String = _campfire.add_fuel(item_id, _bag)
	var item: ItemDefinition = _database.get_item(item_id)
	if reason.is_empty():
		message.emit("%s %s — lửa còn %s." % ["Đã thêm" if was_lit else "Đã nhóm lửa bằng", item.display_name if item != null else String(item_id), _campfire.format_fuel()])
	else:
		message.emit(reason)
	_rebuild()
	return reason


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION) and not event.is_echo() and _book != null:
		# Đang ngủ / chết (màn hình mờ, điều khiển bị khóa): không mở.
		if not visible and _actor != null and _actor.has_method(&"is_control_locked") and _actor.call(&"is_control_locked"):
			return
		toggle()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(CLOSE_ACTION):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if _campfire != null:
		if not is_instance_valid(_campfire) or _actor == null or GroundSpace.length(_actor.global_position - _campfire.global_position, _squash) > _campfire.use_radius * 1.5:
			close()
			return
		_update_status()
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		var before: Array[int] = _stations.duplicate()
		_update_stations()
		if before != _stations:
			_rebuild()
		else:
			_refresh_states()


func _show() -> void:
	if _book == null:
		return
	_update_stations()
	_rebuild()
	if _hint != null:
		_hint.text = get_hint_text()
	if not visible:
		show()
		opened.emit()


func _update_stations() -> void:
	if _campfire != null:
		_stations.clear()
		if is_instance_valid(_campfire) and _campfire.is_station_active():
			_stations.append(RecipeDefinition.Station.CAMPFIRE)
	else:
		_stations = Crafting.stations_near(_actor, _squash)


## Dựng lại danh sách công thức theo chế độ + trạm hiện tại.
func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	var recipes: Array[RecipeDefinition]
	if _campfire != null:
		# Chế độ Nấu: luôn liệt kê công thức lửa trại (khóa khi lửa tắt).
		recipes = _book.recipes_for([RecipeDefinition.Station.CAMPFIRE], RecipeDefinition.Station.CAMPFIRE)
	else:
		recipes = _book.recipes_for(_stations)
	for recipe: RecipeDefinition in recipes:
		_add_row(recipe)
	_empty_label.visible = recipes.is_empty()
	_title.text = "Lửa trại — Nấu ăn" if _campfire != null else "Chế tạo"
	_fuel_row.visible = _campfire != null
	if _campfire != null:
		_build_fuel_buttons()
		_update_status()
	else:
		var names: Array[String] = []
		for station: int in _stations:
			names.append(RecipeDefinition.STATION_NAMES[station])
		_status.text = "Trạm ở gần: %s" % (", ".join(names) if not names.is_empty() else "không có (chỉ chế tạo bằng tay)")
	_refresh_states()


func _add_row(recipe: RecipeDefinition) -> void:
	var item: ItemDefinition = _database.get_item(recipe.result_id)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	var icon: TextureRect = TextureRect.new()
	icon.texture = item.icon if item != null else null
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var text_box: VBoxContainer = VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override(&"separation", 0)
	row.add_child(text_box)
	var name_label: Label = Label.new()
	name_label.text = "%s ×%d%s" % [item.display_name if item != null else String(recipe.result_id), recipe.result_count,
		"" if recipe.station == RecipeDefinition.Station.NONE else "  [%s]" % recipe.get_station_name()]
	name_label.add_theme_font_size_override(&"font_size", 14)
	text_box.add_child(name_label)
	var ingredients: RichTextLabel = RichTextLabel.new()
	ingredients.bbcode_enabled = true
	ingredients.fit_content = true
	ingredients.scroll_active = false
	ingredients.autowrap_mode = TextServer.AUTOWRAP_OFF
	ingredients.custom_minimum_size = Vector2(300, 0)
	ingredients.add_theme_font_size_override(&"normal_font_size", 12)
	ingredients.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(ingredients)
	var button: Button = Button.new()
	button.text = _verb(recipe)
	button.custom_minimum_size = Vector2(84, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(craft.bind(recipe.id))
	row.add_child(button)
	_list.add_child(row)
	_rows[recipe.id] = {"button": button, "label": ingredients, "recipe": recipe}


## Cập nhật màu nguyên liệu + trạng thái nút (túi đổi / trạm đổi).
func _refresh_states() -> void:
	if not visible and _rows.is_empty():
		return
	for recipe_id: StringName in _rows:
		var row: Dictionary = _rows[recipe_id]
		var recipe: RecipeDefinition = row["recipe"]
		var parts: Array[String] = []
		for item_id: StringName in recipe.ingredients:
			var item: ItemDefinition = _database.get_item(item_id)
			var have: int = _bag.count_of(item_id)
			var need: int = recipe.ingredients[item_id]
			parts.append("[color=%s]%s %d/%d[/color]" % [OK_COLOR if have >= need else MISSING_COLOR,
				item.display_name if item != null else String(item_id), have, need])
		(row["label"] as RichTextLabel).text = " · ".join(parts)
		var reason: String = Crafting.get_block_reason(recipe, _bag, _stations)
		var button: Button = row["button"]
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason


func _build_fuel_buttons() -> void:
	for child: Node in _fuel_row.get_children():
		_fuel_row.remove_child(child)
		child.queue_free()
	for item_id: StringName in _campfire.fuel_values:
		var item: ItemDefinition = _database.get_item(item_id)
		var button: Button = Button.new()
		var minutes: int = roundi(_campfire.fuel_values[item_id])
		button.text = "Thêm %s (+%s)" % [item.display_name if item != null else String(item_id),
			"%d giờ" % (minutes / 60) if minutes % 60 == 0 else "%d phút" % minutes]
		button.focus_mode = Control.FOCUS_NONE
		button.set_meta(&"fuel_item", item_id)
		button.pressed.connect(add_fuel.bind(item_id))
		_fuel_row.add_child(button)


func _update_status() -> void:
	if _campfire == null or not is_instance_valid(_campfire):
		return
	_status.text = "Đang cháy — còn %s" % _campfire.format_fuel() if _campfire.lit else "Lửa đã tắt — thêm gỗ hoặc cành để nhóm lại"
	for child: Node in _fuel_row.get_children():
		var button: Button = child as Button
		var reason: String = _campfire.get_fuel_block_reason(button.get_meta(&"fuel_item"), _bag)
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason


func _build() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color(0.45, 0.45, 0.6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 16)
	box.add_child(_title)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 12)
	_status.add_theme_color_override(&"font_color", Color(0.85, 0.82, 0.7))
	box.add_child(_status)
	_fuel_row = HBoxContainer.new()
	_fuel_row.add_theme_constant_override(&"separation", 6)
	box.add_child(_fuel_row)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 4)
	box.add_child(_list)
	_empty_label = Label.new()
	_empty_label.text = "Không có công thức nào dùng được ở đây."
	_empty_label.add_theme_font_size_override(&"font_size", 12)
	box.add_child(_empty_label)
	var hint: Label = Label.new()
	_hint = hint
	hint.text = get_hint_text()
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.8))
	box.add_child(hint)


## Động từ trên nút / thông báo: Nấu (lửa trại), Xay (cối đá — TASK M5), Chế tạo.
static func _verb(recipe: RecipeDefinition) -> String:
	match recipe.station:
		RecipeDefinition.Station.CAMPFIRE:
			return "Nấu"
		RecipeDefinition.Station.MILL:
			return "Xay"
	return "Chế tạo"


## Gợi ý cuối cửa sổ; tên phím đọc từ InputMap (TASK M6).
func get_hint_text() -> String:
	return "%s / %s: đóng · Nguyên liệu đỏ = còn thiếu · Bàn chế tạo / lửa trại: đứng gần để dùng công thức của trạm" % [
		InputHint.action_text(TOGGLE_ACTION), InputHint.action_text(InputActions.PAUSE_ACTION)]
