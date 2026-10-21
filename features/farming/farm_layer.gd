class_name FarmLayer
extends Node2D
## Node cha của mọi vùng ruộng (FarmField) trong một map (TASK M5; trong cây Y-sort của EntityContainer, như
## ResourceNodeLayer). Một node / map; vùng ruộng là con.
## - Đếm ngày: cây lớn theo NGÀY GAME, không theo vị trí người chơi. Mỗi lần đồng hồ vượt qua `growth_minute` (6:00) của
##   một ngày → advance_day(ngày) cho mọi ô (FarmPlot). Nghe GameClock.minute_changed nên ngủ / ngất (nhảy giờ tới 6:00)
##   tính như qua đêm bình thường. `last_tick` (lần 6:00 cuối đã xử lý) được lưu → tải save / quay lại map sau khi thời
##   gian đã trôi ở nơi khác (đồng hồ là global) thì bù đủ các ngày đã qua (catch_up).
## - Thời tiết: chưa có. Hook `rain_hook: Callable(day: int) -> bool` (true = hôm đó mưa → coi như đã tưới).
## - Gieo hạt: nhiều loại hạt trong túi → phát `seed_choice_requested` (World mở menu chọn) và nhớ lựa chọn cho lần sau.
## - Thu hoạch: đồ vào túi người chơi, phần không vừa rơi xuống đất cạnh người chơi (`pickup_layer`).
## - Debug (build debug): `debug_crop_grow` (F6) — cây ở ô dưới con trỏ chuột lớn thêm 1 giai đoạn; `debug_farm_water`
##   (F11) — tưới hết ruộng.
## - Save (group `saveable`, theo map, id `farms`): {version, last_tick, fields: {field_id: {plots: {"c,r": trạng thái}}}} —
##   chỉ lưu ô khác cỏ (xem FarmPlot.save_plot_state).

signal crop_harvested(plot: FarmPlot, crop: CropDefinition, stacks: Array[ItemStack])
## Nhiều loại hạt trong túi: World hỏi người chơi chọn rồi gọi choose_seed().
signal seed_choice_requested(plot: FarmPlot, seed_ids: Array[StringName])
## Sau mỗi lần xử lý một ngày (6:00) — test / HUD.
signal day_processed(day: int)

const STATE_VERSION: int = 1

@export var clock: GameClock
@export var crop_book: CropBook
@export var pickup_layer: ItemPickupLayer
@export var save_id: String = "farms"
## Phút trong ngày cây lớn (6:00).
@export var growth_minute: int = 360
## Cây chưa chín khô liên tục bao nhiêu ngày thì héo chết.
@export var dry_days_to_die: int = 3
## Đất cày bỏ trống (không gieo) bao nhiêu ngày thì về cỏ.
@export var fallow_days_to_grass: int = 3

## Hook thời tiết (chưa dùng): Callable(day: int) -> bool.
var rain_hook: Callable
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Chỉ số lần 6:00 cuối đã xử lý (0 = 6:00 ngày 1).
var last_tick: int = 0

var _selected_seed: StringName = &""
var _shown_day: int = 0
var _mouse_world: Vector2 = Vector2.INF


func _ready() -> void:
	y_sort_enabled = true
	rng.randomize()
	if crop_book != null and pickup_layer != null and pickup_layer.database != null:
		for error: String in crop_book.get_validation_errors(pickup_layer.database):
			push_error("[FarmLayer] CropBook: %s" % error)
	last_tick = _current_tick()
	_shown_day = get_day()
	if clock != null:
		clock.minute_changed.connect(_on_minute_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse_world = (make_input_local(event) as InputEventMouse).position
		_mouse_world = to_global(_mouse_world)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(&"debug_crop_grow"):
		var plot: FarmPlot = plot_at(_mouse_world if _mouse_world != Vector2.INF else get_global_mouse_position())
		if plot != null:
			plot.debug_grow_stage()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"debug_farm_water"):
		water_all()
		get_viewport().set_input_as_handled()


func get_day() -> int:
	return clock.get_day() if clock != null else 1


func get_fields() -> Array[FarmField]:
	var result: Array[FarmField] = []
	for child: Node in get_children():
		if child is FarmField:
			result.append(child as FarmField)
	return result


func find_field(field_id: String) -> FarmField:
	for field: FarmField in get_fields():
		if field.field_id == field_id:
			return field
	return null


func get_plots() -> Array[FarmPlot]:
	var result: Array[FarmPlot] = []
	for field: FarmField in get_fields():
		result.append_array(field.get_plots())
	return result


## Ô ruộng chứa điểm world (null nếu ngoài mọi vùng ruộng).
func plot_at(world_point: Vector2) -> FarmPlot:
	for field: FarmField in get_fields():
		var plot: FarmPlot = field.plot_at(world_point)
		if plot != null:
			return plot
	return null


## Debug: tưới mọi ô đã gieo.
func water_all() -> int:
	var count: int = 0
	for plot: FarmPlot in get_plots():
		if plot.has_crop() and not plot.is_wet():
			plot.water_now()
			count += 1
	return count


# --- Gieo hạt -----------------------------------------------------------------------------------

## Các loại hạt gieo được có trong túi actor (theo thứ tự ô túi, không trùng).
func get_seed_options(actor: Node2D) -> Array[StringName]:
	var result: Array[StringName] = []
	var inventory: Inventory = actor.call(&"get_inventory") as Inventory if actor != null and actor.has_method(&"get_inventory") else null
	if inventory == null or crop_book == null:
		return result
	for i: int in inventory.get_size():
		var stack: ItemStack = inventory.get_stack(i)
		if stack != null and not result.has(stack.item_id) and crop_book.find_by_seed(stack.item_id) != null:
			result.append(stack.item_id)
	return result


