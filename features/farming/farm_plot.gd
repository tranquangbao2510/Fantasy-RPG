class_name FarmPlot
extends Interactable
## Một ô ruộng (TASK M5) — con của FarmField, do FarmField tạo lúc chạy (không đặt tay trong scene). Origin = tâm ô.
## Trạng thái (runtime, lưu qua FarmLayer): cỏ / đất cày; cây đang trồng (CropDefinition) + ngày tuổi; ngày được tưới gần
## nhất; số ngày khô liên tục; số ngày bỏ trống (đất cày chưa gieo).
## E (InteractionDetector), theo thứ tự ưu tiên:
##   1. cây chín → thu hoạch (đồ vào túi; túi đầy → rơi xuống đất cạnh người chơi);
##   2. cỏ + cầm cuốc đất (tool_type `hoe`) ở tay chính → cày (−1 độ bền);
##   3. có cây chưa chín + cầm bình tưới (`watering_can`) còn nước → tưới (−1 nước);
##   4. đất cày trống + có hạt trong túi → gieo (một loại hạt → gieo luôn; nhiều loại → FarmLayer hỏi chọn, nhớ lựa chọn);
##   5. cây đang lớn, không cầm bình tưới → báo trạng thái (giai đoạn, ướt / khô).
##   Ô cỏ chỉ là mục tiêu tương tác khi cầm cuốc đất, đất trống chỉ khi có hạt (can_interact).
## Luật qua ngày (FarmLayer gọi advance_day lúc 6:00): xem advance_day().
## Hình: cây vẽ ở đây (_draw, Y-sort cùng Player); đất (cày / ướt / khô) do FarmField vẽ ở lớp dưới.

## Trạng thái đổi (vẽ lại đất, cập nhật lời nhắc).
signal changed(plot: FarmPlot)

const HOE: StringName = &"hoe"
const WATERING_CAN: StringName = &"watering_can"

## Toạ độ ô trong vùng ruộng (cột, hàng).
var cell: Vector2i = Vector2i.ZERO
var tilled: bool = false
var crop: CropDefinition
## Ngày tuổi của cây (số lần đã lớn).
var age: int = 0
## Ngày game được tưới gần nhất (0 = chưa). Ướt = tưới trong ngày hôm nay.
var watered_day: int = 0
## Số lần qua 6:00 liên tục mà hôm trước không được tưới (cây chưa chín).
var dry_days: int = 0
## Số lần qua 6:00 đất cày bỏ trống (chưa gieo).
var fallow_days: int = 0

var _actor: Node2D


func _init() -> void:
	collision_layer = 1 << 2
	collision_mask = 0
	monitoring = false
	interaction_name = "Ô ruộng"


func _ready() -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)


func get_field() -> FarmField:
	return get_parent() as FarmField


func has_crop() -> bool:
	return crop != null


func get_stage() -> int:
	return crop.stage_for_age(age) if crop != null else -1


func is_mature() -> bool:
	return crop != null and age >= crop.get_mature_age()


## Đất ướt (được tưới trong ngày game hiện tại).
func is_wet() -> bool:
	return tilled and watered_day > 0 and watered_day == _today()


func get_interaction_name() -> String:
	return crop.display_name if crop != null else ("Đất đã cày" if tilled else "Ô ruộng")


## Ô cỏ chỉ là mục tiêu khi cầm cuốc đất, đất cày trống chỉ khi có hạt trong túi → đi ngang ruộng không "giành" phím E
## của rương / giường / bàn ở cạnh. Ô có cây luôn là mục tiêu (xem trạng thái, tưới, thu).
func can_interact(actor: Node2D) -> bool:
	_actor = actor
	if not interaction_enabled:
		return false
	if crop != null:
		return true
	if not tilled:
		var tool: ItemDefinition = _tool_of(actor)
		return tool != null and tool.tool_type == HOE
	var layer: FarmLayer = get_field().get_layer() if get_field() != null else null
	return layer != null and not layer.get_seed_options(actor).is_empty()


func get_interaction_prompt() -> String:
	if is_mature():
		return "Thu hoạch"
	var tool: ItemDefinition = _tool_of(_actor)
	if not tilled:
		if tool != null and tool.tool_type == HOE:
			return "Cày (%s)" % tool.describe_wear(_equipment_of(_actor).get_stack(&"weapon"))
		return "Cần cuốc đất"
	if crop != null:
		var state: String = "giai đoạn %d/%d · %s" % [get_stage() + 1, crop.stages, "ướt" if is_wet() else "khô"]
		if tool != null and tool.tool_type == WATERING_CAN:
			if is_wet():
				return "Đã tưới hôm nay · %s" % state
			var water: int = tool.water_of(_equipment_of(_actor).get_stack(&"weapon"))
			return ("Tưới (%s) · %s" % [tool.describe_wear(_equipment_of(_actor).get_stack(&"weapon")), state]) if water > 0 \
				else "Bình tưới hết nước · %s" % state
		return "Giai đoạn %d/%d · %s" % [get_stage() + 1, crop.stages, "ướt" if is_wet() else "khô — cần tưới"]
	var layer: FarmLayer = get_field().get_layer() if get_field() != null else null
	if layer == null or layer.get_seed_options(_actor).is_empty():
		return "Cần hạt giống"
	var seed_id: StringName = layer.get_seed_choice(_actor)
	return ("Gieo %s" % _item_name(seed_id)) if seed_id != &"" else "Gieo (chọn hạt)"


func _perform_interaction(actor: Node2D) -> String:
	if is_mature():
		return harvest(actor)
	var tool: ItemDefinition = _tool_of(actor)
	if not tilled:
		if tool == null or tool.tool_type != HOE:
			return "Cần cầm cuốc đất ở tay chính để cày."
		return till(actor)
	if crop != null:
		if tool != null and tool.tool_type == WATERING_CAN:
			return water(actor)
		return "%s: giai đoạn %d/%d, %s." % [crop.display_name, get_stage() + 1, crop.stages, "đất ướt" if is_wet() else "đất khô — cần tưới"]
	var layer: FarmLayer = get_field().get_layer() if get_field() != null else null
	if layer == null:
		return ""
	return layer.request_plant(self, actor)


## Cày ô cỏ bằng cuốc đất đang cầm (−1 độ bền).
func till(actor: Node2D) -> String:
	if tilled:
		return "Đất đã cày."
	var equipment: EquipmentSlots = _equipment_of(actor)
	var tool: ItemDefinition = _tool_of(actor)
	var broke: bool = equipment != null and equipment.wear(&"weapon")
	tilled = true
	fallow_days = 0
	watered_day = 0
	_changed()
	return "Đã cày đất.%s" % ((" %s đã vỡ!" % tool.display_name) if broke and tool != null else "")


## Gieo hạt `seed_id` (lấy 1 từ túi actor). "" nếu thành công, ngược lại là lý do.
func plant(actor: Node2D, seed_id: StringName) -> String:
	if not tilled or crop != null:
		return "Không gieo được ở đây."
	var field: FarmField = get_field()
	var definition: CropDefinition = field.get_layer().crop_book.find_by_seed(seed_id) if field != null and field.get_layer() != null else null
	var inventory: Inventory = _inventory_of(actor)
	if definition == null:
		return "%s không gieo được." % _item_name(seed_id)
	if inventory == null or inventory.remove(seed_id, 1) < 1:
		return "Không còn %s." % _item_name(seed_id)
	crop = definition
	age = 0
	dry_days = 0
	fallow_days = 0
	_changed()
	return ""


## Tưới bằng bình tưới đang cầm (−1 nước). Đất ướt tới hết ngày hôm nay.
func water(actor: Node2D) -> String:
	if crop == null:
		return "Chưa gieo gì để tưới."
	if is_wet():
		return "Đã tưới hôm nay."
	var equipment: EquipmentSlots = _equipment_of(actor)
	var tool: ItemDefinition = _tool_of(actor)
	if tool == null or tool.tool_type != WATERING_CAN:
		return "Cần cầm bình tưới."
	var stack: ItemStack = equipment.get_stack(&"weapon")
	var left: int = tool.water_of(stack)
	if left <= 0:
		return "Bình tưới hết nước — múc ở suối."
	equipment.set_stack_data(&"weapon", ItemDefinition.WATER_KEY, left - 1)
	water_now()
	return "Đã tưới %s (nước còn %d/%d)." % [crop.display_name, left - 1, tool.water_capacity]


## Đánh dấu đã tưới hôm nay (bình tưới, debug tưới hết ruộng; sau này: mưa).
func water_now() -> void:
	if crop == null:
		return
	watered_day = _today()
	_changed()


## Thu cây chín: nông sản + hạt vào túi actor (phần không vừa rơi xuống đất cạnh actor). Cây thu một lần → ô về đất cày
## trống; cây thu nhiều lần → ở lại, lùi `regrow_days` ngày tuổi.
func harvest(actor: Node2D) -> String:
	if not is_mature():
		return "Chưa chín."
	var field: FarmField = get_field()
	var rng: RandomNumberGenerator = field.get_layer().rng if field != null and field.get_layer() != null else RandomNumberGenerator.new()
	var stacks: Array[ItemStack] = []
	var amount: int = rng.randi_range(crop.yield_min, crop.yield_max)
	if amount > 0:
		stacks.append(ItemStack.new(crop.yield_item_id, amount))
	var seeds: int = rng.randi_range(crop.seed_return_min, crop.seed_return_max)
	if seeds > 0:
		stacks.append(ItemStack.new(crop.seed_item_id, seeds))
	var harvested: CropDefinition = crop
	if crop.multi_harvest:
		age = maxi(0, crop.get_mature_age() - crop.regrow_days)
	else:
		crop = null
		age = 0
		fallow_days = 0
	dry_days = 0
	var text: String = field.get_layer().give(actor, stacks) if field != null and field.get_layer() != null else ""
	_changed()
	if field != null and field.get_layer() != null:
		field.get_layer().crop_harvested.emit(self, harvested, stacks)
	return "Thu hoạch %s: %s" % [harvested.display_name, text]