## Hạt sẽ gieo khi nhấn E (&"" nếu cần chọn hoặc không có hạt).
func get_seed_choice(actor: Node2D) -> StringName:
	var options: Array[StringName] = get_seed_options(actor)
	if options.has(_selected_seed):
		return _selected_seed
	return options[0] if options.size() == 1 else &""


## E trên đất cày trống: gieo hạt đã chọn / loại duy nhất; nhiều loại → hỏi chọn.
func request_plant(plot: FarmPlot, actor: Node2D) -> String:
	var options: Array[StringName] = get_seed_options(actor)
	if options.is_empty():
		return "Cần hạt giống để gieo."
	var seed_id: StringName = get_seed_choice(actor)
	if seed_id == &"":
		seed_choice_requested.emit(plot, options)
		return "Chọn hạt để gieo."
	return choose_seed(plot, actor, seed_id)


## Gieo `seed_id` vào ô và nhớ lựa chọn cho các lần E sau.
func choose_seed(plot: FarmPlot, actor: Node2D, seed_id: StringName) -> String:
	if plot == null or not is_instance_valid(plot):
		return ""
	_selected_seed = seed_id
	var reason: String = plot.plant(actor, seed_id)
	if not reason.is_empty():
		return reason
	return "Đã gieo %s." % plot.crop.display_name


## Cho đồ vào túi actor; phần không vừa rơi xuống đất cạnh actor. Trả về "+3 Lúa mì, +1 Hạt lúa mì".
func give(actor: Node2D, stacks: Array[ItemStack]) -> String:
	var inventory: Inventory = actor.call(&"get_inventory") as Inventory if actor != null and actor.has_method(&"get_inventory") else null
	var parts: Array[String] = []
	var spilled: bool = false
	for stack: ItemStack in stacks:
		var left: int = inventory.add_stack(stack) if inventory != null else stack.count
		if left > 0 and pickup_layer != null and actor != null:
			var agent: ElevationAgent = ElevationAgent.find_for(actor)
			var offset: Vector2 = Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(4.0, 8.0))
			pickup_layer.spawn_drop(ItemStack.new(stack.item_id, left, stack.data), actor.global_position + offset,
				agent.get_tier() if agent != null else -1)
			spilled = true
		var item: ItemDefinition = inventory.database.get_item(stack.item_id) if inventory != null and inventory.database != null else null
		parts.append("+%d %s" % [stack.count, item.display_name if item != null else String(stack.item_id)])
	return ", ".join(parts) + (" (túi đầy — phần thừa rơi xuống đất)" if spilled else "")


# --- Qua ngày ------------------------------------------------------------------------------------

## Xử lý mọi lần 6:00 chưa xử lý tới thời điểm hiện tại của đồng hồ.
func catch_up() -> void:
	var current: int = _current_tick()
	while last_tick < current:
		last_tick += 1
		_process_day(last_tick + 1)
	_refresh_day()


func _current_tick() -> int:
	if clock == null:
		return 0
	return floori((clock.total_minutes - growth_minute) / GameClock.MINUTES_PER_DAY)


func _process_day(day: int) -> void:
	var rained: bool = rain_hook.is_valid() and bool(rain_hook.call(day - 1))
	for plot: FarmPlot in get_plots():
		if plot.advance_day(day, dry_days_to_die, fallow_days_to_grass, rained):
			plot.queue_redraw()
			plot.changed.emit(plot)
	day_processed.emit(day)


func _on_minute_changed(_day: int, _minute: int) -> void:
	catch_up()


## Sang ngày mới: đất ướt hôm qua hiện thành khô.
func _refresh_day() -> void:
	var day: int = get_day()
	if day == _shown_day:
		return
	_shown_day = day
	for field: FarmField in get_fields():
		field.refresh_soil()


# --- Save ----------------------------------------------------------------------------------------

func get_save_id() -> String:
	return save_id


func save_state() -> Dictionary:
	var fields: Dictionary = {}
	for field: FarmField in get_fields():
		var plots: Dictionary = {}
		for plot: FarmPlot in field.get_plots():
			var state: Dictionary = plot.save_plot_state()
			if not state.is_empty():
				plots["%d,%d" % [plot.cell.x, plot.cell.y]] = state
		fields[field.field_id] = {"plots": plots}
	return {"version": STATE_VERSION, "last_tick": last_tick, "fields": fields}


func load_state(state: Dictionary) -> void:
	var fields: Dictionary = state.get("fields", {}) if state.get("fields") is Dictionary else {}
	for field: FarmField in get_fields():
		var saved: Variant = fields.get(field.field_id, {})
		var plots: Dictionary = (saved as Dictionary).get("plots", {}) if saved is Dictionary and (saved as Dictionary).get("plots") is Dictionary else {}
		for plot: FarmPlot in field.get_plots():
			var plot_state: Variant = plots.get("%d,%d" % [plot.cell.x, plot.cell.y], {})
			plot.load_plot_state(plot_state if plot_state is Dictionary else {}, crop_book)
	var saved_tick: Variant = state.get("last_tick")
	# Save chưa có last_tick (migration v4 → v5): coi như đã xử lý tới hiện tại.
	last_tick = int(saved_tick) if (saved_tick is int or saved_tick is float) else _current_tick()
	_shown_day = 0
	# Đồng hồ có thể được nạp trước hoặc sau layer: bù ngày ngay với giờ hiện tại, đồng hồ đổi sau đó thì minute_changed bù tiếp.
	catch_up()