## Qua 6:00 của ngày `day` (FarmLayer gọi, kể cả khi ngủ / ngất / tải save bù ngày):
## - cây chưa chín: hôm trước (`day` − 1) được tưới (hoặc `rained`) → +1 ngày tuổi, hết khô; không → +1 ngày khô; khô
##   `dry_days_to_die` ngày liên tục → héo chết, để lại đất cày trống;
## - cây chín: không cần nước, không héo (chờ thu);
## - đất cày trống: +1 ngày bỏ trống; đủ `fallow_days_to_grass` → về cỏ.
## Trả về true nếu trạng thái đổi.
func advance_day(day: int, dry_days_to_die: int, fallow_days_to_grass: int, rained: bool = false) -> bool:
	if not tilled:
		return false
	if crop == null:
		fallow_days += 1
		if fallow_days >= fallow_days_to_grass:
			tilled = false
			fallow_days = 0
			watered_day = 0
		return true
	if is_mature():
		dry_days = 0
		return false
	if watered_day == day - 1 or rained:
		age += 1
		dry_days = 0
	else:
		dry_days += 1
		if dry_days >= dry_days_to_die:
			crop = null
			age = 0
			dry_days = 0
			fallow_days = 0
	return true


## Debug: lớn thêm một giai đoạn.
func debug_grow_stage() -> void:
	if crop == null or is_mature():
		return
	age = mini(crop.get_mature_age(), (get_stage() + 1) * crop.days_per_stage)
	_changed()


## Trạng thái lưu (rỗng = ô cỏ, không cần lưu).
func save_plot_state() -> Dictionary:
	if not tilled:
		return {}
	var state: Dictionary = {"state": "planted" if crop != null else "tilled", "watered_day": watered_day, "wet": is_wet(),
		"dry_days": dry_days, "fallow_days": fallow_days}
	if crop != null:
		state["crop"] = String(crop.id)
		state["stage"] = get_stage()
		state["age"] = age
	return state


func load_plot_state(state: Dictionary, book: CropBook) -> void:
	tilled = false
	crop = null
	age = 0
	watered_day = 0
	dry_days = 0
	fallow_days = 0
	var kind: String = str(state.get("state", "grass"))
	if kind != "tilled" and kind != "planted":
		_changed()
		return
	tilled = true
	watered_day = _int_or(state.get("watered_day"), 0)
	dry_days = maxi(0, _int_or(state.get("dry_days"), 0))
	fallow_days = maxi(0, _int_or(state.get("fallow_days"), 0))
	if kind == "planted":
		crop = book.get_crop(StringName(str(state.get("crop", "")))) if book != null else null
		if crop == null:
			push_warning("[FarmPlot] Cây không tồn tại '%s' ở ô %s — để đất cày trống." % [state.get("crop"), cell])
		else:
			age = clampi(_int_or(state.get("age"), 0), 0, crop.get_mature_age())
	_changed()


func _draw() -> void:
	if crop == null:
		return
	var stage: int = get_stage()
	var color: Color = crop.get_stage_color(stage)
	var ratio: float = float(stage + 1) / crop.stages
	var height: float = crop.mature_height * ratio
	var spread: float = 3.0 + 5.0 * ratio
	# Mầm: vài lá nhỏ; lớn dần: thêm thân / lá; chín: thêm bông / quả / củ màu fruit_color.
	var blades: int = 2 + stage
	for k: int in blades:
		var x: float = lerpf(-spread, spread, float(k) / maxf(1.0, blades - 1))
		var top: Vector2 = Vector2(x * 0.6, -height * (0.75 + 0.25 * float(k % 2)))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1.2, 0), Vector2(x + 1.2, 0), top]), color)
	if is_mature():
		for k: int in 3:
			var at: Vector2 = Vector2(lerpf(-spread, spread, k / 2.0) * 0.6, -height * 0.8)
			draw_circle(at, 2.2, crop.fruit_color)


func _changed() -> void:
	queue_redraw()
	changed.emit(self)


func _today() -> int:
	var field: FarmField = get_field()
	return field.get_layer().get_day() if field != null and field.get_layer() != null else 1


func _item_name(item_id: StringName) -> String:
	var inventory: Inventory = _inventory_of(_actor)
	var item: ItemDefinition = inventory.database.get_item(item_id) if inventory != null and inventory.database != null else null
	return item.display_name if item != null else String(item_id)


static func _equipment_of(actor: Node2D) -> EquipmentSlots:
	return actor.call(&"get_equipment") as EquipmentSlots if actor != null and actor.has_method(&"get_equipment") else null


static func _inventory_of(actor: Node2D) -> Inventory:
	return actor.call(&"get_inventory") as Inventory if actor != null and actor.has_method(&"get_inventory") else null


static func _tool_of(actor: Node2D) -> ItemDefinition:
	var equipment: EquipmentSlots = _equipment_of(actor)
	return equipment.get_tool() if equipment != null else null


static func _int_or(value: Variant, fallback: int) -> int:
	return int(value) if (value is int or value is float) else fallback
